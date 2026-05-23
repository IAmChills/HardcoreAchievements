local addonName, addon = ...
if not addon then return end

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetRealmName = GetRealmName
local GetTime = GetTime
local math_random = math.random

local Leaderboard = addon.Leaderboard or {}
addon.Leaderboard = Leaderboard

-- Periodic full dashboard leaderboard rebuild while tab is visible.
-- This serves as the batch refresh timer for Option B (pause instant peer-driven rebuilds).
-- Leaderboard can be up to ~60s out of date while viewing, with one rebuild hitch per cycle.
local LEADERBOARD_VIEW_UI_REFRESH_SEC = 60
local LEADERBOARD_DASHBOARD_REFRESH_DEBOUNCE_SEC = 0.35
local dashboardRefreshToken = 0
local PUBLISH_DEBOUNCE_SEC = 3
local PRESENCE_INTERVAL_SEC = 5 * 60
local LIGHTWEIGHT_SYNC_INTERVAL_SEC = 120
local OPEN_SYNC_COOLDOWN_SEC = 60
local LOGIN_SYNC_RETRY_COOLDOWN_SEC = 20
local SCHEDULER_TICK_SEC = 1
local LOGIN_PRUNE_GRACE_SEC = 10 * 60
local pendingPublishReason
local pendingPublishAt
local pendingPresenceAt
local pendingPresenceOffline
local pendingFullSyncQueue = {}
local lastFullSyncAt = 0
local nextPresenceAt = 0
local nextLightweightSyncAt = 0
local initialLoginSyncDone = false
local schedulerTicker
local loginPruneGraceUntil = 0

