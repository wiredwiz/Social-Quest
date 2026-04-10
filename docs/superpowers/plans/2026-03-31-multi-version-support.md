# Multi-Version Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend SocialQuest to support Retail WoW and other active versions at the API abstraction layer, fix the per-player chain engagement bug, and clean up internal WoW API leaks — without breaking TBC functionality.

**Architecture:** All version-specific branching lives in `Core/WowAPI.lua` (game-state) and `UI/Tooltips.lua` (UI). Consumer files reference only `SQWowAPI` wrappers — no direct WoW globals. The engaged-set construction pattern is deduplicated into `SocialQuestTabUtils.BuildEngagedSet`, eliminating four separate inline copies. Race/class eligibility migrates from lookup tables to the numeric formula `2^(id-1)`, correct for all current and future WoW versions.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), Ace3, AceLocale-3.0. Test runner: `lua tests/TabUtils_test.lua` and `lua tests/FilterParser_test.lua` (run from repo root).

---

## File Map

| File | Change |
|---|---|
| `SocialQuest_Classic.toc` | New — Interface 11508 (Task 1) |
| `SocialQuest_Mists.toc` | New — Interface 50503 (Task 1) |
| `SocialQuest_Mainline.toc` | New — Interface 120001 (Task 1) |
| `Core/WowAPI.lua` | Version constants, updated wrappers, MAX_QUEST_LOG_ENTRIES, RACE_ID/CLASS_ID (Tasks 1, 2) |
| `Core/QuestieBridge.lua` | 9 `C_Timer.After` → `SQWowAPI.TimerAfter` (Task 3) |
| `UI/TabUtils.lua` | Add `BuildEngagedSet` (Task 4) |
| `tests/TabUtils_test.lua` | `SelectChain` and `BuildEngagedSet` tests (Task 4) |
| `Core/Announcements.lua` | `appendChainStep` sender param, remote call site updated (Task 5) |
| `UI/Tabs/SharedTab.lua` | Inline engaged → `BuildEngagedSet` in `addEngagement` (Task 5) |
| `UI/Tabs/MineTab.lua` | Inline engaged → `BuildEngagedSet` in cross-chain peer loop (Task 5) |
| `UI/Tabs/PartyTab.lua` | `BuildEngagedSet`, remove RACE_BITS/CLASS_BITS, numeric formula, `MAX_QUEST_LOG_ENTRIES`, `QuestLogPushQuest(questID)` (Tasks 2, 5, 6) |
| `UI/Tooltips.lua` | Retail `TooltipDataProcessor` branch (Task 7) |
| `SocialQuest.toc` + 3 companion TOCs | Version bump to 2.17.0 (Task 8) |
| `CLAUDE.md` | Version history entry for 2.17.0 (Task 8) |

---

## Task 1: TOC Files + WowAPI Version Detection Constants

**Files:**
- Create: `SocialQuest_Classic.toc`
- Create: `SocialQuest_Mists.toc`
- Create: `SocialQuest_Mainline.toc`
- Modify: `Core/WowAPI.lua`

- [ ] **Step 1: Create `SocialQuest_Classic.toc`**

Identical to `SocialQuest.toc` except `## Interface: 11508`:

```
## Interface: 11508
## Title: SocialQuest
## Notes: Social quest coordination for WoW Burning Crusade Anniversary.
## Author: Thad Ryker
## Version: 2.16.0
## Category: Quests
## IconTexture: Interface\AddOns\SocialQuest\Logo.png
## Dependencies: Ace3, AbsoluteQuestLog
## SavedVariables: SocialQuestDB

# Embedded Libraries
Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua

# Color definitions
Util\Colors.lua

# Localization
Locales\enUS.lua
Locales\deDE.lua
Locales\frFR.lua
Locales\esES.lua
Locales\esMX.lua
Locales\zhCN.lua
Locales\zhTW.lua
Locales\ptBR.lua
Locales\itIT.lua
Locales\koKR.lua
Locales\ruRU.lua
Locales\jaJP.lua

# Core abstraction layer — after locales, before all game-logic modules
Core\WowAPI.lua
Core\WowUI.lua

# Main modules
SocialQuest.lua
Core\GroupComposition.lua
Core\GroupData.lua
Core\Communications.lua
Core\Announcements.lua
Core\BridgeRegistry.lua
Core\QuestieBridge.lua

# UI modules
UI\TabUtils.lua
UI\RowFactory.lua
UI\FilterParser.lua
UI\FilterState.lua
UI\HeaderLabel.lua
UI\Tabs\MineTab.lua
UI\Tabs\PartyTab.lua
UI\Tabs\SharedTab.lua
UI\WindowFilter.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua
```

- [ ] **Step 2: Create `SocialQuest_Mists.toc`**

Identical to `SocialQuest.toc` except `## Interface: 50503`:

