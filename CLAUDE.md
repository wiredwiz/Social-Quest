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
| `Core\WowAPI.lua` | `SocialQuestWowAPI` | Thin pass-through wrappers for all WoW game-state and data globals. All version-specific branching for non-quest APIs lives here. Consumer files access via `local SQWowAPI = SocialQuestWowAPI`. |
| `Core\WowUI.lua` | `SocialQuestWowUI` | Thin pass-through wrappers for volatile WoW UI-layer primitives (`RaidNotice_AddMessage`, `PanelTemplates_*`, `DEFAULT_CHAT_FRAME`). Consumer files access via `local SQWowUI = SocialQuestWowUI`. |
| `Core\GroupComposition.lua` | `SocialQuestGroupComposition` | Sole handler for group membership changes. Diffs `GROUP_ROSTER_UPDATE` against a membership snapshot to classify join/leave/subgroup-move events, then dispatches typed callbacks to Communications and GroupData. Owns the `GroupType` enum. Calls `BridgeRegistry:EnableAll()`/`DisableAll()` on join/leave. |
| `Core\GroupData.lua` | `SocialQuestGroupData` | Owns `PlayerQuests` table. Populated from SQ AceComm messages and bridge modules. Stores numeric-only data — no quest titles or objective text from remote players. Each entry has a `dataProvider` field (`DataProviders.SocialQuest`, `DataProviders.Questie`, or `nil` for stubs). |
| `Core\Communications.lua` | `SocialQuestComm` | All AceComm send/receive. Manages sync protocol, jitter timers, and per-sender cooldowns. |
| `Core\Announcements.lua` | `SocialQuestAnnounce` | All chat announcements (outbound) and banner notifications (inbound). Drives throttle queue, Questie suppression, UIErrorsFrame hook. |
| `Core\BridgeRegistry.lua` | `SocialQuestBridgeRegistry` | Thin lifecycle manager for data-provider bridges. Holds registered bridges; `EnableAll()` hydrates then enables each available bridge on group join; `DisableAll()` suspends processing on leave; `GetNameTag(provider)` returns the display icon for a provider. |
| `Core\QuestieBridge.lua` | `QuestieBridge` | Questie bridge implementation. Hooks `QuestieComms:InsertQuestDataPacket` and `QuestieComms.data:RemoveQuestFromPlayer` via `hooksecurefunc`. `_active` flag gates processing; `_hookInstalled` prevents duplicate hooks. Registers itself with `BridgeRegistry` at load time. |

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

### Addon-Level Constants

Declared on the addon object in `SocialQuest.lua` immediately after the addon is created (available to all sub-modules at file scope):

```lua
SocialQuest.DataProviders = { SocialQuest = "SocialQuest", Questie = "Questie" }

SocialQuest.EventTypes = {
    Accepted="accepted", Completed="completed", Abandoned="abandoned",
    Failed="failed", Finished="finished", Tracked="tracked", Untracked="untracked",
    ObjectiveComplete="objective_complete", ObjectiveProgress="objective_progress",
}
```

Each consumer module that dispatches or compares event types declares `local ET = SocialQuest.EventTypes` at file scope.

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
| `AQL_OBJECTIVE_PROGRESSED` | `OnObjectiveProgressed` | Broadcasts `SQ_OBJECTIVE` |
| `AQL_OBJECTIVE_REGRESSED` | `OnObjectiveRegressed` | Broadcasts objective update and announces regression |
| `AQL_OBJECTIVE_COMPLETED` | `OnObjectiveCompleted` | Broadcasts `SQ_OBJECTIVE` |
| `AQL_UNIT_QUEST_LOG_CHANGED` | `OnUnitQuestLogChanged` | Creates `hasSocialQuest=false` stub for non-SQ group members |

### Zone Transition Suppression

`PLAYER_ENTERING_WORLD` sets a 3-second suppression window (`zoneTransitionSuppressUntil`). All AQL quest and objective callbacks return early during this window to prevent re-announcing the entire quest log on hearth/zone-in.

