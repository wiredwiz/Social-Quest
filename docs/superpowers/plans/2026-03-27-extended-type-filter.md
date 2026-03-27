# Extended Type Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the `type` filter with 9 new quest type predicates (escort, dungeon, raid, elite, daily, pvp, kill, gather, interact) across all three tabs (Mine, Party, Shared), replacing the single-value priority-chain `mapType()` with an independent multi-predicate `MatchesTypeFilter` helper in TabUtils.

**Architecture:** Add `SocialQuestTabUtils.MatchesTypeFilter(entry, descriptor)` to `UI/TabUtils.lua` — each type value is an independent boolean predicate, allowing a quest to match multiple types simultaneously. All three tab `BuildTree` functions drop their local `mapType()` and call the new helper. Nine new `filter.val.*` locale keys and one help-note key are added. The `buildKeyDefs()` type `enumMap` in `GroupFrame.lua` is expanded. The filter help window gains a note about the Questie/QuestWeaver requirement.

**Tech Stack:** Lua, AceDB, AQL (AbsoluteQuestLog), Questie/QuestWeaver provider (required for AQL-based and objective predicates)

---

## Background

**How to verify:** This addon runs inside WoW — there is no offline unit test runner for tab/filter code. Verification is done by code review (logic checks noted per task) and in-game testing after all tasks complete. For in-game testing: use `/sq` to open the SQ window, type a filter expression in the search bar, press Enter.

**AQL provider chain for `GetQuestInfo`:** Tier 1 = active quest cache (instant), Tier 3 = Questie/QuestWeaver static DB (slightly slower first call, cached after). Works for any questID regardless of whether the local player has that quest. Without Questie/QuestWeaver, returns nil and AQL-based predicates silently never match.

**Key file locations:**
- `Locales/enUS.lua:281` — `filter.key.type.desc` (currently: `"Quest type (chain, group, solo, timed)"`)
- `Locales/enUS.lua:291-294` — existing `filter.val.chain/group/solo/timed` keys
- `Locales/enUS.lua:321-324` — `filter.help.example.5` and `filter.help.example.6` (last examples)
- `UI/TabUtils.lua:135-139` — `MatchesEnumFilter` (new function goes immediately after)
- `UI/GroupFrame.lua:115-119` — `type` enumMap in `buildKeyDefs()`
- `UI/GroupFrame.lua:235` — `y = y + 8` spacing line between keys section and examples section
- `UI/Tabs/MineTab.lua:134-141` — `mapType()` local function (remove entirely)
- `UI/Tabs/MineTab.lua:150` — `MatchesEnumFilter(mapType(entry), ft.type)` call (replace)
- `UI/Tabs/PartyTab.lua:238-245` — `mapType()` local function (remove entirely)
- `UI/Tabs/PartyTab.lua:262` — `MatchesEnumFilter(mapType(entry), ft.type)` call (replace)
- `UI/Tabs/SharedTab.lua:254-261` — `mapType()` local function (remove entirely)
- `UI/Tabs/SharedTab.lua:278` — `MatchesEnumFilter(mapType(entry), ft.type)` call (replace)
- Non-enUS locales: 11 files (`deDE`, `frFR`, `esES`, `esMX`, `zhCN`, `zhTW`, `ptBR`, `itIT`, `koKR`, `ruRU`, `jaJP`) — all have `filter.val.chain/group/solo/timed` on one compact line (~line 229-230) and `filter.help.example.6` as the last example line (~line 243)

---

## Task 1: enUS locale — add new type filter keys

**Files:**
- Modify: `Locales/enUS.lua`

`filter.key.type.desc` is already referenced by `buildKeyDefs()` via `descKey` — updating the value here automatically updates the help window key list. New `filter.val.*` keys are required by the expanded `enumMap` in Task 3.

