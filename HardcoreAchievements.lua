local ADDON_NAME, addon = ...
local playerGUID
HCA_SELF_FOUND_BONUS = 5
local SETTINGS_ICON_TEXTURE = "Interface\\AddOns\\HardcoreAchievements\\Images\\icon_gear.png"

local EvaluateCustomCompletions
local RefreshOutleveledAll
local ProfessionTracker = _G.HCA_ProfessionCommon
local QuestTrackedRows = {}

-- Load AchievementTracker module (loaded via TOC, accessed lazily)
local function GetAchievementTracker()
    return _G.HardcoreAchievementsTracker
end

local function TrackRowForQuest(row, questID)
    local qid = tonumber(questID or row and row.requiredQuestId)
    if not qid or not row then return end
    QuestTrackedRows[qid] = QuestTrackedRows[qid] or {}
    table.insert(QuestTrackedRows[qid], row)
    row.requiredQuestId = qid
end

local function UntrackRowForQuest(row)
    if not row or not row.requiredQuestId then return end
    local qid = row.requiredQuestId
    local bucket = QuestTrackedRows[qid]
    if not bucket then return end
    for i = #bucket, 1, -1 do
        if bucket[i] == row or not bucket[i] then
            table.remove(bucket, i)
        end
    end
    if #bucket == 0 then
        QuestTrackedRows[qid] = nil
    end
end

-- Create/initialize addon table and expose globally (similar to BugSack pattern)
if not addon then
    addon = {}
end
_G[ADDON_NAME] = addon

local function EnsureDB()
    HardcoreAchievementsDB = HardcoreAchievementsDB or {}
    HardcoreAchievementsDB.chars = HardcoreAchievementsDB.chars or {}
    return HardcoreAchievementsDB
end

local function GetCharDB()
    local db = EnsureDB()
    if not playerGUID then return db, nil end
    db.chars[playerGUID] = db.chars[playerGUID] or {
        meta = {},            -- name/realm/class/race/level/faction/lastLogin
		achievements = {},    -- [id] = { completed=true, completedAt=time(), level=nn, mapID=123 }
		progress = {},
        settings = {},
    }
    return db, db.chars[playerGUID]
end

-- Cleanup function to remove incorrectly completed level bracket achievements
-- Fixes a bug where players could earn level achievements at the wrong level
local function CleanupIncorrectLevelAchievements()
    local _, cdb = GetCharDB()
    if not cdb or not cdb.achievements then
        return
    end
    
    local cleanedCount = 0
    local cleanedAchievements = {}
    
    -- Check each completed achievement
    for achId, achievementData in pairs(cdb.achievements) do
        -- Only check level bracket achievements (Level10, Level20, Level30, etc.)
        if achId and type(achId) == "string" and string.match(achId, "^Level%d+$") then
            -- Extract the required level from the achievement ID (e.g., "Level30" -> 30)
            local requiredLevel = tonumber(string.match(achId, "Level(%d+)"))
            
            if requiredLevel and achievementData.completed and achievementData.level then
                local completionLevel = achievementData.level
                
                -- If the completion level doesn't match the required level, remove it
                if completionLevel < requiredLevel then
                    -- Store for logging
                    table.insert(cleanedAchievements, {
                        achId = achId,
                        requiredLevel = requiredLevel,
                        completionLevel = completionLevel
                    })
                    
                    -- Remove the achievement from database
                    cdb.achievements[achId] = nil
                    cleanedCount = cleanedCount + 1
                end
            end
        end
    end
    
    -- Log cleanup if any achievements were removed
    if cleanedCount > 0 then
        local message = "|cff69adc9[Hardcore Achievements]|r |cffffd100Cleaned up " .. cleanedCount .. " incorrectly completed achievement(s):|r"
        print(message)
        for _, cleaned in ipairs(cleanedAchievements) do
            print(string.format("  |cffffd100- %s (completed at level %d, required level %d)|r", 
                cleaned.achId, cleaned.completionLevel, cleaned.requiredLevel))
        end
        print("|cffffd100I am chasing a weird bug, thank you for your patience. - |r|cff69adc9Chills|r")
    end
    
    return cleanedCount
end

local function ClearProgress(achId)
    local _, cdb = GetCharDB()
    if cdb and cdb.progress then cdb.progress[achId] = nil end
end

-- =========================================================
-- Row Border Color Helper
-- =========================================================

-- Helper function to strip color codes from text (for shadow text)
local function StripColorCodes(text)
    if not text or type(text) ~= "string" then return text end
    -- Remove |cAARRGGBB color start codes and |r color end codes
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function HasVisibleText(value)
    if type(value) ~= "string" then
        return false
    end
    return value:match("%S") ~= nil
end

local function UpdateRowTextLayout(row)
    if not row or not row.Icon or not row.Title or not row.Sub then
        return
    end

    local hasSubText = HasVisibleText(row.Sub:GetText())

    row.Title:ClearAllPoints()
    row.Sub:ClearAllPoints()
    if row.TitleShadow then
        row.TitleShadow:ClearAllPoints()
    end

    if hasSubText then
        local text = row.Sub:GetText()
        local extraLines = 0
        if text and text ~= "" then
            local _, newlines = text:gsub("\n", "")
            extraLines = math.max(0, newlines)
        end
        local yOffset = 11 + (extraLines * 5)
        row.Title:SetPoint("TOPLEFT", row.Icon, "RIGHT", 8, yOffset)
        row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -1)
        row.Sub:Show()
    else
        row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
        row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
        row.Sub:Hide()
    end

    if row.TitleShadow then
        row.TitleShadow:SetPoint("LEFT", row.Title, "LEFT", 1, -1)
    end
end

local function HookRowSubTextUpdates(row)
    if not row or not row.Sub or row.Sub._hcaSetTextWrapped then
        return
    end

    local fontString = row.Sub
    local originalSetText = fontString.SetText
    local originalSetFormattedText = fontString.SetFormattedText

    fontString.SetText = function(self, text, ...)
        originalSetText(self, text, ...)
        UpdateRowTextLayout(row)
    end

    fontString.SetFormattedText = function(self, ...)
        originalSetFormattedText(self, ...)
        UpdateRowTextLayout(row)
    end

    fontString._hcaSetTextWrapped = true
end

-- Helper function to check if a quest is in the player's quest log
local function IsQuestInQuestLog(questID)
    if not questID then return false end
    -- Try modern API first
    if GetQuestLogIndexByID then
        local logIndex = GetQuestLogIndexByID(questID)
        if logIndex and logIndex > 0 then
            return true
        end
    end
    -- Fallback: check using classic API
    if GetNumQuestLogEntries then
        local numEntries = GetNumQuestLogEntries()
        for i = 1, numEntries do
            local title, level, suggestGroup, isHeader, isCollapsed, isComplete, frequency, questIDFromLog = GetQuestLogTitle(i)
            if not isHeader and questIDFromLog == questID then
                return true
            end
        end
    end
    return false
end

local function IsRowOutleveled(row)
    if not row or row.completed then return false end
    
    -- Additional safeguard: check database to ensure completed achievements are never marked as failed
    local achId = row.achId or row.id
    if achId then
        local _, cdb = GetCharDB()
        if cdb and cdb.achievements and cdb.achievements[achId] and cdb.achievements[achId].completed then
            return false -- Achievement is completed in database, never mark as failed
        end
    end
    
    if not row.maxLevel then return false end
    
    local lvl = UnitLevel("player") or 1
    local isOverLevel = lvl > row.maxLevel
    
    -- Check if there's pending turn-in progress (kill completed but quest not turned in)
    -- If so, check if quest is still in quest log - if not, mark as failed
    if row.questTracker and (row.killTracker or row.requiredKills) then
        -- Achievement requires both kill and quest
        local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
        if progress then
            local hasKill = false
            if row.requiredKills then
                -- Check if all required kills are satisfied
                if progress.eligibleCounts then
                    local allSatisfied = true
                    for npcId, requiredCount in pairs(row.requiredKills) do
                        local idNum = tonumber(npcId) or npcId
                        local current = progress.eligibleCounts[idNum] or progress.eligibleCounts[tostring(idNum)] or 0
                        local required = tonumber(requiredCount) or 1
                        if current < required then
                            allSatisfied = false
                            break
                        end
                    end
                    hasKill = allSatisfied
                end
            else
                -- Single kill achievement
                hasKill = progress.killed or false
            end
            
            local questNotTurnedIn = not progress.quest
            -- If kills are satisfied but quest is not turned in
            if hasKill and questNotTurnedIn then
                -- Get quest ID from row definition
                local questID = nil
                if row._def and row._def.requiredQuestId then
                    questID = row._def.requiredQuestId
                end
                
                -- If player is over level and quest is not in quest log (abandoned), fail the achievement
                if isOverLevel and questID and not IsQuestInQuestLog(questID) then
                    return true -- Mark as outleveled/failed
                end
                
                -- If quest is still in quest log, keep achievement available
                if questID and IsQuestInQuestLog(questID) then
                    return false
                end
            end
        end
    end
    
    return isOverLevel
end

-- Function to update row border color based on state
local function UpdateRowBorderColor(row)
    if not row or not row.Border then return end
    
    if row.completed then
        row.Border:SetVertexColor(0.6, 0.9, 0.6)
        if row.Background then
            row.Background:SetVertexColor(0.1, 1.0, 0.1)
            row.Background:SetAlpha(1)
        end
    elseif IsRowOutleveled(row) then
        row.Border:SetVertexColor(0.957, 0.263, 0.212)
        if row.Background then
            row.Background:SetVertexColor(1.0, 0.1, 0.1)
            row.Background:SetAlpha(1)
        end
    else
        row.Border:SetVertexColor(0.8, 0.8, 0.8)
        if row.Background then
            row.Background:SetVertexColor(1, 1, 1)
            row.Background:SetAlpha(1)
        end
    end
end

-- Function to position border relative to row
local function PositionRowBorder(row)
    if not row or not row.Border or not row:IsShown() then 
        if row and row.Border then row.Border:Hide() end
        if row and row.Background then row.Background:Hide() end
        return 
    end
    
    row.Border:ClearAllPoints()
    row.Border:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
    row.Border:SetSize(295, 43)
    row.Border:Show()
    
    if row.Background then
        row.Background:ClearAllPoints()
        row.Background:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
        row.Background:SetSize(295, 43)
        row.Background:Show()
    end

    if row.highlight then
        row.highlight:ClearAllPoints()
        row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
        row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -20, -1)
    end
end

-- Format timestamp into readable date/time string (locale-aware format)
function FormatTimestamp(timestamp)
    if not timestamp then return "" end
    
    local dateInfo = date("*t", timestamp)
    local locale = GetLocale()
    
    -- US locale uses mm/dd/yy, most others use dd/mm/yy
    if locale == "enUS" then
        -- US format: mm/dd/yy
        return string.format("%02d/%02d/%02d", 
            dateInfo.month, 
            dateInfo.day, 
            dateInfo.year % 100)
    else
        -- European/International format: dd/mm/yy
        return string.format("%02d/%02d/%02d", 
            dateInfo.day, 
            dateInfo.month, 
            dateInfo.year % 100)
    end
end

local function EnsureFailureTimestamp(achId)
    if not achId then return nil end
    local _, cdb = GetCharDB()
    if not cdb then return nil end
    cdb.achievements = cdb.achievements or {}
    local rec = cdb.achievements[achId]
    if not rec then
        rec = {}
        cdb.achievements[achId] = rec
    end
    if not rec.completed and not rec.failedAt then
        rec.failedAt = time()
    end
    if rec.failedAt and not rec.failed then
        rec.failed = true
    end
    return rec.failedAt
end

local function GetFailureTimestamp(achId)
    if not achId then return nil end
    local _, cdb = GetCharDB()
    if not cdb or not cdb.achievements then return nil end
    local rec = cdb.achievements[achId]
    if rec and rec.failedAt then
        if not rec.failed then
            rec.failed = true
        end
        return rec.failedAt
    end
    return nil
end

_G.HCA_GetFailureTimestamp = GetFailureTimestamp
_G.HCA_EnsureFailureTimestamp = EnsureFailureTimestamp
_G.FormatTimestamp = FormatTimestamp
_G.IsRowOutleveled = IsRowOutleveled

-- Export function for embedded UI to get total points
function HCA_GetTotalPoints()
    local total = 0
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.completed and (row.points or 0) > 0 then
                total = total + row.points
            end
        end
    end
    return total
end

-- Export function to get achievement count data
function HCA_AchievementCount()
    local completed = 0
    local total = 0
    
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            local hiddenByProfession = row.hiddenByProfession
            local hiddenUntilComplete = row.hiddenUntilComplete and not row.completed
            
            -- Exclude variation achievements from the count UNLESS they are completed
            -- This prevents incomplete variations from inflating the total, but includes
            -- completed variations so the completed count doesn't exceed the total
            -- Same logic applies to dungeon set achievements
            local isVariation = row._def and row._def.isVariation
            local isDungeonSet = row._def and row._def.isDungeonSet
            local isReputation = row._def and row._def.isReputation
            local shouldCount = not hiddenByProfession and not hiddenUntilComplete and (not isVariation or row.completed) and (not isDungeonSet or row.completed) and (not isReputation or row.completed)
            
            if shouldCount then
                total = total + 1
                if row.completed then
                    completed = completed + 1
                end
            end
        end
    end
    
    return completed, total
end

function HCA_UpdateTotalPoints()
    local total = HCA_GetTotalPoints()
    if AchievementPanel and AchievementPanel.TotalPoints then
        AchievementPanel.TotalPoints:SetText(tostring(total))
        if AchievementPanel.CountsText then
            local completed, totalCount = HCA_AchievementCount()
            if completed and totalCount then
                AchievementPanel.CountsText:SetText(string.format(" (%d/%d)", completed or 0, totalCount or 0))
            else
                AchievementPanel.CountsText:SetText("")
            end
        end
    end
end

-- Sort all rows by their level cap (and re-anchor)
local function SortAchievementRows()
    if not AchievementPanel or not AchievementPanel.achievements then return end

    -- Get database access for timestamps
    local _, cdb = GetCharDB()

    local function isLevelMilestone(row)
        -- milestone: no kill/quest tracker and id like "Reach Level..." sort to the bottom if tied
        return (not row.killTracker) and (not row.questTracker)
            and type(row.id) == "string" and row.id:match("^Level%d+$") ~= nil
    end

    table.sort(AchievementPanel.achievements, function(a, b)
        -- First, separate into three groups: completed, available, failed
        local aCompleted = a.completed or false
        local bCompleted = b.completed or false
        local aFailed = IsRowOutleveled(a)
        local bFailed = IsRowOutleveled(b)
        
        -- Determine group priority: completed (1), available (2), failed (3)
        local aGroup = aCompleted and 1 or (aFailed and 3 or 2)
        local bGroup = bCompleted and 1 or (bFailed and 3 or 2)
        
        if aGroup ~= bGroup then
            return aGroup < bGroup  -- completed first, then available, then failed
        end
        
        -- Within the same group, apply group-specific sorting
        if aGroup == 1 then
            -- Completed group: sort by completedAt timestamp descending (most recent first)
            local aId = a.id or (a.Title and a.Title.GetText and a.Title:GetText()) or ""
            local bId = b.id or (b.Title and b.Title.GetText and b.Title:GetText()) or ""
            local aRec = cdb and cdb.achievements and cdb.achievements[aId]
            local bRec = cdb and cdb.achievements and cdb.achievements[bId]
            local aTimestamp = (aRec and aRec.completedAt) or 0
            local bTimestamp = (bRec and bRec.completedAt) or 0
            if aTimestamp ~= bTimestamp then
                return aTimestamp > bTimestamp  -- Descending order (most recent first)
            end
            -- Tiebreaker: sort by level ascending when dates match
            local la = (a.maxLevel ~= nil) and a.maxLevel or 9999
            local lb = (b.maxLevel ~= nil) and b.maxLevel or 9999
            if la ~= lb then
                return la < lb  -- Ascending order (lower level first)
            end
        elseif aGroup == 2 then
            -- Available group: sort by level ascending (normal level requirement order)
            -- Treat uncapped (nil) maxLevel as very large so they sort to the bottom
            local la = (a.maxLevel ~= nil) and a.maxLevel or 9999
            local lb = (b.maxLevel ~= nil) and b.maxLevel or 9999
            if la ~= lb then return la < lb end
            local aIsLvl, bIsLvl = isLevelMilestone(a), isLevelMilestone(b)
            if aIsLvl ~= bIsLvl then
                return not aIsLvl  -- non-level achievements first on ties
            end
        elseif aGroup == 3 then
            -- Failed group: sort by failedAt timestamp descending (most recent first)
            local aId = a.id or (a.Title and a.Title.GetText and a.Title:GetText()) or ""
            local bId = b.id or (b.Title and b.Title.GetText and b.Title:GetText()) or ""
            local aFailedAt = GetFailureTimestamp(aId) or 0
            local bFailedAt = GetFailureTimestamp(bId) or 0
            if aFailedAt ~= bFailedAt then
                return aFailedAt > bFailedAt  -- Descending order (most recent first)
            end
            -- Tiebreaker: sort by level ascending when dates match
            local la = (a.maxLevel ~= nil) and a.maxLevel or 9999
            local lb = (b.maxLevel ~= nil) and b.maxLevel or 9999
            if la ~= lb then
                return la < lb  -- Ascending order (lower level first)
            end
        end
        
        -- Fallback: stable sort by title/id for ties
        local at = (a.Title and a.Title.GetText and a.Title:GetText()) or (a.id or "")
        local bt = (b.Title and b.Title.GetText and b.Title:GetText()) or (b.id or "")
        return tostring(at) < tostring(bt)
    end)

    local prev = nil
    local totalHeight = 0
    for _, row in ipairs(AchievementPanel.achievements) do
        row:ClearAllPoints()
        -- Only position visible rows
        if row:IsShown() then
            if prev and prev ~= row then
                row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
            else
                row:SetPoint("TOPLEFT", AchievementPanel.Content, "TOPLEFT", 0, 0)
            end
            
            -- Position border relative to row
            PositionRowBorder(row)
            
            prev = row
            totalHeight = totalHeight + (row:GetHeight() + 2)
        elseif row.Border then
            row.Border:Hide()
            if row.Background then
                row.Background:Hide()
            end
        end
    end

    AchievementPanel.Content:SetHeight(math.max(totalHeight + 16, AchievementPanel.Scroll:GetHeight() or 0))
    AchievementPanel.Scroll:UpdateScrollChildRect()
