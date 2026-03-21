# SocialQuest - WoW TBC Addon

## Project Overview

**SocialQuest** is a World of Warcraft addon for The Burning Crusade Anniversary edition. It enables players in parties, raids, and guilds to coordinate quest progress by sharing quest events and displaying group member progress in real time.

**Interface**: 20505 (TBC Anniversary)
**Author**: Thad Ryker
**Status**: Active development (Improvements branch)

> **IMPORTANT FOR CLAUDE:** This file must be updated whenever significant changes are made to the project — architecture changes, new modules, protocol changes, dependency changes, or notable bug fixes. Update the version number in `SocialQuest.toc` after every set of meaningful changes using the versioning rule below. Do not leave this file stale.

>**Versioning Rule:** The major version number should never be changed by claude unless explicitly instructed to do so.  The first time add-on functionality is modified on any given day, the minor version number should be incremented and the revision number should be reset to 0. Any extra changes ocurring within the same days should increment the revision number only, unless explicitly instructed otherwise.

---

## Architecture

### Entry Point

`SocialQuest.lua` — Creates the Ace3 addon object, handles `OnInitialize` and `OnEnable`, registers WoW events and AQL callbacks, and delegates everything else to sub-modules. Registers these WoW events: `GROUP_ROSTER_UPDATE`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `AUTOFOLLOW_BEGIN`, `AUTOFOLLOW_END`.

### Core Modules (`Core\`)

| File | Global | Responsibility |
|---|---|---|
| `Core\GroupComposition.lua` | `SocialQuestGroupComposition` | Sole handler for group membership changes. Diffs `GROUP_ROSTER_UPDATE` against a membership snapshot to classify join/leave/subgroup-move events, then dispatches typed callbacks to Communications and GroupData. Owns the `GroupType` enum. |
| `Core\GroupData.lua` | `SocialQuestGroupData` | Owns `PlayerQuests` table. Populated entirely from incoming AceComm messages. Stores numeric-only data — no quest titles or objective text from remote players. |
| `Core\Communications.lua` | `SocialQuestComm` | All AceComm send/receive. Manages sync protocol, jitter timers, and per-sender cooldowns. |
| `Core\Announcements.lua` | `SocialQuestAnnounce` | All chat announcements (outbound) and banner notifications (inbound). Drives throttle queue, Questie suppression, UIErrorsFrame hook. |

### UI Modules (`UI\`)

| File | Global | Responsibility |
|---|---|---|
| `UI\TabUtils.lua` | `SocialQuestTabUtils` | Shared helpers for tab providers and RowFactory: Wowhead URL builder, zone resolution, chain info, objective row builders. |
| `UI\RowFactory.lua` | `SocialQuestRowFactory` | Builds quest row frames. |
| `UI\Tabs\MineTab.lua` | — | "My Quests" tab provider. |
| `UI\Tabs\PartyTab.lua` | — | "Party" tab provider. |
| `UI\Tabs\SharedTab.lua` | — | "Shared" tab provider. |
| `UI\Options.lua` | `SocialQuestOptions` | AceConfig options panel. |
| `UI\Tooltips.lua` | `SocialQuestTooltips` | Quest tooltip enhancement with group progress. |
| `UI\GroupFrame.lua` | `SocialQuestGroupFrame` | Main group quest progress window. |

### Utilities

- `Util\Colors.lua` — Color definitions.
- `Locales\*.lua` — AceLocale locale files (enUS through jaJP).

---

## Dependencies

### Required

- **Ace3** (AceAddon, AceEvent, AceComm, AceTimer, AceConsole, AceDB, AceConfig, AceSerializer, AceLocale) — addon framework
- **AbsoluteQuestLog-1.0 (AQL)** — quest data library. Provides quest/objective snapshots and callbacks. **This is a hard dependency; the addon disables itself if AQL is missing.**

### Bundled

- `Libs\LibDataBroker-1.1` — minimap button data broker
- `Libs\LibDBIcon-1.0` — minimap button icon

