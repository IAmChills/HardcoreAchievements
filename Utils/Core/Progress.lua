local addonName, addon = ...
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UIParent = UIParent
local UnitLevel = UnitLevel
local IsResting = IsResting
local time = time

-- =========================================================
-- Progress Helpers + Unsaved Reminder Banner
-- =========================================================
-- Extracted from HardcoreAchievements.lua (Phase 1).
-- Call-time lookups for GetCharDB / outleveled refresh: those stay in the monolith until later phases.
--
-- IMPORTANT: never write `addon.GetCharDB and addon.GetCharDB()`. Lua's `and` keeps only the
-- first return value (account db), so `local _, cdb = ...` would leave cdb nil and silently
-- drop every SetProgress / GetProgress call.

local function CallGetCharDB()
    local fn = addon and addon.GetCharDB
    if type(fn) ~= "function" then
        return nil, nil
    end
    return fn()
end

local unsavedAchievementReminderPending = false
local unsavedAchievementReminderFrame = nil
local unsavedAchievementReminderDismissed = false

local function EnsureUnsavedAchievementReminderFrame()
    if unsavedAchievementReminderFrame or not UIParent then
        return unsavedAchievementReminderFrame
    end

    local frame = CreateFrame("Button", nil, UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(20)
    frame:SetSize(520, 32)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -18)
    frame:EnableMouse(true)
    frame:Hide()
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            unsavedAchievementReminderDismissed = true
            self:Hide()
            if self.TextPulse and self.TextPulse:IsPlaying() then
                self.TextPulse:Stop()
            end
            if self.IconPulse and self.IconPulse:IsPlaying() then
                self.IconPulse:Stop()
            end
        end
    end)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png")
    icon:SetSize(22, 22)
    frame.Icon = icon

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", frame, "CENTER", 12, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(1, 1, 1, 0.95)
    text:SetText("You have unsaved achievement progress, please reload. Click to dismiss.")
    frame.Text = text

    icon:SetPoint("RIGHT", text, "LEFT", -8, 0)

    local textPulse = text:CreateAnimationGroup()
    textPulse:SetLooping("REPEAT")

    local textFadeOut = textPulse:CreateAnimation("Alpha")
    textFadeOut:SetOrder(1)
    textFadeOut:SetFromAlpha(1.0)
    textFadeOut:SetToAlpha(0.45)
    textFadeOut:SetDuration(0.6)

    local textFadeIn = textPulse:CreateAnimation("Alpha")
    textFadeIn:SetOrder(2)
    textFadeIn:SetFromAlpha(0.45)
    textFadeIn:SetToAlpha(1.0)
    textFadeIn:SetDuration(0.6)

    local iconPulse = icon:CreateAnimationGroup()
    iconPulse:SetLooping("REPEAT")

    local iconFadeOut = iconPulse:CreateAnimation("Alpha")
    iconFadeOut:SetOrder(1)
    iconFadeOut:SetFromAlpha(1.0)
    iconFadeOut:SetToAlpha(0.45)
    iconFadeOut:SetDuration(0.6)

    local iconFadeIn = iconPulse:CreateAnimation("Alpha")
    iconFadeIn:SetOrder(2)
    iconFadeIn:SetFromAlpha(0.45)
    iconFadeIn:SetToAlpha(1.0)
    iconFadeIn:SetDuration(0.6)

    frame.TextPulse = textPulse
    frame.IconPulse = iconPulse
    unsavedAchievementReminderFrame = frame
    return frame
end

local function UpdateUnsavedAchievementReminderVisibility()
    local frame = EnsureUnsavedAchievementReminderFrame()
    if not frame then
        return
    end

    local isRestingNow = type(IsResting) == "function" and IsResting()
    if not isRestingNow then
        unsavedAchievementReminderDismissed = false
    end

    if unsavedAchievementReminderPending and isRestingNow and not unsavedAchievementReminderDismissed then
        frame:Show()
        if frame.TextPulse and not frame.TextPulse:IsPlaying() then
            frame.TextPulse:Play()
        end
        if frame.IconPulse and not frame.IconPulse:IsPlaying() then
            frame.IconPulse:Play()
        end
    else
        if frame.TextPulse and frame.TextPulse:IsPlaying() then
            frame.TextPulse:Stop()
        end
        if frame.IconPulse and frame.IconPulse:IsPlaying() then
            frame.IconPulse:Stop()
        end
        frame:Hide()
    end
