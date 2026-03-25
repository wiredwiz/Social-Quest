# Cursor/Bag False Objective Events — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate false `AQL_OBJECTIVE_REGRESSED/PROGRESSED/COMPLETED` events caused by bag operations by adding a `CursorHasItem()` guard in AQL's event handler, then remove the now-unnecessary `pendingRegressions` debounce from SocialQuest.

**Architecture:** Add a single early-return guard in `handleQuestLogUpdate()` in AQL's `EventEngine.lua` immediately after the `initialized` check and before the NullProvider upgrade block. In SocialQuest, delete the `pendingRegressions` table and all code that reads or writes it — three handlers become unconditional.

**Tech Stack:** Lua 5.1, WoW TBC Classic (Interface 20505), Ace3, AQL LibStub library

---

## Files Changed

| File | Change |
|---|---|
| `Absolute-Quest-Log/Core/EventEngine.lua` | Add `CursorHasItem()` guard in `handleQuestLogUpdate()` |
| `Absolute-Quest-Log/AbsoluteQuestLog.toc` | Bump version (see versioning note in Task 2) — note: the spec document has a typo (`Absolute-Quest-Log.toc`); the real filename is `AbsoluteQuestLog.toc` (no hyphen, verified against actual file) |
| `Absolute-Quest-Log/CLAUDE.md` | Add version entry; also backfill 2.2.2 if it has no entry |
| `Social-Quest/SocialQuest.lua` | Remove `pendingRegressions` from `OnEnable`, `OnObjectiveProgressed`, `OnObjectiveCompleted`, `OnObjectiveRegressed` |
| `Social-Quest/SocialQuest.toc` | Bump version to 2.8.2 |
| `Social-Quest/CLAUDE.md` | Add version 2.8.2 entry |

---

## Task 1: Add CursorHasItem() guard in AQL EventEngine.lua

**Files:**
- Modify: `Absolute-Quest-Log/Core/EventEngine.lua:329-354`

The target function `handleQuestLogUpdate()` currently has this structure (lines 329–354):

```lua
local function handleQuestLogUpdate()
    if not EventEngine.initialized then
        ...
        return
    end
    -- Belt-and-suspenders: re-attempt provider selection if still on NullProvider.
    if AQL.provider == AQL.NullProvider then
        ...
    end
    local oldCache = AQL.QuestCache:Rebuild()
    ...
end
```

The guard goes immediately after the closing `end` of the `initialized` check (line 336), before the NullProvider comment on line 338.

- [ ] **Step 1: Verify the insertion point by reading the file**

Read `Absolute-Quest-Log/Core/EventEngine.lua` lines 329–355 and confirm:
- Line 330: `if not EventEngine.initialized then`
- Line 335: `        return`
- Line 336: `    end`
- Line 338: `    -- Belt-and-suspenders:...`

The guard inserts between line 336 and line 338 (i.e., after `end`, before the NullProvider comment).

- [ ] **Step 2: Insert the CursorHasItem() guard**

Edit `Absolute-Quest-Log/Core/EventEngine.lua`. After the closing `end` of the `EventEngine.initialized` guard (line 336), and before the `-- Belt-and-suspenders` comment, insert:

```lua

    -- If the player has an item on the cursor, this update is due to a bag
    -- operation in progress. The objective count is an unstable intermediate.
    -- Defer until cursor is empty; the next QUEST_LOG_UPDATE (fired when items
    -- are placed) processes normally with a net-zero diff.
    if CursorHasItem() then
        if AQL.debug then
            DEFAULT_CHAT_FRAME:AddMessage(
                AQL.DBG .. "[AQL] handleQuestLogUpdate: deferred (cursor has item)" .. AQL.RESET)
        end
        return
    end
```

After the edit, the function opening should read:

