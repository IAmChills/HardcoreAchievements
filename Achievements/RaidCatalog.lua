-- Comprehensive raid achievement definitions
local Raids = {
  -- Molten Core (Level 60)
  {
    achId = "MC",
    title = "Molten Core",
    tooltip = "Defeat the bosses of |cff0091e6Molten Core|r",
    icon = 136025,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 409,
    requiredKills = {
      [12118] = 1,  -- Lucifron
      [11982] = 1,  -- Magmadar
      [12259] = 1,  -- Gehennas
      [12057] = 1,  -- Garr
      [12264] = 1,  -- Shazzrah
      [12056] = 1,  -- Baron Geddon
      [11988] = 1,  -- Golemagg the Incinerator
      [12098] = 1,  -- Sulfuron Harbinger
      [12018] = 1,  -- Majordomo Executus
      [11502] = 1,  -- Ragnaros
    },
    bossOrder = {12118, 11982, 12259, 12057, 12264, 12056, 11988, 12098, 12018, 11502}
  },

  -- Onyxia's Lair (Level 60)
  {
    achId = "ONY",
    title = "Onyxia's Lair",
    tooltip = "Defeat |cff0091e6Onyxia|r",
    icon = 132225,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 249,
    requiredKills = {
      [10184] = 1,  -- Onyxia
    },
    bossOrder = {10184}
  },

  -- Blackwing Lair (Level 60)
  {
    achId = "BWL",
    title = "Blackwing Lair",
    tooltip = "Defeat the bosses of |cff0091e6Blackwing Lair|r",
    icon = 136025,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 469,
    requiredKills = {
      [12435] = 1,  -- Razorgore the Untamed
      [13020] = 1,  -- Vaelastrasz the Corrupt
      [12017] = 1,  -- Broodlord Lashlayer
      [11983] = 1,  -- Firemaw
      [14601] = 1,  -- Ebonroc
      [11981] = 1,  -- Flamegor
      [14020] = 1,  -- Chromaggus
      [11583] = 1,  -- Nefarian
    },
    bossOrder = {12435, 13020, 12017, 11983, 14601, 11981, 14020, 11583}
  },

  -- Zul'Gurub (Level 60)
  {
    achId = "ZG",
    title = "Zul'Gurub",
    tooltip = "Defeat the bosses of |cff0091e6Zul'Gurub|r",
    icon = 136025,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 309,
    requiredKills = {
      [14517] = 1,  -- High Priestess Jeklik
      [14507] = 1,  -- High Priest Venoxis
      [14510] = 1,  -- High Priestess Mar'li
      [14509] = 1,  -- High Priest Thekal
      [14515] = 1,  -- High Priestess Arlokk
      [11382] = 1,  -- Bloodlord Mandokir
      [15082] = 1,  -- Gri'lek
      [15083] = 1,  -- Hazza'rah
      [15084] = 1,  -- Renataki
      [15085] = 1,  -- Wushoolay
      [15114] = 1,  -- Gahz'ranka
      [14506] = 1,  -- Lord Kazak
      [11380] = 1,  -- Jin'do the Hexxer
      [14834] = 1,  -- Hakkar
    },
    bossOrder = {14517, 14507, 14510, 14509, 14515, 11382, 15082, 15083, 15084, 15085, 15114, 14506, 11380, 14834}
  },

  -- Ruins of Ahn'Qiraj (Level 60)
  {
    achId = "AQ20",
    title = "Ruins of Ahn'Qiraj",
    tooltip = "Defeat the bosses of |cff0091e6Ruins of Ahn'Qiraj|r",
    icon = 136025,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 509,
    requiredKills = {
      [15348] = 1,  -- Kurinnaxx
      [15341] = 1,  -- General Rajaxx
      [15340] = 1,  -- Moam
      [15370] = 1,  -- Buru the Gorger
      [15369] = 1,  -- Ayamiss the Hunter
      [15339] = 1,  -- Ossirian the Unscarred
    },
    bossOrder = {15348, 15341, 15340, 15370, 15369, 15339}
  },

  -- Temple of Ahn'Qiraj (Level 60)
  {
    achId = "AQ40",
    title = "Temple of Ahn'Qiraj",
    tooltip = "Defeat the bosses of |cff0091e6Temple of Ahn'Qiraj|r",
    icon = 136025,
    points = 50,
    requiredQuestId = nil,
    staticPoints = false,
    requiredMapId = 531,
    requiredKills = {
      [15263] = 1,  -- The Prophet Skeram
      [15511] = 1,  -- Lord Kri
      [15510] = 1,  -- Vem
      [15509] = 1,  -- Princess Yauj
      [15516] = 1,  -- Battleguard Sartura
      [15543] = 1,  -- Princess Huhuran
      [15299] = 1,  -- Viscidus
      [15517] = 1,  -- Ouro
      [15727] = 1,  -- C'Thun
    },
    bossOrder = {15263, 15511, 15510, 15509, 15516, 15543, 15299, 15517, 15727}
  },
}

-- Register all raid achievements
-- Note: RaidCommon must be loaded before this file (RaidCommon.lua should be in .toc before RaidCatalog.lua)
if _G.RaidCommon and _G.RaidCommon.registerRaidAchievement then
  for _, raid in ipairs(Raids) do
    RaidCommon.registerRaidAchievement(raid)
  end
end

