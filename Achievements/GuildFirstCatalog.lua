-- Achievements/GuildFirstCatalog.lua
-- Examples of "first" achievements with different scopes.
-- Completion is not automatic; it is awarded by `Utils/GuildFirst.lua` after a successful claim.
--
-- Scope options (achievementScope field):
--   - nil or "guild" (default): First in player's current guild
--   - "server": First on the entire server
--   - {"GuildA", "GuildB"}: First in any of the specified guilds
--
-- GuildFirst data-driven wiring (optional per achievement):
--   - triggerAchievementId: when this standard achievement completes, attempt to claim this GuildFirst entry
--   - awardMode: "solo" | "party" | "raid" | "group"
--       - solo  : only the claimant
--       - party : up to 5 (party roster)
--       - raid  : up to 40 (raid roster)
--       - group : raid if in raid, else party if in group, else solo
--   - requireSameGuild: boolean (default: true for guild-scoped claims, else false)

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
        achievementScope = "server",
        awardMode = "solo",
    },

    -- Real example: Raid-wide guild first for Molten Core (awarded to eligible raid members)
    {
        achId = "GuildFirst_MC",
        title = "Guild First: Molten Core",
        level = nil,
        tooltip = "Your raid was the first in your guild to conquer " .. HCA_SharedUtils.GetClassColor() .. "Molten Core|r.",
        icon = 254652, -- Molten Core icon (matches RaidCatalog)
        points = 0,
        secret = true,
        secretTitle = "Guild First (Secret)",
        secretTooltip = "Be part of the first raid in your guild to conquer Molten Core.",
        secretIcon = 254652,
        secretPoints = 0,
        staticPoints = true,
        hiddenUntilComplete = true,
        triggerAchievementId = "MC",
        awardMode = "raid",
        requireSameGuild = true,
        -- achievementScope omitted -> defaults to guild-first
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
        table.insert(_G.HCA_GuildFirst_ByTrigger[k], def.achId)
    end
end

-- Register all achievements
for _, def in ipairs(achievements) do
    _G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}
    
    table.insert(_G.HCA_RegistrationQueue, function()
        if not _G.CreateAchievementRow or not _G.AchievementPanel then
            return
        end

        -- (def.isSecret/isGuildFirst already set above; keep consistent if other code mutates)
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

