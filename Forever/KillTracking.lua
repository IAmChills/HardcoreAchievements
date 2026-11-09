local addonName, addon = ...

-- =========================================================
-- Open-world kill credit and solo-vs-assisted tracking (Forever)
--
-- COMBAT_LOG_EVENT_UNFILTERED is unavailable here. Credit comes from the standalone PARTY_KILL event
-- (a party member, including pets, was credited with the kill). You do not need to target the mob or
-- be on its threat table; observing a group kill in range is enough. UNIT_DIED is only a fallback for
-- a mob this addon already saw the player or their group on the threat table of, which covers a killing
-- blow the PARTY_KILL payload cannot attribute. Nearby UNIT_DIED events with no group threat are ignored
-- silently.
--
-- Solo vs assisted is participation, not group membership. A kill stays solo unless another player or
-- their pet was positively seen contributing. When Midnight hides that information, the kill stays solo:
-- the addon is on the honor system for anything it cannot observe.
--
-- Dungeon and raid bosses do not use this participation record. See Forever\EncounterKills.lua.
-- This file loads before Achievements\Common.lua so the overrides below are the functions it captures.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local RECORD_IDLE_SEC = 90
local RECORD_AFTER_DEATH_SEC = 10
local REFRESH_SEC = 1

local IsSecret = addon.IsSecretValue
local UnitThreatSituation = UnitThreatSituation
local UnitIsTapDenied = UnitIsTapDenied
local UnitTokenFromGUID = UnitTokenFromGUID
local UnitPlayerControlled = UnitPlayerControlled

-- guid -> { npcId, assisted, playerOrPetOnThreat, groupOnThreat, tapDenied, participants, lastSeen, diedAt }
-- participants[guid] = { level, isPet, external }. Never written to SavedVariables.
local records = {}
-- guid -> "player" | "pet" | "member" | "memberpet"
local groupGUIDs = {}
local secretGuidLogged = false

local function KillLog(message)
    if not addon.ForeverKillDebug then
        return
    end
    print("|cff008066[HCA Kills]|r " .. message)
    if addon.EventLogAdd then
        addon.EventLogAdd("[Kills] " .. message)
    end
end

local function PlainGUID(unit)
    if not UnitExists(unit) then
        return nil
    end
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" or IsSecret(guid) then
        return nil
    end
    return guid
end

local function RebuildGroup()
    for key in pairs(groupGUIDs) do
        groupGUIDs[key] = nil
    end
    local playerGUID = PlainGUID("player")
    if playerGUID then
        groupGUIDs[playerGUID] = "player"
    end
    local petGUID = PlainGUID("pet")
    if petGUID then
        groupGUIDs[petGUID] = "pet"
    end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        local unit = prefix .. i
        if UnitExists(unit) then
            -- A secret comparison must not relabel the player as a group member, which would turn
            -- their own killing blow into assistance.
            local sameAsPlayer = UnitIsUnit(unit, "player")
            if not IsSecret(sameAsPlayer) and not sameAsPlayer then
                local guid = PlainGUID(unit)
                if guid and not groupGUIDs[guid] then
                    groupGUIDs[guid] = "member"
                end
                local pet = PlainGUID(unit .. "pet")
                if pet and not groupGUIDs[pet] then
                    groupGUIDs[pet] = "memberpet"
                end
            end
        end
    end
end

--- "player", "pet", "member", "memberpet", "other", or nil when the GUID cannot be read.
local function Classify(guid)
    if type(guid) ~= "string" or IsSecret(guid) then
        return nil
    end
    return groupGUIDs[guid] or "other"
end

local function TrackedNpcId(guid)
    local npcId = addon.ParseCreatureNpcId(guid)
    if not npcId then
        return nil
    end
    if not (addon.IsNpcTrackedForAchievement and addon.IsNpcTrackedForAchievement(npcId)) then
        return nil
    end
    return npcId
end

local function GetRecord(guid, npcId)
    local record = records[guid]
    if not record then
        record = {
            npcId = npcId,
            assisted = false,
            playerOrPetOnThreat = false,
            groupOnThreat = false,
            tapDenied = nil,
            participants = {},
            lastSeen = GetTime(),
        }
        records[guid] = record
    end
    record.lastSeen = GetTime()
    if npcId and not record.npcId then
        record.npcId = npcId
    end
    return record
