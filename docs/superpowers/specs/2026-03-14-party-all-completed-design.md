# Party "Everyone Has Completed" Notification — Design Spec

## Goal

Restore the original feature that fires an "Everyone has completed [Quest Name]" banner (and optional chat message) when every party/raid/battleground member has turned in the same quest. The feature is suppressed entirely when any group member does not have SocialQuest installed, ensuring the check is always accurate.

## Scope

Three files touched:

| File | Change |
|------|--------|
| `Util/Colors.lua` | Add `all_complete` event color (purple normal, blue colorblind) |
| `Core/GroupData.lua` | Write `completedQuests[questID] = true` when a remote "completed" event arrives |
| `Core/Announcements.lua` | Add `checkAllCompleted` private function; call it from `OnQuestEvent` and `OnRemoteQuestEvent` |

No new DB schema keys, no new options toggles, no new files.

---

## Colors (`Util/Colors.lua`)

Add `all_complete` to both event color tables:

```lua
-- SocialQuestColors.event
all_complete = { r = 0.6,   g = 0.0,   b = 0.9   },  -- purple   (#9900E6)

-- SocialQuestColors.eventCB
all_complete = { r = 0.0,   g = 0.447, b = 0.698  },  -- blue     (#0072B2, Okabe-Ito)
```

The Okabe-Ito blue is the only remaining unused color from that palette. All other palette slots are already assigned to existing event types. Purple is unused in normal mode.

---

## Data Layer Fix (`Core/GroupData.lua`)

### Problem

`OnUpdateReceived` currently removes a completed quest from the player's active `quests` table but does not write to `completedQuests`. The "everyone completed" check reads `completedQuests`, so real-time completions during a session are invisible to it.

Note: `OnGroupChanged` already initializes `completedQuests = {}` in all new player stubs, so no change is needed there — only `OnUpdateReceived` is missing the write.

### Fix

In `OnUpdateReceived`, when `payload.eventType` is `"completed"`, also mark it in `completedQuests` before removing from active quests:

```lua
if payload.eventType == "completed" then
    entry.completedQuests[payload.questID] = true
end
entry.quests[payload.questID] = nil
```

`abandoned` and `failed` are not written to `completedQuests` — only a successful turn-in counts.

---

## Check Logic (`Core/Announcements.lua`)

### New private function: `checkAllCompleted(questID, localHasCompleted)`

Place this function in the "Remote event banner notifications" section, just before `OnRemoteQuestEvent`.

**Key invariant:** `SocialQuestGroupData.PlayerQuests` contains only remote group members — the local player is never stored there. The local player's completion status is handled separately by the `localHasCompleted` parameter and the `C_QuestLog` API check.

**Algorithm:**

```
1. If SocialQuestGroupData.PlayerQuests is empty → return (not in a group)
2. For each entry in PlayerQuests:
     if hasSocialQuest == false → return  (non-SQ member present)
3. For each entry in PlayerQuests:
     if completedQuests[questID] ~= true → return  (SQ member hasn't completed it)
4. If not localHasCompleted:
     if not C_QuestLog.IsQuestFlaggedCompleted(questID) → return
5. All checks pass:
     a. Determine section via getSenderSection()
     b. Check display gating (see below)
     c. Resolve quest title
     d. Format message: "Everyone has completed [title]"
     e. Show banner via displayBanner(msg, "all_complete")
     f. If localHasCompleted and chat announce gating passes → send chat message
```

**`localHasCompleted` parameter:**
- `true` when called from `OnQuestEvent("completed", ...)` — the local player just turned in the quest; no API check needed
- `false` when called from `OnRemoteQuestEvent(sender, "completed", ...)` — the local player's completion must be verified via `C_QuestLog.IsQuestFlaggedCompleted(questID)`

### Quest title resolution

Use plain text (not a clickable hyperlink) — the message goes to both `RaidNotice_AddMessage` (which does not parse chat hyperlinks) and group chat:

```lua
local AQL   = SocialQuest.AQL
local info  = AQL and AQL:GetQuest(questID)
local title = (info and info.title)
           or C_QuestLog.GetTitleForQuestID(questID)
           or ("Quest " .. questID)
```

