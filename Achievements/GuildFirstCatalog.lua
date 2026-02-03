-- Achievements/GuildFirstCatalog.lua
-- Minimal test "guild first" secret achievement.
-- Completion is not automatic; it is awarded by `Utils/GuildFirst.lua` after a successful claim.

local def = {
    achId = "GuildFirstTest01",
    title = "Guild First: Test Claim",
    level = nil,
    tooltip = "You were the first in your guild to claim this test achievement.",
    icon = 236710, -- snowball icon (re-use)
    points = 0,

    -- Secret presentation before completion
    secret = true,
    secretTitle = "Guild First (Secret)",
    secretTooltip = "Be the first in your guild to claim this secret.",
    secretIcon = 134400, -- question mark
    secretPoints = 0,
    staticPoints = true,

    -- Hide from lists until completed
    hiddenUntilComplete = true,
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts (matches SecretCatalog pattern)
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

table.insert(_G.HCA_RegistrationQueue, function()
    if not _G.CreateAchievementRow or not _G.AchievementPanel then
        return
    end

    def.isSecret = true

    -- Store the row in a global so GuildFirst module can award it without scanning.
    _G.HCA_GuildFirst_TestRow = CreateAchievementRow(
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

