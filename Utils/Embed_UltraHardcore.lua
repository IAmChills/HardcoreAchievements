local ADDON_NAME = ...
local EMBED = {}
local UHCA -- tabContents[3]
local ICON_SIZE = 60
local ICON_PADDING = 12
local GRID_COLS = 7  -- Number of columns in the grid
local currentFilter = "all"  -- Current filter state

-- ---------- Filter Functions ----------
local function IsRowOutleveled(row)
  if not row or row.completed then return false end
  if not row.maxLevel then return false end
  local lvl = UnitLevel("player") or 1
  return lvl > row.maxLevel
end

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
  
  -- Use the helper function to extract all display data from the row
  -- This ensures we get the same formatted data as the character panel
  local data = _G.HCA_ExtractRowDisplayData and _G.HCA_ExtractRowDisplayData(src)
  if not data then
    -- Fallback if helper not available
    local title = ""
    if src.Title and src.Title.GetText then
      title = src.Title:GetText() or ""
    elseif type(src.id) == "string" then
      title = src.id
    end
    data = {
      id = src.id or title,
      title = title,
      iconTex = (src.Icon and src.Icon.GetTexture and src.Icon:GetTexture()) or nil,
      tooltip = src.tooltip or title,
      statusText = nil,
      points = tonumber(src.points) or 0,
      maxLevel = tonumber(src.maxLevel) or nil,
      completed = not not src.completed,
      zone = src.zone,
      requiredKills = src.requiredKills,
      allowSoloDouble = not not src.allowSoloDouble,
      showSoloIndicator = false,
      isSecretAchievement = not not src.isSecretAchievement,
    }
  end
  
  -- Add additional fields needed for filtering
  data.outleveled = IsRowOutleveled(src)
  data.hiddenUntilComplete = not not src.hiddenUntilComplete
  
  return data
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
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    
    -- Show title with solo indicator if applicable (from extracted data)
    if self.showSoloIndicator then
      GameTooltip:AddDoubleLine(self.title or "", "|cFFac81d6Solo|r", 1, 1, 1, 0.5, 0.3, 0.9)
    else
      GameTooltip:SetText(self.title or "", 1, 1, 1)
    end
    
    -- Use status text from the row (already formatted with level + status)
    -- This ensures we match exactly what's shown on the character panel
    local leftText = self.statusText or ((self.maxLevel and self.maxLevel > 0) and (LEVEL .. " " .. self.maxLevel) or " ")
    local rightText = (type(self.points) == "number" and self.points > 0) and (tostring(self.points) .. " pts") or " "
    
    if leftText ~= " " or rightText ~= " " then
      -- Check if status text contains newlines (multi-line status)
      local hasNewline = leftText:find("\n")
      if hasNewline then
        GameTooltip:AddLine(leftText, 1, 1, 1)
        GameTooltip:AddDoubleLine(" ", rightText, 1, 1, 1, 0.6, 0.9, 0.6)
      else
        GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.6, 0.9, 0.6)
      end
    end

    -- Check if this is a dungeon achievement (has requiredMapId/mapID)
    -- Only dungeon achievements should show "Required Bosses:" section
    local requiredKills = self.requiredKills or {}
    local isDungeonAchievement = false
    if self.achId and _G.HCA_AchievementDefs then
      local achDef = _G.HCA_AchievementDefs[tostring(self.achId)]
      if achDef and achDef.mapID then
        isDungeonAchievement = true
      end
    end
    
    if isDungeonAchievement and next(requiredKills) ~= nil then
      -- Build dynamic tooltip with boss completion status
      if self.tooltip and self.tooltip ~= "" then
        -- Default yellow (match in-game color)
        GameTooltip:AddLine(self.tooltip, nil, nil, nil, true)
      end
      -- Zone in gray under the description
      if self.zone and tostring(self.zone) ~= "" then
        GameTooltip:AddLine(tostring(self.zone), 0.6, 1, 0.86)
      end
      
      GameTooltip:AddLine("\nRequired Bosses:", 0, 1, 0) -- Green header
      
      -- Get progress from database
      local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(self.achId)
      local counts = progress and progress.counts or {}
      
      for npcId, need in pairs(requiredKills) do
        local idNum = tonumber(npcId) or npcId
        local current = (counts[idNum] or counts[tostring(idNum)] or 0)
        local bossName = HCA_GetBossName(idNum)
        local done = current >= (tonumber(need) or 1)
        
        if done then
          GameTooltip:AddLine(bossName, 1, 1, 1) -- White for completed
        else
          GameTooltip:AddLine(bossName, 0.5, 0.5, 0.5) -- Gray for not completed
        end
      end
    else
      -- Standard tooltip (already includes party members text if applicable)
      if self.tooltip and self.tooltip ~= "" then
        -- Default yellow (match in-game color)
        GameTooltip:AddLine(self.tooltip, nil, nil, nil, true)
      end
      -- Zone in gray under the description
      if self.zone and tostring(self.zone) ~= "" then
        GameTooltip:AddLine(tostring(self.zone), 0.6, 1, 0.86)
      end
    end
    
    if self.completed then
      GameTooltip:AddLine("Completed", 0.6, 0.9, 0.6)
    end
    
    -- Hint for linking the achievement in chat
    GameTooltip:AddLine("\nShift + Left Click to link in chat", 0.5, 0.5, 0.5)

    GameTooltip:Show()
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
  
  UHCA.TotalPointsText:SetText(totalPoints .. " pts")
  UHCA.TotalPointsText:SetTextColor(0.6, 0.9, 0.6)
