local addonName, addon = ...

-- =========================================================
-- LibP2PDB chat-channel broadcast queue (Classic / TBC / Forever)
--
-- SendChatMessage on custom channels requires a genuine hardware-event
-- stack. Queue presence key updates from PublishPresence / BroadcastKey, then
-- flush from verified binding/UI toggles. Channel name comes from
-- CommChannel's rotating hca###### period (never hard-coded).
-- Opportunistic discovery only — LibP2PDB SyncDatabase owns convergence.
-- =========================================================

local LibStub = LibStub
local GetChannelName = GetChannelName
local pairs = pairs
local next = next
local pcall = pcall
local tostring = tostring
local type = type
local strfind = string.find
local strmatch = string.match
local debugstack = debugstack
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter

-- Must match LeaderboardSync DB_PREFIX (wire header before encoded payload).
-- No underscore: LibP2PDB OnChatMsgChannel parses with ^(%w+); — %w excludes '_'.
local DB_PREFIX = "HCALB"
local CHAT_MAX_BYTES = 255
-- Margin for real row version metadata vs our stand-in estimate.
local CHAT_SIZE_MARGIN = 16
local LibP2PDB = LibStub and LibStub("LibP2PDB", true)

-- Hide everything shown for rotating hca###### channels (player messages, own/other join/leave,
-- moderator/owner notices) plus HCALB payloads anywhere. Display filter only: the events still
-- fire, so LibP2PDB's CHAT_MSG_CHANNEL listener, membership, and rotation are unaffected.
-- All these events share arg4 = "6. hcaXXXXXX" and arg9 = base channel name.
if ChatFrame_AddMessageEventFilter then
    local function IsRotatingChannel(_, _, _, _, _, channelString, _, _, _, _, channelName)
        local name = channelName
        if type(name) ~= "string" or name == "" then
            name = type(channelString) == "string" and strmatch(channelString, "^%d+%.%s*(.+)$") or channelString
        end
        return type(name) == "string" and strmatch(name, "^hca%x%x%x%x%x%x$") ~= nil
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(self, event, msg, ...)
        if type(msg) == "string" and strmatch(msg, "^" .. DB_PREFIX .. ";%d+;") then
            return true
        end
        return IsRotatingChannel(self, event, msg, ...)
    end)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", IsRotatingChannel)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", IsRotatingChannel)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_JOIN", IsRotatingChannel)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_LEAVE", IsRotatingChannel)
end

--- @type table<string, table<string|number, boolean>>
local broadcastQueue = {}
-- Keys that failed chat send (usually >255 bytes); skip until QueueChatBroadcast again.
--- @type table<string, table<string|number, boolean>>
local chatSendFailed = {}
local hooksInstalled = false
local registeredChannelName = nil
local dbHandle = nil

local function Debug(msg)
    if addon.DebugPrint then
        addon.DebugPrint("[ChatBroadcast] " .. tostring(msg))
    end
end

local function CurrentChannelName()
    if addon.GetHCACommChannelName then
        local name = addon.GetHCACommChannelName()
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    local fallback = addon.HCA_COMM_CHANNEL_NAME
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end
    return nil
end

local function ChannelReady(name)
    name = name or CurrentChannelName()
    if type(name) ~= "string" or name == "" or not GetChannelName then
        return false
    end
    local id = GetChannelName(name)
    return type(id) == "number" and id > 0
end

--- Drop LibP2PDB registration for the previously registered rotating channel.
local function ClearChannelRegistration(explicitName)
    local name = explicitName or registeredChannelName
    if not name then
        registeredChannelName = nil
        return
    end
    registeredChannelName = nil
    if LibP2PDB and dbHandle then
        pcall(function()
            LibP2PDB:UnregisterChatChannel(dbHandle, name)
        end)
    end
    Debug("Channel registration cleared: " .. tostring(name))
end

