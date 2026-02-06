local addonName, addon = ...
local table_insert = table.insert

local achievements = {
    {
        achId = "GuildFirst_70",
        title = "Guild First: Reach Level 70",
        level = nil,
        tooltip = "You were the first in your guild to reach level 70.",
        icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\guild_first.png",
        points = 0,
        secret = true,
        staticPoints = true,
        hiddenUntilComplete = true,
        triggerAchievementId = "Level70",
        awardMode = "solo",
        requireSameGuild = true,
    },
}

-- Publish defs/trigger index immediately (so awarding works even if UI rows haven't been created yet).
if addon then
  addon.GuildFirst_DefById = addon.GuildFirst_DefById or {}
  addon.GuildFirst_ByTrigger = addon.GuildFirst_ByTrigger or {}
  for _, def in ipairs(achievements) do
    def.isSecret = true
    def.isGuildFirst = true
    addon.GuildFirst_DefById[def.achId] = def
    if def.triggerAchievementId then
      local k = tostring(def.triggerAchievementId)
      addon.GuildFirst_ByTrigger[k] = addon.GuildFirst_ByTrigger[k] or {}
      table_insert(addon.GuildFirst_ByTrigger[k], def.achId)
    end
  end
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local CreateAchievementRow = addon.CreateAchievementRow
  local AchievementPanel = addon.AchievementPanel

  for _, def in ipairs(achievements) do
    table_insert(queue, function()
      if CreateAchievementRow and AchievementPanel then
        local row = CreateAchievementRow(
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
        addon["GuildFirst_" .. def.achId .. "_Row"] = row
      end
    end)
  end
end

