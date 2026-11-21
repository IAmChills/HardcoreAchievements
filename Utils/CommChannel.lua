local addonName, addon = ...

-- =========================================================
-- Rotating chat channel for LibP2PDB broadcasts (Classic / TBC / Forever)
--
-- Shared period from GetServerTime() / 1337 → deterministic hca###### name +
-- 16-hex password. Seed fallbacks if a name is locked/full. Heartbeat leaves
-- and rejoins when the period rolls or membership is lost.
--
-- LibP2PDB stock GUILD/PARTY/RAID/YELL still applies. Open-world presence uses
-- RegisterChatChannel / BroadcastKeyChatChannel (real SendChatMessage), flushed
-- from hardware events in ChatBroadcast.lua. Do not use NewDatabase channels.
-- =========================================================

local GetServerTime = GetServerTime
local GetChannelName = GetChannelName
local LeaveChannelByName = LeaveChannelByName
local JoinTemporaryChannel = JoinTemporaryChannel
local JoinChannelByName = JoinChannelByName
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local pcall = pcall
local floor = math.floor
local band = bit.band
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift
local format = string.format
local tostring = tostring
local type = type

-- HCA-specific (not Hardcore addon constants).
local PERIOD_SECONDS = 1337
local MAX_SEED = 12
local JOIN_PENDING_TIMEOUT = 2
local HEARTBEAT_SECONDS = 20
-- Background join attempts per login before only hardware Ensure may retry a cycle.
local MAX_AUTO_JOIN_CYCLES = 3

local activePeriod = nil
local activeSeed = 0
local activeName = nil
local activePassword = nil
local joinPending = false
local joinPendingToken = 0
local pendingPeriod = nil
local pendingSeed = nil
local pendingName = nil
local pendingPassword = nil
local autoJoinCycles = 0
local heartbeatStarted = false

addon.HCA_COMM_CHANNEL_NAME = nil
addon.HCACommChannelIndex = nil

local function Debug(msg)
    if addon.DebugPrint then
        addon.DebugPrint("[CommChannel] " .. tostring(msg))
    end
end

--- Mix period + seed into a 32-bit value (HCA scramble; independent of other addons).
local function Mix32(periodNumber, seed)
    local x = band(periodNumber or 0, 0xFFFFFFFF)
    x = bxor(x, band(lshift(seed or 0, 9), 0xFFFFFFFF))
    x = bxor(x, 0xA5A5C3C3)
    x = bxor(x, lshift(band(x, 0xFFFF), 16))
    x = bxor(x, rshift(x, 13))
    x = bxor(x, lshift(band(x, 0xFFF), 7))
    x = bxor(x, 0x5A5A9696)
    x = bxor(x, rshift(x, 11))
    return band(x, 0xFFFFFFFF)
end

--- @return string name hca + 6 hex digits
--- @return string password 16 hex chars
local function DeriveChannel(periodNumber, seed)
    local nameBits = Mix32(periodNumber, seed)
    local passA = Mix32(bxor(periodNumber, 0x0F1E2D3C), seed + 17)
    local passB = Mix32(bxor(periodNumber, 0x7E6D5C4B), seed + 41)
    local name = format("hca%06X", band(nameBits, 0xFFFFFF))
    local password = format("%08X%08X", passA, passB)
    return name, password
end

local function CurrentPeriodNumber()
    local now = GetServerTime and GetServerTime()
    if type(now) ~= "number" or now <= 0 then
        return nil
    end
    return floor(now / PERIOD_SECONDS)
end

--- Leaving/joining is blocked (ADDON_ACTION_BLOCKED, not a Lua error) during combat and Forever
--- encounter chat restrictions; the heartbeat retries once they lift.
local function ChannelChangesBlocked()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    return addon.IsForeverChatRestricted and addon.IsForeverChatRestricted() or false
end

local function DefaultChannelsReady()
    local id = GetChannelName and GetChannelName("General")
    return type(id) == "number" and id > 0
end

local function ChannelIndex(name)
    if type(name) ~= "string" or name == "" or not GetChannelName then
        return nil
    end
    local id = GetChannelName(name)
    if type(id) == "number" and id > 0 then
        return id
    end
    return nil
