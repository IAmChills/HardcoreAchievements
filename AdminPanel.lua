-- AdminPanel.lua
-- Admin panel for manually completing achievements via secure payloads
-- This file should only be included in your local version of the addon

local AceComm = LibStub("AceComm-3.0")
local AceSerialize = LibStub("AceSerializer-3.0")

local AdminPanel = {}
local ADMIN_SIGNATURE = "HC_ADMIN_2024" -- Your unique admin signature
local WHISPER_PREFIX = "\127\127" -- Hidden characters for whisper prefix

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

local function CreateSecurePayload(achievementId, targetCharacter)
    local payload = {
        version = 1,
        timestamp = time(),
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        adminSignature = ADMIN_SIGNATURE,
        validationHash = 0 -- Will be set after creation
    }
    
    payload.validationHash = CreatePayloadHash(payload)
    return payload
end

local function SendAdminCommand(achievementId, targetCharacter)
    if not achievementId or not targetCharacter then
        print("|cffff0000[HardcoreAchievements Admin]|r Invalid achievement ID or character name")
        return
    end
    
    local payload = CreateSecurePayload(achievementId, targetCharacter)
    local serializedPayload = AceSerialize:Serialize(payload)
    
    if not serializedPayload then
        print("|cffff0000[HardcoreAchievements Admin]|r Failed to serialize payload")
        return
    end
    
    -- Send the command via whisper with hidden prefix
    local whisperMessage = WHISPER_PREFIX .. serializedPayload
    SendChatMessage(whisperMessage, "WHISPER", nil, targetCharacter)
    
    print("|cff00ff00[HardcoreAchievements Admin]|r Sent achievement completion command for '" .. achievementId .. "' to " .. targetCharacter)
    
    -- Log the admin action
    if not HardcoreAchievementsDB then HardcoreAchievementsDB = {} end
    if not HardcoreAchievementsDB.adminLog then HardcoreAchievementsDB.adminLog = {} end
    
    table.insert(HardcoreAchievementsDB.adminLog, {
        timestamp = time(),
        achievementId = achievementId,
        targetCharacter = targetCharacter,
        adminCharacter = UnitName("player")
    })
end

local function CreateAdminPanel()
    if adminFrame then return adminFrame end
    
    -- Create main frame
    adminFrame = CreateFrame("Frame", "HardcoreAchievementsAdminPanel", UIParent, "BasicFrameTemplateWithInset")
    adminFrame:SetSize(400, 300)
    adminFrame:SetPoint("CENTER")
    adminFrame:Hide()
    
    -- Create title manually since BasicFrameTemplateWithInset doesn't have SetTitle
    local titleText = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("TOP", adminFrame, "TOP", 0, -25)
    titleText:SetText("HardcoreAchievements Admin Panel")
    
    -- Make it draggable
    adminFrame:SetMovable(true)
    adminFrame:EnableMouse(true)
    adminFrame:RegisterForDrag("LeftButton")
    adminFrame:SetScript("OnDragStart", adminFrame.StartMoving)
    adminFrame:SetScript("OnDragStop", adminFrame.StopMovingOrSizing)
    
    -- Achievement dropdown
    local achievementLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    achievementLabel:SetPoint("TOPLEFT", 20, -40)
    achievementLabel:SetText("Achievement:")
    
    local achievementDropdown = CreateFrame("Frame", nil, adminFrame, "UIDropDownMenuTemplate")
    achievementDropdown:SetPoint("TOPLEFT", achievementLabel, "BOTTOMLEFT", -20, -10)
    achievementDropdown:SetSize(320, 32)
    
    -- Character name input
    local characterLabel = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    characterLabel:SetPoint("TOPLEFT", achievementLabel, "BOTTOMLEFT", 0, -70)
    characterLabel:SetText("Target Character:")
    
    local characterInput = CreateFrame("EditBox", nil, adminFrame, "InputBoxTemplate")
    characterInput:SetPoint("TOPLEFT", characterLabel, "BOTTOMLEFT", 0, -10)
    characterInput:SetSize(200, 32)
    characterInput:SetAutoFocus(false)
    characterInput:SetText("")
    
    -- Send button
    local sendButton = CreateFrame("Button", nil, adminFrame, "UIPanelButtonTemplate")
    sendButton:SetPoint("TOPLEFT", characterInput, "BOTTOMLEFT", 0, -20)
    sendButton:SetSize(120, 32)
    sendButton:SetText("Send Command")
    
    -- Status text
    local statusText = adminFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", sendButton, "BOTTOMLEFT", 0, -20)
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
        
        UIDropDownMenu_SetText(achievementDropdown, "Select Achievement...")
        UIDropDownMenu_Initialize(achievementDropdown, function(self, level)
            for _, item in ipairs(achievementList) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = item.text
                info.value = item.value
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(achievementDropdown, item.value)
                    UIDropDownMenu_SetText(achievementDropdown, item.text)
                    selectedAchievement = item.achievement
                end
                UIDropDownMenu_AddButton(info)
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
            
            SendAdminCommand(selectedAchievement.achId, characterName)
        end)
    end
    
    -- Initialize dropdown
    PopulateAchievementDropdown()
    
    return adminFrame
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

-- Export functions
_G.HardcoreAchievementsAdminPanel = AdminPanel