```
## Interface: 50503
## Title: SocialQuest
## Notes: Social quest coordination for WoW Burning Crusade Anniversary.
## Author: Thad Ryker
## Version: 2.16.0
## Category: Quests
## IconTexture: Interface\AddOns\SocialQuest\Logo.png
## Dependencies: Ace3, AbsoluteQuestLog
## SavedVariables: SocialQuestDB

# Embedded Libraries
Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua

# Color definitions
Util\Colors.lua

# Localization
Locales\enUS.lua
Locales\deDE.lua
Locales\frFR.lua
Locales\esES.lua
Locales\esMX.lua
Locales\zhCN.lua
Locales\zhTW.lua
Locales\ptBR.lua
Locales\itIT.lua
Locales\koKR.lua
Locales\ruRU.lua
Locales\jaJP.lua

# Core abstraction layer — after locales, before all game-logic modules
Core\WowAPI.lua
Core\WowUI.lua

# Main modules
SocialQuest.lua
Core\GroupComposition.lua
Core\GroupData.lua
Core\Communications.lua
Core\Announcements.lua
Core\BridgeRegistry.lua
Core\QuestieBridge.lua

# UI modules
UI\TabUtils.lua
UI\RowFactory.lua
UI\FilterParser.lua
UI\FilterState.lua
UI\HeaderLabel.lua
UI\Tabs\MineTab.lua
UI\Tabs\PartyTab.lua
UI\Tabs\SharedTab.lua
UI\WindowFilter.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua
```

- [ ] **Step 3: Create `SocialQuest_Mainline.toc`**

Identical to `SocialQuest.toc` except `## Interface: 120001`:

```
## Interface: 120001
## Title: SocialQuest
## Notes: Social quest coordination for WoW Burning Crusade Anniversary.
## Author: Thad Ryker
## Version: 2.16.0
## Category: Quests
## IconTexture: Interface\AddOns\SocialQuest\Logo.png
## Dependencies: Ace3, AbsoluteQuestLog
## SavedVariables: SocialQuestDB

# Embedded Libraries
Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua

# Color definitions
Util\Colors.lua

# Localization
Locales\enUS.lua
Locales\deDE.lua
Locales\frFR.lua
Locales\esES.lua
Locales\esMX.lua
Locales\zhCN.lua
Locales\zhTW.lua
Locales\ptBR.lua
Locales\itIT.lua
Locales\koKR.lua
Locales\ruRU.lua
Locales\jaJP.lua

# Core abstraction layer — after locales, before all game-logic modules
Core\WowAPI.lua
Core\WowUI.lua

# Main modules
SocialQuest.lua
Core\GroupComposition.lua
Core\GroupData.lua
Core\Communications.lua
Core\Announcements.lua
Core\BridgeRegistry.lua
Core\QuestieBridge.lua

# UI modules
UI\TabUtils.lua
UI\RowFactory.lua
UI\FilterParser.lua
UI\FilterState.lua
UI\HeaderLabel.lua
UI\Tabs\MineTab.lua
UI\Tabs\PartyTab.lua
UI\Tabs\SharedTab.lua
UI\WindowFilter.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua
```

- [ ] **Step 4: Add version detection constants to `Core/WowAPI.lua`**

Insert after line 6 (`SocialQuestWowAPI = {}`):

```lua
local _toc = select(4, GetBuildInfo())
SocialQuestWowAPI.IS_CLASSIC_ERA = _toc >= 11000 and _toc < 20000
SocialQuestWowAPI.IS_TBC         = _toc >= 20000 and _toc < 30000
SocialQuestWowAPI.IS_MOP         = _toc >= 50000 and _toc < 60000
SocialQuestWowAPI.IS_RETAIL      = _toc >= 100000
```

The resulting file top should read:

```lua
SocialQuestWowAPI = {}

local _toc = select(4, GetBuildInfo())
SocialQuestWowAPI.IS_CLASSIC_ERA = _toc >= 11000 and _toc < 20000
SocialQuestWowAPI.IS_TBC         = _toc >= 20000 and _toc < 30000
SocialQuestWowAPI.IS_MOP         = _toc >= 50000 and _toc < 60000
SocialQuestWowAPI.IS_RETAIL      = _toc >= 100000

function SocialQuestWowAPI.GetTime() ...
```

- [ ] **Step 5: Verify tests pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc Core/WowAPI.lua
git commit -m "$(cat <<'EOF'
feat: add multi-version TOC files and WowAPI version detection constants

Add companion TOC files for Classic Era (11508), Mists (50503), and
Mainline/Retail (120001). Add IS_CLASSIC_ERA/IS_TBC/IS_MOP/IS_RETAIL
booleans to SocialQuestWowAPI derived from GetBuildInfo() toc number,
enabling version-specific branching in all subsequent tasks.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: WowAPI Wrappers + PartyTab Call Site Fixes

**Files:**
- Modify: `Core/WowAPI.lua`
- Modify: `UI/Tabs/PartyTab.lua`

- [ ] **Step 1: Replace `QuestLogPushQuest` wrapper in `Core/WowAPI.lua`**

Current line (one-liner):
```lua
function SocialQuestWowAPI.QuestLogPushQuest()                    QuestLogPushQuest()                           end
```

Replace with:
```lua
function SocialQuestWowAPI.QuestLogPushQuest(questID)
    if SocialQuestWowAPI.IS_RETAIL then
        C_QuestLog.PushQuestToParty(questID)
    else
        QuestLogPushQuest()
    end
end
```

