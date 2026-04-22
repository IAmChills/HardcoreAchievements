local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor())
local CheckZoneDiscovery = (addon and addon.CheckZoneDiscovery)
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitFactionGroup = UnitFactionGroup
local table_insert = table.insert
local string_gsub = string.gsub

local function MakeExplorationAchId(zoneName)
  local sanitized = string_gsub(zoneName or "", "[^%a%d]", "")
  return "Explore" .. sanitized
end

local function CreateZoneExplorationAchievement(cfg)
  local zoneName = cfg.zone
  local title = cfg.title
  local tooltip = cfg.tooltip or ("Explore all the areas of " .. ClassColor .. zoneName .. "|r")

  return {
    achId = MakeExplorationAchId(zoneName),
    title = title,
    level = nil,
    tooltip = tooltip,
    icon = cfg.icon,
    points = cfg.points,
    explorationZone = zoneName,
    customIsCompleted = function()
      return CheckZoneDiscovery(zoneName)
    end,
    staticPoints = true,
  }
end

local function AreAllAchievementsCompleted(achievementIds)
  if not achievementIds or #achievementIds == 0 then
    return false
  end

  for _, achId in ipairs(achievementIds) do
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
    local isCompleted = progress and progress.completed
    if not isCompleted and addon and addon.GetAchievementRow then
      local row = addon.GetAchievementRow(achId)
      isCompleted = row and row.completed
    end
    if not isCompleted then
      return false
    end
  end

  return true
end

local function CreateContinentExplorationAchievement(continentName, zoneConfigs, continentCfg)
  local requiredAchievements = {}

  for _, zoneCfg in ipairs(zoneConfigs) do
    table_insert(requiredAchievements, MakeExplorationAchId(zoneCfg.zone))
  end

  return {
    achId = continentCfg.achId or ("Explore" .. string_gsub(continentName or "", "[^%a%d]", "")),
    title = continentCfg.title,
    level = nil,
    tooltip = continentCfg.tooltip or ("Explore all the zones in " .. ClassColor .. continentName .. "|r"),
    icon = continentCfg.icon,
    points = continentCfg.points,
    isContinentExploration = true,
    requiredAchievements = requiredAchievements,
    achievementOrder = requiredAchievements,
    customIsCompleted = function()
      return AreAllAchievementsCompleted(requiredAchievements)
    end,
    staticPoints = true,
  }
end

local ExplorationAchievements = {
{
    achId = "Precious",
    title = "The Precious",
    level = nil,
    tooltip = "Starting as a level 1 character, journey on foot to " .. ClassColor .. "Blackrock Mountain|r and destroy |cffff8000The 1 Ring|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_DARKMOON_EYE.png",
    points = 0,
    customIsCompleted = function()
        -- This achievement is completed when the player deletes "The 1 Ring" (itemId 8350)
        -- while in Blackrock Mountain (mapId 1415). The event bridge in HardcoreAchievements.lua
        -- sets this flag only after a confirmed delete that results in 0 remaining.
        return (addon and addon.Precious_RingDeleted) == true
    end,
    staticPoints = true,
}, {
  achId = "Fellowship",
  title = "Fellowship of the 1 Ring",
  level = nil,
  tooltip = "Stand with another adventurer and aid them in their perilous journey to " .. ClassColor .. "Blackrock Mountain|r to destroy |cffff8000The 1 Ring|r, sharing in the burden and seeing the quest through.\n\nMust be within 25 yards of the player who destroys the ring.",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\ThePrecious.png",
  points = 0,
  customIsCompleted = function() return false end,
  staticPoints = true,
}, {
  achId = "MessageToKarazhan",
  title = "Urgent Message to Karazhan",
  level = nil,
  tooltip = "Discover all of " .. ClassColor .. "Deadwind Pass|r and speak to " .. ClassColor .. "Archmage Leryda|r at the entrance of " .. ClassColor .. "Karazhan|r at or before level 25",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Raid_Karazhan.png",
  points = 0,
  explorationZone = "Deadwind Pass",
  customIsCompleted = function() return CheckZoneDiscovery(1430, 0.5) and UnitName("npc") == "Archmage Leryda" and UnitLevel("player") <= 25 end,
  staticPoints = true,
}, {
  achId = "OrgA",
  title = "Discover Orgrimmar",
  level = nil,
  tooltip = "Discover " .. ClassColor .. "Orgrimmar|r",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_PVP_Legion05.png",
  points = 0,
  explorationZone = "Orgrimmar",
  customIsCompleted = function()
      return CheckZoneDiscovery(1411)
  end,
  faction = FACTION_ALLIANCE,
  staticPoints = true,
}, {
  achId = "StormH",
  title = "Discover Stormwind City",
  level = nil,
  tooltip = "Discover " .. ClassColor .. "Stormwind City|r",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_PVP_Legion05.png",
  points = 0,
  explorationZone = "Stormwind City",
  customIsCompleted = function()
      return CheckZoneDiscovery(1429)
  end,
  faction = FACTION_HORDE,
  staticPoints = true,
},
}

