------------------------------------------------------------------------------------------------------------------------
-- LibP2PDB: A lightweight, embeddable library for peer-to-peer distributed-database synchronization in WoW addons.
------------------------------------------------------------------------------------------------------------------------

local MAJOR, MINOR = "LibP2PDB", 1
assert(LibStub, MAJOR .. " requires LibStub")

local LibP2PDB = LibStub:NewLibrary(MAJOR, MINOR)
if not LibP2PDB then return end -- no upgrade needed

------------------------------------------------------------------------------------------------------------------------
-- Global Configuration
------------------------------------------------------------------------------------------------------------------------

local DEBUG = false -- Set to true to enable debug output
local VERBOSITY = 4 -- Debug output verbosity: 0 = None, 1 = Errors, 2 = Warnings, 3 = Debug, 4 = Spam, 5 = Trace (detailed)

------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------

local AceComm = LibStub("AceComm-3.0")
local LibBucketedHashSet = LibStub("LibBucketedHashSet")

------------------------------------------------------------------------------------------------------------------------
-- Optional Dependencies
------------------------------------------------------------------------------------------------------------------------

local LibPatternedBloomFilter = LibStub("LibPatternedBloomFilter", true)
local LibSerialize = LibStub("LibSerialize", true)
local LibDeflate = LibStub("LibDeflate", true)

------------------------------------------------------------------------------------------------------------------------
-- Local Lua References
------------------------------------------------------------------------------------------------------------------------

local assert, print = assert, print
local type, ipairs, pairs, rawequal = type, ipairs, pairs, rawequal
local min, max, abs, floor, ceil, sin, log = min, max, abs, floor, ceil, sin, log
local bnot, band, bor, bxor, lshift, rshift = bit.bnot, bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local tonumber, tostring, tostringall = tonumber, tostring, tostringall
local format, strsub, strfind, strjoin, strmatch, strbyte, strchar = format, strsub, strfind, strjoin, strmatch, strbyte, strchar
local tinsert, tremove, tconcat, tsort = table.insert, table.remove, table.concat, table.sort
local unpack, select = unpack, select
local setmetatable, getmetatable = setmetatable, getmetatable
local securecallfunction = securecallfunction

------------------------------------------------------------------------------------------------------------------------
-- Local WoW API References
------------------------------------------------------------------------------------------------------------------------

local UnitName, UnitGUID = UnitName, UnitGUID
local GetTime, GetServerTime = GetTime, GetServerTime
local IsInGuild, IsInRaid, IsInGroup, IsInInstance = IsInGuild, IsInRaid, IsInGroup, IsInInstance

------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------

local NIL_MARKER = strchar(0) --- @type string Marker for nil values in serialization.
local LOG2 = log(2)           --- @type number Precomputed log(2) for efficiency.

--- @enum LibP2PDB.Color Color codes for console output.
local Color = {
    Ace = "ff33ff99",
    White = "ffffffff",
    Gray = "ffc0c0c0",
    Red = "ffff2020",
    Yellow = "ffffff00",
    Green = "ff00ff00",
    Cyan = "ff00ffff",
    Blue = "ff4040ff",
    Magenta = "ffff20ff",
}

--- @enum LibP2PDB.CommMessageType Communication message types.
local CommMessageType = {
    PeerDiscoveryRequest = 1,
    PeerDiscoveryResponse = 2,
    DigestRequest = 3,
    DigestResponse = 4,
    RowsRequest = 5,
    RowsResponse = 6,
}

--- @enum LibP2PDB.CommPriority Communication priorities.
local CommPriority = {
    Low = "BULK",
    Normal = "NORMAL",
    High = "ALERT",
}

------------------------------------------------------------------------------------------------------------------------
-- Private Helper Functions
------------------------------------------------------------------------------------------------------------------------

if DEBUG then
    UIParentLoadAddOn("Blizzard_DebugTools")
end
local LAST_ERROR = nil --- @type string?

--- Format text with color codes for console output.
--- @param color LibP2PDB.Color Color code.
--- @param text string Text to color
local function C(color, text)
    return "|c" .. color .. text .. "|r"
end

--- Print function.
--- @param fmt string Format string.
--- @param ... any Format arguments.
local function Print(fmt, ...)
    local success, message = pcall(format, fmt, tostringall(...))
    if not success then
        message = fmt
    end
    print(C(Color.Ace, "LibP2PDB") .. ": " .. message)
end

--- Error print function.
--- Requires DEBUG to be true and VERBOSITY >= 1.
--- @param fmt string Format string.
--- @param ... any Format arguments.
local function Error(fmt, ...)
    if DEBUG and VERBOSITY >= 1 then
        local success, message = pcall(format, fmt, tostringall(...))
        if not success then
            message = fmt
        end
        Print("%s %s", C(Color.Red, "[ERROR]"), message)
    end
end

--- Warning print function.
--- Requires DEBUG to be true and VERBOSITY >= 2.
--- @param fmt string Format string.
--- @param ... any Format arguments.
local function Warn(fmt, ...)
    if DEBUG and VERBOSITY >= 2 then
        local success, message = pcall(format, fmt, tostringall(...))
        if not success then
            message = fmt
        end
        Print("%s %s", C(Color.Yellow, "[WARNING]"), message)
    end
end

--- Debug print function.
--- Requires DEBUG to be true and VERBOSITY >= 3.
--- @param fmt string Format string.
--- @param ... any Format arguments.
local function Debug(fmt, ...)
    if DEBUG and VERBOSITY >= 3 then
        local success, message = pcall(format, fmt, tostringall(...))
        if not success then
            message = fmt
        end
        Print("%s %s", C(Color.Cyan, "[DEBUG]"), message)
    end
end

--- Spam print function.
--- Requires DEBUG to be true and VERBOSITY >= 4.
--- @param fmt string Format string.
--- @param ... any Format arguments.
local function Spam(fmt, ...)
    if DEBUG and VERBOSITY >= 4 then
        local success, message = pcall(format, fmt, tostringall(...))
        if not success then
            message = fmt
        end
        Print("%s %s", C(Color.Gray, "[SPAM]"), message)
    end
end

--- Dump a value to a string representation for debugging.
--- @param value any Value to dump.
local function Dump(value)
    if type(value) == "table" then
        local s = "{"
        for k, v in pairs(value) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. Dump(v) .. ','
        end
        return s .. '}'
    elseif type(value) == "string" then
        return '"' .. value .. '"'
    else
        return tostring(value)
    end
end

--- Determine if a value is a string.
--- @param value any Value to check if it's a string.
--- @return boolean isString True if the value is a string, false otherwise.
local function IsString(value)
    return type(value) == "string"
end

--- Determine if a value is a string or nil.
--- @param value any Value to check if it's a string or nil.
--- @return boolean isStringOrNil True if the value is a string or nil, false otherwise.
local function IsStringOrNil(value)
    return value == nil or IsString(value)
end

--- Determine if a value is an empty string.
--- @param value any Value to check if it's an empty string.
--- @return boolean isEmptyString True if the value is an empty string, false otherwise.
local function IsEmptyString(value)
    return IsString(value) and value == ""
end

--- Determine if a value is an empty string or nil.
--- @param value any Value to check if it's an empty string or nil.
--- @return boolean isEmptyStringOrNil True if the value is an empty string or nil, false otherwise.
local function IsEmptyStringOrNil(value)
    return value == nil or IsEmptyString(value)
end

--- Determine if a value is a non-empty string.
--- @param value any Value to check if it's a non-empty string.
--- @return boolean isNonEmptyString True if the value is a non-empty string, false otherwise.
local function IsNonEmptyString(value)
    return IsString(value) and value ~= ""
end

--- Determine if a value is a non-empty string or nil.
--- @param value any Value to check if it's a non-empty string or nil.
--- @return boolean isNonEmptyStringOrNil True if the value is a non-empty string or nil, false otherwise.
local function IsNonEmptyStringOrNil(value)
    return value == nil or IsNonEmptyString(value)
end

--- Determine if a value is a non-empty string with minimum and maximum length.
--- @param value any Value to check if it's a non-empty string.
--- @param minLen integer Minimum length of the string.
--- @param maxLen integer Maximum length of the string.
--- @return boolean isNonEmptyStringEx True if the value is a non-empty string with minimum and maximum length, false otherwise.
local function IsNonEmptyStringEx(value, minLen, maxLen)
    if IsNonEmptyString(value) then
        local len = strlen(value)
        return len >= minLen and len <= maxLen
    end
    return false
end

--- Determine if a value is a non-empty string with minimum and maximum length or nil.
--- @param value any Value to check if it's a non-empty string or nil.
--- @param minLen integer Minimum length of the string.
--- @param maxLen integer Maximum length of the string.
--- @return boolean isNonEmptyStringExOrNil True if the value is a non-empty string with minimum and maximum length or nil, false otherwise.
local function IsNonEmptyStringExOrNil(value, minLen, maxLen)
    return value == nil or IsNonEmptyStringEx(value, minLen, maxLen)
end

--- Determine if a value is a number.
--- @param value any Value to check if it's a number.
--- @param minValue number? Optional minimum value.
--- @param maxValue number? Optional maximum value.
--- @return boolean isNumber True if the value is a number, false otherwise.
local function IsNumber(value, minValue, maxValue)
    return type(value) == "number" and (not minValue or value >= minValue) and (not maxValue or value <= maxValue)
end

--- Determine if a value is a number or nil.
--- @param value any Value to check if it's a number or nil.
--- @param minValue number? Optional minimum value.
--- @param maxValue number? Optional maximum value.
--- @return boolean isNumberOrNil True if the value is a number or nil, false otherwise.
local function IsNumberOrNil(value, minValue, maxValue)
    return value == nil or IsNumber(value, minValue, maxValue)
end

--- Determine if a value is an integer.
--- @param value any Value to check if it's an integer.
--- @param minValue integer? Optional minimum value.
--- @param maxValue integer? Optional maximum value.
--- @return boolean isInteger True if the value is an integer, false otherwise.
local function IsInteger(value, minValue, maxValue)
    return type(value) == "number" and value % 1 == 0 and (not minValue or value >= minValue) and (not maxValue or value <= maxValue)
end

--- Determine if a value is an integer or nil.
--- @param value any Value to check if it's an integer or nil.
--- @param minValue integer? Optional minimum value.
--- @param maxValue integer? Optional maximum value.
--- @return boolean isIntegerOrNil True if the value is an integer or nil, false otherwise.
local function IsIntegerOrNil(value, minValue, maxValue)
    return value == nil or IsInteger(value, minValue, maxValue)
end

--- Determine if a value is a boolean.
--- @param value any Value to check if it's a boolean.
--- @return boolean isBoolean True if the value is a boolean, false otherwise.
local function IsBoolean(value)
    return type(value) == "boolean"
end

--- Determine if a value is a boolean or nil.
--- @param value any Value to check if it's a boolean or nil.
--- @return boolean isBooleanOrNil True if the value is a boolean or nil, false otherwise.
local function IsBooleanOrNil(value)
    return value == nil or IsBoolean(value)
end

--- Determine if a value is a table.
--- @param value any Value to check if it's a table.
--- @return boolean isTable True if the value is a table, false otherwise.
local function IsTable(value)
    return type(value) == "table"
end

--- Determine if a value is a table or nil.
--- @param value any Value to check if it's a table or nil.
--- @return boolean isTableOrNil True if the value is a table or nil, false otherwise.
local function IsTableOrNil(value)
    return value == nil or IsTable(value)
end

--- Determine if a value is an empty table.
--- @param value any Value to check if it's an empty table.
--- @return boolean isEmptyTable True if the value is an empty table, false otherwise.
local function IsEmptyTable(value)
    return IsTable(value) and next(value) == nil
end

--- Determine if a value is an empty table or nil.
--- @param value any Value to check if it's an empty table or nil.
--- @return boolean isEmptyTableOrNil True if the value is an empty table or nil, false otherwise.
local function IsEmptyTableOrNil(value)
    return value == nil or IsEmptyTable(value)
end

--- Determine if a value is a non-empty table.
--- @param value any Value to check if it's a non-empty table.
--- @return boolean isNonEmptyTable True if the value is a non-empty table, false otherwise.
local function IsNonEmptyTable(value)
    return IsTable(value) and next(value) ~= nil
end

--- Determine if a value is a non-empty table or nil.
--- @param value any Value to check if it's a non-empty table or nil.
--- @return boolean isNonEmptyTableOrNil True if the value is a non-empty table or nil, false otherwise.
local function IsNonEmptyTableOrNil(value)
    return value == nil or IsNonEmptyTable(value)
end

--- Determine if a value is a primitive type.
--- @param value any Value to check if it's a primitive type.
--- @return boolean isPrimitive True if the value is a primitive type, false otherwise.
local function IsPrimitive(value)
    local t = type(value)
    return t == "boolean" or t == "string" or t == "number" or t == "nil"
end

--- Determine if a value is a primitive type or nil.
--- @param value any Value to check if it's a primitive type or nil.
--- @return boolean isPrimitiveOrNil True if the value is a primitive type or nil, false otherwise.
local function IsPrimitiveOrNil(value)
    return value == nil or IsPrimitive(value)
end

--- Determine if a type name is a primitive type.
--- @param typeName string Type name to check if it's a primitive type.
--- @return boolean isPrimitiveType True if the type name is a primitive type, false otherwise.
local function IsPrimitiveType(typeName)
    return typeName == "boolean" or typeName == "string" or typeName == "number" or typeName == "nil"
end

--- Determine if a value is a function.
--- @param value any Value to check if it's a function.
--- @return boolean isFunction True if the value is a function, false otherwise.
local function IsFunction(value)
    return type(value) == "function"
end

--- Determine if a value is a function or nil.
--- @param value any Value to check if it's a function or nil.
--- @return boolean isFunctionOrNil True if the value is a function or nil, false otherwise.
local function IsFunctionOrNil(value)
    return value == nil or IsFunction(value)
end

--- Determine if a value implements an interface (has required function names).
--- @param value any Value to check if it implements the interface.
--- @param ... string Function names required by the interface.
local function IsInterface(value, ...)
    if type(value) ~= "table" then
        return false
    end
    local interface = { ... }
    for _, fnName in ipairs(interface) do
        local fn = value[fnName]
        if not IsFunction(fn) then
            return false
        end
    end
    return true
end

--- Determine if a value implements an interface or is nil.
--- @param value any Value to check if it implements the interface or is nil.
--- @param ... string Function names required by the interface.
local function IsInterfaceOrNil(value, ...)
    return value == nil or IsInterface(value, ...)
end

--- Compute the next power of two greater than or equal to the given value.
--- @param value integer Input value.
local function NextPowerOfTwo(value)
    if value == 0 then
        return 1
    end
    return 2 ^ ceil(log(value) / LOG2)
end

--- Compute the greatest common divisor (GCD) of two integers.
--- @param a integer First integer.
--- @param b integer Second integer.
--- @return integer gcd The greatest common divisor of a and b.
local function GreatestCommonDivisor(a, b)
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

--- Find a coprime multiplier for a given integer.
--- @param value integer Input integer.
--- @return integer? multiplier A coprime multiplier for the input integer.
local function FindCoprimeMultiplier(value)
    for i = 2, value - 1 do
        if GreatestCommonDivisor(i, value) == 1 then
            return i
        end
    end
end

--- Determine if an array contains a value.
--- @param array any[] Array to search.
--- @param value any Value to search for.
local function Contains(array, value)
    local len = #array
    for i = 1, len do
        if array[i] == value then
            return true
        end
    end
    return false
end

--- Deep copy a value (include nested tables recursively).
--- @param value any Value to deep copy.
--- @return any copy The deep copied value.
local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

--- Deep compare two values for equality (include nested tables recursively).
--- @param a any First value to compare.
--- @param b any Second value to compare.
--- @return boolean isEqual True if the values are equal, false otherwise.
local function DeepEqual(a, b)
    if rawequal(a, b) then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    local count = 0
    for k, v in pairs(a) do
        if not DeepEqual(v, b[k]) then
            return false
        end
        count = count + 1
    end
    for _ in pairs(b) do
        count = count - 1
        if count < 0 then
            return false
        end
    end
    return count == 0
end

--- Shallow copy a value (skip nested tables).
--- @param value any Value to shallow copy.
--- @return any copy The shallow copied value.
local function ShallowCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = v
    end
    return copy
end

--- Shallow compare two values for equality (skip nested tables).
--- @param a any First value to compare.
--- @param b any Second value to compare.
--- @return boolean isEqual True if the values are equal, false otherwise.
local function ShallowEqual(a, b)
    if rawequal(a, b) then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    local count = 0
    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
        count = count + 1
    end
    for _ in pairs(b) do
        count = count - 1
        if count < 0 then
            return false
        end
    end
    return count == 0
end

--- Find the lower bound index for a value in a sorted table.
--- Returns the index of the first element greater than the value.
--- @param sortedTable any[] Sorted table to search.
--- @param value any Value to search for.
--- @return integer index The lower bound index for the value.
local function LowerBound(sortedTable, value)
    local low = 1
    local high = #sortedTable + 1
    while low < high do
        local mid = floor((low + high) / 2)
        if value < sortedTable[mid] then
            high = mid
        else
            low = mid + 1
        end
    end
    return low
end

--- Find the index of a value in a sorted table.
--- Returns the index of the value if found, or nil if not found.
--- @param sortedTable any[] Sorted table to search.
--- @param value any Value to search for.
--- @return integer? index The index of the value if found, or nil if not found.
local function IndexOf(sortedTable, value)
    local low = 1
    local high = #sortedTable
    while low <= high do
        local mid = floor((low + high) / 2)
        if sortedTable[mid] == value then
            return mid
        elseif value < sortedTable[mid] then
            high = mid - 1
        else
            low = mid + 1
        end
    end
    return nil
end

--- Report a non-fatal error without stopping execution.
--- @param dbi LibP2PDB.DBInstance? Database instance if available.
--- @param fmt string Format string.
--- @param ... any Format arguments.
--- @return string message The error message.
local function ReportError(dbi, fmt, ...)
    local success, message = pcall(format, fmt, ...)
    if not success then
        message = fmt
    end
    if dbi and dbi.onError then
        dbi.onError(message, debugstack(2))
    else
        Error(message)
        LAST_ERROR = message
    end
    return message
end

--- Safely call a function with error handling.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param func function Function to call.
--- @param ... any Additional arguments to pass to the function to call.
--- @return boolean success True if the function executed successfully, false on error.
--- @return ... Results from the function if successful, or nil on error.
local function SafeCall(dbi, func, ...)
    assert(IsTable(dbi))
    assert(IsFunction(func))

    -- Use xpcall to catch errors
    local results = {
        xpcall(func, function(err)
            if dbi and dbi.onError then
                dbi.onError(tostring(err), debugstack(2))
            else
                Error(tostring(err))
                LAST_ERROR = tostring(err)
            end
        end, ...)
    }

    -- If the function threw an error, return false with no results
    if not results[1] then
        return false
    end

    -- Return success and all results from the function
    return true, unpack(results, 2)
end

------------------------------------------------------------------------------------------------------------------------
-- Private State
------------------------------------------------------------------------------------------------------------------------

local Private = {}
Private.__index = Private

--- Create a new private library state instance.
--- @param playerName string Player name.
--- @param playerGUID string Player GUID.
--- @return table instance New private library state instance.
function Private.New(playerName, playerGUID)
    assert(IsNonEmptyString(playerName), "player name must be a non-empty string")
    assert(IsNonEmptyString(playerGUID), "player GUID must be a non-empty string")
    local peerID = strsub(playerGUID, 8) -- skip "Player-" prefix
    local instance = setmetatable({
        playerName = playerName,
        playerGUID = playerGUID,
        peerId = peerID,
        prefixes = setmetatable({}, { __mode = "v" }),
        databases = setmetatable({}, { __mode = "k" }),
        frame = CreateFrame("Frame", "LibP2PDB-" .. peerID),
    }, Private)
    instance.frame:SetScript("OnUpdate", function(self)
        for _, dbi in pairs(instance.databases) do
            instance:OnUpdate(dbi)
        end
    end)
    return instance
end

local priv = Private.New(assert(UnitName("player"), "unable to get player name"), assert(UnitGUID("player"), "unable to get player GUID"))

------------------------------------------------------------------------------------------------------------------------
-- Public API: Database Instance Creation
------------------------------------------------------------------------------------------------------------------------

--- @alias LibP2PDB.DBPrefix string Unique communication prefix for a database (max 16 chars).
--- @alias LibP2PDB.DBVersion integer Database version number.

--- @class LibP2PDB.DBHandle Database handle.

--- @class LibP2PDB.DBDesc Description for creating a new database.
--- @field prefix LibP2PDB.DBPrefix Unique communication prefix for the database (max 16 chars).
--- @field version LibP2PDB.DBVersion? Optional database version number (default: 1).
--- @field onError LibP2PDB.DBOnErrorCallback? Optional callback function(errMsg, stack) invoked on errors.
--- @field onMigrateDB LibP2PDB.DBOnMigrateDBCallback? Optional callback function(target, source) invoked when database migration is needed.
--- @field onMigrateTable LibP2PDB.DBOnMigrateTableCallback? Optional callback function(target, source) invoked when table migration is needed.
--- @field onMigrateRow LibP2PDB.DBOnMigrateRowCallback? Optional callback function(target, source) invoked when row migration is needed.
--- @field filter LibP2PDB.Filter? Optional custom filter digest generation (default: LibPatternedBloomFilter if available).
--- @field serializer LibP2PDB.Serializer? Optional custom serializer for encoding/decoding data (default: LibSerialize if available).
--- @field compressor LibP2PDB.Compressor? Optional custom compressor for compressing/decompressing data (default: LibDeflate if available).
--- @field encoder LibP2PDB.Encoder? Optional custom encoder for encoding/decoding data for chat channels and print (default: LibDeflate if available).
--- @field channels string[]? Optional array of custom channels to use for broadcasts, in addition to default channels (GUILD, RAID, PARTY, YELL).
--- @field onChange LibP2PDB.DBOnChangeCallback? Optional callback function(tableName, key, data) invoked on any row change.
--- @field discoveryQuietPeriod number? Optional seconds of quiet time with no new peers before considering discovery complete (default: 1.5).
--- @field discoveryMaxTime number? Optional maximum seconds to wait for peer discovery before considering it complete (default: 3.0).
--- @field onDiscoveryComplete LibP2PDB.DBOnDiscoveryCompleteCallback? Optional callback function() invoked when peers discovery completes.
--- @field peerTimeout number? Optional seconds of inactivity after which a peer is considered inactive (default: 100.0).

--- @class LibP2PDB.Filter Filter interface for generating data digests.
--- @field New fun(capacity: integer, seed: integer): LibP2PDB.Filter Creates a new filter instance.
--- @field Insert fun(self: LibP2PDB.Filter, value: any): boolean Inserts a value into the filter.
--- @field Contains fun(self: LibP2PDB.Filter, value: any): boolean Determine if the filter contains a value.
--- @field Export fun(self: LibP2PDB.Filter): any Exports the filter to a compact format.
--- @field Import fun(state: any): LibP2PDB.Filter Imports the filter from a compact format.

--- @class LibP2PDB.Serializer Serializer interface for serializing/deserializing data.
--- @field Serialize fun(self: LibP2PDB.Serializer, data: any): string Serializes data to a string.
--- @field Deserialize fun(self: LibP2PDB.Serializer, str: string): any? Deserializes a string, restoring the original data.

--- @class LibP2PDB.Compressor Compressor interface for compressing/decompressing data.
--- @field Compress fun(self: LibP2PDB.Compressor, str: string): string Compresses a string.
--- @field Decompress fun(self: LibP2PDB.Compressor, str: string): string? Decompresses a string, restoring the original string.

--- @class LibP2PDB.Encoder Encoder interface for encoding/decoding data.
--- @field EncodeForChannel fun(self: LibP2PDB.Encoder, str: string): string Encodes a string for safe transmission over chat channels.
--- @field DecodeFromChannel fun(self: LibP2PDB.Encoder, str: string): string? Decodes a string received from chat channels, restoring the original string.
--- @field EncodeForPrint fun(self: LibP2PDB.Encoder, str: string): string Encodes a string for safe display or persistence in saved variables.
--- @field DecodeFromPrint fun(self: LibP2PDB.Encoder, str: string): string? Decodes a string from display/storage, restoring the original string.

--- @alias LibP2PDB.DBOnErrorCallback fun(errMsg: string, stack: string?) Callback function invoked on errors.
--- @alias LibP2PDB.DBOnMigrateDBCallback fun(target: LibP2PDB.MigrationContext, source: LibP2PDB.MigrationContext) Callback function invoked when database migration is needed.
--- @alias LibP2PDB.DBOnMigrateTableCallback fun(target: LibP2PDB.MigrationContext, source: LibP2PDB.MigrationContext): LibP2PDB.TableName? Callback function invoked when table migration is needed.
--- @alias LibP2PDB.DBOnMigrateRowCallback fun(target: LibP2PDB.MigrationContext, source: LibP2PDB.MigrationContext): LibP2PDB.TableKey?, LibP2PDB.RowData? Callback function invoked when row migration is needed.
--- @alias LibP2PDB.DBOnChangeCallback fun(tableName: string, key: LibP2PDB.TableKey, data: LibP2PDB.RowData?) Callback function invoked on any row change.
--- @alias LibP2PDB.DBOnDiscoveryCompleteCallback fun() Callback function invoked when peer discovery completes.

--- @class LibP2PDB.MigrationContext Context information for database/table/row migrations.
--- @field db LibP2PDB.DBHandle Database handle.
--- @field version LibP2PDB.DBVersion Database version number.
--- @field tableName LibP2PDB.TableName? Table name if applicable.
--- @field key LibP2PDB.TableKey? Table key if applicable.
--- @field data LibP2PDB.RowData? Row data if applicable.

