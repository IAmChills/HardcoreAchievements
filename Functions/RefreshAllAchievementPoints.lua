-- RefreshAllAchievementPoints.lua
-- Function to refresh all achievement points and status text from scratch

-- Function to refresh all achievement points from scratch
function RefreshAllAchievementPoints()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    
    local preset = (_G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings()) or nil
    local isSelfFound = (_G.IsSelfFound and _G.IsSelfFound()) or false
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    
    for _, row in ipairs(AchievementPanel.achievements) do
        -- Check both row.id and row.achId (dungeon achievements use achId)
        local rowId = row.id or row.achId
        if rowId and not row.completed then
            -- For secret achievements that are not completed, use secretPoints instead of actual points
            if row.isSecretAchievement and row.secretPoints ~= nil then
                row.points = row.secretPoints
                if row.Points then
                    row.Points:SetText(tostring(row.secretPoints))
                end
                -- Skip the rest of the point calculation for secret achievements
            else
                -- Start from original points
                local originalPoints = row.originalPoints or row.points or 0
                local staticPoints = row.staticPoints or false
                local finalPoints = originalPoints
                
                if not staticPoints then
                    -- Apply preset multiplier (replaces base points)
                    local multiplier = (_G.GetPresetMultiplier and _G.GetPresetMultiplier(preset)) or 1.0
                    finalPoints = math.floor(originalPoints * multiplier + 0.5)
                    
                    -- Visual preview: if solo mode toggle is on and no stored points, show doubled points
                    -- This is just a preview - actual points are determined at kill/quest time
                    -- Solo preview applies: requires self-found if hardcore is active, otherwise solo is allowed
                    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
                    local allowSoloBonus = isSelfFound or not isHardcoreActive
                    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(rowId)
                    if isSoloMode and row.allowSoloDouble and allowSoloBonus and not (progress and progress.pointsAtKill) then
                        finalPoints = finalPoints * 2
                    end
                end
                
                -- Apply self-found bonus: +0.5x base points (rounded), applied after multiplier/solo preview.
                local isDungeonSet = row._def and row._def.isDungeonSet
                -- Reputation achievements SHOULD receive the self-found bonus.
                if isSelfFound and not row.isSecretAchievement and not isDungeonSet then
                    local getBonus = _G.HCA_GetSelfFoundBonus
                    local bonus = (type(getBonus) == "function") and getBonus(originalPoints) or 0
                    finalPoints = finalPoints + bonus
                end
                
                row.points = finalPoints
                if row.Points then
                    row.Points:SetText(tostring(finalPoints))
                end
                
                -- Update Sub text - check if we have stored solo status or ineligible status from previous kills/quests
                -- Only update Sub text for incomplete achievements to preserve completed achievement solo indicators
                if not row.completed and row.Sub and row.maxLevel and row.maxLevel > 0 then
                    local levelText = LEVEL .. " " .. row.maxLevel
                    -- Check progress for solo status and ineligible status
                    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(rowId)
                local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
                local hasIneligibleKill = progress and progress.ineligibleKill
                
                -- If we have stored pointsAtKill (solo kill/quest), use those points
                -- pointsAtKill doesn't include self-found bonus, so add it if applicable
                if progress and progress.pointsAtKill then
                    finalPoints = tonumber(progress.pointsAtKill) or finalPoints
                    -- Add self-found bonus if applicable (pointsAtKill doesn't include it)
                    local isDungeonSet = row._def and row._def.isDungeonSet
                    -- Reputation achievements SHOULD receive the self-found bonus.
                    if isSelfFound and not row.isSecretAchievement and not isDungeonSet then
                        local getBonus = _G.HCA_GetSelfFoundBonus
                        local bonus = (type(getBonus) == "function") and getBonus(originalPoints) or 0
                        finalPoints = finalPoints + bonus
                    end
                    row.points = finalPoints
                    if row.Points then
                        row.Points:SetText(tostring(finalPoints))
                    end
                end
                
                -- Use helper function to set status text
                if _G.HCA_SetStatusTextOnRow then
                    local requiresBoth = row.questTracker and row.killTracker
                    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                    local wasSolo = false
                    if row.completed then
                        local getCharDB = _G.GetCharDB or _G.HardcoreAchievements_GetCharDB
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
                    if requiresBoth and progress then
                        -- Check if kills are satisfied
                        local hasKill = false
                        if progress.killed then
                            hasKill = true
                        elseif progress.counts and next(progress.counts) ~= nil then
                            -- Check if all required kills are satisfied using eligibleCounts
                            if progress.eligibleCounts then
                                -- Find the achievement definition to check requiredKills
                                local achDef = nil
                                if _G.Achievements then
                                    for _, def in ipairs(_G.Achievements) do
                                        if def.achId == rowId then
                                            achDef = def
                                            break
                                        end
                                    end
                                end
                                
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
                        
                        killsSatisfied = hasKill and questNotTurnedIn
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

                    _G.HCA_SetStatusTextOnRow(row, {
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
                    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
                    local allowSoloBonus = isSelfFound or not isHardcoreActive
                    if hasIneligibleKill then
                        local requiresBoth = row.questTracker and row.killTracker
                        local message = requiresBoth and "|cffff4646Ineligible Kill|r"
                        row.Sub:SetText(levelText .. "\n" .. message)
                     elseif hasSoloStatus and allowSoloBonus then
                        row.Sub:SetText(levelText .. "\n|cffac81d6Pending solo|r")
                    else
                        row.Sub:SetText(levelText)
                    end
                end
                end
            end
        end
    end
    
    -- Check meta achievements for completion
    if _G.HCA_MetaAchievementCheckers then
        for achId, checkFn in pairs(_G.HCA_MetaAchievementCheckers) do
            if type(checkFn) == "function" then
                checkFn()
            end
        end
    end
    
    -- Update total points
    if HCA_UpdateTotalPoints then
        HCA_UpdateTotalPoints()
    end
    
    -- Update multiplier text if it exists
    if AchievementPanel and AchievementPanel.MultiplierText then
        local labelText = ""
        if preset or isSelfFound or isSoloMode then
            -- Build array of modifiers (preset goes last)
            local modifiers = {}
            if isSelfFound and not isSoloMode then
                table.insert(modifiers, "Self Found")
            end
            if isSoloMode and not isSelfFound then
                table.insert(modifiers, "Solo")
            end
            if isSoloMode and isSelfFound then
                table.insert(modifiers, "Solo Self Found")
            end
            if preset then
                table.insert(modifiers, preset)
            end
            
            labelText = "Point Multiplier (" .. table.concat(modifiers, ", ") .. ")"
        end
        
        AchievementPanel.MultiplierText:SetText(labelText)
        AchievementPanel.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
    end
    
    -- Sync character panel checkbox state if it exists
    if AchievementPanel and AchievementPanel.SoloModeCheckbox then
        AchievementPanel.SoloModeCheckbox:SetChecked(isSoloMode)
    end
end

return RefreshAllAchievementPoints

