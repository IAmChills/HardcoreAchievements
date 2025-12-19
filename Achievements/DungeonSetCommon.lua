local DungeonSetCommon = {}

-- Get item names from item IDs (you can expand this with a lookup table)
-- Export globally so tooltip function can use it
function HCA_GetItemName(itemId)
  -- This is a basic mapping - you can expand this with more item names
  local itemNames = {
    -- Defias Set (Rogue)
    [10399] = "Blackened Defias Armor",
    [10403] = "Blackened Defias Gloves",
    [10402] = "Blackened Defias Boots",
    [10401] = "Blackened Defias Leggings",
    [10400] = "Blackened Defias Belt",

    -- Embrace of the Viper Set (Druid)
    [10412] = "Belt of the Fang",
    [10411] = "Footpads of the Fang",
    [10413] = "Gloves of the Fang",
    [10410] = "Leggings of the Fang",
    [6473] = "Armor of the Fang",

    -- Chain of the Scarlet Crusade Set (Paladin)
    [10329] = "Scarlet Belt",
    [10332] = "Scarlet Boots",
    [10328] = "Scarlet Chestpiece",
    [10331] = "Scarlet Gauntlets",
    [10330] = "Scarlet Leggings",
    [10333] = "Scarlet Wristguards",

    -- Bloodmail Regalia Set (Scholomance)
    [14614] = "Bloodmail Belt",
    [14616] = "Bloodmail Boots",
    [14615] = "Bloodmail Gauntlets",
    [14611] = "Bloodmail Hauberk",
    [14612] = "Bloodmail Legguards",

    -- Cadaverous Set (Scholomance)
    [14637] = "Cadaverous Armor",
    [14636] = "Cadaverous Belt",
    [14640] = "Cadaverous Gloves",
    [14638] = "Cadaverous Leggings",
    [14641] = "Cadaverous Walkers",

    -- Deathbone Set (Scholomance)
    [14624] = "Deathbone Chestplate",
    [14622] = "Deathbone Gauntlets",
    [14620] = "Deathbone Girdle",
    [14623] = "Deathbone Legguards",
    [14621] = "Deathbone Sabatons",

    -- Necropile Set (Scholomance)
    [14631] = "Necropile Boots",
    [14629] = "Necropile Cuffs",
    [14632] = "Necropile Leggings",
    [14633] = "Necropile Mantle",
    [14626] = "Necropile Robe",

    -- Postmaster's Set (Scholomance)
    [13390] = "Postmaster's Band",
    [13388] = "Postmaster's Tunic",
    [13391] = "Postmaster's Treads",
    [13392] = "Postmaster's Seal",
    [13389] = "Postmaster's Trousers",

    -- Ironweave Set (Blackrock Spire)
    [22306] = "Ironweave Belt",
    [22311] = "Ironweave Boots",
    [22313] = "Ironweave Bracers",
    [22302] = "Ironweave Cowl",
    [22304] = "Ironweave Gloves",
    [22305] = "Ironweave Mantle",
    [22303] = "Ironweave Pants",
    [22301] = "Ironweave Robe",

    -- Savage Gladiator Set (Blackrock Depths)
    [11729] = "Savage Gladiator Helm",
    [11726] = "Savage Gladiator Chain",
    [11728] = "Savage Gladiator Leggings",
    [11731] = "Savage Gladiator Greaves",
    [11730] = "Savage Gladiator Grips",

    -- Beaststalker's Set (Hunter D1)
    [16680] = "Beaststalker's Belt",
    [16681] = "Beaststalker's Bindings",
    [16676] = "Beaststalker's Gloves",
    [16675] = "Beaststalker's Boots",
    [16679] = "Beaststalker's Mantle",
    [16677] = "Beaststalker's Cap",
    [16674] = "Beaststalker's Tunic",
    [16678] = "Beaststalker's Pants",

    -- Magister's Set (Mage D1)
    [16685] = "Magister's Belt",
    [16683] = "Magister's Bindings",
    [16684] = "Magister's Gloves",
    [16682] = "Magister's Boots",
    [16689] = "Magister's Mantle",
    [16686] = "Magister's Crown",
    [16688] = "Magister's Robes",
    [16687] = "Magister's Leggings",

    -- Wildheart Set (Druid D1)
    [16716] = "Wildheart's Belt",
    [16714] = "Wildheart's Bracers",
    [16717] = "Wildheart's Gloves",
    [16715] = "Wildheart's Boots",
    [16718] = "Wildheart's Spaulders",
    [16720] = "Wildheart's Cowl",
    [16706] = "Wildheart's Vest",
    [16719] = "Wildheart's Kilt",

    -- Battlegear of Valor Set (Warrior D1)
    [16736] = "Belt of Valor",
    [16735] = "Bracers of Valor",
    [16737] = "Gauntlets of Valor",
    [16734] = "Boots of Valor",
    [16733] = "Spaulders of Valor",
    [16731] = "Helm of Valor",
    [16730] = "Breastplate of Valor",
    [16732] = "Legplates of Valor",

    -- Vestments of the Devout Set (Priest D1)
    [16696] = "Devout Belt",
    [16697] = "Devout Bracers",
    [16692] = "Devout Gloves",
    [16691] = "Devout Sandals",
    [16695] = "Devout Mantle",
    [16693] = "Devout Crown",
    [16690] = "Devout Robe",
    [16694] = "Devout Skirt",

    -- Dreadmist Raiment Set (Warlock D1)
    [16702] = "Dreadmist Belt",
    [16703] = "Dreadmist Bracers",
    [16705] = "Dreadmist Wraps",
    [16704] = "Dreadmist Sandals",
    [16701] = "Dreadmist Mantle",
    [16698] = "Dreadmist Mask",
    [16700] = "Dreadmist Robe",
    [16699] = "Dreadmist Leggings",

    -- Lightforge Armor Set (Paladin D1)
    [16723] = "Lightforge Belt",
    [16722] = "Lightforge Bracers",
    [16724] = "Lightforge Gauntlets",
    [16725] = "Lightforge Boots",
    [16729] = "Lightforge Spaulders",
    [16727] = "Lightforge Helm",
    [16726] = "Lightforge Breastplate",
    [16728] = "Lightforge Legplates",

    -- Shadowcraft Armor Set (Rogue D1)
    [16713] = "Shadowcraft Belt",
    [16710] = "Shadowcraft Bracers",
    [16712] = "Shadowcraft Gloves",
    [16711] = "Shadowcraft Boots",
    [16708] = "Shadowcraft Spaulders",
    [16707] = "Shadowcraft Cap",
    [16721] = "Shadowcraft Tunic",
    [16709] = "Shadowcraft Pants",

    -- The Elements Set (Shaman D1)
    [16673] = "Cord of the Elements",
    [16671] = "Bindings of the Elements",
    [16672] = "Gauntlets of the Elements",
    [16670] = "Boots of the Elements",
    [16669] = "Pauldrons of the Elements",
    [16667] = "Coif of the Elements",
    [16666] = "Vest of the Elements",
    [16668] = "Kilt of the Elements",

    -- Beastmaster's Set (Hunter D2)
    [22010] = "Beastmaster's Belt",
    [22011] = "Beastmaster's Bindings",
    [22015] = "Beastmaster's Gloves",
    [22061] = "Beastmaster's Boots",
    [22016] = "Beastmaster's Mantle",
    [22013] = "Beastmaster's Cap",
    [22060] = "Beastmaster's Tunic",
    [22017] = "Beastmaster's Pants",

    -- Sorcerer's Regalia Set (Mage D2)
    [22062] = "Sorcerer's Belt",
    [22063] = "Sorcerer's Bindings",
    [22066] = "Sorcerer's Gloves",
    [22064] = "Sorcerer's Boots",
    [22068] = "Sorcerer's Mantle",
    [22065] = "Sorcerer's Crown",
    [22069] = "Sorcerer's Robes",
    [22067] = "Sorcerer's Leggings",

    -- Feralheart Raiment Set (Druid D2)
    [22106] = "Feralheart Belt",
    [22108] = "Feralheart Bracers",
    [22110] = "Feralheart Gloves",
    [22107] = "Feralheart Boots",
    [22112] = "Feralheart Spaulders",
    [22109] = "Feralheart Cowl",
    [22113] = "Feralheart Vest",
    [22111] = "Feralheart Kilt",

    -- Battlegear of Heroism Set (Warrior D2)
    [21994] = "Belt of Heroism",
    [21996] = "Bracers of Heroism",
    [21998] = "Gauntlets of Heroism",
    [21995] = "Boots of Heroism",
    [22001] = "Spaulders of Heroism",
    [21999] = "Helm of Heroism",
    [21997] = "Breastplate of Heroism",
    [22000] = "Legplates of Heroism",

    -- Vestments of the Virtuous Set (Priest D2)
    [22078] = "Virtuous Belt",
    [22079] = "Virtuous Bracers",
    [22081] = "Virtuous Gloves",
    [22084] = "Virtuous Sandals",
    [22082] = "Virtuous Mantle",
    [22080] = "Virtuous Crown",
    [22083] = "Virtuous Robe",
    [22085] = "Virtuous Skirt",

    -- Deathmist Raiment Set (Warlock D2)
    [22070] = "Deathmist Belt",
    [22071] = "Deathmist Bracers",
    [22077] = "Deathmist Wraps",
    [22076] = "Deathmist Sandals",
    [22073] = "Deathmist Mantle",
    [22074] = "Deathmist Mask",
    [22075] = "Deathmist Robe",
    [22072] = "Deathmist Leggings",

    -- Soulforge Armor Set (Paladin D2)
    [22086] = "Soulforge Belt",
    [22088] = "Soulforge Bracers",
    [22090] = "Soulforge Gauntlets",
    [22087] = "Soulforge Boots",
    [22093] = "Soulforge Spaulders",
    [22091] = "Soulforge Helm",
    [22089] = "Soulforge Breastplate",
    [22092] = "Soulforge Legplates",

    -- Darkmantle Armor Set (Rogue D2)
    [22002] = "Darkmantle Belt",
    [22004] = "Darkmantle Bracers",
    [22006] = "Darkmantle Gloves",
    [22003] = "Darkmantle Boots",
    [22008] = "Darkmantle Spaulders",
    [22005] = "Darkmantle Cap",
    [22009] = "Darkmantle Tunic",
    [22007] = "Darkmantle Pants",

    -- Five Thunders Set (Shaman D2)
    [22098] = "Cord of the Five Thunders",
    [22095] = "Bindings of the Five Thunders",
    [22099] = "Gauntlets of the Five Thunders",
    [22096] = "Boots of the Five Thunders",
    [22101] = "Pauldrons of the Five Thunders",
    [22097] = "Coif of the Five Thunders",
    [22102] = "Vest of the Five Thunders",
    [22100] = "Kilt of the Five Thunders",

  }
  
  -- First try the lookup table
  if itemNames[itemId] then
    return itemNames[itemId]
  end
  
  -- Fallback to GetItemInfo if item not in table (for items not yet added)
  local itemName = GetItemInfo(itemId)
  if itemName then
    return itemName
  end
  
  -- Last resort: return formatted item ID
  return "Item " .. tostring(itemId)
