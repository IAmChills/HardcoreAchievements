-- CharacterInspection.lua
-- Handles character inspection with achievement data sharing
-- Integrates with HardcoreAchievements to show other players' achievements
--
-- How it works:
-- 1. When you inspect another player, a new "Achievements" tab appears on their inspection frame
-- 2. Clicking the tab sends a whisper request to the target player asking for their achievement data
-- 3. If they have the HardcoreAchievements addon, they respond with serialized achievement data
-- 4. The data is displayed in the same format as your own achievements panel
-- 5. Data is cached for 5 minutes to avoid repeated requests
--
-- Communication Protocol:
-- - HCA_Inspect: Request for achievement data
-- - HCA_InspectResp: Response indicating if addon is available
-- - HCA_InspectData: Actual achievement data transmission

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local CharacterInspection = {}
local INSPECTION_COMM_PREFIX = "HCA_Inspect" -- AceComm prefix for inspection requests
local INSPECTION_RESPONSE_PREFIX = "HCA_InspectResp" -- AceComm prefix for inspection responses
local INSPECTION_DATA_PREFIX = "HCA_InspectData" -- AceComm prefix for achievement data

-- Localize frequently-used WoW API globals (micro-optimization, no behavior change)
local _G = _G
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetLocale = GetLocale
local date = date
local time = time
local wipe = wipe
local hooksecurefunc = hooksecurefunc
local IsShiftKeyDown = IsShiftKeyDown
local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
local table_insert = table.insert
local table_sort = table.sort
local table_concat = table.concat
local string_format = string.format

-- Cache for inspection data to avoid repeated requests
local inspectionCache = {}
local CACHE_DURATION = 300 -- 5 minutes

-- Current inspection target
local currentInspectionTarget = nil
local inspectionFrame = nil
local inspectionAchievementPanel = nil
local achievementDefinitionCache = {}
local panelIndexed = false
local inspectionTabID = nil
local HANDSHAKE_TIMEOUT = 3
local handshakeTimer = nil
local handshakeTarget = nil

local function NormalizeAchievementId(achId)
    if achId == nil then
        return nil
    end
    if type(achId) == "number" then
        return tostring(achId)
    end
    return achId
end

local function InspectStripColorCodes(text)
    if not text or type(text) ~= "string" then return text end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function InspectHasVisibleText(value)
    if type(value) ~= "string" then
        return false
    end
    return value:match("%S") ~= nil
end

local function UpdateInspectionRowTextLayout(row)
    if not row or not row.Icon or not row.Title or not row.Sub then
        return
    end

    local hasSubText = InspectHasVisibleText(row.Sub:GetText())

    row.Title:ClearAllPoints()
    row.Sub:ClearAllPoints()
    if row.TitleShadow then
        row.TitleShadow:ClearAllPoints()
    end

    if hasSubText then
        local text = row.Sub:GetText()
        local extraLines = 0
        if text and text ~= "" then
            local _, newlines = text:gsub("\n", "")
            extraLines = math.max(0, newlines)
        end
        local yOffset = 11 + (extraLines * 5)
        row.Title:SetPoint("TOPLEFT", row.Icon, "RIGHT", 8, yOffset)
        row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -1)
        row.Sub:Show()
    else
        row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
        row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
        row.Sub:Hide()
    end

    if row.TitleShadow then
        row.TitleShadow:SetPoint("LEFT", row.Title, "LEFT", 1, -1)
    end
end

local function HookInspectionRowSubTextUpdates(row)
    if not row or not row.Sub or row.Sub._hcaSetTextWrapped then
        return
    end

    local fontString = row.Sub
    local originalSetText = fontString.SetText
    local originalSetFormattedText = fontString.SetFormattedText

    fontString.SetText = function(self, text, ...)
        originalSetText(self, text, ...)
        UpdateInspectionRowTextLayout(row)
    end

    fontString.SetFormattedText = function(self, ...)
        originalSetFormattedText(self, ...)
        UpdateInspectionRowTextLayout(row)
    end

    fontString._hcaSetTextWrapped = true
end

local function IsInspectionRowOutleveled(row)
    if not row or row.completed then return false end
    if not row.maxLevel then return false end
    local lvl = UnitLevel("player") or 1
    return lvl > row.maxLevel
end

local function FormatInspectionTimestamp(timestamp)
    if not timestamp then return "" end
    local dateInfo = date("*t", timestamp)
    if not dateInfo then return "" end

    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "enUS" then
        return string_format("%02d/%02d/%02d",
            dateInfo.month,
            dateInfo.day,
            dateInfo.year % 100)
    else
        return string_format("%02d/%02d/%02d",
            dateInfo.day,
            dateInfo.month,
            dateInfo.year % 100)
    end
end

