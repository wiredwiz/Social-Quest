# Social Quest Quest Linkification — Design Spec

## Overview

Two related improvements that make quest names actionable across the Social Quest addon:

1. **Clickable quest names in frame** — Quest title rows in the Social Quest frame open the
   native WoW Quest Log to the clicked quest when left-clicked. Shift-click (track/untrack)
   is unchanged.

2. **WoW quest hyperlinks in chat announcements** — Quest event announcements sent to party,
   raid, and guild chat use WoW's native `|Hquest:...|h` hyperlink format so recipients can
   ctrl-click to preview the quest. On-screen banners continue using plain title text (the
   RaidNotice system does not render hyperlinks).

---

## Change 1 — Clickable Quest Names in Frame

### File

`UI/RowFactory.lua` — `AddQuestRow` function and a new `openQuestLogToQuest` local helper.

### openQuestLogToQuest helper

A local function defined at the top of `RowFactory.lua` (before any `RowFactory.*` assignments).
It opens the Quest Log frame and selects the given quest, handling collapsed zone headers
surgically so as not to disrupt the player's quest log state.

**Algorithm:**

1. Call `ShowUIPanel(QuestLogFrame)` to open the log.
2. Get `numEntries = GetNumQuestLogEntries()` (only visible entries are returned).
3. Walk the entry list from index 1 to `numEntries`:
   - If an entry is a **collapsed zone header**: expand it (`ExpandQuestHeader(i)`), re-read
     `numEntries`, then scan the newly visible quests under it.
     - If the target quest is found: call `QuestLog_SetSelection(i)` and `QuestLog_Update()`,
       then return (zone stays expanded — it contains the selected quest).
     - If the target quest is not found: collapse the header back (`CollapseQuestHeader(headerIdx)`)
       and re-read `numEntries` before continuing. After collapsing, `i` is set to
       `headerIdx + 1` directly — the outer loop does NOT increment `i` again. This skips
       past the now-collapsed header and resumes at the next sibling without double-advancing.
   - If an entry is a **non-header quest** with `id == questID`: call
     `QuestLog_SetSelection(i)` and `QuestLog_Update()`, then return (already in an expanded
     zone).
   - If an entry is an **expanded zone header** (isHeader = true, isCollapsed = false): skip
     it unconditionally via the `else` branch (`i = i + 1`). Its child quest rows are visited
     as plain non-header entries in subsequent iterations.
   - Otherwise advance `i` and continue.
4. If the quest is not found (stale data or quest already removed), do nothing — the Quest
   Log is still open at whatever its previous scroll position was.

This ensures only the zone header containing the target quest ends up expanded. Any zone that
was collapsed before the call and does not contain the quest is collapsed again.

**Index stability after expand/collapse:** `headerIdx` is captured before `ExpandQuestHeader`
is called. Expanding a zone only shifts entries at indices *greater than* `headerIdx`, so
`headerIdx` itself remains stable. After `CollapseQuestHeader(headerIdx)` those entries shift
back. Setting `i = headerIdx + 1` after collapse therefore correctly points to the first entry
after the re-collapsed zone header.

```lua
local function openQuestLogToQuest(questID)
    ShowUIPanel(QuestLogFrame)
    local numEntries = GetNumQuestLogEntries()
    local i = 1
    while i <= numEntries do
        local _, _, _, isHeader, isCollapsed, _, _, id = GetQuestLogTitle(i)
        if isHeader and isCollapsed then
            local headerIdx = i
            ExpandQuestHeader(headerIdx)
            numEntries = GetNumQuestLogEntries()
            local found = false
            i = i + 1
            while i <= numEntries do
                local _, _, _, subIsHeader, _, _, _, subId = GetQuestLogTitle(i)
                if subIsHeader then break end
                if subId == questID then
                    found = true
                    QuestLog_SetSelection(i)
                    QuestLog_Update()
                    return
                end
                i = i + 1
            end
            if not found then
                CollapseQuestHeader(headerIdx)
                numEntries = GetNumQuestLogEntries()
                i = headerIdx + 1
            end
        elseif not isHeader and id == questID then
            QuestLog_SetSelection(i)
            QuestLog_Update()
            return
        else
            i = i + 1
        end
    end
end
```

