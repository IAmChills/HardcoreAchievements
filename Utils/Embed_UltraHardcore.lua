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
    { text = "All", value = "all" },
    { text = "Completed", value = "completed" },
    { text = "Not Completed", value = "not_completed" },
    { text = "Failed", value = "failed" },
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
  local title = ""
  if src.Title and src.Title.GetText then
    title = src.Title:GetText() or ""
  elseif type(src.id) == "string" then
    title = src.id
  end
  local iconTex
  if src.Icon and src.Icon.GetTexture then
    iconTex = src.Icon:GetTexture()
  end
  
  -- Get the tooltip from the row object (now stored in CreateAchievementRow)
  local tooltip = src.tooltip or title
  
  -- Get calculated points (now stored directly in row.points)
  local calculatedPoints = tonumber(src.points) or 0
  
  return {
    id        = src.id or title,
    title     = title,
    iconTex   = iconTex,
    tooltip   = tooltip,
    points    = calculatedPoints,
    maxLevel  = tonumber(src.maxLevel) or nil,
    completed = not not src.completed,
    outleveled = IsRowOutleveled(src),
    requiredKills = src.requiredKills,  -- Store requiredKills for dungeon achievements
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

  icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title or "", 1, 0.82, 0)
    
    if self.maxLevel and self.maxLevel > 0 then
      GameTooltip:AddLine(("Max Level: %d"):format(self.maxLevel), 0.7, 0.7, 0.7)
    end

    -- Check if this is a dungeon achievement with requiredKills
    local requiredKills = self.requiredKills or {}
    local isDungeonAchievement = next(requiredKills) ~= nil
    
    if isDungeonAchievement then
      -- Build dynamic tooltip with boss completion status
      if self.tooltip and self.tooltip ~= "" then
        GameTooltip:AddLine(self.tooltip, 0.9, 0.9, 0.9, true)
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
      -- Standard tooltip
      if self.tooltip and self.tooltip ~= "" then
        GameTooltip:AddLine(self.tooltip, 0.9, 0.9, 0.9, true)
      end
    end
    
    if type(self.points) == "number" and self.points > 0 then
      GameTooltip:AddLine("\n" .. ("Points: %d"):format(self.points), 0.7, 0.9, 0.7)
    end
    
    if self.completed then
      GameTooltip:AddLine("Completed", 0.6, 0.9, 0.6)
    end
    
    GameTooltip:Show()
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
    
    local labelText = ""
    if preset or isSelfFound then
        labelText = "Point Multiplier ("
        if preset then
            labelText = labelText .. preset
        end
        if isSelfFound then
            labelText = labelText .. ", Self Found"
        end
        labelText = labelText .. ")"
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
      
      if shouldShow then
        needed = needed + 1
        local icon = self.icons[needed]
        if not icon then
          icon = CreateEmbedIcon(self.Content)
          self.icons[needed] = icon
        end

        icon.id        = data.id
        icon.achId     = data.id  -- Store achId for tooltip lookup
        icon.title     = data.title
        icon.tooltip   = data.tooltip
        icon.points    = data.points
        icon.maxLevel  = data.maxLevel
        icon.completed = data.completed
        icon.requiredKills = data.requiredKills  -- Store requiredKills for dungeon achievements

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
        
        -- Show the icon
        icon:Show()
      end
  end

  LayoutIcons(self.Content, self.icons)
  UpdateMultiplierText()
  UpdateTotalPointsText()
end

