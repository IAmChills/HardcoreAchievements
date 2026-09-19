local addonName, addon = ...

-- =========================================================
-- Forever addon restrictions
--
-- Forever carries over retail's "addon disarmament" rules. Confirmed by probe on this client:
--
--   COMBAT_LOG_EVENT_UNFILTERED    blocked
--   CHAT_MSG_COMBAT_HOSTILE_DEATH  blocked
--   UNIT_DIED                      allowed
--   UNIT_COMBAT                    allowed
--   UNIT_HEALTH                    allowed
--   BOSS_KILL                      allowed
--   ENCOUNTER_START / ENCOUNTER_END allowed
--   PLAYER_REGEN_DISABLED          allowed
--   CHAT_MSG_LOOT                  allowed
--
-- These flags exist to switch on replacement code paths, not to silence errors. The blocked
-- registrations are deliberately left in place so the gap stays visible instead of turning into
-- achievements that quietly never progress.
--
-- This has to be decided by the TOC rather than in Lua: GetExpansionLevel reports account entitlement
-- (0 here), and every capability probe that separates Forever from real retail also matches real
-- retail, where the combat log is permitted. So this file is gated to Forever's game type.
-- =========================================================

-- Separately from blocked events, this client has the 12.0 secret value system. Tainted code may store
-- a secret in a variable or table field and pass it along, but comparing, concatenating or indexing with
-- one is a hard error. Confirmed by probe: UnitDetailedThreatSituation returns secrets during combat.
-- Per Blizzard's docs UnitName does the same for non-player units in combat, and UnitHealth/UnitPower
-- can too, so anything that reads combat state needs to expect it.
--
-- Test with issecretvalue(v) before touching a value, and C_Secrets.ShouldUnitThreatValuesBeSecret to
-- decide up front whether threat logic is worth attempting at all.
--
-- This is why the combat log being blocked is currently hiding a second problem rather than being the
-- whole story: Functions\PlayerIsSolo.lua and Functions\IsGroupEligibleForAchievement.lua compare threat
-- percentages numerically, and those comparisons only run off the back of combat log events. Restore kill
-- tracking without guarding them and they will start erroring in combat.

addon.Restrictions = addon.Restrictions or {}

-- Threat percentages cannot be used in Lua logic during combat. Any replacement for the damage-based
-- solo verification has to reach its verdict without comparing threat numbers.
addon.Restrictions.secretValues = true

-- No PARTY_KILL and no damage-event attribution. Kill credit, overkill checks, and the external-player
-- solo verification in Functions\PlayerIsSolo.lua all have to be rebuilt from the allowed events above.
addon.Restrictions.combatLog = true
