# Progress Bar Polish — Design Spec

**Date:** 2026-03-25
**Branch:** ProgressBars
**Status:** Approved

## Goal

Replace the current flat colored-rectangle progress bars in the Party and Shared tabs with visually polished WoW-style bars using the `StatusBar` widget, the standard `UI-StatusBar` fill texture, the casting bar border, and always-legible white text with a drop shadow.

## Background

The initial progress bar implementation (`2026-03-25-progress-bars.md`) renders bars as plain `CreateFrame("Frame")` containers with `SetColorTexture` fills. The result is flat colored rectangles with no border and no visual depth. Players expect progress bars to look like WoW's native health/cast bars.

## Scope

Three files change: `UI/RowFactory.lua` (game logic — bar-layout path replaced), `SocialQuest.toc` (version bump), and `CLAUDE.md` (version history). Nothing else changes — `Colors.lua`, tab files, frame hierarchy above `AddPlayerRow`, and the plain-text fallback path are all untouched.

---

## Design

### Bar frame structure

Each objective bar row is built from a `StatusBar` frame (child of `contentFrame`) with layers stacked on it:

```
StatusBar  (child of contentFrame, barWidth × ROW_H, positioned at barX, -y)
├── Texture "BACKGROUND"   — dark semi-transparent bg (0,0,0,0.5), SetAllPoints
├── StatusBar fill         — Interface\TargetingFrame\UI-StatusBar, colored via SetStatusBarColor
├── Texture "OVERLAY"      — Interface\CastingBar\UI-CastingBar-Border, 2px outside bar edges on all sides
└── FontString "OVERLAY"   — white objective text, shadow offset (1,-1), shadow color (0,0,0,1)
```

The `SetClipsChildren(true)` call from the original implementation is removed — it was needed to clip the manual fill rectangle, but `StatusBar` handles fill clipping natively via `SetValue`. The StatusBar must NOT have `SetClipsChildren` set; the border texture intentionally overflows the StatusBar bounds by 2px on each side to create the inset visual effect.

### Fill color and opacity

`SetStatusBarColor(r, g, b, 0.85)` — same colors as before from `SocialQuestColors.GetUIColorRGB`:
- Active (in-progress): yellow `(1, 1, 0, 0.85)` — same in both normal and colorblind mode (no colorblind override for "active")
- Completed: green `(0, 1, 0, 0.85)` in normal mode; sky-blue `(0.337, 0.706, 0.914, 0.85)` in colorblind mode

Opacity raised from 0.45 to 0.85 because `UI-StatusBar` has its own internal shading (highlight stripe, bevel) that requires higher opacity to be visible.

### Border

A texture at the `OVERLAY` draw layer on the StatusBar, using `Interface\CastingBar\UI-CastingBar-Border`. Blend mode: default `"BLEND"`. Positioned to extend 2px outside the bar edges on all sides:

```lua
borderTex:SetBlendMode("BLEND")
borderTex:SetPoint("TOPLEFT",     statusBar, "TOPLEFT",     -2,  2)
borderTex:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT",  2, -2)
```

The border texture has a transparent center, so text rendered above it remains visible. The tapered ends give the impression of rounded corners without requiring Retail-only `SetCornerRadius`.

### Text — color stripping and readability

WoW's `obj.text` strings embed color escape codes (`|cFFFFFF00` yellow for in-progress, `|cFF00FF00` green for completed). These colors conflict with the bar fill, reducing contrast to near zero.

The fix: strip all embedded color codes and force white text. The bar fill color already communicates completion status, so the text color coding is redundant.

Both gsub calls replace all occurrences (Lua's `gsub` is global by default — it replaces every match, not just the first). The first handles closed codes (`|c...text...|r`); the second handles any unclosed code that runs to the next pipe or end of string. The second pattern uses `[^|]*` (stops at the next `|`) rather than `.*` (greedy to end of string) so it does not accidentally consume trailing escape sequences like `|T...|t` icon embeds:

```lua
local plainText = (obj.text or "")
    :gsub("|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
    :gsub("|c%x%x%x%x%x%x%x%x([^|]*)", "%1")
textFs:SetText(C.white .. plainText .. C.reset)
```

Text shadow: `SetShadowOffset(1, -1)` and `SetShadowColor(0, 0, 0, 1)`. White text with a 1px black shadow is legible against any fill color, including the colorblind sky-blue completed fill.

### Row height increment

The casting bar border extends 2px beyond the StatusBar edges on top and bottom (4px total vertical protrusion). The row increment changes from `ROW_H + 2` to `ROW_H + 6`:

- `ROW_H` (18px) — the StatusBar height
- `+2px` — bottom border protrusion below the bar
- `+2px` — clearance above the top border of the next row
- `+2px` — preserved gap between rows

This leaves 2px of actual visual space between the bottom border of one row and the top border of the next.

If `barWidth` resolves to 0 (e.g., very narrow window), skip creating the StatusBar and all its children entirely — a zero-width StatusBar with a border texture produces a degenerate visual. The row increment still advances by `ROW_H + 6` so subsequent rows are not displaced.

---

## Implementation Notes

### What changes in AddPlayerRow

Replace the entire bar-layout branch (`if nameColumnWidth and obj.numRequired and obj.numRequired > 0 then ... end`) with the new StatusBar construction. The plain-text fallback (`else` branch) is unchanged.

### Draw layer ordering within StatusBar

Within the same frame, WoW draws layers in order: BACKGROUND → BORDER → ARTWORK → OVERLAY → HIGHLIGHT. The StatusBar's native fill texture renders at ARTWORK — empirically confirmed on Interface 20505. The bg texture at BACKGROUND renders behind it. Both the border texture and the text FontString are at OVERLAY, rendering above the fill. If in testing the border texture appears behind the fill (which would indicate the fill renders at OVERLAY rather than ARTWORK), raise the border texture to `"HIGHLIGHT"` instead.

**Creation order is an explicit requirement — do not reorder these calls:**

1. Create bg texture (`BACKGROUND`) — behind the fill
2. Set StatusBar texture and value (ARTWORK — handled by the widget)
3. Create border texture (`OVERLAY`) — on top of fill, transparent center
4. Create text FontString (`OVERLAY`) — must be created after the border texture so it renders above the border edges

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
| `SocialQuest.toc` | Version bump: `2.10.0` → `2.10.1` (additional same-day change per CLAUDE.md versioning rule) |
| `CLAUDE.md` | Add revision note under 2.10.0 entry |
