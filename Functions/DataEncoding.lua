local AceSerialize = LibStub("AceSerializer-3.0")

local addonName, addon = ...
local string_byte = string.byte
local table_concat = table.concat

-- Simple Base64 encoding/decoding for compression and obfuscation
-- Using bit library if available (Classic WoW should have it)
local bit = _G.bit or _G.bit32
local base64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64encode(data)
    local result = {}
    local len = #data
    
    -- Use bit library if available, otherwise manual operations
    local lshift, rshift, band, bor
    if bit and bit.lshift then
        lshift = bit.lshift
        rshift = bit.rshift
        band = bit.band
        bor = bit.bor
    else
        -- Manual bit operations fallback
        lshift = function(a, b) return math.floor(a * (2 ^ b)) end
        rshift = function(a, b) return math.floor(a / (2 ^ b)) end
        band = function(a, b)
            local result = 0
            local bitval = 1
            while a > 0 or b > 0 do
                if (a % 2 == 1) and (b % 2 == 1) then
                    result = result + bitval
                end
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                bitval = bitval * 2
            end
            return result
        end
        bor = function(a, b)
            local result = 0
            local bitval = 1
            while a > 0 or b > 0 do
                if (a % 2 == 1) or (b % 2 == 1) then
                    result = result + bitval
                end
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                bitval = bitval * 2
            end
            return result
        end
    end
    
    for i = 1, len, 3 do
        local b1 = string_byte(data, i) or 0
        local b2 = string_byte(data, i + 1)
        local b3 = string_byte(data, i + 2)
        
        local bitmap = bor(bor(lshift(b1, 16), lshift(b2 or 0, 8)), b3 or 0)
        
        -- Determine how many bytes we actually have in this group
        local bytesInGroup = math.min(3, len - i + 1)
        
        -- Output the appropriate number of characters
        if bytesInGroup == 3 then
            -- Full group: output all 4 characters
            for j = 1, 4 do
                local idx = band(rshift(bitmap, 6 * (4 - j)), 63)
                result[#result + 1] = string.sub(base64chars, idx + 1, idx + 1)
            end
        elseif bytesInGroup == 2 then
            -- 2 bytes: output 3 chars, then 1 padding
            for j = 1, 3 do
                local idx = band(rshift(bitmap, 6 * (4 - j)), 63)
                result[#result + 1] = string.sub(base64chars, idx + 1, idx + 1)
            end
            result[#result + 1] = '='
        else
            -- 1 byte: output 2 chars, then 2 padding
            for j = 1, 2 do
                local idx = band(rshift(bitmap, 6 * (4 - j)), 63)
                result[#result + 1] = string.sub(base64chars, idx + 1, idx + 1)
            end
            result[#result + 1] = '='
            result[#result + 1] = '='
        end
    end
    return table_concat(result)
end

local function base64decode(data)
    local base64map = {}
    for i = 1, 64 do
        base64map[string.sub(base64chars, i, i)] = i - 1
    end
    data = string.gsub(data, '[^A-Za-z0-9+/=]', '')
    local result = {}
    local len = #data
    
    -- Use bit library if available
    local lshift, rshift, band
    if bit and bit.lshift then
        lshift = bit.lshift
        rshift = bit.rshift
        band = bit.band
    else
        lshift = function(a, b) return math.floor(a * (2 ^ b)) end
        rshift = function(a, b) return math.floor(a / (2 ^ b)) end
        band = function(a, b)
            local result = 0
            local bitval = 1
            while a > 0 or b > 0 do
                if (a % 2 == 1) and (b % 2 == 1) then
                    result = result + bitval
                end
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                bitval = bitval * 2
            end
            return result
        end
    end
    
    for i = 1, len, 4 do
        local bitmap = 0
        local padCount = 0
        local charsRead = 0
        for j = 0, 3 do
            if i + j > len then break end
            local char = string.sub(data, i + j, i + j)
            if char == '=' then
                padCount = padCount + 1
            elseif base64map[char] then
                bitmap = bitmap + lshift(base64map[char], 6 * (3 - j))
                charsRead = charsRead + 1
            end
        end
        -- Only output bytes if we read at least 2 characters (minimum for 1 byte output)
        if charsRead >= 2 then
            local bytesToOutput = 3 - padCount
            for j = 0, bytesToOutput - 1 do
                local byte = band(rshift(bitmap, 8 * (2 - j)), 255)
                result[#result + 1] = string.char(byte)
            end
        end
    end
    return table_concat(result)
end

-- Encode: Serialize -> Base64 (simple and reliable)
-- Encodes any Lua data structure into a Base64 string
-- @param data: Any Lua data structure (table, string, number, etc.)
-- @return: Base64 encoded string
local function EncodeData(data)
    local serialized = AceSerialize:Serialize(data)
    -- Just encode to base64 - still makes it non-readable and slightly smaller
    return base64encode(serialized)
end

-- Decode: Base64 -> Deserialize
-- Decodes a Base64 string back into a Lua data structure
-- @param encoded: Base64 encoded string
-- @return: success (boolean), data or error message
local function DecodeData(encoded)
    if not encoded or encoded == "" then
        return false, "Empty encoded data"
    end
    
    -- Clean the input (remove any whitespace/newlines that might have been added during copy/paste)
    encoded = string.gsub(encoded, '%s+', '')
    
    -- Decode from base64
    local decodeSuccess, compressed = pcall(base64decode, encoded)
    if not decodeSuccess then
        return false, "Base64 decode failed: " .. tostring(compressed)
    end
    if not compressed or compressed == "" then
        return false, "Decoded data is empty after base64 decode"
    end
    
    -- Deserialize using AceSerializer (it automatically ignores whitespace)
    -- Returns: success, data or false, errorMessage
    local deserializeSuccess, deserializeResult = AceSerialize:Deserialize(compressed)
    if not deserializeSuccess then
        return false, "Deserialize failed: " .. tostring(deserializeResult)
    end
    
    return deserializeSuccess, deserializeResult
end

if addon then
    addon.EncodeData = EncodeData
    addon.DecodeData = DecodeData
end