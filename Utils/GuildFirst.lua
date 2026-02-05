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

-- Localize frequently-used WoW API globals (micro-optimization, no behavior change)
local _G = _G
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local GetRealmName = GetRealmName
local GetGuildInfo = GetGuildInfo
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local time = time
local table_insert = table.insert
local table_sort = table.sort
local table_concat = table.concat
local string_byte = string.byte
local string_format = string.format
local string_gmatch = string.gmatch

-- ---------------------------------------------------------------------------------------------------------------------
-- Guild-first toast (own frame above main achievement toast so both are visible)
-- ---------------------------------------------------------------------------------------------------------------------

local guildFirstToastFrame = nil

-- Single OnUpdate for fade; state on frame (fadeT, fadeDuration) avoids allocating a new function per toast
local function GuildFirstToastFadeOnUpdate(s, elapsed)
    local t = (s.fadeT or 0) + elapsed
    s.fadeT = t
    local duration = s.fadeDuration or 1
    local a = 1 - math.min(t / duration, 1)
    s:SetAlpha(a)
    if t >= duration then
        s:SetScript("OnUpdate", nil)
        s.fadeT = nil
        s.fadeDuration = nil
        s:Hide()
        s:SetAlpha(1)
    end
end

local function CreateGuildFirstToast()
    if guildFirstToastFrame and guildFirstToastFrame:IsObjectType("Frame") then
        return guildFirstToastFrame
    end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(320, 92)
    f:SetPoint("CENTER", 0, -180)
    f:Hide()
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(100)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if bg.SetAtlas and bg:SetAtlas("UI-Achievement-Alert-Background", true) then
        bg:SetTexCoord(0, 1, 0, 1)
    else
        bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Alert-Background")
        bg:SetTexCoord(0, 0.605, 0, 0.703)
    end

    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame:SetSize(40, 40)
    iconFrame:SetPoint("LEFT", f, "LEFT", 6, 0)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    icon:SetSize(40, 43)
    icon:SetTexCoord(0.05, 1, 0.05, 1)
    f.icon = icon

    local overlay = iconFrame:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    overlay:SetTexCoord(0, 0.5625, 0, 0.5625)
    overlay:SetSize(72, 72)
    overlay:SetPoint("CENTER", iconFrame, "CENTER", -1, 2)

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("CENTER", f, "CENTER", 10, 0)
    name:SetJustifyH("CENTER")
    name:SetText("")
    f.name = name

    local unlocked = f:CreateFontString(nil, "OVERLAY", "GameFontBlackTiny")
    unlocked:SetPoint("TOP", f, "TOP", 7, -26)
    unlocked:SetText(ACHIEVEMENT_UNLOCKED or "Achievement Unlocked")

    local shield = CreateFrame("Frame", nil, f)
    shield:SetSize(64, 64)
    shield:SetPoint("RIGHT", f, "RIGHT", -10, -4)
    local shieldIcon = shield:CreateTexture(nil, "BACKGROUND")
    shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
    shieldIcon:SetSize(56, 52)
    shieldIcon:SetPoint("TOPRIGHT", 1, 0)
    shieldIcon:SetTexCoord(0, 0.5, 0, 0.45)
    f.shieldIcon = shieldIcon
    local points = shield:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    points:SetPoint("CENTER", 4, 5)
    points:SetText("")
    f.points = points

    function f:PlayFade(duration)
        self.fadeT = 0
        self.fadeDuration = duration
        self:SetScript("OnUpdate", GuildFirstToastFadeOnUpdate)
    end

    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and (_G.ShowHardcoreAchievementWindow or _G.HCA_ShowAchievementTab) then
            if _G.ShowHardcoreAchievementWindow then _G.ShowHardcoreAchievementWindow()
            else _G.HCA_ShowAchievementTab() end
        end
    end)

    guildFirstToastFrame = f
    return f
end

local function ShowGuildFirstToast(iconTex, title, pts)
    -- Defer to next frame so we're not hidden by the same event that triggered the claim
    C_Timer.After(0.05, function()
        local f = CreateGuildFirstToast()
        f:Hide()
        f:SetAlpha(1)
        local tex = iconTex
        if type(iconTex) == "table" and iconTex.GetTexture then
            tex = iconTex:GetTexture()
        end
        if not tex then tex = 136116 end
        f.icon:SetTexture(tex)
        f.name:SetText(title or "")
        local finalPoints = pts or 0
        if finalPoints == 0 then
            f.points:SetText("")
            f.points:Hide()
            if f.shieldIcon then
                f.shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields-Nopoints")
                f.shieldIcon:SetTexCoord(0, 0.5, 0, 0.45)
            end
        else
            f.points:SetText(tostring(finalPoints))
            f.points:Show()
            if f.shieldIcon then
                f.shieldIcon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
                f.shieldIcon:SetTexCoord(0, 0.5, 0, 0.45)
            end
        end
        f:Show()
        PlaySoundFile("Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg", "Effects")
        C_Timer.After(3, function()
            if f:IsShown() then f:PlayFade(0.6) end
        end)
    end)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------------------------------------------------

