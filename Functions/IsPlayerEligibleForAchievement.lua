-- IsPlayerEligibleForAchievement.lua
-- Checks if the player is eligible for an achievement based on threat contribution
-- Maintains a cache of threat data per destGUID and evaluates eligibility during combat
-- Works for players NOT in the player's group by using UnitTokenFromGUID
-- Returns true if eligible (player/group contributed 90%+ threat), false if ineligible, nil if not applicable
-- Parameters:
--   destGUID (string): The GUID of the NPC being fought
--   sourceGUID (string): The GUID of the source of the combat event
--   subevent (string): The combat log subevent

-- Configuration
local PLAYER_THREAT_THRESHOLD = 90  -- % threat player/group must have to be eligible
local OTHER_PLAYER_THREAT_THRESHOLD = 10  -- % threat from non-group players to disqualify

-- Threat cache: threatCache[destGUID] = { 
--   playerThreat = %, 
--   groupThreat = %, 
--   otherPlayersThreat = %, 
--   otherPlayerGUIDs = { [playerGUID] = true },  -- Track players we've seen attacking this NPC
--   lastUpdated = time 
-- }
local threatCache = {}
local CACHE_TIMEOUT = 30  -- seconds to keep cache entries after combat ends

-- Helper function to get NPC ID from GUID
local function getNpcIdFromGUID(guid)
    if not guid then
        return nil
    end
    local npcId = select(6, strsplit("-", guid))
    return npcId and tonumber(npcId) or nil
end

-- Helper function to check if an NPC is required for any achievement
-- NOTE: We do NOT call killTracker here as it can have side effects and grant achievements
-- Instead, we just check if any achievement has a killTracker function (indicating it tracks NPCs)
local function isNpcRequiredForAchievement(destGUID)
    if not destGUID then
        return false
    end
    
    local npcId = getNpcIdFromGUID(destGUID)
    print("[IsPlayerEligible] Checking if NPC required - destGUID:", destGUID, "npcId:", npcId)
    
    -- Check if any achievement tracks NPCs (has a killTracker function)
    -- We don't call killTracker to avoid side effects - we'll let the actual killTracker
    -- handle matching when the kill happens
    if AchievementPanel and AchievementPanel.achievements then
        local achievementCount = 0
        for _, row in ipairs(AchievementPanel.achievements) do
            if not row.completed and type(row.killTracker) == "function" then
                achievementCount = achievementCount + 1
                -- Just check if it has a killTracker - don't call it!
                -- The killTracker will be called by processKill when the NPC actually dies
                print("[IsPlayerEligible] Found achievement with killTracker:", row.id or row.achId)
                -- If any achievement has a killTracker, assume this NPC might be tracked
                -- We'll track threat for it, but eligibility will be checked at kill time
                return true
            end
        end
        print("[IsPlayerEligible] Checked", achievementCount, "achievements with killTrackers")
    else
        print("[IsPlayerEligible] No AchievementPanel or achievements found")
    end
    
    print("[IsPlayerEligible] NPC not required for any achievement")
    return false
end

-- Helper function to check if a GUID belongs to the player or a party member
local function isPlayerOrPartyMember(guid)
    if not guid then
        return false
    end
    
    local playerGUID = UnitGUID("player")
    if guid == playerGUID then
        return true
    end
    
    -- Check party members
    if GetNumGroupMembers() > 1 then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local partyMemberGUID = UnitGUID(unit)
                if partyMemberGUID and guid == partyMemberGUID then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Helper function to get all party/raid member unit tokens
local function getGroupMemberUnits()
    local units = {}
    
    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                table.insert(units, u)
            end
        end
    elseif IsInGroup() then
        local n = GetNumSubgroupMembers()
        for i = 1, n do
            local u = "party" .. i
            if UnitExists(u) then
                table.insert(units, u)
            end
        end
    end
    
    return units
end

