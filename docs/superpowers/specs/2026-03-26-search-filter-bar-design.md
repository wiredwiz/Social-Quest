# Search/Filter Bar — Design Spec

## Goal

Add a persistent search box to the SocialQuest group window that filters the displayed quest list across all three tabs. Typing filters quests by title or chain title in real time; clearing or closing the window restores the full list.

## Context

The group window (Party, Shared, Mine tabs) can show many quests across multiple zones. Finding a specific quest requires scrolling. The search bar lets the player type a substring to narrow the list instantly.

---

## Layout

The search bar occupies a fixed **header strip** between the tab separator and the scrollable content area. It is always visible and does not scroll.

```
[Shared]  [Mine]  [Party]             ← tab buttons
──────────────────────────────────    ← separator
[ 🔍 Search...               ] [x]   ← EditBox (always visible)
[ Filter: Zone: Hellfire...  ] [x]   ← filter label (only when active)
┌──────────────────────────────────┐
│  ▸ Hellfire Peninsula            │  ← scrollable content
│    ...                           │
└──────────────────────────────────┘
```

The filter label row (zone/instance filter) moves from the scrollable content area into the fixed header strip, directly below the search bar. It is only shown when a zone or instance filter is active for the current tab. When hidden, the scroll frame anchors directly below the search bar. When shown, the scroll frame anchors below the filter label.

On every `Refresh()` call the scroll frame's anchor points are fully rebuilt: `ClearAllPoints()`, then `SetPoint("TOPLEFT", ...)` against whichever header element is currently the lowest visible one (filter label if shown, search bar if not), then `SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)` unchanged. Both points are always set explicitly so the scroll frame width is never undefined.

---

## Search Behavior

- **Scope:** all three tabs (Mine, Party, Shared).
- **State:** a single `searchText` string at `GroupFrame.lua` module scope. One box, one text value — all tabs filter against the same string.
- **Match:** case-insensitive plain substring match (`string.find(string.lower(title), string.lower(searchText), 1, true)`).
- **Targets:** quest title and chain title. Zone names and objective text are not searched.
- **Chain matching:** if the chain title matches, all steps in that chain are included. If the chain title does not match, individual steps are included only if their own title matches.
- **Empty zones:** a zone section is omitted entirely when none of its quests pass the filter.
- **Empty search:** when `searchText` is `""`, no filtering is applied — identical to current behavior.
- **Rebuild trigger:** `OnTextChanged` calls `RequestRefresh()`. The existing `refreshPending` debounce (one frame tick) batches rapid keystrokes into a single rebuild.
- **Expand/collapse header:** visibility is unchanged — the header row is shown whenever `#sortedZones > 0` after filtering, same as today. If search reduces the zone list to zero, the header is suppressed; otherwise it remains.

### filterTable assembly

In `GroupFrame:Refresh()`, a composite `filterTable` is assembled immediately before calling `Render()`:

```lua
local zoneFilter  = SocialQuestWindowFilter:GetActiveFilter(activeID)
local filterTable = nil
if zoneFilter or (searchText ~= "") then
    filterTable = {
        zone   = zoneFilter and zoneFilter.zone or nil,
        search = searchText ~= "" and searchText or nil,
    }
end
```

The existing `local filterTable = SocialQuestWindowFilter:GetActiveFilter(activeID)` line in `Refresh()` is deleted and replaced entirely by this block. This single table is passed as the `filterTable` argument to `Render()`, which forwards it unchanged to `BuildTree()`. `BuildTree` checks `filterTable.zone` (existing) and `filterTable.search` (new) independently.

Both filters apply when both fields are present (a quest must satisfy both to appear). **MineTab applies `filterTable.search` only — `filterTable.zone` continues to be ignored in MineTab, same as today.**

---

## Filter Label Migration

The filter label is removed from the tab `Render` methods and from `RowFactory`. Specifically:

- `PartyTab:Render` lines that call `SocialQuestWindowFilter:GetFilterLabel(tabId)` and `rowFactory.AddFilterHeader(...)` are deleted.
- `SharedTab:Render` has the same pattern and receives the same deletion.
- `RowFactory.AddFilterHeader` is deleted entirely (no remaining callers).
- MineTab never had a filter label and is unaffected.

