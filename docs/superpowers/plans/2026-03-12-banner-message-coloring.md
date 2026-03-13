# Banner Message Coloring Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Color `RaidWarningFrame` banner notifications by quest event type (green=accepted, gold=completed, cyan=finished, grey=abandoned, red=failed).

**Architecture:** Two surgical edits — `Util/Colors.lua` gains a `SocialQuestColors.event` sub-table of `{r, g, b}` float triples; `Core/Announcements.lua` passes those floats as color arguments to `RaidWarningFrame:AddMessage()`. No new files, no new dependencies.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary Interface 20505. `RaidWarningFrame:AddMessage(text, r, g, b)` takes 0.0–1.0 float color components — `|c` escape codes are NOT supported here.

**Spec:** `docs/superpowers/specs/2026-03-12-banner-message-coloring.md`

---

## Chunk 1: Add event color table to Colors.lua

### Task 1: Add `SocialQuestColors.event` sub-table

**Files:**
- Modify: `Util/Colors.lua:16` (append after closing `}` of `SocialQuestColors`)

- [ ] **Step 1: Append the event color sub-table after the existing `SocialQuestColors` declaration**

`Util/Colors.lua` currently ends at line 16 with the closing `}` of `SocialQuestColors`. Append the following block after line 16:

```lua
SocialQuestColors.event = {
    accepted  = { r = 0,     g = 1,     b = 0     },  -- green  (#00FF00)
    completed = { r = 1,     g = 0.843, b = 0     },  -- gold   (#FFD700)
    finished  = { r = 0,     g = 0.8,   b = 1     },  -- cyan   (#00CCFF)
    abandoned = { r = 0.533, g = 0.533, b = 0.533 },  -- grey   (#888888)
    failed    = { r = 1,     g = 0,     b = 0     },  -- red    (#FF0000)
}
```

The float values are exact conversions of the hex colors already used in `SocialQuestColors` (e.g. `failed = "|cFFFF0000"` → red → `{1, 0, 0}`).

- [ ] **Step 2: Commit**

```bash
git add Util/Colors.lua
git commit -m "feat: add event color float triples to SocialQuestColors"
```

---

## Chunk 2: Apply colors to RaidWarningFrame in Announcements.lua

### Task 2: Pass event color to `RaidWarningFrame:AddMessage()`

**Files:**
- Modify: `Core/Announcements.lua:181-183`

- [ ] **Step 1: Replace the `RaidWarningFrame` block in `OnRemoteQuestEvent`**

At `Core/Announcements.lua` lines 181-183, replace:

```lua
    if RaidWarningFrame then
        RaidWarningFrame:AddMessage(bannerMsg)
    end
```

With:

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

**Why the `else` branch:** `OnRemoteQuestEvent` exits early at line 178 (`if not tmpl then return end`) for any unknown event type, so `color` will never be nil in practice. The `else` is a belt-and-suspenders guard for future event types added to `templates` but not yet to `SocialQuestColors.event`.

- [ ] **Step 2: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: color RaidWarningFrame banners by quest event type"
```

---

## In-Game Verification

No automated test runner. Verify in the WoW TBC Anniversary client:

- Have a second SocialQuest-enabled player in your group
- Trigger each event type and confirm banner color:
  - Quest accepted → **green** banner
  - Quest objectives finished → **cyan** banner
  - Quest turned in → **gold** banner
  - Quest abandoned → **grey** banner
  - Quest failed → **red** banner