local function UpdateInspectionPointsDisplay(row)
    if not row or not row.PointsFrame then return end

    local isOutleveled = IsInspectionRowOutleveled(row)

    if row.PointsFrame.Texture then
        if row.completed then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_gold.png")
        elseif isOutleveled then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_failed.png")
        else
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.png")
        end
        row.PointsFrame.Texture:SetAlpha(1)
    end

    if row.Points then
        if row.completed or isOutleveled then
            row.Points:SetAlpha(0)
        else
            row.Points:SetAlpha(1)
        end
    end

    if row.PointsFrame.Checkmark then
        if row.completed then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-Ready.png")
            row.PointsFrame.Checkmark:Show()
        elseif isOutleveled then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
            row.PointsFrame.Checkmark:Show()
        else
            row.PointsFrame.Checkmark:Hide()
        end
    end

    if row.IconOverlay then
        if isOutleveled then
            row.IconOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
            row.IconOverlay:Show()
        else
            row.IconOverlay:Hide()
        end
    end

    if row.IconFrameGold and row.IconFrame then
        if row.completed then
            row.IconFrameGold:Show()
            row.IconFrame:Hide()
        else
            row.IconFrameGold:Hide()
            row.IconFrame:Show()
        end
    end

    if row.Title then
        if row.completed then
            row.Title:SetTextColor(1, 0.82, 0)
        elseif isOutleveled then
            row.Title:SetTextColor(0.957, 0.263, 0.212)
        else
            row.Title:SetTextColor(1, 1, 1)
        end
    end

    if row.Sub then
        if row.completed then
            row.Sub:SetTextColor(1, 1, 1)
        else
            row.Sub:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    if row.Icon and row.Icon.SetDesaturated then
        -- Completed achievements are full color; failed/outleveled should remain desaturated
        if row.completed then
            row.Icon:SetDesaturated(false)
        else
            row.Icon:SetDesaturated(true)
        end
    end

    if row.Background then
        if row.completed then
            row.Background:SetVertexColor(0.1, 1.0, 0.1)
        elseif isOutleveled then
            row.Background:SetVertexColor(1.0, 0.1, 0.1)
        else
            row.Background:SetVertexColor(1, 1, 1)
        end
        row.Background:SetAlpha(1)
    end

    if row.Border then
        if row.completed then
            row.Border:SetVertexColor(0.6, 0.9, 0.6)
        elseif isOutleveled then
            row.Border:SetVertexColor(0.957, 0.263, 0.212)
        else
            row.Border:SetVertexColor(0.8, 0.8, 0.8)
        end
        row.Border:SetAlpha(0.5)
    end
    
    if row.TS then
        if row.completed then
            row.TS:SetTextColor(1, 1, 1)
        elseif isOutleveled then
            row.TS:SetTextColor(0.957, 0.263, 0.212)
        else
            row.TS:SetTextColor(1, 1, 1)
        end
    end
end

local function ClearInspectionAchievementRows(statusText, statusColor)
    if not inspectionAchievementPanel or not inspectionAchievementPanel.achievements then return end

    for _, row in ipairs(inspectionAchievementPanel.achievements) do
        if row and row:IsObjectType("Frame") then
            if row.Border then row.Border:Hide() end
            if row.Background then row.Background:Hide() end
            row:Hide()
            row:SetParent(nil)
        end
    end

    wipe(inspectionAchievementPanel.achievements)

    if inspectionAchievementPanel.Content and inspectionAchievementPanel.Scroll then
        inspectionAchievementPanel.Content:SetHeight(inspectionAchievementPanel.Scroll:GetHeight() or 0)
        inspectionAchievementPanel.Scroll:UpdateScrollChildRect()
    end

    if inspectionAchievementPanel.StatusText then
        if statusText then
            inspectionAchievementPanel.StatusText:SetText(statusText)
            local r, g, b = 1, 1, 0
            if type(statusColor) == "table" then
                r = tonumber(statusColor[1]) or r
                g = tonumber(statusColor[2]) or g
                b = tonumber(statusColor[3]) or b
            end
            inspectionAchievementPanel.StatusText:SetTextColor(r, g, b)
            inspectionAchievementPanel.StatusText:Show()
        else
            inspectionAchievementPanel.StatusText:SetText("")
            inspectionAchievementPanel.StatusText:Hide()
        end
    end

    if inspectionAchievementPanel.TotalPoints then
        inspectionAchievementPanel.TotalPoints:SetText("0 pts")
    end

    if inspectionAchievementPanel.CountsText then
        inspectionAchievementPanel.CountsText:SetText("(0/0)")
    end
end

CharacterInspection.ClearInspectionAchievementRows = ClearInspectionAchievementRows

local function CancelInspectionHandshakeTimer()
    if handshakeTimer and handshakeTimer.Cancel then
        handshakeTimer:Cancel()
    end
    handshakeTimer = nil
    handshakeTarget = nil
end

local function StartInspectionHandshakeTimer(targetName)
    CancelInspectionHandshakeTimer()
    handshakeTarget = targetName
    if C_Timer and C_Timer.NewTimer then
        handshakeTimer = C_Timer.NewTimer(HANDSHAKE_TIMEOUT, function()
            if currentInspectionTarget == targetName then
                ClearInspectionAchievementRows("No response from " .. targetName .. ". They may not have HardcoreAchievements installed.", {1, 0.5, 0.5})
            end
            CancelInspectionHandshakeTimer()
        end)
    end
end

local function PositionInspectionRowBorder(row)
    if not row or not inspectionAchievementPanel or not inspectionAchievementPanel.BorderClip then
        return
    end
    if not row.Border then return end

    if not row:IsShown() then
        row.Border:Hide()
        if row.Background then
            row.Background:Hide()
        end
        return
    end

    row.Border:ClearAllPoints()
    row.Border:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
    row.Border:SetSize(295, 43)
    row.Border:Show()

    if row.Background then
        row.Background:ClearAllPoints()
        row.Background:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
        row.Background:SetSize(295, 43)
        row.Background:Show()
    end
end