end

-- Register a dungeon set achievement with the given definition
function DungeonSetCommon.registerDungeonSetAchievement(def)
  local achId = def.achId
  local title = def.title or ""
  local tooltip = def.tooltip or ""
  local icon = def.icon
  local level = def.level
  local points = def.points or 0
  local requiredItems = def.requiredItems or {}
  local itemOrder = def.itemOrder -- Optional ordering for tooltip display
  local faction = def.faction
  local class = def.class
  local zone = def.zone
  local staticPoints = def.staticPoints or false
  
  -- Create unique variable names
  local rowVarName = achId .. "_Row"
  local registerFuncName = "HCA_Register" .. achId
  
  -- State management
  local state = {
    completed = false,
    itemOwned = {} -- Track which items are owned
  }
  
  -- Load progress from database
  local function LoadProgress()
    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(achId)
    if progress then
      state.completed = progress.completed or false
      -- Load item ownership state if stored
      if progress.itemOwned then
        state.itemOwned = progress.itemOwned
      end
    end
  end
  
  -- Save progress to database
  local function SaveProgress()
    if HardcoreAchievements_SetProgress then
      HardcoreAchievements_SetProgress(achId, "completed", state.completed)
      HardcoreAchievements_SetProgress(achId, "itemOwned", state.itemOwned)
    end
  end
  
  -- Check if all required items are owned
  local function HasAllItems()
    if state.completed then return true end
    
    for _, itemId in ipairs(requiredItems) do
      if GetItemCount(itemId, true) == 0 then
        return false
      end
    end
    return true
  end
  
  -- Update item ownership state
  -- Once an item is marked as owned, it stays owned (even if sold/deleted)
  local function UpdateItemOwnership()
    local anyChanged = false
    for _, itemId in ipairs(requiredItems) do
      local currentlyOwned = GetItemCount(itemId, true) > 0
      -- Only update if we don't already have it marked as owned
      -- This ensures "once owned, always owned" behavior
      if currentlyOwned and not state.itemOwned[itemId] then
        state.itemOwned[itemId] = true
        anyChanged = true
      end
    end
    -- Only save if something changed
    if anyChanged then
      SaveProgress()
    end
  end
  
  -- Update tooltip when progress changes
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
          -- Update item ownership before showing tooltip
          UpdateItemOwnership()
          LoadProgress()
          
          local achievementCompleted = state.completed or (self.completed == true)
          
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:ClearLines()
          GameTooltip:SetText(title or "", 1, 1, 1)
          
          -- Level (left) and Points (right) on one line
          local leftText = (self.maxLevel and self.maxLevel > 0) and (LEVEL .. " " .. tostring(self.maxLevel)) or " "
          local rightText = (self.points and tonumber(self.points) and tonumber(self.points) > 0) and (ACHIEVEMENT_POINTS .. ": " .. tostring(self.points)) or " "
          GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.7, 0.9, 0.7)
          
          -- Description in default yellow
          GameTooltip:AddLine(baseTooltip, nil, nil, nil, true)
          
          -- Show zone if provided
          if zone then
            GameTooltip:AddLine(zone, 0.6, 1, 0.86)
          end
          
          if next(requiredItems) ~= nil then
            GameTooltip:AddLine("\nRequired Items:", 0, 1, 0) -- Green header
            
            -- Helper function to process a single item entry
            local function processItemEntry(itemId)
              local owned = false
              local itemName = ""
              
              -- Check saved state first (once owned, always owned)
              if state.itemOwned and state.itemOwned[itemId] then
                owned = true
              else
                -- Fall back to checking current inventory
                local count = GetItemCount(itemId, true)
                owned = count > 0
                -- If currently owned, update and save the state
                if owned then
                  state.itemOwned[itemId] = true
                  SaveProgress()
                end
              end
              
              -- If achievement is complete, all items show as owned
              if achievementCompleted then
                owned = true
              end
              
              itemName = HCA_GetItemName(itemId)
              
              if owned then
                GameTooltip:AddLine(itemName, 1, 1, 1) -- White for owned
              else
                GameTooltip:AddLine(itemName, 0.5, 0.5, 0.5) -- Gray for not owned
              end
            end
            
            -- Use ordered display if provided, otherwise use array order
            if itemOrder then
              for _, itemId in ipairs(itemOrder) do
                processItemEntry(itemId)
              end
            else
              for _, itemId in ipairs(requiredItems) do
                processItemEntry(itemId)
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
  
  -- Check if achievement should be completed
  local function CheckCompletion()
    if state.completed then return true end
    
    if HasAllItems() then
      state.completed = true
      SaveProgress()
      return true
    end
    
    return false
  end
  
  -- Item ownership tracker (called on EQUIP_UNEQUIP events)
  local function ItemTracker()
    if state.completed then return true end
    
    -- Update ownership state
    UpdateItemOwnership()
    
    -- Check if achievement should be completed
    if CheckCompletion() then
      -- Mark achievement as completed in the row if it exists
      local row = _G[rowVarName]
      if row and _G.HCA_MarkRowCompleted then
        _G.HCA_MarkRowCompleted(row)
      end
      UpdateTooltip()
      return true
    end
    
    UpdateTooltip()
    return false
  end
  
  -- Store the tracker function globally for the main system
  -- Note: The bridge will call this on EQUIP_UNEQUIP events
  _G[achId] = ItemTracker
  
  _G[achId .. "_IsCompleted"] = function() 
    UpdateItemOwnership()
    return CheckCompletion()
  end
  
  -- Check eligibility
  local function IsEligible()
    -- Faction: "Alliance" / "Horde"
    if faction and select(2, UnitFactionGroup("player")) ~= faction then
      return false
    end
    
    -- Class: use class file tokens ("MAGE","WARRIOR",...)
    if class then
      local _, classFile = UnitClass("player")
      if classFile ~= class then
        return false
      end
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
    UpdateItemOwnership()
    
    -- Mark as dungeon set achievement (similar to isVariation for filtering)
    def.isDungeonSet = true
    
    _G[rowVarName] = CreateAchievementRow(
      AchievementPanel,
      achId,
      title,
      tooltip,
      icon,
      level,
      points,
      nil, -- No kill tracker for item sets
      nil, -- No quest tracker for item sets
      staticPoints,
      zone, -- Pass zone to row
      def
    )
    
    -- Store requiredItems on the row for easy access
    if requiredItems and next(requiredItems) then
      _G[rowVarName].requiredItems = requiredItems
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
    LoadProgress()
    UpdateItemOwnership()
    _G[registerFuncName]()
  end)
  
  if _G.CharacterFrame and _G.CharacterFrame.HookScript then
    CharacterFrame:HookScript("OnShow", function()
      LoadProgress()
      UpdateItemOwnership()
      _G[registerFuncName]()
    end)
  end
end

-- Export to global scope
_G.DungeonSetCommon = DungeonSetCommon

