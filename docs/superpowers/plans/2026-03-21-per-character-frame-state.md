# Per-Character Frame State & Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the SocialQuest group window's UI state (active tab, collapsed zones, scroll positions) from shared profile storage to per-character storage, and fix three unrelated bugs: a Lua forward-reference crash, and spurious Bindings.xml load warnings.

**Architecture:** AceDB's `char` scope (already used for `knownFlightNodes`) is isolated per character and never shared. `frameState` (currently in `profile`) is moved into `char`, and the two in-memory-only scroll tables become persisted fields there. A `OnProfileReset` AceDB callback resets `char.frameState` to defaults whenever the profile is reset. The two bug fixes are single-line changes in separate files.

**Tech Stack:** Lua 5.1, Ace3 (AceDB-3.0, CallbackHandler-1.0), WoW TBC Anniversary (Interface 20505)

**Spec:** `docs/superpowers/specs/2026-03-21-per-character-frame-state-design.md`

**Verification note:** This is a WoW addon with no automated test framework. Each task's verification step is an in-game smoke test using `/reload` and the SocialQuest group window (`/sq`).

---

## Files modified

| File | Change |
|---|---|
| `SocialQuest.lua` | Move `frameState` from `profile` to `char` in `GetDefaults()`; add `tabScrollPositions`/`tabContentHeights` defaults; add `OnProfileReset` callback |
| `UI/GroupFrame.lua` | Remove two file-scope scroll locals; redirect all reads/writes to `db.char.frameState`; add `ResetFrameState()` method; update header comment |
| `Core/Announcements.lua` | Add `local checkAllCompleted` forward declaration before `OnQuestEvent` |
| `SocialQuest.toc` | Remove `Bindings.xml` line; bump version to 2.3.2 |
| `CLAUDE.md` | Add version 2.3.2 history entry |

---

## Task 1: Update AceDB defaults and add OnProfileReset hook

**Files:**
- Modify: `SocialQuest.lua:314-325`

This task has two sub-changes in the same file: (a) restructure the defaults table, and (b) add the callback. Both are in `SocialQuest.lua`. Do them together and commit once.

### Step 1a: Update `GetDefaults()` — move `frameState` from `profile` to `char`

- [ ] Open `SocialQuest.lua`. Locate lines 314–321 (the `frameState` block inside `profile`) and lines 323–325 (the `char` block).

**Before (lines 314–325):**
```lua
            frameState = {
                activeTab = "shared",
                collapsedZones = {
                    mine   = {},
                    party  = {},
                    shared = {},
                },
            },
        },
        char = {
            knownFlightNodes = {},  -- [nodeName] = true; persists across sessions
        },
```

- [ ] Replace with:
```lua
        },
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
            knownFlightNodes = {},  -- [nodeName] = true; persists across sessions
        },
```

The closing `},` before `char` is the closing brace of the `profile` table — `frameState` has been removed from inside it. Verify the `profile` table now ends at `minimap = { hide = false },` with no `frameState` entry.

### Step 1b: Add `OnProfileReset` callback in `OnInitialize`

- [ ] Locate line 86 in `SocialQuest.lua`:
```lua
    self.db = LibStub("AceDB-3.0"):New("SocialQuestDB", self:GetDefaults(), true)
```

- [ ] Insert the following immediately after that line (before the `self.AQL = AQL` line):
```lua
    -- When the player resets their profile, also reset char-scoped frame state
    -- so the quest window reverts to defaults (tab = Shared, all zones expanded,
    -- scroll positions = 0).
    -- Dot-call (not colon): self.db is the CallbackHandler target, not the
    -- method receiver. Colon would pass self.db as target instead of self.
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

### Step 1c: Verify structure

- [ ] Confirm the file now has:
  - No `frameState` key inside the `profile = { ... }` block
  - `frameState` as the first key inside the `char = { ... }` block, containing `activeTab`, `collapsedZones`, `tabScrollPositions`, `tabContentHeights`
  - `knownFlightNodes` still in `char`, after `frameState`
  - `OnProfileReset` callback registered immediately after line 86

### Step 1d: Commit

- [ ] Commit:
```
git add SocialQuest.lua
git commit -m "feat: move frameState to char scope, add OnProfileReset hook"
```

---

## Task 2: Update GroupFrame.lua

**Files:**
- Modify: `UI/GroupFrame.lua`

This task rewires all references from the removed file-scope scroll locals and the moved `profile.frameState` to `db.char.frameState`. It also adds `ResetFrameState()`. There are approximately 10 call sites plus the 2 local declarations to remove.

### Step 2a: Remove file-scope scroll locals

- [ ] Open `UI/GroupFrame.lua`. Locate lines 11–12:
```lua
local tabScrollPositions  = {}  -- [tabID] = last known vertical scroll offset
local tabContentHeights   = {}  -- [tabID] = content height when scroll was saved (for bottom-detection)
```

- [ ] Delete both lines. Lines 13–14 (`lastRenderedTab` and `scrollRestoreSeq`) must remain untouched.

- [ ] Update the file header comment on line 4 from:
```lua
-- Zone collapse state and active tab are persisted via AceDB frameState.
```
to:
```lua
-- Zone collapse state, active tab, and scroll positions are persisted via AceDB char.frameState.
```

### Step 2b: Update tab click handler

- [ ] Locate the `makeTab` click handler (around line 130–139). It references both locals and `profile.frameState`. Replace:
```lua
            local outgoingID = SocialQuest.db.profile.frameState.activeTab or "shared"
            tabScrollPositions[outgoingID] = frame.scrollFrame:GetVerticalScroll()
            tabContentHeights[outgoingID]  = (frame.content and frame.content:GetHeight()) or 0
            SocialQuest.db.profile.frameState.activeTab = id