-- =============================================================================
-- OPTION A: INCREMENTAL / DIRTY-ROW UPDATE PLAN (FUTURE WORK)
-- =============================================================================
-- Goal
--   Replace the current Option B 60-second full-rebuild ticker with targeted,
--   near-zero-cost updates that only touch the row frames whose underlying
--   player data actually changed. This eliminates the periodic hitch entirely
--   while keeping the leaderboard near real-time for visible rows.
--
-- Why we are not doing this yet (May 2026)
--   Current combination (Option B pause + 500-row cap + data caching) already
--   feels "very responsive and snappy". We want to validate real-world usage
--   and the "Top N of M" UX before investing in the more intrusive incremental
--   path. This plan is recorded here so we can return to it quickly later.
--
-- Current State (what Option A builds on)
--   - LeaderboardData.lua: full sort + LEADERBOARD_MAX_DISPLAY_ROWS=500 cap
--     with totalUntruncated attached to the returned table.
--   - Leaderboard.lua: QueueDashboardLeaderboardRefresh() is a no-op while
--     leaderboard tab visible; 60s ticker does full RefreshDashboard(true).
--   - StoreRow() calls Data:Invalidate() + Leaderboard:Refresh().
--   - Dashboard.lua: BuildDashboardLeaderboardRows() creates/reuses rows in
--     DASHBOARD.leaderboardRows[], each row has .rowData, .playerName, cells[].
--   - Pre-computed display strings (_displayClassPortrait, _displayAchievementColor)
--     already live on row data objects.
--   - PauseDashboardRebuildWhileLeaderboardTabVisible() guard exists.
--
-- High-Level Approach
--   1. Track "dirty" player keys instead of forcing full rebuilds on every peer
--      broadcast.
--   2. Maintain a cheap reverse lookup (playerKey -> row frame or index) so we
--      can locate the exact row that needs updating.
--   3. Implement a lightweight UpdateLeaderboardRow(key) that re-binds only the
--      changed cells on an existing row (re-using the same SetLeaderboardCell,
--      faction texture, color, tooltip, etc. logic).
--   4. On new rows that enter the visible set (or deletions), fall back to a
--      single full rebuild (rare under normal operation with the 500 cap).
--   5. The 60 s ticker becomes a pure safety net / no-op.
--
-- Detailed Implementation Steps (do in order)
--   1. Add dirty tracking
--      - local dirtyLeaderboardKeys = {}   -- set: key -> true
--      - In StoreRow() (LeaderboardSync.lua), after Invalidate(), do:
--          dirtyLeaderboardKeys[row.key] = true
--          -- Do NOT call Leaderboard:Refresh() here anymore (or make it conditional)
--
--   2. Create reverse lookup on rebuild
--      - In BuildDashboardLeaderboardRows() (or a new EnsureLeaderboardRowMap()),
--        build a transient map: DASHBOARD.leaderboardRowByKey = { [key] = rowFrame }
--        This is cheap (max 500 entries) and only rebuilt on full rebuilds.
--
--   3. Implement the core incremental function
--      local function UpdateLeaderboardRow(playerKey)
--        local row = DASHBOARD.leaderboardRowByKey and DASHBOARD.leaderboardRowByKey[playerKey]
--        if not row or not row:IsShown() then return false end
--
--        local lb = addon.Leaderboard
--        -- Re-fetch the latest rowData for this key (from cached GetRows or direct)
--        local latest = ... -- obtain from Leaderboard.Data or a new GetRowByKey helper
--        if not latest then return false end
--
--        -- Re-bind using the exact same logic as the classic path, but targeted:
--        --   - name, level, class portrait (use _displayClassPortrait if present)
--        --   - faction textures (compare to row._hcaLbFaction to avoid redundant sets)
--        --   - selfFound icon, achievement text with color code (_displayAchievementColor)
--        --   - lastSeenText
--        --   - tooltipTitle / tooltipLines
--        --   - alpha / offline state
--        -- All of this already exists in BuildDashboardLeaderboardRows; extract a
--        -- helper BindLeaderboardRowData(row, rowData, localCharacterKey, viewerGuild) if needed.
--
--        row.rowData = latest
--        -- ... perform the SetLeaderboardCell / texture / alpha updates ...
--        return true
--      end
--
--   4. Wire dirty application
--      - Add a new exported function Leaderboard:ApplyPendingUpdates()
--        that iterates dirtyLeaderboardKeys, calls UpdateLeaderboardRow(k) for each,
--        then clears the set.
--      - Call it from:
--          - The existing 60 s ticker (now becomes a cheap "apply dirty" pass)
--          - Any place that currently does RefreshDashboard(true) while viewing
--            (make it conditional: if dirty set is small, use incremental; else full)
--
--   5. Handle edge cases that still need a full rebuild
--      - New player enters the top 500 after sort (rank changes for many rows)
--      - Player drops out of top 500
--      - Scope change (guild/realm/dead filters)
--      - Sort column change (different ordering)
--      - Manual refresh / explicit force
--      Detection: keep a "lastKnownCount" or simply fall back to full rebuild
--      if any UpdateLeaderboardRow returns false (row not found).
--
--   6. Update the 60 s ticker
--      - Change from addon.RefreshDashboard(true) to Leaderboard:ApplyPendingUpdates()
--        (or keep a very cheap safety rebuild every 5–10 minutes).
--
--   7. Cleanup & safety
--      - On tab hide or scope change, clear dirtyLeaderboardKeys.
--      - Add a small size guard: if #dirty > 50 then do a full rebuild instead.
--      - Preserve the existing render cache (_hcaLbCellText, _hcaLbCellColor, etc.)
--        so incremental sets are still cheap.
--
-- Integration with 500 Cap
--   Because we already truncate to 500 after accurate sort, the reverse map never
--   exceeds 500 entries and linear scans (if we choose not to maintain a map) are
--   trivial. Option A becomes dramatically cheaper with the cap in place.
--
-- Expected Outcome After Implementation
--   - Memory stays flat after first leaderboard open.
--   - CPU while viewing leaderboard stays near baseline (6–10 ms) even with
--     constant peer broadcasts.
--   - Updates to any visible row appear almost instantly.
--   - One full rebuild only on explicit user actions or rare structural changes.
--   - The "Top 500 of X" label and all other current optimizations remain.
--
-- Rollback Strategy
--   - Remove dirtyLeaderboardKeys and ApplyPendingUpdates.
--   - Restore the 60 s full-rebuild ticker and the original Refresh path in StoreRow.
--   - The 500 cap and Option B pause can stay or be removed independently.
--
-- Testing Checklist (when we implement)
--   [ ] Peer earns achievement → only that row updates, no hitch
--   [ ] New high-score player appears in top 500 → full rebuild once, then incremental
--   [ ] Scrolling while peers update → no frame drops
--   [ ] Switch sort column → one full rebuild, then incremental again
--   [ ] Large guild (400 players) + many broadcasts → steady low CPU
--   [ ] Toggle leaderboard tab on/off → no leaks or stale dirty keys
--
-- Future Enhancements (optional, post-Option A)
--   - Virtual scrolling on top of incremental (if we ever remove the 500 cap)
--   - Delta compression on LibP2P row diffs to reduce network chatter
--   - "Find Me" button that scrolls to your row using the key→row map
--
-- This plan is intentionally verbose so that when we return to it the implementation
-- work is mechanical and low-risk. All the heavy lifting (caching, pre-computed
-- strings, render caching, 500 cap) is already done.
-- =============================================================================

