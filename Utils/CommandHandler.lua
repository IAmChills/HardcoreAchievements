-- CommandHandler.lua
-- Slash commands

local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")

local addonName, addon = ...
local C_GameRules = C_GameRules
local UnitName = UnitName
local UnitLevel = UnitLevel
local CreateFrame = CreateFrame
local time = time
local date = date
local AchievementTracker = (addon and addon.AchievementTracker)
local IsSelfFound = (addon and addon.IsSelfFound)
local table_insert = table.insert
local string_gmatch = string.gmatch
local PRECIOUS_COMPLETE_PREFIX = "HCA_Fellowship" -- AceComm prefix for Precious completion
local DUNGEON_BOSS_SYNC_PREFIX = "HCA_DngBoss" -- AceComm prefix for dungeon boss credit sync

-- Callback registry for Precious completion messages
local preciousCompletionCallbacks = {}

local function GetAccountDB()
    if type(HardcoreAchievementsDB) == "table" then
        if addon then
            addon.HardcoreAchievementsDB = HardcoreAchievementsDB
        end
        return HardcoreAchievementsDB
    end
    if addon and type(addon.HardcoreAchievementsDB) == "table" then
        return addon.HardcoreAchievementsDB
    end
    return nil
end

-- Debug system: Helper functions for debug messages
local function GetDebugEnabled()
    local db = GetAccountDB()
    return (db and db.debugEnabled) or false
end

local function SetDebugEnabled(enabled)
    local db = GetAccountDB()
    if not db then return end
    db.debugEnabled = enabled and true or false
end

local function DebugPrint(message)
    if GetDebugEnabled() then
        print("|cff008066[HCA DEBUG]|r |cffffd100" .. tostring(message) .. "|r")
    end
end
if addon then addon.DebugPrint = DebugPrint end

local function FindAchievementRow(achievementId)
    if not achievementId then return nil end
    local achStr = tostring(achievementId)
    local panel = addon and addon.AchievementPanel
    if panel and panel.achievements then
        for _, row in ipairs(panel.achievements) do
            local rid = row.id or row.achId
            if rid and (rid == achievementId or tostring(rid) == achStr) then
                return row
            end
        end
    end
    if addon and addon.GetAchievementRow then
        return addon.GetAchievementRow(achievementId)
    end
    return nil
end

-- Player-facing achievement name for appeal messages; falls back to the ID.
local function AchievementName(row, achievementId)
    local def = (row and row._def) or (addon.GuildFirst_DefById and addon.GuildFirst_DefById[achievementId])
    local title = row and (row.revealTitle or row.title)
    if (not title or title == "") and def then
        title = def.title
    end
    if (not title or title == "") and row and row.Title and row.Title.GetText then
        title = row.Title:GetText()
    end
    return (title and title ~= "") and title or tostring(achievementId)
end

local function ResolveAchId(row, fallbackId)
    if row then
        local id = row.id or row.achId
        if id ~= nil and id ~= "" then
            return id
        end
    end
    return fallbackId
end

-- deletedByAdmin keys are always stringified for consistent lookup.
local function ClearDeletedByAdminTombstone(cdb, id)
    if not cdb or not cdb.deletedByAdmin or id == nil then
        return
    end
    local key = tostring(id)
    cdb.deletedByAdmin[key] = nil
    if id ~= key then
        cdb.deletedByAdmin[id] = nil -- drop legacy non-string key if present
    end
end

local function IsGuildFirstAchievementRow(row)
    return row and row._def and row._def.isGuildFirst == true
end

local function MarkDeletedGuildFirstClaim(cdb, achievementId)
    if not cdb or not achievementId or achievementId == "" then
        return
    end
    cdb.revokedGuildFirstClaims = cdb.revokedGuildFirstClaims or {}
    cdb.revokedGuildFirstClaims[achievementId] = true
end

