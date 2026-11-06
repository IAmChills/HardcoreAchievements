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
-- a secret in a variable or table field and pass it along, but comparing, doing arithmetic, or using one
-- as a table key or index is a hard error. Concatenating a secret string is allowed; type() is allowed.
--
-- Creature GUIDs are secret on addon-restricted maps (dungeons and raids) and plain in the open world.
-- Player, party, and raid GUIDs are not secret. UnitThreatSituation's number can be secret, but nil still
-- means "not on the threat table", so type(status) == "number" is a legal presence test. UnitLevel,
-- UnitIsTapDenied, UnitIsPlayer, and UnitPlayerControlled are plain. UnitInRange is always secret.
--
-- Forever\KillTracking.lua replaces PlayerIsSolo and IsGroupEligibleForAchievement before the shared
-- achievement code captures them, so the Classic percentage comparisons never run on this client.

addon.Restrictions = addon.Restrictions or {}

-- Threat percentages cannot be used in Lua logic during combat. Any replacement for the damage-based
-- solo verification has to reach its verdict without comparing threat numbers.
addon.Restrictions.secretValues = true

-- No combat log. PARTY_KILL still exists as its own frame event (attacker GUID, target GUID); whether
-- this client accepted the registration is recorded by Forever\KillTracking.lua.
addon.Restrictions.combatLog = true
addon.Restrictions.partyKillEvent = false
addon.Restrictions.encounterEndEvent = false
