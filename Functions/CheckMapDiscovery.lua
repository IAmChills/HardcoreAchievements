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
    --["Darnassus"] = 1457,
    ["Desolace"] = 1443,
    ["Durotar"] = 1411,
    ["Dustwallow Marsh"] = 1445,
    ["Felwood"] = 1448,
    ["Feralas"] = 1444,
    ["Moonglade"] = 1450,
    ["Mulgore"] = 1412,
    --["Orgrimmar"] = 1454,
    ["Silithus"] = 1451,
    ["Stonetalon Mountains"] = 1442,
    ["Tanaris"] = 1446,
    ["Teldrassil"] = 1438,
    ["The Barrens"] = 1413,
    ["The Exodar"] = 1947,
    ["Thousand Needles"] = 1441,
    --["Thunder Bluff"] = 1456,
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
    --["Ironforge"] = 1455,
    ["Isle of Quel'Danas"] = 1957,
    ["Loch Modan"] = 1432,
    ["Redridge Mountains"] = 1433,
    ["Searing Gorge"] = 1427,
    --["Silvermoon City"] = 1954,
    ["Silverpine Forest"] = 1421,
    --["Stormwind City"] = 1453,
    ["Stranglethorn Vale"] = 1434,
    ["Swamp of Sorrows"] = 1435,
    ["The Hinterlands"] = 1425,
    ["Tirisfal Glades"] = 1420,
    --["Undercity"] = 1458,
    ["Western Plaguelands"] = 1422,
    ["Westfall"] = 1436,
    ["Wetlands"] = 1437,

    -- Outlands
    ["Blade's Edge Mountains"] = 1949,
    ["Hellfire Peninsula"] = 1944,
    ["Nagrand"] = 1951,
    ["Netherstorm"] = 1953,
    ["Shadowmoon Valley"] = 1948,
    --["Shattrath City"] = 1955,
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
        ["Azure Watch"] = {x = 0.0, y = 0.0},
        ["Odesyus' Landing"] = {x = 0.0, y = 0.0},
        ["Stillpine Hold"] = {x = 0.0, y = 0.0},
    },
    ["Bloodmyst Isle"] = {
        ["Blood Watch"] = {x = 0.0, y = 0.0},
        ["The Bloodcursed Reef"] = {x = 0.0, y = 0.0},
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
        ["Craftsmen's Terrace"] = {x = 0.0, y = 0.0},
        ["Warrior's Terrace"] = {x = 0.0, y = 0.0},
        ["Temple of Elune"] = {x = 0.0, y = 0.0},
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
        ["Orgrimmar"] = {x = 0.45, y = 0.06},
        ["Razor Hill"] = {x = 0.0, y = 0.0},
        ["Sen'jin Village"] = {x = 0.0, y = 0.0},
        ["Echo Isles"] = {x = 0.0, y = 0.0},
    },
    ["Dustwallow Marsh"] = {
        ["Brackenwall Village"] = {x = 0.0, y = 0.0},
        ["Mudsprocket"] = {x = 0.0, y = 0.0},
        ["Theramore Isle"] = {x = 0.0, y = 0.0},
    },
    ["Felwood"] = {
        ["Emerald Sanctuary"] = {x = 0.0, y = 0.0},
        ["Jaedenar"] = {x = 0.0, y = 0.0},
        ["Bloodvenom Post"] = {x = 0.0, y = 0.0},
    },
    ["Feralas"] = {
        ["Feathermoon Stronghold"] = {x = 0.0, y = 0.0},
        ["Camp Mojache"] = {x = 0.0, y = 0.0},
        ["Dire Maul"] = {x = 0.0, y = 0.0},
    },
    ["Moonglade"] = {
        ["Nighthaven"] = {x = 0.51, y = 0.54},
    },
    ["Mulgore"] = {
        ["Bloodhoof Village"] = {x = 0.0, y = 0.0},
        ["Thunder Bluff"] = {x = 0.0, y = 0.0},
    },
    ["Orgrimmar"] = {
        ["Valley of Strength"] = {x = 0.0, y = 0.0},
        ["Valley of Honor"] = {x = 0.0, y = 0.0},
        ["The Drag"] = {x = 0.0, y = 0.0},
    },
    ["Silithus"] = {
        ["Cenarion Hold"] = {x = 0.0, y = 0.0},
        ["The Scarab Wall"] = {x = 0.0, y = 0.0},
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
        ["Gadgetzan"] = {x = 0.0, y = 0.0},
        ["Zul'Farrak"] = {x = 0.0, y = 0.0},
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
        ["The Crossroads"] = {x = 0.0, y = 0.0},
        ["Ratchet"] = {x = 0.0, y = 0.0},
        ["Camp Taurajo"] = {x = 0.0, y = 0.0},
    },
    ["The Exodar"] = {
        ["The Vault of Lights"] = {x = 0.0, y = 0.0},
        ["Trader's Tier"] = {x = 0.0, y = 0.0},
    },
    ["Thousand Needles"] = {
        ["Freewind Post"] = {x = 0.0, y = 0.0},
        ["The Great Lift"] = {x = 0.0, y = 0.0},
    },
    ["Thunder Bluff"] = {
        ["The Lower Rise"] = {x = 0.0, y = 0.0},
        ["The Upper Rise"] = {x = 0.0, y = 0.0},
    },
    ["Un'Goro Crater"] = {
        ["Marshal's Refuge"] = {x = 0.0, y = 0.0},
        ["The Marshlands"] = {x = 0.0, y = 0.0},
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
        ["Crushridge Hold"] = {x = 0.0, y = 0.0},
        ["The Uplands"] = {x = 0.0, y = 0.0},
    },
    ["Arathi Highlands"] = {
        ["Hammerfall"] = {x = 0.0, y = 0.0},
        ["Refuge Pointe"] = {x = 0.0, y = 0.0},
    },
    ["Badlands"] = {
        ["Kargath"] = {x = 0.0, y = 0.0},
        ["Uldaman"] = {x = 0.0, y = 0.0},
    },
    ["Blasted Lands"] = {
        ["Dreadmaul Hold"] = {x = 0.0, y = 0.0},
        ["The Dark Portal"] = {x = 0.0, y = 0.0},
    },
    ["Burning Steppes"] = {
        ["Flame Crest"] = {x = 0.0, y = 0.0},
        ["Morgan's Vigil"] = {x = 0.0, y = 0.0},
    },
    ["Deadwind Pass"] = {
        ["Deadman's Crossing"] = {x = 0.50, y = 0.45},
        ["The Vice"] = {x = 0.59, y = 0.64},
        ["Karazhan"] = {x = 0.46, y = 0.73},
    },
    ["Dun Morogh"] = {
        ["Kharanos"] = {x = 0.0, y = 0.0},
        ["Anvilmar"] = {x = 0.0, y = 0.0},
        ["Ironforge"] = {x = 0.0, y = 0.0},
    },
    ["Duskwood"] = {
        ["Darkshire"] = {x = 0.0, y = 0.0},
        ["Raven Hill"] = {x = 0.0, y = 0.0},
    },
    ["Eastern Plaguelands"] = {
        ["Corin's Crossing"] = {x = 0.60, y = 0.67},
        ["Pestilent Scar"] = {x = 0.70, y = 0.61},
        ["Light's Hope Chapel"] = {x = 0.808, y = 0.588},
        ["Tyr's Hand"] = {x = 0.0, y = 0.0},
        ["Northdale"] = {x = 0.0, y = 0.0},
    },
    ["Elwynn Forest"] = {
        ["Stormwind City"] = {x = 0.28, y = 0.42},
        ["Goldshire"] = {x = 0.0, y = 0.0},
        ["Northshire Valley"] = {x = 0.0, y = 0.0},
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
        ["Amani Pass"] = {x = 0.70, y = 0.56},
        ["Thalassian Pass"] = {x = 0.48, y = 0.85},
        ["Tranquillien"] = {x = 0.0, y = 0.0},
        ["Zeb'Sora"] = {x = 0.0, y = 0.0},
    },
    ["Hillsbrad Foothills"] = {
        ["Tarren Mill"] = {x = 0.0, y = 0.0},
        ["Southshore"] = {x = 0.0, y = 0.0},
        ["Durnholde Keep"] = {x = 0.0, y = 0.0},
    },
    ["Ironforge"] = {
        ["The Commons"] = {x = 0.0, y = 0.0},
        ["The Mystic Ward"] = {x = 0.0, y = 0.0},
    },
    ["Isle of Quel'Danas"] = {
        ["Isle of Quel'Danas"] = {x = 0.52, y = 0.55},
    },
    ["Loch Modan"] = {
        ["Thelsamar"] = {x = 0.0, y = 0.0},
        ["Ironband's Excavation Site"] = {x = 0.0, y = 0.0},
    },
    ["Redridge Mountains"] = {
        ["Lakeshire"] = {x = 0.0, y = 0.0},
        ["Stonewatch Keep"] = {x = 0.0, y = 0.0},
    },
    ["Searing Gorge"] = {
        ["Thorium Point"] = {x = 0.0, y = 0.0},
        ["The Cauldron"] = {x = 0.0, y = 0.0},
    },
    ["Silvermoon City"] = {
        ["The Bazaar"] = {x = 0.0, y = 0.0},
        ["The Royal Exchange"] = {x = 0.0, y = 0.0},
    },
    ["Silverpine Forest"] = {
        ["The Sepulcher"] = {x = 0.0, y = 0.0},
        ["Pyrewood Village"] = {x = 0.0, y = 0.0},
    },
    ["Stormwind City"] = {
        ["Trade District"] = {x = 0.0, y = 0.0},
        ["Old Town"] = {x = 0.0, y = 0.0},
        ["Cathedral Square"] = {x = 0.0, y = 0.0},
    },
    ["Stranglethorn Vale"] = {
        ["Booty Bay"] = {x = 0.0, y = 0.0},
        ["Grom'gol Base Camp"] = {x = 0.0, y = 0.0},
        ["Nessingwary's Expedition"] = {x = 0.0, y = 0.0},
    },
    ["Swamp of Sorrows"] = {
        ["Stonard"] = {x = 0.45, y = 0.53},
        ["Splinterspear Junction"] = {x = 0.20, y = 0.50},
    },
    ["The Hinterlands"] = {
        ["Aerie Peak"] = {x = 0.0, y = 0.0},
        ["Revantusk Village"] = {x = 0.0, y = 0.0},
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
        ["Caer Darrow"] = {x = 0.0, y = 0.0},
        ["Andorhal"] = {x = 0.0, y = 0.0},
    },
    ["Westfall"] = {
        ["Sentinel Hill"] = {x = 0.0, y = 0.0},
        ["Moonbrook"] = {x = 0.0, y = 0.0},
    },
    ["Wetlands"] = {
        ["Menethil Harbor"] = {x = 0.0, y = 0.0},
        ["Dun Modr"] = {x = 0.0, y = 0.0},
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
        ["Haal'eshi Gorge"] = {x = 0.28, y = 0.80},
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
        ["Nesingwary Safari"] = {x = 0.72, y = 0.41},
        ["Windyreed Village"] = {x = 0.74, y = 0.52},
        ["The Ring of Trials"] = {x = 0.66, y = 0.57},
        ["Clan Watch"] = {x = 0.62, y = 0.64},
        ["Southwind Cleft"] = {x = 0.50, y = 0.57},
        ["Zangar Ridge"] = {x = 0.50, y = 0.57},
    },
    ["Netherstorm"] = {
        ["Gyro-Plank Bridge"] = {x = 0.26, y = 0.55},
        ["Ruins of Enkaat"] = {x = 0.34, y = 0.56},
        ["Area 52"] = {x = 0.0, y = 0.0},
        ["Kirin'Var Village"] = {x = 0.0, y = 0.0},
        ["The Stormspire"] = {x = 0.0, y = 0.0},
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
        ["Quagg Ridge"] = {x = 0.25, y = 0.63},
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
    
    local mapID = nil
    local zoneName = nil
    
    -- Determine if zone is a mapID (number) or zone name (string)
    if type(zone) == "number" then
        mapID = zone
        -- Try to find zone name from mapID (reverse lookup)
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
            return false, "Unknown zone: " .. tostring(zone), 0, 0
        end
    else
        return false, "Zone must be a string (zone name) or number (mapID)", 0, 0
    end
    
    if not mapID then
        return false, "Could not determine mapID for zone: " .. tostring(zone), 0, 0
    end
    
    -- Check if we have defined locations for this zone
    if not zoneName or not LocationMap[zoneName] then
        return false, "No locations defined for zone: " .. tostring(zoneName or mapID), 0, 0
    end
    
    -- Check if API functions exist
    if not C_MapExplorationInfo or not C_MapExplorationInfo.GetExploredAreaIDsAtPosition then
        return false, "Map exploration API not available", 0, 0
    end
    
    if not CreateVector2D then
        return false, "CreateVector2D function not available", 0, 0
    end
    
    local locationsToCheck = {}
    local discoveredCount = 0
    local totalCount = 0
    
    -- Check all defined locations in the zone
    for locationName, coords in pairs(LocationMap[zoneName]) do
        table_insert(locationsToCheck, {x = coords.x, y = coords.y, name = locationName})
    end
    
    totalCount = #locationsToCheck
    if totalCount == 0 then
        return false, "No locations defined for zone: " .. tostring(zoneName), 0, 0
    end
    
    -- Check each location
    for _, location in ipairs(locationsToCheck) do
        local position = CreateVector2D(location.x, location.y)
        local exploredAreaIDs = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, position)
        
        local isExplored = false
        if exploredAreaIDs and type(exploredAreaIDs) == "table" then
            local count = 0
            for _ in pairs(exploredAreaIDs) do
                count = count + 1
            end
            isExplored = count > 0
        end
        
        if isExplored then
            discoveredCount = discoveredCount + 1
        end
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