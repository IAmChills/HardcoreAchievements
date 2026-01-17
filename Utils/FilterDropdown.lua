-- FilterDropdown.lua
-- Shared filter dropdown implementation for both Character Panel and Embed UI
-- Contains all filter-related logic including checkbox state management

local FilterDropdown = {}

-- =========================================================
-- Checkbox Filter Logic (Core Business Logic)
-- =========================================================

-- Get status filter states (completed, available, failed) from database with proper defaults
function FilterDropdown.GetStatusFilterStates()
    local statusFilters = { true, true, true }  -- completed, available, failed (all default to true)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.statusFilters then
            local states = cdb.settings.statusFilters
            if type(states) == "table" then
                statusFilters = {
                    states[1] ~= false,  -- Completed (default true)
                    states[2] ~= false,  -- Available (default true)
                    states[3] ~= false,  -- Failed (default true)
                }
            end
        end
    end
    return statusFilters
end

-- Save status filter states to character database
function FilterDropdown.SaveStatusFilterStates(statusFilters)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings.statusFilters = {
                statusFilters[1] == true,  -- Completed
                statusFilters[2] == true,  -- Available
                statusFilters[3] == true,  -- Failed
            }
        end
    end
end

-- Get checkbox states from database with proper defaults
function FilterDropdown.GetCheckboxStates()
    local checkboxStates = { true, true, true, true, true, true, false, false, false, false, false, false, false, false }
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.filterCheckboxes then
            local states = cdb.settings.filterCheckboxes
            if type(states) == "table" then
                checkboxStates = {
                    states[1] ~= false,  -- Quest (default true)
                    states[2] ~= false,  -- Dungeon (default true)
                    states[3] ~= false,  -- Heroic Dungeon (default true)
                    states[4] ~= false,  -- Raid (default true)
                    states[5] ~= false,  -- Professions (default true)
                    states[6] ~= false,  -- Meta (default true)
                    states[7] == true,  -- Reputations
                    states[8] == true,  -- Exploration
                    states[9] == true,  -- Dungeon Sets
                    states[10] == true,  -- Solo
                    states[11] == true,  -- Duo
                    states[12] == true,  -- Trio
                    states[13] == true,  -- Ridiculous
                    states[14] == true,  -- Secret
                }
            end
        end
    end
    return checkboxStates
end

-- Save checkbox states to character database
function FilterDropdown.SaveCheckboxStates(checkboxStates)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings.filterCheckboxes = {
                checkboxStates[1] == true,  -- Quest
                checkboxStates[2] == true,  -- Dungeon
                checkboxStates[3] == true,  -- Heroic Dungeon
                checkboxStates[4] == true,  -- Raid
                checkboxStates[5] == true,  -- Professions
                checkboxStates[6] == true,  -- Meta
                checkboxStates[7] == true,  -- Reputations
                checkboxStates[8] == true,  -- Exploration
                checkboxStates[9] == true,  -- Dungeon Sets
                checkboxStates[10] == true,  -- Solo
                checkboxStates[11] == true,  -- Duo
                checkboxStates[12] == true,  -- Trio
                checkboxStates[13] == true,  -- Ridiculous
                checkboxStates[14] == true,  -- Secret
            }
        end
    end
end

-- Check if achievement should be shown based on checkbox filter
-- Returns true if should show, false if should hide
function FilterDropdown.ShouldShowByCheckboxFilter(def, isCompleted, checkboxIndex, variationType)
    local checkboxStates = FilterDropdown.GetCheckboxStates()
    
    -- For variations, check based on variation type
    if variationType then
        if variationType == "Trio" then
            return checkboxStates[12]
        elseif variationType == "Duo" then
            return checkboxStates[11]
        elseif variationType == "Solo" then
            return checkboxStates[10]
        end
        return false
    end
    
    -- For other types, check the specified checkbox index
    if checkboxIndex then
        return checkboxStates[checkboxIndex]
    end
    
    return true -- Default to showing if no checkbox specified
end

-- =========================================================
-- UI Helper Functions
-- =========================================================

-- Helper function to get checkbox states from database (internal use)
local function GetCheckboxStatesFromDB()
    return FilterDropdown.GetCheckboxStates()
end

-- Helper function to save checkbox states to database (internal use)
local function SaveCheckboxStatesToDB(checkboxStates)
    FilterDropdown.SaveCheckboxStates(checkboxStates)
end

-- Default filter list (no longer used - status filters are now checkboxes)
local function GetDefaultFilterList()
    return {}
end

-- Helper function to get player class color
local function GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end
    return 1, 1, 1  -- Default to white if no class color found
