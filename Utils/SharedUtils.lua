local addonName, addon = ...
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local GetClassColor = GetClassColor
local CreateFrame = CreateFrame

-- =========================================================
-- Settings Helpers
-- =========================================================

-- Get a setting value from character database
local function GetSetting(settingName, defaultValue)
    if addon and type(addon.GetCharDB) == "function" then
        local _, cdb = addon.GetCharDB()
        if cdb and cdb.settings then
            local value = cdb.settings[settingName]
            if value ~= nil then
                return value
            end
        end
    end
    return defaultValue
end

-- Set a setting value in character database
local function SetSetting(settingName, value)
    if addon and type(addon.GetCharDB) == "function" then
        local _, cdb = addon.GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings[settingName] = value
        end
    end
end

-- =========================================================
-- Faction Helpers
-- =========================================================

-- UnitFactionGroup returns (englishTag, localizedName). Catalog defs use FACTION_ALLIANCE /
-- FACTION_HORDE (localized globals). Match either so English and non-English clients both work.
local function PlayerFactionMatches(requiredFaction)
    if not requiredFaction then
        return true
    end
    local factionTag, factionLocalized = UnitFactionGroup("player")
    return requiredFaction == factionTag or requiredFaction == factionLocalized
end

-- =========================================================
-- Class Color Helper
-- =========================================================

-- Cache the class color string (player's class doesn't change during session)
local cachedClassColor = nil

-- Initialize class color cache
local function InitializeClassColor()
    if not cachedClassColor then
        -- Use the same method as the original implementation for compatibility
        cachedClassColor = "|c" .. select(4, GetClassColor(select(2, UnitClass("player"))))
    end
    return cachedClassColor
end

local function GetClassColor()
    -- Return cached value, initializing if needed
    if not cachedClassColor then
        InitializeClassColor()
    end
    return cachedClassColor
end

-- Initialize on PLAYER_LOGIN event
local classColorFrame = CreateFrame("Frame")
classColorFrame:RegisterEvent("PLAYER_LOGIN")
classColorFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeClassColor()
        self:UnregisterAllEvents()
    end
end)

-- =========================================================
-- Character Panel Tab Management
-- =========================================================

-- Get the Character Frame achievement tab
local function GetAchievementTab()
    return _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
end

-- Check if tab is the achievement tab
local function IsAchievementTab(tab)
    if not tab or not tab.GetText then return false end
    local tabText = tab:GetText()
    if not tabText then return false end
    return tabText:find("Achievement") ~= nil or (_G.ACHIEVEMENTS and tabText:find(_G.ACHIEVEMENTS))
end

-- Show or hide the Character Panel achievement tab based on useCharacterPanel setting
local function UpdateCharacterPanelTabVisibility()
    -- Get the actual Tab frame directly (more reliable than searching by name)
    local tab = nil
    if addon and type(addon.GetTab) == "function" then
        tab = addon.GetTab()
    end
    
    -- Fallback to finding by name if getter not available
    if not tab then
        tab = GetAchievementTab()
        if not tab or not IsAchievementTab(tab) then 
            -- Tab not found, but still call LoadTabPosition which will handle it
            if addon and type(addon.LoadTabPosition) == "function" then
                addon.LoadTabPosition()
            end
            return 
        end
    end
    
    local useCharacterPanel = GetSetting("useCharacterPanel", true)
    
    if useCharacterPanel then
        -- Show custom tab (Character Panel mode) - LoadTabPosition will handle the actual showing
        -- Also restore vertical tab if it was in vertical mode
        if addon and type(addon.LoadTabPosition) == "function" then
            addon.LoadTabPosition()
        end
    else
        -- Hide custom tab (Dashboard mode) - hide immediately
        if tab then
            tab:Hide()
            -- Also hide square frame if it exists
            if tab.squareFrame then
                tab.squareFrame:Hide()
                tab.squareFrame:EnableMouse(false)
            end
        end
        -- Also hide vertical tab immediately
        if addon and type(addon.HideVerticalTab) == "function" then
            addon.HideVerticalTab()
        end
    end
end

