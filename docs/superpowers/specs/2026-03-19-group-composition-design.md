# GroupComposition Module & Comm Protocol Redesign

## Purpose

Eliminate message storms caused by `GROUP_ROSTER_UPDATE` firing on every raid subgroup reorganization. Introduce a dedicated `GroupComposition` module that classifies group changes, and simplify the communication protocol so syncs are triggered only when genuinely needed.

---

## Problem Statement

`GROUP_ROSTER_UPDATE` fires for every group change: player joins, player leaves, and subgroup moves within a raid. All three cases currently trigger the full comm cycle (beacon → request → init). During raid formation, a raid leader repeatedly moving players between subgroups fires this event continuously, causing:

- Redundant sync attempts for players who haven't changed membership
- SQ_BEACON broadcasts to the full raid channel on every move event
- Each beacon recipient immediately sends an SQ_REQUEST whisper to the sender
- The sender responds with up to 39 SQ_INIT whispers simultaneously — a burst pattern that risks Blizzard bot-detection false positives

**Root cause:** No built-in WoW API distinguishes join/leave from subgroup move. The addon must detect this itself.

---

## Design

### Module: `Core/GroupComposition.lua`

A new module, `SocialQuestGroupComposition`, becomes the sole handler for `GROUP_ROSTER_UPDATE` and `PLAYER_LOGIN`. All other modules stop listening to these WoW events directly.

**Responsibilities:**
- Maintain a snapshot of current group membership and subgroup assignments
- Diff each `GROUP_ROSTER_UPDATE` against the snapshot to classify changes
- Dispatch typed events to `Communications` and `GroupData`
- Immediately evict departed player data from `GroupData` on leave

**Internal state:**

```lua
memberSet       = {}   -- [fullName] = true, current members
memberSubgroups = {}   -- [fullName] = subgroupNumber (raid/BG only)
lastGroupType   = nil  -- group type from last snapshot: GroupType.X or nil
```

**Events dispatched (typed, not raw `GROUP_ROSTER_UPDATE`):**

| Event | When fired | Subscribers |
|---|---|---|
| `OnSelfJoinedGroup(groupType)` | Local player enters a group, OR group type changes (party→raid) | `Communications` |
| `OnSelfLeftGroup()` | Local player leaves all groups | `Communications`, `GroupData` |
| `OnMemberJoined(fullName, groupType)` | A new player appears in the group | `Communications`, `GroupData` |
| `OnMemberLeft(fullName)` | A player leaves the group | `Communications` — clears stale cooldown state. `GroupComposition` calls `GroupData:PurgePlayer(fullName)` inline before dispatching (not via a subscriber callback). |
| `OnSubgroupsChanged()` | Players moved between subgroups with no membership change | No current subscriber — defined as a future extension point |

Note: `OnMemberJoined` passes `groupType` so `Communications` can decide whether to whisper (party) or no-op (raid/BG) without querying WoW APIs itself.

**GroupType enum:**

```lua
-- Defined at file scope in GroupComposition.lua; exposed so Communications.lua can
-- compare groupType arguments without owning the type definition.
-- Values are plain English strings so debug output remains self-documenting.
-- Never transmitted over the wire; never localized.
local GroupType = {
    Party        = "party",
    Raid         = "raid",
    Battleground = "battleground",
}
SocialQuestGroupComposition.GroupType = GroupType
```

In `Core/Communications.lua`, alias it at file scope (after `SocialQuestGroupComposition` is defined by the TOC load order):

```lua
local GroupType = SocialQuestGroupComposition.GroupType
```

**Helper: `currentGroupType()`**

```lua
local function currentGroupType()
    if IsInRaid() then
        return GroupType.Raid
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return GroupType.Battleground
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return GroupType.Party
    end
    return nil
end
```

**Immediate eviction:**
When a member leaves, `GroupComposition` immediately calls `GroupData:PurgePlayer(fullName)` before dispatching `OnMemberLeft`. There is no delay. Rationale: in the new protocol a rejoining player unconditionally broadcasts SQ_INIT via their own `OnSelfJoinedGroup` handler, which is a definitive fresh snapshot that overwrites any stale data. Keeping stale data across a leave/rejoin cycle saves no work and causes the departed player's quests to remain visible in the GroupFrame until eviction fires — a UX defect. Immediate eviction avoids both problems.

