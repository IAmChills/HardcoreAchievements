-- Embed_UltraHardcore.lua
-- Embeds HardcoreAchievements as circular icons in a grid layout into the UltraHardcore Settings "Achievements" tab (tabContents[3])
-- Grid UI: circular icons with tooltips showing title, level requirement, and points.

local ADDON_NAME = ...
local EMBED = {}
local DEST      -- tabContents[3]
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
  
  return {
    id        = src.id or title,
    title     = title,
    iconTex   = iconTex,
    tooltip   = tooltip,
    points    = tonumber(src.points) or 0,
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
  if not DEST or not DEST.Scroll or not DEST.Content then return end
  local w = math.max(DEST.Scroll:GetWidth(), 1)
  DEST.Content:SetWidth(w)
end

-- ---------- Rebuild ----------
function EMBED:Rebuild()
  if not DEST or not DEST.Content then return end
  if not self.Content then self.Content = DEST.Content end

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

-- ---------- Build / Hooks ----------
local function BuildEmbedIfNeeded()
  if DEST and DEST.Scroll and DEST.Content and EMBED.Content then return true end
  if not tabContents or not tabContents[3] then return false end

  DEST = tabContents[3]
  
  -- Hide any existing text objects in the frame that aren't ours
  local function hideExistingTextObjects()
    for i = 1, DEST:GetNumChildren() do
      local child = select(i, DEST:GetChildren())
      if child and child.GetText and type(child.GetText) == "function" then
        -- Hide any text object that exists (assuming they're all from UltraHardcore)
        child:Hide()
      end
    end
  end
  
  -- Hide existing text objects
  hideExistingTextObjects()
  
  -- Hide custom achievement tab when embedded UI loads
  --HideCustomAchievementTab()

  DEST.Scroll = CreateFrame("ScrollFrame", nil, DEST, "UIPanelScrollFrameTemplate")
  DEST.Scroll:SetPoint("TOPLEFT", DEST, "TOPLEFT", 4, -40)
  DEST.Scroll:SetPoint("BOTTOMRIGHT", DEST, "BOTTOMRIGHT", -8, -20)
  
  -- Hide the scroll bar but keep it functional
  if DEST.Scroll.ScrollBar then
    DEST.Scroll.ScrollBar:Hide()
  end

  DEST.Content = CreateFrame("Frame", nil, DEST.Scroll)
  DEST.Content:SetSize(1, 1)
  DEST.Scroll:SetScrollChild(DEST.Content)

  EMBED.Content = DEST.Content
  SyncContentWidth()

  DEST:HookScript("OnShow", function()
    if not EMBED.Content or EMBED.Content ~= DEST.Content then
      EMBED.Content = DEST.Content
    end
    SyncContentWidth()
    EMBED:Rebuild()
  end)

  DEST.Scroll:SetScript("OnSizeChanged", function(self)
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

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event)
  if BuildEmbedIfNeeded() then
    HookSourceSignals()
    C_Timer.After(0, function() EMBED:Rebuild() end)
  else
    C_Timer.After(0.25, function()
      if BuildEmbedIfNeeded() then
        HookSourceSignals()
        C_Timer.After(0, function() EMBED:Rebuild() end)
      else
        -- UltraHardcore not available - achievements will use standalone mode
        print("|cff00ff00[HardcoreAchievements]|r UltraHardcore addon not detected - achievements available in standalone mode")
      end
    end)
  end

  if not GetSourceRows() then
    C_Timer.After(1.0, function()
      HookSourceSignals()
      if DEST and DEST:IsShown() then EMBED:Rebuild() end
    end)
  end
end)
