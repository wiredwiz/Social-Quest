# Advanced Filter Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a structured filter expression language to the SocialQuest search bar: typed expressions like `level>=60` are parsed, stored persistently as dismissible labels, and applied across all three tabs.

**Architecture:** Four new modules (`FilterParser`, `FilterState`, `HeaderLabel`, test runner) integrate with the existing GroupFrame header and tab BuildTree functions. `FilterParser` is pure Lua and fully unit-tested standalone; the rest depend on WoW APIs and are validated in-game. FilterParser is grown incrementally across Tasks 1–4 (string → numeric → enum) so each task maintains a proper red-green TDD cycle.

**Tech Stack:** Lua 5.4 (standalone tests via `lua tests/FilterParser_test.lua`), WoW Lua/Ace3 (AceDB persistence), WoW Frame API (BasicFrameTemplate, UISpecialFrames).

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `UI/FilterParser.lua` | **New** | Pure Lua parser: Initialize(defs) + Parse(text) → nil/filter/error |
| `UI/FilterState.lua` | **New** | AceDB-backed compound filter state (Apply/Dismiss/GetAll/IsEmpty) |
| `UI/HeaderLabel.lua` | **New** | Dismissible label widget factory (New/SetContent/Show/Hide/GetFrame) |
| `tests/FilterParser_test.lua` | **New** | Standalone test runner, no WoW deps |
| `UI/GroupFrame.lua` | **Modify** | [?] button, Enter-key parse flow, error label, lastHeader chain, filterTable assembly, help window |
| `UI/TabUtils.lua` | **Modify** | Add MatchesStringFilter, MatchesNumericFilter, MatchesEnumFilter |
| `UI/Tabs/MineTab.lua` | **Modify** | BuildTree applies autoZone/zone/title/chain/level/group/type/step/status/tracked filters |
| `UI/Tabs/PartyTab.lua` | **Modify** | BuildTree applies all filters except status/tracked; adds player filter; autoZone rename |
| `UI/Tabs/SharedTab.lua` | **Modify** | Same as PartyTab |
| `SocialQuest.lua` | **Modify** | AceDB defaults: activeFilters, helpWindowOpen, helpWindowPos |
| `SocialQuest.toc` | **Modify** | Add new UI files before GroupFrame.lua |
| `Locales/enUS.lua` | **Modify** | All filter.* locale keys as explicit English strings |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | **Modify** | All filter.* keys as `= true` (AceLocale fallback to enUS) |

---

## Task 1: Test scaffold + FilterParser stub

**Files:**
- Create: `tests/FilterParser_test.lua`
- Create: `UI/FilterParser.lua`

- [ ] **Step 1: Write the test bootstrap and fast-fail nil tests**

Create `tests/FilterParser_test.lua`:

```lua
-- tests/FilterParser_test.lua
-- Standalone test runner. Run from repo root: lua tests/FilterParser_test.lua

local f = io.open("UI/FilterParser.lua", "r")
if not f then error("Run from repo root: lua tests/FilterParser_test.lua") end
f:close()

-- Stub locale: key string is its own value
L = setmetatable({}, { __index = function(_, k) return k end })

dofile("UI/FilterParser.lua")

-- Minimal keyDefs for testing (English canonical names as-is)
SocialQuestFilterParser:Initialize({
    { canonical="zone",   names={"zone","z"},       type="string" },
    { canonical="title",  names={"title","t"},       type="string" },
    { canonical="chain",  names={"chain","c"},       type="string" },
    { canonical="player", names={"player","p"},      type="string" },
    { canonical="level",  names={"level","lvl","l"}, type="numeric" },
    { canonical="step",   names={"step","s"},        type="numeric" },
    { canonical="group",  names={"group","g"},       type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5" } },
    { canonical="type",   names={"type"},            type="enum",
      enumMap={ ["chain"]="chain", ["group"]="group", ["solo"]="solo", ["timed"]="timed" } },
    { canonical="status", names={"status"},          type="enum",
      enumMap={ ["complete"]="complete", ["incomplete"]="incomplete", ["failed"]="failed" } },
    { canonical="tracked",names={"tracked"},         type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no" } },
})

local pass, fail = 0, 0

local function assert_eq(label, got, expected)
    if got == expected then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected %s, got %s",
            label, tostring(expected), tostring(got)))
    end
end

local function assert_nil(label, got)
    if got == nil then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected nil, got %s", label, tostring(got)))
    end
end

local function assert_error(label, result, code)
    if result and result.error == true and result.code == code then pass = pass + 1
    else
        fail = fail + 1
        local got = result and (result.code or tostring(result)) or "nil"
        print(string.format("FAIL [%s]: expected error %s, got %s", label, code, got))
    end
end

local function assert_filter(label, result, canonical, op)
    if result and result.filter and result.filter.canonical == canonical then
        if op == nil or result.filter.descriptor.op == op then pass = pass + 1
        else
            fail = fail + 1
            print(string.format("FAIL [%s]: expected op=%s, got op=%s",
                label, tostring(op), tostring(result.filter.descriptor.op)))
        end
    else
        fail = fail + 1
        local got = result and (result.filter and result.filter.canonical or tostring(result)) or "nil"
        print(string.format("FAIL [%s]: expected filter canonical=%s, got %s", label, canonical, got))
    end
end

local P = SocialQuestFilterParser

-- ── Fast-fail (nil) ──────────────────────────────────────────────────
assert_nil("nil input",       P:Parse(nil))
assert_nil("empty string",    P:Parse(""))
assert_nil("plain text",      P:Parse("Defias Brotherhood"))
assert_nil("whitespace only", P:Parse("   "))
assert_nil("no equals sign",  P:Parse("level60"))

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
```

- [ ] **Step 2: Create a minimal FilterParser stub**

Create `UI/FilterParser.lua`:

```lua
-- UI/FilterParser.lua
-- Pure Lua filter expression parser. No WoW dependencies.
-- Grown incrementally across Tasks 1-4.

SocialQuestFilterParser = {}

local _nameToKey = {}

function SocialQuestFilterParser:Initialize(defs)
    _nameToKey = {}
    for _, def in ipairs(defs) do
        for _, name in ipairs(def.names) do
            _nameToKey[name:lower()] = def
        end
    end
end

local function makeError(code, args)
    return { error = true, code = code, args = args or {} }
end

function SocialQuestFilterParser:Parse(text)
    if not text then return nil end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    if not text:find("=", 1, true) then return nil end
    return nil  -- full implementation added in Tasks 2-4
end
```

- [ ] **Step 3: Run tests — expect 5 passed, 0 failed**

```
lua tests/FilterParser_test.lua
```

- [ ] **Step 4: Commit**

```bash
git add tests/FilterParser_test.lua UI/FilterParser.lua
git commit -m "feat: add FilterParser stub and test scaffold with fast-fail nil cases"
```

---

## Task 2: FilterParser — string filters + shared infrastructure errors

**Files:**
- Modify: `tests/FilterParser_test.lua`
- Modify: `UI/FilterParser.lua`

- [ ] **Step 1: Add string filter tests and shared error tests (append to test file, before the final print)**

