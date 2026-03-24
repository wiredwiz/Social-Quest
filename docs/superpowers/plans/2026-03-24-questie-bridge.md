# Questie Bridge Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hook Questie's public comm layer to populate GroupData for party members who have Questie but not SocialQuest, and fire verified banner announcements for their quest events.

**Architecture:** A new `BridgeRegistry` lifecycle manager holds bridge modules (plain Lua tables satisfying a defined interface). `QuestieBridge` hooks `QuestieComms` via `hooksecurefunc`. `GroupData` gains three new methods (`OnBridgeQuestUpdate`, `OnBridgeQuestRemove`, `OnBridgeHydrate`). `RowFactory` appends a nameTag icon when a player's data came from a bridge. `GroupComposition` calls `EnableAll`/`DisableAll` on join/leave. All event type string literals are replaced with `SocialQuest.EventTypes` constants as part of this work.

**Tech Stack:** Lua 5.1 (WoW TBC 20505), hooksecurefunc (permanent hooks), Ace3 framework, existing SQ modules.

---

## Chunk 1: Constants and EventTypes Refactor

### Task 1: Add DataProviders and EventTypes constants to SocialQuest.lua

**Files:**
- Modify: `SocialQuest.lua` (after line 16, after line 22)

These constants are declared on the addon object immediately after it is created so that all sub-modules loaded after `SocialQuest.lua` can reference them at file scope. String values are identical to the existing literals — this is a pure naming refactor.

- [ ] **Step 1: Insert constant tables after the addon declaration**

In `SocialQuest.lua`, after line 16 (the closing `)` of `LibStub("AceAddon-3.0"):NewAddon(...)`), insert:

```lua
SocialQuest.DataProviders = {
    SocialQuest = "SocialQuest",
    Questie     = "Questie",
}

SocialQuest.EventTypes = {
    Accepted          = "accepted",
    Completed         = "completed",         -- turned in to NPC
    Abandoned         = "abandoned",
    Failed            = "failed",
    Finished          = "finished",          -- all objectives done, not yet turned in
    Tracked           = "tracked",
    Untracked         = "untracked",
    ObjectiveComplete = "objective_complete",
    ObjectiveProgress = "objective_progress",
}
```

- [ ] **Step 2: Add ET alias after the existing file-scope locals**

After line 22 (`local SQWowUI  = SocialQuestWowUI`), insert:

```lua
local ET = SocialQuest.EventTypes
```

- [ ] **Step 3: In-game verification**

Save, `/reload` in WoW. Confirm no Lua errors appear in the default chat frame. Then run:

```
/run print(SocialQuest.EventTypes.Accepted)
```
Expected: `accepted`

```
/run print(SocialQuest.DataProviders.Questie)
```
Expected: `Questie`

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: add DataProviders and EventTypes constant tables to SocialQuest.lua"
```

---

### Task 2: Replace event type string literals in SocialQuest.lua

**Files:**
- Modify: `SocialQuest.lua` (lines 491–526)

The five AQL callback handlers each pass a hardcoded string to `OnQuestEvent` and `BroadcastQuestUpdate`. Replace all five with `ET.*` constants. The `ET` alias was added in Task 1.

- [ ] **Step 1: Update OnQuestAccepted (lines 491–492)**

Change:
```lua
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
```
To:
```lua
    SocialQuestAnnounce:OnQuestEvent(ET.Accepted, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Accepted)
```

- [ ] **Step 2: Update OnQuestAbandoned (lines 499–500)**

Change:
```lua
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
```
To:
```lua
    SocialQuestAnnounce:OnQuestEvent(ET.Abandoned, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Abandoned)
```

- [ ] **Step 3: Update OnQuestFinished (lines 509–510)**

Change:
```lua
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
```
To:
```lua
    SocialQuestAnnounce:OnQuestEvent(ET.Finished, questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Finished)
```

- [ ] **Step 4: Update OnQuestCompleted (lines 517–518)**

Change:
```lua
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
```
To:
```lua
    SocialQuestAnnounce:OnQuestEvent(ET.Completed, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Completed)
```

- [ ] **Step 5: Update OnQuestFailed (lines 525–526)**

Change:
```lua
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
```
To:
```lua
    SocialQuestAnnounce:OnQuestEvent(ET.Failed, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Failed)
```

- [ ] **Step 6: In-game verification**

`/reload`. No Lua errors. Accept a quest in-game — quest-accepted banner and chat message fire as before.

- [ ] **Step 7: Commit**

```bash
git add SocialQuest.lua
git commit -m "refactor: replace event type string literals in SocialQuest.lua with ET.* constants"
```

---

### Task 3: Replace event type string literals in GroupData.lua

**Files:**
- Modify: `Core/GroupData.lua` (line 22 area, lines 103–110)

`Communications.lua` was reviewed and contains no hardcoded event type comparisons — eventType arrives as a parameter from callers and is passed through unchanged. No changes needed there.

- [ ] **Step 1: Add ET alias after the existing local declaration**

After line 22 (`local SQWowAPI = SocialQuestWowAPI`), insert:

```lua
local ET = SocialQuest.EventTypes
```

- [ ] **Step 2: Update OnUpdateReceived comparisons (lines 103–110)**

Change:
```lua
    if eventType == "abandoned" or eventType == "completed" or eventType == "failed" then
        if eventType == "completed" then
            entry.completedQuests[questID] = true
        end
