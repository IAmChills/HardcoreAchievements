-- Centralized function to show achievement tooltip
-- Can be called from main window or embed UI

---------------------------------------
-- Helper Functions
---------------------------------------

-- Extract achievement data from row object or data table
local function ExtractAchievementData(data)
    local result = {
        title = "",
        tooltip = "",
        zone = nil,
        achId = nil,
        maxLevel = nil,
        points = nil,
        allowSoloDouble = false,
        isSecretAchievement = false,
        isProfessionAchievement = false,
        def = nil,
        achievementCompleted = false,
        requiredKills = nil,
        requiredItems = nil,
        itemOrder = nil,
        requiredAchievements = nil,
        achievementOrder = nil,
        secretPoints = nil
    }
    
    if type(data) ~= "table" then
        return result
    end
    
    local isRowObject = data.Title and data.Title.GetText
    
    -- Extract basic data
    if isRowObject then
        result.title = data.Title:GetText() or data._title or ""
        result.tooltip = data.tooltip or data._tooltip or ""
        result.zone = data.zone or data._zone
        result.achId = data.achId or data.id or data._achId
        result.maxLevel = data.maxLevel
        result.points = data.points
        result.allowSoloDouble = data.allowSoloDouble or false
        result.isSecretAchievement = data.isSecretAchievement or false
        result.def = data._def
        result.secretPoints = data.secretPoints
        if data.requireProfessionSkillID or (result.def and result.def.requireProfessionSkillID) then
            result.isProfessionAchievement = true
        end
        if data.completed or (data.sourceRow and data.sourceRow.completed) then
            result.achievementCompleted = true
        end
    else
        result.title = data.title or ""
        result.tooltip = data.tooltip or ""
        result.zone = data.zone
        result.achId = data.achId or data.id
        result.maxLevel = data.maxLevel
        result.points = data.points
        result.allowSoloDouble = data.allowSoloDouble or false
        result.isSecretAchievement = data.isSecretAchievement or false
        result.secretPoints = data.secretPoints
        if data.requireProfessionSkillID then
            result.isProfessionAchievement = true
        end
        if data.completed then
            result.achievementCompleted = true
        end
    end
    
    -- Extract requirements (with sourceRow fallback)
    local function getValue(key)
        local value = data[key]
        if not value and data.sourceRow then
            value = data.sourceRow[key]
        end
        return value
    end
    
    result.requiredKills = getValue("requiredKills")
    result.requiredItems = getValue("requiredItems")
    result.itemOrder = getValue("itemOrder")
    result.requiredAchievements = getValue("requiredAchievements")
    result.achievementOrder = getValue("achievementOrder")
    
    return result
end

-- Get achievement definition from HCA_AchievementDefs
local function GetAchievementDefinition(achId)
    if not achId or not _G.HCA_AchievementDefs then
        return nil
    end
    return _G.HCA_AchievementDefs[tostring(achId)]
end

