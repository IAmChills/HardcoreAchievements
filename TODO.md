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
- [ ] Broadcast on hardware-safe events; keep GUILD/PARTY/RAID/YELL as fallback
- [ ] Classic/TBC unchanged (no chat-channel sync required)

### Forever dungeon catalog: missing `requiredMapId` / icons
Fill from `/run local n,t,d,dn,p,_,_,id=GetInstanceInfo(); print("name: "..n,"mapId: "..id)` while inside each dungeon. Icons are file IDs (or `Interface\\...` paths); `000` / `000000` placeholders break UI. `requiredMapId = 000` → Lua `0` and blocks kill credit via `IsOnRequiredMap`.

- [ ] Hall of Thanes (`HOT`)
  - [ ] `requiredMapId`
- [ ] Excavation Site: Wetlands (`ESW`)
  - [ ] `requiredMapId`
- [ ] City of Dalaran (`COD`)
  - [ ] `requiredMapId`
- [ ] The Drowned City (`TDC`)
  - [ ] `requiredMapId`
- [ ] Krol'dok Stronghold (`KS`)
  - [ ] `requiredMapId`
- [ ] Alcaz Prison (`AP`)
  - [ ] `requiredMapId`
- [ ] Blackmaw Hold (`BMH`)
  - [ ] `requiredMapId`
- [ ] Shaper's Terrace (`SHT`)
  - [ ] `requiredMapId`

### Forever dungeon/raid: remaining `ENCOUNTER_END` id → NPC maps
`GetBossName` now has all Forever catalog NPC names. Name fallback works when `encounterName` matches; id maps preferred. Use `/hca killdebug on` + pull. Raids still on `BOSS_KILL` via `RaidCommon` (Onyxia active).

**Forever-original (need live killdebug; no classic wiki ids)**
- [ ] Hall of Thanes
  - [ ] Faldrim Anvilmar (261306)
  - [ ] Magmatus (261316)
  - [ ] Plunder (261311)
  - [ ] Durgen Dirgehammer (261319)
- [ ] Excavation Site: Wetlands
  - [ ] Saltspine (260322)
  - [ ] Shadetooth (260325)
  - [ ] Relic Guardian (260326)
- [ ] Ruins of Lordaeron
  - [ ] Lordaeron Captain (255699) — extra credit
- [ ] City of Dalaran
  - [ ] Atrexis the Grave Knight (247126)
  - [ ] Arcane Anomaly (245999)
  - [ ] Fel Ancient (246003)
  - [ ] Unstable Sentinel (246017)
  - [ ] Mana Devourer (246008)
  - [ ] Arcanic Enigma (246016)
  - [ ] Shade of the Archmage (246020)
  - [ ] Lyn the Ignored (247032)
- [ ] The Drowned City
  - [ ] Zul'alai (258905)
  - [ ] Var'taka (258924)
  - [ ] Captain Dreadrise (260042)
  - [ ] Deathless Marrow (269586)
  - [ ] Primeval Elemental (263886)
  - [ ] Min'loth the Serpent (260274)
  - [ ] Gill (264177)
  - [ ] Umbra (264172)
  - [ ] "Pyromancer" Braxton (260468)
- [ ] Krol'dok Stronghold
  - [ ] Slavecrusher Grox (258966)
  - [ ] Twilight Commander Zarmok (258972)
  - [ ] War Handler Ashka (259281)
  - [ ] Nar'gurk (258964)
  - [ ] Bossman Toof (264773)
  - [ ] Overlord Mugg (258968)
- [ ] Alcaz Prison
  - [ ] Overseer Wrex (255391)
  - [ ] The Questioner (256236)
  - [ ] Tidemistress Ca'zass (255997)
  - [ ] Katerina the Cleaner (257016)
  - [ ] Blazeroar (255702)
- [ ] Blackmaw Hold
  - [ ] Impaan the Imprisoner (247206)
  - [ ] Bonesnout the Unbroken (247198)
  - [ ] Withermaw (247195)
  - [ ] Elder Shaman Bloodmane (247209)
  - [ ] Blackmaw Behemoth (247207)
  - [ ] Unbound Spirit (247231)
  - [ ] Varrox Bleakhoof (247234)
  - [ ] Moontouched Wanderer (269104)
  - [ ] Gortek the Apprentice (269111)
- [ ] Shaper's Terrace
  - [ ] Titanosaur (253201)
  - [ ] Ravasaur Hunters any-of set still `{0000,0000,0000}` — need real NPC ids
  - [ ] Thunderhoof (261812)
  - [ ] Venomridge (261813)
  - [ ] Direhorn Matriarch (262127)
  - [ ] Cinder (261974)
  - [ ] Snowtalon (262297)
  - [ ] Bolt (262081)
  - [ ] Vitrix (272561)
  - [ ] Nanaya (261809)
  - [ ] King Op (261993)

**Classic tracked but still name-fallback only (no wiki encounter id, or side boss)**
- [ ] The Stockade — no classic wiki DungeonEncounterIDs
  - [ ] Targorr the Dread (1696)
  - [ ] Kam Deepfury (1666)
  - [ ] Hamhock (1717)
  - [ ] Dextren Ward (1663)
  - [ ] Bazil Thredd (1716)
  - [ ] Bruegal Ironknuckle (1720)
- [ ] Zul'Farrak
  - [ ] Sergeant Bly (7604)
  - [ ] Ruuzlu (7797)
  - [ ] Dustwraith (10081)
  - [ ] Zerillis (10082)
  - [ ] Sandarr Dunereaver (10080)
- [ ] Temple of Atal'Hakkar
  - [ ] Atal'alarion (8580)
  - [ ] Ogom the Wretched (5711)
- [ ] Dire Maul
  - [ ] Pusillin (14354)
  - [ ] Tsu'zee (11467)
- [ ] Blackrock Depths
  - [ ] Princess Moira Bronzebeard (8929) — shares Emperor encounter 245; do not id-map; needs separate kill signal / name
- [ ] Rares with no wiki encounter (name fallback)
  - [ ] Deviate Faerie Dragon (5912) — WC
  - [ ] Deathsworn Captain (3872) — SFK
  - [ ] Dark Iron Ambassador (6228) — GNOM
  - [ ] Azshir (6490) — SM
  - [ ] Fallen Champion (6488) — SM
  - [ ] Ironspine (6489) — SM
  - [ ] Ragglesnout (7354) — RFD
  - [ ] Plaguemaw (7356) — RFD
  - [ ] Skul (10393) — STRAT
  - [ ] Postmaster Malown (11143) — STRAT
  - [ ] Stonespine (10809) — STRAT
  - [ ] Jed Runewatcher (10509) — UBRS

**Version notes**
- Avatar of Hakkar (`8443` / encounter `492`): Forever only. Classic/TBC leave commented (buggy kill credit).
- Gahz'rilla (`7273` / encounter `594`): extra credit in all three catalogs; Forever encounter map fixed.
- UBRS: Gyth dropped; Jed Runewatcher is extra credit (name-fallback).
- Kill sets / bossOrder for shared classic dungeons synced Forever → Classic/TBC (TBC keeps its own levels/icons).

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