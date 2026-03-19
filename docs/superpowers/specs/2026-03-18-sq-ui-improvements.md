# SocialQuest UI Improvements — Design Spec

**Goal:** Five focused improvements to the SocialQuest group frame and debug panel.

1. Resizable group frame window
2. `(Complete)` badge moved out of quest title row on Party/Shared tabs; replaced by `[Name] Completed` in the player row
3. Debug chat test button that exercises the real quest link path for quest 337
4. Quest title left-click works on all three tabs (not just Mine)
5. Group frame auto-redraws when quest state changes (no longer requires close/reopen)

**Prerequisites:** AQL quest link construction fix (`2026-03-18-aql-quest-link-construction.md`) must be implemented first. Changes 3 and 5 depend on `AQL:GetQuestLink` being available for quests outside the active log.

---

## Change 1 — Resizable Group Frame

**File:** `UI/GroupFrame.lua`

The frame is created with `BasicFrameTemplateWithInset` and is already movable. Add resize support:

- Call `f:SetResizable(true)` and `f:SetResizeBounds(280, 200)` during `createFrame()`. (`SetResizeBounds` is the correct TBC 20505 API; `SetMinResize` was removed before this version.)
- Add a resize handle `Frame` anchored to `BOTTOMRIGHT` of the main frame, sized 16×16. On `OnMouseDown` (left button) call `f:StartSizing("BOTTOMRIGHT")`. On `OnMouseUp` call `f:StopMovingOrSizing()` then `SocialQuestGroupFrame:RequestRefresh()`. Use the standard WoW resize grip texture: `Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up`.
- **Content width is dynamic.** Add `RowFactory.SetContentWidth(w)` — a public setter that writes to the `local CONTENT_WIDTH` upvalue inside `RowFactory.lua`. In `GroupFrame:Refresh()`, before delegating to the tab provider, compute `local contentW = math.floor(frame:GetWidth() - 40)` and call `RowFactory.SetContentWidth(contentW)`. The content frame is recreated on every `Refresh()` call (the `frame.content:Hide()` / `CreateFrame` / `SetSize(360, 1)` block); replace the hardcoded `360` there with `contentW`. Also update the `createFrame()` initial `SetSize(360, 1)` to use the same value for consistency, though it is immediately overwritten by the first `Refresh()`.
- **Size is not persisted.** No AceDB changes. The frame resets to 400×500 on every UI reload.

---

## Change 2 — `(Complete)` Badge and Player Row on Party/Shared Tabs

### 2a. Suppress badge on Party/Shared quest title row

**File:** `UI/RowFactory.lua`

`AddQuestRow` uses `callbacks.onTitleShiftClick ~= nil` as the reliable Mine-tab indicator (Party/Shared always pass `{}`). Gate the `(Complete)` badge on that same indicator:

```lua
-- Before (shows badge on all tabs):
if questEntry.isComplete then
    badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset

-- After (Mine tab only):
if questEntry.isComplete and callbacks and callbacks.onTitleShiftClick then
    badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
```

The `(Group)` badge is unaffected.

### 2b. `[Name] Completed` in player row when objectives done

**File:** `UI/RowFactory.lua` — `AddPlayerRow`

Add an `isComplete` case between the existing `hasCompleted` and `needsShare` branches:

```
Priority order (first matching wins):
  1. hasCompleted  → "[Name] FINISHED"          (green, unchanged)
  2. isComplete    → "[Name] Completed"          (green, new)
  3. needsShare    → "[Name] Needs it Shared"    (grey, unchanged)
  4. no SQ + no objectives → "[Name] (no data)" (grey, unchanged)
  5. else → objective lines                      (unchanged)
```

The `isComplete` line uses `SocialQuestColors.GetUIColor("completed")` (same green as `hasCompleted`). New locale key: `L["%s Completed"]`.

**Files:** `UI/Tabs/PartyTab.lua`, `UI/Tabs/SharedTab.lua`

Populate `isComplete` on each player entry:

- **PartyTab** local player entry (lines ~24–33): add `isComplete = myInfo.isComplete or false`
- **PartyTab** remote player entry (lines ~61–72): add `isComplete = pquest.isComplete or false`
- **SharedTab** local player entries:
  - Chain block (lines ~132–143): `info` is already `AQL:GetQuest(pEng.questID)` — add `isComplete = info and info.isComplete or false`
  - Standalone block (lines ~202–210): the local variable is named `localInfo`, not `info` — add `isComplete = localInfo and localInfo.isComplete or false`
- **SharedTab** remote player entries (both blocks): add `isComplete = pEng.qdata and pEng.qdata.isComplete or false`

**File:** `Locales/enUS.lua`

Add: `L["%s Completed"] = true`

---

## Change 3 — Debug Chat Link Test Button

**Files:** `Core/Announcements.lua`, `UI/Options.lua`, `Locales/enUS.lua`

### New function in `Announcements.lua`

```lua
function SocialQuestAnnounce:TestChatLink()
    local AQL  = SocialQuest.AQL
    local link = AQL and AQL:GetQuestLink(337)
    local msg  = formatOutboundQuestMsg("completed", link or "Quest 337 (no link)")
    displayChatPreview(msg)
end
```

