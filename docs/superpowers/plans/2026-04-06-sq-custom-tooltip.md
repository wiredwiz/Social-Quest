# SocialQuest Custom Quest Tooltip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a rich, alias-aware custom quest tooltip that renders quest details alongside party progress; change the wire format from `(questID)` to `{questID}` to eliminate Questie chat filter collision; add a Tooltips config group with Enhance/Replace options.

**Architecture:** Wire format change in `Core/Announcements.lua` + updated chat filter patterns in `UI/Tooltips.lua`. New `SocialQuestTooltips:BuildTooltip(tooltip, questID)` function renders the full tooltip using `AQL:GetQuestInfo` fields (including Details capability fields). Existing `addGroupProgressToTooltip` is refactored so its party-lines logic lives in a shared `renderPartyProgress` helper callable by both the augment path and `BuildTooltip`. `SetItemRef` hook calls `BuildTooltip` directly for `socialquest:` links. `SetHyperlink` hook gains Replace logic. Retail `TooltipDataProcessor` is guarded by `_sqTooltipBuilt` flag.

**Tech Stack:** Lua, Ace3 (AceConfig, AceDB, AceLocale), WoW tooltip API, AQL-1.0 public API.

---

## File Map

| File | Change |
|---|---|
| `Core/Announcements.lua` | Change `BuildQuestLink` from `(questID)` to `{questID}`; update comment |
| `UI/Tooltips.lua` | New `SQ_LINK_PATTERN` for `{questID}`; keep legacy `(questID)` pattern as fallback; extract `renderPartyProgress` helper; refactor `addGroupProgressToTooltip`; new `BuildTooltip`; update `SetItemRef` hook; restructure `SetHyperlink` hook with Replace logic; Retail `TooltipDataProcessor` guarded by `_sqTooltipBuilt` |
| `UI/Options.lua` | Add `tooltips` group (order=10); bump `debug` to order=11 |
| `SocialQuest.lua` | Add `tooltips = { enhance=true, replaceBlizzard=false, replaceQuestie=false }` to profile defaults |
| `Locales/enUS.lua` through `Locales/jaJP.lua` (all 12 files) | New locale keys for Tooltips config group, status lines, NPC labels, level/type badges |
| `CLAUDE.md` | Document new wire format, Tooltips config options, `BuildTooltip` API |

---

### Task 1: Wire format change — `BuildQuestLink` and chat filter patterns

**Files:**
- Modify: `Core/Announcements.lua:112-124`
- Modify: `UI/Tooltips.lua:119-134`

- [ ] **Step 1: Change `BuildQuestLink` to use `{questID}`**

In `Core/Announcements.lua`, replace the comment block and function body (lines 112–124):

```lua
-- Builds the outbound quest link string for SendChatMessage.
-- Returns plain text [[level] Quest Name {questID}] on all versions — no |H codes,
-- so SendChatMessage never taints on Retail and never gets stripped on TBC.
-- Uses {questID} (curly braces) to distinguish from Questie's ChatFilter.lua, which
-- explicitly matches [[level] Name (questID)] with parentheses and competes to convert
-- that format to its own |Hquestie:| link type.
-- A ChatFrame_AddMessageEventFilter in Tooltips.lua converts this marker to
-- |Hsocialquest:questID:level| locally on each receiving client before display.
-- Returns nil when questID or questName is nil (safe: callers fall back to plain title).
local function BuildQuestLink(questID, questName, questLevel)
    if not questID or not questName then return nil end
    local level = questLevel or 0
    return "[[" .. level .. "] " .. questName .. " {" .. questID .. "}]"
end
-- Exposed for unit tests. Not part of the public API.
SocialQuestAnnounce._BuildQuestLink = BuildQuestLink
```

- [ ] **Step 2: Update `SQ_LINK_PATTERN` and `sqChatFilter` in `UI/Tooltips.lua`**

Replace lines 119–134 (the `SQ_LINK_PATTERN` constant and `sqChatFilter` function):

```lua
    -- New wire format: [[level] Quest Name {questID}] — curly braces avoid Questie collision.
    local SQ_LINK_PATTERN = "%[%[(%d+)%]%s(.-)%s*{(%d+)}%]"
    -- Legacy wire format: [[level] Quest Name (questID)] — for backward compat with old SQ clients.
    -- Only applied when Questie is not installed; with Questie present, Questie's own filter
    -- handles this format and we skip it to avoid producing duplicate socialquest: links.
    local SQ_LINK_PATTERN_LEGACY = "%[%[(%d+)%]%s(.-)%s*%((%d+)%)%]"
    local function sqChatFilter(_, _, msg, ...)
        if not msg then return end
        local function convert(levelStr, name, questIDStr)
            local level   = tonumber(levelStr) or 0
            local questID = tonumber(questIDStr)
            if not questID then return end
            return "|cffffff00|Hsocialquest:" .. questID .. ":" .. level
                   .. "|h[" .. level .. "] " .. name .. "|h|r"
        end
        local newMsg = msg:gsub(SQ_LINK_PATTERN, convert)
        -- Legacy fallback: only when Questie is absent (Questie handles its own (questID) format).
        if newMsg == msg and not QuestieLoader then
            newMsg = msg:gsub(SQ_LINK_PATTERN_LEGACY, convert)
        end
        if newMsg ~= msg then
            return false, newMsg, ...
        end
    end
```

- [ ] **Step 3: Run unit tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both pass with 0 failures. The wire format change has no effect on FilterParser or TabUtils.

- [ ] **Step 4: Verify in-game**

Accept a quest and send a party announcement. Confirm the chat message shows `[[level] Name {questID}]` format. Click the link — it should produce a `socialquest:` link click (tooltip shows via the existing `SetItemRef` hook). With an old-format `(questID)` message pasted in party chat (manual test), confirm it still converts when Questie is absent.