-- Search state for the leaderboard name/class/faction filter (Option A compatible).
Leaderboard.searchTerm = ""

function Leaderboard:SetSearchTerm(term)
  local t = tostring(term or ""):lower():match("^%s*(.-)%s*$") or ""
  if Leaderboard.searchTerm == t then return end
  Leaderboard.searchTerm = t
  if Leaderboard.Data and Leaderboard.Data.Invalidate then
    Leaderboard.Data:Invalidate()
  end
  Leaderboard:ClearDirty()
  if addon and addon.RefreshDashboard then
    addon.RefreshDashboard(true)
  end
end

function Leaderboard:GetSearchTerm()
  return Leaderboard.searchTerm or ""
end

-- =============================================================================
-- OPTION A: DIRTY TRACKING (incremental row updates)
-- =============================================================================
local dirtyLeaderboardKeys = {}

function Leaderboard:MarkDirty(key)
  if key then
    dirtyLeaderboardKeys[key] = true
  end
end

function Leaderboard:ClearDirty()
  dirtyLeaderboardKeys = {}
end

function Leaderboard:GetDirtyCount()
  local n = 0
  for _ in pairs(dirtyLeaderboardKeys) do n = n + 1 end
  return n
end

function Leaderboard:HasDirty()
  for _ in pairs(dirtyLeaderboardKeys) do return true end
  return false
end

function Leaderboard:IterateDirty()
  return pairs(dirtyLeaderboardKeys)
end

function Leaderboard:ApplyPendingUpdates()
  -- Only meaningful while the leaderboard tab is visible.
  local df = addon and addon.DashboardFrame
  if not df or not df:IsShown() or df.SelectedTabKey ~= "leaderboard" then
    Leaderboard:ClearDirty()
    return
  end

  if DASHBOARD and DASHBOARD.ApplyPendingLeaderboardUpdates then
    DASHBOARD.ApplyPendingLeaderboardUpdates()
  else
    -- Safe fallback
    Leaderboard:ClearDirty()
    if addon.RefreshDashboard then addon.RefreshDashboard(true) end
  end
end

-- English display + sync — derived from Blizzard class index (UnitClass third return) when known.
local CLASS_ID_TO_ENGLISH = {
    [1] = "Warrior",
    [2] = "Paladin",
    [3] = "Hunter",
    [4] = "Rogue",
    [5] = "Priest",
    [7] = "Shaman",
    [8] = "Mage",
    [9] = "Warlock",
    [11] = "Druid",
}

--- English name from class id; if id is unknown/missing, uses fallback (e.g. synced class string).
function Leaderboard.GetEnglishClassName(classId, fallback)
    local id = tonumber(classId)
    if id and CLASS_ID_TO_ENGLISH[id] then
        return CLASS_ID_TO_ENGLISH[id]
    end
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end
    return "Unknown"
end

--- English class + numeric id from UnitClass (arg2 locale-free token; arg3 class id).
function Leaderboard.GetNormalizedPlayerClass()
    local localized, token, classId = UnitClass("player")
    classId = tonumber(classId)
    if classId and CLASS_ID_TO_ENGLISH[classId] then
        return CLASS_ID_TO_ENGLISH[classId], classId
    end
    if type(token) == "string" and token ~= "" then
        local lc = token:lower()
        return lc:sub(1, 1):upper() .. lc:sub(2), classId
    end
    return localized or "Unknown", classId
