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
_G.HCA_GuildFirst_DefById = _G.HCA_GuildFirst_DefById or {}
_G.HCA_GuildFirst_ByTrigger = _G.HCA_GuildFirst_ByTrigger or {}
for _, def in ipairs(achievements) do
    def.isSecret = true
    def.isGuildFirst = true

    _G.HCA_GuildFirst_DefById[def.achId] = def
    if def.triggerAchievementId then
        local k = tostring(def.triggerAchievementId)
        _G.HCA_GuildFirst_ByTrigger[k] = _G.HCA_GuildFirst_ByTrigger[k] or {}
        table_insert(_G.HCA_GuildFirst_ByTrigger[k], def.achId)
    end
end

-- Register all achievements
for _, def in ipairs(achievements) do
    _G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}
    
    table_insert(_G.HCA_RegistrationQueue, function()
        if not _G.CreateAchievementRow or not _G.AchievementPanel then
            return
        end

        -- Store the row in a global so GuildFirst module can award it without scanning.
        local globalName = "HCA_GuildFirst_" .. def.achId .. "_Row"
        _G[globalName] = CreateAchievementRow(
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
    end)
end

