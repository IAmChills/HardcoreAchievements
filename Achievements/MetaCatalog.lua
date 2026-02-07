-- Meta achievement definitions
-- Note: MetaCommon should be loaded before this file (via .toc) and exports via addon.MetaCommon

local addonName, addon = ...
local table_insert = table.insert

---------------------------------------
-- Helper Functions
---------------------------------------

-- Get player faction to filter faction-specific achievements
local function GetPlayerFaction()
    local _, faction = UnitFactionGroup("player")
    return faction  -- "Alliance" or "Horde"
end

---------------------------------------
-- Achievement Lists
---------------------------------------

-- Quest Master - requires all quest-related achievements
-- Pre-ordered lists (sorted by level, lowest to highest)
local QUEST_ALLIANCE_ORDERED = {
  "Rageclaw", "Vagash", "Hogger", "Grawmug", "AbsentMindedProspector",
  "Fangore", "Foulborne", "GalensEscape", "Nekrosh", "Morbent", "Eliza",
  "MorLadim", "ForsakenCourier", "StinkysEscapeA", "GetMeOutOfHere",
  "ThogrunAlliance", "Kurzen", "KingBangalash", "LordShalzaru", "OOX",
  "Mokk", "MalletZF", "Mukla", "KimJaelIndeed", "StonesThatBindUs",
  "Hakkar", "ShadowLordFeldan", "SummoningThePrincess", "GorishiHiveQueen",
  "OverseerMaltorius", "DragonkinMenace", "MercutioFilthgorger",
  "HighChiefWinterfall", "Deathclasp"
}

local QUEST_HORDE_ORDERED = {
  "Dargol", "Arrachea", "Gazzuz", "Fizzle", "Goggeroc", "Kromzar", "Ataeric",
  "TheHunt", "Gizmo", "Grenka", "Ironhill", "StinkysEscapeH", "GalensEscape",
  "GetMeOutOfHere", "ThogrunHorde", "NothingButTruth", "KingBangalash",
  "Mugthol", "OOX", "Mokk", "Hatetalon", "MalletZF", "Mukla", "Kromgrul",
  "KimJaelIndeed", "StonesThatBindUs", "Hakkar", "ShadowLordFeldan",
  "SummoningThePrincess", "GorishiHiveQueen", "OverseerMaltorius",
  "MercutioFilthgorger", "HighChiefWinterfall", "Deathclasp"
}

---------------------------------------
-- Achievement List Builders
---------------------------------------

-- Classic Dungeon Master - requires all dungeon achievements
-- RFC is Horde-only, STOCK is Alliance-only
local function GetClassicDungeonMasterAchievements()
    local playerFaction = GetPlayerFaction()
    local requiredAchievements = {
        "VC", "WC", "SFK", "BFD", "RFK", "GNOM", "SM",
        "RFD", "ULD", "ZF", "MARA", "ST", "BRD", "BRS", "STRAT", "DM", "SCHOLO"
    }
    
    -- Add faction-specific dungeons
    if playerFaction == FACTION_HORDE then
        table_insert(requiredAchievements, 1, "RFC")  -- Add at the beginning
    elseif playerFaction == FACTION_ALLIANCE then
        table_insert(requiredAchievements, 6, "STOCK")  -- Add after BFD
    end
    
    return requiredAchievements
end

local function GetQuestMasterAchievements()
    local playerFaction = GetPlayerFaction()
    
    if playerFaction == FACTION_ALLIANCE then
        return QUEST_ALLIANCE_ORDERED
    elseif playerFaction == FACTION_HORDE then
        return QUEST_HORDE_ORDERED
    end
    return {}
end

-- Core Reputation Master - requires all 4 core faction reputation achievements
local function GetCoreReputationMasterAchievements()
    local playerFaction = GetPlayerFaction()
    if playerFaction == FACTION_ALLIANCE then
        return {
            "Stormwind", "Darnassus", "Ironforge", "Gnomeregan Exiles"
        }
    elseif playerFaction == FACTION_HORDE then
        return {
            "Orgrimmar", "Thunder Bluff", "Undercity", "Darkspear Trolls"
        }
    end
    return {}
end

-- Raid Master - requires all raid achievements
local function GetRaidMasterAchievements()
    return {
        "UBRS", "MC", "ONY", "BWL", "ZG", "AQ20", "AQ40", "NAXX"
    }
end

-- Secondary Profession Master - requires First Aid, Fishing, Cooking to 300
local function GetSecondaryProfessionMasterAchievements()
    return {
        "Profession_FirstAid_300",  -- Artisan First Aid
        "Profession_Fishing_300",   -- Artisan Fishing
        "Profession_Cooking_300"    -- Artisan Cooking
    }
end

---------------------------------------
-- Build Achievement Lists
---------------------------------------
local classicDungeons = GetClassicDungeonMasterAchievements()
local coreRepAchievements = GetCoreReputationMasterAchievements()
local raidAchievements = GetRaidMasterAchievements()
local secondaryProfAchievements = GetSecondaryProfessionMasterAchievements()

---------------------------------------
-- Meta Achievement Definitions
---------------------------------------

local MetaAchievements = {
  {
    achId = "DungeonMeta",
    title = "The Dungeon Master",
    tooltip = "Complete all dungeon achievements",
    icon = 255345,
    points = 100,
    requiredAchievements = classicDungeons,
    achievementOrder = classicDungeons
  },
  {
    achId = "QuestMeta",
    title = "The Diplomat",
    tooltip = "Complete all quest-related achievements",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_Misc_Trophy_Argent.png", -- ??
    points = 100,
    requiredAchievements = nil, -- Will be set at registration time after sorting
    achievementOrder = nil -- Will be set at registration time after sorting
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
    tooltip = "Reach 300 skill in all secondary professions",
    icon = 237570,
    points = 100,
    requiredAchievements = secondaryProfAchievements,
    achievementOrder = secondaryProfAchievements
  },
  {
    achId = "Meta",
    title = "Metalomaniac",
    tooltip = "Complete all meta achievements",
    icon = 255343,
    points = 500,
    requiredAchievements = {"DungeonMeta", "QuestMeta", "CoreRepMeta", "SecoProfMeta"},
    achievementOrder = {"DungeonMeta", "QuestMeta", "CoreRepMeta", "SecoProfMeta"}
  }
}

---------------------------------------
-- Registration
---------------------------------------

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
if addon then
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local MetaCommon = addon and addon.MetaCommon
  if MetaCommon and MetaCommon.registerMetaAchievement then
    for _, meta in ipairs(MetaAchievements) do
      table_insert(queue, function()
        if meta.achId == "QuestMeta" then
          local questAchievements = GetQuestMasterAchievements()
          meta.requiredAchievements = questAchievements
          meta.achievementOrder = questAchievements
        end
        MetaCommon.registerMetaAchievement(meta)
      end)
    end
  end
end
