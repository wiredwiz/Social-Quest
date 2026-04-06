# Window Clamp-to-Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure the SocialQuest group window and `/sq diagnose` console never open off-screen, nudging them the minimum amount needed to be fully visible.

**Architecture:** A shared utility `SQWowUI.ClampFrameToScreen(frame)` is added to `Core/WowUI.lua`. It reads the frame's actual rendered edges after positioning and shifts it on-screen if any edge is outside `UIParent` bounds. Both windows call it at the end of their show/restore path. No persistent `SetClampedToScreen` is used — this is a one-shot open-time correction only.

**Tech Stack:** Lua 5.1, WoW addon API (`GetLeft`/`GetRight`/`GetTop`/`GetBottom`, `UIParent`, `SetPoint`/`ClearAllPoints`), AceDB char-scope saved variables.

---

## File Map

| File | Change |
|---|---|
| `tests/WowUI_test.lua` | **Create** — unit tests for `ClampFrameToScreen` |
| `Core/WowUI.lua` | **Modify** — add `SQWowUI.ClampFrameToScreen(frame)` at end of file |
| `UI/GroupFrame.lua` | **Modify** — call `SQWowUI.ClampFrameToScreen(f)` at end of `applyFrameState()` (line 597) |
| `SocialQuest.lua` | **Modify** — call `SQWowUI.ClampFrameToScreen(f)` at end of console restore block (line 877) |
| `SocialQuest.toc` + 3 companion tocs | **Modify** — version bump to 2.18.23 |
| `CLAUDE.md` | **Modify** — add version 2.18.23 entry |

---

## Task 1: Write failing tests for ClampFrameToScreen

**Files:**
- Create: `tests/WowUI_test.lua`

**Context:** The test stubs out WoW globals with plain Lua tables. `UIParent` is mocked with `GetRight()=1920`, `GetTop()=1080` (standard 1080p). Mock frames expose `GetLeft/Right/Top/Bottom` and record the last `SetPoint` call. `dofile("Core/WowUI.lua")` loads the module under test; stubs must be set before that call.

**Coordinate system reminder:** WoW Y increases upward. `GetBottom()` < `GetTop()`. A frame with `GetTop()=800` and height 300 has `GetBottom()=500`. A frame positioned below the screen has `GetBottom() < 0`.

- [ ] **Step 1: Create `tests/WowUI_test.lua` with stubs and mock helpers**