local function RefreshCompletionDependencies()
    if addon and type(addon.EvaluateCustomCompletions) == "function" then
        addon.EvaluateCustomCompletions(UnitLevel("player") or 1)
    end
    if addon and type(addon.RefreshAllAchievementPoints) == "function" then
        addon.RefreshAllAchievementPoints()
    end
end

local function RefreshAuxiliaryViews()
    if addon and type(addon.RefreshAuxiliaryViews) == "function" then
        addon.RefreshAuxiliaryViews()
    end
end

local function ShowCompletionToast(achievementRow, points)
    local showToast = (addon and addon.CreateAchToast)
    if type(showToast) == "function" then
        local iconTex = (achievementRow.Icon and achievementRow.Icon.GetTexture) and achievementRow.Icon:GetTexture() or achievementRow.icon or 134400
        local titleText = (achievementRow.Title and achievementRow.Title.GetText) and achievementRow.Title:GetText() or achievementRow.title or "Achievement"
        showToast(iconTex, titleText, points)
    end
end

-- =========================================================
-- Admin correction operations
-- Called only by Utils/AppealCodes.lua after a signed appeal code has been verified for this
-- character. Each returns ok, message; returning false leaves the code unredeemed.
-- =========================================================

-- The given calendar day d, keeping the time of day of originalTime if known.
local function CalculateBackdatedTimestamp(d, originalTime)
    local t = originalTime and date("*t", originalTime)
    return time({
        year = d.year, month = d.month, day = d.day,
        hour = t and t.hour or 0, min = t and t.min or 0, sec = t and t.sec or 0,
    })
end

-- Removes an achievement (completion, failed state, progress). `permanent` also blocks re-earning until unbanned.
local function DeleteAchievement(achievementId, permanent)
    local achievementRow = FindAchievementRow(achievementId)
    if not achievementRow then
        return false, "Achievement not found (ID: " .. tostring(achievementId) .. ")"
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return false, "Database not initialized"
    end

    local id = ResolveAchId(achievementRow, achievementId)
    local name = AchievementName(achievementRow, achievementId)

    -- Full purge: remove achievement record (completion, failed state, timestamps) and all progress
    cdb.achievements = cdb.achievements or {}
    cdb.achievements[id] = nil
    if cdb.progress then
        cdb.progress[id] = nil
    end

    -- Temporary tombstone: prevent an existing GuildFirst claim from being re-awarded
    -- while the corrected claim/remove state propagates through the guild.
    if IsGuildFirstAchievementRow(achievementRow) then
        MarkDeletedGuildFirstClaim(cdb, id)
    end

    -- Permanent tombstone: prevent the player from earning the achievement again until unbanned.
    if permanent then
        cdb.deletedByAdmin = cdb.deletedByAdmin or {}
        cdb.deletedByAdmin[tostring(id)] = true
    end

    -- Reset UI row to initial state
    achievementRow.completed = false

    -- Reset points to original value
    if achievementRow.originalPoints then
        achievementRow.points = achievementRow.originalPoints
    elseif achievementRow._def and achievementRow._def.points then
        achievementRow.points = achievementRow._def.points
    else
        achievementRow.points = 0
    end

    -- Reset UI elements
    if achievementRow.Points then
        achievementRow.Points:SetText(tostring(achievementRow.points))
        achievementRow.Points:SetTextColor(1, 1, 1)
    end

    if achievementRow.TS then
        achievementRow.TS:SetText("")
        achievementRow.TS:SetTextColor(1, 1, 1)
    end

    -- Reset sub text to default
    if achievementRow.Sub then
        local defaultSub = achievementRow._defaultSubText or ""
        achievementRow.Sub:SetText(defaultSub)
    end

    -- Reset icon/frame styling
    if addon and type(addon.ApplyOutleveledStyle) == "function" then
        addon.ApplyOutleveledStyle(achievementRow)
    elseif type(ApplyOutleveledStyle) == "function" then
        ApplyOutleveledStyle(achievementRow)
    end

    -- Update total points
    if addon and type(addon.UpdateTotalPoints) == "function" then
        addon.UpdateTotalPoints()
    end

    -- Reapply filter so hiddenUntilComplete rows get hidden, visibility recalculated, rows repositioned
    if addon and type(addon.ApplyFilter) == "function" then
        addon.ApplyFilter()
    end

    -- Clear progress (if function exists)
    if addon and type(addon.ClearProgress) == "function" then
        addon.ClearProgress(id)
    end

    -- Dashboard / tracker: main row is updated above; embed dashboard reads from DB — rebuild if open
    RefreshAuxiliaryViews()

    if permanent then
        return true, name .. " was removed with restrictions"
    end
    return true, name .. " was removed"
