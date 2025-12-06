-- IsGroupEligibleForAchievement.lua
-- Checks if the player's group is eligible for an achievement based on level requirements
-- Uses threat system to allow kills even with overleveled players nearby,
-- as long as NO overleveled player (party or non-party) has >10% threat (scaled or raw)
-- Disqualifies if ANY overleveled player has >10% threat, regardless of player's threat percentage
-- Returns true if eligible, false otherwise
-- Parameters:
--   MAX_LEVEL (number): The maximum level allowed for the achievement
--   ACH_ID (string, optional): Achievement ID (for future use)
--   destGUID (string, optional): GUID of the NPC being checked (if provided, checks this NPC specifically)

-- Configuration
local OTHER_PLAYER_THREAT_THRESHOLD = 10  -- % threat from overleveled players to fail (if ANY has >10% threat, disqualify)

function IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID, destGUID)
    -- If in a raid, not eligible
    if IsInRaid() then
        return false
    end

    -- Check party size (should not exceed 5 members)
    local members = GetNumGroupMembers()
    if members > 5 then
        return false
    end

    -- Helper: is this unit over the configured max level?
    local function overLeveled(unit)
        if not UnitExists(unit) then
            return false
        end
        local lvl = UnitLevel(unit)
        if not lvl then
            return false
        end
        if MAX_LEVEL and MAX_LEVEL > 0 then
            return lvl > MAX_LEVEL
        end
        return false -- No level cap means no one is overleveled
    end

    -- Helper: true if this unit is a non-group player (not you, not in your party/raid)
    local function isNonGroupPlayer(unit)
        if not UnitExists(unit) then
            return false
        end
        if not UnitIsPlayer(unit) then
            return false
        end
        if UnitIsUnit(unit, "player") then
            return false
        end
        if UnitInParty(unit) or UnitInRaid(unit) then
            return false
        end
        return true
    end

    -- Helper: check if unit has "significant" threat vs targetUnit
    local function hasSignificantThreat(unit, targetUnit)
        if not UnitExists(unit) or not UnitExists(targetUnit) then
            return false
        end

        local isUnitTanking, unitStatus, scaledPct, rawPct = UnitDetailedThreatSituation(unit, targetUnit)

        -- If they're tanking (high threat and mob focused on them), they're definitely helping
        if isUnitTanking and unitStatus and unitStatus >= 2 then
            return true
        end

        -- If either scaled or raw threat exceeds the threshold, treat as helping
        if scaledPct and scaledPct > OTHER_PLAYER_THREAT_THRESHOLD then
            return true
        end
        if rawPct and rawPct > OTHER_PLAYER_THREAT_THRESHOLD then
            return true
        end

        return false
    end

    -- Player themselves must not be overleveled
    if overLeveled("player") then
        return false
    end

    -------------------------------------------------------------------------
    -- Determine a target we can use for threat checks (shared by all logic)
    -- If destGUID is provided, try to use that NPC; otherwise use current target
    -------------------------------------------------------------------------
    local targetUnit = nil
    local canCheckThreat = false
    local targetGUID = nil

    -- First, try to use the provided destGUID (the NPC that was killed)
    if destGUID then
        targetGUID = destGUID
        -- Check if it's our current target
        if UnitExists("target") and UnitGUID("target") == destGUID and UnitCanAttack("player", "target") then
            targetUnit = "target"
            -- Check if we're in combat or just left combat (recently)
            if UnitAffectingCombat("player") or UnitAffectingCombat("target") then
                canCheckThreat = true
            else
                -- Not in combat, but target exists - try to check threat anyway
                local _, status, scaledPct, rawPct = UnitDetailedThreatSituation("player", targetUnit)
                if scaledPct or rawPct or status then
                    canCheckThreat = true
                end
            end
        end
        -- If destGUID provided but not our target, we'll still check external players via tracking
        -- (which doesn't require the NPC to be our target)
    end
    
    -- Fallback: use current target if no destGUID or destGUID wasn't our target
    if not targetUnit then
        if UnitExists("target") and UnitCanAttack("player", "target") then
            targetGUID = UnitGUID("target")
            -- Check if we're in combat or just left combat (recently)
            if UnitAffectingCombat("player") or UnitAffectingCombat("target") then
                targetUnit = "target"
                canCheckThreat = true
            else
                -- Not in combat, but target exists - try to check threat anyway
                targetUnit = "target"
                local _, status, scaledPct, rawPct = UnitDetailedThreatSituation("player", targetUnit)
                if scaledPct or rawPct or status then
                    canCheckThreat = true
                end
            end
        end
    end
    
    -- If destGUID was provided but we don't have a target unit, set targetGUID for external player checks
    if destGUID and not targetGUID then
        targetGUID = destGUID
    elseif targetUnit then
        targetGUID = UnitGUID(targetUnit)
    end

    -------------------------------------------------------------------------
    -- 1) Party members (existing behavior, refactored to use helpers)
    -------------------------------------------------------------------------
    if members > 1 then
        -- Collect all overleveled party members in range
        local overleveledParty = {}
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                if overLeveled(unit) and UnitInRange(unit) then
                    table.insert(overleveledParty, unit)
                end
            end
        end

        if #overleveledParty > 0 then
            if canCheckThreat and targetUnit then
                -- If ANY overleveled party member has significant threat, disqualify
                for _, unit in ipairs(overleveledParty) do
                    if hasSignificantThreat(unit, targetUnit) then
                        return false
                    end
                end

                -- Check pets of overleveled party members
                for _, unit in ipairs(overleveledParty) do
                    local petUnit = unit .. "pet"
                    if UnitExists(petUnit) then
                        -- Check if the pet has significant threat
                        if hasSignificantThreat(petUnit, targetUnit) then
                            -- Overleveled party member's pet has >10% threat - disqualify
                            return false
                        end
                    end
                end

                -- If mob is targeting a non-player (pet/dummy), that's always fine
                local mobTarget = targetUnit .. "target"
                if UnitExists(mobTarget) and not UnitIsPlayer(mobTarget) then
                    -- NOTE: we intentionally do NOT return here; we still want
                    -- to run the non-party helper checks below.
                end

                -- At this point, overleveled party members are either out of range
                -- or below the threat threshold. We do not early-return true here
                -- so that non-party helpers can still be considered.

            else
                -- Overleveled party members nearby but we can't verify threat.
                -- Stay conservative and disqualify.
                if not UnitAffectingCombat("player") then
                    return false
                else
                    return false
                end
            end
        end
        
        -- Also check ALL party member pets (even if owner isn't overleveled)
        -- If a pet's owner is overleveled OR the pet itself is overleveled, check threat
        if canCheckThreat and targetUnit then
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    local petUnit = unit .. "pet"
                    if UnitExists(petUnit) then
                        -- Check if owner is overleveled
                        local ownerOverleveled = overLeveled(unit)
                        -- Check if pet itself is overleveled (if we can check its level)
                        local petOverleveled = false
                        local petLevel = UnitLevel(petUnit)
                        if petLevel and MAX_LEVEL and MAX_LEVEL > 0 then
                            petOverleveled = petLevel > MAX_LEVEL
                        end
                        
                        -- If owner is overleveled OR pet is overleveled, check threat
                        if (ownerOverleveled or petOverleveled) and hasSignificantThreat(petUnit, targetUnit) then
                            return false
                        end
                    end
                end
            end
        end
    end
    
    -- Check player's own pet if overleveled
    if canCheckThreat and targetUnit then
        if UnitExists("pet") then
            local petOverleveled = false
            local petLevel = UnitLevel("pet")
            if petLevel and MAX_LEVEL and MAX_LEVEL > 0 then
                petOverleveled = petLevel > MAX_LEVEL
            end
            
            -- If pet is overleveled and has significant threat, disqualify
            if petOverleveled and hasSignificantThreat("pet", targetUnit) then
                return false
            end
        end
    end

    -------------------------------------------------------------------------
    -- 2) Non-party helpers: event bridge tracking + simple fallback checks
    --
    -- Primary: Check external players tracked by event bridge (combat log detection)
    -- Fallback: Check targettarget and mouseover (common cases when fighting NPCs)
    --
    -- If any such overleveled non-group player has >10% threat, disqualify.
    -------------------------------------------------------------------------
    -- Primary: Check external players tracked by event bridge
    -- This works even if we can't check threat directly (uses stored threat data from combat)
    if targetGUID and _G.GetExternalPlayersForNPC then
            local externalPlayers = _G.GetExternalPlayersForNPC(targetGUID)
            local playerThreat = 0
            
            -- Only check player threat if we have a valid target unit
            if targetUnit and canCheckThreat then
                local _, _, playerScaledPct, playerRawPct = UnitDetailedThreatSituation("player", targetUnit)
                if playerScaledPct then
                    playerThreat = playerScaledPct
                elseif playerRawPct then
                    playerThreat = playerRawPct
                end
            end
            
            local hasUnknownExternalPlayers = false
            
            for externalGUID, data in pairs(externalPlayers) do
                -- Try to get unit token to check level and threat
                local unitToken = UnitTokenFromGUID(externalGUID)
                local threat = data.threat
                local isTanking = false
                
                -- Try to get current threat if we have a valid target unit (for fresh data)
                if targetUnit and canCheckThreat then
                    if unitToken and UnitExists(unitToken) then
                        local tanking, status, scaledPct, rawPct = UnitDetailedThreatSituation(unitToken, targetUnit)
                        if scaledPct or rawPct then
                            threat = scaledPct or rawPct
                            -- Update stored threat data
                            data.threat = threat
                        end
                        -- Check if they're tanking (status >= 2 means they're the primary target, definitely high threat)
                        if tanking and status and status >= 2 then
                            isTanking = true
                            threat = 100 -- Tanking means very high threat
                            data.threat = threat
                        end
                    end
                end
                
                -- Track if we couldn't verify this external player
                if not unitToken or not UnitExists(unitToken) then
                    hasUnknownExternalPlayers = true
                end
                
                -- Also check stored threat data if we couldn't get fresh data
                -- (This handles cases where NPC is dead but we have stored threat from before death)
                if not threat and data.threat then
                    threat = data.threat
                end
                
                -- Check if they were tanking (from stored data)
                if not isTanking and data.isTanking then
                    isTanking = true
                    threat = 100 -- Treat tanking as 100% threat
                end
                
                -- Check threat: if external player has >10% threat OR is tanking, verify if they're overleveled
                if (threat and threat > OTHER_PLAYER_THREAT_THRESHOLD) or isTanking then
                    if unitToken and UnitExists(unitToken) then
                        -- We can check level - only disqualify if they're actually overleveled
                        if isNonGroupPlayer(unitToken) and overLeveled(unitToken) then
                            -- Overleveled external player with >10% threat or tanking - disqualify
                            return false
                        end
                        -- If they have >10% threat but we can verify they're NOT overleveled, allow it
                    else
                        -- Can't get unit token to check level, but they have >10% threat or were tanking
                        -- Conservative: assume they might be overleveled and disqualify
                        return false
                    end
                end
            end
            
            -- Conservative heuristic: if external players detected but can't verify levels
            -- If we can't check player threat (targeting a player instead of NPC), be very conservative
            if hasUnknownExternalPlayers then
                if not canCheckThreat or playerThreat < 90 then
                    -- External players present + can't verify threat OR low player threat = likely getting help
                    -- Since we can't check their levels, be conservative and disqualify
                    return false
                end
            end
        end
    
    -- Fallback: Simple checks for common visible units (targettarget, mouseover)
    -- These are the most common cases when fighting an achievement NPC
    -- Only check if we have a valid target unit for threat checks
    if targetUnit and canCheckThreat then
            local function checkNonGroupHelper(unit)
                if not UnitExists(unit) then
                    return false
                end
                if not isNonGroupPlayer(unit) then
                    return false
                end
                if not overLeveled(unit) then
                    return false
                end
                if hasSignificantThreat(unit, targetUnit) then
                    return true
                end
                return false
            end

            -- Boss's current target (common case: player might target the helping player)
            if checkNonGroupHelper("targettarget") then
                return false
            end

            -- Mouseover (common case: player might mouseover a helping player)
            if checkNonGroupHelper("mouseover") then
                return false
            end
        end
    
    -- If destGUID was provided but we couldn't check threat (e.g., targeting a player),
    -- and external players were tracked, be conservative and check them
    if destGUID and not canCheckThreat and _G.GetExternalPlayersForNPC then
        local externalPlayers = _G.GetExternalPlayersForNPC(destGUID)
        -- If any external players were tracked, disqualify (conservative approach when we can't verify)
        for externalGUID, data in pairs(externalPlayers) do
            -- If we have threat data and it's significant, disqualify
            if data.threat and data.threat > OTHER_PLAYER_THREAT_THRESHOLD then
                return false
            end
            -- If we have external players but can't verify anything, be conservative
            -- (Better to disqualify than allow potential cheating)
            return false
        end
    end

    -- All checks passed: no overleveled party OR non-party player is meaningfully helping
    return true
end
