-- AdminPanel.lua
-- Admin panel for manually completing achievements via secure payloads
-- This file should only be included in your local version of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local AdminPanel = {}
local ADMIN_SIGNATURE = "HC_ADMIN_CHILLS" -- Your unique admin signature
local COMM_PREFIX = "HCA_Admin_Cmd" -- AceComm prefix for admin commands
local RESPONSE_PREFIX = "HCA_Admin_Resp" -- AceComm prefix for responses (max 16 chars)

-- Admin panel UI
local adminFrame = nil

-- Security and validation functions
local function CreatePayloadHash(payload)
    local hashString = payload.version .. payload.timestamp .. payload.achievementId .. payload.targetCharacter .. ADMIN_SIGNATURE
    local hash = 0
    for i = 1, #hashString do
        hash = hash + string.byte(hashString, i) * i
    end
    return hash % 1000000 -- Simple hash for validation
end

local function CreateSecurePayload(achievementId, targetCharacter, opts)
    local payload = {
        version = 1,
        timestamp = time(),
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        adminSignature = ADMIN_SIGNATURE,
		validationHash = 0 -- Will be set after creation
    }
	
	-- Optional update/override fields (not part of validation hash)
	if opts then
		if opts.forceUpdate ~= nil then payload.forceUpdate = opts.forceUpdate and true or false end
		if opts.overridePoints ~= nil then payload.overridePoints = tonumber(opts.overridePoints) end
		if opts.overrideLevel ~= nil then payload.overrideLevel = tonumber(opts.overrideLevel) end
	end
    
    payload.validationHash = CreatePayloadHash(payload)
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
    
	local payload = CreateSecurePayload(achievementId, targetCharacter, { forceUpdate = forceUpdate, overridePoints = overridePoints, overrideLevel = overrideLevel })
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
		overrideLevel = overrideLevel and tonumber(overrideLevel) or nil
    })
end

local function CreateAdminPanel()
    if adminFrame then return adminFrame end
    
	-- Create main frame (use a unique name that doesn't collide with exported table)
	adminFrame = CreateFrame("Frame", "HardcoreAchievementsAdminPanelFrame", UIParent, "BasicFrameTemplateWithInset")
    adminFrame:SetSize(400, 300)
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
    
    -- Make it draggable
    adminFrame:SetMovable(true)
    adminFrame:EnableMouse(true)
    adminFrame:RegisterForDrag("LeftButton")
    adminFrame:SetScript("OnDragStart", adminFrame.StartMoving)
    adminFrame:SetScript("OnDragStop", adminFrame.StopMovingOrSizing)
    
	-- Achievement selector (scrollable list)
	local achievementLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	achievementLabel:SetPoint("TOP", adminFrame, "TOP", 0, -40)
	achievementLabel:SetText("Achievement")

	local achievementSelectButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
	achievementSelectButton:SetPoint("TOP", adminFrame, "TOP", 0, -55)
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
    characterLabel:SetPoint("TOP", adminFrame, "TOP", 0, -100)
    characterLabel:SetText("Target Character")
    
    local characterInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
    characterInput:SetPoint("TOP", adminFrame, "TOP", 0, -115)
    characterInput:SetSize(125, 32)
    characterInput:SetAutoFocus(false)
    characterInput:SetText("")

	-- Force update checkbox
	local forceCheck = CreateFrame("CheckButton", nil, adminFrame, "ChatConfigCheckButtonTemplate")
	forceCheck:SetPoint("TOP", adminFrame, "TOP", -55, -168)
	forceCheck.tooltip = "Override existing completion and update points"
	local forceLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	forceLabel:SetPoint("TOP", adminFrame, "TOP", 70, -172)
	forceLabel:SetText("Force Update (override if completed)")

	-- Override points input
	local pointsLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pointsLabel:SetPoint("TOP", adminFrame, "TOP", -110, -150)
	pointsLabel:SetText("Override Points (optional)")

	local pointsInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
	pointsInput:SetPoint("TOP", adminFrame, "TOP", -110, -165)
	pointsInput:SetSize(80, 28)
	pointsInput:SetAutoFocus(false)
	pointsInput:SetNumeric(false)
	pointsInput:SetText("")

	-- Override level input
	local levelLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	levelLabel:SetPoint("TOP", adminFrame, "TOP", -110, -180)
	levelLabel:SetText("Override Level (optional)")

	local levelInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
	levelInput:SetPoint("TOP", adminFrame, "TOP", -110, -195)
	levelInput:SetSize(80, 28)
	levelInput:SetAutoFocus(false)
	levelInput:SetNumeric(true)
	levelInput:SetText("")
    
    -- Send button
    local sendButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
    sendButton:SetPoint("BOTTOM", adminFrame, "BOTTOM", 0, 60)
    sendButton:SetSize(120, 32)
    sendButton:SetText("Send Command")
    
    -- Status text
    local statusText = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", adminFrame, "BOTTOM", 0, -20)
    statusText:SetSize(360, 60)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    statusText:SetText("Select an achievement and enter the target character name, then click Send Command to manually complete the achievement for that player.")
    
    -- Populate achievement dropdown
	local function PopulateAchievementDropdown()
        local achievementList = {}
        
        -- Get achievements from the catalog
        if _G.Achievements then
            for _, achievement in ipairs(_G.Achievements) do
                table.insert(achievementList, {
					text = achievement.title .. " (Level " .. achievement.level .. ")",
                    value = achievement.achId,
                    achievement = achievement
                })
            end
        end
        
        -- Sort by level
        table.sort(achievementList, function(a, b)
            return a.achievement.level < b.achievement.level
        end)
        
        local selectedAchievement = nil

		-- Build scrollable buttons
		local ROW_H = 20
		local GAP = 2
		local totalHeight = 0
		local buttons = {}
		
		local function CreateOrUpdateButtons()
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
				btn.text:SetText(item.text)
				btn:SetScript("OnMouseUp", function()
					selectedAchievement = item.achievement
					achievementSelectButton:SetText(item.text)
					achievementListFrame:Hide()
				end)
				btn:Show()
			end
			totalHeight = (#achievementList > 0) and ((ROW_H * #achievementList) + (GAP * math.max(0, #achievementList - 1))) or 1
			content:SetSize(210, totalHeight)
			scroll:UpdateScrollChildRect()
		end

		CreateOrUpdateButtons()

		achievementSelectButton:SetScript("OnClick", function()
			if achievementListFrame:IsShown() then
				achievementListFrame:Hide()
			else
				achievementListFrame:Show()
			end
		end)
        
		-- Send button click handler
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

-- Export functions
_G.HardcoreAchievementsAdminPanel = AdminPanel
