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
    maxWidth = 500,
    maxHeight = 600,
    collapseButtonOffset = 15,  -- Button horizontal offset from left margin
}

-- Local variables
local trackerBaseFrame, trackerHeaderFrame, trackerContentFrame, trackerSizer
local achievementLines = {}
local isInitialized = false
local isExpanded = true
local trackedAchievements = {}
local collapsedAchievements = {}  -- Track which achievements are collapsed (true = collapsed, nil/false = expanded)
local isSizing = false
local savedBackdropSettings = { enabled = false, alpha = 0 }
local savedFrameHeight = nil  -- Store the frame height to persist across collapse/expand
local savedFrameWidth = nil   -- Store the frame width to persist across collapse/expand
local hasBeenResized = false  -- Track if user has manually resized
local userSetWidth = nil      -- User-set width (from manual resize) - takes precedence over auto-sizing
local userSetHeight = nil     -- User-set height (from manual resize) - takes precedence over auto-sizing
local initialHeight = 100
local initialWidth = 250
local isMouseOverTracker = false  -- Track if mouse is currently over the tracker
local fadeTicker = nil  -- Ticker for smooth fade in/out animation
local fadeTickerDirection = nil  -- true = fade in, false = fade out
local fadeTickerValue = 0  -- Current fade value (0 to 0.3)
local hoveredLine = nil  -- Track which achievement line is currently hovered
local HOVER_ALPHA = 0.6  -- Alpha for non-hovered lines when mouse is over tracker

-- Fade ticker system (matching Questie's approach) - module level so accessible from Initialize and Update
local function StartFadeTicker()
    if not fadeTicker then
        fadeTicker = C_Timer.NewTicker(0.02, function()
            if fadeTickerDirection then
                -- Fade in (Unfade)
                if fadeTickerValue < 0.3 then
                    fadeTickerValue = fadeTickerValue + 0.02
                    
                    -- Update sizer alpha (matching Questie's formula: fadeTickerValue * 3.3)
                    if trackerSizer and trackerSizer:IsVisible() and not isSizing then
                        trackerSizer:SetAlpha(fadeTickerValue * 3.3)
                    end
                else
                    -- Reached max alpha, cancel ticker
                    fadeTicker:Cancel()
                    fadeTicker = nil
                end
            else
                -- Fade out
                if fadeTickerValue > 0 then
                    fadeTickerValue = fadeTickerValue - 0.02
                    
                    if fadeTickerValue < 0 then
                        fadeTickerValue = 0
                    end
                    
                    -- Update sizer alpha
                    if trackerSizer and not isSizing then
                        trackerSizer:SetAlpha(fadeTickerValue * 3.3)
                    end
                    
                    if fadeTickerValue <= 0 then
                        -- Reached min alpha, cancel ticker
                        fadeTicker:Cancel()
                        fadeTicker = nil
                    end
                else
                    fadeTickerValue = 0
                    if trackerSizer and not isSizing then
                        trackerSizer:SetAlpha(0)
                    end
                    fadeTicker:Cancel()
                    fadeTicker = nil
                end
            end
        end)
    end
end

-- Function to fade in sizer (matching Questie's Unfade)
local function UnfadeSizer()
    -- Check if tracker is expanded and has tracked achievements
    local hasTrackedAchievements = next(trackedAchievements) ~= nil
    if isExpanded and hasTrackedAchievements then
        fadeTickerDirection = true
        StartFadeTicker()
    end
end

-- Function to fade out sizer (matching Questie's Fade)
local function FadeSizer()
    -- Check if tracker is expanded and has tracked achievements
    local hasTrackedAchievements = next(trackedAchievements) ~= nil
    if isExpanded and hasTrackedAchievements then
        fadeTickerDirection = false
        StartFadeTicker()
    end
end

-- Helper function to set all achievement lines to a specific alpha
local function SetAllLinesAlpha(alpha)
    for _, line in ipairs(achievementLines) do
        if line and line:IsShown() then
            line:SetAlpha(alpha)
            -- Also set alpha on child elements (label, descriptionLabel, collapseButton)
            if line.label then
                line.label:SetAlpha(alpha)
            end
            if line.descriptionLabel then
                line.descriptionLabel:SetAlpha(alpha)
            end
            if line.collapseButton then
                line.collapseButton:SetAlpha(alpha)
            end
        end
    end
end

-- Helper function to reset all lines to full opacity
local function ResetAllLinesAlpha()
    hoveredLine = nil
    SetAllLinesAlpha(1.0)
end

-- Helper functions to save/load tracker position and size from database
local function SaveTrackerPosition()
    if not trackerBaseFrame then return end
    
    -- Get character-specific database
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) ~= "function" then return end
    
    local _, cdb = getCharDB()
    if not cdb then return end
    
    -- Initialize tracker data structure
    cdb.tracker = cdb.tracker or {}
    
    -- Get current position (save as left/top coordinates relative to screen)
    local left = trackerBaseFrame:GetLeft()
    local top = trackerBaseFrame:GetTop()
    
    if left and top then
        cdb.tracker.left = left
        cdb.tracker.top = top
    end
end

local function LoadTrackerPosition()
    -- Get character-specific database
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) ~= "function" then
        return nil, nil
    end
    
    local _, cdb = getCharDB()
    if not cdb or not cdb.tracker then
        return nil, nil
    end
    
    local trackerData = cdb.tracker
    if trackerData.left and trackerData.top then
        return trackerData.left, trackerData.top
    end
    
    return nil, nil
end

local function SaveTrackerSize()
    if not trackerBaseFrame then return end
    
    -- Get character-specific database
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) ~= "function" then return end
    
    local _, cdb = getCharDB()
    if not cdb then return end
    
    -- Initialize tracker data structure
    cdb.tracker = cdb.tracker or {}
    
    -- Save current size (prefer user-set dimensions if available)
    local width = userSetWidth or trackerBaseFrame:GetWidth()
    local height = userSetHeight or trackerBaseFrame:GetHeight()
    
    if width and width >= CONFIG.minWidth then
        cdb.tracker.width = width
        if userSetWidth then
            cdb.tracker.userSetWidth = true
        end
    end
    if height and height >= CONFIG.minHeight then
        cdb.tracker.height = height
        if userSetHeight then
            cdb.tracker.userSetHeight = true
        end
    end
end

local function LoadTrackerSize()
    -- Get character-specific database
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) ~= "function" then
        return nil, nil, false, false
    end
    
    local _, cdb = getCharDB()
    if not cdb or not cdb.tracker then
        return nil, nil, false, false
    end
    
    local trackerData = cdb.tracker
    local width = trackerData.width
    local height = trackerData.height
    local wasUserSetWidth = trackerData.userSetWidth == true
    local wasUserSetHeight = trackerData.userSetHeight == true
    
    -- Validate sizes are within bounds
    local validWidth = width and width >= CONFIG.minWidth and width <= (CONFIG.maxWidth or 9999)
    local validHeight = height and height >= CONFIG.minHeight and height <= (CONFIG.maxHeight or 9999)
    
    return validWidth and width or nil, validHeight and height or nil, wasUserSetWidth, wasUserSetHeight
end