```lua
-- tests/WowUI_test.lua
-- Standalone unit tests for Core/WowUI.lua ClampFrameToScreen.
-- Run from repo root: lua tests/WowUI_test.lua

local f = io.open("Core/WowUI.lua", "r")
if not f then error("Run from repo root: lua tests/WowUI_test.lua") end
f:close()

-- ── Stubs ──────────────────────────────────────────────────────────────────

-- WowUI.lua references SocialQuestWowAPI.IS_RETAIL at module scope.
SocialQuestWowAPI = { IS_RETAIL = false, IS_TBC = true, IS_MOP = false, IS_CLASSIC_ERA = false }

-- WowUI.lua wraps these globals; stub them so dofile doesn't crash.
RaidWarningFrame    = {}
RaidNotice_AddMessage = function() end
PanelTemplates_TabResize   = function() end
PanelTemplates_SelectTab   = function() end
PanelTemplates_DeselectTab = function() end
DEFAULT_CHAT_FRAME  = { AddMessage = function() end }

-- UIParent: standard 1080p screen.
UIParent = {}
function UIParent:GetRight() return 1920 end
function UIParent:GetTop()   return 1080 end
function UIParent:GetLeft()  return 0    end
function UIParent:GetBottom() return 0   end

dofile("Core/WowUI.lua")

-- ── Mock frame builder ──────────────────────────────────────────────────────
-- Creates a frame positioned at (left, top) with the given width and height.
-- Records the last SetPoint call in frame.lastX / frame.lastY.
-- frame.setPointCalled is true if SetPoint was ever called.

local function makeFrame(left, top, width, height)
    local fr = {
        _left   = left,
        _top    = top,
        _right  = left + width,
        _bottom = top  - height,
        lastX   = nil,
        lastY   = nil,
        setPointCalled = false,
    }
    function fr:GetLeft()   return self._left   end
    function fr:GetRight()  return self._right  end
    function fr:GetTop()    return self._top    end
    function fr:GetBottom() return self._bottom end
    function fr:ClearAllPoints() end
    function fr:SetPoint(_, _, _, x, y)
        self.setPointCalled = true
        self.lastX = x
        self.lastY = y
    end
    return fr
end

-- ── Test helpers ────────────────────────────────────────────────────────────

local pass, fail = 0, 0

local function assert_eq(label, expected, got)
    if expected == got then
        pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected %s, got %s",
            label, tostring(expected), tostring(got)))
    end
end

local function assert_false(label, got)
    if got == false or got == nil then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected false/nil, got %s", label, tostring(got)))
    end
end

-- ── Tests ───────────────────────────────────────────────────────────────────

-- 1. Frame fully on-screen: no SetPoint call.
do
    local fr = makeFrame(100, 800, 400, 300)
    -- left=100, right=500, top=800, bottom=500 — all within 1920×1080
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_false("on_screen: SetPoint not called", fr.setPointCalled)
end

-- 2. Frame off the right edge: shifted left.
do
    local fr = makeFrame(1600, 800, 400, 300)
    -- right=2000 > 1920 → dx = 1920-2000 = -80 → new left = 1520
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_right: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_right: x", 1520, fr.lastX)
    assert_eq("off_right: y unchanged", 800, fr.lastY)
end

-- 3. Frame off the left edge: shifted right.
do
    local fr = makeFrame(-50, 800, 400, 300)
    -- left=-50 < 0 → dx = 50 → new left = 0
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_left: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_left: x", 0, fr.lastX)
    assert_eq("off_left: y unchanged", 800, fr.lastY)
end

-- 4. Frame off the top edge: shifted down.
do
    local fr = makeFrame(100, 1200, 400, 300)
    -- top=1200 > 1080 → dy = 1080-1200 = -120 → new top = 1080
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_top: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_top: x unchanged", 100, fr.lastX)
    assert_eq("off_top: y", 1080, fr.lastY)
end

-- 5. Frame off the bottom edge: shifted up.
do
    local fr = makeFrame(100, 100, 400, 300)
    -- bottom = 100-300 = -200 < 0 → dy = 200 → new top = 300
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_bottom: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_bottom: x unchanged", 100, fr.lastX)
    assert_eq("off_bottom: y", 300, fr.lastY)
end

-- 6. Frame off both right and bottom edges: both axes corrected.
do
    local fr = makeFrame(1700, 200, 400, 300)
    -- right=2100>1920 → dx=-180; left+dx=1520≥0 so no left override
    -- bottom=200-300=-100<0 → dy=100 → new top=300
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_right_bottom: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_right_bottom: x", 1520, fr.lastX)
    assert_eq("off_right_bottom: y", 300,  fr.lastY)
end

-- 7. Frame wider than screen: left edge wins.
do
    local fr = makeFrame(-100, 800, 2500, 300)
    -- right=2400>1920 → dx=1920-2400=-480; left+dx=-100+(-480)=-580<0 → dx=-left=100
    -- new left = 0 (left edge pinned)
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("wider_than_screen: setPointCalled", true, fr.setPointCalled)
    assert_eq("wider_than_screen: x", 0, fr.lastX)
    assert_eq("wider_than_screen: y unchanged", 800, fr.lastY)
end

-- 8. Frame with nil GetLeft (not yet laid out): no-op, no error.
do
    local fr = makeFrame(100, 800, 400, 300)
    fr.GetLeft = function() return nil end
    local ok = pcall(SocialQuestWowUI.ClampFrameToScreen, fr)
    assert_eq("nil_getleft: no error", true, ok)
    assert_false("nil_getleft: SetPoint not called", fr.setPointCalled)
end

-- ── Results ─────────────────────────────────────────────────────────────────

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
```

