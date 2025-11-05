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
    local REQUIRED_KILLS = cfg.requiredKills -- Support kill counts: { [npcId] = count }
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
        quest = false,
        counts = {} -- Track kill counts when requiredKills is used
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
        -- Check stored levels: prioritize levelAtKill (when NPC was killed), then levelAtTurnIn (fallback)
        local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
        local levelToCheck = nil
        if progressTable then
            -- Priority: levelAtKill > levelAtTurnIn > current level
            levelToCheck = progressTable.levelAtKill or progressTable.levelAtTurnIn
        end
        if not levelToCheck then
            levelToCheck = UnitLevel("player") or 1
        end
        if MAX_LEVEL and MAX_LEVEL > 0 then
            return levelToCheck <= MAX_LEVEL
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
            -- Check level before storing quest completion
            -- Priority: levelAtKill (from NPC kill) > levelAtTurnIn (fallback) > current level
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            local levelToCheck = nil
            if progressTable then
                -- Prefer levelAtKill if available, otherwise use levelAtTurnIn
                levelToCheck = progressTable.levelAtKill or progressTable.levelAtTurnIn
            end
            if not levelToCheck then
                levelToCheck = UnitLevel("player") or 1
            end
            -- Only store quest completion if player was not over-leveled at kill/turn-in
            if not (MAX_LEVEL and MAX_LEVEL > 0 and levelToCheck > MAX_LEVEL) then
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
                                        row.Sub:SetText(levelText .. "\n|cFFac81d6Pending solo|r")
                                    elseif row.Sub then
                                        row.Sub:SetText("|cFFac81d6Pending solo|r")
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
                                        row.Sub:SetText(levelText .. "\n|cFFac81d6Pending solo|r")
                                    elseif row.Sub then
                                        row.Sub:SetText("|cFFac81d6Pending solo|r")
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

    -- Check if all required kills are satisfied (when requiredKills is used)
    local function countsSatisfied()
        if not REQUIRED_KILLS then return true end
        for npcId, need in pairs(REQUIRED_KILLS) do
            -- Ensure numeric key for lookup
            local idNum = tonumber(npcId) or npcId
            local current = state.counts[idNum] or 0
            local required = tonumber(need) or 1
            if current < required then
                return false
            end
        end
        return true
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
		
		-- Check if there's an ineligible kill flag - achievement was done when group was ineligible
		if progressTable and progressTable.ineligibleKill then
			-- Check if group is now eligible - if so, clear the flag and allow completion
			local isGroupEligible = true
			if _G.IsGroupEligibleForAchievement then
				isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
			end
			if not isGroupEligible then
				return false -- Group still not eligible, don't complete
			end
			-- Group is now eligible, clear the ineligible flag
			setProg("ineligibleKill", false)
		end
		
		local killFromProgress = progressTable and progressTable.killed
		local questFromProgress = progressTable and progressTable.quest
		
		local questOk = (not REQUIRED_QUEST_ID) or state.quest or questFromProgress
		
		-- If requiredKills is defined, check kill counts instead of single kill
		if REQUIRED_KILLS then
			local killsOk = countsSatisfied()
			-- Complete if all kills are satisfied OR quest is turned in
			if killsOk or questOk then
				-- Check group eligibility before marking complete
				local isGroupEligible = true
				if _G.IsGroupEligibleForAchievement then
					isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
				end
				if not isGroupEligible then
					return false -- Group not eligible, don't complete
				end
				state.completed = true
				setProg("completed", true)
				return true
			end
			return false
		end
		
		-- Check if award on kill is enabled
		local awardOnKillEnabled = false
		if type(HardcoreAchievements_IsAwardOnKillEnabled) == "function" then
			awardOnKillEnabled = HardcoreAchievements_IsAwardOnKillEnabled()
		end
		
		-- If both a quest and an NPC are required, check toggle setting
		if REQUIRED_QUEST_ID and TARGET_NPC_ID then
			-- If award on kill is enabled, award on kill completion
			if awardOnKillEnabled then
				local killOk = state.killed or killFromProgress
				if killOk then
					-- Check group eligibility before marking complete
					local isGroupEligible = true
					if _G.IsGroupEligibleForAchievement then
						isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
					end
					if not isGroupEligible then
						return false -- Group not eligible, don't complete
					end
					state.completed = true
					setProg("completed", true)
					return true
				end
				return false
			else
				-- Quest alone is sufficient for completion (default behavior)
				if questOk then
					-- Check group eligibility before marking complete (only if kill was not clean)
					local isCleanKill = false
					if killFromProgress then
						local levelAtKill = progressTable and progressTable.levelAtKill
						if levelAtKill then
							if MAX_LEVEL and MAX_LEVEL > 0 then
								isCleanKill = (levelAtKill <= MAX_LEVEL)
							else
								isCleanKill = true
							end
						end
					end
					if not isCleanKill then
						local isGroupEligible = true
						if _G.IsGroupEligibleForAchievement then
							isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
						end
						if not isGroupEligible then
							return false -- Group not eligible, don't complete
						end
					end
					state.completed = true
					setProg("completed", true)
					return true
				end
				return false
			end
		end

		-- Otherwise, require each defined component individually
		local killOk = (not TARGET_NPC_ID) or state.killed or killFromProgress
		if killOk and questOk then
			-- Check group eligibility before marking complete
			local isGroupEligible = true
			if _G.IsGroupEligibleForAchievement then
				isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
			end
			if not isGroupEligible then
				return false -- Group not eligible, don't complete
			end
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
            -- Load kill counts if requiredKills is used
            if REQUIRED_KILLS then
                if p.counts then
                    -- Ensure counts are loaded with numeric keys
                    state.counts = {}
                    for k, v in pairs(p.counts) do
                        local numKey = tonumber(k) or k
                        state.counts[numKey] = tonumber(v) or v
                    end
                else
                    -- Initialize empty counts if not present
                    state.counts = {}
                end
            end
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
                                row.Sub:SetText(levelText .. "\n|cFFac81d6Pending solo|r")
                            elseif row.Sub then
                                row.Sub:SetText("|cFFac81d6Pending solo|r")
                            end
                        end
                        break
                    end
                end
            end
        end
        -- Check if we have ineligible kill status and restore indicator
        if p and p.ineligibleKill and not state.completed then
            if AchievementPanel and AchievementPanel.achievements then
                for _, row in ipairs(AchievementPanel.achievements) do
                    if row.id == ACH_ID and not row.completed then
                        -- Only show Pending ineligible if there's a kill recorded but not clean
                        -- For REQUIRED_KILLS, check if we have any counts; for TARGET_NPC_ID, check killed flag
                        local hasKill = false
                        if REQUIRED_KILLS then
                            hasKill = state.counts and next(state.counts) ~= nil
                        else
                            hasKill = state.killed or (p.killed)
                        end
                        if hasKill then
                            if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                local levelText = LEVEL .. " " .. row.maxLevel
                                row.Sub:SetText(levelText .. "\n|cffcf7171Pending Ineligible|r")
                            elseif row.Sub then
                                row.Sub:SetText("|cffcf7171Pending Ineligible|r")
                            end
                        end
                        break
                    end
                end
            end
        end
        checkComplete()
    end

    -- Handle kills: support both TARGET_NPC_ID (single kill) and REQUIRED_KILLS (kill counts)
    if TARGET_NPC_ID or REQUIRED_KILLS then
        _G[ACH_ID .. "_Kill"] = function(destGUID)
            if state.completed or not belowMax() then
                return false
            end
            
            local destId = getNpcIdFromGUID(destGUID)
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            local killValidated = false
            local idNum = nil -- For REQUIRED_KILLS
            
            -- Validate kill first: check if NPC matches
            if REQUIRED_KILLS then
                if not destId then
                    return false
                end
                -- Check if this NPC ID is in requiredKills (handle both string and number keys)
                idNum = tonumber(destId)
                local required = REQUIRED_KILLS[idNum] or REQUIRED_KILLS[destId]
                if not required then
                    return false
                end
                killValidated = true
            elseif TARGET_NPC_ID then
                if not isTargetNpcId(destId) then
                    return false
                end
                killValidated = true
            end
            
            if not killValidated then
                return false
            end
            
            -- Check group eligibility after validating the kill matches
            local isGroupEligible = true
            if _G.IsGroupEligibleForAchievement then
                isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
            end
            
            if not isGroupEligible then
                print("|cff00ff00[HardcoreAchievements]|r Achievement |cffffffff" .. (ACH_ID or "Unknown") .. "|r cannot be fulfilled: An overleveled party member is nearby.")
                
                -- Track the kill progress, but mark as ineligible
                if REQUIRED_KILLS then
                    state.counts[idNum] = (state.counts[idNum] or 0) + 1
                    setProg("counts", state.counts)
                else
                    state.killed = true
                    setProg("killed", true)
                end
                local killLevel = UnitLevel("player") or 1
                setProg("levelAtKill", killLevel)
                setProg("ineligibleKill", true)
                
                -- Show "Pending ineligible" indicator on achievement row
                if AchievementPanel and AchievementPanel.achievements then
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if row.id == ACH_ID and not row.completed then
                            if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                local levelText = LEVEL .. " " .. row.maxLevel
                                row.Sub:SetText(levelText .. "\n|cffcf7171Pending Ineligible|r")
                            elseif row.Sub then
                                row.Sub:SetText("|cffcf7171Pending Ineligible|r")
                            end
                            break
                        end
                    end
                end
                
                return false -- Group is not eligible, cannot fulfill achievement
            end
            
            -- Group is eligible: clear ineligible status if it was set
            if progressTable and progressTable.ineligibleKill then
                setProg("ineligibleKill", false)
                
                -- Immediately update UI to remove "Pending Ineligible" indicator
                -- Use the refresh function to update all indicators properly
                if _G.HCA_RefreshAllAchievementPoints then
                    _G.HCA_RefreshAllAchievementPoints()
                end
            end
            
            -- Track kill progress normally (eligible kill)
            if REQUIRED_KILLS then
                -- Increment kill count for this NPC (ensure numeric key for consistency)
                state.counts[idNum] = (state.counts[idNum] or 0) + 1
                -- Save progress after each kill
                setProg("counts", state.counts)
                
                -- Store player's level at time of THIS kill (overwrites previous value)
                -- This ensures levelAtKill reflects the level when ALL kills are completed
                local killLevel = UnitLevel("player") or 1
                setProg("levelAtKill", killLevel)
                
                -- Solo points only apply if player is self-found
                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                local isSoloKill = isSelfFound and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                
                -- Store points at time of kill if this is the first kill (for solo tracking)
                if not state.killed then
                    state.killed = true
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and row.points then
                                -- Get the original base points (before preview doubling or self-found bonus)
                                local currentPoints = tonumber(row.points) or 0
                                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                                local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                                
                                local basePoints = currentPoints
                                if isSelfFound and not row.isSecretAchievement then
                                    basePoints = basePoints - HCA_SELF_FOUND_BONUS
                                end
                                if row.originalPoints then
                                    basePoints = tonumber(row.originalPoints) or basePoints
                                    if not row.staticPoints then
                                        local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                        local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                        basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
                                    end
                                elseif isSoloMode and row.allowSoloDouble and not row.staticPoints then
                                    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                    if not (progress and progress.pointsAtKill) then
                                        basePoints = math.floor(basePoints / 2 + 0.5)
                                    end
                                end
                                
                                local pointsToStore = basePoints
                                if isSoloKill then
                                    pointsToStore = basePoints * 2
                                    setProg("soloKill", true)
                                end
                                setProg("pointsAtKill", pointsToStore)
                                break
                            end
                        end
                    end
                end
                
                -- Check if all kills are satisfied
                return checkComplete()
            else
                -- TARGET_NPC_ID: track kill normally (eligible kill)
                -- Solo points only apply if player is self-found
                -- Always require PlayerIsSolo check regardless of toggle state
                -- This validates the kill was actually solo
                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                local isSoloKill = isSelfFound and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                
                state.killed = true
                setProg("killed", true)
                
                -- Store player's level at time of kill (primary source for validation)
                local killLevel = UnitLevel("player") or 1
                setProg("levelAtKill", killLevel)
                
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
                                    row.Sub:SetText(levelText .. "\n|cFFac81d6Pending solo|r")
                                elseif row.Sub then
                                    row.Sub:SetText("|cFFac81d6Pending solo|r")
                                end
                            end
                            setProg("pointsAtKill", pointsToStore)
                            -- Also store solo status for later reference
                            setProg("soloKill", isSoloKill)
                            break
                        end
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
            
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            
            -- Don't allow quest completion if there's an ineligible kill flag - kill was done when group was ineligible
            if progressTable and progressTable.ineligibleKill then
                -- Check if group is now eligible - if so, clear the flag and allow completion
                local isGroupEligible = true
                if _G.IsGroupEligibleForAchievement then
                    isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
                end
                if not isGroupEligible then
                    return false -- Group still not eligible, don't complete
                end
                -- Group is now eligible, clear the ineligible flag
                setProg("ineligibleKill", false)
                if _G.HCA_RefreshAllAchievementPoints then
                    _G.HCA_RefreshAllAchievementPoints()
                end
            end
            
            -- Check if group is eligible (no overleveled party members in range)
            -- Exception: If NPC kill(s) were required and already fulfilled under level, it's "clean" and achievement can be granted regardless
            local isCleanKill = false
            if TARGET_NPC_ID or REQUIRED_KILLS then
                -- Check if kill(s) were already fulfilled
                local killFulfilled = false
                
                if REQUIRED_KILLS then
                    -- For required kills, check if all kills are satisfied
                    killFulfilled = countsSatisfied()
                else
                    -- For single kill, check if kill was fulfilled
                    killFulfilled = state.killed or (progressTable and progressTable.killed)
                end
                
                if killFulfilled then
                    -- Check if kill(s) were fulfilled under level
                    local levelAtKill = progressTable and progressTable.levelAtKill
                    if levelAtKill then
                        if MAX_LEVEL and MAX_LEVEL > 0 then
                            isCleanKill = (levelAtKill <= MAX_LEVEL)
                        else
                            isCleanKill = true -- No level cap means kill is always clean
                        end
                    else
                        -- No levelAtKill stored, check current level
                        local currentLevel = UnitLevel("player") or 1
                        if MAX_LEVEL and MAX_LEVEL > 0 then
                            isCleanKill = (currentLevel <= MAX_LEVEL)
                        else
                            isCleanKill = true
                        end
                    end
                end
            end
            
            -- Only check group eligibility if kill is not clean
            if not isCleanKill then
                local isGroupEligible = true
                if _G.IsGroupEligibleForAchievement then
                    isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL)
                end
                if not isGroupEligible then
                    -- Kill exists but is not clean due to overleveled party members - mark as Pending ineligible
                    setProg("ineligibleKill", true)
                    
                    -- Show "Pending ineligible" indicator on achievement row
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and not row.completed then
                                if row.Sub and row.maxLevel and row.maxLevel > 0 then
                                    local levelText = LEVEL .. " " .. row.maxLevel
                                    row.Sub:SetText(levelText .. "\n|cffcf7171Pending Ineligible|r")
                                elseif row.Sub then
                                    row.Sub:SetText("|cffcf7171Pending Ineligible|r")
                                end
                                break
                            end
                        end
                    end
                    
                    return false -- Group is not eligible, cannot fulfill achievement
                else
                    -- Group is now eligible, clear ineligible status if it was set
                    if progressTable and progressTable.ineligibleKill then
                        setProg("ineligibleKill", false)
                        
                        -- Immediately update UI to remove "Pending Ineligible" indicator
                        if _G.HCA_RefreshAllAchievementPoints then
                            _G.HCA_RefreshAllAchievementPoints()
                        end
                    end
                end
            else
                -- Kill is clean, clear ineligible status if it was set
                if progressTable and progressTable.ineligibleKill then
                    setProg("ineligibleKill", false)
                    
                    -- Immediately update UI to remove "Pending Ineligible" indicator
                    if _G.HCA_RefreshAllAchievementPoints then
                        _G.HCA_RefreshAllAchievementPoints()
                    end
                end
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
                                    row.Sub:SetText(levelText .. "\n|cFFac81d6Pending solo|r")
                                elseif row.Sub then
                                    row.Sub:SetText("|cFFac81d6Pending solo|r")
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
                                    row.Sub:SetText(levelText .. "\n|cFFac81d6Pending solo|r")
                                elseif row.Sub then
                                    row.Sub:SetText("|cFFac81d6Pending solo|r")
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
        return checkComplete()
    end
end

_G.Achievements_Common = M
return M