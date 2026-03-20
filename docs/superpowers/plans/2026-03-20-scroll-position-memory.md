# Scroll Position Memory Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve per-tab scroll position across `GroupFrame:Refresh()` rebuilds so the display does not jump to the top on every quest update.

**Architecture:** Two module-level locals (`tabScrollPositions`, `lastRenderedTab`) track the last known scroll offset for each tab and detect tab-switch vs. data-refresh calls. `activeID` is resolved at the top of `Refresh()` so the scroll can be saved to `tabScrollPositions` before `SetScrollChild()` clamps it to 0. After the content is rebuilt and its height is set, `SetVerticalScroll` restores the saved offset. The tab click handler saves the outgoing tab's position before switching. All changes are confined to `UI/GroupFrame.lua`.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), Ace3 framework. No automated test runner — verification is done in-game.

---

## Chunk 1: Implementation

### Task 1: Implement per-tab scroll position memory

**Files:**
- Modify: `UI/GroupFrame.lua:8-11` (add two locals at module scope)
- Modify: `UI/GroupFrame.lua:122-131` (makeTab click handler — save outgoing tab scroll)
- Modify: `UI/GroupFrame.lua:208-252` (Refresh — remove reset, move activeID to top, add save/restore)

---

- [ ] **Step 1: Read the file to confirm current state**

Open `UI/GroupFrame.lua` and confirm:
- Lines 8–11 contain `local frame = nil`, `local refreshPending = false`, `local urlPopup = nil`, and `local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")`
- Line 210 contains `frame.scrollFrame:SetVerticalScroll(0)`
- Line 222 contains `local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"` (inside `Refresh()`)
- Lines 122–131 contain the `makeTab` local function with its `OnClick` handler
- Lines 250–251 contain the `Render` call and `SetHeight` call

---

- [ ] **Step 2: Add two module-level locals after the existing module locals**

In `UI/GroupFrame.lua`, the current module-local block (lines 8–11) reads:

```lua
local frame          = nil
local refreshPending = false
local urlPopup       = nil
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

Insert two new locals after `local urlPopup = nil` and before `local L = ...`:

```lua
local frame          = nil
local refreshPending = false
local urlPopup       = nil
local tabScrollPositions = {}  -- [tabID] = last known vertical scroll offset
local lastRenderedTab    = nil -- set to activeID after each render; nil on first run / reload
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

---

- [ ] **Step 3: Rewrite Refresh() — move activeID to top, remove reset, add scroll save before SetScrollChild**

The current start of `Refresh()` (lines 208–219) reads:

```lua
function SocialQuestGroupFrame:Refresh()
    if not frame then return end
    frame.scrollFrame:SetVerticalScroll(0)

    -- Recreate content child (GetChildren does not return FontStrings; hiding is
    -- the only clean way to discard old rows without leaking them).
    local contentW = math.floor(frame:GetWidth() - 40)
    RowFactory.SetContentWidth(contentW)
    if frame.content then frame.content:Hide() end
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(contentW, 1)
    frame.scrollFrame:SetScrollChild(frame.content)
```

Replace it with:

```lua
function SocialQuestGroupFrame:Refresh()
    if not frame then return end

    -- Resolve activeID early so the scroll save below can reference it before
    -- SetScrollChild() is called (SetScrollChild may clamp GetVerticalScroll to 0).
    local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"

    -- Save scroll position for same-tab refreshes BEFORE SetScrollChild can clamp it.
    -- Tab-switch paths save the outgoing tab's position in the click handler instead.
    if activeID == lastRenderedTab then
        tabScrollPositions[activeID] = frame.scrollFrame:GetVerticalScroll()
    end

    -- Recreate content child (GetChildren does not return FontStrings; hiding is
    -- the only clean way to discard old rows without leaking them).
    local contentW = math.floor(frame:GetWidth() - 40)
    RowFactory.SetContentWidth(contentW)
    if frame.content then frame.content:Hide() end
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(contentW, 1)
    frame.scrollFrame:SetScrollChild(frame.content)
```