`Communications` still handles `OnMemberLeft` to clear `lastInitSent[fullName]`: without this, a player who leaves and rejoins within 15 seconds would have their SQ_INIT broadcast on rejoin dropped by the cooldown, leaving us without their latest data.

**`OnSelfLeftGroup` cleanup sequence:**
1. Clear `memberSet = {}`, `memberSubgroups = {}`, `lastGroupType = nil`.
2. Dispatch `OnSelfLeftGroup()` to subscribers.

**`OnPlayerLogin` behavior:**
On login, `GroupComposition:OnPlayerLogin()` runs the same diff logic as `OnGroupRosterUpdate` against an empty `memberSet`. If the player is already in a group, it fires:
1. `OnSelfJoinedGroup(groupType)` first (so `Communications` clears `lastInitSent` and sends its broadcast before member-join whispers are queued)
2. `OnMemberJoined(name, groupType)` for each current member

**Diff algorithm:**

```
function OnGroupRosterUpdate():
  groupType = currentGroupType()
  -- Use UnitName("player"), NOT UnitFullName("player").
  -- UnitFullName always includes the home realm suffix (e.g. "Name-HomeRealm"), but
  -- GetRaidRosterInfo omits the realm suffix for same-realm players (returns just "Name").
  -- UnitName("player") returns nil for realm when same-realm — matching GetRaidRosterInfo's format.
  -- This guarantees selfName is excluded correctly in both the raid and party paths.
  selfName  = normalize(UnitName("player"))

  if groupType == nil:
    if non-empty(memberSet):
      -- Run full cleanup before notifying subscribers (mirrors OnSelfLeftGroup cleanup sequence):
      memberSet       = {}
      memberSubgroups = {}
      lastGroupType   = nil
      dispatch OnSelfLeftGroup()
    return

  -- Build new snapshot
  newMembers   = {}   -- [fullName] = true
  newSubgroups = {}   -- [fullName] = subgroupNumber

  if IsInRaid() or groupType == GroupType.Battleground:
    for i = 1 to GetNumGroupMembers():
      name, _, subgroup = GetRaidRosterInfo(i)
      fullName = normalize(name)            -- one-argument form: name may already contain "-Realm" suffix; do NOT pass additional GetRaidRosterInfo return values as realm
      newMembers[fullName]   = true
      newSubgroups[fullName] = subgroup
  else:  -- party
    newMembers[selfName] = true
    for i = 1 to GetNumGroupMembers() - 1:  -- GetNumGroupMembers() includes self in party; subtract 1 to iterate only non-self members
      name, realm = UnitName("party"..i)
      fullName = normalize(name, realm)
      newMembers[fullName] = true

  -- Handle self join or group-type change FIRST (before member loop).
  -- This guarantees OnSelfJoinedGroup fires before any OnMemberJoined, since
  -- Lua hash table iteration order is undefined and cannot be relied upon for ordering.
  if not memberSet[selfName] then
    -- Self just entered a group
    dispatch OnSelfJoinedGroup(groupType)
  elseif groupType ~= lastGroupType then
    -- Self already in a group but group type changed (e.g. party promoted to raid)
    dispatch OnSelfJoinedGroup(groupType)
  end

  -- Detect member joins (self excluded — handled above)
  for fullName in newMembers:
    if fullName ~= selfName and not memberSet[fullName]:
      dispatch OnMemberJoined(fullName, groupType)

  -- Detect member leaves (self excluded).
  -- Self-leave is handled by the nil-groupType early-return at the top of this function:
  -- if self has left all groups, currentGroupType() returns nil and we never reach this loop.
  -- Therefore selfName being in memberSet but absent from newMembers while groupType != nil
  -- is unreachable in the WoW client.
  for fullName in memberSet:
    if fullName ~= selfName and not newMembers[fullName]:
      GroupData:PurgePlayer(fullName)   -- immediate; rejoining always brings a fresh SQ_INIT
      dispatch OnMemberLeft(fullName)

  -- Detect subgroup moves (raid/BG only).
  -- Only compare entries for players who were already in the group (memberSubgroups[fullName] ~= nil).
  -- New joiners have no prior subgroup entry; comparing nil ~= sg would incorrectly set subgroupsChanged.
  subgroupsChanged = false
  for fullName, sg in newSubgroups:
    if memberSubgroups[fullName] ~= nil and memberSubgroups[fullName] ~= sg:
      subgroupsChanged = true; break
  if subgroupsChanged:
    dispatch OnSubgroupsChanged()

  -- Commit snapshot
  memberSet     = newMembers
  memberSubgroups = newSubgroups
  lastGroupType = groupType
```

