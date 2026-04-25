-- Ridiculous achievement definitions
-- These achievements are hidden by default and do not count towards total unless completed
local addonName, addon = ...
local UnitLevel = UnitLevel
local table_insert = table.insert

local RidiculousAchievements = {
  {
    achId = "NoJumpChallenge",
    title = "The Disciplined One",
    level = nil,
    tooltip = "Reach level 60 without jumping\n\n|cffffffffA jump is any instance of jumping in the air. Falling does not count as a jump.|r",
    icon = 413584,
    points = 0,
    supportsStoredFailure = true,
    customIsCompleted = function()
      local GetCharDB = addon and addon.GetCharDB
      if not GetCharDB then
        return false
      end
      local _, cdb = GetCharDB()
      local jumpCount = cdb and cdb.stats and cdb.stats.playerJumps
      if jumpCount == nil then
        return false
      end
      
      -- Check if achievement is already failed (e.g., player was max level on first load)
      local achId = "NoJumpChallenge"
      local rec = cdb.achievements and cdb.achievements[achId]
      if rec and rec.failed then
        return false
      end
      
      -- Any tracked jump disqualifies the run immediately.
      if jumpCount > 0 then
        return false
      end

      -- Only award if player reaches max level with a verified zero-jump count.
      return UnitLevel("player") >= 60 and jumpCount == 0
    end,
    staticPoints = true,
  },
  {
    achId = "NoWeaponChallenge",
    title = "Knuckle Up",
    level = nil,
    tooltip = "Reach level 60 without using a weapon (cannot have a mainhand, offhand, ranged equipped)\n\n|cffffffffA weapon may never be equipped at any point in the run. It is possible to start the run with a weapon equipped, but it must be removed before gaining experience.|r",
    icon = "Interface\\Icons\\INV_Gauntlets_04",
    points = 0,
    supportsStoredFailure = true,
    customIsCompleted = function()
      local GetCharDB = addon and addon.GetCharDB
      if not GetCharDB then
        return false
      end
      local _, cdb = GetCharDB()
      local playerWeapons = cdb and cdb.stats and cdb.stats.playerWeapons
      if playerWeapons == nil then
        return false
      end

      -- Check if achievement is already failed (e.g., player was max level on first load)
      local achId = "NoWeaponChallenge"
      local rec = cdb.achievements and cdb.achievements[achId]
      if rec and rec.failed then
        return false
      end

      -- Any tracked weapon use disqualifies the run immediately.
      if playerWeapons == true then
        return false
      end

      -- Only award if player reaches max level with a verified clean run.
      return UnitLevel("player") >= 60 and playerWeapons == false
    end,
    staticPoints = true,
  },
  {
    achId = "NoArmorChallenge",
    title = "Birthday Suit",
    level = nil,
    tooltip = "Reach level 60 while completely nude (equipment slots 0-19 must remain empty)\n\n|cffffffffAll equipped gear must be removed before gaining experience, and no item may be equipped afterward.|r",
    icon = 133886,
    points = 0,
    supportsStoredFailure = true,
    customIsCompleted = function()
      local GetCharDB = addon and addon.GetCharDB
      if not GetCharDB then
        return false
      end
      local _, cdb = GetCharDB()
      local playerNude = cdb and cdb.stats and cdb.stats.playerNude
      if playerNude == nil then
        return false
      end

      local achId = "NoArmorChallenge"
      local rec = cdb.achievements and cdb.achievements[achId]
      if rec and rec.failed then
        return false
      end

      if playerNude == true then
        return false
      end

      return UnitLevel("player") >= 60 and playerNude == false
    end,
    staticPoints = true,
  }
}

---------------------------------------
-- Helper Functions
---------------------------------------
local function GetKillTracker(def)
    if def.customKill then
        return def.customKill
    end
    if (def.targetNpcId or def.requiredKills) and addon and addon.GetAchievementFunction then
        return addon.GetAchievementFunction(def.achId, "Kill")
    end
    return nil
end

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
