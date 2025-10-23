-- Achievements_Common.lua
-- Shared factory for standard (quest/kill under level cap) achievements.
local M = {}

local function getNpcIdFromGUID(guid)
    if not guid then
        return nil
    end
    local npcId = select(6, strsplit("-", guid))
    return npcId and tonumber(npcId) or nil
end

function M.registerQuestAchievement(cfg)
    assert(type(cfg.achId) == "string", "achId required")
    local ACH_ID = cfg.achId
    local REQUIRED_QUEST_ID = cfg.requiredQuestId
    local TARGET_NPC_ID = cfg.targetNpcId
    local MAX_LEVEL = cfg.maxLevel or 60
    local FACTION, RACE, CLASS = cfg.faction, cfg.race, cfg.class

    local state = {
        completed = false,
        killed = false,
        quest = false
    }

    local function gate()
        if FACTION and UnitFactionGroup("player") ~= FACTION then return false end
        if RACE then
            local _, raceFile = UnitRace("player")
            if raceFile ~= RACE then return false end
        end
        if CLASS then
            local _, classFile = UnitClass("player")
            if classFile ~= CLASS then return false end
        end
        return true
    end

    local function belowMax()
        return (UnitLevel("player") or 1) <= MAX_LEVEL
    end

    local function setProg(key, val)
        if HardcoreAchievements_SetProgress then
            HardcoreAchievements_SetProgress(ACH_ID, key, val)
        end
    end

    local function serverQuestDone()
        if not REQUIRED_QUEST_ID then
            return false
        end
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            return C_QuestLog.IsQuestFlaggedCompleted(REQUIRED_QUEST_ID) or false
        end
        if IsQuestFlaggedCompleted then
            return IsQuestFlaggedCompleted(REQUIRED_QUEST_ID) or false
        end
        return false
    end

    local function topUpFromServer()
        if REQUIRED_QUEST_ID and not state.quest and serverQuestDone() then
            state.quest = true
            setProg("quest", true)
            return true
        end
    end

    local function checkComplete()
        if state.completed then
            return true
        end
        if not gate() or not belowMax() then
            return false
        end
        local killOk = (not TARGET_NPC_ID) or state.killed
        local questOk = (not REQUIRED_QUEST_ID) or state.quest
        if killOk and questOk then
            state.completed = true
            setProg("completed", true)
            return true
        end
        return false
    end

    do
        local p = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(ACH_ID)
        if p then
            state.killed = not not p.killed
            state.quest = not not p.quest
            state.completed = not not p.completed
        end
        topUpFromServer()
        checkComplete()
    end

    if TARGET_NPC_ID then
        _G[ACH_ID .. "_Kill"] = function(destGUID)
            if state.completed or not belowMax() then
                return false
            end
            if getNpcIdFromGUID(destGUID) ~= TARGET_NPC_ID then
                return false
            end
            state.killed = true
            setProg("killed", true)
            return checkComplete()
        end
    end

    if REQUIRED_QUEST_ID then
        _G[ACH_ID .. "_Quest"] = function(questID)
            if state.completed or not belowMax() then
                return false
            end
            if questID ~= REQUIRED_QUEST_ID then
                return false
            end
            state.quest = true
            setProg("quest", true)
            return checkComplete()
        end

        local f = CreateFrame("Frame")
        f:RegisterEvent("QUEST_LOG_UPDATE")
        f:SetScript("OnEvent", function(self)
            if state.completed then
                self:UnregisterAllEvents()
                return
            end
            C_Timer.After(0.25, function()
                if topUpFromServer() and checkComplete() then
                    self:UnregisterAllEvents()
                end
            end)
        end)
    end

    _G[ACH_ID .. "_IsCompleted"] = function()
        if state.completed then
            return true
        end
        if topUpFromServer() then
            return checkComplete()
        end
        return false
    end
end

_G.Achievements_Common = M
return M
