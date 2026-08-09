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

local rebuildPending = false

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
    if type(row.completedIds) ~= "table" then
        return false
    end
    return VersionAtLeast(row.version, MIN_COMPLETION_STATS_VERSION)
end

local function FactionMatches(rowFaction, required)
    if not required then
        return true
    end
    if type(rowFaction) ~= "string" or rowFaction == "" then
        return false
    end
    if rowFaction == required then
        return true
    end
    -- Row stores UnitFactionGroup english tag; defs often use FACTION_* localized globals.
    if required == "Horde" or required == FACTION_HORDE then
        return rowFaction == "Horde" or rowFaction == FACTION_HORDE
    end
    if required == "Alliance" or required == FACTION_ALLIANCE then
        return rowFaction == "Alliance" or rowFaction == FACTION_ALLIANCE
    end
    return false
end

local function ClassMatches(row, required)
    if not required then
        return true
    end
    local want = tostring(required):upper()
    local classId = tonumber(row.classId)
    if classId and CLASS_FILE_TO_ID[want] == classId then
        return true
    end
    -- Fallback: english display name on row ("Mage") vs file token ("MAGE")
    local className = row.class
    if type(className) == "string" and className:upper() == want then
        return true
    end
    return false
end

local function RaceMatches(row, required)
    if not required then
        return true
    end
    local want = NormalizeRaceToken(required)
    if not want then
        return false
    end
    local raceId = tonumber(row.raceId)
    local raceFile = raceId and RACE_ID_TO_FILE[raceId]
    if raceFile and NormalizeRaceToken(raceFile) == want then
        return true
    end
    -- Catalog IsEligible also allows localized raceName (e.g. "Undead"); accept row.race if present.
    if row.race and NormalizeRaceToken(row.race) == want then
        return true
    end
    return false
end

local function RowMatchesAchievementDef(row, def)
    if not def then
        return true
    end
    if not FactionMatches(row.faction, def.faction) then
        return false
    end
    if not ClassMatches(row, def.class) then
        return false
    end
    if not RaceMatches(row, def.race) then
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
            reporters[#reporters + 1] = {
                row = row,
                set = BuildCompletedSet(row.completedIds),
            }
        end
    end

    local defs = (addon and addon.AchievementDefs) or {}
    for achId, def in pairs(defs) do
        local idKey = tostring(achId)
        local have, total = 0, 0
        for i = 1, #reporters do
            local entry = reporters[i]
            if RowMatchesAchievementDef(entry.row, def) then
                total = total + 1
                if entry.set[idKey] then
                    have = have + 1
                end
            end
        end
        byAchId[idKey] = { have = have, total = total }
    end

    -- Achievements present in payloads but not in local defs still get a global (unfiltered) tally
    for i = 1, #reporters do
        local entry = reporters[i]
        for achId in pairs(entry.set) do
            if not byAchId[achId] then
                local have, total = 0, #reporters
                for j = 1, #reporters do
                    if reporters[j].set[achId] then
                        have = have + 1
                    end
                end
                byAchId[achId] = { have = have, total = total }
            end
        end
    end

    cache.byAchId = byAchId
    cache.version = cache.version + 1
    rebuildPending = false
end

function Leaderboard.ScheduleCompletionStatsRebuild()
    if rebuildPending then
        return
    end
    rebuildPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function()
            if rebuildPending then
                Leaderboard.RebuildCompletionStatsCache()
            end
        end)
    else
        Leaderboard.RebuildCompletionStatsCache()
    end
end

--- Returns have, total for an achievement among eligible known reporters.
function Leaderboard.GetAchievementCompletionStats(achId)
    if not achId then
        return 0, 0
    end
    if cache.version == 0 then
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

function Leaderboard.CompletedIdsEqual(a, b)
    if a == b then
        return true
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
