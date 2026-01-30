local DungeonCommon = {}

-- Module-level tracking for instance entry levels
-- Tracks player and party member levels when entering dungeons
-- Format: instanceEntryLevels[mapId] = { playerLevel = level, partyLevels = { [guid] = level }, wasDeadOnExit = bool }
local instanceEntryLevels = {}

-- Track if player/party members were dead when leaving instance (for re-entry handling)
local wasDeadOnExit = false
local lastInstanceMapId = nil

-- Track if player is currently inside a dungeon or raid instance
-- This prevents achievements from being marked as failed when leveling up inside
local isInDungeonOrRaid = false

-- Helper function to check if a group is eligible for a dungeon achievement
local function CheckAchievementEligibility(mapId, achDef, entryData)
    if not mapId or not achDef or not entryData then return false end
    
    local maxLevel = achDef.level
    if not maxLevel then return false end -- No level requirement
    
    local maxPartySize = achDef.maxPartySize or 5
    local members = GetNumGroupMembers()
    if members > maxPartySize then return false end
    if IsInRaid() then return false end
    
    -- Check faction
    if achDef.faction then
        local playerFaction = select(2, UnitFactionGroup("player"))
        if playerFaction ~= achDef.faction then return false end
    end
    
    -- Check player level
    local playerLevel = entryData.playerLevel or UnitLevel("player") or 1
    if playerLevel > maxLevel then return false end
    
    -- Check party member levels
    if members > 1 then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    local partyLevel = entryData.partyLevels and entryData.partyLevels[guid]
                    if partyLevel and partyLevel > maxLevel then
                        return false
                    end
                end
            end
        end
    end
    
    return true
end

-- Helper function to check and print eligibility messages for achievements matching a mapId
local function CheckAndPrintEligibilityMessages(mapId, entryData)
    if not mapId or not entryData then return end
    if not _G.HCA_AchievementDefs then return end
    
    for achId, achDef in pairs(_G.HCA_AchievementDefs) do
        if achDef.mapID == mapId then
            -- Only show messages for visible achievements (checked in filter)
            local isVisible = false
            if _G.HCA_IsAchievementVisible then
                isVisible = _G.HCA_IsAchievementVisible(achId)
            end
            
            if isVisible then
                -- Only show messages for available achievements (not completed, not failed)
                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(achId)
                local isCompleted = progress and progress.completed
                local isFailed = progress and progress.failed
                
                -- Also check if row exists and is outleveled
                if not isFailed and _G.AchievementPanel and _G.AchievementPanel.achievements then
                    for _, row in ipairs(_G.AchievementPanel.achievements) do
                        local rowId = row.id or row.achId
                        if rowId and tostring(rowId) == tostring(achId) then
                            if _G.IsRowOutleveled and _G.IsRowOutleveled(row) then
                                isFailed = true
                            end
                            break
                        end
                    end
                end
                
                -- Skip if completed or failed
                if not isCompleted and not isFailed then
                    local isEligible = CheckAchievementEligibility(mapId, achDef, entryData)
                    if isEligible then
                        print("|cff008066[Hardcore Achievements]|r |cff00ff00Group is eligible for achievement: " .. (achDef.title or achDef.mapName or "Unknown") .. ". If any player levels beyond the achievement’s allowed level while inside the dungeon, exiting and re-entering will disqualify the group from achievement eligibility.|r")
                    else
                        print("|cff008066[Hardcore Achievements]|r |cffff0000Group is not eligible for achievement: " .. (achDef.title or achDef.mapName or "Unknown") .. "|r")
                    end
                end
            end
        end
    end
end

-- Helper function to update party member levels when they join the dungeon
local function UpdatePartyMemberLevels(mapId, entryData)
    if not mapId or not entryData then return end
    
    local members = GetNumGroupMembers()
    if members > 1 then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    local storedLevel = entryData.partyLevels and entryData.partyLevels[guid]
                    if not storedLevel then
                        -- New party member - add them to entry levels
                        if not entryData.partyLevels then
                            entryData.partyLevels = {}
                        end
                        local currentLevel = UnitLevel(unit) or 1
                        local unitName = UnitName(unit) or ("Party" .. i)
                        entryData.partyLevels[guid] = currentLevel
                        if _G.HCA_DebugPrint then
                            _G.HCA_DebugPrint("Party member " .. unitName .. " joined dungeon - level stored: " .. currentLevel)
                        end
                    end
                end
            end
        end
    end
end

-- Initialize event frame for PLAYER_ENTERING_WORLD, PLAYER_DEAD, and party member events
local dungeonEventFrame = CreateFrame("Frame")
dungeonEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
dungeonEventFrame:RegisterEvent("PLAYER_DEAD")
dungeonEventFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
dungeonEventFrame:RegisterEvent("PARTY_MEMBER_DISABLE")
dungeonEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- Initialize dungeon/raid flag on load
local function InitializeDungeonFlag()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        isInDungeonOrRaid = true
    else
        isInDungeonOrRaid = false
    end
end

