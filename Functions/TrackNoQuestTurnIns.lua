---------------------------------------
-- Bloodbath tracking
---------------------------------------
local ACH_ID = "NoQuestTurnInChallenge"

local _, addon = ...
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local CreateFrame = CreateFrame

local function FailBloodbathIfNeeded(cdb, refreshUI)
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

-- playerQuestTurnIns:
--   nil = not yet verified eligible
--   0   = eligible run in progress
--   >0  = failed
local function SyncBloodbathState(cdb, refreshOnFail, event)
    if not cdb then return end

    cdb.stats = cdb.stats or {}
    local rec = cdb.achievements and cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        return
    end

    local turnIns = cdb.stats.playerQuestTurnIns
    local level = UnitLevel("player") or 1
    local xp = UnitXP("player") or 0

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if turnIns ~= nil then
            if turnIns > 0 then
                FailBloodbathIfNeeded(cdb, refreshOnFail)
            end
            return
        end

        if level == 1 and xp == 0 then
            cdb.stats.playerQuestTurnIns = 0
        else
            -- Installed after run start; cannot verify no prior turn-ins.
            FailBloodbathIfNeeded(cdb, refreshOnFail)
        end
        return
    end

    if event == "QUEST_TURNED_IN" then
        if turnIns == nil then
            if level == 1 and xp == 0 then
                turnIns = 0
            else
                FailBloodbathIfNeeded(cdb, refreshOnFail)
                return
            end
        end

        cdb.stats.playerQuestTurnIns = (turnIns or 0) + 1
        if cdb.stats.playerQuestTurnIns > 0 then
            FailBloodbathIfNeeded(cdb, refreshOnFail)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_TURNED_IN")

local function UpdateEventRegistration(cdb)
    if not cdb then return end
    cdb.achievements = cdb.achievements or {}
    cdb.stats = cdb.stats or {}

    local rec = cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        f:UnregisterEvent("QUEST_TURNED_IN")
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        return
    end

    -- Once initialized, no need to re-check on zoning.
    if cdb.stats.playerQuestTurnIns ~= nil then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

f:SetScript("OnEvent", function(_, event)
    if not (addon and addon.GetCharDB) then
        return
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return
    end

    SyncBloodbathState(cdb, event ~= "PLAYER_LOGIN", event)
    UpdateEventRegistration(cdb)
end)