**Name normalization rule:**

```lua
local function normalize(name, realm)
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name  -- may already contain "-Realm" (GetRaidRosterInfo cross-realm format)
end
```

`GetRaidRosterInfo(i)` returns a single name string that may already include a `-Realm` suffix for cross-realm members. Call `normalize(name)` (one argument). `UnitName(unit)` returns `name, realm` as separate values; call `normalize(name, realm)` (two arguments). Both paths produce the same `"Name-Realm"` key format for the same player.

**Party→raid key continuity:** For same-realm players, `UnitName` returns `"Name", nil` → key `"Name"`; `GetRaidRosterInfo` returns `"Name"` → key `"Name"`. For cross-realm players, `UnitName` returns `"Name", "Realm"` → key `"Name-Realm"`; `GetRaidRosterInfo` returns `"Name-Realm"` → key `"Name-Realm"`. Both APIs produce identical keys for the same player — no false `OnMemberJoined` fires during a party-to-raid promotion.

**Party-to-raid promotion:** Detected by `memberSet[selfName] and groupType ~= lastGroupType`. Fires `OnSelfJoinedGroup("raid")` causing a RAID channel SQ_INIT broadcast. Existing members also receive the `GROUP_ROSTER_UPDATE` on their clients and rebuild their snapshots using `GetRaidRosterInfo`; they receive the RAID SQ_INIT and respond with jittered whispers via the normal receive handler path.

**Leave-then-immediately-rejoin:** If a player leaves one group (nil groupType fires `OnSelfLeftGroup`, all state cleared) then joins another group, `OnSelfJoinedGroup` fires normally on the subsequent `GROUP_ROSTER_UPDATE`. The two events always occupy separate event firings and are handled sequentially.

**UI reload / PLAYER_LOGOUT:** When the UI reloads, all Lua state is discarded. `OnPlayerLogin` rebuilds membership state cleanly from scratch.

**`LE_PARTY_CATEGORY_INSTANCE` scope:** In TBC Anniversary, `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` is true for battlegrounds and arenas. The dungeon finder does not exist in TBC. The `"battleground"` label in `currentGroupType()` covers both BG and arena contexts.

---

### Changes to `Core/GroupData.lua`

- **Remove** `OnGroupChanged()` — no longer handles `GROUP_ROSTER_UPDATE`
- **Add** `OnMemberJoined(fullName, groupType)` — creates `{ hasSocialQuest=false, completedQuests={} }` stub. `groupType` is accepted but unused; it is passed for signature consistency with the dispatched event.
- **Add** `PurgePlayer(fullName)` — sets `self.PlayerQuests[fullName] = nil`; called by `GroupComposition` immediately when a member leaves
- **Add** `OnSelfLeftGroup()` — sets `self.PlayerQuests = {}`; called after `GroupComposition` has already cancelled timers and cleared its own state
- `OnMemberLeft` has no `GroupData` handler; eviction is managed entirely by `GroupComposition`
- All existing receive handlers (`OnInitReceived`, `OnUpdateReceived`, `OnObjectiveReceived`, `OnUnitQuestLogChanged`) are unchanged

---

### Changes to `Core/Communications.lua`

`SendFullInit(channel, targetName)` and `SendReqCompleted()` are **existing functions** called unchanged from new handlers. `lastInitSent` stores `GetTime()` timestamps (used for the 15-second per-sender cooldown check: `GetTime() - lastInitSent[sender] < 15`).

Add a new local table at the top of the file:

```lua
local pendingResponses = {}  -- [sender] = timerHandle; tracks jitter-delayed SQ_INIT and SQ_REQUEST responses
```

#### Removed

- `OnGroupChanged()` — no longer handles `GROUP_ROSTER_UPDATE`
- `SendBeacon(channel)` and its call sites — SQ_BEACON is eliminated entirely
- `"SQ_BEACON"` from the `PREFIXES` table and its receive handler block

#### Added