end

-- Function to update points display and checkmark based on state
local function UpdatePointsDisplay(row)
    if not row or not row.PointsFrame then return end
    
    if row.PointsFrame.Texture then
        if row.completed then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_gold.png")
        elseif IsRowOutleveled(row) then
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_failed.png")
        else
            row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.png")
        end
        if row.PointsFrame.Texture.SetDesaturated then row.PointsFrame.Texture:SetDesaturated(false) end
        if row.PointsFrame.Texture.SetVertexColor then row.PointsFrame.Texture:SetVertexColor(1, 1, 1) end
        row.PointsFrame.Texture:SetAlpha(1)
    end
    
    -- Show/hide variation overlay based on achievement state
    if row.PointsFrame.VariationOverlay and row._def and row._def.isVariation then
        if row.completed then
            -- Completed: use gold texture
            row.PointsFrame.VariationOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dragon_gold.png")
            row.PointsFrame.VariationOverlay:Show()
        elseif IsRowOutleveled(row) then
            -- Failed/overleveled: use failed texture
            row.PointsFrame.VariationOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dragon_failed.png")
            row.PointsFrame.VariationOverlay:Show()
        else
            -- Available (not completed, not failed): use disabled texture
            row.PointsFrame.VariationOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\dragon_disabled.png")
            row.PointsFrame.VariationOverlay:Show()
        end
    elseif row.PointsFrame.VariationOverlay then
        row.PointsFrame.VariationOverlay:Hide()
    end
    
    if row.completed then
        -- Completed: hide points text (make transparent), show green checkmark
        if row.Points then
            row.Points:SetAlpha(0) -- Transparent but still exists for calculations
        end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-Ready.png")
            row.PointsFrame.Checkmark:Show()
        end
        -- Hide icon overlay for completed achievements (they show green checkmark in points circle)
        if row.IconOverlay then
            row.IconOverlay:Hide()
        end
        -- Subtitle (level) text: white when completed
        if row.Sub then
            row.Sub:SetTextColor(1, 1, 1) -- White
        end
        -- Title: yellow (default GameFontNormal color) when completed
        if row.Title then
            row.Title:SetTextColor(1, 0.82, 0) -- Yellow (default GameFontNormal)
        end
    elseif IsRowOutleveled(row) then
        -- Failed: hide points text (make transparent), show red X checkmark
        if row.Points then
            row.Points:SetAlpha(0) -- Transparent but still exists for calculations
        end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
            row.PointsFrame.Checkmark:Show()
        end
        -- Show red X overlay on icon
        if row.IconOverlay then
            row.IconOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ReadyCheck-NotReady.png")
            row.IconOverlay:Show()
        end
        -- Subtitle (level) text: gray when failed
        if row.Sub then
            row.Sub:SetTextColor(0.5, 0.5, 0.5) -- Gray
        end
        -- Title: red when failed
        if row.Title then
            row.Title:SetTextColor(0.957, 0.263, 0.212) -- Red
        end
    else
        -- Incomplete: show points text, hide checkmark
        if row.Points then
            row.Points:SetAlpha(1) -- Visible
        end
        if row.PointsFrame.Checkmark then
            row.PointsFrame.Checkmark:Hide()
        end
        -- Hide icon overlay for incomplete achievements
        if row.IconOverlay then
            row.IconOverlay:Hide()
        end
        -- Subtitle (level) text: gray when incomplete/available
        if row.Sub then
            row.Sub:SetTextColor(0.5, 0.5, 0.5) -- Gray
        end
        -- Title: white when available/incomplete
        if row.Title then
            row.Title:SetTextColor(1, 1, 1) -- White
        end
    end
end

local function ApplyOutleveledStyle(row)
    if not row then return end
    
    local achId = row.achId or row.id
    local isOutleveled = IsRowOutleveled(row)
    
    if row.Icon and row.Icon.SetDesaturated then
        if row.completed or isOutleveled then
            row.Icon:SetDesaturated(false)
        else
            row.Icon:SetDesaturated(true)
        end
    end
    
    if isOutleveled and row.Sub then
        if row.maxLevel then
            row.Sub:SetText((LEVEL or "Level") .. " " .. row.maxLevel)
        else
            row.Sub:SetText(AUCTION_TIME_LEFT0 or "")
        end
    end
    
    if row.completed then
        if row.IconFrameGold then row.IconFrameGold:Show() end
        if row.IconFrame then row.IconFrame:Hide() end
        if row.TS then
            local _, cdb = GetCharDB()
            local completedAt = nil
            if cdb and cdb.achievements and achId and cdb.achievements[achId] then
                completedAt = cdb.achievements[achId].completedAt
            end
            if completedAt then
                row.TS:SetText(FormatTimestamp(completedAt))
            elseif row.TS:GetText() == "" then
                row.TS:SetText(FormatTimestamp(time()))
            end
            row.TS:SetTextColor(1, 1, 1)
        end
    else
        if row.IconFrameGold then row.IconFrameGold:Hide() end
        if row.IconFrame then row.IconFrame:Show() end
        
        if row.TS then
            if isOutleveled then
                local failedAt = GetFailureTimestamp(achId) or EnsureFailureTimestamp(achId) or time()
                row.TS:SetText(FormatTimestamp(failedAt))
                row.TS:SetTextColor(0.957, 0.263, 0.212)
            else
                row.TS:SetText("")
                row.TS:SetTextColor(1, 1, 1)
            end
        end
    end
    
    UpdateRowBorderColor(row)
    UpdatePointsDisplay(row)
end

-- Small utility: mark a UI row as completed visually + persist in DB
function HCA_MarkRowCompleted(row)
    if row.completed then return end
    row.completed = true
    UntrackRowForQuest(row)

    -- Title color will be set by UpdatePointsDisplay
    
    local _, cdb = GetCharDB()
    local wasSolo = false
    if cdb then
        local id = row.id or (row.Title and row.Title:GetText()) or ("row"..tostring(row))
        cdb.progress = cdb.progress or {}
        local progress = cdb.progress[id]
        
        -- Check if achievement was completed solo before clearing progress
        if progress and (progress.soloKill or progress.soloQuest) then
            wasSolo = true
        end
        
        cdb.achievements[id] = cdb.achievements[id] or {}
        local rec = cdb.achievements[id]
        rec.completed   = true
        rec.completedAt = time()
        rec.level       = UnitLevel("player") or nil
        -- Store solo status in achievement record so it persists after progress is cleared
        rec.wasSolo = wasSolo
        -- Check if we have pointsAtKill value in progress to use those points
        local finalPoints = tonumber(row.points) or 0

        local usePointsAtKill = false
        if progress and progress.pointsAtKill then
            -- Use the points that were stored at the time of kill/quest (without self-found bonus)
            finalPoints = tonumber(progress.pointsAtKill) or 0
            usePointsAtKill = true
            -- Add self-found bonus if applicable (pointsAtKill doesn't include it)
            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
            local isDungeonSet = row._def and row._def.isDungeonSet
            local isReputation = row._def and row._def.isReputation
            if isSelfFound and not row.isSecretAchievement and not isDungeonSet and not isReputation then
                finalPoints = finalPoints + HCA_SELF_FOUND_BONUS
                -- Mark that we've already applied self-found bonus so ApplySelfFoundBonus doesn't add it again
                rec.SFMod = true
            end
        end

        -- Note: Secret achievements do NOT get self-found bonus
        if row.isSecretAchievement then
            local base = tonumber(row.revealPointsBase or row.originalPoints) or 0
            local computed = base
            if not (row.revealStaticPoints) then
                local preset = GetPlayerPresetFromSettings and GetPlayerPresetFromSettings() or nil
                local multiplier = GetPresetMultiplier and GetPresetMultiplier(preset) or 1.0
                computed = base + math.floor((base) * (multiplier - 1) + 0.5)
            end
            finalPoints = computed
        end

        -- Points from pointsAtKill already include multiplier and solo doubling if applicable

        rec.points = finalPoints
        -- Reflect final points in UI row and text immediately
        row.points = finalPoints
        if row.Points then
            row.Points:SetText(tostring(finalPoints))
        end

        ClearProgress(id)
        HCA_UpdateTotalPoints()
    end
    
    -- Set Sub text with "Solo" indicator if achievement was completed solo
    -- Solo indicators only show if player is self-found
    -- Completed achievements always show "Solo", never "Solo bonus"
    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
    if row.Sub then
        if wasSolo and isSelfFound then
            -- Completed achievements always show "Solo", not "Solo bonus"
            row.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n|c" .. select(4, GetClassColor(select(2, UnitClass("player")))) .. "Solo|r")
        else
            row.Sub:SetText(AUCTION_TIME_LEFT0)
        end
    end
    if row.Points then row.Points:SetTextColor(0.6, 0.9, 0.6) end
    if row.TS then row.TS:SetText(FormatTimestamp(time())) end
    
    -- Update icon/frame styling to reflect completion
    ApplyOutleveledStyle(row)
    
    -- Reveal secret achievements before persisting/toast
    if row.isSecretAchievement then
        if row.revealTitle and row.Title then 
            row.Title:SetText(row.revealTitle)
            if row.TitleShadow then row.TitleShadow:SetText(StripColorCodes(row.revealTitle)) end
        end
        if row.revealIcon and row.Icon then row.Icon:SetTexture(row.revealIcon) end
        if row.revealTooltip then row.tooltip = row.revealTooltip end
        row.staticPoints = row.revealStaticPoints or false
    end

    if ProfessionTracker and ProfessionTracker.NotifyRowCompleted then
        ProfessionTracker.NotifyRowCompleted(row)
    end
    
	-- Broadcast achievement completion to emote channel
	local playerName = UnitName("player")
	local achievementTitle = row.Title and row.Title:GetText() or "Unknown Achievement"
	local broadcastMessage = string.format(ACHIEVEMENT_BROADCAST, "", achievementTitle)
	-- Remove leading whitespace so EMOTE doesn't show a double space before 'has'
	broadcastMessage = broadcastMessage:gsub("^%s+", "")
    SendChatMessage(broadcastMessage, "EMOTE")

	-- Announce in guild chat (with hyperlink) when enabled
	if type(HardcoreAchievements_ShouldAnnounceInGuildChat) == "function" and HardcoreAchievements_ShouldAnnounceInGuildChat() and IsInGuild() then
        local link = nil
        local achIdForLink = row.achId or row.id
        if achIdForLink and _G.HCA_GetAchievementHyperlink then
            link = _G.HCA_GetAchievementBracket(achIdForLink)
        end
        local guildMessage = string.format(playerName .. ACHIEVEMENT_BROADCAST, "", link or achievementTitle)
        guildMessage = guildMessage:gsub("^%s+", "")
        SendChatMessage(guildMessage, "GUILD")
    end
    
    -- Ensure hidden-until-complete rows become visible now
    if row.hiddenUntilComplete then
        row:Show()
    end
    -- Re-apply filter after completion state changes
    if ApplyFilter then
        C_Timer.After(0, ApplyFilter)
    end
end

function CheckPendingCompletions()
    if not AchievementPanel or not AchievementPanel.achievements then return end

    for _, row in ipairs(AchievementPanel.achievements) do
        if not row.completed then
            local id = row.id
            local fn = _G[id .. "_IsCompleted"]
            if type(fn) == "function" and fn() then
                HCA_MarkRowCompleted(row)
            end
        end
    end
end

local function RestoreCompletionsFromDB()
    local _, cdb = GetCharDB()
    if not cdb or not AchievementPanel or not AchievementPanel.achievements then return end

    for _, row in ipairs(AchievementPanel.achievements) do
        local id = row.id or (row.Title and row.Title:GetText())
        local rec = id and cdb.achievements and cdb.achievements[id]
        if rec and rec.completed then
            row.completed = true
            -- Title color will be set by UpdatePointsDisplay
            -- Check if achievement was completed solo and show indicator
            -- Solo indicators only show if player is self-found
            -- Completed achievements always show "Solo", never "Solo bonus"
            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
            if row.Sub then
                if rec.wasSolo and isSelfFound then
                    -- Completed achievements always show "Solo", not "Solo bonus"
                    row.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n|c" .. select(4, GetClassColor(select(2, UnitClass("player")))) .. "Solo|r")
                else
                    row.Sub:SetText(AUCTION_TIME_LEFT0)
                end
            end
            if row.TS then row.TS:SetText(FormatTimestamp(rec.completedAt)) end
            if row.Points then row.Points:SetTextColor(1, 1, 1) end
            
            -- Update icon/frame styling when loaded as completed
            ApplyOutleveledStyle(row)

            if rec.points then
                row.points = rec.points
                if row.Points then
                    row.Points:SetText(tostring(rec.points))
                end
            end

            -- Apply secret reveal visuals on load
            if row.isSecretAchievement then
                if row.revealTitle and row.Title then 
                    row.Title:SetText(row.revealTitle)
                    if row.TitleShadow then row.TitleShadow:SetText(row.revealTitle) end
                end
                if row.revealIcon and row.Icon then row.Icon:SetTexture(row.revealIcon) end
                if row.revealTooltip then row.tooltip = row.revealTooltip end
                row.staticPoints = row.revealStaticPoints or false
            end
        end
    end

    if SortAchievementRows then SortAchievementRows() end
    if HCA_UpdateTotalPoints then HCA_UpdateTotalPoints() end
    RefreshOutleveledAll()
end

local function ToggleAchievementCharacterFrameTab()
    local isShown = CharacterFrame and CharacterFrame:IsShown() and
                   (AchievementPanel and AchievementPanel:IsShown() or (Tab and Tab.squareFrame and Tab.squareFrame:IsShown()))
    if isShown then
        CharacterFrame:Hide()
    elseif not CharacterFrame:IsShown() then
        CharacterFrame:Show()
        if HCA_ShowAchievementTab then
            HCA_ShowAchievementTab()
        end
    else
        if CharacterFrame:IsShown() and HCA_ShowAchievementTab then
            HCA_ShowAchievementTab()
        end
    end
end

function ShowHardcoreAchievementWindow()
    local _, cdb = GetCharDB()
    if cdb and cdb.settings and cdb.settings.showCustomTab then
        ToggleAchievementCharacterFrameTab()
    elseif type(ToggleSettings) == "function" then
        local container = nil
        if TabManager and TabManager.getTabContent then
            container = TabManager.getTabContent(3)
        end
        if not container and _G.tabContents and _G.tabContents[3] then
            container = _G.tabContents[3]
        end
        local isContainerShown = container and container.IsShown and container:IsShown()
        if isContainerShown then
            ToggleSettings()
        else
            ToggleSettings()
            if TabManager and TabManager.switchToTab then
                TabManager.switchToTab(3)
            elseif type(OpenSettingsToTab) == "function" then
                OpenSettingsToTab(3)
            end
        end
    elseif type(OpenSettingsToTab) == "function" then
        OpenSettingsToTab(3)
    else
        ToggleAchievementCharacterFrameTab()
    end
end

-- =========================================================
-- Simple Achievement Toast
-- =========================================================
-- Usage:
-- HCA_AchToast_Show(iconTextureIdOrPath, "Achievement Title", 10)
-- HCA_AchToast_Show(row.icon or 134400, row.title or "Achievement", row.points or 10)

local function HCA_CreateAchToast()
    if HCA_AchToast and HCA_AchToast:IsObjectType("Frame") then
        return HCA_AchToast
    end

    local f = CreateFrame("Frame", "HCA_AchToast", UIParent)
    f:SetSize(320, 92)
    f:SetPoint("CENTER", 0, -280)
    f:Hide()
    f:SetFrameStrata("TOOLTIP")

    -- Background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    -- Try atlas first; fallback to file + coords (same crop your XML used)
    local ok = bg.SetAtlas and bg:SetAtlas("UI-Achievement-Alert-Background", true)
    if not ok then
        bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Alert-Background")
        bg:SetTexCoord(0, 0.605, 0, 0.703)
    else
        bg:SetTexCoord(0, 1, 0, 1)
    end
    f.bg = bg

    -- Icon group
    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame:SetSize(40, 40)
    iconFrame:SetPoint("LEFT", f, "LEFT", 6, 0)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0) -- move up 2px
    icon:SetSize(40, 43)
    icon:SetTexCoord(0.05, 1, 0.05, 1)
    iconFrame.tex = icon

    f.icon = icon
    f.iconFrame = iconFrame

    local iconOverlay = iconFrame:CreateTexture(nil, "OVERLAY")
    iconOverlay:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    iconOverlay:SetTexCoord(0, 0.5625, 0, 0.5625)
    iconOverlay:SetSize(72, 72)
    iconOverlay:SetPoint("CENTER", iconFrame, "CENTER", -1, 2)

    -- Title (Achievement name)
    local name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("CENTER", f, "CENTER", 10, 0)
    name:SetJustifyH("CENTER")
    name:SetText("")
    f.name = name

    -- "Achievement Unlocked" small label (optional)
    local unlocked = f:CreateFontString(nil, "OVERLAY", "GameFontBlackTiny")
    unlocked:SetPoint("TOP", f, "TOP", 7, -26)
    unlocked:SetText(ACHIEVEMENT_UNLOCKED)
    f.unlocked = unlocked

    -- Shield & points
    local shield = CreateFrame("Frame", nil, f)
    shield:SetSize(64, 64)
    shield:SetPoint("RIGHT", f, "RIGHT", -10, -4)

    local shieldIcon = shield:CreateTexture(nil, "BACKGROUND")
    shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
    shieldIcon:SetSize(56, 52)
    shieldIcon:SetPoint("TOPRIGHT", 1, 0)
    shieldIcon:SetTexCoord(0, 0.5, 0, 0.45)
    f.shieldIcon = shieldIcon

    local points = shield:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    points:SetPoint("CENTER", 4, 5)
    points:SetText("")
    f.points = points

    -- Simple fade-out (no UIParent fades)
    function f:PlayFade(duration)
        local t = 0
        self:SetScript("OnUpdate", function(s, elapsed)
            t = t + elapsed
            local a = 1 - math.min(t / duration, 1)
            s:SetAlpha(a)
            if t >= duration then
                s:SetScript("OnUpdate", nil)
                s:Hide()
                s:SetAlpha(1)
            end
        end)
    end

    local function AttachModelOverlayClipped(parentFrame, texture)
        -- Create a clipper frame to constrain the model to the texture's bounds
        local clipper = CreateFrame("Frame", nil, parentFrame)
        clipper:SetClipsChildren(true)
        clipper:SetFrameStrata(parentFrame:GetFrameStrata())
        clipper:SetFrameLevel(parentFrame:GetFrameLevel() + 3)

        -- Get the texture's size and adjust
        local width, height = texture:GetSize()
        clipper:SetSize(width + 100, height - 50)

        -- Center the clipper on the texture to keep it aligned
        clipper:SetPoint("CENTER", texture, "CENTER", 20, 0)

        -- Create the model inside the clipper
        local model = CreateFrame("PlayerModel", nil, clipper)
        model:SetAllPoints(clipper)
        model:SetAlpha(0.55)
        model:SetModel(166349) -- Default holy light cone
        model:SetModelScale(0.8)
        model:Show()

        -- Model plays once
        C_Timer.After(2.5, function()
            model:Hide()
            --if model:IsShown() then model:PlayFade(0.6) end
        end)

        -- Store references for potential tweaks
        parentFrame.modelOverlayClipped = { clipper = clipper, model = model }

        return clipper, model
    end

    AttachModelOverlayClipped(f, f.bg)

    -- Make the toast clickable
    f:EnableMouse(true)
    
    -- Mouse button handler opens the achievements panel (OnMouseUp for left button)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            ShowHardcoreAchievementWindow()
        end
    end)

    return f
