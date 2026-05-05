---------------------------------------
-- Secret Achievement Definitions (TBC)
---------------------------------------
local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor())
local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitFactionGroup = UnitFactionGroup
local GetUnitName = GetUnitName
local GetItemCount = GetItemCount
local strsplit = strsplit
local table_insert = table.insert
local string_format = string.format

local Secrets = {
{
    achId = "Secret00Horde",
    title = "Snowball at Thrall",
    level = nil,
    tooltip = "Throw a snowball at Thrall",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_worldevent_xmasogre.png", -- 236710
    points = 0,
    faction = FACTION_HORDE,
    zone = "Orgrimmar",
    customIsCompleted = function() return false end,
    customSpell = function(spellId, targetName)
        if targetName == "Thrall" and spellId == 21343 then
            return true
        end
        return false
    end,
    -- Secret presentation before completion
    secret = true,
    secretTitle = "Who Threw That?",
    secretTooltip = "I wonder who to throw a snowball at...",
    secretIcon = 132387,
    --secretPoints = 1,
    staticPoints = true,
}, {
    achId = "Secret00Alliance",
    title = "Snowball at Highlord Bolvar Fordragon",
    level = nil,
    tooltip = "Throw a snowball at Highlord Bolvar Fordragon",
    icon = 133169,
    points = 0,
    faction = FACTION_ALLIANCE,
    zone = "Stormwind City",
    customIsCompleted = function() return false end,
    customSpell = function(spellId, targetName)
        if targetName == "Highlord Bolvar Fordragon" and spellId == 21343 then
            return true
        end
        return false
    end,
    -- Secret presentation before completion
    secret = true,
    secretTitle = "Who Threw That?",
    secretTooltip = "I wonder who to throw a snowball at...",
    secretIcon = 132387,
    --secretPoints = 1,
    staticPoints = true,
}, {
    achId = "Secret001",
    title = "Rats! Rats! Rats!",
    level = nil,
    tooltip = "You have completed the secret achievement: " .. ClassColor .. "Kill a rat|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_rat.png", -- ??
    points = 0,
    targetNpcId = {4075, 13016, 2110},
    allowSoloDouble = false,
    secret = true,
    secretTitle = "Secret Achievement",
    secretTooltip = "You will probably complete this achievement by accident",
    --secretIcon = 132387,
    secretPoints = 0,
    staticPoints = true,
}, {
    achId = "Secret002",
    title = "Taking the Edge Off",
    level = nil,
    tooltip = "You have completed the secret achievement: " .. ClassColor .. "Drink some Noggenfogger|r",
    icon = 134863,
    points = 0,
    customIsCompleted = function() return false end,
    customSpell = function(spellId, targetName)
        if spellId == 16589 then
            return true
        end
        return false
    end,
    secret = true,
    secretTitle = "Secret Achievement",
    secretTooltip = "You will probably complete this achievement by accident",
    --secretIcon = 132387,
    secretPoints = 0,
    staticPoints = true,
}, {
    achId = "Secret003",
    title = "Who's A Good Boy?",
    level = nil,
    tooltip = "You have completed the secret achievement: " .. ClassColor .. "Pet Spot the Wolf|r",
    icon = 132203,
    points = 0,
    customIsCompleted = function() return false end,
    customEmote = function(token)
        if token ~= "PET" then
            return false
        end

        local targetGuid = UnitGUID("target")
        if not targetGuid then
            return false
        end

        local _, _, _, _, _, npcIdStr = strsplit("-", targetGuid)
        local npcId = npcIdStr and tonumber(npcIdStr) or nil
        return npcId == 4950
    end,
    secret = true,
    secretTitle = "Secret Achievement",
    secretTooltip = "I spot a good boy!",
    secretPoints = 0,
    staticPoints = true,
}, {
    achId = "Secret004",
    title = "The Last Achievement",
    level = nil,
    tooltip = string_format("%s... your tale slips quietly into forgotten pages. Only echoes will remember your name now.", GetUnitName("player")),
    -- When this achievement is linked in chat, prefer the completer/sender name instead of the viewer name.
    -- (The real tooltip is still hidden from viewers who haven't completed it.)
    linkTooltip = function(senderName)
      return string_format("%s... your tale slips quietly into forgotten pages. Only echoes will remember your name now.", tostring(senderName or ""))
    end,
    icon = 237542,
    points = 0,
    customIsCompleted = function() return UnitIsDeadOrGhost("player") end,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret005",
    title = "Mak'gora",
    level = nil,
    tooltip = "Obtain an ear by winning a " .. ClassColor .. "Mak'gora|r",
    icon = 133854,
    points = 0,
    customIsCompleted = function() return false end,
    customAura = function()
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end
            if spellId == 419126 or name == "String of Ears" then
                return true
            end
        end
        return false
    end,
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret006",
    title = "Holographic!",
    level = nil,
    tooltip = "You have completed the secret achievement: |cffff8000Obtain the Prismatic Punch Card|r",
    icon = 134391,
    points = 0,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(9316, true) > 0 end,
    -- Secret presentation before completion
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret007",
    title = "Mok'rash",
    level = 50,
    tooltip = "You have completed the secret achievement: |cffff8000Kill Mok'rash and complete the quest: 'The Monogrammed Sash' before level 51|r",
    icon = 133694,
    points = 0,
    requiredQuestId = 8552,
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret008",
    title = "Jump Master",
    level = nil,
    tooltip = "You have completed the secret achievement: " .. ClassColor .. "Jump 100,000 times|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_Icon_Feather01a.png", -- ??
    points = 0,
    customIsCompleted = function()
        local GetCharDB = addon and addon.GetCharDB
        if not GetCharDB then
            return false
        end
        local _, cdb = GetCharDB()
        if not cdb or not cdb.stats or not cdb.stats.playerJumps then
            return false
        end
        return cdb.stats.playerJumps >= 100000
    end,
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret009",
    title = "The Warlord of the Rings",
    level = nil,
    tooltip = "You have completed the secret achievement: |cffff8000Obtain The 1 Ring|r",
    icon = 133345,
    points = 0,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(8350, true) > 0 end,
    -- Secret presentation before completion
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret0010",
    title = "Scarlet Crusade",
    level = nil,
    tooltip = "You have completed the secret achievement: |cffff8000Obtain the Tabard of the Scarlet Crusade|r",
    icon = 133770,
    points = 0,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(23192, true) > 0 end,
    -- Secret presentation before completion
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret0011",
    title = "Legendary Resonance",
    level = nil,
    tooltip = "You have completed the secret achievement: |cffff8000Obtain the Black Qiraji Resonating Crystal|r",
    icon = 134399,
    points = 0,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(21176, true) > 0 end,
    -- Secret presentation before completion
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret0012",
    title = "Level 18? Ughhh",
    level = nil,
    tooltip = "You have completed the secret achievement: " .. ClassColor .. "Obtain the Forest Leather Belt|r",
    icon = 132492,
    points = 0,
    customIsCompleted = function() return false end,
    customItem = function() return GetItemCount(6382, true) > 0 end,
    -- Secret presentation before completion
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
  achId = "Secret013",
  title = "O.G. Collectors Edition",
  level = nil,
  tooltip = "You have completed the secret achievement: |cffff8000Owner of the Vanilla Collectors Edition|r",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\DiabloAnniversary_Achievement.png", -- ??
  points = 0,
  customIsCompleted = function() return false end,
  customItem = function() return (GetItemCount(13584, true) > 0 or GetItemCount(13583, true) > 0 or GetItemCount(13582, true) > 0) end,
  -- Secret presentation before completion
  secret = true,
  staticPoints = true,
  hiddenUntilComplete = true,
}, {
    achId = "Secret014",
    title = "Streamer Client",
    level = nil,
    tooltip = "You have completed the secret achievement: |cffff8000Loot a very rare quest item on the first kill|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Boss_Golden_Lotus_Council.png",
    points = 0,
    customIsCompleted = function()
        local p = addon and addon.GetProgress and addon.GetProgress("Secret014")
        return p and p.firstKillRareState and p.firstKillRareState.met == true
    end,
    -- Variants: PARTY_KILL on npcIds only while questId is in the log (first such kill starts counting).
    -- Progress is never cleared on accept/abandon/turn-in. BAG_UPDATE_DELAYED: killsTotal==1 and
    -- GetItemCount(itemId,true)>=1 completes (no chat loot). No work while no variant quest is in log.
    -- Implementation: Achievements/FirstKillRareQuestLoot.lua (shared with Classic).
    firstKillRareQuestLoot = {
      { itemId = 5097, questId = 896, npcIds = { 3283, 3286, 9336 } },             -- Cat's Eye Emerald / Miner's Fortune [Horde]
      { itemId = 4891, questId = 816, npcIds = { 3110, 3231 } },                   -- Kron's Amulet / Lost But Not Forgotten [Horde]
      { itemId = 3708, questId = 552, npcIds = { 2248, 2249, 2250, 2251 } },       -- Helcular's Rod / Helcular's Revenge [Horde]
      { itemId = 3693, questId = 547, npcIds = { 2345, 2344, 2346 } },             -- Humbert's Sword / Humbert's Sword [Horde]
      { itemId = 4639, questId = 736, npcIds = { 4363 } },                         -- Enchanted Sea Kelp / The Star, THe Hand, and the Heart [Horde]
      { itemId = 3862, questId = 571, npcIds = { 1557 } },                         -- Aged Gorilla Sinew / Mok'thardin's Enchantment [Horde]
      { itemId = 3349, questId = 470, npcIds = { 1032, 1031, 1033 } },             -- Sida's Bag / Digging Through the Ooze [Alliance]
      { itemId = 4639, questId = 735, npcIds = { 4363 } },                         -- Enchanted Sea Kelp / The Star, THe Hand, and the Heart [Alliance]
      { itemId = 3930, questId = 613, npcIds = { 709, 680, 710, 678, 679, 723 } }, -- Maury's Key / Cracking Maury's Foot [Neutral]
      { itemId = 8428, questId = 2605, npcIds = { 5481 } },                        -- Laden Dew Gland / The Thirsty Goblin [Neutral]
      { itemId = 18959, questId = 7728, npcIds = { 5840 } },                       -- Smithing Tuyere / STOLEN: Smithing Tuyere and Lookout's Spyglass [Neutral]
      { itemId = 18960, questId = 7728, npcIds = { 8566 } },                       -- Lookout's Spyglass / STOLEN: Smithing Tuyere and Lookout's Spyglass [Neutral]
      { itemId = 12367, questId = 977, npcIds = { 7460, 7459 }, requiredKills = 2, requiredItems = 2 }, -- Pristine Yeti Horn / Are We There, Yeti? [Neutral]
    },
    supportsStoredFailure = true,
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret100",
    title = "You've Got the Chills",
    level = nil,
    tooltip = "You've unlocked the authors hidden achievement",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Chills.png",
    points = 0,
    customIsCompleted = function() return false end,
    customEmote = function(token)
        return token == "COLD"
      end,
    -- Secret presentation before completion
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
},
-- {
--     achId = "Sylvanas",
--     title = "Something for Sylvanas",
--     level = 60,
--     tooltip = "Give Sylvanas a gift",
--     icon = 236560,
--     points = 1,
--     faction = FACTION_HORDE,
--     zone = "Undercity",
--     customIsCompleted = function() return false end,
--     customEmote = function(token, targetName)
--         return token == "BOW" and targetName == "Lady Sylvanas Windrunner"
--       end,
--     -- Secret presentation before completion
--     secret = true,
--     secretTitle = "Secret",
--     secretTooltip = "I wonder who to give a gift to...",
--     secretIcon = 132387,
--     --secretPoints = 1,
--     staticPoints = true,
--     hiddenUntilComplete = true,
-- }
}

local function IsEligible(def)
    -- Faction: "Alliance" / "Horde"
    if def.faction and select(2, UnitFactionGroup("player")) ~= def.faction then
      return false
    end
  
    -- Race: allow either raceFile or localized race name in the def
    if def.race then
      local raceName, raceFile = UnitRace("player")
      if def.race ~= raceFile and def.race ~= raceName then
        return false
      end
    end
  
    -- Class: use class file tokens ("MAGE","WARRIOR",...)
    if def.class then
      local _, classFile = UnitClass("player")
      if classFile ~= def.class then
        return false
      end
    end
  
    return true
end

---------------------------------------
-- Registration Logic (deferred to queue so IsEligible is valid at PLAYER_LOGIN)
---------------------------------------

if addon then
  addon.Secrets = Secrets
end

---------------------------------------
-- Deferred Registration Queue
---------------------------------------
if addon then
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local RegisterAchievementDef = addon.RegisterAchievementDef

  for _, def in ipairs(Secrets) do
    def.isSecret = true
    table_insert(queue, function()
      if not IsEligible(def) then return end
      -- Register completion logic when eligibility is known (same as former load-time block)
      if def.customKill then
        if addon and addon.RegisterCustomAchievement then
          addon.RegisterCustomAchievement(def.achId, def.customKill, def.customIsCompleted or function() return false end)
        end
      elseif def.customIsCompleted then
        if addon and addon.RegisterCustomAchievement then
          addon.RegisterCustomAchievement(def.achId, nil, def.customIsCompleted)
        end
      else
        if addon and addon.registerQuestAchievement then
          addon.registerQuestAchievement{
            achId           = def.achId,
            requiredQuestId = def.requiredQuestId,
            targetNpcId     = def.targetNpcId,
            requiredKills   = def.requiredKills,
            maxLevel        = def.level,
            faction         = def.faction,
            race            = def.race,
            class           = def.class,
            allowKillsBeforeQuest = def.allowKillsBeforeQuest,
          }
        end
      end
      local killFn = def.customKill or ((def.targetNpcId or def.requiredKills) and addon and addon.GetAchievementFunction and addon.GetAchievementFunction(def.achId, "Kill")) or nil
      local questFn = (def.requiredQuestId and addon and addon.GetAchievementFunction and addon.GetAchievementFunction(def.achId, "Quest")) or nil
      if RegisterAchievementDef then
        RegisterAchievementDef(def)
      end
      local CreateAchievementRow = addon.CreateAchievementRow
      local AchievementPanel = addon.AchievementPanel
      if CreateAchievementRow and AchievementPanel then
        CreateAchievementRow(
          AchievementPanel,
          def.achId,
          def.title,
          def.tooltip,
          def.icon,
          def.level,
          def.points or 0,
          killFn,
          questFn,
          def.staticPoints,
          def.zone,
          def
        )
      end
    end)
  end
end