- [ ] **Step 1: Update `filter.key.type.desc` value (line 281)**

  Replace:
  ```lua
  L["filter.key.type.desc"]    = "Quest type (chain, group, solo, timed)"
  ```
  With:
  ```lua
  L["filter.key.type.desc"]    = "Quest type — chain, group, solo, timed, escort, dungeon, raid, elite, daily, pvp, kill, gather, interact"
  ```

- [ ] **Step 2: Add 9 new `filter.val.*` keys after `filter.val.timed` (after line 294)**

  After `L["filter.val.timed"]        = "timed"`, insert:
  ```lua
  L["filter.val.escort"]   = "escort"
  L["filter.val.dungeon"]  = "dungeon"
  L["filter.val.raid"]     = "raid"
  L["filter.val.elite"]    = "elite"
  L["filter.val.daily"]    = "daily"
  L["filter.val.pvp"]      = "pvp"
  L["filter.val.kill"]     = "kill"
  L["filter.val.gather"]   = "gather"
  L["filter.val.interact"] = "interact"
  ```

- [ ] **Step 3: Add help note key and 3 new examples after `filter.help.example.6` (after line 324)**

  After `L["filter.help.example.6.note"]       = "Quoted value (use when value contains spaces)"`, insert:
  ```lua
  L["filter.help.type.note"] = "kill, gather, and interact match quests with at least one objective of that kind — quests can match multiple types. Type filters require the Questie or Quest Weaver add-on to be installed."
  L["filter.help.example.7"]        = "type=dungeon"
  L["filter.help.example.7.note"]   = "Show only dungeon quests (requires Questie or Quest Weaver)"
  L["filter.help.example.8"]        = "type=kill"
  L["filter.help.example.8.note"]   = "Show quests with at least one kill objective"
  L["filter.help.example.9"]        = "type=daily"
  L["filter.help.example.9.note"]   = "Show only daily quests"
  ```

- [ ] **Step 4: Commit**
  ```bash
  git add Locales/enUS.lua
  git commit -m "feat: add 9 new type filter locale keys to enUS"
  ```

---

## Task 2: TabUtils — add MatchesTypeFilter helper

**Files:**
- Modify: `UI/TabUtils.lua` (after the closing `end` of `MatchesEnumFilter`, after line 139)

Core logic change. Same `(entry, descriptor)` signature as `MatchesEnumFilter` so tab callers need minimal changes. `group`, `timed`, `solo`, `chain` read from entry fields directly — no AQL call. AQL-type predicates (`escort`, `dungeon`, etc.) and objective predicates (`kill`, `gather`, `interact`) call `AQL:GetQuestInfo()` once per quest only.

**Critical: the final return uses explicit `if/else` — not `and/or` — to avoid the Lua ternary pitfall where `a and false or c` returns `c` when `matched` is `false`.**

