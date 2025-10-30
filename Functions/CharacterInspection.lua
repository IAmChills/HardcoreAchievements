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
    
    -- Debug: Print frame dimensions
    local charWidth, charHeight = CharacterFrame:GetSize()
    local inspectWidth, inspectHeight = InspectFrame:GetSize()
    print("DEBUG: CharacterFrame size:", charWidth, "x", charHeight)
    print("DEBUG: InspectFrame size:", inspectWidth, "x", inspectHeight)
    print("DEBUG: Size ratio:", inspectWidth/charWidth, "x", inspectHeight/charHeight)
    
    -- Create achievement tab
    local tabID = InspectFrame.numTabs + 1
    local achievementTab = CreateFrame("Button", "InspectFrameTab" .. tabID, InspectFrame, "CharacterFrameTabButtonTemplate")
    achievementTab:SetPoint("RIGHT", _G["InspectFrameTab" .. (tabID - 1)], "RIGHT", 100, 0)
    achievementTab:SetText("Achievements")
    PanelTemplates_DeselectTab(achievementTab)
    
    -- Create achievement panel for inspection (matching main panel exactly)
    inspectionAchievementPanel = CreateFrame("Frame", "InspectAchievementPanel", InspectFrame)
    inspectionAchievementPanel:Hide()
    inspectionAchievementPanel:EnableMouse(true)
    
    -- Option 1: Match the inspection frame exactly (current)
    --inspectionAchievementPanel:SetAllPoints(InspectFrame)
    
    -- Option 2: Match the character frame size (uncomment to use)
     inspectionAchievementPanel:SetSize(384, 512)
     inspectionAchievementPanel:SetPoint("CENTER", InspectFrame, "CENTER", 8, -30)
    
    -- Option 3: Custom size (uncomment and adjust as needed)
    -- inspectionAchievementPanel:SetSize(400, 500)
    -- inspectionAchievementPanel:SetPoint("CENTER", InspectFrame, "CENTER", 0, 0)
    
    -- Setup the achievement panel UI (similar to main achievement panel)
    CharacterInspection.SetupInspectionAchievementPanel()
    
    -- Tab click handler
    achievementTab:SetScript("OnClick", function()
        CharacterInspection.ShowInspectionAchievementTab()
    end)
    
    -- Hook into inspection frame tab switching (Classic WoW)
    local function OnInspectTabClick(tab)
        if tab ~= achievementTab and inspectionAchievementPanel and inspectionAchievementPanel:IsShown() then
            inspectionAchievementPanel:Hide()
            PanelTemplates_DeselectTab(achievementTab)
        end
    end
    
    -- Hook all existing tabs
    for i = 1, InspectFrame.numTabs do
        local tab = _G["InspectFrameTab" .. i]
        if tab then
            local originalOnClick = tab:GetScript("OnClick")
            tab:SetScript("OnClick", function(self)
                if originalOnClick then
                    originalOnClick(self)
                end
                OnInspectTabClick(self)
            end)
        end
    end
end

