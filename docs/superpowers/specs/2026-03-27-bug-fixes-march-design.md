# Bug Fixes: Zone Filter, Flight Path Detection, Quest Accepted False Positives, Mine Tab Progress Bars

> **For agentic workers:** These are four independent bug fixes and one enhancement spanning two repos (SocialQuest and AbsoluteQuestLog). Each issue maps to one or two files. Implement, test, and commit each issue separately.

**Goal:** Fix three behavioral bugs and add progress bars to the Mine tab's objective rows.

**Repos affected:**
- `D:\Projects\Wow Addons\Social-Quest` (Issues 2, 3, 5)
- `D:\Projects\Wow Addons\Absolute-Quest-Log` (Issue 4)

---

## Issue 2 — Zone Filter Shows Parent Zone in Starter Zones

### Problem

`computeFilterState()` in `UI/WindowFilter.lua` calls `SQWowAPI.GetRealZoneText()` to determine the auto-filter zone name. In starter zones like Northshire Abbey, `GetRealZoneText()` returns `"Elwynn Forest"` (the parent zone), but the quest log groups those quests under `"Northshire Valley"` (the sub-zone). The auto-filter therefore never matches any quests.

### Fix

Prefer `GetSubZoneText()` when it returns a non-empty string; fall back to `GetRealZoneText()` otherwise. Sub-zone names match quest log zone headers in starter zones. In normal open-world zones, `GetSubZoneText()` is empty and the fallback fires correctly.

### Files Changed

**`Core/WowAPI.lua`**
Add a thin wrapper for `GetSubZoneText`:
```lua
function SocialQuestWowAPI.GetSubZoneText()
    return GetSubZoneText()
end
```
Place it adjacent to the existing `GetRealZoneText` wrapper.

**`UI/WindowFilter.lua`** — `computeFilterState()`

The function has two branches:
- **Instance branch** (lines 25–36): when inside a dungeon/raid, `GetRealZoneText()` returns the instance name (e.g., `"Wailing Caverns"`), which matches quest log zone headers exactly. `GetSubZoneText()` inside an instance returns interior sub-areas like `"The Barracks"` — these are never quest log headers. **The instance branch stays unchanged.**
- **Zone branch** (lines 38–46): in the open world, `GetRealZoneText()` returns the parent zone. Apply the sub-zone preference here only.

Replace in the zone branch only:
```lua
local zone = SQWowAPI.GetRealZoneText()
if zone and zone ~= "" then
    return {
        filter = { zone = zone },
        label  = string.format(L["Zone: %s"], zone),
    }
end
```
With:
```lua
local subZone = SQWowAPI.GetSubZoneText()
local zone = (subZone and subZone ~= "") and subZone or SQWowAPI.GetRealZoneText()
if zone and zone ~= "" then
    return {
        filter = { zone = zone },
        label  = string.format(L["Zone: %s"], zone),
    }
end
```

### Testing

1. Enter Northshire Abbey (Human/Worgen starter zone). Open SQ window. Confirm filter label reads "Filter: Zone: Northshire Valley" and quests from that zone appear.
2. Enter Elwynn Forest (outside Northshire). Confirm filter reads "Filter: Zone: Elwynn Forest".
3. Enter a dungeon (Deadmines). Confirm instance filter still works (`IsInInstance` path is unchanged).
4. In a normal open-world zone with no sub-zone (e.g. Durotar), confirm filter reads the zone name correctly.

---

## Issue 3 — Flight Path Discovery Detection Silently Fails

### Problem

`OnTaxiMapOpened()` in `SocialQuest.lua` iterates `GetTaxiNodeInfo(i)` and breaks only on `nil`. In WoW TBC, `GetTaxiNodeInfo` can return `""` (empty string) for certain map entries. Empty string is truthy in Lua, so the loop does not break — it continues and inserts `""` as a key into `currentNodes`. This produces a spurious extra entry in the `diff` table, inflating `diffCount` to 2+ for what is actually a single new node. The code path for `diffCount > 1` with `currentCount > 2` is the "mid-game install / ambiguous" silent-absorb branch, so the discovery is never broadcast.

