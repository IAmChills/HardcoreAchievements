local ADDON_NAME = ...
local EMBED = {}
local UHCA -- tabContents[3]
local ICON_SIZE = 60
local ICON_PADDING = 12
local GRID_COLS = 8  -- Number of columns in the grid
local CHECKBOX_TEXTURE_NORMAL = "Interface\\AddOns\\HardcoreAchievements\\Images\\box.png"
local CHECKBOX_TEXTURE_ACTIVE = "Interface\\AddOns\\HardcoreAchievements\\Images\\box_active.png"
local SETTINGS_ICON_TEXTURE = "Interface\\AddOns\\HardcoreAchievements\\Images\\icon_gear.png"

local function GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function ApplyDropdownBorder(frame)
    if not frame then
        return
    end

    local background = frame.__HCABackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND")
        frame.__HCABackground = background
    end

    local border = frame.__HCAThinBorder
    if not border then
        border = CreateFrame("Frame", nil, frame)
        frame.__HCAThinBorder = border
        border:SetAllPoints(frame)

        border.top = border:CreateTexture(nil, "OVERLAY")
        border.top:SetPoint("TOPLEFT", 10, 0)
        border.top:SetPoint("TOPRIGHT", -11, 0)
        border.top:SetHeight(1)

        border.bottom = border:CreateTexture(nil, "OVERLAY")
        border.bottom:SetPoint("BOTTOMLEFT", 10, 0)
        border.bottom:SetPoint("BOTTOMRIGHT", -11, 0)
        border.bottom:SetHeight(1)

        border.left = border:CreateTexture(nil, "OVERLAY")
        border.left:SetPoint("TOPLEFT", 10, 0)
        border.left:SetPoint("BOTTOMLEFT", -12, 0)
        border.left:SetWidth(1)

        border.right = border:CreateTexture(nil, "OVERLAY")
        border.right:SetPoint("TOPRIGHT", -11, 0)
        border.right:SetPoint("BOTTOMRIGHT", -11, 0)
        border.right:SetWidth(1)
    end

    local existingBackground = frame.__HCABackground
    local existingBorder = frame.__HCAThinBorder

    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:IsObjectType("Texture") then
            if region ~= existingBackground
                and (not existingBorder or (region ~= existingBorder.top and region ~= existingBorder.bottom and region ~= existingBorder.left and region ~= existingBorder.right)) then
                region:SetTexture(nil)
                region:SetAlpha(0)
            end
        end
    end

    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -1)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 1)
    background:SetColorTexture(0, 0, 0, 0.96)
    background:Show()

    border:SetFrameLevel(frame:GetFrameLevel() + 1)
    border.top:SetColorTexture(0.4, 0.4, 0.4, 1)
    border.bottom:SetColorTexture(0.4, 0.4, 0.4, 1)
    border.left:SetColorTexture(0.4, 0.4, 0.4, 1)
    border.right:SetColorTexture(0.4, 0.4, 0.4, 1)
    border:Show()
end

hooksecurefunc("UIDropDownMenu_CreateFrames", function(level)
    ApplyDropdownBorder(_G["DropDownList" .. level .. "Backdrop"])
    ApplyDropdownBorder(_G["DropDownList" .. level .. "MenuBackdrop"])
end)

local currentFilter = "all"  -- Current filter state

local POINTS_FONT_PATH = "Interface\\AddOns\\HardcoreAchievements\\Fonts\\friz-quadrata-regular.ttf"

-- Map class tokens to their icon variants
local classIconTextures = {
  WARRIOR   = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_WARRIOR.png",
  PALADIN   = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_PALADIN.png",
  HUNTER    = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_HUNTER.png",
  ROGUE     = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_ROGUE.png",
  PRIEST    = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_PRIEST.png",
  SHAMAN    = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_SHAMAN.png",
  MAGE      = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_MAGE.png",
  WARLOCK   = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_WARLOCK.png",
  DRUID     = "Interface\\AddOns\\HardcoreAchievements\\Images\\Class_DRUID.png",
}

local function GetClassIconTexture(classToken)
  if classToken and classIconTextures[classToken] then
    return classIconTextures[classToken]
  end

  return "Interface\\AddOns\\HardcoreAchievements\\Images\\class_icon.png"
end

local function UpdateEmbedClassIcon()
  if not UHCA or not UHCA.ClassIcon then
    return
  end

  local _, classToken = UnitClass("player")
  local texture = GetClassIconTexture(classToken)

  UHCA.ClassIcon:SetTexture(texture)
end

-- Helper function to strip color codes from text (for shadow text)
local function StripColorCodes(text)
    if not text or type(text) ~= "string" then return text end
    -- Remove |cAARRGGBB color start codes and |r color end codes
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Helper function to check if modern rows is enabled
local function IsModernRowsEnabled()
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            if cdb.settings.modernRows == nil then
                cdb.settings.modernRows = true
                return true
            end
            return cdb.settings.modernRows == true
        end
    end
    return false
end

local function UpdateLayoutCheckboxes(useModernRows)
    if UHCA and UHCA.LayoutListCheckbox then
        UHCA.LayoutListCheckbox:SetChecked(useModernRows)
    end
    if UHCA and UHCA.LayoutGridCheckbox then
        UHCA.LayoutGridCheckbox:SetChecked(not useModernRows)
    end
end

-- Helper function to check if achievement should be shown based on checkbox filter
-- Returns true if should show, false if should hide
local function ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, checkboxIndex, variationType)
    -- Completed achievements always show when "all" or "completed" filter is selected
    if isCompleted and (currentFilter == "all" or currentFilter == "completed") then
        return true
    end
    
    -- Load checkbox states from database
    local checkboxStates = { false, false, false, false, false, false }
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.filterCheckboxes then
            local states = cdb.settings.filterCheckboxes
            if type(states) == "table" then
                checkboxStates = {
                    states[1] == true,  -- Trio
                    states[2] == true,  -- Duo
                    states[3] == true,  -- Solo
                    states[4] == true,  -- Dungeon Sets
                    states[5] == true,  -- Reputations
                    states[6] == true,  -- Raids
                }
            end
        end
    end
    
    -- For variations, check based on variation type
    if variationType then
        if variationType == "Trio" then
            return checkboxStates[1]
        elseif variationType == "Duo" then
            return checkboxStates[2]
        elseif variationType == "Solo" then
            return checkboxStates[3]
        end
        return false
    end
    
    -- For other types, check the specified checkbox index
    if checkboxIndex then
        return checkboxStates[checkboxIndex]
    end
    
    return true -- Default to showing if no checkbox specified
end

-- Helper function to check if achievement should be shown based on checkbox filter
-- Returns true if should show, false if should hide
local function ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, checkboxIndex, variationType)
    -- Completed achievements always show when "all" or "completed" filter is selected
    if isCompleted and (currentFilter == "all" or currentFilter == "completed") then
        return true
    end
    
    -- Load checkbox states from database
    local checkboxStates = { false, false, false, false, false, false }
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.filterCheckboxes then
            local states = cdb.settings.filterCheckboxes
            if type(states) == "table" then
                checkboxStates = {
                    states[1] == true,  -- Trio
                    states[2] == true,  -- Duo
                    states[3] == true,  -- Solo
                    states[4] == true,  -- Dungeon Sets
                    states[5] == true,  -- Reputations
                    states[6] == true,  -- Raids
                }
            end
        end
    end
    
    -- For variations, check based on variation type
    if variationType then
        if variationType == "Trio" then
            return checkboxStates[1]
        elseif variationType == "Duo" then
            return checkboxStates[2]
        elseif variationType == "Solo" then
            return checkboxStates[3]
        end
        return false
    end
    
    -- For other types, check the specified checkbox index
    if checkboxIndex then
        return checkboxStates[checkboxIndex]
    end
    
    return true -- Default to showing if no checkbox specified
end

local function ApplyCustomCheckboxTextures(checkbox)
    if not checkbox then return end

    checkbox:SetNormalTexture(CHECKBOX_TEXTURE_NORMAL)
    checkbox:SetPushedTexture(CHECKBOX_TEXTURE_NORMAL)
    checkbox:SetHighlightTexture(CHECKBOX_TEXTURE_NORMAL, "ADD")
    checkbox:SetCheckedTexture(CHECKBOX_TEXTURE_ACTIVE)
    checkbox:SetDisabledCheckedTexture(CHECKBOX_TEXTURE_ACTIVE)

    local r, g, b = GetPlayerClassColor()
    local checked = checkbox:GetCheckedTexture()
    if checked then
        checked:SetVertexColor(r, g, b)
    end
    local disabledChecked = checkbox:GetDisabledCheckedTexture()
    if disabledChecked then
        disabledChecked:SetVertexColor(r, g, b)
    end
end

local function SetModernRowsEnabled(enabled)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings.modernRows = enabled and true or false
        end
    end

    UpdateLayoutCheckboxes(enabled)

    if _G._HardcoreAchievementsOptionsPanel and _G._HardcoreAchievementsOptionsPanel.modernRows then
        _G._HardcoreAchievementsOptionsPanel.modernRows:SetChecked(enabled)
    end

    if EMBED and EMBED.Rebuild then
        EMBED:Rebuild()
    end
end

_G.HCA_SetModernRowsEnabled = SetModernRowsEnabled

local function EmbedHasVisibleText(value)
    if type(value) ~= "string" then
        return false
    end
    return value:match("%S") ~= nil
end

local function UpdateEmbedRowTextLayout(row)
    if not row or not row.Icon or not row.Title or not row.Sub then
        return
    end

    local hasSubText = EmbedHasVisibleText(row.Sub:GetText())

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
        local yOffset = 12 + (extraLines * 5)
        row.Title:SetPoint("TOPLEFT", row.Icon, "RIGHT", 8, yOffset)
        row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
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

local function HookEmbedSubTextUpdates(row)
    if not row or not row.Sub or row.Sub._hcaSetTextWrapped then
        return
    end

    local fontString = row.Sub
    local originalSetText = fontString.SetText
    local originalSetFormattedText = fontString.SetFormattedText

    fontString.SetText = function(self, text, ...)
        originalSetText(self, text, ...)
        UpdateEmbedRowTextLayout(row)
    end

    fontString.SetFormattedText = function(self, ...)
        originalSetFormattedText(self, ...)
        UpdateEmbedRowTextLayout(row)
    end

    fontString._hcaSetTextWrapped = true
end

