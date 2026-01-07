local DungeonCommon = {}

-- Variation definitions
local VARIATIONS = {
  {
    suffix = "_Trio",
    label = "Trio",
    levelOffset = 3,
    pointMultiplier = 2,
    maxPartySize = 3,
  },
  {
    suffix = "_Duo",
    label = "Duo",
    levelOffset = 4,
    pointMultiplier = 3,
    maxPartySize = 2,
  },
  {
    suffix = "_Solo",
    label = "Solo",
    levelOffset = 5,
    pointMultiplier = 4,
    maxPartySize = 1,
  },
}

-- Generate a variation achievement from a base dungeon achievement
local function CreateVariation(baseDef, variation)
    local variationDef = {}
    
    -- Copy all base properties
    for k, v in pairs(baseDef) do
        variationDef[k] = v
    end
    
    -- Modify for variation
    variationDef.achId = baseDef.achId .. variation.suffix
    variationDef.level = baseDef.level + variation.levelOffset
    variationDef.points = baseDef.points * variation.pointMultiplier
    variationDef.maxPartySize = variation.maxPartySize
    
    -- Update title to include variation type in parentheses
    variationDef.title = baseDef.title .. " (" .. variation.label .. ")"
    
    -- Update tooltip to reflect variation (clean, without "Variation" suffix)
    local partySizeText = variation.maxPartySize == 1 and "yourself only" or 
                          (variation.maxPartySize == 2 and "up to 2 party members" or "up to 3 party members")
    variationDef.tooltip = "Defeat the bosses of |cff0091e6" .. baseDef.title .. "|r before level " .. (variationDef.level + 1) .. 
                          " (" .. partySizeText .. ")"
    
    -- Mark as variation
    variationDef.isVariation = true
    variationDef.baseAchId = baseDef.achId
    variationDef.variationType = variation.label
    
    return variationDef
