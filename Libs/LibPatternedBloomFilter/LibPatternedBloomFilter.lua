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
-- Patterned Bloom Filter implementation for WoW Lua 5.1 environment.
-- Based on: https://save-buffer.github.io/bloom_filter.html Section 1.4
--
-- Credits:
--   This variant of the standard Bloom Filter, proposed by Sasha Krassovsky, uses a
--   single hash function with a predetermined pattern of bits, improving efficiency
--   while maintaining similar false positive rates.
--
-- Optimized for 32-bit Lua environment with single hash and pattern lookup.
-- Uses FNV-1a hash function.
-- Compact bit array representation using 31-bit integers to avoid sign bit issues.
-- Supports insertion, membership testing, export/import, and false positive rate estimation.

local MAJOR, MINOR = "LibPatternedBloomFilter", 3
assert(LibStub, MAJOR .. " requires LibStub")

local LibPatternedBloomFilter = LibStub:NewLibrary(MAJOR, MINOR)
if not LibPatternedBloomFilter then return end -- no upgrade needed

-- Local lua references
local assert, type, setmetatable = assert, type, setmetatable
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local floor, ceil, log = math.floor, math.ceil, math.log
local tostring, strbyte = tostring, strbyte

-- Constants
local LOG2 = log(2)                            -- Natural log of 2
local UINT32_MODULO = 2 ^ 32                   -- Modulo for 32-bit arithmetic
local ROTATE_BITS = 5                          -- Number of bits for rotation (32 possible rotations)
local ROTATE_MASK = lshift(1, ROTATE_BITS) - 1 -- Mask for rotation bits
local PATTERN_BITS = 31                        -- Number of bits in each pattern (31 to avoid sign bit issues)
local DEFAULT_FALSE_POSITIVE_RATE = 0.01       -- Default: 1% FPR
local DEFAULT_NUM_PATTERNS = 256               -- Default: 256 patterns (8 bits for index)
local DEFAULT_BITS_PER_PATTERN = 4             -- Default: 4 bits set per pattern
local DEFAULT_SEED = 0                         -- Default seed for hash function

-- Module-level pattern cache
local patternCache = {}

--- Deterministic PRNG using Linear Congruential Generator.
--- This ensures all clients generate identical patterns for same parameters.
--- @param seed integer Initial seed value.
--- @return function PRNG function returning pseudo-random numbers.
local function CreateLCG(seed)
    local state = seed
    return function(min, max)
        -- LCG parameters (same as glibc)
        state = band((state * 1103515245 + 12345), 0x7FFFFFFF)
        if max then
            return min + (state % (max - min + 1))
        end
        return state
    end
end

--- Deterministic pattern generation: Create bit patterns with k bits set.
--- Uses deterministic PRNG seeded from parameters to ensure all clients
--- with same parameters generate identical patterns.
--- @param numPatterns integer Number of unique patterns to generate.
--- @param patternBits integer Number of bits in each pattern.
--- @param bitsPerPattern integer Number of bits set in each pattern.
local function GeneratePatterns(numPatterns, patternBits, bitsPerPattern)
    -- Create deterministic seed from parameters
    local seed = numPatterns * 31 + bitsPerPattern * 7 + patternBits * 13
    local prng = CreateLCG(seed)

    -- Generate unique patterns
    local patterns = {}
    local seen = {}
    for i = 1, numPatterns do
        local pattern
        repeat
            pattern = 0
            local positions = {}

            -- Set bitsPerPattern bits deterministically
            for j = 1, bitsPerPattern do
                local pos
                repeat
                    pos = prng(0, patternBits - 1)
                until not positions[pos]
                positions[pos] = true
                pattern = bor(pattern, lshift(1, pos))
            end
        until not seen[pattern]

        seen[pattern] = true
        patterns[i] = pattern
    end
    return patterns
end