end

-- Clears a permanent delete (and any revoked GuildFirst claim) so the player can earn the achievement again.
local function UnbanAchievement(achievementId)
    local _, cdb = addon.GetCharDB()
    if not cdb then
        return false, "Character data is not loaded yet"
    end
    local name = AchievementName(FindAchievementRow(achievementId), achievementId)

    cdb.deletedByAdmin = cdb.deletedByAdmin or {}
    local hadEntry = cdb.deletedByAdmin[achievementId] and true or false
    ClearDeletedByAdminTombstone(cdb, achievementId)
    local hadRevokedClaim = false
    if cdb.revokedGuildFirstClaims then
        hadRevokedClaim = cdb.revokedGuildFirstClaims[achievementId] and true or false
        cdb.revokedGuildFirstClaims[achievementId] = nil
    end

    RefreshAuxiliaryViews()

    if hadEntry or hadRevokedClaim then
        return true, name .. " was unbanned and can be earned again"
    end
    return true, name .. " was not banned, so nothing changed"
end

-- GuildFirst corrections go through GuildFirst's own claim API, which enforces guild scope.
local function GetGuildFirstModule(achievementId)
    local name = AchievementName(FindAchievementRow(achievementId), achievementId)
    if not (addon and addon.GuildFirst_DefById and addon.GuildFirst_DefById[achievementId]) then
        return nil, name .. " is not a Guild First achievement"
    end
    if not (addon.GuildFirst and type(addon.GuildFirst.OverrideClaim) == "function" and type(addon.GuildFirst.ClearClaim) == "function") then
        return nil, "Guild First is not available on this client"
    end
    return addon.GuildFirst, name
end

local function GuildFirstOverride(achievementId, winnerName, winnerGUID)
    local gf, name = GetGuildFirstModule(achievementId)
    if not gf then
        return false, name
    end
    local ok, claimErr = gf:OverrideClaim(achievementId, winnerName, winnerGUID)
    if not ok then
        return false, "Guild First update for " .. name .. " failed: " .. tostring(claimErr or "unknown error")
    end
    RefreshAuxiliaryViews()
    return true, "Guild First claim for " .. name .. " now belongs to " .. winnerName
end

local function GuildFirstClear(achievementId)
    local gf, name = GetGuildFirstModule(achievementId)
    if not gf then
        return false, name
    end
    local ok, claimErr = gf:ClearClaim(achievementId)
    if not ok then
        return false, "Guild First update for " .. name .. " failed: " .. tostring(claimErr or "unknown error")
    end
    RefreshAuxiliaryViews()
    return true, "Guild First claim for " .. name .. " was cleared"
end

local function NotSoloEligible(name)
    return name .. " is not eligible for solo completion on this character"
end

-- Same rule the kill/quest trackers apply: the achievement allows solo doubling and solo bonuses
-- apply to this character (self-found, or not on a hardcore realm).
local function IsSoloEligible(row)
    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
    return row.allowSoloDouble and (IsSelfFound() or not isHardcoreActive) or false
end

local function SetCompletedPoints(row, rec, points)
    rec.points = points
    row.points = points
    if row.Points then
        row.Points:SetText(tostring(points))
    end
end

