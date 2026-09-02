-- Centralized function to show achievement tooltip
-- Can be called from main window or embed UI
local addonName, addon = ...
local GameTooltip = GameTooltip
local GetItemInfo = GetItemInfo
local GetItemCount = GetItemCount
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local type = type
local table_insert = table.insert
local table_concat = table.concat

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
        acceptAnyVariation = false,
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
        result.def = data._def
        if data.allowSoloDouble ~= nil then
            result.allowSoloDouble = data.allowSoloDouble and true or false
        elseif result.def and result.def.allowSoloDouble ~= nil then
            result.allowSoloDouble = result.def.allowSoloDouble and true or false
        else
            result.allowSoloDouble = (data.killTracker ~= nil) and true or false
        end
        result.isSecretAchievement = data.isSecretAchievement or (data._def and data._def.secret) or data.secret or false
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
        result.def = data._def or data.def
        if data.allowSoloDouble ~= nil then
            result.allowSoloDouble = data.allowSoloDouble and true or false
        elseif result.def and result.def.allowSoloDouble ~= nil then
            result.allowSoloDouble = result.def.allowSoloDouble and true or false
        else
            result.allowSoloDouble = (data.killTracker ~= nil or data.targetNpcId ~= nil) and true or false
        end
        result.isSecretAchievement = data.isSecretAchievement or data.secret or false
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
    result.acceptAnyVariation = getValue("acceptAnyVariation") == true
    
    return result
end

-- Get achievement definition from AchievementDefs
local function GetAchievementDefinition(achId)
    if not achId or not (addon and addon.AchievementDefs) then
        return nil
    end
    return addon.AchievementDefs[tostring(achId)]
end

-- Show boss/NPC requirements in tooltip
local function ShowBossRequirements(achId, requiredKills, bossOrder, achievementCompleted, def, achDef)
    if not requiredKills or next(requiredKills) == nil then
        return
    end

    local header = (addon and addon.GetRequiredKillHeader and addon.GetRequiredKillHeader(achDef, def)) or "Required Bosses"
    GameTooltip:AddLine("\n" .. header .. ":", 0, 1, 0) -- Green header

    local isRaid = (def and def.isRaid) or (achDef and achDef.isRaid)
    local entries = nil
    if addon and addon.BuildRequiredKillEntries then
        entries = addon.BuildRequiredKillEntries(achId, requiredKills, {
            achDef = achDef,
            def = def,
            bossOrder = bossOrder,
            achievementCompleted = achievementCompleted,
            isRaid = isRaid,
        })
    end

    if entries then
        for i = 1, #entries do
            local entry = entries[i]
            if entry.done then
                GameTooltip:AddLine(entry.text, 1, 1, 1) -- White for completed
            else
                GameTooltip:AddLine(entry.text, 0.5, 0.5, 0.5) -- Gray for not completed
            end
        end
    end

    -- Self-policing: show average party level recorded at dungeon entry
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
    if progress and progress.avgPartyLevel then
        local sizeText = progress.entryPartySize and (" (" .. tostring(progress.entryPartySize) .. " players)") or ""
        GameTooltip:AddLine("Avg party level on entry: " .. tostring(progress.avgPartyLevel) .. sizeText, 0.75, 0.75, 0.75)
    end
end

-- Show item requirements in tooltip
local function ShowItemRequirements(requiredItems, itemOrder, achievementCompleted, achId)
    if not requiredItems or type(requiredItems) ~= "table" or #requiredItems == 0 then
        return
    end
    
    GameTooltip:AddLine("\nRequired Items:", 0, 1, 0) -- Green header
    
    -- Use itemOrder if available, otherwise use requiredItems order
    local itemsToShow = itemOrder or requiredItems
    local itemOwned = nil
    if achId and addon and addon.GetProgress then
        local progress = addon.GetProgress(achId)
        if progress and type(progress.itemOwned) == "table" then
            itemOwned = progress.itemOwned
        end
    end
    
    for _, itemId in ipairs(itemsToShow) do
        local itemName, itemLink = GetItemInfo(itemId)
        if (not itemName or itemName == "") and addon and addon.GetItemName then
            itemName = addon.GetItemName(itemId)
        end
        if not itemName or itemName == "" then
            itemName = "Item " .. tostring(itemId)
        end
        
        -- Inventory, or once-owned dungeon-set progress (item may have been sold)
        local hasItem = GetItemCount(itemId, true) > 0
            or (itemOwned and (itemOwned[itemId] or itemOwned[tostring(itemId)]))
        local done = achievementCompleted or hasItem
        
        if done then
            GameTooltip:AddLine(itemName or itemLink or ("Item " .. tostring(itemId)), 1, 1, 1) -- White for completed
        else
            GameTooltip:AddLine(itemName or itemLink or ("Item " .. tostring(itemId)), 0.5, 0.5, 0.5) -- Gray for not completed
        end
    end
