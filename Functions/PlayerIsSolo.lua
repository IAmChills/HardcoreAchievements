-- PlayerIsSolo.lua
-- Solo-detection using threat + lightweight combat-log correlation.
-- Allows target dummies / hunter/warlock pets / Dog Whistle etc., but disqualifies
-- meaningful help from other PLAYERS. Nameplates are NOT required.

---------------------------------------
-- Configuration
---------------------------------------
local OTHER_PLAYER_THREAT_THRESHOLD = 10  -- % threat from grouped players to fail
local PLAYER_SOLO_THREAT_THRESHOLD  = 90  -- % threat you must maintain (unless mob is a non-player)
local HELPER_TIMEOUT_SEC            = 8   -- seconds to remember recent player helpers vs your current target

-- Localize frequently-used WoW API globals (micro-optimization, no behavior change)
local UnitGUID = UnitGUID
local GetTime = GetTime
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local UnitInRange = UnitInRange
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local UnitIsTapDenied = UnitIsTapDenied
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local CreateFrame = CreateFrame

---------------------------------------
-- Internal state (helpers per mob GUID)
-- helpersByTarget[targetGUID] = { [playerGUID] = lastSeenTime }
---------------------------------------
local helpersByTarget = {}
local playerGUID = UnitGUID("player")

---------------------------------------
-- Tracked NPCs and their solo status during combat
-- soloStatusByGUID[targetGUID] = { isSolo = bool, lastChecked = time }
---------------------------------------
local soloStatusByGUID = {}
local SOLO_STATUS_TIMEOUT = 10  -- seconds to keep solo status after combat ends

---------------------------------------
-- Utility: shallow wipe a table
---------------------------------------
local function wipeTable(t)
    for k in pairs(t) do t[k] = nil end
end

---------------------------------------
-- Cleanup helpers older than timeout, remove empty targets
---------------------------------------
local function CleanupHelpers(now)
    for targetGUID, helpers in pairs(helpersByTarget) do
        local empty = true
        for srcGUID, t in pairs(helpers) do
            if now - t > HELPER_TIMEOUT_SEC then
                helpers[srcGUID] = nil
            else
                empty = false
            end
        end
        if empty then
            helpersByTarget[targetGUID] = nil
        end
    end
end

---------------------------------------
-- COMBAT_LOG: record other PLAYERS helping against your *current* target
---------------------------------------
local damageEvents = {
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    SPELL_BUILDING_DAMAGE = true,
    DAMAGE_SPLIT = true,
    DAMAGE_SHIELD = true,
}

local bit_band = bit.band
local OBJ_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER

local function OnCombatLogEvent()
    local now = GetTime()
    CleanupHelpers(now)

    -- We only care about events hitting your current target at the time we receive them.
    local currentTargetGUID = UnitGUID("target")
    if not currentTargetGUID then return end

    local _, subEvent, _, srcGUID, _, srcFlags, _, destGUID = CombatLogGetCurrentEventInfo()
    if not damageEvents[subEvent] then return end
    if destGUID ~= currentTargetGUID then return end

    -- Only count other PLAYERS (not you). Pets/guardians/dummies are *not* flagged as players.
    if srcGUID ~= playerGUID and bit_band(srcFlags, OBJ_PLAYER) ~= 0 then
        local bucket = helpersByTarget[currentTargetGUID]
        if not bucket then
            bucket = {}
            helpersByTarget[currentTargetGUID] = bucket
        end
        bucket[srcGUID] = now
    end
end

---------------------------------------
-- Query helpers cache for the current target
---------------------------------------
local function OtherPlayersRecentlyHelped(targetGUID)
    if not targetGUID then return false end
    local now = GetTime()
    CleanupHelpers(now)
    local bucket = helpersByTarget[targetGUID]
    if not bucket then return false end

    -- If any entry remains after cleanup, a player recently helped.
    for _ in pairs(bucket) do
        return true
    end
    return false
end

---------------------------------------
-- Check if a specific unit has significant threat
---------------------------------------
local function UnitHasSignificantThreat(unit, mobUnit, threshold)
    local isUnitTanking, unitStatus, scaledPct, rawPct = UnitDetailedThreatSituation(unit, mobUnit)
    
    -- Check if this unit is tanking (definitely helping) - disqualify immediately
    if isUnitTanking and unitStatus and unitStatus >= 2 then
        return true
    end
    
    -- Check if this unit has >threshold% threat on EITHER scaled or raw threat
    -- This ensures we catch cases where either metric shows they're helping
    if scaledPct and scaledPct > threshold then
        return true
    end
    
    if rawPct and rawPct > threshold then
        return true
    end
    
    return false
end

