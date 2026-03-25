# Zone & Instance Auto-Filter Design

*Feature Idea #5 from FeatureIdeas.md — March 2026*

---

## Overview

Adds automatic zone and instance filtering to the Party and Shared tabs of the SocialQuest group window. When a player enters a dungeon instance, the Party and Shared tabs optionally show only quests relevant to that instance. Outside of instances, an optional zone filter narrows the same tabs to the current open-world zone. Both behaviors are controlled by toggles in the config panel and default to sensible values (instance filter ON, zone filter OFF).

Toggling either setting while the SocialQuest window is open immediately resets the active filter state and refreshes the window content.

A dismissible filter label appears at the top of each affected tab when a filter is active. Dismissal is per-tab and resets when the player changes zones, closes the window, or toggles either filter setting.

---

## Goals

- Reduce visual noise in the Party and Shared tabs when inside a dungeon or raid instance.
- Optionally reduce noise in open-world zones for players who prefer focused views.
- Lay extensible groundwork for future filter types (quest type, level range, etc.) without over-engineering the current scope.

---

## Non-Goals

- No filter on the Mine tab in this version (signature updated for future compatibility only).
- No slash-command filter input or saved/named filters.
- No string parsing infrastructure — filters are Lua tables constructed programmatically.
- No per-character filter dismissal persistence (dismissal is session-local, resets on zone change, window close, or setting toggle).

---

## Architecture

### New File

**`UI/WindowFilter.lua`** (`SocialQuestWindowFilter`)

Owns all filter state and computation. Loaded in TOC between the tab providers and `UI/Options.lua`.

### Modified Files

| File | Change |
|------|--------|
| `Core/WowAPI.lua` | Add `GetRealZoneText()` and `IsInInstance()` wrappers |
| `SocialQuest.lua` | Add `window` defaults block; extend `OnPlayerEnteringWorld` |
| `UI/Options.lua` | Add "Social Quest Window" option group (order 9); debug moves to order 10 |
| `UI/RowFactory.lua` | Add `AddFilterHeader(contentFrame, y, label, onDismiss)` row type |
| `UI/Tabs/PartyTab.lua` | `BuildTree(filterTable)` and `Render(..., filterTable)` |
| `UI/Tabs/SharedTab.lua` | Same signature changes; filter applied in tree construction |
| `UI/Tabs/MineTab.lua` | `BuildTree(filterTable)` signature only; filterTable ignored |
| `UI/GroupFrame.lua` | Pass filterTable to Render; call Reset on Hide |
| `SocialQuest.toc` | Add `UI/WindowFilter.lua` before `UI/Options.lua` |

---

## Filter Module: SocialQuestWindowFilter

### State

```lua
local dismissed = {}    -- [tabId] = true when user has dismissed filter for that tab
```

### Public API

**`SocialQuestWindowFilter:GetActiveFilter(tabId)`**

Returns `{ zone = "Hellfire Ramparts" }` or `nil`. Called by GroupFrame; result passed to `Render()` then `BuildTree()`.

Priority:
1. `dismissed[tabId]` is true → return `nil`
2. `db.profile.window.autoFilterInstance` is true AND `SQWowAPI.IsInInstance()` indicates a real instance → return `{ zone = SQWowAPI.GetRealZoneText() }`
3. `db.profile.window.autoFilterZone` is true → return `{ zone = SQWowAPI.GetRealZoneText() }`
4. → return `nil`

`IsInInstance()` returns two values: `inInstance (bool), instanceType (string)`. Only treat as a real instance when `inInstance` is true and `instanceType` is not `"none"`.

**`SocialQuestWindowFilter:GetFilterLabel(tabId)`**

Returns a human-readable string or `nil`. Uses the same priority logic as `GetActiveFilter`. Called directly inside each tab's `Render()` — not by GroupFrame. Labels:
- Instance filter active: `"Instance: <zoneName>"`
- Zone filter active: `"Zone: <zoneName>"`

