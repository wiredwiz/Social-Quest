# Objective Banner Improvements — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix objective progress banners to show `"Quest Title — Objective Text (3/5)"` (Feature 1), and suppress the default WoW `UIErrorsFrame` notification when Social Quest's own objective progress banner is active (Feature 2).

**Architecture:** Two independent changes, one commit each. Feature 1 adds an `objText` parameter to `formatObjectiveBannerMsg`, plumbs the objective text through from both own-event and remote-event paths, and updates all 12 locale files. Feature 2 adds `UpdateQuestWatchSuppression()` to `Core/Announcements.lua` and wires it into the addon lifecycle and options callbacks.

**Tech Stack:** Lua 5.1, WoW TBC Classic (Interface 20505), AceAddon-3.0, AceLocale-3.0. No automated test framework — verification is manual in-game. Em dash (U+2014) written as the literal UTF-8 character `—` in all Lua strings, consistent with existing `"SocialQuest — Group Quests"` key.

---

## Chunk 1: Show objective text in banners (Feature 1)

**Files modified in this chunk:**
- `Core/Announcements.lua` — `formatObjectiveBannerMsg`, `OnOwnObjectiveEvent`, `OnRemoteObjectiveEvent`, `TEST_DEMOS`
- `Core/GroupData.lua` — `OnObjectiveReceived` forwards `payload.objIndex`
- `Locales/enUS.lua` — 3 keys replaced
- `Locales/deDE.lua` through `Locales/jaJP.lua` (11 files) — 3 keys replaced per file

### Task 1: Update `formatObjectiveBannerMsg` in `Core/Announcements.lua`

**File:** `Core/Announcements.lua` (lines 92–103)

**Background:** The function currently has no `objText` parameter. All three format strings use `questTitle` where the objective description should appear. A new `objText` parameter is inserted as the 3rd argument (after `questTitle`). The format strings all use an em dash separator: `"Quest Title — Objective Text (3/5)"`.

**Current state (lines 92–103):**
```lua
local function formatObjectiveBannerMsg(sender, questTitle, numFulfilled, numRequired, isComplete, isRegression)
    if isComplete then
        return string.format(L["%s completed objective: %s (%d/%d)"],
            sender, questTitle, numFulfilled, numRequired)
    elseif isRegression then
        return string.format(L["%s regressed: %s (%d/%d)"],
            sender, questTitle, numFulfilled, numRequired)
    else
        return string.format(L["%s progressed: %s (%d/%d)"],
            sender, questTitle, numFulfilled, numRequired)
    end
end
```

- [ ] **Step 1: Replace `formatObjectiveBannerMsg` (lines 92–103)**

Replace the entire function with:
```lua
local function formatObjectiveBannerMsg(sender, questTitle, objText, numFulfilled, numRequired, isComplete, isRegression)
    if isComplete then
        return string.format(L["%s completed objective: %s — %s (%d/%d)"],
            sender, questTitle, objText, numFulfilled, numRequired)
    elseif isRegression then
        return string.format(L["%s regressed: %s — %s (%d/%d)"],
            sender, questTitle, objText, numFulfilled, numRequired)
    else
        return string.format(L["%s progressed: %s — %s (%d/%d)"],
            sender, questTitle, objText, numFulfilled, numRequired)
    end
end
```

Note: `—` is the literal UTF-8 em dash character (U+2014), consistent with the project convention (`L["SocialQuest — Group Quests"]` in enUS.lua). The same literal character must be used in all locale files so that AceLocale's key lookup finds the right translation. Lua 5.1 does not support `\xNN` hex escapes, but the literal character is saved as UTF-8 bytes by any UTF-8 editor, which is correct.

Line number note: The tasks below reference pre-edit line numbers in `Core/Announcements.lua`. Each edit may shift subsequent line numbers. Always use verbatim string matching (not line numbers alone) when applying edits.

### Task 2: Update `OnOwnObjectiveEvent` in `Core/Announcements.lua`

