local addonName, addon = ...

-- =========================================================
-- Retail character-frame achievement panel layout (Forever)
--
-- The classic panel is built for the parchment CharacterFrame: 4-quadrant PaperDoll art, a 80px
-- title band, and 85px of bottom padding for the old tab row. On Forever's retail frame the 3D
-- paperdoll *is* the background, so hiding it leaves a hole; rows stay 310px; and UIPanelScrollBar
-- is the old classic widget. This file is TOC-gated to Forever; ApplyRetailAchievementPanelLayout
-- no-ops unless ModeTabs are actually shown. Classic-UI restorers have no character-frame tab.
-- =========================================================

local HEADER_HEIGHT = 36
local TOP_SHIFT = 10

local function HideClassicParchment(panel)
    if panel._hcaClassicParchment then
        for i = 1, #panel._hcaClassicParchment do
            panel._hcaClassicParchment[i]:Hide()
        end
    end
    if panel._hcaRetailCover then
        panel._hcaRetailCover:Hide()
    end
    if panel._hcaRetailClipFill then
        panel._hcaRetailClipFill:Hide()
    end
    if panel.BlurOverlayFrame then
        panel.BlurOverlayFrame:Hide()
    end
    if panel.BlurOverlay then
        panel.BlurOverlay:Hide()
    end
end

local function SetRetailTitle()
    if not CharacterFrame then
        return
    end
    local title = ACHIEVEMENTS or "Achievements"
    if CharacterFrame.SetTitle then
        pcall(CharacterFrame.SetTitle, CharacterFrame, title)
    end
    if CharacterFrame.TitleText then
        CharacterFrame.TitleText:SetText(title)
    end
    if CharacterFrameTitleText then
        CharacterFrameTitleText:SetText(title)
    end
    if CharacterFrame.TitleContainer and CharacterFrame.TitleContainer.TitleText then
        CharacterFrame.TitleContainer.TitleText:SetText(title)
    end
end

local collapsedListWidth
local collapsedFrameWidth
local progressPane
local pointsRefreshHooked
local applyingLayout = false

local DEFAULT_LIST_WIDTH = 400

local function GetRetailInset()
    if not CharacterFrame then
        return nil
    end
    return CharacterFrame.Inset
        or CharacterFrame.InsetFrame
        or CharacterFrameInset
        or CharacterFrame.InsetLeft
end

local function GetRightHost()
    if not CharacterFrame then
        return nil
    end
    return CharacterFrame.InsetRight or _G.CharacterFrameInsetRight
end

local function RememberCollapsedListWidth()
    local inset = GetRetailInset()
    local width = inset and inset.GetWidth and inset:GetWidth()
    if width and width >= 280 and width <= 520 then
        collapsedListWidth = width
    end
    local frameWidth = CharacterFrame and CharacterFrame.GetWidth and CharacterFrame:GetWidth()
    if frameWidth and frameWidth >= 300 and frameWidth <= 560 then
        collapsedFrameWidth = frameWidth
    end
end

local function GetPinnedListWidth()
    if collapsedListWidth then
        return collapsedListWidth
    end
    return DEFAULT_LIST_WIDTH
end

-- Forever does not always set CharacterFrame.Expanded. Treat the frame as expanded
-- when there is a real extra column: a wide inset, a shown InsetRight, or extra
-- frame width beyond the normal list.
local function IsCharacterFrameExpanded()
    if not CharacterFrame then
        return false
    end
    if CharacterFrame.Expanded == true then
        return true
    end
    local inset = GetRetailInset()
    local insetWidth = inset and inset.GetWidth and inset:GetWidth() or 0
    local listWidth = GetPinnedListWidth()
    if insetWidth > listWidth + 80 then
        return true
    end
    local right = GetRightHost()
    if right and right:IsShown() and (right:GetWidth() or 0) > 40 then
        return true
    end
    local frameWidth = CharacterFrame:GetWidth() or 0
    if collapsedFrameWidth and frameWidth > collapsedFrameWidth + 60 then
        return true
    end
    -- Left inset stayed normal-width and the extra column is empty frame chrome.
    if insetWidth > 200 and frameWidth > insetWidth + 160 then
        return true
    end
    return false
