# SocialQuest Banner Message Coloring

**Date:** 2026-03-12
**Addon:** SocialQuest (Interface 20505 — TBC Anniversary)
**Scope:** Restore color to remote quest event banner messages displayed via RaidWarningFrame.

---

## Overview

When SocialQuest receives a remote quest event from another player, it displays a banner notification via `RaidWarningFrame:AddMessage()`. Currently these messages are plain white text. This spec restores color based on event type — the behavior previously provided by the Sea library before it was dropped as a dependency.

In TBC Anniversary (Interface 20505), `RaidWarningFrame:AddMessage(text, r, g, b)` accepts color as separate r/g/b float arguments (0.0–1.0), not as `|c` escape sequences embedded in the text string. The `SocialQuestColors.event` sub-table therefore stores `{r, g, b}` float triples.

---

## Data Structures

### `SocialQuestColors.event` — new sub-table in `Util/Colors.lua`

A lookup table mapping event type strings to `{r, g, b}` float triples (each value 0.0–1.0) for use as `RaidWarningFrame:AddMessage()` color arguments.

| Event type | Color | r | g | b |
|---|---|---|---|---|
| `"accepted"` | green | 0 | 1 | 0 |
| `"completed"` | gold | 1 | 0.843 | 0 |
| `"finished"` | cyan | 0 | 0.8 | 1 |
| `"abandoned"` | grey | 0.533 | 0.533 | 0.533 |
| `"failed"` | red | 1 | 0 | 0 |

These match the colors used in the SocialQuest UI (`#00FF00`, `#FFD700`, `#00CCFF`, `#888888`, `#FF0000` from `SocialQuestColors`), converted to 0.0–1.0 float range — though not always under the same key name.

---

## Implementation Details

### `Util/Colors.lua`

Append the `event` sub-table after the existing `SocialQuestColors` declaration:

```lua
SocialQuestColors.event = {
    accepted  = { r = 0,     g = 1,     b = 0     },  -- green
    completed = { r = 1,     g = 0.843, b = 0     },  -- gold
    finished  = { r = 0,     g = 0.8,   b = 1     },  -- cyan
    abandoned = { r = 0.533, g = 0.533, b = 0.533 },  -- grey
    failed    = { r = 1,     g = 0,     b = 0     },  -- red
}
```

### `Core/Announcements.lua`

In `OnRemoteQuestEvent`, replace the current `RaidWarningFrame:AddMessage(bannerMsg)` call. Look up the event color and pass r/g/b as separate arguments:

```lua
local color = SocialQuestColors.event[eventType]
if RaidWarningFrame then
    if color then
        RaidWarningFrame:AddMessage(bannerMsg, color.r, color.g, color.b)
    else
        RaidWarningFrame:AddMessage(bannerMsg)
    end
end
```

The existing `if RaidWarningFrame then` nil guard is preserved. When `color` is nil (unknown event type), the message is displayed in the frame's default color rather than erroring. `|c` escape codes and `|r` reset are not used — they are not applicable to `RaidWarningFrame`.

---

## Files Changed

| File | Change |
|---|---|
| `Util/Colors.lua` | Add `SocialQuestColors.event` sub-table with r/g/b float triples |
| `Core/Announcements.lua` | Pass color r/g/b to `RaidWarningFrame:AddMessage()` in `OnRemoteQuestEvent` |

**Files NOT changed:** All other SocialQuest files. No new dependencies, no callback or options changes.

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| Unknown event type | `OnRemoteQuestEvent` exits early at `if not tmpl then return end` before reaching `AddMessage` — the nil color branch is a belt-and-suspenders guard only |
| `RaidWarningFrame` nil | Existing nil guard preserved — no change in behavior |
| Future event type added to templates but not to `SocialQuestColors.event` | Falls back to frame default color — no error |
