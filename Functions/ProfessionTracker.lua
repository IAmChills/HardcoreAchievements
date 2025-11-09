local ProfessionTracker = {}

-- =========================================================
-- Profession data
-- =========================================================

local ProfessionList = {
    { key = "Alchemy",       skillID = 171, name = "Alchemy",       icon = 136240 },
    { key = "Blacksmithing", skillID = 164, name = "Blacksmithing", icon = 136241 },
    { key = "Enchanting",    skillID = 333, name = "Enchanting",    icon = 136244 },
    { key = "Engineering",   skillID = 202, name = "Engineering",   icon = 136243 },
    { key = "Herbalism",     skillID = 182, name = "Herbalism",     icon = 136246 },
    { key = "Leatherworking",skillID = 165, name = "Leatherworking",icon = 133611 },
    { key = "Mining",        skillID = 186, name = "Mining",        icon = 134708 },
    { key = "Skinning",      skillID = 393, name = "Skinning",      icon = 134366 },
    { key = "Tailoring",     skillID = 197, name = "Tailoring",     icon = 136249 },
    { key = "Cooking",       skillID = 185, name = "Cooking",       icon = 133971, secondary = true },
    { key = "Fishing",       skillID = 356, name = "Fishing",       icon = 136245, secondary = true },
    { key = "FirstAid",      skillID = 129, name = "First Aid",     icon = 135966, secondary = true },
    -- { key = "Lockpicking",   skillID = 633, name = "Lockpicking",   icon = 134237, secondary = true },
    -- { key = "Poisons",       skillID = 40,  name = "Poisons",       icon = 132273, secondary = true },
    -- { key = "Riding",        skillID = 762, name = "Riding",        icon = 132261, secondary = true },
}

local ProfessionByID = {}
local ProfessionNameToID = {}
for _, entry in ipairs(ProfessionList) do
    entry.shortKey = entry.key or (entry.name:gsub("%s+", ""))
    ProfessionByID[entry.skillID] = entry
    ProfessionNameToID[entry.name] = entry.skillID
end

_G.HCA_ProfessionList = ProfessionList

-- =========================================================
-- Internal state
-- =========================================================

local ProfessionState = {}    -- [skillID] = { rank, maxRank, known, localizedName }
local ProfessionRows = {}     -- [skillID] = { rows... }

local function GetCharacterDB()
    local getter = _G.HardcoreAchievements_GetCharDB
    if type(getter) == "function" then
        local _, cdb = getter()
        return cdb
    end
    return nil
end

local function EnsureState(skillID)
    local state = ProfessionState[skillID]
    if not state then
        state = { rank = 0, maxRank = 0, known = false }
        ProfessionState[skillID] = state
    end
    return state
end

-- =========================================================
-- Public helpers
-- =========================================================

function ProfessionTracker.GetProfessionList()
    return ProfessionList
end

function ProfessionTracker.GetSkillRank(skillID)
    local state = ProfessionState[skillID]
    return state and state.rank or 0
end

function ProfessionTracker.PlayerHasSkill(skillID)
    local state = ProfessionState[skillID]
    return state and state.known or false
end

-- Maintain external compatibility helpers
_G.HCA_GetProfessionSkillRank = ProfessionTracker.GetSkillRank
_G.HCA_PlayerHasProfessionSkill = ProfessionTracker.PlayerHasSkill

local function IsRowCompleted(row, cdb)
    if row.completed then
        return true
    end
    local id = row.id or row.achId
    if not id then
        return false
    end
    if cdb and cdb.achievements then
        local rec = cdb.achievements[id]
        if rec and rec.completed then
            return true
        end
    end
    return false
end

