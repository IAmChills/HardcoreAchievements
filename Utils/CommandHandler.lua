-- CommandHandler.lua
-- Client-side handler for processing admin commands via whispers
-- This file should be included in all versions of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local addonName, addon = ...
local C_GameRules = C_GameRules
local UnitName = UnitName
local UnitLevel = UnitLevel
local CreateFrame = CreateFrame
local time = time
local GetPresetMultiplier = (addon and addon.GetPresetMultiplier)
local AchievementTracker = (addon and addon.AchievementTracker)
local IsSelfFound = (addon and addon.IsSelfFound)
local table_insert = table.insert
local table_remove = table.remove
local string_format = string.format
local string_byte = string.byte
local string_gmatch = string.gmatch
local AdminCommandHandler = {}
local COMM_PREFIX = "HCA_Admin_Cmd" -- AceComm prefix for admin commands
local RESPONSE_PREFIX = "HCA_Admin_Resp" -- AceComm prefix for responses (max 16 chars)
local PRECIOUS_COMPLETE_PREFIX = "HCA_Fellowship" -- AceComm prefix for Precious completion
local MAX_PAYLOAD_AGE = 300 -- 5 minutes in seconds

-- Callback registry for Precious completion messages
local preciousCompletionCallbacks = {}

-- Debug system: Helper functions for debug messages
local function GetDebugEnabled()
    if not addon then return false end
    addon.HardcoreAchievementsDB = addon.HardcoreAchievementsDB or {}
    return addon.HardcoreAchievementsDB.debugEnabled or false
end

local function SetDebugEnabled(enabled)
    if not addon then return end
    addon.HardcoreAchievementsDB = addon.HardcoreAchievementsDB or {}
    addon.HardcoreAchievementsDB.debugEnabled = enabled and true or false
end

local function DebugPrint(message)
    if GetDebugEnabled() then
        print("|cff008066[HCA DEBUG]|r |cffffd100" .. tostring(message) .. "|r")
    end
end
if addon then addon.DebugPrint = DebugPrint end

-- SECURITY: Get admin secret key from database (set by admin via slash command)
-- This key is NOT in source code and must be set by the admin
local function GetAdminSecretKey()
    if not addon then return nil end
    addon.HardcoreAchievementsDB = addon.HardcoreAchievementsDB or {}
    return addon.HardcoreAchievementsDB.adminSecretKey
end

-- SECURITY: Set admin secret key (only accessible via slash command)
local function SetAdminSecretKey(key)
    if not addon then return false end
    addon.HardcoreAchievementsDB = addon.HardcoreAchievementsDB or {}
    if key and #key >= 16 then
        addon.HardcoreAchievementsDB.adminSecretKey = key
        return true
    end
    return false
end