end

local function AnchorPanelToLeftPane(panel)
    local inset = GetRetailInset()
    local expanded = IsCharacterFrameExpanded()
    if not expanded then
        RememberCollapsedListWidth()
    end
    panel:ClearAllPoints()

    if inset then
        if expanded then
            -- Expanding only adds a right pane. Never let the list follow a grown inset.
            panel:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, TOP_SHIFT)
            panel:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 0, 0)
            panel:SetWidth(GetPinnedListWidth())
        else
            panel:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, TOP_SHIFT)
            panel:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
        end
    elseif CharacterFrame then
        panel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12, -48)
        if expanded then
            panel:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 12, 8)
            panel:SetWidth(GetPinnedListWidth())
        else
            panel:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -14, 8)
        end
    end
    if CharacterFrame then
        panel:SetFrameStrata(CharacterFrame:GetFrameStrata() or "MEDIUM")
        local insetLevel = inset and inset.GetFrameLevel and inset:GetFrameLevel() or (CharacterFrame:GetFrameLevel() or 1)
        panel:SetFrameLevel(insetLevel + 10)
    end
end

local function HideClassicScrollBar(scroll, keepBar)
    if not scroll then
        return
    end
    local named = scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"]
    local oldBar = scroll._hcaClassicScrollBar or named
    if not oldBar or oldBar == keepBar then
        return
    end
    oldBar:Hide()
    oldBar:SetAlpha(0)
    if oldBar.SetWidth then
        oldBar:SetWidth(1)
    end
    if oldBar.Disable then
        pcall(oldBar.Disable, oldBar)
    end
    local name = oldBar.GetName and oldBar:GetName()
    if name then
        local up = _G[name .. "ScrollUpButton"]
        local down = _G[name .. "ScrollDownButton"]
        if up then up:Hide() end
        if down then down:Hide() end
    end
    if oldBar.ScrollUpButton then
        oldBar.ScrollUpButton:Hide()
    end
    if oldBar.ScrollDownButton then
        oldBar.ScrollDownButton:Hide()
    end
    if oldBar.ThumbTexture then
        oldBar.ThumbTexture:Hide()
    end
    if oldBar.trackBG then
        oldBar.trackBG:Hide()
    end
    if oldBar.Background then
        oldBar.Background:Hide()
    end
    scroll._hcaClassicScrollBar = oldBar
end

local LIST_SCROLLBAR_WIDTH = 8

local function InitScrollBarCallbacks(bar)
    if not bar or bar.executingEvents then
        return
    end
    if CallbackRegistryMixin and type(CallbackRegistryMixin.OnLoad) == "function" then
        pcall(CallbackRegistryMixin.OnLoad, bar)
    end
    if type(bar.OnLoad) == "function" then
        pcall(bar.OnLoad, bar)
    end
end

local function CreateRetailScrollBar(panel)
    local templates = {
        "MinimalScrollBar",
        "MinimalScrollBarTemplate",
        "WowTrimScrollBar",
        "WowTrimScrollBarTemplate",
    }
    -- MinimalScrollBar's CallbackRegistry only initializes on EventFrame. Creating it as a
    -- Frame (TokenFrame.ScrollBar:GetObjectType() on Forever) leaves executingEvents nil.
    for i = 1, #templates do
        local ok, bar = pcall(CreateFrame, "EventFrame", nil, panel, templates[i])
        if ok and bar and (bar.Track or bar.SetScrollPercentage) then
            InitScrollBarCallbacks(bar)
            if bar.executingEvents or bar.SetScrollPercentage then
                return bar
            end
        end
    end

    -- Forever-safe MinimalScrollBar stand-in: thin track, no classic up/down buttons.
    local bar = CreateFrame("Slider", nil, panel)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(LIST_SCROLLBAR_WIDTH)
    bar:SetObeyStepOnDrag(true)
    bar:SetValueStep(1)
    bar:SetStepsPerPage(5)
    local regions = { bar:GetRegions() }
    for i = 1, #regions do
        if regions[i].SetColorTexture then
            regions[i]:SetColorTexture(0, 0, 0, 0)
        elseif regions[i].SetTexture then
            regions[i]:SetTexture(nil)
            regions[i]:SetAlpha(0)
        end
    end
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.78, 0.76, 0.72, 0.95)
    thumb:SetSize(3, 32)
    bar:SetThumbTexture(thumb)
    bar.Thumb = thumb
    return bar
