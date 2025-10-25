local ADDON_NAME = ...
local EMBED = {}
local UHCA -- tabContents[3]
local ICON_SIZE = 60
local ICON_PADDING = 12
local GRID_COLS = 7  -- Number of columns in the grid

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

  -- Create completion border
  icon.CompletionBorder = icon:CreateTexture(nil, "OVERLAY")
  icon.CompletionBorder:SetAllPoints(icon)
  icon.CompletionBorder:SetTexture("Interface\\CharacterFrame\\UI-Character-InfoFrame-Character")
  icon.CompletionBorder:SetTexCoord(0.5, 0.75, 0.5, 0.75)
  icon.CompletionBorder:SetVertexColor(0, 1, 0, 1.0) -- Green border
  icon.CompletionBorder:Hide()

  icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title or "", 1, 0.82, 0)
    
    if self.maxLevel and self.maxLevel > 0 then
      GameTooltip:AddLine(("Max Level: %d"):format(self.maxLevel), 0.7, 0.7, 0.7)
    end

    if self.tooltip and self.tooltip ~= "" then
      GameTooltip:AddLine(self.tooltip, 0.9, 0.9, 0.9, true)
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
  
  local totalIcons = #icons
  local rows = math.ceil(totalIcons / GRID_COLS)
  local startX = ICON_PADDING
  local startY = -ICON_PADDING
  
  for i, icon in ipairs(icons) do
    local col = ((i - 1) % GRID_COLS)
    local row = math.floor((i - 1) / GRID_COLS)
    
    local x = startX + col * (ICON_SIZE + ICON_PADDING)
    local y = startY - row * (ICON_SIZE + ICON_PADDING)
    
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
    icon:Show()
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
  local needed = 0

  for _, srow in ipairs(srcRows) do
    if not srow._isHidden then
      needed = needed + 1
      local data = ReadRowData(srow)
      local icon = self.icons[needed]
      if not icon then
        icon = CreateEmbedIcon(self.Content)
        self.icons[needed] = icon
      end

      icon.id        = data.id
      icon.title     = data.title
      icon.tooltip   = data.tooltip
      icon.points    = data.points
      icon.maxLevel  = data.maxLevel
      icon.completed = data.completed

      if data.iconTex then
        icon.Icon:SetTexture(data.iconTex)
      else
        icon.Icon:SetTexture(136116) -- generic achievement icon
      end

      -- Set icon appearance based on status
      if data.completed then
        -- Completed: Full color
        icon.Icon:SetDesaturated(false)
        icon.Icon:SetAlpha(1.0)
        icon.Icon:SetVertexColor(1.0, 1.0, 1.0) -- Full color
      elseif data.maxLevel and data.maxLevel > 0 then
        -- Check if player is out-leveled
        local playerLevel = UnitLevel("player") or 0
        if playerLevel > data.maxLevel then
          -- Out-leveled: Desaturated
          icon.Icon:SetDesaturated(true)
          icon.Icon:SetAlpha(0.7)
          icon.Icon:SetVertexColor(1.0, 1.0, 1.0) -- Reset to normal color
        else
          -- Available but has level requirement: Full color
          icon.Icon:SetDesaturated(false)
          icon.Icon:SetAlpha(1.0)
          icon.Icon:SetVertexColor(1.0, 1.0, 1.0) -- Full color
        end
      else
        -- Available/Incomplete: Full color
        icon.Icon:SetDesaturated(false)
        icon.Icon:SetAlpha(1.0)
        icon.Icon:SetVertexColor(1.0, 1.0, 1.0) -- Full color
      end

      -- Set completion border
      if data.completed then
        icon.CompletionBorder:Show()
      else
        icon.CompletionBorder:Hide()
      end
    end
  end

  for i = needed + 1, #self.icons do
    self.icons[i]:Hide()
  end

  LayoutIcons(self.Content, self.icons)
  UpdateMultiplierText()
end

-- Hide the custom Achievement tab when embedded UI loads
local function HideCustomAchievementTab()
    -- Hide the custom Achievement tab created in HardcoreAchievements.lua
    local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
    if tab and tab:GetText() and tab:GetText():find("Achievements") then
        tab:Hide()
        tab:SetScript("OnClick", function() end) -- Disable click functionality
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
  UHCA.Scroll:SetPoint("TOPLEFT", UHCA, "TOPLEFT", 4, -40)
  UHCA.Scroll:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", -8, -20)
  
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

  -- Add checkbox to control custom tab visibility
  UHCA.HideCustomTabCheckbox = CreateFrame("CheckButton", nil, UHCA, "UICheckButtonTemplate")
  UHCA.HideCustomTabCheckbox:SetPoint("BOTTOMRIGHT", UHCA, "BOTTOMRIGHT", 0, -30)
  UHCA.HideCustomTabCheckbox:SetSize(20, 20)
  UHCA.HideCustomTabCheckbox:SetChecked(HardcoreAchievementsDB and HardcoreAchievementsDB.showCustomTab == true) -- Default to not showing custom tab, but respect saved state
  
  -- Add label for the checkbox
  UHCA.HideCustomTabLabel = UHCA:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  UHCA.HideCustomTabLabel:SetPoint("RIGHT", UHCA.HideCustomTabCheckbox, "LEFT", -5, 0)
  UHCA.HideCustomTabLabel:SetText("Show Achievement on CharacterFrame")
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
    EMBED:Rebuild()
  end)

  UHCA.Scroll:SetScript("OnSizeChanged", function(self)
    self:UpdateScrollChildRect()
    SyncContentWidth()
    EMBED:Rebuild()
  end)

  return true
end

local function HookSourceSignals()
  if EMBED._hooked then return end
  if type(CheckPendingCompletions) == "function" then
    hooksecurefunc("CheckPendingCompletions", function()
      C_Timer.After(0, function() EMBED:Rebuild() end)
    end)
  end
  if type(UpdateTotalPoints) == "function" then
    hooksecurefunc("UpdateTotalPoints", function()
      C_Timer.After(0, function() EMBED:Rebuild() end)
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
        if BuildEmbedIfNeeded() then EMBED:Rebuild() end
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
    --print("|cff00ff00[HardcoreAchievements]|r Successfully integrated with UltraHardcore")
  end

  -- Show custom achievement tab as fallback if needed
  if not GetSourceRows() then
    C_Timer.After(1.0, function()
      if not GetSourceRows() then
        -- Show custom achievement tab as fallback
        local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
        if tab and tab:GetText() and tab:GetText():find("Achievements") then
          tab:Show()
          tab:SetScript("OnClick", function(self)
            -- Use the same logic as the main achievement tab
            if HCA_ShowAchievementTab then
              HCA_ShowAchievementTab()
            end
          end)
        end
      end
    end)
  end
end)
