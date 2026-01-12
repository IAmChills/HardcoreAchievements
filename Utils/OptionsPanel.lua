-- OptionsPanel.lua
-- Options panel for Hardcore Achievements addon

local ADDON_NAME = "HardcoreAchievements"

-- Load AceSerializer (still needed for old format fallback)
local AceSerialize = LibStub("AceSerializer-3.0")

-- Use the standalone encoding functions from DataEncoding.lua
-- HCA_EncodeData and HCA_DecodeData are available globally after DataEncoding.lua loads

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

-- Helper function to check if achievements should be announced in guild chat
function HardcoreAchievements_ShouldAnnounceInGuildChat()
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.announceInGuildChat then
            return true
        end
    end
    return false
end

-- Create Discord frame (will be created on first use)
local discordFrame = nil
local DISCORD_LINK = "https://discord.gg/3KChDhux2D"

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
    bgTexture:SetVertexColor(0, 0, 0, 1)
    
    -- Title
    local titleText = discordFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetText("Discord Support")
    titleText:SetTextColor(1, 1, 1, 1)
    
    -- QR Code image (fully opaque, no transparency inheritance)
    local placeholderIcon = discordFrame:CreateTexture(nil, "OVERLAY")
    placeholderIcon:SetSize(175, 175)
    placeholderIcon:SetPoint("TOP", titleText, "BOTTOM", 0, -10)
    placeholderIcon:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\DiscordQR.png")
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

-- =========================================================
-- Backup/Restore Database Frame (Unified with Tabs)
-- =========================================================

-- Unified backup/restore frame (will be created on first use)
local backupRestoreFrame = nil
local activeTab = "Backup" -- "Backup" or "Restore"

-- Function to switch tabs
local function SwitchTab(tabName)
    activeTab = tabName
    local frame = backupRestoreFrame
    if not frame then return end
    
    -- Update tab selection
    for _, tab in pairs(frame.tabs) do
        if tab.tabName == tabName then
            PanelTemplates_SelectTab(tab)
        else
            PanelTemplates_DeselectTab(tab)
        end
    end
    
    -- Show/hide content panels
    if tabName == "Backup" then
        frame.backupPanel:Show()
        frame.restorePanel:Hide()
    else
        frame.backupPanel:Hide()
        frame.restorePanel:Show()
        -- Auto-focus the import edit box when switching to restore tab
        if frame.restorePanel.editBox then
            frame.restorePanel.editBox:SetText("Paste your backup string here...")
            frame.restorePanel.editBox:SetFocus()
            frame.restorePanel.editBox:HighlightText()
        end
    end
end

