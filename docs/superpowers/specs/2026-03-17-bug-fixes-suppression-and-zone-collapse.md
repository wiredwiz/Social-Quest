# Bug Fixes: UIErrorsFrame Suppression and AQL Zone Collapse — Design Spec

## Overview

Two independent bug fixes:

1. **UIErrorsFrame suppression** — the WoW native objective-progress floating text still
   appears even when SocialQuest's own banner is enabled. The previous implementation
   targeted `QUEST_WATCH_UPDATE`, which is not the event path for this notification in
   TBC Classic. The correct event is `UI_INFO_MESSAGE`. Additionally, SocialQuest was
   calling WoW quest log APIs directly to identify objective text; this is replaced by
   a new AQL public method so all quest data access goes through AQL.

2. **AQL zone collapse/expand** — collapsing a zone header in the WoW quest log fires
   `AQL_QUEST_ABANDONED` for every quest in that zone; expanding it fires
   `AQL_QUEST_ACCEPTED`. Root cause: `QuestCache:Rebuild()` discards the `isCollapsed`
   return value of `GetQuestLogTitle()`, so quests under collapsed headers are invisible
   to the rebuild loop and their disappearance is mistaken for abandonment. The fix
   expands all collapsed headers before rebuilding and re-collapses them after, ensuring
   the cache always reflects the complete quest log.

---

## Bug 1 — UIErrorsFrame Suppression

### Root Cause

In TBC Classic (20505), quest objective progress notifications appear in `UIErrorsFrame`
via `UI_INFO_MESSAGE` events, not `QUEST_WATCH_UPDATE`. The previous `InitEventHooks`
intercepted `QUEST_WATCH_UPDATE` (wrong event) and `UpdateQuestWatchSuppression` called
`UIErrorsFrame:UnregisterEvent("QUEST_WATCH_UPDATE")` (also wrong event). Neither had
any effect on the floating notification. Additionally, the previous approach called WoW
quest log APIs directly from SocialQuest; all quest data access must go through AQL.

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

No replacement call is needed in any of these setters — the new approach reads `db`
dynamically in the event handler instead of toggling event registration.

### New AQL Method

Add to `Absolute-Quest-Log/AbsoluteQuestLog.lua`:

```lua
-- Returns true if msg exactly matches the text of any objective in the active quest
-- cache. Used by SocialQuest to identify UI_INFO_MESSAGE events that duplicate its
-- own objective-progress banner. Reads from the live quest cache; the cache is always
-- complete because QuestCache:Rebuild() expands collapsed zones before reading.
function AQL:IsQuestObjectiveText(msg)
    if not msg then return false end
    if not self.QuestCache then return false end
    for _, quest in pairs(self.QuestCache.data) do
        if quest.objectives then
            for _, obj in ipairs(quest.objectives) do
                if obj.text == msg then return true end
            end
        end
    end
    return false
end
```

Place this method after `AQL:GetQuestObjectives` (line 178) to keep objective-related
methods grouped together.

### Updated `InitEventHooks()`

Replace the existing `InitEventHooks` body in `Core/Announcements.lua`:

```lua
function SocialQuestAnnounce:InitEventHooks()
    local orig = UIErrorsFrame:GetScript("OnEvent")
    if not orig then return end
    UIErrorsFrame:SetScript("OnEvent", function(self, event, messageType, msg, ...)
        if event == "UI_INFO_MESSAGE" then
            local db = SocialQuest.db.profile
            local AQL = SocialQuest.AQL
            if db and db.enabled
                    and db.general.displayOwn
                    and db.general.displayOwnEvents.objective_progress
                    and AQL and AQL:IsQuestObjectiveText(msg) then
                return
            end
        end
        return orig(self, event, messageType, msg, ...)
    end)
end
```

