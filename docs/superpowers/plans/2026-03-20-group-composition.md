# GroupComposition Module Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raw `GROUP_ROSTER_UPDATE` / `PLAYER_LOGIN` handling in `Communications` and `GroupData` with a new `GroupComposition` module that classifies group changes (join vs. leave vs. subgroup-move), eliminating the message storms that occurred during raid reorganization.

**Architecture:** A new `Core/GroupComposition.lua` module becomes the sole listener for `GROUP_ROSTER_UPDATE` and `PLAYER_LOGIN`. It diffs each event against a membership snapshot to classify what changed, then calls typed methods on `Communications` and `GroupData` directly (no pub/sub framework — just direct calls). `Communications` is overhauled to remove SQ_BEACON entirely; syncs are driven by `OnSelfJoinedGroup` (outbound SQ_INIT on join) and jittered whisper responses to incoming SQ_INIT broadcasts (for raid/BG).

**Tech Stack:** Lua 5.1, Ace3 (AceAddon, AceTimer, AceComm, AceSerializer), WoW TBC Anniversary API (GetRaidRosterInfo, UnitName, IsInRaid, IsInGroup, LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE)

**Spec:** `docs/superpowers/specs/2026-03-19-group-composition-design.md`

---

## Chunk 1: Module skeleton and GroupData new methods

### Task 1: GroupComposition module skeleton + TOC registration

**What this does:** Creates the new `Core/GroupComposition.lua` file with its helper functions and stub methods, adds it to the load order, and wires `Initialize()` into `SocialQuest:OnEnable()`. The old event handlers in `SocialQuest.lua` are left in place — no behavior changes yet. The addon must load cleanly after this task.

**Files:**
- Create: `Core/GroupComposition.lua`
- Modify: `SocialQuest.toc` — add load entry
- Modify: `SocialQuest.lua` — add `SocialQuestGroupComposition:Initialize()` call in `OnEnable()`

---

- [ ] **Step 1: Add `Core/GroupComposition.lua` to the TOC**

Open `SocialQuest.toc`. Find the `Core\` section (currently `Core\GroupData.lua` followed by `Core\Communications.lua`). Add `Core\GroupComposition.lua` **before** both:

```
Core\GroupComposition.lua
Core\GroupData.lua
Core\Communications.lua
```

The full `Core\` block should now read:
```
Core\GroupComposition.lua
Core\GroupData.lua
Core\Communications.lua
Core\Announcements.lua
```

---

- [ ] **Step 2: Create `Core/GroupComposition.lua`**

Create the file with the full skeleton below. The `OnGroupRosterUpdate` and `OnPlayerLogin` bodies are stubs — the diff algorithm is added in Task 4.

```lua
-- Core/GroupComposition.lua
-- Sole handler for GROUP_ROSTER_UPDATE and PLAYER_LOGIN.
-- Diffs each event against a membership snapshot to classify changes
-- (join / leave / subgroup-move), then calls typed methods on
-- Communications and GroupData directly.
--
-- Internal state:
--   memberSet       [fullName] = true     -- current group members
--   memberSubgroups [fullName] = subgroup -- raid/BG subgroup numbers
--   lastGroupType   GroupType.X|nil       -- group type from last snapshot

------------------------------------------------------------------------
-- GroupType enum
-- Values are plain English strings so debug output is self-documenting.
-- Never transmitted over the wire; never localized.
------------------------------------------------------------------------

local GroupType = {
    Party        = "party",
    Raid         = "raid",
    Battleground = "battleground",
}

SocialQuestGroupComposition = {}

-- Expose for Communications.lua, which compares groupType arguments
-- but does not own the type definition.
SocialQuestGroupComposition.GroupType = GroupType

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

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

-- Produces a canonical "Name" or "Name-Realm" key.
-- One-argument form: name may already contain "-Realm" (GetRaidRosterInfo cross-realm format).
-- Two-argument form: name + realm from UnitName(unit); appends realm when non-nil/non-empty.
local function normalize(name, realm)
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

-- Called from SocialQuest:OnEnable().
function SocialQuestGroupComposition:Initialize()
    self.memberSet       = {}
    self.memberSubgroups = {}
    self.lastGroupType   = nil
    SocialQuest:Debug("Group", "GroupComposition initialized")
end

------------------------------------------------------------------------
-- Event handlers (stubs — full diff implemented in Task 4)
------------------------------------------------------------------------

function SocialQuestGroupComposition:OnGroupRosterUpdate()
    -- Full diff algorithm implemented in Task 4.
end

