---@class AchievementTracker
local AchievementTracker = {}
AchievementTracker.__index = AchievementTracker

-- Configuration
local CONFIG = {
    headerFontSize = 14,
    achievementFontSize = 12,
    marginLeft = 14,
    marginRight = 30,
    minWidth = 230,
    minHeight = 100,
    paddingBetweenAchievements = 4,
}

-- Local variables
local trackerBaseFrame, trackerHeaderFrame, trackerContentFrame, trackerSizer
local achievementLines = {}
local isInitialized = false
local isExpanded = true
local trackedAchievements = {}
local isSizing = false
local savedBackdropSettings = { enabled = false, alpha = 0 }
local savedFrameHeight = nil  -- Store the frame height to persist across collapse/expand
local savedFrameWidth = nil   -- Store the frame width to persist across collapse/expand
local hasBeenResized = false  -- Track if user has manually resized
local initialHeight = 100
local initialWidth = 250
local isMouseOverTracker = false  -- Track if mouse is currently over the tracker

-- Initialize the tracker
function AchievementTracker:Initialize()
    if isInitialized then
        return
    end

    -- Create base frame with backdrop support
    trackerBaseFrame = CreateFrame("Frame", "AchievementTracker_BaseFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    trackerBaseFrame:SetClampedToScreen(true)
    trackerBaseFrame:SetFrameStrata("MEDIUM")
    trackerBaseFrame:SetFrameLevel(0)
    trackerBaseFrame:SetSize(initialWidth, initialHeight)
    savedFrameHeight = initialHeight
    savedFrameWidth = initialWidth  -- Save initial width
    
    -- Set backdrop (initially transparent)
    trackerBaseFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    trackerBaseFrame:SetBackdropColor(0, 0, 0, 0)
    trackerBaseFrame:SetBackdropBorderColor(1, 1, 1, 0)
    
    -- Enable mouse (needed for header and sizer to work), but require Shift for dragging
    trackerBaseFrame:EnableMouse(true)
    trackerBaseFrame:SetMovable(true)
    trackerBaseFrame:SetResizable(true)
    trackerBaseFrame:RegisterForDrag("LeftButton")

    -- Drag handlers for the entire frame (require Shift key to drag)
    trackerBaseFrame:SetScript("OnDragStart", function(self)
        if isSizing then
            return
        end
        -- Only allow dragging if Shift key is held down
        if not IsShiftKeyDown() then
            return  -- Prevent dragging without Shift
        end
        self:StartMoving()
    end)

    trackerBaseFrame:SetScript("OnDragStop", function(self)
        if not isSizing then
            self:StopMovingOrSizing()
        end
    end)
    
    -- Initialize header
    trackerHeaderFrame = AchievementTracker:InitializeHeader(trackerBaseFrame)

    -- Initialize content frame
    trackerContentFrame = AchievementTracker:InitializeContentFrame(trackerBaseFrame)

    -- Initialize sizer (resize handle)
    trackerSizer = AchievementTracker:InitializeSizer(trackerBaseFrame)
    
    -- Helper function to show sizer on hover (defined after sizer is created)
    local function ShowSizerOnHover()
        isMouseOverTracker = true
        if trackerSizer and trackerSizer:IsVisible() and not isSizing then
            trackerSizer:SetAlpha(0.8)
        end
    end
    
    -- Helper function to hide sizer when not hovering
    local function HideSizerOnLeave()
        isMouseOverTracker = false
        if trackerSizer and not isSizing then
            trackerSizer:SetAlpha(0)
        end
    end
    
    -- Show sizer when mouse enters tracker frame
    trackerBaseFrame:SetScript("OnEnter", function(self)
        ShowSizerOnHover()
    end)
    trackerBaseFrame:SetScript("OnLeave", function(self)
        -- Use a small delay to avoid hiding when moving between child frames
        -- Child frames (header, content, sizer) will set isMouseOverTracker to true on their OnEnter
        C_Timer.After(0.1, function()
            -- Only hide if mouse is truly not over any part of the tracker
            if not isMouseOverTracker and not isSizing then
                HideSizerOnLeave()
            end
        end)
    end)
    
    -- Hook into existing header OnEnter to also show sizer
    local originalHeaderOnEnter = trackerHeaderFrame:GetScript("OnEnter")
    trackerHeaderFrame:SetScript("OnEnter", function(self)
        if originalHeaderOnEnter then originalHeaderOnEnter(self) end
        ShowSizerOnHover()
    end)
    
    -- Add OnEnter/OnLeave handlers to content frame to show sizer
    trackerContentFrame:SetScript("OnEnter", ShowSizerOnHover)
    trackerContentFrame:SetScript("OnLeave", function(self)
        -- Don't hide immediately - check if mouse left entire tracker
        C_Timer.After(0.1, function()
            if not isMouseOverTracker and not isSizing then
                HideSizerOnLeave()
            end
        end)
    end)

    -- Set initial position
    trackerBaseFrame:SetPoint("CENTER", UIParent, "CENTER")

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

    -- Header icon
    local headerIcon = headerFrame:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(CONFIG.headerFontSize + 4, CONFIG.headerFontSize + 4)
    headerIcon:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
    headerIcon:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png")
    headerFrame.icon = headerIcon

    -- Header label (positioned after icon)
    local headerLabel = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerLabel:SetPoint("LEFT", headerIcon, "RIGHT", 5, 0)
    headerLabel:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.headerFontSize)
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
    
    -- Note: Sizer visibility will be handled after all frames are initialized

    -- Pass drag events to parent frame (only when Shift is held)
    headerFrame:EnableMouse(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnDragStart", function(self)
        -- Only forward drag if Shift is held
        if trackerBaseFrame and IsShiftKeyDown() then
            trackerBaseFrame:GetScript("OnDragStart")(trackerBaseFrame)
        end
    end)
    headerFrame:SetScript("OnDragStop", function(self)
        -- Forward drag stop to parent base frame
        if trackerBaseFrame then
            trackerBaseFrame:GetScript("OnDragStop")(trackerBaseFrame)
        end
    end)

    headerFrame:Hide()
    return headerFrame
