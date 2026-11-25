local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor())
local CheckMapDiscoveryByLocation = (addon and addon.CheckMapDiscoveryByLocation)
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
    icon = 1100023,
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
  achId = "OrgA",
  title = "Discover Orgrimmar",
  level = nil,
  tooltip = "Discover " .. ClassColor .. "Orgrimmar|r",
  icon = 463450,
  points = 0,
  explorationZone = "Orgrimmar",
  customIsCompleted = function()
      return CheckMapDiscoveryByLocation("Durotar", "Orgrimmar")
  end,
  faction = FACTION_ALLIANCE,
  staticPoints = true,
}, 
-- {
--   achId = "StormH",
--   title = "Discover Stormwind City",
--   level = nil,
--   tooltip = "Discover " .. ClassColor .. "Stormwind City|r",
--   icon = 463451,
--   points = 0,
--   explorationZone = "Stormwind City",
--   customIsCompleted = function()
--       return CheckMapDiscoveryByLocation("Elwynn Forest", "Stormwind City")
--   end,
--   faction = FACTION_HORDE,
--   staticPoints = true,
-- },
}

local KalimdorExplorationZones = {
  { zone = "Ashenvale", title = "Ashenvale", icon = 236713, points = 10 },
  { zone = "Azshara", title = "Azshara", icon = 236714, points = 10 },
  { zone = "Darkshore", title = "Darkshore", icon = 236739, points = 10 },
  --{ zone = "Darnassus", title = "Darnassus", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Desolace", title = "Desolace", icon = 236742, points = 10 },
  { zone = "Durotar", title = "Durotar", icon = 236756, points = 10 },
  { zone = "Dustwallow Marsh", title = "Dustwallow Marsh", icon = 236758, points = 10 },
  { zone = "Felwood", title = "Felwood", icon = 236763, points = 10 },
  { zone = "Feralas", title = "Feralas", icon = 236764, points = 10 },
  --{ zone = "Moonglade", title = "Moonglade", icon = 135758, points = 10 },
  { zone = "Mount Hyjal", title = "Mount Hyjal", icon = 409547, points = 10 },
  { zone = "Mulgore", title = "Mulgore", icon = 236809, points = 10 },
  --{ zone = "Orgrimmar", title = "Orgrimmar", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Shen'Dralas", title = "Shen'Dralas", icon = 135864, points = 10 },
  { zone = "Silithus", title = "Silithus", icon = 236829, points = 10 },
  { zone = "Stonetalon Mountains", title = "Stonetalon Mountains", icon = 236831, points = 10 },
  { zone = "Tanaris", title = "Tanaris", icon = 236846, points = 10 },
  --{ zone = "Teldrassil", title = "Teldrassil", icon = 236740, points = 10 },
  { zone = "The Barrens", title = "The Barrens", icon = 236717, points = 10 },
  --{ zone = "The Exodar", title = "The Exodar", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Thousand Needles", title = "Thousand Needles", icon = 236848, points = 10 },
  --{ zone = "Thunder Bluff", title = "Thunder Bluff", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Un'Goro Crater", title = "Un'Goro Crater", icon = 236850, points = 10 },
  { zone = "Winterspring", title = "Winterspring", icon = 236854, points = 10 },
}

local EasternKingdomsExplorationZones = {
  { zone = "Alterac Mountains", title = "Alterac Mountains", icon = 236711, points = 10 },
  { zone = "Arathi Highlands", title = "Arathi Highlands", icon = 236712, points = 10 },
  { zone = "Badlands", title = "Badlands", icon = 236716, points = 10 },
  { zone = "Blasted Lands", title = "Blasted Lands", icon = 236720, points = 10 },
  { zone = "Burning Steppes", title = "Burning Steppes", icon = 236734, points = 10 },
  { zone = "Deadwind Pass", title = "Deadwind Pass", icon = 236741, points = 10 },
  { zone = "Dun Morogh", title = "Dun Morogh", icon = 236755, points = 10 },
  { zone = "Duskwood", title = "Duskwood", icon = 236757, points = 10 },
  { zone = "Eastern Plaguelands", title = "Eastern Plaguelands", icon = 236760, points = 10 },
  { zone = "Elwynn Forest", title = "Elwynn Forest", icon = 236761, points = 10 },
  { zone = "Hillsbrad Foothills", title = "Hillsbrad Foothills", icon = 236779, points = 10 },
  --{ zone = "Ironforge", title = "Ironforge", icon = 236805, points = 0 },
  { zone = "Loch Modan", title = "Loch Modan", icon = 236808, points = 10 },
  { zone = "Redridge Mountains", title = "Redridge Mountains", icon = 236814, points = 10 },
  { zone = "Riverglades", title = "Riverglades", icon = 409547, points = 10 },
  { zone = "Searing Gorge", title = "Searing Gorge", icon = 236815, points = 10 },
  { zone = "Silverpine Forest", title = "Silverpine Forest", icon = 236830, points = 10 },
  --{ zone = "Stormwind City", title = "Stormwind City", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Stranglethorn Vale", title = "Stranglethorn Vale", icon = 236844, points = 10 },
  { zone = "Swamp of Sorrows", title = "Swamp of Sorrows", icon = 236845, points = 10 },
  { zone = "The Hinterlands", title = "The Hinterlands", icon = 236780, points = 10 },
  { zone = "Tirisfal Glades", title = "Tirisfal Glades", icon = 236849, points = 10 },
  --{ zone = "Undercity", title = "Undercity", icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_Zone_XXX.png", points = 0 },
  { zone = "Western Plaguelands", title = "Western Plaguelands", icon = 236851, points = 10 },
  { zone = "Westfall", title = "Westfall", icon = 236852, points = 10 },
  { zone = "Wetlands", title = "Wetlands", icon = 236853, points = 10 },
  { zone = "Zephra's Isle", title = "Zephra's Isle", icon = 409599, points = 10 },
}

local KalimdorContinentAchievement = {
  title = "Explore Kalimdor",
  icon = 236807,
  points = 50,
}

local EasternKingdomsContinentAchievement = {
  title = "Explore Eastern Kingdoms",
  icon = 236759,
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
  if def.faction and addon.PlayerFactionMatches and not addon.PlayerFactionMatches(def.faction) then
    return false
  elseif def.faction and not addon.PlayerFactionMatches then
    local factionTag, factionLocalized = UnitFactionGroup("player")
    if def.faction ~= factionTag and def.faction ~= factionLocalized then
      return false
    end
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
                if addon and addon.CompleteAchievementWithToast then
                    addon.CompleteAchievementWithToast(fellowshipRow)
                end
            end)
        end
        self:UnregisterAllEvents()
    end
end)
