# Questie Bridge Design Spec

## Goal

Allow party members who have Questie installed but not SocialQuest to have their quest data
displayed in the SocialQuest window and to trigger banner announcements for the local player
when those members accept quests, progress objectives, or complete quests.

## Background

SocialQuest uses its own AceComm protocol (SQ_INIT, SQ_UPDATE, SQ_OBJECTIVE) to share quest
state between group members. Players without SocialQuest produce no data in GroupData and are
shown as stubs with `hasSocialQuest=false`. Questie maintains its own parallel comms layer
(`QuestieComms`) and stores per-player objective state in `QuestieComms.remoteQuestLogs`.

By hooking Questie's public methods we can populate GroupData for Questie-only players without
modifying Questie or replicating its wire protocol.

### Known limitations

- **Zero-objective quests**: Questie only broadcasts quest updates when a quest has trackable
  objectives. Quests with no objectives (certain quest types) are silently skipped — they never
  appear in `remoteQuestLogs`. SQ will never see an accept, finish, or remove event for these
  quests from Questie-only players.
- **Initial sync window**: On group join, Questie fires a 2-second bucket broadcast of the
  full quest log. Hydrating before enabling hooks reduces spurious "accepted" banners, but if
  the snapshot is empty at join time the first sync may still appear as new quests. Accepted as
  a minor limitation.
- **completedQuests not populated for bridge players**: Because the Questie remove packet
  carries no reason code, SQ cannot determine whether a removed quest was turned in or
  abandoned. `completedQuests[questID]` is never set for Questie-only players. Consequence:
  if a Questie-only member turns in a quest, they disappear from the quest's player list
  (rather than showing as "done") and are treated as "not engaged" for the
  "everyone has finished" check. This is a known limitation of the bridge approach.
- **Group-roster filtering**: `OnBridgeQuestUpdate` and `OnBridgeHydrate` only process players
  who already have a stub in `PlayerQuests` (created by `GroupComposition:OnMemberJoined`).
  Questie's hooks fire for all players Questie knows about, not just current group members.
  If bridge data arrives in the narrow window between a player joining and
  `OnMemberJoined` creating their stub, that update is silently dropped. This is acceptable
  given the ordering guarantees of WoW's event system.

---

## Constants

Two new constant tables are added to `SocialQuest` in `SocialQuest.lua`, initialized before any
module loads:

### DataProviders

```lua
SocialQuest.DataProviders = {
    SocialQuest = "SocialQuest",
    Questie     = "Questie",
}
```

Every `PlayerQuests` entry gains a top-level `dataProvider` field set to one of these values.
SocialQuest players have `dataProvider = DataProviders.SocialQuest`. Questie-only players have
`dataProvider = DataProviders.Questie`. Players with only the hasSocialQuest=false stub have
`dataProvider = nil`.

If a Questie-only player installs SocialQuest mid-session and broadcasts SQ_INIT, `OnInitReceived`
upgrades their entry to `DataProviders.SocialQuest` and bridge data is subsequently ignored for
that player (see GroupData changes below).

### EventTypes

