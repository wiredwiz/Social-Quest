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

| State | Fill color | Fill alpha | Notes |
|---|---|---|---|
| In progress | Yellow `#FFFF00` | 0.45 | Matches `C.active` |
| Complete | Green `#00FF00` (or sky-blue `#56B4E9` in colorblind mode) | 0.45 | Uses `SocialQuestColors.GetUIColor("completed")` |
| Background | Black | 0.35 | Behind the fill |

`GetUIColor("completed")` is called at render time, so colorblind mode is respected automatically.

The player name (left column) is always white (`C.white`), regardless of objective state.

Text on the bar is `GameFontNormalSmall` (white with black shadow). The shadow provides contrast over both the fill color and the dark background without any extra color logic.

---

## Implementation

### Files modified

| File | Change |
|---|---|
| `UI/RowFactory.lua` | Add `MeasureNameWidth`, modify `AddPlayerRow` |
| `UI/Tabs/PartyTab.lua` | Add pre-pass to compute `nameColumnWidth` before player rows |
| `UI/Tabs/SharedTab.lua` | Same as PartyTab |

### RowFactory.lua

**New helper: `RowFactory.MeasureNameWidth(displayName)`**

Accepts the fully-resolved display name string (i.e., after nameTag suffix has been appended, matching what `AddPlayerRow` actually renders in the name column). Creates a temporary FontString on `UIParent` using `GameFontNormalSmall`, sets the text, calls `GetStringWidth()`, then releases the FontString (hides it). Returns the pixel width as a number. Used by tab Render methods before calling `AddPlayerRow`.

**Modified: `AddPlayerRow(contentFrame, y, playerEntry, indent, nameColumnWidth)`**

New optional fifth parameter `nameColumnWidth`. Behavior:

- When `nameColumnWidth` is `nil` or the player is in a special-case branch (FINISHED, needsShare, etc.): identical to current behavior — single-column text row.
- When `nameColumnWidth` is provided and the player has in-progress objectives: renders the two-column bar layout for each objective.

Bar construction per objective:
1. Guard: if `obj.numRequired` is nil or `== 0`, fall back to the existing plain-text single-column rendering for that objective row (same as when `nameColumnWidth` is nil). This handles any objective that lacks numeric data.
2. Create a `Frame` anchored at `(indent + nameColumnWidth + 4, -y)`.
3. On the frame, create a background `Texture` (BACKGROUND layer): `SetColorTexture(0, 0, 0, 0.35)`, `SetAllPoints`.
4. On the frame, create a fill `Texture` (ARTWORK layer): color from `GetUIColor("completed")` (complete) or yellow (in-progress), alpha 0.45. Anchor TOPLEFT to TOPLEFT. Width = `barWidth * (numFulfilled / numRequired)`. Height = `ROW_H`.
5. On the frame, create a `FontString` (OVERLAY layer): `GameFontNormalSmall`, white, left-aligned, 4px left padding, objective text (`obj.text`).
6. Create a separate name `FontString` at `(indent, -y)`, width = `nameColumnWidth`, white, `GameFontNormalSmall`, left-aligned.
7. Advance `y` by `ROW_H + 2`.

### PartyTab.lua and SharedTab.lua

Before the player-row rendering loop for each quest, add a pre-pass:

```lua
local nameColumnWidth = 0
for _, playerEntry in ipairs(players) do
    local name = playerEntry.name or "Unknown"
    local nameTag = playerEntry.dataProvider
                 and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
    local displayName = nameTag and (name .. " " .. nameTag) or name
    local w = RowFactory.MeasureNameWidth(displayName)
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
- Colorblind mode respected via `GetUIColor("completed")`.
- `MeasureNameWidth` must not leave persistent FontStrings — create, measure, hide/release.