- [ ] **Step 2: Replace `GetRaidRosterInfo` wrapper in `Core/WowAPI.lua`**

Current line:
```lua
function SocialQuestWowAPI.GetRaidRosterInfo(index)               return GetRaidRosterInfo(index)               end
```

Replace with:
```lua
function SocialQuestWowAPI.GetRaidRosterInfo(index)
    if SocialQuestWowAPI.IS_RETAIL and C_RaidRoster then
        return C_RaidRoster.GetRaidRosterInfo(index)
    end
    return GetRaidRosterInfo(index)
end
```

- [ ] **Step 3: Add `MAX_QUEST_LOG_ENTRIES` and reference tables to `Core/WowAPI.lua`**

Add after `SocialQuestWowAPI.PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE` (the last existing line):

```lua

SocialQuestWowAPI.MAX_QUEST_LOG_ENTRIES = SocialQuestWowAPI.IS_RETAIL and 35 or 25

-- Reference: WoW numeric race IDs (third return of UnitRace(unit)).
-- Used with the formula 2^(raceID-1) to compute requiredRaces bitmask bits.
SocialQuestWowAPI.RACE_ID = {
    Human=1, Orc=2, Dwarf=3, NightElf=4, Undead=5, Tauren=6, Gnome=7, Troll=8,
    Goblin=9, BloodElf=10, Draenei=11, Worgen=22, Pandaren=24, Nightborne=27,
    HighmountainTauren=28, VoidElf=29, LightforgedDraenei=30, ZandalariTroll=31,
    KulTiran=32, DarkIronDwarf=34, Vulpera=35, MagharOrc=36, Mechagnome=37,
}

-- Reference: WoW numeric class IDs (third return of UnitClass(unit)).
-- Used with the formula 2^(classID-1) to compute requiredClasses bitmask bits.
SocialQuestWowAPI.CLASS_ID = {
    Warrior=1, Paladin=2, Hunter=3, Rogue=4, Priest=5, DeathKnight=6,
    Shaman=7, Mage=8, Warlock=9, Monk=10, Druid=11, DemonHunter=12, Evoker=13,
}
```

- [ ] **Step 4: Fix `QuestLogPushQuest` call site in `UI/Tabs/PartyTab.lua`**

In `buildQuestCallbacks` (line ~509), current:
```lua
                SQWowAPI.QuestLogPushQuest()
```

Replace with:
```lua
                SQWowAPI.QuestLogPushQuest(entry.questID)
```

- [ ] **Step 5: Fix quest-log-full cap in `UI/Tabs/PartyTab.lua`**

In `isEligibleForShare` (line ~125), current:
```lua
    if questCount >= 25 then
```

Replace with:
```lua
    if questCount >= SQWowAPI.MAX_QUEST_LOG_ENTRIES then
```

- [ ] **Step 6: Verify tests pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add Core/WowAPI.lua UI/Tabs/PartyTab.lua
git commit -m "$(cat <<'EOF'
feat: version-aware WowAPI wrappers and MAX_QUEST_LOG_ENTRIES constant

QuestLogPushQuest now accepts questID and routes to C_QuestLog.PushQuestToParty
on Retail. GetRaidRosterInfo routes to C_RaidRoster on Retail. Add
MAX_QUEST_LOG_ENTRIES (35 Retail / 25 others) and RACE_ID/CLASS_ID numeric
reference tables. Update PartyTab call sites to pass questID and use
MAX_QUEST_LOG_ENTRIES for the log-full eligibility check.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: QuestieBridge — C_Timer.After → SQWowAPI.TimerAfter

**Files:**
- Modify: `Core/QuestieBridge.lua`

`local SQWowAPI = SocialQuestWowAPI` is already at line 33. Replace all 9 direct `C_Timer.After` calls. The pattern is identical each time: `C_Timer.After(` → `SQWowAPI.TimerAfter(`.

The 9 occurrences are in `_ScheduleHydration` and `_ScheduleQuestieRequest`:

| Line | Current |
|------|---------|
| 178 | `C_Timer.After(0, function()` |
| 263 | `C_Timer.After(1, function()` |
| 272 | `C_Timer.After(4, function()` |
| 278 | `C_Timer.After(5, function()` |
| 287 | `C_Timer.After(4, function()` |
| 290 | `C_Timer.After(8, function()` |
| 297 | `C_Timer.After(10, function()` |
| 306 | `C_Timer.After(4, function()` |
| 309 | `C_Timer.After(10, function()` |

- [ ] **Step 1: Replace all 9 `C_Timer.After` calls**

Each replacement follows the same pattern. After all edits, no bare `C_Timer.After` should remain in `Core/QuestieBridge.lua`.

Replace line 178:
```lua
    C_Timer.After(0, function()
```
With:
```lua
    SQWowAPI.TimerAfter(0, function()
```

Replace line 263:
```lua
    C_Timer.After(1, function()
```
With:
```lua
    SQWowAPI.TimerAfter(1, function()
```

Replace line 272 (inside the t+1s callback):
```lua
        C_Timer.After(4, function()
```
With:
```lua
        SQWowAPI.TimerAfter(4, function()
```

