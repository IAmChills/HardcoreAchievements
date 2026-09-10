-- Community completion rates from leaderboard rows that include completedIds (1.9.5+).
-- Cache: achId -> { have, total }, rebuilt when leaderboard player rows change.
local addonName, addon = ...
if not addon then return end

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

local table_insert = table.insert
local table_sort = table.sort
local tostring = tostring
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs

-- First version that publishes completedIds on leaderboard rows.
local MIN_COMPLETION_STATS_VERSION = "1.9.5"

-- Packed wire form: one string instead of a nested id list (LibSerialize-safe on gossip).
local COMPLETED_IDS_SEP = "\031"

-- Vanilla/TBC class file tokens only (Blizzard ids; 6/10 unused here).
local CLASS_FILE_TO_ID = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    DRUID = 11,
}

-- UnitRace raceFile tokens. Race 5 file is "Scourge"; UI/portrait text often says "Undead".
local RACE_ID_TO_FILE = {
    [1] = "Human",
    [2] = "Orc",
    [3] = "Dwarf",
    [4] = "NightElf",
    [5] = "Scourge",
    [6] = "Tauren",
    [7] = "Gnome",
    [8] = "Troll",
    [10] = "BloodElf",
    [11] = "Draenei",
}

local function NormalizeRaceToken(race)
    if type(race) ~= "string" or race == "" then
        return nil
    end
    local lower = race:lower()
    if lower == "undead" or lower == "scourge" then
        return "scourge"
    end
    return lower
end

local cache = {
    byAchId = {},
    version = 0,
}

-- The cache is only read when a tooltip shows a completion rate, so gossip bursts just mark it
-- dirty and the rebuild happens on first read. Rebuilding per incoming row batch was scanning
-- every def against every reporter dozens of times per sync round.
local cacheDirty = true

-- Parsed completedIds keyed by the packed wire string. Most reporters resend an identical
-- string every round, so this keeps rebuilds from re-splitting hundreds of payloads.
local completedSetCache = {}
local completedSetCacheCount = 0
local COMPLETED_SET_CACHE_LIMIT = 2000

-- Normalized eligibility requirements keyed by def table (defs live for the whole session).
local defReqCache = {}

local function ParseVersion(ver)
    if type(ver) ~= "string" or ver == "" or ver == "?" then
        return nil
    end
    local a, b, c = ver:match("^(%d+)%.(%d+)%.(%d+)")
    if not a then
        a, b = ver:match("^(%d+)%.(%d+)")
        c = 0
    end
    if not a then
        return nil
    end
    return (tonumber(a) or 0) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
end

local function VersionAtLeast(ver, minVer)
    local v = ParseVersion(ver)
    local m = ParseVersion(minVer)
    if not v or not m then
        return false
    end
    return v >= m
end

local function BuildCompletedSet(completedIds)
    local set = {}
    if type(completedIds) == "string" then
        local cached = completedSetCache[completedIds]
        if cached then
            return cached
        end
        if completedIds ~= "" then
            local ids = { strsplit(COMPLETED_IDS_SEP, completedIds) }
            for i = 1, #ids do
                local id = ids[i]
                if id and id ~= "" then
                    set[id] = true
                end
            end
        end
        -- Payload strings are stable across rounds, so memoize. Wipe wholesale rather than
        -- tracking LRU order; the cache refills lazily on the next rebuild.
        if completedSetCacheCount >= COMPLETED_SET_CACHE_LIMIT then
            completedSetCache = {}
            completedSetCacheCount = 0
        end
        completedSetCache[completedIds] = set
        completedSetCacheCount = completedSetCacheCount + 1
        return set
    end
    if type(completedIds) ~= "table" then
        return set
    end
    for i = 1, #completedIds do
        local id = completedIds[i]
        if id ~= nil then
            set[tostring(id)] = true
        end
    end
    -- Also accept map-style tables if ever received
    for k, v in pairs(completedIds) do
        if type(k) == "string" and v then
            set[k] = true
        end
    end
    return set
end

local function IsCompletionReporter(row)
    if type(row) ~= "table" then
        return false
    end
    if type(row.completedIds) ~= "table" and type(row.completedIds) ~= "string" then
        return false
    end
    return VersionAtLeast(row.version, MIN_COMPLETION_STATS_VERSION)
end

-- Rows store the UnitFactionGroup english tag; defs often use FACTION_* localized globals.
-- Collapsing both sides to a single key lets the match be a plain equality test.
local function NormalizeFactionKey(faction)
    if type(faction) ~= "string" or faction == "" then
        return nil
    end
    if faction == "Horde" or faction == FACTION_HORDE then
        return "Horde"
    end
    if faction == "Alliance" or faction == FACTION_ALLIANCE then
        return "Alliance"
    end
    return faction
end

-- Precomputed, allocation-free form of a def's faction/class/race gates.
-- impossible marks defs no row can ever satisfy (e.g. a non-string race requirement).
local UNRESTRICTED_REQ = { unrestricted = true }

local function GetDefRequirements(def)
    if type(def) ~= "table" then
        return UNRESTRICTED_REQ
    end
    local req = defReqCache[def]
    if req then
        return req
    end

    req = {}

    if def.faction then
        req.factionKey = NormalizeFactionKey(def.faction)
        if not req.factionKey then
            req.impossible = true
        end
    end

    local class = def.class
    if class then
        local ids, tokens = nil, nil
        local function AddToken(token)
            if type(token) ~= "string" then return end
            local want = token:upper()
            tokens = tokens or {}
            tokens[want] = true
            local id = CLASS_FILE_TO_ID[want]
            if id then
                ids = ids or {}
                ids[id] = true
            end
        end
        if type(class) == "table" then
            for _, token in pairs(class) do
                AddToken(token)
            end
        else
            AddToken(tostring(class))
        end
        req.classIds = ids
        req.classTokens = tokens
        if not ids and not tokens then
            req.impossible = true
        end
    end

    if def.race then
        req.raceWant = NormalizeRaceToken(def.race)
        if not req.raceWant then
            req.impossible = true
        end
    end

    req.unrestricted = not (req.impossible or req.factionKey or req.classTokens or req.raceWant)

    defReqCache[def] = req
    return req
