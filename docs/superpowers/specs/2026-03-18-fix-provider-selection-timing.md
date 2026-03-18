# Fix: AQL Provider Selection Timing — Design Spec

## Overview

`AQL:GetChainInfo` returns `{ knownStatus = "unknown" }` for all quests even when
Questie or QuestWeaver is installed. Two independent bugs combine to cause this:

1. **Questie not detected** — `QuestieProvider:IsAvailable()` checks for a global
   `QuestieDB` that never exists. Questie stores its database in a private module
   system (`QuestieLoader:CreateModule`) that is only exposed globally in debug mode.
2. **Provider selected too early** — `selectProvider()` runs inside AQL's
   `PLAYER_LOGIN` handler. Both Questie (async coroutine, ~3 seconds) and QuestWeaver
   (synchronous but its own `PLAYER_LOGIN` handler fires after AQL's) are not ready
   at that instant. NullProvider is selected and never re-evaluated.

---

## Root Cause Detail

### Questie access pattern

`QuestieDB` is `QuestieLoader:CreateModule("QuestieDB")` — a table stored in
`QuestieLoader._modules["QuestieDB"]`. The correct access path is
`QuestieLoader:ImportModule("QuestieDB")`. `QuestieLoader` is a global.

`QuestieDB:Initialize()` runs as a coroutine inside `QuestieInit.Stages[1]`, driven
by `QuestieInit:Init()` (called from Questie's `PLAYER_LOGIN` handler). It can take
up to ~3 seconds (uses `C_Timer.NewTicker(1, ...)` to wait for the game cache, up to
3 retries). `QuestieDB.QuestPointers` is set inside `Initialize()` and serves as a
reliable signal that the database is fully compiled and ready.

### QuestWeaver timing

`_G["QuestWeaver"] = qw` is set at file load time, but `qw.Quests = {}` is empty
until `LoadAllZoneData()` runs inside QuestWeaver's `PLAYER_LOGIN` handler.
AQL's handler fires first (addon folder "Absolute-Quest-Log" sorts before
"QuestWeaver"), so `next(qw.Quests) ~= nil` is false when `selectProvider()` runs.

---

## Fix

### Part 1 — `QuestieProvider.lua`: correct access path and readiness check

Replace the global `QuestieDB` references with a `getDB()` helper that accesses the
module through `QuestieLoader`. Add a `QuestPointers ~= nil` guard to the
availability check so the provider only reports ready after `Initialize()` has run:

```lua
-- Returns the live QuestieDB module reference, or nil if Questie is not loaded
-- or its database has not yet been compiled (Initialize() not yet run).
-- pcall guards against ImportModule calling error() when the module is not
-- registered (can happen if Questie is present but partially initialized).
local function getDB()
    if type(QuestieLoader) ~= "table" then return nil end
    local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
    if not ok or not db or type(db.GetQuest) ~= "function" then return nil end
    return db
end

function QuestieProvider:IsAvailable()
    local db = getDB()
    if not db then return false end
    -- QuestPointers is set by QuestieDB:Initialize(), which runs asynchronously
    -- after PLAYER_LOGIN. Nil means the database is not compiled yet.
    return db.QuestPointers ~= nil
end
```

All internal uses of `QuestieDB.*` are updated to call `getDB()` and operate on the
returned reference. `QuestieDB.GetQuest` is a static function (dot notation) —
calling `db.GetQuest(questID)` is correct and does not require `self`.

### Part 2 — `EventEngine.lua`: timer-based provider upgrade

Add a `tryUpgradeProvider` function and a `MAX_DEFERRED_UPGRADE_ATTEMPTS` constant.
`providerName` (the second return value of `selectProvider`) is intentionally
discarded in `tryUpgradeProvider` — identical to how the current `PLAYER_LOGIN`
handler already discards it (it is not stored on `AQL` and has no use after the
initial login log line). `AQL.NullProvider` is a pre-existing sentinel field defined
in `Providers/NullProvider.lua`; it is not introduced by this fix.

```lua
local MAX_DEFERRED_UPGRADE_ATTEMPTS = 5  -- 1 immediate + 5 deferred (1 s each) = 6 total attempts, up to 5 s

local function tryUpgradeProvider(attemptsLeft)
    if AQL.provider ~= AQL.NullProvider then return end  -- already upgraded

    local provider = selectProvider()  -- providerName discarded (not stored on AQL)
    if provider ~= AQL.NullProvider then
        AQL.provider = provider
        -- Rebuild immediately so chain data is populated without waiting for a
        -- game event. Called directly (not via handleQuestLogUpdate) so no diff
        -- fires — quest-accepted/abandoned callbacks are not re-emitted.
        -- Return value (old cache) is intentionally discarded; no diff is needed.
        AQL.QuestCache:Rebuild()
        return
    end

    if attemptsLeft > 0 then
        C_Timer.After(1, function() tryUpgradeProvider(attemptsLeft - 1) end)
    end
end
```

Called from the `PLAYER_LOGIN` handler after all setup is complete:

```lua
-- Deferred until after the current event handler returns. By that point,
-- QuestWeaver's PLAYER_LOGIN handler has already run and populated qw.Quests,
-- so the first attempt catches QuestWeaver. Subsequent attempts at 1-second
-- intervals catch Questie, which finishes its coroutine within ~3 seconds.
C_Timer.After(0, function() tryUpgradeProvider(MAX_DEFERRED_UPGRADE_ATTEMPTS) end)
```

**Belt-and-suspenders:** `handleQuestLogUpdate` checks `AQL.provider == AQL.NullProvider`
on each call and retries provider selection if so. This costs one comparison per
cache rebuild and ensures correctness if the timer window is somehow missed. The
updated function:

```lua
local function handleQuestLogUpdate()
    if not EventEngine.initialized then return end

    -- Re-attempt provider selection while still on NullProvider.
    -- Both QuestWeaver and Questie initialize asynchronously after PLAYER_LOGIN.
    -- The timer in tryUpgradeProvider handles the common case; this is a fallback.
    if AQL.provider == AQL.NullProvider then
        local provider = selectProvider()  -- providerName discarded
        if provider ~= AQL.NullProvider then
            AQL.provider = provider
        end
    end

    local oldCache = AQL.QuestCache:Rebuild()
    if oldCache == nil then return end
    runDiff(oldCache)
end
```

Note: when the belt-and-suspenders path upgrades the provider, `Rebuild()` runs
immediately after as part of the normal `handleQuestLogUpdate` flow, so chain data
is populated in the same rebuild that fires the diff. No separate `Rebuild()` call
is needed in the fallback path.

---

## Invariants

- `tryUpgradeProvider` is a no-op if `AQL.provider` is already set to a real
  provider, so it is safe to call multiple times.
- The direct `AQL.QuestCache:Rebuild()` inside `tryUpgradeProvider` does not run a
  diff and fires no AQL callbacks.
- The direct `Rebuild()` called inside `tryUpgradeProvider` runs after
  `EventEngine.initialized = true`. If a `QUEST_LOG_UPDATE` fires in rapid succession,
  `handleQuestLogUpdate` would also call `Rebuild()`. Both calls complete
  independently (QuestCache has no re-entrancy guard) and produce identical results —
  this is benign. No re-entrancy guard is required; the double-rebuild is benign and
  adding a guard is out of scope for this fix.
- If neither provider is ready within the upgrade window, chain data remains
  `knownStatus = "unknown"` until the next natural `QUEST_LOG_UPDATE`, where the
  belt-and-suspenders check catches it.
- Priority order is unchanged: Questie > QuestWeaver > NullProvider.

---

## Files Changed

| File | Change |
|------|--------|
| `Absolute-Quest-Log/Providers/QuestieProvider.lua` | Replace global `QuestieDB` with `QuestieLoader`-based `getDB()` helper; update `IsAvailable()` to check `QuestPointers ~= nil`; update all internal `QuestieDB.*` calls |
| `Absolute-Quest-Log/Core/EventEngine.lua` | Add `MAX_DEFERRED_UPGRADE_ATTEMPTS` constant, `tryUpgradeProvider()` function, `C_Timer.After(0, ...)` call in `PLAYER_LOGIN` handler, and belt-and-suspenders retry in `handleQuestLogUpdate` |

`QuestWeaverProvider.lua` is unchanged — its `IsAvailable()` check (`next(qw.Quests) ~= nil`)
is correct. `C_Timer.After(0, ...)` defers until after the current event handler returns;
by that point QuestWeaver's `PLAYER_LOGIN` handler has already fired and `LoadAllZoneData()`
has populated `qw.Quests`, so the first upgrade attempt finds QuestWeaver available.

---

## Testing

1. Log in with both Questie and QuestWeaver enabled.
2. Wait at least 6 seconds for Questie to finish initializing, then run in WowLua:
   ```lua
   local AQL = LibStub("AbsoluteQuestLog-1.0")
   print(AQL.provider == AQL.QuestieProvider and "Questie" or
         AQL.provider == AQL.QuestWeaverProvider and "QuestWeaver" or "NullProvider")
   ```
3. Confirm: prints `Questie` (Questie takes priority).
4. Disable Questie, reload UI, repeat — confirm `QuestWeaver`.
5. Disable both, reload UI — confirm `NullProvider`.
6. With Questie enabled: accept a chain quest; dump AQL chain info; confirm
   `knownStatus = "known"` and correct step/length values.
7. With QuestWeaver enabled (Questie disabled): same check.
