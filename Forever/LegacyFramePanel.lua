local addonName, addon = ...

-- =========================================================
-- Forever: achievements page inside LegacySystemFrame
--
-- A sibling page that fills the content area. The existing dashboard
-- (left tabs, right summary/leaderboard/rows) is hosted here.
-- Classic/TBC never load this file.
-- =========================================================

local LEGACY_ADDON = "Blizzard_LegacySystem"
local DEFAULT_TITLE = "Legacy Challenges"

local PAGE_FIELDS = {
    "ChallengesPage",
    "TreePage",
    "RewardTrackPage",
    "ProgressTrack",
    "ProgressPage",
}

local achievementsPage
local savedTitle
local showingPage
local wantAchievements

local function GetHostFrame()
    return _G.LegacySystemFrame or _G.LegacyChallengesFrame
end

local function TryLoadLegacyAddon()
    if GetHostFrame() then
        return true
    end
    -- Load on demand when the user opens HCA. Do not load at login.
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, LEGACY_ADDON)
    end
    if not GetHostFrame() and UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, LEGACY_ADDON)
    end
    if not GetHostFrame() and LoadAddOn then
        pcall(LoadAddOn, LEGACY_ADDON)
    end
    return GetHostFrame() ~= nil
end

function addon.HasLegacyChallengesHost()
    return GetHostFrame() ~= nil
end

function addon.GetLegacyDashboardHost()
    return achievementsPage
end

local function FrameName(frame)
    return (frame and frame.GetName and frame:GetName()) or ""
end

local function ForEachLegacyPage(frame, fn)
    if not frame then
        return
    end
    local seen = {}
    local function visit(page)
        if page and not seen[page] and page ~= achievementsPage then
            seen[page] = true
            fn(page)
        end
    end
    for i = 1, #PAGE_FIELDS do
        visit(frame[PAGE_FIELDS[i]])
    end
    if type(frame.Pages) == "table" then
        for i = 1, #frame.Pages do
            visit(frame.Pages[i])
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        local name = FrameName(child)
        if name:find("Page") or name:find("Track") or name:find("Tree") or name:find("Challenge") then
            if not name:find("NineSlice") and not name:find("ModeTab") and child ~= frame.ModeTabs then
                visit(child)
            end
        end
    end
end

local function IsChromeChild(frame, child)
    if not child then
        return true
    end
    if child == frame.NineSlice or child == frame.ModeTabs or child == frame.TabSystem
        or child == frame.Tabs or child == frame.TabIndicators or child == frame.CloseButton
        or child == frame.TitleContainer or child == frame.Bg or child == frame.Background
        or child == frame.LegacyChallengeTab or child == frame.LegacyTreeTab
        or child == frame.LegacyRewardTrackTab
        or child == addon.LegacyFrameModeTab or child == frame.HardcoreAchievementsTab then
        return true
    end
    local name = FrameName(child)
    if name:find("NineSlice") or name:find("ModeTab") or name:find("Close") or name:find("Title") then
        return true
    end
    return false
end

local function HideOtherPages(frame)
    ForEachLegacyPage(frame, function(page)
        page:Hide()
    end)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= achievementsPage and not IsChromeChild(frame, child) then
            local w, h = child:GetWidth() or 0, child:GetHeight() or 0
            if w > 80 and h > 80 then
                child:Hide()
            end
        end
    end
end

local function RestoreBlizzardContent(frame)
    if not frame then
        return
    end
    local current = frame.currentPage or frame.CurrentPage
    if current and current ~= achievementsPage and current.Show then
        current:Show()
        return
    end
    if frame.ChallengesPage then
        frame.ChallengesPage:Show()
    elseif frame.ProgressTrack then
        frame.ProgressTrack:Show()
    elseif frame.ProgressPage then
        frame.ProgressPage:Show()
    end
end

local function IsAnyBlizzardPageShown(frame)
    local shown = false
    ForEachLegacyPage(frame, function(page)
        if page:IsShown() then
            shown = true
        end
    end)
    return shown
end

local function RememberTitle(frame)
    if savedTitle or not frame then
        return
    end
    if frame.TitleText and frame.TitleText.GetText then
        savedTitle = frame.TitleText:GetText()
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then
        savedTitle = frame.TitleContainer.TitleText:GetText()
    end
    savedTitle = savedTitle or DEFAULT_TITLE
end

local function SetLegacyTitle(frame, title)
    if not frame then
        return
    end
    if frame.SetTitle then
        pcall(frame.SetTitle, frame, title)
    end
    if frame.TitleText then
        frame.TitleText:SetText(title)
    end
    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(title)
    end
end

local function EnsureAchievementsPage(frame)
    if not achievementsPage then
        achievementsPage = CreateFrame("Frame", "HardcoreAchievementsLegacyPage", frame)
        frame.HardcoreAchievementsPage = achievementsPage
        achievementsPage:Hide()
    end
    achievementsPage:SetFrameStrata(frame:GetFrameStrata())
    achievementsPage:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    achievementsPage:ClearAllPoints()
    achievementsPage:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    achievementsPage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    return achievementsPage
end

local function EmbedAndShowDashboard()
    if not addon.Dashboard then
        return
    end
    addon._hcaEmbeddingDashboard = true
    if addon.Dashboard.Show then
        addon.Dashboard:Show()
    end
    if addon.Dashboard.ApplyHostLayout then
        addon.Dashboard.ApplyHostLayout()
    end
    if addon.DashboardFrame then
        addon.DashboardFrame:Show()
    end
    if addon.Dashboard.Rebuild then
        addon.Dashboard:Rebuild()
    end
    addon._hcaEmbeddingDashboard = false