end

-- Create and style the dropdown frame
function FilterDropdown:CreateDropdown(parent, anchorPoint, anchorTo, xOffset, yOffset, width)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    
    -- Apply custom styling (hide default textures, add custom background)
    dropdown.Left:Hide()
    dropdown.Middle:Hide()
    dropdown.Right:Hide()
    
    local bg = dropdown:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -4, 0)
    bg:SetPoint("BOTTOMRIGHT", -17, 9)
    bg:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dropdown.png")
    
    -- Position the dropdown
    dropdown:SetPoint(anchorPoint or "TOPRIGHT", anchorTo or parent, anchorPoint or "TOPRIGHT", xOffset or -17, yOffset or -50)
    UIDropDownMenu_SetWidth(dropdown, width or 85)
    UIDropDownMenu_SetText(dropdown, "Filters")
    
    -- Style the button with custom arrow
    local button = dropdown.Button
    button:ClearAllPoints()
    button:SetPoint("RIGHT", dropdown, "RIGHT", -16, 4)
    button:SetNormalTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dropdown_arrow_down.png")
    button:SetPushedTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dropdown_arrow_down.png")
    button:SetDisabledTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dropdown_arrow_down.png")
    
    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local disabledTexture = button:GetDisabledTexture()
    
    local arrowR, arrowG, arrowB = GetPlayerClassColor()
    
    for _, tex in ipairs({ normalTexture, pushedTexture, disabledTexture }) do
        if tex then
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", button, "CENTER", 0, 0)
            tex:SetSize(20, 20)
            tex:SetVertexColor(arrowR, arrowG, arrowB)
        end
    end
    
    return dropdown
end

