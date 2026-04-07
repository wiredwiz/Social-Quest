# SocialQuest - WoW TBC Addon

## Project Overview

**SocialQuest** is a World of Warcraft addon for The Burning Crusade Anniversary edition. It enables players in parties, raids, and guilds to coordinate quest progress by sharing quest events and displaying group member progress in real time.

**Interface**: 20505 (TBC Anniversary)
**Author**: Thad Ryker
**Status**: Active development (Improvements branch)

> **IMPORTANT FOR CLAUDE:** This file must be updated whenever significant changes are made to the project — architecture changes, new modules, protocol changes, dependency changes, or notable bug fixes. Update the version number in `SocialQuest.toc` after every set of meaningful changes using the versioning rule below. Do not leave this file stale.

>**Versioning Rule:** The major version number should never be changed by claude unless explicitly instructed to do so.  The first time add-on functionality is modified on any given day, the minor version number should be incremented and the revision number should be reset to 0. Any extra changes ocurring within the same days should increment the revision number only, unless explicitly instructed otherwise.

>**Localization Standard:** All locale strings added to this addon must use natural, game-appropriate phrasing that matches how players actually speak in that language — never literal word-for-word translations of the English. Use the same in-game terminology WoW itself uses in each locale (e.g., the word for "quest log", class names, dungeon/raid terms). A native-language player reading the string should find it immediately recognizable. English (enUS) strings are always `= true`. When writing non-English translations, confirm the phrasing uses natural WoW vocabulary for that language, not dictionary translations. This is the same standard applied to all SocialQuest locale strings since v2.12.30.

>**Unit Tests:** Before committing any code change and before bumping the version number, always run the full Lua unit test suite and confirm all tests pass. Run from the repo root: `lua tests/FilterParser_test.lua` and `lua tests/TabUtils_test.lua`. Both must pass (0 failures) before the change is considered done. If a Lua runtime is not available in the environment, note this explicitly and flag to the user that tests could not be verified.

>**AQL is the sole source of truth for all quest data. NEVER bypass AQL to fix quest API issues.** SocialQuest must never call WoW quest APIs directly to work around AQL failures — always fix the root cause in AQL (`AbsoluteQuestLog`). Any quest title, info, objectives, chain, or history lookup must go through AQL's public API. Adding `SQWowAPI` wrappers that duplicate AQL's quest resolution is forbidden.

>**Multi-Version Design:** All new development must be designed with future support for Retail WoW and all other currently active WoW versions in mind — not only TBC. This does not mean implementing Retail support today; TBC is the only actively supported version. It means: (1) all WoW API calls route through `SQWowAPI` / `SQWowUI` wrappers so version-specific branching stays in one place; (2) new data structures, bitmask tables, and lookup tables include stubs for races/classes/features that don't exist in TBC but do in Retail (clearly commented as stubs); (3) avoid hardcoding assumptions that are TBC-specific (e.g., "only 10 races", "only 9 classes") when the pattern can accommodate future values at zero cost; (4) when a Retail API equivalent is unknown, add a comment `-- TODO: verify Retail API` rather than silently omitting the case.

---

## Known Performance Issues (Deferred — Do Not Fix Without Instruction)

Observed in April 2026: clients freeze for ~10 seconds on group join and again on group
leave when a Questie-only player groups with a SQ player. Two root causes identified
spanning AQL and SQ:

### AQL-side (see AQL CLAUDE.md for full details)
- **`GrailProvider.buildReverseMap()`** — iterates 10,000+ Grail quests synchronously on
  first `GetChainInfo()` call, triggered by `QuestCache:Rebuild()` on `GROUP_ROSTER_UPDATE`.
  Primary cause of the join freeze.
- **`QuestCache:_buildEntry()`** — calls chain provider per quest with no caching or
  batching, compounding the GrailProvider cost across every quest in the active log.

### SQ-side
- **`QuestieBridge.GetSnapshot()` in `Core/QuestieBridge.lua`** — pivots Questie's
  `remoteQuestLogs` (quest×player) into player×quest format by iterating every quest for
  every player with no filtering. O(quests × players). Runs at t+4s/t+8s after Questie
  request, causing the delayed secondary freeze after group join.
- **Fix direction:** Build snapshot incrementally or filter to active-log quests only
  before pivoting the full table.

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

### Version 2.22.1 (April 2026)
- Feature: chain line added to `BuildTooltip` between the title line and the status line.
  When `AQL:GetChainInfo` returns `knownStatus = Known` and the chain has more than one
  step, displays `<Chain Root Title> (Step X of Y)` in light periwinkle (`0.8, 0.8, 1.0`).
  Chain name resolved from `chain.steps[1].title`, falling back to multi-quest step format
  and then `AQL:GetQuestTitle(chain.chainID)`. Reuses existing locale key
  `L[" (Step %s of %s)"]`. No new locale strings required.

### Version 2.22.0 (April 2026)
- Feature: tooltip title line redesigned. Level is now shown as `[N]` between the title
  and the SQ badge on the title line itself. Quest type badge (`(Dungeon)`, `(Raid)`,
  `(Group N+)`, or `(Group)`) is right-aligned in light blue via `AddDoubleLine`. Group
  size comes from `questInfo.suggestedGroup` when > 0. The old combined level/zone/badge
  line is replaced by a plain `Location: <Zone>` line (line 3). `buildLevelLine` helper
  removed. All 12 locale files updated with new keys (`Location:`, `(Dungeon)`, `(Raid)`,
  `(Group %d+)`) replacing the old `Level %d`, `[Dungeon]`, `[Raid]`, `[Group]` keys.
  Note: main TBC `SocialQuest.toc` was found at 2.19.2 (missed in prior bumps); brought
  forward to 2.22.0 alongside the other three TOC files.

### Version 2.21.0 (April 2026)
- Bug fix: local player now included in the "Party progress:" section of SQ tooltips.
  Previously `renderPartyProgress` in `UI/Tooltips.lua` skipped the local player with
  a comment that Questie/WoW already showed their progress. This was incorrect for the
  Replace tooltip mode where SQ renders its own full tooltip. The local player is now
  added first using live `AQL:GetQuest` data (authoritative for self) before iterating
  remote party members from `PlayerQuests`.
- Bug fix: description (and NPC/type-badge fields) no longer missing from `BuildTooltip`
  when the quest is in the player's active log. `AQL:GetQuestInfo` Tier 1 (cache path)
  returns the raw `QuestCache` entry, which does not include Details-capability fields
  (`description`, `starterNPC`, `starterZone`, `finisherNPC`, `finisherZone`, `isDungeon`,
  `isRaid`). `BuildTooltip` now calls the new `AQL:GetQuestDetails(questID)` when
  `questInfo.description` is nil, shallow-copies the cache result, and merges the detail
  fields so all sections of the tooltip render correctly regardless of whether the quest
  is in the player's log. Requires AQL 3.7.0.

