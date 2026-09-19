local addonName, addon = ...

-- =========================================================
-- Retail / Camelot character-frame mode tabs (Forever)
--
-- The classic character panel is a row of CharacterFrameTabN buttons along the bottom, driven by
-- PanelTemplates_SelectTab. Forever's retail character frame replaces that with CharacterFrameModeTabs,
-- a vertical icon strip (CharacterFrameModeTab1..N). PanelTemplates_* does not touch those buttons, and
-- PaperDollItemsFrame / CharacterModelScene are siblings of PaperDollFrame rather than children of it,
-- so hiding PaperDollFrame alone leaves the model and gear sitting under the achievements panel.
--
-- This file is loaded on Forever only. The retail ModeTabs crown is the only character-frame
-- achievements tab on this client. If the player is on a classic-UI restorer (ModeTabs hidden),
-- there is no character-frame tab — they use the dashboard. Classic/TBC never load this file.
-- HasCharacterFrameModeTabs() is the gate, not the TOC: ModeTabs remaining in the hierarchy
-- is not enough, restorers typically Hide() that strip.
-- =========================================================

addon.IsForeverCharacterUI = true

local MODE_TAB_TEMPLATE_CANDIDATES = {
    "CharacterFrameModeTabTemplate",
    "CharacterFrameModeTabButtonTemplate",
    "CharacterModeTabTemplate",
}

local PAPERDOLL_PIECES = {
    "PaperDollFrame",
    "PaperDollItemsFrame",
    "CharacterModelScene",
    "CharacterModelFrame",
}

local OTHER_SUBFRAMES = {
    "PetPaperDollFrame",
    "HonorFrame",
    "SkillFrame",
    "ReputationFrame",
    "PVPFrame",
    "TokenFrame",
    "StatisticsFrame",
    "CharacterStatsFrame",
    "TokenFrameContainer",
}

local hookedBlizzardModeTabs = {}
local modeTab
local selectedLook
local HookModeTabsVisibility

local function GetModeTabsParent()
    if CharacterFrameModeTabs then
        return CharacterFrameModeTabs
    end
    if CharacterFrame and CharacterFrame.ModeTabs then
        return CharacterFrame.ModeTabs
    end
    return nil
end

local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

-- True only when Forever's retail ModeTabs strip is actually shown.
function addon.HasCharacterFrameModeTabs()
    return IsFrameShown(GetModeTabsParent())
end

local function ForEachNamedModeTab(fn)
    for i = 1, 16 do
        local tab = _G["CharacterFrameModeTab" .. i]
        if tab then
            fn(tab, i)
        end
    end
end

local function GetLastBlizzardModeTab()
    local last, lastIndex
    ForEachNamedModeTab(function(tab, i)
        if tab ~= modeTab then
            last, lastIndex = tab, i
        end
    end)
    return last, lastIndex
end

local function CopyTextureLook(dst, src)
    if not dst or not src then
        return
    end
    local atlas = src.GetAtlas and src:GetAtlas()
    if type(atlas) == "string" and atlas ~= "" then
        dst:SetAtlas(atlas)
    else
        local tex = src.GetTexture and src:GetTexture()
        if tex then
            dst:SetTexture(tex)
        end
    end
    if src.GetTexCoord then
        pcall(function()
            dst:SetTexCoord(src:GetTexCoord())
        end)
    end
    if src.GetVertexColor then
        dst:SetVertexColor(src:GetVertexColor())
    end
    if src.GetBlendMode then
        local ok, mode = pcall(src.GetBlendMode, src)
        if ok and mode then
            dst:SetBlendMode(mode)
        end
    end
    dst:SetSize(src:GetWidth(), src:GetHeight())
    if src.IsDesaturated and dst.SetDesaturated then
        dst:SetDesaturated(src:IsDesaturated())
    end
    if src.IsShown and not src:IsShown() then
        dst:Hide()
    else
        dst:Show()
    end
end

local function CaptureTextureLook(tex)
    if not tex then
        return nil
    end
    local look = {
        atlas = tex.GetAtlas and tex:GetAtlas() or nil,
        texture = tex.GetTexture and tex:GetTexture() or nil,
        width = tex.GetWidth and tex:GetWidth() or 0,
        height = tex.GetHeight and tex:GetHeight() or 0,
    }
    if tex.GetTexCoord then
        look.texCoord = { tex:GetTexCoord() }
    end
    if type(look.atlas) ~= "string" or look.atlas == "" then
        look.atlas = nil
    end
    if not look.atlas and not look.texture then
        return nil
    end
    return look
