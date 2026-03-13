# SocialQuest — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize SocialQuest into a well-structured AceAddon that consumes AbsoluteQuestLog-1.0 exclusively, adds a chain-aware group quest frame, a numeric-only comm protocol, a beacon+pull init strategy for raids and battlegrounds, and whisper-to-friends messaging.

**Architecture:** SocialQuest is an AceAddon split across focused files: Communications handles all AceComm send/receive and jitter logic; GroupData owns the PlayerQuests table; Announcements drives the chat throttle queue; each UI concern lives in its own file. AQL callbacks replace all direct WoW quest event handling — SocialQuest never calls C_QuestLog.

**Prerequisite:** AbsoluteQuestLog-1.0 must be built and installed before implementing this plan. Verify with `/run print(LibStub("AbsoluteQuestLog-1.0") ~= nil)` → `true`.

**Tech Stack:** AceAddon-3.0, AceEvent-3.0, AceComm-3.0, AceDB-3.0, AceConfig-3.0, AceSerializer-3.0, AceTimer-3.0, AceConsole-3.0 (all via Ace3 standalone addon), AbsoluteQuestLog-1.0 (LibStub).

---

## File Map

| File | Role |
|---|---|
| `SocialQuest.toc` | Addon manifest; lists all files and dependencies |
| `SocialQuest.lua` | AceAddon entry point: OnInitialize, OnEnable, AQL callback registration, WoW event registration |
| `Core/GroupData.lua` | PlayerQuests table: add/update/remove player entries from incoming comm messages |
| `Core/Communications.lua` | AceComm send helpers, receive dispatcher, jitter init logic |
| `Core/Announcements.lua` | Chat throttle queue, message formatting, whisper-to-friends logic |
| `UI/Tooltips.lua` | ItemRefTooltip hook; renders group progress in quest tooltips |
| `UI/GroupFrame.lua` | Group quest frame: tabs (Shared/My/Party), chain display, timed quest display |
| `UI/Options.lua` | AceConfig options table registered with Blizzard Interface Options |
| `Util/Colors.lua` | Color constants used across UI files |

**Files to replace/retire:** The existing `SocialQuest.lua` (monolithic) becomes the slim entry point. `SocialQuest.options.lua` is replaced by `UI/Options.lua`. `Colors.lua` moves to `Util/Colors.lua`.

---

## Chunk 1: Foundation

Replace the TOC, establish the new file skeleton, wire AQL, and get the addon loading cleanly with AQL callbacks registered.

### Task 1: Update TOC

**Files:**
- Replace: `SocialQuest.toc`

- [ ] **Step 1: Overwrite the TOC**

```
## Interface: 20505
## Title: SocialQuest
## Notes: Social quest coordination for WoW Burning Crusade Anniversary.
## Author: Thad Ryker
## Version: 2.0
## Dependencies: Ace3, AbsoluteQuestLog

Util\Colors.lua
SocialQuest.lua
Core\GroupData.lua
Core\Communications.lua
Core\Announcements.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua
```

- [ ] **Step 2: Commit**

```bash
git add SocialQuest.toc
git commit -m "feat: update TOC to depend on AbsoluteQuestLog and list new file structure"
```

---

### Task 2: Colors utility

**Files:**
- Create: `Util/Colors.lua`

- [ ] **Step 1: Write Util/Colors.lua**

```lua
-- Util/Colors.lua
-- Color constants used across SocialQuest UI files.

SocialQuestColors = {
    -- Quest state colors
    active    = "|cFFFFFF00",  -- yellow
    completed = "|cFF00FF00",  -- green
    failed    = "|cFFFF0000",  -- red
    unknown   = "|cFF888888",  -- grey
    header    = "|cFFFFD700",  -- gold
    chain     = "|cFF00CCFF",  -- cyan
    timer     = "|cFFFF8C00",  -- orange
    -- General
    white     = "|cFFFFFFFF",
    reset     = "|r",
}
```

- [ ] **Step 2: Commit**

```bash
git add Util/Colors.lua
git commit -m "feat: add Colors utility with quest state color constants"
```

---

### Task 3: SocialQuest.lua entry point

**Files:**
- Replace: `SocialQuest.lua`

- [ ] **Step 1: Write the new SocialQuest.lua**

This replaces the old monolithic file. It is the AceAddon entry point only — all logic lives in sub-files.

