local addonName, addon = ...

-- =========================================================
-- Forever: pace HCA addon whispers
--
-- Forever reorders addon whispers sent in the same instant (a burst of 10 arrived as
-- 1,4,3,2,6,9,10,8,5,7); 0.05s+ spacing arrived in order. AceComm reassembles multi-part
-- messages in arrival order, so reordered parts corrupt LibP2PDB gossip chunks
-- (LibDeflate / LibSerialize failures). Classic delivers in order and is unaffected.
--
-- Wraps the shared ChatThrottleLib:SendAddonMessage (AceComm calls it per part) and
-- releases HCA-prefixed WHISPER parts one at a time, in order. Everything else passes through.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local SEND_INTERVAL = 0.1
-- LibP2PDB prefixes: HCALB (leaderboard) and HCA%08X (guild-first scopes).
local PREFIX_PATTERN = "^HCA"

local GetTime = GetTime
local C_Timer = C_Timer
local select = select
local unpack = unpack

local queue = {}
local head, tail = 1, 0
local lastSentAt = 0
local pumpScheduled = false
local originalSend
local wrappedSend
local installedOn

local Pump

local function SchedulePump(delay)
    if pumpScheduled then
        return
    end
    pumpScheduled = true
    C_Timer.After(delay, Pump)
end

Pump = function()
    pumpScheduled = false
    if head > tail then
        return
    end
    local elapsed = GetTime() - lastSentAt
    if elapsed < SEND_INTERVAL then
        SchedulePump(SEND_INTERVAL - elapsed)
        return
    end
    local item = queue[head]
    queue[head] = nil
    head = head + 1
    lastSentAt = GetTime()
    local ok, err = pcall(item.send, unpack(item, 1, item.n))
    if not ok then
        geterrorhandler()(err)
    end
    if head <= tail then
        SchedulePump(SEND_INTERVAL)
    else
        head, tail = 1, 0
    end
end

local function Install()
    local CTL = _G.ChatThrottleLib
    if not CTL or type(CTL.SendAddonMessage) ~= "function" then
        return
    end
    if installedOn == CTL and CTL.SendAddonMessage == wrappedSend then
        return
    end
    -- A newer ChatThrottleLib loaded after us replaces the method; re-wrap the new one.
    originalSend = CTL.SendAddonMessage
    local send = originalSend
    wrappedSend = function(self, prio, prefix, text, chattype, ...)
        if chattype ~= "WHISPER" or type(prefix) ~= "string" or not prefix:find(PREFIX_PATTERN) then
            return send(self, prio, prefix, text, chattype, ...)
        end
        tail = tail + 1
        queue[tail] = { send = send, n = select("#", ...) + 5, self, prio, prefix, text, chattype, ... }
        SchedulePump(0)
    end
    CTL.SendAddonMessage = wrappedSend
    installedOn = CTL
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or IsLoggedIn() then
        Install()
    end
end)