local function CreateBackupRestoreFrame()
    if backupRestoreFrame then return backupRestoreFrame end
    
    -- Create the main frame
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(600, 335)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    -- Title background
    local titlebg = frame:CreateTexture(nil, "BORDER")
    titlebg:SetTexture(251966) --"Interface\\PaperDollInfoFrame\\UI-GearManager-Title-Background"
    titlebg:SetPoint("TOPLEFT", 9, -6)
    titlebg:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -28, -24)
    
    -- Dialog background
    local dialogbg = frame:CreateTexture(nil, "BACKGROUND")
    dialogbg:SetTexture(136548) --"Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-L1"
    dialogbg:SetPoint("TOPLEFT", 8, -12)
    dialogbg:SetPoint("BOTTOMRIGHT", -6, 8)
    dialogbg:SetTexCoord(0.255, 1, 0.29, 1)
    
    -- Borders
    local topleft = frame:CreateTexture(nil, "BORDER")
    topleft:SetTexture(251963) --"Interface\\PaperDollInfoFrame\\UI-GearManager-Border"
    topleft:SetWidth(64)
    topleft:SetHeight(64)
    topleft:SetPoint("TOPLEFT")
    topleft:SetTexCoord(0.501953125, 0.625, 0, 1)
    
    local topright = frame:CreateTexture(nil, "BORDER")
    topright:SetTexture(251963)
    topright:SetWidth(64)
    topright:SetHeight(64)
    topright:SetPoint("TOPRIGHT")
    topright:SetTexCoord(0.625, 0.75, 0, 1)
    
    local top = frame:CreateTexture(nil, "BORDER")
    top:SetTexture(251963)
    top:SetHeight(64)
    top:SetPoint("TOPLEFT", topleft, "TOPRIGHT")
    top:SetPoint("TOPRIGHT", topright, "TOPLEFT")
    top:SetTexCoord(0.25, 0.369140625, 0, 1)
    
    local bottomleft = frame:CreateTexture(nil, "BORDER")
    bottomleft:SetTexture(251963)
    bottomleft:SetWidth(64)
    bottomleft:SetHeight(64)
    bottomleft:SetPoint("BOTTOMLEFT")
    bottomleft:SetTexCoord(0.751953125, 0.875, 0, 1)
    
    local bottomright = frame:CreateTexture(nil, "BORDER")
    bottomright:SetTexture(251963)
    bottomright:SetWidth(64)
    bottomright:SetHeight(64)
    bottomright:SetPoint("BOTTOMRIGHT")
    bottomright:SetTexCoord(0.875, 1, 0, 1)
    
    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetTexture(251963)
    bottom:SetHeight(64)
    bottom:SetPoint("BOTTOMLEFT", bottomleft, "BOTTOMRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", bottomright, "BOTTOMLEFT")
    bottom:SetTexCoord(0.376953125, 0.498046875, 0, 1)
    
    local left = frame:CreateTexture(nil, "BORDER")
    left:SetTexture(251963)
    left:SetWidth(64)
    left:SetPoint("TOPLEFT", topleft, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bottomleft, "TOPLEFT")
    left:SetTexCoord(0.001953125, 0.125, 0, 1)
    
    local right = frame:CreateTexture(nil, "BORDER")
    right:SetTexture(251963)
    right:SetWidth(64)
    right:SetPoint("TOPRIGHT", topright, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", bottomright, "TOPRIGHT")
    right:SetTexCoord(0.1171875, 0.2421875, 0, 1)
    
    -- Title
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -7)
    titleText:SetText("Backup and Restore Database")
    titleText:SetTextColor(1, 1, 1, 1)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 2, 2)
    closeButton:SetScript("OnClick", function(self)
        frame:Hide()
    end)
    
    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- =========================================================
    -- Create Tabs
    -- =========================================================
    local backupTab = CreateFrame("Button", "HardcoreAchievementsBackupTab", frame, "CharacterFrameTabButtonTemplate")
    backupTab:SetFrameStrata("FULLSCREEN")
    backupTab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 8)
    backupTab:SetText("Backup")
    backupTab.tabName = "Backup"
    backupTab:SetScript("OnLoad", nil)
    backupTab:SetScript("OnShow", nil)
    backupTab:SetScript("OnClick", function() SwitchTab("Backup") end)
    
    local restoreTab = CreateFrame("Button", "HardcoreAchievementsRestoreTab", frame, "CharacterFrameTabButtonTemplate")
    restoreTab:SetFrameStrata("FULLSCREEN")
    restoreTab:SetPoint("LEFT", backupTab, "RIGHT")
    restoreTab:SetText("Restore")
    restoreTab.tabName = "Restore"
    restoreTab:SetScript("OnLoad", nil)
    restoreTab:SetScript("OnShow", nil)
    restoreTab:SetScript("OnClick", function() SwitchTab("Restore") end)
    
    frame.tabs = { backupTab, restoreTab }
    local tabSize = 200 / 2
    PanelTemplates_TabResize(backupTab, nil, tabSize, tabSize)
    PanelTemplates_TabResize(restoreTab, nil, tabSize, tabSize)
    PanelTemplates_SelectTab(backupTab)
    PanelTemplates_DeselectTab(restoreTab)
    
    -- =========================================================
    -- Backup Panel
    -- =========================================================
    local backupPanel = CreateFrame("Frame", nil, frame)
    backupPanel:SetAllPoints(frame)
    backupPanel:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Instructions text
    local instructionsText = backupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructionsText:SetPoint("TOP", titleText, "BOTTOM", 0, -10)
    instructionsText:SetText("Copy the text below and save it as a backup. This includes all characters, achievements, progress, and settings.")
    instructionsText:SetTextColor(0.8, 0.8, 0.8, 1)
    instructionsText:SetWidth(550)
    instructionsText:SetJustifyH("CENTER")
    
    -- Static black background rectangle for text area with backdrop
    local backupBgFrame = CreateFrame("Frame", nil, backupPanel, "BackdropTemplate")
    backupBgFrame:SetPoint("TOP", instructionsText, "BOTTOM", -10, -10)
    backupBgFrame:SetSize(550, 260)
    backupBgFrame:SetFrameLevel(backupPanel:GetFrameLevel() - 1) -- Behind scroll frame
    
    backupBgFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 64,
        edgeSize = 16,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3,
        },
    })
    backupBgFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95) -- Darker, more solid background
    backupBgFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) -- Softer border
    
    -- Scroll frame for the serialized data
    local backupScrollFrame = CreateFrame("ScrollFrame", nil, backupPanel, "UIPanelScrollFrameTemplate")
    backupScrollFrame:SetPoint("TOP", instructionsText, "BOTTOM", -5, -15)
    backupScrollFrame:SetSize(550, 250)
    
    -- Edit box for the serialized data (read-only)
    local backupEditBox = CreateFrame("EditBox", nil, backupScrollFrame)
    backupEditBox:SetMultiLine(true)
    backupEditBox:SetFontObject("GameFontHighlightSmall")
    backupEditBox:SetWidth(530)
    backupEditBox:SetHeight(250)
    backupEditBox:SetAutoFocus(true)
    backupEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    
    -- Make read-only (allow selection but prevent editing)
    backupEditBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    
    backupEditBox:SetScript("OnChar", function(self)
        -- Prevent any text input - restore original text
        if self.originalText then
            self:SetText(self.originalText)
        end
    end)
    
    backupScrollFrame:SetScrollChild(backupEditBox)
    backupPanel.editBox = backupEditBox
    
    -- =========================================================
    -- Restore Panel
    -- =========================================================
    local restorePanel = CreateFrame("Frame", nil, frame)
    restorePanel:SetAllPoints(frame)
    restorePanel:SetFrameLevel(frame:GetFrameLevel() + 1)
    restorePanel:Hide()
    
    -- Warning text
    local warningText = restorePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warningText:SetPoint("TOP", titleText, "BOTTOM", 0, -10)
    warningText:SetText("|cffff0000WARNING:|r This will replace your entire database including all characters, achievements, progress, and settings. Paste your backup string below and click Import.")
    warningText:SetTextColor(1, 0.8, 0.8, 1)
    warningText:SetWidth(550)
    warningText:SetJustifyH("CENTER")
    
    -- Static black background rectangle for text area with backdrop
    local restoreBgFrame = CreateFrame("Frame", nil, restorePanel, "BackdropTemplate")
    restoreBgFrame:SetPoint("TOP", warningText, "BOTTOM", -10, -10)
    restoreBgFrame:SetSize(550, 230)
    restoreBgFrame:SetFrameLevel(restorePanel:GetFrameLevel() - 1) -- Behind scroll frame
    
    restoreBgFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 64,
        edgeSize = 16,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3,
        },
    })
    restoreBgFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95) -- Darker, more solid background
    restoreBgFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) -- Softer border
    
    -- Scroll frame for the input
    local restoreScrollFrame = CreateFrame("ScrollFrame", nil, restorePanel, "UIPanelScrollFrameTemplate")
    restoreScrollFrame:SetPoint("TOP", warningText, "BOTTOM", -5, -15)
    restoreScrollFrame:SetSize(550, 210)
    
    -- Edit box for pasting the serialized data
    local restoreEditBox = CreateFrame("EditBox", nil, restoreScrollFrame)
    restoreEditBox:SetMultiLine(true)
    restoreEditBox:SetFontObject("GameFontHighlightSmall")
    restoreEditBox:SetWidth(530)
    restoreEditBox:SetHeight(200)
    restoreEditBox:SetAutoFocus(true)
    restoreEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    
    restoreScrollFrame:SetScrollChild(restoreEditBox)
    restorePanel.editBox = restoreEditBox
    
    -- Import button
    local importButton = CreateFrame("Button", nil, restorePanel, "UIPanelButtonTemplate")
    importButton:SetPoint("TOP", restoreScrollFrame, "BOTTOM", 0, -15)
    importButton:SetText("Import Database and Reload UI")
    importButton:SetWidth(210)
    importButton:SetHeight(30)
    importButton:SetScript("OnClick", function(self)
        local text = restoreEditBox:GetText()
        if not text or text:match("^%s*$") then
            print("|cffff0000Hardcore Achievements:|r No data provided to import.")
            return
        end
        
        -- Try to decode and deserialize
        local success, data = HCA_DecodeData(text)
        if not success then
            -- Fallback: try old format (non-encoded) for backward compatibility
            local oldSuccess, oldData = AceSerialize:Deserialize(text)
            if oldSuccess then
                success = true
                data = oldData
                print("|cffffd100Hardcore Achievements:|r Using old format (non-encoded) backup.")
            else
                print("|cffff0000Hardcore Achievements:|r Failed to import database. Invalid backup string.")
                return
            end
        end
        
        -- Validate that it looks like the full database structure
        if type(data) ~= "table" or not data.chars or type(data.chars) ~= "table" then
            print("|cffff0000Hardcore Achievements:|r Invalid backup data format. Expected full database structure with 'chars' table.")
            return
        end
        
        -- Import the entire database structure
        if _G.HardcoreAchievementsDB then
            -- Deep copy function
            local function DeepCopy(orig)
                local orig_type = type(orig)
                local copy
                if orig_type == 'table' then
                    copy = {}
                    for orig_key, orig_value in next, orig, nil do
                        copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
                    end
                    setmetatable(copy, DeepCopy(getmetatable(orig)))
                else
                    copy = orig
                end
                return copy
            end
            
            -- Replace the entire database with imported data
            _G.HardcoreAchievementsDB = DeepCopy(data)
            
            print("|cff00ff00Hardcore Achievements:|r Database imported successfully! All characters and settings have been restored.")
            print("|cffffd100Hardcore Achievements:|r Reloading UI...")
            
            -- Close the frame
            frame:Hide()
            
            -- Reload UI to ensure everything is properly refreshed
            ReloadUI()
        else
            print("|cffff0000Hardcore Achievements:|r Database not available.")
        end
    end)
    
    -- Store references
    frame.backupPanel = backupPanel
    frame.restorePanel = restorePanel
    
    backupRestoreFrame = frame
    return frame
