#!/usr/bin/env python3
"""Appeal code test suite.

Runs the addon's real Lua files (Utils/CommandHandler.lua, Utils/AppealCrypto.lua, Utils/AppealCodes.lua)
inside Lua 5.1 via lupa, with stubbed WoW APIs, and checks them against Python's `cryptography`.
A throwaway test key is substituted into the AppealCodes.lua source text before loading;
the addon itself has no key-override hook.

Requires: pip install cryptography lupa
"""
import base64
import hashlib
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import lupa.lua51 as lupa51
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding, rsa

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
VECTORS = HERE / "vectors"
SIGNER = HERE.parent / "hca_appeal.py"

PASSED = 0
FAILED = 0


def check(cond, label):
    global PASSED, FAILED
    if cond:
        PASSED += 1
    else:
        FAILED += 1
        print("  FAIL:", label)


def section(name):
    print(f"- {name}")


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


TEST_KEY = rsa.generate_private_key(public_exponent=65537, key_size=1024)
OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=1024)


def modulus_of(key) -> bytes:
    pub = key.public_key().public_numbers()
    return pub.n.to_bytes((pub.n.bit_length() + 7) // 8, "big")


def sign(payload: bytes, key=TEST_KEY) -> bytes:
    return key.sign(payload, padding.PKCS1v15(), hashes.SHA256())


def make_code(payload: str, key=TEST_KEY) -> str:
    raw = payload.encode("utf-8")
    return "HCA:" + b64u(raw + sign(raw, key))


GUID = "Player-4395-0207A3F9"


def P(op="C", ach="Ragefire", opts="", guid=GUID, cid=None, ver="1"):
    return ";".join([ver, cid or b64u(secrets.token_bytes(12)), guid, op, ach, opts])


# ---------------------------------------------------------------------------
# Lua environment
# ---------------------------------------------------------------------------
PRELUDE = r"""
PRINTS = {}
print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
  PRINTS[#PRINTS + 1] = table.concat(t, " ")
end
time, date, tinsert = os.time, os.date, table.insert
UISpecialFrames, SlashCmdList, ChatFontNormal = {}, {}, {}
AUCTION_TIME_LEFT0 = ""
PLAYER_GUID = "Player-4395-0207A3F9"
UnitGUID = function(u) if u == "player" then return PLAYER_GUID end end
UnitName = function() return "Tester" end
UnitLevel = function() return 42 end
GetRealmName = function() return "Doomhowl" end
IsInRaid = function() return false end
IsInGroup = function() return false end

local noop = function() end
local methods = {}
local Mock = { __index = function(t, k)
  if methods[k] then return methods[k] end
  if type(k) == "string" and k:match("^%u") then return noop end
end }
FRAMES = {}
function NewMock(name)
  local o = setmetatable({ scripts = {}, name = name }, Mock)
  FRAMES[#FRAMES + 1] = o
  return o
end
methods.SetScript = function(self, n, fn) self.scripts[n] = fn end
methods.GetScript = function(self, n) return self.scripts[n] end
methods.SetText = function(self, t) self.text = t end
methods.GetText = function(self) return self.text end
methods.Show = function(self) self.shown = true end
methods.Hide = function(self) self.shown = false end
methods.IsShown = function(self) return self.shown end
methods.GetName = function(self) return self.name end
methods.CreateFontString = function() return NewMock() end
methods.CreateTexture = function() return NewMock() end
methods.RegisterEvent = function(self, e) self.events = self.events or {}; self.events[e] = true end
CreateFrame = function(kind, name)
  local f = NewMock(name)
  f.kind = kind
  if name then _G[name] = f end
  return f
end
function FIRE_LOGIN()
  for _, f in ipairs(FRAMES) do
    if f.events and f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
  end
end
function FIND_BUTTON(text)
  for _, f in ipairs(FRAMES) do if f.kind == "Button" and f.text == text then return f end end
end

COMM = {}
local AceComm = { RegisterComm = function(self, prefix, fn) COMM[prefix] = fn end, SendCommMessage = noop }
local LibSerialize = { SerializeEx = function() return "x" end, Deserialize = function() return false end }
LibStub = function(name)
  if name == "AceComm-3.0" then return AceComm end
  if name == "LibSerialize" then return LibSerialize end
  error("unexpected library " .. name)
end

HardcoreAchievementsDB = { adminSecretKey = "legacysecret1234", adminNonces = { x = 1 }, adminCommands = { {} }, adminLog = {}, debugEnabled = true }
CDB = { achievements = {}, progress = {} }
ADDON = {}
ADDON.GetCharDB = function() return HardcoreAchievementsDB, CDB end
ADDON.IsSelfFound = function() return false end
ADDON.GetPresetMultiplier = function() return 1.0 end
ADDON.ClassColor = function() return "" end
ADDON.FormatTimestamp = function(ts) return tostring(ts) end
local function row(id, title, pts, soloOk, gf)
  return { id = id, achId = id, title = title, points = pts, originalPoints = pts, allowSoloDouble = soloOk, _def = { isGuildFirst = gf } }
end
ADDON.AchievementPanel = { achievements = {
  row("Sha'tari Skyguard", "The Sha'tari Skyguard", 10, true), row("Ragefire", "Ragefire Chasm", 5, true),
  row("Level60", "Level 60", 20, false), row("Molten Core First", "Molten Core (Guild First)", 50, false, true),
} }
HARDCORE = false
C_GameRules = { IsHardcoreActive = function() return HARDCORE end }
PLAYER_IS_SOLO = false
ADDON.GuildFirst_DefById = { ["Molten Core First"] = {} }
GF = { inGuild = true, claims = {} }
function GF:OverrideClaim(id, name, guid)
  if not self.inGuild then return false, "Not in a guild" end
  self.claims[id] = name .. "/" .. guid
  return true
end
function GF:ClearClaim(id)
  if not self.inGuild then return false, "Not in a guild" end
  self.claims[id] = "cleared"
  return true
end
ADDON.GuildFirst = GF
MARK_ERROR = false
-- Stand-ins for HardcoreAchievements.lua (same contracts: pointsAtKill wins, allowSoloDouble rows are
-- recomputed and doubled when solo, the permanent-delete tombstone blocks completion, and with no tracked
-- solo flag an allowSoloDouble row samples whether the player is currently solo).
ADDON.ComputeCompletionPoints = function(r, p, wasSolo, rec)
  if p and p.pointsAtKill then return p.pointsAtKill end
  if r.allowSoloDouble then return r.originalPoints * (wasSolo and 2 or 1) end
  return r.points
end
ADDON.MarkRowCompleted = function(r, cdb)
  if MARK_ERROR then error("simulated failure") end
  if r.completed then return end
  local id = r.achId or r.id
  if cdb.deletedByAdmin and cdb.deletedByAdmin[tostring(id)] then return end
  r.completed = true
  local p = cdb.progress and cdb.progress[id]
  local wasSolo = false
  if p and (p.soloKill ~= nil or p.soloQuest ~= nil) then
    wasSolo = (p.soloKill or p.soloQuest) and true or false
  elseif r.allowSoloDouble then
    wasSolo = PLAYER_IS_SOLO
  end
  cdb.achievements[id] = cdb.achievements[id] or {}
  local rec = cdb.achievements[id]
  rec.completed, rec.completedAt, rec.level = true, time(), UnitLevel("player")
  rec.wasSolo = wasSolo
  rec.points = ADDON.ComputeCompletionPoints(r, p, wasSolo, rec)
  r.points = rec.points
  if cdb.progress then cdb.progress[id] = nil end
end

function DUMP(v)
  if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = "[" .. DUMP(k) .. "]=" .. DUMP(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end
function STATE()
  local rows = {}
  for i, r in ipairs(ADDON.AchievementPanel.achievements) do rows[i] = { r.completed or false, r.points } end
  return DUMP(CDB) .. DUMP(GF.claims) .. DUMP(rows)
end
function REDEEM(code) return ADDON.Appeal.Redeem(code) end
"""

ADDON_FILES = ["Utils/CommandHandler.lua", "Utils/AppealCrypto.lua", "Utils/AppealCodes.lua"]
MODULUS_RE = re.compile(rb'local PUBLIC_MODULUS_B64 = "[A-Za-z0-9_-]*"')


class Env:
    def __init__(self, modulus=TEST_KEY, setup=""):
        self.lua = lupa51.LuaRuntime(encoding=None, unpack_returned_tuples=True)
        self.lua.execute(PRELUDE.encode())
        self.lua.execute(setup.encode())
        g = self.lua.globals()
        for rel in ADDON_FILES:
            src = (ROOT / rel).read_bytes()
            if rel.endswith("AppealCodes.lua") and modulus is not None:
                if not isinstance(modulus, bytes):
                    modulus = modulus_of(modulus)
                src, n = MODULUS_RE.subn(b'local PUBLIC_MODULUS_B64 = "' + b64u(modulus).encode() + b'"', src)
                assert n == 1
            res = g.loadstring(src, b"@" + rel.encode())
            fn = res[0] if isinstance(res, tuple) else res
            if fn is None:
                raise RuntimeError(f"{rel}: {res[1].decode()}")
            fn(b"HardcoreAchievements", g.ADDON)

    def run(self, lua_code):
        return self.lua.execute(lua_code.encode())

    def eval(self, expr):
        v = self.lua.eval(expr.encode())
        return v.decode() if isinstance(v, bytes) else v

    def redeem(self, code):
        ok, msg = self.lua.globals().REDEEM(code.encode("utf-8") if isinstance(code, str) else code)
        return bool(ok), (msg.decode() if isinstance(msg, bytes) else msg)

    def state(self):
        return self.eval("STATE()")

    def crypto(self, name):
        return self.lua.eval(f"ADDON.AppealCrypto.{name}".encode())


# ---------------------------------------------------------------------------
# Crypto primitives
# ---------------------------------------------------------------------------
def test_sha256(env):
    section("SHA-256 (NIST examples + hashlib cross-check across padding boundaries)")
    sha = env.crypto("SHA256")
    nist = {
        b"": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        b"abc": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq":
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
        b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu":
            "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1",
    }
    for msg, digest in nist.items():
        check(sha(msg).hex() == digest, f"NIST SHA-256 of {msg[:10]!r}")
    check(sha(b"a" * 100000) == hashlib.sha256(b"a" * 100000).digest(), "100000 x 'a'")
    for n in range(0, 260):
        m = os.urandom(n)
        check(sha(m) == hashlib.sha256(m).digest(), f"random length {n}")
    check(sha(bytes(range(256)) * 4) == hashlib.sha256(bytes(range(256)) * 4).digest(), "all byte values")


def test_base64(env):
    section("base64url strict decoding")
    dec = env.crypto("Base64UrlDecode")
    for n in range(0, 70):
        data = os.urandom(n)
        check(dec(b64u(data).encode()) == data, f"roundtrip length {n}")
    for bad in [b"QQ==", b"QQ=", b"a+b/", b"A", b"AAAAA", b"AB", b"AAB", b"QR", b"Q Q", b"Q\nQ", b"Q\x00Q", b"\xc3\xa9AA"]:
        check(dec(bad) is None, f"reject {bad!r}")


def parse_nist(path):
    out, n, e, alg, msg = [], None, None, None, None
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("n = "):
            n = bytes.fromhex(line[4:])
        elif line.startswith("e = "):
            e = int(line[4:], 16)
        elif line.startswith("SHAAlg = "):
            alg = line[9:]
        elif line.startswith("Msg = "):
            msg = bytes.fromhex(line[6:])
        elif line.startswith("S = ") and alg == "SHA256" and e == 65537:
            out.append((n, msg, bytes.fromhex(line[4:])))
    return out


def flip(data: bytes, i: int, bit=1) -> bytes:
    b = bytearray(data)
    b[i] ^= bit
    return bytes(b)


def test_rsa_vectors(env):
    verify = env.crypto("VerifyRSASHA256")

    section("NIST CAVP SigGen15 (PKCS#1 v1.5, SHA-256) - valid and bit-flipped")
    vectors = parse_nist(VECTORS / "SigGen15_186-2.rsp") + parse_nist(VECTORS / "SigGen15_186-3.rsp")
    sizes = sorted({len(n) * 8 for n, _, _ in vectors})
    print(f"  {len(vectors)} vectors, modulus sizes {sizes}")
    check(len(vectors) >= 30 and 1024 in sizes, "NIST vectors loaded (incl. 1024-bit)")
    for idx, (n, msg, sig) in enumerate(vectors):
        check(verify(n, msg, sig) is True, f"NIST vector {idx} ({len(n) * 8}-bit) valid")
        check(verify(n, flip(msg, idx % len(msg)), sig) is False, f"NIST vector {idx} message bit flip")
        check(verify(n, msg, flip(sig, idx % len(sig))) is False, f"NIST vector {idx} signature bit flip")

    section("Wycheproof rsa_signature_2048_sha256 (valid, invalid and malformed signatures)")
    j = json.loads((VECTORS / "rsa_signature_2048_sha256_test.json").read_text())
    counts = {"valid": 0, "invalid": 0, "acceptable": 0, "acceptable-accepted": 0}
    for group in j["testGroups"]:
        pk = group["publicKey"]
        if int(pk["publicExponent"], 16) != 65537:
            continue
        n = int(pk["modulus"], 16).to_bytes(group["keySize"] // 8, "big")
        for t in group["tests"]:
            got = verify(n, bytes.fromhex(t["msg"]), bytes.fromhex(t["sig"])) is True
            if t["result"] == "acceptable":
                counts["acceptable"] += 1
                counts["acceptable-accepted"] += got
                continue
            counts[t["result"]] += 1
            check(got == (t["result"] == "valid"), f"Wycheproof tcId {t['tcId']} ({t['result']}: {t['comment']})")
    print(f"  {counts}")

    section("Random 1024-bit keys vs cryptography (valid + tampered)")
    keys = [TEST_KEY, OTHER_KEY] + [rsa.generate_private_key(65537, 1024) for _ in range(3)]
    for i in range(60):
        key = keys[i % len(keys)]
        n = modulus_of(key)
        msg = os.urandom(i * 5)
        sig = sign(msg, key)
        check(verify(n, msg, sig) is True, f"random valid {i}")
        check(verify(n, msg, flip(sig, i % 128, 1 << (i % 8))) is False, f"random sig bit {i}")
        check(verify(n, msg + b"\0", sig) is False, f"random extended msg {i}")
        check(verify(modulus_of(keys[(i + 1) % len(keys)]), msg, sig) is False, f"random wrong key {i}")

    section("Malformed signatures and wrong schemes (1024-bit)")
    n = modulus_of(TEST_KEY)
    N = int.from_bytes(n, "big")
    msg = b"1;abc"
    sig = sign(msg)
    pss = TEST_KEY.sign(msg, padding.PSS(padding.MGF1(hashes.SHA256()), 32), hashes.SHA256())
    sha1 = TEST_KEY.sign(msg, padding.PKCS1v15(), hashes.SHA1())
    sha512 = TEST_KEY.sign(msg, padding.PKCS1v15(), hashes.SHA512())
    cases = {
        "empty": b"",
        "127 bytes": sig[1:],
        "129 bytes (leading zero)": b"\0" + sig,
        "129 bytes (trailing byte)": sig + b"\0",
        "all zero": bytes(128),
        "one": (1).to_bytes(128, "big"),
        "n - 1": (N - 1).to_bytes(128, "big"),
        "s = n": n,
        "s = n + 1": (N + 1).to_bytes(128, "big"),
        "s + n (> modulus, same residue)": (int.from_bytes(sig, "big") + N).to_bytes(129, "big")[-128:]
            if int.from_bytes(sig, "big") + N < 2 ** 1024 else n,
        "all 0xFF": b"\xff" * 128,
        "RSA-PSS signature": pss,
        "PKCS#1 v1.5 SHA-1 signature": sha1,
        "PKCS#1 v1.5 SHA-512 signature": sha512,
    }
    for label, bad in cases.items():
        check(verify(n, msg, bad) is False, f"reject {label}")
    check(verify(n, msg, sig) is True, "control: real signature still valid")
    check(verify(n, None, sig) is False and verify(None, msg, sig) is False, "reject non-string inputs")

    # Correctly "signed" (raw RSA with the private key) but malformed encoded blocks
    d = TEST_KEY.private_numbers().d
    digest = hashlib.sha256(msg).digest()
    info = bytes.fromhex("3031300d060960864801650304020105000420")

    def raw_sign(em: bytes) -> bytes:
        return pow(int.from_bytes(em, "big"), d, N).to_bytes(128, "big")

    pad = 128 - 3 - len(info) - 32
    good = b"\x00\x01" + b"\xff" * pad + b"\x00" + info + digest
    check(verify(n, msg, raw_sign(good)) is True, "raw-signed correct block verifies")
    forged = {
        "block type 02": b"\x00\x02" + b"\xff" * pad + b"\x00" + info + digest,
        "padding byte not FF": b"\x00\x01" + b"\xff" * (pad - 1) + b"\xfe\x00" + info + digest,
        "missing NULL params": b"\x00\x01" + b"\xff" * (pad + 2) + b"\x00"
            + bytes.fromhex("302f300b0609608648016503040201") + b"\x04\x20" + digest,
        "garbage after digest": b"\x00\x01" + b"\xff" * (pad - 4) + b"\x00" + info + digest + b"\0\0\0\0",
        "short padding + trailing garbage": b"\x00\x01" + b"\xff" * 8 + b"\x00" + info + digest + bytes(pad - 8),
        "SHA-1 OID": b"\x00\x01" + b"\xff" * (128 - 3 - 35) + b"\x00"
            + bytes.fromhex("3021300906052b0e03021a05000414") + hashlib.sha1(msg).digest(),
        "no zero separator": b"\x00\x01" + b"\xff" * (pad + 1) + info + digest,
        "wrong digest": b"\x00\x01" + b"\xff" * pad + b"\x00" + info + hashlib.sha256(msg + b"x").digest(),
    }
    for label, em in forged.items():
        check(len(em) == 128 and verify(n, msg, raw_sign(em)) is False, f"reject forged block: {label}")


# ---------------------------------------------------------------------------
# Appeal codes end to end
# ---------------------------------------------------------------------------
def rec(env, ach, field):
    return env.eval(f'(CDB.achievements[{json.dumps(ach)}] or {{}}).{field}')


def test_operations():
    section("All admin operations through the real CommandHandler executors")

    e = Env()
    ok, msg = e.redeem(make_code(P("C", "Ragefire")))
    check(ok and rec(e, "Ragefire", "completed") is True and rec(e, "Ragefire", "points") == 5, f"complete: {msg}")

    e = Env()
    ok, msg = e.redeem(make_code(P("C", "Ragefire", "p=77")))
    check(ok and rec(e, "Ragefire", "points") == 77, f"complete with points: {msg}")

    e = Env()
    ok, msg = e.redeem(make_code(P("C", "Ragefire", "l=17")))
    check(ok and rec(e, "Ragefire", "level") == 17, f"complete with level: {msg}")

    e = Env()
    ok, msg = e.redeem(make_code(P("C", "Ragefire", "s=1")))
    check(ok and rec(e, "Ragefire", "wasSolo") is True, f"complete solo: {msg}")

    e = Env()
    e.run('CDB.progress["Ragefire"] = { failedAt = os.time({ year = 2025, month = 6, day = 2, hour = 13, min = 14, sec = 15 }) }')
    ok, msg = e.redeem(make_code(P("C", "Sha'tari Skyguard", "d=20240315")))
    ok2, msg2 = e.redeem(make_code(P("C", "Ragefire", "d=20240229")))
    t1 = e.eval('os.date("%Y-%m-%d %H:%M:%S", CDB.achievements["Sha\'tari Skyguard"].completedAt)')
    t2 = e.eval('os.date("%Y-%m-%d %H:%M:%S", CDB.achievements["Ragefire"].completedAt)')
    check(ok and t1 == "2024-03-15 00:00:00", f"complete backdated, apostrophe ID: {msg} {t1}")
    check(ok2 and t2 == "2024-02-29 13:14:15", f"backdate keeps original time of day: {msg2} {t2}")

    e = Env()
    e.redeem(make_code(P("C", "Ragefire")))
    ok, msg = e.redeem(make_code(P("U", "Ragefire", "p=99,l=60,s=1,d=20250101")))
    check(ok and rec(e, "Ragefire", "points") == 99 and rec(e, "Ragefire", "level") == 60
          and rec(e, "Ragefire", "wasSolo") is True, f"force update: {msg}")
    ok, msg = e.redeem(make_code(P("C", "Ragefire")))
    check(not ok and "already completed" in msg, f"plain complete of completed achievement fails: {msg}")

    e = Env()
    e.redeem(make_code(P("C", "Ragefire")))
    ok, msg = e.redeem(make_code(P("D", "Ragefire")))
    check(ok and rec(e, "Ragefire", "completed") is None and e.eval("CDB.deletedByAdmin == nil or CDB.deletedByAdmin.Ragefire == nil")
          and e.eval("ADDON.AchievementPanel.achievements[2].completed") is False, f"delete: {msg}")

    e = Env()
    e.redeem(make_code(P("C", "Ragefire")))
    ok, msg = e.redeem(make_code(P("DP", "Ragefire")))
    check(ok and e.eval("CDB.deletedByAdmin.Ragefire") is True, f"delete permanent: {msg}")
    e.run("ADDON.MarkRowCompleted(ADDON.AchievementPanel.achievements[2], CDB)")
    check(rec(e, "Ragefire", "completed") is None, "permanent delete blocks normal re-earn")
    ok, msg = e.redeem(make_code(P("UB", "Ragefire")))
    check(ok and e.eval("CDB.deletedByAdmin.Ragefire") is None and "unbanned" in msg, f"unban: {msg}")
    ok, msg = e.redeem(make_code(P("UB", "Ragefire")))
    check(ok and "was not banned" in msg, f"unban when not banned: {msg}")

    e = Env()
    ok, msg = e.redeem(make_code(P("GO", "Molten Core First", "n=Bob,g=Player-4395-00AB12CD")))
    check(ok and e.eval('GF.claims["Molten Core First"]') == "Bob/Player-4395-00AB12CD", f"guild first override: {msg}")
    ok, msg = e.redeem(make_code(P("GC", "Molten Core First")))
    check(ok and e.eval('GF.claims["Molten Core First"]') == "cleared", f"guild first clear: {msg}")


def test_solo_and_partial_updates():
    section("Solo is explicit, eligibility enforced, points recalculated")
    e = Env()
    e.run("PLAYER_IS_SOLO = true")
    e.run('CDB.progress["Ragefire"] = { soloKill = true, pointsAtKill = 10 }')
    ok, msg = e.redeem(make_code(P("C", "Ragefire")))
    check(ok and rec(e, "Ragefire", "wasSolo") is False and rec(e, "Ragefire", "points") == 5,
          f"complete without solo is not solo, even while solo or with tracked solo progress: {msg}")
    check(msg == "Ragefire Chasm was completed", f"message uses the achievement name: {msg}")

    e = Env()
    ok, msg = e.redeem(make_code(P("C", "Sha'tari Skyguard", "s=1")))
    check(ok and rec(e, "Sha'tari Skyguard", "wasSolo") is True and rec(e, "Sha'tari Skyguard", "points") == 20,
          f"solo completion doubles points automatically: {msg}")
    before = e.state()
    ok, msg = e.redeem(make_code(P("C", "Level60", "s=1")))
    check(not ok and "Level 60 is not eligible for solo" in msg and e.state() == before,
          f"solo on ineligible achievement rejected, not consumed: {msg}")
    e.run("HARDCORE = true")
    ok, msg = e.redeem(make_code(P("C", "Ragefire", "s=1")))
    check(not ok and "not eligible" in msg, f"solo rejected on hardcore without self-found: {msg}")
    e = Env(setup="HARDCORE = true; ADDON.IsSelfFound = function() return true end")
    ok, msg = e.redeem(make_code(P("C", "Ragefire", "s=1")))
    check(ok and rec(e, "Ragefire", "wasSolo") is True, f"solo allowed on hardcore when self-found: {msg}")

    section("Updates change only the supplied fields")

    def completed_env(opts="s=1,d=20240315"):
        env = Env()
        env.run('CDB.progress["Sha\'tari Skyguard"] = { failedAt = os.time({ year = 2025, month = 6, day = 2, hour = 9, min = 8, sec = 7 }) }')
        ok_, msg_ = env.redeem(make_code(P("C", "Sha'tari Skyguard", opts)))
        assert ok_, msg_
        return env

    def snapshot(env):
        return {f: rec(env, "Sha'tari Skyguard", f) for f in ("points", "level", "wasSolo", "completedAt")}

    e = completed_env()
    base = snapshot(e)
    ok, msg = e.redeem(make_code(P("U", "Sha'tari Skyguard", "l=40")))
    after = snapshot(e)
    check(ok and after["level"] == 40 and {k: after[k] for k in after if k != "level"} == {k: base[k] for k in base if k != "level"},
          f"level-only update keeps points, date and solo: {msg} {after}")

    e = completed_env()
    base = snapshot(e)
    ok, msg = e.redeem(make_code(P("U", "Sha'tari Skyguard", "p=15")))
    after = snapshot(e)
    check(ok and after["points"] == 15 and after["wasSolo"] is True and after["level"] == base["level"]
          and after["completedAt"] == base["completedAt"], f"points-only update keeps solo, level and date: {msg} {after}")
    check(e.eval('ADDON.AchievementPanel.achievements[1].points') == 15, "points update reflected on the row")

    e = completed_env()
    base = snapshot(e)
    ok, msg = e.redeem(make_code(P("U", "Sha'tari Skyguard", "d=20230101")))
    after = snapshot(e)
    when = e.eval('os.date("%Y-%m-%d %H:%M:%S", CDB.achievements["Sha\'tari Skyguard"].completedAt)')
    check(ok and when == "2023-01-01 09:08:07" and after["points"] == base["points"] and after["level"] == base["level"]
          and after["wasSolo"] is True, f"date-only update keeps the time of day and other fields: {msg} {when}")

    e = completed_env(opts="")
    ok, msg = e.redeem(make_code(P("U", "Sha'tari Skyguard", "s=1")))
    check(ok and rec(e, "Sha'tari Skyguard", "wasSolo") is True and rec(e, "Sha'tari Skyguard", "points") == 20,
          f"update --solo recalculates points (10 -> 20): {msg}")

    e = completed_env(opts="")
    ok, msg = e.redeem(make_code(P("U", "Sha'tari Skyguard", "p=25,s=1")))
    check(ok and rec(e, "Sha'tari Skyguard", "wasSolo") is True and rec(e, "Sha'tari Skyguard", "points") == 25,
          f"update --solo --points: explicit points win: {msg}")

    e = completed_env(opts="")
    e.run("ADDON.AchievementPanel.achievements[3].completed = true; CDB.achievements.Level60 = { completed = true, points = 20, level = 42 }")
    before = e.state()
    ok, msg = e.redeem(make_code(P("U", "Level60", "s=1")))
    check(not ok and "not eligible" in msg and e.state() == before, f"update --solo on ineligible achievement rejected: {msg}")

    e = completed_env(opts="l=30,s=1,d=20240315")
    state_without_log = "(function() local r = CDB.redeemedAppeals; CDB.redeemedAppeals = nil; local s = STATE(); CDB.redeemedAppeals = r; return s end)()"
    before = e.eval(state_without_log)
    for opts in ("", "s=1", "p=20", "l=30", "d=20240315", "p=20,l=30,s=1,d=20240315"):
        ok, msg = e.redeem(make_code(P("U", "Sha'tari Skyguard", opts)))
        check(ok and msg == "The Sha'tari Skyguard is already up to date", f"no-op update ({opts or 'no options'}): {msg}")
    check(e.eval(state_without_log) == before, "no-op updates leave the achievement data untouched")

    section("No chat output from appeal redemption")
    e = Env()
    for code in [make_code(P("C", "Ragefire")), make_code(P("C", "Ragefire")), "garbage",
                 make_code(P("C", "Ragefire", guid="Player-1-AB")), make_code(P("C", "Nope")),
                 make_code(P("U", "Ragefire", "l=12")), make_code(P("DP", "Ragefire")), make_code(P("UB", "Ragefire"))]:
        e.redeem(code)
    check(e.eval("#PRINTS") == 0, f"nothing printed: {e.eval('PRINTS[1]')}")

    section("Permanent deletion")
    e = Env()
    e.redeem(make_code(P("C", "Ragefire")))
    e.redeem(make_code(P("D", "Ragefire")))
    e.run("ADDON.MarkRowCompleted(ADDON.AchievementPanel.achievements[2], CDB)")
    check(rec(e, "Ragefire", "completed") is True, "temporary delete does not block earning again")

    e = Env()
    e.redeem(make_code(P("C", "Ragefire")))
    ok, msg = e.redeem(make_code(P("DP", "Ragefire")))
    check(ok and "permanently removed" in msg and "Ragefire Chasm" in msg, f"delete permanent message: {msg}")
    saved = e.eval("DUMP(CDB)")
    e2 = Env()
    e2.run("CDB = " + saved)
    e2.run("ADDON.MarkRowCompleted(ADDON.AchievementPanel.achievements[2], CDB)")
    check(rec(e2, "Ragefire", "completed") is None and e2.eval("CDB.deletedByAdmin.Ragefire") is True,
          "ban survives reload and blocks normal completion")

    e2.run("ADDON.MarkRowCompleted = function() end")
    ok, msg = e2.redeem(make_code(P("C", "Ragefire")))
    check(not ok and e2.eval("CDB.deletedByAdmin.Ragefire") is True, f"failed admin completion keeps the ban: {msg}")

    e = Env()
    e.run("CDB = " + saved)
    ok, msg = e.redeem(make_code(P("C", "Ragefire")))
    check(ok and rec(e, "Ragefire", "completed") is True and e.eval("CDB.deletedByAdmin.Ragefire") is None,
          f"signed admin completion overrides (and clears) the ban: {msg}")

    e = Env()
    e.run("CDB = " + saved)
    ok, msg = e.redeem(make_code(P("UB", "Ragefire")))
    e.run("ADDON.MarkRowCompleted(ADDON.AchievementPanel.achievements[2], CDB)")
    check(ok and rec(e, "Ragefire", "completed") is True, f"unban restores normal earning: {msg}")


def test_redemption_rules():
    section("GUID binding, single use, failure does not consume, persistence")
    e = Env()
    code = make_code(P("C", "Ragefire"))
    other = make_code(P("C", "Ragefire", guid="Player-4395-0207A3FA"))
    before = e.state()
    ok, msg = e.redeem(other)
    check(not ok and msg.startswith("Incorrect character") and e.state() == before, f"wrong GUID rejected: {msg}")

    e.run("issecretvalue = function() return true end")
    ok, msg = e.redeem(code)
    check(not ok and e.state() == before, f"secret GUID value rejected: {msg}")
    e.run("issecretvalue = nil; PLAYER_GUID = nil")
    ok, msg = e.redeem(code)
    check(not ok and e.state() == before, f"missing GUID rejected: {msg}")
    e.run('PLAYER_GUID = "Player-4395-0207A3F9"')

    ok, msg = e.redeem(code)
    check(ok, f"first redemption: {msg}")
    redeemed = e.eval("DUMP(CDB.redeemedAppeals)")
    check('"C"' in redeemed and '"Ragefire"' in redeemed, f"redemption recorded: {redeemed}")
    ok, msg = e.redeem(code)
    check(not ok and msg.startswith("Already redeemed"), f"replay rejected: {msg}")
    ok, msg = e.redeem("  " + code[:40] + "\n`" + code[40:] + "`\r\n")
    check(not ok and msg.startswith("Already redeemed"), f"replay with whitespace/backticks rejected: {msg}")

    e2 = Env()
    e2.run("CDB.redeemedAppeals = " + redeemed)
    ok, msg = e2.redeem(code)
    check(not ok and msg.startswith("Already redeemed"), f"replay rejected after reload: {msg}")

    section("Failed operations leave the code redeemable")
    e = Env()
    code = make_code(P("GC", "Molten Core First"))
    e.run("GF.inGuild = false")
    ok, msg = e.redeem(code)
    check(not ok and "Not in a guild" in msg and e.eval("CDB.redeemedAppeals and next(CDB.redeemedAppeals)") is None,
          f"guild scope enforced, not consumed: {msg}")
    e.run("GF.inGuild = true")
    ok, msg = e.redeem(code)
    check(ok, f"same code succeeds once in guild: {msg}")

    code = make_code(P("GO", "Ragefire", "n=Bob,g=Player-1-AB"))
    ok, msg = e.redeem(code)
    check(not ok and "is not a Guild First achievement" in msg, f"guild first op on normal achievement rejected: {msg}")

    code = make_code(P("C", "No Such Achievement"))
    ok, msg = e.redeem(code)
    check(not ok and "not found" in msg, f"unknown achievement fails: {msg}")

    e = Env()
    code = make_code(P("C", "Level60"))
    e.run("MARK_ERROR = true")
    ok, msg = e.redeem(code)
    check(not ok and "Failed to apply correction" in msg and "simulated failure" in msg, f"executor error caught: {msg}")
    e.run("MARK_ERROR = false")
    ok, msg = e.redeem(code)
    check(ok, f"retry after executor error succeeds: {msg}")

    e = Env()
    e.run("ADDON.MarkRowCompleted = function() end")
    ok, msg = e.redeem(make_code(P("C", "Level60")))
    check(not ok and "could not be marked complete" in msg and e.eval("CDB.redeemedAppeals and next(CDB.redeemedAppeals)") is None,
          f"completion that silently does nothing is a failure: {msg}")


def test_malformed_codes():
    section("Malformed / unsupported / tampered codes are rejected without side effects")
    e = Env()
    before = e.state()
    cid = "AAAAAAAAAAAAAAAA"
    signed_bad = {
        "version 2": (P(ver="2"), None),
        "version 01": (P(ver="01"), None),
        "empty version": (P(ver=""), None),
        "unknown op": (P(op="XX"), "Unsupported operation"),
        "lowercase op": (P(op="c"), "Unsupported operation"),
        "empty op": (P(op=""), "Unsupported operation"),
        "5 fields": (";".join(["1", cid, GUID, "C", "Ragefire"]), None),
        "7 fields": (P() + ";", None),
        "achievement with ;": (";".join(["1", cid, GUID, "C", "Rage;fire", ""]), None),
        "cid 15 chars": (P(cid="A" * 15), None),
        "cid 17 chars": (P(cid="A" * 17), None),
        "cid bad char": (P(cid="A" * 15 + "+"), None),
        "guid name only": (P(guid="Tester"), None),
        "guid lowercase prefix": (P(guid="player-4395-0207A3F9"), None),
        "guid creature": (P(guid="Creature-0-1-2-3-4-5"), None),
        "guid trailing": (P(guid=GUID + "-1"), None),
        "guid non-hex": (P(guid="Player-4395-0207A3FZ"), None),
        "empty achievement": (P(ach=""), None),
        "leading space": (P(ach=" Ragefire"), None),
        "trailing space": (P(ach="Ragefire "), None),
        "control char": (P(ach="Rage\tfire"), None),
        "65-byte achievement": (P(ach="A" * 65), None),
        "options on delete": (P(op="D", opts="p=1"), None),
        "options on unban": (P(op="UB", opts="s=1"), None),
        "options on clear": (P(op="GC", ach="Molten Core First", opts="n=Bob"), None),
        "unknown option": (P(opts="x=1"), None),
        "duplicate option": (P(opts="p=1,p=2"), None),
        "out of order options": (P(opts="l=5,p=1"), None),
        "trailing comma": (P(opts="p=1,"), None),
        "empty option": (P(opts=","), None),
        "no value": (P(opts="p="), None),
        "no equals": (P(opts="p"), None),
        "spaces in option": (P(opts="p= 5"), None),
        "points leading zero": (P(opts="p=05"), None),
        "points negative": (P(opts="p=-5"), None),
        "points too large": (P(opts="p=100001"), None),
        "points decimal": (P(opts="p=1.5"), None),
        "points hex": (P(opts="p=0x10"), None),
        "level 0": (P(opts="l=0"), None),
        "level 256": (P(opts="l=256"), None),
        "solo 0": (P(opts="s=0"), None),
        "solo true": (P(opts="s=true"), None),
        "date Feb 30": (P(opts="d=20240230"), None),
        "date Feb 29 non-leap": (P(opts="d=20230229"), None),
        "date month 13": (P(opts="d=20241301"), None),
        "date day 0": (P(opts="d=20240100"), None),
        "date 2003": (P(opts="d=20031231"), None),
        "date 2100": (P(opts="d=21000101"), None),
        "date dashed": (P(opts="d=2024-01-01"), None),
        "GO missing guid": (P(op="GO", ach="Molten Core First", opts="n=Bob"), None),
        "GO missing name": (P(op="GO", ach="Molten Core First", opts="g=Player-1-AB"), None),
        "GO bad guid": (P(op="GO", ach="Molten Core First", opts="n=Bob,g=Bob"), None),
        "GO name with space": (P(op="GO", ach="Molten Core First", opts="n=Bob Smith,g=Player-1-AB"), None),
        "GO reversed": (P(op="GO", ach="Molten Core First", opts="g=Player-1-AB,n=Bob"), None),
        "GO options on complete": (P(opts="n=Bob,g=Player-1-AB"), None),
    }
    for label, (payload, expected) in signed_bad.items():
        ok, msg = e.redeem(make_code(payload))
        check(not ok and msg.startswith(expected or "Invalid correction code"), f"{label}: got {msg!r}")
    check(e.state() == before, "no state change from rejected codes")

    good = make_code(P("C", "Ragefire"))
    unsigned = [
        ("empty", ""),
        ("prefix only", "HCA:"),
        ("missing prefix", good[4:]),
        ("lowercase prefix", "hca:" + good[4:]),
        ("standard base64 chars", good.replace("-", "+").replace("_", "/") if ("-" in good or "_" in good) else good[:-1] + "+"),
        ("padding", good + "=="),
        ("truncated by one char", good[:-1]),
        ("truncated signature", good[:-20]),
        ("signature only", "HCA:" + b64u(sign(b"x"))),
        ("too long", good + "A" * 2000),
        ("non-string", None),
    ]
    for label, code in unsigned:
        if code is None:
            ok, msg = e.lua.globals().REDEEM(None)
            ok, msg = bool(ok), msg.decode()
        else:
            ok, msg = e.redeem(code)
        check(not ok and msg.startswith(("Invalid correction code", "Invalid signature")), f"{label}: got {msg!r}")

    raw = base64.urlsafe_b64decode(good[4:] + "=" * (-len(good[4:]) % 4))
    accepted = 0
    for i in range(len(raw)):
        tampered = "HCA:" + b64u(flip(raw, i, 1 << (i % 8)))
        accepted += e.redeem(tampered)[0]
    check(accepted == 0, f"every single-bit tampering of payload+signature rejected ({len(raw)} positions)")

    ok, msg = e.redeem(make_code(P("C", "Ragefire"), key=OTHER_KEY))
    check(not ok and msg.startswith("Invalid signature"), f"code signed by a different key rejected: {msg}")

    payload = P("C", "Ragefire").encode()
    ok, msg = e.redeem("HCA:" + b64u(payload + sign(P("C", "Level60").encode())))
    check(not ok and msg.startswith("Invalid signature"), f"signature from another payload rejected: {msg}")
    ok, msg = e.redeem("HCA:" + b64u(payload.replace(b";C;", b";U;") + sign(payload)))
    check(not ok and msg.startswith("Invalid signature"), f"operation swap rejected: {msg}")
    check(e.state() == before, "no state change from tampered codes")

    ok, msg = e.redeem("\n  " + good[:50] + " \t" + good[50:120] + "\n" + good[120:] + "  ")
    check(ok, f"valid code with pasted whitespace accepted: {msg}")
    ok, msg = e.redeem("`" + make_code(P("C", "Level60")) + "`")
    check(ok, f"valid code wrapped in backticks accepted: {msg}")


def test_window_and_legacy():
    section("Appeal window and /hca appeal")
    e = Env()
    e.run('SlashCmdList.HARDCOREAchievements("appeal")')
    check(e.eval("HardcoreAchievementsAppealFrame.shown") is True, "/hca appeal opens the window")
    check(e.eval("HardcoreAchievementsAppealFrame.guidBox.text") == GUID, "window shows the player's GUID")
    check(e.eval("HardcoreAchievementsAppealFrame.character.text") == "Tester - Doomhowl", "window shows name and realm")
    check(e.eval("UISpecialFrames[1]") == "HardcoreAchievementsAppealFrame", "Escape closes the window")
    e.run('local b = HardcoreAchievementsAppealFrame.guidBox; b.text = "edited"; b.scripts.OnTextChanged(b, true)')
    check(e.eval("HardcoreAchievementsAppealFrame.guidBox.text") == GUID, "GUID box resets when edited")

    e.run(f'HardcoreAchievementsAppealFrame.codeBox:SetText("garbage"); FIND_BUTTON("Redeem").scripts.OnClick()')
    check(e.eval("HardcoreAchievementsAppealFrame.status.text").startswith("Invalid correction code: it should start with HCA:"), "Redeem shows where the code failed")
    code = make_code(P("C", "Ragefire"))
    e.run(f'HardcoreAchievementsAppealFrame.codeBox:SetText("{code}"); FIND_BUTTON("Redeem").scripts.OnClick()')
    check(rec(e, "Ragefire", "completed") is True, "Redeem button applies the code")
    check(e.eval("HardcoreAchievementsAppealFrame.codeBox.text") == "", "code box cleared after success")
    check(e.eval("HardcoreAchievementsAppealFrame.status.text") == "Ragefire Chasm was completed", "window shows the achievement name")
    check(e.eval("#PRINTS") == 0, "no chat output from appeal redemption")

    section("Legacy admin system removed")
    e = Env()
    e.run("FIRE_LOGIN()")
    prefixes = sorted(k.decode() for k in e.lua.globals().COMM.keys())
    check(prefixes == ["HCA_DngBoss", "HCA_Fellowship"], f"only Precious/DngBoss AceComm prefixes registered: {prefixes}")
    check(e.eval("ADDON.AdminCommandHandler == nil"), "AdminCommandHandler export removed")
    e.run('HardcoreAchievementsDB.adminSecretKey = nil; SlashCmdList.HARDCOREAchievements("adminkey set abcdefghijklmnopqrstuvwxyz")')
    check(e.eval("HardcoreAchievementsDB.adminSecretKey == nil"), "/hca adminkey no longer stores a key")

    shipped = [p for p in ROOT.rglob("*") if p.suffix in (".lua", ".toc", ".xml")
               and "Tools" not in p.parts and ".git" not in p.parts and "Libs" not in p.parts]
    legacy_hits = [str(p.relative_to(ROOT)) for p in shipped
                   if re.search(rb"HCA_Admin_|AdminPanel|CreateSecureHash|CreateAdminPayload|adminkey",
                                p.read_bytes(), re.I)]
    check(not legacy_hits, f"no legacy admin references in addon files: {legacy_hits}")
    check(not (ROOT / "Admin").exists(), "Admin folder deleted")
    for rel in ["Utils/AppealCrypto.lua", "Utils/AppealCodes.lua"]:
        src = (ROOT / rel).read_bytes()
        check(not re.search(rb"loadstring|\bload\s*\(|RunScript|setfenv|getfenv", src), f"{rel} never executes code")
        check(b"PRIVATE KEY" not in src, f"{rel} contains no private key material")

    section("Shipped public key")
    src = (ROOT / "Utils/AppealCodes.lua").read_text()
    m = re.search(r'local PUBLIC_MODULUS_B64 = "([A-Za-z0-9_-]+)"', src)
    mod = base64.urlsafe_b64decode(m.group(1) + "=" * (-len(m.group(1)) % 4)) if m else b""
    check(len(mod) == 128 and mod[0] & 0x80 and mod[-1] & 1, "addon embeds a 1024-bit odd RSA modulus")
    check(b"PRIVATE" not in b"".join(p.read_bytes() for p in shipped), "no private key text in shipped files")


def test_signer_cli():
    section("Signer CLI (hca_appeal.py)")
    py = sys.executable
    with tempfile.TemporaryDirectory() as tmp:
        key = Path(tmp) / "k.pem"

        def run(*args):
            return subprocess.run([py, str(SIGNER), *args], capture_output=True, text=True)

        r = run("keygen", "--out", str(key))
        check(r.returncode == 0 and key.exists(), f"keygen: {r.stderr}")
        check(run("keygen", "--out", str(key)).returncode != 0, "keygen refuses to overwrite")
        check(run("keygen", "--out", str(ROOT / "Tools" / "x.pem")).returncode != 0 and not (ROOT / "Tools" / "x.pem").exists(),
              "keygen refuses to write inside the addon folder")
        m = re.search(r'"([A-Za-z0-9_-]+)"', run("pubkey", "--key", str(key)).stdout)
        modulus = base64.urlsafe_b64decode(m.group(1) + "=" * (-len(m.group(1)) % 4))

        e = Env(modulus=modulus)
        signed = [
            (["complete", GUID, "Sha'tari Skyguard", "--points", "40", "--level", "30", "--solo", "--date", "2024-12-31"], True),
            (["delete-permanent", GUID, "Ragefire"], True),
            (["unban", GUID, "Ragefire"], True),
            (["gf-override", GUID, "Molten Core First", "--winner-name", "Bob", "--winner-guid", "Player-4395-00AB12CD"], True),
            (["gf-clear", GUID, "Molten Core First"], True),
        ]
        for args, expect in signed:
            r = run("sign", *args, "--key", str(key))
            code = r.stdout.strip()
            ok, msg = e.redeem(code) if r.returncode == 0 else (False, r.stderr)
            check(ok == expect, f"signer {args[0]} -> {msg}")
            check(len(code) < 400, f"code length {len(code)}")
        check(rec(e, "Sha'tari Skyguard", "points") == 40 and rec(e, "Sha'tari Skyguard", "level") == 30, "signer options applied")

        rejects = [
            ["complete", "Tester", "Ragefire"],
            ["complete", GUID, "Rage;fire"],
            ["complete", GUID, " Ragefire"],
            ["complete", GUID, "Ragefire", "--points", "100001"],
            ["complete", GUID, "Ragefire", "--level", "0"],
            ["complete", GUID, "Ragefire", "--date", "2024-02-30"],
            ["delete", GUID, "Ragefire", "--points", "5"],
            ["gf-override", GUID, "Molten Core First", "--winner-name", "Bob"],
            ["gf-override", GUID, "Molten Core First", "--winner-name", "Bob Smith", "--winner-guid", GUID],
            ["complete", GUID, "Ragefire", "--winner-name", "Bob"],
        ]
        for args in rejects:
            check(run("sign", *args, "--key", str(key)).returncode != 0, f"signer rejects {args}")

        r = run("sign", "complete", GUID, "Ragefire", "--key", str(key))
        check("does not match" in r.stderr, "signer warns when its key differs from the addon's")


def test_timing():
    section("Performance (synchronous verification)")
    e = Env()
    codes = [make_code(P("C", "Ragefire")) for _ in range(20)]
    t = time.perf_counter()
    e.redeem(codes[0])
    first = time.perf_counter() - t
    t = time.perf_counter()
    for c in codes[1:]:
        e.redeem(c)
    rest = (time.perf_counter() - t) / (len(codes) - 1)
    print(f"  first redemption {first * 1000:.1f} ms (includes one-time key setup), then {rest * 1000:.1f} ms each")
    check(first < 0.5 and rest < 0.25, "redemption fast enough to run synchronously on a click")


def main():
    t = time.perf_counter()
    env = Env()
    test_sha256(env)
    test_base64(env)
    test_rsa_vectors(env)
    test_operations()
    test_solo_and_partial_updates()
    test_redemption_rules()
    test_malformed_codes()
    test_window_and_legacy()
    test_signer_cli()
    test_timing()
    print(f"\n{PASSED} passed, {FAILED} failed in {time.perf_counter() - t:.1f}s")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
