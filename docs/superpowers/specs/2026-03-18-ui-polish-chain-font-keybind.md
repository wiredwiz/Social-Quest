# Social Quest UI Polish: Chain Header Font + Keybind — Design Spec

## Overview

Two small improvements to the Social Quest addon:

1. **Chain header font** — Chain group label rows (`AddChainHeader`) currently use
   `GameFontNormalSmall`, making them visually smaller than zone headers and quest
   title rows, which both use `GameFontNormal`. Promote chain headers to
   `GameFontNormal` so all primary content rows share the same visual weight.

2. **Keybind** — Add a named keybinding entry to the WoW Key Bindings UI
   (Options → Key Bindings → AddOns → Social Quest) so players can assign a key
   to toggle the Social Quest window without using a macro.

---

## Change 1 — Chain Header Font

**File:** `UI/RowFactory.lua`, function `AddChainHeader` (line 113)

Change the font object from `GameFontNormalSmall` to `GameFontNormal`:

**Before:**
```lua
local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
```

**After:**
```lua
local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
```

No other changes required. The row height (`ROW_H = 18`) and vertical advance
(`ROW_H + 2`) are unchanged — `GameFontNormal` (~12pt) renders comfortably within
18px. The font string uses `SetWidth` only (no fixed height), so the frame auto-
sizes to the font without clipping.

---

## Change 2 — Keybind

### New file: `Bindings.xml`

Place in the Social Quest addon root (`Social-Quest/Bindings.xml`). WoW processes
this file automatically when listed in the TOC.

```xml
<Bindings>
    <Binding header="SOCIALQUEST_HEADER"/>
    <Binding name="SOCIALQUEST_TOGGLE" description="Toggle Social Quest Window">
        SocialQuestGroupFrame:Toggle()
    </Binding>
</Bindings>
```

- The self-closing `<Binding header="SOCIALQUEST_HEADER"/>` declares the category
  grouping in the Key Bindings UI. WoW resolves the display name from the global
  `BINDING_HEADER_SOCIALQUEST_HEADER`. It must be a separate element — `header`
  and `name` cannot coexist on the same tag.
- `name="SOCIALQUEST_TOGGLE"` is the binding identifier. WoW resolves its display
  name from `BINDING_NAME_SOCIALQUEST_TOGGLE`.
- The body (`SocialQuestGroupFrame:Toggle()`) is executed as Lua when the player
  presses the bound key — not at load time — so `SocialQuestGroupFrame` is always
  fully initialized by the time it runs.

### Locale globals

WoW uses `BINDING_HEADER_*` and `BINDING_NAME_*` global string variables to
display human-readable names in the Key Bindings UI. These are defined in
`SocialQuest.lua` (module load, before `AceAddon:NewAddon`):

```lua
BINDING_HEADER_SOCIALQUEST_HEADER = "Social Quest"
BINDING_NAME_SOCIALQUEST_TOGGLE   = "Toggle Social Quest Window"
```

Defining them in `SocialQuest.lua` rather than individual locale files keeps
the change minimal — these strings are UI labels in the key bindings panel only
and do not need per-locale translation for the initial implementation.

### TOC update

Add `Bindings.xml` to `SocialQuest.toc` file list, before the Lua files:

```
Bindings.xml
```

The binding body is evaluated at keypress time (not at load time), so load order
does not affect whether `SocialQuestGroupFrame:Toggle()` is available. Placing
`Bindings.xml` first is conventional for WoW addons and keeps the TOC readable.

---

## Files Changed

| File | Change |
|------|--------|
| `Social-Quest/UI/RowFactory.lua` | `AddChainHeader`: `GameFontNormalSmall` → `GameFontNormal` |
| `Social-Quest/Bindings.xml` | New file: registers `SOCIALQUEST_TOGGLE` binding |
| `Social-Quest/SocialQuest.toc` | Add `Bindings.xml` to file list |
| `Social-Quest/SocialQuest.lua` | Add `BINDING_HEADER_*` and `BINDING_NAME_*` globals |

---

## Testing

1. **Chain header font**: Open the Social Quest window with quests in a chain
   (requires Questie or QuestWeaver). Confirm chain group labels are the same
   visual size as zone header labels and quest title text.

2. **Keybind strings in UI**: Open Options → Key Bindings → AddOns. Confirm a
   "Social Quest" category appears with a "Toggle Social Quest Window" entry
   (not raw strings like `BINDING_NAME_SOCIALQUEST_TOGGLE`). Assign a key.
   Press it. Confirm the Social Quest window opens and closes.

3. **Escape still works**: With the window open, press Escape. Confirm it closes
   (existing `UISpecialFrames` behaviour is unchanged).

4. **`/sq` still works**: Type `/sq`. Confirm it still toggles the window.