```lua
local function handleQuestLogUpdate()
    if not EventEngine.initialized then
        if AQL.debug == "verbose" then
            DEFAULT_CHAT_FRAME:AddMessage(AQL.DBG .. "[AQL] Event received before init, skipping" .. AQL.RESET)
        end
        return
    end

    -- If the player has an item on the cursor, this update is due to a bag
    -- operation in progress. The objective count is an unstable intermediate.
    -- Defer until cursor is empty; the next QUEST_LOG_UPDATE (fired when items
    -- are placed) processes normally with a net-zero diff.
    if CursorHasItem() then
        if AQL.debug then
            DEFAULT_CHAT_FRAME:AddMessage(
                AQL.DBG .. "[AQL] handleQuestLogUpdate: deferred (cursor has item)" .. AQL.RESET)
        end
        return
    end

    -- Belt-and-suspenders: re-attempt provider selection if still on NullProvider.
```

- [ ] **Step 3: Manual in-game verification**

Load the game. Have a quest with a collectible item objective (e.g., 6/8 items collected).

**Test A — stack split, no false events:**
1. Pick up 2 items from your bag onto your cursor to split a stack (do not place yet).
2. Confirm no regression banner or chat message fires while items are on cursor.
3. Place the items back. Confirm no progression or "completed again" banner fires.

**Test B — genuine item pickup still fires:**
1. Kill a mob that drops a quest item.
2. Confirm the normal objective progress banner fires as expected.

**Test C — debug log confirm (optional, with `/aql debug on`):**
1. Pick up an item onto cursor; confirm `[AQL] handleQuestLogUpdate: deferred (cursor has item)` appears in chat.
2. Place the item; confirm the deferred rebuild runs silently (no diff output since net change = 0).

- [ ] **Step 4: Commit the AQL EventEngine change**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add Core/EventEngine.lua
git commit -m "fix: suppress handleQuestLogUpdate during cursor bag operations

Add CursorHasItem() guard as the second check in handleQuestLogUpdate(),
immediately after the initialized guard and before the NullProvider upgrade
block. When the player has an item on the cursor, the QUEST_LOG_UPDATE
represents an unstable intermediate state (item temporarily removed from
bag but not yet placed). The guard defers the rebuild; the next event
fires when the item is placed and processes normally with a net-zero diff.

Fixes false AQL_OBJECTIVE_REGRESSED and false AQL_OBJECTIVE_COMPLETED
events that fired when players split or moved bag stacks of quest items."
```

---

## Task 2: Bump AQL version and update CLAUDE.md

**Files:**
- Modify: `Absolute-Quest-Log/AbsoluteQuestLog.toc`
- Modify: `Absolute-Quest-Log/CLAUDE.md`

**Versioning note:** The current toc version is `2.2.2` but `CLAUDE.md` only documents up to `2.2.1`, meaning 2.2.2 has no CLAUDE.md entry. Before bumping, check whether `2.2.2` was created today (2026-03-24):

- If 2.2.2 was created **on a prior day**: bump to `2.3.0` (first change today → increment minor, reset revision). Add a 2.2.2 backfill entry and a 2.3.0 entry to CLAUDE.md.
- If 2.2.2 was created **today**: bump to `2.2.3` (second change today → increment revision). Add a 2.2.2 backfill entry and a 2.2.3 entry to CLAUDE.md.

The steps below use `2.3.0` as the target. Substitute `2.2.3` if the toc was already touched today.

- [ ] **Step 1: Bump the version in AbsoluteQuestLog.toc**

Edit `Absolute-Quest-Log/AbsoluteQuestLog.toc`. Change:
```
## Version: 2.2.2
```
to:
```
## Version: 2.3.0
```
(or `2.2.3` per the versioning note above)

- [ ] **Step 2: Update AQL CLAUDE.md**

Edit `Absolute-Quest-Log/CLAUDE.md`. In the **Version History** section, add two new entries above the existing `2.2.1` entry. If 2.2.2 already has an entry, skip the backfill.

Backfill entry for 2.2.2 (only if missing — insert above 2.2.1):
```markdown
### Version 2.2.2 (March 2026)
- (No entry — version was bumped without a corresponding CLAUDE.md update.)
```

New entry for 2.3.0 (insert above 2.2.2):
```markdown
### Version 2.3.0 (March 2026)
- Bug fix: `handleQuestLogUpdate()` now returns early when `CursorHasItem()` is true, suppressing false `AQL_OBJECTIVE_REGRESSED` / `AQL_OBJECTIVE_PROGRESSED` / `AQL_OBJECTIVE_COMPLETED` callbacks that fired when the player picked up bag items (e.g., splitting a stack of quest collectibles). The next `QUEST_LOG_UPDATE` fires after items are placed and sees a net-zero diff. Eliminates the need for workaround debouncing in SocialQuest and other AQL consumers.
```

Also update the `AQL_OBJECTIVE_REGRESSED` row in the **Callbacks Reference** table to remove any mention of debouncing (that was always a SocialQuest concern, not AQL's). The current table entry just describes when the event fires — leave it unchanged if it reads:

```
| `AQL_OBJECTIVE_REGRESSED` | `(questInfo, objInfo, delta)` | `numFulfilled` decreased (suppressed during `pendingTurnIn`) |
```

No change needed there. It already doesn't mention debouncing.

- [ ] **Step 3: Update AQL changelog.txt**

Edit `Absolute-Quest-Log/changelog.txt`. Insert a new entry at the top of the file (above the existing `Version 2.2.2` entry):

```
Version 2.3.0 (March 2026)
---------------------------
- Bug fix: handleQuestLogUpdate() now guards against QUEST_LOG_UPDATE events fired
  while the player has an item on the cursor (e.g., splitting or moving bag stacks
  of quest collectibles). The objective count during these operations represents an
  unstable intermediate state. AQL defers the cache rebuild until the cursor is empty;
  the next event sees a net-zero diff and fires no callbacks. Eliminates false
  AQL_OBJECTIVE_REGRESSED, AQL_OBJECTIVE_PROGRESSED, and AQL_OBJECTIVE_COMPLETED
  events caused by bag operations.