end

local function WireScrollBar(scroll, bar)
    if not scroll or not bar then
        return
    end
    InitScrollBarCallbacks(bar)
    local canUseScrollUtil = bar.executingEvents and type(bar.SetScrollPercentage) == "function"
    if canUseScrollUtil and ScrollUtil and type(ScrollUtil.InitScrollFrameWithScrollBar) == "function" then
        pcall(ScrollUtil.InitScrollFrameWithScrollBar, scroll, bar)
    end
    if type(bar.SetHideIfUnscrollable) == "function" then
        pcall(bar.SetHideIfUnscrollable, bar, false)
    end
    if type(bar.SetVisibleAllowed) == "function" then
        pcall(bar.SetVisibleAllowed, bar, true)
    end
    if type(bar.Update) == "function" then
        pcall(bar.Update, bar)
    end
    if not bar._hcaWired and bar.SetMinMaxValues and not bar.SetScrollPercentage then
        bar._hcaWired = true
        bar:SetScript("OnValueChanged", function(self, value)
            if scroll.GetVerticalScroll and scroll:GetVerticalScroll() ~= value then
                scroll:SetVerticalScroll(value)
            end
        end)
        scroll:HookScript("OnVerticalScroll", function(_, offset)
            if bar.GetValue and bar:GetValue() ~= offset then
                bar:SetValue(offset)
            end
        end)
        scroll:HookScript("OnScrollRangeChanged", function(self, _, yRange)
            local max = yRange or (self.GetVerticalScrollRange and self:GetVerticalScrollRange()) or 0
            bar:SetMinMaxValues(0, max)
            bar:SetValue(self:GetVerticalScroll() or 0)
            bar:Show()
        end)
        local max = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0
        bar:SetMinMaxValues(0, max)
        bar:SetValue(scroll:GetVerticalScroll() or 0)
    end
end

local function ApplyRetailScrollBar(panel)
    local scroll = panel.Scroll
    if not scroll then
        return
    end
    local bar = panel._hcaRetailScrollBar
    if bar and bar.isScrollController and not bar.executingEvents then
        bar:Hide()
        panel._hcaRetailScrollBar = nil
        bar = nil
    end
    if not bar then
        bar = CreateRetailScrollBar(panel)
        if not bar then
            return
        end
        panel._hcaRetailScrollBar = bar
        scroll.ScrollBar = bar
    end
    HideClassicScrollBar(scroll, bar)

    bar:SetParent(panel)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -(HEADER_HEIGHT + 6))
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 8)
    if bar.SetWidth and not bar.Track and not bar.Back then
        bar:SetWidth(LIST_SCROLLBAR_WIDTH)
    end
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel((panel:GetFrameLevel() or 1) + 12)
    bar:Show()
    if bar.SetAlpha then
        bar:SetAlpha(1)
    end
    WireScrollBar(scroll, bar)
    scroll:SetFrameStrata("HIGH")
end

local function EnsureRetailHeader(panel)
    if panel._hcaRetailHeader then
        return panel._hcaRetailHeader
    end
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    header:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:SetFrameLevel(panel:GetFrameLevel() + 2)

    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)
    header.BG = bg

    panel._hcaRetailHeader = header
    return header
end