-- On login/reload, memberSet is empty. Running the diff against empty
-- state fires OnSelfJoinedGroup then OnMemberJoined for each current
-- member — the correct bootstrap behavior.
function SocialQuestGroupComposition:OnPlayerLogin()
    self:OnGroupRosterUpdate()
end
```

---

- [ ] **Step 3: Wire `Initialize()` into `SocialQuest:OnEnable()`**

Open `SocialQuest.lua`. Find the `OnEnable()` function. Add `SocialQuestGroupComposition:Initialize()` immediately before `SocialQuestComm:Initialize()`:

```lua
    -- Initialize group composition tracker.
    SocialQuestGroupComposition:Initialize()

    -- Register AceComm prefixes.
    SocialQuestComm:Initialize()
```

Do **not** change the event registrations yet. `GROUP_ROSTER_UPDATE` and `PLAYER_LOGIN` still point to `SocialQuest:OnGroupRosterUpdate()` and `SocialQuest:OnPlayerLogin()`.

---

- [ ] **Step 4: Verify the addon loads cleanly**

In-game or via the WoW client:
1. `/reload`
2. Check the default chat frame for any Lua errors (shown in red)
3. Enable debug mode: `/sq config` → Debug tab → enable "Enable debug mode"
4. `/reload` again
5. Expected in chat: `[SQ][Group] GroupComposition initialized`
6. No other errors

Note: `GROUP_ROSTER_UPDATE` and `PLAYER_LOGIN` are **still wired to the old handlers** at this point — the new stub methods in `GroupComposition` are not yet called. Group-sync behavior is unchanged until Task 5's cutover.

---

- [ ] **Step 5: Commit**

```
git add Core/GroupComposition.lua SocialQuest.toc SocialQuest.lua
git commit -m "feat(GroupComposition): add module skeleton and TOC registration"
```

---

### Task 2: GroupData — replace `OnGroupChanged` with typed event methods

**What this does:** Adds the three new methods that `GroupComposition` will call — `OnMemberJoined`, `PurgePlayer`, and `OnSelfLeftGroup` — to `GroupData`. The existing `OnGroupChanged` method is **kept in place** for now (still called by `SocialQuest:OnGroupRosterUpdate()` until Task 5's cutover). `OnGroupChanged` is deleted from both `GroupData` and `Communications` in Task 5 alongside the event rewiring. No behavior changes yet.

**Files:**
- Modify: `Core/GroupData.lua` — add `OnMemberJoined`, `PurgePlayer`, `OnSelfLeftGroup`

---

- [ ] **Step 1: Add `OnMemberJoined` to `Core/GroupData.lua`**

Open `Core/GroupData.lua`. After the closing `end` of `OnGroupChanged()` (line ~52), add:

```lua
-- Called by GroupComposition when a new player appears in the group.
-- Creates a hasSocialQuest=false stub so receive handlers can accept their
-- messages before an SQ_INIT arrives.
-- groupType is accepted but unused; passed for signature consistency.
function SocialQuestGroupData:OnMemberJoined(fullName, groupType)
    if not self.PlayerQuests[fullName] then
        self.PlayerQuests[fullName] = { hasSocialQuest = false, completedQuests = {} }
        SocialQuest:Debug("Group", "Stub created for " .. fullName)
    end
end
```

---

- [ ] **Step 2: Add `PurgePlayer` to `Core/GroupData.lua`**

Immediately after `OnMemberJoined`, add:

```lua
-- Called by GroupComposition immediately when a player leaves the group.
-- Removes their entry from PlayerQuests so the GroupFrame stops showing them.
-- If they rejoin, their SQ_INIT broadcast on rejoin replaces this data anyway.
function SocialQuestGroupData:PurgePlayer(fullName)
    if self.PlayerQuests[fullName] then
        self.PlayerQuests[fullName] = nil
        SocialQuest:Debug("Group", "Purged data for " .. fullName)
    end
end
```

---

- [ ] **Step 3: Add `OnSelfLeftGroup` to `Core/GroupData.lua`**

Immediately after `PurgePlayer`, add:

```lua
-- Called by GroupComposition when the local player leaves all groups.
-- Clears the entire PlayerQuests table.
function SocialQuestGroupData:OnSelfLeftGroup()
    self.PlayerQuests = {}
    SocialQuest:Debug("Group", "PlayerQuests cleared (self left group)")
