# Advanced Filter Language — Design Spec

**Date:** 2026-03-27
**Branch:** FilterTextbox
**Feature:** FeatureIdeas.md #18

---

## Goal

Extend the search bar in the SocialQuest group window to accept a structured filter expression language. Plain text continues to work as a real-time title substring match (no Enter required). When the user types a valid filter expression and presses Enter, it is parsed into a structured filter descriptor, stored persistently, displayed as a dismissible filter label, and applied to all three tabs. Invalid expressions that look like filter attempts produce a user-friendly error label directly below the search bar. A `[?]` help button opens a companion reference panel.

---

## Context

The existing search bar (`searchText` upvalue + `filterTable.search`) performs real-time case-insensitive substring matching on quest titles and chain titles. The existing `WindowFilter` module provides an auto-zone/instance filter (`filterTable.autoZone`). This feature adds a third filter source — user-typed structured filters stored in `FilterState` — that compounds with both of those without replacing them.

---

## Module Map

### New files

| File | Global | Responsibility |
|---|---|---|
| `UI/FilterParser.lua` | `SocialQuestFilterParser` | Pure Lua parser. No WoW dependencies. Accepts text + pre-built key definition table; returns nil / filter result / error result. |
| `UI/FilterState.lua` | `SocialQuestFilterState` | Compound user-typed filter state. Stores one active filter descriptor per canonical key in AceDB `char.frameState.activeFilters`. Provides the data iterated by GroupFrame to build filter labels and assemble the filterTable. |
| `UI/HeaderLabel.lua` | `SocialQuestHeaderLabel` | Dismissible label widget factory. Creates one reusable controller object per label slot. Used for the auto-zone label, error label, and all user-typed filter labels. |
| `tests/FilterParser_test.lua` | *(none)* | Standalone test runner. `lua tests/FilterParser_test.lua` from repo root. No WoW dependencies. |

### Modified files

`UI/GroupFrame.lua`, `UI/WindowFilter.lua`, `UI/TabUtils.lua`, `UI/Tabs/MineTab.lua`, `UI/Tabs/PartyTab.lua`, `UI/Tabs/SharedTab.lua`, `SocialQuest.lua` (AceDB defaults), `SocialQuest.toc`, all 12 locale files.

---

## Filter Syntax

```
key=value                  -- equals / substring match
key!=value                 -- not-equal / does not contain  (alias: ~=)
key<N                      -- less than (numeric fields only)
key>N                      -- greater than (numeric fields only)
key<=N                     -- less than or equal (numeric fields only)
key>=N                     -- greater than or equal (numeric fields only)
key="value with spaces"    -- quoted value
key=val1|val2              -- OR: zone=Elwynn|Deadmines
key="val 1"|"val 2"        -- OR with quoted values
key=N..M                   -- range: level=60..65 means 60–65 (numeric fields only)
```

- Keys and their aliases are localized (see Localization section).
- Values for string fields are case-insensitive substring matches.
- `!=` and `~=` are interchangeable.
- Comparison operators (`<`, `>`, `<=`, `>=`) and `..` apply only to numeric fields; using them on string or enum fields is a parse error.
- `=` on numeric fields is exact equality.
- Quotes are optional; required when the value contains spaces, `|`, or an operator character.
- Escaped quotes inside a quoted value: `\"`.
- Whitespace around the operator, `|`, and `..` is stripped.
- Keys are case-insensitive.

### Supported keys

| Canonical | Aliases | Type | Notes |
|---|---|---|---|
| `zone` | `z` | string | Zone name substring match |
| `title` | `t` | string | Quest title substring match (same as plain text) |
| `chain` | `c` | string | Chain title substring match |
| `level` | `lvl`, `l` | numeric | Recommended quest level |
| `group` | `g` | enum | `yes` / `no` / `2`–`5` |
| `type` | — | enum | `chain` / `group` / `solo` / `timed` |
| `player` | `p` | string | Party member name (Party/Shared tabs only) |
| `status` | — | enum | `complete` / `incomplete` / `failed` |
| `tracked` | — | enum | `yes` / `no` (Mine tab only) |
| `step` | `s` | numeric | Chain step number |

All key names, aliases, and enumerated values are localized. A Japanese player types the Japanese word for "zone", not the English word.

---

## FilterParser

### Key definition structure

`FilterParser:Initialize(defs)` is called once at addon startup from `GroupFrame.lua` after locale is loaded. Each entry in `defs`:

```lua
{
    canonical = "zone",
    names     = { L["filter.key.zone"], L["filter.key.zone.z"] },  -- all localized names/aliases
    type      = "string",    -- "string" | "numeric" | "enum"
    enumMap   = { ... },     -- type="enum" only: { [localizedValue] = canonicalValue }
    descKey   = "filter.key.zone.desc",  -- locale key for help window description
}
```

`Initialize` builds a flat reverse-lookup table: `nameToKey[lowercasedLocalizedName] = keyEntry`. Lookup is O(1). If two locale strings resolve to the same text, the duplicate maps to the same canonical — no error.

### Parse algorithm (fast-fail, three-way result)

```
1. Trim input.
   No "=" present → return nil immediately. Zero allocations.

2. Extract leading token: match (\w+)\s*([~!<>]?=|[<>])
   Key not in nameToKey       → return error(UNKNOWN_KEY, {rawKey})
   Operator not recognised    → return error(INVALID_OPERATOR, {op, rawKey})

3. Validate operator/type compatibility:
   Comparison op on non-numeric field  → return error(TYPE_MISMATCH, {op, canonical})

4. Parse value(s): handle quotes, \" escapes, | OR combiner, .. range operator
   Unclosed quote             → return error(UNCLOSED_QUOTE, {})
   Empty value after operator → return error(EMPTY_VALUE, {op})
   Non-numeric on numeric     → return error(INVALID_NUMBER, {canonical, val})
   Range min > max            → return error(RANGE_REVERSED, {min, max})
   Value not in enumMap       → return error(INVALID_ENUM, {canonical, val})

5. Return { filter = { canonical=..., descriptor=..., raw=originalText } }
```

### Return types

```lua
-- Not a filter attempt — treat as plain text, no error shown
nil

-- Valid filter
{
    filter = {
        canonical  = "zone",
        descriptor = { op="=", values={"Elwynn","Deadmines"} },
        raw        = "zone=Elwynn|Deadmines",
    }
}

-- Parse error — structured, locale-independent
{ error = true, code = "UNKNOWN_KEY", args = { "palyer" } }
```

### Error codes

| Code | Args | Example rendered message |
|---|---|---|
| `UNKNOWN_KEY` | `{key}` | *"unknown filter key 'palyer'"* |
| `INVALID_OPERATOR` | `{op, key}` | *"operator '>' cannot be used with 'zone'"* |
| `TYPE_MISMATCH` | `{op, canonical}` | *"'<' requires a numeric field"* |
| `UNCLOSED_QUOTE` | `{}` | *"unclosed quote in filter expression"* |
| `EMPTY_VALUE` | `{op}` | *"missing value after '>='"* |
| `INVALID_NUMBER` | `{canonical, val}` | *"expected a number for 'level', got 'abc'"* |
| `RANGE_REVERSED` | `{min, max}` | *"invalid range: min (65) must be ≤ max (60)"* |
| `INVALID_ENUM` | `{canonical, val}` | *"'dungeon' is not a valid value for 'type'"* |

Error codes are translated to player-facing strings by `GroupFrame`, never by the parser.

### Descriptor format

```lua
-- string field  (zone, title, chain, player)
{ op = "=" | "!=",  values = { "Elwynn", "Deadmines" } }

-- numeric field  (level, step) — single value
{ op = "=" | "<" | ">" | "<=" | ">=",  val = 60 }

-- numeric field  — range
{ op = "range",  min = 60,  max = 65 }

-- enum field  (group, type, status, tracked)
{ op = "=" | "!=",  value = "yes" }   -- canonical value stored, not localized
```

---

## FilterState

Owns compound user-typed filter state. Reads and writes `SocialQuest.db.char.frameState.activeFilters` directly.

### AceDB shape

New key added to `char.frameState` defaults:

```lua
activeFilters = {},
-- shape: { [canonical] = { descriptor = {...}, raw = "original expression" } }
```

Descriptors contain canonical values only — locale-independent, safe to persist across sessions and locale changes. The `raw` string is cosmetic (shown in filter label tooltip); a stale raw string after a locale change is a cosmetic imperfection only.

### Public API

```lua
-- Stores or replaces the entry for parseResult.filter.canonical.
-- Assumes the caller has already validated parseResult (i.e. it came from a successful Parse()).
-- Does NOT call RequestRefresh() — the caller is responsible for that.
-- Applying the same canonical key a second time silently replaces the first entry.
SocialQuestFilterState:Apply(parseResult)

-- Removes the entry for the given canonical key. No-op if the key is not active.
-- Does NOT call RequestRefresh() — the caller is responsible for that.
SocialQuestFilterState:Dismiss(canonical)

-- Returns the activeFilters table for read-only iteration. Do not modify the returned table.
SocialQuestFilterState:GetAll()

-- Returns true when no entries are active (activeFilters is empty).
SocialQuestFilterState:IsEmpty()
```

