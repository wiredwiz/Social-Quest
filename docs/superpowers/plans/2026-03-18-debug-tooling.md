# Debug Tooling Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Force Resync button (with security guards) to the debug options page, a `SocialQuest:Debug()` helper, and comprehensive debug logging across all SocialQuest subsystems.

**Architecture:** Debug helper added to `SocialQuest.lua`; security mitigations + resync function + comm logging added to `Core/Communications.lua`; logging added to `Core/GroupData.lua` and `Core/Announcements.lua`; resync button with 30-second cooldown added to `UI/Options.lua`; two locale strings added to `Locales/enUS.lua`.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), Ace3 (AceComm-3.0, AceSerializer-3.0). No automated test framework — verification is done in-game via the options panel (`/sq config`) or `/sq` toggle.

**Spec:** `docs/superpowers/specs/2026-03-18-debug-tooling-design.md`

**Task order:** Task 1 must come first (all other tasks call `SocialQuest:Debug`). Task 5 must come after Task 2 (it calls `SendResyncRequest`). Tasks 2, 3, and 4 can be done in any order after Task 1.

---

## Chunk 1: Debug helper + [SQ][Quest] logging

### Task 1: Add Debug helper and quest event logging to `SocialQuest.lua`

**Files:**
- Modify: `SocialQuest.lua`

- [ ] **Step 1: Read `SocialQuest.lua`**

  Confirm the current structure before editing.

