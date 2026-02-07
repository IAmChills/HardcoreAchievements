---------------------------------------
-- Heroic Dungeon Achievement Definitions
---------------------------------------
local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor())
local table_insert = table.insert

local HeroicDungeons = {
  -- Hellfire Ramparts (Both, Level 70)
  {
    achId = "HRAMPARTS",
    title = "Hellfire Ramparts |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Hellfire Ramparts (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_omartheunscarred_01.png", -- 236427
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 543,
    requiredKills = {
      [18436] = 1, -- Watchkeeper Gargolmar
      [18433] = 1, -- Omar the Unscarred
      [18432] = 1, -- Nazan
      [18434] = 1, -- Vazruden
    },
    bossOrder = {18436, 18433, 18432, 18434}
  },

  -- Hellfire Ramparts (Both, Level 70)
  {
    achId = "HBLOODFURNACE",
    title = "Blood Furnace |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Blood Furnace (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kelidanthebreaker.png", -- 236417
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 542,
    requiredKills = {
      [18621] = 1, -- The Maker
      [18601] = 1, -- Broggok
      [18607] = 1, -- Keli'dan the Breaker
    },
    bossOrder = {18621, 18601, 18607}
  },

  -- The Slave Pens (Both, Level 70)
  {
    achId = "HSLAVEPENS",
    title = "The Slave Pens |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Slave Pens (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_quagmirran.png", -- 236433
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 547,
    requiredKills = {
      [19893] = 1, -- Mennu the Betrayer
      [19895] = 1, -- Rokmar the Crackler
      [19894] = 1, -- Quagmirran
    },
    bossOrder = {19893, 19895, 19894}
  },

  -- The Underbog (Both, Level 70)
  {
    achId = "HUNDERBOG",
    title = "The Underbog |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Underbog (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_theblackstalker.png", -- 254502
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 546,
    requiredKills = {
      [20169] = 1, -- Hungarfen
      [20168] = 1, -- Ghaz'an
      [20183] = 1, -- Swamplord Musel'ek
      [20184] = 1, -- The Black Stalker
    },
    bossOrder = {20169, 20168, 20183, 20184}
  },

  -- Mana-Tombs (Both, Level 70)
  {
    achId = "HMANATOMBS",
    title = "Mana-Tombs |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Mana-Tombs (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_nexus_prince_shaffar.png", -- 236426
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 557,
    requiredKills = {
      [20267] = 1, -- Pandemonius
      [20268] = 1, -- Tavarok
      [20266] = 1, -- Nexus-Prince Shaffar
    },
    bossOrder = {20267, 20268, 20266}
  },

  -- Auchenai Crypts (Both, Level 70)
  {
    achId = "HAC",
    title = "Auchenai Crypts |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Auchenai Crypts (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_exarch_maladaar.png", -- 236411
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 558,
    requiredKills = {
      [20318] = 1, -- Shirrak the Dead Watcher
      [20306] = 1, -- Exarch Maladaar
    },
    bossOrder = {20318, 20306}
  },

  -- Old Hillsbrad Foothills (Both, Level 70)
  {
    achId = "HOLDHILLSBRAD",
    title = "Old Hillsbrad Foothills |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Old Hillsbrad Foothills (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_epochhunter.png", -- 254647
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 560,
    requiredKills = {
      [20535] = 1, -- Lieutenant Drake
      [20521] = 1, -- Captain Skarloc
      [20531] = 1, -- Epoch Hunter
    },
    bossOrder = {20535, 20521, 20531}
  },

  -- Sethekk Halls (Both, Level 70)
  {
    achId = "HSETHEKK",
    title = "Sethekk Halls |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Sethekk Halls (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_talonkingikiss.png", -- 236435
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 556,
    requiredKills = {
      [20690] = 1, -- Darkweaver Syth
      [20706] = 1, -- Talon King Ikiss
      [23035] = 1, -- Anzu
    },
    bossOrder = {20690, 20706, 23035}
  },

  -- The Black Morass (Both, Level 70)
  {
    achId = "HBLACKMORASS",
    title = "The Black Morass |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Black Morass (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_aeonus_01.png", -- 254086
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 269,
    requiredKills = {
      [20738] = 1, -- Chrono Lord Deja
      [20745] = 1, -- Temporus
      [20737] = 1, -- Aeonus
    },
    bossOrder = {20738, 20745, 20737}
  },

  -- The Mechanar (Both, Level 70)
  {
    achId = "HMECHANAR",
    title = "The Mechanar |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Mechanar (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_pathaleonthecalculator.png", -- 236430
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 554,
    requiredKills = {
      [21533] = 1, -- Mechano-Lord Capacitus
      [21536] = 1, -- Nethermancer Sepethrea
      [21537] = 1, -- Pathaleon the Calculator
    },
    bossOrder = {21533, 21536, 21537}
  },

  -- The Shattered Halls (Both, Level 70)
  {
    achId = "HSHATTEREDHALLS",
    title = "The Shattered Halls |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Shattered Halls (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kargathbladefist_01.png", -- 254093
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 540,
    requiredKills = {
      [20568] = 1, -- Grand Warlock Nethekurse
      [20923] = 1, -- Blood Guard Porung
      [20596] = 1, -- Warbringer O'mrogg
      [20597] = 1, -- Warchief Kargath Bladefist
    },
    bossOrder = {20568, 20923, 20596, 20597}
  },

  -- Shadow Labyrinth (Both, Level 70)
  {
    achId = "HSLABS",
    title = "Shadow Labyrinth |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Shadow Labyrinth (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_murmur.png", -- 254501
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 555,
    requiredKills = {
      [20636] = 1, -- Ambassador Hellmaw
      [20637] = 1, -- Blackheart the Inciter
      [20653] = 1, -- Grandmaster Vorpil
      [20657] = 1, -- Murmur
    },
    bossOrder = {20636, 20637, 20653, 20657}
  },

  -- The Steamvault (Both, Level 70)
  {
    achId = "HSTEAMVAULT",
    title = "The Steamvault |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Steamvault (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_warlord_kalithresh.png", -- 236436
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 545,
    requiredKills = {
      [20629] = 1, -- Hydromancer Thespia
      [20630] = 1, -- Mekgineer Steamrigger
      [20633] = 1, -- Warlord Kalithresh
    },
    bossOrder = {20629, 20630, 20633}
  },

  -- The Botanica (Both, Level 70)
  {
    achId = "HBOTANICA",
    title = "The Botanica |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Botanica (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_warpsplinter.png", -- 236437
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 553,
    requiredKills = {
      [21551] = 1, -- Commander Sarannis
      [21558] = 1, -- High Botanist Freywinn
      [21581] = 1, -- Thorngrin the Tender
      [21559] = 1, -- Laj
      [21582] = 1, -- Warp Splinter
    },
    bossOrder = {21551, 21558, 21581, 21559, 21582}
  },

  -- Magisters' Terrace (Both, Level 70)
  {
    achId = "HMT",
    title = "Magisters' Terrace |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Magisters' Terrace (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Boss_Kael'thasSunstrider_01.png", -- 250117
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 585,
    requiredKills = {
      [25562] = 1, -- Selin Fireheart
      [25573] = 1, -- Vexallus
      [25560] = 1, -- Priestess Delrissa
      [24857] = 1, -- Kael'thas Sunstrider
    },
    bossOrder = {25562, 25573, 25560, 24857}
  },

  -- The Arcatraz (Both, Level 70)
  {
    achId = "HARCATRAZ",
    title = "The Arcatraz |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Arcatraz (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_harbinger_skyriss.png", -- 236414
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 552,
    requiredKills = {
      [21626] = 1, -- Zereketh the Unbound
      [21590] = 1, -- Dalliah the Doomsayer
      [21624] = 1, -- Wrath-Scryer Soccothrates
      [21599] = 1, -- Harbinger Skyriss
    },
    bossOrder = {21626, 21590, 21624, 21599}
  },
}

---------------------------------------
-- Deferred Registration Queue
---------------------------------------

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
if addon then
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local DungeonCommon = addon and addon.DungeonCommon
  if DungeonCommon and DungeonCommon.registerDungeonAchievement then
    for _, dungeon in ipairs(HeroicDungeons) do
      dungeon.isHeroicDungeon = true
      table_insert(queue, function()
        DungeonCommon.registerDungeonAchievement(dungeon)
      end)
    end
  end
end