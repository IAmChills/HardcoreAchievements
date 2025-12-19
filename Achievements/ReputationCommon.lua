local ReputationCommon = {}

-- Register a reputation achievement with the given definition
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
  
  -- Check if player has the faction and is exalted
  -- Uses factionId to check standing via C_Reputation.GetFactionDataByID()
  local function IsExalted()
    if C_Reputation and C_Reputation.GetFactionDataByID then
      local factionData = C_Reputation.GetFactionDataByID(factionId)
      if factionData then
        -- factionData[4] is the reaction/standing (8 = Exalted)
        if factionData[4] == 8 then
          return true
        end
        return false -- Faction exists but not exalted
      end
    end
    
    -- Fallback: loop through GetNumFactions and check standingId
    local numFactions = GetNumFactions()
    for i = 1, numFactions do
      local name, _, standingId, _, _, _, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(i)
      if not isHeader and factionID == factionId then
        if standingId == 8 then
          return true
        end
        return false
      end
    end
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
  
  -- Update tooltip
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
  
  -- Check if achievement should be completed (no progress saving - just check directly)
  local function CheckCompletion()
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
      -- Mark achievement as completed in the row if it exists
      local row = _G[rowVarName]
      if row and _G.HCA_MarkRowCompleted then
        _G.HCA_MarkRowCompleted(row)
      end
      UpdateTooltip()
      return true
    end
    
    UpdateTooltip()
    return false
  end
  
  -- Store the tracker function globally for the main system
  -- Note: The bridge will call this on UPDATE_FACTION events
  _G[achId] = ReputationTracker
  
  _G[achId .. "_IsCompleted"] = function() 
    return CheckCompletion()
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
  
  -- Create the registration function dynamically
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
    
    -- Check completion status on registration
    if CheckCompletion() then
      if _G.HCA_MarkRowCompleted then
        _G.HCA_MarkRowCompleted(_G[rowVarName])
      end
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
        if row and _G.HCA_MarkRowCompleted then
          _G.HCA_MarkRowCompleted(row)
        end
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

-- Export to global scope
_G.ReputationCommon = ReputationCommon
