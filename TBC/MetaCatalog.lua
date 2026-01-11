-- Meta achievement definitions for TBC
-- Note: MetaCommon should be loaded before this file (via .toc) and exports via _G.MetaCommon

-- Get player faction to filter faction-specific achievements
local function GetPlayerFaction()
  local _, faction = UnitFactionGroup("player")
  return faction  -- "Alliance" or "Horde"
end

-- TBC Dungeon Master - requires all classic dungeon achievements plus TBC dungeon achievements
-- RFC is Horde-only, STOCK is Alliance-only
local function GetTBCDungeonMasterAchievements()
  local playerFaction = GetPlayerFaction()
  local requiredAchievements = {
    "VC", "WC", "SFK", "BFD", "RFK", "GNOM", "SM",
    "RFD", "ULD", "ZF", "MARA", "ST", "BRD", "BRS", "STRAT", "DM", "SCHOLO",
    -- TBC dungeons
    "RAMPARTS", "BLOODFURNACE", "SLAVEPENS", "UNDERBOG", "MANATOMBS", "AC",
    "OLDHILLSBRAD", "SETHEKK", "BLACKMORASS", "MECHANAR", "SHATTEREDHALLS",
    "SLABS", "STEAMVAULT", "BOTANICA", "MT", "ARCATRAZ"
  }
  
  -- Add faction-specific dungeons
  if playerFaction == FACTION_HORDE then
    table.insert(requiredAchievements, 1, "RFC")  -- Add at the beginning
  elseif playerFaction == FACTION_ALLIANCE then
    table.insert(requiredAchievements, 6, "STOCK")  -- Add after BFD
  end
  
  return requiredAchievements
end

local tbcDungeons = GetTBCDungeonMasterAchievements()

-- Quest Master - requires all classic and TBC quest achievements
-- Pre-ordered lists (sorted by level from TBC/Catalog.lua, lowest to highest)
local QUEST_ALLIANCE_ORDERED = {
  "Rageclaw", "Vagash", "Hogger", "Grawmug", "AbsentMindedProspector",
  "Foulborne", "Fangore", "Nekrosh", "Eliza", "MorLadim", "Morbent",
  "ForsakenCourier", "StinkysEscapeA", "OttoFalcon", "Kurzen", "GalensEscape",
  "GetMeOutOfHere", "KingBangalash", "Mokk", "SummoningThePrincess",
  "LordShalzaru", "OOX", "MalletZF", "OverseerMaltorius", "Hakkar",
  "KimJaelIndeed", "GorishiHiveQueen", "StonesThatBindUs", "MercutioFilthgorger",
  "ShadowLordFeldan", "HighChiefWinterfall", "Deathclasp", "Overlord", "RingOfBlood",
  "FelReaverA"
}

local QUEST_HORDE_ORDERED = {
  "Arrachea", "Dargol", "Fizzle", "Gazzuz", "Goggeroc", "Kromzar",
  "Drathir", "Ataeric", "LuzKnuck", "Gizmo", "TheHunt", "Grenka",
  "Ironhill", "StinkysEscapeH", "GalensEscape", "NothingButTruth",
  "GetMeOutOfHere", "Mugthol", "KingBangalash", "Mokk", "SummoningThePrincess",
  "OOX", "Hatetalon", "MalletZF", "OverseerMaltorius", "Hakkar",
  "KimJaelIndeed", "Kromgrul", "GorishiHiveQueen", "StonesThatBindUs",
  "MercutioFilthgorger", "ShadowLordFeldan", "HighChiefWinterfall", "Deathclasp",
  "Cruel", "RingOfBlood", "FelReaverH"
}

local function GetQuestMasterAchievements()
  local playerFaction = GetPlayerFaction()
  
  if playerFaction == FACTION_ALLIANCE then
    return QUEST_ALLIANCE_ORDERED
  elseif playerFaction == FACTION_HORDE then
    return QUEST_HORDE_ORDERED
  end
end

