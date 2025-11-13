-- AdminPanel.lua
-- Admin panel for manually completing achievements via secure payloads
-- This file should only be included in your local version of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local AdminPanel = {}
local COMM_PREFIX = "HCA_Admin_Cmd" -- AceComm prefix for admin commands
local RESPONSE_PREFIX = "HCA_Admin_Resp" -- AceComm prefix for responses (max 16 chars)

-- Admin panel UI
local adminFrame = nil

-- SECURITY: Get admin secret key from database (set by admin via slash command)
-- This key is NOT in source code and must be set by the admin
local function GetAdminSecretKey()
    if not HardcoreAchievementsDB then
        HardcoreAchievementsDB = {}
    end
    return HardcoreAchievementsDB.adminSecretKey
end

-- SECURITY: HMAC-style hash function using secret key
-- This matches the hash function in CommandHandler.lua
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

-- SECURITY: Create secure payload using version 2 protocol
local function CreateSecurePayload(achievementId, targetCharacter, opts)
    -- Get secret key from database
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        error("Admin secret key not set! Use /hca adminkey set <key> first")
    end
    
    local payload = {
        version = 2,  -- Version 2 uses secure hash with secret key
        timestamp = time(),
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        nonce = GenerateNonce(),  -- Replay protection
    }
	
	-- Optional update/override fields
	if opts then
		if opts.forceUpdate ~= nil then payload.forceUpdate = opts.forceUpdate and true or false end
		if opts.overridePoints ~= nil then payload.overridePoints = tonumber(opts.overridePoints) end
		if opts.overrideLevel ~= nil then payload.overrideLevel = tonumber(opts.overrideLevel) end
		if opts.commandType ~= nil then payload.commandType = opts.commandType end
	end
    
    -- Create secure hash using secret key
    payload.validationHash = CreateSecureHash(payload, secretKey)
    
    if not payload.validationHash then
        error("Failed to create secure hash")
    end
    
    return payload
end

-- SECURITY: Create secure payload for delete achievement command
local function CreateDeleteAchievementPayload(achievementId, targetCharacter)
    -- Get secret key from database
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        error("Admin secret key not set! Use /hca adminkey set <key> first")
    end
    
    local payload = {
        version = 2,
        timestamp = time(),
        commandType = "delete_achievement",
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        nonce = GenerateNonce(),
    }
    
    -- Create secure hash using secret key
    payload.validationHash = CreateSecureHash(payload, secretKey)
    
    if not payload.validationHash then
        error("Failed to create secure hash")
    end
    
    return payload
end

-- SECURITY: Create secure payload for clear secret key command
local function CreateClearKeyPayload(targetCharacter)
    -- Get secret key from database
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        error("Admin secret key not set! Use /hca adminkey set <key> first")
    end
    
    local payload = {
        version = 2,
        timestamp = time(),
        commandType = "clear_secret_key",
        targetCharacter = targetCharacter,
        achievementId = "",  -- Not used for clear key command, but required for hash
        nonce = GenerateNonce(),
    }
    
    -- Create secure hash using secret key
    payload.validationHash = CreateSecureHash(payload, secretKey)
    
    if not payload.validationHash then
        error("Failed to create secure hash")
    end
    
    return payload
end

local function AddResponseMessage(character, message)
    -- Simply print the message to admin's chat
    print(message)
end

