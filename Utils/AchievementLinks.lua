-- Utils/AchievementLinks.lua
-- Custom chat hyperlink support for HardcoreAchievements

local HCA_LINK_PREFIX = "hcaach"

local function GetAchievementById(achId)
	if _G.Achievements then
		for _, rec in ipairs(_G.Achievements) do
			if tostring(rec.achId) == tostring(achId) then
				return rec
			end
		end
	end
	-- Fallback to dungeon/other defs registry if present
	if _G.HCA_AchievementDefs and _G.HCA_AchievementDefs[tostring(achId)] then
		return _G.HCA_AchievementDefs[tostring(achId)]
	end
	return nil
end

local function ViewerHasCompletedAchievement(achId)
    local key = tostring(achId)
    local getDB = _G.HardcoreAchievements_GetCharDB
    if type(getDB) == "function" then
        local _, cdb = getDB()
        if cdb and cdb.achievements and cdb.achievements[key] and cdb.achievements[key].completed then
            return true
        end
    end
    if _G.AchievementPanel and _G.AchievementPanel.achievements then
        for _, row in ipairs(_G.AchievementPanel.achievements) do
            if tostring(row.id) == key and row.completed then
                return true
            end
        end
    end
    return false
end

-- Public: build a hyperlink string for an achievement id and title
function HCA_GetAchievementHyperlink(achId, title, icon, points)
    local sender = UnitGUID("player") or ""
    local display = string.format("[%s]", tostring(title or achId))
    local iconField = icon and tostring(icon) or ""
    local pointsField = points and tostring(points) or ""
    -- Format: |Hhcaach:achId:icon:points:sender|h[Title]|h
    return string.format("|H%s:%s:%s:%s:%s|h%s|h", HCA_LINK_PREFIX, tostring(achId), iconField, pointsField, tostring(sender), display)
end

-- Tooltip rendering for our custom link
local Old_ItemRef_SetHyperlink = ItemRefTooltip and ItemRefTooltip.SetHyperlink
if Old_ItemRef_SetHyperlink then
	ItemRefTooltip.SetHyperlink = function(self, link, ...)
        local linkStr = tostring(link or "")
        -- Extract hyperlink part (between |H and |h) or use the whole string if no |H wrapper
        local hyperlinkPart = string.match(linkStr, "^%|H([^|]+)%|h") or linkStr
        local prefix, achId, iconStr, pointsStr, sender = string.match(hyperlinkPart, "^(%w+):([^:]+):?([^:]*):?([^:]*):?(.*)$")
        if prefix == HCA_LINK_PREFIX and achId then
			ShowUIPanel(ItemRefTooltip)
			ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
			ItemRefTooltip:ClearLines()

            local rec = GetAchievementById(achId)
            local title = rec and rec.title or ("Achievement " .. tostring(achId))
            local tooltip = rec and rec.tooltip or ""
            local icon = 136116
            local points = 0

            -- Per-viewer secrecy: if secret and viewer hasn't completed, show secret placeholders
            do
                local isSecret = rec and rec.secret
                local viewerCompleted = ViewerHasCompletedAchievement(achId)
                if isSecret and not viewerCompleted then
                    title = (rec and rec.secretTitle) or "Secret"
                    tooltip = (rec and rec.secretTooltip) or "Hidden"
                    icon = (rec and rec.secretIcon) or icon
                    points = (rec and tonumber(rec.secretPoints)) or 0
                end
            end

            if iconStr and iconStr ~= "" then
                local asNum = tonumber(iconStr)
                if asNum then icon = asNum else icon = iconStr end
            elseif rec and rec.icon then
                icon = rec.icon
            end

            if pointsStr and pointsStr ~= "" then
                points = tonumber(pointsStr) or 0
            elseif rec and rec.points then
                points = tonumber(rec.points) or 0
            end

			-- Title line with icon texture escape (valid in tooltips)
			local iconTag = type(icon) == "number" and string.format("|T%d:24:24|t", icon) or string.format("|T%s:24:24|t", tostring(icon))
			ItemRefTooltip:AddLine(iconTag .. "  " .. title, 1, 0.82, 0)
			if tooltip and tooltip ~= "" then
				ItemRefTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
			end

			-- Special handling for dungeon-style achievements: points under description, then list required bosses
			local showedDungeonDetails = false
			if rec and rec.requiredKills and next(rec.requiredKills) ~= nil then
				showedDungeonDetails = true
				ItemRefTooltip:AddLine(" ")
				ItemRefTooltip:AddLine("Required Bosses:", 0, 1, 0)
				local progressFn = _G.HardcoreAchievements_GetProgress
				local progress = progressFn and progressFn(rec.achId) or nil
				local counts = (progress and progress.counts) or {}
				-- Build sorted list of boss IDs for stable order
				local keys = {}
				for npcId, _ in pairs(rec.requiredKills) do table.insert(keys, npcId) end
				table.sort(keys, function(a, b)
					local aa = tonumber(a) or 0
					local bb = tonumber(b) or 0
					return aa < bb
				end)
				local total = #keys
				for i, npcId in ipairs(keys) do
					local need = rec.requiredKills[npcId]
					local idNum = tonumber(npcId) or npcId
					local current = (counts[idNum] or counts[tostring(idNum)] or 0)
					local bossName = _G.HCA_GetBossName and _G.HCA_GetBossName(idNum) or ("Boss " .. tostring(idNum))
					local done = current >= (tonumber(need) or 1)
					local lr, lg, lb = done and 1 or 0.5, done and 1 or 0.5, done and 1 or 0.5
					ItemRefTooltip:AddLine(bossName, lr, lg, lb)
				end
			end

            -- Non-dungeon: Zone only (points shown with completion status)
            if not showedDungeonDetails then
                local zoneText
                if rec then
                    if type(rec.zone) == "string" then
                        zoneText = rec.zone
                    elseif type(rec.zoneName) == "string" then
                        zoneText = rec.zoneName
                    elseif type(rec.zoneText) == "string" then
                        zoneText = rec.zoneText
                    elseif rec.mapName then
                        zoneText = tostring(rec.mapName)
                    elseif rec.mapID then
                        zoneText = tostring(rec.mapID)
                    end
                end
                if zoneText and zoneText ~= "" then
                    ItemRefTooltip:AddLine(zoneText, 0.412, 0.678, 0.788)
                end
            end
            
            -- Show completion status at the bottom with points right-aligned
            ItemRefTooltip:AddLine(" ")
            local isCompleted = ViewerHasCompletedAchievement(achId)
            local statusText = isCompleted and "Complete" or "Incomplete"
            local statusR, statusG, statusB = isCompleted and 0.6 or 0.5, isCompleted and 0.9 or 0.5, isCompleted and 0.6 or 0.5
            local pointsText = (points and points > 0) and string.format("%d pts", points) or ""
            ItemRefTooltip:AddDoubleLine(statusText, pointsText, statusR, statusG, statusB, 0.7, 0.9, 0.7)
            
			ItemRefTooltip:Show()
			return
		end
		return Old_ItemRef_SetHyperlink(self, link, ...)
	end