---

## PlayerQuests Data Structure

```lua
-- Core/GroupData.lua
PlayerQuests["Name-Realm"] = {
    hasSocialQuest  = true,
    dataProvider    = "SocialQuest",   -- SocialQuest.DataProviders.* constant; nil for stubs
    lastSync        = GetTime(),
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
-- Players without SocialQuest (stub only):  { hasSocialQuest=false, completedQuests={} }
-- Players with Questie bridge data:         { hasSocialQuest=false, dataProvider="Questie", quests={...}, ... }
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

### Version 2.10.1 (March 2026 — ProgressBars branch)
- Progress Bar Polish: replaced flat colored-rectangle bars with WoW-native `StatusBar` widgets. Each bar now uses the standard `Interface\TargetingFrame\UI-StatusBar` fill texture (the same texture used by health and cast bars), colored at 85% opacity so the texture's built-in highlight stripe and bevel are visible. A `Interface\CastingBar\UI-CastingBar-Border` overlay provides the characteristic tapered border that suggests rounded ends. Objective text is forced white with a 1px drop shadow and has WoW color escape codes stripped, eliminating the yellow-on-yellow readability problem from the previous implementation. Colorblind mode uses sky-blue for completed objectives as before.

### Version 2.10.0 (March 2026 — ProgressBars branch)
- Progress Bars: objective rows in the Party and Shared tabs now render as inline progress bars. Each bar fills proportionally to `numFulfilled/numRequired`; objective text overlays the fill in white. Player names appear in a left-aligned column whose width matches the widest name in each quest, so all bars are column-aligned for at-a-glance comparison. Colorblind mode respected. Falls back to plain text for objectives without numeric data. New `GetDisplayName` helper in `RowFactory` centralizes nameTag resolution. New `GetUIColorRGB` helper in `Colors.lua` exposes numeric RGB tuples for texture coloring.

### Version 2.9.0 (March 2026 — ZoneFilter branch)
- Zone & Instance Auto-Filter: Party and Shared tabs now optionally filter to the current dungeon/raid instance or open-world zone. New `UI/WindowFilter.lua` module (`SocialQuestWindowFilter`) owns all filter state. Each tab shows a dismissible grey filter label at the top. Two new toggles in `/sq config` → Social Quest Window: "Auto-filter to current instance" (default ON) and "Auto-filter to current zone" (default OFF). Filter resets on zone change, window close, or settings toggle. MineTab signature updated for future compatibility. New `GetRealZoneText` and `IsInInstance` wrappers added to `SocialQuestWowAPI`.

### Version 2.8.2 (March 2026 — QuestieIntegration branch)
- Bug fix: eliminated false "objective completed again" and false regression announcements caused by bag operations (picking up or splitting item stacks for quest collectibles). Root fix in AQL (`CursorHasItem()` guard in `handleQuestLogUpdate()`) prevents the false events from ever firing. Removed the `pendingRegressions` AceTimer debounce from `SocialQuest.lua` (`OnEnable`, `OnObjectiveProgressed`, `OnObjectiveCompleted`, `OnObjectiveRegressed`) — it was a workaround for those now-suppressed events and is no longer needed.

### Version 2.8.1 (March 2026 — QuestieIntegration branch)
- Bug fix: clicking a quest title in the SQ window when the quest log was open, the quest selected, and its zone collapsed caused the log to close instead of expanding the zone. Fixed in `RowFactory.openQuestLogToQuest` by adding `AQL:GetQuestLogIndex(questID)` to the toggle condition — this method only searches visible entries, so it returns nil when the zone is collapsed, causing the close branch to be skipped and the expand+navigate path to run instead.
- Bug fix: regression followed by progression banner when splitting an item stack. The debounce window in `OnObjectiveRegressed` was increased from 0.5 s to 2 s to cover cases where the player takes a moment to reposition the cursor before placing the split stack.

### Version 2.8.0 (March 2026 — QuestieIntegration branch)
- **Questie Bridge**: hooks Questie's `QuestieComms` layer to populate `PlayerQuests` for party members who have Questie but not SocialQuest. Fires `Accepted`, `Finished`, and objective banners for their quest events.
- Added `SocialQuest.DataProviders` and `SocialQuest.EventTypes` constant tables on the addon object. All event-type string literals replaced with `ET.*` aliases across `SocialQuest.lua`, `GroupData.lua`, and `Announcements.lua`.
- Added `dataProvider` field to all `PlayerQuests` entries (SQ entries get `DataProviders.SocialQuest`; bridge entries get `DataProviders.Questie`; stubs remain `nil`).
- New modules: `Core/BridgeRegistry.lua` (`SocialQuestBridgeRegistry`) and `Core/QuestieBridge.lua` (`QuestieBridge`).
- `RowFactory` appends the bridge's `nameTag` icon after the player name for non-SQ data sources.
- `checkAllFinished` guard updated: suppresses only when a member has no data source at all (not merely `hasSocialQuest=false`).
- Defense-in-depth: `OnRemoteQuestEvent` suppresses Completed/Abandoned/Failed banners for non-SQ providers.
- Bug fix: `OnUnitQuestLogChanged` no longer clobbers bridge-populated `PlayerQuests` entries.

### Version 2.7.0 (March 2026 — Improvements branch)
- Added `Core/WowAPI.lua` (`SocialQuestWowAPI`) and `Core/WowUI.lua` (`SocialQuestWowUI`) abstraction modules. All direct WoW game-state/data API calls now route through `SQWowAPI`; volatile WoW UI primitives route through `SQWowUI`. Quest and quest-log API calls replaced with AQL public API calls. Prepares SocialQuest to support multiple WoW interface versions without scattered direct WoW API usage.

### Version 2.6.0 (March 2026 — Improvements branch)
- Bug fix: chain header label in the Mine tab showed the title of whichever quest step the player was currently on, rather than a consistent name for the chain. `MineTab:BuildTree` now resolves the chain label by calling `AQL:GetQuestInfo(chainID)` on the chain's root questID (step 1), giving a stable name regardless of which step is active. Falls back to the current quest's title when step-1 data is unavailable. The previous "prefer step 1" override block is removed.

### Version 2.5.1 (March 2026 — Improvements branch)
- Changed `all_complete` banner color from dark purple (`#9900E6`) to hot magenta (`#FF00CC`) for better contrast against WoW's outdoor and dungeon environments. Colorblind color (Okabe-Ito blue `#0072B2`) unchanged.
- Bug fix: `{rt1}` displayed as literal text in the "Test Chat Link" chat preview. `displayChatPreview` now converts `{rt1}`–`{rt8}` to WoW `|T...|t` texture escape sequences before calling `DEFAULT_CHAT_FRAME:AddMessage`. `SendChatMessage` handles `{rt1}` natively; `AddMessage` does not.
- Bug fix: Force Resync button did not automatically re-enable after its 30-second cooldown. The button's `func` now schedules an `AceConfigRegistry:NotifyChange("SocialQuest")` call 30 seconds after each press, causing AceConfig to re-evaluate the `disabled` callback and re-enable the button without requiring the user to reopen the config panel.