end

-- =========================================================
-- Call Achievement Toast
-- =========================================================

function HCA_AchToast_Show(iconTex, title, pts, achIdOrRow)
    local f = HCA_CreateAchToast()
    f:Hide()
    f:SetAlpha(1)

    -- Accept fileID/path/Texture object; fallback if nil
    local tex = iconTex
    if type(iconTex) == "table" and iconTex.GetTexture then
        tex = iconTex:GetTexture()
    end
    if not tex then tex = 136116 end

    -- Check for pointsAtKill and add self-found bonus if applicable
    local finalPoints = pts or 0
    local achId = nil
    local row = nil
    
    if achIdOrRow then
        local _, cdb = GetCharDB()
        
        if type(achIdOrRow) == "table" then
            -- It's a row object
            row = achIdOrRow
            achId = row.achId or row.id
        else
            -- It's an achievement ID string
            achId = achIdOrRow
        end
        
        if cdb and cdb.progress and achId and cdb.progress[achId] and cdb.progress[achId].pointsAtKill then
            finalPoints = tonumber(cdb.progress[achId].pointsAtKill) or finalPoints
            -- Add self-found bonus if applicable (pointsAtKill doesn't include it)
            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
            local isSecretAchievement = row and row.isSecretAchievement or false
            local isDungeonSet = row and row._def and row._def.isDungeonSet
            local isReputation = row and row._def and row._def.isReputation
            if isSelfFound and not isSecretAchievement and not isDungeonSet and not isReputation then
                finalPoints = finalPoints + HCA_SELF_FOUND_BONUS
            end
        end
    end

    -- these exist because we exposed them in the factory
    f.icon:SetTexture(tex)
    f.name:SetText(title or "")
    
    -- Show shield icon for 0-point achievements, otherwise show points text
    if finalPoints == 0 then
        f.points:SetText("")
        f.points:Hide()
        if f.shieldIcon then
            f.shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields-Nopoints")
            f.shieldIcon:SetTexCoord(0, 0.5, 0, 0.45)
        end
    else
        f.points:SetText(tostring(finalPoints))
        f.points:Show()
        if f.shieldIcon then
            f.shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
            f.shieldIcon:SetTexCoord(0, 0.5, 0, 0.45)
        end
    end

    -- Store achievement data for click handler
    f.achId = achId
    f.achTitle = title
    f.achIcon = tex
    f.achPoints = finalPoints

    f:Show()

    --print(ACHIEVEMENT_BROADCAST_SELF:format(title))
    PlaySoundFile("Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg", "Effects")

    C_Timer.After(1, function()
        -- Check if screenshots are disabled before taking screenshot
        local shouldTakeScreenshot = true
        if type(HardcoreAchievements_ShouldTakeScreenshot) == "function" then
            shouldTakeScreenshot = HardcoreAchievements_ShouldTakeScreenshot()
        else
            -- Fallback: check setting directly if function doesn't exist yet
            local _, cdb = GetCharDB()
            if cdb and cdb.settings and cdb.settings.disableScreenshots then
                shouldTakeScreenshot = false
            end
        end
        
        if shouldTakeScreenshot then
            Screenshot()
        end
    end)

    holdSeconds = holdSeconds or 3
    fadeSeconds = fadeSeconds or 0.6
    C_Timer.After(holdSeconds, function()
        if f:IsShown() then f:PlayFade(fadeSeconds) end
    end)
end

-- =========================================================
-- Self Found
-- =========================================================

function IsSelfFound()
    -- Check for Hardcore Self-Found buff
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId == 431567 or name == "Self-Found Adventurer" then
            return true
        end
    end
    return false
end

-- Export IsSelfFound globally
_G.IsSelfFound = IsSelfFound

-- Check if an achievement ID is a level milestone achievement (Level10, Level20, etc.)
function IsLevelMilestone(achId)
    if not achId or type(achId) ~= "string" then return false end
    return string.match(achId, "^Level%d+$") ~= nil
end
_G.IsLevelMilestone = IsLevelMilestone

local function ApplySelfFoundBonus()
    if not IsSelfFound() then return end
    if not HardcoreAchievementsDB or not HardcoreAchievementsDB.chars then return end

    local guid = UnitGUID("player")
    local charData = HardcoreAchievementsDB.chars[guid]
    if not charData or not charData.achievements then return end

    local function isSecretAch(achId)
        if not AchievementPanel or not AchievementPanel.achievements then return false end
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.id == achId and row.isSecretAchievement then return true end
        end
        return false
    end

    local function isDungeonSetOrReputation(achId)
        if not AchievementPanel or not AchievementPanel.achievements then return false end
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.id == achId and row._def then
                if row._def.isDungeonSet or row._def.isReputation then
                    return true
                end
            end
        end
        return false
    end

    local updatedCount = 0
    for achId, ach in pairs(charData.achievements) do
        if ach.completed and not ach.SFMod then
            if isSecretAch(achId) or isDungeonSetOrReputation(achId) then
                ach.SFMod = true -- mark so we don't try again later
            else
            ach.points = (ach.points or 0) + HCA_SELF_FOUND_BONUS
            ach.SFMod = true
            updatedCount = updatedCount + 1
            end
        end
    end
end

-- =========================================================
-- Outleveled (missed) indicator
-- =========================================================

RefreshOutleveledAll = function()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    for _, row in ipairs(AchievementPanel.achievements) do
        ApplyOutleveledStyle(row)
    end
end

_G.HCA_RefreshOutleveledAll = RefreshOutleveledAll

-- =========================================================
-- Progress Helpers
-- =========================================================

local function GetProgress(achId)
    local _, cdb = GetCharDB()
    if not cdb then return nil end
    cdb.progress = cdb.progress or {}
    return cdb.progress[achId]
end

local function SetProgress(achId, key, value)
    local _, cdb = GetCharDB()
    if not cdb then return end
    cdb.progress = cdb.progress or {}
    local p = cdb.progress[achId] or {}
    p[key] = value
    p.updatedAt = time()
    -- Only set levelAt for progress-related keys (kills, quests, counts, etc.)
    -- Don't set it for metadata-only keys like levelAtTurnIn, levelAtKill, etc.
    local shouldSetLevelAt = key == "killed" or key == "quest" or key == "counts" or key == "eligibleCounts" or key == "ineligibleKill" or key == "soloKill" or key == "soloQuest" or key == "pointsAtKill"
    if shouldSetLevelAt then
        p.levelAt = UnitLevel("player") or 1
    end
    cdb.progress[achId] = p

    C_Timer.After(0, function()
        CheckPendingCompletions()
        RefreshOutleveledAll()
    end)
end

-- Export tiny API so achievement modules can use it
function HardcoreAchievements_GetProgress(achId) return GetProgress(achId) end
function HardcoreAchievements_SetProgress(achId, key, value) SetProgress(achId, key, value) end
function HardcoreAchievements_ClearProgress(achId) ClearProgress(achId) end
function HardcoreAchievements_GetCharDB() return GetCharDB() end
  
-- Exported: hide custom vertical tab if present (used by embedded UI)
function HardcoreAchievements_HideVerticalTab()
    if Tab and Tab.squareFrame then
        Tab.squareFrame:Hide()
        Tab.squareFrame:EnableMouse(false)
        return true
    end
    return false
end

-- Exported: reload tab position (used by embedded UI)
function HardcoreAchievements_LoadTabPosition()
    LoadTabPosition()
end

function HardcoreAchievements_GetSettings()
    local _, cdb = GetCharDB()
    if not cdb then return {} end
    return cdb.settings
end

-- =========================================================
-- Minimap Button Implementation
-- =========================================================

-- Initialize minimap button libraries
local function OpenOptionsPanel()
    if Settings and Settings.OpenToCategory then
        local targetCategory = (addon and addon.settingsCategory) or _G._HardcoreAchievementsOptionsCategory
        if targetCategory and targetCategory.GetID then
            Settings.OpenToCategory(targetCategory:GetID())
            return
        end
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("Hardcore Achievements")
    end
end

_G.HardcoreAchievements_OpenOptionsPanel = OpenOptionsPanel

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

BINDING_NAME_HCA_TOGGLE = "Toggle Achievements"

-- Create the data object for the minimap button
local minimapDataObject = LDB:NewDataObject("HardcoreAchievements", {
    type = "data source",
    text = "HardcoreAchievements",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png",
    OnClick = function(self, button)
        if button == "LeftButton" and not IsShiftKeyDown() then
            ShowHardcoreAchievementWindow()
        elseif button == "RightButton" then
            -- Right-click to open options panel
            OpenOptionsPanel()
        elseif button == "LeftButton" and IsShiftKeyDown() then
            -- Left-click with Shift to open admin panel
            if HardcoreAchievementsAdminPanel and HardcoreAchievementsAdminPanel.Toggle then
                HardcoreAchievementsAdminPanel:Toggle()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("HardcoreAchievements", 1, 1, 1)
        
        -- Show different tooltip text based on user preference and UltraHardcore availability
        local _, cdb = GetCharDB()
        if cdb and cdb.settings and cdb.settings.showCustomTab then
            tooltip:AddLine("Left-click to open Hardcore Achievements", 0.5, 0.5, 0.5)
        elseif type(OpenSettingsToTab) == "function" then
            tooltip:AddLine("Left-click to open UltraHardcore Achievements", 0.5, 0.5, 0.5)
        else
            tooltip:AddLine("Left-click to open Hardcore Achievements", 0.5, 0.5, 0.5)
        end
        tooltip:AddLine("Right-click to open Options", 0.5, 0.5, 0.5)
        
        -- Show current achievement count
        local completedCount, totalCount = HCA_AchievementCount()
        tooltip:AddLine(" ")
        local countStr = string.format("%d/%d", completedCount, totalCount)
        tooltip:AddLine(string.format(ACHIEVEMENT_META_COMPLETED_DATE, countStr), 0.6, 0.9, 0.6)
    end,
})

-- Register the minimap icon
local function InitializeMinimapButton()
    local db = EnsureDB()
    if not db.minimap then
        db.minimap = { hide = false, position = 45 }
    end
    
    LDBIcon:Register("HardcoreAchievements", minimapDataObject, db)
    
    -- Show the button by default
    if not db.minimap.hide then
        LDBIcon:Show("HardcoreAchievements")
    end
end

-- =========================================================
-- Events
-- =========================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")

        local db, cdb = GetCharDB()
        if cdb then
            -- Ensure settings table exists
            cdb.settings = cdb.settings or {}
            local name, realm = UnitName("player"), GetRealmName()
            local className = UnitClass("player")
            cdb.meta.name      = name
            cdb.meta.realm     = realm
            cdb.meta.className = className
            cdb.meta.race      = UnitRace("player")
            cdb.meta.level     = UnitLevel("player")
            cdb.meta.faction   = UnitFactionGroup("player")
            cdb.meta.lastLogin = time()
            
            -- Clean up incorrectly completed level bracket achievements
            CleanupIncorrectLevelAchievements()
            
            RestoreCompletionsFromDB()
            CheckPendingCompletions()
            RefreshOutleveledAll()
        end
        SortAchievementRows()
        if ProfessionTracker and ProfessionTracker.RefreshAll then
            ProfessionTracker.RefreshAll()
        end
        
        -- Initialize minimap button
        InitializeMinimapButton()
        
        -- Load saved tab position
        LoadTabPosition()
        
        if UISpecialFrames then
            local frameName = AchievementPanel and AchievementPanel:GetName()
            if frameName and not tContains(UISpecialFrames, frameName) then
                table.insert(UISpecialFrames, frameName)
            end
        end
        
        -- Refresh options panel to sync checkbox states
        if _HardcoreAchievementsOptionsPanel and _HardcoreAchievementsOptionsPanel.refresh then
            _HardcoreAchievementsOptionsPanel:refresh()
        end
        
        -- Initialize AchievementTracker (after it loads)
        C_Timer.After(0.5, function()
            local AchievementTracker = GetAchievementTracker()
            if AchievementTracker and AchievementTracker.Initialize then
                AchievementTracker:Initialize()
            end
        end)

    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            C_Timer.After(3, function()
                ApplySelfFoundBonus()
                RestoreCompletionsFromDB()
                --addon:ShowWelcomeMessage()
            end)
        end
    end
end)

