local addonName, addon = ...
local ProfessionList = (addon and addon.ProfessionList) or {}
local GetSkillRank = (addon and addon.Profession and addon.Profession.GetSkillRank)
local thresholds = { 75, 150, 225, 300, 375 }
local table_insert = table.insert
local string_format = string.format

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
        return GetSkillRank and GetSkillRank(skillID) >= requiredRank
    end
end

if addon then
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local CreateAchievementRow = addon.CreateAchievementRow
  local AchievementPanel = addon.AchievementPanel
  local RegisterAchievementDef = addon.RegisterAchievementDef or (HCA_SharedUtils and HCA_SharedUtils.RegisterAchievementDef)

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

      if addon.RegisterCustomAchievement then
        addon.RegisterCustomAchievement(def.achId, nil, def.customIsCompleted)
      end

      table_insert(queue, function()
        if RegisterAchievementDef then
          RegisterAchievementDef(def)
        end
        if CreateAchievementRow and AchievementPanel then
          CreateAchievementRow(
            AchievementPanel,
            def.achId,
            def.title,
            def.tooltip,
            def.icon,
            def.level,
            def.points or 0,
            nil,
            nil,
            def.staticPoints,
            def.zone,
            def
          )
        end
      end)
    end
  end
end


