-- CommandHandler.lua
-- Client-side handler for processing admin commands via whispers
-- This file should be included in all versions of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local AdminCommandHandler = {}
local ADMIN_SIGNATURE = "HC_ADMIN_CHILLS" -- Must match admin panel signature
local COMM_PREFIX = "HCA_Admin_Cmd" -- AceComm prefix for admin commands
local RESPONSE_PREFIX = "HCA_Admin_Resp" -- AceComm prefix for responses (max 16 chars)
local MAX_PAYLOAD_AGE = 300 -- 5 minutes in seconds

-- Security and validation functions
local function CreatePayloadHash(payload)
    local hashString = payload.version .. payload.timestamp .. payload.achievementId .. payload.targetCharacter .. ADMIN_SIGNATURE
    local hash = 0
    for i = 1, #hashString do
        hash = hash + string.byte(hashString, i) * i
    end
    return hash % 1000000 -- Simple hash for validation
end

local function ValidatePayload(payload)
    if not payload then return false, "No payload" end
    if not payload.version or payload.version ~= 1 then return false, "Invalid version" end
    if not payload.timestamp or not payload.achievementId or not payload.targetCharacter then return false, "Missing required fields" end
    if not payload.adminSignature or payload.adminSignature ~= ADMIN_SIGNATURE then return false, "Invalid admin signature" end
    
    -- Check payload age
    local currentTime = time()
    if currentTime - payload.timestamp > MAX_PAYLOAD_AGE then return false, "Payload too old" end
    
    -- Validate hash
    local expectedHash = CreatePayloadHash(payload)
    if payload.validationHash ~= expectedHash then return false, "Invalid payload hash" end
    
    return true, "Valid"
end

local function CreatePayloadHash(payload)
    local hashString = payload.version .. payload.timestamp .. payload.achievementId .. payload.targetCharacter .. ADMIN_SIGNATURE
    local hash = 0
    for i = 1, #hashString do
        hash = hash + string.byte(hashString, i) * i
    end
    return hash % 1000000 -- Simple hash for validation
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

local function ProcessAdminCommand(payload, sender)
    -- Validate the payload
    local isValid, reason = ValidatePayload(payload)
    if not isValid then
        SendResponseToAdmin(sender, "|cffff0000[HardcoreAchievements]|r Admin command rejected: " .. reason)
        return false
    end
    
    -- Check if target character matches current player
    local currentCharacter = UnitName("player")
    if payload.targetCharacter ~= currentCharacter then
        SendResponseToAdmin(sender, "|cffff0000[HardcoreAchievements]|r Admin command rejected: Target character mismatch")
        return false
    end
    
    -- Find the achievement row
    local achievementRow = FindAchievementRow(payload.achievementId)
    if not achievementRow then
        SendResponseToAdmin(sender, "|cffff0000[HardcoreAchievements]|r Admin command rejected: Achievement not found")
        return false
    end
    
    -- Check if achievement is already completed
    if achievementRow.completed then
        SendResponseToAdmin(sender, "|cffff0000[HardcoreAchievements]|r Admin command rejected: Achievement already completed")
        return false
    end
    
    -- Complete the achievement
    HCA_MarkRowCompleted(achievementRow)
    
    -- Show achievement toast
    HCA_AchToast_Show(achievementRow.Icon:GetTexture(), achievementRow.Title:GetText(), achievementRow.points)
    
    SendResponseToAdmin(sender, "|cff00ff00[HardcoreAchievements]|r Achievement '" .. payload.achievementId .. "' completed via admin command")
    
    -- Log the admin command
    if not HardcoreAchievementsDB then HardcoreAchievementsDB = {} end
    if not HardcoreAchievementsDB.adminCommands then HardcoreAchievementsDB.adminCommands = {} end
    
    table.insert(HardcoreAchievementsDB.adminCommands, {
        timestamp = time(),
        achievementId = payload.achievementId,
        adminSignature = payload.adminSignature,
        payloadHash = payload.validationHash
    })
    
    return true
end

-- AceComm handler for admin commands
local function OnCommReceived(prefix, message, distribution, sender)
    -- Check if this is our admin command prefix
    if prefix ~= COMM_PREFIX then return end
    
    -- Deserialize the payload
    local success, payload = AceSerialize:Deserialize(message)
    if not success then
        SendResponseToAdmin(sender, "|cffff0000[HardcoreAchievements]|r Failed to deserialize admin command")
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
    local command = string.lower(string.trim(msg or ""))
    
    if command == "show" then
        -- Set database flag to show custom tab
        if not HardcoreAchievementsDB then
            HardcoreAchievementsDB = {}
        end
        HardcoreAchievementsDB.showCustomTab = true
        
        -- Immediately show the custom tab
        local tab = _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
        if tab and tab:GetText() and tab:GetText():find("Achievements") then
            tab:Show()
            tab:SetScript("OnClick", function(self)
                if HCA_ShowAchievementTab then
                    HCA_ShowAchievementTab()
                end
            end)
            print("|cff00ff00[HardcoreAchievements]|r Custom achievement tab enabled and shown")
        else
            print("|cffff0000[HardcoreAchievements]|r Custom achievement tab not found")
        end
    else
        print("|cff00ff00[HardcoreAchievements]|r Available commands:")
        print("  |cffffff00/hca show|r - Enable and show the custom achievement tab")
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

-- Export functions
_G.HardcoreAchievementsAdminCommandHandler = AdminCommandHandler