-- -- Function to show welcome message popup on first login
-- function addon:ShowWelcomeMessage()
--     local _, cdb = GetCharDB()
--     if not cdb.settings.showWelcomeMessage and IsSelfFound() then
--         StaticPopup_Show("Hardcore Achievements")
--         cdb.settings.showWelcomeMessage = true
--     end
-- end

-- -- Define the welcome message popup
-- StaticPopupDialogs["Hardcore Achievements"] = {
--     text = "You are self found! You can enable Solo Self Found mode for Hardcore Achievements within the options panel for double the points and double the glory.",
--     button1 = "Got it!",
--     timeout = 0,
--     whileDead = true,
--     hideOnEscape = true,
--     preferredIndex = 3,
--     OnAccept = function()
--         -- Popup automatically closes
--     end,
-- }

-- =========================================================
-- Setting up the Interface
-- =========================================================

-- Constants
local Tabs = CharacterFrame.numTabs
local TabID = CharacterFrame.numTabs + 1

-- Create and configure the subframe
local Tab = CreateFrame("Button" , "$parentTab"..TabID, CharacterFrame, "CharacterFrameTabButtonTemplate")
-- Don't set position here - let LoadTabPosition handle it after CharacterFrame is fully initialized
Tab:SetText(ACHIEVEMENTS)
PanelTemplates_DeselectTab(Tab)

-- Draggable "curl" behavior for Achievements tab (bottom + right edges only)
-- Tab persistence functions
function SaveTabPosition()
    local db = EnsureDB()
    if not db.tabSettings then
        db.tabSettings = {}
    end
    
    -- Determine mode by checking the tab's current anchor point
    local anchor, relativeTo, relativePoint, x, y = Tab:GetPoint()
    local currentMode = "bottom" -- default
    
    if anchor == "TOPRIGHT" then
        currentMode = "right"
    elseif Tab.squareFrame and Tab.squareFrame:IsShown() then
        currentMode = "right"
    end
    
    
    db.tabSettings.mode = currentMode
    
    if currentMode == "bottom" then
        -- For bottom mode, save the X offset from left edge
        db.tabSettings.position = {
            x = x or 25,
            y = 0
        }
    else
        -- For right mode, save the X offset from right edge and Y offset from top
        db.tabSettings.position = {
            x = x or 25,
            y = y or 0
        }
    end
end

function LoadTabPosition()
    local db = EnsureDB()
    if db.tabSettings and db.tabSettings.mode and db.tabSettings.position then
        local savedMode = db.tabSettings.mode
        local posX = db.tabSettings.position.x
        local posY = db.tabSettings.position.y
        
        -- Respect user preference: hide custom tab entirely if disabled
        local _, cdb = GetCharDB()
        if not (cdb and cdb.settings and cdb.settings.showCustomTab) then
            Tab:Hide()
            if Tab.squareFrame then
                Tab.squareFrame:Hide()
                Tab.squareFrame:EnableMouse(false)
            end
            return
        end
        
        -- Only show the tab/squareFrame if CharacterFrame is currently shown
        local isCharacterFrameShown = CharacterFrame and CharacterFrame:IsShown()
        
        Tab:ClearAllPoints()
        if savedMode == "bottom" then
            Tab:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", posX, 45)
            -- Switch to bottom mode
            Tab:SetAlpha(1)
            Tab:EnableMouse(true)   -- Enable tab mouse events in horizontal mode
            if Tab.squareFrame then
                Tab.squareFrame:EnableMouse(false)
                Tab.squareFrame:Hide()
            end
            -- Only show tab if CharacterFrame is shown
            if isCharacterFrameShown then
                Tab:Show()
            else
                Tab:Hide()
            end
        else
            Tab:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", posX, posY)
            -- Switch to right mode
            Tab:SetAlpha(0)
            Tab:EnableMouse(false)  -- Disable tab mouse events in vertical mode; use square frame instead
            -- Ensure square frame exists
            if not Tab.squareFrame then
                CreateSquareFrame()
            end
            if Tab.squareFrame then
                Tab.squareFrame:ClearAllPoints()
                Tab.squareFrame:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", posX, posY)
                Tab.squareFrame:EnableMouse(true)
                -- Only show square frame if CharacterFrame is shown
                if isCharacterFrameShown then
                    Tab.squareFrame:Show()
                else
                    Tab.squareFrame:Hide()
                end
            end
        end
        
        -- Set the mode on the tab object
        Tab.mode = savedMode
    else
        -- If no saved data, check showCustomTab setting
        local _, cdb = GetCharDB()
        local shouldShow = (cdb and cdb.settings and cdb.settings.showCustomTab)
        
        if shouldShow then
            -- Show tab at default position if showCustomTab is true
            local isCharacterFrameShown = CharacterFrame and CharacterFrame:IsShown()
            
            Tab:ClearAllPoints()
            Tab:SetPoint("RIGHT", _G["CharacterFrameTab"..Tabs], "RIGHT", 43, 0)
            Tab:SetAlpha(1)
            Tab:EnableMouse(true)
            Tab.mode = "bottom"
            
            if Tab.squareFrame then
                Tab.squareFrame:EnableMouse(false)
                Tab.squareFrame:Hide()
            end
            
            -- Only show tab if CharacterFrame is shown
            if isCharacterFrameShown then
                Tab:Show()
            else
                Tab:Hide()
            end
        else
            -- Hide the tab if showCustomTab is false
            Tab:Hide()
            if Tab.squareFrame then
                Tab.squareFrame:Hide()
                Tab.squareFrame:EnableMouse(false)
            end
        end
    end
end

function ResetTabPosition()
    local db = EnsureDB()
    if db.tabSettings then
        db.tabSettings = nil
    end
    
    -- Reset to default position (same as original tab creation)
    Tab:ClearAllPoints()
    local Tabs = CharacterFrame.numTabs
    Tab:SetPoint("RIGHT", _G["CharacterFrameTab"..Tabs], "RIGHT", 43, 0)
    Tab:SetAlpha(1)
    Tab:EnableMouse(true)   -- Enable tab mouse events in horizontal mode
    if Tab.squareFrame then
        Tab.squareFrame:Hide()
    end
    
    print("HardcoreAchievements: Tab position reset to default")
end

-- Keeps default anchoring until the user drags; then constrains motion to bottom or right edge.
do
    local PAD_LEFT  = 30   -- keep at least 30px away from left edge while on bottom
    local PAD_TOP   = 30   -- keep at least 30px away from top edge while on right
    local EDGE_EPS  = 2    -- small epsilon to treat "past right edge" as snap condition
    local TAB_WIDTH = 120  -- approximate width of character frame tab
    local TAB_HEIGHT = 32  -- approximate height of character frame tab
    local SQUARE_SIZE = 60 -- size of the custom square frame (doubled)
    local dragging  = false
    local mode      = "bottom"  -- "bottom" (horizontal only) or "right" (vertical only)
    
    -- Store mode on Tab object for persistence functions
    Tab.mode = mode
    
    -- Forward declare so CreateSquareFrame's closures can reference these
    local SwitchTabMode
    local GetCursorInUI
    local clamp
    
    -- Create custom square frame for vertical mode
    function CreateSquareFrame()
        if Tab.squareFrame then return Tab.squareFrame end
        
        local squareFrame = CreateFrame("Button", nil, UIParent) -- Parent to UIParent instead of Tab; use Button for clicks/drag
        squareFrame:SetSize(SQUARE_SIZE, SQUARE_SIZE)
        squareFrame:SetHitRectInsets(0, 30, 0, 0) -- shrink hitbox by 30px from right edge
        squareFrame:SetFrameStrata("BACKGROUND") -- Move to background strata
        squareFrame:SetFrameLevel(1) -- Low frame level to appear below borders
        squareFrame:Hide()
        
        -- Background - Stat background texture only
        local bg = squareFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Spellbook\\SpellBook-SkillLineTab.png")
        bg:SetTexCoord(0, 1, 0, 1)
        squareFrame.bg = bg
        
        -- Logo
        local logo = squareFrame:CreateTexture(nil, "ARTWORK")
        logo:SetSize(26, 26) -- Fixed size, not dependent on frame size
        logo:SetPoint("CENTER", squareFrame, "CENTER", -12, 5)
        logo:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png")
        squareFrame.logo = logo
        
        -- Highlight texture (like default tab)
        local highlight = squareFrame:CreateTexture(nil, "OVERLAY")
        highlight:SetSize(SQUARE_SIZE - 30, SQUARE_SIZE - 30) -- Make it smaller than the frame
        highlight:SetPoint("CENTER", squareFrame, "CENTER", -12, 4) -- Center it on the frame
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetTexCoord(0, 1, 0, 1)
        highlight:SetBlendMode("ADD")
        highlight:Hide()
        squareFrame.highlight = highlight
        
        -- Interaction wiring; initially disabled (enabled only in right mode)
        squareFrame:EnableMouse(false)
        squareFrame:RegisterForClicks("LeftButtonUp")
        squareFrame:SetScript("OnClick", function()
            if HCA_ShowAchievementTab then
                HCA_ShowAchievementTab()
            end
        end)

        -- Hover highlight + tooltip (mirrors Tab hooks)
        squareFrame:HookScript("OnEnter", function(self)
            if self.highlight then
                self.highlight:Show()
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -30, 0)
            GameTooltip:SetText(ACHIEVEMENTS, 1, 1, 1)
            GameTooltip:AddLine("Shift click to drag \nMust not be active", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        squareFrame:HookScript("OnLeave", function(self)
            if self.highlight and not AchievementPanel:IsShown() then
                self.highlight:Hide()
            end
            GameTooltip:Hide()
        end)

        -- Drag support in vertical mode; moves both the hidden Tab and the square
        squareFrame:RegisterForDrag("LeftButton")
        squareFrame:HookScript("OnDragStart", function(self)
            if not IsShiftKeyDown() then return false end
            dragging = true
            mode = "right"
            Tab.mode = mode
            SwitchTabMode("right")
            self:ClearAllPoints()
            self:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, 0)
            Tab:ClearAllPoints()
            Tab:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, 0)
            self:SetScript("OnUpdate", function(s)
                if not dragging then s:SetScript("OnUpdate", nil) return end
                if not IsMouseButtonDown("LeftButton") then
                    dragging = false
                    s:SetScript("OnUpdate", nil)
                    SaveTabPosition()
                    if mode == "bottom" then
                        SwitchTabMode("bottom") -- finalize hide of square
                    end
                    return
                end
                if not IsShiftKeyDown() then
                    dragging = false
                    s:SetScript("OnUpdate", nil)
                    SaveTabPosition()
                    return
                end
                local cxl, cyl = GetCursorInUI()
                local L, B, R, T = CharacterFrame:GetLeft(), CharacterFrame:GetBottom(), CharacterFrame:GetRight(), CharacterFrame:GetTop()
                local width  = R - L
                local height = T - B
                local transitionPoint = R - TAB_WIDTH

                -- Mode switching while dragging from the square
                if mode == "right" and cxl <= transitionPoint then
                    mode = "bottom"
                    Tab.mode = mode
                    SwitchTabMode("bottom", true) -- keep square alive until mouse up
                elseif mode == "bottom" and cxl > transitionPoint + EDGE_EPS then
                    mode = "right"
                    Tab.mode = mode
                    SwitchTabMode("right")
                end

                if mode == "bottom" then
                    -- Horizontal-only along bottom edge while still dragging from square
                    local relX = cxl - L
                    local maxRelX = width - TAB_WIDTH - 15
                    relX = clamp(relX, PAD_LEFT, maxRelX)
                    Tab:ClearAllPoints()
                    Tab:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", relX, 45)
                    -- Keep square near Tab but hidden in bottom mode
                    if Tab.squareFrame then
                        Tab.squareFrame:ClearAllPoints()
                        Tab.squareFrame:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, 0)
                        Tab.squareFrame:SetAlpha(0)
                    end
                else
                    -- Vertical-only along right edge
                    local relYFromTop = T - cyl
                    relYFromTop = clamp(relYFromTop, PAD_TOP, height - TAB_HEIGHT - 95)
                    s:ClearAllPoints()
                    s:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, -relYFromTop)
                    Tab:ClearAllPoints()
                    Tab:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, -relYFromTop)
                    if Tab.squareFrame then
                        Tab.squareFrame:SetAlpha(1)
                    end
                end
            end)
        end)
        squareFrame:HookScript("OnDragStop", function(self)
            dragging = false
            self:SetScript("OnUpdate", nil)
            SaveTabPosition()
        end)
        
        Tab.squareFrame = squareFrame
        return squareFrame
    end
    
    -- Function to switch between tab modes (assigned to the forward-declared local)
    -- keepSquareVisible: when true (during an active drag), don't hide the square immediately
    SwitchTabMode = function(newMode, keepSquareVisible)
        if newMode == "right" then
            -- Show square frame, hide default tab
            Tab:SetAlpha(0) -- Hide the default tab
            Tab:EnableMouse(false) -- Disable Tab mouse in vertical mode; use square frame instead
            local squareFrame = CreateSquareFrame()
            squareFrame:Show()
            squareFrame:EnableMouse(true)
            squareFrame:SetAlpha(1)
            -- Position the square frame to match the tab's current position
            squareFrame:ClearAllPoints()
            squareFrame:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 20, 0)
            squareFrame:SetSize(SQUARE_SIZE, SQUARE_SIZE)
        else
            -- Show default tab, hide square frame
            Tab:SetAlpha(1) -- Show the default tab
            Tab:EnableMouse(true)   -- Enable tab mouse events in horizontal mode
            if Tab.squareFrame then
                Tab.squareFrame:EnableMouse(false)
                if keepSquareVisible then
                    Tab.squareFrame:SetAlpha(0) -- keep around for drag completion but invisible
                    Tab.squareFrame:Show()
                else
                    Tab.squareFrame:Hide()
                end
            end
        end
    end

    -- Helper: get cursor position in UIParent scale
    GetCursorInUI = function()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        return x / scale, y / scale
    end

    -- Helper: clamp
    clamp = function(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    -- Begin drag on left button only
    Tab:RegisterForDrag("LeftButton")
    Tab:EnableMouse(true)
    Tab:SetMovable(false)      -- we are not using StartMoving(); we re-anchor manually

    Tab:HookScript("OnDragStart", function(self)
        -- Only allow dragging if Shift key is held down
        if not IsShiftKeyDown() then
            return false  -- Cancel the drag
        end
        dragging = true
        -- When a new drag starts, assume we're on the bottom unless cursor is already past the transition point
        local left, bottom, right, top = CharacterFrame:GetLeft(), CharacterFrame:GetBottom(), CharacterFrame:GetRight(), CharacterFrame:GetTop()
        local cx = select(1, GetCursorInUI())
        local transitionPoint = right - TAB_WIDTH  -- transition earlier to account for tab width
        mode = (cx > transitionPoint + EDGE_EPS) and "right" or "bottom"
        SwitchTabMode(mode) -- Set initial visual mode
        self:ClearAllPoints()
        -- Anchor to bottom by default so first frame is stable
        if mode == "bottom" then
            -- Use RIGHT anchor to preserve 1-pixel offset (same as default horizontal position)
            local Tabs = CharacterFrame.numTabs
            self:SetPoint("RIGHT", _G["CharacterFrameTab"..Tabs], "RIGHT", 43, 0)
        else
            self:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, 0)
        end
        self:SetScript("OnUpdate", function(s, elapsed)
            if not dragging then s:SetScript("OnUpdate", nil) return end
            
            -- Stop dragging if Left button or Shift key is released
            if not IsMouseButtonDown("LeftButton") then
                dragging = false
                s:SetScript("OnUpdate", nil)
                SaveTabPosition()
                return
            end
            if not IsShiftKeyDown() then
                dragging = false
                s:SetScript("OnUpdate", nil)
                SaveTabPosition()
                return
            end

            local cxl, cyl = GetCursorInUI()
            local L, B, R, T = CharacterFrame:GetLeft(), CharacterFrame:GetBottom(), CharacterFrame:GetRight(), CharacterFrame:GetTop()
            local width  = R - L
            local height = T - B

            -- Switch modes if crossing the transition point (or back inside)
            local transitionPoint = R - TAB_WIDTH
            if mode == "bottom" and cxl > transitionPoint + EDGE_EPS then
                -- snap to right edge
                mode = "right"
                Tab.mode = mode
                SwitchTabMode("right")
                s:ClearAllPoints()
                s:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, 0)
            elseif mode == "right" and cxl <= transitionPoint then
                -- return to bottom edge behavior
                mode = "bottom"
                Tab.mode = mode
                SwitchTabMode("bottom")
                s:ClearAllPoints()
                -- Re-anchor using RIGHT anchor to preserve 1-pixel offset (same as default horizontal position)
                local Tabs = CharacterFrame.numTabs
                s:SetPoint("RIGHT", _G["CharacterFrameTab"..Tabs], "RIGHT", 43, 0)
            end

            if mode == "bottom" then
                -- Horizontal-only along bottom edge
                local relX = cxl - L
                -- Respect left padding; ensure tab doesn't extend beyond right edge
                local maxRelX = width - TAB_WIDTH - 15  -- 15px padding from right edge
                relX = clamp(relX, PAD_LEFT, maxRelX)
                -- Move tab up 45 pixels from bottom edge
                s:ClearAllPoints()
                s:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", relX, 45)

            else -- mode == "right"
                -- Vertical-only along right edge
                local relYFromTop = T - cyl
                -- Respect top padding; limit bottom movement to account for tab height (reduce by 30px)
                relYFromTop = clamp(relYFromTop, PAD_TOP, height - TAB_HEIGHT - 95)
                -- Move tab right 10 pixels from right edge
                s:ClearAllPoints()
                s:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, -relYFromTop)
                
                -- Also move the square frame
                if Tab.squareFrame and Tab.squareFrame:IsShown() then
                    Tab.squareFrame:ClearAllPoints()
                    Tab.squareFrame:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 25, -relYFromTop)
                end
            end
        end)
    end)

    Tab:HookScript("OnDragStop", function(self)
        dragging = false
        self:SetScript("OnUpdate", nil)
        -- Save position when drag stops
        SaveTabPosition()
    end)
