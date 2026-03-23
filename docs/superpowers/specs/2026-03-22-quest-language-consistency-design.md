# Quest Language Consistency — Design Spec

## Goal

Fix player-facing text across banners, outbound chat, the quest window, and the options panel so
that the language SocialQuest uses matches how WoW's own UI labels quest states and how players
actually refer to those states in conversation. No internal event names or data structures change.

---

## Background: The Inconsistency

WoW TBC uses two distinct words for two distinct moments in a quest's life:

| Moment | What happens in-game | WoW's own UI label |
|---|---|---|
| Objectives filled | All objective counts reach their target. Yellow checkmark appears beside the quest in the active quest log. Quest remains in the log. | **"Complete"** |
| Turned in | Player speaks to the NPC, collects the reward. Quest leaves the active log and moves to the Completed Quests history tab. | *(no active label — quest disappears)* |

Players reflect this split in their speech:
- *"I'm done / the quest is complete / I finished the objectives"* → objectives filled
- *"I turned it in / handed it in"* → quest delivered to NPC

The word **"completed"** is genuinely ambiguous in player speech and should be avoided for either
state where possible. **"Complete"** (adjective) is unambiguous for objectives-done.
**"Turned in"** is unambiguous for the NPC hand-off.

AQL names these events `AQL_QUEST_FINISHED` (objectives done) and `AQL_QUEST_COMPLETED` (turned
in). SocialQuest maps them to internal event types `finished` and `completed`. Neither of those
internal names changes — only the player-visible locale strings change.

---

## String Changes — enUS Reference Strings

The enUS locale file is the authoritative source for all string keys. Every non-English locale
must reflect the same semantic intent using that language's own natural gaming vocabulary
(see Localization Philosophy below).

### Banner Templates (`Core/Announcements.lua`)

| Key (the locale string itself) | Old value | New value | Triggering event |
|---|---|---|---|
| `%s finished objectives: %s` | `"%s finished objectives: %s"` | **`"%s completed: %s"`** | `AQL_QUEST_FINISHED` — all objectives filled, quest shows "Complete" checkmark in log, not yet turned in |
| `%s completed: %s` | `"%s completed: %s"` | **`"%s turned in: %s"`** | `AQL_QUEST_COMPLETED` — player delivered quest to NPC, quest leaves active log |
| `Everyone has finished: %s` | `"Everyone has finished: %s"` | **`"Everyone has completed: %s"`** | Synthesized — every engaged group member has all objectives filled or has already turned in |

> **Note:** The banner for "objectives filled" (`finished` event) is effectively adopting the old
> banner text for "turned in" (`completed` event). The two texts are swapping roles. This is
> intentional: players read "completed" as objectives-done, and "turned in" is unambiguous for
> the NPC hand-off.

### Outbound Chat Templates (`Core/Announcements.lua`)

| Key | Old value | New value | Triggering event |
|---|---|---|---|
| `{rt1} SocialQuest: Quest Complete: %s` | unchanged | **unchanged** | `AQL_QUEST_FINISHED` — already matches WoW's own "Complete" label; no change needed |
| `{rt1} SocialQuest: Quest Completed: %s` | `"Quest Completed: %s"` | **`"Quest Turned In: %s"`** | `AQL_QUEST_COMPLETED` — turned in to NPC |

### Options Panel Labels (`UI/Options.lua` via locale)

| Key | Old value | New value | What it controls |
|---|---|---|---|
| `Finished` | `"Finished"` | **`"Complete"`** | Toggle for `finished` event (objectives filled) |
| `Completed` | `"Completed"` | **`"Turned In"`** | Toggle for `completed` event (turned in to NPC) |

> These labels appear in Announce in Chat, Own Quest Banners, and Display Events groups — all
> three use the same locale keys so all three update together.

### Quest Window Labels (`UI/RowFactory.lua` via locale)

| Key | Old value | New value | State it represents |
|---|---|---|---|
| `Completed` | `"Completed"` | **`"Complete"`** | Party member has all objectives filled; shown inline in player rows on Party and Shared tabs |
| `%s FINISHED` | unchanged | **unchanged** | Party member has turned the quest in; shown as a player row label — left as-is by design |

### Debug Test Button Labels (`UI/Options.lua` via locale)

All four strings below are locale keys defined in every locale file.

| Locale key (exact) | Old value | New value |
|---|---|---|
| `Test Finished` | `"Test Finished"` | **`"Test Complete"`** |
| `Test Completed` | `"Test Completed"` | **`"Test Turned In"`** |
| `Display a demo banner and local chat preview for the 'Quest finished objectives' event.` | *(full key as shown)* | **`"Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."`** |
| `Display a demo banner and local chat preview for the 'Quest turned in' event.` | unchanged | unchanged — already correct |

---

## Lua Call Site Changes

