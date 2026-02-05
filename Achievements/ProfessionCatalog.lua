local thresholds = { 75, 150, 225, 300 }
local table_insert = table.insert
local string_format = string.format

local rankTitles = {
    [75]  = "Apprentice",
    [150] = "Journeyman",
    [225] = "Expert",
    [300] = "Artisan",
}

local pointsByThreshold = {
    [75]  = 10,
    [150] = 25,
    [225] = 50,
    [300] = 100,
}

local function MakeCompletionFunc(skillID, requiredRank)
    return function()
        return HCA_GetProfessionSkillRank(skillID) >= requiredRank
    end
end

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

local ProfessionTracker = _G.HCA_ProfessionCommon
local ProfessionList = (ProfessionTracker and ProfessionTracker.GetProfessionList and ProfessionTracker.GetProfessionList()) or _G.HCA_ProfessionList or {}

-- Queue all profession achievements for deferred registration
for _, profession in ipairs(ProfessionList) do
    local label = profession.name or "Profession"
    local shortKey = profession.shortKey or (label:gsub("%s+", ""))
    for _, threshold in ipairs(thresholds) do
        local achId = string_format("Profession_%s_%d", shortKey, threshold)
        local title = string_format("%s %s", rankTitles[threshold] or ("Rank " .. threshold), label)
        local tooltip = string_format("Reach %d skill in %s", threshold, label)
        
        local def = {
            achId = achId,
            title = title,
            tooltip = tooltip,
            icon = profession.icon or 136116,
            points = pointsByThreshold[threshold] or 5,
            staticPoints = true,
            allowSoloDouble = false,
            requireProfessionSkillID = profession.skillID,
            requiredProfessionRank = threshold,
            professionLabel = label,
            hiddenUntilComplete = true,
            customIsCompleted = MakeCompletionFunc(profession.skillID, threshold),
            isProfession = true,
        }
        
        table_insert(_G.HCA_RegistrationQueue, function()
            if def.customIsCompleted then
                _G[def.achId .. "_IsCompleted"] = def.customIsCompleted
            end
            
            CreateAchievementRow(
                AchievementPanel,
                def.achId,
                def.title,
                def.tooltip,
                def.icon,
                def.level,
                def.points or 0,
                nil,  -- No kill tracker for profession achievements
                nil,  -- No quest tracker for profession achievements
                def.staticPoints,
                def.zone,
                def  -- def already has isProfession = true
            )
        end)
    end
end


