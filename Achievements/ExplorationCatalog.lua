local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor)
local CheckZoneDiscovery = (addon and addon.CheckZoneDiscovery)
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitFactionGroup = UnitFactionGroup
local table_insert = table.insert

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
  customIsCompleted = function() return CheckZoneDiscovery(1430) and UnitName("npc") == "Archmage Leryda" and UnitLevel("player") <= 25 end,
  staticPoints = true,
}, {
  achId = "OrgA",
  title = "Discover Orgrimmar",
  level = nil,
  tooltip = "Discover " .. ClassColor .. "Orgrimmar|r",
  icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_PVP_Legion05.png",
  points = 0,
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
  customIsCompleted = function()
      return CheckZoneDiscovery(1429)
  end,
  faction = FACTION_HORDE,
  staticPoints = true,
},
}

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
  local CreateAchievementRow = addon.CreateAchievementRow
  local AchievementPanel = addon.AchievementPanel
  local RegisterAchievementDef = addon.RegisterAchievementDef or (HCA_SharedUtils and HCA_SharedUtils.RegisterAchievementDef)

  for _, def in ipairs(ExplorationAchievements) do
    if IsEligible(def) then
      def.isExploration = true
      table_insert(queue, function()
        if RegisterAchievementDef then
          RegisterAchievementDef(def)
        end
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
            def.staticPoints,
            def.zone,
            def
          )
        end
      end)
    end
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
