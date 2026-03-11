# SocialQuest — Design Specification

**Date:** 2026-03-11
**Version:** 2.0
**Interface:** 20505 (WoW Burning Crusade Anniversary)
**Author:** Thad Ryker
**Status:** Approved for implementation

---

## Overview

SocialQuest is a WoW addon that helps group members coordinate quest progress together. It broadcasts quest events to group chat channels, syncs quest state between group members via addon communication, enhances quest tooltips with group progress, and provides a group quest frame for coordinating quest chains across the party or raid.

SocialQuest is an **AceAddon** that consumes **AbsoluteQuestLog-1.0** (AQL) as its sole source of quest data. It never calls `C_QuestLog` directly.

---

## Dependencies

| Dependency | Type | Notes |
|---|---|---|
| Ace3 | Required | AceAddon, AceEvent, AceComm, AceDB, AceConfig, AceSerializer, AceTimer, AceConsole |
| AbsoluteQuestLog-1.0 | Required | Must be installed as a standalone addon |
| Questie | Optional | Enhances AQL chain data (consumed transparently via AQL) |
| QuestWeaver | Optional | Fallback chain data source (consumed transparently via AQL) |

---

## Architecture

```
SocialQuest (AceAddon)
│
├── Core/
│   ├── Communications.lua    -- AceComm send/receive, serialization, jitter/init logic
│   ├── Announcements.lua     -- Chat message formatting, throttle queue
│   └── GroupData.lua         -- PlayerQuests table management
│
├── UI/
│   ├── Tooltips.lua          -- ItemRefTooltip hook, quest tooltip rendering
│   ├── GroupFrame.lua        -- Group quest window (tabs, chain display)
│   └── Options.lua           -- AceConfig options panel
│
└── Util/
    └── Colors.lua            -- Color constants
```

---

## Core Principle: No Text Over the Wire

**SocialQuest never transmits quest titles, objective text, or any string content derived from the WoW quest API over AceComm.** All addon communication uses numeric identifiers and progress values only.

When displaying another player's quest data, all text (quest title, objective description, chain name) is resolved **locally** from AQL using the receiving client's own language. This ensures:

- A Spanish-language client's quest text never appears in an English client's UI
- Each player always sees quest information in their own configured language
- Quest identification is always by numeric questID — unambiguous across all locales
- Transmitted payloads are smaller and simpler

