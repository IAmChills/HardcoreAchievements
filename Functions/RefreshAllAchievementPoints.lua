local addonName, addon = ...
local C_GameRules = C_GameRules
local C_Timer = C_Timer
local UnitLevel = UnitLevel
local math = math
local GetPresetMultiplier = (addon and addon.GetPresetMultiplier)
local UpdateMultiplierText = (addon and addon.UpdateMultiplierText)
-- Resolve at call time: this file loads before SharedUtils so addon.IsSelfFound is nil at load
local tonumber = tonumber
local pairs = pairs
local type = type
local ipairs = ipairs
local tostring = tostring

---------------------------------------
-- Helper Functions
---------------------------------------

-- Calculate final points for an achievement row
local function CalculateAchievementPoints(row, preset, isSelfFound, isSoloMode, progress)
    -- For secret achievements that are not completed, use secretPoints
    if row.isSecretAchievement and row.secretPoints ~= nil then
        return row.secretPoints
    end
    
    local originalPoints = row.originalPoints or row.points or 0
    local staticPoints = row.staticPoints or false
    local finalPoints = originalPoints
    
    -- Check if we have stored pointsAtKill (solo kill/quest) - use those points first
    local hasStoredPoints = progress and progress.pointsAtKill
    
    if hasStoredPoints then
        -- Use stored points (already doubled if solo, includes multiplier if applicable)
        finalPoints = tonumber(progress.pointsAtKill) or finalPoints
    elseif not staticPoints then
        -- Apply preset multiplier (replaces base points)
        local multiplier = GetPresetMultiplier(preset) or 1.0
        finalPoints = math.floor(originalPoints * multiplier + 0.5)
        
        -- Visual preview: if solo mode toggle is on and no stored points, show doubled points
        -- This is just a preview - actual points are determined at kill/quest time
        -- Solo preview applies: requires self-found if hardcore is active, otherwise solo is allowed
        local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
        local allowSoloBonus = isSelfFound or not isHardcoreActive
        if isSoloMode and row.allowSoloDouble and allowSoloBonus then
            finalPoints = finalPoints * 2
        end
    end
    
    -- Self-found bonus should be reflected in the displayed points (preview + stored),
    -- with a simple rule: 0-point achievements remain 0 (bonus computes to 0).
    if isSelfFound then
        local getBonus = addon and addon.GetSelfFoundBonus
        local bonus = (type(getBonus) == "function") and getBonus(originalPoints) or 0
        if bonus > 0 and finalPoints > 0 then
            finalPoints = finalPoints + bonus
        end
    end
    
    return finalPoints
end

-- Update status text for an achievement row (uses centralized GetStatusParamsForAchievement)
local function UpdateRowStatusText(row, rowId, progress, isSelfFound, isSoloMode, isHardcoreActive, allowSoloBonus, defById)
    if not row or not row.Sub or not row.maxLevel or row.maxLevel <= 0 then return end
    local setStatus = addon and addon.SetStatusTextOnRow
    if not setStatus or not (addon and addon.GetStatusParamsForAchievement) then return end
    local params = addon.GetStatusParamsForAchievement(rowId, row)
    if not params then return end
    setStatus(row, params)
    if params.isOutleveled and progress then
        progress.soloKill = nil
        progress.soloQuest = nil
    end
end

---------------------------------------
-- Main Function
---------------------------------------