-- Show boss requirements in tooltip
local function ShowBossRequirements(achId, requiredKills, bossOrder, achievementCompleted, def, achDef)
    if not requiredKills or next(requiredKills) == nil then
        return
    end
    
    GameTooltip:AddLine("\nRequired Bosses:", 0, 1, 0) -- Green header
    
    -- Get progress from database
    local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(achId)
    local counts = progress and progress.counts or {}
    
    -- Check if this is a raid achievement
    local isRaid = (def and def.isRaid) or (achDef and achDef.isRaid)
    
    -- Helper function to process a single boss entry
    local function processBossEntry(npcId, need)
        local done = achievementCompleted
        local bossName = ""
        
        -- Determine which boss name function to use (raid vs dungeon)
        local getBossNameFn = isRaid and _G.HCA_GetRaidBossName or _G.HCA_GetBossName
        
        -- Support both single NPC IDs and arrays of NPC IDs
        if type(need) == "table" then
            -- Array of NPC IDs - check if any of them has been killed
            local bossNames = {}
            for _, id in pairs(need) do
                local current = (counts[id] or counts[tostring(id)] or 0)
                local name = (getBossNameFn and getBossNameFn(id)) or ("Boss " .. tostring(id))
                table.insert(bossNames, name)
                if not done and current >= 1 then
                    done = true
                end
            end
            -- Use the key as display name for string keys
            if type(npcId) == "string" then
                bossName = npcId
            else
                -- For numeric keys, show all names
                bossName = table.concat(bossNames, " / ")
            end
        else
            -- Single NPC ID
            local idNum = tonumber(npcId) or npcId
            local current = (counts[idNum] or counts[tostring(idNum)] or 0)
            bossName = (getBossNameFn and getBossNameFn(idNum)) or ("Boss " .. tostring(idNum))
            if not done then
                done = current >= (tonumber(need) or 1)
            end
        end
        
        if done then
            GameTooltip:AddLine(bossName, 1, 1, 1) -- White for completed
        else
            GameTooltip:AddLine(bossName, 0.5, 0.5, 0.5) -- Gray for not completed
        end
    end
    
    -- Use ordered display if provided, otherwise use pairs
    if bossOrder then
        for _, npcId in ipairs(bossOrder) do
            local need = requiredKills[npcId]
            if need then
                processBossEntry(npcId, need)
            end
        end
    else
        for npcId, need in pairs(requiredKills) do
            processBossEntry(npcId, need)
        end
    end
end

-- Show item requirements in tooltip
local function ShowItemRequirements(requiredItems, itemOrder, achievementCompleted)
    if not requiredItems or type(requiredItems) ~= "table" or #requiredItems == 0 then
        return
    end
    
    GameTooltip:AddLine("\nRequired Items:", 0, 1, 0) -- Green header
    
    -- Use itemOrder if available, otherwise use requiredItems order
    local itemsToShow = itemOrder or requiredItems
    
    for _, itemId in ipairs(itemsToShow) do
        local itemName, itemLink = GetItemInfo(itemId)
        if not itemName then
            -- Item not cached, use fallback
            itemName = "Item " .. tostring(itemId)
        end
        
        -- Check if player has the item
        local hasItem = GetItemCount(itemId, true) > 0
        local done = achievementCompleted or hasItem
        
        if done then
            GameTooltip:AddLine(itemName or itemLink or ("Item " .. tostring(itemId)), 1, 1, 1) -- White for completed
        else
            GameTooltip:AddLine(itemName or itemLink or ("Item " .. tostring(itemId)), 0.5, 0.5, 0.5) -- Gray for not completed
        end
    end
end

-- Show meta achievement requirements in tooltip
local function ShowMetaAchievementRequirements(requiredAchievements, achievementOrder, achievementCompleted)
    if not requiredAchievements or type(requiredAchievements) ~= "table" or #requiredAchievements == 0 then
        return
    end
    
    GameTooltip:AddLine("\nRequired Achievements:", 0, 1, 0) -- Green header
    
    -- Use achievementOrder if available, otherwise use requiredAchievements order
    local achievementsToShow = achievementOrder or requiredAchievements
    
    for _, reqAchId in ipairs(achievementsToShow) do
        -- Get achievement title from HCA_AchievementDefs
        local reqAchTitle = tostring(reqAchId) -- Fallback to ID
        if _G.HCA_AchievementDefs then
            local reqAchDef = _G.HCA_AchievementDefs[tostring(reqAchId)]
            if reqAchDef and reqAchDef.title then
                reqAchTitle = reqAchDef.title
            end
        end
        -- Fallback: check AchievementPanel.achievements (for quest and profession achievements)
        if reqAchTitle == tostring(reqAchId) and _G.AchievementPanel and _G.AchievementPanel.achievements then
            for _, row in ipairs(_G.AchievementPanel.achievements) do
                local rowId = row.id or row.achId
                if rowId and tostring(rowId) == tostring(reqAchId) then
                    if row.Title and row.Title.GetText then
                        reqAchTitle = row.Title:GetText() or reqAchTitle
                    elseif row._title then
                        reqAchTitle = row._title
                    end
                    break
                end
            end
        end
        
        -- Check if required achievement is completed
        -- First check progress database
        local reqProgress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(reqAchId)
        local reqCompleted = reqProgress and reqProgress.completed
        
        -- Also check the row's completed status directly (for profession achievements and others)
        if not reqCompleted and _G.AchievementPanel and _G.AchievementPanel.achievements then
            for _, row in ipairs(_G.AchievementPanel.achievements) do
                local rowId = row.id or row.achId
                if rowId and tostring(rowId) == tostring(reqAchId) then
                    if row.completed then
                        reqCompleted = true
                    end
                    break
                end
            end
        end
        
        local done = achievementCompleted or reqCompleted
        
        if done then
            GameTooltip:AddLine(reqAchTitle, 1, 1, 1) -- White for completed
        else
            GameTooltip:AddLine(reqAchTitle, 0.5, 0.5, 0.5) -- Gray for not completed
        end
    end
