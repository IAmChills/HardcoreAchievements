-- Achievements/GuildFirstCatalog.lua
-- Examples of "first" achievements with different scopes.
-- Completion is not automatic; it is awarded by `Utils/GuildFirst.lua` after a successful claim.
--
-- Scope options (achievementScope field):
--   - nil or "guild" (default): First in player's current guild
--   - "server": First on the entire server
--   - {"GuildA", "GuildB"}: First in any of the specified guilds

local achievements = {
    -- Example 1: Guild-first (default - no scope needed)
    {
        achId = "GuildFirstTest01",
        title = "Guild First: Test Claim",
        level = nil,
        tooltip = "You were the first in your guild to claim this test achievement.",
        icon = 236710,
        points = 0,
        secret = true,
        secretTitle = "Guild First (Secret)",
        secretTooltip = "Be the first in your guild to claim this secret.",
        secretIcon = 134400,
        secretPoints = 0,
        staticPoints = true,
        hiddenUntilComplete = true,
        achievementScope = "server"
    },
    
    -- Example 2: Server-first
    -- {
    --     achId = "ServerFirstTest01",
    --     title = "Server First: Test Claim",
    --     level = nil,
    --     tooltip = "You were the first on the server to claim this achievement.",
    --     icon = 236710,
    --     points = 0,
    --     secret = true,
    --     secretTitle = "Server First (Secret)",
    --     secretTooltip = "Be the first on the server to claim this secret.",
    --     secretIcon = 134400,
    --     secretPoints = 0,
    --     staticPoints = true,
    --     hiddenUntilComplete = true,
    --     achievementScope = "server",  -- Server-wide competition
    -- },
    
    -- Example 3: Custom guild pool (first in Guild A OR Guild B)
    -- {
    --     achId = "GuildPoolTest01",
    --     title = "Alliance Guilds First: Test Claim",
    --     level = nil,
    --     tooltip = "You were the first in your alliance guild to claim this achievement.",
    --     icon = 236710,
    --     points = 0,
    --     secret = true,
    --     secretTitle = "Alliance First (Secret)",
    --     secretTooltip = "Be the first in an alliance guild to claim this secret.",
    --     secretIcon = 134400,
    --     secretPoints = 0,
    --     staticPoints = true,
    --     hiddenUntilComplete = true,
    --     achievementScope = {"Alliance Guild A", "Alliance Guild B"},  -- Only these guilds compete
    -- },
}

-- Register all achievements
for _, def in ipairs(achievements) do
    _G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}
    
    table.insert(_G.HCA_RegistrationQueue, function()
        if not _G.CreateAchievementRow or not _G.AchievementPanel then
            return
        end

        def.isSecret = true
        def.isGuildFirst = true

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