-- Helper function to check if row is outleveled (must be defined before functions that use it)
local function IsRowOutleveled(row)
  if not row or row.completed then return false end
  if not row.maxLevel then return false end
  
  -- Check if there's pending turn-in progress (kill completed but quest not turned in)
  -- If so, don't mark as outleveled - player can still complete it
  if row.questTracker and (row.killTracker or row.requiredKills) then
    -- Achievement requires both kill and quest
    local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(row.achId or row.id)
    if progress then
      local hasKill = false
      if row.requiredKills then
        -- Check if all required kills are satisfied
        if progress.eligibleCounts then
          local allSatisfied = true
          for npcId, requiredCount in pairs(row.requiredKills) do
            local idNum = tonumber(npcId) or npcId
            local current = progress.eligibleCounts[idNum] or progress.eligibleCounts[tostring(idNum)] or 0
            local required = tonumber(requiredCount) or 1
            if current < required then
              allSatisfied = false
              break
            end
          end
          hasKill = allSatisfied
        end
      else
        -- Single kill achievement
        hasKill = progress.killed or false
      end
      
      local questNotTurnedIn = not progress.quest
      -- If kills are satisfied but quest is not turned in, keep achievement available
      if hasKill and questNotTurnedIn then
        return false
      end
    end
  end
  
  local lvl = UnitLevel("player") or 1
  return lvl > row.maxLevel
end

-- Helper function to update status text using the same logic as main panel
local function UpdateStatusTextEmbed(row)
    if not row or not row.Sub or not _G.HCA_SetStatusTextOnRow then return end
    
    local rowId = row.achId or row.id
    if not rowId then return end
    
    -- Get progress data
    local progress = nil
    if _G.HardcoreAchievements_GetProgress then
        progress = _G.HardcoreAchievements_GetProgress(rowId)
    end
    
    local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
    local hasIneligibleKill = progress and progress.ineligibleKill
    local isOutleveled = IsRowOutleveled(row)
    
    -- Check if achievement requires both kill and quest
    local requiresBoth = (row.killTracker ~= nil) and (row.questTracker ~= nil)
    
    -- Check if kills are satisfied but quest is pending
    local killsSatisfied = false
    if requiresBoth and progress and not isOutleveled then
        local hasKill = false
        if progress.killed then
            hasKill = true
        elseif progress.counts and next(progress.counts) ~= nil then
            if progress.eligibleCounts then
                -- Find the achievement definition to check requiredKills
                local achDef = nil
                if _G.Achievements then
                    for _, def in ipairs(_G.Achievements) do
                        if def.achId == rowId then
                            achDef = def
                            break
                        end
                    end
                end
                
                if achDef and achDef.requiredKills then
                    local allSatisfied = true
                    for npcId, requiredCount in pairs(achDef.requiredKills) do
                        local idNum = tonumber(npcId) or npcId
                        local current = progress.eligibleCounts[idNum] or progress.eligibleCounts[tostring(idNum)] or 0
                        local required = tonumber(requiredCount) or 1
                        if current < required then
                            allSatisfied = false
                            break
                        end
                    end
                    hasKill = allSatisfied
                else
                    hasKill = progress.killed or false
                end
            elseif progress.killed then
                hasKill = true
            end
        end
        
        local questNotTurnedIn = not progress.quest
        killsSatisfied = hasKill and questNotTurnedIn
    end
    
    -- Get self-found and solo mode status
    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    
    -- Check if achievement was completed solo
    local wasSolo = false
    if row.completed then
        local getCharDB = _G.GetCharDB or _G.HardcoreAchievements_GetCharDB
        if getCharDB then
            local _, cdb = getCharDB()
            if cdb and cdb.achievements and rowId then
                local achRec = cdb.achievements[rowId]
                wasSolo = achRec and achRec.wasSolo or false
            end
        end
    end
    
    -- Use the centralized status text function
    _G.HCA_SetStatusTextOnRow(row, {
        completed = row.completed or false,
        hasSoloStatus = hasSoloStatus,
        hasIneligibleKill = hasIneligibleKill,
        requiresBoth = requiresBoth,
        killsSatisfied = killsSatisfied,
        isSelfFound = isSelfFound,
        isSoloMode = isSoloMode,
        wasSolo = wasSolo,
        allowSoloDouble = row.allowSoloDouble,
        maxLevel = row.maxLevel,
        isOutleveled = isOutleveled
    })

    if isOutleveled and progress then
        progress.soloKill = nil
        progress.soloQuest = nil
    end
end

-- Helper functions for modern rows (similar to character panel)
local function UpdateRowBorderColorEmbed(row)
    if not row or not row.Border then return end
    
    if row.completed then
        row.Border:SetVertexColor(0.6, 0.9, 0.6)
        if row.Background then
            row.Background:SetVertexColor(0.1, 1.0, 0.1)
            row.Background:SetAlpha(1)
        end
    elseif IsRowOutleveled(row) then
        row.Border:SetVertexColor(0.957, 0.263, 0.212)
        if row.Background then
            row.Background:SetVertexColor(1.0, 0.1, 0.1)
            row.Background:SetAlpha(1)
        end
    else
        row.Border:SetVertexColor(0.8, 0.8, 0.8)
        if row.Background then
            row.Background:SetVertexColor(1, 1, 1)
            row.Background:SetAlpha(1)
        end
    end
end

local function PositionRowBorderEmbed(row)
    if not row or not row.Border or not row:IsShown() then 
        if row and row.Border then row.Border:Hide() end
        if row and row.Background then row.Background:Hide() end
        return 
    end
    
    -- Get row width for full-width border
    local rowWidth = row:GetWidth() or 310
    local rowHeight = row:GetHeight() or 64
    row.Border:ClearAllPoints()
    row.Border:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
    row.Border:SetSize(rowWidth + 8, rowHeight + 4) -- Full width + padding, slight extra height
    row.Border:Show()
    
    if row.Background then
        row.Background:ClearAllPoints()
        row.Background:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
        row.Background:SetSize(rowWidth + 8, rowHeight + 4)
        row.Background:Show()
    end

    if row.highlight then
        row.highlight:ClearAllPoints()
        row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
        row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 3, -1)
    end
end

local function UpdatePointsDisplayEmbed(row)
    if not row or not row.PointsFrame then return end
    
    -- Show/hide variation overlay based on achievement state
    if row.PointsFrame.VariationOverlay and row._def and row._def.isVariation then
        if row.completed then
            -- Completed: use gold texture
            row.PointsFrame.VariationOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dragon_gold.png")
            row.PointsFrame.VariationOverlay:Show()
        elseif IsRowOutleveled(row) then
            -- Failed/overleveled: use failed texture
            row.PointsFrame.VariationOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dragon_failed.png")
            row.PointsFrame.VariationOverlay:Show()
        else
            -- Available (not completed, not failed): use disabled texture
            row.PointsFrame.VariationOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dragon_disabled.png")
            row.PointsFrame.VariationOverlay:Show()
        end
    elseif row.PointsFrame.VariationOverlay then
        row.PointsFrame.VariationOverlay:Hide()
    end
    
    if row.completed then
        if row.Points then row.Points:SetAlpha(0) end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-Ready.png")
            row.PointsFrame.Checkmark:Show()
        end
        if row.PointsFrame.Texture then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_gold.png")
        end
        if row.IconOverlay then row.IconOverlay:Hide() end
        if row.Sub then row.Sub:SetTextColor(1, 1, 1) end
        if row.Title then row.Title:SetTextColor(1, 0.82, 0) end
    elseif IsRowOutleveled(row) then
        if row.Points then row.Points:SetAlpha(0) end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
            row.PointsFrame.Checkmark:Show()
        end
        if row.PointsFrame.Texture then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_failed.png")
        end
        if row.IconOverlay then
            row.IconOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
            row.IconOverlay:Show()
        end
        if row.Sub then row.Sub:SetTextColor(0.5, 0.5, 0.5) end
        if row.Title then row.Title:SetTextColor(0.957, 0.263, 0.212) end
    else
        if row.Points then row.Points:SetAlpha(1) end
        if row.PointsFrame.Checkmark then row.PointsFrame.Checkmark:Hide() end
        if row.PointsFrame.Texture then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.png")
        end
        if row.IconOverlay then row.IconOverlay:Hide() end
        if row.Sub then row.Sub:SetTextColor(0.5, 0.5, 0.5) end
        if row.Title then row.Title:SetTextColor(1, 1, 1) end
    end
end

local function ApplyOutleveledStyleEmbed(row)
    if not row then return end
    
    -- Desaturate icon
    if row.Icon and row.Icon.SetDesaturated then
        -- Completed achievements are full color; failed/outleveled should remain desaturated
        if row.completed then
            row.Icon:SetDesaturated(false)
        else
            row.Icon:SetDesaturated(true)
        end
    end
    
    if IsRowOutleveled(row) and row.Sub then
        if row.maxLevel then
            row.Sub:SetText((LEVEL or "Level") .. " " .. row.maxLevel)
        else
            row.Sub:SetText(AUCTION_TIME_LEFT0 or "")
        end
    end
    
    -- Show/hide appropriate IconFrame based on state
    if row.completed then
        -- Completed: show gold frame
        if row.IconFrameGold then row.IconFrameGold:Show() end
        if row.IconFrame then row.IconFrame:Hide() end
    else
        -- Available/failed: show silver frame
        if row.IconFrameGold then row.IconFrameGold:Hide() end
        if row.IconFrame then row.IconFrame:Show() end
    end
    
end

-- Format timestamp (same as character panel)
local function FormatTimestampEmbed(timestamp)
    if not timestamp then return "" end
    
    local dateInfo = date("*t", timestamp)
    local locale = GetLocale()
    
    if locale == "enUS" then
        return string.format("%02d/%02d/%02d", dateInfo.month, dateInfo.day, dateInfo.year % 100)
    else
        return string.format("%02d/%02d/%02d", dateInfo.day, dateInfo.month, dateInfo.year % 100)
    end
end

-- ---------- Filter Functions ----------
-- (IsRowOutleveled moved above to be available for helper functions)

-- Function to apply the current filter (similar to main file)
local function ApplyFilter()
  if EMBED and EMBED.Rebuild then
    EMBED:Rebuild()
  end
end

-- ---------- Source ----------
local function GetSourceRows()
  if AchievementPanel and type(AchievementPanel.achievements) == "table" then
    return AchievementPanel.achievements
  end
end

local function ReadRowData(src)
  if not src then return end
  
  -- Extract only the data we need directly from the source row
  local iconTex = nil
  if src.Icon and src.Icon.GetTexture then
    iconTex = src.Icon:GetTexture()
  end
  
  return {
    id = src.id or src.achId,
    achId = src.achId or src.id,
    iconTex = iconTex,
      completed = not not src.completed,
    maxLevel = tonumber(src.maxLevel) or nil,
      requiredKills = src.requiredKills,
    outleveled = IsRowOutleveled(src),
    hiddenUntilComplete = not not src.hiddenUntilComplete,
    -- Profession milestones can "overwrite" previous tiers via ProfessionTracker
    hiddenByProfession = not not src.hiddenByProfession,
  }
end