```
with:
```lua
            local outgoingID = SocialQuest.db.char.frameState.activeTab or "shared"
            SocialQuest.db.char.frameState.tabScrollPositions[outgoingID] = frame.scrollFrame:GetVerticalScroll()
            SocialQuest.db.char.frameState.tabContentHeights[outgoingID]  = (frame.content and frame.content:GetHeight()) or 0
            SocialQuest.db.char.frameState.activeTab = id
```

### Step 2c: Update `Refresh()` — same-tab scroll save

- [ ] Locate the same-tab scroll save block inside `Refresh()` (the `if activeID == lastRenderedTab then` block). Replace:
```lua
    local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"

    -- Save scroll position for same-tab refreshes BEFORE SetScrollChild can clamp it.
    -- Tab-switch paths save the outgoing tab's position in the click handler instead.
    if activeID == lastRenderedTab then
        tabScrollPositions[activeID] = frame.scrollFrame:GetVerticalScroll()
        tabContentHeights[activeID]  = (frame.content and frame.content:GetHeight()) or 0
    end
```
with:
```lua
    local activeID = SocialQuest.db.char.frameState.activeTab or "shared"

    -- Save scroll position for same-tab refreshes BEFORE SetScrollChild can clamp it.
    -- Tab-switch paths save the outgoing tab's position in the click handler instead.
    if activeID == lastRenderedTab then
        SocialQuest.db.char.frameState.tabScrollPositions[activeID] = frame.scrollFrame:GetVerticalScroll()
        SocialQuest.db.char.frameState.tabContentHeights[activeID]  = (frame.content and frame.content:GetHeight()) or 0
    end
```

### Step 2d: Update `Refresh()` — savedScroll / savedHeight reads and collapsedZones

- [ ] Locate the scroll restore calculation block. Replace:
```lua
    local savedScroll  = tabScrollPositions[activeID] or 0
    local savedHeight  = tabContentHeights[activeID]  or 0
```
with:
```lua
    local savedScroll  = SocialQuest.db.char.frameState.tabScrollPositions[activeID] or 0
    local savedHeight  = SocialQuest.db.char.frameState.tabContentHeights[activeID]  or 0
```

- [ ] Locate the `collapsedZones` read in `Refresh()`. Replace:
```lua
    local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
```
with:
```lua
    local collapsedZones = SocialQuest.db.char.frameState.collapsedZones
```

### Step 2e: Update `ExpandAll()`, `CollapseAll()`, `ToggleZone()`

- [ ] In `ExpandAll()`, replace:
```lua
    SocialQuest.db.profile.frameState.collapsedZones[tabId] = {}
```
with:
```lua
    SocialQuest.db.char.frameState.collapsedZones[tabId] = {}
```

- [ ] In `CollapseAll()`, replace:
```lua
    local collapsed = SocialQuest.db.profile.frameState.collapsedZones
```
with:
```lua
    local collapsed = SocialQuest.db.char.frameState.collapsedZones
```

- [ ] In `ToggleZone()`, replace:
```lua
    local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
```
with:
```lua
    local collapsedZones = SocialQuest.db.char.frameState.collapsedZones
```

### Step 2f: Verify no remaining `profile.frameState` references

- [ ] Search `UI/GroupFrame.lua` for `profile.frameState` — expect zero matches.
- [ ] Search `UI/GroupFrame.lua` for `tabScrollPositions` without the `db.char.frameState.` prefix — expect zero matches (only the `db.char.frameState.tabScrollPositions` form should remain).
- [ ] Search `UI/GroupFrame.lua` for `tabContentHeights` without the prefix — same, expect zero matches.

### Step 2g: Add `ResetFrameState()` method

- [ ] At the end of the file (after `ToggleZone()`), add:
```lua
-- Called by the OnProfileReset callback in SocialQuest.lua.
-- Clears lastRenderedTab so the next Refresh() does not write a stale scroll
-- offset back into the freshly-reset char.frameState.
function SocialQuestGroupFrame:ResetFrameState()
    lastRenderedTab = nil
    self:RequestRefresh()
