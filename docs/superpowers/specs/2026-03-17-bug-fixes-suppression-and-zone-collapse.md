# Bug Fixes: UIErrorsFrame Suppression and AQL Zone Collapse — Design Spec

## Overview

Two independent bug fixes:

1. **UIErrorsFrame suppression** — the WoW native objective-progress floating text still appears
   even when SocialQuest's own banner is enabled. The previous implementation targeted
   `QUEST_WATCH_UPDATE`, which is not the event path for this notification in TBC Classic.
   The correct event is `UI_INFO_MESSAGE`.

2. **AQL zone collapse/expand** — collapsing a zone header in the WoW quest log fires
   `AQL_QUEST_ABANDONED` for every quest in that zone; expanding it fires `AQL_QUEST_ACCEPTED`.
   This is a bug in `QuestCache:Rebuild()`: WoW's `GetQuestLogTitle()` silently omits quests
   under collapsed headers, so the cache diff mistakes their disappearance for abandonment.

---

## Bug 1 — UIErrorsFrame Suppression

### Root Cause

In TBC Classic (20505), quest objective progress notifications appear in `UIErrorsFrame` via
`UI_INFO_MESSAGE` events, not `QUEST_WATCH_UPDATE`. The previous `InitEventHooks` intercepted
`QUEST_WATCH_UPDATE` (wrong event) and `UpdateQuestWatchSuppression` called
`UIErrorsFrame:UnregisterEvent("QUEST_WATCH_UPDATE")` (also wrong event). Neither had any
effect on the floating notification.

### Removed Code

All `UpdateQuestWatchSuppression`-related code is removed entirely:

| Location | What is removed |
|----------|----------------|
| `Core/Announcements.lua` | `UpdateQuestWatchSuppression()` function definition |
| `Core/Announcements.lua` | `InitEventHooks()` body replaced (see below) |
| `SocialQuest.lua` | `SocialQuestAnnounce:UpdateQuestWatchSuppression()` call in `OnEnable` |
| `SocialQuest.lua` | `UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")` line in `OnDisable` |
| `UI/Options.lua` | `SocialQuestAnnounce:UpdateQuestWatchSuppression()` call in `objective_progress` setter |
| `UI/Options.lua` | `SocialQuestAnnounce:UpdateQuestWatchSuppression()` call in `db.enabled` setter |
| `UI/Options.lua` | `SocialQuestAnnounce:UpdateQuestWatchSuppression()` call in `displayOwn` setter |

No replacement call is needed in any of these setters — the new approach reads `db` dynamically
in the event handler instead of toggling event registration.

### New Code

Two additions to `Core/Announcements.lua`, placed immediately before `InitEventHooks`:

#### `isQuestObjectiveMessage(msg)`

```lua
-- Returns true when msg exactly matches any active quest objective text in the player's
-- quest log. Used to identify UI_INFO_MESSAGE events that duplicate SocialQuest's own
-- objective-progress banner, so they can be suppressed when displayOwn is active.
-- Uses GetQuestLogLeaderBoard() rather than the AQL cache to read objective text at
-- the moment the event fires (timing-safe: the WoW engine updates the quest log before
-- firing events, so GetQuestLogLeaderBoard reflects the new count when UI_INFO_MESSAGE
-- fires).
local function isQuestObjectiveMessage(msg)
    if not msg then return false end
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader then
            local numObj = GetNumQuestLeaderBoards(i)
            for j = 1, numObj do
                local text = GetQuestLogLeaderBoard(j, i)
                if text == msg then return true end
            end
        end
    end
    return false
end
```

#### Updated `InitEventHooks()`

```lua
function SocialQuestAnnounce:InitEventHooks()
    local orig = UIErrorsFrame:GetScript("OnEvent")
    if not orig then return end
    UIErrorsFrame:SetScript("OnEvent", function(self, event, messageType, msg, ...)
        if event == "UI_INFO_MESSAGE" then
            local db = SocialQuest.db.profile
            if db and db.enabled
                    and db.general.displayOwn
                    and db.general.displayOwnEvents.objective_progress
                    and isQuestObjectiveMessage(msg) then
                return
            end
        end
        return orig(self, event, messageType, msg, ...)
    end)
end
```

`messageType` and `msg` are named explicitly (rather than `...`) so `msg` is available for
`isQuestObjectiveMessage`. The remaining args are forwarded to `orig` via the named params
plus `...`.

### Invariants

- `orig` is captured at `OnInitialize` time. If another addon (e.g. Leatrix Plus) installs
  its own `SetScript` hook before SocialQuest's `OnInitialize`, SocialQuest chains to it
  correctly, since we always call `orig(...)` when not suppressing.
- The suppression condition checks all three settings dynamically; no event
  register/unregister is needed when settings change.
- Non-objective `UI_INFO_MESSAGE` events (e.g. "New mail") are never suppressed because
  `isQuestObjectiveMessage` only matches active quest objective text.
- `UI_ERROR_MESSAGE` and all other events pass through to `orig` unchanged.

---

## Bug 2 — AQL Zone Collapse/Expand

### Root Cause