-- ---------- Icon Factory ----------
local function CreateEmbedIcon(parent)
  local icon = CreateFrame("Button", nil, parent)
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:RegisterForClicks("AnyUp")

  -- Create the achievement icon
  icon.Icon = icon:CreateTexture(nil, "ARTWORK")
  icon.Icon:SetSize(ICON_SIZE - 5, ICON_SIZE - 5)
  icon.Icon:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.Icon:SetTexCoord(0, 1, 0, 1)

  -- Create status frames that match the list view styling
  icon.FrameGold = icon:CreateTexture(nil, "OVERLAY", nil, 1)
  icon.FrameGold:SetSize(ICON_SIZE, ICON_SIZE)
  icon.FrameGold:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.FrameGold:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_gold.png")
  icon.FrameGold:SetTexCoord(0, 1, 0, 1)
  icon.FrameGold:Hide()

  icon.FrameSilver = icon:CreateTexture(nil, "OVERLAY", nil, 1)
  icon.FrameSilver:SetSize(ICON_SIZE, ICON_SIZE)
  icon.FrameSilver:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.FrameSilver:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_silver.png")
  icon.FrameSilver:SetTexCoord(0, 1, 0, 1)
  icon.FrameSilver:Show()
  
  -- Status overlays (green check / red X)
  icon.StatusCheck = icon:CreateTexture(nil, "OVERLAY", nil, 2)
  icon.StatusCheck:SetSize(ICON_SIZE - 32, ICON_SIZE - 32)
  icon.StatusCheck:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.StatusCheck:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-Ready.png")
  icon.StatusCheck:SetTexCoord(0, 1, 0, 1)
  icon.StatusCheck:Hide()

  icon.StatusFail = icon:CreateTexture(nil, "OVERLAY", nil, 2)
  icon.StatusFail:SetSize(ICON_SIZE - 32, ICON_SIZE - 32)
  icon.StatusFail:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.StatusFail:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
  icon.StatusFail:SetTexCoord(0, 1, 0, 1)
  icon.StatusFail:Hide()

  -- Create SSF mode border as a purple/blue glow circle around the icon
  icon.SSFBorder = icon:CreateTexture(nil, "BACKGROUND")
  icon.SSFBorder:SetSize(ICON_SIZE + 4, ICON_SIZE + 4) -- Slightly larger than other borders
  icon.SSFBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.SSFBorder:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  icon.SSFBorder:SetTexCoord(0, 1, 0, 1)
  icon.SSFBorder:SetVertexColor(0.5, 0.3, 0.9, 0.6) -- Purple glow
  icon.SSFBorder:Hide()

  -- Highlight glow on hover
  icon.Highlight = icon:CreateTexture(nil, "HIGHLIGHT")
  icon.Highlight:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\grid_texture.png")
  icon.Highlight:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.Highlight:SetSize(ICON_SIZE, ICON_SIZE)
  icon.Highlight:SetVertexColor(1, 1, 1, 1)
  icon.Highlight:SetBlendMode("ADD")
  icon.Highlight:Hide()

  icon:SetScript("OnEnter", function(self)
    if self.Highlight then
      self.Highlight:Show()
    end
    -- Use centralized tooltip function with source row directly
    if _G.HCA_ShowAchievementTooltip and self.sourceRow then
      _G.HCA_ShowAchievementTooltip(self, self.sourceRow)
    end
  end)
  
  -- Shift click to link achievement bracket into chat or track/untrack (matches CreateAchievementRow behavior)
  icon:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and self.achId then
      local editBox = ChatEdit_GetActiveWindow()
      
      -- Check if chat edit box is active/visible
      if editBox and editBox:IsVisible() then
        -- Chat edit box is active: link achievement (original behavior)
        local bracket = _G.HCA_GetAchievementBracket and _G.HCA_GetAchievementBracket(self.achId) or string.format("[HCA:(%s)]", tostring(self.achId))
        local currentText = editBox:GetText() or ""
        if currentText == "" then
          editBox:SetText(bracket)
        else
          editBox:SetText(currentText .. " " .. bracket)
        end
        editBox:SetFocus()
      else
        -- Chat edit box is NOT active: track/untrack achievement
        local AchievementTracker = _G.HardcoreAchievementsTracker
        if not AchievementTracker then
          print("|cffff0000[Hardcore Achievements]|r Achievement tracker not available. Please reload your UI (/reload).")
          return
        end
        
        local achId = self.achId
        if not achId then
          return
        end
        
        -- Get title from source row if available
        local title = nil
        if self.sourceRow and self.sourceRow.Title and self.sourceRow.Title.GetText then
          title = self.sourceRow.Title:GetText()
        end
        
        -- Strip color codes from title if present
        if title then
          title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        else
          title = tostring(achId)
        end
        
        local isTracked = AchievementTracker:IsTracked(achId)
        
        if isTracked then
          AchievementTracker:UntrackAchievement(achId)
        else
          AchievementTracker:TrackAchievement(achId, title)
        end
      end
    end
  end)
  icon:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    if self.Highlight then
      self.Highlight:Hide()
    end
  end)

  icon:SetScript("OnHide", function(self)
    if self.Highlight then
      self.Highlight:Hide()
    end
  end)

  return icon
end

-- ---------- Layout ----------
local function LayoutIcons(container, icons)
  if not container or not icons then return end
  
  -- Only layout visible icons
  local visibleIcons = {}
  for i, icon in ipairs(icons) do
    if icon:IsShown() then
      table.insert(visibleIcons, icon)
    end
  end
  
  local totalIcons = #visibleIcons
  local rows = math.ceil(totalIcons / GRID_COLS)
  local startX = ICON_PADDING
  local startY = -ICON_PADDING
  
  for i, icon in ipairs(visibleIcons) do
    local col = ((i - 1) % GRID_COLS)
    local row = math.floor((i - 1) / GRID_COLS)
    
    local x = startX + col * (ICON_SIZE + ICON_PADDING)
    local y = startY - row * (ICON_SIZE + ICON_PADDING)
    
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
  end

  local neededH = rows * (ICON_SIZE + ICON_PADDING) + ICON_PADDING
  container:SetHeight(math.max(neededH, 1))
end

-- ---------- Build Classic Grid ----------
function EMBED:BuildClassicGrid(srcRows)
  -- Hide all existing rows if any (including their borders)
  if self.rows then 
    for _, row in ipairs(self.rows) do 
      row:Hide()
      if row.Border then row.Border:Hide() end
      if row.Background then row.Background:Hide() end
    end 
  end
  
  self.icons = self.icons or {}
  
  -- First, hide all existing icons
  for i = 1, #self.icons do
    self.icons[i]:Hide()
  end
  
  local needed = 0

  for _, srow in ipairs(srcRows) do
      local data = ReadRowData(srow)
      
      -- Apply filter logic
      local shouldShow = false
      if currentFilter == "all" then
        shouldShow = true
      elseif currentFilter == "completed" then
        shouldShow = data.completed == true
      elseif currentFilter == "not_completed" then
        shouldShow = data.completed ~= true and not data.outleveled
      elseif currentFilter == "failed" then
        shouldShow = data.outleveled
      end
      if data.hiddenUntilComplete and not data.completed then
        shouldShow = false
      end
      if data.hiddenByProfession then
        shouldShow = false
      end
      
      -- Hide/show achievements based on checkbox filter
      if srow._def then
        local isCompleted = data.completed == true
        local def = srow._def
        
        if def.isVariation then
          -- Variations: check based on variation type
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, nil, def.variationType) then
            shouldShow = false
          end
        elseif def.isDungeonSet then
          -- Dungeon Sets: check index 4
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, 4, nil) then
            shouldShow = false
          end
        elseif def.isReputation then
          -- Reputations: check index 5
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, 5, nil) then
            shouldShow = false
          end
        elseif def.isRaid then
          -- Raids: check index 6
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, 6, nil) then
            shouldShow = false
          end
        end
      end
      
      if shouldShow then
        needed = needed + 1
        local icon = self.icons[needed]
        if not icon then
          icon = CreateEmbedIcon(self.Content)
          self.icons[needed] = icon
        end

        icon.id        = data.id
        icon.achId     = data.achId or data.id  -- Store achId for tooltip lookup
        icon.completed = data.completed
        icon.requiredKills = data.requiredKills  -- Store requiredKills for dungeon achievements
        
        -- Store reference to source row for tooltip function (it can extract data directly from row)
        icon.sourceRow = srow

        local iconTexture = data.iconTex or 136116
        icon.Icon:SetTexture(iconTexture)
        icon.Icon:SetTexCoord(0, 1, 0, 1)

        if icon.Mask then
          if icon.Icon.RemoveMaskTexture then
            icon.Icon:RemoveMaskTexture(icon.Mask)
          end
          icon.Mask:Hide()
          icon.Mask:SetParent(nil)
          icon.Mask = nil
        end

        -- Set icon appearance based on status
        local playerLevel = UnitLevel("player") or 0
        local isOverLeveled = false
        if data.maxLevel and data.maxLevel > 0 then
          isOverLeveled = playerLevel > data.maxLevel
        end
        local isFailed = data.outleveled or isOverLeveled

        if data.completed then
          -- Completed: full color
          icon.Icon:SetDesaturated(false)
          icon.Icon:SetAlpha(1.0)
          icon.Icon:SetVertexColor(1.0, 1.0, 1.0)
        elseif isFailed then
          -- Failed: red tint, not desaturated
          icon.Icon:SetDesaturated(true)
          icon.Icon:SetAlpha(1.0)
          icon.Icon:SetVertexColor(0.85, 0.45, 0.45)
        else
          -- Incomplete and available: desaturated
          icon.Icon:SetDesaturated(true)
          icon.Icon:SetAlpha(1.0)
          icon.Icon:SetVertexColor(1.0, 1.0, 1.0)
        end

        -- Set completion border
        icon.StatusCheck:Hide()
        icon.StatusFail:Hide()

        if data.completed then
          icon.StatusCheck:Show()
        elseif isFailed then
          icon.StatusFail:Show()
        end

        if icon.achId and icon.achId ~= "Secret100" then
          if icon.FrameGold then icon.FrameGold:Hide() end
          if icon.FrameSilver then icon.FrameSilver:Hide() end
          if data.completed then
            if icon.FrameGold then icon.FrameGold:Show() end
          else
            if icon.FrameSilver then icon.FrameSilver:Show() end
          end
        end

        -- Show the icon
        icon:Show()
      end
  end

  LayoutIcons(self.Content, self.icons)
end