end

local function NotifyChannelLeft(oldName)
    if type(oldName) == "string" and oldName ~= "" and addon.OnHCACommChannelLeft then
        pcall(addon.OnHCACommChannelLeft, oldName)
    end
end

local function SetActive(periodNumber, seed, name, password)
    activePeriod = periodNumber
    activeSeed = seed
    activeName = name
    activePassword = password
    addon.HCA_COMM_CHANNEL_NAME = name
    addon.HCACommChannelIndex = ChannelIndex(name)
end

local function ClearActive(notify)
    local old = activeName
    activePeriod = nil
    activeSeed = 0
    activeName = nil
    activePassword = nil
    addon.HCA_COMM_CHANNEL_NAME = nil
    addon.HCACommChannelIndex = nil
    if notify and old then
        NotifyChannelLeft(old)
    end
end

local function LeaveNamed(name)
    if type(name) ~= "string" or name == "" then
        return
    end
    if LeaveChannelByName then
        pcall(LeaveChannelByName, name)
    end
    NotifyChannelLeft(name)
end

--- Leave + unregister every derived HCA name for a period except keepName (may be nil).
local function LeavePeriodChannels(periodNumber, keepName)
    if type(periodNumber) ~= "number" then
        return
    end
    for seed = 0, MAX_SEED do
        local name = DeriveChannel(periodNumber, seed)
        if name ~= keepName and ChannelIndex(name) then
            LeaveNamed(name)
        end
    end
end

--- Drop remembered membership that is no longer the live channel (always leave + unregister).
local function LeaveActiveIfAny()
    local old = activeName
    if not old then
        return
    end
    ClearActive(false)
    LeaveNamed(old)
end

local function TryJoinAPI(name, password)
    if JoinTemporaryChannel then
        local ok = pcall(JoinTemporaryChannel, name, password)
        if ok then
            return true
        end
    end
    if JoinChannelByName then
        return pcall(JoinChannelByName, name, password)
    end
    return false
end

local function ClearPending()
    joinPending = false
    pendingPeriod = nil
    pendingSeed = nil
    pendingName = nil
    pendingPassword = nil
end

local function MarkJoined(periodNumber, seed, name, password)
    joinPendingToken = joinPendingToken + 1
    ClearPending()
    autoJoinCycles = 0
    local prev = activeName
    SetActive(periodNumber, seed, name, password)
    if prev and prev ~= name then
        NotifyChannelLeft(prev)
    end
    Debug("Joined " .. name .. " period=" .. tostring(periodNumber) .. " seed=" .. tostring(seed))
    if addon.TryRegisterHCAChatChannel then
        addon.TryRegisterHCAChatChannel()
    end
    return true
end

local TryJoinCycle

local function ScheduleJoinPendingTimeout(periodNumber, seed, name, password, fromHardwareFlush)
    if not (C_Timer and C_Timer.After) then
        joinPending = false
        return
    end
    joinPendingToken = joinPendingToken + 1
    local token = joinPendingToken
    C_Timer.After(JOIN_PENDING_TIMEOUT, function()
        if token ~= joinPendingToken then
            return
        end
        if ChannelIndex(name) then
            MarkJoined(periodNumber, seed, name, password)
            return
        end
        ClearPending()
        -- Seed fallback: same period, next seed (all clients that fail seed N share seed N+1).
        if seed < MAX_SEED then
            Debug("Join timeout " .. name .. " → seed " .. tostring(seed + 1))
            TryJoinCycle(fromHardwareFlush, periodNumber, seed + 1)
            return
        end
        Debug("Join exhausted seeds for period " .. tostring(periodNumber))
    end)
end