end

-- Function to export database
local function ExportDatabase()
    -- Access the full database structure
    if not _G.HardcoreAchievementsDB then
        print("|cffff0000Hardcore Achievements:|r No database found.")
        return
    end
    
    -- Create a deep copy of the entire database structure
    local function DeepCopy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
            end
            setmetatable(copy, DeepCopy(getmetatable(orig)))
        else
            copy = orig
        end
        return copy
    end
    
    local exportData = DeepCopy(_G.HardcoreAchievementsDB)
    
    -- Serialize, compress, and encode the data
    local encoded = HCA_EncodeData(exportData)
    
    -- Show the unified backup/restore frame with Backup tab active
    local frame = CreateBackupRestoreFrame()
    SwitchTab("Backup")
    frame.backupPanel.editBox:SetText(encoded)
    frame.backupPanel.editBox.originalText = encoded
    frame.backupPanel.editBox:HighlightText() -- Select all text for easy copying
    frame:Show()
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
    miscCategoryTitle:SetText("|cff11806aMiscellaneous|r")
    
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

    -- Award on Kill checkbox
    local awardOnKillCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    awardOnKillCB:SetPoint("TOPLEFT", disableScreenshotsCB, "BOTTOMLEFT", 0, -8)
    awardOnKillCB.Text:SetText("Award achievements on required kill instead of quest completion when available")
    awardOnKillCB:SetChecked(GetSetting("awardOnKill", false))
    awardOnKillCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        SetSetting("awardOnKill", isChecked)
    end)
    AddTooltipToCheckbox(awardOnKillCB, "If enabled, achievements that require an NPC kill will be awarded immediately on kill rather than waiting for quest completion.")

    -- Announce achievements in guild chat checkbox
    local announceInGuildChatCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    announceInGuildChatCB:SetPoint("TOPLEFT", awardOnKillCB, "BOTTOMLEFT", 0, -8)
    announceInGuildChatCB.Text:SetText("Announce achievements in guild chat")
    announceInGuildChatCB:SetChecked(GetSetting("announceInGuildChat", false))
    announceInGuildChatCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        SetSetting("announceInGuildChat", isChecked)
    end)
    AddTooltipToCheckbox(announceInGuildChatCB, "If enabled, achievements will be announced in guild chat when completed.")

    -- =========================================================
    -- User Interface Category
    -- =========================================================
    local uiCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    uiCategoryTitle:SetPoint("TOPLEFT", announceInGuildChatCB, "BOTTOMLEFT", 0, -15)
    uiCategoryTitle:SetText("|cff11806aUser Interface|r")
    
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
    -- Backup & Restore Category
    -- =========================================================
    local backupCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    backupCategoryTitle:SetPoint("TOPLEFT", resetTabButton, "BOTTOMLEFT", 0, -15)
    backupCategoryTitle:SetText("|cff11806aBackup & Restore|r")
    
    -- Backup and Restore Database button (opens unified frame with tabs)
    local backupRestoreButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    backupRestoreButton:SetPoint("TOPLEFT", backupCategoryTitle, "BOTTOMLEFT", 0, -8)
    backupRestoreButton:SetText("Backup and Restore Database")
    backupRestoreButton:SetWidth(220)
    backupRestoreButton:SetHeight(25)
    backupRestoreButton:SetScript("OnClick", function(self)
        -- Open the frame and switch to Backup tab, then load backup data
        local frame = CreateBackupRestoreFrame()
        SwitchTab("Backup")
        ExportDatabase()
    end)
    AddTooltipToCheckbox(backupRestoreButton, "Open the backup and restore window with tabs for exporting or importing your database")
    
    -- =========================================================
    -- Support & Contact Category
    -- =========================================================
    local supportCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    supportCategoryTitle:SetPoint("TOPLEFT", backupRestoreButton, "BOTTOMLEFT", 0, -15)
    supportCategoryTitle:SetText("|cff11806aSupport & Contact|r")
    
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

    -- =========================================================
    -- Credits
    -- =========================================================
    local creditsCategoryTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    creditsCategoryTitle:SetPoint("TOPLEFT", discordButton, "BOTTOMLEFT", 0, -15)
    creditsCategoryTitle:SetText("|cff11806aCredits|r")
    
    -- Credits text
    local creditsText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    creditsText:SetPoint("TOPLEFT", creditsCategoryTitle, "BOTTOMLEFT", 0, -8)
    creditsText:SetText("Special thanks to:\n\n|cffff8000Viviway|r for the help with the addon and the overall design for UI.\n|cffff8000Tulhur|r for the help with tracking down bugs and all his suggestions.\n|cffff8000BonniesDad|r for supplying the Ultra Hardcore addon and allowing Hardcore Achivements to thrive.")
    creditsText:SetTextColor(0.8, 0.8, 0.8, 1)
    creditsText:SetWidth(600)
    creditsText:SetJustifyH("LEFT")
    creditsText:SetJustifyV("TOP")
    
    -- Store references for future use
    panel.checkboxes = {
        disableScreenshots = disableScreenshotsCB,
        awardOnKill = awardOnKillCB,
        announceInGuildChat = announceInGuildChatCB,
        modernRows = modernRowsCB,
    }
    panel.modernRows = modernRowsCB
    panel.buttons = {
        resetAchievementsTab = resetTabButton,
        discord = discordButton,
        backupRestore = backupRestoreButton,
    }

    -- Refresh function to update checkboxes when panel is shown
    panel.refresh = function(self)
        -- Update checkbox state from database
        if disableScreenshotsCB then
            disableScreenshotsCB:SetChecked(GetSetting("disableScreenshots", false))
        end
        if awardOnKillCB then
            awardOnKillCB:SetChecked(GetSetting("awardOnKill", false))
        end
        if announceInGuildChatCB then
            announceInGuildChatCB:SetChecked(GetSetting("announceInGuildChat", false))
        end
        if modernRowsCB then
            modernRowsCB:SetChecked(GetSetting("modernRows", true))
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

-- Global function to open backup/restore frame
function HardcoreAchievements_ShowBackupRestore()
    local frame = CreateBackupRestoreFrame()
    SwitchTab("Backup")
    ExportDatabase()
end