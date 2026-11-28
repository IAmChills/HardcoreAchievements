local addonName, addon = ...

-- =========================================================
-- Item tooltip achievement hints, retail flavour
--
-- Mirrors Forever\NPCTooltip.lua: retail uses TooltipDataProcessor for item
-- tooltips, while Functions\ItemTooltip.lua owns the reverse index + line
-- rendering and stands down when TooltipDataProcessor is present.
-- =========================================================

if not (TooltipDataProcessor
    and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item) then
    return
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip ~= GameTooltip then return end

    local append = addon and addon.AppendItemAchievementLines
    if not append then return end

    local itemId
    if addon.ResolveItemIdFromTooltip then
        itemId = addon.ResolveItemIdFromTooltip(tooltip, data)
    elseif type(data) == "table" then
        itemId = tonumber(data.id)
    end
    if not itemId then return end

    append(tooltip, itemId)
end)