end

--- Stable row key for leaderboard storage and sync (Player-xxxx, or legacy name-realm if GUID unavailable).
function Leaderboard.GetLeaderboardRowKey()
    local guid = UnitGUID("player")
    if type(guid) == "string" and guid ~= "" then
        return guid
    end
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    if not name or name == "" then
        return nil
    end
    return (realm and realm ~= "" and (name .. "-" .. realm)) or name
end

local DEFAULT_SCOPE = {
    guild = true,
    realm = false,
    faction = false,
    dead = false,
}

local function QueueDashboardLeaderboardRefresh()
    local df = addon and addon.DashboardFrame
    if not (df and df:IsShown() and df.SelectedTabKey == "leaderboard" and addon.RefreshDashboard) then
        return
    end
    -- When the leaderboard tab is visible we skip forced rebuilds on peer updates.
    -- StoreRow still calls Invalidate() so the data model stays correct.
    -- A full rebuild occurs periodically via the 60s leaderboardUIViewTicker
    -- (or immediately on scope changes / manual refresh via direct RefreshDashboard(true)).
    -- This eliminates the "every few seconds" full-rebuild thrashing while viewing.
    return
end

local function JitteredDelay(baseSeconds, jitterSeconds)
    baseSeconds = tonumber(baseSeconds) or 0
    jitterSeconds = tonumber(jitterSeconds) or 0
    if jitterSeconds <= 0 then
        return baseSeconds
    end
    return baseSeconds + math_random(0, jitterSeconds)
end

local function IsLeaderboardVisible()
    local df = addon and addon.DashboardFrame
    return df and df:IsShown() and df.SelectedTabKey == "leaderboard"
end

local function PublishNow(reason)
    if Leaderboard.Sync and Leaderboard.Sync.PublishLocal then
        return Leaderboard.Sync:PublishLocal(reason)
    end
    return false
end

local function NowSeconds()
    return (GetTime and GetTime()) or 0
end

local function BroadcastPresenceNow()
    if Leaderboard.Sync and Leaderboard.Sync.BroadcastPresence then
        Leaderboard.Sync:BroadcastPresence()
    end
    if Leaderboard.Sync and Leaderboard.Sync.PublishPresence then
        Leaderboard.Sync:PublishPresence(false)
    end
end

local function RunFullSyncNow(cooldownSeconds)
    local now = NowSeconds()
    cooldownSeconds = tonumber(cooldownSeconds) or 0
    if cooldownSeconds > 0 and lastFullSyncAt > 0 and (now - lastFullSyncAt) < cooldownSeconds then
        return
    end
    lastFullSyncAt = now
    BroadcastPresenceNow()
    if Leaderboard.Sync and Leaderboard.Sync.SyncDatabase then
        Leaderboard.Sync:SyncDatabase()
    end
end

local function SchedulerPulse()
    local now = NowSeconds()

    if Leaderboard.Data and Leaderboard.Data.ProcessTombstoneQueue then
        Leaderboard.Data:ProcessTombstoneQueue()
    end

    if pendingPublishAt and now >= pendingPublishAt then
        local reason = pendingPublishReason or "queued"
        pendingPublishAt = nil
        pendingPublishReason = nil
        PublishNow(reason)
    end

    if pendingPresenceAt and now >= pendingPresenceAt then
        local offline = pendingPresenceOffline == true
        pendingPresenceAt = nil
        pendingPresenceOffline = nil
        if Leaderboard.Sync and Leaderboard.Sync.PublishPresence then
            Leaderboard.Sync:PublishPresence(offline)
        end
    end

    for i = #pendingFullSyncQueue, 1, -1 do
        local item = pendingFullSyncQueue[i]
        if item and now >= item.dueAt then
            table.remove(pendingFullSyncQueue, i)
            RunFullSyncNow(item.cooldown)
        end
    end

    if nextPresenceAt <= 0 then
        nextPresenceAt = now + PRESENCE_INTERVAL_SEC
    elseif now >= nextPresenceAt then
        pendingPresenceAt = pendingPresenceAt and math.min(pendingPresenceAt, now) or now
        pendingPresenceOffline = false
        nextPresenceAt = now + PRESENCE_INTERVAL_SEC
    end

    if nextLightweightSyncAt <= 0 then
        nextLightweightSyncAt = now + LIGHTWEIGHT_SYNC_INTERVAL_SEC
    elseif now >= nextLightweightSyncAt then
        RunFullSyncNow(0)
        nextLightweightSyncAt = now + LIGHTWEIGHT_SYNC_INTERVAL_SEC
    end
