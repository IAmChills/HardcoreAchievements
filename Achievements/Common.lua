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

-- Helper function to check if an achievement is visible (not filtered out)
-- Made global so it can be used in other achievement files
-- This checks filter state directly from database, so it works even if panel hasn't been opened yet
function _G.HCA_IsAchievementVisible(achId)
    if not achId or not _G.AchievementPanel or not _G.AchievementPanel.achievements then
        return false
    end
    
    for _, row in ipairs(_G.AchievementPanel.achievements) do
        local rowId = row.id or row.achId
        if rowId and tostring(rowId) == tostring(achId) then
            -- Check filter flags first
            if row.hiddenByProfession then
                return false
            end
            if row.hiddenUntilComplete and not row.completed then
                return false
            end
            
            -- Check checkbox filter state for variations (same logic as ApplyFilter/ShouldShowByCheckboxFilter)
            -- This works even if the panel hasn't been opened and filter hasn't been applied yet
            if row._def and row._def.isVariation and row._def.variationType then
                -- Use FilterDropdown for checkbox states
                local FilterDropdown = _G.FilterDropdown
                local checkboxStates = FilterDropdown and FilterDropdown.GetCheckboxStates and FilterDropdown.GetCheckboxStates() or { true, true, true, true, true, true, false, false, false, false, false, false, false, false }
                
                local shouldShow = false
                if row._def.variationType == "Trio" then
                    shouldShow = checkboxStates[12]
                elseif row._def.variationType == "Duo" then
                    shouldShow = checkboxStates[11]
                elseif row._def.variationType == "Solo" then
                    shouldShow = checkboxStates[10]
                end
                
                -- Completed achievements always show (same as ShouldShowByCheckboxFilter logic)
                if not shouldShow and not row.completed then
                    return false
                end
            end
            
            -- If we got here, row passes filter checks - use IsShown() as final check
            return row:IsShown()
        end
    end
    
    return false
end

local isAchievementVisible = _G.HCA_IsAchievementVisible

