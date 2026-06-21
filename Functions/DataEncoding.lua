-- Modern Encode/Decode using LibSerialize + LibDeflate (modeled after WeakAuras)
-- Format: !HCA:1!<deflate+print encoded data>

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local addonName, addon = ...

-- Configuration (tuned for speed on large tables, similar to WeakAuras)
local configForLS = { errorOnUnserializableType = false }
local configForDeflate = { level = 1 } -- speed over size for UI responsiveness

-- Cache for repeated encodings of the same data (cleared after 5 minutes)
local compressedCache = {}

local function cleanupCache()
    local now = time()
    for k, v in pairs(compressedCache) do
        if v.lastAccess < (now - 300) then
            compressedCache[k] = nil
        end
    end
end

-- Encode: table → LibSerialize → LibDeflate → EncodeForPrint → "!HCA:1!" prefix
local function EncodeData(data)
    if not data then return "" end

    local serialized = LibSerialize:SerializeEx(configForLS, data)

    -- Check cache
    local cached = compressedCache[serialized]
    local compressed
    if cached then
        compressed = cached.compressed
        cached.lastAccess = time()
    else
        compressed = LibDeflate:CompressDeflate(serialized, configForDeflate)
        compressedCache[serialized] = {
            compressed = compressed,
            lastAccess = time(),
        }
        cleanupCache()
    end

    local encoded = "!HCA:1!" .. LibDeflate:EncodeForPrint(compressed)
    return encoded
end

-- Decode: supports new "!HCA:1!" format + legacy AceSerializer+Base64
local function DecodeData(encoded)
    if not encoded or encoded == "" then
        return false, "Empty encoded data"
    end

    -- Clean input
    encoded = string.gsub(encoded, '%s+', '')

    -- New format: !HCA:1!...
    local _, _, encodeVersion, payload = encoded:find("^(!HCA:(%d+)!)(.+)$")
    if encodeVersion then
        encodeVersion = tonumber(encodeVersion:match("%d+"))
        if encodeVersion == 1 then
            local decoded = LibDeflate:DecodeForPrint(payload)
            if not decoded then
                return false, "Failed to decode HCA v1 data"
            end

            local decompressed = LibDeflate:DecompressDeflate(decoded)
            if not decompressed then
                return false, "Failed to decompress HCA v1 data"
            end

            local success, result = LibSerialize:Deserialize(decompressed)
            if not success then
                return false, "Failed to deserialize HCA v1 data: " .. tostring(result)
            end
            return true, result
        else
            return false, "Unsupported HCA encode version: " .. tostring(encodeVersion)
        end
    end

    -- Legacy fallback: old AceSerializer + custom Base64 (from previous versions)
    -- This block can be removed in a future major version once all users have migrated.
    local success, result = pcall(function()
        -- Try old format using the old AceSerializer path if available
        local AceSerialize = LibStub("AceSerializer-3.0", true)
        if AceSerialize then
            local ok, data = AceSerialize:Deserialize(encoded)
            if ok then return data end
        end
        return nil
    end)

    if success and result then
        return true, result
    end

    return false, "Unrecognized backup format"
end

if addon then
    addon.EncodeData = EncodeData
    addon.DecodeData = DecodeData
end