```
To:
```lua
    if eventType == ET.Abandoned or eventType == ET.Completed or eventType == ET.Failed then
        if eventType == ET.Completed then
            entry.completedQuests[questID] = true
        end
```

Change:
```lua
    elseif eventType == "tracked" or eventType == "untracked" then
```
To:
```lua
    elseif eventType == ET.Tracked or eventType == ET.Untracked then
```

- [ ] **Step 3: In-game verification**

`/reload`. No Lua errors. Have a group member accept and abandon a quest — GroupFrame shows and removes the quest without error.

- [ ] **Step 4: Commit**

```bash
git add Core/GroupData.lua
git commit -m "refactor: replace event type string literals in GroupData.lua with ET.* constants"
```

---

### Task 4: Replace event type string literals in Announcements.lua

**Files:**
- Modify: `Core/Announcements.lua` (line 32 area, lines 255, 415, 482)

- [ ] **Step 1: Add ET alias after the existing file-scope locals**

After line 32 (`local SQWowUI  = SocialQuestWowUI`), insert:

```lua
local ET = SocialQuest.EventTypes
```

- [ ] **Step 2: Update OnQuestEvent "finished" comparison (line 255)**

Change:
```lua
    if eventType == "finished" then
        checkAllFinished(questID, true)
    end
```
To:
```lua
    if eventType == ET.Finished then
        checkAllFinished(questID, true)
    end
```

- [ ] **Step 3: Update OnRemoteQuestEvent "finished" comparison (line 415)**

Change:
```lua
    if eventType == "finished" then
        checkAllFinished(questID, false)
    end
```
To:
```lua
    if eventType == ET.Finished then
        checkAllFinished(questID, false)
    end
```

- [ ] **Step 4: Update OnRemoteObjectiveEvent eventType determination (line 482)**

Change:
```lua
    local eventType = isComplete and "objective_complete" or "objective_progress"
```
To:
```lua
    local eventType = isComplete and ET.ObjectiveComplete or ET.ObjectiveProgress
```

- [ ] **Step 5: In-game verification**

`/reload`. No Lua errors. Accept and complete a quest in a group — banners fire as before. Note: `CHAIN_STEP_EVENTS`, `OUTBOUND_QUEST_TEMPLATES`, and `BANNER_QUEST_TEMPLATES` in `Announcements.lua` use string key literals for table lookup — these are intentionally NOT changed (they are storage-format keys, not event type comparisons).

- [ ] **Step 6: Commit**

```bash
git add Core/Announcements.lua
git commit -m "refactor: replace event type string literals in Announcements.lua with ET.* constants"
```

---

## Chunk 2: GroupData dataProvider Field and Bridge Methods

### Task 5: Add dataProvider field to GroupData SQ entries

**Files:**
- Modify: `Core/GroupData.lua` (lines 70–75, line 93)

Every `PlayerQuests` entry receives a `dataProvider` field. SQ entries get `DataProviders.SocialQuest`; stubs created by `OnMemberJoined` and `OnUnitQuestLogChanged` stay `nil` (unknown until data arrives). If a Questie-only player later installs SQ and broadcasts `SQ_INIT`, `OnInitReceived` upgrades their entry to `DataProviders.SocialQuest`, causing bridge data to be subsequently ignored for that player (the `pdata.hasSocialQuest` guard in `OnBridgeQuestUpdate`).

- [ ] **Step 1: Add dataProvider to OnInitReceived new entry (lines 70–75)**

Change:
```lua
    self.PlayerQuests[sender] = {
        hasSocialQuest  = true,
        lastSync        = SQWowAPI.GetTime(),
        quests          = quests,
        completedQuests = (existing and existing.completedQuests) or {},
    }
```
To:
```lua
    self.PlayerQuests[sender] = {
        hasSocialQuest  = true,
        dataProvider    = SocialQuest.DataProviders.SocialQuest,
        lastSync        = SQWowAPI.GetTime(),
        quests          = quests,
        completedQuests = (existing and existing.completedQuests) or {},
    }
```

- [ ] **Step 2: Add dataProvider to OnUpdateReceived new entry (line 93)**

Change:
```lua
        entry = { hasSocialQuest = true, lastSync = SQWowAPI.GetTime(), quests = {}, completedQuests = {} }
```
To:
```lua
        entry = { hasSocialQuest = true, dataProvider = SocialQuest.DataProviders.SocialQuest, lastSync = SQWowAPI.GetTime(), quests = {}, completedQuests = {} }