--- Attempt one (period, seed). On failure climb seed so peers converge on the first open slot.
TryJoinCycle = function(fromHardwareFlush, periodNumber, seed)
    periodNumber = periodNumber or CurrentPeriodNumber()
    if not periodNumber then
        return false
    end
    seed = seed or 0
    if seed > MAX_SEED then
        return false
    end
    if not DefaultChannelsReady() or ChannelChangesBlocked() then
        return false
    end
    if joinPending then
        return false
    end

    -- Already on a live channel for this period.
    if activeName and activePeriod == periodNumber and ChannelIndex(activeName) then
        addon.HCACommChannelIndex = ChannelIndex(activeName)
        return true
    end

    if not fromHardwareFlush and autoJoinCycles >= MAX_AUTO_JOIN_CYCLES and seed == 0 then
        return false
    end

    local name, password = DeriveChannel(periodNumber, seed)
    if ChannelIndex(name) then
        return MarkJoined(periodNumber, seed, name, password)
    end

    if not fromHardwareFlush and seed == 0 then
        autoJoinCycles = autoJoinCycles + 1
    end

    joinPending = true
    pendingPeriod = periodNumber
    pendingSeed = seed
    pendingName = name
    pendingPassword = password
    if not TryJoinAPI(name, password) then
        ClearPending()
        if seed < MAX_SEED then
            return TryJoinCycle(fromHardwareFlush, periodNumber, seed + 1)
        end
        return false
    end

    if ChannelIndex(name) then
        return MarkJoined(periodNumber, seed, name, password)
    end

    ScheduleJoinPendingTimeout(periodNumber, seed, name, password, fromHardwareFlush)
    return false
end

local function RotateToPeriod(periodNumber, fromHardwareFlush)
    if not periodNumber then
        return false
    end
    if activeName and activePeriod == periodNumber and ChannelIndex(activeName) then
        return true
    end

    local oldName = activeName
    if oldName then
        -- Leaving clears Lib registration via OnHCACommChannelLeft before join.
        activeName = nil
        addon.HCA_COMM_CHANNEL_NAME = nil
        addon.HCACommChannelIndex = nil
        LeaveNamed(oldName)
    end
    activePeriod = periodNumber
    activeSeed = 0
    activePassword = nil
    joinPendingToken = joinPendingToken + 1
    ClearPending()
    return TryJoinCycle(fromHardwareFlush, periodNumber, 0)
end

--- Hardware flush only: bypasses the auto-cycle cap. Do not call from channel events.
function addon.EnsureHCACommChannel()
    local periodNumber = CurrentPeriodNumber()
    if not periodNumber then
        return false
    end
    if ChannelChangesBlocked() then
        return activeName ~= nil and activePeriod == periodNumber and ChannelIndex(activeName) ~= nil
    end
    if activePeriod and activePeriod ~= periodNumber then
        return RotateToPeriod(periodNumber, true)
    end
    if activeName and ChannelIndex(activeName) then
        addon.HCACommChannelIndex = ChannelIndex(activeName)
        return true
    end
    return TryJoinCycle(true, periodNumber, activeSeed or 0)
end

function addon.GetHCACommChannelName()
    if activeName and ChannelIndex(activeName) then
        return activeName
    end
    return nil
end

function addon.GetHCACommChannelIndex()
    local name = addon.GetHCACommChannelName()
    if not name then
        addon.HCACommChannelIndex = nil
        return nil
    end
    local id = ChannelIndex(name)
    addon.HCACommChannelIndex = id
    return id
end

--- Current derived credentials for the active period/seed (for diagnostics).
function addon.GetHCACommChannelInfo()
    local periodNumber = activePeriod or CurrentPeriodNumber()
    local seed = activeSeed or 0
    local name, password = DeriveChannel(periodNumber or 0, seed)
    return {
        period = periodNumber,
        seed = seed,
        name = activeName or name,
        password = activePassword or password,
        joined = activeName ~= nil and ChannelIndex(activeName) ~= nil,
        periodSeconds = PERIOD_SECONDS,
    }
end

local function Heartbeat()
    local periodNumber = CurrentPeriodNumber()
    if not periodNumber or ChannelChangesBlocked() then
        return
    end

    if activePeriod and activePeriod ~= periodNumber then
        Debug("Period roll " .. tostring(activePeriod) .. " → " .. tostring(periodNumber))
        RotateToPeriod(periodNumber, false)
        return
    end

    if activeName then
        if ChannelIndex(activeName) then
            addon.HCACommChannelIndex = ChannelIndex(activeName)
            if addon.TryRegisterHCAChatChannel then
                addon.TryRegisterHCAChatChannel()
            end
            return
        end
        -- Membership lost: rejoin same period starting at the seed we last used, then climb.
        Debug("Missing channel " .. tostring(activeName) .. " — rejoining")
        local seed = activeSeed or 0
        local old = activeName
        activeName = nil
        addon.HCA_COMM_CHANNEL_NAME = nil
        addon.HCACommChannelIndex = nil
        NotifyChannelLeft(old)
        TryJoinCycle(false, periodNumber, seed)
        return
    end

    TryJoinCycle(false, periodNumber, 0)
