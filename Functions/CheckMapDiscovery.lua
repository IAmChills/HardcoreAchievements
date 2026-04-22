-- CheckMapDiscovery.lua
-- Function to check if a specific location on the world map has been discovered
-- Uses C_MapExplorationInfo.GetExploredAreaIDsAtPosition to check exploration status
--
-- Usage Examples:
--   1. By zone and location name:
--      local discovered, err = CheckMapDiscoveryByLocation("Elwynn Forest", "Goldshire")
--      if discovered then print("Goldshire has been discovered!") end
--
--   2. By mapID and coordinates directly:
--      local discovered, err = CheckMapDiscoveryByCoords(1429, 0.42, 0.62)
--      if discovered then print("Location has been discovered!") end
--
--   3. Full function with all parameters:
--      local discovered, err = CheckMapDiscovery(1429, 0.42, 0.62, nil, nil)
--      -- or
--      local discovered, err = CheckMapDiscovery(nil, nil, nil, "Elwynn Forest", "Goldshire")
--
--   4. Check entire zone (checks all defined locations from LocationMap):
--      local discovered, err, count, total = CheckZoneDiscovery("Deadwind Pass")
--      if discovered then print("Entire zone discovered!") end
--      -- Or with a threshold (e.g., 80% of locations must be discovered):
--      local discovered, err = CheckZoneDiscovery("Deadwind Pass", 0.8)
--      -- Or by mapID:
--      local discovered, err = CheckZoneDiscovery(1430)
--
-- Note: Coordinates are normalized (0-1 range) where (0,0) is top-left and (1,1) is bottom-right
-- To find coordinates for a location, stand at that location and run:
--   /run local mapID = C_Map.GetBestMapForUnit("player"); local pos = C_Map.GetPlayerMapPosition(mapID, "player"); if pos then local x,y = pos:GetXY(); print("mapID:", mapID, "x:", x, "y:", y) end
-- Tp find coordinates for a location using the mouse pointer on the world map, run:
-- /dump WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()

local addonName, addon = ...
local C_MapExplorationInfo = C_MapExplorationInfo
local table_insert = table.insert
local table_sort = table.sort
local string_format = string.format

---------------------------------------
-- Zone to MapID mapping
-- Add zones as needed (you can find mapIDs using /dump C_Map.GetBestMapForUnit("player"))
---------------------------------------
local ZoneMapIDs = {
    -- Kalimdor
    ["Ashenvale"] = 1440,
    ["Azshara"] = 1447,
    ["Azuremyst Isle"] = 1943,
    ["Bloodmyst Isle"] = 1950,
    ["Darkshore"] = 1439,
    ["Darnassus"] = 1457,
    ["Desolace"] = 1443,
    ["Durotar"] = 1411,
    ["Dustwallow Marsh"] = 1445,
    ["Felwood"] = 1448,
    ["Feralas"] = 1444,
    ["Moonglade"] = 1450,
    ["Mulgore"] = 1412,
    ["Orgrimmar"] = 1454,
    ["Silithus"] = 1451,
    ["Stonetalon Mountains"] = 1442,
    ["Tanaris"] = 1446,
    ["Teldrassil"] = 1438,
    ["The Barrens"] = 1413,
    ["The Exodar"] = 1947,
    ["Thousand Needles"] = 1441,
    ["Thunder Bluff"] = 1456,
    ["Un'Goro Crater"] = 1449,
    ["Winterspring"] = 1452,

    -- Eastern Kingdoms
    ["Alterac Mountains"] = 1416,
    ["Arathi Highlands"] = 1417,
    ["Badlands"] = 1418,
    ["Blasted Lands"] = 1419,
    ["Burning Steppes"] = 1428,
    ["Deadwind Pass"] = 1430,
    ["Dun Morogh"] = 1426,
    ["Duskwood"] = 1431,
    ["Eastern Plaguelands"] = 1423,
    ["Elwynn Forest"] = 1429,
    ["Eversong Woods"] = 1941,
    ["Ghostlands"] = 1942,
    ["Hillsbrad Foothills"] = 1424,
    ["Ironforge"] = 1455,
    ["Isle of Quel'Danas"] = 1957,
    ["Loch Modan"] = 1432,
    ["Redridge Mountains"] = 1433,
    ["Searing Gorge"] = 1427,
    ["Silvermoon City"] = 1954,
    ["Silverpine Forest"] = 1421,
    ["Stormwind City"] = 1453,
    ["Stranglethorn Vale"] = 1434,
    ["Swamp of Sorrows"] = 1435,
    ["The Hinterlands"] = 1425,
    ["Tirisfal Glades"] = 1420,
    ["Undercity"] = 1458,
    ["Western Plaguelands"] = 1422,
    ["Westfall"] = 1436,
    ["Wetlands"] = 1437,

    -- Outlands
    ["Blade's Edge Mountains"] = 1949,
    ["Hellfire Peninsula"] = 1944,
    ["Nagrand"] = 1951,
    ["Netherstorm"] = 1953,
    ["Shadowmoon Valley"] = 1948,
    ["Shattrath City"] = 1955,
    ["Terokkar Forest"] = 1952,
    ["Zangarmarsh"] = 1946,
}