-- Core Reputation Master - requires all 4 classic core faction reputation achievements plus TBC core factions
local function GetCoreReputationMasterAchievements()
  local playerFaction = GetPlayerFaction()
  if playerFaction == FACTION_ALLIANCE then
    return {
      "Stormwind", "Darnassus", "Ironforge", "Gnomeregan Exiles", -- Classic
      "Exodar"-- TBC
    }
  elseif playerFaction == FACTION_HORDE then
    return {
      "Orgrimmar", "Thunder Bluff", "Undercity", "Darkspear Trolls", -- Classic
      "Silvermoon City" -- TBC
    }
  end
end

-- Raid Master - requires all classic raid achievements plus TBC raid achievements
local function GetRaidMasterAchievements()
  return {
    "UBRS", "MC", "ONY", "BWL", "ZG", "AQ20", "AQ40", "NAXX", -- Classic
    "KARA", "GRUUL", "MAGTHERIDON", "SSC", "TK", "HYJAL", "BT", "ZA", "SWP" -- TBC
  }
end

-- Secondary Profession Master - requires First Aid, Fishing, Cooking to 375 (Master)
local function GetSecondaryProfessionMasterAchievements()
  return {
    "Profession_FirstAid_375",  -- Master First Aid
    "Profession_Fishing_375",   -- Master Fishing
    "Profession_Cooking_375"    -- Master Cooking
  }
end

local coreRepAchievements = GetCoreReputationMasterAchievements()
local raidAchievements = GetRaidMasterAchievements()
local secondaryProfAchievements = GetSecondaryProfessionMasterAchievements()

local MetaAchievements = {
  {
    achId = "DungeonMeta",
    title = "The Dungeon Master",
    tooltip = "Complete all dungeon achievements",
    icon = 255347,
    points = 100,
    requiredAchievements = tbcDungeons,
    achievementOrder = tbcDungeons
  },
  {
    achId = "QuestMeta",
    title = "The Diplomat",
    tooltip = "Complete all quest-related achievements",
    icon = 236670,
    points = 100,
    requiredAchievements = nil, -- Will be set at registration time
    achievementOrder = nil -- Will be set at registration time
  },
  {
    achId = "CoreRepMeta",
    title = "The Ambassador",
    tooltip = "Earn exalted reputation with all home cities",
    icon = 236685,
    points = 100,
    requiredAchievements = coreRepAchievements,
    achievementOrder = coreRepAchievements
  },
  {
    achId = "RaidMeta",
    title = "The Raider",
    tooltip = "Complete all raid achievements",
    icon = 255346,
    points = 100,
    requiredAchievements = raidAchievements,
    achievementOrder = raidAchievements
  },
  {
    achId = "SecoProfMeta",
    title = "The Scholar",
    tooltip = "Reach 375 skill in all secondary professions",
    icon = 237570,
    points = 100,
    requiredAchievements = secondaryProfAchievements,
    achievementOrder = secondaryProfAchievements
  },
  {
    achId = "Meta",
    title = "Metalomaniac",
    tooltip = "Complete all meta achievements",
    icon = 236247,
    points = 500,
    requiredAchievements = {"DungeonMeta", "QuestMeta", "CoreRepMeta", "RaidMeta", "SecoProfMeta"},
    achievementOrder = {"DungeonMeta", "QuestMeta", "CoreRepMeta", "RaidMeta", "SecoProfMeta"}
  }
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
-- Create global registration queue if it doesn't exist
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all meta achievements for deferred registration
for _, meta in ipairs(MetaAchievements) do
  table.insert(_G.HCA_RegistrationQueue, function()
    if _G.MetaCommon and _G.MetaCommon.registerMetaAchievement then
      -- For QuestMeta, set achievements at registration time
      if meta.achId == "QuestMeta" then
        local questAchievements = GetQuestMasterAchievements()
        meta.requiredAchievements = questAchievements
        meta.achievementOrder = questAchievements
      end
      _G.MetaCommon.registerMetaAchievement(meta)
    end
  end)
end
