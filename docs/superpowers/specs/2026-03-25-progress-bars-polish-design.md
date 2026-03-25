# Progress Bar Polish — Design Spec

**Date:** 2026-03-25
**Branch:** ProgressBars
**Status:** Approved

## Goal

Replace the current flat colored-rectangle progress bars in the Party and Shared tabs with visually polished WoW-style bars using the `StatusBar` widget, the standard `UI-StatusBar` fill texture, the casting bar border, and always-legible white text with a drop shadow.

## Background

The initial progress bar implementation (`2026-03-25-progress-bars.md`) renders bars as plain `CreateFrame("Frame")` containers with `SetColorTexture` fills. The result is flat colored rectangles with no border and no visual depth. Players expect progress bars to look like WoW's native health/cast bars.

## Scope

One file changes: `UI/RowFactory.lua`. The bar-layout path inside `AddPlayerRow` is replaced. Nothing else changes — `Colors.lua`, tab files, frame hierarchy above `AddPlayerRow`, and the plain-text fallback path are all untouched.

---

## Design

### Bar frame structure

Each objective bar row is built from a `StatusBar` frame (child of `contentFrame`) with layers stacked on it:

```
StatusBar  (child of contentFrame, barWidth × ROW_H, positioned at barX, -y)
├── Texture "BACKGROUND"   — dark semi-transparent bg (0,0,0,0.5), SetAllPoints
├── StatusBar fill         — Interface\TargetingFrame\UI-StatusBar, colored via SetStatusBarColor
├── Texture "OVERLAY"      — Interface\CastingBar\UI-CastingBar-Border, ~4px outside bar edges
└── FontString "OVERLAY"   — white objective text, shadow offset (1,-1), shadow color (0,0,0,1)
```

The `SetClipsChildren(true)` call from the original implementation is removed — it was needed to clip the manual fill rectangle, but `StatusBar` handles fill clipping natively via `SetValue`.

### Fill color and opacity

`SetStatusBarColor(r, g, b, 0.85)` — same colors as before from `SocialQuestColors.GetUIColorRGB`:
- Active (in-progress): yellow `(1, 1, 0, 0.85)`
- Completed: green `(0, 1, 0, 0.85)` in normal mode; sky-blue `(0.337, 0.706, 0.914, 0.85)` in colorblind mode

Opacity raised from 0.45 to 0.85 because `UI-StatusBar` has its own internal shading (highlight stripe, bevel) that requires higher opacity to be visible.

### Border

A texture at the `OVERLAY` draw layer on the StatusBar, using `Interface\CastingBar\UI-CastingBar-Border`. Positioned to extend ~4px outside the bar edges on all sides:

```lua
borderTex:SetPoint("TOPLEFT",     statusBar, "TOPLEFT",     -4,  4)
borderTex:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT",  4, -4)
```

The border texture has a transparent center, so text rendered above it remains visible. The tapered ends give the impression of rounded corners without requiring Retail-only `SetCornerRadius`.

### Text — color stripping and readability

WoW's `obj.text` strings embed color escape codes (`|cFFFFFF00` yellow for in-progress, `|cFF00FF00` green for completed). These colors conflict with the bar fill, reducing contrast to near zero.

The fix: strip all embedded color codes and force white text. The bar fill color already communicates completion status, so the text color coding is redundant.

Strip pattern applied before `SetText`:
```lua
local plainText = (obj.text or "")
    :gsub("|c%x%x%x%x%x%x%x%x(.-)%|r", "%1")
    :gsub("|c%x%x%x%x%x%x%x%x(.*)", "%1")
textFs:SetText(C.white .. plainText .. C.reset)
```

Text shadow: `SetShadowOffset(1, -1)` and `SetShadowColor(0, 0, 0, 1)`. White text with a 1px black shadow is legible against any fill color, including the colorblind sky-blue completed fill.

### Row height increment

The casting bar border extends ~4px beyond the StatusBar edges (2px top, 2px bottom). The row increment changes from `ROW_H + 2` to `ROW_H + 6` to prevent the border of one row from visually clipping into the next.

---

## Implementation Notes

### What changes in AddPlayerRow

Replace the entire bar-layout branch (`if nameColumnWidth and obj.numRequired and obj.numRequired > 0 then ... end`) with the new StatusBar construction. The plain-text fallback (`else` branch) is unchanged.

### Draw layer ordering within StatusBar

Within the same frame, WoW draws layers in order: BACKGROUND → BORDER → ARTWORK → OVERLAY → HIGHLIGHT. The StatusBar's native fill texture renders at ARTWORK. Textures created at OVERLAY render on top of it. FontStrings at OVERLAY render above textures at OVERLAY when created after them. So creation order matters:

1. Create bg texture (BACKGROUND)
2. Set StatusBar texture and value (ARTWORK — handled by the widget)
3. Create border texture (OVERLAY) — on top of fill, transparent center
4. Create text FontString (OVERLAY, created after border) — on top of border edges

### Unchanged

- `Colors.lua` — `GetUIColorRGB` and color tables unchanged
- `PartyTab.lua`, `SharedTab.lua` — pre-pass and `AddPlayerRow` call signature unchanged
- Plain-text fallback path in `AddPlayerRow` — unchanged
- `ROW_H = 18` constant — unchanged (StatusBar uses it for height; border protrusion handled by row increment only)

---

## File Changes

| File | Change |
|---|---|
| `UI/RowFactory.lua` | Replace bar-layout branch in `AddPlayerRow` with StatusBar-based implementation |

No version bump needed — this is a visual refinement within the same ProgressBars branch, same feature.