- [ ] **Step 5: Commit**

```bash
git add Core/Announcements.lua UI/Tooltips.lua
git commit -m "feat: change SQ wire format from (questID) to {questID} to avoid Questie chat filter collision"
```

---

### Task 2: AceDB defaults for Tooltips config

**Files:**
- Modify: `SocialQuest.lua:317-322` (the `window` and `minimap` defaults block)

- [ ] **Step 1: Add `tooltips` defaults to profile**

In `SocialQuest.lua`, find the `profile` defaults and add `tooltips` after `window`:

```lua
            window = {
                autoFilterInstance = true,
                autoFilterZone     = false,
            },
            tooltips = {
                enhance         = true,
                replaceBlizzard = false,
                replaceQuestie  = false,
            },
            minimap = { hide = false },
```

- [ ] **Step 2: Run unit tests and verify**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both pass. Log in-game and open `/sq config` — the Tooltips tab doesn't exist yet, but no Lua errors should appear and `db.tooltips.enhance` should return `true` when queried from the console.

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: add AceDB profile defaults for Tooltips config group"
```

---

### Task 3: Locale keys for Tooltips config, status lines, NPC labels, and type badges

**Files:**
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/frFR.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/esMX.lua`
- Modify: `Locales/zhCN.lua`
- Modify: `Locales/zhTW.lua`
- Modify: `Locales/koKR.lua`
- Modify: `Locales/ruRU.lua`
- Modify: `Locales/jaJP.lua`
- Modify: `Locales/ptBR.lua`
- Modify: `Locales/itIT.lua`

- [ ] **Step 1: Add keys to `Locales/enUS.lua`**