local function GetGuildName()
    C_GuildInfo.GuildRoster()
    return GetGuildInfo and GetGuildInfo("player") or nil
end

local function Debug(msg)
    if type(_G.HCA_DebugPrint) == "function" then
        _G.HCA_DebugPrint("[GuildFirst] " .. tostring(msg))
    end
end

local function Hash32(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string_byte(s, i)) % 4294967296
    end
    return h
end

local function PrefixForKey(key)
    return "HCA" .. string_format("%08X", Hash32(key))
end

--- Determine the scope key for an achievement based on its definition.
--- @param scope string|table|nil Scope from achievement definition
--- @return string? scopeKey Returns nil if scope is invalid or player can't participate
local function GetScopeKey(scope)
    local realm = GetRealmName()
    if realm == "" then
        Debug("GetScopeKey: No realm name available")
        return nil
    end

    -- Default to guild-first if not specified
    if scope == nil or scope == "guild" then
        local guildName = GetGuildName()
        if not guildName or guildName == "" then
            Debug("GetScopeKey: Guild-first scope but player not in a guild")
            return nil  -- Not in a guild, can't participate in guild-first
        end
        local key = "Guild@" .. tostring(guildName) .. "@" .. tostring(realm)
        Debug("GetScopeKey: Guild-first scope -> " .. key)
        return key
    end

    -- Server-wide
    if scope == "server" then
        local key = "Server@" .. tostring(realm)
        Debug("GetScopeKey: Server-first scope -> " .. key)
        return key
    end

    -- Custom guild list: {"GuildA", "GuildB"}
    if type(scope) == "table" then
        local guildName = GetGuildName()
        if not guildName or guildName == "" then
            Debug("GetScopeKey: Custom guild pool but player not in a guild")
            return nil  -- Not in a guild, can't participate
        end
        
        -- Check if player's guild is in the list
        local playerGuildLower = string.lower(tostring(guildName))
        for _, allowedGuild in ipairs(scope) do
            if string.lower(tostring(allowedGuild)) == playerGuildLower then
                -- Player is in an allowed guild - create deterministic key from sorted guild list
                local sortedGuilds = {}
                for _, g in ipairs(scope) do
                    table_insert(sortedGuilds, tostring(g))
                end
                table_sort(sortedGuilds)
                local guildListStr = table_concat(sortedGuilds, ",")
                local key = "Guilds@" .. guildListStr .. "@" .. tostring(realm)
                Debug("GetScopeKey: Custom guild pool [" .. guildListStr .. "] -> " .. key .. " (player in allowed guild)")
                return key
            end
        end
        
        -- Player's guild is not in the allowed list
        Debug("GetScopeKey: Player's guild '" .. tostring(guildName) .. "' not in custom pool")
        return nil
    end

    Debug("GetScopeKey: Invalid scope type: " .. type(scope))
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
-- GuildFirst config registry (published by Achievements/GuildFirstCatalog.lua)
-- ---------------------------------------------------------------------------------------------------------------------

local function GetGuildFirstDef(achId, row)
    if row and row._def and row._def.isGuildFirst then
        return row._def
    end
    if _G.HCA_GuildFirst_DefById then
        return _G.HCA_GuildFirst_DefById[tostring(achId)]
    end
    return nil
end

local function DefaultRequireSameGuild(def)
    if def and def.requireSameGuild ~= nil then
        return def.requireSameGuild == true
    end
    -- Default: if claim scope is guild-scoped (default), require same guild for group awards.
    local scope = def and def.achievementScope
    return scope == nil or scope == "guild"
end

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ParseDelimitedSet(s, delim)
    local set = {}
    s = Trim(s)
    if s == "" then
        return set
    end
    delim = delim or ";"
    for token in string_gmatch(s, "([^" .. delim .. "]+)") do
        token = Trim(token)
        if token ~= "" then
            set[token] = true
        end
    end
    return set
end

