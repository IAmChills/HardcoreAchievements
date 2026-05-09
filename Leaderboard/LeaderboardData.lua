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
local math_floor = math.floor
local table_sort = table.sort
local time = time

local RECENT_SECONDS = 10 * 60

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

local function ScopeHasFilters(scope)
    return scope and (scope.guild or scope.realm or scope.faction)
end

local function InScope(row, scope)
    if not ScopeHasFilters(scope) then
        return true
    end

    if scope.guild and (row.guild or "") ~= (GetGuildInfo("player") or "") then
        return false
    end
    if scope.realm and (row.realm or "") ~= (GetRealmName() or "") then
        return false
    end
    if scope.faction and (row.faction or "") ~= (UnitFactionGroup("player") or "") then
        return false
    end
    return true
end

local function ValueForSort(row, key)
    if key == "updated" then
        return tonumber(row.lastSeenSec) or math.huge
    elseif key == "name" or key == "class" or key == "faction" or key == "version" then
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
                level = tonumber(row.level) or 0,
                completed = tonumber(row.completed) or 0,
                total = tonumber(row.total) or 0,
                points = tonumber(row.points) or 0,
                label = row.label or "",
                selfFound = row.selfFound == true or row.label == "Self Found",
                dead = row.dead == true,
                version = row.version or "0.0.0",
                updatedAt = updatedAt,
                lastSeenSec = lastSeenSec,
                lastSeenText = FormatAgo(lastSeenSec),
                online = lastSeenSec <= RECENT_SECONDS,
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
    if scope.guild then labels[#labels + 1] = "Guild" end
    if scope.realm then labels[#labels + 1] = "Realm" end
    if scope.faction then labels[#labels + 1] = "Faction" end
    return table.concat(labels, " + ")
end