### AddQuestRow changes

The existing invisible button overlay is currently created only when
`callbacks.onTitleShiftClick` is provided. The new left-click behavior uses the same overlay
frame, extended to handle both clicks together.

**Condition for creating the overlay:** `callbacks and callbacks.onTitleShiftClick`.
`MineTab.lua` always provides `callbacks.onTitleShiftClick` for every quest row it renders
(both chain and regular rows). `PartyTab.lua` and `SharedTab.lua` pass empty `{}` as
callbacks, so `onTitleShiftClick` is always nil on those tabs.

Note: Party/Shared tab entries also set `logIndex = localInfo and localInfo.logIndex`, so
`questEntry.logIndex` can be a positive integer on those tabs when the local player has the
same quest. Using `logIndex > 0` as the overlay guard would therefore incorrectly enable
left-click on Party/Shared rows — the guard must remain `callbacks.onTitleShiftClick` to
restrict clickability to My Quests tab rows only.

**Click handling:**

The existing overlay (currently created only when `callbacks.onTitleShiftClick` is provided)
is extended to also fire `openQuestLogToQuest` on plain left-click:

```lua
if callbacks and callbacks.onTitleShiftClick then
    local titleBtn = CreateFrame("Button", nil, contentFrame)
    titleBtn:SetAllPoints(titleFs)
    titleBtn:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
        else
            openQuestLogToQuest(questEntry.questID)
        end
    end)
end
```

The guard (`callbacks and callbacks.onTitleShiftClick`) is unchanged from the current code.
The `OnClick` body gains the `if IsShiftKeyDown() ... else ... end` branching. Shift-click
still calls the same callback; left-click calls `openQuestLogToQuest`.

The checkmark rendering guard at line 179 (`callbacks.onTitleShiftClick and questEntry.isTracked`)
is unchanged and fires on exactly the same rows as the overlay guard.

**Party/Shared tab behavior:** `callbacks.onTitleShiftClick` is always nil on these tabs,
so no overlay is created and the title is non-clickable. No visual indication is given —
this is silent and intentional. This holds even when the local player also has the quest
(and `questEntry.logIndex` is therefore non-nil on those rows).

---

## Change 2 — Quest Hyperlinks in Chat Announcements

### File

`Core/Announcements.lua` — `OnQuestEvent` function (line 188).

### Current behavior (lines 194–199)

```lua
local title = (info and info.title)
           or (AQL and AQL:GetQuestTitle(questID))
           or ("Quest " .. questID)
local msg   = formatOutboundQuestMsg(eventType, title)
local chainInfo = questInfo and questInfo.chainInfo
msg = appendChainStep(msg, eventType, chainInfo)
```

### New behavior

AQL callbacks pass a `questInfo` table (the `oldInfo` or `newInfo` snapshot). This table
includes a `link` field containing the WoW quest hyperlink string
(`|cFFFFD200|Hquest:questID:level|h[Title]|h|r`) when available.

Prefer `questInfo.link` as the display value for the chat message. Fall back to `info.link`
(from `AQL:GetQuest`), then the plain title string.

```lua
local title = (info and info.title)
           or (AQL and AQL:GetQuestTitle(questID))
           or ("Quest " .. questID)
local display = (questInfo and questInfo.link)
             or (info and info.link)
             or title
local msg   = formatOutboundQuestMsg(eventType, display)
local chainInfo = questInfo and questInfo.chainInfo
msg = appendChainStep(msg, eventType, chainInfo)
```

`title` is still computed because `self:OnOwnQuestEvent(eventType, title, chainInfo)` (called
at line 237, after the channel dispatch block) requires plain text — it feeds into
`RaidNotice_AddMessage` via `OnOwnQuestEvent`, which cannot render hyperlinks. `appendChainStep`
operates on `msg` (the already-formatted string), not on `title`. `display` is only used to
build `msg`.

### When questInfo.link is populated

`questInfo` is the AQL quest snapshot, which includes `link = GetQuestLink(logIndex)` built
at cache-rebuild time (QuestCache.lua `_buildEntry`). The `link` field is non-nil for all
event types where `questInfo` is passed:

- `accepted` — `questInfo` is the new snapshot; quest is in the log, link is available.
- `completed` — `questInfo` is the pre-removal snapshot; link was captured before turn-in.
- `abandoned` — `questInfo` is the pre-removal snapshot; link was captured while quest was active.
- `failed` — `questInfo` is the pre-removal snapshot; link was captured while quest was active.

The `finished` event (`QUEST_COMPLETE` — quest is ready to turn in) is called as
`OnQuestEvent("finished", questInfo.questID)` with **no third argument**, so `questInfo`
is nil for that event. The fallback `info.link` (from `AQL:GetQuest(questID)`) is used
instead. `AQL:GetQuest` returns `QuestCache:Get(questID)`, which is the `_buildEntry`
result and includes the `link` field. The quest is still in the log at this point so the
QuestCache entry exists, but `GetQuestLink` can return nil if the log entry data has not
yet fully loaded client-side — in that case `info.link` is also nil and the fallback chain
reaches plain `title`, which is always non-nil.

For all other event types (`accepted`, `completed`, `abandoned`, `failed`), `GetQuestLink`
can return nil if the log entry is malformed. In that case the fallback chain reaches plain
`title`, which is always non-nil.

### Banner behavior (unchanged)

`OnOwnQuestEvent` constructs its own banner text using `title` directly and passes it to
`RaidNotice_AddMessage`. That path is unchanged — `RaidNotice_AddMessage` does not render
hyperlink escape sequences and plain title is correct for banners.

---

## Files Changed

| File | Change |
|------|--------|
| `Social-Quest/UI/RowFactory.lua` | Add `openQuestLogToQuest` local helper; update `AddQuestRow` overlay to left-click open quest log |
| `Social-Quest/Core/Announcements.lua` | `OnQuestEvent`: prefer `questInfo.link` / `info.link` over plain title for chat announcements |
| `Social-Quest/SocialQuest.lua` | No change needed — `finished` event intentionally omits `questInfo`; fallback chain handles it |

---

## Testing

1. **Left-click quest name — expanded zone:** Open the Social Quest frame with the Quest Log
   also open and all zone headers expanded. Left-click any quest title. Confirm the Quest Log
   selects that quest.

2. **Left-click quest name (My Quests tab) — basic case:** Open the Social Quest frame.
   Left-click any quest title. Confirm the WoW Quest Log opens (if not already open) and the
   clicked quest is selected and visible.

3. **Collapsed zone header:** Manually collapse a zone header in the Quest Log. Left-click a
   quest from that zone in the Social Quest frame. Confirm the zone expands and the quest is
   selected. Other collapsed zones remain collapsed.

4. **Multiple collapsed zones:** With two or more zones collapsed, click a quest in one of
   them. Confirm only the zone containing the clicked quest expands; the other collapsed
   zones remain collapsed.

5. **Shift-click unchanged:** Shift-click a quest title. Confirm it still triggers
   track/untrack as before (no quest log opens).

6. **Party/Shared tab — no click:** Switch to the Party or Shared tab. Confirm quest titles
   are not clickable (cursor does not change, left-click does nothing).

7. **Left-click — stale quest (no-op):** Remove or turn in a quest so it no longer exists
   in the log, but the Social Quest frame has not yet refreshed. Left-click the now-stale
   row. Confirm no Lua error fires and the Quest Log opens (or stays open) without crashing.

8. **Chat hyperlinks — completed event:** Turn in a quest while in a party. Confirm the
   outbound chat announcement contains a clickable quest link (gold text in brackets).
   Ctrl-click it — a quest preview tooltip should appear.

9. **Chat hyperlinks — accepted event:** Accept a new quest while in a party. Confirm the
   acceptance announcement contains a clickable quest link.

10. **Chat hyperlinks — finished event:** Complete a quest's objectives (so it shows as
    ready to turn in) while in a party. Confirm the "finished" announcement also contains
    a clickable link (uses `info.link` fallback since `questInfo` is nil for this event).

11. **Banner still uses plain text:** Confirm the on-screen completed/accepted/abandoned
    banner uses the plain quest title (no raw escape characters visible).
