local addonName, addon = ...
local REQUIRED_MAP_ID = 48 -- Blackfathom Deeps map id
local MAX_LEVEL = 30

local ClassColor = (addon and addon.GetClassColor())
local achId = "FourCandle"
local title = "Four Candles"
local tooltip = "Light all four candles at once within " .. ClassColor .. "Blackfathom Deeps|r and survive before any party member reaches level 31"
local icon = 133750
local level = MAX_LEVEL
local points = 25
local targetNpcId = nil
local REQUIRED_QUEST_ID = 971  -- Quest ID for Four Candles (export on addon for other modules if needed)
if addon then addon.FourCandle = REQUIRED_QUEST_ID end
local requiredQuestId = REQUIRED_QUEST_ID
local staticPoints = false
local zone = "Blackfathom Deeps"

-- Required kills (NPC ID => count)
local REQUIRED = {
  [4978] = 2,  -- Aku'mai Servant x2
  [4825] = 3,  -- Aku'mai Snapjaw x3
  [4823] = 4,  -- Barbed Crustacean x4
  [4977] = 10, -- Murkshallow Softshell x10
}

-- State for the current combat session only
local state = {
  counts = {},           -- npcId => kills this combat
  completed = false,     -- set true once achievement conditions met in this combat
  inCombat = false,
  attemptActive = false, -- true once we've seen at least one required kill while eligible
}
local processedKillTokens = {}

-- Helpers
local function GetNpcIdFromGUID(guid)
  if not guid then return nil end
  local npcId = select(6, strsplit("-", guid))
  npcId = npcId and tonumber(npcId) or nil
  return npcId
end

local function IsOnRequiredMap()
  local mapId = select(8, GetInstanceInfo())
  return mapId == REQUIRED_MAP_ID
end

local function ResetState()
  state.counts = {}
  state.completed = false
  state.attemptActive = false
  processedKillTokens = {}
end

local function CountsSatisfied()
  for npcId, need in pairs(REQUIRED) do
    if (state.counts[npcId] or 0) < need then
      return false
    end
  end
  return true
end

local function IsGroupEligible()
  if IsInRaid() then return false end
  local members = GetNumGroupMembers()
  if members > 5 then return false end

  local function overLeveled(unit)
    local lvl = UnitLevel(unit)
    return (lvl and lvl > MAX_LEVEL)
  end

  if overLeveled("player") then return false end
  if members > 1 then
    for i = 1, 4 do
      local u = "party"..i
      if UnitExists(u) and overLeveled(u) then
        return false
      end
    end
  end
  return true
end

-- local function IsFeigningDeath()
--   for i = 1, 40 do
--     local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
--     if not name then break end
--     if spellId == 5384 or name == "Feign Death" then
--       return true
--     end
--   end
--   return false
-- end

-- local function IsStealthing()
--   for i = 1, 40 do
--     local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
--     if not name then break end
--     if spellId == 1784 or spellId == 1785 or spellId == 1786 or spellId == 1787 or name == "Stealth" then
--       return true
--     end
--   end
--   return false
-- end

local function IsPartyInCombat()
  local members = GetNumGroupMembers()
  if members == 0 then return UnitAffectingCombat("player") end
  for i = 1, 4 do
    local u = "party"..i
    if UnitExists(u) and UnitAffectingCombat(u) then
      return true
    end
  end
  return false
end

-- Kill sync helpers (mirrors DungeonCommon pattern for cross-player credit)
local function BuildKillToken(destGUID, npcId)
  if destGUID and destGUID ~= "" then
    return tostring(destGUID)
  end
  if npcId then
    return tostring(REQUIRED_MAP_ID) .. ":" .. tostring(achId) .. ":" .. tostring(npcId)
  end
  return nil
end

local function HasProcessedKillToken(killToken)
  return killToken and processedKillTokens[killToken] == true
end

local function MarkKillTokenProcessed(killToken)
  if killToken then
    processedKillTokens[killToken] = true
  end
end

local function ApplyBossKillCredit(npcId, killToken)
  if not npcId or not REQUIRED[npcId] then
    return false
  end
  if killToken and HasProcessedKillToken(killToken) then
    return false
  end
  -- Only accept kills (local or synced) during an active tracked combat for this achievement
  if not state.inCombat then
    return false
  end
  state.counts[npcId] = (state.counts[npcId] or 0) + 1
  MarkKillTokenProcessed(killToken)
  -- If eligible, mark attempt active so failure logging works for synced kills too
  if IsGroupEligible() and not state.attemptActive then
    state.attemptActive = true
  end
  -- If this credit completes the set while eligible, mark completed so IsCompleted reflects it immediately
  if CountsSatisfied() and IsGroupEligible() then
    state.completed = true
  end
  return true
end