```lua
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

String values are **unchanged** from current literals — the values `"accepted"`, `"completed"`,
etc. are used as AceDB saved-variable keys and must remain stable. All existing code that
compares or passes event type strings is updated to use these constants. This touches
`Announcements.lua`, `GroupData.lua`, and `Communications.lua`.

Note: `Colors.lua` defines these strings as table key literals in its `event`/`eventCB` tables
(used for keyed lookup, not comparison). Those key literals do not need to change — they remain
as plain string literals. No change needed to `Colors.lua`.

---

## Bridge Interface Contract

A bridge module is a Lua table that satisfies the following contract (enforced by convention,
documented in `BridgeRegistry.lua`):

```lua
-- Required fields:
--   bridge.provider  = SocialQuest.DataProviders.X   (string identity constant)
--   bridge.nameTag   = string or nil
--       Appended after the player's name in RowFactory to signal data provenance.
--       May be a WoW texture escape "|TPath:w:h|t" or plain text. nil = no annotation.
--       SocialQuest's own DataProviders.SocialQuest bridge uses nil (first-party, unmarked).
--
-- Required methods:
--   bridge:IsAvailable() -> bool
--       Returns true if the source addon is loaded and its public API is accessible.
--
--   bridge:Enable() -> void
--       Installs hooks or listeners. Called by BridgeRegistry after snapshot hydration.
--       Safe to call multiple times (internal guard required). Must check _active to
--       avoid double-hydration on group type changes.
--
--   bridge:Disable() -> void
--       Suspends processing. Does NOT remove hooks (hooksecurefunc is permanent).
--       Sets an internal _active flag; hook callbacks check this flag before processing.
--
--   bridge:GetSnapshot() -> { [fullName] = { [questID] = questEntry } }
--       Returns current known state from the source addon for initial hydration.
--       Called by BridgeRegistry before Enable(). Returns {} if unavailable.
--
-- Bridges notify GroupData by calling:
--   SocialQuestGroupData:OnBridgeQuestUpdate(provider, fullName, questEntry)
--   SocialQuestGroupData:OnBridgeQuestRemove(provider, fullName, questID)
--
-- BridgeRegistry calls GroupData directly for hydration:
--   SocialQuestGroupData:OnBridgeHydrate(provider, snapshot)
```

---

## BridgeRegistry

**File:** `Core/BridgeRegistry.lua`

**TOC position:** After `Core/Announcements.lua`. Both BridgeRegistry and QuestieBridge call
`SocialQuestGroupData`, `SocialQuestAnnounce`, and `SocialQuestGroupFrame` at runtime; all
those globals must be loaded before the bridge hooks fire. Loading after Announcements.lua
satisfies all dependencies. `Core/QuestieBridge.lua` goes immediately after.

Thin lifecycle manager. No quest logic.

```lua
SocialQuestBridgeRegistry = {}
SocialQuestBridgeRegistry._bridges = {}

function SocialQuestBridgeRegistry:Register(bridge)
    table.insert(self._bridges, bridge)
end

function SocialQuestBridgeRegistry:EnableAll()
    for _, bridge in ipairs(self._bridges) do
        -- Skip if already active (handles group-type changes where OnSelfJoinedGroup
        -- fires again without an intervening leave; _active prevents re-hydration).
        if bridge:IsAvailable() and not bridge._active then
            -- Hydrate BEFORE enabling hooks to reduce spurious "accepted" banners
            -- from Questie's initial 2-second sync broadcast on group join.
            local snapshot = bridge:GetSnapshot()
            SocialQuestGroupData:OnBridgeHydrate(bridge.provider, snapshot)
            bridge:Enable()
        end
    end
end

function SocialQuestBridgeRegistry:DisableAll()
    for _, bridge in ipairs(self._bridges) do
        bridge:Disable()
    end
end

function SocialQuestBridgeRegistry:GetNameTag(provider)
    for _, bridge in ipairs(self._bridges) do
        if bridge.provider == provider then
            return bridge.nameTag
        end
    end
    return nil