end

    -- Initialize content frame for achievement list
function AchievementTracker:InitializeContentFrame(baseFrame)
    local contentFrame = CreateFrame("Frame", "AchievementTracker_ContentFrame", baseFrame)
    contentFrame:SetWidth(initialWidth)
    contentFrame:SetHeight(100)

    -- Pass drag events to parent frame (don't make content independently draggable)
    contentFrame:EnableMouse(true)
    contentFrame:RegisterForDrag("LeftButton")
    contentFrame:SetScript("OnDragStart", function(self)
        -- Forward drag to parent base frame
        if trackerBaseFrame then
            trackerBaseFrame:GetScript("OnDragStart")(trackerBaseFrame)
        end
    end)
    contentFrame:SetScript("OnDragStop", function(self)
        -- Forward drag stop to parent base frame
        if trackerBaseFrame then
            trackerBaseFrame:GetScript("OnDragStop")(trackerBaseFrame)
        end
    end)

    contentFrame:Hide()
    return contentFrame
end

-- Initialize sizer (resize handle) in bottom right corner
function AchievementTracker:InitializeSizer(baseFrame)
    local sizer = CreateFrame("Frame", "AchievementTracker_Sizer", baseFrame)
    sizer:SetPoint("BOTTOMRIGHT", 0, 0)
    sizer:SetWidth(35)  -- Increased size for easier grabbing
    sizer:SetHeight(35)  -- Increased size for easier grabbing
    sizer:SetFrameLevel(baseFrame:GetFrameLevel() + 10)  -- Ensure sizer is above other elements
    sizer:SetAlpha(0)  -- Hidden by default
    sizer:EnableMouse(true)
    -- Sizer should always be mouse-enabled as a child frame
    
    -- Create visual resize indicator (corner lines similar to Questie)
    local sizerLine1 = sizer:CreateTexture(nil, "BACKGROUND")
    sizerLine1:SetWidth(14)
    sizerLine1:SetHeight(14)
    sizerLine1:SetPoint("BOTTOMRIGHT", -4, 4)
    sizerLine1:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    local x = 0.1 * 14 / 17
    sizerLine1:SetTexCoord(1 / 32 - x, 0.5, 1 / 32, 0.5 + x, 1 / 32, 0.5 - x, 1 / 32 + x, 0.5)
    
    local sizerLine2 = sizer:CreateTexture(nil, "BACKGROUND")
    sizerLine2:SetWidth(11)
    sizerLine2:SetHeight(11)
    sizerLine2:SetPoint("BOTTOMRIGHT", -4, 4)
    sizerLine2:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    x = 0.1 * 11 / 17
    sizerLine2:SetTexCoord(1 / 32 - x, 0.5, 1 / 32, 0.5 + x, 1 / 32, 0.5 - x, 1 / 32 + x, 0.5)
    
    local sizerLine3 = sizer:CreateTexture(nil, "BACKGROUND")
    sizerLine3:SetWidth(8)
    sizerLine3:SetHeight(8)
    sizerLine3:SetPoint("BOTTOMRIGHT", -4, 4)
    sizerLine3:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    x = 0.1 * 8 / 17
    sizerLine3:SetTexCoord(1 / 32 - x, 0.5, 1 / 32, 0.5 + x, 1 / 32, 0.5 - x, 1 / 32 + x, 0.5)
    
    -- Keep sizer visible when hovering over it
    sizer:SetScript("OnEnter", function(self)
        if not isSizing then
            self:SetAlpha(1)
        end
    end)
    
    -- Resize start handler
    sizer:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not InCombatLockdown() then
            if not ChatEdit_GetActiveWindow() then
                isSizing = true
                baseFrame.isSizing = true
                
                -- Keep sizer visible during resize
                self:SetAlpha(1)
                
                -- Save current backdrop settings
                savedBackdropSettings.enabled = true
                savedBackdropSettings.alpha = 0.8
                
                -- Show backdrop during resize for visual feedback
                trackerBaseFrame:SetBackdropColor(0, 0, 0, 0.8)
                trackerBaseFrame:SetBackdropBorderColor(1, 1, 1, 0.8)
                
                -- Start resizing from bottom-right corner
                baseFrame:StartSizing("BOTTOMRIGHT")
                
                -- Update continuously while resizing (more frequent for responsive word wrap)
                local updateTimer = C_Timer.NewTicker(0.05, function()
                    if not isSizing or InCombatLockdown() then
                        updateTimer:Cancel()
                        return
                    end
                    -- Enforce minimum sizes
                    local width = baseFrame:GetWidth()
                    local height = baseFrame:GetHeight()
                    if width < CONFIG.minWidth then
                        baseFrame:SetWidth(CONFIG.minWidth)
                    end
                    if height < CONFIG.minHeight then
                        baseFrame:SetHeight(CONFIG.minHeight)
                    end
                    -- Update immediately to make word wrap responsive
                    AchievementTracker:Update()
                end)
                sizer.updateTimer = updateTimer
            end
        end
    end)
    
    -- Resize stop handler
    sizer:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and isSizing then
            isSizing = false
            baseFrame.isSizing = false
            
            -- Stop resizing
            baseFrame:StopMovingOrSizing()
            
            -- Cancel update timer
            if sizer.updateTimer then
                sizer.updateTimer:Cancel()
                sizer.updateTimer = nil
            end
            
            -- Restore backdrop (make transparent again)
            trackerBaseFrame:SetBackdropColor(0, 0, 0, 0)
            trackerBaseFrame:SetBackdropBorderColor(1, 1, 1, 0)
            
            -- Final size enforcement and save dimensions
            local width = baseFrame:GetWidth()
            local height = baseFrame:GetHeight()
            if width < CONFIG.minWidth then
                baseFrame:SetWidth(CONFIG.minWidth)
                savedFrameWidth = CONFIG.minWidth
            else
                -- Save the width when user finishes resizing
                savedFrameWidth = width
            end
            if height < CONFIG.minHeight then
                baseFrame:SetHeight(CONFIG.minHeight)
                savedFrameHeight = CONFIG.minHeight
            else
                -- Save the height when user finishes resizing
                savedFrameHeight = height
            end
            
            -- Update the tracker
            AchievementTracker:Update()
            
        end
    end)
    
    sizer:Hide()
    return sizer
