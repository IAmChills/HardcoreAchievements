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
    staticPoints = false,
    requiredMapId = 543,
    requiredKills = {
      [17306] = 1, -- Watchkeeper Gargolmar
      [17308] = 1, -- Omor the Unscarred
      [17536] = 1, -- Nazan
      [17307] = 1, -- Vazruden
    },
    bossOrder = {17306, 17308, 17536, 17307}
  },

  -- Hellfire Ramparts (Both, Level 70)
  {
    achId = "HBLOODFURNACE",
    title = "Blood Furnace |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Blood Furnace (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kelidanthebreaker.png", -- 236417
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 542,
    requiredKills = {
      [17381] = 1, -- The Maker
      [17380] = 1, -- Broggok
      [17377] = 1, -- Keli'dan the Breaker
    },
    bossOrder = {17381, 17380, 17377}
  },

  -- The Slave Pens (Both, Level 70)
  {
    achId = "HSLAVEPENS",
    title = "The Slave Pens |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Slave Pens (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_quagmirran.png", -- 236433
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 547,
    requiredKills = {
      [17941] = 1, -- Mennu the Betrayer
      [17991] = 1, -- Rokmar the Crackler
      [17942] = 1, -- Quagmirran
    },
    bossOrder = {17941, 17991, 17942}
  },

  -- The Underbog (Both, Level 70)
  {
    achId = "HUNDERBOG",
    title = "The Underbog |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Underbog (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_theblackstalker.png", -- 254502
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 546,
    requiredKills = {
      [17770] = 1, -- Hungarfen
      [18105] = 1, -- Ghaz'an
      [17826] = 1, -- Swamplord Musel'ek
      [17882] = 1, -- The Black Stalker
    },
    bossOrder = {17770, 18105, 17826, 17882}
  },

  -- Mana-Tombs (Both, Level 70)
  {
    achId = "HMANATOMBS",
    title = "Mana-Tombs |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Mana-Tombs (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_nexus_prince_shaffar.png", -- 236426
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 557,
    requiredKills = {
      [18341] = 1, -- Pandemonius
      [18343] = 1, -- Tavarok
      [18344] = 1, -- Nexus-Prince Shaffar
    },
    bossOrder = {18341, 18343, 18344}
  },

  -- Auchenai Crypts (Both, Level 70)
  {
    achId = "HAC",
    title = "Auchenai Crypts |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Auchenai Crypts (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_exarch_maladaar.png", -- 236411
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 558,
    requiredKills = {
      [18371] = 1, -- Shirrak the Dead Watcher
      [18373] = 1, -- Exarch Maladaar
    },
    bossOrder = {18371, 18373}
  },

  -- Old Hillsbrad Foothills (Both, Level 70)
  {
    achId = "HOLDHILLSBRAD",
    title = "Old Hillsbrad Foothills |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Old Hillsbrad Foothills (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_epochhunter.png", -- 254647
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 560,
    requiredKills = {
      [17848] = 1, -- Lieutenant Drake
      [17862] = 1, -- Captain Skarloc
      [18096] = 1, -- Epoch Hunter
    },
    bossOrder = {17848, 17862, 18096}
  },

  -- Sethekk Halls (Both, Level 70)
  {
    achId = "HSETHEKK",
    title = "Sethekk Halls |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Sethekk Halls (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_talonkingikiss.png", -- 236435
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 556,
    requiredKills = {
      [18472] = 1, -- Darkweaver Syth
      [18473] = 1, -- Talon King Ikiss
      [23035] = 1, -- Anzu (heroic only)
    },
    bossOrder = {18472, 18473, 23035}
  },

  -- The Black Morass (Both, Level 70)
  {
    achId = "HBLACKMORASS",
    title = "The Black Morass |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Black Morass (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_aeonus_01.png", -- 254086
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 269,
    requiredKills = {
      [17879] = 1, -- Chrono Lord Deja
      [17880] = 1, -- Temporus
      [17881] = 1, -- Aeonus
    },
    bossOrder = {17879, 17880, 17881}
  },

  -- The Mechanar (Both, Level 70)
  {
    achId = "HMECHANAR",
    title = "The Mechanar |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Mechanar (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_pathaleonthecalculator.png", -- 236430
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 554,
    requiredKills = {
      [19219] = 1, -- Mechano-Lord Capacitus
      [19221] = 1, -- Nethermancer Sepethrea
      [19220] = 1, -- Pathaleon the Calculator
    },
    bossOrder = {19219, 19221, 19220}
  },

  -- The Shattered Halls (Both, Level 70)
  {
    achId = "HSHATTEREDHALLS",
    title = "The Shattered Halls |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Shattered Halls (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kargathbladefist_01.png", -- 254093
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 540,
    requiredKills = {
      [16807] = 1, -- Grand Warlock Nethekurse
      [20923] = 1, -- Blood Guard Porung (heroic only)
      [16809] = 1, -- Warbringer O'mrogg
      [16808] = 1, -- Warchief Kargath Bladefist
    },
    bossOrder = {16807, 20923, 16809, 16808}
  },

  -- Shadow Labyrinth (Both, Level 70)
  {
    achId = "HSLABS",
    title = "Shadow Labyrinth |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Shadow Labyrinth (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_murmur.png", -- 254501
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 555,
    requiredKills = {
      [18731] = 1, -- Ambassador Hellmaw
      [18667] = 1, -- Blackheart the Inciter
      [18732] = 1, -- Grandmaster Vorpil
      [18708] = 1, -- Murmur
    },
    bossOrder = {18731, 18667, 18732, 18708}
  },

  -- The Steamvault (Both, Level 70)
  {
    achId = "HSTEAMVAULT",
    title = "The Steamvault |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Steamvault (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_warlord_kalithresh.png", -- 236436
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 545,
    requiredKills = {
      [17797] = 1, -- Hydromancer Thespia
      [17796] = 1, -- Mekgineer Steamrigger
      [17798] = 1, -- Warlord Kalithresh
    },
    bossOrder = {17797, 17796, 17798}
  },

  -- The Botanica (Both, Level 70)
  {
    achId = "HBOTANICA",
    title = "The Botanica |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Botanica (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_warpsplinter.png", -- 236437
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 553,
    requiredKills = {
      [17976] = 1, -- Commander Sarannis
      [17975] = 1, -- High Botanist Freywinn
      [17978] = 1, -- Thorngrin the Tender
      [17980] = 1, -- Laj
      [17977] = 1, -- Warp Splinter
    },
    bossOrder = {17976, 17975, 17978, 17980, 17977}
  },

  -- Magisters' Terrace (Both, Level 70)
  {
    achId = "HMT",
    title = "Magisters' Terrace |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Magisters' Terrace (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Boss_Kael'thasSunstrider_01.png", -- 250117
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 585,
    requiredKills = {
      [24723] = 1, -- Selin Fireheart
      [24744] = 1, -- Vexallus
      [24560] = 1, -- Priestess Delrissa
      [24664] = 1, -- Kael'thas Sunstrider
    },
    bossOrder = {24723, 24744, 24560, 24664}
  },

  -- The Arcatraz (Both, Level 70)
  {
    achId = "HARCATRAZ",
    title = "The Arcatraz |cff820000(Heroic)|r",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Arcatraz (Heroic)|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_harbinger_skyriss.png", -- 236414
    level = 70,
    points = 10,
    staticPoints = false,
    requiredMapId = 552,
    requiredKills = {
      [20870] = 1, -- Zereketh the Unbound
      [20885] = 1, -- Dalliah the Doomsayer
      [20886] = 1, -- Wrath-Scryer Soccothrates
      [20912] = 1, -- Harbinger Skyriss
    },
    bossOrder = {20870, 20885, 20886, 20912}
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