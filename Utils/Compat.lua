local addonName, addon = ...

-- =========================================================
-- Cross-version API bridge
--
-- Forever runs on the retail API surface but does not identify itself as retail: GetExpansionLevel()
-- reports 0, the same as Classic Era. Anything that branches on a version number is therefore wrong on
-- at least one client. Everything here probes for the function or template it needs instead, so a
-- client is treated as retail because it behaves like retail, not because of what it calls itself.
--
-- This file is shared rather than forked on purpose. A fork is the right answer when a whole feature
-- works differently (see Forever\NPCTooltip.lua); it is the wrong answer for a one-call API rename,
-- because it duplicates hundreds of unrelated lines that then have to be kept in step by hand.
-- =========================================================

local C_UnitAuras_GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local UnitBuff = UnitBuff
local C_XMLUtil_GetTemplateInfo = C_XMLUtil and C_XMLUtil.GetTemplateInfo
local select = select

--- Reads one of the player's helpful auras by index.
--- UnitBuff was removed in retail 11.0 in favour of C_UnitAuras. Callers only ever needed the name and
--- spell id out of the old ten-value return, so this returns just those two.
--- @param index number 1-based aura slot
--- @return string? name, number? spellId  nil name means there is no aura at that index
function addon.GetPlayerBuff(index)
    if UnitBuff then
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", index)
        return name, spellId
    end

    if C_UnitAuras_GetAuraDataByIndex then
        local data = C_UnitAuras_GetAuraDataByIndex("player", index, "HELPFUL")
        if data then
            return data.name, data.spellId
        end
    end

    return nil
end

--- Creates a bottom-edge panel tab button, styled if this client's templates allow it.
--- CharacterFrameTabButtonTemplate is absent on retail-based clients (Forever), where the nearest
--- equivalent is PanelTabButtonTemplate.
--- @return table tab
function addon.CreatePanelTab(name, parent, label)
    local tab = CreateFrame("Button", name, parent,
        addon.ResolveTemplate("CharacterFrameTabButtonTemplate", "PanelTabButtonTemplate"))

    if label then
        tab:SetText(label)
    end

    -- These reach into the template's Left/Middle/Right textures and throw on a substitute template
    -- that lacks them. Two of the callers run at file load, where an uncaught error discards the rest
    -- of the file, so a template mismatch degrades to an unstyled tab instead.
    if PanelTemplates_TabResize then
        pcall(PanelTemplates_TabResize, tab, 0)
    end
    if PanelTemplates_DeselectTab then
        pcall(PanelTemplates_DeselectTab, tab)
    end

    return tab
end

--- How many tabs the character panel has.
--- The Classic character panel keeps a numTabs field; the retail one leaves it nil, which turned every
--- `CharacterFrame.numTabs + 1` into an arithmetic-on-nil error. Counting the globals the tabs register
--- themselves under gives the same answer without trusting the field to exist.
--- @return number
function addon.GetCharacterFrameTabCount()
    local count = CharacterFrame and CharacterFrame.numTabs
    if type(count) == "number" then
        return count
    end

    count = 0
    for i = 1, 12 do
        if _G["CharacterFrameTab" .. i] then
            count = i
        end
    end
    return count
end

--- The last Blizzard tab on the character panel, for anchoring our own tab beside it.
--- Returns nil on clients that have no character panel tabs at all, so callers must have a fallback
--- anchor rather than passing the result straight to SetPoint.
--- @return table? tab
function addon.GetLastCharacterFrameTab()
    for i = addon.GetCharacterFrameTabCount(), 1, -1 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab then
            return tab
        end
    end
    return nil
end

-- Reputation. GetNumFactions, GetFactionInfo and GetFactionInfoByID were all removed in retail 10.x in
-- favour of C_Reputation, which returns a table instead of a long positional tuple. These three shims
-- expose only the fields this addon reads, so callers stop caring which client they are on.

--- Size of the reputation list, headers included.
--- @return number
function addon.GetNumFactionEntries()
    if C_Reputation and C_Reputation.GetNumFactions then
        return C_Reputation.GetNumFactions() or 0
    end
    if GetNumFactions then
        return GetNumFactions() or 0
    end
    return 0
end

--- One reputation list entry by index.
--- @return number? factionId, number? standingId, boolean isHeader
function addon.GetFactionEntryByIndex(index)
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
        local data = C_Reputation.GetFactionDataByIndex(index)
        if data then
            return data.factionID, data.reaction, data.isHeader and true or false
        end
        return nil
    end

    if GetFactionInfo then
        local _, _, standingId, _, _, _, _, _, isHeader, _, _, _, _, factionId = GetFactionInfo(index)
        return factionId, standingId, isHeader and true or false
    end
    return nil
end

--- Reputation standing for one faction, or nil if the player has not encountered it.
--- 8 is Exalted on both API generations.
--- @return number? standingId
function addon.GetFactionStandingById(factionId)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(factionId)
        return data and data.reaction
    end

    if GetFactionInfoByID then
        local _, _, standingId = GetFactionInfoByID(factionId)
        return standingId
    end

    -- Oldest clients only expose the list, so walk it.
    for i = 1, addon.GetNumFactionEntries() do
        local id, standingId, isHeader = addon.GetFactionEntryByIndex(i)
        if not isHeader and id == factionId then
            return standingId
        end
    end
    return nil
end

--- Hooks a global function only if it exists on this client.
--- hooksecurefunc raises an error when the named global is missing, and several of these hooks sit in
--- main-chunk code where that error would discard the rest of the file. Retail has retired some of the
--- Character UI globals this addon hooks (CharacterFrame_ShowSubFrame among them).
--- @return boolean installed
function addon.SafeHookGlobal(name, hook)
    if type(name) ~= "string" or type(hook) ~= "function" then
        return false
    end
    if type(_G[name]) ~= "function" then
        return false
    end
    hooksecurefunc(name, hook)
    return true
end

--- Returns the first of the supplied frame templates that exists on this client.
--- Passing a nil template to CreateFrame yields a plain, unstyled frame, which is a far better outcome
--- than the error an unknown template name produces.
--- @return string? templateName
function addon.ResolveTemplate(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if not C_XMLUtil_GetTemplateInfo then
            -- No way to ask. The caller lists the oldest-client template first, which is the correct
            -- guess for any client too old to have the lookup.
            return name
        end
        if name and C_XMLUtil_GetTemplateInfo(name) then
            return name
        end
    end
    return nil
end