end
```

---

- [ ] **Step 4: Verify the addon loads cleanly**

1. `/reload`
2. Check the default chat frame for Lua errors
3. Existing group-sync behavior should be unchanged (old `OnGroupChanged` still active)

---

- [ ] **Step 5: Commit**

```
git add Core/GroupData.lua
git commit -m "feat(GroupData): add OnMemberJoined, PurgePlayer, OnSelfLeftGroup"
```

---

## Chunk 2: Communications overhaul, diff algorithm, and cutover

### Task 3: Communications — remove SQ_BEACON, add typed event handlers, add jitter to SQ_INIT/SQ_REQUEST responses

**What this does:** The largest single change. Removes the SQ_BEACON machinery entirely (it caused the storm). Adds `pendingResponses` table. Adds `OnSelfJoinedGroup`, `OnMemberJoined`, `OnMemberLeft`, `OnSelfLeftGroup`. Modifies the SQ_INIT receive handler to schedule a jittered whisper response for raid/BG broadcasts. Modifies the SQ_REQUEST receive handler to use a jittered response. Keeps `OnGroupChanged` in place until Task 5.

**Files:**
- Modify: `Core/Communications.lua`

**Background for the implementer:** In the old protocol, joining a raid sent an SQ_BEACON broadcast; every recipient immediately sent back an SQ_REQUEST whisper; the sender responded with up to 39 simultaneous SQ_INIT whispers. This burst pattern triggered Blizzard bot-detection. The new protocol: on join, broadcast your own SQ_INIT directly. Each existing member who receives it schedules a **jittered** (1–8 second random delay) whisper response. At most one response per member, spread across 8 seconds instead of all at once.

---

- [ ] **Step 1: Alias `GroupType` at file scope in `Core/Communications.lua`**

Open `Core/Communications.lua`. Find the `local lastInitSent = {}` line near the top of the file. Add the alias immediately before it:

```lua
-- GroupType enum alias — GroupComposition owns the definition; we reference it here
-- so comparisons read GroupType.Party rather than raw "party" strings.
-- GroupComposition.lua loads before Communications.lua (see TOC), so this is safe.
local GroupType = SocialQuestGroupComposition.GroupType
```

---

- [ ] **Step 2: Remove `"SQ_BEACON"` from the PREFIXES table**

Open `Core/Communications.lua`. Find the `PREFIXES` table near the top:

```lua
local PREFIXES = {
    "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
    "SQ_BEACON", "SQ_REQUEST",
    "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
    "SQ_REQ_COMPLETED", "SQ_RESP_COMPLETE",
}
```

Remove `"SQ_BEACON"`:

```lua
local PREFIXES = {
    "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
    "SQ_REQUEST",
    "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
    "SQ_REQ_COMPLETED", "SQ_RESP_COMPLETE",
}
```

---

- [ ] **Step 3: Add `pendingResponses` table**

After the `local lastInitSent = {}` line, add:

```lua
-- Jitter-delayed SQ_INIT whisper handles, keyed by sender name.
-- Prevents response bursts: when a new raid member broadcasts SQ_INIT, all
-- existing members schedule responses with 1–8 s random delay rather than
-- responding simultaneously. Also used for SQ_REQUEST (Force Resync) responses.
local pendingResponses = {}
```

---

- [ ] **Step 4: Delete `SendBeacon`**

Find and delete the entire `SendBeacon` function:

```lua
function SocialQuestComm:SendBeacon(channel)
    -- Empty beacon — payload is just a single byte so AceComm has something to send.
    LibStub("AceComm-3.0"):SendCommMessage("SQ_BEACON", serialize({}), channel)
    SocialQuest:Debug("Comm", "Sent SQ_BEACON to " .. channel)
end
```

---

- [ ] **Step 5: Add `OnSelfJoinedGroup`**

Add this after the `SendReqCompleted` function (after line ~191 in the current file):

```lua
-- Called by GroupComposition when the local player joins a group or when the
-- group type changes (e.g. party promoted to raid).
-- Broadcasts our full quest snapshot to the new channel and requests completed
-- quest history from all members.
function SocialQuestComm:OnSelfJoinedGroup(groupType)
    -- Cancel any pending jitter responses: they were scheduled for the previous
    -- group context and are no longer valid.
    for _, handle in pairs(pendingResponses) do
        SocialQuest:CancelTimer(handle)
    end
    pendingResponses = {}
    lastInitSent     = {}

    local db = SocialQuest.db.profile
    if groupType == GroupType.Party then
        if db.party.transmit then
            self:SendFullInit("PARTY")
            self:SendReqCompleted()
        end
    elseif groupType == GroupType.Raid then
        if db.raid.transmit then
            self:SendFullInit("RAID")
            self:SendReqCompleted()
        end
    elseif groupType == GroupType.Battleground then
        if db.battleground.transmit then
            self:SendFullInit("INSTANCE_CHAT")
            self:SendReqCompleted()
        end
    end
    SocialQuest:Debug("Comm", "OnSelfJoinedGroup: " .. (groupType or "nil"))