Replace line 278:
```lua
    C_Timer.After(5, function()
```
With:
```lua
    SQWowAPI.TimerAfter(5, function()
```

Replace line 287 (first hydration inside t+5s callback):
```lua
        C_Timer.After(4, function()
```
With:
```lua
        SQWowAPI.TimerAfter(4, function()
```

Replace line 290 (second hydration inside t+5s callback):
```lua
        C_Timer.After(8, function()
```
With:
```lua
        SQWowAPI.TimerAfter(8, function()
```

Replace line 297:
```lua
    C_Timer.After(10, function()
```
With:
```lua
    SQWowAPI.TimerAfter(10, function()
```

Replace line 306 (first hydration inside t+10s callback):
```lua
        C_Timer.After(4, function()
```
With:
```lua
        SQWowAPI.TimerAfter(4, function()
```

Replace line 309 (second hydration inside t+10s callback):
```lua
        C_Timer.After(10, function()
```
With:
```lua
        SQWowAPI.TimerAfter(10, function()
```

- [ ] **Step 2: Verify no bare `C_Timer.After` remain**

Search `Core/QuestieBridge.lua` for `C_Timer.After` — must return zero matches.

- [ ] **Step 3: Verify tests pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add Core/QuestieBridge.lua
git commit -m "$(cat <<'EOF'
refactor(QuestieBridge): replace all C_Timer.After with SQWowAPI.TimerAfter

All 9 direct C_Timer.After calls in _ScheduleHydration and
_ScheduleQuestieRequest now route through the SQWowAPI abstraction layer,
consistent with the project's single-owner-of-WoW-globals policy.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: TabUtils — SelectChain + BuildEngagedSet Tests + BuildEngagedSet Implementation

**Files:**
- Modify: `tests/TabUtils_test.lua`
- Modify: `UI/TabUtils.lua`

Follow TDD: write failing tests first, then implement, then confirm green.

- [ ] **Step 1: Expand the AQL stub in `tests/TabUtils_test.lua`**

The current AQL stub (lines 22–26):
```lua
local AQL = {
    ChainStatus = { Known = "known", Unknown = "unknown" },
    _questInfoMap = {},
    GetQuestInfo  = function(self, questID) return self._questInfoMap[questID] end,
}
```

Replace with (add two methods before the closing brace):
```lua
local AQL = {
    ChainStatus = { Known = "known", Unknown = "unknown" },
    _questInfoMap = {},
    GetQuestInfo  = function(self, questID) return self._questInfoMap[questID] end,
    _GetCurrentPlayerEngagedQuests = function(self)
        return { [100] = true }
    end,
    SelectBestChain = function(self, chainResult, engaged)
        return chainResult.chains and chainResult.chains[1] or nil
    end,
}
```

- [ ] **Step 2: Add `SelectChain` and `BuildEngagedSet` tests to `tests/TabUtils_test.lua`**

Insert the following before the `print("Results: ...")` footer line at the bottom of the file:

```lua
-- ── SelectChain ───────────────────────────────────────────────────────────────

-- nil chainResult → nil
assert_eq("SelectChain nil result", T.SelectChain(nil, {}), nil)

-- knownStatus != Known → nil
assert_eq("SelectChain unknown status",
    T.SelectChain({ knownStatus = AQL.ChainStatus.Unknown }, {}), nil)

-- AQL 2.x bare ChainInfo (no chains field): returned as-is when knownStatus == Known
local bareCI = { knownStatus = AQL.ChainStatus.Known, chainID = 10, step = 2, length = 5 }
assert_eq("SelectChain bare ChainInfo is returned directly", T.SelectChain(bareCI, {}), bareCI)

-- AQL 3.0+ wrapper with chains array: delegates to AQL:SelectBestChain → chains[1]
local wrappedCI = {
    knownStatus = AQL.ChainStatus.Known,
    chains = { { chainID = 20, step = 1, length = 3 } },
}
local scResult = T.SelectChain(wrappedCI, { [100] = true })
assert_eq("SelectChain wrapper chainID", scResult and scResult.chainID, 20)
assert_eq("SelectChain wrapper step",    scResult and scResult.step,    1)

-- wrapper with empty chains → SelectBestChain returns nil (chains[1] is nil)
local emptyWrapper = { knownStatus = AQL.ChainStatus.Known, chains = {} }
assert_eq("SelectChain wrapper empty chains → nil", T.SelectChain(emptyWrapper, {}), nil)

-- ── BuildEngagedSet ───────────────────────────────────────────────────────────

-- nil playerName → delegates to AQL:_GetCurrentPlayerEngagedQuests → { [100]=true }
local localSet = T.BuildEngagedSet(nil)
assert_true("BuildEngagedSet nil playerName returns local set (quest 100)", localSet[100] == true)

-- playerName not in PlayerQuests → empty set (not nil, safe to iterate)
SocialQuestGroupData.PlayerQuests = {}
local missingSet = T.BuildEngagedSet("NoSuchPlayer")
local missingCount = 0
for _ in pairs(missingSet) do missingCount = missingCount + 1 end
assert_eq("BuildEngagedSet missing player returns empty set", missingCount, 0)

-- player with both quests and completedQuests → union of both
SocialQuestGroupData.PlayerQuests["Alice"] = {
    quests          = { [201] = { questID = 201 }, [202] = { questID = 202 } },
    completedQuests = { [300] = true },
}
local aliceSet = T.BuildEngagedSet("Alice")
assert_true("BuildEngagedSet Alice active quest 201",    aliceSet[201] == true)
assert_true("BuildEngagedSet Alice active quest 202",    aliceSet[202] == true)
assert_true("BuildEngagedSet Alice completed quest 300", aliceSet[300] == true)
assert_eq  ("BuildEngagedSet Alice no stray quest 999",  aliceSet[999], nil)

-- player with only completedQuests (quests field is nil)
SocialQuestGroupData.PlayerQuests["Bob"] = {
    quests          = nil,
    completedQuests = { [400] = true },
}
local bobSet = T.BuildEngagedSet("Bob")
assert_true("BuildEngagedSet Bob completed quest 400", bobSet[400] == true)
local bobCount = 0
for _ in pairs(bobSet) do bobCount = bobCount + 1 end
assert_eq("BuildEngagedSet Bob exactly one entry", bobCount, 1)

-- player with both tables empty → empty set
SocialQuestGroupData.PlayerQuests["Carol"] = {
    quests          = {},
    completedQuests = {},
}
local carolSet = T.BuildEngagedSet("Carol")
local carolCount = 0
for _ in pairs(carolSet) do carolCount = carolCount + 1 end
assert_eq("BuildEngagedSet Carol empty tables → empty set", carolCount, 0)

-- reset shared state so other tests in future runs start clean
SocialQuestGroupData.PlayerQuests = {}
```