### Version 2.5.0 (March 2026 — Improvements branch)
- Quest language consistency: corrected player-facing text to match how WoW's UI and players refer to quest states. "Complete" now consistently means all objectives are filled (the yellow checkmark state in the quest log). "Turned in" means the quest was delivered to the NPC. The word "completed" had been used ambiguously for both states and has been reassigned to the objectives-done banner only, where players expect it. Changes affect banner text, outbound chat, options toggle labels, and debug test button names across all 12 locale files. Non-English translations use natural player vocabulary (e.g. German "abgegeben", French "rendu", Korean "반납", Chinese "交任务"). No internal event names or data structures changed.

### Version 2.4.0 (March 2026 — Improvements branch)
- Follow banner notifications: `OnFollowStart` and `OnFollowStop` now display a banner in addition to the existing chat message. Uses new `follow` color key (warm tan normal / Okabe-Ito yellow colorblind). Added `TestFollowNotification` debug function and corresponding debug panel button.

### Version 2.3.7 (March 2026 — Improvements branch)
- Bug fix: six unescaped ASCII double-quote characters inside Chinese string values in `Locales/zhCN.lua` caused Lua syntax errors at load time. Escaped with `\"` in the translation values for the master-switch description and all five test-button descriptions (lines 126, 173, 175, 177, 179, 181). zhTW was unaffected.