end

---------------------------------------
-- Main Function
---------------------------------------

function HCA_ShowAchievementTooltip(frame, data)
    -- Extract all data from row object or data table
    local extracted = ExtractAchievementData(data)
    local title = extracted.title
    local tooltip = extracted.tooltip
    local zone = extracted.zone
    local achId = extracted.achId
    local maxLevel = extracted.maxLevel
    local points = extracted.points
    local allowSoloDouble = extracted.allowSoloDouble
    local isSecretAchievement = extracted.isSecretAchievement
    local isProfessionAchievement = extracted.isProfessionAchievement
    local def = extracted.def
    local achievementCompleted = extracted.achievementCompleted
    local requiredKills = extracted.requiredKills
    local requiredItems = extracted.requiredItems
    local itemOrder = extracted.itemOrder
    local requiredAchievements = extracted.requiredAchievements
    local achievementOrder = extracted.achievementOrder
    
    -- Check database for completion status if not already set
    if not achievementCompleted and achId then
        local getCharDB = _G.GetCharDB or _G.HardcoreAchievements_GetCharDB
        if type(getCharDB) == "function" then
            local _, cdb = getCharDB()
            if cdb and cdb.achievements then
                local record = cdb.achievements[tostring(achId)]
                if record and record.completed then
                    achievementCompleted = true
                end
            end
        end
    end
    
    -- Get achievement definition once
    local achDef = GetAchievementDefinition(achId)
    
    -- For secret achievements that are not completed, use secretPoints instead of actual points
    if isSecretAchievement and not achievementCompleted then
        -- Try to get secretPoints from extracted data first
        if extracted.secretPoints ~= nil then
            points = extracted.secretPoints
        -- Otherwise try to get it from the definition
        elseif def and def.secretPoints ~= nil then
            points = tonumber(def.secretPoints) or 0
        -- Fallback: look up from catalog if achId is available
        elseif achId and _G.Achievements then
            for _, achievementDef in ipairs(_G.Achievements) do
                if achievementDef.achId == achId and achievementDef.secretPoints ~= nil then
                    points = tonumber(achievementDef.secretPoints) or 0
                    break
                end
            end
        end
    end
    
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    
    -- Check if SSF mode is enabled and this achievement supports it
    -- Secret achievements should not show "Solo bonus"
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    if isSoloMode and allowSoloDouble and not isSecretAchievement then
        -- Show title with "Solo bonus" on the right when SSF is enabled
        local soloText = "Solo bonus"
        GameTooltip:AddDoubleLine(title, HCA_SharedUtils.GetClassColor() .. soloText .. "|r", 1, 1, 1, 0.5, 0.3, 0.9)
    else
        GameTooltip:SetText(title, 1, 1, 1)
    end
    
    -- Show level and points for achievements with level requirements (right-aligned below title, before description)
    -- Achievements without level requirements show points below the description instead
    local hasLevelRequirement = maxLevel and maxLevel > 0
    local showPointsInBody = isSecretAchievement or isProfessionAchievement or not hasLevelRequirement

    if not showPointsInBody then
        local levelText = ""
        if maxLevel and maxLevel > 0 then
            levelText = LEVEL .. " " .. maxLevel
        end
        local pointsText = ""
        if points and points > 0 then
            pointsText = ACHIEVEMENT_POINTS .. ": " .. tostring(points)
        end
        if levelText ~= "" or pointsText ~= "" then
            GameTooltip:AddDoubleLine(levelText, pointsText, 1, 1, 1, 0.6, 0.9, 0.6)
        end
    end
    
    -- Check if this is a catalog achievement (not secret) and SSF is not checked
    -- If so, append "(including all party members)" to the tooltip
    local isCatalogAchievement = false
    if _G.Achievements and achId then
        for _, achievementDef in ipairs(_G.Achievements) do
            if achievementDef.achId == achId then
                isCatalogAchievement = true
                break
            end
        end
    end
    
    local isSecret = (def and def.secret) or isSecretAchievement
    
    local requiresItemOnly = false
    if def then
        local hasQuestRequirement = def.requiredQuestId ~= nil
        local hasKillRequirement = def.requiredKills ~= nil
        local hasTargetNpc = def.targetNpcId ~= nil
        local hasCustomTriggers = def.customKill or def.customSpell or def.customEmote or def.customEvent
        if def.customIsCompleted and not hasQuestRequirement and not hasKillRequirement and not hasTargetNpc and not hasCustomTriggers then
            requiresItemOnly = true
        end
    end
    
    if isCatalogAchievement and not isSecret and not isProfessionAchievement and not isSoloMode and (_G.IsLevelMilestone and not _G.IsLevelMilestone(achId)) and not requiresItemOnly then
        tooltip = tooltip .. "|cffffd100 (including all party members)|r"
    end
    
    GameTooltip:AddLine(tooltip, nil, nil, nil, true)
    
    -- For achievements without level requirements (secret, profession, or no level), show points below the description
    if showPointsInBody then
        if points and points > 0 then
            local pointsText = ACHIEVEMENT_POINTS .. ": " .. tostring(points)
            GameTooltip:AddLine(pointsText, 0.6, 0.9, 0.6)
        end
    end
    
    -- Show zone (if not a dungeon achievement)
    if zone then
        local isDungeonAchievement = achDef and achDef.mapID
        if not isDungeonAchievement then
            GameTooltip:AddLine(zone, 0.6, 1, 0.86)
        end
    end
    
    -- Update requirements from achievement definition if available
    if achDef then
        if achDef.mapID then
            -- Dungeon achievement - get requiredKills and bossOrder
            if achDef.requiredKills then
                requiredKills = achDef.requiredKills
            end
        end
        -- Check for requiredItems in HCA_AchievementDefs (for dungeon sets)
        if achDef.requiredItems then
            requiredItems = achDef.requiredItems
        end
        if achDef.itemOrder then
            itemOrder = achDef.itemOrder
        end
        -- Check for meta achievement requirements
        if achDef.isMetaAchievement then
            if achDef.requiredAchievements then
                requiredAchievements = achDef.requiredAchievements
            end
            if achDef.achievementOrder then
                achievementOrder = achDef.achievementOrder
            end
        end
    end
    
    -- Also check def for requirements
    if def then
        if def.requiredItems then
            requiredItems = def.requiredItems
        end
        if def.itemOrder then
            itemOrder = def.itemOrder
        end
        if def.requiredAchievements then
            requiredAchievements = def.requiredAchievements
        end
        if def.achievementOrder then
            achievementOrder = def.achievementOrder
        end
    end
    
    -- Show boss requirements if available
    local bossOrder = achDef and achDef.bossOrder
    ShowBossRequirements(achId, requiredKills, bossOrder, achievementCompleted, def, achDef)
    
    -- Show item requirements if available
    ShowItemRequirements(requiredItems, itemOrder, achievementCompleted)
    
    -- Show meta achievement requirements if available
    ShowMetaAchievementRequirements(requiredAchievements, achievementOrder, achievementCompleted)
    
    -- Hint for linking the achievement in chat
    GameTooltip:AddLine("\nShift click to link in chat\nor add to tracking list", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end
_G.HCA_ShowAchievementTooltip = HCA_ShowAchievementTooltip

