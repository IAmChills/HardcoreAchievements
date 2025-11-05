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

-- Cache for inspection data to avoid repeated requests
local inspectionCache = {}
local CACHE_DURATION = 300 -- 5 minutes

-- Current inspection target
local currentInspectionTarget = nil
local inspectionFrame = nil
local inspectionAchievementPanel = nil

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
    if not InspectFrame then return end
    
    -- Create achievement tab
    local tabID = InspectFrame.numTabs + 1
    local achievementTab = CreateFrame("Button", "InspectFrameTab" .. tabID, InspectFrame, "CharacterFrameTabButtonTemplate")
    achievementTab:SetPoint("RIGHT", _G["InspectFrameTab" .. (tabID - 1)], "RIGHT", 43, 0)
    achievementTab:SetText(ACHIEVEMENTS)
    PanelTemplates_DeselectTab(achievementTab)
    
    -- Create achievement panel for inspection
    inspectionAchievementPanel = CreateFrame("Frame", "InspectAchievementPanel", InspectFrame)
    inspectionAchievementPanel:Hide()
    inspectionAchievementPanel:EnableMouse(true)
    inspectionAchievementPanel:SetAllPoints(InspectFrame)
    
    -- Setup the achievement panel UI (similar to main achievement panel)
    CharacterInspection.SetupInspectionAchievementPanel()
    
    -- Tab click handler
    achievementTab:SetScript("OnClick", function()
        CharacterInspection.ShowInspectionAchievementTab()
    end)
    
    -- Hook into inspection frame tab switching
    hooksecurefunc("InspectFrame_ShowSubFrame", function(frameName)
        if inspectionAchievementPanel and inspectionAchievementPanel:IsShown() and frameName ~= "InspectAchievementPanel" then
            inspectionAchievementPanel:Hide()
            PanelTemplates_DeselectTab(achievementTab)
        end
    end)
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
    inspectionAchievementPanel.TotalPoints:SetPoint("TOPRIGHT", inspectionAchievementPanel, "TOPRIGHT", -50, -30)
    inspectionAchievementPanel.TotalPoints:SetText("0 pts")
    inspectionAchievementPanel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)
    
    -- Status text (loading, error, etc.)
    inspectionAchievementPanel.StatusText = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inspectionAchievementPanel.StatusText:SetPoint("CENTER", inspectionAchievementPanel, "CENTER", 0, 0)
    inspectionAchievementPanel.StatusText:SetText("Requesting achievement data...")
    inspectionAchievementPanel.StatusText:SetTextColor(1, 1, 0)
    
    -- Scrollable container
    inspectionAchievementPanel.Scroll = CreateFrame("ScrollFrame", "$parentScroll", inspectionAchievementPanel, "UIPanelScrollFrameTemplate")
    inspectionAchievementPanel.Scroll:SetPoint("TOPLEFT", 30, -60)
    inspectionAchievementPanel.Scroll:SetPoint("BOTTOMRIGHT", -65, 70)
    
    -- Content frame
    inspectionAchievementPanel.Content = CreateFrame("Frame", nil, inspectionAchievementPanel.Scroll)
    inspectionAchievementPanel.Content:SetPoint("TOPLEFT")
    inspectionAchievementPanel.Content:SetSize(1, 1)
    inspectionAchievementPanel.Scroll:SetScrollChild(inspectionAchievementPanel.Content)
    
    inspectionAchievementPanel.Content:SetWidth(inspectionAchievementPanel.Scroll:GetWidth())
    inspectionAchievementPanel.Scroll:SetScript("OnSizeChanged", function(self)
        inspectionAchievementPanel.Content:SetWidth(self:GetWidth())
        self:UpdateScrollChildRect()
    end)
    
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
    TL:SetPoint("TOPLEFT", 2, -1)
    TL:SetSize(256, 256)
    
    local TR = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    TR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
    TR:SetPoint("TOPLEFT", TL, "TOPRIGHT", 0, 0)
    TR:SetPoint("RIGHT", inspectionAchievementPanel, "RIGHT", 2, -1)
    TR:SetHeight(256)
    
    local BL = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    BL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
    BL:SetPoint("TOPLEFT", TL, "BOTTOMLEFT", 0, 0)
    BL:SetPoint("BOTTOMLEFT", inspectionAchievementPanel, "BOTTOMLEFT", 2, -1)
    BL:SetWidth(256)
    
    local BR = inspectionAchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    BR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
    BR:SetPoint("TOPLEFT", BL, "TOPRIGHT", 0, 0)
    BR:SetPoint("LEFT", TR, "LEFT", 0, 0)
    BR:SetPoint("BOTTOMRIGHT", inspectionAchievementPanel, "BOTTOMRIGHT", 2, -1)
    
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
    local tabID = InspectFrame.numTabs + 1
    local achievementTab = _G["InspectFrameTab" .. tabID]
    if achievementTab then
        PanelTemplates_SelectTab(achievementTab)
    end
    
    -- Hide other subframes
    if InspectPaperDollFrame then InspectPaperDollFrame:Hide() end
    if InspectHonorFrame then InspectHonorFrame:Hide() end
    if InspectTalentFrame then InspectTalentFrame:Hide() end
    
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
        CharacterInspection.DisplayAchievementData(cachedData.data)
        return
    end
    
    -- Show loading state
    if inspectionAchievementPanel and inspectionAchievementPanel.StatusText then
        inspectionAchievementPanel.StatusText:SetText("Requesting achievement data from " .. targetName .. "...")
        inspectionAchievementPanel.StatusText:SetTextColor(1, 1, 0)
    end
    
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
    
    if not payload.hasAddon then
        -- Target doesn't have the addon
        if inspectionAchievementPanel and inspectionAchievementPanel.StatusText then
            inspectionAchievementPanel.StatusText:SetText("Target player does not have HardcoreAchievements addon")
            inspectionAchievementPanel.StatusText:SetTextColor(1, 0.5, 0.5)
        end
    end
    -- If they have the addon, we'll receive the data via OnInspectionData
