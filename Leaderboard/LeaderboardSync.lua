local addonName, addon = ...
if not addon then return end

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

local Sync = Leaderboard.Sync or {}
Leaderboard.Sync = Sync

local C_Timer = C_Timer
local C_AddOns = C_AddOns
local GetGuildInfo = GetGuildInfo
local GetRealmName = GetRealmName
local GetServerTime = GetServerTime
local LibStub = LibStub
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitRace = UnitRace
local UnitSex = UnitSex
local time = time

--- Numeric race id from UnitRace("player") third return only (Anniversary exposes it).
local function GetPlayerRaceIdSex()
    local sex = UnitSex and UnitSex("player") or 2
    if sex ~= 2 and sex ~= 3 then
        sex = 2
    end

    local raceId
    if UnitRace then
        local _, _, rid = UnitRace("player")
        if type(rid) == "number" then
            raceId = rid
        end
    end

    return raceId, sex
end

-- No underscore: LibP2PDB chat parse uses ^(%w+); — %w excludes '_'.
local DB_PREFIX = "HCALB"
local TABLE_NAME = "players"
local PRESENCE_TABLE_NAME = "presence"
local PERSIST_DEBOUNCE_SECONDS = 90
-- LibP2PDB schema length is strict: bump DB version when player fields change.
-- v3: completedIds is a packed string (still accepts legacy tables from v2 peers).
local DB_VERSION = 3

-- v1 schema (pre-completedIds). Used only to import older persisted/network state.
local PLAYER_SCHEMA_V1 = {
    name = "string",
    realm = "string",
    guild = "string",
    faction = "string",
    class = "string",
    classId = { "number", "nil" },
    level = "number",
    completed = "number",
    total = "number",
    points = "number",
    raceId = { "number", "nil" },
    sex = { "number", "nil" },
    label = "string",
    selfFound = { "boolean", "nil" },
    dead = "boolean",
    offline = { "boolean", "nil" },
    version = "string",
    updatedAt = "number",
}

local PLAYER_SCHEMA_V2 = {
    name = "string",
    realm = "string",
    guild = "string",
    faction = "string",
    class = "string",
    classId = { "number", "nil" },
    level = "number",
    completed = "number",
    total = "number",
    points = "number",
    raceId = { "number", "nil" },
    sex = { "number", "nil" },
    label = "string",
    selfFound = { "boolean", "nil" },
    dead = "boolean",
    offline = { "boolean", "nil" },
    version = "string",
    updatedAt = "number",
    completedIds = { "table", "string", "nil" },
}

local PRESENCE_SCHEMA = {
    updatedAt = "number",
    offline = { "boolean", "nil" },
}

local LibP2PDB = LibStub and LibStub("LibP2PDB", true)
local persistDebounceToken = 0

-- TEMP [LBTrace]: discovery/sync/receive/UI diagnostics. Remove after investigation.
local function Trace(msg)
    if addon.DebugPrint then
        addon.DebugPrint("[LBTrace] " .. tostring(msg))
    end
end
Sync.Trace = Trace

local function TraceTransport()
    local chan = addon.GetHCACommChannelName and addon.GetHCACommChannelName()
    return ("guild=%s group=%s instance=%s yell=%s chat=%s"):format(
        tostring(IsInGuild and IsInGuild() or false),
        tostring(IsInGroup and IsInGroup() or false),
        tostring(IsInInstance and IsInInstance() or false),
        tostring(not (IsInInstance and IsInInstance())),
        tostring(chan or "none"))
end