### Version 2.3.6 (March 2026 — Improvements branch)
- Bug fix: `checkAllFinished` forward declaration was shadowed by `local function checkAllFinished` on the definition line, causing a nil-call crash on every `AQL_QUEST_FINISHED` event. Changed definition to `checkAllFinished = function(...)` (no `local`) so it assigns to the existing upvalue.

### Version 2.3.5 (March 2026 — Improvements branch)
- Fixed chat announcements: WoW TBC does not render `|H...|h` hyperlinks in addon-sent party/raid/guild chat. Changed outbound quest and objective messages to use `[Quest Title]` bracket format instead of the full hyperlink string. Added `questInfo.title` to the title resolution chain in `OnQuestEvent` so completed/abandoned quests (already removed from cache) still resolve the correct name.

### Version 2.3.4 (March 2026 — Improvements branch)
- "Everyone has finished" feature: changed trigger from `eventType == "completed"` (turned in) to `eventType == "finished"` (objectives done). Updated internal completion check to use `isComplete` flag on quest data instead of `completedQuests`/`HasCompletedQuest`, with fallback to `completedQuests` for players who already turned in. Display gate now uses `display.finished` toggle; chat gate uses `announce.finished`. Renamed function from `checkAllCompleted` to `checkAllFinished`.
- Renamed locale key `"Everyone has completed: %s"` → `"Everyone has finished: %s"` and test button `"Test All Completed"` → `"Test All Finished"` across all 11 locale files.

### Version 2.3.3 (March 2026 — Improvements branch)
- Flight path debug logging: added `Debug("Quest", ...)` calls throughout `OnTaxiMapOpened` covering node counts, new discovery announcements, silent-absorb paths (starting city, mid-game install, unknown race), and saved-state update.
- Exposed `SocialQuest:GetStartingNode()` as a public wrapper around the file-scope `getStartingNode()` local, for use by `Announcements.lua` and other modules.
- Test Flight Discovery button: added to Debug options page alongside other test buttons; calls `SocialQuestAnnounce:TestFlightDiscovery()` which shows a flight path unlock banner using the player's starting city as the demo node.

### Version 2.3.2 (March 2026 — Improvements branch)
- Per-character frame state: moved `frameState` (active tab, collapsed zones) and scroll position tables from shared `profile` scope to per-character `char` scope in AceDB. Scroll positions now persist across reloads. Added `OnProfileReset` callback to reset `char.frameState` when the profile is reset.
- Bug fix: added `local checkAllCompleted` forward declaration in `Core/Announcements.lua` to fix "attempt to call global 'checkAllCompleted'" crash when completing a quest.
- Bug fix: removed `Bindings.xml` from `SocialQuest.toc`; WoW's bindings parser discovers it automatically. Eliminates all "Unrecognized XML: Binding" warnings.

### Version 2.3.1 (March 2026 — Improvements branch)
- Scroll position fix: added deferred `C_Timer.After(0)` scroll restoration with sequence guard, so the correct position survives `UIPanelScrollFrameTemplate` callbacks (`OnScrollRangeChanged`/scrollbar `OnValueChanged`) that override `SetVerticalScroll` when `SetScrollChild`/`SetHeight` are called on the new content frame.

### Version 2.3.0 (March 2026 — Improvements branch)
- Scroll position fix: tracks content height when saving scroll offset; when returning to a tab where the user was at the bottom, restores to the new bottom even if content grew (cross-chain peers from GroupData sync).

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