-- Initialize dropdown menu with filters, separator, and checkboxes
function FilterDropdown:InitializeDropdown(dropdown, config)
    config = config or {}
    
    -- Get callbacks and state
    local onFilterChange = config.onFilterChange or function() end
    local onCheckboxChange = config.onCheckboxChange or function() end
    local onStatusFilterChange = config.onStatusFilterChange or function() end
    -- Load checkbox states from database if not provided in config
    local checkboxStates = config.checkboxStates
    if not checkboxStates then
        checkboxStates = GetCheckboxStatesFromDB()
    end
    -- Load status filter states from database if not provided in config
    local statusFilters = config.statusFilters
    if not statusFilters then
        statusFilters = FilterDropdown.GetStatusFilterStates()
    end
    local checkboxLabels = config.checkboxLabels or { "Show Dungeon Trios", "Show Dungeon Duos", "Show Dungeon Solos" }
    local filterList = config.filterList or GetDefaultFilterList()
    
    -- Store state on the dropdown for access in callbacks
    dropdown._checkboxStates = checkboxStates  -- Initial state, will be reloaded from DB on each open
    dropdown._statusFilters = statusFilters  -- Initial state, will be reloaded from DB on each open
    dropdown._onFilterChange = onFilterChange
    dropdown._onCheckboxChange = onCheckboxChange
    dropdown._onStatusFilterChange = onStatusFilterChange
    dropdown._checkboxLabels = checkboxLabels
    dropdown._filterList = filterList
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level == 1 then
            -- Reload checkbox states from database each time dropdown opens (for sync between frames)
            dropdown._checkboxStates = GetCheckboxStatesFromDB()
            -- Reload status filter states from database each time dropdown opens
            dropdown._statusFilters = FilterDropdown.GetStatusFilterStates()
            
            -- Add "Filter By" section title
            local filterByTitleInfo = UIDropDownMenu_CreateInfo()
            filterByTitleInfo.text = "Filter By"
            filterByTitleInfo.isTitle = true
            filterByTitleInfo.isUninteractable = true
            filterByTitleInfo.notCheckable = true
            filterByTitleInfo.disabled = true
            UIDropDownMenu_AddButton(filterByTitleInfo)
            
            -- Add status filter checkboxes (Completed, Available, Failed)
            local statusFilterLabels = { "Completed", "Available", "Failed" }
            for i = 1, 3 do
                local info = UIDropDownMenu_CreateInfo()
                local statusIndex = i  -- Capture index in local variable
                info.text = statusFilterLabels[statusIndex]
                info.checked = dropdown._statusFilters[statusIndex]
                info.isNotRadio = true
                info.keepShownOnClick = true
                info.func = function(self)
                    -- Toggle the state
                    dropdown._statusFilters[statusIndex] = not dropdown._statusFilters[statusIndex]
                    local newState = dropdown._statusFilters[statusIndex]
                    
                    -- Update the button's checked property
                    self.checked = newState
                    
                    -- Manually toggle the checkmark textures for immediate visual feedback
                    local buttonName = self:GetName()
                    local checkTexture = _G[buttonName .. "Check"]
                    local uncheckTexture = _G[buttonName .. "UnCheck"]
                    if checkTexture and uncheckTexture then
                        if newState then
                            checkTexture:Show()
                            uncheckTexture:Hide()
                        else
                            checkTexture:Hide()
                            uncheckTexture:Show()
                        end
                    end
                    
                    -- Save to database
                    FilterDropdown.SaveStatusFilterStates(dropdown._statusFilters)
                    
                    -- Call the callback
                    if dropdown._onStatusFilterChange then
                        dropdown._onStatusFilterChange(statusIndex, newState)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
            
            -- Add separator
            local separatorInfo = UIDropDownMenu_CreateInfo()
            separatorInfo.hasArrow = false
            separatorInfo.dist = 0
            separatorInfo.isTitle = true
            separatorInfo.isUninteractable = true
            separatorInfo.notCheckable = true
            separatorInfo.iconOnly = true
            separatorInfo.icon = "Interface\\Common\\UI-TooltipDivider-Transparent"
            separatorInfo.tCoordLeft = 0
            separatorInfo.tCoordRight = 1
            separatorInfo.tCoordTop = 0
            separatorInfo.tCoordBottom = 1
            separatorInfo.tSizeX = 0
            separatorInfo.tSizeY = 8
            separatorInfo.tFitDropDownSizeX = true
            separatorInfo.iconInfo = {
                tCoordLeft = 0,
                tCoordRight = 1,
                tCoordTop = 0,
                tCoordBottom = 1,
                tSizeX = 0,
                tSizeY = 8,
                tFitDropDownSizeX = true
            }
            UIDropDownMenu_AddButton(separatorInfo)
            
            -- Add "Core Achievements" section title
            local coreTitleInfo = UIDropDownMenu_CreateInfo()
            coreTitleInfo.text = "Core Achievements"
            coreTitleInfo.isTitle = true
            coreTitleInfo.isUninteractable = true
            coreTitleInfo.notCheckable = true
            coreTitleInfo.disabled = true
            UIDropDownMenu_AddButton(coreTitleInfo)
            
            -- Add Core checkboxes (indices 1-6: Quest, Dungeon, Heroic Dungeon, Raid, Professions, Meta)
            local isTBC = GetExpansionLevel and GetExpansionLevel() > 0
            for i = 1, 6 do
                -- Skip Heroic Dungeon (index 3) if not TBC
                if not (i == 3 and not isTBC) then
                    local info = UIDropDownMenu_CreateInfo()
                    local checkboxIndex = i  -- Capture index in local variable
                    info.text = checkboxLabels[checkboxIndex]
                    info.checked = dropdown._checkboxStates[checkboxIndex]
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.func = function(self)
                        -- Toggle the state
                        dropdown._checkboxStates[checkboxIndex] = not dropdown._checkboxStates[checkboxIndex]
                        local newState = dropdown._checkboxStates[checkboxIndex]
                        
                        -- Update the button's checked property
                        self.checked = newState
                        
                        -- Manually toggle the checkmark textures for immediate visual feedback
                        local buttonName = self:GetName()
                        local checkTexture = _G[buttonName .. "Check"]
                        local uncheckTexture = _G[buttonName .. "UnCheck"]
                        if checkTexture and uncheckTexture then
                            if newState then
                                checkTexture:Show()
                                uncheckTexture:Hide()
                            else
                                checkTexture:Hide()
                                uncheckTexture:Show()
                            end
                        end
                        
                        -- Save to database
                        SaveCheckboxStatesToDB(dropdown._checkboxStates)
                        
                        -- Call the callback
                        if dropdown._onCheckboxChange then
                            dropdown._onCheckboxChange(checkboxIndex, newState)
                        end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
            
            -- Add separator
            UIDropDownMenu_AddButton(separatorInfo)
            
            -- Add "Miscellaneous" section title
            local miscTitleInfo = UIDropDownMenu_CreateInfo()
            miscTitleInfo.text = "Miscellaneous"
            miscTitleInfo.isTitle = true
            miscTitleInfo.isUninteractable = true
            miscTitleInfo.notCheckable = true
            miscTitleInfo.disabled = true
            UIDropDownMenu_AddButton(miscTitleInfo)
            
            -- Add Miscellaneous checkboxes (indices 7-14: Reputations, Exploration, Dungeon Sets, Solo, Duo, Trio, Ridiculous, Secret)
            for i = 7, 14 do
                local info = UIDropDownMenu_CreateInfo()
                local checkboxIndex = i  -- Capture index in local variable
                info.text = checkboxLabels[checkboxIndex]
                info.checked = dropdown._checkboxStates[checkboxIndex]
                info.isNotRadio = true
                info.keepShownOnClick = true
                info.func = function(self)
                    -- Toggle the state
                    dropdown._checkboxStates[checkboxIndex] = not dropdown._checkboxStates[checkboxIndex]
                    local newState = dropdown._checkboxStates[checkboxIndex]
                    
                    -- Update the button's checked property
                    self.checked = newState
                    
                    -- Manually toggle the checkmark textures for immediate visual feedback
                    local buttonName = self:GetName()
                    local checkTexture = _G[buttonName .. "Check"]
                    local uncheckTexture = _G[buttonName .. "UnCheck"]
                    if checkTexture and uncheckTexture then
                        if newState then
                            checkTexture:Show()
                            uncheckTexture:Hide()
                        else
                            checkTexture:Hide()
                            uncheckTexture:Show()
                        end
                    end
                    
                    -- Save to database
                    SaveCheckboxStatesToDB(dropdown._checkboxStates)
                    
                    -- Call the callback
                    if dropdown._onCheckboxChange then
                        dropdown._onCheckboxChange(checkboxIndex, newState)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    
    -- Set initial dropdown text (no selection for radio buttons, so just show "Filters")
    UIDropDownMenu_SetText(dropdown, "Filters")