local function TracePeers(db)
    if not LibP2PDB or not db then
        return "peers=?"
    end
    local ok, peers = pcall(function()
        return LibP2PDB:ListPeers(db)
    end)
    if not ok or type(peers) ~= "table" then
        return "peers=?"
    end
    local names = {}
    for _, info in pairs(peers) do
        names[#names + 1] = tostring(info and info.name)
    end
    -- ListPeers includes self.
    return ("peers=%d [%s]"):format(#names, table.concat(names, ","))
end

-- HCA chat carries presence pings only (full players rows exceed the 255-byte chat limit).

--- Stock LibP2PDB BroadcastKey (GUILD/PARTY/RAID/YELL). HCA chat queue: presence only.
local function BroadcastKeyAndQueue(db, tableName, key)
    if not LibP2PDB or not db or not key then
        return
    end
    pcall(function()
        LibP2PDB:BroadcastKey(db, tableName, key)
    end)
    -- Never queue full players rows for HCA chat; presence is the realm-wide ping.
    if tableName == PRESENCE_TABLE_NAME and addon.QueueChatBroadcast then
        addon.QueueChatBroadcast(tableName, key)
    end
end

local function OnMigrateDB(target, source)
    if source.version == 1 then
        LibP2PDB:NewTable(source.db, {
            name = TABLE_NAME,
            keyType = "string",
            exclusive = false,
            schema = PLAYER_SCHEMA_V1,
        })
        LibP2PDB:NewTable(source.db, {
            name = PRESENCE_TABLE_NAME,
            keyType = "string",
            exclusive = false,
            schema = PRESENCE_SCHEMA,
        })
    end
end

local function OnMigrateRow(target, source)
    if not source.key then
        return nil
    end
    if not source.data then
        return source.key, nil
    end
    if source.tableName == TABLE_NAME then
        local data = source.data
        if Leaderboard.PackCompletedIds then
            data.completedIds = Leaderboard.PackCompletedIds(data.completedIds)
        elseif type(data.completedIds) ~= "table" and type(data.completedIds) ~= "string" then
            data.completedIds = ""
        end
        return source.key, data
    end
    return source.key, source.data
end

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

--- Same resolution as Functions/AchievementEventLog.lua (C_AddOns first; global fallback).
local function GetAddOnVersionString()
    local ver
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif GetAddOnMetadata then
        ver = GetAddOnMetadata(addonName, "Version")
    end
    if not ver or ver == "" then
        ver = "?"
    end
    return ver
end

Leaderboard.GetAddOnVersionString = GetAddOnVersionString

local function GetCharacterKey()
    return Leaderboard.GetLeaderboardRowKey and Leaderboard.GetLeaderboardRowKey()
end

-- Inactive players expire locally (onIsExpired + local cache prune) instead of being deleted:
-- LibP2PDB never purges tombstones, so DeleteKey would grow storage and gossip forever.
local ACTIVITY_RETENTION_SECONDS = 30 * 86400

--- Unknown activity (0) never expires; neither does the local character.
--- @param key string
--- @param lastActivityAt number newest updatedAt across players + presence
--- @return boolean
function Sync.IsActivityExpired(key, lastActivityAt)
    if key == GetCharacterKey() or not lastActivityAt or lastActivityAt <= 0 then
        return false
    end
    return (Now() - lastActivityAt) > ACTIVITY_RETENTION_SECONDS
end

--- onIsExpired for both tables: activity is the newer of the players row and presence updatedAt,
--- because unchanged players rows are not republished while presence keeps heartbeating.
local function MakeOnIsExpired(otherTableName)
    return function(key, data)
        local otherAt = 0
        if LibP2PDB and Sync.db then
            local other = LibP2PDB:GetKey(Sync.db, otherTableName, key)
            otherAt = type(other) == "table" and (tonumber(other.updatedAt) or 0) or 0
        end
        local ownAt = type(data) == "table" and (tonumber(data.updatedAt) or 0) or 0
        return Sync.IsActivityExpired(key, math.max(ownAt, otherAt))
    end
end

--- Guild name for sync: GetGuildInfo is often nil during logout / zoning; keep last known + stored row.
local function GuildForPublish(reason)
    local key = GetCharacterKey()
    if not key then
        return ""
    end
    local root = Leaderboard:GetDB()
    root.guildLastKnown = root.guildLastKnown or {}

    local liveRaw = GetGuildInfo("player")
    if type(liveRaw) == "string" and liveRaw ~= "" then
        root.guildLastKnown[key] = liveRaw
        return liveRaw
    end
    if liveRaw == "" then
        root.guildLastKnown[key] = nil
        return ""
    end

    if reason == "PLAYER_LOGOUT" then
        local prev = root.rows and root.rows[key]
        if prev and type(prev.guild) == "string" and prev.guild ~= "" then
            return prev.guild
        end
        local cached = root.guildLastKnown[key]
        if type(cached) == "string" and cached ~= "" then
            return cached
        end
    end

    local prevGuild = root.rows and root.rows[key] and root.rows[key].guild
    if type(prevGuild) == "string" and prevGuild ~= "" then
        return prevGuild
    end
    local cached = root.guildLastKnown[key]
    if type(cached) == "string" and cached ~= "" then
        return cached
    end
    return ""
end

local function ClearGuildCacheForPlayer()
    local key = GetCharacterKey()
    if not key then
        return
    end
    local root = Leaderboard:GetDB()
    if root.guildLastKnown then
        root.guildLastKnown[key] = nil
    end
end

local function FieldEqual(key, a, b)
    if a == b then
        return true
    end
    if key == "completedIds" then
        if Leaderboard.CompletedIdsEqual then
            return Leaderboard.CompletedIdsEqual(a, b)
        end
        return false
    end
    return false
end

local function ShallowEqual(a, b, ignoreKey)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for key, value in pairs(a) do
        if key ~= ignoreKey and not FieldEqual(key, value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if key ~= ignoreKey and a[key] == nil then
            return false
        end
    end
    return true
end

local function StoreRow(key, row)
    local db = Leaderboard:GetDB()
    db.rows = db.rows or {}
    local current = db.rows[key]
    if row and current and ShallowEqual(current, row) then
        return false
    elseif not row and current == nil then
        return false
    end

    if row then
        db.rows[key] = row
    else
        db.rows[key] = nil
    end
    db.updatedAt = Now()
    if Leaderboard.Data and Leaderboard.Data.Invalidate then
        Leaderboard.Data:Invalidate()
    end
    -- Option A: mark dirty for incremental update instead of full refresh.
    -- Full rebuilds still happen on user actions (scope/search/sort) and safety ticker.
    if Leaderboard.MarkDirty then
        Leaderboard:MarkDirty(key)
    end
    if Leaderboard.ScheduleCompletionStatsRebuild then
        Leaderboard.ScheduleCompletionStatsRebuild()
    end
    return true
end

local function StorePresence(key, presence)
    local db = Leaderboard:GetDB()
    db.presence = db.presence or {}
    local current = db.presence[key]
    if presence and current and ShallowEqual(current, presence) then
        return false
    elseif not presence and current == nil then
        return false
    end

    if presence then
        db.presence[key] = presence
    else
        db.presence[key] = nil
    end
    db.updatedAt = Now()
    if Leaderboard.Data and Leaderboard.Data.Invalidate then
        Leaderboard.Data:Invalidate()
    end
    if Leaderboard.MarkDirty then
        Leaderboard:MarkDirty(key)
    end
    return true
end

local function PlayerIsDead()
    if UnitIsDeadOrGhost then
        return UnitIsDeadOrGhost("player") and true or false
    end
    return ((UnitIsDead and UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player"))) and true or false
end

local function GetCachedLeaderboardStats(current)
    if type(current) == "table" then
        return tonumber(current.completed) or 0, tonumber(current.total) or 0, tonumber(current.points) or 0
    end
    return 0, 0, 0
end

-- Guard: at most one combat-deferred persist pending at a time.
local _persistCombatPending = false

local function PersistState()
    if not LibP2PDB or not Sync.db then
        _persistCombatPending = false
        return
    end
    -- Avoid running ExportDatabase (O(n) over all leaderboard rows) during active combat.
    -- A single retry fires 8s later; if still in combat another retry is scheduled, but
    -- _persistCombatPending ensures at most one is ever queued at once.
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        if C_Timer and C_Timer.After and not _persistCombatPending then
            _persistCombatPending = true
            C_Timer.After(8, function()
                _persistCombatPending = false
                PersistState()
            end)
        end
        return
    end
    _persistCombatPending = false
    local db = Leaderboard:GetDB()
    local ok, state = pcall(function()
        return LibP2PDB:ExportDatabase(Sync.db)
    end)
    if ok and state then
        db.state = state
        db.savedAt = Now()
        db.stateVersion = nil
    end
end

local function SchedulePersistState(immediate)
    persistDebounceToken = persistDebounceToken + 1
    if immediate or not C_Timer or not C_Timer.After then
        PersistState()
        return
    end

    local token = persistDebounceToken
    C_Timer.After(PERSIST_DEBOUNCE_SECONDS, function()
        if token == persistDebounceToken then
            PersistState()
        end
    end)
end

-- Pending-change buffers for leaderboard and presence data.
-- Incoming network messages are accumulated here and applied once per drain tick (0.5s),
-- coalescing burst deliveries (e.g. guild login) into a single StoreRow/StorePresence pass.
-- "Last write wins" semantics are correct because updatedAt ordering makes the latest message
-- authoritative. false is used as a nil-sentinel to represent explicit deletions.
local _pendingRowChanges = {}
local _pendingPresenceChanges = {}

-- TEMP [LBTrace]: non-nil while Sync:Initialize imports saved state; per-row logging is aggregated.
local traceInitCounts = nil
-- TEMP [LBTrace]: live tombstones arrive in gossip bursts; reported per drain instead of per row.
local traceLiveDeletes = { rows = 0, presence = 0 }

local function DrainPendingChanges()
    local any = false
    local rowsApplied, presenceApplied = 0, 0
    for key, newData in pairs(_pendingRowChanges) do
        if StoreRow(key, newData ~= false and newData or nil) then
            any = true
            rowsApplied = rowsApplied + 1
        end
        _pendingRowChanges[key] = nil
    end
    for key, newData in pairs(_pendingPresenceChanges) do
        if StorePresence(key, newData ~= false and newData or nil) then
            any = true
            presenceApplied = presenceApplied + 1
        end
        _pendingPresenceChanges[key] = nil
    end
    if rowsApplied > 0 or presenceApplied > 0 or traceLiveDeletes.rows > 0 or traceLiveDeletes.presence > 0 then
        Trace(("drain applied rows=%d presence=%d; remote deletions received rows=%d presence=%d"):format(
            rowsApplied, presenceApplied, traceLiveDeletes.rows, traceLiveDeletes.presence))
        traceLiveDeletes.rows = 0
        traceLiveDeletes.presence = 0
    end
    if any then
        SchedulePersistState(false)
    end
end

local function OnTableChanged(key, newData)
    -- Remote/network applies only — never queue HCA presence pings here (anti ping-pong).
    _pendingRowChanges[key] = newData or false
    if traceInitCounts then
        local field = newData and "rows" or "rowDeletes"
        traceInitCounts[field] = traceInitCounts[field] + 1
    elseif not newData then
        traceLiveDeletes.rows = traceLiveDeletes.rows + 1
    elseif key ~= GetCharacterKey() then
        Trace(("remote players row received %s name=%s"):format(tostring(key), tostring(newData.name)))
    end
end

local function OnPresenceChanged(key, newData)
    -- Remote/network applies only — never queue HCA presence pings here (anti ping-pong).
    _pendingPresenceChanges[key] = newData or false
    if traceInitCounts then
        local field = newData and "presence" or "presenceDeletes"
        traceInitCounts[field] = traceInitCounts[field] + 1
    elseif not newData then
        traceLiveDeletes.presence = traceLiveDeletes.presence + 1
    elseif key ~= GetCharacterKey() then
        Trace(("remote presence received %s"):format(tostring(key)))
    end
end

local function ValidatePeerOwnedKey(key, context)
    if not context or not context.peerID then
        return true
    end
    if not LibP2PDB or type(LibP2PDB.PlayerGUIDToPeerID) ~= "function" then
        return true
    end
    local ok, peerID = pcall(function()
        return LibP2PDB:PlayerGUIDToPeerID(key)
    end)
    if not ok then
        return false
    end

    -- Direct broadcasts should only write the sender's own row. Gossip sync arrives
    -- by WHISPER from a relay peer, so the sender can differ from the row owner there.
    if peerID == context.peerID then
        return true
    end
    return context.channel == "WHISPER"
end

local function OnPlayerRowValidate(key, data, context)
    return type(data) == "table" and ValidatePeerOwnedKey(key, context)
end

local function OnPresenceValidate(key, data, context)
    return type(data) == "table" and ValidatePeerOwnedKey(key, context)
end

--- Old "Name-Realm" row key used before switching to UnitGUID; migrate once to the GUID key.
--- Forever must not treat UnitName's surname as a realm.
local function LegacyNameRealmKey()
    local name = (addon.GetPlayerFullName and addon.GetPlayerFullName()) or UnitName("player")
    local realm = (addon.GetPlayerRealmLabel and addon.GetPlayerRealmLabel()) or GetRealmName()
    if not name or name == "" then
        return nil
    end
    return (realm and realm ~= "" and (name .. "-" .. realm)) or name
end

local function MigrateLegacyLeaderboardKey()
    if not LibP2PDB or not Sync.db then
        return
    end
    local newKey = Leaderboard.GetLeaderboardRowKey and Leaderboard.GetLeaderboardRowKey()
    local legacy = LegacyNameRealmKey()
    if not newKey or not legacy or newKey == legacy then
        return
    end

    local root = Leaderboard:GetDB()
    root.rows = root.rows or {}
    local oldRow = root.rows[legacy]
    if not oldRow then
        return
    end

    if root.rows[newKey] then
        root.rows[legacy] = nil
    else
        root.rows[newKey] = oldRow
        root.rows[legacy] = nil
    end

    root.guildLastKnown = root.guildLastKnown or {}
    if root.guildLastKnown[legacy] ~= nil and root.guildLastKnown[newKey] == nil then
        root.guildLastKnown[newKey] = root.guildLastKnown[legacy]
    end
    root.guildLastKnown[legacy] = nil

    pcall(function()
        LibP2PDB:DeleteKey(Sync.db, TABLE_NAME, legacy)
    end)
    if root.rows[newKey] then
        pcall(function()
            LibP2PDB:SetKey(Sync.db, TABLE_NAME, newKey, root.rows[newKey])
        end)
    end

    SchedulePersistState(true)
end

function Sync:GetDatabase()
    return self.db
end

function Sync:GetTableName()
    return TABLE_NAME
end

function Sync:GetPresenceTableName()
    return PRESENCE_TABLE_NAME
end

function Sync:TombstoneKey(key)
    if not LibP2PDB or not self.db or not key then
        return false
    end

    -- DeleteKey returns true as a no-op for missing/already-tombstoned keys, which leaves nothing
    -- for BroadcastKey to send. Pruned keys are other players' GUIDs, so never use the HCA chat queue.
    local changed = false
    for _, tableName in ipairs({ TABLE_NAME, PRESENCE_TABLE_NAME }) do
        pcall(function()
            if LibP2PDB:HasKey(self.db, tableName, key) and LibP2PDB:DeleteKey(self.db, tableName, key) then
                changed = true
                LibP2PDB:BroadcastKey(self.db, tableName, key)
            end
        end)
    end

    return changed
end

function Sync:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    if not LibP2PDB then
        return
    end

    local db = LibP2PDB:GetDatabase(DB_PREFIX)
    if not db then
        db = LibP2PDB:NewDatabase({
            prefix = DB_PREFIX,
            version = DB_VERSION,
            peerTimeout = 400,
            -- TEMP [LBTrace]: logging only.
            onPeerAdded = function(peerID, peerName)
                Trace(("peer discovered %s (%s)"):format(tostring(peerName), tostring(peerID)))
            end,
            onPeerExpired = function(peerID, peerName)
                Trace(("peer expired %s (%s)"):format(tostring(peerName), tostring(peerID)))
            end,
            onError = addon.LibP2PDBOnError,
            onMigrateDB = OnMigrateDB,
            onMigrateRow = OnMigrateRow,
        })
    end
    self.db = db
    traceInitCounts = { rows = 0, rowDeletes = 0, presence = 0, presenceDeletes = 0 }

    pcall(function()
        LibP2PDB:NewTable(db, {
            name = TABLE_NAME,
            keyType = "string",
            exclusive = false,
            rowsPerChunk = 16, -- packed completedIds keeps each gossip chunk small
            schema = PLAYER_SCHEMA_V2,
            onValidate = OnPlayerRowValidate,
            onIsExpired = MakeOnIsExpired(PRESENCE_TABLE_NAME),
            onChange = OnTableChanged,
        })
    end)

    pcall(function()
        LibP2PDB:NewTable(db, {
            name = PRESENCE_TABLE_NAME,
            keyType = "string",
            exclusive = false,
            rowsPerChunk = 128,
            schema = PRESENCE_SCHEMA,
            onValidate = OnPresenceValidate,
            onIsExpired = MakeOnIsExpired(TABLE_NAME),
            onChange = OnPresenceChanged,
        })
    end)

    local root = Leaderboard:GetDB()
    local saved = root.state
    if saved then
        pcall(function()
            LibP2PDB:ImportDatabase(db, saved)
        end)
    end

    MigrateLegacyLeaderboardKey()

    Trace(("init import: players rows=%d deleted=%d, presence=%d deleted=%d"):format(
        traceInitCounts.rows, traceInitCounts.rowDeletes,
        traceInitCounts.presence, traceInitCounts.presenceDeletes))
    traceInitCounts = nil

    -- Custom chat channel "HCA" (SendChatMessage), not addon CHANNEL — Classic / TBC / Forever.
    if addon.InitializeHCAChatBroadcast then
        addon.InitializeHCAChatBroadcast(db)
    end

    -- Single drain ticker: coalesces burst network deliveries into one apply pass per 0.5 seconds.
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.5, DrainPendingChanges)
    end

    if Leaderboard.ScheduleCompletionStatsRebuild then
        Leaderboard.ScheduleCompletionStatsRebuild()
    end
end

function Sync:BuildLocalRow(options)
    options = options or {}
    local name = UnitName("player")
    if not name or name == "" then
        return nil
    end

    local current = options.currentRow
    if options.skipHeavyStats and type(current) ~= "table" then
        return nil
    end
    local completed, total, points = GetCachedLeaderboardStats(current)
    local allowHeavyStats = not options.skipHeavyStats and not (addon and addon.Initializing)
    if allowHeavyStats and addon.GetCachedAchievementStats then
        local stats = addon.GetCachedAchievementStats()
        if stats then
            completed, total, points = stats.completed, stats.total, stats.points
        end
    elseif allowHeavyStats then
        if addon.AchievementCount then
            completed, total = addon.AchievementCount()
        end
        if addon.GetTotalPoints then
            points = addon.GetTotalPoints()
        end
    end

    local completedIds
    if allowHeavyStats and Leaderboard.BuildLocalCompletedIds then
        completedIds = Leaderboard.BuildLocalCompletedIds()
    elseif type(current) == "table" and type(current.completedIds) == "table" then
        completedIds = current.completedIds
    else
        completedIds = {}
    end

    local label = ""
    if addon.GetPlayerSelfFoundLabel then
        label = addon.GetPlayerSelfFoundLabel() or ""
    end

    local dead = PlayerIsDead()
    if options.dead ~= nil then
        dead = options.dead and true or false
    end

    local raceId, sex = GetPlayerRaceIdSex()
    local classEnglish, classId
    if Leaderboard.GetNormalizedPlayerClass then
        classEnglish, classId = Leaderboard.GetNormalizedPlayerClass()
    end
    if not classEnglish or classEnglish == "" then
        classEnglish = "Unknown"
    end

    return {
        name = (addon.GetPlayerFullName and addon.GetPlayerFullName()) or name,
        realm = (addon.GetPlayerRealmLabel and addon.GetPlayerRealmLabel()) or GetRealmName() or "",
        guild = GuildForPublish(options.publishReason),
        faction = UnitFactionGroup("player") or "",
        class = classEnglish,
        classId = classId,
        level = UnitLevel("player") or 0,
        completed = tonumber(completed) or 0,
        total = tonumber(total) or 0,
        points = tonumber(points) or 0,
        raceId = raceId,
        sex = sex,
        label = label,
        selfFound = label == "Self Found",
        dead = dead,
        offline = options.offline == true,
        version = GetAddOnVersionString(),
        updatedAt = Now(),
        completedIds = (Leaderboard.PackCompletedIds and Leaderboard.PackCompletedIds(completedIds)) or completedIds,
    }
end

function Sync:PublishLocal(reason)
    if addon.IsForeverChatRestricted and addon.IsForeverChatRestricted() then
        return false
    end
    if not LibP2PDB or not self.db then
        return false
    end

    local key = GetCharacterKey()
    local current = key and Leaderboard:GetDB().rows and Leaderboard:GetDB().rows[key]

    -- Logout often runs after unit state clears; keep dead=true from the last stored row.
    local buildOpts = {
        offline = (reason == "PLAYER_LOGOUT"),
        publishReason = reason,
        currentRow = current,
        -- Init publishes are lightweight only; login is delayed by Leaderboard.lua
        -- so it can safely establish a full row after addon startup.
        -- Achievement/level events publish full-stat rows later when meaningful data changes.
        skipHeavyStats = (reason == "init"),
    }
    if reason == "PLAYER_DEAD" then
        buildOpts.dead = true
    elseif reason == "PLAYER_LOGOUT" and current and current.dead == true then
        buildOpts.dead = true
    end
    local row = self:BuildLocalRow(buildOpts)
    if not key or not row then
        return false
    end
    -- updatedAt is always Now(); a timestamp-only difference must not bump the row version and trigger gossip.
    if current and ShallowEqual(current, row, "updatedAt") then
        Trace(("PublishLocal(%s) skipped: unchanged"):format(tostring(reason)))
        return true
    end
    Trace(("PublishLocal(%s) sending players row; %s"):format(tostring(reason), TraceTransport()))
    local ok, success = pcall(function()
        return LibP2PDB:SetKey(self.db, TABLE_NAME, key, row)
    end)
    if ok and success then
        local changed = StoreRow(key, row)
        SchedulePersistState(reason == "PLAYER_LOGOUT" or reason == "PLAYER_DEAD")
        -- Stock channels get the full players row; HCA chat is presence-only.
        BroadcastKeyAndQueue(self.db, TABLE_NAME, key)
        -- Local leaderboard change: bump presence so HCA hardware flush can ping the realm.
        -- Do not do this from onChange handlers (receiving remote rows must not re-broadcast).
        if reason ~= "PLAYER_LOGOUT" then
            self:PublishPresence(row.offline == true)
        end
        return changed or true
    end
    return false
end

function Sync:PublishPresence(offline)
    if not LibP2PDB or not self.db then
        return false
    end

    local key = GetCharacterKey()
    if not key then
        return false
    end

    local presence = {
        updatedAt = Now(),
        offline = offline == true,
    }

    local ok, success = pcall(function()
        return LibP2PDB:SetKey(self.db, PRESENCE_TABLE_NAME, key, presence)
    end)
    if ok and success then
        StorePresence(key, presence)
        SchedulePersistState(offline == true)
        BroadcastKeyAndQueue(self.db, PRESENCE_TABLE_NAME, key)
        return true
    end
    return false
end

function Sync:ClearGuildLastKnown()
    ClearGuildCacheForPlayer()
end

function Sync:BroadcastPresence()
    if not LibP2PDB or not self.db then
        return
    end
    Trace("BroadcastPresence (Empty packet); " .. TraceTransport())
    pcall(function()
        LibP2PDB:BroadcastPresence(self.db)
    end)
end

function Sync:SyncDatabase()
    if not LibP2PDB or not self.db then
        return
    end
    Trace("SyncDatabase; " .. TracePeers(self.db))
    pcall(function()
        LibP2PDB:SyncDatabase(self.db)
    end)
end

function Sync:SyncPeers()
    self:BroadcastPresence()
    self:SyncDatabase()
end

function Sync:Persist()
    SchedulePersistState(true)
end