- [ ] **Step 1: Add `MatchesTypeFilter` function after `MatchesEnumFilter`**

  After the closing `end` of `MatchesEnumFilter` (after line 139), insert exactly:
  ```lua

  -- Type filter: each value is an independent boolean predicate.
  -- descriptor = { op = "=" | "!=", value = canonicalString }
  -- entry must have: questID, suggestedGroup, timerSeconds, chainInfo (all set by each tab's BuildTree).
  -- AQL:GetQuestInfo() is called only for AQL-based and objective-type predicates.
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

- [ ] **Step 2: Verify logic by code review**

  Check these before committing:
  - `group`: `>= 2` (a group of exactly 2 is still a group quest)
  - `solo`: `<= 1` (a chain quest with suggestedGroup=0 matches both `chain` AND `solo` — intentional)
  - `chain`: requires both non-nil AND `knownStatus == Known` (chainInfo may exist with Unknown status)
  - Objective mapping: `kill` → `"monster"`, `gather` → `"item"`, `interact` → `"object"`
  - Final return: explicit `if descriptor.op == "=" then return matched else return not matched end`

- [ ] **Step 3: Commit**
  ```bash
  git add UI/TabUtils.lua
  git commit -m "feat: add MatchesTypeFilter independent predicate helper to TabUtils"
  ```

---

## Task 3: GroupFrame — expand type enumMap and add help note

**Files:**
- Modify: `UI/GroupFrame.lua`

Two changes in one file. `buildKeyDefs()` expansion is required so FilterParser accepts the 9 new values — without this, typing `type=dungeon` would produce a `filter.err.INVALID_ENUM` error. The help note is added between the "Supported Keys" section and the "Examples" section in `createHelpFrame()`.

- [ ] **Step 1: Expand the `type` enumMap in `buildKeyDefs()` (lines 115-119)**

  Replace:
  ```lua
          { canonical="type",   names={L["filter.key.type"]},
            type="enum",
            enumMap={ [L["filter.val.chain"]]="chain", [L["filter.val.group"]]="group",
                      [L["filter.val.solo"]]="solo",   [L["filter.val.timed"]]="timed" },
            descKey="filter.key.type.desc" },
  ```
  With:
  ```lua
          { canonical="type",   names={L["filter.key.type"]},
            type="enum",
            enumMap={
              [L["filter.val.chain"]]   ="chain",    [L["filter.val.group"]]   ="group",
              [L["filter.val.solo"]]    ="solo",     [L["filter.val.timed"]]   ="timed",
              [L["filter.val.escort"]]  ="escort",   [L["filter.val.dungeon"]] ="dungeon",
              [L["filter.val.raid"]]    ="raid",     [L["filter.val.elite"]]   ="elite",
              [L["filter.val.daily"]]   ="daily",    [L["filter.val.pvp"]]     ="pvp",
              [L["filter.val.kill"]]    ="kill",     [L["filter.val.gather"]]  ="gather",
              [L["filter.val.interact"]]="interact",
            },
            descKey="filter.key.type.desc" },
  ```

- [ ] **Step 2: Add the type note line in `createHelpFrame()` between the keys section and examples section**

  In `createHelpFrame()`, find the spacing gap between the keys loop and the examples section (line 235):
  ```lua
      y = y + 8

      addLine(L["filter.help.section.examples"], "GameFontNormal", 1, 0.82, 0)
  ```
  Replace with:
  ```lua
      y = y + 4
      addLine(L["filter.help.type.note"], "GameFontNormalSmall", 1, 0.82, 0.2, 8)
      y = y + 8

      addLine(L["filter.help.section.examples"], "GameFontNormal", 1, 0.82, 0)
  ```
  (The `1, 0.82, 0.2` color is a warm amber — visually distinct from the white key descriptions above and the blue example lines below, drawing attention to the caveat.)

- [ ] **Step 3: Commit**
  ```bash
  git add UI/GroupFrame.lua
  git commit -m "feat: expand type filter enumMap and add help window note"
  ```

---

## Task 4: MineTab — replace mapType with MatchesTypeFilter

**Files:**
- Modify: `UI/Tabs/MineTab.lua`

Two changes: remove the `mapType()` local function entirely, replace its one call site with `T.MatchesTypeFilter`.

- [ ] **Step 1: Remove `mapType()` function (lines 134-141)**

  Remove the entire block (preceded by `mapGroup`, followed by `questPasses`):
  ```lua
          local function mapType(entry)
              if entry.chainInfo and entry.chainInfo.knownStatus == AQL.ChainStatus.Known then
                  return "chain"
              elseif (entry.suggestedGroup or 0) >= 2 then return "group"
              elseif (entry.timerSeconds or 0) > 0 then return "timed"
              else return "solo"
              end
          end
  ```

- [ ] **Step 2: Replace the call site in `questPasses` (line 150)**

  Replace:
  ```lua
              if ft.type   and not T.MatchesEnumFilter(mapType(entry),  ft.type)  then return false end
  ```
  With:
  ```lua
              if ft.type   and not T.MatchesTypeFilter(entry, ft.type)  then return false end
  ```

- [ ] **Step 3: Commit**
  ```bash
  git add UI/Tabs/MineTab.lua
  git commit -m "feat: replace mapType with MatchesTypeFilter in MineTab"
  ```

---

## Task 5: PartyTab — replace mapType with MatchesTypeFilter

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

Identical pattern to Task 4.

- [ ] **Step 1: Remove `mapType()` function (lines 238-245)**

  Remove the entire block (preceded by `mapGroup`, followed by `playerMatches`):
  ```lua
          local function mapType(entry)
              if entry.chainInfo and entry.chainInfo.knownStatus == AQL.ChainStatus.Known then
                  return "chain"
              elseif (entry.suggestedGroup or 0) >= 2 then return "group"
              elseif (entry.timerSeconds or 0) > 0 then return "timed"
              else return "solo"
              end
          end
  ```

- [ ] **Step 2: Replace the call site in `questPasses` (line 262)**

  Replace:
  ```lua
              if ft.type   and not T.MatchesEnumFilter(mapType(entry),  ft.type)  then return false end
  ```
  With:
  ```lua
              if ft.type   and not T.MatchesTypeFilter(entry, ft.type)  then return false end
  ```

- [ ] **Step 3: Commit**
  ```bash
  git add UI/Tabs/PartyTab.lua
  git commit -m "feat: replace mapType with MatchesTypeFilter in PartyTab"
  ```

---

## Task 6: SharedTab — replace mapType with MatchesTypeFilter

**Files:**
- Modify: `UI/Tabs/SharedTab.lua`

Identical pattern to Tasks 4 and 5.

- [ ] **Step 1: Remove `mapType()` function (lines 254-261)**

  Remove the entire block (preceded by `mapGroup`, followed by `playerMatches`):
  ```lua
          local function mapType(entry)
              if entry.chainInfo and entry.chainInfo.knownStatus == AQL.ChainStatus.Known then
                  return "chain"
              elseif (entry.suggestedGroup or 0) >= 2 then return "group"
              elseif (entry.timerSeconds or 0) > 0 then return "timed"
              else return "solo"
              end
          end
  ```

- [ ] **Step 2: Replace the call site in `questPasses` (line 278)**

  Replace:
  ```lua
              if ft.type   and not T.MatchesEnumFilter(mapType(entry),  ft.type)  then return false end
  ```
  With:
  ```lua
              if ft.type   and not T.MatchesTypeFilter(entry, ft.type)  then return false end
  ```

- [ ] **Step 3: Commit**
  ```bash
  git add UI/Tabs/SharedTab.lua
  git commit -m "feat: replace mapType with MatchesTypeFilter in SharedTab"
  ```

---

## Task 7: Non-enUS locales — add new filter value keys

**Files:**
- Modify: `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`, `Locales/esMX.lua`,
  `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`,
  `Locales/koKR.lua`, `Locales/ruRU.lua`, `Locales/jaJP.lua`

All 11 non-enUS files follow the identical compact pattern. **`filter.key.type.desc` is already present as `= true` in all 11 files** (verified via grep) — no change needed for that key. WoW's TOC load order guarantees all locale files load before any UI file, so WoW runtime order is not a concern. AceLocale falls back to enUS for any key set to `true`, so all 9 new canonical values (which ARE the English strings) render correctly. The `filter.help.type.note` key is also new and needs `= true` in each file.

- [ ] **Step 1: In each of the 11 files, add the 9 new `filter.val.*` keys**

  The same old_string exists in all 11 files:
  ```lua
  L["filter.val.chain"]=true L["filter.val.group"]=true L["filter.val.solo"]=true L["filter.val.timed"]=true
  ```

  Replace with:
  ```lua
  L["filter.val.chain"]=true L["filter.val.group"]=true L["filter.val.solo"]=true L["filter.val.timed"]=true
  L["filter.val.escort"]=true L["filter.val.dungeon"]=true L["filter.val.raid"]=true L["filter.val.elite"]=true L["filter.val.daily"]=true L["filter.val.pvp"]=true
  L["filter.val.kill"]=true L["filter.val.gather"]=true L["filter.val.interact"]=true
  ```

- [ ] **Step 2: In each of the 11 files, add the help note key and 3 new example keys**

  The same old_string exists in all 11 files:
  ```lua
  L["filter.help.example.6"]=true L["filter.help.example.6.note"]=true
  ```

  Replace with:
  ```lua
  L["filter.help.example.6"]=true L["filter.help.example.6.note"]=true
  L["filter.help.type.note"]=true
  L["filter.help.example.7"]=true L["filter.help.example.7.note"]=true
  L["filter.help.example.8"]=true L["filter.help.example.8.note"]=true
  L["filter.help.example.9"]=true L["filter.help.example.9.note"]=true
  ```

- [ ] **Step 3: Commit all 11 locale files**
  ```bash
  git add Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua \
          Locales/zhCN.lua Locales/zhTW.lua Locales/ptBR.lua Locales/itIT.lua \
          Locales/koKR.lua Locales/ruRU.lua Locales/jaJP.lua
  git commit -m "feat: add extended type filter locale keys to non-enUS locales"
  ```

---

## Task 8: Version bump and CLAUDE.md update

**Files:**
- Modify: `SocialQuest.toc`, `CLAUDE.md`

All prior changes this session are on 2026-03-27 (versions 2.12.24–2.12.28). Per the versioning rule, further changes on the same day increment the revision only: 2.12.28 → 2.12.29.

- [ ] **Step 1: Bump version in `SocialQuest.toc`**

  Replace:
  ```
  ## Version: 2.12.28
  ```
  With:
  ```
  ## Version: 2.12.29
  ```

- [ ] **Step 2: Add version history entry at the top of Version History in `CLAUDE.md`**

  Insert before the `### Version 2.12.28` line:
  ```markdown
  ### Version 2.12.29 (March 2026 — AdvancedFilters branch)
  - Feature: Extended `type` filter with 9 new predicates. AQL-based: `escort`, `dungeon`, `raid`, `elite`, `daily`, `pvp` (matched via `AQL:GetQuestInfo().type`). Objective-based: `kill` (any monster objective), `gather` (any item objective), `interact` (any object objective) — a quest with mixed objectives matches multiple types simultaneously. Replaced the priority-chain `mapType()` in all three tabs with `SocialQuestTabUtils.MatchesTypeFilter(entry, descriptor)` — each type value is now an independent boolean predicate, so `type=chain` and `type=dungeon` both match a chain dungeon quest. Extended to Party and Shared tabs. Requires Questie or Quest Weaver for AQL-based and objective predicates; filter help window updated with full 13-value list and Questie/QuestWeaver caveat note.

  ```

