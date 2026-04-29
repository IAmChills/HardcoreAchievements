-- Troubleshooting log: plain text lines with timestamps, persisted per character:
-- HardcoreAchievementsDB.chars[playerGUID].eventLogLines (SavedVariables).
-- View: Dashboard → "Log" tab (no standalone window).
local addonName, addon = ...
if not addon then return end

local date = date
local tostring = tostring
local CreateFrame = CreateFrame
local UnitName = UnitName
local table_concat = table.concat
local table_remove = table.remove

local MAX_LINES = 100

-- Session line: logged once at PLAYER_LOGIN.
-- Avoid PLAYER_ENTERING_WORLD/PLAYER_LOGOUT noise from relogs, reloads, and zoning.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if addon.EventLogAdd then
            addon.EventLogAdd("Session started")
        end
    end
end)

local function ensureGlobalDb()
    if type(HardcoreAchievementsDB) ~= "table" then
        HardcoreAchievementsDB = {}
    end
    addon.HardcoreAchievementsDB = HardcoreAchievementsDB
    return HardcoreAchievementsDB
end

-- One-time: old builds stored eventLogLines on the root DB; move into current character when empty.
local function migrateGlobalEventLogToChar(db, cdb)
    if not (db and cdb) then
        return
    end
    local g = db.eventLogLines
    if type(g) ~= "table" or #g == 0 then
        return
    end
    local c = cdb.eventLogLines
    if type(c) == "table" and #c > 0 then
        db.eventLogLines = nil
        return
    end
    cdb.eventLogLines = {}
    for i = 1, #g do
        cdb.eventLogLines[i] = g[i]
    end
    db.eventLogLines = nil
end

local function migratePreLoginEventLogToChar(cdb)
    if not cdb then
        return
    end

    local preLoginLines = addon._hcaEventLogLinesPreLogin
    if type(preLoginLines) ~= "table" or #preLoginLines == 0 then
        return
    end

    cdb.eventLogLines = cdb.eventLogLines or {}
    for i = 1, #preLoginLines do
        cdb.eventLogLines[#cdb.eventLogLines + 1] = preLoginLines[i]
    end
    addon._hcaEventLogLinesPreLogin = nil
end

local function getEventLogLines()
    ensureGlobalDb()
    if type(addon.GetCharDB) == "function" then
        local db, cdb = addon.GetCharDB()
        if cdb then
            migrateGlobalEventLogToChar(db, cdb)
            migratePreLoginEventLogToChar(cdb)
            cdb.eventLogLines = cdb.eventLogLines or {}
            return cdb.eventLogLines
        end
    end
    -- Before player GUID exists (very early load): ephemeral only; normal play uses char table above.
    addon._hcaEventLogLinesPreLogin = addon._hcaEventLogLinesPreLogin or {}
    return addon._hcaEventLogLinesPreLogin
end

local function formatLine(msg)
    local ver
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif GetAddOnMetadata then
        ver = GetAddOnMetadata(addonName, "Version")
    end
    if not ver or ver == "" then
        ver = "?"
    end
    return date("[%Y-%m-%d %H:%M:%S][v" .. ver .. "] ") .. tostring(msg)
end

function addon.EventLogAdd(msg)
    if not msg or msg == "" then return end
    local t = getEventLogLines()
    addon.eventLogLines = t
    t[#t + 1] = formatLine(msg)
    while #t > MAX_LINES do
        table_remove(t, 1)
    end
    if addon.RefreshDashboardEventLog then
        addon.RefreshDashboardEventLog()
    end
end

--[[ Clear disabled for now (retain history for debugging).
function addon.EventLogClear()
    local t = getEventLogLines()
    wipe(t)
    addon.eventLogLines = t
    if addon.RefreshDashboardEventLog then
        addon.RefreshDashboardEventLog()
    end
end
--]]

function addon.EventLogGetText()
    return table_concat(getEventLogLines(), "\n")
end

function addon.EventLogShow()
    addon.eventLogLines = getEventLogLines()
    if not addon.ShowDashboard then return end
    addon._hcaOpenDashboardTabKey = "log"
    addon.ShowDashboard()
end
