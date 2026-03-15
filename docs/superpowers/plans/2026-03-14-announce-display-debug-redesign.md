# Announce / Display / Debug Redesign — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul SocialQuest's announcement and banner system: add colorblind mode, own-quest event banners, per-event-type Questie suppression, per-section display controls, and a debug test panel; remove unused `isTracked` from comm payloads.

**Architecture:** Changes layer cleanly from the foundation up. `Colors.lua` adds the colorblind palette and accessor functions (everything else calls these). `Announcements.lua` is restructured into pure formatters → display primitives → Questie guard → event handlers → own-quest banners → debug panel. `SocialQuest.lua` updates the DB schema and AQL callback wiring. `GroupData.lua` adds regression detection for remote objective banners. `Options.lua` is rebuilt from scratch.

**Tech Stack:** WoW TBC Anniversary (Interface 20505) Lua; AceAddon-3.0, AceDB-3.0, AceConfig-3.0, AceConfigDialog-3.0; AceComm-3.0, AceSerializer-3.0; AbsoluteQuestLog-1.0 (AQL) callbacks.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Util/Colors.lua` | Modify | Add colorblind palette tables and `GetEventColor`/`GetUIColor` accessor functions |
| `UI/RowFactory.lua` | Modify | Replace `C.completed`/`C.failed` with `GetUIColor` accessor calls |
| `Core/Communications.lua` | Modify | Remove `isTracked` from both quest payload builders |
| `Core/GroupData.lua` | Modify | Remove `isTracked` storage; add regression detection + objective banner call |
| `SocialQuest.lua` | Modify | Update `GetDefaults()` schema; update five quest-event callers to pass `questID`; register `AQL_OBJECTIVE_COMPLETED`; update/add objective handlers |
| `Core/Announcements.lua` | Full restructure | New formatters, display primitives, Questie guard, all event handlers, own-quest banners, debug test panel |
| `UI/Options.lua` | Full rebuild | New helper functions and complete option table layout |

**Dependency order (must implement in this sequence):**
1. `Colors.lua` — foundation; accessor functions are called everywhere below
2. `RowFactory.lua` — uses `GetUIColor`; independent of other changes
3. `Communications.lua` — independent; no dependencies
4. `SocialQuest.lua` `GetDefaults()` — independent schema change; must precede Options.lua
5. `Announcements.lua` — must precede SocialQuest.lua callback changes (new signature)
6. `SocialQuest.lua` callbacks — must be committed alongside Announcements.lua (broken in-between)
7. `GroupData.lua` — needs `OnRemoteObjectiveEvent` defined in Announcements.lua
8. `Options.lua` — needs new GetDefaults schema keys to exist

---

## Chunk 1: Foundation — Colors.lua and RowFactory.lua

### Task 1: Colors.lua — Add colorblind palette and accessor functions

**Files:**
- Modify: `Util/Colors.lua`

- [ ] **Step 1: Add `objective_progress` and `objective_complete` to `SocialQuestColors.event`**

Open `Util/Colors.lua`. The current `SocialQuestColors.event` block ends after the `failed` entry on line 23. Add two new entries so the complete block reads:

```lua
SocialQuestColors.event = {
    accepted           = { r = 0,     g = 1,     b = 0     },  -- green  (#00FF00)
    completed          = { r = 1,     g = 0.843, b = 0     },  -- gold   (#FFD700)
    finished           = { r = 0,     g = 0.8,   b = 1     },  -- cyan   (#00CCFF)
    abandoned          = { r = 0.533, g = 0.533, b = 0.533 },  -- grey   (#888888)
    failed             = { r = 1,     g = 0,     b = 0     },  -- red    (#FF0000)
    objective_progress = { r = 1,     g = 0.6,   b = 0     },  -- orange (#FF9900)
    objective_complete = { r = 0.4,   g = 1,     b = 0.4   },  -- lime   (#66FF66)
}
```

- [ ] **Step 2: Add `SocialQuestColors.eventCB` — Okabe-Ito colorblind-safe palette**

After the `SocialQuestColors.event` closing brace, append:

```lua
SocialQuestColors.eventCB = {
    accepted           = { r = 0.337, g = 0.706, b = 0.914 },  -- sky blue       (#56B4E9)
    completed          = { r = 1,     g = 0.843, b = 0     },  -- gold           (#FFD700) unchanged
    finished           = { r = 0,     g = 0.620, b = 0.451 },  -- teal           (#009E73)
    abandoned          = { r = 0.533, g = 0.533, b = 0.533 },  -- grey           (#888888) unchanged
    failed             = { r = 0.835, g = 0.369, b = 0     },  -- vermillion     (#D55E00)
    objective_progress = { r = 0.902, g = 0.624, b = 0     },  -- amber          (#E69F00)
    objective_complete = { r = 0.800, g = 0.475, b = 0.655 },  -- reddish purple (#CC79A7)
}
```

- [ ] **Step 3: Add `SocialQuestColors.cbUI` — colorblind overrides for inline UI text**

After `SocialQuestColors.eventCB`, append:

```lua
SocialQuestColors.cbUI = {
    completed = "|cFF56B4E9",  -- sky blue   (replaces green  #00FF00)
    failed    = "|cFFD55E00",  -- vermillion (replaces red    #FF0000)
}
```

- [ ] **Step 4: Add `isColorblindMode()`, `GetEventColor()`, and `GetUIColor()`**

After `SocialQuestColors.cbUI`, append:

```lua
-- Returns true when colorblind mode is active — either WoW's built-in CVar or the
-- SocialQuest override. The CVar check is intentionally first so WoW's global setting
-- always wins, even if the SocialQuest toggle is off.
local function isColorblindMode()
    if GetCVar("colorblindMode") == "1" then return true end
    return SocialQuest and SocialQuest.db
        and SocialQuest.db.profile.general.colorblindMode == true
end

-- Returns the {r,g,b} color for a banner/chat event type.
-- Always call this instead of indexing SocialQuestColors.event directly.
function SocialQuestColors.GetEventColor(eventType)
    local tbl = isColorblindMode() and SocialQuestColors.eventCB or SocialQuestColors.event
    return tbl[eventType]
end

-- Returns the inline color escape string for a UI text key (e.g. "completed", "failed").
-- Falls back to the standard value when no colorblind override is defined for the key.
function SocialQuestColors.GetUIColor(key)
    if isColorblindMode() and SocialQuestColors.cbUI[key] then
        return SocialQuestColors.cbUI[key]
    end
    return SocialQuestColors[key]
end
```

- [ ] **Step 5: Verify**

Load WoW and `/reload`. No Lua errors in chat. `/sq config` opens without errors.

- [ ] **Step 6: Commit**

```bash
git add Util/Colors.lua
git commit -m "feat: add colorblind palette and GetEventColor/GetUIColor accessors to Colors.lua"
```

---

### Task 2: RowFactory.lua — Use color accessor functions

**Files:**
- Modify: `UI/RowFactory.lua`

- [ ] **Step 1: Replace `C.completed` in `AddObjectiveRow` (line 222)**

Find:
```lua
    local clr = objectiveEntry.isFinished and C.completed or C.active
```
Replace with:
```lua
    local clr = objectiveEntry.isFinished and SocialQuestColors.GetUIColor("completed") or C.active
```

- [ ] **Step 2: Replace `C.completed` in `AddPlayerRow` (line 251)**

Find:
```lua
        fs:SetText(C.completed .. name .. " FINISHED" .. C.reset)
```
Replace with:
```lua
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. name .. " FINISHED" .. C.reset)
```

- [ ] **Step 3: Search for any remaining `C.failed` references and replace**

Search `UI/RowFactory.lua` for `C.failed`. Replace each occurrence with `SocialQuestColors.GetUIColor("failed")`.

- [ ] **Step 4: Verify**

Load WoW and `/reload`. Open the group quest frame (`/sq`). Completed objectives display in green. Toggle Colorblind Mode in `/sq config` → General and `/reload` — completed objectives display in sky blue.

- [ ] **Step 5: Commit**

```bash
git add UI/RowFactory.lua
git commit -m "fix: use GetUIColor accessor in RowFactory for colorblind-aware UI text"
```

---

## Chunk 2: Data Layer — Communications.lua and GroupData.lua

### Task 3: Communications.lua — Remove `isTracked` from payloads

**Files:**
- Modify: `Core/Communications.lua`

- [ ] **Step 1: Remove `isTracked` from `buildQuestPayload` (line 89)**

Find inside `buildQuestPayload()`:
```lua
        isTracked    = questInfo.isTracked   and 1 or 0,
```
Delete that line entirely.

- [ ] **Step 2: Remove `isTracked` from `buildInitPayload` (line 116)**

Find inside `buildInitPayload()`:
```lua
            isTracked    = info.isTracked   and 1 or 0,
```
Delete that line entirely.

- [ ] **Step 3: Verify**

Load WoW and `/reload`. No Lua errors. Quest comms still function (the `isTracked` field is simply absent from future payloads; existing receivers ignore unknown fields).

- [ ] **Step 4: Commit**

```bash
git add Core/Communications.lua
git commit -m "chore: remove unused isTracked from quest and init comm payloads"
```

---

### Task 4: GroupData.lua — Remove `isTracked` storage and add objective banner call

**Files:**
- Modify: `Core/GroupData.lua`

- [ ] **Step 1: Update the top-of-file doc comment (line 10) — remove `isTracked`**

Find:
```lua
--         [questID] = {
--             questID=N, isComplete=bool, isFailed=bool, isTracked=bool,
```
Replace with:
```lua
--         [questID] = {
--             questID=N, isComplete=bool, isFailed=bool,
```

- [ ] **Step 2: Update `OnInitReceived` doc comment (line 53) — remove `isTracked`**

Find:
```lua
-- payload: { quests = { [questID] = { isComplete, isFailed, isTracked,
```
Replace with:
```lua
-- payload: { quests = { [questID] = { isComplete, isFailed,
```

- [ ] **Step 3: Update `OnUpdateReceived` doc comment (line 71) — remove `isTracked`**

Find:
```lua
-- payload: { questID=N, eventType="accepted"|..., isComplete=bool, isFailed=bool,
--            isTracked=bool, snapshotTime=N, timerSeconds=N_or_nil,
```
Replace with:
```lua
-- payload: { questID=N, eventType="accepted"|..., isComplete=bool, isFailed=bool,
--            snapshotTime=N, timerSeconds=N_or_nil,
```

- [ ] **Step 4: Remove `isTracked` from `OnUpdateReceived` storage (line 94)**

Find inside `OnUpdateReceived()` in the `else` branch:
```lua
            isTracked    = payload.isTracked   == 1,
```
Delete that line entirely.

- [ ] **Step 5: Rewrite `OnObjectiveReceived` to add regression detection and banner call**

Replace the entire `OnObjectiveReceived` function body (lines 109–128) with:

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

- [ ] **Step 6: Verify**

Load WoW and `/reload`. No Lua errors. The group frame still updates when group members change objective counts.

- [ ] **Step 7: Commit**

```bash
git add Core/GroupData.lua
git commit -m "feat: add regression detection and objective banner call in OnObjectiveReceived; remove isTracked storage"
```

---

## Chunk 3: Schema — SocialQuest.lua GetDefaults()

### Task 5: SocialQuest.lua — Update `GetDefaults()` schema

**Files:**
- Modify: `SocialQuest.lua`

- [ ] **Step 1: Replace the `general` block — remove `receive`, add new keys**

Find the current `general` block inside `GetDefaults()`:
```lua
            general = {
                displayReceived = true,
                receive = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
```
Replace with:
```lua
            general = {
                displayReceived  = true,
                colorblindMode   = false,
                displayOwn       = false,
                displayOwnEvents = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = true,
                    objective_complete = true,
                },
            },
```

- [ ] **Step 2: Replace the `party` block — update announce, add display**

Find:
```lua
            party = {
                transmit = true,
                displayReceived = true,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=true },
            },
```
Replace with:
```lua
            party = {
                transmit        = true,
                displayReceived = true,
                announce = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
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
```

- [ ] **Step 3: Replace the `raid` block — add display subtable**

Find:
```lua
            raid = {
                transmit = true,
                displayReceived = true,
                friendsOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
```
Replace with:
```lua
            raid = {
                transmit        = true,
                displayReceived = true,
                friendsOnly     = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
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
```

- [ ] **Step 4: Replace the `battleground` block — update announce, add display**

Find:
```lua
            battleground = {
                transmit = true,
                displayReceived = true,
                friendsOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=true },
            },
```
Replace with:
```lua
            battleground = {
                transmit        = true,
                displayReceived = true,
                friendsOnly     = false,
                announce = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
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
```

- [ ] **Step 5: Replace the `whisperFriends` block — update announce keys**

Find:
```lua
            whisperFriends = {
                enabled = false,
                groupOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=false },
            },
```
Replace with:
```lua
            whisperFriends = {
                enabled   = false,
                groupOnly = false,
                announce = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = false,
                    objective_complete = false,
                },
            },
```

- [ ] **Step 6: Verify**

Load WoW and `/reload`. No Lua errors. `/sq config` opens (options will be fixed in Task 8 — some toggles may not appear yet, but no errors).

- [ ] **Step 7: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: update GetDefaults() — remove general.receive, add colorblind/displayOwn/display schema"
```

---

## Chunk 4: Core — Announcements.lua Restructure + SocialQuest.lua Callbacks

### Task 6: Announcements.lua — Full restructure

**Files:**
- Modify: `Core/Announcements.lua`

**What is preserved (do not touch):**
- The throttle queue infrastructure: `throttleQueue`, `lastSendTime`, `THROTTLE_DELAY`, `ticker`, `startThrottleTicker`, `enqueueChat` — keep exactly as-is
- `WhisperFriends` and `IsFriendInGroup` helpers — keep exactly as-is
- `OnFollowStart` and `OnFollowStop` handlers — keep exactly as-is

**What is removed (deleted from the file):**
- `formatQuestMessage` local function (lines 47–57)
- `formatObjectiveMessage` local function (lines 59–61)
- `getAnnouncementChannels` local function (lines 67–100)
- Old `OnQuestEvent` implementation (lines 106–122)
- Old `OnObjectiveEvent` implementation (lines 125–149)
- Old `OnRemoteQuestEvent` implementation (lines 155–189)

**What is added:**
- Pure formatters: `OUTBOUND_QUEST_TEMPLATES`, `formatOutboundQuestMsg`, `formatOutboundObjectiveMsg`, `BANNER_QUEST_TEMPLATES`, `formatQuestBannerMsg`, `formatObjectiveBannerMsg`
- Display primitives: `displayBanner`, `displayChatPreview`
- Questie guard: `QUESTIE_FLAG_FOR`, `questieWouldAnnounce`
- Section helper: `getSenderSection`
- Updated handlers: `OnQuestEvent` (new signature), `OnObjectiveEvent` (new params), `OnRemoteQuestEvent` (new logic)
- New handlers: `OnRemoteObjectiveEvent`, `OnOwnQuestEvent`, `OnOwnObjectiveEvent`
- Debug entry point: `TEST_DEMOS`, `TestEvent`

⚠️ **`OnQuestEvent` signature changes from `(eventType, questInfo)` to `(eventType, questID)`.** The callers in `SocialQuest.lua` are updated in Task 7. Do NOT reload WoW between this task and Task 7 — they must be committed together.

- [ ] **Step 1: Update the file header comment**

Replace the current 8-line header comment block at the top with:

```lua
-- Core/Announcements.lua
-- Drives all chat announcements (outbound from local player's quest events)
-- and banner notifications (inbound from other SocialQuest users).
--
-- Structure (top to bottom):
--   1. Throttle queue: enqueueChat, startThrottleTicker  (unchanged)
--   2. Pure message formatters (no I/O, no game-state reads)
--   3. Display primitives: displayBanner, displayChatPreview
--   4. Questie suppression: QUESTIE_FLAG_FOR, questieWouldAnnounce
--   5. Section detection: getSenderSection
--   6. Public event handlers: OnQuestEvent, OnObjectiveEvent,
--      OnRemoteQuestEvent, OnRemoteObjectiveEvent, OnOwnQuestEvent,
--      OnOwnObjectiveEvent
--   7. Debug test entry point: TestEvent
--   8. Follow notifications + WhisperFriends helpers  (unchanged)
--
-- Chat queue: all SendChatMessage calls pass through a FIFO queue with a
-- 1-second minimum interval to avoid bot-detection throttling. Duplicate
-- messages are dropped before enqueue.
```

- [ ] **Step 2: Delete the three old helpers**

Delete these three blocks entirely (they sit between the throttle queue and `OnQuestEvent`):
- `formatQuestMessage` (lines 47–57, including the "Message formatting" section comment)
- `formatObjectiveMessage` (lines 59–61)
- `getAnnouncementChannels` (lines 67–100, including the "Determine which channels" section comment)

Also delete the "Local quest event announcements" section comment above `OnQuestEvent` (lines 104–105).

- [ ] **Step 3: Add pure message formatters (after throttle queue, before handlers)**

Insert after the throttle queue / `enqueueChat` block:

```lua
------------------------------------------------------------------------
-- Pure message formatters (no I/O, no game-state reads)
------------------------------------------------------------------------

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

-- isRegression appends " (regression)" to distinguish direction.
local function formatOutboundObjectiveMsg(questTitle, objText, numFulfilled, numRequired, isRegression)
    local suffix = isRegression and " (regression)" or ""
    return string.format("{rt1} SocialQuest: %d/%d %s%s for %s!",
        numFulfilled, numRequired, objText, suffix, questTitle)
end

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

- [ ] **Step 4: Add display primitives**

After the pure formatters, insert:

```lua
------------------------------------------------------------------------
-- Display primitives
------------------------------------------------------------------------

local function displayBanner(msg, eventType)
    if not RaidWarningFrame then return end
    local color = SocialQuestColors.GetEventColor(eventType)
    if color then
        RaidWarningFrame:AddMessage(msg, color.r, color.g, color.b)
    else
        RaidWarningFrame:AddMessage(msg)
    end
end

local function displayChatPreview(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCFFSocialQuest (preview):|r " .. msg)
end
```

- [ ] **Step 5: Add Questie suppression helper**

After display primitives, insert:

```lua
------------------------------------------------------------------------
-- Questie suppression
------------------------------------------------------------------------

-- Maps SocialQuest event type → the Questie profile flag that controls the same message.
-- Event types absent from this table are never suppressed (Questie has no equivalent).
-- Research note: Questie only announces objective_complete (threshold reached),
-- never partial progress — so objective_progress is intentionally absent.
local QUESTIE_FLAG_FOR = {
    accepted           = "questAnnounceAccepted",
    abandoned          = "questAnnounceAbandoned",
    completed          = "questAnnounceCompleted",
    objective_complete = "questAnnounceObjectives",
}

local function questieWouldAnnounce(eventType)
    local flag = QUESTIE_FLAG_FOR[eventType]
    if not flag then return false end
    if type(Questie) ~= "table" then return false end
    local profile = Questie.db and Questie.db.profile
    if not profile then return false end
    if not profile[flag] then return false end
    return profile.questAnnounceChannel ~= "disabled"
end
```

- [ ] **Step 6: Add section detection helper**

After the Questie helper, insert:

```lua
------------------------------------------------------------------------
-- Section detection
------------------------------------------------------------------------

-- Returns "raid", "battleground", or "party" only.
-- "whisperFriends" is never returned: whisper-to-friends is outbound only;
-- inbound addon-comm messages always arrive via PARTY, RAID, or BATTLEGROUND.
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

- [ ] **Step 7: Replace `OnQuestEvent` with new implementation**

Where the old `OnQuestEvent` was, write:

```lua
------------------------------------------------------------------------
-- Local quest event announcements (from AQL callbacks)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnQuestEvent(eventType, questID)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local AQL   = SocialQuest.AQL
    local title = AQL and AQL:GetQuestTitle(questID) or ("Quest " .. questID)
    local msg   = formatOutboundQuestMsg(eventType, title)

    if not questieWouldAnnounce(eventType) then
        -- Party
        if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
            if db.party.transmit and db.party.announce[eventType] then
                enqueueChat(msg, "PARTY")
            end
        end

        -- Raid
        if IsInRaid() then
            if db.raid.transmit and db.raid.announce[eventType] then
                enqueueChat(msg, "RAID")
            end
        end

        -- Guild
        if IsInGuild() then
            if db.guild.transmit and db.guild.announce[eventType] then
                enqueueChat(msg, "GUILD")
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

    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnQuestEvent(eventType, title)
end
```

- [ ] **Step 8: Replace `OnObjectiveEvent` with new implementation**

Where the old `OnObjectiveEvent` was, write:

```lua
-- Objective progress/complete/regression — party + battleground + whisper only.
-- isRegression is true when the count decreased (e.g. party member died).
function SocialQuestAnnounce:OnObjectiveEvent(eventType, questInfo, objective, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    if not questieWouldAnnounce(eventType) then
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

    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnObjectiveEvent(eventType, questInfo, objective, isRegression)
end
```

- [ ] **Step 9: Replace `OnRemoteQuestEvent` with new implementation**

Where the old `OnRemoteQuestEvent` was (and its section comment), write:

```lua
------------------------------------------------------------------------
-- Remote event banner notifications (inbound from other SocialQuest users)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end
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

- [ ] **Step 10: Add `OnRemoteObjectiveEvent` (new)**

After `OnRemoteQuestEvent`, insert:

```lua
function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, numFulfilled, numRequired, isComplete, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end

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

- [ ] **Step 11: Add `OnOwnQuestEvent` and `OnOwnObjectiveEvent` (new)**

After `OnRemoteObjectiveEvent`, insert:

```lua
------------------------------------------------------------------------
-- Own-quest banners (local player's own events, opt-in)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle)
    local db = SocialQuest.db.profile
    if not db.enabled then return end
    if not db.general.displayOwn then return end
    if not db.general.displayOwnEvents[eventType] then return end

    local msg = formatQuestBannerMsg("You", eventType, questTitle)
    if msg then displayBanner(msg, eventType) end
end

function SocialQuestAnnounce:OnOwnObjectiveEvent(eventType, questInfo, objective, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled then return end
    if not db.general.displayOwn then return end
    if not db.general.displayOwnEvents[eventType] then return end

    local msg = formatObjectiveBannerMsg(
        "You", questInfo.title,
        objective.numFulfilled, objective.numRequired,
        eventType == "objective_complete", isRegression)
    displayBanner(msg, eventType)
end
```

- [ ] **Step 12: Add `TestEvent` debug entry point**

After the own-quest handlers (before the follow notification section), insert:

```lua
------------------------------------------------------------------------
-- Debug test entry point
------------------------------------------------------------------------

-- "objective_regression" is a pseudo-type used only by the test panel; it shares
-- the objective_progress color and toggle but has distinct demo text.
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
        colorKey = "objective_progress",   -- same color as progress
    },
}

function SocialQuestAnnounce:TestEvent(eventType)
    local demo = TEST_DEMOS[eventType]
    if not demo then return end
    displayBanner(demo.banner, demo.colorKey)
    displayChatPreview(demo.outbound)
end
```

- [ ] **Step 13: Do NOT load WoW yet**

The callers in `SocialQuest.lua` still pass `questInfo` (a table) to `OnQuestEvent`, but the new implementation expects `questID` (a number). A runtime error will fire on the next quest event. Complete Task 7 before reloading.

---

### Task 7: SocialQuest.lua — Update AQL callback wiring

**Files:**
- Modify: `SocialQuest.lua`

This task must be committed **together with Task 6**. The addon is in a broken state until both are complete.

- [ ] **Step 1: Update `OnQuestAccepted` through `OnQuestFailed` — pass `questID` not `questInfo`**

Replace all five handlers:

```lua
function SocialQuest:OnQuestAccepted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
end

function SocialQuest:OnQuestFinished(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
end

function SocialQuest:OnQuestFailed(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
end
```

- [ ] **Step 2: Register `AQL_OBJECTIVE_COMPLETED` in `OnEnable`**

After:
```lua
    AQL.RegisterCallback(self, "AQL_OBJECTIVE_REGRESSED",    "OnObjectiveRegressed")
```
Add:
```lua
    AQL.RegisterCallback(self, "AQL_OBJECTIVE_COMPLETED",    "OnObjectiveCompleted")
```

- [ ] **Step 3: Unregister `AQL_OBJECTIVE_COMPLETED` in `OnDisable`**

After:
```lua
        AQL.UnregisterCallback(self, "AQL_OBJECTIVE_REGRESSED")
```
Add:
```lua
        AQL.UnregisterCallback(self, "AQL_OBJECTIVE_COMPLETED")
```

- [ ] **Step 4: Rewrite `OnObjectiveProgressed`**

Replace:
```lua
function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    SocialQuestAnnounce:OnObjectiveEvent("objective", questInfo, objective)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
end
```
With:
```lua
function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
end
```

- [ ] **Step 5: Add `OnObjectiveCompleted` handler (new)**

After `OnObjectiveProgressed`, insert:

```lua
function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
end
```

- [ ] **Step 6: Update `OnObjectiveRegressed` — add chat announce**

Replace:
```lua
function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    -- Broadcast regression so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
end
```
With:
```lua
function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
end
```

- [ ] **Step 7: Load WoW and verify**

`/reload`. No Lua errors. Accept a test quest — confirm no runtime errors fire. If Questie is installed with `questAnnounceAccepted` enabled, the SocialQuest chat message is suppressed. If not, the message prints normally to party/raid/etc. as configured.

- [ ] **Step 8: Commit (includes both Tasks 6 and 7)**

```bash
git add Core/Announcements.lua SocialQuest.lua
git commit -m "feat: restructure Announcements.lua; add colorblind banners, Questie guard, own-quest banners, TestEvent; update SocialQuest.lua callback wiring"
```

---

## Chunk 5: Options.lua Rebuild

### Task 8: Options.lua — Full rebuild

**Files:**
- Modify: `UI/Options.lua`

This is a complete rewrite of the option table and helpers inside `SocialQuestOptions:Initialize()`.

**Preserved (do not touch):**
- `SocialQuestOptions = {}` declaration (line 4)
- `SocialQuestOptions:Initialize()` signature (line 6)
- Inside `Initialize()`: `AceConfig`, `AceConfigDialog`, `db` locals (lines 7–9)
- `get()` and `set()` local helpers (lines 11–24)
- `toggle()` local helper (lines 26–42) — keep exactly as-is
- `AceConfig:RegisterOptionsTable(...)` and `AceConfigDialog:AddToBlizOptions(...)` calls (lines 166–167)

**Replaced:**
- `announceGroup()` helper — deleted; replaced by `announceChatGroup()`, `displayEventsGroup()`, `ownDisplayEventsGroup()`
- The entire `options` table

- [ ] **Step 1: Delete `announceGroup` and replace with three new helpers**

Delete the `announceGroup` function (lines 44–57). In its place, insert the three new helpers:

```lua
    -- Builds the "Announce in Chat" inline group.
    -- questOnly = true → 5 quest-event keys only (raid and guild).
    -- questOnly = false → all 7 keys (party, battleground, whisperFriends).
    local function announceChatGroup(sectionKey, questOnly)
        local args = {
            accepted  = toggle("Accepted",
                "Send a chat message when you accept a quest.",
                { sectionKey, "announce", "accepted"  }),
            abandoned = toggle("Abandoned",
                "Send a chat message when you abandon a quest.",
                { sectionKey, "announce", "abandoned" }),
            finished  = toggle("Finished",
                "Send a chat message when all your quest objectives are complete (before turning in).",
                { sectionKey, "announce", "finished"  }),
            completed = toggle("Completed",
                "Send a chat message when you turn in a quest.",
                { sectionKey, "announce", "completed" }),
            failed    = toggle("Failed",
                "Send a chat message when a quest fails.",
                { sectionKey, "announce", "failed"    }),
        }
        if not questOnly then
            args.objective_progress = toggle(
                "Objective Progress",
                "Send a chat message when a quest objective progresses or regresses. "
                .. "Format matches Questie's style. Never suppressed by Questie — "
                .. "Questie does not announce partial progress.",
                { sectionKey, "announce", "objective_progress" })
            args.objective_complete = toggle(
                "Objective Complete",
                "Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). "
                .. "Suppressed automatically if Questie is installed and its "
                .. "'Announce Objectives' setting is enabled.",
                { sectionKey, "announce", "objective_complete" })
        end
        return { type = "group", name = "Announce in Chat", inline = true, args = args }
    end

    -- Builds the "Own Quest Banners" inline group under General.
    local function ownDisplayEventsGroup()
        return {
            type   = "group",
            name   = "Own Quest Banners",
            inline = true,
            args   = {
                accepted  = toggle("Accepted",
                    "Show a banner when you accept a quest.",
                    { "general", "displayOwnEvents", "accepted"  }),
                abandoned = toggle("Abandoned",
                    "Show a banner when you abandon a quest.",
                    { "general", "displayOwnEvents", "abandoned" }),
                finished  = toggle("Finished",
                    "Show a banner when all objectives on a quest are complete (before turning in).",
                    { "general", "displayOwnEvents", "finished"  }),
                completed = toggle("Completed",
                    "Show a banner when you turn in a quest.",
                    { "general", "displayOwnEvents", "completed" }),
                failed    = toggle("Failed",
                    "Show a banner when a quest fails.",
                    { "general", "displayOwnEvents", "failed"    }),
                objective_progress = toggle("Objective Progress",
                    "Show a banner when one of your quest objectives progresses or regresses.",
                    { "general", "displayOwnEvents", "objective_progress" }),
                objective_complete = toggle("Objective Complete",
                    "Show a banner when one of your quest objectives reaches its goal (e.g. 8/8).",
                    { "general", "displayOwnEvents", "objective_complete" }),
            },
        }
    end

    -- Builds the "Display Events" inline group (inbound banner controls).
    -- Not added to guild or whisperFriends (no inbound banner path for either).
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

- [ ] **Step 2: Replace the `options` table**

Delete the entire old `options = { ... }` block (lines 59–164) and replace with:

```lua
    local options = {
        type = "group",
        name = "SocialQuest",
        args = {

            general = {
                type  = "group",
                name  = "General",
                order = 1,
                args  = {
                    enabled         = toggle("Enable SocialQuest",
                        "Master on/off switch for all SocialQuest functionality.",
                        { "enabled" }),
                    displayReceived = toggle("Show received events",
                        "Master switch: allow any banner notifications to appear. "
                        .. "Individual 'Display Events' groups below control which event "
                        .. "types are shown per section.",
                        { "general", "displayReceived" }),
                    colorblindMode  = toggle("Colorblind Mode",
                        "Use colorblind-friendly colors for all SocialQuest banners and "
                        .. "UI text. It is unnecessary to enable this if Color Blind mode is "
                        .. "already enabled in the game client.",
                        { "general", "colorblindMode" }),
                    displayOwn      = toggle("Show banners for your own quest events",
                        "Show a banner on screen for your own quest events.",
                        { "general", "displayOwn" }),
                    ownDisplayEvents = ownDisplayEventsGroup(),
                },
            },

            party = {
                type  = "group",
                name  = "Party",
                order = 2,
                args  = {
                    transmit        = toggle("Enable transmission",
                        "Broadcast your quest events to party members via addon comm.",
                        { "party", "transmit" }),
                    displayReceived = toggle("Show received events",
                        "Allow banner notifications from party members (subject to "
                        .. "Display Events toggles below).",
                        { "party", "displayReceived" }),
                    announceChat    = announceChatGroup("party", false),
                    displayEvents   = displayEventsGroup("party"),
                },
            },

            raid = {
                type  = "group",
                name  = "Raid",
                order = 3,
                args  = {
                    transmit        = toggle("Enable transmission",
                        "Broadcast your quest events to raid members via addon comm.",
                        { "raid", "transmit" }),
                    displayReceived = toggle("Show received events",
                        "Allow banner notifications from raid members.",
                        { "raid", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends",
                        "Only show banner notifications from players on your friends list, "
                        .. "suppressing banners from strangers in large raids.",
                        { "raid", "friendsOnly" }),
                    announceChat    = announceChatGroup("raid", true),
                    displayEvents   = displayEventsGroup("raid"),
                },
            },

            guild = {
                type  = "group",
                name  = "Guild",
                order = 4,
                args  = {
                    transmit     = toggle("Enable chat announcements",
                        "Announce your quest events in guild chat. Guild members do not "
                        .. "need SocialQuest installed to see these messages.",
                        { "guild", "transmit" }),
                    announceChat = announceChatGroup("guild", true),
                },
            },

            battleground = {
                type  = "group",
                name  = "Battleground",
                order = 5,
                args  = {
                    transmit        = toggle("Enable transmission",
                        "Broadcast your quest events to battleground members via addon comm.",
                        { "battleground", "transmit" }),
                    displayReceived = toggle("Show received events",
                        "Allow banner notifications from battleground members.",
                        { "battleground", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends",
                        "Only show banner notifications from friends in the battleground.",
                        { "battleground", "friendsOnly" }),
                    announceChat    = announceChatGroup("battleground", false),
                    displayEvents   = displayEventsGroup("battleground"),
                },
            },

            whisperFriends = {
                type  = "group",
                name  = "Whisper Friends",
                order = 6,
                args  = {
                    enabled      = toggle("Enable whispers to friends",
                        "Send your quest events as whispers to online friends.",
                        { "whisperFriends", "enabled" }),
                    groupOnly    = toggle("Group members only",
                        "Restrict whispers to friends currently in your group.",
                        { "whisperFriends", "groupOnly" }),
                    announceChat = announceChatGroup("whisperFriends", false),
                },
            },

            follow = {
                type  = "group",
                name  = "Follow Notifications",
                order = 7,
                args  = {
                    enabled           = toggle("Enable follow notifications",
                        "Send a whisper to players you start or stop following, and "
                        .. "receive notifications when someone follows you.",
                        { "follow", "enabled" }),
                    announceFollowing = toggle("Announce when you follow someone",
                        "Whisper the player you begin following so they know you are following them.",
                        { "follow", "announceFollowing" }),
                    announceFollowed  = toggle("Announce when followed",
                        "Display a local message when someone starts or stops following you.",
                        { "follow", "announceFollowed"  }),
                },
            },

            debug = {
                type  = "group",
                name  = "Debug",
                order = 8,
                args  = {
                    enabled = toggle("Enable debug mode",
                        "Print internal debug messages to the chat frame. Useful for "
                        .. "diagnosing comm issues or event flow problems.",
                        { "debug", "enabled" }),
                    testBanners = {
                        type   = "group",
                        name   = "Test Banners and Chat",
                        inline = true,
                        args   = {
                            testAccepted = {
                                type = "execute",
                                name = "Test Accepted",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest accepted' event. Bypasses all display filters.",
                                func = function() SocialQuestAnnounce:TestEvent("accepted") end,
                            },
                            testAbandoned = {
                                type = "execute",
                                name = "Test Abandoned",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest abandoned' event.",
                                func = function() SocialQuestAnnounce:TestEvent("abandoned") end,
                            },
                            testFinished = {
                                type = "execute",
                                name = "Test Finished",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest finished objectives' event.",
                                func = function() SocialQuestAnnounce:TestEvent("finished") end,
                            },
                            testCompleted = {
                                type = "execute",
                                name = "Test Completed",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest turned in' event.",
                                func = function() SocialQuestAnnounce:TestEvent("completed") end,
                            },
                            testFailed = {
                                type = "execute",
                                name = "Test Failed",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest failed' event.",
                                func = function() SocialQuestAnnounce:TestEvent("failed") end,
                            },
                            testObjProgress = {
                                type = "execute",
                                name = "Test Obj. Progress",
                                desc = "Display a demo banner and local chat preview for a "
                                    .. "partial objective progress update (e.g. 3/8).",
                                func = function() SocialQuestAnnounce:TestEvent("objective_progress") end,
                            },
                            testObjComplete = {
                                type = "execute",
                                name = "Test Obj. Complete",
                                desc = "Display a demo banner and local chat preview for an "
                                    .. "objective completion (e.g. 8/8).",
                                func = function() SocialQuestAnnounce:TestEvent("objective_complete") end,
                            },
                            testObjRegression = {
                                type = "execute",
                                name = "Test Obj. Regression",
                                desc = "Display a demo banner and local chat preview for an "
                                    .. "objective regression (count went backward).",
                                func = function() SocialQuestAnnounce:TestEvent("objective_regression") end,
                            },
                        },
                    },
                },
            },

        },
    }
```

- [ ] **Step 3: Load WoW and verify Options UI**

`/reload`. Open `/sq config`. Verify each section:

- **General:** Enable SocialQuest, Show received events, Colorblind Mode, Show banners for own events, Own Quest Banners inline group (7 toggles: Accepted / Abandoned / Finished / Completed / Failed / Objective Progress / Objective Complete)
- **Party:** Enable transmission, Show received events, Announce in Chat (7 toggles), Display Events (7 toggles)
- **Raid:** Enable transmission, Show received events, Only show from friends, Announce in Chat (5 toggles — quest events only), Display Events (7 toggles)
- **Guild:** Enable chat announcements, Announce in Chat (5 toggles). No Display Events group.
- **Battleground:** Same structure as Party (7+7)
- **Whisper Friends:** Enable, Group Only, Announce in Chat (7 toggles). No Display Events.
- **Follow Notifications:** unchanged — 3 toggles
- **Debug:** Enable debug mode, Test Banners and Chat inline group (8 execute buttons)

- [ ] **Step 4: Test the debug buttons**

Click each of the 8 test buttons. For each:
- A colored RaidWarning banner appears on screen
- A local chat line prints `SocialQuest (preview): <demo text>`
- No actual chat message is sent to party/raid/guild

- [ ] **Step 5: Test colorblind mode via test buttons**

Enable Colorblind Mode in General. Click "Test Accepted" → banner is sky blue (not green). Click "Test Failed" → banner is vermillion/orange (not red). Click "Test Completed" → still gold (unchanged between modes). Disable Colorblind Mode → colors revert.

- [ ] **Step 6: Test own-quest banners**

Enable "Show banners for your own quest events" in General. Accept any quest in-game → a RaidWarning banner reads "You accepted: [Quest Name]". Abandon a quest → "You abandoned: [Quest Name]". Turn in a quest → "You completed: [Quest Name]".

- [ ] **Step 7: Commit**

```bash
git add UI/Options.lua
git commit -m "feat: rebuild Options.lua with colorblind mode, own-quest banners, display events, and debug test panel"
```

---

## Final Checklist

After all 8 tasks are committed, run through this checklist:

- [ ] `/reload` — no Lua errors in chat
- [ ] All 8 debug test buttons produce a banner + local chat preview
- [ ] Colorblind mode changes banner colors for accepted (green→sky blue) and failed (red→vermillion)
- [ ] Own-quest banner toggle works: accept a quest, banner appears reading "You accepted: …"
- [ ] Quest events still send to party/raid/guild/battleground chat as configured
- [ ] No `general.receive` key is present in the DB (check `/sq config` General — no per-event receive toggles)
- [ ] `isTracked` is absent from comm payloads (verify by checking Communications.lua edits)
- [ ] Regression announces: use a quest with kill-count objectives, die during it, confirm the `(regression)` suffix in the announcement