end

local function ApplyCapturedLook(dst, look, parent)
    if not dst or not look then
        return
    end
    if look.atlas then
        dst:SetAtlas(look.atlas)
    elseif look.texture then
        dst:SetTexture(look.texture)
    end
    if look.texCoord then
        pcall(function()
            dst:SetTexCoord(unpack(look.texCoord))
        end)
    end
    if look.width and look.width > 0 and look.height and look.height > 0 then
        dst:SetSize(look.width, look.height)
    elseif parent then
        dst:SetAllPoints(parent)
    end
end

local function SnapshotSelectedLook()
    ForEachNamedModeTab(function(tab)
        if tab == modeTab then
            return
        end
        if tab.SelectedTexture and tab.SelectedTexture:IsShown() then
            local selected = CaptureTextureLook(tab.SelectedTexture)
            if selected then
                selectedLook = selectedLook or {}
                selectedLook.selected = selected
                selectedLook.glow = CaptureTextureLook(tab.TabGlow)
            end
        end
    end)
end

local function EnsureSelectedRegions(tab)
    if not tab then
        return
    end
    if not tab.SelectedTexture then
        tab.SelectedTexture = tab:CreateTexture(nil, "OVERLAY")
        tab.SelectedTexture:SetAllPoints(tab)
        tab.SelectedTexture:SetBlendMode("ADD")
        tab.SelectedTexture:SetColorTexture(1, 0.82, 0.2, 0.35)
        tab.SelectedTexture:Hide()
    end
    if not tab.TabGlow then
        tab.TabGlow = tab:CreateTexture(nil, "OVERLAY")
        tab.TabGlow:SetAllPoints(tab)
        tab.TabGlow:SetBlendMode("ADD")
        tab.TabGlow:SetColorTexture(1, 0.9, 0.4, 0.22)
        tab.TabGlow:Hide()
    end
end

local function TextureHasContent(tex)
    if not tex then
        return false
    end
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if type(atlas) == "string" and atlas ~= "" then
        return true
    end
    local texture = tex.GetTexture and tex:GetTexture()
    return texture ~= nil and texture ~= ""
end

local function ApplySelectedLookToTab(tab)
    EnsureSelectedRegions(tab)
    if selectedLook and selectedLook.selected then
        ApplyCapturedLook(tab.SelectedTexture, selectedLook.selected, tab)
        if selectedLook.glow and tab.TabGlow then
            ApplyCapturedLook(tab.TabGlow, selectedLook.glow, tab)
        end
    elseif tab.SelectedTexture and not TextureHasContent(tab.SelectedTexture) then
        tab.SelectedTexture:SetBlendMode("ADD")
        tab.SelectedTexture:SetColorTexture(1, 0.82, 0.2, 0.4)
        tab.SelectedTexture:SetAllPoints(tab)
    end
end

local function CopyAllPoints(dst, src, srcParent, dstParent)
    dst:ClearAllPoints()
    local n = src:GetNumPoints() or 0
    if n == 0 then
        dst:SetAllPoints(dstParent)
        return
    end
    for i = 1, n do
        local point, rel, relPoint, x, y = src:GetPoint(i)
        if rel == nil or rel == srcParent then
            rel = dstParent
        end
        dst:SetPoint(point, rel, relPoint, x, y)
    end
end

local function TrySetSelected(tab, selected)
    if not tab then
        return
    end
    for _, key in ipairs({ "SetSelected", "SetTabSelected", "SetChecked" }) do
        if type(tab[key]) == "function" then
            pcall(tab[key], tab, selected)
        end
    end
    -- Mixin SetSelected can succeed without changing the textures when the tab is not in
    -- Blizzard's own tab system, so the regions below are the real selected indicator.
    tab.isSelected = selected and true or false
    tab.selected = tab.isSelected
    if type(tab.UpdateVisuals) == "function" then
        pcall(tab.UpdateVisuals, tab)
    elseif type(tab.UpdateButtonVisuals) == "function" then
        pcall(tab.UpdateButtonVisuals, tab)
    end
    if tab.TabGlow then
        tab.TabGlow:SetShown(selected)
    end
    if tab.SelectedTexture then
        local w = tab.SelectedTexture.GetWidth and tab.SelectedTexture:GetWidth()
        if not w or w == 0 then
            tab.SelectedTexture:SetAllPoints(tab)
        end
        tab.SelectedTexture:SetShown(selected)
    end
    if tab.TabGlowAnimation then
        if selected then
            pcall(tab.TabGlowAnimation.Play, tab.TabGlowAnimation)
        else
            pcall(tab.TabGlowAnimation.Stop, tab.TabGlowAnimation)
        end
    end
    if tab.Border then
        -- Classic-style leftover; ignore if the region is a mask-only piece.
        if tab.Border.SetShown then
            tab.Border:SetShown(selected)
        end
    end