-- Set useCharacterPanel setting and update tab visibility
local function SetUseCharacterPanel(enabled)
    SetSetting("useCharacterPanel", enabled)
    
    -- Sync showCustomTab with useCharacterPanel to keep them in sync
    if addon and type(addon.GetCharDB) == "function" then
        local _, cdb = addon.GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings.showCustomTab = enabled
        end
    end
    
    UpdateCharacterPanelTabVisibility()
    
    -- Reload tab position only when enabling (positioning). When disabling, we already hid it directly.
    if enabled and addon and type(addon.LoadTabPosition) == "function" then
        addon.LoadTabPosition()
    end
end

-- =========================================================
-- Self Found: returns true if player has Self-Found buff, else false.
-- Other files: local IsSelfFound = addon.IsSelfFound; call IsSelfFound() for true/false.
-- =========================================================

local function IsSelfFound()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId == 431567 or name == "Self-Found Adventurer" then
            return true
        end
    end
    return false
end

-- =========================================================
-- Achievement Display Values (centralized for frames and links)
-- =========================================================
local function IsSecretSource(source)
    return source and (
        source.secret or source.isSecretAchievement or
        source.secretTitle or source.secretTooltip or source.secretIcon or source.secretPoints
    ) or false
end

-- Returns icon, title, tooltip, points to display.
-- For frames: pass row/srow with .completed; useSourceCompletion=true (default).
-- For links: pass def; useSourceCompletion=false, viewerCompleted=ViewerHasCompletedAchievement(achId).
-- skipSecrecy: if true (e.g. guild-first), never use secret placeholders.
local function GetAchievementDisplayValues(source, options)
    if not source then return 136116, "Achievement", "", 0 end
    options = options or {}
    local useSourceCompletion = options.useSourceCompletion ~= false
    local viewerCompleted = options.viewerCompleted or false
    local isGuildFirst = source.isGuildFirst or (source._def and source._def.isGuildFirst)
    local skipSecrecy = options.skipSecrecy or isGuildFirst or false
    
    local completed = useSourceCompletion and (source.completed == true) or viewerCompleted
    local isSecret = not skipSecrecy and IsSecretSource(source)
    local useSecret = isSecret and not completed
    
    if useSecret then
        return
            source.secretIcon or 134400,
            source.secretTitle or "Secret",
            source.secretTooltip or "Hidden",
            tonumber(source.secretPoints) or 0
    end
    local icon = (source.Icon and source.Icon.GetTexture and source.Icon:GetTexture()) or source.icon or source.revealIcon or 136116
    local title = (source.Title and source.Title.GetText and source.Title:GetText()) or source.title or source.revealTitle or (source.id or source.achId or "")
    local tooltip = source.tooltip or source.revealTooltip or ""
    local points = tonumber(source.points) or 0
    return icon, title, tooltip, points
end

-- =========================================================
-- Achievement Definition Registration
-- =========================================================

-- Unified function to register achievement definitions to AchievementDefs
-- This ensures all achievement types (quest, dungeon, raid, meta, etc.) use the same structure
-- Parameters:
--   def: The achievement definition table (from Catalog files)
--   overrides: Optional table of field overrides (e.g., { level = nil } for raids)
local function RegisterAchievementDef(def, overrides)
    if not def or not def.achId or not addon then
        return
    end
    addon.AchievementDefs = addon.AchievementDefs or {}
    local isSecretDef = IsSecretSource(def)
    
    -- Build the definition entry with all common fields
    local achDef = {
        achId = def.achId,
        title = def.title,
        tooltip = def.tooltip,
        icon = def.icon,
        points = def.points or 0,
        level = def.level,
        -- Quest-specific fields
        targetNpcId = def.targetNpcId,
        requiredKills = def.requiredKills,
        requiredQuestId = def.requiredQuestId,
        -- Dungeon/Raid-specific fields
        mapID = def.requiredMapId or def.mapID,
        mapName = def.mapName or def.title,
        bossOrder = def.bossOrder,
        extraCreditKills = def.extraCreditKills,
        extraCreditLegacyGrant = def.extraCreditLegacyGrant,
        -- Meta-specific fields
        requiredAchievements = def.requiredAchievements,
        achievementOrder = def.achievementOrder,
        acceptAnyVariation = def.acceptAnyVariation or false,
        -- Common fields
        faction = def.faction,
        race = def.race,
        class = def.class,
        zone = def.zone,
        explorationZone = def.explorationZone,
        explorationThreshold = def.explorationThreshold,
        -- Dungeon set / reputation fields
        requiredItems = def.requiredItems,
        itemOrder = def.itemOrder,
        isDungeonSet = def.isDungeonSet or false,
        isReputation = def.isReputation or false,
        isGuildFirst = def.isGuildFirst or false,
        factionId = def.factionId,
        -- Type flags
        isQuest = def.isQuest or false,
        isRaid = def.isRaid or false,
        isHeroicDungeon = def.isHeroicDungeon or false,
        isMetaAchievement = def.isMetaAchievement or false,
        isContinentExploration = def.isContinentExploration or false,
        isVariation = def.isVariation or false,
        baseAchId = def.baseAchId,
        -- Secret achievement fields (for links and UI)
        secret = isSecretDef,
        isSecretAchievement = isSecretDef,
        secretTitle = def.secretTitle,
        secretTooltip = def.secretTooltip,
        secretIcon = def.secretIcon,
        secretPoints = def.secretPoints,
        -- Link display (sender-stable title/tooltip)
        linkUsesSenderTitle = def.linkUsesSenderTitle,
        linkTitle = def.linkTitle,
        linkTooltip = def.linkTooltip,
    }
    
    -- Apply any overrides (e.g., raids might set level = nil)
    if overrides then
        for key, value in pairs(overrides) do
            achDef[key] = value
        end
    end
    
    addon.AchievementDefs[tostring(def.achId)] = achDef