```

- [ ] **Step 3: In-game verification**

`/reload`. No Lua errors. After receiving SQ data from a group member, run:

```
/run for k,v in pairs(SocialQuestGroupData.PlayerQuests) do print(k, v.dataProvider) end
```
Expected: SQ members show `SocialQuest`; stubs (non-SQ members) show `nil`.

- [ ] **Step 4: Commit**

```bash
git add Core/GroupData.lua
git commit -m "feat: add dataProvider=SocialQuest to PlayerQuests entries created by SQ comm handlers"
```

---

### Task 6: Add OnBridgeQuestUpdate to GroupData

**Files:**
- Modify: `Core/GroupData.lua` (append after `IsInGroup`)

This method is called by bridge modules when a Questie packet is parsed. It diffs the incoming quest against stored state to detect first-appearance (accepted), objective progress, and all-objectives-done (finished) events. It does NOT create entries for unknown players — only players with an existing stub (created by `OnMemberJoined`) are processed.

- [ ] **Step 1: Append method to the end of Core/GroupData.lua**

```lua
-- Called by bridge modules when a quest update packet arrives for a player.
-- provider: SocialQuest.DataProviders.* constant identifying the data source.
-- fullName:  "Name-Realm" or "Name" — same format used as PlayerQuests keys.
-- questEntry: { questID, title, isComplete, isFailed, snapshotTime, objectives={...} }
function SocialQuestGroupData:OnBridgeQuestUpdate(provider, fullName, questEntry)
    local pdata = self.PlayerQuests[fullName]
    if not pdata then return end            -- not a known group member; ignore
    if pdata.hasSocialQuest then return end -- SQ data takes precedence

    pdata.dataProvider = provider
    pdata.lastSync     = SQWowAPI.GetTime()

    local questID  = questEntry.questID
    local existing = pdata.quests[questID]
    local isNew    = existing == nil

    -- Diff objectives only when the quest was already known.
    -- Avoids progress banners for catch-up data seen for the first time.
    if existing then
        for i, obj in ipairs(questEntry.objectives) do
            local prev        = existing.objectives[i]
            local wasFinished = prev and prev.isFinished
            if obj.isFinished and not wasFinished then
                SocialQuestAnnounce:OnRemoteObjectiveEvent(
                    fullName, questID, i,
                    obj.numFulfilled, obj.numRequired, true, false)
            elseif prev and obj.numFulfilled > prev.numFulfilled then
                SocialQuestAnnounce:OnRemoteObjectiveEvent(
                    fullName, questID, i,
                    obj.numFulfilled, obj.numRequired, false, false)
            end
        end

        -- Quest complete: all objectives finished and wasn't complete before.
        if questEntry.isComplete and not existing.isComplete then
            SocialQuestAnnounce:OnRemoteQuestEvent(
                fullName, ET.Finished, questID, questEntry.title)
        end
    end

    pdata.quests[questID] = questEntry

    if isNew then
        SocialQuestAnnounce:OnRemoteQuestEvent(
            fullName, ET.Accepted, questID, questEntry.title)
    end

    SocialQuestGroupFrame:RequestRefresh()
end
```

- [ ] **Step 2: In-game verification (syntax check)**

`/reload`. No Lua errors.

- [ ] **Step 3: Commit**

```bash
git add Core/GroupData.lua
git commit -m "feat: add OnBridgeQuestUpdate to GroupData for bridge quest ingestion"
```

---

### Task 7: Add OnBridgeQuestRemove and OnBridgeHydrate to GroupData

**Files:**
- Modify: `Core/GroupData.lua` (append after `OnBridgeQuestUpdate`)

`OnBridgeQuestRemove` silently removes the quest entry. No Announce is fired — the Questie remove packet carries no reason code, so turn-in vs abandon is unverifiable. `completedQuests[questID]` is NOT set (see Known Limitations in spec). `OnBridgeHydrate` is called by `BridgeRegistry` before `Enable()` to pre-populate state without firing banners.

- [ ] **Step 1: Append OnBridgeQuestRemove**

```lua
-- Called by bridge modules when a quest is removed from a player's log.
-- Reason (turn-in vs abandon) is unverifiable from the bridge; no Announce is fired.
-- completedQuests[questID] is NOT set — reason unknown.
function SocialQuestGroupData:OnBridgeQuestRemove(provider, fullName, questID)
    local pdata = self.PlayerQuests[fullName]
    if not pdata or pdata.hasSocialQuest then return end
    if pdata.quests[questID] then
        pdata.quests[questID] = nil
        SocialQuestGroupFrame:RequestRefresh()
    end
