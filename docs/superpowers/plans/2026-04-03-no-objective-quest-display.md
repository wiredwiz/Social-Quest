# No-Objective Quest Status Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "Finished" / "Complete" / "In Progress" status indicators to quest rows for quests with no numeric X/Y objectives, displayed in a consistent two-column layout aligned with objective progress bars.

**Architecture:** All rendering changes are in `UI/RowFactory.lua`. A new `isNoObjectiveQuest` helper detects no-objective quests. A new `renderStatusRow` helper provides the two-column layout (name col + status at bar start) used by all three status cases (`hasCompleted`, `isComplete`, new `In Progress`). Three new locale keys are added to all 12 locale files **before** any code task, since AceLocale strict mode crashes at load if a referenced key is missing. The old `%s FINISHED` format-string key is removed in the same locale task.

**Tech Stack:** Lua 5.1 (WoW addon), AceLocale-3.0, WoW frame API (FontString).

---

## File Map

| File | Change |
|---|---|
| `UI/RowFactory.lua` | Add `isNoObjectiveQuest`, `renderStatusRow`; update badge chain; refactor `hasCompleted`/`isComplete` rows; add `In Progress` row case |
| `Locales/enUS.lua` | Add `L["Finished"]`, `L["In Progress"]`, `L["(In Progress)"]`; remove `L["%s FINISHED"]` |
| `Locales/deDE.lua` | Same structure, German strings |
| `Locales/frFR.lua` | Same structure, French strings |
| `Locales/esES.lua` | Same structure, Spanish strings |
| `Locales/esMX.lua` | Same structure, Mexican Spanish strings |
| `Locales/zhCN.lua` | Same structure, Simplified Chinese strings |
| `Locales/zhTW.lua` | Same structure, Traditional Chinese strings |
| `Locales/ptBR.lua` | Same structure, Brazilian Portuguese strings |
| `Locales/itIT.lua` | Same structure, Italian strings |
| `Locales/koKR.lua` | Same structure, Korean strings |
| `Locales/ruRU.lua` | Same structure, Russian strings |
| `Locales/jaJP.lua` | Same structure, Japanese strings |
| `SocialQuest.toc` | Version bump |
| `SocialQuest_Mainline.toc` | Version bump |
| `CLAUDE.md` | Version history entry |
| `changelog.txt` | Changelog entry |

---

## Context

**`UI/RowFactory.lua`** is the stateless rendering layer for all three tabs. Key areas:

- **Private helpers section** (~line 43): where `formatTimeRemaining` lives. New helpers (`isNoObjectiveQuest`, `renderStatusRow`) go here.
- **`AddQuestRow`** (~line 195): renders the quest title row. Badge priority chain at lines 219–227 determines what right-aligned badge appears. `callbacks.onTitleShiftClick` is non-nil only on the Mine tab.
- **`AddPlayerRow`** (~line 344): renders a single player's row under a quest. Current priority chain:
  1. `hasCompleted` (line 349) → `string.format(L["%s FINISHED"], displayName)` — will be replaced
  2. `isComplete` (line 357) → `displayName .. " " .. L["Complete"]` — will be replaced
  3. `needsShare` (line 365) — unchanged
  4. `ineligReason` (line 373) — unchanged
  5. `!hasSocialQuest + no objectives` (line 391) → `"(no data)"` — unchanged
  6. else (line 400) → objective bars or plain text — unchanged

`nameColumnWidth` is always calculated and passed by PartyTab and SharedTab for every `AddPlayerRow` call. MineTab passes `0` only when `#objs > 0`; MineTab never calls `AddPlayerRow` for no-objective quests.

`SocialQuestColors` is a WoW global. `ROW_H = 18` and `CONTENT_WIDTH` are module-level upvalues accessible to module-level local functions.

**Locale files** are at `Locales/*.lua`. The key `L["%s FINISHED"]` is currently at line ~57–58 in all files; its only code usage is `RowFactory.lua:354`. All new keys go adjacent to the removed key.

---

## Task 1: Locale — add new keys, remove `%s FINISHED`

**Files:** All 12 locale files in `Locales/`

**Why first:** AceLocale strict mode causes a Lua error at load time if code references a key that does not exist in the locale table. All code tasks reference `L["Finished"]`, `L["In Progress"]`, and `L["(In Progress)"]`, so these keys must be present before any code change is committed.