--- Create a new peer-to-peer synchronized database instance.
--- Each database is identified by a unique prefix and operates independently.
--- Database configuration cannot be changed after creation.
--- Use GetDatabase to retrieve existing databases by prefix.
--- @param desc LibP2PDB.DBDesc Description of the database to create.
--- @return LibP2PDB.DBHandle dbh The newly created database handle.
function LibP2PDB:NewDatabase(desc)
    assert(IsNonEmptyTable(desc), "desc must be a non-empty table")
    assert(IsNonEmptyStringEx(desc.prefix, 1, 16), "desc.prefix must be a non-empty string (1-16 chars)")
    assert(IsIntegerOrNil(desc.version, 1), "desc.version must be an integer greater than 0 if provided")
    assert(IsFunctionOrNil(desc.onError), "desc.onError must be a function if provided")
    assert(IsFunctionOrNil(desc.onMigrateDB), "desc.onMigrateDB must be a function if provided")
    assert(IsFunctionOrNil(desc.onMigrateTable), "desc.onMigrateTable must be a function if provided")
    assert(IsFunctionOrNil(desc.onMigrateRow), "desc.onMigrateRow must be a function if provided")
    assert(IsInterfaceOrNil(desc.filter, "New", "Insert", "Contains", "Export", "Import"), "desc.filter must be a filter interface if provided")
    assert(IsInterfaceOrNil(desc.serializer, "Serialize", "Deserialize"), "desc.serializer must be a serializer interface if provided")
    assert(IsInterfaceOrNil(desc.compressor, "Compress", "Decompress"), "desc.compressor must be a compressor interface if provided")
    assert(IsInterfaceOrNil(desc.encoder, "EncodeForChannel", "DecodeFromChannel", "EncodeForPrint", "DecodeFromPrint"), "desc.encoder must be an encoder interface if provided")
    assert(IsNonEmptyTableOrNil(desc.channels), "desc.channels must be a non-empty array of string if provided")
    assert(IsFunctionOrNil(desc.onChange), "desc.onChange must be a function if provided")
    assert(IsNumberOrNil(desc.discoveryQuietPeriod, 0.0), "desc.discoveryQuietPeriod must be a positive number if provided")
    assert(IsNumberOrNil(desc.discoveryMaxTime, 0.0), "desc.discoveryMaxTime must be a positive number if provided")
    assert(IsFunctionOrNil(desc.onDiscoveryComplete), "desc.onDiscoveryComplete must be a function if provided")
    assert(IsNumberOrNil(desc.peerTimeout, 0.0), "desc.peerTimeout must be a positive number if provided")

    if desc.channels then
        for _, channel in ipairs(desc.channels) do
            assert(IsNonEmptyString(channel), "each channel in desc.channels must be a non-empty string")
        end
    end

    -- Ensure prefix is unique
    assert(priv.prefixes[desc.prefix] == nil, "a database with prefix '" .. desc.prefix .. "' already exists")

    -- Create the new database
    local dbi = { --- @type LibP2PDB.DBInstance
        -- Identity
        prefix = desc.prefix,
        version = desc.version or 1,
        clock = 0,
        -- Configuration
        filter = desc.filter,
        serializer = desc.serializer,
        compressor = desc.compressor,
        encoder = desc.encoder,
        channels = desc.channels,
        discoveryQuietPeriod = desc.discoveryQuietPeriod or 1.5,
        discoveryMaxTime = desc.discoveryMaxTime or 3.0,
        peerTimeout = desc.peerTimeout or 100.0,
        -- Networking
        peers = {},
        peersSorted = {},
        buckets = {},
        -- Data
        tables = {},
        -- Callbacks
        onError = desc.onError,
        onMigrateDB = desc.onMigrateDB,
        onMigrateTable = desc.onMigrateTable,
        onMigrateRow = desc.onMigrateRow,
        onChange = desc.onChange,
        onDiscoveryComplete = desc.onDiscoveryComplete,
        -- Access control
        --writePolicy = nil,
    }

    -- Record self in peers list for easier comparisons (but never updated)
    priv:RecordPeer(dbi, priv.peerId, priv.playerName, dbi.clock)

    -- Setup default filter if none provided
    if not dbi.filter then
        if LibPatternedBloomFilter then
            --- @class LibP2PDB.DefaultFilter : LibP2PDB.Filter
            dbi.filter = {
                New = function(capacity, seed)
                    return LibPatternedBloomFilter.New(capacity, seed, 0.01)
                end,
                Insert = LibPatternedBloomFilter.Insert,
                Contains = LibPatternedBloomFilter.Contains,
                Export = LibPatternedBloomFilter.Export,
                Import = LibPatternedBloomFilter.Import,
            }
        else
            error("LibP2PDB requires a filter implementation; load LibPatternedBloomFilter or provide custom filter via desc.filter")
        end
    end

    -- Validate filter works
    do
        local testFilter = dbi.filter.New(10, 12345)
        testFilter:Insert("test1")
        testFilter:Insert("test2")
        assert(testFilter:Contains("test1"), "filter provided in desc.filter is invalid (missing 'test1')")
        assert(testFilter:Contains("test2"), "filter provided in desc.filter is invalid (missing 'test2')")
        assert(not testFilter:Contains("test3"), "filter provided in desc.filter is invalid (contains 'test3')")
    end

    -- Setup default serializer if none provided
    if not dbi.serializer then
        if LibSerialize then
            --- @class LibP2PDB.DefaultSerializer : LibP2PDB.Serializer
            dbi.serializer = {
                Serialize = function(self, data)
                    return LibSerialize:Serialize(data)
                end,
                Deserialize = function(self, str)
                    local success, data = LibSerialize:Deserialize(str)
                    if success then
                        return data
                    else
                        if type(data) == "string" then
                            ReportError(dbi, "LibSerialize failed to deserialize data: %s", data)
                        else
                            ReportError(dbi, "LibSerialize failed to deserialize data")
                        end
                    end
                end,
            }
        else
            error("LibP2PDB requires a serializer implementation; load LibSerialize or provide custom serializer via desc.serializer")
        end
    end

    -- Validate serialization works
    do
        local testData = { a = "value", b = 42, c = true, d = nil, nested = { e = "nested", f = 100, g = false, h = nil } }
        local serialized = dbi.serializer:Serialize(testData)
        local deserialized = dbi.serializer:Deserialize(serialized)
        assert(DeepEqual(testData, deserialized), "serializer provided in desc.serializer is invalid")
    end

    -- Setup default compressor if none provided
    if not dbi.compressor then
        if LibDeflate then
            --- @class LibP2PDB.DefaultCompressor : LibP2PDB.Compressor
            dbi.compressor = {
                Compress = function(self, str)
                    return (LibDeflate:CompressDeflate(str))
                end,
                Decompress = function(self, str)
                    local data = LibDeflate:DecompressDeflate(str)
                    if data then
                        return data
                    else
                        ReportError(dbi, "LibDeflate failed to decompress data")
                    end
                end,
            }
        else
            error("LibP2PDB requires a compressor implementation; load LibDeflate or provide custom compressor via desc.compressor")
        end
    end

    -- Validate compression works
    do
        local testString = "This is a test string for compression."
        local compressed = dbi.compressor:Compress(testString)
        local decompressed = dbi.compressor:Decompress(compressed)
        assert(decompressed == testString, "compressor provided in desc.compressor is invalid")
    end

    -- Setup default encoder if none provided
    if not dbi.encoder then
        if LibDeflate then
            --- @class LibP2PDB.DefaultEncoder : LibP2PDB.Encoder
            --- @field channelCodec LibDeflate.Codec? Custom codec instance
            dbi.encoder = {
                -- Create custom codec that rejects \000 (NULL), \010 (LF), and \013 (CR).
                -- This is because SAY/YELL channels cannot handle LF and CR characters in
                -- addition to NULL and will just truncate the message if they are present.
                channelCodec = LibDeflate:CreateCodec("\000\010\013", "\001", ""),
                EncodeForChannel = function(self, str)
                    return self.channelCodec:Encode(str)
                end,
                DecodeFromChannel = function(self, str)
                    local data = self.channelCodec:Decode(str)
                    if data then
                        return data
                    else
                        ReportError(dbi, "LibDeflate failed to decode channel data")
                    end
                end,
                EncodeForPrint = function(self, str)
                    return LibDeflate:EncodeForPrint(str)
                end,
                DecodeFromPrint = function(self, str)
                    local data = LibDeflate:DecodeForPrint(str)
                    if data then
                        return data
                    else
                        ReportError(dbi, "LibDeflate failed to decode print data")
                    end
                end,
            }
        else
            error("LibP2PDB requires an encoder implementation; load LibDeflate or provide custom encoder via desc.encoder")
        end
    end

    -- Validate encoding works
    do
        local testString = "This is a test string for encoding.\000\010\013"
        local encodedChannel = dbi.encoder:EncodeForChannel(testString)
        local decodedChannel = dbi.encoder:DecodeFromChannel(encodedChannel)
        assert(decodedChannel == testString, "encoder provided in desc.encoder is invalid for channel encoding")

        local encodedPrint = dbi.encoder:EncodeForPrint(testString)
        local decodedPrint = dbi.encoder:DecodeFromPrint(encodedPrint)
        assert(decodedPrint == testString, "encoder provided in desc.encoder is invalid for print encoding")
    end

    -- Register comm prefix
    AceComm.RegisterComm(priv, desc.prefix)
    assert(C_ChatInfo.IsAddonMessagePrefixRegistered(desc.prefix), "failed to register addon message prefix '" .. desc.prefix .. "'")

    -- Register the new database
    --- @type LibP2PDB.DBHandle
    local dbh = {}
    priv.prefixes[desc.prefix] = dbh
    priv.databases[dbh] = dbi
    return dbh
end

--- Retrieve a database by its prefix.
--- @param prefix string Unique communication prefix for the database (max 16 chars).
--- @return LibP2PDB.DBHandle? dbh The database handle if found, or nil if not found.
function LibP2PDB:GetDatabase(prefix)
    assert(IsNonEmptyStringEx(prefix, 1, 16), "prefix must be a non-empty string (1-16 chars)")
    return priv.prefixes[prefix]
end

------------------------------------------------------------------------------------------------------------------------
-- Public API: Table Definition
------------------------------------------------------------------------------------------------------------------------

--- @alias LibP2PDB.Clock integer Lamport clock value.
--- @alias LibP2PDB.PeerID string Peer identifier value.
--- @alias LibP2PDB.Tombstone boolean Flag indicating if a row is a tombstone (deleted).
--- @alias LibP2PDB.TableName string Name of the table.
--- @alias LibP2PDB.TableKeyType "string"|"number" Data type of the primary key.
--- @alias LibP2PDB.TableKey string|number Primary key value.
--- @alias LibP2PDB.TableSchema table<string|number, string|string[]> Table schema definition.
--- @alias LibP2PDB.TableSchemaSorted [string|number, string|string[]] Table schema as a sorted array of field name and allowed types pairs.
--- @alias LibP2PDB.TableOnValidateCallback fun(key: LibP2PDB.TableKey, data: LibP2PDB.RowData):boolean Callback function for custom row validation.
--- @alias LibP2PDB.TableOnChangeCallback fun(key: LibP2PDB.TableKey, data: LibP2PDB.RowData?) Callback function invoked on row data changes.
--- @alias LibP2PDB.RowData table<LibP2PDB.RowDataKey, LibP2PDB.RowDataValue> Data for a row in a table.
--- @alias LibP2PDB.RowDataKey string|number Key of a field in a row.
--- @alias LibP2PDB.RowDataValue boolean|string|number|nil Value of a field in a row.

--- @class LibP2PDB.Row Row in a table.
--- @field data LibP2PDB.RowData? Data for the row (nil if tombstone).
--- @field version LibP2PDB.RowVersion Version metadata for the row.

--- @class LibP2PDB.RowVersion Version metadata for a row in a table.
--- @field clock LibP2PDB.Clock Lamport clock value.
--- @field peer LibP2PDB.PeerID Peer ID that last modified the row.
--- @field tombstone LibP2PDB.Tombstone? Optional flag indicating if the row is a tombstone (deleted).

--- @class LibP2PDB.TableDesc Description for creating a new table in the database.
--- @field name LibP2PDB.TableName Name of the table to create.
--- @field keyType LibP2PDB.TableKeyType Data type of the primary key.
--- @field schema LibP2PDB.TableSchema? Optional table schema defining field names and their allowed data types.
--- @field onValidate LibP2PDB.TableOnValidateCallback? Optional callback function(key, data) for custom row validation. Must return true if valid, false otherwise. Data is a copy and has not yet been applied when this is called.
--- @field onChange LibP2PDB.TableOnChangeCallback? Optional callback function(key, data) on row data changes. Data is nil for deletions. Data is a copy, and has already been applied when this is called.

--- Create a new table in the database with an optional schema.
--- If no schema is provided, the table accepts any fields.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param desc LibP2PDB.TableDesc Description of the table to define.
function LibP2PDB:NewTable(db, desc)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyTable(desc), "desc must be a non-empty table")
    assert(IsNonEmptyString(desc.name), "desc.name must be a non-empty string")
    assert(IsNonEmptyString(desc.keyType), "desc.keyType must be a non-empty string")
    assert(desc.keyType == "string" or desc.keyType == "number", "desc.keyType must be 'string' or 'number'")
    assert(IsNonEmptyTableOrNil(desc.schema), "desc.schema must be a non-empty table if provided")
    for fieldKey, allowedTypes in pairs(desc.schema or {}) do
        assert(IsNonEmptyString(fieldKey) or IsNumber(fieldKey), "each field key in desc.schema must be a non-empty string or number")
        if IsNonEmptyTable(allowedTypes) then
            --- @cast allowedTypes string[]
            for _, allowedType in ipairs(allowedTypes) do
                assert(IsNonEmptyString(allowedType), "each type in desc.schema field types must be a non-empty string")
                assert(IsPrimitiveType(allowedType), "field types in desc.schema must be 'string', 'number', 'boolean', or 'nil'")
            end
        elseif IsNonEmptyString(allowedTypes) then
            --- @cast allowedTypes string
            assert(IsPrimitiveType(allowedTypes), "field type in desc.schema must be 'string', 'number', 'boolean', or 'nil'")
        else
            error("each field value in desc.schema must be a non-empty string or non-empty table of strings")
        end
    end
    assert(IsFunctionOrNil(desc.onValidate), "desc.onValidate must be a function if provided")
    assert(IsFunctionOrNil(desc.onChange), "desc.onChange must be a function if provided")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Ensure table name is unique
    assert(dbi.tables[desc.name] == nil, "table '" .. desc.name .. "' already exists in the database")

    -- Generate sorted schema
    local schemaSorted = nil --- @type LibP2PDB.TableSchemaSorted
    if desc.schema then
        local fieldNames = {}
        for fieldName in pairs(desc.schema) do
            tinsert(fieldNames, fieldName)
        end
        tsort(fieldNames)
        schemaSorted = {}
        for _, fieldName in ipairs(fieldNames) do
            tinsert(schemaSorted, { fieldName, desc.schema[fieldName] })
        end
    end

    -- Create the bucketed hash set for the summary
    local summary = LibBucketedHashSet.New(32)
    summary.keyIndex = {} --- @type table<LibP2PDB.TableKey, integer>

    -- Create the table instance
    --- @type LibP2PDB.TableInstance
    dbi.tables[desc.name] = {
        keyType = desc.keyType,
        schema = desc.schema,
        schemaSorted = schemaSorted,
        onValidate = desc.onValidate,
        onChange = desc.onChange,
        subscribers = setmetatable({}, { __mode = "k" }),
        seed = 0,
        rowCount = 0,
        rows = {},
        summary = summary,
    }
end

------------------------------------------------------------------------------------------------------------------------
-- Public API: CRUD Operations
------------------------------------------------------------------------------------------------------------------------

--- Insert a new key into a table.
--- Validates the key type and row schema against the table definition.
--- If a schema is defined, extra fields in the row are ignored.
--- If no schema is defined, all primitive fields are accepted.
--- Fails if the key already exists (use SetKey to overwrite).
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to insert into.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @param data table Data for the new row.
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:InsertKey(db, tableName, key, data)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")
    assert(IsTable(data), "data must be a table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table and key type
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")
    assert(type(key) == ti.keyType, "expected key of type '" .. ti.keyType .. "' for table '" .. tableName .. "', but was '" .. type(key) .. "'")

    -- Ensure the key does not already exist
    local existingRow = ti.rows[key]
    if existingRow and not existingRow.version.tombstone then
        error("key '" .. tostring(key) .. "' already exists in table '" .. tableName .. "'")
    end

    -- Prepare the row data
    local rowData = priv:PrepareRowData(tableName, ti, data)

    -- Set the row
    return priv:SetKey(dbi, tableName, ti, key, rowData)
end

--- Create or replace a key in a table.
--- Validates the key type and row schema against the table definition.
--- If a schema is defined, extra fields in the row are ignored.
--- If no schema is defined, all primitive fields are accepted.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to set into.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @param data table Row data containing fields defined in the table schema.
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:SetKey(db, tableName, key, data)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")
    assert(IsTable(data), "row must be a table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table and key type
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")
    assert(type(key) == ti.keyType, "expected key of type '" .. ti.keyType .. "' for table '" .. tableName .. "', but was '" .. type(key) .. "'")

    -- Prepare the row data
    local rowData = priv:PrepareRowData(tableName, ti, data)

    -- Set the row
    return priv:SetKey(dbi, tableName, ti, key, rowData)
end

--- @alias LibP2PDB.TableUpdateFunction fun(data: LibP2PDB.RowData?): LibP2PDB.RowData Function invoked to produce updated row data.

--- Create or update a key in a table.
--- Validates the key type against the table definition.
--- The update function is called with the current row data and must return the updated row data.
--- If a schema is defined, extra fields in the updated row are ignored.
--- If no schema is defined, all primitive fields are accepted.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to update.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @param updateFn LibP2PDB.TableUpdateFunction Function invoked to produce updated row data. Current row data is passed as a copy.
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:UpdateKey(db, tableName, key, updateFn)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")
    assert(IsFunction(updateFn), "updateFn must be a function")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table and key type
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")
    assert(type(key) == ti.keyType, "expected key of type '" .. ti.keyType .. "' for table '" .. tableName .. "', but was '" .. type(key) .. "'")

    -- Call the update function to get the updated row data
    local existingRow = ti.rows[key]
    local success, updatedRow = SafeCall(dbi, updateFn, existingRow and ShallowCopy(existingRow.data) or nil)
    if not success then
        return false
    end
    assert(IsTable(updatedRow), "updateFn must return a table")

    -- Prepare the row data
    local rowData = priv:PrepareRowData(tableName, ti, updatedRow)

    -- Set the row
    return priv:SetKey(dbi, tableName, ti, key, rowData)
end

--- Delete a key from a table.
--- Validates the key type against the table definition.
--- Marks the row as a tombstone for gossip synchronization, whether the row existed or not.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to delete from.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:DeleteKey(db, tableName, key)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table and key type
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")
    assert(type(key) == ti.keyType, "expected key of type '" .. ti.keyType .. "' for table '" .. tableName .. "', but was '" .. type(key) .. "'")

    -- Set the row
    return priv:SetKey(dbi, tableName, ti, key, nil)
end

--- Determine if a key exists in a table.
--- A key exists if it is present and not marked as a tombstone.
--- Validates the key type against the table definition.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to check.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @return boolean exists True if the key exists and is not marked as a tombstone (deleted), false otherwise.
function LibP2PDB:HasKey(db, tableName, key)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table and key type
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")
    assert(type(key) == ti.keyType, "expected key of type '" .. ti.keyType .. "' for table '" .. tableName .. "', but was '" .. type(key) .. "'")

    -- Lookup the row and return existence
    local row = ti.rows[key]
    if row == nil or row.version.tombstone then
        return false
    end
    return true
end

--- Retrieve the data for a specific key in a table.
--- A key exists if it is present and not marked as a tombstone.
--- Validates the key type against the table definition.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to get from.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @return LibP2PDB.RowData? rowData The row data if found, or nil if not found or tombstone (deleted).
function LibP2PDB:GetKey(db, tableName, key)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table and key type
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")
    assert(type(key) == ti.keyType, "expected key of type '" .. ti.keyType .. "' for table '" .. tableName .. "', but was '" .. type(key) .. "'")

    -- Lookup the row
    local row = ti.rows[key]
    if row == nil or row.version.tombstone then
        return nil
    end

    -- Return a copy of the row data
    return ShallowCopy(row.data)
end

------------------------------------------------------------------------------------------------------------------------
-- Public API: Subscriptions
------------------------------------------------------------------------------------------------------------------------

--- Subscribe to changes in a specific table.
--- The callback is invoked with the key and new data (nil for deletions) whenever a row changes.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to subscribe to
--- @param callback LibP2PDB.TableOnChangeCallback Function(key, data) to invoke on changes
function LibP2PDB:Subscribe(db, tableName, callback)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsFunction(callback), "callback must be a function")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")

    -- Register subscriber (safe even if already present)
    ti.subscribers[callback] = true
end

--- Unsubscribe to changes in a specific table.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to unsubscribe from
--- @param callback LibP2PDB.TableOnChangeCallback Function(key, data) to remove from subscriptions
function LibP2PDB:Unsubscribe(db, tableName, callback)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "table name must be a non-empty string")
    assert(IsFunction(callback), "callback must be a function")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table
    local t = dbi.tables[tableName]
    assert(t, "table '" .. tableName .. "' is not defined in the database")

    -- Remove subscriber (safe even if not present)
    t.subscribers[callback] = nil
end

------------------------------------------------------------------------------------------------------------------------
-- Public API: Persistence
------------------------------------------------------------------------------------------------------------------------

--- @class LibP2PDB.DBState
--- @field [1] LibP2PDB.DBVersion Database version number.
--- @field [2] LibP2PDB.Clock Database Lamport clock value.
--- @field [3] LibP2PDB.TableStateMap Table states representing each table in the database.

--- @alias LibP2PDB.TableStateMap table<LibP2PDB.TableName, LibP2PDB.RowStateMap> Table states representing each table in the database.
--- @alias LibP2PDB.RowStateMap table<LibP2PDB.TableKey, LibP2PDB.RowState> Table of row states for a specific table.

--- @class LibP2PDB.RowState
--- @field [1] LibP2PDB.RowDataState Data for the row (NIL_MARKER if nil).
--- @field [2] LibP2PDB.Clock Lamport clock value when the row was last modified.
--- @field [3] LibP2PDB.PeerID Peer ID that last modified the row.
--- @field [4] LibP2PDB.Tombstone? Optional flag indicating if the row is a tombstone (deleted).

--- @alias LibP2PDB.RowDataState string|[LibP2PDB.RowDataValue]|LibP2PDB.RowData Row data state, either as an array of values (if schema defined), a table with field names (if no schema), or NIL_MARKER for nil.

--- Export the database state to a compact table format.
--- If a table has a schema, fields are exported in alphabetical order without names.
--- If no schema is defined, all fields are exported in arbitrary order with names.
--- Empty tables or rows are omitted from the exported output.
--- If the database state is empty, nil is returned.
--- @param db LibP2PDB.DBHandle Database handle.
--- @return LibP2PDB.DBState? state The exported database state in compact format.
function LibP2PDB:ExportDatabase(db)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Export database state
    return priv:ExportDatabase(dbi)
end

--- Import a database state from a compact table format.
--- Merges the imported state with existing data based on version metadata.
--- Validates incoming data against table definitions, skipping invalid entries.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param state LibP2PDB.DBState The database state to import.
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:ImportDatabase(db, state)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyTable(state), "state must be a non-empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Import database state
    return priv:ImportDatabase(dbi, state)
end

--- @alias LibP2PDB.ImportCompleteCallback fun(success: boolean, duration: number) Callback function invoked when async import completes.

--- Asynchronously import a database state from a compact table format.
--- Merges the imported state with existing data based on version metadata.
--- Validates incoming data against table definitions, skipping invalid entries.
--- The import process yields periodically to avoid blocking the main thread.
--- Calls onComplete callback when finished with success status and duration in seconds.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param state LibP2PDB.DBState The database state to import.
--- @param onComplete LibP2PDB.ImportCompleteCallback Callback function(success, duration) invoked when import completes.
--- @param maxTime number? Optional maximum time in seconds to spend per processing slice (defaults to 0.01 seconds).
function LibP2PDB:ImportDatabaseAsync(db, state, onComplete, maxTime)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyTable(state), "state must be a non-empty table")
    assert(IsFunction(onComplete), "onComplete must be a function")
    assert(IsNumberOrNil(maxTime), "maxTime must be a number if provided")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Define the import workload
    local workload = function(thread)
        local startTime = GetTimePreciseSec()
        local success = priv:ImportDatabase(dbi, state, thread, maxTime or 0.01)
        SafeCall(dbi, onComplete, success, GetTimePreciseSec() - startTime)
    end

    -- Create and run the coroutine workload
    local thread = coroutine.create(workload)
    C_Timer.NewTicker(0, function(ticker)
        local success = coroutine.resume(thread, thread)
        if not success then
            ticker:Cancel() -- Coroutine finished or errored
        end
    end)
end

------------------------------------------------------------------------------------------------------------------------
-- Public API: Sync / Gossip Controls
------------------------------------------------------------------------------------------------------------------------

--- Discover peers on the database's communication prefix.
--- If onDiscoveryComplete callback is defined, it will be invoked when discovery completes.
--- @param db LibP2PDB.DBHandle Database handle.
function LibP2PDB:DiscoverPeers(db)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Prune timed-out peers
    priv:PruneTimedOutPeers(dbi)

    -- Send the discover peers message
    Spam("broadcasting peer discovery request")
    local obj = {
        type = CommMessageType.PeerDiscoveryRequest,
        peer = priv.peerId,
        data = dbi.clock,
    }
    priv:Broadcast(dbi, obj, dbi.channels, CommPriority.Low)

    -- Record the time of the peer discovery request
    if dbi.onDiscoveryComplete then
        dbi.discoveryStartTime = GetTime()
        dbi.lastDiscoveryResponseTime = dbi.discoveryStartTime
    end
end

--- Initiate a gossip sync by sending a digest request to selected neighbor peers.
--- @param db LibP2PDB.DBHandle Database handle.
function LibP2PDB:SyncDatabase(db)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Get neighbors
    local neighbors = priv:GetNeighbors(dbi)

    -- Send digest requests to neighbors
    if IsNonEmptyTable(neighbors) then
        -- Send the digest request message to closest neighbors
        for neighborPeerId in pairs(neighbors) do
            local peerInfo = dbi.peers[neighborPeerId]
            if peerInfo then
                Spam("sending digest request to '%s'", peerInfo.name)
                local obj = {
                    type = CommMessageType.DigestRequest,
                    peer = priv.peerId,
                }
                priv:Send(dbi, obj, "WHISPER", peerInfo.name, CommPriority.Low)
            else
                ReportError(dbi, "peer info for peer ID '%s' not found", neighborPeerId)
            end
        end
    else
        Spam("no neighbors available for gossip sync")
    end
end

--- Request a key from a target player.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName? Name of the table to request from, or nil to request from all tables.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @param target string Target player name to request the row from.
function LibP2PDB:RequestKey(db, tableName, key, target)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyStringOrNil(tableName), "table name must be a non-empty string or nil")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")
    assert(IsNonEmptyStringEx(target, 2, 12), "target must be a non-empty string (2-12 chars)")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Gather the tables to request from
    local tableNames = {}
    if tableName then
        tinsert(tableNames, tableName)
    else
        for tableName in pairs(dbi.tables) do
            tinsert(tableNames, tableName)
        end
    end

    -- Prepare the database request
    local databaseRequest = {} --- @type LibP2PDB.DBRequest
    for _, tableName in ipairs(tableNames) do
        local ti = dbi.tables[tableName]
        assert(ti, "table '" .. tableName .. "' is not defined in the database")
        databaseRequest[tableName] = { [key] = 0 } --- @type LibP2PDB.TableRequest
    end

    -- Send the row request to the target player
    local obj = {
        type = CommMessageType.RowsRequest,
        peer = priv.peerId,
        data = databaseRequest, --- @type LibP2PDB.DBRequest
    }
    priv:Send(dbi, obj, "WHISPER", target, CommPriority.High)