**File:** `Core/Announcements.lua` (lines 427–430)

**Background:** `objective.text` is available in the callback and must be passed as the new 3rd argument.

**Current state (lines 427–430):**
```lua
    local msg = formatObjectiveBannerMsg(
        L["You"], questInfo.title,
        objective.numFulfilled, objective.numRequired,
        eventType == "objective_complete", isRegression)
```

- [ ] **Step 2: Pass `objective.text` to the formatter**

Replace those lines with:
```lua
    local msg = formatObjectiveBannerMsg(
        L["You"], questInfo.title,
        objective.text or "",
        objective.numFulfilled, objective.numRequired,
        eventType == "objective_complete", isRegression)
```

### Task 3: Update `OnRemoteObjectiveEvent` in `Core/Announcements.lua`

**File:** `Core/Announcements.lua` (lines 380–405)

**Background:** The function currently has no `objIndex` parameter and uses `AQL:GetQuestLink` (which returns a hyperlink) as the first-tier title source — `RaidNotice_AddMessage` does not parse hyperlinks, so the hyperlink is intentionally dropped in favour of `AQL:GetQuestTitle`. The `objIndex` is needed to look up objective text from the AQL cache.

`AQL:GetQuestObjectives(questID)` returns the objectives array (cache first, then `C_QuestLog.GetQuestObjectives` fallback — returns `{}` if quest not in local log). `AQL:GetQuestTitle(questID)` uses three-tier resolution (cache → log scan → `C_QuestLog.GetQuestInfo`) so it returns a real title even for quests not in the local player's log; the `"Quest N"` fallback is only hit if AQL has no data.

**Current state (lines 380–405):**
```lua
function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, numFulfilled, numRequired, isComplete, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end

    local eventType = isComplete and "objective_complete" or "objective_progress"
    if not sectionDb.display[eventType] then return end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end
    if section == "battleground" and db.battleground.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end

    local AQL   = SocialQuest.AQL
    local title = (AQL and AQL:GetQuestLink(questID))
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)

    local msg = formatObjectiveBannerMsg(sender, title, numFulfilled, numRequired, isComplete, isRegression)
    displayBanner(msg, eventType)
end
```

- [ ] **Step 3: Replace `OnRemoteObjectiveEvent` with the new signature and text lookup**

Replace the entire function with:
```lua
function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, objIndex, numFulfilled, numRequired, isComplete, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end

    local eventType = isComplete and "objective_complete" or "objective_progress"
    if not sectionDb.display[eventType] then return end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end
    if section == "battleground" and db.battleground.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end

    local AQL     = SocialQuest.AQL
    local objs    = AQL and AQL:GetQuestObjectives(questID)
    local objInfo = objs and objs[objIndex]
    local objText = (objInfo and objInfo.text) or ""
    local title   = (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)

    local msg = formatObjectiveBannerMsg(sender, title, objText, numFulfilled, numRequired, isComplete, isRegression)
    displayBanner(msg, eventType)
end
```

### Task 4: Update `TEST_DEMOS` in `Core/Announcements.lua`

**File:** `Core/Announcements.lua` (lines 466–480)

**Background:** The hardcoded demo banner strings must match the new format so the test panel shows realistic output.

**Current state (lines 466–480):**
```lua
    objective_progress = {
        outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer progressed: [A Daunting Task] (3/8)",
        colorKey = "objective_progress",
    },
    objective_complete = {
        outbound = "{rt1} SocialQuest: 8/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer completed objective: [A Daunting Task] (8/8)",
        colorKey = "objective_complete",
    },
    objective_regression = {
        outbound = "{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for [A Daunting Task]!",
        banner   = "TestPlayer regressed: [A Daunting Task] (2/8)",
        colorKey = "objective_progress",   -- same color as progress
    },
```

- [ ] **Step 4: Update three banner strings in `TEST_DEMOS`**

