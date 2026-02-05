-- Utils/AchievementLinks.lua
-- Custom chat hyperlink support for HardcoreAchievements

local HCA_LINK_PREFIX = "hcaach"

-- Localize frequently-used WoW API globals (micro-optimization, no behavior change)
local _G = _G
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local GetItemCount = GetItemCount
local ShowUIPanel = ShowUIPanel
local table_insert = table.insert
local table_sort = table.sort
local table_concat = table.concat
local string_format = string.format

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
	-- Guild-first achievements (from GuildFirstCatalog, stored in HCA_GuildFirst_DefById)
	if _G.HCA_GuildFirst_DefById and _G.HCA_GuildFirst_DefById[tostring(achId)] then
		return _G.HCA_GuildFirst_DefById[tostring(achId)]
	end
	-- Check achievement panel rows for reputation and dungeon set achievements
	if _G.AchievementPanel and _G.AchievementPanel.achievements then
		for _, row in ipairs(_G.AchievementPanel.achievements) do
			local rowId = row.id or row.achId
			if rowId and tostring(rowId) == tostring(achId) then
				-- Return the definition from row._def if available, or construct from row data
				if row._def then
					return row._def
				elseif row.Title and row.Title.GetText then
					-- Construct a basic definition from row data
					return {
						achId = achId,
						title = row.Title:GetText() or tostring(achId),
						tooltip = row.tooltip or "",
						icon = row.Icon and row.Icon.GetTexture and row.Icon:GetTexture() or 136116,
						points = tonumber(row.points) or tonumber(row.originalPoints) or 0
					}
				end
			end
		end
	end
	return nil
end

--- Guild-first achievements use secret/hiddenUntilComplete in the UI but should never show secret placeholders when linked in chat.
local function IsGuildFirstAchievement(achId)
	return _G.HCA_GuildFirst_DefById and _G.HCA_GuildFirst_DefById[tostring(achId or "")]
end

local function ViewerHasCompletedAchievement(achId)
    local key = tostring(achId)
    -- Guild-first achievements: completion is "claimed by me" in the guild-first DB
    if _G.HCA_GuildFirst_DefById and _G.HCA_GuildFirst_DefById[key] and _G.HCA_GuildFirst and type(_G.HCA_GuildFirst.IsClaimedByMe) == "function" then
        if _G.HCA_GuildFirst:IsClaimedByMe(key) then
            return true
        end
    end
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