end

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
    level = level,
    mapID = def.requiredMapId,
    mapName = def.title,
    requiredKills = requiredKills,
    bossOrder = bossOrder,  -- Store boss order for tooltip display
    faction = faction,
    isHeroicDungeon = def.isHeroicDungeon or false,  -- Preserve heroic dungeon flag
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

  -- Get boss names from NPC IDs (you can expand this with a lookup table)
  -- Export globally so tooltip function can use it
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
      --[3872] = "Deathsworn Captain",
      [4274] = "Fenrus the Devourer",
      [3927] = "Wolf Master Nandos",
      [4275] = "Archmage Arugal",
      [4887] = "Ghamoo-ra",
      [4831] = "Lady Sarevess",
      [6243] = "Gelihast",
      [12902] = "Lorgus Jett",
      --[12876] = "Baron Aquanis",
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
      --[6228] = "Dark Iron Ambassador",
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
      --[7354] = "Ragglesnout",
      [8567] = "Glutton",
      [7358] = "Amnennar the Coldbringer",
      [6910] = "Revelosh",
      --[6906] = "Baelog",
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
      -- Ring of Law challengers
      [9027] = "Gorosh the Dervish",
      [9028] = "Grizzle",
      [9029] = "Eviscerator",
      [9030] = "Ok'thor the Breaker",
      [9031] = "Anub'shiah",
      [9032] = "Hedrum the Creeper",
      -- Ring of Law challengers
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
      --[10393] = "Skul",
      --[10558] = "Hearthsinger Forresten",
      [10516] = "The Unforgiven",
      --[11143] = "Postmaster Malown",
      [10808] = "Timmy the Cruel",
      [11032] = "Malor the Zealous",
      [10997] = "Cannon Master Willey",
      [11120] = "Crimson Hammersmith",
      [10811] = "Archivist Galford",
      [10813] = "Balnazzar",
      [10435] = "Magistrate Barthilas",
      --[10809] = "Stonespine",
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
      --[11467] = "Tsu'zee",
      [11488] = "Illyanna Ravenoak",
      [11496] = "Immol'thar",
      [11486] = "Prince Tortheldrin",
      --[10506] = "Kirtonos the Herald",
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
      [1853] = "Darkmaster Gandling",
      -- [1200] = "Morbent Fel", -- Duskwood Achievement
      -- [314] = "Eliza", -- Duskwood Achievement
      -- [522] = "Mor'Ladim", -- Duskwood Achievement
      -- [412] = "Stitches", -- Duskwood Achievement
      -- TBC Normal Dungeons
      [17306] = "Watchkeeper Gargolmar",
      [17308] = "Omor the Unscarred",
      [17536] = "Nazan",
      [17537] = "Vazruden",
      [17381] = "The Maker",
      [17380] = "Broggok",
      [17377] = "Keli'dan the Breaker",
      [17941] = "Mennu the Betrayer",
      [17991] = "Rokmar the Crackler",
      [17942] = "Quagmirran",
      [17770] = "Hungarfen",
      [18105] = "Ghaz'an",
      [17826] = "Swamplord Musel'ek",
      [17882] = "The Black Stalker",
      [18341] = "Pandemonius",
      [18343] = "Tavarok",
      [18344] = "Nexus-Prince Shaffar",
      [18371] = "Shirrak the Dead Watcher",
      [18373] = "Exarch Maladaar",
      [17848] = "Lieutenant Drake",
      [17862] = "Captain Skarloc",
      [18096] = "Epoch Hunter",
      [18472] = "Darkweaver Syth",
      [18473] = "Talon King Ikiss",
      [17879] = "Chrono Lord Deja",
      [17880] = "Temporus",
      [17881] = "Aeonus",
      [19219] = "Mechano-Lord Capacitus",
      [19221] = "Nethermancer Sepethrea",
      [19220] = "Pathaleon the Calculator",
      [16807] = "Grand Warlock Nethekurse",
      [16809] = "Warbringer O'mrogg",
      [16808] = "Warchief Kargath Bladefist",
      [18731] = "Ambassador Hellmaw",
      [18667] = "Blackheart the Inciter",
      [18732] = "Grandmaster Vorpil",
      [18708] = "Murmur",
      [17797] = "Hydromancer Thespia",
      [17796] = "Mekgineer Steamrigger",
      [17798] = "Warlord Kalithresh",
      [17976] = "Commander Sarannis",
      [17975] = "High Botanist Freywinn",
      [17978] = "Thorngrin the Tender",
      [17980] = "Laj",
      [17977] = "Warp Splinter",
      [24723] = "Selin Fireheart",
      [24744] = "Vexallus",
      [24560] = "Priestess Delrissa",
      [24664] = "Kael'thas Sunstrider",
      [20870] = "Zereketh the Unbound",
      [20885] = "Dalliah the Doomsayer",
      [20886] = "Wrath-Scryer Soccothrates",
      [20912] = "Harbinger Skyriss",
      -- TBC Heroic Dungeons
      [18436] = "Watchkeeper Gargolmar",
      [18433] = "Omar the Unscarred",
      [18432] = "Nazan",
      [18434] = "Vazruden",
      [18621] = "The Maker",
      [18601] = "Broggok",
      [18607] = "Keli'dan the Breaker",
      [19893] = "Mennu the Betrayer",
      [19895] = "Rokmar the Crackler",
      [19894] = "Quagmirran",
      [20169] = "Hungarfen",
      [20168] = "Ghaz'an",
      [20183] = "Swamplord Musel'ek",
      [20184] = "The Black Stalker",
      [20267] = "Pandemonius",
      [20268] = "Tavarok",
      [20266] = "Nexus-Prince Shaffar",
      [20318] = "Shirrak the Dead Watcher",
      [20306] = "Exarch Maladaar",
      [20535] = "Lieutenant Drake",
      [20521] = "Captain Skarloc",
      [20531] = "Epoch Hunter",
      [20690] = "Darkweaver Syth",
      [20706] = "Talon King Ikiss",
      [23035] = "Anzu",
      [20738] = "Chrono Lord Deja",
      [20745] = "Temporus",
      [20737] = "Aeonus",
      [21533] = "Mechano-Lord Capacitus",
      [21536] = "Nethermancer Sepethrea",
      [21537] = "Pathaleon the Calculator",
      [20568] = "Grand Warlock Nethekurse",
      [20923] = "Blood Guard Porung",
      [20596] = "Warbringer O'mrogg",
      [20597] = "Warchief Kargath Bladefist",
      [20636] = "Ambassador Hellmaw",
      [20637] = "Blackheart the Inciter",
      [20653] = "Grandmaster Vorpil",
      [20657] = "Murmur",
      [20629] = "Hydromancer Thespia",
      [20630] = "Mekgineer Steamrigger",
      [20633] = "Warlord Kalithresh",
      [21551] = "Commander Sarannis",
      [21558] = "High Botanist Freywinn",
      [21581] = "Thorngrin the Tender",
      [21559] = "Laj",
      [21582] = "Warp Splinter",
      [25562] = "Selin Fireheart",
      [25573] = "Vexallus",
      [25560] = "Priestess Delrissa",
      [24857] = "Kael'thas Sunstrider",
      [21626] = "Zereketh the Unbound",
      [21590] = "Dalliah the Doomsayer",
      [21624] = "Wrath-Scryer Soccothrates",
      [21599] = "Harbinger Skyriss",
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
          -- Level (left) and Points (right) on one line
          -- Use self.points (calculated with multipliers) instead of raw points
          local leftText = (self.maxLevel and self.maxLevel > 0) and (LEVEL .. " " .. tostring(self.maxLevel)) or " "
          local rightText = (self.points and tonumber(self.points) and tonumber(self.points) > 0) and (ACHIEVEMENT_POINTS .. ": " .. tostring(self.points)) or " "
          GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.7, 0.9, 0.7)
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
                  local name = HCA_GetBossName(id)
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
                bossName = HCA_GetBossName(idNum)
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

  local function IsGroupEligible()
    if IsInRaid() then return false end
    local members = GetNumGroupMembers()
    
    -- Check max party size (from variation or default to 5)
    local maxPartySize = def.maxPartySize or 5
    if members > maxPartySize then return false end

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
        -- Check group eligibility BEFORE counting the kill
        -- Only count kills when group is eligible - allows returning later with eligible group
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
          
          -- Store the level when this boss was killed (for eligibility checking)
          local killLevel = UnitLevel("player") or 1
          HardcoreAchievements_SetProgress(achId, "levelAtKill", killLevel)
          
          -- Dungeons do not support solo points - store regular points only
          if AchievementPanel and AchievementPanel.achievements then
            local rowVarName = achId .. "_Row"
            local row = _G[rowVarName]
            if row and row.points then
              -- Store pointsAtKill WITHOUT the self-found bonus.
              -- Recompute from base/original points so we don't rely on subtracting a (now dynamic) bonus.
              local base = tonumber(row.originalPoints) or tonumber(row.points) or 0
              local pointsToStore = base
              if not row.staticPoints then
                local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
                local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
                pointsToStore = math.floor(base * multiplier + 0.5)
              end
              HardcoreAchievements_SetProgress(achId, "pointsAtKill", pointsToStore)
            end
          end
          
          SaveProgress() -- Save progress after each eligible kill
          UpdateTooltip() -- Update tooltip to show progress
          print("|cff69adc9[Hardcore Achievements]|r |cffffd100" .. HCA_GetBossName(npcId) .. " killed as part of achievement: " .. title .. "|r")
        else
          -- Group is ineligible - don't count this kill
          -- Player can return later with an eligible group to kill this boss
          -- Only print message if the achievement is still available (not completed or failed) and visible
          local progress = HardcoreAchievements_GetProgress(achId)
          local isStillAvailable = not state.completed and not (progress and progress.failed)
          if isStillAvailable and _G.HCA_IsAchievementVisible and _G.HCA_IsAchievementVisible(achId) then
            print("|cff69adc9[Hardcore Achievements]|r |cffffd100" .. HCA_GetBossName(npcId) .. " killed but group is ineligible - kill not counted for achievement: " .. title .. "|r")
          end
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
      -- Check eligibility using stored level at kill time, not current level
      -- This prevents failing if player leveled up during the kill
      -- Since we only count kills when eligible, if CountsSatisfied() is true,
      -- all bosses were killed while eligible
      if progress and progress.levelAtKill then
        local levelToCheck = progress.levelAtKill
        
        -- If player was eligible when bosses were killed, complete the achievement
        -- We use the stored level because that's when the requirement was fulfilled
        if levelToCheck <= level then
          state.completed = true
          HardcoreAchievements_SetProgress(achId, "completed", true)
          return true
        end
        -- If levelToCheck > level, the player was over-leveled when they killed a boss,
        -- so we don't complete it (this is the fail case)
      end
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
    
    -- Note: Variations are always registered, but filtered in ApplyFilter based on checkbox states

    -- Load progress from database
    LoadProgress()

    -- Ensure dungeons never have allowSoloDouble enabled
    local dungeonDef = def or {}
    dungeonDef.allowSoloDouble = false
    -- Preserve isHeroicDungeon flag if present
    if def.isHeroicDungeon then
      dungeonDef.isHeroicDungeon = true
    end
    
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
      staticPoints,
      nil,
      dungeonDef  -- Pass def with allowSoloDouble forced to false for dungeons
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

