local addonName, addon = ...

-- =========================================================
-- Rare / side-boss credit from distinctive loot (Forever)
--
-- Fallback when GetLootSourceInfo() is unavailable (another player looted, no loot
-- window, secret GUID path failed). ENCOUNTER_END and LootKills GUID credit remain
-- preferred. This only reacts to live loot/roll events — never scans bags.
--
-- When an item could come from more than one NPC, mapId disambiguates (instance map check).
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local IsSecret = addon.IsSecretValue

-- NPC id -> distinctive item ids for tracked bosses with NO ENCOUNTER_ID_TO_NPC entry.
-- mapId is the dungeon instance map (GetInstanceInfo select 8). nil = Forever map not
-- filled yet: allow any party/raid instance when the item uniquely identifies the NPC.
--
-- Audited against Forever/DungeonCatalog + Forever/EncounterKills. Do not list NPCs that
-- already have an encounter id (credit comes from ENCOUNTER_END).
-- Commented-out catalog NPCs (not tracked): Baron Aquanis, Ezra Grimm, Strat hammersmiths
-- Placeholders with empty items = wait for a distinctive drop before loot-credit works.
local RARE_LOOT = {
    -- Wailing Caverns
    [5912] = { -- Deviate Faerie Dragon
        mapId = 43,
        items = { 6632, 5243 }, -- Feyscale Cloak, Firebelcher
    },

    -- Shadowfang Keep
    [3872] = { -- Deathsworn Captain
        mapId = 33,
        items = { 6641, 6642 }, -- Haunting Blade, Phantom Armor
    },

    -- The Stockade
    [1720] = { -- Bruegal Ironknuckle
        mapId = 34,
        items = { 2941, 2942, 3228 }, -- Prison Shank, Iron Knuckles, Jimmied Handcuffs
    },

    -- Gnomeregan
    [6228] = { -- Dark Iron Ambassador
        mapId = 90,
        items = { 9455, 9456, 9457 }, -- Emissary Cuffs, Glass Shooter, Royal Diplomatic Scepter
    },

    -- Scarlet Monastery
    [6490] = { -- Azshir the Sleepless
        mapId = 189,
        items = { 7731, 7709, 7708 }, -- Ghostshard Talisman, Blighted Leggings, Necrotic Wand
    },
    [6488] = { -- Fallen Champion
        mapId = 189,
        items = { 7690, 7689, 7691 }, -- Ebon Vise, Morbid Dawn, Embalmed Shroud
    },
    [6489] = { -- Ironspine
        mapId = 189,
        items = { 7687, 7688, 7686 }, -- Ironspine's Fist, Ironspine's Ribcage, Ironspine's Eye
    },

    -- Razorfen Downs
    [7354] = { -- Ragglesnout
        mapId = 129,
        items = { 10768, 10758, 10767, 251401 }, -- Boar Champion's Belt, X'caliboar, Savage Boar's Guard, Plans: Prefect's Boots
    },
    [7356] = { -- Plaguemaw the Rotting
        mapId = 129,
        items = { 10760, 10766, 274380 }, -- Swine Fists, Plaguerot Sprig, Decaying Flesh Bands
    },

    -- Zul'Farrak
    [7604] = { -- Sergeant Bly (no wiki encounter; Divino-matic Rod is the reliable signal)
        mapId = 209,
        items = { 8548, 274646, 274647, 274648 }, -- Divino-matic Rod, Arch of the Covenant, Farraki Kris, The Desert Rose
    },
    [7797] = { -- Ruuzlu
        mapId = 209,
        items = { 274654, 9479, 274655 }, -- Sandfury Guillotine, Embrace of the Lycan, Peacekeeper Wand
    },
    [10081] = { -- Dustwraith
        mapId = 209,
        items = { 12471, 12469 }, -- Desertwalker Cane, Mutilator
    },
    [10082] = { -- Zerillis
        mapId = 209,
        items = { 12470, 274658 }, -- Sandstalker Ankleguards, Dune Hacker
    },
    [10080] = { -- Sandarr Dunereaver
        mapId = 209,
        items = { 274659, 274660 }, -- Bloodsand Belt, Sandarr's Shoulders
    },

    -- Temple of Atal'Hakkar
    [8580] = { -- Atal'alarion
        mapId = 109,
        items = { 10798, 10799, 10800 }, -- Atal'alarion's Tusk Ring, Headspike, Darkwater Bracers
    },
    [5711] = { -- Ogom the Wretched
        mapId = 109,
        items = { 10803, 10804, 10805 }, -- Blade of the Wretched, Fist of the Damned, Eater of the Dead
    },

    -- Blackrock Depths
    -- 10076 (High Priestess of Thaurissan) is the same kill; CanonicalNpcId maps it to 8929.
    [8929] = { -- Princess Moira Bronzebeard / High Priestess of Thaurissan
        mapId = 230,
        items = { 12557, 12554, 12556, 12553 }, -- Ebonsteel Spaulders, Hands of the Exalted Herald, High Priestess Boots, Swiftwalker Boots
    },

    -- Upper Blackrock Spire (instance map shared with LBRS; Jed is UBRS-only tracked)
    [10509] = { -- Jed Runewatcher
        mapId = 229,
        items = { 12930, 12605, 12604 }, -- Briarwood Reed, Serpentine Skuller, Starfire Tiara
    },

    -- Stratholme
    [10393] = { -- Skul
        mapId = 329,
        items = { 13394, 13395, 13396 }, -- Skul's Cold Embrace, Fingerbone Claws, Ghastly Touch
    },
    [10809] = { -- Stonespine
        mapId = 329,
        items = { 13397, 13399, 13954 }, -- Stoneskin Gargoyle Cape, Gargoyle Shredder Talons, Verdant Footpads
    },

    -- Dire Maul
    [14354] = { -- Pusillin
        mapId = 429,
        items = { 18249, 18267, 18320, 18316 }, -- Crescent Key, Recipe: Runn Tum Tuber Surprise, Demondash Spaulders, Obsidian Bauble
    },
    [11467] = { -- Tsu'zee
        mapId = 429,
        items = { 18345, 18346, 18387 }, -- Murmuring Ring, Threadbare Trousers, Brightspark Gloves
    },

    -- Krol'dok Stronghold (mapId pending)
    [264773] = { -- Bossman Toof
        mapId = nil,
        items = { 286430, 286428, 286429 }, -- Toofbreaker, Band of Bossman, Big-Belly Belt
    },

    -- The Drowned City (mapId pending Forever catalog)
    [264177] = { -- Gill
        mapId = nil,
        items = { 286646, 286649, 271718 }, -- Gill's Gills, Tidebound Dagger, Linken's Boots of Iron
    },
    [264172] = { -- Umbra
        mapId = nil,
        items = { 286662, 286658 }, -- Deep-Dweller's Grips, Umbral Scaled Belt
    },
    [260468] = { -- "Pyromancer" Braxton
        mapId = nil,
        items = { 286651, 286650 }, -- Flamestarter's Signet, Pyromancer's Baton
    },

    -- Blackmaw Hold (mapId pending)
    [269104] = { -- Moontouched Wanderer
        mapId = nil,
        items = { 280080, 280079 }, -- Claymore of Two Moons, Lunarlight Robe
    },
    [269111] = { -- Gortek the Apprentice
        mapId = nil,
        items = { 280077, 280078 }, -- Fist of Revelation, Apprentice's Protective Treads
    },

    -- Shaper's Terrace (mapId pending)
    [261993] = { -- King Op (placeholder: no distinctive drop data yet)
        mapId = nil,
        items = {},
    },
}

