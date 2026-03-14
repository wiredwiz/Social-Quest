# Frame Strata, Escape Key, and Tooltip Fixes — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Social Quest frame z-ordering sandwich bug, make Escape close the Wowhead URL popup on the first keypress, and add a tooltip to the `[?]` Wowhead button.

**Architecture:** Three targeted edits across two files. No new files. No new abstractions. Each change is 1–5 lines.

**Tech Stack:** WoW TBC Anniversary Lua addon (Interface 20505, modern Shadowlands+ client engine). No test framework — verification is in-game after `/reload`.

**Spec:** `D:\Projects\Wow Addons\Social-Quest\docs\superpowers\specs\2026-03-13-frame-strata-and-popup-fixes-design.md`

---

## File Map

| File | What changes |
|------|-------------|
| `UI/GroupFrame.lua` | Task 1: frame strata → MEDIUM, remove redundant Raise from OnDragStart, add OnMouseDown → Raise to frame and tabs, move Raise after Refresh in Toggle. Task 2: add OnEscapePressed to URL popup EditBox. |
| `UI/RowFactory.lua` | Task 3: add OnEnter/OnLeave tooltip to the `[?]` link button. |

---

## Chunk 1: GroupFrame and RowFactory changes

### Task 1: Fix frame strata and focus ordering

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\GroupFrame.lua`

**Background for implementer:**
`TabButtonTemplate` hardcodes `HIGH` strata on every tab button it creates, overriding the parent frame's strata. When the main frame is at `MEDIUM`, this causes a sandwich: other MEDIUM widgets appear above the frame body but below the tabs. The fix is to set `MEDIUM` strata on both the frame and each tab button after creation. Additionally, `OnMouseDown` → `Raise()` must be attached to the frame and each tab (WoW does not bubble script events through the widget hierarchy, so clicking a tab does NOT fire the parent frame's `OnMouseDown`). Finally, `frame:Raise()` in `Toggle()` must move to after `self:Refresh()` so it runs after all content rows exist.

- [ ] **Step 1: Change frame strata from HIGH to MEDIUM**

In `createFrame()`, line 90:
```lua
-- Before:
f:SetFrameStrata("HIGH")
-- After:
f:SetFrameStrata("MEDIUM")
```

- [ ] **Step 2: Remove the redundant Raise() from OnDragStart**

`OnMouseDown` (added in the next step) fires before drag gestures, making the `Raise()` in `OnDragStart` redundant. In `createFrame()`, line 94:
```lua
-- Before:
f:SetScript("OnDragStart", function(self) self:StartMoving(); self:Raise() end)
-- After:
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
```

- [ ] **Step 3: Add OnMouseDown → Raise() to the main frame**

Add immediately after the `OnDragStop` line (currently line 95). This ensures any click anywhere on the frame body brings it to the front within MEDIUM strata:
```lua
f:SetScript("OnDragStop",  f.StopMovingOrSizing)   -- already exists; line 95
f:SetScript("OnMouseDown", function(self) self:Raise() end)   -- NEW: insert after line 95
```

- [ ] **Step 4: Reset tab strata and add OnMouseDown → Raise() to each tab**

In `createFrame()`, the tab creation loop (currently lines 112–115):
```lua
-- Before:
for _, p in ipairs(providers) do
    p.tab = makeTab(p.id, p.module:GetLabel(), p.offsetX)
    PanelTemplates_TabResize(p.tab, 0, 120, 120)
end

-- After:
for _, p in ipairs(providers) do
    p.tab = makeTab(p.id, p.module:GetLabel(), p.offsetX)
    PanelTemplates_TabResize(p.tab, 0, 120, 120)
    p.tab:SetFrameStrata("MEDIUM")
    p.tab:SetScript("OnMouseDown", function() f:Raise() end)
end
```

Note: `f` is the local frame variable in `createFrame()`. It is in scope here because the `for` loop runs inside `createFrame()`. Do NOT use the module-level `frame` variable — that is nil at creation time.

- [ ] **Step 5: Move frame:Raise() to after self:Refresh() in Toggle()**

In `SocialQuestGroupFrame:Toggle()` (currently lines 154–171):
```lua
-- Before:
    else
        frame:Show()
        frame:Raise()
        -- Rebuild the quest cache on every open so IsQuestWatched state is
        -- current.  The initial PLAYER_LOGIN rebuild fires before watch state
        -- is fully set up, causing isTracked to be stale on first open.
        if SocialQuest.AQL and SocialQuest.AQL.QuestCache then
            SocialQuest.AQL.QuestCache:Rebuild()
        end
        self:Refresh()
    end

