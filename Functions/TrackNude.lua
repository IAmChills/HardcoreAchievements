---------------------------------------
-- NoArmorChallenge tracking
---------------------------------------
local ACH_ID = "NoArmorChallenge"

local _, addon = ...
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local GetInventoryItemID = GetInventoryItemID
local CreateFrame = CreateFrame

local function HasAnyEquippedItem()
    for slot = 0, 19 do
        if GetInventoryItemID("player", slot) ~= nil then
            return true
        end
    end
    return false
end

local function FailNoArmorChallengeIfNeeded(cdb, refreshUI)
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

local function MarkNoArmorFailure(cdb, refreshUI)
    cdb.stats = cdb.stats or {}
    cdb.stats.playerNude = true
    cdb.stats.playerNudeArmed = true
    FailNoArmorChallengeIfNeeded(cdb, refreshUI)
end

-- playerNude:
--   nil   = not yet verified eligible
--   false = eligible run in progress
--   true  = failed
--
-- playerNudeArmed:
--   nil/false = first XP not yet verified
--   true      = first XP verified clean; equipment changes can now fail it
local function SyncNoArmorState(cdb, refreshOnFail, event, slot, hasCurrent)
    if not cdb then return end

    cdb.stats = cdb.stats or {}
    local rec = cdb.achievements and cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        return
    end

    local state = cdb.stats.playerNude
    local armed = cdb.stats.playerNudeArmed == true
    local level = UnitLevel("player") or 1
    local xp = UnitXP("player") or 0

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if armed then
            return
        end
        if level == 1 and xp == 0 and not HasAnyEquippedItem() then
            cdb.stats.playerNude = false
            cdb.stats.playerNudeArmed = false
        elseif level > 1 or xp > 0 then
            FailNoArmorChallengeIfNeeded(cdb, refreshOnFail)
        end
        return
    end

    if event == "PLAYER_XP_UPDATE" then
        if armed or xp <= 0 then
            return
        end
        if HasAnyEquippedItem() then
            MarkNoArmorFailure(cdb, refreshOnFail)
        else
            cdb.stats.playerNude = false
            cdb.stats.playerNudeArmed = true
        end
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if not armed or state ~= false then
            return
        end
        if type(slot) == "number" and slot >= 0 and slot <= 19 and hasCurrent == false then
            MarkNoArmorFailure(cdb, refreshOnFail)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not (addon and addon.GetCharDB) then
        return
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return
    end

    SyncNoArmorState(cdb, event ~= "PLAYER_LOGIN", event, arg1, arg2)

    if addon.EvaluateCustomCompletions then
        addon.EvaluateCustomCompletions()
    end
end)
