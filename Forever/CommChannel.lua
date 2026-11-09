local addonName, addon = ...

-- =========================================================
-- Forever: shared "HCA" chat channel for LibP2PDB broadcasts
--
-- LibP2PDB keeps GUILD/PARTY/RAID/YELL and also accepts desc.channels
-- (channel name strings; lib resolves to SendAddonMessage CHANNEL).
-- This file only joins/refreshes the channel so the name stays valid.
-- Classic/TBC never load this.
--
-- Join once after default zone channels (e.g. General) exist so HCA is
-- not assigned chat index 1 ahead of them.
-- =========================================================

if not (addon and addon.IsForeverClient and addon.IsForeverClient()) then
    return
end

local CHANNEL_NAME = "HCA"
local CHANNEL_PW = "ACHIEVEMENT"
addon.HCA_COMM_CHANNEL_NAME = CHANNEL_NAME

local joined = false

local function RefreshChannelIndex()
    local id = GetChannelName and GetChannelName(CHANNEL_NAME)
    if type(id) == "number" and id > 0 then
        addon.HCACommChannelIndex = id
        return id
    end
    addon.HCACommChannelIndex = nil
    return nil
end

local function DefaultChannelsReady()
    local id = GetChannelName and GetChannelName("General")
    return type(id) == "number" and id > 0
end

local function TryJoinOnce()
    if joined then
        RefreshChannelIndex()
        return addon.HCACommChannelIndex ~= nil
    end
    if RefreshChannelIndex() then
        joined = true
        return true
    end
    if not DefaultChannelsReady() then
        return false
    end
    joined = true
    -- Omit chat frame id so the channel is for addon traffic, not chat spam.
    if JoinChannelByName then
        pcall(JoinChannelByName, CHANNEL_NAME, CHANNEL_PW)
    end
    return RefreshChannelIndex() ~= nil
end

function addon.EnsureHCACommChannel()
    return TryJoinOnce()
end

function addon.GetHCACommChannelIndex()
    return RefreshChannelIndex()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("CHANNEL_UI_UPDATE")
boot:RegisterEvent("CHANNEL_COUNT_UPDATE")
boot:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        joined = false
        addon.HCACommChannelIndex = nil
        -- Reload often skips further CHANNEL_UI events; join now if General is already up.
        TryJoinOnce()
        return
    end
    TryJoinOnce()
end)