local function SetCompletedAt(row, rec, ts)
    rec.completedAt = ts
    if row.TS then
        local fmtTs = (addon and addon.FormatTimestamp) or FormatTimestamp
        row.TS:SetText(fmtTs(ts))
    end
end

-- Partial update of a completed achievement: only fields present in opts change.
local function UpdateCompletedAchievement(row, rec, name, opts)
    if not rec then
        return false, name .. " is marked completed but has no saved record"
    end
    local changed = false

    if opts.solo and not rec.wasSolo then
        if not IsSoloEligible(row) then
            return false, NotSoloEligible(name)
        end
        rec.wasSolo = true
        if row.Sub then
            row.Sub:SetText(AUCTION_TIME_LEFT0 .. "\n" .. addon.ClassColor() .. "Solo|r")
        end
        if not opts.points then
            SetCompletedPoints(row, rec, addon.ComputeCompletionPoints(row, nil, true, rec))
        end
        changed = true
    end
    if opts.points and opts.points ~= rec.points then
        SetCompletedPoints(row, rec, opts.points)
        changed = true
    end
    if opts.level and opts.level ~= rec.level then
        rec.level = opts.level
        changed = true
    end
    if opts.date then
        local cur = rec.completedAt and date("*t", rec.completedAt)
        if not (cur and cur.year == opts.date.year and cur.month == opts.date.month and cur.day == opts.date.day) then
            SetCompletedAt(row, rec, CalculateBackdatedTimestamp(opts.date, rec.completedAt))
            changed = true
        end
    end

    if not changed then
        return true, name .. " is already up to date"
    end
    if addon and type(addon.UpdateTotalPoints) == "function" then
        addon.UpdateTotalPoints()
    end
    RefreshCompletionDependencies()
    RefreshAuxiliaryViews()
    return true, name .. " was updated"
end

-- Awards an achievement. opts (all optional): points, level, solo, date = { year, month, day }.
-- forceUpdate applies a partial update to an already-completed achievement instead of failing.
local function CompleteAchievement(achievementId, opts, forceUpdate)
    opts = opts or {}
    local achievementRow = FindAchievementRow(achievementId)
    if not achievementRow then
        return false, "Achievement not found (ID: " .. tostring(achievementId) .. ")"
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return false, "Character data is not loaded yet"
    end
    cdb.achievements = cdb.achievements or {}

    local id = ResolveAchId(achievementRow, achievementId)
    local name = AchievementName(achievementRow, achievementId)

    if achievementRow.completed then
        if not forceUpdate then
            return false, name .. " is already completed (an update code is needed to change it)"
        end
        return UpdateCompletedAchievement(achievementRow, cdb.achievements[id], name, opts)
    end

    if opts.solo and not IsSoloEligible(achievementRow) then
        return false, NotSoloEligible(name)
    end

    -- Pin the solo outcome so MarkRowCompleted neither samples PlayerIsSolo() nor reuses solo flags or
    -- points tracked on partial progress: an admin completion is solo only when the code says so.
    cdb.progress = cdb.progress or {}
    local progress = cdb.progress[id] or {}
    local saved = { progress.soloKill, progress.soloQuest, progress.pointsAtKill }
    progress.soloKill, progress.soloQuest, progress.pointsAtKill = opts.solo or false, opts.solo or false, nil
    cdb.progress[id] = progress
    local originalTime = progress.failedAt or progress.updatedAt

    -- An admin award overrides (and clears) a permanent delete so MarkRowCompleted can proceed.
    local wasBanned = cdb.deletedByAdmin and cdb.deletedByAdmin[tostring(id)]
    ClearDeletedByAdminTombstone(cdb, id)

    if type(addon.MarkRowCompleted) == "function" then
        addon.MarkRowCompleted(achievementRow, cdb)
    end

    local rec = cdb.achievements[id]
    if not (rec and rec.completed) then
        progress.soloKill, progress.soloQuest, progress.pointsAtKill = saved[1], saved[2], saved[3]
        if wasBanned then
            cdb.deletedByAdmin[tostring(id)] = true
        end
        return false, name .. " could not be marked complete by the achievement system"
    end

    -- Explicit overrides win over the computed completion values
    if opts.points then
        SetCompletedPoints(achievementRow, rec, opts.points)
    end
    if opts.date then
        SetCompletedAt(achievementRow, rec, CalculateBackdatedTimestamp(opts.date, originalTime))
    end
    if opts.level then
        rec.level = opts.level
    end
    rec.failed = nil
    rec.failedAt = nil

    if addon and type(addon.UpdateTotalPoints) == "function" then
        addon.UpdateTotalPoints()
    end
    RefreshCompletionDependencies()
    ShowCompletionToast(achievementRow, achievementRow.points)
    RefreshAuxiliaryViews()
    return true, name .. " was completed"
