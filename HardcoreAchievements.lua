local ADDON_NAME, addon = ...
local playerGUID
HCA_SELF_FOUND_BONUS = 5

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

-- Migration function to move achievement data from UltraHardcoreLeaderboard database
local function MigrateFromLeaderboardDB()
    -- Check if we already have our own database
    if HardcoreAchievementsDB and HardcoreAchievementsDB.chars and next(HardcoreAchievementsDB.chars) then
        return false -- Already migrated or have data
    end
    
    -- Check if UltraHardcoreLeaderboardDB exists and has achievement data
    if UltraHardcoreLeaderboardDB and UltraHardcoreLeaderboardDB.chars then
        local migrated = false
        local migrationCount = 0
        
        for guid, charData in pairs(UltraHardcoreLeaderboardDB.chars) do
            if charData.achievements and next(charData.achievements) then
                -- Migrate this character's achievement data
                if not HardcoreAchievementsDB.chars[guid] then
                    HardcoreAchievementsDB.chars[guid] = {
                        meta = charData.meta or {},
                        achievements = charData.achievements
                    }
                    migrationCount = migrationCount + 1
                    migrated = true
                end
            end
        end
        
        if migrated then
            print("|cff00ff00[HardcoreAchievements]|r Migrated " .. migrationCount .. " character(s) achievement data from UltraHardcoreLeaderboard")
        end
        
        return migrated
    end
    
    return false
end

-- Optional cleanup function to remove achievement data from UltraHardcoreLeaderboard database
-- This should only be called after confirming migration was successful
local function CleanupLeaderboardAchievementData()
    if UltraHardcoreLeaderboardDB and UltraHardcoreLeaderboardDB.chars then
        local cleaned = false
        for guid, charData in pairs(UltraHardcoreLeaderboardDB.chars) do
            if charData.achievements then
                charData.achievements = nil
                cleaned = true
            end
        end
        
        if cleaned then
            print("|cff00ff00[HardcoreAchievements]|r Cleaned up old achievement data from UltraHardcoreLeaderboard database")
        end
        
        return cleaned
    end
    return false
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

local function ClearProgress(achId)
    local _, cdb = GetCharDB()
    if cdb and cdb.progress then cdb.progress[achId] = nil end
end

-- Format timestamp into readable date/time string
local function FormatTimestamp(timestamp)
    if not timestamp then return "" end
    
    local dateInfo = date("*t", timestamp)
    local monthNames = {FULLDATE_MONTH_JANUARY, FULLDATE_MONTH_FEBRUARY, FULLDATE_MONTH_MARCH,
                        FULLDATE_MONTH_APRIL, FULLDATE_MONTH_MAY, FULLDATE_MONTH_JUNE, 
                        FULLDATE_MONTH_JULY, FULLDATE_MONTH_AUGUST, FULLDATE_MONTH_SEPTEMBER,
                        FULLDATE_MONTH_OCTOBER, FULLDATE_MONTH_NOVEMBER, FULLDATE_MONTH_DECEMBER}
    
    return string.format("%s %d, %d %02d:%02d", 
        monthNames[dateInfo.month], 
        dateInfo.day, 
        dateInfo.year, 
        dateInfo.hour, 
        dateInfo.min)
end

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
            total = total + 1
            if row.completed then
                completed = completed + 1
            end
        end
    end
    
    return completed, total
end

function HCA_UpdateTotalPoints()
    local total = HCA_GetTotalPoints()
    if AchievementPanel and AchievementPanel.TotalPoints then
        AchievementPanel.TotalPoints:SetText(tostring(total) .. " pts")
    end
end