--- Get or generate patterns from cache.
--- @param numPatterns integer Number of unique patterns.
--- @param bitsPerPattern integer Number of bits set per pattern.
--- @return integer[] patterns Array of bit patterns.
local function GetPatterns(numPatterns, bitsPerPattern)
    local key = numPatterns .. ":" .. bitsPerPattern
    local patterns = patternCache[key]
    if not patterns then
        patterns = GeneratePatterns(numPatterns, PATTERN_BITS, bitsPerPattern)
        patternCache[key] = patterns
    end
    return patterns
end

--- Rotate left for 32-bit integers.
--- @param value integer Input value.
--- @param shift integer Number of bits to rotate.
--- @return integer result Rotated value.
local function RotateLeft32(value, shift)
    shift = shift % 32 -- Ensure shift is 0-31
    if shift == 0 then return value end
    local left = (value * (2 ^ shift)) % UINT32_MODULO
    local right = floor(value / (2 ^ (32 - shift)))
    return left + right
end

--- FNV-1a hash function (32-bit)
--- @param value string Input string to hash.
--- @param seed integer? Seed value.
--- @return integer hash 32-bit hash value.
local function FNV1a32(value, seed)
    local str = tostring(value)
    local len = #str
    local hash = 2166136261 + (seed or 0) * 13
    for i = 1, len do
        hash = bxor(hash, strbyte(str, i))
        hash = (hash * 16777619) % UINT32_MODULO
    end
    return hash
end

-- Construct mask from hash
local function ConstructMask(self, hash)
    -- Extract pattern index from low bits
    local patternIdx = band(hash, self.patternIndexMask) + 1

    -- Extract rotation amount from next bits
    local rotation = band(rshift(hash, self.patternIndexBits), ROTATE_MASK)

    -- Load pattern and rotate
    local pattern = self.patterns[patternIdx]
    return RotateLeft32(pattern, rotation)
end

--- @class LibPatternedBloomFilter Patterned Bloom Filter data structure.
--- @field New fun(capacity: integer, seed: integer?, falsePositiveRate: number?, numPatterns: integer?, bitsPerPattern: integer?): LibPatternedBloomFilter Create a new Patterned Bloom Filter instance.
--- @field Insert fun(self: LibPatternedBloomFilter, value: any) Insert a value into the filter.
--- @field Contains fun(self: LibPatternedBloomFilter, value: any): boolean Determine if a value is possibly in the filter.
--- @field Export fun(self: LibPatternedBloomFilter): LibPatternedBloomFilterState Export the current state of the filter.
--- @field Import fun(data: LibPatternedBloomFilterState): LibPatternedBloomFilter Import a new Patterned Bloom Filter from a compact representation.
--- @field Clear fun(self: LibPatternedBloomFilter) Clear all values from the filter.
--- @field EstimateFalsePositiveRate fun(self: LibPatternedBloomFilter): number Estimate the current false positive rate (FPR) of the filter based on current load factor.
--- @field seed integer Seed used for hashing function.
--- @field numBits integer Total number of bits in the filter.
--- @field numIntegers integer Number of 31-bit integers in the bit array.
--- @field numPatterns integer Number of unique bit patterns.
--- @field patterns integer[] Array of bit patterns (cached reference).
--- @field bitsPerPattern integer Number of bits set per pattern.
--- @field patternIndexBits integer Number of bits used for pattern index.
--- @field patternIndexMask integer Bitmask for pattern index extraction.
--- @field bits integer[] Bit array represented as array of 31-bit integers.

--- @class LibPatternedBloomFilterState Compact representation of a Patterned Bloom Filter state.
--- @field [1] integer seed Seed used for hashing function.
--- @field [2] integer numBits Total number of bits in the filter.
--- @field [3] integer numIntegers Number of 31-bit integers in the bit array.
--- @field [4] integer numPatterns Number of unique bit patterns.
--- @field [5] integer bitsPerPattern Number of bits set per pattern.
--- @field [6] integer[] Bit array represented as array of 31-bit integers.

LibPatternedBloomFilter.__index = LibPatternedBloomFilter