-- Public: build a bracket format string for chat (used before chat filter converts to hyperlink)
-- Format: [HCA:(achId)] - icon, points, and other data are looked up locally on receiver's end
function HCA_GetAchievementBracket(achId)
	-- For some achievements, the title is player-specific (e.g., includes the sender's name).
	-- In those cases, send an expanded bracket form so receivers don't recompute a different title locally.
	-- Pattern handled by ChatFilter_HCA below: [HCA: Title (achId)]
	local rec = GetAchievementById(achId)
	if rec and rec.linkUsesSenderTitle and rec.title then
		return string_format("[HCA: %s (%s)]", tostring(rec.title), tostring(achId))
	end
	return string_format("[HCA:(%s)]", tostring(achId))
end

-- Public: build a hyperlink string for an achievement id and title
-- Icon and other data are looked up locally on the receiver's end using the achId
function HCA_GetAchievementHyperlink(achId, title, senderName, senderGuid)
	-- We intentionally do NOT encode icon/points in the link; those are always looked up locally.
	-- We do include sender identity metadata so certain achievements can render a sender-stable title
	local guid = senderGuid
	if guid == nil then
		guid = UnitGUID("player") or ""
	end
	local name = senderName or ""
	local display = string_format("[%s]", tostring(title or achId))
	-- Format (v2): |Hhcaach:achId:senderGuid:senderName|h[Title]|h
	-- Backwards compatible with v1: hcaach:achId:senderGuid
	return "|cffffd100" .. string_format("|H%s:%s:%s:%s|h%s|h", HCA_LINK_PREFIX, tostring(achId), tostring(guid), tostring(name), display) .. "|r"
end

-- Tooltip rendering for our custom link
local Old_ItemRef_SetHyperlink = ItemRefTooltip and ItemRefTooltip.SetHyperlink
if Old_ItemRef_SetHyperlink then
	ItemRefTooltip.SetHyperlink = function(self, link, ...)
        local linkStr = tostring(link or "")
		-- Extract the visible title from the link text (between |h[ and ]|h) if present.
		-- This is what was shown in chat, and is sender-stable when the sender provided it.
		local displayTitleFromLink = string.match(linkStr, "%|h%[([^%]]-)%]%|h")
        -- Extract hyperlink part (between |H and |h) or use the whole string if no |H wrapper
        local hyperlinkPart = string.match(linkStr, "^%|H([^|]+)%|h") or linkStr
        -- Parse link format:
		-- v1: hcaach:achId:senderGuid
		-- v2: hcaach:achId:senderGuid:senderName
        -- Icon, points, and other data are always looked up locally, never from the link
		local prefix, achId, rest = string.match(hyperlinkPart, "^(%w+):([^:]+):?(.*)$")
		local senderGuid, senderName = "", ""
		if rest and rest ~= "" then
			-- Split rest into guid and optional name
			senderGuid, senderName = string.match(rest, "^([^:]*):?(.*)$")
			senderGuid = senderGuid or ""
			senderName = senderName or ""
		end
        if prefix == HCA_LINK_PREFIX and achId then
            ShowUIPanel(ItemRefTooltip)
			ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
			ItemRefTooltip:ClearLines()

            local rec = GetAchievementById(achId)
            local title = rec and rec.title or ("Achievement " .. tostring(achId))
            local tooltip = rec and rec.tooltip or ""
            local icon = 136116  -- Default fallback icon
            local points = 0

			-- Sender-stable title override for player-specific titles:
			-- if the achievement opts in, prefer the visible title from the link text itself.
			-- This avoids recomputing titles locally (which can depend on the viewer).
			if rec and rec.linkUsesSenderTitle and displayTitleFromLink and displayTitleFromLink ~= "" then
				title = displayTitleFromLink
			end
			-- If we don't have the visible title text (some hyperlink call sites pass only "hcaach:..."),
			-- allow an achievement to compute a sender-stable title from sender identity.
			-- Define `def.linkTitle = function(senderName, senderGuid, displayTitleFromLink) return "..." end`.
			if rec and rec.linkUsesSenderTitle and (not displayTitleFromLink or displayTitleFromLink == "") and type(rec.linkTitle) == "function" then
				local ok, linkTitle = pcall(rec.linkTitle, senderName, senderGuid, displayTitleFromLink)
				if ok and type(linkTitle) == "string" and linkTitle ~= "" then
					title = linkTitle
				end
			end

            -- Per-viewer secrecy: if secret and viewer hasn't completed, show secret placeholders (never for guild-first links)
            local isSecret = rec and rec.secret and not IsGuildFirstAchievement(achId)
            local viewerCompleted = ViewerHasCompletedAchievement(achId)
            local usingSecretPoints = false
            if isSecret and not viewerCompleted then
                title = (rec and rec.secretTitle) or "Secret"
                tooltip = (rec and rec.secretTooltip) or "Hidden"
                icon = (rec and rec.secretIcon) or icon
                points = (rec and tonumber(rec.secretPoints)) or 0
                usingSecretPoints = true
            else
                -- Always use icon from local achievement data (client-side lookup)
                if rec and rec.icon then
                    icon = rec.icon
                end
            end

			-- Sender-stable tooltip override (only when the viewer is allowed to see the real tooltip).
			-- Define `def.linkTooltip = function(senderName, senderGuid) return "..." end` on an achievement.
			if (not isSecret or viewerCompleted) and rec and type(rec.linkTooltip) == "function" and (senderName ~= "" or senderGuid ~= "") then
				local ok, linkTip = pcall(rec.linkTooltip, senderName, senderGuid)
				if ok and type(linkTip) == "string" and linkTip ~= "" then
					tooltip = linkTip
				end
			end

            -- Always use local points, ignore sender's points from the link
            -- Only set points if we're not using secret points (which were already set above)
            if not usingSecretPoints then
                -- First try to get points from the achievement row (calculated with multipliers)
                local rowPoints = nil
                if _G.AchievementPanel and _G.AchievementPanel.achievements then
                    for _, row in ipairs(_G.AchievementPanel.achievements) do
                        if tostring(row.id) == tostring(achId) or tostring(row.achId) == tostring(achId) then
                            rowPoints = row.points
                            break
                        end
                    end
                end
                
                if rowPoints then
                    points = tonumber(rowPoints) or 0
                elseif rec and rec.points then
                    -- Fallback to base points if row not found
                    points = tonumber(rec.points) or 0
                else
                    points = 0
                end
            end

			-- Title line with icon texture escape (valid in tooltips)
			local iconTag = type(icon) == "number" and string_format("|T%d:24:24|t", icon) or string_format("|T%s:24:24|t", tostring(icon))
			ItemRefTooltip:AddLine(iconTag .. "  " .. title, 1, 0.82, 0)
			if tooltip and tooltip ~= "" then
				ItemRefTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
			end

			-- Special handling for dungeon and raid achievements: points under description, then list required bosses
			-- Show boss list for achievements with requiredKills and mapID (dungeons) or isRaid flag (raids)
			local showedDungeonDetails = false
			if rec and rec.requiredKills and next(rec.requiredKills) ~= nil and (rec.mapID or rec.isRaid) then
				showedDungeonDetails = true
				ItemRefTooltip:AddLine(" ")
				ItemRefTooltip:AddLine("Required Bosses:", 0, 1, 0)
				local progressFn = _G.HardcoreAchievements_GetProgress
				local progress = progressFn and progressFn(rec.achId) or nil
				local counts = (progress and progress.counts) or {}
				
				-- Determine which boss name function to use (raid vs dungeon)
				local isRaid = rec.isRaid or false
				local getBossNameFn = isRaid and _G.HCA_GetRaidBossName or _G.HCA_GetBossName
				
				-- Use bossOrder if available (for raids), otherwise build sorted list
				local keys = {}
				if rec.bossOrder and next(rec.bossOrder) ~= nil then
					-- Use provided boss order
					for _, npcId in ipairs(rec.bossOrder) do
						table_insert(keys, npcId)
					end
				else
					-- Build sorted list of boss IDs for stable order
					for npcId, _ in pairs(rec.requiredKills) do 
						table_insert(keys, npcId) 
					end
					table_sort(keys, function(a, b)
						local aa = tonumber(a) or 0
						local bb = tonumber(b) or 0
						return aa < bb
					end)
				end
				
				for i, entry in ipairs(keys) do
					-- Check if entry is a string alias (like "Edge of Madness" or "Ring Of Law")
					local bossName = ""
					local done = false
					
					if type(entry) == "string" then
						-- String alias - use it as the display name and look up the NPC IDs
						bossName = entry
						local need = rec.requiredKills[entry]
						if type(need) == "table" then
							-- Array of NPC IDs - check if any has been killed
							for _, id in ipairs(need) do
								local idNumCheck = tonumber(id) or id
								if (counts[idNumCheck] or counts[tostring(idNumCheck)] or 0) >= 1 then
									done = true
									break
								end
							end
						end
					else
						-- Numeric NPC ID - proceed normally
						local npcId = entry
						local need = rec.requiredKills[npcId]
						local idNum = tonumber(npcId) or npcId
						local current = (counts[idNum] or counts[tostring(idNum)] or 0)
						
						-- Support both single NPC IDs and arrays of NPC IDs
						if type(need) == "table" then
							-- Array of NPC IDs - get names for all of them
							local bossNames = {}
							for _, id in ipairs(need) do
								local name = (getBossNameFn and getBossNameFn(id)) or ("Boss " .. tostring(id))
								table_insert(bossNames, name)
							end
							bossName = table_concat(bossNames, " / ")
							-- Check if any has been killed
							for _, id in ipairs(need) do
								local idNumCheck = tonumber(id) or id
								if (counts[idNumCheck] or counts[tostring(idNumCheck)] or 0) >= 1 then
									done = true
									break
								end
							end
						else
							-- Single NPC ID
							bossName = (getBossNameFn and getBossNameFn(idNum)) or ("Boss " .. tostring(idNum))
							done = current >= (tonumber(need) or 1)
						end
					end
					
					local lr, lg, lb = done and 1 or 0.5, done and 1 or 0.5, done and 1 or 0.5
					ItemRefTooltip:AddLine(bossName, lr, lg, lb)
				end
			end

			-- Special handling for dungeon set achievements: list required items
			local showedDungeonSetDetails = false
			if rec and rec.requiredItems and next(rec.requiredItems) ~= nil then
				showedDungeonSetDetails = true
				ItemRefTooltip:AddLine(" ")
				ItemRefTooltip:AddLine("Required Items:", 0, 1, 0)
				local progressFn = _G.HardcoreAchievements_GetProgress
				local progress = progressFn and progressFn(rec.achId) or nil
				local itemOwned = (progress and progress.itemOwned) or {}
				local isCompleted = ViewerHasCompletedAchievement(achId)
				
				-- Use itemOrder if available, otherwise use requiredItems array order
				local itemsToShow = rec.itemOrder or rec.requiredItems
				for _, itemId in ipairs(itemsToShow) do
					local owned = false
					-- Check saved state first (once owned, always owned)
					if itemOwned and itemOwned[itemId] then
						owned = true
					else
						-- Fall back to checking current inventory
						local count = GetItemCount and GetItemCount(itemId, true) or 0
						owned = count > 0
					end
					-- If achievement is complete, all items show as owned
					if isCompleted then
						owned = true
					end
					
					local itemName = _G.HCA_GetItemName and _G.HCA_GetItemName(itemId) or ("Item " .. tostring(itemId))
					local lr, lg, lb = owned and 1 or 0.5, owned and 1 or 0.5, owned and 1 or 0.5
					ItemRefTooltip:AddLine(itemName, lr, lg, lb)
				end
			end

            -- Non-dungeon: Zone only (points shown with completion status)
            if not showedDungeonDetails and not showedDungeonSetDetails then
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
            local isFailed = false
            if not isCompleted then
                -- Look up the row from AchievementPanel to get maxLevel
                local row = nil
                if _G.AchievementPanel and _G.AchievementPanel.achievements then
                    for _, r in ipairs(_G.AchievementPanel.achievements) do
                        if tostring(r.id) == tostring(achId) or tostring(r.achId) == tostring(achId) then
                            row = r
                            break
                        end
                    end
                end
                if row and row.maxLevel then
                    local playerLevel = UnitLevel("player") or 1
                    isFailed = playerLevel > row.maxLevel
                end
            end
            
            local statusText, statusR, statusG, statusB
            if isCompleted then
                statusText = "Complete"
                statusR, statusG, statusB = 0.6, 0.9, 0.6  -- Light green
            elseif isFailed then
                statusText = "Failed"
                statusR, statusG, statusB = 0.9, 0.2, 0.2  -- Red
            else
                statusText = "Incomplete"
                statusR, statusG, statusB = 0.5, 0.5, 0.5  -- Gray
            end
            
            local pointsText = (points and points > 0) and string_format("%d pts", points) or ""
            ItemRefTooltip:AddDoubleLine(statusText, pointsText, statusR, statusG, statusB, 0.7, 0.9, 0.7)
            
			ItemRefTooltip:Show()
			return
		end
		return Old_ItemRef_SetHyperlink(self, link, ...)
	end
end

local function ChatFilter_HCA(chatFrame, event, msg, author, ...)
    if not msg or type(msg) ~= "string" then return end
    local changed = false
	-- ChatFrame_AddMessageEventFilter passes (self, event, msg, author, ...)
	local authorName = ""
	if type(author) == "string" and author ~= "" then
		-- Strip realm if present (Name-Realm)
		authorName = (author:match("^([^-]+)")) or author
	end
	-- For *_INFORM events (your outgoing whispers), `author` is the recipient, not the sender.
	-- For link metadata we want the *sender/completer* name so tooltips render correctly on both sides.
	local senderNameForLink = authorName
	if event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
		local me = UnitName("player")
		if type(me) == "string" and me ~= "" then
			senderNameForLink = (me:match("^([^-]+)")) or me
		end
	end
    local function ViewerHasCompleted(id)
        return ViewerHasCompletedAchievement(id)
    end
    -- Extended form with title: [HCA: Title (id)]
    msg = msg:gsub("%[HCA:%s*(.-)%s*%(([^%)]+)%)%]", function(title, id)
        local rec = GetAchievementById(id)
        local displayTitle
        if rec and rec.secret and not ViewerHasCompleted(id) and not IsGuildFirstAchievement(id) then
            displayTitle = rec.secretTitle or "Secret"
        else
			-- Prefer the sender-supplied title from the message, so player-specific titles remain stable.
            displayTitle = (title and title ~= "" and title) or (rec and rec.title) or tostring(id)
        end
        local link = HCA_GetAchievementHyperlink(id, displayTitle, senderNameForLink)
        changed = true
        return link
    end)
    -- Compact form without title: [HCA:(id)]
    msg = msg:gsub("%[HCA:%s*%(([^%)]+)%)%]", function(id)
        local rec = GetAchievementById(id)
        local displayTitle
        if rec and rec.secret and not ViewerHasCompleted(id) and not IsGuildFirstAchievement(id) then
            displayTitle = rec.secretTitle or "Secret"
        else
            displayTitle = (rec and rec.title) or tostring(id)
        end
        local link = HCA_GetAchievementHyperlink(id, displayTitle, senderNameForLink)
        changed = true
        return link
    end)
    if changed then
        -- IMPORTANT: since we took `author` as a named parameter, we must return it explicitly,
        -- otherwise WoW chat will mis-handle the message (can appear as if the link didn't send).
        return false, msg, author, ...
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