end

-- Optional: Convert bracketed fallback text to hyperlink for receivers without direct link
-- Pattern: [HCA: Title (achId)] -> |Hhcaach:achId:GUID|h[Title]|h
local function EscapePattern(s)
	return (s
		:gsub("%%", "%%%%")
		:gsub("^%^", "%%^")
		:gsub("%$", "%%$")
		:gsub("%(", "%%(")
		:gsub("%)", "%%)")
		:gsub("%.", "%%.")
		:gsub("%[", "%%[")
		:gsub("%]", "%%]")
		:gsub("%*", "%%*")
		:gsub("%+", "%%+")
		:gsub("%-", "%%-")
		:gsub("%?", "%%?")
		:gsub("%|", "%%|")
	)
end

local function ChatFilter_HCA(chatFrame, _, msg, ...)
    if not msg or type(msg) ~= "string" then return end
    local changed = false
    local function ViewerHasCompleted(id)
        return ViewerHasCompletedAchievement(id)
    end
    -- Extended form with icon and points: [HCA: Title (id,icon,points)]
    msg = msg:gsub("%[HCA:%s*(.-)%s*%(([^,%)]+)%s*,%s*([^,%)]+)%s*,%s*([^%)]*)%)%]", function(title, id, iconStr, pointsStr)
        local icon = (iconStr and iconStr ~= "") and iconStr or nil
        local pts = (pointsStr and pointsStr ~= "") and tonumber(pointsStr) or nil
        local rec = GetAchievementById(id)
        local displayTitle
        if rec and rec.secret and not ViewerHasCompleted(id) then
            displayTitle = rec.secretTitle or "Secret"
        else
            displayTitle = (rec and rec.title) or title
        end
        local link = HCA_GetAchievementHyperlink(id, displayTitle, icon, pts)
        changed = true
        return link
    end)
    -- Compact form without title: [HCA:(id,icon,points)]
    msg = msg:gsub("%[HCA:%s*%(([^,%)]+)%s*,%s*([^,%)]+)%s*,%s*([^%)]*)%)%]", function(id, iconStr, pointsStr)
        local icon = (iconStr and iconStr ~= "") and iconStr or nil
        local pts = (pointsStr and pointsStr ~= "") and tonumber(pointsStr) or nil
        local rec = GetAchievementById(id)
        local displayTitle
        if rec and rec.secret and not ViewerHasCompleted(id) then
            displayTitle = rec.secretTitle or "Secret"
        else
            displayTitle = (rec and rec.title) or tostring(id)
        end
        local link = HCA_GetAchievementHyperlink(id, displayTitle, icon, pts)
        changed = true
        return link
    end)
    -- Simple form without extras: [HCA: Title (id)] (id can be string)
    msg = msg:gsub("%[HCA:%s*(.-)%s*%(([^%)]*)%)%]", function(title, id)
        local rec = GetAchievementById(id)
        local displayTitle
        if rec and rec.secret and not ViewerHasCompleted(id) then
            displayTitle = rec.secretTitle or "Secret"
        else
            displayTitle = (rec and rec.title) or title
        end
        local link = HCA_GetAchievementHyperlink(id, displayTitle)
        changed = true
        return link
    end)
    if changed then
        return false, msg, ...
    end
end

-- Register filters for common channels
if ChatFrame_AddMessageEventFilter then
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", ChatFilter_HCA)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChatFilter_HCA)
end


