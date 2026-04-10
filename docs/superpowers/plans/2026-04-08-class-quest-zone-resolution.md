# Class Quest Zone Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transmit a numeric class ID alongside class quest data so remote clients can correctly group class quests under the localized class-name zone header in the Party and Shared tabs.

**Architecture:** The sender builds a reverse lookup (`localizedClassNameToID`) from `LOCALIZED_CLASS_NAMES_MALE` at file scope in `Communications.lua` and writes an optional `classID` integer into `SQ_INIT` and `SQ_UPDATE` payloads. Receivers store it on the quest entry; `GetZoneForQuestID` resolves it back to the localized class name at render time via `CLASS_TOKEN_BY_ID` (new in `WowAPI.lua`).

**Tech Stack:** Lua, WoW addon API (`LOCALIZED_CLASS_NAMES_MALE`), AceSerializer (existing), AQL (existing).

---

## Files Modified

| File | Change |
|---|---|
| `Core/WowAPI.lua` | Add `CLASS_TOKEN_BY_ID` table mapping classID → token |
| `Core/Communications.lua` | Add `localizedClassNameToID` reverse lookup; add `classID` field to `buildQuestPayload` and `buildInitPayload` |
| `Core/GroupData.lua` | Add `classID = payload.classID` in `OnUpdateReceived` explicit entry construction |
| `UI/TabUtils.lua` | Update `GetZoneForQuestID(questID, classID)` signature; add classID fast path |
| `tests/TabUtils_test.lua` | Add stubs and tests for new `GetZoneForQuestID` behavior |
| `UI/Tabs/PartyTab.lua` | Build `questClassIDs` lookup; pass to `GetZoneForQuestID` |
| `UI/Tabs/SharedTab.lua` | Build `questClassIDs` lookup; pass to `GetZoneForQuestID` |
| `SocialQuest.toc` | Bump version |
| `CLAUDE.md` | Document the feature |

---

### Task 1: WowAPI.lua — CLASS_TOKEN_BY_ID

**Files:**
- Modify: `Core/WowAPI.lua`

- [ ] **Step 1: Run the existing tests to confirm a clean baseline**

Run from the repo root:
```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both print `Results: N passed, 0 failed` and exit 0.

- [ ] **Step 2: Add `CLASS_TOKEN_BY_ID` to `Core/WowAPI.lua`**

Open `Core/WowAPI.lua`. Find the existing `CLASS_ID` table (around line 77):
```lua
SocialQuestWowAPI.CLASS_ID = {
    Warrior=1, Paladin=2, Hunter=3, Rogue=4, Priest=5, DeathKnight=6,
    Shaman=7, Mage=8, Warlock=9, Monk=10, Druid=11, DemonHunter=12, Evoker=13,
}
```

Add the new table immediately after it:
```lua
-- Maps WoW numeric class ID to the uppercase class token used as a key in
-- LOCALIZED_CLASS_NAMES_MALE and returned by UnitClass() as the second value.
-- Covers all classes across all WoW versions; entries for classes absent from
-- the current version are simply absent from LOCALIZED_CLASS_NAMES_MALE.
SocialQuestWowAPI.CLASS_TOKEN_BY_ID = {
    [1]  = "WARRIOR",
    [2]  = "PALADIN",
    [3]  = "HUNTER",
    [4]  = "ROGUE",
    [5]  = "PRIEST",
    [6]  = "DEATHKNIGHT",
    [7]  = "SHAMAN",
    [8]  = "MAGE",
    [9]  = "WARLOCK",
    [10] = "MONK",
    [11] = "DRUID",
    [12] = "DEMONHUNTER",
    [13] = "EVOKER",
}
```

- [ ] **Step 3: Run tests to confirm no regressions**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both print `Results: N passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add Core/WowAPI.lua
git commit -m "feat: add CLASS_TOKEN_BY_ID table to WowAPI for class quest zone resolution"
```

---

### Task 2: Communications.lua — localizedClassNameToID reverse lookup + classID in payloads

**Files:**
- Modify: `Core/Communications.lua`

- [ ] **Step 1: Add `localizedClassNameToID` reverse lookup at file scope**

Open `Core/Communications.lua`. Find the line near the top that reads:
```lua
local SQWowAPI = SocialQuestWowAPI
```

Add the following block immediately after it (after the alias declaration, before any other locals):
```lua
-- Reverse lookup: localized class name (as used by AQL zone headers) → WoW numeric classID.
-- Built at load time from LOCALIZED_CLASS_NAMES_MALE (always available before addon load).
-- Used by buildInitPayload and buildQuestPayload to detect class quests.
local localizedClassNameToID = {}
do
    local names = LOCALIZED_CLASS_NAMES_MALE
    if names then
        for classID, token in pairs(SQWowAPI.CLASS_TOKEN_BY_ID) do
            local name = names[token]
            if name then localizedClassNameToID[name] = classID end
        end
    end
