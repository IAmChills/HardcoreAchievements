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

-- Helper function to check if solo achievements mode is enabled
function HardcoreAchievements_IsSoloModeEnabled()
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.soloAchievements then
            return true
        end
    end
    return false
end

-- Helper function to check if award on kill is enabled
function HardcoreAchievements_IsAwardOnKillEnabled()
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.awardOnKill then
            return true
        end
    end
    return false
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

-- Helper function to update solo achievements checkbox based on self-found status
-- Defined before CreateOptionsPanel so it's available in the refresh function
local function UpdateSoloAchievementsCheckbox()
    local panel = _HardcoreAchievementsOptionsPanel
    if not panel or not panel.checkboxes or not panel.checkboxes.soloAchievements then
        return
    end
    
    local soloAchievementsCB = panel.checkboxes.soloAchievements
    local disableScreenshotsCB = panel.checkboxes.disableScreenshots
    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
    
    if isSelfFound then
        soloAchievementsCB:Enable()
        -- Get the default color from the other checkbox (same template) and use it
        if disableScreenshotsCB and disableScreenshotsCB.Text then
            local r, g, b = disableScreenshotsCB.Text:GetTextColor()
            soloAchievementsCB.Text:SetTextColor(r, g, b, 1)
        end
        soloAchievementsCB.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no party members within 40 yards)."
    else
        soloAchievementsCB:Disable()
        soloAchievementsCB.Text:SetTextColor(0.5, 0.5, 0.5, 1) -- Gray out the text
    end
end

