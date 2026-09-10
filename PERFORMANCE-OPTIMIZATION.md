# Performance Optimization Pass — September 2026

Addon version at time of change: **1.9.9**
Follow-up to PR [#6](https://github.com/IAmChills/HardcoreAchievements/pull/6) (`697d2e2`, "Bug/5 performance impact", merged 2026-07-24).

## Reported symptom

A player reported losing roughly **50 FPS for one to two seconds, almost every 45 seconds, consistently**.

## Key diagnostic finding

**There is no 45-second timer anywhere in the addon.** Every recurring cadence in the codebase is 0.5s, 1s, 60s, 90s, 120s, or 300s.

The ~45 second rhythm is emergent, not scheduled. It is the **peer-to-peer gossip round** landing. `LibP2PDB` paces its whisper chunks at `CHUNK_SEND_DELAY = 1.5` seconds, and several pieces of addon work were re-running once per arriving chunk. That is what stretches a single logical event into a stall lasting "a second or two" rather than one dropped frame, and why the gap between stalls varies around a 60-second sync interval rather than landing on it exactly.

This reframes the whole problem: the fix is not to find a slow timer, it is to stop doing expensive work per inbound network chunk.

## Severity and confidence scales

**Severity** — how much this specific issue contributed to the reported stall:

| Rating | Meaning |
| --- | --- |
| Critical | Very likely a primary cause of the reported symptom |
| High | Significant contributor, or a severe problem on a different trigger |
| Medium | Real waste that adds to the baseline cost |
| Low | Correctness/hygiene improvement with minor performance benefit |

**Confidence** — how sure I am the change behaves correctly, **before any in-game testing**. No change in this pass has been run in the client.

---

## 1. Completion-stats cache rebuilt on every gossip chunk

**File:** `Leaderboard/LeaderboardCompletionStats.lua`

**Severity: Critical — Confidence: Medium-High**

### What it was doing

`Leaderboard.RebuildCompletionStatsCache()` walked every achievement definition against every reporting player: `for achId, def in pairs(defs)` wrapped around `for i = 1, #reporters`. For each of those pairs it called `RowMatchesAchievementDef`, which called `FactionMatches`, `ClassMatches`, and `RaceMatches`. Two of those allocated a brand new string on every single call (`tostring(required):upper()` and `race:lower()`).

The trigger was the real problem. `StoreRow` in `LeaderboardSync.lua` called `ScheduleCompletionStatsRebuild()` on any row change, `DrainPendingChanges` ticks every 0.5 seconds, and gossip delivers 16 rows per chunk every 1.5 seconds. A single sync round covering a few hundred players therefore fired **dozens of consecutive full rebuilds**, each one allocating hundreds of thousands of throwaway strings. That is enough to force garbage collection on its own, on top of the raw iteration cost.

There was also a third pass for achievement IDs not present in local definitions. It was nested — for each reporter, for each ID, scan all reporters again — degrading toward O(reporters²).

### What it does now

- **Rebuild is lazy.** `ScheduleCompletionStatsRebuild()` is now a one-line dirty flag. The rebuild happens inside `GetAchievementCompletionStats()` on first read. The only consumer in the entire addon is the "% of eligible players have this achievement" line in `Functions/ShowAchievementTooltip.lua`, so if the player never hovers an achievement, the work **never happens at all**.
- **Matching no longer allocates.** Each definition's faction/class/race gates are normalized once and memoized in `defReqCache` (keyed by the def table, which lives for the whole session). Each reporter's identity is normalized once per rebuild into `factionKey`, `classId`, `classToken`, `raceFromId`, `raceFromName`. `ReporterMatches` is then pure table lookups and equality tests.
- **Fast path for unrestricted definitions.** Most achievements have no faction, class, or race gate. Those now skip matching entirely: `total` is the reporter count and we only count set hits.
- **Impossible definitions short-circuit.** A definition that no row can ever satisfy (for example a non-string race requirement) is flagged once and skipped.
- **Orphan pass is single-pass.** Counts accumulate into one table instead of rescanning all reporters per orphan ID.
- **Payload parsing is memoized.** `BuildCompletedSet` caches parsed sets keyed by the packed wire string. Reporters resend identical strings across rounds, so repeated rebuilds no longer re-split hundreds of payloads. Bounded at 2000 entries and wiped wholesale on overflow.

### Why this is faster

The expensive work is now (a) skipped entirely unless a tooltip asks for it, and (b) roughly an order of magnitude cheaper when it does run, because the inner loop no longer allocates.

### Confidence notes

Medium-High rather than High because this is the largest rewrite in the pass. I traced each original matching branch against its replacement, including the edge cases where `def.class` is a table, an empty table, a table of numbers, or an unknown class token; where `def.faction` is a non-Horde/Alliance string; and where race comes from `raceId` versus `row.race`. I believe semantics are preserved. The residual risk is a subtle behavioral difference in an edge case I did not think to enumerate. The blast radius is contained: the worst case is a wrong percentage on one tooltip line, not a broken achievement.

---

## 2. Self-perpetuating guild roster refresh loop

**File:** `Utils/GuildFirst.lua`

**Severity: High — Confidence: High**

### What it was doing

```lua
local function GetGuildName()
    C_GuildInfo.GuildRoster()
    return GetGuildInfo and GetGuildInfo("player") or nil
end
```

`GetGuildName()` requested a **full guild roster from the server**, and it was called from inside the `GUILD_ROSTER_UPDATE` handler — the handler for that very event. So the roster arrived, the handler asked for it again, and the cycle repeated forever, paced by Classic's roster request throttle.

In a large guild each refresh makes the client rebuild its entire roster cache and then notifies every other addon listening to `GUILD_ROSTER_UPDATE`, so the cost was not even contained to this addon.

### What it does now

The request is split out into a separate `RequestGuildRoster()` helper that is rate limited to once per 30 seconds and gated on `IsInGuild()`. It is called **once at login**. `GetGuildName()` is now a pure read of `GetGuildInfo("player")`, which does not require a roster request to answer. The `GUILD_ROSTER_UPDATE` handler still runs (it needs to catch the player joining a guild later) but no longer triggers the event it handles.

### Why this is faster

An unbounded periodic full-roster refresh is gone. `GetGuildName()` is called from several places (`ScopeKeyFor`, `BuildWinnersPeerIDList`, the init handler) and each of those was previously firing a server request; now none of them do.

### Confidence notes

High. Small, self-contained change. `GetGuildInfo("player")` returning the player's own guild name without an explicit roster request is well-established behavior. The login-time request plus the retained `GUILD_ROSTER_UPDATE` handler preserve the "joined a guild mid-session" path.

---

## 3. Second combat-log frame (regression against PR #6)

**Files:** `Achievements/FirstKillRareQuestLoot.lua`, `HardcoreAchievements.lua`

**Severity: High — Confidence: High**

### What it was doing

PR #6's central fix was consolidating `COMBAT_LOG_EVENT_UNFILTERED` down to a **single frame** (`achEvt`), and it explicitly removed the second registration from `Functions/PlayerIsSolo.lua`, replacing it with an exported `addon.PlayerIsSolo_OnCombatLogEvent` that `achEvt` calls directly. That file still honors the arrangement.

`Achievements/FirstKillRareQuestLoot.lua` had since added a new second combat-log frame, doing its own unconditional `CombatLogGetCurrentEventInfo()` parse on every event just to check for `PARTY_KILL`. Combat log events fire hundreds of times per second during AoE, so this reinstated exactly the pattern the PR removed.

### What it does now

The module exports `addon.FirstKillRareQuestLoot_OnPartyKill(destGUID)` and no longer registers for combat log events. `achEvt` calls it from its existing `PARTY_KILL` branch. The call is placed at the **top** of that branch, before the tap-denial and instance gates, because those can `return` early and the original standalone handler ran for all party kills regardless.

Verified: there is now exactly one `COMBAT_LOG_EVENT_UNFILTERED` registration in the addon.

### Why this is faster

One combat log parse per event instead of two, on the hottest event in the game.

### Confidence notes

High. The behavioral contract is narrow — `PARTY_KILL` with a `destGUID` — and placing the call ahead of the early returns preserves it exactly. The `#rules == 0` guard in the exported function matches the original's login-time gate.

---

## 4. `UPDATE_FACTION` fan-out across 22–44 frames

**Files:** `Achievements/ReputationCommon.lua`, `TBC/ReputationCommon.lua`, `HardcoreAchievements.lua`

**Severity: High — Confidence: Medium-High**

### What it was doing

Every reputation achievement created **its own event frame** registered for `UPDATE_FACTION` — 22 in vanilla, 44 in TBC. Every one of those handlers unconditionally ran `addon[registerFuncName]()` on every event:

```lua
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "UPDATE_FACTION" then ... end
    addon[registerFuncName]()   -- ran for every event, always
end)
```

For any faction the player had not yet encountered — which is most of them for most of the game — that reached `IsEligible()` → `HasFaction()`, which looped the **entire reputation list** via `GetNumFactions()` / `GetFactionInfo(i)`. With 44 achievements against roughly 70 factions that is around 3,000 API calls per `UPDATE_FACTION` event, and the event fires in bursts during quest turn-ins and reputation grinding.

Separately, `achEvt` **also** handled `UPDATE_FACTION` by scanning every achievement row and `pcall`ing a tracker per reputation row, undebounced.

### What it does now

- **One shared frame** replaces the 22–44 per-achievement frames. Achievements register into a `registrars` list instead of creating a frame.
- **One shared faction scan.** `GetFactionIdSet()` builds an ID set with a single `GetNumFactions()` walk and caches it. `HasFaction()` is now a table lookup. The cache is invalidated on `UPDATE_FACTION` and dropped once at the start of each pass, so the first registrar rebuilds it and the remaining 43 reuse it.
- **One debounced pass.** A burst of events schedules a single pass 0.5 seconds later rather than N × M immediate scans. Completion checks only run when the burst actually included an `UPDATE_FACTION` (preserving the original behavior where `PLAYER_LOGIN` / `ADDON_LOADED` only triggered registration).
- The `achEvt` row-scan bridge is debounced by 0.5 seconds as well.

### Why this is faster

Per burst: one faction list walk instead of dozens, one event frame dispatch instead of dozens, and one row scan instead of one per event.

### Confidence notes

Medium-High. The restructure is mechanical but touches registration ordering, which matters during load. Mitigating factors: `registerReputationAchievement` already calls its registration function immediately when the panel is ready, and the per-achievement `CharacterFrame:HookScript("OnShow")` fallback is untouched, so there are two independent paths that still create rows if the shared pass has not run yet. The new `GetFactionIdSet()` is also strictly safer than the old code against a missing `GetNumFactions` global — it yields an empty set where the old version would have errored. The residual risk is a 0.5 second delay before a reputation achievement row appears, which is cosmetic.

The same change is applied identically to the vanilla and TBC files. Only one loads per game type, and even if both loaded the result would be two frames rather than 66.

---

## 5. `UNIT_INVENTORY_CHANGED` full row scan, undebounced

**File:** `HardcoreAchievements.lua`

**Severity: Medium — Confidence: High**

### What it was doing

Every inventory change on the player scanned the **entire** `AchievementRowModel` and, for each incomplete dungeon-set row, resolved and `pcall`ed a tracker function (which internally checks all required items). There was no debounce, so equipping a full set fired this once per slot — up to a dozen full scans back to back for one logical action.

### What it does now

Wrapped in a `_pendingInventoryCheck` guard with `C_Timer.After(0)`, matching the pattern already used for `UNIT_AURA` in the same handler. A burst of slot changes collapses into a single pass on the next frame.

### Why this is faster

One scan per burst instead of one per slot.

### Confidence notes

High. Same debounce idiom already proven in this file for `UNIT_AURA` and `MAP_EXPLORATION_UPDATED`. Deferring by one frame is safe here because nothing reads the result synchronously. Block nesting was verified directly in the file after the edit.

---

## 6. Tracker's `MAP_EXPLORATION_UPDATED` handler, undebounced and duplicated

**File:** `Utils/AchievementTracker.lua`

**Severity: Medium — Confidence: Medium-High**

### What it was doing

`achEvt` already debounces this event by 0.5 seconds before calling `EvaluateCustomCompletions`. The tracker registered the **same event on a second frame** and ran, with no debounce at all, a full `EvaluateCustomCompletions()` (scans every row, `pcall`s a completion function per row, and can trigger `RefreshAllAchievementPoints()`) plus a full tracker UI rebuild with string width measurement.

`MAP_EXPLORATION_UPDATED` fires repeatedly while running through unexplored terrain, so this was a full duplicate evaluation per map tile.

### What it does now

Debounced by 0.6 seconds — deliberately just behind `achEvt`'s 0.5 second pass. The duplicate `EvaluateCustomCompletions()` call is now conditional on `addon.AchEvt` being absent, so it only runs as a fallback if the main event frame never got created. The tracker keeps responsibility for its own UI refresh.

### Why this is faster

The redundant full-row evaluation is gone in the normal case, and the tracker rebuild runs once per burst instead of once per tile.

### Confidence notes

Medium-High. Gating on `addon.AchEvt` is a real dependency between two modules, so I verified that flag is genuinely assigned (`HardcoreAchievements.lua:4264`, set immediately on frame creation) rather than assuming it. The fallback branch means exploration achievements still complete even if the main frame is missing. The residual risk is that the tracker UI now updates 0.6 seconds after discovering an area instead of instantly.

---

## 7. Per-achievement `QUEST_LOG_UPDATE` timers with no guard

**File:** `Achievements/Common.lua`

**Severity: Low — Confidence: High**

*Not in the original findings list; found during the final sweep.*

> **Correction.** An earlier revision of this document rated this **High** and called `QUEST_LOG_UPDATE` a "high-frequency event." That was wrong on both counts and the rating contradicted this document's own severity scale, which measures contribution to the reported stall. `QUEST_LOG_UPDATE` is **event-driven, not periodic** — it fires when quest state actually changes. It does not fire while a player is standing idle, so it **cannot** be the cause of a recurring ~45 second stall. The change below is still worth keeping, but for burst hygiene at login and during questing, not for the reported symptom.

### What it was doing

Every quest achievement created its own frame registered for `QUEST_LOG_UPDATE`, and each handler created a **brand new closure and timer on every event**:

```lua
f:SetScript("OnEvent", function(self)
    if state.completed then self:UnregisterAllEvents() return end
    C_Timer.After(0.25, function()          -- no pending guard
        if topUpFromServer() and checkComplete() then ... end
    end)
end)
```

The cost here is **fan-out, not frequency**. `requiredQuestId` appears on **61** achievements in `Achievements/Catalog.lua` and **64** in `TBC/Catalog.lua`, so up to ~61 frames are listening at once (completed ones unregister themselves). A single event therefore queued up to 61 timers and closures, all firing 0.25 seconds later to run server top-up checks and completion evaluation.

When that matters:

- **Login and post-loading-screen**, where the client fires the event several times as quest data streams in — several × 61 timers during the exact window the addon is already busy registering catalogs.
- **Active questing**, where an objective advancing (for example a quest mob dying) fires the event, so a grind produces a batch every few seconds.

When it does not matter, and where I originally overstated it: **idle gameplay**, which is the scenario in the bug report. The event simply is not firing then.

### What it does now

A `questLogCheckPending` flag per achievement, so at most one timer is queued at a time. The completion path and `UnregisterAllEvents()` behavior are unchanged.

### Why this is faster

Up to 61 timers and closures per event become at most 61 in flight total, regardless of how many events arrive in a burst. It removes allocation churn at login and during questing. It does nothing for the reported stall.

### Confidence notes

High, and worth stating why the coalescing is safe rather than just asserting it. Dropping an event inside the pending window loses no information because the callback **reads live state** (`topUpFromServer()` queries quest and progress state at call time) rather than a payload captured from the event. An event arriving at t=0.2 is skipped, but the already-scheduled check at t=0.25 still observes that event's data. The flag is also cleared at the *top* of the callback, before `topUpFromServer()` runs, so an error inside the check cannot wedge the flag `true` and permanently disable the achievement.

Given the corrected severity, this is the one change in the pass that could be reverted with no impact on the reported symptom. I would keep it — it is four lines, strictly safe, and the login-window fan-out is real — but it should not be counted as part of the fix for the stall.

---

## 8. Stored failures invisible until reload (correctness regression from PR #6)

**File:** `HardcoreAchievements.lua`

**Severity: N/A (not a performance issue) — Confidence: High**

*Found from a user report during testing, not from the performance sweep. This is a **caching bug introduced by PR #6 itself**, not by this pass.*

### Symptom

The Ridiculous achievements (`Achievements/RidiculousCatalog.lua`) stopped showing as failed the moment they were failed. Jumping with The Disciplined One, or gaining XP while equipped for Birthday Suit and Knuckle Up, would not flip the row to failed until the player reloaded.

### Root cause

PR #6 added a memoization cache for `IsRowOutleveled` (commit `72f6eb3`, with a follow-up in `ebe30da`), keyed by row object:

```lua
local function IsRowOutleveled(row)
    local cached = _outleveledCache[row]
    if cached ~= nil then return cached end
    ...
end
```

It is wiped on `PLAYER_ENTERING_WORLD`, `QUEST_TURNED_IN` and `PLAYER_LEVEL_CHANGED`, and per-achievement inside `SetProgress`. That covers level- and quest-gated failures, but **not stored failures.**

All five Ridiculous achievements fail through `EnsureFailureTimestamp`, which writes `rec.failed = true` straight to the character database and never goes through `SetProgress`. Their triggers — a jump, an XP tick, an equipment change — do not fire any of the invalidating events either. So the write landed correctly in the database, and then `RefreshOutleveledAll` re-styled every row from the **stale cached `false`**. The failure was recorded but invisible until the next `PLAYER_ENTERING_WORLD` wiped the cache, which is exactly why a reload appeared to fix it.

### The fix

`EnsureFailureTimestamp` now clears the cached rows for that achievement whenever the record actually transitions to failed:

```lua
if becameFailed then
    InvalidateOutleveledCacheForAchId(achId)
end
```

All five trackers (`TrackJumps`, `TrackNude`, `TrackNoWeapon`, `TrackNoQuestTurnIns`, `TrackWarforged`) share the identical `EnsureFailureTimestamp` → `RefreshOutleveledAll` pattern, so fixing the single choke point covers all of them, plus the meta and secret achievements that set `supportsStoredFailure`.

### Confidence notes

High. The guard is keyed on an actual state transition, so it does not re-invalidate on every restyle. `InvalidateOutleveledCacheForAchId` was already the established per-achievement invalidation path (used by `SetProgress`) and clears both the model rows and the panel frames, which is what the Dashboard resolves through via `sourceRow`. Callers already call `RefreshOutleveledAll` immediately afterward, so no new refresh plumbing was needed.

Worth noting this cost nothing in performance terms: the cache still works, it just now has a correct invalidation edge.

---

## Deliberately not changed

### `Libs/LibP2PDB/LibP2PDB.lua`

Left untouched per instruction. Two of its message handlers are **synchronous and scale with guild size**:

- `DigestRequestHandler` builds a bloom filter over every key of every synced table and exports it, whenever a peer asks for a digest.
- `DigestResponseHandler` iterates all local rows and calls `ExportRow` for each missing one, then serializes, compresses, and encodes each chunk.

Row *import* is properly coroutine-sliced (`ASYNC_NETWORK_IMPORT_MAX_TIME = 0.001`), but nothing else is. This is the remaining per-round cost, and it is the leading suspect if stalls persist after this pass. Worth raising upstream rather than patching locally.

Two things I checked and ruled out: the roughly 7,000 lines of unit tests inside that file are safely enclosed in a comment block and cost nothing at runtime, and its inbound duplicate-message check correctly runs *before* decompression, so duplicate broadcasts across channels are cheap.

### `PersistState` (90 second `ExportDatabase`)

`Leaderboard/LeaderboardSync.lua:339` still does a full synchronous export of every leaderboard row into SavedVariables. The existing debounce token already means it only fires 90 seconds after the *last* row change, so it does not run during active gossip, and avoiding the export entirely would require library changes. Left as-is.

---

## Verification performed

No in-game testing has been done. Static verification only:

- **Linting** clean across the whole addon.
- **Block balance** verified. No Lua interpreter is available on this machine, so I wrote a tokenizer that strips long-bracket strings, long comments, line comments, and quoted strings, then checks `function`/`if`/`do`/`repeat` against `end`/`until`. All seven modified files balance exactly. Untouched control files (`Utils/Dashboard.lua`, `Leaderboard/Leaderboard.lua`, `Leaderboard/LeaderboardSync.lua`) were run through the same check to confirm it was not trivially passing everything.
- **Nesting spot-checked by reading the file** for the two deepest restructures in `HardcoreAchievements.lua` (`UNIT_INVENTORY_CHANGED` and `UPDATE_FACTION`), rather than trusting diff indentation.
- **No dangling references** to removed helpers (`RowMatchesAchievementDef`, `FactionMatches`, `ClassMatches`, `RaceMatches`, `rebuildPending`, the per-achievement `eventFrame` locals).
- **Single combat-log frame** confirmed by grep.

## Suggested test plan

| Area | What to exercise | What to watch for |
| --- | --- | --- |
| Completion stats | Hover several achievements, including class/race/faction-restricted ones | The "% of eligible players" line still appears with plausible numbers |
| Guild first | Log in while in a guild; check guild-first claims still sync | Guild scope database initializes; no roster spam |
| Rare quest loot | Kill a rare with the relevant quest in the log | Progress still increments; failure path still triggers |
| Reputation | Turn in quests that grant reputation; reach Exalted | Rows appear (possibly ~0.5s later); toast fires on completion |
| Dungeon sets | Equip a full set piece by piece | Achievement completes on the last piece |
| Exploration | Run through unexplored terrain | Tracker updates within a second; exploration achievements complete |
| Quest achievements | Accept, progress, and turn in tracked quests | Completion and server top-up still work |
| Stored failures | Jump (Disciplined One); gain XP while wearing gear (Birthday Suit) or a weapon (Knuckle Up) | Row turns red **immediately**, without a reload, in both the character panel and the dashboard |
| The actual symptom | Idle in a populated guild for several minutes | Whether the ~45s stall is gone or reduced |

The last row is the one that matters. Ideally have the reporting player confirm, since their guild size and peer count are what reproduce it.
