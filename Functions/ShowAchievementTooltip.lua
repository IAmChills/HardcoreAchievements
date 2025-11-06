-- Centralized function to show achievement tooltip
-- Can be called from main window or embed UI
function HCA_ShowAchievementTooltip(frame, data)
    -- data can be a row object or a table with achievement data
    local row = data
    local title = ""
    local tooltip = ""
    local zone = nil
    local achId = nil
    local maxLevel = nil
    local points = nil
    local allowSoloDouble = false
    local isSecretAchievement = false
    local def = nil
    
    -- Extract data from row object or data table
    if type(data) == "table" then
        -- Check if it's a row object (has Title)
        if data.Title and data.Title.GetText then
            title = data.Title:GetText() or data._title or ""
            tooltip = data.tooltip or data._tooltip or ""
            zone = data.zone or data._zone
            achId = data.achId or data.id or data._achId
            maxLevel = data.maxLevel
            points = data.points
            allowSoloDouble = data.allowSoloDouble or false
            isSecretAchievement = data.isSecretAchievement or false
            def = data._def
        else
            -- It's a data table
            title = data.title or ""
            tooltip = data.tooltip or ""
            zone = data.zone
            achId = data.achId or data.id
            maxLevel = data.maxLevel
            points = data.points
            allowSoloDouble = data.allowSoloDouble or false
            isSecretAchievement = data.isSecretAchievement or false
        end
    end
    
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    
    -- Check if SSF mode is enabled and this achievement supports it
    -- Secret achievements should not show "Solo bonus"
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    if isSoloMode and allowSoloDouble and not isSecretAchievement then
        -- Show title with "Solo bonus" on the right when SSF is enabled
        local soloText = "Solo bonus"
        GameTooltip:AddDoubleLine(title, "|cFFac81d6" .. soloText .. "|r", 1, 1, 1, 0.5, 0.3, 0.9)
    else
        GameTooltip:SetText(title, 1, 1, 1)
    end
    
    -- Show level and points for non-secret achievements (right-aligned below title, before description)
    -- Secret achievements show points below the description instead
    if not isSecretAchievement then
        local levelText = ""
        if maxLevel and maxLevel > 0 then
            levelText = LEVEL .. " " .. maxLevel
        end
        local pointsText = ""
        if points and points > 0 then
            pointsText = tostring(points)
        end
        if levelText ~= "" or pointsText ~= "" then
            GameTooltip:AddDoubleLine(levelText, "Points: " .. pointsText, 1, 1, 1, 0.6, 0.9, 0.6)
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
    local isSoloModeChecked = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    
    if isCatalogAchievement and not isSecret and not isSoloModeChecked and (_G.IsLevelMilestone and not _G.IsLevelMilestone(achId)) then
        tooltip = tooltip .. "|cffFFD700 (including all party members)|r"
    end
    
    GameTooltip:AddLine(tooltip, nil, nil, nil, true)
    
    -- For secret achievements, show points below the description instead of with level
    if isSecretAchievement then
        local pointsText = ""
        if points and points > 0 then
            pointsText = "Points: " .. tostring(points)
            GameTooltip:AddLine(pointsText, 0.6, 0.9, 0.6)
        end
    end
    
    if zone then
        GameTooltip:AddLine(zone, 0.6, 1, 0.86)
    end
    
    -- Check if this is a dungeon achievement (has requiredKills) and show boss requirements
    local requiredKills = nil
    local bossOrder = nil
    
    -- Try to get requiredKills from the row object or data table
    if type(data) == "table" then
        if data.Title and data.Title.GetText then
            -- It's a row object
            requiredKills = data.requiredKills
        else
            -- It's a data table
            requiredKills = data.requiredKills
        end
    end
    
    -- Also check HCA_AchievementDefs for dungeon achievement definition
    local isDungeonAchievement = false
    if achId and _G.HCA_AchievementDefs then
        local achDef = _G.HCA_AchievementDefs[tostring(achId)]
        if achDef and achDef.mapID then
            isDungeonAchievement = true
            if achDef.requiredKills then
                requiredKills = achDef.requiredKills
            end
        end
    end
    
    -- If we have requiredKills, show boss requirements
    if requiredKills and next(requiredKills) ~= nil then
        GameTooltip:AddLine("\nRequired Bosses:", 0, 1, 0) -- Green header
        
        -- Get progress from database
        local progress = _G.HardcoreAchievements_GetProgress and _G.HardcoreAchievements_GetProgress(achId)
        local counts = progress and progress.counts or {}
        
        -- Helper function to process a single boss entry
        local function processBossEntry(npcId, need)
            local done = false
            local bossName = ""
            
            -- Support both single NPC IDs and arrays of NPC IDs
            if type(need) == "table" then
                -- Array of NPC IDs - check if any of them has been killed
                local anyKilled = false
                local bossNames = {}
                for _, id in pairs(need) do
                    local current = (counts[id] or counts[tostring(id)] or 0)
                    local name = (_G.HCA_GetBossName and _G.HCA_GetBossName(id)) or ("Boss " .. tostring(id))
                    table.insert(bossNames, name)
                    if current >= 1 then
                        anyKilled = true
                    end
                end
                done = anyKilled
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
                bossName = (_G.HCA_GetBossName and _G.HCA_GetBossName(idNum)) or ("Boss " .. tostring(idNum))
                done = current >= (tonumber(need) or 1)
            end
            
            if done then
                GameTooltip:AddLine(bossName, 1, 1, 1) -- White for completed
            else
                GameTooltip:AddLine(bossName, 0.5, 0.5, 0.5) -- Gray for not completed
            end
        end
        
        -- Get bossOrder from achievement definition
        local achDef = achId and _G.HCA_AchievementDefs and _G.HCA_AchievementDefs[tostring(achId)]
        if achDef then
            bossOrder = achDef.bossOrder
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
    
    -- Hint for linking the achievement in chat
    GameTooltip:AddLine("\nShift + Left Click to link in chat", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end
_G.HCA_ShowAchievementTooltip = HCA_ShowAchievementTooltip