-- ---------- Create/Update Modern Row ----------
local function CreateEmbedModernRow(parent, srow)
    if not parent or not srow then return nil end
    
    local row = CreateFrame("Frame", nil, parent)
    -- Get container width and set row to full width minus 5px for scrollbar spacing, taller
    local containerWidth = (parent:GetWidth() or 310) - 5
    row:SetSize(containerWidth, 64) -- Increased height for additional padding
    row:SetClipsChildren(false)
    
    -- Extract data from source row
    local iconTex = srow.Icon and srow.Icon:GetTexture() or 136116
    local title = (srow.Title and srow.Title.GetText and srow.Title:GetText()) or (srow.id or "")
    local tooltip = srow.tooltip or ""
    local zone = srow.zone or ""
    local achId = srow.achId or srow.id
    local level = srow.maxLevel or 0
    local points = srow.points or 0
    local def = srow._def or (_G.HCA_AchievementDefs and _G.HCA_AchievementDefs[achId])
    
    -- icon
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(39, 39)
    row.Icon:SetPoint("LEFT", row, "LEFT", 10, -2)
    row.Icon:SetTexture(iconTex)
    row.Icon:SetTexCoord(0.025, 0.975, 0.025, 0.975)
    
    -- IconFrame overlays (gold for completed, disabled for failed, silver for available)
    -- Gold frame (completed)
    row.IconFrameGold = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrameGold:SetSize(42, 42)
    row.IconFrameGold:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrameGold:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_gold.png")
    row.IconFrameGold:SetDrawLayer("OVERLAY", 1)
    row.IconFrameGold:Hide()
    
    -- Silver frame (available/disabled) - default
    row.IconFrame = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrame:SetSize(42, 42)
    row.IconFrame:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrame:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_silver.png")
    row.IconFrame:SetDrawLayer("OVERLAY", 1)
    row.IconFrame:Show()
    
    -- Icon overlay (for failed state - red X)
    row.IconOverlay = row:CreateTexture(nil, "OVERLAY")
    row.IconOverlay:SetSize(24, 24) -- Increased from 20x20 to 24x24 to match scale
    row.IconOverlay:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconOverlay:Hide()
    
    -- title
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetText(title)
    row.Title:SetTextColor(1, 1, 1)
    
    -- title drop shadow (strip color codes so shadow is always black)
    row.TitleShadow = row:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    row.TitleShadow:SetText(StripColorCodes(title))
    row.TitleShadow:SetTextColor(0, 0, 0, 0.5)
    row.TitleShadow:SetDrawLayer("BACKGROUND", 0)
    
    -- subtitle / progress
    row.Sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
    row.Sub:SetWidth(265)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetJustifyV("TOP")
    row.Sub:SetWordWrap(true)
    row.Sub:SetTextColor(0.5, 0.5, 0.5)
    do
        local defaultSub = srow._defaultSubText
        if defaultSub == nil then
            if level and level > 0 then
                defaultSub = (LEVEL or "Level") .. " " .. level
            else
                defaultSub = ""
            end
        end
        row.Sub:SetText(defaultSub)
        row._defaultSubText = defaultSub
    end
    HookEmbedSubTextUpdates(row)
    row.UpdateTextLayout = UpdateEmbedRowTextLayout
    UpdateEmbedRowTextLayout(row)
    
    -- Circular frame for points (increased size)
    row.PointsFrame = CreateFrame("Frame", nil, row)
    row.PointsFrame:SetSize(56, 56) -- Increased from 48x48 to 56x56
    row.PointsFrame:SetPoint("RIGHT", row, "RIGHT", -15, -2)
    
    row.PointsFrame.Texture = row.PointsFrame:CreateTexture(nil, "BACKGROUND")
    row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.png")
    row.PointsFrame.Texture:SetAllPoints(row.PointsFrame)
    
    -- Variation overlay texture (solo/duo/trio) - appears on top of ring texture
    row.PointsFrame.VariationOverlay = row.PointsFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    -- Set size (width, height) and position (x, y offsets from center)
    row.PointsFrame.VariationOverlay:SetSize(58, 51)  -- Width, Height (matches PointsFrame size)
    row.PointsFrame.VariationOverlay:SetPoint("CENTER", row.PointsFrame, "CENTER", -8, 1)  -- X offset, Y offset
    row.PointsFrame.VariationOverlay:SetAlpha(1)
    row.PointsFrame.VariationOverlay:Hide()
    
    row.Points = row.PointsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Points:SetPoint("CENTER", row.PointsFrame, "CENTER", 0, 0)
    row.Points:SetText(tostring(points))
    row.Points:SetTextColor(1, 1, 1)
    
    row.PointsFrame.Checkmark = row.PointsFrame:CreateTexture(nil, "OVERLAY")
    row.PointsFrame.Checkmark:SetSize(20, 20) -- Increased from 16x16 to 20x20 to match scale
    row.PointsFrame.Checkmark:SetPoint("CENTER", row.PointsFrame, "CENTER", 0, 0)
    row.PointsFrame.Checkmark:Hide()
    
    -- timestamp
    row.TS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.TS:SetPoint("RIGHT", row.PointsFrame, "LEFT", -15, -2)
    row.TS:SetJustifyH("RIGHT")
    row.TS:SetJustifyV("TOP")
    row.TS:SetText("")
    row.TS:SetTextColor(1, 1, 1)
    
    -- border texture (child of UHCA.Scroll for clipping)
    if not UHCA.BorderClip then
        -- Create border clipping frame if it doesn't exist
        UHCA.BorderClip = CreateFrame("Frame", nil, UHCA)
        UHCA.BorderClip:SetPoint("TOPLEFT", UHCA.Scroll, "TOPLEFT", -10, 2)
        UHCA.BorderClip:SetPoint("BOTTOMRIGHT", UHCA.Scroll, "BOTTOMRIGHT", 10, -2)
        UHCA.BorderClip:SetClipsChildren(true)
    end
    
    row.Background = UHCA.BorderClip:CreateTexture(nil, "BACKGROUND")
    row.Background:SetDrawLayer("BACKGROUND", 0)
    row.Background:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.png")
    row.Background:SetVertexColor(1, 1, 1)
    row.Background:SetAlpha(1)
    row.Background:Hide()
    
    row.Border = UHCA.BorderClip:CreateTexture(nil, "BACKGROUND")
    row.Border:SetDrawLayer("BACKGROUND", 1)
    row.Border:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row-border.png")
    row.Border:SetSize(256, 32)
    row.Border:SetAlpha(0.5)
    row.Border:Hide()
    
    -- highlight/tooltip
    row:EnableMouse(true)
    row.highlight = UHCA.BorderClip:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
    row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 3, -1)
    row.highlight:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.png")
    row.highlight:SetVertexColor(1, 1, 1, 0.75)
    row.highlight:SetBlendMode("ADD")
    row.highlight:Hide()
    
    row:SetScript("OnEnter", function(self)
        if self.highlight then
            self.highlight:SetVertexColor(1, 1, 1, 0.75)
        end
        self.highlight:Show()
        if _G.HCA_ShowAchievementTooltip then
            _G.HCA_ShowAchievementTooltip(self, self)
        end
    end)
    
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and self.achId then
            local editBox = ChatEdit_GetActiveWindow()
            
            -- Check if chat edit box is active/visible
            if editBox and editBox:IsVisible() then
                -- Chat edit box is active: link achievement (original behavior)
                local bracket = _G.HCA_GetAchievementBracket and _G.HCA_GetAchievementBracket(self.achId) or string.format("[HCA:(%s)]", tostring(self.achId))
                local currentText = editBox:GetText() or ""
                if currentText == "" then
                    editBox:SetText(bracket)
                else
                    editBox:SetText(currentText .. " " .. bracket)
                end
                editBox:SetFocus()
            else
                -- Chat edit box is NOT active: track/untrack achievement
                local AchievementTracker = _G.HardcoreAchievementsTracker
                if not AchievementTracker then
                    print("|cffff0000[Hardcore Achievements]|r Achievement tracker not available. Please reload your UI (/reload).")
                    return
                end
                
                local achId = self.achId or self.id
                if not achId then
                    return
                end
                
                -- Get title from row Title or source row
                local title = nil
                if self.Title and self.Title.GetText then
                    title = self.Title:GetText()
                elseif self.sourceRow and self.sourceRow.Title and self.sourceRow.Title.GetText then
                    title = self.sourceRow.Title:GetText()
                end
                
                -- Strip color codes from title if present
                if title then
                    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                else
                    title = tostring(achId)
                end
                
                local isTracked = AchievementTracker:IsTracked(achId)
                
                if isTracked then
                    AchievementTracker:UntrackAchievement(achId)
                else
                    AchievementTracker:TrackAchievement(achId, title)
                end
            end
        end
    end)
    
    -- Store reference to source row
    row._achId = achId
    row._title = title
    row._def = def or (srow and srow._def) or (_G.HCA_AchievementDefs and _G.HCA_AchievementDefs[achId])
    row._tooltip = tooltip
    row._zone = zone
    row._def = def
    row.sourceRow = srow
    row.requiredKills = srow.requiredKills
    
    -- Store data
    row.achId = achId
    row.id = achId
    row.originalPoints = points
    row.points = points
    row.completed = srow.completed or false
    row.maxLevel = level > 0 and level or nil
    row.tooltip = tooltip
    row.zone = zone
    row.allowSoloDouble = (def and def.allowSoloDouble ~= nil) and def.allowSoloDouble or (srow.allowSoloDouble ~= nil and srow.allowSoloDouble)
    row.isSecretAchievement = (def and def.isSecretAchievement) or (srow.isSecretAchievement)
    
    -- Store trackers from source row
    row.killTracker = srow.killTracker
    row.questTracker = srow.questTracker
    
    -- Apply styling
    UpdateRowBorderColorEmbed(row)
    UpdatePointsDisplayEmbed(row)
    ApplyOutleveledStyleEmbed(row)
    PositionRowBorderEmbed(row)
    
    -- Update status text using centralized logic
    UpdateStatusTextEmbed(row)
    
    return row
end

