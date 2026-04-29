---------------------------------------
-- Warforged tracking
---------------------------------------
local ACH_ID = "PVPChallenge"

local _, addon = ...
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitIsPVP = UnitIsPVP
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetPVPTimer = GetPVPTimer
local IsPVPTimerRunning = IsPVPTimerRunning
local UIParent = UIParent

local pvpWarningTicker = nil
local lastWarnedMinute = nil
local pvpTimerGlowText = nil
local pvpTimerGlowIcon = nil

local function EnsurePvpTimerGlowText()
    if (pvpTimerGlowText and pvpTimerGlowIcon) or not UIParent then
        return
    end

    local glowText = UIParent:CreateFontString(nil, "BACKGROUND")
    glowText:Hide()
    glowText:SetJustifyH("CENTER")
    glowText:SetJustifyV("MIDDLE")
    glowText:SetTextColor(1, 1, 1, 0.95)

    local pulse = glowText:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")

    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.45)
    fadeOut:SetDuration(0.6)

    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetFromAlpha(0.45)
    fadeIn:SetToAlpha(1.0)
    fadeIn:SetDuration(0.6)

    glowText.pulse = pulse
    pvpTimerGlowText = glowText

    local glowIcon = UIParent:CreateTexture(nil, "BACKGROUND")
    glowIcon:SetTexture("Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsCurse.png")
    glowIcon:SetSize(100, 100)
    glowIcon:Hide()

    local iconPulse = glowIcon:CreateAnimationGroup()
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

    glowIcon.pulse = iconPulse
    pvpTimerGlowIcon = glowIcon
end

local function UpdatePvpTimerGlowText()
    if not PlayerPVPTimerText or not UIParent then
        return
    end

    EnsurePvpTimerGlowText()

    if pvpTimerGlowText then
        local font, size = PlayerPVPTimerText:GetFont()
        if font and size then
            pvpTimerGlowText:SetFont(font, size + 6, "OUTLINE")
        end
        pvpTimerGlowText:SetText(PlayerPVPTimerText:GetText() or "")
        pvpTimerGlowText:ClearAllPoints()
        pvpTimerGlowText:SetPoint("CENTER", UIParent, "TOP", 0, -30)
        pvpTimerGlowText:SetScale(2)
        pvpTimerGlowText:Show()
        if pvpTimerGlowText.pulse and not pvpTimerGlowText.pulse:IsPlaying() then
            pvpTimerGlowText.pulse:Play()
        end
    end

    if pvpTimerGlowIcon then
        pvpTimerGlowIcon:ClearAllPoints()
        pvpTimerGlowIcon:SetPoint("CENTER", pvpTimerGlowText, "CENTER", 0, 0)
        pvpTimerGlowIcon:Show()
        if pvpTimerGlowIcon.pulse and not pvpTimerGlowIcon.pulse:IsPlaying() then
            pvpTimerGlowIcon.pulse:Play()
        end
    end
end

local function RestorePvpTimerText()
    if pvpTimerGlowIcon then
        if pvpTimerGlowIcon.pulse and pvpTimerGlowIcon.pulse:IsPlaying() then
            pvpTimerGlowIcon.pulse:Stop()
        end
        pvpTimerGlowIcon:Hide()
    end

    if pvpTimerGlowText then
        if pvpTimerGlowText.pulse and pvpTimerGlowText.pulse:IsPlaying() then
            pvpTimerGlowText.pulse:Stop()
        end
        pvpTimerGlowText:SetText("")
        pvpTimerGlowText:SetScale(1)
        pvpTimerGlowText:Hide()
    end
end

local function StopPvpWarningTicker()
    if pvpWarningTicker then
        pvpWarningTicker:Cancel()
        pvpWarningTicker = nil
    end
    lastWarnedMinute = nil
    RestorePvpTimerText()
end

local function PrintWarforgedMessage(colorCode, message)
    print("|cff008066[Hardcore Achievements]|r " .. colorCode .. message .. "|r")
end

