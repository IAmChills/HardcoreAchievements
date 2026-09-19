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
--
-- Requiring both rejected every foreign kill in the probe while accepting group kills where the player
-- held only partial threat. Presence is deliberately the test rather than a threat percentage: socially
-- pulled mobs report status 0 rather than 3, and percentages can be secret values that cannot legally
-- be compared.
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

-- =========================================================
-- Sampling while mobs are alive
-- =========================================================

--- Records tap status and engagement for one live mob.
--- everEngaged is monotonic: threat legitimately reads nil early in a fight and disappears on death, so
--- forgetting it would throw away the only proof of involvement we will ever get.
local function Sample(unit)
    if type(unit) ~= "string" or not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if type(guid) ~= "string" or guid:sub(1, 9) ~= "Creature-" then return end

    local now = GetTime()
    local record = seen[guid]
    if not record then
        record = { npcId = select(6, strsplit("-", guid)) }
        seen[guid] = record
    elseif record.lastSampledAt and (now - record.lastSampledAt) < SAMPLE_THROTTLE_SEC then
        return
    end

    record.lastSampledAt = now
    record.lastSeenAt = now
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
    Sample("pettarget")

    for i = 1, 8 do
        Sample("boss" .. i)
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, (GetNumGroupMembers() or 0) do
        Sample(prefix .. i .. "target")
        Sample(prefix .. i .. "pettarget")
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

    local engaged = (record and record.everEngaged) or false
    if not engaged and unit then
        engaged = GroupIsOnThreatTable(unit)
    end

    seen[guid] = nil

    -- No reading at all means a mob that died somewhere we were never looking, which is not ours.
    if tapDenied == nil then
        return
    end
    if tapDenied then
        return
    end
    if not engaged then
        Debug("ignoring " .. guid .. ": untapped but nobody in the group was on its threat table")
        return
    end

    if addon.AwardKillFromExternalSource then
        addon.AwardKillFromExternalSource(guid)
    end
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

-- UNIT_COMBAT only reports units with nameplates in range, so a mob the player is fighting off-screen
-- would otherwise never be sampled. This sweep is the safety net; it is cheap because Sample throttles
-- per GUID and stops querying threat once a mob is known to be engaged.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(COMBAT_SAMPLE_INTERVAL_SEC, function()
        if UnitAffectingCombat("player") then
            SampleCombatUnits()
        end
    end)
end