Replace with:
```lua
    objective_progress = {
        outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer progressed: [A Daunting Task] — Kobolds Slain (3/8)",
        colorKey = "objective_progress",
    },
    objective_complete = {
        outbound = "{rt1} SocialQuest: 8/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer completed objective: [A Daunting Task] — Kobolds Slain (8/8)",
        colorKey = "objective_complete",
    },
    objective_regression = {
        outbound = "{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for [A Daunting Task]!",
        banner   = "TestPlayer regressed: [A Daunting Task] — Kobolds Slain (2/8)",
        colorKey = "objective_progress",   -- same color as progress
    },
```

### Task 5: Forward `objIndex` in `Core/GroupData.lua`

**File:** `Core/GroupData.lua` (lines 150–153)

**Background:** `payload.objIndex` is already parsed from the `SQ_OBJECTIVE` message and stored on `payload`. It just needs to be passed as the new 3rd argument to `OnRemoteObjectiveEvent`.

**Current state (lines 150–153):**
```lua
    SocialQuestAnnounce:OnRemoteObjectiveEvent(
        sender, payload.questID,
        payload.numFulfilled, payload.numRequired,
        isComplete, isRegression)
```

- [ ] **Step 5: Add `payload.objIndex` to the call**

Replace with:
```lua
    SocialQuestAnnounce:OnRemoteObjectiveEvent(
        sender, payload.questID,
        payload.objIndex,
        payload.numFulfilled, payload.numRequired,
        isComplete, isRegression)
```

### Task 6: Update `Locales/enUS.lua`

**File:** `Locales/enUS.lua` (lines 30–32)

**Background:** The three old keys are removed and replaced with new keys that include the em dash and extra `%s` slot.

**Current state (lines 30–32):**
```lua
L["%s completed objective: %s (%d/%d)"]   = true
L["%s regressed: %s (%d/%d)"]             = true
L["%s progressed: %s (%d/%d)"]            = true
```

- [ ] **Step 6: Replace the three locale keys in `enUS.lua`**

Replace with (using the literal `—` em dash character — must be byte-for-byte identical to the `—` used in the `L[...]` keys inside `Announcements.lua`):
```lua
L["%s completed objective: %s — %s (%d/%d)"] = true
L["%s regressed: %s — %s (%d/%d)"]           = true
L["%s progressed: %s — %s (%d/%d)"]          = true
```

### Task 7: Update all 11 non-English locale files

**Files:** `Locales/deDE.lua`, `frFR.lua`, `esES.lua`, `esMX.lua`, `zhCN.lua`, `zhTW.lua`, `ptBR.lua`, `itIT.lua`, `koKR.lua`, `ruRU.lua`, `jaJP.lua`

**Background:** Each file has 3 lines to change. The translated phrasing is preserved; only the key and value change — old key and value are replaced with the new key (containing the em dash and extra `%s`) and a new translated value that inserts `— %s` in the same position.

For each file, read it first to confirm the current state matches what is shown below, then apply the replacement.

- [ ] **Step 7a: Update `Locales/deDE.lua`**

Read `Locales/deDE.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s hat Ziel abgeschlossen: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s zurückgegangen: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s Fortschritt: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s hat Ziel abgeschlossen: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s zurückgegangen: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s Fortschritt: %s — %s (%d/%d)"
```

- [ ] **Step 7b: Update `Locales/frFR.lua`**

Read `Locales/frFR.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s a accompli l'objectif : %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s a régressé : %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s a progressé : %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s a accompli l'objectif : %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s a régressé : %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s a progressé : %s — %s (%d/%d)"
```

- [ ] **Step 7c: Update `Locales/esES.lua`**

Read `Locales/esES.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s ha completado el objetivo: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s ha retrocedido: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s ha progresado: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s ha completado el objetivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s ha retrocedido: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s ha progresado: %s — %s (%d/%d)"
```

- [ ] **Step 7d: Update `Locales/esMX.lua`**

