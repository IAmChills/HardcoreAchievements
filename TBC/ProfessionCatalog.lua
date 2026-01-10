local thresholds = { 75, 150, 225, 300, 375 }

local rankTitles = {
    [75]  = "Apprentice",
    [150] = "Journeyman",
    [225] = "Expert",
    [300] = "Artisan",
    [375] = "Master",
}

local pointsByThreshold = {
    [75]  = 10,
    [150] = 25,
    [225] = 50,
    [300] = 100,
    [375] = 150,
}

local function MakeCompletionFunc(skillID, requiredRank)
    return function()
        return HCA_GetProfessionSkillRank(skillID) >= requiredRank
    end
end

function _G.HCA_AppendProfessionAchievements(addFunc)
    if type(addFunc) ~= "function" then return end

    local ProfessionTracker = _G.HCA_ProfessionCommon
    local ProfessionList = (ProfessionTracker and ProfessionTracker.GetProfessionList and ProfessionTracker.GetProfessionList()) or _G.HCA_ProfessionList or {}

    for _, profession in ipairs(ProfessionList) do
        local label = profession.name or "Profession"
        local shortKey = profession.shortKey or (label:gsub("%s+", ""))
        for _, threshold in ipairs(thresholds) do
            local achId = string.format("Profession_%s_%d", shortKey, threshold)
            local title = string.format("%s %s", rankTitles[threshold] or ("Rank " .. threshold), label)
            local tooltip = string.format("Reach %d skill in %s", threshold, label)

            addFunc({
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
            })
        end
    end
end


