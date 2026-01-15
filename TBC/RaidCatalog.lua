-- Comprehensive raid achievement definitions
local Raids = {
  -- Lower Blackrock Spire (Level 60)
  {
    achId = "UBRS",
    title = "Upper Blackrock Spire",
    tooltip = "Defeat the bosses of |cff0091e6Upper Blackrock Spire|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_generaldrakkisath.png", -- 254648
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
    tooltip = "Defeat the bosses of |cff0091e6Molten Core|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_ragnaros.png", -- 254652
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
    tooltip = "Defeat |cff0091e6Onyxia|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_onyxia.png", -- 254650
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
    tooltip = "Defeat the bosses of |cff0091e6Blackwing Lair|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_nefarion.png", -- 254649
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
    tooltip = "Defeat the bosses of |cff0091e6Zul'Gurub|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_hakkar.png", -- 236413
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
    tooltip = "Defeat the bosses of |cff0091e6Ruins of Ahn'Qiraj|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_ossiriantheunscarred.png", -- 236428
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
    tooltip = "Defeat the bosses of |cff0091e6Temple of Ahn'Qiraj|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_cthun.png", -- 236407
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
    tooltip = "Defeat the bosses of |cff0091e6Naxxramas|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_sapphiron_01.png", -- 254100
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

  -- Karazhan (Level 70)
  {
    achId = "KARA",
    title = "Karazhan",
    tooltip = "Defeat the bosses of |cff0091e6Karazhan|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_princemalchezaar_02.png", -- 254651
    points = 25,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 532,
    requiredKills = {
      [16152] = 1,  -- Attumen the Huntsman
      [15687] = 1,  -- Moroes
      ["Opera Event"] = {18168, 17521, 17533, 17534},  -- Opera Event (any one of the four)
      [16458] = 1,  -- Maiden of Virtue
      [15691] = 1,  -- The Curator
      [15688] = 1,  -- Terestian Illhoof
      [16524] = 1,  -- Shade of Aran
      [15689] = 1,  -- Netherspite
      [17225] = 1,  -- Nightbane
      [15690] = 1,  -- Prince Malchezaar
    },
    bossOrder = {16152, 15687, "Opera Event", 16458, 15691, 15688, 16524, 15689, 17225, 15690}
  },

  -- Gruul's Lair (Level 70)
  {
    achId = "GRUUL",
    title = "Gruul's Lair",
    tooltip = "Defeat the bosses of |cff0091e6Gruul's Lair|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_gruulthedragonkiller.png", -- 236412
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 565,
    requiredKills = {
      [18831] = 1,  -- High King Maulgar
      [19044] = 1,  -- Gruul the Dragonkiller
    },
    bossOrder = {18831, 19044}
  },

  -- Magtheridon's Lair (Level 70)
  {
    achId = "MAGTHERIDON",
    title = "Magtheridon's Lair",
    tooltip = "Defeat the bosses of |cff0091e6Magtheridon's Lair|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_magtheridon.png", -- 236423
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 544,
    requiredKills = {
      [17257] = 1,  -- Magtheridon
    },
    bossOrder = {17257}
  },

  -- Serpentshrine Cavern (Level 70)
  {
    achId = "SSC",
    title = "Serpentshrine Cavern",
    tooltip = "Defeat the bosses of |cff0091e6Serpentshrine Cavern|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_ladyvashj.png", -- 236422
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 548,
    requiredKills = {
      [21216] = 1,  -- Hydross the Unstable
      [21217] = 1,  -- The Lurker Below
      [21215] = 1,  -- Leotheras the Patient
      [21214] = 1,  -- Fathom-Lord Karathress
      [21213] = 1,  -- Morogrim Tidewalker
      [21212] = 1,  -- Lady Vashj
    },
    bossOrder = {21216, 21217, 21215, 21214, 21213, 21212}
  },

  -- Tempest Keep (Level 70)
  {
    achId = "TK",
    title = "Tempest Keep",
    tooltip = "Defeat the bosses of |cff0091e6Tempest Keep|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Boss_Kael'thasSunstrider_01.png", -- 250117
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 550,
    requiredKills = {
      [19516] = 1,  -- Void Reaver
      [19514] = 1,  -- Al'ar
      [18805] = 1,  -- High Astromancer Solarian
      [19622] = 1,  -- Kael'thas Sunstrider
    },
    bossOrder = {19516, 19514, 18805, 19622}
  },

  -- Hyjal Summit (Level 70)
  {
    achId = "HYJAL",
    title = "Hyjal Summit",
    tooltip = "Defeat the bosses of |cff0091e6Hyjal Summit|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_archimonde.png", -- 236402
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 534,
    requiredKills = {
      [17767] = 1,  -- Rage Winterchill
      [17808] = 1,  -- Anetheron
      [17888] = 1,  -- Kaz'rogal
      [17842] = 1,  -- Azgalor
      [17968] = 1,  -- Archimonde the Warchief
    },
    bossOrder = {17767, 17808, 17888, 17842, 17968}
  },

  -- Black Temple (Level 70)
  {
    achId = "BT",
    title = "Black Temple",
    tooltip = "Defeat the bosses of |cff0091e6Black Temple|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_illidan.png", -- 236415
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 564,
    requiredKills = {
      [22887] = 1,  -- High Warlord Naj'entus
      [22898] = 1,  -- Supremus
      [22841] = 1,  -- Shade of Akama
      [22871] = 1,  -- Teron Gorefiend
      [22948] = 1,  -- Gurtogg Bloodboil
      [23418] = 1,  -- Reliquary of Souls
      [22947] = 1,  -- Mother Shahraz
      [23426] = 1,  -- The Illidari Council
      [22917] = 1,  -- Illidan Stormrage
    },
    bossOrder = {22887, 22898, 22841, 22871, 22948, 23418, 22947, 23426, 22917}
  },

  -- Zul'Aman (Level 70)
  {
    achId = "ZA",
    title = "Zul'Aman",
    tooltip = "Defeat the bosses of |cff0091e6Zul'Aman|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_zuljin.png", -- 236438
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 568,
    requiredKills = {
      [23574] = 1,  -- Akil'zon
      [23576] = 1,  -- Nalorakk
      [23578] = 1,  -- Jan'alai
      [23577] = 1,  -- Halazzi
      [24239] = 1,  -- Hex Lord Malacrass
      [23863] = 1,  -- Zul'jin
    },
    bossOrder = {23574, 23576, 23578, 23577, 24239, 23863}
  },

  -- Sunwell Plateau (Level 70)
  {
    achId = "SWP",
    title = "Sunwell Plateau",
    tooltip = "Defeat the bosses of |cff0091e6Sunwell Plateau|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kiljaedan.png", -- 236418
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 580,
    requiredKills = {
      [24850] = 1,  -- Kalecgos
      [24892] = 1,  -- Sathrovarr
      [24882] = 1,  -- Brutallus
      [25038] = 1,  -- Felmyst
      [25166] = 1,  -- Alythess
      [25165] = 1,  -- Sacrolash
      [25741] = 1,  -- M'uru
      [25840] = 1,  -- Entropius
      [25315] = 1,  -- Kil'jaeden
    },
    bossOrder = {24850, 24892, 24882, 25038, 25166, 25165, 25741, 25840, 25315}
  },
}

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

