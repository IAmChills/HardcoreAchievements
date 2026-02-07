local addonName, addon = ...
local C_GameRules = C_GameRules

-- Centralized: compute status params for an achievement. Use this everywhere so status logic is identical.
-- row: model entry or frame with questTracker, killTracker, requiredKills/_def, completed, maxLevel, allowSoloDouble
-- Returns params table for GetStatusText/SetStatusTextOnRow, or nil if row/achId missing
local function GetStatusParamsForAchievement(achId, row)
    if not achId or not row then return nil end
    local progress = (addon and addon.GetProgress) and addon.GetProgress(achId) or nil
    local rowId = achId
    local requiresBoth = (row.questTracker ~= nil) and (row.killTracker ~= nil or (row.requiredKills and next(row.requiredKills)) or (row._def and (row._def.requiredKills and next(row._def.requiredKills) or row._def.targetNpcId)))
    local killsSatisfied = false
    if requiresBoth and progress and not (addon and addon.IsRowOutleveled and addon.IsRowOutleveled(row)) then
        local hasKill = false
        if progress.killed then
            hasKill = true
        elseif progress.eligibleCounts and next(progress.eligibleCounts) ~= nil then
            local reqKills = row.requiredKills or (row._def and row._def.requiredKills)
            if reqKills then
                local allSat = true
                for npcId, need in pairs(reqKills) do
                    local idNum = tonumber(npcId) or npcId
                    local cur = progress.eligibleCounts[idNum] or progress.eligibleCounts[tostring(idNum)] or 0
                    if cur < (tonumber(need) or 1) then allSat = false break end
                end
                hasKill = allSat
            else
                hasKill = progress.killed or false
            end
        elseif progress.killed then
            hasKill = true
        end
        killsSatisfied = hasKill and not progress.quest
    end
    local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
    local isSelfFound = (addon and addon.IsSelfFound) and addon.IsSelfFound() or false
    local isSoloMode = (addon and addon.IsSoloModeEnabled) and addon.IsSoloModeEnabled() or false
    local wasSolo = false
    if row.completed and addon and addon.GetCharDB then
        local _, cdb = addon.GetCharDB()
        if cdb and cdb.achievements and rowId then
            local rec = cdb.achievements[tostring(rowId)]
            wasSolo = rec and rec.wasSolo or false
        end
    end
    return {
        completed = row.completed or false,
        hasSoloStatus = hasSoloStatus,
        hasIneligibleKill = progress and progress.ineligibleKill,
        requiresBoth = requiresBoth,
        killsSatisfied = killsSatisfied,
        isSelfFound = isSelfFound,
        isSoloMode = isSoloMode,
        wasSolo = wasSolo,
        allowSoloDouble = row.allowSoloDouble,
        maxLevel = row.maxLevel,
        isOutleveled = (addon and addon.IsRowOutleveled) and addon.IsRowOutleveled(row),
    }
end

local function GetStatusText(params)
    local ClassColor = (addon and addon.GetClassColor())
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
        return ClassColor .. "Solo|r"
    end
    
    -- Check if kills are satisfied but quest is pending (for achievements requiring both)
    if not completed and requiresBoth and killsSatisfied then
        if hasSoloStatus and allowSoloBonus then
            return ClassColor .. "Pending Turn-in (solo)|r"
        else
            return ClassColor .. "Pending Turn-in|r"
        end
    end
    
    if not completed and requiresBoth and hasSoloStatus and allowSoloBonus then
        return ClassColor .. "Pending Turn-in (solo)|r"
    end
    
    if not completed and isSoloMode and allowSoloDouble and not hasSoloStatus and allowSoloBonus then
        return ClassColor .. "Solo bonus|r"
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

if addon then
    addon.SetStatusTextOnRow = SetStatusTextOnRow
    addon.GetStatusText = GetStatusText
    addon.GetStatusParamsForAchievement = GetStatusParamsForAchievement
end