function addon.GetRetailAchievementRowLayout()
    if not (addon.HasCharacterFrameModeTabs and addon.HasCharacterFrameModeTabs()) then
        return nil
    end
    local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
    local scroll = panel and panel.Scroll
    local width = scroll and scroll:GetWidth()
    if (not width or width < 80) and panel then
        width = panel:GetWidth() - 28
    end
    if not width or width < 80 then
        return nil
    end
    return {
        rowWidth = width,
        borderWidth = width + 4,
        pointsOffset = -2,
        highlightRight = 0,
        subWidth = math.max(80, width - 90),
    }
end

local function LayoutRetailRows(panel)
    local layout = addon.GetRetailAchievementRowLayout()
    if not layout or not panel.achievements then
        return
    end
    for i = 1, #panel.achievements do
        local row = panel.achievements[i]
        row:SetWidth(layout.rowWidth)
        if row.Sub then
            row.Sub:SetWidth(layout.subWidth)
        end
        if row.PointsFrame then
            row.PointsFrame:ClearAllPoints()
            row.PointsFrame:SetPoint("RIGHT", row, "RIGHT", layout.pointsOffset, 0)
        end
        if row.Border and row:IsShown() then
            row.Border:SetSize(layout.borderWidth, 43)
        end
        if row.Background and row:IsShown() then
            row.Background:SetSize(layout.borderWidth, 43)
        end
        if row.highlight then
            row.highlight:ClearAllPoints()
            row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -4, 0)
            row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", layout.highlightRight, -1)
        end
    end
    if panel.Content and panel.Scroll then
        panel.Content:SetWidth(layout.rowWidth)
    end
end

local function GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function GetProgressSourceRows()
    local model = addon and addon.AchievementRowModel
    if type(model) == "table" and #model > 0 then
        return model
    end
    local panel = addon.AchievementPanel or _G.HardcoreAchievementsFrame
    if panel and type(panel.achievements) == "table" and #panel.achievements > 0 then
        return panel.achievements
    end
    return nil
end

local function DefMatchesCategory(def, key)
    if not def then
        return false
    end
    if key == "quest" then return def.isQuest == true end
    if key == "dungeon" then return def.isDungeon == true and def.isVariation ~= true end
    if key == "heroic_dungeon" then return def.isHeroicDungeon == true end
    if key == "raid" then return def.isRaid == true end
    if key == "profession" then return def.isProfession == true end
    if key == "meta" then return def.isMeta == true end
    if key == "reputation" then return def.isReputation == true end
    if key == "exploration" then return def.isExploration == true end
    if key == "secret" then return def.isSecret == true end
    if key == "guild" then return def.isGuildFirst == true end
    return false
end

local function StyleProgressBarLikeDashboard(bar)
    bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    if bar.Fill then
        bar.Fill:Hide()
    end
    if not bar.BG then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(0, 0, 0, 0.55)
        bar.BG = bg
    end
    if not bar.Border then
        local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
        local border = CreateFrame("Frame", nil, bar, backdropTemplate)
        border:SetAllPoints(bar)
        border:SetFrameLevel((bar:GetFrameLevel() or 1) + 2)
        if border.SetBackdrop then
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            border:SetBackdropBorderColor(0.282, 0.275, 0.259, 0.9)
            border:SetBackdropColor(0, 0, 0, 0)
        end
        bar.Border = border
    end
end

local function CreateProgressBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetHeight(18)
    StyleProgressBarLikeDashboard(bar)

    local left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    left:SetPoint("LEFT", bar, "LEFT", 8, 0)
    left:SetJustifyH("LEFT")
    left:SetTextColor(1, 1, 1)
    bar.LeftText = left

    local right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    right:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    right:SetJustifyH("RIGHT")
    right:SetTextColor(1, 1, 1)
    bar.RightText = right

    return bar
end