local function FourCandle(destGUID)
  if not IsOnRequiredMap() then return false end

  -- Allow counting if player is feigning/Stealthing or party is in combat
  if not UnitAffectingCombat("player") and not UnitIsFeignDeath("player") and not IsStealthed() and not IsPartyInCombat() then
    return false
  end

  state.inCombat = true

  if state.completed then return false end

  local npcId = GetNpcIdFromGUID(destGUID)
  if npcId and REQUIRED[npcId] then
    -- Build token and skip if we've already processed this kill (local or synced)
    local killToken = BuildKillToken(destGUID, npcId)
    if killToken and HasProcessedKillToken(killToken) then
      -- Already counted (via sync or prior local event); still check completion below
    else
      state.counts[npcId] = (state.counts[npcId] or 0) + 1
      if killToken then
        MarkKillTokenProcessed(killToken)
      end
      -- Broadcast so party members without the tag also count it
      if addon and type(addon.SendDungeonBossCreditMessage) == "function" and killToken then
        addon.SendDungeonBossCreditMessage(achId, REQUIRED_MAP_ID, npcId, killToken)
      end
      -- Mark attempt active on first required kill while eligible (quiet start)
      if IsGroupEligible() and not state.attemptActive then
        state.attemptActive = true
      end
    end
  end

  if CountsSatisfied() and IsGroupEligible() then
    state.completed = true
    return true
  end

  return false
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    ResetState()
    state.inCombat = true
    -- Log when tracking starts (first engagement in a required map)
    if IsOnRequiredMap() and addon and addon.EventLogAdd then
      if IsGroupEligible() then
        addon.EventLogAdd("Four Candles tracking started (group |cff00ff00eligible|r)")
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Log failure only for an active attempt (we saw at least one required kill while eligible)
    if state.attemptActive and not state.completed and IsOnRequiredMap() and addon and addon.EventLogAdd then
      addon.EventLogAdd("Four Candles attempt failed: combat ended before all required kills were met")
    end
    -- Only reset if neither player nor party is in combat, and not feigning/Stealthing
    if not UnitIsFeignDeath("player") and not IsStealthed() and not IsPartyInCombat() then
      ResetState()
      state.inCombat = false
    end
  end
end)

-- Register custom IsCompleted so EvaluateCustomCompletions and UI reflect actual completion state
if addon and addon.RegisterCustomAchievement then
  addon.RegisterCustomAchievement(achId, FourCandle, function() return state.completed == true end)
end

-- Register SyncBossKill so party members share kill credit within the same combat session
if addon and addon.RegisterAchievementFunction then
  addon.RegisterAchievementFunction(achId, "SyncBossKill", function(payload, sender)
    if not payload then return false end
    if tostring(payload.achievementId or "") ~= tostring(achId) then return false end
    if tonumber(payload.mapId) ~= tonumber(REQUIRED_MAP_ID) then return false end
    if not IsOnRequiredMap() then return false end

    local npcId = tonumber(payload.npcId)
    local killToken = payload.killToken and tostring(payload.killToken) or nil
    if not npcId or not killToken then return false end
    if not ApplyBossKillCredit(npcId, killToken) then return false end

    if addon and addon.EventLogAdd then
      addon.EventLogAdd("Four Candles kill synced from party: npc " .. tostring(npcId))
    end
    return true
  end)
end

-- Expose this definition so chat link tooltips can resolve details
if addon then
  addon.AchievementDefs = addon.AchievementDefs or {}
  addon.AchievementDefs[tostring(achId)] = {
  achId = achId,
  title = title,
  tooltip = tooltip,
  icon = icon,
  points = points,
  zone = zone,
  mapID = REQUIRED_MAP_ID,
  }
end

local function RegisterFourCandles()
  if not addon or not addon.CreateAchievementRow or not addon.AchievementPanel then return end
  if addon and addon.FourCandle_Row then return end

  -- Create def object with isDungeon flag so it shows with dungeons
  local def = {
    isDungeon = true,
    excludeFromCount = true,  -- Exclude from total count
  }

  if addon then addon.FourCandle_Row = addon.CreateAchievementRow(
    addon.AchievementPanel,
    achId,
    title,
    tooltip,
    icon,
    level,
    points,
    FourCandle,  -- killTracker (custom completion function)
    nil,  -- No quest tracker
    staticPoints,
    zone,
    def
  ) end
end

local pendingEligibilityCheck = false

local function TryPrintFourCandlesEligibility()
  if not pendingEligibilityCheck then return end
  pendingEligibilityCheck = false
  if IsOnRequiredMap() and addon and addon.EventLogAdd then
    if IsGroupEligible() then
      addon.EventLogAdd("Dungeon entered: group is |cff00ff00eligible|r for achievement: Four Candles")
    else
      addon.EventLogAdd("Dungeon entered: group is |cffff0000ineligible|r for achievement: Four Candles")
    end
  end
end

local fc_reg = CreateFrame("Frame")
fc_reg:RegisterEvent("PLAYER_LOGIN")
fc_reg:RegisterEvent("ADDON_LOADED")
fc_reg:RegisterEvent("PLAYER_ENTERING_WORLD")
fc_reg:RegisterEvent("UPDATE_INSTANCE_INFO")
fc_reg:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
    RegisterFourCandles()
  elseif event == "PLAYER_ENTERING_WORLD" then
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "party" then
      local mapId = select(8, GetInstanceInfo())
      if mapId == REQUIRED_MAP_ID then
        pendingEligibilityCheck = true
      end
    end
  elseif event == "UPDATE_INSTANCE_INFO" then
    TryPrintFourCandlesEligibility()
  end
end)

if CharacterFrame and CharacterFrame.HookScript then
  CharacterFrame:HookScript("OnShow", RegisterFourCandles)
end