`messageType` and `msg` are named explicitly (rather than `...`) so `msg` is available
for `AQL:IsQuestObjectiveText`. The remaining args are forwarded via named params plus
`...`. The `AQL` nil-guard in the closure is belt-and-suspenders: `InitEventHooks` is only
reached after `SocialQuest:OnInitialize` verifies AQL is present, so `SocialQuest.AQL`
is non-nil at hook-install time. The guard is retained as defensive coding for the
closure's runtime scope.

### Invariants

- `orig` is captured at `OnInitialize` time. If another addon installs its own
  `SetScript` hook before SocialQuest's `OnInitialize`, SocialQuest chains to it
  correctly by always calling `orig(...)` when not suppressing.
- Suppression conditions are read dynamically; no event register/unregister is needed
  when settings change.
- Non-objective `UI_INFO_MESSAGE` events (e.g. "New mail") pass through because
  `AQL:IsQuestObjectiveText` only matches active quest objective text.
- `UI_ERROR_MESSAGE` and all other events pass through to `orig` unchanged.
- Because Bug 2's fix ensures the AQL cache always contains all quests (including those
  under collapsed zones), `IsQuestObjectiveText` has complete data to search.

---

## Bug 2 — AQL Zone Collapse/Expand

### Root Cause

`QuestCache:Rebuild()` in `Absolute-Quest-Log/Core/QuestCache.lua` iterates
`GetQuestLogTitle(i)` for `i = 1..GetNumQuestLogEntries()`. In TBC Classic, when a
zone header is collapsed, WoW stops returning the quests under it from this API — they
are absent from the loop. The subsequent `EventEngine.runDiff()` sees those questIDs in
the old cache but not the new cache, and fires `AQL_QUEST_ABANDONED`. On expand the
quests reappear and `AQL_QUEST_ACCEPTED` fires. Any stale-entry workaround would leave
the cache incomplete while zones are collapsed; the correct fix is to ensure the rebuild
always reads the full quest log.

### Fix: Expand-Rebuild-Collapse in `QuestCache:Rebuild()`

The rebuild is wrapped in three phases:

**Phase 1 — Collect collapsed headers.**
Iterate the current quest log entries. When a header row with `isCollapsed == true` is
found, record its `{index = i, title = title}` in a list.

**Phase 2 — Expand all collapsed headers.**
Process the collected list in **reverse index order** (highest index first). This
preserves earlier indices: expanding a header adds entries after it, shifting only
later indices. Call `ExpandQuestHeader(entry.index)` for each.

**Phase 3 — Full rebuild.**
Call `GetNumQuestLogEntries()` again (count has increased). Iterate all entries — now
every quest is visible. Build the cache exactly as today (same `_buildEntry` calls,
same zone tracking).

**Phase 4 — Re-collapse.**
Iterate the now-fully-expanded list to find headers whose titles match the saved
collapsed-header titles. Collect their current indices. Process in **reverse index
order** (collapse back to front, same reason as Phase 2). Call
`CollapseQuestHeader(index)` for each. Zone header titles are assumed to be unique
within the TBC Classic quest log — this holds in practice for all retail TBC zone
data. If two headers shared the same title, both would be collapsed; this is not a
concern for the target build.

**Phase 5 — Restore.**
Call `SelectQuestLogEntry(originalSelection or 0)` as today.

Since all phases execute synchronously within a single Lua call, WoW renders nothing
between Phase 2 and Phase 4. The quest log UI does not visibly change even if the
player has it open.

