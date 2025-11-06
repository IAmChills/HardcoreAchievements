-- GetStatusText.lua
-- Helper function to determine achievement status text based on current state

local function GetStatusText(params)
    -- params should contain:
    --   completed: boolean - whether achievement is completed
    --   hasSoloStatus: boolean - whether progress has soloKill or soloQuest
    --   hasIneligibleKill: boolean - whether progress has ineligibleKill flag
    --   requiresBoth: boolean - whether achievement requires both kill AND quest
    --   killsSatisfied: boolean - whether kills are satisfied but quest is not yet turned in
    --   isSelfFound: boolean - whether player is self-found
    --   isSoloMode: boolean - whether solo mode toggle is enabled
    --   wasSolo: boolean - whether achievement was completed solo (only for completed achievements)
    --   allowSoloDouble: boolean - whether achievement allows solo doubling
    
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
            return "|cffcf7171Pending Turn-in (ineligible kill)|r"
        else
            return "|cffcf7171Ineligible Kill|r"
        end
    end
    
    if completed and wasSolo and isSelfFound then
        return "|cFFac81d6Solo|r"
    end
    
    -- Check if kills are satisfied but quest is pending (for achievements requiring both)
    if not completed and requiresBoth and killsSatisfied then
        if hasSoloStatus and isSelfFound then
            return "|cFFac81d6Pending Turn-in (solo)|r"
        else
            return "|cFF99e699Pending Turn-in|r"
        end
    end
    
    if not completed and hasSoloStatus and isSelfFound then
        return "|cFFac81d6Pending Turn-in (solo)|r"
    end
    
    if not completed and isSoloMode and allowSoloDouble and not hasSoloStatus and isSelfFound then
        return "|cFFac81d6Solo|r"
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
    
    if statusText then
        if maxLevel then
            local levelText = (LEVEL or "Level") .. " " .. maxLevel
            row.Sub:SetText(levelText .. "\n" .. statusText)
        else
            row.Sub:SetText(statusText)
        end
    elseif maxLevel then
        row.Sub:SetText((LEVEL or "Level") .. " " .. maxLevel)
    else
        row.Sub:SetText(AUCTION_TIME_LEFT0 or "")
    end
end

-- Helper function to extract all display data from an achievement row
-- This centralizes the logic so both the character panel and embed file use the same data
local function ExtractRowDisplayData(row)
    if not row then return nil end
    
    -- Extract basic data
    local title = ""
    if row.Title and row.Title.GetText then
        title = row.Title:GetText() or ""
    elseif type(row.id) == "string" then
        title = row.id
    end
    
    local iconTex = nil
    if row.Icon and row.Icon.GetTexture then
        iconTex = row.Icon:GetTexture()
    end
    
    local points = tonumber(row.points) or 0
    local maxLevel = tonumber(row.maxLevel) or nil
    local completed = not not row.completed
    
    -- Extract status text from Sub field (this already has level + status formatted)
    local statusText = nil
    if row.Sub and row.Sub.GetText then
        local subText = row.Sub:GetText() or ""
        if subText ~= "" then
            statusText = subText
        end
    end
    
    -- Build tooltip text with party members appended (same logic as CreateAchievementRow)
    local tooltipText = row.tooltip or title
    local isCatalogAchievement = false
    local currentAchId = row.achId or row.id
    if _G.Achievements and currentAchId then
        for _, achievementDef in ipairs(_G.Achievements) do
            if achievementDef.achId == currentAchId then
                isCatalogAchievement = true
                break
            end
        end
    end
    
    local isSecret = row.isSecretAchievement
    local isSoloModeChecked = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    local isLevelMilestone = _G.IsLevelMilestone and _G.IsLevelMilestone(currentAchId) or false
    
    if isCatalogAchievement and not isSecret and not isSoloModeChecked and not isLevelMilestone then
        tooltipText = tooltipText .. "|cffFFD700 (including all party members)|r"
    end
    
    -- Determine if title should show solo indicator (for tooltip display)
    local showSoloIndicator = false
    if isSoloModeChecked and row.allowSoloDouble then
        showSoloIndicator = true
    end
    
    return {
        id = row.id or currentAchId or title,
        achId = currentAchId,
        title = title,
        iconTex = iconTex,
        tooltip = tooltipText,
        statusText = statusText,
        points = points,
        maxLevel = maxLevel,
        completed = completed,
        zone = row.zone,
        requiredKills = row.requiredKills,
        allowSoloDouble = not not row.allowSoloDouble,
        showSoloIndicator = showSoloIndicator,
        isSecretAchievement = isSecret,
    }
end

-- Export globally
_G.HCA_GetStatusText = GetStatusText
_G.HCA_SetStatusTextOnRow = SetStatusTextOnRow
_G.HCA_ExtractRowDisplayData = ExtractRowDisplayData

return GetStatusText

