local ADDON_NAME = ...
local playerGUID

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
        UpdateTotalPoints()
    end
end

local function UpdateTotalPoints()
    local total = 0
    if Panel and Panel.achievements then
        for _, row in ipairs(Panel.achievements) do
            if row.completed and (row.points or 0) > 0 then
                total = total + row.points
            end
        end
    end
    if Panel and Panel.TotalPoints then
        Panel.TotalPoints:SetText(tostring(total) .. "pts")
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
 
local Panel = CreateFrame("Frame", "Achievements", CharacterFrame)
Panel:Hide()
Panel:EnableMouse(true)
Panel:SetAllPoints(CharacterFrame)

Panel.Text = Panel:CreateFontString(nil, "OVERLAY")
Panel.Text:SetFontObject(GameFontNormal)
Panel.Text:SetText("Achievements")
Panel.Text:SetPoint("TOP", 5, -50)

Panel.TotalPoints = Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
Panel.TotalPoints:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -50, -48)
Panel.TotalPoints:SetText("0pts")

-- 4-quadrant PaperDoll art
local TL = Panel:CreateTexture(nil, "BACKGROUND", nil, 0)
TL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
TL:SetPoint("TOPLEFT", 2, -1)
TL:SetSize(256, 256)

local TR = Panel:CreateTexture(nil, "BACKGROUND", nil, 0)
TR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
TR:SetPoint("TOPLEFT", TL, "TOPRIGHT", 0, 0)
TR:SetPoint("RIGHT", Panel, "RIGHT", 2, -1) -- stretch to the right edge if needed
TR:SetHeight(256)

local BL = Panel:CreateTexture(nil, "BACKGROUND", nil, 0)
BL:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
BL:SetPoint("TOPLEFT", TL, "BOTTOMLEFT", 0, 0)
BL:SetPoint("BOTTOMLEFT", Panel, "BOTTOMLEFT", 2, -1) -- stretch down if needed
BL:SetWidth(256)

local BR = Panel:CreateTexture(nil, "BACKGROUND", nil, 0)
BR:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
BR:SetPoint("TOPLEFT", BL, "TOPRIGHT", 0, 0)
BR:SetPoint("LEFT", TR, "LEFT", 0, 0)
BR:SetPoint("BOTTOMRIGHT", Panel, "BOTTOMRIGHT", 2, -1)

-- =========================================================
-- Creating the functionality of achievements
-- =========================================================

Panel.achievements = Panel.achievements or {}

function CreateAchievementRow(parent, title, desc, tooltip, icon, points, tracker)
    local index = (#parent.achievements) + 1
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(305, 36)

    -- stack under title or previous row
    if index == 1 then
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, -80)
    else
        row:SetPoint("TOPLEFT", parent.achievements[index-1], "BOTTOMLEFT", 0, 0)
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
    row.Points:SetPoint("RIGHT", row, "RIGHT", 0, 10)
    row.Points:SetWidth(40)
    row.Points:SetJustifyH("RIGHT")
    row.Points:SetJustifyV("TOP")
    row.Points:SetText(points .. "pts" or "0pts")

    row.points = tonumber(points) or 0

    -- tooltip
    row:SetScript("OnEnter", function()
        if not tooltip then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- state
    row.completed = false
    row.tracker = tracker
    row.id = title

    parent.achievements[index] = row
    UpdateTotalPoints()
    return row
end

-- =========================================================
-- Event bridge: forward PARTY_KILL to any rows with a tracker
-- =========================================================

do
    if not Panel._achEvt then
        Panel._achEvt = CreateFrame("Frame")
        Panel._achEvt:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        Panel._achEvt:SetScript("OnEvent", function()
            local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

            if subevent ~= "PARTY_KILL" then return end

            -- Call each row's tracker; when it returns true once, persist + style
            for _, row in ipairs(Panel.achievements) do
                if not row.completed and type(row.tracker) == "function" then
                    local ok = row.tracker(destGUID)
                    if ok then
                        MarkRowCompleted(row)
                        local title = row.Title and row.Title:GetText() or "Unknown"
                        print("|cff00ff00Congratulations!|r You completed the achievement: " .. title)
                        PlaySound(8473)
                    end
                end
            end
        end)
    end
end

-- =========================================================
-- Calling the achievements
-- =========================================================

-- Four Candles
CreateAchievementRow(
    Panel,
    "Four Candles",
    "Complete the four candles achievement before level 23",
    "Light all four candles at once within Blackfathom Depths and survive before level 23 (including party members).",
    133750, -- any icon fileID or texture path
    50,
    FourCandle_OnPartyKill
)

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

    -- Show our panel directly (no CharacterFrame_ShowSubFrame)
    Panel:Show()
end)

hooksecurefunc("CharacterFrame_ShowSubFrame", function(frameName)
    if Panel and Panel:IsShown() and frameName ~= "Achievements" then
        Panel:Hide()
        PanelTemplates_DeselectTab(Tab)
    end
end)