end

local function EnsureScheduler()
    if schedulerTicker or not (C_Timer and C_Timer.NewTicker) then
        return
    end
    schedulerTicker = C_Timer.NewTicker(SCHEDULER_TICK_SEC, SchedulerPulse)
end

local function QueueLocalPublish(reason, immediate, delaySeconds)
    if immediate or not C_Timer then
        pendingPublishAt = nil
        pendingPublishReason = nil
        return PublishNow(reason)
    end

    local dueAt = NowSeconds() + (tonumber(delaySeconds) or PUBLISH_DEBOUNCE_SEC)
    pendingPublishReason = reason or pendingPublishReason or "queued"
    pendingPublishAt = pendingPublishAt and math.min(pendingPublishAt, dueAt) or dueAt
    EnsureScheduler()
    return true
end

local function QueuePresence(delaySeconds, offline)
    local dueAt = NowSeconds() + (tonumber(delaySeconds) or 0)
    pendingPresenceAt = pendingPresenceAt and math.min(pendingPresenceAt, dueAt) or dueAt
    pendingPresenceOffline = offline == true
    EnsureScheduler()
end

local function QueueFullSync(delaySeconds, cooldownSeconds)
    local dueAt = NowSeconds() + (tonumber(delaySeconds) or 0)
    pendingFullSyncQueue[#pendingFullSyncQueue + 1] = {
        dueAt = dueAt,
        cooldown = tonumber(cooldownSeconds) or 0,
    }
    EnsureScheduler()
end

local function StopVisibleSyncLoop()
    -- Visible sync is intentionally one-shot on open; keep this hook for tab cleanup.
end

local function QueueLeaderboardOpenSync()
    if not C_Timer then
        QueueLocalPublish("leaderboard_open", true)
        BroadcastPresenceNow()
        RunFullSyncNow(OPEN_SYNC_COOLDOWN_SEC)
        return
    end

    QueueLocalPublish("leaderboard_open", false, 0.5)
    QueuePresence(1)
    QueueFullSync(2, OPEN_SYNC_COOLDOWN_SEC)
    EnsureScheduler()
end

local function EnsureRootDB()
    if type(HardcoreAchievementsDB) ~= "table" then
        HardcoreAchievementsDB = {}
    end
    addon.HardcoreAchievementsDB = HardcoreAchievementsDB
    HardcoreAchievementsDB.leaderboard = HardcoreAchievementsDB.leaderboard or {}

    local db = HardcoreAchievementsDB.leaderboard
    db.rows = db.rows or {}
    db.settings = db.settings or {}
    db.settings.scope = db.settings.scope or {}
    for key, defaultValue in pairs(DEFAULT_SCOPE) do
        if db.settings.scope[key] == nil then
            db.settings.scope[key] = defaultValue
        end
    end
    return db
end

function Leaderboard:GetDB()
    return EnsureRootDB()
end

function Leaderboard:GetScope()
    return self:GetDB().settings.scope
end

function Leaderboard:SetScopeValue(key, enabled)
    local scope = self:GetScope()
    scope[key] = enabled and true or false
    if self.Data and self.Data.Invalidate then
        self.Data:Invalidate()
    end
    self:ClearDirty()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
    if addon.RefreshDashboard then
        addon.RefreshDashboard(true)
    end
end

function Leaderboard:Refresh()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
    QueueDashboardLeaderboardRefresh()
end

