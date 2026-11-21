local addonName, addon = ...

-- =========================================================
-- Forever addon restrictions
--
-- Forever identity is addon.IsForeverClient() (Interface 16xxx) in Utils\Compat.lua.
-- This file only records capability flags for that client. TOC still gates the load with
-- AllowLoadGameType forever/mainline; the IsForeverClient guard below also keeps real
-- retail from picking up these flags if the mainline TOC tag loads this file there.
--
-- Confirmed by probe on this client:
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
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

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

-- Forever is realmless: GetRealmName() returns "" (1.60.1.71037+; earlier builds returned an internal
-- shard label like "CAMWOW US2 Realm 3 PvE"). LibP2PDB falls back to the C_GameRules ruleset for its
-- own realm string. Leaderboard and guild-first scope use
-- addon.GetPlayerRealmLabel() so peers share a ruleset (Normal / PvP / Roleplay / Roleplay PvP).
-- UnitName's second return is a surname, not a realm — never use it as one.
--
-- Enum.AddOnRestrictionType.Chat, when active, blocks SendAddonMessage. Leaderboard sync
-- cannot run then; PublishLocal returns false quietly.
--
-- Forever also does not allow SendAddonMessage on custom chat channels. Open-world sync
-- uses Utils\CommChannel.lua (rotating hca###### from GetServerTime()/1337 + seed
-- fallbacks) plus Utils\ChatBroadcast.lua (LibP2PDB RegisterChatChannel /
-- BroadcastKeyChatChannel via SendChatMessage, flushed from hardware events) on
-- Classic, TBC, and Forever. Stock GUILD/PARTY/RAID/YELL BroadcastKey remains.
-- Do not use NewDatabase({ channels = ... }) for this.
--
-- Sender verification: since 1.60.1.71037 GetPlayerInfoByGUID returns an empty realm, so
-- LibP2PDB's VerifySenderPeerID compares bare "First Surname" names and passes across shards.
-- (Earlier builds returned shard labels that never matched across shards.)
--
-- Whispers: Forever reorders addon whispers sent in the same instant, so AceComm reassembles
-- multi-part gossip chunks out of order (corrupt). Forever\WhisperPacing.lua spaces HCA
-- whisper parts 0.1s apart; rowsPerChunk stays at the Classic values.
-- Whispers cannot cross rulesets. LeaderboardSync's onIsPeerAllowed keeps players whose row
-- carries another ruleset out of the LibP2PDB peer list (their presence still applies); players
-- with no row yet are tried and left to LibP2PDB's normal failure/timeout handling.
--
-- Combat: ShowUIPanel/HideUIPanel on LegacySystemFrame are blocked for addon code, but the
-- frame is not protected (and Blizzard_LegacySystem loads in combat). Forever\LegacyFramePanel.lua
-- uses plain Show/Hide in combat, anchors the frame itself if the panel manager never has, and
-- adds it to UISpecialFrames so Escape closes it.