If AQL cannot resolve a title for a given questID (neither Questie nor QuestWeaver installed, and the quest is not in the local player's own log), the UI displays the questID with a localized "Unknown Quest" placeholder.

---

## Group Data Model

SocialQuest maintains a `PlayerQuests` table populated entirely through AceComm messages. All values are numeric:

```lua
SocialQuest.PlayerQuests = {
    ["Thrallson-Kirin Tor"] = {
        hasSocialQuest = true,
        lastSync       = <timestamp>,
        quests = {
            [1234] = {
                questID      = 1234,
                isComplete   = false,
                isFailed     = false,
                isTracked    = true,         -- updated via SQ_UPDATE when AQL_QUEST_TRACKED / AQL_QUEST_UNTRACKED fires
                snapshotTime = 12345.678,    -- sender's GetTime() at moment of transmission
                timerSeconds = 300,          -- seconds remaining at snapshotTime; nil if no timer
                objectives = {
                    { numFulfilled = 4, numRequired = 10, isFinished = false },
                    { numFulfilled = 1, numRequired = 5,  isFinished = false },
                }
            },
        }
    },
    ["Jaina-Kirin Tor"] = {
        hasSocialQuest = false,   -- in group but no addon data available
    },
}
```

Players without SocialQuest always get a stub entry so the group frame can show all group members consistently.

---

## Communication Protocol

Six AceComm prefixes. All message payloads contain numeric data only.

| Prefix | Direction | Payload | Purpose |
|---|---|---|---|
| `SQ_INIT` | broadcast/whisper | Full quest snapshot (all questIDs + objective counts) | Full log sync |
| `SQ_UPDATE` | broadcast | Single quest state change | Accept/complete/abandon/fail |
| `SQ_OBJECTIVE` | broadcast | Single objective progress | Real-time objective update |
| `SQ_BEACON` | broadcast | empty | Announce presence without sending full log; recipients respond with `SQ_REQUEST` if they want data |
| `SQ_REQUEST` | whisper | empty | Request full snapshot from a specific player |
| `SQ_FOLLOW_START` | whisper | empty | Follow notification: started following |
| `SQ_FOLLOW_STOP` | whisper | empty | Follow notification: stopped following |

### Initialization Strategy by Group Size

| Context | Strategy | Jitter | Rationale |
|---|---|---|---|
| Party (≤5) | Broadcast full `SQ_INIT` | None needed | Small audience, full sync is cheap, no storm risk |
| Raid (6–40) | Broadcast `SQ_BEACON`, then respond to `SQ_REQUEST` whispers | 0–8s random before beacon | Prevents 40-player init storm |
| Battleground | Broadcast `SQ_BEACON`, then respond to `SQ_REQUEST` whispers | 0–8s random before beacon | Fast-paced groups; beacon+pull keeps traffic minimal |
| Guild | No sync (guild is chat-only) | N/A | Guild quest data not meaningful for group coordination |

The jitter delay for Raid and Battleground is a random value in the 0–8 second range, chosen at the time of `GROUP_ROSTER_UPDATE`. This staggers beacon broadcasts naturally without coordination. Party joins send `SQ_INIT` immediately — with at most 4 recipients the storm risk does not apply.

---

## Chat Announcement System

### Throttle

All `SendChatMessage` calls flow through a throttle queue with a **1-second minimum interval** between sends. This protects against Blizzard's server-side bot detection for chat messages. The queue is a FIFO list; duplicate messages are dropped before enqueue.

### Announcement Matrix

Determines which events generate chat announcements per channel type:

| Event | Party | Raid | Guild | Battleground | Whisper Friends |
|---|---|---|---|---|---|
| Accepted | ✓ | ✓ | ✓ | ✓ | ✓ |
| Abandoned | ✓ | ✓ | ✓ | ✓ | ✓ |
| Finished (objectives done) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Completed (turned in) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Failed | ✓ | ✓ | ✓ | ✓ | ✓ |
| Objective progress | ✓ | — | — | — | ✓ (optional) |

Party and Battleground receive the full event set. Raid and Guild omit objective progress to avoid spam in large groups. Whisper Friends includes objective progress as a user-configurable toggle (off by default).

### Whisper Friends Logic

When the Whisper Friends channel is enabled:
1. At event time, iterate `C_FriendList` to build a list of online friends
2. If "Group members only" toggle is enabled, filter to friends who are also in the current party/raid/battleground
3. Each qualifying friend receives an individual `SendChatMessage(..., "WHISPER", friendName)`
4. All whispers flow through the same throttle queue as other chat messages

---

## Banner Notification System

On-screen banner notifications use `RaidWarningFrame:AddMessage()`. These are separate from chat announcements and are triggered by receiving `SQ_UPDATE` messages from other SocialQuest users.

### Friends-Only Filter

Raid and Battleground channel settings each expose a **"Only show notifications from friends"** toggle. When enabled, banner notifications from players not on the local player's friends list are suppressed. Chat announcements are unaffected by this filter — they always appear in the channel.

The check uses `C_FriendList.IsFriend(senderName)` at the point of rendering the banner.

---

## Graceful Degradation

Three tiers of functionality depending on whether group members have SocialQuest:

| Tier | Who | Capabilities |
|---|---|---|
| **Full** | SocialQuest users | All quests, full objective progress, real-time updates, chain alignment |
| **Partial** | Non-SocialQuest, quests shared with local player | Quest name known, no objective progress counts |
| **None** | Non-SocialQuest, different quests | Name shown, quests unknown indicator |

`UNIT_QUEST_LOG_CHANGED` fires for party/raid members even without SocialQuest. When this fires for a non-SocialQuest member, AQL exposes it as `AQL_UNIT_QUEST_LOG_CHANGED(unit)`. SocialQuest responds by sweeping the local player's quest log to check shared quests using `UnitIsOnQuest(questLogIndex, unit)` — note this takes a *quest log index* (not a questID) and a unit token such as `"party1"`. The implementation must iterate indices 1 through `GetNumQuestLogEntries()`, skipping any entry where `GetQuestLogTitle(index)` returns `isHeader = true` (category header rows are not quests and have invalid questID fields), and mapping each valid quest entry index to a questID to build the shared quest list for that unit.

Players without SocialQuest are never hidden from the group frame — they always appear with whatever tier of data is available.

---

## Group Quest Frame

Opened via `/sq` or the minimap button. Displays quest coordination information for the current group.

### Chain-Aware Quest Matching

The group frame does **not** match quests by questID alone. It matches by **chainID** (the questID of the first quest in a chain, as returned by `AQL:GetChainInfo()`). Two players are considered to be working on the same content if their active quests share a `chainID`, even if they are at different steps.

This means a player on step 5 of a chain and a party member on step 3 of the same chain are grouped together in the Shared Quests tab, with their relative positions clearly shown.

When `knownStatus = "unknown"` for a quest (no chain provider available), matching falls back to exact questID comparison for that quest.

### Tabs

**Shared Quests Tab**

Quests (or chains) where at least two group members are working on the same content. Standalone quests are grouped by questID; chain quests are grouped by chainID.

Chain display:
```
[Chain] The Legend of Stalvan (10 steps)
  Step:  1 -- 2 -- 3 -- 4 -- 5 -- 6 -- 7 -- 8 -- 9 -- 10
  You:                  ●  (step 5, active)
  Brother:        ●  (step 3, active)

  You are 2 steps ahead in this chain.
```

Standalone quest display:
```
[Quest] The Tainted Scar
  You:       3/10 killed   1/5 collected
  Thrallson: 4/10 killed   ░░░ (no data)
```

Timed quest display (timer shown when `timerSeconds` is present):
```
[Quest] Escape from Durnholde  ⏱ 4:32 remaining
  You:       Stage 2 complete
  Thrallson: Stage 1 complete  ⏱ ~3:45 remaining (est.)
```

The local player's timer is calculated live from AQL. A remote player's timer is estimated using `timerSeconds - (GetTime() - snapshotTime)`. The `~` prefix and `(est.)` suffix indicate the value is an approximation based on a past snapshot rather than a live reading. If the estimated time has elapsed to zero or below, display "Timer may have expired" instead.

**My Quests Tab**

Quests only the local player has (not shared with any SocialQuest group member). Each entry shows:
- Quest title and level
- Current objective progress
- Chain annotation if applicable: "Part of chain: The Legend of Stalvan (step 5 of 10)"

**Party Quests Tab**

Quests that other group members have but the local player does not. Useful for deciding whether to pick up a quest to join a group member. Each entry shows:
- Quest title (resolved locally from AQL)
- Which group member(s) have it
- Chain annotation if applicable: "Part of chain: The Legend of Stalvan (step 3 of 10) — you are 2 steps behind"
- Objective progress if available (SocialQuest members only)

### Auto-Update

The frame re-renders in response to:
- `SQ_UPDATE` messages (quest accepted/completed/abandoned/failed)
- `SQ_OBJECTIVE` messages (objective progress changed)
- `AQL_UNIT_QUEST_LOG_CHANGED` (partial data tier update for non-SocialQuest members)
- `GROUP_ROSTER_UPDATE` (player joined or left group)

No manual refresh button is needed.

---

## Options Panel

Registered with AceConfig and accessible via Blizzard's Interface Options or `/sq config`.

### General
- Enable/disable SocialQuest
- Display received quest events (banner notifications on/off globally)
- Per-event receive toggles (Accepted, Abandoned, Finished, Completed, Failed)

### Party
- Enable transmission
- Display received events
- Per-event announce toggles (all six events)

### Raid
- Enable transmission
- Display received events
- Per-event announce toggles (Accepted, Abandoned, Finished, Completed, Failed — no Objective Progress)
- **"Only show notifications from friends"** toggle

### Guild
- Enable chat announcements (note: Guild is chat-only — no AceComm quest data sync occurs with guild members)
- Per-event announce toggles (Accepted, Abandoned, Finished, Completed, Failed — no Objective Progress)

### Battleground
- Enable transmission
- Display received events
- Per-event announce toggles (all six events)
- **"Only show notifications from friends"** toggle

### Whisper Friends
- Enable whisper to friends
- **"Group members only"** — restrict to friends currently in your group
- Per-event announce toggles (Accepted, Abandoned, Finished, Completed, Failed, Objective Progress)

### Follow Notifications
- Enable follow notifications
- Announce when you start following someone
- Announce when someone starts following you

### Debug
- Enable debug mode
- Per-event debug announce toggles

---

## WoW Events Handled

| WoW Event | Handler | Action |
|---|---|---|
| `GROUP_ROSTER_UPDATE` | `SocialQuest:GROUP_ROSTER_UPDATE` | Trigger init sync or clear stale PlayerQuests data |
| `AUTOFOLLOW_BEGIN` | `SocialQuest:AUTOFOLLOW_BEGIN` | Send `SQ_FOLLOW_START` whisper |
| `AUTOFOLLOW_END` | `SocialQuest:AUTOFOLLOW_END` | Send `SQ_FOLLOW_STOP` whisper |

Quest events are handled entirely via AQL callbacks — SocialQuest registers no WoW quest events directly.

### AQL Callbacks Registered

| AQL Callback | Handler | Notes |
|---|---|---|
| `AQL_QUEST_ACCEPTED` | `SocialQuest:OnQuestAccepted` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_ABANDONED` | `SocialQuest:OnQuestAbandoned` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_FINISHED` | `SocialQuest:OnQuestFinished` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_COMPLETED` | `SocialQuest:OnQuestCompleted` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_FAILED` | `SocialQuest:OnQuestFailed` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_TRACKED` | `SocialQuest:OnQuestTracked` | Broadcasts `SQ_UPDATE` with updated `isTracked = true` |
| `AQL_QUEST_UNTRACKED` | `SocialQuest:OnQuestUntracked` | Broadcasts `SQ_UPDATE` with updated `isTracked = false` |
| `AQL_OBJECTIVE_PROGRESSED` | `SocialQuest:OnObjectiveProgressed` | Broadcasts `SQ_OBJECTIVE` |
| `AQL_OBJECTIVE_REGRESSED` | `SocialQuest:OnObjectiveRegressed` | Broadcasts `SQ_OBJECTIVE` to keep remote PlayerQuests accurate; regressions can occur when quest cache rebuilds after a disconnect or reload |
| `AQL_UNIT_QUEST_LOG_CHANGED` | `SocialQuest:OnUnitQuestLogChanged` | Triggers `UnitIsOnQuest` sweep for partial-data tier |

---

## Error Handling

- **Missing AQL**: If `LibStub("AbsoluteQuestLog-1.0")` returns nil, SocialQuest prints a single clear error message and disables itself. No repeated Lua errors.
- **Deserialization failures**: Incoming AceComm messages that fail to deserialize are silently dropped. A debug-mode warning is logged. The sender is not automatically re-requested to avoid feedback loops.
- **Stale PlayerQuests data**: If a message arrives from a player no longer in the group, it is discarded.
- **Friend list unavailability**: `C_FriendList` calls at login may return incomplete data. Whisper dispatch guards against nil returns.
- **Group frame with unknown chain data**: When `knownStatus = "unknown"`, chain annotations are omitted from the display entirely. The quest still appears — it just shows no chain context.

---

## Testing Checklist

### Core Functionality
- [ ] Addon loads without errors with AQL present
- [ ] Clear error message displayed and addon disabled if AQL is missing
- [ ] Options panel accessible via `/sq config`
- [ ] All settings persist across UI reloads

### Chat Announcements
- [ ] Quest accepted announcement appears in party chat
- [ ] Quest completed announcement appears in party chat
- [ ] Objective progress announcement appears in party (not raid)
- [ ] Finished/Completed announce in raid; objective progress does not
- [ ] Guild announcements respect per-event toggles
- [ ] Friend whispers fire for configured events
- [ ] Friend whispers respect "group members only" toggle
- [ ] 1-second throttle prevents message bursts
- [ ] Duplicate messages are dropped from queue

### Banner Notifications
- [ ] Banner appears when receiving SQ_UPDATE from SocialQuest group member
- [ ] Friends-only filter suppresses banners from non-friends in raid
- [ ] Friends-only filter does not affect chat announcements

### Group Data Sync
- [ ] SQ_INIT broadcasts on party join with jitter delay
- [ ] In raid (6+ members), beacon fires instead of full broadcast
- [ ] SQ_REQUEST response sends correct numeric-only snapshot
- [ ] SQ_OBJECTIVE updates group frame in real time
- [ ] Player leaving group clears their PlayerQuests entry
- [ ] Late SQ_UPDATE from player no longer in group is discarded
- [ ] No quest text strings present in any transmitted payload

### Tooltips
- [ ] Tooltip shows party member objective progress for a shared quest
- [ ] Tooltip shows "data unavailable" for non-SocialQuest party members
- [ ] Tooltip text is in local client language regardless of sender's language

### Group Frame
- [ ] Shared Quests tab shows quests shared by questID match
- [ ] Shared Quests tab groups chain quests by chainID across different steps
- [ ] Chain display shows correct step positions for each group member
- [ ] "You are N steps ahead/behind" message appears correctly
- [ ] My Quests tab shows only local player's unshared quests
- [ ] Party Quests tab shows other members' quests not held by local player
- [ ] Non-SocialQuest member appears with partial data row
- [ ] Non-SocialQuest member appears with "no data" row when no shared quests
- [ ] Frame auto-updates on quest events without manual refresh
- [ ] Unknown chain quests display without chain annotation (no errors)

### Localization
- [ ] Quest titles display in local client language
- [ ] Objective text displays in local client language
- [ ] Chain names display in local client language
- [ ] Receiving data from a different-language client causes no text contamination

### Timed Quests
- [ ] Local timed quest shows live countdown in group frame
- [ ] Remote timed quest shows estimated countdown with `~` and `(est.)` indicator
- [ ] Remote timed quest with elapsed timer shows "Timer may have expired"
- [ ] Non-timed quest shows no timer display (no nil errors)

### Edge Cases
- [ ] Solo play: no messages sent, no errors, frame shows only My Quests
- [ ] Accepting a quest with no objectives does not crash
- [ ] Logging in with a full quest log (25 quests) initializes correctly
- [ ] Reloading UI mid-group re-syncs correctly
- [ ] Follow start/stop notifications fire correctly
