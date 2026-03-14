# Party "Everyone Has Completed" Notification — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fire an "Everyone has completed [Quest Name]" purple banner (and optional chat message) when all engaged group members have turned in the same quest, with the feature suppressed entirely if any group member lacks SocialQuest.

**Architecture:** Three small, layered changes. `Colors.lua` adds the new color. `GroupData.lua` writes `completedQuests[questID] = true` in real-time when a remote "completed" event arrives. `Announcements.lua` adds a private `checkAllCompleted` function that evaluates the engaged-player set and fires the notification; it is called from the two existing completion event handlers.

**Tech Stack:** WoW TBC Anniversary (Interface 20505) Lua; AceAddon-3.0, AceDB-3.0; `RaidNotice_AddMessage` for banners; `C_QuestLog.IsQuestFlaggedCompleted` for local completion state.

---

## File Structure

| File | Action | What changes |
|------|--------|-------------|
| `Util/Colors.lua` | Modify | Add `all_complete` entry to `SocialQuestColors.event` and `SocialQuestColors.eventCB` |
| `Core/GroupData.lua` | Modify | One-line write to `completedQuests` inside `OnUpdateReceived` |
| `Core/Announcements.lua` | Modify | New private `checkAllCompleted` function; two call sites in `OnQuestEvent` and `OnRemoteQuestEvent` |

---

## Chunk 1: All three tasks

### Task 1: Colors.lua — Add `all_complete` event color

**Files:**
- Modify: `Util/Colors.lua`

The current `SocialQuestColors.event` table ends at line 26 and `SocialQuestColors.eventCB` ends at line 36. Add `all_complete` as the last entry in each table.

- [ ] **Step 1: Add `all_complete` to `SocialQuestColors.event`**

In `Util/Colors.lua`, find `SocialQuestColors.event`. The last entry before the closing `}` is:
```lua
    objective_complete = { r = 0.4,   g = 1,     b = 0.4   },  -- lime   (#66FF66)
```

Add after it (before the closing `}`):
```lua
    all_complete       = { r = 0.6,   g = 0.0,   b = 0.9   },  -- purple (#9900E6)
```

- [ ] **Step 2: Add `all_complete` to `SocialQuestColors.eventCB`**

In the same file, find `SocialQuestColors.eventCB`. The last entry before the closing `}` is:
```lua
    objective_complete = { r = 0.800, g = 0.475, b = 0.655 },  -- reddish purple (#CC79A7)
```

Add after it (before the closing `}`):
```lua
    all_complete       = { r = 0.0,   g = 0.447, b = 0.698 },  -- blue   (#0072B2, Okabe-Ito)
```

`#0072B2` is the only remaining Okabe-Ito color not yet assigned to another event type.

- [ ] **Step 3: Verify `GetEventColor("all_complete")` will return a value**

`GetEventColor` reads from whichever table is active based on `isColorblindMode()`. Since `all_complete` is now present in both tables, it will always return a non-nil color. No code change needed in `GetEventColor`.

- [ ] **Step 4: Commit**

```bash
git add Util/Colors.lua
git commit -m "feat: add all_complete event color (purple normal, Okabe-Ito blue colorblind)"
```

---

### Task 2: GroupData.lua — Write `completedQuests` on remote completion

**Files:**
- Modify: `Core/GroupData.lua` (lines 87–88)

**Background:** `OnUpdateReceived` handles all incoming `SQ_UPDATE` messages. When `eventType` is `"completed"`, `"abandoned"`, or `"failed"`, the quest is removed from the player's `quests` table. But for `"completed"`, we also need to record it in `completedQuests` so the "everyone completed" check can read it. `abandoned` and `failed` are deliberately excluded — only a successful turn-in counts.

Current code at lines 87–88:
```lua
    if eventType == "abandoned" or eventType == "completed" or eventType == "failed" then
        entry.quests[questID] = nil
```

- [ ] **Step 1: Add `completedQuests` write before the quest removal**

Replace those two lines with:
```lua
    if eventType == "abandoned" or eventType == "completed" or eventType == "failed" then
        if eventType == "completed" then
            entry.completedQuests[questID] = true
        end
        entry.quests[questID] = nil
```

`entry.completedQuests` is guaranteed to exist — `OnGroupChanged` initializes it as `{}` for every player stub, and `OnUpdateReceived` line 78 creates it as `{}` for any new sender. No nil-guard needed.

- [ ] **Step 2: Commit**

```bash
git add Core/GroupData.lua
git commit -m "fix: write completedQuests[questID] on remote completed event in OnUpdateReceived"
```

---

### Task 3: Announcements.lua — Add `checkAllCompleted` and call sites

**Files:**
- Modify: `Core/Announcements.lua`

**Background:** `Announcements.lua` already uses `SocialQuestGroupData.PlayerQuests` (accessed via the global). The new private function `checkAllCompleted` goes in the "Remote event banner notifications" section, just before `OnRemoteQuestEvent` (currently at line 258). It is called from two existing functions:
- `OnQuestEvent` (local player completion) with `localHasCompleted = true`
- `OnRemoteQuestEvent` (remote player completion) with `localHasCompleted = false`

