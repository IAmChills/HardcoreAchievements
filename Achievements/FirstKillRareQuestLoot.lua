-- "Rare quest item on first kill" for secret defs that set `firstKillRareQuestLoot` on `addon.Secrets`
-- (vanilla Achievements/SecretCatalog.lua or TBC/SecretCatalog.lua — same field shape).
-- Per quest variation: PARTY_KILL on an npcId in the variant only counts while that questId is in the
-- log (that first qualifying kill starts the counter at 1). Totals persist: quest accept, abandon,
-- turn-in, or remove do not clear progress.
-- When BAG_UPDATE_DELAYED fires (bags settled), if killsTotal[questId] == 1 and GetItemCount(itemId, true) >= 1, complete.
-- At 2+ kills for a variation that branch can no longer qualify; if every branch is at 2+ without
-- completion, fail (requires supportsStoredFailure on the def).
-- If no variant quest for any rule is in the log, handlers return immediately (no getState / bag work).
local addonName, addon = ...
local strsplit = strsplit
local tonumber = tonumber
local ipairs = ipairs
local type = type
local CreateFrame = CreateFrame
local GetItemCount = GetItemCount

local function getNpcIdFromGUID(guid)
    if not guid then return nil end
    local _, _, _, _, _, npcId = strsplit("-", guid)
    return npcId and tonumber(npcId) or nil
end

local function isQuestInLog(questId)
    if not questId then return false end
    if GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(questId)
        if idx and idx > 0 then return true end
    end
    if GetNumQuestLogEntries then
        for i = 1, GetNumQuestLogEntries() do
            local _, _, _, isHeader, _, _, _, questIDFromLog = GetQuestLogTitle(i)
            if not isHeader and questIDFromLog == questId then
                return true
            end
        end
    end
    return false
end

local function achievementCompleted(achId)
    if not achId or not addon or not addon.GetCharDB then return false end
    local _, cdb = addon.GetCharDB()
    local rec = cdb and cdb.achievements and cdb.achievements[achId]
    return rec and rec.completed
end

local function achievementFailed(achId)
    if not achId or not addon or not addon.GetCharDB then return false end
    local _, cdb = addon.GetCharDB()
    local rec = cdb and cdb.achievements and cdb.achievements[achId]
    return rec and rec.failed
end

local function normalizeState(achId, state)
    if not state then return end
    if state.killsTotal == nil or state.kills ~= nil or state.pending ~= nil then
        state.killsTotal = state.killsTotal or {}
        state.kills = nil
        state.pending = nil
        if achId and addon and addon.SetProgress then
            addon.SetProgress(achId, "firstKillRareState", state)
        end
    end
end

local function getState(achId)
    if not achId or not addon or not addon.GetProgress or not addon.SetProgress then return nil end
    local p = addon.GetProgress(achId)
    if not p or not p.firstKillRareState then
        addon.SetProgress(achId, "firstKillRareState", { killsTotal = {}, met = false })
        p = addon.GetProgress(achId)
    end
    local st = p and p.firstKillRareState
    if st then
        normalizeState(achId, st)
    end
    return st
end

local function saveState(achId, state)
    if not achId or not addon or not addon.SetProgress then return end
    addon.SetProgress(achId, "firstKillRareState", state)
end

local function allVariationsExhausted(rule, state)
    if not rule or not rule.variants or #rule.variants == 0 then return false end
    if not state or not state.killsTotal then return false end
    for _, variant in ipairs(rule.variants) do
        local qid = tonumber(variant.questId)
        if qid then
            local n = tonumber(state.killsTotal[qid]) or 0
            if n < 2 then
                return false
            end
        end
    end
    return true
end

