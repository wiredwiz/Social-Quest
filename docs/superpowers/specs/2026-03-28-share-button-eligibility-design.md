# One-Click Quest Share Button & Share Eligibility Design

**Date:** 2026-03-28
**Feature:** SocialQuest Feature #6 (revised)
**Status:** Approved

---

## Goal

Add a `[Share]` button to quest rows in the Party tab so players can share quests without leaving the SQ window. Simultaneously tighten the shareability logic so that party members who cannot receive a quest are shown with a specific reason rather than the misleading "Needs it Shared" label.

---

## Background & Problem Statement

The current `isEligibleForShare` check in `PartyTab.lua` covers three cases: the WoW shareability flag, whether the player already completed the quest, and whether the chain prerequisite is met. In practice, many other conditions can make a player ineligible — wrong level, wrong race/class, full quest log, exclusive quest completed, already past the chain step, prereq not done. These cause "Needs it Shared" to appear even when a share attempt would silently fail, which frustrates the sharing player.

---

## Decisions Made

| Question | Decision |
|---|---|
| Where does the `[Share]` button live? | Party tab, on the quest title row |
| Shares per-player or broadcast? | Broadcast — `QuestLogPushQuest()` shares with all at once; the button is on the quest row, not each player row |
| What shows for ineligible players? | Their name with a specific reason label (e.g. "level too low", "needs: [Quest Name]") |
| Where does eligibility logic live? | SocialQuest (`PartyTab.lua`) — it crosses player boundaries and depends on SQ's synced `PlayerQuests` data |
| Where does quest requirements data come from? | AQL via new `AQL:GetQuestRequirements(questID)` — AQL remains the single choke-point that knows about Questie internals; SQ never accesses QuestieDB directly |
| Graceful degradation without Questie? | Tier-1 checks (race, class, level, cap) always run. Tier-2 checks (prereqs, exclusives, chain) run only when a provider is available. Without provider, if tier-1 passes, player is considered eligible. |
| Future-proofing? | When QuestieDB is bundled into AQL, `GetQuestRequirements` will always return data and all checks will be active. The nil fallback is a temporary degradation path, not a permanent design concern. No API changes needed at that point. |

---

## Architecture

### Two-stage implementation

**Stage 1 — AQL:** Add `AQL:GetQuestRequirements(questID)` public method and corresponding provider implementations. No changes to existing AQL APIs.

**Stage 2 — SQ:** Replace `isEligibleForShare` with a full eligibility check function, update `buildPlayerRowsForQuest` to store reasons, update rendering in `RowFactory`, add locale strings.

### Data flow

```
PartyTab.buildPlayerRowsForQuest(questID)
  └─ for each party member in PlayerQuests:
       ├─ resolveUnitToken(playerName)      → "party1".."party4" or nil
       ├─ UnitLevel/Race/Class(unitToken)   → player stats (nil when token not found)
       ├─ playerData.completedQuests        → completed quest history
       ├─ playerData.quests                 → active quest IDs
       └─ isEligibleForShare(questID, playerData, unitToken)
            ├─ AQL:IsQuestIdShareable(questID)      [always]
            ├─ AQL:GetQuestRequirements(questID)    [provider-backed]
            └─ returns { eligible=bool, reason={code, questID?} or nil }
```

---

## AQL Changes (Stage 1)

### New public method

```lua
-- AbsoluteQuestLog.lua
-- Returns provider-backed quest requirements, or nil if no provider is available.
-- Designed to always return data once QuestieDB is bundled into AQL.
-- All field names are confirmed against tbcQuestDB.lua questKeys table.
function AQL:GetQuestRequirements(questID)
```

**Return shape:**
```lua
{
  requiredLevel        = N or nil,               -- questKeys[4]
  requiredMaxLevel     = N or nil,               -- questKeys[32]
  requiredRaces        = N or nil,               -- questKeys[6],  bitmask
  requiredClasses      = N or nil,               -- questKeys[7],  bitmask
  preQuestGroup        = { questID, ... } or nil, -- questKeys[12], ALL must be complete
  preQuestSingle       = { questID, ... } or nil, -- questKeys[13], ANY ONE must be complete
  exclusiveTo          = { questID, ... } or nil, -- questKeys[16]
  nextQuestInChain     = questID or nil,          -- questKeys[22]
  breadcrumbForQuestId = questID or nil,          -- questKeys[27]
}
-- Returns nil when no provider is available (NullProvider active).
```