end
```

- [ ] **Step 2: Add `classID` to `buildQuestPayload`**

Find `buildQuestPayload`. Its `return` statement currently looks like:
```lua
    return {
        questID      = questInfo.questID,
        eventType    = eventType,
        isComplete   = questInfo.isComplete  and 1 or 0,
        isFailed     = questInfo.isFailed    and 1 or 0,
        snapshotTime = SQWowAPI.GetTime(),
        timerSeconds = questInfo.timerSeconds,
        objectives   = objs,
    }
```

Add `classID` after `timerSeconds`:
```lua
    return {
        questID      = questInfo.questID,
        eventType    = eventType,
        isComplete   = questInfo.isComplete  and 1 or 0,
        isFailed     = questInfo.isFailed    and 1 or 0,
        snapshotTime = SQWowAPI.GetTime(),
        timerSeconds = questInfo.timerSeconds,
        classID      = localizedClassNameToID[questInfo.zone],  -- nil for non-class quests
        objectives   = objs,
    }
```

- [ ] **Step 3: Add `classID` to `buildInitPayload`**

Find `buildInitPayload`. Inside the `for questID, info in pairs(AQL:GetAllQuests())` loop, the per-quest table currently looks like:
```lua
        quests[questID] = {
            questID      = questID,
            isComplete   = info.isComplete  and 1 or 0,
            isFailed     = info.isFailed    and 1 or 0,
            snapshotTime = SQWowAPI.GetTime(),
            timerSeconds = info.timerSeconds,
            objectives   = objs,
        }
```

Add `classID` after `timerSeconds`:
```lua
        quests[questID] = {
            questID      = questID,
            isComplete   = info.isComplete  and 1 or 0,
            isFailed     = info.isFailed    and 1 or 0,
            snapshotTime = SQWowAPI.GetTime(),
            timerSeconds = info.timerSeconds,
            classID      = localizedClassNameToID[info.zone],  -- nil for non-class quests
            objectives   = objs,
        }
```

- [ ] **Step 4: Run tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both pass 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Core/Communications.lua
git commit -m "feat: add classID field to SQ_INIT and SQ_UPDATE payloads for class quest zone resolution"
```

---

### Task 3: GroupData.lua — preserve classID in OnUpdateReceived

**Files:**
- Modify: `Core/GroupData.lua`

Background: `OnInitReceived` stores the entire `quests` table from the wire payload (after boolean conversion). Because AceSerializer omits nil fields, any `classID` present on the wire is already preserved in `q` and flows into storage automatically — no change needed in `OnInitReceived`. `OnUpdateReceived`, however, explicitly constructs the stored quest entry and would otherwise drop `classID`.

- [ ] **Step 1: Add `classID` to the explicit entry construction in `OnUpdateReceived`**

Find the `entry.quests[questID] = { ... }` block in `OnUpdateReceived`. It currently looks like:
```lua
        entry.quests[questID] = {
            questID      = questID,
            title        = (info and info.title) or (AQL and AQL:GetQuestTitle(questID)),
            isComplete   = payload.isComplete  == 1,
            isFailed     = payload.isFailed    == 1,
            snapshotTime = payload.snapshotTime,
            timerSeconds = payload.timerSeconds,
            objectives   = storedObjs,
        }
```

Add `classID` after `timerSeconds`:
```lua
        entry.quests[questID] = {
            questID      = questID,
            title        = (info and info.title) or (AQL and AQL:GetQuestTitle(questID)),
            isComplete   = payload.isComplete  == 1,
            isFailed     = payload.isFailed    == 1,
            snapshotTime = payload.snapshotTime,
            timerSeconds = payload.timerSeconds,
            classID      = payload.classID,        -- nil for non-class quests
            objectives   = storedObjs,
        }
```

- [ ] **Step 2: Run tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both pass 0 failures.

- [ ] **Step 3: Commit**

```bash
git add Core/GroupData.lua
git commit -m "feat: preserve classID from wire payload in OnUpdateReceived quest entry"
```

