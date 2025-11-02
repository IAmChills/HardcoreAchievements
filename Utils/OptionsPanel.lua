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

-- Create Discord frame (will be created on first use)
local discordFrame = nil
local DISCORD_LINK = "discord.gg/MMh2Cv8X" -- Replace with actual Discord invite link

local function CreateDiscordFrame()
    if discordFrame then return discordFrame end
    
    -- Create the main frame
    discordFrame = CreateFrame("Frame", nil, UIParent)
    discordFrame:SetSize(250, 250)
    discordFrame:SetPoint("CENTER")
    discordFrame:SetFrameStrata("DIALOG")
    discordFrame:Hide()
    
    -- Create simple semi-transparent background
    local bgTexture = discordFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    bgTexture:SetAllPoints(discordFrame)
    bgTexture:SetVertexColor(0, 0, 0, 0.8)
    
    -- Title
    local titleText = discordFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetText("Discord Support")
    titleText:SetTextColor(1, 1, 1, 1)
    
    -- QR Code image (fully opaque, no transparency inheritance)
    local placeholderIcon = discordFrame:CreateTexture(nil, "OVERLAY")
    placeholderIcon:SetSize(175, 175)
    placeholderIcon:SetPoint("TOP", titleText, "BOTTOM", 0, -10)
    placeholderIcon:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\DiscordQR.tga")
    placeholderIcon:SetAlpha(1.0) -- Fully opaque, don't inherit transparency
    
    -- Discord link (read-only input box)
    local discordLinkBox = CreateFrame("EditBox", nil, discordFrame, "InputBoxTemplate")
    discordLinkBox:SetSize(150, 32)
    discordLinkBox:SetPoint("TOP", placeholderIcon, "BOTTOM", 0, -5)
    discordLinkBox:SetAutoFocus(false)
    discordLinkBox:SetText(DISCORD_LINK)
    discordLinkBox:SetTextColor(0.345, 0.396, 0.949, 1) -- Discord blurple color
    discordLinkBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Make read-only (disable editing)
    discordLinkBox:SetScript("OnEditFocusGained", function(self)
        -- Allow selection but prevent editing
        self:HighlightText()
    end)
    
    -- Make it appear read-only by preventing text changes
    discordLinkBox:SetScript("OnChar", function(self)
        -- Prevent any text input - restore original text
        self:SetText(DISCORD_LINK)
    end)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, discordFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function(self)
        discordFrame:Hide()
    end)
    
    -- Make frame movable
    discordFrame:SetMovable(true)
    discordFrame:EnableMouse(true)
    discordFrame:RegisterForDrag("LeftButton")
    discordFrame:SetScript("OnDragStart", discordFrame.StartMoving)
    discordFrame:SetScript("OnDragStop", discordFrame.StopMovingOrSizing)
    
    -- Store references
    discordFrame.discordLinkBox = discordLinkBox
    discordFrame.placeholderIcon = placeholderIcon
    
    return discordFrame
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
    
    -- =========================================================
    -- Miscellaneous Category
    -- =========================================================
    local miscCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    miscCategoryTitle:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -40)
    miscCategoryTitle:SetText("Miscellaneous")
    
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

    -- =========================================================
    -- User Interface Category
    -- =========================================================
    local uiCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    uiCategoryTitle:SetPoint("TOPLEFT", disableScreenshotsCB, "BOTTOMLEFT", 0, -30)
    uiCategoryTitle:SetText("User Interface")
    
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
    
    -- =========================================================
    -- Support & Contact Category
    -- =========================================================
    local supportCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    supportCategoryTitle:SetPoint("TOPLEFT", resetTabDesc, "BOTTOMLEFT", 0, -30)
    supportCategoryTitle:SetText("Support & Contact")
    
    -- Support text
    local supportText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    supportText:SetPoint("TOPLEFT", supportCategoryTitle, "BOTTOMLEFT", 0, -8)
    supportText:SetText("Found a bug or want to make an appeal? Contact me via Discord! All appeals must have clear evidence of your player name, level, and what the issue is.")
    supportText:SetTextColor(0.8, 0.8, 0.8, 1)
    supportText:SetWidth(600)
    supportText:SetJustifyH("LEFT")
    supportText:SetJustifyV("TOP")
    
    -- Discord button
    local discordButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    discordButton:SetPoint("TOPLEFT", supportText, "BOTTOMLEFT", 0, -12)
    discordButton:SetText("Discord")
    discordButton:SetWidth(120)
    discordButton:SetHeight(25)
    discordButton:SetScript("OnClick", function(self)
        local frame = CreateDiscordFrame()
        frame:Show()
    end)
    
    -- Store references for future use
    panel.checkboxes = {
        disableScreenshots = disableScreenshotsCB,
    }
    panel.buttons = {
        resetAchievementsTab = resetTabButton,
        discord = discordButton,
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