end

--- Send a key to a target player.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName? Name of the table to send from, or nil to send from all tables that contain the key.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @param target string Target player name to send the row to.
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:SendKey(db, tableName, key, target)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyStringOrNil(tableName), "table name must be a non-empty string or nil")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")
    assert(IsNonEmptyStringEx(target, 2, 12), "target must be a non-empty string (2-12 chars)")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Gather the tables to send
    local tableNames = {} --- @type LibP2PDB.TableName[]
    if tableName then
        tinsert(tableNames, tableName)
    else
        for tableName in pairs(dbi.tables) do
            tinsert(tableNames, tableName)
        end
    end

    -- Collect the rows to send
    local tableStateMap = {} --- @type LibP2PDB.TableStateMap
    for _, tableName in ipairs(tableNames) do
        local ti = dbi.tables[tableName]
        if ti then
            local row = ti.rows[key]
            if row then
                tableStateMap[tableName] = { [key] = priv:ExportRow(row, ti.schemaSorted) } --- @type LibP2PDB.RowStateMap
            end
        end
    end

    -- Ensure there is at least one row to send
    if IsEmptyTable(tableStateMap) then
        ReportError(dbi, "no valid rows to send to '%s'", target)
        return false
    end

    -- Send the row to the target player
    Spam("sending key '%s' from table(s) '%s' to '%s'", tostring(key), strjoin(", ", unpack(tableNames)), target)
    local obj = {
        type = CommMessageType.RowsResponse,
        peer = priv.peerId,
        data = { dbi.version, dbi.clock, tableStateMap }, --- @type LibP2PDB.DBState
    }
    priv:Send(dbi, obj, "WHISPER", target, CommPriority.High)
    return true
end

--- Broadcast a key to all peers.
--- Validates the key type against the table definition.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName? Name of the table to broadcast from, or nil to broadcast from all tables that contain the key.
--- @param key LibP2PDB.TableKey Primary key value for the row (must match table's keyType).
--- @return boolean success Returns true on success, false otherwise.
function LibP2PDB:BroadcastKey(db, tableName, key)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyStringOrNil(tableName), "table name must be a non-empty string or nil")
    assert(IsNonEmptyString(key) or IsNumber(key), "key must be a string or number")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Gather the tables to send
    local tableNames = {} --- @type LibP2PDB.TableName[]
    if tableName then
        tinsert(tableNames, tableName)
    else
        for tableName in pairs(dbi.tables) do
            tinsert(tableNames, tableName)
        end
    end

    -- Collect the rows to send
    local tableStateMap = {} --- @type LibP2PDB.TableStateMap
    for _, tableName in ipairs(tableNames) do
        local ti = dbi.tables[tableName]
        if ti then
            local row = ti.rows[key]
            if row then
                tableStateMap[tableName] = { [key] = priv:ExportRow(row, ti.schemaSorted) } --- @type LibP2PDB.RowStateMap
            end
        end
    end

    -- Ensure there is at least one row to send
    if IsEmptyTable(tableStateMap) then
        ReportError(dbi, "no valid rows to broadcast")
        return false
    end

    -- Send the row to the target player
    Spam("broadcasting key '%s' from table(s) '%s'", tostring(key), strjoin(", ", unpack(tableNames)))
    local obj = {
        type = CommMessageType.RowsResponse,
        peer = priv.peerId,
        data = { dbi.version, dbi.clock, tableStateMap }, --- @type LibP2PDB.DBState
    }
    priv:Broadcast(dbi, obj, dbi.channels, CommPriority.High)
    return true
end

------------------------------------------------------------------------------------------------------------------------
-- Public API: Utility / Metadata
------------------------------------------------------------------------------------------------------------------------

--- Return the local peer's unique ID.
--- @return LibP2PDB.PeerID peerId The local peer ID.
function LibP2PDB:GetPeerId()
    return priv.peerId
end

--- Return a remote peer's unique ID from its GUID.
--- @param guid string Full GUID of the remote peer.
--- @return LibP2PDB.PeerID? peerId The remote peer ID if valid, or nil if not a player GUID.
function LibP2PDB:GetPeerIdFromGUID(guid)
    assert(IsNonEmptyString(guid), "guid must be a non-empty string")
    if strsub(guid, 1, 7) ~= "Player-" then
        return nil
    end
    return strsub(guid, 8) -- skip "Player-" prefix
end

--- List all defined tables in the database.
--- @param db LibP2PDB.DBHandle Database handle.
--- @return [LibP2PDB.TableName] tables Array of table names defined in the database
function LibP2PDB:ListTables(db)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Collect table names
    local tableNames = {}
    for tableName in pairs(dbi.tables) do
        tinsert(tableNames, tableName)
    end
    return tableNames
end

--- List all keys of a specific table in the database.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param tableName LibP2PDB.TableName Name of the table to list keys from
--- @return [LibP2PDB.TableKey] keys Array of keys in the specified table
function LibP2PDB:ListKeys(db, tableName)
    assert(IsEmptyTable(db), "db must be an empty table")
    assert(IsNonEmptyString(tableName), "tableName must be a non-empty string")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Validate table
    local ti = dbi.tables[tableName]
    assert(ti, "table '" .. tableName .. "' is not defined in the database")

    -- Collect keys
    local keys = {}
    for key, row in pairs(ti.rows) do
        if row and not row.version.tombstone then
            tinsert(keys, key)
        end
    end
    return keys
end

--- List all discovered peers for this database.
--- This list is not persisted and is reset on logout/reload.
--- @param db LibP2PDB.DBHandle Database handle.
--- @return table<LibP2PDB.PeerID, table> peers Table of peerId -> peer data
function LibP2PDB:ListPeers(db)
    assert(IsEmptyTable(db), "db must be an empty table")

    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Collect peers
    local peers = {}
    for peerId, peerInfo in pairs(dbi.peers) do
        peers[peerId] = DeepCopy(peerInfo)
    end
    return peers
end

--- Serialize data using the database's serializer.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param data any Data to serialize.
--- @return string serialized The serialized string representation of the data.
function LibP2PDB:Serialize(db, data)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Serialize the data
    return dbi.serializer:Serialize(data)
end