---

### Task 4: TabUtils.lua — GetZoneForQuestID signature + tests

**Files:**
- Modify: `UI/TabUtils.lua`
- Modify: `tests/TabUtils_test.lua`

- [ ] **Step 1: Write the failing tests in `tests/TabUtils_test.lua`**

Open `tests/TabUtils_test.lua`. Find the two lines just after the stubs section and before `dofile`:
```lua
SocialQuestWowAPI = { IS_TBC = true, IS_RETAIL = false, IS_MOP = false, IS_CLASSIC_ERA = false }

dofile("UI/TabUtils.lua")
```

Add `CLASS_TOKEN_BY_ID` to the `SocialQuestWowAPI` stub. Change that line to:
```lua
SocialQuestWowAPI = {
    IS_TBC = true, IS_RETAIL = false, IS_MOP = false, IS_CLASSIC_ERA = false,
    CLASS_TOKEN_BY_ID = {
        [1]  = "WARRIOR",
        [5]  = "PRIEST",
    },
}

dofile("UI/TabUtils.lua")
```

Then, find the AQL stub (defined just before `SocialQuest = { AQL = AQL }`). Currently it has `GetQuestInfo` but no `GetQuest`. Add `GetQuest` and `_questMap` to the AQL stub:
```lua
local AQL = {
    ChainStatus = { Known = "known", Unknown = "unknown" },
    _questInfoMap = {},
    _questMap     = {},
    GetQuestInfo  = function(self, questID) return self._questInfoMap[questID] end,
    GetQuest      = function(self, questID) return self._questMap[questID] end,
    ...
}
```

(Keep all existing AQL fields; only add `_questMap` and `GetQuest`.)

Now find the `-- ── Results ──` section at the end of the file. Add the following new test section just before it:

```lua
-- ── GetZoneForQuestID ─────────────────────────────────────────────────────────

-- Reset AQL maps before each scenario.
AQL._questMap     = {}
AQL._questInfoMap = {}

-- Set up LOCALIZED_CLASS_NAMES_MALE global for class-name resolution.
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PRIEST = "Priest" }

-- classID=1 (Warrior) → "Warrior"
assert_eq("GetZone classID=1 returns Warrior",
    T.GetZoneForQuestID(999, 1), "Warrior")

-- classID=5 (Priest) → "Priest"
assert_eq("GetZone classID=5 returns Priest",
    T.GetZoneForQuestID(999, 5), "Priest")

-- classID nil, AQL:GetQuest has zone → returns that zone
AQL._questMap = { [42] = { zone = "Elwynn Forest" } }
assert_eq("GetZone nil classID uses AQL GetQuest zone",
    T.GetZoneForQuestID(42, nil), "Elwynn Forest")
AQL._questMap = {}

-- classID nil, GetQuest nil, AQL:GetQuestInfo has zone → returns that zone
AQL._questInfoMap = { [55] = { zone = "Stormwind City" } }
assert_eq("GetZone nil classID falls through to AQL GetQuestInfo",
    T.GetZoneForQuestID(55, nil), "Stormwind City")
AQL._questInfoMap = {}

-- classID nil, no AQL data → "Other Quests"
assert_eq("GetZone nil classID no AQL data returns Other Quests",
    T.GetZoneForQuestID(999, nil), "Other Quests")

-- classID provided but LOCALIZED_CLASS_NAMES_MALE is nil → falls back to AQL
LOCALIZED_CLASS_NAMES_MALE = nil
AQL._questMap = { [100] = { zone = "Dun Morogh" } }
assert_eq("GetZone classID with nil LOCALIZED table falls back to AQL",
    T.GetZoneForQuestID(100, 1), "Dun Morogh")
AQL._questMap = {}
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PRIEST = "Priest" }

-- classID for unknown class (not in CLASS_TOKEN_BY_ID) → falls back to AQL
AQL._questMap = { [77] = { zone = "Feralas" } }
assert_eq("GetZone unknown classID falls back to AQL",
    T.GetZoneForQuestID(77, 99), "Feralas")
AQL._questMap = {}
```

- [ ] **Step 2: Run tests to confirm they fail**