```lua
-- ── String filters ───────────────────────────────────────────────────
local r = P:Parse("zone=Elwynn")
assert_filter("zone= basic",              r, "zone", "=")
assert_eq("zone= value",                  r and r.filter.descriptor.values[1], "Elwynn")

r = P:Parse("z=Elwynn")
assert_filter("z= alias",                 r, "zone", "=")

r = P:Parse("ZONE=Elwynn")
assert_filter("ZONE= case insensitive",   r, "zone", "=")

r = P:Parse("zone = Elwynn")
assert_filter("zone= whitespace",         r, "zone", "=")

r = P:Parse("zone!=Westfall")
assert_filter("zone!= op",                r, "zone", "!=")

r = P:Parse("zone~=Westfall")
assert_filter("zone~= normalised to !=", r, "zone", "!=")

r = P:Parse("zone=Elwynn|Deadmines")
assert_filter("zone= OR list",            r, "zone", "=")
assert_eq("OR val[1]",                    r and r.filter.descriptor.values[1], "Elwynn")
assert_eq("OR val[2]",                    r and r.filter.descriptor.values[2], "Deadmines")

r = P:Parse('zone="Elwynn Forest"')
assert_filter("zone= quoted",             r, "zone", "=")
assert_eq("quoted value",                 r and r.filter.descriptor.values[1], "Elwynn Forest")

r = P:Parse('zone="val 1"|"val 2"')
assert_filter("zone= quoted OR",          r, "zone", "=")
assert_eq("quoted OR val[1]",             r and r.filter.descriptor.values[1], "val 1")
assert_eq("quoted OR val[2]",             r and r.filter.descriptor.values[2], "val 2")

r = P:Parse('zone="He said \\"hi\\""')
assert_filter("escaped quote",            r, "zone", "=")
assert_eq("escaped quote value",          r and r.filter.descriptor.values[1], 'He said "hi"')

r = P:Parse("t=Defias")
assert_filter("title alias t=",           r, "title", "=")

-- ── Shared-infrastructure errors (tested here because they can be
--    triggered by string inputs and are part of the shared parse path)
assert_error("UNKNOWN_KEY",       P:Parse("palyer=Thad"),    "UNKNOWN_KEY")
assert_eq("UNKNOWN_KEY arg",      P:Parse("palyer=Thad").args[1], "palyer")

assert_error("UNCLOSED_QUOTE",    P:Parse('zone="Elwyn'),    "UNCLOSED_QUOTE")
assert_error("EMPTY_VALUE =",     P:Parse("zone="),          "EMPTY_VALUE")
assert_error("EMPTY_VALUE >=",    P:Parse("level>="),        "EMPTY_VALUE")

-- TYPE_MISMATCH: comparison operator on a non-numeric field
assert_error("TYPE_MISMATCH <",   P:Parse("zone<Elwynn"),    "TYPE_MISMATCH")
assert_error("TYPE_MISMATCH >=",  P:Parse("zone>=Elwynn"),   "TYPE_MISMATCH")

-- INVALID_OPERATOR: known key with an unrecognised operator
assert_error("INVALID_OPERATOR",  P:Parse("zone<=>Elwynn"),  "INVALID_OPERATOR")
```

- [ ] **Step 2: Run tests — expect string/error tests to FAIL**

```
lua tests/FilterParser_test.lua
```

Expected: multiple FAIL lines for every string and error test.

- [ ] **Step 3: Implement string parsing and shared infrastructure in FilterParser.lua**

Replace `UI/FilterParser.lua` entirely. This version handles string fields plus all shared-infrastructure errors (UNKNOWN_KEY, UNCLOSED_QUOTE, EMPTY_VALUE, TYPE_MISMATCH, INVALID_OPERATOR). Numeric and enum fields return `nil` for now.

```lua
-- UI/FilterParser.lua
SocialQuestFilterParser = {}

local _nameToKey = {}

function SocialQuestFilterParser:Initialize(defs)
    _nameToKey = {}
    for _, def in ipairs(defs) do
        for _, name in ipairs(def.names) do
            _nameToKey[name:lower()] = def
        end
    end
end

local function makeError(code, args)
    return { error = true, code = code, args = args or {} }
end

-- Parse one value token from str at pos (quoted or unquoted).
-- Returns (value, nextPos) on success, or (nil, nil, errorResult) on unclosed quote.
local function parseOneValue(str, pos)
    if pos > #str then return nil, nil, makeError("EMPTY_VALUE", {}) end
    local ws = str:match("^%s*()", pos); pos = ws or pos
    if str:sub(pos, pos) == '"' then
        pos = pos + 1
        local chars = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '\\' and pos+1 <= #str and str:sub(pos+1,pos+1) == '"' then
                chars[#chars+1] = '"'; pos = pos + 2
            elseif c == '"' then
                return table.concat(chars), pos + 1
            else
                chars[#chars+1] = c; pos = pos + 1
            end
        end
        return nil, nil, makeError("UNCLOSED_QUOTE", {})
    else
        local pipePos = str:find("|", pos, true)
        if pipePos then
            return str:sub(pos, pipePos-1):match("^%s*(.-)%s*$"), pipePos
        else
            return str:sub(pos):match("^%s*(.-)%s*$"), #str + 1
        end
    end
end

-- Parse a |-separated list of values. Returns (values_table) or (nil, errorResult).
local function parseValues(valueStr, op)
    if not valueStr or valueStr == "" then
        return nil, makeError("EMPTY_VALUE", {op})
    end
    local values, pos = {}, 1
    while pos <= #valueStr do
        local ws = valueStr:match("^%s*()", pos); pos = ws or pos
        if pos > #valueStr then break end
        if valueStr:sub(pos,pos) == "|" then
            pos = pos + 1
        else
            local val, nextPos, err = parseOneValue(valueStr, pos)
            if err then return nil, err end
            if val == "" then return nil, makeError("EMPTY_VALUE", {op}) end
            values[#values+1] = val
            pos = nextPos
            local wsEnd = valueStr:match("^%s*()", pos); pos = wsEnd or pos
        end
    end
    if #values == 0 then return nil, makeError("EMPTY_VALUE", {op}) end
    return values, nil
end

-- Try each operator pattern (longest first to avoid ambiguity).
local _opPatterns = {
    "^(%w+)%s*(~=)%s*(.*)", "^(%w+)%s*(!=)%s*(.*)",
    "^(%w+)%s*(<=)%s*(.*)", "^(%w+)%s*(>=)%s*(.*)",
    "^(%w+)%s*(<)%s*(.*)",  "^(%w+)%s*(>)%s*(.*)",
    "^(%w+)%s*(=)%s*(.*)",
}
local function extractKeyAndOp(text)
    for _, pat in ipairs(_opPatterns) do
        local k, op, rest = text:match(pat)
        if k then return k, op, rest end
    end
    return nil, nil, nil
end

function SocialQuestFilterParser:Parse(text)
    if not text then return nil end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    if not text:find("=", 1, true) then return nil end

    local rawKey, op, valueStr = extractKeyAndOp(text)

    -- Input contains "=" but no operator pattern matched → check for INVALID_OPERATOR.
    if not rawKey then
        local testKey = text:match("^(%w+)")
        if testKey and _nameToKey[testKey:lower()] then
            local afterKey = text:sub(#testKey+1):match("^%s*(.*)")
            local badOp = afterKey:match("^([^%a%d%s\"]+)")
            return makeError("INVALID_OPERATOR", {badOp or "", testKey})
        end
        return nil
    end

    local keyDef = _nameToKey[rawKey:lower()]
    if not keyDef then return makeError("UNKNOWN_KEY", {rawKey}) end

    local isComparison = (op=="<" or op==">" or op=="<=" or op==">=")
    if isComparison and keyDef.type ~= "numeric" then
        return makeError("TYPE_MISMATCH", {op, keyDef.canonical})
    end

    local normOp = (op == "~=" and "!=" or op)

    if keyDef.type == "string" then
        local values, err = parseValues(valueStr, op)
        if err then return err end
        return { filter = { canonical=keyDef.canonical,
                            descriptor={ op=normOp, values=values },
                            raw=text } }
    end

    -- Numeric and enum handling added in Tasks 3 and 4.
    return nil
end
```

- [ ] **Step 4: Run tests — expect all tests so far to pass**

```
lua tests/FilterParser_test.lua
```

Expected: all passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add tests/FilterParser_test.lua UI/FilterParser.lua
git commit -m "feat: implement FilterParser string parsing, shared infrastructure, and all string-path error codes"
```

---

## Task 3: FilterParser — numeric filters

**Files:**
- Modify: `tests/FilterParser_test.lua`
- Modify: `UI/FilterParser.lua`

- [ ] **Step 1: Add numeric tests (append before the final print)**

```lua
-- ── Numeric filters ──────────────────────────────────────────────────
r = P:Parse("level=60")
assert_filter("level= exact",       r, "level", "=")
assert_eq("level= val",             r and r.filter.descriptor.val, 60)

r = P:Parse("level>=60")
assert_filter("level>= op",         r, "level", ">=")
assert_eq("level>= val",            r and r.filter.descriptor.val, 60)

r = P:Parse("level<=65")
assert_filter("level<= op",         r, "level", "<=")

r = P:Parse("level<60")
assert_filter("level< op",          r, "level", "<")

r = P:Parse("level>60")
assert_filter("level> op",          r, "level", ">")

r = P:Parse("level=60..65")
assert_filter("level range",        r, "level", "range")
assert_eq("range min",              r and r.filter.descriptor.min, 60)
assert_eq("range max",              r and r.filter.descriptor.max, 65)

r = P:Parse("level=60..60")
assert_filter("range single",       r, "level", "range")
assert_eq("range single min",       r and r.filter.descriptor.min, 60)
assert_eq("range single max",       r and r.filter.descriptor.max, 60)

r = P:Parse("lvl>=60")
assert_filter("lvl alias",          r, "level", ">=")

