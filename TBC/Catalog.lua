local Achievements = {

--{ achId="Test",  title="Boar Test",  level=4, tooltip="Kill |cff008765a boar", icon=134400, points=10, requiredQuestId=nil, targetNpcId=3098, faction="Horde", zone="Durotar" },
--{ achId="Test2", title="Easy Quest Test", level=2, tooltip="Orc starter quest", icon=134400, points=10, requiredQuestId=4641, targetNpcId=nil, faction="Horde", zone="Durotar" },
--{ achId="Test3", title="Kill + Quest", level=2, tooltip="Kill a boar and complete the orc starter quest", icon=134400, points=10, requiredQuestId=4641, targetNpcId=3098, faction="Horde", zone="Durotar" },
--{ achId="Test4", title="Kill 3 Boars", level=2, tooltip="Kill 3 boars", icon=134400, points=10, requiredQuestId=nil, requiredKills = { [3098] = 3, }, faction="Horde", zone="Durotar" },

-- Alliance
{
    achId = "Rageclaw",
    title = "Claw of the Wilds",
    level = 7,
    tooltip = "Complete |cff008765Druid of the Claw|r before level 8",
    icon = 134297,
    points = 10,
    requiredQuestId = 2561, -- Quest available at level 3
    targetNpcId = 7318, -- Rageclaw level 10
    faction = FACTION_ALLIANCE,
    zone = "Teldrassil"
}, {
    achId = "Vagash",
    title = "The Alpha's End",
    level = 8,
    tooltip = "Complete |cff008765Protecting the Herd|r before level 9",
    icon = 132189,
    points = 10,
    requiredQuestId = 314, -- Quest available at level 6
    targetNpcId = 1388, -- Vagash level 11
    faction = FACTION_ALLIANCE,
    zone = "Dun Morogh"
}, {
    achId = "Hogger",
    title = "Hogger? Never Heard of Her",
    level = 9,
    tooltip = "Complete |cff008765Wanted: 'Hogger'|r before level 10",
    icon = 134163,
    points = 10,
    requiredQuestId = 176, -- Quest available at level 5
    targetNpcId = 448, -- Hogger level 11 Elite
    faction = FACTION_ALLIANCE,
    zone = "Elwynn Forest"
}, {
    achId = "Grawmug",
    title = "Defender of Dun Algaz",
    level = 14,
    tooltip = "Complete |cff008765In Defense of the King's Land Pt. 4|r before level 15",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_boss_kingymiron_03.png", -- 236421
    points = 10,
    requiredQuestId = 217, -- Quest available at level 10
    targetNpcId = 1205, -- Grawmug level 17
    faction = FACTION_ALLIANCE,
    zone = "Loch Modan"
}, {
    achId = "AbsentMindedProspector",
    title = "Absent-Minded Savior",
    level = 17,
    tooltip = "Complete |cff008765Absent Minded Prospector Pt. 1|r before level 18",
    icon = 236444,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 731, -- Quest available at level 15
    targetNpcId = nil,
    faction = FACTION_ALLIANCE,
    zone = "Darkshore"
}, {
    achId = "Fangore",
    title = "Lieutenant’s Downfall",
    level = 24,
    tooltip = "Complete |cff008765Wanted: Lieutenant Fangore|r before level 25",
    icon = 134296,
    points = 10,
    requiredQuestId = 180, -- Quest available at level 11
    targetNpcId = 703, -- Fangore level 26
    faction = FACTION_ALLIANCE,
    zone = "Redridge Mountains"
}, {
    achId = "Foulborne",
    title = "Summoner’s Bane",
    level = 23,
    tooltip = "Complete |cff008765Mage Summoner|r before level 24",
    icon = 134173,
    points = 10,
    requiredQuestId = 1017, -- Quest available at level 20
    targetNpcId = 3986, -- Foulborne level 25
    faction = FACTION_ALLIANCE,
    zone = "Ashenvale"
}, {
    achId = "Nekrosh",
    title = "Nek’rosh No More",
    level = 24,
    tooltip = "Complete |cff008765Defeat Nek'rosh|r before level 35",
    icon = 134170,
    points = 10,
    requiredQuestId = 474, -- Quest available at level 23
    targetNpcId = 2091, -- Nekrosh level 26
    faction = FACTION_ALLIANCE,
    zone = "Wetlands"
}, {
    achId = "Morbent",
    title = "Morbent Has Fallen",
    level = 29,
    tooltip = "Complete |cff008765Morbent Fel|r before level 30",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Ability_mage_studentofthemind.png", -- 236225
    points = 10,
    requiredQuestId = 55, -- Quest available at level 20
    targetNpcId = 1200, -- Morbent level 32 Elite (possibly? he gets weakened)
    faction = FACTION_ALLIANCE,
    zone = "Duskwood"
}, {
    achId = "Eliza",
    title = "The Alchemist's Wife",
    level = 27,
    tooltip = "Complete |cff008765Bride of the Embalmer|r before level 28",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_BG_Xkills_AVgraveyard.png", -- 236399
    points = 10,
    requiredQuestId = 253, -- Quest available at level 20
    targetNpcId = 314, -- Eliza level 30
    faction = FACTION_ALLIANCE,
    zone = "Duskwood"
}, {
    achId = "MorLadim",
    title = "Mor’Ladim’s Rest",
    level = 28,
    tooltip = "Complete |cff008765Mor'Ladim|r before level 29",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Dungeon_TheNecroticWake_StitchFlesh.png", -- ??
    points = 10,
    requiredQuestId = 228, -- Quest available at level 25
    targetNpcId = 522, -- Mor'Ladim level 30 Elite
    faction = FACTION_ALLIANCE,
    zone = "Duskwood"
}, {
    achId = "ForsakenCourier",
    title = "Courier of Death",
    level = 32,
    tooltip = "Complete |cff008765Hints of a New Plague|r before level 33",
    icon = 133470,
    points = 10,
    requiredQuestId = 658, -- Quest available at level 30
    targetNpcId = 2714, -- Forsaken Courier level 35
    faction = FACTION_ALLIANCE,
    zone = "Arathi Highlands"
}, {
    achId = "StinkysEscapeA",
    title = "Stinky Situation",
    level = 32,
    tooltip = "Complete |cff008765Stinky’s Escape|r before level 33",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\achievement_zone_dustwallowmarsh.png", -- 236758
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1222, -- Quest available at level 30
    targetNpcId = nil,
    faction = FACTION_ALLIANCE,
    zone = "Dustwallow Marsh"
}, {
    achId = "OttoFalcon",
    title = "Bring Me Their Heads!",
    level = 37,
    tooltip = "Complete |cff008765Wanted! Otto and Falconcrest|r before level 38",
    icon = 134166,
    points = 10,
    requiredQuestId = 685, -- Quest available at level 29
    targetNpcId = {2599, 2597}, -- Otto and Falconcrest level 38/40
    faction = FACTION_ALLIANCE,
    zone = "Arathi Highlands"
}, {
    achId = "Kurzen",
    title = "Kurzen's Fall",
    level = 37,
    tooltip = "Complete |cff008765Colonel Kurzen|r before level 38",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_stranglethorn_01.png", -- 236844
    points = 10,
    requiredQuestId = 202, -- Quest available at level 30
    targetNpcId = 813, -- Kurzen level 40
    faction = FACTION_ALLIANCE,
    zone = "Stanglethorn Vale"
}, {
    achId = "LordShalzaru",
    title = "Lord of the Depths",
    level = 44,
    tooltip = "Complete |cff008765Against Lord Shalzaru|r before level 45",
    icon = 136098,
    points = 10,
    requiredQuestId = 2870, -- Quest available at level 40
    targetNpcId = 8136, -- Lord Shalzaru level 47
    faction = FACTION_ALLIANCE,
    zone = "Feralas"
}, {
    achId = "Overlord",
    title = "So Rude",
    level = 61,
    tooltip = "Complete |cff008765Overlord|r before level 62",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Spell_Shadow_DemonForm.png", -- 237558
    points = 10,
    requiredQuestId = 10400, -- Quest available at level 58
    targetNpcId = 19191, -- Overlord level 63 Elite
    faction = FACTION_ALLIANCE,
    zone = "Hellfire Peninsula"
}, {
    achId = "FelReaverA",
    title = "The Grim Reaver",
    level = 68,
    tooltip = "Complete |cff008765Hotter Than Hell|r before level 69",
    icon = 135801,
    points = 10,
    requiredQuestId = 10764, -- Quest available at level 68
    targetNpcId = 18733, -- Fel Reaver level 70 Elite
    faction = FACTION_ALLIANCE,
    zone = "Hellfire Peninsula"
},

-- Horde (new)
{
    achId = "Dargol",
    title = "Crypt Commander",
    level = 10,
    tooltip = "Complete |cff008765The Family Crypt|r before level 11",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_character_undead_male.png", -- 236458
    points = 10,
    requiredQuestId = 408, -- Quest available at level 7
    targetNpcId = 1658, -- Dargol level 13
    faction = FACTION_HORDE,
    zone = "Tirisfal Glades"
}, {
    achId = "Arrachea",
    title = "Spirit of the Earthmother",
    level = 8,
    tooltip = "Complete |cff008765Rites of the Earthmother|r before level 9",
    icon = 132243,
    points = 10,
    requiredQuestId = 776, -- Quest available at level 3
    targetNpcId = 3058, -- Arrachea level 11
    faction = FACTION_HORDE,
    zone = "Thunder Bluff"
}, {
    achId = "Gazzuz",
    title = "Slayer of Gazz’uz",
    level = 12,
    tooltip = "Complete |cff008765Burning Shadows|r before level 13",
    icon = 134085,
    points = 10,
    requiredQuestId = 832, -- Quest available at level 4
    targetNpcId = 3204, -- Gazzuz level 14 (quest item drops from this NPC)
    allowKillsBeforeQuest = true, -- Allow tracking kill before quest acceptance (quest item drops from NPC)
    faction = FACTION_HORDE,
    zone = "Orgrimmar"
}, {
    achId = "Fizzle",
    title = "Fo' Rizzle My Fizzle!",
    level = 10,
    tooltip = "Complete |cff008765Dark Storms|r before level 11",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Ability_warlock_backdraft.png", -- 236290
    points = 10,
    requiredQuestId = 806, -- Quest available at level 4
    targetNpcId = 3203, -- Fizzle level 12
    faction = FACTION_HORDE,
    zone = "Durotar"
}, {
    achId = "Goggeroc",
    title = "Stone and Soil",
    level = 17,
    tooltip = "Complete |cff008765Earthen Arise|r before level 18",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_stonetalon_01.png", -- 236831
    points = 10,
    requiredQuestId = 6481, -- Quest available at level 14
    targetNpcId = 11920, -- Goggeroc level 20
    faction = FACTION_HORDE,
    zone = "Stonetalon Mountains"
}, {
    achId = "Kromzar",
    title = "Counterattack!",
    level = 18,
    tooltip = "Complete |cff008765Counterattack!|r before level 19",
    icon = 132484,
    points = 10,
    requiredQuestId = 4021, -- Quest available at level 11
    targetNpcId = 9456, -- Kromzar level 20 Elite
    faction = FACTION_HORDE,
    zone = "The Barrens"
}, {
    achId = "LuzKnuck",
    title = "They Had It Coming",
    level = 20,
    tooltip = "Complete |cff008765Wanted: Luzran & Knucklerot|r before level 21",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\ACHIEVEMENT_BOSS_PATCHWERK.png", -- 298667
    points = 10,
    requiredQuestId = 9156, -- Quest available at level 9
    targetNpcId = {16245, 16246}, -- Luzran & Knucklerot level 21 Elite
    faction = FACTION_HORDE,
    zone = "Ghostlands"
}, {
    achId = "Drathir",
    title = "Dar'khan the Traitor",
    level = 19,
    tooltip = "Complete |cff008765The Traitor's Destruction|r before level 20",
    icon = 134179,
    points = 10,
    requiredQuestId = 9167, -- Quest available at level 15
    targetNpcId = 16329, -- Dar'khan Drathir level 21 Elite
    faction = FACTION_HORDE,
    zone = "Ghostlands"
}, {
    achId = "Ataeric",
    title = "Thread of the Weaver",
    level = 19,
    tooltip = "Complete |cff008765The Weaver|r before level 20",
    icon = 135144,
    points = 10,
    requiredQuestId = 480, -- Quest available at level 10
    targetNpcId = 2120, -- Ataeric level 22
    faction = FACTION_HORDE,
    zone = "Silverpine Forest"
}, {
    achId = "TheHunt",
    title = "The Great Hunt",
    level = 26,
    tooltip = "Complete |cff008765The Hunt Completed|r by slaying |cff008765Sharptalon|r, |cff008765Shadumbra|r, and |cff008765Ursangous|r before level 27",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Ashenvale_01.png", -- 236713
    points = 10,
    requiredQuestId = 247, -- Quest available at level 20
    targetNpcId = {12676, 12677, 12678}, -- Sharptalon, Shadumbra, Ursangous level 25, 28, 31
    faction = FACTION_HORDE,
    zone = "Ashenvale"
}, {
    achId = "Gizmo",
    title = "Flux-Hypercapacitor",
    level = 27,
    tooltip = "Complete |cff008765Hypercapacitor Gizmo|r before level 28",
    icon = 133236,
    points = 10,
    requiredQuestId = 5151, -- Quest available at level 24
    targetNpcId = 10992, -- Gizmo level 30 Elite
    faction = FACTION_HORDE,
    zone = "Thousand Needles"
}, {
    achId = "Grenka",
    title = "What's in the Box!?",
    level = 28,
    tooltip = "Complete |cff008765Test of Endurance|r before level 29",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_ThousandNeedles_01.png", -- 236848
    points = 10,
    requiredQuestId = 1150, -- Quest available at level 25
    targetNpcId = 4490, -- Grenka level 30
    faction = FACTION_HORDE,
    zone = "Thousand Needles"
}, {
    achId = "Ironhill",
    title = "Hillsbrad Commander",
    level = 28,
    tooltip = "Complete |cff008765Battle of Hillsbrad|r before level 29",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_HillsbradFoothills.png", -- 236779
    points = 10,
    requiredQuestId = 541, -- Quest available at level 19
    targetNpcId = 2304, -- Ironhill level 32
    faction = FACTION_HORDE,
    zone = "Hillsbrad Foothills"
}, {
    achId = "StinkysEscapeH",
    title = "Stinky Situation",
    level = 32,
    tooltip = "Complete |cff008765Stinky’s Escape|r before level 33",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\achievement_zone_dustwallowmarsh.png", -- 236758
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1270, -- Quest available at level 30
    targetNpcId = nil,
    faction = FACTION_HORDE,
    zone = "Dustwallow Marsh"
}, {
    achId = "NothingButTruth",
    title = "Truth Seeker",
    level = 39,
    tooltip = "Complete |cff008765Nothing but the Truth Pt. 4|r before level 40",
    icon = 132800,
    points = 10,
    requiredQuestId = 1383, -- Quest available at level 37
    targetNpcId = nil,
    faction = FACTION_HORDE,
    zone = "Duskwood"
}, {
    achId = "Mugthol",
    title = "Crowned",
    level = 40,
    tooltip = "Complete |cff008765The Crown of Will Pt. 4|r before level 41",
    icon = 132768,
    points = 10,
    requiredQuestId = 520, -- Quest available at level 34
    targetNpcId = 2257, -- Mugthol level 43
    faction = FACTION_HORDE,
    zone = "Hillsbrad Foothills"
}, {
    achId = "Hatetalon",
    title = "Dark Heart of the Wild",
    level = 47,
    tooltip = "Complete |cff008765Dark Heart|r before level 48",
    icon = 134131,
    points = 10,
    requiredQuestId = 3062, -- Quest available at level 45
    targetNpcId = 8075, -- Hatetalon level 50
    faction = FACTION_HORDE,
    zone = "Feralas"
}, {
    achId = "Kromgrul",
    title = "Crushing the Grul",
    level = 51,
    tooltip = "Complete |cff008765Krom'Grul|r before level 52",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Reputation_Ogre.png", -- 236695
    points = 10,
    requiredQuestId = 3822, -- Quest available at level 48
    targetNpcId = 8977, -- Kromgrul level 54
    faction = FACTION_HORDE,
    zone = "Burning Steppes"
}, {
    achId = "Cruel",
    title = "So Rude",
    level = 61,
    tooltip = "Complete |cff008765Cruel's Intentions|r before level 62",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Spell_Shadow_DemonForm.png", -- 237558
    points = 10,
    requiredQuestId = 10136, -- Quest available at level 58
    targetNpcId = 19191, -- Overlord level 63 Elite
    faction = FACTION_HORDE,
    zone = "Hellfire Peninsula"
}, {
    achId = "FelReaverH",
    title = "The Grim Reaver",
    level = 68,
    tooltip = "Complete |cff008765Hotter Than Hell|r before level 69",
    icon = 135801,
    points = 10,
    requiredQuestId = 10758, -- Quest available at level 68
    targetNpcId = 18733, -- Fel Reaver level 70 Elite
    faction = FACTION_HORDE,
    zone = "Hellfire Peninsula"
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
    achId = "Level70",
    title = "Outlandish!",
    level = 70,
    tooltip = "Reach level 70 without dying",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\milestone_square_70.png",
    points = 70,
    customIsCompleted = function(newLevel) return (newLevel or UnitLevel("player") or 1) >= 70 end,
    staticPoints = true,
}, {
    achId = "GalensEscape",
    title = "Galen's Freedom",
    level = 38,
    tooltip = "Complete |cff008765Galen's Escape|r before level 39",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_swampsorrows_01.png", -- 236845
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1393, -- Quest available at level 30
    targetNpcId = nil,
    zone = "Swamp of Sorrows"
}, {
    achId = "GetMeOutOfHere",
    title = "Outta Here!",
    level = 40,
    tooltip = "Complete |cff008765Get Me Out of Here!|r before level 41",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_desolace.png", -- 236742
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 6132, -- Quest available at level 34
    targetNpcId = nil,
    zone = "Desolace"
}, {
    achId = "KingBangalash",
    title = "King of the Jungle",
    level = 41,
    tooltip = "Complete |cff008765Big Game Hunter|r before level 42",
    icon = 134176,
    points = 10,
    requiredQuestId = 208, -- Quest available at level 28
    targetNpcId = 731, -- King Bangalash level 43 Elite
    zone = "Stranglethorn Vale"
}, {
    achId = "OOX",
    title = "Oox I Did It Again",
    level = 45,
    tooltip = "Complete |cff008765An OOX of Your Own|r before level 46",
    icon = 133883,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 3721, -- Quest available at level 40
    targetNpcId = nil,
    zone = "Stranglethorn Vale"
}, {
    achId = "Mokk",
    title = "This Isn't Worth It",
    level = 42,
    tooltip = "Complete |cff008765Stranglethorn Fever|r before level 43",
    icon = 134338,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 348, -- Quest available at level 40
    targetNpcId = 1514, -- Mokk level 44
    zone = "Stranglethorn Vale"
}, {
    achId = "MalletZF",
    title = string.format("%s the Keeper", GetUnitName("player")),
    level = 47,
    tooltip = "Obtain the |cff008765Mallet of Zul'Farrak|r before level 48",
    icon = 134559,
    points = 10,
    allowSoloDouble = true,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(9240, true) > 0 end,
    zone = "Hinterlands"
}, {
    achId = "KimJaelIndeed",
    title = "Booty Bay Genius",
    level = 50,
    tooltip = "Complete |cff008765Kim’Jael Indeed!|r before level 51",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_azshara_01.png", -- 236714
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 3601, -- Quest available at level 47
    targetNpcId = nil,
    zone = "Azshara"
}, {
    achId = "StonesThatBindUs",
    title = "Stonebound Savior",
    level = 53,
    tooltip = "Complete |cff008765The Stones That Bind Us|r before level 54",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_blastedlands_01.png", -- 236720
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 2681, -- Quest available at level 45
    targetNpcId = nil,
    zone = "Blasted Lands"
}, {
    achId = "Hakkar",
    title = "Spirits, Tablets, and Eggs, Oh My!",
    level = 48,
    tooltip = "Complete |cff008765The God Hakkar|r before level 49",
    icon = 132209,
    points = 10,
    requiredQuestId = 3528, -- Quest available at level 40
    targetNpcId = nil,
    zone = "Tanaris"
}, {
    achId = "ShadowLordFeldan",
    title = "Shadow’s End",
    level = 55,
    tooltip = "Complete |cff008765A Final Blow|r before level 56",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_felwood.png", -- 236763
    points = 10,
    requiredQuestId = 5242, -- Quest available at level 48
    targetNpcId = 9517, -- Shadow Lord Feldan level 57
    zone = "Felwood"
}, {
    achId = "SummoningThePrincess",
    title = "Shards of Myzrael",
    level = 42,
    tooltip = "Complete |cff008765Summoning the Princess|r before level 43",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_Enchanting_Shard.png", -- ??
    points = 10,
    requiredQuestId = 656, -- Quest available at level 30
    targetNpcId = 2755, -- Myzrael level 44 Elite
    zone = "Badlands"
}, {
    achId = "GorishiHiveQueen",
    title = "Queen’s Gambit",
    level = 53,
    tooltip = "Complete |cff008765Pawn Captures Queen|r before level 54",
    icon = 134340,
    points = 10,
    requiredQuestId = 4507, -- Quest available at level 50
    targetNpcId = 10041, -- Gorishi Hive Queen level 56
    zone = "Un'Goro Crater"
}, {
    achId = "OverseerMaltorius",
    title = "Master of the Forge",
    level = 47,
    tooltip = "Complete |cff008765WANTED: Overseer Maltorius|r before level 48",
    icon = 134159,
    points = 10,
    requiredQuestId = 7701, -- Quest available at level 45
    targetNpcId = 14621, -- Overseer Maltorius level 49
    zone = "Searing Gorge"
}, {
    achId = "MercutioFilthgorger",
    title = "Mercutio’s Memory",
    level = 54,
    tooltip = "Complete |cff008765Of Forgotten Memories|r before level 55",
    icon = 133038,
    points = 10,
    requiredQuestId = 5781, -- Quest available at level 52
    targetNpcId = 11886, -- Mercutio Filthgorger level 57
    zone = "Eastern Plaguelands"
}, {
    achId = "HighChiefWinterfall",
    title = "Winter is Coming",
    level = 56,
    tooltip = "Complete |cff008765High Chief Winterfall|r before level 57",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_timbermaw.png", -- 236696
    points = 10,
    requiredQuestId = 5121, -- Quest available at level 52
    targetNpcId = 10738, -- High Chief Winterfall level 59
    zone = "Winterspring"
}, {
    achId = "Deathclasp",
    title = "Deathclasp Down",
    level = 57,
    tooltip = "Complete |cff008765Wanted: Deathclasp, Terror of the Sands|r before level 58",
    icon = 133708,
    points = 10,
    requiredQuestId = 8283, -- Quest available at level 54
    targetNpcId = 15196, -- Deathclasp level 59 Elite
    zone = "Silithus"
}, {
    achId = "RingOfBlood",
    title = "The Gladiator's Ring",
    level = 65,
    tooltip = "Complete |cff008765The Ring of Blood: The Final Challenge|r before level 66",
    icon = 132334,
    points = 10,
    requiredQuestId = 9977, -- Quest available at level 65
    targetNpcId = 18069, -- Mogor level 67 Elite
    zone = "Nagrand"
},

-- Rogue
{
    achId = "Gallywix",
    title = "Get Gallywix or Die Tryin |cfffff468[Rogue]|r",
    level = 23,
    tooltip = "Complete |cff008765Mission: Possible But Not Probable|r before level 24",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Ability_Rogue_StayofExecution.PNG", -- 236281
    points = 10,
    requiredQuestId = 2478, -- Quest available at level 20
    targetNpcId = 7288, -- Gallywix level 23 Elite
    faction = FACTION_HORDE,
    class = "ROGUE",
    zone = "Barrens"
}, {
    achId = "DefiasMask",
    title = "One of Us! |cfffff468[Rogue]|r",
    level = nil,
    tooltip = "Equip a |cff008765Red Defias Mask|r and join the ranks of the Defias Brotherhood",
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
    tooltip = "Complete |cff008765Investigate the Alchemist Shop|r before level 19",
    icon = 135734,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1960, -- Quest available at level 15
    targetNpcId = nil,
    faction = FACTION_HORDE,
    class = "MAGE",
    zone = "Undercity"
}, {
    achId = "AlchemistShopA",
    title = "Back to Elwynn! |cff3FC7EB[Mage]|r",
    level = 18,
    tooltip = "Complete |cff008765Investigate the Blue Recluse|r before level 19",
    icon = 135734,
    points = 10,
    allowSoloDouble = true,
    requiredQuestId = 1920, -- Quest available at level 15
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
    tooltip = "Complete |cff008765The Summoning|r before level 39",
    icon = 134131,
    points = 10,
    requiredQuestId = 1713, -- Quest available at level 30
    targetNpcId = 6239, -- Cyclonian level 40 Elite
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
        achId                = def.achId,
        requiredQuestId      = def.requiredQuestId,
        targetNpcId          = def.targetNpcId,
        requiredKills        = def.requiredKills,
        maxLevel             = def.level,
        faction              = def.faction,
        race                 = def.race,
        class                = def.class,
        allowKillsBeforeQuest = def.allowKillsBeforeQuest,
      }
    end
  end
end

-- Export achievements to global scope for AdminPanel access
_G.Achievements = Achievements

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
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
