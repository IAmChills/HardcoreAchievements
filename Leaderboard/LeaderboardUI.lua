local addonName, addon = ...
if not addon then return end

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

local UI = Leaderboard.UI or {}
Leaderboard.UI = UI

local C_PartyInfo = C_PartyInfo
local ChatFrame_OpenChat = ChatFrame_OpenChat
local CloseDropDownMenus = CloseDropDownMenus
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetGuildInfo = GetGuildInfo
local GetRealmName = GetRealmName
local InviteUnit = InviteUnit
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local ToggleDropDownMenu = ToggleDropDownMenu
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIParent = UIParent
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitName = UnitName
local UISpecialFrames = UISpecialFrames
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_format = string.format
local table_insert = table.insert

local FRAME_WIDTH = 900
local FRAME_HEIGHT = 420
local ROW_HEIGHT = 20
local OFFLINE_COLOR = { 0.65, 0.65, 0.65 }
local GUILD_MEMBER_COLOR = { 0.4, 0.8, 0.4 }
local DEAD_COLOR = { 0.95, 0.26, 0.21 }
local WHITE_VALUE = "|cffffffff"

local COLS = {
    { key = "name", title = "Player Name", width = 130, align = "LEFT" },
    { key = "level", title = "Lvl", width = 45, align = "CENTER" },
    { key = "class", title = "Class", width = 80, align = "CENTER" },
    { key = "faction", title = "Faction", width = 65, align = "CENTER" },
    { key = "selfFound", title = "Self Found", width = 85, align = "CENTER" },
    { key = "achievements", title = "Achievements", width = 165, align = "CENTER" },
    { key = "updated", title = "Updated", width = 75, align = "CENTER" },
}

local sortState = {
    key = nil,
    asc = false,
}

local contextMenu
local contextTarget
local rows = {}
local headers = {}
local scopeCheckboxes = {}

local function TotalWidth()
    local width = 0
    for _, col in ipairs(COLS) do
        width = width + col.width + 10
    end
    return width - 10
end

local function HexToRgb(hex)
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    return r, g, b
end

local function RgbToHex(r, g, b)
    return string_format("%02x%02x%02x", math_floor(r + 0.5), math_floor(g + 0.5), math_floor(b + 0.5))
end

local function InterpolateColor(color1, color2, t)
    t = math_max(0, math_min(1, t))
    local r1, g1, b1 = HexToRgb(color1)
    local r2, g2, b2 = HexToRgb(color2)
    return RgbToHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
end

local function GetAchievementColor(completed, total)
    if not total or total == 0 then
        return "9d9d9d"
    end

    local percentage = (completed or 0) / total * 100
    if percentage == 0 then
        return "9d9d9d"
    elseif percentage > 0 and percentage < 20 then
        return InterpolateColor("9d9d9d", "ffffff", percentage / 20)
    elseif percentage >= 20 and percentage < 40 then
        return InterpolateColor("ffffff", "1eff00", (percentage - 20) / 20)
    elseif percentage >= 40 and percentage < 60 then
        return InterpolateColor("1eff00", "0070dd", (percentage - 40) / 20)
    elseif percentage >= 60 and percentage < 80 then
        return InterpolateColor("0070dd", "a335ee", (percentage - 60) / 20)
    end
    return InterpolateColor("a335ee", "ff8000", (percentage - 80) / 20)
end

local function TooltipLine(key, value)
    return key .. ": " .. WHITE_VALUE .. tostring(value or "") .. "|r"
end

local function GetFactionTextures(faction)
    if faction == "Horde" then
        return "Interface\\Timer\\Horde-Logo.PNG", "Interface\\Timer\\HordeGlow-Logo.PNG"
    elseif faction == "Alliance" then
        return "Interface\\Timer\\Alliance-Logo.PNG", "Interface\\Timer\\AllianceGlow-Logo.PNG"
    end
    return nil, nil
end

local function GetSelfFoundIcon(isSelfFound)
    if isSelfFound then
        return "|TInterface\\RAIDFRAME\\ReadyCheck-Ready.blp:16:16:0:0|t"
    end
    return ""
end

local function IsGuildOnlyScope()
    local scope = Leaderboard:GetScope()
    return scope and scope.guild and not scope.realm and not scope.faction
end

local function IsGuildMember(rowData)
    local playerGuild = GetGuildInfo("player") or ""
    return playerGuild ~= "" and (rowData.guild or "") == playerGuild
end

local function GetLocalCharacterKey()
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    if not name or name == "" then
        return nil
    end
    return (realm and realm ~= "" and (name .. "-" .. realm)) or name
end

local function CanInvite(name)
    if not name or name == "" or name == UnitName("player") then
        return false
    end
    if IsInGroup() and not (UnitIsGroupLeader("player") or (IsInRaid() and UnitIsGroupAssistant("player"))) then
        return false
    end
    return true
end