local function SendAdminCommand(achievementId, targetCharacter, forceUpdate, overridePoints, overrideLevel)
    if not achievementId or not targetCharacter then
        print("|cffff0000[HardcoreAchievements Admin]|r Invalid achievement ID or character name")
        return
    end
    
    -- Check if secret key is set
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        print("|cffff0000[HardcoreAchievements Admin]|r Admin secret key not set!")
        print("|cffffff00[HardcoreAchievements Admin]|r Use: /hca adminkey set <your-secret-key-here>")
        print("|cffffff00[HardcoreAchievements Admin]|r Key must be at least 16 characters long")
        return
    end
    
    -- Create secure payload
    local success, payload = pcall(CreateSecurePayload, achievementId, targetCharacter, { 
        forceUpdate = forceUpdate, 
        overridePoints = overridePoints, 
        overrideLevel = overrideLevel 
    })
    
    if not success or not payload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to create secure payload: " .. tostring(payload))
        return
    end
    
    local serializedPayload = AceSerialize:Serialize(payload)
    
    if not serializedPayload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to serialize payload")
        return
    end
    
    -- Send the command via AceComm
    AceComm:SendCommMessage(COMM_PREFIX, serializedPayload, "WHISPER", targetCharacter)
    
	local suffix = ""
	if forceUpdate then suffix = suffix .. " [Force Update]" end
	if overridePoints and tonumber(overridePoints) then suffix = suffix .. " [Override Points: " .. tostring(overridePoints) .. "]" end
	if overrideLevel and tonumber(overrideLevel) then suffix = suffix .. " [Override Level: " .. tostring(overrideLevel) .. "]" end
	print("|cff00ff00[HardcoreAchievements Admin]|r Sent achievement command for '" .. achievementId .. "' to " .. targetCharacter .. suffix)
    
    -- Log the admin action
    if not HardcoreAchievementsDB then HardcoreAchievementsDB = {} end
    if not HardcoreAchievementsDB.adminLog then HardcoreAchievementsDB.adminLog = {} end
    
    table.insert(HardcoreAchievementsDB.adminLog, {
        timestamp = time(),
        achievementId = achievementId,
        targetCharacter = targetCharacter,
		adminCharacter = UnitName("player"),
		forceUpdate = forceUpdate and true or false,
		overridePoints = overridePoints and tonumber(overridePoints) or nil,
		overrideLevel = overrideLevel and tonumber(overrideLevel) or nil,
        nonce = payload.nonce,
        payloadHash = payload.validationHash
    })
    
    -- Keep only last 100 log entries to prevent database bloat
    if #HardcoreAchievementsDB.adminLog > 100 then
        table.remove(HardcoreAchievementsDB.adminLog, 1)
    end
end

-- SECURITY: Send delete achievement command to target player
local function SendDeleteAchievementCommand(achievementId, targetCharacter)
    if not achievementId or not targetCharacter then
        print("|cffff0000[HardcoreAchievements Admin]|r Invalid achievement ID or character name")
        return
    end
    
    -- Check if secret key is set
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        print("|cffff0000[HardcoreAchievements Admin]|r Admin secret key not set!")
        print("|cffffff00[HardcoreAchievements Admin]|r Use: /hca adminkey set <your-secret-key-here>")
        print("|cffffff00[HardcoreAchievements Admin]|r Key must be at least 16 characters long")
        return
    end
    
    -- Create delete achievement payload
    local success, payload = pcall(CreateDeleteAchievementPayload, achievementId, targetCharacter)
    
    if not success or not payload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to create delete achievement payload: " .. tostring(payload))
        return
    end
    
    local serializedPayload = AceSerialize:Serialize(payload)
    
    if not serializedPayload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to serialize payload")
        return
    end
    
    -- Send the command via AceComm
    AceComm:SendCommMessage(COMM_PREFIX, serializedPayload, "WHISPER", targetCharacter)
    
    print("|cff00ff00[HardcoreAchievements Admin]|r Sent delete achievement command for '" .. achievementId .. "' to " .. targetCharacter)
    
    -- Log the admin action
    if not HardcoreAchievementsDB then HardcoreAchievementsDB = {} end
    if not HardcoreAchievementsDB.adminLog then HardcoreAchievementsDB.adminLog = {} end
    
    table.insert(HardcoreAchievementsDB.adminLog, {
        timestamp = time(),
        commandType = "delete_achievement",
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        adminCharacter = UnitName("player"),
        nonce = payload.nonce,
        payloadHash = payload.validationHash
    })
    
    -- Keep only last 100 log entries to prevent database bloat
    if #HardcoreAchievementsDB.adminLog > 100 then
        table.remove(HardcoreAchievementsDB.adminLog, 1)
    end
end