---------------------------------------
-- Location mappings within zones
-- Coordinates are normalized 0-1 (x, y) where (0,0) is top-left, (1,1) is bottom-right
-- Format: [zoneName] = { [locationName] = {x = 0.0-1.0, y = 0.0-1.0} }
---------------------------------------
local LocationMap = {
    -- ==================== KALIMDOR ====================
    ["Ashenvale"] = {
        ["Astranaar"] = {x = 0.37, y = 0.51},
        ["Thistlefur Village"] = {x = 0.32, y = 0.38},
        ["The Ruins of Ordil'Aran"] = {x = 0.30, y = 0.28},
        ["Lake Falathim"] = {x = 0.20, y = 0.37},
        ["The Shrine of Aessina"] = {x = 0.22, y = 0.53},
        ["Fire Scare Shrine"] = {x = 0.27, y = 0.64},
        ["The Ruins of Stardust"] = {x = 0.34, y = 0.68},
        ["Mystral Lake"] = {x = 0.48, y = 0.67},
        ["Iris Lake"] = {x = 0.46, y = 0.46},
        ["Nightsong Woods"] = {x = 0.58, y = 0.38},
        ["Raynewood Retreat"] = {x = 0.62, y = 0.51},
        ["Night Run"] = {x = 0.67, y = 0.57},
        ["Fallen Sky Lake"] = {x = 0.64, y = 0.80},
        ["Felfire Hill"] = {x = 0.83, y = 0.70},
        ["Warsong Lumber Camp"] = {x = 0.90, y = 0.58},
        ["Satyrnaar"] = {x = 0.83, y = 0.49},
        ["Bough Shadow"] = {x = 0.93, y = 0.37},
        ["Zoram Strand"] = {x = 0.14, y = 0.25},
    },
    ["Azshara"] = {
        ["Shadowsong Shrine"] = {x = 0.17, y = 0.72},
        ["Haldarr Encampment"] = {x = 0.21, y = 0.61},
        ["Valormok"] = {x = 0.22, y = 0.51},
        ["Ruins of Eldarath"] = {x = 0.37, y = 0.54},
        ["Timbermaw Hold"] = {x = 0.40, y = 0.35},
        ["Ursolan"] = {x = 0.49, y = 0.26},
        ["Legash Encampment"] = {x = 0.55, y = 0.20},
        ["Thalassian Base Camp"] = {x = 0.57, y = 0.29},
        ["Bitter Reaches"] = {x = 0.72, y = 0.22},
        ["Jagged Reef"] = {x = 0.77, y = 0.09},
        ["Temple of Arkkoran"] = {x = 0.78, y = 0.40},
        ["Tower of Eldara"] = {x = 0.90, y = 0.33},
        ["Bay of Storms"] = {x = 0.55, y = 0.55},
        ["Southridge Breach"] = {x = 0.56, y = 0.71},
        ["Ravencrest Monument"] = {x = 0.71, y = 0.86},
        ["The Ruined Reaches"] = {x = 0.63, y = 0.91},
        ["Lake Mennar"] = {x = 0.41, y = 0.79},
        ["Forlorn Ridge"] = {x = 0.30, y = 0.74},
    },
    ["Azuremyst Isle"] = {
        ["The Exodar"] = {x = 0.30, y = 0.40},
        ["Bristlelimb Village"] = {x = 0.28, y = 0.68},
        ["Moonwing Den"] = {x = 0.14, y = 0.84},
        ["Wrathscale Point"] = {x = 0.33, y = 0.77},
        ["Odesyus' Landing"] = {x = 0.46, y = 0.68},
        ["Geezle's Camp"] = {x = 0.59, y = 0.65},
        ["Pod Wreckage"] = {x = 0.52, y = 0.62},
        ["Moongreaze Woods"] = {x = 0.54, y = 0.42},
        ["Azure Watch"] = {x = 0.49, y = 0.51},
        ["Pod Cluster"] = {x = 0.37, y = 0.60},
        ["Valaar's Berth"] = {x = 0.22, y = 0.54},
        ["Silting Shore"] = {x = 0.36, y = 0.13},
        ["Fairbridge Strand"] = {x = 0.46, y = 0.05},
        ["Emberglade"] = {x = 0.58, y = 0.19},
        ["Stillpine Hold"] = {x = 0.46, y = 0.19},
        ["Ammen Ford"] = {x = 0.60, y = 0.54},
        ["Ammen Vale"] = {x = 0.75, y = 0.54},
    },
    ["Bloodmyst Isle"] = {
        ["Kessel's Crossing"] = {x = 0.63, y = 0.87},
        ["Bristlelimb Enclave"] = {x = 0.68, y = 0.77},
        ["Wrathscale Lair"] = {x = 0.69, y = 0.66},
        ["Bloodcurse Isle"] = {x = 0.86, y = 0.54},
        ["Wyrmscar Island"] = {x = 0.74, y = 0.29},
        ["Veridian Point"] = {x = 0.75, y = 0.11},
        ["Talon Stand"] = {x = 0.74, y = 0.20},
        ["The Warp Piston"] = {x = 0.54, y = 0.19},
        ["Ragefeather Ridge"] = {x = 0.56, y = 0.35},
        ["Ruins of Loreth'Aran"] = {x = 0.62, y = 0.47},
        ["Blood Watch"] = {x = 0.54, y = 0.56},
        ["Middenvale"] = {x = 0.51, y = 0.77},
        ["Mystwood"] = {x = 0.47, y = 0.88},
        ["Nazzivian"] = {x = 0.39, y = 0.76},
        ["Blacksilt Shore"] = {x = 0.35, y = 0.91},
        ["The Cryo-Core"] = {x = 0.39, y = 0.59},
        ["The Vector Coil"] = {x = 0.21, y = 0.55},
        ["Vindicator's Rest"] = {x = 0.31, y = 0.45},
        ["Amberweb Pass"] = {x = 0.18, y = 0.30},
        ["The Foul Pool"] = {x = 0.31, y = 0.34},
        ["Axxarien"] = {x = 0.40, y = 0.34},
        ["The Bloodwash"] = {x = 0.38, y = 0.23},
        ["Bladewood"] = {x = 0.46, y = 0.45},
    },
    ["Darkshore"] = {
        ["Bashal'Aran"] = {x = 0.44, y = 0.38},
        ["Ameth'Aran"] = {x = 0.43, y = 0.58},
        ["Auberdine"] = {x = 0.39, y = 0.45},
        ["Remtravel's Excavation"] = {x = 0.36, y = 0.86},
        ["Twilight Vale"] = {x = 0.42, y = 0.87},
        ["Grove of the Ancients"] = {x = 0.43, y = 0.77},
        ["Grove of the Ancients"] = {x = 0.0, y = 0.0},
        ["Cliffspring River"] = {x = 0.49, y = 0.28},
        ["Tower of Althalaxx"] = {x = 0.57, y = 0.26},
        ["Ruins of Mathystra"] = {x = 0.59, y = 0.18},
    },
    ["Darnassus"] = {
        ["Darnassus"] = {x = 0.50, y = 0.50},
    },
    ["Desolace"] = {
        ["Thunder Axe Fortress"] = {x = 0.56, y = 0.27},
        ["Sargeron"] = {x = 0.75, y = 0.22},
        ["Tethris Aran"] = {x = 0.55, y = 0.14},
        ["Kolkar Village"] = {x = 0.70, y = 0.50},
        ["Magram Village"] = {x = 0.73, y = 0.73},
        ["Shadowbreak Ravine"] = {x = 0.79, y = 0.78},
        ["Mannoroc Coven"] = {x = 0.54, y = 0.79},
        ["Kodo Graveyard"] = {x = 0.52, y = 0.59},
        ["Kormek's Hut"] = {x = 0.62, y = 0.40},
        ["Ethel Rethor"] = {x = 0.40, y = 0.30},
        ["Ranazjar Isle"] = {x = 0.29, y = 0.08},
        ["Valley of Spears"] = {x = 0.33, y = 0.57},
        ["Shadowprey Village"] = {x = 0.24, y = 0.70},
        ["Gelkis Village"] = {x = 0.38, y = 0.87},
        ["Nijel's Point"] = {x = 0.65, y = 0.09},
    },
    ["Durotar"] = {
        ["Orgrimmar"] = {x = 0.45, y = 0.07},
        ["Skull Rock"] = {x = 0.55, y = 0.12},
        ["Drygulch Ravine"] = {x = 0.53, y = 0.23},
        ["Razor Hill"] = {x = 0.54, y = 0.43},
        ["Tiragarde Keep"] = {x = 0.58, y = 0.56},
        ["Sen'jin Village"] = {x = 0.56, y = 0.74},
        ["Echo Isles"] = {x = 0.66, y = 0.84},
        ["Kolkar Crag"] = {x = 0.48, y = 0.78},
        ["Valley of Trials"] = {x = 0.44, y = 0.64},
        ["Razormane Grounds"] = {x = 0.41, y = 0.45},
        ["Thunder Ridge"] = {x = 0.41, y = 0.26},
    },
    ["Dustwallow Marsh"] = {
        ["Alcaz Island"] = {x = 0.75, y = 0.18},
        ["Witch Hill"] = {x = 0.54, y = 0.25},
        ["Brackenwall Village"] = {x = 0.39, y = 0.24},
        ["The Quagmire"] = {x = 0.45, y = 0.51},
        ["Stonemaul Ruins"] = {x = 0.43, y = 0.65},
        ["Wyrmbog"] = {x = 0.52, y = 0.74},
        ["Theramore Isle"] = {x = 0.66, y = 0.49},
    },
    ["Felwood"] = {
        ["Morlos'Aran"] = {x = 0.55, y = 0.88},
        ["Deadwood Village"] = {x = 0.48, y = 0.89},
        ["Emerald Sanctuary"] = {x = 0.47, y = 0.76},
        ["Jadefire Glen"] = {x = 0.40, y = 0.83},
        ["Ruins of Constellas"] = {x = 0.39, y = 0.69},
        ["Jaedenar"] = {x = 0.37, y = 0.59},
        ["Bloodvenom Falls"] = {x = 0.43, y = 0.47},
        ["Shatter Scar Vale"] = {x = 0.44, y = 0.39},
        ["Irontree Woods"] = {x = 0.50, y = 0.24},
        ["Jadefire Run"] = {x = 0.42, y = 0.17},
        ["Felpaw Village"] = {x = 0.63, y = 0.13},
        ["Talonbranch Glade"] = {x = 0.63, y = 0.24},
    },
    ["Feralas"] = {
        ["Ruins of Ravenwood"] = {x = 0.41, y = 0.13},
        ["The Twin Colossals"] = {x = 0.46, y = 0.27},
        ["Oneiros"] = {x = 0.54, y = 0.16},
        ["Dream Bough"] = {x = 0.52, y = 0.10},
        ["The Forgotten Coast"] = {x = 0.48, y = 0.46},
        ["Feathermoon Stronghold"] = {x = 0.29, y = 0.49},
        ["Isle of Dread"] = {x = 0.30, y = 0.79},
        ["Frayfeather Highlands"] = {x = 0.55, y = 0.72},
        ["Feral Scar Vale"] = {x = 0.56, y = 0.57},
        ["Dire Maul"] = {x = 0.59, y = 0.48},
        ["Ruins of Isildien"] = {x = 0.61, y = 0.63},
        ["The Writhing Deep"] = {x = 0.73, y = 0.61},
        ["Camp Mojache"] = {x = 0.75, y = 0.42},
        ["Grimtotem Compound"] = {x = 0.66, y = 0.38},
        ["Gordunni Outpost"] = {x = 0.76, y = 0.31},
        ["Lower Wilds"] = {x = 0.86, y = 0.44},
    },
    ["Moonglade"] = {
        ["Nighthaven"] = {x = 0.51, y = 0.54},
    },
    ["Mulgore"] = {
        ["Red Cloud Mesa"] = {x = 0.49, y = 0.79},
        ["Bloodhoof Village"] = {x = 0.51, y = 0.62},
        ["The Rolling Plains"] = {x = 0.65, y = 0.68},
        ["The Venture Co. Mine"] = {x = 0.61, y = 0.48},
        ["Ravaged Caravan"] = {x = 0.53, y = 0.46},
        ["Palemane Rock"] = {x = 0.36, y = 0.64},
        ["Bael'dun Digsite"] = {x = 0.37, y = 0.42},
        ["Thunder Bluff"] = {x = 0.39, y = 0.26},
        ["Wildmane Water Well"] = {x = 0.41, y = 0.13},
        ["Windfury Ridge"] = {x = 0.51, y = 0.09},
        ["The Golden Plains"] = {x = 0.52, y = 0.27},
        ["Red Rocks"] = {x = 0.60, y = 0.21},
        ["Thunderhorn Water Well"] = {x = 0.45, y = 0.46},
    },
    ["Orgrimmar"] = {
        ["Orgrimmar"] = {x = 0.50, y = 0.50},
    },
    ["Silithus"] = {
        ["Staghelm Point"] = {x = 0.64, y = 0.38},
        ["Hive'Ashi"] = {x = 0.45, y = 0.25},
        ["The Crystal Vale"] = {x = 0.23, y = 0.15},
        ["Hive'Zora"] = {x = 0.26, y = 0.59},
        ["Ahn'Qiraj"] = {x = 0.30, y = 0.95},
        ["Hive'Regal"] = {x = 0.59, y = 0.83},
        ["Cenarion Hold"] = {x = 0.50, y = 0.36},
        ["The Swarming Pillar"] = {x = 0.51, y = 0.47},
    },
    ["Stonetalon Mountains"] = {
        ["Webwinder Path"] = {x = 0.64, y = 0.84},
        ["Camp Aparaje"] = {x = 0.78, y = 0.93},
        ["Grimtotem Post"] = {x = 0.76, y = 0.87},
        ["Sishir Canyon"] = {x = 0.54, y = 0.75},
        ["Windshear Crag"] = {x = 0.68, y = 0.50},
        ["Sun Rock Retreat"] = {x = 0.47, y = 0.61},
        ["Mirkfallon Lake"] = {x = 0.49, y = 0.40},
        ["Stonetalon Peak"] = {x = 0.37, y = 0.13},
        ["The Charred Vale"] = {x = 0.32, y = 0.67},
    },
    ["Tanaris"] = {
        ["Sandsorrow Watch"] = {x = 0.40, y = 0.28},
        ["Gadgetzan"] = {x = 0.51, y = 0.28},
        ["Zul'Farrak"] = {x = 0.38, y = 0.14},
        ["Waterspring Field"] = {x = 0.60, y = 0.38},
        ["Steamwheedle Port"] = {x = 0.66, y = 0.22},
        ["Noonshade Ruins"] = {x = 0.60, y = 0.26},
        ["Zalashji's Den"] = {x = 0.68, y = 0.33},
        ["Lost Rigger Cove"] = {x = 0.72, y = 0.47},
        ["Southbreak Shore"] = {x = 0.63, y = 0.59},
        ["Caverns of Time"] = {x = 0.64, y = 0.49},
        ["Broken Pillar"] = {x = 0.52, y = 0.45},
        ["Abyssal Sands"] = {x = 0.44, y = 0.41},
        ["The Noxious Lair"] = {x = 0.35, y = 0.47},
        ["Thistleshrub Valley"] = {x = 0.30, y = 0.65},
        ["Valley of the Watchers"] = {x = 0.36, y = 0.80},
        ["Southmoon Ruins"] = {x = 0.39, y = 0.70},
        ["Dunemaul Compound"] = {x = 0.41, y = 0.55},
        ["Eastmoon Ruins"] = {x = 0.47, y = 0.65},
        ["The Gaping Chasm"] = {x = 0.54, y = 0.69},
        ["Land's End Beach"] = {x = 0.55, y = 0.94},
    },
    ["Teldrassil"] = {
        ["Rut'theran Village"] = {x = 0.56, y = 0.91},
        ["Lake Al'Ameth"] = {x = 0.56, y = 0.68},
        ["Starbreeze Village"] = {x = 0.65, y = 0.58},
        ["Dolanaar"] = {x = 0.56, y = 0.57},
        ["Wellspring River"] = {x = 0.42, y = 0.34},
        ["The Oracle Glade"] = {x = 0.37, y = 0.32},
        ["Ban'ethil Hollow"] = {x = 0.45, y = 0.54},
        ["Pools of Arlithrien"] = {x = 0.40, y = 0.65},
        ["Gnarlpine Hold"] = {x = 0.43, y = 0.78},
        ["Darnassus"] = {x = 0.28, y = 0.57},
        ["Shadowglen"] = {x = 0.60, y = 0.41},
    },
    ["The Barrens"] = {
        ["Razorfen Kraul"] = {x = 0.41, y = 0.88},
        ["Razorfen Downs"] = {x = 0.47, y = 0.91},
        ["Backthorn Ridge"] = {x = 0.43, y = 0.80},
        ["Field of Giants"] = {x = 0.44, y = 0.70},
        ["Bael Modan"] = {x = 0.48, y = 0.84},
        ["Camp Taurajo"] = {x = 0.46, y = 0.60},
        ["Agama'gor"] = {x = 0.46, y = 0.51},
        ["Bramblescar"] = {x = 0.51, y = 0.56},
        ["Northwatch Hold"] = {x = 0.60, y = 0.55},
        ["The Merchant Coast"] = {x = 0.64, y = 0.44},
        ["The Stagnant Oasis"] = {x = 0.55, y = 0.42},
        ["Raptor Grounds"] = {x = 0.57, y = 0.52},
        ["Lushwater Oasis"] = {x = 0.46, y = 0.37},
        ["The Crossroads"] = {x = 0.51, y = 0.28},
        ["Honor's Stand"] = {x = 0.38, y = 0.27},
        ["The Forgotten Pools"] = {x = 0.45, y = 0.23},
        ["Dreamist Peak"] = {x = 0.48, y = 0.18},
        ["The Dry Hills"] = {x = 0.39, y = 0.16},
        ["The Sludge Fen"] = {x = 0.56, y = 0.09},
        ["Boulder Lode Mine"] = {x = 0.62, y = 0.04},
        ["Grol'dom Farm"] = {x = 0.56, y = 0.19},
        ["Far Watch Post"] = {x = 0.61, y = 0.22},
        ["Thorn Hill"] = {x = 0.58, y = 0.28},
        ["Ratchet"] = {x = 0.63, y = 0.37},
    },
    ["The Exodar"] = {
        ["The Exodar"] = {x = 0.50, y = 0.50},
    },
    ["Thousand Needles"] = {
        ["The Screeching Canyon"] = {x = 0.31, y = 0.46},
        ["Darkcloud Pinnacle"] = {x = 0.35, y = 0.35},
        ["White Reach Post"] = {x = 0.15, y = 0.23},
        ["Highperch"] = {x = 0.11, y = 0.36},
        ["The Great Lift"] = {x = 0.29, y = 0.25},
        ["Freewind Post"] = {x = 0.46, y = 0.51},
        ["Splithoof Crag"] = {x = 0.48, y = 0.41},
        ["Shimmering Flats"] = {x = 0.79, y = 0.73},
    },
    ["Thunder Bluff"] = {
        ["Thunder Bluff"] = {x = 0.50, y = 0.50},
    },
    ["Un'Goro Crater"] = {
        ["Marshal's Refuge"] = {x = 0.53, y = 0.25},
        ["Golakka Hot Springs"] = {x = 0.34, y = 0.54},
        ["Terror Run"] = {x = 0.42, y = 0.72},
        ["The Slithering Scar"] = {x = 0.52, y = 0.80},
        ["The Marshlands"] = {x = 0.70, y = 0.62},
        ["Ironstone Plateau"] = {x = 0.80, y = 0.32},
        ["Fire Plume Ridge"] = {x = 0.51, y = 0.49},
    },
    ["Winterspring"] = {
        ["Frostsaber Rock"] = {x = 0.50, y = 0.14},
        ["The Hidden Grove"] = {x = 0.64, y = 0.17},
        ["Winterfall Village"] = {x = 0.68, y = 0.37},
        ["Everlook"] = {x = 0.61, y = 0.38},
        ["Starfall Village"] = {x = 0.50, y = 0.29},
        ["Lake Kel'Theril"] = {x = 0.53, y = 0.43},
        ["Timbermaw Post"] = {x = 0.40, y = 0.43},
        ["Frostfire Hot Springs"] = {x = 0.37, y = 0.37},
        ["Mazthoril"] = {x = 0.59, y = 0.51},
        ["Ice Thistle Hills"] = {x = 0.68, y = 0.46},
        ["Owl Wing Thicket"] = {x = 0.66, y = 0.61},
        ["Frostwhisper Gorge"] = {x = 0.62, y = 0.69},
        ["Darkwhisper Gorge"] = {x = 0.58, y = 0.83},
    },

    -- ==================== EASTERN KINGDOMS ====================
    ["Alterac Mountains"] = {
        ["Dalaran"] = {x = 0.17, y = 0.66},
        ["Dandred's Fold"] = {x = 0.41, y = 0.20},
        ["The Uplands"] = {x = 0.55, y = 0.26},
        ["Strahnbrad"] = {x = 0.62, y = 0.45},
        ["Chillwind Point"] = {x = 0.81, y = 0.65},
        ["Sofera's Naze"] = {x = 0.57, y = 0.66},
        ["Gallows' Corner"] = {x = 0.46, y = 0.59},
        ["Ruins of Alterac"] = {x = 0.41, y = 0.50},
        ["Crushridge Hold"] = {x = 0.49, y = 0.40},
        ["Growless Cave"] = {x = 0.40, y = 0.70},
        ["Lordamere Internment Camp"] = {x = 0.20, y = 0.86},
        ["Gavin's Naze"] = {x = 0.32, y = 0.83},
        ["The Headland"] = {x = 0.39, y = 0.87},
        ["Corrahn's Dagger"] = {x = 0.48, y = 0.83},
    },
    ["Arathi Highlands"] = {
        ["Thoradin's Wall"] = {x = 0.20, y = 0.43},
        ["Circle of West Binding"] = {x = 0.25, y = 0.29},
        ["Stromgarde Keep"] = {x = 0.23, y = 0.63},
        ["Circle of Inner Binding"] = {x = 0.37, y = 0.59},
        ["Faldir's Cove"] = {x = 0.36, y = 0.80},
        ["Bouldfist Hall"] = {x = 0.54, y = 0.74},
        ["Thandol Span"] = {x = 0.44, y = 0.88},
        ["Boulderfist Outpost"] = {x = 0.35, y = 0.44},
        ["Northfold Manor"] = {x = 0.32, y = 0.28},
        ["Refuge Pointe"] = {x = 0.46, y = 0.46},
        ["Circle of Outer Binding"] = {x = 0.52, y = 0.52},
        ["Dabyrie's Farmstead"] = {x = 0.55, y = 0.40},
        ["Circle of East Binding"] = {x = 0.67, y = 0.31},
        ["Hammerfall"] = {x = 0.74, y = 0.35},
        ["Witherbark Village"] = {x = 0.67, y = 0.68},
        ["Go'Shek Farm"] = {x = 0.62, y = 0.57},
    },
    ["Badlands"] = {
        ["Kargath"] = {x = 0.07, y = 0.47},
        ["The Dustbowl"] = {x = 0.29, y = 0.50},
        ["Angor Fortress"] = {x = 0.44, y = 0.33},
        ["Uldaman"] = {x = 0.46, y = 0.13},
        ["Hammertoe's Digsite"] = {x = 0.53, y = 0.35},
        ["Camp Kosh"] = {x = 0.66, y = 0.24},
        ["Dustwind Gulch"] = {x = 0.65, y = 0.45},
        ["Lethlor Ravine"] = {x = 0.81, y = 0.52},
        ["Camp Boff"] = {x = 0.61, y = 0.71},
        ["Agmond's End"] = {x = 0.47, y = 0.72},
        ["Valley of Fangs"] = {x = 0.48, y = 0.55},
        ["Mirage Flats"] = {x = 0.27, y = 0.69},
        ["Dustbelch Grotto"] = {x = 0.10, y = 0.84},
        ["Apocryphan's Rest"] = {x = 0.15, y = 0.60},
    },
    ["Blasted Lands"] = {
        ["Dreadmaul Hold"] = {x = 0.44, y = 0.15},
        ["Nethergarde Keep"] = {x = 0.64, y = 0.20},
        ["Rise of the Defiler"] = {x = 0.49, y = 0.29},
        ["Garrison Armory"] = {x = 0.58, y = 0.16},
        ["The Dark Portal"] = {x = 0.58, y = 0.56},
        ["Dreadmaul Post"] = {x = 0.48, y = 0.44},
        ["The Tainted Scar"] = {x = 0.38, y = 0.60},
        ["The Altar of Storms"] = {x = 0.39, y = 0.33},
        ["Serpent's Coil"] = {x = 0.63, y = 0.33},
    },
    ["Burning Steppes"] = {
        ["Ruins of Thaurissan"] = {x = 0.65, y = 0.35},
        ["Dreadmaul Rock"] = {x = 0.81, y = 0.40},
        ["Terror Wing Path"] = {x = 0.89, y = 0.26},
        ["Pillar of Ashe"] = {x = 0.49, y = 0.56},
        ["Morgan's Vigil"] = {x = 0.84, y = 0.62},
        ["Blackrock Pass"] = {x = 0.73, y = 0.62},
        ["Blackrock Stronghold"] = {x = 0.41, y = 0.37},
        ["Blackrock Mountain"] = {x = 0.28, y = 0.41},
        ["Altar of Storms"] = {x = 0.17, y = 0.29},
        ["Draco'dar"] = {x = 0.25, y = 0.62},
    },
    ["Deadwind Pass"] = {
        ["Deadman's Crossing"] = {x = 0.50, y = 0.45}, -- *
        ["The Vice"] = {x = 0.59, y = 0.64},
        ["Karazhan"] = {x = 0.46, y = 0.73}, -- *
    },
    ["Dun Morogh"] = {
        ["Helm's Bed Lake"] = {x = 0.77, y = 0.56},
        ["South Gate Outpost"] = {x = 0.85, y = 0.50},
        ["North Gate Outpost"] = {x = 0.83, y = 0.40},
        ["Amberstill Ranch"] = {x = 0.63, y = 0.52},
        ["Gol'Bolar Quarry"] = {x = 0.70, y = 0.58},
        ["The Tundrid Hills"] = {x = 0.61, y = 0.57},
        ["Misty Pine Refuge"] = {x = 0.58, y = 0.44},
        ["Ironforge"] = {x = 0.52, y = 0.37},
        ["Kharanos"] = {x = 0.47, y = 0.52},
        ["The Grizzled Den"] = {x = 0.41, y = 0.57},
        ["Chill Breeze Valley"] = {x = 0.34, y = 0.50},
        ["Brewnall Village"] = {x = 0.30, y = 0.45},
        ["Gnomeregan"] = {x = 0.26, y = 0.41},
        ["Iceflow Lake"] = {x = 0.35, y = 0.40},
        ["Shimmer Ridge"] = {x = 0.42, y = 0.37},
        ["Frostmane Hold"] = {x = 0.26, y = 0.52},
        ["Coldridge Valley"] = {x = 0.27, y = 0.73},
    },
    ["Duskwood"] = {
        ["The Darkened Bank"] = {x = 0.55, y = 0.16},
        ["The Hushed Bank"] = {x = 0.10, y = 0.38},
        ["Raven Hill"] = {x = 0.20, y = 0.58},
        ["Raven Hill Cemetery"] = {x = 0.21, y = 0.43},
        ["Addle's Stead"] = {x = 0.22, y = 0.69},
        ["Vul'Gol Ogre Mound"] = {x = 0.36, y = 0.73},
        ["The Yorgen Farmstead"] = {x = 0.51, y = 0.74},
        ["The Rotting Orchard"] = {x = 0.64, y = 0.74},
        ["Tranquil Gardens Cemetery"] = {x = 0.80, y = 0.69},
        ["Manor Mistmantle"] = {x = 0.75, y = 0.36},
        ["Darkshire"] = {x = 0.75, y = 0.47},
        ["Brightwood Grove"] = {x = 0.64, y = 0.43},
        ["Twilight Grove"] = {x = 0.48, y = 0.43},
    },
    ["Eastern Plaguelands"] = {
        ["Corin's Crossing"] = {x = 0.60, y = 0.67}, -- *
        ["Pestilent Scar"] = {x = 0.74, y = 0.64}, -- *
        ["Light's Hope Chapel"] = {x = 0.82, y = 0.60}, -- *
        ["The Marris Stead"] = {x = 0.26, y = 0.75},
        ["The Undercroft"] = {x = 0.28, y = 0.86},
        ["Darrowshire"] = {x = 0.39, y = 0.89},
        ["Crown Guard Tower"] = {x = 0.38, y = 0.73},
        ["The Fungal Vale"] = {x = 0.40, y = 0.53},
        ["Plagewood"] = {x = 0.34, y = 0.36},
        ["Terrodale"] = {x = 0.16, y = 0.32},
        ["Stratholme"] = {x = 0.31, y = 0.14},
        ["Quel'Lithien Lodge"] = {x = 0.53, y = 0.19},
        ["Northpass Tower"] = {x = 0.57, y = 0.31},
        ["Blackwood Lake"] = {x = 0.53, y = 0.50},
        ["The Infectis Scar"] = {x = 0.54, y = 0.69},
        ["Lake Mereldar"] = {x = 0.62, y = 0.80},
        ["Tyr's Hand"] = {x = 0.85, y = 0.84},
        ["The Noxious Glade"] = {x = 0.84, y = 0.42},
        ["Eastwall Tower"] = {x = 0.68, y = 0.47},
        ["Zul'Mashar"] = {x = 0.72, y = 0.16},
        ["Northdale"] = {x = 0.72, y = 0.32},
    },
    ["Elwynn Forest"] = {
        ["Stonecairn Lake"] = {x = 0.74, y = 0.51},
        ["Eastvale Logging Camp"] = {x = 0.83, y = 0.67},
        ["Ridgepoint Tower"] = {x = 0.85, y = 0.81},
        ["Brackwell Pumpkin Patch"] = {x = 0.68, y = 0.78},
        ["Tower of Azora"] = {x = 0.64, y = 0.65},
        ["Stormwind City"] = {x = 0.28, y = 0.42},
        ["Crystal Lake"] = {x = 0.53, y = 0.66},
        ["Jerod's Landing"] = {x = 0.49, y = 0.85},
        ["Fargodeep Mine"] = {x = 0.38, y = 0.82},
        ["Goldshire"] = {x = 0.43, y = 0.65},
        ["Northshire Valley"] = {x = 0.50, y = 0.45},
        ["Westbrook Garrison"] = {x = 0.25, y = 0.76},
    },
    ["Eversong Woods"] = {
        ["Sunstrider Isle"] = {x = 0.34, y = 0.24},
        ["Dawning Lane"] = {x = 0.44, y = 0.42},
        ["West Sanctum"] = {x = 0.35, y = 0.59},
        ["Tranquil Shore"] = {x = 0.29, y = 0.59},
        ["Sunsail Anchorage"] = {x = 0.33, y = 0.70},
        ["Goldenbough Pass"] = {x = 0.33, y = 0.77},
        ["Golden Strand"] = {x = 0.23, y = 0.78},
        ["The Scorched Grove"] = {x = 0.36, y = 0.86},
        ["The Dead Scar"] = {x = 0.47, y = 0.87},
        ["Runestone Shan'dor"] = {x = 0.55, y = 0.82},
        ["Zeb'watha"] = {x = 0.62, y = 0.79},
        ["Lake Elrendar"] = {x = 0.87, y = 0.80},
        ["Tor'Watha"] = {x = 0.73, y = 0.76},
        ["Duskwither Grounds"] = {x = 0.69, y = 0.53},
        ["The Living Wood"] = {x = 0.57, y = 0.71},
        ["The East Sanctum"] = {x = 0.51, y = 0.71},
        ["Fairbreeze Village"] = {x = 0.44, y = 0.71},
        ["Saltheril's Haven"] = {x = 0.38, y = 0.72},
        ["North Sanctum"] = {x = 0.44, y = 0.54},
        ["Stillwhisper Pond"] = {x = 0.55, y = 0.55},
        ["Farstrider Retreat"] = {x = 0.60, y = 0.61},
        ["Elrendar Falls"] = {x = 0.64, y = 0.72},
        ["Thuron's Livery"] = {x = 0.61, y = 0.54},
        ["Azurebreeze Coast"] = {x = 0.73, y = 0.48},
        ["Silvermoon City"] = {x = 0.58, y = 0.39},
    },
    ["Ghostlands"] = {
        ["Goldenmist Village"] = {x = 0.27, y = 0.15},
        ["Suncrown Village"] = {x = 0.62, y = 0.13},
        ["Dawnstar Spire"] = {x = 0.79, y = 0.19},
        ["Amani Pass"] = {x = 0.70, y = 0.56}, -- *
        ["Thalassian Pass"] = {x = 0.48, y = 0.85}, -- *
        ["Tranquillien"] = {x = 0.46, y = 0.32},
        ["Elrendar Crossing"] = {x = 0.49, y = 0.13},
        ["Underlight Mines"] = {x = 0.28, y = 0.49},
        ["Windrunner Spire"] = {x = 0.14, y = 57},
        ["Windrunner Village"]= {x = 0.17, y = 0.42},
        ["Deatholme"] = {x = 0.33, y = 0.81},
        ["Andilien Estate"] = {x = 0.47, y = 0.55},
        ["Sanctum of the Moon"] = {x = 0.34, y = 0.34},
        ["Sanctum of the Sun"] = {x = 0.56, y = 0.50},
        ["Zeb'Nowa"] = {x = 0.67, y = 0.62},
        ["Farstrider Enclave"] = {x = 0.72, y = 0.35},
    },
    ["Hillsbrad Foothills"] = {
        ["Tarren Mill"] = {x = 0.61, y = 0.23},
        ["Durnholde Keep"] = {x = 0.77, y = 0.40},
        ["Southpoint Tower"] = {x = 0.20, y = 0.49},
        ["Western Strand"] = {x = 0.33, y = 0.66},
        ["Purgation Isle"] = {x = 0.16, y = 0.81},
        ["Azurelode Mine"] = {x = 0.27, y = 0.58},
        ["Hillsbrad Fields"] = {x = 0.34, y = 0.42},
        ["Darrow Hill"] = {x = 0.47, y = 0.34},
        ["Southshore"] = {x = 0.51, y = 0.57},
        ["Nethander Stead"] = {x = 0.64, y = 0.60},
        ["Eastern Strand"] = {x = 0.63, y = 0.74},
        ["Dun Garok"] = {x = 0.72, y = 0.71},
    },
    ["Ironforge"] = {
        ["Ironforge"] = {x = 0.50, y = 0.50},
    },
    ["Isle of Quel'Danas"] = {
        ["Isle of Quel'Danas"] = {x = 0.52, y = 0.55},
    },
    ["Loch Modan"] = {
        ["Silver Steam Mine"] = {x = 0.32, y = 0.19},
        ["Algaz Station"] = {x = 0.22, y = 0.17},
        ["Stonewrought Dam"] = {x = 0.48, y = 0.14},
        ["The Loch"] = {x = 0.49, y = 0.32},
        ["Mo'grosh Stronghold"] = {x = 0.70, y = 0.23},
        ["Farstrider Lodge"] = {x = 0.82, y = 0.62},
        ["Ironband's Excavation Site"] = {x = 0.68, y = 0.64},
        ["Grizzlepaw Ridge"] = {x = 0.41, y = 0.66},
        ["Stonesplinter Valley"] = {x = 0.35, y = 0.76},
        ["Thelsamar"] = {x = 0.35, y = 0.47},
        ["Valley of Kings"] = {x = 0.22, y = 0.72},
    },
    ["Redridge Mountains"] = {
        ["Render's Valley"] = {x = 0.74, y = 0.79},
        ["Stonewatch Falls"] = {x = 0.74, y = 0.66},
        ["Tower of Ilgalar"] = {x = 0.80, y = 0.49},
        ["Stonewatch"] = {x = 0.65, y = 0.57},
        ["Alther's Mill"] = {x = 0.53, y = 0.44},
        ["Render's Camp"] = {x = 0.38, y = 0.14},
        ["Redridge Canyons"] = {x = 0.32, y = 0.24},
        ["Lakeshire"] = {x = 0.28, y = 0.48},
        ["Lake Everstill"] = {x = 0.44, y = 0.58},
        ["Lakeridge Highway"] = {x = 0.34, y = 0.76},
        ["Three Corners"] = {x = 0.16, y = 0.72},
    },
    ["Searing Gorge"] = {
        ["Firewatch Ridge"] = {x = 0.29, y = 0.34},
        ["Blackchar Cave"] = {x = 0.26, y = 0.76},
        ["The Cauldron"] = {x = 0.52, y = 0.49},
        ["Dustfire Valley"] = {x = 0.74, y = 0.26},
        ["Grimesilt Dig Site"] = {x = 0.64, y = 0.63},
        ["Tanner Camp"] = {x = 0.65, y = 0.75},
        ["Blackrock Mountain"] = {x = 0.34, y = 0.83},
    },
    ["Silvermoon City"] = {
        ["Silvermoon City"] = {x = 0.50, y = 0.50},
    },
    ["Silverpine Forest"] = {
        ["Fenris Isle"] = {x = 0.66, y = 0.27},
        ["The Shining Strand"] = {x = 0.55, y = 0.21},
        ["Malden's Orchard"] = {x = 0.54, y = 0.13},
        ["The Dead Field"] = {x = 0.44, y = 0.21},
        ["The Skittering Dark"] = {x = 0.36, y = 0.14},
        ["North Tide's Hollow"] = {x = 0.41, y = 0.28},
        ["The Sepulcher"] = {x = 0.44, y = 0.41},
        ["The Decrepit Ferry"] = {x = 0.57, y = 0.33},
        ["Olsen's Farthing"] = {x = 0.47, y = 0.55},
        ["Deep Elem Mine"] = {x = 0.56, y = 0.49},
        ["Ambermill"] = {x = 0.63, y = 0.63},
        ["Shadowfang Keep"] = {x = 0.46, y = 0.68},
        ["Pyrewood Village"] = {x = 0.47, y = 0.76},
        ["Beren's Peril"] = {x = 0.61, y = 0.76},
        ["The Greymane Wall"] = {x = 0.47, y = 0.85},
    },
    ["Stormwind City"] = {
        ["Stormwind City"] = {x = 0.50, y = 0.50},
    },
    ["Stranglethorn Vale"] = {
        ["Zul'Gurub"] = {x = 0.60, y = 0.16},
        ["Kurzen's Compound"] = {x = 0.45, y = 0.09},
        ["Ruins of Zul'Kundra"] = {x = 0.25, y = 0.12},
        ["Booty Bay"] = {x = 0.27, y = 0.77},
        ["Grom'gol Base Camp"] = {x = 0.32, y = 0.28},
        ["Nessingwary's Expedition"] = {x = 0.34, y = 0.14},
        ["The Savage Coast"] = {x = 0.22, y = 0.17},
        ["The Vile Reef"] = {x = 0.26, y = 0.28},
        ["Bal'lal Ruins"] = {x = 0.30, y = 0.20},
        ["Kal'ai Ruins"] = {x = 0.26, y = 0.22},
        ["Mizjah Ruins"] = {x = 0.37, y = 0.30},
        ["Lake Nazferiti"] = {x = 0.42, y = 0.19},
        ["Venture Co. Base Camp"] = {x = 0.45, y = 0.20},
        ["Mosh'Ogg Ogre Mound"] = {x = 0.48, y = 0.29},
        ["Ziata'jai Ruins"] = {x = 0.43, y = 0.34},
        ["Ruins of Zul'Mamwe"] = {x = 0.47, y = 0.42},
        ["Gurubashi Arena"] = {x = 0.31, y = 0.46},
        ["Ruins of Jubuwal"] = {x = 0.36, y = 0.53},
        ["Crystalvein Mine"] = {x = 0.41, y = 0.50},
        ["Bloodsail Compound"] = {x = 0.24, y = 0.52},
        ["Nek'mani Wellspring"] = {x = 0.28, y = 0.63},
        ["Mistvale Valley"] = {x = 0.34, y = 0.63},
        ["Wild Shore"] = {x = 0.32, y = 0.78},
        ["Jaguero Isle"] = {x = 0.39, y = 0.82},
    },
    ["Swamp of Sorrows"] = {
        ["Stonard"] = {x = 0.45, y = 0.53}, -- *
        ["Splinterspear Junction"] = {x = 0.20, y = 0.50}, -- *
        ["The Shifting Mire"] = {x = 0.44, y = 0.37},
        ["Itharius's Cave"] = {x = 0.14, y = 0.60},
        ["Misty Valley"] = {x = 0.14, y = 0.36},
        ["The Harborage"] = {x = 0.26, y = 0.32},
        ["Stagalbog"] = {x = 0.72, y = 0.77},
        ["Misty Reed Strand"] = {x = 0.85, y = 0.84},
        ["Sorrowmurk"] = {x = 0.85, y = 0.50},
        ["Pool of Tears"] = {x = 0.69, y = 0.53},
        ["Fallow Sanctuary"] = {x = 0.63, y = 0.22},
    },
    ["The Hinterlands"] = {
        ["The Altar of Zul"] = {x = 0.48, y = 0.66},
        ["Jintha'Alor"] = {x = 0.62, y = 0.71},
        ["Shaol'Watha"] = {x = 0.72, y = 0.51},
        ["Aerie Peak"] = {x = 0.14, y = 0.49},
        ["Revantusk Village"] = {x = 0.78, y = 0.76},
        ["Skulk Rock"] = {x = 0.58, y = 0.42},
        ["Seradane"] = {x = 0.63, y = 0.26},
        ["Agol'watha"] = {x = 0.46, y = 0.41},
        ["The Creeping Ruin"] = {x = 0.50, y = 0.52},
        ["Valorwind Lake"] = {x = 0.40, y = 0.58},
        ["Shadra'Alor"] = {x = 0.34, y = 0.71},
        ["Quel'Danil Lodge"] = {x = 0.33, y = 0.47},
        ["Plaguemist Ravine"] = {x = 0.24, y = 0.38},
        ["Hiri'watha"] = {x = 0.32, y = 0.58},
    },
    ["Tirisfal Glades"] = {
        ["Brill"] = {x = 0.59, y = 0.52},
        ["Garren's Haunt"] = {x = 0.59, y = 0.37},
        ["Brightwater Lake"] = {x = 0.68, y = 0.47},
        ["Scarlet Watch Post"] = {x = 0.78, y = 0.37},
        ["Scarlet Monastery"] = {x = 0.84, y = 0.35},
        ["Venomweb Vale"] = {x = 0.86, y = 0.45},
        ["Crusader Outpost"] = {x = 0.79, y = 0.55},
        ["Balnir Farmstead"] = {x = 0.75, y = 0.63},
        ["The Bulwark"] = {x = 0.83, y = 0.70},
        ["Cold Hearth Manor"] = {x = 0.54, y = 0.57},
        ["Stillwater Pond"] = {x = 0.50, y = 0.52},
        ["Agamand Mills"] = {x = 0.48, y = 0.36},
        ["Solliden Farmstead"] = {x = 0.36, y = 0.50},
        ["Deathknell"] = {x = 0.33, y = 0.63},
        ["Nightmare Vale"] = {x = 0.44, y = 0.63},
        ["Undercity"] = {x = 0.62, y = 0.71},
    },
    ["Undercity"] = {
        ["Undercity"] = {x = 0.66, y = 0.44},
    },
    ["Western Plaguelands"] = {
        ["Darrowmere Lake"] = {x = 0.60, y = 0.70},
        ["Caer Darrow"] = {x = 0.69, y = 0.75},
        ["Sorrow Hill"] = {x = 0.50, y = 0.78},
        ["Felstone Field"] = {x = 0.38, y = 0.56},
        ["Ruins of Andorhal"] = {x = 0.43, y = 0.68},
        ["The Bulwark"] = {x = 0.31, y = 0.58},
        ["Dalson's Tears"] = {x = 0.47, y = 0.52},
        ["Northridge Lumber Camp"] = {x = 0.47, y = 0.36},
        ["Hearthglen"] = {x = 0.45, y = 0.16},
        ["Gahrron's Withering"] = {x = 0.63, y = 0.58},
        ["The Writhing Haunt"] = {x = 0.54, y = 0.61},
        ["Thondroril River"] = {x = 0.69, y = 0.34},
        ["The Weeping Cave"] = {x = 0.66, y = 0.43},
    },
    ["Westfall"] = {
        ["The Dust Plains"] = {x = 0.62, y = 0.71},
        ["The Dagger Hills"] = {x = 0.46, y = 0.79},
        ["Westfall Lighthouse"] = {x = 0.31, y = 0.85},
        ["Demont's Place"] = {x = 0.33, y = 0.69},
        ["Sentinel Hill"] = {x = 0.54, y = 0.50},
        ["Moonbrook"] = {x = 0.45, y = 0.69},
        ["The Dead Acre"] = {x = 0.62, y = 0.57},
        ["Alexston Farmstead"] = {x = 0.37, y = 0.51},
        ["Gold Coast Quarry"] = {x = 0.32, y = 0.42},
        ["Jangolode Mine"] = {x = 0.45, y = 0.23},
        ["Furlbrow's Pumpkin Farm"] = {x = 0.52, y = 0.20},
        ["Saldean's Farm"] = {x = 0.55, y = 0.33},
        ["The Molsen Farm"] = {x = 0.44, y = 0.37},
    },
    ["Wetlands"] = {
        ["Menethil Harbor"] = {x = 0.10, y = 0.58},
        ["Dun Modr"] = {x = 0.48, y = 0.17},
        ["Ironbear's Tomb"] = {x = 0.44, y = 0.28},
        ["Saltspray Glen"] = {x = 0.32, y = 0.22},
        ["Sundown Marsh"] = {x = 0.24, y = 0.29},
        ["Bluegill Marsh"] = {x = 0.19, y = 0.39},
        ["Black Channel Marsh"] = {x = 0.19, y = 0.49},
        ["Whelgar's Excavation"] = {x = 0.36, y = 0.48},
        ["Angerfang Encampment"] = {x = 0.47, y = 0.46},
        ["The Green Belt"] = {x = 0.55, y = 0.37},
        ["Direforge Hill"] = {x = 0.61, y = 0.27},
        ["Raptor Ridge"] = {x = 0.70, y = 0.36},
        ["Grim Batol"] = {x = 0.77, y = 0.74},
        ["Dun Algaz"] = {x = 0.55, y = 0.70},
        ["Mosshide Fen"] = {x = 0.62, y = 0.57},
    },

    -- ==================== OUTLAND ====================
    ["Blade's Edge Mountains"] = {
        ["Jagged Ridge"] = {x = 0.52, y = 0.72},
        ["Thunderlord Stronghold"] = {x = 0.52, y = 0.58},
        ["Circle of Blood"] = {x = 0.55, y = 0.42},
        ["Ruuan Weald"] = {x = 0.61, y = 0.38},
        ["Veil Ruuan"] = {x = 0.65, y = 0.31},
        ["Gruul's Lair"] = {x = 0.67, y = 0.23},
        ["Crystal Spine"] = {x = 0.68, y = 0.11},
        ["Bash'ir Landing"] = {x = 0.52, y = 0.16},
        ["Grishnath"] = {x = 0.40, y = 0.22},
        ["Raven's Wood"] = {x = 0.32, y = 0.29},
        ["Forge Camp: Wrath"] = {x = 0.34, y = 0.42},
        ["Ogri'la"] = {x = 0.29, y = 0.57},
        ["Forge Camp: Terror"] = {x = 0.29, y = 0.82},
        ["Veil Lashh"] = {x = 0.38, y = 0.79},
        ["Bloodmaul Outpost"] = {x = 0.46, y = 0.76},
        ["Sylvanaar"] = {x = 0.37, y = 0.65},
        ["Bladespire Hold"] = {x = 0.43, y = 0.52},
        ["Toshley's Station"] = {x = 0.61, y = 0.72},
        ["Death's Door"] = {x = 0.64, y = 0.64},
        ["Vekhaar Stand"] = {x = 0.75, y = 0.73},
        ["Mok'Nathal Village"] = {x = 0.75, y = 0.62},
        ["Bladed Gulch"] = {x = 0.71, y = 0.32},
        ["Forge Camp: Anger"] = {x = 0.74, y = 0.42},
        ["Skald"] = {x = 0.75, y = 0.20},
        ["Broken Wilds"] = {x = 0.81, y = 0.28},
    },
    ["Hellfire Peninsula"] = {
        ["Honor Hold"] = {x = 0.56, y = 0.61},
        ["Thrallmar"] = {x = 0.56, y = 0.38},
        ["The Dark Portal"] = {x = 0.86, y = 0.50},
        ["The Legion Front"] = {x = 0.69, y = 0.53},
        ["Zeth'Gor"] = {x = 0.67, y = 0.75},
        ["Expedition Armory"] = {x = 0.55, y = 0.83},
        ["Gor'gaz Outpost"] = {x = 0.45, y = 0.74},
        ["Forge Camp: Megeddon"] = {x = 0.65, y = 0.31},
        ["Throne of Kil'jaeden"] = {x = 0.62, y = 0.19},
        ["Pools of Aggonar"] = {x = 0.41, y = 0.34},
        ["Hellfire Citadel"] = {x = 0.47, y = 0.50},
        ["Mag'har Post"] = {x = 0.32, y = 0.28},
        ["Temple of Telhamat"] = {x = 0.23, y = 0.40},
        ["Fallen Sky Ridge"] = {x = 0.14, y = 0.41},
        ["Ruins of Sha'naar"] = {x = 0.14, y = 0.60},
        ["Falcon Watch"] = {x = 0.28, y = 0.61},
        ["Void Ridge"] = {x = 0.77, y = 0.68},
        ["Den of Haal'esh"] = {x = 0.28, y = 0.80},
    },
    ["Nagrand"] = {
        ["Burning Blade Ruins"] = {x = 0.75, y = 0.66},
        ["Kil'sorrow Fortress"] = {x = 0.69, y = 0.80},
        ["Oshu'gun"] = {x = 0.36, y = 0.72},
        ["Forge Camp: Hate"] = {x = 0.27, y = 0.37},
        ["Forge Camp: Fear"] = {x = 0.21, y = 0.49},
        ["Warmaul Hill"] = {x = 0.28, y = 0.23},
        ["Halaa"] = {x = 0.43, y = 0.44},
        ["Sunspring Post"] = {x = 0.32, y = 0.43},
        ["Laughing Skull Ruins"] = {x = 0.47, y = 0.22},
        ["Garadar"] = {x = 0.56, y = 0.36},
        ["Throne of the Elements"] = {x = 0.61, y = 0.20},
        ["Telaar"] = {x = 0.52, y = 0.71},
        ["Nesingwary Safari"] = {x = 0.72, y = 0.37},
        ["Windyreed Village"] = {x = 0.74, y = 0.52},
        ["The Ring of Trials"] = {x = 0.66, y = 0.57},
        ["Clan Watch"] = {x = 0.62, y = 0.64},
        ["Southwind Cleft"] = {x = 0.50, y = 0.57},
        ["Zangar Ridge"] = {x = 0.50, y = 0.57},
    },
    ["Netherstorm"] = {
        ["Gyro-Plank Bridge"] = {x = 0.26, y = 0.55},
        ["Ruins of Enkaat"] = {x = 0.34, y = 0.56},
        ["Area 52"] = {x = 0.33, y = 0.65},
        ["Manaforge B'naar"] = {x = 0.24, y = 0.71},
        ["The Heap"] = {x = 0.32, y = 0.77},
        ["Arklon Ruins"] = {x = 0.40, y = 0.72},
        ["Manaforge Coruu"] = {x = 0.49, y = 0.83},
        ["Town Square"] = {x = 0.58, y = 0.87},
        ["Sunfury Hold"] = {x = 0.56, y = 0.79},
        ["Manaforge Duro"] = {x = 0.60, y = 0.66},
        ["Cosmowrench"] = {x = 0.65, y = 0.68},
        ["Eco-Dome Midreealm"] = {x = 0.45, y = 0.53},
        ["The Stormspire"] = {x = 0.44, y = 0.34},
        ["Manaforge Ara"] = {x = 0.26, y = 0.39},
        ["Forge Base: Oblivion"] = {x = 0.38, y = 0.26},
        ["Socrethar's Seat"] = {x = 0.30, y = 0.16},
        ["Eco-Dome Farfield"] = {x = 0.46, y = 0.11},
        ["Netherstone"] = {x = 0.49, y = 0.18},
        ["Ruins of Farahlon"] = {x = 0.54, y = 0.22},
        ["Manaforge Ultris"] = {x = 0.62, y = 0.40},
        ["Celstial Ridge"] = {x = 0.72, y = 0.40},
        ["Ethereum Staging Grounds"] = {x = 0.55, y = 0.43},
    },
    ["Shadowmoon Valley"] = {
        ["Legion Hold"] = {x = 0.23, y = 0.37},
        ["Shadowmoon Village"] = {x = 0.29, y = 0.28},
        ["Illidari Point"] = {x = 0.30, y = 0.51},
        ["Wildhammer Stronghold"] = {x = 0.36, y = 0.58},
        ["Eclipse Point"] = {x = 0.45, y = 0.66},
        ["Dragonmaw Fortress"] = {x = 0.67, y = 0.61},
        ["Netherwind Ledge"] = {x = 0.70, y = 0.84},
        ["The Black Temple"] = {x = 0.72, y = 0.44},
        ["Coilskar Point"] = {x = 0.28, y = 0.27},
        ["Altar of Sha'tar"] = {x = 0.61, y = 0.29},
        ["The Hand of Gul'dan"] = {x = 0.52, y = 0.44},
        ["Warden's Cage"] = {x = 0.59, y = 0.51},
        ["The Deathforge"] = {x = 0.40, y = 0.39},
    },
    ["Shattrath City"] = {
        ["Shattrath City"] = {x = 0.54, y = 0.44},
    },
    ["Terokkar Forest"] = {
        ["Cenarion Thicket"] = {x = 0.43, y = 0.22},
        ["Tuurem"] = {x = 0.54, y = 0.29},
        ["Razorthorn Shelf"] = {x = 0.57, y = 0.19},
        ['Firewing Point'] = {x = 0.73, y = 0.35},
        ["Bonechewer Ruins"] = {x = 0.66, y = 0.53},
        ["Raastok Glade"] = {x = 0.58, y = 0.41},
        ["Stonebreaker Hold"] = {x = 0.48, y = 0.43},
        ["Allerian Stronghold"] = {x = 0.57, y = 0.56},
        ["Skettis"] = {x = 0.67, y = 0.79},
        ["Ring of Observance"] = {x = 0.40, y = 0.66},
        ["Derelict Caravan"] = {x = 0.41, y = 0.78},
        ["Writhing Mound"] = {x = 0.50, y = 0.66},
        ["Carrion Hill"] = {x = 0.42, y = 0.52},
        ["Refuge Pointe"] = {x = 0.36, y = 0.50},
        ["Veil Rhaze"] = {x = 0.28, y = 0.62},
        ["Bleeding Hollow Ruins"] = {x = 0.21, y = 0.67},
        ["Auchenai Grounds"] = {x = 0.31, y = 0.76},
        ["Veil Skith"] = {x = 0.30, y = 0.42},
        ["Shadow Tomb"] = {x = 0.31, y = 0.53},
        ["Shattrath City"] = {x = 0.29, y = 0.24},
    },
    ["Zangarmarsh"] = {
        ["The Spawning Glen"] = {x = 0.15, y = 0.61},
        ["Sporeggar"] = {x = 0.18, y = 0.49},
        ["Marshlight Lake"] = {x = 0.22, y = 0.37},
        ["Ango'rosh Grounds"] = {x = 0.18, y = 0.21},
        ["Ango'rosh Stronghold"] = {x = 0.18, y = 0.07},
        ["Hewn Bog"] = {x = 0.33, y = 0.30},
        ["Quagg Ridge"] = {x = 0.29, y = 0.63},
        ["Feralfen Village"] = {x = 0.47, y = 0.62},
        ["Twin Spire Ruins"] = {x = 0.47, y = 0.50},
        ["Orebor Harborage"] = {x = 0.44, y = 0.27},
        ["Coilfang Reservoir"] = {x = 0.56, y = 0.40},
        ["The Dead Mire"] = {x = 0.82, y = 0.39},
        ["Telredor"] = {x = 0.68, y = 0.50},
        ["The Lagoon"] = {x = 0.58, y = 0.62},
        ["Cenarion Refuge"] = {x = 0.80, y = 0.64},
        ["Darkcrest Shore"] = {x = 0.70, y = 0.81},
        ["Umbrafen Village"] = {x = 0.83, y = 0.83},
    },
}

