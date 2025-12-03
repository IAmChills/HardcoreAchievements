---@class AchievementTracker
local AchievementTracker = {}
AchievementTracker.__index = AchievementTracker

-- Configuration
local CONFIG = {
    headerFontSize = 14,
    achievementFontSize = 12,
    marginLeft = 14,
    marginRight = 30,
    minWidth = 260,
    paddingBetweenAchievements = 4,
}

-- Local variables
local trackerBaseFrame, trackerHeaderFrame, trackerContentFrame
local achievementLines = {}
local isInitialized = false
local isExpanded = true
local trackedAchievements = {}

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
    trackerBaseFrame:SetSize(CONFIG.minWidth, 30)
    trackerBaseFrame:EnableMouse(true)
    trackerBaseFrame:SetMovable(true)
    trackerBaseFrame:RegisterForDrag("LeftButton")

    -- Backdrop (keep same style)
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
        end
    end)

    trackerBaseFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Initialize header
    trackerHeaderFrame = AchievementTracker:InitializeHeader(trackerBaseFrame)

    -- Initialize content frame
    trackerContentFrame = AchievementTracker:InitializeContentFrame(trackerBaseFrame)

    -- Set initial position
    trackerBaseFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)

    trackerBaseFrame:Hide()
    isInitialized = true

    return trackerBaseFrame
end

-- Initialize header frame with expand/collapse
function AchievementTracker:InitializeHeader(baseFrame)
    local headerFrame = CreateFrame("Button", "AchievementTracker_HeaderFrame", baseFrame)
    headerFrame:SetHeight(CONFIG.headerFontSize + 8)
    headerFrame:EnableMouse(true)
    headerFrame:RegisterForClicks("LeftButtonUp")

    -- Header label
    local headerLabel = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerLabel:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 5, -2)
    headerLabel:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.headerFontSize, "OUTLINE")
    headerFrame.label = headerLabel

    -- Click to expand/collapse
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

    -- Enable dragging from header
    headerFrame:SetMovable(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnDragStart", trackerBaseFrame:GetScript("OnDragStart"))
    headerFrame:SetScript("OnDragStop", trackerBaseFrame:GetScript("OnDragStop"))

    headerFrame:Hide()
    return headerFrame
end

-- Initialize content frame for achievement list
function AchievementTracker:InitializeContentFrame(baseFrame)
    local contentFrame = CreateFrame("Frame", "AchievementTracker_ContentFrame", baseFrame)
    contentFrame:SetWidth(CONFIG.minWidth)
    contentFrame:SetHeight(100)

    -- Enable dragging from content area
    contentFrame:EnableMouse(true)
    contentFrame:SetMovable(true)
    contentFrame:RegisterForDrag("LeftButton")
    contentFrame:SetScript("OnDragStart", trackerBaseFrame:GetScript("OnDragStart"))
    contentFrame:SetScript("OnDragStop", trackerBaseFrame:GetScript("OnDragStop"))

    contentFrame:Hide()
    return contentFrame
end

-- Create or get achievement line
function AchievementTracker:GetAchievementLine(index)
    if not achievementLines[index] then
        local line = CreateFrame("Frame", "AchievementTracker_Line" .. index, trackerContentFrame)
        line:SetHeight(CONFIG.achievementFontSize + 4)

        local label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", line, "TOPLEFT", CONFIG.marginLeft, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.achievementFontSize, "OUTLINE")
        label:SetJustifyH("LEFT")
        line.label = label

        achievementLines[index] = line
    end
    return achievementLines[index]
end

-- Update the tracker display
function AchievementTracker:Update()
    if not isInitialized then
        return
    end

    if InCombatLockdown() then
        return
    end

    -- Count tracked achievements
    local numTracked = 0
    for _ in pairs(trackedAchievements) do
        numTracked = numTracked + 1
    end

    -- Update header
    if isExpanded then
        trackerHeaderFrame.label:SetText("Achievement Tracker: " .. numTracked .. "/10")
    else
        trackerHeaderFrame.label:SetText("Achievement Tracker +")
    end

    local headerWidth = trackerHeaderFrame.label:GetUnboundedStringWidth() + 20
    trackerHeaderFrame:SetWidth(headerWidth)
    trackerHeaderFrame.label:SetWidth(headerWidth)
    trackerHeaderFrame:ClearAllPoints()
    trackerHeaderFrame:SetPoint("TOPLEFT", trackerBaseFrame, "TOPLEFT", 0, -5)
    trackerHeaderFrame:Show()

    -- Update content
    if isExpanded and numTracked > 0 then
        trackerContentFrame:Show()
        trackerContentFrame:ClearAllPoints()
        trackerContentFrame:SetPoint("TOPLEFT", trackerHeaderFrame, "BOTTOMLEFT", 0, -2)

        local maxWidth = CONFIG.minWidth
        local previousLine = nil
        local lineIndex = 0

        -- Display each tracked achievement
        for achievementId, _ in pairs(trackedAchievements) do
            local achieveId, achieveName = GetAchievementInfo(achievementId)

            if achieveId and achieveName then
                lineIndex = lineIndex + 1
                local line = AchievementTracker:GetAchievementLine(lineIndex)
                
                line.label:SetText("|cFFFFFF00" .. achieveName .. "|r")
                line.label:SetWidth(line.label:GetUnboundedStringWidth())
                line:SetWidth(line.label:GetUnboundedStringWidth() + CONFIG.marginLeft + CONFIG.marginRight)
                line:SetHeight(CONFIG.achievementFontSize + 4)

                maxWidth = math.max(maxWidth, line:GetWidth())

                if previousLine then
                    line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -CONFIG.paddingBetweenAchievements)
                else
                    line:SetPoint("TOPLEFT", trackerContentFrame, "TOPLEFT", 0, 0)
                end

                line:Show()
                previousLine = line
            end
        end

        -- Hide unused lines
        for i = lineIndex + 1, #achievementLines do
            if achievementLines[i] then
                achievementLines[i]:Hide()
            end
        end

        -- Update content frame size
        if previousLine then
            local contentHeight = previousLine:GetBottom() - trackerContentFrame:GetTop() + 5
            trackerContentFrame:SetHeight(math.abs(contentHeight))
            trackerContentFrame:SetWidth(maxWidth)
        else
            trackerContentFrame:SetHeight(50)
            trackerContentFrame:SetWidth(CONFIG.minWidth)
        end
    else
        trackerContentFrame:Hide()
        -- Hide all lines
        for _, line in ipairs(achievementLines) do
            if line then
                line:Hide()
            end
        end
    end

    -- Update base frame size
    local headerWidth = trackerHeaderFrame:GetWidth()
    local headerHeight = trackerHeaderFrame:GetHeight()

    if isExpanded and numTracked > 0 then
        local contentWidth = trackerContentFrame:GetWidth() or CONFIG.minWidth
        local contentHeight = trackerContentFrame:GetHeight() or 50

        trackerBaseFrame:SetWidth(math.max(headerWidth, contentWidth))
        trackerBaseFrame:SetHeight(headerHeight + contentHeight + 10)
    else
        trackerBaseFrame:SetWidth(headerWidth)
        trackerBaseFrame:SetHeight(headerHeight + 5)
    end

    -- Show/hide base frame
    if numTracked == 0 and not isExpanded then
        trackerBaseFrame:Hide()
    else
        trackerBaseFrame:Show()
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
