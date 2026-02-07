# LibP2PDB

A lightweight, embeddable library for peer-to-peer distributed-database synchronization in WoW addons.

## Features

- Peer-to-peer data synchronization between addon users.
- Lightweight and embeddable: minimal overhead for your addon.
- Simple API for ease of integration.
- Compatible with World of Warcraft Lua 5.1 environment.

## Installation

To install LibP2PDB, simply download the `LibP2PDB.lua` file and include it in your WoW addon folder. Then, you can load it using LibStub in your addon code.

```lua
local LibP2PDB = LibStub("LibP2PDB")
```

## Usage

```lua
-- Make a new database
local db = LibP2PDB:New("MyDatabase", {
    prefix = "MyAddon",
    version = 1,
    onDiscoveryComplete = OnDiscoveryCompleteCallback,
})

-- Make a table with a schema
LibP2PDB:CreateTable(db, {
    name = "MyTableName",
    keyType = "string",
    schema = {
        username = "string",
        email = { "string", "nil" },
    }
})

-- Insert a row
LibP2PDB:InsertKey(db, "MyTableName", "user1", {
    username = "PlayerOne",
    email = nil,
})

-- Check for a row existence
local exists = LibP2PDB:HasKey(db, "MyTableName", "user1")

-- Get a row data
local data = LibP2PDB:GetKey(db, "MyTableName", "user1")

-- Broadcast presence to other peers
LibP2PDB:BroadcastPresence(db)

-- Synchronize database with reachable active peers
LibP2PDB:SyncDatabase(db)
```

As noted in the example above, LibP2PDB provides functions to create tables, insert data, check for existence, and retrieve data. It also includes peer discovery and synchronization functions to keep your database up-to-date across all users of your addon.

Synchronization is typically triggered after peer discovery is complete, ensuring that your database reflects the latest data from all connected peers. This also means that without active peers, no synchronization will occur.

LibP2PDB employs several techniques to minimize bandwidth usage, including delta updates and compression, making it highly efficient for WoW addons. Under ideal network conditions, database changes can propagate to peers in O(log₂N) time, where N is the number of peers in the cluster. For example, in a cluster of 1,000 peers, changes can reach all members in about 10 synchronization rounds.

Migration APIs are provided to help you manage schema changes over time, ensuring that your data remains consistent even as your addon evolves.

The design is highly extensible, allowing you to customize its behavior to fit your specific needs. If you require additional flexibility or features, feel free to reach out—LibP2PDB is built to accommodate such requests.

## License

This library is released under the MIT License. See the LICENSE file for details.