end
-- === end draggable curl behavior ===
 
AchievementPanel = CreateFrame("Frame", "HardcoreAchievementsFrame", CharacterFrame)
AchievementPanel:Hide()
AchievementPanel:EnableMouse(true)
AchievementPanel:SetAllPoints(CharacterFrame)
AchievementPanel:SetClipsChildren(true) -- Clip borders to stay within panel

-- Create blur overlay frame for bottom blur effect
if not AchievementPanel.BlurOverlayFrame then
    AchievementPanel.BlurOverlayFrame = CreateFrame("Frame", nil, AchievementPanel)
    AchievementPanel.BlurOverlayFrame:SetFrameStrata("DIALOG")
    AchievementPanel.BlurOverlayFrame:SetFrameLevel(18)
    AchievementPanel.BlurOverlayFrame:SetAllPoints(AchievementPanel)
end

-- Create blur overlay texture at the bottom
if not AchievementPanel.BlurOverlay then
    AchievementPanel.BlurOverlay = AchievementPanel.BlurOverlayFrame:CreateTexture(nil, "OVERLAY")
    AchievementPanel.BlurOverlay:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\blur2.png")
    AchievementPanel.BlurOverlay:SetBlendMode("BLEND")
    AchievementPanel.BlurOverlay:SetTexCoord(0, 1, 0, 1)
    AchievementPanel.BlurOverlay:SetPoint("BOTTOMLEFT", AchievementPanel.BlurOverlayFrame, "BOTTOMLEFT", 20, 80)
    AchievementPanel.BlurOverlay:SetPoint("BOTTOMRIGHT", AchievementPanel.BlurOverlayFrame, "BOTTOMRIGHT", -60, 80)
end

local pendingCharacterFrameClose = false
local combatCloseWatcher = CreateFrame("Frame")
local characterFrameHiddenForCombat = false
local previousCharFrameAlpha = nil
local previousCharFrameMouse = nil

local function HideCharacterFrameContentsForCombat()
    if CharacterFrame then
        if not characterFrameHiddenForCombat then
            previousCharFrameAlpha = CharacterFrame:GetAlpha()
            previousCharFrameMouse = CharacterFrame:IsMouseEnabled()
            CharacterFrame:SetAlpha(0)
            CharacterFrame:EnableMouse(false)
            characterFrameHiddenForCombat = true

            if CharacterFrame.numTabs then
                for i = 1, CharacterFrame.numTabs do
                    local tab = _G["CharacterFrameTab"..i]
                    if tab and tab:IsShown() then
                        tab._hc_prevAlpha = tab:GetAlpha()
                        tab._hc_prevMouse = tab:IsMouseEnabled()
                        tab:SetAlpha(0)
                        tab:EnableMouse(false)
                    end
                end
            end
        end
    end

    if _G["PaperDollFrame"]    then _G["PaperDollFrame"]:Hide()    end
    if _G["PetPaperDollFrame"] then _G["PetPaperDollFrame"]:Hide() end
    if _G["HonorFrame"]        then _G["HonorFrame"]:Hide()        end
    if _G["SkillFrame"]        then _G["SkillFrame"]:Hide()        end
    if _G["ReputationFrame"]   then _G["ReputationFrame"]:Hide()   end
    if _G["TokenFrame"]        then _G["TokenFrame"]:Hide()        end
    if type(_G.CSC_HideStatsPanel) == "function" then
        _G.CSC_HideStatsPanel()
    end
end

local function RestoreCharacterFrameAfterCombat()
    if CharacterFrame and characterFrameHiddenForCombat then
        CharacterFrame:SetAlpha(previousCharFrameAlpha or 1)
        if previousCharFrameMouse ~= nil then
            CharacterFrame:EnableMouse(previousCharFrameMouse)
        else
            CharacterFrame:EnableMouse(true)
        end

        if CharacterFrame.numTabs then
            for i = 1, CharacterFrame.numTabs do
                local tab = _G["CharacterFrameTab"..i]
                if tab then
                    tab:SetAlpha(tab._hc_prevAlpha or 1)
                    if tab._hc_prevMouse ~= nil then
                        tab:EnableMouse(tab._hc_prevMouse)
                    else
                        tab:EnableMouse(true)
                    end
                    tab._hc_prevAlpha = nil
                    tab._hc_prevMouse = nil
                end
            end
        end

        previousCharFrameAlpha = nil
        previousCharFrameMouse = nil
        characterFrameHiddenForCombat = false
    end
end

if CharacterFrame and not CharacterFrame._hc_restoreHooked then
    CharacterFrame:HookScript("OnShow", RestoreCharacterFrameAfterCombat)
    CharacterFrame._hc_restoreHooked = true
end

combatCloseWatcher:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" and pendingCharacterFrameClose then
        pendingCharacterFrameClose = false
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        RestoreCharacterFrameAfterCombat()
        if CharacterFrame and CharacterFrame:IsShown() then
            HideUIPanel(CharacterFrame)
        end
    end
end)

AchievementPanel:HookScript("OnShow", function()
    if pendingCharacterFrameClose then
        pendingCharacterFrameClose = false
        combatCloseWatcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    RestoreCharacterFrameAfterCombat()
end)

AchievementPanel:HookScript("OnHide", function(self)
    if self._suppressOnHide then
        self._suppressOnHide = nil
        return
    end
    
    if InCombatLockdown and InCombatLockdown() then
        HideCharacterFrameContentsForCombat()
        pendingCharacterFrameClose = true
        combatCloseWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif CharacterFrame and CharacterFrame:IsShown() then
        HideUIPanel(CharacterFrame)
    end
    
    if Tab then
        PanelTemplates_DeselectTab(Tab)
        if Tab.squareFrame and Tab.squareFrame:IsShown() and Tab.squareFrame.highlight then
            Tab.squareFrame.highlight:Hide()
        end
    end
end)

-- Filter dropdown - using shared FilterDropdown module

-- Function to apply the current filter to all achievement rows
local function ApplyFilter()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    
    local currentFilter = FilterDropdown:GetCurrentFilter(AchievementPanel.filterDropdown)
    
    for _, row in ipairs(AchievementPanel.achievements) do
        local shouldShow = false
        
        if currentFilter == "all" then
            shouldShow = true
        elseif currentFilter == "completed" then
            shouldShow = row.completed == true
        elseif currentFilter == "not_completed" then
            shouldShow = row.completed ~= true and not IsRowOutleveled(row)
        elseif currentFilter == "failed" then
            shouldShow = IsRowOutleveled(row)
        end
        
        -- Force-hide rows designated as hidden until completion
        if row.hiddenUntilComplete and not row.completed then
            shouldShow = false
        end
        if row.hiddenByProfession then
            shouldShow = false
        end
        
        -- Hide/show variation achievements based on checkbox states
        -- Completed variations always show when "all" or "completed" filter is selected
        if row._def and row._def.isVariation then
            -- Only check checkbox state for non-completed variations
            -- Completed variations always show with "all" or "completed" filter
            local isCompleted = row.completed == true
            local shouldCheckCheckbox = true
            
            if isCompleted and (currentFilter == "all" or currentFilter == "completed") then
                -- Completed variations always show with these filters, skip checkbox check
                shouldCheckCheckbox = false
            end
            
            if shouldCheckCheckbox then
                local checkboxStates = { false, false, false }
                if type(HardcoreAchievements_GetCharDB) == "function" then
                    local _, cdb = HardcoreAchievements_GetCharDB()
                    if cdb and cdb.settings and cdb.settings.filterCheckboxes then
                        local states = cdb.settings.filterCheckboxes
                        if type(states) == "table" then
                            checkboxStates = {
                                states[1] == true,  -- Trio
                                states[2] == true,  -- Duo
                                states[3] == true,  -- Solo
                            }
                        end
                    end
                end
                
                local variationType = row._def.variationType
                if variationType == "Trio" and not checkboxStates[1] then
                    shouldShow = false
                elseif variationType == "Duo" and not checkboxStates[2] then
                    shouldShow = false
                elseif variationType == "Solo" and not checkboxStates[3] then
                    shouldShow = false
                end
            end
        end
        
        -- Hide/show dungeon set achievements based on checkbox state
        -- Completed dungeon sets always show when "all" or "completed" filter is selected
        if row._def and row._def.isDungeonSet then
            local isCompleted = row.completed == true
            local shouldCheckCheckbox = true
            
            if isCompleted and (currentFilter == "all" or currentFilter == "completed") then
                -- Completed dungeon sets always show with these filters, skip checkbox check
                shouldCheckCheckbox = false
            end
            
            if shouldCheckCheckbox then
                local checkboxStates = { false, false, false, false, false }
                if type(HardcoreAchievements_GetCharDB) == "function" then
                    local _, cdb = HardcoreAchievements_GetCharDB()
                    if cdb and cdb.settings and cdb.settings.filterCheckboxes then
                        local states = cdb.settings.filterCheckboxes
                        if type(states) == "table" then
                            checkboxStates = {
                                states[1] == true,  -- Trio
                                states[2] == true,  -- Duo
                                states[3] == true,  -- Solo
                                states[4] == true,  -- Dungeon Sets
                                states[5] == true,  -- Reputations
                            }
                        end
                    end
                end
                
                -- Check if "Show Dungeon Sets" checkbox (index 4) is enabled
                if not checkboxStates[4] then
                    shouldShow = false
                end
            end
        end
        
        -- Hide/show reputation achievements based on checkbox state
        -- Completed reputation achievements always show when "all" or "completed" filter is selected
        if row._def and row._def.isReputation then
            local isCompleted = row.completed == true
            local shouldCheckCheckbox = true
            
            if isCompleted and (currentFilter == "all" or currentFilter == "completed") then
                -- Completed reputation achievements always show with these filters, skip checkbox check
                shouldCheckCheckbox = false
            end
            
            if shouldCheckCheckbox then
                local checkboxStates = { false, false, false, false, false }
                if type(HardcoreAchievements_GetCharDB) == "function" then
                    local _, cdb = HardcoreAchievements_GetCharDB()
                    if cdb and cdb.settings and cdb.settings.filterCheckboxes then
                        local states = cdb.settings.filterCheckboxes
                        if type(states) == "table" then
                            checkboxStates = {
                                states[1] == true,  -- Trio
                                states[2] == true,  -- Duo
                                states[3] == true,  -- Solo
                                states[4] == true,  -- Dungeon Sets
                                states[5] == true,  -- Reputations
                            }
                        end
                    end
                end
                
                -- Check if "Show Reputations" checkbox (index 5) is enabled
                if not checkboxStates[5] then
                    shouldShow = false
                end
            end
        end
        
        if shouldShow then
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Recalculate and update the row positioning after filtering
    SortAchievementRows()
end

_G.HCA_ApplyFilter = ApplyFilter

-- Create and initialize the filter dropdown
local filterDropdown = FilterDropdown:CreateDropdown(AchievementPanel, "TOPRIGHT", AchievementPanel, -20, -52, 60)
AchievementPanel.filterDropdown = filterDropdown

FilterDropdown:InitializeDropdown(filterDropdown, {
    currentFilter = "all",
    -- checkboxStates will be loaded from database automatically
    checkboxLabels = { "Show Dungeon Trios", "Show Dungeon Duos", "Show Dungeon Solos", "Show Dungeon Sets", "Show Reputations" },
    onFilterChange = function(filterValue)
        ApplyFilter()
    end,
    onCheckboxChange = function(checkboxIndex, newState)
        -- Checkbox state is automatically saved to database in FilterDropdown
        -- Variations are always registered but filtered based on checkbox states
        -- Re-apply filter to show/hide variations when checkbox changes
        ApplyFilter()
    end,
})

--AchievementPanel.Text = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
--AchievementPanel.Text:SetPoint("TOP", 5, -45)
--AchievementPanel.Text:SetText(ACHIEVEMENTS)
--AchievementPanel.Text:SetTextColor(1, 1, 0)

AchievementPanel.TotalPoints = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
AchievementPanel.TotalPoints:SetPoint("TOP", AchievementPanel, "TOP", 0, -55)
AchievementPanel.TotalPoints:SetText("0")
AchievementPanel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)

-- " pts" text (smaller, positioned after the number)
AchievementPanel.PointsLabelText = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
-- Position it to the right of the points number
AchievementPanel.PointsLabelText:SetPoint("LEFT", AchievementPanel.TotalPoints, "RIGHT", 2, 0)
AchievementPanel.PointsLabelText:SetText(" pts")
AchievementPanel.PointsLabelText:SetTextColor(0.6, 0.9, 0.6)

AchievementPanel.CountsText = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
AchievementPanel.CountsText:SetPoint("BOTTOMRIGHT", filterDropdown, "TOPRIGHT", -50, 20)
AchievementPanel.CountsText:SetText("(0/0)")
AchievementPanel.CountsText:SetTextColor(0.8, 0.8, 0.8)

-- Preset multiplier label, e.g. "Point Multiplier (Lite +)"
AchievementPanel.MultiplierText = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
AchievementPanel.MultiplierText:SetPoint("TOP", 15, -40)
AchievementPanel.MultiplierText:SetText("")
AchievementPanel.MultiplierText:SetTextColor(0.8, 0.8, 0.8)

-- Solo mode checkbox
AchievementPanel.SoloModeCheckbox = CreateFrame("CheckButton", nil, AchievementPanel, "InterfaceOptionsCheckButtonTemplate")
AchievementPanel.SoloModeCheckbox:SetPoint("TOPLEFT", AchievementPanel, "TOPLEFT", 70, -50)
AchievementPanel.SoloModeCheckbox.Text:SetText("SSF")
AchievementPanel.SoloModeCheckbox:SetScript("OnClick", function(self)
    if self:IsEnabled() then
        local isChecked = self:GetChecked()
        local _, cdb = GetCharDB()
        if cdb and cdb.settings then
            cdb.settings.soloAchievements = isChecked
            -- Refresh all achievement points immediately
            if RefreshAllAchievementPoints then
                RefreshAllAchievementPoints()
            end
        end
    end
end)
AchievementPanel.SoloModeCheckbox:SetScript("OnEnter", function(self)
    if self.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end
end)
AchievementPanel.SoloModeCheckbox:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

AchievementPanel.SettingsButton = CreateFrame("Button", nil, AchievementPanel)
AchievementPanel.SettingsButton:SetSize(14, 14)
AchievementPanel.SettingsButton:SetPoint("BOTTOMLEFT", AchievementPanel.SoloModeCheckbox, "TOPLEFT", 6, 18)
AchievementPanel.SettingsButton.Icon = AchievementPanel.SettingsButton:CreateTexture(nil, "ARTWORK")
AchievementPanel.SettingsButton.Icon:SetAllPoints(AchievementPanel.SettingsButton)
AchievementPanel.SettingsButton.Icon:SetTexture(SETTINGS_ICON_TEXTURE)
AchievementPanel.SettingsButton.Icon:SetVertexColor(1, 0.82, 0.0)
AchievementPanel.SettingsButton:SetScript("OnClick", function()
    OpenOptionsPanel()
end)
AchievementPanel.SettingsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open Options", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)
AchievementPanel.SettingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Scrollable container inside the AchievementPanel
AchievementPanel.Scroll = CreateFrame("ScrollFrame", "$parentScroll", AchievementPanel, "UIPanelScrollFrameTemplate")
AchievementPanel.Scroll:SetPoint("TOPLEFT", 30, -80)      -- adjust to taste
AchievementPanel.Scroll:SetPoint("BOTTOMRIGHT", -65, 85)  -- leaves room for the scrollbar
AchievementPanel.Scroll:SetClipsChildren(false) -- Allow borders to extend into padding space