```
lua tests/TabUtils_test.lua
```
Expected: FAIL on `GetZone classID=1 returns Warrior` and subsequent new tests (because the function signature hasn't changed yet). The existing tests should still pass.

- [ ] **Step 3: Update `GetZoneForQuestID` in `UI/TabUtils.lua`**

Find the current function (around line 34):
```lua
function SocialQuestTabUtils.GetZoneForQuestID(questID)
    local AQL = SocialQuest.AQL
    -- Fast path: active quest cache.
    local info = AQL:GetQuest(questID)
    if info and info.zone then return info.zone end
    -- Slow path: three-tier resolution (cache → WoW log → provider).
    local fullInfo = AQL:GetQuestInfo(questID)
    if fullInfo and fullInfo.zone then return fullInfo.zone end
    return L["Other Quests"]
end
```

Replace it with:
```lua
-- classID is optional. When provided (remote player's quest entry), it is used
-- to resolve the localized class name directly, bypassing AQL. This covers the
-- case where AQL's provider lookup returns a geographic zone instead of the
-- class-name zone header used by WoW's quest log.
function SocialQuestTabUtils.GetZoneForQuestID(questID, classID)
    if classID then
        local token = SQWowAPI.CLASS_TOKEN_BY_ID[classID]
        local name  = token and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
        if name then return name end
    end
    local AQL = SocialQuest.AQL
    -- Fast path: active quest cache.
    local info = AQL:GetQuest(questID)
    if info and info.zone then return info.zone end
    -- Slow path: three-tier resolution (cache → WoW log → provider).
    local fullInfo = AQL:GetQuestInfo(questID)
    if fullInfo and fullInfo.zone then return fullInfo.zone end
    return L["Other Quests"]
end
```

- [ ] **Step 4: Run tests to confirm all pass**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both print `Results: N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add UI/TabUtils.lua tests/TabUtils_test.lua
git commit -m "feat: GetZoneForQuestID accepts optional classID to resolve class quest zone headers"
```

---

### Task 5: PartyTab.lua — build questClassIDs lookup and pass to GetZoneForQuestID

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

Background: `PartyTab:BuildTree` builds `allQuestIDs` by merging the local player's quests with all `PlayerQuests` entries, then iterates `allQuestIDs` to resolve zone names. There is no per-player context at the `GetZoneForQuestID` call site, so a pre-built `questClassIDs[questID] → classID` lookup is needed.

- [ ] **Step 1: Add the `questClassIDs` lookup in `PartyTab:BuildTree`**

Open `UI/Tabs/PartyTab.lua`. Find the block that builds `allQuestIDs` (around line 257):
```lua
    -- Collect all unique questIDs from local player and all party members.
    local allQuestIDs = {}
    for questID in pairs(AQL:GetAllQuests()) do
        allQuestIDs[questID] = true
    end
    for _, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerData.quests then
            for questID in pairs(playerData.quests) do
                allQuestIDs[questID] = true
            end
        end
    end
```

Add the `questClassIDs` lookup immediately after this block (before `local tree = { zones = {} }`):
```lua
    -- Build questID → classID lookup from remote players' quest entries.
    -- Used by GetZoneForQuestID to resolve class-name zone headers for remote
    -- players' class quests, where AQL's provider returns geographic zone instead.
    local questClassIDs = {}
    for _, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerData.quests then
            for questID, qentry in pairs(playerData.quests) do
                if qentry.classID and not questClassIDs[questID] then
                    questClassIDs[questID] = qentry.classID
                end
            end
        end
    end
```

- [ ] **Step 2: Update the `GetZoneForQuestID` call site**

Find the call site inside the `for questID in pairs(allQuestIDs)` loop (around line 300):
```lua
        local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID)
```

Replace with:
```lua
        local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID, questClassIDs[questID])
```

- [ ] **Step 3: Run tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both pass 0 failures.

- [ ] **Step 4: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: PartyTab passes classID to GetZoneForQuestID for class quest zone resolution"
```

---

### Task 6: SharedTab.lua — build questClassIDs lookup and pass to GetZoneForQuestID

**Files:**
- Modify: `UI/Tabs/SharedTab.lua`

Background: `SharedTab:BuildTree` has two loops that call zone resolution — the chain groups loop and the standalone quest groups loop. Only the standalone quest groups loop (around line 341) calls `GetZoneForQuestID`. The chain groups loop resolves zone directly from `AQL:GetQuest` for the local player, which already returns the correct class-name header. Only the standalone loop needs fixing.

- [ ] **Step 1: Add the `questClassIDs` lookup in `SharedTab:BuildTree`**

Open `UI/Tabs/SharedTab.lua`. Find the `-- Step 2: build tree` comment (around line 208):
```lua
    -- Step 2: build tree from groups with 2+ engaged players.
    local tree     = { zones = {} }
    local orderIdx = 0
```

Add the `questClassIDs` lookup immediately before the `-- Step 2` comment:
```lua
    -- Build questID → classID lookup from remote players' quest entries.
    -- Used by GetZoneForQuestID to resolve class-name zone headers for remote
    -- players' class quests.
    local questClassIDs = {}
    for _, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerData.quests then
            for questID, qentry in pairs(playerData.quests) do
                if qentry.classID and not questClassIDs[questID] then
                    questClassIDs[questID] = qentry.classID
                end
            end
        end
    end

    -- Step 2: build tree from groups with 2+ engaged players.
```

- [ ] **Step 2: Update the `GetZoneForQuestID` call site**

Find the call site in the standalone quest groups loop (around line 341):
```lua
            local zoneName  = SocialQuestTabUtils.GetZoneForQuestID(questID)
```

Replace with:
```lua
            local zoneName  = SocialQuestTabUtils.GetZoneForQuestID(questID, questClassIDs[questID])
```

- [ ] **Step 3: Run tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both pass 0 failures.

- [ ] **Step 4: Commit**

```bash
git add UI/Tabs/SharedTab.lua
git commit -m "feat: SharedTab passes classID to GetZoneForQuestID for class quest zone resolution"
```

---

### Task 7: Version bump and CLAUDE.md update

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full test suite one final time**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both pass 0 failures.

- [ ] **Step 2: Bump the version in `SocialQuest.toc`**

Follow the versioning rule in `CLAUDE.md`. This is the first feature change today → increment the minor version and reset revision to 0. If today's version is 2.23.6, the new version is 2.24.0.

Find and update the `## Version:` line in `SocialQuest.toc`:
```
## Version: 2.24.0
```

- [ ] **Step 3: Add a version entry to `CLAUDE.md`**

In `CLAUDE.md`, add a new entry at the top of the Version History section:

```markdown
### Version 2.24.0 (April 2026)
- Feature: class quest zone resolution. Remote players' class quests now appear
  under the correct localized class-name zone header ("Warrior", "Priest", etc.)
  in the Party and Shared tabs instead of under a geographic zone or "Other Quests".
  Root cause: AQL's provider lookup (Questie/Grail) returns the geographic zone for
  class quests, not the class-name zone header used by WoW's quest log. Fix: the
  sender detects class quests via a reverse lookup built from `LOCALIZED_CLASS_NAMES_MALE`
  and transmits an optional `classID` integer in `SQ_INIT` and `SQ_UPDATE` payloads.
  Receivers store it on the quest entry; `GetZoneForQuestID` resolves it to the
  receiver's localized class name via the new `CLASS_TOKEN_BY_ID` table in `WowAPI.lua`.
  Fully backward-compatible: older receivers ignore the new field; older senders produce
  `classID = nil` and receivers fall through to the existing AQL lookup. Questie bridge
  players are out of scope — they do not run SQ and cannot transmit `classID`.
```

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump version to 2.24.0 and document class quest zone resolution"
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Task that implements it |
|---|---|
| `CLASS_TOKEN_BY_ID` table in `WowAPI.lua` | Task 1 |
| `localizedClassNameToID` reverse lookup in `Communications.lua` | Task 2 |
| `classID` field in `buildQuestPayload` | Task 2 |
| `classID` field in `buildInitPayload` | Task 2 |
| `classID` preserved in `OnUpdateReceived` | Task 3 |
| `OnInitReceived` confirmed no change needed | Task 3 notes (auto-preserved) |
| `GetZoneForQuestID(questID, classID)` in `TabUtils.lua` | Task 4 |
| `PartyTab` passes `classID` | Task 5 |
| `SharedTab` passes `classID` | Task 6 |
| Tests for `GetZoneForQuestID` | Task 4 |
| Version bump | Task 7 |

### Consistency check

- `CLASS_TOKEN_BY_ID` defined in Task 1, referenced in Task 4's `GetZoneForQuestID` — consistent.
- `localizedClassNameToID` built using `SQWowAPI.CLASS_TOKEN_BY_ID` — Task 2 depends on Task 1; implementer must complete tasks in order.
- `questClassIDs[questID]` passed to `GetZoneForQuestID(questID, classID)` — parameter name matches function signature in Task 4. Consistent.
- `payload.classID` in Task 3 matches the field name added in Task 2. Consistent.
