local addonName, addon = ...
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UIParent = UIParent
local GetTime = GetTime
local time = time
local string_format = string.format
local table_remove = table.remove
local IsInInstance = IsInInstance
local Screenshot = Screenshot
local SendChatMessage = SendChatMessage
local PlaySoundFile = PlaySoundFile

-- =========================================================
-- Simple Achievement Toast
-- =========================================================
-- Usage:
-- CreateAchToast(iconTextureIdOrPath, "Achievement Title", 10)
-- CreateAchToast(row.icon or 134400, row.title or "Achievement", row.points or 10)
--
-- The achievement toast reuses one shared frame, so simultaneous completions (a meta plus the
-- achievements that satisfied it, or a dungeon finishing several variations on the same kill) used to
-- overwrite each other and only the last one was ever seen. Queue them and show one at a time.
-- Guild-first toasts live on their own frame anchored above this one and stay outside this queue, so a
-- guild first and a regular achievement still appear together.
-- Extracted from HardcoreAchievements.lua (Phase 1) for a fresh Lua 5.1 local budget.

local ACHIEVEMENT_SOUND_FILE = "Interface\\AddOns\\HardcoreAchievements\\Sounds\\AchievementSound1.ogg"
local ACHIEVEMENT_SOUND_COOLDOWN = 0.35
local lastAchievementSoundAt = 0

local achToast = {
    HOLD_SEC = 3,
    FADE_SEC = 0.6,
    GAP_SEC = 0.25,
    QUEUE_LIMIT = 5,
    queue = {},
    showing = false,
    -- Identifies the toast on screen so a stale fade or watchdog cannot advance past a newer one.
    serial = 0,
    BG = "Interface\\AddOns\\HardcoreAchievements\\Images\\AchievementFrame.png",
    ICON_FRAME = "Interface\\AddOns\\HardcoreAchievements\\Images\\AchievementIconFrame.png",
}

-- Never use `addon.GetCharDB and addon.GetCharDB()` — `and` keeps only the first return (account db).
local function CallGetCharDB()
    local fn = addon and addon.GetCharDB
    if type(fn) ~= "function" then
        return nil, nil
    end
    return fn()
end

local function IsSkippingBroadcast()
    return addon and addon.IsSkippingAchievementBroadcast and addon.IsSkippingAchievementBroadcast()
end

local function ToggleUI()
    if addon and addon.ToggleHardcoreAchievementsUI then
        addon.ToggleHardcoreAchievementsUI()
    elseif addon and addon.Dashboard and addon.Dashboard.Toggle then
        addon.Dashboard:Toggle()
    elseif addon and addon.ShowDashboard then
        addon.ShowDashboard()
    end
end

function achToast.Advance(serial)
    if not achToast.showing or serial ~= achToast.serial then
        return
    end
    achToast.showing = false
    if #achToast.queue > 0 and achToast.ShowNext then
        C_Timer.After(achToast.GAP_SEC, achToast.ShowNext)
    end
end

-- Single OnUpdate for toast fade; state on frame (fadeT, fadeDuration) avoids allocating per toast
local function AchToastFadeOnUpdate(s, elapsed)
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
        achToast.Advance(s.toastSerial)
    end
end

