# SocialQuest — Announce / Display / Debug Redesign — Design Spec

**Date:** 2026-03-14
**Scope:** Overhaul the announcement and banner system; add a per-section "Display Events" control
group; unify objective event handling; add Questie chat suppression; remove `isTracked` from
transmitted data; add a fully self-contained debug test panel with hardcoded demo events.

---

## 1. Event Type Model

Seven canonical event type strings used throughout the system:

| Key | Meaning |
|-----|---------|
| `accepted` | Quest accepted |
| `abandoned` | Quest abandoned |
| `finished` | All objectives complete (not yet turned in) |
| `completed` | Quest turned in |
| `failed` | Quest failed |
| `objective_progress` | Objective count incremented **or decremented** (partial; threshold not crossed) |
| `objective_complete` | Objective count reached its required threshold (e.g. 8/8) |

**Objective regression** is NOT a separate event type. It is announced under `objective_progress`
with a different message suffix ("(regression)"). One toggle controls both directions.

---

## 2. DB Schema Changes

### 2.1 Remove `general.receive`

`general.receive` is replaced entirely by per-section `display` tables (§2.2). Remove from
`GetDefaults()` and all code that reads it.

### 2.2 Add per-section `display` tables

Every section that can receive banner notifications gains a `display` subtable with one key per
event type. Guild is excluded (guild has no incoming banner path).

**Affected sections:** `party`, `raid`, `battleground`

`whisperFriends` is **excluded**: it is an outbound-only channel (we send whispers to friends;
no addon-comm messages are received via the whisper channel). `getSenderSection()` never returns
`"whisperFriends"`, so a `display` subtable there would have no code path that reads it.

```lua
display = {
    accepted           = true,
    abandoned          = true,
    finished           = true,
    completed          = true,
    failed             = true,
    objective_progress = true,   -- raid: true but currently unused (no obj comms to raid)
    objective_complete = true,
}
```

### 2.3 Expand `announce` tables with objective keys

Objective chat announcements go to party / battleground / whisperFriends only — **not raid**
(matching current behaviour; raid chat is already high-volume). Raid's `announce` table keeps
the five quest-event keys only.

**party / battleground / whisperFriends — modify existing `announce`: remove the old `objective` key
and add the two new keys:**
```lua
-- Remove this key from all three sections' announce tables:
objective = true,            -- ← DELETE (orphaned; replaced by the two keys below)

-- Add these keys:
objective_progress = true,   -- set false by default for whisperFriends
objective_complete = true,   -- set false by default for whisperFriends
```

**raid / guild `announce` — no change** (5 quest-event keys only; `objective` was never in raid/guild).

### 2.4 Remove `isTracked` from payloads

`isTracked` is transmitted but never read from remote player data. Remove from:
- `buildQuestPayload()` in `Communications.lua`
- `buildInitPayload()` in `Communications.lua`
- `OnUpdateReceived()` storage in `GroupData.lua`
- `OnInitReceived()` storage in `GroupData.lua`
- All doc comments referencing it

### 2.5 Consolidated `GetDefaults()` reference

The following shows the complete shape of every key touched by §2.1–2.4 inside `GetDefaults()`.
Implementers should use this as a single authoritative reference rather than piecing together
the individual sections above.

