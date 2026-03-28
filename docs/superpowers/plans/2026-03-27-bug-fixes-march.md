# March Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three behavioral bugs (zone filter in starter zones, flight path detection, false quest-accepted announcements on party join) and add progress bars to Mine tab objectives.

**Architecture:** Four independent changes across two repos. Tasks 1–2 and 4 are in `D:\Projects\Wow Addons\Social-Quest`. Task 3 is in `D:\Projects\Wow Addons\Absolute-Quest-Log`. Each task is self-contained and can be verified independently in-game.

**Tech Stack:** Lua 5.1 (WoW), AceAddon-3.0, AceComm-3.0, CallbackHandler-1.0, AbsoluteQuestLog-1.0. No automated test framework — all tests are manual in-game verification with SQ debug mode enabled (`/sq config` → Debug tab, or `/aql debug on` for AQL).

**Spec:** `D:\Projects\Wow Addons\Social-Quest\docs\superpowers\specs\2026-03-27-bug-fixes-march-design.md`

---

## File Map

| File | Repo | Change |
|---|---|---|
| `Core/WowAPI.lua` | SocialQuest | Add `GetSubZoneText` wrapper |
| `UI/WindowFilter.lua` | SocialQuest | Prefer sub-zone name in open-world branch |
| `SocialQuest.lua` | SocialQuest | Skip empty strings in taxi node loop |
| `UI/Tabs/MineTab.lua` | SocialQuest | Replace `AddObjectiveRow` with `AddPlayerRow` |
| `SocialQuest.toc` | SocialQuest | Version bump to 2.12.31 |
| `CLAUDE.md` | SocialQuest | Add version 2.12.31 history entry |
| `Core/EventEngine.lua` | AbsoluteQuestLog | Gate `AQL_QUEST_ACCEPTED` on `pendingQuestAccepts` |
| `AbsoluteQuestLog.toc` | AbsoluteQuestLog | Version bump to 2.3.0 |
| `CLAUDE.md` | AbsoluteQuestLog | Add version 2.3.0 history entry |

---

## Task 1: Zone Filter — Prefer Sub-Zone Name in Starter Areas

**Problem:** In Northshire Abbey and similar starter zones, `GetRealZoneText()` returns the parent zone name (`"Elwynn Forest"`), but the quest log groups quests under the sub-zone name (`"Northshire Valley"`). The auto-filter never matches any quests.

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\Core\WowAPI.lua:25`
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\WindowFilter.lua:38-46`

- [ ] **Step 1: Add `GetSubZoneText` wrapper to WowAPI.lua**

Open `Core/WowAPI.lua`. Line 25 currently reads:
```lua
function SocialQuestWowAPI.GetRealZoneText()   return GetRealZoneText()   end
```
Add the new wrapper immediately after it on line 26:
```lua
function SocialQuestWowAPI.GetRealZoneText()   return GetRealZoneText()   end
function SocialQuestWowAPI.GetSubZoneText()     return GetSubZoneText()    end
```

- [ ] **Step 2: Update the zone branch in `computeFilterState()`**

Open `UI/WindowFilter.lua`. The zone branch starts at line 38. Replace:
```lua
    if db.window.autoFilterZone then
        local zone = SQWowAPI.GetRealZoneText()
        if zone and zone ~= "" then
            return {
                filter = { zone = zone },
                label  = string.format(L["Zone: %s"], zone),
            }
        end
    end
```
With:
```lua
    if db.window.autoFilterZone then
        local subZone = SQWowAPI.GetSubZoneText()
        local zone = (subZone and subZone ~= "") and subZone or SQWowAPI.GetRealZoneText()
        if zone and zone ~= "" then
            return {
                filter = { zone = zone },
                label  = string.format(L["Zone: %s"], zone),
            }
        end
    end
```

**Do not touch** the instance branch (lines 25–36). Inside dungeons, `GetRealZoneText()` already returns the instance name (e.g. `"Wailing Caverns"`) which matches quest log headers. `GetSubZoneText()` inside dungeons returns interior sub-areas like `"The Barracks"` — never a quest log header.

- [ ] **Step 3: Verify in-game**

Enable the "Auto-filter to current zone" toggle in `/sq config` → Social Quest Window (it defaults off). Enter Northshire Abbey (Human/Worgen starter zone). Open the SQ window. Confirm:
- Filter label reads `"Filter: Zone: Northshire Valley"` (not `"Elwynn Forest"`)
- Quests from that zone appear in the tab

Then walk out into Elwynn Forest proper. Confirm:
- Filter label reads `"Filter: Zone: Elwynn Forest"`

