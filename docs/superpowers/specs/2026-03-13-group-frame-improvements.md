# SocialQuest Group Frame Improvements — Design Spec
**Date:** 2026-03-13
**Branch:** Improvements
**Repos affected:** Social-Quest (primary), Absolute-Quest-Log (minor additions)

---

## 1. Overview

Redesign the SocialQuest group frame (opened via `/sq` or minimap button) to provide a
richer, more readable display modelled on the WoW quest log. Key improvements:

- Zone/category grouping with per-tab collapsible headers (state persisted across sessions)
- Left-aligned layout with standardised tab-provider architecture
- Quest difficulty colour coding, chain step display, timer display
- Completion and group-size badges; shift-click quest tracking on Mine tab
- Wowhead link button with clipboard fallback
- Objective colour coding (yellow = incomplete, green = complete)
- Party tab: quest-centric layout with per-player progress rows, FINISHED / Needs it Shared indicators
- New AceComm messages to query group members' completed quest history

---

## 2. AQL Changes (Absolute-Quest-Log)

### 2.1 New QuestInfo Fields

Two fields are added to the return table of `QuestCache:_buildEntry` in
`Core/QuestCache.lua`.

**`logIndex` (number)** — the quest's position in the quest log at snapshot time.
`logIndex` is already computed during `Rebuild()` (loop variable `i`) and already
passed as a parameter to `_buildEntry`; it is simply not stored in the returned
table. The only change required is adding `logIndex = logIndex` to the return
table in `_buildEntry`. No other code in QuestCache needs modification.
Required by SocialQuest for `AddQuestWatch(logIndex)` / `RemoveQuestWatch(logIndex)`.

**Important:** `logIndex` is a local-player-only field. It is meaningful only on
entries returned by `AQL:GetAllQuests()`. Remote `PlayerQuests` entries in GroupData
never carry `logIndex`. The shift-click tracking callback in RowFactory must only
be provided when rendering local player quests (Mine tab); it must be `nil` for all
remote player rows. The AQL design spec (`2026-03-11-absolute-quest-log-design.md`)
should also be updated to list `logIndex` and `wowheadUrl` in the QuestInfo table.

**`wowheadUrl` (string)** — always set to
`WOWHEAD_QUEST_BASE .. questID` where `WOWHEAD_QUEST_BASE` is a module-level
constant at the top of `QuestCache.lua`:

```lua
local WOWHEAD_QUEST_BASE = "https://www.wowhead.com/tbc/quest="
```

Using a named constant makes the URL easy to verify or update without hunting through
`_buildEntry`. No provider involvement; populated for every quest regardless of active
provider.

> **Note for implementer:** verify the live Wowhead TBC Classic URL path before
> shipping. The path has historically been `/tbc/` and `/tbc-classic/` at different
> times. Update `WOWHEAD_QUEST_BASE` accordingly.

---

## 3. File Structure

### 3.1 New Files

```
Social-Quest/
  UI/
    RowFactory.lua          -- Shared stateless row-drawing utilities
    Tabs/
      MineTab.lua           -- Mine tab provider
      PartyTab.lua          -- Party tab provider
      SharedTab.lua         -- Shared tab provider
```

### 3.2 Modified Files

```
Social-Quest/
  UI/
    GroupFrame.lua          -- Trimmed to frame shell + tab dispatch + toggle state
  Core/
    GroupData.lua           -- Add per-player completedQuests storage and stub init
    Communications.lua      -- Add SQ_REQ_COMPLETED / SQ_RESP_COMPLETED messages
  SocialQuest.lua           -- Add frameState to GetDefaults()
  SocialQuest.toc           -- Register new files in load order

Absolute-Quest-Log/
  Core/
    QuestCache.lua          -- Add logIndex and wowheadUrl to _buildEntry return table
```

### 3.3 TOC Load Order (Social-Quest)

```
Util\Colors.lua
SocialQuest.lua
Core\GroupData.lua
Core\Communications.lua
Core\Announcements.lua
UI\RowFactory.lua
UI\Tabs\MineTab.lua
UI\Tabs\PartyTab.lua
UI\Tabs\SharedTab.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua
```