end
```

`EnableAll()` is called by `GroupComposition` alongside `SocialQuestComm:OnSelfJoinedGroup()`
when the local player joins a group (GroupComposition.lua ~line 124). `DisableAll()` is called
alongside `SocialQuestComm:OnSelfLeftGroup()` and `SocialQuestGroupData:OnSelfLeftGroup()` when
the local player leaves all groups (GroupComposition.lua ~line 85).

---

## QuestieBridge

**File:** `Core/QuestieBridge.lua`

**TOC position:** Immediately after `Core/BridgeRegistry.lua`.

Implements the bridge interface for Questie. Hooks two public Questie methods:

- `QuestieComms:InsertQuestDataPacket(questPacket, playerName)` — called after every parsed
  quest update (accept, objective progress, objectives complete). `questPacket.id` is the
  questID; `questPacket.objectives` is an array of `{ id, type, fulfilled, required, finished }`.
- `QuestieComms.data:RemoveQuestFromPlayer(questId, playerName)` — called when any quest is
  removed from a player's log (turn-in or abandon; the packet carries no reason code).

The `playerName` argument in both hooks is the AceComm sender string — same `"Name-Realm"` (or
`"Name"` for same-realm) format used by SQ's own comm layer, matching `PlayerQuests` keys.

### Identity and nameTag

```lua
QuestieBridge.provider = SocialQuest.DataProviders.Questie
QuestieBridge.nameTag  = "|TInterface/AddOns/Questie/Icons/<icon>:12:12|t"
-- Exact icon path must be verified against Questie source at implementation time.
-- Look for the icon used in Questie's chat message prefix in QuestieComms.lua.
```

### Lifecycle

`hooksecurefunc` is permanent — hooks cannot be removed once installed. `Enable()` installs
hooks once (guarded by `_hookInstalled`) and sets `_active = true`. `Disable()` sets
`_active = false`. All callbacks check `_active` before processing.

```lua
function QuestieBridge:IsAvailable()
    return QuestieComms ~= nil and QuestieComms.data ~= nil
end

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

function QuestieBridge:Disable()
    self._active = false
end
```

### Snapshot

`QuestieComms.remoteQuestLogs[questId][playerName]` holds current objective arrays for all
remote players Questie knows about. `GetSnapshot()` pivots this into a player-keyed table.
`GroupData:OnBridgeHydrate` will filter to known group members, so no filtering is needed here.

```lua
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
```

### Data translation

Questie objective: `{ id, type, fulfilled, required, finished }`
SQ objective: `{ numFulfilled, numRequired, isFinished }`

```lua
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
                    or ("Quest " .. questId),   -- final fallback when AQL has no data
        isComplete   = allFinished,
        isFailed     = false,  -- Questie does not transmit failure state
        snapshotTime = SocialQuestWowAPI.GetTime(),
        objectives   = objs,
    }
end
```

### Hook handlers

```lua
function QuestieBridge:_OnQuestUpdated(questPacket, playerName)
    local entry = self:_BuildQuestEntry(questPacket.id, questPacket.objectives or {})
    SocialQuestGroupData:OnBridgeQuestUpdate(self.provider, playerName, entry)
end

function QuestieBridge:_OnQuestRemoved(questId, playerName)
    SocialQuestGroupData:OnBridgeQuestRemove(self.provider, playerName, questId)
end
```

### Registration

At the bottom of the file, executed at load time:

```lua
SocialQuestBridgeRegistry:Register(QuestieBridge)
```

---

## GroupData Changes

**File:** `Core/GroupData.lua`

### dataProvider field

Added to every `PlayerQuests` entry.

- `OnInitReceived` — add `dataProvider = SocialQuest.DataProviders.SocialQuest` to the new
  entry it constructs. This is also what causes bridge data to be ignored for this player
  going forward (the `if pdata and pdata.hasSocialQuest then return end` guard in
  `OnBridgeQuestUpdate`).
- `OnUpdateReceived` — when it creates a new entry (no prior SQ_INIT), add
  `dataProvider = SocialQuest.DataProviders.SocialQuest`.
- `OnMemberJoined` stub — leaves `dataProvider = nil` (unknown until data arrives).
- Bridge methods — set `dataProvider` to the bridge's provider constant.

### OnBridgeQuestUpdate

Only processes players who already have a stub in `PlayerQuests` (created by
`GroupComposition:OnMemberJoined`). Questie's hooks fire for all players Questie knows about,
so entries must not be created here for non-group-members.

Diffs incoming quest state against stored state to detect accept/progress/complete events.
Fires Announce only for verifiable events (see Announce Changes below).

```lua
function SocialQuestGroupData:OnBridgeQuestUpdate(provider, fullName, questEntry)
    local pdata = self.PlayerQuests[fullName]
    if not pdata then return end           -- Not a known group member; ignore
    if pdata.hasSocialQuest then return end  -- SQ data takes precedence

    pdata.dataProvider = provider
    pdata.lastSync     = SQWowAPI.GetTime()

    local questID  = questEntry.questID
    local existing = pdata.quests[questID]
    local isNew    = existing == nil

    -- Objective progress: only diff when quest was already known.
    -- Avoids firing progress banners for catch-up data seen for the first time.
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

        -- Quest complete: all objectives finished and wasn't before.
        if questEntry.isComplete and not existing.isComplete then
            SocialQuestAnnounce:OnRemoteQuestEvent(
                fullName, SocialQuest.EventTypes.Finished, questID, questEntry.title)
        end
    end

    pdata.quests[questID] = questEntry

    if isNew then
        SocialQuestAnnounce:OnRemoteQuestEvent(
            fullName, SocialQuest.EventTypes.Accepted, questID, questEntry.title)
    end

    SocialQuestGroupFrame:RequestRefresh()
