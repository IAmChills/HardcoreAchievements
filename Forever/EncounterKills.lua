local addonName, addon = ...

-- =========================================================
-- Dungeon boss credit from ENCOUNTER_END (Forever)
--
-- Inside instances creature GUIDs can be secret, so PARTY_KILL and UNIT_DIED cannot name the boss.
-- ENCOUNTER_END (12.0.7+) carries encounterUnitStatus, whose creatureID and remainingHealthPercent are
-- documented as ordinary numbers. A successful encounter credits each tracked creature that ended at
-- 0 health. Eligibility stays in the dungeon kill tracker: the player's own level, party size, and the
-- existing average-party-level snapshot. Participation and solo state are not consulted.
--
-- Raid rows have no kill tracker; they continue to complete from BOSS_KILL.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local IsSecret = addon.IsSecretValue
local loggedMissingPayload = false

local function KillLog(message)
    if not addon.ForeverKillDebug then
        return
    end
    print("|cff008066[HCA Kills]|r " .. message)
    if addon.EventLogAdd then
        addon.EventLogAdd("[Kills] " .. message)
    end
end

local tracker = CreateFrame("Frame")
local registered = pcall(tracker.RegisterEvent, tracker, "ENCOUNTER_END")
addon.Restrictions.encounterEndEvent = registered and true or false

tracker:SetScript("OnEvent", function(_, _, encounterID, _, _, _, success, encounterUnitStatus)
    if IsSecret(success) or success ~= 1 then
        return
    end
    if issecrettable and issecrettable(encounterUnitStatus) then
        return
    end
    if canaccesstable and not canaccesstable(encounterUnitStatus) then
        return
    end
    if type(encounterUnitStatus) ~= "table" then
        if not loggedMissingPayload then
            loggedMissingPayload = true
            local message = "ENCOUNTER_END has no encounterUnitStatus; dungeon bosses cannot be credited by encounter id on this client"
            KillLog(message)
            if addon.EventLogAdd then
                addon.EventLogAdd(message)
            end
        end
        return
    end

    for _, entry in ipairs(encounterUnitStatus) do
        if type(entry) == "table" then
            local creatureID = entry.creatureID
            local health = entry.remainingHealthPercent
            if not IsSecret(creatureID) and not IsSecret(health) then
                creatureID = tonumber(creatureID)
                health = tonumber(health)
                if creatureID and health == 0
                    and addon.IsNpcTrackedForAchievement and addon.IsNpcTrackedForAchievement(creatureID)
                    and addon.AwardKillFromEncounter then
                    KillLog("ENCOUNTER_END encounter " .. tostring(encounterID) .. " creature " .. tostring(creatureID))
                    addon.AwardKillFromEncounter(encounterID, creatureID)
                end
            end
        end
    end
end)
