# Filter & Operator and Shareable Key — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `&` same-key AND operator to the filter language, add a `shareable` filter key for the Party tab, and document both in the help window across all 12 locales.

**Architecture:** The `&` operator is handled entirely in `FilterParser.lua` — it produces a `compound_and` descriptor that wraps an ordered list of individual descriptors. The four `Matches*` helpers in `TabUtils.lua` each gain a five-line compound_and guard at the top. The `shareable` key is pre-computed in `PartyTab:BuildTree` (setting `entry.hasShareableMembers`) so both the [Share] button in `Render` and the filter in `BuildTree` read the same value without duplication. Locale strings are added to all 12 files.

**Tech Stack:** Lua 5.1 (WoW TBC), AceLocale-3.0, standalone `lua` for tests (`tests/FilterParser_test.lua`).

---

## File Map

| File | Change |
|---|---|
| `UI/FilterParser.lua` | Add `&` detection and compound_and parsing; add two new error codes |
| `UI/TabUtils.lua` | Add compound_and guard to all four `Matches*` helpers |
| `UI/Tabs/PartyTab.lua` | Pre-compute `entry.hasShareableMembers` in `BuildTree`; read it in `buildQuestCallbacks`; apply `ft.shareable` filter in `questPasses` |
| `UI/GroupFrame.lua` | Add `shareable` key def in `buildKeyDefs()`; add `key=val1&val2` line to syntax help rows |
| `tests/FilterParser_test.lua` | Add `shareable` to keyDefs bootstrap; add `&` operator test cases |
| `Locales/enUS.lua` | New strings: two error codes, shareable key/desc, three `&` examples, one shareable example, syntax help row |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | Same keys as `= true` (11 files) |
| `SocialQuest.toc` | Version bump |
| `CLAUDE.md` | Version history entry |

---

## Task 1: Add `&` parsing to FilterParser

**Files:**
- Modify: `UI/FilterParser.lua`
- Modify: `tests/FilterParser_test.lua`

**Background:** `FilterParser:Parse` currently handles string, numeric, and enum fields and returns a typed descriptor. We need to add `&` detection after the first fragment is parsed and produce a `compound_and` descriptor. The `|` OR operator uses `parseValues` which scans for `|` in the value string. The `&` operator sits at a higher level — it splits the entire expression after the key+op+value chunk into subsequent `op value` fragments.

**Key invariants to maintain:**
- `&` inside a quoted string must NOT split. Only scan for unquoted `&`.
- `|` and `&` may not appear together — return `MIXED_AND_OR` error.
- All fragments must use the same canonical key.
- Operator is inherited from the first fragment if omitted in subsequent fragments.
- The existing nil fast-path (`no = sign → return nil`) is untouched.

- [ ] **Step 1: Write failing tests for `&` in tests/FilterParser_test.lua**

Add the following block at the end of the test file, before the final `print` line (line 245):