end

---------------------------------------
-- Required kill tooltip/tracker helpers
---------------------------------------

local function GetRequiredKillCounts(achId)
    if addon and addon.GetAchievementFunction then
        local fn = addon.GetAchievementFunction(achId, "GetKillCounts")
        if type(fn) == "function" then
            local counts = fn()
            if type(counts) == "table" then
                return counts
            end
        end
    end
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
    return (progress and progress.counts) or {}
end

local function GetRequiredKillHeader(achDef, def)
    local header = (achDef and achDef.requiredKillHeader) or (def and def.requiredKillHeader)
    if type(header) == "string" and header ~= "" then
        return header
    end
    return "Required Bosses"
end

local function ShouldShowRequiredKillCounts(achDef, def)
    return (achDef and achDef.showRequiredKillCounts) or (def and def.showRequiredKillCounts) or false
end

local EXTRA_CREDIT_POINTS_PER_BOSS = 5

local function GetAchievementRecord(achId)
    if not achId or not addon or type(addon.GetCharDB) ~= "function" then
        return nil
    end
    local _, cdb = addon.GetCharDB()
    return cdb and cdb.achievements and cdb.achievements[tostring(achId)]
end

local function IsExtraCreditKillAwarded(achId, npcId)
    if not achId or npcId == nil then
        return false
    end
    local key = tostring(npcId)
    local rec = GetAchievementRecord(achId)
    if rec and type(rec.extraCreditKills) == "table" then
        if rec.extraCreditKills[key] or rec.extraCreditKills[npcId] or rec.extraCreditKills[tonumber(npcId)] then
            return true
        end
    end
    local counts = GetRequiredKillCounts(achId)
    local current = tonumber(counts[npcId] or counts[key] or counts[tonumber(npcId)] or 0) or 0
    return current >= 1
end

local function GetExtraCreditPoints(achId)
    local rec = GetAchievementRecord(achId)
    if rec and rec.extraCreditPoints then
        return tonumber(rec.extraCreditPoints) or 0
    end
    local progress = addon and addon.GetProgress and addon.GetProgress(achId)
    return tonumber(progress and progress.extraCreditPoints) or 0
end

local function ApplyExtraCreditPointsToRow(achId, rec)
    if not rec then
        return
    end
    local row = addon and addon.GetAchievementRow and addon.GetAchievementRow(achId)
    if row then
        if rec.points ~= nil then
            row.points = rec.points
        end
        local frame = row.frame or row
        if frame and frame ~= row then
            frame.points = row.points
        end
        if frame and frame.Points then
            frame.Points:SetText(tostring(row.points or rec.points or 0))
        end
    end
    if addon and addon.InvalidateCachedAchievementStats then
        addon.InvalidateCachedAchievementStats()
    end
    if addon and addon.UpdateTotalPoints then
        addon.UpdateTotalPoints()
    end
    if addon and addon.RefreshAuxiliaryViews then
        addon.RefreshAuxiliaryViews()
    end
