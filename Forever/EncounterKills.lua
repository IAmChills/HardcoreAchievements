local addonName, addon = ...

-- =========================================================
-- Dungeon boss credit from ENCOUNTER_END (Forever)
--
-- Inside instances creature GUIDs are secret, so PARTY_KILL / UNIT_DIED cannot name the boss.
-- Live Forever probes show ENCOUNTER_END fires with plain encounterID, encounterName, and success=1,
-- but encounterUnitStatus is an empty table (Retail's creatureID/health list is not populated here).
--
-- Credit order:
--   1. encounterUnitStatus creatureIDs at 0% health (if Forever ever fills the table)
--   2. known DungeonEncounterID -> NPC id map (filled from killdebug)
--   3. encounterName / BOSS_KILL name -> GetBossName reverse index
--
-- Eligibility stays in the dungeon kill tracker (level, party size, entry snapshot).
-- Raid rows have no kill tracker; they continue to complete from BOSS_KILL.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local IsSecret = addon.IsSecretValue
local loggedMissingPayload = false
local nameToNpcId = nil

-- DungeonEncounterID -> NPC id (or list of NPC ids).
-- Classic IDs from the DungeonEncounterID wiki list for shared classic dungeons.
-- Forever-original dungeons (ROL/HOT/etc.) come from live /hca killdebug.
-- Values may be a number or { npcId, ... } when one encounter credits multiple tracked bosses.
local ENCOUNTER_ID_TO_NPC = {
    -- Forever: Ruins of Lordaeron (live)
    [3353] = 250483, -- Witherfang
    [3411] = 256035, -- Viktor the Vile
    [3357] = 250631, -- The Abandoned
    [3412] = 256097, -- Bjork
    [3354] = 250657, -- Rath'mael
    [3355] = 250660, -- The Baron (encounter name "The Butcher")
    -- Lordaeron Captain (255699) — need live killdebug

    -- Ragefire Chasm
    [430] = 11517, -- Oggleflint
    [431] = 11520, -- Taragaman the Hungerer
    [432] = 11518, -- Jergosh the Invoker
    [433] = 11519, -- Bazzalan

    -- Deadmines (Cookie 165 not tracked)
    [161] = 644,   -- Rhahk'Zor
    [162] = 643,   -- Sneed / Sneed's Shredder
    [163] = 1763,  -- Gilnid
    [164] = 646,   -- Mr. Smite
    [166] = 647,   -- Captain Greenskin
    [167] = 639,   -- Edwin VanCleef

    -- Wailing Caverns (Deviate Faerie Dragon rare has no encounter)
    [585] = 3671, -- Lady Anacondra
    [586] = 3669, -- Lord Cobrahn
    [587] = 3653, -- Kresh
    [588] = 3670, -- Lord Pythas
    [589] = 3674, -- Skum
    [590] = 3673, -- Lord Serpentis
    [591] = 5775, -- Verdan the Everliving
    [592] = 3654, -- Mutanus the Devourer

    -- Shadowfang Keep (Deathsworn Captain rare has no encounter)
    [464] = 3914, -- Rethilgore
    [465] = 3886, -- Razorclaw the Butcher
    [466] = 3887, -- Baron Silverlaine
    [467] = 4278, -- Commander Springvale
    [468] = 4279, -- Odo the Blindwatcher
    [469] = 4274, -- Fenrus the Devourer
    [470] = 3927, -- Wolf Master Nandos
    [471] = 4275, -- Archmage Arugal

    -- Blackfathom Deeps
    [219] = 4887,  -- Ghamoo-ra
    [220] = 4831,  -- Lady Sarevess
    [221] = 6243,  -- Gelihast
    [222] = 12902, -- Lorgus Jett
    [224] = 4830,  -- Old Serra'kis
    [225] = 4832,  -- Twilight Lord Kelris
    [226] = 4829,  -- Aku'mai

    -- Razorfen Kraul
    [438] = 6168, -- Roogug
    [439] = 4424, -- Aggem Thorncurse
    [440] = 4428, -- Death Speaker Jargba
    [441] = 4420, -- Overlord Ramtusk
    [883] = 4422, -- Agathelos the Raging
    [443] = 4421, -- Charlga Razorflank

    -- Gnomeregan (Dark Iron Ambassador rare has no encounter)
    [378] = 7079, -- Viscous Fallout
    [379] = 7361, -- Grubbis
    [380] = 6235, -- Electrocutioner 6000
    [381] = 6229, -- Crowd Pummeler 9-60
    [382] = 7800, -- Mekgineer Thermaplugg

    -- Scarlet Monastery (rares have no encounter; Whitemane fight includes Mograine)
    [444] = 3983, -- Interrogator Vishas
    [445] = 4543, -- Bloodmage Thalnos
    [446] = 3974, -- Houndmaster Loksey
    [447] = 6487, -- Arcanist Doan
    [448] = 3975, -- Herod
    [449] = 4542, -- High Inquisitor Fairbanks
    [450] = {3976, 3977}, -- Scarlet Commander Mograine + High Inquisitor Whitemane

    -- Razorfen Downs (Ragglesnout / Plaguemaw have no encounter)
    [434] = 7355, -- Tuten'kash
    [435] = 7357, -- Mordresh Fire Eye
    [436] = 8567, -- Glutton
    [437] = 7358, -- Amnennar the Coldbringer

    -- Uldaman
    [547] = 6910, -- Revelosh
    [548] = {6906, 6907, 6908}, -- The Lost Dwarves (extra credit; any one)
    [549] = 7228, -- Ironaya
    [1887] = 7023, -- Obsidian Sentinel
    [551] = 7206, -- Ancient Stone Keeper
    [552] = 7291, -- Galgann Firehammer
    [553] = 4854, -- Grimlok
    [554] = 2748, -- Archaedas

    -- Zul'Farrak (Sergeant Bly / Ruuzlu / rares: no classic wiki encounter — name fallback)
    [593] = 7795, -- Hydromancer Velratha
    [594] = 7273, -- Gahz'rilla (extra credit)
    [595] = 8127, -- Antu'sul
    [596] = 7272, -- Theka the Martyr
    [597] = 7271, -- Witch Doctor Zum'rah
    [598] = 7796, -- Nekrum Gutchewer
    [599] = 7275, -- Shadowpriest Sezz'ziz
    [600] = 7267, -- Chief Ukorz Sandscalp

    -- Maraudon
    [422] = 13282, -- Noxxion
    [423] = 12258, -- Razorlash
    [424] = 12236, -- Lord Vyletongue
    [425] = 12225, -- Celebras the Cursed
    [426] = 12203, -- Landslide
    [427] = 13601, -- Tinkerer Gizlock
    [428] = 13596, -- Rotgrip
    [429] = 12201, -- Princess Theradras

    -- Temple of Atal'Hakkar (Atal'alarion / Ogom: no classic wiki encounter — name fallback)
    [486] = 5721, -- Dreamscythe
    [487] = 5720, -- Weaver
    [488] = 5710, -- Jammal'an the Prophet
    [490] = 5719, -- Morphaz
    [491] = 5722, -- Hazzas
    [492] = 8443, -- Avatar of Hakkar
    [493] = 5709, -- Shade of Eranikus

    -- Blackrock Depths
    [227] = 9018, -- High Interrogator Gerstahn
    [228] = 9025, -- Lord Roccor
    [229] = 9319, -- Houndmaster Grebmar
    [230] = {9027, 9028, 9029, 9030, 9031, 9032}, -- Ring of Law (any one)
    [231] = 9024, -- Pyromancer Loregrain
    [232] = 9017, -- Lord Incendius
    [233] = 9041, -- Warder Stilgiss
    [234] = 9056, -- Fineous Darkvire
    [235] = 9016, -- Bael'Gar
    [236] = 9033, -- General Angerforge
    [237] = 8983, -- Golem Lord Argelmach
    [238] = 9537, -- Hurley Blackbreath
    [239] = 9502, -- Phalanx
    [240] = 9543, -- Ribbly Screwspigot
    [241] = 9499, -- Plugger Spazzring
    [242] = 9156, -- Ambassador Flamelash
    [243] = {9034, 9035, 9036, 9037, 9038, 9039, 9040}, -- The Seven (any one of the seven) Hate'rel, Anger'rel, Vile'rel, Gloom'rel, Seeth'rel, Doom'rel, Dope'rel
    [244] = 9938, -- Magmus
    -- Emperor + Moira share encounter 245. Map Emperor only: a table {9019, 8929} would
    -- also award Moira extra credit when she is spared (quest). Moira still gets name fallback
    -- if a separate BOSS_KILL/ENCOUNTER_END name fires for her; verify with killdebug.
    [245] = 9019, -- Emperor Dagran Thaurissan (Moira 8929 intentionally not tied to this id)

    -- Lower Blackrock Spire
    [267] = 9196,  -- Highlord Omokk
    [268] = 9236,  -- Shadow Hunter Vosh'gajin
    [269] = 9237,  -- War Master Voone
    [270] = 10596, -- Mother Smolderweb
    [271] = 10584, -- Urok Doomhowl (extra credit)
    [272] = 9736,  -- Quartermaster Zigris
    [273] = 10268, -- Gizrul the Slavener
    [274] = 10220, -- Halycon
    [275] = 9568,  -- Overlord Wyrmthalak

    -- Upper Blackrock Spire (Gyth 10339 no longer tracked; Jed 10509 has no wiki encounter)
    [276] = 9816, -- Pyroguard Emberseer
    [278] = 10429, -- Warchief Rend Blackhand
    [279] = 10430, -- The Beast
    [280] = 10363, -- General Drakkisath

    -- Stratholme (wiki names differ slightly; NPC ids are the tracked ones)
    [472] = 10516, -- The Unforgiven
    [473] = 10558, -- Hearthsinger Forresten (extra credit)
    [474] = 10808, -- Timmy the Cruel
    [475] = 10997, -- Cannon Master Willey / Willey Hopebreaker
    [476] = 11032, -- Malor the Zealous / Commander Malor
    [477] = 10811, -- Archivist Galford / Instructor Galford
    [478] = {10812, 10813}, -- Balnazzar / Dathrohan
    [479] = 10436, -- Baroness Anastari
    [480] = 10437, -- Nerub'enkan
    [481] = 10438, -- Maleki the Pallid
    [482] = 10435, -- Magistrate Barthilas
    [483] = 10439, -- Ramstein the Gorger
    [484] = 10440, -- Baron Rivendare / Lord Aurius Rivendare

    -- Dire Maul (Pusillin / Tsu'zee: no classic wiki encounter — name fallback)
    [343] = 11490, -- Zevrim Thornhoof
    [344] = 13280, -- Hydrospawn
    [345] = 14327, -- Lethtendris
    [346] = 11492, -- Alzzin the Wildshaper
    [347] = 11488, -- Illyanna Ravenoak
    [348] = 11487, -- Magister Kalendris
    [349] = 11496, -- Immol'thar
    [350] = 11489, -- Tendris Warpwood
    [361] = 11486, -- Prince Tortheldrin
    [362] = 14326, -- Guard Mol'dar
    [363] = 14322, -- Stomper Kreeg
    [364] = 14321, -- Guard Fengus
    [365] = 14323, -- Guard Slip'kik
    [366] = 14325, -- Captain Kromcrush
    [367] = 14324, -- Cho'Rush the Observer
    [368] = 11501, -- King Gordok

    -- Scholomance
    [451] = 10506, -- Kirtonos the Herald (extra credit)
    [452] = 10503, -- Jandice Barov
    [453] = 11622, -- Rattlegore
    [454] = 10433, -- Marduk Blackpool
    [455] = 10432, -- Vectus
    [456] = 10508, -- Ras Frostwhisper
    [457] = 10505, -- Instructor Malicia
    [458] = 11261, -- Doctor Theolen Krastinov
    [459] = 10901, -- Lorekeeper Polkelt
    [460] = 10507, -- The Ravenian
    [461] = 10504, -- Lord Alexei Barov
    [462] = 10502, -- Lady Illucia Barov
    [463] = 1853,  -- Darkmaster Gandling
}

-- Encounter-name aliases when ENCOUNTER_END name differs from GetBossName (Forever).
-- Used only when encounter id is unknown; id map still preferred.
local ENCOUNTER_NAME_ALIASES = {
    ["the butcher"] = 250660, -- The Baron
}

local function KillLog(message)
    if not addon.ForeverKillDebug then
        return
    end
    print("|cff008066[HCA Kills]|r " .. message)
    if addon.EventLogAdd then
        addon.EventLogAdd("[Kills] " .. message)
    end
end

local function Describe(value)
    if value == nil then
        return "nil"
    end
    if IsSecret(value) then
        return "secret " .. type(value)
    end
    return type(value) .. "=" .. tostring(value)
end

local function RebuildNameIndex()
    nameToNpcId = {}
    local defs = addon.AchievementDefs
    local getBossName = addon.GetBossName
    if type(defs) ~= "table" or type(getBossName) ~= "function" then
        return
    end
    for _, def in pairs(defs) do
        local required = def and def.requiredKills
        if type(required) == "table" then
            for npcId in pairs(required) do
                npcId = tonumber(npcId)
                if npcId then
                    local name = getBossName(npcId)
                    if type(name) == "string" and name ~= "" and not name:match("^Boss ") then
                        nameToNpcId[string.lower(name)] = npcId
                    end
                end
            end
        end
        local extra = def and def.extraCreditKills
        if type(extra) == "table" then
            for npcId in pairs(extra) do
                npcId = tonumber(npcId)
                if npcId then
                    local name = getBossName(npcId)
                    if type(name) == "string" and name ~= "" and not name:match("^Boss ") then
                        nameToNpcId[string.lower(name)] = npcId
                    end
                end
            end
        end
    end
end

local function ResolveNpcIdFromName(name)
    if type(name) ~= "string" or name == "" or IsSecret(name) then
        return nil
    end
    local key = string.lower(name)
    local aliased = ENCOUNTER_NAME_ALIASES[key]
    if aliased then
        return aliased
    end
    if not nameToNpcId then
        RebuildNameIndex()
    end
    return nameToNpcId and nameToNpcId[key] or nil
end

local function TryAwardCreature(creatureID, source)
    creatureID = tonumber(creatureID)
    if not creatureID then
        return false
    end
    if not (addon.IsNpcTrackedForAchievement and addon.IsNpcTrackedForAchievement(creatureID)) then
        KillLog(source .. " creature " .. tostring(creatureID) .. " not tracked")
        return false
    end
    if not addon.AwardKillFromEncounter then
        KillLog(source .. " AwardKillFromEncounter missing")
        return false
    end
    KillLog(source .. " awarding creature " .. tostring(creatureID))
    addon.AwardKillFromEncounter(nil, creatureID)
    return true
end

local function AwardFromUnitStatus(encounterID, encounterUnitStatus)
    local awarded = false
    local seen = 0
    for _, entry in ipairs(encounterUnitStatus) do
        if type(entry) == "table" then
            seen = seen + 1
            local creatureID = entry.creatureID
            local creatureName = entry.creatureName
            local health = entry.remainingHealthPercent
            KillLog("ENCOUNTER_END unit creatureID=" .. Describe(creatureID)
                .. " name=" .. Describe(creatureName)
                .. " health=" .. Describe(health))
            if not IsSecret(creatureID) and not IsSecret(health) then
                creatureID = tonumber(creatureID)
                health = tonumber(health)
                if creatureID and health == 0 then
                    if TryAwardCreature(creatureID, "ENCOUNTER_END encounter " .. tostring(encounterID)) then
                        awarded = true
                    end
                end
            elseif not IsSecret(creatureName) and not IsSecret(health) and tonumber(health) == 0 then
                local npcId = ResolveNpcIdFromName(creatureName)
                if npcId and TryAwardCreature(npcId, "ENCOUNTER_END name " .. tostring(creatureName)) then
                    awarded = true
                end
            end
        end
    end
    if seen == 0 then
        KillLog("ENCOUNTER_END encounterUnitStatus was an empty table")
    end
    return awarded
end

local function AwardFromEncounterName(encounterName, source)
    local npcId = ResolveNpcIdFromName(encounterName)
    if not npcId then
        KillLog(source .. " no npc mapping for name=" .. Describe(encounterName))
        return false
    end
    return TryAwardCreature(npcId, source .. " name=" .. tostring(encounterName))
end

local function AwardFromEncounterID(encounterID, source)
    if IsSecret(encounterID) then
        return false
    end
    local mapped = ENCOUNTER_ID_TO_NPC[tonumber(encounterID)]
    if not mapped then
        KillLog(source .. " no npc mapping for encounter id=" .. Describe(encounterID))
        return false
    end
    local awarded = false
    if type(mapped) == "table" then
        for _, npcId in ipairs(mapped) do
            if TryAwardCreature(npcId, source .. " id=" .. tostring(encounterID)) then
                awarded = true
            end
        end
        return awarded
    end
    return TryAwardCreature(mapped, source .. " id=" .. tostring(encounterID))
end

local function IsKillSuccess(success)
    if IsSecret(success) then
        return nil
    end
    return success == 1 or success == true
end

local tracker = CreateFrame("Frame")
local registeredEnd = pcall(tracker.RegisterEvent, tracker, "ENCOUNTER_END")
local registeredBoss = pcall(tracker.RegisterEvent, tracker, "BOSS_KILL")
addon.Restrictions.encounterEndEvent = registeredEnd and true or false

tracker:SetScript("OnEvent", function(_, event, ...)
    if event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        KillLog("BOSS_KILL id=" .. Describe(encounterID) .. " name=" .. Describe(encounterName))
        -- Raid rows still use their own BOSS_KILL handler. This is a Forever dungeon fallback when
        -- ENCOUNTER_END did not identify a creature.
        if AwardFromEncounterID(encounterID, "BOSS_KILL") then
            return
        end
        AwardFromEncounterName(encounterName, "BOSS_KILL")
        return
    end

    if event ~= "ENCOUNTER_END" then
        return
    end

    local encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus = ...
    KillLog("ENCOUNTER_END id=" .. Describe(encounterID)
        .. " name=" .. Describe(encounterName)
        .. " difficulty=" .. Describe(difficultyID)
        .. " size=" .. Describe(groupSize)
        .. " success=" .. Describe(success)
        .. " status=" .. (encounterUnitStatus == nil and "nil"
            or (issecrettable and issecrettable(encounterUnitStatus) and "secret-table"
                or type(encounterUnitStatus))))

    local killSuccess = IsKillSuccess(success)
    if killSuccess == false then
        KillLog("ENCOUNTER_END ignored: wipe/failure")
        return
    end

    -- Type check before canaccesstable: canaccesstable(nil) is false and used to silent-return
    -- before the missing-payload path could log or fall back to encounterName.
    if type(encounterUnitStatus) == "table" then
        if issecrettable and issecrettable(encounterUnitStatus) then
            KillLog("ENCOUNTER_END encounterUnitStatus is a secret table")
        elseif canaccesstable and not canaccesstable(encounterUnitStatus) then
            KillLog("ENCOUNTER_END encounterUnitStatus is inaccessible")
        else
            if AwardFromUnitStatus(encounterID, encounterUnitStatus) then
                return
            end
        end
    else
        if not loggedMissingPayload then
            loggedMissingPayload = true
            local message = "ENCOUNTER_END has no usable encounterUnitStatus; using encounter id/name fallback"
            KillLog(message)
            if addon.EventLogAdd then
                addon.EventLogAdd("[Kills] " .. message)
            end
        else
            KillLog("ENCOUNTER_END has no usable encounterUnitStatus")
        end
    end

    if killSuccess == true or killSuccess == nil then
        if AwardFromEncounterID(encounterID, "ENCOUNTER_END") then
            return
        end
        AwardFromEncounterName(encounterName, "ENCOUNTER_END")
    end
end)

-- BOSS_KILL registration failure is non-fatal; ENCOUNTER_END remains the primary path.
if not registeredBoss then
    KillLog("BOSS_KILL could not be registered")
end