dungeonEventFrame:SetScript("OnEvent", function(self, event, unitIndex)
    if event == "PLAYER_DEAD" then
        -- Track that player died while in an instance (will be used when leaving instance)
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "party" then
            wasDeadOnExit = true
            local mapId = select(8, GetInstanceInfo())
            if _G.HCA_DebugPrint then
                _G.HCA_DebugPrint("Tracking death in dungeon (mapId: " .. (mapId or "unknown") .. ")")
            end
        end
    elseif event == "PARTY_MEMBER_DISABLE" then
        -- Party member left or went offline - clear their data if not dead/ghost (allows replacement)
        -- unitIndex is actually the unit ID string (e.g., "party1")
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "party" then
            local mapId = select(8, GetInstanceInfo())
            if mapId and instanceEntryLevels[mapId] then
                if unitIndex then
                    -- unitIndex is already the full unit ID like "party1"
                    local unit = unitIndex
                    if UnitExists(unit) then
                        local guid = UnitGUID(unit)
                        local unitName = UnitName(unit) or unitIndex
                        local isDeadOrGhost = UnitIsDeadOrGhost(unit)
                        
                        if guid then
                            local entryData = instanceEntryLevels[mapId]
                            if entryData.partyLevels and entryData.partyLevels[guid] then
                                if not isDeadOrGhost then
                                    -- Party member left normally (not dead/ghost) - clear their data to allow replacement
                                    entryData.partyLevels[guid] = nil
                                    if _G.HCA_DebugPrint then
                                        _G.HCA_DebugPrint("Party member " .. unitName .. " left dungeon - data cleared (can be replaced)")
                                    end
                                else
                                    -- Party member is dead/ghost - keep their data (they're running back from graveyard)
                                    if _G.HCA_DebugPrint then
                                        _G.HCA_DebugPrint("Party member " .. unitName .. " left dungeon (dead/ghost) - data preserved")
                                    end
                                end
                            end
                        end
                    else
                        -- Unit already gone - debug message only
                        local unitName = unitIndex
                        if _G.HCA_DebugPrint then
                            _G.HCA_DebugPrint("Party member " .. unitName .. " left dungeon (disabled)")
                        end
                    end
                end
            end
        end
    elseif event == "PARTY_MEMBER_ENABLE" then
        -- Party member joined or zoned into the dungeon - update their level if we're tracking entry levels
        -- unitIndex is actually the unit ID string (e.g., "party1")
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "party" then
            local mapId = select(8, GetInstanceInfo())
            if mapId and instanceEntryLevels[mapId] then
                -- Check the specific party member that enabled
                if unitIndex then
                    -- unitIndex is already the full unit ID like "party1"
                    local unit = unitIndex
                    if UnitExists(unit) then
                        local guid = UnitGUID(unit)
                        if guid then
                            local entryData = instanceEntryLevels[mapId]
                            local storedLevel = entryData.partyLevels and entryData.partyLevels[guid]
                            local unitName = UnitName(unit) or unitIndex
                            local currentLevel = UnitLevel(unit) or 1
                            
                            if storedLevel then
                                -- Party member re-entered - update stored level (allow leveling outside if they return)
                                if entryData.wasDeadOnExit then
                                    -- Player was dead when leaving - don't update level (preserve original entry level)
                                    if _G.HCA_DebugPrint then
                                        _G.HCA_DebugPrint("Party member " .. unitName .. " re-entered after player death - level preserved (stored: " .. storedLevel .. ", current: " .. currentLevel .. ")")
                                    end
                                else
                                    -- Update stored level to current level (accepts leveling outside as long as they re-enter)
                                    entryData.partyLevels[guid] = currentLevel
                                    if currentLevel > storedLevel then
                                        if _G.HCA_DebugPrint then
                                            _G.HCA_DebugPrint("Party member " .. unitName .. " re-entered with increased level (was " .. storedLevel .. ", now " .. currentLevel .. ") - stored level updated")
                                        end
                                    else
                                        if _G.HCA_DebugPrint then
                                            _G.HCA_DebugPrint("Party member " .. unitName .. " re-entered - level unchanged (" .. currentLevel .. ")")
                                        end
                                    end
                                end
                            else
                                -- New party member - add them to entry levels
                                if not entryData.partyLevels then
                                    entryData.partyLevels = {}
                                end
                                entryData.partyLevels[guid] = currentLevel
                                if _G.HCA_DebugPrint then
                                    _G.HCA_DebugPrint("Party member " .. unitName .. " joined dungeon - level stored: " .. currentLevel)
                                end
                            end
                        end
                    end
                else
                        -- No unit provided, check all party members
                        UpdatePartyMemberLevels(mapId, instanceEntryLevels[mapId])
                    end
                end
            end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Group roster changed (player joined or left the group)
        -- Process for all tracked instances (in case we're not currently in one but have stored data)
        local inInstance, instanceType = IsInInstance()
        local currentMapId = nil
        if inInstance and instanceType == "party" then
            currentMapId = select(8, GetInstanceInfo())
        end
        
        -- Process all stored entry levels (in case we're outside but have stored data to clean up)
        for mapId, entryData in pairs(instanceEntryLevels) do
            if not entryData.partyLevels then
                entryData.partyLevels = {}
            end
            
            -- Get current party member GUIDs
            local currentPartyGUIDs = {}
            local members = GetNumGroupMembers()
            if members > 1 then
                for i = 1, 4 do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        local guid = UnitGUID(unit)
                        if guid then
                            currentPartyGUIDs[guid] = true
                        end
                    end
                end
            end
            
            -- Remove party members who are no longer in the group
            for storedGUID, storedLevel in pairs(entryData.partyLevels) do
                if not currentPartyGUIDs[storedGUID] then
                    -- This party member left the group - clear their data
                    entryData.partyLevels[storedGUID] = nil
                    if _G.HCA_DebugPrint then
                        _G.HCA_DebugPrint("Party member left group - data cleared (GUID: " .. (storedGUID or "unknown") .. ", mapId: " .. (mapId or "unknown") .. ")")
                    end
                end
            end
            
            -- Add new party members (only if not already stored - preserve existing levels)
            -- Only add if we're in the instance for this mapId
            if currentMapId and currentMapId == mapId then
                if members > 1 then
                    for i = 1, 4 do
                        local unit = "party" .. i
                        if UnitExists(unit) then
                            local guid = UnitGUID(unit)
                            if guid and not entryData.partyLevels[guid] then
                                -- New party member - add them to entry levels
                                -- Only store if level is valid (> 0) - if level is 0, PARTY_MEMBER_ENABLE will handle it when they enter
                                local currentLevel = UnitLevel(unit)
                                if currentLevel and currentLevel > 0 then
                                    local unitName = UnitName(unit) or ("Party" .. i)
                                    entryData.partyLevels[guid] = currentLevel
                                    if _G.HCA_DebugPrint then
                                        _G.HCA_DebugPrint("Party member joined group - level stored: " .. currentLevel .. " (" .. unitName .. ", mapId: " .. (mapId or "unknown") .. ")")
                                    end
                                elseif _G.HCA_DebugPrint then
                                    local unitName = UnitName(unit) or ("Party" .. i)
                                    _G.HCA_DebugPrint("Party member joined group but level not available yet (" .. (unitName or "unknown") .. ") - will be handled on entry")
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Initialize flag on first load
        InitializeDungeonFlag()
        
        local inInstance, instanceType = IsInInstance()
        
        if inInstance and (instanceType == "party" or instanceType == "raid") then
            -- Player is entering or already in a dungeon/raid instance
            isInDungeonOrRaid = true
            
            if instanceType == "party" then
                -- Entering or already in a dungeon instance
                local mapId = select(8, GetInstanceInfo())
              if mapId then
                  -- Check if we already have entry levels for this map (to detect re-entry)
                  local existingEntry = instanceEntryLevels[mapId]
                  
                  if existingEntry then
                      -- Re-entry: verify player and party members didn't level up
                      -- Skip level check if player was dead when leaving (running back from graveyard)
                      lastInstanceMapId = mapId  -- Update tracking for current instance
                      
                      if existingEntry.wasDeadOnExit then
                          -- Player was dead when leaving, skip level check and clear the flag
                          existingEntry.wasDeadOnExit = nil
                          wasDeadOnExit = false
                          if _G.HCA_DebugPrint then
                              _G.HCA_DebugPrint("Re-entry after death - level check omitted")
                          end
                      else
                          -- Normal re-entry: update stored level (allow leveling outside if they return)
                          local playerLevel = UnitLevel("player") or 1
                          local oldPlayerLevel = existingEntry.playerLevel
                          if playerLevel > oldPlayerLevel then
                              -- Player leveled up outside - update stored level
                              existingEntry.playerLevel = playerLevel
                              if _G.HCA_DebugPrint then
                                  _G.HCA_DebugPrint("Player re-entered with increased level (was " .. oldPlayerLevel .. ", now " .. playerLevel .. ") - stored level updated")
                              end
                          else
                              if _G.HCA_DebugPrint then
                                  _G.HCA_DebugPrint("Player re-entered - level unchanged (" .. playerLevel .. ")")
                              end
                          end
                      end
                      
                      -- Check and update party member levels on re-entry
                      local members = GetNumGroupMembers()
                      if members > 1 then
                          for i = 1, 4 do
                              local unit = "party" .. i
                              if UnitExists(unit) then
                                  local guid = UnitGUID(unit)
                                  
                                  if guid then
                                      local storedLevel = existingEntry.partyLevels and existingEntry.partyLevels[guid]
                                      local currentLevel = UnitLevel(unit) or 1
                                      local unitName = UnitName(unit) or ("Party" .. i)
                                      
                                      if storedLevel then
                                          -- This party member was in the instance before - update stored level
                                          if existingEntry.wasDeadOnExit then
                                              -- Player was dead when leaving - preserve original stored level
                                              if _G.HCA_DebugPrint then
                                                  _G.HCA_DebugPrint("Party member " .. unitName .. " re-entry after player death - level preserved (stored: " .. storedLevel .. ", current: " .. currentLevel .. ")")
                                              end
                                          else
                                              -- Normal re-entry: update stored level to current level
                                              existingEntry.partyLevels[guid] = currentLevel
                                              if currentLevel > storedLevel then
                                                  if _G.HCA_DebugPrint then
                                                      _G.HCA_DebugPrint("Party member " .. unitName .. " re-entered with increased level (was " .. storedLevel .. ", now " .. currentLevel .. ") - stored level updated")
                                                  end
                                              else
                                                  if _G.HCA_DebugPrint then
                                                      _G.HCA_DebugPrint("Party member " .. unitName .. " re-entered - level unchanged (" .. currentLevel .. ")")
                                                  end
                                              end
                                          end
                                      else
                                          -- New party member joined - store their level
                                          if not existingEntry.partyLevels then
                                              existingEntry.partyLevels = {}
                                          end
                                          existingEntry.partyLevels[guid] = currentLevel
                                          if _G.HCA_DebugPrint then
                                              _G.HCA_DebugPrint("Party member " .. unitName .. " joined on re-entry - level stored: " .. currentLevel)
                                          end
                                      end
                                  end
                              end
                          end
                      end
                  else
                      -- First entry: store entry levels
                      local playerLevel = UnitLevel("player") or 1
                      local entryData = {
                          playerLevel = playerLevel,
                          partyLevels = {}
                      }
                      
                      -- Store party member levels
                      local members = GetNumGroupMembers()
                      local levelStr = "Player: " .. playerLevel
                      if members > 1 then
                          for i = 1, 4 do
                              local unit = "party" .. i
                              if UnitExists(unit) then
                                  local guid = UnitGUID(unit)
                                  local level = UnitLevel(unit) or 1
                                  if guid then
                                      entryData.partyLevels[guid] = level
                                      levelStr = levelStr .. ", Party" .. i .. ": " .. level
                                  end
                              end
                          end
                      end
                      
                      instanceEntryLevels[mapId] = entryData
                      lastInstanceMapId = mapId
                      wasDeadOnExit = false
                      if _G.HCA_DebugPrint then
                          _G.HCA_DebugPrint("Dungeon entry levels stored: " .. levelStr)
                      end
                      -- Also update party member levels in case any joined during the zone load
                      UpdatePartyMemberLevels(mapId, entryData)
                      
                      -- Check and print eligibility messages for visible achievements matching this mapId
                      CheckAndPrintEligibilityMessages(mapId, entryData)
                  end
              end
            end
        else
            -- Not in a dungeon/raid instance - we're leaving an instance
            isInDungeonOrRaid = false
            
            if lastInstanceMapId and instanceEntryLevels[lastInstanceMapId] then
                -- We were in an instance - if player was dead, mark it in entry data and keep entry levels
                -- Otherwise, clear entry levels (normal exit)
                if wasDeadOnExit then
                    instanceEntryLevels[lastInstanceMapId].wasDeadOnExit = true
                    if _G.HCA_DebugPrint then
                        _G.HCA_DebugPrint("Left instance after death - entry levels preserved for re-entry")
                    end
                else
                    -- Player left normally (not dead) - clear entry levels for this map
                    instanceEntryLevels[lastInstanceMapId] = nil
                    if _G.HCA_DebugPrint then
                        _G.HCA_DebugPrint("Left instance normally - entry levels cleared")
                    end
                    
                    -- Refresh outleveled status now that we're outside the dungeon
                    -- This will mark dungeon achievements as failed if player is over level
                    if _G.HCA_RefreshOutleveledAll then
                        _G.HCA_RefreshOutleveledAll()
                    end
                end
            else
                -- Not leaving from a tracked instance - clear all entry levels
                wipe(instanceEntryLevels)
                
                -- Refresh outleveled status if player left normally (not dead)
                -- This handles cases where player wasn't in a tracked instance but was in a dungeon
                if not wasDeadOnExit and _G.HCA_RefreshOutleveledAll then
                    _G.HCA_RefreshOutleveledAll()
                end
            end
            wasDeadOnExit = false
            lastInstanceMapId = nil
        end
        
        -- Ensure flag is set correctly based on current instance state
        -- This handles cases where the event fires but we need to verify current state
        local currentInInstance, currentInstanceType = IsInInstance()
        if currentInInstance and (currentInstanceType == "party" or currentInstanceType == "raid") then
            isInDungeonOrRaid = true
        else
            isInDungeonOrRaid = false
        end
    end
end)

-- Variation definitions
local VARIATIONS = {
  {
    suffix = "_Trio",
    label = "Trio",
    levelOffset = 3,
    pointMultiplier = 2,
    maxPartySize = 3,
  },
  {
    suffix = "_Duo",
    label = "Duo",
    levelOffset = 4,
    pointMultiplier = 3,
    maxPartySize = 2,
  },
  {
    suffix = "_Solo",
    label = "Solo",
    levelOffset = 5,
    pointMultiplier = 4,
    maxPartySize = 1,
  },
}

-- Generate a variation achievement from a base dungeon achievement
local function CreateVariation(baseDef, variation)
    local variationDef = {}
    
    -- Copy all base properties
    for k, v in pairs(baseDef) do
        variationDef[k] = v
    end
    
    -- Modify for variation
    variationDef.achId = baseDef.achId .. variation.suffix
    variationDef.level = baseDef.level + variation.levelOffset
    variationDef.points = baseDef.points * variation.pointMultiplier
    variationDef.maxPartySize = variation.maxPartySize
    
    -- Update title to include variation type in parentheses
    variationDef.title = baseDef.title .. " (" .. variation.label .. ")"
    
    -- Update tooltip to reflect variation (clean, without "Variation" suffix)
    local partySizeText = variation.maxPartySize == 1 and "yourself only" or 
                          (variation.maxPartySize == 2 and "up to 2 party members" or "up to 3 party members")
    variationDef.tooltip = "Defeat the bosses of " .. HCA_SharedUtils.GetClassColor() .. "" .. baseDef.title .. "|r with every party member at level " .. variationDef.level .. " or lower upon entering the dungeon" .. " (" .. partySizeText .. ")"
    
    -- Mark as variation
    variationDef.isVariation = true
    variationDef.baseAchId = baseDef.achId
    variationDef.variationType = variation.label
    
    return variationDef
end

-- Register a dungeon achievement with the given definition
function DungeonCommon.registerDungeonAchievement(def)
  local achId = def.achId
  local title = def.title
  local tooltip = def.tooltip
  local icon = def.icon
  local level = def.level
  local points = def.points
  local requiredQuestId = def.requiredQuestId
  local staticPoints = def.staticPoints or false
  local requiredMapId = def.requiredMapId
  local requiredKills = def.requiredKills or {}
  local bossOrder = def.bossOrder  -- Optional ordering for tooltip display
  local faction = def.faction

  -- Expose this definition for external lookups (e.g., chat link tooltips)
  HCA_SharedUtils.RegisterAchievementDef({
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    level = level,
    requiredMapId = def.requiredMapId,
    mapName = def.title,
    requiredKills = requiredKills,
    bossOrder = bossOrder,
    faction = faction,
    isVariation = def.isVariation,
    baseAchId = def.baseAchId,
  })

  -- State for the current achievement session only
  local state = {
    counts = {},           -- npcId => kills this achievement
    completed = false,     -- set true once achievement conditions met in this achievement
  }

  -- Load progress from database on initialization
  local function LoadProgress()
    local progress = HardcoreAchievements_GetProgress(achId)
    if progress and progress.counts then
      state.counts = progress.counts
    end
    -- Check if already completed in previous session
    if progress and progress.completed then
      state.completed = true
    end
  end

  -- Save progress to database
  local function SaveProgress()
    HardcoreAchievements_SetProgress(achId, "counts", state.counts)
    if state.completed then
      HardcoreAchievements_SetProgress(achId, "completed", true)
    end
  end

  -- Dynamic names first so functions capture these locals
  local registerFuncName = "HCA_Register" .. achId
  local rowVarName       = achId .. "_Row"

  -- Helpers
  local function GetNpcIdFromGUID(guid)
    if not guid then return nil end
    local npcId = select(6, strsplit("-", guid))
    npcId = npcId and tonumber(npcId) or nil
    return npcId
  end

  local function IsOnRequiredMap()
    -- If no map restriction, allow anywhere
    if requiredMapId == nil then
      return true
    end
    local mapId = select(8, GetInstanceInfo())
    return mapId == requiredMapId
  end

  local function CountsSatisfied()
    for npcId, need in pairs(requiredKills) do
      -- Support both single NPC IDs and arrays of NPC IDs
      local isSatisfied = false
      if type(need) == "table" then
        -- Array of NPC IDs - check if any of them has been killed
        for _, id in pairs(need) do
          if (state.counts[id] or 0) >= 1 then
            isSatisfied = true
            break
          end
        end
      else
        -- Single NPC ID
        if (state.counts[npcId] or 0) >= need then
          isSatisfied = true
        end
      end
      if not isSatisfied then
        return false
      end
    end
    return true
  end

  -- Get boss names from NPC IDs (you can expand this with a lookup table)
  -- Export globally so tooltip function can use it
  function HCA_GetBossName(npcId)
    -- This is a basic mapping - you can expand this with more boss names
    local bossNames = {
      [11520] = "Taragaman the Hungerer",
      [11517] = "Oggleflint", 
      [11518] = "Jergosh the Invoker",
      [11519] = "Bazzalan",
      [644] = "Rhahk'Zor",
      [643] = "Sneed's Shredder",
      [1763] = "Gilnid",
      [646] = "Mr. Smite",
      [647] = "Captain Greenskin",
      [639] = "Edwin VanCleef",
      [3653] = "Kresh",
      [3671] = "Lady Anacondra",
      [3669] = "Lord Cobrahn",
      [3670] = "Lord Pythas",
      [3674] = "Skum",
      [3673] = "Lord Serpentis",
      [5775] = "Verdan the Everliving",
      [3654] = "Mutanus the Devourer",
      [3914] = "Rethilgore",
      [3886] = "Razorclaw the Butcher",
      [3887] = "Baron Silverlaine",
      [4278] = "Commander Springvale",
      [4279] = "Odo the Blindwatcher",
      --[3872] = "Deathsworn Captain",
      [4274] = "Fenrus the Devourer",
      [3927] = "Wolf Master Nandos",
      [4275] = "Archmage Arugal",
      [4887] = "Ghamoo-ra",
      [4831] = "Lady Sarevess",
      [6243] = "Gelihast",
      [12902] = "Lorgus Jett",
      --[12876] = "Baron Aquanis",
      [4832] = "Twilight Lord Kelris",
      [4830] = "Old Serra'kis",
      [4829] = "Aku'mai",
      [1696] = "Targorr the Dread",
      [1666] = "Kam Deepfury",
      [1717] = "Hamhock",
      [1663] = "Dextren Ward",
      [1716] = "Bazil Thredd",
      [7361] = "Grubbis",
      [7079] = "Viscous Fallout",
      [6235] = "Electrocutioner 6000",
      [6229] = "Crowd Pummeler 9-60",
      --[6228] = "Dark Iron Ambassador",
      [7800] = "Mekgineer Thermaplugg",
      [6168] = "Roogug",
      [4424] = "Aggem Thorncurse",
      [4428] = "Death Speaker Jargba",
      [4420] = "Overlord Ramtusk",
      [4422] = "Agathelos the Raging",
      [4421] = "Charlga Razorflank",
      [3983] = "Interrogator Vishas",
      [4543] = "Bloodmage Thalnos",
      [3974] = "Houndmaster Loksey",
      [6487] = "Arcanist Doan",
      [3975] = "Herod",
      [3976] = "Scarlet Commander Mograine",
      [3977] = "High Inquisitor Whitemane",
      [4542] = "High Inquisitor Fairbanks",
      [7355] = "Tuten'kash",
      [7356] = "Plaguemaw the Rotting",
      [7357] = "Mordresh Fire Eye",
      --[7354] = "Ragglesnout",
      [8567] = "Glutton",
      [7358] = "Amnennar the Coldbringer",
      [6910] = "Revelosh",
      --[6906] = "Baelog",
      [7228] = "Ironaya",
      [7023] = "Obsidian Sentinel",
      [7206] = "Ancient Stone Keeper",
      [7291] = "Galgann Firehammer",
      [4854] = "Grimlok",
      [2748] = "Archaedas",
      [13282] = "Noxxion",
      [12258] = "Razorlash",
      [12236] = "Lord Vyletongue",
      [12225] = "Celebras the Cursed",
      [12203] = "Landslide",
      [13601] = "Tinkerer Gizlock",
      [13596] = "Rotgrip",
      [12201] = "Princess Theradras",
      [8127] = "Antu'sul",
      [7272] = "Theka the Martyr",
      [7271] = "Witch Doctor Zum'rah",
      [7796] = "Nekrum Gutchewer",
      [7275] = "Shadowpriest Sezz'ziz",
      [7604] = "Sergeant Bly",
      [7795] = "Hydromancer Velratha",
      [7267] = "Chief Ukorz Sandscalp",
      [7797] = "Ruuzlu",
      [8580] = "Atal'alarion",
      [5721] = "Dreamscythe",
      [5720] = "Weaver",
      [5710] = "Jammal'an the Prophet",
      [5711] = "Ogom the Wretched",
      [5719] = "Morphaz",
      [5722] = "Hazzas",
      [8443] = "Avatar of Hakkar",
      [5709] = "Shade of Eranikus",
      [9025] = "Lord Roccor",
      [9016] = "Bael'Gar",
      [9319] = "Houndmaster Grebmar",
      [9018] = "High Interrogator Gerstahn",
      [10096] = "High Justice Grimstone",
      -- Ring of Law challengers
      [9027] = "Gorosh the Dervish",
      [9028] = "Grizzle",
      [9029] = "Eviscerator",
      [9030] = "Ok'thor the Breaker",
      [9031] = "Anub'shiah",
      [9032] = "Hedrum the Creeper",
      -- Ring of Law challengers
      [9024] = "Pyromancer Loregrain",
      [9033] = "General Angerforge",
      [8983] = "Golem Lord Argelmach",
      [9017] = "Lord Incendius",
      [9056] = "Fineous Darkvire",
      [9041] = "Warder Stilgiss",
      [9042] = "Verek",
      [9156] = "Ambassador Flamelash",
      [9938] = "Magmus",
      [8929] = "Princess Moira Bronzebeard",
      [9019] = "Emperor Dagran Thaurissan",
      [9196] = "Highlord Omokk",
      [9236] = "Shadow Hunter Vosh'gajin",
      [9237] = "War Master Voone",
      [10596] = "Mother Smolderweb",
      [10584] = "Urok Doomhowl",
      [9736] = "Quartermaster Zigris",
      [10268] = "Gizrul the Slavener",
      [10220] = "Halycon",
      [9568] = "Overlord Wyrmthalak",
      [9816] = "Pyroguard Emberseer",
      [10429] = "Warchief Rend Blackhand",
      [10339] = "Gyth",
      [10430] = "The Beast",
      [10363] = "General Drakkisath",
      [11058] = "Ezra Grimm",
      --[10393] = "Skul",
      --[10558] = "Hearthsinger Forresten",
      [10516] = "The Unforgiven",
      --[11143] = "Postmaster Malown",
      [10808] = "Timmy the Cruel",
      [11032] = "Malor the Zealous",
      [10997] = "Cannon Master Willey",
      [11120] = "Crimson Hammersmith",
      [10811] = "Archivist Galford",
      [10813] = "Balnazzar",
      [10435] = "Magistrate Barthilas",
      --[10809] = "Stonespine",
      [10437] = "Nerub'enkan",
      [11121] = "Black Guard Swordsmith",
      [10438] = "Maleki the Pallid",
      [10436] = "Baroness Anastari",
      [10439] = "Ramstein the Gorger",
      [10440] = "Baron Rivendare",
      [14354] = "Pusillin",
      [14327] = "Lethtendris",
      [13280] = "Hydrospawn",
      [11490] = "Zevrim Thornhoof",
      [11492] = "Alzzin the Wildshaper",
      [14326] = "Guard Mol'dar",
      [14322] = "Stomper Kreeg",
      [14321] = "Guard Fengus",
      [14323] = "Guard Slip'kik",
      [14325] = "Captain Kromcrush",
      [14324] = "Cho'Rush the Observer",
      [11501] = "King Gordok",
      [11489] = "Tendris Warpwood",
      [11487] = "Magister Kalendris",
      --[11467] = "Tsu'zee",
      [11488] = "Illyanna Ravenoak",
      [11496] = "Immol'thar",
      [11486] = "Prince Tortheldrin",
      --[10506] = "Kirtonos the Herald",
      [10503] = "Jandice Barov",
      [11622] = "Rattlegore",
      [10433] = "Marduk Blackpool",
      [10432] = "Vectus",
      [10508] = "Ras Frostwhisper",
      [10505] = "Instructor Malicia",
      [11261] = "Doctor Theolen Krastinov",
      [10901] = "Lorekeeper Polkelt",
      [10507] = "The Ravenian",
      [10504] = "Lord Alexei Barov",
      [10502] = "Lady Illucia Barov",
      [1853] = "Darkmaster Gandling",
      -- [1200] = "Morbent Fel", -- Duskwood Achievement
      -- [314] = "Eliza", -- Duskwood Achievement
      -- [522] = "Mor'Ladim", -- Duskwood Achievement
      -- [412] = "Stitches", -- Duskwood Achievement
    }
    return bossNames[npcId] or ("Boss " .. npcId)
  end


  -- Lazy tooltip setup - only initialize when first hovered (optimization)
  local tooltipInitialized = false
  local function CreateTooltipHandler()
    local row = _G[rowVarName]
    if not row then return function() end end
    
    -- Store the base tooltip for the main tooltip
    local baseTooltip = tooltip or ""
    row.tooltip = baseTooltip
    
    -- Ensure mouse events are enabled and highlight texture exists
    row:EnableMouse(true)
    if not row.highlight then
      row.highlight = row:CreateTexture(nil, "BACKGROUND")
      row.highlight:SetAllPoints(row)
      row.highlight:SetColorTexture(1, 1, 1, 0.10)
      row.highlight:Hide()
    end
    
    -- Set up OnLeave script to hide highlight and tooltip
    row:SetScript("OnLeave", function(self)
      if self.highlight then
        self.highlight:Hide()
      end
      GameTooltip:Hide()
    end)
    
    -- Return the tooltip handler function
    return function(self)
        -- Show highlight
        if self.highlight then
          self.highlight:Show()
        end
        
        if self.Title and self.Title.GetText then
          -- Load fresh progress from database before showing tooltip
          LoadProgress()
          
          local achievementCompleted = state.completed or (self.completed == true)
          
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:ClearLines()
          GameTooltip:SetText(title or "", 1, 1, 1)
          -- Level (left) and Points (right) on one line
          -- Use self.points (calculated with multipliers) instead of raw points
          local leftText = (self.maxLevel and self.maxLevel > 0) and (LEVEL .. " " .. tostring(self.maxLevel)) or " "
          local rightText = (self.points and tonumber(self.points) and tonumber(self.points) > 0) and (ACHIEVEMENT_POINTS .. ": " .. tostring(self.points)) or " "
          GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.7, 0.9, 0.7)
          -- Description in default yellow
          GameTooltip:AddLine(baseTooltip, nil, nil, nil, true)
          
          if next(requiredKills) ~= nil then
            GameTooltip:AddLine("\nRequired Bosses:", 0, 1, 0) -- Green header
            
            -- Helper function to process a single boss entry
          local function processBossEntry(npcId, need)
            local done = false
              local bossName = ""
              
              -- Support both single NPC IDs and arrays of NPC IDs
              if type(need) == "table" then
                -- Array of NPC IDs - check if any of them has been killed
                local bossNames = {}
                for _, id in pairs(need) do
                  local current = (state.counts[id] or state.counts[tostring(id)] or 0)
                  local name = HCA_GetBossName(id)
                  table.insert(bossNames, name)
                  -- Mark as done if this boss has been killed (or if achievement is complete)
                  if current >= 1 then
                    done = true
                  end
                end
                -- Use the key as display name for string keys
                if type(npcId) == "string" then
                  -- Use the key as display name for string keys (e.g., "Ring Of Law")
                  bossName = npcId
                else
                  -- For numeric keys, show all names
                  bossName = table.concat(bossNames, " / ")
                end
              else
                -- Single NPC ID
                local idNum = tonumber(npcId) or npcId
                local current = (state.counts[idNum] or state.counts[tostring(idNum)] or 0)
                bossName = HCA_GetBossName(idNum)
                -- Mark as done if this boss has been killed enough times (or if achievement is complete)
                done = current >= (tonumber(need) or 1)
              end
              
              -- If achievement is complete, all bosses show as done
              if achievementCompleted then
                done = true
              end
              
              if done then
                GameTooltip:AddLine(bossName, 1, 1, 1) -- White for completed
              else
                GameTooltip:AddLine(bossName, 0.5, 0.5, 0.5) -- Gray for not completed
              end
            end
            
            -- Use ordered display if provided, otherwise use pairs
            if bossOrder then
              for _, npcId in ipairs(bossOrder) do
                local need = requiredKills[npcId]
                if need then
                  processBossEntry(npcId, need)
                end
              end
            else
              for npcId, need in pairs(requiredKills) do
                processBossEntry(npcId, need)
              end
            end
          end
          -- Hint for linking the achievement in chat
          GameTooltip:AddLine("\nShift click to link in chat\nor add to tracking list", 0.5, 0.5, 0.5)
          
          GameTooltip:Show()
        end
      end
    end

  -- Lazy tooltip handler - initializes on first hover
  local tooltipHandler = nil
  local function GetTooltipHandler()
    if not tooltipHandler then
      tooltipHandler = CreateTooltipHandler()
    end
    return tooltipHandler
  end

  -- Update tooltip when progress changes (triggers lazy re-initialization on next hover)
  local function UpdateTooltip()
    -- Mark as needing update - tooltip will be re-initialized on next hover
    tooltipInitialized = false
    tooltipHandler = nil
  end

  local function IsGroupEligible()
    if IsInRaid() then return false end
    local members = GetNumGroupMembers()
    
    -- Check max party size (from variation or default to 5)
    local maxPartySize = def.maxPartySize or 5
    if members > maxPartySize then return false end

    -- Check if we're in an instance and have stored entry levels for this map
    local inInstance, instanceType = IsInInstance()
    local currentMapId = inInstance and select(8, GetInstanceInfo())
    local useEntryLevels = inInstance and instanceType == "party" and currentMapId and currentMapId == requiredMapId and instanceEntryLevels[currentMapId]
    
    local function overLeveled(unit, unitLevel)
      return (unitLevel and unitLevel > level)
    end

    -- Always use stored entry levels if in an instance, otherwise use current levels
    if useEntryLevels then
      -- We're in a tracked instance - must use stored levels only
      local entryData = instanceEntryLevels[currentMapId]
      
      -- Check player level (must use stored level)
      local playerLevel = entryData.playerLevel
      if not playerLevel or overLeveled("player", playerLevel) then return false end
      
      -- Check party member levels (must use stored levels only)
      if members > 1 then
        for i = 1, 4 do
          local u = "party"..i
          if UnitExists(u) then
            local guid = UnitGUID(u)
            if guid then
              local partyLevel = entryData.partyLevels and entryData.partyLevels[guid]
              -- If we don't have stored level for this party member, they shouldn't be eligible
              -- (they should have been added when they entered)
              if not partyLevel or overLeveled(u, partyLevel) then
                return false
              end
            else
              -- No GUID - disqualify
              return false
            end
          end
        end
      end
    else
      -- Not in a tracked instance - use current levels (fallback for non-instance scenarios)
      local playerLevel = UnitLevel("player")
      if overLeveled("player", playerLevel) then return false end
      
      if members > 1 then
        for i = 1, 4 do
          local u = "party"..i
          if UnitExists(u) and overLeveled(u, UnitLevel(u)) then
            return false
          end
        end
      end
    end
    return true
  end

  -- Create the tracker function dynamically
  local function KillTracker(destGUID)
    if not IsOnRequiredMap() then 
      return false 
    end

    if state.completed then 

      return false 
    end

    local npcId = GetNpcIdFromGUID(destGUID)
    
    if npcId then
      -- Check if this is a required boss first
      local isRequiredBoss = false
      -- Support both single NPC IDs and arrays of NPC IDs
      if requiredKills[npcId] then
        isRequiredBoss = true
      else
        -- Check if this NPC ID is in any array
        for key, value in pairs(requiredKills) do
          if type(value) == "table" then
            for _, id in pairs(value) do
              if id == npcId then
                isRequiredBoss = true
                break
              end
            end
            if isRequiredBoss then break end
          end
        end
      end
      
      if isRequiredBoss then
        -- Check group eligibility BEFORE counting the kill
        -- Only count kills when group is eligible - allows returning later with eligible group
        local isEligible = IsGroupEligible()
        if isEligible then
          -- Group is eligible - count this kill
          if requiredKills[npcId] then
            -- Direct lookup for single NPC ID
            if type(requiredKills[npcId]) == "table" then
              -- This is an array entry - increment the actual killed NPC ID
              state.counts[npcId] = (state.counts[npcId] or 0) + 1
            else
              -- Single NPC ID with count requirement
              state.counts[npcId] = (state.counts[npcId] or 0) + 1
            end
          else
            -- Check if this NPC ID is in any array
            for key, value in pairs(requiredKills) do
              if type(value) == "table" then
                for _, id in pairs(value) do
                  if id == npcId then
                    state.counts[npcId] = (state.counts[npcId] or 0) + 1
                    break
                  end
                end
              end
            end
          end
          
          -- Dungeons do not support solo points - store regular points only
          if AchievementPanel and AchievementPanel.achievements then
            local rowVarName = achId .. "_Row"
            local row = _G[rowVarName]
            if row and row.points then
              -- Store pointsAtKill WITHOUT the self-found bonus.
              -- Recompute from base/original points so we don't rely on subtracting a (now dynamic) bonus.
              local base = tonumber(row.originalPoints) or tonumber(row.points) or 0
              local pointsToStore = base
              if not row.staticPoints then
                local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                pointsToStore = math.floor(base * multiplier + 0.5)
              end
              HardcoreAchievements_SetProgress(achId, "pointsAtKill", pointsToStore)
            end
          end
          
          SaveProgress() -- Save progress after each eligible kill
          UpdateTooltip() -- Update tooltip to show progress
          print("|cff008066[Hardcore Achievements]|r |cffffd100" .. HCA_GetBossName(npcId) .. " killed as part of achievement: " .. title .. "|r")
        else
          -- Group is ineligible - don't count this kill
          -- Player can return later with an eligible group to kill this boss
          -- Only print message if the achievement is still available (not completed or failed) and visible
          local progress = HardcoreAchievements_GetProgress(achId)
          local isStillAvailable = not state.completed and not (progress and progress.failed)
          if isStillAvailable and _G.HCA_IsAchievementVisible and _G.HCA_IsAchievementVisible(achId) then
            print("|cff008066[Hardcore Achievements]|r |cffffd100" .. HCA_GetBossName(npcId) .. " killed but group is ineligible - kill not counted for achievement: " .. title .. "|r")
          end
        end
      end
    end

    -- Check if achievement should be completed
    local progress = HardcoreAchievements_GetProgress(achId)
    if progress and progress.completed then
      state.completed = true
      return true
    end
    
    -- Check if all bosses are killed
    if CountsSatisfied() then
      -- Since we only count kills when group is eligible (using entry levels when in instance),
      -- if CountsSatisfied() is true, all bosses were killed while eligible
      state.completed = true
      HardcoreAchievements_SetProgress(achId, "completed", true)
      return true
    end

    return false
  end

  -- Tracker function is passed directly to CreateAchievementRow and stored on row.killTracker

  -- Register functions in local registry to reduce global pollution
  if _G.HardcoreAchievements_RegisterAchievementFunction then
    _G.HardcoreAchievements_RegisterAchievementFunction(achId, "Kill", KillTracker)
    _G.HardcoreAchievements_RegisterAchievementFunction(achId, "IsCompleted", function() return state.completed end)
  end

  -- Check faction eligibility
  local function IsEligible()
    -- Faction: "Alliance" / "Horde"
    if faction and select(2, UnitFactionGroup("player")) ~= faction then
      return false
    end
    return true
  end

  -- Create the registration function dynamically
  _G[registerFuncName] = function()
    if not _G.CreateAchievementRow or not _G.AchievementPanel then return end
    if _G[rowVarName] then return end
    
    -- Check if player is eligible for this achievement
    if not IsEligible() then return end
    
    -- Note: Variations are always registered, but filtered in ApplyFilter based on checkbox states

    -- Load progress from database
    LoadProgress()

    -- Ensure dungeons never have allowSoloDouble enabled
    local dungeonDef = def or {}
    dungeonDef.allowSoloDouble = false
    dungeonDef.isDungeon = true
    
    _G[rowVarName] = CreateAchievementRow(
      AchievementPanel,
      achId,
      title,
      tooltip,  -- Use the original tooltip string
      icon,
      level,
      points,
      KillTracker,  -- Use the local function directly
      requiredQuestId,
      staticPoints,
      nil,
      dungeonDef  -- Pass def with allowSoloDouble forced to false for dungeons
    )
    
    -- Store requiredKills on the row for the embed UI to access
    if requiredKills and next(requiredKills) then
      _G[rowVarName].requiredKills = requiredKills
    end
    
    -- Refresh points with multipliers after creation
    if RefreshAllAchievementPoints then
      RefreshAllAchievementPoints()
    end
    
    -- Set up lazy tooltip initialization - only set up handlers on first hover
    local row = _G[rowVarName]
    if row then
      row:EnableMouse(true)
      -- Lazy OnEnter handler - creates tooltip handler on first hover
      row:SetScript("OnEnter", function(self)
        GetTooltipHandler()(self)
      end)
      -- OnLeave handler
      row:SetScript("OnLeave", function(self)
        if self.highlight then
          self.highlight:Hide()
        end
        GameTooltip:Hide()
      end)
    end
  end

  -- Auto-register the achievement immediately if the panel is ready
  if _G.CreateAchievementRow and _G.AchievementPanel then
    _G[registerFuncName]()
  end

  -- Note: Event handling is now centralized in HardcoreAchievements.lua
  -- Individual event frames removed for performance
end

-- Function to register dungeon variations
-- Note: Variations are always registered, but filtered in ApplyFilter based on checkbox states
function DungeonCommon.registerDungeonVariations(baseDef)
  -- Only create variations for dungeons up to 60
  if baseDef.level > 57 then
    return
  end
  
  -- Always register all variations (they will be filtered in display logic based on checkbox states)
  local trioDef = CreateVariation(baseDef, VARIATIONS[1])
  DungeonCommon.registerDungeonAchievement(trioDef)
  
  local duoDef = CreateVariation(baseDef, VARIATIONS[2])
  DungeonCommon.registerDungeonAchievement(duoDef)
  
  local soloDef = CreateVariation(baseDef, VARIATIONS[3])
  DungeonCommon.registerDungeonAchievement(soloDef)
end

-- Function to refresh variation registrations (for when checkboxes change)
-- This forces re-registration of variation achievements by clearing their row variables
function DungeonCommon.refreshDungeonVariations()
  if not _G.HCA_AchievementDefs then return end
  
  -- Get all base dungeon IDs (those without variation suffixes)
  local baseDungeonIds = {}
  for achId, def in pairs(_G.HCA_AchievementDefs) do
    if not def.isVariation and def.mapID then  -- Dungeons have mapID
      table.insert(baseDungeonIds, achId)
    end
  end
  
  -- Re-register variations for each base dungeon
  -- First, clear existing variation rows so they can be re-registered
  for _, baseId in ipairs(baseDungeonIds) do
    for _, variation in ipairs(VARIATIONS) do
      local variationId = baseId .. variation.suffix
      local rowVarName = variationId .. "_Row"
      if _G[rowVarName] then
        -- Hide and clear the row so it can be re-registered
        _G[rowVarName]:Hide()
        _G[rowVarName] = nil
      end
    end
  end
  
  -- Re-trigger registration by calling register functions
  -- This will check checkbox states and register accordingly
  for _, baseId in ipairs(baseDungeonIds) do
    for _, variation in ipairs(VARIATIONS) do
      local variationId = baseId .. variation.suffix
      local registerFuncName = "HCA_Register" .. variationId
      if _G[registerFuncName] and type(_G[registerFuncName]) == "function" then
        _G[registerFuncName]()
      end
    end
  end
end

-- Export function to check if player is currently in a dungeon or raid instance
-- This is used to prevent achievements from being marked as failed when leveling up inside
function DungeonCommon.IsInDungeonOrRaid()
    return isInDungeonOrRaid
end

-- Export function to check if player is currently in a specific dungeon (by mapId)
function DungeonCommon.IsInDungeon(mapId)
    if not mapId then return false end
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "party" then
        local currentMapId = select(8, GetInstanceInfo())
        return currentMapId == mapId
    end
    return false
end

-- Export the functions globally for use in IsRowOutleveled
_G.HCA_IsInDungeonOrRaid = DungeonCommon.IsInDungeonOrRaid
_G.HCA_IsInDungeon = DungeonCommon.IsInDungeon

_G.DungeonCommon = DungeonCommon