local function EnsureProgressPane(panel)
    if progressPane then
        if progressPane.Scroll then
            progressPane.Scroll:Hide()
        end
        if progressPane.ScrollBar then
            progressPane.ScrollBar:Hide()
        end
        if progressPane.Bars then
            for _, bar in pairs(progressPane.Bars) do
                bar:SetParent(progressPane)
            end
        end
        if progressPane.NoteText then
            progressPane.NoteText:SetParent(progressPane)
        end
        return progressPane
    end

    local pane = CreateFrame("Frame", "HardcoreAchievementsProgressPane", CharacterFrame or panel)
    pane:Hide()
    pane:EnableMouse(true)

    local header = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -6)
    header:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -12, -6)
    header:SetHeight(HEADER_HEIGHT)
    header:SetJustifyH("CENTER")
    header:SetJustifyV("MIDDLE")
    header:SetTextColor(0.922, 0.871, 0.761)
    header:SetText("Progress Overview")
    pane.Header = header

    pane.Bars = {
        all = CreateProgressBar(pane),
        quest = CreateProgressBar(pane),
        dungeon = CreateProgressBar(pane),
        heroic_dungeon = CreateProgressBar(pane),
        raid = CreateProgressBar(pane),
        profession = CreateProgressBar(pane),
        reputation = CreateProgressBar(pane),
        exploration = CreateProgressBar(pane),
        secret = CreateProgressBar(pane),
        guild = CreateProgressBar(pane),
    }

    local note = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetJustifyH("LEFT")
    note:SetJustifyV("TOP")
    note:SetWordWrap(true)
    note:SetTextColor(0.65, 0.65, 0.65, 1)
    note:SetText("Only core achievements count toward the total. Completed extras are added. Meta achievements are core.")
    pane.NoteText = note

    progressPane = pane
    return pane
end

local function CountCategory(key, srcRows, achievements)
    local completed, total = 0, 0
    if not srcRows then
        return completed, total
    end
    achievements = achievements or {}
    local hasSkillFn = addon.Profession and addon.Profession.PlayerHasSkill
    for i = 1, #srcRows do
        local row = srcRows[i]
        local def = row and row._def
        if def and DefMatchesCategory(def, key) then
            local achId = tostring(row.achId or row.id or def.achId or "")
            local rec = (achId ~= "" and achievements[achId]) or nil
            local isCompleted = (rec and rec.completed == true) or (row.completed == true)
            if key == "profession" then
                local hasSkill = false
                if type(hasSkillFn) == "function" and def.requireProfessionSkillID then
                    hasSkill = hasSkillFn(def.requireProfessionSkillID) == true
                end
                if hasSkill or isCompleted then
                    total = total + 1
                    if isCompleted then
                        completed = completed + 1
                    end
                end
            else
                total = total + 1
                if isCompleted then
                    completed = completed + 1
                end
            end
        end
    end
    return completed, total
end

local function CountCoreFallback(srcRows)
    local completed, total = 0, 0
    if not srcRows then
        return completed, total
    end
    for i = 1, #srcRows do
        local row = srcRows[i]
        if row then
            local hiddenByProfession = row.hiddenByProfession and not row.completed
            local hiddenUntilComplete = row.hiddenUntilComplete and not row.completed
            local def = row._def
            local exclude = def and (
                (def.isVariation and not row.completed)
                or (def.isDungeonSet and not row.completed)
                or (def.isReputation and not row.completed)
                or (def.isExploration and not row.completed)
                or (def.isRidiculous and not row.completed)
                or (def.isSecret and not row.completed)
                or (def.isGuildFirst and not row.completed)
                or def.excludeFromCount
            )
            if not hiddenByProfession and not hiddenUntilComplete and not exclude then
                total = total + 1
                if row.completed then
                    completed = completed + 1
                end
            end
        end
    end
    return completed, total
end

local function HasHeroicCategory(srcRows)
    if not srcRows then
        return false
    end
    for i = 1, #srcRows do
        local def = srcRows[i] and srcRows[i]._def
        if def and def.isHeroicDungeon then
            return true
        end
    end
    return false
end