-- Function to refresh all achievement points from scratch
local function RefreshAllAchievementPoints()
    local rows = (addon and addon.AchievementRowModel) or {}
    if #rows == 0 then return end

    -- Re-entrancy guard: Meta achievement checkers (and other UI updaters) may request a refresh
    -- while a refresh is already running. Nested refresh calls cause infinite recursion and
    -- "script ran too long". Instead, coalesce into one extra refresh after this pass.
    if addon and addon.RefreshingPoints then
        addon.PointsRefreshPending = true
        return
    end
    if addon then addon.RefreshingPoints = true end
    
    -- Calculate shared values once at the top
    local preset = (addon and addon.GetPlayerPresetFromSettings and addon.GetPlayerPresetFromSettings()) or nil
    local isSoloMode = (addon and addon.IsSoloModeEnabled and addon.IsSoloModeEnabled()) or false
    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
    local isSelfFoundFn = addon and addon.IsSelfFound
    local allowSoloBonus = (type(isSelfFoundFn) == "function" and isSelfFoundFn()) or not isHardcoreActive

    -- Build a fast lookup table for achievement definitions (by achId) once.
    local defById = {}
    local achievementsList = (addon and addon.CatalogAchievements)
    if achievementsList then
        for _, def in ipairs(achievementsList) do
            if def and def.achId ~= nil then
                defById[tostring(def.achId)] = def
            end
        end
    end
    
    for _, row in ipairs(rows) do
        -- Check both row.id and row.achId (dungeon achievements use achId)
        local rowId = row.id or row.achId
        if rowId and not row.completed then
            -- Get progress once for this row
            local progress = addon and addon.GetProgress and addon.GetProgress(rowId)
            
            -- Calculate and set points
            local finalPoints = CalculateAchievementPoints(row, preset, (type(isSelfFoundFn) == "function" and isSelfFoundFn()), isSoloMode, progress)
            
            row.points = finalPoints
            local frame = row.frame
            if frame then
                frame.points = finalPoints
                if frame.Points then
                    frame.Points:SetText(tostring(finalPoints))
                end
            end
            
            -- Re-apply point-circle UI rules (e.g., 0-point shield icon) after recalculation
            if frame and addon and addon.UpdatePointsDisplay then
                addon.UpdatePointsDisplay(frame)
            end
            
            -- Update Sub text - check if we have stored solo status or ineligible status from previous kills/quests
            -- Only update Sub text for incomplete achievements to preserve completed achievement solo indicators
            if frame and not row.completed then
                UpdateRowStatusText(frame, rowId, progress, (type(isSelfFoundFn) == "function" and isSelfFoundFn()), isSoloMode, isHardcoreActive, allowSoloBonus, defById)
            end
        end
    end
    
    -- Check meta achievements for completion
    if addon and addon.MetaAchievementCheckers then
        for achId, checkFn in pairs(addon.MetaAchievementCheckers) do
            if type(checkFn) == "function" then
                checkFn()
            end
        end
    end
    
    -- Update total points
    if addon and addon.UpdateTotalPoints then
        addon.UpdateTotalPoints()
    end
    
    -- Update multiplier text if it exists (using centralized function)
    if AchievementPanel and AchievementPanel.MultiplierText and UpdateMultiplierText then
        UpdateMultiplierText(AchievementPanel.MultiplierText)
    end
    -- Update Dashboard multiplier text if it exists
    if DashboardFrame and DashboardFrame.MultiplierText and UpdateMultiplierText then
        UpdateMultiplierText(DashboardFrame.MultiplierText, {0.922, 0.871, 0.761})
    end
    
    -- Sync character panel checkbox state if it exists
    if AchievementPanel and AchievementPanel.SoloModeCheckbox then
        AchievementPanel.SoloModeCheckbox:SetChecked(isSoloMode)
    end

    -- Re-apply failed/completed styling to all rows (e.g. metas marked failed by checkers above)
    if addon and addon.RefreshOutleveledAll then
        addon.RefreshOutleveledAll()
    end

    if addon then addon.RefreshingPoints = nil end
    if addon and addon.PointsRefreshPending then
        addon.PointsRefreshPending = nil
        C_Timer.After(0, function()
            if not (addon and addon.RefreshingPoints) then
                RefreshAllAchievementPoints()
            end
        end)
    end
end

if addon then
    addon.RefreshAllAchievementPoints = RefreshAllAchievementPoints
end