`AQL:GetQuest` returns the cached quest info table with a `.title` field. `C_QuestLog.GetTitleForQuestID` is used as a fallback; its TBC Classic availability is confirmed by existing usage elsewhere in Announcements.lua.

### Display gating

The "everyone has completed" notification is a synthesized local event (it fires on all SQ clients simultaneously). Display gating:

**Banner:**
```lua
db.enabled
and db[section]                  -- nil-safety: section key must exist in DB
and db[section].display          -- nil-safety: display subtable must exist
and db[section].display.completed
```

`checkAllCompleted` reads `db.enabled` itself rather than relying on the caller, because it is called from two different sites (`OnQuestEvent` and `OnRemoteQuestEvent`) and must be self-contained.

The `db.general.displayReceived` master switch and the per-section `displayReceived` toggle are intentionally not checked. Those gates apply to raw inbound remote events (one sender → one receiver). This notification is synthesized locally — it is not "received from" any single remote player.

**Chat message (local trigger only):**
```lua
db[section].transmit and db[section].announce.completed
```

`db[section]` nil-safety is guaranteed by the banner gate earlier in the function — if `db[section]` were nil the function would have returned already. `transmit` is used for consistency with `OnQuestEvent`, which uses the same two-part gate for all outbound chat messages. If the user has disabled transmission, no messages of any kind go to group chat.

### Chat channel mapping

| `getSenderSection()` | `enqueueChat` channel arg |
|---------------------|--------------------------|
| `"party"` | `"PARTY"` |
| `"raid"` | `"RAID"` |
| `"battleground"` | `"BATTLEGROUND"` |

`"BATTLEGROUND"` is the correct WoW chat channel string for TBC Classic. `"INSTANCE_CHAT"` does not exist in TBC Classic and must not be used.

### Call sites

**`OnQuestEvent`** — after the existing own-quest banner call:
```lua
if eventType == "completed" then
    checkAllCompleted(questID, true)
end
```

**`OnRemoteQuestEvent`** — after `displayBanner`:
```lua
if eventType == "completed" then
    checkAllCompleted(questID, false)
end
```

---

## Chat message deduplication

When a remote player is last to complete the quest, every SocialQuest client in the group simultaneously detects "everyone completed" via `OnRemoteQuestEvent`. Because `localHasCompleted` is `false` in all these cases, none of them sends a chat message — only the banner fires. This avoids multiple identical chat messages in party/raid chat.

When the local player is last to complete the quest, they fire `OnQuestEvent("completed")` with `localHasCompleted = true`. All other SQ clients receive the `SQ_UPDATE` and fire `OnRemoteQuestEvent` with `localHasCompleted = false`. Result: exactly one chat message is sent (by whoever completed last), and all SQ members see the banner.

If the last-completer reloads their UI before peers receive their `SQ_UPDATE`, peers still see `OnRemoteQuestEvent` with `localHasCompleted = false` — the banner fires but no chat message is sent. This is the correct safe failure mode.

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Solo (no group) | `PlayerQuests` empty → return early, no notification |
| Any non-SQ member in group | `hasSocialQuest == false` → return early, no notification |
| SQ member hasn't completed quest yet | `completedQuests[questID] ~= true` → return early |
| Local player hasn't completed quest | `C_QuestLog.IsQuestFlaggedCompleted` false → return early |
| `display.completed` toggle off | Banner suppressed (same as normal completion banners) |
| `announce.completed` toggle off | Chat message suppressed even on local trigger |
| Two players complete simultaneously (remote arrival) | Both send `SQ_UPDATE`; second arrival triggers the check; first arrival finds the second player not yet marked complete → no false positive |
| Two players complete simultaneously (local fire) | Both machines call `checkAllCompleted(questID, true)` locally before either's `SQ_UPDATE` arrives. Each machine's `PlayerQuests` still shows the other player as not done → both return early at step 3, no false positive |
| Last-completer reloads mid-sync | Peers see `OnRemoteQuestEvent`, show banner only, no chat — safe failure mode |
