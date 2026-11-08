# TODO List

NOT USED BUT COULD HAVE USE (Already added to Icons)
Achievement_Dungeon_Outland_Dungeon_Hero

Discord link generator
https://linkbreakers.com/qr-code-generator/discord

## Active Tasks

### Forever leaderboard sync: LibP2PDB `channels` + stock broadcasts (waiting on upstream fix)
**Goal:** Keep default GUILD/PARTY/RAID/YELL, and also sync over custom chat channel `HCA` on Forever for open-world peers (no party/guild required). No LibP2PDB fork; no ChatThrottleLib redirect.

**Wired now:**
- `Leaderboard/LeaderboardSync.lua` → `NewDatabase({ ..., channels = { "HCA" } })` on Forever only.
- `Forever/CommChannel.lua` joins/refreshes channel `HCA` by name (indexes move; do not hardcode ids).
- Classic/TBC: no `channels`; stock YELL path unchanged.

**Upstream status (author):** `desc.channels` is the intended API, but current `Private:Broadcast` wrongly does `SendCommMessage(..., channelName, nil)` instead of resolving the name to `"CHANNEL", GetChannelName(name)`. Author acknowledged and will fix. Until that lands, the `HCA` entry may no-op/fail while GUILD/PARTY/RAID/YELL still work. Separate API `RegisterChatChannel` / `BroadcastKeyChatChannel` is for visible chat-channel payloads (Hardcore Mode style), not what we want for continuous leaderboard gossip.

**After upstream fix ships:**
- [ ] Bump embedded LibP2PDB.
- [ ] Confirm ungrouped Forever peers sync via `HCA` (`/hca probe` shows live channel index).
- [ ] Confirm Classic still ignores CHANNEL and uses stock paths.
- [ ] Optional later: if author adds a way to disable default GUILD/PARTY/RAID/YELL when CHANNEL is enough, reconsider Forever CHANNEL-only to cut duplicate sends (not required).

## Bugs
 - empty

## TBC TODO List

## Quests
 - 

## Explorer Achievements
 - 

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

## Ultra HC Addon

## Raids
 - Wiping on chess (blundered)
   - I will have to see if I can check if an encounter fails?

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
/run HardcoreAchievementsDB.chars[UnitGUID("player")].progress["Test3"] = nil; ReloadUI()
```