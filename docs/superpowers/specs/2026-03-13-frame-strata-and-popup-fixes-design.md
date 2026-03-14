# Social Quest — Frame Strata, Escape Key, and Tooltip Fixes — Design Spec

**Date:** 2026-03-13
**Scope:** Three targeted bug fixes for `UI/GroupFrame.lua` and `UI/RowFactory.lua`.

---

## 1. Frame Z-Ordering (Strata Sandwich Fix)

### Problem

The Social Quest frame exhibits a "sandwich" rendering artifact when set to `MEDIUM` strata: other MEDIUM-strata widgets (objective tracker, bags, etc.) appear on top of the frame body, but underneath the tab buttons. Setting the frame to `HIGH` strata eliminates the sandwich but makes the frame always-on-top, covering talents, character panel, bags, and every other window regardless of focus. Neither behavior is correct.

### Root Cause

`TabButtonTemplate` explicitly sets the created button's strata to `HIGH`, overriding the parent frame's inherited strata. When the main frame is at `MEDIUM`:

- Frame body: `MEDIUM` strata → can be below other `MEDIUM` frames with higher frame levels
- Tab buttons: `HIGH` strata (set by template) → always above all `MEDIUM` frames

This produces the sandwich: other `MEDIUM` widgets render above the frame body but below the tabs.

A secondary issue is ordering within `Toggle()`: `frame:Raise()` is currently called *before* `self:Refresh()`. `Refresh()` creates new child frames (content rows). Moving `Raise()` to after `Refresh()` ensures it runs last, so any stale frame level ordering from a previous show/hide cycle is corrected after all content frames exist. (In the modern engine, child frame levels recalculate dynamically from the parent; the ordering change is still best practice for clarity and correctness.)

### Solution

**`UI/GroupFrame.lua` — `createFrame()`:**

1. Change `f:SetFrameStrata("HIGH")` → `f:SetFrameStrata("MEDIUM")`. Standard strata for addon windows that should participate in normal WoW focus ordering.

2. After `PanelTemplates_TabResize(p.tab, 0, 120, 120)`, add:
   ```lua
   p.tab:SetFrameStrata("MEDIUM")
   ```
   This overrides the `HIGH` strata that `TabButtonTemplate` sets, bringing tabs in line with the frame body. The sandwich is eliminated because both body and tabs are now in the same strata tier.

3. Add to the frame after the existing drag scripts:
   ```lua
   f:SetScript("OnMouseDown", function(self) self:Raise() end)
   ```
   Any mouse interaction (click, drag start) calls `Raise()`, bringing the frame to the front within `MEDIUM` strata. This is the standard WoW addon window pattern. Other windows (talents, bags) also call `Raise()` when interacted with, so they naturally go above Social Quest; clicking Social Quest again brings it back.

   Because `OnMouseDown` fires on every button-press (including drag gestures), the explicit `self:Raise()` inside the existing `OnDragStart` script is now redundant. Remove it from `OnDragStart`, leaving only `self:StartMoving()`:
   ```lua
   -- Before:
   f:SetScript("OnDragStart", function(self) self:StartMoving(); self:Raise() end)
   -- After:
   f:SetScript("OnDragStart", function(self) self:StartMoving() end)
   ```

   **Note:** `PanelTemplates_SelectTab` and `PanelTemplates_DeselectTab` (called in `Refresh()`) only toggle the button's disabled state and swap textures — they do not reset frame strata. The `MEDIUM` strata set on each tab in step 2 will persist across tab selection changes.

   **Note on event bubbling:** WoW script events do not bubble through the widget hierarchy. Clicking a tab button will not fire `f`'s `OnMouseDown`. To ensure clicking a tab also raises the frame, add `OnMouseDown → Raise()` to each tab inside the creation loop in step 2 (alongside the strata reset):
   ```lua
   p.tab:SetFrameStrata("MEDIUM")
   p.tab:SetScript("OnMouseDown", function() f:Raise() end)
   ```
   `f` is in scope here because `makeTab` is defined as a closure inside `createFrame()`. Using `f` directly is preferred over the module-level `frame` variable since it avoids a dependency on the outer scope during frame construction.

**`UI/GroupFrame.lua` — `Toggle()`:**

4. Move `frame:Raise()` to **after** `self:Refresh()`:
   ```lua
   -- Before (current):
   frame:Show()
   frame:Raise()
   ...
   self:Refresh()

   -- After (correct):
   frame:Show()
   ...
   self:Refresh()
   frame:Raise()
   ```
   Ensures all content frames created in `Refresh()` are part of the hierarchy when `Raise()` is called, so the entire frame tree (body, tabs, scroll content, rows) is raised together.

---

## 2. Escape Key Does Not Close the Wowhead URL Popup

### Problem

Pressing Escape while the Wowhead URL popup is open does not close it. The popup is registered in `UISpecialFrames` (which should cause Escape to hide it), but the EditBox has focus when the popup opens — and the EditBox's default `OnEscapePressed` handler calls `ClearFocus()` and **consumes the key event**, preventing it from reaching `UISpecialFrames`. The result is that the first Escape press only clears focus; only a second Escape press (with no EditBox focus) would close the popup.

### Solution

**`UI/GroupFrame.lua` — `createUrlPopup()`:**

Add to the EditBox `eb` after its other setup:
```lua
eb:SetScript("OnEscapePressed", function() p:Hide() end)
```

`p` is the local popup frame created in `createUrlPopup()` — the closure captures it directly. When Escape is pressed while the EditBox has focus, the popup is hidden immediately with a single keypress. When the EditBox does not have focus, the existing `UISpecialFrames` path handles Escape normally.

---

## 3. Tooltip on the Wowhead `[?]` Button

### Problem

The `[?]` link button in quest rows has no tooltip. Users cannot tell what it does without clicking it.

### Solution

**`UI/RowFactory.lua` — `AddQuestRow()`:**

Add `OnEnter` and `OnLeave` handlers to `linkBtn` after the existing `OnClick` script:
```lua
linkBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Click here to copy the wowhead quest url", 1, 1, 1)
    GameTooltip:Show()
end)
linkBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
```

Uses the standard `GameTooltip` global (available throughout the WoW UI). `ANCHOR_RIGHT` positions the tooltip to the right of the button, which is the least likely direction to be clipped by the frame edge. The text is rendered in white (`1, 1, 1`) to match WoW's standard informational tooltip style.

---

## Summary

| # | Issue | Root Cause | Fix | Files |
|---|-------|-----------|-----|-------|
| 1 | Sandwich / always-on-top | `TabButtonTemplate` forces `HIGH` strata on tabs; `Raise()` called before content exists | `MEDIUM` strata for frame; `MEDIUM` strata + `OnMouseDown → Raise()` for tabs; `OnMouseDown → Raise()` on frame; remove redundant raise from `OnDragStart`; move `Raise()` after `Refresh()` | `UI/GroupFrame.lua` |
| 2 | Escape key swallowed by EditBox | EditBox `OnEscapePressed` consumes keypress before `UISpecialFrames` sees it | Add `OnEscapePressed → p:Hide()` to EditBox | `UI/GroupFrame.lua` |
| 3 | No tooltip on `[?]` button | Not implemented | `OnEnter`/`OnLeave` with `GameTooltip` | `UI/RowFactory.lua` |
