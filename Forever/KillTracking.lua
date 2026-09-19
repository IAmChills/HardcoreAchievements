local addonName, addon = ...

-- =========================================================
-- Kill credit without the combat log (Forever)
--
-- Forever blocks COMBAT_LOG_EVENT_UNFILTERED, so PARTY_KILL never arrives and nothing tells us who
-- killed what. It does fire a standalone UNIT_DIED carrying the victim's GUID, which is the same
-- destGUID the combat log used to provide, so the npcId and the existing award path survive intact.
--
-- What has to be rebuilt is credit. Two signals, both established by probe on this client:
--
--   UnitIsTapDenied(unit) == false   we or our group hold the tag. Necessary but not sufficient: an
--                                    untapped mob also reads false, so a mob killed by another NPC
--                                    looks identical to one of ours.
--   on the threat table               the player or a group member appears on the mob's threat table,
--                                    which is positive proof of involvement.
--   held as a group member's target   equally positive proof, and the only one that survives a fight the
--                                    player takes no part in. Threat readings for units other than the
--                                    player cannot be relied on here, and a mob's threat table is empty
--                                    by the time it dies, so a kill made entirely by a party member left
--                                    no evidence at all under the two signals above.
--
-- Requiring tap plus one of the engagement signals rejected every foreign kill in the probe while
-- accepting group kills where the player held only partial threat. Presence is deliberately the test
-- rather than a threat percentage: socially pulled mobs report status 0 rather than 3, and percentages
-- can be secret values that cannot legally be compared.
--
-- Timing note that shapes the whole file: a mob's nameplate is already gone by the time UNIT_DIED
-- fires, so nameplates never resolve a dying GUID. In the probe every genuine kill resolved through
-- target, mouseover or party1target instead. Nameplates are still worth sampling while mobs are alive,
-- which is what the cache below is for.
-- =========================================================

-- Real retail permits the combat log, so the normal path is better there. Stand down unless the client
-- has actually had it taken away.
if not (addon and addon.Restrictions and addon.Restrictions.combatLog) then
    return
end

local SAMPLE_THROTTLE_SEC = 0.25
local RECORD_LIFETIME_SEC = 60
local PRUNE_INTERVAL_SEC = 30
local COMBAT_SAMPLE_INTERVAL_SEC = 0.5

local issecretvalue = issecretvalue
local UnitIsTapDenied = UnitIsTapDenied
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitIsDead = UnitIsDead

-- guid -> { npcId, tapDenied, everEngaged, lastSeenAt, lastSampledAt }
local seen = {}
local lastPruneAt = 0

local function Debug(message)
    if addon.DebugPrint then
        addon.DebugPrint("[ForeverKills] " .. message)
    end
end

-- =========================================================
-- Signals
-- =========================================================

--- True when `unit` appears on `mob`'s threat table at all.
--- Presence is the only granularity needed, and it is the one question a secret value can still answer:
--- a secret status is by definition not nil, so its secrecy alone proves the unit is on the table.
local function IsOnThreatTable(unit, mob)
    if not UnitDetailedThreatSituation then
        return false
    end

    local ok, _, status = pcall(UnitDetailedThreatSituation, unit, mob)
    if not ok then
        return false
    end
    if issecretvalue and issecretvalue(status) then
        return true
    end
    return status ~= nil
end

--- Whether the player or anyone in their group is on `mob`'s threat table. Group members count because
--- the player may never have targeted or damaged a mob the group killed.
local function GroupIsOnThreatTable(mob)
    if IsOnThreatTable("player", mob) then
        return true
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") and IsOnThreatTable(unit, mob) then
            return true
        end
    end

    return false
end

--- Whether this GUID is currently a group member's target or pet target.
--- The player's own target is deliberately excluded: looking at a corpse is not proof the group killed it.
--- A member still targeting that corpse after a one-shot is the only engagement signal UNIT_DIED still has,
--- because the threat table is already empty by then.
local function IsGuidHeldByGroup(guid)
    if type(guid) ~= "string" then
        return false
    end
    local function matches(token)
        return UnitExists(token) and UnitGUID(token) == guid
    end
    if matches("pettarget") then
        return true
    end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        if matches(prefix .. i .. "target") or matches(prefix .. i .. "pettarget") then
            return true
        end
    end
    return false
end

--- Whether the player or anyone in their group is fighting anything at all.
--- The sweep below used to run only while the player personally was in combat, which is exactly wrong for
--- the case it needs to cover: when a party member fights a mob alone the player is out of combat, so the
--- mob was never sampled and its death arrived with nothing on record.
local function GroupIsInCombat()
    if UnitAffectingCombat("player") then
        return true
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        local unit = prefix .. i
        if UnitExists(unit) and UnitAffectingCombat(unit) then
            return true
        end
    end

    return false
end

-- =========================================================
-- Sampling while mobs are alive
-- =========================================================