-- SECURITY: Send clear secret key command to target player
local function SendClearSecretKeyCommand(targetCharacter)
    if not targetCharacter or targetCharacter == "" then
        print("|cffff0000[HardcoreAchievements Admin]|r Invalid character name")
        return
    end
    
    -- Check if secret key is set
    local secretKey = GetAdminSecretKey()
    if not secretKey or secretKey == "" then
        print("|cffff0000[HardcoreAchievements Admin]|r Admin secret key not set!")
        print("|cffffff00[HardcoreAchievements Admin]|r Use: /hca adminkey set <your-secret-key-here>")
        print("|cffffff00[HardcoreAchievements Admin]|r Key must be at least 16 characters long")
        return
    end
    
    -- Create clear key payload
    local success, payload = pcall(CreateClearKeyPayload, targetCharacter)
    
    if not success or not payload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to create clear key payload: " .. tostring(payload))
        return
    end
    
    local serializedPayload = AceSerialize:Serialize(payload)
    
    if not serializedPayload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to serialize payload")
        return
    end
    
    -- Send the command via AceComm
    AceComm:SendCommMessage(COMM_PREFIX, serializedPayload, "WHISPER", targetCharacter)
    
    print("|cff00ff00[HardcoreAchievements Admin]|r Sent clear secret key command to " .. targetCharacter)
    
    -- Log the admin action
    if not HardcoreAchievementsDB then HardcoreAchievementsDB = {} end
    if not HardcoreAchievementsDB.adminLog then HardcoreAchievementsDB.adminLog = {} end
    
    table.insert(HardcoreAchievementsDB.adminLog, {
        timestamp = time(),
        commandType = "clear_secret_key",
        targetCharacter = targetCharacter,
        adminCharacter = UnitName("player"),
        nonce = payload.nonce,
        payloadHash = payload.validationHash
    })
    
    -- Keep only last 100 log entries to prevent database bloat
    if #HardcoreAchievementsDB.adminLog > 100 then
        table.remove(HardcoreAchievementsDB.adminLog, 1)
    end
end

