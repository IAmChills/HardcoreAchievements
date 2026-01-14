local MetaCommon = {}

-- Register a meta achievement with the given definition
function MetaCommon.registerMetaAchievement(def)
  local achId = def.achId
  local title = def.title
  local tooltip = def.tooltip
  local icon = def.icon
  local points = def.points
  local requiredAchievements = def.requiredAchievements or {} -- Array of achievement IDs
  local achievementOrder = def.achievementOrder -- Optional ordering for tooltip display

  -- Expose this definition for external lookups (e.g., chat link tooltips)
  _G.HCA_AchievementDefs = _G.HCA_AchievementDefs or {}
  _G.HCA_AchievementDefs[tostring(achId)] = {
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    requiredAchievements = requiredAchievements,
    achievementOrder = achievementOrder,
    isMetaAchievement = true,
  }
  
  -- Meta achievements only allow solo bonuses when hardcore is active (self-found buff)
  -- Set allowSoloDouble on def to control this behavior
  local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
  def.allowSoloDouble = isHardcoreActive

  -- State for the current achievement session only
  local state = {
    completed = false,     -- set true once achievement conditions met
  }

  -- Load progress from database on initialization
  local function LoadProgress()
    local progress = HardcoreAchievements_GetProgress(achId)
    -- Check if already completed in previous session
    if progress and progress.completed then
      state.completed = true
    end
  end

  -- Save progress to database
  local function SaveProgress()
    if state.completed then
      HardcoreAchievements_SetProgress(achId, "completed", true)
    end
  end

  -- Helper function to check if any required achievement is failed/outleveled
  local function AnyRequiredAchievementFailed()
    if not requiredAchievements or #requiredAchievements == 0 then
      return false
    end

    -- Check if AchievementPanel is available and has rows
    if not _G.AchievementPanel or not _G.AchievementPanel.achievements then
      return false
    end

    -- Check each required achievement to see if it's failed/outleveled
    for _, reqAchId in ipairs(requiredAchievements) do
      -- Find the row for this achievement
      for _, row in ipairs(_G.AchievementPanel.achievements) do
        local rowId = row.id or row.achId
        if rowId and tostring(rowId) == tostring(reqAchId) then
          -- Check if this row is outleveled/failed
          if _G.IsRowOutleveled and _G.IsRowOutleveled(row) then
            return true
          end
          break
        end
      end
    end

    return false
  end

  -- Helper function to check if all required achievements are completed
  local function AllRequiredAchievementsCompleted()
    if not requiredAchievements or #requiredAchievements == 0 then
      return false
    end

    for _, reqAchId in ipairs(requiredAchievements) do
      local progress = HardcoreAchievements_GetProgress(reqAchId)
      if not progress or not progress.completed then
        return false
      end
    end

    return true
  end

  -- Check if achievement is complete (called periodically)
  local function CheckComplete()
    if state.completed then
      return true
    end

    -- If any required achievement is failed, mark meta achievement as failed
    if AnyRequiredAchievementFailed() then
      if _G.HCA_EnsureFailureTimestamp then
        _G.HCA_EnsureFailureTimestamp(achId)
      end
      return false
    end

    if AllRequiredAchievementsCompleted() then
      state.completed = true
      SaveProgress()
      return true
    end

    return false
  end

  -- Initialize
  LoadProgress()

  -- Dynamic names first so functions capture these locals
  local registerFuncName = "HCA_Register" .. achId
  local rowVarName = achId .. "_Row"

  -- Create a dummy tracker function (meta achievements don't track kills)
  local function MetaTracker()
    -- Check completion on any event (this will be called periodically)
    if CheckComplete() and _G[rowVarName] then
      local row = _G[rowVarName]
      if row and not row.completed then
        row.completed = true
        -- Trigger UI update
        if _G.UpdatePointsDisplay then
          _G.UpdatePointsDisplay(row)
        end
        if _G.RefreshAllAchievementPoints then
          _G.RefreshAllAchievementPoints()
        end
      end
    end
    return state.completed
  end

  -- Create the registration function
  _G[registerFuncName] = function()
    if not _G.CreateAchievementRow or not _G.AchievementPanel then return end
    if _G[rowVarName] then return end
    
    -- Load progress from database
    LoadProgress()
    
    -- Check completion before creating row
    CheckComplete()
    
    -- Set meta flag on def
    local metaDef = def or {}
    metaDef.isMeta = true
    
    -- Create the achievement row (meta achievements don't need level or questTracker)
    _G[rowVarName] = CreateAchievementRow(
      AchievementPanel,
      achId,
      title,
      tooltip,
      icon,
      nil,  -- No level requirement for meta achievements
      points,
      MetaTracker,  -- Dummy tracker function
      nil,  -- No quest tracker
      false,  -- staticPoints
      nil,  -- zone
      metaDef  -- Pass def with isMeta flag
    )
    
    -- Store requiredAchievements on the row for tooltip access
    if requiredAchievements and #requiredAchievements > 0 then
      _G[rowVarName].requiredAchievements = requiredAchievements
      _G[rowVarName].achievementOrder = achievementOrder
    end
    
    -- Refresh points with multipliers after creation
    if RefreshAllAchievementPoints then
      RefreshAllAchievementPoints()
    end
    
    -- Check completion initially and store checker function
    CheckComplete()
    
    -- Store checker function globally so it can be called when achievements refresh
    if not _G.HCA_MetaAchievementCheckers then
      _G.HCA_MetaAchievementCheckers = {}
    end
    _G.HCA_MetaAchievementCheckers[achId] = function()
      if _G[rowVarName] then
        local row = _G[rowVarName]
        if row and not row.completed then
          -- Check if any required achievement is failed
          if AnyRequiredAchievementFailed() then
            -- Mark meta achievement as failed
            if _G.HCA_EnsureFailureTimestamp then
              _G.HCA_EnsureFailureTimestamp(achId)
            end
            -- Update display to show failed state
            if _G.UpdatePointsDisplay then
              _G.UpdatePointsDisplay(row)
            end
          elseif CheckComplete() then
            -- All required achievements completed
            row.completed = true
            if _G.UpdatePointsDisplay then
              _G.UpdatePointsDisplay(row)
            end
            if _G.RefreshAllAchievementPoints then
              _G.RefreshAllAchievementPoints()
            end
          end
        end
      end
    end
  end
  
  -- Auto-register the achievement immediately if the panel is ready
  if _G.CreateAchievementRow and _G.AchievementPanel then
    _G[registerFuncName]()
  end
end

_G.MetaCommon = MetaCommon
return MetaCommon
