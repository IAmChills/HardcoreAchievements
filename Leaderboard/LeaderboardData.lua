local addonName, addon = ...
if not addon then return end

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

local Data = Leaderboard.Data or {}
Leaderboard.Data = Data

local GetGuildInfo = GetGuildInfo
local GetRealmName = GetRealmName
local GetServerTime = GetServerTime
local UnitFactionGroup = UnitFactionGroup
local UnitName = UnitName
local math_floor = math.floor
local table_sort = table.sort
local time = time

local LibStub = LibStub
local LibP2PDB = LibStub and LibStub("LibP2PDB", true)

local RECENT_SECONDS = 10 * 60
-- Drop other players' rows with no heartbeat for this long (UI + saved DB cleanup).
local STALE_ROW_SECONDS = 3 * 86400
-- Avoid pruning work on every GetRows refresh.
local PRUNE_COOLDOWN_SECONDS = 120
local lastPruneAt = 0

local function MatchesSearch(row, term)
  if not term or term == "" then return true end
  local t = term
  local name = tostring(row.name or ""):lower()
  local class = tostring(row.class or ""):lower()
  local faction = tostring(row.faction or ""):lower()
  local level = tostring(row.level or ""):lower()
  return name:find(t, 1, true) ~= nil
      or class:find(t, 1, true) ~= nil
      or level:find(t, 1, true) ~= nil
      or faction:find(t, 1, true) ~= nil
end

-- Hard cap on displayed leaderboard rows after accurate sorting.
-- Keeps memory/CPU bounded for very large scopes (World) while still showing
-- the true top N for any sort column. Guild/Realm scopes usually stay under this.
local LEADERBOARD_MAX_DISPLAY_ROWS = 500

-- Small duplicated token table + formatter so we can pre-compute the expensive portrait string once per row.
-- This avoids calling Dashboard.LeaderboardClassCellWithPortrait (which does string_format + path concat) on every rebuild.
local LEADERBOARD_RACE_PORTRAIT_TOKEN = {
  [1] = "Human",
  [2] = "Orc",
  [3] = "Dwarf",
  [4] = "Nightelf",
  [5] = "Undead",
  [6] = "Tauren",
  [7] = "Gnome",
  [8] = "Troll",
  [10] = "Bloodelf",
  [11] = "Draenei",
}

local function FormatClassPortrait(classText, raceId, sex)
  local rid = tonumber(raceId)
  local sx = tonumber(sex)
  if not sx or (sx ~= 2 and sx ~= 3) then
    sx = 2
  end
  local token = rid and LEADERBOARD_RACE_PORTRAIT_TOKEN[rid]
  if not token then
    return tostring(classText or "")
  end
  local gender = (sx == 3) and "Female" or "Male"
  local path = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Character_" .. token .. "_" .. gender .. ".PNG"
  return string.format("|T%s:16:16:0:-1|t %s", path, tostring(classText or ""))
end

local function GetLeaderboardAchievementColorCode(completed, total)
  if not total or total == 0 then
    return "9d9d9d"
  end
  local percentage = (completed or 0) / total * 100
  if percentage == 0 then
    return "9d9d9d"
  elseif percentage > 0 and percentage < 20 then
    return "ffffff"
  elseif percentage >= 20 and percentage < 40 then
    return "1eff00"
  elseif percentage >= 40 and percentage < 60 then
    return "0070dd"
  elseif percentage >= 60 and percentage < 80 then
    return "a335ee"
  end
  return "ff8000"
end
local dataVersion = 0
local cachedBaseRows
local cachedBaseVersion
local cachedBaseScopeSignature
local cachedSortedRows
local cachedSortSignature
local cachedRankLabel
local cachedRankVersion
local cachedRankScopeSignature

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Data:Invalidate()
    dataVersion = dataVersion + 1
    cachedBaseRows = nil
    cachedSortedRows = nil
    cachedRankLabel = nil
end

local function FormatAgo(seconds)
    if not seconds or seconds < 0 then return "?" end
    if seconds < 60 then return "now" end
    local minutes = math_floor(seconds / 60)
    if seconds < RECENT_SECONDS then return ("%dm"):format(minutes) end
    local hours = math_floor(seconds / 3600)
    if hours < 1 then return "<1h" end
    if hours < 24 then return ("%dh"):format(hours) end
    return ("%dd"):format(math_floor(seconds / 86400))