end

-- Helper function to get achievement level from definition
local function GetAchievementLevel(achievementId)
    -- Try to get from global achievement definitions
    if _G.Achievements then
        for _, rec in ipairs(_G.Achievements) do
            if tostring(rec.achId) == tostring(achievementId) then
                return rec.level
            end
        end
    end
    -- Try HCA_AchievementDefs (for dungeon/other achievements)
    if _G.HCA_AchievementDefs and _G.HCA_AchievementDefs[tostring(achievementId)] then
        return _G.HCA_AchievementDefs[tostring(achievementId)].level
    end
    -- Try to get from achievement row if available
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if (row.id == achievementId or row.achId == achievementId) and row.maxLevel then
                -- maxLevel represents the level requirement
                return row.maxLevel
            end
        end
    end
    return nil
end

-- Helper function to get achievement description/tooltip from definition
local function GetAchievementDescription(achievementId)
    -- Try to get from global achievement definitions
    if _G.Achievements then
        for _, rec in ipairs(_G.Achievements) do
            if tostring(rec.achId) == tostring(achievementId) then
                return rec.tooltip
            end
        end
    end
    -- Try HCA_AchievementDefs (for dungeon/other achievements)
    if _G.HCA_AchievementDefs and _G.HCA_AchievementDefs[tostring(achievementId)] then
        return _G.HCA_AchievementDefs[tostring(achievementId)].tooltip
    end
    -- Try to get from achievement row if available
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if (row.id == achievementId or row.achId == achievementId) then
                return row.tooltip or row._tooltip
            end
        end
    end
    return nil