local function ShowContextMenu(name)
    if not contextMenu or not name or name == "" then
        return
    end
    contextTarget = name
    ToggleDropDownMenu(1, nil, contextMenu, "cursor", 3, -3)
end

local function EnsureContextMenu()
    if contextMenu then
        return
    end
    contextMenu = CreateFrame("Frame", "HCALeaderboardContextMenu", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(contextMenu, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        if (level or 1) == 1 then
            info = UIDropDownMenu_CreateInfo()
            info.text = contextTarget or "Player"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Whisper"
            info.notCheckable = true
            info.func = function()
                if contextTarget then
                    if ChatFrame_OpenChat then
                        ChatFrame_OpenChat("/w " .. contextTarget .. " ")
                    end
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Invite to Group"
            info.notCheckable = true
            info.disabled = not CanInvite(contextTarget)
            info.func = function()
                if contextTarget then
                    if C_PartyInfo and C_PartyInfo.InviteUnit then
                        C_PartyInfo.InviteUnit(contextTarget)
                    else
                        InviteUnit(contextTarget)
                    end
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Cancel"
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
end

local function UpdateHeaderText()
    for i, col in ipairs(COLS) do
        local text = col.title
        if sortState.key == col.key then
            text = text .. (sortState.asc and " ^" or " v")
        end
        if headers[i] and headers[i].Text then
            headers[i].Text:SetText(text)
        end
    end
end

local function SetCellText(rowFrame, colIndex, text, color)
    local cell = rowFrame.cells[colIndex]
    if not cell then
        return
    end
    cell:SetText(text or "")
    if color then
        cell:SetTextColor(color[1], color[2], color[3])
    else
        cell:SetTextColor(1, 1, 1)
    end
end

local function EnsureRow(parent, index, width)
    if rows[index] then
        return rows[index]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetSize(width, ROW_HEIGHT)
    row:EnableMouse(true)
    row.cells = {}

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(0.95, 0.26, 0.21, 0.22)
    highlight:Hide()
    row.highlight = highlight

    local x = 0
    for i, col in ipairs(COLS) do
        local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell:SetPoint("LEFT", row, "LEFT", x, 0)
        cell:SetSize(col.width, ROW_HEIGHT)
        cell:SetJustifyH(col.align or "CENTER")
        cell:SetJustifyV("MIDDLE")
        row.cells[i] = cell
        x = x + col.width + 10
    end

    row.factionGlow = row:CreateTexture(nil, "ARTWORK")
    row.factionGlow:SetPoint("CENTER", row.cells[4], "CENTER")
    row.factionGlow:SetSize(26, 26)
    row.factionGlow:Hide()

    row.factionLogo = row:CreateTexture(nil, "OVERLAY")
    row.factionLogo:SetPoint("CENTER", row.cells[4], "CENTER")
    row.factionLogo:SetSize(25, 25)
    row.factionLogo:Hide()

    row:SetScript("OnEnter", function(self)
        if self.isOffline then
            self.highlight:SetColorTexture(0.60, 0.60, 0.60, 0.25)
        else
            self.highlight:SetColorTexture(0.95, 0.26, 0.21, 0.25)
        end
        self.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:SetText(self.tooltipTitle or "Player", 1, 1, 1)
        if self.tooltipLines then
            for i = 1, #self.tooltipLines do
                GameTooltip:AddLine(self.tooltipLines[i])
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.playerName then
            ShowContextMenu(self.playerName)
        elseif button == "LeftButton" then
            CloseDropDownMenus()
        end
    end)

    rows[index] = row
    return row
end

local function CreateScopeCheckbox(parent, key, label, anchor, xOffset)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", anchor, "RIGHT", xOffset or 0, 0)
    checkbox:SetSize(22, 22)
    checkbox.Label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    checkbox.Label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.Label:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        CloseDropDownMenus()
        Leaderboard:SetScopeValue(key, self:GetChecked())
    end)
    scopeCheckboxes[key] = checkbox
    return checkbox
end

local function RefreshScopeCheckboxes()
    local scope = Leaderboard:GetScope()
    for key, checkbox in pairs(scopeCheckboxes) do
        checkbox:SetChecked(scope[key] and true or false)
    end
end

function UI:CreateFrame()
    if self.frame then
        return self.frame
    end

    EnsureContextMenu()

    local width = TotalWidth()
    local frame = CreateFrame("Frame", "HCALeaderboardFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("HIGH")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnMouseDown", function()
        CloseDropDownMenus()
    end)
    frame:Hide()

    local frameName = frame:GetName()
    local found = false
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == frameName then
            found = true
            break
        end
    end
    if not found then
        table_insert(UISpecialFrames, frameName)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER")
    frame.title:SetText("|cfff44336Achievement Leaderboard|r")

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)
    header:SetSize(width, 22)
    frame.header = header

    local x = 0
    for i, col in ipairs(COLS) do
        local button = CreateFrame("Button", nil, header)
        button:SetPoint("LEFT", header, "LEFT", x, 0)
        button:SetSize(col.width, 22)
        button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.Text:SetAllPoints(button)
        button.Text:SetJustifyH(col.align or "CENTER")
        button.Text:SetText(col.title)
        button:SetScript("OnClick", function()
            CloseDropDownMenus()
            if sortState.key == col.key then
                sortState.asc = not sortState.asc
            else
                sortState.key = col.key
                sortState.asc = col.key == "name" or col.key == "class" or col.key == "faction"
            end
            UpdateHeaderText()
            UI:Refresh()
        end)
        headers[i] = button
        x = x + col.width + 10
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 46)
    frame.scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, 1)
    scroll:SetScrollChild(child)
    frame.child = child

    local scopeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    scopeLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 15)
    scopeLabel:SetText("Limit:")
    frame.scopeLabel = scopeLabel

    local guildCheckbox = CreateScopeCheckbox(frame, "guild", "Guild", scopeLabel, 6)
    local realmCheckbox = CreateScopeCheckbox(frame, "realm", "Realm", guildCheckbox.Label, 18)
    CreateScopeCheckbox(frame, "faction", "Faction", realmCheckbox.Label, 18)

    frame.countText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 17)

    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.frame = frame
    return frame
