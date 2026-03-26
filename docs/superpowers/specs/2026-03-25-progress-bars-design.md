# Progress Bars in the Group Frame — Design Spec

## Goal

Replace the plain objective text rows in `AddPlayerRow` with inline progress bars that make party quest progress scannable at a glance. The bar fill represents `numFulfilled / numRequired`; objective text is rendered over the bar fill. No protocol changes. No new config toggle.

## Context

The current group frame renders each in-progress player objective as a single text row:

```
  Thad  3/8 Gnolls Slain
  Bob   2/8 Gnolls Slain
  Alice 7/8 Gnolls Slain
```

This is readable but not scannable. Comparing progress across players requires reading every number.

The new layout keeps the same row height (`ROW_H = 18px`) and row count. It splits each objective row into two columns:

```
[indent] [Thad  ] [████████░░  3/8 Gnolls Slain        ]
[indent] [Bob   ] [████░░░░░░  2/8 Gnolls Slain        ]
[indent] [Alice ] [██████████  7/8 Gnolls Slain        ]
```

Bars for the same objective are column-aligned across all players, so relative progress is visible without reading the numbers.

---

## Layout

### Row structure

Each in-progress objective row consists of:

- **Name column** — `GameFontNormalSmall`, white (`C.white`), left-aligned. Width is the widest player name in the current quest's player list, measured before rendering begins (dynamic two-pass approach).
- **4px gap** between name column and bar.
- **Bar** — spans from `indent + nameColumnWidth + 4` to the right edge of the content frame (minus a 4px right margin). Height = `ROW_H`.

### Bar internals (rendered as sub-elements of a Frame)

| Layer | Element | Description |
|---|---|---|
| BACKGROUND | Background texture | Dark, semi-transparent (black, alpha 0.35). Full bar width. |
| ARTWORK | Fill texture | Colored, alpha 0.45. Width = `barWidth * (numFulfilled / numRequired)`. Anchored TOPLEFT. |
| OVERLAY | FontString | Objective text (`"3/8 Gnolls Slain"`), `GameFontNormalSmall`, white. Centered vertically. Left-aligned with 4px left padding. |

### Special-case rows — unchanged

The following player row variants keep their current single-column layout (no bar):
- `hasCompleted` → `"Name FINISHED"` (green)
- `isComplete` → `"Name Complete"` (white + green)
- `needsShare` → `"Name Needs it Shared"` (grey)
- No data → `"Name (no data)"` (grey)
- No objectives yet → `"Name"` alone (white)

Bars only apply when the player has one or more objectives with `numFulfilled` and `numRequired` available.

---

## Colors

Bar fill and background are set via `texture:SetColorTexture(r, g, b, a)`, which requires numeric RGB values. The existing `GetUIColor` returns inline escape strings (unusable for textures), so a new helper is added to `Colors.lua`.

**New helper: `SocialQuestColors.GetUIColorRGB(key)`**

Returns `{r, g, b}` for a UI color key, respecting colorblind mode. Same logic as `GetUIColor` but returns numbers instead of escape strings. Initial entries needed:

```lua
SocialQuestColors.uiRGB = {
    completed = { r = 0,     g = 1,     b = 0     },  -- green  (#00FF00)
    active    = { r = 1,     g = 1,     b = 0     },  -- yellow (#FFFF00)
}
SocialQuestColors.uiCBRGB = {
    completed = { r = 0.337, g = 0.706, b = 0.914 },  -- sky-blue (#56B4E9)
}
```

`GetUIColorRGB(key)` checks colorblind mode (same `isColorblindMode()` call as `GetUIColor`), returns `uiCBRGB[key]` if available and colorblind, else `uiRGB[key]`.

| State | `GetUIColorRGB` key | Fill alpha |
|---|---|---|
| In progress | `"active"` → `{1, 1, 0}` | 0.45 |
| Complete | `"completed"` → `{0, 1, 0}` or `{0.337, 0.706, 0.914}` (CB) | 0.45 |
| Background | (hardcoded) `{0, 0, 0}` | 0.35 |

The player name (left column) is always white (`C.white`), regardless of objective state.

Text on the bar is `GameFontNormalSmall` (white with black shadow). The shadow provides contrast over both the fill color and the dark background without any extra color logic.

---

## Implementation

### Files modified

| File | Change |
|---|---|
| `Util/Colors.lua` | Add `uiRGB`/`uiCBRGB` tables and `GetUIColorRGB(key)` helper |
| `UI/RowFactory.lua` | Add `GetDisplayName`, `MeasureNameWidth`; modify `AddPlayerRow` |
| `UI/Tabs/PartyTab.lua` | Add pre-pass to compute `nameColumnWidth` before player rows |
| `UI/Tabs/SharedTab.lua` | Same as PartyTab |

