-- FourCandleTracker.lua
-- Tracks "Four Candle" (all specified mobs slain in a single combat) in Blackfathom Deeps (mapId 48).
-- Exposes: FourCandle_OnPartyKill(destGUID) -> boolean (true exactly once when all conditions are met)

local REQUIRED_MAP_ID = 48 -- Blackfathom Deeps map id
local MAX_LEVEL = 25 -- The maximum level any player in the group can be to count this achievement

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
}

-- Helpers
local function GetNpcIdFromGUID(guid)
  if not guid then return nil end
  -- Creature GUID format: "Creature-0-<serverId>-<instanceId>-<zoneUid>-<npcId>-<spawnUid>"
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
  -- If in a raid -> not eligible; also ensure party size ≤ 5.
  if IsInRaid() then return false end

  -- GetNumGroupMembers() includes the player in parties.
  local members = GetNumGroupMembers() -- 0 if solo, else 2..5 in a party
  if members > 5 then return false end

  -- Check levels: player + up to 4 party members
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

function FourCandle_OnPartyKill(destGUID)
  -- Early outs that keep this dirt cheap and safe to call every PARTY_KILL
  if not IsOnRequiredMap() then return false end

  -- Must be in a single continuous combat session
  if not UnitAffectingCombat("player") then
    -- Not in combat: ensure we don't accumulate kills across pulls
    return false
  end

  -- Track that we are in combat for this session
  state.inCombat = true

  -- If we already finished this session, just say no further triggers
  if state.completed then return false end

  -- Only count required mobs
  local npcId = GetNpcIdFromGUID(destGUID)
  if npcId and REQUIRED[npcId] then
    state.counts[npcId] = (state.counts[npcId] or 0) + 1
  end

  -- Check completion on every relevant kill
  if CountsSatisfied() and IsGroupEligible() then
    state.completed = true
    return true
  end

  return false
end

-- Lightweight event hook to reset between combats
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED") -- entered combat
f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- left combat
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    ResetState()
    state.inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    ResetState()
    state.inCombat = false
  end
end)