---------------------------------------
-- Grouped player > threshold% threat?
-- Only checks PARTY/RAID *players* via unit tokens (pets excluded by token choice).
-- Checks both scaled and raw threat, and tanking status.
---------------------------------------
local function AnyGroupedPlayerOverThresholdOn(mobUnit, pct)
    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do
            local u = "raid"..i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                if UnitHasSignificantThreat(u, mobUnit, pct) then
                    return true
                end
            end
        end
    elseif IsInGroup() then
        local n = GetNumSubgroupMembers()
        for i = 1, n do
            local u = "party"..i
            if UnitExists(u) then
                if UnitHasSignificantThreat(u, mobUnit, pct) then
                    return true
                end
            end
        end
    end
    return false
end

---------------------------------------
-- Is the mob currently targeting a *player* (not you)?
-- If it targets a pet/guardian/dummy (non-player), that's allowed.
---------------------------------------
local function MobPrimaryTargetIsOtherPlayer(mobUnit)
    local tgt = mobUnit .. "target"
    return UnitExists(tgt) and UnitIsPlayer(tgt) and not UnitIsUnit(tgt, "player")
end

---------------------------------------
-- Player threat sufficiency:
-- - Normally require you to be tanking (status>=2) OR >=90% (scaled preferred, raw fallback).
-- - If the mob is hitting a *non-player* (pet/dummy), relax the 90% requirement:
--   you're allowed to pass without the strict threshold as long as no other *player* breaks rules.
---------------------------------------
local function PlayerThreatGoodEnough(mobUnit)
    local isTanking, status, scaledPct, rawPct = UnitDetailedThreatSituation("player", mobUnit)
    local primaryIsOtherPlayer = MobPrimaryTargetIsOtherPlayer(mobUnit)

    -- If data is missing entirely, treat as not good enough (unless mob is clearly on a non-player).
    if not (scaledPct or rawPct or status or isTanking) then
        -- If it's smacking a non-player (dummy/pet), allow it and let the other checks decide.
        local mobTarget = mobUnit .. "target"
        if UnitExists(mobTarget) and not UnitIsPlayer(mobTarget) then
            return true, isTanking, status, scaledPct, rawPct
        end
        return false, isTanking, status, scaledPct, rawPct
    end

    -- If mob is targeting a player (not you), be strict.
    if primaryIsOtherPlayer then
        if isTanking and status and status >= 2 then
            return true, isTanking, status, scaledPct, rawPct
        end
        if (scaledPct and scaledPct >= PLAYER_SOLO_THREAT_THRESHOLD)
            or (not scaledPct and rawPct and rawPct >= PLAYER_SOLO_THREAT_THRESHOLD) then
            return true, isTanking, status, scaledPct, rawPct
        end
        return false, isTanking, status, scaledPct, rawPct
    end

    -- Normal case (mob on you or on non-player): require 90% OR tanking,
    -- but if the mob is on a non-player (pet/dummy), relax and allow passing below 90%.
    if isTanking and status and status >= 2 then
        return true, isTanking, status, scaledPct, rawPct
    end
    if (scaledPct and scaledPct >= PLAYER_SOLO_THREAT_THRESHOLD)
        or (not scaledPct and rawPct and rawPct >= PLAYER_SOLO_THREAT_THRESHOLD) then
        return true, isTanking, status, scaledPct, rawPct
    end

    -- Relaxation: mob not on another player -> allow (pets/dummies case).
    local mobTarget = mobUnit .. "target"
    if UnitExists(mobTarget) and not UnitIsPlayer(mobTarget) then
        return true, isTanking, status, scaledPct, rawPct
    end

    return false, isTanking, status, scaledPct, rawPct
end

---------------------------------------
-- Check solo status for a specific GUID (used during combat tracking)
---------------------------------------
local function CheckSoloStatusForGUID(targetGUID)
    if not targetGUID then return false end
    
    -- Try to find the unit by GUID (check target first, then nameplate)
    local mobUnit = nil
    if UnitExists("target") and UnitGUID("target") == targetGUID then
        mobUnit = "target"
    else
        -- Try to find via nameplate (limited in Classic, but worth trying)
        -- For now, we'll use a workaround: check if we can query threat by GUID
        -- Since we can't directly get unit from GUID, we'll need to track during combat
        -- This function will be called when we have the unit available
        return nil -- Can't check without unit
    end
    
    if not mobUnit or not UnitExists(mobUnit) or not UnitCanAttack("player", mobUnit) then
        return nil
    end
    
    -- Early exit: if player doesn't have the tag, they can't be solo
    if UnitIsTapDenied(mobUnit) then
        return false
    end
    
    if not UnitAffectingCombat("player") then
        return nil
    end
    
    local threatOK, isTanking, status, scaledPct, rawPct = PlayerThreatGoodEnough(mobUnit)
    if not threatOK then
        return false
    end

    -- Disqualify if any grouped player has >10% threat.
    if AnyGroupedPlayerOverThresholdOn(mobUnit, OTHER_PLAYER_THREAT_THRESHOLD) then
        return false
    end

    -- If any *ungrouped* player recently helped (via combat log),
    -- only fail if you're NOT clearly holding threat (not tanking and <90%).
    if OtherPlayersRecentlyHelped(targetGUID) then
        local clearlyAhead =
            (isTanking and status and status >= 2) or
            (scaledPct and scaledPct >= PLAYER_SOLO_THREAT_THRESHOLD) or
            (not scaledPct and rawPct and rawPct >= PLAYER_SOLO_THREAT_THRESHOLD) or
            (not MobPrimaryTargetIsOtherPlayer(mobUnit))  -- pet/dummy tanking allowance
        if not clearlyAhead then
            return false
        end
    end

    return true