end

local function MarkUnsavedAchievementProgress()
    unsavedAchievementReminderPending = true
    UpdateUnsavedAchievementReminderVisibility()
end

local function ClearProgress(achId)
    local _, cdb = CallGetCharDB()
    if cdb and cdb.progress then cdb.progress[achId] = nil end
end

local function GetProgress(achId)
    local _, cdb = CallGetCharDB()
    if not cdb then return nil end
    cdb.progress = cdb.progress or {}
    return cdb.progress[achId]
end

-- A single boss kill fans out into a lot of SetProgress calls. Every dungeon variation tracking that
-- boss (base, Solo, Duo, Trio) separately stores counts, points-at-kill and a three-part entry-level
-- snapshot, which is roughly 5-7 writes each, so 20-plus writes for one kill. Each write used to
-- queue its own next-frame pass, and every pass ran CheckPendingCompletions across the whole
-- catalog, meaning one kill could probe tens of thousands of rows in a single frame.
--
-- Coalesce the burst into one pass and remember which achievements actually changed so the follow-up
-- refresh stays as narrow as it was before.
local progressFlush = {
    pending = false,
    dirty = {},
    -- Keys that represent real saved progress worth prompting a reload.
    -- Level/entry metadata is rewritten often on login and must not false-trigger the banner.
    unsavedKeys = {
        killed = true,
        quest = true,
        counts = true,
        eligibleCounts = true,
        completed = true,
        pointsAtKill = true,
        soloKill = true,
        soloQuest = true,
        ineligibleKill = true,
        itemOwned = true,
        firstKillRareState = true,
        extraCreditPoints = true,
        extraCreditKills = true,
    },
}