Because AceLocale uses the English string as the key, every Lua call site that references a
changed string must also update its key. Locale files alone are not sufficient — the Lua code
must change in lockstep.

### `Core/Announcements.lua`

| Old call | New call |
|---|---|
| `L["%s finished objectives: %s"]` | `L["%s completed: %s"]` |
| `L["%s completed: %s"]` | `L["%s turned in: %s"]` |
| `L["Everyone has finished: %s"]` | `L["Everyone has completed: %s"]` |
| `L["{rt1} SocialQuest: Quest Completed: %s"]` | `L["{rt1} SocialQuest: Quest Turned In: %s"]` |

### `UI/Options.lua`

| Old call | New call |
|---|---|
| `L["Finished"]` (toggle label, three occurrences — Announce, Own Banners, Display Events) | `L["Complete"]` |
| `L["Completed"]` (toggle label, three occurrences — same groups) | `L["Turned In"]` |
| `L["Test Finished"]` | `L["Test Complete"]` |
| `L["Test Completed"]` | `L["Test Turned In"]` |
| `L["Display a demo banner and local chat preview for the 'Quest finished objectives' event."]` | `L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."]` |

### `UI/RowFactory.lua`

| Old call | New call |
|---|---|
| `L["Completed"]` (player row badge for objectives-done state) | `L["Complete"]` |

> **Key conflict resolved:** `L["Completed"]` was shared between `Options.lua` (toggle label
> for the turned-in event) and `RowFactory.lua` (player row badge for the objectives-done state).
> After this change they diverge: Options uses `L["Turned In"]` and RowFactory uses `L["Complete"]`.
> Both must be added as new independent locale keys.

---

## Localization Philosophy

**Intent over literalism.** Each language translation must convey the same semantic meaning as
the English string, using the natural vocabulary of that language's WoW player community. A
literal translation of "turned in" may produce an unnatural or confusing phrase in some
languages. The translator (or the implementation research phase) must ask: *how do players in
this language community actually refer to this moment in a quest?*

### Reference: Natural Gaming Vocabulary by Language

The following notes document the intended semantic target and the natural player vocabulary for
each locale. These are starting points for translation — verify against current community usage
where possible.

#### deDE — German
- **Objectives filled ("Complete"):** WoW DE labels this state **"Abgeschlossen"** (lit.
  "concluded/closed"). Players say *"die Quest ist fertig"* or *"abgeschlossen"*.
  Recommended banner: `%s abgeschlossen: %s`
- **Turned in:** Players say *"abgeben"* (to hand over). Common phrase: *"die Quest abgeben"*.
  Recommended banner: `%s abgegeben: %s`
- **Everyone has completed:** `Alle haben abgeschlossen: %s`
- **Chat — Turned In:** `Quest abgegeben: %s`
- **Toggle labels:** `Abgeschlossen` / `Abgegeben`

#### frFR — French
- **Objectives filled ("Complete"):** WoW FR uses **"Terminée"** (lit. "finished/done").
  Players say *"la quête est terminée"*.
  Recommended banner: `%s a terminé : %s`
- **Turned in:** Players say *"rendre la quête"* (to hand in/return the quest).
  Recommended banner: `%s a rendu : %s`
- **Everyone has completed:** `Tout le monde a terminé : %s`
- **Chat — Turned In:** `Quête rendue : %s`
- **Toggle labels:** `Terminé` / `Rendu`

#### esES — Spanish (Spain)
- **Objectives filled ("Complete"):** WoW ES uses **"Completada"**. Players say *"la misión
  está completada"*.
  Recommended banner: `%s ha completado: %s`
- **Turned in:** Players say *"entregar la misión"* (to hand in the mission).
  Recommended banner: `%s ha entregado: %s`
- **Everyone has completed:** `Todos han completado: %s`
- **Chat — Turned In:** `Misión entregada: %s`
- **Toggle labels:** `Completado` / `Entregado`

#### esMX — Spanish (Latin America)
- Same semantic targets as esES. Latin American players also use *"entregar"* for turning in.
  Translations may use identical strings to esES or vary slightly in phrasing — defer to the
  existing esMX locale's established style.

#### ptBR — Portuguese (Brazil)
- **Objectives filled ("Complete"):** Players say *"missão completa"* or *"terminei a missão"*.
  Recommended banner: `%s completou: %s`
- **Turned in:** Players say *"entregar a missão"*.
  Recommended banner: `%s entregou: %s`
- **Everyone has completed:** `Todos completaram: %s`
- **Chat — Turned In:** `Missão entregue: %s`
- **Toggle labels:** `Completo` / `Entregue`

#### itIT — Italian
- **Objectives filled ("Complete"):** WoW IT uses **"Completata"**. Players say *"la missione
  è completa"*.
  Recommended banner: `%s ha completato: %s`
- **Turned in:** Players say *"consegnare la missione"* (to deliver/hand in).
  Recommended banner: `%s ha consegnato: %s`
