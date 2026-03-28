# Filter & Operator and Shareable Key — Design Spec

**Date:** 2026-03-28
**Branch:** Improvements
**Features:** `&` same-key AND operator; `shareable` filter key

---

## Goal

Extend the SocialQuest advanced filter language with two additions:
1. A `&` operator that allows a single filter label to express AND conditions on the same key (e.g. `type=dungeon&gather`, `level>=55&<=62`).
2. A `shareable` boolean filter key that identifies quests which can be shared with at least one party member right now.

---

## Context

The advanced filter language was added in v2.12.18. Filters are parsed by `UI/FilterParser.lua`, stored in `UI/FilterState.lua` (AceDB-backed, one entry per canonical key), and applied by `BuildTree` in each tab via helpers in `UI/TabUtils.lua`. The existing `|` OR operator allows `zone=Elwynn|Deadmines` — the key is written once and multiple values are separated by `|`. The `&` AND operator follows the same single-key convention.

The `shareable` key reuses the logic that already drives the `[Share]` button in `UI/Tabs/PartyTab.lua`, moving the computation into `BuildTree` so both the button and the filter read from the same pre-computed value.

---

## Feature 1 — `&` Operator (Same-Key AND)

### Syntax

```
type=dungeon&gather       -- type equals dungeon AND gather (operator = inherited)
level>=55&<=62            -- level >= 55 AND level <= 62 (explicit operators)
title=dragon&slayer       -- title contains dragon AND slayer (string field)
```

Rules:
- The key is written **once**; fragments after `&` contain an operator and value, or just a value (operator inherited from the first fragment).
- All fragments must resolve to the same canonical key; mixing keys is a parse error.
- Applicable to all field types: string, numeric, enum.
- `&` and `|` may not appear together in the same expression; `level>=55&<=62|58` is a parse error (`MIXED_AND_OR`).
- Whitespace around `&` is stripped.

### Descriptor

A new descriptor type `compound_and` wraps an ordered list of individual descriptors:

```lua
-- type=dungeon&gather  →
{
    type  = "compound_and",
    parts = {
        { op="=", value="dungeon" },   -- enum descriptor
        { op="=", value="gather"  },
    }
}

-- level>=55&<=62  →
{
    type  = "compound_and",
    parts = {
        { op=">=", val=55 },           -- numeric descriptor
        { op="<=", val=62 },
    }
}
```

`FilterState` stores this descriptor under the canonical key like any other descriptor — no changes to `FilterState`.

### Parser Changes (`UI/FilterParser.lua`)

**Detection:** After extracting the key and first operator+value, scan for `&` not inside a quoted string. If found, split into fragments and enter compound-and parsing.

**Algorithm:**

```
1. Parse first fragment normally → yields canonical key, op1, val1
2. For each remaining fragment (split on unquoted &):
   a. Try to match ^([~!<>]?=|[<>])\s*(.*) — if operator present, use it;
      otherwise inherit op1 (the first fragment's operator)
   b. Parse the value using the same value-parsing logic (quotes, type checks)
   c. Confirm the value's canonical key matches the first fragment's canonical key
      (re-checking enum maps and type validity with the (possibly different) operator)
3. If any fragment fails validation, return the appropriate error code
4. Return { filter = { canonical = ..., descriptor = compound_and{parts=[...]}, raw = ... } }
```

**New error codes:**

| Code | Args | Example message |
|---|---|---|
| `MIXED_AND_OR` | `{}` | *"cannot mix & and \| in the same expression"* |
| `AND_KEY_MISMATCH` | `{frag}` | *"all & fragments must use the same key"* (defensive; parser structure makes this unlikely) |

**No changes** to the nil fast-path (still: no `=` → return nil immediately).

### Filter Helpers — `compound_and` Guard (`UI/TabUtils.lua`)

Each helper gains a guard at the top:

```lua
function SocialQuestTabUtils.MatchesStringFilter(value, descriptor)
    if descriptor.type == "compound_and" then
        for _, part in ipairs(descriptor.parts) do
            if not SocialQuestTabUtils.MatchesStringFilter(value, part) then
                return false
            end
        end
        return true
    end
    -- existing logic ...
end
```

Same pattern for `MatchesNumericFilter`, `MatchesEnumFilter`, and `MatchesTypeFilter`.

### Filter Labels

A `compound_and` descriptor produces **one** dismissible label showing the full raw expression (e.g. `type=dungeon&gather`). No special rendering — `entry.raw` is displayed as-is, which is the existing behaviour.

