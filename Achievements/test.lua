-- Kill-a-Wolf-Before-2 (NPC 299) — super simple achievement tracker
-- Exposes: KillWolfBefore2_OnPartyKill(destGUID) -> boolean
-- Returns true exactly once when the player (still level 1) kills NPC ID 299.

local TARGET_NPC_ID = 299

-- Minimal local state: flip once, never again this session
local state = {
  completed = false,
}

-- Helper copied in spirit from the reference:
-- Creature GUID format: "Creature-0-<serverId>-<instanceId>-<zoneUid>-<npcId>-<spawnUid>"
local function GetNpcIdFromGUID(guid)
  if not guid then return nil end
  local npcId = select(6, strsplit("-", guid))
  return npcId and tonumber(npcId) or nil
end

function KillWolfBefore2_OnPartyKill(destGUID)
  -- Already earned? Never trigger again.
  if state.completed then return false end

  -- Must be before level 2 (i.e., player level is 1)
  local playerLevel = UnitLevel("player")
  if not playerLevel or playerLevel >= 3 then
    return false
  end

  -- Count only the specific wolf NPC
  local npcId = GetNpcIdFromGUID(destGUID)
  if npcId ~= TARGET_NPC_ID then
    return false
  end

  -- Success: mark and fire once
  state.completed = true
  return true
end

-- (Optional) tiny tester helper you can call from /run if needed:
-- /run if KillWolfBefore2_Reset then KillWolfBefore2_Reset() print("wolf reset") end
function KillWolfBefore2_Reset()
  state.completed = false
end
