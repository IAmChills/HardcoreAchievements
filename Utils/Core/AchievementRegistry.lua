local addonName, addon = ...

-- Achievement function registry to reduce global pollution.
-- Catalogs register Kill/IsCompleted/etc. here; Common and custom paths look them up by achId.

local AchievementFunctionRegistry = {}
local CustomAchievementHandlers = {}

local function RegisterAchievementFunction(achId, funcType, func)
    if not achId or not funcType or not func then return end
    AchievementFunctionRegistry[achId] = AchievementFunctionRegistry[achId] or {}
    AchievementFunctionRegistry[achId][funcType] = func
end

local function GetAchievementFunction(achId, funcType)
    if not achId or not funcType then return nil end
    local achFuncs = AchievementFunctionRegistry[achId]
    return achFuncs and achFuncs[funcType] or nil
end

-- Custom achievement handlers (Kill/IsCompleted) for catalogs that register without Common.
local function RegisterCustomAchievement(achId, killFn, isCompletedFn)
    if not achId then return end
    CustomAchievementHandlers[achId] = CustomAchievementHandlers[achId] or {}
    if killFn then CustomAchievementHandlers[achId].Kill = killFn end
    if isCompletedFn then CustomAchievementHandlers[achId].IsCompleted = isCompletedFn end
end

local function GetCustomIsCompleted(achId)
    local h = achId and CustomAchievementHandlers[achId]
    return h and h.IsCompleted or nil
end

local function GetCustomKill(achId)
    local h = achId and CustomAchievementHandlers[achId]
    return h and h.Kill or nil
end

if addon then
    addon.GetAchievementFunction = GetAchievementFunction
    addon.RegisterAchievementFunction = RegisterAchievementFunction
    addon.RegisterCustomAchievement = RegisterCustomAchievement
    addon.GetCustomIsCompleted = GetCustomIsCompleted
    addon.GetCustomKill = GetCustomKill
    addon.RegistrationQueue = addon.RegistrationQueue or {}
end