### Fix

Skip (do not break on) empty-string node names. Use `continue`-style logic since Lua has no `continue` keyword:

**`SocialQuest.lua`** — `OnTaxiMapOpened()`
Replace:
```lua
while true do
    local name = SQWowAPI.GetTaxiNodeInfo(i)
    if not name then break end
    currentNodes[name] = true
    i = i + 1
end
```
With:
```lua
while true do
    local name = SQWowAPI.GetTaxiNodeInfo(i)
    if not name then break end
    if name ~= "" then
        currentNodes[name] = true
    end
    i = i + 1
end
```

The `break` on `nil` remains unchanged (end-of-list sentinel). Empty strings are skipped so they never enter `currentNodes` or `diff`. The saved-state update at the bottom of `OnTaxiMapOpened` iterates `currentNodes` to copy entries into `saved` — because `currentNodes` never contains `""` after this fix, `saved[""]` is also never set. No separate change to the saved-state update is needed.

### Testing

Enable SQ debug mode (`/sq config` → Debug). Talk to a flightmaster at a newly discovered location. In the default chat frame, confirm:
- `[SQ][Quest] OnTaxiMapOpened: currentNodes=N saved=M diff=1` — diff is exactly 1 (not inflated by empty strings)
- `[SQ][Quest] OnTaxiMapOpened: announcing new node=<NodeName>`
- `[SQ][Comm] Sent SQ_FLIGHT: <NodeName>`

The party member (with SQ) should see a green banner: `"<Name> unlocked flight path: <NodeName>"`.

To test the mid-game install edge case (many nodes already known): when `diff > 1` and `currentCount > 2`, confirm the silent-absorb still fires (no announcement, no crash).

---

## Issue 4 — False `AQL_QUEST_ACCEPTED` Callbacks on Party Join

### Problem

When a player joins a party, WoW fires `UNIT_QUEST_LOG_CHANGED` for the local player. AQL's `EventEngine` handles this by running `handleQuestLogUpdate()`, which rebuilds `QuestCache` and diffs old vs. new state. If the previous cache was missing any quests (due to a prior rebuild racing a collapsed zone header or another transient API state), those quests appear as "new" in the diff and `AQL_QUEST_ACCEPTED` fires for them. SocialQuest interprets every `AQL_QUEST_ACCEPTED` as a genuine new accept, broadcasting `SQ_UPDATE(accepted)` and displaying an accept banner for quests the player already had.

### Fix

`AQL_QUEST_ACCEPTED` should only fire when WoW's own `QUEST_ACCEPTED` event confirms the player genuinely accepted a quest. EventEngine already receives `QUEST_ACCEPTED` but discards its `questID` argument. The fix adds a `pendingQuestAccepts` set: the `QUEST_ACCEPTED` handler records the questID; `runDiff` clears it when firing the callback; quests that appear "new in cache" without a corresponding `QUEST_ACCEPTED` event are silently absorbed.

**This fix is in `Absolute-Quest-Log/Core/EventEngine.lua`.**

### Files Changed

**`Absolute-Quest-Log/Core/EventEngine.lua`**

**Step 1** — Initialize `pendingQuestAccepts` alongside other EventEngine fields:
```lua
EventEngine.pendingQuestAccepts = {}  -- questIDs for which QUEST_ACCEPTED fired and are awaiting cache diff
```

