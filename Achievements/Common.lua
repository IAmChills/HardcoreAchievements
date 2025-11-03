-- Achievements_Common.lua
-- Shared factory for standard (quest/kill under level cap) achievements.
local M = {}

-- Load GetPlayerPresetFromSettings function from GetUHCPreset
local GetPlayerPresetFromSettings = _G.GetPlayerPresetFromSettings

local function getNpcIdFromGUID(guid)
    if not guid then
        return nil
    end
    local npcId = select(6, strsplit("-", guid))
    return npcId and tonumber(npcId) or nil
end

function M.registerQuestAchievement(cfg)
    assert(type(cfg.achId) == "string", "achId required")
    local ACH_ID = cfg.achId
    local REQUIRED_QUEST_ID = cfg.requiredQuestId
    local TARGET_NPC_ID = cfg.targetNpcId
    -- Support multiple target NPC IDs (number or {ids})
    local function isTargetNpcId(npcId)
        if not TARGET_NPC_ID then return false end
        local n = tonumber(npcId)
        if not n then return false end
        if type(TARGET_NPC_ID) == "table" then
            for _, id in pairs(TARGET_NPC_ID) do
                if tonumber(id) == n then return true end
            end
            return false
        end
        return tonumber(TARGET_NPC_ID) == n
    end

    local MAX_LEVEL = tonumber(cfg.maxLevel)
    local FACTION, RACE, CLASS = cfg.faction, cfg.race, cfg.class

    local state = {
        completed = false,
        killed = false,
        quest = false
    }

    local function gate()
        if FACTION and UnitFactionGroup("player") ~= FACTION then return false end
        if RACE then
            local _, raceFile = UnitRace("player")
            if raceFile ~= RACE then return false end
        end
        if CLASS then
            local _, classFile = UnitClass("player")
            if classFile ~= CLASS then return false end
        end
        return true
    end

    local function belowMax()
        local lvl = UnitLevel("player") or 1
        if MAX_LEVEL and MAX_LEVEL > 0 then
            return lvl <= MAX_LEVEL
        end
        return true -- no level cap
    end

    local function setProg(key, val)
        if HardcoreAchievements_SetProgress then
            HardcoreAchievements_SetProgress(ACH_ID, key, val)
        end
    end

    local function serverQuestDone()
        if not REQUIRED_QUEST_ID then
            return false
        end
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            return C_QuestLog.IsQuestFlaggedCompleted(REQUIRED_QUEST_ID) or false
        end
        if IsQuestFlaggedCompleted then
            return IsQuestFlaggedCompleted(REQUIRED_QUEST_ID) or false
        end
        return false
    end

    local function topUpFromServer()
        if REQUIRED_QUEST_ID and not state.quest and serverQuestDone() then
            -- Only store quest completion if player is not over-leveled
            if belowMax() then
                state.quest = true
                setProg("quest", true)
                
                -- Check if we already have pointsAtKill from a previous NPC kill
                -- If we do, preserve it; if not, store points based on current solo status
                local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                local existingPointsAtKill = progressTable and progressTable.pointsAtKill
                
                if not existingPointsAtKill then
                    -- No existing pointsAtKill, check if quest completion was solo (check at time of topUp)
                    -- Solo points only apply if player is self-found
                    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                    local isSoloQuest = isSelfFound and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                    
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and row.points then
                                -- Get the original base points (before preview doubling or self-found bonus)
                                -- Check if row.points has been doubled by preview toggle
                                local currentPoints = tonumber(row.points) or 0
                                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                                local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                                
                                -- Detect if points have been doubled by preview toggle
                                local basePoints = currentPoints
                                if isSelfFound and not row.isSecretAchievement then
                                    basePoints = basePoints - HCA_SELF_FOUND_BONUS
                                end
                                -- If solo mode toggle is on and row.allowSoloDouble, the points might be doubled
                                -- Use originalPoints if available, otherwise divide by 2 if doubled
                                if row.originalPoints then
                                    -- Use stored original points
                                    basePoints = tonumber(row.originalPoints) or basePoints
                                    -- Apply multiplier if not static
                                    if not row.staticPoints then
                                        local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                        local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                        basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
                                    end
                                elseif isSoloMode and row.allowSoloDouble and not row.staticPoints then
                                    -- Points might have been doubled by preview, divide by 2 to get base
                                    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                    if not (progress and progress.pointsAtKill) then
                                        basePoints = math.floor(basePoints / 2 + 0.5)
                                    end
                                end
                                
                                local pointsToStore = basePoints
                                -- If solo quest, store doubled points; otherwise store regular points
                                if isSoloQuest then
                                    pointsToStore = basePoints * 2
                                    -- Update points display to show doubled value (including self-found bonus for display)
                                    local displayPoints = pointsToStore
                                    if isSelfFound and not row.isSecretAchievement then
                                        displayPoints = displayPoints + HCA_SELF_FOUND_BONUS
                                    end
                                    row.points = displayPoints
                                    if row.Points then
                                        row.Points:SetText(tostring(displayPoints) .. " pts")
                                    end
                                    -- Set "pending solo" indicator on the achievement row (not yet completed)
                                    if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                        local levelText = LEVEL .. " " .. row.maxLevel
                                        row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                                    elseif row.Sub then
                                        row.Sub:SetText("|cFF9D3AFFPending solo|r")
                                    end
                                end
                                setProg("pointsAtKill", pointsToStore)
                                -- Also store solo status for later reference
                                setProg("soloQuest", isSoloQuest)
                                break
                            end
                        end
                    end
                else
                    -- We have existing pointsAtKill from NPC kill, preserve it
                    -- But still update solo status if current check is solo (for indicator purposes)
                    local isSoloQuest = _G.PlayerIsSolo and _G.PlayerIsSolo() or false
                    if isSoloQuest then
                        -- Update solo quest status and indicator (only if not completed)
                        setProg("soloQuest", true)
                        if AchievementPanel and AchievementPanel.achievements then
                            for _, row in ipairs(AchievementPanel.achievements) do
                                if row.id == ACH_ID and not row.completed then
                                    -- Use stored pointsAtKill value if available (doubled for solo)
                                    local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                    if progressTable and progressTable.pointsAtKill then
                                        row.points = tonumber(progressTable.pointsAtKill) or row.points
                                        if row.Points then
                                            row.Points:SetText(tostring(row.points) .. " pts")
                                        end
                                    end
                                    if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                        local levelText = LEVEL .. " " .. row.maxLevel
                                        row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                                    elseif row.Sub then
                                        row.Sub:SetText("|cFF9D3AFFPending solo|r")
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                return true
            end
        end
    end

    local function checkComplete()
        if state.completed then
            return true
        end
        if not gate() or not belowMax() then
            return false
        end
		
		-- Check both state and progress table for kill/quest completion
		local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
		local killFromProgress = progressTable and progressTable.killed
		local questFromProgress = progressTable and progressTable.quest
		
		local questOk = (not REQUIRED_QUEST_ID) or state.quest or questFromProgress
		
		-- If both a quest and an NPC are required, the quest alone should fulfill
		-- the achievement (NPC kill becomes optional when quest is defined).
		if REQUIRED_QUEST_ID and TARGET_NPC_ID then
			-- Quest alone is sufficient for completion
			if questOk then
				state.completed = true
				setProg("completed", true)
				return true
			end
			return false
		end

		-- Otherwise, require each defined component individually
		local killOk = (not TARGET_NPC_ID) or state.killed or killFromProgress
		if killOk and questOk then
			state.completed = true
			setProg("completed", true)
			return true
		end
		return false
    end

    do
        local p = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
        if p then
            state.killed = not not p.killed
            state.quest = not not p.quest
            state.completed = not not p.completed
        end
        topUpFromServer()
        -- Check if we have solo status from previous kills/quests and update UI
        -- Solo indicators only show if player is self-found
        local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
        if p and (p.soloKill or p.soloQuest) and isSelfFound then
            if AchievementPanel and AchievementPanel.achievements then
                for _, row in ipairs(AchievementPanel.achievements) do
                    if row.id == ACH_ID then
                        -- Restore "pending solo" indicator if it was a solo kill/quest and not completed
                        if (p.soloKill or p.soloQuest) and not state.completed and isSelfFound then
                            -- Use stored pointsAtKill value if available (doubled for solo kills)
                            if p.pointsAtKill then
                                row.points = tonumber(p.pointsAtKill) or row.points
                                if row.Points then
                                    row.Points:SetText(tostring(row.points) .. " pts")
                                end
                            end
                            if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                local levelText = LEVEL .. " " .. row.maxLevel
                                row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                            elseif row.Sub then
                                row.Sub:SetText("|cFF9D3AFFPending solo|r")
                            end
                        end
                        break
                    end
                end
            end
        end
        checkComplete()
    end

    if TARGET_NPC_ID then
        _G[ACH_ID .. "_Kill"] = function(destGUID)
            if state.completed or not belowMax() then
                return false
            end
            local destId = getNpcIdFromGUID(destGUID)
            if not isTargetNpcId(destId) then
                return false
            end
            -- Solo points only apply if player is self-found
            -- Always require PlayerIsSolo check regardless of toggle state
            -- This validates the kill was actually solo
            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
            local isSoloKill = isSelfFound and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
            
            state.killed = true
            setProg("killed", true)
            
            -- Store points at time of kill, doubled if solo, regular if not
            -- Need to find the row and calculate points WITHOUT self-found bonus
            -- Self-found bonus will be added at completion time
            if AchievementPanel and AchievementPanel.achievements then
                for _, row in ipairs(AchievementPanel.achievements) do
                    if row.id == ACH_ID and row.points then
                        -- Get the original base points (before preview doubling or self-found bonus)
                        -- Check if row.points has been doubled by preview toggle
                        local currentPoints = tonumber(row.points) or 0
                        local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                        local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                        
                        -- Detect if points have been doubled by preview toggle
                        local basePoints = currentPoints
                        if isSelfFound and not row.isSecretAchievement then
                            basePoints = basePoints - HCA_SELF_FOUND_BONUS
                        end
                        -- If solo mode toggle is on and row.allowSoloDouble, the points might be doubled
                        -- Use originalPoints if available, otherwise divide by 2 if doubled
                        if row.originalPoints then
                            -- Use stored original points
                            basePoints = tonumber(row.originalPoints) or basePoints
                            -- Apply multiplier if not static
                            if not row.staticPoints then
                                local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
                            end
                        elseif isSoloMode and row.allowSoloDouble and not row.staticPoints then
                            -- Points might have been doubled by preview, divide by 2 to get base
                            local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                            if not (progress and progress.pointsAtKill) then
                                basePoints = math.floor(basePoints / 2 + 0.5)
                            end
                        end
                        
                        local pointsToStore = basePoints
                        -- If solo kill, store doubled points; otherwise store regular points
                        if isSoloKill then
                            pointsToStore = basePoints * 2
                            -- Update points display to show doubled value (including self-found bonus for display)
                            local displayPoints = pointsToStore
                            if isSelfFound and not row.isSecretAchievement then
                                displayPoints = displayPoints + HCA_SELF_FOUND_BONUS
                            end
                            row.points = displayPoints
                            if row.Points then
                                row.Points:SetText(tostring(displayPoints) .. " pts")
                            end
                            -- Set "pending solo" indicator on the achievement row (not yet completed)
                            if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                local levelText = LEVEL .. " " .. row.maxLevel
                                row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                            elseif row.Sub then
                                row.Sub:SetText("|cFF9D3AFFPending solo|r")
                            end
                        end
                        setProg("pointsAtKill", pointsToStore)
                        -- Also store solo status for later reference
                        setProg("soloKill", isSoloKill)
                        break
                    end
                end
            end
            return checkComplete()
        end
    end

    if REQUIRED_QUEST_ID then
        _G[ACH_ID .. "_Quest"] = function(questID)
            if state.completed or not belowMax() then
                return false
            end
            if questID ~= REQUIRED_QUEST_ID then
                return false
            end
            
            state.quest = true
            setProg("quest", true)
            
            -- Check if we already have pointsAtKill from a previous NPC kill
            -- If we do, preserve it; if not, store points based on quest turn-in solo status
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            local existingPointsAtKill = progressTable and progressTable.pointsAtKill
            
            if not existingPointsAtKill then
                -- No existing pointsAtKill, check if quest completion was solo
                -- Solo points only apply if player is self-found
                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                local isSoloQuest = isSelfFound and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                
                if AchievementPanel and AchievementPanel.achievements then
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if row.id == ACH_ID and row.points then
                            -- Get the original base points (before preview doubling or self-found bonus)
                            -- Check if row.points has been doubled by preview toggle
                            local currentPoints = tonumber(row.points) or 0
                            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                            local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                            
                            -- Detect if points have been doubled by preview toggle
                            local basePoints = currentPoints
                            if isSelfFound and not row.isSecretAchievement then
                                basePoints = basePoints - HCA_SELF_FOUND_BONUS
                            end
                            -- If solo mode toggle is on and row.allowSoloDouble, the points might be doubled
                            -- Use originalPoints if available, otherwise divide by 2 if doubled
                            if row.originalPoints then
                                -- Use stored original points
                                basePoints = tonumber(row.originalPoints) or basePoints
                                -- Apply multiplier if not static
                                if not row.staticPoints then
                                    local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                    local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                    basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
                                end
                            elseif isSoloMode and row.allowSoloDouble and not row.staticPoints then
                                -- Points might have been doubled by preview, divide by 2 to get base
                                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                if not (progress and progress.pointsAtKill) then
                                    basePoints = math.floor(basePoints / 2 + 0.5)
                                end
                            end
                            
                            local pointsToStore = basePoints
                            -- If solo quest, store doubled points; otherwise store regular points
                            if isSoloQuest then
                                pointsToStore = basePoints * 2
                                -- Update points display to show doubled value (including self-found bonus for display)
                                local displayPoints = pointsToStore
                                if isSelfFound and not row.isSecretAchievement then
                                    displayPoints = displayPoints + HCA_SELF_FOUND_BONUS
                                end
                                row.points = displayPoints
                                if row.Points then
                                    row.Points:SetText(tostring(displayPoints) .. " pts")
                                end
                                -- Set "pending solo" indicator on the achievement row (not yet completed)
                                if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                    local levelText = LEVEL .. " " .. row.maxLevel
                                    row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                                elseif row.Sub then
                                    row.Sub:SetText("|cFF9D3AFFPending solo|r")
                                end
                            end
                            setProg("pointsAtKill", pointsToStore)
                            -- Also store solo status for later reference
                            setProg("soloQuest", isSoloQuest)
                            break
                        end
                    end
                end
                else
                    -- We have existing pointsAtKill from NPC kill, preserve it
                    -- But still update solo status if quest was solo (for indicator purposes)
                    -- Solo points only apply if player is self-found
                    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                    local isSoloQuest = isSelfFound and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                    if isSoloQuest then
                    -- Update solo quest status and indicator (only if not completed)
                    setProg("soloQuest", true)
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and not row.completed then
                                -- Use stored pointsAtKill value if available (doubled for solo)
                                -- pointsAtKill doesn't include self-found bonus, so add it if applicable
                                local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                if progressTable and progressTable.pointsAtKill then
                                    local storedPoints = tonumber(progressTable.pointsAtKill) or row.points
                                    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                                    if isSelfFound and not row.isSecretAchievement then
                                        storedPoints = storedPoints + HCA_SELF_FOUND_BONUS
                                    end
                                    row.points = storedPoints
                                    if row.Points then
                                        row.Points:SetText(tostring(storedPoints) .. " pts")
                                    end
                                end
                                if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                    local levelText = LEVEL .. " " .. row.maxLevel
                                    row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                                elseif row.Sub then
                                    row.Sub:SetText("|cFF9D3AFFPending solo|r")
                                end
                                break
                            end
                        end
                    end
                end
            end
            return checkComplete()
        end

        local f = CreateFrame("Frame")
        f:RegisterEvent("QUEST_LOG_UPDATE")
        f:SetScript("OnEvent", function(self)
            if state.completed then
                self:UnregisterAllEvents()
                return
            end
            C_Timer.After(0.25, function()
                if topUpFromServer() and checkComplete() then
                    self:UnregisterAllEvents()
                end
            end)
        end)
    end

    _G[ACH_ID .. "_IsCompleted"] = function()
        if state.completed then
            return true
        end
        if topUpFromServer() then
            return checkComplete()
        end
        return false
    end
end

_G.Achievements_Common = M
return M