No mass-`Reset()` method. FilterState entries are **only** removed via `Dismiss()`. They persist across window close/reopen, loading screens, and `/reload`.

**Profile reset.** The existing `OnProfileReset` callback in `SocialQuest.lua` resets `char.frameState` to AceDB defaults (clearing `collapsedZones`, scroll positions, etc.). `activeFilters = {}` is part of `char.frameState`, so it is also cleared on profile reset — consistent with all other `frameState` fields.

**Self leaving group.** `FilterState` is **not** cleared when the player leaves the group. Filters are display preferences, not group-context data. A `player=Thad` filter with Thad absent simply returns an empty result set on the Party/Shared tabs — the same as any filter that matches nothing. This is the least-surprising behaviour and avoids discarding filters the player deliberately set.

### Enter-key flow

```
User presses Enter in search box
  │
  ├─ No "=" in text
  │     → no-op (plain text works real-time; Enter does nothing)
  │
  ├─ Parse returns { filter = ... }
  │     → FilterState:Apply(result)
  │     → searchBox:SetText("")        (search bar cleared; FilterState untouched by [x])
  │     → errorLabel:Hide()
  │     → RequestRefresh()
  │
  └─ Parse returns { error = true, ... }
        → translate error code to locale string
        → errorLabel:SetContent("Filter error: " .. msg, ...)
        → errorLabel:Show()
        → search bar text left intact for correction
        → RequestRefresh()
```

The `[x]` search bar clear button clears `searchText` only — it never touches `FilterState`.

---

## FilterTable format

`GroupFrame:Refresh()` assembles a single `filterTable` from three sources and passes it to `BuildTree`. This replaces the current `filterTable` assembly block entirely.

```lua
local ft = nil

-- Source 1: auto-zone (WindowFilter — exact match, existing behaviour)
local zoneFilter = SocialQuestWindowFilter:GetActiveFilter(activeID)
if zoneFilter then
    ft = ft or {}
    ft.autoZone = zoneFilter.zone
end

-- Source 2: user-typed structured filters (FilterState)
if not SocialQuestFilterState:IsEmpty() then
    ft = ft or {}
    for canonical, entry in pairs(SocialQuestFilterState:GetAll()) do
        ft[canonical] = entry.descriptor
    end
end

-- Source 3: real-time search text
if searchText ~= "" then
    ft = ft or {}
    ft.search = searchText
end
```

`autoZone` (exact equality) and `zone` (OR-list substring) coexist and AND together when both are present.

### Complete filterTable shape

```lua
{
    -- Existing (unchanged behaviour)
    search   = "text",
    autoZone = "Hellfire Peninsula",

    -- New: string fields
    zone   = { op="="|"!=", values={"Elwynn","Deadmines"} },
    title  = { op="="|"!=", values={"Defias"} },
    chain  = { op="="|"!=", values={"Legend"} },
    player = { op="="|"!=", values={"Thad"} },

    -- New: numeric fields.
    -- A numeric field holds exactly one of two mutually exclusive shapes at runtime:
    --   Single-value: op is "=", "<", ">", "<=", or ">="; val holds the number; no min/max.
    --   Range:        op is always "range"; min and max hold the bounds; no val field.
    -- Example single-value (level>=60):
    level  = { op=">=", val=60 },
    -- Example range (level=60..65) — would replace the single-value entry above, not coexist:
    -- level = { op="range", min=60, max=65 },
    -- step follows the same two-shape pattern as level.
    step   = { op="=", val=2 },

    -- New: enum fields
    group   = { op="="|"!=", value="yes"|"no"|"2"|"3"|"4"|"5" },
    type    = { op="="|"!=", value="chain"|"group"|"solo"|"timed" },
    status  = { op="="|"!=", value="complete"|"incomplete"|"failed" },
    tracked = { op="="|"!=", value="yes"|"no" },
}
```

### BuildTree filter helpers

Three shared helpers in `TabUtils.lua` prevent logic duplication across tabs:

```lua
SocialQuestTabUtils.MatchesStringFilter(value, descriptor)   -- op, OR-list, substring
SocialQuestTabUtils.MatchesNumericFilter(value, descriptor)  -- op, range, exact
SocialQuestTabUtils.MatchesEnumFilter(value, descriptor)     -- op, exact enum
```