end
```

### Step 2h: In-game verification

- [ ] `/reload` in WoW.
- [ ] Open `/sq`. Verify the window opens on the Shared tab with all zones expanded and scroll at top.
- [ ] Switch to the Mine tab, scroll down, close the window with Escape, reopen with `/sq`. Verify the Mine tab is restored at the same scroll position.
- [ ] Switch between tabs; verify each tab's scroll position is remembered within the session.
- [ ] `/reload` again. Verify the active tab and scroll positions survive the reload.

### Step 2i: Commit

- [ ] Commit:
```
git add UI/GroupFrame.lua
git commit -m "feat: wire GroupFrame.lua to char.frameState, persist scroll positions"
```

---

## Task 3: Fix `checkAllCompleted` forward reference

**Files:**
- Modify: `Core/Announcements.lua:187–188`

`checkAllCompleted` is a `local function` defined at line 316 but called at line 260 (inside `OnQuestEvent`) and line 417 (inside `OnRemoteQuestEvent`). Lua 5.1 resolves undeclared locals to the global scope at the point of call, finding `nil`, and crashing with "attempt to call global 'checkAllCompleted'".

### Step 3a: Add forward declaration

- [ ] Open `Core/Announcements.lua`. Locate line 187–188:
```lua

function SocialQuestAnnounce:OnQuestEvent(eventType, questID, questInfo)
```

- [ ] Insert one line immediately before `function SocialQuestAnnounce:OnQuestEvent`:
```lua
local checkAllCompleted  -- forward declaration; defined after OnRemoteQuestEvent below
```

The blank line before it can stay or be removed — either is fine.

### Step 3b: Verify the definition is still `local function`

- [ ] Confirm line 316 (now shifted by 1 to line 317) still reads:
```lua
local function checkAllCompleted(questID, localHasCompleted)
```
No change needed there — the forward declaration and the `local function` definition share the same upvalue slot automatically in Lua 5.1.

### Step 3c: In-game verification

- [ ] `/reload` and complete or turn in a quest while in a party (or simulate by checking BugSack after normal play). The "attempt to call global 'checkAllCompleted'" error must not appear.

### Step 3d: Commit

- [ ] Commit:
```
git add Core/Announcements.lua
git commit -m "fix: forward-declare checkAllCompleted to prevent nil call error"
```

---

## Task 4: Fix Bindings.xml warnings, version bump, CLAUDE.md

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

### Step 4a: Remove `Bindings.xml` from `SocialQuest.toc`

- [ ] Open `SocialQuest.toc`. Locate line 9:
```
Bindings.xml
```

- [ ] Delete that line. WoW automatically discovers and loads `Bindings.xml` from the addon directory via the bindings parser; it must not also be listed in the .toc (which would cause the UI XML parser to load it a second time, generating all the "Unrecognized XML: Binding" warnings).

### Step 4b: Bump version in `SocialQuest.toc`

- [ ] Locate the `## Version:` line. The current version is `2.3.1`. This is the second revision-level change on the same day (2.3.0 and 2.3.1 were both today), so increment the revision only:

```
## Version: 2.3.2
```

### Step 4c: Update `CLAUDE.md`

- [ ] Add the following entry at the top of the Version History section (above the 2.3.1 entry):

```markdown
### Version 2.3.2 (March 2026 — Improvements branch)
- Per-character frame state: moved `frameState` (active tab, collapsed zones) and scroll position tables from shared `profile` scope to per-character `char` scope in AceDB. Scroll positions now persist across reloads. Added `OnProfileReset` callback to reset `char.frameState` when the profile is reset.
- Bug fix: added `local checkAllCompleted` forward declaration in `Core/Announcements.lua` to fix "attempt to call global 'checkAllCompleted'" crash when completing a quest.
- Bug fix: removed `Bindings.xml` from `SocialQuest.toc`; WoW's bindings parser discovers it automatically. Eliminates all "Unrecognized XML: Binding" warnings.
```

### Step 4d: In-game verification

- [ ] `/reload`. Open `/sq`. Confirm no BugSack warnings about `Bindings.xml`. Confirm key bindings still appear in the Key Bindings frame under the "Social Quest" category.

### Step 4e: Commit

- [ ] Commit:
```
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: remove Bindings.xml from toc, bump version to 2.3.2, update CLAUDE.md"
```