Append after the `-- UI/Options.lua — general toggles` section:

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = true
L["Enhance Questie/Blizzard tooltips"]               = true
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = true
L["Replace Blizzard quest tooltips"]                  = true
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = true
L["Replace Questie quest tooltips"]                   = true
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = true

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = true
L["You have completed this quest"]                    = true
L["You are eligible for this quest"]                  = true
L["You are not eligible for this quest"]              = true

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = true
L["Turn In:"]                                         = true

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = true
L["[Dungeon]"]                                        = true
L["[Raid]"]                                           = true
L["[Group]"]                                          = true
```

- [ ] **Step 2: Add keys to `Locales/deDE.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Schnellinfos"
L["Enhance Questie/Blizzard tooltips"]               = "Questie/Blizzard-Schnellinfos erweitern"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Fügt den bestehenden Quest-Schnellinfos einen Gruppenfortschrittsabschnitt hinzu."
L["Replace Blizzard quest tooltips"]                  = "Blizzard-Quest-Schnellinfos ersetzen"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Zeigt beim Klick auf einen Quest-Link den vollständigen SocialQuest-Tooltip statt des WoW-Standardtooltips."
L["Replace Questie quest tooltips"]                   = "Questie-Quest-Schnellinfos ersetzen"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Zeigt beim Klick auf einen Questie-Link den vollständigen SocialQuest-Tooltip. Nicht verfügbar, wenn Questie nicht installiert ist."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Du bist auf dieser Quest"
L["You have completed this quest"]                    = "Du hast diese Quest abgeschlossen"
L["You are eligible for this quest"]                  = "Du kannst diese Quest annehmen"
L["You are not eligible for this quest"]              = "Du kannst diese Quest nicht annehmen"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Questgeber:"
L["Turn In:"]                                         = "Abgabe:"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "Stufe %d"
L["[Dungeon]"]                                        = "[Verlies]"
L["[Raid]"]                                           = "[Schlachtzug]"
L["[Group]"]                                          = "[Gruppe]"
```

- [ ] **Step 3: Add keys to `Locales/frFR.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Info-bulles"
L["Enhance Questie/Blizzard tooltips"]               = "Améliorer les info-bulles Questie/Blizzard"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Ajoute la progression du groupe aux info-bulles de quête existantes."
L["Replace Blizzard quest tooltips"]                  = "Remplacer les info-bulles de quête Blizzard"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Affiche l'info-bulle complète de SocialQuest au lieu de l'info-bulle de base de WoW."
L["Replace Questie quest tooltips"]                   = "Remplacer les info-bulles de quête Questie"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Affiche l'info-bulle complète de SocialQuest au lieu de l'info-bulle de Questie. Non disponible si Questie n'est pas installé."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Vous suivez cette quête"
L["You have completed this quest"]                    = "Vous avez accompli cette quête"
L["You are eligible for this quest"]                  = "Vous pouvez accepter cette quête"
L["You are not eligible for this quest"]              = "Vous ne pouvez pas accepter cette quête"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Donneur de quête :"
L["Turn In:"]                                         = "Restitution :"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "Niveau %d"
L["[Dungeon]"]                                        = "[Donjon]"
L["[Raid]"]                                           = "[Raid]"
L["[Group]"]                                          = "[Groupe]"
```

- [ ] **Step 4: Add keys to `Locales/esES.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Globos de información"
L["Enhance Questie/Blizzard tooltips"]               = "Mejorar globos de Questie/Blizzard"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Añade el progreso del grupo a los globos de misión existentes."
L["Replace Blizzard quest tooltips"]                  = "Sustituir globos de misión de Blizzard"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Al hacer clic en un enlace de misión, muestra el globo completo de SocialQuest en lugar del básico de WoW."
L["Replace Questie quest tooltips"]                   = "Sustituir globos de misión de Questie"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Al hacer clic en un enlace de Questie, muestra el globo completo de SocialQuest. No disponible si Questie no está instalado."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Tienes esta misión"
L["You have completed this quest"]                    = "Has completado esta misión"
L["You are eligible for this quest"]                  = "Puedes aceptar esta misión"
L["You are not eligible for this quest"]              = "No puedes aceptar esta misión"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Dador de misión:"
L["Turn In:"]                                         = "Entrega:"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "Nivel %d"
L["[Dungeon]"]                                        = "[Mazmorra]"
L["[Raid]"]                                           = "[Banda]"
L["[Group]"]                                          = "[Grupo]"
```

- [ ] **Step 5: Add keys to `Locales/esMX.lua`**

Identical to esES — copy the same block into esMX.lua.

- [ ] **Step 6: Add keys to `Locales/zhCN.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "提示信息"
L["Enhance Questie/Blizzard tooltips"]               = "增强 Questie/暴雪任务提示"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "在现有任务提示框中添加队伍成员进度。"
L["Replace Blizzard quest tooltips"]                  = "替换暴雪任务提示"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "点击任务链接时，显示 SocialQuest 完整提示框而非原版任务提示框。"
L["Replace Questie quest tooltips"]                   = "替换 Questie 任务提示"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "点击 Questie 链接时，显示 SocialQuest 完整提示框而非 Questie 提示框。未安装 Questie 时不可用。"

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "你正在进行此任务"
L["You have completed this quest"]                    = "你已完成此任务"
L["You are eligible for this quest"]                  = "你可以接取此任务"
L["You are not eligible for this quest"]              = "你无法接取此任务"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "任务发布者："
L["Turn In:"]                                         = "交任务处："

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "%d 级"
L["[Dungeon]"]                                        = "[地下城]"
L["[Raid]"]                                           = "[团队副本]"
L["[Group]"]                                          = "[组队]"
```

- [ ] **Step 7: Add keys to `Locales/zhTW.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "提示資訊"
L["Enhance Questie/Blizzard tooltips"]               = "增強 Questie/暴雪任務提示"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "在現有任務提示框中加入小隊成員進度。"
L["Replace Blizzard quest tooltips"]                  = "取代暴雪任務提示"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "點擊任務連結時，顯示 SocialQuest 完整提示框而非原版任務提示框。"
L["Replace Questie quest tooltips"]                   = "取代 Questie 任務提示"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "點擊 Questie 連結時，顯示 SocialQuest 完整提示框而非 Questie 提示框。未安裝 Questie 時不可用。"

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "你正在進行此任務"
L["You have completed this quest"]                    = "你已完成此任務"
L["You are eligible for this quest"]                  = "你可以接取此任務"
L["You are not eligible for this quest"]              = "你無法接取此任務"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "任務發布者："
L["Turn In:"]                                         = "交任務："

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "%d 級"
L["[Dungeon]"]                                        = "[地城]"
L["[Raid]"]                                           = "[團隊]"
L["[Group]"]                                          = "[組隊]"
```

- [ ] **Step 8: Add keys to `Locales/koKR.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "툴팁"
L["Enhance Questie/Blizzard tooltips"]               = "Questie/블리자드 툴팁 향상"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "기존 퀘스트 툴팁에 파티 진행 상황을 추가합니다."
L["Replace Blizzard quest tooltips"]                  = "블리자드 퀘스트 툴팁 교체"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "퀘스트 링크 클릭 시 WoW 기본 툴팁 대신 SocialQuest 전체 툴팁을 표시합니다."
L["Replace Questie quest tooltips"]                   = "Questie 퀘스트 툴팁 교체"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Questie 링크 클릭 시 Questie 툴팁 대신 SocialQuest 전체 툴팁을 표시합니다. Questie가 없으면 사용할 수 없습니다."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "현재 이 퀘스트를 진행 중입니다"
L["You have completed this quest"]                    = "이 퀘스트를 완료했습니다"
L["You are eligible for this quest"]                  = "이 퀘스트를 받을 수 있습니다"
L["You are not eligible for this quest"]              = "이 퀘스트를 받을 수 없습니다"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "퀘스트 수여자:"
L["Turn In:"]                                         = "완료:"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "%d 레벨"
L["[Dungeon]"]                                        = "[던전]"
L["[Raid]"]                                           = "[공격대]"
L["[Group]"]                                          = "[그룹]"
```

- [ ] **Step 9: Add keys to `Locales/ruRU.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Подсказки"
L["Enhance Questie/Blizzard tooltips"]               = "Улучшить подсказки Questie/Blizzard"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Добавляет прогресс группы к существующим подсказкам заданий."
L["Replace Blizzard quest tooltips"]                  = "Заменить подсказки заданий Blizzard"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "При нажатии на ссылку задания показывает полную подсказку SocialQuest вместо стандартной WoW."
L["Replace Questie quest tooltips"]                   = "Заменить подсказки заданий Questie"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "При нажатии на ссылку Questie показывает полную подсказку SocialQuest вместо Questie. Недоступно без Questie."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Вы выполняете это задание"
L["You have completed this quest"]                    = "Вы выполнили это задание"
L["You are eligible for this quest"]                  = "Вы можете принять это задание"
L["You are not eligible for this quest"]              = "Вы не можете принять это задание"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Источник задания:"
L["Turn In:"]                                         = "Сдать:"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "%d ур."
L["[Dungeon]"]                                        = "[Подземелье]"
L["[Raid]"]                                           = "[Рейд]"
L["[Group]"]                                          = "[Группа]"
```

- [ ] **Step 10: Add keys to `Locales/jaJP.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "ツールチップ"
L["Enhance Questie/Blizzard tooltips"]               = "Questie/Blizzardのツールチップを拡張"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "既存のクエストツールチップにパーティ進行状況を追加します。"
L["Replace Blizzard quest tooltips"]                  = "Blizzardのクエストツールチップを置換"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "クエストリンクのクリック時にWoWの基本ツールチップの代わりにSocialQuestのツールチップを表示します。"
L["Replace Questie quest tooltips"]                   = "Questieのクエストツールチップを置換"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Questieリンクのクリック時にQuestieのツールチップの代わりにSocialQuestのツールチップを表示します。Questie未インストール時は使用できません。"

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "このクエストを進行中です"
L["You have completed this quest"]                    = "このクエストを完了しました"
L["You are eligible for this quest"]                  = "このクエストを受注できます"
L["You are not eligible for this quest"]              = "このクエストを受注できません"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "クエスト発行者："
L["Turn In:"]                                         = "完了報告："

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "レベル%d"
L["[Dungeon]"]                                        = "[ダンジョン]"
L["[Raid]"]                                           = "[レイド]"
L["[Group]"]                                          = "[グループ]"
```

- [ ] **Step 11: Add keys to `Locales/ptBR.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Dicas de ferramenta"
L["Enhance Questie/Blizzard tooltips"]               = "Aprimorar dicas do Questie/Blizzard"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Adiciona o progresso do grupo às dicas de missão existentes."
L["Replace Blizzard quest tooltips"]                  = "Substituir dicas de missão do Blizzard"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Ao clicar em um link de missão, exibe a dica completa do SocialQuest em vez da dica básica do WoW."
L["Replace Questie quest tooltips"]                   = "Substituir dicas de missão do Questie"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Ao clicar em um link do Questie, exibe a dica completa do SocialQuest em vez da do Questie. Indisponível sem o Questie."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Você está nesta missão"
L["You have completed this quest"]                    = "Você completou esta missão"
L["You are eligible for this quest"]                  = "Você pode aceitar esta missão"
L["You are not eligible for this quest"]              = "Você não pode aceitar esta missão"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Doador de missão:"
L["Turn In:"]                                         = "Entrega:"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "Nível %d"
L["[Dungeon]"]                                        = "[Masmorra]"
L["[Raid]"]                                           = "[Banda]"
L["[Group]"]                                          = "[Grupo]"
```

- [ ] **Step 12: Add keys to `Locales/itIT.lua`**

```lua
-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Tooltip"
L["Enhance Questie/Blizzard tooltips"]               = "Migliora i tooltip di Questie/Blizzard"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Aggiunge il progresso del gruppo ai tooltip delle missioni esistenti."
L["Replace Blizzard quest tooltips"]                  = "Sostituisci i tooltip di missione di Blizzard"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Cliccando un link di missione, mostra il tooltip completo di SocialQuest invece di quello base di WoW."
L["Replace Questie quest tooltips"]                   = "Sostituisci i tooltip di missione di Questie"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Cliccando un link Questie, mostra il tooltip completo di SocialQuest invece di quello di Questie. Non disponibile senza Questie."

