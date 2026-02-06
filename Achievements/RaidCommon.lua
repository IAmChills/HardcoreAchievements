local RaidCommon = {}

local addonName, addon = ...
local UnitLevel = UnitLevel
local GetInstanceInfo = GetInstanceInfo
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetPresetMultiplier = (addon and addon.GetPresetMultiplier)
local RefreshAllAchievementPoints = (addon and addon.RefreshAllAchievementPoints)
local table_insert = table.insert
local table_concat = table.concat

-- Mapping from encounter IDs (as reported by BOSS_KILL event) to NPC IDs
-- This allows us to track boss kills even when the kill is delivered by someone outside your party
local ENCOUNTER_ID_TO_NPC_IDS = {
  -- Lower Blackrock Spire
  [276] = {9816},   -- Pyroguard Emberseer
  [278] = {10429, 10339},  -- Warchief Rend Blackhand / Gyth (both use 278)
  [279] = {10430},  -- The Beast
  [280] = {10363},  -- General Drakkisath
  
  -- Molten Core
  [663] = {12118},  -- Lucifron
  [664] = {11982},  -- Magmadar
  [665] = {12259},  -- Gehennas
  [666] = {12057},  -- Garr
  [667] = {12264},  -- Shazzrah
  [668] = {12056},  -- Baron Geddon
  [669] = {12098},  -- Sulfuron Harbinger
  [670] = {11988},  -- Golemagg the Incinerator
  [671] = {12018},  -- Majordomo Executus
  [672] = {11502},  -- Ragnaros
  
  -- Onyxia's Lair
  [1084] = {10184}, -- Onyxia
  
  -- Blackwing Lair
  [610] = {12435},  -- Razorgore the Untamed
  [611] = {13020},  -- Vaelastrasz the Corrupt
  [612] = {12017},  -- Broodlord Lashlayer
  [613] = {11983},  -- Firemaw
  [614] = {14601},  -- Ebonroc
  [615] = {11981},  -- Flamegor
  [616] = {14020},  -- Chromaggus
  [617] = {11583},  -- Nefarian
  
  -- Zul'Gurub
  [784] = {14507},  -- High Priest Venoxis
  [785] = {14517},  -- High Priestess Jeklik
  [786] = {14510},  -- High Priestess Mar'li
  [787] = {11382},  -- Bloodlord Mandokir
  [788] = {15082, 15083, 15084, 15085},  -- Edge of Madness (Gri'lek, Hazza'rah, Renataki, Wushoolay)
  [789] = {14509},  -- High Priest Thekal
  [790] = {15114},  -- Gahz'ranka
  [791] = {14515},  -- High Priestess Arlokk
  [792] = {11380},  -- Jin'do the Hexxer
  [793] = {14834},  -- Hakkar
  
  -- Ruins of Ahn'Qiraj
  [718] = {15348},  -- Kurinnaxx
  [719] = {15341},  -- General Rajaxx
  [720] = {15340},  -- Moam
  [721] = {15370},  -- Buru the Gorger
  [722] = {15369},  -- Ayamiss the Hunter
  [723] = {15339},  -- Ossirian the Unscarred
  
  -- Temple of Ahn'Qiraj
  [709] = {15263},  -- The Prophet Skeram
  [710] = {15511, 15544, 15543},  -- Silithid Royalty (Lord Kri, Vem, Princess Yauj)
  [711] = {15516},  -- Battleguard Sartura
  [712] = {15510},  -- Fankriss the Unyielding
  [713] = {15299},  -- Viscidus
  [714] = {15509},  -- Princess Huhuran
  [715] = {15276, 15275},  -- Twin Emperors (Vek'lor, Vek'nilash)
  [716] = {15517},  -- Ouro
  [717] = {15727},  -- C'Thun
  
  -- Naxxramas
  [1107] = {15956}, -- Anub'Rekhan
  [1108] = {15932}, -- Gluth
  [1109] = {16060}, -- Gothik the Harvester
  [1110] = {15953}, -- Grand Widow Faerlina
  [1111] = {15931}, -- Grobbulus
  [1112] = {15936}, -- Heigan the Unclean
  [1113] = {16061}, -- Instructor Razuvious
  [1114] = {15990}, -- Kel'Thuzad
  [1115] = {16011}, -- Loatheb
  [1116] = {15952}, -- Maexxna
  [1117] = {15954}, -- Noth the Plaguebringer
  [1118] = {16028}, -- Patchwerk
  [1119] = {15989}, -- Sapphiron
  [1120] = {15928}, -- Thaddius
  [1121] = {16064, 16065, 16062, 16063},  -- The Four Horsemen (Thane Korth'azz, Lady Blaumeux, Highlord Mograine, Sir Zeliek)
}

---------------------------------------
-- Registration Function
---------------------------------------

-- Register a raid achievement with the given definition
local function registerRaidAchievement(def)
  local achId = def.achId
  local title = def.title
  local tooltip = def.tooltip
  local icon = def.icon
  local points = def.points
  local requiredQuestId = def.requiredQuestId
  local staticPoints = def.staticPoints or false
  local requiredMapId = def.requiredMapId
  local requiredKills = def.requiredKills or {}
  local bossOrder = def.bossOrder  -- Optional ordering for tooltip display
  local faction = def.faction

  -- Expose this definition for external lookups (e.g., chat link tooltips)
  addon.RegisterAchievementDef({
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    level = def.level,  -- Will be overridden to nil below
    requiredMapId = def.requiredMapId,
    mapName = def.title,
    requiredKills = requiredKills,
    bossOrder = bossOrder,
    faction = faction,
    isRaid = true,
  }, { level = nil })  -- Raids have no level requirement

  ---------------------------------------
  -- State Management
  ---------------------------------------

  -- State for the current achievement session only
  local state = {
    counts = {},           -- npcId => kills this achievement
    completed = false,     -- set true once achievement conditions met in this achievement
  }

  ---------------------------------------
  -- Helper Functions
  ---------------------------------------

  -- Load progress from database on initialization
  local function LoadProgress()
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
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
    addon.SetProgress(achId, "counts", state.counts)
    if state.completed then
      addon.SetProgress(achId, "completed", true)
    end
  end

  -- Dynamic names first so functions capture these locals
  local registerFuncName = "HCA_Register" .. achId
  local rowVarName       = achId .. "_Row"

  -- Helper function to get NPC IDs from encounter ID
  local function GetNpcIdsFromEncounterID(encounterID)
    if not encounterID then return nil end
    return ENCOUNTER_ID_TO_NPC_IDS[encounterID]
  end

  -- Get boss names from NPC IDs
  -- Export globally so tooltip function can use it
  function HCA_GetRaidBossName(npcId)
    local bossNames = {
      -- Lower Blackrock Spire
      [9816] = "Pyroguard Emberseer",
      [10429] = "Warchief Rend Blackhand",
      [10339] = "Gyth",
      [10430] = "The Beast",
      [10363] = "General Drakkisath",
      -- Molten Core
      [12118] = "Lucifron",
      [11982] = "Magmadar",
      [12259] = "Gehennas",
      [12057] = "Garr",
      [12264] = "Shazzrah",
      [12056] = "Baron Geddon",
      [11988] = "Golemagg the Incinerator",
      [12098] = "Sulfuron Harbinger",
      [12018] = "Majordomo Executus",
      [11502] = "Ragnaros",
      -- Onyxia
      [10184] = "Onyxia",
      -- Blackwing Lair
      [12435] = "Razorgore the Untamed",
      [13020] = "Vaelastrasz the Corrupt",
      [12017] = "Broodlord Lashlayer",
      [11983] = "Firemaw",
      [14601] = "Ebonroc",
      [11981] = "Flamegor",
      [14020] = "Chromaggus",
      [11583] = "Nefarian",
      -- Zul'Gurub
      [14517] = "High Priestess Jeklik",
      [14507] = "High Priest Venoxis",
      [14510] = "High Priestess Mar'li",
      [14509] = "High Priest Thekal",
      [14515] = "High Priestess Arlokk",
      [11382] = "Bloodlord Mandokir",
      -- Edge of Madness
      [15082] = "Gri'lek",
      [15083] = "Hazza'rah",
      [15084] = "Renataki",
      [15085] = "Wushoolay",
      -- Edge of Madness
      [15114] = "Gahz'ranka",
      [11380] = "Jin'do the Hexxer",
      [14834] = "Hakkar",
      -- Ruins of Ahn'Qiraj
      [15348] = "Kurinnaxx",
      [15341] = "General Rajaxx",
      [15340] = "Moam",
      [15370] = "Buru the Gorger",
      [15369] = "Ayamiss the Hunter",
      [15339] = "Ossirian the Unscarred",
      -- Temple of Ahn'Qiraj
      [15263] = "The Prophet Skeram",
      [15511] = "Lord Kri",
      [15544] = "Vem",
      [15543] = "Princess Yauj",
      [15516] = "Battleguard Sartura",
      [15510] = "Fankriss the Unyielding",
      [15509] = "Princess Huhuran",
      [15276] = "Emperor Vek'lor",
      [15275] = "Emperor Vek'nilash",
      [15299] = "Viscidus",
      [15517] = "Ouro",
      [15727] = "C'Thun",
      -- Naxxramas
      [15956] = "Anub'Rekhan",
      [15953] = "Grand Widow Faerlina",
      [15952] = "Maexxna",
      [15954] = "Noth the Plaguebringer",
      [15936] = "Heigan the Unclean",
      [16011] = "Loatheb",
      [16061] = "Instructor Razuvious",
      [16060] = "Gothik the Harvester",
      -- Four Horsemen
      [16064] = "Thane Korth'azz",
      [16065] = "Lady Blaumeux",
      [16062] = "Highlord Mograine",
      [16063] = "Sir Zeliek",
      -- Four Horsemen
      [16028] = "Patchwerk",
      [15931] = "Grobbulus",
      [15932] = "Gluth",
      [15928] = "Thaddius",
      [15989] = "Sapphiron",
      [15990] = "Kel'Thuzad",
    }
    return bossNames[npcId] or ("Boss " .. tostring(npcId))
  end

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

  -- Check if an NPC ID is a required boss for this achievement
  local function IsRequiredBoss(npcId)
    if not npcId then return false end
    -- Direct lookup
    if requiredKills[npcId] then
      return true
    end
    -- Check if this NPC ID is in any array
    for key, value in pairs(requiredKills) do
      if type(value) == "table" then
        for _, id in pairs(value) do
          if id == npcId then
            return true
          end
        end
      end
    end
    return false
  end

  -- Increment kill count for a boss
  local function IncrementBossKill(npcId)
    if not npcId then return end
    state.counts[npcId] = (state.counts[npcId] or 0) + 1
  end

  -- Calculate and store points for this achievement
  local function StorePointsAtKill()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    local row = addon[rowVarName]
    if not row or not row.points then return end
    
    -- Store pointsAtKill WITHOUT the self-found bonus.
    -- Recompute from base/original points so we don't rely on subtracting a (now dynamic) bonus.
    local base = tonumber(row.originalPoints) or tonumber(row.points) or 0
    local pointsToStore = base
    if not row.staticPoints then
      local preset = addon and addon.GetPlayerPresetFromSettings and addon.GetPlayerPresetFromSettings() or nil
      local multiplier = GetPresetMultiplier(preset) or 1.0
      pointsToStore = math.floor(base * multiplier + 0.5)
    end
    addon.SetProgress(achId, "pointsAtKill", pointsToStore)
  end

  -- Update tooltip when progress changes (local; closes over the local generator)
  ---------------------------------------
  -- Tooltip Management
  ---------------------------------------

  local function UpdateTooltip()
    local row = addon[rowVarName]
    if row then
      -- Store the base tooltip for the main tooltip
      local baseTooltip = tooltip or ""
      row.tooltip = baseTooltip

      local frame = row.frame
      if not frame then
        if addon and addon.AddRowUIInit then
          addon.AddRowUIInit(row, function()
            C_Timer.After(0, UpdateTooltip)
          end)
        end
        return
      end
      frame.tooltip = baseTooltip
      
      -- Ensure mouse events are enabled and highlight texture exists
      frame:EnableMouse(true)
      if not frame.highlight then
        frame.highlight = frame:CreateTexture(nil, "BACKGROUND")
        frame.highlight:SetAllPoints(frame)
        frame.highlight:SetColorTexture(1, 1, 1, 0.10)
        frame.highlight:Hide()
      end
      
      -- Process a single boss entry (defined once per UpdateTooltip run, not per hover)
      local function processBossEntry(npcId, need, achievementCompleted)
        local done = false
        local bossName = ""
        if type(need) == "table" then
          local bossNames = {}
          for _, id in pairs(need) do
            local current = (state.counts[id] or state.counts[tostring(id)] or 0)
            local name = HCA_GetRaidBossName(id)
            table_insert(bossNames, name)
            if current >= 1 then done = true end
          end
          if type(npcId) == "string" then
            bossName = npcId
          else
            bossName = table_concat(bossNames, " / ")
          end
        else
          local idNum = tonumber(npcId) or npcId
          local current = (state.counts[idNum] or state.counts[tostring(idNum)] or 0)
          bossName = HCA_GetRaidBossName(idNum)
          done = current >= (tonumber(need) or 1)
        end
        if achievementCompleted then done = true end
        if done then
          GameTooltip:AddLine(bossName, 1, 1, 1)
        else
          GameTooltip:AddLine(bossName, 0.5, 0.5, 0.5)
        end
      end

      -- Override the OnEnter script to use proper GameTooltip API while preserving highlighting
      frame:SetScript("OnEnter", function(self)
        if self.highlight then
          self.highlight:Show()
        end
        if self.Title and self.Title.GetText then
          LoadProgress()
          local achievementCompleted = state.completed or (self.completed == true)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:ClearLines()
          GameTooltip:SetText(title or "", 1, 1, 1)
          local rightText = (self.points and tonumber(self.points) and tonumber(self.points) > 0) and (ACHIEVEMENT_POINTS .. ": " .. tostring(self.points)) or " "
          GameTooltip:AddDoubleLine(" ", rightText, 1, 1, 1, 0.7, 0.9, 0.7)
          GameTooltip:AddLine(baseTooltip, nil, nil, nil, true)
          if next(requiredKills) ~= nil then
            GameTooltip:AddLine("\nRequired Bosses:", 0, 1, 0)
            if bossOrder then
              for _, npcId in ipairs(bossOrder) do
                local need = requiredKills[npcId]
                if need then
                  processBossEntry(npcId, need, achievementCompleted)
                end
              end
              for npcId, need in pairs(requiredKills) do
                local found = false
                for _, orderedId in ipairs(bossOrder) do
                  if orderedId == npcId then found = true break end
                end
                if not found then
                  processBossEntry(npcId, need, achievementCompleted)
                end
              end
            else
              for npcId, need in pairs(requiredKills) do
                processBossEntry(npcId, need, achievementCompleted)
              end
            end
          end
          GameTooltip:Show()
        end
      end)
      
      -- Set up OnLeave script to hide highlight and tooltip
      frame:SetScript("OnLeave", function(self)
        if self.highlight then
          self.highlight:Hide()
        end
        GameTooltip:Hide()
      end)
    end
  end

  -- Helper function to process a boss kill from BOSS_KILL event (by encounter ID)
  -- This is called when BOSS_KILL fires, providing encounterID
  local function ProcessBossKillByEncounterID(encounterID)
    if not IsOnRequiredMap() then
      return false
    end

    if state.completed then
      return false
    end

    -- Get NPC IDs for this encounter
    local npcIds = GetNpcIdsFromEncounterID(encounterID)
    if not npcIds then
      return false
    end

    -- Process each NPC ID that matches this encounter
    local anyKilled = false
    for _, npcId in ipairs(npcIds) do
      if IsRequiredBoss(npcId) then
        -- Count this kill (always eligible for raids)
        IncrementBossKill(npcId)
        anyKilled = true

        -- Store the level when this boss was killed (for tracking purposes)
        local killLevel = UnitLevel("player") or 1
        addon.SetProgress(achId, "levelAtKill", killLevel)

        -- Store points (raids do not support solo doubling)
        StorePointsAtKill()

        print("|cff008066[Hardcore Achievements]|r |cffffd100" .. HCA_GetRaidBossName(npcId) .. " killed as part of achievement: " .. title .. "|r")
      end
    end

    if anyKilled then
      SaveProgress() -- Save progress after each eligible kill
      UpdateTooltip() -- Update tooltip to show progress

      -- Check if achievement should be completed
      local progress = addon and addon.GetProgress and addon.GetProgress(achId)
      if progress and progress.completed then
        state.completed = true
        return true
      end

      -- Check if all bosses are killed
      if CountsSatisfied() then
        state.completed = true
        addon.SetProgress(achId, "completed", true)
        return true
      end
    end

    return false
  end

  -- No global tracker function for raids - we use BOSS_KILL event with encounter IDs instead
  
  -- Register functions in local registry to reduce global pollution
  if addon and addon.RegisterAchievementFunction then
    addon.RegisterAchievementFunction(achId, "IsCompleted", function() return state.completed end)
  end

  ---------------------------------------
  -- Registration Logic
  ---------------------------------------

  -- Check faction eligibility
  local function IsEligible()
    -- Faction: "Alliance" / "Horde"
    if faction and select(2, UnitFactionGroup("player")) ~= faction then
      return false
    end
    return true
  end

  -- Create the registration function dynamically
  addon[registerFuncName] = function()
    if not (addon and addon.CreateAchievementRow) then return end
    if addon[rowVarName] then return end
    
    -- Check if player is eligible for this achievement
    if not IsEligible() then return end

    -- Load progress from database
    LoadProgress()

    -- Ensure raids never have allowSoloDouble enabled and have no level requirement
    local raidDef = def or {}
    raidDef.allowSoloDouble = false
    raidDef.isRaid = true
    raidDef.level = nil  -- No level requirement for raids
    
    local AchievementPanel = addon and addon.AchievementPanel
    addon[rowVarName] = addon.CreateAchievementRow(
      AchievementPanel,
      achId,
      title,
      tooltip,
      icon,
      nil,  -- No level requirement for raids
      points,
      nil,  -- No KillTracker for raids - we use BOSS_KILL event with encounter IDs instead
      requiredQuestId,
      staticPoints,
      nil,
      raidDef  -- Pass def with isRaid flag and allowSoloDouble forced to false
    )
    
    -- Store requiredKills on the row for the embed UI to access
    if requiredKills and next(requiredKills) then
      addon[rowVarName].requiredKills = requiredKills
    end
    
    -- Store the ProcessBossKillByEncounterID function on the row for BOSS_KILL event handler
    addon[rowVarName].processBossKillByEncounterID = ProcessBossKillByEncounterID
    
    -- Load completion status from database on registration
    -- If the achievement was previously completed, mark the row as completed without showing toast
    if state.completed then
      if addon and addon.MarkRowCompleted then
        addon.MarkRowCompleted(addon[rowVarName])
      end
    end
    
    -- Refresh points with multipliers after creation
    if not (addon and addon.Initializing) then
      RefreshAllAchievementPoints()
    end
    
    -- Update tooltip after creation to ensure it shows current progress
    C_Timer.After(0.1, UpdateTooltip)
  end

  -- Auto-register the achievement immediately if the panel is ready
  if addon and addon.CreateAchievementRow then
    addon[registerFuncName]()
  end

  -- Create the event frame dynamically
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("PLAYER_LOGIN")
  eventFrame:RegisterEvent("ADDON_LOADED")
  eventFrame:SetScript("OnEvent", function()
    LoadProgress() -- Load progress on login/addon load
    addon[registerFuncName]()
  end)

  if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    CharacterFrame:HookScript("OnShow", function()
      LoadProgress() -- Load progress when character frame is shown
      addon[registerFuncName]()
    end)
  end
end

---------------------------------------
-- Module Export
---------------------------------------

RaidCommon.registerRaidAchievement = registerRaidAchievement

if addon then addon.RaidCommon = RaidCommon end