end
```

- [ ] **Step 2: Append OnBridgeHydrate**

```lua
-- Called by BridgeRegistry before Enable() to populate initial quest state.
-- No banners are fired. Only hydrates players who already have a stub in
-- PlayerQuests (current group members) — skips non-group players in the snapshot.
function SocialQuestGroupData:OnBridgeHydrate(provider, snapshot)
    for fullName, quests in pairs(snapshot) do
        local pdata = self.PlayerQuests[fullName]
        if pdata and not pdata.hasSocialQuest then
            pdata.dataProvider = provider
            pdata.lastSync     = SQWowAPI.GetTime()
            pdata.quests       = quests
            -- completedQuests preserved if accumulated before hydration
        end
    end
    SocialQuestGroupFrame:RequestRefresh()
end
```

- [ ] **Step 3: In-game verification**

`/reload`. No Lua errors.

- [ ] **Step 4: Commit**

```bash
git add Core/GroupData.lua
git commit -m "feat: add OnBridgeQuestRemove and OnBridgeHydrate to GroupData"
```

---

## Chunk 3: Announce Guards

### Task 8: Fix checkAllFinished guard in Announcements.lua

**Files:**
- Modify: `Core/Announcements.lua` (line 331)

The current guard suppresses "Everyone has finished" whenever any group member has `hasSocialQuest == false`. Bridge players also have `hasSocialQuest = false` but provide full objective data via their `dataProvider` field. The guard must only suppress when a member has NO data source at all.

- [ ] **Step 1: Update the suppression condition (line 331)**

Change:
```lua
    for _, entry in pairs(PlayerQuests) do
        if not entry.hasSocialQuest then
            SocialQuest:Debug("Banner", "All finished suppressed: non-SQ member present")
            return
        end
    end
```
To:
```lua
    for _, entry in pairs(PlayerQuests) do
        if not entry.hasSocialQuest and not entry.dataProvider then
            SocialQuest:Debug("Banner", "All finished suppressed: member with no data present")
            return
        end
    end
```

- [ ] **Step 2: In-game verification**

`/reload`. No Lua errors. Scenario: in a party with a bridge-data member (or simulate by setting `dataProvider` in chat), all players finish quest objectives. "Everyone has finished" banner should fire. Previously it would have been suppressed.

- [ ] **Step 3: Commit**

```bash
git add Core/Announcements.lua
git commit -m "fix: allow checkAllFinished to fire when all members have a data source (SQ or bridge)"
```

---

### Task 9: Add suppression guard to OnRemoteQuestEvent

**Files:**
- Modify: `Core/Announcements.lua` (after line 411)

Defense-in-depth: `OnBridgeQuestRemove` never calls Announce, so Completed/Abandoned/Failed should never reach `OnRemoteQuestEvent` for bridge players. This guard enforces that contract explicitly in case a future call site changes.

- [ ] **Step 1: Insert guard after the db.enabled check (after line 411)**

`OnRemoteQuestEvent` begins at line 409. After line 411 (`if not db.enabled then return end`), insert:

```lua
    -- Defense-in-depth: bridge providers cannot verify Completed/Abandoned/Failed
    -- (remove packet carries no reason code). Block them here regardless of call site.
    local pdata    = SocialQuestGroupData.PlayerQuests[sender]
    local provider = pdata and pdata.dataProvider
    if provider and provider ~= SocialQuest.DataProviders.SocialQuest then
        if eventType == ET.Completed
        or eventType == ET.Abandoned
        or eventType == ET.Failed then
            return
        end
    end
```

- [ ] **Step 2: In-game verification**

`/reload`. No Lua errors.

- [ ] **Step 3: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: suppress Completed/Abandoned/Failed banners for non-SQ data providers"
```

---

## Chunk 4: New Files and TOC

### Task 10: Create Core/BridgeRegistry.lua

**Files:**
- Create: `Core/BridgeRegistry.lua`

Thin lifecycle manager. No quest logic. Must be added to TOC (Task 12) before in-game verification is possible.

- [ ] **Step 1: Create the file**