-- Helper function to save tracked achievements to database
local function SaveTrackedAchievements()
    -- Get character-specific database
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) ~= "function" then return end
    
    local _, cdb = getCharDB()
    if not cdb then return end
    
    -- Initialize tracker data structure
    cdb.tracker = cdb.tracker or {}
    
    -- Convert trackedAchievements table to a serializable format
    local savedAchievements = {}
    for achievementId, data in pairs(trackedAchievements) do
        local achIdStr = tostring(achievementId)
        if type(data) == "table" and data.title then
            -- Custom achievement with title
            savedAchievements[achIdStr] = { title = data.title }
        else
            -- Standard achievement (just mark as tracked)
            savedAchievements[achIdStr] = true
        end
    end
    
    cdb.tracker.trackedAchievements = savedAchievements
end

-- Helper function to load tracked achievements from database
local function LoadTrackedAchievements()
    -- Get character-specific database
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) ~= "function" then
        return {}
    end
    
    local _, cdb = getCharDB()
    if not cdb or not cdb.tracker then
        return {}
    end
    
    local trackerData = cdb.tracker
    if not trackerData.trackedAchievements then
        return {}
    end
    
    -- Return a copy of the saved achievements
    local loadedAchievements = {}
    for achievementId, data in pairs(trackerData.trackedAchievements) do
        if type(data) == "table" and data.title then
            loadedAchievements[achievementId] = { title = data.title }
        else
            loadedAchievements[achievementId] = true
        end
    end
    
    return loadedAchievements
end

-- Function to restore tracked achievements from database (called on login/reload)
local function RestoreTrackedAchievements()
    if not isInitialized then
        return
    end
    
    local savedAchievements = LoadTrackedAchievements()
    if not savedAchievements or next(savedAchievements) == nil then
        return  -- No saved achievements to restore
    end
    
    -- Clear current tracked achievements
    trackedAchievements = {}
    
    -- Restore each saved achievement
    for achievementId, data in pairs(savedAchievements) do
        -- Convert string ID back to number if possible
        local achId = tonumber(achievementId) or achievementId
        
        if type(data) == "table" and data.title then
            trackedAchievements[achId] = { title = data.title }
        else
            trackedAchievements[achId] = true
        end
    end
    
    -- Update the tracker display (this will show it if there are tracked achievements)
    AchievementTracker:Update()
    
    -- Show the tracker if there are tracked achievements (auto-show on login)
    if next(trackedAchievements) ~= nil then
        AchievementTracker:Show()
    end
