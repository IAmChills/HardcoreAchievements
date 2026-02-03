-- Utils/GuildFirst.lua
-- Flexible "first" claim system backed by LibP2PDB.
-- Supports multiple scopes: guild-first (default), server-first, or custom guild pools.
-- 
-- Achievement scope options (in achievement definition):
--   - nil or "guild" (default): First in player's current guild
--   - "server": First on the entire server
--   - {"GuildA", "GuildB"}: First in any of the specified guilds
--
-- How it works:
-- 1. When an achievement triggers, check its scope and if it's already claimed.
-- 2. If not claimed: claim it locally, broadcast to all online peers, and award immediately.
-- 3. If claimed by someone else: silently fail (achievement stays hidden).
--
-- Propagation (handled by LibP2PDB):
-- - BroadcastKey: Immediately broadcasts claim to all online peers via GUILD/RAID/PARTY/YELL channels
-- - DiscoverPeers: Periodically finds new peers (every 30s) and syncs when they come online
-- - SyncDatabase: Gossip-style sync with neighbors via WHISPER (exchanges digests, requests missing data)
-- - Persistence: Saves state to SavedVariables on claim + every 60s, loads on login

local LibStub = LibStub
if not LibStub then return end

local LibP2PDB = LibStub("LibP2PDB", true)
if not LibP2PDB then return end

local TABLE_NAME = "Claims"
local databases = {}  -- [scopeKey] = { db = DBHandle, prefix = string, discoverTicker = ticker }

local M = {}
_G.HCA_GuildFirst = M

-- ---------------------------------------------------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------------------------------------------------

local function GetGuildName()
    C_GuildInfo.GuildRoster()
    return GetGuildInfo and GetGuildInfo("player") or nil
end

local function GetRealmName()
    return GetRealmName and GetRealmName() or ""
end