-- Function to register dungeon variations
-- Note: Variations are always registered, but filtered in ApplyFilter based on checkbox states
function DungeonCommon.registerDungeonVariations(baseDef)
  -- Only create variations for dungeons up to 70
  if baseDef.level > 67 then
    return
  end
  
  -- Always register all variations (they will be filtered in display logic based on checkbox states)
  local trioDef = CreateVariation(baseDef, VARIATIONS[1])
  DungeonCommon.registerDungeonAchievement(trioDef)
  
  local duoDef = CreateVariation(baseDef, VARIATIONS[2])
  DungeonCommon.registerDungeonAchievement(duoDef)
  
  local soloDef = CreateVariation(baseDef, VARIATIONS[3])
  DungeonCommon.registerDungeonAchievement(soloDef)
end

-- Function to refresh variation registrations (for when checkboxes change)
-- This forces re-registration of variation achievements by clearing their row variables
function DungeonCommon.refreshDungeonVariations()
  if not _G.HCA_AchievementDefs then return end
  
  -- Get all base dungeon IDs (those without variation suffixes)
  local baseDungeonIds = {}
  for achId, def in pairs(_G.HCA_AchievementDefs) do
    if not def.isVariation and def.mapID then  -- Dungeons have mapID
      table.insert(baseDungeonIds, achId)
    end
  end
  
  -- Re-register variations for each base dungeon
  -- First, clear existing variation rows so they can be re-registered
  for _, baseId in ipairs(baseDungeonIds) do
    for _, variation in ipairs(VARIATIONS) do
      local variationId = baseId .. variation.suffix
      local rowVarName = variationId .. "_Row"
      if _G[rowVarName] then
        -- Hide and clear the row so it can be re-registered
        _G[rowVarName]:Hide()
        _G[rowVarName] = nil
      end
    end
  end
  
  -- Re-trigger registration by calling register functions
  -- This will check checkbox states and register accordingly
  for _, baseId in ipairs(baseDungeonIds) do
    for _, variation in ipairs(VARIATIONS) do
      local variationId = baseId .. variation.suffix
      local registerFuncName = "HCA_Register" .. variationId
      if _G[registerFuncName] and type(_G[registerFuncName]) == "function" then
        _G[registerFuncName]()
      end
    end
  end
end

_G.DungeonCommon = DungeonCommon