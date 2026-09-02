---------------------------------------
-- Meta Achievement Common Module
---------------------------------------
local addonName, addon = ...
local RefreshAllAchievementPoints = (addon and addon.RefreshAllAchievementPoints)
local MetaCommon = {}

---------------------------------------
-- Registration Function
---------------------------------------

-- Dungeon trio/duo/solo suffixes (must match DungeonCommon VARIATIONS).
local DUNGEON_VARIATION_SUFFIXES = { "_Trio", "_Duo", "_Solo" }

local function IsSingleAchievementCompleted(reqAchId)
  local id = tostring(reqAchId)

  local progress = addon and addon.GetProgress and addon.GetProgress(id)
  if progress and progress.completed then
    return true
  end

  if addon and addon.GetAchievementRow then
    local reqRow = addon.GetAchievementRow(id)
    if reqRow and reqRow.completed then
      return true
    end
  end

  if addon and addon.GetCharDB then
    local _, cdb = addon.GetCharDB()
    local rec = cdb and cdb.achievements and cdb.achievements[id]
    if rec and rec.completed then
      return true
    end
  end

  return false
end

local function IsSingleAchievementFailed(reqAchId)
  local id = tostring(reqAchId)
  if IsSingleAchievementCompleted(id) then
    return false
  end

  local row = nil
  if addon and addon.GetAchievementRow then
    row = addon.GetAchievementRow(id)
  end
  if row and addon and addon.IsRowOutleveled and addon.IsRowOutleveled(row) then
    return true
  end

  if addon and addon.GetCharDB then
    local _, cdb = addon.GetCharDB()
    local rec = cdb and cdb.achievements and cdb.achievements[id]
    if rec and not rec.completed and (rec.failed or rec.failedAt) then
      return true
    end
  end

  local progress = addon and addon.GetProgress and addon.GetProgress(id)
  if progress and progress.failed then
    return true
  end

  return false
end