```lua
-- Core/BridgeRegistry.lua
-- Lifecycle manager for data-provider bridges. Bridges are plain Lua tables that
-- satisfy the bridge interface contract documented below.
--
-- Bridge interface contract:
--
--   bridge.provider  = SocialQuest.DataProviders.X   (string identity constant)
--   bridge.nameTag   = string or nil
--       Appended after the player's name in RowFactory. May be a WoW texture
--       escape "|TPath:w:h|t" or plain text. nil means no annotation (first-party).
--
--   bridge:IsAvailable() -> bool
--       Returns true when the source addon is loaded and its public API is accessible.
--
--   bridge:Enable() -> void
--       Installs hooks or listeners. Safe to call multiple times (must guard with
--       _hookInstalled). Must check _active to avoid double-hydration on group type
--       changes. hooksecurefunc is permanent — hooks cannot be uninstalled.
--
--   bridge:Disable() -> void
--       Suspends processing. Sets _active = false. Does NOT remove hooks.
--
--   bridge:GetSnapshot() -> { [fullName] = { [questID] = questEntry } }
--       Returns current known state for initial hydration. Returns {} if unavailable.
--
-- Bridges call GroupData directly:
--   SocialQuestGroupData:OnBridgeQuestUpdate(provider, fullName, questEntry)
--   SocialQuestGroupData:OnBridgeQuestRemove(provider, fullName, questID)
--
-- BridgeRegistry calls GroupData for hydration:
--   SocialQuestGroupData:OnBridgeHydrate(provider, snapshot)

SocialQuestBridgeRegistry = {}
SocialQuestBridgeRegistry._bridges = {}

function SocialQuestBridgeRegistry:Register(bridge)
    table.insert(self._bridges, bridge)
end

-- Called by GroupComposition when the local player joins a group (or group type changes).
-- For each available bridge that is not already active:
--   1. Gets a snapshot of existing data (reduces spurious "accepted" banners from
--      Questie's initial 2-second sync broadcast on group join).
--   2. Hydrates GroupData with the snapshot (no banners).
--   3. Calls Enable() to start processing live hook events.
-- Skips bridges already active — avoids double-hydration on group type changes
-- (e.g. party promoted to raid) where OnSelfJoinedGroup fires again.
function SocialQuestBridgeRegistry:EnableAll()
    for _, bridge in ipairs(self._bridges) do
        if bridge:IsAvailable() and not bridge._active then
            local snapshot = bridge:GetSnapshot()
            SocialQuestGroupData:OnBridgeHydrate(bridge.provider, snapshot)
            bridge:Enable()
        end
    end
end

-- Called by GroupComposition when the local player leaves all groups.
-- Suspends all bridge callbacks until the next EnableAll().
function SocialQuestBridgeRegistry:DisableAll()
    for _, bridge in ipairs(self._bridges) do
        bridge:Disable()
    end
end

-- Returns the nameTag string for a given provider, or nil if not found.
-- Used by RowFactory to annotate player names with their data-source icon.
function SocialQuestBridgeRegistry:GetNameTag(provider)
    for _, bridge in ipairs(self._bridges) do
        if bridge.provider == provider then
            return bridge.nameTag
        end
    end
    return nil
end
```

- [ ] **Step 2: Commit (before TOC wires it in)**

```bash
git add Core/BridgeRegistry.lua
git commit -m "feat: add Core/BridgeRegistry.lua — bridge lifecycle manager"
```

---

### Task 11: Create Core/QuestieBridge.lua

**Files:**
- Create: `Core/QuestieBridge.lua`

Implements the bridge interface for Questie. Hooks two public Questie methods via `hooksecurefunc`. Both hooks are permanent once installed; `_hookInstalled` prevents duplicate installation; `_active` gates all processing.

The Questie icon path `Interface/AddOns/Questie/Icons/questie.png` was verified from `QuestieAnnounce.lua` line 44 in the Questie source.

- [ ] **Step 1: Create the file**