**Step 2** — Split the `QUEST_ACCEPTED` and `QUEST_REMOVED` cases out of the shared branch in the `OnEvent` handler. Currently:
```lua
elseif event == "QUEST_WATCH_LIST_CHANGED"
    or event == "QUEST_LOG_UPDATE"
    or event == "QUEST_ACCEPTED"
    or event == "QUEST_REMOVED" then
    handleQuestLogUpdate()
```
Change to:
```lua
elseif event == "QUEST_ACCEPTED" then
    local questID = ...
    if questID then
        EventEngine.pendingQuestAccepts[questID] = true
    end
    handleQuestLogUpdate()
elseif event == "QUEST_REMOVED" then
    local questID = ...
    if questID then
        -- Clear any stale pending accept so a future cache inconsistency for this
        -- questID cannot fire AQL_QUEST_ACCEPTED for a quest that has left the log.
        EventEngine.pendingQuestAccepts[questID] = nil
    end
    handleQuestLogUpdate()
elseif event == "QUEST_WATCH_LIST_CHANGED"
    or event == "QUEST_LOG_UPDATE" then
    handleQuestLogUpdate()
```

**Step 3** — Gate the `AQL_QUEST_ACCEPTED` callback in `runDiff`. In the "Detect newly accepted quests" block:

Replace:
```lua
for questID, newInfo in pairs(newCache) do
    if not oldCache[questID] then
        if histCache and histCache:HasCompleted(questID) then
            -- Quest was already completed historically; ignore as a new accept.
            -- (Can happen at login when cache first builds.)
        else
            AQL.callbacks:Fire(AQL.Event.QuestAccepted, newInfo)
            if AQL.debug then
                DEFAULT_CHAT_FRAME:AddMessage(AQL.DBG .. "[AQL] Quest accepted: " .. tostring(questID) ..
                      " \"" .. tostring(newInfo.title) .. "\"" .. AQL.RESET)
            end
        end
    end
end
```
With:
```lua
for questID, newInfo in pairs(newCache) do
    if not oldCache[questID] then
        if histCache and histCache:HasCompleted(questID) then
            -- Quest was already completed historically; ignore as a new accept.
            -- (Can happen at login when cache first builds.)
        elseif EventEngine.pendingQuestAccepts[questID] then
            EventEngine.pendingQuestAccepts[questID] = nil
            AQL.callbacks:Fire(AQL.Event.QuestAccepted, newInfo)
            if AQL.debug then
                DEFAULT_CHAT_FRAME:AddMessage(AQL.DBG .. "[AQL] Quest accepted: " .. tostring(questID) ..
                      " \"" .. tostring(newInfo.title) .. "\"" .. AQL.RESET)
            end
        else
            -- Quest appeared in cache without a QUEST_ACCEPTED event.
            -- Silently absorb: cache inconsistency, group-join UNIT_QUEST_LOG_CHANGED,
            -- or other non-accept log update. Do not fire AQL_QUEST_ACCEPTED.
            if AQL.debug then
                DEFAULT_CHAT_FRAME:AddMessage(AQL.DBG .. "[AQL] Quest absorbed (no QUEST_ACCEPTED event): " ..
                      tostring(questID) .. " \"" .. tostring(newInfo.title) .. "\"" .. AQL.RESET)
            end
        end
    end
end
```

### Versioning

Bump `AbsoluteQuestLog.toc` version after this change.

### Testing

1. **Normal accept:** Accept a quest from an NPC. Confirm SQ banner fires and `SQ_UPDATE(accepted)` is broadcast to party.
2. **Party join (regression test):** Have existing quests in log. Join a party. Confirm no "accepted" banners appear for existing quests.
3. **AQL debug:** Enable AQL debug (`/aql debug on`). Join a party. Confirm `[AQL] Quest absorbed (no QUEST_ACCEPTED event)` messages appear for existing quests rather than `[AQL] Quest accepted`.
4. **Shared quest:** Have a party member share a quest. Confirm the `AQL_QUEST_ACCEPTED` callback still fires (WoW fires `QUEST_ACCEPTED` for shared quests too).

---

## Issue 5 — Mine Tab Objectives Show Plain Text Instead of Progress Bars