-- itemId -> { { npcId=, mapId= }, ... }
local ITEM_TO_NPC = {}
do
    for npcId, entry in pairs(RARE_LOOT) do
        local items = entry and entry.items
        if type(items) == "table" then
            local mapId = tonumber(entry.mapId)
            if mapId == 0 then
                mapId = nil
            end
            for _, itemId in ipairs(items) do
                itemId = tonumber(itemId)
                if itemId then
                    local list = ITEM_TO_NPC[itemId]
                    if not list then
                        list = {}
                        ITEM_TO_NPC[itemId] = list
                    end
                    list[#list + 1] = { npcId = npcId, mapId = mapId }
                end
            end
        end
    end
end

local function KillLog(message)
    if not addon.ForeverKillDebug then
        return
    end
    if IsSecret(message) then
        return
    end
    print("|cff008066[HCA Kills]|r " .. message)
    if addon.EventLogAdd then
        addon.EventLogAdd("[Kills] " .. message)
    end
end

local function IsInsideGroupInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "party" or instanceType == "raid"
end

local function CurrentInstanceMapID()
    return tonumber(select(8, GetInstanceInfo()))
end

local function ParseItemIdFromLink(link)
    if type(link) ~= "string" or IsSecret(link) then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

--- Resolve item -> npc for the current instance. Shared drops require a map match.
local function ResolveNpcForItem(itemId)
    itemId = tonumber(itemId)
    if not itemId then
        return nil
    end
    local candidates = ITEM_TO_NPC[itemId]
    if not candidates or #candidates == 0 then
        return nil
    end

    local mapId = CurrentInstanceMapID()
    local matched = {}
    for _, cand in ipairs(candidates) do
        if cand.mapId then
            if mapId and mapId == cand.mapId then
                matched[#matched + 1] = cand.npcId
            end
        else
            -- No catalog map yet: only accept if this item does not also require a map elsewhere,
            -- or if it is the sole candidate.
            matched[#matched + 1] = cand.npcId
        end
    end

    if #matched == 0 then
        return nil
    end

    -- Shared-drop safety: more than one NPC still matched (should not happen if maps differ).
    if #matched > 1 then
        KillLog("RARE_LOOT item " .. tostring(itemId) .. " ambiguous on map " .. tostring(mapId))
        return nil
    end

    return matched[1]
end

local function TryAwardFromItem(itemId, source)
    if not IsInsideGroupInstance() then
        return
    end

    local npcId = ResolveNpcForItem(itemId)
    if not npcId then
        return
    end

    if not (addon.IsNpcTrackedForAchievement and addon.IsNpcTrackedForAchievement(npcId)) then
        KillLog(source .. " item " .. tostring(itemId) .. " npc " .. tostring(npcId) .. " not tracked")
        return
    end

    KillLog(source .. " item=" .. tostring(itemId) .. " -> npc=" .. tostring(npcId)
        .. " map=" .. tostring(CurrentInstanceMapID()))

    -- No Creature GUID from this path; encounter entry still runs dungeon eligibility + sync.
    if not addon.AwardKillFromEncounter then
        KillLog(source .. " AwardKillFromEncounter missing")
        return
    end

    KillLog(source .. " awarding npc " .. tostring(npcId))
    addon.AwardKillFromEncounter(nil, npcId)
end

local tracker = CreateFrame("Frame")
pcall(tracker.RegisterEvent, tracker, "START_LOOT_ROLL")
pcall(tracker.RegisterEvent, tracker, "CHAT_MSG_LOOT")

tracker:SetScript("OnEvent", function(_, event, ...)
    if event == "START_LOOT_ROLL" then
        local rollID = ...
        if not rollID or not GetLootRollItemLink then
            return
        end
        local ok, link = pcall(GetLootRollItemLink, rollID)
        if not ok then
            return
        end
        local itemId = ParseItemIdFromLink(link)
        if itemId then
            TryAwardFromItem(itemId, "RARE_LOOT ROLL")
        end
        return
    end

    if event == "CHAT_MSG_LOOT" then
        -- Any group member receiving a distinctive drop is enough; Master Loot / FFA
        -- often have no START_LOOT_ROLL. NPC/map gates still apply; achievement layer dedupes.
        local msg = ...
        if IsSecret(msg) then
            return
        end
        if type(msg) ~= "string" then
            return
        end
        local itemId = tonumber(msg:match("|Hitem:(%d+)"))
        if itemId then
            TryAwardFromItem(itemId, "RARE_LOOT CHAT")
        end
    end
end)
