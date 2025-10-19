local ADDON_NAME = ...
local playerGUID
--AchievementPanel

local function EnsureDB()
    HardcoreAchievementsDB = HardcoreAchievementsDB or {}
    HardcoreAchievementsDB.chars = HardcoreAchievementsDB.chars or {}
    return HardcoreAchievementsDB
end

local function GetCharDB()
    local db = EnsureDB()
    if not playerGUID then return db, nil end
    db.chars[playerGUID] = db.chars[playerGUID] or {
        meta = {},            -- name/realm/class/race/level/lastLogin
        achievements = {}     -- [id] = { completed=true, completedAt=time(), level=nn, mapID=123 }
    }
    return db, db.chars[playerGUID]
end

-- Progress helpers
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
    cdb.progress[achId] = p
end

local function ClearProgress(achId)
    local _, cdb = GetCharDB()
    if cdb and cdb.progress then cdb.progress[achId] = nil end
end

-- Export tiny API so achievement modules can use it
function HardcoreAchievements_GetProgress(achId) return GetProgress(achId) end
function HardcoreAchievements_SetProgress(achId, key, value) SetProgress(achId, key, value) end
function HardcoreAchievements_ClearProgress(achId) ClearProgress(achId) end

local function UpdateTotalPoints()
    local total = 0
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.completed and (row.points or 0) > 0 then
                total = total + row.points
            end
        end
    end
    if AchievementPanel and AchievementPanel.TotalPoints then
        AchievementPanel.TotalPoints:SetText(tostring(total) .. "pts")
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
            if row.Sub then row.Sub:SetText("Completed!") end
            if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(true) end
            if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end
        end
    end

    if UpdateTotalPoints then UpdateTotalPoints() end
end

-- Small utility: mark a UI row as completed visually + persist in DB
local function MarkRowCompleted(row)
    if row.completed then return end
    row.completed = true
    if row.Sub then row.Sub:SetText("Completed!") end
    if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(true) end
    if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end

    local _, cdb = GetCharDB()
    if cdb then
        local id = row.id or (row.Title and row.Title:GetText()) or ("row"..tostring(row))
        cdb.achievements[id] = cdb.achievements[id] or {}
        local rec = cdb.achievements[id]
        rec.completed   = true
        rec.completedAt = time()
        rec.level       = UnitLevel("player") or nil
        rec.mapID       = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or nil
        ClearProgress(id)
        UpdateTotalPoints()
    end
end

local function CheckPendingCompletions()
    local _, cdb = GetCharDB()
    if not cdb or not AchievementPanel or not AchievementPanel.achievements then return end

    for _, row in ipairs(AchievementPanel.achievements) do
        if not row.completed then
            local id = row.id or (row.Title and row.Title:GetText())
            local progress = cdb.progress and cdb.progress[id]
            if progress then
                -- hydrate state via module’s IsCompleted() if it exists
                local isDone = false
                local fn = _G[id:gsub("%s+", "_") .. "_IsCompleted"]
                if type(fn) == "function" then
                    isDone = fn()
                elseif progress.killed and progress.quest then
                    -- fallback for simple dual-condition achievements
                    isDone = true
                end
                if isDone then
                    MarkRowCompleted(row)
                end
            end
        end
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_LEVEL_UP")
initFrame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")

        local db, cdb = GetCharDB()  -- this now creates db.chars[playerGUID]
        if cdb then
            local name, realm = UnitName("player"), GetRealmName()
            local className, classID = UnitClass("player")

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
    elseif event == "PLAYER_LEVEL_UP" then
        RefreshOutleveledAll()
    end
end)

-- =========================================================
-- Outleveled (missed) indicator
-- =========================================================

local function ExtractMaxLevel(desc, tooltip)
    return tonumber(string.match(desc or "", "[Ll]evel%s*(%d+)"))
        or tonumber(string.match(tooltip or "", "before%s+[Ll]evel%s*(%d+)"))
end

local function IsRowOutleveled(row)
    if not row or row.completed then return false end
    if not row.maxLevel then return false end
    local lvl = UnitLevel("player") or 1
    return lvl >= row.maxLevel
end

local function ApplyOutleveledStyle(row)
    if IsRowOutleveled(row) and row.Title and row.Title.SetTextColor then
        -- simple: red title to indicate you missed the pre-level requirement
        row.Title:SetTextColor(0.9, 0.2, 0.2)
    end
end

local function RefreshOutleveledAll()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    for _, row in ipairs(AchievementPanel.achievements) do
        ApplyOutleveledStyle(row)
    end
end


-- =========================================================
-- Setting up the Interface
-- =========================================================

-- Constants
local Tabs = CharacterFrame.numTabs
local TabID = CharacterFrame.numTabs + 1

-- Create and configure the subframe
local Tab = CreateFrame("Button" , "$parentTab"..TabID, CharacterFrame, "CharacterFrameTabButtonTemplate")
Tab:SetPoint("LEFT", _G["CharacterFrameTab"..Tabs], "RIGHT", -50, -1)
Tab:SetText("Achievements")
PanelTemplates_DeselectTab(Tab)
 