`RowFactory` and all tab providers must load before `GroupFrame`.

### 3.4 `RequestRefresh` Compatibility

`SocialQuestGroupFrame:RequestRefresh()` is called by `GroupData.lua` (lines 64,
102, 125, 170). After the refactor, `GroupFrame.lua` still owns the
`SocialQuestGroupFrame` global and still exposes `RequestRefresh` as a public method.
No changes to `GroupData.lua` are required for this surface.

---

## 4. Tab Provider Interface

Each tab module (`MineTab`, `PartyTab`, `SharedTab`) implements three functions.
This is a Lua naming convention, not a runtime mechanism.

```lua
TabModule:GetLabel()
  -- Returns the display string for the tab button.
  -- Returns: string

TabModule:BuildTree()
  -- Reads AQL and GroupData; returns a structured data tree. No UI created.
  -- Returns: tree (see Section 5)

TabModule:Render(contentFrame, rowFactory, tabCollapsedZones)
  -- Calls BuildTree(), walks the tree, calls rowFactory functions to draw rows.
  -- tabCollapsedZones: the per-tab subtable — GroupFrame passes
  --   SocialQuestDB.profile.frameState.collapsedZones[tabId] (NOT the full map).
  -- Returns: number  (total content height, for SetHeight on contentFrame)
```

`GroupFrame` registers providers in an ordered table:

```lua
local providers = {
    { id = "mine",   module = MineTab   },
    { id = "party",  module = PartyTab  },
    { id = "shared", module = SharedTab },
}
```

On `Refresh()`, `GroupFrame`:
1. Looks up `activeProvider` from `providers`
2. Slices `SocialQuestDB.profile.frameState.collapsedZones[activeProvider.id]`
3. Calls `activeProvider.module:Render(contentFrame, RowFactory, slicedTable)`

---

## 5. Tree Structure

`BuildTree()` returns:

```lua
{
  zones = {
    [zoneName] = {
      name   = string,    -- zone/category header text (from quest log header)
      order  = number,    -- quest log iteration order (ascending integer, 1-based,
                          -- assigned by the order headers are encountered in
                          -- GetQuestLogTitle loop during Rebuild)
      chains = {
        [chainID] = {
          title = string,         -- display name of the chain
          steps = { questEntry, ... }  -- ordered ascending by chainInfo.step
        }
      },
      quests = { questEntry, ... }  -- standalone quests (no chain info)
    }
  }
}
```

**Placement rule:** a quest is placed in `chains[chainID]` when
`chainInfo ~= nil` and `chainInfo.knownStatus == "known"` and
`chainInfo.chainID ~= nil`; otherwise it goes into `quests`.
Zones with no chain data render purely from `quests`.
Mixed zones render chains first (ordered by `chainInfo.chainID` ascending, numeric
sort), then standalone quests.

### 5.1 questEntry

```lua
{
  questID        = number,
  title          = string,
  level          = number,
  zone           = string,
  isComplete     = bool,
  isFailed       = bool,
  isTracked      = bool,
  logIndex       = number,
  suggestedGroup = number,    -- 0 means solo
  timerSeconds   = number|nil,
  snapshotTime   = number|nil,
  wowheadUrl     = string,
  chainInfo      = ChainInfo|nil,
  objectives     = { ObjectiveEntry, ... },
  players        = { playerEntry, ... },
  -- Mine tab: contains cross-chain peers (other players on the same chain,
  --           different step). Empty when no chain or no peers.
  -- Party/Shared: contains all relevant party members for that quest.
}
```

### 5.2 playerEntry

```lua
{
  name         = string,
  isMe         = bool,
  step         = number|nil,    -- chainInfo.step for this player's questID in the chain;
                                -- nil when chainInfo.knownStatus ~= "known" for that quest
  objectives   = { ObjectiveEntry, ... },
  isComplete   = bool,
  hasCompleted = bool,    -- true if found in GroupData.PlayerQuests[name].completedQuests
  needsShare   = bool,    -- see Section 8.2 for exact conditions
}
```

---

