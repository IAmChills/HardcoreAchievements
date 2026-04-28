---------------------------------------
-- NoWeaponChallenge tracking
---------------------------------------
local ACH_ID = "NoWeaponChallenge"
local SLOT_MAINHAND = INVSLOT_MAINHAND or 16
local SLOT_OFFHAND = INVSLOT_OFFHAND or 17
local SLOT_RANGED = INVSLOT_RANGED or 18

local _, addon = ...
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local GetInventoryItemID = GetInventoryItemID
local CreateFrame = CreateFrame

local function HasWeaponInHandSlots()
    return GetInventoryItemID("player", SLOT_MAINHAND) ~= nil
        or GetInventoryItemID("player", SLOT_OFFHAND) ~= nil
        or GetInventoryItemID("player", SLOT_RANGED) ~= nil
end

local function FailNoWeaponChallengeIfNeeded(cdb, refreshUI)
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

local function MarkNoWeaponFailure(cdb, refreshUI)
    cdb.stats = cdb.stats or {}
    cdb.stats.playerWeapons = true
    cdb.stats.playerWeaponsArmed = true
    FailNoWeaponChallengeIfNeeded(cdb, refreshUI)
end

-- playerWeapons:
--   nil   = not yet verified eligible
--   false = eligible run in progress
--   true  = failed
--
-- playerWeaponsArmed:
--   nil/false = first XP not yet verified
--   true      = first XP verified clean; equipment changes can now fail it
local function SyncNoWeaponState(cdb, refreshOnFail, event, slot, hasCurrent)
    if not cdb then return end

    cdb.stats = cdb.stats or {}
    local rec = cdb.achievements and cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        return
    end

    local state = cdb.stats.playerWeapons
    local armed = cdb.stats.playerWeaponsArmed == true
    local level = UnitLevel("player") or 1
    local xp = UnitXP("player") or 0

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if armed then
            return
        end
        if level == 1 and xp == 0 and not HasWeaponInHandSlots() then
            cdb.stats.playerWeapons = false
            cdb.stats.playerWeaponsArmed = false
        elseif level > 1 or xp > 0 then
            FailNoWeaponChallengeIfNeeded(cdb, refreshOnFail)
        end
        return
    end

    if event == "PLAYER_XP_UPDATE" then
        if armed or xp <= 0 then
            return
        end
        if HasWeaponInHandSlots() then
            MarkNoWeaponFailure(cdb, refreshOnFail)
        else
            cdb.stats.playerWeapons = false
            cdb.stats.playerWeaponsArmed = true
        end
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if not armed or state ~= false then
            return
        end
        if (slot == SLOT_MAINHAND or slot == SLOT_OFFHAND) and hasCurrent == false then
            MarkNoWeaponFailure(cdb, refreshOnFail)
        end
    end
end

local f = CreateFrame("Frame")

local function UpdateXPEventRegistration(cdb)
    if not cdb then return end
    cdb.achievements = cdb.achievements or {}
    local rec = cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        f:UnregisterEvent("PLAYER_XP_UPDATE")
        return
    end
    if cdb.stats and cdb.stats.playerWeaponsArmed == true then
        f:UnregisterEvent("PLAYER_XP_UPDATE")
        return
    end
    f:RegisterEvent("PLAYER_XP_UPDATE")
end

local function UpdateEventRegistration(cdb)
    if not cdb then return end
    cdb.achievements = cdb.achievements or {}
    cdb.stats = cdb.stats or {}

    local rec = cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        f:UnregisterEvent("PLAYER_XP_UPDATE")
        f:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        return
    end

    -- Initialization only needs to happen once.
    if cdb.stats.playerWeapons ~= nil then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not (addon and addon.GetCharDB) then
        return
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return
    end

    SyncNoWeaponState(cdb, event ~= "PLAYER_LOGIN", event, arg1, arg2)
    UpdateXPEventRegistration(cdb)
    UpdateEventRegistration(cdb)
end)