local function UpdateProgressOverview(pane)
    if not pane or not pane.Bars then
        return
    end
    local srcRows = GetProgressSourceRows()
    local _, cdb
    if type(addon.GetCharDB) == "function" then
        _, cdb = addon.GetCharDB()
    end
    local achievements = (cdb and cdb.achievements) or {}
    local classR, classG, classB = GetPlayerClassColor()
    local showHeroic = HasHeroicCategory(srcRows)

    local function SetBar(key, label)
        local bar = pane.Bars[key]
        if not bar then
            return
        end
        local c, t
        if key == "all" then
            if addon.AchievementCount then
                c, t = addon.AchievementCount()
            else
                c, t = CountCoreFallback(srcRows)
            end
        else
            c, t = CountCategory(key, srcRows, achievements)
        end
        if t <= 0 and key ~= "all" and key ~= "profession" then
            bar:Hide()
            return
        end
        StyleProgressBarLikeDashboard(bar)
        bar:SetMinMaxValues(0, math.max(t, 1))
        bar:SetValue(math.min(c, t))
        bar:SetStatusBarColor(classR, classG, classB, 0.85)
        if bar.LeftText then
            bar.LeftText:SetText(label)
        end
        if bar.RightText then
            bar.RightText:SetText(string.format("%d/%d", c, t))
        end
        bar:Show()
    end

    if pane.Bars.heroic_dungeon then
        pane.Bars.heroic_dungeon:Hide()
    end

    SetBar("all", "Achievements Earned")
    SetBar("quest", "Quests")
    SetBar("dungeon", "Dungeon")
    if showHeroic then
        SetBar("heroic_dungeon", "Heroic Dungeon")
    end
    SetBar("raid", "Raid")
    SetBar("profession", "Profession")
    SetBar("reputation", "Reputation")
    SetBar("exploration", "Exploration")
    SetBar("secret", "Secret")
    SetBar("guild", "Guild")

    local pad = 16
    local BAR_H = 20
    local BAR_GAP = 8

    local allBar = pane.Bars.all
    allBar:ClearAllPoints()
    allBar:SetHeight(BAR_H)
    allBar:SetPoint("TOPLEFT", pane, "TOPLEFT", pad, -(HEADER_HEIGHT + 8))
    allBar:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -pad, -(HEADER_HEIGHT + 8))

    local order = { "quest", "dungeon" }
    if showHeroic and pane.Bars.heroic_dungeon and pane.Bars.heroic_dungeon:IsShown() then
        order[#order + 1] = "heroic_dungeon"
    end
    order[#order + 1] = "raid"
    order[#order + 1] = "profession"
    order[#order + 1] = "reputation"
    order[#order + 1] = "exploration"
    order[#order + 1] = "secret"
    order[#order + 1] = "guild"

    local index = 0
    for i = 1, #order do
        local bar = pane.Bars[order[i]]
        if bar and bar:IsShown() then
            index = index + 1
            bar:ClearAllPoints()
            bar:SetHeight(BAR_H)
            local y = -((BAR_H + BAR_GAP) * (index - 1) + HEADER_HEIGHT + 8 + BAR_H + 10)
            bar:SetPoint("TOPLEFT", pane, "TOPLEFT", pad, y)
            bar:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -pad, y)
        end
    end

    local barsH = BAR_H + 10 + (BAR_H * index) + (BAR_GAP * math.max(index - 1, 0))
    local note = pane.NoteText
    if note then
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", pane, "TOPLEFT", pad, -(HEADER_HEIGHT + 8 + barsH + 12))
        note:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -pad, -(HEADER_HEIGHT + 8 + barsH + 12))
        note:Show()
    end
end

function addon.HideRetailAchievementProgressPane()
    if progressPane then
        progressPane:Hide()
    end
end

local function LayoutProgressPane(panel)
    local pane = EnsureProgressPane(panel)
    if not panel or not panel:IsShown() or not IsCharacterFrameExpanded() then
        pane:Hide()
        return
    end

    pane:ClearAllPoints()
    pane:SetParent(CharacterFrame or panel)
    pane:SetFrameStrata("HIGH")
    pane:SetFrameLevel((panel:GetFrameLevel() or 1) + 20)

    -- Fill the extra column. InsetRight is the narrow paperdoll stats slot and must not
    -- be used as the width — that is why the bars were collapsing.
    pane:SetPoint("TOPLEFT", panel, "TOPRIGHT", 24, 0)
    pane:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 24, 0)
    local modeTabs = CharacterFrameModeTabs or (CharacterFrame and CharacterFrame.ModeTabs)
    if modeTabs then
        pane:SetPoint("RIGHT", modeTabs, "LEFT", -10, 0)
    else
        pane:SetPoint("RIGHT", CharacterFrame, "RIGHT", -48, 0)
    end

    if CharacterFrame and CharacterFrame.StatsPane then
        CharacterFrame.StatsPane:Hide()
    end
    if _G.CharacterStatsPane then
        _G.CharacterStatsPane:Hide()
    end
    pane:Show()
    UpdateProgressOverview(pane)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if pane:IsShown() then
                UpdateProgressOverview(pane)
            end
        end)
    end
end

local function HookProgressPointsRefresh()
    if pointsRefreshHooked or type(hooksecurefunc) ~= "function" then
        return
    end
    if type(addon.RefreshAllAchievementPoints) ~= "function" then
        return
    end
    pointsRefreshHooked = true
    hooksecurefunc(addon, "RefreshAllAchievementPoints", function()
        if progressPane and progressPane:IsShown() then
            UpdateProgressOverview(progressPane)
        end
    end)
end

function addon.ApplyRetailAchievementPanelLayout(panel)
    if not panel or not (addon.HasCharacterFrameModeTabs and addon.HasCharacterFrameModeTabs()) then
        return false
    end
    if applyingLayout then
        return true
    end
    applyingLayout = true

    HideClassicParchment(panel)

    AnchorPanelToLeftPane(panel)
    panel:SetClipsChildren(false)

    ApplyRetailScrollBar(panel)
    local header = EnsureRetailHeader(panel)
    header:SetFrameLevel(panel:GetFrameLevel() + 7)
    if header.BG then
        header.BG:SetColorTexture(0, 0, 0, 0)
    end

    if panel.Scroll then
        panel.Scroll:ClearAllPoints()
        panel.Scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(HEADER_HEIGHT + 2))
        panel.Scroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
        if panel._hcaRetailScrollBar then
            panel.Scroll:SetPoint("RIGHT", panel._hcaRetailScrollBar, "LEFT", -6, 0)
        else
            panel.Scroll:SetPoint("RIGHT", panel, "RIGHT", -(LIST_SCROLLBAR_WIDTH + 8), 0)
        end
        panel.Scroll:SetFrameStrata("HIGH")
    end

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    if panel.Scroll then
        header:SetPoint("RIGHT", panel.Scroll, "RIGHT", 4, 0)
    else
        header:SetPoint("RIGHT", panel, "RIGHT", -(LIST_SCROLLBAR_WIDTH + 4), 0)
    end
    header:SetHeight(HEADER_HEIGHT)

    if panel.SoloModeCheckbox then
        panel.SoloModeCheckbox:ClearAllPoints()
        panel.SoloModeCheckbox:SetPoint("LEFT", header, "LEFT", 2, -4)
        panel.SoloModeCheckbox:SetFrameLevel(header:GetFrameLevel() + 2)
    end
    if panel.SettingsButton and panel.SoloModeCheckbox then
        panel.SettingsButton:ClearAllPoints()
        panel.SettingsButton:SetPoint("LEFT", panel.SoloModeCheckbox.Text or panel.SoloModeCheckbox, "RIGHT", 8, 0)
        panel.SettingsButton:SetFrameLevel(header:GetFrameLevel() + 2)
    end
    if panel.DashboardButton and panel.SettingsButton then
        panel.DashboardButton:ClearAllPoints()
        panel.DashboardButton:SetPoint("LEFT", panel.SettingsButton, "RIGHT", 4, -2)
        panel.DashboardButton:SetFrameLevel(header:GetFrameLevel() + 2)
    end
    if panel.TotalPoints then
        panel.TotalPoints:SetParent(header)
        panel.TotalPoints:ClearAllPoints()
        panel.TotalPoints:SetPoint("TOP", header, "TOP", -10, -8)
        panel.TotalPoints:SetTextColor(0.6, 0.9, 0.6)
    end
    if panel.PointsLabelText then
        panel.PointsLabelText:SetParent(header)
        panel.PointsLabelText:SetTextColor(0.6, 0.9, 0.6)
    end
    if panel.CountsText then
        panel.CountsText:SetParent(header)
        panel.CountsText:ClearAllPoints()
        if panel.PointsLabelText then
            panel.CountsText:SetPoint("LEFT", panel.PointsLabelText, "RIGHT", 6, 0)
        else
            panel.CountsText:SetPoint("LEFT", panel.TotalPoints, "RIGHT", 18, 0)
        end
        panel.CountsText:SetTextColor(0.8, 0.8, 0.8)
    end
    if panel.MultiplierText then
        panel.MultiplierText:SetParent(header)
        panel.MultiplierText:ClearAllPoints()
        panel.MultiplierText:SetJustifyH("CENTER")
        if panel.TotalPoints and panel.CountsText then
            local anchor = header._hcaPointsCenter
            if not anchor then
                anchor = CreateFrame("Frame", nil, header)
                header._hcaPointsCenter = anchor
            end
            anchor:ClearAllPoints()
            anchor:SetPoint("LEFT", panel.TotalPoints, "LEFT", 0, 0)
            anchor:SetPoint("RIGHT", panel.CountsText, "RIGHT", 0, 0)
            anchor:SetHeight(1)
            panel.MultiplierText:SetPoint("BOTTOM", anchor, "TOP", 0, 20)
        elseif panel.TotalPoints then
            panel.MultiplierText:SetPoint("BOTTOM", panel.TotalPoints, "TOP", 0, 20)
        else
            panel.MultiplierText:SetPoint("TOP", header, "TOP", 0, 0)
        end
        panel.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
    end
    if panel.filterDropdown then
        panel.filterDropdown:ClearAllPoints()
        panel.filterDropdown:SetPoint("RIGHT", header, "RIGHT", 12, -4)
        panel.filterDropdown:SetFrameLevel(header:GetFrameLevel() + 2)
    end
    if panel.BorderClip and panel.Scroll then
        panel.BorderClip:ClearAllPoints()
        panel.BorderClip:SetPoint("TOPLEFT", panel.Scroll, "TOPLEFT", -4, 2)
        panel.BorderClip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 4)
    end

    LayoutRetailRows(panel)
    LayoutProgressPane(panel)
    HookProgressPointsRefresh()
    SetRetailTitle()
    if not panel._hcaProgressHideHooked then
        panel._hcaProgressHideHooked = true
        panel:HookScript("OnHide", function()
            addon.HideRetailAchievementProgressPane()
        end)
    end
    if not IsCharacterFrameExpanded() then
        local width = panel:GetWidth()
        if width and width >= 280 then
            collapsedListWidth = width
        end
    end
    applyingLayout = false
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if not panel:IsShown() then
                return
            end
            if not IsCharacterFrameExpanded() then
                RememberCollapsedListWidth()
                local width = panel:GetWidth()
                if width and width >= 280 then
                    collapsedListWidth = width
                end
            end
            AnchorPanelToLeftPane(panel)
            ApplyRetailScrollBar(panel)
            if panel.Scroll then
                panel.Scroll:ClearAllPoints()
                panel.Scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(HEADER_HEIGHT + 2))
                panel.Scroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
                if panel._hcaRetailScrollBar then
                    panel.Scroll:SetPoint("RIGHT", panel._hcaRetailScrollBar, "LEFT", -6, 0)
                else
                    panel.Scroll:SetPoint("RIGHT", panel, "RIGHT", -(LIST_SCROLLBAR_WIDTH + 8), 0)
                end
            end
            LayoutRetailRows(panel)
            LayoutProgressPane(panel)
            SetRetailTitle()
        end)
    end
    panel._hcaRetailLayout = true
    return true
end