- [ ] **Step 3: Run tests — expect `BuildEngagedSet` failures**

```bash
lua tests/TabUtils_test.lua
```

`SelectChain` tests should pass (function already exists). `BuildEngagedSet` tests should fail with "attempt to call nil value" or "attempt to index nil value". Note the failure count — it should equal the number of `BuildEngagedSet` test lines.

- [ ] **Step 4: Implement `BuildEngagedSet` in `UI/TabUtils.lua`**

In `UI/TabUtils.lua`, add after the closing `end` of `SelectChain` and before the `-- Builds objective rows...` comment that precedes `BuildLocalObjectives`:

```lua
-- Builds an engaged quest set (active + completed) for a named player,
-- or the local player when playerName is nil.
-- Returns {} (empty, safe to iterate) when the player is not in PlayerQuests.
function SocialQuestTabUtils.BuildEngagedSet(playerName)
    local AQL = SocialQuest.AQL
    if not playerName then
        return AQL:_GetCurrentPlayerEngagedQuests()
    end
    local pdata = SocialQuestGroupData.PlayerQuests[playerName]
    if not pdata then return {} end
    local engaged = {}
    for qid in pairs(pdata.quests or {}) do engaged[qid] = true end
    for qid in pairs(pdata.completedQuests or {}) do engaged[qid] = true end
    return engaged
end
```

- [ ] **Step 5: Run tests — all must pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add UI/TabUtils.lua tests/TabUtils_test.lua
git commit -m "$(cat <<'EOF'
feat(TabUtils): add BuildEngagedSet helper with full test coverage

BuildEngagedSet(playerName) builds the union of active+completed quests
for a named player, or delegates to AQL:_GetCurrentPlayerEngagedQuests
for the local player (nil arg). Eliminates four copies of the same inline
pattern across MineTab, PartyTab, SharedTab, and Announcements.

Tests cover SelectChain (nil, unknown, AQL 2.x bare, AQL 3.0+ wrapper,
empty chains) and BuildEngagedSet (nil/local, missing player, active+completed
union, nil quests field, empty tables).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Per-Player Engagement Fix — Announcements, SharedTab, MineTab, PartyTab

**Files:**
- Modify: `Core/Announcements.lua`
- Modify: `UI/Tabs/SharedTab.lua`
- Modify: `UI/Tabs/MineTab.lua`
- Modify: `UI/Tabs/PartyTab.lua`

- [ ] **Step 1: Add `sender` param to `appendChainStep` in `Core/Announcements.lua`**

Current definition (line 47):
```lua
local function appendChainStep(msg, eventType, chainResult)
    if not CHAIN_STEP_EVENTS[eventType] then return msg end
    if not chainResult or chainResult.knownStatus ~= SocialQuest.AQL.ChainStatus.Known then
        return msg
    end
    local AQL = SocialQuest.AQL
    local engaged = AQL:_GetCurrentPlayerEngagedQuests()
    local ci = SocialQuestTabUtils.SelectChain(chainResult, engaged)
    if not ci or not ci.step then return msg end
    return msg .. " " .. string.format(L["(Step %s)"], ci.step)
end
```

Replace with:
```lua
local function appendChainStep(msg, eventType, chainResult, sender)
    if not CHAIN_STEP_EVENTS[eventType] then return msg end
    if not chainResult or chainResult.knownStatus ~= SocialQuest.AQL.ChainStatus.Known then
        return msg
    end
    local engaged = SocialQuestTabUtils.BuildEngagedSet(sender)  -- nil = local player
    local ci = SocialQuestTabUtils.SelectChain(chainResult, engaged)
    if not ci or not ci.step then return msg end
    return msg .. " " .. string.format(L["(Step %s)"], ci.step)
end
```

