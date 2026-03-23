# Quest Language Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all player-facing text so "completed" means objectives-done and "turned in" means NPC hand-off, consistently across banners, chat, the quest window, and the options panel.

**Architecture:** AceLocale uses the English string as the key, so every change requires updating both the Lua call site (the key) and all locale files (the key→value mapping). No internal event type names or data structures change — only locale strings and the Lua code that references them. Three Lua files have call site changes; 12 locale files need key updates.

**Tech Stack:** Lua 5.1, AceLocale-3.0, WoW TBC Anniversary (Interface 20505)

---

## Files Modified

| File | Change |
|---|---|
| `Core/Announcements.lua` | 4 locale key renames + 4 TEST_DEMOS hardcoded string updates |
| `UI/Options.lua` | 9 locale key renames across toggle labels and test buttons |
| `UI/RowFactory.lua` | 1 locale key rename |
| `Locales/enUS.lua` | Remove old keys, add new keys with `= true` |
| `Locales/deDE.lua` | Remove old keys, add new keys with German translations |
| `Locales/frFR.lua` | Remove old keys, add new keys with French translations |
| `Locales/esES.lua` | Remove old keys, add new keys with Spanish (Spain) translations |
| `Locales/esMX.lua` | Remove old keys, add new keys with Spanish (Latin America) translations |
| `Locales/ptBR.lua` | Remove old keys, add new keys with Portuguese (Brazil) translations |
| `Locales/itIT.lua` | Remove old keys, add new keys with Italian translations |
| `Locales/zhCN.lua` | Remove old keys, add new keys with Simplified Chinese translations |
| `Locales/zhTW.lua` | Remove old keys, add new keys with Traditional Chinese translations |
| `Locales/koKR.lua` | Remove old keys, add new keys with Korean translations |
| `Locales/ruRU.lua` | Remove old keys, add new keys with Russian translations |
| `Locales/jaJP.lua` | Remove old keys, add new keys with Japanese translations |
| `README.md` | Update banner examples, toggle label tables, Everyone Has Completed section |
| `CLAUDE.md` | Add version 2.5.0 history entry |
| `changelog.txt` | Add version 2.5.0 entry |
| `SocialQuest.toc` | Bump version 2.4.0 → 2.5.0 |

---

## Complete String Change Reference

### Key: what changes and why

| Old locale key / string | New locale key / string | Where used |
|---|---|---|
| `"%s finished objectives: %s"` | `"%s completed: %s"` | Banner: objectives filled (not yet turned in) |
| `"%s completed: %s"` | `"%s turned in: %s"` | Banner: quest turned in to NPC |
| `"Everyone has finished: %s"` | `"Everyone has completed: %s"` | Banner: all group members objectives filled |
| `"{rt1} SocialQuest: Quest Completed: %s"` | `"{rt1} SocialQuest: Quest Turned In: %s"` | Outbound chat: quest turned in |
| `"Finished"` (toggle label) | `"Complete"` | Options toggle label for objectives-filled event |
| `"Completed"` (toggle label) | `"Turned In"` | Options toggle label for turned-in event |
| `"Completed"` (row badge) | `"Complete"` | RowFactory player row: objectives done state |
| `"Test Finished"` | `"Test Complete"` | Debug button name |
| `"Test Completed"` | `"Test Turned In"` | Debug button name |
| `"Display a demo banner and local chat preview for the 'Quest finished objectives' event."` | `"Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."` | Debug button description |
| `"Test All Finished"` | `"Test All Completed"` | Debug button name |
| `"Display a demo banner for the 'Everyone has finished' purple notification. No chat preview (this event never generates outbound chat directly)."` | `"Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."` | Debug button description |

> **Key that stays unchanged:** `"%s completed: %s"` already exists in enUS as the old turned-in
> banner key. After the change it becomes the objectives-done banner key. The enUS key string
> itself does not need to be added or removed — only the Lua code that references it changes
> (from the `completed` template slot to the `finished` template slot).

---

## Task 1: Update Lua call sites in Core/Announcements.lua

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\Core\Announcements.lua`

- [ ] **Step 1: Update OUTBOUND_QUEST_TEMPLATES (line 83)**

Change:
```lua
    completed = L["{rt1} SocialQuest: Quest Completed: %s"],
```
To:
```lua
    completed = L["{rt1} SocialQuest: Quest Turned In: %s"],
