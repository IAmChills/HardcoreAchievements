local addonName, addon = ...

-- =========================================================
-- Forever: 4th chrome tab on LegacySystemFrame
--
-- Blizzard's strip is three Frames on the host itself:
--   LegacyChallengeTab, LegacyTreeTab, LegacyRewardTrackTab
-- plus host.Tabs / host.Pages / host.currentPage.
-- Classic/TBC never load this file.
-- =========================================================

addon.IsForeverCharacterUI = true

local BLIZZARD_TAB_FIELDS = {
    "LegacyChallengeTab",
    "LegacyTreeTab",
    "LegacyRewardTrackTab",
}

local hookedBlizzardTabs = {}
local modeTab

local function GetHostFrame()
    return _G.LegacySystemFrame or _G.LegacyChallengesFrame
end

local function FrameHasScript(frame, script)
    return frame and type(frame.HasScript) == "function" and frame:HasScript(script)
end

local function SafeHookScript(frame, script, handler)
    if not FrameHasScript(frame, script) then
        return false
    end
    return pcall(frame.HookScript, frame, script, handler)
end

local function SafeSetScript(frame, script, handler)
    if not FrameHasScript(frame, script) then
        return false
    end
    return pcall(frame.SetScript, frame, script, handler)
end

local function SafeCall(frame, method, ...)
    if not frame or type(frame[method]) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(frame[method], frame, ...)
    if ok then
        return a, b, c, d
    end
    return nil
end

local function BindTabActivate(tab, handler)
    if not tab or type(handler) ~= "function" then
        return false
    end
    local function onMouse(self, button)
        if button and button ~= "LeftButton" then
            return
        end
        handler(self)
    end
    if SafeSetScript(tab, "OnClick", handler) then
        return true
    end
    if SafeSetScript(tab, "OnMouseUp", onMouse) then
        return true
    end
    if type(tab.OnClick) == "function" then
        hooksecurefunc(tab, "OnClick", handler)
        return true
    end
    return false
end

local function CopyTextureLook(dst, src)
    if not dst or not src then
        return
    end
    local atlas = SafeCall(src, "GetAtlas")
    if type(atlas) == "string" and atlas ~= "" then
        dst:SetAtlas(atlas)
    else
        local tex = SafeCall(src, "GetTexture")
        if tex then
            dst:SetTexture(tex)
        end
    end
    if src.GetTexCoord then
        pcall(function()
            dst:SetTexCoord(src:GetTexCoord())
        end)
    end
    local w = SafeCall(src, "GetWidth") or 20
    local h = SafeCall(src, "GetHeight") or 20
    dst:SetSize(w, h)
end

local function CopyAllPoints(dst, src, srcParent, dstParent)
    dst:ClearAllPoints()
    local n = SafeCall(src, "GetNumPoints") or 0
    if n == 0 then
        dst:SetAllPoints(dstParent)
        return
    end
    for i = 1, n do
        local ok, point, rel, relPoint, x, y = pcall(src.GetPoint, src, i)
        if ok then
            if rel == nil or rel == srcParent then
                rel = dstParent
            end
            dst:SetPoint(point, rel, relPoint, x, y)
        end
    end
end

