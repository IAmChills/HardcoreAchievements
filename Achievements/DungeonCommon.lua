local DungeonCommon = {}

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
  local zone = def.zone
  local requiredMapId = def.requiredMapId
  local requiredKills = def.requiredKills or {}
  local faction = def.faction

  -- Expose this definition for external lookups (e.g., chat link tooltips)
  _G.HCA_AchievementDefs = _G.HCA_AchievementDefs or {}
  _G.HCA_AchievementDefs[tostring(achId)] = {
    achId = achId,
    title = title,
    tooltip = tooltip,
    icon = icon,
    points = points,
    zone = def.zone,
    mapID = def.requiredMapId,
    mapName = def.title,
    requiredKills = requiredKills,
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
    local mapId = select(8, GetInstanceInfo())
    return mapId == requiredMapId
  end

  local function CountsSatisfied()
    for npcId, need in pairs(requiredKills) do
      if (state.counts[npcId] or 0) < need then
        return false
      end
    end
    return true
  end

  -- Get boss names from NPC IDs (you can expand this with a lookup table)
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
      [3872] = "Deathsworn Captain",
      [4274] = "Fenrus the Devourer",
      [3927] = "Wolf Master Nandos",
      [4275] = "Archmage Arugal",
      [4887] = "Ghamoo-ra",
      [4831] = "Lady Sarevess",
      [6243] = "Gelihast",
      [12902] = "Lorgus Jett",
      [12876] = "Baron Aquanis",
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
      [6228] = "Dark Iron Ambassador",
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
      [7354] = "Ragglesnout",
      [8567] = "Glutton",
      [7358] = "Amnennar the Coldbringer",
      [6910] = "Revelosh",
      [6906] = "Baelog",
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
      [10393] = "Skul",
      [10558] = "Hearthsinger Forresten",
      [10516] = "The Unforgiven",
      [11143] = "Postmaster Malown",
      [10808] = "Timmy the Cruel",
      [11032] = "Malor the Zealous",
      [10997] = "Cannon Master Willey",
      [11120] = "Crimson Hammersmith",
      [10811] = "Archivist Galford",
      [10813] = "Balnazzar",
      [10435] = "Magistrate Barthilas",
      [10809] = "Stonespine",
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
      [11467] = "Tsu'zee",
      [11488] = "Illyanna Ravenoak",
      [11496] = "Immol'thar",
      [11486] = "Prince Tortheldrin",
      [10506] = "Kirtonos the Herald",
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
      [1853] = "Darkmaster Gandling"
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
          
          GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
          GameTooltip:ClearLines()
          GameTooltip:SetText(title or "", 1, 1, 1)
          GameTooltip:AddLine(baseTooltip, nil, nil, nil, true)
          
          if next(requiredKills) ~= nil then
            GameTooltip:AddLine("\nRequired Bosses:", 0, 1, 0) -- Green header
            
            for npcId, need in pairs(requiredKills) do
              local idNum = tonumber(npcId) or npcId
              local current = (state.counts[idNum] or state.counts[tostring(idNum)] or 0)
              local bossName = HCA_GetBossName(idNum)
              local done = current >= (tonumber(need) or 1)
              
              if done then
                GameTooltip:AddLine(bossName, 1, 1, 1) -- White for completed
              else
                GameTooltip:AddLine(bossName, 0.5, 0.5, 0.5) -- Gray for not completed
              end
            end
          end
          -- Hint for linking the achievement in chat
          GameTooltip:AddLine("\nShift + Left Click to link in chat", 0.5, 0.5, 0.5)
          
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

  local function IsGroupEligible()
    if IsInRaid() then return false end
    local members = GetNumGroupMembers()
    if members > 5 then return false end

    local function overLeveled(unit)
      local lvl = UnitLevel(unit)
      return (lvl and lvl > level)
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

  -- Create the tracker function dynamically
  local function KillTracker(destGUID)
    if not IsOnRequiredMap() then 
      return false 
    end

    if state.completed then 

      return false 
    end

    local npcId = GetNpcIdFromGUID(destGUID)
    
    if npcId and requiredKills[npcId] then
        state.counts[npcId] = (state.counts[npcId] or 0) + 1
        SaveProgress() -- Save progress after each kill
        UpdateTooltip() -- Update tooltip to show progress
        print("[HardcoreAchievements] " .. HCA_GetBossName(npcId) .. " killed as part of achievement: " .. title)
    end

    if CountsSatisfied() and IsGroupEligible() then
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
    if faction and UnitFactionGroup("player") ~= faction then
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
      staticPoints
    )
    
    -- Store requiredKills on the row for the embed UI to access
    if requiredKills and next(requiredKills) then
      _G[rowVarName].requiredKills = requiredKills
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
_G.DungeonCommon = DungeonCommon