```

- [ ] **Step 2: Update BANNER_QUEST_TEMPLATES (lines 102-103)**

Change:
```lua
    finished  = L["%s finished objectives: %s"],
    completed = L["%s completed: %s"],
```
To:
```lua
    finished  = L["%s completed: %s"],
    completed = L["%s turned in: %s"],
```

- [ ] **Step 3: Update Everyone banner (line 392)**

Change:
```lua
    local msg = string.format(L["Everyone has finished: %s"], title)
```
To:
```lua
    local msg = string.format(L["Everyone has completed: %s"], title)
```

- [ ] **Step 4: Update TEST_DEMOS hardcoded strings**

The TEST_DEMOS table has hardcoded English demo strings (not locale keys — these bypass the locale system intentionally for the debug preview). Find the TEST_DEMOS table (around line 571) and update:

```lua
    finished = {
        outbound = "{rt1} SocialQuest: Quest Complete: |cFFFFD200[A Daunting Task]|r",
        banner   = "TestPlayer completed: [A Daunting Task]",   -- was "finished objectives"
        colorKey = "finished",
    },
    completed = {
        outbound = "{rt1} SocialQuest: Quest Turned In: |cFFFFD200[A Daunting Task]|r (Step 2)",  -- was "Quest Completed"
        banner   = "TestPlayer turned in: [A Daunting Task] (Step 2)",   -- was "completed"
        colorKey = "completed",
    },
```

And the all_complete entry:
```lua
    all_complete = {
        outbound = nil,
        banner   = "Everyone has completed: [A Daunting Task]",   -- was "has finished"
        colorKey = "all_complete",
    },
```

- [ ] **Step 5: Commit**

```
git add Core/Announcements.lua
git commit -m "refactor: update locale key references and TEST_DEMOS strings in Announcements.lua

- BANNER_QUEST_TEMPLATES: finished→L['%s completed: %s'], completed→L['%s turned in: %s']
- OUTBOUND_QUEST_TEMPLATES: completed→L['{rt1} SocialQuest: Quest Turned In: %s']
- Everyone banner: L['Everyone has finished'] → L['Everyone has completed']
- TEST_DEMOS: update hardcoded demo strings to match new language"
```

---

## Task 2: Update Lua call sites in UI/Options.lua

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\Options.lua`

- [ ] **Step 1: Update toggle labels — Announce in Chat group (lines 44, 47)**

Change:
```lua
            finished  = toggle(L["Finished"],
```
To:
```lua
            finished  = toggle(L["Complete"],
```

Change:
```lua
            completed = toggle(L["Completed"],
```
To:
```lua
            completed = toggle(L["Turned In"],
```

- [ ] **Step 2: Update toggle labels — Own Quest Banners group (lines 81, 84)**

Same replacements: `L["Finished"]` → `L["Complete"]` and `L["Completed"]` → `L["Turned In"]`

- [ ] **Step 3: Update toggle labels — Display Events group (lines 121, 124)**

Same replacements: `L["Finished"]` → `L["Complete"]` and `L["Completed"]` → `L["Turned In"]`

- [ ] **Step 4: Update testFinished button (lines 332-333)**

Change:
```lua
                                name = L["Test Finished"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest finished objectives' event."],
```
To:
```lua
                                name = L["Test Complete"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."],
```

- [ ] **Step 5: Update testCompleted button (line 338)**

Change:
```lua
                                name = L["Test Completed"],
```
To:
```lua
                                name = L["Test Turned In"],
```

- [ ] **Step 6: Update testAllComplete button (lines 368-369)**

Change:
```lua
                                name = L["Test All Finished"],
                                desc = L["Display a demo banner for the 'Everyone has finished' purple notification. No chat preview (this event never generates outbound chat directly)."],
```
To:
```lua
                                name = L["Test All Completed"],
                                desc = L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."],
```

- [ ] **Step 7: Commit**

```
git add UI/Options.lua
git commit -m "refactor: update locale key references in Options.lua

- Toggle labels: L['Finished']→L['Complete'], L['Completed']→L['Turned In'] (3 groups each)
- Test buttons: Test Finished→Test Complete, Test Completed→Test Turned In
- Test All Finished→Test All Completed with updated description"
```

---

