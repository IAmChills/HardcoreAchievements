# TODO List

# Useful Links

### Dungeon IDs / Encounters

https://warcraft.wiki.gg/wiki/DungeonEncounterID

### Discord link generator

https://linkbreakers.com/qr-code-generator/discord

## Active Tasks

### Leaderboard sync: open-world via chat channels

**Current:** HCA owns local `players`/`presence` writes + stock `BroadcastKey` (GUILD/PARTY/RAID/YELL) and rotating `hca######` presence-only chat. LibP2PDB owns peer discovery/convergence via `BroadcastPresence` + `SyncDatabase` every **180s** (`peerTimeout = 400`). Prefix `HCALB`. Do not use `NewDatabase({ channels = ... })`.

- [x] **Forever: per-ruleset peer list** — shared rotating channel kept (cross-ruleset presence still shows online). `onIsPeerAllowed` (local LibP2PDB patch in `UpdatePeer`) drops peers whose players row has another ruleset; unknown players are left to LibP2PDB. Cross-ruleset rows stay stale (players rows never cross rulesets).
- [ ] **Local LibP2PDB patches: re-check on every library update.** Base: upstream **MINOR 15** (`Libs/LibP2PDB/LibP2PDB.lua`, TOC `Version: 15`). Every patch site is tagged `HCA patch` (grep it). When a new version arrives, compare it against this list. Drop a patch the author fixed (adapt HCA if the API differs); re-apply the rest. Then report the remaining ones upstream.
  1. **Debug loader:** `if DEBUG then` block near the top: `UIParentLoadAddOn or LoadAddOnWithErrorHandling` (Forever renamed it). Only matters with `DEBUG = true`.
  2. **Realm fallback:** `local function GetPlayerRealm()` before `local priv = Private.New(...)`. `GetRealmName()` is `""` on Forever, which fails a load-time assert; falls back to the C_GameRules ruleset. `Private.New` was changed to take `GetPlayerRealm()` instead of `GetRealmName()`.
  3. **Self-name:** `priv.playerFullName = GetUnitName("player", false)` right after `priv` is created, plus `or sender == self.playerFullName` in the self-filter of both `Private:OnCommReceived` and `Private:OnChatMsgChannel`. Forever senders arrive as "First Surname" while `UnitName` is the first name only, so own broadcasts were processed.
  4. **Peer filter (`onIsPeerAllowed`):** desc doc field + `DBOnIsPeerAllowedCallback` alias + `IsFunctionOrNil` assert in `NewDatabase` + `onIsPeerAllowed = desc.onIsPeerAllowed` in the dbi table + check at the top of `Private:UpdatePeer` (returning false skips/removes the peer; the message is still dispatched). HCA user: `IsPeerAllowed` in `Leaderboard/LeaderboardSync.lua` (Forever only; rejects peers whose players row has another ruleset). If upstream adds an equivalent under another name, switch `Sync:Initialize` to it.
  5. **Secret chat payloads:** `issecretvalue` early-return at the top of `Private:OnCommReceived` and `Private:OnChatMsgChannel`. During Forever/12.0 encounter restrictions, `CHAT_MSG_CHANNEL` msg/sender arrive as secret strings and the self-name compare errors.
  - **Not a lib patch, but report it:** Forever reorders addon whispers sent in the same instant, corrupting multi-part AceComm messages. Worked around in HCA by `Forever/WhisperPacing.lua` (wraps `ChatThrottleLib.SendAddonMessage` for `^HCA` whispers, 0.1s apart). Remove it if AceComm/LibP2PDB handles ordering upstream.

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

### Get peer list

```lua
/run local L=LibStub("LibP2PDB")for i,p in pairs(L:ListPeers(L:GetDatabase("HCALB")))do print(format("%X",i),p.name,floor(GetTime()-p.lastSeen)
end
```