local function GetRequirementCompletionIds(reqAchId, acceptAnyVariation)
  local baseId = tostring(reqAchId)
  local ids = { baseId }
  if acceptAnyVariation then
    for i = 1, #DUNGEON_VARIATION_SUFFIXES do
      ids[#ids + 1] = baseId .. DUNGEON_VARIATION_SUFFIXES[i]
    end
  end
  return ids
end

-- Failure candidates: base always; variations only when registered (missing Solo must not block).
local function GetRequirementFailureIds(reqAchId, acceptAnyVariation)
  local baseId = tostring(reqAchId)
  local ids = { baseId }
  if acceptAnyVariation and addon and addon.AchievementDefs then
    for i = 1, #DUNGEON_VARIATION_SUFFIXES do
      local variationId = baseId .. DUNGEON_VARIATION_SUFFIXES[i]
      if addon.AchievementDefs[variationId] then
        ids[#ids + 1] = variationId
      end
    end
  end
  return ids
end

local function IsRequirementCompleted(reqAchId, acceptAnyVariation)
  local ids = GetRequirementCompletionIds(reqAchId, acceptAnyVariation)
  for i = 1, #ids do
    if IsSingleAchievementCompleted(ids[i]) then
      return true
    end
  end
  return false
end

local function IsRequirementFailed(reqAchId, acceptAnyVariation)
  if IsRequirementCompleted(reqAchId, acceptAnyVariation) then
    return false
  end

  local ids = GetRequirementFailureIds(reqAchId, acceptAnyVariation)
  for i = 1, #ids do
    if not IsSingleAchievementFailed(ids[i]) then
      return false
    end
  end
  return #ids > 0
end

-- Shared for tooltips / other callers
if addon then
  addon.IsMetaRequirementCompleted = IsRequirementCompleted
  addon.IsMetaRequirementFailed = IsRequirementFailed
end

local function registerMetaAchievement(def)
  local achId = def.achId
  local title = def.title
  local tooltip = def.tooltip
  local icon = def.icon
  local points = def.points
  local requiredAchievements = def.requiredAchievements or {} -- Array of achievement IDs
  local achievementOrder = def.achievementOrder -- Optional ordering for tooltip display
  local acceptAnyVariation = def.acceptAnyVariation == true

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
    acceptAnyVariation = acceptAnyVariation,
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
  local function GetCurrentCompletionState()
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
    if progress and progress.completed then
      return true
    end

    if addon and addon.GetAchievementRow then
      local row = addon.GetAchievementRow(achId)
      if row and row.completed then
        return true
      end
    end

    if addon and addon.GetCharDB then
      local _, cdb = addon.GetCharDB()
      local rec = cdb and cdb.achievements and cdb.achievements[tostring(achId)]
      if rec and rec.completed then
        return true
      end
    end

    return false
  end

  local function LoadProgress()
    state.completed = GetCurrentCompletionState()
  end

  -- Save progress to database
  local function SaveProgress()
    if state.completed then
      if addon and addon.SetProgress then addon.SetProgress(achId, "completed", true) end
    end
  end

  -- Helper function to check if any required achievement is failed/outleveled
  -- When acceptAnyVariation is set, a dungeon only fails the meta if every registered
  -- base/variation path is failed (e.g. failed 5-man but open Duo still counts as available).
  local function AnyRequiredAchievementFailed()
    if not requiredAchievements or #requiredAchievements == 0 then
      return false
    end

    for _, reqAchId in ipairs(requiredAchievements) do
      if IsRequirementFailed(reqAchId, acceptAnyVariation) then
        return true
      end
    end

    return false
  end

  -- Helper function to check if all required achievements are completed
  -- When acceptAnyVariation is set, any completed base/Trio/Duo/Solo satisfies that dungeon.
  local function AllRequiredAchievementsCompleted()
    if not requiredAchievements or #requiredAchievements == 0 then
      return false
    end

    for _, reqAchId in ipairs(requiredAchievements) do
      if not IsRequirementCompleted(reqAchId, acceptAnyVariation) then
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

  -- If a prerequisite failure is corrected later (for example via admin action),
  -- the meta should return to available/complete state instead of staying failed
  -- until someone manually deletes the meta record.
  local function ClearFailedState()
    if not (addon and addon.GetCharDB) then
      return false
    end
    local _, cdb = addon.GetCharDB()
    local rec = cdb and cdb.achievements and cdb.achievements[tostring(achId)]
    if not rec then
      return false
    end

    local changed = false
    if rec.failed then
      rec.failed = nil
      changed = true
    end
    if rec.failedAt then
      rec.failedAt = nil
      changed = true
    end
    return changed
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
    state.completed = GetCurrentCompletionState()
    if state.completed then
      return true
    end

    -- If any required achievement is failed, mark meta achievement as failed
    if AnyRequiredAchievementFailed() then
      MarkAsFailed()
      return false
    end

    -- Prerequisite failure was corrected; clear any stale failed state on this meta
    -- before checking completion so the dashboard/list can recover immediately.
    ClearFailedState()

    if AllRequiredAchievementsCompleted() then
      state.completed = true
      SaveProgress()
      return true
    end

    return false
  end

  -- Complete a meta row through the canonical completion path so completedAt/guild-first/recent
  -- and other side effects match regular achievements.
  local function CompleteMetaRow(row)
    if not row then return end

    local id = row.achId or row.id
    local alreadyCompleted = row.completed == true
    if not alreadyCompleted and addon and addon.GetCharDB and id then
      local _, cdb = addon.GetCharDB()
      local rec = cdb and cdb.achievements and cdb.achievements[tostring(id)]
      if rec and rec.completed then
        alreadyCompleted = true
      end
    end

    if (not alreadyCompleted) and addon and type(addon.CompleteAchievementWithToast) == "function" then
      addon.CompleteAchievementWithToast(row)
    elseif addon and addon.MarkRowCompleted then
      addon.MarkRowCompleted(row)
    else
      row.completed = true
    end

    UpdateUI(row)
  end

  -- Initialize
  LoadProgress()

  -- Dynamic names first so functions capture these locals
  local registerFuncName = "Register" .. achId
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
        CompleteMetaRow(row)
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

    -- Set meta flags on def (isMetaAchievement used by IsRowOutleveled for failed styling in list/Character panel)
    local metaDef = def or {}
    metaDef.isMeta = true
    metaDef.isMetaAchievement = true

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
      row.acceptAnyVariation = acceptAnyVariation
    end

    -- If this meta already qualifies at registration time, finalize it through MarkRowCompleted
    -- so the DB record, recent feed, toasts, and downstream handlers are consistent.
    if row and state.completed and not row.completed then
      CompleteMetaRow(row)
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
          -- Only call UpdateUI when *newly* marking as failed. If we already had rec.failed,
          -- calling UpdateUI every run would set PointsRefreshPending and cause RefreshAllAchievementPoints
          -- to run every frame (infinite loop, FPS drop at level 10+ when opening achievement panel).
          local wasAlreadyFailed = false
          if addon and addon.GetCharDB then
            local _, cdb = addon.GetCharDB()
            local rec = cdb and cdb.achievements and cdb.achievements[achId]
            wasAlreadyFailed = rec and rec.failed
          end
          MarkAsFailed()
          if not wasAlreadyFailed then
            UpdateUI(r)
          end
        else
          local clearedFailure = ClearFailedState()
          if clearedFailure then
            UpdateUI(r)
          end

          if CheckComplete() then
            CompleteMetaRow(r)
          end
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