```lua
function QuestCache:Rebuild()
    local new = {}
    local currentZone = nil
    local logIndexByQuestID = {}
    local originalSelection = GetQuestLogSelection()

    -- Phase 1: Collect collapsed zone headers.
    local collapsedHeaders = {}
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
        if title and isHeader and isCollapsed then
            table.insert(collapsedHeaders, { index = i, title = title })
        end
    end

    -- Phase 2: Expand collapsed headers back-to-front to preserve earlier indices.
    for k = #collapsedHeaders, 1, -1 do
        ExpandQuestHeader(collapsedHeaders[k].index)
    end

    -- Phase 3: Full rebuild — all quests now visible.
    numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, level, suggestedGroup, isHeader, _, isComplete, _, questID =
            GetQuestLogTitle(i)
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

    -- Phase 4: Re-collapse headers that were collapsed before rebuild.
    if #collapsedHeaders > 0 then
        local collapsedTitles = {}
        for _, h in ipairs(collapsedHeaders) do
            collapsedTitles[h.title] = true
        end
        local toCollapse = {}
        numEntries = GetNumQuestLogEntries()
        for i = 1, numEntries do
            local title, _, _, isHeader = GetQuestLogTitle(i)
            if title and isHeader and collapsedTitles[title] then
                table.insert(toCollapse, i)
            end
        end
        -- Collapse back-to-front to preserve earlier indices.
        for k = #toCollapse, 1, -1 do
            CollapseQuestHeader(toCollapse[k])
        end
    end

    -- Phase 5: Restore quest log selection.
    SelectQuestLogEntry(originalSelection or 0)

    local old = self.data
    self.data = new
    return old
end
```

### Invariants

- The cache is always built from the fully-expanded quest log, so every quest is
  represented regardless of the player's zone collapse state.
- The player's visual collapse state is fully restored after the rebuild. Net visual
  effect: none.
- Re-entrancy: `ExpandQuestHeader` and `CollapseQuestHeader` may queue
  `QUEST_LOG_UPDATE` events. AQL's EventEngine re-entrancy guard prevents a second
  `Rebuild()` from starting while the first is still running.
- `SelectQuestLogEntry` is called after the re-collapse pass, as before.
- The `logIndexByQuestID` map built during Phase 3 reflects fully-expanded indices.
  These indices are only used during `_buildEntry` (to read timer and track data), and
  `_buildEntry` calls `SelectQuestLogEntry(logIndex)` using these same indices — which
  are still valid at Phase 3 call time since no collapse has happened yet.

---

## Files Changed

| File | Change |
|------|--------|
| `Absolute-Quest-Log/AbsoluteQuestLog.lua` | Add `AQL:IsQuestObjectiveText(msg)` method |
| `Absolute-Quest-Log/Core/QuestCache.lua` | Replace `Rebuild()` body with expand-rebuild-collapse |
| `Social-Quest/Core/Announcements.lua` | Remove `UpdateQuestWatchSuppression`; rewrite `InitEventHooks` to intercept `UI_INFO_MESSAGE` using `AQL:IsQuestObjectiveText` |
| `Social-Quest/SocialQuest.lua` | Remove `UpdateQuestWatchSuppression()` call from `OnEnable`; remove `UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")` from `OnDisable` |
| `Social-Quest/UI/Options.lua` | Remove three `UpdateQuestWatchSuppression()` call sites |

No changes to `EventEngine.lua`, `HistoryCache.lua`, or any SocialQuest files not listed.

---

## Testing

### Bug 1

1. Enable `displayOwn` and `Objective Progress` banner in SocialQuest settings.
2. Kill a mob that advances a quest objective.
3. Confirm: SocialQuest's own banner appears; the native WoW floating text does NOT.
4. Disable either `displayOwn` or `Objective Progress` in settings.
5. Kill another mob.
6. Confirm: the native WoW floating text appears (no suppression when SQ banner is off).
7. Verify non-objective `UI_INFO_MESSAGE` events (e.g. "New mail") still appear normally.

### Bug 2

1. Accept two or more quests in the same zone.
2. Collapse that zone's header in the quest log.
3. Confirm: no "Quest abandoned" messages appear in chat or banners.
4. Expand the zone header.
5. Confirm: no "Quest accepted" messages appear.
6. Abandon one of those quests normally (right-click → Abandon) while the zone is expanded.
7. Confirm: the abandoned message DOES appear (genuine abandonment still works).
8. With a zone collapsed, progress an objective for a quest in that zone.
9. Expand the zone; confirm AQL correctly reflects the updated objective state.