function progressFlush.Run()
    progressFlush.pending = false
    local progressDirtyAchIds = progressFlush.dirty

    -- Only live gameplay progress should queue follow-up completion checks.
    -- Initial login/retroactive passes run their own synchronous completion sweep.
    -- One sweep covers every achievement touched during the burst.
    if addon and addon.CheckPendingCompletions then
        addon.CheckPendingCompletions()
    end

    -- Resolve every dirty achievement in one pass over the model rather than one pass each.
    local dirtyRows = nil
    local resolved = nil
    for _, r in ipairs((addon and addon.AchievementRowModel) or {}) do
        local matched = nil
        if r.id ~= nil and progressDirtyAchIds[r.id] then
            matched = r.id
        elseif r.achId ~= nil and progressDirtyAchIds[r.achId] then
            matched = r.achId
        end
        if matched ~= nil then
            dirtyRows = dirtyRows or {}
            dirtyRows[#dirtyRows + 1] = r
            resolved = resolved or {}
            resolved[matched] = true
        end
    end

    -- Progress can flip failed <-> available (e.g. kills done, quest still in log).
    -- Clear only the affected achievements' cached rows so other results stay hot.
    local needsFullOutleveledRefresh = false
    local anyUnresolved = false
    local invalidateForAchId = addon and addon.InvalidateOutleveledCacheForAchId
    local applyOutleveledStyle = addon and addon.ApplyOutleveledStyle
    for achId in pairs(progressDirtyAchIds) do
        progressDirtyAchIds[achId] = nil
        local dirtyUiRow = invalidateForAchId and invalidateForAchId(achId)
        if dirtyUiRow and applyOutleveledStyle then
            applyOutleveledStyle(dirtyUiRow)
        else
            needsFullOutleveledRefresh = true
        end
        if not (resolved and resolved[achId]) then
            anyUnresolved = true
        end
    end

    if needsFullOutleveledRefresh then
        if addon and addon.RefreshOutleveledAll then
            addon.RefreshOutleveledAll()
        end
    elseif addon and addon.RefreshAuxiliaryViews then
        addon.RefreshAuxiliaryViews()
    end

    -- Partial refresh: only recalculate the rows whose progress just changed. An achievement we
    -- could not resolve to a model row means we cannot narrow it, so fall back to the full pass.
    if addon and addon.RefreshAllAchievementPoints then
        addon.RefreshAllAchievementPoints((not anyUnresolved) and dirtyRows or nil)
    end
end

-- SavedVariables may reload numeric map keys as strings (or the reverse). Treat "644" and 644 as the same.
function progressFlush.TableGet(t, k)
    if type(t) ~= "table" then
        return nil
    end
    local v = t[k]
    if v ~= nil then
        return v
    end
    if type(k) == "string" then
        local n = tonumber(k)
        if n ~= nil then
            return t[n]
        end
    elseif type(k) == "number" then
        return t[tostring(k)]
    end
    return nil
end

function progressFlush.ValuesEqual(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    local seen = {}
    for k, v in pairs(a) do
        seen[k] = true
        if type(k) == "number" then
            seen[tostring(k)] = true
        elseif type(k) == "string" then
            local n = tonumber(k)
            if n ~= nil then
                seen[n] = true
            end
        end
        local bv = progressFlush.TableGet(b, k)
        if type(v) == "table" then
            if not progressFlush.ValuesEqual(v, bv) then
                return false
            end
        elseif bv ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if not seen[k] and progressFlush.TableGet(a, k) == nil then
            return false
        end
    end
    return true
end

-- Login settle often writes markers that are not player progress (incomplete flags, empty trackers).
function progressFlush.IsTrivialUnsavedWrite(key, oldValue, newValue)
    if key == "completed" and newValue == false then
        return true
    end
    if key == "firstKillRareState" and oldValue == nil and type(newValue) == "table" then
        if newValue.met ~= true and (not newValue.killsTotal or next(newValue.killsTotal) == nil) then
            return true
        end
    end
    return false
end

local function SetProgress(achId, key, value)
    local _, cdb = CallGetCharDB()
    if not cdb then return end
    cdb.progress = cdb.progress or {}
    local p = cdb.progress[achId] or {}
    -- Login/zone/quest handlers often rewrite the same values; ignore no-ops.
    if progressFlush.ValuesEqual(p[key], value) then
        return
    end
    local oldValue = p[key]
    p[key] = value
    p.updatedAt = time()
    -- Only set levelAt for progress-related keys (kills, quests, counts, etc.)
    -- Don't set it for metadata-only keys like levelAtTurnIn, levelAtKill, etc.
    local shouldSetLevelAt = key == "killed" or key == "quest" or key == "counts" or key == "eligibleCounts" or key == "ineligibleKill" or key == "soloKill" or key == "soloQuest" or key == "pointsAtKill"
    if shouldSetLevelAt then
        p.levelAt = UnitLevel("player") or 1
    end
    cdb.progress[achId] = p

    local restorationsComplete = addon and addon.RestorationsComplete
    local skippingBroadcast = addon and addon.IsSkippingAchievementBroadcast and addon.IsSkippingAchievementBroadcast()
    if restorationsComplete and not skippingBroadcast and not (addon and addon.Initializing) then
        if progressFlush.unsavedKeys[key] and not progressFlush.IsTrivialUnsavedWrite(key, oldValue, value) then
            addon._lastUnsavedProgress = { achId = achId, key = key, at = time() }
            MarkUnsavedAchievementProgress()
        end
        if achId ~= nil then
            progressFlush.dirty[achId] = true
        end
        if not progressFlush.pending then
            progressFlush.pending = true
            C_Timer.After(0, progressFlush.Run)
        end
    end
end

if addon then
    addon.GetProgress = GetProgress
    addon.SetProgress = SetProgress
    addon.ClearProgress = ClearProgress
    addon.MarkUnsavedAchievementProgress = MarkUnsavedAchievementProgress
    addon.UpdateUnsavedAchievementReminderVisibility = UpdateUnsavedAchievementReminderVisibility
    addon.progressFlush = progressFlush
end