```lua
-- ── & operator (compound_and) ────────────────────────────────────────

-- Helper: confirm a result is a compound_and with N parts
local function assert_compound(label, result, canonical, nParts)
    if result and result.filter
       and result.filter.canonical == canonical
       and result.filter.descriptor.type == "compound_and"
       and #result.filter.descriptor.parts == nParts then
        pass = pass + 1
    else
        fail = fail + 1
        local got = result and result.filter and result.filter.descriptor.type or "nil"
        print(string.format("FAIL [%s]: expected compound_and(%d) canonical=%s, got %s",
            label, nParts, canonical, got))
    end
end

-- Numeric & with explicit operators on both sides
r = P:Parse("level>=55&<=62")
assert_compound("numeric & 2-part", r, "level", 2)
assert_eq("part1 op", r and r.filter.descriptor.parts[1].op, ">=")
assert_eq("part1 val", r and r.filter.descriptor.parts[1].val, 55)
assert_eq("part2 op", r and r.filter.descriptor.parts[2].op, "<=")
assert_eq("part2 val", r and r.filter.descriptor.parts[2].val, 62)

-- Enum & with inherited operator
r = P:Parse("type=chain&group")
assert_compound("enum & inherited op", r, "type", 2)
assert_eq("enum part1 op", r and r.filter.descriptor.parts[1].op, "=")
assert_eq("enum part1 val", r and r.filter.descriptor.parts[1].value, "chain")
assert_eq("enum part2 op", r and r.filter.descriptor.parts[2].op, "=")
assert_eq("enum part2 val", r and r.filter.descriptor.parts[2].value, "group")

-- String & with inherited operator
r = P:Parse("title=dragon&slayer")
assert_compound("string & inherited op", r, "title", 2)
assert_eq("string part1 val[1]", r and r.filter.descriptor.parts[1].values[1], "dragon")
assert_eq("string part2 val[1]", r and r.filter.descriptor.parts[2].values[1], "slayer")

-- Whitespace around &
r = P:Parse("level >= 55 & <= 62")
assert_compound("& whitespace tolerance", r, "level", 2)
assert_eq("& ws part1 val", r and r.filter.descriptor.parts[1].val, 55)

-- raw field preserved
r = P:Parse("level>=55&<=62")
assert_eq("& raw field", r and r.filter.raw, "level>=55&<=62")

-- MIXED_AND_OR error
assert_error("MIXED_AND_OR |&", P:Parse("level>=55&<=62|58"), "MIXED_AND_OR")
assert_error("MIXED_AND_OR &|", P:Parse("type=chain|group&solo"), "MIXED_AND_OR")

-- EMPTY_VALUE on trailing &
assert_error("& trailing EMPTY_VALUE", P:Parse("level>=55&"), "EMPTY_VALUE")
```

- [ ] **Step 2: Run tests to verify the new cases fail**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
```

Expected: existing tests all pass, new `&` tests FAIL with "expected compound_and" messages.

- [ ] **Step 3: Add MIXED_AND_OR check and `&` splitting to FilterParser.lua**

In `UI/FilterParser.lua`, modify `Parse` to detect `&` and build compound_and. Make these changes in order:

**3a.** After the `extractKeyAndOp` call (line 94) and key lookup (line 107–108), add a `MIXED_AND_OR` pre-check immediately before type-dispatch (around line 123). Insert before the `local isComparison = ...` line:

```lua
    -- Detect & before | check so MIXED_AND_OR has priority.
    local hasAmpersand = valueStr:find("&", 1, true)
    -- Check for & outside quotes
    local hasUnquotedAmpersand = false
    if hasAmpersand then
        -- Scan for unquoted &: step through the value string
        local pos2, inQ = 1, false
        while pos2 <= #valueStr do
            local c = valueStr:sub(pos2, pos2)
            if c == '"' then inQ = not inQ
            elseif c == '\\' and inQ then pos2 = pos2 + 1  -- skip escaped char
            elseif c == '&' and not inQ then hasUnquotedAmpersand = true; break
            end
            pos2 = pos2 + 1
        end
    end
    -- & and | may not coexist (check raw valueStr for unquoted |)
    if hasUnquotedAmpersand then
        local hasPipe = false
        local pos2, inQ = 1, false
        while pos2 <= #valueStr do
            local c = valueStr:sub(pos2, pos2)
            if c == '"' then inQ = not inQ
            elseif c == '\\' and inQ then pos2 = pos2 + 1
            elseif c == '|' and not inQ then hasPipe = true; break
            end
            pos2 = pos2 + 1
        end
        if hasPipe then return makeError("MIXED_AND_OR", {}) end
    end
