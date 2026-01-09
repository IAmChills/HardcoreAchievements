# TODO List

## Active Tasks
- Dungon achievements are calculated by dungeon entrance level
- Show achievement locations on map

## Bugs
 - empty

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

## TBC TODO List

- Catalog
  - NEED LEVEL 70 MILESTONE ICON
- Dungeon Set Catalog
  - Already implemented, needs updated to include TBC sets
- Dungeon Set Common
  - dependancy for the above catalog

## Quests
 - Luzran & Knucklerot at level 18
 - The Traitor's Destruction at 18
 - Battle for Hillsbrad (full chain) at 27
 - Test of Endurance at 27
 - The Dying Balance (Boglash) at 58
   - Something like this might suck because its so low level for Outlands
 - Cruel's Intentions at 60
 - Ring of Blood (full chain) at 65
 - Hotter than Hell (Fel Reaver) at 68
 - ...Gonna need all hands on deck to get notable difficult Outlands quests. Too many might make it annoying since you never get a break and bounce from one to the next

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
   - “and my axe…” for being in the raid with the person who does it
 - Destroy your light of elune (giga hardcore achievement)

## Class challenges
 - paladin, hunter, mage (likely not do-able with the nerfs)
   - zg solo pull (kill x number of zombies in y amount of time solo)