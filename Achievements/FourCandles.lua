local addonName, addon = ...
local REQUIRED_MAP_ID = 48 -- Blackfathom Deeps map id
local MAX_LEVEL = 70

local ClassColor = (addon and addon.GetClassColor())
local achId = "FourCandle"
local title = "Four Candles"
local tooltip = "Light all four candles at once within " .. ClassColor .. "Blackfathom Deeps|r and survive before any party member reaches level 31"
local icon = 133750
local level = MAX_LEVEL
local points = 25
local staticPoints = false
local zone = "Blackfathom Deeps"

-- Required kills (NPC ID => count). Display order matters for tooltip/tracker.
local NPC_ORDER = { 4978, 4825, 4823, 4977, 4809, 4810 }
local NPC_NAMES = {
  [4978] = "Aku'mai Servant",
  [4825] = "Aku'mai Snapjaw",
  [4823] = "Barbed Crustacean",
  [4977] = "Murkshallow Softshell",
  -- Temporary test NPC (kept named so tooltips stay accurate while debugging)
  [4809] = "Twilight Acolyte",
  [4810] = "Twilight Reaver",
}
local REQUIRED = {
  [4978] = 2,  -- Aku'mai Servant x2
  [4825] = 3,  -- Aku'mai Snapjaw x3
  [4823] = 4,  -- Barbed Crustacean x4
  [4977] = 10, -- Murkshallow Softshell x10
  -- Temporary test NPC (kept named so tooltips stay accurate while debugging)
  --[4809] = 2, -- Twilight Acolyte x2
  --[4810] = 1, -- Twilight Reaver x1
}

-- State for the current combat session only
local state = {
  counts = {},           -- npcId => kills this combat
  completed = false,     -- set true once achievement conditions met in this combat
  inCombat = false,
  attemptActive = false, -- true once we've seen at least one required kill while eligible
  logAttemptId = nil,    -- scopes event-log upsert keys to this attempt
}
local processedKillTokens = {}

-- Helpers
local function GetNpcIdFromGUID(guid)
  if not guid then return nil end
  local npcId = select(6, strsplit("-", guid))
  npcId = npcId and tonumber(npcId) or nil
  return npcId
end

local function GetNpcDisplayName(npcId)
  return NPC_NAMES[npcId] or NPC_NAMES[tostring(npcId)] or ("NPC " .. tostring(npcId))
end

local function IsOnRequiredMap()
  local mapId = select(8, GetInstanceInfo())
  return mapId == REQUIRED_MAP_ID
end

local function NotifyProgressChanged()
  if addon and addon.AchievementTracker and type(addon.AchievementTracker.Update) == "function" then
    addon.AchievementTracker:Update()
  elseif addon and type(addon.UpdateTracker) == "function" then
    addon.UpdateTracker(addon.AchievementTracker)
  end
end

local function IsAchievementCompletedPersisted()
  if state.completed then return true end
  if addon and addon.GetProgress then
    local progress = addon.GetProgress(achId)
    if progress and progress.completed then return true end
  end
  local row = addon and addon.GetAchievementRow and addon.GetAchievementRow(achId)
  if row and row.completed then return true end
  return false
end

local function EnsureFulfilledCounts()
  for npcId, need in pairs(REQUIRED) do
    local current = state.counts[npcId] or 0
    if current < need then
      state.counts[npcId] = need
    end
  end
end

local function ClearAttemptTracking()
  state.attemptActive = false
  state.logAttemptId = nil
  processedKillTokens = {}
end

-- Full wipe used for failed / abandoned attempts (not when the achievement is complete).
local function ResetState()
  state.counts = {}
  state.completed = false
  ClearAttemptTracking()
  NotifyProgressChanged()
end

-- Entering a new combat: never wipe a completed achievement's fulfilled counts.
local function ResetStateForNewCombat()
  if IsAchievementCompletedPersisted() then
    state.completed = true
    EnsureFulfilledCounts()
    ClearAttemptTracking()
    NotifyProgressChanged()
    return
  end
  ResetState()
end

-- Leaving combat: keep fulfilled counts on success; clear only on failure.
local function FinalizeCombatState()
  if state.completed or IsAchievementCompletedPersisted() then
    state.completed = true
    EnsureFulfilledCounts()
    ClearAttemptTracking()
    state.inCombat = false
    NotifyProgressChanged()
    return
  end
  ResetState()
  state.inCombat = false
end

local function GetDisplayKillCounts()
  if IsAchievementCompletedPersisted() then
    local counts = {}
    for npcId, need in pairs(REQUIRED) do
      local current = state.counts[npcId] or 0
      counts[npcId] = (current >= need) and current or need
    end
    return counts
  end
  return state.counts
end

local function CountsSatisfied()
  for npcId, need in pairs(REQUIRED) do
    if (state.counts[npcId] or 0) < need then
      return false
    end
  end
  return true
end

local function IterRequiredNpcs(callback)
  local seen = {}
  for _, npcId in ipairs(NPC_ORDER) do
    if REQUIRED[npcId] and not seen[npcId] then
      seen[npcId] = true
      callback(npcId, REQUIRED[npcId])
    end
  end
  for npcId, need in pairs(REQUIRED) do
    if not seen[npcId] then
      callback(npcId, need)
    end
  end
end

local function FormatNpcProgressMsg(npcId)
  local need = REQUIRED[npcId] or 1
  local current = state.counts[npcId] or 0
  if current > need then current = need end
  local name = GetNpcDisplayName(npcId)
  local progress = name .. " " .. tostring(current) .. "/" .. tostring(need)
  local color = (current >= need) and "ff00ff00" or "ffff0000"
  return "Four Candles - |c" .. color .. progress .. "|r"