-- Sort all rows by their level cap (and re-anchor)
local function SortAchievementRows()
    if not AchievementPanel or not AchievementPanel.achievements then return end

    local function isLevelMilestone(row)
        -- milestone: no kill/quest tracker and id like "Level30"
        return (not row.killTracker) and (not row.questTracker)
            and type(row.id) == "string" and row.id:match("^Level%d+$") ~= nil
    end

    table.sort(AchievementPanel.achievements, function(a, b)
        -- Treat uncapped (nil) maxLevel as very large so they sort to the bottom
        local la = (a.maxLevel ~= nil) and a.maxLevel or 9999
        local lb = (b.maxLevel ~= nil) and b.maxLevel or 9999
        if la ~= lb then return la < lb end
        local aIsLvl, bIsLvl = isLevelMilestone(a), isLevelMilestone(b)
        if aIsLvl ~= bIsLvl then
            return not aIsLvl  -- non-level achievements first on ties
        end
        -- stable-ish fallback by title/id
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
            prev = row
            totalHeight = totalHeight + (row:GetHeight() + 2)
        end
    end

    AchievementPanel.Content:SetHeight(math.max(totalHeight + 16, AchievementPanel.Scroll:GetHeight() or 0))
    AchievementPanel.Scroll:UpdateScrollChildRect()
end

-- Small utility: mark a UI row as completed visually + persist in DB
function HCA_MarkRowCompleted(row)
    if row.completed then return end
    row.completed = true

    if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end
    
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
            if isSelfFound and not row.isSecretAchievement then
                finalPoints = finalPoints + HCA_SELF_FOUND_BONUS
                -- Mark that we've already applied self-found bonus so ApplySelfFoundBonus doesn't add it again
                rec.SFMod = true
            end
        end

        -- For secret achievements, compute final points from reveal base with multipliers/bonuses
        if row.isSecretAchievement then
            local base = tonumber(row.revealPointsBase or row.originalPoints) or 0
            local computed = base
            if not (row.revealStaticPoints) then
                local preset = GetPlayerPresetFromSettings and GetPlayerPresetFromSettings() or nil
                local multiplier = GetPresetMultiplier and GetPresetMultiplier(preset) or 1.0
                computed = base + math.floor((base) * (multiplier - 1) + 0.5)
            end
            -- Add self-found bonus if applicable
            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
            if isSelfFound then
                computed = computed + HCA_SELF_FOUND_BONUS
            end
            finalPoints = computed
        end

        -- Points from pointsAtKill already include multiplier and solo doubling if applicable
        -- We've added self-found bonus above if needed

        rec.points = finalPoints
        -- Reflect final points in UI row and text immediately
        row.points = finalPoints
        if row.Points then
            row.Points:SetText(tostring(finalPoints) .. " pts")
        end

        ClearProgress(id)
        HCA_UpdateTotalPoints()
    end
    
    -- Set Sub text with "Solo" indicator if achievement was completed solo
    -- Solo indicators only show if player is self-found
    local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
    if row.Sub then
        if wasSolo and isSelfFound then
            row.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n|cFF9D3AFFSolo|r")
        else
            row.Sub:SetText(AUCTION_TIME_LEFT0)
        end
    end
    if row.Points then row.Points:SetTextColor(0.6, 0.9, 0.6) end
    if row.TS then row.TS:SetText(FormatTimestamp(time())) end
    if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(false) end
    
    -- Update icon borders for completion status
    -- if row.GreenBorder then row.GreenBorder:Show() end
    -- if row.RedBorder then row.RedBorder:Hide() end
    -- if row.YellowBorder then row.YellowBorder:Hide() end

    -- Reveal secret achievements before persisting/toast
    if row.isSecretAchievement then
        if row.revealTitle and row.Title then row.Title:SetText(row.revealTitle) end
        if row.revealIcon and row.Icon then row.Icon:SetTexture(row.revealIcon) end
        if row.revealTooltip then row.tooltip = row.revealTooltip end
        row.staticPoints = row.revealStaticPoints or false
    end
    
    -- Broadcast achievement completion to emote channel
	local playerName = UnitName("player")
	local achievementTitle = row.Title and row.Title:GetText() or "Unknown Achievement"
	local broadcastMessage = string.format(ACHIEVEMENT_BROADCAST, "", achievementTitle)
	-- Remove leading whitespace so EMOTE doesn't show a double space before 'has'
	broadcastMessage = broadcastMessage:gsub("^%s+", "")
    SendChatMessage(broadcastMessage, "EMOTE")
    
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
            if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end
            -- Check if achievement was completed solo and show indicator
            -- Solo indicators only show if player is self-found
            local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
            if row.Sub then
                if rec.wasSolo and isSelfFound then
                    row.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n|cFF9D3AFFSolo|r")
                else
                    row.Sub:SetText(AUCTION_TIME_LEFT0)
                end
            end
            if row.TS then row.TS:SetText(FormatTimestamp(rec.completedAt)) end
            if row.Points then row.Points:SetTextColor(0.6, 0.9, 0.6) end
            
            if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(false) end
            
            -- Update icon borders for completion status
            -- if row.GreenBorder then row.GreenBorder:Show() end
            -- if row.RedBorder then row.RedBorder:Hide() end
            -- if row.YellowBorder then row.YellowBorder:Hide() end

            if rec.points then
                row.points = rec.points
                if row.Points then
                    row.Points:SetText(tostring(rec.points) .. " pts")
                end
            end

            -- Apply secret reveal visuals on load
            if row.isSecretAchievement then
                if row.revealTitle and row.Title then row.Title:SetText(row.revealTitle) end
                if row.revealIcon and row.Icon then row.Icon:SetTexture(row.revealIcon) end
                if row.revealTooltip then row.tooltip = row.revealTooltip end
                row.staticPoints = row.revealStaticPoints or false
            end
        end
    end

    if SortAchievementRows then SortAchievementRows() end
    if HCA_UpdateTotalPoints then HCA_UpdateTotalPoints() end
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
    if achIdOrRow then
        local _, cdb = GetCharDB()
        local achId = nil
        local row = nil
        
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
            if isSelfFound and not isSecretAchievement then
                finalPoints = finalPoints + HCA_SELF_FOUND_BONUS
            end
        end
    end

    -- these exist because we exposed them in the factory
    f.icon:SetTexture(tex)
    f.name:SetText(title or "")
    f.points:SetText(finalPoints and tostring(finalPoints) or "")

    f:Show()

    print(ACHIEVEMENT_BROADCAST_SELF:format(title))
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

    local updatedCount = 0
    for achId, ach in pairs(charData.achievements) do
        if ach.completed and not ach.SFMod then
            if isSecretAch(achId) then
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

local function IsRowOutleveled(row)
    if not row or row.completed then return false end
    if not row.maxLevel then return false end
    local lvl = UnitLevel("player") or 1
    return lvl > row.maxLevel
end

local function ApplyOutleveledStyle(row)
    if IsRowOutleveled(row) and row.Title and row.Title.SetTextColor then
        row.Title:SetTextColor(0.9, 0.2, 0.2)
        row.Icon:SetDesaturated(true)

    end
end

local function RefreshOutleveledAll()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    for _, row in ipairs(AchievementPanel.achievements) do
        ApplyOutleveledStyle(row)
    end
end

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
    p.levelAt = UnitLevel("player") or 1
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

-- Export migration functions for manual use
function HardcoreAchievements_MigrateFromLeaderboard() 
    local migrated = MigrateFromLeaderboardDB()
    if not migrated then
        print("|cff00ff00[HardcoreAchievements]|r No data found to migrate from UltraHardcoreLeaderboard")
    end
    return migrated
end

function HardcoreAchievements_CleanupOldData()
    local cleaned = CleanupLeaderboardAchievementData()
    return cleaned
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
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Create the data object for the minimap button
local minimapDataObject = LDB:NewDataObject("HardcoreAchievements", {
    type = "data source",
    text = "HardcoreAchievements",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.tga",
    OnClick = function(self, button)
        if button == "LeftButton" and not IsShiftKeyDown() then
            local _, cdb = GetCharDB()
            
            -- Helper function to toggle Character Frame with achievements tab
            local function toggleCharacterFrameTab()
                local isShown = CharacterFrame and CharacterFrame:IsShown() and 
                               (AchievementPanel and AchievementPanel:IsShown() or (Tab and Tab.squareFrame and Tab.squareFrame:IsShown()))
                if isShown then
                    ToggleCharacter("PaperDollFrame")
                    ToggleCharacter("PaperDollFrame")
                elseif not CharacterFrame:IsShown() then
                        ToggleCharacter("PaperDollFrame")
                    if HCA_ShowAchievementTab then
                        HCA_ShowAchievementTab()
                    end
                else
                    if CharacterFrame:IsShown() then
                        HCA_ShowAchievementTab()
                    end
                end
            end
            
            -- Check if using custom Character Frame tab
            if cdb and cdb.settings and cdb.settings.showCustomTab then
                toggleCharacterFrameTab()
            elseif type(ToggleSettings) == "function" then
                -- Toggle UltraHardcore settings window and switch to tab 3 when opening
                local container = nil
                if TabManager and TabManager.getTabContent then
                    container = TabManager.getTabContent(3)
                end
                if not container and _G.tabContents and _G.tabContents[3] then
                    container = _G.tabContents[3]
                end
                -- Check if the achievements tab container is currently shown
                local isContainerShown = container and container.IsShown and container:IsShown()
                
                -- If the container is shown, we're on achievements tab and should just close
                if isContainerShown then
                    ToggleSettings()
                else
                    -- Container is not shown, open the settings window
                    ToggleSettings()
                    -- After opening, switch to tab 3
                    if TabManager and TabManager.switchToTab then
                        TabManager.switchToTab(3)
                    elseif type(OpenSettingsToTab) == "function" then
                        OpenSettingsToTab(3)
                    end
                end
            elseif type(OpenSettingsToTab) == "function" then
                -- Fallback if ToggleSettings doesn't exist but OpenSettingsToTab does
                OpenSettingsToTab(3)
            else
                -- Fallback: use Character Frame method
                toggleCharacterFrameTab()
            end
        elseif button == "RightButton" then
            -- Right-click to open options panel
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(addon.settingsCategory:GetID())
            end
        elseif button == "LeftButton" and IsShiftKeyDown() then
            -- Left-click with Shift to open admin panel
            if AdminPanel and AdminPanel.Open then
                AdminPanel.Open()
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

        -- Run migration first, before setting up current character
        MigrateFromLeaderboardDB()

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
            RestoreCompletionsFromDB()
            CheckPendingCompletions()
            RefreshOutleveledAll()
        end
        SortAchievementRows()
        
        -- Initialize minimap button
        InitializeMinimapButton()
        
        -- Load saved tab position
        LoadTabPosition()
        
        -- Refresh options panel to sync checkbox states
        if _HardcoreAchievementsOptionsPanel and _HardcoreAchievementsOptionsPanel.refresh then
            _HardcoreAchievementsOptionsPanel:refresh()
        end

    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            C_Timer.After(3, function()
                ApplySelfFoundBonus()
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

-- === Draggable "curl" behavior for Achievements tab (bottom ↔ right edges only) ===
-- Place this immediately after the lines that create `Tab` and set its text.
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
        squareFrame:SetHitRectInsets(0, 30, 0, 0) -- shrink hitbox by 15px from right edge
        squareFrame:SetFrameStrata("BACKGROUND") -- Move to background strata
        squareFrame:SetFrameLevel(1) -- Low frame level to appear below borders
        squareFrame:Hide()
        
        -- Background - Stat background texture only
        local bg = squareFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Spellbook\\SpellBook-SkillLineTab.blp")
        bg:SetTexCoord(0, 1, 0, 1)
        squareFrame.bg = bg
        
        -- Logo
        local logo = squareFrame:CreateTexture(nil, "ARTWORK")
        logo:SetSize(26, 26) -- Fixed size, not dependent on frame size
        logo:SetPoint("CENTER", squareFrame, "CENTER", -12, 5)
        logo:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.tga")
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
            GameTooltip:AddLine("Shift + Left Click to drag \nMust not be active", 0.5, 0.5, 0.5)
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
 
AchievementPanel = CreateFrame("Frame", "Achievements", CharacterFrame)
AchievementPanel:Hide()
AchievementPanel:EnableMouse(true)
AchievementPanel:SetAllPoints(CharacterFrame)

-- Filter dropdown
local filterDropdown = CreateFrame("Frame", nil, AchievementPanel, "UIDropDownMenuTemplate")
filterDropdown:SetPoint("TOP", AchievementPanel, "TOP", 5, -50)
UIDropDownMenu_SetWidth(filterDropdown, 110)
UIDropDownMenu_SetText(filterDropdown, "All")

local currentFilter = "all"

local function PopulateFilterDropdown()
    local filterList = {
        { text = ACHIEVEMENTFRAME_FILTER_ALL, value = "all" },
        { text = ACHIEVEMENTFRAME_FILTER_COMPLETED, value = "completed" },
        { text = ACHIEVEMENTFRAME_FILTER_INCOMPLETE, value = "not_completed" },
        { text = FAILED, value = "failed" },
    }
    return filterList
end

-- Function to apply the current filter to all achievement rows
local function ApplyFilter()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    
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
        
        if shouldShow then
            row:Show()
        else
            row:Hide()
        end
    end
    
    -- Recalculate and update the row positioning after filtering
    SortAchievementRows()
end

UIDropDownMenu_Initialize(filterDropdown, function(self, level)
    if level == 1 then
        for _, filter in ipairs(PopulateFilterDropdown()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = filter.text
            info.value = filter.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(filterDropdown, filter.value)
                UIDropDownMenu_SetText(filterDropdown, filter.text)
                currentFilter = filter.value
                ApplyFilter()
            end
            UIDropDownMenu_AddButton(info)
        end
    end
end)

--AchievementPanel.Text = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
--AchievementPanel.Text:SetPoint("TOP", 5, -45)
--AchievementPanel.Text:SetText(ACHIEVEMENTS)
--AchievementPanel.Text:SetTextColor(1, 1, 0)

AchievementPanel.TotalPoints = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
AchievementPanel.TotalPoints:SetPoint("TOPRIGHT", AchievementPanel, "TOPRIGHT", -50, -55)
AchievementPanel.TotalPoints:SetText("0 pts")
AchievementPanel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)

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
            if _G.HCA_RefreshAllAchievementPoints then
                _G.HCA_RefreshAllAchievementPoints()
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

-- Scrollable container inside the AchievementPanel
AchievementPanel.Scroll = CreateFrame("ScrollFrame", "$parentScroll", AchievementPanel, "UIPanelScrollFrameTemplate")
AchievementPanel.Scroll:SetPoint("TOPLEFT", 30, -80)      -- adjust to taste
AchievementPanel.Scroll:SetPoint("BOTTOMRIGHT", -65, 90)  -- leaves room for the scrollbar

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
-- AchievementPanel.PortraitCover:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.tga")
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
    row:SetSize(300, 36)

    -- stack under title or previous row
    if index == 1 then
        row:SetPoint("TOPLEFT", rowParent, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", AchievementPanel.achievements[index-1], "BOTTOMLEFT", 0, 0)
    end

    -- icon
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(32, 32)
    row.Icon:SetPoint("LEFT", row, "LEFT", 1, 0) -- Shifted to account for SSF border
    row.Icon:SetTexture(icon or 136116)
    
    -- Create completion border as a green square outline around the icon
    row.GreenBorder = row:CreateTexture(nil, "BORDER")
    row.GreenBorder:SetSize(34, 34) -- Slightly larger than icon
    row.GreenBorder:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.GreenBorder:SetColorTexture(0.6, 0.9, 0.6, 0.8) -- Green square
    row.GreenBorder:Hide()
    
    -- Create failed border as a red square outline around the icon
    row.RedBorder = row:CreateTexture(nil, "BORDER")
    row.RedBorder:SetSize(34, 34) -- Slightly larger than icon
    row.RedBorder:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.RedBorder:SetColorTexture(0.53, 0.02, 0.03, 0.8) -- Red square
    row.RedBorder:Hide()
    
    -- Create available border as a yellow square outline around the icon
    row.YellowBorder = row:CreateTexture(nil, "BORDER")
    row.YellowBorder:SetSize(34, 34) -- Slightly larger than icon
    row.YellowBorder:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.YellowBorder:SetColorTexture(1, 0.82, 0, 0.8) -- Goldish yellow square
    row.YellowBorder:Hide()
    
    -- Create SSF mode border as a purple/blue glow around the icon
    row.SSFBorder = row:CreateTexture(nil, "BORDER")
    row.SSFBorder:SetSize(34, 34) -- Slightly larger than other borders
    row.SSFBorder:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)
    row.SSFBorder:SetColorTexture(0.5, 0.3, 0.9, 0.6) -- Purple glow
    row.SSFBorder:Hide()

    -- title
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 8, 10) -- Title stays anchored to icon
    row.Title:SetText(title or ("Achievement %d"):format(index))

    -- subtitle / progress
    row.Sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
    row.Sub:SetWidth(265)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetJustifyV("TOP")
    row.Sub:SetWordWrap(true)
    do
        local capNum = tonumber(level)
        if capNum and capNum > 0 then
            row.Sub:SetText(LEVEL .. " " .. capNum)
        else
            row.Sub:SetText("")
        end
    end

    -- points
    row.Points = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Points:SetPoint("RIGHT", row, "RIGHT", -15, 10)
    row.Points:SetWidth(100)
    row.Points:SetJustifyH("RIGHT")
    row.Points:SetJustifyV("TOP")
    row.Points:SetText(points or 0 .. " pts")
    row.Points:SetTextColor(1, 1, 1)

    -- timestamp
    row.TS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.TS:SetPoint("RIGHT", row.Points, "RIGHT", 0, -15)
    row.TS:SetJustifyH("RIGHT")
    row.TS:SetJustifyV("TOP")
    row.TS:SetText("")
    row.TS:SetTextColor(0.5, 0.5, 0.5)

    -- highlight/tooltip
    row:EnableMouse(true)
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(1, 1, 1, 0.10)
    row.highlight:Hide()

    row:SetScript("OnEnter", function(self)
        self.highlight:SetColorTexture(1, 1, 1, 0.10)
        self.highlight:Show()

        if self.Title and self.Title.GetText then
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            local currentTitle = (self.Title and self.Title.GetText and self.Title:GetText()) or (title or "")
            
            -- Check if SSF mode is enabled and this achievement supports it
            local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
            if isSoloMode and self.allowSoloDouble then
                -- Show title with "Solo" on the right
                GameTooltip:AddDoubleLine(currentTitle, "|cFF9D3AFFSolo|r", 1, 1, 1, 0.5, 0.3, 0.9)
            else
                GameTooltip:SetText(currentTitle, 1, 1, 1)
            end
            
            GameTooltip:AddLine(self.tooltip or tooltip or "", nil, nil, nil, true)
            if self.zone then
                GameTooltip:AddLine(self.zone, 0.6, 1, 0.86)
            end
			-- Hint for linking the achievement in chat
			GameTooltip:AddLine("\nShift + Left Click to link in chat", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and row.achId then
            local titleText = row.Title and row.Title:GetText() or tostring(row.achId)
            -- Sanitize title for bracket placeholder to avoid nested [] issues
            local iconTexture = row.Icon and row.Icon:GetTexture() or ""
            local pts = tonumber(row.points) or 0
            -- Send bracketed placeholder using commas (no pipes) to avoid chat escape codes
            -- Compact bracket tag without title to avoid special characters breaking chat parsing
            local bracket = string.format("[HCA:(%s,%s,%s)]", tostring(row.achId), tostring(iconTexture), tostring(pts))

            local editBox = ChatEdit_GetActiveWindow()
            -- If no chat edit box is currently active/visible, do nothing
            if not editBox or not editBox:IsVisible() then
                return
            end
            local currentText = editBox and (editBox:GetText() or "") or ""
            if currentText == "" then
                editBox:SetText(bracket)
            else
                editBox:SetText(currentText .. " " .. bracket)
            end
            editBox:SetFocus()
            return
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
    ApplyOutleveledStyle(row)
    if row.Icon and IsRowOutleveled(row) and row.Icon.SetDesaturated then
        row.Icon:SetDesaturated(true)
    end

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
        if row.Title then row.Title:SetText(row.secretTitle) end
        row.tooltip = row.secretTooltip
        if row.Icon then row.Icon:SetTexture(row.secretIcon) end
        row.points = row.secretPoints
        if row.Points then row.Points:SetText(tostring(row.secretPoints) .. " pts") end
        -- Prevent multipliers from inflating placeholder points
        row.staticPoints = true
    end

    AchievementPanel.achievements[index] = row
    SortAchievementRows()
    HCA_UpdateTotalPoints()

    return row
end

-- =========================================================
-- Event bridge: forward PARTY_KILL to any rows with a tracker
-- =========================================================

do
    if not AchievementPanel._achEvt then
        AchievementPanel._achEvt = CreateFrame("Frame")
        AchievementPanel._achEvt:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        AchievementPanel._achEvt:RegisterEvent("QUEST_TURNED_IN")
        AchievementPanel._achEvt:RegisterEvent("UNIT_SPELLCAST_SENT")
        AchievementPanel._achEvt:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        AchievementPanel._achEvt:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
        AchievementPanel._achEvt:RegisterEvent("PLAYER_LEVEL_UP")
        AchievementPanel._achEvt:RegisterEvent("CHAT_MSG_LOOT")
        AchievementPanel._achEvt:SetScript("OnEvent", function(_, event, ...)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
                if subevent ~= "PARTY_KILL" and subevent ~= "UNIT_DIED" then return end
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.killTracker) == "function" then
                        if row.killTracker(destGUID) then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end

            elseif event == "QUEST_TURNED_IN" then
                local questID = ...
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.questTracker) == "function" then
                        if row.questTracker(questID) then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end
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
            elseif event == "PLAYER_LEVEL_UP" then
                local newLevel = tonumber(select(1, ...))
                print(newLevel)
                -- Check for level-based achievement completions
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed then
                        local isCompleted = false
                        local fn = nil

                        -- First try customIsCompleted on the row (direct from def)
                        if type(row.customIsCompleted) == "function" then
                            fn = row.customIsCompleted
                        else
                            -- Fallback to global _IsCompleted function
                            local id = row.id or row.achId
                            if id then
                                fn = _G[id .. "_IsCompleted"]
                            end
                        end
                        
                        if type(fn) == "function" then
                            local ok, result = pcall(fn, newLevel)
                            if ok and result == true then
                                isCompleted = true
                            end
                        end
                        if isCompleted then
                            HCA_MarkRowCompleted(row)
                            HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points, row)
                        end
                    end
                end
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
            AchievementPanel.SoloModeCheckbox.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no party members within 40 yards)."
        else
            AchievementPanel.SoloModeCheckbox:Disable()
            AchievementPanel.SoloModeCheckbox.Text:SetTextColor(0.5, 0.5, 0.5, 1)
            --AchievementPanel.SoloModeCheckbox.tooltip = "|cffffffffSolo Self Found|r \nToggling this option on will display the total points you will receive if you complete this achievement solo (no party members within 40 yards). |cffff0000(Requires Self-Found buff to enable)|r"
        end
        
        -- Update SSF borders for all achievements
        -- if AchievementPanel and AchievementPanel.achievements then
        --     local isSoloMode = isChecked
        --     for _, row in ipairs(AchievementPanel.achievements) do
        --         if not row.completed and row.allowSoloDouble and row.SSFBorder then
        --             if isSoloMode then
        --                 row.SSFBorder:Show()
        --             else
        --                 row.SSFBorder:Hide()
        --             end
        --         end
        --     end
        -- end
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
    
    -- Show tooltip with drag instructions
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ACHIEVEMENTS, 1, 1, 1)
    GameTooltip:AddLine("Shift + Left Click to drag \nMust not be active", 0.5, 0.5, 0.5)
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
    if AchievementPanel and AchievementPanel:IsShown() and frameName ~= "Achievements" then
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
