# Forever combat tracking audit

What Classic/TBC decides from the combat log, what Forever can still see, and what this addon does about the difference. Forever-only code lives in `Forever/`. The Classic and TBC combat-log path in `HardcoreAchievements.lua` is unchanged.

Sources for the API column: Blizzard's generated 12.x documentation (`UnitDocumentation.lua`, `SecretPredicatesDocumentation.lua`, `EncounterInfoDocumentation.lua`) and the warcraft.wiki.gg pages for `PARTY_KILL`, `UNIT_DIED`, `ENCOUNTER_END`, and Patch 1.60.1. Rows marked **needs `/hca probe`** are documented one way and must be confirmed on the Forever client before treating them as settled.

## How a kill is awarded now

**Open world.** `PARTY_KILL` (attacker GUID, target GUID) awards the kill when the target is a tracked creature and the attacker is the player, their pet, or a group member or that member's pet. You do not need to target the mob or be on its threat table. A secret attacker still counts: the event itself means the party was credited, and it is not treated as assistance. `UNIT_DIED` awards only when that creature was already seen with the player, their pet, or the group on its threat table, and does not log nearby deaths of the same npc id with no group threat. A denied tap drops the kill only when the player or their pet got the killing blow.

**Solo vs assisted.** A temporary record is kept for achievement NPCs only. It is thrown away about 10 seconds after the mob dies and is never saved. The kill stays **solo** unless one of these was positively seen:

- a party or raid member, or their pet, on the mob's threat table
- the mob's own target being a player or a player-controlled minion from outside the group
- the `PARTY_KILL` attacker being a group member or their pet

Being grouped is not assistance. Another player targeting the mob is not assistance. A secret or unreadable value is not assistance. The player's own pet is the player's own participation. If Midnight hides an outsider's damage, the kill stays solo. That is the honor-system rule.

**Level and group size.** The player's level and an achievement's explicit party-size or raid-size limit are always checked. Another player's level is checked only when that player, or their pet, was one of the participants above. A level 80 friend in another zone does not fail a level-capped solo kill.

**Dungeons.** `ENCOUNTER_END` with `success == 1` credits each `encounterUnitStatus` entry whose `creatureID` is tracked and whose `remainingHealthPercent` is 0. The existing dungeon kill tracker then checks the player's level and party size, and `StoreEntryLevelSnapshot()` records average party level for the tooltip. Other members' levels do not fail a base dungeon clear. This pass does not add or remove the variation rules already in `Forever/DungeonCommon.lua`.

**Raids.** Still `BOSS_KILL` to `processBossKillByEncounterID`. No participation or solo check, and no new group-level rule.

A GUID kill and an encounter kill for the same npc id inside 10 seconds count once. Two different creatures of the same npc id both still count, because that window is only checked across the two paths.

## Mechanism comparison

| Mechanic | Classic / TBC | Forever now | Midnight status |
| --- | --- | --- | --- |
| Who got the kill | CLEU `PARTY_KILL`, plus overkill on the group's damage events | Standalone `PARTY_KILL`. `UNIT_DIED` only with a recorded threat presence | CLEU registration errors. `PARTY_KILL` is a frame event (`attackerGUID`, `targetGUID`), secret only when that unit's identity is secret. **Confirm registration with `/hca probe`.** |
| Damage and overkill | CLEU damage subevents set `npcsInCombat` and catch pet/DoT kills | Not available. Pet and DoT kills fall through to `UNIT_DIED` if threat was seen, otherwise to `PARTY_KILL` if it fires for them | CLEU gone. No replacement that reports damage amounts to addons. |
| External players | CLEU source GUID stored by `GetExternalPlayersForNPC`, then a 10% threat test | Only if the mob is targeting them, or they are otherwise identified without reading secret numbers | No damage events. Their threat percentage cannot be required. |
| Threat percentages | Above 10% fails solo or a level cap; above 90% supports solo | Not used. Presence on the table is enough, and only for someone positively queried | `UnitDetailedThreatSituation` can return secrets (`SecretWhenUnitThreatValuesRestricted`). `type(status) == "number"` is legal and means "on the table"; nil means not. Whether open-world numbers are actually secret **needs `/hca probe`**. |
| Tap | `UnitIsTapDenied` stored while the player is hitting their target | Same API. Denies credit only for the player's or their pet's own killing blow | Plain boolean. No secret predicate. |
| Solo while grouped | Fails when a group member is `UnitInRange`, or has threat | Allowed. Fails only when participation was detected | `UnitInRange` is always secret, so the Classic fallback would error or lie. It is not used. |
| Grouped overleveled player who never hits the mob | Can fail the level cap when threat cannot be checked | Does not fail it | Honor system. Their level is applied only after participation is detected. |
| Dungeon boss identity | Creature GUID from CLEU, in-instance deaths count | `ENCOUNTER_END` `creatureID` when the GUID is secret; GUID path still works when it is plain | Creature GUIDs are secret on restricted maps. `encounterUnitStatus` was added in 12.0.7 and is documented as non-secret. **Confirm the payload with a dungeon kill.** |
| Average party level | `StoreEntryLevelSnapshot()` on boss credit; tooltip only | Same function, same `avgPartyLevel` / `entryPartySize` progress keys. Not an eligibility check | Player and party GUIDs and `UnitLevel` are plain, so the existing snapshot still works inside an instance. |
| Raid boss | `BOSS_KILL` encounter id | Unchanged | `BOSS_KILL` has no secret predicate. |
| Secret GUID handling | Not applicable | Refused before `strsplit`, substring, table key, or SavedVariables | Comparing, indexing, or using a secret as a key is a Lua error. `type()` and `issecretvalue()` are safe. |