- **Everyone has completed:** `Tutti hanno completato: %s`
- **Chat — Turned In:** `Missione consegnata: %s`
- **Toggle labels:** `Completato` / `Consegnato`

#### koKR — Korean
- **Objectives filled ("Complete"):** WoW KR uses **"완료"** (wanryo, "completion").
  Players say *"퀘스트 완료"*.
  Recommended banner: `%s 퀘스트 완료: %s`
- **Turned in:** Players say *"반납"* (bannap, "return/hand back") — *"퀘스트를 반납하다"*.
  Recommended banner: `%s 반납: %s`
- **Everyone has completed:** `모두 완료: %s`
- **Chat — Turned In:** `퀘스트 반납: %s`
- **Toggle labels:** `완료` / `반납`

#### zhCN — Chinese (Simplified)
- **Objectives filled ("Complete"):** WoW CN uses **"已完成"** (yǐ wánchéng, "already
  complete"). Players say *"任务完成了"*.
  Recommended banner: `%s 完成了: %s`
- **Turned in:** Players say *"交任务"* (jiāo rènwu, "submit/hand in quest") — very common
  colloquial term.
  Recommended banner: `%s 交任务了: %s`
- **Everyone has completed:** `所有人都完成了: %s`
- **Chat — Turned In:** `任务已提交: %s`
- **Toggle labels:** `完成` / `已提交`

#### zhTW — Chinese (Traditional)
- **Objectives filled ("Complete"):** Same semantic target as zhCN. Traditional characters:
  *"任務完成了"*.
  Recommended banner: `%s 完成了: %s`
- **Turned in:** Players say *"交任務"* (jiāo rènwù) — traditional character equivalent of
  the zhCN colloquial term.
  Recommended banner: `%s 交任務了: %s`
- **Everyone has completed:** `所有人都完成了: %s`
- **Chat — Turned In:** `任務已提交: %s`
- **Toggle labels:** `完成` / `已提交`

#### ruRU — Russian
- **Objectives filled ("Complete"):** WoW RU uses **"Выполнено"** (vypolneno, "fulfilled/done").
  Players say *"задание выполнено"*.
  Recommended banner: `%s выполнил: %s`
- **Turned in:** Players say *"сдать задание"* (sdat' zadaniye, "to submit/hand in the quest").
  Recommended banner: `%s сдал задание: %s`
- **Everyone has completed:** `Все выполнили: %s`
- **Chat — Turned In:** `Задание сдано: %s`
- **Toggle labels:** `Выполнено` / `Сдано`

#### jaJP — Japanese
- **Objectives filled ("Complete"):** WoW JP uses **"達成"** (tassei, "achievement/accomplishment")
  or **"完了"** (kanryō, "completion"). Players say *"クエスト達成"*.
  Recommended banner: `%sがクエストを達成: %s`
- **Turned in:** WoW JP uses *"完了"* for the hand-in dialogue. Players say
  *"クエストを渡す"* (to hand over) or *"クエスト完了"*.
  Recommended banner: `%sがクエストを完了: %s`
- **Everyone has completed:** `全員達成: %s`
- **Chat — Turned In:** `クエスト完了: %s`
- **Toggle labels:** `達成` / `完了`

> **Japanese note:** Japanese WoW uses "完了" for the turn-in confirmation in the NPC dialogue,
> making it a natural fit for the turned-in state despite potential overlap with "達成" for the
> objectives-done state. The distinction is preserved by using different verbs in banner context.

---

## Documentation File Updates

### `README.md`
- Update the banner examples table to reflect new text
- Update the "Everyone Has Completed" section (already renamed from "Everyone Has Finished"
  in a prior session — verify the example banner text matches the new string)
- Update Options toggle labels in the settings reference tables

### `CLAUDE.md`
- Add version history entry for 2.4.1
- Include a note about the language inconsistency finding and the philosophy adopted
  (Complete = objectives done, Turned In = NPC hand-off)

### `changelog.txt`
- Add entry for 2.4.1 describing the language consistency fix

### `docs/` — no additional spec or plan documents need updating beyond this file

---

## Version

This is the second change on 2026-03-22. Per the versioning rule: **2.4.0 → 2.4.1**
(same day, revision increment only).

`SocialQuest.toc` line 5 must be updated from `## Version: 2.4.0` to `## Version: 2.4.1`
as part of this change.

---

## What Does NOT Change

- Internal event type strings: `finished`, `completed`, `accepted`, `abandoned`, `failed`,
  `objective_progress`, `objective_complete`, `all_complete`
- AQL callback names
- Database key names (`db.profile.party.announce.finished`, etc.)
- Lua function names
- The `%s FINISHED` quest window label (left as-is by design decision)
- The `Quest Complete:` outbound chat string for the `finished` event (already correct)
- All other banner strings (accepted, abandoned, failed, objective progress/complete/regression)