end

function addon.SetCharacterFrameModeTabSelected(tab, selected)
    TrySetSelected(tab, selected)
end

function addon.DeselectOtherCharacterFrameModeTabs(keep)
    ForEachNamedModeTab(function(tab)
        if tab ~= keep then
            TrySetSelected(tab, false)
        end
    end)
    local parent = GetModeTabsParent()
    if parent then
        for _, tab in ipairs({ parent:GetChildren() }) do
            if tab ~= keep and tab.SelectedTexture then
                TrySetSelected(tab, false)
            end
        end
    end
end

local function CloneModeTab(source, name, parent)
    local tab = CreateFrame("Button", name, parent)
    tab:SetSize(source:GetSize())
    tab:SetFrameStrata(source:GetFrameStrata())
    tab:SetFrameLevel(source:GetFrameLevel())

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
        tab:SetHighlightTexture(tab.HighlightTexture)
    end

    if source.Icon then
        tab.Icon = tab:CreateTexture(nil, "ARTWORK")
        CopyTextureLook(tab.Icon, source.Icon)
        CopyAllPoints(tab.Icon, source.Icon, source, tab)
    end

    if source.Mask then
        tab.Mask = tab:CreateMaskTexture()
        CopyTextureLook(tab.Mask, source.Mask)
        CopyAllPoints(tab.Mask, source.Mask, source, tab)
        if tab.Icon then
            tab.Icon:AddMaskTexture(tab.Mask)
        end
    end

    if source.TabGlow then
        tab.TabGlow = tab:CreateTexture(nil, "OVERLAY")
        CopyTextureLook(tab.TabGlow, source.TabGlow)
        CopyAllPoints(tab.TabGlow, source.TabGlow, source, tab)
        tab.TabGlow:Hide()
    end

    if source.SelectedTexture then
        tab.SelectedTexture = tab:CreateTexture(nil, "OVERLAY")
        CopyTextureLook(tab.SelectedTexture, source.SelectedTexture)
        CopyAllPoints(tab.SelectedTexture, source.SelectedTexture, source, tab)
        tab.SelectedTexture:Hide()
    end

    return tab
end

local function HideNamedFrames(names)
    for i = 1, #names do
        local frame = _G[names[i]]
        if frame and frame.Hide and frame:IsShown() then
            frame:Hide()
        end
    end
end

local function AchievementsAreShowing()
    local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
    if panel and panel:IsShown() then
        return true
    end
    return CharacterFrame and CharacterFrame.activeSubframe == "HardcoreAchievementsFrame"
end

local function HookKeepDeselectedWhileAchievements(tab)
    if not tab or tab == modeTab or tab._hcaKeepDeselectedHooked then
        return
    end
    tab._hcaKeepDeselectedHooked = true
    local function forceOff(self)
        if not AchievementsAreShowing() then
            return
        end
        self.isSelected = false
        self.selected = false
        if self.SelectedTexture then
            self.SelectedTexture:Hide()
        end
        if self.TabGlow then
            self.TabGlow:Hide()
        end
        if self.TabGlowAnimation then
            pcall(self.TabGlowAnimation.Stop, self.TabGlowAnimation)
        end
    end
    if type(tab.SetSelected) == "function" then
        hooksecurefunc(tab, "SetSelected", function(self, selected)
            if selected then
                forceOff(self)
            end
        end)
    end
    if type(tab.UpdateVisuals) == "function" then
        hooksecurefunc(tab, "UpdateVisuals", forceOff)
    elseif type(tab.UpdateButtonVisuals) == "function" then
        hooksecurefunc(tab, "UpdateButtonVisuals", forceOff)
    end
end

local MODEL_OBJECT_TYPES = {
    ModelScene = true,
    PlayerModel = true,
    DressUpModel = true,
    CinematicModel = true,
    Model = true,
}

