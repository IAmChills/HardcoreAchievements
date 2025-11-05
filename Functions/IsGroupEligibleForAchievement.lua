-- IsGroupEligibleForAchievement.lua
-- Checks if the player's group is eligible for an achievement based on level requirements
-- Returns true if eligible, false otherwise
-- Parameters:
--   MAX_LEVEL (number): The maximum level allowed for the achievement

function IsGroupEligibleForAchievement(MAX_LEVEL)
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
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                -- Check if party member is overleveled AND in range
                if overLeveled(unit) and UnitInRange(unit) then
                    return false -- Found an overleveled party member in range
                end
            end
        end
    end
    
    -- All checks passed, group is eligible
    return true
end