local function IndexLocalAchievementRows()
    if panelIndexed then return end
    if not AchievementPanel or not AchievementPanel.achievements then return end

    for _, row in ipairs(AchievementPanel.achievements) do
        local id = row.id or row.achId
        local key = NormalizeAchievementId(id)
        if key and not achievementDefinitionCache[key] then
            achievementDefinitionCache[key] = {
                achId = id,
                title = row.Title and row.Title.GetText and row.Title:GetText() or (type(id) == "string" and id or "Unknown Achievement"),
                tooltip = row.tooltip or "",
                icon = row.Icon and row.Icon:GetTexture() or 136116,
                points = row.originalPoints or row.points or 0,
                level = row.maxLevel or row.level,
                zone = row.zone,
            }
        end
    end

    panelIndexed = true
end

local function GetAchievementDefinition(achId)
    if not achId then return nil end

    local key = NormalizeAchievementId(achId)
    if not key then return nil end

    if achievementDefinitionCache[key] then
        return achievementDefinitionCache[key]
    end

    IndexLocalAchievementRows()
    if achievementDefinitionCache[key] then
        return achievementDefinitionCache[key]
    end

    if _G.HCA_AchievementDefs and _G.HCA_AchievementDefs[key] then
        local def = _G.HCA_AchievementDefs[key]
        achievementDefinitionCache[key] = {
            achId = def.achId or achId,
            title = def.title or (type(achId) == "string" and achId or "Unknown Achievement"),
            tooltip = def.tooltip or "",
            icon = def.icon or 136116,
            points = def.points or 0,
            level = def.level,
            zone = def.zone or def.mapName,
            requiredKills = def.requiredKills,
            bossOrder = def.bossOrder,
        }
        return achievementDefinitionCache[key]
    end

    return nil
end

CharacterInspection.GetAchievementDefinition = GetAchievementDefinition

-- Initialize the inspection system
local function InitializeInspectionSystem()
    -- Register AceComm handlers
    AceComm:RegisterComm(INSPECTION_COMM_PREFIX, CharacterInspection.OnInspectionRequest)
    AceComm:RegisterComm(INSPECTION_RESPONSE_PREFIX, CharacterInspection.OnInspectionResponse)
    AceComm:RegisterComm(INSPECTION_DATA_PREFIX, CharacterInspection.OnInspectionData)
    
    -- Hook into the inspection frame
    CharacterInspection.HookInspectionFrame()
end

-- Hook into the inspection frame to add our achievement tab
function CharacterInspection.HookInspectionFrame()
    -- Wait for inspection frame to be available
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Blizzard_InspectUI" or InspectFrame then
            CharacterInspection.SetupInspectionTab()
            self:UnregisterAllEvents()
        end
    end)
    
    -- Also try to hook immediately if frame already exists
    if InspectFrame then
        CharacterInspection.SetupInspectionTab()
    end
end

-- Setup the achievement tab on the inspection frame
function CharacterInspection.SetupInspectionTab()
    if not InspectFrame or inspectionAchievementPanel then return end
    
    -- Create achievement tab
    local tabID = (InspectFrame.numTabs or 0) + 1
    local achievementTab = CreateFrame("Button", "InspectFrameTab" .. tabID, InspectFrame, "CharacterFrameTabButtonTemplate")
    achievementTab:SetID(tabID)
    achievementTab:SetPoint("LEFT", _G["InspectFrameTab" .. (tabID - 1)], "RIGHT", -15, 0)
    achievementTab:SetText(ACHIEVEMENTS)
    PanelTemplates_DeselectTab(achievementTab)
    inspectionTabID = tabID
    InspectFrame.numTabs = tabID
    PanelTemplates_SetNumTabs(InspectFrame, tabID)
    
    -- Create achievement panel for inspection
    inspectionAchievementPanel = CreateFrame("Frame", "InspectAchievementPanel", InspectFrame)
    inspectionAchievementPanel:Hide()
    inspectionAchievementPanel:EnableMouse(true)
    inspectionAchievementPanel:SetAllPoints(InspectFrame)
    
    -- Setup the achievement panel UI (similar to main achievement panel)
    CharacterInspection.SetupInspectionAchievementPanel()
    
    -- Tab click handler
    achievementTab.subFrame = "InspectAchievementPanel"
    achievementTab:SetScript("OnClick", function(self)
        PanelTemplates_SetTab(InspectFrame, self:GetID())
        if InspectFrame_ShowSubFrame then
            InspectFrame_ShowSubFrame(self.subFrame)
        else
            CharacterInspection.ShowInspectionAchievementTab()
        end
    end)
    
    -- Hook into inspection frame tab switching
    if InspectFrame_ShowSubFrame then
        hooksecurefunc("InspectFrame_ShowSubFrame", function(frameName)
            if frameName == "InspectAchievementPanel" then
                CharacterInspection.ShowInspectionAchievementTab()
            elseif inspectionAchievementPanel and inspectionAchievementPanel:IsShown() then
                inspectionAchievementPanel:Hide()
            end
        end)
    elseif InspectFrameTab_OnClick then
        hooksecurefunc("InspectFrameTab_OnClick", function(tabID)
            if tabID == inspectionTabID then
                CharacterInspection.ShowInspectionAchievementTab()
            elseif inspectionAchievementPanel and inspectionAchievementPanel:IsShown() then
                inspectionAchievementPanel:Hide()
            end
        end)
    end

    -- Ensure the default inspect framework knows about our new panel
    if type(INSPECTFRAME_SUBFRAMES) == "table" then
        local exists = false
        for _, name in ipairs(INSPECTFRAME_SUBFRAMES) do
            if name == "InspectAchievementPanel" then
                exists = true
                break
            end
        end
        if not exists then
            table_insert(INSPECTFRAME_SUBFRAMES, "InspectAchievementPanel")
        end
    end