end

if addon then
    addon.AdminOps = {
        CompleteAchievement = CompleteAchievement,
        DeleteAchievement = DeleteAchievement,
        UnbanAchievement = UnbanAchievement,
        GuildFirstOverride = GuildFirstOverride,
        GuildFirstClear = GuildFirstClear,
    }
end

-- AceComm handler for Precious completion messages
local function OnPreciousCompletedMessage(prefix, message, distribution, sender)
    -- Deserialize the message
    local success, payload = LibSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "precious_completed" then
        return
    end
    
    -- Don't notify the player who completed Precious
    local playerName = UnitName("player")
    if payload.playerName == playerName or sender == playerName then
        DebugPrint("Precious completion message ignored (from self)")
        return
    end
    
    DebugPrint("Precious completion message received from " .. tostring(sender))
    
    -- Call all registered callbacks
    for _, callback in ipairs(preciousCompletionCallbacks) do
        if type(callback) == "function" then
            local ok, err = pcall(callback, payload, sender)
            if not ok then
                DebugPrint("Error in Precious completion callback: " .. tostring(err))
            end
        end
    end
end

local function OnDungeonBossCreditMessage(prefix, message, distribution, sender)
    local success, payload = LibSerialize:Deserialize(message)
    if not success or not payload or payload.type ~= "dungeon_boss_credit" then
        return
    end

    local playerName = UnitName("player")
    if payload.senderName == playerName or sender == playerName then
        return
    end

    local achievementId = payload.achievementId and tostring(payload.achievementId) or ""
    if achievementId == "" then
        return
    end

    local syncFn = addon and addon.GetAchievementFunction and addon.GetAchievementFunction(achievementId, "SyncBossKill")
    if type(syncFn) ~= "function" then
        return
    end

    local okCall, errResult = pcall(syncFn, payload, sender)
    if not okCall and DebugPrint then
        DebugPrint("Error in dungeon boss credit callback: " .. tostring(errResult))
    end
end

-- Initialize the handler
local function InitializeCommHandlers()
    AceComm:RegisterComm(PRECIOUS_COMPLETE_PREFIX, OnPreciousCompletedMessage)
    AceComm:RegisterComm(DUNGEON_BOSS_SYNC_PREFIX, OnDungeonBossCreditMessage)
end