local function UpdateEmbedModernRow(row, srow)
    if not row or not srow then return end
    
    -- Update data from source row
    local iconTex = srow.Icon and srow.Icon:GetTexture() or 136116
    local title = (srow.Title and srow.Title.GetText and srow.Title:GetText()) or (srow.id or "")
    local points = srow.points or 0
    local level = srow.maxLevel or 0
    local achId = srow.achId or srow.id
    local def = srow._def or (_G.HCA_AchievementDefs and _G.HCA_AchievementDefs[achId])
    
    if row.Icon then row.Icon:SetTexture(iconTex) end
    if row.Title then row.Title:SetText(title) end
    if row.TitleShadow then row.TitleShadow:SetText(StripColorCodes(title)) end
    if row.Points then row.Points:SetText(tostring(points)) end
    
    -- Update stored data
    row.achId = achId
    row.id = achId
    row.points = points
    row.completed = srow.completed or false
    row.maxLevel = level > 0 and level or nil
    row.sourceRow = srow
    row._def = def
    row.requiredKills = srow.requiredKills
    row.tooltip = srow.tooltip or srow._tooltip or ""
    row._tooltip = row.tooltip
    row.zone = srow.zone or srow._zone
    row._zone = row.zone
    row._title = title
    
    if not row.Background and UHCA then
        if not UHCA.BorderClip then
            UHCA.BorderClip = CreateFrame("Frame", nil, UHCA)
            UHCA.BorderClip:SetPoint("TOPLEFT", UHCA.Scroll, "TOPLEFT", -10, 2)
            UHCA.BorderClip:SetPoint("BOTTOMRIGHT", UHCA.Scroll, "BOTTOMRIGHT", 10, -2)
            UHCA.BorderClip:SetClipsChildren(true)
        end
        row.Background = UHCA.BorderClip:CreateTexture(nil, "BACKGROUND")
        row.Background:SetDrawLayer("BACKGROUND", 0)
        row.Background:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.png")
        row.Background:SetVertexColor(1, 1, 1)
        row.Background:SetAlpha(1)
        row.Background:Hide()
    end
    
    -- Store trackers from source row
    row.killTracker = srow.killTracker
    row.questTracker = srow.questTracker
    row.allowSoloDouble = (def and def.allowSoloDouble ~= nil) and def.allowSoloDouble or (srow.allowSoloDouble ~= nil and srow.allowSoloDouble)
    
    -- Update timestamp display based on completion or failure state
    if row.TS then
        if row.completed and type(HardcoreAchievements_GetCharDB) == "function" then
            local _, cdb = HardcoreAchievements_GetCharDB()
            if cdb and cdb.achievements and cdb.achievements[achId] then
                local timestamp = cdb.achievements[achId].completedAt
                if timestamp then
                    row.TS:SetText(FormatTimestampEmbed(timestamp))
                else
                    row.TS:SetText(FormatTimestampEmbed(time()))
                end
            else
                row.TS:SetText(FormatTimestampEmbed(time()))
            end
            row.TS:SetTextColor(1, 1, 1)
        elseif IsRowOutleveled(row) then
            local failedAt = nil
            if _G.HCA_GetFailureTimestamp then
                failedAt = _G.HCA_GetFailureTimestamp(achId)
            end
            if not failedAt and _G.HCA_EnsureFailureTimestamp then
                failedAt = _G.HCA_EnsureFailureTimestamp(achId)
            end
            failedAt = failedAt or time()
            row.TS:SetText(FormatTimestampEmbed(failedAt))
            row.TS:SetTextColor(0.957, 0.263, 0.212)
        else
            row.TS:SetText("")
            row.TS:SetTextColor(1, 1, 1)
        end
    end
    
    -- Apply styling
    UpdateRowBorderColorEmbed(row)
    UpdatePointsDisplayEmbed(row)
    ApplyOutleveledStyleEmbed(row)
    PositionRowBorderEmbed(row)
    
    -- Update status text using centralized logic
    UpdateStatusTextEmbed(row)
end

-- Layout modern rows vertically
local function LayoutModernRows(container, rows)
    if not container or not rows then return end
    
    -- Get container width for full-width rows (minus 5px for scrollbar spacing)
    local containerWidth = (container:GetWidth() or 310) - 5
    
    local visibleRows = {}
    for i, row in ipairs(rows) do
        if row:IsShown() then
            table.insert(visibleRows, row)
        else
            -- Hide border for hidden rows
            if row.Border then
                row.Border:Hide()
            end
            if row.Background then
                row.Background:Hide()
            end
        end
    end
    
    local totalHeight = 0
    local rowSpacing = 8 -- Additional spacing for taller rows
    for i, row in ipairs(visibleRows) do
        -- Set row to full width minus 5px for scrollbar spacing
        row:SetWidth(containerWidth)
        
        if i == 1 then
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", visibleRows[i-1], "BOTTOMLEFT", 0, -rowSpacing)
        end
        PositionRowBorderEmbed(row)
        totalHeight = totalHeight + (row:GetHeight() + rowSpacing)
    end
    
    container:SetHeight(math.max(totalHeight + 16, 1))
    if UHCA.Scroll then
        UHCA.Scroll:UpdateScrollChildRect()
    end
end

-- ---------- Build Modern Rows ----------
function EMBED:BuildModernRows(srcRows)
  -- Hide all existing icons if any
  if self.icons then for _, icon in ipairs(self.icons) do icon:Hide() end end
  
  self.rows = self.rows or {}
  
  -- First, hide all existing rows and their borders
  for i = 1, #self.rows do
    self.rows[i]:Hide()
    if self.rows[i].Border then
      self.rows[i].Border:Hide()
    end
    if self.rows[i].Background then
      self.rows[i].Background:Hide()
    end
  end
  
  local visibleRows = {}
  
  -- Filter and collect visible rows
  for _, srow in ipairs(srcRows) do
      local data = ReadRowData(srow)
      
      -- Apply filter logic
      local shouldShow = false
      if currentFilter == "all" then
        shouldShow = true
      elseif currentFilter == "completed" then
        shouldShow = data.completed == true
      elseif currentFilter == "not_completed" then
        shouldShow = data.completed ~= true and not data.outleveled
      elseif currentFilter == "failed" then
        shouldShow = data.outleveled
      end
      if data.hiddenUntilComplete and not data.completed then
        shouldShow = false
      end
      if data.hiddenByProfession then
        shouldShow = false
      end
      
      -- Hide/show achievements based on checkbox filter
      if srow._def then
        local isCompleted = data.completed == true
        local def = srow._def
        
        if def.isVariation then
          -- Variations: check based on variation type
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, nil, def.variationType) then
            shouldShow = false
          end
        elseif def.isDungeonSet then
          -- Dungeon Sets: check index 4
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, 4, nil) then
            shouldShow = false
          end
        elseif def.isReputation then
          -- Reputations: check index 5
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, 5, nil) then
            shouldShow = false
          end
        elseif def.isRaid then
          -- Raids: check index 6
          if not ShouldShowByCheckboxFilter(def, isCompleted, currentFilter, 6, nil) then
            shouldShow = false
          end
        end
      end
      
      if shouldShow then
        table.insert(visibleRows, srow)
      end
  end
  
  -- Sort rows (failed to bottom, maintaining level order)
  -- Get database access for timestamps
  local _, cdb = nil, nil
  if type(HardcoreAchievements_GetCharDB) == "function" then
    _, cdb = HardcoreAchievements_GetCharDB()
  end
  
  table.sort(visibleRows, function(a, b)
    -- First, separate into three groups: completed, available, failed
    local aCompleted = a.completed or false
    local bCompleted = b.completed or false
    local aFailed = IsRowOutleveled(a)
    local bFailed = IsRowOutleveled(b)
    
    -- Determine group priority: completed (1), available (2), failed (3)
    local aGroup = aCompleted and 1 or (aFailed and 3 or 2)
    local bGroup = bCompleted and 1 or (bFailed and 3 or 2)
    
    if aGroup ~= bGroup then
      return aGroup < bGroup  -- completed first, then available, then failed
    end
    
    -- Within the same group, apply group-specific sorting
    if aGroup == 1 then
      -- Completed group: sort by completedAt timestamp descending (most recent first)
      local aId = a.id or (a.Title and a.Title.GetText and a.Title:GetText()) or ""
      local bId = b.id or (b.Title and b.Title.GetText and b.Title:GetText()) or ""
      local aRec = cdb and cdb.achievements and cdb.achievements[aId]
      local bRec = cdb and cdb.achievements and cdb.achievements[bId]
      local aTimestamp = (aRec and aRec.completedAt) or 0
      local bTimestamp = (bRec and bRec.completedAt) or 0
      if aTimestamp ~= bTimestamp then
        return aTimestamp > bTimestamp  -- Descending order (most recent first)
      end
    elseif aGroup == 2 then
      -- Available group: sort by level ascending (normal level requirement order)
      local la = (a.maxLevel ~= nil) and a.maxLevel or 9999
      local lb = (b.maxLevel ~= nil) and b.maxLevel or 9999
      if la ~= lb then return la < lb end
    elseif aGroup == 3 then
      -- Failed group: sort by failedAt timestamp descending (most recent first)
      local aId = a.id or (a.Title and a.Title.GetText and a.Title:GetText()) or ""
      local bId = b.id or (b.Title and b.Title.GetText and b.Title:GetText()) or ""
      local aFailedAt = (_G.HCA_GetFailureTimestamp and _G.HCA_GetFailureTimestamp(aId)) or 0
      local bFailedAt = (_G.HCA_GetFailureTimestamp and _G.HCA_GetFailureTimestamp(bId)) or 0
      if aFailedAt ~= bFailedAt then
        return aFailedAt > bFailedAt  -- Descending order (most recent first)
      end
    end
    
    -- Fallback: stable sort by title/id for ties
    local at = (a.Title and a.Title.GetText and a.Title:GetText()) or (a.id or "")
    local bt = (b.Title and b.Title.GetText and b.Title:GetText()) or (b.id or "")
    return tostring(at) < tostring(bt)
  end)
  
  -- Create or update rows
  for i, srow in ipairs(visibleRows) do
    local row = self.rows[i]
    if not row then
      row = CreateEmbedModernRow(self.Content, srow)
      self.rows[i] = row
    end
    
    -- Ensure row data (including timestamp) is refreshed
    UpdateEmbedModernRow(row, srow)
    
    -- Position row
    local rowSpacing = 8 -- Additional spacing for taller rows
    if i == 1 then
      row:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, 0)
    else
      row:SetPoint("TOPLEFT", self.rows[i-1], "BOTTOMLEFT", 0, -rowSpacing)
    end
    
    row:Show()
  end
  
  -- Hide any remaining rows that weren't used and their borders
  for i = #visibleRows + 1, #self.rows do
    if self.rows[i] then
      self.rows[i]:Hide()
      if self.rows[i].Border then
        self.rows[i].Border:Hide()
      end
      if self.rows[i].Background then
        self.rows[i].Background:Hide()
      end
    end
  end
  
  -- Layout rows (calculate total height)
  LayoutModernRows(self.Content, self.rows)
end

-- ---------- Layout ----------
local function LayoutIcons(container, icons)
  if not container or not icons then return end
  
  -- Only layout visible icons
  local visibleIcons = {}
  for i, icon in ipairs(icons) do
    if icon:IsShown() then
      table.insert(visibleIcons, icon)
    end
  end
  
  local totalIcons = #visibleIcons
  local rows = math.ceil(totalIcons / GRID_COLS)
  local startX = ICON_PADDING
  local startY = -ICON_PADDING
  
  for i, icon in ipairs(visibleIcons) do
    local col = ((i - 1) % GRID_COLS)
    local row = math.floor((i - 1) / GRID_COLS)
    
    local x = startX + col * (ICON_SIZE + ICON_PADDING)
    local y = startY - row * (ICON_SIZE + ICON_PADDING)
    
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
  end

  local neededH = rows * (ICON_SIZE + ICON_PADDING) + ICON_PADDING
  container:SetHeight(math.max(neededH, 1))
end

