local addonName, addon = ...

-- =========================================================
-- /hca probe and /hca killdebug (Forever)
--
-- Prints what this client actually exposes right now: event registration, restriction state, and the
-- secrecy of the values kill tracking depends on. Nothing here is compared, persisted, or used to award.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
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
    -- Never concatenate/compare secrets into the event log; chat print is fine for probe output.
    if IsSecret(text) then
        print("|cff008066[HCA Probe]|r <secret line omitted from event log>")
        return
    end
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
    -- local _, _, _, tocversion = GetBuildInfo()
    -- local interfaceVersion = tonumber(tocversion) or 0
    -- Line("IsForeverClient=" .. tostring(addon.IsForeverClient and addon.IsForeverClient())
    --     .. " interface=" .. tostring(interfaceVersion))
    local inInstance, instanceType = IsInInstance()
    Line("instance=" .. tostring(inInstance) .. " type=" .. tostring(instanceType))

    if addon.TryRegisterHCAChatChannel then
        addon.TryRegisterHCAChatChannel()
    end
    Line("HCA channel index=" .. tostring(addon.GetHCACommChannelIndex and addon.GetHCACommChannelIndex()))
    Line("HCA chat broadcast=" .. tostring(addon.FlushBroadcastQueue ~= nil)
        .. " queueFn=" .. tostring(addon.QueueChatBroadcast ~= nil))

    -- Line("PARTY_KILL registered=" .. tostring(addon.Restrictions.partyKillEvent)
    --     .. " ENCOUNTER_END registered=" .. tostring(addon.Restrictions.encounterEndEvent))

    -- local restriction = Enum and Enum.AddOnRestrictionType
    -- RestrictionState("Combat", restriction and restriction.Combat)
    -- RestrictionState("Encounter", restriction and restriction.Encounter)
    -- RestrictionState("Map", restriction and restriction.Map)
    -- RestrictionState("Chat", restriction and restriction.Chat)
    -- Line("GetRealmName=" .. tostring(GetRealmName and GetRealmName()))
    -- Line("ruleset=" .. tostring(addon.GetPlayerRulesetLabel and addon.GetPlayerRulesetLabel()))
    -- Line("fullName=" .. tostring(addon.GetPlayerFullName and addon.GetPlayerFullName()))
    -- local first, second = UnitName("player")
    -- Line("UnitName first=" .. tostring(first) .. " second=" .. tostring(second))

    -- local inGroup = IsInGroup and IsInGroup()
    -- local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    -- Line("grouped=" .. tostring(inGroup) .. " members=" .. tostring(members)
    --     .. " guild=" .. tostring(IsInGuild and IsInGuild()))
    -- Line("chatRestricted=" .. tostring(addon.IsForeverChatRestricted and addon.IsForeverChatRestricted()))

    -- local lb = addon.Leaderboard
    -- local sync = lb and lb.Sync
    -- local rowCount = 0
    -- if lb and lb.GetDB then
    --     local rows = lb:GetDB().rows
    --     if type(rows) == "table" then
    --         for _ in pairs(rows) do
    --             rowCount = rowCount + 1
    --         end
    --     end
    -- end
    -- Line("leaderboardSync=" .. tostring(sync ~= nil)
    --     .. " rows=" .. tostring(rowCount)
    --     .. " libP2PDB=" .. tostring(LibStub and LibStub("LibP2PDB", true) ~= nil))
    -- if sync and sync.PublishLocal then
    --     local published = sync:PublishLocal("probe")
    --     Line("publishLocal=" .. tostring(published))
    -- end

    -- ------------------------------------------------------------------
    -- UnitGUID("target") secrecy report
    -- /dump can still *display* a secret GUID; the decisive check is issecretvalue().
    -- Re-run this in open world, then again in a dungeon boss fight (in combat).
    -- ------------------------------------------------------------------
    -- local playerGuid = UnitGUID("player")
    -- Line("player GUID " .. Describe(playerGuid)
    --     .. " issecretvalue=" .. tostring(IsSecret(playerGuid)))

    if not UnitExists("target") then
        Line("no target — select a dungeon boss (in combat) and /hca probe again")
        return
    end

    local guid = UnitGUID("target")
    -- local name = UnitName("target")
    local guidSecret = IsSecret(guid)
    -- local nameSecret = IsSecret(name)
    Line("--- target UnitGUID ---")
    -- Line("UnitExists=true UnitCanAttack=" .. tostring(UnitCanAttack and UnitCanAttack("player", "target")))
    Line("player combat=" .. Describe(UnitAffectingCombat and UnitAffectingCombat("player"))
        .. " target combat=" .. Describe(UnitAffectingCombat and UnitAffectingCombat("target")))
    -- Line("target name " .. Describe(name) .. " issecretvalue=" .. tostring(nameSecret))
    Line("target GUID type=" .. type(guid)
        .. " issecretvalue=" .. tostring(guidSecret)
        .. " Describe=" .. Describe(guid))

    -- tostring on a secret value can error or return a secret placeholder; never concatenate secrets.
    local tostringOk, tostringVal = pcall(tostring, guid)
    if not tostringOk then
        Line("target GUID tostring FAILED")
    elseif IsSecret(tostringVal) then
        Line("target GUID tostring ok=secret " .. type(tostringVal))
    else
        Line("target GUID tostring ok=" .. tostring(tostringVal))
    end

    if type(guid) == "string" and not guidSecret then
        local npcId = addon.ParseCreatureNpcId and addon.ParseCreatureNpcId(guid)
        Line("target npcId(from GUID)=" .. tostring(npcId) .. " (UnitGUID usable for cache/credit)")
    elseif guidSecret then
        Line("target GUID marked SECRET — compare with UnitCreatureID / ParseCreatureNpcId below")
    else
        Line("target GUID unusable (type=" .. type(guid) .. ")")
    end

    -- Patch 1.60.1: creature GUID spawn/server portions may be obfuscated, but NPC id is retained.
    -- UnitCreatureID is the direct API; still check issecretvalue before using the return.
    Line("--- target UnitCreatureID ---")
    if type(UnitCreatureID) == "function" then
        local creatureOk, creatureId = pcall(UnitCreatureID, "target")
        if not creatureOk then
            Line("UnitCreatureID call FAILED")
        else
            local creatureSecret = IsSecret(creatureId)
            Line("UnitCreatureID " .. Describe(creatureId)
                .. " issecretvalue=" .. tostring(creatureSecret))
            if creatureId ~= nil and not creatureSecret then
                Line("UnitCreatureID usable npcId=" .. tostring(creatureId))
            elseif creatureSecret then
                Line("UnitCreatureID is SECRET — cannot use for cache/credit")
            else
                Line("UnitCreatureID returned nil")
            end
        end
    else
        Line("UnitCreatureID unavailable on this client")
    end

    -- Also probe C_CreatureInfo.GetCreatureID(guid) when GUID is a plain string.
    if C_CreatureInfo and C_CreatureInfo.GetCreatureID and type(guid) == "string" and not guidSecret then
        local getOk, fromGuid = pcall(C_CreatureInfo.GetCreatureID, guid)
        Line("C_CreatureInfo.GetCreatureID " .. (getOk and Describe(fromGuid) or "call FAILED")
            .. (getOk and (" issecretvalue=" .. tostring(IsSecret(fromGuid))) or ""))
    end

    Line("UnitIsDead " .. Describe(UnitIsDead and UnitIsDead("target")))
        -- .. " UnitIsDeadOrGhost " .. Describe(UnitIsDeadOrGhost and UnitIsDeadOrGhost("target")))
    -- Line("UnitIsTapDenied " .. Describe(UnitIsTapDenied and UnitIsTapDenied("target")))
    -- Line("UnitInRange " .. Describe(UnitInRange and UnitInRange("target")))

    -- Loot identity (only meaningful with a loot window open).
    if GetLootSourceInfo then
        local lootOk, lootGuid = pcall(GetLootSourceInfo, 1)
        if lootOk and lootGuid ~= nil then
            Line("GetLootSourceInfo(1) " .. Describe(lootGuid)
                .. " issecretvalue=" .. tostring(IsSecret(lootGuid)))
            if type(lootGuid) == "string" and not IsSecret(lootGuid) then
                Line("loot npcId=" .. tostring(addon.ParseCreatureNpcId and addon.ParseCreatureNpcId(lootGuid)))
            end
        else
            Line("GetLootSourceInfo(1) " .. (lootOk and "nil (no loot slot 1)" or "call failed"))
        end
    else
        Line("GetLootSourceInfo unavailable")
    end

    -- local function Threat(label, unit, mob)
    --     if not UnitExists(unit) then
    --         Line(label .. " (unit missing)")
    --         return
    --     end
    --     if C_Secrets and C_Secrets.ShouldUnitThreatValuesBeSecret then
    --         local ok, secret = pcall(C_Secrets.ShouldUnitThreatValuesBeSecret, unit, mob)
    --         Line(label .. " values-should-be-secret " .. (ok and Describe(secret) or "call failed"))
    --     end
    --     if UnitThreatSituation then
    --         local ok, status = pcall(UnitThreatSituation, unit, mob)
    --         Line(label .. " UnitThreatSituation " .. (ok and Describe(status) or "call failed"))
    --     end
    --     if UnitDetailedThreatSituation then
    --         local ok, tanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, unit, mob)
    --         if ok then
    --             Line(label .. " detailed tanking=" .. Describe(tanking)
    --                 .. " status=" .. Describe(status)
    --                 .. " scaled=" .. Describe(scaled)
    --                 .. " raw=" .. Describe(raw))
    --         else
    --             Line(label .. " UnitDetailedThreatSituation call failed")
    --         end
    --     end
    -- end

    -- Threat("player", "player", "target")
    -- Threat("pet", "pet", "target")
    -- if UnitExists("party1") then
    --     Threat("party1", "party1", "target")
    -- end

    -- if type(guid) ~= "string" or guidSecret then
    --     -- GetKillRecord cannot key on secret GUIDs; dungeon/raid bosses use ENCOUNTER_END instead.
    --     Line("no participation record (target GUID secret; open-world GUID tracking only)")
    --     return
    -- end

    -- local record = addon.GetKillRecord and addon.GetKillRecord(guid)
    -- if record then
    --     local count = 0
    --     for _ in pairs(record.participants) do
    --         count = count + 1
    --     end
    --     Line("record assisted=" .. tostring(record.assisted)
    --         .. " playerThreat=" .. tostring(record.playerOrPetOnThreat)
    --         .. " groupThreat=" .. tostring(record.groupOnThreat)
    --         .. " participants=" .. tostring(count))
    -- else
    --     Line("no participation record for this target")
    -- end
end

function addon.SetForeverKillDebug(enabled)
    addon.ForeverKillDebug = enabled and true or false
end