Relies on `AQL:GetQuestLink` (upgraded by the AQL prerequisite spec) to resolve quest 337 from the provider database even if the player doesn't currently have it in their log.

### New button in `Options.lua` debug section

Add to the `testBanners` inline group, after `testAllComplete`:

```lua
testChatLink = {
    type = "execute",
    name = L["Test Chat Link"],
    desc = L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."],
    func = function() SocialQuestAnnounce:TestChatLink() end,
},
```

### New locale keys in `Locales/enUS.lua`

```lua
L["Test Chat Link"] = true
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = true
```

---

## Change 4 — Clickable Quest Titles on All Three Tabs

**File:** `UI/RowFactory.lua` — `AddQuestRow`

The invisible click overlay is currently created only when `callbacks.onTitleShiftClick` is set (Mine tab only). Remove that outer guard and always create the overlay. Inside `OnClick`, gate each action independently:

```lua
-- Always create overlay (was: only when callbacks.onTitleShiftClick present)
local titleBtn = CreateFrame("Button", nil, contentFrame)
titleBtn:SetAllPoints(titleFs)
titleBtn:SetScript("OnClick", function()
    if IsShiftKeyDown() and callbacks and callbacks.onTitleShiftClick then
        -- Mine tab: shift-click track/untrack (unchanged)
        callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
    elseif not IsShiftKeyDown() and questEntry.logIndex then
        -- All tabs: left-click opens Quest Log if player has the quest
        openQuestLogToQuest(questEntry.questID)
    end
    -- else: no logIndex (player doesn't have quest) or unhandled combo → do nothing
end)
```

`questEntry.logIndex` is nil on Party/Shared tabs when the local player does not have the quest, so the `openQuestLogToQuest` call is naturally suppressed. No changes to tab providers.

**Update the existing comment** on the overlay block to reflect the new behaviour.

---

## Change 5 — Auto-Redraw on Quest Change

**File:** `SocialQuest.lua`

`SocialQuestGroupFrame:RequestRefresh()` already exists in `GroupFrame.lua` with correct one-per-frame batching and an early-out when the frame is hidden. It is not currently called from any AQL callback handler.

Add `SocialQuestGroupFrame:RequestRefresh()` as the last statement in each of these handlers:

- `OnQuestAccepted`
- `OnQuestAbandoned`
- `OnQuestFinished`
- `OnQuestCompleted`
- `OnQuestFailed`
- `OnQuestTracked`
- `OnQuestUntracked`
- `OnObjectiveProgressed`
- `OnObjectiveCompleted`
- `OnObjectiveRegressed`
- `OnUnitQuestLogChanged` — note: `GroupData.lua`'s `OnUnitQuestLogChanged` handler already calls `RequestRefresh()`. Adding it here too is safe (the `refreshPending` guard makes it idempotent), but documents the intent that any quest log change — even from a non-SQ member — should update the frame.

All other listed handlers have no existing `RequestRefresh()` calls. No changes to `GroupData.lua` for the other events.

---

## In-Game Verification

**Change 1 — Resize:**
1. Open the group frame. Drag the bottom-right corner to make it taller. Confirm quest rows fill the available height correctly and the content redraws on release.
2. Drag to make it narrower. Confirm quest titles truncate cleanly rather than overflowing.
3. `/reload`. Confirm the frame returns to its default 400×500 size.

**Change 2 — Complete badge / player row:**
1. Have a quest with all objectives done (ready to turn in). Open the Party tab. Confirm `(Complete)` does NOT appear on the quest title row. Confirm the `(You)` row shows `(You) Completed` on a single line with no objective lines below it.
2. Open the Mine tab for the same quest. Confirm `(Complete)` badge still appears on the title row.
3. Have a party member with all objectives done. Confirm their row shows `Name Completed` on the Party/Shared tabs.

**Change 3 — Chat link test button:**
1. Open `Interface Options → SocialQuest → Debug`. Click "Test Chat Link". Confirm the chat preview shows `[SocialQuest (preview):] Quest turned in: [Quest Name]` where the quest name is rendered as clickable gold text. Ctrl-click it to confirm the quest tooltip appears.
2. If the link shows as plain text instead of gold/clickable, `GetQuestLink` is returning nil and the fallback construction in AQL's `_buildEntry` may not be working.

**Change 4 — Clickable titles:**
1. On the Party/Shared tab, left-click a quest title for a quest the player also has. Confirm the Quest Log opens and selects that quest.
2. Left-click a quest title on the Party/Shared tab that only another party member has (player does not have this quest). Confirm nothing happens — no Quest Log opens, no Lua error appears in chat.
3. Shift-click a quest title on the Mine tab. Confirm it still toggles the tracking checkmark.
4. Left-click a quest title on the Mine tab (no shift). Confirm it opens the Quest Log to that quest.

**Change 5 — Auto-redraw:**
1. Open the group frame. Accept a new quest without closing the frame. Confirm the quest appears immediately.
2. Complete objectives on a tracked quest. Confirm the objective progress updates in the frame without closing and reopening.
3. Abandon a quest. Confirm it disappears from the Mine tab immediately.