```

(Substitute `2.3.0` with `2.2.3` if that is the resolved version per the versioning rule.)

- [ ] **Step 4: Commit the AQL version bump**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add AbsoluteQuestLog.toc CLAUDE.md changelog.txt
git commit -m "chore: bump AQL version to 2.3.0; update CLAUDE.md and changelog"
```

> **Note:** If the version resolves to `2.2.3`, update both the changelog entry header and commit message accordingly.

---

## Task 3: Remove pendingRegressions debounce from SocialQuest.lua

**Files:**
- Modify: `Social-Quest/SocialQuest.lua`

Four changes to `SocialQuest.lua`. Read the file before editing.

### Change A: OnEnable — remove pendingRegressions initialization

Current (lines ~144–148):
```lua
    -- Pending regression timer handles, keyed by "questID_objIndex".
    -- AQL_OBJECTIVE_REGRESSED is debounced: if AQL_OBJECTIVE_PROGRESSED arrives for
    -- the same objective within 2 s, the regression is a stack-split artefact and
    -- is silently cancelled.
    self.pendingRegressions = {}
```

**Delete** these 5 lines entirely. The preceding `self.zoneTransitionSuppressUntil = 0` line and the following `-- Initialize group composition tracker.` comment line are unchanged.

- [ ] **Step 1: Remove pendingRegressions initialization in OnEnable**

Edit `Social-Quest/SocialQuest.lua`. Delete the comment block and `self.pendingRegressions = {}` line from `OnEnable` (approximately lines 144–148 as shown above).

### Change B: OnObjectiveProgressed — remove pendingRegressions cancellation block

Current (lines ~568–573, inside `OnObjectiveProgressed`):
```lua
    -- Cancel any pending regression debounce for this objective.
    -- When a BAG_UPDATE stack split causes a temporary count dip, AQL fires
    -- REGRESSED then PROGRESSED in rapid succession. Cancelling here prevents
    -- the false regression from being broadcast or announced.
    local key = questInfo.questID .. "_" .. (objective.index or 0)
    if self.pendingRegressions[key] then
        self:Debug("Quest", "Regression debounce cancelled for questID=" .. questInfo.questID .. " obj=" .. (objective.index or 0))
        self:CancelTimer(self.pendingRegressions[key])
        self.pendingRegressions[key] = nil
    end
```

