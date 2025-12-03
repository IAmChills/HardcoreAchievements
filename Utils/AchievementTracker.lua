---@class AchievementTracker
local AchievementTracker = {}
AchievementTracker.__index = AchievementTracker

-- Configuration - adjust these to match your addon's needs
local CONFIG = {
    headerFontSize = 14,
    achievementFontSize = 12,
    objectiveFontSize = 11,
    marginLeft = 14,
    marginRight = 30,
    minLineWidth = 260,
    linePoolSize = 50,
    paddingBetweenAchievements = 4,
}

-- Local variables
local trackerBaseFrame, trackerHeaderFrame, trackerContentFrame
local linePool = {}
local lineIndex = 0
local lastUpdate = 0
local isInitialized = false

-- Tracked achievements storage (you'll need to manage this in your addon)
-- Format: trackedAchievements[achievementId] = true
local trackedAchievements = {}

-- State
local isExpanded = true

-- Initialize the tracker
function AchievementTracker:Initialize()
    if isInitialized then
        return
    end

    -- Create base frame
    trackerBaseFrame = CreateFrame("Frame", "AchievementTracker_BaseFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    trackerBaseFrame:SetClampedToScreen(true)
    trackerBaseFrame:SetFrameStrata("MEDIUM")
    trackerBaseFrame:SetFrameLevel(0)
    trackerBaseFrame:SetSize(25, 25)
    trackerBaseFrame:EnableMouse(true)
    trackerBaseFrame:SetMovable(true)
    trackerBaseFrame:SetResizable(true)
    trackerBaseFrame:RegisterForDrag("LeftButton")

    -- Backdrop
    trackerBaseFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    trackerBaseFrame:SetBackdropColor(0, 0, 0, 0.8)
    trackerBaseFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Drag handlers
    trackerBaseFrame:SetScript("OnDragStart", function(self)
        if IsControlKeyDown() or not self.isLocked then
            self:StartMoving()
            self.isMoving = true
        end
    end)

    trackerBaseFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false
        -- Save position here if needed
    end)

    -- Initialize header
    trackerHeaderFrame = AchievementTracker:InitializeHeader(trackerBaseFrame)

    -- Initialize content frame
    trackerContentFrame = AchievementTracker:InitializeContentFrame(trackerBaseFrame, trackerHeaderFrame)

    -- Initialize line pool
    AchievementTracker:InitializeLinePool()

    -- Set initial position (adjust as needed)
    trackerBaseFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)

    trackerBaseFrame:Hide()
    isInitialized = true

    return trackerBaseFrame
end

-- Initialize header frame with expand/collapse
function AchievementTracker:InitializeHeader(baseFrame)
    local headerFrame = CreateFrame("Button", "AchievementTracker_HeaderFrame", baseFrame)
    headerFrame:SetSize(1, CONFIG.headerFontSize + 5)

    -- Header label
    local headerLabel = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerLabel:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 0, 0)
    headerLabel:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.headerFontSize, "OUTLINE")
    headerFrame.label = headerLabel

    -- Expand/collapse button
    headerFrame:EnableMouse(true)
    headerFrame:RegisterForClicks("LeftButtonUp")

    headerFrame:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            return
        end

        isExpanded = not isExpanded
        AchievementTracker:Update()
    end)

    headerFrame:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
    end)

    headerFrame:SetScript("OnLeave", function(self)
        self:SetAlpha(0.8)
    end)

    headerFrame:Hide()
    return headerFrame
end

