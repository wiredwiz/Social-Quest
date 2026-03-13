# Social Quest UI Polish — Design Spec

**Date:** 2026-03-13
**Scope:** Five targeted improvements to the SocialQuestGroupFrame and minimap button.
**Target addon:** SocialQuest (`D:\Projects\Wow Addons\Social-Quest\`)

---

## 1. Wowhead URL Popup (Custom Frame)

### Problem
`StaticPopup_Show` calls `editBox:SetText(text1)` **after** `OnShow` fires, overwriting any pre-population and leaving the box blank.

### Solution
Replace `StaticPopupDialogs["SQ_WOWHEAD_POPUP"]` with a dedicated custom `Frame`. The URL is set synchronously before `Show()` — no timers, no races.

### Design

**Parent frame:** `UIParent`. The popup must NOT be a child of the main quest frame; a child frame hides when its parent hides.

**Lazy creation:** Declare `local urlPopup = nil` at file scope in `GroupFrame.lua`, alongside the existing `local frame = nil` and `local refreshPending = false`. Create the frame once on first call to `ShowWowheadUrl`.

**Frame template:** Use `"BasicFrameTemplate"` (intentionally, not `"BasicFrameTemplateWithInset"` — the inset border is unnecessary for a small popup). `BasicFrameTemplate` provides a title bar and a close (X) button. The title text widget is at `urlPopup.TitleText`.

**Frame layout:**
- Global name: `"SocialQuestWowheadPopup"` — required for `UISpecialFrames` Escape support (see below).
- Size: 340 × 100 px.
- Anchor: `CENTER` to `UIParent`.
- Title: set `urlPopup.TitleText:SetText("Quest URL (Ctrl+C to copy)")`.
- `EditBox`: 300 px wide, 20 px tall, anchored `CENTER` to the frame.
  - Call `editBox:SetAutoFocus(false)` so it does not steal focus on every popup open.
  - Do NOT call `editBox:SetEnabled(false)` — that would prevent the user from selecting the text for Ctrl+C. The field is left enabled; the user can type in it, but there is no handler that would do anything with typed text. This is the correct approach for a "copy-able URL" field in TBC Classic.
- The template's built-in X button dismisses the popup. No additional Close button is needed.

**Escape key to close:** After creating the frame, register its global name with `UISpecialFrames`:
```lua
tinsert(UISpecialFrames, "SocialQuestWowheadPopup")
```
WoW's `UIParent_OnKeyDown` iterates `UISpecialFrames` when Escape is pressed and hides any shown frame in the list. This is the same pattern used by the main quest frame (`"SocialQuestGroupFramePanel"`).

**`SocialQuestGroupFrame.ShowWowheadUrl(questID)` function** (added to the `SocialQuestGroupFrame` table in `GroupFrame.lua`):
1. If `urlPopup == nil`, create the frame as described above (including the `UISpecialFrames` registration).
2. Call `SocialQuestTabUtils.WowheadUrl(questID)` — pre-existing in `UI/TabUtils.lua`.
3. Call `urlPopup.editBox:SetText(url)` — synchronous.
4. Call `urlPopup:Show()`.
5. Call `urlPopup.editBox:SetFocus()` and `urlPopup.editBox:HighlightText()`. Text is already set; these succeed immediately, pre-selecting the URL for the user.

**Caller change:** In `RowFactory.AddQuestRow`, replace:
```lua
StaticPopup_Show("SQ_WOWHEAD_POPUP", SocialQuestTabUtils.WowheadUrl(questEntry.questID))
```
with:
```lua
SocialQuestGroupFrame.ShowWowheadUrl(questEntry.questID)
```

**Cleanup:** Remove the entire `StaticPopupDialogs["SQ_WOWHEAD_POPUP"] = { ... }` block from `GroupFrame.lua`.

**Files changed:** `UI/GroupFrame.lua`, `UI/RowFactory.lua`

---

## 2. Tab Width and Adjacency

### Problem
Tabs created with `TabButtonTemplate` default to ~70 px; label text overflows. Current positions leave large gaps.

### Solution
- Call `tab:SetWidth(120)` on each tab after creation.
- Positions — each tab anchored `TOPLEFT` of the button to `TOPLEFT` of the frame, with these x offsets (y = −24 as currently):
  - Shared: x = 10 (occupies x 10–130)
  - Mine: x = 130 (occupies x 130–250)
  - Party: x = 250 (occupies x 250–370)
- The frame is 400 px wide. The usable interior ends at ~394 px (6 px border). Tabs ending at x = 370 leave 24 px of right margin — sufficient clearance from the frame border.

**Files changed:** `UI/GroupFrame.lua`

---

## 3. Active Tab Highlighting

### Problem
No visual indicator shows which tab is currently active.

### Solution
Use the standard WoW tab highlight API:
- `PanelTemplates_SelectTab(tab)` — visually marks the tab as active and **calls `tab:Disable()`**, preventing re-clicks on the already-active tab. This is standard WoW behavior.
- `PanelTemplates_DeselectTab(tab)` — restores inactive appearance and re-enables the button.

Because `PanelTemplates_SelectTab` disables the button, always deselect all tabs before selecting the active one. The loop below does this correctly (the else-branch deselects, the if-branch selects, one tab at a time):

**`providers` table update** — add `tab` and `offsetX` fields so both tab reference and position are stored together:
```lua
local providers = {
    { id = "shared", module = SharedTab, tab = nil, offsetX = 10  },
    { id = "mine",   module = MineTab,   tab = nil, offsetX = 130 },
    { id = "party",  module = PartyTab,  tab = nil, offsetX = 250 },
}
```

**In `createFrame()`** — replace the three individual `makeTab` calls with a loop (or replace inline; either works) and assign `p.tab`:
```lua
for _, p in ipairs(providers) do
    p.tab = makeTab(p.id, p.module:GetLabel(), p.offsetX)
    p.tab:SetWidth(120)
end
```

**In `Refresh()`** — add after determining `activeID`:
```lua
for _, p in ipairs(providers) do
    if p.tab then
        if p.id == activeID then
            PanelTemplates_SelectTab(p.tab)
        else
            PanelTemplates_DeselectTab(p.tab)
        end
    end
end
```

**Files changed:** `UI/GroupFrame.lua`

---

## 4. Window Strata

### Problem
`SetFrameStrata("HIGH")` keeps the quest window above all other game windows regardless of focus.

### Solution
Change `f:SetFrameStrata("HIGH")` → `f:SetFrameStrata("MEDIUM")`. Keep `frame:Raise()` in `Toggle()` so the window comes to front on open, but other MEDIUM-strata windows can be focused on top afterward.

**Files changed:** `UI/GroupFrame.lua`

---

## 5. Minimap Button — LibDBIcon-1.0

### Approach
Bundle `LibDataBroker-1.1` and `LibDBIcon-1.0` as embedded libraries — the standard Ace3 pattern used by Questie and others. Gives a correct spherical minimap button with drag-to-reposition, automatic position persistence, and forward-compatibility across WoW versions.

### Libraries to bundle
Copy these two files from the Questie addon (sibling directory in the WoW AddOns folder):
- `D:\Projects\Wow Addons\Questie\Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua` → `Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua`
- `D:\Projects\Wow Addons\Questie\Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua` → `Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua`

The `lib.xml` wrapper files are **not needed** — the `.lua` files are listed directly in the TOC.

### TOC changes (`SocialQuest.toc`)
Insert the two lib lines as the **first two entries in the file**, before `Util\Colors.lua`:
```
Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
Util\Colors.lua
SocialQuest.lua
...
```
These libraries have no dependencies on any SocialQuest code so loading them first is correct.

### AceDB defaults (`SocialQuest.lua` — `GetDefaults`)
Add `minimap = { hide = false }` inside the existing `profile = { ... }` block (alongside `enabled`, `general`, `party`, etc.):
```lua
minimap = { hide = false },
-- LibDBIcon writes minimapPos into this table automatically when the user drags.
```

### Registration (`SocialQuest.lua` — `OnEnable`)
Add at the end of `OnEnable`, after the existing AQL callback registrations. `SocialQuestGroupFrame` is a global table (`SocialQuestGroupFrame = {}`) defined at the top of `UI/GroupFrame.lua`, so it is accessible here.

```lua
local LDB    = LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub("LibDBIcon-1.0", true)

if LDB and DBIcon then
    local launcher = LDB:NewDataObject("SocialQuest", {
        type  = "launcher",
        icon  = "Interface\\Icons\\INV_Misc_GroupNeedMore",
        OnClick = function(_, button)
            if button == "LeftButton" then
                SocialQuestGroupFrame:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText("SocialQuest")
            tooltip:AddLine("Click to open group quest frame.", 1, 1, 1)
            tooltip:Show()
        end,
    })
    DBIcon:Register("SocialQuest", launcher, self.db.profile.minimap)
end
```

### Remove old minimap button
Delete the following block from `UI/GroupFrame.lua` (currently lines 199–242):
- `local minimapButton = CreateFrame(...)` and all its `Set*` calls
- `local angle = 225`
- `local function updateMinimapButtonPosition() ... end` and the initial call
- All `minimapButton:SetScript(...)` blocks through `minimapButton:SetScript("OnLeave", ...)`

LibDBIcon owns the button lifecycle entirely.

**Files changed:** `SocialQuest.toc`, `SocialQuest.lua`, `UI/GroupFrame.lua`
**Files created:** `Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua`, `Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua`

---

## Summary of All Changes

| # | What | Files |
|---|------|-------|
| 1 | Custom URL popup frame (UIParent child, remove StaticPopup) | `UI/GroupFrame.lua`, `UI/RowFactory.lua` |
| 2 | Tab width 120 px, positions 10/130/250 (TOPLEFT anchor) | `UI/GroupFrame.lua` |
| 3 | Active tab highlight via PanelTemplates; offsetX in providers | `UI/GroupFrame.lua` |
| 4 | Frame strata MEDIUM (was HIGH) | `UI/GroupFrame.lua` |
| 5 | LibDBIcon-1.0 minimap button; bundle libs; remove old button + helpers | `SocialQuest.toc`, `SocialQuest.lua`, `UI/GroupFrame.lua`, new `Libs/` files |