-- Keep content width synced to the scroll frame so text aligns and doesn't bunch up
local function SyncContentWidth()
  if not UHCA or not UHCA.Scroll or not UHCA.Content then return end
  local scrollWidth = UHCA.Scroll:GetWidth() or 0
  local w = math.max(scrollWidth, 1)
  UHCA.Content:SetWidth(w)

  local horizontalPadding = math.max((scrollWidth - w) * 0.5, 0)
  UHCA.Content:ClearAllPoints()
  if IsModernRowsEnabled() then
    UHCA.Content:SetPoint("TOPLEFT", UHCA.Scroll, "TOPLEFT", horizontalPadding, 0)
    UHCA.Content:SetPoint("TOPRIGHT", UHCA.Scroll, "TOPRIGHT", -horizontalPadding, 0)
  else
    UHCA.Content:SetPoint("TOPLEFT", UHCA.Scroll, "TOPLEFT", 0, 0)
    UHCA.Content:SetPoint("TOPRIGHT", UHCA.Scroll, "TOPRIGHT", 0, 0)
  end
end

-- Function to update multiplier text
local function UpdateMultiplierText()
  if not UHCA.MultiplierText then return end
  
  local preset = GetPlayerPresetFromSettings()
  local isSelfFound = IsSelfFound()
  local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
  
  local labelText = ""
  if preset or isSelfFound or isSoloMode then
      -- Build array of modifiers (preset goes last)
      local modifiers = {}
      if isSelfFound and not isSoloMode then
          table.insert(modifiers, "Self Found")
      end
      if isSoloMode and not isSelfFound then
          table.insert(modifiers, "Solo")
      end
      if isSoloMode and isSelfFound then
          table.insert(modifiers, "Solo Self Found")
      end
      if preset then
          table.insert(modifiers, preset)
      end
      
      labelText = "Point Multiplier (" .. table.concat(modifiers, ", ") .. ")"
  end
  
  UHCA.MultiplierText:SetText(labelText)
  UHCA.MultiplierText:SetTextColor(0.922, 0.871, 0.761)
end

-- Function to update total points text
local function UpdateTotalPointsText()
  if not UHCA.TotalPointsText then return end
  
  local totalPoints = 0
  if _G.HCA_GetTotalPoints then
    totalPoints = _G.HCA_GetTotalPoints()
  end
  
  -- Update the number text and its shadow
  local pointsStr = tostring(totalPoints)
  UHCA.TotalPointsText:SetText(pointsStr)
  if UHCA.TotalPointsTextShadow then
    UHCA.TotalPointsTextShadow:SetText(pointsStr)
  end
  if totalPoints > 0 then
    UHCA.TotalPointsText:SetTextColor(0.922, 0.871, 0.761)
    UHCA.PointsLabelText:SetTextColor(0.922, 0.871, 0.761)
  else
    UHCA.TotalPointsText:SetTextColor(1, 1, 1)
    UHCA.PointsLabelText:SetTextColor(1, 1, 1)
  end

  if UHCA.CountsText then
    local completed, totalCount
    if _G.HCA_AchievementCount then
      completed, totalCount = _G.HCA_AchievementCount()
    end
    if completed and totalCount then
      UHCA.CountsText:SetText(string.format(" (%d/%d)", completed or 0, totalCount or 0))
    else
      UHCA.CountsText:SetText("")
    end
  end

end

-- ---------- Rebuild ----------
function EMBED:Rebuild()
  if not UHCA or not UHCA.Content then return end
  if not self.Content then self.Content = UHCA.Content end

  SyncContentWidth()

  local srcRows = GetSourceRows()
  if not srcRows then
    if self.icons then for _, icon in ipairs(self.icons) do icon:Hide() end end
    if self.rows then for _, row in ipairs(self.rows) do row:Hide() end end
    return
  end

  -- Check if modern rows is enabled
  local useModernRows = IsModernRowsEnabled()

  if UHCA and UHCA.ScrollBackground then
    if useModernRows then
      UHCA.ScrollBackground:Hide()
    else
      UHCA.ScrollBackground:Show()
    end
  end
  
  if useModernRows then
    -- Modern rows mode: build rows similar to character panel
    self:BuildModernRows(srcRows)
  else
    -- Classic grid mode: build icons (existing behavior)
    self:BuildClassicGrid(srcRows)
  end

  UpdateMultiplierText()
  UpdateTotalPointsText()
  
  -- Update status text for all visible rows after rebuild
  if useModernRows and self.rows then
    for _, row in ipairs(self.rows) do
      if row:IsShown() then
        UpdateStatusTextEmbed(row)
      end
    end
  end
  
  -- Sync solo mode checkbox state (for both modes)
  if UHCA and UHCA.SoloModeCheckbox then
    if type(HardcoreAchievements_GetCharDB) == "function" then
      local _, cdb = HardcoreAchievements_GetCharDB()
      local isChecked = (cdb and cdb.settings and cdb.settings.soloAchievements) or false
      UHCA.SoloModeCheckbox:SetChecked(isChecked)
      
      -- Update enable/disable state based on Self-Found status
      local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
      if isSelfFound then
        UHCA.SoloModeCheckbox:Enable()
        UHCA.SoloModeCheckbox.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no help from nearby players)."
      else
        UHCA.SoloModeCheckbox:Disable()
        UHCA.SoloModeCheckbox.Text:SetTextColor(0.5, 0.5, 0.5, 1)
        --UHCA.SoloModeCheckbox.tooltip = "Require solo play (no group members nearby) to complete achievements. Doubles achievement points. |cffff0000(Requires Self-Found buff to enable)|r"
      end
    end
  end
end

-- Hide the custom Achievement tab when embedded UI loads
local function HideCustomAchievementTab()
    -- Hide the custom Achievement tab created in HardcoreAchievements.lua
    local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
    if tab and tab:GetText() and tab:GetText():find(ACHIEVEMENTS) then
        tab:Hide()
        tab:SetScript("OnClick", function() end) -- Disable click functionality
    end
    -- Also hide the custom vertical tab (square) if available
    if type(HardcoreAchievements_HideVerticalTab) == "function" then
        HardcoreAchievements_HideVerticalTab()
    end
end

-- helper: get the Achievements tab frame in both old and new UHC builds
local function GetAchievementsContainer()
  if TabManager and TabManager.getTabContent then
    local f = TabManager.getTabContent(3)
    if f then return f end
  end
  if _G.tabContents and _G.tabContents[3] then
    return _G.tabContents[3]
  end
end

