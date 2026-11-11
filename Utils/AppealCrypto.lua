local _, addon = ...

local floor, byte, char, concat, rep = math.floor, string.byte, string.char, table.concat, string.rep

local Crypto = {}

local TWO32 = 4294967296

-- ---------------------------------------------------------------------------
-- 32-bit bitwise helpers via 4-bit lookup tables. Operands are integers in [0, 2^32).
-- ---------------------------------------------------------------------------
local XOR4, AND4 = {}, {}
for a = 0, 15 do
    for b = 0, 15 do
        local x, y, xr, ar, v = a, b, 0, 0, 1
        for _ = 1, 4 do
            local xa, yb = x % 2, y % 2
            if xa ~= yb then xr = xr + v elseif xa == 1 then ar = ar + v end
            x, y, v = (x - xa) / 2, (y - yb) / 2, v * 2
        end
        XOR4[a * 16 + b], AND4[a * 16 + b] = xr, ar
    end
end

local function bxor(a, b)
    local r, m = 0, 1
    while a > 0 and b > 0 do
        local na, nb = a % 16, b % 16
        r = r + XOR4[na * 16 + nb] * m
        a, b, m = (a - na) / 16, (b - nb) / 16, m * 16
    end
    return r + (a + b) * m
end

local function band(a, b)
    local r, m = 0, 1
    while a > 0 and b > 0 do
        local na, nb = a % 16, b % 16
        r = r + AND4[na * 16 + nb] * m
        a, b, m = (a - na) / 16, (b - nb) / 16, m * 16
    end
    return r
end

local function rotr(x, n)
    local low = x % 2 ^ n
    return (x - low) / 2 ^ n + low * 2 ^ (32 - n)
end

local function shr(x, n)
    return (x - x % 2 ^ n) / 2 ^ n
end

-- ---------------------------------------------------------------------------
-- SHA-256 (FIPS 180-4)
-- ---------------------------------------------------------------------------
local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local H0 = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }

function Crypto.SHA256(msg)
    local len = #msg
    local lenBytes, bitLen = {}, len * 8
    for i = 8, 1, -1 do
        local b = bitLen % 256
        lenBytes[i] = char(b)
        bitLen = (bitLen - b) / 256
    end
    msg = msg .. "\128" .. rep("\0", (55 - len) % 64) .. concat(lenBytes)

    local H = { H0[1], H0[2], H0[3], H0[4], H0[5], H0[6], H0[7], H0[8] }
    local w = {}
    for chunk = 1, #msg, 64 do
        for i = 0, 15 do
            local b1, b2, b3, b4 = byte(msg, chunk + i * 4, chunk + i * 4 + 3)
            w[i] = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        end
        for i = 16, 63 do
            local x, y = w[i - 15], w[i - 2]
            local s0 = bxor(bxor(rotr(x, 7), rotr(x, 18)), shr(x, 3))
            local s1 = bxor(bxor(rotr(y, 17), rotr(y, 19)), shr(y, 10))
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % TWO32
        end

        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        for i = 0, 63 do
            local S1 = bxor(bxor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
            local ch = bxor(g, band(e, bxor(f, g)))
            local t1 = h + S1 + ch + K[i + 1] + w[i]
            local S0 = bxor(bxor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
            local maj = bxor(band(a, b), band(c, bxor(a, b)))
            h, g, f, e, d, c, b, a = g, f, e, (d + t1) % TWO32, c, b, a, (t1 + S0 + maj) % TWO32
        end
        H[1], H[2], H[3], H[4] = (H[1] + a) % TWO32, (H[2] + b) % TWO32, (H[3] + c) % TWO32, (H[4] + d) % TWO32
        H[5], H[6], H[7], H[8] = (H[5] + e) % TWO32, (H[6] + f) % TWO32, (H[7] + g) % TWO32, (H[8] + h) % TWO32
    end

    local out = {}
    for i = 1, 8 do
        local v = H[i]
        out[i] = char(floor(v / 16777216), floor(v / 65536) % 256, floor(v / 256) % 256, v % 256)
    end
    return concat(out)
end

-- ---------------------------------------------------------------------------
-- Big integers: little-endian arrays of base-2^24 limbs (products < 2^48 stay exact).
-- ---------------------------------------------------------------------------
local LIMB = 16777216

local function toLimbs(s, count)
    local limbs = {}
    for i = 1, count do limbs[i] = 0 end
    local n = #s
    for i = 0, n - 1 do
        local li = floor(i / 3) + 1
        limbs[li] = limbs[li] + byte(s, n - i) * 256 ^ (i % 3)
    end
    return limbs
end

local function fromLimbs(limbs, byteCount)
    local out = {}
    for i = 0, byteCount - 1 do
        out[byteCount - i] = char(floor(limbs[floor(i / 3) + 1] / 256 ^ (i % 3)) % 256)
    end
    return concat(out)
end

local function compare(a, b, count)
    for i = count, 1, -1 do
        if a[i] ~= b[i] then
            return a[i] > b[i] and 1 or -1
        end
    end
    return 0
end

local function subtract(a, b, count)
    local borrow = 0
    for i = 1, count do
        local v = a[i] - b[i] - borrow
        if v < 0 then v, borrow = v + LIMB, 1 else borrow = 0 end
        a[i] = v
    end
end

-- Montgomery product a * b * R^-1 mod n (R = 2^(24*s)). Inputs < n; result < n.
local function montMul(a, b, key)
    local n, s, n0inv = key.n, key.s, key.n0inv
    local t = {}
    for i = 1, s + 2 do t[i] = 0 end
    for i = 1, s do
        local ai, c, v = a[i], 0, 0
        for j = 1, s do
            v = t[j] + ai * b[j] + c
            c = floor(v / LIMB)
            t[j] = v - c * LIMB
        end
        v = t[s + 1] + c
        c = floor(v / LIMB)
        t[s + 1], t[s + 2] = v - c * LIMB, c

        local m = (t[1] * n0inv) % LIMB
        c = floor((t[1] + m * n[1]) / LIMB)
        for j = 2, s do
            v = t[j] + m * n[j] + c
            c = floor(v / LIMB)
            t[j - 1] = v - c * LIMB
        end
        v = t[s + 1] + c
        c = floor(v / LIMB)
        t[s], t[s + 1] = v - c * LIMB, t[s + 2] + c
    end
    t[s + 2] = nil
    if compare(t, n, s + 1) >= 0 then
        subtract(t, n, s + 1)
    end
    return t
end

local keyCache = {}

local function PrepareKey(modulus)
    local k = #modulus
    local s = floor((k * 8 + 23) / 24)
    local n = toLimbs(modulus, s + 1)

    -- n0inv = -n^-1 mod 2^24 (Newton iteration; n is odd)
    local x = n[1]
    for _ = 1, 5 do
        x = (x * ((2 - (n[1] * x) % LIMB) % LIMB)) % LIMB
    end

    -- R^2 mod n by repeated doubling, so only the modulus has to be configured
    local r2 = toLimbs("\1", s + 1)
    for _ = 1, 2 * 24 * s do
        local carry = 0
        for i = 1, s + 1 do
            local v = r2[i] * 2 + carry
            carry = v >= LIMB and 1 or 0
            r2[i] = v - carry * LIMB
        end
        if compare(r2, n, s + 1) >= 0 then
            subtract(r2, n, s + 1)
        end
    end

    return { k = k, s = s, n = n, n0inv = (LIMB - x) % LIMB, r2 = r2, one = toLimbs("\1", s + 1) }
end

-- ASN.1 DigestInfo prefix for SHA-256 (RFC 8017, section 9.2)
local SHA256_DIGEST_INFO = "\48\49\48\13\6\9\96\134\72\1\101\3\4\2\1\5\0\4\32"

-- Returns true only if `signature` is a valid RSASSA-PKCS1-v1_5 SHA-256 signature of `message`
-- under the big-endian `modulus` with e = 65537. The decoded block is compared whole, never parsed.
function Crypto.VerifyRSASHA256(modulus, message, signature)
    if type(modulus) ~= "string" or type(message) ~= "string" or type(signature) ~= "string" then
        return false
    end
    local key = keyCache[modulus]
    if not key then
        key = PrepareKey(modulus)
        keyCache[modulus] = key
    end
    local k = key.k
    if #signature ~= k or k < 64 then
        return false
    end

    local sig = toLimbs(signature, key.s + 1)
    if compare(sig, key.n, key.s + 1) >= 0 then
        return false
    end

    local x = montMul(sig, key.r2, key)
    local y = x
    for _ = 1, 16 do
        y = montMul(y, y, key)
    end
    y = montMul(montMul(y, x, key), key.one, key)

    local expected = "\0\1" .. rep("\255", k - 3 - #SHA256_DIGEST_INFO - 32) .. "\0"
        .. SHA256_DIGEST_INFO .. Crypto.SHA256(message)
    return fromLimbs(y, k) == expected
end

-- ---------------------------------------------------------------------------
-- base64url (RFC 4648 section 5), unpadded and canonical only.
-- ---------------------------------------------------------------------------
local B64_INDEX = {}
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    for i = 1, 64 do
        B64_INDEX[byte(alphabet, i)] = i - 1
    end
end

function Crypto.Base64UrlDecode(s)
    if type(s) ~= "string" or #s % 4 == 1 then
        return nil
    end
    local out, buf, bits = {}, 0, 0
    for i = 1, #s do
        local v = B64_INDEX[byte(s, i)]
        if not v then
            return nil
        end
        buf, bits = buf * 64 + v, bits + 6
        if bits >= 8 then
            bits = bits - 8
            local p = 2 ^ bits
            local b = floor(buf / p)
            out[#out + 1] = char(b)
            buf = buf - b * p
        end
    end
    if buf ~= 0 then
        return nil
    end
    return concat(out)
end

if addon then
    addon.AppealCrypto = Crypto
end
