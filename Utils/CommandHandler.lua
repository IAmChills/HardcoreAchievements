-- CommandHandler.lua
-- Client-side handler for processing admin commands via whispers
-- This file should be included in all versions of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

-- Reference to AchievementTracker (loaded via TOC, get it lazily)
local function GetAchievementTracker()
    return _G.HardcoreAchievementsTracker
end

local AdminCommandHandler = {}
local COMM_PREFIX = "HCA_Admin_Cmd" -- AceComm prefix for admin commands
local RESPONSE_PREFIX = "HCA_Admin_Resp" -- AceComm prefix for responses (max 16 chars)
local MAX_PAYLOAD_AGE = 300 -- 5 minutes in seconds

-- Debug system: Helper functions for debug messages
local function GetDebugEnabled()
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    return HardcoreAchievementsDB.debugEnabled or false
end

local function SetDebugEnabled(enabled)
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    HardcoreAchievementsDB.debugEnabled = enabled and true or false
end

-- Global debug print function (exported)
function _G.HCA_DebugPrint(message)
    if GetDebugEnabled() then
        print("|cff11806a[HCA DEBUG]|r |cffffd100" .. tostring(message) .. "|r")
    end
end

-- SECURITY: Get admin secret key from database (set by admin via slash command)
-- This key is NOT in source code and must be set by the admin
local function GetAdminSecretKey()
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    return HardcoreAchievementsDB.adminSecretKey
end