end

-- Setup the inspection achievement panel UI
function CharacterInspection.SetupInspectionAchievementPanel()
    if not inspectionAchievementPanel then return end
    
    -- Title
    -- inspectionAchievementPanel.Title = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    -- inspectionAchievementPanel.Title:SetPoint("TOP", inspectionAchievementPanel, "TOP", 0, -20)
    -- inspectionAchievementPanel.Title:SetText(ACHIEVEMENTS)
    -- inspectionAchievementPanel.Title:SetTextColor(1, 1, 0)
    
    -- Total points display
    inspectionAchievementPanel.TotalPoints = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    inspectionAchievementPanel.TotalPoints:SetPoint("TOP", inspectionAchievementPanel, "TOP", 5, -30)
    inspectionAchievementPanel.TotalPoints:SetText("0 pts")
    inspectionAchievementPanel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)
    
    inspectionAchievementPanel.CountsText = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inspectionAchievementPanel.CountsText:SetPoint("CENTER", inspectionAchievementPanel.TotalPoints, "CENTER", 0, -15)
    inspectionAchievementPanel.CountsText:SetText("(0/0)")
    inspectionAchievementPanel.CountsText:SetTextColor(0.8, 0.8, 0.8)
    
    -- Status text (loading, error, etc.)
    inspectionAchievementPanel.StatusText = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inspectionAchievementPanel.StatusText:SetPoint("CENTER", inspectionAchievementPanel, "CENTER", -10, 0)
    inspectionAchievementPanel.StatusText:SetText("Requesting achievement data...")
    inspectionAchievementPanel.StatusText:SetTextColor(1, 1, 0)
    inspectionAchievementPanel.StatusText:SetJustifyH("CENTER")
    inspectionAchievementPanel.StatusText:SetJustifyV("MIDDLE")
    inspectionAchievementPanel.StatusText:SetWordWrap(true)
    
    -- Scrollable container
    inspectionAchievementPanel.Scroll = CreateFrame("ScrollFrame", "$parentScroll", inspectionAchievementPanel, "UIPanelScrollFrameTemplate")
    inspectionAchievementPanel.Scroll:SetPoint("TOPLEFT", 10, -65)
    inspectionAchievementPanel.Scroll:SetPoint("BOTTOMRIGHT", -35, 10)
    
    -- Content frame
    inspectionAchievementPanel.Content = CreateFrame("Frame", nil, inspectionAchievementPanel.Scroll)
    inspectionAchievementPanel.Content:SetPoint("TOPLEFT")
    inspectionAchievementPanel.Content:SetSize(1, 1)
    inspectionAchievementPanel.Scroll:SetScrollChild(inspectionAchievementPanel.Content)
    
    inspectionAchievementPanel.Content:SetWidth(inspectionAchievementPanel.Scroll:GetWidth())
    if inspectionAchievementPanel.StatusText then
        inspectionAchievementPanel.StatusText:SetWidth(math.max((inspectionAchievementPanel.Scroll:GetWidth() or 0) - 20, 200))
    end
    inspectionAchievementPanel.Scroll:SetScript("OnSizeChanged", function(self)
        inspectionAchievementPanel.Content:SetWidth(self:GetWidth())
        self:UpdateScrollChildRect()
        if inspectionAchievementPanel.StatusText then
            inspectionAchievementPanel.StatusText:SetWidth(math.max((self:GetWidth() or 0) - 20, 200))
        end
    end)
    
    if not inspectionAchievementPanel.BorderClip then
        inspectionAchievementPanel.BorderClip = CreateFrame("Frame", nil, inspectionAchievementPanel)
        inspectionAchievementPanel.BorderClip:SetPoint("TOPLEFT", inspectionAchievementPanel.Scroll, "TOPLEFT", -10, 2)
        inspectionAchievementPanel.BorderClip:SetPoint("BOTTOMRIGHT", inspectionAchievementPanel.Scroll, "BOTTOMRIGHT", 10, -2)
        inspectionAchievementPanel.BorderClip:SetClipsChildren(true)
    end
    
    -- Mouse wheel support
    inspectionAchievementPanel.Scroll:EnableMouseWheel(true)
    inspectionAchievementPanel.Scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 36
        local cur = self:GetVerticalScroll()
        local maxV = self:GetVerticalScrollRange() or 0
        local newV = math.min(maxV, math.max(0, cur - delta * step))
        self:SetVerticalScroll(newV)
        
        local sb = self.ScrollBar or (self:GetName() and _G[self:GetName().."ScrollBar"])
        if sb then sb:SetValue(newV) end
    end)
    
    -- Background textures (same as main panel)
    local TL = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    TL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
    TL:SetPoint("TOPLEFT", -13, 13)
    TL:SetSize(258, 258)
    
    local TR = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    TR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
    TR:SetPoint("TOPLEFT", TL, "TOPRIGHT", 0, 0)
    TR:SetPoint("RIGHT", inspectionAchievementPanel, "RIGHT", 32, -1)
    TR:SetHeight(258)
    
    local BL = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    BL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
    BL:SetPoint("TOPLEFT", TL, "BOTTOMLEFT", 0, 0)
    BL:SetPoint("BOTTOMLEFT", inspectionAchievementPanel, "BOTTOMLEFT", 2, -75)
    BL:SetWidth(258)
    
    local BR = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    BR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
    BR:SetPoint("TOPLEFT", BL, "TOPRIGHT", 0, 0)
    BR:SetPoint("LEFT", TR, "LEFT", 0, 0)
    BR:SetPoint("BOTTOMRIGHT", inspectionAchievementPanel, "BOTTOMRIGHT", 32, -75)
    
    -- Initialize achievements array
    inspectionAchievementPanel.achievements = {}