- [ ] **Step 2: Pass `sender` at the remote call site in `Core/Announcements.lua`**

Inside `OnRemoteQuestEvent` (around line 478), the call that already has `sender` in scope:
```lua
        msg = appendChainStep(msg, eventType, chainInfo)
```

Replace with:
```lua
        msg = appendChainStep(msg, eventType, chainInfo, sender)
```

The other two call sites (`OnQuestEvent` ~line 211 and `OnOwnQuestEvent` ~line 541) keep their three-argument form — nil sender correctly uses the local player's engaged set.

- [ ] **Step 3: Replace inline engaged construction in `UI/Tabs/SharedTab.lua` `addEngagement`**

Current block (lines 31–41) inside `addEngagement`:
```lua
        local engaged
        if isLocal then
            engaged = AQL:_GetCurrentPlayerEngagedQuests()
        else
            engaged = {}
            local pd = SocialQuestGroupData.PlayerQuests[playerName]
            if pd then
                for aqid in pairs(pd.completedQuests or {}) do engaged[aqid] = true end
                for aqid in pairs(pd.quests or {}) do engaged[aqid] = true end
            end
        end
```

Replace with:
```lua
        local engaged = SocialQuestTabUtils.BuildEngagedSet(isLocal and nil or playerName)
```

- [ ] **Step 4: Replace inline `pEngaged` in `UI/Tabs/MineTab.lua` cross-chain peer loop**

In the cross-chain peer loop (lines ~79–83), current:
```lua
                        local pEngaged = {}
                        for aqid in pairs(playerData.completedQuests or {}) do pEngaged[aqid] = true end
                        for aqid in pairs(playerData.quests) do pEngaged[aqid] = true end
                        local pCI = SocialQuestTabUtils.SelectChain(pChainResult, pEngaged)
```

Replace with:
```lua
                        local pCI = SocialQuestTabUtils.SelectChain(pChainResult, SocialQuestTabUtils.BuildEngagedSet(playerName))
```

- [ ] **Step 5: Replace inline `pEngaged` in `UI/Tabs/PartyTab.lua` `buildPlayerRowsForQuest`**

In the `elseif hasQuest then` branch (lines ~247–252), current:
```lua
            local pChainResult = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
            local pEngaged = {}
            for aqid in pairs(playerData.completedQuests or {}) do pEngaged[aqid] = true end
            for aqid in pairs(playerData.quests or {}) do pEngaged[aqid] = true end
            local pCI = SocialQuestTabUtils.SelectChain(pChainResult, pEngaged)
```

Replace with:
```lua
            local pChainResult = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
            local pCI = SocialQuestTabUtils.SelectChain(pChainResult, SocialQuestTabUtils.BuildEngagedSet(playerName))
```

- [ ] **Step 6: Verify tests pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add Core/Announcements.lua UI/Tabs/SharedTab.lua UI/Tabs/MineTab.lua UI/Tabs/PartyTab.lua
git commit -m "$(cat <<'EOF'
fix: use per-player engaged set for SelectChain across all call sites

appendChainStep now accepts an optional sender param and calls
BuildEngagedSet(sender) so remote banners show that player's own chain
step rather than the local player's. SharedTab addEngagement,
MineTab cross-chain peer loop, and PartyTab buildPlayerRowsForQuest
all replace their inline engaged-set construction with BuildEngagedSet.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: PartyTab Race/Class Eligibility Fix

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

Remove the `RACE_BITS` and `CLASS_BITS` lookup tables and replace both eligibility checks with the numeric formula `2^(id-1)`, using the third return value of `UnitRace`/`UnitClass`.

Formula correctness for TBC races: Human(1)→1, Orc(2)→2, Dwarf(3)→4, NightElf(4)→8, Undead(5)→16, Tauren(6)→32, Gnome(7)→64, Troll(8)→128, BloodElf(10)→512, Draenei(11)→1024. Identical to the old table values.

- [ ] **Step 1: Delete the `RACE_BITS` table (lines 10–29)**

Delete from the opening comment through the closing `}`:
```lua
-- Maps UnitRace() second return value (English race string) to Questie requiredRaces bitmask bits.
-- "Scourge" is the English race file name for Undead in TBC.
-- Goblin (256) included as a stub: follows the sequential raceKeys pattern (index 9 → bit 256).
-- Post-Cataclysm allied races (Worgen, Pandaren, Nightborne, etc.) are intentionally absent:
-- their bitmask values in the retail Questie DB are non-contiguous and unverified — including
-- wrong values would produce incorrect eligibility results. Add them when retail support is
-- implemented and the values are confirmed. Missing entries are gracefully skipped (nil check).
local RACE_BITS = {
    ["Human"]    = 1,
    ["Orc"]      = 2,
    ["Dwarf"]    = 4,
    ["NightElf"] = 8,
    ["Scourge"]  = 16,   -- UnitRace returns "Scourge" for Undead
    ["Tauren"]   = 32,
    ["Gnome"]    = 64,
    ["Troll"]    = 128,
    ["Goblin"]   = 256,  -- Cataclysm; stub for future retail support
    ["BloodElf"] = 512,
    ["Draenei"]  = 1024,
}
```

