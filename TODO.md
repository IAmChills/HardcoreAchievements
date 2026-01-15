# TODO List

NOT USED BUT COULD HAVE USE (Already added to Icons)
Achievement_Dungeon_Outland_Dungeon_Hero
INV_DARKMOON_EYE (could be LOTR alternative)

## Active Tasks
- Expand on comms to allow achievement related statistics where data is propogated for realm-first, % of players completed style info

## Bugs
 - empty

## TBC TODO List

- Dungeon Set Catalog
  - Already implemented, needs updated to include TBC sets
- Dungeon Set Common
  - dependancy for the above catalog

## Quests
 - The Dying Balance (Boglash) at 58
   - Something like this might suck because its so low level for Outlands

## Explorer Achievements
 - Discover Karazhan before level 25 and speak to archmage leryda
 - Get Light’s Hope Chapel flight path before level 25
 - Enter Stormwind (as horde)

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
 - Warlord of the Rings
   - Destroy the 1 ring in black rock mountain as a level 1 gnome must be carrying the ring the entire way from the starting zone
   - May require tracking for when item is picked up (set flag) player is in BRM, all else satisfied, destroy popup displays, and count goes to 0?
   - “and my axe…” for being in the raid with the person who does it
   - Use a hook?
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