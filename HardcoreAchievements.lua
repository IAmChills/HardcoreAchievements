local ADDON_NAME = ...
local playerGUID
local SELF_FOUND_BONUS = 5

-- Check if UltraHardcoreLeaderboard addon is available for preset detection
local function IsLeaderboardAddonAvailable()
    return type(GetPresetAndTooltip) == "function"
end

-- Check if UltraHardcore addon is available for integration
local function IsUltraHardcoreAddonAvailable()
    return UltraHardcoreDB ~= nil
end

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
        achievements = {}     -- [id] = { completed=true, completedAt=time(), level=nn, mapID=123 }
    }
    return db, db.chars[playerGUID]
end

function HCA_GetPlayerPreset()
  -- Try to get preset from UltraHardcoreLeaderboard addon first
  if IsLeaderboardAddonAvailable() then
    local preset = GetPresetAndTooltip(UnitName("player"))
    if type(preset) == "string" and preset ~= "" then
      return preset
    end
  end
  return "Custom"
end

local function ClearProgress(achId)
    local _, cdb = GetCharDB()
    if cdb and cdb.progress then cdb.progress[achId] = nil end
end

function UpdateTotalPoints()
    local total = 0
    if AchievementPanel and AchievementPanel.achievements then
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.completed and (row.points or 0) > 0 then
                total = total + row.points
            end
        end
    end
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
        local la, lb = (a.maxLevel or 0), (b.maxLevel or 0)
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
        if not row._isHidden then
            row:ClearAllPoints()
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
local function MarkRowCompleted(row)
    if row.completed then return end

    if row._isHidden then
        row._isHidden = false
        row:Show()
        SortAchievementRows()
    end

    row.completed = true

    if row.Sub then row.Sub:SetText("Completed!") end
    if row.Points then row.Points:SetTextColor(0.6, 0.9, 0.6) end
    if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end
    if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(false) end

    local _, cdb = GetCharDB()
    if cdb then
        local id = row.id or (row.Title and row.Title:GetText()) or ("row"..tostring(row))
        cdb.achievements[id] = cdb.achievements[id] or {}
        local rec = cdb.achievements[id]
        rec.completed   = true
        rec.completedAt = time()
        rec.level       = UnitLevel("player") or nil
        local fixedPoints = tonumber(row.points) or 0
        rec.points = fixedPoints
        if row.Points then
            row.Points:SetText(tostring(fixedPoints) .. "pts")
        end
        ClearProgress(id)
        UpdateTotalPoints()
    end
end

function CheckPendingCompletions()
    if not AchievementPanel or not AchievementPanel.achievements then return end

    for _, row in ipairs(AchievementPanel.achievements) do
        if not row.completed then
            if row.killTracker then
            else
                local id = row.id
                local fn = _G[id .. "_IsCompleted"]
                if type(fn) == "function" and fn() then
                    MarkRowCompleted(row)
                end
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
            if row.Sub then row.Sub:SetText("Completed!") end
            if row.Points then row.Points:SetTextColor(0.6, 0.9, 0.6) end
            if row.Title and row.Title.SetTextColor then row.Title:SetTextColor(0.6, 0.9, 0.6) end
            if row.Icon and row.Icon.SetDesaturated then row.Icon:SetDesaturated(false) end
            if row._isHidden then row._isHidden = false end
            if row._isHidden then row:show() end

            if rec.points then
                row.points = rec.points
                if row.Points then
                    row.Points:SetText(tostring(rec.points) .. "pts")
                end
            end
        end
    end

    if SortAchievementRows then SortAchievementRows() end
    if UpdateTotalPoints then UpdateTotalPoints() end
end

-- =========================================================
-- Simple Achievement Toast
-- =========================================================
-- Usage:
-- UHC_AchToast_Show(iconTextureIdOrPath, "Achievement Title", 10)
-- UHC_AchToast_Show(row.icon or 134400, row.title or "Achievement", row.points or 10)

local function UHC_CreateAchToast()
    if UHC_AchToast and UHC_AchToast:IsObjectType("Frame") then
        return UHC_AchToast
    end

    local f = CreateFrame("Frame", "UHC_AchToast", UIParent)
    f:SetSize(320, 92)
    f:SetPoint("CENTER", 0, -400)
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
    unlocked:SetText("Achievement Earned")
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

function UHC_AchToast_Show(iconTex, title, pts)
    local f = UHC_CreateAchToast()
    f:Hide()
    f:SetAlpha(1)

    -- Accept fileID/path/Texture object; fallback if nil
    local tex = iconTex
    if type(iconTex) == "table" and iconTex.GetTexture then
        tex = iconTex:GetTexture()
    end
    if not tex then tex = 136116 end

    -- these exist because we exposed them in the factory
    f.icon:SetTexture(tex)
    f.name:SetText(title or "")
    f.points:SetText(pts and tostring(pts) or "")

    f:Show()

    print("|cff00ff00Congratulations!|r You completed the achievement: " .. title)
    PlaySoundFile("Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg", "Effects")

    holdSeconds = holdSeconds or 3
    fadeSeconds = fadeSeconds or 0.6
    C_Timer.After(holdSeconds, function()
        if f:IsShown() then f:PlayFade(fadeSeconds) end
    end)
end

-- =========================================================
-- Self Found
-- =========================================================

local function IsSelfFound()
    -- Check for UltraHardcore Self-Found buff
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId == 431567 or name == "Self-Found Adventurer" then
            return true
        end
    end
    return false
end

