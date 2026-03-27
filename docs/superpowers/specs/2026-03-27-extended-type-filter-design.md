# Extended Type Filter Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend the `type` filter to support independent multi-predicate matching across all three tabs, adding AQL-based quest types and objective-based types alongside the existing chain/group/timed/solo values.

**Architecture:** Replace the single-value `mapType()` priority chain with a `MatchesTypeFilter(entry, descriptor)` helper in TabUtils that checks each type value as an independent predicate. Each type value is a boolean check so a quest can match multiple type values simultaneously (e.g. `type=chain` AND `type=dungeon` both match a chain dungeon quest). Extend the filter to Mine, Party, and Shared tabs.

**Tech Stack:** Lua, AceDB, AQL (AbsoluteQuestLog), Questie/QuestWeaver provider

---

## Background

The current `type` filter uses a priority-chain `mapType()` in MineTab that returns exactly one value per quest (`chain > group > timed > solo`). This prevents a quest from matching multiple type values simultaneously.

`ft[canonical] = entry.descriptor` in `GroupFrame.lua:Refresh()` means `ft.type` is the raw `{ op = "=" | "!=", value = canonicalString }` descriptor — matching the signature of the existing `MatchesEnumFilter(value, descriptor)` helpers.

AQL exposes `quest.type` (populated by Questie or QuestWeaver from their static quest databases) with values: `normal`, `elite`, `dungeon`, `raid`, `daily`, `pvp`, `escort`. WoW quest objectives carry `obj.type` (`"monster"`, `"item"`, `"object"`, `"event"`, `"log"`). Both are available as **local static lookups by questID** via `AQL:GetQuestInfo(questID)` — independent of what addons the remote party member has installed.

---

## Type Values — Complete Predicate Table

| Value | Predicate | Notes |
|---|---|---|
| `chain` | chainInfo present and `knownStatus == AQL.ChainStatus.Known` | Via `AQL:GetQuestInfo()` |
| `group` | `suggestedGroup >= 2` | From entry or AQL |
| `timed` | `timerSeconds > 0` | From entry or AQL |
| `solo` | `suggestedGroup <= 1` | Positive predicate — a chain solo quest matches both `chain` and `solo` |
| `escort` | `aqlInfo.type == "escort"` | Via `AQL:GetQuestInfo()` |
| `dungeon` | `aqlInfo.type == "dungeon"` | Via `AQL:GetQuestInfo()` |
| `raid` | `aqlInfo.type == "raid"` | Via `AQL:GetQuestInfo()` |
| `elite` | `aqlInfo.type == "elite"` | Via `AQL:GetQuestInfo()` |
| `daily` | `aqlInfo.type == "daily"` | Via `AQL:GetQuestInfo()` |
| `pvp` | `aqlInfo.type == "pvp"` | Via `AQL:GetQuestInfo()` |
| `kill` | any `obj.type == "monster"` in objectives | "at least one kill objective" |
| `gather` | any `obj.type == "item"` in objectives | "at least one gather objective" |
| `interact` | any `obj.type == "object"` in objectives | "at least one interact objective" |

`!=` operator is supported on all values: `type!=dungeon` inverts the predicate result, same as all other enum filters.

For objective-based types (`kill`, `gather`, `interact`): a quest with mixed objectives (kill 5 + collect 3) matches both `type=kill` and `type=gather`. This is intentional and documented in the help text.

Type filters require **the Questie or QuestWeaver add-on to be installed**. Without either, `AQL:GetQuestInfo()` returns nil and type predicates silently never match.

---

## Scope

All three tabs: **Mine, Party, Shared.**

### Mine tab
`entry` from `AQL:GetAllQuests()` is fully enriched. `entry.suggestedGroup`, `entry.timerSeconds`, `entry.chainInfo`, `entry.type`, and `entry.objectives[i].type` are all directly available. Call `AQL:GetQuestInfo(entry.questID)` for the predicates that need it (chain, AQL types, objectives).

### Party and Shared tabs
Remote entries in `PlayerQuests[name].quests[questID]` carry `questID`, `title`, `isComplete`, `isFailed`, `timerSeconds`, `objectives` (counts only — no `obj.type`). They do **not** carry `suggestedGroup`, `type`, `chainInfo`, or objective types.