All field names above are confirmed against the TBC questKeys definition in `tbcQuestDB.lua`.

### Provider interface

`Providers/Provider.lua` — add `GetQuestRequirements(questID)` to the interface contract (documentation only, no runtime code).

### Provider implementations

| Provider | Behaviour |
|---|---|
| `QuestieProvider` | Calls `QuestieDB.QueryQuestSingle(questID, fieldName)` for each field. Returns nil for any field where the DB entry has no value (0 or nil). `nextQuestInChain = 0` is normalised to nil. |
| `QuestWeaverProvider` | Returns what QuestWeaver exposes; nil for unsupported fields. |
| `NullProvider` | Returns nil (method returns nil, not a table). |

### Race bitmask (confirmed against `QuestieDB.raceKeys` in TBC)

| Race | Bit | In TBC? |
|---|---|---|
| Human | 1 | Yes |
| Orc | 2 | Yes |
| Dwarf | 4 | Yes |
| Night Elf | 8 | Yes |
| Undead | 16 | Yes |
| Tauren | 32 | Yes |
| Gnome | 64 | Yes |
| Troll | 128 | Yes |
| Goblin | 256 | No (Cataclysm) |
| Blood Elf | 512 | Yes |
| Draenei | 1024 | Yes |

`requiredRaces = 0` (NONE) means no restriction — all races pass. Check is skipped when value is 0 or nil.

