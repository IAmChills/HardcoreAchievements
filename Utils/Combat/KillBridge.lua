local addonName, addon = ...
-- =========================================================
-- Kill / combat event bridge + emote hook
-- =========================================================
-- Extracted from HardcoreAchievements.lua (Phase 2). Fresh Lua 5.1 local budget.
-- Loads after HardcoreAchievements.lua so MarkRowCompleted / CreateAchToast are on addon.

local MarkRowCompleted = addon.MarkRowCompleted
local CreateAchToast = addon.CreateAchToast
local IsAchievementAlreadyCompleted = addon.IsAchievementAlreadyCompleted
local ClearProgress = addon.ClearProgress
local EvaluateCustomCompletions = addon.EvaluateCustomCompletions
local PlayerIsSolo_UpdateStatusForGUID = addon.PlayerIsSolo_UpdateStatusForGUID
local PlayerIsSolo_OnCombatLogEvent = addon.PlayerIsSolo_OnCombatLogEvent
local PlayerFactionMatches = addon.PlayerFactionMatches
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UnitExists = UnitExists
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitCanAttack = UnitCanAttack
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local string_format = string.format
local QuestTrackedRows = addon.QuestTrackedRows
if type(QuestTrackedRows) ~= "table" then
    QuestTrackedRows = {}
    addon.QuestTrackedRows = QuestTrackedRows
end

-- Call-time lookups: these live in HardcoreAchievements.lua and may be nil at this file's load.
local function InvalidateOutleveledCache()
    if addon.InvalidateOutleveledCache then
        return addon.InvalidateOutleveledCache()
    end
end

local function RefreshOutleveledAll()
    if addon.RefreshOutleveledAll then
        return addon.RefreshOutleveledAll()
    end
end

local function IsRowOutleveled(row)
    if addon.IsRowOutleveled then
        return addon.IsRowOutleveled(row)
    end
    return false
end

local function SortAchievementRows()
    if addon.SortAchievementRows then
        return addon.SortAchievementRows()
    end
end

local function GetAchievementToastDisplay(row)
    if addon.GetAchievementToastDisplay then
        return addon.GetAchievementToastDisplay(row)
    end
    if not row then
        return 136116, "Achievement", nil
    end
    local frame = row.frame or row
    return row.icon or 136116, row.title or "Achievement", frame
end

-- Forever may omit this global; resolve at CLEU time rather than capturing nil at load.
local function CombatLogGetCurrentEventInfo(...)
    local fn = _G.CombatLogGetCurrentEventInfo
    if fn then
        return fn(...)
    end
end

-- =========================================================
-- Event bridge: forward PARTY_KILL to any rows with a tracker
-- =========================================================