local function GetOrCreateAchToastFrame()
    if AchToast and AchToast:IsObjectType("Frame") then
        return AchToast
    end

    local f = CreateFrame("Frame", "AchToast", UIParent)
    f:SetSize(320, 92) -- 92 for bronze, 100 for dark bronze
    -- Forever: one toast higher, clear of Blizzard's legacy achievement alerts.
    local isForever = addon.IsForeverClient and addon.IsForeverClient()
    f:SetPoint("CENTER", 0, isForever and -300 or -400) -- previously -280
    f:Hide()
    f:SetFrameStrata("TOOLTIP")

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(achToast.BG)

    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame:SetSize(64, 64)
    iconFrame:SetPoint("LEFT", f, "LEFT", 0, 0) -- 0 for bronze, 6 for dark bronze

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconFrame, "CENTER", 2, 0)
    icon:SetSize(50, 50)
    icon:SetTexCoord(0.05, 1, 0.05, 1)
    f.icon = icon

    local iconOverlay = iconFrame:CreateTexture(nil, "OVERLAY")
    iconOverlay:SetTexture(achToast.ICON_FRAME)
    iconOverlay:SetAllPoints(iconFrame)

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("CENTER", f, "CENTER", 10, 0) -- 0 for bronze, 6 for dark bronze
    name:SetJustifyH("CENTER")
    f.name = name

    local unlocked = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlocked:SetPoint("TOP", f, "TOP", 12, -22) -- -22 for bronze, -19 for dark bronze
    unlocked:SetText(ACHIEVEMENT_UNLOCKED)

    function f:PlayFade(duration)
        self.fadeT = 0
        self.fadeDuration = duration
        self:SetScript("OnUpdate", AchToastFadeOnUpdate)
    end

    local clipper = CreateFrame("Frame", nil, f)
    clipper:SetClipsChildren(true)
    clipper:SetFrameLevel(f:GetFrameLevel() + 3)
    clipper:SetSize(420, 42)
    clipper:SetPoint("CENTER", bg, "CENTER", 20, 0)
    clipper:EnableMouse(false)
    local model = CreateFrame("PlayerModel", nil, clipper)
    model:SetAllPoints(clipper)
    model:SetAlpha(0.55)
    model:SetModel(166349)
    model:SetModelScale(0.8)
    model:EnableMouse(false)
    f.shineModel = model

    -- Points must be above the shine model or Forever draws the model over them.
    local pointsFrame = CreateFrame("Frame", nil, f)
    pointsFrame:SetAllPoints(f)
    pointsFrame:SetFrameLevel(f:GetFrameLevel() + 4)
    pointsFrame:EnableMouse(false)
    local points = pointsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    points:SetPoint("CENTER", f, "RIGHT", -31, 2) -- -31, 2 for bronze, -32, 9 for dark bronze
    f.points = points
    local noPoints = pointsFrame:CreateTexture(nil, "OVERLAY")
    noPoints:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\noPoints.png")
    noPoints:SetSize(14, 18)
    noPoints:SetPoint("CENTER", f, "RIGHT", -31, 2)
    noPoints:Hide()
    f.noPoints = noPoints

    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        -- Forever: EMOTE requires a hardware event; this click is that event.
        local pendingEmote = self.pendingEmote
        if pendingEmote then
            self.pendingEmote = nil
            SendChatMessage(pendingEmote, "EMOTE")
        end
        if self.achId and addon and addon.OpenDashboardToAchievement then
            addon.OpenDashboardToAchievement(self.achId)
        else
            ToggleUI()
        end
    end)

    return f
end

-- Shared achievement sound gate: prevent overlapping sound when many completions
-- happen in a short burst (meta + dependent achievements, restore batches, etc.).
local function PlayAchievementSound()
    local now = GetTime and GetTime() or 0
    if (now - (lastAchievementSoundAt or 0)) < ACHIEVEMENT_SOUND_COOLDOWN then
        return false
    end
    lastAchievementSoundAt = now
    PlaySoundFile(ACHIEVEMENT_SOUND_FILE, "Effects")
    return true
end

