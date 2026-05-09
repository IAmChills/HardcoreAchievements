local addonName, addon = ...
if not addon then return end

local C_Timer = C_Timer
local CreateFrame = CreateFrame

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

local DEFAULT_SCOPE = {
    guild = true,
    realm = false,
    faction = false,
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
end

function Leaderboard:Refresh()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function Leaderboard:Toggle()
    if self.UI and self.UI.Toggle then
        self.UI:Toggle()
    end
end

function Leaderboard:Show()
    if self.UI and self.UI.Show then
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
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function()
                publish("login")
                if Leaderboard.Sync and Leaderboard.Sync.SyncPeers then
                    Leaderboard.Sync:SyncPeers()
                end
            end)
        else
            publish(event)
        end
    end)

    if self.refreshTicker then
        self.refreshTicker:Cancel()
    end
    self.refreshTicker = C_Timer.NewTicker(90, function()
        publish("periodic")
        if Leaderboard.Sync and Leaderboard.Sync.SyncPeers then
            Leaderboard.Sync:SyncPeers()
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
