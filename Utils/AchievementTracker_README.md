# Achievement Tracker

A simplified achievement tracking system based on Questie's tracker design. This tracker provides a collapsible header that displays tracked achievements when expanded.

## Features

- **Expandable/Collapsible Header**: Click the "Achievement Tracker" header to expand or collapse the tracker
- **Achievement Display**: Shows achievement names and their criteria/objectives
- **Drag & Drop**: Move the tracker by dragging (can be locked)
- **Auto-updates**: Automatically updates when achievements are tracked/untracked
- **Simple API**: Easy-to-use functions for managing tracked achievements

## Files

- **AchievementTracker.lua**: Main tracker module (copy this to your addon)
- **AchievementTracker_Example.lua**: Example usage code showing how to integrate the tracker
- **AchievementTracker_README.md**: This file

## Quick Start

1. Copy `AchievementTracker.lua` to your addon's directory
2. Load it in your addon (e.g., `local AchievementTracker = require("AchievementTracker")`)
3. Initialize it: `AchievementTracker:Initialize()`
4. Track achievements: `AchievementTracker:TrackAchievement(achievementId)`

## API Reference

### Initialization

```lua
AchievementTracker:Initialize()
```
Initializes the tracker. Call this once when your addon loads.

### Tracking Achievements

```lua
AchievementTracker:TrackAchievement(achievementId)
```
Adds an achievement to the tracker. Returns nothing.

```lua
AchievementTracker:UntrackAchievement(achievementId)
```
Removes an achievement from the tracker.

```lua
AchievementTracker:IsTracked(achievementId)
```
Returns `true` if the achievement is currently tracked.

```lua
AchievementTracker:GetTrackedAchievements()
```
Returns a table of all tracked achievement IDs.

### Visibility

```lua
AchievementTracker:Show()
```
Shows the tracker frame.

```lua
AchievementTracker:Hide()
```
Hides the tracker frame.

```lua
AchievementTracker:Toggle()
```
Toggles the tracker visibility.

### Expand/Collapse

```lua
AchievementTracker:Expand()
```
Expands the tracker to show achievements.

```lua
AchievementTracker:Collapse()
```
Collapses the tracker to show only the header.

### Locking

```lua
AchievementTracker:SetLocked(locked)
```
Sets whether the tracker can be dragged. `locked = true` prevents dragging (unless Ctrl is held).

### Updates

```lua
AchievementTracker:Update()
```
Manually triggers an update of the tracker display. Usually called automatically, but you can call this if needed.

## Configuration

You can modify the `CONFIG` table at the top of `AchievementTracker.lua` to customize:

- `headerFontSize`: Size of the header text (default: 14)
- `achievementFontSize`: Size of achievement names (default: 12)
- `objectiveFontSize`: Size of achievement objectives (default: 11)
- `marginLeft`: Left margin for content (default: 14)
- `marginRight`: Right margin for content (default: 30)
- `minLineWidth`: Minimum width of the tracker (default: 260)
- `linePoolSize`: Maximum number of lines to display (default: 50)
- `paddingBetweenAchievements`: Space between achievements (default: 4)

## Integration with Blizzard Achievement System

To automatically sync with Blizzard's achievement tracking, hook the functions:

```lua
hooksecurefunc("AddTrackedAchievement", function(achievementId)
    AchievementTracker:TrackAchievement(achievementId)
    RemoveTrackedAchievement(achievementId) -- Remove from Blizzard tracker
end)

hooksecurefunc("RemoveTrackedAchievement", function(achievementId)
    AchievementTracker:UntrackAchievement(achievementId)
end)
```

## Differences from Questie Tracker

This tracker is simplified compared to Questie's tracker:

- **No zone grouping**: Achievements are displayed in a flat list
- **No quest support**: Only tracks achievements
- **Simpler line pool**: Basic line pool without complex quest/objective handling
- **No dependencies**: Self-contained, doesn't require Questie modules
- **Simpler styling**: Basic backdrop and text, easily customizable

## Customization

The tracker uses standard WoW UI elements and can be customized by modifying:

1. **Colors**: Change color codes in the `SetText()` calls (e.g., `|cFFFFFF00` for yellow)
2. **Fonts**: Modify the font paths in `SetFont()` calls
3. **Backdrop**: Change the backdrop settings in `Initialize()`
4. **Positioning**: Modify the `SetPoint()` calls to change default position

## Notes

- The tracker respects WoW's 10 achievement tracking limit
- Updates are throttled to prevent performance issues
- The tracker hides automatically when no achievements are tracked (if collapsed)
- Dragging is disabled during combat unless Ctrl is held

## Troubleshooting

**Tracker doesn't show up:**
- Make sure you've called `AchievementTracker:Initialize()`
- Check that you're tracking at least one achievement
- Try calling `AchievementTracker:Show()` explicitly

**Achievements not appearing:**
- Verify the achievement ID is valid using `GetAchievementInfo(achievementId)`
- Check that the achievement isn't already completed
- Ensure you're calling `AchievementTracker:Update()` after tracking

**Tracker position resets:**
- The tracker doesn't save position by default. Add position saving in `OnDragStop` if needed.