-- Initialize content frame (scrollable area)
function AchievementTracker:InitializeContentFrame(baseFrame, headerFrame)
    local contentFrame = CreateFrame("Frame", "AchievementTracker_ContentFrame", baseFrame)
    contentFrame:SetWidth(25)
    contentFrame:SetHeight(25)

    -- Enable mouse for dragging
    contentFrame:EnableMouse(true)
    contentFrame:SetMovable(true)
    contentFrame:RegisterForDrag("LeftButton")
    contentFrame:SetScript("OnDragStart", trackerBaseFrame:GetScript("OnDragStart"))
    contentFrame:SetScript("OnDragStop", trackerBaseFrame:GetScript("OnDragStop"))

    -- Scroll frame
    contentFrame.ScrollFrame = CreateFrame("ScrollFrame", "AchievementTracker_ScrollFrame", contentFrame, "ScrollFrameTemplate")
    contentFrame.ScrollFrame:SetAllPoints(contentFrame)
    contentFrame.ScrollFrame.ScrollBar:Hide()

    -- Scroll child frame
    contentFrame.ScrollChildFrame = CreateFrame("Frame", "AchievementTracker_ScrollChildFrame")
    contentFrame.ScrollChildFrame:SetSize(contentFrame.ScrollFrame:GetWidth(), contentFrame.ScrollFrame:GetHeight())
    contentFrame.ScrollFrame:SetScrollChild(contentFrame.ScrollChildFrame)

    contentFrame:Hide()
    return contentFrame
end

-- Initialize line pool for displaying achievements
function AchievementTracker:InitializeLinePool()
    for i = 1, CONFIG.linePoolSize do
        local line = CreateFrame("Button", "AchievementTracker_Line" .. i, trackerContentFrame.ScrollChildFrame)
        line:SetWidth(1)
        line:SetHeight(1)

        -- Label for text
        line.label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        line.label:SetJustifyH("LEFT")
        line.label:SetJustifyV("TOP")
        line.label:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
        line.label:Hide()

        -- Position relative to previous line
        if i == 1 then
            line:SetPoint("TOPLEFT", trackerContentFrame.ScrollChildFrame, "TOPLEFT", CONFIG.marginLeft, 0)
        else
            line:SetPoint("TOPLEFT", linePool[i - 1], "BOTTOMLEFT", 0, 0)
        end

        line:Hide()
        linePool[i] = line
    end
end

-- Get next available line from pool
function AchievementTracker:GetNextLine()
    lineIndex = lineIndex + 1
    if lineIndex <= CONFIG.linePoolSize then
        return linePool[lineIndex]
    end
    return nil
end

-- Reset line pool
function AchievementTracker:ResetLinePool()
    for i = 1, CONFIG.linePoolSize do
        if linePool[i] then
            linePool[i]:Hide()
            linePool[i].label:Hide()
            linePool[i].achievementId = nil
        end
    end
    lineIndex = 0
end

-- Update the tracker display
function AchievementTracker:Update()
    if not isInitialized then
        return
    end

    -- Throttle updates
    local now = GetTime()
    if InCombatLockdown() or (now - lastUpdate) < 0.1 then
        return
    end
    lastUpdate = now

    -- Reset line pool
    AchievementTracker:ResetLinePool()

    -- Update header
    AchievementTracker:UpdateHeader()

    -- Update content
    if isExpanded then
        AchievementTracker:UpdateContent()
    else
        trackerContentFrame:Hide()
    end

    -- Update frame visibility and size
    AchievementTracker:UpdateFrame()
end

-- Update header display
function AchievementTracker:UpdateHeader()
    if not trackerHeaderFrame then
        return
    end

    local numTracked = 0
    for _ in pairs(trackedAchievements) do
        numTracked = numTracked + 1
    end

    if isExpanded then
        trackerHeaderFrame.label:SetText("Achievement Tracker: " .. numTracked .. "/10")
    else
        trackerHeaderFrame.label:SetText("Achievement Tracker +")
    end

    -- Size header to content
    local headerWidth = trackerHeaderFrame.label:GetUnboundedStringWidth() + 20
    trackerHeaderFrame:SetWidth(headerWidth)
    trackerHeaderFrame:SetHeight(CONFIG.headerFontSize + 5)
    trackerHeaderFrame.label:SetWidth(headerWidth)

    -- Position header
    trackerHeaderFrame:ClearAllPoints()
    trackerHeaderFrame:SetPoint("TOPLEFT", trackerBaseFrame, "TOPLEFT", 0, -5)
    trackerHeaderFrame:Show()
end