```lua
-- Core/QuestieBridge.lua
-- Questie implementation of the bridge interface. Hooks QuestieComms to populate
-- GroupData for party members who have Questie but not SocialQuest.
--
-- Hooked methods (permanent via hooksecurefunc):
--   QuestieComms:InsertQuestDataPacket(questPacket, playerName)
--       Called by Questie after every parsed quest update (accept, progress, complete).
--       questPacket.id         = questID
--       questPacket.objectives = { { id, type, fulfilled, required, finished }, ... }
--
--   QuestieComms.data:RemoveQuestFromPlayer(questId, playerName)
--       Called when any quest is removed from a player's log.
--       No reason code — cannot distinguish turn-in from abandon.
--
-- playerName format: "Name-Realm" or "Name" (same as SQ's own comm layer).

QuestieBridge = {}
QuestieBridge.provider       = SocialQuest.DataProviders.Questie
QuestieBridge.nameTag        = "|TInterface/AddOns/Questie/Icons/questie.png:12:12|t"
QuestieBridge._active        = false
QuestieBridge._hookInstalled = false

local SQWowAPI = SocialQuestWowAPI

-- Returns true when Questie is loaded and its public comm API is accessible.
function QuestieBridge:IsAvailable()
    return QuestieComms ~= nil and QuestieComms.data ~= nil
end

-- Activates bridge processing and installs permanent hooks (once).
-- _hookInstalled guards against duplicate hook installation.
-- _active = true re-enables processing after a Disable() call.
function QuestieBridge:Enable()
    self._active = true
    if not self._hookInstalled then
        hooksecurefunc(QuestieComms, "InsertQuestDataPacket",
            function(_, questPacket, playerName)
                if self._active then self:_OnQuestUpdated(questPacket, playerName) end
            end)
        hooksecurefunc(QuestieComms.data, "RemoveQuestFromPlayer",
            function(_, questId, playerName)
                if self._active then self:_OnQuestRemoved(questId, playerName) end
            end)
        self._hookInstalled = true
    end
end

-- Suspends bridge processing. Does NOT remove hooks (hooksecurefunc is permanent).
function QuestieBridge:Disable()
    self._active = false
end

-- Returns a player-keyed snapshot of Questie's current remote quest log.
-- Called by BridgeRegistry before Enable() for initial hydration.
-- Pivots QuestieComms.remoteQuestLogs from [questId][playerName] to [playerName][questId].
-- GroupData:OnBridgeHydrate filters to known group members; no filtering needed here.
function QuestieBridge:GetSnapshot()
    if not QuestieComms or not QuestieComms.remoteQuestLogs then return {} end
    local snapshot = {}
    for questId, players in pairs(QuestieComms.remoteQuestLogs) do
        for playerName, objectives in pairs(players) do
            if not snapshot[playerName] then snapshot[playerName] = {} end
            snapshot[playerName][questId] = self:_BuildQuestEntry(questId, objectives)
        end
    end
    return snapshot
end

-- Translates a Questie objective array into an SQ-compatible quest entry.
-- Questie objective fields: { id, type, fulfilled, required, finished }
-- SQ objective fields:      { numFulfilled, numRequired, isFinished }
function QuestieBridge:_BuildQuestEntry(questId, questieObjectives)
    local AQL  = SocialQuest.AQL
    local info = AQL and AQL:GetQuest(questId)
    local objs = {}
    local allFinished = #questieObjectives > 0
    for i, o in ipairs(questieObjectives) do
        objs[i] = {
            numFulfilled = o.fulfilled,
            numRequired  = o.required,
            isFinished   = o.finished == true,
        }
        if not o.finished then allFinished = false end
    end
    return {
        questID      = questId,
        title        = (info and info.title)
                    or (AQL and AQL:GetQuestTitle(questId))
                    or ("Quest " .. questId),
        isComplete   = allFinished,
        isFailed     = false,   -- Questie does not transmit failure state
        snapshotTime = SQWowAPI.GetTime(),
        objectives   = objs,
    }
end

-- Hook handler: called after Questie parses a quest update packet.
function QuestieBridge:_OnQuestUpdated(questPacket, playerName)
    local entry = self:_BuildQuestEntry(questPacket.id, questPacket.objectives or {})
    SocialQuestGroupData:OnBridgeQuestUpdate(self.provider, playerName, entry)
end

-- Hook handler: called when Questie removes a quest from a player's tracked log.
function QuestieBridge:_OnQuestRemoved(questId, playerName)
    SocialQuestGroupData:OnBridgeQuestRemove(self.provider, playerName, questId)
end

-- Register with BridgeRegistry at load time.
SocialQuestBridgeRegistry:Register(QuestieBridge)
```

- [ ] **Step 2: Commit (before TOC wires it in)**

```bash
git add Core/QuestieBridge.lua
git commit -m "feat: add Core/QuestieBridge.lua — Questie bridge implementation"
```

---

### Task 12: Update SocialQuest.toc

**Files:**
- Modify: `SocialQuest.toc` (after line 41)

Both new files must load after `Core/Announcements.lua`. At that point all globals they depend on (`SocialQuestGroupData`, `SocialQuestAnnounce`, `SocialQuestGroupFrame`) are already defined. `BridgeRegistry` must precede `QuestieBridge` since `QuestieBridge` calls `SocialQuestBridgeRegistry:Register()` at file scope.

- [ ] **Step 1: Add new entries to the load order**

After line 41 (`Core\Announcements.lua`), insert:

```
Core\BridgeRegistry.lua
Core\QuestieBridge.lua
```

The affected section of the TOC becomes:

```
Core\Communications.lua
Core\Announcements.lua
Core\BridgeRegistry.lua
Core\QuestieBridge.lua

# UI modules
```

- [ ] **Step 2: In-game verification**

`/reload`. No Lua errors. Verify both globals loaded:

```
/run print(SocialQuestBridgeRegistry ~= nil, QuestieBridge ~= nil)
```
Expected: `true   true`

Verify registration and identity:

```
/run print(SocialQuestBridgeRegistry._bridges[1].provider)
```
Expected: `Questie`

If Questie is not installed, `QuestieBridge:IsAvailable()` returns false. No hooks are installed. This is expected — not an error.

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.toc
git commit -m "chore: add Core/BridgeRegistry.lua and Core/QuestieBridge.lua to TOC load order"
```

---

## Chunk 5: UI and GroupComposition Wiring

### Task 13: Update RowFactory to display nameTag

**Files:**
- Modify: `UI/RowFactory.lua` (line 273 and the 6 SetText calls inside `AddPlayerRow`)

Add `displayName` variable immediately after reading `playerEntry.name`. Use `displayName` in all six `SetText` calls. The `name` local is left unchanged so `string.format` calls using `%s` still work — only the value passed is changed.

- [ ] **Step 1: Insert nameTag/displayName after line 273**

After line 273 (`local name = playerEntry.name or "Unknown"`), insert:

```lua
    local nameTag     = playerEntry.dataProvider
                     and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
    local displayName = nameTag and (name .. " " .. nameTag) or name