**Implementation note:** `GetActiveFilter` and `GetFilterLabel` both evaluate the same priority chain independently. To prevent the label diverging silently from the filter actually applied (e.g. if one is updated and the other is not), extract the shared logic into a private `computeFilterState()` helper that returns `{ filter={zone=...}, label="...", isInstance=bool }` or `nil`. Both public methods call this helper and project out what they need.

**`SocialQuestWindowFilter:Dismiss(tabId)`**

Sets `dismissed[tabId] = true`. Called when user clicks [x] on the filter header row.

**`SocialQuestWindowFilter:Reset()`**

Sets `dismissed = {}`. Called by:

- `SocialQuest:OnPlayerEnteringWorld` — after `zoneTransitionSuppressUntil` is set, as the next statement
- The GroupFrame `OnHide` script
- Each options toggle `set` callback (see Settings section)

---

## Data Flow

```
PLAYER_ENTERING_WORLD
  → zoneTransitionSuppressUntil = GetTime() + 3  (existing)
  → WindowFilter:Reset()                          (new, immediately after)
  → GroupFrame:RequestRefresh()                   (new, immediately after)

Options toggle changed (autoFilterInstance or autoFilterZone)
  → db.profile.window.<key> = value               (existing AceConfig set)
  → WindowFilter:Reset()                          (new)
  → GroupFrame:RequestRefresh()                   (new)

GroupFrame:Refresh()
  → filterTable = WindowFilter:GetActiveFilter(activeID)
  → provider:Render(contentFrame, rowFactory, tabCollapsed, filterTable)
      → filterLabel = WindowFilter:GetFilterLabel(tabId)  [inside Render]
      → if filterLabel: rowFactory.AddFilterHeader(..., onDismiss)
      → self:BuildTree(filterTable)
          → skip quests whose zone ≠ filterTable.zone

User clicks [x] on filter header
  → WindowFilter:Dismiss(tabId)
  → GroupFrame:Refresh()

Frame OnHide
  → WindowFilter:Reset()
```

---

## BuildTree Filtering

### PartyTab

In the `for questID in pairs(allQuestIDs)` loop, after resolving `zoneName`, before adding to the tree:

```lua
if filterTable and filterTable.zone and zoneName ~= filterTable.zone then
    -- skip this questID
end
```

### SharedTab

For chain groups: after resolving `zoneName` from the local player's quest info, before calling `ensureZone()`:

```lua
if filterTable and filterTable.zone and zoneName ~= filterTable.zone then
    -- skip this chain group
end
```

For standalone quest groups: after `SocialQuestTabUtils.GetZoneForQuestID(questID)`, same guard before `ensureZone()`.

### MineTab

No filter logic. Signature updated to `BuildTree(filterTable)` for future compatibility; filterTable is accepted and ignored.

---

## Filter Header Row (RowFactory)

`rowFactory.AddFilterHeader(contentFrame, y, label, onDismiss)`

Renders a slim row (same height as a zone header) at the top of the tab content:
- Left side: label text (e.g. `"Instance: Hellfire Ramparts"`) in a muted/informational color
- Right side: a small `[x]` button that calls `onDismiss()` when clicked

Returns the new `y` offset after the row (consistent with all other `AddXxx` return conventions).

---

## GroupFrame Changes

In `Refresh()`, before calling `provider.module:Render()`:

```lua
local filterTable = SocialQuestWindowFilter:GetActiveFilter(activeID)
local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed, filterTable)
```

In `createFrame()`, before the function returns `f`, register the OnHide script:

```lua
f:SetScript("OnHide", function()
    SocialQuestWindowFilter:Reset()
end)
```

---

## Render Signature and Filter Label

All three tab providers update their `Render` signature:

```lua
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable)
function SharedTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable)
function MineTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable)
```

Each tab provider fetches its own filter label using its known tab ID. GroupFrame does not call `GetFilterLabel` — that responsibility belongs to each Render implementation that uses it.

In `PartyTab:Render()`:

```lua
local filterLabel = SocialQuestWindowFilter:GetFilterLabel("party")
if filterLabel then
    y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
        SocialQuestWindowFilter:Dismiss("party")
        SocialQuestGroupFrame:Refresh()
    end)
end
```

