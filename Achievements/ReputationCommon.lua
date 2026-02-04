---------------------------------------
-- Reputation Achievement Common Module
---------------------------------------
local ReputationCommon = {}

---------------------------------------
-- Registration Function
---------------------------------------

function ReputationCommon.registerReputationAchievement(def)
  local achId = def.achId
  local title = def.title or ""
  local tooltip = def.tooltip or ""
  local icon = def.icon
  local points = def.points or 0
  local factionId = def.factionId -- Faction ID (required)
  local staticPoints = def.staticPoints or false
  local class = def.class -- Optional class restriction
  
  -- Create unique variable names
  local rowVarName = achId .. "_Row"
  local registerFuncName = "HCA_Register" .. achId
  
  ---------------------------------------
  -- Helper Functions
  ---------------------------------------

  -- Get character database with fallback
  local function GetCharDB()
    return HardcoreAchievements_GetCharDB and HardcoreAchievements_GetCharDB() or (function() return nil, nil end)()
  end

  -- Check if achievement was already completed in database
  local function WasAlreadyCompleted()
    local _, cdb = GetCharDB()
    return cdb and cdb.achievements and cdb.achievements[achId] and cdb.achievements[achId].completed
  end

  -- Get faction standing ID (8 = Exalted)
  local function GetFactionStanding()
    if GetFactionInfoByID then
      local standing = select(4, GetFactionInfoByID(factionId))
      if standing then
        return standing
      end
    end
    
    -- Fallback: loop through GetNumFactions and check standingId
    local numFactions = GetNumFactions()
    for i = 1, numFactions do
      local name, _, standingId, _, _, _, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(i)
      if not isHeader and factionID == factionId then
        return standingId
      end
    end
    return nil
  end

  -- Check if player has the faction and is exalted
  -- Uses factionId to check standing via C_Reputation.GetFactionDataByID()
  local function IsExalted()
    local standing = GetFactionStanding()
    return standing == 8
  end
  
  -- Check if player has the faction in their list (even if not exalted)
  -- Uses GetNumFactions loop to check if faction exists in player's reputation list
  local function HasFaction()  
    local numFactions = GetNumFactions()
    for i = 1, numFactions do
      local name, _, _, _, _, _, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(i)
      if not isHeader and factionID == factionId then
        return true
      end
    end
    return false
  end
  
  ---------------------------------------
  -- Tooltip Management
  ---------------------------------------

  local function UpdateTooltip()
    local row = _G[rowVarName]
    if row then
      -- Store the base tooltip for the main tooltip
      local baseTooltip = tooltip or ""
      row.tooltip = baseTooltip
      
      -- Ensure mouse events are enabled and highlight texture exists
      row:EnableMouse(true)
      if not row.highlight then
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints(row)
        row.highlight:SetColorTexture(1, 1, 1, 0.10)
        row.highlight:Hide()
      end
      
      -- Override the OnEnter script to use proper GameTooltip API while preserving highlighting
      row:SetScript("OnEnter", function(self)
        -- Show highlight
        if self.highlight then
          self.highlight:Show()
        end
        
        if self.Title and self.Title.GetText then
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:ClearLines()
          GameTooltip:SetText(title or "", 1, 1, 1)
          
          -- Points (right) on one line
          local rightText = (self.points and tonumber(self.points) and tonumber(self.points) > 0) and (ACHIEVEMENT_POINTS .. ": " .. tostring(self.points)) or " "
          GameTooltip:AddLine(rightText, 0.7, 0.9, 0.7)
          
          -- Description in default yellow
          GameTooltip:AddLine(baseTooltip, nil, nil, nil, true)
          
          -- Hint for linking the achievement in chat
          GameTooltip:AddLine("\nShift click to link in chat\nor add to tracking list", 0.5, 0.5, 0.5)
          
          GameTooltip:Show()
        end
      end)
      
      -- Set up OnLeave script to hide highlight and tooltip
      row:SetScript("OnLeave", function(self)
        if self.highlight then
          self.highlight:Hide()
        end
        GameTooltip:Hide()
      end)
    end
  end
  
  -- Mark achievement as completed and optionally show toast
  local function MarkCompletionAndShowToast(row, showToast)
    if not row or not _G.HCA_MarkRowCompleted then
      return
    end
    
    _G.HCA_MarkRowCompleted(row)
    
    if showToast and _G.HCA_AchToast_Show then
      _G.HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
    end
  end

  -- Check if achievement should be completed (no progress saving - just check directly)
  local function CheckCompletion()
    -- First check database to see if achievement was previously completed
    if WasAlreadyCompleted() then
      return true
    end
    
    -- Check if row is already marked as completed
    local row = _G[rowVarName]
    if row and row.completed then
      return true
    end
    
    -- Check if player is exalted
    if IsExalted() then
      return true
    end
    
    return false
  end
  
  -- Reputation tracker (called on UPDATE_FACTION events)
  local function ReputationTracker()
    -- Check if achievement should be completed
    if CheckCompletion() then
      local row = _G[rowVarName]
      -- Only show toast if this is a new completion (not loading from database)
      local showToast = not WasAlreadyCompleted()
      MarkCompletionAndShowToast(row, showToast)
      UpdateTooltip()
      return true
    end
    
    UpdateTooltip()
    return false
  end
  
  -- Store the tracker function globally for the main system
  -- Note: The bridge will call this on UPDATE_FACTION events
  -- Tracker function is passed directly to CreateAchievementRow and stored on row
  
  -- Register functions in local registry to reduce global pollution
  if _G.HardcoreAchievements_RegisterAchievementFunction then
    _G.HardcoreAchievements_RegisterAchievementFunction(achId, "IsCompleted", function() 
      return CheckCompletion()
    end)
  end
  
  -- Check eligibility - only show if player has the faction in their list and matches class (if specified)
  local function IsEligible()
    -- Only register if the player has this faction in their reputation list
    if not HasFaction() then
      return false
    end
    
    -- Class: use class file tokens ("MAGE","WARRIOR","ROGUE",...)
    if class then
      local _, classFile = UnitClass("player")
      if classFile ~= class then
        return false
      end
    end
    
    return true
  end
  
  ---------------------------------------
  -- Registration Logic
  ---------------------------------------

  _G[registerFuncName] = function()
    if not _G.CreateAchievementRow or not _G.AchievementPanel then return end
    if _G[rowVarName] then return end
    
    -- Check if player is eligible for this achievement (has the faction)
    if not IsEligible() then return end
    
    -- Mark as reputation achievement (similar to isDungeonSet for filtering)
    def.isReputation = true
    
    _G[rowVarName] = CreateAchievementRow(
      AchievementPanel,
      achId,
      title,
      tooltip,
      icon,
      nil, -- No level for reputation achievements
      points,
      nil, -- No kill tracker for reputation
      nil, -- No quest tracker for reputation
      staticPoints,
      nil, -- No zone for reputation achievements
      def
    )
    
    -- Store faction ID on the row for easy access
    _G[rowVarName].factionId = factionId
    
    -- Load completion status from database on registration
    if WasAlreadyCompleted() then
      -- Achievement was previously completed - mark row as completed without showing toast
      MarkCompletionAndShowToast(_G[rowVarName], false)
    elseif CheckCompletion() then
      -- Achievement should be completed now (player is exalted) - mark and show toast
      MarkCompletionAndShowToast(_G[rowVarName], true)
    end
    
    -- Update tooltip after creation to ensure it shows current progress
    C_Timer.After(0.1, UpdateTooltip)
  end
  
  -- Auto-register the achievement immediately if the panel is ready
  if _G.CreateAchievementRow and _G.AchievementPanel then
    _G[registerFuncName]()
  end
  
  -- Create the event frame dynamically
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("PLAYER_LOGIN")
  eventFrame:RegisterEvent("ADDON_LOADED")
  eventFrame:RegisterEvent("UPDATE_FACTION")
  eventFrame:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_FACTION" then
      -- Check completion when reputation updates
      if CheckCompletion() then
        local row = _G[rowVarName]
        -- Only show toast if this is a new completion (not loading from database)
        local showToast = not WasAlreadyCompleted()
        MarkCompletionAndShowToast(row, showToast)
      end
    end
    _G[registerFuncName]()
  end)
  
  if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    CharacterFrame:HookScript("OnShow", function()
      _G[registerFuncName]()
    end)
  end
end

---------------------------------------
-- Module Export
---------------------------------------

_G.ReputationCommon = ReputationCommon
