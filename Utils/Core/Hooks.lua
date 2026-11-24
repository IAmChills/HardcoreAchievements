local addonName, addon = ...
local table_insert = table.insert

-- =========================================================
-- Hook System for Addon Integration
-- =========================================================
-- Allows other addons to register callbacks for achievement events
--
-- Usage example for other addons:
--   if HardcoreAchievements and HardcoreAchievements.Hooks then
--       HardcoreAchievements.Hooks:HookScript("OnAchievement", function(achievementData)
--           -- achievementData contains:
--           --   achievementId: string - The achievement ID
--           --   title: string - The achievement title
--           --   points: number - Points awarded for this achievement
--           --   completedAt: number - Timestamp of completion
--           --   level: number - Player level at completion
--           --   wasSolo: boolean - Whether it was completed solo
--           --   completedCount: number - Total number of completed achievements (after this one)
--           --   totalCount: number - Total number of achievements
--           --   totalPoints: number - Total points across all completed achievements (after this one)
--       end)
--   end

local HookSystem = {
    hooks = {}
}

local PublicHooks = {}

local function SnapshotHookList(hookList)
    local count = #hookList
    if count == 0 then
        return nil
    end

    local snapshot = {}
    for i = 1, count do
        snapshot[i] = hookList[i]
    end
    return snapshot
end

local function ShallowCopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function HookSystem:HookScript(eventName, callback)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        return
    end
    self.hooks[eventName] = self.hooks[eventName] or {}
    table_insert(self.hooks[eventName], callback)
end

function HookSystem:FireEvent(eventName, ...)
    local eventHooks = self.hooks[eventName]
    local hookSnapshot = eventHooks and SnapshotHookList(eventHooks)
    local args = {...}
    local singleTablePayload = (#args == 1 and type(args[1]) == "table")

    if hookSnapshot then
        for _, callback in ipairs(hookSnapshot) do
            local success, err
            if singleTablePayload then
                success, err = pcall(callback, ShallowCopyTable(args[1]))
            else
                success, err = pcall(callback, unpack(args))
            end
            if not success and addon and addon.DebugPrint then
                addon.DebugPrint("Error in hook callback for " .. tostring(eventName) .. ": " .. tostring(err))
            end
        end
    end
end

function PublicHooks:HookScript(eventName, callback)
    return HookSystem:HookScript(eventName, callback)
end

-- Internal hook access for files loaded in this addon.
if addon then
    addon.Hooks = HookSystem
end

-- Public namespace for external addons.
_G.HardcoreAchievements = _G.HardcoreAchievements or {}
_G.HardcoreAchievements.Hooks = PublicHooks
