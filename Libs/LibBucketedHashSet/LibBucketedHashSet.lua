-- MIT License
--
-- Copyright (c) 2026 Erunehtar
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--
-- Bucketed Hash Set implementation for WoW Lua 5.1 environment.
-- Based on: "Partitioned Bucket Hashing for Efficient Anti‑Entropy"
--
-- Bucketed hash set is used for divergence detection as an alternative to Merkle trees.
-- It is essentially a partitioned anti‑entropy structure. Each bucket holds a combined
-- hash of all inserted values, allowing for efficient divergence detection.

local MAJOR, MINOR = "LibBucketedHashSet", 4
assert(LibStub, MAJOR .. " requires LibStub")

--- @class LibBucketedHashSet A bucketed hash set implementation for efficient divergence detection.
--- @field seed integer The seed used for hashing, which can be set to create different hash sets with the same values.
--- @field numBuckets integer The number of buckets in the hash set, which determines the granularity of divergence detection.
--- @field buckets integer[] An array of integers representing the combined hash values for each bucket.
local LibBucketedHashSet = LibStub:NewLibrary(MAJOR, MINOR)
if not LibBucketedHashSet then return end -- no upgrade needed

LibBucketedHashSet.__index = LibBucketedHashSet

-- Local lua references
local tostring = tostring
local bxor = bit.bxor
local rshift = bit.rshift
local strbyte = string.byte
local assert = assert
local type = type
local setmetatable = setmetatable
local rawequal = rawequal
local select = select

-- Constants
local UINT32_MODULO = 2 ^ 32
local UINT32_MAX = 0xFFFFFFFF
local DEFAULT_SEED = 0

--- FNV-1a hash function (32-bit)
--- @param value string Input string to hash.
--- @param seed integer Seed value.
--- @return integer hash 32-bit hash value.
local function FNV1a32(value, seed)
    local str = tostring(value)
    local len = #str
    local hash = 2166136261 + seed * 13
    for i = 1, len do
        hash = bxor(hash, strbyte(str, i))
        hash = (hash * 16777619) % UINT32_MODULO
    end
    return hash
end

--- Creates a new bucket hash set instance.
--- @param numBuckets integer Number of buckets to use.
--- @param seed integer? Seed for the hashing function (default: 0).
--- @return LibBucketedHashSet instance The new bucket hash set instance.
function LibBucketedHashSet.New(numBuckets, seed)
    assert(numBuckets > 0, "numBuckets must be greater than 0")
    assert(numBuckets % 1 == 0, "numBuckets must be an integer")
    seed = seed or DEFAULT_SEED
    assert(type(seed) == "number", "seed must be a number")
    assert(seed % 1 == 0, "seed must be an integer")

    local buckets = {}
    for i = 1, numBuckets do
        buckets[i] = 0
    end

    return setmetatable({
        seed = seed,
        numBuckets = numBuckets,
        buckets = buckets,
    }, LibBucketedHashSet)
end

--- Updates a value in the bucket hash set.
--- Calling this function twice with the same value will remove it from the set.
--- Only the first value is used to determine the bucket index, but additional values can be included in the hash.
--- @param value any The value to update.
--- @param ... any Additional values to include in the hash (optional).
--- @return integer bucketIndex The index of the bucket where the hash was updated.
function LibBucketedHashSet:Update(value, ...)
    local hash = FNV1a32(value, self.seed)
    local bucketIndex = (rshift(hash, 16) % self.numBuckets) + 1
    local numArgs = select("#", ...)
    if numArgs > 0 then
        local args = { ... }
        for i = 1, numArgs do
            local argHash = FNV1a32(args[i], self.seed)
            hash = bxor(hash, argHash) % UINT32_MODULO
        end
    end
    self.buckets[bucketIndex] = bxor(self.buckets[bucketIndex], hash) % UINT32_MODULO
    return bucketIndex
end

--- Clears all entries in the bucket hash set.
function LibBucketedHashSet:Clear()
    for i = 1, self.numBuckets do
        self.buckets[i] = 0
    end
end