Read `Locales/esMX.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s completó el objetivo: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s retrocedió: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s progresó: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s completó el objetivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s retrocedió: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s progresó: %s — %s (%d/%d)"
```

- [ ] **Step 7e: Update `Locales/zhCN.lua`**

Read `Locales/zhCN.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s 完成了目标：%s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s 退步了：%s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s 进度更新：%s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s 完成了目标：%s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s 退步了：%s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s 进度更新：%s — %s (%d/%d)"
```

- [ ] **Step 7f: Update `Locales/zhTW.lua`**

Read `Locales/zhTW.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s 完成了目標：%s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s 退步了：%s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s 進度更新：%s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s 完成了目標：%s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s 退步了：%s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s 進度更新：%s — %s (%d/%d)"
```

- [ ] **Step 7g: Update `Locales/ptBR.lua`**

Read `Locales/ptBR.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s concluiu objetivo: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s regrediu: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s progrediu: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s concluiu objetivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s regrediu: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s progrediu: %s — %s (%d/%d)"
```

- [ ] **Step 7h: Update `Locales/itIT.lua`**

Read `Locales/itIT.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s ha completato l'obiettivo: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s è regredito: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s ha progredito: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s ha completato l'obiettivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s è regredito: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s ha progredito: %s — %s (%d/%d)"
```

- [ ] **Step 7i: Update `Locales/koKR.lua`**

Read `Locales/koKR.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s 목표 달성: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s 퇴보: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s 진행: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s 목표 달성: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s 퇴보: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s 진행: %s — %s (%d/%d)"
```

- [ ] **Step 7j: Update `Locales/ruRU.lua`**

Read `Locales/ruRU.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s выполнил цель: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s откатился: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s прогрессировал: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s выполнил цель: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s откатился: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s прогрессировал: %s — %s (%d/%d)"
```

- [ ] **Step 7k: Update `Locales/jaJP.lua`**

Read `Locales/jaJP.lua` first and confirm the three "Find" strings below are present before editing.

Find:
```lua
L["%s completed objective: %s (%d/%d)"]   = "%s が目標クリア: %s (%d/%d)"
L["%s regressed: %s (%d/%d)"]             = "%s が後退: %s (%d/%d)"
L["%s progressed: %s (%d/%d)"]            = "%s が進捗: %s (%d/%d)"
```
Replace with:
```lua
L["%s completed objective: %s — %s (%d/%d)"] = "%s が目標クリア: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s が後退: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s が進捗: %s — %s (%d/%d)"
```

### Task 8: Verify and commit Feature 1

- [ ] **Step 8: Verify all changes**

Re-read the following and confirm:
1. `Core/Announcements.lua`:
   - `formatObjectiveBannerMsg` has 7 parameters with `objText` as 3rd
   - All three `string.format` calls use the new 5-arg locale keys with `—`
   - `OnOwnObjectiveEvent` passes `objective.text or ""` as 3rd arg
   - `OnRemoteObjectiveEvent` signature starts `(sender, questID, objIndex, ...)`
   - `OnRemoteObjectiveEvent` uses `AQL:GetQuestObjectives` + `AQL:GetQuestTitle` (no `GetQuestLink`)
   - `TEST_DEMOS` has `— Kobolds Slain` in all three objective banner strings
2. `Core/GroupData.lua`: `OnObjectiveReceived` passes `payload.objIndex` as 3rd arg to `OnRemoteObjectiveEvent`
3. `Locales/enUS.lua`: lines 30–32 have the new `—` keys (old 4-arg keys are gone)
4. Each of the 11 non-English locale files: 3 old 4-arg keys replaced with 5-arg keys

- [ ] **Step 9: Commit Feature 1**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Core/Announcements.lua Core/GroupData.lua Locales/enUS.lua Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua Locales/zhCN.lua Locales/zhTW.lua Locales/ptBR.lua Locales/itIT.lua Locales/koKR.lua Locales/ruRU.lua Locales/jaJP.lua
git commit -m "feat: show objective text in progress banners