- [ ] **Step 1: Insert `checkAllCompleted` before `OnRemoteQuestEvent`**

In `Core/Announcements.lua`, find the section comment and `OnRemoteQuestEvent` declaration:
```lua
------------------------------------------------------------------------
-- Remote event banner notifications (inbound from other SocialQuest users)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)
```

Insert the new function block **between** the section comment and `OnRemoteQuestEvent`:

```lua
------------------------------------------------------------------------
-- Remote event banner notifications (inbound from other SocialQuest users)
------------------------------------------------------------------------

-- Fires "Everyone has completed [Quest Name]" when every engaged group member
-- (those who have or had the quest) has turned it in.
-- Suppressed entirely if any group member lacks SocialQuest (hasSocialQuest == false).
-- localHasCompleted: true when the local player just triggered this via OnQuestEvent;
--                    false when a remote player's SQ_UPDATE triggered it.
local function checkAllCompleted(questID, localHasCompleted)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local PlayerQuests = SocialQuestGroupData.PlayerQuests

    -- Step 1: must be in a group (PlayerQuests only contains remote members).
    local anyRemote = false
    for _ in pairs(PlayerQuests) do anyRemote = true; break end
    if not anyRemote then return end

    -- Step 2: every group member must have SocialQuest.
    for _, entry in pairs(PlayerQuests) do
        if not entry.hasSocialQuest then return end
    end

    -- Steps 3-5: build engaged set and verify all completed.
    -- "Engaged" = currently has the quest active OR has completed it.
    -- Players who never had the quest are excluded entirely.
    local AQL = SocialQuest.AQL

    -- Local player engagement and completion.
    local localFlagged  = localHasCompleted or C_QuestLog.IsQuestFlaggedCompleted(questID)
    local localActive   = AQL and AQL:GetQuest(questID) ~= nil
    local localEngaged  = localHasCompleted or localActive or localFlagged
    -- If the local player is engaged but hasn't completed the quest, bail out.
    if localEngaged and not localFlagged then return end

    -- Remote player engagement and completion.
    local anyEngaged = localEngaged
    for _, entry in pairs(PlayerQuests) do
        local hasActive    = entry.quests and entry.quests[questID] ~= nil
        local hasCompleted = entry.completedQuests and entry.completedQuests[questID] == true
        local engaged      = hasActive or hasCompleted
        if engaged then
            anyEngaged = true
            if not hasCompleted then return end  -- engaged but not done
        end
    end

    -- Step 4: nobody in the group has or had the quest.
    if not anyEngaged then return end

    -- Step 6a: display gating.
    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.display.completed then return end

    -- Step 6c: title resolution (plain text — RaidNotice does not parse hyperlinks).
    local info  = AQL and AQL:GetQuest(questID)
    local title = (info and info.title)
               or C_QuestLog.GetTitleForQuestID(questID)
               or ("Quest " .. questID)

    -- Step 6d-e: format and show banner.
    local msg = "Everyone has completed: " .. title
    displayBanner(msg, "all_complete")

    -- Step 6f: chat message only when the local player triggered it (avoids duplicate
    -- sends from multiple SQ clients simultaneously detecting the same condition).
    if localHasCompleted and sectionDb.transmit and sectionDb.announce.completed then
        local channelMap = { party = "PARTY", raid = "RAID", battleground = "BATTLEGROUND" }
        local channel = channelMap[section]
        if channel then
            enqueueChat(msg, channel)
        end
    end
end

function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)
```

- [ ] **Step 2: Add call site in `OnQuestEvent`**

Find the end of `OnQuestEvent`. It currently ends with:
```lua
    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnQuestEvent(eventType, title)
end
```

Replace with:
```lua
    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnQuestEvent(eventType, title)

    -- Party-wide completion check: fires "Everyone has completed" when all engaged
    -- group members have turned in this quest.
    if eventType == "completed" then
        checkAllCompleted(questID, true)
    end
end
```

- [ ] **Step 3: Add call site in `OnRemoteQuestEvent`**

Find the end of `OnRemoteQuestEvent`. It currently ends with:
```lua
    local msg = formatQuestBannerMsg(sender, eventType, title)
    if msg then displayBanner(msg, eventType) end
end
```

Replace with:
```lua
    local msg = formatQuestBannerMsg(sender, eventType, title)
    if msg then displayBanner(msg, eventType) end

    -- Party-wide completion check.
    if eventType == "completed" then
        checkAllCompleted(questID, false)
    end
end
```

- [ ] **Step 4: Load WoW and verify**

`/reload`. No Lua errors. In a group where all members have SocialQuest and all have the same quest:
- When the last member turns in the quest, a purple banner reads "Everyone has completed: [Quest Name]"
- The banner does not appear if any group member lacks SocialQuest
- The banner does not appear if any engaged group member has not yet completed the quest
- Click the 8 debug test buttons in `/sq config` → Debug — confirm no Lua errors (the new color key must resolve without crashing)

- [ ] **Step 5: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: add checkAllCompleted — 'Everyone has completed' banner and chat announce"
```