local function GetBlizzardTabs(host)
    host = host or GetHostFrame()
    local tabs = {}
    if not host then
        return tabs
    end
    local seen = {}
    local function add(tab)
        if tab and not seen[tab] and tab ~= modeTab then
            seen[tab] = true
            tabs[#tabs + 1] = tab
        end
    end
    for i = 1, #BLIZZARD_TAB_FIELDS do
        add(host[BLIZZARD_TAB_FIELDS[i]])
    end
    if type(host.Tabs) == "table" then
        for i = 1, #host.Tabs do
            add(host.Tabs[i])
        end
    end
    return tabs
end

local function GetLastBlizzardTab(host)
    host = host or GetHostFrame()
    if host and type(host.Tabs) == "table" then
        for i = #host.Tabs, 1, -1 do
            if host.Tabs[i] and host.Tabs[i] ~= modeTab then
                return host.Tabs[i]
            end
        end
    end
    local tabs = GetBlizzardTabs(host)
    local best, bestBottom
    for i = 1, #tabs do
        local bottom = SafeCall(tabs[i], "GetBottom")
        if bottom and (not bestBottom or bottom < bestBottom) then
            best, bestBottom = tabs[i], bottom
        end
    end
    return best or tabs[#tabs]
end

local function TrySetSelected(tab, selected)
    if not tab then
        return
    end
    tab.isSelected = selected and true or false
    tab.selected = tab.isSelected
    if tab.SelectedTexture then
        if selected then
            tab.SelectedTexture:Show()
        else
            tab.SelectedTexture:Hide()
        end
    end
    if tab.TabGlow then
        if selected then
            tab.TabGlow:Show()
        else
            tab.TabGlow:Hide()
        end
    end
end

local function CloneTab(source, name, parent)
    local tab = CreateFrame("Frame", name, parent)
    local w = SafeCall(source, "GetWidth") or 32
    local h = SafeCall(source, "GetHeight") or 32
    tab:SetSize(w, h)
    tab:SetFrameStrata(source:GetFrameStrata())
    tab:SetFrameLevel((SafeCall(source, "GetFrameLevel") or 1) + 1)
    tab:EnableMouse(true)

    if source.Background then
        tab.Background = tab:CreateTexture(nil, "BACKGROUND")
        CopyTextureLook(tab.Background, source.Background)
        CopyAllPoints(tab.Background, source.Background, source, tab)
    end
    if source.HighlightTexture then
        tab.HighlightTexture = tab:CreateTexture(nil, "HIGHLIGHT")
        CopyTextureLook(tab.HighlightTexture, source.HighlightTexture)
        CopyAllPoints(tab.HighlightTexture, source.HighlightTexture, source, tab)
        tab.HighlightTexture:SetBlendMode("ADD")
    end
    if source.Icon then
        tab.Icon = tab:CreateTexture(nil, "ARTWORK")
        CopyTextureLook(tab.Icon, source.Icon)
        CopyAllPoints(tab.Icon, source.Icon, source, tab)
    end
    -- Do not copy Mask. An empty/cloned mask hides our PNG entirely.
    if source.SelectedTexture then
        tab.SelectedTexture = tab:CreateTexture(nil, "OVERLAY")
        CopyTextureLook(tab.SelectedTexture, source.SelectedTexture)
        CopyAllPoints(tab.SelectedTexture, source.SelectedTexture, source, tab)
        tab.SelectedTexture:Hide()
    end
    if source.TabGlow then
        tab.TabGlow = tab:CreateTexture(nil, "OVERLAY")
        CopyTextureLook(tab.TabGlow, source.TabGlow)
        CopyAllPoints(tab.TabGlow, source.TabGlow, source, tab)
        tab.TabGlow:Hide()
    end
    return tab
end

local ACHIEVEMENT_ICON = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsTab.png"

local function ApplyAchievementIcon(tab)
    local icon = tab.Icon or tab.icon
    if not icon or type(icon.SetTexture) ~= "function" then
        icon = tab:CreateTexture(nil, "ARTWORK")
        tab.Icon = icon
    end
    if icon.GetNumMaskTextures and icon.RemoveMaskTexture and icon.GetMaskTexture then
        for i = icon:GetNumMaskTextures(), 1, -1 do
            local mask = icon:GetMaskTexture(i)
            if mask then
                pcall(icon.RemoveMaskTexture, icon, mask)
            end
        end
    end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", -5, 1)
    icon:SetSize(SafeCall(tab, "GetWidth") + 7, SafeCall(tab, "GetHeight") + 4)
    pcall(function()
        icon:SetAtlas(nil)
    end)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetTexture(ACHIEVEMENT_ICON)
    icon:SetDrawLayer("ARTWORK", 2)
    icon:Show()
    if tab.SetIcon then
        pcall(tab.SetIcon, tab, ACHIEVEMENT_ICON)
    end
end

local function HideAchievementsForTabSwitch()
    if addon.HideLegacyAchievementsPage then
        addon.HideLegacyAchievementsPage()
    end
    TrySetSelected(modeTab, false)
end

local function HookBlizzardTab(tab)
    if not tab or tab == modeTab or hookedBlizzardTabs[tab] then
        return
    end
    hookedBlizzardTabs[tab] = true
    if not SafeHookScript(tab, "OnClick", HideAchievementsForTabSwitch) then
        SafeHookScript(tab, "OnMouseUp", HideAchievementsForTabSwitch)
    end
    if type(tab.OnClick) == "function" then
        pcall(hooksecurefunc, tab, "OnClick", HideAchievementsForTabSwitch)
    end
end

local function HookBlizzardTabs(host)
    local tabs = GetBlizzardTabs(host)
    for i = 1, #tabs do
        HookBlizzardTab(tabs[i])
    end
end

local function UnregisterFromHost(host, tab)
    -- SelectPage iterates host.Tabs and calls mixin methods. Our clone is not a
    -- Blizzard tab, so it must stay out of Tabs/Pages or clicking any tab errors.
    if type(host.Tabs) == "table" then
        for i = #host.Tabs, 1, -1 do
            if host.Tabs[i] == tab then
                table.remove(host.Tabs, i)
            end
        end
    end
    local page = addon.GetLegacyDashboardHost and addon.GetLegacyDashboardHost()
    if type(host.Pages) == "table" then
        for i = #host.Pages, 1, -1 do
            if host.Pages[i] == tab or host.Pages[i] == page then
                table.remove(host.Pages, i)
            end
        end
    end
    host.HardcoreAchievementsTab = tab
end

local function HookSelectPage(host)
    if not host or host._hcaSelectPageHooked or type(host.SelectPage) ~= "function" then
        return
    end
    host._hcaSelectPageHooked = true
    hooksecurefunc(host, "SelectPage", function(_, id)
        if addon._hcaShowingLegacyPage or addon._hcaRestoreAchievementsOnShow then
            return
        end
        HideAchievementsForTabSwitch()
    end)
end

local function GetSafeTabParent(host, lastTab)
    -- Parent to the Legacy frame so the tab hides with it. Never TabIndicators
    -- (that mixin lays out exactly 3 tabs) and never UIParent (orphan after close).
    local parent = lastTab and SafeCall(lastTab, "GetParent")
    if parent and parent ~= UIParent and parent ~= host.TabIndicators then
        local name = (parent.GetName and parent:GetName()) or ""
        if name ~= "TabIndicators" and not name:find("TabIndicator") then
            return parent
        end
    end
    return host
end

local function SyncModeTabVisibility()
    local host = GetHostFrame()
    if not modeTab then
        return
    end
    if host and SafeCall(host, "IsShown") then
        modeTab:Show()
    else
        modeTab:Hide()
        TrySetSelected(modeTab, false)
    end
end

local function AnchorModeTab(tab)
    local host = GetHostFrame()
    if not host or not tab then
        return
    end
    local lastTab = GetLastBlizzardTab(host)
    local parent = GetSafeTabParent(host, lastTab)
    tab:SetParent(parent)
    tab:ClearAllPoints()
    tab:SetFrameStrata(host:GetFrameStrata() or "MEDIUM")
    tab:SetFrameLevel((SafeCall(host, "GetFrameLevel") or 1) + 50)
    if lastTab then
        tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, 0)
        local w = SafeCall(lastTab, "GetWidth") or 32
        local h = SafeCall(lastTab, "GetHeight") or 32
        tab:SetSize(w, h)
        tab:SetFrameStrata(lastTab:GetFrameStrata())
        tab:SetFrameLevel((SafeCall(lastTab, "GetFrameLevel") or 1) + 2)
    else
        tab:SetPoint("TOPLEFT", host, "TOPRIGHT", 0, -96)
        tab:SetSize(32, 32)
    end
    ApplyAchievementIcon(tab)
    SyncModeTabVisibility()
    tab:SetAlpha(1)
    tab:EnableMouse(true)
end

function addon.CreateLegacyFrameModeTab()
    local host = GetHostFrame()
    if not host then
        return nil
    end

    if modeTab then
        UnregisterFromHost(host, modeTab)
        HookSelectPage(host)
        AnchorModeTab(modeTab)
        HookBlizzardTabs(host)
        return modeTab
    end

    local lastTab = GetLastBlizzardTab(host)
    local globalName = (host:GetName() or "LegacySystemFrame") .. "HardcoreAchievementsTab"

    local parent = GetSafeTabParent(host, lastTab)
    if lastTab then
        modeTab = CloneTab(lastTab, globalName, parent)
    else
        modeTab = CreateFrame("Frame", globalName, parent)
        modeTab:SetSize(32, 32)
        modeTab:EnableMouse(true)
        local icon = modeTab:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        modeTab.Icon = icon
    end

    modeTab._hcaLegacyTab = true
    modeTab._hcaModeTab = true
    ApplyAchievementIcon(modeTab)
    AnchorModeTab(modeTab)
    TrySetSelected(modeTab, false)
    UnregisterFromHost(host, modeTab)
    HookSelectPage(host)

    BindTabActivate(modeTab, function()
        if addon.ShowLegacyAchievementsPage then
            addon.ShowLegacyAchievementsPage()
        end
    end)
    SafeSetScript(modeTab, "OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ACHIEVEMENTS or "Achievements", 1, 1, 1)
        GameTooltip:Show()
    end)
    SafeSetScript(modeTab, "OnLeave", function()
        GameTooltip:Hide()
    end)

    HookBlizzardTabs(host)

    if not host._hcaLegacyTabHostHooked then
        host._hcaLegacyTabHostHooked = true
        host:HookScript("OnShow", function()
            addon.LayoutLegacyFrameModeTab()
        end)
        host:HookScript("OnHide", function()
            SyncModeTabVisibility()
        end)
    end

    addon.LegacyFrameModeTab = modeTab
    return modeTab
end

function addon.LayoutLegacyFrameModeTab()
    if not modeTab then
        return addon.CreateLegacyFrameModeTab()
    end
    AnchorModeTab(modeTab)
    HookBlizzardTabs(GetHostFrame())
    return modeTab
end

function addon.SelectLegacyFrameModeTab()
    if not modeTab then
        addon.CreateLegacyFrameModeTab()
    end
    local host = GetHostFrame()
    local tabs = GetBlizzardTabs(host)
    for i = 1, #tabs do
        TrySetSelected(tabs[i], false)
    end
    TrySetSelected(modeTab, true)
end

function addon.SetLegacyFrameModeTabSelected(selected)
    TrySetSelected(modeTab, selected)
end

function addon.SyncLegacyFrameModeTabVisibility()
    SyncModeTabVisibility()
end