```lua
-- SocialQuest.lua
-- AceAddon entry point. Handles OnInitialize, OnEnable, and AQL callback
-- registration. All quest logic delegates to sub-modules.

SocialQuest = LibStub("AceAddon-3.0"):NewAddon(
    "SocialQuest",
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceTimer-3.0",
    "AceConsole-3.0"
)

local AQL  -- set in OnInitialize

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

function SocialQuest:OnInitialize()
    -- Verify AQL is present before doing anything else.
    AQL = LibStub("AbsoluteQuestLog-1.0", true)
    if not AQL then
        self:Print("|cFFFF0000ERROR:|r AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled.")
        return
    end

    -- AceDB sets up saved variables. Profile key "Default" shared across chars.
    self.db = LibStub("AceDB-3.0"):New("SocialQuestDB", self:GetDefaults(), true)

    -- Expose AQL to sub-modules that need it.
    self.AQL = AQL

    -- Register options panel.
    SocialQuestOptions:Initialize()
end

function SocialQuest:OnEnable()
    if not self.AQL then return end  -- AQL missing; stay dormant.

    -- Register AceComm prefixes.
    SocialQuestComm:Initialize()

    -- Register WoW events (non-quest; quest events come via AQL callbacks).
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("AUTOFOLLOW_BEGIN",    "OnAutoFollowBegin")
    self:RegisterEvent("AUTOFOLLOW_END",      "OnAutoFollowEnd")

    -- Register AQL callbacks.
    AQL:RegisterCallback("AQL_QUEST_ACCEPTED",        self, self.OnQuestAccepted)
    AQL:RegisterCallback("AQL_QUEST_ABANDONED",       self, self.OnQuestAbandoned)
    AQL:RegisterCallback("AQL_QUEST_FINISHED",        self, self.OnQuestFinished)
    AQL:RegisterCallback("AQL_QUEST_COMPLETED",       self, self.OnQuestCompleted)
    AQL:RegisterCallback("AQL_QUEST_FAILED",          self, self.OnQuestFailed)
    AQL:RegisterCallback("AQL_QUEST_TRACKED",         self, self.OnQuestTracked)
    AQL:RegisterCallback("AQL_QUEST_UNTRACKED",       self, self.OnQuestUntracked)
    AQL:RegisterCallback("AQL_OBJECTIVE_PROGRESSED",  self, self.OnObjectiveProgressed)
    AQL:RegisterCallback("AQL_OBJECTIVE_REGRESSED",   self, self.OnObjectiveRegressed)
    AQL:RegisterCallback("AQL_UNIT_QUEST_LOG_CHANGED",self, self.OnUnitQuestLogChanged)
end

function SocialQuest:OnDisable()
    if AQL then
        AQL:UnregisterCallback("AQL_QUEST_ACCEPTED",         self)
        AQL:UnregisterCallback("AQL_QUEST_ABANDONED",        self)
        AQL:UnregisterCallback("AQL_QUEST_FINISHED",         self)
        AQL:UnregisterCallback("AQL_QUEST_COMPLETED",        self)
        AQL:UnregisterCallback("AQL_QUEST_FAILED",           self)
        AQL:UnregisterCallback("AQL_QUEST_TRACKED",          self)
        AQL:UnregisterCallback("AQL_QUEST_UNTRACKED",        self)
        AQL:UnregisterCallback("AQL_OBJECTIVE_PROGRESSED",   self)
        AQL:UnregisterCallback("AQL_OBJECTIVE_REGRESSED",    self)
        AQL:UnregisterCallback("AQL_UNIT_QUEST_LOG_CHANGED", self)
    end
end

------------------------------------------------------------------------
-- Default settings
------------------------------------------------------------------------

function SocialQuest:GetDefaults()
    return {
        profile = {
            enabled = true,
            general = {
                displayReceived = true,
                receive = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
            party = {
                transmit = true,
                displayReceived = true,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=true },
            },
            raid = {
                transmit = true,
                displayReceived = true,
                friendsOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
            guild = {
                transmit = true,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
            battleground = {
                transmit = true,
                displayReceived = true,
                friendsOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=true },
            },
            whisperFriends = {
                enabled = false,
                groupOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=false },
            },
            follow = {
                enabled = true,
                announceFollowing = true,
                announceFollowed  = true,
            },
            debug = {
                enabled = false,
            },
        },
    }
end

------------------------------------------------------------------------
-- WoW event handlers
------------------------------------------------------------------------

function SocialQuest:OnGroupRosterUpdate()
    SocialQuestComm:OnGroupChanged()
    SocialQuestGroupData:OnGroupChanged()
end

function SocialQuest:OnAutoFollowBegin(event, unit)
    if not self.db.profile.follow.enabled then return end
    if not self.db.profile.follow.announceFollowing then return end
    local name = UnitName(unit)
    if name then
        SocialQuestComm:SendFollowStart(name)
    end
end

function SocialQuest:OnAutoFollowEnd()
    if not self.db.profile.follow.enabled then return end
    -- Find who we were following by iterating group.
    -- AUTOFOLLOW_END does not pass the unit; whisper is sent to last known follow target.
    -- Stored in SocialQuestComm.followTarget.
    local target = SocialQuestComm.followTarget
    if target then
        SocialQuestComm:SendFollowStop(target)
        SocialQuestComm.followTarget = nil
    end
end

------------------------------------------------------------------------
-- AQL Callback handlers
------------------------------------------------------------------------

function SocialQuest:OnQuestAccepted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
end

function SocialQuest:OnQuestFinished(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
end

function SocialQuest:OnQuestFailed(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
end

function SocialQuest:OnQuestTracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "tracked")
end

function SocialQuest:OnQuestUntracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "untracked")
end

function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    SocialQuestAnnounce:OnObjectiveEvent("objective", questInfo, objective)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    -- Broadcast regression so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
end

function SocialQuest:OnUnitQuestLogChanged(event, unit)
    -- Non-SocialQuest member changed their quest log. Sweep shared quests.
    SocialQuestGroupData:OnUnitQuestLogChanged(unit)
end

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------

SocialQuest:RegisterChatCommand("sq", function(input)
    local cmd = strtrim(input or "")
    if cmd == "config" then
        LibStub("AceConfigDialog-3.0"):Open("SocialQuest")
    else
        SocialQuestGroupFrame:Toggle()
    end
end)
```

- [ ] **Step 2: Load in WoW and verify**

```
/reload
```

Expected: no Lua errors. Addon loads. If AQL is missing, a clear error message prints. If AQL is present, no output (silent success).

Verify:
```
/run print(SocialQuest ~= nil)
```
Expected: `true`

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: replace SocialQuest.lua with slim AceAddon entry point using AQL callbacks"
```

---

## Chunk 2: Group Data and Communications

The PlayerQuests table and all AceComm send/receive logic. After this chunk, group members running SocialQuest will sync quest state with each other.

### Task 4: GroupData module

**Files:**
- Create: `Core/GroupData.lua`

- [ ] **Step 1: Write Core/GroupData.lua**

```lua
-- Core/GroupData.lua
-- Owns the PlayerQuests table. Populated entirely from incoming AceComm messages.
-- All values stored are numeric — no text strings from other players.
--
-- PlayerQuests["Name-Realm"] = {
--     hasSocialQuest = true,
--     lastSync       = <GetTime()>,
--     quests = {
--         [questID] = {
--             questID=N, isComplete=bool, isFailed=bool, isTracked=bool,
--             snapshotTime=N, timerSeconds=N_or_nil,
--             objectives = { {numFulfilled=N, numRequired=N, isFinished=bool}, ... }
--         },
--     }
-- }
-- Players without SocialQuest: { hasSocialQuest=false }

SocialQuestGroupData = {}

SocialQuestGroupData.PlayerQuests = {}

-- Called when GROUP_ROSTER_UPDATE fires. Removes stale entries and adds stubs
-- for newly visible members who haven't sent data yet.
function SocialQuestGroupData:OnGroupChanged()
    -- Build a set of current group member names.
    local current = {}
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid"..i) or ("party"..i)
        local name, realm = UnitName(unit)
        if name then
            local fullName = realm and realm ~= "" and (name.."-"..realm) or name
            current[fullName] = true
        end
    end

    -- Remove entries for players no longer in group.
    for fullName in pairs(self.PlayerQuests) do
        if not current[fullName] then
            self.PlayerQuests[fullName] = nil
        end
    end

    -- Add stub entries for new members we haven't heard from yet.
    for fullName in pairs(current) do
        if not self.PlayerQuests[fullName] then
            self.PlayerQuests[fullName] = { hasSocialQuest = false }
        end
    end
end

-- Called when a full SQ_INIT message arrives from a player.
-- payload: { quests = { [questID] = { isComplete, isFailed, isTracked,
--            snapshotTime, timerSeconds, objectives={...} } } }
function SocialQuestGroupData:OnInitReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    self.PlayerQuests[sender] = {
        hasSocialQuest = true,
        lastSync       = GetTime(),
        quests         = payload.quests or {},
    }

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a single-quest SQ_UPDATE arrives.
-- payload: { questID=N, eventType="accepted"|..., isComplete=bool, isFailed=bool,
--            isTracked=bool, snapshotTime=N, timerSeconds=N_or_nil,
--            objectives={...} }
function SocialQuestGroupData:OnUpdateReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry then
        entry = { hasSocialQuest = true, lastSync = GetTime(), quests = {} }
        self.PlayerQuests[sender] = entry
    end
    entry.hasSocialQuest = true
    entry.lastSync       = GetTime()

    local eventType = payload.eventType
    local questID   = payload.questID

    if eventType == "abandoned" or eventType == "completed" or eventType == "failed" then
        entry.quests[questID] = nil
    else
        entry.quests[questID] = {
            questID      = questID,
            isComplete   = payload.isComplete  == 1,
            isFailed     = payload.isFailed    == 1,
            isTracked    = payload.isTracked   == 1,
            snapshotTime = payload.snapshotTime,
            timerSeconds = payload.timerSeconds,
            objectives   = payload.objectives or {},
        }
    end

    -- Trigger banner notification if applicable.
    SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a single-objective SQ_OBJECTIVE arrives.
-- payload: { questID=N, objIndex=N, numFulfilled=N, numRequired=N, isFinished=bool }
function SocialQuestGroupData:OnObjectiveReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry or not entry.quests then return end

    local quest = entry.quests[payload.questID]
    if not quest then return end

    local obj = quest.objectives[payload.objIndex]
    if not obj then
        obj = {}
        quest.objectives[payload.objIndex] = obj
    end
    obj.numFulfilled = payload.numFulfilled
    obj.numRequired  = payload.numRequired
    obj.isFinished   = payload.isFinished == 1

    SocialQuestGroupFrame:RequestRefresh()