local function CreateAdminPanel()
    if adminFrame then return adminFrame end
    
	-- Create main frame (use a unique name that doesn't collide with exported table)
	adminFrame = CreateFrame("Frame", "HardcoreAchievementsAdminPanelFrame", UIParent, "BasicFrameTemplateWithInset")
    adminFrame:SetSize(400, 400)  -- Increased height to accommodate key status indicator
    adminFrame:SetPoint("CENTER")
    adminFrame:Hide()

	-- Allow closing with ESC key via UISpecialFrames
	local frameName = adminFrame:GetName()
	local exists = false
	for i = 1, #UISpecialFrames do
		if UISpecialFrames[i] == frameName then
			exists = true
			break
		end
	end
	if not exists then
		table.insert(UISpecialFrames, frameName)
	end
    
    -- Create title manually since BasicFrameTemplateWithInset doesn't have SetTitle
    local titleText = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("TOP", adminFrame, "TOP", 0, -5)
    titleText:SetText("HardcoreAchievements Admin Panel")
    
    -- SECURITY: Status indicator for secret key
    local keyStatusText = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keyStatusText:SetPoint("TOPLEFT", adminFrame, "TOPLEFT", 10, -30)
    keyStatusText:SetJustifyH("CENTER")
    
    local function UpdateKeyStatus()
        local secretKey = GetAdminSecretKey()
        if secretKey and secretKey ~= "" then
            keyStatusText:SetText("|cff00ff00Secret Key: Set|r")
            keyStatusText:SetTextColor(0, 1, 0)
        else
            keyStatusText:SetText("|cffff0000Secret Key: NOT SET|r")
            keyStatusText:SetTextColor(1, 0, 0)
        end
    end
    
    -- Update status when frame is shown
    adminFrame:SetScript("OnShow", function()
        UpdateKeyStatus()
    end)
    UpdateKeyStatus()
    
    -- Make it draggable
    adminFrame:SetMovable(true)
    adminFrame:EnableMouse(true)
    adminFrame:RegisterForDrag("LeftButton")
    adminFrame:SetScript("OnDragStart", adminFrame.StartMoving)
    adminFrame:SetScript("OnDragStop", adminFrame.StopMovingOrSizing)
    
	-- Achievement selector (scrollable list)
	local achievementLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	achievementLabel:SetPoint("TOP", titleText, "BOTTOM", 0, -20)
	achievementLabel:SetText("Achievement")

	local achievementSelectButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
	achievementSelectButton:SetPoint("TOP", achievementLabel, "BOTTOM", 0, -5)
	achievementSelectButton:SetSize(220, 22)
	achievementSelectButton:SetText("Select Achievement...")

	-- Dropdown-like scrollable frame
	local achievementListFrame = CreateFrame("Frame", nil, adminFrame)
	achievementListFrame:SetSize(260, 180)
	achievementListFrame:SetPoint("TOP", achievementSelectButton, "BOTTOM", 0, -2)
	achievementListFrame:Hide()
	achievementListFrame:SetFrameStrata("DIALOG")

	-- Simple background
	local bg = achievementListFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.8)

	local border = achievementListFrame:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetColorTexture(1, 1, 1, 0.08)

	local scroll = CreateFrame("ScrollFrame", nil, achievementListFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", achievementListFrame, "TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", achievementListFrame, "BOTTOMRIGHT", -28, 6)
	scroll:EnableMouseWheel(true)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
    
    -- Character name input
    local characterLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    characterLabel:SetPoint("TOP", achievementSelectButton, "BOTTOM", 0, -30)
    characterLabel:SetText("Target Character")
    
    local characterInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
    characterInput:SetPoint("TOP", characterLabel, "BOTTOM", 0, -5)
    characterInput:SetSize(125, 32)
    characterInput:SetAutoFocus(false)
    characterInput:SetText("")

	-- Force update checkbox
	local forceCheck = CreateFrame("CheckButton", nil, adminFrame, "ChatConfigCheckButtonTemplate")
	forceCheck:SetPoint("TOP", characterInput, "BOTTOM", -175, -15)
	-- Prevent the template from expanding the clickable area far to the right
	forceCheck:SetHitRectInsets(0, 0, 0, 0)
	forceCheck.tooltip = "Override existing completion and update points"
	local forceLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	forceLabel:SetPoint("LEFT", forceCheck, "RIGHT", 5, 0)
	forceLabel:SetText("Force Update (override if completed)")

	-- Override points input
	local pointsLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pointsLabel:SetPoint("TOP", forceCheck, "BOTTOM", 80, -30)
	pointsLabel:SetText("Override Points (optional)")

	local pointsInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
	pointsInput:SetPoint("TOP", pointsLabel, "BOTTOM", 0, -5)
	pointsInput:SetSize(80, 28)
	pointsInput:SetAutoFocus(false)
	pointsInput:SetNumeric(false)
	pointsInput:SetText("")

	-- Override level input
	local levelLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	levelLabel:SetPoint("TOP", forceCheck, "BOTTOM", 275, -30)
	levelLabel:SetText("Override Level (optional)")

	local levelInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
	levelInput:SetPoint("TOP", levelLabel, "BOTTOM", 0, -5)
	levelInput:SetSize(80, 28)
	levelInput:SetAutoFocus(false)
	levelInput:SetNumeric(true)
	levelInput:SetText("")
    
    -- Send button
    local sendButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
    sendButton:SetPoint("BOTTOM", adminFrame, "BOTTOM", -110, 75)
    sendButton:SetSize(100, 32)
    sendButton:SetText("Send")
    
    -- Delete Achievement button
    local deleteButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
    deleteButton:SetPoint("BOTTOM", adminFrame, "BOTTOM", 0, 75)
    deleteButton:SetSize(100, 32)
    deleteButton:SetText("Delete")
    deleteButton:SetNormalFontObject("GameFontNormalSmall")
    deleteButton:GetFontString():SetTextColor(1, 0.3, 0.3)  -- Red tint to indicate danger
    
    -- Tooltip for delete button
    deleteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete Achievement", 1, 0.3, 0.3)
        GameTooltip:AddLine("Removes the achievement from the target player's database.", 1, 1, 1, true)
        GameTooltip:AddLine("This will reset the achievement to its initial state.", 1, 1, 1, true)
        GameTooltip:AddLine("Use this to correct incorrect completions.", 1, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    deleteButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Clear Key button (security feature)
    local clearKeyButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
    clearKeyButton:SetPoint("BOTTOM", adminFrame, "BOTTOM", 110, 75)
    clearKeyButton:SetSize(100, 32)
    clearKeyButton:SetText("Clear Key")
    clearKeyButton:SetNormalFontObject("GameFontNormalSmall")
    clearKeyButton:GetFontString():SetTextColor(1, 0.5, 0.5)  -- Reddish tint to indicate danger
    
    -- Tooltip for clear key button
    clearKeyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear Secret Key", 1, 1, 1)
        GameTooltip:AddLine("Remotely clears the secret key for the target player.", 1, 1, 1, true)
        GameTooltip:AddLine("Use this if you suspect the key has been compromised.", 1, 0.5, 0.5, true)
        GameTooltip:AddLine("The player will need to set a new key afterward.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearKeyButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Status text
    local statusText = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", adminFrame, "BOTTOM", 0, -50)
    statusText:SetSize(360, 100)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    statusText:SetText("Select an achievement and enter the target character name.\n|cff00ff00Send Command:|r Completes the achievement.\n|cffff0000Delete:|r Removes the achievement from player's database.\n|cffff0000Clear Key:|r Clears player's secret key if compromised.")
    
    -- Populate achievement dropdown
	local function PopulateAchievementDropdown()
        local achievementList = {}
        local buttons = {}
        local selectedAchievement = nil

        local ROW_H = 20
        local GAP = 2

        local function AddEntry(targetList, seen, entry)
            if not entry or not entry.achId then return end
            local achId = tostring(entry.achId)
            if seen[achId] then return end
            seen[achId] = true

            local title = entry.title or achId
            local level = entry.level and tonumber(entry.level) or nil
            local points = entry.points and tonumber(entry.points) or nil

            table.insert(targetList, {
                achievement = {
                    achId = achId,
                    title = title,
                    level = level,
                    points = points,
                }
            })
        end

        local function BuildAchievementEntries()
            local entries = {}
            local seen = {}

            if AchievementPanel and AchievementPanel.achievements then
                for _, row in ipairs(AchievementPanel.achievements) do
                    local rowAchId = row.achId or row.id
                    if rowAchId then
                        local def = row._def or {}
                        AddEntry(entries, seen, {
                            achId = rowAchId,
                            title = def.title or row._title or (row.Title and row.Title:GetText()) or tostring(rowAchId),
                            level = def.level or row.maxLevel,
                            points = def.points or row.originalPoints or row.points,
                        })
                    end
                end
            end

            if _G.Achievements then
                for _, achievement in ipairs(_G.Achievements) do
                    AddEntry(entries, seen, achievement)
                end
            end

            if _G.HCA_AchievementDefs then
                for achId, achievement in pairs(_G.HCA_AchievementDefs) do
                    AddEntry(entries, seen, {
                        achId = achId,
                        title = achievement.title,
                        level = achievement.level or achievement.maxLevel,
                        points = achievement.points,
                    })
                end
            end

            return entries
        end

        local function FormatButtonLabel(item)
            local title = item.achievement.title or item.achievement.achId
            local level = item.achievement.level
            local levelText = level and (" (Level " .. level .. ")") or " (No Level)"
            return title .. levelText
        end

        local function RefreshButtons()
            achievementList = BuildAchievementEntries()

            table.sort(achievementList, function(a, b)
                local levelA = a.achievement.level or 999
                local levelB = b.achievement.level or 999
                if levelA == levelB then
                    return (a.achievement.title or "") < (b.achievement.title or "")
                end
                return levelA < levelB
            end)

            for _, btn in ipairs(buttons) do
                btn:Hide()
            end

            for i, item in ipairs(achievementList) do
                local btn = buttons[i]
                if not btn then
                    btn = CreateFrame("Button", nil, content)
                    btn:SetSize(210, ROW_H)
                    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
                    btn.hl = btn:CreateTexture(nil, "BACKGROUND")
                    btn.hl:SetAllPoints()
                    btn.hl:SetColorTexture(1, 1, 1, 0.08)
                    btn.hl:Hide()
                    btn:SetScript("OnEnter", function(s) s.hl:Show() end)
                    btn:SetScript("OnLeave", function(s) s.hl:Hide() end)
                    buttons[i] = btn
                end
                btn:ClearAllPoints()
                if i == 1 then
                    btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
                else
                    btn:SetPoint("TOPLEFT", buttons[i-1], "BOTTOMLEFT", 0, -GAP)
                end
                local label = FormatButtonLabel(item)
                btn.text:SetText(label)
                btn:SetScript("OnMouseUp", function()
                    selectedAchievement = item.achievement
                    achievementSelectButton:SetText(label)
                    achievementListFrame:Hide()
                end)
                btn:Show()
            end

            local visibleCount = #achievementList
            local totalHeight = (visibleCount > 0) and ((ROW_H * visibleCount) + (GAP * math.max(0, visibleCount - 1))) or 1
            content:SetSize(210, totalHeight)
            scroll:UpdateScrollChildRect()

            if selectedAchievement then
                local found = false
                local matchedLabel = nil
                for _, item in ipairs(achievementList) do
                    if item.achievement.achId == selectedAchievement.achId then
                        found = true
                        matchedLabel = FormatButtonLabel(item)
                        break
                    end
                end
                if found and matchedLabel then
                    achievementSelectButton:SetText(matchedLabel)
                elseif not found then
                    selectedAchievement = nil
                    achievementSelectButton:SetText("Select Achievement...")
                end
            end
        end

        RefreshButtons()

        achievementSelectButton:SetScript("OnClick", function()
            if achievementListFrame:IsShown() then
                achievementListFrame:Hide()
            else
                RefreshButtons()
                achievementListFrame:Show()
            end
        end)

        sendButton:SetScript("OnClick", function()
            local characterName = characterInput:GetText():trim()
            if not selectedAchievement then
                print("|cffff0000[HardcoreAchievements Admin]|r Please select an achievement")
                return
            end
            if not characterName or characterName == "" then
                print("|cffff0000[HardcoreAchievements Admin]|r Please enter a character name")
                return
            end

            local forceUpdate = forceCheck:GetChecked() and true or false
            local overridePoints = tonumber(pointsInput:GetText())
            local overrideLevel = tonumber(levelInput:GetText())

            SendAdminCommand(selectedAchievement.achId, characterName, forceUpdate, overridePoints, overrideLevel)
        end)
        
        -- Delete Achievement button handler
        deleteButton:SetScript("OnClick", function()
            local characterName = characterInput:GetText():trim()
            if not selectedAchievement then
                print("|cffff0000[HardcoreAchievements Admin]|r Please select an achievement")
                return
            end
            if not characterName or characterName == "" then
                print("|cffff0000[HardcoreAchievements Admin]|r Please enter a character name")
                return
            end
            
            -- Confirm before deleting (store achievement ID and character name in popup data)
            local popup = StaticPopup_Show("HCA_DELETE_ACHIEVEMENT_CONFIRM", selectedAchievement.achId, characterName)
            if popup then
                popup.data = {
                    achievementId = selectedAchievement.achId,
                    characterName = characterName
                }
            end
        end)
        
        -- Clear Key button handler
        clearKeyButton:SetScript("OnClick", function()
            local characterName = characterInput:GetText():trim()
            if not characterName or characterName == "" then
                print("|cffff0000[HardcoreAchievements Admin]|r Please enter a character name")
                return
            end
            
            -- Confirm before clearing (store character name in popup data)
            local popup = StaticPopup_Show("HCA_CLEAR_KEY_CONFIRM", characterName)
            if popup then
                popup.data = characterName
            end
        end)
    end
    
    -- Initialize dropdown
    PopulateAchievementDropdown()
    
    return adminFrame
end

-- AceComm handler for response messages
local function OnResponseReceived(prefix, message, distribution, sender)
    -- Check if this is our response prefix
    if prefix ~= RESPONSE_PREFIX then return end
    
    -- Deserialize the response payload
    local success, payload = AceSerialize:Deserialize(message)
    if not success then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to deserialize response")
        return
    end
    
    -- Check if this is an admin response
    if payload.type == "admin_response" then
        AddResponseMessage(payload.targetCharacter, payload.message)
    end
end

-- Toggle admin panel visibility
function AdminPanel:Toggle()
    local frame = CreateAdminPanel()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Register slash command
SLASH_HARDCOREACHIEVEMENTSADMIN1 = "/hcaadmin"
SLASH_HARDCOREACHIEVEMENTSADMIN2 = "/hcadmin"
SlashCmdList["HARDCOREACHIEVEMENTSADMIN"] = function()
    AdminPanel:Toggle()
end

-- Register AceComm handler for responses
AceComm:RegisterComm(RESPONSE_PREFIX, OnResponseReceived)

-- Create confirmation dialog for delete achievement command
StaticPopupDialogs["HCA_DELETE_ACHIEVEMENT_CONFIRM"] = {
    text = "Are you sure you want to delete achievement '%s' for %s?\n\nThis will remove the achievement from their database and reset it to its initial state.\n\n|cffff0000This action cannot be undone!|r",
    button1 = "Yes, Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data and data.achievementId and data.characterName then
            SendDeleteAchievementCommand(data.achievementId, data.characterName)
        end
    end,
    OnCancel = function(self, data)
        -- Do nothing
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

-- Create confirmation dialog for clear key command
StaticPopupDialogs["HCA_CLEAR_KEY_CONFIRM"] = {
    text = "Are you sure you want to clear the secret key for %s?\n\nThis will prevent them from receiving admin commands until they set a new key.\n\n|cffff0000This action cannot be undone!|r",
    button1 = "Yes, Clear Key",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data and data ~= "" then
            SendClearSecretKeyCommand(data)
        end
    end,
    OnCancel = function(self, data)
        -- Do nothing
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

-- Export functions
_G.HardcoreAchievementsAdminPanel = AdminPanel