- [ ] **Step 2: Run the tests — expect failure**

```
cd "D:\Projects\Wow Addons\Social-Quest"
lua tests/WowUI_test.lua
```

Expected: `attempt to call a nil value (field 'ClampFrameToScreen')` or similar — `ClampFrameToScreen` does not exist yet.

---

## Task 2: Implement ClampFrameToScreen — make tests pass

**Files:**
- Modify: `Core/WowUI.lua` (append after line 39)

**Context:** `Core/WowUI.lua` currently ends at line 39 with `SocialQuestWowUI.AddChatMessage`. Append the new function after the final closing `end`. The function reads actual rendered frame edges (post-`SetPoint`) using WoW's `GetLeft/Right/Top/Bottom` — same coordinate space as `UIParent:GetRight/Top` so no scale math is needed. The two-pass X and two-pass Y structure handles all four edges; left-edge and top-edge take priority when a frame is wider/taller than the screen.

- [ ] **Step 3: Append `ClampFrameToScreen` to `Core/WowUI.lua`**

Add this block at the very end of `Core/WowUI.lua` (after the `AddChatMessage` function):

```lua
-- Nudges `frame` the minimum amount needed to be fully within the visible
-- UI area. Called once at open time — not a persistent clamp.
-- Safe to call when no saved position exists; no-op if frame is already on-screen.
-- Uses GetLeft/Right/Top/Bottom directly (same coordinate space as UIParent
-- GetRight/Top) — no scale math required.
function SocialQuestWowUI.ClampFrameToScreen(frame)
    local left   = frame:GetLeft()
    local right  = frame:GetRight()
    local top    = frame:GetTop()
    local bottom = frame:GetBottom()
    if not left then return end  -- frame not yet laid out; skip

    local sw = UIParent:GetRight()   -- screen width in UI coordinates
    local sh = UIParent:GetTop()     -- screen height in UI coordinates

    -- X axis: two-pass so left edge takes priority when frame is wider than screen.
    local dx = 0
    if right > sw    then dx = sw - right end  -- off right  → shift left  (dx negative)
    if left + dx < 0 then dx = -left      end  -- off left   → shift right (dx positive)

    -- Y axis: two-pass so top edge takes priority when frame is taller than screen.
    local dy = 0
    if bottom < 0      then dy = -bottom    end  -- off bottom → shift up   (dy positive)
    if top + dy > sh   then dy = sh - top   end  -- off top    → shift down (dy negative)

    if dx ~= 0 or dy ~= 0 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
    end
end
```

- [ ] **Step 4: Run the tests — expect all pass**

```
cd "D:\Projects\Wow Addons\Social-Quest"
lua tests/WowUI_test.lua
```

Expected output:
```
Results: 8 passed, 0 failed
```

- [ ] **Step 5: Also run the full suite to confirm no regressions**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua
```

Expected: all three suites report 0 failures.

- [ ] **Step 6: Commit**

```
git add Core/WowUI.lua tests/WowUI_test.lua
git commit -m "feat: add SQWowUI.ClampFrameToScreen utility with tests"
```

---

## Task 3: Integrate into the group window

**Files:**
- Modify: `UI/GroupFrame.lua` lines 588–597

**Context:** `applyFrameState(f)` is the single function that positions the group window. It is called from both `Toggle()` (user opens the window) and `RestoreAfterTransition()` (window auto-reopens after a loading screen). Adding the clamp call at the end of this function covers every open path. `local SQWowUI = SocialQuestWowUI` is already declared at line 20 of `GroupFrame.lua`.

Current `applyFrameState` (lines 588–597):
```lua
local function applyFrameState(f)
    local fs = SocialQuest.db.char.frameState
    if fs.frameWidth and fs.frameHeight then
        f:SetSize(fs.frameWidth, fs.frameHeight)
    end
    if fs.frameX and fs.frameY then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", fs.frameX, fs.frameY)
    end