In `SharedTab:Render()`:

```lua
local filterLabel = SocialQuestWindowFilter:GetFilterLabel("shared")
if filterLabel then
    y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
        SocialQuestWindowFilter:Dismiss("shared")
        SocialQuestGroupFrame:Refresh()
    end)
end
```

`MineTab:Render()` does not call `GetFilterLabel` and does not render a filter header row.

The tab ID strings `"party"` and `"shared"` match the `id` values in the `providers` table in `GroupFrame.lua`.

---

## Settings

### DB Defaults (`SocialQuest:GetDefaults()`)

New key in `profile` scope:

```lua
window = {
    autoFilterInstance = true,
    autoFilterZone     = false,
},
```

`profile` scope is intentional: settings are shared across characters on the same AceDB profile, and can be copied between profiles using the built-in Profiles UI. Characters wanting independent settings create their own profiles.

### Options Panel (`UI/Options.lua`)

New top-level group `window`, name `L["Social Quest Window"]`, order 9. The existing Debug group moves from order 9 to order 10. No other group currently occupies order 10.

The `window` group uses the existing `toggle()` helper. Each toggle's `set` callback calls `WindowFilter:Reset()` and `GroupFrame:RequestRefresh()` in addition to updating the DB value, so the window reflects the new filter state immediately without requiring a zone transition.

```lua
window = {
    type  = "group",
    name  = L["Social Quest Window"],
    order = 9,
    args  = {
        autoFilterInstance = {
            type  = "toggle",
            name  = L["Auto-filter to current instance"],
            desc  = L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."],
            order = 1,
            get   = function(info) return db.window.autoFilterInstance end,
            set   = function(info, value)
                db.window.autoFilterInstance = value
                SocialQuestWindowFilter:Reset()
                SocialQuestGroupFrame:RequestRefresh()
            end,
        },
        autoFilterZone = {
            type  = "toggle",
            name  = L["Auto-filter to current zone"],
            desc  = L["Outside of instances, the Party and Shared tabs show only quests for your current zone."],
            order = 2,
            get   = function(info) return db.window.autoFilterZone end,
            set   = function(info, value)
                db.window.autoFilterZone = value
                SocialQuestWindowFilter:Reset()
                SocialQuestGroupFrame:RequestRefresh()
            end,
        },
    },
},
```

These toggles cannot use the generic `toggle()` helper because their `set` callbacks perform additional work beyond writing to the DB. They are written out in full.

New locale keys required (add to all 12 locale files):
- `"Social Quest Window"`
- `"Auto-filter to current instance"`
- `"When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."`
- `"Auto-filter to current zone"`
- `"Outside of instances, the Party and Shared tabs show only quests for your current zone."`

---

## WowAPI Additions

```lua
function SocialQuestWowAPI.GetRealZoneText()   return GetRealZoneText()   end
function SocialQuestWowAPI.IsInInstance()       return IsInInstance()       end
```

---

## TOC Order

`UI/WindowFilter.lua` is added after the tab provider files and before `UI/Options.lua`:

```
UI/TabUtils.lua
UI/RowFactory.lua
UI/Tabs/MineTab.lua
UI/Tabs/PartyTab.lua
UI/Tabs/SharedTab.lua
UI/WindowFilter.lua     ← new
UI/Options.lua
UI/Tooltips.lua
UI/GroupFrame.lua       ← position unchanged; listed for completeness
```

---

## Extensibility Notes

The filter table `{ zone = "..." }` is a plain Lua table. Future filter types (e.g. `{ type = "monster" }`, `{ level = 70 }`) are added by:
1. Generating them in `WindowFilter:GetActiveFilter()` alongside or instead of `zone`
2. Handling the new key in each `BuildTree()` method that cares about it

Unknown keys in the filter table are silently ignored by tabs that don't handle them, so new filter types don't require simultaneous changes to all tabs.

---

## Version Impact

This is new functionality added on a feature branch. Version bump follows the project versioning rule: first change of the day increments minor version and resets revision.