---

## Communication Protocol

All payloads are **numeric-only** — no quest titles or objective text are ever transmitted. Text is resolved locally from AQL on the receiving end.

### AceComm Prefixes

| Prefix | Direction | Description |
|---|---|---|
| `SQ_INIT` | broadcast or whisper | Full quest log snapshot (questID + objective counts) |
| `SQ_UPDATE` | broadcast | Single quest state change (accepted, completed, abandoned, etc.) |
| `SQ_OBJECTIVE` | broadcast | Single objective progress update |
| `SQ_REQUEST` | whisper | Force Resync — requests a full `SQ_INIT` from a specific player |
| `SQ_FOLLOW_START` | whisper | Follow notification |
| `SQ_FOLLOW_STOP` | whisper | Follow notification |
| `SQ_REQ_COMPLETED` | broadcast | Requests completed quest history from all group members |
| `SQ_RESP_COMPLETE` | whisper | Response with completed quest history |
| `SQ_FLIGHT` | broadcast (PARTY) | Flight path discovery notification |

### Sync Protocol (current)

**On join (party):** Broadcast `SQ_INIT` to `PARTY` channel. Each existing member's `OnMemberJoined` fires and sends a direct `SQ_INIT` whisper to the new joiner.

**On join (raid/BG):** Broadcast `SQ_INIT` to `RAID`/`INSTANCE_CHAT`. Each existing member who receives it schedules a **jittered whisper response (1–8 s random delay)** — prevents the burst pattern that previously triggered Blizzard bot-detection.

**Subgroup moves:** Detected by `GroupComposition` and suppressed — no sync activity.

**Force Resync:** Sends `SQ_REQUEST` whisper; recipient responds with a jittered `SQ_INIT` (1–4 s delay). 15-second per-sender cooldown prevents duplicate responses.

**SQ_BEACON is eliminated.** The old protocol used SQ_BEACON → SQ_REQUEST → up to 39 simultaneous SQ_INIT whispers, which caused bot-detection false positives. This has been replaced with the direct SQ_INIT broadcast + jittered response pattern described above.

---

## GroupType Enum

Defined as a file-scope local in `Core\GroupComposition.lua` and exposed as `SocialQuestGroupComposition.GroupType`. Aliased at file scope in `Communications.lua`. Values are plain English strings (self-documenting in debug output). **Never transmitted over the wire; never localized.**

```lua
GroupType = {
    Party        = "party",
    Raid         = "raid",
    Battleground = "battleground",
}
```

---

## AQL Callbacks (registered in `SocialQuest:OnEnable`)