AchievementPanel = CreateFrame("Frame", "Achievements", CharacterFrame)
AchievementPanel:Hide()
AchievementPanel:EnableMouse(true)
AchievementPanel:SetAllPoints(CharacterFrame)

AchievementPanel.Text = AchievementPanel:CreateFontString(nil, "OVERLAY")
AchievementPanel.Text:SetFontObject(GameFontNormal)
AchievementPanel.Text:SetText("Achievements")
AchievementPanel.Text:SetPoint("TOP", 5, -50)

AchievementPanel.TotalPoints = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
AchievementPanel.TotalPoints:SetPoint("TOPLEFT", AchievementPanel, "TOPLEFT", 85, -48)
AchievementPanel.TotalPoints:SetText("0pts")

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

-- Optional: mouse wheel support
AchievementPanel.Scroll:EnableMouseWheel(true)
AchievementPanel.Scroll:SetScript("OnMouseWheel", function(self, delta)
  local step = 24
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

function CreateAchievementRow(parent, title, desc, tooltip, icon, points, killTracker, questTracker)
    local rowParent = AchievementPanel and AchievementPanel.Content or parent or AchievementPanel
    
    AchievementPanel.achievements = AchievementPanel.achievements or {}
    local index = (#AchievementPanel.achievements) + 1

    local row = CreateFrame("Frame", nil, rowParent)
    row:SetSize(305, 36)

    -- stack under title or previous row
    if index == 1 then
        row:SetPoint("TOPLEFT", rowParent, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", AchievementPanel.achievements[index-1], "BOTTOMLEFT", 0, 0)
    end

    -- icon
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(32, 32)
    row.Icon:SetPoint("LEFT", row, "LEFT", -1, 0)
    row.Icon:SetTexture(icon or 136116)

    -- title
    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetPoint("LEFT", row.Icon, "RIGHT", 8, 10)
    row.Title:SetText(title or ("Achievement %d"):format(index))

    -- subtitle / progress
    row.Sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -2)
    row.Sub:SetWidth(265)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetJustifyV("TOP")
    row.Sub:SetWordWrap(true)
    row.Sub:SetText(desc or "—")

    -- points
    row.Points = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Points:SetPoint("RIGHT", row, "RIGHT", -15, 10)
    row.Points:SetWidth(40)
    row.Points:SetJustifyH("RIGHT")
    row.Points:SetJustifyV("TOP")
    row.Points:SetText((points and tostring(points) or "0") .. "pts")

    -- tooltip
    row:SetScript("OnEnter", function()
        if not tooltip then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.points = tonumber(points) or 0
    row.completed = false
    row.maxLevel = ExtractMaxLevel(desc, tooltip)
    ApplyOutleveledStyle(row)
    if row.Icon and IsRowOutleveled(row) and row.Icon.SetDesaturated then
        row.Icon:SetDesaturated(true)
    end

    -- store trackers
    row.killTracker  = killTracker
    row.questTracker = questTracker
    row.id = title

    local totalHeight = 0
    for i = 1, #AchievementPanel.achievements do
        totalHeight = totalHeight + (AchievementPanel.achievements[i]:GetHeight() - 10)
    end
    AchievementPanel.Content:SetHeight(math.max(totalHeight + 16, AchievementPanel.Scroll:GetHeight() or 0))
    AchievementPanel.Scroll:UpdateScrollChildRect()

    AchievementPanel.achievements[index] = row
    UpdateTotalPoints()
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
        AchievementPanel._achEvt:SetScript("OnEvent", function(_, event, ...)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
                if subevent ~= "PARTY_KILL" then return end
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.killTracker) == "function" then
                        if row.killTracker(destGUID) then
                            MarkRowCompleted(row)
                            local title = row.Title and row.Title:GetText() or "Unknown"
                            print("|cff00ff00Congratulations!|r You completed the achievement: " .. title)
                            PlaySoundFile("Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg", "Master")
                        end
                    end
                end

            elseif event == "QUEST_TURNED_IN" then
                local questID = ...
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.questTracker) == "function" then
                        if row.questTracker(questID) then
                            MarkRowCompleted(row)
                            local title = row.Title and row.Title:GetText() or "Unknown"
                            print("|cff00ff00Congratulations!|r You completed the achievement: " .. title)
                            PlaySoundFile("Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg", "Master")
                        end
                    end
                end
            end
        end)
    end
end

-- =========================================================
-- Handle only OUR tabs click (dont toggle the whole frame)
-- =========================================================
 
Tab:SetScript("OnClick", function(self)
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

    -- Show our AchievementPanel directly (no CharacterFrame_ShowSubFrame)
    AchievementPanel:Show()
end)

hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
    if AchievementPanel and AchievementPanel:IsShown() and frameName ~= "Achievements" then
        AchievementPanel:Hide()
        PanelTemplates_DeselectTab(Tab)
    end
end)

if AchievementPanel and AchievementPanel.HookScript then
    AchievementPanel:HookScript("OnShow", RestoreCompletionsFromDB)
end
