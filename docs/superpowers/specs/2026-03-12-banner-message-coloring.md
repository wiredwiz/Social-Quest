# SocialQuest Banner Message Coloring

**Date:** 2026-03-12
**Addon:** SocialQuest (Interface 20505 — TBC Anniversary)
**Scope:** Restore color to remote quest event banner messages displayed via RaidWarningFrame.

---

## Overview

When SocialQuest receives a remote quest event from another player, it displays a banner notification via `RaidWarningFrame:AddMessage()`. Currently these messages are plain white text. This spec restores color based on event type — the behavior previously provided by the Sea library before it was dropped as a dependency.

---

## Data Structures

### `SocialQuestColors.event` — new sub-table in `Util/Colors.lua`

A lookup table mapping event type strings to existing `SocialQuestColors` values. Referencing existing values ensures colors are defined exactly once and any future change to a base color propagates automatically.

| Event type | Color source | Visual |
|---|---|---|
| `"accepted"` | `SocialQuestColors.completed` | green `#00FF00` |
| `"completed"` | `SocialQuestColors.header` | gold `#FFD700` |
| `"finished"` | `SocialQuestColors.chain` | cyan `#00CCFF` |
| `"abandoned"` | `SocialQuestColors.unknown` | grey `#888888` |
| `"failed"` | `SocialQuestColors.failed` | red `#FF0000` |

---

## Implementation Details

### `Util/Colors.lua`

Append the `event` sub-table after the existing `SocialQuestColors` declaration. Values reference existing entries — no new hex literals:

```lua
SocialQuestColors.event = {
    accepted  = SocialQuestColors.completed,  -- green
    completed = SocialQuestColors.header,     -- gold
    finished  = SocialQuestColors.chain,      -- cyan
    abandoned = SocialQuestColors.unknown,    -- grey
    failed    = SocialQuestColors.failed,     -- red
}
```

### `Core/Announcements.lua`

In `OnRemoteQuestEvent`, replace the current `RaidWarningFrame:AddMessage(bannerMsg)` call with a color-wrapped version:

```lua
local color = SocialQuestColors.event[eventType] or SocialQuestColors.white
RaidWarningFrame:AddMessage(color .. bannerMsg .. SocialQuestColors.reset)
```

`SocialQuestColors.white` (`"|cFFFFFFFF"`) serves as the fallback for any unknown future event types. `SocialQuestColors.reset` (`"|r"`) already exists in the table.

---

## Files Changed

| File | Change |
|---|---|
| `Util/Colors.lua` | Add `SocialQuestColors.event` sub-table |
| `Core/Announcements.lua` | Wrap banner message with event color in `OnRemoteQuestEvent` |

**Files NOT changed:** All other SocialQuest files. No new public API, no new dependencies, no callback or options changes.

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| Unknown event type | Falls back to `SocialQuestColors.white` — plain white, no error |
| `RaidWarningFrame` nil (frame not yet created) | Existing nil guard at line 181 handles this — no change |
| Base color value changes in `SocialQuestColors` | `event` sub-table references propagate the change automatically |