```

- [ ] **Step 2: Replace name with displayName in all 6 SetText calls**

All occurrences are inside `AddPlayerRow`. Find each use of `name` in a `SetText` call and replace with `displayName`:

Line ~280 (hasCompleted branch):
```lua
-- Before:
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], name) .. C.reset)
-- After:
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], displayName) .. C.reset)
```

Line ~288 (isComplete branch):
```lua
-- Before:
        fs:SetText(C.white .. name .. C.reset .. " " .. SocialQuestColors.GetUIColor("completed") .. L["Complete"] .. C.reset)
-- After:
        fs:SetText(C.white .. displayName .. C.reset .. " " .. SocialQuestColors.GetUIColor("completed") .. L["Complete"] .. C.reset)
```

Line ~296 (needsShare branch):
```lua
-- Before:
        fs:SetText(C.unknown .. string.format(L["%s Needs it Shared"], name) .. C.reset)
-- After:
        fs:SetText(C.unknown .. string.format(L["%s Needs it Shared"], displayName) .. C.reset)
```

Line ~305 (no data branch):
```lua
-- Before:
        fs:SetText(C.unknown .. string.format(L["%s (no data)"], name) .. C.reset)
-- After:
        fs:SetText(C.unknown .. string.format(L["%s (no data)"], displayName) .. C.reset)
```

Line ~316 (has quest, no objectives branch):
```lua
-- Before:
            fs:SetText(C.white .. name .. C.reset)
-- After:
            fs:SetText(C.white .. displayName .. C.reset)
```

Line ~327 (objectives loop, per-objective row prefix):
```lua
-- Before:
            fs:SetText(C.white .. name .. C.reset .. " " .. clr .. (obj.text or "") .. C.reset)
-- After:
            fs:SetText(C.white .. displayName .. C.reset .. " " .. clr .. (obj.text or "") .. C.reset)
```

- [ ] **Step 3: In-game verification**

`/reload`. No Lua errors. Open the SQ window. With a Questie-only party member whose data has been bridged: their name in the window shows the Questie icon appended. Without bridge players: names render identically to before.

- [ ] **Step 4: Commit**

```bash
git add UI/RowFactory.lua
git commit -m "feat: append bridge nameTag icon to player names in RowFactory"
```

---

### Task 14: Add dataProvider to PartyTab playerEntry construction

**Files:**
- Modify: `UI/Tabs/PartyTab.lua` (lines 88–123 inside `buildPlayerRowsForQuest`)

The remote player loop iterates `SocialQuestGroupData.PlayerQuests` directly, so `playerData` is the PlayerQuests entry. Use `playerData.dataProvider` (no `and` guard needed — `playerData` is always non-nil inside the loop).

- [ ] **Step 1: Add dataProvider to the hasCompleted path (lines ~89–97)**

```lua
        if hasCompleted then
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = true,
                needsShare     = false,
                isComplete     = false,
                objectives     = {},
                dataProvider   = playerData.dataProvider,
            })
```

- [ ] **Step 2: Add dataProvider to the hasQuest path (lines ~98–111)**

```lua
        elseif hasQuest then
            local pquest = playerData.quests[questID]
            local pCI    = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                needsShare     = false,
                isComplete     = pquest.isComplete or false,
                objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pquest, myInfo),
                step           = pCI.knownStatus == AQL.ChainStatus.Known and pCI.step   or nil,
                chainLength    = pCI.knownStatus == AQL.ChainStatus.Known and pCI.length or nil,
                dataProvider   = playerData.dataProvider,
            })
```

- [ ] **Step 3: Add dataProvider to the needsShare path (lines ~112–123)**

```lua
        elseif localHasIt then
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                isComplete     = false,
                needsShare     = isEligibleForShare(questID, playerData),
                objectives     = {},
                dataProvider   = playerData.dataProvider,
            })
```

- [ ] **Step 4: In-game verification**

`/reload`. No Lua errors. Party tab renders without error. With bridge data present: Questie icon appears next to player name in party tab rows.

- [ ] **Step 5: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: include dataProvider in all PartyTab playerEntry construction paths"
```

---

### Task 15: Add dataProvider to SharedTab and MineTab playerEntry construction

**Files:**
- Modify: `UI/Tabs/SharedTab.lua` (lines ~147–157, ~214–224)
- Modify: `UI/Tabs/MineTab.lua` (lines ~80–91)

SharedTab uses `local playerData = SocialQuestGroupData.PlayerQuests[pName]` / `[playerName]` before building the entry, so use `playerData and playerData.dataProvider` (the `and` guard handles nil playerData defensively).

MineTab iterates `SocialQuestGroupData.PlayerQuests` directly, so `playerData` is always non-nil — use `playerData.dataProvider` directly.

- [ ] **Step 1: Update SharedTab chain player entry (lines ~147–157)**

