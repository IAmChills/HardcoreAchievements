local addonName, addon = ...
local GameTooltip = GameTooltip
local UnitGUID = UnitGUID
local strsplit = strsplit
local CreateFrame = CreateFrame
local select = select
local tonumber = tonumber
local pairs = pairs
local type = type
local table_insert = table.insert

local function GetNPCIdFromGUID(guid)
    if not guid then return nil end
    local npcId = select(6, strsplit("-", guid))
    return npcId and tonumber(npcId) or nil
end

-- Reverse index: npcId -> list of { achId, title }.
-- Built once on first use. AchievementDefs does not change after load.
local _npcToAchievements = nil

local function BuildNPCIndex()
    _npcToAchievements = {}
    if not (addon and addon.AchievementDefs) then return end
    for achId, achDef in pairs(addon.AchievementDefs) do
        if not achDef.isVariation and not achDef.secret then
            local entry = { achId = achId, title = achDef.title or achDef.mapName or tostring(achId) }
            local function addEntry(npcId)
                npcId = tonumber(npcId)
                if not npcId then return end
                if not _npcToAchievements[npcId] then _npcToAchievements[npcId] = {} end
                table_insert(_npcToAchievements[npcId], entry)
            end
            if achDef.targetNpcId then
                if type(achDef.targetNpcId) == "table" then
                    for _, id in pairs(achDef.targetNpcId) do addEntry(id) end
                else
                    addEntry(achDef.targetNpcId)
                end
            end
            if achDef.requiredKills then
                for killNpcId, need in pairs(achDef.requiredKills) do
                    if type(need) == "table" then
                        for _, id in pairs(need) do addEntry(id) end
                    else
                        addEntry(killNpcId)
                    end
                end
            end
            if achDef.extraCreditKills then
                for killNpcId, need in pairs(achDef.extraCreditKills) do
                    if type(need) == "table" then
                        for _, id in pairs(need) do addEntry(id) end
                    else
                        addEntry(killNpcId)
                    end
                end
            end
        end
    end
end

local function GetAchievementsForNPC(npcId)
    if not npcId then return {} end
    if not _npcToAchievements then BuildNPCIndex() end
    return _npcToAchievements[npcId] or {}
end

-- Appends one line per achievement that involves `unit`. Both tooltip hook styles share this: the
-- classic OnTooltipSetUnit script below, and TooltipDataProcessor on retail (Forever\NPCTooltip.lua).
local function AppendNPCAchievementLines(tooltip, unit)
    if not tooltip or not unit then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- Only process NPCs (not players, pets, etc.)
    local npcId = GetNPCIdFromGUID(guid)
    if not npcId then return end

    -- Find achievements that require this NPC
    local achievements = GetAchievementsForNPC(npcId)
    if #achievements == 0 then return end

    tooltip:AddLine(" ")  -- Add spacing
    for _, ach in ipairs(achievements) do
        -- Prefix achievement title with logo icon
        local iconPath = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png"
        local iconSize = 16  -- Size of the icon in pixels
        local iconString = "|T" .. iconPath .. ":" .. iconSize .. ":" .. iconSize .. "|t "
        tooltip:AddLine(iconString .. ach.title)
    end
end

if addon then addon.AppendNPCAchievementLines = AppendNPCAchievementLines end

-- Hook GameTooltip to add achievement information
local function HookNPCTooltip()
    -- Retail (Forever) dropped the OnTooltipSetUnit script in 10.0, and HookScript raises an error when
    -- handed a script name the frame does not have. Forever\NPCTooltip.lua registers the
    -- TooltipDataProcessor equivalent instead, so stand down when that system is present.
    if TooltipDataProcessor then return end
    if not GameTooltip then return end

    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        AppendNPCAchievementLines(self, select(2, self:GetUnit()))
    end)
end

-- Initialize on addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HardcoreAchievements" then
        -- Hook after a short delay to ensure GameTooltip is ready
            HookNPCTooltip()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