Enter a dungeon (e.g. Deadmines). Confirm:
- Instance filter still works (filter label shows the instance name, quests for that instance appear)
- The `IsInInstance` branch is unaffected — `GetSubZoneText()` change is in the zone branch only

In a normal open-world zone with no sub-zone (e.g. Durotar — no starter-area nesting). Confirm:
- Filter label reads `"Filter: Zone: Durotar"` (falls back to `GetRealZoneText()` correctly because `GetSubZoneText()` returns `""`)

- [ ] **Step 4: Commit**

```
git add "Core/WowAPI.lua" "UI/WindowFilter.lua"
git commit -m "fix: zone filter uses sub-zone name in starter areas"
```

---

## Task 2: Flight Path Detection — Skip Empty String Node Names

**Problem:** `OnTaxiMapOpened()` iterates `GetTaxiNodeInfo(i)` and breaks only on `nil`. WoW can return `""` (empty string, truthy in Lua) for some entries. This inserts `""` into `currentNodes`, inflating `diffCount` to 2+ for a single real new node. A `diffCount > 1` with `currentCount > 2` hits the "mid-game install / ambiguous" silent-absorb branch and the discovery is never broadcast to the party.

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\SocialQuest.lua:478-483`

- [ ] **Step 1: Fix the taxi node loop**

Open `SocialQuest.lua`. The loop is at lines 478–483 inside `OnTaxiMapOpened()`. Replace:
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

The `break` on `nil` is unchanged (end-of-list sentinel). Empty strings are skipped in-place so iteration continues past them to collect any remaining valid node names.

- [ ] **Step 2: Verify in-game**

Enable SQ debug mode (`/sq config` → Debug tab → Enable Debug). Talk to a flightmaster at a location you have not previously visited (use a character with few flight paths). In the default chat frame, confirm:
- `[SQ][Quest] OnTaxiMapOpened: currentNodes=N saved=M diff=1` — `diff` is exactly 1, not inflated
- `[SQ][Quest] OnTaxiMapOpened: announcing new node=<NodeName>`
- `[SQ][Comm] Sent SQ_FLIGHT: <NodeName>`

A party member with SQ should see a green banner: `"<YourName> unlocked flight path: <NodeName>"`.

If you cannot reproduce a first-visit scenario, check that the `currentNodes=N` count matches your expected number of flight paths and `diff=0` fires correctly on a revisit (no announcement).

**Mid-game install edge case:** With many nodes already known (10+ saved nodes), open the taxi map. Confirm:
- `diff > 1` and `currentCount > 2` path triggers the silent-absorb branch (no announcement, no crash)
- No SQ_FLIGHT message is sent

- [ ] **Step 3: Commit**

```
git add "SocialQuest.lua"
git commit -m "fix: skip empty-string taxi node names in flight path detection"
```

---

## Task 3: AQL — Gate `AQL_QUEST_ACCEPTED` on `QUEST_ACCEPTED` Event

**This task is in a different repo: `D:\Projects\Wow Addons\Absolute-Quest-Log`**

**Problem:** When a player joins a party, WoW fires `UNIT_QUEST_LOG_CHANGED` for the player. AQL's `EventEngine` rebuilds `QuestCache` and runs a diff. If the previous cache was missing any quests (due to a transient rebuild during a collapsed zone header or other race), those quests appear "new" in the diff and `AQL_QUEST_ACCEPTED` fires for them. SocialQuest interprets every `AQL_QUEST_ACCEPTED` as a genuine new accept, announcing it to the party and broadcasting `SQ_UPDATE(accepted)` for quests the player already had.

**Fix:** Track a `pendingQuestAccepts` set. The `QUEST_ACCEPTED` WoW event handler records the questID. `runDiff` only fires `AQL_QUEST_ACCEPTED` when `pendingQuestAccepts[questID]` is set. `QUEST_REMOVED` clears any stale entry. Quests that appear "new in cache" without a matching `QUEST_ACCEPTED` event are silently absorbed.

**Files:**
- Modify: `D:\Projects\Wow Addons\Absolute-Quest-Log\Core\EventEngine.lua:28-32` (initialization)
- Modify: `D:\Projects\Wow Addons\Absolute-Quest-Log\Core\EventEngine.lua:142-156` (runDiff)
- Modify: `D:\Projects\Wow Addons\Absolute-Quest-Log\Core\EventEngine.lua:420-425` (OnEvent handler)

- [ ] **Step 1: Add `pendingQuestAccepts` to EventEngine initialization**

Open `Core/EventEngine.lua`. Lines 28–31 declare EventEngine fields:
```lua
EventEngine.diffInProgress      = false
EventEngine.initialized         = false
EventEngine.pendingTurnIn       = {}  -- questIDs currently awaiting QUEST_REMOVED after turn-in confirmation
EventEngine.debounceGeneration  = 0   -- incremented on every QUEST_LOG_UPDATE; timer fires only when still current
```
Add one line after `pendingTurnIn`:
```lua
EventEngine.diffInProgress      = false
EventEngine.initialized         = false
EventEngine.pendingTurnIn       = {}  -- questIDs currently awaiting QUEST_REMOVED after turn-in confirmation
EventEngine.pendingQuestAccepts = {}  -- questIDs for which QUEST_ACCEPTED fired and are awaiting cache diff
EventEngine.debounceGeneration  = 0   -- incremented on every QUEST_LOG_UPDATE; timer fires only when still current
```

- [ ] **Step 2: Split `QUEST_ACCEPTED` and `QUEST_REMOVED` out of the shared event branch**

In the `OnEvent` handler, lines 420–425 currently read:
```lua
    elseif event == "QUEST_WATCH_LIST_CHANGED"
        or event == "QUEST_LOG_UPDATE"
        or event == "QUEST_ACCEPTED"
        or event == "QUEST_REMOVED" then
        handleQuestLogUpdate()
    end