- [ ] **Step 2: Delete the `CLASS_BITS` table (lines 31–48 after Step 1)**

Delete the entire block:
```lua
-- Maps UnitClass() second return value (English class token) to Questie requiredClasses bitmask bits.
-- All 13 classes included. DK/Monk/DemonHunter/Evoker are stubs for future retail support:
-- UnitClass never returns their tokens in TBC so these entries are unreachable and harmless.
local CLASS_BITS = {
    ["WARRIOR"]     = 1,
    ["PALADIN"]     = 2,
    ["HUNTER"]      = 4,
    ["ROGUE"]       = 8,
    ["PRIEST"]      = 16,
    ["DEATHKNIGHT"] = 32,    -- WotLK; stub for retail support
    ["SHAMAN"]      = 64,
    ["MAGE"]        = 128,
    ["WARLOCK"]     = 256,
    ["MONK"]        = 512,   -- MoP; stub for retail support
    ["DRUID"]       = 1024,
    ["DEMONHUNTER"] = 2048,  -- Legion; stub for retail support
    ["EVOKER"]      = 4096,  -- Dragonflight; stub for retail support
}
```

- [ ] **Step 3: Replace Check 2 (race) in `isEligibleForShare`**

Current block:
```lua
        -- Check 2: wrong race.
        if reqs and reqs.requiredRaces then
            local _, raceEn = SQWowAPI.UnitRace(unitToken)
            local raceBit = raceEn and RACE_BITS[raceEn]
            if raceBit and bit.band(reqs.requiredRaces, raceBit) == 0 then
                return { eligible = false, reason = { code = "wrong_race" } }
            end
        end
```

Replace with:
```lua
        -- Check 2: wrong race.
        -- UnitRace returns (localizedName, englishName, raceID). The numeric raceID
        -- maps to Questie's requiredRaces bitmask via bit position 2^(raceID-1).
        if reqs and reqs.requiredRaces then
            local raceId = select(3, SQWowAPI.UnitRace(unitToken))
            if raceId and bit.band(reqs.requiredRaces, 2 ^ (raceId - 1)) == 0 then
                return { eligible = false, reason = { code = "wrong_race" } }
            end
        end
```

- [ ] **Step 4: Replace Check 3 (class) in `isEligibleForShare`**

Current block:
```lua
        -- Check 3: wrong class.
        -- CLASS_BITS includes all retail classes as stubs; DK/Monk/DH/Evoker never
        -- match in TBC since UnitClass never returns those tokens there.
        if reqs and reqs.requiredClasses then
            local _, classToken = SQWowAPI.UnitClass(unitToken)
            local classBit = classToken and CLASS_BITS[classToken]
            if classBit and bit.band(reqs.requiredClasses, classBit) == 0 then
                return { eligible = false, reason = { code = "wrong_class" } }
            end
        end
```

Replace with:
```lua
        -- Check 3: wrong class.
        -- UnitClass returns (localizedName, classToken, classID). The numeric classID
        -- maps to Questie's requiredClasses bitmask via bit position 2^(classID-1).
        if reqs and reqs.requiredClasses then
            local classId = select(3, SQWowAPI.UnitClass(unitToken))
            if classId and bit.band(reqs.requiredClasses, 2 ^ (classId - 1)) == 0 then
                return { eligible = false, reason = { code = "wrong_class" } }
            end
        end
```

- [ ] **Step 5: Verify tests pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "$(cat <<'EOF'
refactor(PartyTab): replace RACE_BITS/CLASS_BITS tables with 2^(id-1) formula

Remove RACE_BITS and CLASS_BITS lookup tables. Race/class eligibility now
uses the numeric raceID/classID (third return from UnitRace/UnitClass) with
the formula 2^(id-1) to compute the bitmask position. Correct for all WoW
versions including Retail allied races; no table maintenance required.
Behavior is identical for all TBC races/classes.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Tooltip Retail Hook

**Files:**
- Modify: `UI/Tooltips.lua`

- [ ] **Step 1: Replace `SocialQuestTooltips:Initialize` in `UI/Tooltips.lua`**

Current implementation (lines 53–63):
```lua
function SocialQuestTooltips:Initialize()
    -- Hook the quest hyperlink tooltip.
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

Replace with:
```lua
function SocialQuestTooltips:Initialize()
    if SocialQuestWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        -- Retail: use the native tooltip data processor API.
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )
    else
        -- TBC / Classic / Mists: hook SetHyperlink on ItemRefTooltip.
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local questID = tonumber(link:match("quest:(%d+)"))
            if questID then
                addGroupProgressToTooltip(self, questID)
            end
        end)
    end
end
```

- [ ] **Step 2: Verify tests pass**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 3: Commit**

```bash
git add UI/Tooltips.lua
git commit -m "$(cat <<'EOF'
feat(Tooltips): add Retail TooltipDataProcessor branch for quest tooltip hook