In each file, find the line containing `L["%s FINISHED"]` and replace it with the three new lines shown below. The exact line number varies ±1 by file; search for the string to be safe.

- [ ] **Step 1: Update `Locales/enUS.lua`**

Remove:
```lua
L["%s FINISHED"]                            = true   -- permanent: quest turned in
```
Add in its place:
```lua
L["Finished"]                               = true   -- player row: quest turned in
L["In Progress"]                            = true   -- player row: no-objective quest, not yet done
L["(In Progress)"]                          = true   -- Mine tab title badge
```

- [ ] **Step 2: Update `Locales/deDE.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s ABGESCHLOSSEN"
```
Add:
```lua
L["Finished"]                              = "Abgeschlossen"
L["In Progress"]                           = "In Bearbeitung"
L["(In Progress)"]                         = "(In Bearbeitung)"
```

- [ ] **Step 3: Update `Locales/frFR.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s TERMINÉE"
```
Add:
```lua
L["Finished"]                              = "Terminée"
L["In Progress"]                           = "En cours"
L["(In Progress)"]                         = "(En cours)"
```

- [ ] **Step 4: Update `Locales/esES.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s TERMINADA"
```
Add:
```lua
L["Finished"]                              = "Terminada"
L["In Progress"]                           = "En progreso"
L["(In Progress)"]                         = "(En progreso)"
```

- [ ] **Step 5: Update `Locales/esMX.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s TERMINADA"
```
Add:
```lua
L["Finished"]                              = "Terminada"
L["In Progress"]                           = "En progreso"
L["(In Progress)"]                         = "(En progreso)"
```

- [ ] **Step 6: Update `Locales/zhCN.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s 已完成"
```
Add:
```lua
L["Finished"]                              = "已完成"
L["In Progress"]                           = "进行中"
L["(In Progress)"]                         = "（进行中）"
```

- [ ] **Step 7: Update `Locales/zhTW.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s 已完成"
```
Add:
```lua
L["Finished"]                              = "已完成"
L["In Progress"]                           = "進行中"
L["(In Progress)"]                         = "（進行中）"
```

- [ ] **Step 8: Update `Locales/ptBR.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s CONCLUÍDA"
```
Add:
```lua
L["Finished"]                              = "Concluída"
L["In Progress"]                           = "Em andamento"
L["(In Progress)"]                         = "(Em andamento)"
```

- [ ] **Step 9: Update `Locales/itIT.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s COMPLETATA"
```
Add:
```lua
L["Finished"]                              = "Completata"
L["In Progress"]                           = "In corso"
L["(In Progress)"]                         = "(In corso)"
```

- [ ] **Step 10: Update `Locales/koKR.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s 완료"
```
Add:
```lua
L["Finished"]                              = "완료"
L["In Progress"]                           = "진행 중"
L["(In Progress)"]                         = "(진행 중)"
```

- [ ] **Step 11: Update `Locales/ruRU.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s ЗАВЕРШЕНО"
```
Add:
```lua
L["Finished"]                              = "Завершено"
L["In Progress"]                           = "В процессе"
L["(In Progress)"]                         = "(В процессе)"
```

- [ ] **Step 12: Update `Locales/jaJP.lua`**

Remove:
```lua
L["%s FINISHED"]                           = "%s 完了"
```
Add:
```lua
L["Finished"]                              = "完了"
L["In Progress"]                           = "進行中"
L["(In Progress)"]                         = "（進行中）"
```

- [ ] **Step 13: Run existing tests**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua
```

Expected: both suites report 0 failures.

- [ ] **Step 14: Commit**

```bash
git add Locales/
git commit -m "i18n: add Finished/In Progress locale keys, remove %s FINISHED"
```

---

## Task 2: Add `isNoObjectiveQuest` helper and `(In Progress)` title badge

**Files:**
- Modify: `UI/RowFactory.lua`

No automated tests exist for WoW UI rendering. Verify in-game after all tasks: a no-objective quest on the Mine tab should show `(In Progress)` right-aligned on the title row when not yet complete.

- [ ] **Step 1: Add `isNoObjectiveQuest` after `formatTimeRemaining` (~line 53)**

Insert immediately after the closing `end` of `formatTimeRemaining`:

```lua
-- Returns true when a quest has no trackable numeric objectives:
-- nil/empty objectives array, or all entries have numRequired == 0.
local function isNoObjectiveQuest(objectives)
    if not objectives or #objectives == 0 then return true end
    for _, obj in ipairs(objectives) do
        if obj.numRequired and obj.numRequired > 0 then return false end
    end
    return true