end

-- Sweep the local quest log via UnitIsOnQuest for a non-SocialQuest member.
-- UNIT_QUEST_LOG_CHANGED fires for party members even without the addon.
-- UnitIsOnQuest(questLogIndex, unit) checks if `unit` is on the quest at index.
-- We must skip header entries (isHeader = true) when iterating.
function SocialQuestGroupData:OnUnitQuestLogChanged(unit)
    -- Only handle party/raid units, not "player".
    if not unit or unit == "player" then return end

    local name, realm = UnitName(unit)
    if not name then return end
    local fullName = realm and realm ~= "" and (name.."-"..realm) or name

    local entry = self.PlayerQuests[fullName]
    if entry and entry.hasSocialQuest then return end  -- Full data already available.

    -- Partial data: find which of OUR quests this unit also has.
    local sharedQuestIDs = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        -- GetQuestLogTitle returns isHeader as the 5th return value.
        -- GetQuestLogTitle in TBC Classic returns: title, level, suggestedGroup, isHeader, ...
        -- isHeader is the 4th return value (not 5th).
        local title, level, suggestedGroup, isHeader = GetQuestLogTitle(i)
        if not isHeader and UnitIsOnQuest(i, unit) then
            local info = C_QuestLog.GetInfo(i)
            if info then
                table.insert(sharedQuestIDs, info.questID)
            end
        end
    end

    -- Build a minimal quest entry with only the questIDs we know about.
    local questData = {}
    for _, questID in ipairs(sharedQuestIDs) do
        questData[questID] = { questID = questID, objectives = {} }
    end

    self.PlayerQuests[fullName] = {
        hasSocialQuest = false,
        lastSync       = GetTime(),
        quests         = questData,
    }

    SocialQuestGroupFrame:RequestRefresh()
end

-- Helper: is this sender currently in our group?
function SocialQuestGroupData:IsInGroup(fullName)
    return self.PlayerQuests[fullName] ~= nil
end
```

- [ ] **Step 2: Commit**

```bash
git add Core/GroupData.lua
git commit -m "feat: add GroupData module owning the PlayerQuests table"
```

---

### Task 5: Communications module

**Files:**
- Create: `Core/Communications.lua`

- [ ] **Step 1: Write Core/Communications.lua**

```lua
-- Core/Communications.lua
-- Handles all AceComm send/receive. All payloads are numeric-only tables —
-- no quest titles or objective text are ever transmitted.
--
-- Prefixes:
--   SQ_INIT      Full quest log snapshot (questID + objective counts).
--   SQ_UPDATE    Single quest state change.
--   SQ_OBJECTIVE Single objective progress update.
--   SQ_BEACON    Empty broadcast to announce presence (raid/BG init).
--   SQ_REQUEST   Whisper requesting a full SQ_INIT from a specific player.
--   SQ_FOLLOW_START / SQ_FOLLOW_STOP  Follow notifications (whisper).

SocialQuestComm = {}
SocialQuestComm.followTarget = nil  -- last player we started following

local PREFIXES = {
    "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
    "SQ_BEACON", "SQ_REQUEST",
    "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
}

-- Called from SocialQuest:OnEnable().
function SocialQuestComm:Initialize()
    local AceComm = LibStub("AceComm-3.0")
    for _, prefix in ipairs(PREFIXES) do
        AceComm:RegisterComm(prefix, function(pfx, msg, dist, sender)
            SocialQuestComm:OnCommReceived(pfx, msg, dist, sender)
        end)
    end
end

------------------------------------------------------------------------
-- Group change / initialization
------------------------------------------------------------------------

-- Called when GROUP_ROSTER_UPDATE fires.
function SocialQuestComm:OnGroupChanged()
    local db = SocialQuest.db.profile

    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        -- Party (≤5): send full init immediately to PARTY channel.
        if db.party.transmit then
            self:SendFullInit("PARTY")
        end

    elseif IsInRaid() then
        -- Raid (6–40): send SQ_BEACON with 0–8s jitter, then respond to requests.
        if db.raid.transmit then
            local jitter = math.random(0, 8)
            SocialQuest:ScheduleTimer(function()
                self:SendBeacon("RAID")
            end, jitter)
        end

    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        -- Battleground: same beacon+pull as raid.
        if db.battleground.transmit then
            local jitter = math.random(0, 8)
            SocialQuest:ScheduleTimer(function()
                self:SendBeacon("INSTANCE_CHAT")
            end, jitter)
        end
    end
    -- Guild: no AceComm sync.
end

------------------------------------------------------------------------
-- Send helpers
------------------------------------------------------------------------

-- Build a numeric-only quest payload table from a QuestInfo.
local function buildQuestPayload(questInfo, eventType)
    local objs = {}
    for i, obj in ipairs(questInfo.objectives or {}) do
        objs[i] = {
            numFulfilled = obj.numFulfilled,
            numRequired  = obj.numRequired,
            isFinished   = obj.isFinished and 1 or 0,
        }
    end
    return {
        questID      = questInfo.questID,
        eventType    = eventType,
        isComplete   = questInfo.isComplete  and 1 or 0,
        isFailed     = questInfo.isFailed    and 1 or 0,
        isTracked    = questInfo.isTracked   and 1 or 0,
        -- snapshotTime is the sender's GetTime() AT MOMENT OF TRANSMISSION, not
        -- the time AQL built its local cache. This gives receivers an accurate
        -- reference for timer estimation: remaining = timerSeconds - (GetTime() - snapshotTime).
        snapshotTime = GetTime(),
        timerSeconds = questInfo.timerSeconds,  -- nil if no timer (serializes cleanly)
        objectives   = objs,
    }
end

-- Build the full init payload: all active quests, objectives only (numeric).
local function buildInitPayload()
    local AQL = SocialQuest.AQL
    local quests = {}
    for questID, info in pairs(AQL:GetAllQuests()) do
        local objs = {}
        for i, obj in ipairs(info.objectives or {}) do
            objs[i] = {
                numFulfilled = obj.numFulfilled,
                numRequired  = obj.numRequired,
                isFinished   = obj.isFinished and 1 or 0,
            }
        end
        quests[questID] = {
            questID      = questID,
            isComplete   = info.isComplete  and 1 or 0,
            isFailed     = info.isFailed    and 1 or 0,
            isTracked    = info.isTracked   and 1 or 0,
            snapshotTime = GetTime(),  -- stamp at transmission time, not AQL cache build time
            timerSeconds = info.timerSeconds,
            objectives   = objs,
        }
    end
    return { quests = quests }
end

local function serialize(t)
    return LibStub("AceSerializer-3.0"):Serialize(t)
end

function SocialQuestComm:SendFullInit(channel, targetName)
    local payload = buildInitPayload()
    local msg = serialize(payload)
    if targetName then
        LibStub("AceComm-3.0"):SendCommMessage("SQ_INIT", msg, "WHISPER", targetName)
    else
        LibStub("AceComm-3.0"):SendCommMessage("SQ_INIT", msg, channel)
    end
end

function SocialQuestComm:SendBeacon(channel)
    -- Empty beacon — payload is just a single byte so AceComm has something to send.
    LibStub("AceComm-3.0"):SendCommMessage("SQ_BEACON", serialize({}), channel)