local function HideModelFrame(frame)
    if not frame then
        return
    end
    if frame.Hide then
        frame:Hide()
    end
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
end

local function HookModelStayHidden(frame)
    if not frame or frame._hcaHideWhileAchievements then
        return
    end
    frame._hcaHideWhileAchievements = true
    if frame.HookScript then
        pcall(frame.HookScript, frame, "OnShow", function(self)
            local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
            if panel and panel:IsShown() then
                self:Hide()
                if self.SetAlpha then
                    self:SetAlpha(0)
                end
            end
        end)
    end
end

local function HideCharacterFrameModels()
    local function consider(frame)
        if not frame or not frame.GetObjectType then
            return
        end
        local objectType = frame:GetObjectType()
        local name = frame.GetName and frame:GetName() or ""
        if MODEL_OBJECT_TYPES[objectType] or (type(name) == "string" and name:find("ModelScene", 1, true)) then
            HideModelFrame(frame)
            HookModelStayHidden(frame)
        end
    end
    consider(_G.CharacterModelScene)
    consider(_G.CharacterModelFrame)
    if CharacterFrame then
        consider(CharacterFrame.ModelScene)
        local children = { CharacterFrame:GetChildren() }
        for i = 1, #children do
            consider(children[i])
            if children[i].GetChildren then
                local grand = { children[i]:GetChildren() }
                for j = 1, #grand do
                    consider(grand[j])
                end
            end
        end
    end
end

local EXPANDED_PAPERDOLL_CHROME = {
    "CharacterStatsPane",
    "PaperDollSidebarTabs",
    "PaperDollSidebarTab1",
    "PaperDollSidebarTab2",
    "PaperDollSidebarTab3",
    "PaperDollSidebarTab4",
}