--- Create a new Patterned Bloom Filter instance.
--- @param capacity integer Capacity of the filter (expected number of values).
--- @param seed integer? Seed for the hashing function (default: 0).
--- @param falsePositiveRate number? Desired false positive rate (between 0.0 and 1.0, default: 0.01 which means 1%).
--- @param numPatterns integer? Number of unique bit patterns to generate (default: 256).
--- @param bitsPerPattern integer? Number of bits set per pattern (between 1 and 31, default: 4).
--- @return LibPatternedBloomFilter instance The new Patterned Bloom Filter instance.
function LibPatternedBloomFilter.New(capacity, seed, falsePositiveRate, numPatterns, bitsPerPattern)
    assert(capacity and capacity > 0, "capacity must be greater than 0")
    seed = seed or DEFAULT_SEED
    assert(type(seed) == "number", "seed must be a number")
    falsePositiveRate = falsePositiveRate or DEFAULT_FALSE_POSITIVE_RATE
    assert(falsePositiveRate >= 0.0 and falsePositiveRate <= 1.0, "falsePositiveRate must be between 0 and 1")
    numPatterns = numPatterns or DEFAULT_NUM_PATTERNS
    assert(numPatterns > 0 and band(numPatterns, numPatterns - 1) == 0, "numPatterns must be a power of two")
    bitsPerPattern = bitsPerPattern or DEFAULT_BITS_PER_PATTERN
    assert(bitsPerPattern > 0 and bitsPerPattern <= PATTERN_BITS, "bitsPerPattern must be between 1 and 31")

    -- Calculate optimal number of bits (using standard Bloom formula)
    -- m = -n * ln(p) / (ln(2)^2)
    local numBits = ceil(-capacity * log(falsePositiveRate) / (LOG2 * LOG2))

    -- Round up to multiple of 32 for efficient storage
    numBits = ceil(numBits / 32) * 32

    -- We use 31 bits per integer (avoid sign bit issues)
    local numIntegers = ceil(numBits / PATTERN_BITS)

    -- Calculate derived fields
    local patternIndexBits = floor(log(numPatterns) / LOG2)
    local patternIndexMask = numPatterns - 1

    -- Get patterns from cache (shared reference)
    local patterns = GetPatterns(numPatterns, bitsPerPattern)

    -- Initialize bit array
    local bits = {}
    for i = 1, numIntegers do
        bits[i] = 0
    end

    return setmetatable({
        seed = seed,
        numBits = numBits,
        numIntegers = numIntegers,
        numPatterns = numPatterns,
        patterns = patterns,
        bitsPerPattern = bitsPerPattern,
        patternIndexBits = patternIndexBits,
        patternIndexMask = patternIndexMask,
        bits = bits,
    }, LibPatternedBloomFilter)
end

--- Insert a value into the filter.
--- @param value any Value to insert.
function LibPatternedBloomFilter:Insert(value)
    assert(value ~= nil, "value cannot be nil")
    local hash = FNV1a32(value, self.seed)
    local mask = ConstructMask(self, hash)

    -- Use high bits of hash to determine which integer to update
    local offset = rshift(hash, self.patternIndexBits + ROTATE_BITS)
    local idx = (offset % self.numIntegers) + 1

    -- Apply pattern to single integer
    self.bits[idx] = bor(self.bits[idx], mask)
end

--- Determine if a value is possibly in the filter.
--- @param value any Value to check.
--- @return boolean result True if value might be in the set, false if definitely not.
function LibPatternedBloomFilter:Contains(value)
    assert(value ~= nil, "value cannot be nil")
    local hash = FNV1a32(value, self.seed)
    local mask = ConstructMask(self, hash)

    -- Use same offset calculation as Insert
    local offset = rshift(hash, self.patternIndexBits + ROTATE_BITS)
    local idx = (offset % self.numIntegers) + 1

    -- Check if all bits in pattern are set at this location
    return band(self.bits[idx], mask) == mask
end

