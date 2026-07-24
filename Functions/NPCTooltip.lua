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
        end
    end
end

local function GetAchievementsForNPC(npcId)
    if not npcId then return {} end
    if not _npcToAchievements then BuildNPCIndex() end
    return _npcToAchievements[npcId] or {}
end

-- Hook GameTooltip to add achievement information
local function HookNPCTooltip()
    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            local unit = select(2, self:GetUnit())
            if not unit then return end
            
            local guid = UnitGUID(unit)
            if not guid then return end
            
            -- Only process NPCs (not players, pets, etc.)
            local npcId = GetNPCIdFromGUID(guid)
            if not npcId then return end
            
            -- Find achievements that require this NPC
            local achievements = GetAchievementsForNPC(npcId)
            if #achievements > 0 then
                GameTooltip:AddLine(" ")  -- Add spacing
                for _, ach in ipairs(achievements) do
                    -- Prefix achievement title with logo icon
                    local iconPath = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png"
                    local iconSize = 16  -- Size of the icon in pixels
                    local iconString = "|T" .. iconPath .. ":" .. iconSize .. ":" .. iconSize .. "|t "
                    GameTooltip:AddLine(iconString .. ach.title)
                end
                --GameTooltip:AddLine(" ")  -- Add spacing
            end
        end)
    end
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