end

local function GetLocalCharacterKey()
    if Leaderboard.GetLeaderboardRowKey then
        return Leaderboard.GetLeaderboardRowKey()
    end
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    if not name or name == "" then
        return nil
    end
    return (realm and realm ~= "" and (name .. "-" .. realm)) or name
end

local function PruneStaleLeaderboardRows()
    local now = Now()
    if (now - lastPruneAt) < PRUNE_COOLDOWN_SECONDS then
        return
    end
    lastPruneAt = now

    local localKey = GetLocalCharacterKey()
    if not localKey then
        return
    end

    local root = Leaderboard:GetDB()
    local rows = root.rows
    if not rows then
        return
    end

    local sync = Leaderboard.Sync
    local pdb = sync and sync.GetDatabase and sync:GetDatabase()
    local tableName = sync and sync.GetTableName and sync:GetTableName()
    local presenceTableName = sync and sync.GetPresenceTableName and sync:GetPresenceTableName()

    local toDrop = {}
    for key, row in pairs(rows) do
        if type(row) == "table" and key ~= localKey then
            local presence = root.presence and root.presence[key]
            local rowUpdatedAt = tonumber(row.updatedAt) or 0
            local presenceUpdatedAt = type(presence) == "table" and (tonumber(presence.updatedAt) or 0) or 0
            local updatedAt = math.max(rowUpdatedAt, presenceUpdatedAt)
            if updatedAt > 0 and (now - updatedAt) > STALE_ROW_SECONDS then
                toDrop[#toDrop + 1] = key
            end
        end
    end

    if #toDrop == 0 then
        return
    end

    if Leaderboard.IsPruneGraceActive and Leaderboard:IsPruneGraceActive() then
        -- After login, local saved data can be days old while gossip catch-up is still in flight.
        -- Do not hide or tombstone rows until peers had a chance to refresh them.
        return
    end

    for _, key in ipairs(toDrop) do
        if LibP2PDB and pdb and tableName then
            pcall(function()
                LibP2PDB:DeleteKey(pdb, tableName, key)
                LibP2PDB:BroadcastKey(pdb, tableName, key)
                if presenceTableName then
                    local hasPresence = LibP2PDB:HasKey(pdb, presenceTableName, key)
                    if hasPresence then
                        LibP2PDB:DeleteKey(pdb, presenceTableName, key)
                        LibP2PDB:BroadcastKey(pdb, presenceTableName, key)
                    end
                end
            end)
        else
            rows[key] = nil
            if root.presence then
                root.presence[key] = nil
            end
        end
    end

    if sync and sync.Persist then
        sync:Persist()
    end
    Data:Invalidate()
end

local function ScopeHasFilters(scope)
    return scope and (scope.guild or scope.realm or scope.faction or scope.dead)
end

local function GetPlayerGuildNameForScope()
    local g = select(1, GetGuildInfo("player"))
    if type(g) ~= "string" or g == "" then
        return nil
    end
    return g
end

local function BuildScopeContext()
    return {
        guild = GetPlayerGuildNameForScope(),
        realm = GetRealmName() or "",
        faction = UnitFactionGroup("player") or "",
    }
end

local function ScopeSignature(scope, context)
    context = context or BuildScopeContext()
    return table.concat({
        scope and scope.guild and "1" or "0",
        scope and scope.realm and "1" or "0",
        scope and scope.faction and "1" or "0",
        scope and scope.dead and "1" or "0",
        context.guild or "",
        context.realm or "",
        context.faction or "",
    }, "|")
end

local function InScope(row, scope, context)
    if not ScopeHasFilters(scope) then
        return true
    end

    -- Guild filter only applies when the viewer is in a guild; otherwise it would match every guildless row.
    if scope.guild then
        local playerGuild = context and context.guild or GetPlayerGuildNameForScope()
        if playerGuild then
            local rowGuild = (type(row.guild) == "string" and row.guild ~= "") and row.guild or ""
            if rowGuild ~= playerGuild then
                return false
            end
        end
    end
    if scope.realm and (row.realm or "") ~= ((context and context.realm) or (GetRealmName() or "")) then
        return false
    end
    if scope.faction and (row.faction or "") ~= ((context and context.faction) or (UnitFactionGroup("player") or "")) then
        return false
    end
    if scope.dead and row.dead ~= true then
        return false
    end
    return true
end

local function ValueForSort(row, key)
    if key == "updated" then
        return row._sortUpdated or tonumber(row.lastSeenSec) or math.huge
    elseif key == "class" then
        return row._sortClass or ""
    elseif key == "name" then
        return row._sortName or tostring(row.name or ""):lower()
    elseif key == "faction" then
        return row._sortFaction or tostring(row.faction or ""):lower()
    elseif key == "version" then
        return row._sortVersion or tostring(row.version or ""):lower()
    elseif key == "achievements" then
        return row._sortAchievements or tonumber(row.points) or 0
    elseif key == "selfFound" then
        return row._sortSelfFound or (row.selfFound and 1 or 0)
    end
    return tonumber(row[key]) or 0
end

local function SortRows(rows, sortState)
    sortState = sortState or {}
    local key = sortState.key
    local asc = sortState.asc

    table_sort(rows, function(a, b)
        if key then
            local av = ValueForSort(a, key)
            local bv = ValueForSort(b, key)
            if av ~= bv then
                if asc then
                    return av < bv
                end
                return av > bv
            end
        else
            if a.online ~= b.online then
                return a.online
            end
            if (a.points or 0) ~= (b.points or 0) then
                return (a.points or 0) > (b.points or 0)
            end
            if (a.completed or 0) ~= (b.completed or 0) then
                return (a.completed or 0) > (b.completed or 0)
            end
        end

        if (a.level or 0) ~= (b.level or 0) then
            return (a.level or 0) > (b.level or 0)
        end
        return (a._sortName or tostring(a.name or ""):lower()) < (b._sortName or tostring(b.name or ""):lower())
    end)
end

local function UpdateRelativeTimes(rows, now)
    if not rows then
        return
    end
    for i = 1, #rows do
        local row = rows[i]
        local lastSeenSec = math.max(0, now - (tonumber(row.updatedAt) or 0))
        row.lastSeenSec = lastSeenSec
        row.lastSeenText = FormatAgo(lastSeenSec)
        row.online = (row.offline ~= true) and (lastSeenSec <= RECENT_SECONDS)
        row._sortUpdated = lastSeenSec
    end
end

local function BuildDisplayRow(key, row, now, presence)
    local rowUpdatedAt = tonumber(row.updatedAt) or 0
    local presenceUpdatedAt = type(presence) == "table" and (tonumber(presence.updatedAt) or 0) or 0
    local updatedAt = math.max(rowUpdatedAt, presenceUpdatedAt)
    local lastSeenSec = math.max(0, now - updatedAt)
    local offline = row.offline == true
    if type(presence) == "table" and presenceUpdatedAt >= rowUpdatedAt then
        offline = presence.offline == true
    end
    local classLabel = row.class or "Unknown"
    if Leaderboard.GetEnglishClassName then
        classLabel = Leaderboard.GetEnglishClassName(row.classId, classLabel)
    end
    local name = row.name or key
    local faction = row.faction or ""
    local version = row.version or "0.0.0"
    local selfFound = row.selfFound == true or row.label == "Self Found"
    return {
        key = key,
        name = name,
        realm = row.realm or "",
        guild = row.guild or "",
        faction = faction,
        class = row.class or "Unknown",
        classId = tonumber(row.classId),
        level = tonumber(row.level) or 0,
        completed = tonumber(row.completed) or 0,
        total = tonumber(row.total) or 0,
        points = tonumber(row.points) or 0,
        label = row.label or "",
        raceId = tonumber(row.raceId),
        sex = tonumber(row.sex),
        selfFound = selfFound,
        dead = row.dead == true,
        offline = offline,
        version = version,
        updatedAt = updatedAt,
        lastSeenSec = lastSeenSec,
        lastSeenText = FormatAgo(lastSeenSec),
        online = not offline and (lastSeenSec <= RECENT_SECONDS),
        _sortName = tostring(name):lower(),
        _sortClass = tostring(classLabel):lower(),
        _sortFaction = tostring(faction):lower(),
        _sortVersion = tostring(version):lower(),
        _sortAchievements = tonumber(row.points) or 0,
        _sortSelfFound = selfFound and 1 or 0,
        _sortUpdated = lastSeenSec,
        _displayClassPortrait = FormatClassPortrait(classLabel, row.raceId, row.sex),
        _displayAchievementColor = GetLeaderboardAchievementColorCode(tonumber(row.completed) or 0, tonumber(row.total) or 0),
    }
end

local function BuildBaseRows(scope, scopeSignature, context)
    if cachedBaseRows and cachedBaseVersion == dataVersion and cachedBaseScopeSignature == scopeSignature then
        UpdateRelativeTimes(cachedBaseRows, Now())
        return cachedBaseRows
    end

    local now = Now()
    local db = Leaderboard:GetDB()
    local rows = {}

    for key, row in pairs(db.rows or {}) do
        if type(row) == "table" and InScope(row, scope, context) then
            rows[#rows + 1] = BuildDisplayRow(key, row, now, db.presence and db.presence[key])
        end
    end

    cachedBaseRows = rows
    cachedBaseVersion = dataVersion
    cachedBaseScopeSignature = scopeSignature
    cachedSortedRows = nil
    cachedRankLabel = nil
    return rows
end

function Data:GetRowByKey(key)
    if not key then
        return nil
    end

    local db = Leaderboard:GetDB()
    local raw = db.rows and db.rows[key]
    if type(raw) ~= "table" then
        return nil
    end

    local scope = Leaderboard:GetScope()
    local context = BuildScopeContext()
    if not InScope(raw, scope, context) then
        return nil
    end

    local row = BuildDisplayRow(key, raw, Now(), db.presence and db.presence[key])
    local searchTerm = Leaderboard.GetSearchTerm and Leaderboard:GetSearchTerm() or ""
    if not MatchesSearch(row, searchTerm) then
        return nil
    end
    return row
end

local function SortSignature(sortState, scopeSignature)
    sortState = sortState or {}
    return scopeSignature .. "|" .. tostring(sortState.key or "") .. "|" .. tostring(sortState.asc and 1 or 0)
end

function Data:GetRows(sortState, opts)
    opts = opts or {}
    -- Hot paths (e.g. periodic time-only refresh) can skip prune to avoid even the cheap cooldown check.
    -- PruneStaleLeaderboardRows already has its own 120s internal cooldown, so this is only for micro-optimization.
    if not opts.skipPrune then
        PruneStaleLeaderboardRows()
    end

    local scope = Leaderboard:GetScope()
    local context = BuildScopeContext()
    local scopeSignature = ScopeSignature(scope, context)
    local baseRows = BuildBaseRows(scope, scopeSignature, context)
    local sortSignature = SortSignature(sortState, scopeSignature)
    local sortKey = sortState and sortState.key

    if sortKey and sortKey ~= "updated" and cachedSortedRows and cachedBaseVersion == dataVersion and cachedSortSignature == sortSignature then
        UpdateRelativeTimes(cachedSortedRows, Now())
        return cachedSortedRows
    end

    local searchTerm = Leaderboard.GetSearchTerm and Leaderboard:GetSearchTerm() or ""
    local rows = {}
    for i = 1, #baseRows do
        local row = baseRows[i]
        if MatchesSearch(row, searchTerm) then
            rows[#rows + 1] = row
        end
    end
    SortRows(rows, sortState)

    -- Apply display cap AFTER accurate full sort. This keeps top-N correct for any column
    -- while bounding UI work and memory for huge scopes. The total is attached so the
    -- footer can show "Top 500 of 1,234".
    local total = #rows
    if LEADERBOARD_MAX_DISPLAY_ROWS > 0 and total > LEADERBOARD_MAX_DISPLAY_ROWS then
        for i = LEADERBOARD_MAX_DISPLAY_ROWS + 1, total do
            rows[i] = nil
        end
        rows.totalUntruncated = total
    else
        rows.totalUntruncated = nil
    end

    cachedSortedRows = rows
    cachedSortSignature = sortSignature
    return rows
end

function Data:GetScopeLabel()
    local scope = Leaderboard:GetScope()
    local base
    if not ScopeHasFilters(scope) then
        base = "World"
    else
        local labels = {}
        if scope.guild and GetPlayerGuildNameForScope() then
            labels[#labels + 1] = "Guild"
        end
        if scope.realm then labels[#labels + 1] = "Realm" end
        if scope.faction then labels[#labels + 1] = "Faction" end
        if scope.dead then labels[#labels + 1] = "Dead" end
        base = (#labels == 0) and "World" or table.concat(labels, " + ")
    end

    -- Append (filtered) when a search term is active so the user knows the view is narrowed.
    local term = (Leaderboard.GetSearchTerm and Leaderboard:GetSearchTerm()) or ""
    if term ~= "" then
        base = base .. " (filtered)"
    end
    return base
end

local function SamePointsRankingTier(a, b)
    if a.points ~= b.points then
        return false
    end
    local ca, ta = a.completed, a.total
    local cb, tb = b.completed, b.total
    if ta > 0 and tb > 0 then
        return (ca * tb) == (cb * ta)
    end
    return ta <= 0 and tb <= 0
end

--- Rank label for the local player in the current leaderboard scope (#1 / #T11 / —).
-- When a search filter is active, ranks are computed relative to the filtered set only.
function Data:GetPointsRankLabel()
    PruneStaleLeaderboardRows()

    local scope = Leaderboard:GetScope()
    local context = BuildScopeContext()
    local scopeSignature = ScopeSignature(scope, context)
    local searchTerm = (Leaderboard.GetSearchTerm and Leaderboard:GetSearchTerm()) or ""
    local rankSignature = scopeSignature .. "|" .. searchTerm

    if cachedRankLabel and cachedRankVersion == dataVersion and cachedRankScopeSignature == rankSignature then
        return cachedRankLabel
    end

    local baseRows = BuildBaseRows(scope, scopeSignature, context)
    local entries = {}
    for i = 1, #baseRows do
        entries[i] = baseRows[i]
    end

    if #entries == 0 then
        cachedRankLabel = "—"
        cachedRankVersion = dataVersion
        cachedRankScopeSignature = rankSignature
        return "—"
    end

    table_sort(entries, function(a, b)
        if a.points ~= b.points then
            return a.points > b.points
        end
        local ca, ta = a.completed, a.total
        local cb, tb = b.completed, b.total
        if ta > 0 and tb > 0 then
            local left = ca * tb
            local right = cb * ta
            if left ~= right then
                return left > right
            end
        elseif ta > 0 then
            return true
        elseif tb > 0 then
            return false
        end
        return (a._sortName or tostring(a.name or ""):lower()) < (b._sortName or tostring(b.name or ""):lower())
    end)

    -- If a search term is active, keep only matching rows for ranking purposes.
    -- This makes the displayed rank relative to the filtered leaderboard view.
    if searchTerm ~= "" then
        local filtered = {}
        for i = 1, #entries do
            if MatchesSearch(entries[i], searchTerm) then
                filtered[#filtered + 1] = entries[i]
            end
        end
        entries = filtered
    end

    if #entries == 0 then
        cachedRankLabel = "—"
        cachedRankVersion = dataVersion
        cachedRankScopeSignature = rankSignature
        return "—"
    end

    entries[1].rank = 1
    for i = 2, #entries do
        if SamePointsRankingTier(entries[i], entries[i - 1]) then
            entries[i].rank = entries[i - 1].rank
        else
            entries[i].rank = i
        end
    end

    local countAtRank = {}
    for i = 1, #entries do
        local r = entries[i].rank
        countAtRank[r] = (countAtRank[r] or 0) + 1
    end

    local myKey = GetLocalCharacterKey()
    if not myKey then
        cachedRankLabel = "—"
        cachedRankVersion = dataVersion
        cachedRankScopeSignature = rankSignature
        return "—"
    end

    for i = 1, #entries do
        if entries[i].key == myKey then
            local r = entries[i].rank
            cachedRankVersion = dataVersion
            cachedRankScopeSignature = rankSignature
            if (countAtRank[r] or 0) >= 2 then
                cachedRankLabel = "#T" .. r
                return cachedRankLabel
            end
            cachedRankLabel = "#" .. r
            return cachedRankLabel
        end
    end

    cachedRankLabel = "—"
    cachedRankVersion = dataVersion
    cachedRankScopeSignature = rankSignature
    return "—"
end

-- Lightweight alias for callers that expect a cached variant (minimap tooltip, etc.).
-- GetPointsRankLabel is already internally cached and safe to call frequently.
function Data:GetPointsRankLabelCached()
    return Data:GetPointsRankLabel()
end