-- ---------- Build / Hooks ----------
local function BuildEmbedIfNeeded()
  if UHCA and UHCA.Scroll and UHCA.Content and UHCA._initialized then return true end
  
  local container = GetAchievementsContainer()
  if not container then return false end

  UHCA = container
  
  -- Clear any existing content that UltraHardcore might have added
  local regions = {UHCA:GetRegions()}
  for i = #regions, 1, -1 do
    regions[i]:Hide()
  end
  
  -- Hide any existing text objects in the frame that aren't ours
  local function hideExistingTextObjects()
    -- Look for FontString regions (like the "Achievements Coming In Phase 3!" text)
    for _, region in ipairs({ UHCA:GetRegions() }) do
      if region.GetText then
        region:Hide()
      end
    end
  end
  
  -- Hide existing text objects
  hideExistingTextObjects()
  
  -- Hide custom achievement tab when embedded UI loads
  HideCustomAchievementTab()

  -- Only create Scroll and Content if they don't already exist
  if not UHCA.Scroll then
    UHCA.Scroll = CreateFrame("ScrollFrame", nil, UHCA, "UIPanelScrollFrameTemplate")
    -- Adjust top position to account for points background and multiplier text (tightened headspace)
    UHCA.Scroll:SetPoint("TOPLEFT", UHCA, "TOPLEFT", -4, -150)
    UHCA.Scroll:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", -8, -15)
    
    do
      local scrollBar = UHCA.Scroll and UHCA.Scroll.ScrollBar
      if scrollBar then

        local function ApplyDropdownArrowTextures(button, texturePath)
          if not button or not texturePath then return end

          local arrowR, arrowG, arrowB = 0.922, 0.871, 0.761

          button:SetNormalTexture(texturePath)
          button:SetPushedTexture(texturePath)
          button:SetDisabledTexture(texturePath)
          button:SetHighlightTexture(texturePath)
          button:SetSize(20, 20)

          local textures = {
            button:GetNormalTexture(),
            button:GetPushedTexture(),
            button:GetDisabledTexture(),
            button:GetHighlightTexture(),
          }

          for _, tex in ipairs(textures) do
            if tex then
              tex:ClearAllPoints()
              tex:SetPoint("CENTER", button, "CENTER", 0, 0)
              tex:SetSize(16, 16)
              tex:SetVertexColor(arrowR, arrowG, arrowB)
            end
          end

          local highlight = button:GetHighlightTexture()
          if highlight then
            highlight:SetBlendMode("ADD")
            highlight:SetAlpha(0.7)
            highlight:SetVertexColor(arrowR, arrowG, arrowB)
          end
        end

        ApplyDropdownArrowTextures(
          scrollBar.ScrollUpButton or scrollBar.UpButton or (scrollBar:GetName() and _G[scrollBar:GetName() .. "ScrollUpButton"]),
          "Interface\\AddOns\\HardcoreAchievements\\Images\\dropdown_arrow_up.png"
        )
        ApplyDropdownArrowTextures(
          scrollBar.ScrollDownButton or scrollBar.DownButton or (scrollBar:GetName() and _G[scrollBar:GetName() .. "ScrollDownButton"]),
          "Interface\\AddOns\\HardcoreAchievements\\Images\\dropdown_arrow_down.png"
        )

        local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()
        if thumb then
          thumb:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\thumb_box.png")
          thumb:SetSize(12, 12)
          thumb:SetTexCoord(0, 1, 0, 1)
          thumb:SetVertexColor(0.922, 0.871, 0.761)
        end
      end
    end
    
    -- Hide the scroll bar but keep it functional
    if UHCA.Scroll.ScrollBar then
      UHCA.Scroll.ScrollBar:Hide()
    end
  end
  
  if not UHCA.Content then
    UHCA.Content = CreateFrame("Frame", nil, UHCA.Scroll)
    UHCA.Content:SetSize(1, 1)
    UHCA.Scroll:SetScrollChild(UHCA.Content)
  end

  if not UHCA.ScrollBackground then
    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local background = CreateFrame("Frame", nil, UHCA, backdropTemplate)
    background:SetPoint("TOPLEFT", UHCA.Scroll, "TOPLEFT", 0, 0)
    background:SetPoint("BOTTOMRIGHT", UHCA.Scroll, "BOTTOMRIGHT", 0, 0)
    background:SetFrameStrata(UHCA.Scroll:GetFrameStrata())
    local scrollLevel = UHCA.Scroll:GetFrameLevel() or 1
    background:SetFrameLevel(scrollLevel > 0 and (scrollLevel - 1) or 0)
    background:EnableMouse(false)

    if background.SetBackdrop then
      background:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      background:SetBackdropColor(0, 0, 0, 0.45)
      background:SetBackdropBorderColor(0.282, 0.275, 0.259)
    else
      local fill = background:CreateTexture(nil, "BACKGROUND")
      fill:SetAllPoints()
      fill:SetColorTexture(0, 0, 0, 0.45)
      background.Fill = fill
    end

    background:Hide()
    UHCA.ScrollBackground = background
  end

  if not UHCA.BlurOverlayFrame then
    UHCA.BlurOverlayFrame = CreateFrame("Frame", nil, UHCA)
    UHCA.BlurOverlayFrame:SetFrameStrata("DIALOG")
    UHCA.BlurOverlayFrame:SetFrameLevel(18)
    UHCA.BlurOverlayFrame:SetAllPoints(UHCA)
  end

  if not UHCA.BlurOverlay then
    UHCA.BlurOverlay = UHCA.BlurOverlayFrame:CreateTexture(nil, "OVERLAY")
    UHCA.BlurOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\blur.png")
    UHCA.BlurOverlay:SetBlendMode("BLEND")
    UHCA.BlurOverlay:SetTexCoord(0, 1, 0, 1)
    UHCA.BlurOverlay:SetPoint("BOTTOMLEFT", UHCA.BlurOverlayFrame, "BOTTOMLEFT", -18, -47)
    UHCA.BlurOverlay:SetPoint("BOTTOMRIGHT", UHCA.BlurOverlayFrame, "BOTTOMRIGHT", 18, -47)
  end

  if not UHCA.UIOverlayFrame then
    UHCA.UIOverlayFrame = CreateFrame("Frame", nil, UHCA.BlurOverlayFrame)
    UHCA.UIOverlayFrame:SetAllPoints(UHCA)
    UHCA.UIOverlayFrame:SetFrameStrata("DIALOG")
    UHCA.UIOverlayFrame:SetFrameLevel(19)
  end

  -- Class icon (centered over background, with drop shadow)
  if not UHCA.ClassIcon then
    UHCA.ClassIcon = UHCA:CreateTexture(nil, "OVERLAY")
    UHCA.ClassIcon:SetPoint("BOTTOMRIGHT", UHCA.Scroll, "TOPRIGHT", 0, 40)
    UHCA.ClassIcon:SetTexCoord(0, 1, 0, 1)
    UHCA.ClassIcon:SetSize(44, 44)
  end

  UpdateEmbedClassIcon()

  -- Points number text (with drop shadow)
  if not UHCA.TotalPointsText then
    UHCA.TotalPointsText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    UHCA.TotalPointsText:SetPoint("TOPLEFT", UHCA, "TOPLEFT", -7, -60)
    UHCA.TotalPointsText:SetText("0") -- Will be updated by UpdateTotalPointsText
    UHCA.TotalPointsText:SetTextColor(0.922, 0.871, 0.761)
    UHCA.TotalPointsText:SetFont(POINTS_FONT_PATH, 42)
  end

  -- Points number drop shadow
  if not UHCA.TotalPointsTextShadow then
    UHCA.TotalPointsTextShadow = UHCA:CreateFontString(nil, "BACKGROUND", "GameFontHighlightHuge")
    UHCA.TotalPointsTextShadow:SetPoint("CENTER", UHCA.TotalPointsText, "CENTER", 1, -1)
    UHCA.TotalPointsTextShadow:SetText("0")
    UHCA.TotalPointsTextShadow:SetTextColor(0, 0, 0, 0.5)
    UHCA.TotalPointsTextShadow:SetDrawLayer("BACKGROUND", 0)
    UHCA.TotalPointsTextShadow:SetFont(POINTS_FONT_PATH, 42)
  end

  -- " pts" text (smaller, positioned after the number)
  if not UHCA.PointsLabelText then
    UHCA.PointsLabelText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    -- Position it to the right of the points number
    UHCA.PointsLabelText:SetPoint("LEFT", UHCA.TotalPointsText, "RIGHT", 2, 0)
    UHCA.PointsLabelText:SetText(" pts")
    UHCA.PointsLabelText:SetTextColor(0.922, 0.871, 0.761)
    UHCA.PointsLabelText:SetFont(POINTS_FONT_PATH, 32)
  end

  -- Player name text (centered above the points background)
  if not UHCA.PlayerNameText then
    UHCA.PlayerNameText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    UHCA.PlayerNameText:SetPoint("TOPLEFT", UHCA.TotalPointsText, "BOTTOMLEFT", 2, -6)
    UHCA.PlayerNameText:SetJustifyH("LEFT")
    UHCA.PlayerNameText:SetText(GetUnitName('player')) -- Will be updated by UpdatePlayerNameText
    --UHCA.PlayerNameText:SetTextColor(0.42, 0.396, 0.345)
    UHCA.PlayerNameText:SetTextColor(GetPlayerClassColor())
  end

  -- Achievement completion counter (next to player name)
  if not UHCA.CountsText then
    UHCA.CountsText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.CountsText:SetPoint("BOTTOMLEFT", UHCA.TotalPointsText, "TOPLEFT", 0, 0)
    UHCA.CountsText:SetText("(0/0)")
    UHCA.CountsText:SetTextColor(0.8, 0.8, 0.8)
    UHCA.CountsText:SetJustifyH("LEFT")
  end

  -- Multiplier text (below the points background)
  if not UHCA.MultiplierText then
    UHCA.MultiplierText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.MultiplierText:SetPoint("TOPLEFT", UHCA.PlayerNameText, "BOTTOMLEFT", 1, - 12) -- Positioned below with spacing
    UHCA.MultiplierText:SetText("") -- Will be set by UpdateMultiplierText
  end

  -- Settings button (cogwheel icon) in bottom left of frame
  if not UHCA.SettingsButton then
    local parent = UHCA.UIOverlayFrame or UHCA
    UHCA.SettingsButton = CreateFrame("Button", nil, parent)
    UHCA.SettingsButton:SetSize(10, 10)
    UHCA.SettingsButton:SetPoint("BOTTOMLEFT", UHCA, "BOTTOMLEFT", -5, -40)
    UHCA.SettingsButton:SetFrameLevel(19)
    
    -- Create cogwheel icon texture (using a simple circular button style)
    UHCA.SettingsButton.Icon = UHCA.SettingsButton:CreateTexture(nil, "ARTWORK")
    UHCA.SettingsButton.Icon:SetAllPoints(UHCA.SettingsButton)
    -- Use addon-provided gear icon texture
    UHCA.SettingsButton.Icon:SetTexture(SETTINGS_ICON_TEXTURE)
    UHCA.SettingsButton.Icon:SetVertexColor(GetPlayerClassColor())
    
    -- Click handler to open Options panel
    UHCA.SettingsButton:SetScript("OnClick", function(self)
      if _G.HardcoreAchievements_OpenOptionsPanel then
        _G.HardcoreAchievements_OpenOptionsPanel()
      end
    end)
    
    -- Tooltip
    UHCA.SettingsButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Open Options", nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    
    UHCA.SettingsButton:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
  end

  if not UHCA.LayoutLabel then
    local parent = UHCA.UIOverlayFrame or UHCA
    UHCA.LayoutLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.LayoutLabel:SetPoint("LEFT", UHCA.SettingsButton, "RIGHT", 25, 0)
    UHCA.LayoutLabel:SetText("Layout:")
    UHCA.LayoutLabel:SetTextColor(0.922, 0.871, 0.761)
    UHCA.LayoutLabel:SetDrawLayer("OVERLAY", 7)
  end

  if not UHCA.LayoutListCheckbox then
    local parent = UHCA.UIOverlayFrame or UHCA
    UHCA.LayoutListCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    UHCA.LayoutListCheckbox:SetPoint("LEFT", UHCA.LayoutLabel, "RIGHT", 6, 0)
    UHCA.LayoutListCheckbox:SetSize(10, 10)
    UHCA.LayoutListCheckbox:SetFrameLevel(19)
    UHCA.LayoutListCheckbox.text:SetText("List")
    UHCA.LayoutListCheckbox.text:SetTextColor(0.922, 0.871, 0.761)
    UHCA.LayoutListCheckbox.text:ClearAllPoints()
    UHCA.LayoutListCheckbox.text:SetPoint("LEFT", UHCA.LayoutListCheckbox, "RIGHT", 5, 0)
    ApplyCustomCheckboxTextures(UHCA.LayoutListCheckbox)
    UHCA.LayoutListCheckbox:SetScript("OnClick", function(self)
      if not self:GetChecked() then
        self:SetChecked(true)
        return
      end
      SetModernRowsEnabled(true)
    end)
  end

  if not UHCA.LayoutGridCheckbox then
    local parent = UHCA.UIOverlayFrame or UHCA
    UHCA.LayoutGridCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    UHCA.LayoutGridCheckbox:SetPoint("LEFT", UHCA.LayoutListCheckbox.text, "RIGHT", 6, 0)
    UHCA.LayoutGridCheckbox:SetSize(10, 10)
    UHCA.LayoutGridCheckbox:SetFrameLevel(19)
    UHCA.LayoutGridCheckbox.text:SetText("Grid")
    UHCA.LayoutGridCheckbox.text:SetTextColor(0.922, 0.871, 0.761)
    UHCA.LayoutGridCheckbox.text:ClearAllPoints()
    UHCA.LayoutGridCheckbox.text:SetPoint("LEFT", UHCA.LayoutGridCheckbox, "RIGHT", 5, 0)
    ApplyCustomCheckboxTextures(UHCA.LayoutGridCheckbox)
    UHCA.LayoutGridCheckbox:SetScript("OnClick", function(self)
      if not self:GetChecked() then
        self:SetChecked(true)
        return
      end
      SetModernRowsEnabled(false)
    end)
  end

  UpdateLayoutCheckboxes(IsModernRowsEnabled())

  -- Solo mode checkbox
  if not UHCA.SoloModeCheckbox then
    local parent = UHCA.UIOverlayFrame or UHCA
    UHCA.SoloModeCheckbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    UHCA.SoloModeCheckbox:SetPoint("LEFT", UHCA.LayoutGridCheckbox.text, "RIGHT", 6, 0)
    UHCA.SoloModeCheckbox:SetSize(10, 10)
    UHCA.SoloModeCheckbox:SetFrameLevel(19)
    UHCA.SoloModeCheckbox.Text:SetText("SSF")
    UHCA.SoloModeCheckbox.Text:SetTextColor(0.922, 0.871, 0.761)
    UHCA.SoloModeCheckbox.Text:ClearAllPoints()
    UHCA.SoloModeCheckbox.Text:SetPoint("LEFT", UHCA.SoloModeCheckbox, "RIGHT", 5, 0)
    ApplyCustomCheckboxTextures(UHCA.SoloModeCheckbox)
    UHCA.SoloModeCheckbox:SetScript("OnClick", function(self)
      if self:IsEnabled() then
        local isChecked = self:GetChecked()
        if type(HardcoreAchievements_GetCharDB) == "function" then
          local _, cdb = HardcoreAchievements_GetCharDB()
          if cdb and cdb.settings then
            cdb.settings.soloAchievements = isChecked
            -- Refresh all achievement points immediately
            if RefreshAllAchievementPoints then
              RefreshAllAchievementPoints()
            end
            -- Update status text for all embed rows after solo mode toggle
            if EMBED and EMBED.rows then
              for _, row in ipairs(EMBED.rows) do
                if row:IsShown() then
                  UpdateStatusTextEmbed(row)
                end
              end
            end
          end
        end
      end
    end)
    UHCA.SoloModeCheckbox:SetScript("OnEnter", function(self)
      if self.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
        GameTooltip:Show()
      end
    end)
    UHCA.SoloModeCheckbox:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
  end

  -- Only create filter dropdown if it doesn't exist
  local filterDropdown = UHCA.FilterDropdown
  if not filterDropdown then
    -- Create and style the dropdown using shared FilterDropdown module
    filterDropdown = FilterDropdown:CreateDropdown(UHCA, "TOP", UHCA.ClassIcon, -30, -58, 87)
    UHCA.FilterDropdown = filterDropdown
    
    -- Initialize filter dropdown
    FilterDropdown:InitializeDropdown(filterDropdown, {
      currentFilter = currentFilter,
      -- checkboxStates will be loaded from database automatically
      checkboxLabels = { "Show Dungeon Trios", "Show Dungeon Duos", "Show Dungeon Solos", "Show Dungeon Sets", "Show Reputations", "Show Raids" },
      onFilterChange = function(filterValue)
        currentFilter = filterValue
        ApplyFilter()
      end,
      onCheckboxChange = function(checkboxIndex, newState)
        -- Checkbox state is automatically saved to database in FilterDropdown
        -- Handle any additional logic if needed
        ApplyFilter()  -- Re-apply filter when checkbox changes
      end,
    })
  end

  if not UHCA.HideCustomTabCheckbox then
    -- Add label for the checkbox
    local labelParent = UHCA.UIOverlayFrame or UHCA
    UHCA.HideCustomTabLabel = labelParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.HideCustomTabLabel:SetPoint("RIGHT", UHCA.Scroll, "BOTTOMRIGHT", 0, -20)
    UHCA.HideCustomTabLabel:SetText("Show Achievements on the Character Info Panel")
    UHCA.HideCustomTabLabel:SetTextColor(0.922, 0.871, 0.761)
    UHCA.HideCustomTabLabel:SetDrawLayer("OVERLAY", 10)

    -- Add checkbox to control custom tab visibility
    UHCA.HideCustomTabCheckbox = CreateFrame("CheckButton", nil, UHCA, "UICheckButtonTemplate")
    UHCA.HideCustomTabCheckbox:SetPoint("RIGHT", UHCA.HideCustomTabLabel, "LEFT", -8, 0)
    UHCA.HideCustomTabCheckbox:SetSize(10, 10)
    UHCA.HideCustomTabCheckbox:SetFrameLevel(19)
    ApplyCustomCheckboxTextures(UHCA.HideCustomTabCheckbox)
    
    local function GetShowCustomTabSetting()
      if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings and cdb.settings.showCustomTab ~= nil then
          return cdb.settings.showCustomTab == true
        end
      end
      return true -- Default to showing custom tab
    end
    UHCA.HideCustomTabCheckbox:SetChecked(GetShowCustomTabSetting()) -- Default to showing custom tab, but respect saved state
    
    -- Handle checkbox changes
    UHCA.HideCustomTabCheckbox:SetScript("OnClick", function(self)
      local isChecked = self:GetChecked()
      local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
      
      -- Save the state to the database
      if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
          cdb.settings = cdb.settings or {}
          cdb.settings.showCustomTab = isChecked
        end
      end
      
      if tab and tab:GetText() and tab:GetText():find(ACHIEVEMENTS) then
        if isChecked then
          -- Show custom tab
          tab:Show()
          tab:SetScript("OnClick", function(self)
            -- Use the same logic as the main achievement tab
            if HCA_ShowAchievementTab then
              HCA_ShowAchievementTab()
            end
          end)
          -- Also restore vertical tab if it was in vertical mode
          if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
            _G.HardcoreAchievements_LoadTabPosition()
          end
        else
          -- Hide custom tab
          tab:Hide()
          tab:SetScript("OnClick", function() end) -- Disable click functionality
          -- Also hide vertical tab immediately
          if type(_G.HardcoreAchievements_HideVerticalTab) == "function" then
            _G.HardcoreAchievements_HideVerticalTab()
          end
        end
      end
    end)
  end

  EMBED.Content = UHCA.Content
  SyncContentWidth()
  
  -- Apply saved state on initialization
  local savedState = nil
  if type(HardcoreAchievements_GetCharDB) == "function" then
    local _, cdb = HardcoreAchievements_GetCharDB()
    if cdb and cdb.settings then
      savedState = cdb.settings.showCustomTab
    end
  end
  if savedState ~= nil then
    local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
    if tab and tab:GetText() and tab:GetText():find(ACHIEVEMENTS) then
      if savedState then
        -- Show custom tab
        tab:Show()
        tab:SetScript("OnClick", function(self)
          -- Use the same logic as the main achievement tab
          if HCA_ShowAchievementTab then
            HCA_ShowAchievementTab()
          end
        end)
      else
        -- Hide custom tab
        tab:Hide()
        tab:SetScript("OnClick", function() end) -- Disable click functionality
        if type(HardcoreAchievements_HideVerticalTab) == "function" then
            HardcoreAchievements_HideVerticalTab()
        end
      end
    end
  end

  -- Only hook once to prevent duplicate scripts
  if not UHCA._hooked then
    UHCA:HookScript("OnShow", function()
      if not EMBED.Content or EMBED.Content ~= UHCA.Content then
        EMBED.Content = UHCA.Content
      end
      SyncContentWidth()
      ApplyFilter()
    end)

    UHCA.Scroll:SetScript("OnSizeChanged", function(self)
      self:UpdateScrollChildRect()
      SyncContentWidth()
      ApplyFilter()
    end)
    
    UHCA._hooked = true
  end

  UHCA._initialized = true
  return true