## Task 3: Update Lua call site in UI/RowFactory.lua

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\UI\RowFactory.lua:333`

- [ ] **Step 1: Update player row badge (line 333)**

Change:
```lua
        fs:SetText(C.white .. name .. C.reset .. " " .. SocialQuestColors.GetUIColor("completed") .. L["Completed"] .. C.reset)
```
To:
```lua
        fs:SetText(C.white .. name .. C.reset .. " " .. SocialQuestColors.GetUIColor("completed") .. L["Complete"] .. C.reset)
```

- [ ] **Step 2: Commit**

```
git add UI/RowFactory.lua
git commit -m "refactor: update locale key L['Completed']→L['Complete'] in RowFactory.lua

Player row badge for objectives-done state now uses 'Complete' to match WoW's own
quest log label, distinguishing it from 'Turned In' (the NPC hand-off state)."
```

---

## Task 4: Update enUS locale

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\enUS.lua`

Read the file first to find exact line numbers before editing.

- [ ] **Step 1: Update banner template keys**

In the inbound banner templates section:
- Remove: `L["%s finished objectives: %s"]  = true`
- Add: `L["%s turned in: %s"]               = true`  (the `"%s completed: %s"` key stays — it already exists and is reused)
- Change: `L["Everyone has finished: %s"] = true` → `L["Everyone has completed: %s"] = true`

- [ ] **Step 2: Update outbound chat template key**

- Change: `L["{rt1} SocialQuest: Quest Completed: %s"] = true` → `L["{rt1} SocialQuest: Quest Turned In: %s"] = true`

- [ ] **Step 3: Update options toggle label keys**

In the options section:
- Change: `L["Finished"]  = true` → `L["Complete"]  = true`
- Change: `L["Completed"] = true` → `L["Turned In"] = true`

- [ ] **Step 4: Update debug test button keys**

- Change: `L["Test Finished"]  = true` → `L["Test Complete"]  = true`
- Change: `L["Test Completed"] = true` → `L["Test Turned In"] = true`
- Change old description key for testFinished:
  `L["Display a demo banner and local chat preview for the 'Quest finished objectives' event."] = true`
  → `L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = true`
- Change: `L["Test All Finished"] = true` → `L["Test All Completed"] = true`
- Change old testAllComplete description key:
  `L["Display a demo banner for the 'Everyone has finished' purple notification. No chat preview (this event never generates outbound chat directly)."] = true`
  → `L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = true`

- [ ] **Step 5: Update option toggle descriptions that reference old language**

These description strings appear as locale keys and their wording should stay accurate:
- `L["Show a banner on screen when a group member finishes all objectives on a quest."]` — change to:
  `L["Show a banner on screen when a group member completes all objectives on a quest."]`
  (matches the new "Complete" toggle label)

- [ ] **Step 6: Commit**

```
git add Locales/enUS.lua
git commit -m "locale(enUS): update keys for quest language consistency

- Remove '%s finished objectives: %s'; add '%s turned in: %s'
- Rename 'Everyone has finished' → 'Everyone has completed'
- Rename 'Quest Completed' → 'Quest Turned In' (outbound chat)
- Rename toggles: 'Finished'→'Complete', 'Completed'→'Turned In'
- Rename test buttons: Test Finished→Test Complete, Test Completed→Test Turned In,
  Test All Finished→Test All Completed with updated descriptions"
```

---

