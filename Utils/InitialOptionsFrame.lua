-- Utils/InitialOptionsFrame.lua
-- One-time initial options frame for new characters (review options on first load).
-- UI style matches Dashboard.lua: backdrop, title bar, checkboxes, fonts.

local ADDON_NAME = "HardcoreAchievements"
local POINTS_FONT_PATH = "Interface\\AddOns\\HardcoreAchievements\\Fonts\\friz-quadrata-regular.ttf"
local CHECKBOX_TEXTURE_NORMAL = "Interface\\AddOns\\HardcoreAchievements\\Images\\box.png"
local CHECKBOX_TEXTURE_ACTIVE = "Interface\\AddOns\\HardcoreAchievements\\Images\\box_active.png"
local TITLE_COLOR = { 0.922, 0.871, 0.761 }

-- Class background textures (same as Dashboard.lua)
local CLASS_BACKGROUND_MAP = {
    WARRIOR = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_warrior.png",
    PALADIN = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_pally.png",
    HUNTER = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_hunter.png",
    ROGUE = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_rogue.png",
    PRIEST = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_priest.png",
    SHAMAN = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_shaman.png",
    MAGE = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_mage.png",
    WARLOCK = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_warlock.png",
    DRUID = "Interface\\AddOns\\HardcoreAchievements\\Images\\bg_druid.png",
}
local CLASS_BACKGROUND_ASPECT_RATIO = 1200 / 700

local InitialOptionsFrame = nil

local function GetClassBackgroundTexture()
    local _, classFileName = UnitClass("player")
    if classFileName and CLASS_BACKGROUND_MAP[classFileName] then
        return CLASS_BACKGROUND_MAP[classFileName]
    end
    return "Interface\\DialogFrame\\UI-DialogBox-Background"
end

local function GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function ApplyCustomCheckboxTextures(checkbox)
    if not checkbox then return end
    checkbox:SetNormalTexture(CHECKBOX_TEXTURE_NORMAL)
    checkbox:SetPushedTexture(CHECKBOX_TEXTURE_NORMAL)
    checkbox:SetHighlightTexture(CHECKBOX_TEXTURE_NORMAL, "ADD")
    checkbox:SetCheckedTexture(CHECKBOX_TEXTURE_ACTIVE)
    checkbox:SetDisabledCheckedTexture(CHECKBOX_TEXTURE_ACTIVE)
    local r, g, b = GetPlayerClassColor()
    local checked = checkbox:GetCheckedTexture()
    if checked then
        checked:SetVertexColor(r, g, b)
    end
    local disabledChecked = checkbox:GetDisabledCheckedTexture()
    if disabledChecked then
        disabledChecked:SetVertexColor(r, g, b)
    end
end

local function getSetting(name, default)
    if type(HardcoreAchievements_GetCharDB) ~= "function" then return default end
    local _, cdb = HardcoreAchievements_GetCharDB()
    if cdb and cdb.settings and cdb.settings[name] ~= nil then
        return cdb.settings[name]
    end
    return default
end

local function setSetting(name, value)
    if type(HardcoreAchievements_GetCharDB) ~= "function" then return end
    local _, cdb = HardcoreAchievements_GetCharDB()
    if cdb then
        cdb.settings = cdb.settings or {}
        cdb.settings[name] = value
    end
end