--- @class LibBucketedHashSet.State The exported state of a bucket hash set, which can be used for serialization or transmission.
--- @field [1] integer The seed used for hashing.
--- @field [2] integer The number of buckets in the hash set.
--- @field [3] integer[] An array of integers representing the combined hash values for each bucket.

--- Exports the current state of the bucket hash set.
--- @return LibBucketedHashSet.State state The exported state.
function LibBucketedHashSet:Export()
    return {
        self.seed,
        self.numBuckets,
        self.buckets,
    }
end

--- Imports a new bucket hash set from an exported state.
--- @param state LibBucketedHashSet.State The bucket hash set state to import.
--- @return LibBucketedHashSet instance The imported bucket hash set instance.
function LibBucketedHashSet.Import(state)
    assert(type(state) == "table", "state must be a table")
    local seed = state[1]
    local numBuckets = state[2]
    local buckets = state[3]

    assert(type(seed) == "number", "seed in state must be a number")
    assert(seed % 1 == 0, "seed in state must be an integer")
    assert(numBuckets > 0, "numBuckets in state must be greater than 0")
    assert(numBuckets % 1 == 0, "numBuckets in state must be an integer")
    assert(type(buckets) == "table", "buckets in state must be a table")
    assert(#buckets == numBuckets, "buckets length does not match numBuckets in state")

    return setmetatable({
        seed = seed,
        numBuckets = numBuckets,
        buckets = buckets,
    }, LibBucketedHashSet)
end

--- Compare two bucketed hash sets for equality.
--- @param a LibBucketedHashSet The first bucket hash set.
--- @param b LibBucketedHashSet The second bucket hash set.
--- @return boolean equal True if the two bucket hash sets are equal, false otherwise.
LibBucketedHashSet.__eq = function(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if rawequal(a, b) then
        return true
    end
    if a.seed ~= b.seed then
        return false
    end
    if a.numBuckets ~= b.numBuckets then
        return false
    end
    for i = 1, a.numBuckets do
        if a.buckets[i] ~= b.buckets[i] then
            return false
        end
    end
    return true
end

--[[ Uncomment to run tests when loading this file

local function RunLibBucketedHashSetTests()
    print("=== LibBucketedHashSet Tests ===")

    do
        -- Test 1: Basic creation
        local set = LibBucketedHashSet.New(4)
        assert(set.numBuckets == 4, "Test 1 Failed: numBuckets should be 4")
        assert(set.seed == 0, "Test 1 Failed: default seed should be 0")
        for i = 1, set.numBuckets do
            assert(set.buckets[i] == 0, "Test 1 Failed: all buckets should be initialized to 0")
        end
        print("Test 1 PASSED: Basic creation")
    end

    do
        -- Test 2: Invalid numBuckets raises error
        --- @diagnostic disable: param-type-mismatch
        assert(not pcall(function() LibBucketedHashSet.New(nil) end), "Test 2 Failed: numBuckets of nil should raise error")
        assert(not pcall(function() LibBucketedHashSet.New(0) end), "Test 2 Failed: numBuckets of 0 should raise error")
        assert(not pcall(function() LibBucketedHashSet.New(-5) end), "Test 2 Failed: negative numBuckets should raise error")
        assert(not pcall(function() LibBucketedHashSet.New("four") end), "Test 2 Failed: non-number numBuckets should raise error")
        assert(not pcall(function() LibBucketedHashSet.New({}) end), "Test 2 Failed: non-number numBuckets should raise error")
        assert(not pcall(function() LibBucketedHashSet.New(3.5) end), "Test 2 Failed: non-integer numBuckets should raise error")
        --- @diagnostic enable: param-type-mismatch
        print("Test 2 PASSED: Invalid numBuckets raises error")
    end

    do
        -- Test 3: Invalid seed raises error
        --- @diagnostic disable: param-type-mismatch
        assert(not pcall(function() LibBucketedHashSet.New(4, "seed") end), "Test 3 Failed: non-number seed should raise error")
        assert(not pcall(function() LibBucketedHashSet.New(4, {}) end), "Test 3 Failed: non-number seed should raise error")
        assert(not pcall(function() LibBucketedHashSet.New(4, 3.5) end), "Test 3 Failed: non-integer seed should raise error")
        --- @diagnostic enable: param-type-mismatch
        print("Test 3 PASSED: Invalid seed raises error")
    end

    do
        -- Test 4: Identical sets remain identical
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        setA:Update("foo", 123)
        setB:Update("foo", 123)
        assert(setA == setB, "Test 4 Failed: Sets should be identical after same insert")
        print("Test 4 PASSED: Identical sets after same insert")
    end

    do
        -- Test 5: Divergence after different insert
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        setA:Update("foo", 123)
        setB:Update("foo", 123)
        setB:Update("bar", 456)
        assert(setA ~= setB, "Test 5 Failed: Sets should diverge after different insert")
        print("Test 5 PASSED: Sets diverge after different insert")
    end

    do
        -- Test 6: Convergence after same inserts in any order
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        setA:Update("baz", 789)
        setA:Update("foo", 123)
        setA:Update("bar", 456)
        setB:Update("bar", 456)
        setB:Update("foo", 123)
        setB:Update("baz", 789)
        assert(setA == setB, "Test 6 Failed: Sets should be identical after same inserts in any order")
        print("Test 6 PASSED: Sets converge after same sequence")
    end

    do
        -- Test 7: Updating existing value twice removes it
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        setA:Update("foo", 123)
        setA:Update("foo", 123)
        assert(setA == setB, "Test 7 Failed: Updating same value twice should remove it")
    end

    do
        -- Test 8: Updating existing value regardless of order removes it
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        setA:Update("foo", 123) -- inserted
        setA:Update("bar", 456) -- inserted
        setA:Update("baz", 789) -- inserted
        setB:Update("foo", 123) -- inserted
        setB:Update("baz", 789) -- inserted
        setA:Update("bar", 456) -- removed
        assert(setA == setB, "Test 8 Failed: Updating existing value should remove it")
        print("Test 8 PASSED: Updating existing value effectively removes it")
    end

    do
        --- Test 9: Same key produce same bucket index
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        local setC = LibBucketedHashSet.New(4)
        local bucketIndexA = setA:Update("foo")
        local bucketIndexB = setB:Update("foo", 123)
        local bucketIndexC = setC:Update("foo", 456)
        assert(bucketIndexA == bucketIndexB and bucketIndexB == bucketIndexC, "Test 9 Failed: Same key should produce same bucket index")
        print("Test 9 PASSED: Same key produces same bucket index")
    end

    do
        --- Test 10: Same key but different values produce different bucket hashes
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        local setC = LibBucketedHashSet.New(4)
        setA:Update("foo")
        setB:Update("foo", 123)
        setC:Update("foo", 456)
        assert(setA ~= setB and setB ~= setC and setA ~= setC, "Test 10 Failed: Same key but different values should produce different bucket hashes")
        print("Test 10 PASSED: Same key but different values produce different bucket hashes")
    end

    do
        -- Test 11: Different seeds produce different hashes
        local setA = LibBucketedHashSet.New(4, 123)
        local setB = LibBucketedHashSet.New(4, 456)
        setA:Update("foo", 123)
        setB:Update("foo", 123)
        assert(setA ~= setB, "Test 11 Failed: Different seeds should produce different hashes")
        print("Test 11 PASSED: Different seeds produce different hashes")
    end

    do
        -- Test 12: Clear resets to identical
        local setA = LibBucketedHashSet.New(4)
        local setB = LibBucketedHashSet.New(4)
        setA:Update("foo", 123)
        setB:Update("bar", 456)
        assert(setA ~= setB, "Test 12 Failed: Sets should diverge before clear")
        setA:Clear()
        setB:Clear()
        assert(setA == setB, "Test 12 Failed: Clear should reset sets to identical")
        print("Test 12 PASSED: Clear resets buckets")
    end

    do
        -- Test 13: Export and Import preserves state
        local setA = LibBucketedHashSet.New(4)
        setA:Update("foo", 123)
        setA:Update("bar", 456)
        local state = setA:Export()
        local setB = LibBucketedHashSet.Import(state)
        assert(setA == setB, "Test 13 Failed: Export and Import should preserve state")
        print("Test 13 PASSED: Export and Import preserves state")
    end

    do
        -- Test 14: Import invalid state raises error
        ---@diagnostic disable: param-type-mismatch, missing-fields
        assert(not pcall(function() LibBucketedHashSet.Import(nil) end), "Test 14 Failed: Importing nil state should raise error")
        assert(not pcall(function() LibBucketedHashSet.Import(123) end), "Test 14 Failed: Importing non-table state should raise error")
        assert(not pcall(function() LibBucketedHashSet.Import("invalid") end), "Test 14 Failed: Importing non-table state should raise error")
        assert(not pcall(function() LibBucketedHashSet.Import({}) end), "Test 14 Failed: Importing incomplete state should raise error")
        assert(not pcall(function() LibBucketedHashSet.Import({ 123, 4 }) end), "Test 14 Failed: Importing state with missing buckets should raise error")
        assert(not pcall(function() LibBucketedHashSet.Import({ 123, -1, {} }) end), "Test 14 Failed: Importing state with invalid numBuckets should raise error")
        assert(not pcall(function() LibBucketedHashSet.Import({ 123, 4, { 0, 1 } }) end), "Test 14 Failed: Importing state with incorrect buckets length should raise error")
        --- @diagnostic enable: param-type-mismatch, missing-fields
        print("Test 14 PASSED: Invalid state raises error on import")
    end

    do
        -- Test 15: Equality operator
        local function CompareBuckets(a, b)
            if a.numBuckets ~= b.numBuckets then
                return false
            end
            for i = 1, a.numBuckets do
                if a.buckets[i] ~= b.buckets[i] then
                    return false
                end
            end
            return true
        end
        do -- sets with same numBuckets and seed
            local setA = LibBucketedHashSet.New(4)
            local setB = LibBucketedHashSet.New(4)
            assert(setA == setB, "Test 15 Failed: Newly created sets should be equal")
            assert(CompareBuckets(setA, setB), "Test 15 Failed: Buckets should be equal for newly created sets")
            setA:Update("foo", 123)
            assert(setA ~= setB, "Test 15 Failed: Sets should not be equal after different insert")
            assert(not CompareBuckets(setA, setB), "Test 15 Failed: Buckets should not be equal after different insert")
            setB:Update("foo", 123)
            assert(setA == setB, "Test 15 Failed: Sets should be equal after same insert")
            assert(CompareBuckets(setA, setB), "Test 15 Failed: Buckets should be equal after same insert")
            setA:Update("bar", 456)
            setB:Update("baz", 789)
            assert(setA ~= setB, "Test 15 Failed: Sets should not be equal after different inserts")
            assert(not CompareBuckets(setA, setB), "Test 15 Failed: Buckets should not be equal after different inserts")
        end
        do -- sets with different numBuckets
            local setA = LibBucketedHashSet.New(4)
            local setB = LibBucketedHashSet.New(5)
            assert(setA ~= setB, "Test 15 Failed: Sets with different numBuckets should not be equal")
            assert(not CompareBuckets(setA, setB), "Test 15 Failed: Buckets of sets with different numBuckets should not be equal")
            setA:Update("foo", 123)
            setB:Update("foo", 123)
            assert(setA ~= setB, "Test 15 Failed: Sets with different numBuckets should not be equal even after same insert")
            assert(not CompareBuckets(setA, setB), "Test 15 Failed: Buckets of sets with different numBuckets should not be equal even after same insert")
        end
        do -- sets with different seeds
            local setA = LibBucketedHashSet.New(4, 123)
            local setB = LibBucketedHashSet.New(4, 456)
            assert(setA ~= setB, "Test 15 Failed: Sets with different seeds should not be equal")
            assert(CompareBuckets(setA, setB), "Test 15 Failed: Buckets of sets with different seeds should not be equal")
            setA:Update("foo", 123)
            setB:Update("foo", 123)
            assert(setA ~= setB, "Test 15 Failed: Sets with different seeds should not be equal even after same insert")
            assert(not CompareBuckets(setA, setB), "Test 15 Failed: Buckets of sets with different seeds should not be equal even after same insert")
        end
        print("Test 15 PASSED: Equality operator works correctly")
    end

    do
        -- Test 16: Bucket hash values are within 32-bit range
        local numOperations = 100000
        local set = LibBucketedHashSet.New(numOperations)
        for i = 1, numOperations do
            set:Update("value" .. i * 13, i * 13)
        end
        for i = 1, set.numBuckets do
            local bucketValue = set.buckets[i]
            assert(type(bucketValue) == "number" and bucketValue >= 0 and bucketValue <= UINT32_MAX, "Test 16 Failed: Bucket value should be a valid 32-bit unsigned integer")
        end
        print("Test 16 PASSED: Bucket hash values are within 32-bit range")
    end

    -- Test 17: Distribution of values across buckets
    do
        local keysPerBucket = 32
        local numValues = 10000
        local numBuckets = ceil(numValues / keysPerBucket)
        local set = LibBucketedHashSet.New(numBuckets)
        local seenBuckets = {}

        for i = 1, numBuckets do
            seenBuckets[i] = 0
        end

        for i = 1, numValues do
            local bucketIndex = set:Update("user-" .. i .. 0, i * 13)
            seenBuckets[bucketIndex] = seenBuckets[bucketIndex] + 1
        end

        -- Compute min/max
        local minCount = math.huge
        local maxCount = 0

        for i = 1, numBuckets do
            local c = seenBuckets[i]
            if c < minCount then minCount = c end
            if c > maxCount then maxCount = c end
        end

        -- Expected mean and sigma for binomial distribution
        local expected = numValues / numBuckets
        local sigma = math.sqrt(expected * (1 - 1 / numBuckets))

        -- 3-sigma bounds: using 3.5 sigma avoids rare false positives; 3 sigma was too tight for binomial variance.
        local lowerBound = expected - 3.5 * sigma
        local upperBound = expected + 3.5 * sigma

        assert(minCount >= lowerBound, format("Test 17 Failed: Bucket distribution too skewed: min=%d < %d", minCount, lowerBound))
        assert(maxCount <= upperBound, format("Test 17 Failed: Bucket distribution too skewed: max=%d > %d", maxCount, upperBound))
        --print(format("distribution: %s", table.concat(seenBuckets, ", ")))
        print("Test 17 PASSED: Distribution of values across buckets is acceptable")
    end

    do
        -- Test 18: Performance
        local numOperations = 10000
        local set = LibBucketedHashSet.New(ceil(numOperations / 32))
        local results = {}
        for i = 1, numOperations do
            local suffix = i * 13
            local startTime = debugprofilestop()
            set:Update("value" .. suffix, suffix)
            local endTime = debugprofilestop()
            results[i] = endTime - startTime
        end
        local totalTime = 0.0
        local minTime = math.huge
        local maxTime = 0.0
        for i = 1, numOperations do
            totalTime = totalTime + results[i]
            if results[i] < minTime then
                minTime = results[i]
            end
            if results[i] > maxTime then
                maxTime = results[i]
            end
        end
        local avgTime = totalTime / numOperations
        table.sort(results)
        local medianTime = results[math.floor(numOperations / 2)]
        local FormatTime = function(milliseconds)
            if milliseconds < 1.0 then
                return format("%.2fus", milliseconds * 1000.0)
            elseif milliseconds < 1000.0 then
                return format("%.2fms", milliseconds)
            else
                return format("%.2fs", milliseconds / 1000.0)
            end
        end
        print(format("Test 18: Performance over %d operations: median=%s, avg=%s, min=%s, max=%s, total=%s", numOperations, FormatTime(medianTime), FormatTime(avgTime), FormatTime(minTime), FormatTime(maxTime), FormatTime(totalTime)))
    end

    print("=== All LibBucketedHashSet Tests PASSED ===\n")
end

RunLibBucketedHashSetTests()

]]--