In the current Party/Shared BuildTree implementations, `suggestedGroup` and `timerSeconds` are already read from `localInfo = AQL:GetQuest(questID)` (the local player's AQL cache), **not** from the wire entry. When the local player does not have that quest (`localInfo == nil`), these default to `0` / `nil`. This existing limitation applies to the `group`, `timed`, and `solo` predicates for remote-only quests.

For all AQL-based predicates (chain, escort, dungeon, etc.) and objective-type predicates (kill, gather, interact): call `AQL:GetQuestInfo(entry.questID)` — this is a local static lookup from the Questie/QuestWeaver quest DB, returning data for any questID regardless of whether the local player has that quest.

**Performance:** `AQL:GetQuestInfo()` hits the local cache (Tier 1) for the player's active quests, or falls through to the Questie/QuestWeaver static DB (Tier 3). Called at most once per visible quest row per Refresh. The objective loop is O(objectives) — typically 1–5 items.

---

## Implementation Changes

### 1. `UI/GroupFrame.lua` — `buildKeyDefs()`

Expand the `type` enumMap with 9 new values using the existing `filter.val.*` locale key convention:

```lua
{ canonical="type", names={L["filter.key.type"]}, type="enum",
  descKey="filter.key.type.desc",    -- key name unchanged; locale value updated in Step 5
  enumMap={
    -- existing
    [L["filter.val.chain"]]  = "chain",  [L["filter.val.group"]]   = "group",
    [L["filter.val.solo"]]   = "solo",   [L["filter.val.timed"]]   = "timed",
    -- AQL-based (new)
    [L["filter.val.escort"]] = "escort", [L["filter.val.dungeon"]] = "dungeon",
    [L["filter.val.raid"]]   = "raid",   [L["filter.val.elite"]]   = "elite",
    [L["filter.val.daily"]]  = "daily",  [L["filter.val.pvp"]]     = "pvp",
    -- objective-based (new)
    [L["filter.val.kill"]]   = "kill",   [L["filter.val.gather"]]  = "gather",
    [L["filter.val.interact"]]= "interact",
  }
}
```

### 2. `UI/TabUtils.lua` — new `MatchesTypeFilter(entry, descriptor)`

Add a new helper alongside `MatchesEnumFilter`. It takes `entry` (a quest entry from any tab) and `descriptor` (the raw `{ op, value }` from `ft.type` — same shape as all other filter descriptors). Returns true if the quest matches.

`group`, `timed`, `solo`, and `chain` read directly from `entry` fields — no AQL call needed. `AQL:GetQuestInfo()` is called only for AQL-type predicates (escort, dungeon, etc.) and objective predicates (kill, gather, interact).

The return uses an explicit `if/else` rather than `and/or` to avoid the Lua ternary pitfall where `a and false or c` returns `c` instead of `false`.

```lua
function SocialQuestTabUtils.MatchesTypeFilter(entry, descriptor)
    if not descriptor then return true end
    local value = descriptor.value
    local matched

    -- group/timed/solo/chain: read from entry fields directly (no AQL call needed).
    -- suggestedGroup and timerSeconds are denormalized onto every entry by each tab's
    -- BuildTree; chainInfo is populated from GetChainInfoForQuestID by each tab.
    if value == "group" then
        matched = (entry.suggestedGroup or 0) >= 2
    elseif value == "solo" then
        matched = (entry.suggestedGroup or 0) <= 1
    elseif value == "timed" then
        matched = (entry.timerSeconds or 0) > 0
    elseif value == "chain" then
        matched = entry.chainInfo ~= nil
            and entry.chainInfo.knownStatus == SocialQuest.AQL.ChainStatus.Known
    else
        -- AQL-based and objective predicates: one GetQuestInfo call per quest.
        local info = SocialQuest.AQL and SocialQuest.AQL:GetQuestInfo(entry.questID)
        if not info then
            matched = false
        elseif value == "escort" or value == "dungeon" or value == "raid"
            or value == "elite"  or value == "daily"   or value == "pvp" then
            matched = (info.type == value)
        elseif value == "kill" or value == "gather" or value == "interact" then
            local objType = value == "kill" and "monster"
                         or value == "gather" and "item"
                         or "object"
            matched = false
            if info.objectives then
                for _, obj in ipairs(info.objectives) do
                    if obj.type == objType then matched = true; break end
                end
            end
        else
            matched = false  -- unknown value
        end
    end

    -- Explicit if/else avoids the Lua `a and false or c` pitfall.
    if descriptor.op == "=" then return matched else return not matched end
end
```

### 3. `UI/Tabs/MineTab.lua`

- Remove `mapType()` function.
- Replace `T.MatchesEnumFilter(mapType(entry), ft.type)` with `T.MatchesTypeFilter(entry, ft.type)`.

### 4. `UI/Tabs/PartyTab.lua`

- Remove the `mapType()` local function from the `questPasses` closure.
- Replace the existing `T.MatchesEnumFilter(mapType(entry), ft.type)` call with `T.MatchesTypeFilter(entry, ft.type)`. The `ft.type` guard and overall call structure are already in place — only the inner call changes.

### 5. `UI/Tabs/SharedTab.lua`

Same two changes as PartyTab — remove `mapType()`, replace the `MatchesEnumFilter(mapType(...), ft.type)` call.

### 6. `Locales/enUS.lua` and all other locale files

In `enUS.lua`: add 9 new `filter.val.*` keys and update the existing `filter.key.type.desc` value. The `descKey` key name `"filter.key.type.desc"` is unchanged — only its locale string is updated:

In all other locale files: add the same 9 `filter.val.*` keys as `= true` (falls back to enUS via AceLocale), and add `L["filter.key.type.desc"] = true` so they also fall back to the updated enUS description.

```lua
-- New type enum values (filter.val.* convention)
L["filter.val.escort"]   = "escort"
L["filter.val.dungeon"]  = "dungeon"
L["filter.val.raid"]     = "raid"
L["filter.val.elite"]    = "elite"
L["filter.val.daily"]    = "daily"
L["filter.val.pvp"]      = "pvp"
L["filter.val.kill"]     = "kill"
L["filter.val.gather"]   = "gather"
L["filter.val.interact"] = "interact"

-- Updated type key description (key name unchanged)
L["filter.key.type.desc"] = "Quest type — chain, group, solo, timed, escort, dungeon, raid, elite, daily, pvp, kill, gather, interact"
```

All other locale files: add the same 9 keys with `= true` (falls back to canonical string via AceLocale).

### 7. `UI/GroupFrame.lua` — filter syntax help window

In `createHelpFrame()`:
- Update the `type` key description line to list all 13 values.
- Add a note below the key list: *"kill, gather, and interact match quests with at least one objective of that kind — quests can match multiple types. Type filters require the Questie or QuestWeaver add-on to be installed."*
- Add example locale entries: `filter.help.example.N` for `type=dungeon`, `type=kill`, `type=daily`.

---

## Filter Applicability Table (updated)

| Filter key | Mine | Party | Shared |
|---|---|---|---|
| zone | ✓ | ✓ | ✓ |
| title | ✓ | ✓ | ✓ |
| chain | ✓ | ✓ | ✓ |
| player | — | ✓ | ✓ |
| level | ✓ | ✓ | ✓ |
| step | ✓ | — | — |
| group | ✓ | ✓ | ✓ |
| **type** | **✓** | **✓ (new)** | **✓ (new)** |
| status | ✓ | — | — |
| tracked | ✓ | — | — |

---

## Known Limitations

- **Remote-only quests:** For quests a party member has that the local player does not, `suggestedGroup` and `timerSeconds` come from `localInfo = AQL:GetQuest(questID)` which is nil for those quests. `group`/`timed`/`solo` predicates fall back to `0`/`nil` defaults for those quests — same limitation that already exists in Party/Shared tab rendering today.
- **No provider:** Without Questie or QuestWeaver, AQL-based and objective predicates return false. `group`, `timed`, and `solo` still work from wire data.
- **Mixed objectives:** `kill`, `gather`, `interact` match quests with at least one matching objective, not quests where all objectives are of that kind.

---

## What Is Not Included

- `delivery` / `fed-ex` quests — no reliable signal.
- `event` objective type — too rarely useful to expose.
- `log` objective type — not a meaningful user-facing category.
- `normal` as explicit value — redundant given `solo` covers the intent.
- No changes to the SQ wire protocol — type data is always resolved locally.