--- Called from CommChannel when leaving a rotating channel (period roll / rejoin).
function addon.OnHCACommChannelLeft(oldName)
    if type(oldName) ~= "string" or oldName == "" then
        return
    end
    if registeredChannelName == oldName then
        ClearChannelRegistration(oldName)
    elseif LibP2PDB and dbHandle then
        -- Belts and suspenders if registration tracking drifted.
        pcall(function()
            LibP2PDB:UnregisterChatChannel(dbHandle, oldName)
        end)
    end
end

--- Register LibP2PDB chat listen/send for the current rotating channel.
--- Does not join — only registers once CommChannel membership exists.
--- @param db table|nil LibP2PDB handle; defaults to Leaderboard.Sync.db
--- @return boolean registered
function addon.TryRegisterHCAChatChannel(db)
    if not LibP2PDB then
        return false
    end
    db = db or dbHandle
    if not db then
        local sync = addon.Leaderboard and addon.Leaderboard.Sync
        db = sync and sync.db
    end
    if not db then
        return false
    end
    dbHandle = db

    local name = CurrentChannelName()
    if not name or not ChannelReady(name) then
        ClearChannelRegistration()
        return false
    end

    if registeredChannelName == name then
        return true
    end

    if registeredChannelName and registeredChannelName ~= name then
        ClearChannelRegistration(registeredChannelName)
    end

    local ok, err = pcall(function()
        LibP2PDB:RegisterChatChannel(db, name)
    end)
    if not ok then
        Debug("Channel register failed: " .. tostring(err))
        return false
    end

    registeredChannelName = name
    Debug("Channel registered: " .. name)
    return true
end

--- Deduped queue entry for a later hardware-event flush.
--- @param tableName string
--- @param key string|number
function addon.QueueChatBroadcast(tableName, key)
    if type(tableName) ~= "string" or tableName == "" or key == nil then
        return
    end
    if chatSendFailed[tableName] then
        chatSendFailed[tableName][key] = nil
    end
    broadcastQueue[tableName] = broadcastQueue[tableName] or {}
    if broadcastQueue[tableName][key] then
        return
    end
    broadcastQueue[tableName][key] = true
    Debug("Update queued: " .. tableName .. "/" .. tostring(key))
end

local function QueueHasPending()
    for _, keys in pairs(broadcastQueue) do
        if next(keys) then
            return true
        end
    end
    return false
end

--- Estimate chat wire length using public Serialize/Compress/EncodeForPrint.
--- LibP2PDB has no chat size API; BroadcastKeyChatChannel still returns true when oversized.
local function EstimateChatMsgLen(db, tableName, key)
    local dataOk, data = pcall(function()
        return LibP2PDB:GetKey(db, tableName, key)
    end)
    if not dataOk then
        return nil
    end
    -- Stand-in RowsResponse-shaped packet (version tuple is approximate).
    local rowState = { data, 1, 1 }
    local packet = {
        7, -- CommMessageType.RowsResponse
        1,
        { 1, 1, { [tableName] = { [key] = rowState } } },
    }
    local ser = LibP2PDB:Serialize(db, packet)
    if type(ser) ~= "string" then
        return nil
    end
    local comp = LibP2PDB:Compress(db, ser)
    if type(comp) ~= "string" then
        return nil
    end
    local enc = LibP2PDB:EncodeForPrint(db, comp)
    if type(enc) ~= "string" then
        return nil
    end
    return #DB_PREFIX + 1 + #tostring(#enc) + 1 + #enc
end

