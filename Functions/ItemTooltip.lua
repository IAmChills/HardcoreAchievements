local addonName, addon = ...
local GameTooltip = GameTooltip
local CreateFrame = CreateFrame
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local type = type
local table_insert = table.insert
local strmatch = string.match
local string_format = string.format

local ADDON_LOGO = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png"

-- Reverse index: itemId -> list of { achId, title, icon }.
-- Built once on first use. AchievementDefs does not change after load.
local _itemToAchievements = nil

local function BuildItemIndex()
    _itemToAchievements = {}
    if not (addon and addon.AchievementDefs) then return end
    for achId, achDef in pairs(addon.AchievementDefs) do
        if not achDef.isVariation and not achDef.secret then
            local items = achDef.requiredItems
            -- Gear sets use an array of item IDs. Skip scalar counts (e.g. secret "own N items").
            if type(items) == "table" and #items > 0 then
                local entry = {
                    achId = achId,
                    title = achDef.title or achDef.mapName or tostring(achId),
                }
                local seen = {}
                for _, itemId in ipairs(items) do
                    itemId = tonumber(itemId)
                    if itemId and not seen[itemId] then
                        seen[itemId] = true
                        if not _itemToAchievements[itemId] then
                            _itemToAchievements[itemId] = {}
                        end
                        table_insert(_itemToAchievements[itemId], entry)
                    end
                end
            end
        end
    end
end

local function GetAchievementsForItem(itemId)
    itemId = tonumber(itemId)
    if not itemId then return {} end
    if not _itemToAchievements then BuildItemIndex() end
    return _itemToAchievements[itemId] or {}
end

local function ResolveItemIdFromTooltip(tooltip, data)
    if type(data) == "table" then
        local id = tonumber(data.id) or tonumber(data.itemID) or tonumber(data.ItemID)
        if id then return id end
    end
    if not tooltip or not tooltip.GetItem then return nil end
    local ok, _, link = pcall(function()
        return tooltip:GetItem()
    end)
    if not ok or type(link) ~= "string" then return nil end
    return tonumber(strmatch(link, "item:(%d+)"))
end

-- Appends one line per achievement that requires this item (gear sets, etc.).
-- Same presentation as NPC tooltips: Hardcore Achievements logo + title.
local function AppendItemAchievementLines(tooltip, itemId)
    if not tooltip then return end
    itemId = tonumber(itemId)
    if not itemId then return end

    local achievements = GetAchievementsForItem(itemId)
    if #achievements == 0 then return end

    tooltip:AddLine(" ")
    local iconString = string_format("|T%s:16:16|t ", ADDON_LOGO)
    for _, ach in ipairs(achievements) do
        tooltip:AddLine(iconString .. ach.title)
    end
end

if addon then
    addon.AppendItemAchievementLines = AppendItemAchievementLines
    addon.ResolveItemIdFromTooltip = ResolveItemIdFromTooltip
end

local function HookItemTooltip()
    -- Forever/retail use TooltipDataProcessor (Forever\ItemTooltip.lua); stand down here.
    if TooltipDataProcessor then return end
    if not GameTooltip then return end

    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        local itemId = ResolveItemIdFromTooltip(self)
        if itemId then
            AppendItemAchievementLines(self, itemId)
        end
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedName)
    if loadedName == "HardcoreAchievements" then
        HookItemTooltip()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