local KalimdorExplorationZones = {
  { zone = "Ashenvale", title = "Ashenvale", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Ashenvale_01.png", points = 10 },
  { zone = "Azshara", title = "Azshara", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_zone_azshara_01.png", points = 10 },
  { zone = "Darkshore", title = "Darkshore", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Darkshore_01.png", points = 10 },
  --{ zone = "Darnassus", title = "Darnassus", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Desolace", title = "Desolace", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Desolace.png", points = 10 },
  { zone = "Durotar", title = "Durotar", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Durotar.png", points = 10 },
  { zone = "Dustwallow Marsh", title = "Dustwallow Marsh", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_DustwallowMarsh.png", points = 10 },
  { zone = "Felwood", title = "Felwood", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Felwood.png", points = 0 },
  { zone = "Feralas", title = "Feralas", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Feralas.png", points = 10 },
  { zone = "Moonglade", title = "Moonglade", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Spell_Arcane_TeleportMoonglade.png", points = 10 },
  { zone = "Mulgore", title = "Mulgore", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Mulgore_01.png", points = 10 },
  --{ zone = "Orgrimmar", title = "Orgrimmar", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Silithus", title = "Silithus", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Silithus_01.png", points = 10 },
  { zone = "Stonetalon Mountains", title = "Stonetalon Mountains", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Stonetalon_01.png", points = 10 },
  { zone = "Tanaris", title = "Tanaris", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Tanaris_01.png", points = 10 },
  { zone = "Teldrassil", title = "Teldrassil", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Darnassus.png", points = 10 },
  { zone = "The Barrens", title = "The Barrens", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Barrens_01.png", points = 10 },
  --{ zone = "The Exodar", title = "The Exodar", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Thousand Needles", title = "Thousand Needles", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_ThousandNeedles_01.png", points = 10 },
  --{ zone = "Thunder Bluff", title = "Thunder Bluff", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Un'Goro Crater", title = "Un'Goro Crater", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_UnGoroCrater_01.png", points = 10 },
  { zone = "Winterspring", title = "Winterspring", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Winterspring.png", points = 10 },
}

local EasternKingdomsExplorationZones = {
  { zone = "Alterac Mountains", title = "Alterac Mountains", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_AlteracMountains_01.png", points = 10 },
  { zone = "Arathi Highlands", title = "Arathi Highlands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_ArathiHighlands_01.png", points = 10 },
  { zone = "Badlands", title = "Badlands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Badlands_01.png", points = 10 },
  { zone = "Blasted Lands", title = "Blasted Lands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_BlastedLands_01.png", points = 10 },
  { zone = "Burning Steppes", title = "Burning Steppes", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_BurningSteppes_01.png", points = 10 },
  { zone = "Deadwind Pass", title = "Deadwind Pass", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_DeadwindPass.png", points = 10 },
  { zone = "Dun Morogh", title = "Dun Morogh", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_DunMorogh.png", points = 10 },
  { zone = "Duskwood", title = "Duskwood", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Duskwood.png", points = 0 },
  { zone = "Eastern Plaguelands", title = "Eastern Plaguelands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_EasternPlaguelands.png", points = 0 },
  { zone = "Elwynn Forest", title = "Elwynn Forest", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_ElwynnForest.png", points = 10 },
  { zone = "Hillsbrad Foothills", title = "Hillsbrad Foothills", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_HillsbradFoothills.png", points = 10 },
  --{ zone = "Ironforge", title = "Ironforge", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Loch Modan", title = "Loch Modan", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_LochModan.png", points = 10 },
  { zone = "Redridge Mountains", title = "Redridge Mountains", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_RedridgeMountains.png", points = 10 },
  { zone = "Searing Gorge", title = "Searing Gorge", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_SearingGorge_01.png", points = 10 },
  { zone = "Silverpine Forest", title = "Silverpine Forest", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Silverpine_01.png", points = 10 },
  --{ zone = "Stormwind City", title = "Stormwind City", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Stranglethorn Vale", title = "Stranglethorn Vale", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Stranglethorn_01.png", points = 10 },
  { zone = "Swamp of Sorrows", title = "Swamp of Sorrows", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_SwampSorrows_01.png", points = 10 },
  { zone = "The Hinterlands", title = "The Hinterlands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Hinterlands_01.png", points = 10 },
  { zone = "Tirisfal Glades", title = "Tirisfal Glades", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_TirisfalGlades_01.png", points = 10 },
  --{ zone = "Undercity", title = "Undercity", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Western Plaguelands", title = "Western Plaguelands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_WesternPlaguelands_01.png", points = 10 },
  { zone = "Westfall", title = "Westfall", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_WestFall_01.png", points = 10 },
  { zone = "Wetlands", title = "Wetlands", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_Wetlands_01.png", points = 10 },
}

local KalimdorContinentAchievement = {
  title = "Explore Kalimdor",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_EasternKingdoms_01.png",
  points = 50,
}

local EasternKingdomsContinentAchievement = {
  title = "Explore Eastern Kingdoms",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_EasternKingdoms_01.png",
  points = 50,
}

local ZoneExplorationOrder = {}
for _, zoneCfg in ipairs(KalimdorExplorationZones) do
  table_insert(ZoneExplorationOrder, zoneCfg)
end
for _, zoneCfg in ipairs(EasternKingdomsExplorationZones) do
  table_insert(ZoneExplorationOrder, zoneCfg)
end

for _, zoneCfg in ipairs(ZoneExplorationOrder) do
  table_insert(ExplorationAchievements, CreateZoneExplorationAchievement(zoneCfg))
end

table_insert(ExplorationAchievements, CreateContinentExplorationAchievement("Kalimdor", KalimdorExplorationZones, KalimdorContinentAchievement))
table_insert(ExplorationAchievements, CreateContinentExplorationAchievement("Eastern Kingdoms", EasternKingdomsExplorationZones, EasternKingdomsContinentAchievement))

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
-- Check faction eligibility (same pattern as Catalog.lua and SecretCatalog.lua)
local function IsEligible(def)
  if def.faction and select(2, UnitFactionGroup("player")) ~= def.faction then
    return false
  end
  return true
end

if addon then
  for _, def in ipairs(ExplorationAchievements) do
    if def.customIsCompleted and addon.RegisterCustomAchievement then
      addon.RegisterCustomAchievement(def.achId, nil, def.customIsCompleted)
    end
  end
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local RegisterAchievementDef = addon.RegisterAchievementDef

  for _, def in ipairs(ExplorationAchievements) do
    def.isExploration = true
    table_insert(queue, function()
      if not IsEligible(def) then return end
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
          nil,
          nil,
          def.staticPoints,
          def.zone,
          def
        )
      end
    end)
  end
end

---------------------------------------
-- Fellowship Achievement Handler
---------------------------------------

-- Helper: Find achievement row by ID
local function FindAchievementRow(achId)
    if not AchievementPanel or not AchievementPanel.achievements then
        return nil
    end
    for _, row in ipairs(AchievementPanel.achievements) do
        local id = row and (row.id or row.achId)
        if row and id == achId then
            return row
        end
    end
    return nil
end

-- Handle Fellowship achievement when someone nearby completes Precious
-- Register callback with CommandHandler to receive Precious completion messages
local fellowshipFrame = CreateFrame("Frame")
fellowshipFrame:RegisterEvent("PLAYER_LOGIN")
fellowshipFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        local RegisterPreciousCompletionCallback = (addon and addon.RegisterPreciousCompletionCallback)
        if RegisterPreciousCompletionCallback then
            RegisterPreciousCompletionCallback(function(payload, sender)
                -- Only check if Fellowship isn't already completed
                local fellowshipRow = FindAchievementRow("Fellowship")
                
                -- If Fellowship is already completed, don't do anything
                if not fellowshipRow or fellowshipRow.completed then
                    return
                end
                
                -- If we received the message via SAY, we're within chat range (approximately 40 yards)
                -- Complete Fellowship for the nearby player
                if addon and addon.MarkRowCompleted and addon.AchToast_Show then
                    addon.MarkRowCompleted(fellowshipRow)
                    addon.AchToast_Show(fellowshipRow.Icon:GetTexture(), fellowshipRow.Title:GetText(), fellowshipRow.points, fellowshipRow)
                end
            end)
        end
        self:UnregisterAllEvents()
    end
end)