-- Helper function to calculate total group threat
local function calculateGroupThreat(mobUnit)
    local playerThreat = 0
    local groupThreat = 0
    
    -- Check if we're in combat and unit is valid
    if not UnitAffectingCombat("player") and not UnitAffectingCombat(mobUnit) then
        print("[IsPlayerEligible] Not in combat, threat data may not be available")
        return 0, 0
    end
    
    if not UnitExists(mobUnit) or not UnitCanAttack("player", mobUnit) then
        print("[IsPlayerEligible] Invalid mob unit for threat check")
        return 0, 0
    end
    
    -- Get player threat
    local isPlayerTanking, playerStatus, playerScaledPct, playerRawPct = UnitDetailedThreatSituation("player", mobUnit)
    print("[IsPlayerEligible] Player threat check - tanking:", isPlayerTanking, "status:", playerStatus, "scaled:", playerScaledPct, "raw:", playerRawPct)
    
    -- Check if we got any threat data at all
    if not isPlayerTanking and not playerStatus and not playerScaledPct and not playerRawPct then
        print("[IsPlayerEligible] No threat data available yet (may need to wait for threat to build)")
        return 0, 0
    end
    
    if playerScaledPct then
        playerThreat = playerScaledPct
    elseif playerRawPct then
        playerThreat = playerRawPct
    elseif isPlayerTanking and playerStatus and playerStatus >= 2 then
        -- Player is tanking, assume high threat
        playerThreat = 100
    end
    
    -- Get group member threat (highest threat among group members)
    local groupUnits = getGroupMemberUnits()
    print("[IsPlayerEligible] Checking", #groupUnits, "group members")
    for _, unit in ipairs(groupUnits) do
        if UnitExists(unit) then
            local isUnitTanking, unitStatus, scaledPct, rawPct = UnitDetailedThreatSituation(unit, mobUnit)
            local unitThreat = 0
            if scaledPct then
                unitThreat = scaledPct
            elseif rawPct then
                unitThreat = rawPct
            elseif isUnitTanking and unitStatus and unitStatus >= 2 then
                unitThreat = 100
            end
            print("[IsPlayerEligible] Group member", unit, "threat:", unitThreat)
            groupThreat = math.max(groupThreat, unitThreat)
        end
    end
    
    -- Calculate combined group threat (max of player and highest group member)
    -- In a group, we consider the group eligible if the highest threat holder in the group has >= 90%
    local combinedGroupThreat = math.max(playerThreat, groupThreat)
    print("[IsPlayerEligible] Combined group threat:", combinedGroupThreat, "(player:", playerThreat, "group:", groupThreat, ")")
    
    return playerThreat, combinedGroupThreat
end

-- Helper function to check threat for a specific player GUID (not in group)
-- Note: UnitTokenFromGUID doesn't work reliably for players outside your group in Classic
-- So we use a conservative approach: if we've seen them dealing damage, assume they might be helping
local function checkOtherPlayerThreat(mobUnit, playerGUID)
    if not mobUnit or not playerGUID then
        print("[IsPlayerEligible] checkOtherPlayerThreat - invalid params")
        return 0
    end
    
    -- Try to get unit token from GUID (this often fails for non-grouped players)
    local unitToken = UnitTokenFromGUID(playerGUID)
    print("[IsPlayerEligible] checkOtherPlayerThreat - playerGUID:", playerGUID, "unitToken:", unitToken)
    
    -- If we can get the unit token and it exists, try to check threat directly
    if unitToken and UnitExists(unitToken) then
        local isTanking, status, scaledPct, rawPct = UnitDetailedThreatSituation(unitToken, mobUnit)
        print("[IsPlayerEligible] checkOtherPlayerThreat - tanking:", isTanking, "status:", status, "scaled:", scaledPct, "raw:", rawPct)
        
        if scaledPct then
            return scaledPct
        elseif rawPct then
            return rawPct
        elseif isTanking and status and status >= 2 then
            return 100
        end
        -- If we got the unit but threat is nil/0, return 0 (they're not on threat table)
        return 0
    end
    
    -- UnitTokenFromGUID failed - this is common for non-grouped players
    -- We can't check their threat directly, so we use a conservative heuristic:
    -- If we've seen them dealing damage, we assume they might be helping
    -- However, if the player has >= 90% threat, we can be more lenient
    print("[IsPlayerEligible] checkOtherPlayerThreat - Cannot get unit token for non-grouped player")
    print("[IsPlayerEligible] checkOtherPlayerThreat - Using conservative estimate: assuming they might have threat")
    
    -- Return a conservative estimate: if we can't check, assume they might have some threat
    -- This will be handled in the eligibility logic - if player has >= 90% threat, we'll still allow it
    -- But if player has < 90%, we'll be conservative and assume other players are helping
    return nil  -- Return nil to indicate we can't determine threat
end

-- Main function to update threat cache and check eligibility
function IsPlayerEligibleForAchievement(destGUID, sourceGUID, subevent)
    print("[IsPlayerEligible] Called with destGUID:", destGUID, "sourceGUID:", sourceGUID, "subevent:", subevent)
    
    if not destGUID then
        print("[IsPlayerEligible] No destGUID, returning nil")
        return nil
    end
    
    -- Only process damage events (similar to how combat log is handled)
    local damageEvents = {
        SWING_DAMAGE = true,
        RANGE_DAMAGE = true,
        SPELL_DAMAGE = true,
        SPELL_PERIODIC_DAMAGE = true,
        SPELL_BUILDING_DAMAGE = true,
        DAMAGE_SPLIT = true,
        DAMAGE_SHIELD = true,
    }
    
    if not damageEvents[subevent] then
        print("[IsPlayerEligible] Not a damage event, returning nil")
        return nil
    end
    
    -- Check if player is involved in this combat event
    local playerInvolved = isPlayerOrPartyMember(sourceGUID)
    print("[IsPlayerEligible] Player involved:", playerInvolved)
    
    if not playerInvolved then
        -- Player not involved, but check if this is damage to an NPC we're tracking
        -- We still want to track threat even if we didn't deal the damage
        -- (e.g., another player hits our target)
        local npcRequired = isNpcRequiredForAchievement(destGUID)
        print("[IsPlayerEligible] Player not involved, NPC required:", npcRequired)
        if not npcRequired then
            print("[IsPlayerEligible] NPC not required, returning nil")
            return nil
        end
    end
    
    -- Check if this NPC is required for any achievement
    local npcRequired = isNpcRequiredForAchievement(destGUID)
    print("[IsPlayerEligible] NPC required for achievement:", npcRequired)
    if not npcRequired then
        print("[IsPlayerEligible] NPC not required, returning nil")
        return nil
    end
    
    -- Try to get the unit for this NPC
    local mobUnit = nil
    local targetGUID = UnitGUID("target")
    print("[IsPlayerEligible] Checking target - exists:", UnitExists("target"), "targetGUID:", targetGUID, "destGUID:", destGUID)
    
    if UnitExists("target") and targetGUID == destGUID then
        mobUnit = "target"
        print("[IsPlayerEligible] Mob is current target")
    else
        print("[IsPlayerEligible] Mob is NOT current target, caching for later")
        -- Can't check threat without the unit being our target
        -- Store that we're tracking this NPC but can't evaluate yet
        -- Still track other players we see attacking it
        local now = GetTime()
        local cached = threatCache[destGUID]
        if not cached then
            cached = {
                playerThreat = 0,
                groupThreat = 0,
                otherPlayersThreat = 0,
                otherPlayerGUIDs = {},
                lastUpdated = now,
                needsUpdate = true
            }
            threatCache[destGUID] = cached
            print("[IsPlayerEligible] Created new cache entry")
        end
        
        -- Track other players we see attacking this NPC even if we can't check threat yet
        if sourceGUID and not isPlayerOrPartyMember(sourceGUID) then
            local guidType = sourceGUID and select(1, strsplit("-", sourceGUID))
            if guidType == "Player" then
                cached.otherPlayerGUIDs[sourceGUID] = true
                print("[IsPlayerEligible] Tracked other player GUID:", sourceGUID)
            end
        end
        
        print("[IsPlayerEligible] Returning nil (mob not target)")
        return nil
    end
    
    if not mobUnit or not UnitExists(mobUnit) or not UnitCanAttack("player", mobUnit) then
        print("[IsPlayerEligible] Invalid mob unit, returning nil")
        return nil
    end
    
    -- Only check threat if we're actually in combat
    if not UnitAffectingCombat("player") and not UnitAffectingCombat(mobUnit) then
        print("[IsPlayerEligible] Not in combat yet, can't check threat - returning nil")
        return nil
    end
    
    -- Get or create cache entry
    local now = GetTime()
    local cached = threatCache[destGUID]
    if not cached then
        cached = {
            playerThreat = 0,
            groupThreat = 0,
            otherPlayersThreat = 0,
            otherPlayerGUIDs = {},
            lastUpdated = now,
            needsUpdate = false
        }
        threatCache[destGUID] = cached
    end
    
    -- Track other players we see attacking this NPC
    if sourceGUID and not isPlayerOrPartyMember(sourceGUID) then
        local guidType = sourceGUID and select(1, strsplit("-", sourceGUID))
        if guidType == "Player" then
            cached.otherPlayerGUIDs[sourceGUID] = true
            print("[IsPlayerEligible] Tracked other player GUID:", sourceGUID)
        end
    end
    
    -- Update threat cache
    local playerThreat, groupThreat = calculateGroupThreat(mobUnit)
    print("[IsPlayerEligible] Threat calculated - player:", playerThreat, "group:", groupThreat)
    
    -- If we don't have threat data yet, don't update eligibility
    if playerThreat == 0 and groupThreat == 0 then
        print("[IsPlayerEligible] No threat data available yet, skipping eligibility check")
        -- Still update cache timestamp so we know we're tracking this NPC
        cached.lastUpdated = now
        return nil
    end
    
    -- Check threat for all other players we've seen
    local maxOtherPlayerThreat = 0
    local otherPlayerCount = 0
    local hasUnknownThreat = false  -- Track if we couldn't determine threat for any player
    for otherPlayerGUID, _ in pairs(cached.otherPlayerGUIDs) do
        otherPlayerCount = otherPlayerCount + 1
        local otherThreat = checkOtherPlayerThreat(mobUnit, otherPlayerGUID)
        print("[IsPlayerEligible] Other player threat - GUID:", otherPlayerGUID, "threat:", otherThreat)
        
        if otherThreat == nil then
            -- Couldn't determine threat (UnitTokenFromGUID failed)
            hasUnknownThreat = true
        else
            maxOtherPlayerThreat = math.max(maxOtherPlayerThreat, otherThreat or 0)
        end
    end
    print("[IsPlayerEligible] Other players tracked:", otherPlayerCount, "max threat:", maxOtherPlayerThreat, "hasUnknownThreat:", hasUnknownThreat)
    
    -- If we have unknown threat (couldn't check non-grouped players), use conservative approach
    -- If player has >= 90% threat, we can assume other players aren't helping significantly
    -- But if player has < 90%, we should be conservative
    if hasUnknownThreat then
        if playerThreat >= PLAYER_THREAT_THRESHOLD then
            -- Player has >= 90% threat, so even if other players are helping, player is clearly doing the work
            print("[IsPlayerEligible] Player has >= 90% threat, allowing despite unknown other player threat")
            maxOtherPlayerThreat = 0  -- Treat as if other players have no significant threat
        else
            -- Player has < 90% threat, and we've seen other players - be conservative
            print("[IsPlayerEligible] Player has < 90% threat and other players present, assuming they might be helping")
            maxOtherPlayerThreat = OTHER_PLAYER_THREAT_THRESHOLD + 1  -- Assume they exceed threshold
        end
    end
    
    -- Update cache
    cached.playerThreat = playerThreat
    cached.groupThreat = groupThreat
    cached.otherPlayersThreat = maxOtherPlayerThreat
    cached.lastUpdated = now
    cached.needsUpdate = false
    
    -- Determine eligibility
    local isEligible = false
    local inGroup = IsInGroup() or IsInRaid()
    print("[IsPlayerEligible] In group:", inGroup)
    
    if inGroup then
        -- In a group: check if group (player + highest group member) has >= 90% threat
        -- and no other players have >10% threat
        print("[IsPlayerEligible] Group check - groupThreat:", groupThreat, "threshold:", PLAYER_THREAT_THRESHOLD, "otherThreat:", maxOtherPlayerThreat, "otherThreshold:", OTHER_PLAYER_THREAT_THRESHOLD)
        if groupThreat >= PLAYER_THREAT_THRESHOLD and maxOtherPlayerThreat <= OTHER_PLAYER_THREAT_THRESHOLD then
            isEligible = true
            print("[IsPlayerEligible] GROUP ELIGIBLE - group threat sufficient and no other players")
        else
            print("[IsPlayerEligible] GROUP INELIGIBLE - group threat:", groupThreat, "other threat:", maxOtherPlayerThreat)
        end
    else
        -- Solo: check if player has >= 90% threat and no other players have >10% threat
        print("[IsPlayerEligible] Solo check - playerThreat:", playerThreat, "threshold:", PLAYER_THREAT_THRESHOLD, "otherThreat:", maxOtherPlayerThreat, "otherThreshold:", OTHER_PLAYER_THREAT_THRESHOLD)
        if playerThreat >= PLAYER_THREAT_THRESHOLD and maxOtherPlayerThreat <= OTHER_PLAYER_THREAT_THRESHOLD then
            isEligible = true
            print("[IsPlayerEligible] SOLO ELIGIBLE - player threat sufficient and no other players")
        else
            print("[IsPlayerEligible] SOLO INELIGIBLE - player threat:", playerThreat, "other threat:", maxOtherPlayerThreat)
        end
    end
    
    -- Special case: if mob is targeting a non-player (pet/dummy), allow it
    local mobTarget = mobUnit .. "target"
    if UnitExists(mobTarget) and not UnitIsPlayer(mobTarget) then
        print("[IsPlayerEligible] Mob targeting non-player (pet/dummy)")
        -- Mob is on a pet/dummy, allow it if no other players have significant threat
        if maxOtherPlayerThreat <= OTHER_PLAYER_THREAT_THRESHOLD then
            isEligible = true
            print("[IsPlayerEligible] ELIGIBLE - mob on pet/dummy and no other players")
        else
            print("[IsPlayerEligible] INELIGIBLE - mob on pet/dummy but other players have threat:", maxOtherPlayerThreat)
        end
    end
    
    print("[IsPlayerEligible] Final result:", isEligible)
    return isEligible
end

-- Function to get cached eligibility status (for use at kill time)
function IsPlayerEligibleForAchievement_GetCached(destGUID)
    print("[IsPlayerEligible_GetCached] Called with destGUID:", destGUID)
    
    if not destGUID then
        print("[IsPlayerEligible_GetCached] No destGUID, returning nil")
        return nil
    end
    
    local cached = threatCache[destGUID]
    if not cached then
        print("[IsPlayerEligible_GetCached] No cache entry found, returning nil")
        return nil
    end
    
    print("[IsPlayerEligible_GetCached] Cache found - playerThreat:", cached.playerThreat, "groupThreat:", cached.groupThreat, "otherThreat:", cached.otherPlayersThreat)
    
    local now = GetTime()
    local cacheAge = now - cached.lastUpdated
    print("[IsPlayerEligible_GetCached] Cache age:", cacheAge, "timeout:", CACHE_TIMEOUT)
    
    -- Return cached status if it's recent (within timeout)
    if cacheAge <= CACHE_TIMEOUT then
        print("[IsPlayerEligible_GetCached] Cache is fresh, checking eligibility")
        -- Try to get fresh threat data if the mob is still our target
        local mobUnit = nil
        if UnitExists("target") and UnitGUID("target") == destGUID then
            mobUnit = "target"
            print("[IsPlayerEligible_GetCached] Mob is still target, getting fresh threat data")
        else
            print("[IsPlayerEligible_GetCached] Mob not target, using cached threat data")
        end
        
        -- If we can check threat, use fresh data; otherwise use cached
        local playerThreat = cached.playerThreat
        local groupThreat = cached.groupThreat
        local maxOtherPlayerThreat = cached.otherPlayersThreat
        
        if mobUnit and UnitExists(mobUnit) and UnitCanAttack("player", mobUnit) then
            -- Get fresh threat data
            playerThreat, groupThreat = calculateGroupThreat(mobUnit)
            print("[IsPlayerEligible_GetCached] Fresh threat - player:", playerThreat, "group:", groupThreat)
            
            -- Check threat for all other players we've seen
            maxOtherPlayerThreat = 0
            local hasUnknownThreat = false
            for otherPlayerGUID, _ in pairs(cached.otherPlayerGUIDs) do
                local otherThreat = checkOtherPlayerThreat(mobUnit, otherPlayerGUID)
                if otherThreat == nil then
                    hasUnknownThreat = true
                else
                    maxOtherPlayerThreat = math.max(maxOtherPlayerThreat, otherThreat or 0)
                end
            end
            
            -- Apply same conservative logic as in main function
            if hasUnknownThreat then
                if playerThreat >= PLAYER_THREAT_THRESHOLD then
                    maxOtherPlayerThreat = 0
                else
                    maxOtherPlayerThreat = OTHER_PLAYER_THREAT_THRESHOLD + 1
                end
            end
            
            print("[IsPlayerEligible_GetCached] Fresh other player threat:", maxOtherPlayerThreat, "hasUnknownThreat:", hasUnknownThreat)
            
            -- Update cache with fresh data
            cached.playerThreat = playerThreat
            cached.groupThreat = groupThreat
            cached.otherPlayersThreat = maxOtherPlayerThreat
            cached.lastUpdated = now
        else
            print("[IsPlayerEligible_GetCached] Using cached threat values")
        end
        
        -- Recalculate eligibility from threat values
        local isEligible = false
        local inGroup = IsInGroup() or IsInRaid()
        
        if inGroup then
            print("[IsPlayerEligible_GetCached] Group check - groupThreat:", groupThreat, "otherThreat:", maxOtherPlayerThreat)
            if groupThreat >= PLAYER_THREAT_THRESHOLD and maxOtherPlayerThreat <= OTHER_PLAYER_THREAT_THRESHOLD then
                isEligible = true
                print("[IsPlayerEligible_GetCached] GROUP ELIGIBLE")
            else
                print("[IsPlayerEligible_GetCached] GROUP INELIGIBLE")
            end
        else
            print("[IsPlayerEligible_GetCached] Solo check - playerThreat:", playerThreat, "otherThreat:", maxOtherPlayerThreat)
            if playerThreat >= PLAYER_THREAT_THRESHOLD and maxOtherPlayerThreat <= OTHER_PLAYER_THREAT_THRESHOLD then
                isEligible = true
                print("[IsPlayerEligible_GetCached] SOLO ELIGIBLE")
            else
                print("[IsPlayerEligible_GetCached] SOLO INELIGIBLE")
            end
        end
        
        -- Special case: if mob is targeting a non-player (pet/dummy), allow it
        if mobUnit then
            local mobTarget = mobUnit .. "target"
            if UnitExists(mobTarget) and not UnitIsPlayer(mobTarget) then
                print("[IsPlayerEligible_GetCached] Mob targeting non-player")
                if maxOtherPlayerThreat <= OTHER_PLAYER_THREAT_THRESHOLD then
                    isEligible = true
                    print("[IsPlayerEligible_GetCached] ELIGIBLE - mob on pet/dummy")
                end
            end
        end
        
        print("[IsPlayerEligible_GetCached] Final result:", isEligible)
        return isEligible
    end
    
    -- Cache expired, remove it
    print("[IsPlayerEligible_GetCached] Cache expired, removing")
    threatCache[destGUID] = nil
    return nil
end

-- Function to clear cache for a specific GUID (called when NPC dies)
function IsPlayerEligibleForAchievement_ClearCache(destGUID)
    print("[IsPlayerEligible_ClearCache] Called with destGUID:", destGUID)
    if destGUID then
        threatCache[destGUID] = nil
        print("[IsPlayerEligible_ClearCache] Cache cleared for:", destGUID)
    end
end

-- Cleanup function to remove old cache entries
local function cleanupCache()
    local now = GetTime()
    for guid, data in pairs(threatCache) do
        if now - data.lastUpdated > CACHE_TIMEOUT then
            threatCache[guid] = nil
        end
    end
end

-- Register cleanup on combat end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Clean up cache after a delay (in case we're still processing events)
        C_Timer.After(2, function()
            if not UnitAffectingCombat("player") then
                cleanupCache()
            end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Clear cache on zone loads
        threatCache = {}
    end
end)