--- Export the current state of the filter.
--- @return LibPatternedBloomFilterState state Compact representation of the filter.
function LibPatternedBloomFilter:Export()
    return {
        self.seed,
        self.numBits,
        self.numIntegers,
        self.numPatterns,
        self.bitsPerPattern,
        self.bits,
    }
end

--- Import a new Patterned Bloom Filter from a compact representation.
--- @param state LibPatternedBloomFilterState Compact representation of the filter.
--- @return LibPatternedBloomFilter instance The imported Patterned Bloom Filter instance.
function LibPatternedBloomFilter.Import(state)
    assert(state and type(state) == "table", "state must be a table")
    assert(type(state[1]) == "number", "invalid seed in state")
    assert(state[2] and state[2] > 0, "invalid numBits in state")
    assert(state[3] and state[3] > 0, "invalid numIntegers in state")
    assert(state[4] and state[4] > 0, "invalid numPatterns in state")
    assert(state[5] and state[5] > 0, "invalid bitsPerPattern in state")
    assert(state[6] and type(state[6]) == "table", "invalid bits array in state")
    local seed = state[1]
    local numBits = state[2]
    local numIntegers = state[3]
    local numPatterns = state[4]
    local bitsPerPattern = state[5]
    local bits = state[6]

    -- Calculate derived fields
    local patternIndexBits = floor(log(numPatterns) / LOG2)
    local patternIndexMask = numPatterns - 1

    -- Get patterns from cache (shared reference)
    local patterns = GetPatterns(numPatterns, bitsPerPattern)

    return setmetatable({
        seed = seed,
        numBits = numBits,
        numIntegers = numIntegers,
        numPatterns = numPatterns,
        patterns = patterns,
        bitsPerPattern = bitsPerPattern,
        patternIndexBits = patternIndexBits,
        patternIndexMask = patternIndexMask,
        bits = bits,
    }, LibPatternedBloomFilter)
end

--- Clear all values from the filter.
function LibPatternedBloomFilter:Clear()
    for i = 1, self.numIntegers do
        self.bits[i] = 0
    end
end

--- Estimate the current false positive rate (FPR) of the filter based on current load factor.
--- @return number fpr Estimated false positive rate.
function LibPatternedBloomFilter:EstimateFalsePositiveRate()
    -- Count set bits
    local bitsSet = 0
    for i = 1, self.numIntegers do
        local val = self.bits[i]
        -- Count bits in val
        while val > 0 do
            bitsSet = bitsSet + 1
            val = band(val, val - 1) -- Clear lowest set bit
        end
    end

    -- FPR ≈ l^k
    -- Where:
    --   l = fill ratio = bitsSet / numBits
    --   k = number of bits set per pattern
    local fillRatio = bitsSet / self.numBits
    return fillRatio ^ self.bitsPerPattern
end

-- Generate the patterns representing the default parameters on load (should take less than 1 millisecond)
GetPatterns(DEFAULT_NUM_PATTERNS, DEFAULT_BITS_PER_PATTERN)

-------------------------------------------------------------------------------
-- TESTS: Verify Patterned Bloom Filter correctness
-------------------------------------------------------------------------------