end
```

- [ ] **Step 2: Update badge chain in `AddQuestRow` (~line 219)**

Replace the existing badge block:

```lua
    -- Determine badge text. "Complete" trumps "Group".
    -- (Complete) is shown on Mine tab only (callbacks.onTitleShiftClick is present
    -- only there). On Party/Shared, completion is shown in the player row instead.
    local badgeText = ""
    if questEntry.isComplete and callbacks and callbacks.onTitleShiftClick then
        badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
    elseif questEntry.suggestedGroup and questEntry.suggestedGroup > 0 then
        badgeText = C.chain .. L["(Group)"] .. C.reset
    end
```

With:

```lua
    -- Determine badge text. Priority: (Complete) > (Group) > (In Progress).
    -- (Complete) and (In Progress) are Mine tab only (callbacks.onTitleShiftClick
    -- is present only there). (Group) shows on all tabs.
    -- On Party/Shared, per-player status is shown in the player rows instead.
    local badgeText = ""
    if questEntry.isComplete and callbacks and callbacks.onTitleShiftClick then
        badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
    elseif questEntry.suggestedGroup and questEntry.suggestedGroup > 0 then
        badgeText = C.chain .. L["(Group)"] .. C.reset
    elseif not questEntry.isComplete
        and callbacks and callbacks.onTitleShiftClick
        and isNoObjectiveQuest(questEntry.objectives) then
        badgeText = C.unknown .. L["(In Progress)"] .. C.reset
    end
```

- [ ] **Step 3: Run existing tests**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua
```

Expected: 0 failures.

- [ ] **Step 4: Commit**

```bash
git add "UI/RowFactory.lua"
git commit -m "feat: add isNoObjectiveQuest helper and (In Progress) Mine tab title badge"
```

---

## Task 3: Add `renderStatusRow` and refactor `hasCompleted` / `isComplete` player rows

**Files:**
- Modify: `UI/RowFactory.lua`

This is a pure rendering refactor — no visible behavioral change for players. `hasCompleted` rows change from a single left-aligned `"[Name] FINISHED"` string to a two-column layout showing `"Name"` on the left and `"Finished"` at bar start. `isComplete` rows change from `"[Name] Complete"` to the same two-column layout. The single-string fallback (when `nameColumnWidth` is nil) preserves the prior look for any call site that omits `nameColumnWidth`.

- [ ] **Step 1: Add `renderStatusRow` immediately before `AddPlayerRow` (~line 343)**

Insert this block immediately before `function RowFactory.AddPlayerRow(...)`:

```lua
-- Two-column status row: player name in left column, status text left-aligned at
-- bar start (x + nameColumnWidth + 4). Falls back to a single left-aligned string
-- when nameColumnWidth is nil (e.g. Mine tab peer rows called without a name column).
-- color: a WoW color escape sequence string (e.g. C.unknown or GetUIColor("completed")).
local function renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName, statusText, color)
    local C = SocialQuestColors
    if nameColumnWidth then
        local barX = x + nameColumnWidth + 4
        local nameFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        nameFs:SetSize(nameColumnWidth, ROW_H)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetJustifyV("MIDDLE")
        nameFs:SetText(C.white .. displayName .. C.reset)
        local statusFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", barX, -y)
        statusFs:SetWidth(CONTENT_WIDTH - barX - 4)
        statusFs:SetJustifyH("LEFT")
        statusFs:SetJustifyV("MIDDLE")
        statusFs:SetText(color .. statusText .. C.reset)
    else
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.white .. displayName .. C.reset .. " " .. color .. statusText .. C.reset)
    end
    return y + ROW_H + 2
end
```

- [ ] **Step 2: Replace `hasCompleted` case (~line 349)**

Replace:

```lua
    if playerEntry.hasCompleted then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], displayName) .. C.reset)
        return y + ROW_H + 2
```

With:

```lua
    if playerEntry.hasCompleted then
        return renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName,
            L["Finished"], SocialQuestColors.GetUIColor("completed"))
```

