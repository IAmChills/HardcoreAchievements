local Achievements = {

--{ achId="Test",  title="Boar Test",  level=4, tooltip="Kill |cff0091e6a boar", icon=134400, points=10, requiredQuestId=nil, targetNpcId=3098, faction="Horde", zone="Durotar" },
--{ achId="Test2", title="Easy Quest Test", level=2, tooltip="Orc starter quest", icon=134400, points=10, requiredQuestId=4641, targetNpcId=nil, faction="Horde", zone="Durotar" },
--{ achId="Test3", title="Kill + Quest", level=2, tooltip="Kill a boar and complete the orc starter quest", icon=134400, points=10, requiredQuestId=4641, targetNpcId=3098, faction="Horde", zone="Durotar" },
--{ achId="Test4", title="Kill 3 Boars", level=2, tooltip="Kill 3 boars", icon=134400, points=10, requiredQuestId=nil, requiredKills = { [3098] = 3, }, faction="Horde", zone="Durotar" },

-- Alliance
{
    achId = "Rageclaw",
    title = "Claw of the Wilds",
    level = 9,
    tooltip = "Complete |cff0091e6Druid of the Claw|r before level 10",
    icon = 134297,
    points = 10,
    requiredQuestId = 2561,
    targetNpcId = 7318,
    faction = FACTION_ALLIANCE,
    zone = "Teldrassil"
}, {
    achId = "Vagash",
    title = "The Alpha's End",
    level = 10,
    tooltip = "Complete |cff0091e6Protecting the Herd|r before level 11",
    icon = 132189,
    points = 10,
    requiredQuestId = 314,
    targetNpcId = 1388,
    faction = FACTION_ALLIANCE,
    zone = "Dun Morogh"
}, {
    achId = "Hogger",
    title = "Hogger? Never Heard of Her",
    level = 11,
    tooltip = "Complete |cff0091e6Wanted: 'Hogger'|r before level 12",
    icon = 134163,
    points = 10,
    requiredQuestId = 176,
    targetNpcId = 448,
    faction = FACTION_ALLIANCE,
    zone = "Elwynn Forest"
}, {
    achId = "Grawmug",
    title = "Defender of Dun Algaz",
    level = 16,
    tooltip = "Complete |cff0091e6In Defense of the King's Land Pt. 4|r before level 17",
    icon = 236421,
    points = 10,
    requiredQuestId = 217,
    targetNpcId = 1205,
    faction = FACTION_ALLIANCE,
    zone = "Loch Modan"
}, {
    achId = "AbsentMindedProspector",
    title = "Absent-Minded Savior",
    level = 19,
    tooltip = "Complete |cff0091e6Absent Minded Prospector Pt. 1|r before level 20",
    icon = 236444,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 731,
    targetNpcId = nil,
    faction = FACTION_ALLIANCE,
    zone = "Darkshore"
}, {
    achId = "Fangore",
    title = "Lieutenant’s Downfall",
    level = 23,
    tooltip = "Complete |cff0091e6Wanted: Lieutenant Fangore|r before level 24",
    icon = 134296,
    points = 10,
    requiredQuestId = 180,
    targetNpcId = 703,
    faction = FACTION_ALLIANCE,
    zone = "Redridge Mountains"
}, {
    achId = "Foulborne",
    title = "Summoner’s Bane",
    level = 23,
    tooltip = "Complete |cff0091e6Mage Summoner|r before level 24",
    icon = 134173,
    points = 10,
    requiredQuestId = 1017,
    targetNpcId = 3986,
    faction = FACTION_ALLIANCE,
    zone = "Ashenvale"
}, {
    achId = "Nekrosh",
    title = "Nek’rosh No More",
    level = 31,
    tooltip = "Complete |cff0091e6Defeat Nek'rosh|r before level 32",
    icon = 134170,
    points = 10,
    requiredQuestId = 474,
    targetNpcId = 2091,
    faction = FACTION_ALLIANCE,
    zone = "Wetlands"
}, {
    achId = "Morbent",
    title = "Morbent Has Fallen",
    level = 32,
    tooltip = "Complete |cff0091e6Morbent Fel|r before level 33",
    icon = 236225,
    points = 10,
    requiredQuestId = 55,
    targetNpcId = 1200,
    faction = FACTION_ALLIANCE,
    zone = "Duskwood"
}, {
    achId = "Eliza",
    title = "The Alchemist's Wife",
    level = 32,
    tooltip = "Complete |cff0091e6Bride of the Embalmer|r before level 33",
    icon = 236399,
    points = 10,
    requiredQuestId = 253,
    targetNpcId = 314,
    faction = FACTION_ALLIANCE,
    zone = "Duskwood"
}, {
    achId = "MorLadim",
    title = "Mor’Ladim’s Rest",
    level = 33,
    tooltip = "Complete |cff0091e6Mor'Ladim|r before level 34",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Dungeon_TheNecroticWake_StitchFlesh.png", -- ??
    points = 10,
    requiredQuestId = 228,
    targetNpcId = 522,
    faction = FACTION_ALLIANCE,
    zone = "Duskwood"
}, {
    achId = "ForsakenCourier",
    title = "Courier of Death",
    level = 34,
    tooltip = "Complete |cff0091e6Hints of a New Plague|r before level 35",
    icon = 133470,
    points = 10,
    requiredQuestId = 658,
    targetNpcId = 2714,
    faction = FACTION_ALLIANCE,
    zone = "Arathi Highlands"
}, {
    achId = "StinkysEscapeA",
    title = "Stinky Situation",
    level = 34,
    tooltip = "Complete |cff0091e6Stinky’s Escape|r before level 35",
    icon = 236758,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1222,
    targetNpcId = nil,
    faction = FACTION_ALLIANCE,
    zone = "Dustwallow Marsh"
}, {
    achId = "ThogrunAlliance",
    title = "Tremors Beneath",
    level = 40,
    tooltip = "Complete |cff0091e6Tremors of the Earth Pt. 1|r before level 41",
    icon = 254093,
    points = 10,
    requiredQuestId = 732,
    targetNpcId = 2944,
    faction = FACTION_ALLIANCE,
    zone = "Badlands"
}, {
    achId = "Kurzen",
    title = "Kurzen's Fall",
    level = 41,
    tooltip = "Complete |cff0091e6Colonel Kurzen|r before level 42",
    icon = 236844,
    points = 10,
    requiredQuestId = 202,
    targetNpcId = 813,
    faction = FACTION_ALLIANCE,
    zone = "Stanglethorn Vale"
}, {
    achId = "LordShalzaru",
    title = "Lord of the Depths",
    level = 43,
    tooltip = "Complete |cff0091e6Against Lord Shalzaru|r before level 44",
    icon = 136098,
    points = 10,
    requiredQuestId = 2870,
    targetNpcId = 8136,
    faction = FACTION_ALLIANCE,
    zone = "Feralas"
}, {
    achId = "DragonkinMenace",
    title = "Wrath of the Dragonkin",
    level = 57,
    tooltip = "Complete |cff0091e6Dragonkin Menace|r before level 58",
    icon = 236734,
    points = 10,
    requiredQuestId = 4182,
    requiredKills = {
        [7047] = 15,  -- Black Broodling x15
        [7040] = 10,  -- Black Dragonspawn x10
        [7044] = 1,   -- Black Drake x1
        [7041] = 4,   -- Black Wyrmkin x4
    },
    faction = FACTION_ALLIANCE,
    zone = "Burning Steppes"
},

-- Horde (new)
{
    achId = "Dargol",
    title = "Crypt Commander",
    level = 11,
    tooltip = "Complete |cff0091e6The Family Crypt|r before level 12",
    icon = 236458,
    points = 10,
    requiredQuestId = 408,
    targetNpcId = 1658,
    faction = FACTION_HORDE,
    zone = "Tirisfal Glades"
}, {
    achId = "Arrachea",
    title = "Spirit of the Earthmother",
    level = 11,
    tooltip = "Complete |cff0091e6Rites of the Earthmother|r before level 12",
    icon = 132243,
    points = 10,
    requiredQuestId = 776,
    targetNpcId = 3058,
    faction = FACTION_HORDE,
    zone = "Thunder Bluff"
}, {
    achId = "Gazzuz",
    title = "Slayer of Gazz’uz",
    level = 12,
    tooltip = "Complete |cff0091e6Burning Shadows|r before level 13",
    icon = 134085,
    points = 10,
    requiredQuestId = 832,
    targetNpcId = 3204,
    allowKillsBeforeQuest = true,
    faction = FACTION_HORDE,
    zone = "Orgrimmar"
}, {
    achId = "Fizzle",
    title = "Fo' Rizzle My Fizzle!",
    level = 12,
    tooltip = "Complete |cff0091e6Dark Storms|r before level 13",
    icon = 236290,
    points = 10,
    requiredQuestId = 806,
    targetNpcId = 3203,
    faction = FACTION_HORDE,
    zone = "Durotar"
}, {
    achId = "Goggeroc",
    title = "Stone and Soil",
    level = 20,
    tooltip = "Complete |cff0091e6Earthen Arise|r before level 21",
    icon = 236831,
    points = 10,
    requiredQuestId = 6481,
    targetNpcId = 11920,
    faction = FACTION_HORDE,
    zone = "Stonetalon Mountains"
}, {
    achId = "Kromzar",
    title = "Counterattack!",
    level = 20,
    tooltip = "Complete |cff0091e6Counterattack!|r before level 21",
    icon = 132484,
    points = 10,
    requiredQuestId = 4021,
    targetNpcId = 9456,
    faction = FACTION_HORDE,
    zone = "The Barrens"
}, {
    achId = "Ataeric",
    title = "Thread of the Weaver",
    level = 20,
    tooltip = "Complete |cff0091e6The Weaver|r before level 21",
    icon = 135144,
    points = 10,
    requiredQuestId = 480,
    targetNpcId = 2120,
    faction = FACTION_HORDE,
    zone = "Silverpine Forest"
}, {
    achId = "TheHunt",
    title = "The Great Hunt",
    level = 26,
    tooltip = "Complete |cff0091e6The Hunt Completed|r by slaying |cff0091e6Sharptalon|r, |cff0091e6Shadumbra|r, and |cff0091e6Ursangous|r before level 27",
    icon = 236713,
    points = 10,
    requiredQuestId = 247,
    targetNpcId = {12676, 12677, 12678},
    faction = FACTION_HORDE,
    zone = "Ashenvale"
}, {
    achId = "Gizmo",
    title = "Flux-Hypercapacitor",
    level = 28,
    tooltip = "Complete |cff0091e6Hypercapacitor Gizmo|r before level 29",
    icon = 133236,
    points = 10,
    requiredQuestId = 5151,
    targetNpcId = 10992,
    faction = FACTION_HORDE,
    zone = "Thousand Needles"
}, {
    achId = "Grenka",
    title = "What's in the Box!?",
    level = 30,
    tooltip = "Complete |cff0091e6Test of Endurance|r before level 31",
    icon = 236848,
    points = 10,
    requiredQuestId = 1150,
    targetNpcId = 4490,
    faction = FACTION_HORDE,
    zone = "Thousand Needles"
}, {
    achId = "Ironhill",
    title = "Hillsbrad Commander",
    level = 33,
    tooltip = "Complete |cff0091e6Battle of Hillsbrad|r before level 34",
    icon = 236779,
    points = 10,
    requiredQuestId = 541,
    targetNpcId = 2304,
    faction = FACTION_HORDE,
    zone = "Hillsbrad Foothills"
}, {
    achId = "StinkysEscapeH",
    title = "Stinky Situation",
    level = 34,
    tooltip = "Complete |cff0091e6Stinky’s Escape|r before level 35",
    icon = 236758,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1270,
    targetNpcId = nil,
    faction = FACTION_HORDE,
    zone = "Dustwallow Marsh"
}, {
    achId = "ThogrunHorde",
    title = "Sign of the Earth",
    level = 40,
    tooltip = "Complete |cff0091e6Broken Alliances Pt. 1|r before level 41",
    icon = 254093,
    points = 10,
    requiredQuestId = 782,
    targetNpcId = 2944,
    faction = FACTION_HORDE,
    zone = "Badlands"
}, {
    achId = "NothingButTruth",
    title = "Truth Seeker",
    level = 40,
    tooltip = "Complete |cff0091e6Nothing but the Truth Pt. 4|r before level 41",
    icon = 132800,
    points = 10,
    requiredQuestId = 1383,
    targetNpcId = nil,
    faction = FACTION_HORDE,
    zone = "Duskwood"
}, {
    achId = "Mugthol",
    title = "Crowned",
    level = 43,
    tooltip = "Complete |cff0091e6The Crown of Will Pt. 4|r before level 44",
    icon = 132768,
    points = 10,
    requiredQuestId = 520,
    targetNpcId = 2257,
    faction = FACTION_HORDE,
    zone = "Hillsbrad Foothills"
}, {
    achId = "Hatetalon",
    title = "Dark Heart of the Wild",
    level = 48,
    tooltip = "Complete |cff0091e6Dark Heart|r before level 49",
    icon = 134131,
    points = 10,
    requiredQuestId = 3062,
    targetNpcId = 8075,
    faction = FACTION_HORDE,
    zone = "Feralas"
}, {
    achId = "Kromgrul",
    title = "Crushing the Grul",
    level = 51,
    tooltip = "Complete |cff0091e6Krom'Grul|r before level 52",
    icon = 236695,
    points = 10,
    requiredQuestId = 3822,
    targetNpcId = 8977,
    faction = FACTION_HORDE,
    zone = "Burning Steppes"
},

-- Neutral (no faction)
{
    achId = "Level10",
    title = "This Isn't Too Bad...",
    level = 10,
    tooltip = "Reach level 10 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_10.png",
    points = 10,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 10 end,
    staticPoints = true,
}, {
    achId = "Level20",
    title = "Roaring Twenties",
    level = 20,
    tooltip = "Reach level 20 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_20.png",
    points = 20,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 20 end,
    staticPoints = true,
}, {
    achId = "Level30",
    title = "Thirty and Flirty",
    level = 30,
    tooltip = "Reach level 30 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_30.png",
    points = 30,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 30 end,
    staticPoints = true,
}, {
    achId = "Level40",
    title = "Over the Hill",
    level = 40,
    tooltip = "Reach level 40 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_40.png",
    points = 40,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 40 end,
    staticPoints = true,
}, {
    achId = "Level50",
    title = "Lock In",
    level = 50,
    tooltip = "Reach level 50 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_50.png",
    points = 50,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 50 end,
    staticPoints = true,
}, {
    achId = "Level60",
    title = "Locked In and Dialed",
    level = 60,
    tooltip = "Reach level 60 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_60.png",
    points = 60,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 60 end,
    staticPoints = true,
}, {
    achId = "GalensEscape",
    title = "Galen's Freedom",
    level = 38,
    tooltip = "Complete |cff0091e6Galen's Escape|r before level 39",
    icon = 236845,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1393,
    targetNpcId = nil,
    zone = "Swamp of Sorrows"
}, {
    achId = "GetMeOutOfHere",
    title = "Outta Here!",
    level = 41,
    tooltip = "Complete |cff0091e6Get Me Out of Here!|r before level 42",
    icon = 236742,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 6132,
    targetNpcId = nil,
    zone = "Desolace"
}, {
    achId = "KingBangalash",
    title = "King of the Jungle",
    level = 42,
    tooltip = "Complete |cff0091e6Big Game Hunter|r before level 43",
    icon = 134176,
    points = 10,
    requiredQuestId = 208,
    targetNpcId = 731,
    zone = "Stranglethorn Vale"
}, {
    achId = "OOX",
    title = "Oox I Did It Again",
    level = 45,
    tooltip = "Complete |cff0091e6An OOX of Your Own|r before level 46",
    icon = 133883,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 3721,
    targetNpcId = nil,
    zone = "Stranglethorn Vale"
}, {
    achId = "CuergosGold",
    title = "Cuergo’s Fortune",
    level = 45,
    tooltip = "Complete |cff0091e6Cuergo’s Gold|r before level 46",
    icon = 237387,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 2882,
    targetNpcId = nil,
    zone = "Tanaris"
}, {
    achId = "Mokk",
    title = "This Isn't Worth It",
    level = 47,
    tooltip = "Complete |cff0091e6Stranglethorn Fever|r before level 48",
    icon = 134338,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 348,
    targetNpcId = 1514,
    zone = "Stranglethorn Vale"
}, {
    achId = "MalletZF",
    title = string.format("%s the Keeper", GetUnitName("player")),
    level = 49,
    tooltip = "Obtain the |cff0091e6Mallet of Zul'Farrak|r before level 50",
    icon = 134559,
    points = 10,
    allowSoloDouble = true,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(9240, true) > 0 end,
    zone = "Hinterlands"
}, {
    achId = "Mukla",
    title = "Kong of the Jungle",
    level = 50,
    tooltip = "Complete |cff0091e6Message in a Bottle|r before level 51",
    icon = 132159,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 630,
    targetNpcId = 1559,
    zone = "Stranglethorn Vale"
}, {
    achId = "KimJaelIndeed",
    title = "Booty Bay Genius",
    level = 51,
    tooltip = "Complete |cff0091e6Kim’Jael Indeed!|r before level 52",
    icon = 236714,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 3601,
    targetNpcId = nil,
    zone = "Azshara"
}, {
    achId = "StonesThatBindUs",
    title = "Stonebound Savior",
    level = 51,
    tooltip = "Complete |cff0091e6The Stones That Bind Us|r before level 52",
    icon = 236720,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 2681,
    targetNpcId = nil,
    zone = "Blasted Lands"
}, {
    achId = "Hakkar",
    title = "Spirits, Tablets, and Eggs, Oh My!",
    level = 53,
    tooltip = "Complete |cff0091e6The God Hakkar|r before level 54",
    icon = 132209,
    points = 10,
    requiredQuestId = 3528,
    targetNpcId = nil,
    zone = "Tanaris"
}, {
    achId = "ShadowLordFeldan",
    title = "Shadow’s End",
    level = 55,
    tooltip = "Complete |cff0091e6A Final Blow|r before level 56",
    icon = 236763,
    points = 10,
    requiredQuestId = 5242,
    targetNpcId = 9517,
    zone = "Felwood"
}, {
    achId = "SummoningThePrincess",
    title = "Shards of Myzrael",
    level = 55,
    tooltip = "Complete |cff0091e6Summoning the Princess|r before level 56",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_Enchanting_Shard.png", -- ??
    points = 10,
    requiredQuestId = 656,
    targetNpcId = 2755,
    zone = "Badlands"
}, {
    achId = "GorishiHiveQueen",
    title = "Queen’s Gambit",
    level = 56,
    tooltip = "Complete |cff0091e6Pawn Captures Queen|r before level 57",
    icon = 134340,
    points = 10,
    requiredQuestId = 4507,
    targetNpcId = 10041,
    zone = "Un'Goro Crater"
}, {
    achId = "OverseerMaltorius",
    title = "Master of the Forge",
    level = 56,
    tooltip = "Complete |cff0091e6WANTED: Overseer Maltorius|r before level 57",
    icon = 134159,
    points = 10,
    requiredQuestId = 7701,
    targetNpcId = 14621,
    zone = "Searing Gorge"
}, {
    achId = "MercutioFilthgorger",
    title = "Mercutio’s Memory",
    level = 57,
    tooltip = "Complete |cff0091e6Of Forgotten Memories|r before level 58",
    icon = 133038,
    points = 10,
    requiredQuestId = 5781,
    targetNpcId = 11886,
    zone = "Eastern Plaguelands"
}, {
    achId = "HighChiefWinterfall",
    title = "Winter is Coming",
    level = 59,
    tooltip = "Complete |cff0091e6High Chief Winterfall|r before level 60",
    icon = 236696,
    points = 10,
    requiredQuestId = 5121,
    targetNpcId = 10738,
    zone = "Winterspring"
}, {
    achId = "Deathclasp",
    title = "Deathclasp Down",
    level = 59,
    tooltip = "Complete |cff0091e6Wanted: Deathclasp, Terror of the Sands|r before level 60",
    icon = 133708,
    points = 10,
    requiredQuestId = 8283,
    targetNpcId = 15196,
    zone = "Silithus"
},

-- Rogue
{
    achId = "Gallywix",
    title = "Get Gallywix or Die Tryin |cfffff468[Rogue]|r",
    level = 23,
    tooltip = "Complete |cff0091e6Mission: Possible But Not Probable|r before level 24",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Ability_Rogue_StayofExecution.PNG.png", -- 236281
    points = 10,
    requiredQuestId = 2478,
    targetNpcId = 7288,
    faction = FACTION_HORDE,
    class = "ROGUE",
    zone = "Barrens"
}, {
    achId = "DefiasMask",
    title = "One of Us! |cfffff468[Rogue]|r",
    level = nil,
    tooltip = "Equip a |cff0091e6Red Defias Mask|r and join the ranks of the Defias Brotherhood",
    icon = 133694,
    points = 0,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(7997, true) > 0 end,
    class = "ROGUE",
    staticPoints = true,
},

-- Mage
{
    achId = "AlchemistShopH",
    title = "Back to Brill! |cff3FC7EB[Mage]|r",
    level = 18,
    tooltip = "Complete |cff0091e6Investigate the Alchemist Shop|r before level 19",
    icon = 135734,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1960,
    targetNpcId = nil,
    faction = FACTION_HORDE,
    class = "MAGE",
    zone = "Undercity"
}, {
    achId = "AlchemistShopA",
    title = "Back to Elwynn! |cff3FC7EB[Mage]|r",
    level = 18,
    tooltip = "Complete |cff0091e6Investigate the Blue Recluse|r before level 19",
    icon = 135734,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1920,
    targetNpcId = nil,
    faction = FACTION_ALLIANCE,
    class = "MAGE",
    zone = "Stormwind City"
}, 

-- Warrior
{
    achId = "Whirlwind",
    title = "Cyclonian's Collapse |cffc69b6d[Warrior]|r",
    level = 38,
    tooltip = "Complete |cff0091e6The Summoning|r before level 39",
    icon = 134131,
    points = 10,
    requiredQuestId = 1713,
    targetNpcId = 6239,
    class = "WARRIOR",
    zone = "Alterac Mountains"
},
}

