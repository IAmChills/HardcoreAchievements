---------------------------------------
-- Raid Achievement Definitions
---------------------------------------
local Raids = {
  -- Lower Blackrock Spire (Level 60)
  {
    achId = "UBRS",
    title = "Upper Blackrock Spire",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Upper Blackrock Spire|r",
    icon = 254648,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 229,
    requiredKills = {
      [9816] = 1,  -- Pyroguard Emberseer
      [10429] = 1, -- Warchief Rend Blackhand
      [10339] = 1, -- Gyth
      [10430] = 1, -- The Beast
      [10363] = 1, -- General Drakkisath
    },
    bossOrder = {9816, 10429, 10339, 10430, 10363}
  },
  
  -- Molten Core (Level 60)
  {
    achId = "MC",
    title = "Molten Core",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Molten Core|r",
    icon = 254652,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 409,
    requiredKills = {
      [12118] = 1,  -- Lucifron
      [11982] = 1,  -- Magmadar
      [12259] = 1,  -- Gehennas
      [12057] = 1,  -- Garr
      [12264] = 1,  -- Shazzrah
      [12056] = 1,  -- Baron Geddon
      [11988] = 1,  -- Golemagg the Incinerator
      [12098] = 1,  -- Sulfuron Harbinger
      [12018] = 1,  -- Majordomo Executus
      [11502] = 1,  -- Ragnaros
    },
    bossOrder = {12118, 11982, 12259, 12057, 12264, 12056, 11988, 12098, 12018, 11502}
  },

  -- Onyxia's Lair (Level 60)
  {
    achId = "ONY",
    title = "Onyxia's Lair",
    tooltip = "Defeat " .. HCA_SharedUtils.GetClassColor() .. "Onyxia|r",
    icon = 254650,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 249,
    requiredKills = {
      [10184] = 1,  -- Onyxia
    },
    bossOrder = {10184}
  },

  -- Blackwing Lair (Level 60)
  {
    achId = "BWL",
    title = "Blackwing Lair",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Blackwing Lair|r",
    icon = 254649,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 469,
    requiredKills = {
      [12435] = 1,  -- Razorgore the Untamed
      [13020] = 1,  -- Vaelastrasz the Corrupt
      [12017] = 1,  -- Broodlord Lashlayer
      [11983] = 1,  -- Firemaw
      [14601] = 1,  -- Ebonroc
      [11981] = 1,  -- Flamegor
      [14020] = 1,  -- Chromaggus
      [11583] = 1,  -- Nefarian
    },
    bossOrder = {12435, 13020, 12017, 11983, 14601, 11981, 14020, 11583}
  },

  -- Zul'Gurub (Level 60)
  {
    achId = "ZG",
    title = "Zul'Gurub",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Zul'Gurub|r",
    icon = 236413,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 309,
    requiredKills = {
      [14517] = 1,  -- High Priestess Jeklik
      [14507] = 1,  -- High Priest Venoxis
      [14510] = 1,  -- High Priestess Mar'li
      [14509] = 1,  -- High Priest Thekal
      [14515] = 1,  -- High Priestess Arlokk
      [11382] = 1,  -- Bloodlord Mandokir
      ["Edge of Madness"] = {15082, 15083, 15084, 15085},  -- Edge of Madness (any one of the four)
      [15114] = 1,  -- Gahz'ranka
      [11380] = 1,  -- Jin'do the Hexxer
      [14834] = 1,  -- Hakkar
    },
    bossOrder = {14517, 14507, 14510, 14509, 14515, 11382, "Edge of Madness", 15114, 11380, 14834}
  },

  -- Ruins of Ahn'Qiraj (Level 60)
  {
    achId = "AQ20",
    title = "Ruins of Ahn'Qiraj",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Ruins of Ahn'Qiraj|r",
    icon = 236428,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 509,
    requiredKills = {
      [15348] = 1,  -- Kurinnaxx
      [15341] = 1,  -- General Rajaxx
      [15340] = 1,  -- Moam
      [15370] = 1,  -- Buru the Gorger
      [15369] = 1,  -- Ayamiss the Hunter
      [15339] = 1,  -- Ossirian the Unscarred
    },
    bossOrder = {15348, 15341, 15340, 15370, 15369, 15339}
  },

  -- Temple of Ahn'Qiraj (Level 60)
  {
    achId = "AQ40",
    title = "Temple of Ahn'Qiraj",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Temple of Ahn'Qiraj|r",
    icon = 236407,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 531,
    requiredKills = {
      [15263] = 1,  -- The Prophet Skeram
      [15511] = 1,  -- Lord Kri
      [15544] = 1,  -- Vem
      [15543] = 1,  -- Princess Yauj
      [15516] = 1,  -- Battleguard Sartura
      [15510] = 1,  -- Fankriss the Unyielding
      [15509] = 1,  -- Princess Huhuran
      [15276] = 1,  -- Twin Emperors (Vek'lor)
      [15275] = 1,  -- Twin Emperors (Vek'nilash)
      [15299] = 1,  -- Viscidus
      [15517] = 1,  -- Ouro
      [15727] = 1,  -- C'Thun
    },
    bossOrder = {15263, 15511, 15544, 15543, 15516, 15510, 15509, 15276, 15275, 15299, 15517, 15727}
  },

  -- Naxxramas (Level 60)
  {
    achId = "NAXX",
    title = "Naxxramas",
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Naxxramas|r",
    icon = 254100,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 533,
    requiredKills = {
      [15956] = 1,  -- Anub'Rekhan
      [15953] = 1,  -- Grand Widow Faerlina
      [15952] = 1,  -- Maexxna
      [15954] = 1,  -- Noth the Plaguebringer
      [15936] = 1,  -- Heigan the Unclean
      [16011] = 1,  -- Loatheb
      [16061] = 1,  -- Instructor Razuvious
      [16060] = 1,  -- Gothik the Harvester
      [16064] = 1,  -- Thane Korth'azz (Four Horsemen)
      [16065] = 1,  -- Lady Blaumeux (Four Horsemen)
      [16062] = 1,  -- Highlord Mograine (Four Horsemen)
      [16063] = 1,  -- Sir Zeliek (Four Horsemen)
      [16028] = 1,  -- Patchwerk
      [15931] = 1,  -- Grobbulus
      [15932] = 1,  -- Gluth
      [15928] = 1,  -- Thaddius
      [15989] = 1,  -- Sapphiron
      [15990] = 1,  -- Kel'Thuzad
    },
    bossOrder = {15956, 15953, 15952, 15954, 15936, 16011, 16061, 16060, 16064, 16065, 16062, 16063, 16028, 15931, 15932, 15928, 15989, 15990}
  },
}

---------------------------------------
-- Deferred Registration Queue
---------------------------------------

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all raid achievements for deferred registration
-- Note: RaidCommon must be loaded before this file (RaidCommon.lua should be in .toc before RaidCatalog.lua)
if _G.RaidCommon and _G.RaidCommon.registerRaidAchievement then
  for _, raid in ipairs(Raids) do
    table.insert(_G.HCA_RegistrationQueue, function()
      RaidCommon.registerRaidAchievement(raid)
    end)
  end
end

