local addonName, addon = ...

-- =========================================================
-- Instance loot-source kill fallback (Forever)
--
-- Inside dungeons/raids, PARTY_KILL and UNIT_DIED GUIDs are secret, so open-world GUID credit
-- cannot name the mob. GetLootSourceInfo() still returns readable Creature GUIDs (and NPC ids)
-- when the loot window opens.
--
-- ENCOUNTER_END remains the primary boss path (Forever\EncounterKills.lua). This module is the
-- fallback for rares and bosses without a usable encounter payload. Credit goes through
-- AwardKillFromExternalSource so dungeon eligibility and PARTY/RAID SyncBossKill stay shared.
-- No threat/participation checks: looting in an instance is enough.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local IsSecret = addon.IsSecretValue

-- guid -> expiry time. Covers LOOT_READY + LOOT_OPENED and multi-slot AoE loot of the same corpse.
local seenGuids = {}
local DEDUPE_SEC = 120

local function KillLog(message)
    if not addon.ForeverKillDebug then
        return
    end
    if IsSecret(message) then
        return
    end
    print("|cff008066[HCA Kills]|r " .. message)
    if addon.EventLogAdd then
        addon.EventLogAdd("[Kills] " .. message)
    end
end

local function IsInsideGroupInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "party" or instanceType == "raid"
end

local function PurgeExpired(now)
    for guid, expires in pairs(seenGuids) do
        if expires <= now then
            seenGuids[guid] = nil
        end
    end
end

--- Returns true the first time this GUID is claimed within the dedupe window.
local function ClaimGuid(guid, now)
    PurgeExpired(now)
    local expires = seenGuids[guid]
    if expires and expires > now then
        return false
    end
    seenGuids[guid] = now + DEDUPE_SEC
    return true
end

local function ProcessLootGuid(guid)
    if guid == nil then
        return
    end
    if IsSecret(guid) then
        KillLog("LOOT source secret=true type=" .. type(guid) .. " (not parsed)")
        return
    end
    if type(guid) ~= "string" then
        return
    end
    if guid:sub(1, 9) ~= "Creature-" then
        return
    end

    local npcId = addon.ParseCreatureNpcId and addon.ParseCreatureNpcId(guid)
    if not npcId then
        return
    end
    if not (addon.IsNpcTrackedForAchievement and addon.IsNpcTrackedForAchievement(npcId)) then
        return
    end

    local now = GetTime()
    if not ClaimGuid(guid, now) then
        KillLog("LOOT npc " .. tostring(npcId) .. " skipped: duplicate guid")
        return
    end

    KillLog("LOOT source secret=false guid=" .. guid .. " npcId=" .. tostring(npcId))

    if not addon.AwardKillFromExternalSource then
        KillLog("LOOT AwardKillFromExternalSource missing")
        return
    end

    KillLog("LOOT awarding npc " .. tostring(npcId))
    addon.AwardKillFromExternalSource(guid, npcId)
end

local function ScanLootSources()
    if not IsInsideGroupInstance() then
        return
    end
    if not GetLootSourceInfo or not GetNumLootItems then
        return
    end

    local numOk, numItems = pcall(GetNumLootItems)
    if not numOk or type(numItems) ~= "number" or numItems < 1 then
        return
    end

    for slot = 1, numItems do
        local packOk, sources = pcall(function()
            return { GetLootSourceInfo(slot) }
        end)
        if packOk and type(sources) == "table" then
            for i = 1, #sources, 2 do
                ProcessLootGuid(sources[i])
            end
        end
    end
end

local tracker = CreateFrame("Frame")
local registeredReady = pcall(tracker.RegisterEvent, tracker, "LOOT_READY")
local registeredOpened = pcall(tracker.RegisterEvent, tracker, "LOOT_OPENED")

tracker:SetScript("OnEvent", function(_, event)
    if event ~= "LOOT_READY" and event ~= "LOOT_OPENED" then
        return
    end
    ScanLootSources()
end)

if addon.ForeverKillDebug then
    KillLog("LOOT_READY registered=" .. tostring(registeredReady)
        .. " LOOT_OPENED registered=" .. tostring(registeredOpened))
end