```lua
-- REMOVE entirely from GetDefaults():
general = {
    receive = { ... },   -- ← DELETE: replaced by per-section display tables
}

-- UPDATED general section (add displayReceived, keep everything else):
general = {
    displayReceived = true,  -- master banner gate (was: general.receive.* merged here)
    -- ... other existing general keys unchanged ...
},

-- UPDATED party section (add displayReceived, add display{}, replace objective key):
party = {
    -- existing keys unchanged: transmit, announce.{accepted,abandoned,finished,completed,failed}
    displayReceived    = true,
    announce = {
        -- existing 5 quest-event keys unchanged
        objective          = nil,    -- ← REMOVE (was true)
        objective_progress = true,
        objective_complete = true,
    },
    display = {
        accepted           = true,
        abandoned          = true,
        finished           = true,
        completed          = true,
        failed             = true,
        objective_progress = true,
        objective_complete = true,
    },
},

-- UPDATED raid section (add displayReceived, add display{}; announce unchanged):
raid = {
    -- existing keys unchanged: transmit, friendsOnly, announce.{accepted,...,failed}
    displayReceived = true,
    display = {
        accepted           = true,
        abandoned          = true,
        finished           = true,
        completed          = true,
        failed             = true,
        objective_progress = true,
        objective_complete = true,
    },
},

-- guild: no change. Existing announce table already has the five quest-event keys:
--   accepted = true, abandoned = true, finished = true, completed = true, failed = true
-- No display subtable (guild has no inbound banner path).

-- UPDATED battleground section (same pattern as party):
battleground = {
    -- existing keys unchanged: transmit, friendsOnly, announce.{accepted,...,failed}
    displayReceived    = true,
    announce = {
        objective          = nil,    -- ← REMOVE
        objective_progress = true,
        objective_complete = true,
    },
    display = {
        accepted           = true,
        abandoned          = true,
        finished           = true,
        completed          = true,
        failed             = true,
        objective_progress = true,
        objective_complete = true,
    },
},

-- UPDATED whisperFriends section (objective keys off by default; NO display table —
-- whisperFriends is outbound only, so no displayReceived or display subtable):
whisperFriends = {
    -- existing keys unchanged: enabled, groupOnly, announce.{accepted,...,failed}
    announce = {
        objective          = nil,    -- ← REMOVE
        objective_progress = false,  -- off by default for whisperFriends
        objective_complete = false,  -- off by default for whisperFriends
    },
    -- No displayReceived key. No display subtable.
},
```

### 2.6 New color entries

Add to `SocialQuestColors.event` in `Util/Colors.lua`:

```lua
objective_progress = { r = 1,   g = 0.6, b = 0   },  -- orange  (#FF9900)
objective_complete = { r = 0.4, g = 1,   b = 0.4 },  -- lime    (#66FF66)
```

---

## 3. `Announcements.lua` Redesign

The file is restructured into four layers: **pure formatters → display primitives → public event
handlers → debug test entry point**.

### 3.1 Pure message formatters (no I/O, no game-state reads)

```lua
-- Outbound: message sent to chat channels from local player's own events.
local OUTBOUND_QUEST_TEMPLATES = {
    accepted  = "Quest accepted: %s",
    abandoned = "Quest abandoned: %s",
    finished  = "Quest complete (objectives done): %s",
    completed = "Quest turned in: %s",
    failed    = "Quest failed: %s",
}

local function formatOutboundQuestMsg(eventType, questTitle)
    local tmpl = OUTBOUND_QUEST_TEMPLATES[eventType] or "Quest event: %s"
    return string.format(tmpl, questTitle)
end

-- Outbound objective: matches Questie's format so players familiar with Questie
-- read it naturally. isRegression appends " (regression)" to distinguish direction.
local function formatOutboundObjectiveMsg(questTitle, objText, numFulfilled, numRequired, isRegression)
    local suffix = isRegression and " (regression)" or ""
    return string.format("{rt1} SocialQuest: %d/%d %s%s for %s!",
        numFulfilled, numRequired, objText, suffix, questTitle)
end

-- Inbound banner: shown when receiving another player's quest event.
local BANNER_QUEST_TEMPLATES = {
    accepted  = "%s accepted: %s",
    abandoned = "%s abandoned: %s",
    finished  = "%s finished objectives: %s",
    completed = "%s completed: %s",
    failed    = "%s failed: %s",
}

local function formatQuestBannerMsg(sender, eventType, questTitle)
    local tmpl = BANNER_QUEST_TEMPLATES[eventType]
    if not tmpl then return nil end
    return string.format(tmpl, sender, questTitle)
end

-- Inbound banner: shown when receiving another player's objective update.
-- Objective text is not transmitted, so only counts are shown.
local function formatObjectiveBannerMsg(sender, questTitle, numFulfilled, numRequired, isComplete, isRegression)
    if isComplete then
        return string.format("%s completed objective: %s (%d/%d)",
            sender, questTitle, numFulfilled, numRequired)
    elseif isRegression then
        return string.format("%s regressed: %s (%d/%d)",
            sender, questTitle, numFulfilled, numRequired)
    else
        return string.format("%s progressed: %s (%d/%d)",
            sender, questTitle, numFulfilled, numRequired)
    end
end
```

### 3.2 Display primitives