---------------------------------------
-- Get MapID from zone name
---------------------------------------
local function GetMapIDForZone(zoneName)
    if not zoneName then return nil end
    return ZoneMapIDs[zoneName]
end

---------------------------------------
-- Get coordinates for location name within a zone
---------------------------------------
local function GetLocationCoords(zoneName, locationName)
    if not zoneName or not locationName then return nil, nil end
    
    local zoneLocations = LocationMap[zoneName]
    if not zoneLocations then return nil, nil end
    
    local location = zoneLocations[locationName]
    if not location then return nil, nil end
    
    return location.x, location.y
end

---------------------------------------
-- Check if a position on the map has been discovered
-- Parameters:
--   mapID: number - The map ID to check (optional if zone/location provided)
--   x: number (0-1) - Normalized X coordinate (optional if location name provided)
--   y: number (0-1) - Normalized Y coordinate (optional if location name provided)
--   zone: string (optional) - Zone name (used with locationName)
--   locationName: string (optional) - Location name within the zone
-- Returns: boolean, errorMessage
---------------------------------------
local function CheckMapDiscovery(mapID, x, y, zone, locationName)
    -- If zone and locationName provided, look them up
    if zone and locationName then
        local foundMapID = GetMapIDForZone(zone)
        if not foundMapID then
            return false, "Unknown zone: " .. tostring(zone)
        end
        
        local foundX, foundY = GetLocationCoords(zone, locationName)
        if not foundX or not foundY then
            return false, "Unknown location '" .. locationName .. "' in zone: " .. zone
        end
        
        mapID = foundMapID
        x = foundX
        y = foundY
    end
    
    -- Validate required parameters
    if not mapID then
        return false, "mapID is required (or provide zone and locationName)"
    end
    
    if x == nil or y == nil then
        return false, "x and y coordinates are required (or provide locationName with zone)"
    end
    
    -- Validate coordinate range (0-1)
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return false, "Coordinates must be normalized values between 0 and 1"
    end
    
    -- Check if the API functions exist
    if not C_MapExplorationInfo or not C_MapExplorationInfo.GetExploredAreaIDsAtPosition then
        return false, "Map exploration API not available"
    end
    
    if not CreateVector2D then
        return false, "CreateVector2D function not available (required for creating position objects)"
    end
    
    -- Create a Vector2D position object with normalized coordinates (0-1 range)
    local position = CreateVector2D(x, y)
    
    -- Get explored area IDs at this position
    -- Returns a table of area IDs if the position has been explored, nil or empty table if not
    local exploredAreaIDs = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, position)
    
    -- If we got any explored area IDs back, the location has been discovered
    -- The function returns a table of area IDs, or nil/empty table if not explored
    if exploredAreaIDs then
        -- Check if it's a table with at least one element
        if type(exploredAreaIDs) == "table" then
            -- Count elements (handles both array and dictionary-style tables)
            local count = 0
            for _ in pairs(exploredAreaIDs) do
                count = count + 1
            end
            if count > 0 then
                return true, nil
            end
        end
    end
    
    return false, nil