### Problem

The Mine tab's `Render()` method calls `rowFactory.AddObjectiveRow()` for each objective, which renders a plain-text colored line (yellow = in progress, green = complete). The Party and Shared tabs use `rowFactory.AddPlayerRow()` with a `nameColumnWidth` argument, which renders WoW-native `StatusBar` progress bars. There is no reason the Mine tab cannot use the same rendering path with an empty name column.

### Fix

Replace the `AddObjectiveRow` for-loops in `MineTab:Render()` with a single `AddPlayerRow` call per quest entry. Pass a synthetic player entry with `name = ""` and `nameColumnWidth = 0`. The 0-width name column is invisible; the bar occupies the full available width from the indent position. The `obj.isFinished` field drives bar color (green when complete), independent of `playerEntry.isComplete`.

**`UI/Tabs/MineTab.lua`** — `Render()`

**Chain quest entries** (currently at `OBJ_INDENT + 8`):
Replace:
```lua
for _, obj in ipairs(entry.objectives or {}) do
    y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT + 8)
end
```
With:
```lua
local objs = entry.objectives or {}
if #objs > 0 then
    y = rowFactory.AddPlayerRow(contentFrame, y, {
        name          = "",
        isMe          = true,
        hasSocialQuest = true,
        hasCompleted  = false,
        needsShare    = false,
        isComplete    = false,
        objectives    = objs,
    }, OBJ_INDENT + 8, 0)
end
```

**Standalone quest entries** (currently at `OBJ_INDENT`):
Replace:
```lua
for _, obj in ipairs(entry.objectives or {}) do
    y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
end
```
With:
```lua
local objs = entry.objectives or {}
if #objs > 0 then
    y = rowFactory.AddPlayerRow(contentFrame, y, {
        name          = "",
        isMe          = true,
        hasSocialQuest = true,
        hasCompleted  = false,
        needsShare    = false,
        isComplete    = false,
        objectives    = objs,
    }, OBJ_INDENT, 0)
end
```

### Why `isComplete = false`

The quest row above the objectives already shows a `(Complete)` badge when `entry.isComplete` is true. Passing `isComplete = false` on the synthetic player entry ensures `AddPlayerRow` does not render a redundant "Complete" text label and instead renders the objective bars (all green when finished), which is more informative.

### Why `nameColumnWidth = 0`

With `nameColumnWidth = 0`, the name label is 0px wide (invisible). `barX = indent + 0 + 4 = indent + 4`, so the bar's left edge is 4px to the right of the indent position — consistent with the Party and Shared tabs' bar rendering. This 4px gap is intentional and correct; the spec's description "fills the remaining content width from the indent" should be read as "from indent + 4". The bar width is `CONTENT_WIDTH - (indent + 4) - 4`.

Objectives without numeric data (`numRequired = nil` or `0`) fall back to `AddPlayerRow`'s plain-text path, which renders `C.white .. "" .. C.reset .. " " .. color .. text`. The empty name prefix adds a single leading space before the objective text — a cosmetic difference from the old `AddObjectiveRow` (no prefix) that is acceptable.

### Testing

1. Open the SQ window → Mine tab. Confirm quest objectives render as progress bars (StatusBar fill, white overlaid text).
2. An in-progress objective (e.g. 4/10 kills): bar partially filled, yellow/orange color.
3. A finished objective (10/10): bar fully filled, green color.
4. A completed quest with all objectives done: all bars green.
5. An objective with no numeric data (event/NPC type): renders as plain text — same appearance as before.
6. Chain quest objectives (indented further): bars render correctly at the deeper indent.

---

## Version Bump

After all SocialQuest changes: bump `SocialQuest.toc` version and add a Version entry to `CLAUDE.md` covering all four changes.

After AQL changes: bump `AbsoluteQuestLog.toc` version and add a Version entry to `Absolute-Quest-Log/CLAUDE.md`.
