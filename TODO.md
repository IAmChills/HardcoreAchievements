# TODO List

# Useful Links

### Dungeon IDs / Encounters

https://warcraft.wiki.gg/wiki/DungeonEncounterID

### Discord link generator

https://linkbreakers.com/qr-code-generator/discord

## Active Tasks

### Forever leaderboard sync: open-world via chat channels (not started)

**Current:** LibP2PDB stock GUILD/PARTY/RAID/YELL only (all clients). Forever blocks `SendAddonMessage` on custom channels, so `desc.channels` / addon-CHANNEL is a dead end — that wiring was removed.

**Future (Hardcore Mode style):** real chat channel + LibP2PDB `RegisterChatChannel` / `BroadcastKeyChatChannel` (`SendChatMessage`, not addon CHANNEL). Needs join/leave, optional channel rotation against admin locks, hardware-event sends, and 255-byte payload limits. Do not use `NewDatabase({ channels = ... })` for this.

- [ ] Design Forever chat-channel join + register with LibP2PDB

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