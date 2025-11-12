-- IsGroupEligibleForAchievement.lua
-- Checks if the player's group is eligible for an achievement based on level requirements
-- Uses threat system to allow kills even with overleveled party members nearby,
-- as long as NO overleveled party member has >10% threat (scaled or raw)
-- Disqualifies if ANY overleveled party member has >10% threat, regardless of player's threat percentage
-- Returns true if eligible, false otherwise
-- Parameters:
--   MAX_LEVEL (number): The maximum level allowed for the achievement
--   ACH_ID (string, optional): Achievement ID (for future use)

-- Configuration
local OTHER_PLAYER_THREAT_THRESHOLD = 10  -- % threat from overleveled party members to fail (if ANY overleveled member has >10% threat, disqualify)

function IsGroupEligibleForAchievement(MAX_LEVEL, ACH_ID)
    -- If not in a group or raid, player is eligible (solo)
    if not IsInGroup() and not IsInRaid() then
        return true
    end
    
    -- If in a raid, not eligible
    if IsInRaid() then
        return false
    end
    
    -- Check party size (should not exceed 5 members)
    local members = GetNumGroupMembers()
    if members > 5 then
        return false
    end
    
    -- Helper function to check if a unit is overleveled
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
    
    -- Check if player is overleveled
    if overLeveled("player") then
        return false
    end
    
    -- Check party members (only if in a party)
    if members > 1 then
        -- First, collect all overleveled party members in range
        local overleveledMembers = {}
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                if overLeveled(unit) and UnitInRange(unit) then
                    table.insert(overleveledMembers, unit)
                end
            end
        end
        
        -- If we have overleveled party members in range, check threat
        if #overleveledMembers > 0 then
            -- Check if we're in combat with a target that we can check threat on
            -- Also check if we just left combat (target might still exist briefly)
            local targetUnit = nil
            local canCheckThreat = false
            
            if UnitExists("target") and UnitCanAttack("player", "target") then
                -- Check if we're in combat or just left combat (recently)
                if UnitAffectingCombat("player") or UnitAffectingCombat("target") then
                    targetUnit = "target"
                    canCheckThreat = true
                else
                    -- Not in combat, but target exists - try to check threat anyway
                    -- Threat data might still be available for a brief moment after combat
                    targetUnit = "target"
                    local isTanking, status, scaledPct, rawPct = UnitDetailedThreatSituation("player", targetUnit)
                    if scaledPct or rawPct or status then
                        canCheckThreat = true
                    end
                end
            end
            
            -- If we can check threat, use threat-based logic
            if canCheckThreat and targetUnit then
                -- Check if ANY overleveled party member has significant threat (>10%)
                -- This is an absolute check: if ANY overleveled member has >10% threat, disqualify
                -- regardless of player's threat percentage (player might have grabbed threat at the end)
                
                for _, unit in ipairs(overleveledMembers) do
                    local isUnitTanking, unitStatus, scaledPct, rawPct = UnitDetailedThreatSituation(unit, targetUnit)
                    
                    -- Check if this unit is tanking (definitely helping) - disqualify immediately
                    if isUnitTanking and unitStatus and unitStatus >= 2 then
                        -- Overleveled party member is tanking, they're definitely helping - disqualify
                        return false
                    end
                    
                    -- Check if this unit has >10% threat on EITHER scaled or raw threat
                    -- Disqualify if scaledPct > 10% OR rawPct > 10%
                    -- This ensures we catch cases where either metric shows they're helping
                    local hasSignificantThreat = false
                    
                    if scaledPct and scaledPct > OTHER_PLAYER_THREAT_THRESHOLD then
                        hasSignificantThreat = true
                    end
                    
                    if rawPct and rawPct > OTHER_PLAYER_THREAT_THRESHOLD then
                        hasSignificantThreat = true
                    end
                    
                    -- If this overleveled party member has significant threat (>10%), they're helping - disqualify
                    if hasSignificantThreat then
                        return false
                    end
                end
                
                -- No overleveled party member has >10% threat, so they're not helping meaningfully
                -- Allow the kill - player is doing the work, overleveled members are just nearby
                
                -- Check if mob is targeting a non-player (pet/dummy) - if so, definitely allow it
                local mobTarget = targetUnit .. "target"
                if UnitExists(mobTarget) and not UnitIsPlayer(mobTarget) then
                    -- Mob is targeting a non-player (pet/dummy), allow it
                    return true
                end
                
                -- All overleveled party members have <=10% threat, so they're not helping
                -- Allow the kill
                return true
            else
                -- No valid target or threat data not available, but overleveled party members are in range
                -- Check if we're still in combat (might be fighting something else)
                -- If not in combat, we can't verify threat, so fall back to conservative behavior
                if not UnitAffectingCombat("player") then
                    -- Not in combat and can't check threat - disqualify if overleveled party member is nearby
                    -- This is conservative: if we can't verify the player had >=90% threat, we disqualify
                    return false
                else
                    -- Still in combat but can't check threat on target (might be fighting something else)
                    -- This is an edge case - if we're in combat but can't verify threat, be conservative
                    return false
                end
            end
        end
    end
    
    -- All checks passed, group is eligible
    return true
end