do
    if addon and not addon.AchEvt then
        local achEvt = CreateFrame("Frame")
        addon.AchEvt = achEvt
        -- Track recently processed kills to prevent duplicate processing
        local recentKills = {}
        -- Cross-path dedupe between a GUID kill and ENCOUNTER_END for the same boss death. Stored on
        -- the frame so this block does not add locals: the file is at Lua's 200-local limit. Keyed by
        -- npcId and only consulted by the other path, so repeated open-world kills of one npcId are
        -- unaffected. Bosses do not respawn inside the 10 second window.
        achEvt.guidClaimedAt = {}
        achEvt.encounterClaimedAt = {}
        local function clearRecentKill(destGUID)
            C_Timer.After(1, function()
                recentKills[destGUID] = nil
            end)
        end
        
        -- Track NPCs the player is fighting (for achievements)
        -- Only process kills if the player was actually fighting the NPC
        local npcsInCombat = {}  -- [destGUID] = true when player is fighting this NPC
        
        -- Track tap denial status for NPCs we're fighting
        -- [destGUID] = true if tap denied, false if not tap denied, nil if unknown
        local npcTapDenied = {}
        
        -- Helper function to check and store tap denial status for an NPC
        local function checkAndStoreTapDenied(destGUID)
            if UnitExists("target") and UnitGUID("target") == destGUID then
                local isTapDenied = UnitIsTapDenied("target")
                npcTapDenied[destGUID] = isTapDenied
                return isTapDenied
            end
            -- Return stored value if we can't check right now
            return npcTapDenied[destGUID]
        end
        
        -- Track external players (non-party) that are fighting tracked NPCs
        -- externalPlayersByNPC[destGUID] = { [playerGUID] = { lastSeen = time, threat = nil } }
        local externalPlayersByNPC = {}
        local EXTERNAL_PLAYER_TIMEOUT = 15  -- seconds to remember external players after last damage event

        -- Throttle UnitDetailedThreatSituation checks to at most once per 0.5s per NPC
        local _threatCheckTime = {}

        -- Per-NPC solo status throttle: max once per 0.25s to cap CheckSoloStatusForGUID calls.
        local _soloUpdateThrottle = {}

        -- Quest log state cache (questID -> bool). Cleared on quest events.
        local _questLogCache = {}

        -- Debounce flags for events that burst (multiple fires per frame).
        local _pendingExplorationCheck = false
        local _pendingAuraCheck = false
        local _pendingInventoryCheck = false
        local _pendingFactionCheck = false

        -- Party/pet GUID cache — rebuilt on GROUP_ROSTER_UPDATE/PLAYER_ENTERING_WORLD/UNIT_PET.
        -- Eliminates 20-30 UnitExists/UnitGUID calls per damage event in isPlayerPartyOrPetSource.
        local _cachedPlayerGUID = nil
        local _cachedPartyGUIDs = {}
        local _cachedPetOwnerByGUID = {}

        local function RebuildPartyGUIDCache()
            -- Forever: pet (and sometimes other) GUIDs can be secret and cannot be used as table keys.
            local isSecret = addon and addon.IsSecretValue
            local function plainGUID(unit)
                if not UnitExists(unit) then
                    return nil
                end
                local guid = UnitGUID(unit)
                if not guid or (isSecret and isSecret(guid)) then
                    return nil
                end
                return guid
            end

            _cachedPlayerGUID = plainGUID("player")
            for k in pairs(_cachedPartyGUIDs) do _cachedPartyGUIDs[k] = nil end
            for k in pairs(_cachedPetOwnerByGUID) do _cachedPetOwnerByGUID[k] = nil end
            if _cachedPlayerGUID then _cachedPartyGUIDs[_cachedPlayerGUID] = true end
            local petGUID = plainGUID("pet")
            if petGUID then
                _cachedPetOwnerByGUID[petGUID] = _cachedPlayerGUID
            end
            if GetNumGroupMembers() > 1 then
                for i = 1, 4 do
                    local g = plainGUID("party" .. i)
                    if g then
                        _cachedPartyGUIDs[g] = true
                        local pg = plainGUID("party" .. i .. "pet")
                        if pg then
                            _cachedPetOwnerByGUID[pg] = g
                        end
                    end
                end
            end
        end

        -- Cache recent level-ups to handle event ordering issues with quest turn-ins
        -- Stores the previous level when player levels up, so we can use it if a quest turn-in happens shortly after
        local recentLevelUpCache = nil  -- { previousLevel = number, timestamp = number }
        local LEVEL_UP_WINDOW = 1.0  -- seconds - window to consider a level-up as quest-related

        -- Dedicated support for the Rats achievement: NPC IDs that qualify
        local RAT_NPC_IDS = {
            [4075] = true,
            [13016] = true,
            [2110] = true,
        }
        local achievementRuntimeIndex

        -- Damage events that include overkill information for player attacks
        local DAMAGE_SUBEVENTS = {
            SWING_DAMAGE = true,
            SPELL_DAMAGE = true,
            SPELL_PERIODIC_DAMAGE = true,
            RANGE_DAMAGE = true,
        }

        local _lastGuid = nil
        local _lastNpcId = nil
        local function getNpcIdFromGUID(guid)
            if not guid or (addon.IsSecretValue and addon.IsSecretValue(guid)) then
                return nil
            end
            if guid == _lastGuid then
                return _lastNpcId
            end
            -- ParseCreatureNpcId matches the historical strsplit for plain GUIDs and also accepts the
            -- "Encounter:<npcId>" key Forever uses when a boss kill has no readable GUID.
            local result = addon.ParseCreatureNpcId and addon.ParseCreatureNpcId(guid) or nil
            _lastGuid = guid
            _lastNpcId = result
            return result
        end

        local function getPetOwnerGUID(sourceGUID)
            if not sourceGUID or (addon.IsSecretValue and addon.IsSecretValue(sourceGUID)) then
                return nil
            end
            return _cachedPetOwnerByGUID[sourceGUID]
        end

        local function isPlayerOrPartyMember(guid)
            if not guid or (addon.IsSecretValue and addon.IsSecretValue(guid)) then
                return false
            end
            return _cachedPartyGUIDs[guid] == true
        end
        
        local function isSecretAchievementRow(row)
            if not row then return false end
            if row.isSecretAchievement then return true end
            local d = row._def
            return d and (d.secret or d.isSecret or d.isSecretAchievement) or false
        end

        local function collectTrackedNpcIds(row)
            if not row or type(row.killTracker) ~= "function" then
                return nil
            end
            local def = row._def
            local targetNpcId = def and def.targetNpcId
            local rk = row.requiredKills or (def and def.requiredKills)
            local extra = row.extraCreditKills or (def and def.extraCreditKills)
            -- Completed dungeon rows only stay indexed for optional bonus bosses.
            local includeRequired = not row.completed
            local trackedNpcIds
            local seenNpcIds

            local function addNpcId(value)
                local npcId = tonumber(value)
                if not npcId then
                    return
                end
                if seenNpcIds and seenNpcIds[npcId] then
                    return
                end
                trackedNpcIds = trackedNpcIds or {}
                seenNpcIds = seenNpcIds or {}
                seenNpcIds[npcId] = true
                table_insert(trackedNpcIds, npcId)
            end

            local function addFromKillTable(killTable)
                if type(killTable) ~= "table" then
                    return
                end
                for key, need in pairs(killTable) do
                    -- Any-of groups (e.g. "Ring Of Law") store NPC IDs as the value table.
                    if type(need) == "table" then
                        for _, id in pairs(need) do
                            addNpcId(id)
                        end
                    else
                        addNpcId(key)
                    end
                end
            end

            if includeRequired then
                if type(targetNpcId) == "table" then
                    for _, id in pairs(targetNpcId) do
                        addNpcId(id)
                    end
                else
                    addNpcId(targetNpcId)
                end
                addFromKillTable(rk)
            end

            addFromKillTable(extra)

            return trackedNpcIds
        end

        local function hasRelevantQuestInLog(row)
            local questID = row and (row.requiredQuestId or (row._def and row._def.requiredQuestId))
            if not questID then return true end
            local cached = _questLogCache[questID]
            if cached ~= nil then return cached end
            local getQuestLogState = addon and addon.GetQuestLogState
            local questInLog, questReadyForTurnIn = false, false
            if type(getQuestLogState) == "function" then
                questInLog, questReadyForTurnIn = getQuestLogState(questID)
            end
            local result = questInLog or questReadyForTurnIn or false
            _questLogCache[questID] = result
            return result
        end

        -- Order for dungeon kill print: base first, then Trio, Duo, Solo (so only first eligible variation prints)
        local function dungeonKillPrintOrder(row)
            local def = row._def
            local mapID = def and (def.mapID or def.requiredMapId)
            if not def or not mapID then return 2, 0, 0 end
            local achId = row.achId or row.id or ""
            local order = 0
            if achId:match("_Trio$") then order = 1
            elseif achId:match("_Duo$") then order = 2
            elseif achId:match("_Solo$") then order = 3
            end
            return 1, mapID, order
        end

        local function compareKillRows(a, b)
            local da, ma, oa = dungeonKillPrintOrder(a)
            local db, mb, ob = dungeonKillPrintOrder(b)
            if da ~= db then return da < db end
            if ma ~= mb then return ma < mb end
            return oa < ob
        end

        local function rowHasExtraCreditKills(row)
            if not row then return false end
            local extra = row.extraCreditKills or (row._def and row._def.extraCreditKills)
            return type(extra) == "table" and next(extra) ~= nil
        end

        -- Keep dungeon kill rows registered for CLEU even if IsRowOutleveled mis-fires briefly
        -- (e.g. instance id not ready). KillTracker still enforces entry-level eligibility.
        -- Completed rows stay active only when they still have optional bonus bosses to award.
        local function isRuntimeKillRowActive(row)
            if not row or type(row.killTracker) ~= "function" then
                return false
            end
            if row.completed and not rowHasExtraCreditKills(row) then
                return false
            end
            if not IsRowOutleveled(row) then
                return true
            end
            local def = row._def
            if def and (def.isDungeon or def.isHeroicDungeon) then
                local mapId = def.requiredMapId or def.mapID
                if mapId and addon and addon.IsInDungeon and addon.IsInDungeon(mapId) then
                    return true
                end
            end
            return false
        end
        local function buildAchievementRuntimeIndex()
            local index = {
                killTrackerRowsSorted = {},
                genericKillRowsSorted = {},
                npcIdToKillRows = {},
                npcIdToWarnRows = {},
                npcIdToKillRowsMerged = {},
            }
            local rows = (addon and addon.AchievementRowModel) or {}
            for _, row in ipairs(rows) do
                if type(row.killTracker) == "function" then
                    if not row.completed or rowHasExtraCreditKills(row) then
                        table_insert(index.killTrackerRowsSorted, row)
                    end
                end
            end
            table_sort(index.killTrackerRowsSorted, compareKillRows)

            for sortIndex, row in ipairs(index.killTrackerRowsSorted) do
                row._runtimeKillSortIndex = sortIndex
                local trackedNpcIds = collectTrackedNpcIds(row)
                if trackedNpcIds and #trackedNpcIds > 0 then
                    for _, trackedNpcId in ipairs(trackedNpcIds) do
                        local killBucket = index.npcIdToKillRows[trackedNpcId]
                        if not killBucket then
                            killBucket = {}
                            index.npcIdToKillRows[trackedNpcId] = killBucket
                        end
                        table_insert(killBucket, row)

                        if not isSecretAchievementRow(row) then
                            local warnBucket = index.npcIdToWarnRows[trackedNpcId]
                            if not warnBucket then
                                warnBucket = {}
                                index.npcIdToWarnRows[trackedNpcId] = warnBucket
                            end
                            table_insert(warnBucket, row)
                        end
                    end
                else
                    table_insert(index.genericKillRowsSorted, row)
                end
            end

            -- Pre-merge npcId-specific rows with generic rows using a two-pointer merge.
            -- Both sources are already sorted by _runtimeKillSortIndex, so we can merge in O(n)
            -- instead of re-sorting at call time on every kill event.
            local generic = index.genericKillRowsSorted
            for npcId, specific in pairs(index.npcIdToKillRows) do
                local merged = {}
                local si, gi = 1, 1
                local sn, gn = #specific, #generic
                while si <= sn and gi <= gn do
                    if (specific[si]._runtimeKillSortIndex or 0) <= (generic[gi]._runtimeKillSortIndex or 0) then
                        table_insert(merged, specific[si])
                        si = si + 1
                    else
                        table_insert(merged, generic[gi])
                        gi = gi + 1
                    end
                end
                while si <= sn do
                    table_insert(merged, specific[si])
                    si = si + 1
                end
                while gi <= gn do
                    table_insert(merged, generic[gi])
                    gi = gi + 1
                end
                index.npcIdToKillRowsMerged[npcId] = merged
            end

            return index
        end
        local function InvalidateAchievementRuntimeIndex()
            achievementRuntimeIndex = nil
            -- Proactively rebuild on the next frame so the index is ready before the next kill
            -- event. Without this, the first CLEU after any quest/level/zone change blocks while
            -- buildAchievementRuntimeIndex() runs synchronously (O(n) + sort + merge passes).
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not achievementRuntimeIndex then
                        achievementRuntimeIndex = buildAchievementRuntimeIndex()
                    end
                end)
            end
        end
        if addon then
            addon.InvalidateAchievementRuntimeIndex = InvalidateAchievementRuntimeIndex
        end

        local function EnsureAchievementRuntimeIndex()
            if not achievementRuntimeIndex then
                achievementRuntimeIndex = buildAchievementRuntimeIndex()
            end
            return achievementRuntimeIndex
        end
        if addon then
            addon.EnsureAchievementRuntimeIndex = EnsureAchievementRuntimeIndex
        end

        local function rowsContainActiveCandidates(rows)
            if not rows then
                return false
            end
            for _, row in ipairs(rows) do
                if isRuntimeKillRowActive(row) then
                    return true
                end
            end
            return false
        end

        local function rowsContainActiveTapWarning(rows)
            if not rows then
                return false
            end
            for _, row in ipairs(rows) do
                if isRuntimeKillRowActive(row) and hasRelevantQuestInLog(row) then
                    return true
                end
            end
            return false
        end

        -- Returns whether this NPC should participate in kill/tap-denied handling and whether
        -- a tap-denied warning line should be shown for it.
        local function npcKillTrackContext(npcId)
            if not npcId then
                return false, false
            end
            npcId = (addon.CanonicalNpcId and addon.CanonicalNpcId(npcId)) or tonumber(npcId) or npcId
            local runtimeIndex = EnsureAchievementRuntimeIndex and EnsureAchievementRuntimeIndex()
            local trackedRows = runtimeIndex and runtimeIndex.npcIdToKillRows[npcId]
            local warnRows = runtimeIndex and runtimeIndex.npcIdToWarnRows[npcId]
            local tracked = RAT_NPC_IDS[npcId] or rowsContainActiveCandidates(trackedRows)
            local warnTapDenied = rowsContainActiveTapWarning(warnRows)
            return tracked, warnTapDenied
        end

        local function isNpcTrackedForAchievement(npcId)
            local tracked = npcKillTrackContext(npcId)
            return tracked
        end
        addon.IsNpcTrackedForAchievement = isNpcTrackedForAchievement

        -- Module-level table reused across calls to avoid per-call allocation and GC pressure.
        -- Safe because callers iterate the result synchronously before the next CLEU event fires.
        local _killCandidates = {}

        local function collectKillCandidatesForNpc(npcId)
            local runtimeIndex = EnsureAchievementRuntimeIndex and EnsureAchievementRuntimeIndex()
            -- Clear without allocating a new table
            for i = #_killCandidates, 1, -1 do _killCandidates[i] = nil end

            if runtimeIndex then
                -- Use the pre-merged+sorted list built at index time (eliminates runtime table.sort).
                -- Falls back to genericKillRowsSorted for NPCs with no specific rows.
                local source = runtimeIndex.npcIdToKillRowsMerged[npcId] or runtimeIndex.genericKillRowsSorted
                if source then
                    for _, row in ipairs(source) do
                        if isRuntimeKillRowActive(row) then
                            table_insert(_killCandidates, row)
                        end
                    end
                end
            end

            return _killCandidates
        end

        -- Cleanup old external player tracking entries
        local function cleanupExternalPlayers()
            local now = GetTime()
            for destGUID, players in pairs(externalPlayersByNPC) do
                local anyValid = false
                for playerGUID, data in pairs(players) do
                    if now - data.lastSeen > EXTERNAL_PLAYER_TIMEOUT then
                        players[playerGUID] = nil
                    else
                        anyValid = true
                    end
                end
                if not anyValid then
                    externalPlayersByNPC[destGUID] = nil
                end
            end
        end
        
        -- Core threat sampling logic shared by throttled and forced variants.
        local function doThreatSample(destGUID)
            if not UnitExists("target") or UnitGUID("target") ~= destGUID then
                return
            end
            
            local targetUnit = "target"
            if not UnitCanAttack("player", targetUnit) then
                return
            end
            
            local now = GetTime()
            for playerGUID, data in pairs(externalPlayersByNPC[destGUID]) do
                -- Try to get unit token for this player
                local unitToken = UnitTokenFromGUID(playerGUID)
                if unitToken and UnitExists(unitToken) then
                    -- Check threat for this external player
                    local isTanking, status, scaledPct, rawPct = UnitDetailedThreatSituation(unitToken, targetUnit)
                    if isTanking and status and status >= 2 then
                        -- Tanking (status >= 2) means they're the primary target - definitely high threat
                        data.threat = 100
                        data.isTanking = true
                    elseif scaledPct then
                        data.threat = scaledPct
                        data.isTanking = false
                    elseif rawPct then
                        data.threat = rawPct
                        data.isTanking = false
                    else
                        data.threat = 0
                        data.isTanking = false
                    end
                    data.lastSeen = now
                end
            end
        end

        -- Throttled variant: called on every damage event (SWING/SPELL/RANGE_DAMAGE).
        -- Skips sampling if the same NPC was checked within the last 0.5 seconds.
        local function updateExternalPlayerThreat(destGUID)
            if not externalPlayersByNPC[destGUID] then
                return
            end
            local now = GetTime()
            if now - (_threatCheckTime[destGUID] or 0) < 0.5 then
                return
            end
            _threatCheckTime[destGUID] = now
            doThreatSample(destGUID)
        end

        -- Unthrottled variant: called immediately before processing a kill (overkill path)
        -- to ensure the freshest threat data is available for solo-kill determination.
        local function updateExternalPlayerThreatForce(destGUID)
            if not externalPlayersByNPC[destGUID] then
                return
            end
            _threatCheckTime[destGUID] = GetTime()
            doThreatSample(destGUID)
        end

        local function clearCombatTrackingForGUID(destGUID)
            if not destGUID then return end
            npcsInCombat[destGUID] = nil
            npcTapDenied[destGUID] = nil
            _threatCheckTime[destGUID] = nil
            _soloUpdateThrottle[destGUID] = nil
        end

        local function isPlayerPartyOrPetSource(sourceGUID)
            if not sourceGUID or (addon.IsSecretValue and addon.IsSecretValue(sourceGUID)) then
                return false
            end
            return _cachedPartyGUIDs[sourceGUID] == true
                or _cachedPetOwnerByGUID[sourceGUID] ~= nil
        end

        local function isExternalPlayerSource(sourceGUID)
            -- sub(1,7) prefix check avoids strsplit allocation on every damage event.
            return sourceGUID ~= nil
                and sourceGUID:sub(1, 7) == "Player-"
                and not isPlayerOrPartyMember(sourceGUID)
        end

        local function trackExternalPlayerForNpc(destGUID, sourceGUID)
            local now = GetTime()
            if not externalPlayersByNPC[destGUID] then
                externalPlayersByNPC[destGUID] = {}
            end

            local playerData = externalPlayersByNPC[destGUID][sourceGUID]
            if not playerData then
                playerData = { lastSeen = now, threat = nil }
                externalPlayersByNPC[destGUID][sourceGUID] = playerData
            else
                playerData.lastSeen = now
            end

            if npcsInCombat[destGUID] then
                updateExternalPlayerThreat(destGUID)
            end
        end

        local function updateSoloStatusForTrackedNpc(destGUID, sourceGUID)
            if not destGUID then return end
            -- Source check first: GUID comparison is cheaper than getNpcIdFromGUID + isNpcTrackedForAchievement.
            -- NPC-vs-NPC events (the majority in busy zones) exit here with no index lookups.
            local isPlayerDamage = sourceGUID == _cachedPlayerGUID
            local isExternalPlayerDamage = not isPlayerDamage and isExternalPlayerSource(sourceGUID)
            if not (isPlayerDamage or isExternalPlayerDamage) then return end

            local npcId = getNpcIdFromGUID(destGUID)
            local npcTracked = npcId and isNpcTrackedForAchievement(npcId)
            if not npcTracked then return end

            local now = GetTime()
            if now - (_soloUpdateThrottle[destGUID] or 0) < 0.25 then return end
            _soloUpdateThrottle[destGUID] = now

            if not UnitAffectingCombat("player") then return end
            if UnitExists("target") and UnitGUID("target") == destGUID then
                if isExternalPlayerDamage then
                    updateExternalPlayerThreat(destGUID)
                end
                PlayerIsSolo_UpdateStatusForGUID(destGUID)
            end
        end

        -- Heavy award logic deferred to the next frame to keep the CLEU handler lean.
        -- Called via C_Timer.After(0) with a snapshot of the data needed at kill time.
        local function awardKill(destGUID, npcId)
            -- If another path already awarded this kill in the same frame, bail out.
            if recentKills[destGUID] == true then
                return
            end

            local rowsWithTracker = collectKillCandidatesForNpc(npcId)
            if not rowsWithTracker or #rowsWithTracker == 0 then
                externalPlayersByNPC[destGUID] = nil
                -- Reset pending sentinel so UNIT_DIED or other paths can retry if needed.
                if recentKills[destGUID] == "pending" then
                    recentKills[destGUID] = nil
                end
                return
            end

            local anyAwarded = false
            for _, row in ipairs(rowsWithTracker) do
                if row.killTracker(destGUID, npcId) then
                    MarkRowCompleted(row)
                    local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                    local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                    CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                    anyAwarded = true
                end
            end

            if anyAwarded then
                recentKills[destGUID] = true
                clearRecentKill(destGUID)
            else
                -- No credit given; reset pending so UNIT_DIED can retry.
                if recentKills[destGUID] == "pending" then
                    recentKills[destGUID] = nil
                end
            end

            -- Clean up external player tracking for this NPC after kill attempt.
            externalPlayersByNPC[destGUID] = nil
        end

        local function processKill(destGUID, npcId)
            if not destGUID or (addon.IsSecretValue and addon.IsSecretValue(destGUID)) or recentKills[destGUID] then
                return
            end

            if npcId and addon.CanonicalNpcId then
                npcId = addon.CanonicalNpcId(npcId) or npcId
            end

            local isEncounter = type(destGUID) == "string" and destGUID:sub(1, 10) == "Encounter:"
            local now = GetTime()
            if not isEncounter and npcId and achEvt.encounterClaimedAt[npcId]
                and (now - achEvt.encounterClaimedAt[npcId]) < 10 then
                return
            end
            if not isEncounter and npcId then
                achEvt.guidClaimedAt[npcId] = now
            end

            -- Capture solo status synchronously while game state is current
            -- (critical for one-shot kills with no prior damage event).
            if PlayerIsSolo_UpdateStatusForGUID then
                PlayerIsSolo_UpdateStatusForGUID(destGUID)
            end

            -- Mark as pending immediately to block duplicate events in the same frame
            -- before the deferred awardKill runs. "pending" is truthy so the guard above blocks re-entry.
            recentKills[destGUID] = "pending"

            C_Timer.After(0, function()
                awardKill(destGUID, npcId)
            end)
        end
        
        -- Define and expose for IsGroupEligibleForAchievement and other callers
        local function GetExternalPlayersForNPC(destGUID)
            if not destGUID then
                return {}
            end
            cleanupExternalPlayers()
            if UnitExists("target") and UnitGUID("target") == destGUID and UnitCanAttack("player", "target") then
                updateExternalPlayerThreatForce(destGUID)
            end
            return externalPlayersByNPC[destGUID] or {}
        end
        if addon then
            addon.GetExternalPlayersForNPC = GetExternalPlayersForNPC
        end
        
        -- Entry point for clients that cannot register COMBAT_LOG_EVENT_UNFILTERED (Forever). The caller
        -- decides credit itself. The rare/quest-loot hook is the caller's job: PARTY_KILL runs it for
        -- every creature, while the UNIT_DIED fallback must not. See Forever\KillTracking.lua.
        if addon then
            addon.AwardKillFromExternalSource = function(destGUID, npcIdHint)
                if type(destGUID) ~= "string" or (addon.IsSecretValue and addon.IsSecretValue(destGUID)) then
                    return false
                end
                if destGUID:sub(1, 9) ~= "Creature-" then
                    return false
                end

                local npcId = tonumber(npcIdHint) or getNpcIdFromGUID(destGUID)
                if not npcId then
                    return false
                end
                if addon.CanonicalNpcId then
                    npcId = addon.CanonicalNpcId(npcId) or npcId
                end

                processKill(destGUID, npcId)
                clearCombatTrackingForGUID(destGUID)
                return true
            end

            -- Boss credit from ENCOUNTER_END, which identifies the creature without a GUID. The dungeon
            -- kill tracker still applies the player's level, party size, and average-party-level snapshot.
            addon.AwardKillFromEncounter = function(_, creatureID)
                creatureID = tonumber(creatureID)
                if not creatureID then
                    return false
                end
                if addon.CanonicalNpcId then
                    creatureID = addon.CanonicalNpcId(creatureID) or creatureID
                end
                local now = GetTime()
                if achEvt.guidClaimedAt[creatureID] and (now - achEvt.guidClaimedAt[creatureID]) < 10 then
                    return false
                end
                achEvt.encounterClaimedAt[creatureID] = now
                processKill("Encounter:" .. creatureID, creatureID)
                return true
            end
        end

        achEvt:RegisterEvent("GROUP_ROSTER_UPDATE")
        achEvt:RegisterEvent("UNIT_PET")
        -- Forever forbids this for insecure addons, and asking anyway reports ADDON_ACTION_FORBIDDEN.
        -- Restrictions.combatLog is the capability flag; IsForeverClient is the product identity.
        if not (addon.Restrictions and addon.Restrictions.combatLog) then
            achEvt:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
        achEvt:RegisterEvent("BOSS_KILL")
        achEvt:RegisterEvent("QUEST_ACCEPTED")
        achEvt:RegisterEvent("QUEST_TURNED_IN")
        achEvt:RegisterEvent("QUEST_REMOVED")
        achEvt:RegisterEvent("UNIT_SPELLCAST_SENT")
        achEvt:RegisterEvent("UNIT_SPELLCAST_START")
        achEvt:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        achEvt:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        achEvt:RegisterEvent("UNIT_SPELLCAST_FAILED")
        achEvt:RegisterEvent("UNIT_INVENTORY_CHANGED")
        achEvt:RegisterEvent("ITEM_LOCKED")
        achEvt:RegisterEvent("DELETE_ITEM_CONFIRM")
        achEvt:RegisterEvent("ITEM_UNLOCKED")
        achEvt:RegisterEvent("BAG_UPDATE_DELAYED")
        achEvt:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
        achEvt:RegisterEvent("GOSSIP_SHOW")
        achEvt:RegisterEvent("PLAYER_LEVEL_CHANGED")
        achEvt:RegisterEvent("CHAT_MSG_LOOT")
        achEvt:RegisterEvent("PLAYER_DEAD")
        achEvt:RegisterEvent("PLAYER_REGEN_ENABLED")
        achEvt:RegisterEvent("PLAYER_ENTERING_WORLD")
        achEvt:RegisterEvent("UPDATE_FACTION")
        achEvt:RegisterEvent("UNIT_AURA")
        achEvt:RegisterEvent("MAP_EXPLORATION_UPDATED")
        local function HandleAchievementEvent(_, event, ...)
            -- Clean up external player tracking on zone loads
            if event == "PLAYER_ENTERING_WORLD" then
                externalPlayersByNPC = {}
                npcsInCombat = {}
                npcTapDenied = {}
                _threatCheckTime = {}
                _soloUpdateThrottle = {}
                for k in pairs(_questLogCache) do _questLogCache[k] = nil end
                RebuildPartyGUIDCache()
                InvalidateOutleveledCache()
                if InvalidateAchievementRuntimeIndex then
                    InvalidateAchievementRuntimeIndex()
                end
                return
            end
            -- Handle BOSS_KILL event for raid achievements (fires regardless of who delivered final blow)
            if event == "BOSS_KILL" then
                local encounterID, encounterName = ...
                local rows = addon.AchievementRowModel
                if encounterID and rows then
                    -- Process boss kill for all raid achievements that have processBossKillByEncounterID function
                    for _, row in ipairs(rows) do
                        if not row.completed and type(row.processBossKillByEncounterID) == "function" then
                            local shouldComplete = row.processBossKillByEncounterID(encounterID)
                            -- If the function indicates completion, mark the achievement as complete
                            if shouldComplete then
                                MarkRowCompleted(row)
                                local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                            end
                        end
                    end
                end
                return
            end
            -- Clean up combat tracking when combat ends
            if event == "PLAYER_REGEN_ENABLED" then
                -- Clear combat tracking after a short delay (in case we're still processing events)
                C_Timer.After(2, function()
                    -- Only clear if we're not in combat anymore
                    if not UnitAffectingCombat("player") then
                        npcsInCombat = {}
                        npcTapDenied = {}
                        if InvalidateAchievementRuntimeIndex then
                            InvalidateAchievementRuntimeIndex()
                        end
                        -- Clean up old external player tracking (keep recent ones for a bit longer)
                        cleanupExternalPlayers()
                    end
                end)
            elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
                RebuildPartyGUIDCache()
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                -- PlayerIsSolo external-helper tracking runs here (single CLEU frame instead of two).
                if PlayerIsSolo_OnCombatLogEvent then
                    PlayerIsSolo_OnCombatLogEvent()
                end
                -- Multi-return avoids allocating a table on every CLEU event (fires hundreds/sec in AoE).
                local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, param12, param13, param14, param15, param16 = CombatLogGetCurrentEventInfo()
                
                if subevent == "PARTY_KILL" then
                    -- Routed here instead of its own CLEU frame; must run before the tap-denial
                    -- and instance gates below, which can return early.
                    local onRareQuestLootKill = addon and addon.FirstKillRareQuestLoot_OnPartyKill
                    if onRareQuestLootKill and destGUID then
                        onRareQuestLootKill(destGUID)
                    end
                    -- PARTY_KILL fires when the player/party gets credit for a kill.
                    -- In dungeon/raid: only the group is present, so we always process (interchangeable with UNIT_DIED).
                    -- In open world: require npcsInCombat and check tap denial so we don't credit kills we didn't tag.
                    local instanceName, instanceType = GetInstanceInfo()
                    local inInstance = (instanceType == "party" or instanceType == "raid")
                    local isTapDenied = npcTapDenied[destGUID]
                    if isTapDenied == true and not inInstance then
                        return
                    end
                    if inInstance and destGUID then
                        -- Instance: process party kill if it's a tracked creature (same filter as UNIT_DIED)
                        if destGUID:sub(1, 9) == "Creature-" then
                            local npcId = getNpcIdFromGUID(destGUID)
                            if npcId and isNpcTrackedForAchievement(npcId) then
                                processKill(destGUID, npcId)
                                clearCombatTrackingForGUID(destGUID)
                            end
                        end
                    elseif npcsInCombat[destGUID] then
                        -- Open world: only if we were fighting this NPC
                        local owId = getNpcIdFromGUID(destGUID)
                        processKill(destGUID, owId)
                        clearCombatTrackingForGUID(destGUID)
                    end
                elseif subevent == "UNIT_DIED" then
                    -- UNIT_DIED always fires when something dies. In dungeon/raid use it as primary/fallback
                    -- when PARTY_KILL doesn't fire (e.g. environment/totem/pet/mechanic got the kill).
                    -- Only process in instance so we don't credit world kills we had no part in.
                    local instanceName, instanceType = GetInstanceInfo()
                    if instanceType == "party" or instanceType == "raid" then
                        if destGUID then
                            if destGUID:sub(1, 9) == "Creature-" then
                                local npcId = getNpcIdFromGUID(destGUID)
                                if npcId and isNpcTrackedForAchievement(npcId) then
                                    processKill(destGUID, npcId)
                                    clearCombatTrackingForGUID(destGUID)
                                end
                            end
                        end
                    end
                elseif DAMAGE_SUBEVENTS[subevent] then
                    local shouldProcess = isPlayerPartyOrPetSource(sourceGUID)
                    
                    if shouldProcess and destGUID then
                        -- Player/party member/pet damage - track that we're fighting this NPC
                        local npcId = getNpcIdFromGUID(destGUID)
                        local npcTracked, npcTapDeniedWarn = npcKillTrackContext(npcId)
                        if npcTracked then
                            -- Use cached tap denial when known; only query the API on the first hit.
                            local isTapDenied = npcTapDenied[destGUID]
                            if isTapDenied == nil then
                                isTapDenied = checkAndStoreTapDenied(destGUID)
                            end
                            if isTapDenied == true then
                                npcsInCombat[destGUID] = nil
                                npcTapDenied[destGUID] = true
                            else
                                npcsInCombat[destGUID] = true
                                updateExternalPlayerThreat(destGUID)
                            end
                        end
                        
                        -- If overkill is present (>= 0), the target died from this damage
                        -- This catches kills that don't trigger PARTY_KILL (e.g., pet kills, DoT kills)
                        local overkill = subevent == "SWING_DAMAGE" and param13 or param16
                        if overkill and overkill >= 0 then
                            -- Force-update threat immediately before processing the kill to guarantee
                            -- the freshest data is used for solo-kill eligibility, bypassing the throttle.
                            if npcsInCombat[destGUID] then
                                updateExternalPlayerThreatForce(destGUID)
                            end
                            
                            -- Check if player tagged the enemy (prevents credit for killing untagged mobs when awardOnKill is enabled)
                            -- Use stored tap denial status (NPC is cleared from target when it dies, so we can't check at kill time)
                            local isTapDenied = npcTapDenied[destGUID]
                            if isTapDenied == true then
                                if npcTapDeniedWarn then
                                    print("|cff008066[Hardcore Achievements]|r |cffffd100Achievement cannot be fulfilled: Unit was not your tag.|r")
                                end
                                if addon.EventLogAdd then
                                    addon.EventLogAdd("Kill processing skipped (tap denied / not your tag) for GUID " .. tostring(destGUID))
                                end
                                -- Clean up combat tracking
                                clearCombatTrackingForGUID(destGUID)
                                return
                            end
                            
                            if npcTracked then
                                processKill(destGUID, npcId)
                                clearCombatTrackingForGUID(destGUID)
                            end
                        end
                    elseif not shouldProcess and destGUID then
                        -- This is damage from a non-player, non-party source (or external player)
                        local npcId = getNpcIdFromGUID(destGUID)
                        
                        -- Check if source is an external player (not in our party)
                        local isExternalPlayer = isExternalPlayerSource(sourceGUID)
                        
                        -- Track external players fighting tracked NPCs
                        if isExternalPlayer and npcId and isNpcTrackedForAchievement(npcId) then
                            trackExternalPlayerForNpc(destGUID, sourceGUID)
                        end
                        
                        -- Check if this is a kill by a non-party player
                        -- Only process if the player was fighting this NPC
                        if not npcsInCombat[destGUID] then
                            -- Player wasn't fighting this NPC, ignore the kill
                            -- (This prevents tracking kills the player had no part in)
                        else
                            -- If overkill is present (>= 0), the target died from this damage
                            local overkill = subevent == "SWING_DAMAGE" and param13 or param16
                            if overkill and overkill >= 0 then
                                if isExternalPlayer and npcId then
                                    local isTracked = isNpcTrackedForAchievement(npcId)
                                    
                                    if isTracked then
                                        -- A non-party player got the kill while we were fighting this NPC
                                        -- Process the kill - the killTracker will check eligibility
                                        -- PlayerIsSolo tracks if non-party players helped (via threat)
                                        -- If they helped significantly (>10% threat), it will mark as ineligible
                                        processKill(destGUID, npcId)
                                        
                                        -- Clean up combat tracking
                                        clearCombatTrackingForGUID(destGUID)
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Track threat/solo status during combat for tracked NPCs
                    -- This ensures we have solo status available when PARTY_KILL fires.
                    updateSoloStatusForTrackedNpc(destGUID, sourceGUID)
                end
            elseif event == "QUEST_ACCEPTED" then
                for k in pairs(_questLogCache) do _questLogCache[k] = nil end
                if InvalidateAchievementRuntimeIndex then
                    InvalidateAchievementRuntimeIndex()
                end
                -- Classic: (questLogIndex, questID). Retail/Forever: (questID) only.
                local arg1, arg2 = ...
                local questID = tonumber(arg2) or tonumber(arg1)
                if questID and addon and addon.SetProgress then
                    -- Store player's level when quest is accepted as a backup reference
                    -- This helps prevent achievements from failing if player levels up between accepting and turning in
                    local acceptLevel = UnitLevel("player") or 1
                    for _, row in ipairs(addon.AchievementRowModel or {}) do
                        if not row.completed then
                            -- Check if this achievement tracks this quest by comparing questID directly
                            -- Don't call questTracker as it processes the quest and can complete the achievement
                            local rowQuestId = row.requiredQuestId
                            if rowQuestId and tonumber(rowQuestId) == questID then
                                -- Store levelAtAccept as a backup (will be overwritten by levelAtKill or levelAtTurnIn on fulfillment)
                                addon.SetProgress(row.id, "levelAtAccept", acceptLevel)
                            end
                        end
                    end
                end
            elseif event == "QUEST_TURNED_IN" then
                for k in pairs(_questLogCache) do _questLogCache[k] = nil end
                InvalidateOutleveledCache()
                if InvalidateAchievementRuntimeIndex then
                    InvalidateAchievementRuntimeIndex()
                end
                local arg1 = ...
                local questID = arg1 and tonumber(arg1) or nil
                local currentTime = GetTime()
                
                for _, row in ipairs(addon.AchievementRowModel or {}) do
                    if not row.completed and type(row.questTracker) == "function" then
                        -- First check if the quest matches this achievement
                        local questMatched = row.questTracker(questID)
                        
                        -- Only set levelAtTurnIn if the quest actually matches this achievement
                        if questMatched then
                            -- Check if player just leveled up within the window - if so, use the previous level
                            if addon and addon.SetProgress then
                                local progressTable = addon.GetProgress and addon.GetProgress(row.id)
                                -- Only set levelAtTurnIn if we don't already have levelAtKill (for achievements without kill requirements)
                                if not (progressTable and progressTable.levelAtKill) then
                                    local currentLevel = UnitLevel("player") or 1
                                    local levelToStore = currentLevel
                                    
                                    -- Check if there was a recent level-up within the time window
                                    if recentLevelUpCache and (currentTime - recentLevelUpCache.timestamp) <= LEVEL_UP_WINDOW then
                                        -- Player leveled up recently - use the previous level as the "true" turn-in level
                                        -- This handles the case where the quest XP causes the level-up
                                        levelToStore = recentLevelUpCache.previousLevel
                                    else
                                        -- No recent level-up, or it was outside the window - check if levelAtAccept might be better
                                        -- Only use levelAtAccept if current level matches (player hasn't leveled since accept)
                                        local levelAtAccept = progressTable and progressTable.levelAtAccept
                                        if levelAtAccept and currentLevel == levelAtAccept then
                                            levelToStore = levelAtAccept
                                        end
                                    end
                                    
                                    addon.SetProgress(row.id, "levelAtTurnIn", levelToStore)
                                end
                            end
                            
                            MarkRowCompleted(row)
                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                        end
                    end
                end
                
                -- Clear the level-up cache after processing quest turn-in
                recentLevelUpCache = nil
            elseif event == "UNIT_SPELLCAST_SENT"
                or event == "UNIT_SPELLCAST_START"
                or event == "UNIT_SPELLCAST_SUCCEEDED"
                or event == "UNIT_SPELLCAST_INTERRUPTED"
                or event == "UNIT_SPELLCAST_FAILED" then
                -- SENT: unit, targetName, castGUID, spellId
                -- START / SUCCEEDED / INTERRUPTED / FAILED: unit, castGUID, spellId
                local unit, a2, a3, a4 = ...
                if unit ~= "player" then return end

                local spellId, targetName, castGUID, phase
                if event == "UNIT_SPELLCAST_SENT" then
                    targetName, castGUID, spellId, phase = a2, a3, a4, "sent"
                else
                    castGUID, spellId = a2, a3
                    targetName = ""
                    if event == "UNIT_SPELLCAST_START" then
                        phase = "start"
                    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                        phase = "succeeded"
                    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
                        phase = "interrupted"
                    else
                        phase = "failed"
                    end
                end

                spellId = tonumber(spellId)
                -- snowball, noggenfogger, hearthstone
                if spellId ~= 21343 and spellId ~= 16589 and spellId ~= 8690 then return end

                for _, row in ipairs(addon.AchievementRowModel or {}) do
                    if not IsAchievementAlreadyCompleted(row) and type(row.spellTracker) == "function" then
                        local ok, shouldComplete = pcall(row.spellTracker, spellId, tostring(targetName or ""), phase, castGUID)
                        if ok and shouldComplete == true then
                            MarkRowCompleted(row)
                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                        end
                    end
                end
            elseif event == "UNIT_AURA" then
                local unit = ...
                if unit ~= "player" then return end
                -- Debounce: UNIT_AURA can fire many times per frame on zone entry (buffs, mounts, env auras).
                -- Defer to next frame so all rapid-fire aura changes are collapsed into one evaluation.
                if not _pendingAuraCheck then
                    _pendingAuraCheck = true
                    C_Timer.After(0, function()
                        _pendingAuraCheck = false
                        for _, row in ipairs(addon.AchievementRowModel or {}) do
                            if not IsAchievementAlreadyCompleted(row) and type(row.auraTracker) == "function" then
                                local ok, shouldComplete = pcall(row.auraTracker)
                                if ok and shouldComplete == true then
                                    MarkRowCompleted(row)
                                    local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                    local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                    CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                                    break
                                end
                            end
                        end
                    end)
                end
            elseif event == "UNIT_INVENTORY_CHANGED" then
                local unit = ...
                if unit ~= "player" then return end

                -- Debounce: equipping a set fires this once per slot, and each pass scans every
                -- row and pcalls a tracker per dungeon-set row. Collapse a burst into one pass.
                if not _pendingInventoryCheck then
                    _pendingInventoryCheck = true
                    C_Timer.After(0, function()
                        _pendingInventoryCheck = false

                        -- Single pass: evaluate DefiasMask (Rogue only) and dungeon set achievements together.
                        local _, classFile = UnitClass("player")
                        local isRogue = (classFile == "ROGUE")
                        local headSlotItemId = isRogue and GetInventoryItemID("player", 1) or nil

                        for _, row in ipairs(addon.AchievementRowModel or {}) do
                            if not IsAchievementAlreadyCompleted(row) then
                                -- DefiasMask: Rogue wearing the head item
                                if isRogue and headSlotItemId == 7997 and (row.id == "DefiasMask" or row.achId == "DefiasMask") then
                                    MarkRowCompleted(row)
                                    local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                    local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                    CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                                end
                                -- Dungeon set achievements (tracker checks all required items internally)
                                if row._def and row._def.isDungeonSet then
                                    local achId = row.achId or row.id
                                    if achId then
                                        local trackerFn = (addon and addon.GetAchievementFunction and addon.GetAchievementFunction(achId, "IsCompleted")) or (addon and addon[achId])
                                        if type(trackerFn) == "function" then
                                            local ok, shouldComplete = pcall(trackerFn)
                                            if ok and shouldComplete == true then
                                                MarkRowCompleted(row)
                                                local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                                local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                                CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            elseif event == "ITEM_LOCKED" then
                -- Track item delete flow for "Precious"
                -- We only arm the state if the player is holding the ring on the cursor in Blackrock Mountain.
                local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                local cursorType, itemId = GetCursorInfo()
                if mapId == 1415 and cursorType == "item" and tonumber(itemId) == 8350 then
                    -- Store the current item count before deletion
                    local initialCount = GetItemCount and GetItemCount(8350, true) or 0
                    addon.Precious_DeleteState = {
                        armed = true,
                        mapId = mapId,
                        itemId = 8350,
                        initialItemCount = tonumber(initialCount) or 0,
                        deleteConfirmed = false,
                        awaitingBagUpdate = false,
                    }
                end
            elseif event == "DELETE_ITEM_CONFIRM" then
                -- This fires when the delete confirmation dialog is shown/confirmed
                local st = addon.Precious_DeleteState
                if st and st.armed and st.itemId == 8350 and st.mapId == 1415 then
                    -- Require the player still be in Blackrock Mountain when the delete prompt occurs
                    local currentMapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                    if currentMapId == 1415 then
                        st.deleteConfirmed = true
                    end
                end
            elseif event == "ITEM_UNLOCKED" then
                local st = addon.Precious_DeleteState
                if st and st.armed and st.itemId == 8350 and st.mapId == 1415 then
                    if st.deleteConfirmed then
                        st.awaitingBagUpdate = true
                    else
                        addon.Precious_DeleteState = nil
                    end
                end
            elseif event == "BAG_UPDATE_DELAYED" then
                local st = addon.Precious_DeleteState
                if st and st.armed and st.awaitingBagUpdate and st.deleteConfirmed and st.itemId == 8350 and st.mapId == 1415 then
                    local currentMapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                    local itemCount = GetItemCount and GetItemCount(8350, true) or 0
                    local newCount = tonumber(itemCount) or 0
                    local expectedCount = (st.initialItemCount or 0) - 1
                    if currentMapId == 1415 and newCount == expectedCount then
                        -- Keep the completion flag for the customIsCompleted function.
                        addon.Precious_RingDeleted = true

                        -- Manually complete the row immediately.
                        for _, row in ipairs(addon.AchievementRowModel or {}) do
                            local id = row and (row.id or row.achId)
                            -- Check both row.completed and database to prevent re-completion
                            if row and not IsAchievementAlreadyCompleted(row) and id == "Precious" then
                                MarkRowCompleted(row)
                                local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                                
                                -- Send SAY channel message to notify nearby players for Fellowship achievement
                                local SendPreciousCompletionMessage = (addon and addon.SendPreciousCompletionMessage)
                                if SendPreciousCompletionMessage then
                                    SendPreciousCompletionMessage()
                                end
                                break
                            end
                        end
                    end
                    -- Clear state after the first bag update following unlock, regardless of outcome.
                    addon.Precious_DeleteState = nil
                end
                local currentLevel = UnitLevel("player") or 1
                for _, row in ipairs(addon.AchievementRowModel or {}) do
                    -- Check both row.completed and database to prevent re-completion
                    if not IsAchievementAlreadyCompleted(row) and type(row.itemTracker) == "function" then
                        local ok, shouldComplete = pcall(row.itemTracker, currentLevel)
                        if ok and shouldComplete == true then
                            MarkRowCompleted(row)
                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                            break -- Achievement completed, no need to check others
                        end
                    end
                end
            elseif event == "CHAT_MSG_TEXT_EMOTE" then
                local msg, unit = ...
                if unit ~= UnitName("player") then return end
                for _, row in ipairs(addon.AchievementRowModel or {}) do
                    -- Check both row.completed and database to prevent re-completion
                    if not IsAchievementAlreadyCompleted(row) and type(row.chatTracker) == "function" then
                        local ok, shouldComplete = pcall(row.chatTracker, tostring(msg or ""))
                        if ok and shouldComplete == true then
                            MarkRowCompleted(row)
                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                        end
                    end
                end
            elseif event == "GOSSIP_SHOW" then
                -- Check for "MessageToKarazhan" achievement when speaking to Archmage Leryda
                local npcName = UnitName("npc")
                local playerLevel = UnitLevel("player")
                -- Forever: NPC names can be secret on restricted maps; comparing them errors.
                if npcName and not (addon.IsSecretValue and addon.IsSecretValue(npcName))
                    and npcName == "Archmage Leryda" and playerLevel <= 60 then
                    for _, row in ipairs(addon.AchievementRowModel or {}) do
                        local id = row and (row.id or row.achId)
                        if row and (not row.completed) and id == "MessageToKarazhan" then
                            -- Check if the zone is fully discovered and speaking to the correct NPC
                            if addon and addon.CheckZoneDiscovery and addon.CheckZoneDiscovery(1430) then
                                MarkRowCompleted(row)
                                local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                                break
                            end
                        end
                    end
                end
            elseif event == "PLAYER_LEVEL_CHANGED" then
                InvalidateOutleveledCache()
                if InvalidateAchievementRuntimeIndex then
                    InvalidateAchievementRuntimeIndex()
                end
                -- arg1 is previous level, arg2 is new level
                local prevArg, newArg = ...
                local previousLevel = tonumber(tostring(prevArg))
                local newLevel = tonumber(tostring(newArg))
                
                -- Cache the level-up info with timestamp for quest turn-in validation
                if previousLevel and newLevel then
                    recentLevelUpCache = {
                        previousLevel = previousLevel,
                        timestamp = GetTime()
                    }
                end
                
                EvaluateCustomCompletions(newLevel)
                RefreshOutleveledAll()
            elseif event == "CHAT_MSG_LOOT" then
                local msg, _, _, _, playerName = ...
                if playerName == GetUnitName("player") then

                -- Extract the item link and itemID from the chat message
                local itemLink = msg:match("|Hitem:%d+.-|h%[.-%]|h")
                if not itemLink then return end

                local itemID = tonumber(itemLink:match("|Hitem:(%d+)"))
                if itemID ~= 6382 then return end  -- Forest Leather Belt
                    for _, row in ipairs(addon.AchievementRowModel or {}) do
                        -- Check both row.completed and database to prevent re-completion
                        if not IsAchievementAlreadyCompleted(row) and row.id == "Secret99" then
                            MarkRowCompleted(row)
                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                        end
                    end
                end
            elseif event == "UPDATE_FACTION" then
                -- Debounce: UPDATE_FACTION arrives in bursts on quest turn-ins and rep grinds,
                -- and each pass scans every row and pcalls a tracker per reputation row.
                if not _pendingFactionCheck then
                    _pendingFactionCheck = true
                    C_Timer.After(0.5, function()
                        _pendingFactionCheck = false
                        -- Handle reputation achievement completion
                        for _, row in ipairs(addon.AchievementRowModel or {}) do
                            if not row.completed and row._def and row._def.isReputation then
                                local achId = row.achId or row.id
                                if achId then
                                    -- Check if this achievement has a reputation tracker function
                                    local trackerFn = (addon and addon.GetAchievementFunction and addon.GetAchievementFunction(achId, "IsCompleted")) or (addon and addon[achId])
                                    if type(trackerFn) == "function" then
                                        -- The tracker function checks if the player is exalted with the faction
                                        local ok, shouldComplete = pcall(trackerFn)
                                        if ok and shouldComplete == true then
                                            MarkRowCompleted(row)
                                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            elseif event == "QUEST_REMOVED" then
                for k in pairs(_questLogCache) do _questLogCache[k] = nil end
                InvalidateOutleveledCache()
                if InvalidateAchievementRuntimeIndex then
                    InvalidateAchievementRuntimeIndex()
                end
                local questIdArg = ...
                local removedQuestId = questIdArg and tonumber(tostring(questIdArg)) or nil
                if removedQuestId and QuestTrackedRows[removedQuestId] then
                    local rows = QuestTrackedRows[removedQuestId]
                    local needsRefresh = false
                    local clearedProgress = false
                    for i = #rows, 1, -1 do
                        local row = rows[i]
                        if not row or row.completed then
                            table_remove(rows, i)
                        else
                            needsRefresh = true
                            -- Hard reset on quest abandon: clear all progress for this specific
                            -- non-completed quest-tracked achievement. This gives players a clean
                            -- slate if they abandon and re-accept. Completed achievements are never
                            -- touched (filtered above). The previous overlevel-only clear is now
                            -- subsumed by the general abandon reset.
                            local achId = row.id or row.achId or (row.Title and row.Title:GetText())
                            if achId then
                                ClearProgress(achId)
                                clearedProgress = true
                            end
                        end
                    end
                    if #rows == 0 then
                        QuestTrackedRows[removedQuestId] = nil
                    end
                    if needsRefresh then
                        if clearedProgress and addon and addon.UpdateTotalPoints then
                            addon.UpdateTotalPoints()
                        end
                        RefreshOutleveledAll()
                        if SortAchievementRows then
                            SortAchievementRows()
                        end
                    end
                end
            elseif event == "MAP_EXPLORATION_UPDATED" then
                -- Debounce: multiple tiles can fire in the same frame when moving through unexplored areas.
                -- Consolidate into a single deferred evaluation 0.5s after the last event.
                if not _pendingExplorationCheck then
                    _pendingExplorationCheck = true
                    C_Timer.After(0.5, function()
                        _pendingExplorationCheck = false
                        if EvaluateCustomCompletions then
                            EvaluateCustomCompletions(UnitLevel("player") or 1)
                        end
                        for _, row in ipairs(addon.AchievementRowModel or {}) do
                            if not row.completed and row.id == "OrgA" and PlayerFactionMatches and PlayerFactionMatches(FACTION_ALLIANCE) then
                                if addon and addon.CheckZoneDiscovery and addon.CheckZoneDiscovery(1411) then
                                    MarkRowCompleted(row)
                                    local iconTex, titleText, frame = GetAchievementToastDisplay(row)
                                    CreateAchToast(iconTex, titleText, row.points, frame or row)
                                end
                            elseif not row.completed and row.id == "StormH" and PlayerFactionMatches and PlayerFactionMatches(FACTION_HORDE) then
                                if addon and addon.CheckZoneDiscovery and addon.CheckZoneDiscovery(1429) then
                                    MarkRowCompleted(row)
                                    local iconTex, titleText, frame = GetAchievementToastDisplay(row)
                                    CreateAchToast(iconTex, titleText, row.points, frame or row)
                                end
                            end
                        end
                    end)
                end
            elseif event == "PLAYER_DEAD" then
                for _, row in ipairs(addon.AchievementRowModel or {}) do
                    -- Check both row.completed and database to prevent re-completion
                    if not IsAchievementAlreadyCompleted(row) and (row.id == "Secret4" or row.id == "Secret004" or row.achId == "Secret4" or row.achId == "Secret004") then
                        MarkRowCompleted(row)
                        local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                        local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                        CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                        break
                    end
                end
            end
        end

        achEvt:SetScript("OnEvent", HandleAchievementEvent)
    end
end

-- =========================================================
-- Cross-locale Emote Hook (token-based)
-- Classic/TBC: DoEmote. Forever/Midnight: C_ChatInfo.PerformEmote (DoEmote is deprecated
-- and /pet no longer routes through it, which silently broke Secret003 and other emote secrets).
-- =========================================================
do
    if not addon.EmoteHooked then
        addon.EmoteHooked = true
        if type(hooksecurefunc) == "function" then
            local function OnEmote(token, unitOrName)
                -- DoEmote passes a unit token; PerformEmote passes a display name (or nil).
                local targetName
                if type(unitOrName) == "string" and unitOrName ~= "" then
                    if UnitExists(unitOrName) then
                        targetName = UnitName(unitOrName)
                    else
                        targetName = unitOrName
                    end
                elseif UnitExists("target") then
                    targetName = UnitName("target")
                end

                for _, row in ipairs(addon.AchievementRowModel or {}) do
                    if not IsAchievementAlreadyCompleted(row) and type(row.emoteTracker) == "function" then
                        local ok, shouldComplete = pcall(
                            row.emoteTracker,
                            tostring(token or ""),
                            tostring(targetName or ""),
                            tostring(unitOrName or "")
                        )
                        if ok and shouldComplete == true then
                            MarkRowCompleted(row)
                            local iconTex = (row.frame and row.frame.Icon and row.frame.Icon.GetTexture and row.frame.Icon:GetTexture()) or row.icon or 136116
                            local titleText = (row.frame and row.frame.Title and row.frame.Title.GetText and row.frame.Title:GetText()) or row.title or "Achievement"
                            CreateAchToast(iconTex, titleText, row.points, row.frame or row)
                        end
                    end
                end
            end

            if DoEmote then
                hooksecurefunc("DoEmote", OnEmote)
            end
            if C_ChatInfo and C_ChatInfo.PerformEmote then
                hooksecurefunc(C_ChatInfo, "PerformEmote", OnEmote)
            end
        end
    end
end
