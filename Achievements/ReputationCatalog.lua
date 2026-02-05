-- Reputation achievement definitions
-- Each achievement requires reaching Exalted with a specific faction
-- Only factions that the player has discovered will show up in the achievement list
local table_insert = table.insert

local Reputations = {
  
  -- ALLIANCE
  {
    achId = "Stormwind",
    title = "Exalted with Stormwind",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Stormwind|r",
    icon = 236681,
    points = 100,
    factionId = 72,
    staticPoints = true,
  }, {
    achId = "Darnassus",
    title = "Exalted with Darnassus",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Darnassus|r",
    icon = 236681,
    points = 100,
    factionId = 69,
    staticPoints = true,
  }, {
    achId = "Ironforge",
    title = "Exalted with Ironforge",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ironforge|r",
    icon = 236681,
    points = 100,
    factionId = 47,
    staticPoints = true,
  }, {
    achId = "Gnomeregan Exiles",
    title = "Exalted with Gnomeregan Exiles",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Gnomeregan Exiles|r",
    icon = 236681,
    points = 100,
    factionId = 54,
    staticPoints = true,
  },
  
  -- HORDE
  {
    achId = "Orgrimmar",
    title = "Exalted with Orgrimmar",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Orgrimmar|r",
    icon = 236681,
    points = 100,
    factionId = 76,
    staticPoints = true,
  }, {
    achId = "Thunder Bluff",
    title = "Exalted with Thunder Bluff",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Thunder Bluff|r",
    icon = 236681,
    points = 100,
    factionId = 81,
    staticPoints = true,
  }, {
    achId = "Undercity",
    title = "Exalted with Undercity",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Undercity|r",
    icon = 236681,
    points = 100,
    factionId = 68,
    staticPoints = true,
  }, {
    achId = "Darkspear Trolls",
    title = "Exalted with Darkspear Trolls",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Darkspear Trolls|r",
    icon = 236681,
    points = 100,
    factionId = 530,
    staticPoints = true,
  },
  
  -- NEUTRAL
  {
    achId = "BootyBay",
    title = "Exalted with Booty Bay",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Booty Bay|r",
    icon = 236688,
    points = 200,
    factionId = 21,
    staticPoints = true,
  }, {
    achId = "Ratchet",
    title = "Exalted with Ratchet",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ratchet|r",
    icon = 236688,
    points = 200,
    factionId = 470,
    staticPoints = true,
  }, {
    achId = "Everlook",
    title = "Exalted with Everlook",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Everlook|r",
    icon = 236688,
    points = 200,
    factionId = 577,
    staticPoints = true,
  }, {
    achId = "Gadgetzan",
    title = "Exalted with Gadgetzan",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Gadgetzan|r",
    icon = 236688,
    points = 200,
    factionId = 369,
    staticPoints = true,
  }, {
    achId = "ArgentDawn",
    title = "Exalted with Argent Dawn",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Argent Dawn|r",
    icon = 236688,
    points = 150,
    factionId = 529,
    staticPoints = true,
  }, {
    achId = "Timbermaw",
    title = "Exalted with Timbermaw Hold",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Timbermaw Hold|r",
    icon = 236688,
    points = 200,
    factionId = 576,
    staticPoints = true,
  }, {
    achId = "CenarionCircle",
    title = "Exalted with Cenarion Circle",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Cenarion Circle|r",
    icon = 236688,
    points = 150,
    factionId = 609,
    staticPoints = true,
  }, {
    achId = "ThoriumBrotherhood",
    title = "Exalted with Thorium Brotherhood",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Thorium Brotherhood|r",
    icon = 236688,
    points = 150,
    factionId = 59,
    staticPoints = true,
  }, {
    achId = "Hydraxian",
    title = "Exalted with Hydraxian Waterlords",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Hydraxian Waterlords|r",
    icon = 236688,
    points = 150,
    factionId = 749,
    staticPoints = true,
  }, {
    achId = "Zandalar",
    title = "Exalted with Zandalar Tribe",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Zandalar Tribe|r",
    icon = 236688,
    points = 150,
    factionId = 270,
    staticPoints = true,
  }, {
    achId = "Nozdormu",
    title = "Exalted with Brood of Nozdormu",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Brood of Nozdormu|r",
    icon = 236688,
    points = 150,
    factionId = 910,
    staticPoints = true,
  },

  -- NOVELTY
  {
    achId = "Bloodsail",
    title = "Exalted with Bloodsail Buccaneers",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Bloodsail Buccaneers|r",
    icon = 236685,
    points = 200,
    factionId = 87,
    staticPoints = true,
  }, {
    achId = "Wintersaber",
    title = "Exalted with Wintersaber Trainers",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Wintersaber Trainers|r",
    icon = 236685,
    points = 200,
    factionId = 589,
    staticPoints = true,
  },

  -- ROGUE
  {
    achId = "Ravenholdt",
    title = "Exalted with Ravenholdt |cfffff468[Rogue]|r",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ravenholdt|r",
    icon = 236686,
    points = 200,
    factionId = 349,
    staticPoints = true,
    class = "ROGUE",
  },
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all reputation achievements for deferred registration
for _, def in ipairs(Reputations) do
  if _G.ReputationCommon and _G.ReputationCommon.registerReputationAchievement then
    table_insert(_G.HCA_RegistrationQueue, function()
      _G.ReputationCommon.registerReputationAchievement(def)
    end)
  end
end