end

-- Show the inspection achievement tab
function CharacterInspection.ShowInspectionAchievementTab()
    if not InspectFrame or not inspectionAchievementPanel then return end
    
    -- Play tab sound
    if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    else
        PlaySound("igCharacterInfoTab")
    end
    
    -- Deselect other tabs
    for i = 1, InspectFrame.numTabs do
        local tab = _G["InspectFrameTab" .. i]
        if tab then
            PanelTemplates_DeselectTab(tab)
        end
    end
    
    -- Select our tab
    local tabID = inspectionTabID or InspectFrame.numTabs
    local achievementTab = _G["InspectFrameTab" .. tabID]
    if achievementTab then
        PanelTemplates_SelectTab(achievementTab)
    end
    
    -- Hide other subframes
    if type(INSPECTFRAME_SUBFRAMES) == "table" then
        for _, frameName in ipairs(INSPECTFRAME_SUBFRAMES) do
            if frameName ~= "InspectAchievementPanel" then
                local frame = _G[frameName]
                if frame and frame.Hide then
                    frame:Hide()
                end
            end
        end
    end
    if InspectPaperDollFrame then InspectPaperDollFrame:Hide() end
    if InspectHonorFrame then InspectHonorFrame:Hide() end
    if InspectTalentFrame then InspectTalentFrame:Hide() end
    if InspectPVPFrame then InspectPVPFrame:Hide() end
    
    -- Show our panel
    inspectionAchievementPanel:Show()
    
    -- Request achievement data if we have a target
    local targetName = UnitName("target")
    if targetName and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        CharacterInspection.RequestAchievementData(targetName)
    end
end

-- Request achievement data from target player
function CharacterInspection.RequestAchievementData(targetName)
    if not targetName then return end
    
    currentInspectionTarget = targetName
    
    -- Check cache first
    local cacheKey = targetName
    local cachedData = inspectionCache[cacheKey]
    if cachedData and (time() - cachedData.timestamp) < CACHE_DURATION then
        CancelInspectionHandshakeTimer()
        CharacterInspection.DisplayAchievementData(cachedData.data)
        return
    end
    
    -- Show loading state
    ClearInspectionAchievementRows("Checking for HardcoreAchievements addon on " .. targetName .. "...", {1, 1, 0})
    StartInspectionHandshakeTimer(targetName)
    
    -- Send request
    local requestPayload = {
        type = "achievement_request",
        timestamp = time(),
        requester = UnitName("player")
    }
    
    local serializedRequest = AceSerialize:Serialize(requestPayload)
    if serializedRequest then
        AceComm:SendCommMessage(INSPECTION_COMM_PREFIX, serializedRequest, "WHISPER", targetName)
    end
end

-- Handle incoming inspection requests
function CharacterInspection.OnInspectionRequest(prefix, message, distribution, sender)
    if prefix ~= INSPECTION_COMM_PREFIX then return end
    
    local success, payload = AceSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "achievement_request" then return end
    
    -- Send response indicating we have the addon
    local responsePayload = {
        type = "achievement_response",
        timestamp = time(),
        hasAddon = true,
        requester = payload.requester
    }
    
    local serializedResponse = AceSerialize:Serialize(responsePayload)
    if serializedResponse then
        AceComm:SendCommMessage(INSPECTION_RESPONSE_PREFIX, serializedResponse, "WHISPER", sender)
    end
    
    -- Send achievement data
    CharacterInspection.SendAchievementData(sender)
end

-- Handle incoming inspection responses
function CharacterInspection.OnInspectionResponse(prefix, message, distribution, sender)
    if prefix ~= INSPECTION_RESPONSE_PREFIX then return end
    
    local success, payload = AceSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "achievement_response" then return end
    if payload.requester and payload.requester ~= UnitName("player") then return end
    if sender ~= currentInspectionTarget then return end
    
    local wasPending = (handshakeTarget == sender)
    if wasPending then
        CancelInspectionHandshakeTimer()
    end
    
    if not payload.hasAddon then
        -- Target doesn't have the addon
        ClearInspectionAchievementRows("Target player does not have the HardcoreAchievements addon installed.", {1, 0.5, 0.5})
        return
    end

    if wasPending then
        ClearInspectionAchievementRows("Receiving achievement data from " .. sender .. "...", {0.6, 0.9, 0.6})
    end
    -- If they have the addon, we'll receive the data via OnInspectionData
end

-- Handle incoming achievement data
function CharacterInspection.OnInspectionData(prefix, message, distribution, sender)
    if prefix ~= INSPECTION_DATA_PREFIX then return end
    
    local success, payload = AceSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "achievement_data" then return end
    
    if sender == currentInspectionTarget then
        CancelInspectionHandshakeTimer()
    end
    
    -- Cache the data
    local cacheKey = sender
    inspectionCache[cacheKey] = {
        data = payload.data,
        timestamp = time()
    }
    
    -- Display the data
    CharacterInspection.DisplayAchievementData(payload.data)
end