### Per-tab key applicability

| Key | Mine | Party | Shared |
|---|---|---|---|
| `search`, `autoZone`, `zone`, `title`, `chain`, `level`, `group`, `type`, `step` | ✓ | ✓ | ✓ |
| `status`, `tracked` | ✓ | — | — |
| `player` | — | ✓ | ✓ |

Keys not applicable to a tab are silently ignored by that tab's `BuildTree`.

---

## HeaderLabel Factory

`SocialQuestHeaderLabel.New(parent, config)` creates one reusable controller. Frame is created once; only content and visibility change on each `Refresh()`.

```lua
-- config = { height = 18, textColor = {r, g, b} }

controller:SetContent(text, tooltipText, onDismiss)
controller:Show()
controller:Hide()
controller:IsShown()
controller:GetFrame()   -- for anchor chaining
```

The `[x]` dismiss button's `OnClick` is reassigned on every `SetContent()` call so it always captures the current `onDismiss` closure.

---

## GroupFrame Header Layout

### Fixed header stacking order (top to bottom)

```
Search bar            (always shown, 24px)
Error label           (shown only on parse error, 18px, red/amber)
Expand/collapse row   (always shown, 18px)
Auto-zone label       (shown only when WindowFilter active, 18px)
Filter label[zone]    (shown when FilterState has zone entry, 18px)
Filter label[level]   (shown when FilterState has level entry, 18px)
...up to 10 labels, one per canonical key...
Scroll frame
```

### Dynamic anchor chain

`Refresh()` walks the stack with a `lastHeader` cursor. The expand/collapse frame is re-anchored on every `Refresh()` (no longer has a fixed creation-time anchor):

```lua
local lastHeader = frame.searchBarFrame

-- Error label (immediately below search box)
if errorShown then
    anchorBelow(frame.errorLabel:GetFrame(), lastHeader)
    frame.errorLabel:Show()
    lastHeader = frame.errorLabel:GetFrame()
else
    frame.errorLabel:Hide()
end

-- Expand/collapse row (dynamic anchor)
frame.expandCollapseFrame:ClearAllPoints()
frame.expandCollapseFrame:SetPoint("TOPLEFT",  lastHeader, "BOTTOMLEFT",  0, -2)
frame.expandCollapseFrame:SetPoint("TOPRIGHT", lastHeader, "BOTTOMRIGHT", 0, -2)
lastHeader = frame.expandCollapseFrame

-- Auto-zone label
if filterLabel then
    frame.autoZoneLabel:SetContent(filterLabel, filterLabel, dismissFn)
    frame.autoZoneLabel:Show()
    anchorBelow(frame.autoZoneLabel:GetFrame(), lastHeader)
    lastHeader = frame.autoZoneLabel:GetFrame()
else
    frame.autoZoneLabel:Hide()
end

-- User-typed filter labels (lazy-created, one slot per canonical key)
for canonical, entry in pairs(SocialQuestFilterState:GetAll()) do
    local lbl = getOrCreateFilterLabel(canonical)
    lbl:SetContent(buildDisplayText(canonical, entry), entry.raw,
        function()
            SocialQuestFilterState:Dismiss(canonical)
            SocialQuestGroupFrame:RequestRefresh()
        end)
    lbl:Show()
    anchorBelow(lbl:GetFrame(), lastHeader)
    lastHeader = lbl:GetFrame()
end
hideUnusedFilterLabels()

-- Scroll frame
frame.scrollFrame:ClearAllPoints()
frame.scrollFrame:SetPoint("TOPLEFT",  lastHeader, "BOTTOMLEFT",  0, -4)
frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 10)
```

Filter label slots are created lazily via `getOrCreateFilterLabel(canonical)`. At most 10 slots ever exist (one per canonical key).

### Search bar button layout

```
[ search text...              ] [?] [x]
```

- `[x]` clear:  `RIGHT -2`,  20px wide
- `[?]` help:   `RIGHT -24`, 22px wide
- `searchBox` RIGHT anchor: `-48` (was `-26`)

### Error label behaviour

- Created once in `createFrame()` via `HeaderLabel.New`.
- Shown when the last Enter-key parse returned an error.
- Hidden automatically on `OnTextChanged` (any keystroke clears it).
- Dismissed via its own `[x]` button.
- At most one error label; new parse errors replace the previous message.

---