r = P:Parse("l=60")
assert_filter("l alias",            r, "level", "=")

r = P:Parse("step=2")
assert_filter("step= exact",        r, "step", "=")
assert_eq("step= val",              r and r.filter.descriptor.val, 2)

r = P:Parse("level >= 60")
assert_filter("whitespace around",  r, "level", ">=")

-- Numeric error codes
assert_error("INVALID_NUMBER str",  P:Parse("level=abc"),     "INVALID_NUMBER")
assert_error("RANGE_REVERSED",      P:Parse("level=65..60"),  "RANGE_REVERSED")
local rr = P:Parse("level=65..60")
assert_eq("RANGE_REVERSED min arg", rr and rr.args[1], 65)
assert_eq("RANGE_REVERSED max arg", rr and rr.args[2], 60)
```

- [ ] **Step 2: Run tests — numeric tests FAIL (numeric returns nil)**

```
lua tests/FilterParser_test.lua
```

Expected: FAILs for all numeric tests.

- [ ] **Step 3: Add numeric parsing to FilterParser.lua**

Replace the `-- Numeric and enum handling added in Tasks 3 and 4. return nil` section with:

```lua
    if keyDef.type == "numeric" then
        local values, err = parseValues(valueStr, op)
        if err then return err end
        local v = values[1]
        local minS, maxS = v:match("^(.-)%.%.(.+)$")
        if minS then
            local minN = tonumber(minS:match("^%s*(.-)%s*$"))
            local maxN = tonumber(maxS:match("^%s*(.-)%s*$"))
            if not minN then return makeError("INVALID_NUMBER", {keyDef.canonical, minS}) end
            if not maxN then return makeError("INVALID_NUMBER", {keyDef.canonical, maxS}) end
            if minN > maxN then return makeError("RANGE_REVERSED", {minN, maxN}) end
            return { filter = { canonical=keyDef.canonical,
                                descriptor={ op="range", min=minN, max=maxN },
                                raw=text } }
        else
            local n = tonumber(v)
            if not n then return makeError("INVALID_NUMBER", {keyDef.canonical, v}) end
            return { filter = { canonical=keyDef.canonical,
                                descriptor={ op=normOp, val=n },
                                raw=text } }
        end
    end

    -- Enum handling added in Task 4.
    return nil
```

- [ ] **Step 4: Run tests — all pass**

```
lua tests/FilterParser_test.lua
```

- [ ] **Step 5: Commit**

```bash
git add tests/FilterParser_test.lua UI/FilterParser.lua
git commit -m "feat: add numeric filter parsing (exact, comparison, range) and INVALID_NUMBER/RANGE_REVERSED errors"
```

---

## Task 4: FilterParser — enum filters + INVALID_ENUM

**Files:**
- Modify: `tests/FilterParser_test.lua`
- Modify: `UI/FilterParser.lua`

- [ ] **Step 1: Add enum tests (append before final print)**

```lua
-- ── Enum filters ─────────────────────────────────────────────────────
r = P:Parse("group=yes")
assert_filter("group= yes",         r, "group", "=")
assert_eq("group= canonical",       r and r.filter.descriptor.value, "yes")

r = P:Parse("group=2")
assert_filter("group= 2",           r, "group", "=")
assert_eq("group= 2 canonical",     r and r.filter.descriptor.value, "2")

r = P:Parse("type=chain")
assert_filter("type= chain",        r, "type", "=")
assert_eq("type= canonical",        r and r.filter.descriptor.value, "chain")

r = P:Parse("status=complete")
assert_filter("status= complete",   r, "status", "=")

r = P:Parse("status!=incomplete")
assert_filter("status!= op",        r, "status", "!=")

r = P:Parse("tracked=yes")
assert_filter("tracked= yes",       r, "tracked", "=")

-- Operator variant: != and ~= produce identical results
local r1, r2 = P:Parse("zone!=Elwynn"), P:Parse("zone~=Elwynn")
assert_eq("!= and ~= same op",
    r1 and r1.filter.descriptor.op,
    r2 and r2.filter.descriptor.op)

-- Enum error
assert_error("INVALID_ENUM",        P:Parse("type=dungeon"),  "INVALID_ENUM")
local ie = P:Parse("type=dungeon")
assert_eq("INVALID_ENUM canonical", ie and ie.args[1], "type")
assert_eq("INVALID_ENUM value",     ie and ie.args[2], "dungeon")
```

- [ ] **Step 2: Run tests — enum tests FAIL**

```
lua tests/FilterParser_test.lua
```

- [ ] **Step 3: Add enum parsing to FilterParser.lua**

Replace the final `-- Enum handling added in Task 4. return nil` with:

```lua
    if keyDef.type == "enum" then
        local values, err = parseValues(valueStr, op)
        if err then return err end
        local v = values[1]:lower()
        local canonicalVal = keyDef.enumMap and keyDef.enumMap[v]
        if not canonicalVal then
            return makeError("INVALID_ENUM", {keyDef.canonical, values[1]})
        end
        return { filter = { canonical=keyDef.canonical,
                            descriptor={ op=normOp, value=canonicalVal },
                            raw=text } }
    end

    return nil
```

- [ ] **Step 4: Run tests — all pass**

```
lua tests/FilterParser_test.lua
```

Expected: all passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add tests/FilterParser_test.lua UI/FilterParser.lua
git commit -m "feat: add enum filter parsing and INVALID_ENUM error; FilterParser complete"
```

---

## Task 5: AceDB defaults + TOC load order + enUS locale

**Files:**
- Create: `UI/FilterState.lua` (stub)
- Create: `UI/HeaderLabel.lua` (stub)
- Modify: `SocialQuest.lua`
- Modify: `SocialQuest.toc`
- Modify: `Locales/enUS.lua`

- [ ] **Step 1: Create FilterState stub**

```lua
-- UI/FilterState.lua  (stub — implemented in Task 7)
SocialQuestFilterState = {}
```

- [ ] **Step 2: Create HeaderLabel stub**

```lua
-- UI/HeaderLabel.lua  (stub — implemented in Task 8)
SocialQuestHeaderLabel = {}
```

- [ ] **Step 3: Add three new keys to char.frameState defaults in SocialQuest.lua**

Inside the `char.frameState` defaults block, after `frameHeight = nil`:

```lua
                frameHeight    = nil,
                -- Advanced filter language (Feature #18)
                activeFilters  = {},    -- [canonical] = { descriptor={...}, raw="..." }
                helpWindowOpen = false,
                helpWindowPos  = nil,   -- { x=N, y=N } or nil (use default position)
```

- [ ] **Step 4: Add three new UI files to SocialQuest.toc**

After `UI\RowFactory.lua`:

```
UI\TabUtils.lua
UI\RowFactory.lua
UI\FilterParser.lua
UI\FilterState.lua
UI\HeaderLabel.lua
UI\Tabs\MineTab.lua
```

- [ ] **Step 5: Add all filter.* locale keys to Locales/enUS.lua**

Append before the closing `end`:

