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
-- - BroadcastPresence: Periodically announces presence (every 60s) so peers can see us; then SyncDatabase
-- - SyncDatabase: Gossip-style sync with neighbors via WHISPER (exchanges digests, requests missing data)
-- - Persistence: Saves state to SavedVariables on claim and on PLAYER_LOGOUT, loads on login

local LibStub = LibStub
if not LibStub then return end

local LibP2PDB = LibStub("LibP2PDB", true)
if not LibP2PDB then return end

local TABLE_NAME = "Claims"
-- One P2P database per scope so guild-first claims are isolated (e.g. Guild A vs Guild B, or server-first).
-- We create each DB and its table once at first use and store the handle here so we never call GetDatabase
-- again for that scope; all later use reuses this handle.
local databases = {}  -- [scopeKey] = { db = DBHandle, prefix = string, presenceTicker = ticker, ... }

-- Cached local peer ID (smaller than full GUID for sync). Get with LibP2PDB:GetLocalPeerID() at first use.
-- Debug: format("%X", peerId) for hex; convert back to GUID with "Player-"..peerId or LibP2PDB:PeerIDToPlayerGUID if available.
local localPeerId = nil

local function GetLocalPeerId()
    if localPeerId == nil then
        localPeerId = LibP2PDB:GetLocalPeerID()
    end
    return localPeerId
end

local addonName, addon = ...
local MarkRowCompleted = addon and addon.MarkRowCompleted
local ApplyFilter = addon and addon.ApplyFilter
local ShowAchievementWindow = addon and (addon.ShowAchievementWindow or addon.ShowAchievementTab)
local PlayAchievementSound = addon and addon.PlayAchievementSound

local M = {}

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
        if button == "LeftButton" and ShowAchievementWindow then
            ShowAchievementWindow()
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
        if type(PlayAchievementSound) == "function" then
            PlayAchievementSound()
        else
            PlaySoundFile("Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg", "Effects")
        end
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
    if addon and type(addon.DebugPrint) == "function" then
        addon.DebugPrint("[GuildFirst] " .. tostring(msg))
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
                    table_insert(sortedGuilds, tostring(g))
                end
                table_sort(sortedGuilds)
                local guildListStr = table_concat(sortedGuilds, ",")
                return "Guilds@" .. guildListStr .. "@" .. tostring(realm)
            end
        end
        
        -- Player's guild is not in the allowed list
        return nil
    end

    return nil  -- Invalid scope
end

local function FindRowByAchId(achId)
    if not (addon and addon.AchievementPanel and addon.AchievementPanel.achievements) then
        return nil
    end
    for _, row in ipairs(addon.AchievementPanel.achievements) do
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
    local defById = addon and addon.GuildFirst_DefById
    if defById then
        return defById[tostring(achId)]
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

--- Check if the claim record includes the given peer ID (or legacy GUID for backward compat).
local function RecordIncludesPeerID(rec, peerId)
    peerId = tostring(peerId or "")
    if peerId == "" or not rec then
        return false
    end
    -- Prefer winnerPeerID (smaller, from LibP2PDB peer ID)
    local s = tostring(rec.winnerPeerID or rec.winnerGUID or "")
    if s == "" then return false end
    if s:find(";", 1, true) then
        local set = ParseDelimitedSet(s, ";")
        return set[peerId] == true
    end
    return s == peerId
end

--- True if the given claim record includes the current player as a winner.
--- @param rec table?
--- @return boolean
local function IsWinnerRecord(self, rec)
    local myPeerId = GetLocalPeerId()
    return RecordIncludesPeerID(rec, myPeerId)
end