end
```

### OnBridgeQuestRemove

Removes the entry silently. No Announce call — turn-in vs abandon is unverifiable.
`completedQuests[questID]` is NOT set (reason unknown). See Known Limitations.

```lua
function SocialQuestGroupData:OnBridgeQuestRemove(provider, fullName, questID)
    local pdata = self.PlayerQuests[fullName]
    if not pdata or pdata.hasSocialQuest then return end
    if pdata.quests[questID] then
        pdata.quests[questID] = nil
        SocialQuestGroupFrame:RequestRefresh()
    end
end
```

### OnBridgeHydrate

Populates existing group members without firing banners. Called by BridgeRegistry before
`Enable()`. Only hydrates players who already have a stub in `PlayerQuests` — skips any
player in the snapshot who is not a current group member.

```lua
function SocialQuestGroupData:OnBridgeHydrate(provider, snapshot)
    for fullName, quests in pairs(snapshot) do
        local pdata = self.PlayerQuests[fullName]
        -- Only hydrate known group members who don't yet have SQ data
        if pdata and not pdata.hasSocialQuest then
            pdata.dataProvider    = provider
            pdata.lastSync        = SQWowAPI.GetTime()
            pdata.quests          = quests
            -- Preserve completedQuests if any were accumulated before hydration
        end
    end
    SocialQuestGroupFrame:RequestRefresh()
end
```

---

## RowFactory / Tab Provider Changes

**Files:** `UI/RowFactory.lua`, `UI/Tabs/PartyTab.lua`, `UI/Tabs/SharedTab.lua`,
`UI/Tabs/MineTab.lua`

Player names are rendered by `RowFactory.AddPlayerRow`, which reads `playerEntry.name` at line
273. The `playerEntry` table is constructed by the tab providers before being passed to
`AddPlayerRow`.

**Tab providers** (PartyTab, SharedTab, MineTab): every code path that builds a `playerEntry`
for a group member must include the `dataProvider` field from their `PlayerQuests` entry.
This includes the hasCompleted path, the needsShare path, the active-quest path, and the
local-player paths. Example:

```lua
local pdata = SocialQuestGroupData.PlayerQuests[fullName]
local playerEntry = {
    name         = shortName,
    -- ... existing fields ...
    dataProvider = pdata and pdata.dataProvider,
}
```

**RowFactory.AddPlayerRow**: append the nameTag to the display name variable immediately after
reading `playerEntry.name`. Use a separate `displayName` variable to avoid shadowing:

```lua
local name        = playerEntry.name or "Unknown"
local nameTag     = playerEntry.dataProvider
                 and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
local displayName = nameTag and (name .. " " .. nameTag) or name
-- Use displayName in all subsequent SetText calls
```

No other RowFactory or GroupFrame logic changes. Questie-sourced entries render identically to
SQ entries in every other respect.

---

## Announce Changes

**File:** `Core/Announcements.lua`

### checkAllFinished

The guard at line 330 currently suppresses "everyone has finished" whenever any group member
has `hasSocialQuest == false`. Bridge players have `hasSocialQuest = false` but provide full
objective data — they must not trigger this suppression.

Change the guard to suppress only when a member has **no data source at all**:

```lua
-- Before:
if not entry.hasSocialQuest then
    SocialQuest:Debug("Banner", "All finished suppressed: non-SQ member present")
    return
