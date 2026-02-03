-- Utils/GuildFirst.lua
-- Simple "guild first" claim system backed by LibP2PDB.
-- 
-- How it works:
-- 1. When an achievement triggers, check if it's already claimed.
-- 2. If not claimed: claim it locally, broadcast to all online peers, and award immediately.
-- 3. If claimed by someone else: silently fail (achievement stays hidden).
--
-- Propagation (handled by LibP2PDB):
-- - BroadcastKey: Immediately broadcasts claim to all online peers via GUILD/RAID/PARTY/YELL channels
-- - DiscoverPeers: Periodically finds new peers (every 30s) and syncs when they come online
-- - SyncDatabase: Gossip-style sync with neighbors via WHISPER (exchanges digests, requests missing data)
-- - Persistence: Saves state to SavedVariables on claim + every 60s, loads on login
--
-- When a player comes online:
-- - Loads saved state from SavedVariables (restores all previous claims)
-- - Discovers peers via GUILD channel broadcasts
-- - Syncs with neighbors to get any claims made while offline
-- - All online players eventually converge to the same state via gossip protocol

local LibStub = LibStub
if not LibStub then return end

local LibP2PDB = LibStub("LibP2PDB", true)
if not LibP2PDB then return end

local TABLE_NAME = "Claims"
local state = {
    db = nil,
    prefix = nil,
    guildKey = nil,
    discoverTicker = nil,
    initDone = false,
}

local M = {}
_G.HCA_GuildFirst = M

-- ---------------------------------------------------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------------------------------------------------

local function GetGuildKey()
    C_GuildInfo.GuildRoster()
    local guildName = GetGuildInfo and GetGuildInfo("player")
    if not guildName or guildName == "" then
        return nil
    end
    local realm = GetRealmName and GetRealmName() or ""
    return tostring(guildName) .. "@" .. tostring(realm)
end

