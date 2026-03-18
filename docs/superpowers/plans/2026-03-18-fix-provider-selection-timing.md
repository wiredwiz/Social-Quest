# Fix: AQL Provider Selection Timing — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `AQL:GetChainInfo` returning `knownStatus = "unknown"` for all quests by correcting Questie's access path and adding a timer-based provider upgrade that fires after both Questie and QuestWeaver finish their async initialization.

**Architecture:** Two independent changes in the AQL repo: (1) `QuestieProvider.lua` — replace all global `QuestieDB.*` accesses with a `getDB()` module helper that routes through `QuestieLoader`; (2) `EventEngine.lua` — add a `tryUpgradeProvider` retry loop using `C_Timer.After` that fires after `PLAYER_LOGIN`, plus a belt-and-suspenders check in `handleQuestLogUpdate`.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AbsoluteQuestLog-1.0. No test runner — verification is by reading the edited files and in-game testing.

---

## Chunk 1: QuestieProvider.lua

### Task 1: Update `QuestieProvider.lua` — replace all `QuestieDB.*` with module-based `getDB()`

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/QuestieProvider.lua`

**Background for the implementer:**

`QuestieDB` is never a global. It lives inside Questie's private module system as `QuestieLoader:CreateModule("QuestieDB")`. The only correct access path is `QuestieLoader:ImportModule("QuestieDB")`, where `QuestieLoader` IS a global. `QuestieDB.GetQuest` is a **static function** (dot notation) — calling `db.GetQuest(questID)` is correct; no `self` is needed.

`QuestieDB:Initialize()` runs asynchronously (~3 s after `PLAYER_LOGIN`). `QuestieDB.QuestPointers` is only set after `Initialize()` completes. `getDB()` must return `nil` if `QuestPointers` is `nil`, so the provider isn't considered available until the DB is fully compiled.

**Important cache invalidation detail:** `buildReverseChain` caches its result in the module-level `reverseChain` variable. When `getDB()` returns nil (DB not yet ready), the function must return an empty table WITHOUT caching it, so future calls will re-try once the DB is ready. Only assign `reverseChain = {}` after confirming `getDB()` is not nil.

- [ ] **Step 1: Read the file to confirm current state**

  Read `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/QuestieProvider.lua` lines 1–229.

  Expected: `IsAvailable()` at lines 21–24 checks `type(QuestieDB) == "table"`. `buildReverseChain` at lines 34–49 uses `QuestieDB.QuestPointers` and `pcall(QuestieDB.GetQuest, questID)`. `buildChain` at lines 65–99 uses `QuestieDB.GetQuest` twice. `GetChainInfo` at lines 101–174 uses `QuestieDB.GetQuest(sid)` at lines 146 and 162. `GetQuestBasicInfo` at lines 184–198 uses `pcall(QuestieDB.GetQuest, questID)`. `GetQuestType` at line 201 and `GetQuestFaction` at line 220 each use `QuestieDB.GetQuest(questID)`.

- [ ] **Step 2: Replace the file header comment and insert `getDB()` above `IsAvailable()`**

  Replace lines 1–24 (file header through the closing `end` of `IsAvailable`) with the following. This removes the incorrect global-`QuestieDB` check and adds the `getDB()` helper with its `QuestPointers` readiness guard.

  ```lua
  -- Providers/QuestieProvider.lua
  -- Reads chain metadata from Questie if installed.
  -- Questie stores quest data in a private module system (QuestieLoader).
  -- Access path: QuestieLoader:ImportModule("QuestieDB").GetQuest(questID)
  -- Relevant fields on a quest object:
  --   quest.nextQuestInChain  (questID of next step, or 0)
  -- Type info comes from quest.questTagId / quest.questFlags.

  local AQL = LibStub("AbsoluteQuestLog-1.0", true)
  if not AQL then return end

  local QuestieProvider = {}

  -- questTagIds enum values from QuestieDB (QuestieDB.lua questKeys):
  --   ELITE = 1, RAID = 62, DUNGEON = 81
  -- Daily is detected via quest.questFlags (bit 1 = DAILY in classic era flags).
  local TAG_ELITE   = 1
  local TAG_RAID    = 62
  local TAG_DUNGEON = 81

  -- Returns the live QuestieDB module reference, or nil if Questie is not loaded
  -- or its database has not yet been compiled (Initialize() not yet run).
  -- pcall guards against ImportModule calling error() when the module is not
  -- registered (can happen if Questie is present but partially initialized).
  -- pcall cannot use colon syntax; self must be passed as the first argument explicitly.
  local function getDB()
      if type(QuestieLoader) ~= "table" then return nil end
      local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
      if not ok or not db or type(db.GetQuest) ~= "function" then return nil end
      -- QuestPointers is set by QuestieDB:Initialize(), which runs asynchronously
      -- after PLAYER_LOGIN. Nil here means the database is not compiled yet.
      if db.QuestPointers == nil then return nil end
      return db
  end

  -- Returns true if Questie is available and the provider can be used.
  function QuestieProvider:IsAvailable()
      return getDB() ~= nil
  end
  ```

- [ ] **Step 3: Update `buildReverseChain()` to use `getDB()`**

  Replace the entire `buildReverseChain` function (lines 34–49 in the original).

  **Key detail:** when `getDB()` returns nil the function returns `{}` directly WITHOUT assigning it to the module-level `reverseChain` variable. This prevents caching a stale empty result — future calls will retry once the DB is ready.

  Old code:
  ```lua
  local function buildReverseChain()
      if reverseChain then return reverseChain end
      reverseChain = {}
      local pointers = QuestieDB.QuestPointers or QuestieDB.questPointers
      if type(pointers) ~= "table" then
          -- QuestPointers not available in this Questie version. reverseChain stays empty.
          return reverseChain
      end
      for questID in pairs(pointers) do
          local ok, q = pcall(QuestieDB.GetQuest, questID)
          if ok and q and q.nextQuestInChain and q.nextQuestInChain ~= 0 then
              reverseChain[q.nextQuestInChain] = questID
          end
      end
      return reverseChain
  end
  ```

  New code:
  ```lua
  local function buildReverseChain()
      if reverseChain then return reverseChain end
      local db = getDB()
      if not db then return {} end  -- DB not ready; return empty but don't cache
      reverseChain = {}
      local pointers = db.QuestPointers or db.questPointers
      if type(pointers) ~= "table" then
          -- QuestPointers not available in this Questie version. reverseChain stays empty.
          return reverseChain
      end
      for questID in pairs(pointers) do
          local ok, q = pcall(db.GetQuest, questID)
          if ok and q and q.nextQuestInChain and q.nextQuestInChain ~= 0 then
              reverseChain[q.nextQuestInChain] = questID
          end
      end
      return reverseChain
  end
  ```

- [ ] **Step 4: Update `buildChain()` to use `getDB()`**

  Replace the entire `buildChain` function (lines 65–99 in the original). Add `local db = getDB()` guard at the top; replace the two `QuestieDB.GetQuest` calls with `db.GetQuest`.

  Old code:
  ```lua
  local function buildChain(startQuestID)
      local quest = QuestieDB.GetQuest(startQuestID)
      if not quest then return nil end

      local nextID = quest.nextQuestInChain
      if not nextID or nextID == 0 then
          -- Check if any quest points TO startQuestID (startQuestID may be a later step).
          local rev = buildReverseChain()
          if not rev[startQuestID] then
              return nil  -- standalone quest
          end
          -- startQuestID is a later step in a chain; fall through to root-finding below.
      end

      -- Find the true chain root by walking backward.
      local chainRoot = findChainRoot(startQuestID)

      -- Collect all steps by walking forward from the root.
      local steps = {}
      local current = chainRoot
      local visited = { [chainRoot] = true }

      while current do
          table.insert(steps, { questID = current })
          local q = QuestieDB.GetQuest(current)
          local nxt = q and q.nextQuestInChain
          if not nxt or nxt == 0 or visited[nxt] then break end
          visited[nxt] = true
          current = nxt
      end

      if #steps < 2 then return nil end  -- single-step "chain" is just a standalone quest

      return { chainRoot = chainRoot, steps = steps }
  end
  ```

  New code:
  ```lua
  local function buildChain(startQuestID)
      local db = getDB()
      if not db then return nil end
      local quest = db.GetQuest(startQuestID)
      if not quest then return nil end

      local nextID = quest.nextQuestInChain
      if not nextID or nextID == 0 then
          -- Check if any quest points TO startQuestID (startQuestID may be a later step).
          local rev = buildReverseChain()
          if not rev[startQuestID] then
              return nil  -- standalone quest
          end
          -- startQuestID is a later step in a chain; fall through to root-finding below.
      end

      -- Find the true chain root by walking backward.
      local chainRoot = findChainRoot(startQuestID)

      -- Collect all steps by walking forward from the root.
      local steps = {}
      local current = chainRoot
      local visited = { [chainRoot] = true }

      while current do
          table.insert(steps, { questID = current })
          local q = db.GetQuest(current)
          local nxt = q and q.nextQuestInChain
          if not nxt or nxt == 0 or visited[nxt] then break end
          visited[nxt] = true
          current = nxt
      end

      if #steps < 2 then return nil end  -- single-step "chain" is just a standalone quest

      return { chainRoot = chainRoot, steps = steps }
  end
  ```

- [ ] **Step 5: Update the two `QuestieDB.GetQuest` calls inside `GetChainInfo()`**

  There are two `QuestieDB.GetQuest(sid)` calls inside the loop at the bottom of `GetChainInfo` (original lines 146 and 162). Add `local db = getDB()` guard at the very start of the function and replace both calls.

  Replace the opening two lines of `GetChainInfo`:

  Old:
  ```lua
  function QuestieProvider:GetChainInfo(questID)
      local chain = buildChain(questID)
  ```

  New:
  ```lua
  function QuestieProvider:GetChainInfo(questID)
      local db = getDB()
      if not db then return { knownStatus = "unknown" } end
      local chain = buildChain(questID)
  ```

  Replace the first `QuestieDB.GetQuest` call (original line 146):

  Old:
  ```lua
              local stepQuestData = QuestieDB.GetQuest(sid)
  ```
  New:
  ```lua
              local stepQuestData = db.GetQuest(sid)
  ```

  Replace the second `QuestieDB.GetQuest` call (original line 162):

  Old:
  ```lua
          local sq = QuestieDB.GetQuest(sid)
  ```
  New:
  ```lua
          local sq = db.GetQuest(sid)
  ```

- [ ] **Step 6: Update `GetQuestBasicInfo()`, `GetQuestType()`, and `GetQuestFaction()`**

  **`GetQuestBasicInfo`** — replace `self:IsAvailable()` with `getDB()` and keep the `pcall` wrapper (it guards against unexpected `GetQuest` errors):

  Old opening:
  ```lua
  function QuestieProvider:GetQuestBasicInfo(questID)
      if not self:IsAvailable() then return nil end
      local ok, quest = pcall(QuestieDB.GetQuest, questID)
      if not ok or not quest then return nil end
  ```
  New:
  ```lua
  function QuestieProvider:GetQuestBasicInfo(questID)
      local db = getDB()
      if not db then return nil end
      local ok, quest = pcall(db.GetQuest, questID)
      if not ok or not quest then return nil end
  ```

  **`GetQuestType`** — replace the bare `QuestieDB.GetQuest` call:

  Old opening:
  ```lua
  function QuestieProvider:GetQuestType(questID)
      local quest = QuestieDB.GetQuest(questID)
      if not quest then return nil end
  ```
  New:
  ```lua
  function QuestieProvider:GetQuestType(questID)
      local db = getDB()
      if not db then return nil end
      local quest = db.GetQuest(questID)
      if not quest then return nil end
  ```

  **`GetQuestFaction`** — same pattern:

  Old opening:
  ```lua
  function QuestieProvider:GetQuestFaction(questID)
      local quest = QuestieDB.GetQuest(questID)
      if not quest then return nil end
  ```
  New:
  ```lua
  function QuestieProvider:GetQuestFaction(questID)
      local db = getDB()
      if not db then return nil end
      local quest = db.GetQuest(questID)
      if not quest then return nil end
  ```

- [ ] **Step 7: Verify the edit**

  Read `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/QuestieProvider.lua` lines 1–240. Confirm:
  - `getDB()` is present with `QuestPointers == nil` guard, returning the module ref or nil
  - `IsAvailable()` body is exactly `return getDB() ~= nil`
  - `buildReverseChain` returns `{}` (uncached) when `db` is nil; otherwise sets `reverseChain = {}` and uses `db.QuestPointers`, `db.questPointers`, `pcall(db.GetQuest, questID)`
  - `buildChain` opens with `local db = getDB(); if not db then return nil end` and uses `db.GetQuest` in both places
  - `GetChainInfo` opens with `local db = getDB()` guard and uses `db.GetQuest(sid)` in both loop sites (lines ~146 and ~162 in new numbering)
  - `GetQuestBasicInfo` uses `getDB()` guard and `pcall(db.GetQuest, questID)`
  - `GetQuestType` and `GetQuestFaction` use `getDB()` guard and `db.GetQuest(questID)`
  - Zero remaining bare `QuestieDB.*` references anywhere in the file

- [ ] **Step 8: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" add Providers/QuestieProvider.lua
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" commit -m "fix: access QuestieDB via QuestieLoader module system; guard on QuestPointers for readiness"
  ```

  Expected: 1 file changed, ~20 insertions, ~12 deletions.