local function GetRemainingPvpMilliseconds()
    if type(GetPVPTimer) ~= "function" then
        return 0
    end

    local remainingMs = GetPVPTimer() or 0
    if remainingMs <= 0 then
        return 0
    end

    return remainingMs
end

local function GetWarningMinuteBucket(remainingMs)
    if remainingMs <= 60000 then
        return 1
    elseif remainingMs <= 120000 then
        return 2
    elseif remainingMs <= 180000 then
        return 3
    elseif remainingMs <= 240000 then
        return 4
    end

    return 5
end

local function UpdatePvpWarningTicker(cdb, announceStart)
    if not cdb then
        StopPvpWarningTicker()
        return
    end

    local rec = cdb.achievements and cdb.achievements[ACH_ID]
    local stats = cdb.stats or {}
    local state = stats.playerWarforgedPvpDropped
    local timerRunning = type(IsPVPTimerRunning) == "function" and IsPVPTimerRunning() == true
    local remainingMs = GetRemainingPvpMilliseconds()

    if (rec and (rec.completed or rec.failed)) or state ~= false or not timerRunning then
        StopPvpWarningTicker()
        return
    end

    if remainingMs <= 0 then
        StopPvpWarningTicker()
        return
    end

    UpdatePvpTimerGlowText()

    if not pvpWarningTicker then
        if announceStart then
            PrintWarforgedMessage("|cffffd100", "|cffff0000[WARNING]|r PvP has been toggled off. The Warforged achievement will fail in 5 minute(s) unless you enable PvP again.")
            lastWarnedMinute = 5
        else
            lastWarnedMinute = GetWarningMinuteBucket(remainingMs)
        end
        pvpWarningTicker = C_Timer.NewTicker(1, function()
            if not (addon and addon.GetCharDB) then
                StopPvpWarningTicker()
                return
            end

            local _, latestCdb = addon.GetCharDB()
            if not latestCdb then
                StopPvpWarningTicker()
                return
            end

            local latestRec = latestCdb.achievements and latestCdb.achievements[ACH_ID]
            local latestStats = latestCdb.stats or {}
            local latestState = latestStats.playerWarforgedPvpDropped
            local latestTimerRunning = type(IsPVPTimerRunning) == "function" and IsPVPTimerRunning() == true

            if (latestRec and (latestRec.completed or latestRec.failed)) or latestState ~= false or not latestTimerRunning then
                StopPvpWarningTicker()
                return
            end

            local latestRemainingMs = GetRemainingPvpMilliseconds()
            if latestRemainingMs <= 0 then
                StopPvpWarningTicker()
                return
            end

            UpdatePvpTimerGlowText()

            local remainingMinuteBucket = GetWarningMinuteBucket(latestRemainingMs)
            if remainingMinuteBucket <= 4 and remainingMinuteBucket >= 1 and remainingMinuteBucket < (lastWarnedMinute or 99) then
                PrintWarforgedMessage("|cffffd100", "|cffff0000[WARNING]|r YOU WILL FAIL THE WARFORGED ACHIEVEMENT IN " .. remainingMinuteBucket .. " MINUTE(S) UNLESS YOU ENABLE PVP AGAIN.")
                lastWarnedMinute = remainingMinuteBucket
            end
        end)
    end
end

local function FailWarforgedIfNeeded(cdb, refreshUI)
    if not cdb then return end

    cdb.achievements = cdb.achievements or {}
    local rec = cdb.achievements[ACH_ID]
    if not rec or (not rec.completed and not rec.failed) then
        StopPvpWarningTicker()
        if addon and addon.EnsureFailureTimestamp then
            addon.EnsureFailureTimestamp(ACH_ID)
            if refreshUI and addon.RefreshOutleveledAll then
                addon.RefreshOutleveledAll()
            end
        end
    end
end