### New Locale Keys

Added to all 12 locale files:

```lua
L["filter.err.MIXED_AND_OR"]    = "cannot mix & and | in the same expression"
L["filter.err.AND_KEY_MISMATCH"]= "all & fragments must use the same key"

-- Filter help examples
L["filter.help.example.12"]      = "type=dungeon&gather"
L["filter.help.example.12.note"] = "Show dungeon quests that also have gather objectives"
L["filter.help.example.13"]      = "level>=55&<=62"
L["filter.help.example.13.note"] = "Show quests in the level 55–62 range"
L["filter.help.example.14"]      = "title=dragon&slayer"
L["filter.help.example.14.note"] = "Show quests with both 'dragon' and 'slayer' in the title"
```

Help window syntax block addition (all 12 locales):

```lua
-- New line in GroupFrame.lua hardcoded syntax rows:
"key=val1&val2  (AND — same key)"
```

### Test Coverage Additions (`tests/FilterParser_test.lua`)

| Case | Input | Expected |
|---|---|---|
| Numeric range via `&` | `level>=55&<=62` | compound_and, parts `[{>=,55},{<=,62}]` |
| Enum AND | `type=dungeon&gather` | compound_and, parts `[{=,dungeon},{=,gather}]` |
| String AND | `title=dragon&slayer` | compound_and, parts `[{=,dragon},{=,slayer}]` |
| Inherited operator | `type=dungeon&gather` | second part inherits `=` |
| Mixed `&` and `|` | `level>=55&<=62\|70` | error `MIXED_AND_OR` |
| Single-fragment `&` | `level>=55&` | error `EMPTY_VALUE` |
| Whitespace around `&` | `level >= 55 & <= 62` | same as no-whitespace |

---

## Feature 2 — `shareable` Filter Key

### Definition

| Canonical | Aliases | Type | Enum values | Tab applicability |
|---|---|---|---|---|
| `shareable` | — | enum | `yes` / `no` | Party only (Mine/Shared always false) |

`shareable=yes` matches a quest row when **all three** conditions hold:
1. `entry.logIndex ~= nil` — the local player has this quest in their log.
2. `AQL:IsQuestIdShareable(entry.questID)` — the quest is flagged as shareable by AQL.
3. At least one player in `entry.players` has `needsShare = true`.

This is identical to the condition that shows the `[Share]` button.

### Pre-computation in PartyTab `BuildTree`

After `buildPlayerRowsForQuest` populates `entry.players`, `BuildTree` sets:

```lua
entry.hasShareableMembers = false
if entry.logIndex then
    local sqWowAPI = SocialQuestWowAPI
    if sqWowAPI.IsQuestIdShareable and sqWowAPI:IsQuestIdShareable(entry.questID) then
        for _, player in ipairs(entry.players) do
            if player.needsShare then
                entry.hasShareableMembers = true
                break
            end
        end
    end
end
```

`buildQuestCallbacks` in `Render` reads `entry.hasShareableMembers` instead of recomputing:

```lua
-- before:
local canShare = entry.logIndex and AQL:IsQuestIdShareable(entry.questID) and hasNeedsShare(entry)
-- after:
local canShare = entry.hasShareableMembers
```

### Mine and Shared Tabs

`entry.hasShareableMembers` is always `false` (not set) for Mine and Shared tab entries. The `shareable` key is silently ignored by those tabs' `BuildTree` (per-tab applicability table, same as `tracked` is ignored on Party/Shared).

### Filter Helper

`MatchesEnumFilter` handles `shareable` via the existing enum descriptor path. The caller passes `entry.hasShareableMembers and "yes" or "no"` as the value to test.

In `PartyTab:BuildTree`, after computing `entry.hasShareableMembers`, apply the filter:

```lua
if ft.shareable then
    local val = entry.hasShareableMembers and "yes" or "no"
    if not SocialQuestTabUtils.MatchesEnumFilter(val, ft.shareable) then
        goto continue
    end
end
```

### Tab-Mask Enforcement

`GroupFrame` assembles `ft` (the filterTable) once per `Refresh()` before passing it to each tab's `BuildTree`. Keys with `tabMask` restrictions are **not added** to `ft` for non-matching tabs. Concretely: when building the filterTable for Mine or Shared tab renders, `ft.shareable` is never set — so the `if ft.shareable then` guard in `BuildTree` is never entered, and Mine/Shared entries are unaffected. This is consistent with how `tracked` (Mine only) and `player` (Party/Shared only) are already handled.

