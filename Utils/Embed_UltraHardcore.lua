local ADDON_NAME = ...
local EMBED = {}
local UHCA -- tabContents[3]
local ICON_SIZE = 60
local ICON_PADDING = 12
local GRID_COLS = 7  -- Number of columns in the grid
local currentFilter = "all"  -- Current filter state

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

-- Helper function to check if row is outleveled (must be defined before functions that use it)
local function IsRowOutleveled(row)
  if not row or row.completed then return false end
  if not row.maxLevel then return false end
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
end

local function UpdatePointsDisplayEmbed(row)
    if not row or not row.PointsFrame then return end
    
    if row.completed then
        if row.Points then row.Points:SetAlpha(0) end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-Ready.blp")
            row.PointsFrame.Checkmark:Show()
        end
        if row.PointsFrame.Texture then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_gold.blp")
        end
        if row.IconOverlay then row.IconOverlay:Hide() end
        if row.Sub then row.Sub:SetTextColor(1, 1, 1) end
        if row.Title then row.Title:SetTextColor(1, 0.82, 0) end
    elseif IsRowOutleveled(row) then
        if row.Points then row.Points:SetAlpha(0) end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.blp")
            row.PointsFrame.Checkmark:Show()
        end
        if row.PointsFrame.Texture then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_failed.blp")
        end
        if row.IconOverlay then
            row.IconOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.blp")
            row.IconOverlay:Show()
        end
        if row.Sub then row.Sub:SetTextColor(0.5, 0.5, 0.5) end
        if row.Title then row.Title:SetTextColor(0.957, 0.263, 0.212) end
    else
        if row.Points then row.Points:SetAlpha(1) end
        if row.PointsFrame.Checkmark then row.PointsFrame.Checkmark:Hide() end
        if row.PointsFrame.Texture then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.blp")
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
        if IsRowOutleveled(row) then
            row.Icon:SetDesaturated(false)
        elseif row.completed then
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

local function PopulateFilterDropdown()
  local filterList = {
    { text = ACHIEVEMENTFRAME_FILTER_ALL, value = "all" },
    { text = ACHIEVEMENTFRAME_FILTER_COMPLETED, value = "completed" },
    { text = ACHIEVEMENTFRAME_FILTER_INCOMPLETE, value = "not_completed" },
    { text = FAILED, value = "failed" },
  }
  return filterList
end

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
  }
end

