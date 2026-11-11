local _, addon = ...

local Crypto = addon.AppealCrypto

local PUBLIC_MODULUS_B64 = "p0tq8MxapV5se5KmszCvqnaNKNG3mI6I1NUyq1bZANSMbMVtLW6OqgtUJeSn_AyodcGcisgwXuTqakPsRhZxV1eOiio-rRKKbiqOiW7cWBhUTsHBrE6jvWZXVGkUszUlrQSvgEu_Sw78uIOMhiAP-LOcvnWiBGntrCdhZajaQ78"

local PREFIX = "HCA:"
local VERSION = "1"
local SIG_LEN = 128
local MAX_CODE_LEN = 1024

local ERR_INVALID = "Invalid correction code"

local Appeal = {}
local publicModulus

local function IsPlayerGUID(s)
    return #s <= 64 and s:match("^Player%-%d+%-%x+$") ~= nil
end

local function ParseUInt(v, min, max)
    if not v:match("^%d+$") or #v > 6 or (#v > 1 and v:sub(1, 1) == "0") then
        return nil
    end
    local n = tonumber(v)
    if n < min or n > max then
        return nil
    end
    return n
end

local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function ParseDate(v)
    local y, m, d = v:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if not y then
        return nil
    end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if y < 2004 or y > 2099 or m < 1 or m > 12 or d < 1 then
        return nil
    end
    local maxDay = (m == 2 and y % 4 == 0) and 29 or DAYS_IN_MONTH[m] -- every 4th year is a leap year in 2004-2099
    if d > maxDay then
        return nil
    end
    return { year = y, month = m, day = d }
end

-- Option keys per operation, in the only order they may appear.
local OP_OPTIONS = {
    C = { "p", "l", "s", "d" },
    U = { "p", "l", "s", "d" },
    D = {},
    DP = {},
    UB = {},
    GO = { "n", "g" },
    GC = {},
}