-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Stai svolgendo questa missione"
L["You have completed this quest"]                    = "Hai completato questa missione"
L["You are eligible for this quest"]                  = "Puoi accettare questa missione"
L["You are not eligible for this quest"]              = "Non puoi accettare questa missione"

-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Iniziatore:"
L["Turn In:"]                                         = "Consegna:"

-- UI/Tooltips.lua — BuildTooltip level / type line
L["Level %d"]                                         = "Livello %d"
L["[Dungeon]"]                                        = "[Istanza]"
L["[Raid]"]                                           = "[Incursione]"
L["[Group]"]                                          = "[Gruppo]"
```

- [ ] **Step 13: Run unit tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both pass.

- [ ] **Step 14: Commit**

```bash
git add Locales/enUS.lua Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua Locales/zhCN.lua Locales/zhTW.lua Locales/koKR.lua Locales/ruRU.lua Locales/jaJP.lua Locales/ptBR.lua Locales/itIT.lua
git commit -m "feat: add locale keys for Tooltips config group, status lines, NPC labels, and type badges"
```

---

### Task 4: Add Tooltips config group to `UI/Options.lua`

**Files:**
- Modify: `UI/Options.lua` (around lines 299–336)

- [ ] **Step 1: Insert `tooltips` group and bump `debug` order**

In `UI/Options.lua`, find the `window` group's closing brace (around line 329) and insert the new `tooltips` group between `window` and `debug`. Also change `debug`'s `order` from `10` to `11`.

Insert between `window = { ... }` and `debug = { ... }`:

```lua
            tooltips = {
                type  = "group",
                name  = L["Tooltips"],
                order = 10,
                args  = {
                    enhance = toggle(L["Enhance Questie/Blizzard tooltips"],
                        L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."],
                        { "tooltips", "enhance" }, 1),
                    replaceBlizzard = toggle(L["Replace Blizzard quest tooltips"],
                        L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."],
                        { "tooltips", "replaceBlizzard" }, 2),
                    replaceQuestie  = {
                        type     = "toggle",
                        name     = L["Replace Questie quest tooltips"],
                        desc     = L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."],
                        order    = 3,
                        disabled = function() return QuestieLoader == nil end,
                        get      = function(info) return db.tooltips.replaceQuestie end,
                        set      = function(info, v)
                            db.tooltips.replaceQuestie = v
                        end,
                    },
                },
            },