---

- [ ] **Step 4: Remove the now-redundant activeID declaration in the middle of Refresh()**

After the edit in Step 3, `activeID` is declared at the top of `Refresh()`. The original declaration inside the function body (line 222, now shifted slightly) still exists:

```lua
    local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"
```

Delete that line. `activeID` is already in scope from the top of the function.

---

- [ ] **Step 5: Add the scroll-restore decision block after the early-return guard**

Locate the early-return guard (now a few lines later due to Step 3's additions):

```lua
    if not activeProvider or not activeProvider.module then return end
```

Immediately after that line (before the tab-highlight loop), insert:

```lua
    -- Determine which scroll offset to restore after the rebuild.
    -- Same-tab path: the offset was saved before SetScrollChild above.
    -- Tab-switch / first-render path (lastRenderedTab is nil on first call):
    --   restore the remembered offset for the incoming tab (0 on first visit).
    local scrollToRestore
    if activeID == lastRenderedTab then
        scrollToRestore = tabScrollPositions[activeID] or 0
    else
        lastRenderedTab = activeID
        scrollToRestore = tabScrollPositions[activeID] or 0
    end
```

---

- [ ] **Step 6: Apply the scroll restore after SetHeight**

At the very end of `Refresh()`, after `frame.content:SetHeight(math.max(totalHeight, 10))`, add:

```lua
    frame.scrollFrame:SetVerticalScroll(scrollToRestore)
```

The tail of `Refresh()` should now read:

```lua
    -- Delegate rendering to the tab provider.
    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed)
    frame.content:SetHeight(math.max(totalHeight, 10))
    frame.scrollFrame:SetVerticalScroll(scrollToRestore)
end
```

---

- [ ] **Step 7: Update the makeTab click handler to save the outgoing tab's scroll**

In `createFrame()`, locate the `makeTab` local function. Its `OnClick` handler currently reads:

```lua
        tab:SetScript("OnClick", function()
            SocialQuest.db.profile.frameState.activeTab = id
            SocialQuestGroupFrame:Refresh()
        end)
```

Replace it with:

```lua
        tab:SetScript("OnClick", function()
            -- Save the outgoing tab's scroll position before activeTab is overwritten.
            -- frame is the module-level upvalue (not the local f); it is non-nil by the
            -- time any click fires.
            local outgoingID = SocialQuest.db.profile.frameState.activeTab or "shared"
            tabScrollPositions[outgoingID] = frame.scrollFrame:GetVerticalScroll()
            SocialQuest.db.profile.frameState.activeTab = id
            SocialQuestGroupFrame:Refresh()
        end)
```

---

- [ ] **Step 8: Verify the full Refresh() function looks correct**

After all edits, `Refresh()` should match this exactly:

```lua
function SocialQuestGroupFrame:Refresh()
    if not frame then return end

    -- Resolve activeID early so the scroll save below can reference it before
    -- SetScrollChild() is called (SetScrollChild may clamp GetVerticalScroll to 0).
    local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"

    -- Save scroll position for same-tab refreshes BEFORE SetScrollChild can clamp it.
    -- Tab-switch paths save the outgoing tab's position in the click handler instead.
    if activeID == lastRenderedTab then
        tabScrollPositions[activeID] = frame.scrollFrame:GetVerticalScroll()
    end

    -- Recreate content child (GetChildren does not return FontStrings; hiding is
    -- the only clean way to discard old rows without leaking them).
    local contentW = math.floor(frame:GetWidth() - 40)
    RowFactory.SetContentWidth(contentW)
    if frame.content then frame.content:Hide() end
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(contentW, 1)
    frame.scrollFrame:SetScrollChild(frame.content)

    -- Find active provider.
    local activeProvider
    for _, p in ipairs(providers) do
        if p.id == activeID then
            activeProvider = p
            break
        end
    end
    if not activeProvider or not activeProvider.module then return end

    -- Determine which scroll offset to restore after the rebuild.
    -- Same-tab path: the offset was saved before SetScrollChild above.
    -- Tab-switch / first-render path (lastRenderedTab is nil on first call):
    --   restore the remembered offset for the incoming tab (0 on first visit).
    local scrollToRestore
    if activeID == lastRenderedTab then
        scrollToRestore = tabScrollPositions[activeID] or 0
    else
        lastRenderedTab = activeID
        scrollToRestore = tabScrollPositions[activeID] or 0
    end

    -- Highlight active tab; deselect others.
    -- PanelTemplates_SelectTab disables the button (standard WoW: can't re-click active tab).
    -- PanelTemplates_DeselectTab re-enables inactive tabs.
    for _, p in ipairs(providers) do
        if p.tab then
            if p.id == activeID then
                PanelTemplates_SelectTab(p.tab)
            else
                PanelTemplates_DeselectTab(p.tab)
            end
        end
    end

    -- Per-tab collapsed zones subtable.
    local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
    local tabCollapsed   = collapsedZones[activeID] or {}

    -- Delegate rendering to the tab provider.
    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed)
    frame.content:SetHeight(math.max(totalHeight, 10))
    frame.scrollFrame:SetVerticalScroll(scrollToRestore)
end
```

---

- [ ] **Step 9: Commit the implementation**

```bash
git add "UI/GroupFrame.lua"
git commit -m "$(cat <<'EOF'
feat(GroupFrame): preserve per-tab scroll position across refreshes

Replaces the unconditional SetVerticalScroll(0) with per-tab scroll
memory. activeID is resolved before SetScrollChild so the scroll save
is not clamped. Data refreshes, resizes, zone toggles, and frame
reopens restore the user's last scroll offset. Tab switches restore
the remembered offset for the incoming tab (0 on first visit).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

- [ ] **Step 10: In-game verification — data refresh preserves scroll**

Load the addon in WoW (Interface 20505 / TBC Anniversary). Open the quest frame (`/sq`). Scroll down past several quests. Have a party member make quest progress (or trigger a rebuild by resizing the frame slightly). Confirm the scroll position does not jump to the top.

---

- [ ] **Step 11: In-game verification — tab switch resets to top on first visit, remembers on return**

With the quest frame open, scroll down on the Shared tab. Click the Mine tab — it should open at the top (first visit). Scroll down on Mine. Click Shared — it should return to the position you left it at. Click Mine — it should return to the Mine position.

---

- [ ] **Step 12: In-game verification — frame close/reopen remembers position**

Scroll down on any tab. Close the frame (click X or press Escape). Reopen (`/sq`). Confirm the scroll is where you left it.

---

- [ ] **Step 13: In-game verification — zone collapse preserves scroll**

Scroll to a zone in the middle of the list. Click its header to collapse it. Confirm the scroll position stays roughly in place (the collapsed zone shrinks, so some shift is expected, but the view should not jump to the top).

---

### Task 2: Update Claude.md and version

**Files:**
- Modify: `Claude.md`
- Modify: `SocialQuest.toc`

---

- [ ] **Step 1: Bump the version in SocialQuest.toc**

Today is 2026-03-20. Version 2.1.0 was the first change of this day. This is an additional same-day change, so increment the revision only: `2.1.0 → 2.1.1`.

In `SocialQuest.toc`, change:

```
## Version: 2.1.0
```

to:

```
## Version: 2.1.1
```

---

- [ ] **Step 2: Add version entry to Claude.md**

In `Claude.md`, add a new version entry under the Version History section, above the 2.1.0 entry:

```markdown
### Version 2.1.1 (March 2026 — Improvements branch)
- GroupFrame now preserves per-tab scroll position across rebuilds; no longer resets to top on quest updates
```

---

- [ ] **Step 3: Commit docs and version bump**

```bash
git add "Claude.md" "SocialQuest.toc"
git commit -m "$(cat <<'EOF'
chore: bump version to 2.1.1, update Claude.md

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