```lua
-- Shows a RaidWarningFrame banner. eventType selects the colour from SocialQuestColors.event.
local function displayBanner(msg, eventType)
    if not RaidWarningFrame then return end
    local color = SocialQuestColors.event[eventType]
    if color then
        RaidWarningFrame:AddMessage(msg, color.r, color.g, color.b)
    else
        RaidWarningFrame:AddMessage(msg)
    end
end

-- Prints a local-only chat preview. Never sends over the network.
-- Used exclusively by the debug test panel.
local function displayChatPreview(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCFFSocialQuest (preview):|r " .. msg)
end
```

### 3.3 Questie suppression helper

```lua
-- Returns true when Questie is installed and configured to announce objective
-- progress to at least one channel, meaning SocialQuest should suppress its own
-- objective chat message to avoid double-printing.
local function questieWouldAnnounceObjective()
    if type(Questie) ~= "table" then return false end
    local profile = Questie.db and Questie.db.profile
    if not profile then return false end
    if not profile.questAnnounceObjectives then return false end
    return profile.questAnnounceChannel ~= "disabled"
end
```

### 3.4 Section detection helper

```lua
-- Determines which settings section applies to a sender based on current group context.
-- Returns "raid", "battleground", or "party" only.
-- "whisperFriends" is never returned: whisper-to-friends is outbound only; inbound
-- addon-comm messages always arrive via PARTY, RAID, or BATTLEGROUND channel contexts.
local function getSenderSection()
    if IsInRaid() then
        return "raid"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "battleground"
    else
        return "party"
    end
end
```

### 3.5 `OnQuestEvent` — local player outbound (unchanged interface, updated internals)

Replaces `formatQuestMessage` inline usage with `formatOutboundQuestMsg`.
Chat channel logic is unchanged. No banner for local player's own quest events.

### 3.6 `OnObjectiveEvent` — local player outbound objective chat

Replaces the old single `"objective"` eventType with `"objective_progress"` /
`"objective_complete"`. Accepts `isRegression bool` parameter.

```lua
function SocialQuestAnnounce:OnObjectiveEvent(eventType, questInfo, objective, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    -- Suppress if Questie would already print this.
    if questieWouldAnnounceObjective() then return end

    local msg = formatOutboundObjectiveMsg(
        questInfo.title,
        objective.text or "",
        objective.numFulfilled,
        objective.numRequired,
        isRegression)

    -- Party
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        if db.party.transmit and db.party.announce[eventType] then
            enqueueChat(msg, "PARTY")
        end
    end

    -- Battleground
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if db.battleground.transmit and db.battleground.announce[eventType] then
            enqueueChat(msg, "BATTLEGROUND")
        end
    end

    -- Whisper friends
    if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
        self:WhisperFriends(msg, db.whisperFriends.groupOnly)
    end
end
```

### 3.7 `OnRemoteQuestEvent` — inbound banner (refactored)

Replaces `general.receive` check with per-section `display` check.

```lua
function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end   -- per-section banner master gate
    if not sectionDb.display[eventType] then return end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end
    if section == "battleground" and db.battleground.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end

    local AQL   = SocialQuest.AQL
    local title = (AQL and AQL:GetQuestLink(questID))
               or C_QuestLog.GetTitleForQuestID(questID)
               or ("Quest " .. questID)

    local msg = formatQuestBannerMsg(sender, eventType, title)
    if msg then displayBanner(msg, eventType) end
end
```

### 3.8 `OnRemoteObjectiveEvent` — NEW inbound objective banner

Called from `GroupData:OnObjectiveReceived`. `isRegression` is determined in GroupData by
comparing the incoming count to the stored count before updating.

```lua
function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, numFulfilled, numRequired, isComplete, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end   -- per-section banner master gate

    local eventType = isComplete and "objective_complete" or "objective_progress"
    if not sectionDb.display[eventType] then return end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end
    if section == "battleground" and db.battleground.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end

    local AQL   = SocialQuest.AQL
    local title = (AQL and AQL:GetQuestLink(questID))
               or C_QuestLog.GetTitleForQuestID(questID)
               or ("Quest " .. questID)

    local msg = formatObjectiveBannerMsg(sender, title, numFulfilled, numRequired, isComplete, isRegression)
    displayBanner(msg, eventType)
end
```

### 3.9 `TestEvent` — debug test entry point

Bypasses **all** filters (displayReceived, section display, Questie suppression). Always shows
both the banner and a local chat preview regardless of current settings.