end

-- Broadcast a single quest state update.
function SocialQuestComm:BroadcastQuestUpdate(questInfo, eventType)
    local channel = self:GetActiveChannel()
    if not channel then return end

    local payload = buildQuestPayload(questInfo, eventType)
    LibStub("AceComm-3.0"):SendCommMessage("SQ_UPDATE", serialize(payload), channel)
end

-- Broadcast a single objective update.
function SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    local channel = self:GetActiveChannel()
    if not channel then return end

    local payload = {
        questID      = questInfo.questID,
        objIndex     = objective.index,
        numFulfilled = objective.numFulfilled,
        numRequired  = objective.numRequired,
        isFinished   = objective.isFinished and 1 or 0,
    }
    LibStub("AceComm-3.0"):SendCommMessage("SQ_OBJECTIVE", serialize(payload), channel)
end

function SocialQuestComm:SendFollowStart(targetName)
    self.followTarget = targetName
    LibStub("AceComm-3.0"):SendCommMessage("SQ_FOLLOW_START", serialize({}), "WHISPER", targetName)
end

function SocialQuestComm:SendFollowStop(targetName)
    LibStub("AceComm-3.0"):SendCommMessage("SQ_FOLLOW_STOP", serialize({}), "WHISPER", targetName)
end

-- Returns the appropriate AceComm channel string for the player's current group context.
-- Returns nil if not in a group or guild-only (guild has no AceComm sync).
function SocialQuestComm:GetActiveChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
    return nil
end

------------------------------------------------------------------------
-- Receive
------------------------------------------------------------------------

function SocialQuestComm:OnCommReceived(prefix, msg, distribution, sender)
    -- Ignore our own messages.
    local myName = UnitName("player")
    if sender == myName then return end

    local ok, payload = LibStub("AceSerializer-3.0"):Deserialize(msg)
    if not ok then
        if SocialQuest.db.profile.debug.enabled then
            SocialQuest:Print("[Comm] Failed to deserialize "..prefix.." from "..sender)
        end
        return
    end

    if prefix == "SQ_INIT" then
        SocialQuestGroupData:OnInitReceived(sender, payload)

    elseif prefix == "SQ_UPDATE" then
        SocialQuestGroupData:OnUpdateReceived(sender, payload)

    elseif prefix == "SQ_OBJECTIVE" then
        SocialQuestGroupData:OnObjectiveReceived(sender, payload)

    elseif prefix == "SQ_BEACON" then
        -- Someone announced their presence. Per the beacon+pull protocol, the
        -- correct response is to send SQ_REQUEST (a whisper asking for their
        -- full snapshot). They will reply with SQ_INIT. Do NOT send our own
        -- SQ_INIT unsolicited — that defeats the storm-prevention purpose of
        -- the beacon pattern. They will send us an SQ_REQUEST in return when
        -- they receive our beacon (or request directly if they already heard ours).
        LibStub("AceComm-3.0"):SendCommMessage("SQ_REQUEST", serialize({}), "WHISPER", sender)

    elseif prefix == "SQ_REQUEST" then
        -- Someone is requesting our full snapshot.
        self:SendFullInit("WHISPER", sender)

    elseif prefix == "SQ_FOLLOW_START" then
        SocialQuestAnnounce:OnFollowStart(sender)

    elseif prefix == "SQ_FOLLOW_STOP" then
        SocialQuestAnnounce:OnFollowStop(sender)
    end