**Delete** these 9 lines entirely. The `if SQWowAPI.GetTime() < ...` guard above and the `-- Always broadcast...` comment below are unchanged.

- [ ] **Step 2: Remove pendingRegressions cancellation block from OnObjectiveProgressed**

Edit `Social-Quest/SocialQuest.lua`. Delete the comment + `local key` + `if self.pendingRegressions[key]` block from `OnObjectiveProgressed`.

After removal, `OnObjectiveProgressed` should read:

```lua
function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    self:Debug("Quest", "Objective " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end
```

### Change C: OnObjectiveCompleted — remove pendingRegressions cancellation block

Current (lines ~591–594, inside `OnObjectiveCompleted`):
```lua
    -- Also cancel any pending regression debounce (objective completed = not regressed).
    local key = questInfo.questID .. "_" .. (objective.index or 0)
    if self.pendingRegressions[key] then
        self:CancelTimer(self.pendingRegressions[key])
        self.pendingRegressions[key] = nil
    end
```

**Delete** these 6 lines entirely.

- [ ] **Step 3: Remove pendingRegressions cancellation block from OnObjectiveCompleted**

Edit `Social-Quest/SocialQuest.lua`. Delete the comment + `local key` + `if self.pendingRegressions[key]` block from `OnObjectiveCompleted`.

After removal, `OnObjectiveCompleted` should read:

```lua
function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    self:Debug("Quest", "Objective complete " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end
```

### Change D: OnObjectiveRegressed — replace debounce with direct announcement

Current `OnObjectiveRegressed` body (lines ~602–620):
```lua
function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    -- Debounce: delay by 2 s. If PROGRESSED or COMPLETED fires for the same
    -- objective within that window, the timer is cancelled — indicating a transient
    -- stack-split artefact rather than a genuine regression. 2 s covers the case
    -- where the player takes a moment to reposition the cursor after picking up items.
    local key = questInfo.questID .. "_" .. (objective.index or 0)
    if self.pendingRegressions[key] then
        self:CancelTimer(self.pendingRegressions[key])
    end
    self.pendingRegressions[key] = self:ScheduleTimer(function()
        self.pendingRegressions[key] = nil
        self:Debug("Quest", "Objective regression " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
        SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
        SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
        SocialQuestGroupFrame:RequestRefresh()
    end, 2.0)
end
```

**Replace the entire function body** (everything after the zone-transition guard) with a direct announcement:

- [ ] **Step 4: Simplify OnObjectiveRegressed to direct announcement**

Edit `Social-Quest/SocialQuest.lua`. Replace `OnObjectiveRegressed` so it reads:

```lua
function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    self:Debug("Quest", "Objective regression " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
    SocialQuestGroupFrame:RequestRefresh()
end
```

- [ ] **Step 5: Manual in-game verification**

Load the game. Have a quest with a collectible item objective (e.g., 8/8 collected).

**Test A — no false "completed again" on stack merge:**
1. Split the stack of 8 into 6 and 2.
2. Confirm no regression message fires.
3. Merge the 2 back onto the 6 (you now have 8/8 again).
4. Confirm no "objective completed" banner fires.

**Test B — genuine regression still announces:**
1. Drop or destroy one quest item from your bag (right-click delete from bag, not from cursor).
2. Confirm an objective regression message fires correctly.

**Test C — genuine completion still announces:**
1. Kill a mob to go from 7/8 to 8/8 on a kill quest.
2. Confirm the objective complete banner fires.

- [ ] **Step 6: Commit the SocialQuest debounce removal**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add SocialQuest.lua
git commit -m "refactor: remove pendingRegressions debounce (AQL fix makes it unnecessary)

AQL now suppresses handleQuestLogUpdate() when CursorHasItem() is true,
so bag operations no longer produce false REGRESSED/PROGRESSED/COMPLETED
events. The pendingRegressions AceTimer debounce was the workaround for
those false events; it is now dead code.