```lua
    -- Advanced filter language (Feature #18)
    ["filter.key.zone"]         = "zone",
    ["filter.key.zone.z"]       = "z",
    ["filter.key.zone.desc"]    = "Zone name (substring match)",
    ["filter.key.title"]        = "title",
    ["filter.key.title.t"]      = "t",
    ["filter.key.title.desc"]   = "Quest title (substring match)",
    ["filter.key.chain"]        = "chain",
    ["filter.key.chain.c"]      = "c",
    ["filter.key.chain.desc"]   = "Chain title (substring match)",
    ["filter.key.player"]       = "player",
    ["filter.key.player.p"]     = "p",
    ["filter.key.player.desc"]  = "Party member name (Party/Shared tabs only)",
    ["filter.key.level"]        = "level",
    ["filter.key.level.lvl"]    = "lvl",
    ["filter.key.level.l"]      = "l",
    ["filter.key.level.desc"]   = "Recommended quest level",
    ["filter.key.step"]         = "step",
    ["filter.key.step.s"]       = "s",
    ["filter.key.step.desc"]    = "Chain step number",
    ["filter.key.group"]        = "group",
    ["filter.key.group.g"]      = "g",
    ["filter.key.group.desc"]   = "Group requirement (yes, no, 2-5)",
    ["filter.key.type"]         = "type",
    ["filter.key.type.desc"]    = "Quest type (chain, group, solo, timed)",
    ["filter.key.status"]       = "status",
    ["filter.key.status.desc"]  = "Quest status (complete, incomplete, failed)",
    ["filter.key.tracked"]      = "tracked",
    ["filter.key.tracked.desc"] = "Tracked on minimap (yes, no; Mine tab only)",
    ["filter.val.yes"]          = "yes",
    ["filter.val.no"]           = "no",
    ["filter.val.complete"]     = "complete",
    ["filter.val.incomplete"]   = "incomplete",
    ["filter.val.failed"]       = "failed",
    ["filter.val.chain"]        = "chain",
    ["filter.val.group"]        = "group",
    ["filter.val.solo"]         = "solo",
    ["filter.val.timed"]        = "timed",
    ["filter.err.UNKNOWN_KEY"]      = "unknown filter key '%s'",
    ["filter.err.INVALID_OPERATOR"] = "operator '%s' cannot be used with '%s'",
    ["filter.err.TYPE_MISMATCH"]    = "'%s' requires a numeric field",
    ["filter.err.UNCLOSED_QUOTE"]   = "unclosed quote in filter expression",
    ["filter.err.EMPTY_VALUE"]      = "missing value after '%s'",
    ["filter.err.INVALID_NUMBER"]   = "expected a number for '%s', got '%s'",
    ["filter.err.RANGE_REVERSED"]   = "invalid range: min (%s) must be <= max (%s)",
    ["filter.err.INVALID_ENUM"]     = "'%s' is not a valid value for '%s'",
    ["filter.err.label"]            = "Filter error: %s",
    ["filter.help.title"]                = "SQ Filter Syntax",
    ["filter.help.intro"]                = "Type a filter expression and press Enter to apply it as a persistent label. Dismiss a label with [x]. Multiple filters AND together.",
    ["filter.help.section.syntax"]       = "Syntax",
    ["filter.help.section.keys"]         = "Supported Keys",
    ["filter.help.section.examples"]     = "Examples",
    ["filter.help.col.key"]              = "Key",
    ["filter.help.col.aliases"]          = "Aliases",
    ["filter.help.col.desc"]             = "Description",
    ["filter.help.example.1"]            = "level>=60",
    ["filter.help.example.1.note"]       = "Show quests for level 60 or higher",
    ["filter.help.example.2"]            = "level=58..62",
    ["filter.help.example.2.note"]       = "Show quests in the level 58-62 range",
    ["filter.help.example.3"]            = "zone=Elwynn|Deadmines",
    ["filter.help.example.3.note"]       = "Show quests in Elwynn Forest OR Deadmines",
    ["filter.help.example.4"]            = "status=incomplete",
    ["filter.help.example.4.note"]       = "Show only incomplete quests",
    ["filter.help.example.5"]            = "type=chain",
    ["filter.help.example.5.note"]       = "Show only chain quests",
    ["filter.help.example.6"]            = 'zone="Hellfire Peninsula"',
    ["filter.help.example.6.note"]       = "Quoted value (use when value contains spaces)",
```

- [ ] **Step 6: Reload in WoW — verify no Lua errors**

- [ ] **Step 7: Commit**

```bash
git add UI/FilterState.lua UI/HeaderLabel.lua SocialQuest.lua SocialQuest.toc Locales/enUS.lua
git commit -m "feat: AceDB defaults, TOC load order, and enUS locale for advanced filter language"
```

---

## Task 6: Locale fallbacks (11 remaining locale files)

**Files:**
- Modify: `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`, `Locales/esMX.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`, `Locales/koKR.lua`, `Locales/ruRU.lua`, `Locales/jaJP.lua`

- [ ] **Step 1: Append `= true` block to each of the 11 locale files**

For each file, add before the closing `end`:

```lua
    -- Advanced filter language (Feature #18) — translate these strings
    ["filter.key.zone"]=true, ["filter.key.zone.z"]=true, ["filter.key.zone.desc"]=true,
    ["filter.key.title"]=true, ["filter.key.title.t"]=true, ["filter.key.title.desc"]=true,
    ["filter.key.chain"]=true, ["filter.key.chain.c"]=true, ["filter.key.chain.desc"]=true,
    ["filter.key.player"]=true, ["filter.key.player.p"]=true, ["filter.key.player.desc"]=true,
    ["filter.key.level"]=true, ["filter.key.level.lvl"]=true, ["filter.key.level.l"]=true, ["filter.key.level.desc"]=true,
    ["filter.key.step"]=true, ["filter.key.step.s"]=true, ["filter.key.step.desc"]=true,
    ["filter.key.group"]=true, ["filter.key.group.g"]=true, ["filter.key.group.desc"]=true,
    ["filter.key.type"]=true, ["filter.key.type.desc"]=true,
    ["filter.key.status"]=true, ["filter.key.status.desc"]=true,
    ["filter.key.tracked"]=true, ["filter.key.tracked.desc"]=true,
    ["filter.val.yes"]=true, ["filter.val.no"]=true,
    ["filter.val.complete"]=true, ["filter.val.incomplete"]=true, ["filter.val.failed"]=true,
    ["filter.val.chain"]=true, ["filter.val.group"]=true, ["filter.val.solo"]=true, ["filter.val.timed"]=true,
    ["filter.err.UNKNOWN_KEY"]=true, ["filter.err.INVALID_OPERATOR"]=true,
    ["filter.err.TYPE_MISMATCH"]=true, ["filter.err.UNCLOSED_QUOTE"]=true,
    ["filter.err.EMPTY_VALUE"]=true, ["filter.err.INVALID_NUMBER"]=true,
    ["filter.err.RANGE_REVERSED"]=true, ["filter.err.INVALID_ENUM"]=true,
    ["filter.err.label"]=true,
    ["filter.help.title"]=true, ["filter.help.intro"]=true,
    ["filter.help.section.syntax"]=true, ["filter.help.section.keys"]=true, ["filter.help.section.examples"]=true,
    ["filter.help.col.key"]=true, ["filter.help.col.aliases"]=true, ["filter.help.col.desc"]=true,
    ["filter.help.example.1"]=true, ["filter.help.example.1.note"]=true,
    ["filter.help.example.2"]=true, ["filter.help.example.2.note"]=true,
    ["filter.help.example.3"]=true, ["filter.help.example.3.note"]=true,
    ["filter.help.example.4"]=true, ["filter.help.example.4.note"]=true,
    ["filter.help.example.5"]=true, ["filter.help.example.5.note"]=true,
    ["filter.help.example.6"]=true, ["filter.help.example.6.note"]=true,
```

- [ ] **Step 2: Reload in WoW — verify no Lua errors**

- [ ] **Step 3: Commit**

```bash
git add Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua \
        Locales/zhCN.lua Locales/zhTW.lua Locales/ptBR.lua Locales/itIT.lua \
        Locales/koKR.lua Locales/ruRU.lua Locales/jaJP.lua
git commit -m "feat: add filter language locale fallbacks to all 11 non-enUS locale files"
```

---

## Task 7: FilterState module

**Files:**
- Modify: `UI/FilterState.lua`

- [ ] **Step 1: Replace stub with full implementation**

```lua
-- UI/FilterState.lua
-- Compound user-typed filter state backed by AceDB char.frameState.activeFilters.
-- Keys are canonical (locale-independent); safe to persist across locale changes.
-- No mass Reset() method — entries are ONLY removed via Dismiss().

SocialQuestFilterState = {}

local function getFilters()
    return SocialQuest.db.char.frameState.activeFilters
end

-- Store or replace the entry for parseResult.filter.canonical.
-- Does NOT call RequestRefresh() — caller is responsible.
function SocialQuestFilterState:Apply(parseResult)
    local f = parseResult.filter
    getFilters()[f.canonical] = { descriptor = f.descriptor, raw = f.raw }
end

-- Remove the entry for canonical. No-op if not active.
-- Does NOT call RequestRefresh() — caller is responsible.
function SocialQuestFilterState:Dismiss(canonical)
    getFilters()[canonical] = nil
end

-- Read-only access to all active filters. Do not modify the returned table.
function SocialQuestFilterState:GetAll()
    return getFilters()
end

-- True when no filters are active.
function SocialQuestFilterState:IsEmpty()
    return next(getFilters()) == nil
end
```

- [ ] **Step 2: Smoke test in WoW**

```
/script print(SocialQuestFilterState:IsEmpty())
```
Expected: `true`

- [ ] **Step 3: Commit**

```bash
git add UI/FilterState.lua
git commit -m "feat: implement FilterState — AceDB-backed filter state with Apply/Dismiss/GetAll/IsEmpty"
```

---

## Task 8: HeaderLabel factory

**Files:**
- Modify: `UI/HeaderLabel.lua`