function M.registerQuestAchievement(cfg)
    assert(type(cfg.achId) == "string", "achId required")
    local ACH_ID = cfg.achId
    local REQUIRED_QUEST_ID = cfg.requiredQuestId
    local TARGET_NPC_ID = cfg.targetNpcId
    local REQUIRED_KILLS = cfg.requiredKills -- Support kill counts: { [npcId] = count }
    local ALLOW_KILLS_BEFORE_QUEST = cfg.allowKillsBeforeQuest or false -- Allow tracking kills before quest acceptance
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
        counts = {}, -- Track kill counts when requiredKills is used (total kills, including ineligible)
        eligibleCounts = {} -- Track only eligible kill counts for requiredKills achievements
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
        -- Check stored levels: prioritize levelAtKill (when NPC was killed), then levelAtTurnIn, then levelAtAccept (backup)
        local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
        local levelToCheck = nil
        if progressTable then
            -- Priority: levelAtKill > levelAtTurnIn > levelAtAccept > current level
            levelToCheck = progressTable.levelAtKill or progressTable.levelAtTurnIn or progressTable.levelAtAccept
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

    local function isPlayerOnQuest()
        if not REQUIRED_QUEST_ID then
            return true -- No quest requirement means always "on quest"
        end
        -- Check if quest is in quest log (player is actively on the quest)
        if GetQuestLogIndexByID then
            local logIndex = GetQuestLogIndexByID(REQUIRED_QUEST_ID)
            if logIndex and logIndex > 0 then
                return true
            end
        end
        -- Fallback: check using classic API (for older versions)
        if GetNumQuestLogEntries then
            local numEntries = GetNumQuestLogEntries()
            for i = 1, numEntries do
                local title, level, suggestGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(i)
                if not isHeader and questID == REQUIRED_QUEST_ID then
                    return true
                end
            end
        end
        return false
    end

    local function topUpFromServer()
        if REQUIRED_QUEST_ID and not state.quest and serverQuestDone() then
            -- Check level before storing quest completion
            -- Priority: levelAtKill (from NPC kill) > levelAtTurnIn > levelAtAccept (backup) > current level
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            local levelToCheck = nil
            if progressTable then
                -- Prefer levelAtKill if available, otherwise use levelAtTurnIn, then levelAtAccept
                levelToCheck = progressTable.levelAtKill or progressTable.levelAtTurnIn or progressTable.levelAtAccept
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
                    -- Solo points apply: requires self-found if hardcore is active, otherwise solo is allowed
                    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
                    local allowSoloBonus = isSelfFound or not isHardcoreActive
                    local isSoloQuest = allowSoloBonus and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                    
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and row.points then
                                -- Get the original base points (before preview doubling or self-found bonus)
                                -- Check if row.points has been doubled by preview toggle
                                local currentPoints = tonumber(row.points) or 0
                                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                                local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                                
                                -- Detect if points have been doubled by preview toggle
                                -- Use originalPoints when available; do NOT subtract a flat self-found bonus from display points.
                                local basePoints = tonumber(row.originalPoints) or currentPoints
                                -- If solo mode toggle is on and row.allowSoloDouble, the points might be doubled
                                -- Use originalPoints if available, otherwise divide by 2 if doubled
                                if row.originalPoints then
                                    -- Use stored original points
                                    basePoints = tonumber(row.originalPoints) or basePoints
                                    -- Apply multiplier if not static (replaces base points)
                                    if not row.staticPoints then
                                        local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                        local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                        basePoints = math.floor((basePoints) * multiplier + 0.5)
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
                                    if isSelfFound then
                                        -- pointsAtKill is stored WITHOUT self-found bonus; display includes it.
                                        -- 0-point achievements naturally add 0.
                                        local getBonus = _G.HCA_GetSelfFoundBonus
                                        local baseForBonus = row.originalPoints or row.revealPointsBase or 0
                                        local bonus = (type(getBonus) == "function") and getBonus(tonumber(baseForBonus) or 0) or 0
                                        if bonus > 0 and displayPoints > 0 then
                                            displayPoints = displayPoints + bonus
                                        end
                                    end
                                    row.points = displayPoints
                                    if row.Points then
                                        row.Points:SetText(tostring(displayPoints))
                                    end
                                    -- Set "pending solo" indicator on the achievement row (not yet completed)
                                    if _G.HCA_SetStatusTextOnRow then
                                        _G.HCA_SetStatusTextOnRow(row, {
                                            completed = false,
                                            hasSoloStatus = true,
                                            requiresBoth = false,
                                            isSelfFound = isSelfFound,
                                            maxLevel = row.maxLevel
                                        })
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
                                            row.Points:SetText(tostring(row.points))
                                        end
                                    end
                                    if _G.HCA_SetStatusTextOnRow then
                                        _G.HCA_SetStatusTextOnRow(row, {
                                            completed = false,
                                            hasSoloStatus = true,
                                            requiresBoth = false,
                                            isSelfFound = isSelfFound,
                                            maxLevel = row.maxLevel
                                        })
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
    -- Use eligibleCounts to only count eligible kills toward fulfillment
    local function countsSatisfied()
        if not REQUIRED_KILLS then return true end
        
        -- Always reload eligibleCounts from progress table to ensure we have latest saved data
        local p = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
        state.eligibleCounts = {}
        if p and p.eligibleCounts then
            for k, v in pairs(p.eligibleCounts) do
                local numKey = tonumber(k) or k
                state.eligibleCounts[numKey] = tonumber(v) or v
            end
        end
        
        for npcId, need in pairs(REQUIRED_KILLS) do
            -- Ensure numeric key for lookup
            local idNum = tonumber(npcId) or npcId
            -- Check eligible counts (should always be loaded from progress table above)
            local current = state.eligibleCounts[idNum] or 0
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
		-- The ineligibleKill flag can be cleared by getting a new eligible kill of the same NPC,
		-- but if it's still set when checking completion, it should block completion
		if progressTable and progressTable.ineligibleKill then
			return false -- Kill was done when group was ineligible - do not allow completion
		end
		
		local killFromProgress = progressTable and progressTable.killed
		local questFromProgress = progressTable and progressTable.quest
		
		local questOk = (not REQUIRED_QUEST_ID) or state.quest or questFromProgress
		
		-- If requiredKills is defined, check kill counts instead of single kill
		if REQUIRED_KILLS then
			local killsOk = countsSatisfied()
			-- Complete if all kills are satisfied OR (if quest is required) quest is turned in
			if killsOk or (REQUIRED_QUEST_ID and questOk) then
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
                -- Load eligible counts separately
                if p.eligibleCounts then
                    state.eligibleCounts = {}
                    for k, v in pairs(p.eligibleCounts) do
                        local numKey = tonumber(k) or k
                        state.eligibleCounts[numKey] = tonumber(v) or v
                    end
                else
                    -- Initialize empty eligible counts if not present
                    state.eligibleCounts = {}
                end
            end
        end
        topUpFromServer()
        -- Check if we have solo status from previous kills/quests and update UI
        -- Solo indicators show: requires self-found if hardcore is active, otherwise solo is allowed
        local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
        local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
        local allowSoloBonus = isSelfFound or not isHardcoreActive
        if p and (p.soloKill or p.soloQuest) and allowSoloBonus then
            if AchievementPanel and AchievementPanel.achievements then
                for _, row in ipairs(AchievementPanel.achievements) do
                    if row.id == ACH_ID then
                        -- Restore "pending solo" indicator if it was a solo kill/quest and not completed
                        if (p.soloKill or p.soloQuest) and not state.completed and allowSoloBonus then
                            -- Use stored pointsAtKill value if available (doubled for solo kills)
                            if p.pointsAtKill then
                                row.points = tonumber(p.pointsAtKill) or row.points
                                if row.Points then
                                    row.Points:SetText(tostring(row.points))
                                end
                            end
                            -- Check if kills are satisfied but quest is pending
                            local killsSatisfied = false
                            if REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS) then
                                local hasKill = false
                                if REQUIRED_KILLS then
                                    hasKill = countsSatisfied()
                                else
                                    hasKill = state.killed or (p and p.killed)
                                end
                                local questNotTurnedIn = not state.quest and not (p and p.quest)
                                killsSatisfied = hasKill and questNotTurnedIn
                            end
                            
                            if _G.HCA_SetStatusTextOnRow then
                                _G.HCA_SetStatusTextOnRow(row, {
                                    completed = false,
                                    hasSoloStatus = true,
                                    requiresBoth = REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS),
                                    killsSatisfied = killsSatisfied,
                                    isSelfFound = isSelfFound,
                                    maxLevel = row.maxLevel
                                })
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
                            -- Use helper function to set status text
                            local requiresBoth = REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS)
                            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                            if _G.HCA_SetStatusTextOnRow then
                                _G.HCA_SetStatusTextOnRow(row, {
                                    completed = false,
                                    hasIneligibleKill = true,
                                    requiresBoth = requiresBoth,
                                    isSelfFound = isSelfFound,
                                    maxLevel = row.maxLevel
                                })
                            end
                        end
                        break
                    end
                end
            end
        end
        -- Check if we have kills satisfied but quest is pending (restore "Pending Turn-in" status)
        -- This handles the case where NPC is killed before quest is obtained
        if not state.completed and REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS) then
            local killsOk = false
            if REQUIRED_KILLS then
                killsOk = countsSatisfied()
            else
                killsOk = state.killed or (p and p.killed) or false
            end
            local questNotTurnedIn = not state.quest and not (p and p.quest)
            -- Only show "Pending Turn-in" if kills are satisfied, quest is not turned in, and no ineligible kill
            if killsOk and questNotTurnedIn and not (p and p.ineligibleKill) then
                if AchievementPanel and AchievementPanel.achievements then
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if row.id == ACH_ID and not row.completed then
                            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                            local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                            local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
                            if _G.HCA_SetStatusTextOnRow then
                                _G.HCA_SetStatusTextOnRow(row, {
                                    completed = false,
                                    hasSoloStatus = hasSoloStatus,
                                    requiresBoth = true,
                                    killsSatisfied = true,
                                    isSelfFound = isSelfFound,
                                    maxLevel = row.maxLevel
                                })
                            end
                            break
                        end
                    end
                end
            end
        end
        checkComplete()
    end

    -- Handle kills: support both TARGET_NPC_ID (single kill) and REQUIRED_KILLS (kill counts)
    if TARGET_NPC_ID or REQUIRED_KILLS then
        local killFunc = function(destGUID)
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
            
            -- Check if player is on the quest (required for kills to count, unless award on kill is enabled or allowKillsBeforeQuest is set)
            if REQUIRED_QUEST_ID then
                -- Check if award on kill is enabled
                local awardOnKillEnabled = false
                if type(HardcoreAchievements_IsAwardOnKillEnabled) == "function" then
                    awardOnKillEnabled = HardcoreAchievements_IsAwardOnKillEnabled()
                end
                
                -- Allow kill tracking if:
                -- 1. Player is on the quest (normal case), OR
                -- 2. Award on kill is enabled, OR
                -- 3. AllowKillsBeforeQuest is enabled (for quests where item drops from NPC), OR
                -- 4. Player has quest progress (has turned in quest) - allows re-killing for eligibility
                --    This fixes the case where player turns in quest with ineligible kill and needs to re-kill for eligibility
                local hasQuestProgress = state.quest or (progressTable and progressTable.quest)
                local canTrackKill = awardOnKillEnabled or isPlayerOnQuest() or ALLOW_KILLS_BEFORE_QUEST or hasQuestProgress
                
                if not canTrackKill then
                    return false -- Player is not on quest, award on kill is disabled, allowKillsBeforeQuest is disabled, and no quest progress - don't track kill
                end
            end
            
            -- Check group eligibility after validating the kill matches
            local isGroupEligible = true
            if _G.IsGroupEligibleForAchievement then
                isGroupEligible = _G.IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID, destGUID)
            end
            
            if not isGroupEligible then
                -- Check if achievement requirements are already satisfied - if so, don't process this kill
                local alreadySatisfied = false
                if REQUIRED_KILLS then
                    alreadySatisfied = countsSatisfied()
                elseif TARGET_NPC_ID then
                    alreadySatisfied = state.killed or (progressTable and progressTable.killed) or state.completed
                end
                
                -- If already satisfied (completed or fulfilled), don't process ineligible kill
                if alreadySatisfied or state.completed then
                    return false
                end
                
                -- Only print message if the achievement is visible (not filtered out)
                if isAchievementVisible(ACH_ID) then
                    print("|cff008066[Hardcore Achievements]|r |cffffd100Achievement " .. (ACH_ID or "Unknown") .. " cannot be fulfilled: An ineligible player contributed.|r")
                end
                
                -- Track the kill progress, but mark as ineligible (don't increment eligible counts)
                if REQUIRED_KILLS then
                    -- Always reload eligibleCounts from progress table to ensure we have latest saved data
                    local p = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                    state.eligibleCounts = {}
                    if p and p.eligibleCounts then
                        for k, v in pairs(p.eligibleCounts) do
                            local numKey = tonumber(k) or k
                            state.eligibleCounts[numKey] = tonumber(v) or v
                        end
                    end
                    
                    state.counts[idNum] = (state.counts[idNum] or 0) + 1
                    setProg("counts", state.counts)
                    -- Don't increment eligibleCounts for ineligible kills, but always save existing eligibleCounts to preserve it
                    setProg("eligibleCounts", state.eligibleCounts)
                else
                    state.killed = true
                    setProg("killed", true)
                end
                local killLevel = UnitLevel("player") or 1
                setProg("levelAtKill", killLevel)
                setProg("ineligibleKill", true)
                
                -- Show "Pending ineligible" or "Ineligible Kill" indicator on achievement row
                if AchievementPanel and AchievementPanel.achievements then
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if row.id == ACH_ID and not row.completed then
                            -- Use helper function to set status text
                            local requiresBoth = REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS)
                            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                            if _G.HCA_SetStatusTextOnRow then
                                _G.HCA_SetStatusTextOnRow(row, {
                                    completed = false,
                                    hasIneligibleKill = true,
                                    requiresBoth = requiresBoth,
                                    isSelfFound = isSelfFound,
                                    maxLevel = row.maxLevel
                                })
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
                if RefreshAllAchievementPoints then
                    RefreshAllAchievementPoints()
                end
            end
            
            -- Track kill progress normally (eligible kill)
            if REQUIRED_KILLS then
                -- Always reload eligibleCounts from progress table to ensure we have latest saved data
                local p = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                state.eligibleCounts = {}
                if p and p.eligibleCounts then
                    for k, v in pairs(p.eligibleCounts) do
                        local numKey = tonumber(k) or k
                        state.eligibleCounts[numKey] = tonumber(v) or v
                    end
                end
                
                -- Check if all kills are already satisfied BEFORE this kill (to determine if we should update levelAtKill)
                local allKillsAlreadySatisfied = countsSatisfied()
                
                -- Increment both total counts and eligible counts for this NPC (ensure numeric key for consistency)
                state.counts[idNum] = (state.counts[idNum] or 0) + 1
                state.eligibleCounts[idNum] = (state.eligibleCounts[idNum] or 0) + 1
                -- Save progress after each kill
                setProg("counts", state.counts)
                setProg("eligibleCounts", state.eligibleCounts)
                
                -- Store player's level at time of THIS kill
                -- Always update levelAtKill while kills are not all satisfied (tracks current level, even if player levels up)
                -- Once all kills are satisfied, levelAtKill becomes static and won't be updated anymore
                -- This ensures if player levels up after fulfilling the achievement, they can still complete it
                if not allKillsAlreadySatisfied then
                    -- All kills weren't satisfied before this kill, so update levelAtKill to current level
                    -- This includes the case where this kill satisfies all requirements (final update before becoming static)
                    local killLevel = UnitLevel("player") or 1
                    setProg("levelAtKill", killLevel)
                    -- After this point, if all kills are now satisfied, levelAtKill becomes static
                end
                -- If allKillsAlreadySatisfied was true, levelAtKill is already static and won't be updated
                
                -- Solo points only apply if player is self-found
                -- Use stored solo status from combat tracking (more accurate than checking at kill time)
                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                local storedSoloStatus = nil
                if destGUID and _G.PlayerIsSoloForGUID then
                    storedSoloStatus = _G.PlayerIsSoloForGUID(destGUID)
                end
                -- Fallback to current check if no stored status available
                local isSoloKill = isSelfFound and (
                    (storedSoloStatus ~= nil and storedSoloStatus) or
                    (storedSoloStatus == nil and _G.PlayerIsSolo and _G.PlayerIsSolo() or false)
                ) or false
                
                -- Mark as killed (allows re-killing to update solo status and points)
                if not state.killed then
                    state.killed = true
                end
                
                -- Always update points and solo status on kill (allows re-killing to upgrade from non-solo to solo)
                if AchievementPanel and AchievementPanel.achievements then
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if row.id == ACH_ID and row.points then
                            -- Get the original base points (before preview doubling or self-found bonus)
                            local currentPoints = tonumber(row.points) or 0
                            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                            local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                            
                            -- Always recalculate base points from originalPoints if available, or from current points
                            -- Use originalPoints when available; do NOT subtract a flat self-found bonus from display points.
                            local basePoints = tonumber(row.originalPoints) or currentPoints
                            if row.originalPoints then
                                -- Use stored original points and apply current preset multiplier
                                basePoints = tonumber(row.originalPoints) or basePoints
                                if not row.staticPoints then
                                    local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                    local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                    basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
                                end
                            elseif isSoloMode and row.allowSoloDouble and not row.staticPoints then
                                -- Points might have been doubled by preview, divide by 2 to get base
                                -- Check if we have a stored pointsAtKill that was already doubled (solo kill)
                                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                local storedPointsAtKill = progress and progress.pointsAtKill
                                if storedPointsAtKill then
                                    -- If stored points are doubled (solo), divide by 2 to get base
                                    -- Otherwise use current points (might already be base)
                                    local storedSolo = progress and progress.soloKill
                                    if storedSolo then
                                        basePoints = math.floor(tonumber(storedPointsAtKill) / 2 + 0.5)
                                    else
                                        basePoints = math.floor(basePoints / 2 + 0.5)
                                    end
                                else
                                    basePoints = math.floor(basePoints / 2 + 0.5)
                                end
                            end
                            
                            -- Check existing progress to preserve solo status and only upgrade points
                            local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                            local existingSoloKill = progress and progress.soloKill or false
                            local existingPointsAtKill = progress and progress.pointsAtKill
                            
                            local pointsToStore = basePoints
                            if isSoloKill then
                                pointsToStore = basePoints * 2
                            end
                            
                            -- Never overwrite soloKill = true with false
                            local shouldUpdateSoloKill = true
                            local shouldUpdatePoints = true
                            
                            if existingSoloKill and not isSoloKill then
                                -- Existing is solo, new is non-solo - preserve solo status and never update points
                                shouldUpdateSoloKill = false
                                shouldUpdatePoints = false
                            elseif existingPointsAtKill then
                                -- Calculate base points for comparison (always compare base to base)
                                local existingBasePoints = existingSoloKill and math.floor(tonumber(existingPointsAtKill) / 2 + 0.5) or tonumber(existingPointsAtKill)
                                local newBasePoints = basePoints
                                
                                -- Check if we're upgrading from non-solo to solo
                                local isUpgradingToSolo = not existingSoloKill and isSoloKill
                                
                                -- Only update if new base points are higher, OR if upgrading to solo (even with same base points)
                                -- Solo status rules:
                                -- - false -> false: OK if points higher
                                -- - false -> true: Always update (solo upgrade, even if base points same)
                                -- - true -> true: OK if points higher
                                -- - true -> false: Never (handled above)
                                if not isUpgradingToSolo and newBasePoints <= existingBasePoints then
                                    shouldUpdatePoints = false
                                end
                            end
                            
                            if shouldUpdatePoints then
                                setProg("pointsAtKill", pointsToStore)
                            end
                            
                            if shouldUpdateSoloKill then
                                setProg("soloKill", isSoloKill)
                            end
                            break
                        end
                    end
                end
                
                -- Check if all kills are satisfied
                return checkComplete()
            else
                -- TARGET_NPC_ID: track kill normally (eligible kill)
                -- Solo points apply: requires self-found if hardcore is active, otherwise solo is allowed
                -- Use stored solo status from combat tracking (more accurate than checking at kill time)
                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
                local allowSoloBonus = isSelfFound or not isHardcoreActive
                local storedSoloStatus = nil
                if destGUID and _G.PlayerIsSoloForGUID then
                    storedSoloStatus = _G.PlayerIsSoloForGUID(destGUID)
                end
                -- Fallback to current check if no stored status available
                local isSoloKill = allowSoloBonus and (
                    (storedSoloStatus ~= nil and storedSoloStatus) or
                    (storedSoloStatus == nil and _G.PlayerIsSolo and _G.PlayerIsSolo() or false)
                ) or false
                
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
                            
                            -- Always recalculate base points from originalPoints if available, or from current points
                            -- Use originalPoints when available; do NOT subtract a flat self-found bonus from display points.
                            local basePoints = tonumber(row.originalPoints) or currentPoints
                            if row.originalPoints then
                                -- Use stored original points and apply current preset multiplier
                                basePoints = tonumber(row.originalPoints) or basePoints
                                if not row.staticPoints then
                                    local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                                    local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                                    basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
                                end
                            elseif isSoloMode and row.allowSoloDouble and not row.staticPoints then
                                -- Points might have been doubled by preview, divide by 2 to get base
                                -- Check if we have a stored pointsAtKill that was already doubled (solo kill)
                                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                local storedPointsAtKill = progress and progress.pointsAtKill
                                if storedPointsAtKill then
                                    -- If stored points are doubled (solo), divide by 2 to get base
                                    -- Otherwise use current points (might already be base)
                                    local storedSolo = progress and progress.soloKill
                                    if storedSolo then
                                        basePoints = math.floor(tonumber(storedPointsAtKill) / 2 + 0.5)
                                    else
                                        basePoints = math.floor(basePoints / 2 + 0.5)
                                    end
                                else
                                    basePoints = math.floor(basePoints / 2 + 0.5)
                                end
                            end
                            
                            -- Check existing progress to preserve solo status and only upgrade points
                            local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                            local existingSoloKill = progress and progress.soloKill or false
                            local existingPointsAtKill = progress and progress.pointsAtKill
                            
                            local pointsToStore = basePoints
                            -- If solo kill, store doubled points; otherwise store regular points
                            if isSoloKill then
                                pointsToStore = basePoints * 2
                            end
                            
                            -- Never overwrite soloKill = true with false
                            local shouldUpdateSoloKill = true
                            local shouldUpdatePoints = true
                            
                            if existingSoloKill and not isSoloKill then
                                -- Existing is solo, new is non-solo - preserve solo status and never update points
                                shouldUpdateSoloKill = false
                                shouldUpdatePoints = false
                            elseif existingPointsAtKill then
                                -- Calculate base points for comparison (always compare base to base)
                                local existingBasePoints = existingSoloKill and math.floor(tonumber(existingPointsAtKill) / 2 + 0.5) or tonumber(existingPointsAtKill)
                                local newBasePoints = basePoints
                                
                                -- Check if we're upgrading from non-solo to solo
                                local isUpgradingToSolo = not existingSoloKill and isSoloKill
                                
                                -- Only update if new base points are higher, OR if upgrading to solo (even with same base points)
                                -- Solo status rules:
                                -- - false -> false: OK if points higher
                                -- - false -> true: Always update (solo upgrade, even if base points same)
                                -- - true -> true: OK if points higher
                                -- - true -> false: Never (handled above)
                                if not isUpgradingToSolo and newBasePoints <= existingBasePoints then
                                    shouldUpdatePoints = false
                                end
                            end
                            
                            -- Use the preserved solo status for display and UI updates
                            local effectiveSoloKill = shouldUpdateSoloKill and isSoloKill or existingSoloKill
                            local effectivePoints = shouldUpdatePoints and pointsToStore or (existingPointsAtKill and tonumber(existingPointsAtKill) or pointsToStore)
                            
                            if shouldUpdatePoints then
                                setProg("pointsAtKill", pointsToStore)
                            end
                            
                            if shouldUpdateSoloKill then
                                setProg("soloKill", isSoloKill)
                            end
                            
                            -- Update UI display with effective values
                            if effectiveSoloKill then
                                -- Update points display to show doubled value (including self-found bonus for display)
                                local displayPoints = effectivePoints
                                if isSelfFound then
                                    -- pointsAtKill is stored WITHOUT self-found bonus; display includes it.
                                    -- 0-point achievements naturally add 0.
                                    local getBonus = _G.HCA_GetSelfFoundBonus
                                    local baseForBonus = row.originalPoints or row.revealPointsBase or 0
                                    local bonus = (type(getBonus) == "function") and getBonus(tonumber(baseForBonus) or 0) or 0
                                    if bonus > 0 and displayPoints > 0 then
                                        displayPoints = displayPoints + bonus
                                    end
                                end
                                row.points = displayPoints
                                if row.Points then
                                    row.Points:SetText(tostring(displayPoints))
                                end
                                -- Check if kills are satisfied but quest is pending
                                local killsSatisfied = false
                                if REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS) then
                                    local hasKill = false
                                    if REQUIRED_KILLS then
                                        hasKill = countsSatisfied()
                                    else
                                        hasKill = state.killed or false
                                    end
                                    local questNotTurnedIn = not state.quest
                                    killsSatisfied = hasKill and questNotTurnedIn
                                end
                                
                                -- Set "pending solo" indicator on the achievement row (not yet completed)
                                if _G.HCA_SetStatusTextOnRow then
                                    _G.HCA_SetStatusTextOnRow(row, {
                                        completed = false,
                                        hasSoloStatus = true,
                                        requiresBoth = REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS),
                                        killsSatisfied = killsSatisfied,
                                        isSelfFound = isSelfFound,
                                        maxLevel = row.maxLevel
                                    })
                                end
                            end
                            break
                        end
                    end
                end
            end
            
            -- After kills are completed, check if quest is pending and update status
            if not state.completed and REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS) then
                local killsOk = false
                if REQUIRED_KILLS then
                    killsOk = countsSatisfied()
                else
                    killsOk = state.killed or false
                end
                local questNotTurnedIn = not state.quest
                if killsOk and questNotTurnedIn then
                    -- Update UI to show "Pending Turn-in"
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and not row.completed then
                                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
                                if _G.HCA_SetStatusTextOnRow then
                                    _G.HCA_SetStatusTextOnRow(row, {
                                        completed = false,
                                        hasSoloStatus = hasSoloStatus,
                                        requiresBoth = true,
                                        killsSatisfied = true,
                                        isSelfFound = isSelfFound,
                                        maxLevel = row.maxLevel
                                    })
                                end
                                break
                            end
                        end
                    end
                end
            end
            
            return checkComplete()
        end
        
        -- Register Kill function immediately while killFunc is in scope
        if _G.HardcoreAchievements_RegisterAchievementFunction and killFunc then
            _G.HardcoreAchievements_RegisterAchievementFunction(ACH_ID, "Kill", killFunc)
        end
    end

    if REQUIRED_QUEST_ID then
        local questFunc = function(questID)
            if state.completed then
                return false
            end
            -- Check questID match first (language-independent, fast check)
            -- Ensure both are numbers for reliable comparison
            local questIDNum = tonumber(questID)
            local requiredQuestIDNum = tonumber(REQUIRED_QUEST_ID)
            if not questIDNum or not requiredQuestIDNum or questIDNum ~= requiredQuestIDNum then
                return false
            end
            -- Now check level requirements after confirming quest match
            if not belowMax() then
                return false
            end
            
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            
            -- Don't allow quest completion if there's an ineligible kill flag - kill was done when group was ineligible
            -- The ineligibleKill flag can be cleared by getting a new eligible kill of the same NPC,
            -- but if it's still set when quest is turned in, completion should be blocked
            if progressTable and progressTable.ineligibleKill then
                -- Kill was done when group was ineligible - do not allow completion
                return false
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
                    
                    -- Show "Pending Turn-in (ineligible kill)" indicator on achievement row (quest handler always means both kill and quest required)
                    if AchievementPanel and AchievementPanel.achievements then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if row.id == ACH_ID and not row.completed then
                                -- Use helper function to set status text (quest handler always means both kill and quest required)
                                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                                if _G.HCA_SetStatusTextOnRow then
                                    _G.HCA_SetStatusTextOnRow(row, {
                                        completed = false,
                                        hasIneligibleKill = true,
                                        requiresBoth = true, -- Quest handler always means both required
                                        isSelfFound = isSelfFound,
                                        maxLevel = row.maxLevel
                                    })
                                end
                                break
                            end
                        end
                    end
                    
                    return false -- Group is not eligible, cannot fulfill achievement
                end
                -- Note: We don't clear ineligibleKill here in the quest handler
                -- The flag can only be cleared by getting a new eligible kill of the same NPC (via the kill handler)
            end
            
            state.quest = true
            setProg("quest", true)
            
            -- Check if we already have pointsAtKill from a previous NPC kill
            -- If we do, preserve it; if not, store points based on quest turn-in solo status
            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
            local existingPointsAtKill = progressTable and progressTable.pointsAtKill
            
            if not existingPointsAtKill then
                -- No existing pointsAtKill, check if quest completion was solo
                -- Solo points apply: requires self-found if hardcore is active, otherwise solo is allowed
                local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
                local allowSoloBonus = isSelfFound or not isHardcoreActive
                local isSoloQuest = allowSoloBonus and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
                
                if AchievementPanel and AchievementPanel.achievements then
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if row.id == ACH_ID and row.points then
                            -- Get the original base points (before preview doubling or self-found bonus)
                            -- Check if row.points has been doubled by preview toggle
                            local currentPoints = tonumber(row.points) or 0
                            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                            local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                            
                                -- Detect if points have been doubled by preview toggle
                                -- Use originalPoints when available; do NOT subtract a flat self-found bonus from display points.
                                local basePoints = tonumber(row.originalPoints) or currentPoints
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
                                if isSelfFound then
                                    -- pointsAtKill is stored WITHOUT self-found bonus; display includes it.
                                    -- 0-point achievements naturally add 0.
                                    local getBonus = _G.HCA_GetSelfFoundBonus
                                    local baseForBonus = row.originalPoints or row.revealPointsBase or 0
                                    local bonus = (type(getBonus) == "function") and getBonus(tonumber(baseForBonus) or 0) or 0
                                    if bonus > 0 and displayPoints > 0 then
                                        displayPoints = displayPoints + bonus
                                    end
                                end
                                row.points = displayPoints
                                if row.Points then
                                    row.Points:SetText(tostring(displayPoints))
                                end
                                -- Check if kills are satisfied but quest is pending
                                local killsSatisfied = false
                                if REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS) then
                                    local hasKill = false
                                    if REQUIRED_KILLS then
                                        hasKill = countsSatisfied()
                                    else
                                        hasKill = state.killed or false
                                    end
                                    local questNotTurnedIn = not state.quest
                                    killsSatisfied = hasKill and questNotTurnedIn
                                end
                                
                                -- Set "pending solo" indicator on the achievement row (not yet completed)
                                if _G.HCA_SetStatusTextOnRow then
                                    _G.HCA_SetStatusTextOnRow(row, {
                                        completed = false,
                                        hasSoloStatus = true,
                                        requiresBoth = REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS),
                                        killsSatisfied = killsSatisfied,
                                        isSelfFound = isSelfFound,
                                        maxLevel = row.maxLevel
                                    })
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
                    -- Solo points apply: requires self-found if hardcore is active, otherwise solo is allowed
                    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
                    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
                    local allowSoloBonus = isSelfFound or not isHardcoreActive
                    local isSoloQuest = allowSoloBonus and (_G.PlayerIsSolo and _G.PlayerIsSolo() or false) or false
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
                                    if isSelfFound then
                                        -- pointsAtKill is stored WITHOUT self-found bonus; display includes it.
                                        -- 0-point achievements naturally add 0.
                                        local getBonus = _G.HCA_GetSelfFoundBonus
                                        local baseForBonus = row.originalPoints or row.revealPointsBase or 0
                                        local bonus = (type(getBonus) == "function") and getBonus(tonumber(baseForBonus) or 0) or 0
                                        if bonus > 0 and storedPoints > 0 then
                                            storedPoints = storedPoints + bonus
                                        end
                                    end
                                    row.points = storedPoints
                                    if row.Points then
                                        row.Points:SetText(tostring(storedPoints))
                                    end
                                end
                                -- Check if kills are satisfied but quest is pending
                                local killsSatisfied = false
                                if REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS) then
                                    local hasKill = false
                                    local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
                                    if REQUIRED_KILLS then
                                        -- Need to check eligibleCounts from progress table
                                        if progressTable and progressTable.eligibleCounts then
                                            local allSatisfied = true
                                            for npcId, requiredCount in pairs(REQUIRED_KILLS) do
                                                local idNum = tonumber(npcId) or npcId
                                                local current = progressTable.eligibleCounts[idNum] or progressTable.eligibleCounts[tostring(idNum)] or 0
                                                local required = tonumber(requiredCount) or 1
                                                if current < required then
                                                    allSatisfied = false
                                                    break
                                                end
                                            end
                                            hasKill = allSatisfied
                                        end
                                    else
                                        hasKill = (progressTable and progressTable.killed) or false
                                    end
                                    local questNotTurnedIn = not (progressTable and progressTable.quest)
                                    killsSatisfied = hasKill and questNotTurnedIn
                                end
                                
                                if _G.HCA_SetStatusTextOnRow then
                                    _G.HCA_SetStatusTextOnRow(row, {
                                        completed = false,
                                        hasSoloStatus = true,
                                        requiresBoth = REQUIRED_QUEST_ID and (TARGET_NPC_ID or REQUIRED_KILLS),
                                        killsSatisfied = killsSatisfied,
                                        isSelfFound = isSelfFound,
                                        maxLevel = row.maxLevel
                                    })
                                end
                                break
                            end
                        end
                    end
                end
            end
            return checkComplete()
        end

        -- Register quest function in local registry
        if _G.HardcoreAchievements_RegisterAchievementFunction then
            _G.HardcoreAchievements_RegisterAchievementFunction(ACH_ID, "Quest", questFunc)
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

    -- Register IsCompleted function in local registry
    if _G.HardcoreAchievements_RegisterAchievementFunction then
        _G.HardcoreAchievements_RegisterAchievementFunction(ACH_ID, "IsCompleted", function()
            if state.completed then
                return true
            end
            if topUpFromServer() then
                return checkComplete()
            end
            return checkComplete()
        end)
    end
end

_G.Achievements_Common = M
return M