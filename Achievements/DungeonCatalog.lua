-- Comprehensive dungeon achievement definitions
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_RAGEFIRE1.."|r with every party member at level 14 or lower upon entering the dungeon",
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_THEDEADMINES1.."|r with every party member at level 19 or lower upon entering the dungeon",
    icon = 236409,
    level = 19,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_WAILINGCAVERNS1.."|r with every party member at level 20 or lower upon entering the dungeon",
    icon = 236425,
    level = 20,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Shadowfang Keep|r with every party member at level 24 or lower upon entering the dungeon",
    icon = 254646,
    level = 24,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Blackfathom Deeps|r with every party member at level 26 or lower upon entering the dungeon",
    icon = 236403,
    level = 26,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_THESTOCKADE1.."|r with every party member at level 27 or lower upon entering the dungeon",
    icon = 236404,
    level = 27,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_RAZORFENKRAUL1.."|r with every party member at level 31 or lower upon entering the dungeon",
    icon = 236405,
    level = 31,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_DUNMOROGH10.."|r with every party member at level 32 or lower upon entering the dungeon",
    icon = 236424,
    level = 32,
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
  --   tooltip = "Defeat the enemies of " .. HCA_SharedUtils.GetClassColor() .. "Duskwood|r with every party member at level 35 or lower upon entering the dungeon",
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Scarlet Monastery|r with every party member at level 40 or lower upon entering the dungeon",
    icon = 133154,
    level = 40,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_RAZORFENDOWNS1.."|r with every party member at level 39 or lower upon entering the dungeon",
    icon = 236400,
    level = 39,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Uldaman|r with every party member at level 45 or lower upon entering the dungeon",
    icon = 236401, --254106 also looks good
    level = 45,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_ZULFARRAK.."|r with every party member at level 46 or lower upon entering the dungeon",
    icon = 236406,
    level = 46,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Maraudon|r with every party member at level 50 or lower upon entering the dungeon",
    icon = 236432,
    level = 50,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_THETEMPLEOFATALHAKKAR1.."|r with every party member at level 54 or lower upon entering the dungeon",
    icon = 236434,
    level = 54,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. ""..DUNGEON_FLOOR_BURNINGSTEPPES16.."|r with every party member at level 58 or lower upon entering the dungeon",
    icon = 236410,
    level = 58,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Lower Blackrock Spire|r with every party member at level 59 or lower upon entering the dungeon",
    icon = 236429,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Stratholme|r",
    icon = 237511,
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Dire Maul|r",
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
    tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "Scholomance|r",
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
  }
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
-- Create global registration queue if it doesn't exist
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all dungeon achievements for deferred registration
for _, dungeon in ipairs(Dungeons) do
  -- Queue base dungeon achievement
  table.insert(_G.HCA_RegistrationQueue, function()
    DungeonCommon.registerDungeonAchievement(dungeon)
  end)
  -- Queue variations (if checkboxes are enabled)
  if DungeonCommon.registerDungeonVariations then
    table.insert(_G.HCA_RegistrationQueue, function()
      DungeonCommon.registerDungeonVariations(dungeon)
    end)
  end
end