- [ ] **Step 1: Replace stub with full implementation**

```lua
-- UI/HeaderLabel.lua
-- Dismissible label widget factory.
-- Usage: local ctrl = SocialQuestHeaderLabel.New(parent, config)
-- config: { height=N, r=N, g=N, b=N }

SocialQuestHeaderLabel = {}

function SocialQuestHeaderLabel.New(parent, config)
    config = config or {}
    local height = config.height or 18
    local tR, tG, tB = config.r or 0.9, config.g or 0.9, config.b or 0.9

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(height)
    frame:Hide()

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT",     frame, "TOPLEFT",     4,   0)
    label:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetTextColor(tR, tG, tB)

    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(18, height)
    btn:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")

    local ctrl = {}

    -- SetContent wires new text and handlers. Always reassigns OnClick so
    -- the closure captures the current onDismiss even after filter state changes.
    function ctrl:SetContent(text, tooltipText, onDismiss)
        label:SetText(text or "")
        if tooltipText and tooltipText ~= "" then
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
        end
        btn:SetScript("OnClick", onDismiss or function() end)
    end

    function ctrl:Show()     frame:Show()           end
    function ctrl:Hide()     frame:Hide()           end
    function ctrl:IsShown()  return frame:IsShown() end
    function ctrl:GetFrame() return frame           end

    return ctrl
end
```

- [ ] **Step 2: Reload in WoW — verify no errors**

- [ ] **Step 3: Commit**

```bash
git add UI/HeaderLabel.lua
git commit -m "feat: implement HeaderLabel factory — dismissible label widget"
```

---

## Task 9: GroupFrame — [?] button, Enter-key flow, error label

**Files:**
- Modify: `UI/GroupFrame.lua`

Changes to `createFrame()` only (no Refresh changes yet).

- [ ] **Step 1: Add module-level locals**

At the top of `GroupFrame.lua`, after `local L = ...`, add:

```lua
local _keyDefs = {}     -- stored for help window content; set by buildKeyDefs()
local helpFrame = nil   -- lazy-created filter syntax help window
```

- [ ] **Step 2: Add buildKeyDefs() local function**

Place before `createFrame`. This function builds the localized key definition table, stores it in `_keyDefs`, and returns it:

```lua
local function buildKeyDefs()
    local defs = {
        { canonical="zone",   names={L["filter.key.zone"],   L["filter.key.zone.z"]},
          type="string",  descKey="filter.key.zone.desc" },
        { canonical="title",  names={L["filter.key.title"],  L["filter.key.title.t"]},
          type="string",  descKey="filter.key.title.desc" },
        { canonical="chain",  names={L["filter.key.chain"],  L["filter.key.chain.c"]},
          type="string",  descKey="filter.key.chain.desc" },
        { canonical="player", names={L["filter.key.player"], L["filter.key.player.p"]},
          type="string",  descKey="filter.key.player.desc" },
        { canonical="level",  names={L["filter.key.level"],  L["filter.key.level.lvl"], L["filter.key.level.l"]},
          type="numeric", descKey="filter.key.level.desc" },
        { canonical="step",   names={L["filter.key.step"],   L["filter.key.step.s"]},
          type="numeric", descKey="filter.key.step.desc" },
        { canonical="group",  names={L["filter.key.group"],  L["filter.key.group.g"]},
          type="enum",
          enumMap={ [L["filter.val.yes"]]="yes", [L["filter.val.no"]]="no",
                    ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5" },
          descKey="filter.key.group.desc" },
        { canonical="type",   names={L["filter.key.type"]},
          type="enum",
          enumMap={ [L["filter.val.chain"]]="chain", [L["filter.val.group"]]="group",
                    [L["filter.val.solo"]]="solo",   [L["filter.val.timed"]]="timed" },
          descKey="filter.key.type.desc" },
        { canonical="status", names={L["filter.key.status"]},
          type="enum",
          enumMap={ [L["filter.val.complete"]]="complete",
                    [L["filter.val.incomplete"]]="incomplete",
                    [L["filter.val.failed"]]="failed" },
          descKey="filter.key.status.desc" },
        { canonical="tracked",names={L["filter.key.tracked"]},
          type="enum",
          enumMap={ [L["filter.val.yes"]]="yes", [L["filter.val.no"]]="no" },
          descKey="filter.key.tracked.desc" },
    }
    _keyDefs = defs
    return defs
end
```

At the very bottom of `GroupFrame.lua` (after all function definitions, at file scope):

```lua
-- Initialize FilterParser with localized key definitions.
-- Locale files are loaded before GroupFrame.lua in the TOC, so L is ready.
SocialQuestFilterParser:Initialize(buildKeyDefs())
```

- [ ] **Step 3: In createFrame(), shift searchBox right anchor and add [?] button**

Find the searchBox `SetPoint("RIGHT", ...)` call and change `-26` to `-48`:

```lua
    searchBox:SetPoint("RIGHT", searchBarFrame, "RIGHT", -48, 0)
```

Add the help button after the searchBox creation block:

```lua
    local helpBtn = CreateFrame("Button", nil, searchBarFrame)
    helpBtn:SetSize(22, 22)
    helpBtn:SetPoint("RIGHT", searchBarFrame, "RIGHT", -24, 0)
    helpBtn:SetNormalFontObject("GameFontNormalSmall")
    helpBtn:SetText("?")
    helpBtn:GetFontString():SetTextColor(0.8, 0.8, 0.2)
    helpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(L["filter.help.title"], 1, 1, 1, nil, true)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    helpBtn:SetScript("OnClick", function()
        if not helpFrame then helpFrame = createHelpFrame() end
        if helpFrame:IsShown() then helpFrame:Hide() else helpFrame:Show() end
    end)
    f.helpBtn = helpBtn
```

- [ ] **Step 4: In createFrame(), create error label via HeaderLabel.New**

After the search bar frame block, before the expandCollapseFrame creation:

```lua
    -- Error label: shown on parse error, hidden on any keystroke or [x] dismiss.
    local errorLabel = SocialQuestHeaderLabel.New(f, { height=18, r=1.0, g=0.4, b=0.4 })
    errorLabel:GetFrame():SetPoint("TOPLEFT",  searchBarFrame, "BOTTOMLEFT",  0, -2)
    errorLabel:GetFrame():SetPoint("TOPRIGHT", searchBarFrame, "BOTTOMRIGHT", 0, -2)
    f.errorLabel = errorLabel
```

- [ ] **Step 5: Add errorLabel:Hide() to the existing OnTextChanged handler**

At the top of the `searchBox:SetScript("OnTextChanged", ...)` callback:

```lua
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        f.errorLabel:Hide()   -- any keystroke clears the error label
        -- existing code follows...
```

- [ ] **Step 6: Add OnEnterPressed handler to searchBox**

After the OnTextChanged block:

```lua
    searchBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if not text:find("=", 1, true) then return end  -- plain text; Enter is no-op

        local result = SocialQuestFilterParser:Parse(text)
        if not result then return end

        if result.filter then
            SocialQuestFilterState:Apply(result)
            self:SetText("")
            searchText = ""
            f.errorLabel:Hide()
            SocialQuestGroupFrame:RequestRefresh()
        else
            -- Translate error code to locale string
            local template = L["filter.err." .. result.code] or result.code
            local msg = string.format(template, unpack(result.args or {}))
            local fullMsg = string.format(L["filter.err.label"], msg)
            f.errorLabel:SetContent(fullMsg, nil, function()
                f.errorLabel:Hide()
                SocialQuestGroupFrame:RequestRefresh()
            end)
            f.errorLabel:Show()
            SocialQuestGroupFrame:RequestRefresh()
        end
    end)
```

- [ ] **Step 7: Reload and verify**

Type `level=60` and press Enter. Search bar should clear. No Lua errors.
Type `palyer=Thad` and press Enter. Red error label should appear. Any keystroke should hide it.

- [ ] **Step 8: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: add [?] button, buildKeyDefs, Enter-key parse flow, and error label to GroupFrame"
```

---

## Task 10: GroupFrame — dynamic header anchor chain

**Files:**
- Modify: `UI/GroupFrame.lua`

Replaces the fixed `filterLabelFrame` with `HeaderLabel`-based labels; implements the `lastHeader` cursor in `Refresh()`.

- [ ] **Step 1: In createFrame(), replace filterLabelFrame with autoZoneLabel and filterLabels**

Remove the entire `filterLabelFrame` creation block (including `filterLabelText`, `filterDismissBtn`, and their anchors/scripts). Replace with:

```lua
    -- Auto-zone label (replaces filterLabelFrame). Anchored dynamically in Refresh().
    local autoZoneLabel = SocialQuestHeaderLabel.New(f, { height = 18 })
    f.autoZoneLabel = autoZoneLabel

    -- User-typed filter label slots (lazy-created in Refresh, one per canonical key).
    f.filterLabels = {}