end

-- Get current filter value (deprecated - use GetStatusFilterStates instead)
function FilterDropdown:GetCurrentFilter(dropdown)
    -- Return empty string as we no longer use a single filter value
    return ""
end

-- Get status filter states from dropdown (method)
function FilterDropdown:GetStatusFilterStatesFromDropdown(dropdown)
    if dropdown and dropdown._statusFilters then
        return dropdown._statusFilters
    end
    return FilterDropdown.GetStatusFilterStates()
end

-- Get checkbox state
function FilterDropdown:GetCheckboxState(dropdown, index)
    if dropdown._checkboxStates and dropdown._checkboxStates[index] then
        return dropdown._checkboxStates[index]
    end
    return false
end

-- Set checkbox state
function FilterDropdown:SetCheckboxState(dropdown, index, state)
    if dropdown._checkboxStates then
        dropdown._checkboxStates[index] = state
        -- Re-initialize to update visual state
        FilterDropdown:InitializeDropdown(dropdown, {
            currentFilter = dropdown._currentFilter,
            checkboxStates = dropdown._checkboxStates,
            onFilterChange = dropdown._onFilterChange,
            onCheckboxChange = dropdown._onCheckboxChange,
            checkboxLabels = dropdown._checkboxLabels,
            filterList = dropdown._filterList,
        })
    end
end

-- Helper function to create and initialize a complete filter dropdown with standard configuration
-- parent: Frame to attach dropdown to
-- positionConfig: Table with {anchorPoint, anchorTo, xOffset, yOffset, width} or defaults will be used
-- callbacks: Table with {onFilterChange, onCheckboxChange, onStatusFilterChange} functions
-- Returns: The created dropdown frame
function FilterDropdown:CreateAndInitializeDropdown(parent, positionConfig, callbacks)
    positionConfig = positionConfig or {}
    callbacks = callbacks or {}
    
    -- Default position if not provided
    local anchorPoint = positionConfig.anchorPoint or "TOPRIGHT"
    local anchorTo = positionConfig.anchorTo or parent
    local xOffset = positionConfig.xOffset or -20
    local yOffset = positionConfig.yOffset or -52
    local width = positionConfig.width or 60
    
    -- Create the dropdown
    local dropdown = FilterDropdown:CreateDropdown(parent, anchorPoint, anchorTo, xOffset, yOffset, width)
    
    -- Standard checkbox labels
    local checkboxLabels = { 
        "Quests", "Dungeons", "Heroic Dungeons", "Raids", "Professions", "Meta", 
        "Reputations", "Exploration", "Dungeon Sets", "Solo Dungeons", "Duo Dungeons", 
        "Trio Dungeons", "Ridiculous", "Secret" 
    }
    
    -- Initialize the dropdown
    FilterDropdown:InitializeDropdown(dropdown, {
        checkboxLabels = checkboxLabels,
        onFilterChange = callbacks.onFilterChange or function() end,
        onCheckboxChange = callbacks.onCheckboxChange or function() end,
        onStatusFilterChange = callbacks.onStatusFilterChange or function() end,
    })
    
    return dropdown
end

-- Export as global module
_G.FilterDropdown = FilterDropdown