local function ApplySelfFoundBonus()
    if not IsSelfFound() then return end
    if not HardcoreAchievementsDB or not HardcoreAchievementsDB.chars then return end

    local guid = UnitGUID("player")
    local charData = HardcoreAchievementsDB.chars[guid]
    if not charData or not charData.achievements then return end

    local updatedCount = 0
    for achId, ach in pairs(charData.achievements) do
        if ach.completed and not ach.SFMod then
            ach.points = (ach.points or 0) + SELF_FOUND_BONUS
            ach.SFMod = true
            updatedCount = updatedCount + 1
        end
    end

    if updatedCount > 0 then
        print("|cff00ff00[HardcoreAchievements]|r Added +" .. SELF_FOUND_BONUS ..
              " to " .. updatedCount .. " completed achievements (Self-Found bonus).")
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

-- =========================================================
-- Events
-- =========================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_LEVEL_UP")
initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")

        local db, cdb = GetCharDB()
        if cdb then
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
        ApplySelfFoundBonus()

    elseif event == "PLAYER_LEVEL_UP" then
        RefreshOutleveledAll()
        CheckPendingCompletions()
    end
end)

-- =========================================================
-- Setting up the Interface
-- =========================================================

-- Constants
local Tabs = CharacterFrame.numTabs
local TabID = CharacterFrame.numTabs + 1

-- Create and configure the subframe
local Tab = CreateFrame("Button" , "$parentTab"..TabID, CharacterFrame, "CharacterFrameTabButtonTemplate")
Tab:SetPoint("RIGHT", _G["CharacterFrameTab"..Tabs], "RIGHT", 43, 0)
Tab:SetText("Achievements")
PanelTemplates_DeselectTab(Tab)
 
AchievementPanel = CreateFrame("Frame", "Achievements", CharacterFrame)
AchievementPanel:Hide()
AchievementPanel:EnableMouse(true)
AchievementPanel:SetAllPoints(CharacterFrame)

AchievementPanel.Text = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
AchievementPanel.Text:SetPoint("TOP", 5, -45)
AchievementPanel.Text:SetText("Achievements")
--AchievementPanel.Text:SetTextColor(1, 1, 0)

AchievementPanel.TotalPoints = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
AchievementPanel.TotalPoints:SetPoint("TOPRIGHT", AchievementPanel, "TOPRIGHT", -45, -43)
AchievementPanel.TotalPoints:SetText("0pts")
AchievementPanel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)

-- Preset multiplier label, e.g. "Point Multiplier (Lite +)"
AchievementPanel.PresetLabel = AchievementPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
AchievementPanel.PresetLabel:SetPoint("TOP", 5, -60)

-- Build the label text based on available information
local function BuildPresetLabelText()
    local preset = HCA_GetPlayerPreset()
    local isSelfFound = IsSelfFound()
    
    if preset or isSelfFound then
        local labelText = "Point Multiplier ("
        if preset ~= "Custom" then
            labelText = labelText .. preset
        else
            labelText = labelText .. "Standard"
        end
        if isSelfFound then
            labelText = labelText .. ", Self Found"
        end
        labelText = labelText .. ")"
    end
    return labelText
end

AchievementPanel.PresetLabel:SetText(BuildPresetLabelText())
AchievementPanel.PresetLabel:SetTextColor(0.8, 0.8, 0.8)

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
-- AchievementPanel.PortraitCover:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievements.tga")
-- AchievementPanel.PortraitCover:SetSize(58, 58)
-- AchievementPanel.PortraitCover:SetPoint("TOPLEFT", CharacterFramePortrait, "TOPLEFT", 4, -1)
-- AchievementPanel.PortraitCover:Hide()

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

function CreateAchievementRow(parent, achId, title, desc, tooltip, icon, level, points, killTracker, questTracker, hidden)
    local rowParent = AchievementPanel and AchievementPanel.Content or parent or AchievementPanel
    AchievementPanel.achievements = AchievementPanel.achievements or {}

    local initiallyHidden = not not hidden

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
    row.Points:SetText(((points or 0) + (IsSelfFound() and SELF_FOUND_BONUS or 0)) .. " pts")
    row.Points:SetTextColor(1, 1, 1)

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
            GameTooltip:SetText(title or "", 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    row._isHidden = initiallyHidden
    if initiallyHidden then
        row:Hide()
    end

    row.points = tonumber(points) or 0
    row.completed = false
    row.maxLevel = tonumber(level) or 0
    row.tooltip = tooltip  -- Store the tooltip for later access
    ApplyOutleveledStyle(row)
    if row.Icon and IsRowOutleveled(row) and row.Icon.SetDesaturated then
        row.Icon:SetDesaturated(true)
    end

    -- store trackers
    row.killTracker  = killTracker
    row.questTracker = questTracker
    row.id = achId

    AchievementPanel.achievements[index] = row
    SortAchievementRows()
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
                            UHC_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points)
                        end
                    end
                end

            elseif event == "QUEST_TURNED_IN" then
                local questID = ...
                for _, row in ipairs(AchievementPanel.achievements) do
                    if not row.completed and type(row.questTracker) == "function" then
                        if row.questTracker(questID) then
                            MarkRowCompleted(row)
                            UHC_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points)
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

    -- AchievementPanel.PortraitCover:Show()
end)

hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
    if AchievementPanel and AchievementPanel:IsShown() and frameName ~= "Achievements" then
        AchievementPanel:Hide()
        -- AchievementPanel.PortraitCover:Hide()
        PanelTemplates_DeselectTab(Tab)
    end
end)

if AchievementPanel and AchievementPanel.HookScript then
    AchievementPanel:HookScript("OnShow", RestoreCompletionsFromDB)
end