local function Hash32(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return h
end

local function PrefixForGuild(guildKey)
    -- Must be <= 16 chars; "HCAGF" (5) + 8 hex = 13 chars
    return "HCAGF" .. string.format("%08X", Hash32(guildKey))
end

local function FindRowByAchId(achId)
    if not _G.AchievementPanel or not _G.AchievementPanel.achievements then
        return nil
    end
    for _, row in ipairs(_G.AchievementPanel.achievements) do
        if tostring(row.id or row.achId or "") == tostring(achId) then
            return row
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Database initialization
-- ---------------------------------------------------------------------------------------------------------------------

local function EnsureDBInitialized()
    if state.initDone then
        return true
    end

    local guildKey = GetGuildKey()
    if not guildKey then
        return false
    end

    state.guildKey = guildKey
    state.prefix = PrefixForGuild(guildKey)

    -- Get or create database (uses LibP2PDB defaults: LibPatternedBloomFilter, LibSerialize, LibDeflate)
    local db = LibP2PDB:GetDatabase(state.prefix)
    if not db then
        db = LibP2PDB:NewDatabase({
            prefix = state.prefix,
            version = 1,
            onDiscoveryComplete = function()
                if state.db then
                    LibP2PDB:SyncDatabase(state.db)
                end
            end,
        })
    end

    state.db = db

    -- Create claims table (ignore error if already exists)
    pcall(function()
        LibP2PDB:NewTable(db, {
            name = TABLE_NAME,
            keyType = "string",
            schema = {
                winnerName = "string",
                winnerGUID = "string",
                claimedAt = "number",
            },
            onChange = function(_key, _data)
                -- When a claim changes, refresh the achievement filter to hide/show rows
                if type(_G.HCA_ApplyFilter) == "function" then
                    C_Timer.After(0.1, function()
                        _G.HCA_ApplyFilter()
                    end)
                end
            end,
        })
    end)

    -- Load persisted state
    local root = _G.HardcoreAchievementsDB
    if root and root.guildFirst and root.guildFirst[guildKey] and root.guildFirst[guildKey].state then
        pcall(function()
            LibP2PDB:ImportDatabase(db, root.guildFirst[guildKey].state)
        end)
    end

    -- Periodic peer discovery and sync
    if state.discoverTicker and state.discoverTicker.Cancel then
        state.discoverTicker:Cancel()
    end
    state.discoverTicker = C_Timer.NewTicker(30.0, function()
        if state.db then
            LibP2PDB:DiscoverPeers(state.db)
        end
    end)

    -- Initial discovery
    LibP2PDB:DiscoverPeers(db)

    -- Save state periodically
    C_Timer.NewTicker(60.0, function()
        if state.db and state.guildKey then
            local root = _G.HardcoreAchievementsDB or {}
            root.guildFirst = root.guildFirst or {}
            local dbState = LibP2PDB:ExportDatabase(state.db)
            if dbState then
                root.guildFirst[state.guildKey] = {
                    version = 1,
                    prefix = state.prefix,
                    state = dbState,
                    savedAt = time(),
                }
            end
        end
    end)

    state.initDone = true
    return true
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------------------------------------------------

--- Check if an achievement is already claimed by someone else.
--- @param achievementId string
--- @return boolean isClaimed, table? winnerRecord
function M:IsClaimed(achievementId)
    if not EnsureDBInitialized() then
        return false, nil
    end
    local rec = LibP2PDB:GetKey(state.db, TABLE_NAME, tostring(achievementId))
    if rec then
        local myGUID = UnitGUID("player") or ""
        return true, rec
    end
    return false, nil
end

--- Check if an achievement is claimed by the current player.
--- @param achievementId string
--- @return boolean isClaimedByMe
function M:IsClaimedByMe(achievementId)
    if not EnsureDBInitialized() then
        return false
    end
    local rec = LibP2PDB:GetKey(state.db, TABLE_NAME, tostring(achievementId))
    if rec then
        local myGUID = UnitGUID("player") or ""
        return rec.winnerGUID == myGUID
    end
    return false
end

--- Attempt to claim and award an achievement.
--- Returns true if awarded, false if already claimed (silent fail).
--- @param achievementId string
--- @param row table? Optional achievement row (will find if not provided)
--- @return boolean awarded
function M:CanClaimAndAward(achievementId, row)
    achievementId = tostring(achievementId or "")
    if achievementId == "" then
        return false
    end

    if not EnsureDBInitialized() then
        return false
    end

    -- Check if already claimed
    local existing = LibP2PDB:GetKey(state.db, TABLE_NAME, achievementId)
    if existing then
        -- Already claimed - silently fail
        return false
    end

    -- Claim it
    local myName = UnitName("player") or ""
    local myGUID = UnitGUID("player") or ""
    local claim = {
        winnerName = myName,
        winnerGUID = myGUID,
        claimedAt = time(),
    }

    pcall(function()
        LibP2PDB:SetKey(state.db, TABLE_NAME, achievementId, claim)
        LibP2PDB:BroadcastKey(state.db, TABLE_NAME, achievementId)
        LibP2PDB:DiscoverPeers(state.db)
        LibP2PDB:SyncDatabase(state.db)
        
        -- Save immediately after claiming (don't wait for periodic save)
        if state.guildKey then
            local root = _G.HardcoreAchievementsDB or {}
            root.guildFirst = root.guildFirst or {}
            local dbState = LibP2PDB:ExportDatabase(state.db)
            if dbState then
                root.guildFirst[state.guildKey] = {
                    version = 1,
                    prefix = state.prefix,
                    state = dbState,
                    savedAt = time(),
                }
            end
        end
    end)

    -- Award the achievement
    if not row then
        row = FindRowByAchId(achievementId)
    end

    if row and type(_G.HCA_MarkRowCompleted) == "function" then
        _G.HCA_MarkRowCompleted(row)
        if type(_G.HCA_AchToast_Show) == "function" and row.Icon and row.Title then
            _G.HCA_AchToast_Show(row.Icon:GetTexture(), row.Title:GetText(), row.points or 0, row)
        end
        return true
    end

    return false
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Testing slash command
-- ---------------------------------------------------------------------------------------------------------------------

local function HandleSlash(msg)
    msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" or msg == "help" then
        print("|cff008066[Hardcore Achievements]|r GuildFirst commands:")
        print("  |cffffd100/hcagf claim|r - Attempt to claim the test guild-first achievement")
        print("  |cffffd100/hcagf status|r - Show current winner (if any)")
        return
    end

    if msg == "claim" then
        local achId = "GuildFirstTest01"
        local row = _G.HCA_GuildFirst_TestRow or FindRowByAchId(achId)
        if M:CanClaimAndAward(achId, row) then
            print("|cff008066[Hardcore Achievements]|r |cff00ff00Claimed and awarded!|r")
        else
            print("|cff008066[Hardcore Achievements]|r |cffff0000Already claimed by someone else.|r")
        end
        return
    end

    if msg == "status" then
        local achId = "GuildFirstTest01"
        local isClaimed, winner = M:IsClaimed(achId)
        if isClaimed and winner then
            print(string.format("|cff008066[Hardcore Achievements]|r Winner: |cffffd100%s|r", tostring(winner.winnerName or "?")))
        else
            print("|cff008066[Hardcore Achievements]|r Not claimed yet.")
        end
        return
    end

    print("|cff008066[Hardcore Achievements]|r Unknown command. Use |cffffd100/hcagf help|r")
end

SLASH_HCAGUILDFIRST1 = "/hcagf"
SlashCmdList["HCAGUILDFIRST"] = HandleSlash

-- Initialize on login/guild events
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
initFrame:SetScript("OnEvent", function()
    EnsureDBInitialized()
end)