### Key Definition (`UI/GroupFrame.lua` — `buildKeyDefs`)

```lua
{
    canonical = "shareable",
    names     = { L["filter.key.shareable"] },
    type      = "enum",
    enumMap   = { [L["filter.val.yes"]] = "yes", [L["filter.val.no"]] = "no" },
    descKey   = "filter.key.shareable.desc",
    tabMask   = { party = true },   -- help window note: Party tab only
}
```

### New Locale Keys

Added to all 12 locale files:

```lua
L["filter.key.shareable"]      = "shareable"
L["filter.key.shareable.desc"] = "Quest can be shared with a party member right now (Party tab only)"

-- Filter help example
L["filter.help.example.15"]      = "shareable=yes"
L["filter.help.example.15.note"] = "Show quests you can share with a party member right now (Party tab)"
```

---

## Files Modified

| File | Change |
|---|---|
| `UI/FilterParser.lua` | Add `&` detection and compound_and parsing; add `MIXED_AND_OR` / `AND_KEY_MISMATCH` error codes |
| `UI/TabUtils.lua` | Add `compound_and` guard to all four `Matches*` helpers |
| `UI/Tabs/PartyTab.lua` | Pre-compute `entry.hasShareableMembers` in `BuildTree`; read it in `buildQuestCallbacks`; apply `ft.shareable` filter |
| `UI/GroupFrame.lua` | Add `shareable` key def in `buildKeyDefs()`; add `key=val1&val2` to syntax help rows |
| `tests/FilterParser_test.lua` | Add `&` operator test cases |
| `Locales/enUS.lua` | New `filter.*` keys (see above) |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | Same keys as `= true` (AceLocale fallback), natural translations where appropriate |
| `SocialQuest.toc` | Version bump |
| `CLAUDE.md` | Version history entry |

No changes to: `UI/FilterState.lua`, `UI/HeaderLabel.lua`, `UI/WindowFilter.lua`, `UI/Tabs/MineTab.lua`, `UI/Tabs/SharedTab.lua`, `SocialQuest.lua` (AceDB schema unchanged — compound_and is a descriptor shape, not a new storage key), `SocialQuest.toc` load order (no new files).

---

## AceDB Schema

No changes. `activeFilters` continues to hold `{ [canonical] = { descriptor, raw } }`. The `compound_and` descriptor is stored as the descriptor for the canonical key — `FilterState` is agnostic to descriptor shape.

---

## Per-Tab Applicability (updated)

| Key | Mine | Party | Shared |
|---|---|---|---|
| `search`, `autoZone`, `zone`, `title`, `chain`, `level`, `group`, `type`, `step` | ✓ | ✓ | ✓ |
| `status`, `tracked` | ✓ | — | — |
| `player` | — | ✓ | ✓ |
| `shareable` | — | ✓ | — |

---

## Error Codes (complete updated list)

| Code | New? | Args | Example |
|---|---|---|---|
| `UNKNOWN_KEY` | — | `{key}` | "unknown filter key 'palyer'" |
| `INVALID_OPERATOR` | — | `{op, key}` | "operator '>' cannot be used with 'zone'" |
| `TYPE_MISMATCH` | — | `{op, canonical}` | "'<' requires a numeric field" |
| `UNCLOSED_QUOTE` | — | `{}` | "unclosed quote in filter expression" |
| `EMPTY_VALUE` | — | `{op}` | "missing value after '>='" |
| `INVALID_NUMBER` | — | `{canonical, val}` | "expected a number for 'level', got 'abc'" |
| `RANGE_REVERSED` | — | `{min, max}` | "invalid range: min (65) must be ≤ max (60)" |
| `INVALID_ENUM` | — | `{canonical, val}` | "'dungeon' is not a valid value for 'type'" |
| `MIXED_AND_OR` | **new** | `{}` | "cannot mix & and \| in the same expression" |
| `AND_KEY_MISMATCH` | **new** | `{frag}` | "all & fragments must use the same key" |

---

## Not In Scope

- Cross-key AND via `&` (e.g. `type=dungeon&zone=Deadmines`) — rejected; use two separate filter labels.
- `&` inside quoted strings — treated as literal characters, not the AND operator.
- `shareable` on Shared tab — always false (Party member must have the quest locally for sharing to apply).
- `shareable` on Mine tab — always false (no party members in Mine tab).