end

-- entry carries the reporter's normalized identity so matching never allocates.
local function ReporterMatches(entry, req)
    if req.factionKey and entry.factionKey ~= req.factionKey then
        return false
    end
    if req.classTokens then
        local byId = req.classIds
        if not (byId and entry.classId and byId[entry.classId]) then
            local token = entry.classToken
            if not (token and req.classTokens[token]) then
                return false
            end
        end
    end
    local raceWant = req.raceWant
    if raceWant and entry.raceFromId ~= raceWant and entry.raceFromName ~= raceWant then
        return false
    end
    return true
end

function Leaderboard.RebuildCompletionStatsCache()
    local byAchId = {}
    local reporters = {}
    local root = Leaderboard.GetDB and Leaderboard:GetDB()
    local rows = root and root.rows or {}

    for _, row in pairs(rows) do
        if IsCompletionReporter(row) then
            local classToken = row.class
            local raceId = tonumber(row.raceId)
            local raceFile = raceId and RACE_ID_TO_FILE[raceId]
            reporters[#reporters + 1] = {
                set = BuildCompletedSet(row.completedIds),
                factionKey = NormalizeFactionKey(row.faction),
                classId = tonumber(row.classId),
                classToken = type(classToken) == "string" and classToken:upper() or nil,
                raceFromId = raceFile and NormalizeRaceToken(raceFile) or nil,
                raceFromName = NormalizeRaceToken(row.race),
            }
        end
    end

    local reporterCount = #reporters
    local defs = (addon and addon.AchievementDefs) or {}
    for achId, def in pairs(defs) do
        local idKey = tostring(achId)
        local req = GetDefRequirements(def)
        local have, total = 0, 0
        if req.impossible then
            -- No row can satisfy this def; leave the tally empty so the tooltip omits the line.
        elseif req.unrestricted then
            total = reporterCount
            for i = 1, reporterCount do
                if reporters[i].set[idKey] then
                    have = have + 1
                end
            end
        else
            for i = 1, reporterCount do
                local entry = reporters[i]
                if ReporterMatches(entry, req) then
                    total = total + 1
                    if entry.set[idKey] then
                        have = have + 1
                    end
                end
            end
        end
        byAchId[idKey] = { have = have, total = total }
    end

    -- Achievements present in payloads but not in local defs still get a global (unfiltered)
    -- tally. Counting in one pass avoids rescanning every reporter per orphan id.
    local orphanCounts
    for i = 1, reporterCount do
        for achId in pairs(reporters[i].set) do
            if byAchId[achId] == nil then
                orphanCounts = orphanCounts or {}
                orphanCounts[achId] = (orphanCounts[achId] or 0) + 1
            end
        end
    end
    if orphanCounts then
        for achId, have in pairs(orphanCounts) do
            byAchId[achId] = { have = have, total = reporterCount }
        end
    end

    cache.byAchId = byAchId
    cache.version = cache.version + 1
    cacheDirty = false
end

--- Marks the cache stale. The rebuild itself is deferred to the next read, since incoming
--- gossip rows arrive in chunks and nothing consumes these stats unless a tooltip is shown.
function Leaderboard.ScheduleCompletionStatsRebuild()
    cacheDirty = true
end

--- Returns have, total for an achievement among eligible known reporters.
function Leaderboard.GetAchievementCompletionStats(achId)
    if not achId then
        return 0, 0
    end
    if cacheDirty or cache.version == 0 then
        Leaderboard.RebuildCompletionStatsCache()
    end
    local entry = cache.byAchId[tostring(achId)]
    if not entry then
        return 0, 0
    end
    return entry.have or 0, entry.total or 0
end

function Leaderboard.GetCompletionStatsCacheVersion()
    return cache.version
end

-- Build sorted completed ID list from the local character DB.
function Leaderboard.BuildLocalCompletedIds()
    local ids = {}
    if not (addon and type(addon.GetCharDB) == "function") then
        return ids
    end
    local _, cdb = addon.GetCharDB()
    local achievements = cdb and cdb.achievements
    if type(achievements) ~= "table" then
        return ids
    end
    for achId, rec in pairs(achievements) do
        if type(rec) == "table" and rec.completed then
            table_insert(ids, tostring(achId))
        end
    end
    table_sort(ids)
    return ids
end

function Leaderboard.PackCompletedIds(ids)
    if type(ids) == "string" then
        return ids
    end
    if type(ids) ~= "table" then
        return ""
    end
    local list = {}
    if #ids > 0 then
        for i = 1, #ids do
            local id = ids[i]
            if id ~= nil and id ~= "" then
                list[#list + 1] = tostring(id)
            end
        end
    else
        for k, v in pairs(ids) do
            if type(k) == "string" and k ~= "" and v then
                list[#list + 1] = k
            end
        end
        table_sort(list)
    end
    return table.concat(list, COMPLETED_IDS_SEP)
end

function Leaderboard.CompletedIdsEqual(a, b)
    if a == b then
        return true
    end
    local pack = Leaderboard.PackCompletedIds
    if pack then
        return pack(a) == pack(b)
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

if addon then
    addon.GetAchievementCompletionStats = function(achId)
        return Leaderboard.GetAchievementCompletionStats(achId)
    end
end
