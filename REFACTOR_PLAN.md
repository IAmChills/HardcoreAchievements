# HardcoreAchievements.lua Refactor Plan

Living reference for organizing, optimizing, and cleaning up the monolith.
**Do not change SavedVariables schema, DB version, prefixes, or LibP2PDB sync format as part of this work.**

---

## Why

`HardcoreAchievements.lua` is ~6.9k lines / ~300KB and sits at Lua 5.1’s **200-local-per-function** ceiling. Nested `do` blocks and `local function`s in that file still count against the **main chunk**, which is why helpers keep getting packed onto tables (`achToast`, `progressFlush`, fields on `achEvt`).

**Each new file = a new main chunk = a fresh 200-local budget.** That is the primary win. Secondary wins: clearer ownership, safer edits, less accidental coupling.

---

## Goals

1. Never hit the 200-local ceiling again during normal feature work.
2. Incremental, reload-safe moves — one extract (or small batch) at a time.
3. No intentional behavior changes unless called out in the phase notes.
4. Keep the public `addon.*` surface stable for catalogs and Utils that load later.
5. Preserve TOC ordering so catalogs still see progress/registry/row APIs.

---

## Non-goals (this effort)

- Merging Classic / TBC / Forever dungeon commons
- LibP2PDB patch cleanup (tracked in `TODO.md`)
- Schema / channel / handshake changes
- Big-bang rewrite of CharacterPanel + KillBridge in one pass

---

## Current TOC constraint

Relevant load order today:

```
Utils\Compat.lua
… Functions / Forever kill tracking …
Utils\SharedUtils.lua
Utils\FilterDropdown.lua
Utils\AchievementTracker.lua
HardcoreAchievements.lua          ← monolith (must expose APIs catalogs need)
Utils\GuildFirst.lua
Utils\CommChannel.lua
…
Leaderboard\*
Achievements\* / TBC\* / Forever\* catalogs
Utils\Dashboard.lua / CommandHandler / Options …
```

Anything achievement catalogs call (`GetCharDB`, `GetProgress` / `SetProgress`, `RegisterAchievementFunction`, `CreateAchievementRow`, `MarkRowCompleted`, hooks) must exist **before** catalog files run. Extracted Core/UI/Combat modules therefore load **in the HardcoreAchievements.lua slot**, immediately before the thinned main file (or replace slices of it).

---

## Monolith map (approximate line ranges)

| Lines | Region | Phase |
|------:|--------|------|
| 1–145 | Locals, outleveled cache, registry | P1 registry / keep bootstrap locals |
| 147–240 | Hook system | **P1** → `Utils\Core\Hooks.lua` |
| 242–275 | Self-found bonus + quest track helpers | Later / stay until panel extract |
| 277–748 | SavedVariables (`sv.*`), GetCharDB, cleanups | **P3/P4** → `Utils\Core\SavedVariables.lua` |
| 749–870 | ClearProgress + unsaved reminder banner | **P1** with Progress |
| 870–2350 | Row UI helpers, MarkRowCompleted, points, tab toggle | **P3** CharacterPanel-ish |
| 2354–2755 | Achievement toast (`achToast`) | **P1** → `Utils\UI\AchievementToast.lua` |
| 2757–2797 | Outleveled indicator | P3 / keep near panel |
| 2799–3050 | Progress helpers (`progressFlush`, Get/SetProgress) | **P1** → `Utils\Core\Progress.lua` |
| 3052–3220 | Minimap + AddonCompartment | **P1** → `Utils\UI\MinimapButton.lua` |
| 3222–3432 | initFrame events (login / ADDON_LOADED) | Bootstrap (stays late) |
| 3433–4544 | Setting up the Interface | **P3** |
| 4545–5104 | Creating achievement functionality / rows | **P3** |
| 5105–6530 | Kill event bridge (`do` + `achEvt`) | **P2** → `Utils\Combat\KillBridge.lua` |
| 6532–6563 | Emote hook | P2-adjacent or with KillBridge |
| 6565–6780 | Tab click / ShowAchievementTab | P3 |
| 6783–6900 | Deferred registration + finalization | Bootstrap (stays) |

---

## Target layout

```
Utils\Core\Hooks.lua
Utils\Core\AchievementRegistry.lua
Utils\Core\Progress.lua              -- Get/Set/ClearProgress, progressFlush, unsaved banner
Utils\Core\SavedVariables.lua        -- later
Utils\UI\AchievementToast.lua
Utils\UI\MinimapButton.lua
Utils\UI\CharacterPanel.lua          -- later
Utils\Combat\KillBridge.lua          -- Phase 2
HardcoreAchievements.lua             -- thin bootstrap + remaining UI until P3
```