-- After:
    else
        frame:Show()
        -- Rebuild the quest cache on every open so IsQuestWatched state is
        -- current.  The initial PLAYER_LOGIN rebuild fires before watch state
        -- is fully set up, causing isTracked to be stale on first open.
        if SocialQuest.AQL and SocialQuest.AQL.QuestCache then
            SocialQuest.AQL.QuestCache:Rebuild()
        end
        self:Refresh()
        frame:Raise()   -- after Refresh so all content rows exist when raised
    end
```

- [ ] **Step 6: Verify in-game**

`/reload` in WoW. Open the Social Quest frame with `/sq`.

Expected behavior:
- Open bags, talents, character sheet, or any other game window — those windows should appear **above** Social Quest. ✓
- Click the Social Quest frame (title bar, body, or any tab) — it should come back to the **foreground**. ✓
- Drag the Social Quest frame across bags/bags slots/minimap — no widgets should appear above the frame body while below the tabs. The frame body and tabs should stay at the same z-order. ✓
- Social Quest should NOT always be on top when you click away from it. ✓

- [ ] **Step 7: Commit**

```bash
cd "D:\Projects\Wow Addons\Social-Quest"
git add UI/GroupFrame.lua
git commit -m "fix: MEDIUM strata + OnMouseDown raise eliminates frame z-order sandwich"
```

---

### Task 2: Fix Escape key not closing the Wowhead URL popup

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\GroupFrame.lua`

**Background for implementer:**
When the popup opens, `ShowWowheadUrl` calls `urlPopup.editBox:SetFocus()`. With focus, the EditBox intercepts the Escape keypress: its default handler calls `ClearFocus()` and **consumes** the event, so `UISpecialFrames` never sees it. A second Escape then closes the popup via `UISpecialFrames`. The fix is a one-line `OnEscapePressed` handler that hides the popup immediately.

- [ ] **Step 1: Add OnEscapePressed to the EditBox in createUrlPopup()**

In `createUrlPopup()`, immediately after `eb:SetFontObject("ChatFontNormal")` (currently line 45), insert this single new line:
```lua
eb:SetScript("OnEscapePressed", function() p:Hide() end)
```

`p` is the local popup frame variable in `createUrlPopup()`. The closure captures `p` directly — this is correct and safe. The handler works both when the EditBox has focus (immediate hide on first Escape) and when it does not (the existing `UISpecialFrames` path handles that case unchanged).

- [ ] **Step 2: Verify in-game**

`/reload`. Click the `[?]` button on any quest row to open the Wowhead URL popup.

Expected behavior:
- URL is pre-selected in the EditBox. ✓
- Press Escape **once** — popup closes immediately. ✓
- Reopen the popup, click somewhere on the popup frame (outside the EditBox) to remove EditBox focus, then press Escape — popup still closes. ✓

- [ ] **Step 3: Commit**

```bash
cd "D:\Projects\Wow Addons\Social-Quest"
git add UI/GroupFrame.lua
git commit -m "fix: escape key closes wowhead url popup on first keypress"
```

---

### Task 3: Add tooltip to the [?] Wowhead button

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\RowFactory.lua`

**Background for implementer:**
The `[?]` button in each quest row has no tooltip. Users cannot tell what it does without clicking. Standard WoW tooltip pattern uses `GameTooltip:SetOwner` / `SetText` / `Show` in `OnEnter` and `GameTooltip:Hide` in `OnLeave`.

- [ ] **Step 1: Add OnEnter and OnLeave to linkBtn in AddQuestRow()**

In `RowFactory.AddQuestRow()`, after the `linkBtn:SetScript("OnClick", ...)` block (currently lines 98–100), add:
```lua
    linkBtn:SetScript("OnClick", function()
        SocialQuestGroupFrame.ShowWowheadUrl(questEntry.questID)
    end)
    linkBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click here to copy the wowhead quest url", 1, 1, 1)
        GameTooltip:Show()
    end)
    linkBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
```

`ANCHOR_RIGHT` places the tooltip to the right of the button. `1, 1, 1` is white — WoW's standard color for informational tooltip body text. `GameTooltip` is a global available throughout the WoW UI.

- [ ] **Step 2: Verify in-game**

`/reload`. Open the Social Quest frame. Hover over any `[?]` button.

Expected behavior:
- A tooltip appears to the right of the button with the text "Click here to copy the wowhead quest url". ✓
- Moving the mouse away hides the tooltip. ✓
- Clicking the button still opens the Wowhead URL popup normally. ✓

- [ ] **Step 3: Commit**

```bash
cd "D:\Projects\Wow Addons\Social-Quest"
git add UI/RowFactory.lua
git commit -m "feat: add tooltip to wowhead url button"
```