end

function UI:Refresh()
    local frame = self:CreateFrame()
    RefreshScopeCheckboxes()
    UpdateHeaderText()

    local data = Leaderboard.Data and Leaderboard.Data:GetRows(sortState) or {}
    frame.child:SetHeight(math.max(1, #data * ROW_HEIGHT))

    for index, rowData in ipairs(data) do
        local row = EnsureRow(frame.child, index, TotalWidth())
        local isOffline = not rowData.online
        local isGuildMember = IsGuildMember(rowData)
        local isGlobalView = not IsGuildOnlyScope()
        local cellColor = isOffline and OFFLINE_COLOR or nil
        local nameColor = cellColor

        row.playerName = rowData.name
        row.isOffline = isOffline
        row:SetAlpha(isOffline and 0.75 or 1)
        row.tooltipTitle = rowData.name
        row.tooltipLines = {}
        if rowData.guild ~= "" then
            row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("Guild", rowData.guild)
        end
        if rowData.realm ~= "" then
            row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("Realm", rowData.realm)
        end
        local ver = rowData.version
        if (not ver or ver == "" or ver == "0.0.0") and rowData.key == GetLocalCharacterKey() then
            ver = (Leaderboard.GetAddOnVersionString and Leaderboard.GetAddOnVersionString()) or "?"
        elseif not ver or ver == "" or ver == "0.0.0" then
            ver = "?"
        end
        row.tooltipLines[#row.tooltipLines + 1] = TooltipLine("Version", ver)

        local name = rowData.name
        if rowData.dead then
            local skull = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:12:12:0:0|t "
            name = skull .. name
            nameColor = DEAD_COLOR
        elseif isOffline then
            nameColor = OFFLINE_COLOR
        elseif isGlobalView and isGuildMember then
            nameColor = GUILD_MEMBER_COLOR
        elseif rowData.online then
            nameColor = { 0.25, 1, 0.25 }
        end

        SetCellText(row, 1, name, nameColor)
        SetCellText(row, 2, tostring(rowData.level or 0), cellColor)
        SetCellText(row, 3, rowData.class or "", cellColor)
        SetCellText(row, 4, "", cellColor)
        local factionLogo, factionGlow = GetFactionTextures(rowData.faction)
        if factionLogo and factionGlow then
            row.factionGlow:SetTexture(factionGlow)
            row.factionGlow:Show()
            row.factionLogo:SetTexture(factionLogo)
            row.factionLogo:Show()
        else
            row.factionGlow:Hide()
            row.factionLogo:Hide()
        end
        SetCellText(row, 5, GetSelfFoundIcon(rowData.selfFound), cellColor)
        local colorCode = GetAchievementColor(rowData.completed, rowData.total)
        local achievementText = string_format("%d pts |cff%s[%d/%d]|r", rowData.points or 0, colorCode, rowData.completed or 0, rowData.total or 0)
        if isOffline then
            achievementText = string_format("%d pts [%d/%d]", rowData.points or 0, rowData.completed or 0, rowData.total or 0)
        end
        SetCellText(row, 6, achievementText, cellColor)
        SetCellText(row, 7, rowData.lastSeenText or "?", cellColor)
        row:Show()
    end

    for i = #data + 1, #rows do
        rows[i]:Hide()
    end

    local scopeLabel = Leaderboard.Data and Leaderboard.Data:GetScopeLabel() or "World"
    frame.title:SetText("|cfff44336Achievement Leaderboard - " .. scopeLabel .. "|r")
    frame.countText:SetText(string_format("Players: %d", #data))
end

function UI:Show()
    local frame = self:CreateFrame()
    self:Refresh()
    frame:Show()
end

function UI:Toggle()
    local frame = self:CreateFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

function UI:Initialize()
    self:CreateFrame()
end
