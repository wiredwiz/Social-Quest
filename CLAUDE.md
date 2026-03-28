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

`SocialQuest.lua` — Creates the Ace3 addon object, handles `OnInitialize` and `OnEnable`, registers WoW events and AQL callbacks, and delegates everything else to sub-modules. Registers these WoW events: `GROUP_ROSTER_UPDATE`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_CONTROL_GAINED`, `AUTOFOLLOW_BEGIN`, `AUTOFOLLOW_END`.

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
| `Core\QuestieBridge.lua` | `QuestieBridge` | Questie bridge implementation. Hooks `QuestieComms.data:RegisterTooltip` (fires after all packet-insertion paths populate `remoteQuestLogs`) and `QuestieComms.data:RemoveQuestFromPlayer` via `hooksecurefunc`. `_active` flag gates processing; `_hookInstalled` prevents duplicate hooks. Registers itself with `BridgeRegistry` at load time. |

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

### Version 2.12.33 (March 2026 — Improvements branch)
- Removed flight path discovery feature entirely. The TBC Classic API (`NumTaxiNodes`, `TaxiNodeName`, `TaxiNodeGetType`) only returns data while the flight map UI is open — it returns nothing at gossip time when the path is actually discovered. Since detection requires the player to explicitly open the flight map, the feature cannot reliably detect discoveries. Removed: `OnTaxiMapOpened`, `GetStartingNode`, `RACE_STARTING_NODES`, `getStartingNode`, `TAXIMAP_OPENED` event registration, `flightPath` AceDB profile defaults, `knownFlightNodes` char defaults, `SQ_FLIGHT` comm prefix, `SendFlightDiscovery`, `OnFlightDiscovery`, `TestFlightDiscovery`, `NumTaxiNodes`/`TaxiNodeName`/`TaxiNodeGetType` WowAPI wrappers, Flight Path Discovery config group, Test Flight Discovery debug button, and all related locale keys across 12 locale files.

### Version 2.12.32 (March 2026 — Improvements branch)
- Bug fix: flight path discovery detection now uses the correct TBC Classic taxi APIs. `GetTaxiNodeInfo` does not exist in TBC (Interface 20505) — it is a retail-only API. `OnTaxiMapOpened()` now uses `NumTaxiNodes()` / `TaxiNodeName(i)` / `TaxiNodeGetType(i)`. Only `REACHABLE` and `CURRENT` nodes are collected; `DISTANT` nodes (not yet discovered) are skipped, preventing them from polluting `currentNodes`, inflating `diffCount`, and triggering the silent-absorb branch.

### Version 2.12.31 (March 2026 — Improvements branch)
- Bug fix: zone auto-filter now shows the correct zone name in starter areas (e.g. "Northshire Valley" instead of "Elwynn Forest"). `computeFilterState()` in `WindowFilter.lua` now prefers `GetSubZoneText()` when non-empty; falls back to `GetRealZoneText()` for normal open-world zones. Instance filter branch unchanged — `GetRealZoneText()` is correct inside dungeons/raids.
- Feature: Mine tab quest objectives now render as WoW-native `StatusBar` progress bars, matching the Party and Shared tabs. Uses `AddPlayerRow` with an empty name column (`nameColumnWidth = 0`) and a synthetic player entry, reusing the existing bar rendering code without duplication.

### Version 2.12.30 (March 2026 — AdvancedFilters branch)
- Feature: Full filter localization for 11 non-enUS locales (deDE, frFR, esES, esMX, zhCN, zhTW, ptBR, itIT, koKR, ruRU, jaJP). All `filter.*` keys previously falling back to enUS (`= true`) are now replaced with natural, game-appropriate translated strings — key names players type, enum values, key descriptions, error messages, and help window text. Single-letter aliases remain `= true` (English letters). WoW's own in-game terminology is used where applicable (e.g., German Verlies/Schlachtzug, French Donjon, Spanish Mazmorra/Banda, Korean 던전/공격대). esMX is identical to esES.

### Version 2.12.29 (March 2026 — AdvancedFilters branch)
- Feature: Extended `type` filter with 9 new predicates. AQL-based: `escort`, `dungeon`, `raid`, `elite`, `daily`, `pvp` (matched via `AQL:GetQuestInfo().type`). Objective-based: `kill` (any monster objective), `gather` (any item objective), `interact` (any object objective) — a quest with mixed objectives matches multiple types simultaneously. Replaced the priority-chain `mapType()` in all three tabs with `SocialQuestTabUtils.MatchesTypeFilter(entry, descriptor)` — each type value is now an independent boolean predicate, so `type=chain` and `type=dungeon` both match a chain dungeon quest. Extended to Party and Shared tabs. Requires Questie or Quest Weaver for AQL-based and objective predicates; filter help window updated with full 13-value list and Questie/QuestWeaver caveat note.

### Version 2.12.28 (March 2026 — AdvancedFilters branch)
- Bug fix: multi-value filter labels ("zone=storm|war") displayed garbled text ("stormar") because WoW treats `|` as an escape sequence prefix and swallows characters following it. The OR separator in the label is now `||`, which WoW renders as a literal `|`.

### Version 2.12.27 (March 2026 — AdvancedFilters branch)
- Bug fix: advanced filter label display text now uses title-cased key names ("Filter: Zone: storm" not "Filter: zone: storm"), matching the auto-zone label format ("Filter: Zone: Elwynn Forest"). Canonical key names (always lowercase internally) have their first letter uppercased when building the display string. Error labels continue to show the raw user-typed expression unchanged.

### Version 2.12.26 (March 2026 — AdvancedFilters branch)
- Bug fix: advanced filter label tooltips now use the display text ("Filter: key: value") instead of the raw expression ("key=value"), matching the auto-zone label tooltip format. Both label types now consistently show their display text as the tooltip.

### Version 2.12.25 (March 2026 — AdvancedFilters branch)
- Bug fix: filter label tooltips now appear when hovering anywhere over the label, not only the dismiss button. `HeaderLabel` frames now have `EnableMouse(true)` and wire `OnEnter`/`OnLeave` on both the container frame and the button so the tooltip fires across the full label area.

### Version 2.12.24 (March 2026 — AdvancedFilters branch)
- Bug fix: help window interleaving with SQ window. Changed help frame strata from `HIGH` to `DIALOG` so it always renders above the SQ window with no frame-level interleaving. Added `OnMouseDown → Raise()` to the help frame (mirrors the SQ window) so clicking it brings it fully to the front.
- Bug fix: help window positioning. Replaced all formula-based coordinate-space detection with a two-step approach: anchor TOPLEFT to the right of the SQ frame, then check `helpFrame:GetRight() > UIParent:GetRight()` and flip to TOPLEFT anchored to the left side if off-screen. `GetRight()` values are in WoW's absolute screen coordinate space and are directly comparable. Position is recalculated on every Show() call (not just at frame creation), so it correctly adapts to the SQ window's current position and any savedPos reset takes effect immediately.
- Bug fix: savedPos no longer uses scale-multiplied coordinates. `OnDragStop` now stores raw `GetCenter()` values (absolute screen coordinates); validation uses `UIParent:GetRight()` and `UIParent:GetTop()` in the same space.

### Version 2.12.23 (March 2026 — AdvancedFilters branch)
- Bug fix: help window first-press-after-reload/login. WoW creates frames shown by default (inheriting parent visibility); `createHelpFrame()` now calls `hf:Hide()` before returning so the `OnClick` `IsShown()` check works correctly and the first press opens instead of closes. AceLocale strict mode crash fixed with `rawget(L, exKey)` for optional locale keys in the examples loop.

### Version 2.12.18 (March 2026 — FilterTextbox branch)
- Feature: Advanced filter language (Feature #18). The SQ search bar now accepts structured filter expressions (e.g. `level>=60`, `zone=Elwynn|Deadmines`, `status=incomplete`) entered by pressing Enter. Valid expressions are stored persistently in AceDB `char.frameState.activeFilters` (one entry per canonical key) and displayed as dismissible filter labels in the fixed header. Multiple filters AND together with each other, the real-time search text, and the auto-zone filter. New modules: `UI/FilterParser.lua` (pure Lua parser, standalone test runner at `tests/FilterParser_test.lua`), `UI/FilterState.lua` (AceDB-backed compound state with Apply/Dismiss/GetAll/IsEmpty — no mass reset), `UI/HeaderLabel.lua` (dismissible label widget factory). The auto-zone label, error label, and all user-typed filter labels are `HeaderLabel` instances stacked via a `lastHeader` cursor in `Refresh()`. A `[?]` button opens a movable reference panel (`SocialQuestFilterHelpFrame`) registered in `UISpecialFrames`; its open state persists and it opens/closes with the main SQ window. `filterTable.zone` (WindowFilter exact-match key) renamed to `filterTable.autoZone` to avoid collision with the new structured `zone` descriptor; `autoZone` now applies to all three tabs including Mine. Three helpers added to `TabUtils`: `MatchesStringFilter`, `MatchesNumericFilter`, `MatchesEnumFilter`. All three tab `BuildTree` functions apply the new structured filters per the per-tab applicability table (status/tracked: Mine only; player: Party/Shared only).

### Version 2.12.17 (March 2026 — FilterTextbox branch)
- Bug fix: `OnInitReceived` stored quest entries directly from the wire payload without converting integer flags to booleans. `buildInitPayload()` sends `isComplete`/`isFailed` as `0` or `1` (integers), but in Lua `0` is truthy — so every unprogressed quest received via SQ_INIT had `isComplete = 0` which evaluated as `true` everywhere in the UI and announce logic. `OnUpdateReceived` already used `payload.isComplete == 1` to convert correctly; `OnInitReceived` now does the same for `isComplete`, `isFailed`, and each objective's `isFinished` before storing.

### Version 2.12.16 (March 2026 — FilterTextbox branch)
- Diagnostics + fix attempt: `_ScheduleQuestieRequest` now logs `UnitInParty("player")` and `UnitInRaid("player")` at t+1s and t+5s sends to determine whether `QuestiePlayer:GetGroupType()` returns nil (which silently aborts `RequestQuestLog`). Added a third send at t+10s — by t+10s the party API is always stable on reload so `GetGroupType()` will return non-nil and the request will succeed. Hydration polls at t+14s and t+20s follow the t+10s send. The t+15s hydration-only poll (previously after the t+5s send) is replaced by the t+10s send + its polls.

### Version 2.12.15 (March 2026 — FilterTextbox branch)
- Diagnostics: added debug logging to `QuestieBridge:Enable`, `_ScheduleQuestieRequest` (t+1s and t+5s sends), `_EnsurePartyStubs` (group member count, stub creation, nil UnitName), and `_ScheduleHydration` callback (`remoteQuestLogs` quest count, snapshot player count). Enabled via `/sq config` → Debug tab.

### Version 2.12.14 (March 2026 — FilterTextbox branch)
- Bug fix: Questie player's quests never appeared after `/reload` even after 30+ seconds. Root cause: on reload, `UnitName("party1")` returns nil during `PLAYER_LOGIN`, so `GroupComposition:OnGroupRosterUpdate()` misses the party member and never calls `OnMemberJoined` — leaving no `PlayerQuests` stub for them. `GROUP_ROSTER_UPDATE` may not re-fire after the party API is ready (or fires before SocialQuest is even registered for it), leaving no other path to create the stub. Every `_ScheduleHydration()` poll called `OnBridgeHydrate()`, which silently skips any player not already in `PlayerQuests`, so all Questie data was dropped. Fix: new `_EnsurePartyStubs()` method called before `GetSnapshot()` in `_ScheduleHydration()`. At poll-time (t+5s, t+9s, etc.) `UnitName("party1")` is reliably available, so the method creates any missing stubs and `OnBridgeHydrate()` can then hydrate them. Also added a t+20s safety-net hydration poll to `_ScheduleQuestieRequest()`.

### Version 2.12.13 (March 2026 — FilterTextbox branch)
- Bug fix: Questie player's quests never appeared after `/reload` even after 30+ seconds. Root cause: `QuestieComms:Initialize()` — which calls `Questie:RegisterMessage("QC_ID_REQUEST_FULL_QUESTLIST", ...)` to register the AceEvent listener — runs in QuestieInit Stage 3, which only starts after Stage 2 finishes (up to 3s waiting for game cache validation). Our t+1s request fired before the listener existed, so `Questie:SendMessage(...)` went unhandled. Fix: fire the request at both t+1s (initial group join, Questie already initialized) and t+5s (reload, after QuestieComms:Initialize() has had time to run). Hydration polls follow each send. `_pendingRequest` is reset at t+5s so subsequent member joins can schedule new requests.

### Version 2.12.12 (March 2026 — FilterTextbox branch)
- Bug fix: Questie player's quests never appeared after `/reload`. Root cause: on `PLAYER_LOGIN`, group API data (`UnitName("party1")` etc.) may not be populated yet, so `newMembers` contained only self and `OnMemberJoined` was never called for existing party members — leaving no code path to call `_ScheduleQuestieRequest()`. Fix: call `_ScheduleQuestieRequest()` from `QuestieBridge:Enable()` directly. `Enable()` is called by `BridgeRegistry:EnableAll()` which is triggered reliably by the first `GROUP_ROSTER_UPDATE` or `PLAYER_LOGIN` event. `_pendingRequest` guards against duplicate requests if `OnMemberJoined` also fires.

### Version 2.12.11 (March 2026 — FilterTextbox branch)
- Bug fix: SQ window restored to screen center after reload instead of its last position. Added `frameX`, `frameY`, `frameWidth`, `frameHeight` to `char.frameState` AceDB defaults. Position saved on `OnDragStop`; size saved on resize handle `OnMouseUp`. `applyFrameState()` helper restores both using `TOPLEFT` anchor against `UIParent` after `createFrame()` is called — both in `Toggle()` and `RestoreAfterTransition()`.

### Version 2.12.10 (March 2026 — FilterTextbox branch)
- Bug fix: progress bar text overlay for remote players (Questie bridge) showed the local player's progress count instead of the remote player's. E.g. "Tough Wolf Meat: 0/8" when local player had 0 but remote player had 6. Root cause: `BuildRemoteObjectives` used `localObj.text` verbatim, which embeds the local player's count. Fix: strip the trailing `: X/Y` from `localObj.text` via pattern match and re-append with the remote player's `numFulfilled`/`numRequired`. Event/NPC objectives with no embedded count are passed through unchanged.

### Version 2.12.9 (March 2026 — FilterTextbox branch)
- Bug fix: Questie bridge quests never appeared on member join. Root cause confirmed: `hooksecurefunc(qc.data, "RegisterTooltip", ...)` never fires for V2 full-log packets despite `remoteQuestLogs` being populated within 10 seconds. Diagnostic: trace hook installed in WoWLua also never fired, ruling out SQ-specific logic as the cause. Fix: after sending `QC_ID_REQUEST_FULL_QUESTLIST` in `_ScheduleQuestieRequest()`, schedule `_ScheduleHydration()` at t+4s and t+8s (relative to request send) to poll `remoteQuestLogs` directly. Covers the 3–6 second V2 response window (`BroadcastQuestLogV2` uses `C_Timer.After(random() * 3)` + `C_Timer.NewTicker(3)`). `_ScheduleHydration()` is idempotent so double-firing is safe.

### Version 2.12.8 (March 2026 — FilterTextbox branch)
- Refactor: replaced two separate packet hooks (`InsertQuestDataPacket` V1 and `InsertQuestDataPacketV2_noclass_RenameMe` V2) with a single stable hook on `QuestieComms.data:RegisterTooltip(questId, playerName, objectives)`. `RegisterTooltip` is called by all Questie packet-insertion paths (V1, V2-noclass, V2-with-class) after `remoteQuestLogs` is populated, has a semantic name, and passes `questId` directly — eliminating the need for separate handlers and correctly handling multi-block V2 full-log responses. `_OnQuestUpdated` and `_OnQuestUpdatedV2` replaced by single `_OnQuestDataArrived(questId, playerName)`.

### Version 2.12.7 (March 2026 — FilterTextbox branch)
- Bug fix: (superseded by 2.12.8) Hooked `InsertQuestDataPacketV2_noclass_RenameMe` — unstable name (developer TODO), and `_OnQuestUpdatedV2` could not handle multi-block logs for existing players.

### Version 2.12.6 (March 2026 — FilterTextbox branch)
- Bug fix: (superseded by 2.12.8) Attempted to hook `InsertQuestDataPacketV2` for full quest log responses — was the wrong function.

### Version 2.12.5 (March 2026 — FilterTextbox branch)
- Bug fix: Questie bridge name mismatch. `CHAT_MSG_ADDON` whisper senders include `-RealmName` even for same-realm players, but `UnitName("partyN")` returns a nil realm for same-realm players so `PlayerQuests` stores short names. Added `_NormalizeName()` helper that tries the full name first (correct for cross-realm) then falls back to the short name (correct for same-realm Questie whispers). Applied in `_OnQuestUpdated`, `_OnQuestRemoved`, and `GetSnapshot`.

### Version 2.12.4 (March 2026 — FilterTextbox branch)
- Bug fix: `SocialQuestBridgeRegistry:OnMemberJoined` was called after `SocialQuestComm:OnMemberJoined` in the member-join loop. An error in `SocialQuestComm:OnMemberJoined` was stopping execution before the bridge call was reached. Moved `BridgeRegistry:OnMemberJoined` before `SocialQuestComm:OnMemberJoined` so comm errors cannot block bridge initialization.

### Version 2.12.3 (March 2026 — FilterTextbox branch)
- Bug fix: Questie player joining an existing group never had their quests appear. Root cause: Questie's `GroupRosterUpdate` handler has its broadcast commented out, so Questie never requests quest logs when a new member joins. Fix: `QuestieBridge:OnMemberJoined()` sends `Questie:SendMessage("QC_ID_REQUEST_FULL_QUESTLIST")` via a 1-second debounced timer (`_pendingRequest` guard) so rapid joins produce one request. Wired through new `BridgeRegistry:OnMemberJoined()` called from `GroupComposition` in the member-join loop.

### Version 2.12.2 (March 2026 — FilterTextbox branch)
- `GroupData:OnMemberJoined`, `PurgePlayer`, and `OnSelfLeftGroup` now call `SocialQuestGroupFrame:RequestRefresh()` so the Party and Shared tabs update immediately when the group roster changes. `RequestRefresh` is already a no-op when the frame is hidden, so there is no cost when the window is closed.

### Version 2.12.1 (March 2026 — FilterTextbox branch)
- Bug fix: Questie bridge live updates used abbreviated objective field names (`fin`/`ful`/`req`) from the raw packet, but `_BuildQuestEntry` expected full names (`finished`/`fulfilled`/`required`). Live updates now read from `remoteQuestLogs` (post-transform, full names) instead of the raw packet. Added `_ScheduleHydration()`: on first contact for a player (stub, no quests yet), defers a full re-hydration via `C_Timer.After(0)` so all packets in the comm batch land in `remoteQuestLogs` before the snapshot is taken — prevents missing quests and spurious `ET.Accepted` banners caused by the group-join hydration firing before Questie's comm exchange completes.

### Version 2.12.0 (March 2026 — FilterTextbox branch)
- Bug fix: `QuestieBridge` was referencing the global `QuestieComms` which does not exist. Questie registers all modules via `QuestieLoader:CreateModule()` into a private table, not as globals (`_G.QuestieComms` is only set when Questie debug mode calls `PopulateGlobals()`). `IsAvailable()`, `Enable()`, and `GetSnapshot()` now resolve the reference via `QuestieLoader:ImportModule("QuestieComms")` through a new `_GetQuestieComms()` helper. `IsAvailable()` also now checks `remoteQuestLogs ~= nil` as an additional readiness guard.

### Version 2.11.1 (March 2026 — FilterTextbox branch)
- Expand/collapse all buttons moved from scrollable content to fixed header. The `[+]` and `[-]` buttons are now permanently visible in the search bar row (right side, left of the `[x]` clear button) regardless of scroll position. Handlers are re-wired on every `Refresh()` to target the current active tab. `RowFactory.AddExpandCollapseHeader` removed; the per-tab calls in `MineTab`, `PartyTab`, and `SharedTab` `Render()` methods removed. Hovering shows "expand all" / "collapse all" tooltips.

### Version 2.11.0 (March 2026 — FilterTextbox branch)
- Search bar: a persistent search box appears in a fixed header strip below the tab
  separator, above the scrollable quest list. Typing filters all three tabs by quest
  title or chain title (case-insensitive substring match). The search text is shared
  across tabs; switching tabs re-filters against the same text. Cleared on user-initiated
  window close; preserved across loading screen transitions (`leavingWorld` guard).
- Filter label migration: the zone/instance filter label is moved from the scrollable
  content area (RowFactory.AddFilterHeader) into the same fixed header strip below the
  search bar. GroupFrame:Refresh() now manages the label visibility and the dismiss
  button directly. RowFactory.AddFilterHeader removed.

### Version 2.10.4 (March 2026 — ProgressBars branch)
- Bug fix: zone/instance filter did not update when a flight path (gryphon/wyvern) ended in a different zone. `ZONE_CHANGED_NEW_AREA` fires for seamless overland crossings (walking/riding) but does not fire during taxi flights — the taxi system handles zone transitions internally without raising that event. Added `PLAYER_CONTROL_GAINED` handler which fires when the taxi system releases the player at the destination; resets the window filter and refreshes the window.

### Version 2.10.3 (March 2026 — ProgressBars branch)
- Feature: the SQ window now reopens automatically after loading screens (hearthstone, portals, instance entry/exit, `/reload`) if it was open before the transition. `PLAYER_LEAVING_WORLD` snapshots the open state before WoW's `CloseAllWindows()` hides the frame; `PLAYER_ENTERING_WORLD` restores it. `OnHide` saves closed state only for user-initiated closes (X button, Escape), guarded by a `leavingWorld` flag so zone-transition hides do not overwrite the snapshot. `windowOpen` added to `char.frameState` AceDB defaults.

### Version 2.10.2 (March 2026 — ProgressBars branch)
- Filter label now prefixed with "Filter: " across all 12 locales (e.g. "Filter: Zone: Elwynn Forest"). Updated locale values for `L["Zone: %s"]` and `L["Instance: %s"]` in all locale files; enUS changed from `= true` to explicit strings.
- Bug fix: zone filter was not updating when the player crossed an overland zone border (e.g. Elwynn Forest → Westfall). `ZONE_CHANGED_NEW_AREA` is now registered and calls `SocialQuestWindowFilter:Reset()` + `SocialQuestGroupFrame:RequestRefresh()`. `PLAYER_ENTERING_WORLD` only fires on full loading screens (portals, instances, `/reload`) — seamless zone transitions require this separate event.

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