Goblin (256) follows the sequential Questie raceKeys pattern (bit = 1 << (index-1), index 9). Post-Cataclysm allied races (Worgen, Pandaren, Nightborne, Highmountain Tauren, Void Elf, Lightforged Draenei, Zandalari Troll, Kul Tiran, Dark Iron Dwarf, Mag'har Orc, Mechagnome, Vulpera, Dracthyr) are **not** included in `RACE_BITS`. Their bitmask values in the retail Questie DB are not sequential from index 12 onward (WoW race IDs for these races are non-contiguous), and including wrong values would cause incorrect eligibility results. These entries should be added when retail support is implemented and the values are verified against the retail Questie DB. A missing entry gracefully falls through (check skipped, player treated as eligible — same behavior as the nil-provider path).

### Class bitmask (confirmed against `QuestieDB.classKeys`)

| Class | Bit | In TBC? |
|---|---|---|
| Warrior | 1 | Yes |
| Paladin | 2 | Yes |
| Hunter | 4 | Yes |
| Rogue | 8 | Yes |
| Priest | 16 | Yes |
| Death Knight | 32 | No (WotLK) |
| Shaman | 64 | Yes |
| Mage | 128 | Yes |
| Warlock | 256 | Yes |
| Monk | 512 | No (MoP) |
| Druid | 1024 | Yes |
| Demon Hunter | 2048 | No (Legion) |
| Evoker | 4096 | No (Dragonflight) |

`requiredClasses = 0` (NONE) means no restriction — all classes pass. Check is skipped when value is 0 or nil.

All 13 classes are included in the `CLASS_BITS` lookup table in `PartyTab.lua` as stubs for future retail support. In TBC, `UnitClass` will never return `"DEATHKNIGHT"`, `"MONK"`, `"DEMONHUNTER"`, or `"EVOKER"` — those entries are unreachable and harmless.

---

## SQ Changes (Stage 2)

### Files modified

| File | Changes |
|---|---|
| `UI/Tabs/PartyTab.lua` | Replace `isEligibleForShare`, add `resolveUnitToken`, update `buildPlayerRowsForQuest`, update `Render` |
| `UI/RowFactory.lua` | `AddQuestRow` renders `[Share]` button; `AddPlayerRow` renders reason string; update `AddQuestRow` doc comment to include `onShare` |
| `Core/WowAPI.lua` | Add `SQWowAPI.QuestLogPushQuest()`, `SQWowAPI.UnitLevel(unit)`, `SQWowAPI.UnitRace(unit)`, `SQWowAPI.UnitClass(unit)`, `SQWowAPI.UnitName(unit)` wrappers |
| `Locales/enUS.lua` | New reason locale keys |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | Translated reason strings (11 files) |

### `isEligibleForShare(questID, playerData, unitToken)`

Private function in `PartyTab.lua`. Returns `{ eligible=true }` or `{ eligible=false, reason={code=string, questID=N?} }`.

This function is only called from the `localHasIt == true` branch of `buildPlayerRowsForQuest` — players who already have the quest or have completed it are handled by separate branches before this function is ever reached, so checks for those states are not needed here.

**Check sequence (first failure wins):**

| # | Check | Tier | Data source | Reason code |
|---|---|---|---|---|
| 1 | `AQL:IsQuestIdShareable(questID)` returns false | Always | AQL | *(quest not shareable — see note below)* |
| 2 | `reqs.requiredRaces ~= 0` and player race bit not set | Always | `reqs` + `UnitRace(unitToken)` | `"wrong_race"` |
| 3 | `reqs.requiredClasses ~= 0` and player class bit not set | Always | `reqs` + `UnitClass(unitToken)` | `"wrong_class"` |
| 4 | `reqs.requiredLevel` and `UnitLevel(unitToken) < reqs.requiredLevel` | Always | `reqs` + `UnitLevel(unitToken)` | `"level_too_low"` |
| 5 | `reqs.requiredMaxLevel > 0` and `UnitLevel(unitToken) > reqs.requiredMaxLevel` | Always | `reqs` + `UnitLevel(unitToken)` | `"level_too_high"` |
| 6 | `count(playerData.quests) >= 25` | Always | `playerData` | `"quest_log_full"` |
| 7 | Any `reqs.exclusiveTo` questID in `playerData.completedQuests` | Provider | `reqs` + `playerData` | `"exclusive_quest"` |
| 8 | `reqs.nextQuestInChain` is in `playerData.quests` or `playerData.completedQuests` | Provider | `reqs` + `playerData` | `"already_advanced"` |
| 9 | `reqs.preQuestGroup` — any required questID not in `playerData.completedQuests` | Provider | `reqs` + `playerData` | `"needs_quest"` + questID |
| 10 | `reqs.preQuestSingle` — none of the questIDs in `playerData.completedQuests` | Provider | `reqs` + `playerData` | `"needs_quest"` + first questID |
| 11 | `reqs.breadcrumbForQuestId` is in `playerData.quests` or `playerData.completedQuests` | Provider | `reqs` + `playerData` | `"already_advanced"` |

**Check 1 scope:** Check 1 is evaluated once per quest in `buildPlayerRowsForQuest`, before the party member loop. If it fails, the entire `localHasIt` branch is skipped for all members — none of them will have `needsShare=true` or an `ineligReason`. Players who already have the quest or have completed it are still rendered normally via the `hasQuest` and `hasCompleted` branches, which are independent of shareability.

**Checks 2–5 when `unitToken` is nil:** When `resolveUnitToken` returns nil (player offline or not matched), level/race/class are unavailable and checks 2–5 are skipped. This means an offline player with an incompatible race or class will appear as eligible rather than blocked. This is the accepted trade-off: silently excluding offline players from share eligibility would suppress the share button incorrectly in some cases and provide no actionable information. The WoW client's own sharing logic handles the final ineligibility decision when the share broadcast is received.

**Checks 7–11 when `reqs` is nil:** When `AQL:GetQuestRequirements` returns nil (no provider), checks 7–11 are skipped entirely. If checks 1–6 all pass, `{ eligible=true }` is returned. This is the same graceful degradation pattern used throughout AQL.

### `resolveUnitToken(playerName)`

Private helper in `PartyTab.lua`. Scans `"party1"`–`"party4"`, compares `UnitName(token)` against `playerName` with realm-suffix normalisation (strip `-RealmName` suffix for same-realm matching — same pattern used elsewhere in SQ for Questie bridge name normalisation). Returns the unit token string or `nil` if no match found.

### `buildPlayerRowsForQuest` changes

The existing single `isEligibleForShare` boolean is expanded. The `localHasIt` branch now stores both the eligibility boolean and the reason:

```lua
-- Before:
needsShare = isEligibleForShare(questID, playerData)

-- After:
local shareable = AQL:IsQuestIdShareable(questID)  -- evaluated once, outside member loop
-- ...
local eligResult = shareable and isEligibleForShare(questID, playerData, resolveUnitToken(playerName))
                              or { eligible = false }
needsShare   = eligResult.eligible
ineligReason = eligResult.reason   -- nil when eligible or quest not shareable
```

Both `needsShare` and `ineligReason` are stored in the playerEntry table. These fields are private to the rendering pipeline — only `RowFactory.AddPlayerRow` reads them. No external module accesses playerEntry fields directly.

### `[Share]` button in `AddQuestRow`

`AddQuestRow` gains a new optional callback: `callbacks.onShare = function()`. When present:
- A `[Share]` button is rendered right-aligned, to the left of the existing badge.
- `titleWidth` shrinks by 52px to accommodate the button.
- On click: verify `AQL:IsQuestIdShareable(questID)` as a safety check, save current selection via `AQL:GetQuestLogSelection()`, select the quest via `AQL:SetQuestLogSelection(logIndex)`, call `SQWowAPI.QuestLogPushQuest()`, restore previous selection.
- `SQWowAPI.QuestLogPushQuest()` is a new wrapper added to `Core/WowAPI.lua`, following the project convention that all WoW API calls route through `SQWowAPI`.
- All unit API calls in `resolveUnitToken` and `isEligibleForShare` (`UnitName`, `UnitLevel`, `UnitRace`, `UnitClass`) are called through `SQWowAPI` wrappers, also added to `Core/WowAPI.lua` in Stage 2. This ensures future retail/Classic edition compatibility — version-specific branching lives in one place.
- The button does not vanish immediately after clicking. The window refreshes naturally when party members accept (their `UNIT_QUEST_LOG_CHANGED` fires and SQ rebuilds the tab).
- The `AddQuestRow` function doc comment is updated to include `callbacks.onShare`.

`PartyTab:Render()` passes `callbacks.onShare` only when all three conditions hold:
1. The local player has the quest (`entry.logIndex ~= nil`).
2. `AQL:IsQuestIdShareable(questID)` returns true.
3. At least one party member playerEntry has `needsShare = true`.

### Ineligible player row rendering

`AddPlayerRow` current and new behaviour:

- `needsShare = true` → unchanged: grey "PlayerName `[Needs it Shared]`"
- `needsShare = false` and `ineligReason ~= nil` → muted amber: "PlayerName `[reason]`"
  - `ineligReason.code == "needs_quest"` → `"needs: " .. (AQL:GetQuestTitle(ineligReason.questID) or "?")`
  - All other codes → `L["share.reason." .. ineligReason.code]`
- `needsShare = false` and `ineligReason == nil` → player not shown in the `localHasIt` branch (they either have the quest, completed it, or the quest is not shareable — handled by other branches)

---

## Locale Keys

New keys added to all 12 locale files (enUS + 11 non-English).

**Translation standard:** Translations must use natural, game-appropriate phrasing that matches how players actually speak in that language — not literal word-for-word translations of the English. Use the same in-game terminology WoW itself uses in that locale (e.g. the word for "quest log", class names, "level"). The goal is that a native-language player reading the reason label would find it immediately recognizable, not like a machine translation. This is the same standard applied to all SocialQuest locale strings in v2.12.30.

| Key | enUS value |
|---|---|
| `"share.reason.level_too_low"` | `"level too low"` |
| `"share.reason.level_too_high"` | `"level too high"` |
| `"share.reason.wrong_race"` | `"wrong race"` |
| `"share.reason.wrong_class"` | `"wrong class"` |
| `"share.reason.quest_log_full"` | `"quest log full"` |
| `"share.reason.exclusive_quest"` | `"took exclusive quest"` |
| `"share.reason.already_advanced"` | `"already past this quest"` |

The `"needs_quest"` reason is formatted dynamically as `"needs: " .. questTitle` and does not use a locale key for the reason string itself. The title is resolved via `AQL:GetQuestTitle(ineligReason.questID)`.

---

## What Does Not Change

- The `[?]` Wowhead link button and shift-click tracking remain unchanged in `AddQuestRow`.
- The Mine tab is not modified — no share button or eligibility rows there.
- The Shared tab is not modified.
- The communications protocol is not modified — no new sync data.
- The existing `isEligibleForShare` in `PartyTab.lua` is replaced in-place; the function is private and has no callers outside that file.

---

## Future-Proofing Note

When QuestieDB is bundled into AQL, `GetQuestRequirements` will always return non-nil data and all 11 checks will always be active. The `if not reqs then return { eligible=true } end` guard in SQ is a one-liner temporary degradation path. No API changes are required in AQL or SQ at that point — the provider system handles it transparently.