--- Build ';'-delimited list of winner peer IDs (smaller than GUIDs for sync).
local function BuildWinnersPeerIDList(awardMode, requireSameGuild)
    awardMode = tostring(awardMode or "solo"):lower()
    requireSameGuild = requireSameGuild == true

    local myGuild = requireSameGuild and GetGuildName() or nil
    local winnersPeerID = {}
    local seen = {}

    local function AddUnit(unit)
        if not UnitExists(unit) then return end
        local guid = UnitGUID(unit)
        if not guid or guid == "" then return end
        local peerId = nil
        if type(LibP2PDB.PlayerGUIDToPeerID) == "function" then
            -- Current LibP2PDB export: convert "Player-XXXX-XXXXXXXX" GUID to compact peer ID.
            local ok, converted = pcall(function()
                return LibP2PDB:PlayerGUIDToPeerID(guid)
            end)
            if ok then
                peerId = converted
            end
        end
        if not peerId and unit == "player" then
            -- Always include self for solo awards even if GUID conversion API is unavailable.
            peerId = GetLocalPeerId()
        end
        if not peerId or seen[peerId] then return end

        if myGuild and myGuild ~= "" then
            local gName = GetGuildInfo and GetGuildInfo(unit) or nil
            if gName ~= myGuild then
                return
            end
        end

        seen[peerId] = true
        table_insert(winnersPeerID, peerId)
    end

    if awardMode == "solo" then
        AddUnit("player")
    elseif awardMode == "party" then
        AddUnit("player")
        for i = 1, 4 do AddUnit("party" .. i) end
    elseif awardMode == "raid" then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do AddUnit("raid" .. i) end
        AddUnit("player")
    else
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

    return table_concat(winnersPeerID, ";")
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

    -- Get or create database once per scope; we store the handle in databases[scopeKey] so we never call
    -- GetDatabase again for this scope (all callers reuse the stored handle).
    local db = LibP2PDB:GetDatabase(prefix)
    local created = false
    if not db then
        Debug("Initializing database for scope: " .. tostring(scopeKey) .. " (prefix: " .. tostring(prefix) .. ")")
        db = LibP2PDB:NewDatabase({
            prefix = prefix,
            version = 1,
        })
        created = true
    end

    -- Create the claims table exactly once for this database (only when we just created the db).
    if created then
        LibP2PDB:NewTable(db, {
        name = TABLE_NAME,
        keyType = "string",
        schema = {
            winnerName = "string",
            winnerPeerID = "string",  -- peer ID (smaller than full GUID); legacy winnerGUID still read in RecordIncludesPeerID
            claimedAt = "number",
        },
        onChange = function(key, data)
                -- When a claim changes, refresh the achievement filter to hide/show rows
                local myPeerId = GetLocalPeerId()
                if data and (data.winnerPeerID or data.winnerGUID) then
                    if RecordIncludesPeerID(data, myPeerId) then
                        Debug("Received claim update: Achievement '" .. tostring(key) .. "' claimed and I am an eligible winner")
                        -- Skip re-awarding if admin manually deleted this achievement from the player (tombstone)
                        local _, cdb
                        if addon and addon.GetCharDB then
                            _, cdb = addon.GetCharDB()
                        end
                        if cdb and cdb.deletedByAdmin and cdb.deletedByAdmin[tostring(key)] then
                            Debug("Skipping GuildFirst re-award: achievement was deleted by admin")
                        else
                            -- Mark row completed when we receive the claim (e.g. from sync or broadcast).
                            -- Do NOT show toast here: onChange also fires on load/relog when we ImportDatabase,
                            -- so we only show the toast in CanClaimAndAward when we actually just claimed.
                            -- Ensure row frames exist (they may not be built yet if player hasn't opened achievement tab)
                            if addon and addon.EnsureAchievementRowsBuilt then
                                addon.EnsureAchievementRowsBuilt()
                            end
                            -- Prefer FindRowByAchId (panel frames) over addon row (may be model only)
                            local row = FindRowByAchId(tostring(key))
                            if not row and addon and addon.GetAchievementRow then
                                row = addon.GetAchievementRow(tostring(key))
                            end
                            if not row then
                                row = addon and addon["GuildFirst_" .. tostring(key) .. "_Row"]
                            end
                            -- Use frame if row has UI elements (Title FontString, Points)
                            local frame = (row and row.Title and row.Points and row) or (row and row.frame)
                            if frame and not frame.completed and type(MarkRowCompleted) == "function" then
                                MarkRowCompleted(frame)
                                local def = GetGuildFirstDef(tostring(key), row)
                                local icon = (frame.Icon and frame.Icon.GetTexture and frame.Icon:GetTexture()) or (def and def.icon) or 136116
                                local titleText = (frame.Title and frame.Title.GetText and frame.Title:GetText()) or (def and def.title) or tostring(key)
                                local pts = frame.points or (def and def.points) or 0
                                ShowGuildFirstToast(icon, titleText, pts)
                            elseif not frame and addon and addon.GetCharDB then
                                -- No frame yet (model not built) - persist to DB so RestoreCompletionsFromDB applies when panel opens
                                local _, cdb = addon.GetCharDB()
                                if cdb then
                                    local achId = tostring(key)
                                    local def = GetGuildFirstDef(achId, nil)
                                    local pts = (def and def.points) or 0
                                    cdb.achievements = cdb.achievements or {}
                                    cdb.achievements[achId] = cdb.achievements[achId] or {}
                                    local rec = cdb.achievements[achId]
                                    rec.completed = true
                                    rec.completedAt = rec.completedAt or time()
                                    rec.points = rec.points or pts
                                    rec.level = rec.level or (UnitLevel("player") or nil)
                                    Debug("Persisted GuildFirst completion for " .. achId .. " (frame not yet built)")
                                    if addon.UpdateTotalPoints then addon.UpdateTotalPoints() end
                                    if addon.RestoreCompletionsFromDB then addon.RestoreCompletionsFromDB() end
                                end
                            end
                        end
                    else
                        Debug("Received claim update: Achievement '" .. tostring(key) .. "' claimed by " .. tostring(data.winnerName or "?") .. " - not eligible (silent fail)")
                    end
                else
                    Debug("Received claim update: Achievement '" .. tostring(key) .. "' claim removed")
                end
                
                if type(ApplyFilter) == "function" then
                    C_Timer.After(0.1, function()
                        ApplyFilter()
                    end)
                end
            end,
        })
    end

    -- Load persisted state
    local root = addon and addon.HardcoreAchievementsDB
    if root and root.guildFirst and root.guildFirst[scopeKey] and root.guildFirst[scopeKey].state then
        pcall(function()
            LibP2PDB:ImportDatabase(db, root.guildFirst[scopeKey].state)
        end)
    end

    -- Periodic presence broadcast and sync (only create one ticker per scope).
    -- Interval 60s so sync has time to complete before the next run.
    if not databases[scopeKey] or not databases[scopeKey].presenceTicker then
        local ticker = C_Timer.NewTicker(60.0, function()
            if databases[scopeKey] and databases[scopeKey].db then
                LibP2PDB:BroadcastPresence(databases[scopeKey].db)
                LibP2PDB:SyncDatabase(databases[scopeKey].db)
            end
        end)
        databases[scopeKey] = {
            db = db,
            prefix = prefix,
            scopeKey = scopeKey,
            presenceTicker = ticker,
        }
    end

    -- Initial presence broadcast only (no peers yet, so SyncDatabase would be a no-op).
    Debug("Broadcasting presence for scope: " .. tostring(scopeKey))
    LibP2PDB:BroadcastPresence(db)

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
local function IsClaimed(self, achievementId, row)
    achievementId = tostring(achievementId)
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
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
        if RecordIncludesPeerID(rec, GetLocalPeerId()) then
            Debug("IsClaimed(" .. achievementId .. "): Already claimed and I am an eligible winner (scope: " .. tostring(scopeKey) .. ")")
        else
            Debug("IsClaimed(" .. achievementId .. "): Already claimed by " .. tostring(rec.winnerName or "?") .. " (scope: " .. tostring(scopeKey) .. ")")
        end
        return true, rec
    end
    
    return false, nil
end

--- Check if an achievement is claimed by the current player.
--- @param achievementId string
--- @param row table? Optional achievement row (to determine scope)
--- @return boolean isClaimedByMe
local function IsClaimedByMe(self, achievementId, row)
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
        return RecordIncludesPeerID(rec, GetLocalPeerId())
    end
    return false
end

--- Attempt to claim and award an achievement.
--- Returns true if awarded, false if already claimed (silent fail).
--- @param achievementId string
--- @param row table? Optional achievement row (will find if not provided, also used to determine scope)
--- @param winnersPeerIDs string? Optional ';' delimited peer ID list for multi-winner claims (from BuildWinnersPeerIDList)
--- @return boolean awarded
local function CanClaimAndAward(self, achievementId, row, winnersPeerIDs)
    achievementId = tostring(achievementId or "")
    if achievementId == "" then
        return false
    end

    -- Get row if not provided (catalog stores row on addon or legacy global)
    if not row then
        row = (addon and addon["GuildFirst_" .. achievementId .. "_Row"]) or FindRowByAchId(achievementId)
    end

    -- Determine scope from achievement definition
    local scope = GetAchievementScope(row, achievementId)
    local scopeKey = GetScopeKey(scope)
    if not scopeKey then
        return false
    end

    local db = EnsureDBForScope(scopeKey)
    if not db then
        Debug("CanClaimAndAward(" .. achievementId .. "): Failed to initialize database")
        return false
    end

    -- Check if already claimed
    local existing = LibP2PDB:GetKey(db, TABLE_NAME, achievementId)
    if existing then
        if RecordIncludesPeerID(existing, GetLocalPeerId()) then
            Debug("CanClaimAndAward(" .. achievementId .. "): Already claimed and I am a winner - skipping")
        else
            Debug("CanClaimAndAward(" .. achievementId .. "): Already claimed by " .. tostring(existing.winnerName or "?") .. " - silently failing")
        end
        return false
    end

    -- Claim it (use peer IDs for smaller sync payload)
    local myName = UnitName("player") or ""
    local myPeerId = GetLocalPeerId()
    local encodedWinners = (type(winnersPeerIDs) == "string" and winnersPeerIDs ~= "") and winnersPeerIDs or myPeerId
    local claim = {
        winnerName = myName,
        winnerPeerID = encodedWinners,
        claimedAt = time(),
    }

    Debug("CanClaimAndAward(" .. achievementId .. "): Not claimed yet - claiming as FIRST! (scope: " .. tostring(scopeKey) .. ")")
    
    pcall(function()
        LibP2PDB:SetKey(db, TABLE_NAME, achievementId, claim)
        Debug("CanClaimAndAward(" .. achievementId .. "): Claim written locally, broadcasting to all peers...")
        LibP2PDB:BroadcastKey(db, TABLE_NAME, achievementId)
        -- BroadcastKey already pushed this key to reachable peers; no need for BroadcastPresence/SyncDatabase here.

        -- Save to SavedVariables so state is current when WoW persists on logout/exit
        if databases[scopeKey] then
            local root = (addon and addon.HardcoreAchievementsDB) or {}
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
    if RecordIncludesPeerID(claim, GetLocalPeerId()) then
        if row and type(MarkRowCompleted) == "function" and not row.completed then
            Debug("CanClaimAndAward(" .. achievementId .. "): Awarding achievement to player")
            MarkRowCompleted(row)
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
--- @param opts table? { winnersPeerIDs?: string, awardMode?: string, requireSameGuild?: boolean }
local function Trigger(self, guildFirstAchId, opts)
    guildFirstAchId = tostring(guildFirstAchId or "")
    if guildFirstAchId == "" then return false end

    opts = opts or {}
    local row = (addon and addon["GuildFirst_" .. guildFirstAchId .. "_Row"]) or FindRowByAchId(guildFirstAchId)
    local def = GetGuildFirstDef(guildFirstAchId, row)

    local awardMode = opts.awardMode or (def and def.awardMode) or "solo"
    local requireSameGuild = opts.requireSameGuild
    if requireSameGuild == nil then
        requireSameGuild = DefaultRequireSameGuild(def)
    end

    local winnersPeerIDs = opts.winnersPeerIDs
    if type(winnersPeerIDs) ~= "string" or winnersPeerIDs == "" then
        winnersPeerIDs = BuildWinnersPeerIDList(awardMode, requireSameGuild)
    end

    return self:CanClaimAndAward(guildFirstAchId, row, winnersPeerIDs)
end

-- Initialize databases on login/guild events (lazy initialization per scope)
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
initFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
initFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        -- Export all guild-first DBs so SavedVariables persist current state on logout/exit
        local root = (addon and addon.HardcoreAchievementsDB) or {}
        root.guildFirst = root.guildFirst or {}
        for scopeKey, info in pairs(databases) do
            if info.db then
                local dbState = LibP2PDB:ExportDatabase(info.db)
                if dbState then
                    root.guildFirst[scopeKey] = {
                        version = 1,
                        prefix = info.prefix,
                        state = dbState,
                        savedAt = time(),
                    }
                end
            end
        end
        return
    end
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

    local idx = addon and addon.GuildFirst_ByTrigger
    if not idx then return end

    local list = idx[triggerId]
    if type(list) ~= "table" then return end

    for _, gfAchId in ipairs(list) do
        local id = tostring(gfAchId)
        local row = (addon and addon["GuildFirst_" .. id .. "_Row"]) or FindRowByAchId(id)
        local def = GetGuildFirstDef(gfAchId, row)
        local awardMode = (def and def.awardMode) or "solo"
        local requireSameGuild = DefaultRequireSameGuild(def)
        local winnersPeerIDs = BuildWinnersPeerIDList(awardMode, requireSameGuild)
        M:CanClaimAndAward(id, row, winnersPeerIDs)
    end
end

-- Admin helpers: exposed for AdminPanel only. AdminPanel implements Override/Clear; LibP2PDB propagates to players.
--- @return string? scopeKey
function M.GetScopeKeyForAchievement(self, achievementId)
    local row = FindRowByAchId(achievementId)
    local scope = GetAchievementScope(row, achievementId)
    return GetScopeKey(scope)
end

--- @return table? db, string? prefix
function M.GetDBInfoForScope(self, scopeKey)
    local db = EnsureDBForScope(scopeKey)
    if not db or not databases[scopeKey] then return nil, nil end
    return db, databases[scopeKey].prefix
end

M.CLAIMS_TABLE_NAME = TABLE_NAME

-- Assign local functions to module (no globals)
M.IsWinnerRecord = IsWinnerRecord
M.IsClaimed = IsClaimed
M.IsClaimedByMe = IsClaimedByMe
M.CanClaimAndAward = CanClaimAndAward
M.Trigger = Trigger

if addon then
    addon.GuildFirst = M
end

local function RegisterAchievementHook()
    local Hooks = addon and addon.Hooks
    if Hooks and Hooks.HookScript and not M._achievementHookRegistered then
        Hooks:HookScript("OnAchievement", OnAchievementCompleted)
        M._achievementHookRegistered = true
    end
end

-- Try immediately (works if HookSystem is already initialized).
RegisterAchievementHook()

-- Load-order safe fallback: GuildFirst.lua loads before HardcoreAchievements.lua in .toc,
-- so addon.Hooks may not exist yet at file load time.
local hookInitFrame = CreateFrame("Frame")
hookInitFrame:RegisterEvent("PLAYER_LOGIN")
hookInitFrame:SetScript("OnEvent", function()
    RegisterAchievementHook()
    hookInitFrame:UnregisterAllEvents()
end)

