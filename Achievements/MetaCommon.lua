---------------------------------------
-- Meta Achievement Common Module
---------------------------------------
local addonName, addon = ...
local RefreshAllAchievementPoints = (addon and addon.RefreshAllAchievementPoints)
local MetaCommon = {}

---------------------------------------
-- Registration Function
---------------------------------------

local function registerMetaAchievement(def)
  local achId = def.achId
  local title = def.title
  local tooltip = def.tooltip
  local icon = def.icon
  local points = def.points
  local requiredAchievements = def.requiredAchievements or {} -- Array of achievement IDs
  local achievementOrder = def.achievementOrder -- Optional ordering for tooltip display

  -- Expose this definition for external lookups (e.g., chat link tooltips)
  if addon and addon.RegisterAchievementDef then
    addon.RegisterAchievementDef({
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    requiredAchievements = requiredAchievements,
    achievementOrder = achievementOrder,
    isMetaAchievement = true,
  })
  end
  
  -- Meta achievements only allow solo bonuses when hardcore is active (self-found buff)
  -- Set allowSoloDouble on def to control this behavior
  local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
  def.allowSoloDouble = isHardcoreActive

  ---------------------------------------
  -- State Management
  ---------------------------------------

  -- State for the current achievement session only
  local state = {
    completed = false,     -- set true once achievement conditions met
  }

  ---------------------------------------
  -- Helper Functions
  ---------------------------------------

  -- Load progress from database on initialization
  local function LoadProgress()
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
    -- Check if already completed in previous session
    if progress and progress.completed then
      state.completed = true
    end
  end

  -- Save progress to database
  local function SaveProgress()
    if state.completed then
      if addon and addon.SetProgress then addon.SetProgress(achId, "completed", true) end
    end
  end

  -- Find an achievement row by achievement ID
  local function FindAchievementRow(reqAchId)
    if not addon or not addon.AchievementPanel or not addon.AchievementPanel.achievements then
      return nil
    end
    
    for _, row in ipairs(addon.AchievementPanel.achievements) do
      local rowId = row.id or row.achId
      if rowId and tostring(rowId) == tostring(reqAchId) then
        return row
      end
    end
    return nil
  end

  -- Helper function to check if any required achievement is failed/outleveled
  local function AnyRequiredAchievementFailed()
    if not requiredAchievements or #requiredAchievements == 0 then
      return false
    end

    for _, reqAchId in ipairs(requiredAchievements) do
      local row = FindAchievementRow(reqAchId)
      if row and addon and addon.IsRowOutleveled and addon.IsRowOutleveled(row) then
        return true
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
      local progress = addon and addon.GetProgress and addon.GetProgress(reqAchId)
      if not progress or not progress.completed then
        return false
      end
    end

    return true
  end

  -- Mark meta achievement as failed
  local function MarkAsFailed()
    if addon and addon.EnsureFailureTimestamp then
      addon.EnsureFailureTimestamp(achId)
    end
  end

  -- Update UI when achievement state changes
  local function UpdateUI(row)
    if not row then return end
    
    if addon and addon.UpdatePointsDisplay then
      addon.UpdatePointsDisplay(row)
    end
    -- IMPORTANT: don't call RefreshAllAchievementPoints() directly here.
    -- RefreshAllAchievementPoints() itself calls meta checkers, which call UpdateUI again.
    -- Direct calls cause infinite recursion and "script ran too long".
    if addon and addon.Initializing then
      return
    end

    -- If a refresh is already running, mark pending; otherwise schedule one refresh on the next frame.
    if addon and addon.RefreshingPoints then
      addon.PointsRefreshPending = true
      return
    end

    if RefreshAllAchievementPoints and addon and not addon.PointsRefreshScheduled then
      addon.PointsRefreshScheduled = true
      C_Timer.After(0, function()
        addon.PointsRefreshScheduled = nil
        RefreshAllAchievementPoints()
      end)
    end
  end

  -- Check if achievement is complete (called periodically)
  local function CheckComplete()
    if state.completed then
      return true
    end

    -- If any required achievement is failed, mark meta achievement as failed
    if AnyRequiredAchievementFailed() then
      MarkAsFailed()
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

  ---------------------------------------
  -- Tracker Function
  ---------------------------------------

  -- Create a dummy tracker function (meta achievements don't track kills)
  local function MetaTracker()
    -- Check completion on any event (this will be called periodically)
    if CheckComplete() then
      local row = addon and addon.MetaRows and addon.MetaRows[rowVarName]
      if row and not row.completed then
        row.completed = true
        UpdateUI(row)
      end
    end
    return state.completed
  end

  ---------------------------------------
  -- Registration Logic
  ---------------------------------------

  local function doRegister()
    if not addon or not addon.CreateAchievementRow or not addon.AchievementPanel then return end
    addon.MetaRows = addon.MetaRows or {}
    if addon.MetaRows[rowVarName] then return end

    -- Load progress from database
    LoadProgress()

    -- Check completion before creating row
    CheckComplete()

    -- Set meta flag on def
    local metaDef = def or {}
    metaDef.isMeta = true

    -- Create the achievement row (meta achievements don't need level or questTracker)
    addon.MetaRows[rowVarName] = addon.CreateAchievementRow(
      addon.AchievementPanel,
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
    local row = addon.MetaRows[rowVarName]
    if row and requiredAchievements and #requiredAchievements > 0 then
      row.requiredAchievements = requiredAchievements
      row.achievementOrder = achievementOrder
    end

    -- Refresh points with multipliers after creation
    if not (addon and addon.Initializing) and RefreshAllAchievementPoints then
      RefreshAllAchievementPoints()
    end

    -- Check completion initially and store checker function
    CheckComplete()

    -- Store checker function on addon so it can be called when achievements refresh
    if addon then
      addon.MetaAchievementCheckers = addon.MetaAchievementCheckers or {}
      addon.MetaAchievementCheckers[achId] = function()
        local r = addon.MetaRows and addon.MetaRows[rowVarName]
        if not r or r.completed then
          return
        end

        if AnyRequiredAchievementFailed() then
          MarkAsFailed()
          UpdateUI(r)
        elseif CheckComplete() then
          r.completed = true
          UpdateUI(r)
        end
      end
    end
  end

  if addon then
    addon[registerFuncName] = doRegister
  end

  -- Auto-register the achievement immediately if the panel is ready
  if addon and addon.CreateAchievementRow then
    doRegister()
  end
end

MetaCommon.registerMetaAchievement = registerMetaAchievement

---------------------------------------
-- Module Export
---------------------------------------

if addon then
  addon.MetaCommon = MetaCommon
end