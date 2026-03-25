# Design: Suppress False Objective Events from Cursor/Bag Operations

**Date:** 2026-03-24
**Projects:** AbsoluteQuestLog-1.0 (AQL), SocialQuest
**Status:** Approved for implementation

---

## Problem

When a player picks up items onto their cursor (e.g., splitting a bag stack or picking up a stack to move it), WoW fires `QUEST_LOG_UPDATE` / `UNIT_QUEST_LOG_CHANGED` with a temporarily reduced objective count. AQL rebuilds its cache, diffs, and fires `AQL_OBJECTIVE_REGRESSED`. When the player places the items, another event fires and AQL fires `AQL_OBJECTIVE_PROGRESSED` and possibly `AQL_OBJECTIVE_COMPLETED`.

These events represent an unstable intermediate state, not a meaningful change. SocialQuest consumers see false regression and false "objective completed" announcements.

**Concrete failure sequence:**
1. Player has 8/8 quest items (objective complete).
2. Player picks up 2-item stack to merge with 6-item stack.
3. `QUEST_LOG_UPDATE` fires — count reads 6. AQL fires `REGRESSED(8→6)`.
4. Player places items. `QUEST_LOG_UPDATE` fires — count reads 8. AQL fires `PROGRESSED(6→8)` and `COMPLETED`.
5. SocialQuest announces a false "objective completed again."

A 2.0-second debounce was added to SocialQuest as a workaround, but it does not reliably cover the COMPLETED re-fire, and a time-based debounce is the wrong layer for this fix.

---

## Root Cause

`handleQuestLogUpdate()` in AQL's `EventEngine.lua` runs a full cache rebuild on every `QUEST_LOG_UPDATE` / `UNIT_QUEST_LOG_CHANGED` (player) event, including events triggered by bag operations where items are temporarily on the cursor. The intermediate "items on cursor" state is not a valid objective snapshot.

---

## Design

### AQL change — `CursorHasItem()` guard in `EventEngine.lua`

Add an early-return to `handleQuestLogUpdate()` as the **second** check — immediately after the `EventEngine.initialized` guard and **before** the inline NullProvider upgrade block. Placement before the upgrade block is required; inserting it after would allow unnecessary provider selection work to run on every suppressed event.

```lua
local function handleQuestLogUpdate()
    if not EventEngine.initialized then return end

    -- If the player has an item on the cursor, this update is due to a bag
    -- operation in progress. The objective count is an unstable intermediate.
    -- Defer until cursor is empty; the next QUEST_LOG_UPDATE (fired when items
    -- are placed) processes normally with a net-zero diff.
    if CursorHasItem() then
        if AQL.debug then
            DEFAULT_CHAT_FRAME:AddMessage(
                AQL.DBG .. "[AQL] handleQuestLogUpdate: deferred (cursor has item)" .. AQL.RESET)
        end
        return
    end

    -- Belt-and-suspenders: re-attempt provider selection if still on NullProvider.
    if AQL.provider == AQL.NullProvider then
        -- ... existing inline upgrade block (unchanged) ...
    end

    local oldCache = AQL.QuestCache:Rebuild()
    if oldCache == nil then return end
    runDiff(oldCache)
end
```

(`AQL.DBG` and `AQL.RESET` are accessible — `AQL` is captured as a file-scope upvalue at the top of EventEngine.lua via `local AQL = LibStub(...)`.)

`CursorHasItem()` is called directly as a WoW global, consistent with how `GetQuestID()` and `GetTime()` are already used directly in EventEngine.lua. No WowQuestAPI wrapper is needed.

**Why this works:** WoW fires another `QUEST_LOG_UPDATE` when cursor items are placed (the objective count changes again). At that point the cache is rebuilt against the last stable snapshot and the diff sees a net-zero change — no REGRESSED or PROGRESSED events fire.

**Note:** This guard applies to all events that route through `handleQuestLogUpdate()`: `QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED` (player), `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_WATCH_LIST_CHANGED`. In normal gameplay, accepting quests, completing turn-ins, or removing quests cannot occur while the player is actively dragging an item, so suppressing those paths is safe.

**Edge cases:**

- *Quest state change while cursor has item:* Not possible in normal gameplay — you cannot accept quests, kill tracked mobs, or complete turn-ins while actively dragging items. The deferred rebuild triggered by placing items catches any state correctly.

- *Player destroys item from cursor (right-click delete on cursor item):* This is a reachable interaction. WoW will fire `QUEST_LOG_UPDATE` when the item is deleted from the cursor (the count changes permanently). At that point `CursorHasItem()` is false and the rebuild runs normally, seeing the genuine decrease. AQL fires `REGRESSED` correctly. This case is handled without special logic.

- *Player never places items (logs out, etc.):* WoW drops cursor items on logout/reload. The next session starts with a fresh cache build from `PLAYER_LOGIN`, which bypasses `handleQuestLogUpdate()` entirely.

---

### SocialQuest change — remove regression debounce entirely

The `pendingRegressions` debounce was added specifically to suppress false `AQL_OBJECTIVE_REGRESSED` events caused by bag operations. With the AQL fix in place, those events no longer fire. The mechanism is dead code and is removed in full.

**All removals in `SocialQuest.lua`:**

1. In `OnEnable`: remove the `self.pendingRegressions = {}` initialization and its explaining comment block.

2. In `OnObjectiveProgressed`: remove the entire `if self.pendingRegressions[key] then ... end` block (the guard and its body), not just the cancel call inside it.

3. In `OnObjectiveCompleted`: remove the entire `if self.pendingRegressions[key] then ... end` block (the guard and its body).

4. In `OnObjectiveRegressed`: replace the entire debounce scheduling block with a direct announcement.

**Post-removal form of all three handlers:**

```lua
function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    self:Debug("Quest", "Objective " .. objective.numFulfilled .. "/" ..
        objective.numRequired .. ": " .. (objective.name or "") ..
        " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    self:Debug("Quest", "Objective complete " .. objective.numFulfilled .. "/" ..
        objective.numRequired .. ": " .. (objective.name or "") ..
        " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    self:Debug("Quest", "Objective regression " .. objective.numFulfilled .. "/" ..
        objective.numRequired .. ": " .. (objective.name or "") ..
        " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
    SocialQuestGroupFrame:RequestRefresh()
end
```

---

## Files Changed

| File | Change |
|---|---|
| `Absolute-Quest-Log/Core/EventEngine.lua` | Add `CursorHasItem()` guard in `handleQuestLogUpdate()` |
| `Absolute-Quest-Log/Absolute-Quest-Log.toc` | Bump version |
| `Absolute-Quest-Log/CLAUDE.md` | Update version history; note the AQL_OBJECTIVE_REGRESSED callback table entry no longer mentions a debounce (that is a SocialQuest concern, not AQL's) |
| `Social-Quest/SocialQuest.lua` | Remove `pendingRegressions` debounce from `OnEnable`, `OnObjectiveProgressed`, `OnObjectiveCompleted`, `OnObjectiveRegressed` |
| `Social-Quest/CLAUDE.md` | Update version history; update AQL Callbacks table entry for `AQL_OBJECTIVE_REGRESSED` (remove debounce description) |
| `Social-Quest/SocialQuest.toc` | Bump version |

---

## Out of Scope

- No changes to QuestCache, WowQuestAPI, or any other AQL module.
- No changes to SocialQuest's communication layer or GroupData.
- The `pendingTurnIn` suppression in AQL (for regression during NPC turn-in via the `GetQuestReward` hook) is unrelated and unchanged.