local function CreateInitialOptionsFrame()
    if InitialOptionsFrame then return InitialOptionsFrame end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "HardcoreAchievementsInitialOptions", UIParent, backdropTemplate)
    frame:SetSize(320, 200)
    frame:SetPoint("CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClipsChildren(true)
    frame:Hide()

    -- Class-based background texture (Dashboard-style)
    frame.ClassBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.ClassBackground:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.ClassBackground:SetTexture(GetClassBackgroundTexture())
    --frame.ClassBackground:SetTexCoord(0, 1, 0, 1)
    local frameHeight = frame:GetHeight()
    frame.ClassBackground:SetSize(frameHeight * CLASS_BACKGROUND_ASPECT_RATIO, frameHeight)

    -- Backdrop (Dashboard-style): border only, no fill so class texture shows through
    if frame.SetBackdrop then
        frame:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame:SetBackdropBorderColor(0, 0, 0, 1)
        frame:SetBackdropColor(0, 0, 0, 0)  -- transparent so class background is visible
    end

    -- Title bar (Dashboard-style)
    local titleBar = CreateFrame("Frame", nil, frame, backdropTemplate)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    if titleBar.SetBackdrop then
        titleBar:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        titleBar:SetBackdropBorderColor(0, 0, 0, 1)
        titleBar:SetBackdropColor(0, 0, 0, 0.95)
    end

    local headerTexture = "Interface\\AddOns\\HardcoreAchievements\\Images\\header.png"
    local titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBarBg:SetAllPoints()
    titleBarBg:SetTexture(headerTexture)
    titleBarBg:SetTexCoord(0, 1, 0, 1)

    -- Logo in top left corner of title bar
    local logoSize = 24
    local titleBarLogo = titleBar:CreateTexture(nil, "OVERLAY")
    titleBarLogo:SetSize(logoSize, logoSize)
    titleBarLogo:SetPoint("LEFT", titleBar, "LEFT", 5, 0)
    titleBarLogo:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png")
    titleBarLogo:SetTexCoord(0, 1, 0, 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetFont(POINTS_FONT_PATH, 18)
    titleText:SetTextColor(GetPlayerClassColor())
    titleText:SetText("Hardcore Achievements")

    -- Divider below title (Dashboard-style)
    local divider = CreateFrame("Frame", nil, frame)
    divider:SetHeight(16)
    divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", -3, 5)
    divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 3, 5)
    local dividerTex = divider:CreateTexture(nil, "ARTWORK")
    dividerTex:SetAllPoints()
    dividerTex:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\divider.png")
    dividerTex:SetTexCoord(0, 1, 0, 1)

    -- "Review your options" in main frame below divider
    local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleText:SetPoint("TOP", divider, "BOTTOM", 0, 0)
    subtitleText:SetFont(POINTS_FONT_PATH, 14)
    subtitleText:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
    subtitleText:SetText("Initial Setup Options")

    local anchor = subtitleText

    local function setCheckboxLabel(cb, text)
        local label = cb.text or cb.Text
        if label then
            label:SetText(text)
            label:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
            label:ClearAllPoints()
            label:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        end
    end

    -- Tooltip helper (same as OptionsPanel)
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

    -- Disable Screenshots
    local disableScreenshotsCB = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    disableScreenshotsCB:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 16, -24)
    disableScreenshotsCB:SetSize(10, 10)
    setCheckboxLabel(disableScreenshotsCB, "Disable Screenshots")
    disableScreenshotsCB:SetChecked(getSetting("disableScreenshots", false))
    ApplyCustomCheckboxTextures(disableScreenshotsCB)
    AddTooltipToCheckbox(disableScreenshotsCB, "Prevent the addon from taking screenshots when achievements are completed.")
    disableScreenshotsCB:SetScript("OnClick", function(self)
        setSetting("disableScreenshots", self:GetChecked())
    end)

    -- Announce achievements in guild chat
    local announceInGuildChatCB = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    announceInGuildChatCB:SetPoint("TOPLEFT", disableScreenshotsCB, "BOTTOMLEFT", 0, -10)
    announceInGuildChatCB:SetSize(10, 10)
    setCheckboxLabel(announceInGuildChatCB, "Announce achievements in guild chat")
    announceInGuildChatCB:SetChecked(getSetting("announceInGuildChat", true))
    ApplyCustomCheckboxTextures(announceInGuildChatCB)
    AddTooltipToCheckbox(announceInGuildChatCB, "If enabled, achievements will be announced in guild chat when completed.")
    announceInGuildChatCB:SetScript("OnClick", function(self)
        setSetting("announceInGuildChat", self:GetChecked())
    end)

    -- Show Achievements on the Character Info Panel
    local useCharacterPanelCB = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    useCharacterPanelCB:SetPoint("TOPLEFT", announceInGuildChatCB, "BOTTOMLEFT", 0, -10)
    useCharacterPanelCB:SetSize(10, 10)
    setCheckboxLabel(useCharacterPanelCB, "Show Achievements on the Character Info Panel")
    useCharacterPanelCB:SetChecked(getSetting("useCharacterPanel", true))
    ApplyCustomCheckboxTextures(useCharacterPanelCB)
    AddTooltipToCheckbox(useCharacterPanelCB, "If enabled, the Achievements tab will appear on the Character (C) frame.")
    useCharacterPanelCB:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        setSetting("useCharacterPanel", isChecked)
        setSetting("showCustomTab", isChecked)
        if _G.HCA_SharedUtils and _G.HCA_SharedUtils.UpdateCharacterPanelTabVisibility then
            _G.HCA_SharedUtils.UpdateCharacterPanelTabVisibility()
        end
        -- Sync Dashboard checkbox if it exists (so Dashboard stays in sync when open)
        local dashboardFrame = _G.HardcoreAchievementsDashboard
        if dashboardFrame and dashboardFrame.UseCharacterPanelCheckbox then
            dashboardFrame.UseCharacterPanelCheckbox:SetChecked(isChecked)
        end
    end)

    -- Done button
    local doneBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    doneBtn:SetSize(120, 24)
    doneBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
    doneBtn:SetText("Save and Close")
    doneBtn:SetScript("OnClick", function()
        if type(HardcoreAchievements_GetCharDB) == "function" then
            local _, cdb = HardcoreAchievements_GetCharDB()
            if cdb then
                cdb.settings = cdb.settings or {}
                cdb.settings.initialSetupDone = true
            end
        end
        frame:Hide()
        if _HardcoreAchievementsOptionsPanel and _HardcoreAchievementsOptionsPanel.refresh then
            _HardcoreAchievementsOptionsPanel:refresh()
        end
    end)

    InitialOptionsFrame = frame
    return frame
end

function HardcoreAchievements_ShowInitialOptionsIfNeeded()
    if type(HardcoreAchievements_GetCharDB) ~= "function" then return end
    local _, cdb = HardcoreAchievements_GetCharDB()
    if not cdb then return end
    cdb.settings = cdb.settings or {}
    if cdb.settings.initialSetupDone == true then return end
    local frame = CreateInitialOptionsFrame()
    frame:Show()
end