local function HideExpandedPaperdollChrome()
    if not CharacterFrame then
        return
    end

    local function hideAndKeepDown(frame)
        if not frame then
            return
        end
        if frame.Hide then
            frame:Hide()
        end
        HookModelStayHidden(frame)
    end

    hideAndKeepDown(CharacterFrame.StatsPane)
    hideAndKeepDown(_G.CharacterStatsPane)
    hideAndKeepDown(CharacterFrame.SidebarTabs)
    hideAndKeepDown(PaperDollFrame and PaperDollFrame.SidebarTabs)

    HideNamedFrames(EXPANDED_PAPERDOLL_CHROME)

    if type(GetPaperDollSideBarFrame) == "function" then
        local count = type(PAPERDOLL_SIDEBARS) == "table" and #PAPERDOLL_SIDEBARS or 8
        for i = 1, count do
            hideAndKeepDown(GetPaperDollSideBarFrame(i))
        end
    end

    if PaperDollFrame and PaperDollFrame.currentSideBar then
        hideAndKeepDown(PaperDollFrame.currentSideBar)
    end

    -- Sidebar tab buttons sit between the inset and ModeTabs on the expanded paperdoll.
    -- InsetRight stays up: that is the extra section other tabs get when the frame expands.
    local children = { CharacterFrame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        local name = child.GetName and child:GetName() or ""
        if type(name) == "string" and (
            name:find("Sidebar", 1, true)
            or name:find("StatsPane", 1, true)
        ) then
            hideAndKeepDown(child)
        end
    end
end

function addon.HideRetailCharacterFrameContents()
    HideNamedFrames(PAPERDOLL_PIECES)
    HideNamedFrames(OTHER_SUBFRAMES)
    HideCharacterFrameModels()
    HideExpandedPaperdollChrome()
    -- LeftPaneHost / Inset stay up: they are the shared dark background Currency and Reputation use.
    if CharacterFrame and CharacterFrame.LeftPaneHost then
        CharacterFrame.LeftPaneHost:Show()
        if CharacterFrame.LeftPaneHost.SetAlpha then
            CharacterFrame.LeftPaneHost:SetAlpha(1)
        end
    end
end

-- PaperDoll stays CharacterFrame.activeSubframe unless we change it, so ModeTab1 (character)
-- keeps its selected glow even after SetSelected(false). ShowSubFrame with an unknown name
-- hides the Blizzard subframes without selecting one of them.
function addon.ActivateRetailAchievementSubFrame()
    if not CharacterFrame then
        return
    end
    if type(CharacterFrame.ShowSubFrame) == "function" then
        pcall(CharacterFrame.ShowSubFrame, CharacterFrame, "HardcoreAchievementsFrame")
    end
    -- Size like Currency so the left inset is the full-height list, not the paperdoll viewport.
    -- Leave Expanded alone: the extra right section is used for the progress overview.
    CharacterFrame.activeSubframe = "TokenFrame"
    if type(CharacterFrame.UpdateSize) == "function" then
        pcall(CharacterFrame.UpdateSize, CharacterFrame)
    end
    if TokenFrame then
        TokenFrame:Hide()
    end
    CharacterFrame.activeSubframe = "HardcoreAchievementsFrame"
    if type(CharacterFrame.UpdatePortrait) == "function" then
        pcall(CharacterFrame.UpdatePortrait, CharacterFrame)
    end
end

local restoringPaperdoll = false

function addon.RestoreRetailCharacterFrameContents()
    local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
    if panel and panel:IsShown() then
        return
    end
    if restoringPaperdoll then
        return
    end
    restoringPaperdoll = true
    for i = 1, #PAPERDOLL_PIECES do
        local frame = _G[PAPERDOLL_PIECES[i]]
        if frame and frame.Show then
            frame:Show()
            if frame.SetAlpha then
                frame:SetAlpha(1)
            end
        end
    end
    if CharacterFrame then
        if CharacterFrame.ModelScene then
            CharacterFrame.ModelScene:Show()
            CharacterFrame.ModelScene:SetAlpha(1)
        end
        if CharacterFrame.LeftPaneHost then
            CharacterFrame.LeftPaneHost:Show()
            CharacterFrame.LeftPaneHost:SetAlpha(1)
        end
    end
    restoringPaperdoll = false
end

local function HideAchievementsForTabSwitch()
    local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
    if not (panel and panel:IsShown()) then
        return
    end
    panel._suppressOnHide = true
    panel:Hide()
    if addon.HideRetailAchievementProgressPane then
        addon.HideRetailAchievementProgressPane()
    end
    if modeTab then
        TrySetSelected(modeTab, false)
    end
end

-- These tabs are Frames (SharedUIPanelTemplates), not Buttons. Frames have OnMouseUp
-- and no OnClick; HookScript("OnClick") raises and used to abort tab creation, which
-- left the achievements button with no activate handler at all.
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

function addon.SetCharacterFrameModeTabOnActivate(tab, handler)
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

local function HookBlizzardModeTab(tab)
    if not tab or hookedBlizzardModeTabs[tab] then
        return
    end
    hookedBlizzardModeTabs[tab] = true
    local function onActivate()
        HideAchievementsForTabSwitch()
    end
    if not SafeHookScript(tab, "OnClick", onActivate) then
        SafeHookScript(tab, "OnMouseUp", onActivate)
    end
    if type(tab.OnClick) == "function" then
        pcall(hooksecurefunc, tab, "OnClick", onActivate)
    end
end

local function HookBlizzardModeTabs()
    ForEachNamedModeTab(function(tab)
        if tab ~= modeTab then
            HookBlizzardModeTab(tab)
            HookKeepDeselectedWhileAchievements(tab)
        end
    end)
    local parent = GetModeTabsParent()
    if parent then
        for _, tab in ipairs({ parent:GetChildren() }) do
            if tab ~= modeTab and tab.HookScript then
                HookBlizzardModeTab(tab)
            end
        end
    end
end

local function HookSubFrameShows()
    if CharacterFrame and type(CharacterFrame.ShowSubFrame) == "function" and not CharacterFrame._hcaShowSubFrameHooked then
        hooksecurefunc(CharacterFrame, "ShowSubFrame", function(_, frameName)
            if frameName ~= "HardcoreAchievementsFrame" then
                HideAchievementsForTabSwitch()
                if frameName == "PaperDollFrame" then
                    addon.RestoreRetailCharacterFrameContents()
                else
                    HideExpandedPaperdollChrome()
                end
            end
        end)
        CharacterFrame._hcaShowSubFrameHooked = true
    end

    local function onPaperdollShown()
        HideAchievementsForTabSwitch()
        addon.RestoreRetailCharacterFrameContents()
    end

    local function onOtherShown()
        HideAchievementsForTabSwitch()
        -- Do not Show CharacterStatsPane here. Restore used to, which is why Item Level /
        -- Attributes sat on Currency and Statistics after visiting this tab.
        HideExpandedPaperdollChrome()
    end

    for _, name in ipairs({ "PaperDollFrame", "PaperDollItemsFrame" }) do
        local frame = _G[name]
        if frame and not frame._hcaAchievementsHideHooked then
            frame:HookScript("OnShow", onPaperdollShown)
            frame._hcaAchievementsHideHooked = true
        end
    end
    for _, name in ipairs({ "ReputationFrame", "TokenFrame", "SkillFrame", "HonorFrame" }) do
        local frame = _G[name]
        if frame and not frame._hcaAchievementsHideHooked then
            frame:HookScript("OnShow", onOtherShown)
            frame._hcaAchievementsHideHooked = true
        end
    end

    if CharacterFrame and not CharacterFrame._hcaAchievementSizeHooked then
        CharacterFrame._hcaAchievementSizeHooked = true
        local function relayoutExpandedPane()
            local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
            if panel and panel:IsShown() and addon.ApplyRetailAchievementPanelLayout then
                HideExpandedPaperdollChrome()
                addon.ApplyRetailAchievementPanelLayout(panel)
            elseif addon.HideRetailAchievementProgressPane then
                addon.HideRetailAchievementProgressPane()
            end
        end
        CharacterFrame:HookScript("OnSizeChanged", relayoutExpandedPane)
        if type(CharacterFrame.Expand) == "function" then
            hooksecurefunc(CharacterFrame, "Expand", relayoutExpandedPane)
        end
        if type(CharacterFrame.Collapse) == "function" then
            hooksecurefunc(CharacterFrame, "Collapse", relayoutExpandedPane)
        end
        if type(CharacterFrame.UpdateSize) == "function" then
            hooksecurefunc(CharacterFrame, "UpdateSize", relayoutExpandedPane)
        end
    end
end

local function ApplyAchievementIcon(tab)
    local icon = tab.Icon or tab.icon
    if not icon then
        icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(20, 20)
        tab.Icon = icon
    end
    icon:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png")
    if tab.Mask and icon.AddMaskTexture then
        icon:AddMaskTexture(tab.Mask)
    end
end

local function AnchorModeTab(tab)
    local lastTab = GetLastBlizzardModeTab()
    local parent = GetModeTabsParent()
    tab:ClearAllPoints()
    if lastTab then
        tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, 0)
        tab:SetSize(lastTab:GetSize())
    elseif parent then
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    elseif CharacterFrame then
        tab:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 4, -72)
    end