```

- [ ] **Step 2: Remove fixed creation-time anchors from expandCollapseFrame**

Find the two `SetPoint` calls on `expandCollapseFrame` that anchor it to `searchBarFrame` and delete them. The frame will be anchored in Refresh().

- [ ] **Step 3: In Refresh(), replace the filter label + scroll frame block with lastHeader cursor**

Remove:
- The `filterLabel` / `filterLabelText` / `filterLabelFrame` / `filterDismissBtn` block
- The `frame.scrollFrame:ClearAllPoints() ... SetPoint` block

Replace with the full lastHeader cursor:

```lua
    -- ── Dynamic header anchor chain ────────────────────────────────────
    local lastHeader = frame.searchBarFrame

    -- Error label: re-anchor below search bar; visibility managed by OnEnterPressed/OnTextChanged.
    if frame.errorLabel:IsShown() then
        frame.errorLabel:GetFrame():ClearAllPoints()
        frame.errorLabel:GetFrame():SetPoint("TOPLEFT",  lastHeader, "BOTTOMLEFT",  0, -2)
        frame.errorLabel:GetFrame():SetPoint("TOPRIGHT", lastHeader, "BOTTOMRIGHT", 0, -2)
        lastHeader = frame.errorLabel:GetFrame()
    end

    -- Expand/collapse row: re-anchored every Refresh.
    frame.expandCollapseFrame:ClearAllPoints()
    frame.expandCollapseFrame:SetPoint("TOPLEFT",  lastHeader, "BOTTOMLEFT",  0, -2)
    frame.expandCollapseFrame:SetPoint("TOPRIGHT", lastHeader, "BOTTOMRIGHT", 0, -2)
    lastHeader = frame.expandCollapseFrame

    -- Auto-zone label (WindowFilter).
    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(activeID)
    if filterLabel then
        frame.autoZoneLabel:SetContent(filterLabel, filterLabel, function()
            SocialQuestWindowFilter:Dismiss(activeID)
            SocialQuestGroupFrame:RequestRefresh()
        end)
        frame.autoZoneLabel:GetFrame():ClearAllPoints()
        frame.autoZoneLabel:GetFrame():SetPoint("TOPLEFT",  lastHeader, "BOTTOMLEFT",  0, -2)
        frame.autoZoneLabel:GetFrame():SetPoint("TOPRIGHT", lastHeader, "BOTTOMRIGHT", 0, -2)
        frame.autoZoneLabel:Show()
        lastHeader = frame.autoZoneLabel:GetFrame()
    else
        frame.autoZoneLabel:Hide()
    end

    -- User-typed filter labels (one per canonical key; lazy-created).
    local usedCanonicals = {}
    for canonical, entry in pairs(SocialQuestFilterState:GetAll()) do
        usedCanonicals[canonical] = true
        if not frame.filterLabels[canonical] then
            frame.filterLabels[canonical] = SocialQuestHeaderLabel.New(frame, { height = 18 })
        end
        local lbl = frame.filterLabels[canonical]
        local displayText = canonical .. ": " .. (entry.raw or "")
        lbl:SetContent(displayText, entry.raw or "", function()
            SocialQuestFilterState:Dismiss(canonical)
            SocialQuestGroupFrame:RequestRefresh()
        end)
        lbl:GetFrame():ClearAllPoints()
        lbl:GetFrame():SetPoint("TOPLEFT",  lastHeader, "BOTTOMLEFT",  0, -2)
        lbl:GetFrame():SetPoint("TOPRIGHT", lastHeader, "BOTTOMRIGHT", 0, -2)
        lbl:Show()
        lastHeader = lbl:GetFrame()
    end
    for canonical, lbl in pairs(frame.filterLabels) do
        if not usedCanonicals[canonical] then lbl:Hide() end
    end

    -- Scroll frame always anchored below the last visible header.
    frame.scrollFrame:ClearAllPoints()
    frame.scrollFrame:SetPoint("TOPLEFT",     lastHeader, "BOTTOMLEFT",  0, -4)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame,      "BOTTOMRIGHT", -28, 10)
    -- ── End of dynamic header anchor chain ────────────────────────────
```

- [ ] **Step 4: Reload and verify layout**

- Expand/collapse buttons visible, directly below search bar (no gap).
- Enable zone filter: auto-zone label appears between expand/collapse and scroll.
- Type `level=60` Enter: filter label `level: level=60` appears below auto-zone label.
- Dismiss with [x]: label disappears, scroll frame re-anchors correctly.

- [ ] **Step 5: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: implement lastHeader cursor anchor chain in Refresh(); migrate auto-zone to HeaderLabel"
```

---

## Task 11: GroupFrame — filterTable compound assembly + autoZone rename

**Files:**
- Modify: `UI/GroupFrame.lua`
- Modify: `UI/Tabs/MineTab.lua`
- Modify: `UI/Tabs/PartyTab.lua`
- Modify: `UI/Tabs/SharedTab.lua`

The existing `filterTable.zone` (WindowFilter exact match) is renamed to `filterTable.autoZone` in all three tabs.

- [ ] **Step 1: Replace filterTable assembly block in GroupFrame Refresh()**

Find:

```lua
    local zoneFilter  = SocialQuestWindowFilter:GetActiveFilter(activeID)
    local filterTable = nil
    if zoneFilter or (searchText ~= "") then
        filterTable = {
            zone   = zoneFilter and zoneFilter.zone or nil,
            search = searchText ~= "" and searchText or nil,
        }
    end
```

Replace with:

```lua
    local ft = nil
    -- Source 1: auto-zone exact match (WindowFilter — key renamed autoZone to avoid
    --           collision with new structured zone descriptor from FilterState)
    local zoneFilter = SocialQuestWindowFilter:GetActiveFilter(activeID)
    if zoneFilter then
        ft = ft or {}
        ft.autoZone = zoneFilter.zone
    end
    -- Source 2: user-typed structured filters (AceDB-persisted)
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
    local filterTable = ft
```

- [ ] **Step 2: Update MineTab.lua — rename filterTable.zone → filterTable.autoZone**

The current MineTab intentionally ignores the zone filter (`filterTable.zone`), but per the spec `autoZone` applies to all three tabs. Update the comment and add autoZone support:

Remove the old `-- filterTable.zone is intentionally not applied in MineTab.` comment. At the top of the tree-building loop (before the search text filter section), add:

```lua
    -- autoZone exact match (same as Party/Shared tabs)
    if filterTable and filterTable.autoZone then
        for zoneName in pairs(tree.zones) do
            if zoneName ~= filterTable.autoZone then
                tree.zones[zoneName] = nil
            end
        end
    end
```

Also update the function header comment:
```lua
function MineTab:BuildTree(filterTable)  -- filterTable.search, filterTable.autoZone, and structured filters applied
```

- [ ] **Step 3: Update PartyTab.lua — rename filterTable.zone → filterTable.autoZone**

Find all occurrences of `filterTable.zone` used as an exact-match string comparison (the WindowFilter check). Change:

```lua
local filtered = filterTable and filterTable.zone and zoneName ~= filterTable.zone
```

to:

```lua
local filtered = filterTable and filterTable.autoZone and zoneName ~= filterTable.autoZone
```

Apply to all occurrences in PartyTab:BuildTree.

- [ ] **Step 4: Update SharedTab.lua — same rename**

Apply the identical change to SharedTab:BuildTree.

- [ ] **Step 5: Reload and test**

- Auto-zone filter works on all three tabs (including Mine).
- Type `level=60` Enter. Filter persists across tab switches.
- `/reload`: filter label reappears with SQ window.

- [ ] **Step 6: Commit**

```bash
git add UI/GroupFrame.lua UI/Tabs/MineTab.lua UI/Tabs/PartyTab.lua UI/Tabs/SharedTab.lua
git commit -m "feat: compound filterTable assembly with FilterState; rename zone to autoZone; apply autoZone to MineTab"
```

---

## Task 12: TabUtils filter helpers

**Files:**
- Modify: `UI/TabUtils.lua`

- [ ] **Step 1: Append three helpers to TabUtils.lua**