end

-- Persist an extra-credit boss kill. Returns points added (0 if already awarded).
-- Additive after multipliers, same as self-found: +5 per boss.
local function AwardDungeonExtraCreditKill(achId, npcId)
    if not achId or npcId == nil or not addon or type(addon.GetCharDB) ~= "function" then
        return 0
    end
    local _, cdb = addon.GetCharDB()
    if not cdb then
        return 0
    end
    cdb.achievements = cdb.achievements or {}
    local id = tostring(achId)
    cdb.achievements[id] = cdb.achievements[id] or {}
    local rec = cdb.achievements[id]
    rec.extraCreditKills = rec.extraCreditKills or {}
    local key = tostring(npcId)
    if rec.extraCreditKills[key] then
        return 0
    end

    rec.extraCreditKills[key] = true
    rec.extraCreditPoints = (tonumber(rec.extraCreditPoints) or 0) + EXTRA_CREDIT_POINTS_PER_BOSS
    if addon.SetProgress then
        addon.SetProgress(achId, "extraCreditPoints", rec.extraCreditPoints)
    end

    if rec.completed then
        rec.points = (tonumber(rec.points) or 0) + EXTRA_CREDIT_POINTS_PER_BOSS
        ApplyExtraCreditPointsToRow(achId, rec)
    end
    return EXTRA_CREDIT_POINTS_PER_BOSS
end

-- Completions from before extra-credit existed may have required some of these bosses.
-- Only grant for IDs listed in legacyGrant (e.g. Urok), never for rares that were always optional.
local function GrantLegacyDungeonExtraCredit(achId, legacyGrant)
    if not achId or type(legacyGrant) ~= "table" or not next(legacyGrant) then
        return
    end
    local rec = GetAchievementRecord(achId)
    if not rec or not rec.completed or rec.extraCreditKills ~= nil then
        return
    end
    rec.extraCreditKills = {}
    rec.extraCreditPoints = 0
    for npcId in pairs(legacyGrant) do
        rec.extraCreditKills[tostring(npcId)] = true
        rec.extraCreditPoints = rec.extraCreditPoints + EXTRA_CREDIT_POINTS_PER_BOSS
    end
    if rec.extraCreditPoints > 0 then
        rec.points = (tonumber(rec.points) or 0) + rec.extraCreditPoints
        ApplyExtraCreditPointsToRow(achId, rec)
    end
end

