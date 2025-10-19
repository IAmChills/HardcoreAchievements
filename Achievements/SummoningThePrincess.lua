local TARGET_NPC_ID = 2755        -- set to nil for quest-only
local REQUIRED_QUEST_ID = 656     -- set to nil for kill-only
local MAX_LEVEL = 56
local ACH_ID = "SummoningThePrincess"
local FACTION = "Neutral"
local RACE = nil
local CLASS = nil

-- define state BEFORE helpers that use it
local state = {
  completed = false,
  killed = false,
  quest = false,
}

local function RestoreFromProgress()
  if HardcoreAchievements_GetProgress then
    local p = HardcoreAchievements_GetProgress(ACH_ID)
    if p then
      if p.killed ~= nil then state.killed = p.killed end
      if p.quest  ~= nil then state.quest  = p.quest  end
    end
  end
end

do
  local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
  if progress then
    state.killed    = not not progress.killed
    state.quest     = not not progress.quest
    state.completed = not not progress.completed
  else
    -- Optional: seed from server 'truth' on load
    if REQUIRED_QUEST_ID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
      state.quest = C_QuestLog.IsQuestFlaggedCompleted(REQUIRED_QUEST_ID) or false
    elseif REQUIRED_QUEST_ID and IsQuestFlaggedCompleted then
      state.quest = IsQuestFlaggedCompleted(REQUIRED_QUEST_ID) or false
    end
  end
end

local function GetNpcIdFromGUID(guid)
  if not guid then return nil end
  local npcId = select(6, strsplit("-", guid))
  return npcId and tonumber(npcId) or nil
end

local function BelowMax()
  local Level = UnitLevel("player")
  return Level and Level < MAX_LEVEL
end

local function CheckComplete()
  if state.completed then return true end
  local KillComplete   = (not TARGET_NPC_ID)    or state.killed
  local QuestCompleted = (not REQUIRED_QUEST_ID) or state.quest
  if KillComplete and QuestCompleted then
    state.completed = true
    if HardcoreAchievements_SetProgress then
      HardcoreAchievements_SetProgress(ACH_ID, "completed", true)
    end
    return true  -- core will MarkRowCompleted when our tracker returns true
  end
  return false
end

function SummoningThePrincess_Kill(destGUID)
  RestoreFromProgress()
  if state.completed or not BelowMax() then return false end
  if not TARGET_NPC_ID then return false end
  if GetNpcIdFromGUID(destGUID) ~= TARGET_NPC_ID then return false end
  state.killed = true
  if HardcoreAchievements_SetProgress then
    HardcoreAchievements_SetProgress(ACH_ID, "killed", true)
  end
  return CheckComplete()
end

function SummoningThePrincess_Quest(questID)
  RestoreFromProgress()
  if state.completed or not BelowMax() then return false end
  if not REQUIRED_QUEST_ID then return false end
  if questID ~= REQUIRED_QUEST_ID then return false end
  state.quest = true
  if HardcoreAchievements_SetProgress then
    HardcoreAchievements_SetProgress(ACH_ID, "quest", true)
  end
  return CheckComplete()
end

function SummoningThePrincess_IsCompleted()
  return state.completed
end
