local addonName, addon = ...
if not addon then return end

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetRealmName = GetRealmName

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

-- Periodic dashboard leaderboard rebuild while tab is visible (does not bypass sync/data; pairs with paused instant refresh).
local LEADERBOARD_VIEW_UI_REFRESH_SEC = 60

-- English display + sync — derived from Blizzard class index (UnitClass third return) when known.
local CLASS_ID_TO_ENGLISH = {
    [1] = "Warrior",
    [2] = "Paladin",
    [3] = "Hunter",
    [4] = "Rogue",
    [5] = "Priest",
    [7] = "Shaman",
    [8] = "Mage",
    [9] = "Warlock",
    [11] = "Druid",
}

--- English name from class id; if id is unknown/missing, uses fallback (e.g. synced class string).
function Leaderboard.GetEnglishClassName(classId, fallback)
    local id = tonumber(classId)
    if id and CLASS_ID_TO_ENGLISH[id] then
        return CLASS_ID_TO_ENGLISH[id]
    end
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end
    return "Unknown"
end

--- English class + numeric id from UnitClass (arg2 locale-free token; arg3 class id).
function Leaderboard.GetNormalizedPlayerClass()
    local localized, token, classId = UnitClass("player")
    classId = tonumber(classId)
    if classId and CLASS_ID_TO_ENGLISH[classId] then
        return CLASS_ID_TO_ENGLISH[classId], classId
    end
    if type(token) == "string" and token ~= "" then
        local lc = token:lower()
        return lc:sub(1, 1):upper() .. lc:sub(2), classId
    end
    return localized or "Unknown", classId
end

--- Stable row key for leaderboard storage and sync (Player-xxxx, or legacy name-realm if GUID unavailable).
function Leaderboard.GetLeaderboardRowKey()
    local guid = UnitGUID("player")
    if type(guid) == "string" and guid ~= "" then
        return guid
    end
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    if not name or name == "" then
        return nil
    end
    return (realm and realm ~= "" and (name .. "-" .. realm)) or name
end

local DEFAULT_SCOPE = {
    guild = true,
    realm = false,
    faction = false,
    dead = false,
}

local function EnsureRootDB()
    if type(HardcoreAchievementsDB) ~= "table" then
        HardcoreAchievementsDB = {}
    end
    addon.HardcoreAchievementsDB = HardcoreAchievementsDB
    HardcoreAchievementsDB.leaderboard = HardcoreAchievementsDB.leaderboard or {}

    local db = HardcoreAchievementsDB.leaderboard
    db.rows = db.rows or {}
    db.settings = db.settings or {}
    db.settings.scope = db.settings.scope or {}
    for key, defaultValue in pairs(DEFAULT_SCOPE) do
        if db.settings.scope[key] == nil then
            db.settings.scope[key] = defaultValue
        end
    end
    return db
end

function Leaderboard:GetDB()
    return EnsureRootDB()
end

function Leaderboard:GetScope()
    return self:GetDB().settings.scope
end

function Leaderboard:SetScopeValue(key, enabled)
    local scope = self:GetScope()
    scope[key] = enabled and true or false
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
    if addon.RefreshDashboard then
        addon.RefreshDashboard(true)
    end
end

function Leaderboard:Refresh()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function Leaderboard:Toggle()
    local dashboardFrame = addon and addon.DashboardFrame
    if dashboardFrame and dashboardFrame:IsShown() and dashboardFrame.SelectedTabKey == "leaderboard" then
        if addon.Dashboard and addon.Dashboard.Hide then
            addon.Dashboard:Hide()
        else
            dashboardFrame:Hide()
        end
        return
    end
    self:Show()
end

function Leaderboard:Show()
    addon._hcaOpenDashboardTabKey = "leaderboard"
    if addon.Dashboard and addon.Dashboard.Show then
        addon.Dashboard:Show()
    elseif self.UI and self.UI.Show then
        self.UI:Show()
    end
end

function Leaderboard:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    EnsureRootDB()

    if self.Sync and self.Sync.Initialize then
        self.Sync:Initialize()
    end
    if self.UI and self.UI.Initialize then
        self.UI:Initialize()
    end

    local function publish(reason)
        if Leaderboard.Sync and Leaderboard.Sync.PublishLocal then
            Leaderboard.Sync:PublishLocal(reason)
        end
    end

    if addon.Hooks and addon.Hooks.HookScript then
        addon.Hooks:HookScript("OnAchievement", function()
            publish("achievement")
        end)
    end

    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_ALIVE")
    eventFrame:RegisterEvent("PLAYER_UNGHOST")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                publish("login")
                if Leaderboard.Sync and Leaderboard.Sync.SyncPeers then
                    Leaderboard.Sync:SyncPeers()
                end
            end)
        elseif event == "PLAYER_DEAD" then
            -- Publish immediately so a fast logout does not write offline=false before dead=true is stored.
            publish("PLAYER_DEAD")
        elseif event == "PLAYER_GUILD_UPDATE" then
            if Leaderboard.Sync and Leaderboard.Sync.ClearGuildLastKnown then
                Leaderboard.Sync:ClearGuildLastKnown()
            end
            publish("PLAYER_GUILD_UPDATE")
        else
            publish(event)
        end
    end)

    if self.refreshTicker then
        self.refreshTicker:Cancel()
    end
    -- Heartbeat: must run sooner than RECENT_SECONDS in LeaderboardData (offline threshold).
    self.refreshTicker = C_Timer.NewTicker(90, function()
        publish("periodic")
        if Leaderboard.Sync and Leaderboard.Sync.SyncPeers then
            Leaderboard.Sync:SyncPeers()
        end
    end)

    if self.leaderboardUIViewTicker then
        self.leaderboardUIViewTicker:Cancel()
    end
    self.leaderboardUIViewTicker = C_Timer.NewTicker(LEADERBOARD_VIEW_UI_REFRESH_SEC, function()
        local df = addon.DashboardFrame
        if df and df:IsShown() and df.SelectedTabKey == "leaderboard" and addon.RefreshDashboard then
            addon.RefreshDashboard(true)
        end
    end)
end

SLASH_HCALEADERBOARD1 = "/hcalb"
SlashCmdList.HCALEADERBOARD = function()
    if addon.Leaderboard and addon.Leaderboard.Toggle then
        addon.Leaderboard:Toggle()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if addon.Leaderboard and addon.Leaderboard.Initialize then
        addon.Leaderboard:Initialize()
    end
end)