end

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
    
    -- Load saved size from database, or use initial values
    local savedWidth, savedHeight, wasUserSetWidth, wasUserSetHeight = LoadTrackerSize()
    if savedWidth and savedHeight then
        trackerBaseFrame:SetSize(savedWidth, savedHeight)
        savedFrameWidth = savedWidth
        savedFrameHeight = savedHeight
        -- Restore user-set flags if they were saved
        if wasUserSetWidth then
            userSetWidth = savedWidth
            hasBeenResized = true
        end
        if wasUserSetHeight then
            userSetHeight = savedHeight
            hasBeenResized = true
        end
    else
        trackerBaseFrame:SetSize(initialWidth, initialHeight)
        savedFrameWidth = initialWidth
        savedFrameHeight = initialHeight
    end
    
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
    trackerBaseFrame:SetResizeBounds(CONFIG.minWidth, CONFIG.minHeight, CONFIG.maxWidth, CONFIG.maxHeight)
    trackerBaseFrame:RegisterForDrag("LeftButton")

    -- Drag handlers for the entire frame (require Control key to drag)
    trackerBaseFrame:SetScript("OnDragStart", function(self)
        if isSizing then
            return
        end
        -- Only allow dragging if Control key is held down
        if not IsControlKeyDown() then
            return  -- Prevent dragging without Control
        end
        self:StartMoving()
    end)

    trackerBaseFrame:SetScript("OnDragStop", function(self)
        if not isSizing then
            self:StopMovingOrSizing()
            -- Save position after dragging stops
            SaveTrackerPosition()
        end
    end)
    
    -- Initialize header
    trackerHeaderFrame = AchievementTracker:InitializeHeader(trackerBaseFrame)

    -- Initialize content frame
    trackerContentFrame = AchievementTracker:InitializeContentFrame(trackerBaseFrame)

    -- Initialize sizer (resize handle)
    trackerSizer = AchievementTracker:InitializeSizer(trackerBaseFrame)
    
    -- Helper function to check if a frame or any of its parents is a tracker frame
    local function isTrackerFrameOrChild(checkFrame)
        if not checkFrame then
            return false
        end
        
        -- Check if it's one of our tracker frames
        if checkFrame == trackerBaseFrame or 
           checkFrame == trackerHeaderFrame or 
           checkFrame == trackerContentFrame or
           checkFrame == trackerSizer then
            return true
        end
        
        -- Recursively check parents (up to UIParent)
        -- Use pcall to safely call GetParent in case the frame doesn't support it
        local success, parent = pcall(function() return checkFrame:GetParent() end)
        if success and parent then
            -- Stop at UIParent to avoid infinite recursion
            if parent == UIParent then
                return false
            end
            -- Continue checking up the parent chain
            return isTrackerFrameOrChild(parent)
        end
        
        return false
    end
    
    -- Fade functions are now module-level, defined above
    
    -- Show sizer when mouse enters tracker frame (matching Questie's OnEnter)
    trackerBaseFrame:SetScript("OnEnter", function(self)
        isMouseOverTracker = true
        UnfadeSizer()
        -- When entering tracker but not over a specific line, make all lines semi-transparent
        if not hoveredLine then
            SetAllLinesAlpha(HOVER_ALPHA)
        end
    end)
    
    trackerBaseFrame:SetScript("OnLeave", function(self)
        isMouseOverTracker = false
        FadeSizer()
        -- Reset all lines to full opacity when mouse leaves tracker
        ResetAllLinesAlpha()
    end)
    
    -- Hook into existing header OnEnter to also show sizer
    local originalHeaderOnEnter = trackerHeaderFrame:GetScript("OnEnter")
    trackerHeaderFrame:SetScript("OnEnter", function(self)
        if originalHeaderOnEnter then originalHeaderOnEnter(self) end
        isMouseOverTracker = true
        UnfadeSizer()
        -- When entering header but not over a specific line, make all lines semi-transparent
        if not hoveredLine then
            SetAllLinesAlpha(HOVER_ALPHA)
        end
    end)
    
    -- Add OnEnter/OnLeave handlers to content frame to show sizer
    trackerContentFrame:SetScript("OnEnter", function(self)
        isMouseOverTracker = true
        UnfadeSizer()
        -- When entering content frame but not over a specific line, make all lines semi-transparent
        if not hoveredLine then
            SetAllLinesAlpha(HOVER_ALPHA)
        end
    end)
    
    trackerContentFrame:SetScript("OnLeave", function(self)
        isMouseOverTracker = false
        FadeSizer()
        -- Reset all lines to full opacity when mouse leaves content frame
        ResetAllLinesAlpha()
    end)
    
    -- Add OnLeave handler to header frame
    local originalHeaderOnLeave = trackerHeaderFrame:GetScript("OnLeave")
    trackerHeaderFrame:SetScript("OnLeave", function(self)
        if originalHeaderOnLeave then originalHeaderOnLeave(self) end
        isMouseOverTracker = false
        FadeSizer()
        -- Reset all lines to full opacity when mouse leaves header (if not moving to another tracker element)
        C_Timer.After(0.05, function()
            if not isMouseOverTracker and not isSizing then
                ResetAllLinesAlpha()
            end
        end)
    end)

    -- Restore saved position from database, or use default center position
    local savedLeft, savedTop = LoadTrackerPosition()
    if savedLeft and savedTop then
        trackerBaseFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedLeft, savedTop)
    else
        trackerBaseFrame:SetPoint("CENTER", UIParent, "CENTER")
    end

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

    -- Pass drag events to parent frame (only when Control is held)
    headerFrame:EnableMouse(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnDragStart", function(self)
        -- Only forward drag if Control is held
        if trackerBaseFrame and IsControlKeyDown() then
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
    
    -- Keep sizer visible when hovering over it (fade in)
    sizer:SetScript("OnEnter", function(self)
        if not isSizing then
            isMouseOverTracker = true
            UnfadeSizer()
        end
    end)
    
    -- Fade out sizer when leaving it (if not over tracker)
    sizer:SetScript("OnLeave", function(self)
        -- Check if mouse is still over tracker before fading
        C_Timer.After(0.05, function()
            if not isMouseOverTracker and not isSizing then
                FadeSizer()
            end
        end)
    end)
    
    -- Resize start handler
    sizer:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not InCombatLockdown() then
            if not ChatEdit_GetActiveWindow() then
                isSizing = true
                baseFrame.isSizing = true
                
                -- Cancel fade ticker during resize
                if fadeTicker then
                    fadeTicker:Cancel()
                    fadeTicker = nil
                end
                
                -- Keep sizer visible during resize (set directly, bypass fade)
                self:SetAlpha(1)
                fadeTickerValue = 0.3  -- Keep at max value for immediate unfade when resize ends
                
                -- Save current backdrop settings
                savedBackdropSettings.enabled = true
                savedBackdropSettings.alpha = 0.8
                
                -- Show backdrop during resize for visual feedback
                trackerBaseFrame:SetBackdropColor(0, 0, 0, 0.8)
                trackerBaseFrame:SetBackdropBorderColor(1, 1, 1, 0.8)
                
                -- Start resizing from bottom-right corner
                baseFrame:StartSizing("BOTTOMRIGHT")
                
                -- Update continuously while resizing (more frequent for responsive word wrap)
                -- SetResizeBounds handles minimum size enforcement automatically
                local updateTimer = C_Timer.NewTicker(0.05, function()
                    if not isSizing or InCombatLockdown() then
                        updateTimer:Cancel()
                        return
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
            
            -- Save dimensions (SetResizeBounds already enforced minimums)
            savedFrameWidth = baseFrame:GetWidth()
            savedFrameHeight = baseFrame:GetHeight()
            
            -- Mark as user-resized (user explicitly set the size)
            userSetWidth = savedFrameWidth
            userSetHeight = savedFrameHeight
            hasBeenResized = true
            
            -- Save size to database
            SaveTrackerSize()
            
            -- Update the tracker
            AchievementTracker:Update()
            
            -- Restore fade behavior after resize (if mouse is still over tracker, fade in; otherwise fade out)
            -- Small delay to check mouse position after resize ends
            C_Timer.After(0.1, function()
                if isMouseOverTracker and not isSizing then
                    UnfadeSizer()
                else
                    FadeSizer()
                end
            end)
            
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

-- Helper function to get achievement description/tooltip from definition (with extended info for dungeons/sets)
local function GetAchievementDescription(achievementId)
    local baseTooltip = nil
    local requiredKills = nil
    local bossOrder = nil
    local requiredItems = nil
    local itemOrder = nil
    local isRaid = false
    local achDef = nil
    
    -- Check if achievement is completed first (needed for secret achievements)
    local achievementCompleted = false
    local getCharDB = _G.HardcoreAchievements_GetCharDB
    if type(getCharDB) == "function" then
        local _, cdb = getCharDB()
        if cdb and cdb.achievements then
            local record = cdb.achievements[tostring(achievementId)]
            if record and record.completed then
                achievementCompleted = true
            end
        end
    end
    
    -- Try to get from global achievement definitions
    local isSecretAchievement = false
    if _G.Achievements then
        for _, rec in ipairs(_G.Achievements) do
            if tostring(rec.achId) == tostring(achievementId) then
                isSecretAchievement = rec.secret == true
                -- For secret achievements that aren't completed, use secretTooltip
                if isSecretAchievement and not achievementCompleted and rec.secretTooltip then
                    baseTooltip = rec.secretTooltip
                else
                    baseTooltip = rec.tooltip
                end
                break
            end
        end
    end
    
    -- Try HCA_AchievementDefs (for dungeon/other achievements)
    if _G.HCA_AchievementDefs and _G.HCA_AchievementDefs[tostring(achievementId)] then
        achDef = _G.HCA_AchievementDefs[tostring(achievementId)]
        if not baseTooltip then
            -- Check if it's a secret achievement and not completed
            if achDef.secret and not achievementCompleted and achDef.secretTooltip then
                baseTooltip = achDef.secretTooltip
            else
                baseTooltip = achDef.tooltip
            end
        end
        if achDef.requiredKills then
            requiredKills = achDef.requiredKills
        end
        if achDef.bossOrder then
            bossOrder = achDef.bossOrder
        end
        if achDef.requiredItems then
            requiredItems = achDef.requiredItems
        end
        if achDef.itemOrder then
            itemOrder = achDef.itemOrder
        end
        if achDef.isRaid then
            isRaid = true
        end
    end
    
    -- Try to get from achievement row if available
    if not baseTooltip and AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if (row.id == achievementId or row.achId == achievementId) then
                -- Check if this is a secret achievement and not completed
                local rowIsSecret = row.isSecretAchievement or (row._def and row._def.secret)
                local rowCompleted = row.completed or achievementCompleted
                if rowIsSecret and not rowCompleted and row.secretTooltip then
                    baseTooltip = row.secretTooltip
                else
                    baseTooltip = row.tooltip or row._tooltip
                end
                if not requiredKills and row.requiredKills then
                    requiredKills = row.requiredKills
                end
                if not requiredItems and row.requiredItems then
                    requiredItems = row.requiredItems
                end
                if not itemOrder and row.itemOrder then
                    itemOrder = row.itemOrder
                end
                if row._def and row._def.isRaid then
                    isRaid = true
                end
                if row._def and row._def.requiredKills and not requiredKills then
                    requiredKills = row._def.requiredKills
                end
                if row._def and row._def.bossOrder and not bossOrder then
                    bossOrder = row._def.bossOrder
                end
                break
            end
        end
    end
    
    -- Check if this is a dungeon/raid achievement (has requiredKills or requiredItems)
    local isDungeonOrRaidAchievement = (requiredKills and next(requiredKills) ~= nil) or (requiredItems and type(requiredItems) == "table" and #requiredItems > 0)
    
    -- For dungeon achievements, we don't need baseTooltip - only return nil if it's not a dungeon achievement and we have no tooltip
    if not baseTooltip and not isDungeonOrRaidAchievement then
        return nil
    end
    
    -- Check row.completed flag as well (immediate status)
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if (row.id == achievementId or row.achId == achievementId) and row.completed then
                achievementCompleted = true
                break
            end
        end
    end
    
    -- Build extended description
    -- For dungeon achievements (with requiredKills), skip the base tooltip and only show boss/item lists
    local description = ""
    
    -- Only include base tooltip if this is NOT a dungeon achievement
    if not isDungeonOrRaidAchievement and baseTooltip then
        description = baseTooltip
    end
    
    -- Add required bosses section if available
    if requiredKills and next(requiredKills) ~= nil then
        -- Only add newline before if there's already content, otherwise start directly with the header
        if description ~= "" then
            description = description .. "\n\n|cff00ff00Required Bosses:|r"
        else
            -- Start directly with header (no extra newlines for dungeon achievements)
            description = "|cff00ff00Required Bosses:|r"
        end
        
        -- Get progress from database
        local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(achievementId)
        local counts = progress and progress.counts or {}
        
        -- Determine which boss name function to use (raid vs dungeon)
        local getBossNameFn = isRaid and _G.HCA_GetRaidBossName or _G.HCA_GetBossName
        
        -- Helper function to process a single boss entry
        local function processBossEntry(npcId, need)
            local done = achievementCompleted
            local bossName = ""
            
            -- Support both single NPC IDs and arrays of NPC IDs
            if type(need) == "table" then
                -- Array of NPC IDs - check if any of them has been killed
                local bossNames = {}
                for _, id in pairs(need) do
                    local current = (counts[id] or counts[tostring(id)] or 0)
                    local name = (getBossNameFn and getBossNameFn(id)) or ("Boss " .. tostring(id))
                    table.insert(bossNames, name)
                    if not done and current >= 1 then
                        done = true
                    end
                end
                -- Use the key as display name for string keys
                if type(npcId) == "string" then
                    bossName = npcId
                else
                    -- For numeric keys, show all names
                    bossName = table.concat(bossNames, " / ")
                end
            else
                -- Single NPC ID
                local idNum = tonumber(npcId) or npcId
                local current = (counts[idNum] or counts[tostring(idNum)] or 0)
                bossName = (getBossNameFn and getBossNameFn(idNum)) or ("Boss " .. tostring(idNum))
                if not done then
                    done = current >= (tonumber(need) or 1)
                end
            end
            
            -- Add boss name with color coding (white for completed, gray for not completed)
            if done then
                description = description .. "\n|cffffffff" .. bossName .. "|r"
            else
                description = description .. "\n|cff808080" .. bossName .. "|r"
            end
        end
        
        -- Use ordered display if provided, otherwise use pairs
        if bossOrder then
            for _, npcId in ipairs(bossOrder) do
                local need = requiredKills[npcId]
                if need then
                    processBossEntry(npcId, need)
                end
            end
        else
            for npcId, need in pairs(requiredKills) do
                processBossEntry(npcId, need)
            end
        end
    end
    
    -- Add required items section if available (for dungeon sets)
    if requiredItems and type(requiredItems) == "table" and #requiredItems > 0 then
        -- Only add newline before if there's already content, otherwise start directly with the header
        if description ~= "" then
            description = description .. "\n\n|cff00ff00Required Items:|r"
        else
            -- Start directly with header (no extra newlines for dungeon set achievements)
            description = "|cff00ff00Required Items:|r"
        end
        
        -- Get progress to check saved itemOwned state (once owned, always owned)
        local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(achievementId)
        local itemOwned = progress and progress.itemOwned or {}
        
        -- Use itemOrder if available, otherwise use requiredItems order
        local itemsToShow = itemOrder or requiredItems
        
        for _, itemId in ipairs(itemsToShow) do
            local itemName, itemLink = GetItemInfo(itemId)
            if not itemName then
                -- Item not cached, use fallback
                itemName = "Item " .. tostring(itemId)
            end
            
            -- Check if item is owned: check saved state first (once owned, always owned), then current inventory
            local owned = false
            if achievementCompleted then
                owned = true
            elseif itemOwned and itemOwned[itemId] then
                -- Item was previously owned (saved state)
                owned = true
            else
                -- Check current inventory
                local count = GetItemCount(itemId, true)
                owned = count > 0
            end
            
            -- Add item name with color coding (white for completed, gray for not completed)
            local displayName = itemName or itemLink or ("Item " .. tostring(itemId))
            if owned then
                description = description .. "\n|cffffffff" .. displayName .. "|r"
            else
                description = description .. "\n|cff808080" .. displayName .. "|r"
            end
        end
    end
    
    return description
end

-- Helper function to get achievement status text and color for tracker display
-- Returns: statusText (string like " (Completed)"), statusColor (hex string like "00FF00")
local function GetAchievementStatus(achievementId)
    if not achievementId then
        return nil, nil
    end
    
    -- Get achievement row if available
    local achievementRow = nil
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if (row.id == achievementId or row.achId == achievementId) then
                achievementRow = row
                break
            end
        end
    end
    
    -- Check completion status - prioritize row.completed flag (set immediately) over database
    local achIdStr = tostring(achievementId)
    local isCompleted = false
    
    -- First check row.completed flag (set immediately when completed)
    if achievementRow and achievementRow.completed then
        isCompleted = true
    else
        -- Fallback to database check
        local getCharDB = _G.HardcoreAchievements_GetCharDB
        if type(getCharDB) == "function" then
            local _, cdb = getCharDB()
            if cdb and cdb.achievements and cdb.achievements[achIdStr] then
                isCompleted = cdb.achievements[achIdStr].completed or false
            end
        end
    end
    
    -- Check failed/outleveled status using the exported function
    local isFailed = false
    if not isCompleted and achievementRow and _G.IsRowOutleveled then
        isFailed = _G.IsRowOutleveled(achievementRow)
    elseif not isCompleted and not achievementRow then
        -- Fallback: check if player is over level when row doesn't exist yet
        local maxLevel = GetAchievementLevel(achievementId)
        if maxLevel and maxLevel > 0 then
            local playerLevel = UnitLevel("player") or 1
            isFailed = playerLevel > maxLevel
        end
    end
    
    if isCompleted then
        return " (Completed)", "FF00FF00"  -- Green
    elseif isFailed then
        return " (Failed)", "FFFF0000"  -- Red
    else
        -- Check for pending turn-in status
        local isPendingTurnIn = false
        if achievementRow and achievementRow.questTracker and (achievementRow.killTracker or achievementRow.requiredKills) then
            -- Achievement requires both kill and quest
            local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(achievementId)
            if progress then
                local hasKill = false
                
                -- Check for required kills
                if achievementRow.requiredKills then
                    local countsSatisfied = true
                    for npcId, need in pairs(achievementRow.requiredKills) do
                        local idNum = tonumber(npcId) or npcId
                        local current = progress.eligibleCounts and (progress.eligibleCounts[idNum] or progress.eligibleCounts[tostring(idNum)]) or (progress.counts and (progress.counts[idNum] or progress.counts[tostring(idNum)])) or 0
                        local required = tonumber(need) or 1
                        if current < required then
                            countsSatisfied = false
                            break
                        end
                    end
                    hasKill = countsSatisfied
                elseif achievementRow.killTracker then
                    -- Single kill achievement
                    hasKill = progress.killed or false
                end
                
                local questNotTurnedIn = not progress.quest
                
                -- Get quest ID to check if quest is in log
                local questID = achievementRow.requiredQuestId
                if not questID and achievementRow._def then
                    questID = achievementRow._def.requiredQuestId or achievementRow._def.REQUIRED_QUEST_ID
                end
                
                -- Check if quest is still in quest log (not abandoned)
                local questInLog = false
                if questID then
                    if GetQuestLogIndexByID then
                        local logIndex = GetQuestLogIndexByID(questID)
                        questInLog = (logIndex and logIndex > 0) or false
                    elseif GetNumQuestLogEntries then
                        local numEntries = GetNumQuestLogEntries()
                        for i = 1, numEntries do
                            local title, level, suggestGroup, isHeader, isCollapsed, isComplete, frequency, questIDFromLog = GetQuestLogTitle(i)
                            if not isHeader and questIDFromLog == questID then
                                questInLog = true
                                break
                            end
                        end
                    end
                end
                
                -- Pending turn-in: kills satisfied, quest not turned in, and quest is still in quest log
                isPendingTurnIn = hasKill and questNotTurnedIn and questInLog
            end
        end
        
        if isPendingTurnIn then
            return " (Pending Turn-In)", HCA_SharedUtils.GetClassColor()
        end
    end
    
    return nil, nil
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
        -- Create as Button to enable clicking on entire line (title + description)
        local line = CreateFrame("Button", "AchievementTracker_Line" .. index, trackerContentFrame)
        line:SetHeight(CONFIG.achievementFontSize + 4)
        line:EnableMouse(true)
        line:RegisterForClicks("LeftButtonUp")
        line:RegisterForDrag("LeftButton")

        -- Collapse/Expand button (icon) - positioned to the left of the title, aligned at top
        local collapseButton = CreateFrame("Button", nil, line)
        collapseButton:SetSize(14, 14)
        collapseButton:SetPoint("TOPLEFT", line, "TOPLEFT", CONFIG.marginLeft + CONFIG.collapseButtonOffset, 1)
        
        -- Title label (with word wrap support) - will be positioned after button
        local label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", line, "TOPLEFT", CONFIG.marginLeft + CONFIG.collapseButtonOffset + 16 + 4, 0)  -- Just to the right of button (offset + 16px button + 4px spacing)
        label:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.achievementFontSize)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetWordWrap(true)
        line.label = label
        collapseButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        collapseButton:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
        collapseButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        collapseButton:SetScript("OnClick", function(self, button)
            -- Stop event propagation so the line's OnClick doesn't fire
            -- In WoW, we don't need explicit StopPropagation, but we can mark it
            local achId = line.achievementId
            if achId then
                local achIdStr = tostring(achId)
                -- Toggle collapsed state
                if collapsedAchievements[achIdStr] then
                    collapsedAchievements[achIdStr] = nil
                else
                    collapsedAchievements[achIdStr] = true
                end
                -- Update the display
                AchievementTracker:Update()
            end
        end)
        -- Make sure button clicks don't trigger line clicks by registering for clicks separately
        collapseButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        -- Add hover handlers to collapse button to trigger sizer fade
        -- Note: The button's hover is handled by the parent line's OnEnter/OnLeave, so we don't need to duplicate opacity logic here
        collapseButton:SetScript("OnEnter", function(self)
            isMouseOverTracker = true
            UnfadeSizer()
            -- The parent line's OnEnter will handle opacity
        end)
        
        collapseButton:SetScript("OnLeave", function(self)
            -- Set flag to false, but delay fade check to allow mouse to move to another tracker element
            isMouseOverTracker = false
            C_Timer.After(0.05, function()
                if not isMouseOverTracker and not isSizing then
                    FadeSizer()
                end
            end)
        end)
        
        line.collapseButton = collapseButton

        -- Description label (below title, with indent)
        local descriptionLabel = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        descriptionLabel:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        descriptionLabel:SetFont("Fonts\\FRIZQT__.TTF", CONFIG.achievementFontSize)
        descriptionLabel:SetJustifyH("LEFT")
        descriptionLabel:SetJustifyV("TOP")
        descriptionLabel:SetWordWrap(true)
        descriptionLabel:SetTextColor(1, 1, 1)
        line.descriptionLabel = descriptionLabel

        -- Track if a drag occurred to prevent click handler from firing after drag
        local wasDragging = false
        
        -- Click handler: Left click = toggle panel, Shift+Click = untrack or link
        -- Skip if the click was on the collapse button
        line:SetScript("OnClick", function(self, button)
            -- Check if the click originated from the collapse button
            -- GetMouseFoci() returns a nested table structure
            -- Structure can be: [1] = frame (when clicking line) or [1][1][0] = frame (when clicking button)
            local mouseFoci = GetMouseFoci()
            local clickedFrame = nil
            
            if mouseFoci and type(mouseFoci) == "table" then
                -- Try to extract the frame from the nested structure
                if mouseFoci[1] then
                    local firstLevel = mouseFoci[1]
                    -- Check if firstLevel is directly a frame (userdata)
                    if type(firstLevel) == "userdata" then
                        clickedFrame = firstLevel
                    elseif type(firstLevel) == "table" then
                        -- Nested structure: check [1][1][0] pattern
                        if firstLevel[1] then
                            local secondLevel = firstLevel[1]
                            if type(secondLevel) == "userdata" then
                                clickedFrame = secondLevel
                            elseif type(secondLevel) == "table" and secondLevel[0] then
                                clickedFrame = secondLevel[0]
                            elseif type(secondLevel) == "table" then
                                -- Search for userdata in the table
                                for k, v in pairs(secondLevel) do
                                    if type(v) == "userdata" then
                                        clickedFrame = v
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Check if the clicked frame is the collapse button or a child of it
            if clickedFrame then
                local checkFrame = clickedFrame
                local depth = 0
                while checkFrame and depth < 10 do  -- Limit depth to prevent infinite loops
                    if checkFrame == collapseButton then
                        -- Click was on collapse button, ignore
                        return
                    end
                    -- Check parent frames
                    local success, parent = pcall(function() return checkFrame:GetParent() end)
                    if success and parent then
                        if parent == collapseButton then
                            -- Click was on a child of collapse button, ignore
                            return
                        end
                        checkFrame = parent
                    else
                        break
                    end
                    depth = depth + 1
                    -- Stop at known parent boundaries
                    if checkFrame == line or checkFrame == trackerContentFrame or checkFrame == trackerBaseFrame or checkFrame == UIParent then
                        break
                    end
                end
            end
            
            if button == "LeftButton" and not InCombatLockdown() and not wasDragging then
                if IsShiftKeyDown() then
                    -- Shift+Click: Check if chat is open, otherwise untrack
                    local editBox = ChatEdit_GetActiveWindow()
                    if editBox and editBox:IsVisible() then
                        -- Chat edit box is active: link achievement
                        local achId = line.achievementId
                        if achId then
                            local bracket = _G.HCA_GetAchievementBracket and _G.HCA_GetAchievementBracket(achId) or string.format("[HCA:(%s)]", tostring(achId))
                            local currentText = editBox:GetText() or ""
                            if currentText == "" then
                                editBox:SetText(bracket)
                            else
                                editBox:SetText(currentText .. " " .. bracket)
                            end
                        end
                    else
                        -- No chat open: Untrack achievement
                        local achId = line.achievementId
                        if achId then
                            AchievementTracker:UntrackAchievement(achId)
                        end
                    end
                else
                    -- Regular Click: Open HardcoreAchievementWindow
                    ShowHardcoreAchievementWindow()
                end
            end
            wasDragging = false  -- Reset flag
        end)
        
        -- Forward drag events to base frame (for Control+drag functionality)
        line:SetScript("OnDragStart", function(self)
            -- Only forward if Control is held (matching base frame behavior)
            if IsControlKeyDown() and trackerBaseFrame then
                wasDragging = true  -- Mark that dragging occurred
                trackerBaseFrame:GetScript("OnDragStart")(trackerBaseFrame)
            end
        end)
        line:SetScript("OnDragStop", function(self)
            if trackerBaseFrame then
                trackerBaseFrame:GetScript("OnDragStop")(trackerBaseFrame)
            end
        end)
        
        -- Add hover handlers to trigger sizer fade and line opacity (matching Questie's behavior)
        line:SetScript("OnEnter", function(self)
            isMouseOverTracker = true
            UnfadeSizer()
            
            -- Set this line to full opacity and all others to semi-transparent
            hoveredLine = self
            for _, otherLine in ipairs(achievementLines) do
                if otherLine and otherLine:IsShown() then
                    if otherLine == self then
                        -- This is the hovered line - full opacity
                        otherLine:SetAlpha(1.0)
                        if otherLine.label then
                            otherLine.label:SetAlpha(1.0)
                        end
                        if otherLine.descriptionLabel then
                            otherLine.descriptionLabel:SetAlpha(1.0)
                        end
                        if otherLine.collapseButton then
                            otherLine.collapseButton:SetAlpha(1.0)
                        end
                    else
                        -- Other lines - semi-transparent
                        otherLine:SetAlpha(HOVER_ALPHA)
                        if otherLine.label then
                            otherLine.label:SetAlpha(HOVER_ALPHA)
                        end
                        if otherLine.descriptionLabel then
                            otherLine.descriptionLabel:SetAlpha(HOVER_ALPHA)
                        end
                        if otherLine.collapseButton then
                            otherLine.collapseButton:SetAlpha(HOVER_ALPHA)
                        end
                    end
                end
            end
        end)
        
        line:SetScript("OnLeave", function(self)
            -- Clear hovered line reference
            if hoveredLine == self then
                hoveredLine = nil
            end
            
            -- Set flag to false, but delay fade check to allow mouse to move to another tracker element
            isMouseOverTracker = false
            C_Timer.After(0.05, function()
                -- Only fade if mouse is still not over tracker (other elements' OnEnter will set it back to true)
                if not isMouseOverTracker and not isSizing then
                    FadeSizer()
                    -- Reset all lines to full opacity when mouse leaves tracker
                    ResetAllLinesAlpha()
                elseif isMouseOverTracker and not hoveredLine then
                    -- Mouse is still over tracker but not over a specific line - make all semi-transparent
                    SetAllLinesAlpha(HOVER_ALPHA)
                end
            end)
        end)

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
        trackerHeaderFrame.label:SetText("|CFFFFD100Achievement Tracker: " .. numTracked .. "/10|r")
    else
        trackerHeaderFrame.label:SetText("|CFFFFD100Achievement Tracker +|r")
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

    -- Show/hide sizer based on expanded state (alpha controlled by fade ticker)
    if isExpanded and numTracked > 0 then
        if not trackerSizer:IsVisible() then
            trackerSizer:Show()
        end
        -- If mouse is over tracker, fade in; otherwise fade out
        if isMouseOverTracker and not isSizing then
            UnfadeSizer()
        elseif not isMouseOverTracker and not isSizing then
            FadeSizer()
        end
    else
        trackerSizer:Hide()
        trackerSizer:SetAlpha(0)  -- Reset alpha when hidden
        -- Cancel fade ticker when tracker is collapsed
        if fadeTicker then
            fadeTicker:Cancel()
            fadeTicker = nil
            fadeTickerValue = 0
        end
    end

    -- Set base frame width BEFORE updating content (so content uses correct width for wrapping)
    -- Height will be calculated after content is rendered
    if not isSizing then
        if isExpanded and numTracked > 0 then
            -- Set width first (user-set or auto-calculated, but use saved as fallback)
            if userSetWidth and userSetWidth >= CONFIG.minWidth then
                trackerBaseFrame:SetWidth(userSetWidth)
            elseif savedFrameWidth and savedFrameWidth >= CONFIG.minWidth then
                trackerBaseFrame:SetWidth(savedFrameWidth)
            else
                trackerBaseFrame:SetWidth(initialWidth)
            end
            -- Don't set height yet - it will be calculated after content is rendered
        end
    end

    -- Track line index at function scope so it's accessible in sizing logic
    local lineIndex = 0
    
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
        lineIndex = 0  -- Reset for this update
        
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
                
                -- Store achievement ID on the line for click handler
                line.achievementId = achievementId
                
                -- Get achievement level and format title with level prefix
                local achievementLevel = GetAchievementLevel(achievementId)
                local displayTitle = achieveName
                if achievementLevel then
                    displayTitle = "[" .. achievementLevel .. "] " .. achieveName
                end
                
                -- Get achievement status (Completed, Failed, Pending Turn-In)
                local statusText, statusColor = GetAchievementStatus(achievementId)
                if statusText then
                    displayTitle = displayTitle .. statusColor .. statusText .. "|r"
                end
                
                -- Set title with color coding based on player level vs required level
                local titleColor = GetTitleColor(achievementLevel)
                line.label:SetText("|cff" .. titleColor .. displayTitle .. "|r")
                
                -- Get and set description (gray color)
                local description = GetAchievementDescription(achievementId)
                
                -- Check if this achievement is collapsed
                local achIdStr = tostring(achievementId)
                local isCollapsed = collapsedAchievements[achIdStr] == true
                
                -- Show/hide collapse button based on whether there's a description
                local hasDescription = description and description ~= ""
                if line.collapseButton then
                    if hasDescription then
                        -- Update collapse button icon based on state
                        if isCollapsed then
                            line.collapseButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                            line.collapseButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
                        else
                            line.collapseButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                            line.collapseButton:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
                        end
                        -- Re-anchor button to align with title (in case title height changed)
                        line.collapseButton:ClearAllPoints()
                        line.collapseButton:SetPoint("TOPLEFT", line, "TOPLEFT", CONFIG.marginLeft + CONFIG.collapseButtonOffset, 1)
                        line.collapseButton:Show()
                    else
                        -- No description, hide the button
                        line.collapseButton:Hide()
                    end
                end
                
                -- Calculate available width (account for icon space only if button is visible)
                local iconSpace = hasDescription and 20 or 0  -- 16px icon + 4px spacing
                local availableWidth = (trackerContentFrame:GetWidth() or initialWidth) - CONFIG.marginLeft - CONFIG.marginRight - iconSpace
                
                -- Set title width FIRST to allow wrapping (availableWidth already accounts for icon space)
                -- This must be done before calculating heights so text wraps correctly
                line.label:SetWidth(availableWidth)
                
                -- Only show description if not collapsed and description exists
                if not isCollapsed and hasDescription then
                    -- Check if this is a dungeon achievement (starts directly with "Required Bosses:" or "Required Items:")
                    -- Strip color codes temporarily to check the pattern
                    local cleanDesc = description:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    local isDungeonDesc = cleanDesc:match("^Required Bosses:") or cleanDesc:match("^Required Items:")
                    
                    -- Keep color codes for extended tooltips (boss/item lists with completion status)
                    -- Reposition description label with indent (12px from title start)
                    line.descriptionLabel:ClearAllPoints()
                    -- Use minimal spacing for dungeon achievements (no base tooltip, description starts immediately)
                    -- For regular achievements, use normal spacing after base tooltip
                    local verticalOffset = isDungeonDesc and 0 or -2
                    line.descriptionLabel:SetPoint("TOPLEFT", line.label, "BOTTOMLEFT", 12, verticalOffset)
                    line.descriptionLabel:SetWidth(availableWidth - 12)  -- Account for indent
                    line.descriptionLabel:SetText(description)
                    line.descriptionLabel:Show()
                    -- Calculate total height needed (title + spacing + description)
                    -- Use GetStringHeight for both to ensure accurate calculations with current widths
                    local titleHeight = line.label:GetStringHeight() or line.label:GetHeight()
                    local descriptionHeight = line.descriptionLabel:GetStringHeight()
                    -- Use minimal spacing for dungeon achievements (description starts right after title)
                    local spacing = isDungeonDesc and 0 or 4
                    line:SetHeight(titleHeight + descriptionHeight + spacing)
                else
                    -- Collapsed or no description - hide description and set height to title only
                    line.descriptionLabel:Hide()
                    -- Use GetStringHeight after width is set for accurate height calculation
                    local titleHeight = line.label:GetStringHeight() or line.label:GetHeight()
                    line:SetHeight(titleHeight)
                end
                
                -- Set line width to match content frame width
                line:SetWidth(baseFrameWidth)
                
                -- Track the widest content for auto-sizing (only if not manually resized)
                -- Use GetStringWidth which respects wrapping
                if not isSizing then
                    local titleWidth = line.label:GetStringWidth() or line.label:GetUnboundedStringWidth()
                    local descWidth = hasDescription and (line.descriptionLabel:GetStringWidth() or (line.descriptionLabel:GetUnboundedStringWidth() + 12)) or 0
                    -- Account for icon space when button is visible
                    local contentWidth = math.max(titleWidth, descWidth) + CONFIG.marginLeft + CONFIG.marginRight + iconSpace
                    maxWidth = math.max(maxWidth, contentWidth)
                end

                if previousLine then
                    line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -CONFIG.paddingBetweenAchievements)
                else
                    line:SetPoint("TOPLEFT", trackerContentFrame, "TOPLEFT", 0, 0)
                end

                -- Reset line alpha to full opacity on update (hover state will be restored by OnEnter handlers)
                line:SetAlpha(1.0)
                if line.label then
                    line.label:SetAlpha(1.0)
                end
                if line.descriptionLabel then
                    line.descriptionLabel:SetAlpha(1.0)
                end
                if line.collapseButton then
                    line.collapseButton:SetAlpha(1.0)
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

        -- Set content frame to a large temporary height for layout (will be recalculated later)
        if lineIndex > 0 then
            trackerContentFrame:SetHeight(1000)  -- Temporary large height for layout
        else
            trackerContentFrame:SetHeight(50)
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
    
    -- Track the maximum line index (for use in sizing logic to hide overflow lines)
    -- Use lineIndex from the content update above
    local maxLineIndex = lineIndex

    if not isSizing then
        -- Save current top-left corner position before resizing to prevent frame from moving
        local topLeftX = trackerBaseFrame:GetLeft()
        local topLeftY = trackerBaseFrame:GetTop()

        if isExpanded and numTracked > 0 then
            -- Calculate required dimensions from content
            local contentWidth = trackerContentFrame:GetWidth() or initialWidth
            
            -- Calculate content height by accumulating all visible line heights
            -- This is more reliable than GetTop/GetBottom which may not work until frames are fully laid out
            local contentHeight = 50  -- Default minimum
            if lineIndex > 0 then
                local accumulatedHeight = 0
                for i = 1, lineIndex do
                    local line = achievementLines[i]
                    if line and line:IsShown() then
                        -- Get the actual height of the line (after all content is set)
                        local lineHeight = line:GetHeight()
                        if lineHeight and lineHeight > 0 then
                            accumulatedHeight = accumulatedHeight + lineHeight
                            -- Add padding between achievements (except after the last one)
                            if i < lineIndex then
                                accumulatedHeight = accumulatedHeight + CONFIG.paddingBetweenAchievements
                            end
                        end
                    end
                end
                -- Add 3 pixels for text that extends beyond GetStringHeight() (like Questie does)
                contentHeight = math.max(accumulatedHeight + 3, 50)
                
                -- Try to verify with GetTop/GetBottom if available (as secondary check)
                local firstLine = achievementLines[1]
                local currentLine = achievementLines[lineIndex]
                if firstLine and currentLine and firstLine:IsShown() and currentLine:IsShown() then
                    local firstLineTop = firstLine:GetTop()
                    local currentLineBottom = currentLine:GetBottom()
                    if firstLineTop and currentLineBottom and firstLineTop > currentLineBottom then
                        -- Use GetTop/GetBottom if it's available and reasonable (within 20px of accumulated)
                        local pixelHeight = firstLineTop - currentLineBottom + 3
                        -- Use whichever is larger to ensure content isn't cut off
                        contentHeight = math.max(contentHeight, pixelHeight, 50)
                    end
                end
            end
            
            -- Update content frame height to match calculated height (like Questie sets ScrollChildFrame height)
            trackerContentFrame:SetHeight(contentHeight)
            
            -- Calculate minimum width needed (header or content, whichever is wider)
            local calculatedWidth = math.max(headerWidth, contentWidth, initialWidth)
            calculatedWidth = math.max(calculatedWidth, CONFIG.minWidth)
            
            -- Calculate minimum height needed (header + content + padding)
            -- Match Questie's approach: baseFrame = questFrame + header + 20 (QuestieTracker.lua line 1922)
            local calculatedHeight = headerHeight + contentHeight + 20
            calculatedHeight = math.max(calculatedHeight, initialHeight, CONFIG.minHeight)
            
            -- Width logic: Use user-set width if available, otherwise auto-expand to fit content
            if userSetWidth and userSetWidth >= CONFIG.minWidth then
                -- User has manually set width - respect it
                trackerBaseFrame:SetWidth(userSetWidth)
            else
                -- Auto-size width to fit content (but don't exceed maxWidth)
                local finalWidth = math.min(calculatedWidth, CONFIG.maxWidth or 9999)
                trackerBaseFrame:SetWidth(finalWidth)
                savedFrameWidth = finalWidth  -- Save calculated width
            end
            
            -- Height logic: Always auto-expand to fit content unless user is currently resizing
            -- Match Questie's approach: baseFrame = questFrame + header + 20 (QuestieTracker.lua line 1922)
            local finalHeight = math.min(calculatedHeight, CONFIG.maxHeight or 9999)
            trackerBaseFrame:SetHeight(finalHeight)
            
            -- Update content frame height to match calculated height
            -- If we hit maxHeight, clamp content and hide overflow lines
            if calculatedHeight > (CONFIG.maxHeight or 9999) then
                local maxContentHeight = finalHeight - headerHeight - 20
                if contentHeight > maxContentHeight then
                    trackerContentFrame:SetHeight(maxContentHeight)
                    -- Hide lines that would be cut off
                    if maxLineIndex > 0 then
                        for i = 1, maxLineIndex do
                            if achievementLines[i] and achievementLines[i]:IsShown() then
                                local lineBottom = achievementLines[i]:GetBottom()
                                local contentTop = trackerContentFrame:GetTop() or 0
                                if lineBottom and contentTop and lineBottom < (contentTop - maxContentHeight) then
                                    achievementLines[i]:Hide()
                                end
                            end
                        end
                    end
                else
                    trackerContentFrame:SetHeight(contentHeight)
                end
            else
                -- Content fits within maxHeight, set content frame to actual calculated height
                trackerContentFrame:SetHeight(contentHeight)
            end
            
            -- Save calculated height for next time (but only if not manually resizing)
            -- This ensures auto-sizing continues to work when achievements are added/removed
            if not isSizing then
                savedFrameHeight = finalHeight
            end
        else
            -- Save width and height before collapsing (but don't override user-set dimensions)
            local currentWidth = trackerBaseFrame:GetWidth()
            local currentHeight = trackerBaseFrame:GetHeight()
            if currentWidth and currentWidth >= CONFIG.minWidth and not userSetWidth then
                savedFrameWidth = currentWidth
            end
            if currentHeight and currentHeight >= CONFIG.minHeight and not userSetHeight then
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
    
    -- SetResizeBounds handles minimum size enforcement for user resizing
    -- We still enforce minimums when programmatically setting sizes above

    -- Show/hide base frame
    -- Hide if there are no tracked achievements, regardless of expanded state
    if numTracked == 0 then
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
        print("|cff008066[Hardcore Achievements]|r You may only track 10 achievements at a time.")
        return
    end

    -- Store achievement data (title for custom achievements)
    if title then
        trackedAchievements[achievementId] = { title = title }
    else
        trackedAchievements[achievementId] = true
    end
    
    -- Save to database
    SaveTrackedAchievements()
    
    AchievementTracker:Update()
end

-- Public API: Remove achievement from tracker
function AchievementTracker:UntrackAchievement(achievementId)
    if trackedAchievements[achievementId] then
        trackedAchievements[achievementId] = nil
        -- Save to database
        SaveTrackedAchievements()
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

-- Hook into achievement refresh functions to update tracker status
local function HookAchievementRefresh()
    -- Store original function
    local originalMarkCompleted = _G.HCA_MarkRowCompleted
    
    -- Hook into HCA_MarkRowCompleted to update tracker when achievement is completed
    if originalMarkCompleted then
        _G.HCA_MarkRowCompleted = function(row, ...)
            local result = originalMarkCompleted(row, ...)
            
            if row then
                -- Get achievement ID from row
                local achId = row.achId or row.id
                
                -- Update tracker when any achievement is completed
                if achId and AchievementTracker and AchievementTracker.Update then
                    -- Update tracker immediately (row.completed is set synchronously)
                    AchievementTracker:Update()
                    -- Schedule another update after a delay to ensure database is updated
                    C_Timer.After(0.3, function()
                        if AchievementTracker and AchievementTracker.Update then
                            AchievementTracker:Update()
                        end
                    end)
                end
            end
            
            return result
        end
    end
    
    -- Hook into HardcoreAchievements_SetProgress to update tracker when progress changes
    -- This will catch boss kills (counts updates) and item collection (itemOwned updates)
    local originalSetProgress = _G.HardcoreAchievements_SetProgress
    if originalSetProgress then
        -- Debounce tracker updates to avoid excessive updates during rapid progress changes
        local updateTimer = nil
        local pendingUpdates = {}
        
        _G.HardcoreAchievements_SetProgress = function(achId, key, value)
            -- Call original function first
            local result = originalSetProgress(achId, key, value)
            
            -- Check if this achievement is tracked and if the progress change affects display
            if achId and (key == "counts" or key == "itemOwned") then
                local achIdStr = tostring(achId)
                local achIdNum = tonumber(achIdStr)
                
                -- Check if this achievement is tracked (handle both string and numeric keys)
                local isTracked = trackedAchievements[achIdStr] ~= nil or (achIdNum and trackedAchievements[achIdNum] ~= nil)
                
                if isTracked then
                    -- Mark this achievement for update
                    pendingUpdates[achIdStr] = true
                    
                    -- Cancel existing timer if any
                    if updateTimer then
                        updateTimer:Cancel()
                        updateTimer = nil
                    end
                    
                    -- Schedule update after a short delay to batch multiple rapid changes
                    updateTimer = C_Timer.NewTimer(0.2, function()
                        updateTimer = nil
                        if AchievementTracker and AchievementTracker.Update and next(pendingUpdates) ~= nil then
                            -- Clear pending updates and update tracker
                            local updates = pendingUpdates
                            pendingUpdates = {}
                            
                            -- Update tracker, retrying if in combat
                            local function TryUpdate()
                                if AchievementTracker and AchievementTracker.Update then
                                    if InCombatLockdown() then
                                        -- Still in combat, retry after a short delay
                                        C_Timer.After(0.5, TryUpdate)
                                    else
                                        -- Out of combat, update now to refresh boss colors
                                        AchievementTracker:Update()
                                    end
                                end
                            end
                            TryUpdate()
                        end
                    end)
                end
            end
            
            return result
        end
    end
end

-- Set up hooks after a short delay to ensure all functions are loaded
C_Timer.After(1.0, HookAchievementRefresh)

-- Restore tracked achievements on login/reload
-- Wait for achievement registrations to complete before restoring
local function RestoreOnLogin()
    -- Check if registration is still in progress
    if _G.HCA_RegistrationQueue and #_G.HCA_RegistrationQueue > 0 then
        -- Registration still in progress, wait a bit and retry
        C_Timer.After(0.5, RestoreOnLogin)
        return
    end
    
    if AchievementTracker and AchievementTracker.Initialize then
        -- Ensure tracker is initialized first
        if not isInitialized then
            AchievementTracker:Initialize()
        end
        -- Restore tracked achievements (this will also show the tracker if there are tracked achievements)
        RestoreTrackedAchievements()
    end
end

-- Register for PLAYER_LOGIN event to restore tracked achievements
-- Also register for PLAYER_LEVEL_UP to refresh title colors when player levels up
local restoreFrame = CreateFrame("Frame")
restoreFrame:RegisterEvent("PLAYER_LOGIN")
restoreFrame:RegisterEvent("PLAYER_LEVEL_UP")
restoreFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Wait a moment for registration to start, then check and restore
        C_Timer.After(0.1, RestoreOnLogin)
    elseif event == "PLAYER_LEVEL_UP" then
        -- Refresh tracker to update title colors based on new player level
        if AchievementTracker and AchievementTracker.Update then
            AchievementTracker:Update()
        end
    end
end)

return AchievementTracker