-- announce is true only for the toast that opens a burst, so a batch of completions produces one sound
-- and one screenshot rather than one of each per achievement.
function achToast.ShowNow(iconTex, title, pts, achIdOrRow, announce)
    local f = GetOrCreateAchToastFrame()
    f:Hide()
    -- Clear any fade left running by a toast that was cut short, otherwise this one starts mid-fade.
    f:SetScript("OnUpdate", nil)
    f.fadeT = nil
    f.fadeDuration = nil
    f:SetAlpha(1)

    -- Accept fileID/path/Texture object; fallback if nil
    local tex = iconTex
    if type(iconTex) == "table" and iconTex.GetTexture then
        tex = iconTex:GetTexture()
    end
    if not tex then tex = 136116 end

    -- Check for pointsAtKill and add self-found bonus if applicable
    local finalPoints = pts or 0
    local achId = nil
    local row = nil

    if achIdOrRow then
        local _, cdb = CallGetCharDB()

        if type(achIdOrRow) == "table" then
            row = achIdOrRow
            achId = row.achId or row.id
        else
            achId = achIdOrRow
        end

        if cdb and cdb.progress and achId and cdb.progress[achId] and cdb.progress[achId].pointsAtKill then
            finalPoints = tonumber(cdb.progress[achId].pointsAtKill) or finalPoints
            -- Add self-found bonus if applicable (pointsAtKill doesn't include it)
            -- Simplified rule: 0-point achievements remain 0 (bonus computes to 0).
            if addon.IsSelfFound and addon.IsSelfFound() then
                local baseForBonus = 0
                if row and row.originalPoints then
                    baseForBonus = row.originalPoints
                elseif row and row.revealPointsBase then
                    baseForBonus = row.revealPointsBase
                elseif AchievementPanel and AchievementPanel.achievements and achId then
                    for _, r in ipairs(AchievementPanel.achievements) do
                        if r and (r.id == achId or r.achId == achId) then
                            baseForBonus = r.originalPoints or r.revealPointsBase or r.points or 0
                            break
                        end
                    end
                end
                local bonus = (addon.GetSelfFoundBonus and addon.GetSelfFoundBonus(baseForBonus)) or 0
                if bonus > 0 and finalPoints > 0 then
                    finalPoints = finalPoints + bonus
                end
            end
        end
    end

    f.achId = achId
    f.icon:SetTexture(tex)
    f.name:SetText(title or "")

    -- Forever outdoors: auto-EMOTE needs a hardware event, so stash text for the toast click.
    -- Forever inside instances already auto-emotes from the award path — do not queue a duplicate.
    f.pendingEmote = nil
    local shouldAnnounce = true
    if addon and addon.ShouldAnnounceInChat then
        shouldAnnounce = addon.ShouldAnnounceInChat() and true or false
    end
    if not IsSkippingBroadcast() and shouldAnnounce
        and addon and addon.IsForeverClient and addon.IsForeverClient() then
        local inInstance = IsInInstance and select(1, IsInInstance()) or false
        if not inInstance then
            local broadcastMessage = string_format(ACHIEVEMENT_BROADCAST, "", title or "Unknown Achievement")
            f.pendingEmote = broadcastMessage:gsub("^%s+", "")
        end
    end

    if finalPoints == 0 then
        f.points:SetText("")
        f.points:Hide()
        f.noPoints:Show()
    else
        f.noPoints:Hide()
        f.points:SetText(tostring(finalPoints))
        f.points:Show()
    end

    if f.shineModel then
        f.shineModel:Show()
        C_Timer.After(2.5, function()
            if f.shineModel then
                f.shineModel:Hide()
            end
        end)
    end

    f:Show()

    if announce and not IsSkippingBroadcast() and addon and addon.PlayAchievementSound then
        addon.PlayAchievementSound()
    end

    if announce then
        C_Timer.After(1, function()
            local shouldTakeScreenshot = true
            if addon and addon.ShouldTakeScreenshot then
                shouldTakeScreenshot = addon.ShouldTakeScreenshot()
            else
                local _, cdb = CallGetCharDB()
                if cdb and cdb.settings and cdb.settings.disableScreenshots then
                    shouldTakeScreenshot = false
                end
            end

            if shouldTakeScreenshot then
                Screenshot()
            end
        end)
    end

    achToast.serial = achToast.serial + 1
    local serial = achToast.serial
    f.toastSerial = serial

    C_Timer.After(achToast.HOLD_SEC, function()
        if f:IsShown() then f:PlayFade(achToast.FADE_SEC) end
    end)

    -- The completed fade normally advances the queue. This is the backstop for the toast being hidden
    -- some other way, so a stuck "showing" flag can never strand the achievements still queued behind it.
    C_Timer.After(achToast.HOLD_SEC + achToast.FADE_SEC + 0.5, function()
        achToast.Advance(serial)
    end)
end

function achToast.ShowNext()
    local entry = table_remove(achToast.queue, 1)
    if not entry then
        achToast.showing = false
        return
    end
    achToast.showing = true
    achToast.ShowNow(entry.icon, entry.title, entry.points, entry.target, entry.announce)
end

local function CreateAchToast(iconTex, title, pts, achIdOrRow)
    if #achToast.queue >= achToast.QUEUE_LIMIT then
        return
    end

    -- Gameplay callers toast right after MarkRowCompleted, which refuses permanently admin-deleted
    -- achievements; don't celebrate a completion that was blocked.
    local toastId = type(achIdOrRow) == "table" and (achIdOrRow.id or achIdOrRow.achId) or achIdOrRow
    if toastId ~= nil then
        local _, cdb = CallGetCharDB()
        if cdb and cdb.deletedByAdmin and cdb.deletedByAdmin[tostring(toastId)] then
            return
        end
    end

    -- Nothing on screen and nothing waiting means this toast opens a burst, so it is the one that gets
    -- the sound and the screenshot. Anything that lands while the queue is draining stays quiet.
    local opensBurst = (not achToast.showing) and #achToast.queue == 0

    achToast.queue[#achToast.queue + 1] = {
        icon = iconTex,
        title = title,
        points = pts,
        target = achIdOrRow,
        announce = opensBurst,
    }

    if not achToast.showing then
        achToast.ShowNext()
    end
end

if addon then
    addon.PlayAchievementSound = PlayAchievementSound
    addon.CreateAchToast = CreateAchToast
end

-- Toast-only global for /run testing (not part of HardcoreAchievements.Hooks).
_G.HardcoreAchievementsToast = CreateAchToast