On IS_RETAIL, use TooltipDataProcessor.AddTooltipPostCall with
Enum.TooltipDataType.Quest. Falls back to hooksecurefunc(ItemRefTooltip,
"SetHyperlink") on TBC/Classic/Mists. Both paths call the same
addGroupProgressToTooltip function.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Docs + Version Bump

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `SocialQuest_Classic.toc`
- Modify: `SocialQuest_Mists.toc`
- Modify: `SocialQuest_Mainline.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Bump version to 2.17.0 in all four TOC files**

In each of `SocialQuest.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`, `SocialQuest_Mainline.toc`, change:
```
## Version: 2.16.0
```
To:
```
## Version: 2.17.0
```

- [ ] **Step 2: Add version history entry to `CLAUDE.md`**

Insert the following at the top of the Version History section (before `### Version 2.16.0`):

```markdown
### Version 2.17.0 (March 2026 — Improvements branch)
- Feature: Multi-version WoW support infrastructure. `Core/WowAPI.lua` now derives `IS_CLASSIC_ERA`, `IS_TBC`, `IS_MOP`, `IS_RETAIL` booleans from `GetBuildInfo()` at load time. Three companion TOC files added: `SocialQuest_Classic.toc` (Interface 11508), `SocialQuest_Mists.toc` (Interface 50503), `SocialQuest_Mainline.toc` (Interface 120001). `QuestLogPushQuest` routes to `C_QuestLog.PushQuestToParty(questID)` on Retail; call site updated to pass `entry.questID`. `GetRaidRosterInfo` routes to `C_RaidRoster.GetRaidRosterInfo` on Retail. `MAX_QUEST_LOG_ENTRIES` constant (35 Retail / 25 others) replaces hardcoded `25` in the quest-log-full check. `RACE_ID` and `CLASS_ID` numeric reference tables added for documentation purposes.
- Refactor: `RACE_BITS` and `CLASS_BITS` lookup tables removed from `PartyTab.lua`. Race/class eligibility now uses the numeric raceID/classID (third return from `UnitRace`/`UnitClass`) with `2^(id-1)` — correct for all WoW versions and Retail allied races, no maintenance required.
- Refactor: `SocialQuestTabUtils.BuildEngagedSet(playerName)` consolidates four copies of the inline engaged-set construction pattern across `MineTab.lua`, `PartyTab.lua`, `SharedTab.lua`, and `Announcements.lua`. `appendChainStep` in `Announcements.lua` now accepts an optional `sender` parameter so remote quest banners show the sender's own chain step.
- Refactor: All 9 direct `C_Timer.After` calls in `Core/QuestieBridge.lua` replaced with `SQWowAPI.TimerAfter`, consistent with the single-owner-of-WoW-globals policy.
- Feature: Retail tooltip hook. `UI/Tooltips.lua` `Initialize` uses `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Quest, ...)` on Retail; falls back to `hooksecurefunc(ItemRefTooltip, "SetHyperlink")` on all other versions.
```

- [ ] **Step 3: Final test run**

```bash
lua tests/TabUtils_test.lua
lua tests/FilterParser_test.lua
```

Both must report `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.toc SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc CLAUDE.md
git commit -m "$(cat <<'EOF'
chore: bump to 2.17.0 and document multi-version support changes

Increment version across all four TOC files. Add Version 2.17.0 history
entry to CLAUDE.md covering version detection constants, companion TOCs,
API wrapper changes, BuildEngagedSet, RACE_BITS/CLASS_BITS removal,
QuestieBridge timer cleanup, and Retail tooltip hook.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Implementation Notes

**`BuildEngagedSet` nil-safety:** Guards `pdata.quests` and `pdata.completedQuests` with `or {}` before iterating. Handles the stub case `{ hasSocialQuest=false, completedQuests={} }` where `quests` is nil. Returns `{}` (not nil) for unknown players — safe to pass to `SelectChain` → `SelectBestChain`.

**`appendChainStep` call sites:** Only the remote call site in `OnRemoteQuestEvent` passes `sender`. The local outbound (`OnQuestEvent` ~line 211) and own-quest (`OnOwnQuestEvent` ~line 541) call sites keep three arguments — nil sender correctly uses the local player's engaged set.

**Race/class formula equivalence for TBC:**

| Race | ID | `2^(id-1)` | Old `RACE_BITS` |
|---|---|---|---|
| Human | 1 | 1 | 1 |
| Orc | 2 | 2 | 2 |
| Dwarf | 3 | 4 | 4 |
| NightElf | 4 | 8 | 8 |
| Undead | 5 | 16 | 16 |
| Tauren | 6 | 32 | 32 |
| Gnome | 7 | 64 | 64 |
| Troll | 8 | 128 | 128 |
| BloodElf | 10 | 512 | 512 |
| Draenei | 11 | 1024 | 1024 |

Identical for all TBC-playable races. The old `Goblin=256` stub (raceID 9 → `2^8=256`) also matches.

**`C_Timer.After` in `Core/WowAPI.lua`:** The `TimerAfter` wrapper itself uses `C_Timer.After` — this is the single permitted owner, intentional and correct.

**`LE_PARTY_CATEGORY_HOME` on Retail:** These globals may behave differently on Retail. This is pre-existing and out of scope for this plan.