-- Slash command handler
local function HandleSlashCommand(msg)
    local args = {}
    for arg in string_gmatch(msg or "", "%S+") do
        table_insert(args, arg)
    end
    local command = args[1] and string.lower(args[1]) or ""
    
    if command == "reset" and args[2] == "tab" then
        if addon and addon.ResetTabPosition then
            addon.ResetTabPosition()
        end
    elseif command == "appeal" then
        if addon and addon.Appeal then
            addon.Appeal.ShowWindow()
        else
            print("|cffff0000[Hardcore Achievements]|r Appeal codes are not available.")
        end
    elseif command == "tracker" then
        -- Tracker commands
        local subcommand = args[2] and string.lower(args[2]) or ""
        
        if not AchievementTracker then
            print("|cff008066[Hardcore Achievements]|r Achievement tracker not loaded yet. Please wait a moment and try again, or reload your UI.")
            return
        end
        
        if subcommand == "show" then
            if AchievementTracker.Show then
                AchievementTracker:Show()
                print("|cff008066[Hardcore Achievements]|r Achievement tracker shown")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        elseif subcommand == "hide" then
            if AchievementTracker.Hide then
                AchievementTracker:Hide()
                print("|cff008066[Hardcore Achievements]|r Achievement tracker hidden")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        elseif subcommand == "toggle" then
            if AchievementTracker.Toggle then
                AchievementTracker:Toggle()
                print("|cff008066[Hardcore Achievements]|r Achievement tracker toggled")
            else
                print("|cffff0000[Hardcore Achievements]|r Achievement tracker not initialized")
            end
        else
            print("|cff008066[Hardcore Achievements]|r Tracker commands:")
            print("  |CFFFFD100/hca tracker show|r - Show the achievement tracker")
            print("  |CFFFFD100/hca tracker hide|r - Hide the achievement tracker")
            print("  |CFFFFD100/hca tracker toggle|r - Toggle the achievement tracker")
        end
    elseif command == "log" then
        local sub = args[2] and string.lower(args[2]) or "show"
        -- Event log /hca log clear disabled for now (retain history for debugging).
        -- if sub == "clear" then
        --     if addon.EventLogClear then
        --         addon.EventLogClear()
        --         print("|cff008066[Hardcore Achievements]|r Event log cleared (saved log wiped).")
        --     end
        -- elseif sub == "show" or sub == "" then
        if sub == "show" or sub == "" then
            if addon.EventLogShow then
                addon.EventLogShow()
            else
                print("|cffff0000[Hardcore Achievements]|r Event log is not available.")
            end
        else
            print("|cff008066[Hardcore Achievements]|r Event log: |CFFFFD100/hca log|r or |CFFFFD100/hca log show|r")
        end
    elseif command == "leaderboard" or command == "lb" then
        if addon and addon.Leaderboard and addon.Leaderboard.Toggle then
            addon.Leaderboard:Toggle()
        else
            print("|cffff0000[Hardcore Achievements]|r Achievement leaderboard is not available yet.")
        end
    elseif command == "probe" then
        if addon and addon.RunForeverProbe then
            addon.RunForeverProbe()
        else
            print("|cff008066[Hardcore Achievements]|r /hca probe is only available on the Forever client")
        end
    elseif command == "killdebug" then
        if not (addon and addon.SetForeverKillDebug) then
            print("|cff008066[Hardcore Achievements]|r /hca killdebug is only available on the Forever client")
        else
            local sub = args[2] and string.lower(args[2]) or ""
            local enable = sub == "on" or (sub ~= "off" and not addon.ForeverKillDebug)
            addon.SetForeverKillDebug(enable)
            print("|cff008066[Hardcore Achievements]|r Kill debug " .. (enable and "enabled" or "disabled"))
        end
    elseif command == "debug" then
        -- Debug toggle command
        if args[2] and string.lower(args[2]) == "on" then
            SetDebugEnabled(true)
            print("|cff008066[Hardcore Achievements]|r Debug mode enabled")
            if addon and addon.DebugPrint then addon.DebugPrint("Debug mode is now ON - you will see debug messages") end
        elseif args[2] and string.lower(args[2]) == "off" then
            SetDebugEnabled(false)
            print("|cff008066[Hardcore Achievements]|r Debug mode disabled")
        else
            -- Toggle if no argument provided
            local currentState = GetDebugEnabled()
            SetDebugEnabled(not currentState)
            if not currentState then
                print("|cff008066[Hardcore Achievements]|r Debug mode enabled")
                if addon and addon.DebugPrint then addon.DebugPrint("Debug mode is now ON - you will see debug messages") end
            else
                print("|cff008066[Hardcore Achievements]|r Debug mode disabled")
            end
        end
    elseif command == "" then
        if addon and addon.ShowAchievementWindow then
            addon.ShowAchievementWindow()
        elseif addon and addon.Dashboard and addon.Dashboard.Toggle then
            addon.Dashboard:Toggle()
        elseif addon and addon.ShowDashboard then
            addon.ShowDashboard()
        end
    else
        print("|cff008066[Hardcore Achievements]|r Available commands:")
        --        print("  |CFFFFD100/hca reset tab|r - Reset the tab position to default")
        print("  |CFFFFD100/hca tracker|r - Manage the achievement tracker")
        print("  |CFFFFD100/hca leaderboard|r - Toggle the achievement leaderboard")
        --print("  |CFFFFD100/hca appeal|r - Redeem an achievement correction code")
        print("  |CFFFFD100/hca debug|r - Toggle debug mode (on/off)")
        print("  |CFFFFD100/hca log|r - Open troubleshooting event log")
        --print("  |CFFFFD100/hca log clear|r - Clear the event log")
    end