- `OnSelfJoinedGroup(groupType)`:
  - Clear `lastInitSent = {}` and cancel + clear all timers in `pendingResponses = {}`
  - `GroupType.Party`: `self:SendFullInit("PARTY")` then `self:SendReqCompleted()`
  - `GroupType.Raid`: `self:SendFullInit("RAID")` then `self:SendReqCompleted()`
  - `GroupType.Battleground`: `self:SendFullInit("INSTANCE_CHAT")` then `self:SendReqCompleted()`
  - Note: `SendReqCompleted()` calls `GetActiveChannel()` internally. By the time `OnSelfJoinedGroup` fires, `IsInRaid()` / `IsInGroup()` already reflect the new group type, so `GetActiveChannel()` returns the correct channel.

- `OnSelfLeftGroup()`:
  - Cancel all timers in `pendingResponses` via `SocialQuest:CancelTimer`
  - Clear `pendingResponses = {}` and `lastInitSent = {}`

- `OnMemberLeft(fullName)`:
  - `lastInitSent[fullName] = nil` — clears the 15-second cooldown for that sender
  - If `pendingResponses[fullName]`, cancel and clear it
  - Rationale: if the player leaves and rejoins within 15 seconds, their SQ_INIT broadcast on rejoin would be dropped by the cooldown without this clearing step, leaving us without their latest data. Clearing on leave guarantees a fresh response on any subsequent SQ_INIT from them.

- `OnMemberJoined(fullName, groupType)`:
  - `GroupType.Party` only: `self:SendFullInit("WHISPER", fullName)` — whisper the new member directly, since they won't have received our broadcast (they weren't in the group when we sent it)
  - `GroupType.Raid` or `GroupType.Battleground`: no-op — the new member broadcasts SQ_INIT to the channel themselves; existing members respond via the receive handler

#### Modified: SQ_INIT receive handler

**Party distribution (`"PARTY"`):** Store in `GroupData` normally (call `SocialQuestGroupData:OnInitReceived(sender, payload)`). No **outbound** response action. The existing-member response is already handled by `OnMemberJoined("party")`, which fires simultaneously via `GroupComposition` and sends the whisper directly. No receive-side jitter timer or whisper is scheduled.

**Raid/BG broadcast (`"RAID"` or `"INSTANCE_CHAT"`):** The new joiner's SQ_INIT announces their presence. Schedule a jittered whisper response:

```lua
if distribution == "RAID" or distribution == "INSTANCE_CHAT" then
    if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
        -- on cooldown; skip (prevents duplicate responses)
    else
        lastInitSent[sender] = GetTime()
        if pendingResponses[sender] then
            SocialQuest:CancelTimer(pendingResponses[sender])
        end
        pendingResponses[sender] = SocialQuest:ScheduleTimer(function()
            pendingResponses[sender] = nil
            self:SendFullInit("WHISPER", sender)
        end, math.random(1, 8))  -- minimum 1s jitter; 0 not used to guarantee at least one frame of spread
    end
end
```

**Whisper (`"WHISPER"`):** Process normally (store in `GroupData`). No outbound response.

**`lastInitSent` timing note:** The timestamp is stored at schedule time (`lastInitSent[sender] = GetTime()` before `ScheduleTimer`), not inside the timer closure. This prevents a second SQ_INIT from the same sender arriving during the jitter window from scheduling a duplicate response. An implementer who stamps inside the timer closure (at fire time) instead of at schedule time would break the deduplication guard for rapid re-broadcasts.

**Party whisper burst:** When a new member joins an existing party, each SQ-running party member independently fires `OnMemberJoined("party")` and sends a whisper to the new joiner. For a 4-person party this is a burst of at most 3 simultaneous whispers to a single recipient — well within normal communication limits. This is intentional and requires no throttle.

#### Modified: SQ_REQUEST receive handler

Used only by Force Resync. Replace the existing synchronous `SendFullInit` call with a jittered response using `pendingResponses`:

```lua
-- 15-second cooldown check (same guard as SQ_INIT handler)
if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
    return  -- on cooldown; drop
end
lastInitSent[sender] = GetTime()
if pendingResponses[sender] then
    SocialQuest:CancelTimer(pendingResponses[sender])
end
pendingResponses[sender] = SocialQuest:ScheduleTimer(function()
    pendingResponses[sender] = nil
    self:SendFullInit("WHISPER", sender)
end, math.random(1, 4))
```

Minimum jitter of 1 second (rather than 0) ensures at least one frame of spread even for the first responder. The 1–4 second window (vs 1–8 seconds for join broadcasts) is intentional: Force Resync is a manual debug action on a stable group, so a shorter spread is acceptable and responds more promptly.