The remote player entry inside the chain section already has `local playerData = SocialQuestGroupData.PlayerQuests[pName]`. Add `dataProvider`:

```lua
                                table.insert(entry.players, {
                                    name           = pName,
                                    isMe           = false,
                                    hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                                    hasCompleted   = false,
                                    needsShare     = false,
                                    isComplete     = pEng.qdata and pEng.qdata.isComplete or false,
                                    objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pEng.qdata or {}, localInfo),
                                    step           = pEng.step,
                                    chainLength    = pEng.chainLength,
                                    dataProvider   = playerData and playerData.dataProvider,
                                })
```

- [ ] **Step 2: Update SharedTab standalone quest player entry (lines ~214–224)**

The remote entry in the standalone quest section already has `local playerData = SocialQuestGroupData.PlayerQuests[playerName]`. Add `dataProvider`:

```lua
                    table.insert(entry.players, {
                        name           = playerName,
                        isMe           = false,
                        hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                        hasCompleted   = false,
                        needsShare     = false,
                        isComplete     = eng.qdata and eng.qdata.isComplete or false,
                        objectives     = SocialQuestTabUtils.BuildRemoteObjectives(eng.qdata or {}, localInfo),
                        dataProvider   = playerData and playerData.dataProvider,
                    })
```

- [ ] **Step 3: Update MineTab cross-chain peer entry (lines ~80–91)**

```lua
                            table.insert(entry.players, {
                                name           = playerName,
                                isMe           = false,
                                hasSocialQuest = playerData.hasSocialQuest,
                                step           = pCI.step,
                                chainLength    = pCI.length,
                                objectives     = {},
                                isComplete     = playerData.quests[pQuestID] and
                                                 playerData.quests[pQuestID].isComplete or false,
                                hasCompleted   = false,
                                needsShare     = false,
                                dataProvider   = playerData.dataProvider,
                            })
```

- [ ] **Step 4: In-game verification**

`/reload`. No Lua errors. Shared and Mine tabs render without error. With bridge data present: Questie icon appears on bridge player rows in both tabs.

- [ ] **Step 5: Commit**

```bash
git add UI/Tabs/SharedTab.lua UI/Tabs/MineTab.lua
git commit -m "feat: include dataProvider in SharedTab and MineTab playerEntry construction"
```

---

### Task 16: Wire BridgeRegistry into GroupComposition

**Files:**
- Modify: `Core/GroupComposition.lua` (lines ~85, ~124, ~127)

`BridgeRegistry:EnableAll()` must be called on both paths that invoke `SocialQuestComm:OnSelfJoinedGroup` — the "self joined" path (~line 124) and the "group type changed" path (~line 127). `BridgeRegistry:DisableAll()` is called on the self-left path alongside the existing `OnSelfLeftGroup` calls (~line 85).

- [ ] **Step 1: Add DisableAll on self-left-group (after line 85)**

Current code (lines 85–86):
```lua
            SocialQuestComm:OnSelfLeftGroup()
            SocialQuestGroupData:OnSelfLeftGroup()
```
Change to:
```lua
            SocialQuestComm:OnSelfLeftGroup()
            SocialQuestGroupData:OnSelfLeftGroup()
            SocialQuestBridgeRegistry:DisableAll()
```

- [ ] **Step 2: Add EnableAll on self-joined path (after line 124)**

Current code:
```lua
        SocialQuestComm:OnSelfJoinedGroup(groupType)
    elseif groupType ~= self.lastGroupType then
```
Change to:
```lua
        SocialQuestComm:OnSelfJoinedGroup(groupType)
        SocialQuestBridgeRegistry:EnableAll()
    elseif groupType ~= self.lastGroupType then
```

- [ ] **Step 3: Add EnableAll on group-type-changed path (after line 127)**

Current code:
```lua
        SocialQuestComm:OnSelfJoinedGroup(groupType)
    end
```
Change to:
```lua
        SocialQuestComm:OnSelfJoinedGroup(groupType)
        SocialQuestBridgeRegistry:EnableAll()
    end
```

- [ ] **Step 4: In-game verification**

`/reload`. No Lua errors.

Full end-to-end test with Questie installed and a Questie-only party member:
1. Form a party — their quests appear in the SQ window with the Questie icon next to their name.
2. The group member accepts a new quest — "accepted" banner fires.
3. The group member progresses an objective — objective progress banner fires.
4. The group member completes all objectives — "finished" banner fires.
5. The group member turns in or abandons the quest — no banner (remove packet carries no reason); quest disappears from the SQ window.
6. Disband party — their quests disappear from the SQ window.

Without Questie installed: `/run print(QuestieBridge:IsAvailable())` → `false`. No hooks installed. No errors.

- [ ] **Step 5: Commit**

```bash
git add Core/GroupComposition.lua
git commit -m "feat: wire BridgeRegistry EnableAll/DisableAll into GroupComposition join/leave"
```
