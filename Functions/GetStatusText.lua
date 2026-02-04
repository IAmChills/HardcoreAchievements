-- GetStatusText.lua
-- Helper function to determine achievement status text based on current state

local function GetStatusText(params)
    local completed = params.completed or false
    local hasSoloStatus = params.hasSoloStatus or false
    local hasIneligibleKill = params.hasIneligibleKill or false
    local requiresBoth = params.requiresBoth or false
    local killsSatisfied = params.killsSatisfied or false
    local isSelfFound = params.isSelfFound or false
    local isSoloMode = params.isSoloMode or false
    local wasSolo = params.wasSolo or false
    local allowSoloDouble = params.allowSoloDouble or false
    
    -- Priority order:
    -- 1. Ineligible kill (takes highest priority)
    -- 2. Completed solo (if completed and wasSolo)
    -- 3. Pending Turn-in (if kills satisfied but quest not turned in)
    -- 4. Pending Turn-in (solo) (if kills satisfied, quest pending, and has solo status)
    -- 5. Pending solo (if has solo status but not completed and not pending turn-in)
    -- 6. Solo preview (if solo mode toggle is on and no solo status yet)
    
    if hasIneligibleKill and not completed then
        -- Determine message based on whether both kill and quest are required
        if requiresBoth then
            return "|cffff4646Ineligible Kill|r"
        else
            return "|cffff4646Ineligible Kill|r"
        end
    end
    
    -- Solo bonuses: require self-found if hardcore is active, otherwise solo is allowed
    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
    local allowSoloBonus = isSelfFound or not isHardcoreActive
    
    if completed and wasSolo and allowSoloBonus then
        return HCA_SharedUtils.GetClassColor() .. "Solo|r"
    end
    
    -- Check if kills are satisfied but quest is pending (for achievements requiring both)
    if not completed and requiresBoth and killsSatisfied then
        if hasSoloStatus and allowSoloBonus then
            return HCA_SharedUtils.GetClassColor() .. "Pending Turn-in (solo)|r"
        else
            return HCA_SharedUtils.GetClassColor() .. "Pending Turn-in|r"
        end
    end
    
    if not completed and requiresBoth and hasSoloStatus and allowSoloBonus then
        return HCA_SharedUtils.GetClassColor() .. "Pending Turn-in (solo)|r"
    end
    
    if not completed and isSoloMode and allowSoloDouble and not hasSoloStatus and allowSoloBonus then
        return HCA_SharedUtils.GetClassColor() .. "Solo bonus|r"
    end
    
    -- No special status
    return nil
end

-- Helper function to set status text on an achievement row
-- This handles the level text logic automatically
local function SetStatusTextOnRow(row, params)
    if not row or not row.Sub then return end
    
    local statusText = GetStatusText(params)
    local maxLevel = row.maxLevel or (params.maxLevel and tonumber(params.maxLevel) > 0 and params.maxLevel) or nil
    local isSecretAchievement = false
    if params.isSecretAchievement ~= nil then
        isSecretAchievement = params.isSecretAchievement
    elseif row.isSecretAchievement ~= nil then
        isSecretAchievement = row.isSecretAchievement
    end
    local completed = params.completed or false
    
    if statusText then
        if maxLevel then
            local levelText = (LEVEL or "Level") .. " " .. maxLevel
            row.Sub:SetText(levelText .. "\n" .. statusText)
        else
            row.Sub:SetText(statusText)
        end
    elseif isSecretAchievement and not completed then
        row.Sub:SetText("")
    elseif maxLevel then
        row.Sub:SetText((LEVEL or "Level") .. " " .. maxLevel)
    else
        if completed then
            row.Sub:SetText(AUCTION_TIME_LEFT0 or "")
        else
            local defaultText = row._defaultSubText
            row.Sub:SetText(defaultText or "")
        end
    end
end

-- Export globally
_G.HCA_GetStatusText = GetStatusText
_G.HCA_SetStatusTextOnRow = SetStatusTextOnRow

return GetStatusText
