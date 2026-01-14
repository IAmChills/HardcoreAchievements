-- Ridiculous achievement definitions
-- These achievements are hidden by default and do not count towards total unless completed
local RidiculousAchievements = {
  {
    achId = "NoJumpChallenge",
    title = "The Disciplined One",
    level = nil,
    tooltip = "Reach level 70 without jumping",
    icon = 413584,
    points = 0,
    customIsCompleted = function()
      if not _G.HardcoreAchievements_GetCharDB then
        return false
      end
      local _, cdb = _G.HardcoreAchievements_GetCharDB()
      if not cdb or not cdb.stats or not cdb.stats.playerJumps then
        return false
      end
      
      -- Check if achievement is already failed (e.g., player was max level on first load)
      local achId = "NoJumpChallenge"
      local rec = cdb.achievements and cdb.achievements[achId]
      if rec and rec.failed then
        return false
      end
      
      -- Only award if player is max level and has 0 jumps
      return UnitLevel("player") >= 70 and cdb.stats.playerJumps == 0
    end,
    staticPoints = true,
  },
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all ridiculous achievements for deferred registration
for _, def in ipairs(RidiculousAchievements) do
  -- Mark as ridiculous for filtering
  def.isRidiculous = true
  -- Queue achievement registration
  table.insert(_G.HCA_RegistrationQueue, function()
    if def.customIsCompleted then
      _G[def.achId .. "_IsCompleted"] = def.customIsCompleted
    end
    
    local killFn = def.customKill or ((def.targetNpcId or def.requiredKills) and _G.HardcoreAchievements_GetAchievementFunction(def.achId, "Kill")) or nil
    local questFn = (def.requiredQuestId and _G.HardcoreAchievements_GetAchievementFunction(def.achId, "Quest")) or nil

    CreateAchievementRow(
      AchievementPanel,
      def.achId,
      def.title,
      def.tooltip,
      def.icon,
      def.level,
      def.points or 0,
      killFn,
      questFn,
      def.staticPoints,
      def.zone,
      def
    )
  end)
end