`QuestCache:Rebuild()` in `Absolute-Quest-Log/Core/QuestCache.lua` iterates
`GetQuestLogTitle(i)` for `i = 1..GetNumQuestLogEntries()`. In TBC Classic, when a zone
header is collapsed, WoW stops returning the quests under it from this API — they are
absent from the loop. The subsequent `EventEngine.runDiff()` sees those questIDs in the
old cache but not the new cache, and fires `AQL_QUEST_ABANDONED`. On expand, the quests
reappear and `AQL_QUEST_ACCEPTED` fires.

### Fix

In `QuestCache:Rebuild()`:

1. Capture `isCollapsed` (5th return value of `GetQuestLogTitle`) — currently discarded
   as `_`.
2. When a header row is encountered with `isCollapsed == true`, record its `title` in a
   local `collapsedZones` set.
3. After the main loop, before assigning `self.data = new`, iterate the old cache: for
   any `questID` whose entry has `zone` matching a name in `collapsedZones` and which
   is absent from `new`, copy the old entry into `new`.

```lua
function QuestCache:Rebuild()
    local new = {}
    local collapsedZones = {}          -- NEW: zone names whose header is collapsed
    local numEntries = GetNumQuestLogEntries()
    local currentZone = nil
    local logIndexByQuestID = {}
    local originalSelection = GetQuestLogSelection()

    for i = 1, numEntries do
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, _, questID =
            GetQuestLogTitle(i)        -- isCollapsed now captured (was _)
        if title then
            local info = {
                title          = title,
                level          = level,
                suggestedGroup = suggestedGroup,
                isHeader       = isHeader,
                isComplete     = isComplete,
                questID        = questID,
            }
            if info.isHeader then
                currentZone = info.title
                if isCollapsed then
                    collapsedZones[info.title] = true   -- NEW
                end
            else
                logIndexByQuestID[questID] = i
                local ok, entryOrErr = pcall(self._buildEntry, self, questID, info, currentZone, i)
                if ok and entryOrErr then
                    new[questID] = entryOrErr
                elseif not ok and AQL.debug then
                    print(AQL.RED .. "[AQL] QuestCache: error building entry for questID "
                        .. tostring(questID) .. ": " .. tostring(entryOrErr) .. AQL.RESET)
                end
            end
        end
    end

    -- NEW: Preserve entries for quests under collapsed zone headers.
    -- When a zone is collapsed, GetQuestLogTitle does not return its quests, so they
    -- would otherwise appear as "abandoned" in runDiff. Copying them from the old cache
    -- prevents false AQL_QUEST_ABANDONED / AQL_QUEST_ACCEPTED events on collapse/expand.
    local old = self.data
    for questID, oldEntry in pairs(old) do
        if not new[questID] and oldEntry.zone and collapsedZones[oldEntry.zone] then
            new[questID] = oldEntry
        end
    end

    SelectQuestLogEntry(originalSelection or 0)
    self.data = new
    return old
end
```

### Invariants

- Only quests whose zone is currently collapsed are preserved; quests that genuinely
  left the log (abandoned, completed, failed) are under zones that remain visible and
  therefore continue to be detected by the diff normally.
- The old entry is preserved as-is (same snapshot). If the quest's objective state
  changes while the zone is collapsed, those changes will be reflected when the zone
  is next expanded and `Rebuild()` sees the quest again.
- `SelectQuestLogEntry(originalSelection or 0)` remains after the `for` loop (it was
  never inside the loop). It is now positioned after the collapsed-zone preservation
  pass rather than before it — a minor positional shift within the post-loop section.

---

## Files Changed

| File | Change |
|------|--------|
| `Social-Quest/Core/Announcements.lua` | Remove `UpdateQuestWatchSuppression`; rewrite `InitEventHooks`; add `isQuestObjectiveMessage` helper |
| `Social-Quest/SocialQuest.lua` | Remove `UpdateQuestWatchSuppression()` call from `OnEnable`; remove `UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")` from `OnDisable` |
| `Social-Quest/UI/Options.lua` | Remove three `UpdateQuestWatchSuppression()` call sites |
| `Absolute-Quest-Log/Core/QuestCache.lua` | Capture `isCollapsed`; track `collapsedZones`; preserve collapsed-zone entries in `Rebuild()` |

---

## Testing

### Bug 1

1. Enable `displayOwn` and `Objective Progress` banner in SocialQuest settings.
2. Kill a mob for an active quest objective.
3. Confirm: SocialQuest's own banner appears; the native WoW floating text does NOT.
4. Disable either `displayOwn` or `Objective Progress` in settings.
5. Kill another mob.
6. Confirm: the native WoW floating text DOES appear (no suppression when SQ banner is off).
7. Verify non-objective `UI_INFO_MESSAGE` events (e.g., "New mail") still appear normally.

### Bug 2

1. Accept two or more quests in the same zone.
2. Collapse that zone's header in the quest log.
3. Confirm: no "Quest abandoned" messages appear in chat or banners.
4. Expand the zone header.
5. Confirm: no "Quest accepted" messages appear.
6. Abandon one of those quests normally (right-click → Abandon).
7. Confirm: the abandoned message DOES appear (genuine abandonment still works).