end

local function NoteParticipant(record, guid, level, isPet, external)
    if type(guid) ~= "string" or IsSecret(guid) then
        record.assisted = true
        return
    end
    local entry = record.participants[guid]
    if not entry then
        entry = { isPet = isPet and true or false, external = external and true or false }
        record.participants[guid] = entry
    end
    if type(level) == "number" and level > 0 then
        entry.level = level
    end
    record.assisted = true
end

--- On the threat table at all. The status number may be secret; its type is not, and nil means "not on it".
local function OnThreatTable(unit, mob)
    if not UnitThreatSituation or not UnitExists(unit) or not UnitExists(mob) then
        return false
    end
    local ok, status = pcall(UnitThreatSituation, unit, mob)
    return ok and type(status) == "number"
end

local function ReadableLevel(unit)
    local level = UnitLevel(unit)
    if type(level) == "number" and level > 0 then
        return level
    end
    return nil
end

--- Records participation for one living mob. Targeting alone never counts as assistance.
local function Sample(unit)
    if type(unit) ~= "string" or not UnitExists(unit) or UnitIsDead(unit) then
        return
    end
    local guid = UnitGUID(unit)
    if type(guid) ~= "string" or IsSecret(guid) or guid:sub(1, 9) ~= "Creature-" then
        return
    end
    local npcId = TrackedNpcId(guid)
    if not npcId then
        return
    end
    local record = GetRecord(guid, npcId)

    if UnitIsTapDenied then
        local tapDenied = UnitIsTapDenied(unit)
        if type(tapDenied) == "boolean" then
            record.tapDenied = tapDenied
        end
    end

    if OnThreatTable("player", unit) or OnThreatTable("pet", unit) then
        record.playerOrPetOnThreat = true
        record.groupOnThreat = true
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        local member = prefix .. i
        local sameAsPlayer = UnitExists(member) and UnitIsUnit(member, "player")
        if UnitExists(member) and not IsSecret(sameAsPlayer) and not sameAsPlayer then
            local memberThreat = OnThreatTable(member, unit)
            local petUnit = member .. "pet"
            local petThreat = UnitExists(petUnit) and OnThreatTable(petUnit, unit)
            if memberThreat or petThreat then
                record.groupOnThreat = true
                local ownerLevel = ReadableLevel(member)
                local memberGUID = PlainGUID(member)
                if memberGUID then
                    NoteParticipant(record, memberGUID, ownerLevel, false, false)
                else
                    record.assisted = true
                end
                if petThreat then
                    local petGUID = PlainGUID(petUnit)
                    if petGUID then
                        -- The pet counts as its owner for the level cap.
                        NoteParticipant(record, petGUID, ownerLevel, true, false)
                    end
                end
            end
        end
    end

    -- The mob's own target is a contribution signal: it is hitting that unit. Another player merely
    -- targeting this mob is not, and a secret answer is not either.
    local target = unit .. "target"
    if UnitExists(target) then
        local sameAsPlayer = UnitIsUnit(target, "player")
        local sameAsPet = UnitIsUnit(target, "pet")
        -- Compound tokens (nameplate1target, party1target) are secret comparisons inside an instance.
        -- An unreadable answer is not assistance.
        if not IsSecret(sameAsPlayer) and not IsSecret(sameAsPet) and not sameAsPlayer and not sameAsPet then
            local isPlayer = UnitIsPlayer(target)
            local controlled = UnitPlayerControlled and UnitPlayerControlled(target)
            local inParty = UnitInParty(target)
            local inRaid = UnitInRaid(target)
            if not IsSecret(isPlayer) and not IsSecret(controlled) and not IsSecret(inParty) and not IsSecret(inRaid)
                and not inParty and not inRaid and (isPlayer or controlled) then
                local targetGUID = PlainGUID(target)
                local level = isPlayer and ReadableLevel(target) or nil
                if targetGUID then
                    NoteParticipant(record, targetGUID, level, not isPlayer, true)
                else
                    record.assisted = true
                end
            end
        end
    end
end

