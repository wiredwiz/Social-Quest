# Scroll Position Memory — Design Spec

## Overview

When `GroupFrame:Refresh()` rebuilds the quest list, the scroll position resets to the top. This interrupts the user mid-read on every quest progress update. The fix preserves scroll position across rebuilds while still resetting to the top on intentional navigation (tab switches, first open).

---

## Problem

`GroupFrame:Refresh()` always calls `frame.scrollFrame:SetVerticalScroll(0)` before rebuilding. In addition, replacing the scroll child frame via `SetScrollChild(newContent)` may cause WoW to clamp the current scroll to 0 because the new content frame starts at height 1 before rendering. Both must be addressed.

---

## Approach

Per-tab scroll memory stored in a module-level local table. Two new locals drive the logic:

- `tabScrollPositions` — stores the last known scroll offset for each tab ID
- `lastRenderedTab` — tracks which tab was rendered last; distinguishes tab switches from data refreshes

`Refresh()` uses the exact condition `if activeID == lastRenderedTab then` to choose a branch:

- **Same tab** (`activeID == lastRenderedTab`) — data refresh, resize, zone collapse/expand, or frame reopen: Read `GetVerticalScroll()`, save it into `tabScrollPositions[activeID]`, then restore it after the content height is set. Net effect: scroll position is unchanged.
- **Different tab** (`activeID ~= lastRenderedTab`) — tab switch *or* first render (when `lastRenderedTab` is `nil`, `nil ~= activeID` is true): Set `lastRenderedTab = activeID` first (at the top of this branch). Then restore `tabScrollPositions[activeID] or 0` (the remembered position for that tab, defaulting to 0 on first visit or after `/reload`). This single branch covers both the first-render and tab-switch cases.

The tab click handler saves the *outgoing* tab's scroll position before overwriting `activeTab`. The outgoing tab ID is read from `SocialQuest.db.profile.frameState.activeTab` before it is overwritten with the new tab's ID. Concretely:

```lua
local outgoingID = SocialQuest.db.profile.frameState.activeTab or "shared"
tabScrollPositions[outgoingID] = frame.scrollFrame:GetVerticalScroll()
SocialQuest.db.profile.frameState.activeTab = id   -- overwrite happens here
SocialQuestGroupFrame:Refresh()
```

**Important:** `frame` here is the module-level upvalue, **not** the local `f` inside `createFrame()`. `createFrame()` assigns `f = CreateFrame(...)` and returns it; the caller (`Toggle()`) then assigns `frame = createFrame()`. By the time any click handler fires, `frame` is non-nil. The handler must close over the module-level `frame` (which it does naturally, since `frame` is in scope from the module's upvalue chain). Do not substitute `f`.

Scroll is restored *after* `SetHeight(totalHeight)` so WoW's scroll range is correct before the value is applied — preventing premature clamping. The `SetVerticalScroll(scrollToRestore)` call at the end of `Refresh()` is required even on the same-tab path, because `SetScrollChild(newContent)` (called earlier with a height-1 frame) may have already clamped the scroll offset to 0. The restore call undoes that clamp — it is not a no-op.

**Zone collapse/expand** (`ExpandAll`, `CollapseAll`, `ToggleZone`) all call `Refresh()` directly without changing the active tab. They take the same-tab path and preserve the current scroll position. This is intentional — the user clicked a zone header in the current view and should remain roughly in place.

---

## State Lifecycle

| Event | `tabScrollPositions` update | `lastRenderedTab` update |
|---|---|---|
| First render | No update (reads nil → 0); takes tab-switch path since `lastRenderedTab` is nil | Set to activeID |
| Data refresh (via `RequestRefresh()`) | Saved from `GetVerticalScroll()` | No change |
| Track/untrack quest (shift-click in MineTab) | Saved from `GetVerticalScroll()` (direct `Refresh()` call, same-tab path) | No change |
| Tab switch (click) | Outgoing tab saved in click handler before `activeTab` is overwritten | Set to new tab in `Refresh()` |
| Zone collapse/expand | Saved from `GetVerticalScroll()` (same-tab path) | No change |
| Frame reopen (via `Toggle()`) | Saved from `GetVerticalScroll()` (scroll frame persists, last value retained — see note) | No change |
| `/reload` | Reset to `{}` and `nil` (module locals re-initialized) | Reset to `nil` |

Frame close/reopen: `RequestRefresh()` is guarded by `frame:IsShown()` so rebuilds via that path do not happen while the frame is hidden. `MineTab.lua` calls `Refresh()` directly (not via `RequestRefresh()`), but those calls are triggered only by user interaction with the visible frame. In both cases, when the frame reopens, `Toggle()` calls `Refresh()`. `lastRenderedTab` still matches the active tab (set during the last visible render), so the same-tab path runs.

**WoW scroll frame behavior (Interface 20505 / TBC Anniversary):** `ScrollFrame:Hide()` and `ScrollFrame:Show()` do not reset `GetVerticalScroll()`. The scroll offset is a persistent property of the scroll frame in WoW's UI engine. Therefore, when the frame is reopened, `GetVerticalScroll()` returns the value from the last time the frame was visible, and the same-tab path correctly saves and restores it. Position is remembered within the play session but not across `/reload`. **Failure mode if this behavior does not hold:** `GetVerticalScroll()` would return 0 on reopen; the same-tab path would save 0 and restore 0. This is equivalent to the current behavior (explicit reset to top) — a graceful degradation, not a regression.

`activeTab` is only written from the `makeTab` click handler (confirmed by searching for writes to `frameState.activeTab` across all source files — only one write site exists). The click handler requires an interactable, visible frame. No code path modifies `activeTab` while the frame is hidden, so `lastRenderedTab` will always match `activeTab` on reopen. Any future code that programmatically switches the active tab while the frame is hidden must also update `lastRenderedTab` to maintain this invariant.

**Early-return guard:** `Refresh()` returns early if `activeProvider` is not found (an unreachable condition with current tab IDs). The scroll-determining block (step 3 in Files Changed) is placed *after* the provider early-return guard. If the early return fires, scroll state is left completely unchanged — `tabScrollPositions` and `lastRenderedTab` are not modified, and no `SetVerticalScroll` call is made.

The click handler modification is inside `makeTab()`, which is a nested local function inside `createFrame()`.

---

## Files Changed

**`UI/GroupFrame.lua`** — only file modified.

Changes:
1. Add `local tabScrollPositions = {}` and `local lastRenderedTab = nil` at module scope (alongside existing `local frame`, `local refreshPending`, etc.)
2. Remove `frame.scrollFrame:SetVerticalScroll(0)` from `Refresh()`
3. In `Refresh()`, *after* the `activeProvider` early-return guard: determine `scrollToRestore` via the same-tab vs. tab-switch branch described above; update `lastRenderedTab` on switch
4. In `Refresh()`, after `frame.content:SetHeight(...)`: call `frame.scrollFrame:SetVerticalScroll(scrollToRestore)`
5. In `makeTab()`'s click handler (inside `createFrame()`): read the outgoing tab ID from `SocialQuest.db.profile.frameState.activeTab` *before* overwriting it, save its scroll position into `tabScrollPositions`, then overwrite `activeTab` and call `Refresh()`

No changes to `RowFactory`, tab providers, `Communications`, `GroupData`, or any other module.

---

## Explicitly Out of Scope

- Persisting scroll position across `/reload` (session memory is sufficient)
- Zone-header anchor restore (Approach 3 — deferred; see memory note)
- Any changes to how content is rendered or how rows are built
