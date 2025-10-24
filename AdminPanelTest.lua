-- AdminPanelTest.lua
-- Test script for the admin panel system
-- This file should only be included in your local version for testing

local AdminPanelTest = {}

-- Test function to simulate receiving an admin command
function AdminPanelTest:TestAdminCommand()
    print("|cff00ff00[HardcoreAchievements Test]|r Testing admin command system...")
    
    -- Check if required functions exist
    if not _G.HardcoreAchievementsAdminCommandHandler then
        print("|cffff0000[HardcoreAchievements Test]|r AdminCommandHandler not found")
        return false
    end
    
    if not _G.HardcoreAchievementsAdminPanel then
        print("|cffff0000[HardcoreAchievements Test]|r AdminPanel not found")
        return false
    end
    
    -- Check if Ace3 libraries are available
    if not LibStub then
        print("|cffff0000[HardcoreAchievements Test]|r LibStub not found - Ace3 libraries required")
        return false
    end
    
    local AceComm = LibStub("AceComm-3.0", true)
    local AceSerialize = LibStub("AceSerializer-3.0", true)
    
    if not AceComm then
        print("|cffff0000[HardcoreAchievements Test]|r AceComm-3.0 not found")
        return false
    end
    
    if not AceSerialize then
        print("|cffff0000[HardcoreAchievements Test]|r AceSerializer-3.0 not found")
        return false
    end
    
    print("|cff00ff00[HardcoreAchievements Test]|r All required components found!")
    print("|cff00ff00[HardcoreAchievements Test]|r Admin panel system is ready to use")
    print("|cff00ff00[HardcoreAchievements Test]|r Use /hcaadmin to open the admin panel")
    
    return true
end

-- Test function to verify achievement system integration
function AdminPanelTest:TestAchievementSystem()
    print("|cff00ff00[HardcoreAchievements Test]|r Testing achievement system integration...")
    
    -- Check if achievement system is loaded
    if not AchievementPanel then
        print("|cffff0000[HardcoreAchievements Test]|r AchievementPanel not found")
        return false
    end
    
    if not AchievementPanel.achievements then
        print("|cffff0000[HardcoreAchievements Test]|r No achievements loaded")
        return false
    end
    
    local achievementCount = #AchievementPanel.achievements
    print("|cff00ff00[HardcoreAchievements Test]|r Found " .. achievementCount .. " achievements")
    
    -- List first few achievements
    for i = 1, math.min(5, achievementCount) do
        local achievement = AchievementPanel.achievements[i]
        if achievement and achievement.id then
            print("|cff00ff00[HardcoreAchievements Test]|r - " .. achievement.id)
        end
    end
    
    return true
end

-- Run all tests
function AdminPanelTest:RunAllTests()
    print("|cff00ff00[HardcoreAchievements Test]|r Running admin panel system tests...")
    
    local success = true
    
    success = success and self:TestAdminCommand()
    success = success and self:TestAchievementSystem()
    
    if success then
        print("|cff00ff00[HardcoreAchievements Test]|r All tests passed! Admin panel system is ready.")
    else
        print("|cffff0000[HardcoreAchievements Test]|r Some tests failed. Check the output above for details.")
    end
    
    return success
end

-- Register test command
SLASH_HARDCOREACHIEVEMENTSTEST1 = "/hcatest"
SlashCmdList["HARDCOREACHIEVEMENTSTEST"] = function()
    AdminPanelTest:RunAllTests()
end

-- Export for global access
_G.HardcoreAchievementsAdminPanelTest = AdminPanelTest