```

Change `debug = { order = 10` to `debug = { order = 11`.

- [ ] **Step 2: Verify in-game**

Open `/sq config`. A "Tooltips" tab should appear with three toggles:
- "Enhance Questie/Blizzard tooltips" — ON by default
- "Replace Blizzard quest tooltips" — OFF by default
- "Replace Questie quest tooltips" — OFF by default; greyed out when Questie is not installed

- [ ] **Step 3: Run unit tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both pass.

- [ ] **Step 4: Commit**

```bash
git add UI/Options.lua
git commit -m "feat: add Tooltips config group to /sq config with Enhance and Replace options"
```

---

### Task 5: Extract `renderPartyProgress` helper; implement `BuildTooltip`

**Files:**
- Modify: `UI/Tooltips.lua:1-197` (full rewrite of Tooltips.lua with new helpers)

This task replaces the entire content of `UI/Tooltips.lua`. Read the current file first, then write the new version.

The new file adds:
1. `renderPartyProgress(tooltip, questID)` — extracted from `addGroupProgressToTooltip`, returns `true` if any lines were added
2. `addGroupProgressToTooltip(tooltip, questID)` — now delegates to `renderPartyProgress`, calls `Show()` if data present
3. `buildStatusLine(questID, questInfo, AQL)` — returns `text, r, g, b` or `nil`
4. `buildLevelLine(questInfo)` — returns level · zone · type string or `nil`
5. `SocialQuestTooltips:BuildTooltip(tooltip, questID)` — full tooltip renderer

- [ ] **Step 1: Write the new `UI/Tooltips.lua`**

```lua
-- UI/Tooltips.lua
-- Quest tooltip enhancement. Two modes:
--   Enhance: appends party progress section to Questie's or WoW's existing tooltip.
--   Replace: renders SocialQuest's own full tooltip instead (configurable per link type).
-- SAFETY: all augmentation is wrapped in pcall so SQ errors never corrupt the
-- base WoW or Questie tooltip.

SocialQuestTooltips = {}

local L      = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

-- ---------------------------------------------------------------------------
-- resolveQuestData (unchanged)
-- ---------------------------------------------------------------------------

-- Returns qdata for the given questID from entry, or nil.
-- On Retail and MoP, falls back to a title-based scan to handle aliased quest IDs.
local function resolveQuestData(entry, questID, questTitle)
    if not entry or not entry.quests then return nil end
    if entry.quests[questID] then return entry.quests[questID] end
    if (SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP) and questTitle then
        for _, qdata in pairs(entry.quests) do
            if qdata and qdata.title == questTitle then return qdata end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- renderPartyProgress — shared helper used by both augment and replace paths
-- ---------------------------------------------------------------------------

-- Adds "Party progress:" lines to tooltip for all group members who have the quest.
-- Includes the blank separator line before the header.
-- Returns true if any party data was added, false otherwise.
-- Does NOT call tooltip:Show().
local function renderPartyProgress(tooltip, questID)
    -- Party-only gate: never augment in raid or BG.
    local inRaid  = SQWowAPI.IsInRaid()
    local inBG    = SQWowAPI.PARTY_CATEGORY_INSTANCE
                 and SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)
    local inParty = SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)
    if not inParty or inRaid or inBG then return false end

    local AQL = SocialQuest.AQL
    if not AQL then return false end

    local questTitle = AQL:GetQuestTitle(questID)
    local localObjs  = AQL:GetQuestObjectives(questID) or {}

    local localName, localRealm = SQWowAPI.UnitFullName("player")
    local localKey = (localName and localRealm)
                  and (localName .. "-" .. localRealm)
                  or  localName

    local hasAnyGroupData = false

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if localKey and playerName == localKey then
            -- Skip local player — their progress is shown by Questie / native tooltip.
        else
            local qdata = resolveQuestData(entry, questID, questTitle)
            if qdata then
                if not hasAnyGroupData then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(L["Party progress"] .. ":")
                    hasAnyGroupData = true
                end

                local line
                if not entry.hasSocialQuest then
                    line = " - " .. playerName .. ": " .. L["(shared, no data)"]
                elseif qdata.isComplete then
                    line = " - " .. playerName .. ": "
                           .. "|cFF40C040" .. L["Complete"] .. "|r"
                else
                    local parts = {}
                    for i, obj in ipairs(qdata.objectives or {}) do
                        local nf       = obj.numFulfilled or 0
                        local nr       = obj.numRequired  or 1
                        local localObj = localObjs[i]
                        local text     = localObj and localObj.text
                        local desc
                        if text then
                            desc = text:match("^(.-)%s*:%s*%d+/%d+%s*$")
                                or text:match("^%d+/%d+%s+(.+)$")
                        end
                        if desc and desc ~= "" then
                            table.insert(parts, desc .. ": " .. nf .. "/" .. nr)
                        else
                            table.insert(parts, nf .. "/" .. nr)
                        end
                    end
                    local status = #parts > 0
                        and table.concat(parts, "; ")
                        or  L["In Progress"]
                    line = " - " .. playerName .. ": " .. status
                end

                tooltip:AddLine(line, 1, 1, 1)
            end
        end
    end

    return hasAnyGroupData
end

-- ---------------------------------------------------------------------------
-- addGroupProgressToTooltip — augment path (called when Replace is OFF)
-- ---------------------------------------------------------------------------