| Callback | Handler | Notes |
|---|---|---|
| `AQL_QUEST_ACCEPTED` | `OnQuestAccepted` | Broadcasts `SQ_UPDATE` + announces |
| `AQL_QUEST_ABANDONED` | `OnQuestAbandoned` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_FINISHED` | `OnQuestFinished` | Turn-in complete |
| `AQL_QUEST_COMPLETED` | `OnQuestCompleted` | Objectives met, not yet turned in |
| `AQL_QUEST_FAILED` | `OnQuestFailed` | Broadcasts `SQ_UPDATE` |
| `AQL_QUEST_TRACKED` / `AQL_QUEST_UNTRACKED` | `OnQuestTracked/Untracked` | Local only — not broadcast |
| `AQL_OBJECTIVE_PROGRESSED` | `OnObjectiveProgressed` | Broadcasts `SQ_OBJECTIVE`; also cancels pending regression debounce |
| `AQL_OBJECTIVE_REGRESSED` | `OnObjectiveRegressed` | 0.5 s debounce — cancelled by subsequent PROGRESSED/COMPLETED (suppresses BAG_UPDATE stack-split artefacts) |
| `AQL_OBJECTIVE_COMPLETED` | `OnObjectiveCompleted` | Broadcasts `SQ_OBJECTIVE`; cancels pending regression debounce |
| `AQL_UNIT_QUEST_LOG_CHANGED` | `OnUnitQuestLogChanged` | Creates `hasSocialQuest=false` stub for non-SQ group members |

### Zone Transition Suppression

`PLAYER_ENTERING_WORLD` sets a 3-second suppression window (`zoneTransitionSuppressUntil`). All AQL quest and objective callbacks return early during this window to prevent re-announcing the entire quest log on hearth/zone-in.

---

## PlayerQuests Data Structure

```lua
-- Core/GroupData.lua
PlayerQuests["Name-Realm"] = {
    hasSocialQuest = true,
    lastSync       = GetTime(),
    completedQuests = { [questID] = true, ... },
    quests = {
        [questID] = {
            questID      = N,
            title        = "string",   -- resolved locally, never transmitted
            isComplete   = bool,
            isFailed     = bool,
            snapshotTime = N,
            timerSeconds = N_or_nil,
            objectives   = {
                { numFulfilled=N, numRequired=N, isFinished=bool }, ...
            }
        }
    }
}
-- Players without SocialQuest: { hasSocialQuest=false, completedQuests={} }
```

---

## Configuration

Configured via AceConfig (`/sq config`). Settings stored in `SocialQuestDB` (AceDB saved variable, shared profile across characters).

Per-channel settings (party, raid, battleground, guild):
- Enable transmission
- Display received events
- Per-event-type announce toggles (accepted, completed, finished, abandoned, failed)

Other settings: follow notifications, debug mode, debug event type filter.

---

## Debug

Enable via `/sq config` → Debug tab. Debug messages appear in the default chat frame as `[SQ][Category] message`. Categories: `Group`, `Comm`, `Quest`, `Announce`, `Resync`.

---

## Version History

### Version 2.2.0 (March 2026 — Improvements branch)
- Flight Path Discovery: detects new flight path unlocks via `TAXIMAP_OPENED`; broadcasts to party via `SQ_FLIGHT` prefix; displays banner using quest-accepted green color. Per-character `knownFlightNodes` persists across sessions. Handles first-run, mid-game install, and unknown-race edge cases.
- Needs-Shared Eligibility: "Needs it Shared" rows now suppressed unless the quest is shareable (`GetQuestLogPushable`), the player has not completed it, and any chain prerequisite has been completed.
- Quest Log Toggle: left-clicking a quest title in the SQ window now closes the quest log if it is already open and showing that quest.

### Version 2.1.2 (March 2026 — Improvements branch)
- Updated all `knownStatus` comparisons to use `AQL.ChainStatus.Known` / `AQL.ChainStatus.Unknown` constants

### Version 2.1.1 (March 2026 — Improvements branch)
- GroupFrame now preserves per-tab scroll position across rebuilds; no longer resets to top on quest updates

### Version 2.1.0 (March 2026 — Improvements branch)
- Added `Core\GroupComposition.lua` module — sole owner of `GROUP_ROSTER_UPDATE` / `PLAYER_LOGIN` events
- Eliminated SQ_BEACON storm pattern; replaced with direct SQ_INIT broadcast + jittered responses
- Subgroup moves in raids no longer trigger sync activity
- Immediate player eviction on leave (no 30-second delay)
- Added `GroupType` enum (`Party`/`Raid`/`Battleground`) to replace raw string comparisons
- 7 bug fixes: hyperlink fallback in abandoned banners, tracked/untracked storm, zone-transition re-announce suppression, BAG_UPDATE regression debounce, `/reload` group re-sync ordering, remote-only quest zone resolution, remote objective text fallback

### Version 2.0 (earlier 2026)
- Major refactor: added AQL integration, group progress tracking, PartyTab, GroupFrame, tooltip enhancement, banner notifications, follow system, minimap button
- Multi-language locale support

### Version 1.01 (March 2026)
- Updated for TBC Anniversary compatibility (Interface 20505)
- Replaced deprecated APIs

---

*This file must be kept up to date. Update it when adding modules, changing the protocol, fixing significant bugs, or bumping the version number.*