end

local function UpsertNpcProgressLog(npcId)
  if not npcId or not REQUIRED[npcId] or not state.logAttemptId then return end
  if not (addon and addon.EventLogUpsert) then return end
  local key = "FourCandle:" .. tostring(state.logAttemptId) .. ":" .. tostring(npcId)
  addon.EventLogUpsert(key, FormatNpcProgressMsg(npcId))
end

local function SeedAttemptProgressLogs()
  if not state.logAttemptId then return end
  IterRequiredNpcs(function(npcId, _)
    UpsertNpcProgressLog(npcId)
  end)
end

local function LogAttemptFailure()
  if addon and addon.EventLogAdd then
    addon.EventLogAdd("Four Candles attempt failed: combat ended before all required kills were met")
  end
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

local function MarkAttemptActiveIfEligible()
  if state.attemptActive or not IsGroupEligible() then
    return
  end
  state.attemptActive = true
  state.logAttemptId = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
  -- Only log once the first required candle-mob kill is seen (avoids spam on trash pulls)
  if addon and addon.EventLogAdd then
    addon.EventLogAdd("Four Candles tracking started (group |cff00ff00eligible|r)")
  end
  -- Seed one amendable progress line per required NPC (starts at 0/need, then updates on kills)
  SeedAttemptProgressLogs()
end

local function RegisterKillCredit(npcId)
  state.counts[npcId] = (state.counts[npcId] or 0) + 1
  MarkAttemptActiveIfEligible()
  UpsertNpcProgressLog(npcId)
  NotifyProgressChanged()
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
  MarkKillTokenProcessed(killToken)
  RegisterKillCredit(npcId)
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
      if killToken then
        MarkKillTokenProcessed(killToken)
      end
      -- Broadcast so party members without the tag also count it
      if addon and type(addon.SendDungeonBossCreditMessage) == "function" and killToken then
        addon.SendDungeonBossCreditMessage(achId, REQUIRED_MAP_ID, npcId, killToken)
      end
      RegisterKillCredit(npcId)
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
    ResetStateForNewCombat()
    state.inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Log failure only for an active attempt (we saw at least one required kill while eligible)
    if state.attemptActive and not state.completed and IsOnRequiredMap() then
      -- Keep progress lines at last known counts, then log a short failure reason
      IterRequiredNpcs(function(npcId, _)
        UpsertNpcProgressLog(npcId)
      end)
      LogAttemptFailure()
    end
    -- Only finalize if neither player nor party is in combat, and not feigning/Stealthing
    if not UnitIsFeignDeath("player") and not IsStealthed() and not IsPartyInCombat() then
      FinalizeCombatState()
    end
  end
end)

-- Register custom IsCompleted so EvaluateCustomCompletions and UI reflect actual completion state
if addon and addon.RegisterCustomAchievement then
  addon.RegisterCustomAchievement(achId, FourCandle, function()
    return state.completed == true or IsAchievementCompletedPersisted()
  end)
end

-- Live combat-session kill counts for tooltip/tracker.
-- Completed achievements keep fulfilled counts (like dungeon bosses); failures clear them.
if addon and addon.RegisterAchievementFunction then
  addon.RegisterAchievementFunction(achId, "GetKillCounts", function()
    return GetDisplayKillCounts()
  end)
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
    -- ApplyBossKillCredit already upserts the shared per-NPC progress log line
    return ApplyBossKillCredit(npcId, killToken)
  end)
end

-- Expose this definition so chat link tooltips / NPC tooltips can resolve details
if addon then
  addon.AchievementDefs = addon.AchievementDefs or {}
  addon.AchievementDefs[tostring(achId)] = {
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    level = level,
    zone = zone,
    mapID = REQUIRED_MAP_ID,
    requiredKills = REQUIRED, -- Used by NPC tooltip index
    bossOrder = NPC_ORDER,
    npcNames = NPC_NAMES,
    requiredKillHeader = "Required NPCs",
    showRequiredKillCounts = true,
    -- Four Candles still requires the whole group under the level cap
    requirePartyLevels = true,
    excludeFromCount = true, -- Separate enter message from BFD clear chain
    isDungeon = true,
  }
end

local function RegisterFourCandles()
  if not addon or not addon.CreateAchievementRow or not addon.AchievementPanel then return end
  if addon and addon.FourCandle_Row then return end

  -- Create def object with isDungeon flag so it shows with dungeons
  local def = {
    isDungeon = true,
    excludeFromCount = true,  -- Exclude from total count
    requiredKills = REQUIRED,
    bossOrder = NPC_ORDER,
    npcNames = NPC_NAMES,
    requiredKillHeader = "Required NPCs",
    showRequiredKillCounts = true,
    requiredMapId = REQUIRED_MAP_ID,
    mapID = REQUIRED_MAP_ID,
    requirePartyLevels = true,
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

-- Enter eligibility chat/event-log is handled by DungeonCommon for all map achievements.

local fc_reg = CreateFrame("Frame")
fc_reg:RegisterEvent("PLAYER_LOGIN")
fc_reg:RegisterEvent("ADDON_LOADED")
fc_reg:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
    RegisterFourCandles()
  end
end)

if CharacterFrame and CharacterFrame.HookScript then
  CharacterFrame:HookScript("OnShow", RegisterFourCandles)
end
