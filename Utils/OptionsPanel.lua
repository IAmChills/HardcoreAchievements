-- OptionsPanel.lua
-- Options panel for Hardcore Achievements addon

local ADDON_NAME = "HardcoreAchievements"

-- Helper function to get settings
local function GetSetting(settingName, defaultValue)
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

-- Helper function to set settings
local function SetSetting(settingName, value)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings[settingName] = value
        end
    end
end

-- Helper function to check if screenshots are disabled
-- This will be called before Screenshot() in HardcoreAchievements.lua
function HardcoreAchievements_ShouldTakeScreenshot()
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.disableScreenshots then
            return false
        end
    end
    return true
end

-- Create the main options panel
local function CreateOptionsPanel()
    -- Create the panel frame
    local panel = CreateFrame("Frame")
    
    -- Create title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Hardcore Achievements")
    
    -- Create subtitle/description
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure settings for the Hardcore Achievements addon")
    subtitle:SetTextColor(0.7, 0.7, 0.7, 1)
    
    -- Track current Y position for layout
    local currentY = -60
    local spacing = 30
    
    -- =========================================================
    -- User Interface Category
    -- =========================================================
    local uiCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    uiCategoryTitle:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, currentY)
    uiCategoryTitle:SetText("User Interface")
    currentY = currentY - spacing
    
    -- Reset Achievements Tab button
    local resetTabButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetTabButton:SetPoint("TOPLEFT", uiCategoryTitle, "BOTTOMLEFT", 0, -8)
    resetTabButton:SetText("Reset Achievements Tab")
    resetTabButton:SetWidth(180)
    resetTabButton:SetHeight(25)
    resetTabButton:SetScript("OnClick", function(self)
        if type(_G.ResetTabPosition) == "function" then
            _G.ResetTabPosition()
        end
    end)
    
    -- Description for the button
    local resetTabDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    resetTabDesc:SetPoint("TOPLEFT", resetTabButton, "BOTTOMLEFT", 0, -4)
    resetTabDesc:SetText("Used to force the Achievements tab to be shown on the character screen in case it's hidden")
    resetTabDesc:SetTextColor(0.7, 0.7, 0.7, 1)
    resetTabDesc:SetWidth(600)
    resetTabDesc:SetJustifyH("LEFT")
    resetTabDesc:SetJustifyV("TOP")
    currentY = currentY - (spacing * 2) -- Extra spacing for button and description
    
    -- =========================================================
    -- Miscellaneous Category
    -- =========================================================
    currentY = currentY - 20 -- Extra spacing between categories
    local miscCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    miscCategoryTitle:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, currentY)
    miscCategoryTitle:SetText("Miscellaneous")
    currentY = currentY - spacing
    
    -- Disable Screenshots checkbox
    local disableScreenshotsCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    disableScreenshotsCB:SetPoint("TOPLEFT", miscCategoryTitle, "BOTTOMLEFT", 0, -8)
    disableScreenshotsCB.Text:SetText("Disable Screenshots")
    disableScreenshotsCB.tooltipText = "Prevent the addon from taking screenshots when achievements are completed."
    disableScreenshotsCB:SetChecked(GetSetting("disableScreenshots", false))
    disableScreenshotsCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        SetSetting("disableScreenshots", isChecked)
    end)
    currentY = currentY - spacing
    
    -- Store references for future use
    panel.checkboxes = {
        disableScreenshots = disableScreenshotsCB,
    }
    panel.buttons = {
        resetAchievementsTab = resetTabButton,
    }
    
    -- Refresh function to update checkboxes when panel is shown
    panel.refresh = function(self)
        -- Update checkbox state from database
        if disableScreenshotsCB then
            disableScreenshotsCB:SetChecked(GetSetting("disableScreenshots", false))
        end
    end
    
    -- Register with Settings API (newer API for Classic Era)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Hardcore Achievements")
    Settings.RegisterAddOnCategory(category)
    
    -- Store category in addon table (similar to BugSack pattern)
    -- Access addon table from global namespace
    local addon = _G[ADDON_NAME]
    if not addon then
        -- Create addon table if it doesn't exist
        addon = {}
        _G[ADDON_NAME] = addon
    end
    addon.settingsCategory = category
    
    -- Also store globally as backup
    _HardcoreAchievementsOptionsCategory = category
    
    return panel
end

-- Initialize the options panel when the addon loads
local optionsPanel = CreateOptionsPanel()

-- Global reference for external access if needed
_HardcoreAchievementsOptionsPanel = optionsPanel