formatObjectiveBannerMsg gains an objText parameter. Banners now
read 'Quest Title — Objective Text (3/5)' instead of 'Quest Title
(3/5)'. Own-event path passes objective.text; remote-event path
looks up text via AQL:GetQuestObjectives using objIndex (already
transmitted in SQ_OBJECTIVE payload). All 12 locale files updated."
```

---

## Chunk 2: Suppress default WoW objective progress banner (Feature 2)

**Files modified in this chunk:**
- `Core/Announcements.lua` — add `UpdateQuestWatchSuppression()`
- `SocialQuest.lua` — call suppression from `OnEnable`; always re-register in `OnDisable`
- `UI/Options.lua` — explicit `set` callbacks for `enabled`, `displayOwn`, `objective_progress`

### Task 9: Add `UpdateQuestWatchSuppression` to `Core/Announcements.lua`

**File:** `Core/Announcements.lua`

**Background:** When Social Quest's own objective progress banner is on, `UIErrorsFrame:UnregisterEvent("QUEST_WATCH_UPDATE")` suppresses the default WoW notification for the same event. All three conditions must be true to suppress: `db.enabled`, `db.general.displayOwn`, and `db.general.displayOwnEvents.objective_progress`. `objective_complete` is NOT part of the criteria — TBC Classic uses the same `QUEST_WATCH_UPDATE` event for both partial progress and final completion; suppressing on `objective_progress` alone covers all cases.

Safety tradeoff: if Social Quest encounters an error after unregistering and before `OnDisable` can re-register, the default WoW notification will be absent for the remainder of the session. A `/reload` restores normal behavior. This is accepted.

The function should be added after `OnOwnObjectiveEvent` (which ends around line 432), before the `TEST_DEMOS` block (which begins around line 440). Add it after the closing `end` of `OnOwnObjectiveEvent`.

- [ ] **Step 10: Add `UpdateQuestWatchSuppression` after `OnOwnObjectiveEvent`**

After the `end` that closes `OnOwnObjectiveEvent` (around line 432) and before the `--------` separator that precedes `TEST_DEMOS`, insert:

```lua
function SocialQuestAnnounce:UpdateQuestWatchSuppression()
    local db = SocialQuest.db.profile
    local shouldSuppress = db.enabled
                       and db.general.displayOwn
                       and db.general.displayOwnEvents.objective_progress
    if shouldSuppress then
        UIErrorsFrame:UnregisterEvent("QUEST_WATCH_UPDATE")
    else
        UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")
    end
end
```

### Task 10: Wire suppression into `SocialQuest.lua`

**File:** `SocialQuest.lua`

**Background:** `OnEnable` must call `UpdateQuestWatchSuppression()` after the addon is fully set up so initial suppression state is correct on login/reload. `OnDisable` must always re-register `UIErrorsFrame` for `QUEST_WATCH_UPDATE` regardless of settings — the addon is off, so the default WoW UI must take over.

**Current state of `OnEnable` end (lines 91–96):**
```lua
        if not DBIcon:GetMinimapButton("SocialQuest") then
            DBIcon:Register("SocialQuest", launcher, self.db.profile.minimap)
        end
    end
end
```

**Current state of `OnDisable` end (lines 109–112):**
```lua
        AQL.UnregisterCallback(self, "AQL_UNIT_QUEST_LOG_CHANGED")
    end
end
```

- [ ] **Step 11: Add suppression call to `OnEnable`**

Find the closing `end` of `OnEnable` (the final standalone `end` after the `if LDB and DBIcon then ... end` block). Replace:
```lua
        if not DBIcon:GetMinimapButton("SocialQuest") then
            DBIcon:Register("SocialQuest", launcher, self.db.profile.minimap)
        end
    end
end
```
With:
```lua
        if not DBIcon:GetMinimapButton("SocialQuest") then
            DBIcon:Register("SocialQuest", launcher, self.db.profile.minimap)
        end
    end

    SocialQuestAnnounce:UpdateQuestWatchSuppression()