-- Clipping frame for borders: allows horizontal extension but clips top/bottom
-- Extends left/right to allow padding space, but clips top/bottom to prevent overflow
AchievementPanel.BorderClip = CreateFrame("Frame", nil, AchievementPanel)
AchievementPanel.BorderClip:SetPoint("TOPLEFT", AchievementPanel.Scroll, "TOPLEFT", -10, 2)  -- Allow left padding, clip top
AchievementPanel.BorderClip:SetPoint("BOTTOMRIGHT", AchievementPanel.Scroll, "BOTTOMRIGHT", 10, -2)  -- Allow right padding, clip bottom
AchievementPanel.BorderClip:SetClipsChildren(true) -- Clip borders to this frame's boundaries

-- The content frame that actually holds rows
AchievementPanel.Content = CreateFrame("Frame", nil, AchievementPanel.Scroll)
AchievementPanel.Content:SetPoint("TOPLEFT")
AchievementPanel.Content:SetSize(1, 1)  -- will grow as rows are added
AchievementPanel.Scroll:SetScrollChild(AchievementPanel.Content)

AchievementPanel.Content:SetWidth(AchievementPanel.Scroll:GetWidth())
AchievementPanel.Scroll:SetScript("OnSizeChanged", function(self)
    AchievementPanel.Content:SetWidth(self:GetWidth())
    self:UpdateScrollChildRect()
end)

-- AchievementPanel.PortraitCover = AchievementPanel:CreateTexture(nil, "OVERLAY")
-- AchievementPanel.PortraitCover:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png")
-- AchievementPanel.PortraitCover:SetSize(75, 75)
-- AchievementPanel.PortraitCover:SetPoint("TOPLEFT", CharacterFramePortrait, "TOPLEFT", -5, 6)
-- AchievementPanel.PortraitCover:Show()

-- Optional: mouse wheel support
AchievementPanel.Scroll:EnableMouseWheel(true)
AchievementPanel.Scroll:SetScript("OnMouseWheel", function(self, delta)
  local step = 36
  local cur  = self:GetVerticalScroll()
    local maxV = self:GetVerticalScrollRange() or 0
    local newV = math.min(maxV, math.max(0, cur - delta * step))
    self:SetVerticalScroll(newV)

    local sb = self.ScrollBar or (self:GetName() and _G[self:GetName().."ScrollBar"])
    if sb then sb:SetValue(newV) end
end)

AchievementPanel.Scroll:SetScript("OnScrollRangeChanged", function(self, xRange, yRange)
    yRange = yRange or 0
    local cur = self:GetVerticalScroll()
    if cur > yRange then
        self:SetVerticalScroll(yRange)
    elseif cur < 0 then
        self:SetVerticalScroll(0)
    end
    local sb = self.ScrollBar or (self:GetName() and _G[self:GetName().."ScrollBar"])
    if sb then
        sb:SetMinMaxValues(0, yRange)
        sb:SetValue(self:GetVerticalScroll())
    end
end)

-- 4-quadrant PaperDoll art
local TL = AchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
TL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
TL:SetPoint("TOPLEFT", 2, -1)
TL:SetSize(256, 256)

local TR = AchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
TR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
TR:SetPoint("TOPLEFT", TL, "TOPRIGHT", 0, 0)
TR:SetPoint("RIGHT", AchievementPanel, "RIGHT", 2, -1) -- stretch to the right edge if needed
TR:SetHeight(256)

local BL = AchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
BL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
BL:SetPoint("TOPLEFT", TL, "BOTTOMLEFT", 0, 0)
BL:SetPoint("BOTTOMLEFT", AchievementPanel, "BOTTOMLEFT", 2, -1) -- stretch down if needed
BL:SetWidth(256)

local BR = AchievementPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
BR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
BR:SetPoint("TOPLEFT", BL, "TOPRIGHT", 0, 0)
BR:SetPoint("LEFT", TR, "LEFT", 0, 0)
BR:SetPoint("BOTTOMRIGHT", AchievementPanel, "BOTTOMRIGHT", 2, -1)

-- =========================================================
-- Creating the functionality of achievements
-- =========================================================

AchievementPanel.achievements = AchievementPanel.achievements or {}

