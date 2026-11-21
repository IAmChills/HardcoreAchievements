# TODO List

# Useful Links

### Dungeon IDs / Encounters

https://warcraft.wiki.gg/wiki/DungeonEncounterID

### Discord link generator

https://linkbreakers.com/qr-code-generator/discord

## Active Tasks

### Leaderboard sync: open-world via chat channels

**Current:** HCA owns local `players`/`presence` writes + stock `BroadcastKey` (GUILD/PARTY/RAID/YELL) and rotating `hca######` presence-only chat. LibP2PDB owns peer discovery/convergence via `BroadcastPresence` + `SyncDatabase` every **180s** (`peerTimeout = 400`). Prefix `HCALB`. Do not use `NewDatabase({ channels = ... })`.

- [ ] **Forever: per-ruleset peer list (preferred over a per-ruleset channel)** — keep the shared rotating channel so cross-ruleset presence still shows players online, but keep only same-ruleset senders in LibP2PDB's peer list so `SyncDatabase` never whispers across rulesets ("No player named ..." failures). Needs a small lib patch: a peer filter checked in `Private:AddPeer` (message/row still applied, peer not inserted). Ruleset source options:
  - Reactive: on `ERR_CHAT_PLAYER_NOT_FOUND_S` for a peer, block that name from the peer list for the session and hide the system message (no schema change; one failed whisper per foreign peer per session).
  - Proactive: optional `ruleset` field on the presence row (schema change; verify older clients accept it).
  - Caveat: cross-ruleset rows stay stale (players rows never cross rulesets); only presence/online status updates.
- [ ] *(Alternative, not preferred)* **Forever: per-ruleset rotating channel** — mix the ruleset (`GetPlayerRulesetLabel`) into `DeriveChannel` in `Utils/CommChannel.lua` on Forever only. Simpler, but hides cross-ruleset players from the leaderboard entirely.
- [ ] **Report upstream (LibP2PDB):**
  - `GetRealmName()` is `""` on Forever → load-time assert; patched locally with C_GameRules ruleset fallback (`GetPlayerRealm`)
  - `UIParentLoadAddOn` missing on Forever when `DEBUG = true` (renamed `LoadAddOnWithErrorHandling`); patched locally to use whichever exists
  - Self-message filter compares sender to `UnitName("player")` (first name only on Forever), so own broadcasts are processed; patched locally with `playerFullName` (`GetUnitName("player", false)`)
  - Forever reorders addon whispers sent in the same instant, corrupting multi-part AceComm messages; worked around locally by pacing HCA whisper parts 0.1s apart (`Forever/WhisperPacing.lua`). Digest responses also grow with row count
  - Whispers cannot cross Forever rulesets; peers on other rulesets cause repeated "No player named" errors

### Forever dungeon catalog: missing `requiredMapId`

Fill from `/run local n,t,d,dn,p,_,_,id=GetInstanceInfo(); print("name: "..n,"mapId: "..id)` while inside each dungeon. `requiredMapId = 000` → Lua `0` and blocks kill credit via `IsOnRequiredMap`. Same ids must be copied into `RareLootKills.lua` `mapId` for Forever rares (currently `nil`).

- [ ] Excavation Site: Wetlands (`ESW`) — `requiredMapId`
- [ ] City of Dalaran (`COD`) — `requiredMapId`
- [ ] The Drowned City (`TDC`) — `requiredMapId` (+ RareLoot mapId for Gill / Umbra / Braxton)
- [ ] Krol'dok Stronghold (`KS`) — `requiredMapId` (+ RareLoot mapId for Bossman Toof)
- [ ] Alcaz Prison (`AP`) — `requiredMapId`
- [ ] Blackmaw Hold (`BMH`) — `requiredMapId` (+ RareLoot mapId for Moontouched Wanderer / Gortek)
- [ ] Shaper's Terrace (`SHT`) — `requiredMapId` (+ RareLoot mapId for King Op)

### Forever: missing encounter / NPC ids (no rare-loot coverage yet)

- [ ] Shaper's Terrace — Ravasaur Hunters any-of still `{0000,0000,0000}` — real NPC ids + encounter id
- [ ] Shaper's Terrace — King Op (`261993`) — empty `RareLootKills` items; need distinctive drops and/or encounter id

**Notes**

- Avatar of Hakkar (`8443` / encounter `492`): Forever only. Classic/TBC leave commented (buggy kill credit).
- Moira shares Emperor encounter `245`; keep loot/name-only, never `{9019, 8929}` on the encounter id. Post-quest form `10076` (High Priestess) canonicalizes to `8929`.

## Bugs

- Molten Core bosses?

## Quests

 - 

## Explorer Achievements

- Several Forever zones

## Titles? (I can fake titles in tooltips / chat but that's it. Requires addon)

- The Eager Explorer title
- Hardcore Legend
- Tier I – The Brave
- Tier II – The Reckless

## Challenges (heavy code, not opposed)

- No pet hunter
- Protection warrior
- Monk build
- Cloth paladin

## Miscellaneous

- Pirate Software Achieve 
  - hearth out of an instance while in combat
- Destroy your light of elune (giga hardcore achievement)

## Class challenges

- paladin, hunter, mage (likely not do-able with the nerfs)

## Helpful Code Snippets

### Class-colored text

```lua
|c" .. select(4, GetClassColor(select(2, UnitClass("player")))) .. "PlayerName|r
```

### Print player's assigned group role

```lua
/script print(UnitGroupRolesAssigned('player'))
```

### Reset Progress or Achievement in database

```lua
/run HardcoreAchievementsCharDB[UnitGUID("player")].achievements["Test"]=nil HardcoreAchievementsCharDB[UnitGUID("player")].progress["Test"]=nil ReloadUI()
```

### Display Toast

```lua
/run HardcoreAchievementsToast(nil, "Test Toast", 10, "TestAchievement");HardcoreAchievementsShowGuildFirstToast("Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\guild_first.png", "Guild First Test Toast", 100, "TestAchievement");
```

### Clear Logs

```lua
/run HardcoreAchievementsCharDB[UnitGUID("player")].eventLogLines={} ReloadUI()
```

### Get Dungeon Info

```lua
/dump GetInstanceInfo()
/run local n,t,d,dn,p,_,_,id=GetInstanceInfo(); print("name: "..n,"type: "..t,"difficulty: "..dn,"maxPlayers: "..p,"mapId: ".. id)
```

### Check chat channel rotation time

```lua
/run local t=GetServerTime();print("Next rotation in:",1337-t%1337,"seconds")
```