--- Records tap status and engagement for one live mob.
--- everEngaged is monotonic: threat legitimately reads nil early in a fight and disappears on death, so
--- forgetting it would throw away the only proof of involvement we will ever get.
--- Pass heldByGroup when `unit` was reached through a group member's target or pet target, which is itself
--- proof that a member of the group is fighting it.
local function Sample(unit, heldByGroup)
    if type(unit) ~= "string" or not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if type(guid) ~= "string" or guid:sub(1, 9) ~= "Creature-" then return end

    local now = GetTime()
    local record = seen[guid]
    if not record then
        record = { npcId = select(6, strsplit("-", guid)) }
        seen[guid] = record
    end
    record.lastSeenAt = now

    -- Player-target samples do not pass heldByGroup, but the same GUID may already be a member's target.
    if not heldByGroup then
        heldByGroup = IsGuidHeldByGroup(guid)
    end

    -- Deliberately ahead of the throttle, because it is two cheap calls and because the player usually has
    -- the same mob selected as the party member fighting it. Sampling that as a plain "target" first would
    -- otherwise take the throttle slot on every pass and this signal would never get to run.
    -- UnitCanAttack is not required: Forever can report a party-tagged mob as tap-denied to the player,
    -- and a denied mob is often not attackable, which is exactly the party-kill case we have to record.
    if not record.everEngaged and heldByGroup and not UnitIsDead(unit) then
        record.everEngaged = true
    end

    if record.lastSampledAt and (now - record.lastSampledAt) < SAMPLE_THROTTLE_SEC then
        return
    end
    record.lastSampledAt = now

    record.tapDenied = UnitIsTapDenied and UnitIsTapDenied(unit) or false

    -- Once engaged, stop asking. This is the expensive call and the answer cannot become "no".
    if not record.everEngaged and GroupIsOnThreatTable(unit) then
        record.everEngaged = true
    end
end

--- Sweeps the units worth sampling during combat, for mobs that never become the player's target.
local function SampleCombatUnits()
    Sample("target")
    Sample("targettarget")
    Sample("mouseover")
    Sample("pettarget", true)

    for i = 1, 8 do
        Sample("boss" .. i)
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        local member = prefix .. i
        if UnitExists(member) then
            Sample(member .. "target", true)
            Sample(member .. "pettarget", true)
        end
    end

    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
    for _, plate in ipairs(plates or {}) do
        if plate.namePlateUnitToken then
            Sample(plate.namePlateUnitToken)
        end
    end
end

local function Prune(now)
    if (now - lastPruneAt) < PRUNE_INTERVAL_SEC then return end
    lastPruneAt = now

    for guid, record in pairs(seen) do
        if not record.lastSeenAt or (now - record.lastSeenAt) > RECORD_LIFETIME_SEC then
            seen[guid] = nil
        end
    end
end

-- =========================================================
-- Death handling
-- =========================================================

--- Finds a unit token still pointing at `guid`. Ordered by how likely each is to be the mob we just
--- killed; nameplates are last and, per the probe, never actually win at this point.
local function ResolveUnitByGUID(guid)
    local candidates = { "target", "mouseover", "focus", "pettarget" }

    for i = 1, 8 do
        candidates[#candidates + 1] = "boss" .. i
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        candidates[#candidates + 1] = prefix .. i .. "target"
        candidates[#candidates + 1] = prefix .. i .. "pettarget"
    end

    for _, unit in ipairs(candidates) do
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end

    return nil
end

local function OnUnitDied(guid)
    if type(guid) ~= "string" or guid:sub(1, 9) ~= "Creature-" then return end

    local record = seen[guid]

    -- A corpse stays queryable for a moment, so prefer a reading taken now over a cached one.
    local unit = ResolveUnitByGUID(guid)

    local tapDenied
    if unit and UnitIsTapDenied then
        tapDenied = UnitIsTapDenied(unit)
    elseif record then
        tapDenied = record.tapDenied
    end

    local engaged = (record and record.everEngaged) or IsGuidHeldByGroup(guid)
    if not engaged and unit then
        engaged = GroupIsOnThreatTable(unit)
    end

    seen[guid] = nil

    -- Group involvement is enough. Forever's tap is not shared with the party: a member's tag reads as
    -- tapDenied for the player, so requiring tapDenied == false dropped every party kill even when the
    -- player had the mob targeted. A foreign kill never sets everEngaged and is never a member's target.
    if engaged then
        if addon.AwardKillFromExternalSource then
            addon.AwardKillFromExternalSource(guid)
        end
        return
    end

    -- No reading at all means a mob that died somewhere we were never looking, which is not ours.
    if tapDenied == nil then
        return
    end
    if tapDenied then
        Debug("ignoring " .. guid .. ": tap denied and the group never engaged it")
        return
    end
    Debug("ignoring " .. guid .. ": untapped but nobody in the group was on its threat table")
end

-- =========================================================
-- Events
-- =========================================================

local tracker = CreateFrame("Frame")
tracker:RegisterEvent("UNIT_DIED")
tracker:RegisterEvent("UNIT_COMBAT")
tracker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
tracker:RegisterEvent("PLAYER_TARGET_CHANGED")
tracker:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

tracker:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_DIED" then
        OnUnitDied(arg1)
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        Sample("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Sample("mouseover")
    else
        -- UNIT_COMBAT and NAME_PLATE_UNIT_ADDED both pass the affected unit as arg1.
        Sample(arg1)
    end

    Prune(GetTime())
end)

-- UNIT_COMBAT only reports units with nameplates in range, so a mob being fought off-screen would
-- otherwise never be sampled, and it is the group's targets that carry the engagement signal. This sweep
-- is the safety net; it is cheap because Sample throttles per GUID and stops querying threat once a mob is
-- known to be engaged.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(COMBAT_SAMPLE_INTERVAL_SEC, function()
        if GroupIsInCombat() then
            SampleCombatUnits()
        end
    end)
end