local function Hash32(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return h
end

local function PrefixForKey(key)
    -- Must be <= 16 chars; "HCAGF" (5) + 8 hex = 13 chars
    return "HCAGF" .. string.format("%08X", Hash32(key))
end

--- Determine the scope key for an achievement based on its definition.
--- @param scope string|table|nil Scope from achievement definition
--- @return string? scopeKey Returns nil if scope is invalid or player can't participate
local function GetScopeKey(scope)
    local realm = GetRealmName()
    if realm == "" then
        return nil
    end

    -- Default to guild-first if not specified
    if scope == nil or scope == "guild" then
        local guildName = GetGuildName()
        if not guildName or guildName == "" then
            return nil  -- Not in a guild, can't participate in guild-first
        end
        return "Guild@" .. tostring(guildName) .. "@" .. tostring(realm)
    end

    -- Server-wide
    if scope == "server" then
        return "Server@" .. tostring(realm)
    end

    -- Custom guild list: {"GuildA", "GuildB"}
    if type(scope) == "table" then
        local guildName = GetGuildName()
        if not guildName or guildName == "" then
            return nil  -- Not in a guild, can't participate
        end
        
        -- Check if player's guild is in the list
        local playerGuildLower = string.lower(tostring(guildName))
        for _, allowedGuild in ipairs(scope) do
            if string.lower(tostring(allowedGuild)) == playerGuildLower then
                -- Player is in an allowed guild - create deterministic key from sorted guild list
                local sortedGuilds = {}
                for _, g in ipairs(scope) do
                    table.insert(sortedGuilds, tostring(g))
                end
                table.sort(sortedGuilds)
                local guildListStr = table.concat(sortedGuilds, ",")
                return "Guilds@" .. guildListStr .. "@" .. tostring(realm)
            end
        end
        
        -- Player's guild is not in the allowed list
        return nil
    end

    return nil  -- Invalid scope
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

local function EnsureDBForScope(scopeKey)
    if not scopeKey then
        return nil
    end

    -- Return existing database if already initialized
    if databases[scopeKey] and databases[scopeKey].db then
        return databases[scopeKey].db
    end

    local prefix = PrefixForKey(scopeKey)

    -- Get or create database (uses LibP2PDB defaults: LibPatternedBloomFilter, LibSerialize, LibDeflate)
    local db = LibP2PDB:GetDatabase(prefix)
    if not db then
        db = LibP2PDB:NewDatabase({
            prefix = prefix,
            version = 1,
            onDiscoveryComplete = function()
                if databases[scopeKey] and databases[scopeKey].db then
                    LibP2PDB:SyncDatabase(databases[scopeKey].db)
                end
            end,
        })
    end

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
    if root and root.guildFirst and root.guildFirst[scopeKey] and root.guildFirst[scopeKey].state then
        pcall(function()
            LibP2PDB:ImportDatabase(db, root.guildFirst[scopeKey].state)
        end)
    end

    -- Periodic peer discovery and sync (only create one ticker per scope)
    if not databases[scopeKey] or not databases[scopeKey].discoverTicker then
        local ticker = C_Timer.NewTicker(30.0, function()
            if databases[scopeKey] and databases[scopeKey].db then
                LibP2PDB:DiscoverPeers(databases[scopeKey].db)
            end
        end)
        databases[scopeKey] = {
            db = db,
            prefix = prefix,
            scopeKey = scopeKey,
            discoverTicker = ticker,
        }
    end

    -- Initial discovery
    LibP2PDB:DiscoverPeers(db)

    -- Save state periodically (only create one saver per scope)
    if not databases[scopeKey].saveTicker then
        databases[scopeKey].saveTicker = C_Timer.NewTicker(60.0, function()
            if databases[scopeKey] and databases[scopeKey].db then
                local root = _G.HardcoreAchievementsDB or {}
                root.guildFirst = root.guildFirst or {}
                local dbState = LibP2PDB:ExportDatabase(databases[scopeKey].db)
                if dbState then
                    root.guildFirst[scopeKey] = {
                        version = 1,
                        prefix = databases[scopeKey].prefix,
                        state = dbState,
                        savedAt = time(),
                    }
                end
            end
        end)
    end

    return db
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------------------------------------------------

--- Get the scope for an achievement from its definition.
--- @param row table? Achievement row (checks row._def.achievementScope)
--- @param achievementId string? Optional achievement ID to look up row
--- @return string|table|nil scope
local function GetAchievementScope(row, achievementId)
    if row and row._def and row._def.achievementScope ~= nil then
        return row._def.achievementScope
    end
    
    -- Try to find row by ID if not provided
    if not row and achievementId then
        row = FindRowByAchId(achievementId)
        if row and row._def and row._def.achievementScope ~= nil then
            return row._def.achievementScope
        end
    end
    
    -- Default to guild-first
    return "guild"
end

--- Check if an achievement is already claimed by someone else.
--- @param achievementId string
--- @param row table? Optional achievement row (to determine scope)
--- @return boolean isClaimed, table? winnerRecord
function M:IsClaimed(achievementId, row)
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
        return false, nil
    end

    local db = EnsureDBForScope(scopeKey)
    if not db then
        return false, nil
    end

    local rec = LibP2PDB:GetKey(db, TABLE_NAME, tostring(achievementId))
    if rec then
        return true, rec
    end
    return false, nil
end

--- Check if an achievement is claimed by the current player.
--- @param achievementId string
--- @param row table? Optional achievement row (to determine scope)
--- @return boolean isClaimedByMe
function M:IsClaimedByMe(achievementId, row)
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
        return false
    end

    local db = EnsureDBForScope(scopeKey)
    if not db then
        return false
    end

    local rec = LibP2PDB:GetKey(db, TABLE_NAME, tostring(achievementId))
    if rec then
        local myGUID = UnitGUID("player") or ""
        return rec.winnerGUID == myGUID
    end
    return false
end

--- Attempt to claim and award an achievement.
--- Returns true if awarded, false if already claimed (silent fail).
--- @param achievementId string
--- @param row table? Optional achievement row (will find if not provided, also used to determine scope)
--- @return boolean awarded
function M:CanClaimAndAward(achievementId, row)
    achievementId = tostring(achievementId or "")
    if achievementId == "" then
        return false
    end

    -- Get row if not provided
    if not row then
        row = FindRowByAchId(achievementId)
    end

    -- Determine scope from achievement definition
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
        -- Player can't participate in this scope (e.g., not in guild for guild-first)
        return false
    end

    local db = EnsureDBForScope(scopeKey)
    if not db then
        return false
    end

    -- Check if already claimed
    local existing = LibP2PDB:GetKey(db, TABLE_NAME, achievementId)
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
        LibP2PDB:SetKey(db, TABLE_NAME, achievementId, claim)
        LibP2PDB:BroadcastKey(db, TABLE_NAME, achievementId)
        LibP2PDB:DiscoverPeers(db)
        LibP2PDB:SyncDatabase(db)
        
        -- Save immediately after claiming (don't wait for periodic save)
        if databases[scopeKey] then
            local root = _G.HardcoreAchievementsDB or {}
            root.guildFirst = root.guildFirst or {}
            local dbState = LibP2PDB:ExportDatabase(db)
            if dbState then
                root.guildFirst[scopeKey] = {
                    version = 1,
                    prefix = databases[scopeKey].prefix,
                    state = dbState,
                    savedAt = time(),
                }
            end
        end
    end)

    -- Award the achievement
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
        local row = _G["HCA_GuildFirst_" .. achId .. "_Row"] or FindRowByAchId(achId)
        if M:CanClaimAndAward(achId, row) then
            print("|cff008066[Hardcore Achievements]|r |cff00ff00Claimed and awarded!|r")
        else
            print("|cff008066[Hardcore Achievements]|r |cffff0000Already claimed by someone else.|r")
        end
        return
    end

    if msg == "status" then
        local achId = "GuildFirstTest01"
        local row = _G.HCA_GuildFirst_TestRow or FindRowByAchId(achId)
        local isClaimed, winner = M:IsClaimed(achId, row)
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

-- Initialize databases on login/guild events (lazy initialization per scope)
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
initFrame:SetScript("OnEvent", function()
    -- Pre-initialize common scopes (guild-first and server-first)
    local realm = GetRealmName()
    if realm ~= "" then
        -- Pre-init server-first (always available)
        EnsureDBForScope("Server@" .. realm)
        
        -- Pre-init guild-first if in a guild
        local guildName = GetGuildName()
        if guildName and guildName ~= "" then
            EnsureDBForScope("Guild@" .. guildName .. "@" .. realm)
        end
    end
end)

