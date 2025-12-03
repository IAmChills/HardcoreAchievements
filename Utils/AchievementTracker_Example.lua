--[[
    AchievementTracker Usage Example

    This file demonstrates how to use the AchievementTracker module in your addon.

    To use this tracker:
    1. Copy AchievementTracker.lua to your addon
    2. Load it in your addon's initialization
    3. Use the API functions to track/untrack achievements
]]

-- Example: Loading the tracker in your addon
local AchievementTracker = require("AchievementTracker") -- or however you load modules

-- Initialize the tracker when your addon loads
local function OnAddonLoaded()
    AchievementTracker:Initialize()

    -- Optional: Set locked state (prevents dragging)
    -- AchievementTracker:SetLocked(true)

    -- Show the tracker
    AchievementTracker:Show()
end

-- Example: Hook into Blizzard's achievement tracking
local function HookAchievementTracking()
    -- Hook AddTrackedAchievement
    hooksecurefunc("AddTrackedAchievement", function(achievementId)
        AchievementTracker:TrackAchievement(achievementId)
    end)

    -- Hook RemoveTrackedAchievement
    hooksecurefunc("RemoveTrackedAchievement", function(achievementId)
        AchievementTracker:UntrackAchievement(achievementId)
    end)

    -- Sync existing tracked achievements on load
    C_Timer.After(1, function()
        local tracked = { GetTrackedAchievements() }
        for _, achievementId in ipairs(tracked) do
            if achievementId and achievementId > 0 then
                -- Remove from Blizzard tracker
                RemoveTrackedAchievement(achievementId)
                -- Add to our tracker
                AchievementTracker:TrackAchievement(achievementId)
            end
        end
    end)
end

-- Example: Slash command to toggle tracker
SLASH_ACHIEVEMENTTRACKER1 = "/atracker"
SLASH_ACHIEVEMENTTRACKER2 = "/achievetracker"
SlashCmdList["ACHIEVEMENTTRACKER"] = function(msg)
    local command = string.lower(strtrim(msg))

    if command == "toggle" or command == "" then
        AchievementTracker:Toggle()
    elseif command == "show" then
        AchievementTracker:Show()
    elseif command == "hide" then
        AchievementTracker:Hide()
    elseif command == "expand" then
        AchievementTracker:Expand()
    elseif command == "collapse" then
        AchievementTracker:Collapse()
    elseif command == "lock" then
        AchievementTracker:SetLocked(true)
        print("Achievement Tracker locked")
    elseif command == "unlock" then
        AchievementTracker:SetLocked(false)
        print("Achievement Tracker unlocked")
    else
        print("Achievement Tracker commands:")
        print("  /atracker toggle - Toggle tracker visibility")
        print("  /atracker show - Show tracker")
        print("  /atracker hide - Hide tracker")
        print("  /atracker expand - Expand tracker")
        print("  /atracker collapse - Collapse tracker")
        print("  /atracker lock - Lock tracker position")
        print("  /atracker unlock - Unlock tracker position")
    end
end

-- Example: Event handler for when achievements are tracked/untracked
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")

frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "YourAddonName" then
        OnAddonLoaded()
        HookAchievementTracking()
    elseif event == "TRACKED_ACHIEVEMENT_LIST_CHANGED" then
        -- Update tracker when achievement list changes
        AchievementTracker:Update()
    end
end)

-- Example: Manual tracking functions
function TrackAchievementById(achievementId)
    AchievementTracker:TrackAchievement(achievementId)
end

function UntrackAchievementById(achievementId)
    AchievementTracker:UntrackAchievement(achievementId)
end

function IsAchievementTracked(achievementId)
    return AchievementTracker:IsTracked(achievementId)
end

function GetTrackedAchievements()
    return AchievementTracker:GetTrackedAchievements()
end

