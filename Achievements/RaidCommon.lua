local RaidCommon = {}

-- Register a raid achievement with the given definition
function RaidCommon.registerRaidAchievement(def)
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
  _G.HCA_AchievementDefs = _G.HCA_AchievementDefs or {}
  _G.HCA_AchievementDefs[tostring(achId)] = {
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    level = nil,  -- Raids have no level requirement
    mapID = def.requiredMapId,
    mapName = def.title,
    requiredKills = requiredKills,
    bossOrder = bossOrder,  -- Store boss order for tooltip display
    faction = faction,
    isRaid = true,
  }

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

  -- Get boss names from NPC IDs
  -- Export globally so tooltip function can use it
  function HCA_GetRaidBossName(npcId)
    local bossNames = {
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
    return bossNames[npcId] or ("Boss " .. npcId)
  end

  -- Update tooltip when progress changes (local; closes over the local generator)
  local function UpdateTooltip()
    local row = _G[rowVarName]
    if row then
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
      
      -- Override the OnEnter script to use proper GameTooltip API while preserving highlighting
      row:SetScript("OnEnter", function(self)
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
          -- Points only (no level requirement for raids)
          local rightText = (self.points and tonumber(self.points) and tonumber(self.points) > 0) and (ACHIEVEMENT_POINTS .. ": " .. tostring(self.points)) or " "
          GameTooltip:AddDoubleLine(" ", rightText, 1, 1, 1, 0.7, 0.9, 0.7)
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
                  local name = HCA_GetRaidBossName(id)
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
                bossName = HCA_GetRaidBossName(idNum)
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
      end)
      
      -- Set up OnLeave script to hide highlight and tooltip
      row:SetScript("OnLeave", function(self)
        if self.highlight then
          self.highlight:Hide()
        end
        GameTooltip:Hide()
      end)
    end
  end

  -- Raids allow any group size (solo, party, or raid)
  -- No level requirement
  local function IsGroupEligible()
    -- Always eligible - no restrictions on group size or level for raids
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
        -- Check group eligibility (always returns true for raids, but keeping for consistency)
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
          
          -- Store the level when this boss was killed (for tracking purposes)
          local killLevel = UnitLevel("player") or 1
          HardcoreAchievements_SetProgress(achId, "levelAtKill", killLevel)
          
          -- Store points (raids do not support solo doubling)
          if AchievementPanel and AchievementPanel.achievements then
            local rowVarName = achId .. "_Row"
            local row = _G[rowVarName]
            if row and row.points then
              -- Calculate base points (row.points includes self-found bonus, subtract it)
              -- Self-found bonus will be added at completion time
              local basePoints = tonumber(row.points) or 0
              local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
              if isSelfFound and not row.isSecretAchievement then
                basePoints = basePoints - HCA_SELF_FOUND_BONUS
              end
              
              -- Store regular points (no solo doubling for raids)
              local pointsToStore = basePoints
              HardcoreAchievements_SetProgress(achId, "pointsAtKill", pointsToStore)
            end
          end
          
          SaveProgress() -- Save progress after each eligible kill
          UpdateTooltip() -- Update tooltip to show progress
          print("|cff69adc9[Hardcore Achievements]|r |cffffd100" .. HCA_GetRaidBossName(npcId) .. " killed as part of achievement: " .. title .. "|r")
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
      -- Since raids have no level requirement, complete immediately when all bosses are killed
      state.completed = true
      HardcoreAchievements_SetProgress(achId, "completed", true)
      return true
    end

    return false
  end

  -- Store the tracker function globally for the main system
  _G[achId] = KillTracker

  _G[achId .. "_IsCompleted"] = function() return state.completed end

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

    -- Load progress from database
    LoadProgress()

    -- Ensure raids never have allowSoloDouble enabled and have no level requirement
    local raidDef = def or {}
    raidDef.allowSoloDouble = false
    raidDef.isRaid = true
    raidDef.level = nil  -- No level requirement for raids
    
    _G[rowVarName] = CreateAchievementRow(
      AchievementPanel,
      achId,
      title,
      tooltip,
      icon,
      nil,  -- No level requirement for raids
      points,
      KillTracker,
      requiredQuestId,
      staticPoints,
      nil,
      raidDef  -- Pass def with isRaid flag and allowSoloDouble forced to false
    )
    
    -- Store requiredKills on the row for the embed UI to access
    if requiredKills and next(requiredKills) then
      _G[rowVarName].requiredKills = requiredKills
    end
    
    -- Refresh points with multipliers after creation
    if RefreshAllAchievementPoints then
      RefreshAllAchievementPoints()
    end
    
    -- Update tooltip after creation to ensure it shows current progress
    C_Timer.After(0.1, UpdateTooltip)
  end

  -- Auto-register the achievement immediately if the panel is ready
  if _G.CreateAchievementRow and _G.AchievementPanel then
    _G[registerFuncName]()
  end

  -- Create the event frame dynamically
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("PLAYER_LOGIN")
  eventFrame:RegisterEvent("ADDON_LOADED")
  eventFrame:SetScript("OnEvent", function()
    LoadProgress() -- Load progress on login/addon load
    _G[registerFuncName]()
  end)

  if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    CharacterFrame:HookScript("OnShow", function()
      LoadProgress() -- Load progress when character frame is shown
      _G[registerFuncName]()
    end)
  end
end

-- Export to global scope
_G.RaidCommon = RaidCommon

