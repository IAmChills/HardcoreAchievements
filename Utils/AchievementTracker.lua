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
local hideSizerTimer = nil  -- Timer for delayed sizer hiding

-- Helper functions to save/load tracker position and size from database
local function SaveTrackerPosition()
    if not trackerBaseFrame then return end
    
    -- Ensure database exists
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    HardcoreAchievementsDB.tracker = HardcoreAchievementsDB.tracker or {}
    
    -- Get current position (save as left/top coordinates relative to screen)
    local left = trackerBaseFrame:GetLeft()
    local top = trackerBaseFrame:GetTop()
    
    if left and top then
        HardcoreAchievementsDB.tracker.left = left
        HardcoreAchievementsDB.tracker.top = top
    end
end

local function LoadTrackerPosition()
    if not HardcoreAchievementsDB or not HardcoreAchievementsDB.tracker then
        return nil, nil
    end
    
    local trackerData = HardcoreAchievementsDB.tracker
    if trackerData.left and trackerData.top then
        return trackerData.left, trackerData.top
    end
    
    return nil, nil
end

local function SaveTrackerSize()
    if not trackerBaseFrame then return end
    
    -- Ensure database exists
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    HardcoreAchievementsDB.tracker = HardcoreAchievementsDB.tracker or {}
    
    -- Save current size
    local width = trackerBaseFrame:GetWidth()
    local height = trackerBaseFrame:GetHeight()
    
    if width and width >= CONFIG.minWidth then
        HardcoreAchievementsDB.tracker.width = width
    end
    if height and height >= CONFIG.minHeight then
        HardcoreAchievementsDB.tracker.height = height
    end
end

local function LoadTrackerSize()
    if not HardcoreAchievementsDB or not HardcoreAchievementsDB.tracker then
        return nil, nil
    end
    
    local trackerData = HardcoreAchievementsDB.tracker
    local width = trackerData.width
    local height = trackerData.height
    
    -- Validate sizes are within bounds
    if width and width >= CONFIG.minWidth and width <= (CONFIG.maxWidth or 9999) then
        if height and height >= CONFIG.minHeight and height <= (CONFIG.maxHeight or 9999) then
            return width, height
        end
    end
    
    return nil, nil
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
    local savedWidth, savedHeight = LoadTrackerSize()
    if savedWidth and savedHeight then
        trackerBaseFrame:SetSize(savedWidth, savedHeight)
        savedFrameWidth = savedWidth
        savedFrameHeight = savedHeight
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
    
    -- Helper function to show sizer on hover (defined after sizer is created)
    local function ShowSizerOnHover()
        isMouseOverTracker = true
        
        -- Cancel any pending hide timer
        if hideSizerTimer then
            hideSizerTimer:Cancel()
            hideSizerTimer = nil
        end
        
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
    
    -- Shared function to check if mouse is over tracker and hide sizer if not
    local function CheckMouseAndHideSizer()
        if isSizing then
            return  -- Don't hide during resize
        end
        
        -- Check if mouse is over any tracker-related frame using GetMouseFoci()
        local mouseFoci = GetMouseFoci()
        local isOverTracker = false
        
        if mouseFoci then
            -- GetMouseFoci() returns a table where each entry may be the frame directly or a table containing the frame
            for i = 1, #mouseFoci do
                local entry = mouseFoci[i]
                if entry then
                    -- Get the frame - it might be the entry directly, or at entry[0]
                    local frame = nil
                    if type(entry) == "table" and entry[0] then
                        -- Frame is stored at index [0] within the entry table
                        frame = entry[0]
                    else
                        -- Entry is the frame directly (userdata)
                        frame = entry
                    end
                    
                    if frame then
                        -- Check if this frame or any parent is a tracker frame
                        if isTrackerFrameOrChild(frame) then
                            isOverTracker = true
                            break
                        end
                    end
                end
            end
        end
        
        -- Only hide if mouse is not over any part of the tracker
        if not isOverTracker then
            HideSizerOnLeave()
        else
            -- Mouse is still over tracker, keep sizer visible
            if trackerSizer and trackerSizer:IsVisible() and not isSizing then
                trackerSizer:SetAlpha(0.8)
            end
        end
    end
    
    -- Schedule delayed hide check with cancellation support
    local function ScheduleHideCheck()
        -- Cancel any existing timer
        if hideSizerTimer then
            hideSizerTimer:Cancel()
            hideSizerTimer = nil
        end
        
        -- Schedule new check with slightly longer delay to reduce flickering
        hideSizerTimer = C_Timer.NewTicker(0.15, function(timer)
            timer:Cancel()
            hideSizerTimer = nil
            CheckMouseAndHideSizer()
        end, 1)  -- Only run once
    end
    
    -- Show sizer when mouse enters tracker frame
    trackerBaseFrame:SetScript("OnEnter", function(self)
        ShowSizerOnHover()
    end)
    trackerBaseFrame:SetScript("OnLeave", function(self)
        -- Schedule delayed check to avoid hiding when moving between child frames
        ScheduleHideCheck()
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
        -- Schedule delayed check to avoid hiding when moving between child frames
        ScheduleHideCheck()
    end)
    
    -- Add OnLeave handler to header frame
    local originalHeaderOnLeave = trackerHeaderFrame:GetScript("OnLeave")
    trackerHeaderFrame:SetScript("OnLeave", function(self)
        if originalHeaderOnLeave then originalHeaderOnLeave(self) end
        -- Schedule delayed check to avoid hiding when moving between child frames
        ScheduleHideCheck()
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
            
            -- Save size to database
            SaveTrackerSize()
            
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
            return " (Pending Turn-In)", select(4, GetClassColor(select(2, UnitClass("player"))))
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
                
                -- Get achievement status (Completed, Failed, Pending Turn-In)
                local statusText, statusColor = GetAchievementStatus(achievementId)
                if statusText then
                    displayTitle = displayTitle .. "|c" .. statusColor .. statusText .. "|r"
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
end

-- Set up hooks after a short delay to ensure all functions are loaded
C_Timer.After(1.0, HookAchievementRefresh)

return AchievementTracker