#### Protocol summary (new)

| Scenario | Outgoing messages | Incoming messages |
|---|---|---|
| Self joins raid (39 existing SQ members) | 2: SQ_INIT to RAID + SQ_REQ_COMPLETED to RAID | Up to 39 jittered SQ_INIT whispers spread over 1–8s |
| Self joins party (4 existing SQ members) | 2: SQ_INIT to PARTY + SQ_REQ_COMPLETED to PARTY | Up to 4 SQ_INIT whispers — each existing member's `OnMemberJoined("party")` fires on their client and whispers us directly |
| New SQ member joins our party | 1: SQ_INIT whisper to new member (`OnMemberJoined` fires for us) | 1 SQ_INIT broadcast from new member via PARTY channel (no receive-side response needed) |
| New SQ member joins our raid | 1: jittered SQ_INIT whisper to new member (1–8s, via receive handler) | 1 SQ_INIT broadcast from new member via RAID channel |
| Player moves between subgroups | 0 | 0 |
| Player leaves then rejoins | 1: jittered SQ_INIT whisper to returning member (their data was purged on leave; their SQ_INIT on rejoin is the definitive fresh snapshot) | 1 SQ_INIT broadcast from returning member → triggers our jittered whisper response |
| Party promoted to raid | 2: SQ_INIT to RAID + SQ_REQ_COMPLETED (via `OnSelfJoinedGroup("raid")`) | Up to N jittered SQ_INIT whispers from existing members (they receive the RAID broadcast) |
| Force Resync (debug) | 1 SQ_REQUEST to channel | 1 jittered SQ_INIT whisper per SQ member, 1–4s, with 15s per-sender cooldown |

---

### Changes to `SocialQuest.lua`

- Remove `GROUP_ROSTER_UPDATE` wiring to `SocialQuestComm:OnGroupChanged()` and `SocialQuestGroupData:OnGroupChanged()`
- Remove `PLAYER_LOGIN` → `SocialQuestComm:OnGroupChanged()` (currently wired there)
- Add `GROUP_ROSTER_UPDATE` → `SocialQuestGroupComposition:OnGroupRosterUpdate()`
- Add `PLAYER_LOGIN` → `SocialQuestGroupComposition:OnPlayerLogin()`
- Add `SocialQuestGroupComposition:Initialize()` call in `OnEnable()` alongside existing `SocialQuestComm:Initialize()`

---

### Changes to `SocialQuest.toc`

Add `Core/GroupComposition.lua` before `Core/Communications.lua` and `Core/GroupData.lua`. Ace3 module wiring is runtime, not load-time, so strict ordering is not required — but placing it first makes the dependency relationship clear to readers.

---

## Files Changed

| File | Change type |
|---|---|
| `Core/GroupComposition.lua` | **New** |
| `Core/GroupData.lua` | Modified — remove `OnGroupChanged`; add `OnMemberJoined`, `PurgePlayer`, `OnSelfLeftGroup` |
| `Core/Communications.lua` | Modified — remove `OnGroupChanged`, `SendBeacon`, SQ_BEACON; add `OnSelfJoinedGroup`, `OnMemberJoined`, `OnMemberLeft`, `OnSelfLeftGroup`; modify SQ_INIT and SQ_REQUEST handlers; add `pendingResponses` table |
| `SocialQuest.lua` | Modified — rewire event registrations, add `GroupComposition:Initialize()` call |
| `SocialQuest.toc` | Modified — add `Core/GroupComposition.lua` entry |

---

## What Is Not Changed

- `SendFullInit(channel, targetName)` function signature and implementation
- `SendReqCompleted()` function signature and implementation
- `SQ_REQ_COMPLETED` / `SQ_RESP_COMPLETE` flow (completed quest history exchange)
- `SQ_UPDATE` and `SQ_OBJECTIVE` broadcast logic — both use `GetActiveChannel()` which is group-type-aware and returns the correct channel after a party→raid promotion
- `SQ_FOLLOW_START` / `SQ_FOLLOW_STOP`
- `GetActiveChannel()` priority logic
- All `GroupData` receive handlers (`OnInitReceived`, `OnUpdateReceived`, `OnObjectiveReceived`, `OnUnitQuestLogChanged`)
- UI layer (GroupFrame, RowFactory, Tabs)
- Options / debug panel