end

local function StartHeartbeat()
    if heartbeatStarted or not (C_Timer and C_Timer.NewTicker) then
        return
    end
    heartbeatStarted = true
    C_Timer.NewTicker(HEARTBEAT_SECONDS, Heartbeat)
end

--- After zone or /reload: keep only the current period's joined HCA channel.
--- Defined after ClearPending / MarkJoined / TryJoinCycle / StartHeartbeat so locals resolve.
--- Reuses an existing membership when possible; otherwise leaves stale channels and rejoins.
local function ReconcileEnteringWorld()
    joinPendingToken = joinPendingToken + 1
    ClearPending()
    autoJoinCycles = 0
    StartHeartbeat()
    if ChannelChangesBlocked() then
        return false
    end

    local periodNumber = CurrentPeriodNumber()
    if not periodNumber then
        LeaveActiveIfAny()
        return false
    end

    -- Still tracked and live for this period: keep registration, do not leave.
    if activeName and activePeriod == periodNumber and ChannelIndex(activeName) then
        -- Ensure no sibling seed for this period (or prior period) lingers.
        LeavePeriodChannels(periodNumber, activeName)
        if periodNumber > 0 then
            LeavePeriodChannels(periodNumber - 1, nil)
        end
        addon.HCA_COMM_CHANNEL_NAME = activeName
        addon.HCACommChannelIndex = ChannelIndex(activeName)
        if addon.TryRegisterHCAChatChannel then
            addon.TryRegisterHCAChatChannel()
        end
        return true
    end

    -- Membership may have survived /reload or zoning while Lua state reset or period drifted.
    for seed = 0, MAX_SEED do
        local name, password = DeriveChannel(periodNumber, seed)
        if ChannelIndex(name) then
            if activeName and activeName ~= name then
                LeaveActiveIfAny()
            end
            LeavePeriodChannels(periodNumber, name)
            if periodNumber > 0 then
                LeavePeriodChannels(periodNumber - 1, nil)
            end
            return MarkJoined(periodNumber, seed, name, password)
        end
    end

    -- Not in the current period channel: leave remembered + prior-period leftovers, then join.
    LeaveActiveIfAny()
    if periodNumber > 0 then
        LeavePeriodChannels(periodNumber - 1, nil)
    end
    LeavePeriodChannels(periodNumber, nil)
    return TryJoinCycle(false, periodNumber, 0)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("CHANNEL_UI_UPDATE")
boot:RegisterEvent("CHANNEL_COUNT_UPDATE")
boot:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ReconcileEnteringWorld()
        return
    end

    if activeName and ChannelIndex(activeName) then
        joinPendingToken = joinPendingToken + 1
        ClearPending()
        autoJoinCycles = 0
        addon.HCA_COMM_CHANNEL_NAME = activeName
        addon.HCACommChannelIndex = ChannelIndex(activeName)
        if addon.TryRegisterHCAChatChannel then
            addon.TryRegisterHCAChatChannel()
        end
        return
    end

    -- Async join succeeded: accept pending seed immediately so peers converge without waiting.
    if joinPending and pendingName and ChannelIndex(pendingName) then
        MarkJoined(pendingPeriod, pendingSeed, pendingName, pendingPassword)
        return
    end

    if joinPending then
        return
    end

    local periodNumber = CurrentPeriodNumber()
    if not periodNumber or ChannelChangesBlocked() then
        return
    end
    if activePeriod and activePeriod ~= periodNumber then
        RotateToPeriod(periodNumber, false)
        return
    end
    TryJoinCycle(false, periodNumber, activeSeed or 0)
end)