local function tryMarkFailedIfExhausted(rule)
    local achId = rule.achId
    if not achId or achievementCompleted(achId) or achievementFailed(achId) then return end
    local state = getState(achId)
    if not state or state.met then return end
    if not allVariationsExhausted(rule, state) then return end
    if addon.EnsureFailureTimestamp then
        addon.EnsureFailureTimestamp(achId)
    end
    if addon.RefreshOutleveledAll then
        addon.RefreshOutleveledAll()
    end
    if addon.RefreshAllAchievementPoints then
        addon.RefreshAllAchievementPoints()
    end
end

local function collectRules()
    local out = {}
    if not addon or type(addon.Secrets) ~= "table" then return out end
    for _, def in ipairs(addon.Secrets) do
        if def.achId and type(def.firstKillRareQuestLoot) == "table" then
            out[#out + 1] = { achId = def.achId, variants = def.firstKillRareQuestLoot }
        end
    end
    return out
end

local rules = {}

-- True if this achievement has at least one variant quest currently in the log.
local function ruleHasAnyQuestInLog(rule)
    if not rule or not rule.variants then return false end
    for _, variant in ipairs(rule.variants) do
        local qid = tonumber(variant.questId)
        if qid and isQuestInLog(qid) then
            return true
        end
    end
    return false
end

local function anyRuleHasQuestInLog()
    for _, rule in ipairs(rules) do
        if ruleHasAnyQuestInLog(rule) then
            return true
        end
    end
    return false
end

local function onPartyKill(destGUID)
    if not destGUID then return end
    if not anyRuleHasQuestInLog() then return end

    local npcId = getNpcIdFromGUID(destGUID)
    if not npcId then return end

    for _, rule in ipairs(rules) do
        if not ruleHasAnyQuestInLog(rule) then
            -- skip: no related quests in log for this achievement
        else
            local achId = rule.achId
            if achievementCompleted(achId) or achievementFailed(achId) then
                -- skip
            else
                local state = getState(achId)
                if state and not state.met then
                    local touched = false
                    for _, variant in ipairs(rule.variants) do
                        local qid = tonumber(variant.questId)
                        local itemId = tonumber(variant.itemId)
                        if qid and itemId and isQuestInLog(qid) then
                            local matchesNpc = false
                            if type(variant.npcIds) == "table" then
                                for _, nid in ipairs(variant.npcIds) do
                                    if tonumber(nid) == npcId then
                                        matchesNpc = true
                                        break
                                    end
                                end
                            end
                            if matchesNpc then
                                state.killsTotal[qid] = (tonumber(state.killsTotal[qid]) or 0) + 1
                                touched = true
                            end
                        end
                    end
                    if touched then
                        saveState(achId, state)
                        tryMarkFailedIfExhausted(rule)
                    end
                end
            end
        end
    end
end

local function onBagUpdateDelayed()
    if not anyRuleHasQuestInLog() then return end

    for _, rule in ipairs(rules) do
        if not ruleHasAnyQuestInLog(rule) then
            -- skip
        else
            local achId = rule.achId
            if achievementCompleted(achId) or achievementFailed(achId) then
                -- skip
            else
                local state = getState(achId)
                if state and not state.met and state.killsTotal then
                    for _, variant in ipairs(rule.variants) do
                        local qid = tonumber(variant.questId)
                        local itemId = tonumber(variant.itemId)
                        if qid and itemId and isQuestInLog(qid) then
                            local total = tonumber(state.killsTotal[qid]) or 0
                            -- Inventory is settled on this event; require exactly one counted kill and at least one item.
                            if total == 1 and (GetItemCount(itemId, true) or 0) >= 1 then
                                state.met = true
                                saveState(achId, state)
                                if addon.CheckPendingCompletions then
                                    addon.CheckPendingCompletions()
                                end
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        rules = collectRules()
        if #rules == 0 then
            return
        end
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        f:RegisterEvent("BAG_UPDATE_DELAYED")
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if subevent == "PARTY_KILL" and destGUID then
            onPartyKill(destGUID)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        onBagUpdateDelayed()
    end
end)