-- Send achievement data to requester
function CharacterInspection.SendAchievementData(targetName)
    if not targetName then return end
    
    -- Get our achievement data
    local _, charDB = HardcoreAchievements_GetCharDB()
    if not charDB or not charDB.achievements then
        return
    end
    
    -- Prepare data for transmission
    local completedAchievements = {}
    local totalCount = 0
    local completedCount = 0
    local totalPoints = 0
    
    local achievements = charDB.achievements or {}
    for achId, achievement in pairs(achievements) do
        totalCount = totalCount + 1
        if achievement.completed then
            completedCount = completedCount + 1
            local key = NormalizeAchievementId(achId)
            local definition = GetAchievementDefinition(achId)
            local points = achievement.points or (definition and definition.points) or 0
            totalPoints = totalPoints + (tonumber(points) or 0)
            
            completedAchievements[key] = {
                completed = true,
                completedAt = achievement.completedAt,
                points = points,
                level = achievement.level,
                wasSolo = achievement.wasSolo,
                sfMod = achievement.SFMod,
                notes = achievement.notes,
            }
        end
    end
    
    local achievementData = {
        meta = charDB.meta or {},
        completed = completedAchievements,
        totalPoints = totalPoints,
        completedCount = completedCount,
        totalCount = totalCount,
        version = 2,
    }
    
    -- Send the data
    local dataPayload = {
        type = "achievement_data",
        timestamp = time(),
        data = achievementData
    }
    
    local serializedData = AceSerialize:Serialize(dataPayload)
    if serializedData then
        AceComm:SendCommMessage(INSPECTION_DATA_PREFIX, serializedData, "WHISPER", targetName)
    end
end

-- Display achievement data in the inspection panel
function CharacterInspection.DisplayAchievementData(data)
    if not inspectionAchievementPanel or not data then return end
    
    inspectionAchievementPanel.achievements = inspectionAchievementPanel.achievements or {}
    
    -- Clear existing achievements
    ClearInspectionAchievementRows()
    
    -- Normalize incoming payload
    local completedMap = {}
    if type(data.completed) == "table" then
        completedMap = data.completed
    end
    
    -- Compute total points (fall back to provided totalPoints if available)
    local totalPoints = tonumber(data.totalPoints) or 0
    if totalPoints == 0 then
        for _, achievementData in pairs(completedMap) do
            totalPoints = totalPoints + (tonumber(achievementData.points) or 0)
        end
    end
    if inspectionAchievementPanel.TotalPoints then
        inspectionAchievementPanel.TotalPoints:SetText(string_format("%d pts", totalPoints))
    end
    
    local createdRows = 0
    for achId, achievementData in pairs(completedMap) do
        local definition = GetAchievementDefinition(achId)
        local title = (definition and definition.title) or tostring(achId)
        local tooltip = (definition and definition.tooltip) or ""
        local icon = (definition and definition.icon) or 136116
        local definitionLevel = nil
        if definition then
            if definition.level then
                definitionLevel = tonumber(definition.level)
            end
            if not definitionLevel and definition.maxLevel then
                definitionLevel = tonumber(definition.maxLevel)
            end
        end
        local points = achievementData.points or (definition and definition.points) or 0
        
        local inspectionRow = CharacterInspection.CreateInspectionAchievementRow(
            inspectionAchievementPanel.Content,
            achId,
            title,
            tooltip,
            icon,
            definitionLevel,
            points,
            achievementData,
            definition
        )
        
        createdRows = createdRows + 1
        table_insert(inspectionAchievementPanel.achievements, inspectionRow)
    end

    local completedCount = tonumber(data.completedCount) or createdRows
    local totalCount = tonumber(data.totalCount) or math.max(completedCount, createdRows)
    if inspectionAchievementPanel.CountsText then
        inspectionAchievementPanel.CountsText:SetText(string_format("(%d/%d)", completedCount or 0, totalCount or 0))
    end
    
    if createdRows == 0 then
        if inspectionAchievementPanel.StatusText then
            inspectionAchievementPanel.StatusText:SetText("No completed achievements to display yet.")
            inspectionAchievementPanel.StatusText:SetTextColor(0.9, 0.9, 0.9)
            inspectionAchievementPanel.StatusText:Show()
        end
        inspectionAchievementPanel.Content:SetHeight(inspectionAchievementPanel.Scroll:GetHeight() or 0)
        inspectionAchievementPanel.Scroll:UpdateScrollChildRect()
        return
    end
    
    if inspectionAchievementPanel.StatusText then
        inspectionAchievementPanel.StatusText:SetText("")
    end
    
    -- Sort and position rows
    CharacterInspection.SortInspectionAchievementRows()
end

