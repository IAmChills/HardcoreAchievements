-- Comprehensive dungeon achievement definitions
local Dungeons = {
  -- Ragefire Chasm (Horde, Level 13-18)
  {
    achId = "RFC",
    title = DUNGEON_FLOOR_RAGEFIRE1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_RAGEFIRE1.."|r before level 16 (including party members)",
    icon = 237582,
    level = 15,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_RAGEFIRE1,
    requiredMapId = 389,
    faction = FACTION_HORDE,
    requiredKills = {
      [11520] = 1, -- Taragaman the Hungerer
      [11517] = 1, -- Oggleflint
      [11518] = 1, -- Jergosh the Invoker
      [11519] = 1, -- Bazzalan
    }
  },

  -- The Deadmines (Alliance, Level 10-20)
  {
    achId = "DM",
    title = DUNGEON_FLOOR_THEDEADMINES1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_THEDEADMINES1.."|r before level 20 (including party members)",
    icon = 236404,
    level = 19,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_THEDEADMINES1,
    requiredMapId = UPDATEME,
    requiredKills = {
      [644] = 1,   -- Rhahk'Zor
      [643] = 1,   -- Sneed's Shredder
      [1763] = 1,  -- Gilnid
      [646] = 1,   -- Mr. Smite
      [647] = 1,   -- Captain Greenskin
      [639] = 1,   -- Edwin VanCleef
    }
  },

  -- Wailing Caverns (Both, Level 15-25)
  {
    achId = "WC",
    title = DUNGEON_FLOOR_WAILINGCAVERNS1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_WAILINGCAVERNS1.."|r before level 20 (including party members)",
    icon = 236717,
    level = 21,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_WAILINGCAVERNS1,
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
    }
  },

  -- Shadowfang Keep (Both, Level 18-25)
  {
    achId = "SFK",
    title = "Shadowfang Keep",
    tooltip = "Complete the bosses of |cff0091e6Shadowfang Keep|r before level 26 (including party members)",
    icon = 236830,
    level = 25,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Shadowfang Keep",
    requiredMapId = 33,
    requiredKills = {
      [3914] = 1,  -- Rethilgore
      [3886] = 1,  -- Razorclaw the Butcher
      [3887] = 1,  -- Baron Silverlaine
      [4278] = 1,  -- Commander Springvale
      [4279] = 1,  -- Odo the Blindwatcher
      [3872] = 1,  -- Deathsworn Captain
      [4274] = 1,  -- Fenrus the Devourer
      [3927] = 1,  -- Wolf Master Nandos
      [4275] = 1,  -- Archmage Arugal
    }
  },

  -- Blackfathom Deeps (Both, Level 20-30)
  {
    achId = "BFD",
    title = "Blackfathom Deeps",
    tooltip = "Complete the bosses of |cff0091e6Blackfathom Deeps|r before level 28 (including party members)",
    icon = 132852,
    level = 27,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Blackfathom Deeps",
    requiredMapId = 48,
    requiredKills = {
      [4887] = 1,  -- Ghamoo-ra
      [4831] = 1,  -- Lady Sarevess
      [6243] = 1,  -- Gelihast
      [12902] = 1, -- Lorgus Jett
      [12876] = 1, -- Baron Aquanis
      [4832] = 1,  -- Twilight Lord Kelris
      [4830] = 1,  -- Old Serra'kis
      [4829] = 1,  -- Aku'mai
    }
  },

  -- The Stockade (Alliance, Level 22-30)
  {
    achId = "STOCK",
    title = DUNGEON_FLOOR_THETHESTOCKADE1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_THETHESTOCKADE1.."|r before level 29 (including party members)",
    icon = 236448,
    level = 28,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_THETHESTOCKADE1,
    requiredMapId = 34,
    faction = FACTION_ALLIANCE,
    requiredKills = {
      [1696] = 1,  -- Targorr the Dread
      [1666] = 1,  -- Kam Deepfury
      [1717] = 1,  -- Hamhock
      [1663] = 1,  -- Dextren Ward
      [1716] = 1,  -- Bazil Thredd
    }
  },

  -- Gnomeregan (Alliance, Level 24-33)
  {
    achId = "GNOM",
    title = DUNGEON_FLOOR_DUNMOROGH10,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_DUNMOROGH10.."|r before level 34 (including party members)",
    icon = 134152,
    level = 33,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_DUNMOROGH10,
    requiredMapId = 90,
    requiredKills = {
      [7361] = 1,  -- Grubbis
      [7079] = 1,  -- Viscous Fallout
      [6235] = 1,  -- Electrocutioner 6000
      [6229] = 1,  -- Crowd Pummeler 9-60
      [6228] = 1,  -- Dark Iron Ambassador
      [7800] = 1,  -- Mekgineer Thermaplugg
    }
  },

  -- Razorfen Kraul (Both, Level 25-35)
  {
    achId = "RFK",
    title = DUNGEON_FLOOR_RAZORFENKRAUL1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_RAZORFENKRAUL1.."|r before level 33 (including party members)",
    icon = 236756,
    level = 32,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_RAZORFENKRAUL1,
    requiredMapId = 47,
    requiredKills = {
      [6168] = 1,  -- Roogug
      [4424] = 1,  -- Aggem Thorncurse
      [4428] = 1,  -- Death Speaker Jargba
      [4420] = 1,  -- Overlord Ramtusk
      [4422] = 1,  -- Agathelos the Raging
      [4421] = 1,  -- Charlga Razorflank
    }
  },

  -- Scarlet Monastery (Both, Level 28-38)
  {
    achId = "SM",
    title = "Scarlet Monastery",
    tooltip = "Complete the bosses of |cff0091e6Scarlet Monastery|r before level 41 (including party members)",
    icon = 5210047,
    level = 40,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Scarlet Monastery",
    requiredMapId = 1004,
    requiredKills = {
      [3983] = 1,  -- Interrogator Vishas
      [4543] = 1,  -- Bloodmage Thalnos
      [3974] = 1,  -- Houndmaster Loksey
      [6487] = 1,  -- Arcanist Doan
      [3975] = 1,  -- Herod
      [3976] = 1,  -- Scarlet Commander Mograine
      [3977] = 1,  -- High Inquisitor Whitemane
      [4542] = 1,  -- High Inquisitor Fairbanks
    }
  },

  -- Razorfen Downs (Both, Level 35-45)
  {
    achId = "RFD",
    title = DUNGEON_FLOOR_RAZORFENDOWNS1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_RAZORFENDOWNS1.."|r before level 41 (including party members)",
    icon = 236405,
    level = 40,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_RAZORFENDOWNS1,
    requiredMapId = 129,
    requiredKills = {
      [7355] = 1,  -- Tuten'kash
      [7356] = 1,  -- Plaguemaw the Rotting
      [7357] = 1,  -- Mordresh Fire Eye
      [7354] = 1,  -- Ragglesnout
      [8567] = 1,  -- Glutton
      [7358] = 1,  -- Amnennar the Coldbringer
    }
  },

  -- Uldaman (Both, Level 35-45)
  {
    achId = "ULD",
    title = "Uldaman",
    tooltip = "Complete the bosses of |cff0091e6Uldaman|r before level 46 (including party members)",
    icon = 236401, --254106 also looks good
    level = 45,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Uldaman",
    requiredMapId = 70,
    requiredKills = {
      [6910] = 1,  -- Revelosh
      [6906] = 1,  -- Baelog
      [7228] = 1,  -- Ironaya
      [7023] = 1,  -- Obsidian Sentinel
      [7206] = 1,  -- Ancient Stone Keeper
      [7291] = 1,  -- Galgann Firehammer
      [4854] = 1,  -- Grimlok
      [2748] = 1,  -- Archaedas
    }
  },

  -- Zul'Farrak (Both, Level 44-54)
  {
    achId = "ZF",
    title = DUNGEON_FLOOR_ZULFARRAK,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_ZULFARRAK.."|r before level 48 (including party members)",
    icon = 236865,
    level = 47,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_ZULFARRAK,
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
    }
  },

  -- Maraudon (Both, Level 40-50)
  {
    achId = "MARA",
    title = "Maraudon",
    tooltip = "Complete the bosses of |cff0091e6Maraudon|r before level 51 (including party members)",
    icon = 135153,
    level = 50,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Maraudon",
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
    }
  },

  -- The Temple of Atal'Hakkar (Both, Level 50-60)
  {
    achId = "ST",
    title = DUNGEON_FLOOR_THETEMPLEOFATALHAKKAR1,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_THETEMPLEOFATALHAKKAR1.."|r before level 55 (including party members)",
    icon = 134157,
    level = 54,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_THETEMPLEOFATALHAKKAR1,
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
    }
  },

  -- Blackrock Depths (Both, Level 52-60)
  {
    achId = "BRD",
    title = DUNGEON_FLOOR_BURNINGSTEPPES16,
    tooltip = "Complete the bosses of |cff0091e6"..DUNGEON_FLOOR_BURNINGSTEPPES16.."|r before level 59 (including party members)",
    icon = 135790,
    level = 58,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = DUNGEON_FLOOR_BURNINGSTEPPES16,
    requiredMapId = 230,
    requiredKills = {
      [9025] = 1,  -- Lord Roccor
      [9016] = 1,  -- Bael'Gar
      [9319] = 1,  -- Houndmaster Grebmar
      [9018] = 1,  -- High Interrogator Gerstahn
      [10096] = 1, -- High Justice Grimstone
      [9024] = 1,  -- Pyromancer Loregrain
      [9033] = 1,  -- General Angerforge
      [8983] = 1,  -- Golem Lord Argelmach
      [9017] = 1,  -- Lord Incendius
      [9056] = 1,  -- Fineous Darkvire
      [9041] = 1,  -- Warder Stilgiss
      [9042] = 1,  -- Verek
      [9156] = 1,  -- Ambassador Flamelash
      [9938] = 1,  -- Magmus
      [8929] = 1,  -- Princess Moira Bronzebeard
      [9019] = 1,  -- Emperor Dagran Thaurissan
    }
  },

  -- Blackrock Spire (Both, Level 55-60)
  {
    achId = "BRS",
    title = "Lower Blackrock Spire",
    tooltip = "Complete the bosses of |cff0091e6Lower Blackrock Spire|r before level 60 (including party members)",
    icon = 133886,
    level = 59,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Blackrock Spire",
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
      --[9816] = 1,  -- Pyroguard Emberseer
      --[10429] = 1, -- Warchief Rend Blackhand
      --[10339] = 1, -- Gyth
      --[10430] = 1, -- The Beast
      --[10363] = 1, -- General Drakkisath
    }
  },

  -- Stratholme (Both, Level 58-60)
  {
    achId = "STRAT",
    title = "Stratholme",
    tooltip = "Complete the bosses of |cff0091e6Stratholme|r",
    icon = 237534,
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Stratholme",
    requiredMapId = 329,
    requiredKills = {
      [11058] = 1, -- Ezra Grimm
      [10393] = 1, -- Skul
      [10558] = 1, -- Hearthsinger Forresten
      [10516] = 1, -- The Unforgiven
      [11143] = 1, -- Postmaster Malown
      [10808] = 1, -- Timmy the Cruel
      [11032] = 1, -- Malor the Zealous
      [10997] = 1, -- Cannon Master Willey
      [11120] = 1, -- Crimson Hammersmith
      [10811] = 1, -- Archivist Galford
      [10813] = 1, -- Balnazzar
      [10435] = 1, -- Magistrate Barthilas
      [10809] = 1, -- Stonespine
      [10437] = 1, -- Nerub'enkan
      [11121] = 1, -- Black Guard Swordsmith
      [10438] = 1, -- Maleki the Pallid
      [10436] = 1, -- Baroness Anastari
      [10439] = 1, -- Ramstein the Gorger
      [10440] = 1, -- Baron Rivendare
    }
  },

  -- Dire Maul (Both, Level 58-60)
  {
    achId = "DM",
    title = "Dire Maul",
    tooltip = "Complete the bosses of |cff0091e6Dire Maul|r",
    icon = 236764,
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Dire Maul",
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
      [11467] = 1, -- Tsu'zee
      [11488] = 1, -- Illyanna Ravenoak
      [11496] = 1, -- Immol'thar
      [11486] = 1, -- Prince Tortheldrin
    }
  },

  -- Scholomance (Both, Level 58-60)
  {
    achId = "SCHOLO",
    title = "Scholomance",
    tooltip = "Complete the bosses of |cff0091e6Scholomance|r",
    icon = 236208,
    level = 60,
    points = 10,
    requiredQuestId = nil,
    staticPoints = false,
    zone = "Scholomance",
    requiredMapId = 1007,
    requiredKills = {
      [10506] = 1, -- Kirtonos the Herald
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
    }
  }
}

-- Register all dungeon achievements
for _, dungeon in ipairs(Dungeons) do
  DungeonCommon.registerDungeonAchievement(dungeon)
end