## Filter Syntax Help Window

### Behaviour

- `BasicFrameTemplate` frame, named `"SocialQuestFilterHelpFrame"`, registered in `UISpecialFrames` (Escape closes it).
- Movable via title bar drag.
- Default size: 420×500. Position saved in `char.frameState.helpWindowPos`.
- Created lazily on first `[?]` click (`createHelpFrame()` local in `GroupFrame.lua`).
- `[?]` button toggles open/closed; saves `char.frameState.helpWindowOpen` on each toggle.

### Lifecycle (tied to main SQ window)

The help window is a companion panel — it opens and closes with the main window:

| Event | Behaviour |
|---|---|
| User closes SQ window (`OnHide`, `leavingWorld == false`) | Snapshot `helpWindowOpen`, hide help window |
| User opens SQ window (`Toggle()`) | If `helpWindowOpen == true`, show help window |
| `OnLeavingWorld()` | Snapshot `helpWindowOpen` (same as `windowOpen`) |
| `RestoreAfterTransition()` | Restore help window if `helpWindowOpen == true` |

### AceDB additions

```lua
char.frameState.helpWindowOpen = false,
char.frameState.helpWindowPos  = nil,   -- { x=N, y=N } or nil (default position)
```

### Content

All content is derived from the `keyDefs` table and locale strings — no separate string tables to maintain.

```
Title: L["filter.help.title"]         ("SQ Filter Syntax")
────────────────────────────────────
Intro: L["filter.help.intro"]

Section: L["filter.help.section.syntax"]
  [syntax reference rows — from locale keys]

Section: L["filter.help.section.keys"]
  [key table rows — derived from keyDefs: canonical, aliases, desc]

Section: L["filter.help.section.examples"]
  [example rows — expression + annotation from locale keys]
```

A `ScrollFrame` wraps the content panel to handle window resize.

---

## Localization

### Key naming convention

All new keys use the `filter.` prefix:

```
filter.key.<canonical>           Primary localized key name
filter.key.<canonical>.<alias>   Each alias
filter.key.<canonical>.desc      One-line description for help window

filter.val.yes / filter.val.no
filter.val.complete / filter.val.incomplete / filter.val.failed
filter.val.chain / filter.val.group / filter.val.solo / filter.val.timed

filter.err.UNKNOWN_KEY
filter.err.INVALID_OPERATOR
filter.err.TYPE_MISMATCH
filter.err.UNCLOSED_QUOTE
filter.err.EMPTY_VALUE
filter.err.INVALID_NUMBER
filter.err.RANGE_REVERSED
filter.err.INVALID_ENUM
filter.err.label                 "Filter error: %s"

filter.help.title
filter.help.intro
filter.help.section.syntax
filter.help.section.keys
filter.help.section.examples
filter.help.col.key
filter.help.col.aliases
filter.help.col.desc
filter.help.example.<n>          One annotation per example expression
```

### Scope

`enUS.lua` gets all keys as explicit strings. The remaining 11 locale files receive `= true` initially (AceLocale falls back to enUS), to be filled in by translators — the existing pattern throughout the addon.

---

## Test Strategy

### Runner

`tests/FilterParser_test.lua` — standalone, no external framework:

```lua
local pass, fail = 0, 0
local function assert_eq(label, got, expected)
    if got == expected then
        pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected %s, got %s",
            label, tostring(expected), tostring(got)))
    end
end
```

### Bootstrap

```lua
-- Stub locale: key string is its own value
L = setmetatable({}, { __index = function(_, k) return k end })

dofile("UI/FilterParser.lua")
SocialQuestFilterParser:Initialize({ ... })  -- minimal keyDefs
```

### Test coverage

| Category | Cases |
|---|---|
| Fast-fail (nil) | No `=`, plain text, empty string |
| Valid string filter | `zone=Elwynn`, OR list, `!=`, quoted value with spaces |
| Valid numeric filter | Exact, `>=`, `<=`, `<`, `>`, range `60..65`, single-value range `60..60` |
| Valid enum filter | `group=yes`, `type=chain`, `tracked=no` |
| Localized key lookup | Alias resolves to same canonical as primary name |
| OR list | Two values, three values, quoted values |
| Error: UNKNOWN_KEY | `palyer=Thad` |
| Error: TYPE_MISMATCH | `zone>=Elwynn` |
| Error: UNCLOSED_QUOTE | `zone="Elwyn` |
| Error: INVALID_NUMBER | `level=abc` |
| Error: RANGE_REVERSED | `level=65..60` |
| Error: INVALID_ENUM | `type=dungeon` |
| Error: EMPTY_VALUE | `level=` |
| Operator variants | `!=` and `~=` produce identical results |
| Whitespace tolerance | `zone = Elwynn`, `level >= 60` |
| Case insensitivity | `ZONE=Elwynn` resolves to `zone` canonical |