```
Replace with:
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
    end
```

- [ ] **Step 3: Gate `AQL_QUEST_ACCEPTED` in `runDiff`**

In `runDiff`, the "Detect newly accepted quests" block at lines 142–156 currently reads:
```lua
        -- Detect newly accepted quests (in new, not in old).
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
Replace with:
```lua
        -- Detect newly accepted quests (in new, not in old).
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

- [ ] **Step 4: Verify in-game**

Enable AQL debug (`/aql debug on`). Load into a character that has existing quests.

**Test A — Normal accept:** Talk to an NPC and accept a quest. In chat, confirm `[AQL] Quest accepted: <questID> "<title>"` fires. Confirm SQ shows an accept banner and broadcasts to party if in a group.

**Test B — Party join (no false banners):** Have 10+ quests in your log. Join a party (have a friend invite you or use a second account). Confirm no SQ "accepted" banners appear for existing quests. Confirm NO `[AQL] Quest accepted` messages fire in chat for existing quests.

**Test C — Party join (absorbed messages):** With AQL debug still on, rejoin or join another party. Confirm `[AQL] Quest absorbed (no QUEST_ACCEPTED event): <questID> "<title>"` messages appear in chat for any quests that previously triggered the false positive. These confirm the silent-absorb path is working correctly.

**Test D — Shared quest:** Have a party member share a quest with you. Accept it. Confirm `AQL_QUEST_ACCEPTED` fires (WoW fires `QUEST_ACCEPTED` for shared quests).

- [ ] **Step 5: Bump AQL version to 2.3.0**

Open `AbsoluteQuestLog.toc`. Change:
```
## Version: 2.2.8
```
To:
```
## Version: 2.3.0
```

- [ ] **Step 6: Add version history to AQL CLAUDE.md**

Open `D:\Projects\Wow Addons\Absolute-Quest-Log\CLAUDE.md`. Add the following entry before the `### Version 2.2.8` entry:

```markdown
### Version 2.3.0 (March 2026)
- Bug fix: `AQL_QUEST_ACCEPTED` was firing for quests already in the player's log when `UNIT_QUEST_LOG_CHANGED` fired on party join, causing SocialQuest to announce existing quests as newly accepted. Root cause: `runDiff` fired the callback for any quest appearing "new in cache" regardless of whether the player had actually accepted it. Fix: added `EventEngine.pendingQuestAccepts` set. The `QUEST_ACCEPTED` WoW event handler records the questID; `runDiff` only fires `AQL_QUEST_ACCEPTED` when `pendingQuestAccepts[questID]` is set and clears it on fire. `QUEST_REMOVED` also clears any stale entry. Quests that appear new in a diff without a matching `QUEST_ACCEPTED` event are silently absorbed into the cache with a debug-mode log message.
```

- [ ] **Step 7: Commit AQL changes**

From `D:\Projects\Wow Addons\Absolute-Quest-Log`:
```
git add "Core/EventEngine.lua" "AbsoluteQuestLog.toc" "CLAUDE.md"
git commit -m "fix: gate AQL_QUEST_ACCEPTED on QUEST_ACCEPTED event to prevent false positives on party join"
```

---

## Task 4: Mine Tab — Progress Bars for Objectives

**Problem:** The Mine tab calls `rowFactory.AddObjectiveRow()` for each objective, which renders plain yellow/green text. The Party and Shared tabs use `rowFactory.AddPlayerRow()` with a `nameColumnWidth` argument, which renders WoW-native `StatusBar` progress bars.