```

**3b.** Add a helper function after `makeError` (around line 17) and before `parseOneValue`:

```lua
-- Split valueStr on unquoted & characters.
-- Returns a table of fragment strings (trimmed), or nil if no unquoted & found.
local function splitOnAmpersand(str)
    local parts = {}
    local current = {}
    local inQ = false
    local i = 1
    local found = false
    while i <= #str do
        local c = str:sub(i, i)
        if c == '"' then
            inQ = not inQ
            current[#current+1] = c
        elseif c == '\\' and inQ and i+1 <= #str then
            current[#current+1] = c
            current[#current+1] = str:sub(i+1, i+1)
            i = i + 2
            goto continue_split
        elseif c == '&' and not inQ then
            parts[#parts+1] = table.concat(current):match("^%s*(.-)%s*$")
            current = {}
            found = true
        else
            current[#current+1] = c
        end
        i = i + 1
        ::continue_split::
    end
    if not found then return nil end
    parts[#parts+1] = table.concat(current):match("^%s*(.-)%s*$")
    return parts
end
```

**3c.** After the `MIXED_AND_OR` check (added in 3a), add the compound_and dispatch just before the type-dispatch (`if keyDef.type == "string"` etc.). The full block to insert:

```lua
    -- ── compound_and: & splits the value into multiple fragments ──────
    if hasUnquotedAmpersand then
        local fragments = splitOnAmpersand(valueStr)
        -- fragments[1] is the already-extracted first value; fragments[2..n] are "op val" or "val"
        local parts = {}

        -- Parse the first fragment as a standalone expression (re-use existing type paths).
        -- We reconstruct "key op fragments[1]" and call the existing parse logic inline.
        local firstValueStr = fragments[1]
        local firstResult = SocialQuestFilterParser:_ParseFragment(keyDef, op, normOp, firstValueStr)
        if firstResult.error then return firstResult end
        parts[#parts+1] = firstResult

        -- Parse subsequent fragments, each as "op val" or "val" (inheriting op).
        for fi = 2, #fragments do
            local frag = fragments[fi]
            if not frag or frag == "" then
                return makeError("EMPTY_VALUE", {op})
            end
            -- Try to extract a leading operator from the fragment (longest first).
            local _fragOpPats = {
                "^(~=)%s*(.*)", "^(!=)%s*(.*)",
                "^(<=)%s*(.*)", "^(>=)%s*(.*)",
                "^(<)%s*(.*)",  "^(>)%s*(.*)",
                "^(=)%s*(.*)",
            }
            local fragOp, fragVal = nil, nil
            for _, fpat in ipairs(_fragOpPats) do
                fragOp, fragVal = frag:match(fpat)
                if fragOp then break end
            end
            if not fragOp then
                -- No operator present: inherit from first fragment.
                fragOp = normOp
                fragVal = frag
            else
                fragOp = (fragOp == "~=" and "!=" or fragOp)
            end
            -- Validate operator/type compatibility.
            local fragIsComp = (fragOp=="<" or fragOp==">" or fragOp=="<=" or fragOp==">=")
            if fragIsComp and keyDef.type ~= "numeric" then
                return makeError("TYPE_MISMATCH", {fragOp, keyDef.canonical})
            end
            local fragResult = SocialQuestFilterParser:_ParseFragment(keyDef, fragOp, fragOp, fragVal)
            if fragResult.error then return fragResult end
            parts[#parts+1] = fragResult
        end

        return { filter = { canonical=keyDef.canonical,
                            descriptor={ type="compound_and", parts=parts },
                            raw=text } }
    end
    -- ── End compound_and ──────────────────────────────────────────────
```

**3d.** Add the `_ParseFragment` helper as a method on `SocialQuestFilterParser` at the bottom of `FilterParser.lua`, before the final `return nil`:

```lua
-- Internal helper: parse a single value fragment for a given keyDef/op pair.
-- Returns a descriptor table on success, or { error=true, ... } on failure.
-- Does NOT produce a full filter result — callers wrap descriptors into compound_and.parts.
function SocialQuestFilterParser:_ParseFragment(keyDef, rawOp, normOp, valueStr)
    if not valueStr or valueStr:match("^%s*$") then
        return makeError("EMPTY_VALUE", {rawOp})
    end
    if keyDef.type == "string" then
        local values, err = parseValues(valueStr, rawOp)
        if err then return err end
        return { op=normOp, values=values }
    end
    if keyDef.type == "numeric" then
        local values, err = parseValues(valueStr, rawOp)
        if err then return err end
        local v = values[1]
        local minS, maxS = v:match("^(.-)%.%.(.+)$")
        if minS then
            local minN = tonumber(minS:match("^%s*(.-)%s*$"))
            local maxN = tonumber(maxS:match("^%s*(.-)%s*$"))
            if not minN then return makeError("INVALID_NUMBER", {keyDef.canonical, minS}) end
            if not maxN then return makeError("INVALID_NUMBER", {keyDef.canonical, maxS}) end
            if minN > maxN then return makeError("RANGE_REVERSED", {minN, maxN}) end
            return { op="range", min=minN, max=maxN }
        else
            local n = tonumber(v)
            if not n then return makeError("INVALID_NUMBER", {keyDef.canonical, v}) end
            return { op=normOp, val=n }
        end
    end
    if keyDef.type == "enum" then
        local values, err = parseValues(valueStr, rawOp)
        if err then return err end
        local v = values[1]:lower()
        local canonicalVal = keyDef.enumMap and keyDef.enumMap[v]
        if not canonicalVal then
            return makeError("INVALID_ENUM", {keyDef.canonical, values[1]})
        end
        return { op=normOp, value=canonicalVal }
    end
    return makeError("EMPTY_VALUE", {rawOp})
end
```

Also add `MIXED_AND_OR` to `makeError`'s error codes — no code change needed since `makeError` is generic; just add the error string to the locale (Task 5).

- [ ] **Step 4: Run tests to verify all new cases pass**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
```

Expected: all tests PASS, 0 failures. If failures remain, read the error messages carefully — they show which `assert_*` call failed and what was received.

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/FilterParser.lua tests/FilterParser_test.lua
git commit -m "feat: add & compound_and operator to FilterParser"
```

---

## Task 2: Add `compound_and` guard to TabUtils helpers

**Files:**
- Modify: `UI/TabUtils.lua` (lines 105–188)

**Background:** The four helpers `MatchesStringFilter`, `MatchesNumericFilter`, `MatchesEnumFilter`, and `MatchesTypeFilter` each currently handle the known descriptor shapes. A `compound_and` descriptor has `descriptor.type == "compound_and"` and `descriptor.parts = { desc1, desc2, ... }`. Each helper must check for this at entry and AND all parts.

There are no standalone unit tests for `TabUtils` (in-game only), so the test is: after implementing, run the full parser test suite to confirm no regressions, then verify in-game (Task 6 covers this).

- [ ] **Step 1: Add guard to MatchesStringFilter (TabUtils.lua:105)**

Replace `MatchesStringFilter` (lines 105–113):

```lua
function SocialQuestTabUtils.MatchesStringFilter(value, descriptor)
    if not descriptor then return true end
    if descriptor.type == "compound_and" then
        for _, part in ipairs(descriptor.parts) do
            if not SocialQuestTabUtils.MatchesStringFilter(value, part) then return false end
        end
        return true
    end
    local lower = (value or ""):lower()
    local anyMatch = false
    for _, v in ipairs(descriptor.values or {}) do
        if lower:find(v:lower(), 1, true) then anyMatch = true; break end
    end
    if descriptor.op == "=" then return anyMatch else return not anyMatch end
end
```

- [ ] **Step 2: Add guard to MatchesNumericFilter (TabUtils.lua:118)**

Replace `MatchesNumericFilter` (lines 118–131):

```lua
function SocialQuestTabUtils.MatchesNumericFilter(value, descriptor)
    if not descriptor then return true end
    if descriptor.type == "compound_and" then
        for _, part in ipairs(descriptor.parts) do
            if not SocialQuestTabUtils.MatchesNumericFilter(value, part) then return false end
        end
        return true
    end
    if value == nil then return false end
    local n = tonumber(value)
    if not n then return false end
    if descriptor.op == "range" then return n >= descriptor.min and n <= descriptor.max
    elseif descriptor.op == "="  then return n == descriptor.val
    elseif descriptor.op == "<"  then return n <  descriptor.val
    elseif descriptor.op == ">"  then return n >  descriptor.val
    elseif descriptor.op == "<=" then return n <= descriptor.val
    elseif descriptor.op == ">=" then return n >= descriptor.val
    end
    return true
end
```

- [ ] **Step 3: Add guard to MatchesEnumFilter (TabUtils.lua:135)**

Replace `MatchesEnumFilter` (lines 135–139):

```lua
function SocialQuestTabUtils.MatchesEnumFilter(value, descriptor)
    if not descriptor then return true end
    if descriptor.type == "compound_and" then
        for _, part in ipairs(descriptor.parts) do
            if not SocialQuestTabUtils.MatchesEnumFilter(value, part) then return false end
        end
        return true
    end
    local matches = (value == descriptor.value)
    return descriptor.op == "=" and matches or not matches
end
```

- [ ] **Step 4: Add guard to MatchesTypeFilter (TabUtils.lua:145)**

Insert the compound_and guard immediately after the `if not descriptor then return true end` line (line 146):

```lua
    if descriptor.type == "compound_and" then
        for _, part in ipairs(descriptor.parts) do
            if not SocialQuestTabUtils.MatchesTypeFilter(entry, part) then return false end
        end
        return true
    end
```

- [ ] **Step 5: Run parser tests to confirm no regressions**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add UI/TabUtils.lua
git commit -m "feat: add compound_and guard to TabUtils Matches* helpers"
```

---

## Task 3: Add `shareable` to PartyTab

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

**Background:** `PartyTab:BuildTree` already calls `buildPlayerRowsForQuest(questID, localHasIt)` (line 342) which checks shareability per member and sets `player.needsShare`. We need to:

1. After `buildPlayerRowsForQuest` returns, compute `entry.hasShareableMembers` by checking:
   - `entry.logIndex ~= nil` (local has the quest)
   - `SocialQuestWowAPI:IsQuestIdShareable(questID)` (AQL delegates this via SQWowAPI wrapper; check that this is the right call — in the codebase `AQL:IsQuestIdShareable` is used directly in `buildPlayerRowsForQuest` at line 196; use the same call)
   - any `player.needsShare == true` in `entry.players`

2. In `buildQuestCallbacks` (line 475), replace the re-computation of shareability with a read from `entry.hasShareableMembers`.

3. In `questPasses` (line 391), add `ft.shareable` check using `MatchesEnumFilter`.

**Important:** `buildQuestCallbacks` is a closure defined inside `Render`, which receives `entry` as a parameter. `entry.hasShareableMembers` is set in `BuildTree` — `Render` calls `BuildTree` first (line 468), so the field is present by the time `buildQuestCallbacks` is called.

- [ ] **Step 1: Pre-compute `entry.hasShareableMembers` in BuildTree**

In `BuildTree`, after the `players = buildPlayerRowsForQuest(questID, localHasIt)` line (line 342), add:

```lua
            -- Pre-compute shareability so Render's buildQuestCallbacks doesn't redo this work.
            local shareable_pre = false
            if entry.logIndex then
                local AQL_s = SocialQuest.AQL
                if AQL_s and AQL_s:IsQuestIdShareable(questID) then
                    for _, pl in ipairs(entry.players) do
                        if pl.needsShare then shareable_pre = true; break end
                    end
                end
            end
            entry.hasShareableMembers = shareable_pre
```

Note: `entry` is built on lines 326–343; the `players` field is assigned last (line 342). Add the pre-computation block immediately after the closing `}` of the entry table literal (after line 343), before the chain/quest insertion block.

- [ ] **Step 2: Simplify buildQuestCallbacks to read from entry**

`buildQuestCallbacks` currently (lines 475–494) re-evaluates shareability. Replace lines 475–494 with:

```lua
    local function buildQuestCallbacks(entry)
        if not entry.hasShareableMembers then return {} end
        local AQL = SocialQuest.AQL
        return {
            onShare = function()
                -- Safety check: re-verify shareability at click time.
                if not AQL:IsQuestIdShareable(entry.questID) then return end
                local prev = AQL:GetQuestLogSelection()
                AQL:SetQuestLogSelection(entry.logIndex)
                SQWowAPI.QuestLogPushQuest()
                AQL:SetQuestLogSelection(prev)
            end,
        }
    end
```

- [ ] **Step 3: Add `ft.shareable` check to questPasses**

In the `questPasses` local function (line 391), add the `shareable` check after the existing `ft.type` check:

```lua
            if ft.shareable and not T.MatchesEnumFilter(
                    entry.hasShareableMembers and "yes" or "no", ft.shareable) then
                return false
            end
```

The full updated `questPasses` block becomes:

```lua
        local function questPasses(entry)
            if ft.zone   and not T.MatchesStringFilter(entry.zone,  ft.zone)   then return false end
            if ft.title  and not T.MatchesStringFilter(entry.title, ft.title)  then return false end
            if ft.level  and not T.MatchesNumericFilter(entry.level, ft.level) then return false end
            if ft.step   and not T.MatchesNumericFilter(
                    entry.chainInfo and entry.chainInfo.step, ft.step)          then return false end
            if ft.group  and not T.MatchesEnumFilter(mapGroup(entry), ft.group) then return false end
            if ft.type   and not T.MatchesTypeFilter(entry, ft.type)  then return false end
            if ft.shareable and not T.MatchesEnumFilter(
                    entry.hasShareableMembers and "yes" or "no", ft.shareable) then return false end
            if not playerMatches(entry.players) then return false end
            return true
        end
```

- [ ] **Step 4: Run parser tests (regression check)**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: add shareable filter key to PartyTab"
```

---

## Task 4: Add `shareable` key def and syntax row to GroupFrame

**Files:**
- Modify: `UI/GroupFrame.lua`

**Background:** `buildKeyDefs()` (line 96) returns the list of key definitions used by `FilterParser:Initialize` and the help window. A new entry for `shareable` must be added. The syntax help rows (lines 225–232) must gain a `key=val1&val2` line.

`tabMask` is a documentation field — it appears in `buildKeyDefs` for the `descKey` note and is shown in the help window. The actual tab-gating (not adding `ft.shareable` for non-Party tabs) is handled by FilterState being per-tab; since Party, Mine, and Shared have separate `activeFilters[tabId]` namespaces, a `shareable` filter applied on the Party tab never appears in `ft` for Mine or Shared tab renders. No runtime tabMask enforcement is needed in the filterTable assembly loop.

- [ ] **Step 1: Add `shareable` to buildKeyDefs**

Inside `buildKeyDefs()`, after the `tracked` entry (line 133–136), add before the closing `}` of the `defs` table:

```lua
        { canonical="shareable", names={L["filter.key.shareable"]},
          type="enum",
          enumMap={ [L["filter.val.yes"]]="yes", [L["filter.val.no"]]="no" },
          descKey="filter.key.shareable.desc" },
```

- [ ] **Step 2: Add `key=val1&val2` to syntax help rows**

In the `for _, line in ipairs({...})` block (lines 225–232), add the `&` line after `"key=val1|val2"`:

```lua
    for _, line in ipairs({
        "key=value",  'key="value with spaces"',
        "key!=value  (or ~=)",  "key=val1|val2",
        "key=val1&val2  (AND)",
        "key=yes  key=no",
        "key<N  key>N  key<=N  key>=N",  "key=N..M",
    }) do
```

- [ ] **Step 3: Run parser tests (regression check)**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: add shareable key def and & syntax row to GroupFrame"
```

---

## Task 5: Add locale strings to enUS.lua

**Files:**
- Modify: `Locales/enUS.lua`

**Background:** `enUS.lua` uses explicit string values; all other locales use `= true` (AceLocale fallback to enUS). Add at the end of the filter section, after `filter.err.label` (line 298) and before `filter.help.title` (line 299).

The help examples loop (GroupFrame line 248–260) iterates `filter.help.example.1` upward until a key is missing. Examples 1–11 already exist; we add 12, 13, 14, 15.

- [ ] **Step 1: Add new error codes after line 298 (`filter.err.label`)**

```lua
L["filter.err.MIXED_AND_OR"]     = "cannot mix & and | in the same expression"
L["filter.err.AND_KEY_MISMATCH"] = "all & fragments must use the same key"
```

- [ ] **Step 2: Add shareable key strings after the existing key/desc block**

Find the `filter.key.tracked` lines (~line 286–287) and add after:

```lua
L["filter.key.shareable"]      = "shareable"
L["filter.key.shareable.desc"] = "Quest can be shared with a party member right now (Party tab only)"
```

- [ ] **Step 3: Add new help examples after example 11 (line 329)**

```lua
L["filter.help.example.12"]      = "type=dungeon&gather"
L["filter.help.example.12.note"] = "Show dungeon quests that also have gather objectives"
L["filter.help.example.13"]      = "level>=55&<=62"
L["filter.help.example.13.note"] = "Show quests in the level 55–62 range (same as level=55..62)"
L["filter.help.example.14"]      = "title=dragon&slayer"
L["filter.help.example.14.note"] = "Show quests with both 'dragon' and 'slayer' in the title"
L["filter.help.example.15"]      = "shareable=yes"
L["filter.help.example.15.note"] = "Show quests you can share with a party member right now (Party tab)"
```

- [ ] **Step 4: Run parser tests (regression check)**

```
lua tests/FilterParser_test.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Locales/enUS.lua
git commit -m "feat: add & and shareable locale strings to enUS"
```

---

## Task 6: Add locale strings to the 11 non-enUS locales

**Files:**
- Modify: `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`, `Locales/esMX.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`, `Locales/koKR.lua`, `Locales/ruRU.lua`, `Locales/jaJP.lua`

**Background:** Each locale file uses `= true` for new keys (AceLocale falls back to enUS). All 11 files need the same set of keys. The `shareable` key name (what players type) should be translated to a natural equivalent in each language where possible — but `= true` (English fallback) is acceptable initially. The `desc` and example note strings are display-only; `= true` is fine.

Add each block to the matching position in each file (after `filter.key.tracked` lines, after `filter.err.label`, before `filter.help.title`, and after example 11).

- [ ] **Step 1: Add to deDE.lua**

After `L["filter.key.tracked"]` lines, add:
```lua
L["filter.key.shareable"]      = "teilbar"
L["filter.key.shareable.desc"] = true
```

After `L["filter.err.label"]`, add:
```lua
L["filter.err.MIXED_AND_OR"]     = true
L["filter.err.AND_KEY_MISMATCH"] = true
```

After example 11, add:
```lua
L["filter.help.example.12"]      = true
L["filter.help.example.12.note"] = true
L["filter.help.example.13"]      = true
L["filter.help.example.13.note"] = true
L["filter.help.example.14"]      = true
L["filter.help.example.14.note"] = true
L["filter.help.example.15"]      = true
L["filter.help.example.15.note"] = true
```

- [ ] **Step 2: Add to frFR.lua** (same pattern)

```lua
L["filter.key.shareable"]      = "partageable"
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 3: Add to esES.lua and esMX.lua** (same pattern; esMX mirrors esES)

```lua
L["filter.key.shareable"]      = "compartible"
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`. Apply identical changes to both esES.lua and esMX.lua.

- [ ] **Step 4: Add to zhCN.lua and zhTW.lua**

```lua
L["filter.key.shareable"]      = true   -- English "shareable" used; no standard WoW Chinese term
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 5: Add to ptBR.lua**

```lua
L["filter.key.shareable"]      = "compartilhável"
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 6: Add to itIT.lua**

```lua
L["filter.key.shareable"]      = "condivisibile"
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 7: Add to koKR.lua**

```lua
L["filter.key.shareable"]      = true   -- English fallback
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 8: Add to ruRU.lua**

```lua
L["filter.key.shareable"]      = true   -- English fallback
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 9: Add to jaJP.lua**

```lua
L["filter.key.shareable"]      = true   -- English fallback
L["filter.key.shareable.desc"] = true
```
Error codes and examples: all `= true`.

- [ ] **Step 10: Run parser tests (regression check)**

```
lua tests/FilterParser_test.lua
```

Expected: all pass.

- [ ] **Step 11: Commit**

```bash
git add Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua \
        Locales/zhCN.lua Locales/zhTW.lua Locales/ptBR.lua Locales/itIT.lua \
        Locales/koKR.lua Locales/ruRU.lua Locales/jaJP.lua
git commit -m "feat: add & and shareable locale strings to 11 non-enUS locales"
```

---

## Task 7: Add `shareable` to test keyDefs bootstrap; version bump; CLAUDE.md

**Files:**
- Modify: `tests/FilterParser_test.lua`
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

**Background:** The test keyDefs bootstrap (lines 14–29) does not include `shareable` — the parser tests for `shareable=yes` need it. Add it. Then bump the version and update CLAUDE.md.

- [ ] **Step 1: Add `shareable` to test keyDefs**

In `tests/FilterParser_test.lua`, after the `tracked` entry (line 28), add before the closing `})`:

```lua
    { canonical="shareable",names={"shareable"},   type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no" } },
```

Also add a shareable test case at the end of the enum tests (before the `&` tests added in Task 1):

```lua
r = P:Parse("shareable=yes")
assert_filter("shareable= yes",     r, "shareable", "=")
assert_eq("shareable= value",       r and r.filter.descriptor.value, "yes")

r = P:Parse("shareable=no")
assert_filter("shareable= no",      r, "shareable", "=")
assert_eq("shareable=no value",     r and r.filter.descriptor.value, "no")
```

- [ ] **Step 2: Run tests to confirm shareable parses correctly**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
```

Expected: all pass.

- [ ] **Step 3: Bump version in SocialQuest.toc**

Current version is `2.14.2`. Today is 2026-03-28 — this is the first functional change today, so minor version increments and revision resets to 0: bump to `2.15.0`.

Find and replace in `SocialQuest.toc`:
```
## Version: 2.14.2
```
→
```
## Version: 2.15.0
```

- [ ] **Step 4: Update CLAUDE.md version history**

Add a new entry before the existing `### Version 2.14.2` block:

```markdown
### Version 2.15.0 (March 2026 — Improvements branch)
- Feature: `&` same-key AND operator in the advanced filter language. A single filter label can now express multiple conditions on the same key: `type=dungeon&gather` (dungeon quests with gather objectives), `level>=55&<=62` (level range), `title=dragon&slayer` (title contains both words). The key is written once; operator is inherited by subsequent fragments when omitted. `&` and `|` may not be combined in the same expression (`MIXED_AND_OR` error). `compound_and` descriptor type added to `FilterParser`; all four `Matches*` helpers in `TabUtils` handle it recursively. `FilterState` and `HeaderLabel` unchanged.
- Feature: `shareable` filter key (Party tab only). `shareable=yes` shows quests the local player can share with at least one party member right now — same condition as the [Share] button (local has it, AQL reports it shareable, at least one party member has `needsShare=true`). `entry.hasShareableMembers` pre-computed in `PartyTab:BuildTree`; `buildQuestCallbacks` reads the pre-computed value. Help window updated with three `&` examples and one `shareable` example across all 12 locales.
```

- [ ] **Step 5: Commit**

```bash
git add tests/FilterParser_test.lua SocialQuest.toc CLAUDE.md
git commit -m "chore: bump to 2.15.0, update CLAUDE.md for & and shareable features"
```

---

## In-game verification checklist

After loading the addon in WoW TBC:

- [ ] `type=dungeon&gather` — shows only dungeon quests with a gather objective
- [ ] `level>=55&<=62` — shows quests in the 55–62 level range; label shows `level>=55&<=62`
- [ ] `title=dragon&slayer` — shows quests with both words in the title
- [ ] `type=dungeon&gather` and separately `type=gather` applied as two labels — both filter simultaneously (AND between labels)
- [ ] `type=dungeon|raid` — still works (OR unaffected)
- [ ] `level>=55&<=62|70` — shows `MIXED_AND_OR` error label
- [ ] `shareable=yes` on Party tab — shows only quests eligible to share with at least one party member
- [ ] `shareable=yes` on Mine tab — shows nothing (filter never added to ft for Mine tab; no `shareable` key in Mine tab's FilterState)
- [ ] `[?]` help window — syntax section shows `key=val1&val2  (AND)` line; examples section shows examples 12–15
- [ ] Dismiss a `compound_and` filter label with `[x]` — filter removed, list reverts
