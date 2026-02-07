---------------------------------------
-- Reputation Achievement Definitions
---------------------------------------
-- Each achievement requires reaching Exalted with a specific faction
-- Only factions that the player has discovered will show up in the achievement list
local addonName, addon = ...
local ClassColor = (addon and addon.GetClassColor())
local table_insert = table.insert

local Reputations = {
  
  -- ALLIANCE
  {
    achId = "Stormwind",
    title = "Exalted with Stormwind",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Stormwind|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 72,
    staticPoints = true,
  }, {
    achId = "Darnassus",
    title = "Exalted with Darnassus",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Darnassus|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 69,
    staticPoints = true,
  }, {
    achId = "Ironforge",
    title = "Exalted with Ironforge",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ironforge|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 47,
    staticPoints = true,
  }, {
    achId = "Gnomeregan Exiles",
    title = "Exalted with Gnomeregan Exiles",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Gnomeregan Exiles|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 54,
    staticPoints = true,
  }, {
    achId = "Exodar",
    title = "Exalted with Exodar",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Exodar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 930,
    staticPoints = true,
  }, {
    achId = "Kurenai",
    title = "Exalted with Kurenai",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Kurenai|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 978,
    staticPoints = true,
  }, {
    achId = "Honor Hold",
    title = "Exalted with Honor Hold",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Honor Hold|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 946,
    staticPoints = true,
  },
  
  -- HORDE
  {
    achId = "Orgrimmar",
    title = "Exalted with Orgrimmar",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Orgrimmar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 76,
    staticPoints = true,
  }, {
    achId = "Thunder Bluff",
    title = "Exalted with Thunder Bluff",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Thunder Bluff|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 81,
    staticPoints = true,
  }, {
    achId = "Undercity",
    title = "Exalted with Undercity",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Undercity|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 68,
    staticPoints = true,
  }, {
    achId = "Darkspear Trolls",
    title = "Exalted with Darkspear Trolls",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Darkspear Trolls|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_01.png", -- 236681
    points = 100,
    factionId = 530,
    staticPoints = true,
  }, {
    achId = "Silvermoon City",
    title = "Exalted with Silvermoon City",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Silvermoon City|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 911,
    staticPoints = true,
  }, {
    achId = "Tranquillien",
    title = "Exalted with Tranquillien",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Tranquillien|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 922,
    staticPoints = true,
  }, {
    achId = "Thrallmar",
    title = "Exalted with Thrallmar",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Thrallmar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_03.png", -- 236683
    points = 100,
    factionId = 947,
    staticPoints = true,
  },
  
  -- NEUTRAL
  {
    achId = "BootyBay",
    title = "Exalted with Booty Bay",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Booty Bay|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 21,
    staticPoints = true,
  }, {
    achId = "Ratchet",
    title = "Exalted with Ratchet",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ratchet|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 470,
    staticPoints = true,
  }, {
    achId = "Everlook",
    title = "Exalted with Everlook",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Everlook|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 577,
    staticPoints = true,
  }, {
    achId = "Gadgetzan",
    title = "Exalted with Gadgetzan",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Gadgetzan|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 369,
    staticPoints = true,
  }, {
    achId = "ArgentDawn",
    title = "Exalted with Argent Dawn",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Argent Dawn|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 529,
    staticPoints = true,
  }, {
    achId = "Timbermaw",
    title = "Exalted with Timbermaw Hold",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Timbermaw Hold|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 200,
    factionId = 576,
    staticPoints = true,
  }, {
    achId = "CenarionCircle",
    title = "Exalted with Cenarion Circle",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Cenarion Circle|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 609,
    staticPoints = true,
  }, {
    achId = "ThoriumBrotherhood",
    title = "Exalted with Thorium Brotherhood",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Thorium Brotherhood|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 59,
    staticPoints = true,
  }, {
    achId = "Hydraxian",
    title = "Exalted with Hydraxian Waterlords",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Hydraxian Waterlords|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 749,
    staticPoints = true,
  }, {
    achId = "Zandalar",
    title = "Exalted with Zandalar Tribe",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Zandalar Tribe|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 270,
    staticPoints = true,
  }, {
    achId = "Nozdormu",
    title = "Exalted with Brood of Nozdormu",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Brood of Nozdormu|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 910,
    staticPoints = true,
  }, {
    achId = "Ashtongue Deathsworn",
    title = "Exalted with Ashtongue Deathsworn",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ashtongue Deathsworn|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1012,
    staticPoints = true,
  }, {
    achId = "Scale of the Sands",
    title = "Exalted with Scale of the Sands",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Scale of the Sands|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 990,
    staticPoints = true,
  }, {
    achId = "The Violet Eye",
    title = "Exalted with The Violet Eye",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "The Violet Eye|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 967,
    staticPoints = true,
  }, {
    achId = "Shattered Sun Offensive",
    title = "Exalted with Shattered Sun Offensive",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Shattered Sun Offensive|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1077,
    staticPoints = true,
  }, {
    achId = "Sha'tari Skyguard",
    title = "Exalted with Sha'tari Skyguard",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Sha'tari Skyguard|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1031,
    staticPoints = true,
  }, {
    achId = "The Mag'har",
    title = "Exalted with The Mag'har",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "The Mag'har|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 941,
    staticPoints = true,
  }, {
    achId = "Sporeggar",
    title = "Exalted with Sporeggar",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Sporeggar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 970,
    staticPoints = true,
  }, {
    achId = "Ogri'la",
    title = "Exalted with Ogri'la",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ogri'la|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1038,
    staticPoints = true,
  }, {
    achId = "Netherwing",
    title = "Exalted with Netherwing",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Netherwing|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1015,
    staticPoints = true,
  }, {
    achId = "The Consortium",
    title = "Exalted with The Consortium",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "The Consortium|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 933,
    staticPoints = true,
  }, {
    achId = "Keepers of Time",
    title = "Exalted with Keepers of Time",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Keepers of Time|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 989,
    staticPoints = true,
  }, {
    achId = "Lower City",
    title = "Exalted with Lower City",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Lower City|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 1011,
    staticPoints = true,
  }, {
    achId = "Cenarion Expedition",
    title = "Exalted with Cenarion Expedition",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Cenarion Expedition|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 942,
    staticPoints = true,
  }, {
    achId = "The Sha'tar",
    title = "Exalted with The Sha'tar",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "The Sha'tar|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 935,
    staticPoints = true,
  }, {
    achId = "The Aldor",
    title = "Exalted with The Aldor",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "The Aldor|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 932,
    staticPoints = true,
  }, {
    achId = "The Scryers",
    title = "Exalted with The Scryers",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "The Scryers|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_08.png", -- 236688
    points = 150,
    factionId = 934,
    staticPoints = true,
  },

  -- NOVELTY
  {
    achId = "Bloodsail",
    title = "Exalted with Bloodsail Buccaneers",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Bloodsail Buccaneers|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_05.png", -- 236685
    points = 200,
    factionId = 87,
    staticPoints = true,
  }, {
    achId = "Wintersaber",
    title = "Exalted with Wintersaber Trainers",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Wintersaber Trainers|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_05.png", -- 236685
    points = 200,
    factionId = 589,
    staticPoints = true,
  },

  -- ROGUE
  {
    achId = "Ravenholdt",
    title = "Exalted with Ravenholdt |cfffff468[Rogue]|r",
    tooltip = "Reach Exalted reputation with " .. ClassColor .. "Ravenholdt|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\Achievement_reputation_06.png", -- 236686
    points = 200,
    factionId = 349,
    staticPoints = true,
    class = "ROGUE",
  },
}

---------------------------------------
-- Deferred Registration Queue
---------------------------------------

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
