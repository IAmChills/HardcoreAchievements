---------------------------------------
-- Dungeon Achievement Definitions
---------------------------------------
local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor())
local table_insert = table.insert

local Dungeons = {
  -- Test achievement
  -- {
  --   achId = "TestDungeon",
  --   title = "Test Dungeon",
  --   tooltip = "Test Dungeon",
  --   icon = 134400,
  --   level = 5,
  --   points = 0,
  --   requiredQuestId = nil,
  --   requiredKills = {
  --     [3098] = 1,
  --     [3124] = 1,
  --   },
  -- },

  -- Ragefire Chasm (Horde, Level 13-18)
  {
    achId = "RFC",
    title = DUNGEON_FLOOR_RAGEFIRE1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_RAGEFIRE1.."|r with every party member at level 14 or lower upon entering the dungeon",
    icon = 136216,
    level = 14,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 389,
    faction = FACTION_HORDE,
    requiredKills = {
      [11520] = 1, -- Taragaman the Hungerer
      [11517] = 1, -- Oggleflint
      [11518] = 1, -- Jergosh the Invoker
      [11519] = 1, -- Bazzalan
    },
    bossOrder = {11517, 11520, 11518, 11519}
  },

  -- The Deadmines (Alliance, Level 10-20)
  {
    achId = "VC",
    title = DUNGEON_FLOOR_THEDEADMINES1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_THEDEADMINES1.."|r with every party member at level 18 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_edwinvancleef.png", -- 236409
    level = 18,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 36,
    requiredKills = {
      [644] = 1,   -- Rhahk'Zor
      [643] = 1,   -- Sneed's Shredder
      [1763] = 1,  -- Gilnid
      [646] = 1,   -- Mr. Smite
      [647] = 1,   -- Captain Greenskin
      [639] = 1,   -- Edwin VanCleef
    },
    bossOrder = {644, 643, 1763, 646, 647, 639}
  },

  -- Wailing Caverns (Both, Level 15-25)
  {
    achId = "WC",
    title = DUNGEON_FLOOR_WAILINGCAVERNS1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_WAILINGCAVERNS1.."|r with every party member at level 18 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_mutanus_the_devourer.png", -- 236425
    level = 18,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 43,
    requiredKills = {
      [3653] = 1,  -- Kresh
      [3671] = 1,  -- Lady Anacondra
      [3669] = 1,  -- Lord Cobrahn
      [3670] = 1,  -- Lord Pythas
      [3674] = 1,  -- Skum
      [3673] = 1,  -- Lord Serpentis
      [5775] = 1,  -- Verdan the Everliving
      [3654] = 1,  -- Mutanus the Devourer
    },
    bossOrder = {3671, 3653, 3669, 3670, 3674, 3673, 5775, 3654}
  },

  -- Shadowfang Keep (Both, Level 18-25)
  {
    achId = "SFK",
    title = "Shadowfang Keep",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Shadowfang Keep|r with every party member at level 19 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_archmagearugal.png", -- 254646
    level = 19,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 33,
    requiredKills = {
      [3914] = 1,  -- Rethilgore
      [3886] = 1,  -- Razorclaw the Butcher
      [3887] = 1,  -- Baron Silverlaine
      [4278] = 1,  -- Commander Springvale
      [4279] = 1,  -- Odo the Blindwatcher
      --[3872] = 1,  -- Deathsworn Captain (rare)
      [4274] = 1,  -- Fenrus the Devourer
      [3927] = 1,  -- Wolf Master Nandos
      [4275] = 1,  -- Archmage Arugal
    },
    bossOrder = {3914, 3886, 3887, 4278, 4279, 4274, 3927, 4275}
  },

  -- Blackfathom Deeps (Both, Level 20-30)
  {
    achId = "BFD",
    title = "Blackfathom Deeps",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Blackfathom Deeps|r with every party member at level 22 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_bazil_akumai.png", -- 236403
    level = 22,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 48,
    requiredKills = {
      [4887] = 1,  -- Ghamoo-ra
      [4831] = 1,  -- Lady Sarevess
      [6243] = 1,  -- Gelihast
      [12902] = 1, -- Lorgus Jett
      --[12876] = 1, -- Baron Aquanis (Horde only quest)
      [4832] = 1,  -- Twilight Lord Kelris
      [4830] = 1,  -- Old Serra'kis
      [4829] = 1,  -- Aku'mai
    },
    bossOrder = {4887, 4831, 6243, 12902, 4832, 4830, 4829}
  },

  -- The Stockade (Alliance, Level 22-30)
  {
    achId = "STOCK",
    title = DUNGEON_FLOOR_THESTOCKADE1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_THESTOCKADE1.."|r with every party member at level 23 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_bazil_thredd.png", -- 236404
    level = 23,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 34,
    faction = FACTION_ALLIANCE,
    requiredKills = {
      [1696] = 1,  -- Targorr the Dread
      [1666] = 1,  -- Kam Deepfury
      [1717] = 1,  -- Hamhock
      [1663] = 1,  -- Dextren Ward
      [1716] = 1,  -- Bazil Thredd
    },
    bossOrder = {1696, 1666, 1717, 1663, 1716}
  },

  -- Razorfen Kraul (Both, Level 25-35)
  {
    achId = "RFK",
    title = DUNGEON_FLOOR_RAZORFENKRAUL1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_RAZORFENKRAUL1.."|r with every party member at level 25 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_charlgarazorflank.png", -- 236405
    level = 25,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 47,
    requiredKills = {
      [6168] = 1,  -- Roogug (No one does this boss, left side)
      [4424] = 1,  -- Aggem Thorncurse
      [4428] = 1,  -- Death Speaker Jargba
      [4420] = 1,  -- Overlord Ramtusk
      [4422] = 1,  -- Agathelos the Raging
      [4421] = 1,  -- Charlga Razorflank
    },
    bossOrder = {6168, 4424, 4428, 4420, 4422, 4421}
  },

  -- Gnomeregan (Alliance, Level 24-33)
  {
    achId = "GNOM",
    title = DUNGEON_FLOOR_DUNMOROGH10,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_DUNMOROGH10.."|r with every party member at level 26 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Boss_Mekgineer_Thermaplugg.png", -- 236424
    level = 26,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 90,
    requiredKills = {
      [7361] = 1,  -- Grubbis
      [7079] = 1,  -- Viscous Fallout
      [6235] = 1,  -- Electrocutioner 6000
      [6229] = 1,  -- Crowd Pummeler 9-60
      --[6228] = 1,  -- Dark Iron Ambassador
      [7800] = 1,  -- Mekgineer Thermaplugg
    },
    bossOrder = {7361, 7079, 6235, 6229, 7800}
  },

  --  -- Potential Duskwood Achievement (Alliance)
  --  {
  --   achId = "CurseOfDuskwood",
  --   title = "The Curse of Duskwood",
  --   tooltip = "Defeat the enemies of " .. ClassColor .. "Duskwood|r with every party member at level 35 or lower upon entering the dungeon",
  --   icon = 236757,
  --   level = 35,
  --   points = 10,
  --   requiredQuestId = nil,
  --   staticPoints = false,
  --   requiredMapId = nil,
  --   faction = FACTION_ALLIANCE,
  --   requiredKills = {
  --     [1200] = 1,  -- Morbent Fel
  --     [314] = 1,  -- Eliza
  --     [522] = 1,  -- Mor'Ladim
  --     [412] = 1,  -- Stitches
  --   },
  --   bossOrder = {1200, 314, 522, 412}
  -- },

  -- Scarlet Monastery (Both, Level 28-38)
  {
    achId = "SM",
    title = "Scarlet Monastery",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Scarlet Monastery|r with every party member at level 38 or lower upon entering the dungeon",
    icon = 133154,
    level = 38,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 189,
    requiredKills = {
      [3983] = 1,  -- Interrogator Vishas
      [4543] = 1,  -- Bloodmage Thalnos
      [3974] = 1,  -- Houndmaster Loksey
      [6487] = 1,  -- Arcanist Doan
      [3975] = 1,  -- Herod
      [3976] = 1,  -- Scarlet Commander Mograine
      [3977] = 1,  -- High Inquisitor Whitemane
      [4542] = 1,  -- High Inquisitor Fairbanks
    },
    bossOrder = {3983, 4543, 3974, 6487, 3975, 4542, 3976, 3977}
  },

  -- Razorfen Downs (Both, Level 35-45)
  {
    achId = "RFD",
    title = DUNGEON_FLOOR_RAZORFENDOWNS1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_RAZORFENDOWNS1.."|r with every party member at level 35 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_amnennar_the_coldbringer.png", -- 236400
    level = 35,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 129,
    requiredKills = {
      [7355] = 1,  -- Tuten'kash
      [7356] = 1,  -- Plaguemaw the Rotting
      [7357] = 1,  -- Mordresh Fire Eye
      --[7354] = 1,  -- Ragglesnout (rare)
      [8567] = 1,  -- Glutton
      [7358] = 1,  -- Amnennar the Coldbringer
    },
    bossOrder = {7355, 7356, 7357, 8567, 7358}
  },

  -- Uldaman (Both, Level 35-45)
  {
    achId = "ULD",
    title = "Uldaman",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Uldaman|r with every party member at level 38 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_archaedas.png", -- 236401
    level = 38,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 70,
    requiredKills = {
      [6910] = 1,  -- Revelosh
      --[6906] = 1,  -- Baelog (horde only)
      [7228] = 1,  -- Ironaya
      [7023] = 1,  -- Obsidian Sentinel
      [7206] = 1,  -- Ancient Stone Keeper
      [7291] = 1,  -- Galgann Firehammer
      [4854] = 1,  -- Grimlok
      [2748] = 1,  -- Archaedas
    },
    bossOrder = {6910, 7228, 7023, 7206, 7291, 4854, 2748}
  },

  -- Zul'Farrak (Both, Level 44-54)
  {
    achId = "ZF",
    title = DUNGEON_FLOOR_ZULFARRAK,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_ZULFARRAK.."|r with every party member at level 44 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_chiefukorzsandscalp.png", -- 236406
    level = 44,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 209,
    requiredKills = {
      [8127] = 1,  -- Antu'sul
      [7272] = 1,  -- Theka the Martyr
      [7271] = 1,  -- Witch Doctor Zum'rah
      [7796] = 1,  -- Nekrum Gutchewer
      [7275] = 1,  -- Shadowpriest Sezz'ziz
      [7604] = 1,  -- Sergeant Bly
      [7795] = 1,  -- Hydromancer Velratha
      [7267] = 1,  -- Chief Ukorz Sandscalp
      [7797] = 1,  -- Ruuzlu
    },
    bossOrder = {8127, 7272, 7271, 7796, 7275, 7604, 7795, 7267, 7797}
  },

  -- Maraudon (Both, Level 40-50)
  {
    achId = "MARA",
    title = "Maraudon",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Maraudon|r with every party member at level 46 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_princesstheradras.png", -- 236432
    level = 46,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 349,
    requiredKills = {
      [13282] = 1, -- Noxxion
      [12258] = 1, -- Razorlash
      [12236] = 1, -- Lord Vyletongue
      [12225] = 1, -- Celebras the Cursed
      [12203] = 1, -- Landslide
      [13601] = 1, -- Tinkerer Gizlock
      [13596] = 1, -- Rotgrip
      [12201] = 1, -- Princess Theradras
    },
    bossOrder = {13282, 12258, 12236, 12225, 12203, 13601, 13596, 12201}
  },

  -- The Temple of Atal'Hakkar (Both, Level 50-60)
  {
    achId = "ST",
    title = DUNGEON_FLOOR_THETEMPLEOFATALHAKKAR1,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_THETEMPLEOFATALHAKKAR1.."|r with every party member at level 48 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_shadeoferanikus.png", -- 236434
    level = 48,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 109,
    requiredKills = {
      [8580] = 1,  -- Atal'alarion
      [5721] = 1,  -- Dreamscythe
      [5720] = 1,  -- Weaver
      [5710] = 1,  -- Jammal'an the Prophet
      [5711] = 1,  -- Ogom the Wretched
      [5719] = 1,  -- Morphaz
      [5722] = 1,  -- Hazzas
      [8443] = 1,  -- Avatar of Hakkar
      [5709] = 1,  -- Shade of Eranikus
    },
    bossOrder = {8580, 5721, 5720, 5710, 5711, 5719, 5722, 8443, 5709}
  },

  -- Blackrock Depths (Both, Level 52-60)
  {
    achId = "BRD",
    title = DUNGEON_FLOOR_BURNINGSTEPPES16,
    tooltip = "Defeat the bosses of " .. ClassColor .. ""..DUNGEON_FLOOR_BURNINGSTEPPES16.."|r with every party member at level 54 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_emperordagranthaurissan.png", -- 236410
    level = 54,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 230,
    requiredKills = {
      [9025] = 1,  -- Lord Roccor
      [9016] = 1,  -- Bael'Gar
      [9319] = 1,  -- Houndmaster Grebmar
      [9018] = 1,  -- High Interrogator Gerstahn
      ["Ring Of Law"] = {9027, 9028, 9029, 9030, 9031, 9032},  -- Ring of Law (any one of the six)
      [9024] = 1,  -- Pyromancer Loregrain
      [9033] = 1,  -- General Angerforge (Might be broken)
      [8983] = 1,  -- Golem Lord Argelmach
      [9017] = 1,  -- Lord Incendius
      [9056] = 1,  -- Fineous Darkvire
      [9041] = 1,  -- Warder Stilgiss
      [9042] = 1,  -- Verek
      [9156] = 1,  -- Ambassador Flamelash
      [9938] = 1,  -- Magmus
      [8929] = 1,  -- Princess Moira Bronzebeard
      [9019] = 1,  -- Emperor Dagran Thaurissan
    },
    bossOrder = {9025, 9016, 9319, 9018, "Ring Of Law", 9024, 9033, 8983, 9017, 9056, 9041, 9042, 9156, 9938, 8929, 9019}
  },

  -- Blackrock Spire (Both, Level 55-60)
  {
    achId = "BRS",
    title = "Lower Blackrock Spire",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Lower Blackrock Spire|r with every party member at level 59 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_overlord_wyrmthalak.png", -- 236429
    level = 59,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 229,
    requiredKills = {
      [9196] = 1,  -- Highlord Omokk
      [9236] = 1,  -- Shadow Hunter Vosh'gajin
      [9237] = 1,  -- War Master Voone
      [10596] = 1, -- Mother Smolderweb
      [10584] = 1, -- Urok Doomhowl
      [9736] = 1,  -- Quartermaster Zigris
      [10268] = 1, -- Gizrul the Slavener
      [10220] = 1, -- Halycon
      [9568] = 1,  -- Overlord Wyrmthalak
    },
    bossOrder = {9196, 9236, 9237, 10596, 10584, 9736, 10268, 10220, 9568}
  },

  -- Stratholme (Both, Level 58-60)
  {
    achId = "STRAT",
    title = "Stratholme",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Stratholme|r with every party member at level 60 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Spell_deathknight_armyofthedead.png", -- 237511
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 329,
    requiredKills = {
      [11058] = 1, -- Ezra Grimm
      --[10393] = 1, -- Skul (rare)
      --[10558] = 1, -- Hearthsinger Forresten (rare)
      [10516] = 1, -- The Unforgiven
      --[11143] = 1, -- Postmaster Malown (summoned)
      [10808] = 1, -- Timmy the Cruel
      [11032] = 1, -- Malor the Zealous
      [10997] = 1, -- Cannon Master Willey
      [11120] = 1, -- Crimson Hammersmith
      [10811] = 1, -- Archivist Galford
      [10813] = 1, -- Balnazzar
      [10435] = 1, -- Magistrate Barthilas
      --[10809] = 1, -- Stonespine (rare)
      [10437] = 1, -- Nerub'enkan
      [11121] = 1, -- Black Guard Swordsmith
      [10438] = 1, -- Maleki the Pallid
      [10436] = 1, -- Baroness Anastari
      [10439] = 1, -- Ramstein the Gorger
      [10440] = 1, -- Baron Rivendare
    },
    bossOrder = {11058, 10516, 10808, 11032, 10997, 11120, 10811, 10813, 10435, 10437, 11121, 10438, 10436, 10439, 10440}
  },

  -- Dire Maul (Both, Level 58-60)
  {
    achId = "DM",
    title = "Dire Maul",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Dire Maul|r with every party member at level 60 or lower upon entering the dungeon",
    icon = 132340,
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 429,
    requiredKills = {
      [14354] = 1, -- Pusillin
      [14327] = 1, -- Lethtendris
      [13280] = 1, -- Hydrospawn
      [11490] = 1, -- Zevrim Thornhoof
      [11492] = 1, -- Alzzin the Wildshaper
      [14326] = 1, -- Guard Mol'dar
      [14322] = 1, -- Stomper Kreeg
      [14321] = 1, -- Guard Fengus
      [14323] = 1, -- Guard Slip'kik
      [14325] = 1, -- Captain Kromcrush
      [14324] = 1, -- Cho'Rush the Observer
      [11501] = 1, -- King Gordok
      [11489] = 1, -- Tendris Warpwood
      [11487] = 1, -- Magister Kalendris
      --[11467] = 1, -- Tsu'zee (rare)
      [11488] = 1, -- Illyanna Ravenoak
      [11496] = 1, -- Immol'thar
      [11486] = 1, -- Prince Tortheldrin
    },
    bossOrder = {14354, 14327, 13280, 11490, 11492, 14326, 14322, 14321, 14323, 14325, 14324, 11501, 11489, 11487, 11488, 11496, 11486}
  },

  -- Scholomance (Both, Level 58-60)
  {
    achId = "SCHOLO",
    title = "Scholomance",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Scholomance|r with every party member at level 60 or lower upon entering the dungeon",
    icon = 135974,
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 289,
    requiredKills = {
      --[10506] = 1, -- Kirtonos the Herald (summoned)
      [10503] = 1, -- Jandice Barov
      [11622] = 1, -- Rattlegore
      [10433] = 1, -- Marduk Blackpool
      [10432] = 1, -- Vectus
      [10508] = 1, -- Ras Frostwhisper
      [10505] = 1, -- Instructor Malicia
      [11261] = 1, -- Doctor Theolen Krastinov
      [10901] = 1, -- Lorekeeper Polkelt
      [10507] = 1, -- The Ravenian
      [10504] = 1, -- Lord Alexei Barov
      [10502] = 1, -- Lady Illucia Barov
      [1853] = 1,  -- Darkmaster Gandling
    },
    bossOrder = {10503, 11622, 10433, 10432, 10508, 10505, 11261, 10901, 10507, 10504, 10502, 1853}
  },

  -- Hellfire Ramparts (Both, Level 60-62)
  {
    achId = "RAMPARTS",
    title = "Hellfire Ramparts",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Hellfire Ramparts|r with every party member at level 60 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_omartheunscarred_01.png", -- 236427
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 543,
    requiredKills = {
      [17306] = 1, -- Watchkeeper Gargolmar
      [17308] = 1, -- Omor the Unscarred
      [17536] = 1, -- Nazan
      [17537] = 1, -- Vazruden
    },
    bossOrder = {17306, 17308, 17536, 17537}
  },

  -- Hellfire Ramparts (Both, Level 61-63)
  {
    achId = "BLOODFURNACE",
    title = "Blood Furnace",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Blood Furnace|r with every party member at level 61 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kelidanthebreaker.png", -- 236417
    level = 61,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 542,
    requiredKills = {
      [17381] = 1, -- The Maker
      [17380] = 1, -- Broggok
      [17377] = 1, -- Keli'dan the Breaker
    },
    bossOrder = {17381, 17380, 17377}
  },

  -- The Slave Pens (Both, Level 62-64)
  {
    achId = "SLAVEPENS",
    title = "The Slave Pens",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Slave Pens|r with every party member at level 62 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_quagmirran.png", -- 236433
    level = 62,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 547,
    requiredKills = {
      [17941] = 1, -- Mennu the Betrayer
      [17991] = 1, -- Rokmar the Crackler
      [17942] = 1, -- Quagmirran
    },
    bossOrder = {17941, 17991, 17942}
  },

  -- The Underbog (Both, Level 63-65)
  {
    achId = "UNDERBOG",
    title = "The Underbog",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Underbog|r with every party member at level 63 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_theblackstalker.png", -- 254502
    level = 63,
    points = 10,
    requiredQuestId = nil,
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

  -- Mana-Tombs (Both, Level 64-66)
  {
    achId = "MANATOMBS",
    title = "Mana-Tombs",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Mana-Tombs|r with every party member at level 64 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_nexus_prince_shaffar.png", -- 236426
    level = 64,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 557,
    requiredKills = {
      [18341] = 1, -- Pandemonius
      [18343] = 1, -- Tavarok
      [18344] = 1, -- Nexus-Prince Shaffar
    },
    bossOrder = {18341, 18343, 18344}
  },

  -- Auchenai Crypts (Both, Level 64-66)
  {
    achId = "AC",
    title = "Auchenai Crypts",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Auchenai Crypts|r with every party member at level 65 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_exarch_maladaar.png", -- 236411
    level = 65,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 558,
    requiredKills = {
      [18371] = 1, -- Shirrak the Dead Watcher
      [18373] = 1, -- Exarch Maladaar
    },
    bossOrder = {18371, 18373}
  },

  -- Old Hillsbrad Foothills (Both, Level 66-68)
  {
    achId = "OLDHILLSBRAD",
    title = "Old Hillsbrad Foothills",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Old Hillsbrad Foothills|r with every party member at level 66 or lower upon entering the dungeon",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_epochhunter.png", -- 254647
    level = 66,
    points = 10,
    requiredQuestId = nil,
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
    achId = "SETHEKK",
    title = "Sethekk Halls",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Sethekk Halls|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_talonkingikiss.png", -- 236435
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 556,
    requiredKills = {
      [18472] = 1, -- Darkweaver Syth
      [18473] = 1, -- Talon King Ikiss
    },
    bossOrder = {18472, 18473}
  },

  -- The Black Morass (Both, Level 70)
  {
    achId = "BLACKMORASS",
    title = "The Black Morass",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Black Morass|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_aeonus_01.png", -- 254086
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    achId = "MECHANAR",
    title = "The Mechanar",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Mechanar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_pathaleonthecalculator.png", -- 236430
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    achId = "SHATTEREDHALLS",
    title = "The Shattered Halls",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Shattered Halls|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kargathbladefist_01.png", -- 254093
    level = 70,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 540,
    requiredKills = {
      [16807] = 1, -- Grand Warlock Nethekurse
      [16809] = 1, -- Warbringer O'mrogg
      [16808] = 1, -- Warchief Kargath Bladefist
    },
    bossOrder = {16807, 16809, 16808}
  },

  -- Shadow Labyrinth (Both, Level 70)
  {
    achId = "SLABS",
    title = "Shadow Labyrinth",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Shadow Labyrinth|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_murmur.png", -- 254501
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    achId = "STEAMVAULT",
    title = "The Steamvault",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Steamvault|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_warlord_kalithresh.png", -- 236436
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    achId = "BOTANICA",
    title = "The Botanica",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Botanica|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_warpsplinter.png", -- 236437
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    achId = "MT",
    title = "Magisters' Terrace",
    tooltip = "Defeat the bosses of " .. ClassColor .. "Magisters' Terrace|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Boss_Kael'thasSunstrider_01.png", -- 250117
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    achId = "ARCATRAZ",
    title = "The Arcatraz",
    tooltip = "Defeat the bosses of " .. ClassColor .. "The Arcatraz|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_harbinger_skyriss.png", -- 236414
    level = 70,
    points = 10,
    requiredQuestId = nil,
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
    for _, dungeon in ipairs(Dungeons) do
      table_insert(queue, function()
        DungeonCommon.registerDungeonAchievement(dungeon)
      end)
      if DungeonCommon.registerDungeonVariations then
        table_insert(queue, function()
          DungeonCommon.registerDungeonVariations(dungeon)
        end)
      end
    end
  end
end