`TabUtils` filter helpers and `BuildTree` filter application are tested in-game (depend on AQL and `PlayerQuests` data).

---

## Files Modified Summary

| File | Change |
|---|---|
| `UI/FilterParser.lua` | **New** — pure parser |
| `UI/FilterState.lua` | **New** — compound filter state (AceDB-backed) |
| `UI/HeaderLabel.lua` | **New** — dismissible label widget factory |
| `tests/FilterParser_test.lua` | **New** — standalone test runner |
| `UI/GroupFrame.lua` | Search bar `[?]` button; error label; dynamic header anchor chain; Enter-key parse flow; filterTable assembly; help window lifecycle |
| `UI/TabUtils.lua` | Add `MatchesStringFilter`, `MatchesNumericFilter`, `MatchesEnumFilter` helpers |
| `UI/Tabs/MineTab.lua` | `BuildTree` handles extended filterTable fields applicable to Mine tab |
| `UI/Tabs/PartyTab.lua` | `BuildTree` handles extended filterTable fields applicable to Party tab |
| `UI/Tabs/SharedTab.lua` | `BuildTree` handles extended filterTable fields applicable to Shared tab |
| `SocialQuest.lua` | AceDB defaults: add three keys to `char.frameState` (see schema below) |
| `SocialQuest.toc` | Add new UI files in load order before `GroupFrame.lua` (see order below) |
| `Locales/enUS.lua` | All `filter.*` locale keys as explicit strings |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | All `filter.*` keys as `= true` (AceLocale fallback) |

No protocol changes. No new AceComm prefixes. No changes to `PlayerQuests` data structure.

---

## AceDB Schema Additions

In `SocialQuest.lua`, inside the `char.frameState` defaults table:

```lua
char = {
    frameState = {
        -- existing keys unchanged --
        activeFilters  = {},    -- [canonical] = { descriptor={...}, raw="..." }
        helpWindowOpen = false, -- true if help window was open when SQ window last closed
        helpWindowPos  = nil,   -- { x=N, y=N } screen-relative position, or nil (use default)
    }
}
```

All three keys are in `char` scope (per-character), not `profile` scope (shared). They are cleared by `OnProfileReset` along with the rest of `char.frameState`.

---

## TOC Load Order

The three new UI files must be loaded **before** `UI/GroupFrame.lua` and in dependency order:

```
# UI modules (existing entries shown for context)
UI\TabUtils.lua
UI\RowFactory.lua
UI\FilterParser.lua      ← new, no SQ dependencies; must precede FilterState
UI\FilterState.lua       ← new, depends on AceDB (SocialQuest.db); must precede GroupFrame
UI\HeaderLabel.lua       ← new, no dependencies on FilterParser or FilterState
UI\Tabs\MineTab.lua
UI\Tabs\PartyTab.lua
UI\Tabs\SharedTab.lua
UI\WindowFilter.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua        ← calls FilterParser:Initialize(), FilterState, HeaderLabel
```

`FilterParser.lua` has no SQ-specific dependencies and can be loaded at any point before `GroupFrame.lua`. `FilterState.lua` accesses `SocialQuest.db` at call time (not at load time), so load order relative to `SocialQuest.lua` is not a concern.

---

## Test Bootstrap Detail

`tests/FilterParser_test.lua` uses a path relative to the **repo root**, which is the documented working directory for running the test. To guard against invocation from a wrong directory, the file opens with an existence check:

```lua
-- Verify working directory is the repo root
local f = io.open("UI/FilterParser.lua", "r")
if not f then
    error("Run this test from the repo root: lua tests/FilterParser_test.lua")
end
f:close()

-- Stub locale: key string is its own value (English canonical = display value)
L = setmetatable({}, { __index = function(_, k) return k end })

dofile("UI/FilterParser.lua")

-- Minimal keyDefs for testing (English, one key per type)
SocialQuestFilterParser:Initialize({
    { canonical="zone",  names={"zone","z"},   type="string" },
    { canonical="level", names={"level","lvl"}, type="numeric" },
    { canonical="group", names={"group","g"},   type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no", ["2"]="2", ["3"]="3" } },
})
```