local function Refresh()
    local now = GetTime()
    for guid, record in pairs(records) do
        if record.diedAt and (now - record.diedAt) > RECORD_AFTER_DEATH_SEC then
            records[guid] = nil
        elseif not record.diedAt and record.lastSeen and (now - record.lastSeen) > RECORD_IDLE_SEC then
            records[guid] = nil
        end
    end
    if not UnitAffectingCombat("player") then
        return
    end

    Sample("target")
    Sample("pettarget")
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        Sample(prefix .. i .. "target")
        Sample(prefix .. i .. "pettarget")
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if type(plate.namePlateUnitToken) == "string" then
                Sample(plate.namePlateUnitToken)
            end
        end
    end
    if UnitTokenFromGUID then
        -- Copy first. Sample may insert records, and Lua does not allow that during pairs().
        local pending = {}
        for guid, record in pairs(records) do
            if not record.diedAt then
                pending[#pending + 1] = guid
            end
        end
        for _, guid in ipairs(pending) do
            local record = records[guid]
            if record and not record.diedAt then
                local ok, token = pcall(UnitTokenFromGUID, guid)
                if ok and type(token) == "string" and not IsSecret(token) then
                    Sample(token)
                end
            end
        end
    end
end

local function LogSecretGUID(kind)
    if secretGuidLogged then
        return
    end
    secretGuidLogged = true
    KillLog(kind .. " GUID is secret; this kill cannot be attributed by GUID (expected inside instances)")
end

local function Award(guid, npcId, source)
    local record = records[guid]
    KillLog(source .. " npc " .. tostring(npcId)
        .. " assisted=" .. tostring(record and record.assisted or false)
        .. " tapDenied=" .. tostring(record and record.tapDenied))
    if record then
        record.diedAt = GetTime()
    end
    if addon.AwardKillFromExternalSource then
        addon.AwardKillFromExternalSource(guid, npcId)
    end
end

local function OnPartyKill(attackerGUID, targetGUID)
    if type(targetGUID) ~= "string" or IsSecret(targetGUID) then
        LogSecretGUID("PARTY_KILL target")
        return
    end
    if targetGUID:sub(1, 9) ~= "Creature-" then
        return
    end

    local role = Classify(attackerGUID)
    if role == nil then
        -- The event itself means the party was credited. Who swung is unreadable, so this is not assistance.
        role = "party"
    end

    -- Same contract as the Classic PARTY_KILL branch: the rare-quest hook sees every party kill, including
    -- ones no achievement row tracks and ones tap denial later rejects.
    local onRareQuestLootKill = addon.FirstKillRareQuestLoot_OnPartyKill
    if onRareQuestLootKill then
        onRareQuestLootKill(targetGUID)
    end

    local npcId = TrackedNpcId(targetGUID)
    if not npcId then
        return
    end
    if role == "other" then
        KillLog("PARTY_KILL npc " .. tostring(npcId) .. " ignored: killer is not in the group")
        return
    end

    local record = GetRecord(targetGUID, npcId)
    if role == "player" or role == "pet" then
        record.playerOrPetOnThreat = true
        record.groupOnThreat = true
    elseif role == "member" or role == "memberpet" then
        record.groupOnThreat = true
        NoteParticipant(record, attackerGUID, nil, role == "memberpet", false)
    end

    -- A denied tap drops the kill only when we ourselves got the killing blow. A party member's tag can
    -- report as denied for the player, and that must not reject a legitimate group kill.
    if record.tapDenied == true and (role == "player" or role == "pet") then
        KillLog("PARTY_KILL npc " .. tostring(npcId) .. " dropped: tap denied")
        record.diedAt = GetTime()
        return
    end

    Award(targetGUID, npcId, "PARTY_KILL " .. role)
end

local function OnUnitDied(guid)
    if type(guid) ~= "string" or IsSecret(guid) then
        LogSecretGUID("UNIT_DIED")
        return
    end
    if guid:sub(1, 9) ~= "Creature-" then
        return
    end
    local npcId = TrackedNpcId(guid)
    if not npcId then
        return
    end

    local _, instanceType = GetInstanceInfo()
    local inInstance = instanceType == "party" or instanceType == "raid"
    local record = records[guid]

    if not inInstance then
        -- No PARTY_KILL, so the threat record is the only proof anyone in the group fought it.
        -- Nearby copies of a tracked npc die constantly; those are ignored without a log line.
        if not record or not record.groupOnThreat then
            return
        end
        if record.tapDenied == true and not record.assisted then
            KillLog("UNIT_DIED npc " .. tostring(npcId) .. " dropped: tap denied")
            record.diedAt = GetTime()
            return
        end
    end

    Award(guid, npcId, inInstance and "UNIT_DIED instance" or "UNIT_DIED")
end

-- =========================================================
-- Overrides captured by Achievements\Common.lua. Group membership is not assistance, and a missing
-- record stays solo: that is the honor-system default when the fight was not observable.
-- =========================================================

local function PlayerIsSoloForGUID(guid)
    if type(guid) ~= "string" or IsSecret(guid) then
        return nil
    end
    local record = records[guid]
    if not record then
        return nil
    end
    return not record.assisted
end

local function PlayerIsSolo()
    local guid = PlainGUID("target")
    if guid and records[guid] then
        return not records[guid].assisted
    end
    return true
end

local function IsGroupEligibleForAchievement(maxLevel, achievementId, destGUID)
    local maxPartySize = 5
    if achievementId and addon.AchievementDefs then
        local def = addon.AchievementDefs[tostring(achievementId)] or addon.AchievementDefs[achievementId]
        if def and def.maxPartySize then
            maxPartySize = def.maxPartySize
        end
    end
    -- Explicit membership limits. Independent of whether anyone actually helped.
    if IsInRaid() and maxPartySize <= 5 then
        return false
    end
    if (GetNumGroupMembers() or 0) > maxPartySize then
        return false
    end

    local playerLevel = UnitLevel("player")
    if type(playerLevel) == "number" and maxLevel and maxLevel > 0 and playerLevel > maxLevel then
        return false
    end

    -- Only players (and pet owners) positively seen participating can fail the level cap.
    if type(destGUID) == "string" and not IsSecret(destGUID) then
        local record = records[destGUID]
        if record then
            for _, participant in pairs(record.participants) do
                local level = participant.level
                if type(level) == "number" and maxLevel and maxLevel > 0 and level > maxLevel then
                    return false
                end
            end
        end
    end
    return true
end

addon.PlayerIsSolo = PlayerIsSolo
addon.PlayerIsSoloForGUID = PlayerIsSoloForGUID
addon.PlayerIsSolo_UpdateStatusForGUID = function() end
addon.IsGroupEligibleForAchievement = IsGroupEligibleForAchievement
addon.GetKillRecord = function(guid)
    return records[guid]
end

-- The Classic threat frame compares percentages and would error on secret values. It has nothing to
-- observe here anyway, because the combat log never arrives.
if PlayerIsSolo_EventFrame then
    PlayerIsSolo_EventFrame:UnregisterAllEvents()
end

local tracker = CreateFrame("Frame")

local function TryRegister(event)
    local ok = pcall(tracker.RegisterEvent, tracker, event)
    if event == "PARTY_KILL" then
        addon.Restrictions.partyKillEvent = ok and true or false
        if not ok then
            KillLog("PARTY_KILL could not be registered; kill credit falls back to UNIT_DIED plus threat")
        end
    end
    return ok
end

TryRegister("PARTY_KILL")
TryRegister("UNIT_DIED")
TryRegister("UNIT_THREAT_LIST_UPDATE")
TryRegister("UNIT_TARGET")
TryRegister("PLAYER_TARGET_CHANGED")
TryRegister("NAME_PLATE_UNIT_ADDED")
TryRegister("GROUP_ROSTER_UPDATE")
TryRegister("UNIT_PET")
TryRegister("PLAYER_ENTERING_WORLD")
TryRegister("PLAYER_LOGIN")

tracker:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PARTY_KILL" then
        OnPartyKill(arg1, arg2)
    elseif event == "UNIT_DIED" then
        OnUnitDied(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        records = {}
        secretGuidLogged = false
        RebuildGroup()
    elseif event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        RebuildGroup()
    elseif event == "PLAYER_TARGET_CHANGED" then
        Sample("target")
    elseif type(arg1) == "string" then
        Sample(arg1)
    end
end)

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(REFRESH_SEC, Refresh)
end