## Task 5: Update European locale files

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\deDE.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\frFR.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\esES.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\esMX.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\ptBR.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\itIT.lua`

For each file: read it first to find the existing translations for the old keys, then replace old keys with new keys using the translations below. The key string must match exactly (it's used for lookup); the value is the localized text.

**Translation reference:**

| Old key | New key | deDE | frFR | esES | esMX | ptBR | itIT |
|---|---|---|---|---|---|---|---|
| `%s finished objectives: %s` | `%s completed: %s` | `%s abgeschlossen: %s` | `%s a terminé : %s` | `%s ha completado: %s` | `%s ha completado: %s` | `%s completou: %s` | `%s ha completato: %s` |
| `%s completed: %s` | `%s turned in: %s` | `%s abgegeben: %s` | `%s a rendu : %s` | `%s ha entregado: %s` | `%s ha entregado: %s` | `%s entregou: %s` | `%s ha consegnato: %s` |
| `Everyone has finished: %s` | `Everyone has completed: %s` | `Alle haben abgeschlossen: %s` | `Tout le monde a terminé : %s` | `Todos han completado: %s` | `Todos han completado: %s` | `Todos completaram: %s` | `Tutti hanno completato: %s` |
| `{rt1} SocialQuest: Quest Completed: %s` | `{rt1} SocialQuest: Quest Turned In: %s` | `{rt1} SocialQuest: Quest abgegeben: %s` | `{rt1} SocialQuest: Quête rendue : %s` | `{rt1} SocialQuest: Misión entregada: %s` | `{rt1} SocialQuest: Misión entregada: %s` | `{rt1} SocialQuest: Missão entregue: %s` | `{rt1} SocialQuest: Missione consegnata: %s` |
| `Finished` (toggle) | `Complete` | `Abgeschlossen` | `Terminé` | `Completado` | `Completado` | `Completo` | `Completato` |
| `Completed` (toggle) | `Turned In` | `Abgegeben` | `Rendu` | `Entregado` | `Entregado` | `Entregue` | `Consegnato` |
| `Completed` (row badge) | `Complete` | same as toggle above | same | same | same | same | same |
| `Test Finished` | `Test Complete` | adapt from existing style | adapt | adapt | adapt | adapt | adapt |
| `Test Completed` | `Test Turned In` | adapt from existing style | adapt | adapt | adapt | adapt | adapt |
| `Test All Finished` | `Test All Completed` | adapt | adapt | adapt | adapt | adapt | adapt |

For the test button names and descriptions, adapt the translation from the existing locale strings' style — look at how `Test Flight Discovery` is translated in the file and match that style. The description strings for changed test buttons should reflect the updated English description content.

> **Note on `Completed` (row badge):** In the non-English locales, the old `L["Completed"]` key
> was used for both the toggle label and the row badge. After the split, both `L["Complete"]`
> (objectives-done, used by both toggle and badge) and `L["Turned In"]` (turned-in toggle) are
> new keys. The value for `L["Complete"]` is the same word as the objectives-done toggle, so
> one entry covers both uses.

- [ ] **Step 1: Update deDE.lua**
- [ ] **Step 2: Update frFR.lua**
- [ ] **Step 3: Update esES.lua**
- [ ] **Step 4: Update esMX.lua**
- [ ] **Step 5: Update ptBR.lua**
- [ ] **Step 6: Update itIT.lua**

- [ ] **Step 7: Commit**

```
git add Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua Locales/ptBR.lua Locales/itIT.lua
git commit -m "locale(European): update keys for quest language consistency

Rename keys to match English changes. Translations use natural player vocabulary:
- objectives-done: abgeschlossen/terminé/completado/completou/completato
- turned-in: abgegeben/rendu/entregado/entregou/consegnato"
```

---

## Task 6: Update CJK and Russian locale files

**Files:**
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\zhCN.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\zhTW.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\koKR.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\ruRU.lua`
- Modify: `D:\Projects\Wow Addons\Social-Quest\Locales\jaJP.lua`

Same process as Task 5. Read each file first, then replace old keys with new keys.

**Translation reference:**

| Old key | New key | zhCN | zhTW | koKR | ruRU | jaJP |
|---|---|---|---|---|---|---|
| `%s finished objectives: %s` | `%s completed: %s` | `%s 完成了: %s` | `%s 完成了: %s` | `%s 퀘스트 완료: %s` | `%s выполнил: %s` | `%sがクエストを達成: %s` |
| `%s completed: %s` | `%s turned in: %s` | `%s 交任务了: %s` | `%s 交任務了: %s` | `%s 반납: %s` | `%s сдал задание: %s` | `%sがクエストを完了: %s` |
| `Everyone has finished: %s` | `Everyone has completed: %s` | `所有人都完成了: %s` | `所有人都完成了: %s` | `모두 완료: %s` | `Все выполнили: %s` | `全員達成: %s` |
| `{rt1} SocialQuest: Quest Completed: %s` | `{rt1} SocialQuest: Quest Turned In: %s` | `{rt1} SocialQuest: 任务已提交: %s` | `{rt1} SocialQuest: 任務已提交: %s` | `{rt1} SocialQuest: 퀘스트 반납: %s` | `{rt1} SocialQuest: Задание сдано: %s` | `{rt1} SocialQuest: クエスト完了: %s` |
| `Finished` (toggle) | `Complete` | `完成` | `完成` | `완료` | `Выполнено` | `達成` |
| `Completed` (toggle) | `Turned In` | `已提交` | `已提交` | `반납` | `Сдано` | `完了` |
| `Test Finished` | `Test Complete` | adapt | adapt | adapt | adapt | adapt |
| `Test Completed` | `Test Turned In` | adapt | adapt | adapt | adapt | adapt |
| `Test All Finished` | `Test All Completed` | adapt | adapt | adapt | adapt | adapt |

