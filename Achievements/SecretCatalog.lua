local Secrets = {
    -- Secret Achievements
{
    achId = "Secret00Horde",
    title = "Snowball at Thrall",
    level = nil,
    tooltip = "Throw a snowball at Thrall",
    icon = 236710,
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
    tooltip = "You have completed the secret achievement: |cff0091e6Kill a rat|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_rat.png", -- ??
    points = 0,
    targetNpcId = {4075, 13016, 2110},
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
    tooltip = "You have completed the secret achievement: |cff0091e6Drink some Noggenfogger|r",
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
    tooltip = "You have completed the secret achievement: |cff0091e6Pet Spot the Wolf|r",
    icon = 132203,
    points = 0,
    faction = FACTION_ALLIANCE,
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
    --secretIcon = 132387,
    secretPoints = 0,
    staticPoints = true,
}, {
    achId = "Secret004",
    title = "The Last Achievement",
    level = nil,
    tooltip = string.format("%s... your tale slips quietly into forgotten pages. Only echoes will remember your name now.", GetUnitName("player")),
    icon = 237542,
    points = 0,
    customIsCompleted = function() return UnitIsDeadOrGhost("player") end,
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret005",
    title = "Mak'gora",
    level = nil,
    tooltip = "Obtain an ear by winning a |cff0091e6Mak'gora|r",
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
}, 
-- {
--   achId = "Secret006",
--   title = "PLACEHOLDER",
--   level = nil,
--   tooltip = "",
--   icon = 237542,
--   points = 0,
--   customIsCompleted = function() return false end,
--   secret = true,
--   staticPoints = true,
--   hiddenUntilComplete = true,
-- },
{
    achId = "Secret007",
    title = "Mok'rash",
    level = 50,
    tooltip = "You have completed the secret achievement: |cffff8000Kill Mok'rash and complete the quest: 'The Monogrammed Sash' before level 51|r",
    icon = 133345,
    points = 0,
    requiredQuestId = 8552,
    secret = true,
    staticPoints = true,
    hiddenUntilComplete = true,
}, {
    achId = "Secret008",
    title = "Jump Master",
    level = nil,
    tooltip = "You have completed the secret achievement: |cff0091e6Jump 100,000 times|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_Icon_Feather01a.png", -- ??
    points = 0,
    customIsCompleted = function()
        if not _G.HardcoreAchievements_GetCharDB then
            return false
        end
        local _, cdb = _G.HardcoreAchievements_GetCharDB()
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
    tooltip = "You have completed the secret achievement: |cff0091e6Obtain the Forest Leather Belt|r",
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
  title = "O.G. Colectors Edition",
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
  
-- Register achievements and set up completion functions
for _, def in ipairs(Secrets) do
  if IsEligible(def) then
    if def.customKill then
      _G[def.achId .. "_Kill"] = def.customKill
      _G[def.achId .. "_IsCompleted"] = _G[def.achId .. "_IsCompleted"] or function() return false end
    elseif def.customIsCompleted then
      _G[def.achId .. "_IsCompleted"] = def.customIsCompleted
    else
      _G.Achievements_Common.registerQuestAchievement{
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
end

-- Export secrets to global scope for AdminPanel access
_G.Secrets = Secrets

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all secret achievements for deferred registration
for _, def in ipairs(Secrets) do
  if IsEligible(def) then
    -- Mark as secret for filtering
    def.isSecret = true
    -- Queue achievement registration
    table.insert(_G.HCA_RegistrationQueue, function()
      if def.customIsCompleted then
        _G[def.achId .. "_IsCompleted"] = def.customIsCompleted
      end
      
      local killFn = def.customKill or ((def.targetNpcId or def.requiredKills) and _G.HardcoreAchievements_GetAchievementFunction(def.achId, "Kill")) or nil
      local questFn = (def.requiredQuestId and _G.HardcoreAchievements_GetAchievementFunction(def.achId, "Quest")) or nil

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
    end)
  end
end