### RowFactory.lua

**New helper: `RowFactory.GetDisplayName(playerEntry)`**

Extracts the fully-resolved display name from a player entry, applying the nameTag suffix from `SocialQuestBridgeRegistry` when a `dataProvider` is set. Centralizes the name resolution logic that currently exists inline in `AddPlayerRow`. Used by `MeasureNameWidth` pre-passes in tab Render methods and by `AddPlayerRow` itself (refactored to call this helper).

```lua
function RowFactory.GetDisplayName(playerEntry)
    local name    = playerEntry.name or "Unknown"
    local nameTag = playerEntry.dataProvider
                 and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
    return nameTag and (name .. " " .. nameTag) or name
end
```

**New helper: `RowFactory.MeasureNameWidth(displayName)`**

Accepts the fully-resolved display name string (from `GetDisplayName`). Creates a temporary FontString on `UIParent` using `GameFontNormalSmall`, sets the text, calls `GetStringWidth()`, then hides the FontString (reuse a single module-level FontString to avoid per-call creation overhead). Returns the pixel width as a number. Used by tab Render methods before calling `AddPlayerRow`.

**Modified: `AddPlayerRow(contentFrame, y, playerEntry, indent, nameColumnWidth)`**

New optional fifth parameter `nameColumnWidth`. Behavior:

- When `nameColumnWidth` is `nil` or the player is in a special-case branch (FINISHED, needsShare, etc.): identical to current behavior — single-column text row.
- When `nameColumnWidth` is provided and the player has in-progress objectives: renders the two-column bar layout for each objective.

Bar construction per objective:
1. Guard: if `obj.numRequired` is nil or `== 0`, fall back to the existing plain-text single-column rendering for that objective row (same as when `nameColumnWidth` is nil). This handles event-type objectives (e.g., "Talk to NPC") that lack numeric data.
2. Resolve `numFulfilled`: use `obj.numFulfilled or 0` (defensive default matching `BuildRemoteObjectives` behavior, in case a local AQL objective has a nil value).
3. Compute `barWidth = math.max(CONTENT_WIDTH - indent - nameColumnWidth - 4 - 4, 0)` (right-edge margin of 4px; clamped to 0 to handle very narrow frames).
4. Compute `fillWidth = math.floor(barWidth * ((obj.numFulfilled or 0) / obj.numRequired))`.
5. Create a `Frame` on `contentFrame`, size `(barWidth, ROW_H)`, anchored TOPLEFT at `(indent + nameColumnWidth + 4, -y)`. Set `frame:SetClipsChildren(true)` so text cannot overflow.
6. On the frame, create a background `Texture` (BACKGROUND layer): `SetColorTexture(0, 0, 0, 0.35)`, `SetAllPoints`.
7. On the frame, create a fill `Texture` (ARTWORK layer): color from `SocialQuestColors.GetUIColorRGB(obj.isFinished and "completed" or "active")`, alpha 0.45. Anchor TOPLEFT to TOPLEFT. `SetSize(fillWidth, ROW_H)`. Skip if `fillWidth == 0`.
8. On the frame, create a `FontString` (OVERLAY layer): `GameFontNormalSmall`, white, `SetMaxLines(1)`, left-aligned with `SetPoint("LEFT", frame, "LEFT", 4, 0)`. Text = `obj.text`.
9. Create a separate name `FontString` directly on `contentFrame` at `(indent, -y)`, `SetSize(nameColumnWidth, ROW_H)`, white, `GameFontNormalSmall`, left-aligned, vertically middle.
10. Advance `y` by `ROW_H + 2`.

### PartyTab.lua and SharedTab.lua

Before the player-row rendering loop for each quest, add a pre-pass:

```lua
local nameColumnWidth = 0
for _, playerEntry in ipairs(players) do
    local w = RowFactory.MeasureNameWidth(RowFactory.GetDisplayName(playerEntry))
    if w > nameColumnWidth then nameColumnWidth = w end
end
```

Pass `nameColumnWidth` as the fifth argument to every `AddPlayerRow` call for that quest.

The pre-pass is scoped per-quest (not per-tab), since each quest can have a different player subset. In practice all party members are the same across quests in a tab, but per-quest scoping is correct.

---

## Constraints

- Row height unchanged at `ROW_H = 18px`. No extra rows.
- No protocol changes.
- No new config toggle — bars replace the plain text rendering directly.
- No new files.
- Colorblind mode respected via `SocialQuestColors.GetUIColorRGB("completed")`.
- `MeasureNameWidth` must not leave persistent FontStrings — create, measure, hide/release.
