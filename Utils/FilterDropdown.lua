-- FilterDropdown.lua
-- Shared filter dropdown implementation for both Character Panel and Embed UI

local FilterDropdown = {}

-- Helper function to get checkbox states from character database
local function GetCheckboxStatesFromDB()
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.filterCheckboxes then
            -- Ensure we have a table with up to 13 boolean values
            local states = cdb.settings.filterCheckboxes
            if type(states) == "table" then
                return {
                    states[1] ~= false,  -- Quest (default true)
                    states[2] ~= false,  -- Dungeon (default true)
                    states[3] == true,  -- Heroic Dungeon
                    states[4] ~= false,  -- Raid (default true)
                    states[5] ~= false,  -- Professions (default true)
                    states[6] ~= false,  -- Meta (default true)
                    states[7] == true,  -- Reputations
                    states[8] == true,  -- Dungeon Sets
                    states[9] == true,  -- Solo
                    states[10] == true,  -- Duo
                    states[11] == true,  -- Trio
                    states[12] == true,  -- Ridiculous
                    states[13] == true,  -- Secret
                }
            end
        end
    end
    -- Default: Core checked, Miscellaneous unchecked
    return { true, true, false, true, true, true, false, false, false, false, false, false, false }
end

-- Helper function to save checkbox states to character database
local function SaveCheckboxStatesToDB(checkboxStates)
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
                checkboxStates[8] == true,  -- Dungeon Sets
                checkboxStates[9] == true,  -- Solo
                checkboxStates[10] == true,  -- Duo
                checkboxStates[11] == true,  -- Trio
                checkboxStates[12] == true,  -- Ridiculous
                checkboxStates[13] == true,  -- Secret
            }
        end
    end
end

-- Default filter list
local function GetDefaultFilterList()
    return {
        { text = ACHIEVEMENTFRAME_FILTER_ALL, value = "all" },
        { text = ACHIEVEMENTFRAME_FILTER_COMPLETED, value = "completed" },
        { text = ACHIEVEMENTFRAME_FILTER_INCOMPLETE, value = "not_completed" },
        { text = FAILED, value = "failed" },
    }
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
    UIDropDownMenu_SetText(dropdown, ACHIEVEMENTFRAME_FILTER_ALL)
    
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
    local currentFilter = config.currentFilter or "all"
    -- Load checkbox states from database if not provided in config
    local checkboxStates = config.checkboxStates
    if not checkboxStates then
        checkboxStates = GetCheckboxStatesFromDB()
    end
    local checkboxLabels = config.checkboxLabels or { "Show Dungeon Trios", "Show Dungeon Duos", "Show Dungeon Solos" }
    local filterList = config.filterList or GetDefaultFilterList()
    
    -- Store state on the dropdown for access in callbacks
    dropdown._currentFilter = currentFilter
    dropdown._checkboxStates = checkboxStates  -- Initial state, will be reloaded from DB on each open
    dropdown._onFilterChange = onFilterChange
    dropdown._onCheckboxChange = onCheckboxChange
    dropdown._checkboxLabels = checkboxLabels
    dropdown._filterList = filterList
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level == 1 then
            -- Reload checkbox states from database each time dropdown opens (for sync between frames)
            dropdown._checkboxStates = GetCheckboxStatesFromDB()
            -- Add filter options
            for _, filter in ipairs(filterList) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = filter.text
                info.value = filter.value
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(dropdown, filter.value)
                    UIDropDownMenu_SetText(dropdown, filter.text)
                    dropdown._currentFilter = filter.value
                    if dropdown._onFilterChange then
                        dropdown._onFilterChange(filter.value)
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
            
            -- Add Miscellaneous checkboxes (indices 7-13: Reputations, Dungeon Sets, Solo, Duo, Trio, Ridiculous, Secret)
            for i = 7, 13 do
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
    
    -- Set initial selected value
    UIDropDownMenu_SetSelectedValue(dropdown, currentFilter)
    UIDropDownMenu_SetText(dropdown, filterList[1].text)
end

-- Get current filter value
function FilterDropdown:GetCurrentFilter(dropdown)
    return dropdown._currentFilter or "all"
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

-- Export as global module
_G.FilterDropdown = FilterDropdown