local function RecordIncludesGUID(rec, guid)
    guid = tostring(guid or "")
    if guid == "" or not rec then
        return false
    end
    -- Multi-winner claim (raid/party): encode the GUID list into winnerGUID as a ';' delimited string.
    -- (This avoids LibP2PDB schema migration issues for existing installs.)
    local s = tostring(rec.winnerGUID or "")
    if s:find(";", 1, true) then
        local set = ParseDelimitedSet(s, ";")
        return set[guid] == true
    end
    -- Single-winner claim:
    return s == guid
end

--- True if the given claim record includes the current player as a winner.
--- @param rec table?
--- @return boolean
function M:IsWinnerRecord(rec)
    local myGUID = UnitGUID("player") or ""
    return RecordIncludesGUID(rec, myGUID)
end

local function BuildWinnersGUIDList(awardMode, requireSameGuild)
    awardMode = tostring(awardMode or "solo"):lower()
    requireSameGuild = requireSameGuild == true

    local myGuild = requireSameGuild and GetGuildName() or nil
    local winnersGUID = {}
    local seen = {}

    local function AddUnit(unit)
        if not UnitExists(unit) then return end
        local guid = UnitGUID(unit)
        if not guid or guid == "" or seen[guid] then return end

        if myGuild and myGuild ~= "" then
            local gName = GetGuildInfo and GetGuildInfo(unit) or nil
            if gName ~= myGuild then
                return
            end
        end

        seen[guid] = true
        table_insert(winnersGUID, guid)
    end

    if awardMode == "solo" then
        AddUnit("player")
    elseif awardMode == "party" then
        AddUnit("player")
        for i = 1, 4 do AddUnit("party" .. i) end
    elseif awardMode == "raid" then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do AddUnit("raid" .. i) end
        -- Fallback if API returns 0 unexpectedly
        AddUnit("player")
    else
        -- "group" (default): raid if in raid, else party if in group, else solo
        if IsInRaid and IsInRaid() then
            local n = GetNumGroupMembers and GetNumGroupMembers() or 0
            for i = 1, n do AddUnit("raid" .. i) end
            AddUnit("player")
        elseif IsInGroup and IsInGroup() then
            AddUnit("player")
            for i = 1, 4 do AddUnit("party" .. i) end
        else
            AddUnit("player")
        end
    end

    return table_concat(winnersGUID, ";")
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
        Debug("Initializing database for scope: " .. tostring(scopeKey) .. " (prefix: " .. tostring(prefix) .. ")")
        db = LibP2PDB:NewDatabase({
            prefix = prefix,
            version = 1,
            onDiscoveryComplete = function()
                Debug("Peer discovery complete for scope: " .. tostring(scopeKey) .. " - starting sync")
                if databases[scopeKey] and databases[scopeKey].db then
                    LibP2PDB:SyncDatabase(databases[scopeKey].db)
                end
            end,
        })
    else
        Debug("Using existing database for scope: " .. tostring(scopeKey))
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
            onChange = function(key, data)
                -- When a claim changes, refresh the achievement filter to hide/show rows
                local myGUID = UnitGUID("player") or ""
                if data and data.winnerGUID then
                    if RecordIncludesGUID(data, myGUID) then
                        Debug("Received claim update: Achievement '" .. tostring(key) .. "' claimed and I am an eligible winner")
                        -- Mark row completed when we receive the claim (e.g. from sync or broadcast).
                        -- Do NOT show toast here: onChange also fires on load/relog when we ImportDatabase,
                        -- so we only show the toast in CanClaimAndAward when we actually just claimed.
                        local row = _G["HCA_GuildFirst_" .. tostring(key) .. "_Row"] or FindRowByAchId(tostring(key))
                        if row and not row.completed and type(_G.HCA_MarkRowCompleted) == "function" then
                            _G.HCA_MarkRowCompleted(row)
                        end
                    else
                        Debug("Received claim update: Achievement '" .. tostring(key) .. "' claimed by " .. tostring(data.winnerName or "?") .. " - not eligible (silent fail)")
                    end
                else
                    Debug("Received claim update: Achievement '" .. tostring(key) .. "' claim removed")
                end
                
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
        Debug("Loading persisted state for scope: " .. tostring(scopeKey))
        pcall(function()
            LibP2PDB:ImportDatabase(db, root.guildFirst[scopeKey].state)
            Debug("Persisted state loaded for scope: " .. tostring(scopeKey))
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
    Debug("Starting peer discovery for scope: " .. tostring(scopeKey))
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
        local scope = row._def.achievementScope
        if type(scope) == "table" then
            Debug("GetAchievementScope(" .. tostring(achievementId) .. "): Custom guild pool: " .. table_concat(scope, ", "))
        else
            Debug("GetAchievementScope(" .. tostring(achievementId) .. "): Scope from def: " .. tostring(scope))
        end
        return scope
    end
    
    -- Try to find row by ID if not provided
    if not row and achievementId then
        row = FindRowByAchId(achievementId)
        if row and row._def and row._def.achievementScope ~= nil then
            local scope = row._def.achievementScope
            if type(scope) == "table" then
                Debug("GetAchievementScope(" .. tostring(achievementId) .. "): Custom guild pool (from lookup): " .. table_concat(scope, ", "))
            else
                Debug("GetAchievementScope(" .. tostring(achievementId) .. "): Scope from def (from lookup): " .. tostring(scope))
            end
            return scope
        end
    end
    
    -- Default to guild-first
    Debug("GetAchievementScope(" .. tostring(achievementId) .. "): Using default scope: guild")
    return "guild"
end

--- Check if an achievement is already claimed by someone else.
--- @param achievementId string
--- @param row table? Optional achievement row (to determine scope)
--- @return boolean isClaimed, table? winnerRecord
function M:IsClaimed(achievementId, row)
    achievementId = tostring(achievementId)
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
        Debug("IsClaimed(" .. achievementId .. "): No valid scope key (player can't participate)")
        return false, nil
    end

    local db = EnsureDBForScope(scopeKey)
    if not db then
        Debug("IsClaimed(" .. achievementId .. "): Failed to initialize database for scope: " .. tostring(scopeKey))
        return false, nil
    end

    local rec = LibP2PDB:GetKey(db, TABLE_NAME, achievementId)
    if rec then
        local myGUID = UnitGUID("player") or ""
        if RecordIncludesGUID(rec, myGUID) then
            Debug("IsClaimed(" .. achievementId .. "): Already claimed and I am an eligible winner (scope: " .. tostring(scopeKey) .. ")")
        else
            Debug("IsClaimed(" .. achievementId .. "): Already claimed by " .. tostring(rec.winnerName or "?") .. " (scope: " .. tostring(scopeKey) .. ")")
        end
        return true, rec
    end
    
    Debug("IsClaimed(" .. achievementId .. "): Not claimed yet (scope: " .. tostring(scopeKey) .. ")")
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
        return RecordIncludesGUID(rec, UnitGUID("player") or "")
    end
    return false
end

--- Attempt to claim and award an achievement.
--- Returns true if awarded, false if already claimed (silent fail).
--- @param achievementId string
--- @param row table? Optional achievement row (will find if not provided, also used to determine scope)
--- @param winnersGUIDs string? Optional ';' delimited GUID list for multi-winner claims (e.g. a raid)
--- @return boolean awarded
function M:CanClaimAndAward(achievementId, row, winnersGUIDs)
    achievementId = tostring(achievementId or "")
    if achievementId == "" then
        Debug("CanClaimAndAward: Empty achievement ID")
        return false
    end

    Debug("CanClaimAndAward(" .. achievementId .. "): Starting claim attempt")

    -- Get row if not provided (check global first; catalog stores row there so we can award/toast even if panel scan misses it)
    if not row then
        row = _G["HCA_GuildFirst_" .. achievementId .. "_Row"] or FindRowByAchId(achievementId)
        if row then
            Debug("CanClaimAndAward(" .. achievementId .. "): Found achievement row")
        else
            Debug("CanClaimAndAward(" .. achievementId .. "): Achievement row not found")
        end
    end

    -- Determine scope from achievement definition
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
        Debug("CanClaimAndAward(" .. achievementId .. "): Player can't participate in this scope (e.g., not in guild for guild-first)")
        return false
    end

    Debug("CanClaimAndAward(" .. achievementId .. "): Scope determined -> " .. tostring(scopeKey))

    local db = EnsureDBForScope(scopeKey)
    if not db then
        Debug("CanClaimAndAward(" .. achievementId .. "): Failed to initialize database")
        return false
    end

    -- Check if already claimed
    local existing = LibP2PDB:GetKey(db, TABLE_NAME, achievementId)
    if existing then
        local myGUID = UnitGUID("player") or ""
        if RecordIncludesGUID(existing, myGUID) then
            Debug("CanClaimAndAward(" .. achievementId .. "): Already claimed and I am a winner - skipping")
        else
            Debug("CanClaimAndAward(" .. achievementId .. "): Already claimed by " .. tostring(existing.winnerName or "?") .. " - silently failing")
        end
        return false
    end

    -- Claim it
    local myName = UnitName("player") or ""
    local myGUID = UnitGUID("player") or ""
    local encodedWinners = (type(winnersGUIDs) == "string" and winnersGUIDs ~= "") and winnersGUIDs or myGUID
    local claim = {
        winnerName = myName,
        winnerGUID = encodedWinners,
        claimedAt = time(),
    }

    Debug("CanClaimAndAward(" .. achievementId .. "): Not claimed yet - claiming as FIRST! (scope: " .. tostring(scopeKey) .. ")")
    
    pcall(function()
        LibP2PDB:SetKey(db, TABLE_NAME, achievementId, claim)
        Debug("CanClaimAndAward(" .. achievementId .. "): Claim written locally, broadcasting to all peers...")
        LibP2PDB:BroadcastKey(db, TABLE_NAME, achievementId)
        Debug("CanClaimAndAward(" .. achievementId .. "): Broadcast sent, discovering peers and syncing...")
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
                Debug("CanClaimAndAward(" .. achievementId .. "): State saved to SavedVariables")
            end
        end
    end)

    -- Award the achievement (row may be a UI frame or the model/data if panel wasn't built yet)
    if RecordIncludesGUID(claim, myGUID) then
        if row and type(_G.HCA_MarkRowCompleted) == "function" and not row.completed then
            Debug("CanClaimAndAward(" .. achievementId .. "): Awarding achievement to player")
            _G.HCA_MarkRowCompleted(row)
        end
        -- Always show guild-first toast when we're a winner (use row or def so we show even when row is nil)
        local def = GetGuildFirstDef(achievementId, row)
        local icon = (row and ((row.Icon and row.Icon.GetTexture and row.Icon:GetTexture()) or row.icon)) or (def and def.icon) or 136116
        local titleText = (row and ((row.Title and row.Title.GetText and row.Title:GetText()) or row.title)) or (def and def.title) or tostring(achievementId)
        local pts = (row and row.points) or (def and def.points) or 0
        ShowGuildFirstToast(icon, titleText, pts)
        Debug("CanClaimAndAward(" .. achievementId .. "): Achievement awarded successfully!")
        return true
    else
        Debug("CanClaimAndAward(" .. achievementId .. "): Claim succeeded but player not in winners list (no award)")
    end

    return false
end

--- Data-driven trigger: claim + award using the catalog definition (or overrides).
--- @param guildFirstAchId string
--- @param opts table? { winnersGUIDs?: string, awardMode?: string, requireSameGuild?: boolean }
function M:Trigger(guildFirstAchId, opts)
    guildFirstAchId = tostring(guildFirstAchId or "")
    if guildFirstAchId == "" then return false end

    opts = opts or {}
    local row = _G["HCA_GuildFirst_" .. guildFirstAchId .. "_Row"] or FindRowByAchId(guildFirstAchId)
    local def = GetGuildFirstDef(guildFirstAchId, row)

    local awardMode = opts.awardMode or (def and def.awardMode) or "solo"
    local requireSameGuild = opts.requireSameGuild
    if requireSameGuild == nil then
        requireSameGuild = DefaultRequireSameGuild(def)
    end

    local winnersGUIDs = opts.winnersGUIDs
    if type(winnersGUIDs) ~= "string" or winnersGUIDs == "" then
        winnersGUIDs = BuildWinnersGUIDList(awardMode, requireSameGuild)
    end

    return self:CanClaimAndAward(guildFirstAchId, row, winnersGUIDs, nil)
end

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

-- ---------------------------------------------------------------------------------------------------------------------
-- Generic trigger wiring: when a standard achievement completes, trigger any configured GuildFirst entries.
-- ---------------------------------------------------------------------------------------------------------------------

local function OnAchievementCompleted(achievementData)
    if not achievementData then return end
    local triggerId = tostring(achievementData.achievementId or "")
    if triggerId == "" then return end

    local idx = _G.HCA_GuildFirst_ByTrigger
    if not idx then return end

    local list = idx[triggerId]
    if type(list) ~= "table" then return end

    for _, gfAchId in ipairs(list) do
        local row = _G["HCA_GuildFirst_" .. tostring(gfAchId) .. "_Row"] or FindRowByAchId(tostring(gfAchId))
        local def = GetGuildFirstDef(gfAchId, row)
        local awardMode = (def and def.awardMode) or "solo"
        local requireSameGuild = DefaultRequireSameGuild(def)
        local winnersGUIDs = BuildWinnersGUIDList(awardMode, requireSameGuild)
        M:CanClaimAndAward(tostring(gfAchId), row, winnersGUIDs)
    end
end

if _G.HardcoreAchievements_Hooks and _G.HardcoreAchievements_Hooks.HookScript then
    _G.HardcoreAchievements_Hooks:HookScript("OnAchievement", OnAchievementCompleted)
end