end
```

- [ ] **Step 2: Load in WoW and verify**

```
/reload
```

No errors. Join a party with another SocialQuest user and confirm group sync initiates (debug messages if debug enabled).

- [ ] **Step 3: Commit**

```bash
git add Core/Communications.lua
git commit -m "feat: add Communications module with AceComm send/receive and beacon+pull init"
```

---

## Chunk 3: Announcements

Chat throttle queue and all message formatting — guild, raid, party, battleground, and whisper friends.

### Task 6: Announcements module

**Files:**
- Create: `Core/Announcements.lua`

- [ ] **Step 1: Write Core/Announcements.lua**

```lua
-- Core/Announcements.lua
-- Drives all chat announcements (outbound from local player's quest events)
-- and banner notifications (inbound from other SocialQuest users).
--
-- Chat queue: all SendChatMessage calls pass through a FIFO queue with a
-- 1-second minimum interval to avoid bot-detection throttling. Duplicate
-- messages are dropped before enqueue.

SocialQuestAnnounce = {}

local throttleQueue  = {}
local lastSendTime   = 0
local THROTTLE_DELAY = 1.0  -- seconds between chat sends

-- Ticker drives the throttle queue. Created once and kept running.
local ticker = nil

local function startThrottleTicker()
    if ticker then return end
    ticker = SocialQuest:ScheduleRepeatingTimer(function()
        local now = GetTime()
        if #throttleQueue > 0 and (now - lastSendTime) >= THROTTLE_DELAY then
            local item = table.remove(throttleQueue, 1)
            SendChatMessage(item.text, item.channel, nil, item.target)
            lastSendTime = now
        end
    end, 0.25)
end

local function enqueueChat(text, channel, target)
    -- Drop duplicate messages already in queue.
    for _, item in ipairs(throttleQueue) do
        if item.text == text and item.channel == channel and item.target == target then
            return
        end
    end
    table.insert(throttleQueue, { text = text, channel = channel, target = target })
    startThrottleTicker()
end

------------------------------------------------------------------------
-- Message formatting
------------------------------------------------------------------------

-- Format a quest event announcement. Returns a plain string.
-- Text is always resolved locally from AQL — never transmitted.
local function formatQuestMessage(eventType, questTitle)
    local AQL = SocialQuest.AQL
    local templates = {
        accepted  = "Quest accepted: %s",
        abandoned = "Quest abandoned: %s",
        finished  = "Quest complete (objectives done): %s",
        completed = "Quest turned in: %s",
        failed    = "Quest failed: %s",
    }
    local tmpl = templates[eventType] or "Quest event (%s): %%s"
    return string.format(tmpl, questTitle)
end

local function formatObjectiveMessage(questTitle, objectiveText)
    return string.format("Quest progress — %s: %s", questTitle, objectiveText)
end

------------------------------------------------------------------------
-- Determine which channels to announce to
------------------------------------------------------------------------

local function getAnnouncementChannels(eventType)
    local db  = SocialQuest.db.profile
    local channels = {}

    -- Party
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        if db.party.transmit and db.party.announce[eventType] then
            table.insert(channels, { channel = "PARTY" })
        end
    end

    -- Raid
    if IsInRaid() then
        if db.raid.transmit and db.raid.announce[eventType] then
            table.insert(channels, { channel = "RAID" })
        end
    end

    -- Guild
    if IsInGuild() then
        if db.guild.transmit and db.guild.announce[eventType] then
            table.insert(channels, { channel = "GUILD" })
        end
    end

    -- Battleground
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if db.battleground.transmit and db.battleground.announce[eventType] then
            table.insert(channels, { channel = "BATTLEGROUND" })
        end
    end

    return channels
end

------------------------------------------------------------------------
-- Local quest event announcements (from our own AQL callbacks)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnQuestEvent(eventType, questInfo)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local title = questInfo.title
    local msg   = formatQuestMessage(eventType, title)
    local chans = getAnnouncementChannels(eventType)

    for _, chan in ipairs(chans) do
        enqueueChat(msg, chan.channel, chan.target)
    end

    -- Whisper friends.
    if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
        self:WhisperFriends(msg, db.whisperFriends.groupOnly)
    end
end

-- Objective progress (party + whisper friends only per announcement matrix).
function SocialQuestAnnounce:OnObjectiveEvent(eventType, questInfo, objective)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local title = questInfo.title
    local msg   = formatObjectiveMessage(title, objective.text or "")

    -- Party and Battleground get objective progress; Raid and Guild do not (per announcement matrix).
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        if db.party.transmit and db.party.announce["objective"] then
            enqueueChat(msg, "PARTY")
        end
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if db.battleground.transmit and db.battleground.announce["objective"] then
            enqueueChat(msg, "BATTLEGROUND")
        end
    end

    -- Whisper friends.
    if db.whisperFriends.enabled and db.whisperFriends.announce["objective"] then
        self:WhisperFriends(msg, db.whisperFriends.groupOnly)
    end
end

------------------------------------------------------------------------
-- Remote event banner notifications (from SQ_UPDATE received from others)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end
    if not db.general.receive[eventType] then return end

    -- Check friends-only filter for raid/BG.
    local inRaid = IsInRaid()
    local inBG   = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    if inRaid and db.raid.friendsOnly and not C_FriendList.IsFriend(sender) then return end
    if inBG   and db.battleground.friendsOnly and not C_FriendList.IsFriend(sender) then return end

    -- Resolve quest title locally from AQL.
    local AQL = SocialQuest.AQL
    local title = AQL and AQL:GetQuestLink(questID) or C_QuestLog.GetTitleForQuestID(questID) or ("Quest "..questID)

    local templates = {
        accepted  = "%s accepted: %s",
        abandoned = "%s abandoned: %s",
        finished  = "%s finished objectives: %s",
        completed = "%s completed: %s",
        failed    = "%s failed: %s",
    }
    local tmpl = templates[eventType]
    if not tmpl then return end

    local bannerMsg = string.format(tmpl, sender, title)
    if RaidWarningFrame then
        RaidWarningFrame:AddMessage(bannerMsg)
    end
end

------------------------------------------------------------------------
-- Follow notifications
------------------------------------------------------------------------

function SocialQuestAnnounce:OnFollowStart(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    SocialQuest:Print(sender .. " started following you.")
end

function SocialQuestAnnounce:OnFollowStop(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    SocialQuest:Print(sender .. " stopped following you.")
end

------------------------------------------------------------------------
-- Whisper friends helper
------------------------------------------------------------------------

function SocialQuestAnnounce:WhisperFriends(msg, groupOnly)
    local numFriends = C_FriendList.GetNumFriends()
    for i = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            local friendName = info.name
            if groupOnly then
                -- Only whisper if friend is in current group.
                if not self:IsFriendInGroup(friendName) then
                    friendName = nil
                end
            end
            if friendName then
                enqueueChat(msg, "WHISPER", friendName)
            end
        end
    end
end

function SocialQuestAnnounce:IsFriendInGroup(name)
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid"..i) or ("party"..i)
        local unitName = UnitName(unit)
        if unitName == name then return true end
    end
    return false
end
```

- [ ] **Step 2: Load and verify throttle**

```
/reload
```

Register a callback and generate two rapid quest events (accept two quests immediately). Observe in chat that the second message appears ~1 second after the first, not immediately.

- [ ] **Step 3: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: add Announcements module with throttle queue, banner notifications, and whisper friends"
```

---

## Chunk 4: UI — Tooltips and Group Frame

Visual layer: enhanced quest tooltips showing group progress, and the group quest window with chain-aware matching.

### Task 7: Tooltips

**Files:**
- Create: `UI/Tooltips.lua`

- [ ] **Step 1: Write UI/Tooltips.lua**

```lua
-- UI/Tooltips.lua
-- Hooks ItemRefTooltip to append group quest progress when hovering a quest link.

SocialQuestTooltips = {}

local function addGroupProgressToTooltip(tooltip, questID)
    local C = SocialQuestColors
    local AQL = SocialQuest.AQL
    if not AQL then return end

    local hasAnyGroupData = false

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests and entry.quests[questID] then
            -- Add the header on the first matching entry, then subsequent entries
            -- fall through to the player rows below.
            if not hasAnyGroupData then
                tooltip:AddLine(C.header .. "Group Progress" .. C.reset)
                hasAnyGroupData = true
            end

            local qdata = entry.quests[questID]
            local statusStr

            if not entry.hasSocialQuest then
                statusStr = C.unknown .. "(shared, no data)" .. C.reset
            elseif qdata.isComplete then
                statusStr = C.completed .. "Objectives complete" .. C.reset
            else
                -- Show objective progress.
                local parts = {}
                for i, obj in ipairs(qdata.objectives or {}) do
                    table.insert(parts, obj.numFulfilled .. "/" .. obj.numRequired)
                end
                statusStr = #parts > 0 and table.concat(parts, "  ") or C.unknown .. "(no data)" .. C.reset
            end

            tooltip:AddDoubleLine(
                C.white .. playerName .. C.reset,
                statusStr,
                1, 1, 1, 1, 1, 1
            )
        end
    end

    if hasAnyGroupData then
        tooltip:Show()
    end
end

function SocialQuestTooltips:Initialize()
    -- Hook the quest hyperlink tooltip.
    local orig = ItemRefTooltip:GetScript("OnTooltipSetItem")
    -- Quest links use a different hook point. We hook SetHyperlink instead.
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
        if not link then return end
        local questID = tonumber(link:match("quest:(%d+)"))
        if questID then
            addGroupProgressToTooltip(self, questID)
        end
    end)
end
```

- [ ] **Step 2: Call Initialize from SocialQuest.lua**

In `SocialQuest:OnEnable()`, after comm initialization, add:
```lua
SocialQuestTooltips:Initialize()
```

- [ ] **Step 3: Verify**

Hover over a quest link in chat while a group member has the same quest. Tooltip should show their progress below the normal tooltip content.

- [ ] **Step 4: Commit**

```bash
git add UI/Tooltips.lua SocialQuest.lua
git commit -m "feat: add Tooltips module with group progress in quest hyperlink tooltips"
```

---

### Task 8: Group Frame

**Files:**
- Create: `UI/GroupFrame.lua`

- [ ] **Step 1: Write the frame skeleton and tab structure**

```lua
-- UI/GroupFrame.lua
-- Group quest window. Opened via /sq or minimap button.
-- Three tabs: Shared Quests, My Quests, Party Quests.
-- Chain-aware matching: groups quests by chainID when known.

SocialQuestGroupFrame = {}

local frame = nil
local currentTab = "shared"  -- "shared" | "mine" | "party"
local refreshPending = false

------------------------------------------------------------------------
-- Frame construction
------------------------------------------------------------------------

local function createFrame()
    local f = CreateFrame("Frame", "SocialQuestGroupFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(400, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.title = f.TitleBg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
    f.title:SetText("SocialQuest — Group Quests")

    -- Scroll area for quest content.
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(360, 1)
    f.scrollFrame:SetScrollChild(f.content)

    -- Tabs.
    local function makeTab(name, label, offsetX)
        local tab = CreateFrame("Button", "SocialQuestTab_"..name, f, "TabButtonTemplate")
        tab:SetPoint("BOTTOMLEFT", f, "TOPLEFT", offsetX, -30)
        tab:SetText(label)
        tab:SetScript("OnClick", function()
            currentTab = name
            SocialQuestGroupFrame:Refresh()
        end)
        return tab
    end

    f.tabShared = makeTab("shared", "Shared",  10)
    f.tabMine   = makeTab("mine",   "Mine",    90)
    f.tabParty  = makeTab("party",  "Party",  150)

    return f
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function SocialQuestGroupFrame:Toggle()
    if not frame then frame = createFrame() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:Refresh()
    end
end

-- Called by GroupData/Comm whenever data changes.
-- Batches refreshes to avoid multiple redraws per frame.
function SocialQuestGroupFrame:RequestRefresh()
    if not frame or not frame:IsShown() then return end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        SocialQuestGroupFrame:Refresh()
    end)
end

function SocialQuestGroupFrame:Refresh()
    if not frame then return end
    -- Clear existing content.
    for _, child in ipairs({frame.content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    if currentTab == "shared" then
        self:RenderSharedTab()
    elseif currentTab == "mine" then
        self:RenderMineTab()
    else
        self:RenderPartyTab()
    end
end

------------------------------------------------------------------------
-- Chain-aware grouping helpers
------------------------------------------------------------------------

-- Returns a grouping key for a questID:
--   If chain is known, returns "chain:<chainID>"
--   Otherwise returns "quest:<questID>"
local function groupKey(questID)
    local AQL = SocialQuest.AQL
    if AQL then
        local chain = AQL:GetChainInfo(questID)
        if chain and chain.knownStatus == "known" and chain.chainID then
            return "chain:" .. chain.chainID, chain
        end
    end
    return "quest:" .. questID, nil
end

-- Format a time duration (seconds) as "M:SS".
local function formatTime(seconds)
    if not seconds or seconds <= 0 then return "0:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

-- Estimate remaining timer for a remote player's quest snapshot.
local function estimateTimer(timerSeconds, snapshotTime)
    if not timerSeconds or not snapshotTime then return nil end
    local elapsed = GetTime() - snapshotTime
    local remaining = timerSeconds - elapsed
    return remaining
end

------------------------------------------------------------------------
-- Shared Quests Tab
------------------------------------------------------------------------

function SocialQuestGroupFrame:RenderSharedTab()
    local AQL = SocialQuest.AQL
    if not AQL then return end
    local C = SocialQuestColors

    -- Build groups: key → { localQuestID, players = { [name] = questID } }
    local groups = {}

    -- Include local player's quests.
    for questID, info in pairs(AQL:GetAllQuests()) do
        local key, chain = groupKey(questID)
        if not groups[key] then groups[key] = { chain = chain, members = {} } end
        groups[key].members["(You)"] = questID
    end

    -- Include group members' quests.
    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests then
            for questID in pairs(entry.quests) do
                local key, chain = groupKey(questID)
                if not groups[key] then groups[key] = { chain = chain, members = {} } end
                groups[key].members[playerName] = questID
            end
        end
    end

    -- Filter to groups with at least 2 members (shared = 2+ people on same content).
    local y = 0
    local function addText(text, indent)
        local fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", indent or 0, -y)
        fs:SetText(text)
        fs:SetWidth(340)
        y = y + fs:GetStringHeight() + 4
    end

    for key, group in pairs(groups) do
        local memberCount = 0
        for _ in pairs(group.members) do memberCount = memberCount + 1 end
        if memberCount < 2 then goto continue end

        if group.chain then
            -- Chain display.
            local chain = group.chain
            addText(C.chain .. "[Chain] " .. (chain.steps and chain.steps[chain.step] and chain.steps[chain.step].title or "Unknown Chain") .. C.reset)

            -- Step bar: show each step with member positions marked.
            local stepLine = "  Step: "
            for i = 1, chain.length do
                stepLine = stepLine .. i
                if i < chain.length then stepLine = stepLine .. " -- " end
            end
            addText(stepLine)

            for playerName, questID in pairs(group.members) do
                local playerChain = AQL and AQL:GetChainInfo(questID)
                local step = playerChain and playerChain.step or "?"
                local label = playerName .. ": step " .. step

                -- Timer display.
                if playerName == "(You)" then
                    local info = AQL:GetQuest(questID)
                    if info and info.timerSeconds then
                        local remaining = info.timerSeconds - (GetTime() - info.snapshotTime)
                        if remaining > 0 then
                            label = label .. "  " .. C.timer .. "⏱ " .. formatTime(remaining) .. C.reset
                        end
                    end
                else
                    local pentry = SocialQuestGroupData.PlayerQuests[playerName]
                    local pquest = pentry and pentry.quests and pentry.quests[questID]
                    if pquest and pquest.timerSeconds then
                        local remaining = estimateTimer(pquest.timerSeconds, pquest.snapshotTime)
                        if remaining and remaining > 0 then
                            label = label .. "  " .. C.timer .. "⏱ ~" .. formatTime(remaining) .. " (est.)" .. C.reset
                        elseif remaining then
                            label = label .. "  " .. C.timer .. "(Timer may have expired)" .. C.reset
                        end
                    end
                end

                addText(label, 16)
            end

            -- Relative step summary: compare local player's step to each other member.
            -- "You are N steps ahead/behind" per the spec chain display example.
            local myStep = nil
            local myQuestID = group.members["(You)"]
            if myQuestID then
                local myCI = AQL and AQL:GetChainInfo(myQuestID)
                myStep = myCI and myCI.step
            end
            if myStep then
                for playerName, questID in pairs(group.members) do
                    if playerName ~= "(You)" then
                        local theirCI = AQL and AQL:GetChainInfo(questID)
                        local theirStep = theirCI and theirCI.step
                        if theirStep and theirStep ~= myStep then
                            local diff = myStep - theirStep
                            local rel = diff > 0
                                and string.format("You are %d step(s) ahead of %s.", diff, playerName)
                                or  string.format("You are %d step(s) behind %s.", -diff, playerName)
                            addText(rel, 16)
                        end
                    end
                end
            end
        else
            -- Standalone quest display.
            local questID = next(group.members)  -- get any questID for title lookup
            local title = AQL and AQL:GetQuest(questID) and AQL:GetQuest(questID).title
                          or C_QuestLog.GetTitleForQuestID(questID)
                          or ("Quest " .. questID)
            addText(C.header .. "[Quest] " .. title .. C.reset)

            for playerName, qid in pairs(group.members) do
                local label = "  " .. playerName .. ":"
                if playerName == "(You)" then
                    local info = AQL and AQL:GetQuest(qid)
                    if info then
                        for _, obj in ipairs(info.objectives or {}) do
                            label = label .. " " .. obj.numFulfilled .. "/" .. obj.numRequired
                        end
                    end
                else
                    local pentry = SocialQuestGroupData.PlayerQuests[playerName]
                    local pquest = pentry and pentry.quests and pentry.quests[qid]
                    if pquest then
                        for _, obj in ipairs(pquest.objectives or {}) do
                            label = label .. " " .. obj.numFulfilled .. "/" .. obj.numRequired
                        end
                    else
                        label = label .. " " .. SocialQuestColors.unknown .. "(no data)" .. SocialQuestColors.reset
                    end
                end
                addText(label, 8)
            end
        end

        ::continue::
    end

    frame.content:SetHeight(math.max(y, 10))
end

------------------------------------------------------------------------
-- My Quests Tab
------------------------------------------------------------------------

function SocialQuestGroupFrame:RenderMineTab()
    local AQL = SocialQuest.AQL
    if not AQL then return end
    local C = SocialQuestColors

    -- Build set of questIDs shared with any group member.
    local sharedIDs = {}
    for _, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests then
            for questID in pairs(entry.quests) do
                sharedIDs[questID] = true
            end
        end
    end

    local y = 0
    local function addText(text, indent)
        local fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", indent or 0, -y)
        fs:SetText(text)
        fs:SetWidth(340)
        y = y + fs:GetStringHeight() + 4
    end

    for questID, info in pairs(AQL:GetAllQuests()) do
        if not sharedIDs[questID] then
            local title = info.title or ("Quest " .. questID)
            local chain = info.chainInfo
            local header = C.white .. title .. C.reset
            if chain and chain.knownStatus == "known" then
                header = header .. "  " .. C.chain .. "(chain step " .. chain.step .. "/" .. chain.length .. ")" .. C.reset
            end
            addText(header)

            for _, obj in ipairs(info.objectives or {}) do
                addText("  " .. obj.text, 8)
            end
        end
    end

    frame.content:SetHeight(math.max(y, 10))
end

------------------------------------------------------------------------
-- Party Quests Tab
------------------------------------------------------------------------

function SocialQuestGroupFrame:RenderPartyTab()
    local AQL = SocialQuest.AQL
    if not AQL then return end
    local C = SocialQuestColors

    -- Build set of local player's questIDs.
    local myIDs = {}
    for questID in pairs(AQL:GetAllQuests()) do
        myIDs[questID] = true
    end

    local y = 0
    local function addText(text, indent)
        local fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", indent or 0, -y)
        fs:SetText(text)
        fs:SetWidth(340)
        y = y + fs:GetStringHeight() + 4
    end

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests then
            for questID, qdata in pairs(entry.quests) do
                if not myIDs[questID] then
                    local title = C_QuestLog.GetTitleForQuestID(questID) or ("Quest " .. questID)
                    local chain = AQL:GetChainInfo(questID)
                    local header = C.white .. title .. C.reset .. "  — " .. playerName

                    if chain and chain.knownStatus == "known" then
                        local myChain = nil
                        -- Check if local player is in same chain.
                        for myQuestID in pairs(AQL:GetAllQuests()) do
                            local myCI = AQL:GetChainInfo(myQuestID)
                            if myCI and myCI.chainID == chain.chainID then
                                myChain = myCI
                                break
                            end
                        end
                        if myChain then
                            local diff = chain.step - myChain.step
                            local rel = diff > 0 and ("you are " .. diff .. " step(s) behind")
                                      or diff < 0 and ("you are " .. (-diff) .. " step(s) ahead")
                                      or "same step"
                            header = header .. "  " .. C.chain .. "(chain step " .. chain.step .. "/" .. chain.length .. " — " .. rel .. ")" .. C.reset
                        else
                            header = header .. "  " .. C.chain .. "(chain step " .. chain.step .. "/" .. chain.length .. ")" .. C.reset
                        end
                    end

                    addText(header)

                    if entry.hasSocialQuest then
                        for _, obj in ipairs(qdata.objectives or {}) do
                            addText("  " .. obj.numFulfilled .. "/" .. obj.numRequired, 8)
                        end
                    end
                end
            end
        end
    end

    frame.content:SetHeight(math.max(y, 10))
end
```

- [ ] **Step 2: Call Initialize from SocialQuest.lua**

In `SocialQuest:OnEnable()`, no explicit init call needed — GroupFrame initializes lazily on first Toggle.

- [ ] **Step 3: Verify**

```
/sq
```
Expected: the group frame opens. Tabs are visible. With a group member who has SocialQuest, Shared tab shows common quests.

- [ ] **Step 4: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: add GroupFrame with Shared/Mine/Party tabs and chain-aware quest matching"
```

---

### Task 9: Minimap button

The spec states the Group Frame opens via "/sq **or the minimap button**" (spec §Group Quest Frame).

**Files:**
- Modify: `UI/GroupFrame.lua` (add minimap button construction)

- [ ] **Step 1: Add minimap button to GroupFrame.lua**

Append this function to `UI/GroupFrame.lua` after the frame construction block:

```lua
------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------

local minimapButton = CreateFrame("Button", "SocialQuestMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)

-- Use a standard icon texture. Replace path if a custom icon is added later.
minimapButton:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:SetPushedTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")

-- Position on the minimap edge.
local angle = 225  -- degrees, top-left region
local function updateMinimapButtonPosition()
    local rad  = math.rad(angle)
    local x    = 80 * math.cos(rad)
    local y    = 80 * math.sin(rad)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
updateMinimapButtonPosition()

-- Draggable repositioning around the minimap edge.
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", function(self)
    local cx, cy = Minimap:GetCenter()
    local mx, my = GetCursorPosition()
    local scale  = UIParent:GetEffectiveScale()
    angle = math.deg(math.atan2((my / scale) - cy, (mx / scale) - cx))
    updateMinimapButtonPosition()
end) end)
minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

minimapButton:SetScript("OnClick", function()
    SocialQuestGroupFrame:Toggle()
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("SocialQuest")
    GameTooltip:AddLine("Click to open group quest frame.", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
```

- [ ] **Step 2: Verify**

```
/reload
```
Expected: a small icon appears on the minimap edge. Clicking it opens/closes the Group Frame. Hovering shows a tooltip.

- [ ] **Step 3: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: add minimap button to open/close group quest frame"
```

---

## Chunk 5: Options Panel

AceConfig registration and all per-channel toggle options.

### Task 10: Options panel

**Files:**
- Create: `UI/Options.lua`
- Delete: `SocialQuest.options.lua` (old options file, all references removed)

- [ ] **Step 1: Write UI/Options.lua**

```lua
-- UI/Options.lua
-- AceConfig options table. Accessible via /sq config or Interface Options.

SocialQuestOptions = {}

function SocialQuestOptions:Initialize()
    local AceConfig       = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local db = SocialQuest.db.profile

    local function get(info)
        local key = info[#info]
        -- Walk info path to find value in db.profile.
        local t = db
        for i = 1, #info - 1 do t = t[info[i]] end
        return t[key]
    end

    local function set(info, value)
        local key = info[#info]
        local t = db
        for i = 1, #info - 1 do t = t[info[i]] end
        t[key] = value
    end

    local function toggle(label, desc, path)
        return {
            type    = "toggle",
            name    = label,
            desc    = desc,
            get     = function(info)
                local t = db
                for _, k in ipairs(path) do t = t[k] end
                return t
            end,
            set     = function(info, v)
                local t = db
                for i = 1, #path - 1 do t = t[path[i]] end
                t[path[#path]] = v
            end,
        }
    end

    local function announceGroup(pathPrefix)
        return {
            type = "group",
            name = "Announce Events",
            inline = true,
            args = {
                accepted  = toggle("Accepted",  "Announce quest accepted",  { pathPrefix, "announce", "accepted"  }),
                abandoned = toggle("Abandoned", "Announce quest abandoned", { pathPrefix, "announce", "abandoned" }),
                finished  = toggle("Finished",  "Announce objectives done", { pathPrefix, "announce", "finished"  }),
                completed = toggle("Completed", "Announce quest turned in", { pathPrefix, "announce", "completed" }),
                failed    = toggle("Failed",    "Announce quest failed",    { pathPrefix, "announce", "failed"    }),
            },
        }
    end

    local options = {
        type = "group",
        name = "SocialQuest",
        args = {

            general = {
                type  = "group",
                name  = "General",
                order = 1,
                args  = {
                    enabled         = toggle("Enable SocialQuest", "Master on/off switch.", { "enabled" }),
                    displayReceived = toggle("Show received events", "Display banners for events from other players.", { "general", "displayReceived" }),
                },
            },

            party = {
                type  = "group",
                name  = "Party",
                order = 2,
                args  = {
                    transmit        = toggle("Enable transmission",     "Send quest events to party.", { "party", "transmit" }),
                    displayReceived = toggle("Show received events",    "Show banners from party members.", { "party", "displayReceived" }),
                    objective       = toggle("Objective progress",      "Announce objective progress in party.", { "party", "announce", "objective" }),
                    events          = announceGroup("party"),
                },
            },

            raid = {
                type  = "group",
                name  = "Raid",
                order = 3,
                args  = {
                    transmit        = toggle("Enable transmission",   "Send quest events to raid.", { "raid", "transmit" }),
                    displayReceived = toggle("Show received events",  "Show banners from raid members.", { "raid", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends", "Suppress banners from non-friends in raid.", { "raid", "friendsOnly" }),
                    events          = announceGroup("raid"),
                },
            },

            guild = {
                type  = "group",
                name  = "Guild",
                order = 4,
                args  = {
                    transmit = toggle("Enable chat announcements", "Send quest events to guild chat. No AceComm sync occurs with guild.", { "guild", "transmit" }),
                    events   = announceGroup("guild"),
                },
            },

            battleground = {
                type  = "group",
                name  = "Battleground",
                order = 5,
                args  = {
                    transmit        = toggle("Enable transmission",   "Send quest events to battleground.", { "battleground", "transmit" }),
                    displayReceived = toggle("Show received events",  "Show banners from BG members.", { "battleground", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends", "Suppress banners from non-friends in BG.", { "battleground", "friendsOnly" }),
                    objective       = toggle("Objective progress",    "Announce objective progress in battleground.", { "battleground", "announce", "objective" }),
                    events          = announceGroup("battleground"),
                },
            },

            whisperFriends = {
                type  = "group",
                name  = "Whisper Friends",
                order = 6,
                args  = {
                    enabled   = toggle("Enable whispers to friends", "Send quest events as whispers to online friends.", { "whisperFriends", "enabled" }),
                    groupOnly = toggle("Group members only", "Restrict to friends currently in your group.", { "whisperFriends", "groupOnly" }),
                    objective = toggle("Objective progress", "Include objective progress in friend whispers (off by default).", { "whisperFriends", "announce", "objective" }),
                    events    = {
                        type   = "group",
                        name   = "Events",
                        inline = true,
                        args   = {
                            accepted  = toggle("Accepted",  nil, { "whisperFriends", "announce", "accepted"  }),
                            abandoned = toggle("Abandoned", nil, { "whisperFriends", "announce", "abandoned" }),
                            finished  = toggle("Finished",  nil, { "whisperFriends", "announce", "finished"  }),
                            completed = toggle("Completed", nil, { "whisperFriends", "announce", "completed" }),
                            failed    = toggle("Failed",    nil, { "whisperFriends", "announce", "failed"    }),
                        },
                    },
                },
            },

            follow = {
                type  = "group",
                name  = "Follow Notifications",
                order = 7,
                args  = {
                    enabled           = toggle("Enable follow notifications",       "Send whispers when following starts/stops.", { "follow", "enabled" }),
                    announceFollowing = toggle("Announce when you follow someone",  "Whisper the player you start following.", { "follow", "announceFollowing" }),
                    announceFollowed  = toggle("Announce when followed",            "Show message when someone starts following you.", { "follow", "announceFollowed"  }),
                },
            },

            debug = {
                type  = "group",
                name  = "Debug",
                order = 8,
                args  = {
                    enabled = toggle("Enable debug mode", "Print debug messages to chat.", { "debug", "enabled" }),
                },
            },
        },
    }

    AceConfig:RegisterOptionsTable("SocialQuest", options)
    AceConfigDialog:AddToBlizzard("SocialQuest")
end
```

- [ ] **Step 2: Delete the old options file**

Delete `SocialQuest.options.lua` — it has been superseded by `UI/Options.lua`.

- [ ] **Step 3: Load and verify**

```
/reload
/sq config
```
Expected: the Interface Options panel opens with the SocialQuest section visible, all toggles present and functional.

- [ ] **Step 4: Commit**

```bash
git add UI/Options.lua
git rm SocialQuest.options.lua
git commit -m "feat: add AceConfig options panel; replace old options.lua"
```

---

## Chunk 6: Final Verification

End-to-end checklist from the spec's Testing Checklist.

### Task 11: Full verification

- [ ] **Step 1: Addon loads without errors**
```
/reload
```
No red Lua error dialogs. No error spam in chat.

- [ ] **Step 2: Options panel accessible**
```
/sq config
```
Expected: opens cleanly with all sections.

- [ ] **Step 3: Quest accepted announces in party**
Join a party. Accept a quest. Expected: announcement appears in party chat.

- [ ] **Step 4: Quest completed announces in party**
Turn in a quest. Expected: completion message in party chat.

- [ ] **Step 5: Objective progress announces in party, NOT in raid**
In a party: kill quest mobs. Expected: objective message in party chat.
In a raid: kill quest mobs. Expected: no objective message.

- [ ] **Step 6: Guild announces respect per-event toggles**
Toggle "Accepted" off in guild settings. Accept a quest. Expected: no guild announcement.

- [ ] **Step 7: Friend whispers fire**
Enable Whisper Friends with a friend online. Accept a quest. Expected: friend receives a whisper.

- [ ] **Step 8: Whispers respect group-members-only toggle**
Enable "Group members only" with a friend not in group. Accept a quest. Expected: friend does NOT receive whisper.

- [ ] **Step 9: 1-second throttle works**
Accept two quests rapidly. Expected: second chat message appears ~1 second after first.

- [ ] **Step 10: Banner appears from SQ_UPDATE**
Have a group member (also running SocialQuest) accept a quest. Expected: banner appears on your screen.

- [ ] **Step 11: Friends-only filter suppresses raid banners from non-friends**
Enable "Only show notifications from friends" in Raid. Have a non-friend raid member accept a quest. Expected: no banner on your screen.

- [ ] **Step 12: SQ_INIT broadcasts on party join**
Join a party. Expected: other SocialQuest member's quests appear in GroupData (visible in Group Frame).

- [ ] **Step 13: Raid uses beacon+pull**
Join a raid. Expected: no full SQ_INIT broadcast. SQ_BEACON sent with 0-8s delay. Data arrives via whisper response to SQ_REQUEST.

- [ ] **Step 14: Group frame opens**
```
/sq
```
Expected: frame opens, tabs visible.

- [ ] **Step 15: Shared Quests tab shows chain grouping**
Have a group member on a different step of the same chain. Expected: both players appear under the same chain entry in Shared tab.

- [ ] **Step 16: No text contamination from Spanish-client group member**
Have a different-locale group member in party. Expected: all text in the Group Frame and tooltips displays in your own client language.

- [ ] **Step 17: Solo play produces no errors**
Dismiss group. Accept/abandon quests. Expected: no errors, no orphaned banners.

- [ ] **Step 18: Final commit**

```bash
git add --all
git status  # confirm only expected files
git commit -m "feat: SocialQuest v2.0 complete — AQL-driven, chain-aware group coordination addon"
```