### Version 2.19.2 (April 2026)
- Bug fix: quest links in chat now show Questie's custom tooltip when clicked.
  Reverted 2.19.1's chat filter change — links are again `|Hsocialquest:|` (not `|Hquest:|`).
  Restored the `SetItemRef` hook for `socialquest:` links with the correct fix: Questie's
  `SetHyperlink` override only renders its enhanced tooltip for `questie:` link format; for
  `quest:` format it falls through to the basic WoW handler. The hook now calls
  `ItemRefTooltip:SetHyperlink("questie:questID:level")` when `QuestieLoader` is present
  (triggering Questie's enhanced tooltip), and falls back to `quest:` format otherwise.
  SQ's `SetHyperlink` hook already matched `questie:` links (unchanged) so party progress
  is appended after Questie's tooltip in both cases.

### Version 2.19.1 (April 2026)
- Bug fix: clicking a quest link in chat now shows Questie's custom tooltip correctly and
  the link itself is clickable. Two fixes in `UI/Tooltips.lua`: (1) Chat filter now
  produces native `|Hquest:questID:level|h` links instead of `|Hsocialquest:|` links.
  Using `quest:` lets WoW's native SetItemRef pipeline handle clicks, so Questie's own
  SetItemRef hook fires and renders its enhanced tooltip; SQ's SetHyperlink hook on
  ItemRefTooltip still fires afterwards to append party progress. (2) Removed the
  `SetItemRef` hook for `socialquest:` links entirely — it is no longer needed since the
  chat filter produces native `quest:` links. Note: calling `SetItemRef` from inside a
  `hooksecurefunc("SetItemRef")` callback (2.19.0) is illegal — SetItemRef is a protected
  function and the call caused a silent taint error, leaving the link non-functional.

### Version 2.19.0 (April 2026)
- Bug fix: clicking a `socialquest:` quest link in chat now shows Questie's custom tooltip
  instead of the basic WoW tooltip. Root cause: the `SetItemRef` hook was calling
  `ItemRefTooltip:SetHyperlink("quest:...")` directly, bypassing Questie's own `SetItemRef`
  hook which intercepts `quest:` links to render its enhanced tooltip. Fix: replaced the
  three-line direct manipulation with a single `SetItemRef("quest:questID:level", text, button)`
  call, routing through WoW's full link-handling pipeline so Questie's hook fires first and
  SQ's existing `SetHyperlink` hook on `ItemRefTooltip` appends party progress afterwards.

### Version 2.18.28 (April 2026)
- Bug fix: `SQWowAPI` was never declared in `UI/Tabs/SharedTab.lua`. Every alias-handling
  code path added in 2.18.26 (chainTitleToID normalization, title fallback, objectives
  fingerprint, two-phase questEngaged merge) referenced `SQWowAPI.IS_RETAIL` and
  `SQWowAPI.IS_MOP`, which crashed at runtime because the local was absent. WoW's error
  handler swallowed the crash and rendered an empty Shared tab. Fix: added
  `local SQWowAPI = SocialQuestWowAPI` at the top of the file, matching the existing
  declaration in `PartyTab.lua`.

### Version 2.18.27 (April 2026)
- Bug fix: Shared tab now correctly shows quests shared by two players with alias questIDs
  on MoP Classic even when the remote alias questID's title cannot be resolved (not in the
  local log and no provider coverage). Added objectives fingerprint (`numRequired` count
  and per-objective values) as a secondary matching key. Two new fallback paths in
  `UI/Tabs/SharedTab.lua`: (1) `addEngagement` else-branch now tries objectives fingerprint
  against existing `chainEngaged` entries when both title-based matching and chain
  resolution fail — covers the common MoP case where one alias resolves a chain and the
  other does not. (2) The `questEngaged` merge pass is now two-phase: Phase 1 builds
  canonical entries from questIDs with resolvable titles (indexing their objectives sig);
  Phase 2 merges questIDs with unresolvable titles into the canonical entry by objectives
  fingerprint match — covers non-chain quests where neither player has provider coverage.
  Both paths are gated on `IS_RETAIL or IS_MOP` and only activate when
  `#objectives > 0` (no-op for talk/travel quests that have no numeric objectives).

### Version 2.18.26 (April 2026)
- Bug fix: MoP Classic alias quest IDs now handled the same as Retail. On MoP Classic,
  Blizzard assigns different questIDs for the same logical quest per race/class character
  type (same as Retail). Five fixes: (1) `UI/Tooltips.lua` `resolveQuestData` title-based
  alias fallback extended to `IS_MOP`, so clicking a quest link shows party progress for
  players whose alias questID differs from the link's ID. (2) `UI/Tabs/PartyTab.lua`
  chain insertion adds title-based chainID normalization (`chainTitleToIDByZone`): when a
  new chain would be created with a step-1 title matching an existing chain, the incoming
  chainID is redirected to the canonical one so both alias questIDs merge into one block
  instead of two. (3) `UI/Tabs/PartyTab.lua` post-processing pass after the main loop
  moves any ungrouped `zone.quests` entry whose title matches a chain step into that step,
  covering the case where one alias resolves chain info and the other does not. (4)
  `UI/Tabs/SharedTab.lua` `addEngagement` adds the same title-based chain normalization
  (`chainTitleToID`) before inserting into `chainEngaged`. (5) `UI/Tabs/SharedTab.lua`
  `addEngagement` `else` branch gains a title-based fallback to route a failed-chain-
  resolution questID into an existing `chainEngaged` entry with the same title. All alias
  logic gated on `IS_RETAIL or IS_MOP`.

### Version 2.18.25 (April 2026)
- Fix: quest link chat announcements no longer taint or lock up the Retail client.
  Root cause (2.18.24): `BuildQuestLink` sent `|Hsocialquest:...|h` directly through
  `SendChatMessage`, which Retail rejects at the client level causing taint/lockup.
  `BuildQuestLink` now sends plain text `[[level] Quest Name (questID)]` on all
  versions — no `|H` codes ever go through `SendChatMessage`. A new
  `ChatFrame_AddMessageEventFilter` registered in `Tooltips.lua:Initialize()` intercepts
  incoming messages on each client and replaces the marker with
  `|cffffff00|Hsocialquest:questID:level|h...|h|r` before display, making it clickable
  locally. The `SetItemRef` hook for `socialquest:` links is moved outside the
  IS_RETAIL guard so it handles clicks on both Retail and TBC. Architecture matches
  Questie's `ChatFilter.lua` pattern exactly.