```lua
------------------------------------------------------------------------
-- Advanced filter language helpers (Feature #18)
------------------------------------------------------------------------

-- String filter: case-insensitive substring match.
-- descriptor = { op = "=" | "!=", values = { ... } }
function SocialQuestTabUtils.MatchesStringFilter(value, descriptor)
    if not descriptor then return true end
    local lower = (value or ""):lower()
    local anyMatch = false
    for _, v in ipairs(descriptor.values or {}) do
        if lower:find(v:lower(), 1, true) then anyMatch = true; break end
    end
    return descriptor.op == "=" and anyMatch or not anyMatch
end

-- Numeric filter: exact, comparison, or range.
-- Single: { op="="|"<"|">"|"<="|">=", val=N }
-- Range:  { op="range", min=N, max=N }
function SocialQuestTabUtils.MatchesNumericFilter(value, descriptor)
    if not descriptor then return true end
    local n = tonumber(value) or 0
    if descriptor.op == "range" then return n >= descriptor.min and n <= descriptor.max
    elseif descriptor.op == "="  then return n == descriptor.val
    elseif descriptor.op == "<"  then return n <  descriptor.val
    elseif descriptor.op == ">"  then return n >  descriptor.val
    elseif descriptor.op == "<=" then return n <= descriptor.val
    elseif descriptor.op == ">=" then return n >= descriptor.val
    end
    return true
end

-- Enum filter: canonical value exact match.
-- descriptor = { op = "=" | "!=", value = canonicalString }
function SocialQuestTabUtils.MatchesEnumFilter(value, descriptor)
    if not descriptor then return true end
    local matches = (value == descriptor.value)
    return descriptor.op == "=" and matches or not matches
end
```

- [ ] **Step 2: Reload — no errors**

- [ ] **Step 3: Commit**

```bash
git add UI/TabUtils.lua
git commit -m "feat: add MatchesStringFilter, MatchesNumericFilter, MatchesEnumFilter to TabUtils"
```

---

## Task 13: MineTab — structured filter application

**Files:**
- Modify: `UI/Tabs/MineTab.lua`

Applicable keys: `zone`, `title`, `chain`, `level`, `group`, `type`, `step`, `status`, `tracked`. Keys `player` and `autoZone` (already handled in Task 11) are not applicable here.

- [ ] **Step 1: Add structured filter pass to MineTab:BuildTree**

Insert immediately before the existing `-- Search text filter` / `local searchText` block:

```lua
    -- ── Structured filter application (Feature #18) ──────────────────
    local ft = filterTable
    if ft then
        local T = SocialQuestTabUtils
        local AQL = SocialQuest.AQL

        local function mapGroup(entry)
            local sg = entry.suggestedGroup or 0
            if sg >= 2 then return tostring(sg) end
            if sg == 1 then return "yes" end
            return "no"
        end

        local function mapType(entry)
            if entry.chainInfo and entry.chainInfo.knownStatus == AQL.ChainStatus.Known then
                return "chain"
            elseif (entry.suggestedGroup or 0) >= 2 then return "group"
            elseif (entry.timerSeconds or 0) > 0 then return "timed"
            else return "solo"
            end
        end

        local function questPasses(entry)
            if ft.zone   and not T.MatchesStringFilter(entry.zone,  ft.zone)   then return false end
            if ft.title  and not T.MatchesStringFilter(entry.title, ft.title)  then return false end
            if ft.level  and not T.MatchesNumericFilter(entry.level, ft.level) then return false end
            if ft.step   and not T.MatchesNumericFilter(
                    entry.chainInfo and entry.chainInfo.step, ft.step)          then return false end
            if ft.group  and not T.MatchesEnumFilter(mapGroup(entry), ft.group) then return false end
            if ft.type   and not T.MatchesEnumFilter(mapType(entry),  ft.type)  then return false end
            if ft.status then
                local s = entry.isFailed and "failed" or entry.isComplete and "complete" or "incomplete"
                if not T.MatchesEnumFilter(s, ft.status) then return false end
            end
            if ft.tracked then
                local tv = entry.isTracked and "yes" or "no"
                if not T.MatchesEnumFilter(tv, ft.tracked) then return false end
            end
            return true
        end

        for zoneName, zone in pairs(tree.zones) do
            -- Filter standalone quests
            local kept = {}
            for _, e in ipairs(zone.quests) do
                if questPasses(e) then kept[#kept+1] = e end
            end
            zone.quests = kept

            -- Filter chains
            for chainID, chain in pairs(zone.chains) do
                local chainMatchesTitle = not ft.chain
                    or T.MatchesStringFilter(chain.title, ft.chain)
                local keptSteps = {}
                for _, step in ipairs(chain.steps) do
                    if (chainMatchesTitle or T.MatchesStringFilter(step.title, ft.chain))
                       and questPasses(step) then
                        keptSteps[#keptSteps+1] = step
                    end
                end
                chain.steps = keptSteps
                if #chain.steps == 0 then zone.chains[chainID] = nil end
            end

            -- Remove empty zones
            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end
    -- ── End of structured filter application ─────────────────────────
```

- [ ] **Step 2: Reload and test in WoW**

Apply `status=incomplete`. Completed quests disappear. Apply `level>=60`. Only high-level quests remain. Dismiss both. All quests return.

- [ ] **Step 3: Commit**

```bash
git add UI/Tabs/MineTab.lua
git commit -m "feat: apply structured filters (zone/title/chain/level/group/type/step/status/tracked) in MineTab"
```

---

## Task 14: PartyTab — structured filter application

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

Applicable: `zone`, `title`, `chain`, `level`, `group`, `type`, `step`, `player`. Not applicable: `status`, `tracked`.

- [ ] **Step 1: Add structured filter pass to PartyTab:BuildTree**

Using the same pattern as Task 13. The `player` filter is unique: an entry passes only if at least one player in its `players` list matches.

Insert before the existing `search` text filter:

```lua
    -- ── Structured filter application (Feature #18) ──────────────────
    local ft = filterTable
    if ft then
        local T = SocialQuestTabUtils
        local AQL = SocialQuest.AQL

        local function mapGroup(entry)
            local sg = entry.suggestedGroup or 0
            if sg >= 2 then return tostring(sg) end
            if sg == 1 then return "yes" end
            return "no"
        end

        local function mapType(entry)
            if entry.chainInfo and entry.chainInfo.knownStatus == AQL.ChainStatus.Known then
                return "chain"
            elseif (entry.suggestedGroup or 0) >= 2 then return "group"
            elseif (entry.timerSeconds or 0) > 0 then return "timed"
            else return "solo"
            end
        end

        local function playerMatches(players)
            if not ft.player then return true end
            for _, p in ipairs(players) do
                if T.MatchesStringFilter(p.name, ft.player) then return true end
            end
            return false
        end

        local function questPasses(entry)
            if ft.zone   and not T.MatchesStringFilter(entry.zone,  ft.zone)   then return false end
            if ft.title  and not T.MatchesStringFilter(entry.title, ft.title)  then return false end
            if ft.level  and not T.MatchesNumericFilter(entry.level, ft.level) then return false end
            if ft.step   and not T.MatchesNumericFilter(
                    entry.chainInfo and entry.chainInfo.step, ft.step)          then return false end
            if ft.group  and not T.MatchesEnumFilter(mapGroup(entry), ft.group) then return false end
            if ft.type   and not T.MatchesEnumFilter(mapType(entry),  ft.type)  then return false end
            if not playerMatches(entry.players) then return false end
            return true
        end

        for zoneName, zone in pairs(tree.zones) do
            local kept = {}
            for _, e in ipairs(zone.quests) do
                if questPasses(e) then kept[#kept+1] = e end
            end
            zone.quests = kept

            for chainID, chain in pairs(zone.chains) do
                local chainMatchesTitle = not ft.chain
                    or T.MatchesStringFilter(chain.title, ft.chain)
                local keptSteps = {}
                for _, step in ipairs(chain.steps) do
                    if (chainMatchesTitle or T.MatchesStringFilter(step.title, ft.chain))
                       and questPasses(step) then
                        keptSteps[#keptSteps+1] = step
                    end
                end
                chain.steps = keptSteps
                if #chain.steps == 0 then zone.chains[chainID] = nil end
            end

            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end
    -- ── End of structured filter application ─────────────────────────
```

- [ ] **Step 2: Reload and test**

Apply `player=Thad` on Party tab. Confirm only quests where Thad is listed appear.