local function addGroupProgressToTooltip(tooltip, questID)
    local ok, err = pcall(function()
        local hasData = renderPartyProgress(tooltip, questID)
        if hasData then tooltip:Show() end
    end)
    if not ok then
        SocialQuest:Debug("Banner", "Tooltip augment error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- BuildTooltip helpers
-- ---------------------------------------------------------------------------

-- Determines the status line for the tooltip. Returns text, r, g, b or nil.
-- Checks: active quest → completed quest → heuristic eligibility.
local function buildStatusLine(questID, questInfo, AQL)
    local title = questInfo.title

    -- On this quest? (exact match or alias title scan)
    if AQL:GetQuest(questID) then
        return L["You are on this quest"], 0.25, 1, 0.25
    end
    if title then
        for _, q in pairs(AQL:GetAllQuests()) do
            if q.title == title then
                return L["You are on this quest"], 0.25, 1, 0.25
            end
        end
    end

    -- Already completed? (exact match or title scan of history)
    if AQL:HasCompletedQuest(questID) then
        return L["You have completed this quest"], 0.25, 1, 0.25
    end
    if title then
        for cqID in pairs(AQL:GetCompletedQuests()) do
            local cqTitle = AQL:GetQuestTitle(cqID)
            if cqTitle == title then
                return L["You have completed this quest"], 0.25, 1, 0.25
            end
        end
    end

    -- Heuristic eligibility: only when a provider has requirements data.
    local reqs = AQL:GetQuestRequirements(questID)
    if not reqs then
        -- NullProvider or quest completely unknown — show nothing.
        return nil
    end

    -- Check level, race, class.
    local playerLevel = AQL:GetPlayerLevel()
    if reqs.requiredLevel and playerLevel < reqs.requiredLevel then
        return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
    end
    if reqs.requiredMaxLevel and reqs.requiredMaxLevel > 0
       and playerLevel > reqs.requiredMaxLevel then
        return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
    end
    if reqs.requiredRaces and reqs.requiredRaces ~= 0 then
        local _, _, raceID = SQWowAPI.UnitRace("player")
        if raceID and bit.band(reqs.requiredRaces, bit.lshift(1, raceID - 1)) == 0 then
            return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
        end
    end
    if reqs.requiredClasses and reqs.requiredClasses ~= 0 then
        local _, _, classID = SQWowAPI.UnitClass("player")
        if classID and bit.band(reqs.requiredClasses, bit.lshift(1, classID - 1)) == 0 then
            return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
        end
    end

    return L["You are eligible for this quest"], 1, 1, 1
end

-- Builds the "Level N · Zone · [Dungeon] [Raid] [Group]" line.
-- Returns the string or nil when no level is available.
local function buildLevelLine(questInfo)
    local parts = {}
    if questInfo.level then
        table.insert(parts, string.format(L["Level %d"], questInfo.level))
    end
    if questInfo.zone then
        table.insert(parts, questInfo.zone)
    end
    if questInfo.isDungeon then
        table.insert(parts, L["[Dungeon]"])
    end
    if questInfo.isRaid then
        table.insert(parts, L["[Raid]"])
    end
    -- [Group] only when not already labelled as dungeon or raid.
    if questInfo.isGroup and not questInfo.isDungeon and not questInfo.isRaid then
        table.insert(parts, L["[Group]"])
    end
    if #parts == 0 then return nil end
    -- Middle dot separator (U+00B7, UTF-8 bytes 0xC2 0xB7).
    return table.concat(parts, " \195\183 ")
end

-- ---------------------------------------------------------------------------
-- BuildTooltip — full SQ tooltip renderer
-- ---------------------------------------------------------------------------

-- Renders a complete quest tooltip on `tooltip` for the given questID.
-- Uses AQL:GetQuestInfo for all fields, including Details capability fields
-- (description, starterNPC, starterZone, finisherNPC, finisherZone, isDungeon, isRaid, isGroup).
-- Sets tooltip._sqTooltipBuilt = true and calls tooltip:Show().
-- tooltip._sqTooltipBuilt is cleared by an OnHide hook registered in Initialize().
function SocialQuestTooltips:BuildTooltip(tooltip, questID)
    local ok, err = pcall(function()
        local AQL = SocialQuest.AQL
        if not AQL then return end

        local questInfo = AQL:GetQuestInfo(questID)
        if not questInfo then return end

        tooltip:ClearLines()

        -- 1. Title line — yellow, same as WoW quest link color.
        local title = questInfo.title or ("Quest " .. questID)
        tooltip:AddLine(title, 1, 0.82, 0)

        -- 2. Status line (alias-aware).
        local statusText, sR, sG, sB = buildStatusLine(questID, questInfo, AQL)
        if statusText then
            tooltip:AddLine(statusText, sR, sG, sB)
        end

        -- 3. Level · Zone · type badges line.
        local levelLine = buildLevelLine(questInfo)
        if levelLine then
            tooltip:AddLine(levelLine, 1, 1, 1)
        end

        -- 4. Description (Questie only; nil when not available).
        if questInfo.description then
            tooltip:AddLine(" ")
            tooltip:AddLine(questInfo.description, 1, 1, 1, true)  -- true = wrap
        end

        -- 5. NPC lines (Questie + Grail).
        local hasNPC = questInfo.starterNPC or questInfo.finisherNPC
        if hasNPC then
            tooltip:AddLine(" ")
            if questInfo.starterNPC then
                local giverLine = L["Quest Giver:"] .. " " .. questInfo.starterNPC
                if questInfo.starterZone then
                    giverLine = giverLine .. ", " .. questInfo.starterZone
                end
                tooltip:AddLine(giverLine, 1, 1, 1)
            end
            if questInfo.finisherNPC then
                local turnInLine = L["Turn In:"] .. " " .. questInfo.finisherNPC
                if questInfo.finisherZone then
                    turnInLine = turnInLine .. ", " .. questInfo.finisherZone
                end
                tooltip:AddLine(turnInLine, 1, 1, 1)
            end
        end

        -- 6. Party progress section (adds its own blank separator when data present).
        renderPartyProgress(tooltip, questID)

        -- 7. Mark built and show.
        tooltip._sqTooltipBuilt = true
        tooltip:Show()
    end)
    if not ok then
        SocialQuest:Debug("Banner", "BuildTooltip error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Initialize — register all hooks
-- ---------------------------------------------------------------------------

function SocialQuestTooltips:Initialize()
    -- New wire format: [[level] Quest Name {questID}] — curly braces avoid Questie collision.
    local SQ_LINK_PATTERN = "%[%[(%d+)%]%s(.-)%s*{(%d+)}%]"
    -- Legacy wire format: [[level] Quest Name (questID)] — for backward compat with old SQ clients.
    -- Only applied when Questie is not installed.
    local SQ_LINK_PATTERN_LEGACY = "%[%[(%d+)%]%s(.-)%s*%((%d+)%)%]"
    local function sqChatFilter(_, _, msg, ...)
        if not msg then return end
        local function convert(levelStr, name, questIDStr)
            local level   = tonumber(levelStr) or 0
            local questID = tonumber(questIDStr)
            if not questID then return end
            return "|cffffff00|Hsocialquest:" .. questID .. ":" .. level
                   .. "|h[" .. level .. "] " .. name .. "|h|r"
        end
        local newMsg = msg:gsub(SQ_LINK_PATTERN, convert)
        if newMsg == msg and not QuestieLoader then
            newMsg = msg:gsub(SQ_LINK_PATTERN_LEGACY, convert)
        end
        if newMsg ~= msg then
            return false, newMsg, ...
        end
    end
    local SQ_FILTER_EVENTS = {
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    }
    for _, event in ipairs(SQ_FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, sqChatFilter)
    end

    -- SetItemRef hook: fires when the player clicks a |Hsocialquest:| link.
    -- Calls BuildTooltip directly — no routing through questie:/quest: links.
    hooksecurefunc("SetItemRef", function(link, text, button)
        local ok, err = pcall(function()
            if not link then return end
            local linkType, qidStr = strsplit(":", link)
            if linkType ~= "socialquest" then return end
            local questID = tonumber(qidStr)
            if not questID then return end
            ShowUIPanel(ItemRefTooltip)
            ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
            SocialQuestTooltips:BuildTooltip(ItemRefTooltip, questID)
        end)
        if not ok then
            SocialQuest:Debug("Banner", "SetItemRef hook error: " .. tostring(err))
        end
    end)

    -- SetHyperlink hook: handles quest: and questie: links.
    -- Replace mode: ClearLines() + BuildTooltip (all versions).
    -- Enhance mode on non-Retail: addGroupProgressToTooltip.
    -- Enhance mode on Retail: handled by TooltipDataProcessor below.
    if ItemRefTooltip then
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local db = SocialQuest.db and SocialQuest.db.profile
            if not db then return end

            local questID = tonumber(link:match("^quest:(%d+)"))
            if questID then
                if db.tooltips.replaceBlizzard then
                    self:ClearLines()
                    SocialQuestTooltips:BuildTooltip(self, questID)
                elseif db.tooltips.enhance and not SQWowAPI.IS_RETAIL then
                    addGroupProgressToTooltip(self, questID)
                end
                return
            end

            questID = tonumber(link:match("^questie:(%d+)"))
            if questID then
                if db.tooltips.replaceQuestie then
                    self:ClearLines()
                    SocialQuestTooltips:BuildTooltip(self, questID)
                elseif db.tooltips.enhance and not SQWowAPI.IS_RETAIL then
                    addGroupProgressToTooltip(self, questID)
                end
                return
            end
        end)

        -- Clear _sqTooltipBuilt when the tooltip hides so future tooltip calls are not blocked.
        ItemRefTooltip:HookScript("OnHide", function(self)
            self._sqTooltipBuilt = nil
        end)
    end

    if SQWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        -- Retail: native tooltip data processor fires after WoW populates quest tooltips.
        -- Skipped when BuildTooltip already ran via the SetHyperlink hook (Replace mode).
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if tooltip._sqTooltipBuilt then return end
                local db = SocialQuest.db and SocialQuest.db.profile
                if not db or not db.tooltips.enhance then return end
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )
    end