TOC for Phase 1+2 (as landed):

```
Utils\Core\Hooks.lua
Utils\Core\AchievementRegistry.lua
Utils\UI\AchievementToast.lua
Utils\Core\Progress.lua
Utils\UI\MinimapButton.lua
HardcoreAchievements.lua
Utils\Combat\KillBridge.lua          -- AFTER main (needs MarkRowCompleted on addon)
```

---

## Extraction rules (every phase)

1. **Call-time lookups** for cross-file deps (`addon.GetCharDB()`, not a load-time upvalue that is still nil).
2. Prefer **`addon.Foo = …`** exports; avoid new file-level locals that other files must close over.
3. Promote shared flags used across files onto `addon` when extracting:
   - `addon.RestorationsComplete` (today: local `restorationsComplete`)
   - keep `addon.Initializing`, `addon.SetSkipAchievementBroadcast`
   - optional: `addon.IsSkippingAchievementBroadcast()` if SetProgress needs it without a local
4. After each extract: `/reload`, open dashboard, complete or restore an achievement, confirm toast + unsaved banner + minimap.
5. Do not leave duplicate definitions (old locals + new module) that shadow each other.
6. Keep comments that explain *why* (200-local packing, Initializing grace, etc.).

---

## Phase 1 — Quick wins (in progress)

**Order inside Phase 1** (dependency-friendly):

### 1A. `Utils\Core\Hooks.lua`
- Move HookSystem + `HardcoreAchievementsHooks` public namespace.
- Export `addon.Hooks`.
- Remove from monolith; leave a one-line comment pointing at the new file.

### 1B. `Utils\Core\AchievementRegistry.lua`
- Move `AchievementFunctionRegistry`, `CustomAchievementHandlers`, register/get helpers.
- Preserve `addon.RegistrationQueue` init (`or {}`) so catalogs can queue before finalization.
- Export the same `addon.Register*` / `Get*` names.

### 1C. `Utils\UI\AchievementToast.lua`
- Move `achToast` table, frame factory, queue, `CreateAchToast`, sound gate if tightly coupled.
- Export `addon.CreateAchToast` (and keep global `CreateAchToast` alias if anything still expects the forward-declared local — prefer routing monolith callers through `addon.CreateAchToast` or a thin local alias after load).
- Forever Y offset (`-300`) stays.
- GuildFirst toasts remain separate (`Utils\GuildFirst.lua`).

### 1D. `Utils\Core\Progress.lua`
- Move together:
  - `ClearProgress`
  - Unsaved reminder frame + `MarkUnsavedAchievementProgress` / visibility
  - `GetProgress` / `SetProgress`
  - `progressFlush` (dirty coalesce, ValuesEqual, trivial write filter, unsavedKeys)
- **Deps (call-time):** `addon.GetCharDB`, outleveled invalidate/apply/refresh helpers, `addon.CheckPendingCompletions`, `addon.RefreshAllAchievementPoints`, `addon.Initializing`, restorations / skip-broadcast flags.
- **Prerequisite in monolith:** export `addon.GetCharDB` immediately after `GetCharDB` is defined (do not wait until the old mid-file export block). Mirror `restorationsComplete` onto `addon.RestorationsComplete` wherever it is set/read so Progress does not need a monolith local.
- Main file keeps SV/`sv.*` until a later phase; Progress only *consumes* GetCharDB.

### 1E. `Utils\UI\MinimapButton.lua`
- Move LDB/LibDBIcon setup, show/hide API, AddonCompartment globals, `OpenOptionsPanel` if only used here (or keep OpenOptions on addon from this file).
- **Deps (call-time):** `addon.GetCharDB` / EnsureDB pattern, `addon.AchievementCount`, `ToggleHardcoreAchievementsUI` (export as `addon.ToggleHardcoreAchievementsUI` if needed), Leaderboard rank tooltip.
- `HardcoreAchievements_Toggle` / compartment globals must remain **global** (Bindings.xml / TOC).
- PLAYER_LOGIN in monolith still *calls* `InitializeMinimapButton` via `addon.InitializeMinimapButton`.

### Phase 1 verification checklist
- [ ] Addon loads with no Lua errors
- [ ] `/reload` while resting does **not** show false unsaved banner
- [ ] Completing an achievement shows toast (queue still serializes)
- [ ] Minimap left/right/shift-right clicks work; compartment tooltip works
- [ ] Catalog registration still works (`RegisterAchievementFunction` / custom handlers)
- [ ] Main-chunk local pressure visibly down (room to add helpers without table-packing)

