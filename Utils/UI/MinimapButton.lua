local addonName, addon = ...
local IsShiftKeyDown = IsShiftKeyDown
local string_format = string.format
local LibStub = LibStub

-- =========================================================
-- Minimap Button + Addon Compartment
-- =========================================================
-- Extracted from HardcoreAchievements.lua (Phase 1).
-- Globals below are required by Bindings.xml and TOC AddonCompartmentFunc*.

local function OpenOptionsPanel()
    if Settings and Settings.OpenToCategory then
        local targetCategory = addon and addon.settingsCategory
        if targetCategory and targetCategory.GetID then
            Settings.OpenToCategory(targetCategory:GetID())
            return
        end
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("Hardcore Achievements")
    end
end

if addon then
    addon.OpenOptionsPanel = OpenOptionsPanel
end

BINDING_NAME_HCA_TOGGLE = "Toggle Achievements"

local function ToggleUI()
    if addon and addon.ToggleHardcoreAchievementsUI then
        addon.ToggleHardcoreAchievementsUI()
    elseif addon and addon.Dashboard and addon.Dashboard.Toggle then
        addon.Dashboard:Toggle()
    elseif addon and addon.ShowDashboard then
        addon.ShowDashboard()
    end
end

-- Bindings.xml runs in the global env.
function HardcoreAchievements_Toggle()
    ToggleUI()
end

local LDB, LDBIcon, minimapDataObject
local minimapRegistered = false

local function EnsureMinimapDB()
    local db = addon.GetCharDB and select(1, addon.GetCharDB())
    if not db then return nil end
    db.minimap = db.minimap or { hide = false, minimapPos = 45 }
    if db.minimap.hide == nil then
        db.minimap.hide = false
    end
    if db.minimap.minimapPos == nil then
        db.minimap.minimapPos = 45
    end
    -- Drop legacy root keys from when LibDBIcon was registered against the account DB.
    db.minimapPos = nil
    db.hide = nil
    db.minimap.position = nil
    return db, db.minimap
end

-- Shared by minimap LDB and AddonCompartment (Left = dashboard, Right = leaderboard, Shift-Right = options).
local function HandleLauncherClick(button)
    -- Hardware-event flush for LibP2PDB chat-channel queue (before UI work).
    if addon and addon.FlushBroadcastQueue then
        addon.FlushBroadcastQueue()
    end
    if button == "LeftButton" then
        ToggleUI()
    elseif button == "RightButton" and IsShiftKeyDown() then
        OpenOptionsPanel()
    elseif button == "RightButton" then
        if addon and addon.Leaderboard and addon.Leaderboard.Toggle then
            addon.Leaderboard:Toggle()
        end
    end
end

local function InitializeMinimapButton()
    local db, minimapDB = EnsureMinimapDB()
    if not db or not minimapDB then return end

    -- If the user has it hidden, don't create/register anything yet.
    if minimapDB.hide then
        return
    end

    if not LDB then
        LDB = LibStub("LibDataBroker-1.1")
    end
    if not LDBIcon then
        LDBIcon = LibStub("LibDBIcon-1.0")
    end
    if not minimapDataObject then
        minimapDataObject = LDB:NewDataObject("HardcoreAchievements", {
            type = "data source",
            text = "HardcoreAchievements",
            icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png",
            OnClick = function(self, button)
                HandleLauncherClick(button)
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Hardcore Achievements", 1, 0.82, 0)

                tooltip:AddLine("Left-click to open Dashboard", 0.5, 0.5, 0.5)
                tooltip:AddLine("Right-click to open Leaderboard", 0.5, 0.5, 0.5)
                tooltip:AddLine("Shift-right-click to open Options", 0.5, 0.5, 0.5)

                local completedCount, totalCount = 0, 0
                if addon and addon.AchievementCount then
                    completedCount, totalCount = addon.AchievementCount()
                end
                tooltip:AddLine(" ")
                local countStr = string_format("%d/%d", completedCount, totalCount)
                tooltip:AddLine(string_format(ACHIEVEMENT_META_COMPLETED_DATE, countStr), 0.6, 0.9, 0.6)

                local lbData = addon and addon.Leaderboard and addon.Leaderboard.Data
                local rankLbl = lbData and lbData.GetPointsRankLabelCached and lbData:GetPointsRankLabelCached()
                if rankLbl then
                    tooltip:AddLine("Rank: " .. rankLbl, 0.85, 0.85, 0.92)
                    tooltip:AddLine("(current leaderboard filters)", 0.45, 0.45, 0.45)
                end
            end,
        })
    end

    -- Register once against db.minimap so hide + minimapPos live in one table.
    if not minimapRegistered then
        LDBIcon:Register("HardcoreAchievements", minimapDataObject, minimapDB)
        minimapRegistered = true
    end
    LDBIcon:Show("HardcoreAchievements")
end

local function SetMinimapButtonShown(shown)
    local _, minimapDB = EnsureMinimapDB()
    if not minimapDB then return end

    minimapDB.hide = not shown

    if minimapDB.hide then
        if LDBIcon then
            LDBIcon:Hide("HardcoreAchievements")
        end
    else
        InitializeMinimapButton()
    end
end

local function IsMinimapButtonShown()
    local _, minimapDB = EnsureMinimapDB()
    return not (minimapDB and minimapDB.hide)
end

if addon then
    addon.SetMinimapButtonShown = SetMinimapButtonShown
    addon.IsMinimapButtonShown = IsMinimapButtonShown
    addon.InitializeMinimapButton = InitializeMinimapButton
end

-- Addon compartment (TOC ## AddonCompartmentFunc*). Globals required; same clicks as minimap.
function HardcoreAchievements_OnAddonCompartmentClick(addonNameArg, buttonName)
    HandleLauncherClick(buttonName or "LeftButton")
end

function HardcoreAchievements_OnAddonCompartmentEnter(addonNameArg, menuButtonFrame)
    local owner = menuButtonFrame or AddonCompartmentFrame
    if not (GameTooltip and owner) then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    if minimapDataObject and minimapDataObject.OnTooltipShow then
        minimapDataObject.OnTooltipShow(GameTooltip)
    else
        GameTooltip:SetText("Hardcore Achievements", 1, 0.82, 0)
        GameTooltip:AddLine("Click to toggle Dashboard", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

function HardcoreAchievements_OnAddonCompartmentLeave(addonNameArg, menuButtonFrame)
    if GameTooltip then
        GameTooltip:Hide()
    end
end