Remove:
- self.pendingRegressions = {} from OnEnable
- local key + if self.pendingRegressions[key] block from OnObjectiveProgressed
- local key + if self.pendingRegressions[key] block from OnObjectiveCompleted
- Entire debounce scheduling block from OnObjectiveRegressed (replaced with
  direct announcement, matching the post-timer body that was already correct)"
```

---

## Task 4: Bump SocialQuest version and update CLAUDE.md

**Files:**
- Modify: `Social-Quest/SocialQuest.toc`
- Modify: `Social-Quest/CLAUDE.md`

Version 2.8.1 was already bumped today (2026-03-24). This is the second change today, so: `2.8.1 → 2.8.2`.

- [ ] **Step 1: Bump SocialQuest.toc**

Edit `Social-Quest/SocialQuest.toc`. Change:
```
## Version: 2.8.1
```
to:
```
## Version: 2.8.2
```

- [ ] **Step 2: Update SocialQuest CLAUDE.md**

Edit `Social-Quest/CLAUDE.md`. In the **Version History** section, add a new entry above the 2.8.1 entry:

```markdown
### Version 2.8.2 (March 2026 — QuestieIntegration branch)
- Bug fix: eliminated false "objective completed again" and false regression announcements caused by bag operations (picking up or splitting item stacks for quest collectibles). Root fix in AQL (`CursorHasItem()` guard in `handleQuestLogUpdate()`) prevents the false events from ever firing. Removed the `pendingRegressions` AceTimer debounce from `SocialQuest.lua` (`OnEnable`, `OnObjectiveProgressed`, `OnObjectiveCompleted`, `OnObjectiveRegressed`) — it was a workaround for those now-suppressed events and is no longer needed.
```

Also update the AQL Callbacks table entry for `AQL_OBJECTIVE_REGRESSED` — remove the debounce description from the **Notes** column. The current entry reads:

> `AQL_OBJECTIVE_REGRESSED` | `OnObjectiveRegressed` | 0.5 s debounce — cancelled by subsequent PROGRESSED/COMPLETED (suppresses BAG_UPDATE stack-split artefacts)

Change to:

> `AQL_OBJECTIVE_REGRESSED` | `OnObjectiveRegressed` | Broadcasts objective update and announces regression

- [ ] **Step 3: Update SocialQuest changelog.txt**

The SocialQuest changelog is behind — it currently ends at 2.7.0 but the addon is at 2.8.1. Edit `Social-Quest/changelog.txt` and insert three new entries at the top of the file (above the existing `Version 2.7.0` entry):

```
Version 2.8.2 (March 2026)
- Bug fix: eliminated false "objective completed again" and false regression
  announcements when splitting or merging bag stacks of quest collectible items.
  Root fix in AQL (CursorHasItem() guard in handleQuestLogUpdate()) prevents
  false REGRESSED/PROGRESSED/COMPLETED events from ever firing. Removed the
  pendingRegressions AceTimer debounce from SocialQuest.lua — it was a workaround
  for those now-suppressed events and is no longer needed.

Version 2.8.1 (March 2026)
- Bug fix: clicking a quest title in the SQ window when the quest log was open,
  the quest selected, but its zone was collapsed caused the log to close instead
  of expanding the zone. Fixed by gating the close-toggle on the quest being
  visible (zone not collapsed) using AQL:GetQuestLogIndex().
- Bug fix: regression banner still appeared when splitting a quest item stack.
  Debounce window in OnObjectiveRegressed increased from 0.5 s to 2 s.

Version 2.8.0 (March 2026)
- Questie Bridge: hooks Questie's QuestieComms layer to populate PlayerQuests
  for party members who have Questie but not SocialQuest.
- Added SocialQuest.DataProviders and SocialQuest.EventTypes constant tables.
- Added dataProvider field to all PlayerQuests entries.
- New modules: Core/BridgeRegistry.lua and Core/QuestieBridge.lua.
- RowFactory appends the bridge's name tag icon for non-SQ data sources.

```

- [ ] **Step 4: Commit the SocialQuest version bump**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add SocialQuest.toc CLAUDE.md changelog.txt
git commit -m "chore: bump SocialQuest version to 2.8.2; update CLAUDE.md and changelog"
```
