-- Reputation achievement definitions
-- Each achievement requires reaching Exalted with a specific faction
-- Only factions that the player has discovered will show up in the achievement list
local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor)
local table_insert = table.insert

local Reputations = {
  
  -- ALLIANCE
  {
    achId = "Stormwind",
    title = "Exalted with Stormwind",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Stormwind|r",
    icon = 236681,
    points = 100,
    factionId = 72,
    staticPoints = true,
  }, {
    achId = "Darnassus",
    title = "Exalted with Darnassus",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Darnassus|r",
    icon = 236681,
    points = 100,
    factionId = 69,
    staticPoints = true,
  }, {
    achId = "Ironforge",
    title = "Exalted with Ironforge",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ironforge|r",
    icon = 236681,
    points = 100,
    factionId = 47,
    staticPoints = true,
  }, {
    achId = "Gnomeregan Exiles",
    title = "Exalted with Gnomeregan Exiles",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Gnomeregan Exiles|r",
    icon = 236681,
    points = 100,
    factionId = 54,
    staticPoints = true,
  },
  
  -- HORDE
  {
    achId = "Orgrimmar",
    title = "Exalted with Orgrimmar",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Orgrimmar|r",
    icon = 236681,
    points = 100,
    factionId = 76,
    staticPoints = true,
  }, {
    achId = "Thunder Bluff",
    title = "Exalted with Thunder Bluff",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Thunder Bluff|r",
    icon = 236681,
    points = 100,
    factionId = 81,
    staticPoints = true,
  }, {
    achId = "Undercity",
    title = "Exalted with Undercity",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Undercity|r",
    icon = 236681,
    points = 100,
    factionId = 68,
    staticPoints = true,
  }, {
    achId = "Darkspear Trolls",
    title = "Exalted with Darkspear Trolls",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Darkspear Trolls|r",
    icon = 236681,
    points = 100,
    factionId = 530,
    staticPoints = true,
  },
  
  -- NEUTRAL
  {
    achId = "BootyBay",
    title = "Exalted with Booty Bay",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Booty Bay|r",
    icon = 236688,
    points = 200,
    factionId = 21,
    staticPoints = true,
  }, {
    achId = "Ratchet",
    title = "Exalted with Ratchet",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ratchet|r",
    icon = 236688,
    points = 200,
    factionId = 470,
    staticPoints = true,
  }, {
    achId = "Everlook",
    title = "Exalted with Everlook",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Everlook|r",
    icon = 236688,
    points = 200,
    factionId = 577,
    staticPoints = true,
  }, {
    achId = "Gadgetzan",
    title = "Exalted with Gadgetzan",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Gadgetzan|r",
    icon = 236688,
    points = 200,
    factionId = 369,
    staticPoints = true,
  }, {
    achId = "ArgentDawn",
    title = "Exalted with Argent Dawn",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Argent Dawn|r",
    icon = 236688,
    points = 150,
    factionId = 529,
    staticPoints = true,
  }, {
    achId = "Timbermaw",
    title = "Exalted with Timbermaw Hold",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Timbermaw Hold|r",
    icon = 236688,
    points = 200,
    factionId = 576,
    staticPoints = true,
  }, {
    achId = "CenarionCircle",
    title = "Exalted with Cenarion Circle",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Cenarion Circle|r",
    icon = 236688,
    points = 150,
    factionId = 609,
    staticPoints = true,
  }, {
    achId = "ThoriumBrotherhood",
    title = "Exalted with Thorium Brotherhood",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Thorium Brotherhood|r",
    icon = 236688,
    points = 150,
    factionId = 59,
    staticPoints = true,
  }, {
    achId = "Hydraxian",
    title = "Exalted with Hydraxian Waterlords",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Hydraxian Waterlords|r",
    icon = 236688,
    points = 150,
    factionId = 749,
    staticPoints = true,
  }, {
    achId = "Zandalar",
    title = "Exalted with Zandalar Tribe",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Zandalar Tribe|r",
    icon = 236688,
    points = 150,
    factionId = 270,
    staticPoints = true,
  }, {
    achId = "Nozdormu",
    title = "Exalted with Brood of Nozdormu",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Brood of Nozdormu|r",
    icon = 236688,
    points = 150,
    factionId = 910,
    staticPoints = true,
  },

  -- NOVELTY
  {
    achId = "Bloodsail",
    title = "Exalted with Bloodsail Buccaneers",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Bloodsail Buccaneers|r",
    icon = 236685,
    points = 200,
    factionId = 87,
    staticPoints = true,
  }, {
    achId = "Wintersaber",
    title = "Exalted with Wintersaber Trainers",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Wintersaber Trainers|r",
    icon = 236685,
    points = 200,
    factionId = 589,
    staticPoints = true,
  },

  -- ROGUE
  {
    achId = "Ravenholdt",
    title = "Exalted with Ravenholdt |cfffff468[Rogue]|r",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ravenholdt|r",
    icon = 236686,
    points = 200,
    factionId = 349,
    staticPoints = true,
    class = "ROGUE",
  },
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
if addon then
  addon.RegistrationQueue = addon.RegistrationQueue or {}
  local queue = addon.RegistrationQueue
  local ReputationCommon = addon and addon.ReputationCommon
  if ReputationCommon and ReputationCommon.registerReputationAchievement then
    for _, def in ipairs(Reputations) do
      table_insert(queue, function()
        ReputationCommon.registerReputationAchievement(def)
      end)
    end
  end
end
