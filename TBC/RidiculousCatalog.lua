---------------------------------------
-- Ridiculous Achievement Definitions
---------------------------------------
-- These achievements are hidden by default and do not count towards total unless completed
local addonName, addon = ...
local UnitLevel = UnitLevel
local table_insert = table.insert

local RidiculousAchievements = {
  {
    achId = "NoJumpChallenge",
    title = "The Disciplined One",
    level = nil,
    tooltip = "Reach level 70 without jumping",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_guildperk_honorablemention.png", -- 413584
    points = 0,
    customIsCompleted = function()
      local GetCharDB = addon and addon.GetCharDB
      if not GetCharDB then
        return false
      end
      local _, cdb = GetCharDB()
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

---------------------------------------
-- Helper Functions
---------------------------------------

-- Get kill tracker function for an achievement definition
local function GetKillTracker(def)
    if def.customKill then
        return def.customKill
    end
    if (def.targetNpcId or def.requiredKills) and addon and addon.GetAchievementFunction then
        return addon.GetAchievementFunction(def.achId, "Kill")
    end
    return nil
end

-- Get quest tracker function for an achievement definition
local function GetQuestTracker(def)
    if def.requiredQuestId and addon and addon.GetAchievementFunction then
        return addon.GetAchievementFunction(def.achId, "Quest")
    end
    return nil
end

---------------------------------------
-- Registration
---------------------------------------
if addon then
  for _, def in ipairs(RidiculousAchievements) do
    if def.customIsCompleted and addon.RegisterCustomAchievement then
      addon.RegisterCustomAchievement(def.achId, nil, def.customIsCompleted)
    end
  end
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local RegisterAchievementDef = addon.RegisterAchievementDef

  for _, def in ipairs(RidiculousAchievements) do
    def.isRidiculous = true
    table_insert(queue, function()
      local killFn = GetKillTracker(def)
      local questFn = GetQuestTracker(def)
      if RegisterAchievementDef then
        RegisterAchievementDef(def)
      end
      local CreateAchievementRow = addon and addon.CreateAchievementRow
      local AchievementPanel = addon and addon.AchievementPanel
      if CreateAchievementRow and AchievementPanel then
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
      end
    end)
  end
end
