local addonName, addon = ...

-- =========================================================
-- /hca probe and /hca killdebug (Forever)
--
-- Prints what this client actually exposes right now: event registration, restriction state, and the
-- secrecy of the values kill tracking depends on. Nothing here is compared, persisted, or used to award.
-- =========================================================

if not (addon and addon.Restrictions and addon.Restrictions.combatLog) then
    return
end

local IsSecret = addon.IsSecretValue

local function Describe(value)
    if IsSecret(value) then
        return "secret " .. type(value)
    end
    if value == nil then
        return "nil"
    end
    return type(value) .. "=" .. tostring(value)
end

local function Line(text)
    print("|cff008066[HCA Probe]|r " .. text)
    if addon.EventLogAdd then
        addon.EventLogAdd("[Probe] " .. text)
    end
end

local function RestrictionState(name, enumValue)
    if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive) or enumValue == nil then
        Line(name .. " restriction: API unavailable")
        return
    end
    local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, enumValue)
    Line(name .. " restriction: " .. (ok and Describe(active) or "call failed"))
end

function addon.RunForeverProbe()
    local inInstance, instanceType = IsInInstance()
    Line("instance=" .. tostring(inInstance) .. " type=" .. tostring(instanceType))
    Line("PARTY_KILL registered=" .. tostring(addon.Restrictions.partyKillEvent)
        .. " ENCOUNTER_END registered=" .. tostring(addon.Restrictions.encounterEndEvent))

    local restriction = Enum and Enum.AddOnRestrictionType
    RestrictionState("Combat", restriction and restriction.Combat)
    RestrictionState("Encounter", restriction and restriction.Encounter)
    RestrictionState("Map", restriction and restriction.Map)
    RestrictionState("Chat", restriction and restriction.Chat)

    if not UnitExists("target") then
        Line("no target")
        return
    end

    local guid = UnitGUID("target")
    Line("target GUID " .. Describe(guid))
    if type(guid) == "string" and not IsSecret(guid) then
        Line("target npcId=" .. tostring(addon.ParseCreatureNpcId(guid)))
    end
    Line("UnitIsTapDenied " .. Describe(UnitIsTapDenied and UnitIsTapDenied("target")))
    Line("UnitInRange " .. Describe(UnitInRange and UnitInRange("target")))
    Line("UnitAffectingCombat " .. Describe(UnitAffectingCombat("target")))
    Line("UnitIsDead " .. Describe(UnitIsDead("target")))

    local function Threat(label, unit, mob)
        if not UnitExists(unit) then
            Line(label .. " (unit missing)")
            return
        end
        if C_Secrets and C_Secrets.ShouldUnitThreatValuesBeSecret then
            local ok, secret = pcall(C_Secrets.ShouldUnitThreatValuesBeSecret, unit, mob)
            Line(label .. " values-should-be-secret " .. (ok and Describe(secret) or "call failed"))
        end
        if UnitThreatSituation then
            local ok, status = pcall(UnitThreatSituation, unit, mob)
            Line(label .. " UnitThreatSituation " .. (ok and Describe(status) or "call failed"))
        end
        if UnitDetailedThreatSituation then
            local ok, tanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, unit, mob)
            if ok then
                Line(label .. " detailed tanking=" .. Describe(tanking)
                    .. " status=" .. Describe(status)
                    .. " scaled=" .. Describe(scaled)
                    .. " raw=" .. Describe(raw))
            else
                Line(label .. " UnitDetailedThreatSituation call failed")
            end
        end
    end

    Threat("player", "player", "target")
    Threat("pet", "pet", "target")
    if UnitExists("party1") then
        Threat("party1", "party1", "target")
    end

    local record = addon.GetKillRecord and addon.GetKillRecord(guid)
    if record then
        local count = 0
        for _ in pairs(record.participants) do
            count = count + 1
        end
        Line("record assisted=" .. tostring(record.assisted)
            .. " playerThreat=" .. tostring(record.playerOrPetOnThreat)
            .. " groupThreat=" .. tostring(record.groupOnThreat)
            .. " participants=" .. tostring(count))
    else
        Line("no participation record for this target")
    end
end

function addon.SetForeverKillDebug(enabled)
    addon.ForeverKillDebug = enabled and true or false
end