end
```

- [ ] **Step 2: Run unit tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both pass.

- [ ] **Step 3: Verify Enhance mode in-game**

With "Replace" options OFF (defaults), hover over a `quest:` or `questie:` link. The native tooltip should appear with party progress appended at the bottom (same behavior as before).

- [ ] **Step 4: Verify BuildTooltip with socialquest: links**

Click a `socialquest:` link from a party chat announcement. The tooltip should show:
- Quest title (yellow)
- Status line (green if on quest)
- Level · Zone line
- Description (if Questie installed and data available)
- Quest Giver / Turn In lines (if provider installed and data available)
- Party progress section (if in party with group members on same quest)

- [ ] **Step 5: Verify Replace modes**

Enable "Replace Blizzard quest tooltips" in `/sq config` → Tooltips. Click a `quest:` link. The SQ full tooltip should appear instead of WoW's basic tooltip.

Enable "Replace Questie quest tooltips". Click a `questie:` link. The SQ full tooltip should appear instead of Questie's tooltip.

- [ ] **Step 6: Commit**

```bash
git add UI/Tooltips.lua
git commit -m "feat: add BuildTooltip renderer and refactor party progress into renderPartyProgress helper"
```

---

### Task 6: Update `CLAUDE.md` and bump version

**Files:**
- Modify: `CLAUDE.md`
- Modify: `SocialQuest.toc`
- Modify: `SocialQuest_TBC.toc` (if present)
- Modify: `SocialQuest_Mists.toc` (if present)
- Modify: `SocialQuest_Mainline.toc` (if present)
- Modify: `SocialQuest_Classic.toc` (if present)

- [ ] **Step 1: Update `CLAUDE.md` — wire format section**

In `CLAUDE.md`, find the `Core/Communications.lua` module description (or the Communication Protocol section) and update the `BuildQuestLink` documentation:

Add or update the wire format note in the Communication Protocol section:

```
**Quest Link Wire Format:** Plain-text `[[level] Quest Name {questID}]` (curly braces around questID).
Uses `{` / `}` rather than `(` / `)` to avoid collision with Questie's `ChatFilter.lua`, which
explicitly matches the parenthesis format and replaces it with `|Hquestie:|` links. SQ's
`ChatFrame_AddMessageEventFilter` in `UI/Tooltips.lua` converts `{questID}` format to
`|Hsocialquest:|` links locally on each receiving client.
Old-format `(questID)` messages from pre-2.20.0 SQ clients are still handled when
Questie is not installed (backward compat fallback in `SQ_LINK_PATTERN_LEGACY`).
```

- [ ] **Step 2: Update `CLAUDE.md` — Tooltips config section**

Add a new entry to the Configuration section:

```
**Tooltips config (db.profile.tooltips):**
- `enhance` (bool, default true) — append party progress to Questie/Blizzard tooltips
- `replaceBlizzard` (bool, default false) — replace WoW's basic `quest:` link tooltip with SQ full tooltip
- `replaceQuestie` (bool, default false) — replace Questie's `questie:` link tooltip with SQ full tooltip;
  greyed out in config UI when `QuestieLoader` is nil