function CreateAchievementRow(parent, achId, title, tooltip, icon, level, points, killTracker, questTracker, staticPoints, zone, def)
    local rowParent = AchievementPanel and AchievementPanel.Content or parent or AchievementPanel
    AchievementPanel.achievements = AchievementPanel.achievements or {}

    local index = (#AchievementPanel.achievements) + 1
    local row = CreateFrame("Frame", nil, rowParent)
    row:SetSize(310, 42)
    row:SetClipsChildren(false) -- Allow IconFrame to extend beyond row bounds if needed

    -- stack under title or previous row
    if index == 1 then
        row:SetPoint("TOPLEFT", rowParent, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", AchievementPanel.achievements[index-1], "BOTTOMLEFT", 0, 0)
    end

    -- icon
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(30, 30)
    row.Icon:SetPoint("LEFT", row, "LEFT", 1, 0) -- Shift to account for SSF border
    row.Icon:SetTexture(icon or 136116)
    
    -- Icon overlay (for failed state - red X)
    row.IconOverlay = row:CreateTexture(nil, "OVERLAY")
    row.IconOverlay:SetSize(20, 20) -- Same size as points checkmark
    row.IconOverlay:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconOverlay:Hide() -- Hidden by default

    -- IconFrame overlays (gold for completed, disabled for failed, silver for available)
    -- Gold frame (completed)
    row.IconFrameGold = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrameGold:SetSize(33, 33)
    row.IconFrameGold:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrameGold:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_gold.png")
    row.IconFrameGold:SetDrawLayer("OVERLAY", 1)
    row.IconFrameGold:Hide()
    
    -- Silver frame (available/failed) - default
    row.IconFrame = row:CreateTexture(nil, "OVERLAY", nil, 7)
    row.IconFrame:SetSize(33, 33)
    row.IconFrame:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.IconFrame:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\frame_silver.png")
    row.IconFrame:SetDrawLayer("OVERLAY", 1)
    row.IconFrame:Show()

    -- title
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetText(title or ("Achievement %d"):format(index))
    row.Title:SetTextColor(1, 1, 1) -- Default white (will be updated by UpdatePointsDisplay)
    
    -- title drop shadow (strip color codes so shadow is always black)
    row.TitleShadow = row:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    row.TitleShadow:SetText(StripColorCodes(title or ("Achievement %d"):format(index)))
    row.TitleShadow:SetTextColor(0, 0, 0, 0.5) -- Black with 50% opacity for shadow
    row.TitleShadow:SetDrawLayer("BACKGROUND", 0) -- Behind the main title

    -- subtitle / progress
    row.Sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
    row.Sub:SetWidth(265)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetJustifyV("TOP")
    row.Sub:SetWordWrap(true)
    row.Sub:SetTextColor(0.5, 0.5, 0.5) -- Default gray (will be updated by UpdatePointsDisplay)
    do
        local capNum = tonumber(level)
        if capNum and capNum > 0 then
            row.Sub:SetText(LEVEL .. " " .. capNum)
        else
            row.Sub:SetText("")
        end
    end
    if row.Sub then
        row._defaultSubText = row.Sub:GetText() or ""
    end
    HookRowSubTextUpdates(row)
    row.UpdateTextLayout = UpdateRowTextLayout
    UpdateRowTextLayout(row)

    -- Circular frame for points
    row.PointsFrame = CreateFrame("Frame", nil, row)
    row.PointsFrame:SetSize(42, 42)
    row.PointsFrame:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    
    row.PointsFrame.Texture = row.PointsFrame:CreateTexture(nil, "BACKGROUND")
    row.PointsFrame.Texture:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\ring_disabled.png")
    row.PointsFrame.Texture:SetAllPoints(row.PointsFrame)
    row.PointsFrame.Texture:SetAlpha(1)
    
    -- Variation overlay texture (solo/duo/trio) - appears on top of ring texture
    row.PointsFrame.VariationOverlay = row.PointsFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    -- Set size (width, height) and position (x, y offsets from center)
    row.PointsFrame.VariationOverlay:SetSize(44, 38)  -- Width, Height
    row.PointsFrame.VariationOverlay:SetPoint("CENTER", row.PointsFrame, "CENTER", -6, 1)  -- X offset, Y offset
    row.PointsFrame.VariationOverlay:SetAlpha(0.8)
    row.PointsFrame.VariationOverlay:Hide()
    
    -- Points text (number only, no "pts")
    row.Points = row.PointsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Points:SetPoint("CENTER", row.PointsFrame, "CENTER", 0, 0)
    row.Points:SetText(tostring(points or 0))
    row.Points:SetTextColor(1, 1, 1)
    
    -- Checkmark texture (for completed/failed states)
    row.PointsFrame.Checkmark = row.PointsFrame:CreateTexture(nil, "OVERLAY")
    row.PointsFrame.Checkmark:SetSize(14, 14)
    row.PointsFrame.Checkmark:SetPoint("CENTER", row.PointsFrame, "CENTER", 0, 0)
    row.PointsFrame.Checkmark:Hide()

    -- timestamp
    row.TS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.TS:SetPoint("RIGHT", row.PointsFrame, "LEFT", -10, 0)
    row.TS:SetJustifyH("RIGHT")
    row.TS:SetJustifyV("TOP")
    row.TS:SetText("")
    row.TS:SetTextColor(1, 1, 1)

    -- background + border textures (clipped to BorderClip frame)
    row.Background = AchievementPanel.BorderClip:CreateTexture(nil, "BACKGROUND")
    row.Background:SetDrawLayer("BACKGROUND", 0)
    row.Background:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.png")
    row.Background:SetVertexColor(1, 1, 1)
    row.Background:SetAlpha(1)
    row.Background:Hide()
    
    row.Border = AchievementPanel.BorderClip:CreateTexture(nil, "BACKGROUND")
    row.Border:SetDrawLayer("BACKGROUND", 1)
    row.Border:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row-border.png")
    row.Border:SetSize(256, 32)
    row.Border:SetAlpha(0.5)
    row.Border:Hide()
    
    -- highlight/tooltip
    row:EnableMouse(true)
    row.highlight = AchievementPanel.BorderClip:CreateTexture(nil, "BACKGROUND", nil, 0)
    row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
    row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -20, -1)
    row.highlight:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\row_texture.png")
    row.highlight:SetVertexColor(1, 1, 1, 0.75)
    row.highlight:SetBlendMode("ADD")
    row.highlight:Hide()

    row:SetScript("OnEnter", function(self)
        if self.highlight then
            self.highlight:SetVertexColor(1, 1, 1, 0.75)
        end
        self.highlight:Show()

        if self.Title and self.Title.GetText then
            -- Use centralized tooltip function
            if _G.HCA_ShowAchievementTooltip then
                _G.HCA_ShowAchievementTooltip(row, self)
            end
        end
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    
    -- Store reference to row data for centralized tooltip function
    row._achId = achId
    row._title = title
    row._tooltip = tooltip
    row._def = def

    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and row.achId then
            local editBox = ChatEdit_GetActiveWindow()
            
            -- Check if chat edit box is active/visible
            if editBox and editBox:IsVisible() then
                -- Chat edit box is active: link achievement (original behavior)
                local bracket = _G.HCA_GetAchievementBracket and _G.HCA_GetAchievementBracket(row.achId) or string.format("[HCA:(%s)]", tostring(row.achId))
                local currentText = editBox:GetText() or ""
                if currentText == "" then
                    editBox:SetText(bracket)
                else
                    editBox:SetText(currentText .. " " .. bracket)
                end
                editBox:SetFocus()
            else
                -- Chat edit box is NOT active: track/untrack achievement
                local AchievementTracker = GetAchievementTracker()
                if not AchievementTracker then
                    print("|cffff0000[Hardcore Achievements]|r Achievement tracker not available. Please reload your UI (/reload).")
                    return
                end
                
                local achId = row.achId or row.id
                if not achId then
                    return
                end
                
                local title = row.Title and row.Title:GetText() or tostring(achId)
                -- Strip color codes from title if present
                title = title and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or tostring(achId)
                local isTracked = AchievementTracker:IsTracked(achId)
                
                if isTracked then
                    AchievementTracker:UntrackAchievement(achId)
                    --print("|cff69adc9[Hardcore Achievements]|r Stopped tracking: " .. title)
                else
                    AchievementTracker:TrackAchievement(achId, title)
                    --print("|cff69adc9[Hardcore Achievements]|r Now tracking: " .. title)
                end
            end
        end
    end)

    row.originalPoints = points or 0  -- Store original points before any multipliers
    row.staticPoints = staticPoints or false  -- Store static points flag
    row.points = (points or 0)
    row.completed = false
    do
        local capNum = tonumber(level)
        row.maxLevel = (capNum and capNum > 0) and capNum or nil
    end
    row.tooltip = tooltip  -- Store the tooltip for later access
    row.zone = zone  -- Store the zone for later access
    row.achId = achId
    row._def = def  -- Store def for filtering variations and other checks
    
    if def and def.requiredQuestId then
        TrackRowForQuest(row, def.requiredQuestId)
    end

    if def and def.mapID then
        row.zone = nil
    end
    -- Apply icon/frame styling for initial state
    ApplyOutleveledStyle(row)

    -- store trackers
    row.killTracker  = killTracker
    row.questTracker = questTracker
    row.id = achId
    -- Store solo doubling flag (defaults to true if killTracker exists for backward compatibility)
    if def and def.allowSoloDouble ~= nil then
        row.allowSoloDouble = def.allowSoloDouble
    else
        row.allowSoloDouble = (killTracker ~= nil)
    end
    
    if def and type(def.customSpell) == "function" then
        row.spellTracker = def.customSpell
    end
    if def and type(def.customAura) == "function" then
        row.auraTracker = def.customAura
    end
    if def and type(def.customChat) == "function" then
        row.chatTracker = def.customChat
    end
    if def and type(def.customEmote) == "function" then
        row.emoteTracker = def.customEmote
    end
    if def and type(def.customIsCompleted) == "function" then
        row.customIsCompleted = def.customIsCompleted
    end
    if def and def.hiddenUntilComplete == true then
        row.hiddenUntilComplete = true
        -- Hide initially; filter logic will show it after completion
        row:Hide()
    end
    if def and def.requireProfessionSkillID then
        row.hiddenByProfession = true
        row._professionHiddenUntilComplete = row.hiddenUntilComplete
        row._professionSkillID = def.requireProfessionSkillID
        if row.Sub then
            row.Sub:SetText("")
            row._defaultSubText = ""
        end
    end
    if ProfessionTracker and def and def.requireProfessionSkillID then
        ProfessionTracker.RegisterRow(row, def)
    end

    -- Secret/hidden achievement support (optional via def)
    if def and (def.secret or def.secretTitle or def.secretTooltip or def.secretIcon or def.secretPoints) then
        row.isSecretAchievement = true
        -- Store reveal values (final state after completion)
        row.revealTitle = title
        row.revealTooltip = tooltip
        row.revealIcon = icon or 136116
        row.revealPointsBase = points or 0
        row.revealStaticPoints = staticPoints or false

        -- Store secret placeholder values (pre-completion)
        row.secretTitle = def.secretTitle or "Secret"
        row.secretTooltip = def.secretTooltip or "Hidden"
        row.secretIcon = def.secretIcon or 134400 -- question mark icon
        row.secretPoints = tonumber(def.secretPoints) or 0

        -- Apply secret placeholder visuals initially
        if row.Title then 
            row.Title:SetText(row.secretTitle)
            if row.TitleShadow then row.TitleShadow:SetText(StripColorCodes(row.secretTitle)) end
        end
        row.tooltip = row.secretTooltip
        if row.Icon then row.Icon:SetTexture(row.secretIcon) end
        row.points = row.secretPoints
        if row.Points then row.Points:SetText(tostring(row.secretPoints)) end
        -- Prevent multipliers from inflating placeholder points
        row.staticPoints = true
    end

    AchievementPanel.achievements[index] = row
    SortAchievementRows()
    HCA_UpdateTotalPoints()

    return row
end

EvaluateCustomCompletions = function(newLevel)
    if not AchievementPanel or not AchievementPanel.achievements then return end

    local anyCompleted = false
    for _, row in ipairs(AchievementPanel.achievements) do
        if not row.completed then
            local fn = row.customIsCompleted
            if type(fn) ~= "function" then
                local id = row.id or row.achId
                if id then
                    fn = _G[id .. "_IsCompleted"]
                end
            end

            if type(fn) == "function" then
                local ok, result = pcall(fn, newLevel)
                if ok and result == true then
                    HCA_MarkRowCompleted(row)
                    HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                    anyCompleted = true
                end
            end
        end
    end

    if anyCompleted then
        RefreshOutleveledAll()
    end
end

-- =========================================================
-- Event bridge: forward PARTY_KILL to any rows with a tracker
-- =========================================================

do
    if not AchievementPanel._achEvt then
        AchievementPanel._achEvt = CreateFrame("Frame")
        -- Track recently processed kills to prevent duplicate processing
        local recentKills = {}
        local function clearRecentKill(destGUID)
            C_Timer.After(1, function()
                recentKills[destGUID] = nil
            end)
        end
        
        -- Track NPCs the player is fighting (for achievements)
        -- Only process kills if the player was actually fighting the NPC
        local npcsInCombat = {}  -- [destGUID] = true when player is fighting this NPC
        
        -- Track external players (non-party) that are fighting tracked NPCs
        -- externalPlayersByNPC[destGUID] = { [playerGUID] = { lastSeen = time, threat = nil } }
        local externalPlayersByNPC = {}
        local EXTERNAL_PLAYER_TIMEOUT = 15  -- seconds to remember external players after last damage event
        
        -- Cache recent level-ups to handle event ordering issues with quest turn-ins
        -- Stores the previous level when player levels up, so we can use it if a quest turn-in happens shortly after
        local recentLevelUpCache = nil  -- { previousLevel = number, timestamp = number }
        local LEVEL_UP_WINDOW = 1.0  -- seconds - window to consider a level-up as quest-related

        -- Dedicated support for the Rats achievement: NPC IDs that qualify
        local RAT_NPC_IDS = {
            [4075] = true,
            [13016] = true,
            [2110] = true,
        }

        -- Damage events that include overkill information for player attacks
        local DAMAGE_SUBEVENTS = {
            SWING_DAMAGE = true,
            SPELL_DAMAGE = true,
            SPELL_PERIODIC_DAMAGE = true,
            RANGE_DAMAGE = true,
        }

        local function getNpcIdFromGUID(guid)
            if not guid then
                return nil
            end
            local _, _, _, _, _, npcId = strsplit("-", guid)
            return npcId and tonumber(npcId) or nil
        end

        -- Check if a GUID belongs to a pet and return the owner's GUID if it's the player's or party member's pet
        -- In Classic WoW, pet GUIDs are "Creature-" and change each summon, so we check pet units directly
        local function getPetOwnerGUID(sourceGUID)
            if not sourceGUID then
                return nil
            end
            
            -- Check if it's the player's pet
            if UnitExists("pet") then
                local playerPetGUID = UnitGUID("pet")
                if playerPetGUID and playerPetGUID == sourceGUID then
                    return UnitGUID("player")
                end
            end
            
            -- Check if it's a party member's pet
            if GetNumGroupMembers() > 1 then
                for i = 1, 4 do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        local partyPetUnit = unit .. "pet"
                        if UnitExists(partyPetUnit) then
                            local partyPetGUID = UnitGUID(partyPetUnit)
                            if partyPetGUID and partyPetGUID == sourceGUID then
                                return UnitGUID(unit)
                            end
                        end
                    end
                end
            end
            
            return nil
        end

        -- Helper function to check if a GUID belongs to player or party member
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
        
        -- Helper function to check if an NPC is tracked by any achievement
        local function isNpcTrackedForAchievement(npcId)
            if not npcId then
                return false
            end
            -- Check for Rats achievement
            if RAT_NPC_IDS[npcId] then
                return true
            end
            -- Check if any achievement has a killTracker (tracks NPCs)
            if AchievementPanel and AchievementPanel.achievements then
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.killTracker) == "function" then
                        return true
                    end
                end
            end
            return false
        end
        
        -- Cleanup old external player tracking entries
        local function cleanupExternalPlayers()
            local now = GetTime()
            for destGUID, players in pairs(externalPlayersByNPC) do
                local anyValid = false
                for playerGUID, data in pairs(players) do
                    if now - data.lastSeen > EXTERNAL_PLAYER_TIMEOUT then
                        players[playerGUID] = nil
                    else
                        anyValid = true
                    end
                end
                if not anyValid then
                    externalPlayersByNPC[destGUID] = nil
                end
            end
        end
        
        -- Update threat data for tracked external players when possible
        local function updateExternalPlayerThreat(destGUID)
            if not externalPlayersByNPC[destGUID] then
                return
            end
            
            -- Only update threat if the NPC is currently our target
            if not UnitExists("target") or UnitGUID("target") ~= destGUID then
                return
            end
            
            local targetUnit = "target"
            if not UnitCanAttack("player", targetUnit) then
                return
            end
            
            local now = GetTime()
            for playerGUID, data in pairs(externalPlayersByNPC[destGUID]) do
                -- Try to get unit token for this player
                local unitToken = UnitTokenFromGUID(playerGUID)
                if unitToken and UnitExists(unitToken) then
                    -- Check threat for this external player
                    local isTanking, status, scaledPct, rawPct = UnitDetailedThreatSituation(unitToken, targetUnit)
                    if isTanking and status and status >= 2 then
                        -- Tanking (status >= 2) means they're the primary target - definitely high threat
                        data.threat = 100
                        data.isTanking = true
                    elseif scaledPct then
                        data.threat = scaledPct
                        data.isTanking = false
                    elseif rawPct then
                        data.threat = rawPct
                        data.isTanking = false
                    else
                        data.threat = 0
                        data.isTanking = false
                    end
                    data.lastSeen = now
                end
            end
        end

        local function processKill(destGUID)
            if not destGUID or recentKills[destGUID] then
                return
            end

            recentKills[destGUID] = true
            clearRecentKill(destGUID)

            if not (AchievementPanel and AchievementPanel.achievements) then
                return
            end

            for _, row in ipairs(AchievementPanel.achievements) do
                if not row.completed and type(row.killTracker) == "function" then
                    if row.killTracker(destGUID) then
                        HCA_MarkRowCompleted(row)
                        HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                    end
                end
            end
            
            -- Clean up external player tracking for this NPC after kill
            externalPlayersByNPC[destGUID] = nil
        end
        
        -- Expose function to get external players for an NPC (for use by IsGroupEligibleForAchievement)
        _G.GetExternalPlayersForNPC = function(destGUID)
            if not destGUID then
                return {}
            end
            cleanupExternalPlayers()
            
            -- Try to update threat data one last time before returning (if NPC is still targetable)
            if UnitExists("target") and UnitGUID("target") == destGUID and UnitCanAttack("player", "target") then
                updateExternalPlayerThreat(destGUID)
            end
            
            return externalPlayersByNPC[destGUID] or {}
        end
        
        AchievementPanel._achEvt:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        AchievementPanel._achEvt:RegisterEvent("QUEST_ACCEPTED")
        AchievementPanel._achEvt:RegisterEvent("QUEST_TURNED_IN")
        AchievementPanel._achEvt:RegisterEvent("QUEST_REMOVED")
        AchievementPanel._achEvt:RegisterEvent("UNIT_SPELLCAST_SENT")
        AchievementPanel._achEvt:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        AchievementPanel._achEvt:RegisterEvent("UNIT_INVENTORY_CHANGED")
        AchievementPanel._achEvt:RegisterEvent("BAG_UPDATE")
        AchievementPanel._achEvt:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
        AchievementPanel._achEvt:RegisterEvent("PLAYER_LEVEL_CHANGED")
        AchievementPanel._achEvt:RegisterEvent("CHAT_MSG_LOOT")
        AchievementPanel._achEvt:RegisterEvent("PLAYER_DEAD")
        AchievementPanel._achEvt:RegisterEvent("PLAYER_REGEN_ENABLED")
        AchievementPanel._achEvt:RegisterEvent("PLAYER_ENTERING_WORLD")
        AchievementPanel._achEvt:RegisterEvent("UPDATE_FACTION")
        AchievementPanel._achEvt:RegisterEvent("UNIT_AURA")
        AchievementPanel._achEvt:SetScript("OnEvent", function(_, event, ...)
            -- Clean up external player tracking on zone loads
            if event == "PLAYER_ENTERING_WORLD" then
                externalPlayersByNPC = {}
                npcsInCombat = {}
                return
            end
            -- Clean up combat tracking when combat ends
            if event == "PLAYER_REGEN_ENABLED" then
                -- Clear combat tracking after a short delay (in case we're still processing events)
                C_Timer.After(2, function()
                    -- Only clear if we're not in combat anymore
                    if not UnitAffectingCombat("player") then
                        npcsInCombat = {}
                        -- Clean up old external player tracking (keep recent ones for a bit longer)
                        cleanupExternalPlayers()
                    end
                end)
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, param12, param13, param14, param15, param16 = CombatLogGetCurrentEventInfo()
                --DevTools_Dump(COMBAT_LOG_EVENT_UNFILTERED)
                
                -- Debug: Print threat situation for player when damage events occur
                -- if DAMAGE_SUBEVENTS[subevent] and UnitExists("target") then
                --     print("[CLEU Debug]", subevent, "| Threat:", UnitDetailedThreatSituation("player", "target"))
                -- end
                if subevent == "PARTY_KILL" then
                    -- PARTY_KILL fires for player/party member kills
                    -- Only process if we were fighting this NPC (prevents tracking kills we had no part in)
                    if npcsInCombat[destGUID] then
                        processKill(destGUID)
                        -- Clean up combat tracking
                        npcsInCombat[destGUID] = nil
                    end
                elseif DAMAGE_SUBEVENTS[subevent] then
                    local playerGUID = UnitGUID("player")
                    local shouldProcess = false
                    
                    -- Check if source is the player
                    if playerGUID and sourceGUID == playerGUID then
                        shouldProcess = true
                    -- Check if source is a party member
                    elseif sourceGUID and GetNumGroupMembers() > 1 then
                        for i = 1, 4 do
                            local unit = "party" .. i
                            if UnitExists(unit) then
                                local partyMemberGUID = UnitGUID(unit)
                                if partyMemberGUID and sourceGUID == partyMemberGUID then
                                    shouldProcess = true
                                    break
                                end
                            end
                        end
                    end
                    
                    -- Check if source is a pet (player's or party member's)
                    -- This catches pet kills that don't trigger PARTY_KILL
                    if not shouldProcess then
                        local ownerGUID = getPetOwnerGUID(sourceGUID)
                        if ownerGUID then
                            shouldProcess = true
                        end
                    end
                    
                    if shouldProcess and destGUID then
                        -- Player/party member/pet damage - track that we're fighting this NPC
                        local npcId = getNpcIdFromGUID(destGUID)
                        if npcId then
                            -- Check if any achievement tracks this NPC
                            local isTracked = false
                            if AchievementPanel and AchievementPanel.achievements then
                                for _, row in ipairs(AchievementPanel.achievements) do
                                    if not row.completed and type(row.killTracker) == "function" then
                                        isTracked = true
                                        break
                                    end
                                end
                            end
                            -- Mark that we're fighting this tracked NPC
                            if isTracked or (npcId and RAT_NPC_IDS[npcId]) then
                                npcsInCombat[destGUID] = true
                                -- Update threat for any tracked external players
                                updateExternalPlayerThreat(destGUID)
                            end
                        end
                        
                        -- If overkill is present (>= 0), the target died from this damage
                        -- This catches kills that don't trigger PARTY_KILL (e.g., pet kills, DoT kills)
                        local overkill = subevent == "SWING_DAMAGE" and param13 or param16
                        if overkill and overkill >= 0 then
                            -- Update threat for external players RIGHT BEFORE processing kill
                            -- This ensures we have the most recent threat data when checking eligibility
                            if npcsInCombat[destGUID] then
                                updateExternalPlayerThreat(destGUID)
                            end
                            
                            -- Check for Rats achievement NPCs
                            if npcId and RAT_NPC_IDS[npcId] then
                                processKill(destGUID)
                            -- Check if this is a tracked boss (any achievement with a killTracker)
                            elseif npcId then
                                -- Check if any achievement tracks this NPC
                                local isTracked = false
                                if AchievementPanel and AchievementPanel.achievements then
                                    for _, row in ipairs(AchievementPanel.achievements) do
                                        if not row.completed and type(row.killTracker) == "function" then
                                            -- This achievement has a kill tracker, let processKill check if it matches
                                            isTracked = true
                                            break
                                        end
                                    end
                                end
                                if isTracked then
                                    processKill(destGUID)
                                end
                            end
                        end
                    elseif not shouldProcess and destGUID then
                        -- This is damage from a non-player, non-party source (or external player)
                        local npcId = getNpcIdFromGUID(destGUID)
                        
                        -- Check if source is an external player (not in our party)
                        local guidType = sourceGUID and select(1, strsplit("-", sourceGUID))
                        local isExternalPlayer = guidType == "Player" and not isPlayerOrPartyMember(sourceGUID)
                        
                        -- Track external players fighting tracked NPCs
                        if isExternalPlayer and npcId and isNpcTrackedForAchievement(npcId) then
                            local now = GetTime()
                            if not externalPlayersByNPC[destGUID] then
                                externalPlayersByNPC[destGUID] = {}
                            end
                            
                            local playerData = externalPlayersByNPC[destGUID][sourceGUID]
                            if not playerData then
                                playerData = { lastSeen = now, threat = nil }
                                externalPlayersByNPC[destGUID][sourceGUID] = playerData
                            else
                                playerData.lastSeen = now
                            end
                            
                            -- Try to update threat if NPC is currently our target
                            if npcsInCombat[destGUID] then
                                updateExternalPlayerThreat(destGUID)
                            end
                        end
                        
                        -- Check if this is a kill by a non-party player
                        -- Only process if the player was fighting this NPC
                        if not npcsInCombat[destGUID] then
                            -- Player wasn't fighting this NPC, ignore the kill
                            -- (This prevents tracking kills the player had no part in)
                        else
                            -- If overkill is present (>= 0), the target died from this damage
                            local overkill = subevent == "SWING_DAMAGE" and param13 or param16
                            if overkill and overkill >= 0 then
                                if isExternalPlayer and npcId then
                                    local isTracked = isNpcTrackedForAchievement(npcId)
                                    
                                    if isTracked then
                                        -- A non-party player got the kill while we were fighting this NPC
                                        -- Process the kill - the killTracker will check eligibility
                                        -- PlayerIsSolo tracks if non-party players helped (via threat)
                                        -- If they helped significantly (>10% threat), it will mark as ineligible
                                        processKill(destGUID)
                                        
                                        -- Clean up combat tracking
                                        npcsInCombat[destGUID] = nil
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Track threat/solo status during combat for tracked NPCs
                    -- This ensures we have solo status available when PARTY_KILL fires
                    -- Update for both player damage and external player damage to tracked NPCs
                    if destGUID then
                        local npcId = getNpcIdFromGUID(destGUID)
                        if npcId and isNpcTrackedForAchievement(npcId) then
                            local playerGUID = UnitGUID("player")
                            local isPlayerDamage = sourceGUID == playerGUID
                            local isExternalPlayerDamage = false
                            
                            if not isPlayerDamage and sourceGUID then
                                local guidType = select(1, strsplit("-", sourceGUID))
                                isExternalPlayerDamage = guidType == "Player" and not isPlayerOrPartyMember(sourceGUID)
                            end
                            
                            -- Update solo status if this is a tracked NPC and we're in combat
                            if (isPlayerDamage or isExternalPlayerDamage) and UnitAffectingCombat("player") then
                                -- Check if this is our current target
                                if UnitExists("target") and UnitGUID("target") == destGUID then
                                    -- Update threat for external players
                                    if isExternalPlayerDamage then
                                        updateExternalPlayerThreat(destGUID)
                                    end
                                    -- Update solo status
                                    if _G.PlayerIsSolo_UpdateStatusForGUID then
                                        _G.PlayerIsSolo_UpdateStatusForGUID(destGUID)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif event == "QUEST_ACCEPTED" then
                -- arg2 is the QuestId
                local questID = select(2, ...)
                questID = questID and tonumber(questID) or nil
                if questID and HardcoreAchievements_SetProgress then
                    -- Store player's level when quest is accepted as a backup reference
                    -- This helps prevent achievements from failing if player levels up between accepting and turning in
                    local acceptLevel = UnitLevel("player") or 1
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if not row.completed then
                            -- Check if this achievement tracks this quest by comparing questID directly
                            -- Don't call questTracker as it processes the quest and can complete the achievement
                            local rowQuestId = row.requiredQuestId
                            if rowQuestId and tonumber(rowQuestId) == questID then
                                -- Store levelAtAccept as a backup (will be overwritten by levelAtKill or levelAtTurnIn on fulfillment)
                                HardcoreAchievements_SetProgress(row.id, "levelAtAccept", acceptLevel)
                            end
                        end
                    end
                end
            elseif event == "QUEST_TURNED_IN" then
                local questID = select(1, ...)
                questID = questID and tonumber(questID) or nil
                local currentTime = GetTime()
                
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.questTracker) == "function" then
                        -- Before calling questTracker, ensure we have a level stored for validation
                        -- Check if player just leveled up within the window - if so, use the previous level
                        if HardcoreAchievements_SetProgress then
                            local progressTable = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
                            -- Only set levelAtTurnIn if we don't already have levelAtKill (for achievements without kill requirements)
                            if not (progressTable and progressTable.levelAtKill) then
                                local currentLevel = UnitLevel("player") or 1
                                local levelToStore = currentLevel
                                
                                -- Check if there was a recent level-up within the time window
                                if recentLevelUpCache and (currentTime - recentLevelUpCache.timestamp) <= LEVEL_UP_WINDOW then
                                    -- Player leveled up recently - use the previous level as the "true" turn-in level
                                    -- This handles the case where the quest XP causes the level-up
                                    levelToStore = recentLevelUpCache.previousLevel
                                else
                                    -- No recent level-up, or it was outside the window - check if levelAtAccept might be better
                                    -- Only use levelAtAccept if current level matches (player hasn't leveled since accept)
                                    local levelAtAccept = progressTable and progressTable.levelAtAccept
                                    if levelAtAccept and currentLevel == levelAtAccept then
                                        levelToStore = levelAtAccept
                                    end
                                end
                                
                                HardcoreAchievements_SetProgress(row.id, "levelAtTurnIn", levelToStore)
                            end
                        end
                        
                        local questMatched = row.questTracker(questID)
                        if questMatched then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end
                
                -- Clear the level-up cache after processing quest turn-in
                recentLevelUpCache = nil
            elseif event == "UNIT_SPELLCAST_SENT" then
                -- Classic signature: unit, targetName, castGUID, spellId
                local unit, targetName, castGUID, spellId = ...
                if unit ~= "player" then return end
                if spellId ~= 21343 and spellId ~= 16589 then return end
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.spellTracker) == "function" then
                        -- Evaluate tracker and require true return value
                        local ok, shouldComplete = pcall(row.spellTracker, tonumber(spellId), tostring(targetName or ""))
                        if ok and shouldComplete == true then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                local unit, castGUID, spellId = ...
                if unit ~= "player" then return end
                if spellId ~= 11435 then return end
                -- Only check MalletZF achievement for this specific spell
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and (row.id == "MalletZF" or row.achId == "MalletZF") then
                        HCA_MarkRowCompleted(row)
                        HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                    end
                end
            elseif event == "UNIT_AURA" then
                local unit = select(1, ...)
                if unit ~= "player" then return end
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.auraTracker) == "function" then
                        local ok, shouldComplete = pcall(row.auraTracker)
                        if ok and shouldComplete == true then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                            break -- Achievement completed, no need to check others
                        end
                    end
                end
            elseif event == "UNIT_INVENTORY_CHANGED" then
                local unit = ...
                if unit ~= "player" then return end
                
                -- Handle DefiasMask achievement (specific item check)
                local _, classFile = UnitClass("player")
                if classFile == "ROGUE" then
                    local headSlotItemId = GetInventoryItemID("player", 1)
                    if headSlotItemId == 7997 then
                        for _, row in ipairs(AchievementPanel.achievements) do
                            if not row.completed and (row.id == "DefiasMask" or row.achId == "DefiasMask") then
                                HCA_MarkRowCompleted(row)
                                HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                            end
                        end
                    end
                end
                
                -- Call item tracker functions for dungeon set achievements
                -- The tracker checks if ALL required items are owned, so we call it for all incomplete sets
                -- This is efficient because GetItemCount is fast and the tracker only completes when ALL items are owned
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and row._def and row._def.isDungeonSet then
                        local achId = row.achId or row.id
                        if achId then
                            -- Check if this achievement has an item tracker function (dungeon sets)
                            local trackerFn = _G[achId]
                            if type(trackerFn) == "function" then
                                -- The tracker function checks all required items and only returns true
                                -- when ALL items are owned, so it's safe to call on every inventory change
                                local ok, shouldComplete = pcall(trackerFn)
                                if ok and shouldComplete == true then
                                    HCA_MarkRowCompleted(row)
                                    HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                                end
                            end
                        end
                    end
                end
            elseif event == "BAG_UPDATE" then
                -- Check customIsCompleted functions when bag contents change
                -- This handles achievements that check for items in bags (GetItemCount checks bags)
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.customIsCompleted) == "function" then
                        local ok, shouldComplete = pcall(row.customIsCompleted)
                        if ok and shouldComplete == true then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                            break -- Achievement completed, no need to check others
                        end
                    end
                end
            elseif event == "CHAT_MSG_TEXT_EMOTE" then
                local msg, unit = ...
                if unit ~= UnitName("player") then return end
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.chatTracker) == "function" then
                        local ok, shouldComplete = pcall(row.chatTracker, tostring(msg or ""))
                        if ok and shouldComplete == true then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end
            elseif event == "PLAYER_LEVEL_CHANGED" then
                -- arg1 is previous level, arg2 is new level
                local previousLevel = tonumber(select(1, ...))
                local newLevel = tonumber(select(2, ...))
                
                -- Cache the level-up info with timestamp for quest turn-in validation
                if previousLevel and newLevel then
                    recentLevelUpCache = {
                        previousLevel = previousLevel,
                        timestamp = GetTime()
                    }
                end
                
                EvaluateCustomCompletions(newLevel)
                RefreshOutleveledAll()
            elseif event == "CHAT_MSG_LOOT" then
                local msg, _, _, _, playerName = ...
                if playerName == GetUnitName("player") then

                -- Extract the item link and itemID from the chat message
                local itemLink = msg:match("|Hitem:%d+.-|h%[.-%]|h")
                if not itemLink then return end

                local itemID = tonumber(itemLink:match("|Hitem:(%d+)"))
                if itemID ~= 6382 then return end  -- Forest Leather Belt
                    for _, row in ipairs(AchievementPanel.achievements) do
                        if not row.completed and row.id == "Secret99" then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end
            elseif event == "UPDATE_FACTION" then
                -- Handle reputation achievement completion
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and row._def and row._def.isReputation then
                        local achId = row.achId or row.id
                        if achId then
                            -- Check if this achievement has a reputation tracker function
                            local trackerFn = _G[achId]
                            if type(trackerFn) == "function" then
                                -- The tracker function checks if the player is exalted with the faction
                                local ok, shouldComplete = pcall(trackerFn)
                                if ok and shouldComplete == true then
                                    HCA_MarkRowCompleted(row)
                                    HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                                end
                            end
                        end
                    end
                end
            elseif event == "QUEST_REMOVED" then
                local removedQuestId = tonumber(...)
                if removedQuestId and QuestTrackedRows[removedQuestId] then
                    local rows = QuestTrackedRows[removedQuestId]
                    local needsRefresh = false
                    local clearedProgress = false
                    local playerLevel = UnitLevel("player") or 1
                    for i = #rows, 1, -1 do
                        local row = rows[i]
                        if not row or row.completed then
                            table.remove(rows, i)
                        else
                            needsRefresh = true
                            local shouldClearProgress = false
                            if row.maxLevel and playerLevel > row.maxLevel then
                                shouldClearProgress = true
                            end
                            if shouldClearProgress then
                                local achId = row.id or row.achId or (row.Title and row.Title:GetText())
                                if achId then
                                    ClearProgress(achId)
                                    clearedProgress = true
                                end
                            end
                        end
                    end
                    if #rows == 0 then
                        QuestTrackedRows[removedQuestId] = nil
                    end
                    if needsRefresh then
                        if clearedProgress and HCA_UpdateTotalPoints then
                            HCA_UpdateTotalPoints()
                        end
                        RefreshOutleveledAll()
                        if SortAchievementRows then
                            SortAchievementRows()
                        end
                    end
                end
            elseif event == "PLAYER_DEAD" then
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and row.id == "Secret4" then
                        HCA_MarkRowCompleted(row)
                        HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                    end
                end
            end
        end)
    end
