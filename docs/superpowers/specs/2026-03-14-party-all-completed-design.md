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

### Fix

In `OnUpdateReceived`, when `payload.eventType` is `"completed"`, `"abandoned"`, or `"failed"` (i.e. when the quest is removed from active tracking), also mark it in `completedQuests` for the `"completed"` case:

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

**Algorithm:**

```
1. If SocialQuestGroupData.PlayerQuests is empty → return (not in a group)
2. For each entry in PlayerQuests:
     if hasSocialQuest == false → return  (non-SQ member present; option B)
3. For each entry in PlayerQuests:
     if completedQuests[questID] ~= true → return  (SQ member hasn't completed it)
4. If not localHasCompleted:
     if not C_QuestLog.IsQuestFlaggedCompleted(questID) → return
5. All checks pass:
     a. Resolve quest title (AQL:GetQuestLink → C_QuestLog.GetTitleForQuestID → "Quest N" fallback)
     b. Format message: "Everyone has completed [title]"
     c. Show banner via displayBanner(msg, "all_complete")
     d. If localHasCompleted and chat announce gating passes → enqueueChat(msg, activeChannel)
```

**`localHasCompleted` parameter:**
- `true` when called from `OnQuestEvent("completed", ...)` — the local player just turned in the quest, no API check needed
- `false` when called from `OnRemoteQuestEvent(sender, "completed", ...)` — the local player's state must be verified via `C_QuestLog.IsQuestFlaggedCompleted`

### Display gating

The "everyone has completed" notification is a synthesized local event. It is gated as follows:

- **Banner:** `db.enabled` and `db[section].display` and `db[section].display.completed`
  - `section` is the return value of `getSenderSection()` (party / raid / battleground)
  - The `displayReceived` per-section toggle is **not** checked — this is a synthetic notification, not a raw inbound remote event
- **Chat message (local trigger only):** additionally requires `db[section].transmit` and `db[section].announce.completed`

This means the notification respects the same "completed" toggles as normal quest completion banners and chat announces, with no new options.

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

When a remote player is last to complete the quest, every SocialQuest client in the group simultaneously detects "everyone completed" via `OnRemoteQuestEvent`. Because `localHasCompleted` is `false` in all these cases, none of them sends a chat message — only the banner fires. This avoids multiple identical chat messages appearing in party/raid chat.

When the local player is last to complete the quest, they fire `OnQuestEvent("completed")` with `localHasCompleted = true`. All other SQ clients receive the `SQ_UPDATE` and fire `OnRemoteQuestEvent` with `localHasCompleted = false`. Result: exactly one chat message is sent (by the player who completed last), and all SQ members see the banner.

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Solo (no group) | `PlayerQuests` empty → return early, no notification |
| Any non-SQ member in group | `hasSocialQuest == false` → return early, no notification |
| SQ member hasn't completed quest yet | `completedQuests[questID] ~= true` → return early |
| Local player hasn't completed quest | `C_QuestLog.IsQuestFlaggedCompleted` false → return early |
| display.completed toggle off | Banner suppressed (same as normal completion banners) |
| announce.completed toggle off | Chat message suppressed even on local trigger |
| Two players complete simultaneously | Both send `SQ_UPDATE`; second arrival triggers the check; first arrival finds the second player not yet marked complete → safe, no false positive |