-- Hide the custom Achievement tab when embedded UI loads
local function HideCustomAchievementTab()
    -- Hide the custom Achievement tab created in HardcoreAchievements.lua
    local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
    if tab and tab:GetText() and tab:GetText():find("Achievements") then
        tab:Hide()
        tab:SetScript("OnClick", function() end) -- Disable click functionality
    end
    -- Also hide the custom vertical tab (square) if available
    if type(_G.HardcoreAchievements_HideVerticalTab) == "function" then
        _G.HardcoreAchievements_HideVerticalTab()
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
  if UHCA and UHCA.Scroll and UHCA.Content and EMBED.Content then return true end
  
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

  UHCA.Scroll = CreateFrame("ScrollFrame", nil, UHCA, "UIPanelScrollFrameTemplate")
  UHCA.Scroll:SetPoint("TOPLEFT", UHCA, "TOPLEFT", -4, -60)
  UHCA.Scroll:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", -8, -15)
  
  -- Hide the scroll bar but keep it functional
  if UHCA.Scroll.ScrollBar then
    UHCA.Scroll.ScrollBar:Hide()
  end

  UHCA.Content = CreateFrame("Frame", nil, UHCA.Scroll)
  UHCA.Content:SetSize(1, 1)
  UHCA.Scroll:SetScrollChild(UHCA.Content)

  -- Add multiplier text (like in standalone mode)
  UHCA.MultiplierText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  UHCA.MultiplierText:SetPoint("TOP", UHCA, "TOP", 0, -35)
  UHCA.MultiplierText:SetText("") -- Will be set by UpdateMultiplierText

  -- Add total points text in top left corner
  UHCA.TotalPointsText = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  UHCA.TotalPointsText:SetPoint("TOPLEFT", UHCA, "TOPLEFT", 5, -35)
  UHCA.TotalPointsText:SetText("0 pts") -- Will be updated by UpdateTotalPointsText

  -- Add filter dropdown
  local filterDropdown = CreateFrame("Frame", nil, UHCA, "UIDropDownMenuTemplate")
  filterDropdown:SetPoint("TOPRIGHT", UHCA, "TOPRIGHT", 30, -25)
  UIDropDownMenu_SetWidth(filterDropdown, 110)
  UIDropDownMenu_SetText(filterDropdown, "All")

  -- Add checkbox to control custom tab visibility
  UHCA.HideCustomTabCheckbox = CreateFrame("CheckButton", nil, UHCA, "UICheckButtonTemplate")
  UHCA.HideCustomTabCheckbox:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", 8, -40)
  UHCA.HideCustomTabCheckbox:SetSize(20, 20)
  UHCA.HideCustomTabCheckbox:SetChecked(HardcoreAchievementsDB and HardcoreAchievementsDB.showCustomTab == true) -- Default to not showing custom tab, but respect saved state
  
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
    if not HardcoreAchievementsDB then
      HardcoreAchievementsDB = {}
    end
    HardcoreAchievementsDB.showCustomTab = isChecked
    
    if tab and tab:GetText() and tab:GetText():find("Achievements") then
      if isChecked then
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
      end
    end
  end)

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

  EMBED.Content = UHCA.Content
  SyncContentWidth()
  
  -- Apply saved state on initialization
  local savedState = HardcoreAchievementsDB and HardcoreAchievementsDB.showCustomTab
  if savedState ~= nil then
    local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
    if tab and tab:GetText() and tab:GetText():find("Achievements") then
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
      end
    end
  end

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
f:SetScript("OnEvent", function(self, event, addonName)
  -- Wait for UltraHardcore addon to be loaded
  if event == "ADDON_LOADED" and addonName == "UltraHardcore" then
    HookTabManager()
    HookSourceSignals()
    
    -- Hide custom achievement tab immediately when UltraHardcore loads
    if not HardcoreAchievementsDB.showCustomTab then HideCustomAchievementTab() end
    
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
  end

  -- Show custom achievement tab as fallback if needed (only if UltraHardcore is not loaded)
  if not GetSourceRows() then
    C_Timer.After(1.0, function()
      if not GetSourceRows() then
        -- Show custom achievement tab as fallback
        local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
        if tab and tab:GetText() and tab:GetText():find("Achievements") then
          tab:Show()
          tab:SetScript("OnClick", function(self)
            if HCA_ShowAchievementTab then
              HCA_ShowAchievementTab()
            end
          end)
        end
      end
    end)
  end
end)