-- Update content display
function AchievementTracker:UpdateContent()
    if not trackerContentFrame then
        return
    end

    trackerContentFrame:Show()

    local maxWidth = 0
    local previousLine = nil

    -- Display each tracked achievement
    for achievementId, _ in pairs(trackedAchievements) do
        local achieveId, achieveName, _, _, _, _, _, achieveDescription, _, _, _, _, achieveComplete, _, _ = GetAchievementInfo(achievementId)

        if achieveId and not achieveComplete then
            -- Achievement title line
            local line = AchievementTracker:GetNextLine()
            if not line then break end

            line.achievementId = achievementId
            line.label:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.achievementFontSize, "OUTLINE")
            line.label:SetText("|cFFFFFF00" .. achieveName .. "|r")
            line.label:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)

            -- Size line
            local textWidth = line.label:GetUnboundedStringWidth()
            line.label:SetWidth(textWidth)
            line:SetWidth(textWidth + CONFIG.marginLeft)
            line:SetHeight(CONFIG.achievementFontSize + 2)

            maxWidth = math.max(maxWidth, textWidth + CONFIG.marginLeft + CONFIG.marginRight)

            -- Position line
            if previousLine then
                line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -CONFIG.paddingBetweenAchievements)
            else
                line:SetPoint("TOPLEFT", trackerContentFrame.ScrollChildFrame, "TOPLEFT", CONFIG.marginLeft, 0)
            end

            line:Show()
            line.label:Show()
            previousLine = line

            -- Achievement criteria (objectives)
            local numCriteria = GetAchievementNumCriteria(achievementId)
            if numCriteria > 0 then
                for objCriteria = 1, numCriteria do
                    local criteriaString, _, completed, quantityProgress, quantityNeeded, _, _, refId, quantityString = GetAchievementCriteriaInfo(achievementId, objCriteria)

                    if criteriaString and criteriaString ~= "" then
                        local objLine = AchievementTracker:GetNextLine()
                        if not objLine then break end

                        objLine.achievementId = achievementId
                        objLine.label:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.objectiveFontSize, "OUTLINE")

                        -- Format objective text
                        local objDesc = criteriaString:gsub("%.", "")
                        local color = completed and "|cFF00FF00" or "|cFFFFFFFF"

                        if quantityNeeded and quantityNeeded > 1 then
                            local progressText = quantityString or (tostring(quantityProgress) .. "/" .. tostring(quantityNeeded))
                            objLine.label:SetText(color .. objDesc .. ": " .. progressText .. "|r")
                        else
                            objLine.label:SetText(color .. objDesc .. "|r")
                        end

                        objLine.label:SetPoint("TOPLEFT", objLine, "TOPLEFT", CONFIG.achievementFontSize, 0)

                        -- Size objective line
                        local objTextWidth = objLine.label:GetUnboundedStringWidth()
                        objLine.label:SetWidth(objTextWidth)
                        objLine:SetWidth(objTextWidth + CONFIG.marginLeft + CONFIG.achievementFontSize)
                        objLine:SetHeight(CONFIG.objectiveFontSize + 1)

                        maxWidth = math.max(maxWidth, objTextWidth + CONFIG.marginLeft + CONFIG.marginRight + CONFIG.achievementFontSize)

                        -- Position objective line
                        objLine:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -1)

                        objLine:Show()
                        objLine.label:Show()
                        previousLine = objLine
                    end
                end
            else
                -- Achievement with no criteria, show description
                if achieveDescription and achieveDescription ~= "" then
                    local descLine = AchievementTracker:GetNextLine()
                    if descLine then
                        descLine.achievementId = achievementId
                        descLine.label:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.objectiveFontSize, "OUTLINE")
                        descLine.label:SetText("|cFFC0C0C0" .. achieveDescription .. "|r")
                        descLine.label:SetPoint("TOPLEFT", descLine, "TOPLEFT", CONFIG.achievementFontSize, 0)

                        local descTextWidth = descLine.label:GetUnboundedStringWidth()
                        descLine.label:SetWidth(descTextWidth)
                        descLine:SetWidth(descTextWidth + CONFIG.marginLeft + CONFIG.achievementFontSize)
                        descLine:SetHeight(CONFIG.objectiveFontSize + 1)

                        maxWidth = math.max(maxWidth, descTextWidth + CONFIG.marginLeft + CONFIG.marginRight + CONFIG.achievementFontSize)

                        descLine:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -1)

                        descLine:Show()
                        descLine.label:Show()
                        previousLine = descLine
                    end
                end
            end
        end
    end

    -- Update content frame size
    if previousLine then
        local contentHeight = previousLine:GetTop() - trackerContentFrame.ScrollChildFrame:GetTop() + previousLine:GetHeight() + 5
        trackerContentFrame.ScrollChildFrame:SetHeight(math.max(contentHeight, 50))
        trackerContentFrame.ScrollChildFrame:SetWidth(maxWidth)
    else
        trackerContentFrame.ScrollChildFrame:SetHeight(50)
        trackerContentFrame.ScrollChildFrame:SetWidth(CONFIG.minLineWidth)
    end