-- ---------- Icon Factory ----------
local function CreateEmbedIcon(parent)
  local icon = CreateFrame("Button", nil, parent)
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:RegisterForClicks("AnyUp")

  -- Create the achievement icon
  icon.Icon = icon:CreateTexture(nil, "ARTWORK")
  icon.Icon:SetSize(ICON_SIZE - 2, ICON_SIZE - 2)
  icon.Icon:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.Icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

  -- Create circular mask for the icon
  icon.Mask = icon:CreateMaskTexture()
  icon.Mask:SetAllPoints(icon.Icon)
  icon.Mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  icon.Icon:AddMaskTexture(icon.Mask)

  -- Create completion border as a green circle behind the icon
  icon.GreenBorder = icon:CreateTexture(nil, "BACKGROUND")
  icon.GreenBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2) -- Slightly larger than icon
  icon.GreenBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.GreenBorder:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  icon.GreenBorder:SetTexCoord(0, 1, 0, 1)
  icon.GreenBorder:SetVertexColor(0.6, 0.9, 0.6, 0.8) -- Green circle
  icon.GreenBorder:Hide()

  -- Create failed border as a red circle behind the icon
  icon.RedBorder = icon:CreateTexture(nil, "BACKGROUND")
  icon.RedBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2) -- Slightly larger than icon
  icon.RedBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.RedBorder:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  icon.RedBorder:SetTexCoord(0, 1, 0, 1)
  icon.RedBorder:SetVertexColor(0.53, 0.02, 0.03, 0.8) -- Red circle
  icon.RedBorder:Hide()

      -- Create available border as a yellow circle behind the icon
  icon.YellowBorder = icon:CreateTexture(nil, "BACKGROUND")
  icon.YellowBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2) -- Slightly larger than icon
  icon.YellowBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.YellowBorder:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  icon.YellowBorder:SetTexCoord(0, 1, 0, 1)
  icon.YellowBorder:SetVertexColor(1, 0.82, 0, 0.8) -- Goldish yellow circle
  icon.YellowBorder:Hide()
  
  -- Create SSF mode border as a purple/blue glow circle around the icon
  icon.SSFBorder = icon:CreateTexture(nil, "BACKGROUND")
  icon.SSFBorder:SetSize(ICON_SIZE + 4, ICON_SIZE + 4) -- Slightly larger than other borders
  icon.SSFBorder:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.SSFBorder:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  icon.SSFBorder:SetTexCoord(0, 1, 0, 1)
  icon.SSFBorder:SetVertexColor(0.5, 0.3, 0.9, 0.6) -- Purple glow
  icon.SSFBorder:Hide()

  icon:SetScript("OnEnter", function(self)
    -- Use centralized tooltip function with source row directly
    if _G.HCA_ShowAchievementTooltip and self.sourceRow then
      _G.HCA_ShowAchievementTooltip(self, self.sourceRow)
    end
  end)
  
  -- Shift + Left Click to link achievement bracket into chat (matches CreateAchievementRow behavior)
  icon:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and self.achId then
      local iconTexture = self.Icon and self.Icon.GetTexture and self.Icon:GetTexture() or ""
      -- Use centralized function to generate bracket format
      local bracket = _G.HCA_GetAchievementBracket and _G.HCA_GetAchievementBracket(self.achId, iconTexture) or string.format("[HCA:(%s,%s)]", tostring(self.achId), tostring(iconTexture))

      local editBox = ChatEdit_GetActiveWindow()
      if not editBox or not editBox:IsVisible() then
        return
      end
      local currentText = editBox and (editBox:GetText() or "") or ""
      if currentText == "" then
        editBox:SetText(bracket)
      else
        editBox:SetText(currentText .. " " .. bracket)
      end
      editBox:SetFocus()
      return
    end
  end)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
  local startY = -2
  
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

        if data.iconTex then
          icon.Icon:SetTexture(data.iconTex)
        else
          icon.Icon:SetTexture(136116) -- generic achievement icon
        end

        -- Set icon appearance based on status
        if data.completed then
          -- Completed: full color
          icon.Icon:SetDesaturated(false)
          icon.Icon:SetAlpha(1.0)
          icon.Icon:SetVertexColor(1.0, 1.0, 1.0)
        else
          local isOverLeveled = false
          if data.maxLevel and data.maxLevel > 0 then
            local playerLevel = UnitLevel("player") or 0
            isOverLeveled = playerLevel > data.maxLevel
          end
          if isOverLeveled then
            -- Over-leveled: soft red tint, not desaturated
            icon.Icon:SetDesaturated(true)
            icon.Icon:SetAlpha(1.0)
            icon.Icon:SetVertexColor(1.0, 0.7, 0.7)
          else
            -- Incomplete and available: desaturated
            icon.Icon:SetDesaturated(true)
            icon.Icon:SetAlpha(1.0)
            icon.Icon:SetVertexColor(1.0, 1.0, 1.0)
          end
        end

        -- Set completion border
        if icon.achId and icon.achId ~= "Secret100" then
          if data.completed then
            icon.GreenBorder:Show()
            icon.YellowBorder:Hide()
            icon.RedBorder:Hide()
          elseif data.outleveled then
            icon.RedBorder:Show()
            icon.GreenBorder:Hide()
            icon.YellowBorder:Hide()
          else
            icon.YellowBorder:Show()
            icon.GreenBorder:Hide()
            icon.RedBorder:Hide()
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
    row.IconFrameGold:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_gold.blp")
    row.IconFrameGold:SetDrawLayer("OVERLAY", 1)
    row.IconFrameGold:Hide()
    
    -- Silver frame (available/disabled) - default
    row.IconFrame = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrame:SetSize(42, 42)
    row.IconFrame:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrame:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_silver.blp")
    row.IconFrame:SetDrawLayer("OVERLAY", 1)
    row.IconFrame:Show()
    
    -- Icon overlay (for failed state - red X)
    row.IconOverlay = row:CreateTexture(nil, "OVERLAY")
    row.IconOverlay:SetSize(24, 24) -- Increased from 20x20 to 24x24 to match scale
    row.IconOverlay:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconOverlay:Hide()
    
    -- title
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 8, 10)
    row.Title:SetText(title)
    row.Title:SetTextColor(1, 1, 1)
    
    -- title drop shadow (strip color codes so shadow is always black)
    row.TitleShadow = row:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    row.TitleShadow:SetPoint("LEFT", row.Icon, "RIGHT", 9, 9)
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
    -- Status text will be set by UpdateStatusTextEmbed
    
    -- Circular frame for points (increased size)
    row.PointsFrame = CreateFrame("Frame", nil, row)
    row.PointsFrame:SetSize(56, 56) -- Increased from 48x48 to 56x56
    row.PointsFrame:SetPoint("RIGHT", row, "RIGHT", -15, -2)
    
    row.PointsFrame.Texture = row.PointsFrame:CreateTexture(nil, "BACKGROUND")
    row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.blp")
    row.PointsFrame.Texture:SetAllPoints(row.PointsFrame)
    
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
    row.TS:SetPoint("RIGHT", row.PointsFrame, "LEFT", -5, -2)
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
    row.Background:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.blp")
    row.Background:SetVertexColor(1, 1, 1)
    row.Background:SetAlpha(1)
    row.Background:Hide()
    
    row.Border = UHCA.BorderClip:CreateTexture(nil, "BACKGROUND")
    row.Border:SetDrawLayer("BACKGROUND", 1)
    row.Border:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row-border.blp")
    row.Border:SetSize(256, 32)
    row.Border:SetAlpha(0.5)
    row.Border:Hide()
    
    -- highlight/tooltip
    row:EnableMouse(true)
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    -- Set highlight to match border positioning (extends 4px left to match border, 2px right)
    row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, 0)
    row.highlight:SetColorTexture(1, 1, 1, 0.10)
    row.highlight:Hide()
    
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        if _G.HCA_ShowAchievementTooltip then
            _G.HCA_ShowAchievementTooltip(self, srow)
        end
    end)
    
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    
    -- Store reference to source row
    row._achId = achId
    row._title = title
    row._tooltip = tooltip
    row._zone = zone
    row._def = def
    row.sourceRow = srow
    
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
    if row.Title then 
        row.Title:SetText(title)
        if row.TitleShadow then row.TitleShadow:SetText(StripColorCodes(title)) end
    end
    if row.Points then row.Points:SetText(tostring(points)) end
    
    -- Update stored data
    row.achId = achId
    row.id = achId
    row.points = points
    row.completed = srow.completed or false
    row.maxLevel = level > 0 and level or nil
    row.sourceRow = srow
    row._def = def
    
    if not row.Background and UHCA then
        if not UHCA.BorderClip then
            UHCA.BorderClip = CreateFrame("Frame", nil, UHCA)
            UHCA.BorderClip:SetPoint("TOPLEFT", UHCA.Scroll, "TOPLEFT", -10, 2)
            UHCA.BorderClip:SetPoint("BOTTOMRIGHT", UHCA.Scroll, "BOTTOMRIGHT", 10, -2)
            UHCA.BorderClip:SetClipsChildren(true)
        end
        row.Background = UHCA.BorderClip:CreateTexture(nil, "BACKGROUND")
        row.Background:SetDrawLayer("BACKGROUND", 0)
        row.Background:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.blp")
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
      
      if shouldShow then
        table.insert(visibleRows, srow)
      end
  end
  
  -- Sort rows (failed to bottom, maintaining level order)
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
    
    -- Within same group, sort by level
    local la = (a.maxLevel ~= nil) and a.maxLevel or 9999
    local lb = (b.maxLevel ~= nil) and b.maxLevel or 9999
    if la ~= lb then return la < lb end
    
    -- Fallback by title
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
  local startY = -2
  
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
  local w = math.max(UHCA.Scroll:GetWidth(), 1)
  UHCA.Content:SetWidth(w)
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
  UHCA.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
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
    UHCA.TotalPointsText:SetTextColor(0.6, 0.9, 0.6)
    UHCA.PointsLabelText:SetTextColor(0.6, 0.9, 0.6)
  else
    UHCA.TotalPointsText:SetTextColor(1, 1, 1)
    UHCA.PointsLabelText:SetTextColor(1, 1, 1)
  end

  if UHCA.PointsBackground then
    if totalPoints > 0 then
      UHCA.PointsBackground:SetDesaturated(true)
      UHCA.PointsBackground:SetVertexColor(0.6, 0.9, 0.6, 1)
    else
      UHCA.PointsBackground:SetVertexColor(1, 1, 1, 1)
      UHCA.PointsBackground:SetDesaturated(false)
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
        UHCA.SoloModeCheckbox.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no party members within 40 yards)."
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
    UHCA.Scroll:SetPoint("TOPLEFT", UHCA, "TOPLEFT", -4, -80)
    UHCA.Scroll:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", -8, -15)
    
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

  -- Only create UI elements if they don't exist
  -- Points background texture (centered horizontally at top)
  if not UHCA.PointsBackground then
    UHCA.PointsBackground = UHCA:CreateTexture(nil, "BACKGROUND")
    UHCA.PointsBackground:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\points-bg.blp")
    -- Size adjusted: wider and shorter
    local bgWidth = 300  -- Increased width
    local bgHeight = 30  -- Reduced height
    UHCA.PointsBackground:SetSize(bgWidth, bgHeight)
    UHCA.PointsBackground:SetPoint("TOP", UHCA, "TOP", 0, -30) -- Brought down a bit
    UHCA.PointsBackground:SetDesaturated(false)
    UHCA.PointsBackground:SetAlpha(0.7)
    UHCA.PointsBackground:SetVertexColor(1, 1, 1, 1)
  end

  -- Points number text (centered over background, with drop shadow)
  if not UHCA.TotalPointsText then
    UHCA.TotalPointsText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    UHCA.TotalPointsText:SetPoint("CENTER", UHCA.PointsBackground, "CENTER", 0, -1)
    UHCA.TotalPointsText:SetText("0") -- Will be updated by UpdateTotalPointsText
    UHCA.TotalPointsText:SetTextColor(0.6, 0.9, 0.6)
  end

  -- Points number drop shadow
  if not UHCA.TotalPointsTextShadow then
    UHCA.TotalPointsTextShadow = UHCA:CreateFontString(nil, "BACKGROUND", "GameFontHighlightLarge")
    UHCA.TotalPointsTextShadow:SetPoint("CENTER", UHCA.PointsBackground, "CENTER", 1, -1)
    UHCA.TotalPointsTextShadow:SetText("0")
    UHCA.TotalPointsTextShadow:SetTextColor(0, 0, 0, 0.5)
    UHCA.TotalPointsTextShadow:SetDrawLayer("BACKGROUND", 0)
  end

  -- " pts" text (smaller, positioned after the number)
  if not UHCA.PointsLabelText then
    UHCA.PointsLabelText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- Position it to the right of the points number
    UHCA.PointsLabelText:SetPoint("LEFT", UHCA.TotalPointsText, "RIGHT", 2, 0)
    UHCA.PointsLabelText:SetText(" pts")
    UHCA.PointsLabelText:SetTextColor(1, 1, 1)
  end

  -- Multiplier text (below the points background)
  if not UHCA.MultiplierText then
    UHCA.MultiplierText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.MultiplierText:SetPoint("TOP", UHCA.PointsBackground, "BOTTOM", 0, -5) -- Positioned below with spacing
    UHCA.MultiplierText:SetText("") -- Will be set by UpdateMultiplierText
  end

  -- Solo mode checkbox
  if not UHCA.SoloModeCheckbox then
    UHCA.SoloModeCheckbox = CreateFrame("CheckButton", nil, UHCA, "InterfaceOptionsCheckButtonTemplate")
    UHCA.SoloModeCheckbox:SetPoint("TOPLEFT", UHCA, "TOPLEFT", -10, -30)
    UHCA.SoloModeCheckbox.Text:SetText("SSF")
    UHCA.SoloModeCheckbox.Text:SetTextColor(1, 1, 1, 1)
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

  -- Settings button (cogwheel icon) in bottom left of frame
  if not UHCA.SettingsButton then
    UHCA.SettingsButton = CreateFrame("Button", nil, UHCA)
    UHCA.SettingsButton:SetSize(16, 16)
    UHCA.SettingsButton:SetPoint("BOTTOMLEFT", UHCA, "BOTTOMLEFT", -10, -40)
    
    -- Create cogwheel icon texture (using a simple circular button style)
    UHCA.SettingsButton.Icon = UHCA.SettingsButton:CreateTexture(nil, "ARTWORK")
    UHCA.SettingsButton.Icon:SetAllPoints(UHCA.SettingsButton)
    -- Use a simple circular icon - try using the minimap button background or a simple texture
    UHCA.SettingsButton.Icon:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
    UHCA.SettingsButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
    -- Click handler to open Options panel
    UHCA.SettingsButton:SetScript("OnClick", function(self)
      -- Try to open via Settings API first
      if Settings and Settings.OpenToCategory then
        -- Get the addon reference
        local addon = _G.HardcoreAchievementsAddon
        if addon and addon.settingsCategory then
          Settings.OpenToCategory(addon.settingsCategory:GetID())
        elseif _G._HardcoreAchievementsOptionsCategory then
          Settings.OpenToCategory(_G._HardcoreAchievementsOptionsCategory:GetID())
        end
      else
        -- Fallback: try to show Interface Options and navigate to addon
        if InterfaceOptionsFrame then
          InterfaceOptionsFrame_OpenToCategory("Hardcore Achievements")
        end
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
    UHCA.LayoutLabel = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.LayoutLabel:SetPoint("LEFT", UHCA.SettingsButton, "RIGHT", 6, 0)
    UHCA.LayoutLabel:SetText("Layout:")
    UHCA.LayoutLabel:SetTextColor(1, 1, 1)
  end

  if not UHCA.LayoutListCheckbox then
    UHCA.LayoutListCheckbox = CreateFrame("CheckButton", nil, UHCA, "UICheckButtonTemplate")
    UHCA.LayoutListCheckbox:SetPoint("LEFT", UHCA.LayoutLabel, "RIGHT", 6, 0)
    UHCA.LayoutListCheckbox:SetSize(18, 18)
    UHCA.LayoutListCheckbox.text:SetText("List")
    UHCA.LayoutListCheckbox.text:SetTextColor(1, 1, 1)
    UHCA.LayoutListCheckbox:SetScript("OnClick", function(self)
      if not self:GetChecked() then
        self:SetChecked(true)
        return
      end
      SetModernRowsEnabled(true)
    end)
  end

  if not UHCA.LayoutGridCheckbox then
    UHCA.LayoutGridCheckbox = CreateFrame("CheckButton", nil, UHCA, "UICheckButtonTemplate")
    UHCA.LayoutGridCheckbox:SetPoint("LEFT", UHCA.LayoutListCheckbox, "RIGHT", 20, 0)
    UHCA.LayoutGridCheckbox:SetSize(18, 18)
    UHCA.LayoutGridCheckbox.text:SetText("Grid")
    UHCA.LayoutGridCheckbox.text:SetTextColor(1, 1, 1)
    UHCA.LayoutGridCheckbox:SetScript("OnClick", function(self)
      if not self:GetChecked() then
        self:SetChecked(true)
        return
      end
      SetModernRowsEnabled(false)
    end)
  end

  UpdateLayoutCheckboxes(IsModernRowsEnabled())

  -- Only create filter dropdown if it doesn't exist
  local filterDropdown = UHCA.FilterDropdown
  if not filterDropdown then
    filterDropdown = CreateFrame("Frame", nil, UHCA, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("TOPRIGHT", UHCA, "TOPRIGHT", 30, -35) -- Moved down 10px (from -25 to -35)
    UIDropDownMenu_SetWidth(filterDropdown, 110)
    UIDropDownMenu_SetText(filterDropdown, "All")
    UHCA.FilterDropdown = filterDropdown
    
    -- Initialize filter dropdown
    UIDropDownMenu_Initialize(filterDropdown, function(self, level)
      if level == 1 then
        for _, filter in ipairs(PopulateFilterDropdown()) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = filter.text
          info.value = filter.value
          info.func = function()
            UIDropDownMenu_SetSelectedValue(filterDropdown, filter.value)
            UIDropDownMenu_SetText(filterDropdown, filter.text)
            currentFilter = filter.value
            ApplyFilter()
          end
          UIDropDownMenu_AddButton(info)
        end
      end
    end)
  end

  if not UHCA.HideCustomTabCheckbox then
    -- Add checkbox to control custom tab visibility
    UHCA.HideCustomTabCheckbox = CreateFrame("CheckButton", nil, UHCA, "UICheckButtonTemplate")
    UHCA.HideCustomTabCheckbox:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", 8, -43)
    UHCA.HideCustomTabCheckbox:SetSize(20, 20)
    
    local function GetShowCustomTabSetting()
      if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        return cdb and cdb.settings and cdb.settings.showCustomTab == true
      end
      return false
    end
    UHCA.HideCustomTabCheckbox:SetChecked(GetShowCustomTabSetting()) -- Default to not showing custom tab, but respect saved state
    
    -- Add label for the checkbox
    UHCA.HideCustomTabLabel = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.HideCustomTabLabel:SetPoint("RIGHT", UHCA.HideCustomTabCheckbox, "LEFT", -3, 0)
    UHCA.HideCustomTabLabel:SetText("Show Achievements on the Character Info Panel")
    UHCA.HideCustomTabLabel:SetTextColor(0.8, 0.8, 0.8)
    
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

  --print("|cff00ff00[HardcoreAchievements]|r UltraHardcore addon not detected")

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

  --print(string.format("|cff00ff00[HardcoreAchievements]|r %s addon detected", addonName or "UltraHardcore"))

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
