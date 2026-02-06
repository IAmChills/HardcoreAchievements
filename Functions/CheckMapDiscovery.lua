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
    ["Deadwind Pass"] = 1430,
    ["Eastern Plaguelands"] = 1423,
    ["Ghostlands"] = 1942,
    ["Durotar"] = 1411,
    ["Elwynn Forest"] = 1429,
    ["Swamp of Sorrows"] = 1435,
    ["Shadowmoon Valley"] = 1948,
}

---------------------------------------
-- Location mappings within zones
-- Coordinates are normalized 0-1 (x, y) where (0,0) is top-left, (1,1) is bottom-right
-- Format: [zoneName] = { [locationName] = {x = 0.0-1.0, y = 0.0-1.0} }
---------------------------------------
local LocationMap = {
    ["Deadwind Pass"] = {
        ["Deadman's Crossing"] = {x = 0.50, y = 0.45},
        --["The Vice"] = {x = 0.59, y = 0.64},
        ["Karazhan"] = {x = 0.46, y = 0.73},
    },
    ["Eastern Plaguelands"] = {
        ["Corin's Crossing"] = {x = 0.60, y = 0.67},
        ["Pestilent Scar"] = {x = 0.70, y = 0.61},
        ["Light's Hope Chapel"] = {x = 0.808, y = 0.588},
    },
    ["Ghostlands"] = {
        ["Amani Pass"] = {x = 0.70, y = 0.56},
        ["Thalassian Pass"] = {x = 0.48, y = 0.85},
    },
    ["Durotar"] = {
        ["Orgrimmar"] = {x = 0.45, y = 0.06},
    },
    ["Elwynn Forest"] = {
        ["Stormwind City"] = {x = 0.28, y = 0.42},
    },
    ["Swamp of Sorrows"] = {
        ["Stonard"] = {x = 0.45, y = 0.53},
        ["Splinterspear Junction"] = {x = 0.20, y = 0.50},
    },
    ["Shadowmoon Valley"] = {
        ["Legion Hold"] = {x = 0.23, y = 0.37},
        ["Shadowmoon Village"] = {x = 0.29, y = 0.28},
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