```lua
-- Hardcoded demo strings for each testable event type.
-- "objective_regression" is a pseudo-type used only by the test panel; it shares
-- the objective_progress colour and toggle in production but has distinct demo text.
local TEST_DEMOS = {
    accepted = {
        outbound = "Quest accepted: A Daunting Task",
        banner   = "TestPlayer accepted: [A Daunting Task]",
        colorKey = "accepted",
    },
    abandoned = {
        outbound = "Quest abandoned: A Daunting Task",
        banner   = "TestPlayer abandoned: [A Daunting Task]",
        colorKey = "abandoned",
    },
    finished = {
        outbound = "Quest complete (objectives done): A Daunting Task",
        banner   = "TestPlayer finished objectives: [A Daunting Task]",
        colorKey = "finished",
    },
    completed = {
        outbound = "Quest turned in: A Daunting Task",
        banner   = "TestPlayer completed: [A Daunting Task]",
        colorKey = "completed",
    },
    failed = {
        outbound = "Quest failed: A Daunting Task",
        banner   = "TestPlayer failed: [A Daunting Task]",
        colorKey = "failed",
    },
    objective_progress = {
        outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer progressed: [A Daunting Task] (3/8)",
        colorKey = "objective_progress",
    },
    objective_complete = {
        outbound = "{rt1} SocialQuest: 8/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer completed objective: [A Daunting Task] (8/8)",
        colorKey = "objective_complete",
    },
    objective_regression = {
        outbound = "{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for [A Daunting Task]!",
        banner   = "TestPlayer regressed: [A Daunting Task] (2/8)",
        colorKey = "objective_progress",   -- same colour as progress
    },
}

function SocialQuestAnnounce:TestEvent(eventType)
    local demo = TEST_DEMOS[eventType]
    if not demo then return end
    displayBanner(demo.banner, demo.colorKey)
    displayChatPreview(demo.outbound)
end
```

---

## 4. `SocialQuest.lua` Changes

### 4.1 Register `AQL_OBJECTIVE_COMPLETED`

Add alongside the existing `AQL_OBJECTIVE_PROGRESSED` registration:

```lua
AQL.RegisterCallback(self, "AQL_OBJECTIVE_COMPLETED", "OnObjectiveCompleted")
```

And unregister in `OnDisable`:

```lua
AQL.UnregisterCallback(self, "AQL_OBJECTIVE_COMPLETED")
```

### 4.2 `OnObjectiveProgressed` — skip when threshold crossed

AQL fires `AQL_OBJECTIVE_PROGRESSED` then immediately `AQL_OBJECTIVE_COMPLETED` when the count
crosses the threshold. Always broadcast the comm (so remote players get current counts), but
suppress the `objective_progress` chat/banner announcement when the objective is now complete —
`OnObjectiveCompleted` will fire next and handle it.

```lua
function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
end
```

### 4.3 `OnObjectiveCompleted` — NEW handler

Comm was already broadcast by `OnObjectiveProgressed` above. Only announce chat/banner here.

```lua
function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
end
```

### 4.4 `OnObjectiveRegressed` — add chat announcement

Currently only broadcasts comm. Now also announces as `objective_progress` with
`isRegression = true`.

```lua
function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
end
```

---

## 5. `Communications.lua` Changes

Remove `isTracked` from both payload builders:

```lua
-- buildQuestPayload: remove
isTracked = questInfo.isTracked and 1 or 0,

-- buildInitPayload: remove
isTracked = info.isTracked and 1 or 0,
```

No other changes to Communications.lua.

---

## 6. `GroupData.lua` Changes

### 6.1 Remove `isTracked` from storage

In `OnUpdateReceived`, remove:
```lua
isTracked = payload.isTracked == 1,
```

In `OnInitReceived`, remove the `isTracked` field from the per-quest table being built.
Update all doc comments to remove references to `isTracked`.

### 6.2 Call `OnRemoteObjectiveEvent` from `OnObjectiveReceived`

Determine regression before updating the stored value, then call the announce function:

```lua
function SocialQuestGroupData:OnObjectiveReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry or not entry.quests then return end
    local quest = entry.quests[payload.questID]
    if not quest then return end

    local obj = quest.objectives[payload.objIndex]
    if not obj then obj = {}; quest.objectives[payload.objIndex] = obj end

    -- Determine direction before updating stored value.
    local isRegression = obj.numFulfilled ~= nil
                     and payload.numFulfilled < obj.numFulfilled
    local isComplete   = payload.isFinished == 1

    obj.numFulfilled = payload.numFulfilled
    obj.numRequired  = payload.numRequired
    obj.isFinished   = isComplete

    -- Banner notification.
    SocialQuestAnnounce:OnRemoteObjectiveEvent(
        sender, payload.questID,
        payload.numFulfilled, payload.numRequired,
        isComplete, isRegression)

    SocialQuestGroupFrame:RequestRefresh()
end
```

---

## 7. `Options.lua` Changes

### 7.1 Full rebuild of `Options.lua`

`Options.lua` is rebuilt from scratch. All existing AceConfig option table keys, helper function
names, and group structures are replaced by the new layout specified in §7.2–§7.3. The existing
`announceGroup()` helper is replaced by the two new helpers (`announceChatGroup()` and
`displayEventsGroup()`). Because this is a full rebuild, there is no partial rename to track —
the implementer deletes the old option table and writes the new one per §7.3.

### 7.2 New helper functions

```lua
-- Builds the "Announce in Chat" inline group.
-- questOnly = true → 5 quest-event keys only (for raid and guild).
-- questOnly = false → all 7 keys (for party, battleground, whisperFriends).
local function announceChatGroup(sectionKey, questOnly)
    local args = {
        accepted  = toggle("Accepted",  "Send a chat message when you accept a quest.",
                           { sectionKey, "announce", "accepted"  }),
        abandoned = toggle("Abandoned", "Send a chat message when you abandon a quest.",
                           { sectionKey, "announce", "abandoned" }),
        finished  = toggle("Finished",  "Send a chat message when all your quest objectives are complete (before turning in).",
                           { sectionKey, "announce", "finished"  }),
        completed = toggle("Completed", "Send a chat message when you turn in a quest.",
                           { sectionKey, "announce", "completed" }),
        failed    = toggle("Failed",    "Send a chat message when a quest fails.",
                           { sectionKey, "announce", "failed"    }),
    }
    if not questOnly then
        args.objective_progress = toggle(
            "Objective Progress",
            "Send a chat message when a quest objective progresses or regresses. "
            .. "Format matches Questie's style. Suppressed automatically if Questie "
            .. "is installed and already announcing objective progress.",
            { sectionKey, "announce", "objective_progress" })
        args.objective_complete = toggle(
            "Objective Complete",
            "Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). "
            .. "Suppressed automatically if Questie is handling this.",
            { sectionKey, "announce", "objective_complete" })
    end
    return { type = "group", name = "Announce in Chat", inline = true, args = args }
end

-- Builds the "Display Events" inline group for controlling which inbound events
-- show a banner on screen. Not added to guild (guild has no banner receive path).
local function displayEventsGroup(sectionKey)
    return {
        type   = "group",
        name   = "Display Events",
        inline = true,
        args   = {
            accepted  = toggle("Accepted",
                "Show a banner on screen when a group member accepts a quest.",
                { sectionKey, "display", "accepted"  }),
            abandoned = toggle("Abandoned",
                "Show a banner on screen when a group member abandons a quest.",
                { sectionKey, "display", "abandoned" }),
            finished  = toggle("Finished",
                "Show a banner on screen when a group member finishes all objectives on a quest.",
                { sectionKey, "display", "finished"  }),
            completed = toggle("Completed",
                "Show a banner on screen when a group member turns in a quest.",
                { sectionKey, "display", "completed" }),
            failed    = toggle("Failed",
                "Show a banner on screen when a group member fails a quest.",
                { sectionKey, "display", "failed"    }),
            objective_progress = toggle("Objective Progress",
                "Show a banner on screen when a group member's quest objective count changes "
                .. "(includes partial progress and regression).",
                { sectionKey, "display", "objective_progress" }),
            objective_complete = toggle("Objective Complete",
                "Show a banner on screen when a group member completes a quest objective (e.g. 8/8).",
                { sectionKey, "display", "objective_complete" }),
        },
    }
end
```

### 7.3 Per-section layout

**General:**
```
enabled         "Master on/off switch for all SocialQuest functionality."
displayReceived "Master switch: allow any banner notifications to appear.
                 Individual 'Display Events' groups below control which event
                 types are shown per section."
```