-- SECURITY: Set admin secret key (only accessible via slash command)
local function SetAdminSecretKey(key)
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    if key and #key >= 16 then
        HardcoreAchievementsDB.adminSecretKey = key
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
    
    -- Create message to sign: all critical fields in canonical order
    local message = string.format("%d:%d:%s:%s:%s",
        payload.version or 0,
        payload.timestamp or 0,
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
        local byte = string.byte(combined, i)
        hash = ((hash * prime1) + byte * prime2) % 2147483647
        hash = (hash + (byte * i * prime1)) % 2147483647
    end
    
    -- Combine with secret key length for additional entropy
    hash = (hash * #secretKey) % 2147483647
    
    -- Return as hex string for better security
    return string.format("%08x", hash)
end

-- Generate a nonce for replay protection
local function GenerateNonce()
    return string.format("%d:%d", time(), math.random(1000000, 9999999))
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
    if not HardcoreAchievementsDB.adminNonces then
        HardcoreAchievementsDB.adminNonces = {}
    end
    
    -- Clean old nonces (older than MAX_PAYLOAD_AGE)
    local noncesToRemove = {}
    for nonce, nonceTime in pairs(HardcoreAchievementsDB.adminNonces) do
        if currentTime - nonceTime > MAX_PAYLOAD_AGE then
            table.insert(noncesToRemove, nonce)
        end
    end
    for _, nonce in ipairs(noncesToRemove) do
        HardcoreAchievementsDB.adminNonces[nonce] = nil
    end
    
    -- Check if nonce was already used (replay attack)
    if HardcoreAchievementsDB.adminNonces[payload.nonce] then
        return false, "Nonce already used (replay attack detected)"
    end
    
    -- Store nonce to prevent reuse
    HardcoreAchievementsDB.adminNonces[payload.nonce] = currentTime
    
    return true, "Valid"
end

local function FindAchievementRow(achievementId)
    if not AchievementPanel or not AchievementPanel.achievements then return nil end
    
    for _, row in ipairs(AchievementPanel.achievements) do
        if row.id == achievementId then
            return row
        end
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
    
    local _, cdb = HardcoreAchievements_GetCharDB()
    if not cdb then
        SendResponseToAdmin(sender, "|cffff0000[Hardcore Achievements]|r Failed to delete achievement: Database not initialized")
        return false
    end
    
    local id = achievementRow.id
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
    if type(ApplyOutleveledStyle) == "function" then
        ApplyOutleveledStyle(achievementRow)
    end
    
    -- Update total points
    if type(HCA_UpdateTotalPoints) == "function" then
        HCA_UpdateTotalPoints()
    end
    
    -- Clear progress (if function exists)
    if type(HardcoreAchievements_ClearProgress) == "function" then
        HardcoreAchievements_ClearProgress(id)
    end
    
    -- Log the action
    if not HardcoreAchievementsDB.adminCommands then HardcoreAchievementsDB.adminCommands = {} end
    table.insert(HardcoreAchievementsDB.adminCommands, {
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
    if #HardcoreAchievementsDB.adminCommands > 100 then
        table.remove(HardcoreAchievementsDB.adminCommands, 1)
    end
    
    if hadAchievement then
        SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' deleted successfully for " .. currentCharacter)
        print("|cffff0000[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' has been deleted by admin")
    else
        SendResponseToAdmin(sender, "|cffffff00[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' was not in database for " .. currentCharacter .. " (already deleted)")
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
    if HardcoreAchievementsDB and HardcoreAchievementsDB.adminSecretKey and HardcoreAchievementsDB.adminSecretKey ~= "" then
        hadKey = true
    end
    
    -- Clear the secret key
    if HardcoreAchievementsDB then
        HardcoreAchievementsDB.adminSecretKey = nil
        
        -- Also clear admin nonces to prevent any issues
        if HardcoreAchievementsDB.adminNonces then
            HardcoreAchievementsDB.adminNonces = {}
        end
        
        -- Log the action
        if not HardcoreAchievementsDB.adminCommands then HardcoreAchievementsDB.adminCommands = {} end
        table.insert(HardcoreAchievementsDB.adminCommands, {
            timestamp = time(),
            commandType = "clear_secret_key",
            sender = sender,
            targetCharacter = payload.targetCharacter,
            nonce = payload.nonce,
            hadKey = hadKey
        })
        
        -- Keep only last 100 commands
        if #HardcoreAchievementsDB.adminCommands > 100 then
            table.remove(HardcoreAchievementsDB.adminCommands, 1)
        end
        
        if hadKey then
            SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Secret key cleared successfully for " .. currentCharacter)
            print("|cffff0000[Hardcore Achievements]|r Your admin secret key has been cleared by the admin. This is intentional, to prevent you from receiving admin commands unless you set another key.")
        else
            SendResponseToAdmin(sender, "|cffffff00[Hardcore Achievements]|r Secret key was not set for " .. currentCharacter .. " (already cleared)")
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
                SendResponseToAdmin(sender, "|cffffff00[Hardcore Achievements]|r Secret key was already cleared for " .. payload.targetCharacter)
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
			local _, cdb = HardcoreAchievements_GetCharDB()
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
					achievementRow.TS:SetText(FormatTimestamp(rec.completedAt))
				end
				-- Update solo status in UI if applicable
				if payload.solo and achievementRow.Sub then
					local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
					local isTBC = GetExpansionLevel() > 0
					local allowSoloBonus = isSelfFound or isTBC
					if allowSoloBonus then
						achievementRow.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n|c" .. select(4, GetClassColor(select(2, UnitClass("player")))) .. "Solo|r")
					end
				end
				if type(HCA_UpdateTotalPoints) == "function" then
					HCA_UpdateTotalPoints()
				end
				-- Toast to indicate update
				HCA_AchToast_Show(achievementRow.Icon:GetTexture(), achievementRow.Title:GetText(), newPoints)
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
		local _, cdb = HardcoreAchievements_GetCharDB()
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
				local isSelfFound = _G.IsSelfFound and _G.IsSelfFound() or false
				if isSelfFound and not achievementRow.isSecretAchievement then
					-- pointsAtKill is stored WITHOUT the self-found bonus, so strip it from the override.
					local getBonus = _G.HCA_GetSelfFoundBonus
					local bonus = (type(getBonus) == "function") and getBonus(achievementRow.originalPoints or 0) or 0
					overridePts = overridePts - bonus
				end
				progress.pointsAtKill = overridePts
			-- Otherwise, if achievement allows solo doubling, calculate and store pointsAtKill
			elseif achievementRow.allowSoloDouble and not achievementRow.staticPoints then
				local basePoints = tonumber(achievementRow.originalPoints) or tonumber(achievementRow.points) or 0
				-- Apply preset multiplier if not static
				if not achievementRow.staticPoints then
					local preset = _G.GetPlayerPresetFromSettings and _G.GetPlayerPresetFromSettings() or nil
					local multiplier = _G.GetPresetMultiplier and _G.GetPresetMultiplier(preset) or 1.0
					basePoints = basePoints + math.floor((basePoints) * (multiplier - 1) + 0.5)
				end
				-- Double for solo (pointsAtKill stores without self-found bonus)
				progress.pointsAtKill = basePoints * 2
			end
			
			cdb.progress[id] = progress
		end
	end

	-- Complete the achievement
	HCA_MarkRowCompleted(achievementRow)
	
	-- Clear failed status when manually awarding achievement
	local _, cdb = HardcoreAchievements_GetCharDB()
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
			local _, cdb = HardcoreAchievements_GetCharDB()
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
	HCA_AchToast_Show(achievementRow.Icon:GetTexture(), achievementRow.Title:GetText(), achievementRow.points)
	
	SendResponseToAdmin(sender, "|cff00ff00[Hardcore Achievements]|r Achievement '" .. payload.achievementId .. "' completed via admin command")
    
    -- Log the admin command (for audit trail)
    if not HardcoreAchievementsDB.adminCommands then HardcoreAchievementsDB.adminCommands = {} end
    
    table.insert(HardcoreAchievementsDB.adminCommands, {
        timestamp = time(),
        achievementId = payload.achievementId,
        sender = sender,
        targetCharacter = payload.targetCharacter,
        nonce = payload.nonce,
        payloadHash = payload.validationHash,
        solo = payload.solo and true or false
    })
    
    -- Keep only last 100 commands to prevent database bloat
    if #HardcoreAchievementsDB.adminCommands > 100 then
        table.remove(HardcoreAchievementsDB.adminCommands, 1)
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

-- Initialize the handler
local function InitializeAdminCommandHandler()
    -- Register AceComm handler
    AceComm:RegisterComm(COMM_PREFIX, OnCommReceived)
end

-- Slash command handler
local function HandleSlashCommand(msg)
    local args = {}
    for arg in string.gmatch(msg or "", "%S+") do
        table.insert(args, arg)
    end
    local command = args[1] and string.lower(args[1]) or ""
    
    if command == "show" then
        -- Set database flag to show custom tab
        do
            local _, cdb = HardcoreAchievements_GetCharDB and HardcoreAchievements_GetCharDB() or nil
            if cdb then cdb.showCustomTab = true end
        end
        
        -- Immediately show the custom tab
        local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
        if tab and tab:GetText() and tab:GetText():find("Achievements") then
            tab:Show()
            tab:SetScript("OnClick", function(self)
                if HCA_ShowAchievementTab then
                    HCA_ShowAchievementTab()
                end
            end)
            print("|cff00ff00[Hardcore Achievements]|r Custom achievement tab enabled and shown")
        else
            print("|cffff0000[Hardcore Achievements]|r Custom achievement tab not found")
        end
    elseif command == "reset" and args[2] == "tab" then
        if ResetTabPosition then
            ResetTabPosition()
            print("|cff00ff00[Hardcore Achievements]|r Tab position reset to default")
        else
            print("|cffff0000[Hardcore Achievements]|r ResetTabPosition function not found")
        end
    elseif command == "adminkey" then
        -- SECURITY: Set admin secret key for secure command authentication
        if args[2] == "set" and args[3] then
            local key = args[3]
            if #key >= 16 then
                if SetAdminSecretKey(key) then
                    print("|cff00ff00[Hardcore Achievements]|r Admin secret key set successfully")
                    print("|cffffff00[Hardcore Achievements]|r Keep this key secret! Anyone with this key can send admin commands.")
                    if UpdateKeyStatus then
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
                print("|cffffff00[Hardcore Achievements]|r Use: /hca adminkey set <your-secret-key-here>")
                print("|cffffff00[Hardcore Achievements]|r Key must be at least 16 characters long")
            end
        elseif args[2] == "clear" then
            if HardcoreAchievementsDB then
                HardcoreAchievementsDB.adminSecretKey = nil
                print("|cff00ff00[Hardcore Achievements]|r Admin secret key cleared")
                if UpdateKeyStatus then
                    UpdateKeyStatus()
                end
            end
        else
            print("|cff00ff00[Hardcore Achievements]|r Admin key commands:")
            print("  |cffffff00/hca adminkey set <key>|r - Set admin secret key (min 16 chars)")
            print("  |cffffff00/hca adminkey check|r - Check if admin key is set")
            print("  |cffffff00/hca adminkey clear|r - Clear admin secret key")
        end
    elseif command == "tracker" then
        -- Tracker commands
        local AchievementTracker = GetAchievementTracker()
        local subcommand = args[2] and string.lower(args[2]) or ""
        
        if not AchievementTracker then
            print("|cffff0000[Hardcore Achievements]|r Achievement tracker not loaded yet. Please wait a moment and try again, or reload your UI.")
            return
        end
        
        if subcommand == "show" then
            if AchievementTracker.Show then
                AchievementTracker:Show()
                print("|cff00ff00[Hardcore Achievements]|r Achievement tracker shown")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        elseif subcommand == "hide" then
            if AchievementTracker.Hide then
                AchievementTracker:Hide()
                print("|cff00ff00[Hardcore Achievements]|r Achievement tracker hidden")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        elseif subcommand == "toggle" then
            if AchievementTracker.Toggle then
                AchievementTracker:Toggle()
                print("|cff00ff00[Hardcore Achievements]|r Achievement tracker toggled")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        else
            print("|cff00ff00[Hardcore Achievements]|r Tracker commands:")
            print("  |cffffff00/hca tracker show|r - Show the achievement tracker")
            print("  |cffffff00/hca tracker hide|r - Hide the achievement tracker")
            print("  |cffffff00/hca tracker toggle|r - Toggle the achievement tracker")
        end
    elseif command == "debug" then
        -- Debug toggle command
        if args[2] and string.lower(args[2]) == "on" then
            SetDebugEnabled(true)
            print("|cff00ff00[Hardcore Achievements]|r Debug mode enabled")
            _G.HCA_DebugPrint("Debug mode is now ON - you will see debug messages")
        elseif args[2] and string.lower(args[2]) == "off" then
            SetDebugEnabled(false)
            print("|cff00ff00[Hardcore Achievements]|r Debug mode disabled")
        else
            -- Toggle if no argument provided
            local currentState = GetDebugEnabled()
            SetDebugEnabled(not currentState)
            if not currentState then
                print("|cff00ff00[Hardcore Achievements]|r Debug mode enabled")
                _G.HCA_DebugPrint("Debug mode is now ON - you will see debug messages")
            else
                print("|cff00ff00[Hardcore Achievements]|r Debug mode disabled")
            end
        end
    else
        print("|cff00ff00[Hardcore Achievements]|r Available commands:")
        print("  |cffffff00/hca show|r - Enable and show the custom achievement tab")
        print("  |cffffff00/hca reset tab|r - Reset the tab position to default")
        print("  |cffffff00/hca tracker|r - Manage the achievement tracker")
        print("  |cffffff00/hca debug|r - Toggle debug mode (on/off)")
        --print("  |cffffff00/hca adminkey|r - Manage admin secret key for secure commands")
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

-- Export globally for admin tools
_G.HardcoreAchievementsAdminCommandHandler = AdminCommandHandler

-- Helper function to create a secure admin command payload
-- This is what the admin panel should use to send commands
function AdminCommandHandler.CreateAdminPayload(targetCharacter, achievementId, overridePoints, overrideLevel, forceUpdate)
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