- [ ] **Step 2: Add the `Debug` helper method**

  Insert a new section after the closing `end` of `SocialQuest:OnDisable()` and before the `-- Default settings` heading comment:

  ```lua
  ------------------------------------------------------------------------
  -- Debug helper
  ------------------------------------------------------------------------

  function SocialQuest:Debug(tag, msg)
      if not self.db.profile.debug.enabled then return end
      DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD200[SQ][" .. tag .. "]|r " .. tostring(msg))
  end
  ```

  `DEFAULT_CHAT_FRAME:AddMessage` bypasses addon chat hooks (including Questie's `{rt1}` substitution), which is intentional for debug output.

- [ ] **Step 3: Add [SQ][Quest] debug call to each quest event handler**

  For every handler below, add `self:Debug(...)` as the **first line** of the function body. Use the variable names already present in each handler's parameter list.

  `OnQuestAccepted(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest accepted: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
  ```

  `OnQuestAbandoned(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest abandoned: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
  ```

  `OnQuestFinished(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest finished: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
  ```

  `OnQuestCompleted(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest completed: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
  ```

  `OnQuestFailed(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest failed: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
  ```

  `OnQuestTracked(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest tracked: (id=" .. questInfo.questID .. ")")
  ```

  `OnQuestUntracked(event, questInfo)`:
  ```lua
  self:Debug("Quest", "Quest untracked: (id=" .. questInfo.questID .. ")")
  ```

  `OnObjectiveProgressed(event, questInfo, objective, delta)` — add **after** the early-return guard so this fires only for partial progress (not when the threshold is crossed, which is handled by `OnObjectiveCompleted`):
  ```lua
  -- add after: if objective.numFulfilled >= objective.numRequired then return end
  self:Debug("Quest", "Objective " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
  ```

  `OnObjectiveCompleted(event, questInfo, objective)`:
  ```lua
  self:Debug("Quest", "Objective complete " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
  ```

  `OnObjectiveRegressed(event, questInfo, objective, delta)` — add after `BroadcastObjectiveUpdate`:
  ```lua
  self:Debug("Quest", "Objective regression " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
  ```

- [ ] **Step 4: Verify**

  Confirm:
  - `SocialQuest:Debug` helper is defined with the gold prefix format
  - All 10 handler call sites are present
  - `OnObjectiveProgressed` debug call is placed **after** the early-return, not before it
  - No unbalanced `function`/`end` blocks

- [ ] **Step 5: Commit**

  ```bash
  git add SocialQuest.lua
  git commit -m "feat: add Debug helper and [SQ][Quest] logging"
  ```

---

## Chunk 2: Security guards + SendResyncRequest + Comm logging

### Task 2: Security mitigations, `SendResyncRequest`, and `[SQ][Comm]`/`[SQ][Resync]` logging in `Core/Communications.lua`

**Files:**
- Modify: `Core/Communications.lua`

This task has five sub-goals that are implemented together since they all touch this one file.

- [ ] **Step 1: Read `Core/Communications.lua`**

  Read the full file. Identify:
  - The module-level `local` declarations at the top
  - `SocialQuestComm:OnGroupChanged()` body
  - All send functions: `SendFullInit`, `BroadcastQuestUpdate`, `BroadcastObjectiveUpdate`, any beacon/request/completed send functions — note the variable names used for quest count, event type, quest ID, objective index, channel, sender, etc.
  - `GetActiveChannel()` — note its position; `SendResyncRequest` goes after it
  - `OnCommReceived` — note the `elseif` chain and the existing inline debug block near the `pcall` error path
  - The `SQ_REQUEST` handler block (currently 2 lines)

- [ ] **Step 2: Add `local lastInitSent = {}` at the module level**

  Add this with the other module-level `local` declarations at the top of the file:
  ```lua
  local lastInitSent = {}   -- keyed by sender name; tracks when SQ_INIT was last sent per player
  ```

- [ ] **Step 3: Clear `lastInitSent` in `OnGroupChanged`**

  At the very start of `SocialQuestComm:OnGroupChanged()` body (before any other logic), add:
  ```lua
  lastInitSent = {}
  ```

  **Why:** `OnGroupChanged` fires on both `GROUP_ROSTER_UPDATE` and `PLAYER_LOGIN`. Both represent a fresh comm session where stale cooldowns would block legitimate init exchanges — for example, a player who leaves and rejoins within 15 seconds.

- [ ] **Step 4: Replace the `SQ_REQUEST` handler in `OnCommReceived`**

  The current handler is two lines:
  ```lua
  elseif prefix == "SQ_REQUEST" then
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
      SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — responding")
      lastInitSent[sender] = GetTime()
      self:SendFullInit("WHISPER", sender)
  ```

  **Guard 1 rationale:** `SocialQuestGroupData.PlayerQuests` is keyed by the exact name format that AceComm delivers (handles cross-realm `"Name-Realm"` strings correctly; `UnitInParty`/`UnitInRaid` do not).

  **Guard 2 rationale:** caps damage from rapid repeated requests from any single sender. The 15-second cooldown applies ONLY to SQ_INIT responses triggered by SQ_REQUEST — it does not affect SQ_UPDATE or SQ_OBJECTIVE paths.

- [ ] **Step 5: Convert the existing inline debug block**

  Find the existing inline debug block near the `pcall` error path in `OnCommReceived`. It currently looks like:
  ```lua
  if SocialQuest.db.profile.debug.enabled then
      SocialQuest:Print("[Comm] Failed to deserialize "..prefix.." from "..sender)
  end
  ```

  Replace it with:
  ```lua
  SocialQuest:Debug("Comm", "Failed to deserialize " .. prefix .. " from " .. sender)
  ```

- [ ] **Step 6: Add `SendResyncRequest()` after `GetActiveChannel()`**

  Insert the following new function immediately after `GetActiveChannel()`:

  ```lua
  function SocialQuestComm:SendResyncRequest()
      local channel = self:GetActiveChannel()
      if not channel then
          SocialQuest:Debug("Resync", "Resync: not in group, no-op")
          return
      end
      -- Transmit guard: use GetActiveChannel priority (raid > battleground > party).
      local sectionMap = { RAID = "raid", INSTANCE_CHAT = "battleground", PARTY = "party" }
      local section = sectionMap[channel]
      local db = SocialQuest.db.profile
      if section and db[section] and not db[section].transmit then
          SocialQuest:Debug("Resync", "Resync: transmit disabled for " .. section .. ", no-op")
          return
      end
      SocialQuest:Debug("Resync", "Resync: broadcasting SQ_REQUEST to " .. channel)
      self:SendCommMessage("SQ_REQUEST", "", channel)
      SocialQuest:Debug("Comm", "Sent SQ_REQUEST to " .. channel)
  end
  ```

- [ ] **Step 7: Add `[SQ][Comm]` debug calls to send functions**

  For each send function, add a `SocialQuest:Debug("Comm", ...)` call **after** the `SendCommMessage` (or `SendCommMessage`-equivalent) call. Use the variable names already in scope in each function.

  The exact debug string format for each (read the function body to find the right variable names):

  **`SendFullInit`** (sends `SQ_INIT`):
  The function serializes a table of active quests (keyed by questID — a hash table, not an array). Add a count computation **before** the `SendCommMessage("SQ_INIT", ...)` call, using whatever variable holds the quest table (call it `questsVar` here; substitute the actual name after reading the function):
  ```lua
  local _sqN = 0
  for _ in pairs(questsVar) do _sqN = _sqN + 1 end
  ```
  Then after `SendCommMessage("SQ_INIT", ...)`:
  ```lua
  SocialQuest:Debug("Comm", "Sent SQ_INIT to " .. channel .. " (" .. _sqN .. " quests)")
  ```

  **`BroadcastQuestUpdate`** (sends `SQ_UPDATE`):
  After `SendCommMessage("SQ_UPDATE", ...)`:
  ```lua
  SocialQuest:Debug("Comm", "Sent SQ_UPDATE: " .. eventType .. " questID=" .. questID)
  ```

  **`BroadcastObjectiveUpdate`** (sends `SQ_OBJECTIVE`):
  After `SendCommMessage("SQ_OBJECTIVE", ...)`:
  ```lua
  SocialQuest:Debug("Comm", "Sent SQ_OBJECTIVE: questID=" .. questID .. " obj=" .. objIndex .. " " .. numFulfilled .. "/" .. numRequired)
  ```

  **Beacon send function** (sends `SQ_BEACON`):
  After `SendCommMessage("SQ_BEACON", ...)`:
  ```lua
  SocialQuest:Debug("Comm", "Sent SQ_BEACON to " .. channel)
  ```

  **`SQ_REQ_COMPLETED` send** (requests completed quest list):
  After `SendCommMessage("SQ_REQ_COMPLETED", ...)`:
  ```lua
  SocialQuest:Debug("Comm", "Sent SQ_REQ_COMPLETED to " .. channel)
  ```

  **`SQ_RESP_COMPLETE` send** (response with completed quest list):
  Add a count computation **before** the `SendCommMessage("SQ_RESP_COMPLETE", ...)` call, using whatever variable holds the completed quest table (call it `completedVar`; substitute the actual name after reading the function):
  ```lua
  local _sqN = 0
  for _ in pairs(completedVar) do _sqN = _sqN + 1 end
  ```
  Then after `SendCommMessage("SQ_RESP_COMPLETE", ...)`:
  ```lua
  SocialQuest:Debug("Comm", "Sent SQ_RESP_COMPLETE to " .. sender .. " (" .. _sqN .. " completed quests)")
  ```

  **`SendResyncRequest`** already has its `[SQ][Comm]` and `[SQ][Resync]` debug calls from Step 6. No additional call needed here.

- [ ] **Step 8: Add `[SQ][Comm]` debug calls to receive handlers in `OnCommReceived`**

  For each `elseif prefix == ...` block in `OnCommReceived`, add the corresponding received debug call **after** the deserialization succeeds (i.e., inside the successful pcall branch, before dispatching to the handler). Use the variables already in scope.

  For `SQ_UPDATE`, `SQ_OBJECTIVE`, `SQ_BEACON`, `SQ_REQ_COMPLETED` — the deserialized fields are directly available; add these after deserialization succeeds:

  | Prefix | Debug string to add |
  |---|---|
  | `SQ_UPDATE` | `SocialQuest:Debug("Comm", "Received SQ_UPDATE from " .. sender .. ": " .. eventType .. " questID=" .. questID)` |
  | `SQ_OBJECTIVE` | `SocialQuest:Debug("Comm", "Received SQ_OBJECTIVE from " .. sender .. ": questID=" .. questID .. " obj=" .. objIndex)` |
  | `SQ_BEACON` | `SocialQuest:Debug("Comm", "Received SQ_BEACON from " .. sender)` |
  | `SQ_REQ_COMPLETED` | `SocialQuest:Debug("Comm", "Received SQ_REQ_COMPLETED from " .. sender)` |

  Substitute actual variable names from the deserialized payload as needed (e.g., `eventType`, `questID`, `objIndex` may be named differently).

  For `SQ_INIT` (deserialized quest table is a hash keyed by questID): add a count before the debug call:
  ```lua
  local _sqN = 0
  for _ in pairs(deserializedData.quests or deserializedData) do _sqN = _sqN + 1 end
  SocialQuest:Debug("Comm", "Received SQ_INIT from " .. sender .. " (" .. _sqN .. " quests)")
  ```
  Adjust `deserializedData` to the actual variable name; the quest count comes from the quests sub-table (or the top-level table if quests are stored at the root level — inspect the function to confirm).

  For `SQ_RESP_COMPLETE` (deserialized completed quest table): same counting pattern:
  ```lua
  local _sqN = 0
  for _ in pairs(deserializedData) do _sqN = _sqN + 1 end
  SocialQuest:Debug("Comm", "Received SQ_RESP_COMPLETE from " .. sender .. " (" .. _sqN .. " completed quests)")
  ```

  The `SQ_REQUEST` handler already has its three debug calls from Step 4.

- [ ] **Step 9: Verify**

  Confirm:
  - `lastInitSent = {}` is declared at module level
  - `lastInitSent = {}` is called at the start of `OnGroupChanged`
  - `SQ_REQUEST` handler has Guard 1, Guard 2, debug calls, and `lastInitSent[sender] = GetTime()` before responding
  - Existing inline debug block is converted (no more `SocialQuest:Print` for comm deserialize errors)
  - `SendResyncRequest` is defined
  - Every send function has a post-send debug call
  - Every receive handler has a post-deserialize debug call
  - No unbalanced `function`/`end` blocks

- [ ] **Step 10: Commit**

  ```bash
  git add Core/Communications.lua
  git commit -m "feat: security guards, SendResyncRequest, and [SQ][Comm] logging"
  ```

---

## Chunk 3: GroupData logging

### Task 3: Add `[SQ][Group]` debug calls to `Core/GroupData.lua`

**Files:**
- Modify: `Core/GroupData.lua`

- [ ] **Step 1: Read `Core/GroupData.lua`**

  Identify:
  - `OnGroupChanged()` — the loop where stale entries are removed and new stubs are added
  - `OnInitReceived(sender, data)` — where init data is stored into `PlayerQuests`

- [ ] **Step 2: Add debug calls**

  **In `OnGroupChanged`** — when a player is removed from the tracked roster:
  ```lua
  SocialQuest:Debug("Group", "Removed " .. name .. " from tracked roster")
  ```
  Add this just before or just after the removal of the entry. The variable holding the player name will be whatever the loop variable is (likely `name` or `playerName`).

  **In `OnGroupChanged`** — when a new player stub is added:
  ```lua
  SocialQuest:Debug("Group", "Added " .. name .. " to tracked roster")
  ```
  Add this after the stub is inserted into `PlayerQuests`.

  **In `OnInitReceived`** — after the full snapshot is stored into `PlayerQuests`, add a count and debug call:
  ```lua
  local _sqN = 0
  for _ in pairs(data.quests or {}) do _sqN = _sqN + 1 end
  SocialQuest:Debug("Group", "Stored init data for " .. sender .. " (" .. _sqN .. " quests)")
  ```
  `data.quests` is the quest sub-table from the received init snapshot. Adjust if the field has a different name (read `OnInitReceived` to confirm).

- [ ] **Step 3: Verify**

  Confirm three call sites: remove, add, init-stored.

- [ ] **Step 4: Commit**

  ```bash
  git add Core/GroupData.lua
  git commit -m "feat: add [SQ][Group] debug logging"
  ```

---

## Chunk 4: Announcements logging

### Task 4: Add `[SQ][Banner]` debug calls to `Core/Announcements.lua`

**Files:**
- Modify: `Core/Announcements.lua`

- [ ] **Step 1: Read `Core/Announcements.lua`**

  Identify:
  - `OnQuestEvent` — the outbound chat path; the `questieWouldAnnounce` suppression check; the `enqueueChat` calls
  - `OnObjectiveEvent` — same structure
  - `OnRemoteQuestEvent` — the inbound banner display path; all the guard conditions before `displayBanner`
  - `OnRemoteObjectiveEvent` — same
  - `checkAllCompleted` — all early-return points; the `displayBanner` call at the end

- [ ] **Step 2: Add [SQ][Banner] debug calls — outbound chat path**

  Both `OnQuestEvent` and `OnObjectiveEvent` share the same structure: outbound chat is gated behind `if not questieWouldAnnounce(eventType) then ... end`.

  **Questie suppression log:** In both functions, change the structure from:
  ```lua
  if not questieWouldAnnounce(eventType) then
      -- enqueueChat calls
  end
  ```
  to:
  ```lua
  if questieWouldAnnounce(eventType) then
      SocialQuest:Debug("Banner", "Chat suppressed: Questie will announce " .. eventType)
  else
      -- enqueueChat calls
  end
  ```

  **Per-send log:** In both functions, for each `enqueueChat(msg, channel)` call, add immediately before it:
  ```lua
  SocialQuest:Debug("Banner", "Chat [" .. channel .. "]: " .. string.sub(msg, 1, 60))
  ```
  (Truncating at 60 characters keeps the debug line readable.)

  For `WhisperFriends` calls (used in both functions for whisper-to-friends), add before the call:
  ```lua
  SocialQuest:Debug("Banner", "Chat [WHISPER]: " .. string.sub(msg, 1, 60))
  ```

  **`OnQuestEvent` has:** party, raid, guild, battleground, and whisper-friends chat paths.
  **`OnObjectiveEvent` has:** party, battleground, and whisper-friends paths only (no raid, no guild — objectives never go to those channels).

- [ ] **Step 3: Add [SQ][Banner] debug calls — inbound banner path**

  **In `OnRemoteQuestEvent`**, just before each `return` that exits early (guard failures), add a debug call explaining the reason:

  | Guard condition | Debug string |
  |---|---|
  | `db.general.displayReceived` is false | `"Banner suppressed: displayReceived off"` |
  | `sectionDb.displayReceived` is false | `"Banner suppressed: section displayReceived off"` |
  | `sectionDb.display[eventType]` is false | `"Banner suppressed: display." .. eventType .. " off"` |
  | friends-only filter | `"Banner suppressed: friends-only filter"` |

  And just before the `displayBanner` call at the end of `OnRemoteQuestEvent`:
  ```lua
  SocialQuest:Debug("Banner", "Banner: " .. eventType .. " from " .. sender .. " — " .. (title or "?"))
  ```

  **In `OnRemoteObjectiveEvent`**, apply the same pattern. This function's guards are:

  | Guard condition | Debug string |
  |---|---|
  | `not db.enabled or not db.general.displayReceived` | `"Banner suppressed: addon or displayReceived off"` |
  | `not sectionDb.displayReceived` | `"Banner suppressed: section displayReceived off"` |
  | `not sectionDb.display[eventType]` | `"Banner suppressed: display." .. eventType .. " off"` |
  | friends-only filter (raid) | `"Banner suppressed: friends-only filter"` |
  | friends-only filter (battleground) | `"Banner suppressed: friends-only filter"` |

  And just before the `displayBanner` call at the end of `OnRemoteObjectiveEvent`:
  ```lua
  SocialQuest:Debug("Banner", "Banner: " .. eventType .. " from " .. sender .. " — questID=" .. questID)
  ```
  (Use `questID` since `OnRemoteObjectiveEvent` receives the raw questID, not a resolved title.)

- [ ] **Step 4: Add [SQ][Banner] debug calls — all-complete path**

  **In `checkAllCompleted`**, add a debug call at each early-return guard:

  | Guard condition | Debug string |
  |---|---|
  | `not anyRemote` (no group members) | `"All complete suppressed: not in group"` |
  | non-SQ member present | `"All complete suppressed: non-SQ member present"` |
  | `localEngaged and not localFlagged` | `"All complete suppressed: local player engaged but not done"` |
  | `engaged but not hasCompleted` (remote) | `"All complete suppressed: not all engaged players completed"` |
  | `not anyEngaged` | `"All complete suppressed: no engaged players"` |
  | display gating (`sectionDb.display.completed` off) | `"All complete suppressed: display.completed off"` |

  Just before the `displayBanner(msg, "all_complete")` call:
  ```lua
  SocialQuest:Debug("Banner", "All complete: questID=" .. questID .. " — banner displayed")
  ```

- [ ] **Step 5: Verify**

  Confirm:
  - Each `enqueueChat` call site in `OnQuestEvent` and `OnObjectiveEvent` has a pre-call debug log
  - Questie suppression path has a debug log
  - `OnRemoteQuestEvent` and `OnRemoteObjectiveEvent` have debug logs at each guard exit and at the banner display
  - `checkAllCompleted` has debug logs at each early return and at the banner display

- [ ] **Step 6: Commit**

  ```bash
  git add Core/Announcements.lua
  git commit -m "feat: add [SQ][Banner] debug logging"
  ```

---

## Chunk 5: Force Resync button

### Task 5: Add Force Resync button to `UI/Options.lua` and locale strings to `Locales/enUS.lua`

**Files:**
- Modify: `UI/Options.lua`
- Modify: `Locales/enUS.lua`

- [ ] **Step 1: Read both files**

  In `UI/Options.lua`, locate the `debug` section (around line 277). Note the existing structure: a `testBanners` inline group with `execute` buttons. The Force Resync button goes in the `debug.args` table, **outside** the `testBanners` group (it is a standalone execute button, not a test demo button).

  The button must be hidden when `db.debug.enabled` is false. In AceConfig, use the `hidden` field for this.

  The button uses a module-level timestamp for its 30-second cooldown. The timestamp and button are both defined inside `SocialQuestOptions:Initialize()` (or at module level in `UI/Options.lua`).

- [ ] **Step 2: Add locale strings to `Locales/enUS.lua`**

  Add two entries in the `-- UI/Options.lua — debug section` comment block:
  ```lua
  L["Force Resync"]   = true
  L["Request a fresh quest snapshot from all current group members. Disabled for 30 seconds after each use."] = true
  ```

- [ ] **Step 3: Add the cooldown timestamp and button definition in `UI/Options.lua`**

  **Cooldown timestamp:** Add a module-level variable at the top of `UI/Options.lua` (with the other file-level locals):
  ```lua
  local lastResyncTime = 0
  ```

  **Button definition:** Inside `SocialQuestOptions:Initialize()`, in the `debug.args` table, add the `forceResync` entry. Insert it before the `testBanners` inline group so it appears first in the debug section:

  ```lua
  forceResync = {
      type     = "execute",
      name     = L["Force Resync"],
      desc     = L["Request a fresh quest snapshot from all current group members. Disabled for 30 seconds after each use."],
      order    = 1,
      hidden   = function() return not db.debug.enabled end,
      disabled = function() return GetTime() - lastResyncTime < 30 end,
      func     = function()
          lastResyncTime = GetTime()
          SocialQuestComm:SendResyncRequest()
      end,
  },
  ```

  Also update the `testBanners` group's `order` if needed so it sorts after the new button (e.g., `order = 2`).

  **Important:** The `hidden` function gates the button on `db.debug.enabled`. The button is only visible — and therefore only clickable — when debug mode is on. This matches the spec: "The button lives inside the existing Debug options group, so it is only visible when `db.debug.enabled` is true."

  **Important:** The `disabled` function uses `GetTime()` directly. `GetTime()` is always available in the WoW environment. No ticker or timer is needed — AceConfigDialog re-evaluates `disabled` on each UI refresh.

- [ ] **Step 4: Verify**

  Confirm:
  - `lastResyncTime = 0` declared at module level
  - `forceResync` button entry is in `debug.args`
  - `hidden` returns `not db.debug.enabled`
  - `disabled` returns `GetTime() - lastResyncTime < 30`
  - `func` sets `lastResyncTime = GetTime()` and calls `SocialQuestComm:SendResyncRequest()`
  - Both locale strings are in `Locales/enUS.lua`
  - No new db keys were added (the cooldown state is purely in-memory)

- [ ] **Step 5: Commit**

  ```bash
  git add UI/Options.lua Locales/enUS.lua
  git commit -m "feat: add Force Resync button to debug options"
  ```