end

-- Handle incoming achievement data
function CharacterInspection.OnInspectionData(prefix, message, distribution, sender)
    if prefix ~= INSPECTION_DATA_PREFIX then return end
    
    local success, payload = AceSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "achievement_data" then return end
    
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
    local achievementData = {
        meta = charDB.meta or {},
        achievements = charDB.achievements or {},
        totalPoints = HCA_GetTotalPoints and HCA_GetTotalPoints() or 0,
        completedCount = 0,
        totalCount = 0
    }
    
    -- Count achievements
    for _, achievement in pairs(charDB.achievements) do
        achievementData.totalCount = achievementData.totalCount + 1
        if achievement.completed then
            achievementData.completedCount = achievementData.completedCount + 1
        end
    end
    
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
    
    -- Clear existing achievements
    if inspectionAchievementPanel.achievements then
        for _, row in ipairs(inspectionAchievementPanel.achievements) do
            if row and row:IsObjectType("Frame") then
                row:Hide()
                row:SetParent(nil)
            end
        end
        inspectionAchievementPanel.achievements = {}
    end
    
    -- Update status
    if inspectionAchievementPanel.StatusText then
        inspectionAchievementPanel.StatusText:SetText("")
    end
    
    -- Update total points
    if inspectionAchievementPanel.TotalPoints then
        inspectionAchievementPanel.TotalPoints:SetText(tostring(data.totalPoints or 0) .. " pts")
    end
    
    -- Create achievement rows based on our local achievement definitions
    if AchievementPanel and AchievementPanel.achievements then
        for _, localRow in ipairs(AchievementPanel.achievements) do
            local achId = localRow.id
            local achievementData = data.achievements[achId]
            
            -- Create inspection row
            local inspectionRow = CharacterInspection.CreateInspectionAchievementRow(
                inspectionAchievementPanel.Content,
                achId,
                localRow.Title and localRow.Title:GetText() or "Unknown Achievement",
                localRow.tooltip or "",
                localRow.Icon and localRow.Icon:GetTexture() or 136116,
                localRow.maxLevel or 0,
                localRow.originalPoints or 0,
                achievementData
            )
            
            table.insert(inspectionAchievementPanel.achievements, inspectionRow)
        end
    end
    
    -- Sort and position rows
    CharacterInspection.SortInspectionAchievementRows()
end

