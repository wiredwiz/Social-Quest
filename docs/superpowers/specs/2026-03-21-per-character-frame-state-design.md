# Per-Character Frame State & Bug Fixes Design

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the SocialQuest group window's UI state (active tab, collapsed zones, scroll positions) from shared profile storage to per-character storage, and fix three unrelated bugs discovered in the same session.

**Architecture:** AceDB already provides a `char` scope (currently used for `knownFlightNodes`) that is isolated per character and never shared across accounts or profiles. All four `frameState` fields are moved there. The two in-memory scroll tables become persisted defaults in the same `char.frameState` subtable. A `OnProfileReset` hook clears `char.frameState` back to defaults so a profile reset also resets the window state.

**Tech Stack:** Lua 5.1, Ace3 (AceDB-3.0), WoW TBC Anniversary (Interface 20505)

---

## Part 1 — Per-Character Frame State

### Problem

`frameState` (containing `activeTab` and `collapsedZones`) is stored in AceDB's `profile` scope, which is shared across all characters on the same account. The two scroll tables (`tabScrollPositions`, `tabContentHeights`) are volatile file-scope locals in `GroupFrame.lua` and are lost on every reload.

All four values are character-specific UI preferences — they reflect a specific character's quest progress and viewing habits — and must not bleed across characters.

### Data Changes — `SocialQuest.lua` `GetDefaults()`

Remove `frameState` from the `profile` subtable. Add it to the `char` subtable alongside `knownFlightNodes`:

```lua
char = {
    frameState = {
        activeTab = "shared",
        collapsedZones = {
            mine   = {},
            party  = {},
            shared = {},
        },
        tabScrollPositions = {
            mine   = 0,
            party  = 0,
            shared = 0,
        },
        tabContentHeights = {
            mine   = 0,
            party  = 0,
            shared = 0,
        },
    },
    knownFlightNodes = {},  -- unchanged
},
```

The `profile` table keeps all its other keys unchanged; only `frameState` is removed from it.

### Reference Updates — `GroupFrame.lua`


The file-scope locals `tabScrollPositions` and `tabContentHeights` are **removed**. All reads and writes to those tables are redirected to `SocialQuest.db.char.frameState.tabScrollPositions` and `SocialQuest.db.char.frameState.tabContentHeights`. No logic changes — same bottom-detection and deferred C_Timer scroll restoration.

`scrollRestoreSeq` (line 14) is a **third** file-scope scroll-related local — a transient render-cycle counter used by the deferred C_Timer sequence guard. It must **not** be removed or moved to `db.char`; it stays as a file-scope local.

`lastRenderedTab` (line 13) is also a file-scope local — it tracks which tab was last rendered to decide whether to save scroll on same-tab rebuilds. It is not persisted and must remain a file-scope local.

Every occurrence of `SocialQuest.db.profile.frameState` becomes `SocialQuest.db.char.frameState`. There are approximately 10 call sites spread across the tab click handler, `Refresh()`, `ExpandAll()`, `CollapseAll()`, and `ToggleZone()`.

### Profile Reset Hook — `SocialQuest.lua`

Register for AceDB's `OnProfileReset` callback in `OnInitialize`, **immediately after** the `self.db = LibStub("AceDB-3.0"):New(...)` line (line 86). Placing it before that line will crash at startup because `self.db` is nil. When the callback fires, overwrite `db.char.frameState` with a fresh copy of the defaults and call `SocialQuestGroupFrame:ResetFrameState()`.

```lua
-- Dot-call (not colon) is correct here: self.db is the CallbackHandler target,
-- not the method receiver. Using a colon would pass self.db as the target
-- argument instead of self, breaking callback dispatch.
self.db.RegisterCallback(self, "OnProfileReset", function()
    self.db.char.frameState = {
        activeTab          = "shared",
        collapsedZones     = { mine = {}, party = {}, shared = {} },
        tabScrollPositions = { mine = 0,  party = 0,  shared = 0  },
        tabContentHeights  = { mine = 0,  party = 0,  shared = 0  },
    }
    SocialQuestGroupFrame:ResetFrameState()
end)
```

### `ResetFrameState()` — `GroupFrame.lua`

Add a new public method on `SocialQuestGroupFrame`:

```lua
function SocialQuestGroupFrame:ResetFrameState()
    lastRenderedTab = nil
    self:RequestRefresh()
end
```

Clearing `lastRenderedTab` prevents the same-tab scroll-save path from writing a stale offset back into the freshly-reset `char.frameState` on the next render.

### Migration

Existing `profile.frameState` data (collapsed zones, active tab) is silently abandoned on upgrade. On first load after the update, `char.frameState` initialises from AceDB defaults: all zones expanded, active tab = Shared, all scroll positions = 0. This is acceptable for an active development branch.

---

## Part 2 — `checkAllCompleted` Forward Reference (Announcements.lua)

### Problem

`checkAllCompleted` is a `local function` defined at line 316 of `Core/Announcements.lua`, but it is called at line 260 (inside `OnQuestEvent`) and again at line 417. In Lua 5.1, `local` declarations are only visible from their point of definition forward — calling a local before its definition resolves to the global scope, which is `nil`, producing:

```
attempt to call global 'checkAllCompleted' (a nil value)
```

### Fix

Add a forward declaration (a `local` with no value assigned) immediately before its first use. The `local function` definition further down in the file then fills the upvalue in-place.

```lua
local checkAllCompleted  -- forward declaration; defined below OnQuestEvent
```

Place this line immediately before line 188, the `function SocialQuestAnnounce:OnQuestEvent` declaration. No other changes needed.

---

## Part 3 — `Bindings.xml` Double-Load Warnings

### Problem

`Bindings.xml` is listed in `SocialQuest.toc`, causing WoW to load it twice:

1. **Bindings parser** — loads it automatically from the addon directory (this is how all `Bindings.xml` files work in WoW; no .toc entry is required or desired).
2. **UI XML parser** — loads it because it is listed in the .toc, treats it as a UI layout file, and emits "Unrecognized XML" warnings for every `<Binding>` element and attribute it does not understand.

Leatrix Plus does not list `Bindings.xml` in its .toc and generates no warnings, confirming the diagnosis.

### Fix

Remove the `Bindings.xml` line from `SocialQuest.toc`. WoW's bindings parser will continue to discover and load the file automatically. All bindings (including the `category` grouping) remain fully functional.

---

## Version Bump

After all changes: increment the minor version in `SocialQuest.toc` (first meaningful change of the day rule from CLAUDE.md) and add a version history entry to `CLAUDE.md` covering all three items.
