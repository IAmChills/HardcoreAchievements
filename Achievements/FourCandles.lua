-- FourCandleTracker.lua
-- Tracks "Four Candle" (all specified mobs slain in a single combat) in Blackfathom Deeps (mapId 48).
-- Exposes: FourCandle_OnPartyKill(destGUID) -> boolean (true exactly once when all conditions are met)

local REQUIRED_MAP_ID = 48 -- Blackfathom Deeps map id
local MAX_LEVEL = 30 -- The maximum level any player in the group can be to count this achievement

local achId = "FourCandle"
local title = "Four Candles"
local desc = ("Level %d"):format(30)
local tooltip = "Light all four candles at once within Blackfathom Depths and survive before level 31 (including party members)"
local icon = 133750
local level = 30
local points = 50
local requiredQuestId = _G.FourCandle
local targetNpcId = nil

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
  if IsInRaid() then return false end
  local members = GetNumGroupMembers()
  if members > 5 then return false end

  local function overLeveled(unit)
    local lvl = UnitLevel(unit)
    return (lvl and lvl >= MAX_LEVEL)
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

local function IsFeigningDeath()
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if not name then break end
    if spellId == 5384 or name == "Feign Death" then
      return true
    end
  end
  return false
end

local function IsStealthing()
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if not name then break end
    if spellId == 1784 or spellId == 1785 or spellId == 1786 or spellId == 1787 or name == "Stealth" then
      return true
    end
  end
  return false
end

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

function FourCandle(destGUID)
  if not IsOnRequiredMap() then return false end

  -- Allow counting if player is feigning/Stealthing or party is in combat
  if not UnitAffectingCombat("player") and not IsFeigningDeath() and not IsStealthing() and not IsPartyInCombat() then
    return false
  end

  state.inCombat = true

  if state.completed then return false end

  local npcId = GetNpcIdFromGUID(destGUID)
  if npcId and REQUIRED[npcId] then
    state.counts[npcId] = (state.counts[npcId] or 0) + 1
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
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Only reset if neither player nor party is in combat, and not feigning/Stealthing
    if not IsFeigningDeath() and not IsStealthing() and not IsPartyInCombat() then
      ResetState()
      state.inCombat = false
    end
  end
end)

-- Four Candles self-registration (kept minimal)
_G.FourCandle_IsCompleted = function() return false end

local function HCA_RegisterFourCandles()
  if not _G.CreateAchievementRow or not _G.AchievementPanel then return end
  if _G.FourCandle_Row then return end

  _G.FourCandle_Row = CreateAchievementRow(
    AchievementPanel,
    achId,
    title,
    desc,
    tooltip,
    icon,
    level,
    points,
    requiredQuestId,
    targetNpcId
  )
end

local fc_reg = CreateFrame("Frame")
fc_reg:RegisterEvent("PLAYER_LOGIN")
fc_reg:RegisterEvent("ADDON_LOADED")
fc_reg:SetScript("OnEvent", function()
  HCA_RegisterFourCandles()
end)

if _G.CharacterFrame and _G.CharacterFrame.HookScript then
  CharacterFrame:HookScript("OnShow", HCA_RegisterFourCandles)
end