end

local function AssertAchievementsVisible()
    if not wantAchievements then
        return
    end
    local frame = GetHostFrame()
    if not frame or not frame:IsShown() then
        return
    end
    EnsureAchievementsPage(frame)
    HideOtherPages(frame)
    if achievementsPage then
        achievementsPage:Show()
    end
    if addon.SelectLegacyFrameModeTab then
        addon.SelectLegacyFrameModeTab()
    end
    if addon.DashboardFrame then
        addon.DashboardFrame:Show()
    end
end

local function InitializeLegacyHost()
    local frame = GetHostFrame()
    if not frame then
        return false
    end
    EnsureAchievementsPage(frame)
    if addon.CreateLegacyFrameModeTab then
        addon.CreateLegacyFrameModeTab()
    end
    if not frame._hcaLegacyHideHooked then
        frame:HookScript("OnHide", function()
            -- Remember HCA if it was the active page. Tearing it down here
            -- leaves Blizzard pages hidden, so Y-reopen would be blank.
            if wantAchievements then
                addon._hcaRestoreAchievementsOnShow = true
            end
        end)
        frame._hcaLegacyHideHooked = true
    end
    if not frame._hcaLegacyShowHooked then
        frame:HookScript("OnShow", function()
            if addon.CreateLegacyFrameModeTab then
                addon.CreateLegacyFrameModeTab()
            end
            if addon.LayoutLegacyFrameModeTab then
                addon.LayoutLegacyFrameModeTab()
            end
            local restoreHCA = wantAchievements or addon._hcaRestoreAchievementsOnShow
            local function afterShow()
                local host = GetHostFrame()
                if not host or not host:IsShown() then
                    addon._hcaRestoreAchievementsOnShow = false
                    return
                end
                if wantAchievements or addon._hcaRestoreAchievementsOnShow then
                    addon.ShowLegacyAchievementsPage()
                    addon._hcaRestoreAchievementsOnShow = false
                    return
                end
                addon._hcaRestoreAchievementsOnShow = false
                if not IsAnyBlizzardPageShown(host) then
                    RestoreBlizzardContent(host)
                end
            end
            if restoreHCA or not IsAnyBlizzardPageShown(frame) then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, afterShow)
                else
                    afterShow()
                end
            end
        end)
        frame._hcaLegacyShowHooked = true
    end
    return true
end

addon.TryInitLegacyChallengesHost = InitializeLegacyHost

function addon.ShowLegacyAchievementsPage()
    if showingPage then
        return true
    end
    showingPage = true
    addon._hcaShowingLegacyPage = true
    wantAchievements = true
    local ok = false
    TryLoadLegacyAddon()
    InitializeLegacyHost()
    local frame = GetHostFrame()
    if frame then
        if ShowUIPanel then
            ShowUIPanel(frame)
        else
            frame:Show()
        end
        EnsureAchievementsPage(frame)
        RememberTitle(frame)
        if addon.CreateLegacyFrameModeTab then
            addon.CreateLegacyFrameModeTab()
        end
        if addon.LayoutLegacyFrameModeTab then
            addon.LayoutLegacyFrameModeTab()
        end
        SetLegacyTitle(frame, ACHIEVEMENTS or "Achievements")
        AssertAchievementsVisible()
        EmbedAndShowDashboard()
        AssertAchievementsVisible()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if addon.LayoutLegacyFrameModeTab then
                    addon.LayoutLegacyFrameModeTab()
                end
                AssertAchievementsVisible()
            end)
        end
        ok = true
    end
    showingPage = false
    addon._hcaShowingLegacyPage = false
    return ok
end

function addon.HideLegacyAchievementsPage()
    if showingPage then
        return
    end
    wantAchievements = false
    addon._hcaRestoreAchievementsOnShow = false
    if achievementsPage then
        achievementsPage:Hide()
    end
    if addon.SetLegacyFrameModeTabSelected then
        addon.SetLegacyFrameModeTabSelected(false)
    end
    if addon.SyncLegacyFrameModeTabVisibility then
        addon.SyncLegacyFrameModeTabVisibility()
    end
    if addon.DashboardFrame then
        addon.DashboardFrame:Hide()
    end
    local frame = GetHostFrame()
    if frame then
        SetLegacyTitle(frame, savedTitle or DEFAULT_TITLE)
        -- Tab switch while open is handled by SelectPage. If HCA was torn down
        -- while the host is closed, unhide Blizzard's last page so Y is not blank.
        if not frame:IsShown() then
            RestoreBlizzardContent(frame)
        end
    end
end

function addon.ToggleLegacyAchievementsPage()
    TryLoadLegacyAddon()
    local frame = GetHostFrame()
    if not frame then
        return false
    end
    if frame:IsShown() and wantAchievements and achievementsPage and achievementsPage:IsShown() then
        if HideUIPanel then
            HideUIPanel(frame)
        else
            frame:Hide()
        end
        return true
    end
    return addon.ShowLegacyAchievementsPage()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded ~= addonName and loaded ~= LEGACY_ADDON then
        return
    end
    if not InitializeLegacyHost() and C_Timer and C_Timer.After then
        C_Timer.After(1, InitializeLegacyHost)
        C_Timer.After(5, InitializeLegacyHost)
    end
end)