end

-- =========================================================
-- Cross-locale Emote Hook (token-based via DoEmote)
-- =========================================================
do
    if not _G.HCA_EmoteHooked then
        _G.HCA_EmoteHooked = true
        if type(hooksecurefunc) == "function" then
            hooksecurefunc("DoEmote", function(token, unit)
                -- Resolve a reasonable target name
                local targetName
                if unit and UnitExists(unit) then
                    targetName = UnitName(unit)
                elseif UnitExists("target") then
                    targetName = UnitName("target")
                end

                if not AchievementPanel or not AchievementPanel.achievements then return end
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.emoteTracker) == "function" then
                        local ok, shouldComplete = pcall(row.emoteTracker, tostring(token or ""), tostring(targetName or ""), tostring(unit or ""))
                        if ok and shouldComplete == true then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon and row.Icon:GetTexture() or 136116, row.Title and row.Title:GetText() or "Achievement", row.points)
                        end
                    end
                end
            end)
        end
    end
end

-- =========================================================
-- Handle only OUR tabs click (dont toggle the whole frame)
-- =========================================================
 
-- Reusable function for achievement tab click logic
function HCA_ShowAchievementTab()
    -- tab sfx (Classic-compatible)
    if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    else
        PlaySound("igCharacterInfoTab")
    end

    for i = 1, CharacterFrame.numTabs do
        local t = _G["CharacterFrameTab"..i]
        if t then
            PanelTemplates_DeselectTab(t)
        end
    end

    PanelTemplates_SelectTab(Tab)

    -- Hide Blizzard subframes manually (same list Hardcore hides)
    if _G["PaperDollFrame"]    then _G["PaperDollFrame"]:Hide()    end
    if _G["PetPaperDollFrame"] then _G["PetPaperDollFrame"]:Hide() end
    if _G["HonorFrame"]        then _G["HonorFrame"]:Hide()        end
    if _G["SkillFrame"]        then _G["SkillFrame"]:Hide()        end
    if _G["ReputationFrame"]   then _G["ReputationFrame"]:Hide()   end
    if _G["TokenFrame"]        then _G["TokenFrame"]:Hide()        end

    -- Hide CharacterStatsClassic panel
    if type(_G.CSC_HideStatsPanel) == "function" then
        _G.CSC_HideStatsPanel()
    end

    -- Show our AchievementPanel directly (no CharacterFrame_ShowSubFrame)
    AchievementPanel:Show()
    --Tab.squareFrame:Show()
    
    -- Sync solo mode checkbox state
    if AchievementPanel.SoloModeCheckbox then
        local _, cdb = GetCharDB()
        local isChecked = (cdb and cdb.settings and cdb.settings.soloAchievements) or false
        AchievementPanel.SoloModeCheckbox:SetChecked(isChecked)
        
        -- Update enable/disable state based on Self-Found status
        local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
        if isSelfFound then
            AchievementPanel.SoloModeCheckbox:Enable()
            AchievementPanel.SoloModeCheckbox.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no help from nearby players)."
        else
            AchievementPanel.SoloModeCheckbox:Disable()
            AchievementPanel.SoloModeCheckbox.Text:SetTextColor(0.5, 0.5, 0.5, 1)
            --AchievementPanel.SoloModeCheckbox.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no help from nearby players). |cffff0000(Requires Self-Found buff to enable)|r"
        end
    end
    
    -- Apply current filter when opening panel
    if ApplyFilter then
        ApplyFilter()
    end

    -- AchievementPanel.PortraitCover:Show()
end

Tab:SetScript("OnClick", HCA_ShowAchievementTab)

-- Add mouseover highlighting for square frame and tooltip
Tab:HookScript("OnEnter", function(self)
    if Tab.squareFrame and Tab.squareFrame:IsShown() and Tab.squareFrame.highlight then
        Tab.squareFrame.highlight:Show()
    end
    local key1, key2 = GetBindingKey("HCA_TOGGLE")
    local keybindText = ""
    if key1 then keybindText = "|cffffd100 (" .. key1 .. ")|r" end
    -- Show tooltip with drag instructions
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if keybindText ~= "" then
        GameTooltip:SetText(ACHIEVEMENTS .. keybindText, 1, 1, 1)
    else
        GameTooltip:SetText(ACHIEVEMENTS, 1, 1, 1)
    end
    GameTooltip:AddLine("Shift click to drag \nMust not be active", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

Tab:HookScript("OnLeave", function(self)
    if Tab.squareFrame and Tab.squareFrame:IsShown() and Tab.squareFrame.highlight then
        -- Only hide highlight if tab is not selected (check if AchievementPanel is shown)
        if not AchievementPanel:IsShown() then
            Tab.squareFrame.highlight:Hide()
        end
    end
    
    -- Hide tooltip
    GameTooltip:Hide()
end)

-- Hook tab selection to show/hide highlight based on selection state
hooksecurefunc("PanelTemplates_SelectTab", function(tab)
    if tab == Tab and Tab.squareFrame and Tab.squareFrame:IsShown() and Tab.squareFrame.highlight then
        Tab.squareFrame.highlight:Show()
    end
end)

hooksecurefunc("PanelTemplates_DeselectTab", function(tab)
    if tab == Tab and Tab.squareFrame and Tab.squareFrame:IsShown() and Tab.squareFrame.highlight then
        Tab.squareFrame.highlight:Hide()
    end
end)

hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
    if AchievementPanel and AchievementPanel:IsShown() and frameName ~= "HardcoreAchievementsFrame" then
        AchievementPanel._suppressOnHide = true
        AchievementPanel:Hide()
        -- AchievementPanel.PortraitCover:Hide()
        PanelTemplates_DeselectTab(Tab)
        
        -- Hide highlight when switching away from achievements
        if Tab.squareFrame and Tab.squareFrame:IsShown() and Tab.squareFrame.highlight then
            Tab.squareFrame.highlight:Hide()
        end
        
        -- Show CharacterStatsClassic panel when leaving achievements tab
        if type(_G.CSC_ShowStatsPanel) == "function" then
            _G.CSC_ShowStatsPanel()
        end
    end
end)

if AchievementPanel and AchievementPanel.HookScript then
    AchievementPanel:HookScript("OnShow", RestoreCompletionsFromDB)
end

-- Hook CharacterFrame OnHide to hide square frame when character frame closes
CharacterFrame:HookScript("OnHide", function()
    if Tab.squareFrame then
        Tab.squareFrame:Hide()
    end
end)

-- Hook CharacterFrame OnShow to restore square frame visibility if in vertical mode
CharacterFrame:HookScript("OnShow", function()
    local _, cdb = GetCharDB()
    if not (cdb and cdb.settings and cdb.settings.showCustomTab) then
        Tab:Hide()
        if Tab.squareFrame then
            Tab.squareFrame:Hide()
            Tab.squareFrame:EnableMouse(false)
        end
        return
    end
    
    -- Load tab position first to restore saved mode and position
    LoadTabPosition()
    
    -- Ensure tab is shown (LoadTabPosition may have hidden it if CharacterFrame wasn't shown)
    -- Check if we have saved position data
    local db = EnsureDB()
    local hasSavedData = db.tabSettings and db.tabSettings.mode and db.tabSettings.position
    
    if not hasSavedData then
        -- No saved data but showCustomTab is true, ensure tab is at default position and visible
        Tab:ClearAllPoints()
        Tab:SetPoint("RIGHT", _G["CharacterFrameTab"..Tabs], "RIGHT", 43, 0)
        Tab:SetAlpha(1)
        Tab:EnableMouse(true)
        Tab.mode = "bottom"
        Tab:Show()
        
        if Tab.squareFrame then
            Tab.squareFrame:Hide()
            Tab.squareFrame:EnableMouse(false)
        end
    else
        -- Has saved data, LoadTabPosition should have handled it, but ensure tab/squareFrame is visible
        if Tab.mode == "bottom" then
            Tab:Show()
        elseif Tab.mode == "right" and Tab.squareFrame then
            Tab.squareFrame:Show()
            Tab.squareFrame:EnableMouse(true)
            -- Reposition the square frame to match the tab's current position
            local _, _, _, x, y = Tab:GetPoint()
            if x and y then
                Tab.squareFrame:ClearAllPoints()
                Tab.squareFrame:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", x, y)
            end
        end
    end
end)

-- Hook ToggleCharacter to handle CharacterStatsClassic visibility and square frame
hooksecurefunc("ToggleCharacter", function(tab, onlyShow)
    -- When switching to PaperDoll tab, show CharacterStatsClassic if not hidden
    if tab == "PaperDollFrame" then
        if type(_G.CSC_ShowStatsPanel) == "function" then
            _G.CSC_ShowStatsPanel()
        end
    end
    
    -- Hide square frame when character frame is closed
    if not CharacterFrame:IsShown() and Tab.squareFrame then
        Tab.squareFrame:Hide()
    end
end)