## 6. GroupFrame (Revised Responsibilities)

`GroupFrame.lua` after the split:

- Creates the frame, title, tab buttons, and scroll area (unchanged visually)
- Holds the ordered `providers` table; calls the active provider on `Refresh()`
- Owns `collapsedZones` state; providers read the per-tab slice but never write it
- Exposes `GroupFrame:ToggleZone(tabId, zoneName)` — flips
  `SocialQuestDB.profile.frameState.collapsedZones[tabId][zoneName]` and calls
  `Refresh()`
- Registers the `SQ_WOWHEAD_POPUP` StaticPopup at module load (see Section 7)

### 6.1 Saved Variables

Toggle state and active tab are stored under `SocialQuestDB.profile.frameState`.
The `frameState` key must be added to `GetDefaults()` in `SocialQuest.lua`:

```lua
frameState = {
  activeTab = "mine",
  collapsedZones = {
    mine   = {},
    party  = {},
    shared = {},
  },
},
```

Absent key = expanded (default). Toggle state persists across `/reload` and game
sessions via AceDB saved variables. AceDB merges defaults on first run, so no
migration is needed.

### 6.2 StaticPopup Registration

`GroupFrame.lua` registers the Wowhead URL popup at module scope (outside any
function), before any frame is created:

```lua
StaticPopupDialogs["SQ_WOWHEAD_POPUP"] = {
    text         = "Quest URL (Ctrl+C to copy):",
    button1      = "Close",
    hasEditBox   = 1,
    editBoxWidth = 300,
    OnShow       = function(self)
        self.editBox:SetText(self.data)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    OnAccept  = function() end,
    timeout   = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

`RowFactory.AddQuestRow` calls `StaticPopup_Show("SQ_WOWHEAD_POPUP", url)` in the
link button's `OnClick`. RowFactory itself contains no registration code; it is
stateless with respect to popup setup.

---

## 7. RowFactory

`RowFactory.lua` is a stateless module of row-drawing functions. All functions take
`contentFrame` and a running `y` offset, create WoW UI elements as children of
`contentFrame`, and return the new `y` value.

```lua
RowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, onToggle) → y
  -- [+]/[-] toggle Button + bold zone name FontString

RowFactory.AddChainHeader(contentFrame, y, chainTitle, indent) → y
  -- Chain label in SocialQuestColors.chain (cyan)

RowFactory.AddQuestRow(contentFrame, y, questEntry, indent, callbacks) → y
  -- Layout (left to right):
  --   Small Button "[?]" — OnClick calls StaticPopup_Show("SQ_WOWHEAD_POPUP", wowheadUrl)
  --   "[✓]" FontString if questEntry.isTracked (only rendered when callbacks.onTitleShiftClick ~= nil)
  --   Quest title Button, coloured by difficulty (see difficulty colour below)
  --     Regular click: no action
  --     Shift-click: calls callbacks.onTitleShiftClick(logIndex, isTracked) if provided
  --   " (Step X of Y)" FontString appended when chainInfo.knownStatus == "known" (Mine tab)
  --   Right-aligned FontString: "(Complete)" if isComplete, else "(Group)" if suggestedGroup > 0

RowFactory.AddObjectiveRow(contentFrame, y, objectiveEntry, indent) → y
  -- SocialQuestColors.active (yellow) if not isFinished
  -- SocialQuestColors.completed (green) if isFinished

RowFactory.AddPlayerRow(contentFrame, y, playerEntry, indent) → y
  -- "[Name] Step X of Y"         when step ~= nil and not hasCompleted
  -- "[Name] FINISHED"            green (SocialQuestColors.completed); bold via GameFontNormalSmall
  --                              or "|cFF00FF00[Name] FINISHED|r" if bold unavailable
  -- "[Name] Needs it Shared"     SocialQuestColors.unknown (grey)
  -- "[Name]" + objectives rows   when playerEntry.hasSocialQuest == true and none of the above apply
  -- "[Name] (no data)"           grey; when playerEntry.hasSocialQuest == false and
  --                              playerEntry.objectives is empty — the member is in the group
  --                              but has not responded to SQ_REQ_COMPLETED and sent no objective data