end

function addon.CreateCharacterFrameModeTab(name)
    if modeTab then
        return modeTab
    end

    local parent = GetModeTabsParent() or CharacterFrame or UIParent
    local lastTab, lastIndex = GetLastBlizzardModeTab()
    local globalName = lastIndex and ("CharacterFrameModeTab" .. (lastIndex + 1)) or name

    local template = addon.ResolveTemplate and addon.ResolveTemplate(
        MODE_TAB_TEMPLATE_CANDIDATES[1], MODE_TAB_TEMPLATE_CANDIDATES[2], MODE_TAB_TEMPLATE_CANDIDATES[3])
    if template then
        local ok, created = pcall(CreateFrame, "Button", globalName, parent, template)
        if ok and created then
            modeTab = created
        end
    end

    if not modeTab and lastTab then
        modeTab = CloneModeTab(lastTab, globalName, parent)
    end

    if not modeTab then
        modeTab = CreateFrame("Button", globalName, parent)
        modeTab:SetSize(32, 32)
        local icon = modeTab:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        modeTab.Icon = icon
    end

    modeTab._hcaModeTab = true
    ApplyAchievementIcon(modeTab)
    AnchorModeTab(modeTab)
    SnapshotSelectedLook()
    ApplySelectedLookToTab(modeTab)
    TrySetSelected(modeTab, false)

    if lastTab then
        modeTab:SetFrameStrata(lastTab:GetFrameStrata())
        modeTab:SetFrameLevel(lastTab:GetFrameLevel() + 1)
    elseif parent.GetFrameLevel then
        modeTab:SetFrameLevel(parent:GetFrameLevel() + 10)
    end

    modeTab:EnableMouse(true)
    pcall(function()
        modeTab:RegisterForClicks("LeftButtonUp")
    end)
    SafeSetScript(modeTab, "OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ACHIEVEMENTS or "Achievements", 1, 1, 1)
        GameTooltip:Show()
    end)
    SafeSetScript(modeTab, "OnLeave", function()
        GameTooltip:Hide()
    end)
    -- Look up ShowAchievementTab at click time: this file loads before HardcoreAchievements.lua.
    addon.SetCharacterFrameModeTabOnActivate(modeTab, function()
        if type(addon.ShowAchievementTab) == "function" then
            addon.ShowAchievementTab()
        end
    end)

    HookBlizzardModeTabs()
    HookSubFrameShows()

    if CharacterFrame and not CharacterFrame._hcaModeTabShowHooked then
        CharacterFrame:HookScript("OnShow", function()
            SnapshotSelectedLook()
            if modeTab then
                ApplySelectedLookToTab(modeTab)
            end
        end)
        CharacterFrame._hcaModeTabShowHooked = true
    end

    HookModeTabsVisibility()

    addon.CharacterFrameModeTab = modeTab
    return modeTab