- [ ] **Step 3: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: apply structured filters including player name filter in PartyTab BuildTree"
```

---

## Task 15: SharedTab — structured filter application

**Files:**
- Modify: `UI/Tabs/SharedTab.lua`

Identical filter set to PartyTab (zone/title/chain/level/group/type/step/player; no status/tracked).

- [ ] **Step 1: Add the same structured filter block as Task 14 to SharedTab:BuildTree**

Use the exact same code as Task 14. Insert before the existing `-- Search text filter` block.

- [ ] **Step 2: Reload and test**

Apply `player=Thad` on Shared tab. Confirm filtering works.

- [ ] **Step 3: Commit**

```bash
git add UI/Tabs/SharedTab.lua
git commit -m "feat: apply structured filters including player name filter in SharedTab BuildTree"
```

---

## Task 16: GroupFrame — help window

**Files:**
- Modify: `UI/GroupFrame.lua`

- [ ] **Step 1: Add createHelpFrame() local function (place before createFrame)**

```lua
local function createHelpFrame()
    local hf = CreateFrame("Frame", "SocialQuestFilterHelpFrame", UIParent, "BasicFrameTemplate")
    hf:SetSize(420, 500)
    hf:SetPoint("CENTER", UIParent, "CENTER", 60, 0)
    hf:SetMovable(true)
    hf:EnableMouse(true)
    hf:RegisterForDrag("LeftButton")
    hf:SetScript("OnDragStart", hf.StartMoving)
    hf:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local scale = self:GetEffectiveScale()
        SocialQuest.db.char.frameState.helpWindowPos = { x = x * scale, y = y * scale }
    end)
    -- NOTE: Do NOT wire OnShow/OnHide to write helpWindowOpen — the SQ window lifecycle
    -- code owns that field. Writing it here would race with the lifecycle snapshot.
    tinsert(UISpecialFrames, "SocialQuestFilterHelpFrame")

    local savedPos = SocialQuest.db.char.frameState.helpWindowPos
    if savedPos then
        hf:ClearAllPoints()
        local scale = hf:GetEffectiveScale()
        hf:SetPoint("CENTER", UIParent, "BOTTOMLEFT", savedPos.x / scale, savedPos.y / scale)
    end

    hf.TitleText:SetText(L["filter.help.title"])

    local scrollFrame = CreateFrame("ScrollFrame", nil, hf, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     hf, "TOPLEFT",     10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", hf, "BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(380)
    scrollFrame:SetScrollChild(content)

    local y = 0
    local function addLine(text, font, r, g, b, indent)
        local fs = content:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        fs:SetPoint("TOPLEFT",  content, "TOPLEFT",  (indent or 0) + 4, -y)
        fs:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -y)
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:SetText(text)
        fs:SetWordWrap(true)
        y = y + (fs:GetStringHeight() or 14) + 4
    end

    addLine(L["filter.help.intro"], "GameFontNormalSmall", 0.9, 0.9, 0.9)
    y = y + 8

    addLine(L["filter.help.section.syntax"], "GameFontNormal", 1, 0.82, 0)
    for _, line in ipairs({
        "key=value",  'key="value with spaces"',
        "key!=value  (or ~=)",  "key=val1|val2",
        "key<N  key>N  key<=N  key>=N",  "key=N..M",
    }) do
        addLine(line, "GameFontNormalSmall", 0.7, 0.9, 1, 8)
    end
    y = y + 8

    addLine(L["filter.help.section.keys"], "GameFontNormal", 1, 0.82, 0)
    for _, def in ipairs(_keyDefs) do
        local aliases = {}
        for i = 2, #def.names do aliases[#aliases+1] = def.names[i] end
        local aliasStr = #aliases > 0 and " (" .. table.concat(aliases, ", ") .. ")" or ""
        local desc = def.descKey and L[def.descKey] or ""
        addLine(def.names[1] .. aliasStr .. " — " .. desc, "GameFontNormalSmall", 0.9, 0.9, 0.9, 8)
    end
    y = y + 8

    addLine(L["filter.help.section.examples"], "GameFontNormal", 1, 0.82, 0)
    local i = 1
    while true do
        local exKey  = "filter.help.example." .. i
        local noteKey = exKey .. ".note"
        local expr = L[exKey]
        -- AceLocale returns the key string itself when the key is missing
        if not expr or expr == exKey then break end
        local note = L[noteKey]
        local line = (note and note ~= noteKey) and (expr .. " — " .. note) or expr
        addLine(line, "GameFontNormalSmall", 0.7, 0.9, 1, 8)
        i = i + 1
    end

    content:SetHeight(math.max(y, 10))
    return hf
end
```

- [ ] **Step 2: Wire help window lifecycle to the main SQ window**

In `Toggle()`, after the `createFrame()` / show block, add:

```lua
    -- Restore help window companion if it was open when the SQ window last closed.
    if SocialQuest.db.char.frameState.helpWindowOpen then
        if not helpFrame then helpFrame = createHelpFrame() end
        helpFrame:Show()
    end
```

In the user-initiated `OnHide` handler (the `leavingWorld == false` branch), add before/after the `windowOpen = false` line:

```lua
        -- Snapshot and hide help window companion on user-initiated SQ close.
        SocialQuest.db.char.frameState.helpWindowOpen = helpFrame ~= nil and helpFrame:IsShown()
        if helpFrame then helpFrame:Hide() end
```

In `OnLeavingWorld()`, add (snapshot both true and false):

```lua
    SocialQuest.db.char.frameState.helpWindowOpen = helpFrame ~= nil and helpFrame:IsShown()
    if helpFrame then helpFrame:Hide() end
```

In `RestoreAfterTransition()`, after showing the main frame:

```lua
    if SocialQuest.db.char.frameState.helpWindowOpen then
        if not helpFrame then helpFrame = createHelpFrame() end
        helpFrame:Show()
    end
```

- [ ] **Step 3: Reload and test**

- Click `[?]`: help window opens with syntax, keys, and examples sections.
- Press Escape: help window closes (UISpecialFrames).
- Drag: position saves across `/reload`.
- Close SQ window: help window hides; reopen SQ window: help window reopens.
- `/reload` with help open: both windows reopen.
- `/reload` with help closed: help stays closed.

- [ ] **Step 4: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: add filter syntax help window with UISpecialFrames Escape, movable, lifecycle tied to SQ window"
```

---

## Task 17: CLAUDE.md update + TOC version bump

**Files:**
- Modify: `CLAUDE.md`
- Modify: `SocialQuest.toc`

- [ ] **Step 1: Bump version in SocialQuest.toc**

Today is 2026-03-27. Current version is 2.12.17. Increment revision:

```
## Version: 2.12.18
```

- [ ] **Step 2: Add version history entry to CLAUDE.md**

Add at the top of the Version History section:

```markdown
### Version 2.12.18 (March 2026 — FilterTextbox branch)
- Feature: Advanced filter language (Feature #18). The SQ search bar now accepts structured filter expressions (e.g. `level>=60`, `zone=Elwynn|Deadmines`, `status=incomplete`) entered by pressing Enter. Valid expressions are stored persistently in AceDB `char.frameState.activeFilters` (one entry per canonical key) and displayed as dismissible filter labels in the fixed header. Multiple filters AND together with each other, the real-time search text, and the auto-zone filter. New modules: `UI/FilterParser.lua` (pure Lua parser, standalone test runner at `tests/FilterParser_test.lua`), `UI/FilterState.lua` (AceDB-backed compound state with Apply/Dismiss/GetAll/IsEmpty — no mass reset), `UI/HeaderLabel.lua` (dismissible label widget factory). The auto-zone label, error label, and all user-typed filter labels are `HeaderLabel` instances stacked via a `lastHeader` cursor in `Refresh()`. A `[?]` button opens a movable reference panel (`SocialQuestFilterHelpFrame`) registered in `UISpecialFrames`; its open state persists and it opens/closes with the main SQ window. `filterTable.zone` (WindowFilter exact-match key) renamed to `filterTable.autoZone` to avoid collision with the new structured `zone` descriptor; `autoZone` now applies to all three tabs including Mine. Three helpers added to `TabUtils`: `MatchesStringFilter`, `MatchesNumericFilter`, `MatchesEnumFilter`. All three tab `BuildTree` functions apply the new structured filters per the per-tab applicability table (status/tracked: Mine only; player: Party/Shared only).
```

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump version to 2.12.18, update CLAUDE.md with Feature #18 implementation notes"
```

---

## Running the test suite

After Task 1 (or any time):

```bash
# Install Lua if needed: winget install DEVCOM.Lua
lua tests/FilterParser_test.lua
```

Expected final output after Task 4: `N passed, 0 failed`

All WoW-dependent functionality is validated in-game via `/reload` and manual exercise.