end

-- ---------- Rebuild ----------
function EMBED:Rebuild()
  if not UHCA or not UHCA.Content then return end
  if not self.Content then self.Content = UHCA.Content end

  SyncContentWidth()

  local srcRows = GetSourceRows()
  if not srcRows then
    if self.icons then for _, icon in ipairs(self.icons) do icon:Hide() end end
    return
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
        icon.title     = data.title
        icon.tooltip   = data.tooltip
        icon.points    = data.points
        icon.maxLevel  = data.maxLevel
        icon.completed = data.completed
        icon.requiredKills = data.requiredKills  -- Store requiredKills for dungeon achievements
        icon.zone      = data.zone
        icon.allowSoloDouble = data.allowSoloDouble
        icon.statusText = data.statusText  -- Store status text (level + status formatted)
        icon.showSoloIndicator = data.showSoloIndicator  -- Store solo indicator flag

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
  UpdateMultiplierText()
  UpdateTotalPointsText()
  
  -- Sync solo mode checkbox state
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
    UHCA.Scroll:SetPoint("TOPLEFT", UHCA, "TOPLEFT", -4, -60)
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
  if not UHCA.MultiplierText then
    -- Add multiplier text (like in standalone mode)
    UHCA.MultiplierText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UHCA.MultiplierText:SetPoint("TOP", UHCA, "TOP", 0, -35)
    UHCA.MultiplierText:SetText("") -- Will be set by UpdateMultiplierText
  end

  if not UHCA.TotalPointsText then
    -- Add total points text in top left corner
    UHCA.TotalPointsText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    UHCA.TotalPointsText:SetPoint("TOPLEFT", UHCA, "TOPLEFT", 5, -35)
    UHCA.TotalPointsText:SetText("0 pts") -- Will be updated by UpdateTotalPointsText
  end

  -- Solo mode checkbox
  if not UHCA.SoloModeCheckbox then
    UHCA.SoloModeCheckbox = CreateFrame("CheckButton", nil, UHCA, "InterfaceOptionsCheckButtonTemplate")
    UHCA.SoloModeCheckbox:SetPoint("BOTTOMLEFT", UHCA, "BOTTOMLEFT", -10, -43)
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
    filterDropdown = CreateFrame("Frame", nil, UHCA, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("TOPRIGHT", UHCA, "TOPRIGHT", 30, -25)
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

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, addonName)
  -- Wait for UltraHardcore addon to be loaded
  if event == "ADDON_LOADED" and addonName == "UltraHardcore" then
    HookTabManager()
    HookSourceSignals()
    
    -- Don't try to access player data here - playerGUID may not be set yet
    
    -- Try modern integration approach first
    C_Timer.After(0.5, function()
      if BuildEmbedIfNeeded() then
        C_Timer.After(0, function() 
          if EMBED.Rebuild then EMBED:Rebuild() else ApplyFilter() end
        end)
        --print("|cff00ff00[HardcoreAchievements]|r Successfully integrated with UltraHardcore")
      end
    end)
    
    -- Fallback method for old versions - try after 2 seconds
    C_Timer.After(2.0, function()
      if not UHCA and tabContents and tabContents[3] then
        if BuildEmbedIfNeeded() then
          C_Timer.After(0, function() 
            if EMBED.Rebuild then EMBED:Rebuild() else ApplyFilter() end
          end)
          --print("|cff00ff00[HardcoreAchievements]|r Successfully integrated with UltraHardcore (fallback)")
        end
      end
    end)
  else
    -- UltraHardcore is not loaded, so set showCustomTab to true
    if type(HardcoreAchievements_GetCharDB) == "function" then
      local _, cdb = HardcoreAchievements_GetCharDB()
      if cdb then
        cdb.settings = cdb.settings or {}
        cdb.settings.showCustomTab = true
        
        -- Load tab position to apply the setting and show the tab
        if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
          _G.HardcoreAchievements_LoadTabPosition()
        end
        
        -- Ensure the tab is visible if it exists (even if LoadTabPosition had no saved data)
        local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
        if tab and tab:GetText() and tab:GetText():find(ACHIEVEMENTS) then
          tab:Show()
          -- Make sure the tab is enabled and has the click handler
          tab:EnableMouse(true)
          tab:SetScript("OnClick", function(self)
            if HCA_ShowAchievementTab then
              HCA_ShowAchievementTab()
            end
          end)
          
          -- If LoadTabPosition had no saved data, ensure the tab is at default position and visible
          -- Check if tab is positioned (has points set), if not, it needs default positioning
          local point, relativeTo, relativePoint = tab:GetPoint()
          if not point then
            -- Tab has no position, set it to default position
            tab:SetPoint("RIGHT", _G["CharacterFrameTab" .. CharacterFrame.numTabs], "RIGHT", 43, 0)
          end
          
          -- Ensure tab is not hidden
          if not tab:IsShown() then
            tab:Show()
          end
        end
      end
    end
  end
end)