-- playerWarforgedPvpDropped:
--   nil   = not yet verified eligible
--   false = eligible run in progress or pending first XP verification
--   true  = failed (pvp flag dropped)
--
-- playerWarforgedPvpArmed:
--   nil/false = first XP not yet verified
--   true      = first XP verified while PvP flagged; future flag drops fail it
local function SyncWarforgedState(cdb, refreshOnFail, event, unit)
    if not cdb then return end

    cdb.stats = cdb.stats or {}
    local rec = cdb.achievements and cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        return
    end

    local state = cdb.stats.playerWarforgedPvpDropped
    local armed = cdb.stats.playerWarforgedPvpArmed == true
    local level = UnitLevel("player") or 1
    local xp = UnitXP("player") or 0
    local isPvpNow = UnitIsPVP("player")
    local timerRunning = type(IsPVPTimerRunning) == "function" and IsPVPTimerRunning() == true

    if event == "PLAYER_ENTERING_WORLD" then
        if state == nil then
            if level == 1 and xp == 0 then
                cdb.stats.playerWarforgedPvpDropped = false
                cdb.stats.playerWarforgedPvpArmed = false
            elseif level > 1 or xp > 0 then
                -- Installed after run start or run started unflagged.
                FailWarforgedIfNeeded(cdb, refreshOnFail)
            end
            return
        end

        UpdatePvpWarningTicker(cdb, false)
        return
    end

    if event == "PLAYER_XP_UPDATE" then
        if armed or xp <= 0 then
            return
        end

        if state == nil then
            if level == 1 and xp == 0 then
                cdb.stats.playerWarforgedPvpDropped = false
                cdb.stats.playerWarforgedPvpArmed = false
            else
                FailWarforgedIfNeeded(cdb, refreshOnFail)
                return
            end
        end

        if isPvpNow == true or timerRunning then
            cdb.stats.playerWarforgedPvpDropped = false
            cdb.stats.playerWarforgedPvpArmed = true
            UpdatePvpWarningTicker(cdb, timerRunning)
        else
            cdb.stats.playerWarforgedPvpDropped = true
            cdb.stats.playerWarforgedPvpArmed = true
            FailWarforgedIfNeeded(cdb, refreshOnFail)
        end
        return
    end

    if event == "PLAYER_FLAGS_CHANGED" then
        if unit ~= "player" then
            return
        end

        if state ~= false then
            StopPvpWarningTicker()
            return
        end

        UpdatePvpWarningTicker(cdb, timerRunning)

        -- Only fail when the flag is truly off after the PvP timer has expired,
        -- and only after the run has armed on first XP.
        if armed and state == false and isPvpNow == false and not timerRunning then
            cdb.stats.playerWarforgedPvpDropped = true
            FailWarforgedIfNeeded(cdb, refreshOnFail)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_FLAGS_CHANGED")
f:RegisterEvent("PLAYER_LOGOUT")

local function UpdateXPEventRegistration(cdb)
    if not cdb then return end
    cdb.achievements = cdb.achievements or {}

    local rec = cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        f:UnregisterEvent("PLAYER_XP_UPDATE")
        return
    end

    if cdb.stats and cdb.stats.playerWarforgedPvpArmed == true then
        f:UnregisterEvent("PLAYER_XP_UPDATE")
        return
    end

    f:RegisterEvent("PLAYER_XP_UPDATE")
end

local function UpdateEventRegistration(cdb)
    if not cdb then return end
    cdb.achievements = cdb.achievements or {}
    cdb.stats = cdb.stats or {}

    local rec = cdb.achievements[ACH_ID]
    if rec and (rec.completed or rec.failed) then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        f:UnregisterEvent("PLAYER_XP_UPDATE")
        f:UnregisterEvent("PLAYER_FLAGS_CHANGED")
        return
    end

    -- Initialization only needs to happen once.
    if cdb.stats.playerWarforgedPvpDropped ~= nil then
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGOUT" then
        StopPvpWarningTicker()
        return
    end

    if not (addon and addon.GetCharDB) then
        return
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return
    end

    SyncWarforgedState(cdb, true, event, arg1)
    UpdateXPEventRegistration(cdb)
    UpdateEventRegistration(cdb)
end)