end

-- Register slash command
SLASH_HARDCOREAchievements1 = "/hca"
SLASH_HARDCOREAchievements2 = "/hardcoreachievements"
SlashCmdList["HARDCOREAchievements"] = HandleSlashCommand

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeCommHandlers()
        self:UnregisterAllEvents()
    end
end)

-- =========================================================
-- Precious Completion Communication (Regular Feature)
-- These functions are NOT admin-related and are available to all players
-- =========================================================

-- Helper function to send Precious completion notification via SAY channel
-- This notifies nearby players (within chat range) so they can complete Fellowship
local function SendPreciousCompletionMessage()
    local messagePayload = {
        type = "precious_completed",
        playerName = UnitName("player")
    }
    
    local serializedMessage = LibSerialize:SerializeEx({errorOnUnserializableType = false}, messagePayload)
    if serializedMessage then
        AceComm:SendCommMessage(PRECIOUS_COMPLETE_PREFIX, serializedMessage, "SAY")
        if DebugPrint then DebugPrint("Precious completion message sent") end
    end
end

-- Register a callback to be called when Precious completion message is received
-- Callback signature: function(payload, sender) where payload contains {type, playerName}
local function RegisterPreciousCompletionCallback(callback)
    if type(callback) == "function" then
        table_insert(preciousCompletionCallbacks, callback)
    end
end

local function SendDungeonBossCreditMessage(achievementId, mapId, npcId, killToken)
    achievementId = achievementId and tostring(achievementId) or ""
    killToken = killToken and tostring(killToken) or ""
    npcId = tonumber(npcId)
    if achievementId == "" or killToken == "" or not npcId then
        return false
    end

    local distribution = nil
    if IsInRaid and IsInRaid() then
        distribution = "RAID"
    elseif IsInGroup and IsInGroup() then
        distribution = "PARTY"
    end
    if not distribution then
        return false
    end

    local messagePayload = {
        type = "dungeon_boss_credit",
        achievementId = achievementId,
        mapId = tonumber(mapId),
        npcId = npcId,
        killToken = killToken,
        senderName = UnitName("player"),
    }

    local serializedMessage = LibSerialize:SerializeEx({errorOnUnserializableType = false}, messagePayload)
    if not serializedMessage then
        return false
    end

    AceComm:SendCommMessage(DUNGEON_BOSS_SYNC_PREFIX, serializedMessage, distribution)
    if DebugPrint then
        DebugPrint("Dungeon boss credit sync sent for " .. achievementId .. " npc " .. tostring(npcId))
    end
    return true
end

if addon then
    addon.SendPreciousCompletionMessage = SendPreciousCompletionMessage
    addon.RegisterPreciousCompletionCallback = RegisterPreciousCompletionCallback
    addon.SendDungeonBossCreditMessage = SendDungeonBossCreditMessage
end
