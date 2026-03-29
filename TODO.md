# TODO List

NOT USED BUT COULD HAVE USE (Already added to Icons)
Achievement_Dungeon_Outland_Dungeon_Hero

## Active Tasks


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
 - Get Light’s Hope Chapel flight path before level 25

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