-- Setup the inspection achievement panel UI
function CharacterInspection.SetupInspectionAchievementPanel()
    if not inspectionAchievementPanel then return end
    
    -- Filter dropdown (matching main panel exactly)
    local filterDropdown = CreateFrame("Frame", nil, inspectionAchievementPanel, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("TOP", inspectionAchievementPanel, "TOP", 0, -48)
    UIDropDownMenu_SetWidth(filterDropdown, 110)
    UIDropDownMenu_SetText(filterDropdown, "All")
    
    -- Total points display
    inspectionAchievementPanel.TotalPoints = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    inspectionAchievementPanel.TotalPoints:SetPoint("TOPRIGHT", inspectionAchievementPanel, "TOPRIGHT", -50, -50)
    inspectionAchievementPanel.TotalPoints:SetText("0 pts")
    inspectionAchievementPanel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)
    
    -- Status text (loading, error, etc.)
    inspectionAchievementPanel.StatusText = inspectionAchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inspectionAchievementPanel.StatusText:SetPoint("CENTER", inspectionAchievementPanel, "CENTER", -10, 0)
    inspectionAchievementPanel.StatusText:SetText("Requesting achievement data...")
    inspectionAchievementPanel.StatusText:SetTextColor(1, 1, 0)
    
    -- Scrollable container (matching main panel exactly)
    inspectionAchievementPanel.Scroll = CreateFrame("ScrollFrame", "$parentScroll", inspectionAchievementPanel, "UIPanelScrollFrameTemplate")
    inspectionAchievementPanel.Scroll:SetPoint("TOPLEFT", 30, -80)      -- adjust to taste
    inspectionAchievementPanel.Scroll:SetPoint("BOTTOMRIGHT", -65, 90)  -- leaves room for the scrollbar
    
    -- Content frame (matching main panel exactly)
    inspectionAchievementPanel.Content = CreateFrame("Frame", nil, inspectionAchievementPanel.Scroll)
    inspectionAchievementPanel.Content:SetPoint("TOPLEFT")
    inspectionAchievementPanel.Content:SetSize(1, 1)  -- will grow as rows are added
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
    
    -- Create achievement rows using the same function as main UI
    if AchievementPanel and AchievementPanel.achievements then
        for _, localRow in ipairs(AchievementPanel.achievements) do
            local achId = localRow.id
            local achievementData = data.achievements[achId]
            
            -- Use the main CreateAchievementRow function for consistent styling
            -- Temporarily replace AchievementPanel.Content with inspection panel's content
            local originalContent = AchievementPanel.Content
            AchievementPanel.Content = inspectionAchievementPanel.Content
            local inspectionRow = CreateAchievementRow(
                inspectionAchievementPanel.Content,
                achId,
                localRow.Title and localRow.Title:GetText() or "Unknown Achievement",
                localRow.tooltip or "",
                localRow.Icon and localRow.Icon:GetTexture() or 136116,
                localRow.maxLevel or 0,
                localRow.originalPoints or 0,
                nil, -- killTracker
                nil, -- questTracker
                localRow.staticPoints or false,
                localRow.zone or ""
            )
            AchievementPanel.Content = originalContent
            
            -- Apply inspection-specific data
            if achievementData and achievementData.completed then
                inspectionRow.completed = true
                if inspectionRow.Title and inspectionRow.Title.SetTextColor then 
                    inspectionRow.Title:SetTextColor(0.6, 0.9, 0.6) 
                end
                if inspectionRow.Sub then 
                    inspectionRow.Sub:SetText("Completed!") 
                end
                if inspectionRow.Points then 
                    inspectionRow.Points:SetTextColor(0.6, 0.9, 0.6) 
                end
                if inspectionRow.TS then 
                    local timestamp = achievementData.completedAt
                    if timestamp then
                        local dateInfo = date("*t", timestamp)
                        local monthNames = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                                           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
                        inspectionRow.TS:SetText(string.format("%s %d, %d %02d:%02d", 
                            monthNames[dateInfo.month], 
                            dateInfo.day, 
                            dateInfo.year, 
                            dateInfo.hour, 
                            dateInfo.min))
                    end
                end
                if inspectionRow.Icon and inspectionRow.Icon.SetDesaturated then 
                    inspectionRow.Icon:SetDesaturated(false) 
                end
                
                -- Update icon borders for completion status
                if inspectionRow.GreenBorder then inspectionRow.GreenBorder:Show() end
                if inspectionRow.RedBorder then inspectionRow.RedBorder:Hide() end
                if inspectionRow.YellowBorder then inspectionRow.YellowBorder:Hide() end
                
                -- Update points if different
                if achievementData.points then
                    inspectionRow.Points:SetText(tostring(achievementData.points) .. " pts")
                end
            else
                inspectionRow.completed = false
                -- Check if outleveled
                local playerLevel = UnitLevel("player")
                if localRow.maxLevel and playerLevel > localRow.maxLevel then
                    if inspectionRow.Title and inspectionRow.Title.SetTextColor then 
                        inspectionRow.Title:SetTextColor(0.9, 0.2, 0.2) 
                    end
                    if inspectionRow.Icon and inspectionRow.Icon.SetDesaturated then 
                        inspectionRow.Icon:SetDesaturated(true) 
                    end
                    
                    -- Update icon borders for failed status
                    if inspectionRow.RedBorder then inspectionRow.RedBorder:Show() end
                    if inspectionRow.GreenBorder then inspectionRow.GreenBorder:Hide() end
                    if inspectionRow.YellowBorder then inspectionRow.YellowBorder:Hide() end
                else
                    -- Available (not completed, not outleveled)
                    if inspectionRow.YellowBorder then inspectionRow.YellowBorder:Show() end
                    if inspectionRow.GreenBorder then inspectionRow.GreenBorder:Hide() end
                    if inspectionRow.RedBorder then inspectionRow.RedBorder:Hide() end
                end
            end
            
            table.insert(inspectionAchievementPanel.achievements, inspectionRow)
        end
    end
    
    -- Sort and position rows using the main UI's sorting function
    -- Temporarily replace AchievementPanel.achievements with inspection panel's achievements
    local originalAchievements = AchievementPanel.achievements
    AchievementPanel.achievements = inspectionAchievementPanel.achievements
    SortAchievementRows()
    AchievementPanel.achievements = originalAchievements
end

-- Note: Using main CreateAchievementRow function for consistent styling

-- Note: Using main SortAchievementRows function for consistent sorting

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