```

- [ ] **Step 3: Update `CLAUDE.md` — UI/Tooltips.lua architecture**

In the UI Modules table, update the `UI/Tooltips.lua` row:

```
| `UI\Tooltips.lua` | `SocialQuestTooltips` | Quest tooltip enhancement. `Initialize()` registers the chat filter, `SetItemRef` hook (calls `BuildTooltip` for `socialquest:` links), `SetHyperlink` hook (Replace or Enhance logic for `quest:`/`questie:` links), and Retail `TooltipDataProcessor` handler. `BuildTooltip(tooltip, questID)` renders a full alias-aware tooltip using `AQL:GetQuestInfo` fields. |
```

- [ ] **Step 4: Bump version**

This is the first modification today (2026-04-06) for SQ, so increment minor version and reset revision. Current version: 2.19.2. New version: **2.20.0**.

Update `## Version:` in all `.toc` files:
- `SocialQuest.toc`: `## Version: 2.20.0`
- `SocialQuest_TBC.toc` (if present): same
- `SocialQuest_Mists.toc` (if present): same
- `SocialQuest_Mainline.toc` (if present): same
- `SocialQuest_Classic.toc` (if present): same

Add a version history entry to `CLAUDE.md`:

```markdown
### Version 2.20.0 (April 2026)
- Feature: custom quest tooltip. `SocialQuestTooltips:BuildTooltip(tooltip, questID)` renders
  a full alias-aware tooltip using `AQL:GetQuestInfo` — title (yellow), status line (on quest /
  completed / eligible / ineligible), level · zone · type badges, quest description (Questie only),
  Quest Giver and Turn In NPC lines (Questie + Grail), and party progress. The `socialquest:`
  link `SetItemRef` hook now calls `BuildTooltip` directly instead of routing through
  `questie:`/`quest:` links.
- Feature: Tooltips config group in `/sq config`. Three options: "Enhance Questie/Blizzard
  tooltips" (default ON, appends party progress to existing tooltips), "Replace Blizzard quest
  tooltips" (default OFF), "Replace Questie quest tooltips" (default OFF; greyed out when
  Questie not installed).
- Wire format change: `BuildQuestLink` now emits `[[level] Name {questID}]` (curly braces)
  instead of `[[level] Name (questID)]` (parentheses). This prevents collision with Questie's
  `ChatFilter.lua`, which explicitly matches and converts the parenthesis format. Old-format
  messages from pre-2.20.0 clients are still handled when Questie is absent (backward compat).
- Retail `TooltipDataProcessor` handler now guarded by `_sqTooltipBuilt` flag: skips Enhance
  augmentation when `BuildTooltip` already ran via the `SetHyperlink` hook (Replace mode).
- Locale: new keys for Tooltips config group, status lines, NPC labels, and type badges
  across all 12 locales.
```

- [ ] **Step 5: Run unit tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md SocialQuest.toc
git commit -m "docs: update CLAUDE.md with wire format, Tooltips config, BuildTooltip; bump version to 2.20.0"
```

(Add `SocialQuest_TBC.toc`, `SocialQuest_Mists.toc`, `SocialQuest_Mainline.toc`, `SocialQuest_Classic.toc` to the `git add` command if those files exist.)

---

## Spec Coverage Self-Review

| Spec Requirement | Covered By |
|---|---|
| Wire format `{questID}` to prevent Questie collision | Task 1 |
| Old `(questID)` format backward compat | Task 1 |
| Wire protocol version bump mentioned in CLAUDE.md | Task 6 |
| AceDB defaults for tooltips config | Task 2 |
| "Enhance" ON by default, "Replace" OFF by default | Task 2 |
| Tooltips group in `/sq config` with 3 options | Task 4 |
| Replace Questie greyed out when QuestieLoader nil | Task 4 |
| Locale keys all 12 locales | Task 3 |
| `BuildTooltip(tooltip, questID)` renderer | Task 5 |
| Title line yellow | Task 5 |
| Status line: on quest / completed / eligible / ineligible | Task 5 |
| Status line alias-aware (title scan) | Task 5 |
| Level · Zone · type line | Task 5 |
| Description (optional, Questie only) | Task 5 |
| Quest Giver / Turn In NPC lines (optional) | Task 5 |
| Party progress section | Task 5 |
| `socialquest:` links call BuildTooltip directly | Task 5 |
| `quest:` links: Replace or Enhance based on config | Task 5 |
| `questie:` links: Replace or Enhance based on config | Task 5 |
| Retail `_sqTooltipBuilt` guard on TooltipDataProcessor | Task 5 |
| `tooltip:OnHide` clears `_sqTooltipBuilt` | Task 5 |
| CLAUDE.md documentation | Task 6 |