end

-- Show meta achievement requirements in tooltip
-- headerLine: optional green header (default "\nRequired Achievements:")
-- acceptAnyVariation: if true, base dungeon counts complete when any Trio/Duo/Solo variation is done
local function ShowMetaAchievementRequirements(requiredAchievements, achievementOrder, achievementCompleted, headerLine, acceptAnyVariation)
    if not requiredAchievements or type(requiredAchievements) ~= "table" or #requiredAchievements == 0 then
        return
    end
    
    GameTooltip:AddLine(headerLine or "\nRequired Achievements:", 0, 1, 0) -- Green header
    
    -- Use achievementOrder if available, otherwise use requiredAchievements order
    local achievementsToShow = achievementOrder or requiredAchievements
    
    for _, reqAchId in ipairs(achievementsToShow) do
        -- Get achievement title from AchievementDefs
        local reqAchTitle = tostring(reqAchId) -- Fallback to ID
        if addon and addon.AchievementDefs then
            local reqAchDef = addon.AchievementDefs[tostring(reqAchId)]
            if reqAchDef and reqAchDef.title then
                reqAchTitle = reqAchDef.title
            end
        end
        local reqRow = (addon and addon.GetAchievementRow and addon.GetAchievementRow(reqAchId)) or nil

        -- Fallback: check the loaded row/model for quest and profession achievements.
        if reqAchTitle == tostring(reqAchId) and reqRow then
            if reqRow.Title and reqRow.Title.GetText then
                reqAchTitle = reqRow.Title:GetText() or reqAchTitle
            elseif reqRow._title then
                reqAchTitle = reqRow._title
            elseif reqRow.title then
                reqAchTitle = reqRow.title
            end
        end
        
        -- Check if required achievement is completed, failed (outleveled), or still available
        local reqCompleted = false
        local reqFailed = false
        if addon and addon.IsMetaRequirementCompleted then
            reqCompleted = addon.IsMetaRequirementCompleted(reqAchId, acceptAnyVariation)
            reqFailed = (not reqCompleted) and addon.IsMetaRequirementFailed and addon.IsMetaRequirementFailed(reqAchId, acceptAnyVariation)
        else
            local reqProgress = addon and addon.GetProgress and addon.GetProgress(reqAchId)
            reqCompleted = reqProgress and reqProgress.completed
            if reqRow and reqRow.completed then
                reqCompleted = true
            end
            if not reqCompleted and addon and addon.IsRowOutleveled and reqRow and addon.IsRowOutleveled(reqRow) then
                reqFailed = true
            end
            if not reqFailed and not reqCompleted and not reqRow and addon and addon.GetCharDB then
                local _, cdb = addon.GetCharDB()
                local rec = cdb and cdb.achievements and cdb.achievements[tostring(reqAchId)]
                if rec and rec.failed then
                    reqFailed = true
                end
            end
        end

        if reqCompleted then
            GameTooltip:AddLine(reqAchTitle, 1, 1, 1) -- White for completed
        elseif reqFailed then
            GameTooltip:AddLine("|cffff4444" .. reqAchTitle .. "|r", 1, 1, 1) -- Red for failed (color in text for visibility)
        else
            GameTooltip:AddLine(reqAchTitle, 0.5, 0.5, 0.5) -- Gray for available
        end
    end
end

local function ShowExplorationRequirements(explorationZone)
    if not explorationZone or not addon or type(addon.GetZoneDiscoveryDetails) ~= "function" then
        return
    end

    local details, err = addon.GetZoneDiscoveryDetails(explorationZone)
    if err or not details or #details == 0 then
        return
    end

    GameTooltip:AddLine("\nRequired Areas:", 0, 1, 0)

    for _, info in ipairs(details) do
        local label = tostring(info.name or "Unknown")
        if info.discovered then
            GameTooltip:AddLine(label, 1, 1, 1)
        else
            GameTooltip:AddLine(label, 0.5, 0.5, 0.5)
        end
    end