```

**`callbacks` table passed to `AddQuestRow`:**

```lua
{
  onLinkClick       = function(wowheadUrl) end,          -- always provided
  onTitleShiftClick = function(logIndex, isTracked) end, -- nil on Party/Shared tabs
}
```

**Difficulty colour** — use `GetQuestDifficultyColor(questLevel)` when available.
In TBC Classic (interface 20505) this function returns a table with `r`, `g`, `b`
number fields (0–1 range). Apply with `questTitleButton:SetTextColor(c.r, c.g, c.b)`.
If the function does not exist, derive colour from `UnitLevel("player") - questLevel`:

| Player level − Quest level | Colour |
|---|---|
| ≥ +10 | Grey `(0.75, 0.75, 0.75)` |
| +5 to +9 | Grey |
| +3 to +4 | Green `(0.25, 0.75, 0.25)` |
| -2 to +2 | Yellow `(1.0, 1.0, 0.0)` |
| -3 to -4 | Orange `(1.0, 0.5, 0.25)` |
| ≤ -5 | Red `(1.0, 0.1, 0.1)` |

**Shift-click tracking** (Mine tab only) — quest title is a `Button`, not a
`FontString`. In `OnClick`, check `IsShiftKeyDown()`. If true, call
`AddQuestWatch(logIndex)` when `not isTracked`, or `RemoveQuestWatch(logIndex)` when
`isTracked`. Regular clicks do nothing.

---

## 8. Tab-Specific Rendering Logic

### 8.1 Mine Tab

- **Source:** `AQL:GetAllQuests()`
- **Chain peers:** for each quest in the Mine tree, check `GroupData.PlayerQuests`
  for any party member whose active questID shares the same `chainID` but has a
  different `chainInfo.step`. Those members appear as `AddPlayerRow` entries in
  `questEntry.players`, showing `[Name] Step X of Y`. These player rows are part
  of the Mine tree — `questEntry.players` is NOT empty on Mine when chain peers exist.
- **Shift-click tracking:** enabled. `callbacks.onTitleShiftClick` is provided.
- **Timer:** if `timerSeconds` is present, remaining time is computed as
  `timerSeconds - (GetTime() - snapshotTime)` and appended to the quest row label
  (e.g. `" [2:34]"`).
- **Chain info:** `" (Step X of Y)"` appended to title when `chainInfo.knownStatus == "known"`.

### 8.2 Party Tab

- **Source:** `GroupData.PlayerQuests` (all party members, including the local player
  via `(You)`) plus `AQL:GetAllQuests()` for the local player's active quests.
- **Each quest is listed once** under its zone/chain, regardless of how many members
  share it.
- **Under each quest:** one `AddPlayerRow` per party member. The member's row state:
  - **Active (has quest):** show `playerEntry.objectives` with colour coding.
  - **FINISHED:** `hasCompleted == true` (found in `completedQuests`). Show
    `[Name] FINISHED` in green bold. Shown even if the member also has the quest
    actively (edge case: re-accepted quest after completion).
  - **Needs it Shared:** show `[Name] Needs it Shared` in grey when ALL of these
    are true:
    1. The member does NOT have the quest in their active log.
    2. The member does NOT have a `hasCompleted` record for it.
    3. The local player HAS the quest in their active AQL snapshot.
    Condition 3 is the gate; if the local player does not have the quest,
    `needsShare` is false for all members.
    **Note:** `GetQuestLogPushable` does not exist in TBC Classic (Interface 20505).
    The pushability check is therefore omitted entirely. Any quest meeting conditions
    1–3 is labelled "Needs it Shared", accepting that a small number of
    non-shareable quest types (e.g. some dungeon unlock quests) may be incorrectly
    labelled. This is preferable to a silent API error.
  - **No entry:** member has neither the quest nor a completion record and the quest
    is not shareable by the local player — omit that member entirely.
- **Shift-click tracking:** disabled (`onTitleShiftClick = nil`).

### 8.3 Shared Tab

- **Source:** union of `AQL:GetAllQuests()` (local player) and `GroupData.PlayerQuests`
  (all party members).
- **Qualification threshold:** a quest qualifies for the Shared tab when 2 or more
  players are engaged with the same quest content. "Engaged" means either:
  - The player has the questID in their active log, **or**
  - The player is on a different step of the same chain (same `chainID`).
  Chain peers on different steps of the same chain DO count toward the 2+ threshold.
- **Each quest listed once** (by questID for standalone; by chainID for chain quests).
- **Player rows:** local player shown as `(You)`. All active members listed with
  their objectives.
- **No FINISHED or Needs it Shared rows** on this tab — all listed players are
  actively engaged with the quest.
- **Shift-click tracking:** disabled.

---

## 9. Communications — Completed Quest Querying

### 9.1 New Message Types

| Message | Direction | Payload |
|---|---|---|
| `SQ_REQ_COMPLETED` | Broadcast to group | none (empty string) |
| `SQ_RESP_COMPLETED` | Whisper to requester | AceSerializer-encoded table (see below) |

Both strings must be added to the `PREFIXES` table in `SocialQuestComm:Initialize()`
alongside existing prefixes, and handled as new branches in `OnCommReceived`.

### 9.2 Payload Encoding

All existing SocialQuest messages use `AceSerializer-3.0`. `SQ_RESP_COMPLETED` must
follow the same pattern. The payload is an AceSerializer-encoded table:

```lua
{ completedQuests = { [questID] = true, ... } }
```

The receiver calls `AceSerializer:Deserialize(msg)` (matching the existing pattern
in `OnCommReceived`) and stores `data.completedQuests` in
`GroupData.PlayerQuests[senderName].completedQuests`.

### 9.3 Flow

1. SocialQuest `OnEnable` or `GROUP_ROSTER_UPDATE` fires with a new member →
   broadcast `SQ_REQ_COMPLETED` to "PARTY" channel via AceComm.
2. Each SocialQuest member who receives it whispers `SQ_RESP_COMPLETED` back to
   the sender. The `sender` argument provided by AceComm's `OnCommReceived`
   callback is used directly as the whisper target for `SendCommMessage`.
   The response payload is built from `AQL.HistoryCache.completed`.
3. Sender's `OnCommReceived` receives the `SQ_RESP_COMPLETED` whisper. The
   `sender` argument identifies which group member responded. The decoded
   `data.completedQuests` table is stored in
   `GroupData.PlayerQuests[sender].completedQuests`.
4. `PartyTab:BuildTree()` reads `completedQuests` to set `playerEntry.hasCompleted`.

### 9.4 GroupData Schema Additions

`GroupData.PlayerQuests[name]` gains one new field:

```lua
completedQuests = { [questID] = true, ... }   -- set; defaults to {}
```

`completedQuests` is initialised to `{}` in `OnGroupChanged` when a stub entry is
created for a new member — including members who do not have SocialQuest installed
(`hasSocialQuest == false`). The empty table is always present so that
`PartyTab:BuildTree()` can read it without nil-guarding. When a member leaves the
group (`GROUP_ROSTER_UPDATE` removes them), their entry in `PlayerQuests` is cleared
entirely — `completedQuests` is not persisted between separate group sessions.

### 9.5 Payload Size

AceComm's built-in chunking handles messages exceeding WoW's 255-byte channel
limit automatically. A character with thousands of completed quests will produce a
large payload; AceComm chunks transparently. Response is whispered (not group
broadcast) to avoid spamming the channel.

---

## 10. SocialQuest.lua — GetDefaults() Addition

`frameState` must be added to the `profile` table in `GetDefaults()`:

```lua
frameState = {
  activeTab = "mine",
  collapsedZones = {
    mine   = {},
    party  = {},
    shared = {},
  },
},
```

AceDB merges defaults on first load; no migration is needed for existing saved
variables.

---

## 11. Out of Scope

- Virtual scrolling (not needed at typical quest list sizes)
- Per-objective `needsShare` indicators
- Raid channel support (existing behaviour unchanged)
- Any changes to the Announcements, Tooltips, or Options modules
