local addonName, addon = ...
if not addon then return end

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

local Sync = Leaderboard.Sync or {}
Leaderboard.Sync = Sync

local C_Timer = C_Timer
local C_AddOns = C_AddOns
local GetGuildInfo = GetGuildInfo
local GetRealmName = GetRealmName
local GetServerTime = GetServerTime
local LibStub = LibStub
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitLevel = UnitLevel
local UnitName = UnitName
local time = time

local DB_PREFIX = "HCA_LB"
local DB_VERSION = 1
local TABLE_NAME = "players"

local LibP2PDB = LibStub and LibStub("LibP2PDB", true)

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

--- Same resolution as Functions/AchievementEventLog.lua (C_AddOns first; global fallback).
local function GetAddOnVersionString()
    local ver
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif GetAddOnMetadata then
        ver = GetAddOnMetadata(addonName, "Version")
    end
    if not ver or ver == "" then
        ver = "?"
    end
    return ver
end

Leaderboard.GetAddOnVersionString = GetAddOnVersionString

local function GetCharacterKey()
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    if not name or name == "" then
        return nil
    end
    return (realm and realm ~= "" and (name .. "-" .. realm)) or name
end

local function ShallowEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for key, value in pairs(a) do
        if b[key] ~= value then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local function StoreRow(key, row)
    local db = Leaderboard:GetDB()
    db.rows = db.rows or {}
    if row then
        db.rows[key] = row
    else
        db.rows[key] = nil
    end
    db.updatedAt = Now()
    if Leaderboard.Refresh then
        Leaderboard:Refresh()
    end
end

local function PlayerIsDead()
    if UnitIsDeadOrGhost then
        return UnitIsDeadOrGhost("player") and true or false
    end
    return ((UnitIsDead and UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player"))) and true or false
end

local function PersistState()
    if not LibP2PDB or not Sync.db then
        return
    end
    local db = Leaderboard:GetDB()
    local ok, state = pcall(function()
        return LibP2PDB:ExportDatabase(Sync.db)
    end)
    if ok and state then
        db.state = state
        db.stateVersion = DB_VERSION
        db.savedAt = Now()
    end
end

local function OnTableChanged(key, newData)
    StoreRow(key, newData)
    PersistState()
end

function Sync:GetDatabase()
    return self.db
end

function Sync:GetTableName()
    return TABLE_NAME
end

function Sync:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    if not LibP2PDB then
        return
    end

    local db = LibP2PDB:GetDatabase(DB_PREFIX)
    local created = false
    if not db then
        db = LibP2PDB:NewDatabase({
            prefix = DB_PREFIX,
            version = DB_VERSION,
        })
        created = true
    end
    self.db = db

    if created then
        LibP2PDB:NewTable(db, {
            name = TABLE_NAME,
            keyType = "string",
            exclusive = true,
            rowsPerChunk = 96,
            schema = {
                name = "string",
                realm = "string",
                guild = "string",
                faction = "string",
                class = "string",
                level = "number",
                completed = "number",
                total = "number",
                points = "number",
                label = "string",
                selfFound = { "boolean", "nil" },
                dead = "boolean",
                version = "string",
                updatedAt = "number",
            },
            onChange = OnTableChanged,
        })
    end

    pcall(function()
        LibP2PDB:RegisterTableChange(db, TABLE_NAME, self, OnTableChanged)
    end)

    local saved = Leaderboard:GetDB().state
    if saved then
        pcall(function()
            LibP2PDB:ImportDatabase(db, saved)
        end)
    end

    self:PublishLocal("init")
    C_Timer.After(5, function()
        if Sync.SyncPeers then
            Sync:SyncPeers()
        end
    end)
end

function Sync:BuildLocalRow()
    local name = UnitName("player")
    if not name or name == "" then
        return nil
    end

    local completed, total = 0, 0
    if addon.AchievementCount then
        completed, total = addon.AchievementCount()
    end

    local points = 0
    if addon.GetTotalPoints then
        points = addon.GetTotalPoints()
    end

    local label = ""
    if addon.GetPlayerSelfFoundLabel then
        label = addon.GetPlayerSelfFoundLabel() or ""
    end

    return {
        name = name,
        realm = GetRealmName() or "",
        guild = GetGuildInfo("player") or "",
        faction = UnitFactionGroup("player") or "",
        class = select(1, UnitClass("player")) or "Unknown",
        level = UnitLevel("player") or 0,
        completed = tonumber(completed) or 0,
        total = tonumber(total) or 0,
        points = tonumber(points) or 0,
        label = label,
        selfFound = label == "Self Found",
        dead = PlayerIsDead(),
        version = GetAddOnVersionString(),
        updatedAt = Now(),
    }
end

function Sync:PublishLocal(reason)
    if not LibP2PDB or not self.db then
        return false
    end

    local key = GetCharacterKey()
    local row = self:BuildLocalRow()
    if not key or not row then
        return false
    end

    local current = Leaderboard:GetDB().rows and Leaderboard:GetDB().rows[key]
    if current and ShallowEqual(current, row) then
        return true
    end

    local ok, success = pcall(function()
        return LibP2PDB:SetKey(self.db, TABLE_NAME, key, row)
    end)
    if ok and success then
        StoreRow(key, row)
        PersistState()
        pcall(function()
            LibP2PDB:BroadcastKey(self.db, TABLE_NAME, key)
        end)
        return true
    end
    return false
end

function Sync:SyncPeers()
    if not LibP2PDB or not self.db then
        return
    end
    pcall(function()
        LibP2PDB:BroadcastPresence(self.db)
    end)
    pcall(function()
        LibP2PDB:SyncDatabase(self.db)
    end)
end

function Sync:Persist()
    PersistState()
end