end
```

---

- [ ] **Step 6: Add `OnMemberJoined`**

Immediately after `OnSelfJoinedGroup`:

```lua
-- Called by GroupComposition when a new member appears in the group.
-- Party only: whisper the new member directly because they missed our channel
-- broadcast (they weren't in the group when we sent it).
-- Raid/BG: no-op — the new member broadcasts SQ_INIT to the channel themselves;
-- we respond via the SQ_INIT receive handler with a jittered whisper.
function SocialQuestComm:OnMemberJoined(fullName, groupType)
    if groupType == GroupType.Party then
        local db = SocialQuest.db.profile
        if db.party.transmit then
            self:SendFullInit("WHISPER", fullName)
            SocialQuest:Debug("Comm", "OnMemberJoined (party): sent SQ_INIT whisper to " .. fullName)
        end
    end
    -- raid/battleground: receive handler schedules jittered response to their SQ_INIT broadcast
end
```

---

- [ ] **Step 7: Add `OnMemberLeft`**

Immediately after `OnMemberJoined`:

```lua
-- Called by GroupComposition immediately after PurgePlayer when a member leaves.
-- Clears the 15-second cooldown for that sender so that if they rejoin quickly
-- (within 15 s), their SQ_INIT broadcast on rejoin is not silently dropped.
function SocialQuestComm:OnMemberLeft(fullName)
    lastInitSent[fullName] = nil
    if pendingResponses[fullName] then
        SocialQuest:CancelTimer(pendingResponses[fullName])
        pendingResponses[fullName] = nil
    end
    SocialQuest:Debug("Comm", "OnMemberLeft: cleared cooldowns for " .. fullName)
end
```

---

- [ ] **Step 8: Add `OnSelfLeftGroup`**

Immediately after `OnMemberLeft`:

```lua
-- Called by GroupComposition when the local player leaves all groups.
-- Cancels all pending jitter timers and clears cooldown state.
function SocialQuestComm:OnSelfLeftGroup()
    for _, handle in pairs(pendingResponses) do
        SocialQuest:CancelTimer(handle)
    end
    pendingResponses = {}
    lastInitSent     = {}
    SocialQuest:Debug("Comm", "OnSelfLeftGroup: cleared all pending responses and cooldowns")
end
```

---

- [ ] **Step 9: Modify the SQ_INIT receive handler to add jitter for raid/BG**

Find the `elseif prefix == "SQ_INIT" then` block inside `OnCommReceived`:

```lua
    if prefix == "SQ_INIT" then
        local _sqN = 0
        for _ in pairs(payload.quests or payload) do _sqN = _sqN + 1 end
        SocialQuest:Debug("Comm", "Received SQ_INIT from " .. sender .. " (" .. _sqN .. " quests)")
        SocialQuestGroupData:OnInitReceived(sender, payload)
```

Replace it with:

```lua
    if prefix == "SQ_INIT" then
        local _sqN = 0
        for _ in pairs(payload.quests or {}) do _sqN = _sqN + 1 end
        SocialQuest:Debug("Comm", "Received SQ_INIT from " .. sender .. " (" .. _sqN .. " quests, dist=" .. distribution .. ")")
        SocialQuestGroupData:OnInitReceived(sender, payload)

        -- Raid/BG broadcasts: schedule a jittered whisper response so that up to
        -- 39 existing members don't all respond simultaneously (storm prevention).
        -- Party and whisper distributions need no response here:
        --   Party:   OnMemberJoined already sent a direct whisper to new members.
        --   Whisper: This is their response to us; no further response needed.
        if distribution == "RAID" or distribution == "INSTANCE_CHAT" then
            if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
                SocialQuest:Debug("Comm", "SQ_INIT from " .. sender .. " — response suppressed (cooldown)")
            else
                lastInitSent[sender] = GetTime()
                if pendingResponses[sender] then
                    SocialQuest:CancelTimer(pendingResponses[sender])
                end
                pendingResponses[sender] = SocialQuest:ScheduleTimer(function()
                    pendingResponses[sender] = nil
                    self:SendFullInit("WHISPER", sender)
                    SocialQuest:Debug("Comm", "Sent jittered SQ_INIT whisper to " .. sender)
                end, math.random(1, 8))
            end
        end
```

---

- [ ] **Step 10: Modify the SQ_BEACON receive handler — delete it entirely**

Find and delete the entire `elseif prefix == "SQ_BEACON" then` block:

```lua
    elseif prefix == "SQ_BEACON" then
        -- Someone announced their presence. Per the beacon+pull protocol, the
        -- correct response is to send SQ_REQUEST (a whisper asking for their
        -- full snapshot). They will reply with SQ_INIT. Do NOT send our own
        -- SQ_INIT unsolicited — that defeats the storm-prevention purpose of
        -- the beacon pattern. They will send us an SQ_REQUEST in return when
        -- they receive our beacon (or request directly if they already heard ours).
        SocialQuest:Debug("Comm", "Received SQ_BEACON from " .. sender)
        LibStub("AceComm-3.0"):SendCommMessage("SQ_REQUEST", serialize({}), "WHISPER", sender)
```

---

- [ ] **Step 11: Modify the SQ_REQUEST receive handler to use a jittered response**

Find the `elseif prefix == "SQ_REQUEST" then` block:

```lua
    elseif prefix == "SQ_REQUEST" then
        if not SocialQuestGroupData.PlayerQuests[sender] then
            SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — dropped (not in group)")
            return
        end
        if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
            SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — dropped (cooldown)")
            return
        end
        SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — responding")
        lastInitSent[sender] = GetTime()
        self:SendFullInit("WHISPER", sender)
```

Replace with:

```lua
    elseif prefix == "SQ_REQUEST" then
        if not SocialQuestGroupData.PlayerQuests[sender] then
            SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — dropped (not in group)")
            return
        end
        if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
            SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — dropped (cooldown)")
            return
        end
        -- Stamp at schedule time (not fire time) so a second SQ_REQUEST arriving
        -- during the jitter window doesn't schedule a duplicate response.
        lastInitSent[sender] = GetTime()
        if pendingResponses[sender] then
            SocialQuest:CancelTimer(pendingResponses[sender])
        end
        SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — scheduling jittered response (1-4 s)")
        pendingResponses[sender] = SocialQuest:ScheduleTimer(function()
            pendingResponses[sender] = nil
            self:SendFullInit("WHISPER", sender)
            SocialQuest:Debug("Comm", "Sent jittered SQ_INIT to " .. sender .. " (SQ_REQUEST response)")
        end, math.random(1, 4))
    end  -- elseif prefix == "SQ_REQUEST"
```

---

- [ ] **Step 12: Verify the addon loads cleanly**

1. `/reload`
2. Check for Lua errors in the default chat frame
3. Old `OnGroupChanged` behavior still active — joining a party should still send SQ_INIT to PARTY channel (via the old path in `SocialQuest:OnGroupRosterUpdate`)
4. Confirm no SQ_BEACON messages appear in debug output when joining a raid (beacon was sending `{rt1} SocialQuest...` type messages — actually no, beacon was a comm message not a chat message; just confirm no Lua errors)

---

- [ ] **Step 13: Commit**

```
git add Core/Communications.lua
git commit -m "feat(Communications): remove SQ_BEACON, add typed group event handlers, jitter SQ_INIT/SQ_REQUEST responses"
```

---

### Task 4: GroupComposition — implement the full diff algorithm

**What this does:** Fills in the stub `OnGroupRosterUpdate()` with the complete diff algorithm from the spec. After this task, `GroupComposition` correctly classifies joins, leaves, and subgroup moves, and calls the right methods on `Communications` and `GroupData`. The old `SocialQuest:OnGroupRosterUpdate()` still delegates to `SocialQuestComm:OnGroupChanged()` and `SocialQuestGroupData:OnGroupChanged()` (cutover happens in Task 5), so there will be **double processing** of GROUP_ROSTER_UPDATE in intermediate state. This is acceptable for the Improvements branch — both paths are harmless when running in parallel, and Task 5 removes the old path.

**Note on `OnPlayerLogin`:** The skeleton written in Task 1 (`self:OnGroupRosterUpdate()`) is the **complete and final implementation** of `OnPlayerLogin` — it is not a stub that needs to be filled in here. Only `OnGroupRosterUpdate` receives a body in this task.

**Files:**
- Modify: `Core/GroupComposition.lua` — replace stub `OnGroupRosterUpdate` body

**Key WoW API notes for the implementer:**
- `UnitName("player")` returns `name, realm` where `realm` is `nil` for same-realm players. Use `normalize(UnitName("player"))` (two-return, but normalize handles nil realm).
- `GetRaidRosterInfo(i)` returns `name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML` — the first return is `name`, which may already contain `-Realm` suffix for cross-realm players. Use `normalize(name)` (one-arg form only).
- `GetNumGroupMembers()` includes self in the count for parties (e.g. returns 5 for a full party). For party iteration, loop `UnitName("party1")` through `UnitName("party"..N-1)` (N-1 party units since self is not a "partyX" unit).
- `GetNumGroupMembers()` for raids returns the full raid count including self.

---

- [ ] **Step 1: Replace the stub `OnGroupRosterUpdate` body**

Open `Core/GroupComposition.lua`. Replace the entire stub body of `OnGroupRosterUpdate`:

```lua
function SocialQuestGroupComposition:OnGroupRosterUpdate()
    local groupType = currentGroupType()
    -- UnitName("player") returns name, realm where realm is nil for same-realm.
    -- normalize() handles nil realm correctly.
    local selfName  = normalize(UnitName("player"))

    -- ── Self left all groups ──────────────────────────────────────────────────
    if groupType == nil then
        if next(self.memberSet) then
            self.memberSet       = {}
            self.memberSubgroups = {}
            self.lastGroupType   = nil
            SocialQuestComm:OnSelfLeftGroup()
            SocialQuestGroupData:OnSelfLeftGroup()
            SocialQuest:Debug("Group", "Self left all groups")
        end
        return
    end

    -- ── Build new membership snapshot ─────────────────────────────────────────
    local newMembers   = {}   -- [fullName] = true
    local newSubgroups = {}   -- [fullName] = subgroupNumber (raid/BG only)

    if IsInRaid() or groupType == GroupType.Battleground then
        local count = GetNumGroupMembers()
        for i = 1, count do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name then
                local fullName = normalize(name)  -- one-arg: name may already have "-Realm"
                newMembers[fullName]   = true
                newSubgroups[fullName] = subgroup
            end
        end
    else
        -- Party: self is not a "partyX" unit; add explicitly.
        newMembers[selfName] = true
        local count = GetNumGroupMembers()
        for i = 1, count - 1 do  -- count includes self; partyX units are non-self members
            local name, realm = UnitName("party" .. i)
            if name then
                local fullName = normalize(name, realm)
                newMembers[fullName] = true
            end
        end
    end

    -- ── Self joined or group type changed — handle FIRST ─────────────────────
    -- Must fire before member loops so OnSelfJoinedGroup (which broadcasts SQ_INIT)
    -- runs before OnMemberJoined (which whispers individual party members).
    if not self.memberSet[selfName] then
        SocialQuest:Debug("Group", "Self joined group: " .. groupType)
        SocialQuestComm:OnSelfJoinedGroup(groupType)
    elseif groupType ~= self.lastGroupType then
        SocialQuest:Debug("Group", "Group type changed: " .. (self.lastGroupType or "nil") .. " → " .. groupType)
        SocialQuestComm:OnSelfJoinedGroup(groupType)
    end

    -- ── Detect member joins ───────────────────────────────────────────────────
    for fullName in pairs(newMembers) do
        if fullName ~= selfName and not self.memberSet[fullName] then
            SocialQuest:Debug("Group", fullName .. " joined the group")
            SocialQuestGroupData:OnMemberJoined(fullName, groupType)
            SocialQuestComm:OnMemberJoined(fullName, groupType)
        end
    end

    -- ── Detect member leaves ──────────────────────────────────────────────────
    -- Self-leave is handled by the nil-groupType path at the top; selfName being
    -- in memberSet but absent from newMembers while groupType != nil is unreachable.
    for fullName in pairs(self.memberSet) do
        if fullName ~= selfName and not newMembers[fullName] then
            SocialQuest:Debug("Group", fullName .. " left the group — purging data")
            SocialQuestGroupData:PurgePlayer(fullName)
            SocialQuestComm:OnMemberLeft(fullName)
        end
    end

    -- ── Detect subgroup moves (raid/BG only) ──────────────────────────────────
    -- Only compare players who had a prior subgroup entry (guard against false
    -- positives for new joiners whose memberSubgroups entry is nil).
    local subgroupsChanged = false
    for fullName, sg in pairs(newSubgroups) do
        if self.memberSubgroups[fullName] ~= nil and self.memberSubgroups[fullName] ~= sg then
            subgroupsChanged = true
            break
        end
    end
    if subgroupsChanged then
        SocialQuest:Debug("Group", "Subgroup reorganization detected (no sync needed)")
        -- OnSubgroupsChanged() has no current subscribers; defined as a future extension point.
    end

    -- ── Commit snapshot ───────────────────────────────────────────────────────
    self.memberSet       = newMembers
    self.memberSubgroups = newSubgroups
    self.lastGroupType   = groupType
end
```

---

- [ ] **Step 2: Verify in debug mode — party join**

1. `/reload` — check for Lua errors
2. Enable debug: `/sq config` → Debug → enable
3. While **not** in a group: `/reload`
4. Expected: no group-related debug messages (not in a group)
5. Have a friend invite you to a party
6. Expected debug messages (in order — self-joined fires before member loop):
   - `[SQ][Group] Self joined group: party`
   - `[SQ][Comm] OnSelfJoinedGroup: party`
   - `[SQ][Comm] Sent SQ_INIT to PARTY (N quests)`
   - `[SQ][Group] <FriendName> joined the group`
7. Also verify from the **other side**: when you join, your party member's debug should show:
   - `[SQ][Group] Self joined group: party` (if they weren't already in a group)
   - `[SQ][Group] <YourName> joined the group`
   - `[SQ][Comm] OnMemberJoined (party): sent SQ_INIT whisper to <YourName>`

Note: During this task, the old `SocialQuest:OnGroupRosterUpdate` is ALSO still firing `SocialQuestComm:OnGroupChanged()` and `SocialQuestGroupData:OnGroupChanged()`. This produces some redundant messages but no errors.

---

- [ ] **Step 3: Verify in debug mode — member leaves party**

1. Have friend leave the party
2. Expected debug messages:
   - `[SQ][Group] <FriendName> left the group — purging data`
   - `[SQ][Comm] OnMemberLeft: cleared cooldowns for <FriendName>`
3. The GroupFrame (`/sq`) should immediately stop showing the departed player's quests

---

- [ ] **Step 4: Verify in debug mode — subgroup move (raid only)**

1. Join a raid
2. Have the raid leader move someone to a different subgroup
3. Expected: `[SQ][Group] Subgroup reorganization detected (no sync needed)` appears exactly once per move
4. Expected: no SQ_INIT is sent (check that `Sent SQ_INIT` does NOT appear in debug output)

---

- [ ] **Step 5: Commit**

```
git add Core/GroupComposition.lua
git commit -m "feat(GroupComposition): implement full diff algorithm (join/leave/subgroup)"
```

---

### Task 5: SocialQuest.lua cutover — rewire events, remove dead code

**What this does:** Performs the final atomic cutover. Rewires `GROUP_ROSTER_UPDATE` and `PLAYER_LOGIN` handlers in `SocialQuest.lua` to delegate to `GroupComposition` instead of the old `Comm:OnGroupChanged()` / `GroupData:OnGroupChanged()` pair. Then removes the now-dead `OnGroupChanged()` methods from both `GroupData` and `Communications`. After this task the old beacon/roster code is gone entirely.

**Files:**
- Modify: `SocialQuest.lua` — update `OnGroupRosterUpdate` and `OnPlayerLogin` handlers
- Modify: `Core/GroupData.lua` — delete `OnGroupChanged`
- Modify: `Core/Communications.lua` — delete `OnGroupChanged`

---

- [ ] **Step 1: Update `SocialQuest:OnGroupRosterUpdate` in `SocialQuest.lua`**

Find:
```lua
function SocialQuest:OnGroupRosterUpdate()
    SocialQuestComm:OnGroupChanged()
    SocialQuestGroupData:OnGroupChanged()
end
```

Replace with:
```lua
function SocialQuest:OnGroupRosterUpdate()
    SocialQuestGroupComposition:OnGroupRosterUpdate()
end
```

---

- [ ] **Step 2: Update `SocialQuest:OnPlayerLogin` in `SocialQuest.lua`**

Find:
```lua
-- Re-sync quest data with group after a UI reload (PLAYER_LOGIN fires on /reload).
function SocialQuest:OnPlayerLogin()
    SocialQuestGroupData:OnGroupChanged()
    SocialQuestComm:OnGroupChanged()
end
```

Replace with:
```lua
-- Re-sync quest data with group after a UI reload (PLAYER_LOGIN fires on /reload).
function SocialQuest:OnPlayerLogin()
    SocialQuestGroupComposition:OnPlayerLogin()
end
```

---

- [ ] **Step 3: Delete `OnGroupChanged` from `Core/GroupData.lua`**

Find and delete the entire `OnGroupChanged` function (lines ~22–52):

```lua
-- Called when GROUP_ROSTER_UPDATE fires. Removes stale entries and adds stubs
-- for newly visible members who haven't sent data yet.
function SocialQuestGroupData:OnGroupChanged()
    -- Build a set of current group member names.
    local current = {}
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid"..i) or ("party"..i)
        local name, realm = UnitName(unit)
        if name then
            local fullName = realm and realm ~= "" and (name.."-"..realm) or name
            current[fullName] = true
        end
    end

    -- Remove entries for players no longer in group.
    for fullName in pairs(self.PlayerQuests) do
        if not current[fullName] then
            SocialQuest:Debug("Group", "Removed " .. fullName .. " from tracked roster")
            self.PlayerQuests[fullName] = nil
        end
    end

    -- Add stub entries for new members we haven't heard from yet.
    for fullName in pairs(current) do
        if not self.PlayerQuests[fullName] then
            self.PlayerQuests[fullName] = { hasSocialQuest = false, completedQuests = {} }
            SocialQuest:Debug("Group", "Added " .. fullName .. " to tracked roster")
        end
    end
end
```

Also update the file header comment at lines 22–23 to remove the reference to `GROUP_ROSTER_UPDATE`:

```lua
-- Called when GROUP_ROSTER_UPDATE fires. Removes stale entries and adds stubs
-- for newly visible members who haven't sent data yet.
```

Delete those two comment lines (they refer to the removed function).

---

- [ ] **Step 4: Delete `OnGroupChanged` from `Core/Communications.lua`**

Find and delete the entire `OnGroupChanged` function (~lines 40–71):

```lua
-- Called when GROUP_ROSTER_UPDATE fires.
function SocialQuestComm:OnGroupChanged()
    lastInitSent = {}
    local db = SocialQuest.db.profile

    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        -- Party (≤5): send full init immediately to PARTY channel.
        if db.party.transmit then
            self:SendFullInit("PARTY")
        end

    elseif IsInRaid() then
        -- Raid (6–40): send SQ_BEACON with 0–8s jitter, then respond to requests.
        if db.raid.transmit then
            local jitter = math.random(0, 8)
            SocialQuest:ScheduleTimer(function()
                self:SendBeacon("RAID")
            end, jitter)
        end

    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        -- Battleground: same beacon+pull as raid.
        if db.battleground.transmit then
            local jitter = math.random(0, 8)
            SocialQuest:ScheduleTimer(function()
                self:SendBeacon("INSTANCE_CHAT")
            end, jitter)
        end
    end
    -- Guild: no AceComm sync.

    self:SendReqCompleted()
end
```

---

- [ ] **Step 5: Full in-game verification — solo**

1. `/reload`
2. Check for Lua errors — expect none
3. Not in a group: no group-related debug output

---

- [ ] **Step 6: Full in-game verification — party join/leave cycle**

Enable debug mode. Run through the following sequence and verify each expected output:

**You join a party** (self-joined fires before member loop):
- `[SQ][Group] Self joined group: party`
- `[SQ][Comm] OnSelfJoinedGroup: party`
- `[SQ][Comm] Sent SQ_INIT to PARTY (N quests)`
- `[SQ][Group] <TheirName> joined the group` (for each existing member)
- (from their side) `[SQ][Comm] OnMemberJoined (party): sent SQ_INIT whisper to <YourName>`

**A new player joins your party:**
- `[SQ][Group] <NewName> joined the group`
- `[SQ][Comm] OnMemberJoined (party): sent SQ_INIT whisper to <NewName>`

**A party member leaves:**
- `[SQ][Group] <TheirName> left the group — purging data`
- `[SQ][Comm] OnMemberLeft: cleared cooldowns for <TheirName>`
- GroupFrame no longer shows their quests (immediately, no 30-second delay)

**You leave the party:**
- `[SQ][Comm] OnSelfLeftGroup: cleared all pending responses and cooldowns`
- `[SQ][Group] PlayerQuests cleared (self left group)`
- GroupFrame shows no party members

---

- [ ] **Step 7: Full in-game verification — raid subgroup reorganization**

1. Join a raid (or have a friend set up a 2-person raid)
2. Have the raid leader move players between subgroups
3. Expected: `[SQ][Group] Subgroup reorganization detected (no sync needed)` for each move
4. Expected: **no** `Sent SQ_INIT` messages (sync is suppressed for subgroup moves)
5. Open GroupFrame (`/sq`) — it should continue showing members' quest data unchanged

---

- [ ] **Step 8: Full in-game verification — Force Resync**

1. In a party with debug enabled
2. `/sq config` → Debug → Force Resync button
3. Expected on your side: `[SQ][Comm] Sent SQ_REQUEST to PARTY` (or RAID)
4. Expected on their side (within 1–4 seconds): `[SQ][Comm] Sent jittered SQ_INIT to <YourName> (SQ_REQUEST response)`
5. Expected on your side (shortly after): `[SQ][Comm] Received SQ_INIT from <TheirName> (N quests, dist=WHISPER)`

---

- [ ] **Step 9: Commit**

```
git add SocialQuest.lua Core/GroupData.lua Core/Communications.lua
git commit -m "feat(GroupComposition): cut over event handlers, remove dead OnGroupChanged and SQ_BEACON"
```

---