## What was wrong in the previous Forever attempt

These were confirmed by reading the code, not by assuming the comments were right.

- A group member targeting a live mob, or still targeting its corpse, set `everEngaged` and awarded the kill. Tap was then ignored.
- A secret threat status was treated as proof the unit was on the threat table. A secret value is not a readable "yes".
- `IsGroupEligibleForAchievement` boolean-tested `UnitInRange` (always secret) and compared threat percentages. With an overleveled party member nearby that errors instead of deciding.
- `GetExternalPlayersForNPC` only fills from the combat log, so on Forever it was always empty and outside help was treated as absent.
- `PlayerIsSolo` turned "in a group" and "threat number is secret" into "not solo".
- Parsing a creature GUID with `strsplit` or `guid:sub` errors when the GUID is secret, which is the documented state inside a dungeon.

## What cannot be verified

- Damage dealt by a player who never gets targeted by the mob and is not in the group. The kill stays solo.
- The owner level of another player's pet or guardian, unless that owner is themselves visible. The pet still counts as assistance, but it cannot fail a level cap without a level.
- Whether `PARTY_KILL` fires when a pet lands the killing blow. If it does not, `UNIT_DIED` still credits the kill when the pet or owner was seen on the threat table.
- Dungeon bosses on a client whose `ENCOUNTER_END` has no `encounterUnitStatus`. The addon logs that once and does not guess an encounter-id mapping. Credit then depends on creature GUIDs being readable.
- Syncing dungeon boss credit to other party members. Addon messages are blocked while the Chat restriction is active, and the send is skipped rather than attempted.

## Diagnostics

- `/hca probe` prints instance state, whether `PARTY_KILL` and `ENCOUNTER_END` registered, which addon restrictions are active, and the type or secrecy of the target GUID, tap, combat, and threat returns for the player, pet, and `party1`. It never compares a threat number.
- `/hca killdebug` logs each credited or rejected kill to chat and the event log (`/hca log`). It does not write SavedVariables of its own.

Useful checks: a solo tag and kill; a one-shot; a party member killing a mob you never target (credit if PARTY_KILL is in range); a party member only targeting a mob someone else kills (no credit); an outsider the mob actually swings at (assisted, and ineligible when their level is over the cap); a dungeon boss (one toast, average party level on the tooltip); two quick kills of the same non-boss npc (both count).

## Files

- `Forever/KillTracking.lua` replaces solo and group eligibility before shared code captures them, and only loads when `Restrictions.combatLog` is set.
- `Forever/EncounterKills.lua` turns a successful encounter into the existing dungeon kill tracker.
- `Forever/Diagnostics.lua` is `/hca probe` and `/hca killdebug`.
- `HardcoreAchievements.lua` accepts an npc id hint, refuses secret GUIDs, and dedupes the GUID and encounter paths. Its combat-log branch is unchanged.
- `Utils/Compat.lua`, `Achievements/Common.lua`, `Forever/DungeonCommon.lua`, and `Achievements/FirstKillRareQuestLoot.lua` parse GUIDs through `addon.ParseCreatureNpcId`. For a plain GUID that is the same strsplit result as before.