--- Deserialize data using the database's serializer.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Serialized string representation of the value.
--- @return any? data The deserialized data if successful, or nil if failed.
function LibP2PDB:Deserialize(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Deserialize the string
    return dbi.serializer:Deserialize(str)
end

--- Decompress a string using the database's compressor.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Compressed string to decompress.
--- @return string decompressed The decompressed string.
function LibP2PDB:Compress(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Compress the data
    return dbi.compressor:Compress(str)
end

--- Decompress a string using the database's compressor.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Compressed string to decompress.
--- @return string? decompressed The decompressed string, or nil if decompression failed.
function LibP2PDB:Decompress(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Decompress the data
    return dbi.compressor:Decompress(str)
end

--- Encode a string for safe transmission over WoW chat channels, using the database's encoder.
--- This prepares data for sending via chat channels by escaping unsafe characters.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Input string to encode.
--- @return string encoded The encoded string safe for transmission.
function LibP2PDB:EncodeForChannel(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Encode the data
    return dbi.encoder:EncodeForChannel(str)
end

--- Decode a string received from WoW chat channels, using the database's encoder.
--- This reverses the encoding applied by EncodeForChannel to restore the original data.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Encoded string to decode.
--- @return string? decoded The decoded string if successful, or nil if decoding failed.
function LibP2PDB:DecodeFromChannel(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Decode the data
    return dbi.encoder:DecodeFromChannel(str)
end

--- Encode a string for safe display or persistence, using the database's encoder.
--- This prepares data for printing to chat windows or saving in saved variables.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Input string to encode.
--- @return string encoded The encoded string safe for printing.
function LibP2PDB:EncodeForPrint(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Encode the data
    return dbi.encoder:EncodeForPrint(str)
end

--- Decode a string previously encoded for display or persistence, using the database's encoder.
--- This reverses the encoding applied by EncodeForPrint to restore the original data.
--- @param db LibP2PDB.DBHandle Database handle.
--- @param str string Encoded string to decode.
--- @return string? decoded The decoded string if successful, or nil if decoding failed.
function LibP2PDB:DecodeFromPrint(db, str)
    assert(IsEmptyTable(db), "db must be an empty table")

    -- Validate db instance
    local dbi = priv.databases[db]
    assert(dbi, "db is not a recognized database handle")

    -- Decode the data
    return dbi.encoder:DecodeFromPrint(str)
end

--- Sanitize a string for printing in WoW chat channels.
--- Replaces non-printable characters with their numeric byte values prefixed by a backslash.
--- @param s string Input string
--- @return string sanitized The sanitized string safe for printing
function LibP2PDB:SanitizeForPrint(s)
    local parts = {}
    local len = #s
    for i = 1, len do
        local byte = strbyte(s, i)
        if byte >= 32 and byte <= 126 then
            tinsert(parts, strchar(byte))
        else
            tinsert(parts, "\\")
            tinsert(parts, tostring(byte))
        end
    end
    return tconcat(parts)
end

------------------------------------------------------------------------------------------------------------------------
-- Private API
------------------------------------------------------------------------------------------------------------------------

--- @class LibP2PDB.DBInstance Database instance.
--- @field prefix LibP2PDB.DBPrefix Unique communication prefix.
--- @field version LibP2PDB.DBVersion Database version.
--- @field clock LibP2PDB.Clock Lamport clock for versioning.
--- @field channels string[]? List of custom channels for broadcasts.
--- @field discoveryQuietPeriod number Seconds of quiet time for discovery completion.
--- @field discoveryMaxTime number Maximum time for discovery completion.
--- @field filter LibP2PDB.Filter Filter interface.
--- @field serializer LibP2PDB.Serializer Serializer interface.
--- @field compressor LibP2PDB.Compressor Compressor interface.
--- @field encoder LibP2PDB.Encoder Encoder interface.
--- @field peers table<string, LibP2PDB.PeerInfo> Known peers for this session.
--- @field peersSorted LibP2PDB.PeerID[] Sorted array of peer IDs for efficient neighbors lookup.
--- @field peerTimeout number Timeout in seconds for considering a peer inactive.
--- @field buckets table Communication event buckets for burst control.
--- @field tables table<LibP2PDB.TableName, LibP2PDB.TableInstance> Defined tables in the database.
--- @field onError LibP2PDB.DBOnErrorCallback? Callback for error events.
--- @field onMigrateDB LibP2PDB.DBOnMigrateDBCallback? Callback for database migrations.
--- @field onMigrateTable LibP2PDB.DBOnMigrateTableCallback? Callback for table migrations.
--- @field onMigrateRow LibP2PDB.DBOnMigrateRowCallback? Callback for row migrations.
--- @field onChange LibP2PDB.DBOnChangeCallback? Callback for row changes.
--- @field onDiscoveryComplete LibP2PDB.DBOnDiscoveryCompleteCallback? Callback for discovery completion.
--- @field discoveryStartTime number? Local timestamp when discovery started.
--- @field lastDiscoveryResponseTime number? Local timestamp when last discovery response was received.

--- @class LibP2PDB.PeerInfo Peer information.
--- @field name string Name of the peer.
--- @field clock LibP2PDB.Clock Lamport clock of the peer's database.
--- @field lastSeen number Local timestamp of the last time the peer was seen.

--- @class LibP2PDB.TableInstance Table instance.
--- @field keyType LibP2PDB.TableKeyType Primary key type for the table.
--- @field schema LibP2PDB.TableSchema? Optional schema definition for the table.
--- @field schemaSorted LibP2PDB.TableSchemaSorted? Cached sorted schema for the table.
--- @field onValidate LibP2PDB.TableOnValidateCallback? Optional validation callback for rows.
--- @field onChange LibP2PDB.TableOnChangeCallback? Optional change callback for rows.
--- @field subscribers table<LibP2PDB.TableOnChangeCallback, boolean> Weak table of subscriber callbacks.
--- @field seed integer Seed value for the table's filter and bucket hash set.
--- @field rowCount integer Total number of rows in the table (including tombstones).
--- @field rows table<LibP2PDB.TableKey, LibP2PDB.TableRow> Registry of rows in the table.
--- @field summary any Summary of the table's keys, stored in a bucketed hash set.

--- @class LibP2PDB.TableRow Table row definition.
--- @field data LibP2PDB.RowData? Data for the row, or nil if the row is a tombstone (deleted).
--- @field version LibP2PDB.RowVersion Version metadata for the row.

--- @class LibP2PDB.ImportedTable Table imported from a DBState.
--- @field name LibP2PDB.TableName Name of the table.
--- @field rows table<LibP2PDB.TableKey, LibP2PDB.RowData> Table rows mapped by their keys.

--- @class LibP2PDB.ImportedRow Row imported from a DBState.
--- @field key LibP2PDB.TableKey Primary key of the row.
--- @field data LibP2PDB.RowData? Data for the row, or nil if the row is a tombstone.
--- @field version LibP2PDB.RowVersion Version metadata for the row.

--- @alias LibP2PDB.DBDigest table<LibP2PDB.TableName, LibP2PDB.TableDigest> Database digest mapping table names to their table digests.

--- @class LibP2PDB.TableDigest
--- @field filter any Bloom filter representing the table's keys.
--- @field summary any Summary of the table's keys, stored in a bucketed hash set.

--- @alias LibP2PDB.DBRequest table<LibP2PDB.TableName, LibP2PDB.TableRequest> Database request mapping table names to their table requests.
--- @alias LibP2PDB.TableRequest table<LibP2PDB.TableKey, LibP2PDB.RowRequest> Table of row requests mapped by their keys.
--- @alias LibP2PDB.RowRequest LibP2PDB.Clock Current Lamport clock for the row.

--- Set a row in a table, overwriting any existing row.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param tableName LibP2PDB.TableName Name of the table.
--- @param ti LibP2PDB.TableInstance Table instance.
--- @param key LibP2PDB.TableKey Primary key value for the row.
--- @param rowData LibP2PDB.RowData? Row data containing fields defined in the table schema (or nil for tombstone).
--- @return boolean success Returns true on success, false otherwise.
function Private:SetKey(dbi, tableName, ti, key, rowData)
    -- Run custom validation if provided
    if rowData and ti.onValidate then
        local success, result = SafeCall(dbi, ti.onValidate, key, rowData)
        if not success then
            return false -- validation threw an error
        end
        assert(IsBoolean(result), "onValidate must return a boolean")
        if not result then
            return false -- validation failed
        end
    end

    -- Determine if the row will change
    local changes = false
    local existingRow = ti.rows[key]
    if rowData then
        if not existingRow or existingRow.version.tombstone or not ShallowEqual(existingRow.data, rowData) then
            changes = true -- new row or data changes
        end
    else
        if not existingRow or not existingRow.version.tombstone then
            changes = true -- new tombstone row or existing row is not a tombstone
        end
    end

    -- Apply changes if any
    if changes then
        -- Versioning (Lamport clock)
        dbi.clock = dbi.clock + 1

        -- Update row count (must be done before storing the row and updating summary)
        if not existingRow then
            ti.rowCount = ti.rowCount + 1

            -- Resize summary if needed
            local requiredNumBucket = max(32, NextPowerOfTwo(ti.rowCount) / 32)
            if requiredNumBucket > ti.summary.numBuckets then
                self:ResizeTableSummary(ti, requiredNumBucket)
            end
        end

        -- Store the row
        ti.rows[key] = {
            data = rowData,
            version = {
                clock = dbi.clock,
                peer = (key == self.peerId) and "=" or self.peerId,
                tombstone = (rowData == nil) and true or nil,
            },
        }

        -- Update summary
        if existingRow then
            ti.summary:Toggle(key .. existingRow.version.clock)
        end
        ti.summary.keyIndex[key] = ti.summary:Toggle(key .. dbi.clock)

        -- Invoke row changed callbacks
        self:InvokeChangeCallbacks(dbi, tableName, ti, key, rowData)
    end

    return true
end

--- Merge a row in a table, overwriting any existing row, based on version metadata.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param dbClock LibP2PDB.Clock Incoming database Lamport clock.
--- @param tableName LibP2PDB.TableName Name of the table.
--- @param ti LibP2PDB.TableInstance Table instance.
--- @param key LibP2PDB.TableKey Primary key value for the row.
--- @param rowData LibP2PDB.RowData? Row data containing fields defined in the table schema (or nil for tombstone).
--- @param rowVersion LibP2PDB.RowVersion Version metadata for the row.
--- @return boolean success Returns true on success, false otherwise.
function Private:MergeKey(dbi, dbClock, tableName, ti, key, rowData, rowVersion)
    -- Determine if the incoming row is newer
    local existingRow = ti.rows[key]
    if existingRow and self:CompareVersion(rowVersion, existingRow.version) then
        return true -- existing row is newer, skip
    end

    -- Run custom validation if provided
    if rowData and ti.onValidate then
        local success, result = SafeCall(dbi, ti.onValidate, key, rowData)
        if not success then
            return false -- validation threw an error
        end
        assert(IsBoolean(result), "onValidate must return a boolean")
        if not result then
            return false -- validation failed
        end
    end

    -- Determine if the row will change
    local changes = false
    if rowData then
        if not existingRow or existingRow.version.tombstone or not ShallowEqual(existingRow.data, rowData) then
            changes = true -- new row or data changes
        end
    else
        if not existingRow or not existingRow.version.tombstone then
            changes = true -- new tombstone row or existing row is not a tombstone
        end
    end

    -- Apply changes if any
    if changes then
        -- Versioning (Lamport clock)
        dbi.clock = max(dbi.clock, dbClock)

        -- Update row count (must be done before storing the row and updating summary)
        if not existingRow then
            ti.rowCount = ti.rowCount + 1

            -- Resize summary if needed
            local requiredNumBucket = max(32, NextPowerOfTwo(ti.rowCount) / 32)
            if requiredNumBucket > ti.summary.numBuckets then
                self:ResizeTableSummary(ti, requiredNumBucket)
            end
        end

        -- Store the row
        ti.rows[key] = {
            data = rowData,
            version = {
                clock = rowVersion.clock,
                peer = rowVersion.peer,
                tombstone = rowVersion.tombstone,
            },
        }

        -- Update summary
        if existingRow then
            ti.summary:Toggle(key .. existingRow.version.clock)
        end
        ti.summary.keyIndex[key] = ti.summary:Toggle(key .. rowVersion.clock)

        -- Invoke row changed callbacks
        self:InvokeChangeCallbacks(dbi, tableName, ti, key, rowData)
    end

    return true
end

--- Prepare data for a row.
--- If a schema is defined, validates field types and copies only defined fields.
--- If no schema is defined, copies all primitive fields with string or number keys.
--- @param tableName LibP2PDB.TableName Name of the table.
--- @param ti LibP2PDB.TableInstance Table instance.
--- @param data table? Row data to prepare (or nil for tombstone).
--- @return LibP2PDB.RowData? rowData The processed row data.
function Private:PrepareRowData(tableName, ti, data)
    if data == nil then
        return nil -- Tombstone
    end

    local rowData = {}
    if ti.schema then
        -- Schema defined: validate and copy only defined fields
        for k, allowedTypes in pairs(ti.schema) do
            local v = data[k]
            local t = type(v)
            if IsTable(allowedTypes) then
                --- @cast allowedTypes string[]
                assert(Contains(allowedTypes, t), "expected field '" .. k .. "' of type '" .. strjoin(", ", unpack(allowedTypes)) .. "' in table '" .. tableName .. "', but was '" .. t .. "'")
            elseif IsString(allowedTypes) then
                --- @cast allowedTypes string
                assert(t == allowedTypes, "expected field '" .. k .. "' of type '" .. allowedTypes .. "' in table '" .. tableName .. "', but was '" .. t .. "'")
            else
                error("invalid schema definition for field '" .. k .. "' in table '" .. tableName .. "'")
            end
            rowData[k] = v
        end
    else
        -- No schema: copy all primitive fields with string or number keys
        for k, v in pairs(data) do
            if (IsString(k) or IsNumber(k)) and IsPrimitive(v) then
                rowData[k] = v
            end
        end
    end
    return rowData
end

--- Resize a table's summary to accommodate more rows.
--- @param ti LibP2PDB.TableInstance Table instance.
--- @param requiredNumBucket integer Required number of buckets for the summary.
function Private:ResizeTableSummary(ti, requiredNumBucket)
    -- Create new summary
    local summary = LibBucketedHashSet.New(requiredNumBucket)

    -- Rehash existing keys into new summary
    for key, row in pairs(ti.rows) do
        summary.keyIndex[key] = summary:Toggle(key .. row.version.clock)
    end

    -- Replace old summary with new summary
    ti.summary = summary
end

--- Invoke change callbacks for a row change.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param tableName LibP2PDB.TableName Name of the table.
--- @param ti LibP2PDB.TableInstance Table instance.
--- @param key LibP2PDB.TableKey Primary key value for the row.
--- @param rowData LibP2PDB.RowData? New row data (or nil for tombstone).
function Private:InvokeChangeCallbacks(dbi, tableName, ti, key, rowData)
    -- Invoke database global change callback
    if dbi.onChange then
        SafeCall(dbi, dbi.onChange, tableName, key, rowData)
    end

    -- Invoke database table change callback
    if ti.onChange then
        SafeCall(dbi, ti.onChange, key, rowData)
    end

    -- Invoke database table subscribers
    for callback in pairs(ti.subscribers) do
        SafeCall(dbi, callback, key, rowData)
    end
end

--- Export the database state to a compact format.
--- If a table has a schema, fields are exported in alphabetical order without names.
--- If no schema is defined, all fields are exported in arbitrary order with names.
--- Empty tables are omitted from the exported output.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @return LibP2PDB.DBState? databaseState The exported database state in compact format.
function Private:ExportDatabase(dbi)
    -- Export each table
    local tableStateMap = {} --- @type LibP2PDB.TableStateMap
    for tableName, ti in pairs(dbi.tables) do
        local rowStateMap = self:ExportTable(ti)
        if rowStateMap then
            tableStateMap[tableName] = rowStateMap
        end
    end

    -- Return nil if no tables to export
    if IsEmptyTable(tableStateMap) then
        return nil
    end

    -- Export the database state
    return { dbi.version, dbi.clock, tableStateMap } --- @type LibP2PDB.DBState
end

--- Export a single table to compact format.
--- If the table has a schema, fields are exported in alphabetical order without names.
--- If no schema is defined, all fields are exported in arbitrary order with names.
--- @param ti LibP2PDB.TableInstance Table instance to export.
--- @return LibP2PDB.RowStateMap? rowStateMap The exported row state map, or nil if no rows to export.
function Private:ExportTable(ti)
    -- Export each row
    local rowStateMap = {} --- @type LibP2PDB.RowStateMap
    for key, row in pairs(ti.rows) do
        rowStateMap[key] = self:ExportRow(row, ti.schemaSorted)
    end

    -- Return nil if no rows to export
    if IsEmptyTable(rowStateMap) then
        return nil
    end

    -- Export the row state map
    return rowStateMap
end

--- Export a single row to compact format.
--- If a schema is provided, fields are exported in alphabetical order without names.
--- If no schema is defined, all fields are exported in arbitrary order with names.
--- @param row LibP2PDB.TableRow Row to export.
--- @param schemaSorted LibP2PDB.TableSchemaSorted? Sorted schema for the table (if any).
--- @return LibP2PDB.RowState rowState The exported row state.
function Private:ExportRow(row, schemaSorted)
    -- Export each row's data
    local rowDataState = nil
    local rowData = row.data
    if rowData then
        rowDataState = {} --- @cast rowDataState LibP2PDB.RowDataState
        local rowDataIndex = 1
        if schemaSorted then
            -- Schema defined: export field values in schema sorted order without names
            --- @cast rowDataState [LibP2PDB.RowDataValue]
            for _, fieldData in ipairs(schemaSorted) do
                local fieldKey = fieldData[1]
                local fieldValue = rowData and rowData[fieldKey] or nil
                if fieldValue == nil then
                    fieldValue = NIL_MARKER
                end
                rowDataState[rowDataIndex] = fieldValue
                rowDataIndex = rowDataIndex + 1
            end
        else
            -- No schema: export field key and value pairs in arbitrary order
            --- @cast rowDataState LibP2PDB.RowData
            for k, v in pairs(rowData or {}) do
                rowDataState[k] = v
            end
        end
    else
        rowDataState = NIL_MARKER
    end

    -- Export the row state
    return { --- @type LibP2PDB.RowState
        rowDataState,
        row.version.clock,
        row.version.peer,
        row.version.tombstone and true or nil
    }
end

--- @class LibP2PDB.ImportContext
--- @field db LibP2PDB.DBHandle Database handle.
--- @field dbi LibP2PDB.DBInstance Database instance.
--- @field tableName LibP2PDB.TableName? Name of the table if applicable.
--- @field ti LibP2PDB.TableInstance? Table instance if applicable.
--- @field key LibP2PDB.TableKey? Primary key of the row if applicable.
--- @field rowData LibP2PDB.RowData? Data of the row if applicable.
--- @field rowVersion LibP2PDB.RowVersion? Version of the row if applicable.

--- Import the database state from a compact format.
--- Merges the imported state with existing data based on version metadata.
--- Validates incoming data against table definitions, skipping invalid entries.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param state LibP2PDB.DBState The database state to import.
--- @param thread thread? Optional coroutine thread for yielding during long imports.
--- @param maxTime number? Optional maximum time in seconds to spend importing before yielding.
--- @return boolean success Returns true on success, false otherwise.
function Private:ImportDatabase(dbi, state, thread, maxTime)
    -- Validate database state format
    if not IsNonEmptyTable(state) then
        ReportError(dbi, "invalid database state format")
        return false
    end

    -- Validate database state version
    local dbVersion = state[1] --- @type LibP2PDB.DBVersion
    if not IsInteger(dbVersion, 1) then
        ReportError(dbi, "invalid database version in state")
        return false
    end

    -- Validate database state clock
    local dbClock = state[2] --- @type LibP2PDB.Clock
    if not IsInteger(dbClock, 0) then
        ReportError(dbi, "invalid database clock in state")
        return false
    end

    -- Validate database tables
    local tableStateMap = state[3] --- @type LibP2PDB.TableStateMap
    if not IsTable(tableStateMap) then
        ReportError(dbi, "invalid database tables in state")
        return false
    end

    -- If migration is needed, import into a temporary migration database first
    local migrationDB = nil  --- @type LibP2PDB.DBHandle
    local migrationDBI = nil --- @type LibP2PDB.DBInstance
    if dbVersion ~= dbi.version and dbi.onMigrateDB then
        migrationDB = {}
        ---@diagnostic disable-next-line: missing-fields
        migrationDBI = {
            version = dbVersion,
            clock = dbClock,
            tables = {},
            onError = dbi.onError,
        }
        self.databases[migrationDB] = migrationDBI

        -- Give the user a chance to set up the migration database tables
        local targetCtx = { --- @type LibP2PDB.MigrationContext
            db = priv.prefixes[dbi.prefix],
            version = dbi.version,
        }
        local sourceCtx = { --- @type LibP2PDB.MigrationContext
            db = migrationDB,
            version = dbVersion,
        }
        local success = SafeCall(dbi, dbi.onMigrateDB, targetCtx, sourceCtx)
        if not success then
            ReportError(dbi, "database migration failed")
            return false
        end
    end

    -- Import each table (skipping invalid table entries)
    for tableName, rowStateMap in pairs(tableStateMap or {}) do
        self:ImportTable(migrationDBI or dbi, dbClock, tableName, rowStateMap, thread, maxTime)
    end

    -- If migration is needed, migrate each table from the migration database
    if dbVersion ~= dbi.version and migrationDB and migrationDBI then
        local target = { --- @type LibP2PDB.ImportContext
            db = priv.prefixes[dbi.prefix],
            dbi = dbi,
        }
        local source = { --- @type LibP2PDB.ImportContext
            db = migrationDB,
            dbi = migrationDBI,
        }
        for tableName, ti in pairs(source.dbi.tables) do
            source.tableName = tableName
            source.ti = ti
            self:MigrateTable(target, source)
        end
    end

    return true
end

--- Import a single table from the table state.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param dbClock LibP2PDB.Clock Incoming database clock from the state.
--- @param tableName LibP2PDB.TableName Name of the table.
--- @param rowStateMap LibP2PDB.RowStateMap Row state map to import.
--- @param thread thread? Optional coroutine thread for yielding during long imports.
--- @param maxTime number? Optional maximum time in seconds to spend importing before yielding.
function Private:ImportTable(dbi, dbClock, tableName, rowStateMap, thread, maxTime)
    -- Validate table state format
    if not IsNonEmptyTable(rowStateMap) then
        ReportError(dbi, "invalid table state format")
        return
    end

    -- Check if table is defined in the database
    local ti = dbi.tables[tableName]
    if not ti then
        ReportError(dbi, "table '%s' is not defined in the database", tableName)
        return
    end

    -- Import each row (skipping invalid row entries)
    local startTime = GetTimePreciseSec()
    for key, rowState in pairs(rowStateMap or {}) do
        self:ImportRow(dbi, dbClock, tableName, ti, key, rowState)
        if thread then
            local now = GetTimePreciseSec()
            if now - startTime >= maxTime then
                startTime = now
                coroutine.yield()
            end
        end
    end
end

--- Import a single row from the row entry.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param dbClock LibP2PDB.Clock Incoming database clock from the state.
--- @param tableName LibP2PDB.TableName Name of the table.
--- @param ti LibP2PDB.TableInstance Table instance.
--- @param key LibP2PDB.TableKey Primary key value for the row.
--- @param rowState LibP2PDB.RowState Row state to import.
function Private:ImportRow(dbi, dbClock, tableName, ti, key, rowState)
    -- Validate row state format
    if not IsNonEmptyTable(rowState) then
        ReportError(dbi, "invalid row state format for table '%s'", tableName)
        return
    end

    -- Check key type matches table definition
    if type(key) ~= ti.keyType then
        ReportError(dbi, "expected key of type '%s' for table '%s', but was '%s'", ti.keyType, tableName, type(key))
        return
    end

    -- Validate row data (skipped for tombstone rows)
    local incomingData = rowState[1]
    if not IsTableOrNil(incomingData) and incomingData ~= NIL_MARKER then
        ReportError(dbi, "invalid data in row state for key '%s' in table '%s'", tostring(key), tableName)
        return
    end

    -- Validate version clock
    local incomingVersionClock = rowState[2]
    if not IsInteger(incomingVersionClock, 0) then
        ReportError(dbi, "invalid clock in row version state for key '%s' in table '%s'", tostring(key), tableName)
        return
    end

    -- Validate version peer
    local incomingVersionPeer = rowState[3]
    if not IsNonEmptyString(incomingVersionPeer) then
        ReportError(dbi, "invalid peer in row version state for key '%s' in table '%s'", tostring(key), tableName)
        return
    end

    -- Validate tombstone flag
    local incomingVersionTombstone = rowState[4]
    if not IsBooleanOrNil(incomingVersionTombstone) then
        ReportError(dbi, "invalid tombstone flag in row version state for key '%s' in table '%s'", tostring(key), tableName)
        return
    end

    -- Prepare the imported row version
    --- @type LibP2PDB.RowVersion
    local importedVersion = {
        clock = incomingVersionClock,
        peer = incomingVersionPeer,
        tombstone = incomingVersionTombstone and true or nil,
    }

    -- Merge the incoming row
    if incomingVersionTombstone then
        -- Merge the tombstone row (no data)
        SafeCall(dbi, self.MergeKey, self, dbi, dbClock, tableName, ti, key, nil, importedVersion)
    else
        -- Import the row data
        local importedRowData = self:ImportRowData(dbi, ti.schemaSorted, incomingData)
        if importedRowData then
            -- Merge the row data
            SafeCall(dbi, self.MergeKey, self, dbi, dbClock, tableName, ti, key, importedRowData, importedVersion)
        end
    end
end

--- Import row data from the row data state.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param schemaSorted LibP2PDB.TableSchemaSorted? Sorted schema for the table (if any).
--- @param rowDataState LibP2PDB.RowDataState Row data state to import.
--- @return LibP2PDB.RowData? importedRowData The imported row data, or nil on error.
function Private:ImportRowData(dbi, schemaSorted, rowDataState)
    -- Validate row data state format
    if not IsTableOrNil(rowDataState) then
        ReportError(dbi, "invalid row data state format")
        return nil
    end

    -- Reconstruct row data
    --- @type LibP2PDB.RowData
    local importedRowData = {}
    if schemaSorted then
        -- Schema defined: reconstruct data from ordered array
        --- @cast rowDataState [LibP2PDB.RowDataValue]
        if #rowDataState ~= #schemaSorted then
            ReportError(dbi, "row data state length does not match schema length")
            return nil
        end
        for i, fieldData in ipairs(schemaSorted) do
            local fieldKey = fieldData[1]
            local fieldValue = rowDataState[i]
            if fieldValue == NIL_MARKER then
                fieldValue = nil
            end
            importedRowData[fieldKey] = fieldValue
        end
    else
        -- No schema: copy all primitive fields with string or number keys
        --- @cast rowDataState LibP2PDB.RowData
        for k, v in pairs(rowDataState or {}) do
            if (IsString(k) or IsNumber(k)) and IsPrimitive(v) then
                importedRowData[k] = v
            end
        end
    end

    -- Return row data
    return importedRowData
end

--- Migrate a single table's data using the migration callback.
--- @param target LibP2PDB.ImportContext Target import context.
--- @param source LibP2PDB.ImportContext Source import context.
function Private:MigrateTable(target, source)
    local tableName = source.tableName
    if target.dbi.onMigrateTable then
        -- Migrate table using the callback
        local targetCtx = { --- @type LibP2PDB.MigrationContext
            db = target.db,
            version = target.dbi.version,
        }
        local sourceCtx = { --- @type LibP2PDB.MigrationContext
            db = source.db,
            version = source.dbi.version,
            tableName = source.tableName,
        }
        local success, newTableName = SafeCall(target.dbi, target.dbi.onMigrateTable, targetCtx, sourceCtx)
        if not success then
            ReportError(target.dbi, "table migration failed for table '%s'", source.tableName)
            return
        end
        if newTableName then
            tableName = newTableName
        end
    end

    -- Validate table name
    if not IsNonEmptyString(tableName) then
        ReportError(target.dbi, "migrated table name must be a non-empty string for table '%s'", source.tableName)
        return
    end

    -- Check target table exists in target database
    local ti = target.dbi.tables[tableName]
    if not ti then
        ReportError(target.dbi, "migrated table '%s' does not exist in target database", tableName)
        return
    end
    target.tableName = tableName
    target.ti = ti

    -- Migrate each row in the table
    for key, row in pairs(source.ti.rows) do
        source.key = key
        source.rowData = row.data
        source.rowVersion = row.version
        self:MigrateRow(target, source)
    end
end

--- Migrate a single row's data using the migration callback.
--- @param target LibP2PDB.ImportContext Target import context.
--- @param source LibP2PDB.ImportContext Source import context.
function Private:MigrateRow(target, source)
    local targetKey = source.key
    local targetRowData = source.rowData
    if target.dbi.onMigrateRow then
        -- Migrate row data using the callback
        local targetCtx = { --- @type LibP2PDB.MigrationContext
            db = target.db,
            version = target.dbi.version,
            tableName = target.tableName,
        }
        local sourceCtx = { --- @type LibP2PDB.MigrationContext
            db = source.db,
            version = source.dbi.version,
            tableName = source.tableName,
            key = source.key,
            data = ShallowCopy(source.rowData),
        }
        local success, newKey, newRowData = SafeCall(target.dbi, target.dbi.onMigrateRow, targetCtx, sourceCtx)
        if not success then
            ReportError(target.dbi, "row data migration failed for key '%s' in table '%s'", tostring(source.key), source.tableName)
            return
        end
        if newKey then
            targetKey = newKey
        end
        if newRowData then
            targetRowData = newRowData
        end
    end

    -- Validate key
    if not IsNonEmptyString(targetKey) and not IsNumber(targetKey) then
        ReportError(target.dbi, "migrated key must be a non-empty string or number for key '%s' in table '%s'", tostring(source.key), source.tableName)
        return
    end

    -- Check key type matches table definition
    --- @cast targetKey LibP2PDB.TableKey
    if type(targetKey) ~= target.ti.keyType then
        ReportError(target.dbi, "expected migrated key of type '%s' for table '%s', but was '%s'", target.ti.keyType, target.tableName, type(targetKey))
        return
    end

    -- Validate row data
    if not IsTableOrNil(targetRowData) then
        ReportError(target.dbi, "migrated row data must be a table or nil for key '%s' in table '%s'", tostring(source.key), source.tableName)
        return
    end

    -- Prepare the migrated row data
    local success, rowData = SafeCall(target.dbi, Private.PrepareRowData, self, target.tableName, target.ti, targetRowData)
    if success then
        -- Merge the migrated row
        self:MergeKey(target.dbi, source.dbi.clock, target.tableName, target.ti, targetKey, rowData, source.rowVersion)
    end
end

--- Compare two version for ordering.
--- Returns true if version a precedes version b (is older), false otherwise.
--- @param a LibP2PDB.RowVersion? First version metadata, or nil.
--- @param b LibP2PDB.RowVersion? Second version metadata, or nil.
--- @return boolean result True if a is strictly less than (precedes) b, false otherwise (if the two are equivalent or b precedes a)
function Private:CompareVersion(a, b)
    if a == nil and b == nil then
        return false
    elseif a == nil then
        return true
    elseif b == nil then
        return false
    end
    if a.clock < b.clock then
        return true
    elseif a.clock > b.clock then
        return false
    else
        return a.peer < b.peer
    end
end

--- Get neighbors for the local peer.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @return table<LibP2PDB.PeerID, boolean> neighbors Hash set of active neighbor peer IDs.
function Private:GetNeighbors(dbi)
    local numPeers = #dbi.peersSorted
    if numPeers == 0 then
        return {}
    end

    -- Compute our virtual index, zero-based
    local peerIndex = IndexOf(dbi.peersSorted, self.peerId)
    if not peerIndex then
        return {}
    end

    -- Collect neighbors
    local neighbors = {} --- @type table<LibP2PDB.PeerID, boolean>

    -- Ring successor (guaranteed full coverage)
    local successorIndex = (peerIndex % numPeers) + 1
    if successorIndex ~= peerIndex then
        neighbors[dbi.peersSorted[successorIndex]] = true
    end

    -- Ring predecessor (guaranteed full coverage)
    local predecessorIndex = ((peerIndex - 2 + numPeers) % numPeers) + 1
    if predecessorIndex ~= peerIndex then
        neighbors[dbi.peersSorted[predecessorIndex]] = true
    end

    -- Multiplicative skip neighbors (fast propagation)
    local multiplier = FindCoprimeMultiplier(numPeers)
    if multiplier then
        local skipIndex = (((peerIndex - 1) * multiplier) % numPeers) + 1
        if skipIndex ~= peerIndex then
            neighbors[dbi.peersSorted[skipIndex]] = true
        end
    end

    return neighbors
end

--- Send a message to a specific target peer.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param data any The message data to send.
--- @param channel string The channel to send the message on.
--- @param target string? Target peer name, only required for WHISPER channel.
--- @param priority LibP2PDB.CommPriority The priority of the message.
function Private:Send(dbi, data, channel, target, priority)
    local serialized = dbi.serializer:Serialize(data)
    if not serialized then
        Error("failed to serialize data for prefix '%s'", tostring(dbi.prefix))
        return
    end

    local compressed = dbi.compressor:Compress(serialized)
    if not compressed then
        Error("failed to compress data for prefix '%s'", tostring(dbi.prefix))
        return
    end

    local encoded = dbi.encoder:EncodeForChannel(compressed)
    if not encoded then
        Error("failed to encode data for prefix '%s'", tostring(dbi.prefix))
        return
    end

    if target then
        Spam("sending %d bytes on prefix '%s' channel '%s' target '%s'", #encoded, tostring(dbi.prefix), tostring(channel), tostring(target))
    else
        Spam("sending %d bytes on prefix '%s' channel '%s'", #encoded, tostring(dbi.prefix), tostring(channel))
    end
    if DEBUG and VERBOSITY >= 5 then
        DevTools_Dump(data)
    end

    --- @cast priority "ALERT"|"BULK"|"NORMAL"
    AceComm.SendCommMessage(self, dbi.prefix, encoded, channel, target, priority)
end

--- Broadcast a message to all peers on multiple channels.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param data any The message data to broadcast.
--- @param channels string[]? Optional list of additional channels to broadcast on.
--- @param priority LibP2PDB.CommPriority The priority of the message.
function Private:Broadcast(dbi, data, channels, priority)
    local serialized = dbi.serializer:Serialize(data)
    if not serialized then
        Error("failed to serialize message for prefix '%s'", tostring(dbi.prefix))
        return
    end

    local compressed = dbi.compressor:Compress(serialized)
    if not compressed then
        Error("failed to compress message for prefix '%s'", tostring(dbi.prefix))
        return
    end

    local encoded = dbi.encoder:EncodeForChannel(compressed)
    if not encoded then
        Error("failed to encode message for prefix '%s'", tostring(dbi.prefix))
        return
    end

    Spam("broadcasting %d bytes on prefix '%s'", #encoded, tostring(dbi.prefix))
    if DEBUG and VERBOSITY >= 5 then
        DevTools_Dump(data)
    end

    if IsInGuild() then
        --- @cast priority "ALERT"|"BULK"|"NORMAL"
        AceComm.SendCommMessage(self, dbi.prefix, encoded, "GUILD", nil, priority)
    end

    if IsInRaid() and not InActiveBattlefield()then
        --- @cast priority "ALERT"|"BULK"|"NORMAL"
        AceComm.SendCommMessage(self, dbi.prefix, encoded, "RAID", nil, priority)
    elseif IsInGroup() then
        --- @cast priority "ALERT"|"BULK"|"NORMAL"
        AceComm.SendCommMessage(self, dbi.prefix, encoded, "PARTY", nil, priority)
    end

    if not IsInInstance() then
        --- @cast priority "ALERT"|"BULK"|"NORMAL"
        AceComm.SendCommMessage(self, dbi.prefix, encoded, "YELL", nil, priority)
    end

    for _, channel in ipairs(channels or {}) do
        --- @cast priority "ALERT"|"BULK"|"NORMAL"
        AceComm.SendCommMessage(self, dbi.prefix, encoded, channel, nil, priority)
    end

    -- local numFriends = C_FriendList.GetNumFriends()
    -- for i = 1, numFriends do
    --     local info = C_FriendList.GetFriendInfoByIndex(i)
    --     if info and info.connected then
    --         AceComm.SendCommMessage(self, dbi.prefix, encoded, "WHISPER", info.name, priority)
    --     end
    -- end
end

--- @class LibP2PDB.Message Received communication message.
--- @field type LibP2PDB.CommMessageType Received message type.
--- @field peer LibP2PDB.PeerID Sender peer ID.
--- @field data any Message data.
--- @field dbi LibP2PDB.DBInstance Database instance the message is associated with.
--- @field channel string The channel the message was received on.
--- @field sender string The sender name of the message.

--- Handler for received communication messages.
--- @param prefix string The communication prefix.
--- @param encoded string The encoded message data.
--- @param channel string The channel the message was received on.
--- @param sender string The sender of the message.
function Private:OnCommReceived(prefix, encoded, channel, sender)
    -- Ignore messages from self
    if sender == self.playerName then
        return
    end

    -- Get the database instance for this prefix
    local db = self.prefixes[prefix]
    if not db then
        Error("received message for unknown prefix '%s' from channel '%s' sender '%s'", tostring(prefix), tostring(channel), tostring(sender))
        return
    end

    local dbi = self.databases[db]
    if not dbi then
        Error("received message for unregistered database prefix '%s' from channel '%s' sender '%s'", tostring(prefix), tostring(channel), tostring(sender))
        return
    end

    -- Deserialize message
    local compressed = dbi.encoder:DecodeFromChannel(encoded)
    if not compressed then
        Error("failed to decode message from prefix '%s' channel '%s' sender '%s'", tostring(prefix), tostring(channel), tostring(sender))
        return
    end

    local serialized = dbi.compressor:Decompress(compressed)
    if not serialized then
        Error("failed to decompress message from prefix '%s' channel '%s' sender '%s'", tostring(prefix), tostring(channel), tostring(sender))
        return
    end

    local obj = dbi.serializer:Deserialize(serialized)
    if not obj then
        Error("failed to deserialize message from prefix '%s' channel '%s' sender '%s': %s", tostring(prefix), tostring(channel), tostring(sender), Dump(obj))
        return
    end

    -- Validate message structure
    if not IsTable(obj) then
        Error("received invalid message structure from '%s' on channel '%s'", tostring(sender), tostring(channel))
        return
    end

    if not IsInteger(obj.type) then
        Error("received message with missing or invalid type from '%s' on channel '%s'", tostring(sender), tostring(channel))
        return
    end

    if not IsNonEmptyString(obj.peer) then
        Error("received message with missing or invalid peer from '%s' on channel '%s'", tostring(sender), tostring(channel))
        return
    end

    -- Build message object
    local message = { --- @type LibP2PDB.Message
        type = obj.type,
        peer = obj.peer,
        data = obj.data,
        dbi = dbi,
        channel = channel,
        sender = sender,
    }

    -- Get or create bucket
    local bucket = dbi.buckets[message.type]
    if not bucket then
        bucket = {}
        dbi.buckets[message.type] = bucket
    end

    -- If we already have a timer running for this peer, ignore it
    if bucket[message.peer] then
        return
    end

    -- Create a timer to process this message after 200 milliseconds
    bucket[message.peer] = C_Timer.NewTimer(0.2, function()
        -- Process the message
        self:DispatchMessage(message)

        -- Clean up
        bucket[message.peer] = nil

        -- Clean up bucket if empty
        if not next(bucket) then
            dbi.buckets[message.type] = nil
        end
    end)
end

--- Dispatch a received message to the appropriate handler.
--- @param message LibP2PDB.Message
function Private:DispatchMessage(message)
    if message.type == CommMessageType.PeerDiscoveryRequest then
        self:PeerDiscoveryRequestHandler(message)
    elseif message.type == CommMessageType.PeerDiscoveryResponse then
        self:PeerDiscoveryResponseHandler(message)
    elseif message.type == CommMessageType.DigestRequest then
        self:DigestRequestHandler(message)
    elseif message.type == CommMessageType.DigestResponse then
        self:DigestResponseHandler(message)
    elseif message.type == CommMessageType.RowsRequest then
        self:RowsRequestHandler(message)
    elseif message.type == CommMessageType.RowsResponse then
        self:RowsResponseHandler(message)
    else
        Error("received unknown message type %d from '%s' on channel '%s'", message.type, message.sender, message.channel)
    end
end

--- Handler for peer discovery request messages.
--- Reply to the sender with our peer ID and clock.
--- @param message LibP2PDB.Message
function Private:PeerDiscoveryRequestHandler(message)
    local dbi = message.dbi
    local sender = message.sender
    Spam("received peer discovery request from '%s'", tostring(sender))

    -- Record the peer
    local peerID = message.peer
    local peerClock = message.data --- @type LibP2PDB.Clock
    self:RecordPeer(dbi, peerID, sender, peerClock)

    -- Send peer discovery response
    Spam("sending peer discovery response to '%s'", tostring(sender))
    local obj = {
        type = CommMessageType.PeerDiscoveryResponse,
        peer = self.peerId,
        data = dbi.clock, --- @type LibP2PDB.Clock
    }
    self:Send(dbi, obj, "WHISPER", sender, CommPriority.Low)
end

--- Handler for peer discovery response messages.
--- Record peer information used to find neighbors for gossip synchronization.
--- @param message LibP2PDB.Message
function Private:PeerDiscoveryResponseHandler(message)
    local dbi = message.dbi
    local sender = message.sender
    Spam("received peer discovery response from '%s'", tostring(sender))

    -- Update last discovery time
    local now = GetTime()
    if dbi.onDiscoveryComplete then
        dbi.lastDiscoveryResponseTime = now
    end

    -- Record the peer
    local peerID = message.peer
    local clock = message.data --- @type LibP2PDB.Clock
    self:RecordPeer(dbi, peerID, sender, clock)
end

--- Handler for digest request messages.
--- Reply to the sender with digests for each table.
--- Data will be sent using the LibP2PDB.DBDigest format.
--- @param message LibP2PDB.Message
function Private:DigestRequestHandler(message)
    local dbi = message.dbi
    local sender = message.sender
    Spam("received digest request from '%s'", sender)

    -- Build digest for each table
    local databaseDigest = {} --- @type LibP2PDB.DBDigest
    for tableName, ti in pairs(dbi.tables) do
        if ti.rowCount > 0 then
            local filter = dbi.filter.New(ti.rowCount, ti.seed)
            ti.seed = ti.seed + 1 -- increment seed for next use
            for key in pairs(ti.rows) do
                filter:Insert(key)
            end
            databaseDigest[tableName] = {
                filter = filter:Export(),
                summary = ti.summary:Export(),
            }
        else
            databaseDigest[tableName] = {
                NIL_MARKER,
                NIL_MARKER,
            }
        end
    end

    -- Return if there are no tables to include in the digest
    if IsEmptyTable(databaseDigest) then
        Spam("no tables to include in digest response to '%s'", sender)
        return
    end

    -- Send digest response
    Spam("sending digest response to '%s'", sender)
    local obj = {
        type = CommMessageType.DigestResponse,
        peer = self.peerId,
        data = databaseDigest,
    }
    self:Send(dbi, obj, "WHISPER", sender, CommPriority.Normal)
end

--- Handler for digest response messages.
--- Reply to the sender with rows they are missing and request outdated rows.
--- Data will be sent using the LibP2PDB.DBState and LibP2PDB.DBRequest formats.
--- @param message LibP2PDB.Message
function Private:DigestResponseHandler(message)
    local dbi = message.dbi
    local sender = message.sender
    Spam("received digest response from '%s'", sender)

    -- Iterate each table in the digest
    local databaseDigest = message.data --- @type LibP2PDB.DBDigest
    local tableStateMap = {}            --- @type LibP2PDB.TableStateMap
    local databaseRequest = {}          --- @type LibP2PDB.DBRequest
    for tableName, tableDigest in pairs(databaseDigest or {}) do
        -- Check if table is defined in the database
        local ti = dbi.tables[tableName]
        if ti then
            -- Reconstruct the filter
            local filter = nil
            if tableDigest.filter and tableDigest.filter ~= NIL_MARKER then
                filter = dbi.filter.Import(tableDigest.filter)
            end

            -- Reconstruct the summary
            local summary = nil
            if tableDigest.summary and tableDigest.summary ~= NIL_MARKER then
                summary = LibBucketedHashSet.Import(tableDigest.summary)

                -- Resize our summary if needed, to match theirs
                if summary.numBuckets > ti.summary.numBuckets then
                    self:ResizeTableSummary(ti, summary.numBuckets)
                elseif summary.numBuckets < ti.summary.numBuckets then
                    summary = nil -- Their summary is smaller than ours, so we cannot compare properly
                end
            end

            -- Find rows they are missing, and rows we have that differs from their summary
            local rowStateMap = {}  --- @type LibP2PDB.RowStateMap
            local tableRequest = {} --- @type LibP2PDB.TableRequest
            for key, row in pairs(ti.rows) do
                -- Check if they are missing our row
                if not filter or not filter:Contains(key) then
                    -- They are missing our row, send it to them
                    rowStateMap[key] = self:ExportRow(row, ti.schemaSorted)
                elseif summary then -- Check if our row differs from their summary
                    local bucketIndex = ti.summary.keyIndex[key]
                    if summary.buckets[bucketIndex] ~= ti.summary.buckets[bucketIndex] then
                        -- Their summary differs from ours for this key, request the row
                        tableRequest[key] = row.version.clock
                    end
                end
            end

            -- Send the table only if there are any rows to send
            if IsNonEmptyTable(rowStateMap) then
                tableStateMap[tableName] = rowStateMap
            end

            -- Request the table only if there are any rows to request
            if IsNonEmptyTable(tableRequest) then
                databaseRequest[tableName] = tableRequest
            end
        else
            ReportError(dbi, "table '%s' in digest response from '%s' is not defined in the database", tableName, tostring(sender))
        end
    end

    -- Send rows they are missing
    if IsNonEmptyTable(tableStateMap) then
        Spam("sending missing rows response to '%s'", sender)
        local obj = {
            type = CommMessageType.RowsResponse,
            peer = self.peerId,
            data = { dbi.version, dbi.clock, tableStateMap }, --- @type LibP2PDB.DBState
        }
        self:Send(dbi, obj, "WHISPER", sender, CommPriority.Normal)
    end

    -- Request rows that differs from their summary
    if IsNonEmptyTable(databaseRequest) then
        Spam("sending outdated rows request to '%s'", sender)
        local obj = {
            type = CommMessageType.RowsRequest,
            peer = self.peerId,
            data = databaseRequest, --- @type LibP2PDB.DBRequest
        }
        self:Send(dbi, obj, "WHISPER", sender, CommPriority.Normal)
    end
end

--- Handler for rows request messages.
--- Reply to the sender with the requested rows.
--- Data will be sent using the LibP2PDB.DBState format.
--- @param message LibP2PDB.Message
function Private:RowsRequestHandler(message)
    local dbi = message.dbi
    local sender = message.sender
    local peerID = message.peer
    Spam("received rows request from '%s'", tostring(sender))

    -- Export requested rows for each table
    local databaseRequest = message.data                           --- @type LibP2PDB.DBRequest
    local tableStateMap = {}                                       --- @type LibP2PDB.TableStateMap
    for tableName, tableRequest in pairs(databaseRequest or {}) do --- @cast tableRequest LibP2PDB.TableRequest
        local ti = dbi.tables[tableName]
        if ti then
            -- Export each requested row
            local rowStateMap = {} --- @type LibP2PDB.RowStateMap
            for key, clock in pairs(tableRequest or {}) do
                local row = ti.rows[key]
                if row and self:CompareVersion({ clock = clock, peer = peerID }, row.version) then
                    rowStateMap[key] = self:ExportRow(row, ti.schemaSorted)
                end
            end

            -- Include the table only if there are any rows to send
            if IsNonEmptyTable(rowStateMap) then
                tableStateMap[tableName] = rowStateMap
            end
        else
            ReportError(dbi, "table '%s' in rows request from '%s' is not defined in the database", tableName, tostring(sender))
        end
    end

    -- Return if there are no rows to send
    if IsEmptyTable(tableStateMap) then
        Spam("no rows to send to '%s'", tostring(sender))
        return
    end

    -- Send rows response
    Spam("sending rows response to '%s'", tostring(sender))
    local obj = {
        type = CommMessageType.RowsResponse,
        peer = self.peerId,
        data = { dbi.version, dbi.clock, tableStateMap }, --- @type LibP2PDB.DBState
    }
    self:Send(dbi, obj, "WHISPER", sender, CommPriority.Normal)
end

--- Handler for rows response messages.
--- Import the received rows into the database.
--- Data is expected to be in the LibP2PDB.DBState format.
--- @param message LibP2PDB.Message
function Private:RowsResponseHandler(message)
    local dbi = message.dbi
    local sender = message.sender
    Spam("received rows response from '%s'", tostring(sender))

    -- Import the database state we received
    local databaseState = message.data --- @type LibP2PDB.DBState
    self:ImportDatabase(dbi, databaseState)
end

--- OnUpdate handler called periodically to handle time-based events.
--- @param dbi LibP2PDB.DBInstance Database instance.
function Private:OnUpdate(dbi)
    if not dbi.discoveryStartTime then
        return
    end

    -- Handle peer discovery timeout
    local now = GetTime()
    local sinceStart = now - dbi.discoveryStartTime
    local sinceLast = now - dbi.lastDiscoveryResponseTime

    -- Discovery quiet period or max time reached
    if sinceLast >= dbi.discoveryQuietPeriod or sinceStart >= dbi.discoveryMaxTime then
        dbi.discoveryStartTime = nil
        if dbi.onDiscoveryComplete then
            securecallfunction(dbi.onDiscoveryComplete)
        end
    end
end

--- Record information about a new or existing peer.
--- @param dbi LibP2PDB.DBInstance Database instance.
--- @param peerID LibP2PDB.PeerID Peer ID.
--- @param peerName string Peer name.
--- @param peerClock LibP2PDB.Clock Peer clock.
function Private:RecordPeer(dbi, peerID, peerName, peerClock)
    -- Lookup existing peer info
    local now = GetTime()
    local peerInfo = dbi.peers[peerID]

    -- Update existing peer
    if peerInfo then
        peerInfo.clock = peerClock
        peerInfo.lastSeen = now
    else -- Insert new peer
        peerInfo = {
            name = peerName,
            clock = peerClock,
            lastSeen = now,
        }
        dbi.peers[peerID] = peerInfo

        -- Insert into sorted peers array
        local index = LowerBound(dbi.peersSorted, peerID)
        --assert(index >= 1 and index <= #dbi.peersSorted + 1, "LowerBound returned invalid index")
        --assert(dbi.peersSorted[index] ~= peerID, "peerID already exists in peersSorted")
        tinsert(dbi.peersSorted, index, peerID)
    end
end

--- Prune peers that have timed out from the peer and neighbors list.
--- @param dbi LibP2PDB.DBInstance Database instance.
function Private:PruneTimedOutPeers(dbi)
    local now = GetTime()
    local timedOutPeers = {}
    for peerID, peerInfo in pairs(dbi.peers) do
        if peerID ~= self.peerId then -- never remove self
            if now - peerInfo.lastSeen >= dbi.peerTimeout then
                tinsert(timedOutPeers, peerID)
            end
        end
    end
    for _, peerID in ipairs(timedOutPeers) do
        dbi.peers[peerID] = nil
        local index = IndexOf(dbi.peersSorted, peerID)
        if index then
            tremove(dbi.peersSorted, index)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Testing
------------------------------------------------------------------------------------------------------------------------

--[[ Uncomment to enable testing

local Assert = {
    IsNil = function(value, msg) assert(value == nil, msg or "value is not nil") end,
    IsNotNil = function(value, msg) assert(value ~= nil, msg or "value is nil") end,
    IsTrue = function(value, msg) assert(value == true, msg or "value is not true") end,
    IsFalse = function(value, msg) assert(value == false, msg or "value is not false") end,
    IsNumber = function(value, msg) assert(IsNumber(value), msg or "value is not a number") end,
    IsInteger = function(value, msg) assert(IsInteger(value), msg or "value is not an integer") end,
    IsString = function(value, msg) assert(IsString(value), msg or "value is not a string") end,
    IsEmptyString = function(value, msg) assert(IsEmptyString(value), msg or "value is not an empty string") end,
    IsNonEmptyString = function(value, msg) assert(IsNonEmptyString(value), msg or "value is not a non-empty string") end,
    IsTable = function(value, msg) assert(IsTable(value), msg or "value is not a table") end,
    IsEmptyTable = function(value, msg) assert(IsEmptyTable(value), msg or "value is not an empty table") end,
    IsNonEmptyTable = function(value, msg) assert(IsNonEmptyTable(value), msg or "value is not a non-empty table") end,
    IsFunction = function(value, msg) assert(IsFunction(value), msg or "value is not a function") end,
    IsInterface = function(value, interface, msg)
        assert(IsTable(value), msg or "value is not a table")
        for _, fnName in ipairs(interface) do
            assert(IsFunction(value[fnName]), msg or format("value is missing function '%s'", tostring(fnName)))
        end
    end,
    AreEqual = function(actual, expected, msg) assert(DeepEqual(actual, expected) == true, msg or format("values are not equal, expected '%s' but got '%s'", Dump(expected), Dump(actual))) end,
    AreNotEqual = function(actual, expected, msg) assert(DeepEqual(actual, expected) == false, msg or format("values are equal, both are '%s'", Dump(actual))) end,
    IsGreaterThan = function(actual, expected, msg) assert(actual > expected, msg or format("value '%s' is not greater than '%s'", tostring(actual), tostring(expected))) end,
    IsGreaterThanOrEqual = function(actual, expected, msg) assert(actual >= expected, msg or format("value '%s' is not greater than or equal to '%s'", tostring(actual), tostring(expected))) end,
    IsLessThan = function(actual, expected, msg) assert(actual < expected, msg or format("value '%s' is not less than '%s'", tostring(actual), tostring(expected))) end,
    IsLessThanOrEqual = function(actual, expected, msg) assert(actual <= expected, msg or format("value '%s' is not less than or equal to '%s'", tostring(actual), tostring(expected))) end,
    Contains = function(haystack, needle, msg)
        if type(haystack) == "string" then
            assert(strfind(haystack, needle, 1, true) ~= nil, msg or format("string does not contain '%s'", tostring(needle)))
        elseif type(haystack) == "table" then
            for _, v in pairs(haystack) do
                if DeepEqual(v, needle) then
                    return
                end
            end
            assert(false, msg or format("table does not contain value '%s'", tostring(needle)))
        else
            assert(false, msg or "first argument must be a string or table")
        end
    end,
    DoesNotContain = function(haystack, needle, msg)
        if type(haystack) == "string" then
            assert(strfind(haystack, needle, 1, true) == nil, msg or format("string contains '%s'", tostring(needle)))
        elseif type(haystack) == "table" then
            for _, v in pairs(haystack) do
                if DeepEqual(v, needle) then
                    assert(false, msg or format("table contains value '%s'", tostring(needle)))
                    return
                end
            end
        else
            assert(false, msg or "first argument must be a string or table")
        end
    end,
    ContainsKey = function(table, key, msg)
        assert(IsTable(table), msg or "first argument is not a table")
        assert(table[key] ~= nil, msg or format("table does not contain key '%s'", tostring(key)))
    end,
    DoesNotContainKey = function(table, key, msg)
        assert(IsTable(table), msg or "first argument is not a table")
        assert(table[key] == nil, msg or format("table contains key '%s'", tostring(key)))
    end,
    Throws = function(fn, msg) assert(pcall(fn) == false, msg or "function did not throw") end,
    DoesNotThrow = function(fn, msg)
        local s, r = pcall(fn)
        assert(s == true, msg or format("function threw an error: %s", tostring(r)))
    end,
    ExpectErrors = function(func, report)
        local originalVerbosity = VERBOSITY
        if not report then
            VERBOSITY = 0
        end
        func()
        if not report then
            VERBOSITY = originalVerbosity
        end
        assert(LAST_ERROR ~= nil, "expected an error but none was reported")
        LAST_ERROR = nil
    end,
}

--- @param index integer Player index.
--- @return table instance New private instance.
local function NewPrivateInstance(index)
    return Private.New(format("Player%d", index), format("Player-%04d-%08X", index % 10000, index))
end

--- Executes a function within the context of a given private instance.
--- @param instance table Private instance.
--- @param func function Function to execute within the private scope.
local function PrivateScope(instance, func)
    local _priv = priv
    priv = instance
    local result = { func() }
    priv = _priv
    return unpack(result)
end

--- Executes a function with a specified verbosity level.
--- @param level integer Verbosity level to set.
--- @param func function Function to execute within the verbosity scope.
local function VerbosityScope(level, func)
    local originalVerbosity = VERBOSITY
    VERBOSITY = level
    local result = { func() }
    VERBOSITY = originalVerbosity
    return unpack(result)
end

local function FormatTime(milliseconds)
    if milliseconds < 1.0 then
        return format("%.2fus", milliseconds * 1000.0)
    elseif milliseconds < 1000.0 then
        return format("%.2fms", milliseconds)
    else
        return format("%.2fs", milliseconds / 1000.0)
    end
end

local function FormatSize(bytes, allowPartialBytes)
    if bytes < 1024 then
        if allowPartialBytes then
            return format("%.2fB", bytes)
        else
            return format("%dB", bytes)
        end
    elseif bytes < (1024 * 1024) then
        return format("%.2fKB", bytes / 1024)
    else
        return format("%.2fMB", bytes / (1024 * 1024))
    end
end

local function GenerateName(i, minLen, maxLen, seedMultiplier, maxSpaces)
    -- Generate a deterministic random name based on index
    -- minLen: minimum length (inclusive)
    -- maxLen: maximum length (inclusive)
    -- seedMultiplier: multiplier for seed generation (different values = different sequences)
    -- maxSpaces: maximum number of spaces to include (0 = no spaces)
    local seed = sin(i * seedMultiplier) * 10000
    local absSeed = seed < 0 and -seed or seed
    local length = minLen + (floor(absSeed) % (maxLen - minLen + 1))

    if maxSpaces == 0 then
        -- No spaces - simple name generation
        local chars = {}
        for j = 1, length do
            if j == 1 then
                chars[j] = strchar(65 + (floor(absSeed / j) % 26)) -- Uppercase A-Z
            else
                chars[j] = strchar(97 + (floor(absSeed / j) % 26)) -- Lowercase a-z
            end
        end
        return table.concat(chars)
    else
        -- Multi-word name generation
        local numWords = 1 + (floor(absSeed / 3) % maxSpaces)                -- 1 to maxSpaces words
        numWords = numWords > (length / 3) and floor(length / 3) or numWords -- At least 3 chars per word
        numWords = numWords < 1 and 1 or numWords

        -- Calculate word lengths
        local words = {}
        local remainingLength = length - (numWords - 1) -- Subtract space count
        for w = 1, numWords do
            local minWordLen = 2
            local maxWordLen = remainingLength - (numWords - w) * minWordLen
            maxWordLen = maxWordLen > 12 and 12 or maxWordLen
            local wordLen = minWordLen + (floor(absSeed / (w * 7)) % (maxWordLen - minWordLen + 1))

            local wordChars = {}
            for c = 1, wordLen do
                local charIndex = (w - 1) * 12 + c
                if c == 1 then
                    wordChars[c] = strchar(65 + (floor(absSeed / charIndex) % 26)) -- Uppercase
                else
                    wordChars[c] = strchar(97 + (floor(absSeed / charIndex) % 26)) -- Lowercase
                end
            end
            words[w] = table.concat(wordChars)
            remainingLength = remainingLength - wordLen
        end

        return table.concat(words, " ")
    end
end

local function GeneratePlayerName(i)
    return GenerateName(i, 2, 12, 12345, 0) -- 2-12 chars, no spaces
end

local function GenerateGuildName(i)
    return GenerateName(i, 2, 24, 54321, 4) -- 2-24 chars, up to 4 spaces
end

local function GenerateRealmName(i)
    return GenerateName(i, 6, 20, 67890, 1) -- 6-20 chars, up to 1 space
end

local function GeneratePlayerGUID(i)
    -- Generate deterministic GUID in format Player-XXXX-YYYYYYYY
    -- XXXX is realm ID (4 hex digits)
    -- YYYYYYYY is player ID (8 hex digits)
    local seed = sin(i * 123.456) * 10000
    local absSeed = seed < 0 and -seed or seed
    local realmId = floor(absSeed * 65535) % 65536                    -- 0x0000 to 0xFFFF
    local playerId = (i * 31337 + floor(absSeed * 1000)) % 4294967296 -- 0x00000000 to 0xFFFFFFFF
    return format("Player-%04X-%08X", realmId, playerId)
end

local function GenerateKey(i)
    return LibP2PDB:GetPeerIdFromGUID(GeneratePlayerGUID(i))
end

local function GenerateData(i)
    return {
        name = GeneratePlayerName(i),
        realm = GenerateRealmName(i % 10),
        classID = (floor(math.abs(sin(i * 11111) * 10000)) % 12) + 1,
        guild = GenerateGuildName(i % 20),
        version = "1.0." .. (floor(math.abs(sin(i * 22222) * 10000)) % 100),
        level = (floor(math.abs(sin(i * 33333) * 10000)) % 60) + 1,
        xpTotal = floor(math.abs(sin(i * 44444) * 10000) % 3379401),
        money = floor(math.abs(sin(i * 55555) * 10000) % 2147483648),
        timePlayed = floor(math.abs(sin(i * 11111) * 10000) * math.abs(sin(i * 22222) * 10000) % 2147483648),
    }
end

--- @diagnostic disable: param-type-mismatch, assign-type-mismatch, missing-fields
local UnitTests = {
    NewDatabase = function()
        do -- check new database creation with minimal description
            Assert.IsNil(LibP2PDB:GetDatabase("LibP2PDBTests1"))
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests1" })
            Assert.IsEmptyTable(db)
            Assert.AreEqual(LibP2PDB:GetDatabase("LibP2PDBTests1"), db)

            -- verify internal database instance
            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.prefix, "LibP2PDBTests1")
            Assert.AreEqual(dbi.version, 1)
            Assert.AreEqual(dbi.clock, 0)
            Assert.IsNil(dbi.channels)
            Assert.AreEqual(dbi.discoveryQuietPeriod, 1.5)
            Assert.AreEqual(dbi.discoveryMaxTime, 3.0)
            Assert.AreEqual(dbi.peerTimeout, 100.0)
            Assert.IsInterface(dbi.filter, { "New", "Insert", "Contains", "Export", "Import" })
            Assert.IsInterface(dbi.serializer, { "Serialize", "Deserialize" })
            Assert.IsInterface(dbi.compressor, { "Compress", "Decompress" })
            Assert.IsInterface(dbi.encoder, { "EncodeForChannel", "DecodeFromChannel", "EncodeForPrint", "DecodeFromPrint" })
            Assert.IsNonEmptyTable(dbi.peers)
            Assert.IsNonEmptyTable(dbi.peersSorted)
            Assert.IsEmptyTable(dbi.buckets)
            Assert.IsEmptyTable(dbi.tables)
            Assert.IsNil(dbi.onError)
            Assert.IsNil(dbi.onMigrateDB)
            Assert.IsNil(dbi.onMigrateTable)
            Assert.IsNil(dbi.onMigrateRow)
            Assert.IsNil(dbi.onChange)
            Assert.IsNil(dbi.onDiscoveryComplete)
            Assert.IsNil(dbi.discoveryStartTime)
            Assert.IsNil(dbi.lastDiscoveryResponseTime)
        end
        do -- check new database creation with full description
            Assert.IsNil(LibP2PDB:GetDatabase("LibP2PDBTests2"))
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBTests2",
                version = 2,
                onError = function(dbi, msg) end,
                onMigrateDB = function(target, source) end,
                onMigrateTable = function(target, source) return "" end,
                onMigrateRow = function(target, source) return 1, {} end,
                serializer = {
                    Serialize = function(self, obj) return obj end,
                    Deserialize = function(self, str) return str end
                },
                filter = (function()
                    local TestFilter = {}
                    TestFilter.New = function(numItems)
                        return setmetatable({ items = {} }, { __index = TestFilter })
                    end
                    TestFilter.Import = function(state)
                        return setmetatable({ items = state or {} }, { __index = TestFilter })
                    end
                    TestFilter.Insert = function(self, key)
                        self.items[tostring(key)] = true
                        return true
                    end
                    TestFilter.Contains = function(self, key)
                        return self.items[tostring(key)] == true
                    end
                    TestFilter.Export = function(self)
                        return self.items
                    end
                    return TestFilter
                end)(),
                compressor = {
                    Compress = function(self, str) return str end,
                    Decompress = function(self, str) return str end
                },
                encoder = {
                    EncodeForChannel = function(self, str) return str end,
                    DecodeFromChannel = function(self, str) return str end,
                    EncodeForPrint = function(self, str) return str end,
                    DecodeFromPrint = function(self, str) return str end
                },
                channels = { "CUSTOM" },
                onChange = function(table, key, row) end,
                discoveryQuietPeriod = 5.0,
                discoveryMaxTime = 30.0,
                onDiscoveryComplete = function() end,
                peerTimeout = 300.0,
            })
            Assert.IsEmptyTable(db)
            Assert.AreEqual(LibP2PDB:GetDatabase("LibP2PDBTests2"), db)

            -- verify internal database instance
            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.prefix, "LibP2PDBTests2")
            Assert.AreEqual(dbi.version, 2)
            Assert.AreEqual(dbi.clock, 0)
            Assert.AreEqual(dbi.channels, { "CUSTOM" })
            Assert.AreEqual(dbi.discoveryQuietPeriod, 5.0)
            Assert.AreEqual(dbi.discoveryMaxTime, 30.0)
            Assert.AreEqual(dbi.peerTimeout, 300.0)
            Assert.IsInterface(dbi.filter, { "New", "Insert", "Contains", "Export", "Import" })
            Assert.IsInterface(dbi.serializer, { "Serialize", "Deserialize" })
            Assert.IsInterface(dbi.compressor, { "Compress", "Decompress" })
            Assert.IsInterface(dbi.encoder, { "EncodeForChannel", "DecodeFromChannel", "EncodeForPrint", "DecodeFromPrint" })
            Assert.IsNonEmptyTable(dbi.peers)
            Assert.IsNonEmptyTable(dbi.peersSorted)
            Assert.IsEmptyTable(dbi.buckets)
            Assert.IsEmptyTable(dbi.tables)
            Assert.IsFunction(dbi.onError)
            Assert.IsFunction(dbi.onChange)
            Assert.IsFunction(dbi.onDiscoveryComplete)
            Assert.IsNil(dbi.discoveryStartTime)
            Assert.IsNil(dbi.lastDiscoveryResponseTime)
        end
    end,

    NewDatabase_DescIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase(nil) end)
        Assert.Throws(function() LibP2PDB:NewDatabase(true) end)
        Assert.Throws(function() LibP2PDB:NewDatabase(false) end)
        Assert.Throws(function() LibP2PDB:NewDatabase("") end)
        Assert.Throws(function() LibP2PDB:NewDatabase("invalid") end)
        Assert.Throws(function() LibP2PDB:NewDatabase(123) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({}) end)
    end,

    NewDatabase_DescPrefixIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = nil }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "this_prefix_is_longer_than_16_characters" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = {} }) end)
    end,

    NewDatabase_DescOnErrorIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onError = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onError = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onError = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onError = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onError = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onError = {} }) end)
    end,

    NewDatabase_DescChannelsIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = {} }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = { true } }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = { false } }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = { "" } }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = { 123 } }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", channels = { {} } }) end)
    end,

    NewDatabase_DescOnChangeIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = {} }) end)
    end,

    NewDatabase_DescDiscoveryQuietPeriodIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryQuietPeriod = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryQuietPeriod = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryQuietPeriod = -1 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryQuietPeriod = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryQuietPeriod = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryQuietPeriod = {} }) end)
    end,

    NewDatabase_DescDiscoveryMaxTimeIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryMaxTime = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryMaxTime = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryMaxTime = -1 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryMaxTime = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryMaxTime = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", discoveryMaxTime = {} }) end)
    end,

    NewDatabase_DescOnDiscoveryCompleteIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onDiscoveryComplete = true }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onDiscoveryComplete = false }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onDiscoveryComplete = "" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onDiscoveryComplete = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onDiscoveryComplete = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onDiscoveryComplete = {} }) end)
    end,

    NewDatabase_PrefixAlreadyExists_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.IsEmptyTable(db)
        Assert.Throws(function() LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" }) end)
    end,

    NewDatabase_DefaultSerializerNotFound_Throws = function()
        -- can't test this properly since we do not want to unload libraries
    end,

    NewDatabase_CustomSerializerFails_Throws = function()
        Assert.Throws(function()
            LibP2PDB:NewDatabase({
                prefix = "LibP2PDBTests",
                serializer = {
                    Serialize = function(self, data) return tostring(data) end,
                    Deserialize = function(self, str) return {} end,
                },
            })
        end)
    end,

    NewDatabase_DefaultCompressorNotFound_Throws = function()
        -- can't test this properly since we do not want to unload libraries
    end,

    NewDatabase_CustomCompressorFails_Throws = function()
        Assert.Throws(function()
            LibP2PDB:NewDatabase({
                prefix = "LibP2PDBTests",
                compressor = {
                    Compress = function(self, str) return str end,
                    Decompress = function(self, str) return nil end,
                },
            })
        end)
    end,

    NewDatabase_DefaultEncoderNotFound_Throws = function()
        -- can't test this properly since we do not want to unload libraries
    end,

    NewDatabase_CustomEncoderFails_Throws = function()
        Assert.Throws(function()
            LibP2PDB:NewDatabase({
                prefix = "LibP2PDBTests",
                encoder = {
                    EncodeForChannel = function(self, str) return str end,
                    DecodeFromChannel = function(self, str) return nil end,
                    EncodeForPrint = function(self, str) return str end,
                    DecodeFromPrint = function(self, str) return nil end,
                },
            })
        end)
    end,

    NewDatabase_RegistersCommPrefix = function()
        local db = LibP2PDB:NewDatabase({ prefix = "_LibP2PDBTests_" })
        Assert.IsEmptyTable(db)
        Assert.IsTrue(C_ChatInfo.IsAddonMessagePrefixRegistered("_LibP2PDBTests_"))
    end,

    GetDatabase = function()
        local db1 = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests1" })
        Assert.IsEmptyTable(db1)

        local db2 = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests2" })
        Assert.IsEmptyTable(db2)

        local fetched1 = LibP2PDB:GetDatabase("LibP2PDBTests1")
        Assert.AreEqual(fetched1, db1)

        local fetched2 = LibP2PDB:GetDatabase("LibP2PDBTests2")
        Assert.AreEqual(fetched2, db2)

        local fetchedNil = LibP2PDB:GetDatabase("NonExistent")
        Assert.IsNil(fetchedNil)
    end,

    GetDatabase_PrefixIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:GetDatabase(nil) end)
        Assert.Throws(function() LibP2PDB:GetDatabase(true) end)
        Assert.Throws(function() LibP2PDB:GetDatabase(false) end)
        Assert.Throws(function() LibP2PDB:GetDatabase("") end)
        Assert.Throws(function() LibP2PDB:GetDatabase("this_prefix_is_longer_than_16_characters") end)
        Assert.Throws(function() LibP2PDB:GetDatabase(123) end)
        Assert.Throws(function() LibP2PDB:GetDatabase({}) end)
    end,

    NewTable = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.IsEmptyTable(db)
        local dbi = priv.databases[db]
        Assert.IsNonEmptyTable(dbi)

        do -- check new table creation with minimal description
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })

            local ti = dbi.tables["Users1"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.keyType, "string")
            Assert.IsNil(ti.schema)
            Assert.IsNil(ti.schemaSorted)
            Assert.IsNil(ti.onValidate)
            Assert.IsNil(ti.onChange)
            Assert.IsTable(ti.subscribers)
            Assert.AreEqual(ti.rowCount, 0)
            Assert.IsEmptyTable(ti.rows)
            Assert.IsTable(ti.summary)
        end
        do -- check new table creation with full description
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = { "number", "nil" },
                },
                onValidate = function(key, row) return true end,
                onChange = function(key, row) end,
            })

            local ti = dbi.tables["Users2"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.keyType, "number")
            Assert.AreEqual(ti.schema, { name = "string", age = { "number", "nil" } })
            Assert.AreEqual(ti.schemaSorted, { { "age", { "number", "nil" } }, { "name", "string" } })
            Assert.IsFunction(ti.onValidate)
            Assert.IsFunction(ti.onChange)
            Assert.IsTable(ti.subscribers)
            Assert.AreEqual(ti.rowCount, 0)
            Assert.IsEmptyTable(ti.rows)
            Assert.IsTable(ti.summary)
        end
        do -- check schema allowed types
            local schemaDef = {
                boolField = "boolean",
                strField = "string",
                numField = "number",
                nilField = "nil", -- not really useful?
                multiple = { "boolean", "string", "number", "nil" },
            }
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "string",
                schema = schemaDef,
            })

            local ti = dbi.tables["Users3"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.schema, schemaDef)
        end
    end,

    NewTable_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:NewTable(nil, { name = "Users", keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(true, { name = "Users", keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(false, { name = "Users", keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable("", { name = "Users", keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(123, { name = "Users", keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable({}, { name = "Users", keyType = "string" }) end)
    end,

    NewTable_DescIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:NewTable(db, nil) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, true) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, false) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, "") end)
        Assert.Throws(function() LibP2PDB:NewTable(db, "invalid") end)
        Assert.Throws(function() LibP2PDB:NewTable(db, 123) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, {}) end)
    end,

    NewTable_DescTableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = nil, keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = true, keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = false, keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "", keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = 123, keyType = "string" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = {}, keyType = "string" }) end)
    end,

    NewTable_DescKeyTypeIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = nil }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = true }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = false }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "boolean" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "nil" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "table" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "function" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "userdata" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "thread" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = {} }) end)
    end,

    NewTable_DescSchemaIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = true }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = false }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = "" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = {} }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = true } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = false } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = "" } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = "table" } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = "function" } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = "userdata" } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = "thread" } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = 123 } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = {} } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { true } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { false } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { "" } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { "table" } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { "function" } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { "userdata" } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { "thread" } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { 123 } } }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { a = { {} } } }) end)
    end,

    NewTable_DescOnValidateIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onValidate = true }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onValidate = false }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onValidate = "" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onValidate = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onValidate = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onValidate = {} }) end)
    end,

    NewTable_DescOnChangeIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onChange = true }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onChange = false }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onChange = "" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onChange = "invalid" }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onChange = 123 }) end)
        Assert.Throws(function() LibP2PDB:NewTable(db, { name = "Users", keyType = "string", onChange = {} }) end)
    end,

    NewTable_NameAlreadyExists_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local tableDesc = { name = "Users", keyType = "string" }
        LibP2PDB:NewTable(db, tableDesc)
        Assert.Throws(function() LibP2PDB:NewTable(db, tableDesc) end)
    end,

    InsertKey = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- test with string key type and no schema
            LibP2PDB:NewTable(db, {
                name = "Users1",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user1", { name = "Bob", age = 25, city = "NY" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Bob", age = 25, city = "NY" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user2", { name = "Alice", age = 30, town = "LA" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user2"), { name = "Alice", age = 30, town = "LA" })
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users1", "user3", { name = "Eve", age = -1 }))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users1", "user3"))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user4", {}))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user4"), {})
        end
        do -- test with number key type and schema
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 1, { name = "Bob", age = 25 }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Bob", age = 25 })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 2, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 2), { name = "Alice" })
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users2", 3, { name = "Eve", age = -1 }))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users2", 3))
        end
        do -- check inserting over deleted keys
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "number",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end,
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Bob" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Bob" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Eve" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Eve" })

            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Eve" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Eve" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Bob" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Bob" })
        end
    end,

    InsertKey_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:InsertKey(nil, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(true, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(false, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey("", "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey("invalid", "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(123, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey({}, "Users", 1, { name = "A" }) end)
    end,

    InsertKey_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:InsertKey(db, nil, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, true, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, false, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "invalid", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, 123, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, {}, 1, { name = "A" }) end)
    end,

    InsertKey_KeyIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- check string key type
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users1", nil, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users1", true, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users1", false, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users1", "", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users1", 123, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users1", {}, { name = "A" }) end)
        end
        do -- check number key type
            LibP2PDB:NewTable(db, { name = "Users2", keyType = "number" })
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users2", nil, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users2", true, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users2", false, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users2", "", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users2", "invalid", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:InsertKey(db, "Users2", {}, { name = "A" }) end)
        end
    end,

    InsertKey_DataIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, nil) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, true) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, false) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, "") end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, "invalid") end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, 123) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, {}) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob" }) end)
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, { age = 25 }) end)
    end,

    InsertKey_UpdatesRowCount = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, {
            name = "Users",
            keyType = "number",
            schema = {
                name = "string",
                age = {
                    "number",
                    "nil"
                }
            },
            onValidate = function(key, data)
                return not data or not data.age or data.age >= 0
            end
        })

        local ti = priv.databases[db].tables["Users"]
        Assert.IsNonEmptyTable(ti)
        Assert.AreEqual(ti.rowCount, 0)

        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice" }))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsFalse(LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = -1 }))
        Assert.AreEqual(ti.rowCount, 2)
    end,

    InsertKey_InvokeChangeCallbacks = function()
        local dbCount, tableCount, subCount = 0, 0, 0
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = function() dbCount = dbCount + 1 end })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", onChange = function() tableCount = tableCount + 1 end })
        LibP2PDB:Subscribe(db, "Users", function() subCount = subCount + 1 end)
        Assert.AreEqual(dbCount, 0)
        Assert.AreEqual(tableCount, 0)
        Assert.AreEqual(subCount, 0)

        -- check inserting a new key invokes all callbacks
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        -- check inserting the same key again does not invoke any callbacks
        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }) end)
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        -- check inserting over a deleted key invokes all callbacks
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(dbCount, 3)    -- 1 for delete, 1 for insert
        Assert.AreEqual(tableCount, 3) -- 1 for delete, 1 for insert
        Assert.AreEqual(subCount, 3)   -- 1 for delete, 1 for insert
    end,

    SetKey = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- test with string key type and no schema
            LibP2PDB:NewTable(db, {
                name = "Users1",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users1", "user1", { name = "Bob", age = 25, city = "NY" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Bob", age = 25, city = "NY" })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users1", "user1", { name = "Alice", age = 30, town = "LA" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Alice", age = 30, town = "LA" })
            Assert.IsFalse(LibP2PDB:SetKey(db, "Users1", "user1", { name = "Eve", age = -1 }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Alice", age = 30, town = "LA" })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users1", "user1", {}))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), {})
        end
        do -- test with number key type and schema
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users2", 1, { name = "Bob", age = 25 }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Bob", age = 25 })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users2", 1, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Alice" })
            Assert.IsFalse(LibP2PDB:SetKey(db, "Users2", 1, { name = "Eve", age = -1 }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Alice" })
        end
        do -- check setting over deleted keys
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "number",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users3", 1, { name = "Bob" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Bob" })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users3", 2, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users3", 3, { name = "Eve" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Eve" })

            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:SetKey(db, "Users3", 1, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users3", 2, { name = "Eve" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Eve" })
            Assert.IsTrue(LibP2PDB:SetKey(db, "Users3", 3, { name = "Bob" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Bob" })
        end
    end,

    SetKey_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:SetKey(nil, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(true, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(false, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey("", "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey("invalid", "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(123, "Users", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey({}, "Users", 1, { name = "A" }) end)
    end,

    SetKey_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:SetKey(db, nil, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, true, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, false, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "invalid", 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, 123, 1, { name = "A" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, {}, 1, { name = "A" }) end)
    end,

    SetKey_KeyIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- check string key type
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users1", nil, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users1", true, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users1", false, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users1", "", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users1", 123, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users1", {}, { name = "A" }) end)
        end
        do -- check number key type
            LibP2PDB:NewTable(db, { name = "Users2", keyType = "number" })
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users2", nil, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users2", true, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users2", false, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users2", "", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users2", "invalid", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:SetKey(db, "Users2", {}, { name = "A" }) end)
        end
    end,

    SetKey_DataIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, nil) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, true) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, false) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, "") end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, "invalid") end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, 123) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, {}) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, { name = "Bob" }) end)
        Assert.Throws(function() LibP2PDB:SetKey(db, "Users", 1, { age = 25 }) end)
    end,

    SetKey_UpdatesRowCount = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, {
            name = "Users",
            keyType = "number",
            schema = {
                name = "string",
                age = {
                    "number",
                    "nil"
                }
            },
            onValidate = function(key, data)
                return not data or not data.age or data.age >= 0
            end
        })

        local ti = priv.databases[db].tables["Users"]
        Assert.IsNonEmptyTable(ti)
        Assert.AreEqual(ti.rowCount, 0)

        Assert.IsTrue(LibP2PDB:SetKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:SetKey(db, "Users", 2, { name = "Alice" }))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsFalse(LibP2PDB:SetKey(db, "Users", 3, { name = "Eve", age = -1 }))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:SetKey(db, "Users", 1, { name = "Bob", age = 30 }))
        Assert.AreEqual(ti.rowCount, 2)
    end,

    SetKey_InvokeChangeCallbacks = function()
        local dbCount, tableCount, subCount = 0, 0, 0
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = function() dbCount = dbCount + 1 end })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", onChange = function() tableCount = tableCount + 1 end })
        LibP2PDB:Subscribe(db, "Users", function() subCount = subCount + 1 end)
        Assert.AreEqual(dbCount, 0)
        Assert.AreEqual(tableCount, 0)
        Assert.AreEqual(subCount, 0)

        -- check inserting a new key invokes all callbacks
        Assert.IsTrue(LibP2PDB:SetKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        -- check inserting the same key again with same data does not invoke any callbacks
        Assert.IsTrue(LibP2PDB:SetKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        -- check inserting over a deleted key invokes all callbacks
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.IsTrue(LibP2PDB:SetKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(dbCount, 3)    -- 1 for delete, 1 for insert
        Assert.AreEqual(tableCount, 3) -- 1 for delete, 1 for insert
        Assert.AreEqual(subCount, 3)   -- 1 for delete, 1 for insert
    end,

    UpdateKey = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- test with string key type and no schema
            LibP2PDB:NewTable(db, {
                name = "Users1",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users1", "user1", function(data) return { name = "Bob", age = 25, city = "NY" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Bob", age = 25, city = "NY" })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users1", "user1", function(data) return { name = "Alice", age = 30, town = "LA" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Alice", age = 30, town = "LA" })
            Assert.IsFalse(LibP2PDB:UpdateKey(db, "Users1", "user1", function(data) return { name = "Eve", age = -1 } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Alice", age = 30, town = "LA" })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users1", "user1", function(data) return {} end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), {})
        end
        do -- test with number key type and schema
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users2", 1, function(data) return { name = "Bob", age = 25 } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Bob", age = 25 })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users2", 1, function(data) return { name = "Alice" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Alice" })
            Assert.IsFalse(LibP2PDB:UpdateKey(db, "Users2", 1, function(data) return { name = "Eve", age = -1 } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Alice" })
        end
        do -- check updating over deleted keys
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "number",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users3", 1, function(data) return { name = "Bob" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Bob" })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users3", 2, function(data) return { name = "Alice" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users3", 3, function(data) return { name = "Eve" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Eve" })

            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users3", 1, function(data) return { name = "Alice" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users3", 2, function(data) return { name = "Eve" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Eve" })
            Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users3", 3, function(data) return { name = "Bob" } end))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Bob" })
        end
    end,

    UpdateKey_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:UpdateKey(nil, "Users", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(true, "Users", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(false, "Users", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey("", "Users", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey("invalid", "Users", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(123, "Users", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey({}, "Users", 1, function(data) return data end) end)
    end,

    UpdateKey_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:UpdateKey(db, nil, 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, true, 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, false, 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "invalid", 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, 123, 1, function(data) return data end) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, {}, 1, function(data) return data end) end)
    end,

    UpdateKey_KeyIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- check string key type
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users1", nil, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users1", true, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users1", false, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users1", "", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users1", 123, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users1", {}, { name = "A" }) end)
        end
        do -- check number key type
            LibP2PDB:NewTable(db, { name = "Users2", keyType = "number" })
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users2", nil, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users2", true, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users2", false, { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users2", "", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users2", "invalid", { name = "A" }) end)
            Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users2", {}, { name = "A" }) end)
        end
    end,

    UpdateKey_UpdateFunctionIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, nil) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, true) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, false) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, "") end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, "invalid") end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, 123) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, {}) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, { name = "Bob" }) end)
        Assert.Throws(function() LibP2PDB:UpdateKey(db, "Users", 1, { age = 25 }) end)
    end,

    UpdateKey_UpdatesRowCount = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, {
            name = "Users",
            keyType = "number",
            schema = {
                name = "string",
                age = {
                    "number",
                    "nil"
                }
            },
            onValidate = function(key, data)
                return not data or not data.age or data.age >= 0
            end
        })

        local ti = priv.databases[db].tables["Users"]
        Assert.IsNonEmptyTable(ti)
        Assert.AreEqual(ti.rowCount, 0)

        Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users", 1, function() return { name = "Bob", age = 25 } end))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users", 2, function() return { name = "Alice" } end))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsFalse(LibP2PDB:UpdateKey(db, "Users", 3, function() return { name = "Eve", age = -1 } end))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users", 1, function(row)
            row.age = 30
            return row
        end))
        Assert.AreEqual(ti.rowCount, 2)
    end,

    UpdateKey_InvokeChangeCallbacks = function()
        local dbCount, tableCount, subCount = 0, 0, 0
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = function() dbCount = dbCount + 1 end })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", onChange = function() tableCount = tableCount + 1 end })
        LibP2PDB:Subscribe(db, "Users", function() subCount = subCount + 1 end)
        Assert.AreEqual(dbCount, 0)
        Assert.AreEqual(tableCount, 0)
        Assert.AreEqual(subCount, 0)

        -- check inserting a new key invokes all callbacks
        Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users", 1, function() return { name = "Bob", age = 25 } end))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        -- check inserting the same key again with same data does not invoke any callbacks
        Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users", 1, function() return { name = "Bob", age = 25 } end))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        -- check inserting over a deleted key invokes all callbacks
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.IsTrue(LibP2PDB:UpdateKey(db, "Users", 1, function() return { name = "Bob", age = 25 } end))
        Assert.AreEqual(dbCount, 3)    -- 1 for delete, 1 for insert
        Assert.AreEqual(tableCount, 3) -- 1 for delete, 1 for insert
        Assert.AreEqual(subCount, 3)   -- 1 for delete, 1 for insert
    end,

    UpdateKey_UpdateFunctionData_IsNotModified = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
        LibP2PDB:UpdateKey(db, "Users", 1, function(row)
            row.additionalField = "abc"
            return row
        end)
        local fetchedRow = LibP2PDB:GetKey(db, "Users", 1)
        Assert.AreEqual(fetchedRow, { name = "Bob", age = 25 })
    end,

    DeleteKey = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- test with string key type and no schema
            LibP2PDB:NewTable(db, {
                name = "Users1",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user1", { name = "Bob", age = 25, city = "NY" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users1", "user1"))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user2", { name = "Alice", age = 30, town = "LA" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users1", "user2"))
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users1", "user3", { name = "Eve", age = -1 }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users1", "user3"))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user4", {}))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users1", "user4"))
        end
        do -- test with number key type and schema
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 1, { name = "Bob", age = 25 }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users2", 1))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 2, { name = "Alice" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users2", 2))
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users2", 3, { name = "Eve", age = -1 }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users2", 3))
        end
        do -- check inserting over deleted keys
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "number",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end,
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Bob" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Alice" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Eve" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Alice" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Eve" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Bob" }))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
        end
    end,

    DeleteKey_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:DeleteKey(nil, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(true, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(false, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey("", "Users", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey("invalid", "Users", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(123, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey({}, "Users", 1) end)
    end,

    DeleteKey_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:DeleteKey(db, nil, 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(db, true, 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(db, false, 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(db, "", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(db, "invalid", 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(db, 123, 1) end)
        Assert.Throws(function() LibP2PDB:DeleteKey(db, {}, 1) end)
    end,

    DeleteKey_KeyIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- check string key type
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users1", nil) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users1", true) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users1", false) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users1", "") end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users1", 123) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users1", {}) end)
        end
        do -- check number key type
            LibP2PDB:NewTable(db, { name = "Users2", keyType = "number" })
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users2", nil) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users2", true) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users2", false) end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users2", "") end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users2", "invalid") end)
            Assert.Throws(function() LibP2PDB:DeleteKey(db, "Users2", {}) end)
        end
    end,

    DeleteKey_UpdatesRowCount = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, {
            name = "Users",
            keyType = "number",
            schema = {
                name = "string",
                age = {
                    "number",
                    "nil"
                }
            },
            onValidate = function(key, data)
                return not data or not data.age or data.age >= 0
            end
        })

        local ti = priv.databases[db].tables["Users"]
        Assert.IsNonEmptyTable(ti)
        Assert.AreEqual(ti.rowCount, 0)

        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice" }))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 2))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 3))
        Assert.AreEqual(ti.rowCount, 3)
    end,

    DeleteKey_InvokeChangeCallbacks = function()
        local dbCount, tableCount, subCount = 0, 0, 0
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = function() dbCount = dbCount + 1 end })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", onChange = function() tableCount = tableCount + 1 end })
        LibP2PDB:Subscribe(db, "Users", function() subCount = subCount + 1 end)
        Assert.AreEqual(dbCount, 0)
        Assert.AreEqual(tableCount, 0)
        Assert.AreEqual(subCount, 0)

        -- check deleting a key invokes all callbacks
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.AreEqual(dbCount, 2)    -- 1 for insert, 1 for delete
        Assert.AreEqual(tableCount, 2) -- 1 for insert, 1 for delete
        Assert.AreEqual(subCount, 2)   -- 1 for insert, 1 for delete

        -- check deleting the same key again does not invoke any callbacks
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.AreEqual(dbCount, 2)
        Assert.AreEqual(tableCount, 2)
        Assert.AreEqual(subCount, 2)

        -- check deleting a non-existent key invokes all callbacks
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 2))
        Assert.AreEqual(dbCount, 3)
        Assert.AreEqual(tableCount, 3)
        Assert.AreEqual(subCount, 3)
    end,

    HasKey = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- test with string key type and no schema
            LibP2PDB:NewTable(db, {
                name = "Users1",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user1", { name = "Bob", age = 25, city = "NY" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users1", "user1"))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user2", { name = "Alice", age = 30, town = "LA" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users1", "user2"))
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users1", "user3", { name = "Eve", age = -1 }))
            Assert.IsFalse(LibP2PDB:HasKey(db, "Users1", "user3"))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user4", {}))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users1", "user4"))
        end
        do -- test with number key type and schema
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 1, { name = "Bob", age = 25 }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users2", 1))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 2, { name = "Alice" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users2", 2))
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users2", 3, { name = "Eve", age = -1 }))
            Assert.IsFalse(LibP2PDB:HasKey(db, "Users2", 3))
        end
        do -- check inserting over deleted keys
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "number",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end,
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Bob" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Alice" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Eve" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsFalse(LibP2PDB:HasKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsFalse(LibP2PDB:HasKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
            Assert.IsFalse(LibP2PDB:HasKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Alice" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Eve" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Bob" }))
            Assert.IsTrue(LibP2PDB:HasKey(db, "Users3", 3))
        end
    end,

    HasKey_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:HasKey(nil, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(true, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(false, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey("", "Users", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey("invalid", "Users", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(123, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey({}, "Users", 1) end)
    end,

    HasKey_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:HasKey(db, nil, 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(db, true, 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(db, false, 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(db, "", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(db, "invalid", 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(db, 123, 1) end)
        Assert.Throws(function() LibP2PDB:HasKey(db, {}, 1) end)
    end,

    HasKey_KeyIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- check string key type
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users1", nil) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users1", true) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users1", false) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users1", "") end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users1", 123) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users1", {}) end)
        end
        do -- check number key type
            LibP2PDB:NewTable(db, { name = "Users2", keyType = "number" })
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users2", nil) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users2", true) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users2", false) end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users2", "") end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users2", "invalid") end)
            Assert.Throws(function() LibP2PDB:HasKey(db, "Users2", {}) end)
        end
    end,

    HasKey_DoesNotUpdateRowCount = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = { "number", "nil" } } })

        local ti = priv.databases[db].tables["Users"]
        Assert.IsNonEmptyTable(ti)
        Assert.AreEqual(ti.rowCount, 0)

        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:HasKey(db, "Users", 1))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice" }))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:HasKey(db, "Users", 2))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsFalse(LibP2PDB:HasKey(db, "Users", 1))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsFalse(LibP2PDB:HasKey(db, "Users", 3))
        Assert.AreEqual(ti.rowCount, 2)
    end,

    HasKey_DoesNotInvokeChangeCallbacks = function()
        local dbCount, tableCount, subCount = 0, 0, 0
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = function() dbCount = dbCount + 1 end })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", onChange = function() tableCount = tableCount + 1 end })
        LibP2PDB:Subscribe(db, "Users", function() subCount = subCount + 1 end)
        Assert.AreEqual(dbCount, 0)
        Assert.AreEqual(tableCount, 0)
        Assert.AreEqual(subCount, 0)

        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.IsTrue(LibP2PDB:HasKey(db, "Users", 1))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }) end)
        Assert.IsTrue(LibP2PDB:HasKey(db, "Users", 1))
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.IsFalse(LibP2PDB:HasKey(db, "Users", 1))
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.IsTrue(LibP2PDB:HasKey(db, "Users", 1))
        Assert.AreEqual(dbCount, 3)    -- 1 for delete, 1 for insert
        Assert.AreEqual(tableCount, 3) -- 1 for delete, 1 for insert
        Assert.AreEqual(subCount, 3)   -- 1 for delete, 1 for insert
    end,

    GetKey = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- test with string key type and no schema
            LibP2PDB:NewTable(db, {
                name = "Users1",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user1", { name = "Bob", age = 25, city = "NY" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user1"), { name = "Bob", age = 25, city = "NY" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user2", { name = "Alice", age = 30, town = "LA" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user2"), { name = "Alice", age = 30, town = "LA" })
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users1", "user3", { name = "Eve", age = -1 }))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users1", "user3"))
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users1", "user4", {}))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users1", "user4"), {})
        end
        do -- test with number key type and schema
            LibP2PDB:NewTable(db, {
                name = "Users2",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 1, { name = "Bob", age = 25 }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 1), { name = "Bob", age = 25 })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users2", 2, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users2", 2), { name = "Alice" })
            Assert.IsFalse(LibP2PDB:InsertKey(db, "Users2", 3, { name = "Eve", age = -1 }))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users2", 3))
        end
        do -- check inserting over deleted keys
            LibP2PDB:NewTable(db, {
                name = "Users3",
                keyType = "number",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end,
            })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Bob" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Bob" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Eve" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Eve" })

            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 1))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 1))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 2))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 2))
            Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users3", 3))
            Assert.IsNil(LibP2PDB:GetKey(db, "Users3", 3))

            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 1, { name = "Alice" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 1), { name = "Alice" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 2, { name = "Eve" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 2), { name = "Eve" })
            Assert.IsTrue(LibP2PDB:InsertKey(db, "Users3", 3, { name = "Bob" }))
            Assert.AreEqual(LibP2PDB:GetKey(db, "Users3", 3), { name = "Bob" })
        end
    end,

    GetKey_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:GetKey(nil, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(true, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(false, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey("", "Users", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey("invalid", "Users", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(123, "Users", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey({}, "Users", 1) end)
    end,

    GetKey_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:GetKey(db, nil, 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(db, true, 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(db, false, 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(db, "", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(db, "invalid", 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(db, 123, 1) end)
        Assert.Throws(function() LibP2PDB:GetKey(db, {}, 1) end)
    end,

    GetKey_KeyIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        do -- check string key type
            LibP2PDB:NewTable(db, { name = "Users1", keyType = "string" })
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users1", nil) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users1", true) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users1", false) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users1", "") end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users1", 123) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users1", {}) end)
        end
        do -- check number key type
            LibP2PDB:NewTable(db, { name = "Users2", keyType = "number" })
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users2", nil) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users2", true) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users2", false) end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users2", "") end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users2", "invalid") end)
            Assert.Throws(function() LibP2PDB:GetKey(db, "Users2", {}) end)
        end
    end,

    GetKey_DoesNotUpdateRowCount = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = { "number", "nil" } } })

        local ti = priv.databases[db].tables["Users"]
        Assert.IsNonEmptyTable(ti)
        Assert.AreEqual(ti.rowCount, 0)

        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(ti.rowCount, 1)
        Assert.AreEqual(LibP2PDB:GetKey(db, "Users", 1), { name = "Bob", age = 25 })
        Assert.AreEqual(ti.rowCount, 1)
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice" }))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.AreEqual(LibP2PDB:GetKey(db, "Users", 2), { name = "Alice" })
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsNil(LibP2PDB:GetKey(db, "Users", 1))
        Assert.AreEqual(ti.rowCount, 2)
        Assert.IsNil(LibP2PDB:GetKey(db, "Users", 3))
        Assert.AreEqual(ti.rowCount, 2)
    end,

    GetKey_DoesNotInvokeChangeCallbacks = function()
        local dbCount, tableCount, subCount = 0, 0, 0
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", onChange = function() dbCount = dbCount + 1 end })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", onChange = function() tableCount = tableCount + 1 end })
        LibP2PDB:Subscribe(db, "Users", function() subCount = subCount + 1 end)
        Assert.AreEqual(dbCount, 0)
        Assert.AreEqual(tableCount, 0)
        Assert.AreEqual(subCount, 0)

        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(LibP2PDB:GetKey(db, "Users", 1), { name = "Bob", age = 25 })
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        Assert.Throws(function() LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }) end)
        Assert.AreEqual(LibP2PDB:GetKey(db, "Users", 1), { name = "Bob", age = 25 })
        Assert.AreEqual(dbCount, 1)
        Assert.AreEqual(tableCount, 1)
        Assert.AreEqual(subCount, 1)

        Assert.IsTrue(LibP2PDB:DeleteKey(db, "Users", 1))
        Assert.IsNil(LibP2PDB:GetKey(db, "Users", 1))
        Assert.IsTrue(LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 }))
        Assert.AreEqual(LibP2PDB:GetKey(db, "Users", 1), { name = "Bob", age = 25 })
        Assert.AreEqual(dbCount, 3)    -- 1 for delete, 1 for insert
        Assert.AreEqual(tableCount, 3) -- 1 for delete, 1 for insert
        Assert.AreEqual(subCount, 3)   -- 1 for delete, 1 for insert
    end,

    Version = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string" } })
        LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob" })

        local version = priv.databases[db].tables["Users"].rows[1].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 1)
        Assert.AreEqual(version.peer, priv.peerId)
        Assert.IsNil(version.tombstone)

        LibP2PDB:UpdateKey(db, "Users", 1, function(row)
            row.name = "Robert"
            return row
        end)
        version = priv.databases[db].tables["Users"].rows[1].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 2)
        Assert.AreEqual(version.peer, priv.peerId)
        Assert.IsNil(version.tombstone)

        LibP2PDB:DeleteKey(db, "Users", 1)
        version = priv.databases[db].tables["Users"].rows[1].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 3)
        Assert.AreEqual(version.peer, priv.peerId)
        Assert.IsTrue(version.tombstone)
    end,

    Version_WhenPeerEqualsKey_PeerValueIsEqualChar = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { name = "string" } })

        LibP2PDB:InsertKey(db, "Users", priv.peerId, { name = "Bob" })
        local version = priv.databases[db].tables["Users"].rows[priv.peerId].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 1)
        Assert.AreEqual(version.peer, "=")
        Assert.IsNil(version.tombstone)

        LibP2PDB:SetKey(db, "Users", priv.peerId, { name = "Robert" })
        version = priv.databases[db].tables["Users"].rows[priv.peerId].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 2)
        Assert.AreEqual(version.peer, "=")
        Assert.IsNil(version.tombstone)

        LibP2PDB:UpdateKey(db, "Users", priv.peerId, function(row)
            row.name = "Alice"
            return row
        end)
        version = priv.databases[db].tables["Users"].rows[priv.peerId].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 3)
        Assert.AreEqual(version.peer, "=")
        Assert.IsNil(version.tombstone)

        LibP2PDB:DeleteKey(db, "Users", priv.peerId)
        version = priv.databases[db].tables["Users"].rows[priv.peerId].version
        Assert.IsTable(version)
        Assert.AreEqual(version.clock, 4)
        Assert.AreEqual(version.peer, "=")
        Assert.IsTrue(version.tombstone)
    end,

    Subscribe = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        local callbackInvoked = 0
        local callback = function(key, row)
            callbackInvoked = callbackInvoked + 1
            Assert.AreEqual(key, 1)
            Assert.AreEqual(row, { name = "Bob", age = 25 })
        end
        LibP2PDB:Subscribe(db, "Users", callback)
        LibP2PDB:Subscribe(db, "Users", callback)
        LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
        Assert.AreEqual(callbackInvoked, 1)
    end,

    Subscribe_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:Subscribe(nil, "Users", function() end) end)
        Assert.Throws(function() LibP2PDB:Subscribe(123, "Users", function() end) end)
        Assert.Throws(function() LibP2PDB:Subscribe("", "Users", function() end) end)
        Assert.Throws(function() LibP2PDB:Subscribe({}, "Users", function() end) end)
    end,

    Subscribe_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:Subscribe(db, nil, function() end) end)
        Assert.Throws(function() LibP2PDB:Subscribe(db, 123, function() end) end)
        Assert.Throws(function() LibP2PDB:Subscribe(db, {}, function() end) end)
    end,

    Subscribe_CallbackIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "string" })
        Assert.Throws(function() LibP2PDB:Subscribe(db, "Users", nil) end)
        Assert.Throws(function() LibP2PDB:Subscribe(db, "Users", 123) end)
        Assert.Throws(function() LibP2PDB:Subscribe(db, "Users", "invalid") end)
    end,

    Unsubscribe = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        local callbackInvoked = 0
        local callback = function(key, row)
            callbackInvoked = callbackInvoked + 1
        end
        LibP2PDB:Subscribe(db, "Users", callback)
        LibP2PDB:Unsubscribe(db, "Users", callback)
        LibP2PDB:Unsubscribe(db, "Users", callback)
        LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
        Assert.AreEqual(callbackInvoked, 0)
    end,

    Unsubscribe_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:Unsubscribe(nil, "Users", function() end) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe(123, "Users", function() end) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe("", "Users", function() end) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe({}, "Users", function() end) end)
    end,

    Unsubscribe_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:Unsubscribe(db, nil, function() end) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe(db, 123, function() end) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe(db, {}, function() end) end)
    end,

    Unsubscribe_CallbackIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "string" })
        Assert.Throws(function() LibP2PDB:Unsubscribe(db, "Users", nil) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe(db, "Users", 123) end)
        Assert.Throws(function() LibP2PDB:Unsubscribe(db, "Users", "invalid") end)
    end,

    ExportDatabase = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
        LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })

        local state = LibP2PDB:ExportDatabase(db)
        Assert.IsNonEmptyTable(state)
    end,

    ExportDatabase_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:ExportDatabase(nil) end)
        Assert.Throws(function() LibP2PDB:ExportDatabase(true) end)
        Assert.Throws(function() LibP2PDB:ExportDatabase(false) end)
        Assert.Throws(function() LibP2PDB:ExportDatabase("") end)
        Assert.Throws(function() LibP2PDB:ExportDatabase("invalid") end)
        Assert.Throws(function() LibP2PDB:ExportDatabase(123) end)
        Assert.Throws(function() LibP2PDB:ExportDatabase({}) end)
    end,

    ImportDatabase = function()
        do -- test with string key type and no schema
            local dbExport = LibP2PDB:NewDatabase({ prefix = "LibP2PDBExport1" })
            local tableDesc = {
                name = "Users",
                keyType = "string",
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            }
            LibP2PDB:NewTable(dbExport, tableDesc)
            LibP2PDB:InsertKey(dbExport, "Users", "user1", { name = "Bob", age = 25, city = "NY" })
            LibP2PDB:InsertKey(dbExport, "Users", "user2", { name = "Alice", age = 30, town = "LA" })
            LibP2PDB:InsertKey(dbExport, "Users", "user3", { name = "Eve", age = -1 })
            LibP2PDB:InsertKey(dbExport, "Users", "user4", {})
            LibP2PDB:InsertKey(dbExport, "Users", "user5", { name = "Charlie", age = 28 })
            LibP2PDB:DeleteKey(dbExport, "Users", "user5")
            LibP2PDB:DeleteKey(dbExport, "Users", "user6")

            local state = LibP2PDB:ExportDatabase(dbExport)
            Assert.IsNonEmptyTable(state)

            local dbImport = LibP2PDB:NewDatabase({ prefix = "LibP2PDBImport1" })
            LibP2PDB:NewTable(dbImport, tableDesc)

            Assert.IsTrue(LibP2PDB:ImportDatabase(dbImport, state))

            local dbi = priv.databases[dbImport]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 6) -- 6 changes performed (1 rejected)
            Assert.IsNonEmptyTable(dbi.tables)

            local ti = dbi.tables["Users"]
            Assert.IsNonEmptyTable(ti)

            local rows = ti.rows
            Assert.IsNonEmptyTable(rows)

            Assert.AreEqual(rows["user1"], {
                data = {
                    name = "Bob",
                    age = 25,
                    city = "NY"
                },
                version = {
                    clock = 1,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.AreEqual(rows["user2"], {
                data = {
                    name = "Alice",
                    age = 30,
                    town = "LA"
                },
                version = {
                    clock = 2,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.IsNil(rows["user3"])
            Assert.AreEqual(rows["user4"], {
                data = {},
                version = {
                    clock = 3,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.AreEqual(rows["user5"], {
                data = nil,
                version = {
                    clock = 5,
                    peer = priv.peerId,
                    tombstone = true
                },
            })
            Assert.AreEqual(rows["user6"], {
                data = nil,
                version = {
                    clock = 6,
                    peer = priv.peerId,
                    tombstone = true
                },
            })
        end
        do -- test with number key type and schema
            local dbExport = LibP2PDB:NewDatabase({ prefix = "LibP2PDBExport2" })
            local tableDesc = {
                name = "Users",
                keyType = "number",
                schema = {
                    name = "string",
                    age = {
                        "number",
                        "nil"
                    }
                },
                onValidate = function(key, data)
                    return not data or not data.age or data.age >= 0
                end
            }
            LibP2PDB:NewTable(dbExport, tableDesc)
            LibP2PDB:InsertKey(dbExport, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(dbExport, "Users", 2, { name = "Alice" })
            LibP2PDB:InsertKey(dbExport, "Users", 3, { name = "Eve", age = -1 })
            LibP2PDB:InsertKey(dbExport, "Users", 4, { name = "Charlie", age = 28 })
            LibP2PDB:DeleteKey(dbExport, "Users", 4)
            LibP2PDB:DeleteKey(dbExport, "Users", 5)

            local state = LibP2PDB:ExportDatabase(dbExport)
            Assert.IsNonEmptyTable(state)

            local dbImport = LibP2PDB:NewDatabase({ prefix = "LibP2PDBImport2" })
            LibP2PDB:NewTable(dbImport, tableDesc)

            Assert.IsTrue(LibP2PDB:ImportDatabase(dbImport, state))

            local dbi = priv.databases[dbImport]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 5) -- 5 changes performed (1 rejected)
            Assert.IsNonEmptyTable(dbi.tables)

            local ti = dbi.tables["Users"]
            Assert.IsNonEmptyTable(ti)

            local rows = ti.rows
            Assert.IsNonEmptyTable(rows)
            Assert.AreEqual(rows[1], {
                data = {
                    name = "Bob",
                    age = 25
                },
                version = {
                    clock = 1,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.AreEqual(rows[2], {
                data = {
                    name = "Alice"
                },
                version = {
                    clock = 2,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.IsNil(rows[3])
            Assert.AreEqual(rows[4], {
                data = nil,
                version = {
                    clock = 4,
                    peer = priv.peerId,
                    tombstone = true
                },
            })
            Assert.AreEqual(rows[5], {
                data = nil,
                version = {
                    clock = 5,
                    peer = priv.peerId,
                    tombstone = true
                },
            })
        end
    end,

    ImportDatabase_DBIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local exported = LibP2PDB:ExportDatabase(db)
        Assert.Throws(function() LibP2PDB:ImportDatabase(nil, exported) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(true, exported) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(false, exported) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase("", exported) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase("invalid", exported) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(123, exported) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase({}, exported) end)
    end,

    ImportDatabase_StateIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, nil) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, true) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, false) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, "") end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, "invalid") end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, 123) end)
        Assert.Throws(function() LibP2PDB:ImportDatabase(db, {}) end)
    end,

    ImportDatabase_SkipInvalidTables = function()
        --- @type LibP2PDB.DBState
        local state = {
            [1] = 1,                       -- DBVersion
            [2] = 3,                       -- DBClock
            [3] = {                        -- Tables
                ["Users"] = {              -- First table
                    [1] = {                -- First row
                        [1] = {            -- Data
                            25,            -- age
                            "Bob"          -- name
                        },
                        [2] = 1,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                },
                ["InvalidTable"] = {       -- Invalid table structure
                    0x123,                 -- invalid
                },
                ["Posts"] = {              -- Third table
                    ["post1"] = {          -- First row
                        [1] = {            -- Data
                            "Hello World"  -- content
                        },
                        [2] = 3,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                },
            },
        }

        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        LibP2PDB:NewTable(db, { name = "Posts", keyType = "string", schema = { content = "string" } })

        Assert.ExpectErrors(function() LibP2PDB:ImportDatabase(db, state) end)

        local dbi = priv.databases[db]
        Assert.IsNonEmptyTable(dbi)
        Assert.AreEqual(dbi.clock, 3) -- State pretends 3 changes performed
        Assert.IsNonEmptyTable(dbi.tables)

        local usersTable = dbi.tables["Users"]
        Assert.IsNonEmptyTable(usersTable)

        local usersRows = usersTable.rows
        Assert.IsNonEmptyTable(usersRows)

        Assert.AreEqual(usersRows[1], {
            data = {
                name = "Bob",
                age = 25,
            },
            version = {
                clock = 1,
                peer = priv.peerId,
                tombstone = nil
            },
        })

        local invalidTable = dbi.tables["InvalidTable"]
        Assert.IsNil(invalidTable)

        local postsTable = dbi.tables["Posts"]
        Assert.IsNonEmptyTable(postsTable)

        local postsRows = postsTable.rows
        Assert.IsNonEmptyTable(postsRows)
        Assert.AreEqual(postsRows["post1"], {
            data = {
                content = "Hello World",
            },
            version = {
                clock = 3,
                peer = priv.peerId,
                tombstone = nil
            },
        })
    end,

    ImportDatabase_SkipInvalidRows = function()
        --- @type LibP2PDB.DBState
        local state = {
            [1] = 1,                       -- DBVersion
            [2] = 6,                       -- DBClock
            [3] = {                        -- Tables
                ["Users"] = {              -- First table
                    [1] = {                -- First row (valid)
                        [1] = {            -- Data
                            25,            -- age
                            "Bob"          -- name
                        },
                        [2] = 1,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                    [2] = {                -- Second row (invalid row structure)
                        0x123,
                    },
                    [3] = {                -- Third row (valid)
                        [1] = {            -- Data
                            30,            -- age
                            "Alice"        -- name
                        },
                        [2] = 3,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                    [4] = {                -- Fourth row (invalid data)
                        [1] = "invalid_data",
                        [2] = 4,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                    ["5"] = {              -- Fifth row (invalid key)
                        [1] = {            -- Data
                            28,            -- age
                            "Eve"          -- name
                        },
                        [2] = 5,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                    [6] = {                -- Sixth row (missing schema required field)
                        [1] = {            -- Data
                            -- age is missing
                            "Charlie"      -- name
                        },
                        [2] = 6,           -- Version clock
                        [3] = priv.peerId, -- Version peer
                    },
                }
            },
        }

        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.AreEqual(priv.databases[db].clock, 0)
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })

        Assert.ExpectErrors(function() LibP2PDB:ImportDatabase(db, state) end)

        local dbi = priv.databases[db]
        Assert.IsNonEmptyTable(dbi)
        Assert.AreEqual(dbi.clock, 6) -- State pretends 6 changes performed
        Assert.IsNonEmptyTable(dbi.tables)

        local ti = dbi.tables["Users"]
        Assert.IsNonEmptyTable(ti)

        local rows = ti.rows
        Assert.IsNonEmptyTable(rows)

        Assert.AreEqual(rows[1], {
            data = {
                name = "Bob",
                age = 25,
            },
            version = {
                clock = 1,
                peer = priv.peerId,
                tombstone = nil
            },
        })
        Assert.IsNil(rows[2])
        Assert.AreEqual(rows[3], {
            data = {
                name = "Alice",
                age = 30,
            },
            version = {
                clock = 3,
                peer = priv.peerId,
                tombstone = nil
            },
        })
        Assert.IsNil(rows[4])
        Assert.IsNil(rows[5])
        Assert.IsNil(rows[6])
    end,

    Migration = function()
        local state = nil
        do
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", version = 1 })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
            LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
            LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
            state = LibP2PDB:ExportDatabase(db)
        end
        do
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBImport",
                version = 2,
                onMigrateDB = function(target, source)
                    if source.version == 1 then
                        LibP2PDB:NewTable(source.db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                    end
                end,
                onMigrateTable = function(target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            return "Accounts"
                        end
                    end
                end,
                onMigrateRow = function(target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            local key = "user" .. source.key
                            local data = {
                                username = key,
                                name = source.data.name,
                                age = source.data.age,
                                email = nil,
                            }
                            return key, data
                        end
                    end
                end,
            })
            LibP2PDB:NewTable(db, { name = "Accounts", keyType = "string", schema = { username = "string", name = "string", age = "number", email = { "string", "nil" } } })
            LibP2PDB:ImportDatabase(db, state)

            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 3)
            Assert.IsNonEmptyTable(dbi.tables)
            Assert.IsNil(dbi.tables["Users"])

            local ti = dbi.tables["Accounts"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.rowCount, 3)

            local rows = ti.rows
            Assert.IsNonEmptyTable(rows)
            Assert.AreEqual(rows["user1"], {
                data = {
                    username = "user1",
                    name = "Bob",
                    age = 25,
                    email = nil,
                },
                version = {
                    clock = 1,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.AreEqual(rows["user2"], {
                data = {
                    username = "user2",
                    name = "Alice",
                    age = 30,
                    email = nil,
                },
                version = {
                    clock = 2,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.AreEqual(rows["user3"], {
                data = {
                    username = "user3",
                    name = "Eve",
                    age = 35,
                    email = nil,
                },
                version = {
                    clock = 3,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
        end
    end,

    Migration_SkipUnknownTables = function()
        local state = nil
        do
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", version = 1 })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
            LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
            LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
            state = LibP2PDB:ExportDatabase(db)
        end
        do
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBImport",
                version = 2,
                onMigrateTable = function(target, source)
                    LibP2PDB:NewTable(source.db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                end,
            })
            Assert.ExpectErrors(function() LibP2PDB:ImportDatabase(db, state) end)

            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 0)
            Assert.IsEmptyTable(dbi.tables)
            Assert.IsNil(dbi.tables["Users"])
        end
    end,

    Migration_SkipUnmigratedKeys = function()
        local state = nil
        do
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", version = 1 })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
            LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
            LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
            state = LibP2PDB:ExportDatabase(db)
        end
        do
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBImport",
                version = 2,
                onMigrateDB = function(target, source)
                    LibP2PDB:NewTable(source.db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                end,
                onMigrateTable = function(target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            return "Accounts"
                        end
                    end
                end,
            })
            LibP2PDB:NewTable(db, { name = "Accounts", keyType = "string", schema = { username = "string", name = "string", age = "number" } })
            Assert.ExpectErrors(function() LibP2PDB:ImportDatabase(db, state) end)

            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 0)
            Assert.IsNonEmptyTable(dbi.tables)

            local ti = dbi.tables["Accounts"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.rowCount, 0)

            local rows = ti.rows
            Assert.IsEmptyTable(rows)
        end
    end,

    Migration_SkipUnmigratedRows = function()
        local state = nil
        do
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", version = 1 })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
            LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
            LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
            state = LibP2PDB:ExportDatabase(db)
        end
        do
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBImport",
                version = 2,
                onMigrateDB = function(target, source)
                    LibP2PDB:NewTable(source.db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                end,
                onMigrateTable = function(target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            return "Accounts"
                        end
                    end
                end,
                onMigrateRow =function (target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            return "user" .. source.key, nil -- always return invalid data to skip all rows
                        end
                    end
                end
            })
            LibP2PDB:NewTable(db, { name = "Accounts", keyType = "string", schema = { username = "string", name = "string", age = "number" } })
            Assert.ExpectErrors(function() LibP2PDB:ImportDatabase(db, state) end)

            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 0)
            Assert.IsNonEmptyTable(dbi.tables)

            local ti = dbi.tables["Accounts"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.rowCount, 0)

            local rows = ti.rows
            Assert.IsEmptyTable(rows)
        end
    end,

    Migration_SkipInvalidRowData = function()
        local state = nil
        do
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", version = 1 })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
            LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
            LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
            state = LibP2PDB:ExportDatabase(db)
        end
        do
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBImport",
                version = 2,
                onMigrateDB = function(target, source)
                    LibP2PDB:NewTable(source.db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                end,
                onMigrateTable = function(target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            return "Accounts"
                        end
                    end
                end,
                onMigrateRow =function (target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            local key = "user" .. source.key
                            local data = {
                                --username = key, -- omit required field to make data invalid
                                name = source.data.name,
                                age = source.data.age,
                            }
                            return key, data
                        end
                    end
                end
            })
            LibP2PDB:NewTable(db, { name = "Accounts", keyType = "string", schema = { username = "string", name = "string", age = "number" } })
            Assert.ExpectErrors(function() LibP2PDB:ImportDatabase(db, state) end)

            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 0)
            Assert.IsNonEmptyTable(dbi.tables)

            local ti = dbi.tables["Accounts"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.rowCount, 0)

            local rows = ti.rows
            Assert.IsEmptyTable(rows)
        end
    end,

    Migration_SkipRowsThatFailValidation = function()
        local state = nil
        do
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests", version = 1 })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
            LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
            LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
            LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
            state = LibP2PDB:ExportDatabase(db)
        end
        do
            local db = LibP2PDB:NewDatabase({
                prefix = "LibP2PDBImport",
                version = 2,
                onMigrateDB = function(target, source)
                    LibP2PDB:NewTable(source.db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                end,
                onMigrateTable = function(target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            return "Accounts"
                        end
                    end
                end,
                onMigrateRow =function (target, source)
                    if source.version == 1 then
                        if source.tableName == "Users" then
                            local key = "user" .. source.key
                            local age = source.data.age
                            if source.data.name == "Alice" then
                                age = age + 200 -- make age invalid for validation
                            end
                            local data = {
                                username = key,
                                name = source.data.name,
                                age = age,
                            }
                            return key, data
                        end
                    end
                end
            })
            LibP2PDB:NewTable(db, {
                name = "Accounts",
                keyType = "string",
                schema = {
                    username = "string",
                    name = "string",
                    age = "number"
                },
                onValidate = function(key, data)
                    return data and data.age < 200
                end
            })
            LibP2PDB:ImportDatabase(db, state)

            local dbi = priv.databases[db]
            Assert.IsNonEmptyTable(dbi)
            Assert.AreEqual(dbi.clock, 3)
            Assert.IsNonEmptyTable(dbi.tables)
            Assert.IsNil(dbi.tables["Users"])

            local ti = dbi.tables["Accounts"]
            Assert.IsNonEmptyTable(ti)
            Assert.AreEqual(ti.rowCount, 2)

            local rows = ti.rows
            Assert.IsNonEmptyTable(rows)
            Assert.AreEqual(rows["user1"], {
                data = {
                    username = "user1",
                    name = "Bob",
                    age = 25,
                    email = nil,
                },
                version = {
                    clock = 1,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
            Assert.IsNil(rows["user2"])
            Assert.AreEqual(rows["user3"], {
                data = {
                    username = "user3",
                    name = "Eve",
                    age = 35,
                    email = nil,
                },
                version = {
                    clock = 3,
                    peer = priv.peerId,
                    tombstone = nil
                },
            })
        end
    end,

    ListTables = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number" })
        LibP2PDB:NewTable(db, { name = "Posts", keyType = "string" })
        local tables = LibP2PDB:ListTables(db)
        Assert.IsTable(tables)
        Assert.AreEqual(#tables, 2)
        Assert.IsTrue(tables[1] == "Users" or tables[1] == "Posts")
        Assert.IsTrue(tables[2] == "Users" or tables[2] == "Posts")
        Assert.AreNotEqual(tables[1], tables[2])
    end,

    ListTables_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:ListTables(nil) end)
        Assert.Throws(function() LibP2PDB:ListTables(123) end)
        Assert.Throws(function() LibP2PDB:ListTables("") end)
        Assert.Throws(function() LibP2PDB:ListTables({}) end)
    end,

    ListKeys = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
        LibP2PDB:InsertKey(db, "Users", 1, { name = "Bob", age = 25 })
        LibP2PDB:InsertKey(db, "Users", 2, { name = "Alice", age = 30 })
        LibP2PDB:InsertKey(db, "Users", 3, { name = "Eve", age = 35 })
        LibP2PDB:DeleteKey(db, "Users", 2)
        local keys = LibP2PDB:ListKeys(db, "Users")
        Assert.IsTable(keys)
        Assert.AreEqual(#keys, 2)
        Assert.IsTrue(keys[1] == 1 or keys[1] == 3)
        Assert.IsTrue(keys[2] == 1 or keys[2] == 3)
        Assert.AreNotEqual(keys[1], keys[2])
    end,

    ListKeys_DBIsInvalid_Throws = function()
        Assert.Throws(function() LibP2PDB:ListKeys(nil, "Users") end)
        Assert.Throws(function() LibP2PDB:ListKeys(123, "Users") end)
        Assert.Throws(function() LibP2PDB:ListKeys("", "Users") end)
        Assert.Throws(function() LibP2PDB:ListKeys({}, "Users") end)
    end,

    ListKeys_TableNameIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        Assert.Throws(function() LibP2PDB:ListKeys(db, nil) end)
        Assert.Throws(function() LibP2PDB:ListKeys(db, 123) end)
        Assert.Throws(function() LibP2PDB:ListKeys(db, {}) end)
    end,

    SerializeDeserialize = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testData = { a = "value", b = 42, c = true, d = nil, nested = { e = "nested", f = 100, g = false, h = nil } }
        local serialized = LibP2PDB:Serialize(db, testData)
        local deserialized = LibP2PDB:Deserialize(db, serialized)
        Assert.AreEqual(deserialized, testData)
    end,

    Serialize_DBIsInvalid_Throws = function()
        local testData = { a = "value", b = 42 }
        Assert.Throws(function() LibP2PDB:Serialize(nil, testData) end)
        Assert.Throws(function() LibP2PDB:Serialize(true, testData) end)
        Assert.Throws(function() LibP2PDB:Serialize(false, testData) end)
        Assert.Throws(function() LibP2PDB:Serialize("", testData) end)
        Assert.Throws(function() LibP2PDB:Serialize("invalid", testData) end)
        Assert.Throws(function() LibP2PDB:Serialize(123, testData) end)
        Assert.Throws(function() LibP2PDB:Serialize({}, testData) end)
    end,

    Deserialize_DBIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testData = { a = "value", b = 42 }
        local serialized = LibP2PDB:Serialize(db, testData)
        Assert.Throws(function() LibP2PDB:Deserialize(nil, serialized) end)
        Assert.Throws(function() LibP2PDB:Deserialize(true, serialized) end)
        Assert.Throws(function() LibP2PDB:Deserialize(false, serialized) end)
        Assert.Throws(function() LibP2PDB:Deserialize("", serialized) end)
        Assert.Throws(function() LibP2PDB:Deserialize("invalid", serialized) end)
        Assert.Throws(function() LibP2PDB:Deserialize(123, serialized) end)
        Assert.Throws(function() LibP2PDB:Deserialize({}, serialized) end)
    end,

    CompressDecompress = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testString = "This is a test string for compression."
        local compressed = LibP2PDB:Compress(db, testString)
        local decompressed = LibP2PDB:Decompress(db, compressed)
        Assert.AreEqual(decompressed, testString)
    end,

    Compress_DBIsInvalid_Throws = function()
        local testString = "This is a test string for compression."
        Assert.Throws(function() LibP2PDB:Compress(nil, testString) end)
        Assert.Throws(function() LibP2PDB:Compress(true, testString) end)
        Assert.Throws(function() LibP2PDB:Compress(false, testString) end)
        Assert.Throws(function() LibP2PDB:Compress("", testString) end)
        Assert.Throws(function() LibP2PDB:Compress("invalid", testString) end)
        Assert.Throws(function() LibP2PDB:Compress(123, testString) end)
        Assert.Throws(function() LibP2PDB:Compress({}, testString) end)
    end,

    Decompress_DBIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testString = "This is a test string for compression."
        local compressed = LibP2PDB:Compress(db, testString)
        Assert.Throws(function() LibP2PDB:Decompress(nil, compressed) end)
        Assert.Throws(function() LibP2PDB:Decompress(true, compressed) end)
        Assert.Throws(function() LibP2PDB:Decompress(false, compressed) end)
        Assert.Throws(function() LibP2PDB:Decompress("", compressed) end)
        Assert.Throws(function() LibP2PDB:Decompress("invalid", compressed) end)
        Assert.Throws(function() LibP2PDB:Decompress(123, compressed) end)
        Assert.Throws(function() LibP2PDB:Decompress({}, compressed) end)
    end,

    EncodeDecodeForChannel = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testString = "This is a test string for channel encoding."
        local encoded = LibP2PDB:EncodeForChannel(db, testString)
        local decoded = LibP2PDB:DecodeFromChannel(db, encoded)
        Assert.AreEqual(decoded, testString)
    end,

    EncodeForChannel_DBIsInvalid_Throws = function()
        local testString = "This is a test string for channel encoding."
        Assert.Throws(function() LibP2PDB:EncodeForChannel(nil, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForChannel(true, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForChannel(false, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForChannel("", testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForChannel("invalid", testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForChannel(123, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForChannel({}, testString) end)
    end,

    DecodeFromChannel_DBIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testString = "This is a test string for channel encoding."
        local encoded = LibP2PDB:EncodeForChannel(db, testString)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel(nil, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel(true, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel(false, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel("", encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel("invalid", encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel(123, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromChannel({}, encoded) end)
    end,

    EncodeDecodeForPrint = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testString = "This is a test string for print encoding."
        local encoded = LibP2PDB:EncodeForPrint(db, testString)
        local decoded = LibP2PDB:DecodeFromPrint(db, encoded)
        Assert.AreEqual(decoded, testString)
    end,

    EncodeForPrint_DBIsInvalid_Throws = function()
        local testString = "This is a test string for print encoding."
        Assert.Throws(function() LibP2PDB:EncodeForPrint(nil, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForPrint(true, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForPrint(false, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForPrint("", testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForPrint("invalid", testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForPrint(123, testString) end)
        Assert.Throws(function() LibP2PDB:EncodeForPrint({}, testString) end)
    end,

    DecodeFromPrint_DBIsInvalid_Throws = function()
        local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
        local testString = "This is a test string for print encoding."
        local encoded = LibP2PDB:EncodeForPrint(db, testString)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint(nil, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint(true, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint(false, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint("", encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint("invalid", encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint(123, encoded) end)
        Assert.Throws(function() LibP2PDB:DecodeFromPrint({}, encoded) end)
    end,
}

--- Fake communication channels to simulate message passing between private instances.
--- @type table<string, table<string, function>>
local testChannels = {
    GUILD = {},
    RAID = {},
    PARTY = {},
    YELL = {},
    WHISPER = {},
}

--- Simulates ticking multiple private instances, processing their outgoing messages and OnUpdate handlers.
--- @param instances table[] Array of private instances to tick.
local function TickPrivateInstances(instances)
    local orderedChannels = { "GUILD", "RAID", "PARTY", "YELL", "WHISPER" }

    -- Process messages until there are no more to process
    local moreMessagesToProcess = true
    while moreMessagesToProcess do
        -- Take a copy of outgoing messages to process, since processing may generate new messages
        local messages = DeepCopy(testChannels)
        for channel in pairs(testChannels) do
            testChannels[channel] = {}
        end

        -- Process outgoing messages from each instance
        for _, channel in ipairs(orderedChannels) do
            for _, instance in ipairs(instances) do
                for _, msg in ipairs(messages[channel] or {}) do
                    if channel ~= "WHISPER" or msg.target == instance.playerName then
                        PrivateScope(instance, function() instance:OnCommReceived(msg.prefix, msg.text, msg.distribution, msg.sender) end)
                    end
                end
            end
        end

        -- Process OnUpdate for each instance
        for _, instance in ipairs(instances) do
            if instance.frame then
                local onUpdateHandler = instance.frame:GetScript("OnUpdate")
                if onUpdateHandler then
                    onUpdateHandler(instance.frame)
                end
            end
        end

        -- Check if there are more messages to process
        moreMessagesToProcess = false
        for _, channel in ipairs(orderedChannels) do
            if #testChannels[channel] > 0 then
                moreMessagesToProcess = true
                break
            end
        end
    end
end

local numPeers = 8
local numRounds = ceil(log(numPeers + 1) / log(2))

local NetworkTests = {
    DiscoverPeers = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                return LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            end)
        end

        -- This is expected to make peer 1 discover all other peers, while others discover only peer 1
        VerbosityScope(3, function()
            PrivateScope(instances[1], function() LibP2PDB:DiscoverPeers(databases[1]) end)
            TickPrivateInstances(instances)
        end)

        -- Check that peer 1 knows about all other peers
        for i = 2, numPeers do
            local db = databases[1]
            local dbi = instances[1].databases[db]
            Assert.ContainsKey(dbi.peers, instances[i].peerId)
            Assert.AreEqual(dbi.peers[instances[i].peerId].name, "Player" .. i)
        end

        -- Check that other peers know only about peer 1
        for i = 2, numPeers do
            local db = databases[i]
            local dbi = instances[i].databases[db]
            Assert.ContainsKey(dbi.peers, instances[1].peerId)
            Assert.AreEqual(dbi.peers[instances[1].peerId].name, "Player1")
            for j = 2, numPeers do
                if i ~= j then
                    Assert.IsNil(dbi.peers[instances[j].peerId])
                end
            end
        end
    end,

    DiscoverPeers_DBIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            Assert.Throws(function() LibP2PDB:DiscoverPeers(nil) end)
            Assert.Throws(function() LibP2PDB:DiscoverPeers(true) end)
            Assert.Throws(function() LibP2PDB:DiscoverPeers(false) end)
            Assert.Throws(function() LibP2PDB:DiscoverPeers("") end)
            Assert.Throws(function() LibP2PDB:DiscoverPeers("invalid") end)
            Assert.Throws(function() LibP2PDB:DiscoverPeers(123) end)
            Assert.Throws(function() LibP2PDB:DiscoverPeers({}) end)
        end)
    end,

    SyncDatabase = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make all peers sync their databases
        VerbosityScope(3, function()
            for r = 1, numRounds do
                for i = 1, numPeers do
                    PrivateScope(instances[i], function() LibP2PDB:SyncDatabase(databases[i]) end)
                end
                TickPrivateInstances(instances)
            end
        end)

        -- Check that all peers have all data
        for i = 1, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                --Debug("Peer " .. i .. " has keys: " .. table.concat(keys, ", "))
                for j = 1, numPeers do
                    Assert.AreEqual(#keys, numPeers)
                    Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", j), { name = "Player" .. j, age = 20 + j })
                end
            end)
        end
    end,

    SyncDatabase_DBIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            Assert.Throws(function() LibP2PDB:SyncDatabase(nil) end)
            Assert.Throws(function() LibP2PDB:SyncDatabase(true) end)
            Assert.Throws(function() LibP2PDB:SyncDatabase(false) end)
            Assert.Throws(function() LibP2PDB:SyncDatabase("") end)
            Assert.Throws(function() LibP2PDB:SyncDatabase("invalid") end)
            Assert.Throws(function() LibP2PDB:SyncDatabase(123) end)
            Assert.Throws(function() LibP2PDB:SyncDatabase({}) end)
        end)
    end,

    RequestKey = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make peer 1 request a key from all other peers
        VerbosityScope(3, function()
            PrivateScope(instances[1], function()
                for i = 2, numPeers do
                    LibP2PDB:RequestKey(databases[1], "Users", i, "Player" .. i)
                end
            end)
            TickPrivateInstances(instances)
        end)

        -- Check that peer 1 has all the requested data
        PrivateScope(instances[1], function()
            local keys = LibP2PDB:ListKeys(databases[1], "Users")
            Assert.AreEqual(#keys, numPeers)
            for i = 1, numPeers do
                Assert.AreEqual(LibP2PDB:GetKey(databases[1], "Users", keys[i]), { name = "Player" .. i, age = 20 + i })
            end
        end)

        -- Check that other peers did not receive any data they did not already have
        for i = 2, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                Assert.AreEqual(#keys, 1)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", keys[1]), { name = "Player" .. i, age = 20 + i })
            end)
        end
    end,

    RequestKey_FromAnyTables = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:NewTable(db, { name = "Scores", keyType = "number", schema = { score = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                LibP2PDB:InsertKey(db, "Scores", i, { score = i * 10 })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make peer 1 request a key from all other peers, without specifying table name
        VerbosityScope(3, function()
            PrivateScope(instances[1], function()
                for i = 2, numPeers do
                    LibP2PDB:RequestKey(databases[1], nil, i, "Player" .. i)
                end
            end)
            TickPrivateInstances(instances)
        end)

        -- Check that peer 1 has all the requested data
        PrivateScope(instances[1], function()
            local keys = LibP2PDB:ListKeys(databases[1], "Users")
            Assert.AreEqual(#keys, numPeers)
            for i = 1, numPeers do
                Assert.AreEqual(LibP2PDB:GetKey(databases[1], "Users", keys[i]), { name = "Player" .. i, age = 20 + i })
            end
            keys = LibP2PDB:ListKeys(databases[1], "Scores")
            Assert.AreEqual(#keys, numPeers)
            for i = 1, numPeers do
                Assert.AreEqual(LibP2PDB:GetKey(databases[1], "Scores", keys[i]), { score = i * 10 })
            end
        end)

        -- Check that other peers did not receive any data they did not already have
        for i = 2, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                Assert.AreEqual(#keys, 1)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", keys[1]), { name = "Player" .. i, age = 20 + i })
                keys = LibP2PDB:ListKeys(databases[i], "Scores")
                Assert.AreEqual(#keys, 1)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Scores", keys[1]), { score = i * 10 })
            end)
        end
    end,

    RequestKey_DBIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            Assert.Throws(function() LibP2PDB:RequestKey(nil, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(true, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(false, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey("", "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey("invalid", "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(123, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey({}, "Users", 1, "Player1") end)
        end)
    end,

    RequestKey_TableNameIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            Assert.Throws(function() LibP2PDB:RequestKey(db, true, 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, false, 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "invalid", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, 123, 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, {}, 1, "Player1") end)
        end)
    end,

    RequestKey_KeyIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { name = "string", age = "number" } })
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", nil, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", true, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", false, "Player1") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", {}, "Player1") end)
        end)
    end,

    RequestKey_TargetIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { name = "string", age = "number" } })
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", nil) end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", true) end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", false) end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", "") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", "ThisTargetNameIsTooLong") end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", 123) end)
            Assert.Throws(function() LibP2PDB:RequestKey(db, "Users", "key1", {}) end)
        end)
    end,

    SendKey = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make peer 1 send a key to all other peers
        VerbosityScope(3, function()
            PrivateScope(instances[1], function()
                for i = 2, numPeers do
                    LibP2PDB:SendKey(databases[1], "Users", 1, "Player" .. i)
                end
            end)
            TickPrivateInstances(instances)
        end)

        -- Check that all other peers have received data, and nothing else
        for i = 2, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                Assert.AreEqual(#keys, 2)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", 1), { name = "Player1", age = 21 })
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", i), { name = "Player" .. i, age = 20 + i })
            end)
        end
    end,

    SendKey_FromAnyTables = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:NewTable(db, { name = "Scores", keyType = "number", schema = { score = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                LibP2PDB:InsertKey(db, "Scores", i, { score = i * 10 })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make peer 1 send a key to all other peers, without specifying table name
        VerbosityScope(3, function()
            PrivateScope(instances[1], function()
                for i = 2, numPeers do
                    LibP2PDB:SendKey(databases[1], nil, 1, "Player" .. i)
                end
            end)
            TickPrivateInstances(instances)
        end)

        -- Check that all other peers have received data, and nothing else
        for i = 2, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                Assert.AreEqual(#keys, 2)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", 1), { name = "Player1", age = 21 })
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", i), { name = "Player" .. i, age = 20 + i })
                keys = LibP2PDB:ListKeys(databases[i], "Scores")
                Assert.AreEqual(#keys, 2)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Scores", 1), { score = 10 })
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Scores", i), { score = i * 10 })
            end)
        end
    end,

    SendKey_DBIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            Assert.Throws(function() LibP2PDB:SendKey(nil, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(true, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(false, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey("", "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey("invalid", "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(123, "Users", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey({}, "Users", 1, "Player1") end)
        end)
    end,

    SendKey_TableNameIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            Assert.Throws(function() LibP2PDB:SendKey(db, true, 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, false, 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "", 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, 123, 1, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, {}, 1, "Player1") end)
        end)
    end,

    SendKey_KeyIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { name = "string", age = "number" } })
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", nil, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", true, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", false, "Player1") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", {}, "Player1") end)
        end)
    end,

    SendKey_TargetIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { name = "string", age = "number" } })
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", nil) end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", true) end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", false) end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", "") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", "ThisTargetNameIsTooLong") end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", 123) end)
            Assert.Throws(function() LibP2PDB:SendKey(db, "Users", "key1", {}) end)
        end)
    end,

    BroadcastKey = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make peer 1 broadcast a key to all other peers
        VerbosityScope(3, function()
            PrivateScope(instances[1], function()
                LibP2PDB:BroadcastKey(databases[1], "Users", 1)
            end)
            TickPrivateInstances(instances)
        end)

        -- Check that all other peers have received data, and nothing else
        for i = 2, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                Assert.AreEqual(#keys, 2)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", 1), { name = "Player1", age = 21 })
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", i), { name = "Player" .. i, age = 20 + i })
            end)
        end
    end,

    BroadcastKey_FromAnyTables = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Users", keyType = "number", schema = { name = "string", age = "number" } })
                LibP2PDB:NewTable(db, { name = "Scores", keyType = "number", schema = { score = "number" } })
                LibP2PDB:InsertKey(db, "Users", i, { name = "Player" .. i, age = 20 + i })
                LibP2PDB:InsertKey(db, "Scores", i, { score = i * 10 })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Make peer 1 broadcast a key to all other peers, without specifying table name
        VerbosityScope(3, function()
            PrivateScope(instances[1], function()
                LibP2PDB:BroadcastKey(databases[1], nil, 1)
            end)
            TickPrivateInstances(instances)
        end)

        -- Check that all other peers have received data, and nothing else
        for i = 2, numPeers do
            PrivateScope(instances[i], function()
                local keys = LibP2PDB:ListKeys(databases[i], "Users")
                Assert.AreEqual(#keys, 2)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", 1), { name = "Player1", age = 21 })
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Users", i), { name = "Player" .. i, age = 20 + i })
                keys = LibP2PDB:ListKeys(databases[i], "Scores")
                Assert.AreEqual(#keys, 2)
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Scores", 1), { score = 10 })
                Assert.AreEqual(LibP2PDB:GetKey(databases[i], "Scores", i), { score = i * 10 })
            end)
        end
    end,

    BroadcastKey_DBIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            Assert.Throws(function() LibP2PDB:BroadcastKey(nil, "Users", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(true, "Users", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(false, "Users", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey("", "Users", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey("invalid", "Users", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(123, "Users", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey({}, "Users", 1) end)
        end)
    end,

    BroadcastKey_TableNameIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, true, 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, false, 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, "", 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, 123, 1) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, {}, 1) end)
        end)
    end,

    BroadcastKey_KeyIsInvalid_Throws = function()
        local instance = NewPrivateInstance(1)
        PrivateScope(instance, function()
            local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
            LibP2PDB:NewTable(db, { name = "Users", keyType = "string", schema = { name = "string", age = "number" } })
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, "Users", nil) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, "Users", true) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, "Users", false) end)
            Assert.Throws(function() LibP2PDB:BroadcastKey(db, "Users", {}) end)
        end)
    end,

    Propagation = function()
        local instances = {}
        local databases = {}
        for i = 1, numPeers do
            instances[i] = NewPrivateInstance(i)
            databases[i] = PrivateScope(instances[i], function()
                local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
                LibP2PDB:NewTable(db, { name = "Values", keyType = "number", schema = { value = "number" } })
                return db
            end)
        end

        -- Make all peers discover each other
        VerbosityScope(3, function()
            for i = 1, numPeers do
                PrivateScope(instances[i], function() LibP2PDB:DiscoverPeers(databases[i]) end)
            end
            TickPrivateInstances(instances)
        end)

        -- Check neighborhood connectivity
        local peers = {}
        for i = 1, numPeers do
            PrivateScope(instances[i], function()
                local db = databases[i]
                local dbi = priv.databases[db]
                Assert.IsNonEmptyTable(dbi.peers)
                Assert.IsNonEmptyTable(dbi.peersSorted)
                local neighbors = instances[i]:GetNeighbors(dbi)
                for neighborId in pairs(neighbors) do
                    peers[neighborId] = true
                end
            end)
        end
        for i = 1, numPeers do
            Assert.ContainsKey(peers, instances[i].peerId, "All peers should be reachable through neighborhood connections")
        end

        -- Add one key to the first peer
        PrivateScope(instances[1], function()
            LibP2PDB:InsertKey(databases[1], "Values", 1, { value = 42 })
        end)

        -- Tick all peers until all have received the key
        local allReceived = false
        local maxTicks = numPeers
        local tickCount = 0
        VerbosityScope(3, function()
            while not allReceived and tickCount < maxTicks do
                for i = 1, numPeers do
                    PrivateScope(instances[i], function() LibP2PDB:SyncDatabase(databases[i]) end)
                end
                TickPrivateInstances(instances)
                tickCount = tickCount + 1

                allReceived = true
                for i = 1, numPeers do
                    local hasKey = PrivateScope(instances[i], function() return LibP2PDB:HasKey(databases[i], "Values", 1) end)
                    if not hasKey then
                        allReceived = false
                        break
                    end
                end
            end
        end)
        Assert.IsTrue(allReceived, "All peers should have received the key within the maximum tick limit")
        Assert.IsLessThanOrEqual(tickCount, numRounds)
    end,
}
--- @diagnostic enable: param-type-mismatch, assign-type-mismatch, missing-fields

local profilingMarkers = {}

local function ProfileBegin(markerName)
    local marker = profilingMarkers[markerName]
    if not marker then
        marker = { startTime = 0, samples = {} }
        profilingMarkers[markerName] = marker
    end
    marker.startTime = debugprofilestop()
end

local function ProfileEnd(markerName)
    local now = debugprofilestop()
    local marker = profilingMarkers[markerName]
    if marker then
        if marker.startTime > 0 and now > marker.startTime then
            tinsert(marker.samples, now - marker.startTime)
        end
        marker.startTime = 0
    end
end

local function ProfileReset(markerName)
    profilingMarkers[markerName] = nil
end

local function PrintProfileMarker(markerName, testName)
    local marker = profilingMarkers[markerName]
    if marker then
        local total = 0
        for _, sample in ipairs(marker.samples) do
            total = total + sample
        end
        tsort(marker.samples)
        local count = #marker.samples
        local average = count > 0 and (total / count) or 0
        local median = marker.samples[math.floor((count + 1) / 2)] or 0
        local min = marker.samples[1] or 0
        local max = marker.samples[count] or 0
        Print("[%s] median=%s avg=%s min=%s max=%s total=%s samples=%d", C(Color.Magenta, testName), FormatTime(median), FormatTime(average), FormatTime(min), FormatTime(max), FormatTime(total), count)
        profilingMarkers[markerName] = nil
    else
        Print("No profiling data for marker: %s", markerName)
    end
end

local function GenerateDatabase(numRows)
    ProfileBegin("LibP2PDB:NewDatabase")
    local db = LibP2PDB:NewDatabase({ prefix = "LibP2PDBTests" })
    ProfileEnd("LibP2PDB:NewDatabase")
    ProfileBegin("LibP2PDB:NewTable")
    LibP2PDB:NewTable(db, {
        name = "Players",
        keyType = "string",
        schema = {
            name = "string",             -- 2 to 12 characters
            realm = { "string", "nil" }, -- 6 to 20 characters
            classID = "number",          -- 1 to 12
            guild = { "string", "nil" }, -- 2 to 24 characters
            version = "string",          -- semantic versioning e.g., "1.0.0"
            level = "number",            -- 1 to 60
            xpTotal = "number",          -- 0 to 3,379,400 xp
            money = "number",            -- 0 to 2,147,483,647 coppers
            timePlayed = "number",       -- 0 to 2,147,483,647 seconds
        }
    })
    ProfileEnd("LibP2PDB:NewTable")
    for i = 1, numRows do
        local key = GenerateKey(i)
        local data = GenerateData(i)
        ProfileBegin("LibP2PDB:InsertKey")
        LibP2PDB:InsertKey(db, "Players", key, data)
        ProfileEnd("LibP2PDB:InsertKey")
    end
    return db
end

local sampleCount = 1024

local PerformanceTests = {
    InsertKey = function()
        ProfileReset("LibP2PDB:InsertKey")
        GenerateDatabase(sampleCount)
        PrintProfileMarker("LibP2PDB:InsertKey", "InsertKey")
    end,

    SetKey = function()
        local db = GenerateDatabase(sampleCount)
        ProfileReset("LibP2PDB:SetKey")
        for i = 1, sampleCount do
            local key = GenerateKey(i)
            local data = LibP2PDB:GetKey(db, "Players", key)
            ProfileBegin("LibP2PDB:SetKey") --- @diagnostic disable-next-line: param-type-mismatch
            LibP2PDB:SetKey(db, "Players", key, data)
            ProfileEnd("LibP2PDB:SetKey")
        end
        PrintProfileMarker("LibP2PDB:SetKey", "SetKey NoChanges")

        ProfileReset("LibP2PDB:SetKey")
        for i = 1, sampleCount do
            local key = GenerateKey(i)
            local data = GenerateData(i + sampleCount)
            ProfileBegin("LibP2PDB:SetKey")
            LibP2PDB:SetKey(db, "Players", key, data)
            ProfileEnd("LibP2PDB:SetKey")
        end
        PrintProfileMarker("LibP2PDB:SetKey", "SetKey Changes")

        for i = 1, sampleCount do
            local key = GenerateKey(i)
            LibP2PDB:DeleteKey(db, "Players", key)
        end
        ProfileReset("LibP2PDB:SetKey")
        for i = 1, sampleCount do
            local key = GenerateKey(i)
            local data = GenerateData(i)
            ProfileBegin("LibP2PDB:SetKey")
            LibP2PDB:SetKey(db, "Players", key, data)
            ProfileEnd("LibP2PDB:SetKey")
        end
        PrintProfileMarker("LibP2PDB:SetKey", "SetKey Deleted")
    end,

    ExportImportDatabase = function()
        local db = GenerateDatabase(sampleCount)

        ProfileReset("LibP2PDB:ExportDatabase")
        ProfileBegin("LibP2PDB:ExportDatabase")
        local state = LibP2PDB:ExportDatabase(db)
        ProfileEnd("LibP2PDB:ExportDatabase")
        PrintProfileMarker("LibP2PDB:ExportDatabase", "ExportDatabase")

        ProfileReset("LibP2PDB:ImportDatabase")
        ProfileBegin("LibP2PDB:ImportDatabase")
        --- @cast state LibP2PDB.DBState
        LibP2PDB:ImportDatabase(db, state)
        ProfileEnd("LibP2PDB:ImportDatabase")
        PrintProfileMarker("LibP2PDB:ImportDatabase", "ImportDatabase")

        local serialized = LibP2PDB:Serialize(db, state)
        Print("Database (%d rows) serialized: %s (%s)", sampleCount, FormatSize(#serialized), FormatSize(#serialized / sampleCount, true))
        local compressed = LibP2PDB:Compress(db, serialized)
        Print("Database (%d rows) compressed: %s (%s)", sampleCount, FormatSize(#compressed), FormatSize(#compressed / sampleCount, true))
        local encodedForChannel = LibP2PDB:EncodeForChannel(db, compressed)
        Print("Database (%d rows) encoded for channel: %s (%s)", sampleCount, FormatSize(#encodedForChannel), FormatSize(#encodedForChannel / sampleCount, true))
        local encodedForPrint = LibP2PDB:EncodeForPrint(db, compressed)
        Print("Database (%d rows) encoded for print: %s (%s)", sampleCount, FormatSize(#encodedForPrint), FormatSize(#encodedForPrint / sampleCount, true))
    end,
}

local GREEN_CHECKMARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t"

local function RunTests()
    Print("Running LibP2PDB tests...")

    -- Run unit tests
    local count = 0
    local startTime = debugprofilestop()
    for _, testFn in pairs(UnitTests) do
        PrivateScope(NewPrivateInstance(1), testFn)
        count = count + 1
    end

    -- Run network tests
    for _, testFn in pairs(NetworkTests) do
        -- Override C_Timer.NewTimer to call the callback immediately
        local _NewTimer = C_Timer.NewTimer
        ---@diagnostic disable-next-line: duplicate-set-field
        C_Timer.NewTimer = function(delay, callback)
            ---@diagnostic disable-next-line: missing-parameter
            callback()
            return nil
        end

        -- Override C_ChatInfo.IsAddonMessagePrefixRegistered to check our fake registered prefixes
        local _IsAddonMessagePrefixRegistered = C_ChatInfo.IsAddonMessagePrefixRegistered
        ---@diagnostic disable-next-line: duplicate-set-field
        C_ChatInfo.IsAddonMessagePrefixRegistered = function(prefix)
            return priv.registeredPrefixes and priv.registeredPrefixes[prefix] ~= nil
        end

        -- Override AceComm with fake implementation
        local _AceComm = AceComm
        AceComm = {
            RegisterComm = function(self, prefix)
                self.registeredPrefixes = self.registeredPrefixes or {}
                self.registeredPrefixes[prefix] = true
            end,
            SendCommMessage = function(self, prefix, text, distribution, target, prio)
                assert(self.registeredPrefixes and self.registeredPrefixes[prefix], "Prefix not registered: " .. tostring(prefix))
                tinsert(testChannels[distribution], {
                    prefix = prefix,
                    text = text,
                    distribution = distribution,
                    sender = priv.playerName,
                    target = target,
                    prio = prio,
                })
            end,
        }

        -- Run the test
        testFn()

        -- Restore overridden functions
        AceComm = _AceComm
        C_ChatInfo.IsAddonMessagePrefixRegistered = _IsAddonMessagePrefixRegistered
        C_Timer.NewTimer = _NewTimer
        count = count + 1
    end

    local endTime = debugprofilestop()
    Print("%sAll %d tests passed in %.2f ms.", GREEN_CHECKMARK, count, endTime - startTime)
end

local function RunPerformanceTests()
    Print("Running LibP2PDB performance tests...")
    local count = 0
    local startTime = debugprofilestop()
    for _, testFn in pairs(PerformanceTests) do
        PrivateScope(NewPrivateInstance(1), testFn)
        count = count + 1
    end
    local endTime = debugprofilestop()
    Print("%sAll %d performance tests completed in %.2f ms.", GREEN_CHECKMARK, count, endTime - startTime)
end

-- Register slash commands
SLASH_LIBP2PDB1 = "/libp2pdb"
SlashCmdList["LIBP2PDB"] = function(arg)
    if arg == "runtests" then
        RunTests()
    elseif arg == "runperftests" then
        RunPerformanceTests()
    else
        Print("LibP2PDB Slash Commands:")
        Print("  /libp2pdb runtests - Run all unit tests.")
        Print("  /libp2pdb runperftests - Run all performance tests.")
    end
end

]] --