-- Create an achievement row for inspection display
function CharacterInspection.CreateInspectionAchievementRow(parent, achId, title, tooltip, icon, level, points, achievementData, definition)
    local index = (#inspectionAchievementPanel.achievements) + 1
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(310, 42)
    row:SetClipsChildren(false)
    
    -- Position
    if index == 1 then
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, 0)
    else
        row:SetPoint("TOPLEFT", inspectionAchievementPanel.achievements[index-1], "BOTTOMLEFT", 0, -2)
    end
    
    -- Icon and frames
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(30, 30)
    row.Icon:SetPoint("LEFT", row, "LEFT", 1, 0)
    row.Icon:SetTexture(icon or 136116)
    
    row.IconOverlay = row:CreateTexture(nil, "OVERLAY")
    row.IconOverlay:SetSize(20, 20)
    row.IconOverlay:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconOverlay:Hide()
    
    row.IconFrameGold = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrameGold:SetSize(33, 33)
    row.IconFrameGold:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrameGold:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_gold.png")
    row.IconFrameGold:SetDrawLayer("OVERLAY", 1)
    row.IconFrameGold:Hide()
    
    row.IconFrame = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrame:SetSize(33, 33)
    row.IconFrame:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrame:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_silver.png")
    row.IconFrame:SetDrawLayer("OVERLAY", 1)
    row.IconFrame:Show()
    
    -- Title + shadow
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetText(title or ("Achievement %d"):format(index))
    
    row.TitleShadow = row:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    row.TitleShadow:SetText(InspectStripColorCodes(row.Title:GetText() or ""))
    row.TitleShadow:SetTextColor(0, 0, 0, 0.5)
    row.TitleShadow:SetDrawLayer("BACKGROUND", 0)
    
    -- Subtitle / progress
    row.Sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Sub:SetWidth(265)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetJustifyV("TOP")
    row.Sub:SetWordWrap(true)
    row.Sub:SetTextColor(0.5, 0.5, 0.5)
    local capNum = tonumber(level)
    local completionLevel = tonumber(achievementData and achievementData.level)
    local subLines = {}
    if capNum and capNum > 0 then
        table_insert(subLines, ((LEVEL or "Level") .. " " .. capNum))
    end
    if completionLevel and completionLevel > 0 then
        local completionText
        if type(ACHIEVEMENT_COMPLETED_AT_LEVEL) == "string" then
            completionText = string_format(ACHIEVEMENT_COMPLETED_AT_LEVEL, completionLevel)
        else
            completionText = string_format("Completed at level %d", completionLevel)
        end
        table_insert(subLines, completionText)
    end
    row.Sub:SetText(table_concat(subLines, "\n"))
    row._defaultSubText = row.Sub:GetText() or ""
    HookInspectionRowSubTextUpdates(row)
    row.UpdateTextLayout = UpdateInspectionRowTextLayout
    
    -- Points frame
    row.PointsFrame = CreateFrame("Frame", nil, row)
    row.PointsFrame:SetSize(42, 42)
    row.PointsFrame:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    
    row.PointsFrame.Texture = row.PointsFrame:CreateTexture(nil, "BACKGROUND")
    row.PointsFrame.Texture:SetAllPoints(row.PointsFrame)
    row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.png")
    
    row.Points = row.PointsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Points:SetPoint("CENTER", row.PointsFrame, "CENTER", 0, 0)
    row.Points:SetText(tostring(points or 0))
    row.Points:SetTextColor(1, 1, 1)
    
    row.PointsFrame.Checkmark = row.PointsFrame:CreateTexture(nil, "OVERLAY")
    row.PointsFrame.Checkmark:SetSize(10, 10)
    row.PointsFrame.Checkmark:SetPoint("CENTER", row.PointsFrame, "CENTER", 0, 0)
    row.PointsFrame.Checkmark:Hide()
    
    -- Timestamp
    row.TS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.TS:SetPoint("RIGHT", row.PointsFrame, "LEFT", -5, 0)
    row.TS:SetJustifyH("RIGHT")
    row.TS:SetJustifyV("TOP")
    row.TS:SetText("")
    row.TS:SetTextColor(1, 1, 1)
    
    -- Background + border (clipped)
    if inspectionAchievementPanel.BorderClip then
        row.Background = inspectionAchievementPanel.BorderClip:CreateTexture(nil, "BACKGROUND")
        row.Background:SetDrawLayer("BACKGROUND", 0)
        row.Background:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.png")
        row.Background:SetVertexColor(1, 1, 1)
        row.Background:SetAlpha(1)
        row.Background:Hide()
        
        row.Border = inspectionAchievementPanel.BorderClip:CreateTexture(nil, "BACKGROUND")
        row.Border:SetDrawLayer("BACKGROUND", 1)
        row.Border:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row-border.png")
        row.Border:SetSize(256, 32)
        row.Border:SetAlpha(0.5)
        row.Border:Hide()
    end
    
    -- Highlight/tooltip handling
    row:EnableMouse(true)
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(1, 1, 1, 0.10)
    row.highlight:Hide()
    
    row:SetScript("OnEnter", function(self)
        self.highlight:SetColorTexture(1, 1, 1, 0.10)
        self.highlight:Show()
        
        if _G.HCA_ShowAchievementTooltip then
            _G.HCA_ShowAchievementTooltip(row, self)
        else
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row._title or row.Title:GetText() or "", 1, 1, 1)
            if row._tooltip and row._tooltip ~= "" then
                GameTooltip:AddLine(row._tooltip, nil, nil, nil, true)
            end
            GameTooltip:Show()
        end
    end)
    
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and row.achId then
            -- Use centralized function to generate bracket format (icon looked up client-side)
            local bracket = _G.HCA_GetAchievementBracket and _G.HCA_GetAchievementBracket(row.achId) or string_format("[HCA:(%s)]", tostring(row.achId))
            
            local editBox = ChatEdit_GetActiveWindow()
            if not editBox or not editBox:IsVisible() then
                return
            end
            local currentText = editBox:GetText() or ""
            if currentText == "" then
                editBox:SetText(bracket)
            else
                editBox:SetText(currentText .. " " .. bracket)
            end
            editBox:SetFocus()
        end
    end)
    
    -- Metadata + state
    row.achId = achId
    row.id = achId
    row.tooltip = tooltip
    row._achId = achId
    row._title = title
    row._tooltip = tooltip
    row._def = definition
    if definition and definition.zone then
        row.zone = definition.zone
    elseif definition and definition.mapName then
        row.zone = definition.mapName
    end
    
    row.points = tonumber(points) or 0
    row.originalPoints = row.points
    row.staticPoints = true
    row.completed = false
    row.maxLevel = (capNum and capNum > 0) and capNum or nil
    row.sfMod = achievementData and achievementData.sfMod
    row.wasSolo = achievementData and achievementData.wasSolo
    row.notes = achievementData and achievementData.notes
    
    if achievementData then
        if achievementData.points then
            row.points = tonumber(achievementData.points) or row.points
            row.Points:SetText(tostring(row.points))
        end
        if achievementData.completed then
            row.completed = true
        end
        if achievementData.completedAt and row.TS then
            row.TS:SetText(FormatInspectionTimestamp(achievementData.completedAt))
        end
        if achievementData.wasSolo then
            local base = row._defaultSubText or ""
            local soloText = "|cff008066Solo|r"
            if base ~= "" then
                row.Sub:SetText(base .. "\n" .. soloText)
            else
                row.Sub:SetText(soloText)
            end
            row._defaultSubText = row.Sub:GetText() or row._defaultSubText
        end
        if achievementData.notes and achievementData.notes ~= "" then
            row._tooltip = (tooltip and tooltip ~= "" and (tooltip .. "\n\n" .. achievementData.notes)) or achievementData.notes
            row.tooltip = row._tooltip
        end
    end
    
    UpdateInspectionRowTextLayout(row)
    UpdateInspectionPointsDisplay(row)
    PositionInspectionRowBorder(row)
    
    return row