**Party:**
```
transmit        "Broadcast your quest events to party members via addon comm."
displayReceived "Allow banner notifications from party members (subject to
                 Display Events toggles below)."
announceChatGroup("party", false)
displayEventsGroup("party")
```

**Raid:**
```
transmit        "Broadcast your quest events to raid members via addon comm."
displayReceived "Allow banner notifications from raid members."
friendsOnly     "Only show banner notifications from players on your friends list,
                 suppressing banners from strangers in large raids."
announceChatGroup("raid", true)   -- quest events only; objective chat not sent to raid
displayEventsGroup("raid")
```

**Guild:**
```
transmit        "Announce your quest events in guild chat. Guild members do not
                 need SocialQuest installed to see these messages."
announceChatGroup("guild", true)  -- no Display Events group for guild
```

**Battleground:**
```
transmit        "Broadcast your quest events to battleground members via addon comm."
displayReceived "Allow banner notifications from battleground members."
friendsOnly     "Only show banner notifications from friends in the battleground."
announceChatGroup("battleground", false)
displayEventsGroup("battleground")
```

**Whisper Friends:**
```
enabled         "Send your quest events as whispers to online friends."
groupOnly       "Restrict whispers to friends who are currently in your group."
announceChatGroup("whisperFriends", false)
-- No displayEventsGroup: whisperFriends is outbound only; no inbound banner path.
```

**Follow Notifications:**
```
enabled             "Send a whisper to players you start or stop following, and
                     receive notifications when someone follows you."
announceFollowing   "Whisper the player you begin following so they know you are
                     following them."
announceFollowed    "Display a local message when someone starts or stops following you."
```

**Debug:**
```
enabled             "Print internal debug messages to the chat frame. Useful for
                     diagnosing comm issues or event flow problems."

-- Inline group: "Test Banners and Chat"
testAccepted         execute "Test Accepted"
                     desc "Display a demo banner and local chat preview for the
                           'Quest accepted' event. Bypasses all display filters."
testAbandoned        execute "Test Abandoned"
                     desc "Display a demo banner and local chat preview for the
                           'Quest abandoned' event."
testFinished         execute "Test Finished"
                     desc "Display a demo banner and local chat preview for the
                           'Quest finished objectives' event."
testCompleted        execute "Test Completed"
                     desc "Display a demo banner and local chat preview for the
                           'Quest turned in' event."
testFailed           execute "Test Failed"
                     desc "Display a demo banner and local chat preview for the
                           'Quest failed' event."
testObjProgress      execute "Test Obj. Progress"
                     desc "Display a demo banner and local chat preview for a
                           partial objective progress update (e.g. 3/8)."
testObjComplete      execute "Test Obj. Complete"
                     desc "Display a demo banner and local chat preview for an
                           objective completion (e.g. 8/8)."
testObjRegression    execute "Test Obj. Regression"
                     desc "Display a demo banner and local chat preview for an
                           objective regression (count went backward)."
```

Each `execute` button calls `SocialQuestAnnounce:TestEvent(eventType)`.

---

## 8. Summary of File Changes

| File | Change |
|------|--------|
| `Util/Colors.lua` | Add `objective_progress` and `objective_complete` to `SocialQuestColors.event` |
| `Core/Announcements.lua` | Full restructure: pure formatters, display primitives, Questie suppression, section-aware `OnRemoteQuestEvent`, new `OnRemoteObjectiveEvent`, new `TestEvent` |
| `Core/Communications.lua` | Remove `isTracked` from `buildQuestPayload` and `buildInitPayload` |
| `Core/GroupData.lua` | Remove `isTracked` storage; add `OnRemoteObjectiveEvent` call with regression detection in `OnObjectiveReceived` |
| `SocialQuest.lua` | Register `AQL_OBJECTIVE_COMPLETED`; update `OnObjectiveProgressed` (suppress when complete, always broadcast); add `OnObjectiveCompleted`; update `OnObjectiveRegressed` (add chat announce) |
| `SocialQuest.lua` `GetDefaults()` | Remove `general.receive`; add `general.displayReceived = true`; add `displayReceived = true` to party/raid/battleground; add `display` subtables to party/raid/battleground (whisperFriends is outbound-only — no display subtable); add `objective_progress`/`objective_complete` to party/battleground/whisperFriends announce tables; remove orphaned `objective` key from same three sections |
| `UI/Options.lua` | Full rebuild: rename helpers, two inline groups per section, all tooltips, debug execute buttons |
