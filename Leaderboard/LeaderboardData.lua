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

local RECENT_SECONDS = 5 * 60
-- Drop other players' rows with no heartbeat for this long (UI + saved DB cleanup).
local STALE_ROW_SECONDS = 7 * 86400
-- Avoid pruning work on every GetRows refresh.
local PRUNE_COOLDOWN_SECONDS = 120
local lastPruneAt = 0

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

local function FormatAgo(seconds)
    if not seconds or seconds < 0 then return "?" end
    if seconds < 5 then return "now" end
    if seconds < 60 then return ("%ds"):format(math_floor(seconds)) end
    local minutes = math_floor(seconds / 60)
    if minutes < 60 then return ("%dm"):format(minutes) end
    local hours = math_floor(seconds / 3600)
    if hours < 48 then return ("%dh"):format(hours) end
    return ("%dd"):format(math_floor(seconds / 86400))
end

local function GetLocalCharacterKey()
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

    local toDrop = {}
    for key, row in pairs(rows) do
        if type(row) == "table" and key ~= localKey then
            local updatedAt = tonumber(row.updatedAt) or 0
            if updatedAt > 0 and (now - updatedAt) > STALE_ROW_SECONDS then
                toDrop[#toDrop + 1] = key
            end
        end
    end

    if #toDrop == 0 then
        return
    end

    for _, key in ipairs(toDrop) do
        if LibP2PDB and pdb and tableName then
            pcall(function()
                LibP2PDB:DeleteKey(pdb, tableName, key)
                LibP2PDB:BroadcastKey(pdb, tableName, key)
            end)
        else
            rows[key] = nil
        end
    end

    if sync and sync.Persist then
        sync:Persist()
    end
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

local function InScope(row, scope)
    if not ScopeHasFilters(scope) then
        return true
    end

    -- Guild filter only applies when the viewer is in a guild; otherwise it would match every guildless row.
    if scope.guild then
        local playerGuild = GetPlayerGuildNameForScope()
        if playerGuild then
            local rowGuild = (type(row.guild) == "string" and row.guild ~= "") and row.guild or ""
            if rowGuild ~= playerGuild then
                return false
            end
        end
    end
    if scope.realm and (row.realm or "") ~= (GetRealmName() or "") then
        return false
    end
    if scope.faction and (row.faction or "") ~= (UnitFactionGroup("player") or "") then
        return false
    end
    if scope.dead and row.dead ~= true then
        return false
    end
    return true
end

local function ValueForSort(row, key)
    if key == "updated" then
        return tonumber(row.lastSeenSec) or math.huge
    elseif key == "class" then
        -- Prefer English from classId; fallback to synced class string (legacy rows).
        local label = row.class or "Unknown"
        if Leaderboard.GetEnglishClassName then
            label = Leaderboard.GetEnglishClassName(row.classId, label)
        end
        return tostring(label):lower()
    elseif key == "name" or key == "faction" or key == "version" then
        return tostring(row[key] or ""):lower()
    elseif key == "achievements" then
        return tonumber(row.points) or 0
    elseif key == "selfFound" then
        return row.selfFound and 1 or 0
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
        return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
    end)
end

function Data:GetRows(sortState)
    PruneStaleLeaderboardRows()

    local db = Leaderboard:GetDB()
    local scope = Leaderboard:GetScope()
    local rows = {}
    local now = Now()

    for key, row in pairs(db.rows or {}) do
        if type(row) == "table" and InScope(row, scope) then
            local updatedAt = tonumber(row.updatedAt) or 0
            local lastSeenSec = math.max(0, now - updatedAt)
            rows[#rows + 1] = {
                key = key,
                name = row.name or key,
                realm = row.realm or "",
                guild = row.guild or "",
                faction = row.faction or "",
                class = row.class or "Unknown",
                classId = tonumber(row.classId),
                level = tonumber(row.level) or 0,
                completed = tonumber(row.completed) or 0,
                total = tonumber(row.total) or 0,
                points = tonumber(row.points) or 0,
                label = row.label or "",
                raceId = tonumber(row.raceId),
                sex = tonumber(row.sex),
                selfFound = row.selfFound == true or row.label == "Self Found",
                dead = row.dead == true,
                offline = row.offline == true,
                version = row.version or "0.0.0",
                updatedAt = updatedAt,
                lastSeenSec = lastSeenSec,
                lastSeenText = FormatAgo(lastSeenSec),
                online = (row.offline ~= true) and (lastSeenSec <= RECENT_SECONDS),
            }
        end
    end

    SortRows(rows, sortState)
    return rows
end

function Data:GetScopeLabel()
    local scope = Leaderboard:GetScope()
    if not ScopeHasFilters(scope) then
        return "World"
    end

    local labels = {}
    if scope.guild and GetPlayerGuildNameForScope() then
        labels[#labels + 1] = "Guild"
    end
    if scope.realm then labels[#labels + 1] = "Realm" end
    if scope.faction then labels[#labels + 1] = "Faction" end
    if scope.dead then labels[#labels + 1] = "Dead" end
    if #labels == 0 then
        return "World"
    end
    return table.concat(labels, " + ")
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
function Data:GetPointsRankLabel()
    PruneStaleLeaderboardRows()

    local db = Leaderboard:GetDB()
    local scope = Leaderboard:GetScope()
    local entries = {}

    for key, row in pairs(db.rows or {}) do
        if type(row) == "table" and InScope(row, scope) then
            entries[#entries + 1] = {
                key = key,
                points = tonumber(row.points) or 0,
                completed = tonumber(row.completed) or 0,
                total = tonumber(row.total) or 0,
                name = tostring(row.name or key),
            }
        end
    end

    if #entries == 0 then
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
        return string.lower(a.name) < string.lower(b.name)
    end)

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
        return "—"
    end

    for i = 1, #entries do
        if entries[i].key == myKey then
            local r = entries[i].rank
            if (countAtRank[r] or 0) >= 2 then
                return "#T" .. r
            end
            return "#" .. r
        end
    end

    return "—"
end