end

-- Sort inspection achievement rows
function CharacterInspection.SortInspectionAchievementRows()
    if not inspectionAchievementPanel or not inspectionAchievementPanel.achievements then return end
    
    -- Sort by level cap (same as main panel)
    table_sort(inspectionAchievementPanel.achievements, function(a, b)
        local la, lb = (a.maxLevel or 0), (b.maxLevel or 0)
        if la ~= lb then return la < lb end
        
        local aIsLvl = type(a.achId) == "string" and a.achId:match("^Level%d+$") ~= nil
        local bIsLvl = type(b.achId) == "string" and b.achId:match("^Level%d+$") ~= nil
        if aIsLvl ~= bIsLvl then
            return not aIsLvl -- non-level achievements first on ties
        end
        
        local at = (a.Title and a.Title.GetText and a.Title:GetText()) or (a.achId or "")
        local bt = (b.Title and b.Title.GetText and b.Title:GetText()) or (b.achId or "")
        return tostring(at) < tostring(bt)
    end)
    
    -- Reposition rows
    local prev = nil
    local totalHeight = 0
    for _, row in ipairs(inspectionAchievementPanel.achievements) do
        row:ClearAllPoints()
        if row:IsShown() then
            if prev and prev ~= row then
                row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
            else
                row:SetPoint("TOPLEFT", inspectionAchievementPanel.Content, "TOPLEFT", 4, 0)
            end
            prev = row
            UpdateInspectionPointsDisplay(row)
            PositionInspectionRowBorder(row)
            totalHeight = totalHeight + (row:GetHeight() + 2)
        else
            if row.Border then row.Border:Hide() end
            if row.Background then row.Background:Hide() end
        end
    end
    
    inspectionAchievementPanel.Content:SetHeight(math.max(totalHeight + 16, inspectionAchievementPanel.Scroll:GetHeight() or 0))
    inspectionAchievementPanel.Scroll:UpdateScrollChildRect()
end

-- Hook into inspection events
local function HookInspectionEvents()
    -- Hook InspectUnit to detect when we start inspecting someone
    hooksecurefunc("InspectUnit", function(unit)
        if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local targetName = UnitName(unit)
            if targetName then
                -- Clear previous data
                ClearInspectionAchievementRows()
                currentInspectionTarget = targetName
            end
        end
    end)
end

-- -- Hook into unit popup menu to add "Inspect Achievements" option
-- local function HookUnitPopupMenu()
--     -- Try modern Menu API first (if available, likely Retail)
--     if Menu and type(Menu.ModifyMenu) == "function" and MENU_UNIT_TARGET then
--         Menu.ModifyMenu("MENU_UNIT_TARGET", function(ownerRegion, rootDescription, contextData)
--             -- Only show for friendly players (not self)
--             local unit = contextData and contextData.unit
--             if unit and UnitIsPlayer(unit) and UnitIsFriend("player", unit) and not UnitIsUnit(unit, "player") then
--                 rootDescription:CreateDivider()
--                 rootDescription:CreateButton("Inspect Achievements", function()
--                     local targetName = UnitName(unit)
--                     if targetName then
--                         -- Open inspection frame and switch to achievements tab
--                         if InspectUnit then
--                             InspectUnit(unit)
--                         end
--                         -- Wait a frame for InspectFrame to initialize, then show achievement tab
--                         if C_Timer and C_Timer.After then
--                             C_Timer.After(0.1, function()
--                                 if InspectFrame and InspectFrame:IsShown() then
--                                     CharacterInspection.ShowInspectionAchievementTab()
--                                 end
--                             end)
--                         end
--                     end
--                 end)
--             end
--         end)
--         return
--     end
-- end

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeInspectionSystem()
        HookInspectionEvents()
        --HookUnitPopupMenu()
        self:UnregisterAllEvents()
    end
end)

-- Export functions
_G.CharacterInspection = CharacterInspection