- [ ] **Step 3: Replace `isComplete` case (~line 357)**

Replace:

```lua
    elseif playerEntry.isComplete then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.white .. displayName .. C.reset .. " " .. SocialQuestColors.GetUIColor("completed") .. L["Complete"] .. C.reset)
        return y + ROW_H + 2
```

With:

```lua
    elseif playerEntry.isComplete then
        return renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName,
            L["Complete"], SocialQuestColors.GetUIColor("completed"))
```

- [ ] **Step 4: Update the comment block above `AddPlayerRow` (~line 331)**

Replace:

```lua
-- Player row. Display priority (first matching wins):
--   1. playerEntry.hasCompleted → "[Name] FINISHED" (green)
--   2. playerEntry.needsShare   → "[Name] Needs it Shared" (grey)
--   2b. playerEntry.ineligReason (needsShare=false, ineligReason~=nil) → "[Name] [reason]" (muted amber)
--   3. hasSocialQuest==false and no objectives → "[Name] (no data)" (grey)
--   4. otherwise → "[Name]" label (+ "Step X of Y" when step/chainLength set),
--                  followed by objective rows.
```

With:

```lua
-- Player row. Display priority (first matching wins):
--   1. playerEntry.hasCompleted       → two-column: name | "Finished" (green)
--   2. playerEntry.isComplete         → two-column: name | "Complete" (green)
--   3. playerEntry.needsShare         → "[Name] Needs it Shared" (grey)
--   3b. playerEntry.ineligReason      → "[Name] [reason]" (muted amber)
--   4. hasSocialQuest + isNoObjective → two-column: name | "In Progress" (dimmed)
--   5. !hasSocialQuest + no objectives → "[Name] (no data)" (grey)
--   6. otherwise                      → name label + objective bar rows
-- renderStatusRow provides two-column layout when nameColumnWidth is set;
-- falls back to single left-aligned string when nameColumnWidth is nil.
```

- [ ] **Step 5: Run existing tests**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua
```

Expected: 0 failures.

- [ ] **Step 6: Commit**

```bash
git add "UI/RowFactory.lua"
git commit -m "refactor: two-column status layout for Finished/Complete player rows"
```

---

## Task 4: Add `In Progress` player row case

**Files:**
- Modify: `UI/RowFactory.lua`

- [ ] **Step 1: Insert new `elseif` after `ineligReason` block (~line 389)**

The `ineligReason` block ends with `return y + ROW_H + 2`. Immediately after that closing line, before the `elseif not playerEntry.hasSocialQuest` line, insert:

```lua
    elseif playerEntry.hasSocialQuest and isNoObjectiveQuest(playerEntry.objectives) then
        -- Quest has no numeric objectives and is not yet complete: nothing to track.
        return renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName,
            L["In Progress"], C.unknown)
```

- [ ] **Step 2: Run existing tests**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua
```

Expected: 0 failures.

- [ ] **Step 3: Commit**

```bash
git add "UI/RowFactory.lua"
git commit -m "feat: show In Progress status for no-objective quest player rows"
```

---

## Task 5: Version bump, CLAUDE.md, changelog

**Files:** `SocialQuest.toc`, `SocialQuest_Mainline.toc`, `CLAUDE.md`, `changelog.txt`

Version 2.18.0 was the first change on this date (April 3 2026), so this is 2.18.1 (revision increment, same day per the versioning rule in CLAUDE.md).

- [ ] **Step 1: Bump version in both TOC files**

In `SocialQuest.toc` and `SocialQuest_Mainline.toc`, change:
```
## Version: 2.18.0
```
To:
```
## Version: 2.18.1
```

- [ ] **Step 2: Add version entry to `CLAUDE.md`**

In the Version History section, add above the existing `### Version 2.18.0` entry:

```markdown
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
```

- [ ] **Step 3: Add entry to `changelog.txt`**

Prepend the same text above the existing top entry in `changelog.txt`.

- [ ] **Step 4: Run tests one final time**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua
```

Expected: 0 failures.

- [ ] **Step 5: Commit**

```bash
git add SocialQuest.toc SocialQuest_Mainline.toc CLAUDE.md changelog.txt
git commit -m "chore: bump version to 2.18.1, update CLAUDE.md and changelog"
```