local function EvaluateCompletions(skillID)
    local rows = ProfessionRows[skillID]
    if not rows then return end

    local cdb = GetCharacterDB()
    if not cdb then
        return
    end

    local anyCompleted = false
    for _, row in ipairs(rows) do
        local completionFn = row.customIsCompleted
        if not IsRowCompleted(row, cdb) and type(completionFn) == "function" then
            local ok, result = pcall(completionFn)
            if ok and result == true then
                HCA_MarkRowCompleted(row)
                local icon = row.Icon and row.Icon:GetTexture() or 136116
                local title = row.Title and row.Title:GetText() or "Achievement"
                HCA_AchToast_Show(icon, title, row.points, row)
                anyCompleted = true
            end
        end
    end

    if anyCompleted and type(_G.HCA_RefreshOutleveledAll) == "function" then
        _G.HCA_RefreshOutleveledAll()
    end
end

function ProfessionTracker.RegisterRow(row, def)
    if not row or not def then return end
    local skillID = def.requireProfessionSkillID
    if not skillID then return end

    ProfessionRows[skillID] = ProfessionRows[skillID] or {}
    table.insert(ProfessionRows[skillID], row)
end

-- =========================================================
-- Skill scanning
-- =========================================================

local function NotifySkillChanged(skillID, newRank, oldRank, localizedName)
    local state = EnsureState(skillID)
    state.rank = newRank or state.rank or 0
    state.known = (state.rank or 0) > 0 or (state.maxRank or 0) > 0
    if localizedName and localizedName ~= "" then
        state.localizedName = localizedName
    end

    EvaluateCompletions(skillID)
end

local function ScanSkills()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return
    end

    local seen = {}
    for index = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank, _, _, skillMaxRank, _, _, _, _, _, _, _, _, _, _, skillLineID = GetSkillLineInfo(index)
        if not isHeader then
        local skillID = skillLineID or (skillName and ProfessionNameToID[skillName])

            if skillID and ProfessionByID[skillID] then
                seen[skillID] = true
                local state = EnsureState(skillID)
                local oldRank = state.rank or 0
                local oldKnown = state.known

                state.rank = skillRank or 0
                state.maxRank = skillMaxRank or 0
                state.known = (state.rank > 0) or (state.maxRank > 0)

                if skillName and skillName ~= "" then
                    state.localizedName = skillName
                end

                if state.known ~= oldKnown or state.rank ~= oldRank then
                    NotifySkillChanged(skillID, state.rank, oldRank, state.localizedName)
                end
            end
        end
    end

    -- Handle unlearned professions
    for skillID, state in pairs(ProfessionState) do
        if not seen[skillID] and (state.known or (state.rank and state.rank ~= 0)) then
            local oldRank = state.rank or 0
            state.rank = 0
            state.maxRank = 0
            state.known = false
            NotifySkillChanged(skillID, 0, oldRank)
        end
    end
end

local function HandleConsoleSkillMessage(message)
    if type(message) ~= "string" then
        return false
    end

    local skillID, oldRank, newRank = message:match("Skill%s+(%d+)%s+increased%s+from%s+(%d+)%s+to%s+(%d+)")
    if not skillID then
        return false
    end

    skillID = tonumber(skillID)
    oldRank = tonumber(oldRank) or 0
    newRank = tonumber(newRank) or oldRank

    local state = EnsureState(skillID)
    state.rank = newRank
    state.known = true

    NotifySkillChanged(skillID, newRank, oldRank)
    return true
end

-- =========================================================
-- Event handling
-- =========================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("CHAT_MSG_SKILL")
eventFrame:RegisterEvent("CONSOLE_MESSAGE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Delay initial scan slightly to ensure skills are loaded
        C_Timer.After(1, ScanSkills)
    elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
        ScanSkills()
    elseif event == "CONSOLE_MESSAGE" then
        local message = ...
        if not HandleConsoleSkillMessage(message) then
            ScanSkills()
        end
    end
end)

-- =========================================================
-- Public API
-- =========================================================

function ProfessionTracker.RefreshAll()
    ScanSkills()
end

_G.HCA_ProfessionCommon = ProfessionTracker

return ProfessionTracker