-- Returns ordered entries: { text = "Name 0/2", done = bool }
local function BuildRequiredKillEntries(achId, requiredKills, opts)
    opts = opts or {}
    local achDef = opts.achDef
    local def = opts.def
    local extraCreditKills = opts.extraCreditKills or (achDef and achDef.extraCreditKills) or (def and def.extraCreditKills)
    if (not requiredKills or next(requiredKills) == nil) and (not extraCreditKills or next(extraCreditKills) == nil) then
        return {}
    end
    requiredKills = requiredKills or {}

    local bossOrder = opts.bossOrder or (achDef and achDef.bossOrder) or (def and def.bossOrder)
    local achievementCompleted = opts.achievementCompleted and true or false
    local isRaid = opts.isRaid and true or false
    local showCounts = ShouldShowRequiredKillCounts(achDef, def)
    local counts = GetRequiredKillCounts(achId)
    local npcNames = (achDef and achDef.npcNames) or (def and def.npcNames) or {}
    local header = GetRequiredKillHeader(achDef, def)
    local fallbackPrefix = (header ~= "Required Bosses") and "NPC " or "Boss "

    local getBossNameFn = isRaid and (addon and addon.GetRaidBossName) or (addon and addon.GetBossName)

    local function resolveName(id)
        local idNum = tonumber(id) or id
        if npcNames[idNum] then return npcNames[idNum] end
        if npcNames[tostring(idNum)] then return npcNames[tostring(idNum)] end
        if getBossNameFn then
            local name = getBossNameFn(idNum)
            if name and name ~= "" then return name end
        end
        return fallbackPrefix .. tostring(idNum)
    end

    local function processEntry(npcId, need, extraCredit)
        local done = (not extraCredit) and achievementCompleted
        local text = ""

        if type(need) == "table" then
            local names = {}
            for _, id in pairs(need) do
                local current = (counts[id] or counts[tostring(id)] or 0)
                table.insert(names, resolveName(id))
                if extraCredit then
                    if IsExtraCreditKillAwarded(achId, id) or current >= 1 then
                        done = true
                    end
                elseif not done and current >= 1 then
                    done = true
                end
            end
            if type(npcId) == "string" then
                text = npcId
            else
                text = table.concat(names, " / ")
            end
        else
            local idNum = tonumber(npcId) or npcId
            local needNum = tonumber(need) or 1
            local current = tonumber(counts[idNum] or counts[tostring(idNum)] or 0) or 0
            if current > needNum then current = needNum end
            local name = resolveName(idNum)
            if extraCredit then
                text = name
                done = IsExtraCreditKillAwarded(achId, idNum) or current >= needNum
            else
                if showCounts then
                    text = name .. " " .. tostring(current) .. "/" .. tostring(needNum)
                else
                    text = name
                end
                if not done then
                    done = current >= needNum
                end
            end
        end

        if extraCredit and text ~= "" then
            text = text .. " (+" .. tostring(EXTRA_CREDIT_POINTS_PER_BOSS) .. " pts)"
        end

        return { text = text, done = done, extraCredit = extraCredit and true or nil }
    end

    local entries = {}
    local seen = {}

    local function markSeen(npcId)
        seen[npcId] = true
        seen[tostring(npcId)] = true
        local idNum = tonumber(npcId)
        if idNum then seen[idNum] = true end
    end

    extraCreditKills = extraCreditKills or {}
    if bossOrder then
        for _, npcId in ipairs(bossOrder) do
            local need = requiredKills[npcId]
            if need then
                table.insert(entries, processEntry(npcId, need, false))
                markSeen(npcId)
            elseif extraCreditKills[npcId] then
                table.insert(entries, processEntry(npcId, extraCreditKills[npcId], true))
                markSeen(npcId)
            end
        end
    end
    for npcId, need in pairs(requiredKills) do
        if not seen[npcId] and not seen[tostring(npcId)] and not seen[tonumber(npcId) or npcId] then
            table.insert(entries, processEntry(npcId, need, false))
            markSeen(npcId)
        end
    end
    for npcId, need in pairs(extraCreditKills) do
        if not seen[npcId] and not seen[tostring(npcId)] and not seen[tonumber(npcId) or npcId] then
            table.insert(entries, processEntry(npcId, need, true))
        end
    end
    return entries
end

local function PartitionKillEntries(entries)
    local required, bonus = {}, {}
    if type(entries) ~= "table" then
        return required, bonus
    end
    for i = 1, #entries do
        local entry = entries[i]
        if entry and entry.extraCredit then
            table.insert(bonus, entry)
        elseif entry then
            table.insert(required, entry)
        end
    end
    return required, bonus
end

---------------------------------------
-- Export: internal (addon)
---------------------------------------
if addon then
    addon.GetSetting = GetSetting
    addon.GetClassColor = GetClassColor
    addon.GetAchievementDisplayValues = GetAchievementDisplayValues
    addon.UpdateCharacterPanelTabVisibility = UpdateCharacterPanelTabVisibility
    addon.SetUseCharacterPanel = SetUseCharacterPanel
    addon.RegisterAchievementDef = RegisterAchievementDef
    addon.IsSelfFound = IsSelfFound
    addon.PlayerFactionMatches = PlayerFactionMatches
    addon.GetRequiredKillCounts = GetRequiredKillCounts
    addon.GetRequiredKillHeader = GetRequiredKillHeader
    addon.ShouldShowRequiredKillCounts = ShouldShowRequiredKillCounts
    addon.BuildRequiredKillEntries = BuildRequiredKillEntries
    addon.PartitionKillEntries = PartitionKillEntries
    addon.IsExtraCreditKillAwarded = IsExtraCreditKillAwarded
    addon.GetExtraCreditPoints = GetExtraCreditPoints
    addon.AwardDungeonExtraCreditKill = AwardDungeonExtraCreditKill
    addon.GrantLegacyDungeonExtraCredit = GrantLegacyDungeonExtraCredit
    addon.EXTRA_CREDIT_POINTS_PER_BOSS = EXTRA_CREDIT_POINTS_PER_BOSS
end