local OPTION_PARSERS = {
    p = { "points", function(v) return ParseUInt(v, 0, 100000) end },
    l = { "level", function(v) return ParseUInt(v, 1, 255) end },
    s = { "solo", function(v) return v == "1" or nil end },
    d = { "date", ParseDate },
    n = { "winnerName", function(v) return #v <= 48 and (v:match("^%S+$") or v:match("^%S+ %S+$")) and not v:find("[%c,;=]") and v or nil end },
    g = { "winnerGUID", function(v) return IsPlayerGUID(v) and v or nil end },
}

local function ParseOptions(op, raw)
    local keys, opts, nextKey = OP_OPTIONS[op], {}, 1
    if raw == "" then
        return opts
    end
    for pair in (raw .. ","):gmatch("([^,]*),") do
        local key, value = pair:match("^(%a)=(.+)$")
        local idx
        for i = nextKey, #keys do
            if keys[i] == key then
                idx = i
                break
            end
        end
        if not idx then
            return nil -- malformed, unknown, repeated or out of order
        end
        nextKey = idx + 1
        local field, parse = OPTION_PARSERS[key][1], OPTION_PARSERS[key][2]
        opts[field] = parse(value)
        if opts[field] == nil then
            return nil
        end
    end
    return opts
end

-- Decodes and validates a code's structure. Does not check the signature, character or redemption state.
function Appeal.Parse(code)
    if type(code) ~= "string" then
        return nil, ERR_INVALID .. ": no code entered"
    end
    code = code:gsub("[%s`]", "")
    if code == "" then
        return nil, ERR_INVALID .. ": no code entered"
    end
    if #code > MAX_CODE_LEN then
        return nil, ERR_INVALID .. ": the code is too long"
    end
    if code:sub(1, #PREFIX) ~= PREFIX then
        return nil, ERR_INVALID .. ": it should start with " .. PREFIX
    end
    local raw = Crypto.Base64UrlDecode(code:sub(#PREFIX + 1))
    if not raw or #raw <= SIG_LEN then
        return nil, ERR_INVALID .. ": the code is incomplete or was not copied exactly"
    end
    local payload, signature = raw:sub(1, -SIG_LEN - 1), raw:sub(-SIG_LEN)

    local fields = {}
    for field in (payload .. ";"):gmatch("([^;]*);") do
        fields[#fields + 1] = field
    end
    if #fields ~= 6 or fields[1] ~= VERSION then
        return nil, ERR_INVALID .. ": unrecognized code format"
    end
    local cid, guid, op, achId, rawOpts = fields[2], fields[3], fields[4], fields[5], fields[6]

    if not (#cid == 16 and cid:match("^[%w_%-]+$")) then
        return nil, ERR_INVALID .. ": bad correction ID"
    end
    if not IsPlayerGUID(guid) then
        return nil, ERR_INVALID .. ": bad character ID"
    end
    if not OP_OPTIONS[op] then
        return nil, "Unsupported operation: " .. op
    end
    if #achId < 1 or #achId > 64 or achId:find("%c") or achId:find("^%s") or achId:find("%s$") then
        return nil, ERR_INVALID .. ": bad achievement ID"
    end
    local opts = ParseOptions(op, rawOpts)
    if not opts or (op == "GO" and not (opts.winnerName and opts.winnerGUID)) then
        return nil, ERR_INVALID .. ": bad options"
    end

    return { cid = cid, guid = guid, op = op, achId = achId, opts = opts, payload = payload, signature = signature }
end

local function Apply(token)
    local ops, o = addon.AdminOps, token.opts
    if token.op == "C" or token.op == "U" then
        return ops.CompleteAchievement(token.achId, o, token.op == "U")
    elseif token.op == "D" or token.op == "DP" then
        return ops.DeleteAchievement(token.achId, token.op == "DP")
    elseif token.op == "UB" then
        return ops.UnbanAchievement(token.achId)
    elseif token.op == "GO" then
        return ops.GuildFirstOverride(token.achId, o.winnerName, o.winnerGUID)
    elseif token.op == "GC" then
        return ops.GuildFirstClear(token.achId)
    end
    return false, "Unsupported operation"
end

local function GetPlayerGUID()
    local guid = UnitGUID("player")
    if guid == nil or (issecretvalue and issecretvalue(guid)) then
        return nil
    end
    return guid
end

-- Verifies and applies a code. Returns ok, message. A code is recorded as redeemed only after it applies.
function Appeal.Redeem(code)
    local token, err = Appeal.Parse(code)
    if not token then
        return false, err
    end

    publicModulus = publicModulus or Crypto.Base64UrlDecode(PUBLIC_MODULUS_B64)
    if not Crypto.VerifyRSASHA256(publicModulus, token.payload, token.signature) then
        return false, "Invalid signature: the code was changed or was not issued for this addon version"
    end

    local playerGUID = GetPlayerGUID()
    if not playerGUID then
        return false, "Character information is not available yet - try again in a moment"
    end
    if token.guid ~= playerGUID then
        return false, "Incorrect character: this code was issued for " .. token.guid .. ", not this character"
    end

    local _, cdb = addon.GetCharDB()
    if not cdb then
        return false, "Character data is not loaded yet - try again in a moment"
    end
    cdb.redeemedAppeals = cdb.redeemedAppeals or {}
    local previous = cdb.redeemedAppeals[token.cid]
    if previous then
        return false, "Already redeemed" .. (previous.at and (" on " .. date("%Y-%m-%d %H:%M", previous.at)) or "")
    end

    local called, ok, msg = pcall(Apply, token)
    if not called then
        return false, "Failed to apply correction (unexpected error): " .. tostring(ok)
    end
    if not ok then
        return false, "Failed to apply correction: " .. tostring(msg)
    end

    cdb.redeemedAppeals[token.cid] = { at = time(), op = token.op, achId = token.achId }
    return true, msg or "Correction applied"
end

-- ---------------------------------------------------------------------------
-- Appeal window: shows the character's GUID for the admin and accepts a code.
-- ---------------------------------------------------------------------------
local frame

local function CreateAppealWindow()
    frame = CreateFrame("Frame", "HardcoreAchievementsAppealFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(440, 285)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText("Hardcore Achievements - Appeal")

    local character = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    character:SetPoint("TOPLEFT", 16, -36)
    frame.character = character

    local guidLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guidLabel:SetPoint("TOPLEFT", character, "BOTTOMLEFT", 0, -10)
    guidLabel:SetText("Character ID (send this to the admin with your appeal)")

    local guidBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    guidBox:SetSize(400, 20)
    guidBox:SetPoint("TOPLEFT", guidLabel, "BOTTOMLEFT", 6, -4)
    guidBox:SetAutoFocus(false)
    guidBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(frame.guid or "")
            self:HighlightText()
        end
    end)
    guidBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    guidBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.guidBox = guidBox

    local codeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    codeLabel:SetPoint("TOPLEFT", guidBox, "BOTTOMLEFT", -6, -14)
    codeLabel:SetText("Paste your redemption code below")

    local codeBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    codeBg:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 0, -4)
    codeBg:SetSize(408, 120)
    codeBg:SetFrameLevel(frame:GetFrameLevel() + 1)
    codeBg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 64,
        edgeSize = 16,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3,
        },
    })
    codeBg:SetBackdropColor(0, 0, 0, 1)
    codeBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetFrameLevel(codeBg:GetFrameLevel() + 1)
    scroll:SetPoint("TOPLEFT", codeBg, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", codeBg, "BOTTOMRIGHT", -26, 6)

    local codeBox = CreateFrame("EditBox", nil, scroll)
    codeBox:SetMultiLine(true)
    codeBox:SetAutoFocus(false)
    codeBox:SetMaxLetters(MAX_CODE_LEN * 2)
    codeBox:SetFontObject(ChatFontNormal)
    codeBox:SetWidth(376)
    codeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(codeBox)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() codeBox:SetFocus() end)
    frame.codeBox = codeBox

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", codeBg, "BOTTOMLEFT", 0, -10)
    status:SetWidth(300)
    status:SetJustifyH("LEFT")
    frame.status = status

    local redeem = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    redeem:SetSize(100, 24)
    redeem:SetPoint("BOTTOMRIGHT", -14, 12)
    redeem:SetText("Redeem")
    redeem:SetScript("OnClick", function()
        local ok, msg = Appeal.Redeem(codeBox:GetText())
        if ok then
            status:SetTextColor(0.2, 1, 0.2)
            codeBox:SetText("")
        else
            status:SetTextColor(1, 0.3, 0.3)
        end
        status:SetText(msg)
    end)
end

function Appeal.ShowWindow()
    if not frame then
        CreateAppealWindow()
    end
    local name = UnitName("player") or "?"
    local realm = (addon.GetPlayerRealmLabel and addon.GetPlayerRealmLabel()) or GetRealmName() or "?"
    frame.guid = GetPlayerGUID() or ""
    frame.character:SetText(name .. " - " .. realm)
    frame.guidBox:SetText(frame.guid)
    frame.status:SetText("")
    frame:Show()
    frame.guidBox:SetFocus()
end

addon.Appeal = Appeal