---

## Chunk 2: EventEngine.lua

### Task 2: Update `EventEngine.lua` — add timer-based provider upgrade

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/Core/EventEngine.lua`

**Background for the implementer:**

`selectProvider()` currently runs only once at `PLAYER_LOGIN`. Both QuestWeaver (populates `qw.Quests` in its own `PLAYER_LOGIN` handler, which fires *after* AQL's because "QuestWeaver" > "Absolute-Quest-Log" alphabetically) and Questie (async coroutine, ~3 seconds) aren't ready at that instant. The fix:

1. After `PLAYER_LOGIN` setup completes, schedule `C_Timer.After(0, ...)` — this defers until after the current event handler returns, by which point QuestWeaver's handler has already run.
2. If QuestWeaver isn't found on that first attempt, retry every second for up to 5 more seconds (catches Questie's ~3 s coroutine).
3. On success, set `AQL.provider` and call `AQL.QuestCache:Rebuild()` directly (no diff — just refreshes chain data). The return value of `Rebuild()` (old cache) is intentionally discarded.
4. Add a cheap belt-and-suspenders check at the top of `handleQuestLogUpdate`: if still on `NullProvider`, try `selectProvider()` once more before rebuilding.

`AQL.NullProvider` is a pre-existing sentinel defined in `Providers/NullProvider.lua`. `selectProvider()` returns two values (`provider, providerName`); `providerName` is intentionally discarded in `tryUpgradeProvider` and the belt-and-suspenders block — identical to how the current PLAYER_LOGIN handler already discards it (never stored on `AQL`).

- [ ] **Step 1: Read the file to confirm current state**

  Read `D:/Projects/Wow Addons/Absolute-Quest-Log/Core/EventEngine.lua` lines 1–271.

  Expected:
  - `EventEngine.frame = frame` at line 27
  - `-- Provider selection` separator at line 29
  - `selectProvider()` spanning lines 33–56, ending with `return AQL.NullProvider, "none"` and closing `end`
  - `-- Diff + dispatch logic` separator at line 58
  - `handleQuestLogUpdate()` at lines 196–203 with three lines: initialized guard, `Rebuild()`, `runDiff()`
  - `PLAYER_LOGIN` handler opens at line 210; last `frame:RegisterEvent` call (`QUEST_WATCH_LIST_CHANGED`) at line 228; `elseif event == "QUEST_TURNED_IN"` at line 230

- [ ] **Step 2: Add `MAX_DEFERRED_UPGRADE_ATTEMPTS` constant after `EventEngine.frame = frame`**

  The constant is file-local (`local`). Insert it between `EventEngine.frame = frame` and the `-- Provider selection` separator.

  Old text:
  ```lua
  -- Hidden event frame.
  local frame = CreateFrame("Frame")
  EventEngine.frame = frame

  ------------------------------------------------------------------------
  -- Provider selection
  ------------------------------------------------------------------------
  ```

  New text:
  ```lua
  -- Hidden event frame.
  local frame = CreateFrame("Frame")
  EventEngine.frame = frame

  -- Number of deferred 1-second retry attempts after the initial frame-0 attempt.
  -- Total checks: 1 immediate (t=0) + 5 retries (t=1s–5s) = 6 total, up to 5 s.
  local MAX_DEFERRED_UPGRADE_ATTEMPTS = 5

  ------------------------------------------------------------------------
  -- Provider selection
  ------------------------------------------------------------------------
  ```

- [ ] **Step 3: Insert `tryUpgradeProvider` between `selectProvider` and `-- Diff + dispatch logic`**

  Insert after the closing `end` of `selectProvider`, before the `-- Diff + dispatch logic` separator.

  Old text:
  ```lua
      -- Fallback.
      return AQL.NullProvider, "none"
  end

  ------------------------------------------------------------------------
  -- Diff + dispatch logic
  ------------------------------------------------------------------------
  ```

  New text:
  ```lua
      -- Fallback.
      return AQL.NullProvider, "none"
  end

  -- Retries provider selection until a real provider is found or attempts run out.
  -- Called once from PLAYER_LOGIN via C_Timer.After(0, ...) so it fires after all
  -- other addons' PLAYER_LOGIN handlers complete. Retries every 1 s for up to 5 s
  -- to catch Questie, whose async init coroutine takes ~3 s.
  -- On success, rebuilds the cache immediately so chain data is populated without
  -- waiting for the next game event. The old-cache return value from Rebuild() is
  -- intentionally discarded — no diff is needed, only a data refresh.
  -- providerName (second return of selectProvider) is intentionally discarded;
  -- it is not stored on AQL anywhere in this file.
  local function tryUpgradeProvider(attemptsLeft)
      if AQL.provider ~= AQL.NullProvider then return end  -- already upgraded

      local provider = selectProvider()
      if provider ~= AQL.NullProvider then
          AQL.provider = provider
          AQL.QuestCache:Rebuild()
          return
      end

      if attemptsLeft > 0 then
          C_Timer.After(1, function() tryUpgradeProvider(attemptsLeft - 1) end)
      end
  end

  ------------------------------------------------------------------------
  -- Diff + dispatch logic
  ------------------------------------------------------------------------
  ```

- [ ] **Step 4: Replace `handleQuestLogUpdate` with belt-and-suspenders version**

  Old code:
  ```lua
  local function handleQuestLogUpdate()
      if not EventEngine.initialized then return end

      local oldCache = AQL.QuestCache:Rebuild()
      if oldCache == nil then return end  -- Rebuild failed (re-entrant guard from QuestCache side)

      runDiff(oldCache)
  end
  ```

  New code:
  ```lua
  local function handleQuestLogUpdate()
      if not EventEngine.initialized then return end

      -- Belt-and-suspenders: re-attempt provider selection if still on NullProvider.
      -- tryUpgradeProvider handles the common case via C_Timer; this is a fallback
      -- in case the upgrade window was missed. One comparison per rebuild — no cost.
      -- providerName (second return of selectProvider) is intentionally discarded.
      if AQL.provider == AQL.NullProvider then
          local provider = selectProvider()
          if provider ~= AQL.NullProvider then
              AQL.provider = provider
          end
      end

      local oldCache = AQL.QuestCache:Rebuild()
      if oldCache == nil then return end  -- Rebuild failed (re-entrant guard from QuestCache side)

      runDiff(oldCache)
  end
  ```

- [ ] **Step 5: Add `C_Timer.After` call in the `PLAYER_LOGIN` handler**

  In the `PLAYER_LOGIN` block, insert the deferred upgrade call after the last `frame:RegisterEvent` call and before the closing blank line / `elseif`.

  Old text:
  ```lua
          -- Register for quest events now that we're ready.
          frame:RegisterEvent("QUEST_ACCEPTED")
          frame:RegisterEvent("QUEST_REMOVED")
          frame:RegisterEvent("QUEST_TURNED_IN")
          frame:RegisterEvent("QUEST_LOG_UPDATE")
          frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
          frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")

      elseif event == "QUEST_TURNED_IN" then
  ```

  New text:
  ```lua
          -- Register for quest events now that we're ready.
          frame:RegisterEvent("QUEST_ACCEPTED")
          frame:RegisterEvent("QUEST_REMOVED")
          frame:RegisterEvent("QUEST_TURNED_IN")
          frame:RegisterEvent("QUEST_LOG_UPDATE")
          frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
          frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")

          -- Deferred provider upgrade: fires after all PLAYER_LOGIN handlers complete.
          -- QuestWeaver is caught on the first attempt (its PLAYER_LOGIN handler runs
          -- before C_Timer.After(0, ...) callbacks fire). Questie may take ~3 s;
          -- retries cover up to 5 s total.
          C_Timer.After(0, function() tryUpgradeProvider(MAX_DEFERRED_UPGRADE_ATTEMPTS) end)

      elseif event == "QUEST_TURNED_IN" then
  ```

- [ ] **Step 6: Verify the edit**

  Read `D:/Projects/Wow Addons/Absolute-Quest-Log/Core/EventEngine.lua` lines 1–295. Confirm:
  - `local MAX_DEFERRED_UPGRADE_ATTEMPTS = 5` is present after `EventEngine.frame = frame`, before the `-- Provider selection` separator
  - `tryUpgradeProvider` function is present between the closing `end` of `selectProvider` and `-- Diff + dispatch logic`
  - `handleQuestLogUpdate` opens with the `AQL.provider == AQL.NullProvider` check before calling `Rebuild()`
  - `C_Timer.After(0, function() tryUpgradeProvider(MAX_DEFERRED_UPGRADE_ATTEMPTS) end)` is inside the `PLAYER_LOGIN` block after `frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")`
  - No other lines in the file were accidentally modified
  - The `selectProvider` function itself is unchanged