function Leaderboard:Toggle()
    local dashboardFrame = addon and addon.DashboardFrame
    if dashboardFrame and dashboardFrame:IsShown() and dashboardFrame.SelectedTabKey == "leaderboard" then
        StopVisibleSyncLoop()
        if addon.Dashboard and addon.Dashboard.Hide then
            addon.Dashboard:Hide()
        else
            dashboardFrame:Hide()
        end
        return
    end
    self:Show()
end

function Leaderboard:Show()
    addon._hcaOpenDashboardTabKey = "leaderboard"
    if addon.Dashboard and addon.Dashboard.Show then
        addon.Dashboard:Show()
    elseif self.UI and self.UI.Show then
        self.UI:Show()
    end
    QueueLeaderboardOpenSync()
end

function Leaderboard:OnLeaderboardHidden()
    StopVisibleSyncLoop()
end

function Leaderboard:EnsureScheduler()
    EnsureScheduler()
end

function Leaderboard:IsPruneGraceActive()
    return loginPruneGraceUntil > 0 and NowSeconds() < loginPruneGraceUntil
end

function Leaderboard:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    EnsureRootDB()

    if self.Sync and self.Sync.Initialize then
        self.Sync:Initialize()
    end
    if self.UI and self.UI.Initialize then
        self.UI:Initialize()
    end

    if addon.Hooks and addon.Hooks.HookScript then
        addon.Hooks:HookScript("OnAchievement", function()
            QueueLocalPublish("achievement", IsLeaderboardVisible())
        end)
    end

    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_ALIVE")
    eventFrame:RegisterEvent("PLAYER_UNGHOST")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            if initialLoginSyncDone then
                return
            end
            initialLoginSyncDone = true
            loginPruneGraceUntil = NowSeconds() + LOGIN_PRUNE_GRACE_SEC
            local loginDelay = JitteredDelay(3, 3)
            QueueLocalPublish("login", false, loginDelay)
            QueuePresence(loginDelay)
            QueueFullSync(loginDelay + 2, LOGIN_SYNC_RETRY_COOLDOWN_SEC)
            QueueFullSync(loginDelay + 25, LOGIN_SYNC_RETRY_COOLDOWN_SEC)
            QueueFullSync(loginDelay + 55, 5 * 60)
        elseif event == "PLAYER_LOGOUT" then
            QueueLocalPublish("PLAYER_LOGOUT", true)
            if Leaderboard.Sync and Leaderboard.Sync.PublishPresence then
                Leaderboard.Sync:PublishPresence(true)
            end
        elseif event == "PLAYER_DEAD" then
            -- Publish immediately so a fast logout does not write offline=false before dead=true is stored.
            QueueLocalPublish("PLAYER_DEAD", true)
        elseif event == "PLAYER_GUILD_UPDATE" then
            if Leaderboard.Sync and Leaderboard.Sync.ClearGuildLastKnown then
                Leaderboard.Sync:ClearGuildLastKnown()
            end
            QueueLocalPublish("PLAYER_GUILD_UPDATE", IsLeaderboardVisible())
        else
            QueueLocalPublish(event, IsLeaderboardVisible())
        end
    end)

    if self.refreshTicker then
        self.refreshTicker:Cancel()
        self.refreshTicker = nil
    end
    EnsureScheduler()

    if self.leaderboardUIViewTicker then
        self.leaderboardUIViewTicker:Cancel()
    end
    self.leaderboardUIViewTicker = C_Timer.NewTicker(LEADERBOARD_VIEW_UI_REFRESH_SEC, function()
        local df = addon.DashboardFrame
        if df and df:IsShown() and df.SelectedTabKey == "leaderboard" then
            if Leaderboard.ApplyPendingUpdates then
                -- Option A: cheap incremental pass over dirty rows.
                Leaderboard:ApplyPendingUpdates()
            elseif addon.RefreshDashboard then
                addon.RefreshDashboard(true)
            end
        else
            StopVisibleSyncLoop()
        end
    end)
end

SLASH_HCALEADERBOARD1 = "/hcalb"
SlashCmdList.HCALEADERBOARD = function()
    if addon.Leaderboard and addon.Leaderboard.Toggle then
        addon.Leaderboard:Toggle()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if addon.Leaderboard and addon.Leaderboard.Initialize then
        addon.Leaderboard:Initialize()
    end
end)