---

## Phase 2 — Kill bridge (highest leverage)

### Target: `Utils\Combat\KillBridge.lua`
- Move the entire `do … end` block at “Event bridge: forward PARTY_KILL…” (~5105–6530).
- Keep `addon.AchEvt` frame + `guidClaimedAt` / `encounterClaimedAt` on the frame (already local-budget aware).
- Inside the new file, nested locals are fine — **new 200 budget**.
- Prefer clarifying names once extracted; avoid drive-by behavior changes.
- Optional same-phase: Cross-locale Emote Hook (~6532–6563) if it only needs `MarkRowCompleted` / `CreateAchToast` / `IsAchievementAlreadyCompleted` via `addon.*`.

### Deps (call-time via addon)
- `MarkRowCompleted`, `CreateAchToast`, `GetProgress` / `SetProgress`
- Forever kill helpers already loaded earlier in TOC (`KillTracking`, `EncounterKills`, `LootKills`, `RareLootKills`)
- `PlayerIsSolo_*`, combat log helpers

### Phase 2 verification checklist
- [ ] Open-world PARTY_KILL still credits trackers
- [ ] Dungeon ENCOUNTER_END + loot fallback still work (Stockade / BFD style)
- [ ] Tracker highlights on kill without waiting for loot
- [ ] No duplicate credit across GUID kill vs encounter within dedupe window
- [ ] Emote achievements still complete if emote hook moved

---

## Phase 3 — Character panel / row factory (later)

- `Utils\UI\CharacterPanel.lua`: “Setting up the Interface” + “Creating the functionality of achievements” + tab click.
- Includes `CreateAchievementRow`, filters, SortAchievementRows, border/text layout helpers as needed.
- Highest wiring cost (`Tab` forward decl, CharacterFrame hooks, Forever legacy tabs).
- Do only after Phase 1–2 are stable.

---

## Phase 4 — Thin bootstrap + cleanup (later)

`HardcoreAchievements.lua` should only:
- ADDON_LOADED / PLAYER_LOGIN orchestration
- Registration queue finalization + Initializing grace
- Glue that does not yet have a home

Then cleanup:
- Deduplicate helpers that already exist in `SharedUtils.lua`
- Document the stable `addon.*` API surface (short comment block or `Utils\Core\API.md` only if useful)
- Remove obsolete “packed onto table for 200-local” comments where the pressure is gone
- Consider `Utils\Core\SavedVariables.lua` extract if SV block still bloats bootstrap

---

## Progress tracking

| Phase | Status | Notes |
|-------|--------|-------|
| Plan doc | Done | This file |
| 1A Hooks | Done | `Utils\Core\Hooks.lua` |
| 1B Registry | Done | `Utils\Core\AchievementRegistry.lua` |
| 1C Toast | Done | `Utils\UI\AchievementToast.lua` (+ sound gate) |
| 1D Progress | Done | `Utils\Core\Progress.lua` (banner + Get/Set/Clear + flush) |
| 1E Minimap | Done | `Utils\UI\MinimapButton.lua` |
| 2 KillBridge | Done | `Utils\Combat\KillBridge.lua` (+ emote hook); loads **after** main |
| 3 CharacterPanel | Not started | |
| 4 Bootstrap cleanup | Not started | |

Main file reduced ~6922 → ~4489 lines after Phase 1+2.

### In-game verification still needed
- [ ] `/reload` resting: no false unsaved banner
- [ ] Toast queue + Forever Y offset
- [ ] Minimap / compartment clicks
- [ ] Dungeon kill credit (ENCOUNTER_END + PARTY_KILL) + tracker highlight
- [ ] Emote achievements

### Pitfall: multi-return via `and`
Never write `local _, cdb = addon.GetCharDB and addon.GetCharDB()`.
Lua `and` keeps only the **first** return value (account `db`), so `cdb` is always nil and
`SetProgress`/`GetProgress` silently no-op. That caused RFK boss prints with zero UI progress.
Use a direct call: `local fn = addon.GetCharDB; return fn()`.

Update the Status column as each slice lands.

---

## Rollback

Each phase is TOC + move + delete-from-monolith. To roll back one slice: restore the section in `HardcoreAchievements.lua`, remove the new file from TOC, delete the new file. Prefer rolling back a single slice rather than the whole phase.