--- Flush pending keys via BroadcastKeyChatChannel. Must run from a hardware event.
function addon.FlushBroadcastQueue()
    if not QueueHasPending() then
        return
    end
    if not LibP2PDB or not dbHandle then
        return
    end
    -- Hardware-only join/rotate retry (bypasses CommChannel auto-cycle cap).
    if addon.EnsureHCACommChannel then
        addon.EnsureHCACommChannel()
    end
    if not addon.TryRegisterHCAChatChannel(dbHandle) then
        Debug("Broadcast skipped: channel not ready")
        return
    end

    for tableName, keys in pairs(broadcastQueue) do
        for key in pairs(keys) do
            -- HasKey errors must not drop the queue entry; only a definitive false does.
            local hasOk, hasKey = pcall(function()
                return LibP2PDB:HasKey(dbHandle, tableName, key) and true or false
            end)
            if not hasOk then
                Debug("HasKey failed (retained): " .. tableName .. "/" .. tostring(key))
            elseif not hasKey then
                keys[key] = nil
            elseif chatSendFailed[tableName] and chatSendFailed[tableName][key] then
                keys[key] = nil
            else
                local est = EstimateChatMsgLen(dbHandle, tableName, key)
                if est and est + CHAT_SIZE_MARGIN > CHAT_MAX_BYTES then
                    keys[key] = nil
                    chatSendFailed[tableName] = chatSendFailed[tableName] or {}
                    chatSendFailed[tableName][key] = true
                    Debug("Broadcast oversized (until republish): " .. tableName .. "/" .. tostring(key)
                        .. " est=" .. tostring(est))
                else
                    -- Size preflight passed. LibP2PDB still returns true even when it silently
                    -- drops oversized payloads; we do not treat a clean pcall as delivery proof.
                    local ok = pcall(function()
                        LibP2PDB:BroadcastKeyChatChannel(dbHandle, tableName, key)
                    end)
                    if ok then
                        keys[key] = nil
                        Debug("Broadcast sent: " .. tableName .. "/" .. tostring(key)
                            .. (est and (" est=" .. tostring(est)) or ""))
                    else
                        -- Retain for the next hardware flush.
                        Debug("Broadcast invoke failed (retained): " .. tableName .. "/" .. tostring(key))
                    end
                end
            end
        end
        if not next(keys) then
            broadcastQueue[tableName] = nil
        end
    end
end

local function HookToggle(apiName, bindingToken)
    if type(_G[apiName]) ~= "function" then
        return
    end
    hooksecurefunc(apiName, function()
        if bindingToken and not strfind(debugstack(), bindingToken, 1, true) then
            return
        end
        addon.FlushBroadcastQueue()
    end)
end

local function InstallHardwareHooks()
    if hooksInstalled then
        return
    end
    hooksInstalled = true

    -- Preserve the verified working set (binding tokens from Blizzard secure actions).
    HookToggle("ToggleAllBags", "OPENALLBAGS")
    HookToggle("ToggleBackpack", "TOGGLEBACKPACK")
    HookToggle("ToggleCharacter", "TOGGLECHARACTER")
    HookToggle("ToggleQuestLog", "TOGGLEQUESTLOG")
    HookToggle("ToggleWorldMap", "TOGGLEWORLDMAP")
    HookToggle("ToggleSpellBook", "TOGGLESPELLBOOK")
    -- ToggleGameMenu omitted: SendChatMessage from that stack raised ADDON_ACTION_BLOCKED.
    HookToggle("ToggleFriendsFrame", "TOGGLEFRIENDSTAB")
    HookToggle("ToggleGuildFrame", "TOGGLEGUILDTAB")
    HookToggle("ToggleTalentFrame", "TOGGLETALENTS")
end

--- Called from Leaderboard Sync:Initialize after the HCALB database exists.
--- @param db table LibP2PDB database handle
function addon.InitializeHCAChatBroadcast(db)
    if type(db) ~= "table" then
        return
    end
    dbHandle = db
    InstallHardwareHooks()
    addon.TryRegisterHCAChatChannel(db)
end

-- Late register after Sync.Initialize; clear registration if membership drops.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("CHANNEL_UI_UPDATE")
boot:RegisterEvent("CHANNEL_COUNT_UPDATE")
boot:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        InstallHardwareHooks()
        addon.TryRegisterHCAChatChannel()
        return
    end
    if ChannelReady() then
        addon.TryRegisterHCAChatChannel()
    else
        ClearChannelRegistration()
    end
end)
