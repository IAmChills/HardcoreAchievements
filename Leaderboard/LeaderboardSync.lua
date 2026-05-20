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

local DB_PREFIX = "HCA_LB"
local TABLE_NAME = "players"
local PRESENCE_TABLE_NAME = "presence"
local PERSIST_DEBOUNCE_SECONDS = 45

local LibP2PDB = LibStub and LibStub("LibP2PDB", true)
local persistDebounceToken = 0

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

local function ShallowEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for key, value in pairs(a) do
        if b[key] ~= value then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
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

local function PersistState()
    if not LibP2PDB or not Sync.db then
        return
    end
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

local function OnTableChanged(key, newData)
    if StoreRow(key, newData) then
        SchedulePersistState(false)
    end
end

local function OnPresenceChanged(key, newData)
    if StorePresence(key, newData) then
        SchedulePersistState(false)
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
    return ok and peerID == context.peerID
end

local function OnPlayerRowValidate(key, data, context)
    return type(data) == "table" and ValidatePeerOwnedKey(key, context)
end

local function OnPresenceValidate(key, data, context)
    return type(data) == "table" and ValidatePeerOwnedKey(key, context)
end

--- Old "Name-Realm" row key used before switching to UnitGUID; migrate once to the GUID key.
local function LegacyNameRealmKey()
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
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
        })
    end
    self.db = db

    pcall(function()
        LibP2PDB:NewTable(db, {
            name = TABLE_NAME,
            keyType = "string",
            exclusive = false,
            rowsPerChunk = 96,
            schema = {
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
            },
            onValidate = OnPlayerRowValidate,
            onChange = OnTableChanged,
        })
    end)

    pcall(function()
        LibP2PDB:NewTable(db, {
            name = PRESENCE_TABLE_NAME,
            keyType = "string",
            exclusive = false,
            rowsPerChunk = 128,
            schema = {
                updatedAt = "number",
                offline = { "boolean", "nil" },
            },
            onValidate = OnPresenceValidate,
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
    if allowHeavyStats and addon.AchievementCount then
        completed, total = addon.AchievementCount()
    end

    if allowHeavyStats and addon.GetTotalPoints then
        points = addon.GetTotalPoints()
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
        name = name,
        realm = GetRealmName() or "",
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
    }
end

function Sync:PublishLocal(reason)
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
    if current and ShallowEqual(current, row) then
        return true
    end
    local ok, success = pcall(function()
        return LibP2PDB:SetKey(self.db, TABLE_NAME, key, row)
    end)
    if ok and success then
        local changed = StoreRow(key, row)
        SchedulePersistState(reason == "PLAYER_LOGOUT" or reason == "PLAYER_DEAD")
        pcall(function()
            LibP2PDB:BroadcastKey(self.db, TABLE_NAME, key)
        end)
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
        pcall(function()
            LibP2PDB:BroadcastKey(self.db, PRESENCE_TABLE_NAME, key)
        end)
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
    pcall(function()
        LibP2PDB:BroadcastPresence(self.db)
    end)
end

function Sync:SyncDatabase()
    if not LibP2PDB or not self.db then
        return
    end
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
