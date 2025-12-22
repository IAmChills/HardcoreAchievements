# TODO List

## Active Tasks

- [ ] Completed at: ## information like Inspection window?
- [ ] Hardcore Autopsy Journal
- [ ] Show achievement locations on map
- [ ] Bugs
  - [ ] 

## Helpful Code Snippets

### Class-colored text
```lua
|c" .. select(4, GetClassColor(select(2, UnitClass("player")))) .. "TEXTHERE|r
```

### Print player's assigned group role
```lua
/script print(UnitGroupRolesAssigned('player'))
```

### Check if UltraHardcore addon is loaded (Does not work)
```lua
if event == "ADDON_LOADED" and select(1, ...) == "UltraHardcore" then
```

### Reset Progress or Achievement in database
```lua
/run HardcoreAchievementsDB.chars[UnitGUID("player")].progress["Test3"] = nil; ReloadUI()
```

## TBC Brainstorm

- [ ] Dungeons before specific level
- [ ] Difficult Quests?
- [ ] ??