end

---------------------------------------
-- Shared completion-rate line (character-frame custom tooltips + main tooltip)
---------------------------------------

local function AddAchievementCompletionRateToTooltip(achId)
    if not achId or not addon or not addon.Leaderboard or not addon.Leaderboard.GetAchievementCompletionStats then
        return
    end
    local have, total = addon.Leaderboard.GetAchievementCompletionStats(achId)
    if type(total) ~= "number" or total <= 0 then
        return
    end
    local pct = math.floor(((tonumber(have) or 0) / total) * 100 + 0.5)
    GameTooltip:AddLine(
        string.format("\n%d%% of eligible players have this achievement (%d/%d)", pct, tonumber(have) or 0, total),
        0.0, 0.502, 0.4,
        true
    )
end

---------------------------------------
-- Main Function
---------------------------------------

local function ShowAchievementTooltip(frame, data)
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
    local acceptAnyVariation = extracted.acceptAnyVariation
    local explorationZone = nil
    
    -- Check database for completion status if not already set
    if not achievementCompleted and achId then
        local getCharDB = addon and addon.GetCharDB
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
    local isGuildFirst = (def and def.isGuildFirst) or (achDef and achDef.isGuildFirst) or false
    
    local isSecret = (isSecretAchievement or (def and def.secret) or (achDef and achDef.secret) or false) and not isGuildFirst
    local isMetaAchievement = (def and (def.isMetaAchievement or def.isMeta or def.requiredAchievements ~= nil))
        or (achDef and (achDef.isMetaAchievement or achDef.isMeta or achDef.requiredAchievements ~= nil))
        or (requiredAchievements ~= nil)
        or false

    -- For secret achievements that are not completed, use secretPoints instead of actual points
    if isSecret and not achievementCompleted then
        -- Try to get secretPoints from extracted data first
        if extracted.secretPoints ~= nil then
            points = extracted.secretPoints
        -- Otherwise try to get it from the definition
        elseif def and def.secretPoints ~= nil then
            points = tonumber(def.secretPoints) or 0
        -- Fallback: look up from catalog if achId is available
        elseif achId and addon and addon.CatalogAchievements then
            for _, achievementDef in ipairs(addon.CatalogAchievements) do
                if achievementDef.achId == achId and achievementDef.secretPoints ~= nil then
                    points = tonumber(achievementDef.secretPoints) or 0
                    break
                end
            end
        end
    end

    -- Incomplete secrets: never show reveal title/tooltip (dashboard may pass model rows with stale strings).
    if isSecret and not achievementCompleted then
        local secTip = (def and def.secretTooltip) or (achDef and achDef.secretTooltip)
        if type(data) == "table" and type(data.secretTooltip) == "string" and data.secretTooltip ~= "" then
            secTip = secTip or data.secretTooltip
        end
        if type(secTip) == "string" and secTip ~= "" then
            tooltip = secTip
        end
        local secTitle = (def and def.secretTitle) or (achDef and achDef.secretTitle)
        if type(data) == "table" and type(data.secretTitle) == "string" and data.secretTitle ~= "" then
            secTitle = secTitle or data.secretTitle
        end
        if type(secTitle) == "string" and secTitle ~= "" then
            title = secTitle
        end
    end
    
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    
    -- Prefer stored completion points / wasSolo for the tooltip
    local wasSoloCompleted = false
    if achievementCompleted and achId and addon and addon.GetCharDB then
        local _, cdb = addon.GetCharDB()
        local rec = cdb and cdb.achievements and (cdb.achievements[tostring(achId)] or cdb.achievements[achId])
        if rec then
            wasSoloCompleted = rec.wasSolo and true or false
            if rec.points ~= nil then
                points = tonumber(rec.points) or points
            end
        end
    end
    -- Resolve allowSoloDouble from def when the row omitted it (Dashboard fallback used to force false)
    if not allowSoloDouble and def and def.allowSoloDouble then
        allowSoloDouble = true
    end

    -- Match under-level status text:
    -- completed + wasSolo => "Solo"
    -- incomplete + Solo checkbox + allowSoloDouble => "Solo bonus"
    -- completed non-solo => no solo text
    -- Secret/meta never show solo preview text.
    local isSoloMode = (addon and addon.IsSoloModeEnabled and addon.IsSoloModeEnabled()) or false
    local ClassColor = (addon and addon.GetClassColor())
    if achievementCompleted and wasSoloCompleted and not isSecret and not isMetaAchievement then
        GameTooltip:AddDoubleLine(title, ClassColor .. "Solo|r", 1, 1, 1, 0.5, 0.3, 0.9)
    elseif (not achievementCompleted) and isSoloMode and allowSoloDouble and not isSecret and not isMetaAchievement then
        GameTooltip:AddDoubleLine(title, ClassColor .. "Solo bonus|r", 1, 1, 1, 0.5, 0.3, 0.9)
    else
        GameTooltip:SetText(title, 1, 1, 1)
    end
    
    -- Show level and points for achievements with level requirements (right-aligned below title, before description)
    -- Achievements without level requirements show points below the description instead
    local hasLevelRequirement = maxLevel and maxLevel > 0
    local showPointsInBody = isSecret or isProfessionAchievement or not hasLevelRequirement

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
    if addon and addon.CatalogAchievements and achId then
        for _, achievementDef in ipairs(addon.CatalogAchievements) do
            if achievementDef.achId == achId then
                isCatalogAchievement = true
                break
            end
        end
    end
    
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
    
    if isCatalogAchievement and not isSecret and not isProfessionAchievement and not isSoloMode and (addon and addon.IsLevelMilestone and not addon.IsLevelMilestone(achId)) and not requiresItemOnly then
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
        -- Check for requiredItems in AchievementDefs (for dungeon sets)
        if achDef.requiredItems then
            requiredItems = achDef.requiredItems
        end
        if achDef.itemOrder then
            itemOrder = achDef.itemOrder
        end
        -- Meta / continent exploration: merge ordered child achievements from defs
        if achDef.requiredAchievements then
            requiredAchievements = achDef.requiredAchievements
        end
        if achDef.achievementOrder then
            achievementOrder = achDef.achievementOrder
        end
        if achDef.acceptAnyVariation then
            acceptAnyVariation = true
        end
        if achDef.explorationZone then
            explorationZone = achDef.explorationZone
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
        if def.acceptAnyVariation then
            acceptAnyVariation = true
        end
        if def.explorationZone then
            explorationZone = def.explorationZone
        end
    end
    
    -- Show boss requirements if available
    local bossOrder = achDef and achDef.bossOrder
    ShowBossRequirements(achId, requiredKills, bossOrder, achievementCompleted, def, achDef)
    
    -- Show item requirements if available
    ShowItemRequirements(requiredItems, itemOrder, achievementCompleted, achId)
    
    -- Show meta achievement requirements if available (continent exploration uses zone-style header)
    local useZoneListHeader = (achDef and achDef.isContinentExploration) or (def and def.isContinentExploration)
    ShowMetaAchievementRequirements(
        requiredAchievements,
        achievementOrder,
        achievementCompleted,
        useZoneListHeader and "\nRequired Zones:" or nil,
        acceptAnyVariation
    )

    -- Show exploration subzone requirements if available
    ShowExplorationRequirements(explorationZone)

    -- Hint for linking the achievement in chat
    GameTooltip:AddLine("\nShift click to link in chat or add to tracking list", 0.5, 0.5, 0.5, true)

    -- Community completion rate from leaderboard reporters on 1.9.5+
    AddAchievementCompletionRateToTooltip(achId)

    GameTooltip:Show()
end

-- Bind character-frame row hover to the centralized tooltip (highlight + optional pre-show hook).
local function BindAchievementRowTooltip(frame, options)
    if not frame or not frame.SetScript then
        return
    end
    options = options or {}
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self.highlight then
            if self.highlight.SetVertexColor then
                self.highlight:SetVertexColor(1, 1, 1, 0.75)
            end
            self.highlight:Show()
        end
        if type(options.beforeShow) == "function" then
            pcall(options.beforeShow, self)
        end
        if self.Title and self.Title.GetText and ShowAchievementTooltip then
            ShowAchievementTooltip(self, options.data or self)
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if self.highlight then
            self.highlight:Hide()
        end
        GameTooltip:Hide()
    end)
end

if addon then
    addon.ShowAchievementTooltip = ShowAchievementTooltip
    addon.AddAchievementCompletionRateToTooltip = AddAchievementCompletionRateToTooltip
    addon.BindAchievementRowTooltip = BindAchievementRowTooltip
end