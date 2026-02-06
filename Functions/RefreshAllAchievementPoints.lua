local addonName, addon = ...
local C_GameRules = C_GameRules
local C_Timer = C_Timer
local UnitLevel = UnitLevel
local math = math
local GetPresetMultiplier = (addon and addon.GetPresetMultiplier)
local UpdateMultiplierText = (addon and addon.UpdateMultiplierText)
local IsSelfFound = (addon and addon.IsSelfFound)
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

-- Check if kills are satisfied for an achievement that requires both kills and quest
local function CheckKillsSatisfied(row, rowId, progress, defById)
    if not progress then
        return false
    end
    
    local hasKill = false
    
    if progress.killed then
        hasKill = true
    elseif progress.counts and next(progress.counts) ~= nil then
        -- Check if all required kills are satisfied using eligibleCounts
        if progress.eligibleCounts then
            -- Use a pre-built lookup table for definitions (avoid scanning the full catalog per row)
            local achDef = defById and defById[tostring(rowId)] or nil
            
            if achDef and achDef.requiredKills then
                local allSatisfied = true
                for npcId, requiredCount in pairs(achDef.requiredKills) do
                    local idNum = tonumber(npcId) or npcId
                    local current = progress.eligibleCounts[idNum] or progress.eligibleCounts[tostring(idNum)] or 0
                    local required = tonumber(requiredCount) or 1
                    if current < required then
                        allSatisfied = false
                        break
                    end
                end
                hasKill = allSatisfied
            else
                -- Single kill achievement, check killed flag
                hasKill = progress.killed or false
            end
        elseif progress.killed then
            hasKill = true
        end
    end
    
    -- Check if quest is not yet turned in
    local questNotTurnedIn = not progress.quest
    
    return hasKill and questNotTurnedIn
end

-- Update status text for an achievement row
local function UpdateRowStatusText(row, rowId, progress, isSelfFound, isSoloMode, isHardcoreActive, allowSoloBonus, defById)
    if not row.Sub or not row.maxLevel or row.maxLevel <= 0 then
        return
    end
    
    local levelText = LEVEL .. " " .. row.maxLevel
    local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
    local hasIneligibleKill = progress and progress.ineligibleKill
    local requiresBoth = row.questTracker and row.killTracker
    
    -- Use helper function to set status text
    if SetStatusTextOnRow then
        local wasSolo = false
        if row.completed then
            local getCharDB = addon and addon.GetCharDB
            if getCharDB then
                local _, cdb = getCharDB()
                if cdb and cdb.achievements and rowId then
                    local achRec = cdb.achievements[rowId]
                    wasSolo = achRec and achRec.wasSolo or false
                end
            end
        end
        
        -- Check if kills are satisfied but quest is pending
        local killsSatisfied = false
        if requiresBoth then
            killsSatisfied = CheckKillsSatisfied(row, rowId, progress, defById)
        end
        
        local playerLevel = UnitLevel("player") or 1
        local isOutleveled = false
        -- Check if player is over level, but don't mark as outleveled if there's pending turn-in
        if (not row.completed) and row.maxLevel and (playerLevel > row.maxLevel) then
            -- If kills are satisfied but quest is not turned in, keep achievement available
            if killsSatisfied then
                isOutleveled = false
            else
                isOutleveled = true
            end
        end

        SetStatusTextOnRow(row, {
            completed = row.completed or false,
            hasSoloStatus = hasSoloStatus,
            hasIneligibleKill = hasIneligibleKill,
            requiresBoth = requiresBoth,
            killsSatisfied = killsSatisfied,
            isSelfFound = isSelfFound,
            isSoloMode = isSoloMode,
            wasSolo = wasSolo,
            allowSoloDouble = row.allowSoloDouble,
            maxLevel = row.maxLevel,
            isOutleveled = isOutleveled
        })

        if isOutleveled and progress then
            progress.soloKill = nil
            progress.soloQuest = nil
        end
    else
        -- Fallback if helper not available
        if hasIneligibleKill then
            local message = requiresBoth and "|cffff4646Ineligible Kill|r" or ""
            row.Sub:SetText(levelText .. "\n" .. message)
        elseif hasSoloStatus and allowSoloBonus then
            row.Sub:SetText(levelText .. "\n|cffac81d6Pending solo|r")
        else
            row.Sub:SetText(levelText)
        end
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
    local allowSoloBonus = IsSelfFound() or not isHardcoreActive

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
            local finalPoints = CalculateAchievementPoints(row, preset, IsSelfFound(), isSoloMode, progress)
            
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
                UpdateRowStatusText(frame, rowId, progress, IsSelfFound(), isSoloMode, isHardcoreActive, allowSoloBonus, defById)
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