local function IsEligible(def)
  -- Faction: "Alliance" / "Horde"
  if def.faction and select(2, UnitFactionGroup("player")) ~= def.faction then
    return false
  end

  -- Race: allow either raceFile or localized race name in the def
  if def.race then
    local raceName, raceFile = UnitRace("player")
    if def.race ~= raceFile and def.race ~= raceName then
      return false
    end
  end

  -- Class: use class file tokens ("MAGE","WARRIOR",...)
  if def.class then
    local _, classFile = UnitClass("player")
    if classFile ~= def.class then
      return false
    end
  end

  return true
end

for _, def in ipairs(Achievements) do
  if IsEligible(def) then
    if def.customKill then
      _G[def.achId .. "_Kill"] = def.customKill
      _G[def.achId .. "_IsCompleted"] = _G[def.achId .. "_IsCompleted"] or function() return false end
    elseif def.customIsCompleted then
      _G[def.achId .. "_IsCompleted"] = def.customIsCompleted
    else
      _G.Achievements_Common.registerQuestAchievement{
        achId           = def.achId,
        requiredQuestId = def.requiredQuestId,
        targetNpcId     = def.targetNpcId,
        requiredKills   = def.requiredKills,
        maxLevel        = def.level,
        faction         = def.faction,
        race            = def.race,
        class           = def.class,
        allowKillsBeforeQuest = def.allowKillsBeforeQuest,
      }
    end
  end
end

-- Export achievements to global scope for AdminPanel access
_G.Achievements = Achievements

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
-- Create global registration queue if it doesn't exist
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all achievements for deferred registration
for _, def in ipairs(Achievements) do
  if IsEligible(def) then
    -- Mark as quest achievement for filtering
    def.isQuest = true
    table.insert(_G.HCA_RegistrationQueue, function()
      local killFn  = def.customKill or ((def.targetNpcId or def.requiredKills) and _G.HardcoreAchievements_GetAchievementFunction(def.achId, "Kill")) or nil
      local questFn = (def.requiredQuestId and _G.HardcoreAchievements_GetAchievementFunction(def.achId, "Quest")) or nil

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
    end)
  end
end