- [ ] **Step 3: Commit**
  ```bash
  git add SocialQuest.toc CLAUDE.md
  git commit -m "chore: bump version to 2.12.29 for extended type filter"
  ```

---

## In-Game Verification Checklist

After all tasks complete, load the addon in WoW and verify:

- [ ] `type=chain` — existing behavior preserved; chain quests appear
- [ ] `type=solo` — a chain quest with no group requirement matches both `type=chain` AND `type=solo`
- [ ] `type=group` — group quests appear
- [ ] `type=dungeon` — dungeon-type quests (requires Questie/QuestWeaver installed)
- [ ] `type=daily` — daily quests appear
- [ ] `type=kill` — quests with at least one kill objective appear; quests with kill+collect objectives appear under both `type=kill` and `type=gather`
- [ ] `type!=dungeon` — all non-dungeon quests appear
- [ ] `type=kill` on Party tab — filter applies without error
- [ ] `type=kill` on Shared tab — filter applies without error
- [ ] Without Questie/QuestWeaver: `type=dungeon` matches nothing silently (no Lua error)
- [ ] Help window (`[?]` button): key list shows all 13 type values in description; amber note about Questie requirement is visible between keys section and examples; examples include `type=dungeon`, `type=kill`, `type=daily`
- [ ] Invalid enum still errors: `type=xyz` produces `filter.err.INVALID_ENUM` label