end

-- Helper function to get title color based on player level vs required level
local function GetTitleColor(requiredLevel)
    if not requiredLevel or requiredLevel <= 0 then
        return "FFFF00"  -- Yellow (default) if no level requirement
    end
    
    local playerLevel = UnitLevel("player") or 1
    local levelDiff = requiredLevel - playerLevel
    
    if levelDiff <= 1 then
        -- Within 1 level or equal/above: Yellow
        return "FFFF00"
    elseif levelDiff == 2 then
        -- 2 levels below: Orange (#f26000)
        return "F26000"
    else
        -- 3+ levels below: Red (#ff0000)
        return "FF0000"
    end
end

-- Create or get achievement line
function AchievementTracker:GetAchievementLine(index)
    if not achievementLines[index] then
        local line = CreateFrame("Frame", "AchievementTracker_Line" .. index, trackerContentFrame)
        line:SetHeight(CONFIG.achievementFontSize + 4)

        -- Title label (with word wrap support)
        local label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", line, "TOPLEFT", CONFIG.marginLeft, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.achievementFontSize)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetWordWrap(true)
        line.label = label

        -- Description label (below title, with indent)
        local descriptionLabel = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        descriptionLabel:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        descriptionLabel:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.achievementFontSize)
        descriptionLabel:SetJustifyH("LEFT")
        descriptionLabel:SetJustifyV("TOP")
        descriptionLabel:SetWordWrap(true)
        descriptionLabel:SetTextColor(1, 1, 1)
        line.descriptionLabel = descriptionLabel

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

    -- Update header (yellow color)
    if isExpanded then
        trackerHeaderFrame.label:SetText("|cFFFFFF00Achievement Tracker: " .. numTracked .. "/10|r")
    else
        trackerHeaderFrame.label:SetText("|cFFFFFF00Achievement Tracker +|r")
    end

    -- Calculate header width including icon, spacing, and label
    local iconWidth = trackerHeaderFrame.icon and (CONFIG.headerFontSize + 4) or 0
    local iconSpacing = trackerHeaderFrame.icon and 5 or 0
    local labelWidth = trackerHeaderFrame.label:GetUnboundedStringWidth()
    local headerWidth = 5 + iconWidth + iconSpacing + labelWidth + 15 -- left margin + icon + spacing + text + right margin
    trackerHeaderFrame:SetWidth(headerWidth)
    trackerHeaderFrame.label:SetWidth(labelWidth)
    trackerHeaderFrame:ClearAllPoints()
    trackerHeaderFrame:SetPoint("TOPLEFT", trackerBaseFrame, "TOPLEFT", 0, -5)
    trackerHeaderFrame:Show()

    -- Show/hide sizer based on expanded state (alpha controlled by mouse hover)
    if isExpanded and numTracked > 0 then
        if not trackerSizer:IsVisible() then
            trackerSizer:Show()
        end
        -- Don't reset alpha if mouse is over tracker - let hover handlers control it
        if not isMouseOverTracker and not isSizing then
            trackerSizer:SetAlpha(0)  -- Only reset if not hovering
        end
    else
        trackerSizer:Hide()
        trackerSizer:SetAlpha(0)  -- Reset alpha when hidden
    end

    -- Restore saved dimensions BEFORE updating content (so content uses correct size)
    if not isSizing then
        if isExpanded and numTracked > 0 then
            -- Restore saved width and height before rendering content
            if savedFrameWidth and savedFrameWidth >= CONFIG.minWidth then
                trackerBaseFrame:SetWidth(savedFrameWidth)
            end
            if savedFrameHeight and savedFrameHeight >= CONFIG.minHeight then
                trackerBaseFrame:SetHeight(savedFrameHeight)
            end
        end
    end

    -- Update content
    if isExpanded and numTracked > 0 then
        trackerContentFrame:Show()
        trackerContentFrame:ClearAllPoints()
        trackerContentFrame:SetPoint("TOPLEFT", trackerHeaderFrame, "BOTTOMLEFT", 0, -2)

        -- Use current width during resize, otherwise use saved width
        local baseFrameWidth
        if isSizing then
            -- During resize, always use current width for responsive word wrap
            baseFrameWidth = trackerBaseFrame:GetWidth() or initialWidth
        else
            -- When not resizing, use saved width or current width
            baseFrameWidth = savedFrameWidth or trackerBaseFrame:GetWidth() or initialWidth
        end
        local maxWidth = baseFrameWidth
        local previousLine = nil
        local lineIndex = 0
        
        -- Set content frame width to match base frame (for text wrapping)
        trackerContentFrame:SetWidth(baseFrameWidth)

        -- Sort tracked achievements by level (easiest to hardest)
        local sortedAchievements = {}
        for achievementId, data in pairs(trackedAchievements) do
            local level = GetAchievementLevel(achievementId) or 999  -- Put achievements without level at end
            table.insert(sortedAchievements, {
                id = achievementId,
                data = data,
                level = level
            })
        end
        
        -- Sort by level (ascending - easiest first)
        table.sort(sortedAchievements, function(a, b)
            return a.level < b.level
        end)

        -- Display each tracked achievement in sorted order
        for _, achievementEntry in ipairs(sortedAchievements) do
            local achievementId = achievementEntry.id
            local data = achievementEntry.data
            local achieveName = nil
            
            -- Try to get name from stored data first (custom achievements)
            if type(data) == "table" and data.title then
                achieveName = data.title
            elseif type(data) == "string" then
                -- Legacy support: if data is a string, use it as the title
                achieveName = data
            else
                -- Try WoW's built-in achievement system (for compatibility)
                local wowAchieveId, wowAchieveName = GetAchievementInfo(achievementId)
                if wowAchieveId and wowAchieveName then
                    achieveName = wowAchieveName
                else
                    -- Fallback: try to get from achievement row if available
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if (row.id == achievementId or row.achId == achievementId) and row.Title then
                                achieveName = row.Title:GetText() or tostring(achievementId)
                                break
                            end
                        end
                    end
                    -- Last resort: use achievement ID as name
                    if not achieveName then
                        achieveName = tostring(achievementId)
                    end
                end
            end

            if achieveName then
                lineIndex = lineIndex + 1
                local line = AchievementTracker:GetAchievementLine(lineIndex)
                
                -- Get achievement level and format title with level prefix
                local achievementLevel = GetAchievementLevel(achievementId)
                local displayTitle = achieveName
                if achievementLevel then
                    displayTitle = "[" .. achievementLevel .. "] " .. achieveName
                end
                
                -- Set title with color coding based on player level vs required level
                local titleColor = GetTitleColor(achievementLevel)
                line.label:SetText("|cff" .. titleColor .. displayTitle .. "|r")
                
                -- Get and set description (gray color)
                local description = GetAchievementDescription(achievementId)
                local availableWidth = (trackerContentFrame:GetWidth() or initialWidth) - CONFIG.marginLeft - CONFIG.marginRight
                
                if description then
                    -- Strip color codes from description for cleaner display
                    local cleanDescription = description:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    -- Reposition description label with indent (12px from title start)
                    line.descriptionLabel:ClearAllPoints()
                    line.descriptionLabel:SetPoint("TOPLEFT", line.label, "BOTTOMLEFT", 12, -2)
                    line.descriptionLabel:SetWidth(availableWidth - 12)  -- Account for indent
                    line.descriptionLabel:SetText(cleanDescription)
                    line.descriptionLabel:Show()
                    -- Calculate total height needed (title + spacing + description)
                    local titleHeight = line.label:GetHeight()
                    local descriptionHeight = line.descriptionLabel:GetStringHeight()
                    line:SetHeight(titleHeight + descriptionHeight + 4)  -- 4px spacing between title and description
                else
                    line.descriptionLabel:Hide()
                    line:SetHeight(CONFIG.achievementFontSize + 4)
                end
                
                -- Set title width to allow wrapping
                line.label:SetWidth(availableWidth)
                
                -- Set line width to match content frame width
                line:SetWidth(baseFrameWidth)
                
                -- Track the widest content for auto-sizing (only if not manually resized)
                -- Use GetStringWidth which respects wrapping
                if not isSizing then
                    local titleWidth = line.label:GetStringWidth() or line.label:GetUnboundedStringWidth()
                    local descWidth = description and (line.descriptionLabel:GetStringWidth() or (line.descriptionLabel:GetUnboundedStringWidth() + 12)) or 0
                    local contentWidth = math.max(titleWidth, descWidth) + CONFIG.marginLeft + CONFIG.marginRight
                    maxWidth = math.max(maxWidth, contentWidth)
                end

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
        else
            trackerContentFrame:SetHeight(50)
        end
        
        -- Clamp content to base frame height (cutoff if too small, no scrolling)
        local baseFrameHeight = trackerBaseFrame:GetHeight() or initialHeight
        local headerHeight = trackerHeaderFrame:GetHeight()
        local maxContentHeight = baseFrameHeight - headerHeight - 10
        if trackerContentFrame:GetHeight() > maxContentHeight then
            trackerContentFrame:SetHeight(maxContentHeight)
            -- Hide lines that would be cut off
            local accumulatedHeight = 0
            for i = 1, lineIndex do
                if achievementLines[i] then
                    local lineHeight = achievementLines[i]:GetHeight() + CONFIG.paddingBetweenAchievements
                    if accumulatedHeight + lineHeight > maxContentHeight then
                        achievementLines[i]:Hide()
                    else
                        accumulatedHeight = accumulatedHeight + lineHeight
                    end
                end
            end
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

    -- Update base frame size (only auto-size if not manually resizing)
    local headerWidth = trackerHeaderFrame:GetWidth()
    local headerHeight = trackerHeaderFrame:GetHeight()

    if not isSizing then
        -- Save current top-left corner position before resizing to prevent frame from moving
        local topLeftX = trackerBaseFrame:GetLeft()
        local topLeftY = trackerBaseFrame:GetTop()

        if isExpanded and numTracked > 0 then
            -- Use saved width and height if available, otherwise calculate from content
            local contentWidth = trackerContentFrame:GetWidth() or initialWidth
            local contentHeight = trackerContentFrame:GetHeight() or initialHeight
            
            if savedFrameWidth and savedFrameWidth >= CONFIG.minWidth then
                trackerBaseFrame:SetWidth(savedFrameWidth)
            else
                -- Calculate width from content, but ensure it's at least initialWidth (or minimum if smaller)
                local calculatedWidth = math.max(headerWidth, contentWidth, initialWidth)
                trackerBaseFrame:SetWidth(math.max(calculatedWidth, CONFIG.minWidth))
                savedFrameWidth = trackerBaseFrame:GetWidth()  -- Save calculated width
            end
            
            if savedFrameHeight and savedFrameHeight >= CONFIG.minHeight then
                trackerBaseFrame:SetHeight(savedFrameHeight)
            else
                -- Calculate height from content, but ensure it's at least initialHeight (or minimum if smaller)
                local calculatedHeight = headerHeight + contentHeight + 10
                trackerBaseFrame:SetHeight(math.max(calculatedHeight, initialHeight, CONFIG.minHeight))
                savedFrameHeight = trackerBaseFrame:GetHeight()  -- Save calculated height
            end
        else
            -- Save width and height before collapsing
            local currentWidth = trackerBaseFrame:GetWidth()
            local currentHeight = trackerBaseFrame:GetHeight()
            if currentWidth and currentWidth >= CONFIG.minWidth then
                savedFrameWidth = currentWidth
            end
            if currentHeight and currentHeight >= CONFIG.minHeight then
                savedFrameHeight = currentHeight
            end
            
            trackerBaseFrame:SetWidth(headerWidth)
            trackerBaseFrame:SetHeight(headerHeight + 5)
        end

        -- Restore top-left corner position after resizing to keep header in place
        if topLeftX and topLeftY then
            trackerBaseFrame:ClearAllPoints()
            trackerBaseFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", topLeftX, topLeftY)
        end
    end
    
    -- Ensure minimum sizes even during resize
    if trackerBaseFrame:GetWidth() < CONFIG.minWidth then
        trackerBaseFrame:SetWidth(CONFIG.minWidth)
    end
    if trackerBaseFrame:GetHeight() < CONFIG.minHeight then
        trackerBaseFrame:SetHeight(CONFIG.minHeight)
    end

    -- Show/hide base frame
    if numTracked == 0 and not isExpanded then
        trackerBaseFrame:Hide()
    else
        trackerBaseFrame:Show()
    end
end

-- Public API: Add achievement to tracker
-- achievementId: string or number - the achievement ID
-- title: optional string - the achievement title (for custom achievements)
function AchievementTracker:TrackAchievement(achievementId, title)
    if not achievementId or achievementId == 0 then
        return
    end

    -- Check limit (WoW allows max 10 tracked achievements)
    local count = 0
    for _ in pairs(trackedAchievements) do
        count = count + 1
    end

    if count >= 10 and not trackedAchievements[achievementId] then
        print("|cff69adc9[Hardcore Achievements]|r You may only track 10 achievements at a time.")
        return
    end

    -- Store achievement data (title for custom achievements)
    if title then
        trackedAchievements[achievementId] = { title = title }
    else
        trackedAchievements[achievementId] = true
    end
    
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
    return trackedAchievements[achievementId] ~= nil
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

-- Export globally for use in main addon
_G.HardcoreAchievementsTracker = AchievementTracker

return AchievementTracker