-- SECURITY: HMAC-style hash function using secret key
-- This provides much better security than a simple hash
local function CreateSecureHash(payload, secretKey)
    if not secretKey or secretKey == "" then
        return nil
    end
    
    -- Create message to sign: all critical fields in canonical order (include commandType for command differentiation)
    local message = string_format("%d:%d:%s:%s:%s:%s",
        payload.version or 0,
        payload.timestamp or 0,
        payload.commandType or "",
        payload.achievementId or "",
        payload.targetCharacter or "",
        payload.nonce or ""
    )
    
    -- HMAC-style hash: hash(key + message + key)
    local combined = secretKey .. message .. secretKey
    
    -- Use a more complex hash algorithm
    local hash = 0
    local prime1 = 31
    local prime2 = 17
    
    for i = 1, #combined do
        local byte = string_byte(combined, i)
        hash = ((hash * prime1) + byte * prime2) % 2147483647
        hash = (hash + (byte * i * prime1)) % 2147483647
    end
    
    -- Combine with secret key length for additional entropy
    hash = (hash * #secretKey) % 2147483647
    
    -- Return as hex string for better security
    return string_format("%08x", hash)
end

-- Generate a nonce for replay protection
local function GenerateNonce()
    return string_format("%d:%d", time(), math.random(1000000, 9999999))
end

local function ValidatePayload(payload, sender)
    if not payload then return false, "No payload" end
    if not payload.version or payload.version ~= 2 then 
        -- Version 2 uses secure hash, version 1 is deprecated
        return false, "Invalid version (must be 2)" 
    end
    if not payload.timestamp or not payload.achievementId or not payload.targetCharacter or not payload.nonce then 
        return false, "Missing required fields" 
    end
    
    -- SECURITY: Get secret key from database
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        return false, "Admin secret key not configured"
    end
    
    -- Check payload age (prevent replay attacks)
    local currentTime = time()
    if currentTime - payload.timestamp > MAX_PAYLOAD_AGE then 
        return false, "Payload too old (max 5 minutes)" 
    end
    if payload.timestamp > currentTime + 120 then
        return false, "Payload timestamp too far in future"
    end
    
    -- SECURITY: Validate secure hash
    local expectedHash = CreateSecureHash(payload, secretKey)
    if not expectedHash or payload.validationHash ~= expectedHash then 
        return false, "Invalid authentication hash" 
    end
    
    -- SECURITY: Check nonce to prevent replay attacks
    -- Store used nonces in database (with expiration)
    if not addon or not addon.HardcoreAchievementsDB then return false, "Database not initialized" end
    if not addon.HardcoreAchievementsDB.adminNonces then
        addon.HardcoreAchievementsDB.adminNonces = {}
    end
    
    -- Clean old nonces (older than MAX_PAYLOAD_AGE)
    local noncesToRemove = {}
    for nonce, nonceTime in pairs(addon.HardcoreAchievementsDB.adminNonces) do
        if currentTime - nonceTime > MAX_PAYLOAD_AGE then
            table_insert(noncesToRemove, nonce)
        end
    end
    for _, nonce in ipairs(noncesToRemove) do
        addon.HardcoreAchievementsDB.adminNonces[nonce] = nil
    end
    
    -- Check if nonce was already used (replay attack)
    if addon.HardcoreAchievementsDB.adminNonces[payload.nonce] then
        return false, "Nonce already used (replay attack detected)"
    end
    
    -- Store nonce to prevent reuse
    addon.HardcoreAchievementsDB.adminNonces[payload.nonce] = currentTime
    
    return true, "Valid"
end

local function FindAchievementRow(achievementId)
    if not achievementId then return nil end
    local achStr = tostring(achievementId)
    local panel = addon and addon.AchievementPanel
    if panel and panel.achievements then
        for _, row in ipairs(panel.achievements) do
            local rid = row.id or row.achId
            if rid and (rid == achievementId or tostring(rid) == achStr) then
                return row
            end
        end
    end
    if addon and addon.GetAchievementRow then
        return addon.GetAchievementRow(achievementId)
    end
    return nil
end

local function SendResponseToAdmin(sender, message)
    -- Send response back to admin via AceComm (hidden)
    local responsePayload = {
        type = "admin_response",
        message = message,
        timestamp = time(),
        targetCharacter = UnitName("player")
    }
    
    local serializedResponse = AceSerialize:Serialize(responsePayload)
    if serializedResponse then
        AceComm:SendCommMessage(RESPONSE_PREFIX, serializedResponse, "WHISPER", sender)
    end
end

-- SECURITY: Handle delete achievement command
-- This command removes an achievement from the player's database
local function ProcessDeleteAchievementCommand(payload, sender)
    -- Check if target character matches current player
    local currentCharacter = UnitName("player")
    if payload.targetCharacter ~= currentCharacter then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Delete achievement command rejected: Target character mismatch")
        return false
    end
    
    -- Find the achievement row
    local achievementRow = FindAchievementRow(payload.achievementId)
    if not achievementRow then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Delete achievement command rejected: Achievement not found")
        return false
    end
    
    local _, cdb = addon.GetCharDB()
    if not cdb then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Failed to delete achievement: Database not initialized")
        return false
    end
    
    local id = achievementRow.id or achievementRow.achId
    if not id then id = payload.achievementId end
    local hadAchievement = false
    
    -- Check if achievement exists in database
    if cdb.achievements and cdb.achievements[id] then
        hadAchievement = true
    end
    
    -- Delete achievement from database
    cdb.achievements = cdb.achievements or {}
    cdb.achievements[id] = nil
    
    -- Clear progress for this achievement
    if cdb.progress then
        cdb.progress[id] = nil
    end
    
    -- Tombstone (only when permanent): prevent GuildFirst onChange from re-awarding if claim syncs back
    if payload.permanent then
        cdb.deletedByAdmin = cdb.deletedByAdmin or {}
        cdb.deletedByAdmin[id] = true
    end
    
    -- Reset UI row to initial state
    achievementRow.completed = false
    
    -- Reset points to original value
    if achievementRow.originalPoints then
        achievementRow.points = achievementRow.originalPoints
    elseif achievementRow._def and achievementRow._def.points then
        achievementRow.points = achievementRow._def.points
    else
        achievementRow.points = 0
    end
    
    -- Reset UI elements
    if achievementRow.Points then
        achievementRow.Points:SetText(tostring(achievementRow.points))
        achievementRow.Points:SetTextColor(1, 1, 1)
    end
    
    if achievementRow.TS then
        achievementRow.TS:SetText("")
        achievementRow.TS:SetTextColor(1, 1, 1)
    end
    
    -- Reset sub text to default
    if achievementRow.Sub then
        local defaultSub = achievementRow._defaultSubText or ""
        achievementRow.Sub:SetText(defaultSub)
    end
    
    -- Reset icon/frame styling
    if addon and type(addon.ApplyOutleveledStyle) == "function" then
        addon.ApplyOutleveledStyle(achievementRow)
    elseif type(ApplyOutleveledStyle) == "function" then
        ApplyOutleveledStyle(achievementRow)
    end
    
    -- Update total points
    if addon and type(addon.UpdateTotalPoints) == "function" then
        addon.UpdateTotalPoints()
    end
    
    -- Reapply filter so hiddenUntilComplete rows get hidden, visibility recalculated, rows repositioned
    if addon and type(addon.ApplyFilter) == "function" then
        addon.ApplyFilter()
    end
    
    -- Clear progress (if function exists)
    if addon and type(addon.ClearProgress) == "function" then
        addon.ClearProgress(id)
    end
    
    -- Log the action
    if not addon.HardcoreAchievementsDB.adminCommands then addon.HardcoreAchievementsDB.adminCommands = {} end
    table_insert(addon.HardcoreAchievementsDB.adminCommands, {
        timestamp = time(),
        commandType = "delete_achievement",
        achievementId = payload.achievementId,
        sender = sender,
        targetCharacter = payload.targetCharacter,
        nonce = payload.nonce,
        payloadHash = payload.validationHash,
        hadAchievement = hadAchievement
    })
    
    -- Keep only last 100 commands
    if #addon.HardcoreAchievementsDB.adminCommands > 100 then
        table_remove(addon.HardcoreAchievementsDB.adminCommands, 1)
    end
    
    SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' deleted successfully")
    return true
end

-- Handle clear deletedByAdmin (unban) - allows player to earn the achievement again
local function ProcessClearDeletedByAdminCommand(payload, sender)
    local currentCharacter = UnitName("player")
    if payload.targetCharacter ~= currentCharacter then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Unban command rejected: Target character mismatch")
        return false
    end

    local achievementId = payload.achievementId and tostring(payload.achievementId):trim()
    if not achievementId or achievementId == "" then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Unban command rejected: Achievement ID required")
        return false
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Failed to unban: Database not initialized")
        return false
    end

    cdb.deletedByAdmin = cdb.deletedByAdmin or {}
    local hadEntry = cdb.deletedByAdmin[achievementId]
    cdb.deletedByAdmin[achievementId] = nil

    if hadEntry then
        SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Achievement '" .. achievementId .. "' unbanned for " .. currentCharacter .. " - player can earn again")
        --print("|cff00ff00[Hardcore Achievements]|r Achievement '" .. achievementId .. "' has been unbanned - you can earn it again")
    else
        SendResponseToAdmin(sender, "|CFFFFD100[Hardcore Achievements]|r Achievement '" .. achievementId .. "' was not banned for " .. currentCharacter)
    end

    return true
end

-- SECURITY: Handle clear secret key command
-- This command validates using the secret key, then clears it
local function ProcessClearSecretKeyCommand(payload, sender)
    -- Check if target character matches current player
    local currentCharacter = UnitName("player")
    if payload.targetCharacter ~= currentCharacter then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Clear key command rejected: Target character mismatch")
        return false
    end
    
    -- Check if key exists before clearing (for idempotency)
    local hadKey = false
    if addon.HardcoreAchievementsDB and addon.HardcoreAchievementsDB.adminSecretKey and addon.HardcoreAchievementsDB.adminSecretKey ~= "" then
        hadKey = true
    end
    
    -- Clear the secret key
    if addon.HardcoreAchievementsDB then
        addon.HardcoreAchievementsDB.adminSecretKey = nil
        
        -- Also clear admin nonces to prevent any issues
        if addon.HardcoreAchievementsDB.adminNonces then
            addon.HardcoreAchievementsDB.adminNonces = {}
        end
        
        -- Log the action
        if not addon.HardcoreAchievementsDB.adminCommands then addon.HardcoreAchievementsDB.adminCommands = {} end
        table_insert(addon.HardcoreAchievementsDB.adminCommands, {
            timestamp = time(),
            commandType = "clear_secret_key",
            sender = sender,
            targetCharacter = payload.targetCharacter,
            nonce = payload.nonce,
            hadKey = hadKey
        })
        
        -- Keep only last 100 commands
        if #addon.HardcoreAchievementsDB.adminCommands > 100 then
            table_remove(addon.HardcoreAchievementsDB.adminCommands, 1)
        end
        
        if hadKey then
            SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Secret key cleared successfully for " .. currentCharacter)
            print("|cffff0000[Hardcore Achievements]|r Your admin secret key has been cleared by the admin. This is intentional, to prevent you from receiving admin commands unless you set another key.")
        else
            SendResponseToAdmin(sender, "|CFFFFD100[Hardcore Achievements]|r Secret key was not set for " .. currentCharacter .. " (already cleared)")
        end
        return true
    else
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Failed to clear secret key: Database not initialized")
        return false
    end
end

local function ProcessAdminCommand(payload, sender)
    -- Check if this is a delete achievement command
    if payload.commandType == "delete_achievement" then
        -- Validate the payload (includes secret key verification)
        local isValid, reason = ValidatePayload(payload, sender)
        if not isValid then
            SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Delete achievement command rejected: " .. reason)
            return false
        end
        
        -- Validation passed, proceed to delete the achievement
        return ProcessDeleteAchievementCommand(payload, sender)
    end
    
    -- Check if this is a clear deletedByAdmin (unban) command
    if payload.commandType == "clear_deleted_by_admin" then
        local isValid, reason = ValidatePayload(payload, sender)
        if not isValid then
            SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Unban command rejected: " .. reason)
            return false
        end
        return ProcessClearDeletedByAdminCommand(payload, sender)
    end

    -- Check if this is a clear secret key command
    if payload.commandType == "clear_secret_key" then
        -- For clear key commands, we must validate the payload first
        -- The validation uses the current secret key (which will be cleared after validation)
        local isValid, reason = ValidatePayload(payload, sender)
        if not isValid then
            -- If validation fails because key is not configured, that's okay (key already cleared)
            -- But if it fails for other reasons (invalid hash, etc.), reject it
            if reason == "Admin secret key not configured" then
                -- Key is already cleared, return success (idempotent operation)
                SendResponseToAdmin(sender, "|CFFFFD100[Hardcore Achievements]|r Secret key was already cleared for " .. payload.targetCharacter)
                return true
            else
                SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Clear key command rejected: " .. reason)
                return false
            end
        end
        
        -- Validation passed, proceed to clear the key
        return ProcessClearSecretKeyCommand(payload, sender)
    end
    
    -- SECURITY: Validate the payload (includes secret key verification)
    local isValid, reason = ValidatePayload(payload, sender)
    if not isValid then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Admin command rejected: " .. reason)
        return false
    end
    
    -- Check if target character matches current player
    local currentCharacter = UnitName("player")
    if payload.targetCharacter ~= currentCharacter then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Admin command rejected: Target character mismatch")
        return false
    end
    
    -- Find the achievement row
    local achievementRow = FindAchievementRow(payload.achievementId)
    if not achievementRow then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Admin command rejected: Achievement not found")
        return false
    end
    
	-- Use shared FormatTimestamp function for consistent date formatting

	-- If already completed, allow forced update when flagged
	if achievementRow.completed then
		if payload.forceUpdate then
			local _, cdb = addon.GetCharDB()
			if cdb then
				cdb.achievements = cdb.achievements or {}
				local id = achievementRow.id
				local rec = cdb.achievements[id] or {}
				rec.completed = true
				-- Preserve existing completion timestamp if present; otherwise set now
				if not rec.completedAt then
					rec.completedAt = time()
				end
				
				-- Handle solo flag
				if payload.solo then
					rec.wasSolo = true
				end
				
				-- Use overridePoints if provided, otherwise keep existing points
				local newPoints = tonumber(payload.overridePoints) or rec.points or achievementRow.points or 0
				
				rec.points = newPoints
				-- Use overrideLevel if provided, otherwise keep existing or UnitLevel("player")
				local newLevel = tonumber(payload.overrideLevel) or rec.level or (UnitLevel("player") or nil)
				rec.level = newLevel
				-- Clear failed status when manually awarding achievement
				rec.failed = nil
				rec.failedAt = nil
				cdb.achievements[id] = rec
				-- Reflect in UI
				achievementRow.points = newPoints
				if achievementRow.Points then
					achievementRow.Points:SetText(tostring(newPoints))
					achievementRow.Points:SetTextColor(0.6, 0.9, 0.6)
				end
				if achievementRow.TS then
					local fmtTs = (addon and addon.FormatTimestamp) or FormatTimestamp
					achievementRow.TS:SetText(fmtTs(rec.completedAt))
				end
				-- Update solo status in UI if applicable
				if payload.solo and achievementRow.Sub then
					local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
					local allowSoloBonus = IsSelfFound() or not isHardcoreActive
					if allowSoloBonus then
                        local ClassColor = (addon and addon.ClassColor())
						achievementRow.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n" .. ClassColor .. "Solo|r")
					end
				end
				if addon and type(addon.UpdateTotalPoints) == "function" then
					addon.UpdateTotalPoints()
				end
				-- Toast to indicate update
				local showToast = (addon and addon.CreateAchToast)
				if type(showToast) == "function" then
					local iconTex = (achievementRow.Icon and achievementRow.Icon.GetTexture) and achievementRow.Icon:GetTexture() or achievementRow.icon or 134400
					local titleText = (achievementRow.Title and achievementRow.Title.GetText) and achievementRow.Title:GetText() or achievementRow.title or "Achievement"
					showToast(iconTex, titleText, newPoints)
				end
				SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' updated via admin command")
				return true
			end
		else
			SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Admin command rejected: Achievement already completed")
			return false
		end
	end

	-- Not completed yet: optionally override points before completion
	if payload.overridePoints then
		local p = tonumber(payload.overridePoints)
		if p and p > 0 then
			achievementRow.points = p
			if achievementRow.Points then
				achievementRow.Points:SetText(tostring(p))
			end
		end
	end

	-- If solo flag is set, we need to set up progress data before completion
	-- This ensures HCA_MarkRowCompleted recognizes it as solo and doubles points if applicable
	if payload.solo then
		local _, cdb = addon.GetCharDB()
		if cdb then
			cdb.progress = cdb.progress or {}
			local id = achievementRow.id
			local progress = cdb.progress[id] or {}
			
			-- Set solo status in progress (this is what HCA_MarkRowCompleted checks)
			progress.soloKill = true
			progress.soloQuest = true
			
			-- If override points provided, use those (don't double even if solo)
			local overridePts = tonumber(payload.overridePoints)
			if overridePts and overridePts > 0 then
				if IsSelfFound() then
					-- pointsAtKill is stored WITHOUT the self-found bonus, so strip it from the override.
					-- 0-point achievements naturally strip 0.
					local getBonus = addon and addon.GetSelfFoundBonus
					local baseForBonus = achievementRow.originalPoints or achievementRow.revealPointsBase or 0
					local bonus = (type(getBonus) == "function") and getBonus(baseForBonus) or 0
					if bonus > 0 and overridePts > 0 then
						overridePts = overridePts - bonus
					end
				end
				progress.pointsAtKill = overridePts
			-- Otherwise, if achievement allows solo doubling, calculate and store pointsAtKill
			elseif achievementRow.allowSoloDouble and not achievementRow.staticPoints then
				local basePoints = tonumber(achievementRow.originalPoints) or tonumber(achievementRow.points) or 0
				-- Apply preset multiplier if not static
				if not achievementRow.staticPoints then
					local preset = addon and addon.GetPlayerPresetFromSettings and addon.GetPlayerPresetFromSettings() or nil
					local multiplier = GetPresetMultiplier(preset) or 1.0
					basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
				end
				-- Double for solo (pointsAtKill stores without self-found bonus)
				progress.pointsAtKill = basePoints * 2
			end
			
			cdb.progress[id] = progress
		end
	end

	-- Complete the achievement
	local markComplete = (addon and addon.MarkRowCompleted)
	if type(markComplete) == "function" then
		markComplete(achievementRow)
	end
	
	-- Clear failed status when manually awarding achievement
	local _, cdb = addon.GetCharDB()
	if cdb then
		cdb.achievements = cdb.achievements or {}
		local id = achievementRow.id
		local rec = cdb.achievements[id]
		if rec then
			rec.failed = nil
			rec.failedAt = nil
		end
	end
	
	-- Optionally override level after completion (if provided)
	if payload.overrideLevel then
		local lvl = tonumber(payload.overrideLevel)
		if lvl then
			local _, cdb = addon.GetCharDB()
			if cdb then
				cdb.achievements = cdb.achievements or {}
				local id = achievementRow.id
				local rec = cdb.achievements[id]
				if rec then
					rec.level = lvl
					cdb.achievements[id] = rec
				end
			end
		end
	end
	
	-- Show achievement toast
	local showToast = (addon and addon.CreateAchToast)
	if type(showToast) == "function" then
		local iconTex = (achievementRow.Icon and achievementRow.Icon.GetTexture) and achievementRow.Icon:GetTexture() or achievementRow.icon or 134400
		local titleText = (achievementRow.Title and achievementRow.Title.GetText) and achievementRow.Title:GetText() or achievementRow.title or "Achievement"
		showToast(iconTex, titleText, achievementRow.points)
	end
	
	SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' completed via admin command")
    
    -- Log the admin command (for audit trail)
    if not addon.HardcoreAchievementsDB.adminCommands then addon.HardcoreAchievementsDB.adminCommands = {} end
    
    table_insert(addon.HardcoreAchievementsDB.adminCommands, {
        timestamp = time(),
        achievementId = payload.achievementId,
        sender = sender,
        targetCharacter = payload.targetCharacter,
        nonce = payload.nonce,
        payloadHash = payload.validationHash,
        solo = payload.solo and true or false
    })
    
    -- Keep only last 100 commands to prevent database bloat
    if #addon.HardcoreAchievementsDB.adminCommands > 100 then
        table_remove(addon.HardcoreAchievementsDB.adminCommands, 1)
    end
    
    return true
end

-- AceComm handler for admin commands
local function OnCommReceived(prefix, message, distribution, sender)
    -- Check if this is our admin command prefix
    if prefix ~= COMM_PREFIX then return end
    
    -- Deserialize the payload
    local success, payload = AceSerialize:Deserialize(message)
    if not success then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Failed to deserialize admin command")
        return
    end
    
    -- Process the admin command
    ProcessAdminCommand(payload, sender)
end

-- AceComm handler for Precious completion messages
local function OnPreciousCompletedMessage(prefix, message, distribution, sender)
    -- Deserialize the message
    local success, payload = AceSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "precious_completed" then
        return
    end
    
    -- Don't notify the player who completed Precious
    local playerName = UnitName("player")
    if payload.playerName == playerName or sender == playerName then
        DebugPrint("Precious completion message ignored (from self)")
        return
    end
    
    DebugPrint("Precious completion message received from " .. tostring(sender))
    
    -- Call all registered callbacks
    for _, callback in ipairs(preciousCompletionCallbacks) do
        if type(callback) == "function" then
            local ok, err = pcall(callback, payload, sender)
            if not ok then
                DebugPrint("Error in Precious completion callback: " .. tostring(err))
            end
        end
    end
end

-- Initialize the handler
local function InitializeAdminCommandHandler()
    -- Register AceComm handlers
    AceComm:RegisterComm(COMM_PREFIX, OnCommReceived)
    AceComm:RegisterComm(PRECIOUS_COMPLETE_PREFIX, OnPreciousCompletedMessage)
end

-- Slash command handler
local function HandleSlashCommand(msg)
    local args = {}
    for arg in string_gmatch(msg or "", "%S+") do
        table_insert(args, arg)
    end
    local command = args[1] and string.lower(args[1]) or ""
    
    if command == "show" then
        -- Set database flag to show custom tab
        do
            local _, cdb = (addon and addon.GetCharDB and addon.GetCharDB()) or nil
            if cdb then cdb.showCustomTab = true end
        end
        
        -- Immediately show the custom tab
        local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
        if tab and tab:GetText() and tab:GetText():find("Achievements") then
            tab:Show()
            tab:SetScript("OnClick", function(self)
                local showTab = (addon and (addon.ShowAchievementTab or addon.ShowAchievementWindow))
                if type(showTab) == "function" then
                    showTab()
                end
            end)
            print("|cff008066[Hardcore Achievements]|r Custom achievement tab enabled and shown")
        end
    elseif command == "reset" and args[2] == "tab" then
        if addon and addon.ResetTabPosition then
            addon.ResetTabPosition()
        end
    elseif command == "adminkey" then
        -- SECURITY: Set admin secret key for secure command authentication
        if args[2] == "set" and args[3] then
            local key = args[3]
            if #key >= 16 then
                if SetAdminSecretKey(key) then
                    print("|cff00ff00[Hardcore Achievements]|r Admin secret key set successfully")
                    print("|CFFFFD100[Hardcore Achievements]|r Keep this key secret! Anyone with this key can send admin commands.")
                    if addon and addon.UpdateKeyStatus then
                        UpdateKeyStatus()
                    end
                else
                    print("|cffff0000[Hardcore Achievements]|r Failed to set admin secret key")
                end
            else
                print("|cffff0000[Hardcore Achievements]|r Admin secret key must be at least 16 characters long")
            end
        elseif args[2] == "check" then
            local key = GetAdminSecretKey()
            if key and key ~= "" then
                print("|cff00ff00[Hardcore Achievements]|r Admin secret key is set (length: " .. #key .. ")")
            else
                print("|cffff0000[Hardcore Achievements]|r Admin secret key is NOT set")
                print("|CFFFFD100[Hardcore Achievements]|r Use: /hca adminkey set <your-secret-key-here>")
                print("|CFFFFD100[Hardcore Achievements]|r Key must be at least 16 characters long")
            end
        elseif args[2] == "clear" then
            if addon.HardcoreAchievementsDB then
                addon.HardcoreAchievementsDB.adminSecretKey = nil
                print("|cff00ff00[Hardcore Achievements]|r Admin secret key cleared")
                if addon and addon.UpdateKeyStatus then
                    UpdateKeyStatus()
                end
            end
        else
            print("|cff00ff00[Hardcore Achievements]|r Admin key commands:")
            print("  |CFFFFD100/hca adminkey set <key>|r - Set admin secret key (min 16 chars)")
            print("  |CFFFFD100/hca adminkey check|r - Check if admin key is set")
            print("  |CFFFFD100/hca adminkey clear|r - Clear admin secret key")
        end
    elseif command == "tracker" then
        -- Tracker commands
        local subcommand = args[2] and string.lower(args[2]) or ""
        
        if not AchievementTracker then
            print("|cff008066[Hardcore Achievements]|r Achievement tracker not loaded yet. Please wait a moment and try again, or reload your UI.")
            return
        end
        
        if subcommand == "show" then
            if AchievementTracker.Show then
                AchievementTracker:Show()
                print("|cff008066[Hardcore Achievements]|r Achievement tracker shown")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        elseif subcommand == "hide" then
            if AchievementTracker.Hide then
                AchievementTracker:Hide()
                print("|cff008066[Hardcore Achievements]|r Achievement tracker hidden")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        elseif subcommand == "toggle" then
            if AchievementTracker.Toggle then
                AchievementTracker:Toggle()
                print("|cff008066[Hardcore Achievements]|r Achievement tracker toggled")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        else
            print("|cff008066[Hardcore Achievements]|r Tracker commands:")
            print("  |CFFFFD100/hca tracker show|r - Show the achievement tracker")
            print("  |CFFFFD100/hca tracker hide|r - Hide the achievement tracker")
            print("  |CFFFFD100/hca tracker toggle|r - Toggle the achievement tracker")
        end
    elseif command == "debug" then
        -- Debug toggle command
        if args[2] and string.lower(args[2]) == "on" then
            SetDebugEnabled(true)
            print("|cff008066[Hardcore Achievements]|r Debug mode enabled")
            if addon and addon.DebugPrint then addon.DebugPrint("Debug mode is now ON - you will see debug messages") end
        elseif args[2] and string.lower(args[2]) == "off" then
            SetDebugEnabled(false)
            print("|cff008066[Hardcore Achievements]|r Debug mode disabled")
        else
            -- Toggle if no argument provided
            local currentState = GetDebugEnabled()
            SetDebugEnabled(not currentState)
            if not currentState then
                print("|cff008066[Hardcore Achievements]|r Debug mode enabled")
                if addon and addon.DebugPrint then addon.DebugPrint("Debug mode is now ON - you will see debug messages") end
            else
                print("|cff008066[Hardcore Achievements]|r Debug mode disabled")
            end
        end
    else
        print("|cff008066[Hardcore Achievements]|r Available commands:")
        print("  |CFFFFD100/hca show|r - Enable and show the custom achievement tab")
        print("  |CFFFFD100/hca reset tab|r - Reset the tab position to default")
        print("  |CFFFFD100/hca tracker|r - Manage the achievement tracker")
        print("  |CFFFFD100/hca debug|r - Toggle debug mode (on/off)")
        --print("  |CFFFFD100/hca adminkey|r - Manage admin secret key for secure commands")
    end
end

-- Register slash command
SLASH_HARDCOREAchievements1 = "/hca"
SLASH_HARDCOREAchievements2 = "/hardcoreachievements"
SlashCmdList["HARDCOREAchievements"] = HandleSlashCommand

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeAdminCommandHandler()
        self:UnregisterAllEvents()
    end
end)

-- Export functions for admin panel (if needed)
AdminCommandHandler.CreateSecureHash = CreateSecureHash
AdminCommandHandler.GetAdminSecretKey = GetAdminSecretKey
AdminCommandHandler.GenerateNonce = GenerateNonce

-- =========================================================
-- Precious Completion Communication (Regular Feature)
-- These functions are NOT admin-related and are available to all players
-- =========================================================

-- Helper function to send Precious completion notification via SAY channel
-- This notifies nearby players (within chat range) so they can complete Fellowship
local function SendPreciousCompletionMessage()
    local messagePayload = {
        type = "precious_completed",
        playerName = UnitName("player")
    }
    
    local serializedMessage = AceSerialize:Serialize(messagePayload)
    if serializedMessage then
        AceComm:SendCommMessage(PRECIOUS_COMPLETE_PREFIX, serializedMessage, "SAY")
        if DebugPrint then DebugPrint("Precious completion message sent") end
    end
end

-- Register a callback to be called when Precious completion message is received
-- Callback signature: function(payload, sender) where payload contains {type, playerName}
local function RegisterPreciousCompletionCallback(callback)
    if type(callback) == "function" then
        table_insert(preciousCompletionCallbacks, callback)
    end
end

-- Helper function to create a secure admin command payload
-- This is what the admin panel should use to send commands
local function CreateAdminPayload(targetCharacter, achievementId, overridePoints, overrideLevel, forceUpdate)
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        error("Admin secret key not set! Use /hca adminkey set <key> first")
    end
    
    local payload = {
        version = 2,  -- Version 2 uses secure hash
        timestamp = time(),
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        nonce = GenerateNonce(),
        overridePoints = overridePoints,
        overrideLevel = overrideLevel,
        forceUpdate = forceUpdate
    }
    
    -- Create secure hash using secret key
    payload.validationHash = CreateSecureHash(payload, secretKey)
    
    if not payload.validationHash then
        error("Failed to create secure hash")
    end
    
    return payload
end

AdminCommandHandler.CreateAdminPayload = CreateAdminPayload

if addon then
    addon.AdminCommandHandler = AdminCommandHandler
    addon.SendPreciousCompletionMessage = SendPreciousCompletionMessage
    addon.RegisterPreciousCompletionCallback = RegisterPreciousCompletionCallback
end