**Fix:** Replace both `AddObjectiveRow` for-loops in `MineTab:Render()` with `AddPlayerRow` calls using a synthetic player entry (`name = ""`, `nameColumnWidth = 0`). The 0-width name column is invisible; the bar fills from `indent + 4` to `CONTENT_WIDTH - 4`. Bar color is driven by `obj.isFinished` on each objective (yellow when in-progress, green when complete), independent of the `isComplete = false` on the synthetic entry.

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\Tabs\MineTab.lua:272-274` (chain quest objectives)
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\Tabs\MineTab.lua:297-299` (standalone quest objectives)

- [ ] **Step 1: Replace chain quest objective rows**

Open `UI/Tabs/MineTab.lua`. Around line 272, inside the chain quest step loop, find:
```lua
                    for _, obj in ipairs(entry.objectives or {}) do
                        y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT + 8)
                    end
```
Replace with:
```lua
                    local objs = entry.objectives or {}
                    if #objs > 0 then
                        y = rowFactory.AddPlayerRow(contentFrame, y, {
                            name           = "",
                            isMe           = true,
                            hasSocialQuest = true,
                            hasCompleted   = false,
                            needsShare     = false,
                            isComplete     = false,
                            objectives     = objs,
                        }, OBJ_INDENT + 8, 0)
                    end
```

- [ ] **Step 2: Replace standalone quest objective rows**

Around line 297, inside the standalone quest loop, find:
```lua
                for _, obj in ipairs(entry.objectives or {}) do
                    y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                end
```
Replace with:
```lua
                local objs = entry.objectives or {}
                if #objs > 0 then
                    y = rowFactory.AddPlayerRow(contentFrame, y, {
                        name           = "",
                        isMe           = true,
                        hasSocialQuest = true,
                        hasCompleted   = false,
                        needsShare     = false,
                        isComplete     = false,
                        objectives     = objs,
                    }, OBJ_INDENT, 0)
                end
```

- [ ] **Step 3: Verify in-game**

Open the SQ window → Mine tab.

- An in-progress kill/gather quest (e.g. "Wolves killed: 4/10"): bar is ~40% filled, yellow/orange fill color, white text overlay shows the objective description.
- A finished objective (10/10): bar is fully green.
- A quest with all objectives complete: all bars are green.
- An event/NPC objective with no numeric data: renders as plain text (a single leading space before the objective text — this is expected and acceptable).
- A quest in a chain: objectives appear at `OBJ_INDENT + 8` (slightly more indented than standalone), consistent with how chain steps are indented relative to the chain header.
- Switch to Party tab and back — confirm Mine tab still renders correctly.

- [ ] **Step 4: Commit**

```
git add "UI/Tabs/MineTab.lua"
git commit -m "feat: Mine tab objectives render as progress bars matching Party/Shared tabs"
```

---

## Task 5: Version Bumps for SocialQuest

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\SocialQuest.toc`
- Modify: `D:\Projects\Wow Addons\Social-Quest\CLAUDE.md`

- [ ] **Step 1: Bump SocialQuest version to 2.12.31**

Open `SocialQuest.toc`. Change:
```
## Version: 2.12.30
```
To:
```
## Version: 2.12.31
```

- [ ] **Step 2: Add version history entry to CLAUDE.md**

Open `CLAUDE.md`. Add the following entry before the `### Version 2.12.30` entry:

```markdown
### Version 2.12.31 (March 2026 — Improvements branch)
- Bug fix: zone auto-filter now shows the correct zone name in starter areas (e.g. "Northshire Valley" instead of "Elwynn Forest"). `computeFilterState()` in `WindowFilter.lua` now prefers `GetSubZoneText()` when non-empty; falls back to `GetRealZoneText()` for normal open-world zones. Instance filter branch unchanged — `GetRealZoneText()` is correct inside dungeons/raids.
- Bug fix: flight path discovery detection now correctly broadcasts new nodes to the party. `OnTaxiMapOpened()` loop skips empty-string entries from `GetTaxiNodeInfo()` rather than inserting them into `currentNodes`. Previously, empty strings inflated `diffCount`, triggering the "mid-game install / ambiguous" silent-absorb branch for single new discoveries.
- Feature: Mine tab quest objectives now render as WoW-native `StatusBar` progress bars, matching the Party and Shared tabs. Uses `AddPlayerRow` with an empty name column (`nameColumnWidth = 0`) and a synthetic player entry, reusing the existing bar rendering code without duplication.
```

- [ ] **Step 3: Commit**

```
git add "SocialQuest.toc" "CLAUDE.md"
git commit -m "chore: bump version to 2.12.31"
```