end

---------------------------------------
-- Helper function: Check discovery by zone and location name (convenience wrapper)
---------------------------------------
local function CheckMapDiscoveryByLocation(zone, locationName)
    return CheckMapDiscovery(nil, nil, nil, zone, locationName)
end

---------------------------------------
-- Helper function: Check discovery by mapID and coordinates (convenience wrapper)
---------------------------------------
local function CheckMapDiscoveryByCoords(mapID, x, y)
    return CheckMapDiscovery(mapID, x, y, nil, nil)
end

local function ResolveZoneDiscoveryTarget(zone)
    local mapID = nil
    local zoneName = nil

    if type(zone) == "number" then
        mapID = zone
        for name, id in pairs(ZoneMapIDs) do
            if id == mapID then
                zoneName = name
                break
            end
        end
    elseif type(zone) == "string" then
        zoneName = zone
        mapID = GetMapIDForZone(zoneName)
        if not mapID then
            return nil, nil, "Unknown zone: " .. tostring(zone)
        end
    else
        return nil, nil, "Zone must be a string (zone name) or number (mapID)"
    end

    if not mapID then
        return nil, nil, "Could not determine mapID for zone: " .. tostring(zone)
    end

    if not zoneName or not LocationMap[zoneName] then
        return nil, nil, "No locations defined for zone: " .. tostring(zoneName or mapID)
    end

    return mapID, zoneName, nil