end
```

- [ ] **Step 12: Add re-register call to `OnDisable`**

Find the closing of `OnDisable`. Replace:
```lua
        AQL.UnregisterCallback(self, "AQL_UNIT_QUEST_LOG_CHANGED")
    end
end
```
With:
```lua
        AQL.UnregisterCallback(self, "AQL_UNIT_QUEST_LOG_CHANGED")
    end
    -- Always re-register on disable regardless of settings.
    UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")
end
```

### Task 11: Add explicit `set` callbacks in `UI/Options.lua`

**File:** `UI/Options.lua`

**Background:** Three option toggles affect suppression state. Currently all three use the generic `toggle()` helper which only writes the db value — it does NOT call `UpdateQuestWatchSuppression()`. Each must be replaced with an inline table that has its own `get`/`set` functions.

The three toggles are:
1. `enabled` (line 143) — master on/off toggle under `general`
2. `displayOwn` (line 152) — "Show banners for your own quest events" under `general`
3. `objective_progress` inside `ownDisplayEventsGroup()` (line 89) — "Objective Progress" under Own Quest Banners

**Current state — `enabled` (lines 143–145):**
```lua
                    enabled         = toggle(L[\"Enable SocialQuest\"],
                        L[\"Master on/off switch for all SocialQuest functionality.\"],
                        { \"enabled\" }, 1),
```

**Current state — `displayOwn` (lines 152–154):**
```lua
                    displayOwn      = toggle(L[\"Show banners for your own quest events\"],
                        L[\"Show a banner on screen for your own quest events.\"],
                        { \"general\", \"displayOwn\" }, 4),
```

**Current state — `objective_progress` in `ownDisplayEventsGroup` (lines 89–92):**
```lua
                objective_progress = toggle(L[\"Objective Progress\"],
                    L[\"Show a banner when one of your quest objectives progresses or regresses.\"],
                    { \"general\", \"displayOwnEvents\", \"objective_progress\" }),
```

- [ ] **Step 13: Replace `enabled` toggle with explicit set callback**

Replace:
```lua
                    enabled         = toggle(L["Enable SocialQuest"],
                        L["Master on/off switch for all SocialQuest functionality."],
                        { "enabled" }, 1),
```
With:
```lua
                    enabled         = {
                        type  = "toggle",
                        name  = L["Enable SocialQuest"],
                        desc  = L["Master on/off switch for all SocialQuest functionality."],
                        order = 1,
                        get   = function(info) return SocialQuest.db.profile.enabled end,
                        set   = function(info, value)
                            SocialQuest.db.profile.enabled = value
                            SocialQuestAnnounce:UpdateQuestWatchSuppression()
                        end,
                    },
```

- [ ] **Step 14: Replace `displayOwn` toggle with explicit set callback**

Replace:
```lua
                    displayOwn      = toggle(L["Show banners for your own quest events"],
                        L["Show a banner on screen for your own quest events."],
                        { "general", "displayOwn" }, 4),
```
With:
```lua
                    displayOwn      = {
                        type  = "toggle",
                        name  = L["Show banners for your own quest events"],
                        desc  = L["Show a banner on screen for your own quest events."],
                        order = 4,
                        get   = function(info) return SocialQuest.db.profile.general.displayOwn end,
                        set   = function(info, value)
                            SocialQuest.db.profile.general.displayOwn = value
                            SocialQuestAnnounce:UpdateQuestWatchSuppression()
                        end,
                    },
```

- [ ] **Step 15: Replace `objective_progress` toggle in `ownDisplayEventsGroup` with explicit set callback**

Replace:
```lua
                objective_progress = toggle(L["Objective Progress"],
                    L["Show a banner when one of your quest objectives progresses or regresses."],
                    { "general", "displayOwnEvents", "objective_progress" }),
```
With:
```lua
                objective_progress = {
                    type = "toggle",
                    name = L["Objective Progress"],
                    desc = L["Show a banner when one of your quest objectives progresses or regresses."],
                    get  = function(info) return SocialQuest.db.profile.general.displayOwnEvents.objective_progress end,
                    set  = function(info, value)
                        SocialQuest.db.profile.general.displayOwnEvents.objective_progress = value
                        SocialQuestAnnounce:UpdateQuestWatchSuppression()
                    end,
                },
```

### Task 12: Verify and commit Feature 2

- [ ] **Step 16: Verify all changes**

Re-read the following and confirm:
1. `Core/Announcements.lua`:
   - `UpdateQuestWatchSuppression` function is present between `OnOwnObjectiveEvent` and the `TEST_DEMOS` block
   - It checks `db.enabled and db.general.displayOwn and db.general.displayOwnEvents.objective_progress`
   - It calls `UIErrorsFrame:UnregisterEvent("QUEST_WATCH_UPDATE")` when true, `:RegisterEvent(...)` when false
   - `objective_complete` is NOT part of the condition
2. `SocialQuest.lua`:
   - `OnEnable` ends with `SocialQuestAnnounce:UpdateQuestWatchSuppression()` after the minimap block
   - `OnDisable` ends with `UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")` after the AQL unregister block
3. `UI/Options.lua`:
   - `enabled` is now an inline table (not a `toggle()` call) with its own `get`/`set`; `set` calls `UpdateQuestWatchSuppression()`
   - `displayOwn` is now an inline table with the same pattern
   - `objective_progress` inside `ownDisplayEventsGroup` is now an inline table with the same pattern
   - The `order` field is preserved on `enabled` (1) and `displayOwn` (4); `objective_progress` in `ownDisplayEventsGroup` did not have an order before and doesn't need one now

- [ ] **Step 17: Commit Feature 2**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Core/Announcements.lua SocialQuest.lua UI/Options.lua
git commit -m "feat: suppress default WoW objective progress notification

Add UpdateQuestWatchSuppression() which unregisters UIErrorsFrame
from QUEST_WATCH_UPDATE when Social Quest's own objective progress
banner is active (db.enabled + displayOwn + objective_progress all
true). Called from OnEnable and from set callbacks on the three
controlling options. OnDisable always re-registers so the default
UI is restored when the addon is disabled."
```

---

## Manual Verification Checklist

These steps cannot be automated (no test framework for WoW Lua). Perform them in-game after loading the updated addon.

**Feature 1 — Objective text in banners:**
- [ ] Accept a multi-objective quest (e.g. kill quest + collect quest, or any multi-step quest).
- [ ] Progress one objective.
- [ ] Confirm the Social Quest banner shows `"You progressed: Quest Title — Objective Text (n/req)"`.
- [ ] In a group with another Social Quest user, confirm their banner also shows objective text.
- [ ] On a remote banner for a quest the local player does not have, confirm the banner degrades gracefully — shows title and `—  (3/5)` (empty objective text with em dash) without crashing.
- [ ] Open the Debug options panel and click Test Obj. Progress / Test Obj. Complete / Test Obj. Regression — confirm banners show `[A Daunting Task] — Kobolds Slain (3/8)` format.

**Feature 2 — Suppress default WoW notification:**
- [ ] Enable `displayOwn` and `objective_progress` in Social Quest settings.
- [ ] Progress a quest objective.
- [ ] Confirm only the Social Quest banner appears — no smaller default WoW notification.
- [ ] Disable `objective_progress` in settings — confirm the default WoW notification reappears.
- [ ] Re-enable `objective_progress` — confirm suppression is back.
- [ ] `/reload` — confirm suppression state matches current settings after reload.
- [ ] While suppression is active, disable SocialQuest via the `Enable SocialQuest` master toggle — confirm the default WoW notification reappears immediately (no `/reload` needed).
- [ ] While suppression is active, disable `Show banners for your own quest events` — confirm the default WoW notification reappears immediately.