### Version 2.18.24 (April 2026)
- Feature: clickable quest links in SQ outbound chat announcements. On non-Retail,
  SQ now sends `|Hquestie:questID:senderGUID|h[level] Quest Name|h|r` format —
  Questie users get a clickable tooltip; others see `[level] Quest Name` as readable
  plain text. On Retail, SQ sends `|Hsocialquest:questID:level|h` with a `SetItemRef`
  hook in `Tooltips.lua` that forwards clicks to the native quest tooltip.
- Feature: quest link tooltip augmentation now works for all quest link types (native
  `|Hquest:|`, Questie `|Hquestie:|`, and SQ's `|Hsocialquest:|`). Party member
  progress is appended below Questie's "Your progress:" section in matching visual
  style — plain "Party progress:" header, `" - Name: desc: X/Y"` objective lines.
  Only fires in a party group (never in raid or BG). Local player is skipped (already
  shown by Questie/WoW). On Retail, alias resolution via title-based scan handles
  variant quest IDs. All tooltip augmentation wrapped in `pcall` to prevent SQ errors
  from corrupting the base WoW or Questie tooltip.

### Version 2.18.23 (April 2026)
- Feature: group window and `/sq diagnose` console no longer open off-screen.
  Added `SQWowUI.ClampFrameToScreen(frame)` to `Core/WowUI.lua`. Reads the
  frame's actual rendered edges after positioning and applies the minimum X/Y
  shift to bring all four edges within `UIParent` bounds. Called at the end of
  `applyFrameState()` in `UI/GroupFrame.lua` (covers both `Toggle()` and
  `RestoreAfterTransition()`) and at the end of the console restore block in
  `SocialQuest.lua`. No persistent `SetClampedToScreen` is used — correction
  fires once at open time only. Dragging partially off-screen during a session
  is still allowed; the window is nudged back on-screen at the next open.

### Version 2.18.22 (April 2026)
- Bug fix: Wowhead quest URL is now version-aware. `SocialQuestTabUtils.WowheadUrl`
  in `UI/TabUtils.lua` previously hardcoded the TBC path (`/tbc/quest=`) for all WoW
  versions. The base URL is now selected at load time from `SQWowAPI` version flags:
  Retail → `wowhead.com/quest=`, MoP Classic → `wowhead.com/mop-classic/quest=`,
  TBC → `wowhead.com/tbc/quest=`, Classic Era → `wowhead.com/classic/quest=`.

### Version 2.18.21 (April 2026)
- Cleanup: removed diagnostic debug messages from `checkAllCompleted` and `OnQuestEvent`
  added during the "Everyone has completed" investigation. Retained suppression-reason
  messages ("not in group", "member without data source", "local player not done",
  "remote player not done", "no remote players engaged", "display.finished off") and
  the success banner log. Removed entry log, local state dump, per-player loop log,
  post-loop state dump, display gate log, and the `OnQuestEvent` event-type diagnostic.

### Version 2.18.20 (April 2026)
- Cleanup: removed diagnostic debug logging from `UIErrorsFrame.AddMessage` hook
  (`InitEventHooks`) added during 2.18.17–2.18.19 investigation.

### Version 2.18.19 (April 2026)
- Bug fix: "Objective Complete" suppression still failed after 2.18.18. Root cause:
  Retail sends the message as `"Objective Complete."` (with a trailing period). The
  comparison target `"objective complete"` (no period) never matched. Fix: strip a
  trailing period from the message before the case-insensitive comparison using
  `msg:match("^(.-)%.?$")`.

### Version 2.18.18 (April 2026)
- Bug fix: "Objective Complete" suppression did not work on Retail. Root cause:
  `UIErrorsFrame:GetScript("OnEvent")` returns nil on Retail (the handler is defined in
  XML, not Lua), so `InitEventHooks` exited immediately without installing any hook.
  Fix: replaced the `GetScript("OnEvent")` / `SetScript` pattern with a direct
  `UIErrorsFrame.AddMessage` replacement hook. `AddMessage` is the common display path
  on all WoW version families regardless of how the event reached the frame (event
  handler, direct call, XML, etc.). The suppression logic is unchanged: count-based
  objective text is suppressed via `AQL:IsQuestObjectiveText`, and the standalone
  "Objective Complete" string is matched case-insensitively against
  `QUEST_WATCH_OBJECTIVE_COMPLETE` (nil on Retail) with fallback `"objective complete"`.

### Version 2.18.17 (April 2026)
- Bug fix: "Objective Complete" WoW notification still appeared when SQ's own
  objective-complete banner was enabled. Root cause: `QUEST_WATCH_OBJECTIVE_COMPLETE`
  is nil in TBC Classic, and the fallback `"Objective Complete"` used an exact
  case-sensitive match. TBC sends `"Objective complete"` (lowercase c). Fix: replaced
  the exact-match check with a case-insensitive comparison against the WoW global when
  present, falling back to `"objective complete"`. Also checks `messageType` (arg1) in
  addition to `msg` (arg2) since the text arg position varies by WoW build. Added
  debug-mode logging of all `UI_INFO_MESSAGE` events through `UIErrorsFrame` (visible
  when SQ debug is enabled) to aid future diagnosis.

### Version 2.18.16 (April 2026)
- Bug fix: WoW's "Objective Complete" notification was not suppressed when SQ's own
  objective-complete banner was enabled. The existing `UI_INFO_MESSAGE` hook only
  suppressed count-based objective text (e.g. "Tainted Ooze killed: 10/10") and only
  when `objective_progress` was on. Two fixes in `InitEventHooks`: (1) count-based
  objective text suppression now also fires when `objective_complete` is enabled (not
  only `objective_progress`); (2) added a second check that suppresses the standalone
  "Objective Complete" string (WoW global `QUEST_WATCH_OBJECTIVE_COMPLETE`) when
  `objective_complete` is enabled. Both checks are gated on `displayOwn` being true.

### Version 2.18.15 (April 2026)
- Bug fix: "Everyone has completed" banner fired immediately when the first player
  completed a quest on the second (or later) run, even though other party members had
  not finished yet. Root cause: `selfFinishedQuests[questID]` was set to `true` when the
  local player completed a quest but was never cleared when the quest was abandoned and
  re-accepted. On a subsequent run, when a remote player finished first and triggered
  `checkAllCompleted(questID, false)`, `localDone` evaluated to `true` via the stale
  `selfFinishedQuests` entry even though `localHasCompleted` was `false`. Fix: added
  `selfFinishedQuests[questID] = nil` inside `OnQuestEvent` when `eventType == ET.Abandoned`,
  clearing the record so `localDone` correctly evaluates to `false` until the local player
  completes the quest again in the new run.

### Version 2.18.14 (April 2026)
- Bug fix: "Everyone has completed" banner fired immediately when the first player
  completed a quest, even though other party members had not finished yet. Root cause:
  `checkAllCompleted` checked `entry.completedQuests` when determining remote player
  engagement. That table is populated by `SQ_RESP_COMPLETE` which sends
  `AQL:GetCompletedQuests()` — the player's entire quest completion history. If a party
  member had previously completed the quest (any prior session, daily reset, etc.), they
  were counted as "engaged and done" for the current session, causing the banner to fire
  as soon as the first player finished. Fix: removed the `completedQuests` lookup from
  the remote-engagement check entirely. Only `entry.quests` (active quests this session)
  is used to determine whether a player is engaged with the quest.

### Version 2.18.13 (April 2026)
- Bug fix: "Everyone has completed" banner was not visible for the last player to finish
  a quest. Root cause: `RaidWarningFrame` holds at most ~2 messages; when three banners
  fire in the same Lua frame (objective "4/4", "You have completed", "Everyone has
  completed"), the third message is dropped. Fix: `displayBanner` for "Everyone has
  completed" is now deferred by 2 seconds via `SQWowAPI.TimerAfter`. The banner fires
  after the quest-finished and objective-complete banners have cleared the queue, making
  it the prominent final notification. The chat message (when applicable) is still sent
  immediately since the chat system does not share the RaidWarningFrame queue.

### Version 2.18.12 (April 2026)
- Bug fix: "Everyone has completed" banner fired prematurely as soon as the first player
  completed a quest, even when no other party member had finished yet. Root cause: in
  `checkAllCompleted`, `anyEngaged` was initialized to `localEngaged` (true when the
  local player just completed). If no remote player's quest data was found in
  `PlayerQuests`, the remote loop left `anyEngaged = true` (from the initialization) and
  the `if not anyEngaged then return end` guard did not suppress the banner. Fix: added
  `anyRemoteEngaged` flag (initialized to false) that is set to true inside the remote
  loop only when a party member is found engaged with the same quest. The guard now
  requires both `anyEngaged` and `anyRemoteEngaged` — the banner only fires when at
  least one remote party member was also engaged with the quest and all such members
  are done.

### Version 2.18.11 (April 2026)
- Bug fix: Party and Shared tabs showed "Complete" status text for quests with numeric
  objectives (kill/collect/interact) when all objectives were fulfilled, instead of
  showing fully-filled progress bars. Root cause: `AddPlayerRow` in `RowFactory.lua`
  applied the `isComplete → "Complete"` text branch to all complete quests regardless
  of objective type. Fix: added `isNoObjectiveQuest` guard to the `isComplete` branch,
  matching the existing guard on the `"In Progress"` branch. Quests with numeric
  objectives now always render bars; "Complete" text only shows for quests with no
  trackable numeric objectives (talk-to-NPC, go-to-location, etc.).

### Version 2.18.10 (April 2026)
- Bug fix: "Everyone has completed" banner suppressed when both players finish
  near-simultaneously. Root cause: `checkAllCompleted` is called twice per completion
  event — once with `localHasCompleted=true` (own AQL callback) and once with
  `localHasCompleted=false` (triggered by the remote player's incoming `SQ_UPDATE`).
  On the second call, `AQL:GetQuest(questID).isComplete` may still be `false` if the
  AQL cache hasn't settled yet (or in `/aql fire` testing, where the cache is never
  updated). The local-done check then fails and the banner is suppressed even though
  the local player did complete the quest. Fix: `selfFinishedQuests` module-level table
  in `Announcements.lua` records any questID for which `checkAllCompleted` fired with
  `localHasCompleted=true`. The `localDone` check now includes `selfFinishedQuests[questID]`
  so subsequent remote-triggered calls always see the local player as done.

### Version 2.18.9 (April 2026)
- Feature: `/sq diagnose` console window now persists geometry across sessions. Window
  position (TOPLEFT), size, and input/output split fraction are stored in
  `char.frameState.console` (AceDB char scope) and restored the next time `/sq diagnose`
  is opened. Position is saved on drag-stop, size on resize-grip mouse-up, and split
  fraction when the separator bar is released.
- Feature: PageUp / PageDown scroll the input and output panes of the `/sq diagnose`
  console while keeping keyboard focus, so scrolling no longer interrupts typing or
  text selection. Shift+PageUp/Down additionally extends the text selection: uses the
  click anchor (set when the user clicks in the pane) and estimates characters per page
  from the EditBox line height and scroll-frame viewport height, then calls HighlightText
  to extend the selection to the new cursor position.
- Fix: all four `.toc` files (TBC, Mainline, Classic, Mists) now stay in sync on every
  version bump. Classic and Mists were last updated at 2.17.10 and have been brought
  forward to the current version.

### Version 2.18.8 (April 2026)
- Bug fix: "Everyone has completed" banner never fired in cross-realm parties on Retail
  due to three compounding issues in `Core/Communications.lua`:
  1. **Self-filter** (`OnCommReceived`): `UnitFullName("player")` returns nil realm on
     Retail even inside a cross-realm party, but CHAT_MSG_ADDON includes the realm suffix
     for all senders.  The self-filter now falls back to `GetNormalizedRealmName()` when
     UnitFullName returns a nil or empty realm, so own PARTY loopback messages (e.g.
     `"Leannae-Hakkar"`) are correctly suppressed instead of creating a self-stub with
     `hasSocialQuest=false`.
  2. **PARTY /reload recovery** (`SQ_INIT` handler): after the reloading player broadcasts
     `SQ_INIT` to PARTY, existing members never received `GROUP_ROSTER_UPDATE` (they never
     saw the player leave), so `OnMemberJoined` never fired and no whisper was sent back.
     PARTY is now included in the jittered-whisper-response path alongside RAID and
     INSTANCE_CHAT, with a 1–4 s delay.  `OnMemberJoined`'s direct send stamps
     `lastInitSent` so the 15-second cooldown suppresses any duplicate on fresh joins.
  3. **`hasSocialQuest` in `SQ_RESP_COMPLETE`**: a player responding to `SQ_REQ_COMPLETED`
     proves they have SocialQuest installed.  The handler now sets `entry.hasSocialQuest =
     true` and `entry.dataProvider` so `checkAllCompleted`'s suppression gate
     (`not hasSocialQuest and not dataProvider`) cannot fire for them even if the normal
     `SQ_INIT` exchange was delayed.

### Version 2.18.7 (April 2026)
- Bug fix: Ctrl+C in the `/sq diagnose` output pane still opened the Character window.
  Root cause identified: WoW fires `OnKeyDown` with `key = "LCTRL"` (or `"RCTRL"`) the
  moment the user holds Ctrl, *before* "C" is pressed. The previous handler had no guard
  for modifier keys, so `ClearFocus()` was called on the LCTRL event, stripping C-level
  focus from the EditBox. When "C" then arrived, no EditBox owned focus and the game
  keybinding fired instead. Fix: modifier keys (`LCTRL/RCTRL/LSHIFT/RSHIFT/LALT/RALT`)
  now call `SetPropagateKeyboardInput(false)` and return early without clearing focus.
  `Ctrl+A` / `Ctrl+C` likewise call `SetPropagateKeyboardInput(false)` explicitly so
  WoW's native EditBox copy/select-all runs at the C level. All other keys propagate
  normally and release focus as before.

### Version 2.18.6 (April 2026)
- Bug fix: Ctrl+C in the `/sq diagnose` console output pane opened the Character window
  instead of copying selected text. Root cause: `SetPropagateKeyboardInput(false)` on the
  child EditBox only blocks Lua-frame propagation, not WoW's C-level game keybinding system.
  Fix: the main console frame now calls `f:EnableKeyboard(true)` and installs an `OnKeyDown`
  handler that calls `self:SetPropagateKeyboardInput(not sqEditFocused)`. A `sqEditFocused`
  flag is toggled by `OnEditFocusGained`/`OnEditFocusLost` on both EditBoxes. When either
  EditBox owns keyboard focus the main frame blocks game keybindings (Ctrl+C, etc.); when
  neither does, keybindings propagate normally so chat and other UI shortcuts are unaffected.
- Bug fix: clicking anywhere in the input pane (including empty space below the text) now
  gives the input EditBox keyboard focus. The input ScrollFrame now has `EnableMouse(true)`
  and an `OnMouseDown` that forwards `SetFocus()` to the EditBox, so a left-click anywhere
  in the input area places the cursor rather than only responding when clicking directly
  on existing text.

### Version 2.18.5 (April 2026)
- Feature: `/sq diagnose` now opens a persistent interactive Lua console window instead of
  the old read-only copyable text popup. The window has: an input pane (multiline EditBox,
  Tab inserts 2 spaces) for typing Lua code; a draggable separator bar between input and
  output; an output pane (ScrollFrame + FontString) showing captured results; Run and Clear
  buttons in the title bar. Clicking Run executes the input as Lua via `loadstring`/`pcall`,
  temporarily redirects the global `print` to capture output lines (shown in yellow), and
  wraps each run with `--[[ SQ-RUN-START ]]--` / `--[[ SQ-RUN-END ]]--` markers. Compile
  and runtime errors shown in red. The window is draggable, resizable (resize grip at
  bottom-right), clamped to screen, TOOLTIP strata (always on top), and toggles on repeated
  `/sq diagnose`. The output pane pre-populates with the same group-state snapshot the old
  popup showed, in grey. Frame persists as `SQConsoleFrame` global for the session.

### Version 2.18.4 (April 2026)
- Bug fix: "Everyone has completed" banner never fired on Retail when both party members
  completed their quest. Root cause: on Retail, `UnitName("partyN")` returns a nil realm
  for same-realm players, while AceComm message senders include the realm suffix
  (`"Name-Realm"`). This caused two separate `PlayerQuests` entries per player — a ghost
  stub under `"Name"` (created by `GroupComposition` and `OnUnitQuestLogChanged`) and a
  full-data entry under `"Name-Realm"` (created from the AceComm sender). The ghost stub
  has `hasSocialQuest=false` and no `dataProvider`, so `checkAllCompleted`'s suppression
  gate (`if not entry.hasSocialQuest and not entry.dataProvider then return end`) fired on
  it, preventing the "Everyone completed" message. Fix: `GroupComposition.lua` and
  `GroupData.lua` now call `SQWowAPI.UnitFullName` instead of `SQWowAPI.UnitName` when
  building the player key for `PlayerQuests`. On Retail, `UnitFullName` returns
  `"Name", "Realm"` even for same-realm players, matching the AceComm sender format. On
  TBC/Classic/MoP, `UnitFullName` behaves identically to `UnitName` (realm is nil for all
  players) — no behavior change on those versions.

### Version 2.18.3 (April 2026)
- Bug fix: chain header label in Party and Shared tabs showed the title of the current
  quest step rather than the chain's root quest name, causing the label to change as
  players turned in quests and advanced steps (regression on Retail). Both tabs now use
  `AQL:GetQuestInfo(chainID)` to resolve the step-1 title at chain-entry creation time,
  matching the fix already in place in MineTab since 2.6.0.

### Version 2.18.2 (April 2026)
- Bug fix: "Everyone has completed" banner failed to fire on Retail when party members
  held variant questIDs for the same logical quest. Two fixes in `checkAllCompleted`:
  (1) Remote player quest lookup now falls back to a direct questID match when title
  resolution fails (`triggerTitle = nil`) or when `qdata.title` was not stored — this
  ensures the player who sent ET.Finished is always found as engaged. (2) Local player
  engagement detection now also scans `AQL:GetAllQuests()` by title when `AQL:GetQuest`
  returns nil for the triggering questID — correctly identifies the local player's
  variant quest on Retail. Verbose debug logging added to `checkAllCompleted` (fires
  when debug.enabled) to capture triggerTitle, localEngaged/Done, and per-remote-player
  engagement when troubleshooting future issues.

### Version 2.18.1 (April 2026)
- Feature: No-objective quest status display. Quests with no numeric X/Y objectives
  (travel, talk-to-NPC, exploration) now show per-player status in Party and Shared tabs
  using a two-column layout: player name left, status text left-aligned at bar start
  position. Three states: "Finished" (quest turned in, green), "Complete" (objectives
  met not yet turned in, green), "In Progress" (no objectives, not yet done, dimmed).
  Mine tab title row gains an `(In Progress)` badge at lowest priority (after `(Complete)`
  and `(Group)`).
- Refactor: `hasCompleted` and `isComplete` player rows now use `renderStatusRow` for
  consistent two-column layout. Single-string fallback preserved when `nameColumnWidth`
  is nil.
- i18n: new locale keys `Finished`, `In Progress`, `(In Progress)` in all 12 locales.
  Removed `%s FINISHED` format-string key (superseded by standalone `Finished`).

### Version 2.18.0 (April 2026 — Improvements branch)
- Bug fix: "Everyone has completed" banner now fires correctly when party members hold
  Retail variant questIDs for the same logical quest (same title, different numeric ID
  per race/class character type). `checkAllFinished` renamed to `checkAllCompleted`
  throughout. Remote player matching now uses quest title comparison (`qdata.title`)
  rather than exact questID lookup, so variant questIDs are correctly detected as the
  same quest.
- Bug fix: Party tab no longer shows duplicate rows for Retail variant questIDs of the
  same ungrouped (non-chain) quest. Entries are merged by title via new `mergePlayers`
  deduplication helper that prefers real quest-data rows over "needsShare" placeholders.
- Bug fix: Shared tab no longer requires both players to have the identical questID for
  a quest to appear. Title-based merge of `questEngaged` entries means variant questIDs
  of the same quest now combine their player counts, correctly reaching the 2+ threshold.
- Language cleanup: all internal debug messages and comments around the "everyone done"
  check updated from "finished" to "completed" for consistency with the displayed
  `L["Everyone has completed: %s"]` string.
- Requires: AQL 3.3.0 (`GetQuestAliasKey`, `AreQuestsAliases` available; `checkAllCompleted`
  uses `AQL:GetQuestTitle` for cross-source title resolution).

### Version 2.17.19 (April 2026 — Improvements branch)
- Bug fix: spurious `QuestMapFrame_ShowQuestDetails` re-fires after `QuestMapFrame_CloseQuestDetails` during back-navigation. Blizzard calls ShowQuestDetails immediately after CloseQuestDetails as part of its own bookkeeping, re-setting `_retailDetailQuestID` in the same game frame and causing the toggle-close to misfire on the next SQ click. Fix: `_retailDetailClosedAt` records the `GetTime()` of the last CloseQuestDetails call; ShowQuestDetails hook ignores any call within 100ms of it. That window is far longer than the same-frame spurious Blizzard fire, and far shorter than any human re-click.

### Version 2.17.18 (April 2026 — Improvements branch)
- Bug fix: toggle-close in `openQuestLogToQuest` (RowFactory.lua) now uses hook-based tracking instead of `AQL:IsQuestDetailShown()`. On Retail, `QuestModelScene:IsVisible()` (the basis of `IsQuestDetailShown`) remains true even when the quest list is showing — the Retail quest log uses a split-pane layout where the model scene stays visible regardless of which panel is active. The fix: `hooksecurefunc` on `QuestMapFrame_ShowQuestDetails` sets `_retailDetailQuestID = questID` when details are confirmed shown; `hooksecurefunc` on `QuestMapFrame_CloseQuestDetails` (if present) and `WorldMapFrame:OnHide` clear it. The toggle-close condition on Retail is now `IsQuestLogShown() AND _retailDetailQuestID == questID`. On TBC/Classic, the original `GetSelectedQuestLogEntryId() == questID` check is preserved (still correct on those versions).

### Version 2.17.17 (April 2026 — Improvements branch)
- Superseded by 2.17.18. Added `AQL:IsQuestDetailShown()` to toggle-close condition; did not work because `QuestModelScene:IsVisible()` does not distinguish detail-panel-active from quest-list-showing on Retail.

### Version 2.17.16 (April 2026 — Improvements branch)
- Cleanup: removed orphaned `local SQWowUI = SocialQuestWowUI` declaration from `UI/RowFactory.lua`. This local was added when implementing the (now-removed) SQ bypass for quest detail navigation and was never referenced after the bypass was deleted.

### Version 2.17.15 (April 2026 — Improvements branch)
- Reverted 2.17.14's toggle change. Using `AQL:GetCurrentlyOpenQuestId()` (AQL-tracked state) is incorrect: if the player opens the quest log from the tracker, a keybind, or any other source, the tracked questID is stale and the toggle fires on the wrong quest. The toggle check is restored to `AQL:GetSelectedQuestLogEntryId() == questID` (observable UI state). On Retail this depends on `WowQuestAPI.ShowQuestDetails` establishing the visual selection — the toggle-close gracefully degrades to a no-op until that unverified Retail API is resolved.

### Version 2.17.13 (April 2026 — Improvements branch)
- Bug fix: clicking a quest title in the SQ group window opened the quest log but did not navigate to or select that quest's detail panel. `openQuestLogToQuest` in `RowFactory.lua` used two deprecated AQL APIs — `AQL:GetSelectedQuestId()` replaced with `AQL:GetSelectedQuestLogEntryId()` and `AQL:SetQuestLogSelection(logIndex)` replaced with `AQL:OpenQuestLogById(questID)`. The Retail detail-panel navigation gap is fixed in AQL 3.2.7 (`WowQuestAPI.ShowQuestDetails` + `OpenQuestLogByIndex` update). Also fixed a nil dereference: `AQL:GetQuest(questID).zone` now nil-safe.

### Version 2.17.12 (April 2026 — Improvements branch)
- Bug fix (follow-up to 2.17.11): `BuildRemoteObjectives` reformatted count-first objective text (`"X/Y Description"`) into count-last (`"Description: X/Y"`), causing the local player's bar to show `"8/8 Blackrock Spy slain"` while remote players showed `"Blackrock Spy slain: 8/8"`. Fixed by detecting which format was matched and reconstructing in the same format — count-first stays count-first, count-last stays count-last.

### Version 2.17.11 (April 2026 — Improvements branch)
- Bug fix: remote player objective bar text showed the local player's stale count instead of the remote player's actual progress. Two root causes: (1) `BuildRemoteObjectives` in `TabUtils.lua` only recognised WoW's count-last objective text format (`"Description: X/Y"`) when stripping the embedded count before substituting the remote player's value; Retail's `C_QuestLog.GetQuestObjectives` returns count-first format (`"X/Y Description"`) which didn't match the pattern, so the verbatim stale text was used. Fixed by trying the count-first pattern `"^%d+/%d+%s+(.+)$"` as a fallback, with a final safety net of count-only text when neither pattern matches but an embedded count is detected. (2) `OnUpdateReceived` in `GroupData.lua` stored `objectives[i].isFinished` directly from the wire as an integer (0 or 1) — in Lua `0` is truthy, so RowFactory's `obj.isFinished and "completed" or "active"` coloured every freshly-accepted quest bar green immediately. Fixed by converting `obj.isFinished = obj.isFinished == 1` in a loop before storing, matching the fix already applied to `OnInitReceived` in 2.12.17.

### Version 2.17.10 (April 2026 — Improvements branch)
- Bug fix: `chainStepEntries` declared at wrong scope in `PartyTab:BuildTree` — shared across all zones, so a chainID appearing in multiple zones caused Zone B to silently merge players into Zone A's entry and drop the step from Zone B's chain. Fixed by replacing `local chainStepEntries = {}` (before the questID loop) with `local chainStepEntriesByZone = {}`, initializing a per-zone sub-table on first use inside the loop. Added nil guard on `ciEntry.step` before using it as a table key, falling back to an unconditional `table.insert` when step is nil.

### Version 2.17.9 (April 2026 — Improvements branch)
- Refactor (Retail): `SocialQuestTabUtils.GetChainInfoForQuestID` removed. All call sites in
  PartyTab and SharedTab replaced with direct `AQL:GetChainInfo(questID)` calls. The provider
  fallthrough logic is now handled inside `AQL:GetChainInfo` itself (AQL 3.2.6), making the
  SocialQuest wrapper redundant. Party tab and Shared tab step deduplication replaced: the
  previous title+zone heuristic merge (2.17.8) is superseded by step-number keying
  `chainStepEntries[chainID][stepNum]` — since AQL now returns the same chainID and step for
  all Retail variant questIDs of the same logical quest, the key is unambiguous and O(1).

### Version 2.17.8 (April 2026 — Improvements branch)
- Bug fix (Retail): Party tab duplicated same-quest entries when two players had different race/class variant questIDs for the same logical quest (e.g. questID 28763 and 28766 for "Beating Them Back!"). Both were correctly grouped under the same `chainID` after AQL 3.2.4 fixes, but still appeared as two separate step entries under the same chain header — each with only one player's progress rows. Fix: when inserting an entry into `zone.chains[chainID].steps` (or `zone.quests`), check if an entry with the same title AND zone already exists. If so, merge the new entry's `players` array into the existing entry instead of adding a duplicate. Title+zone matching prevents false positives from unrelated quests with coincidentally identical names in different zones. Same merge applied to ungrouped quests in `zone.quests`.

### Version 2.17.7 (April 2026 — Improvements branch)
- Diagnostic: two additions to pinpoint why SQ addon messages are not received on Retail. (1) Raw independent `CHAT_MSG_ADDON` frame registered in `OnEnable` — fires for every SQ-prefixed message that WoW delivers, completely bypassing AceComm. When `debug.enabled` is true, prints `[SQ][CHAT_MSG_ADDON] prefix= dist= sender=` directly to chat. If this fires, WoW delivered the event; if not, prefix registration is failing and messages go to `CHAT_MSG_ADDON_FILTERED` instead. (2) `/sq diagnose` now reports `C_ChatInfo.IsAddonMessagePrefixRegistered` status for all 8 SQ prefixes (Retail only).

### Version 2.17.6 (April 2026 — Improvements branch)
- Bug fix: SQ party communication completely broken on Retail — `memberSet` and `PlayerQuests` always empty despite being in a party. Root cause: on Retail, `GROUP_ROSTER_UPDATE` fires before `OnEnable` registers for it. The existing fallback (`PLAYER_LOGIN` → `OnPlayerLogin` → `OnGroupRosterUpdate`) also never fires because `PLAYER_LOGIN` has already been consumed by the time `OnEnable` registers for it. Result: group state was never bootstrapped; `memberSet` stays empty; all send/receive paths silently fail because no stubs exist. Fix: call `SocialQuestGroupComposition:OnGroupRosterUpdate()` directly at the end of `OnEnable()`. This runs immediately after all initialization, correctly detects any existing group, and works regardless of prior event ordering. Removed dead `PLAYER_LOGIN` event registration and `OnPlayerLogin` handler from both `SocialQuest.lua` and `GroupComposition.lua`.

### Version 2.17.5 (April 2026 — Improvements branch)
- Diagnostic: added `/sq diagnose` slash command. Prints runtime group state unconditionally (no debug.enabled gate): IsInRaid, PARTY_CATEGORY_HOME/INSTANCE values, IsInGroup results for both categories, GetActiveChannel result, GetNumGroupMembers, UnitFullName/UnitName for player, UnitName for each party slot, GroupComposition.memberSet contents, PlayerQuests keys with hasSocialQuest/dataProvider, debug.enabled, party.transmit, and zone-suppress status. Used to pinpoint which layer of the send/receive pipeline is failing on Retail.

### Version 2.17.4 (April 2026 — Improvements branch)
- Diagnostic attempt: SQ_UPDATE and all other AceComm prefixes not received on Retail. Attempted fix was a no-op: changing `LibStub("AceComm-3.0"):RegisterComm(prefix, callback)` to `SocialQuest:RegisterComm(prefix, callback)` — both write to the same `AceComm.callbacks.events` table (the library mixin copies its callback table to the addon object at embed time), so receive behavior was unchanged. Root cause at this point was still unidentified; the actual cause was found in 2.17.8 (`AQL:GetQuestTitle`/`AQL:GetQuestInfo` calling non-existent `GetQuestInfo` WoW global on Retail).

### Version 2.17.3 (April 2026 — Improvements branch)
- Bug fix: Party communication completely broken — banners never fired for other players and quest data never appeared in Party/Shared tabs. Root cause: `GetActiveChannel()` in `Communications.lua` and `currentGroupType()` in `GroupComposition.lua` both checked `IsInGroup(PARTY_CATEGORY_INSTANCE)` before `IsInGroup(PARTY_CATEGORY_HOME)`. If `LE_PARTY_CATEGORY_INSTANCE` is nil in the WoW environment (possible on TBC), `IsInGroup(nil)` degrades to `IsInGroup()` which returns truthy for any group including a home party — so a normal party was classified as a Battleground and messages were sent to `INSTANCE_CHAT` instead of `PARTY`. Both checks now nil-guard `PARTY_CATEGORY_INSTANCE` before using it.

### Version 2.17.2 (March 2026 — Improvements branch)
- Bug fix: `GroupFrame.lua:318` crashed on Retail with "Couldn't find inherited node 'TabButtonTemplate'" — `TabButtonTemplate` was removed in Retail. Added `SocialQuestWowUI.TabButtonTemplate` constant to `Core/WowUI.lua` that returns `"PanelTabButtonTemplate"` on Retail and `"TabButtonTemplate"` on all other versions. `GroupFrame.lua` `makeTab` now uses `SQWowUI.TabButtonTemplate`.

### Version 2.17.1 (March 2026 — Improvements branch)
- Bug fix (port from AQL3Compat): `BuildEngagedSet(nil)` in `TabUtils.lua` now nil-checks `_GetCurrentPlayerEngagedQuests` before calling it, falling back to `AQL:GetAllQuests()` + `AQL:GetCompletedQuests()`. Eight remaining standalone `AQL:_GetCurrentPlayerEngagedQuests()` direct calls in `MineTab.lua`, `PartyTab.lua`, and `SharedTab.lua` replaced with `SocialQuestTabUtils.BuildEngagedSet(nil)`.
- Bug fix (port from AQL3Compat): SocialQuest group members incorrectly shown as Questie bridge users due to a race condition where the joining player's `SQ_INIT` PARTY broadcast arrived before `GROUP_ROSTER_UPDATE` created their `PlayerQuests` stub. `OnInitReceived` dropped the message; the Questie bridge then hydrated them at t+4s. Fix: `Communications.lua` creates the stub via `OnMemberJoined` for non-whisper SQ_INIT when the sender has no existing entry.

### Version 2.17.0 (March 2026 — Improvements branch)
- Feature: Multi-version WoW support infrastructure. `Core/WowAPI.lua` now derives `IS_CLASSIC_ERA`, `IS_TBC`, `IS_MOP`, `IS_RETAIL` booleans from `GetBuildInfo()` at load time. Three companion TOC files added: `SocialQuest_Classic.toc` (Interface 11508), `SocialQuest_Mists.toc` (Interface 50503), `SocialQuest_Mainline.toc` (Interface 120001). `QuestLogPushQuest` routes to `C_QuestLog.PushQuestToParty(questID)` on Retail; call site updated to pass `entry.questID`. `GetRaidRosterInfo` routes to `C_RaidRoster.GetRaidRosterInfo` on Retail. `MAX_QUEST_LOG_ENTRIES` constant (35 Retail / 25 others) replaces hardcoded `25` in the quest-log-full check. `RACE_ID` and `CLASS_ID` numeric reference tables added for documentation purposes.
- Refactor: `RACE_BITS` and `CLASS_BITS` lookup tables removed from `PartyTab.lua`. Race/class eligibility now uses the numeric raceID/classID (third return from `UnitRace`/`UnitClass`) with `2^(id-1)` — correct for all WoW versions and Retail allied races, no maintenance required.
- Refactor: `SocialQuestTabUtils.BuildEngagedSet(playerName)` consolidates four copies of the inline engaged-set construction pattern across `MineTab.lua`, `PartyTab.lua`, `SharedTab.lua`, and `Announcements.lua`. `appendChainStep` in `Announcements.lua` now accepts an optional `sender` parameter so remote quest banners show the sender's own chain step.
- Refactor: All 9 direct `C_Timer.After` calls in `Core/QuestieBridge.lua` replaced with `SQWowAPI.TimerAfter`, consistent with the single-owner-of-WoW-globals policy.
- Feature: Retail tooltip hook. `UI/Tooltips.lua` `Initialize` uses `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Quest, ...)` on Retail; falls back to `hooksecurefunc(ItemRefTooltip, "SetHyperlink")` on all other versions.

### Version 2.15.0 (March 2026 — Improvements branch)
- Feature: `&` same-key AND operator in the advanced filter language. A single filter label can now express multiple conditions on the same key: `type=dungeon&gather` (dungeon quests with gather objectives), `level>=55&<=62` (level range), `title=dragon&slayer` (title contains both words). The key is written once; operator is inherited by subsequent fragments when omitted. `&` and `|` may not be combined in the same expression (`MIXED_AND_OR` error). `compound_and` descriptor type added to `FilterParser`; all four `Matches*` helpers in `TabUtils` handle it recursively. `FilterState` and `HeaderLabel` unchanged.
- Feature: `shareable` filter key (Party tab only). `shareable=yes` shows quests the local player can share with at least one party member right now — same condition as the [Share] button (local has it, AQL reports it shareable, at least one party member has `needsShare=true`). `entry.hasShareableMembers` pre-computed in `PartyTab:BuildTree`; `buildQuestCallbacks` reads the pre-computed value. Help window updated with three `&` examples and one `shareable` example across all 12 locales.

### Version 2.14.2 (March 2026 — Improvements branch)
- Polish: Share button now uses `UIPanelButtonTemplate` for the standard WoW button appearance (same style as quest log Accept/Decline/Share buttons). Removed bracket-wrapped text label; button now shows plain "Share" text via the template's built-in font string.

### Version 2.14.1 (March 2026 — Improvements branch)
- Bug fix: `[Share]` button did not appear in the Party tab. Root cause: `shareBtn:SetPoint` used `"RIGHT"` / `"RIGHT"` anchors, which position relative to the center of the content frame's right edge — the button rendered at the wrong vertical position (hidden off-screen). Fixed by changing to `"TOPRIGHT"` / `"TOPRIGHT"`, matching the badge anchor convention used by all other right-aligned row elements.

### Version 2.14.0 (March 2026 — Improvements branch)
- Feature: Share button + full quest eligibility. Party tab quest rows now show a `[Share]` button when the local player has the quest, it is shareable, and at least one party member needs it. Clicking calls `QuestLogPushQuest()` via `SQWowAPI` after selecting the quest in the log. Party member rows for ineligible players now show a specific reason label in muted amber (e.g. "level too low", "wrong class", "needs: [Quest Name]") instead of the misleading "Needs it Shared" label. Reason labels cover 7 cases: level_too_low, level_too_high, wrong_race, wrong_class, quest_log_full, exclusive_quest, already_advanced, plus dynamic "needs: questTitle" for prerequisite mismatches. Uses `AQL:GetQuestRequirements(questID)` (new in AQL 2.4.0) for tier-2 checks; degrades gracefully to tier-1-only (race/class/level/log-full) when no provider is available. New `SQWowAPI` wrappers: `QuestLogPushQuest`, `UnitClass`. New private helpers in `PartyTab.lua`: `resolveUnitToken`, updated `isEligibleForShare`. New locale keys in all 12 locale files.

### Version 2.13.0 (March 2026 — Improvements branch)
- Bug fix: zone auto-filter broke in all non-starter subzones after the 2.12.31 sub-zone preference fix. In subzones like Goldshire (Elwynn Forest), `GetSubZoneText()` returned "Goldshire" which doesn't match any quest log zone header, so the filter showed no quests. Root cause: the fix unconditionally preferred `GetSubZoneText()` when non-empty. New approach: check whether the subzone name actually appears as a zone header in the active quest log (`AQL:GetQuestLogZones()`). Starter subzones (Northshire Valley, etc.) are the only subzones with quests scoped to their name, so the check correctly selects the subzone for starter zones and falls back to `GetRealZoneText()` everywhere else. Locale-safe: both `GetSubZoneText()` and AQL zone headers use the client language.

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
