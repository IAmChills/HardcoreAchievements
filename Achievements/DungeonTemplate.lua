local REQUIRED_MAP_ID = 48 -- The map ID where the achievement is valid
local MAX_LEVEL = 30 -- The maximum level any player in the group can be to count this achievement

local achId = "DungeonTemplate" -- Unique identifier for the achievement
local title = "Dungeon Template" -- Display name of the achievement
local desc = ("Level %d"):format(MAX_LEVEL) -- Description of the achievement
local tooltip = "Template for dungeon achievements" -- Tooltip text
local icon = 133750 -- Icon texture for the achievement
local level = MAX_LEVEL -- Level requirement
local points = 50 -- Points awarded for completing the achievement
local requiredQuestId = nil -- Quest ID required for the achievement
local targetNpcId = nil -- NPC ID required for the achievement

-- Required kills (NPC ID => count)
local REQUIRED = {
  [123456] = 2,  -- NPC ID x2
}

-- State for the current achievement session only
local state = {
  counts = {},           -- npcId => kills this achievement
  completed = false,     -- set true once achievement conditions met in this achievement
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

function DungeonTemplate(destGUID)
  if not IsOnRequiredMap() then return false end

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

_G.DungeonTemplate_IsCompleted = function() return false end

local function HCA_RegisterDungeonTemplate()
  if not _G.CreateAchievementRow or not _G.AchievementPanel then return end
  if _G.DungeonTemplate_Row then return end

  _G.DungeonTemplate_Row = CreateAchievementRow(
    AchievementPanel,
    achId,
    title,
    desc,
    tooltip,
    icon,
    level,
    points,
    DungeonTemplate,
    requiredQuestId
  )
end

local dt_reg = CreateFrame("Frame")
dt_reg:RegisterEvent("PLAYER_LOGIN")
dt_reg:RegisterEvent("ADDON_LOADED")
dt_reg:SetScript("OnEvent", function()
  HCA_RegisterDungeonTemplate()
end)

if _G.CharacterFrame and _G.CharacterFrame.HookScript then
  CharacterFrame:HookScript("OnShow", HCA_RegisterDungeonTemplate)
end