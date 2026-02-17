# LibBucketedHashSet

Bucketed Hash Set for WoW Lua 5.1 environment - Alternative to Merkle trees for divergence detection and set reconciliation.

## Features

- Efficiently detects divergence between sets.
- Fast toggle operation: toggling the same value twice removes it.
- Low memory usage, suitable for constrained environments.
- Simple API for toggling and checking elements.
- Compatible with World of Warcraft Lua 5.1 environment.

## Installation

To install LibBucketedHashSet, simply download the `LibBucketedHashSet.lua` file and include it in your WoW addon folder. Then, you can load it using LibStub in your addon code.

```lua
local LibBucketedHashSet = LibStub("LibBucketedHashSet")
```

## Performance

Measured on an AMD Ryzen 9 5900X with 10,000 values inserted with a for loop:

```lua
for i = 1, 10000 do
    local value = "value" .. i * 13
    local startTime = debugprofilestop()
    set:Update(value)
    local endTime = debugprofilestop()
    local duration = endTime - startTime
end
```

| Update | Median | Average | Min | Max | Total |
| - | - | - | - | - | - |
| LibBucketedHashSet | 2.10µs | 2.19µs | 1.70µs | 37.60µs | 21.90ms |

The performance of the `Update` operation will scale with the length of the value being updated, as it needs to hash the value to determine the appropriate bucket.

## Usage

```lua
-- Create a new Bucketed Hash Set with 32 buckets
local set = LibBucketedHashSet.New(32)

-- Add any values to the set
for i = 1, 1000 do
    set:Update("value" .. i)
end

-- Remove existing values from the set
for i = 500, 750 do
    set:Update("value" .. i) -- Updating the same value removes it
end

-- Bucket index of a value must be stored when inserting it
local valueBucketIndexMap = {}
valueBucketIndexMap["someValue"] = set:Update("someValue")

-- Comparing two bucketed hash sets
local setA = LibBucketedHashSet.New(32)
local setB = LibBucketedHashSet.New(32)
setA:Update("foo")
setB:Update("foo")
assert(setA == setB, "Sets should be equal")
setB:Update("bar")
assert(setA ~= setB, "Sets should not be equal")

-- Check which buckets differ between two sets
for i = 1, setA.numBuckets do
    if setA.buckets[i] ~= setB.buckets[i] then
        print("Bucket " .. i .. " differs between the two sets.")
    end
end

-- Export the bucketed hash set state for serialization
local state = setA:Export()

-- Import the state into a new bucketed hash set
local setC = LibBucketedHashSet.Import(state)
```

## API

### LibBucketedHashSet.New(numBuckets, seed)

Create a new Bucketed Hash Set instance.

- `numBuckets`: Number of buckets in the bucketedHashSet.
- `seed`: Optional seed for hash function (default: 0).
- Returns: The new Bucketed Hash Set instance.

### bucketedHashSet:Update(value, ...)

Update a value in the bucketed hash set. Updating the same value twice removes it. Only the first value is used to determine the bucket index, but additional values can be included in the hash.

- `value`: Value to update.
- `...`: Additional values to include in the hash (optional).

### bucketedHashSet:Clear()

Clear all values from the bucketedHashSet.

### bucketedHashSet:Export()

Export the current state of the bucketedHashSet.

- Returns: Compact representation of the bucketedHashSet.

### LibBucketedHashSet.Import(state)

Import a new Bucketed Hash Set from a compact representation.

- `state`: Compact representation of the bucketedHashSet.
- Returns: The imported Bucketed Hash Set instance.

## License

This library is released under the MIT License. See the LICENSE file for details.