-- Create the main options panel
local function CreateOptionsPanel()
    -- Create the panel frame
    local panel = CreateFrame("Frame")
    
    -- Create title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Hardcore Achievements")
    --title:SetFont("Interface\\Addons\\MyAddon\\Fonts\\MyCustomFont.ttf", 20)
    title:SetTextColor(1, 1, 1, 1)
    
    -- Create subtitle/description
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure settings for the Hardcore Achievements addon")
    subtitle:SetTextColor(0.7, 0.7, 0.7, 1)

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetAtlas("Options_HorizontalDivider", true)
    panel.divider:SetPoint("TOP", 0, -60)
    
    -- =========================================================
    -- Miscellaneous Category
    -- =========================================================
    local miscCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    miscCategoryTitle:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -40)
    miscCategoryTitle:SetText("|cff69adc9Miscellaneous|r")
    
    -- Helper function to add tooltip to checkboxes
    local function AddTooltipToCheckbox(cb, tooltipText)
        cb.tooltip = tooltipText
        cb:SetScript("OnEnter", function(self)
            if self.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    -- Disable Screenshots checkbox
    local disableScreenshotsCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    disableScreenshotsCB:SetPoint("TOPLEFT", miscCategoryTitle, "BOTTOMLEFT", 0, -8)
    disableScreenshotsCB.Text:SetText("Disable Screenshots")
    disableScreenshotsCB:SetChecked(GetSetting("disableScreenshots", false))
    disableScreenshotsCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        SetSetting("disableScreenshots", isChecked)
    end)
    AddTooltipToCheckbox(disableScreenshotsCB, "Prevent the addon from taking screenshots when achievements are completed.")

    -- Solo Achievements checkbox
    local soloAchievementsCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    soloAchievementsCB:SetPoint("TOPLEFT", disableScreenshotsCB, "BOTTOMLEFT", 0, -8)
    soloAchievementsCB.Text:SetText("Solo Self Found Mode")
    soloAchievementsCB:SetChecked(GetSetting("soloAchievements", false))
    
    -- Check if player is self-found to enable/disable checkbox
    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
    if not isSelfFound then
        soloAchievementsCB:Disable()
        soloAchievementsCB.Text:SetTextColor(0.5, 0.5, 0.5, 1) -- Gray out the text
    end
    
    soloAchievementsCB:SetScript("OnClick", function(self)
        if self:IsEnabled() then
            local isChecked = self:GetChecked()
            SetSetting("soloAchievements", isChecked)
            -- Refresh all achievement points immediately
            if RefreshAllAchievementPoints then
                RefreshAllAchievementPoints()
            end
        end
    end)
    
    local tooltipText = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no party members within 40 yards)."
    AddTooltipToCheckbox(soloAchievementsCB, tooltipText)

    -- Award on Kill checkbox
    local awardOnKillCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    awardOnKillCB:SetPoint("TOPLEFT", soloAchievementsCB, "BOTTOMLEFT", 0, -8)
    awardOnKillCB.Text:SetText("Award achievements on kill rather than quest")
    awardOnKillCB:SetChecked(GetSetting("awardOnKill", false))
    awardOnKillCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        SetSetting("awardOnKill", isChecked)
    end)
    AddTooltipToCheckbox(awardOnKillCB, "If enabled, achievements that require an NPC kill will be awarded immediately on kill rather than waiting for quest completion.")

    -- Modern Rows checkbox (for embed display)
    local modernRowsCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    modernRowsCB:SetPoint("TOPLEFT", awardOnKillCB, "BOTTOMLEFT", 0, -8)
    modernRowsCB.Text:SetText("Modern Rows (Embed Display)")
    modernRowsCB:SetChecked(GetSetting("modernRows", false))
    modernRowsCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        SetSetting("modernRows", isChecked)
        -- Refresh embed display when setting changes
        if EMBED and EMBED.Rebuild then
            EMBED:Rebuild()
        end
    end)
    AddTooltipToCheckbox(modernRowsCB, "If enabled, the embedded achievements frame will display achievements as modern rows (similar to the character panel). If disabled, it will use the classic grid layout.")

    -- =========================================================
    -- User Interface Category
    -- =========================================================
    local uiCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    uiCategoryTitle:SetPoint("TOPLEFT", awardOnKillCB, "BOTTOMLEFT", 0, -30)
    uiCategoryTitle:SetText("|cff69adc9User Interface|r")
    
    -- Reset Achievements Tab button
    local resetTabButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetTabButton:SetPoint("TOPLEFT", uiCategoryTitle, "BOTTOMLEFT", 0, -8)
    resetTabButton:SetText("Reset Achievements Tab Position")
    resetTabButton:SetWidth(220)
    resetTabButton:SetHeight(25)
    resetTabButton:SetScript("OnClick", function(self)
        if type(_G.ResetTabPosition) == "function" then
            _G.ResetTabPosition()
        end
    end)
    AddTooltipToCheckbox(resetTabButton, "Used to reset the position of the Achievements tab in case it's hidden")
    
    -- =========================================================
    -- Support & Contact Category
    -- =========================================================
    local supportCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    supportCategoryTitle:SetPoint("TOPLEFT", resetTabButton, "BOTTOMLEFT", 0, -30)
    supportCategoryTitle:SetText("|cff69adc9Support & Contact|r")
    
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
    AddTooltipToCheckbox(discordButton, "Click to open Discord support")
    
    -- Store references for future use
    panel.checkboxes = {
        disableScreenshots = disableScreenshotsCB,
        soloAchievements = soloAchievementsCB,
        awardOnKill = awardOnKillCB,
        modernRows = modernRowsCB,
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
        if soloAchievementsCB then
            soloAchievementsCB:SetChecked(GetSetting("soloAchievements", false))
            -- Update enable/disable state based on Self-Found status using helper function
            UpdateSoloAchievementsCheckbox()
        end
        if awardOnKillCB then
            awardOnKillCB:SetChecked(GetSetting("awardOnKill", false))
        end
        if modernRowsCB then
            modernRowsCB:SetChecked(GetSetting("modernRows", false))
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

-- Event frame to listen for buff changes (self-found buff appearing)
local selfFoundEventFrame = CreateFrame("Frame")
selfFoundEventFrame:RegisterEvent("UNIT_AURA")
selfFoundEventFrame:RegisterEvent("PLAYER_LOGIN")
selfFoundEventFrame:RegisterEvent("ADDON_LOADED")

-- Track if we've already enabled the checkbox to avoid redundant updates
local selfFoundCheckboxEnabled = false

selfFoundEventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = select(1, ...)
    
    -- Only process UNIT_AURA for player, and only if checkbox isn't already enabled
    if event == "UNIT_AURA" and arg1 == "player" and not selfFoundCheckboxEnabled then
        UpdateSoloAchievementsCheckbox()
        -- Mark as enabled if self-found is detected
        if _G.IsSelfFound and _G.IsSelfFound() then
            selfFoundCheckboxEnabled = true
        end
    elseif event == "PLAYER_LOGIN" then
        -- Reset flag on login
        selfFoundCheckboxEnabled = false
        -- Initial check (might be false at this point)
        UpdateSoloAchievementsCheckbox()
        -- Delayed check after a few seconds (fallback for slow buff loading)
        C_Timer.After(3, function()
            UpdateSoloAchievementsCheckbox()
            if _G.IsSelfFound and _G.IsSelfFound() then
                selfFoundCheckboxEnabled = true
            end
        end)
        -- Another delayed check after 5 seconds as extra fallback
        C_Timer.After(5, function()
            if not selfFoundCheckboxEnabled then
                UpdateSoloAchievementsCheckbox()
                if _G.IsSelfFound and _G.IsSelfFound() then
                    selfFoundCheckboxEnabled = true
                end
            end
        end)
    elseif event == "ADDON_LOADED" then
        local addonName = arg1
        if addonName == ADDON_NAME then
            -- Reset flag when addon loads
            selfFoundCheckboxEnabled = false
            -- Delayed check after addon loads (buff might appear around this time)
            C_Timer.After(3, function()
                UpdateSoloAchievementsCheckbox()
                if _G.IsSelfFound and _G.IsSelfFound() then
                    selfFoundCheckboxEnabled = true
                end
            end)
        end
    end
end)

-- Initialize the options panel when the addon loads
local optionsPanel = CreateOptionsPanel()

-- Global reference for external access if needed
_HardcoreAchievementsOptionsPanel = optionsPanel