end

local function HookSourceSignals()
  if EMBED._hooked then return end
  if type(CheckPendingCompletions) == "function" then
    hooksecurefunc("CheckPendingCompletions", function()
      C_Timer.After(0, function() 
        if EMBED.Rebuild then EMBED:Rebuild() else ApplyFilter() end
      end)
    end)
  end
  if type(HCA_UpdateTotalPoints) == "function" then
    hooksecurefunc("HCA_UpdateTotalPoints", function()
      C_Timer.After(0, function() 
        if EMBED.Rebuild then EMBED:Rebuild() else ApplyFilter() end
      end)
    end)
  end
  EMBED._hooked = true
end

local function HookTabManager()
  if EMBED._tmHooked or not TabManager or not TabManager.switchToTab then return end
  local orig = TabManager.switchToTab
  TabManager.switchToTab = function(index)
    orig(index)
    if index == 3 then
      C_Timer.After(0, function()
        if BuildEmbedIfNeeded() then ApplyFilter() end
      end)
    end
  end
  EMBED._tmHooked = true
end

local function IsUltraHardcoreAddonName(name)
  if type(name) ~= "string" then
    return false
  end
  local normalized = name:lower():gsub("[^%w]", "")
  return normalized:find("ultrahardcore", 1, true) ~= nil
end

local function FindLoadedUltraHardcoreAddon()
  if GetNumAddOns and GetAddOnInfo then
    for i = 1, GetNumAddOns() do
      local candidate = GetAddOnInfo(i)
      if IsUltraHardcoreAddonName(candidate) then
        local loaded = false
        if C_AddOns and C_AddOns.IsAddOnLoaded then
          loaded = C_AddOns.IsAddOnLoaded(candidate)
        elseif IsAddOnLoaded then
          loaded = IsAddOnLoaded(candidate)
        end
        if loaded then
          return candidate
        end
      end
    end
  end

  if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("UltraHardcore") then
    return "UltraHardcore"
  end
  if IsAddOnLoaded and IsAddOnLoaded("UltraHardcore") then
    return "UltraHardcore"
  end
end

local function HandleUltraHardcoreMissing()
  if EMBED._uhcMissingHandled then return end
  EMBED._uhcMissingHandled = true

  --print("|cff00ff00[Hardcore Achievements]|r UltraHardcore addon not detected")

  if type(HardcoreAchievements_GetCharDB) == "function" then
    local _, cdb = HardcoreAchievements_GetCharDB()
    if cdb then
      cdb.settings = cdb.settings or {}
      cdb.settings.showCustomTab = true

      if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
        _G.HardcoreAchievements_LoadTabPosition()
      end

      local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
      if tab and tab:GetText() and tab:GetText():find(ACHIEVEMENTS) then
        tab:Show()
        tab:EnableMouse(true)
        tab:SetScript("OnClick", function(self)
          if HCA_ShowAchievementTab then
            HCA_ShowAchievementTab()
          end
        end)

        local point = tab:GetPoint()
        if not point then
          tab:SetPoint("RIGHT", _G["CharacterFrameTab" .. CharacterFrame.numTabs], "RIGHT", 43, 0)
        end

        if not tab:IsShown() then
          tab:Show()
        end
      end
    end
  end
end

local function HandleUltraHardcoreDetected(addonName)
  if EMBED._uhcDetected then return end
  EMBED._uhcDetected = true

  --print(string.format("|cff00ff00[Hardcore Achievements]|r %s addon detected", addonName or "UltraHardcore"))

  HookTabManager()
  HookSourceSignals()

  C_Timer.After(0.5, function()
    if BuildEmbedIfNeeded() then
      C_Timer.After(0, function()
        if EMBED.Rebuild then EMBED:Rebuild() else ApplyFilter() end
      end)
    end
  end)

  C_Timer.After(2.0, function()
    if not UHCA and tabContents and tabContents[3] then
      if BuildEmbedIfNeeded() then
        C_Timer.After(0, function()
          if EMBED.Rebuild then EMBED:Rebuild() else ApplyFilter() end
        end)
      end
    end
  end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" then
    if IsUltraHardcoreAddonName(addonName) then
      HandleUltraHardcoreDetected(addonName)
    elseif addonName == ADDON_NAME then
      C_Timer.After(0, function()
        if EMBED._uhcDetected then return end
        local loadedName = FindLoadedUltraHardcoreAddon()
        if loadedName then
          HandleUltraHardcoreDetected(loadedName)
        end
      end)
    end
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if EMBED._uhcDetected then return end
    local loadedName = FindLoadedUltraHardcoreAddon()
    if loadedName then
      HandleUltraHardcoreDetected(loadedName)
    else
      HandleUltraHardcoreMissing()
    end
  end
end)