end
```

- [ ] **Step 7: Add the clamp call at the end of `applyFrameState`**

Replace the function body so it reads:

```lua
local function applyFrameState(f)
    local fs = SocialQuest.db.char.frameState
    if fs.frameWidth and fs.frameHeight then
        f:SetSize(fs.frameWidth, fs.frameHeight)
    end
    if fs.frameX and fs.frameY then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", fs.frameX, fs.frameY)
    end
    SQWowUI.ClampFrameToScreen(f)
end
```

- [ ] **Step 8: Run the full test suite**

```
cd "D:\Projects\Wow Addons\Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua
```

Expected: all three suites report 0 failures.

- [ ] **Step 9: Commit**

```
git add UI/GroupFrame.lua
git commit -m "feat: clamp group window to screen on open"
```

---

## Task 4: Integrate into the diagnose console

**Files:**
- Modify: `SocialQuest.lua` lines 869–877

**Context:** The console window is created and positioned once inside the `/sq diagnose` handler. The restore geometry block reads `cs.x`, `cs.y`, `cs.width`, `cs.height` from AceDB and calls `SetPoint`. `local SQWowUI = SocialQuestWowUI` is already declared at line 39 of `SocialQuest.lua`.

Current console restore block (lines 869–877):
```lua
            do
                local cs = SocialQuest.db.char.frameState.console
                if cs.width and cs.height then f:SetSize(cs.width, cs.height) end
                f._sepFrac = cs.sepFrac or 0.38
                if cs.x and cs.y then
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cs.x, cs.y)
                end
            end
```

- [ ] **Step 10: Add the clamp call at the end of the console restore block**

Replace the block so it reads:

```lua
            do
                local cs = SocialQuest.db.char.frameState.console
                if cs.width and cs.height then f:SetSize(cs.width, cs.height) end
                f._sepFrac = cs.sepFrac or 0.38
                if cs.x and cs.y then
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cs.x, cs.y)
                end
                SQWowUI.ClampFrameToScreen(f)
            end
```

- [ ] **Step 11: Run the full test suite**

```
cd "D:\Projects\Wow Addons\Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua
```

Expected: all three suites report 0 failures.

- [ ] **Step 12: Commit**

```
git add SocialQuest.lua
git commit -m "feat: clamp diagnose console to screen on open"
```

---

## Task 5: Version bump and CLAUDE.md update

**Files:**
- Modify: `SocialQuest.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`, `SocialQuest_Mainline.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 13: Bump version to 2.18.23 in all four toc files**

```
cd "D:\Projects\Wow Addons\Social-Quest"
sed -i 's/## Version: 2.18.22/## Version: 2.18.23/' SocialQuest.toc SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc
```

Verify:
```
grep "Version:" SocialQuest.toc SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc
```

Expected: all four lines show `## Version: 2.18.23`.

- [ ] **Step 14: Add version entry to CLAUDE.md**

Insert this block immediately before the `### Version 2.18.22` line in `CLAUDE.md`:

```markdown
### Version 2.18.23 (April 2026)
- Feature: group window and `/sq diagnose` console no longer open off-screen.
  Added `SQWowUI.ClampFrameToScreen(frame)` to `Core/WowUI.lua`. Reads the
  frame's actual rendered edges after positioning and applies the minimum X/Y
  shift to bring all four edges within `UIParent` bounds. Called at the end of
  `applyFrameState()` in `UI/GroupFrame.lua` (covers both `Toggle()` and
  `RestoreAfterTransition()`) and at the end of the console restore block in
  `SocialQuest.lua`. No persistent `SetClampedToScreen` is used — correction
  fires once at open time only. Dragging partially off-screen during a session
  is still allowed; the window is nudged back on-screen at the next open.
```

- [ ] **Step 15: Run full test suite one final time**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua
```

Expected: all three suites report 0 failures.

- [ ] **Step 16: Commit**

```
git add SocialQuest.toc SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc CLAUDE.md
git commit -m "chore: bump version to 2.18.23 — window clamp-to-screen"
```