-- Create an achievement row for inspection display
function CharacterInspection.CreateInspectionAchievementRow(parent, achId, title, tooltip, icon, level, points, achievementData)
    local index = (#inspectionAchievementPanel.achievements) + 1
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(300, 36)
    
    -- Position
    if index == 1 then
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", inspectionAchievementPanel.achievements[index-1], "BOTTOMLEFT", 0, 0)
    end
    
    -- Icon
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(32, 32)
    row.Icon:SetPoint("LEFT", row, "LEFT", -1, 0)
    row.Icon:SetTexture(icon or 136116)
    
    -- Title
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 8, 10)
    row.Title:SetText(title or ("Achievement %d"):format(index))
    
    -- Subtitle / progress
    row.Sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
    row.Sub:SetWidth(265)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetJustifyV("TOP")
    row.Sub:SetWordWrap(true)
    row.Sub:SetText(level and string.format(LEVEL, level) or "—")
    
    -- Points
    row.Points = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Points:SetPoint("RIGHT", row, "RIGHT", -15, 10)
    row.Points:SetWidth(100)
    row.Points:SetJustifyH("RIGHT")
    row.Points:SetJustifyV("TOP")
    row.Points:SetText(tostring(points or 0) .. " pts")
    row.Points:SetTextColor(1, 1, 1)
    
    -- Timestamp
    row.TS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.TS:SetPoint("RIGHT", row.Points, "RIGHT", 0, -15)
    row.TS:SetJustifyH("RIGHT")
    row.TS:SetJustifyV("TOP")
    row.TS:SetText("")
    row.TS:SetTextColor(0.5, 0.5, 0.5)
    
    -- Highlight/tooltip
    row:EnableMouse(true)
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(1, 1, 1, 0.10)
    row.highlight:Hide()
    
    row:SetScript("OnEnter", function(self)
        self.highlight:SetColorTexture(1, 1, 1, 0.10)
        self.highlight:Show()
        
        if self.Title and self.Title.GetText then
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(title or "", 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)
    
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    
    -- Set completion state based on received data
    if achievementData and achievementData.completed then
        row.completed = true
        if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end
        -- Check if achievement was completed solo and show indicator
        if row.Sub then
            if achievementData.wasSolo then
                row.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n|cFFac81d6Solo|r")
            else
                row.Sub:SetText(AUCTION_TIME_LEFT0)
            end
        end
        if row.Points then row.Points:SetTextColor(0.6, 0.9, 0.6) end
        if row.TS then 
            local timestamp = achievementData.completedAt
            if timestamp then
                local dateInfo = date("*t", timestamp)
                local monthNames = {FULLDATE_MONTH_JANUARY, FULLDATE_MONTH_FEBRUARY, FULLDATE_MONTH_MARCH,
                                    FULLDATE_MONTH_APRIL, FULLDATE_MONTH_MAY, FULLDATE_MONTH_JUNE, 
                                    FULLDATE_MONTH_JULY, FULLDATE_MONTH_AUGUST, FULLDATE_MONTH_SEPTEMBER,
                                    FULLDATE_MONTH_OCTOBER, FULLDATE_MONTH_NOVEMBER, FULLDATE_MONTH_DECEMBER}

                row.TS:SetText(string.format("%s %d, %d %02d:%02d", 
                    monthNames[dateInfo.month], 
                    dateInfo.day, 
                    dateInfo.year, 
                    dateInfo.hour, 
                    dateInfo.min))
            end
        end
        if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(false) end
        
        -- Update points if different
        if achievementData.points then
            row.Points:SetText(tostring(achievementData.points) .. " pts")
        end
    else
        row.completed = false
        -- Check if outleveled
        local playerLevel = UnitLevel("player")
        if level and playerLevel > level then
            if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.9, 0.2, 0.2) end
            if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(true) end
        end
    end
    
    row.achId = achId
    row.tooltip = tooltip
    
    return row
end

-- Sort inspection achievement rows
function CharacterInspection.SortInspectionAchievementRows()
    if not inspectionAchievementPanel or not inspectionAchievementPanel.achievements then return end
    
    -- Sort by level cap (same as main panel)
    table.sort(inspectionAchievementPanel.achievements, function(a, b)
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
                row:SetPoint("TOPLEFT", inspectionAchievementPanel.Content, "TOPLEFT", 0, 0)
            end
            prev = row
            totalHeight = totalHeight + (row:GetHeight() + 2)
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
                if inspectionAchievementPanel and inspectionAchievementPanel.StatusText then
                    inspectionAchievementPanel.StatusText:SetText("")
                end
                currentInspectionTarget = targetName
            end
        end
    end)
end

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeInspectionSystem()
        HookInspectionEvents()
        self:UnregisterAllEvents()
    end
end)

-- Export functions
_G.CharacterInspection = CharacterInspection