- [ ] **Step 7: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" add Core/EventEngine.lua
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" commit -m "fix: add timer-based provider upgrade at login; belt-and-suspenders in handleQuestLogUpdate"
  ```

  Expected: 1 file changed, ~35 insertions, ~5 deletions.

---

## In-Game Verification

After both commits, reload the game and verify in WoW TBC Anniversary:

1. **QuestWeaver detection** — Log in with Questie disabled, QuestWeaver enabled. Within 1 second of login run in WowLua:
   ```lua
   local AQL = LibStub("AbsoluteQuestLog-1.0")
   print(AQL.provider == AQL.QuestWeaverProvider and "QuestWeaver" or "WRONG: "..tostring(AQL.provider))
   ```
   Confirm: prints `QuestWeaver`.

2. **Questie detection** — Enable Questie, disable QuestWeaver, reload. Wait at least 6 seconds, then run:
   ```lua
   local AQL = LibStub("AbsoluteQuestLog-1.0")
   print(AQL.provider == AQL.QuestieProvider and "Questie" or "WRONG: "..tostring(AQL.provider))
   ```
   Confirm: prints `Questie`.

3. **Questie takes priority** — Enable both. Wait 6 seconds. Confirm provider prints `Questie`.

4. **NullProvider fallback** — Disable both, reload. Confirm `NullProvider`.

5. **Chain data populated** — With Questie or QuestWeaver enabled, accept a quest that is part of a known chain. Run:
   ```lua
   local AQL = LibStub("AbsoluteQuestLog-1.0")
   for questID, info in pairs(AQL:GetAllQuests()) do
       local ci = info.chainInfo
       if ci and ci.knownStatus == "known" then
           print("chain found: questID="..questID.." step="..tostring(ci.step).."/"..tostring(ci.length))
           break
       end
   end
   ```
   Confirm: at least one quest prints with `knownStatus = "known"` and valid step/length.
