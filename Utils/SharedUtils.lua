-- SharedUtils.lua
-- Shared utility functions used across multiple files in the Hardcore Achievements addon
-- This reduces code duplication and centralizes common logic

local SharedUtils = {}

-- =========================================================
-- Settings Helpers
-- =========================================================

-- Get a setting value from character database
function SharedUtils.GetSetting(settingName, defaultValue)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings then
            local value = cdb.settings[settingName]
            if value ~= nil then
                return value
            end
        end
    end
    return defaultValue
end

-- Set a setting value in character database
function SharedUtils.SetSetting(settingName, value)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings[settingName] = value
        end
    end
end

-- =========================================================
-- Character Panel Tab Management
-- =========================================================

-- Get the Character Frame achievement tab
function SharedUtils.GetAchievementTab()
    return _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
end

-- Check if tab is the achievement tab
function SharedUtils.IsAchievementTab(tab)
    if not tab or not tab.GetText then return false end
    local tabText = tab:GetText()
    if not tabText then return false end
    return tabText:find("Achievement") ~= nil or (_G.ACHIEVEMENTS and tabText:find(_G.ACHIEVEMENTS))
end

-- Show or hide the Character Panel achievement tab based on useCharacterPanel setting
function SharedUtils.UpdateCharacterPanelTabVisibility()
    -- Get the actual Tab frame directly (more reliable than searching by name)
    local tab = nil
    if type(_G.HardcoreAchievements_GetTab) == "function" then
        tab = _G.HardcoreAchievements_GetTab()
    end
    
    -- Fallback to finding by name if getter not available
    if not tab then
        tab = SharedUtils.GetAchievementTab()
        if not tab or not SharedUtils.IsAchievementTab(tab) then 
            -- Tab not found, but still call LoadTabPosition which will handle it
            if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
                _G.HardcoreAchievements_LoadTabPosition()
            end
            return 
        end
    end
    
    local useCharacterPanel = SharedUtils.GetSetting("useCharacterPanel", true)
    
    if useCharacterPanel then
        -- Show custom tab (Character Panel mode) - LoadTabPosition will handle the actual showing
        -- Also restore vertical tab if it was in vertical mode
        if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
            _G.HardcoreAchievements_LoadTabPosition()
        end
    else
        -- Hide custom tab (Dashboard mode) - hide immediately
        if tab then
            tab:Hide()
            -- Also hide square frame if it exists
            if tab.squareFrame then
                tab.squareFrame:Hide()
                tab.squareFrame:EnableMouse(false)
            end
        end
        -- Also hide vertical tab immediately
        if type(_G.HardcoreAchievements_HideVerticalTab) == "function" then
            _G.HardcoreAchievements_HideVerticalTab()
        end
    end
end

-- Set useCharacterPanel setting and update tab visibility
function SharedUtils.SetUseCharacterPanel(enabled)
    SharedUtils.SetSetting("useCharacterPanel", enabled)
    
    -- Sync showCustomTab with useCharacterPanel to keep them in sync
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings.showCustomTab = enabled
        end
    end
    
    SharedUtils.UpdateCharacterPanelTabVisibility()
    
    -- Reload tab position only when enabling (positioning). When disabling, we already hid it directly.
    if enabled and type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
        _G.HardcoreAchievements_LoadTabPosition()
    end
end

-- =========================================================
-- Export Globally
-- =========================================================

-- Export as global for use by other files
_G.HardcoreAchievements_SharedUtils = SharedUtils