end

---------------------------------------
-- Public API: PlayerIsSolo() - checks current target
---------------------------------------
function PlayerIsSolo()
    local mobUnit = "target"

    if UnitExists(mobUnit)
        and UnitCanAttack("player", mobUnit)
        and UnitAffectingCombat("player")
    then
        -- Early exit: if player doesn't have the tag, they can't be solo
        if UnitIsTapDenied(mobUnit) then
            return false
        end
        
        local targetGUID = UnitGUID(mobUnit)
        if targetGUID then
            -- Try to use cached/stored status first
            local isSolo = CheckSoloStatusForGUID(targetGUID)
            if isSolo ~= nil then
                local now = GetTime()
                soloStatusByGUID[targetGUID] = {
                    isSolo = isSolo,
                    lastChecked = now
                }
                return isSolo
            end
        end
        
        -- If GUID tracking failed, fall back to direct check
        -- (This should rarely happen, but provides a safety net)
        return false
    end

    -- Fallbacks when no valid hostile target / not in combat:
    -- Treat ungrouped as solo; if grouped, fail when groupmates are in range.
    if not IsInGroup() and not IsInRaid() then
        return true
    end

    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do
            local u = "raid"..i
            if UnitExists(u) and not UnitIsUnit(u, "player") and UnitInRange(u) then
                return false
            end
        end
    else
        local n = GetNumSubgroupMembers()
        for i = 1, n do
            local u = "party"..i
            if UnitExists(u) and UnitInRange(u) then
                return false
            end
        end
    end

    return true
end

---------------------------------------
-- Public API: Get stored solo status for a GUID (used at kill time)
---------------------------------------
function PlayerIsSoloForGUID(targetGUID)
    if not targetGUID then return nil end
    
    local status = soloStatusByGUID[targetGUID]
    if not status then return nil end
    
    local now = GetTime()
    -- Return stored status if it's recent enough
    if now - status.lastChecked <= SOLO_STATUS_TIMEOUT then
        return status.isSolo
    end
    
    -- Status is stale, remove it
    soloStatusByGUID[targetGUID] = nil
    return nil
end

---------------------------------------
-- Public API: Update solo status for a GUID (called during combat)
---------------------------------------
function PlayerIsSolo_UpdateStatusForGUID(targetGUID)
    if not targetGUID then return end
    
    -- Only update if target exists and matches GUID
    if UnitExists("target") and UnitGUID("target") == targetGUID then
        local isSolo = CheckSoloStatusForGUID(targetGUID)
        if isSolo ~= nil then
            local now = GetTime()
            soloStatusByGUID[targetGUID] = {
                isSolo = isSolo,
                lastChecked = now
            }
        end
    end
end

---------------------------------------
-- Helper: Update solo status for current target if in combat
---------------------------------------
local function UpdateSoloStatusForCurrentTarget()
    if UnitExists("target") and UnitAffectingCombat("player") then
        local targetGUID = UnitGUID("target")
        if targetGUID then
            PlayerIsSolo_UpdateStatusForGUID(targetGUID)
        end
    end
end

---------------------------------------
-- Event frame: register handlers
---------------------------------------
local _PlayerIsSolo_EventFrame = _PlayerIsSolo_EventFrame or CreateFrame("Frame")
_PlayerIsSolo_EventFrame:UnregisterAllEvents() -- avoid duplicates on reloads
_PlayerIsSolo_EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
_PlayerIsSolo_EventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
_PlayerIsSolo_EventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
_PlayerIsSolo_EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leave combat
_PlayerIsSolo_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD") -- zone loads

_PlayerIsSolo_EventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
        UpdateSoloStatusForCurrentTarget()
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        -- Update solo status when threat changes during combat
        local unit = ...
        if unit == "player" or unit == "target" then
            UpdateSoloStatusForCurrentTarget()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Clear memory when combat ends to avoid stale helpers
        wipeTable(helpersByTarget)
        -- Clean up old solo status entries
        local now = GetTime()
        for guid, status in pairs(soloStatusByGUID) do
            if now - status.lastChecked > SOLO_STATUS_TIMEOUT then
                soloStatusByGUID[guid] = nil
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Also clear on reloads/teleports/loads
        wipeTable(helpersByTarget)
        wipeTable(soloStatusByGUID)
    end
end)

-- Optional: expose a tiny debug helper (comment out for release)
-- /dump _PlayerIsSolo_Debug()
function _PlayerIsSolo_Debug()
    local tGUID = UnitGUID("target")
    return {
        targetGUID = tGUID,
        helpers = tGUID and helpersByTarget[tGUID] or nil,
    }
end