end

-- After:
if not entry.hasSocialQuest and not entry.dataProvider then
    SocialQuest:Debug("Banner", "All finished suppressed: member with no data present")
    return
end
```

The subsequent engaged/done checks (lines 358–371) use `entry.quests[questID].isComplete` and
`entry.completedQuests[questID]`, which work identically for bridge-populated entries. Note that
bridge players who have turned in a quest will not have a `completedQuests` entry (see Known
Limitations) and will therefore not be treated as "done" in this check.

### Verifiable events for Questie-only players

| Event | Fires for Questie-only players? | Reason |
|---|---|---|
| Accepted | Yes | Detected when quest first appears in InsertQuestDataPacket |
| Objective progress | Yes | Detected by diffing fulfilled counts |
| Objective complete | Yes | Detected when objective.finished flips to true |
| Finished (all objectives done) | Yes | Detected when isComplete flips to true |
| Completed (turned in) | No | Remove packet carries no reason code |
| Abandoned | No | Remove packet carries no reason code |
| Failed | No | Not transmitted by Questie |

By design, `OnBridgeQuestRemove` never calls Announce, so Completed/Abandoned/Failed never
reach `OnRemoteQuestEvent` for Questie-only players. A defense-in-depth guard enforces this
explicitly in case of future call site changes:

```lua
function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID, cachedTitle)
    local pdata    = SocialQuestGroupData.PlayerQuests[sender]
    local provider = pdata and pdata.dataProvider
    if provider and provider ~= SocialQuest.DataProviders.SocialQuest then
        if eventType == SocialQuest.EventTypes.Completed
        or eventType == SocialQuest.EventTypes.Abandoned
        or eventType == SocialQuest.EventTypes.Failed then
            return
        end
    end
    -- existing logic continues unchanged
end
```

### EventTypes constant replacement

All event type string literals in `Announcements.lua`, `GroupData.lua`, and `Communications.lua`
are replaced with `SocialQuest.EventTypes.*` constants. The string values are identical — this
is a pure readability refactor with no behavioral change. `Colors.lua` table key literals are
not changed (they are storage-format keys, not comparison values).

---

## Files Created or Modified

### New files

| File | Purpose |
|---|---|
| `Core/BridgeRegistry.lua` | Bridge lifecycle manager and nameTag lookup |
| `Core/QuestieBridge.lua` | Questie implementation of the bridge interface |

### Modified files

| File | Change |
|---|---|
| `SocialQuest.lua` | Add `DataProviders` and `EventTypes` constant tables |
| `Core/GroupData.lua` | Add `dataProvider` field in `OnInitReceived`, `OnUpdateReceived`; add `OnBridgeQuestUpdate`, `OnBridgeQuestRemove`, `OnBridgeHydrate`; replace event type string literals with `EventTypes` constants |
| `Core/GroupComposition.lua` | Call `BridgeRegistry:EnableAll()` on group join (~line 124); call `BridgeRegistry:DisableAll()` on group leave (~line 85) |
| `Core/Announcements.lua` | Update `checkAllFinished` guard; add suppression guard in `OnRemoteQuestEvent`; replace event type string literals with `EventTypes` constants |
| `Core/Communications.lua` | Replace event type string literals with `EventTypes` constants |
| `UI/RowFactory.lua` | Append nameTag to displayed name using `playerEntry.dataProvider`; use `displayName` variable |
| `UI/Tabs/PartyTab.lua` | Include `dataProvider` in all playerEntry construction paths |
| `UI/Tabs/SharedTab.lua` | Include `dataProvider` in all playerEntry construction paths |
| `UI/Tabs/MineTab.lua` | Include `dataProvider` in all playerEntry construction paths |
| `SocialQuest.toc` | Add `Core/BridgeRegistry.lua` and `Core/QuestieBridge.lua` after `Core/Announcements.lua`, BridgeRegistry before QuestieBridge |