end

function addon.LayoutCharacterFrameModeTab()
    if not addon.HasCharacterFrameModeTabs() then
        if modeTab then
            modeTab:Hide()
            modeTab:EnableMouse(false)
        end
        return false
    end

    if not modeTab then
        addon.CreateCharacterFrameModeTab((addonName or "HardcoreAchievements") .. "ModeTab")
    end
    if not modeTab then
        return false
    end

    local _, cdb = addon.GetCharDB and addon.GetCharDB()
    local useCharacterPanel = true
    if cdb and cdb.settings and cdb.settings.useCharacterPanel ~= nil then
        useCharacterPanel = cdb.settings.useCharacterPanel
    end
    if not useCharacterPanel then
        modeTab:Hide()
        modeTab:EnableMouse(false)
        return true
    end

    AnchorModeTab(modeTab)
    HookBlizzardModeTabs()
    HookSubFrameShows()
    if CharacterFrame and CharacterFrame:IsShown() then
        modeTab:Show()
        modeTab:EnableMouse(true)
    else
        modeTab:Hide()
    end
    return true
end

function addon.SelectCharacterFrameModeTab(tab)
    -- The selected atlas lives on whichever Blizzard tab is currently lit. Copy it before
    -- we turn those off, or our clone has a blank SelectedTexture and never looks active.
    SnapshotSelectedLook()
    if tab and tab.SelectedTexture then
        ForEachNamedModeTab(function(other)
            if other ~= tab and other.SelectedTexture and other.SelectedTexture:IsShown() then
                CopyTextureLook(tab.SelectedTexture, other.SelectedTexture)
                CopyAllPoints(tab.SelectedTexture, other.SelectedTexture, other, tab)
            end
        end)
    end
    addon.ActivateRetailAchievementSubFrame()
    addon.DeselectOtherCharacterFrameModeTabs(tab)
    local parent = GetModeTabsParent()
    if parent then
        parent.selectedTab = tab
        parent.currentTab = tab
        if type(parent.SetSelectedTab) == "function" then
            pcall(parent.SetSelectedTab, parent, tab)
        elseif type(parent.SetSelected) == "function" then
            pcall(parent.SetSelected, parent, tab)
        end
    end
    if tab then
        tab.frameName = "HardcoreAchievementsFrame"
    end
    TrySetSelected(tab, true)
    -- Mixin SetSelected may clear our textures because this tab is not in Blizzard's tab list.
    ApplySelectedLookToTab(tab)
    if tab and tab.SelectedTexture then
        tab.SelectedTexture:Show()
    end
    if tab and tab.TabGlow then
        tab.TabGlow:Show()
    end
    addon.HideRetailCharacterFrameContents()
    -- Character tab (ModeTab1) re-applies selected from activeSubframe; do this after that update.
    ForEachNamedModeTab(function(other)
        if other ~= tab then
            TrySetSelected(other, false)
            HookKeepDeselectedWhileAchievements(other)
        end
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            addon.HideRetailCharacterFrameContents()
            ForEachNamedModeTab(function(other)
                if other ~= tab then
                    TrySetSelected(other, false)
                end
            end)
        end)
    end
end

local function SyncTabChromeFromModeTabsVisibility()
    if type(addon.LoadTabPosition) == "function" then
        addon.LoadTabPosition()
    end
end

function HookModeTabsVisibility()
    local parent = GetModeTabsParent()
    if not parent or parent._hcaModeTabsVisHooked then
        return
    end
    parent._hcaModeTabsVisHooked = true
    parent:HookScript("OnHide", SyncTabChromeFromModeTabsVisibility)
    parent:HookScript("OnShow", SyncTabChromeFromModeTabsVisibility)
end

HookModeTabsVisibility()
