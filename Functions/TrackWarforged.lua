---------------------------------------
-- Warforged tracking
---------------------------------------
local ACH_ID = "PVPChallenge"

local _, addon = ...
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitIsPVP = UnitIsPVP
local CreateFrame = CreateFrame

local function FailWarforgedIfNeeded(cdb, refreshUI)
    if not cdb then return end

    cdb.achievements = cdb.achievements or {}
    local rec = cdb.achievements[ACH_ID]
    if not rec or (not rec.completed and not rec.failed) then
        if addon and addon.EnsureFailureTimestamp then
            addon.EnsureFailureTimestamp(ACH_ID)
            if refreshUI and addon.RefreshOutleveledAll then
                addon.RefreshOutleveledAll()
            end
        end
    end
end

-- playerWarforgedPvpDropped:
--   nil   = not yet verified eligible
--   false = eligible run in progress
--   true  = failed (pvp flag dropped)
local function SyncWarforgedState(cdb, refreshOnFail, event, unit)
    if not cdb then return end

    cdb.stats = cdb.stats or {}
    local rec = cdb.achievements and cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        return
    end

    local state = cdb.stats.playerWarforgedPvpDropped
    local level = UnitLevel("player") or 1
    local xp = UnitXP("player") or 0
    local isPvpNow = UnitIsPVP("player") == true

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if state == nil then
            if level == 1 and xp == 0 and isPvpNow then
                cdb.stats.playerWarforgedPvpDropped = false
            else
                -- Installed after run start or run started unflagged.
                FailWarforgedIfNeeded(cdb, refreshOnFail)
            end
            return
        end

        if state == false and not isPvpNow then
            cdb.stats.playerWarforgedPvpDropped = true
            FailWarforgedIfNeeded(cdb, refreshOnFail)
        end
        return
    end

    if event == "PLAYER_FLAGS_CHANGED" then
        if unit ~= "player" then
            return
        end

        if state == nil then
            if level == 1 and xp == 0 and isPvpNow then
                cdb.stats.playerWarforgedPvpDropped = false
            else
                FailWarforgedIfNeeded(cdb, refreshOnFail)
            end
            return
        end

        -- Only fail when the flag is truly off (not when it is pending off during the 5-minute timer).
        if state == false and not isPvpNow then
            cdb.stats.playerWarforgedPvpDropped = true
            FailWarforgedIfNeeded(cdb, refreshOnFail)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")

local function UpdateEventRegistration(cdb)
    if not cdb then return end
    cdb.achievements = cdb.achievements or {}
    cdb.stats = cdb.stats or {}

    local rec = cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        f:UnregisterEvent("PLAYER_FLAGS_CHANGED")
        return
    end

    -- Initialization only needs to happen once.
    if cdb.stats.playerWarforgedPvpDropped ~= nil then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

f:SetScript("OnEvent", function(_, event, arg1)
    if not (addon and addon.GetCharDB) then
        return
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return
    end

    SyncWarforgedState(cdb, event ~= "PLAYER_LOGIN", event, arg1)
    UpdateEventRegistration(cdb)
end)