--[[ -- Uncomment to run tests when loading this file

local function RunLibPatternedBloomFilterTests()
    print("=== LibPatternedBloomFilter Tests ===")

    -- Test 1: Basic insertion and membership
    local pbf = LibPatternedBloomFilter.New(100)
    assert(not pbf:Contains("item1"), "Test 1 Failed: Empty filter should not contain items")

    pbf:Insert("item1")
    pbf:Insert("item2")
    pbf:Insert("item3")
    assert(pbf:Contains("item1"), "Test 1 Failed: Should contain inserted item1")
    assert(pbf:Contains("item2"), "Test 1 Failed: Should contain inserted item2")
    assert(pbf:Contains("item3"), "Test 1 Failed: Should contain inserted item3")
    print("Test 1 PASSED: Basic insertion and membership")

    -- Test 2: False positives vs true negatives
    local testPbf = LibPatternedBloomFilter.New(100000)
    for i = 1, 50000 do
        local item = "test_" .. i
        testPbf:Insert(item)
    end

    local falsePositives = 0
    local testCount = 100000
    for i = 50001, 50000 + testCount do
        local item = "test_" .. i
        if testPbf:Contains(item) then
            falsePositives = falsePositives + 1
        end
    end

    local actualFPR = falsePositives / testCount
    local estimatedFPR = testPbf:EstimateFalsePositiveRate()
    print(format("Test 2 PASSED: FP Rate - Actual: %.4f, Estimated: %.4f", actualFPR, estimatedFPR))
    assert(actualFPR < 0.1, "Test 2 Failed: False positive rate too high")

    -- Test 3: Export and Import
    local pbf3 = LibPatternedBloomFilter.New(100)
    for i = 1, 100 do
        pbf3:Insert("export_" .. i)
    end

    local exported = pbf3:Export()
    local imported = LibPatternedBloomFilter.Import(exported)

    for i = 1, 100 do
        assert(imported:Contains("export_" .. i), "Test 3 Failed: Imported filter should contain export_" .. i)
    end
    print("Test 3 PASSED: Export and Import")

    -- Test 4: Clear functionality
    local pbf4 = LibPatternedBloomFilter.New(100)
    pbf4:Insert("clear1")
    pbf4:Insert("clear2")
    assert(pbf4:Contains("clear1"), "Test 4 Failed: Should contain clear1 before clear")

    pbf4:Clear()
    assert(not pbf4:Contains("clear1"), "Test 4 Failed: Should not contain clear1 after clear")
    assert(not pbf4:Contains("clear2"), "Test 4 Failed: Should not contain clear2 after clear")
    print("Test 4 PASSED: Clear functionality")

    -- Test 5: No false negatives (critical property)
    local pbf5 = LibPatternedBloomFilter.New(100000)
    local items = {}
    for i = 1, 100000 do
        items[i] = "item_" .. i
        pbf5:Insert(items[i])
    end

    for i = 1, 100000 do
        assert(pbf5:Contains(items[i]), "Test 5 Failed: False negative detected for " .. items[i])
    end
    print("Test 5 PASSED: No false negatives")

    -- Test 6: Deterministic pattern generation
    local pbf6a = LibPatternedBloomFilter.New(100)
    local pbf6b = LibPatternedBloomFilter.New(100)

    pbf6a:Insert("pattern_test")
    pbf6b:Insert("pattern_test")

    -- Both should have identical bit patterns
    local export6a = pbf6a:Export()
    local export6b = pbf6b:Export()

    assert(#export6a == #export6b, "Test 6 Failed: Export sizes should match")
    local export6aBits = export6a[6]
    local export6bBits = export6b[6]
    assert(#export6aBits == #export6bBits, "Test 6 Failed: Bit array sizes should match")
    for i = 1, #export6aBits do -- Compare bits
        assert(export6aBits[i] == export6bBits[i], "Test 6 Failed: Bit arrays should be identical")
    end
    print("Test 6 PASSED: Deterministic pattern generation")

    -- Test 7: Different seeds produce different filters
    local pbf7a = LibPatternedBloomFilter.New(100, 123)
    local pbf7b = LibPatternedBloomFilter.New(100, 456)
    pbf7a:Insert("seed_test")
    pbf7b:Insert("seed_test")
    local export7a = pbf7a:Export()
    local export7b = pbf7b:Export()
    local export7aBits = export7a[6]
    local export7bBits = export7b[6]
    local different = false
    for i = 1, #export7aBits do
        if export7aBits[i] ~= export7bBits[i] then
            different = true
            break
        end
    end

    assert(different, "Test 7 Failed: Filters with different seeds should differ")
    print("Test 7 PASSED: Different seeds produce different filters")

    print("=== All LibPatternedBloomFilter Tests PASSED ===\n")
end

RunLibPatternedBloomFilterTests()

]] --
