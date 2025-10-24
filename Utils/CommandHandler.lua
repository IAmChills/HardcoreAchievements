-- CommandHandler.lua
-- Client-side handler for processing admin commands via whispers
-- This file should be included in all versions of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local AdminCommandHandler = {}
local ADMIN_SIGNATURE = "HC_ADMIN_2024" -- Must match admin panel signature
local WHISPER_PREFIX = "\127\127" -- Hidden characters for whisper prefix
local MAX_PAYLOAD_AGE = 300 -- 5 minutes in seconds

-- Security and validation functions
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

local function ProcessAdminCommand(payload)
    -- Validate the payload
    local isValid, reason = ValidatePayload(payload)
    if not isValid then
        print("|cffff0000[HardcoreAchievements]|r Admin command rejected: " .. reason)
        return false
    end
    
    -- Check if target character matches current player
    local currentCharacter = UnitName("player")
    if payload.targetCharacter ~= currentCharacter then
        print("|cffff0000[HardcoreAchievements]|r Admin command rejected: Target character mismatch")
        return false
    end
    
    -- Find the achievement row
    local achievementRow = FindAchievementRow(payload.achievementId)
    if not achievementRow then
        print("|cffff0000[HardcoreAchievements]|r Admin command rejected: Achievement not found")
        return false
    end
    
    -- Check if achievement is already completed
    if achievementRow.completed then
        print("|cffff0000[HardcoreAchievements]|r Admin command rejected: Achievement already completed")
        return false
    end
    
    -- Complete the achievement
    MarkRowCompleted(achievementRow)
    
    -- Show achievement toast
    UHC_AchToast_Show(achievementRow.Icon:GetTexture(), achievementRow.Title:GetText(), achievementRow.points)
    
    print("|cff00ff00[HardcoreAchievements]|r Achievement '" .. payload.achievementId .. "' completed via admin command")
    
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

-- Whisper handler
local function OnWhisperReceived(event, text, playerName, language, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLine, hideSenderInLog, suppressRaidWarning, suppressFrameMessage)
    -- Check if whisper starts with our hidden prefix
    if not text or not text:match("^" .. WHISPER_PREFIX) then return end
    
    -- Extract the serialized payload
    local serializedPayload = text:sub(#WHISPER_PREFIX + 1)
    
    -- Deserialize the payload
    local success, payload = AceSerialize:Deserialize(serializedPayload)
    if not success then
        print("|cffff0000[HardcoreAchievements]|r Failed to deserialize admin command")
        return
    end
    
    -- Process the admin command
    ProcessAdminCommand(payload)
end

-- Initialize the handler
local function InitializeAdminCommandHandler()
    -- Register whisper event
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:SetScript("OnEvent", OnWhisperReceived)
    
    print("|cff00ff00[HardcoreAchievements]|r Admin command handler initialized")
end

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