end

-- Update frame size and visibility
function AchievementTracker:UpdateFrame()
    if not trackerBaseFrame then
        return
    end

    local numTracked = 0
    for _ in pairs(trackedAchievements) do
        numTracked = numTracked + 1
    end

    if numTracked == 0 and not isExpanded then
        trackerBaseFrame:Hide()
        return
    end

    trackerBaseFrame:Show()

    -- Calculate sizes
    local headerWidth = trackerHeaderFrame:GetWidth()
    local headerHeight = trackerHeaderFrame:GetHeight()

    if isExpanded then
        local contentWidth = trackerContentFrame.ScrollChildFrame:GetWidth() or CONFIG.minLineWidth
        local contentHeight = trackerContentFrame.ScrollChildFrame:GetHeight() or 50

        trackerBaseFrame:SetWidth(math.max(headerWidth, contentWidth))
        trackerBaseFrame:SetHeight(headerHeight + contentHeight + 10)

        trackerContentFrame:SetWidth(trackerBaseFrame:GetWidth())
        trackerContentFrame:SetHeight(contentHeight)

        -- Position content frame
        trackerContentFrame:ClearAllPoints()
        trackerContentFrame:SetPoint("TOPLEFT", trackerHeaderFrame, "BOTTOMLEFT", 0, 0)
    else
        trackerBaseFrame:SetWidth(headerWidth)
        trackerBaseFrame:SetHeight(headerHeight + 5)
    end
end

-- Public API: Add achievement to tracker
function AchievementTracker:TrackAchievement(achievementId)
    if not achievementId or achievementId == 0 then
        return
    end

    -- Check limit (WoW allows max 10 tracked achievements)
    local count = 0
    for _ in pairs(trackedAchievements) do
        count = count + 1
    end

    if count >= 10 and not trackedAchievements[achievementId] then
        print("You may only track 10 achievements at a time.")
        return
    end

    trackedAchievements[achievementId] = true
    AchievementTracker:Update()
end

-- Public API: Remove achievement from tracker
function AchievementTracker:UntrackAchievement(achievementId)
    if trackedAchievements[achievementId] then
        trackedAchievements[achievementId] = nil
        AchievementTracker:Update()
    end
end

-- Public API: Check if achievement is tracked
function AchievementTracker:IsTracked(achievementId)
    return trackedAchievements[achievementId] == true
end

-- Public API: Get all tracked achievements
function AchievementTracker:GetTrackedAchievements()
    local result = {}
    for id, _ in pairs(trackedAchievements) do
        table.insert(result, id)
    end
    return result
end

-- Public API: Show tracker
function AchievementTracker:Show()
    if trackerBaseFrame then
        trackerBaseFrame:Show()
        AchievementTracker:Update()
    end
end

-- Public API: Hide tracker
function AchievementTracker:Hide()
    if trackerBaseFrame then
        trackerBaseFrame:Hide()
    end
end

-- Public API: Toggle tracker
function AchievementTracker:Toggle()
    if trackerBaseFrame and trackerBaseFrame:IsShown() then
        AchievementTracker:Hide()
    else
        AchievementTracker:Show()
    end
end

-- Public API: Expand tracker
function AchievementTracker:Expand()
    isExpanded = true
    AchievementTracker:Update()
end

-- Public API: Collapse tracker
function AchievementTracker:Collapse()
    isExpanded = false
    AchievementTracker:Update()
end

-- Public API: Set locked state (prevents dragging)
function AchievementTracker:SetLocked(locked)
    if trackerBaseFrame then
        trackerBaseFrame.isLocked = locked
    end
end

return AchievementTracker