end

local function IsExploredAtPosition(mapID, x, y)
    local position = CreateVector2D(x, y)
    local exploredAreaIDs = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, position)

    if exploredAreaIDs and type(exploredAreaIDs) == "table" then
        local count = 0
        for _ in pairs(exploredAreaIDs) do
            count = count + 1
        end
        return count > 0
    end

    return false
end

local function GetZoneDiscoveryDetails(zone)
    local mapID, zoneName, err = ResolveZoneDiscoveryTarget(zone)
    if err then
        return nil, err, 0, 0, nil, nil
    end

    if not C_MapExplorationInfo or not C_MapExplorationInfo.GetExploredAreaIDsAtPosition then
        return nil, "Map exploration API not available", 0, 0, zoneName, mapID
    end

    if not CreateVector2D then
        return nil, "CreateVector2D function not available", 0, 0, zoneName, mapID
    end

    local details = {}
    local discoveredCount = 0

    for locationName, coords in pairs(LocationMap[zoneName]) do
        local discovered = IsExploredAtPosition(mapID, coords.x, coords.y)
        if discovered then
            discoveredCount = discoveredCount + 1
        end
        table_insert(details, {
            name = locationName,
            discovered = discovered,
            x = coords.x,
            y = coords.y,
        })
    end

    table_sort(details, function(a, b)
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    return details, nil, discoveredCount, #details, zoneName, mapID
end

---------------------------------------
-- Check if an entire zone has been discovered
-- This checks all defined locations in the zone from LocationMap
-- Parameters:
--   zone: string or number - Zone name (string) or mapID (number)
--   threshold: number (optional, 0-1) - Minimum percentage of locations that must be discovered (default: 1.0 = 100%)
-- Returns: boolean, errorMessage, discoveredCount, totalCount
---------------------------------------
local function CheckZoneDiscovery(zone, threshold)
    threshold = threshold or 1.0 -- Default to 100% coverage required

    local details, err, discoveredCount, totalCount, zoneName, mapID = GetZoneDiscoveryDetails(zone)
    if err then
        return false, err, discoveredCount, totalCount
    end

    if totalCount == 0 then
        return false, "No locations defined for zone: " .. tostring(zoneName), 0, 0
    end

    -- Calculate percentage and compare to threshold
    local percentage = totalCount > 0 and (discoveredCount / totalCount) or 0
    local isDiscovered = percentage >= threshold
    
    local message = nil
    if not isDiscovered then
        message = string_format("Zone %s: %d/%d locations discovered (%.1f%%, need %.1f%%)", 
            tostring(zoneName or mapID), discoveredCount, totalCount, percentage * 100, threshold * 100)
    end
    
    return isDiscovered, message, discoveredCount, totalCount
end

addon.CheckZoneDiscovery = CheckZoneDiscovery
addon.GetZoneDiscoveryDetails = GetZoneDiscoveryDetails