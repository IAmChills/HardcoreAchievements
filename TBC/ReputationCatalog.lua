-- Reputation achievement definitions
-- Each achievement requires reaching Exalted with a specific faction
-- Only factions that the player has discovered will show up in the achievement list
local Reputations = {
  
  -- ALLIANCE
  {
    achId = "Stormwind",
    title = "Exalted with Stormwind",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Stormwind|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 72,
    staticPoints = true,
  }, {
    achId = "Darnassus",
    title = "Exalted with Darnassus",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Darnassus|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 69,
    staticPoints = true,
  }, {
    achId = "Ironforge",
    title = "Exalted with Ironforge",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ironforge|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 47,
    staticPoints = true,
  }, {
    achId = "Gnomeregan Exiles",
    title = "Exalted with Gnomeregan Exiles",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Gnomeregan Exiles|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 54,
    staticPoints = true,
  }, {
    achId = "Exodar",
    title = "Exalted with Exodar",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Exodar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 930,
    staticPoints = true,
  }, {
    achId = "Kurenai",
    title = "Exalted with Kurenai",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Kurenai|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 978,
    staticPoints = true,
  }, {
    achId = "Honor Hold",
    title = "Exalted with Honor Hold",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Honor Hold|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 946,
    staticPoints = true,
  },
  
  -- HORDE
  {
    achId = "Orgrimmar",
    title = "Exalted with Orgrimmar",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Orgrimmar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 76,
    staticPoints = true,
  }, {
    achId = "Thunder Bluff",
    title = "Exalted with Thunder Bluff",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Thunder Bluff|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 81,
    staticPoints = true,
  }, {
    achId = "Undercity",
    title = "Exalted with Undercity",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Undercity|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 68,
    staticPoints = true,
  }, {
    achId = "Darkspear Trolls",
    title = "Exalted with Darkspear Trolls",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Darkspear Trolls|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 530,
    staticPoints = true,
  }, {
    achId = "Silvermoon City",
    title = "Exalted with Silvermoon City",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Silvermoon City|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 911,
    staticPoints = true,
  }, {
    achId = "Tranquillien",
    title = "Exalted with Tranquillien",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Tranquillien|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 922,
    staticPoints = true,
  }, {
    achId = "Thrallmar",
    title = "Exalted with Thrallmar",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Thrallmar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 947,
    staticPoints = true,
  },
  
  -- NEUTRAL
  {
    achId = "BootyBay",
    title = "Exalted with Booty Bay",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Booty Bay|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 21,
    staticPoints = true,
  }, {
    achId = "Ratchet",
    title = "Exalted with Ratchet",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ratchet|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 470,
    staticPoints = true,
  }, {
    achId = "Everlook",
    title = "Exalted with Everlook",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Everlook|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 577,
    staticPoints = true,
  }, {
    achId = "Gadgetzan",
    title = "Exalted with Gadgetzan",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Gadgetzan|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 369,
    staticPoints = true,
  }, {
    achId = "ArgentDawn",
    title = "Exalted with Argent Dawn",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Argent Dawn|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 529,
    staticPoints = true,
  }, {
    achId = "Timbermaw",
    title = "Exalted with Timbermaw Hold",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Timbermaw Hold|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 576,
    staticPoints = true,
  }, {
    achId = "CenarionCircle",
    title = "Exalted with Cenarion Circle",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Cenarion Circle|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 609,
    staticPoints = true,
  }, {
    achId = "ThoriumBrotherhood",
    title = "Exalted with Thorium Brotherhood",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Thorium Brotherhood|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 59,
    staticPoints = true,
  }, {
    achId = "Hydraxian",
    title = "Exalted with Hydraxian Waterlords",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Hydraxian Waterlords|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 749,
    staticPoints = true,
  }, {
    achId = "Zandalar",
    title = "Exalted with Zandalar Tribe",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Zandalar Tribe|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 270,
    staticPoints = true,
  }, {
    achId = "Nozdormu",
    title = "Exalted with Brood of Nozdormu",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Brood of Nozdormu|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 910,
    staticPoints = true,
  }, {
    achId = "Ashtongue Deathsworn",
    title = "Exalted with Ashtongue Deathsworn",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ashtongue Deathsworn|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1012,
    staticPoints = true,
  }, {
    achId = "Scale of the Sands",
    title = "Exalted with Scale of the Sands",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Scale of the Sands|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 990,
    staticPoints = true,
  }, {
    achId = "The Violet Eye",
    title = "Exalted with The Violet Eye",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "The Violet Eye|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 967,
    staticPoints = true,
  }, {
    achId = "Shattered Sun Offensive",
    title = "Exalted with Shattered Sun Offensive",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Shattered Sun Offensive|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1077,
    staticPoints = true,
  }, {
    achId = "Sha'tari Skyguard",
    title = "Exalted with Sha'tari Skyguard",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Sha'tari Skyguard|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1031,
    staticPoints = true,
  }, {
    achId = "The Mag'har",
    title = "Exalted with The Mag'har",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "The Mag'har|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 941,
    staticPoints = true,
  }, {
    achId = "Sporeggar",
    title = "Exalted with Sporeggar",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Sporeggar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 970,
    staticPoints = true,
  }, {
    achId = "Ogri'la",
    title = "Exalted with Ogri'la",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ogri'la|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1038,
    staticPoints = true,
  }, {
    achId = "Netherwing",
    title = "Exalted with Netherwing",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Netherwing|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1015,
    staticPoints = true,
  }, {
    achId = "The Consortium",
    title = "Exalted with The Consortium",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "The Consortium|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 933,
    staticPoints = true,
  }, {
    achId = "Keepers of Time",
    title = "Exalted with Keepers of Time",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Keepers of Time|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 989,
    staticPoints = true,
  }, {
    achId = "Lower City",
    title = "Exalted with Lower City",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Lower City|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1011,
    staticPoints = true,
  }, {
    achId = "Cenarion Expedition",
    title = "Exalted with Cenarion Expedition",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Cenarion Expedition|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 942,
    staticPoints = true,
  }, {
    achId = "The Sha'tar",
    title = "Exalted with The Sha'tar",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "The Sha'tar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 935,
    staticPoints = true,
  }, {
    achId = "The Aldor",
    title = "Exalted with The Aldor",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "The Aldor|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 932,
    staticPoints = true,
  }, {
    achId = "The Scryers",
    title = "Exalted with The Scryers",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "The Scryers|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 934,
    staticPoints = true,
  },

  -- NOVELTY
  {
    achId = "Bloodsail",
    title = "Exalted with Bloodsail Buccaneers",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Bloodsail Buccaneers|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_05.png", -- 236685
    points = 200,
    factionId = 87,
    staticPoints = true,
  }, {
    achId = "Wintersaber",
    title = "Exalted with Wintersaber Trainers",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Wintersaber Trainers|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_05.png", -- 236685
    points = 200,
    factionId = 589,
    staticPoints = true,
  },

  -- ROGUE
  {
    achId = "Ravenholdt",
    title = "Exalted with Ravenholdt |cfffff468[Rogue]|r",
    tooltip = "Reach Exalted reputation with " .. HCA_SharedUtils.GetClassColor() .. "Ravenholdt|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_06.png", -- 236686
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
    table.insert(_G.HCA_RegistrationQueue, function()
      _G.ReputationCommon.registerReputationAchievement(def)
    end)
  end
end
