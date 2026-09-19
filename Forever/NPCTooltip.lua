local addonName, addon = ...

-- =========================================================
-- NPC tooltip achievement hints, retail flavour
--
-- Retail 10.0 removed the OnTooltipSetUnit script in favour of TooltipDataProcessor, so the classic
-- hook in Functions\NPCTooltip.lua cannot be installed here. Only the registration differs: the NPC
-- reverse index and the line rendering stay in the shared file, which stands down when it sees
-- TooltipDataProcessor so the two never both hook.
-- =========================================================

if not (TooltipDataProcessor
    and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit) then
    return
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
    -- The post-call fires for every unit tooltip, including the compare and inspect ones.
    if tooltip ~= GameTooltip then return end

    local append = addon and addon.AppendNPCAchievementLines
    if not append then return end

    local _, unit = tooltip:GetUnit()
    if not unit then return end

    append(tooltip, unit)
end)