> **Japanese note:** "達成" (tassei) for objectives-done and "完了" (kanryō) for turned-in are
> the correct distinction. WoW JP uses "完了" in the NPC turn-in dialogue, making it the natural
> choice for the hand-off state. "達成" matches the achievement/objectives-done meaning.

- [ ] **Step 1: Update zhCN.lua**
- [ ] **Step 2: Update zhTW.lua**
- [ ] **Step 3: Update koKR.lua**
- [ ] **Step 4: Update ruRU.lua**
- [ ] **Step 5: Update jaJP.lua**

- [ ] **Step 6: Commit**

```
git add Locales/zhCN.lua Locales/zhTW.lua Locales/koKR.lua Locales/ruRU.lua Locales/jaJP.lua
git commit -m "locale(CJK+RU): update keys for quest language consistency

Rename keys to match English changes. Translations use natural player vocabulary:
- zhCN/zhTW: 完成了 (objectives done) / 交任务了|交任務了 (turned in)
- koKR: 완료 (objectives done) / 반납 (turned in)
- ruRU: выполнил (objectives done) / сдал задание (turned in)
- jaJP: 達成 (objectives done) / 完了 (turned in, matches WoW JP NPC dialogue)"
```

---

## Task 7: Documentation and version bump

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `changelog.txt`
- Modify: `SocialQuest.toc` line 5

- [ ] **Step 1: Bump version in SocialQuest.toc**

Change `## Version: 2.4.0` to `## Version: 2.5.0`

- [ ] **Step 2: Update README.md**

Three areas to update:
1. In the **On-Screen Banner Notifications** table, update the two changed rows:
   - `Objectives complete | Thralldar finished objectives: ...` → `Objectives complete | Thralldar completed: The Cipher of Damnation`
   - `Turned in | Thralldar completed: ...` → `Turned in | Thralldar turned in: The Cipher of Damnation`

2. In the **"Everyone Has Completed" section** (already named correctly), verify the example banner text reads `Everyone has completed: The Cipher of Damnation` (not "finished").

3. In the **settings tables** throughout the page, update toggle labels from `Finished`/`Completed` to `Complete`/`Turned In` wherever they appear in the Party, Raid, Battleground, Whisper Friends, and General sections.

- [ ] **Step 3: Add CLAUDE.md version history entry**

Add before the existing `### Version 2.4.0` entry:

```markdown
### Version 2.5.0 (March 2026 — Improvements branch)
- Quest language consistency: corrected player-facing text to match how WoW's UI and players
  refer to quest states. "Complete" now consistently means all objectives are filled (the yellow
  checkmark state in the quest log). "Turned in" means the quest was delivered to the NPC.
  The word "completed" had been used ambiguously for both states and has been reassigned to the
  objectives-done banner only, where players expect it. Changes affect banner text, outbound chat,
  options toggle labels, and debug test button names across all 12 locale files. No internal
  event names or data structures changed.
```

- [ ] **Step 4: Add changelog.txt entry**

Add at the top of the file (before Version 2.4.0):

```
Version 2.5.0 (March 2026)
- Quest language consistency: "Complete" now means all objectives are filled (matching WoW's
  own quest log label). "Turned in" means the quest was delivered to the NPC. Updated banner
  text, outbound chat messages, options toggle labels, and debug test button names across all
  12 locale files. Non-English translations use natural player vocabulary for each language
  rather than literal translations (e.g. German "abgegeben", French "rendu", Korean "반납",
  Chinese "交任务").
```

- [ ] **Step 5: Commit**

```
git add SocialQuest.toc README.md CLAUDE.md changelog.txt
git commit -m "docs: update README, CLAUDE.md, changelog for quest language consistency (v2.5.0)

Banner examples and toggle label tables updated to reflect new 'Complete'/'Turned In'
language. Version bumped to 2.5.0."
```