GroupFrame becomes responsible for rendering the filter label in the fixed header area. In `Refresh()`, GroupFrame calls `SocialQuestWindowFilter:GetFilterLabel(activeID)`:
- Non-nil → show the filter label widget, set its text, reassign the dismiss button's `OnClick` script.
- Nil → hide the filter label widget.

**The dismiss button's `OnClick` script is reassigned on every `Refresh()` call** (not at widget creation time), so the closure always captures the current `activeID`. Since the widget is reused across tab switches, a closure captured at creation would always dismiss the initial tab (typically "shared"). The reassignment in `Refresh()` prevents this.

The dismiss callback: `SocialQuestWindowFilter:Dismiss(activeID)` then `RequestRefresh()` — same behavior as before, just initiated from GroupFrame instead of inside the content frame.

`GroupFrame:Refresh()` calls `SocialQuestWindowFilter:GetActiveFilter(activeID)` (for `filterTable`) and `SocialQuestWindowFilter:GetFilterLabel(activeID)` (for the header widget) separately. Both calls invoke the same internal `computeFilterState()` logic and will always agree — they cannot diverge.

---

## Widget Lifecycle

Both the search EditBox and the filter label widget are created **once** in `createFrame()` and reused for the lifetime of the frame. They are never recreated — only shown, hidden, and updated on each `Refresh()`.

**Search bar construction:**
- A `Frame` container anchored below the separator, full content width, height 24px.
- An `EditBox` inside the container: `AutoFocus = false`, `GameFontNormalSmall`, placeholder text `L["Search..."]`.
- A clear `Button` (`[x]`) at the right edge: `OnClick` sets `searchText = ""`, calls `editBox:SetText("")`, calls `editBox:ClearFocus()`, calls `RequestRefresh()`. Focus is cleared so the player is not left in a typing state after the clear.
- `OnTextChanged`: sets `searchText = self:GetText()`, calls `RequestRefresh()`.

**Filter label construction:**
- A `Frame` container anchored below the search bar, full content width, height `ROW_H`.
- A `FontString` for the label text (`GameFontNormalSmall`, grey/tan).
- A dismiss `Button` at the right edge.
- Initially hidden (`frame:Hide()`).

---

## Search Text Lifecycle

| Event | Behavior |
|---|---|
| User types | `searchText` updated, `RequestRefresh()` called |
| User clicks [x] | `searchText = ""`, EditBox text cleared, focus cleared, `RequestRefresh()` |
| Tab switch | Same `searchText` used; new tab's content filtered. EditBox retains keyboard focus if it had it — no `ClearFocus()` on tab switch. The EditBox lives on the main frame `f` and survives `Refresh()`; focus state is not affected by content frame recreation. |
| Zone filter dismissed | `RequestRefresh()` only — `searchText` unchanged |
| Window closed by user (X / Escape) | `searchText = ""`, EditBox cleared (`leavingWorld == false`) |
| Window closed by loading screen | `searchText` preserved (`leavingWorld == true`) |
| Window reopened after loading screen | EditBox repopulated from `searchText`; list filtered as before |

The `leavingWorld` guard already exists in `OnHide` for the `windowOpen` state; search text clearing is added to the same `if not leavingWorld then` block.

---

## Files Modified

| File | Change |
|---|---|
| `UI/GroupFrame.lua` | Add search bar + filter label to fixed header; dynamic scroll anchor in `Refresh()`; assemble composite `filterTable`; clear search in `OnHide` (guarded by `leavingWorld`) |
| `UI/Tabs/MineTab.lua` | Add `filterTable.search` check in `BuildTree` |
| `UI/Tabs/PartyTab.lua` | Add `filterTable.search` check in `BuildTree`; remove `GetFilterLabel` + `AddFilterHeader` calls from `Render` |
| `UI/Tabs/SharedTab.lua` | Same as PartyTab |
| `UI/RowFactory.lua` | Remove `AddFilterHeader` |
| `Locales/enUS.lua` | Add `["Search..."] = true` (AceLocale convention; key string is the display value) |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | Add `["Search..."]` translation in all 11 remaining locale files |

No new files. No protocol changes. No new config toggles.

---

## Constraints

- No protocol changes — search is purely local rendering.
- No persistence across sessions — search text is session-scoped (cleared on user-initiated window close).
- No minimum character threshold — filter applies from the first character.
- No regex or wildcard support — plain substring only.
- `AddFilterHeader` in RowFactory is removed; it has no remaining callers.
