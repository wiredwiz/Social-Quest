# Quest Chat Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SocialQuest's broken/plain `[Quest Title]` chat links with clickable Questie-format links on non-Retail and a custom `socialquest` link type on Retail, plus augment any quest link tooltip with party member progress in a style that blends seamlessly with Questie's existing tooltip.

**Architecture:** `BuildQuestLink()` in `Core/Announcements.lua` constructs the version-appropriate hyperlink string for `SendChatMessage`; `UI/Tooltips.lua` is extended to handle the new link types, add a party-only gate, skip the local player (already shown by Questie/WoW), resolve aliased quest IDs on Retail, and append party progress in Questie's visual style.

**Tech Stack:** Lua 5.1, WoW TBC/Retail addon API, AceLocale-3.0, Questie (non-Retail), AQL (`SocialQuest.AQL`).

---

## File Structure

| File | Change |
|---|---|
| `Core/Announcements.lua` | Add `BuildQuestLink` local function + test export; update `OnQuestEvent`; update `OnObjectiveEvent` |
| `UI/Tooltips.lua` | Add `local SQWowAPI` alias; add `resolveQuestData` helper; rewrite `addGroupProgressToTooltip`; update `Initialize` |
| `Locales/enUS.lua` … `Locales/zhTW.lua` (12 files) | Add `L["Party progress"]` key |
| `tests/Announcements_test.lua` | New test file for `BuildQuestLink` |

---

## Task 1: `BuildQuestLink` function + unit tests

**Files:**
- Modify: `Core/Announcements.lua` (after line 110, inside "Pure message formatters" section)
- Create: `tests/Announcements_test.lua`

- [ ] **Step 1: Create the test file**

Create `tests/Announcements_test.lua`:

```lua
-- tests/Announcements_test.lua
-- Unit tests for SocialQuestAnnounce._BuildQuestLink

local failures = 0
local function assert_eq(label, got, expected)
    if got ~= expected then
        failures = failures + 1
        print("FAIL [" .. label .. "]")
        print("  expected: " .. tostring(expected))
        print("  got:      " .. tostring(got))
    end
end

-- ── Stubs ────────────────────────────────────────────────────────────────────
SocialQuestWowAPI = {
    IS_RETAIL = false, IS_TBC = true, IS_MOP = false, IS_CLASSIC_ERA = false,
    GetTime = function() return 0 end,
    SendChatMessage = function() end,
    IsInGroup = function() return false end,
    IsInRaid  = function() return false end,
    IsInGuild = function() return false end,
    IsInGroup = function() return false end,
    TimerAfter = function() end,
    GetNumFriends = function() return 0 end,
    PARTY_CATEGORY_HOME = 0,
    PARTY_CATEGORY_INSTANCE = 2,
}
SocialQuestWowUI  = { AddRaidNotice = function() end, AddChatMessage = function() end }
SocialQuestColors = { GetEventColor = function() return nil end }
SocialQuestTabUtils = {
    BuildEngagedSet = function() return {} end,
    SelectChain     = function() return nil end,
}
SocialQuestGroupData = { PlayerQuests = {} }
UnitGUID = function(unit) return "Player-1234-ABCDEF12" end
LibStub = function(name)
    if name == "AceLocale-3.0" then
        return {
            GetLocale = function()
                return setmetatable({}, { __index = function(t, k) return k end })
            end,
        }
    end
    return {}
end
SocialQuest = {
    EventTypes = {
        Accepted = "accepted", Completed = "completed", Abandoned = "abandoned",
        Failed = "failed", Finished = "finished", Tracked = "tracked",
        Untracked = "untracked",
        ObjectiveComplete = "objective_complete",
        ObjectiveProgress = "objective_progress",
    },
    AQL = { ChainStatus = { Known = "known" } },
    db  = { profile = { enabled = false } },
}
function SocialQuest:Debug() end
function SocialQuest:ScheduleRepeatingTimer(fn, delay) return {} end
function SocialQuest:Print() end

-- ── TBC tests (IS_RETAIL = false) ────────────────────────────────────────────
dofile("Core/Announcements.lua")
local B = SocialQuestAnnounce._BuildQuestLink

assert_eq("tbc_basic",
    B(337, "Wanted: Hogger", 10),
    "|Hquestie:337:Player-1234-ABCDEF12|h[10] Wanted: Hogger|h|r")

assert_eq("tbc_nil_level",
    B(100, "A Quest", nil),
    "|Hquestie:100:Player-1234-ABCDEF12|h[0] A Quest|h|r")

assert_eq("tbc_nil_questID",  B(nil, "A Quest", 5), nil)
assert_eq("tbc_nil_name",     B(337, nil,       5), nil)

-- ── Retail tests (IS_RETAIL = true) ──────────────────────────────────────────
SocialQuestWowAPI.IS_RETAIL = true
SocialQuestWowAPI.IS_TBC    = false
dofile("Core/Announcements.lua")   -- re-load so SQWowAPI local captures IS_RETAIL=true
B = SocialQuestAnnounce._BuildQuestLink

assert_eq("retail_basic",
    B(337, "Wanted: Hogger", 40),
    "|Hsocialquest:337:40|h[40] Wanted: Hogger|h|r")

assert_eq("retail_nil_level",
    B(337, "Wanted: Hogger", nil),
    "|Hsocialquest:337:0|h[0] Wanted: Hogger|h|r")

assert_eq("retail_nil_questID", B(nil, "Name", 5), nil)
assert_eq("retail_nil_name",    B(1,   nil,    5), nil)

-- ── Result ────────────────────────────────────────────────────────────────────
if failures == 0 then
    print("Announcements_test: all tests passed")
else
    print("Announcements_test: " .. failures .. " failure(s)")
    os.exit(1)
end
```

- [ ] **Step 2: Run the test to verify it fails**

```
lua tests/Announcements_test.lua
```

Expected: error loading `Core/Announcements.lua` or `FAIL` lines (function not yet defined).

- [ ] **Step 3: Add `BuildQuestLink` to `Core/Announcements.lua`**

Insert the following block **after line 110** (after `formatOutboundObjectiveMsg`, still inside the "Pure message formatters" section). Add before `local BANNER_QUEST_TEMPLATES`:

```lua
-- Builds the clickable hyperlink string for SendChatMessage.
-- Non-Retail: Questie-compatible |Hquestie:| format. Questie users get a clickable
--   tooltip; others see "[level] Name" as plain readable text.
-- Retail: SQ's own |Hsocialquest:| format. Tooltips.lua registers a SetItemRef hook
--   that forwards it to the native quest tooltip display.
-- Returns nil when questID or questName is nil (safe: callers fall back to plain title).
local function BuildQuestLink(questID, questName, questLevel)
    if not questID or not questName then return nil end
    local level = questLevel or 0
    if SQWowAPI.IS_RETAIL then
        return "|Hsocialquest:" .. questID .. ":" .. level
               .. "|h[" .. level .. "] " .. questName .. "|h|r"
    else
        local senderGUID = UnitGUID("player") or ""
        return "|Hquestie:" .. questID .. ":" .. senderGUID
               .. "|h[" .. level .. "] " .. questName .. "|h|r"
    end
end
-- Exposed for unit tests. Not part of the public API.
SocialQuestAnnounce._BuildQuestLink = BuildQuestLink
```

- [ ] **Step 4: Run the test to verify it passes**

```
lua tests/Announcements_test.lua
```

Expected: `Announcements_test: all tests passed`

- [ ] **Step 5: Run the full test suite**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua && lua tests/Announcements_test.lua
```

Expected: all four print `… all tests passed`, no failures.

- [ ] **Step 6: Commit**

```bash
git add Core/Announcements.lua tests/Announcements_test.lua
git commit -m "feat: add BuildQuestLink for version-aware clickable quest links"
```

---

## Task 2: Update `OnQuestEvent` to use `BuildQuestLink`

**Files:**
- Modify: `Core/Announcements.lua` (around line 215)

Context: `OnQuestEvent` currently builds the display string as `"[" .. title .. "]"`. Replace it with `BuildQuestLink`.

- [ ] **Step 1: Locate and replace the display line in `OnQuestEvent`**

Find this block (around lines 208–216):

```lua
    local title = (info and info.title)
               or (questInfo and questInfo.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)
    -- WoW TBC does not render |H...|h hyperlinks in addon-sent party chat messages;
    -- use [Title] bracket format instead. Banners also use plain title.
    local msg   = formatOutboundQuestMsg(eventType, "[" .. title .. "]")
```

Replace with:

```lua
    local title = (info and info.title)
               or (questInfo and questInfo.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)
    local level   = (questInfo and questInfo.level) or (info and info.level)
    local display = BuildQuestLink(questID, title, level) or ("[" .. title .. "]")
    local msg     = formatOutboundQuestMsg(eventType, display)
```

The `title` variable is intentionally kept because `OnOwnQuestEvent` (called later at line 262) requires plain text for `RaidNotice_AddMessage`, which cannot render hyperlinks.

- [ ] **Step 2: Run the full test suite**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua && lua tests/Announcements_test.lua
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: use BuildQuestLink in OnQuestEvent for clickable chat links"
```

---

## Task 3: Update `OnObjectiveEvent` to use `BuildQuestLink`

**Files:**
- Modify: `Core/Announcements.lua` (around lines 288–293)

Context: `OnObjectiveEvent` currently passes `"[" .. questInfo.title .. "]"` to `formatOutboundObjectiveMsg`. Replace with `BuildQuestLink`.

- [ ] **Step 1: Locate and replace the display line in `OnObjectiveEvent`**

Find this block (around lines 288–293):

```lua
        local msg = formatOutboundObjectiveMsg(
            "[" .. (questInfo.title or ("Quest " .. questInfo.questID)) .. "]",
            objective.name or "",
            objective.numFulfilled,
            objective.numRequired,
            isRegression)
```

Replace with:

```lua
        local questName  = questInfo.title or ("Quest " .. questInfo.questID)
        local questLevel = questInfo.level
        local display    = BuildQuestLink(questInfo.questID, questName, questLevel)
                        or ("[" .. questName .. "]")
        local msg = formatOutboundObjectiveMsg(
            display,
            objective.name or "",
            objective.numFulfilled,
            objective.numRequired,
            isRegression)
```

- [ ] **Step 2: Run the full test suite**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua && lua tests/Announcements_test.lua
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: use BuildQuestLink in OnObjectiveEvent for clickable chat links"
```

---

## Task 4: Rewrite `addGroupProgressToTooltip` in `Tooltips.lua`

**Files:**
- Modify: `UI/Tooltips.lua` (full file rewrite — replaces lines 1–74)

This task replaces the entire current `Tooltips.lua` content. The existing file is 74 lines; the new version adds `resolveQuestData`, a party gate, local-player skip, alias resolution, pcall safety, and Questie-matched visual formatting. Read the existing file before editing to ensure no extra functions have been added since the last session read.

- [ ] **Step 1: Replace the full content of `UI/Tooltips.lua`**

```lua
-- UI/Tooltips.lua
-- Hooks quest link tooltips to append group party member progress.
-- Matches Questie's visual style: blank separator, plain "Party progress:" header,
-- " - Name: desc: X/Y" objective lines.
-- SAFETY: all augmentation is wrapped in pcall so SQ errors never corrupt the
-- base WoW or Questie tooltip.

SocialQuestTooltips = {}

local L      = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

-- Returns qdata for the given questID from entry, or nil.
-- On Retail, falls back to a title-based scan to handle aliased quest IDs
-- (same logical quest, different numeric IDs per race/class character type).
local function resolveQuestData(entry, questID, questTitle)
    if not entry or not entry.quests then return nil end
    if entry.quests[questID] then return entry.quests[questID] end
    -- Alias fallback: Retail only, requires a resolved title.
    if SQWowAPI.IS_RETAIL and questTitle then
        for _, qdata in pairs(entry.quests) do
            if qdata and qdata.title == questTitle then return qdata end
        end
    end
    return nil
end

local function addGroupProgressToTooltip(tooltip, questID)
    local ok, err = pcall(function()
        -- Party-only gate: never augment in raid or BG.
        local inRaid = SQWowAPI.IsInRaid()
        local inBG   = SQWowAPI.PARTY_CATEGORY_INSTANCE
                    and SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)
        local inParty = SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)
        if not inParty or inRaid or inBG then return end

        local AQL = SocialQuest.AQL
        if not AQL then return end

        local questTitle = AQL:GetQuestTitle(questID)
        -- Local objective text for description labels (never transmitted over wire).
        local localObjs = AQL:GetQuestObjectives(questID) or {}

        -- Build the local-player key in the same format used by PlayerQuests.
        -- On Retail: "Name-Realm". On TBC: "Name".
        local localName, localRealm = SQWowAPI.UnitFullName("player")
        local localKey = (localName and localRealm)
                      and (localName .. "-" .. localRealm)
                      or  localName

        local hasAnyGroupData = false

        for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
            -- Skip local player — their progress is shown by Questie / native tooltip.
            if localKey and playerName == localKey then
                -- continue
            else
                local qdata = resolveQuestData(entry, questID, questTitle)
                if qdata then
                    if not hasAnyGroupData then
                        -- Blank separator line matches Questie's style before "Your progress:".
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
                            local nf  = obj.numFulfilled or 0
                            local nr  = obj.numRequired  or 1
                            local localObj = localObjs[i]
                            local text = localObj and localObj.text
                            -- Strip embedded count from objective text so we can substitute
                            -- the remote player's values. Two formats exist:
                            --   count-last:  "Description: X/Y"
                            --   count-first: "X/Y Description"
                            local desc
                            if text then
                                desc = text:match("^(.-)%s*:%s*%d+/%d+%s*$")  -- count-last
                                    or text:match("^%d+/%d+%s+(.+)$")         -- count-first
                            end
                            if desc and desc ~= "" then
                                table.insert(parts, desc .. ": " .. nf .. "/" .. nr)
                            else
                                table.insert(parts, nf .. "/" .. nr)
                            end
                        end
                        local status = #parts > 0
                            and table.concat(parts, "; ")
                            or  L["(no data)"]
                        line = " - " .. playerName .. ": " .. status
                    end

                    -- White text (1,1,1), matching Questie's plain objective lines.
                    tooltip:AddLine(line, 1, 1, 1)
                end
            end
        end

        if hasAnyGroupData then tooltip:Show() end
    end)

    if not ok then
        SocialQuest:Debug("Banner", "Tooltip augment error: " .. tostring(err))
    end
end

function SocialQuestTooltips:Initialize()
    local SQWowAPI = SocialQuestWowAPI   -- local alias for closures below
    if SQWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        -- Retail: native tooltip data processor — fires after WoW populates quest tooltips.
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )

        -- Retail: forward our custom |Hsocialquest:questID:level| links to the native
        -- quest tooltip display. TooltipDataProcessor then fires and appends party progress.
        hooksecurefunc("SetItemRef", function(link, text, button)
            local ok, err = pcall(function()
                if not link then return end
                local linkType, qidStr, levelStr = strsplit(":", link)
                if linkType ~= "socialquest" then return end
                local questID = tonumber(qidStr)
                local level   = tonumber(levelStr) or 0
                if not questID then return end
                ShowUIPanel(ItemRefTooltip)
                ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
                ItemRefTooltip:SetHyperlink("quest:" .. questID .. ":" .. level)
                ItemRefTooltip:Show()
            end)
            if not ok then
                SocialQuest:Debug("Banner", "SetItemRef hook error: " .. tostring(err))
            end
        end)

    elseif ItemRefTooltip then
        -- TBC / Classic / Mists: hook SetHyperlink on ItemRefTooltip.
        -- Matches quest: (native links), questie: (Questie links), and
        -- socialquest: (should not appear on non-Retail, but guard anyway).
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local questID = tonumber(link:match("^quest:(%d+)"))
                         or tonumber(link:match("^questie:(%d+)"))
            if questID then
                addGroupProgressToTooltip(self, questID)
            end
        end)
    end
end
```

- [ ] **Step 2: Run the full test suite**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua && lua tests/Announcements_test.lua
```

Expected: all pass. (Tooltips.lua has no Lua unit tests — coverage is via in-game verification.)

- [ ] **Step 3: Commit**

```bash
git add UI/Tooltips.lua
git commit -m "feat: rewrite tooltip augmentation with party gate, alias resolution, Questie-matched style"
```

---

## Task 5: Add `L["Party progress"]` locale key to all 12 locales

**Files:**
- Modify: `Locales/enUS.lua`, `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`,
  `Locales/esMX.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/koKR.lua`,
  `Locales/ruRU.lua`, `Locales/jaJP.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`

In each file, insert the new key on the line **immediately after** `L["Group Progress"]`.

- [ ] **Step 1: Add to `Locales/enUS.lua`** (after `L["Group Progress"] = true`)

```lua
L["Party progress"]                           = true
```

- [ ] **Step 2: Add to `Locales/deDE.lua`** (after `L["Group Progress"] = "Gruppenfortschritt"`)

```lua
L["Party progress"]                        = "Gruppenfortschritt"
```

- [ ] **Step 3: Add to `Locales/frFR.lua`** (after `L["Group Progress"] = "Progression du groupe"`)

```lua
L["Party progress"]                        = "Progression du groupe"
```

- [ ] **Step 4: Add to `Locales/esES.lua`** (after `L["Group Progress"] = "Progreso del grupo"`)

```lua
L["Party progress"]                        = "Progreso del grupo"
```

- [ ] **Step 5: Add to `Locales/esMX.lua`** (after `L["Group Progress"] = "Progreso del grupo"`)

```lua
L["Party progress"]                        = "Progreso del grupo"
```

- [ ] **Step 6: Add to `Locales/zhCN.lua`** (after `L["Group Progress"] = "团队进度"`)

```lua
L["Party progress"]                        = "团队进度"
```

- [ ] **Step 7: Add to `Locales/zhTW.lua`** (after `L["Group Progress"] = "團隊進度"`)

```lua
L["Party progress"]                        = "團隊進度"
```

- [ ] **Step 8: Add to `Locales/koKR.lua`** (after `L["Group Progress"] = "그룹 진행도"`)

```lua
L["Party progress"]                        = "그룹 진행도"
```

- [ ] **Step 9: Add to `Locales/ruRU.lua`** (after `L["Group Progress"] = "Прогресс группы"`)

```lua
L["Party progress"]                        = "Прогресс группы"
```

- [ ] **Step 10: Add to `Locales/jaJP.lua`** (after `L["Group Progress"] = "グループ進捗"`)

```lua
L["Party progress"]                        = "グループ進捗"
```

- [ ] **Step 11: Add to `Locales/ptBR.lua`** (after `L["Group Progress"] = "Progresso do grupo"`)

```lua
L["Party progress"]                        = "Progresso do grupo"
```

- [ ] **Step 12: Add to `Locales/itIT.lua`** (after `L["Group Progress"] = "Progresso del gruppo"`)

```lua
L["Party progress"]                        = "Progresso del gruppo"
```

- [ ] **Step 13: Run the full test suite**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua && lua tests/Announcements_test.lua
```

Expected: all pass.

- [ ] **Step 14: Commit**

```bash
git add Locales/
git commit -m "i18n: add Party progress locale key to all 12 locales"
```

---

## Task 6: Version bump and CLAUDE.md update

**Files:**
- Modify: `SocialQuest.toc`, `SocialQuest_Mainline.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run the full test suite one final time**

```
lua tests/FilterParser_test.lua && lua tests/TabUtils_test.lua && lua tests/WowUI_test.lua && lua tests/Announcements_test.lua
```

Expected: all pass. Do not bump the version if any test fails.

- [ ] **Step 2: Bump version in all four `.toc` files**

Per the versioning rule: first change today → increment minor, reset revision.
Today is 2026-04-05 and the last version is 2.18.23, so the new version is **2.18.24**.

In each of `SocialQuest.toc`, `SocialQuest_Mainline.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`:

```
## Version: 2.18.24
```

- [ ] **Step 3: Add version entry to `CLAUDE.md`**

Insert the following block **before** the `### Version 2.18.23` entry:

```markdown
### Version 2.18.24 (April 2026)
- Feature: clickable quest links in SQ outbound chat announcements. On non-Retail,
  SQ now sends `|Hquestie:questID:senderGUID|h[level] Quest Name|h|r` format —
  Questie users get a clickable tooltip; others see `[level] Quest Name` as readable
  plain text. On Retail, SQ sends `|Hsocialquest:questID:level|h` with a `SetItemRef`
  hook in `Tooltips.lua` that forwards clicks to the native quest tooltip.
- Feature: quest link tooltip augmentation now works for all quest link types (native
  `|Hquest:|`, Questie `|Hquestie:|`, and SQ's `|Hsocialquest:|`). Party member
  progress is appended below Questie's "Your progress:" section in matching visual
  style — plain "Party progress:" header, `" - Name: desc: X/Y"` objective lines.
  Only fires in a party group (never in raid or BG). Local player is skipped (already
  shown by Questie/WoW). On Retail, alias resolution via title-based scan handles
  variant quest IDs. All tooltip augmentation wrapped in `pcall` to prevent SQ errors
  from corrupting the base WoW or Questie tooltip.
```

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.toc SocialQuest_Mainline.toc SocialQuest_Classic.toc SocialQuest_Mists.toc CLAUDE.md
git commit -m "chore: bump version to 2.18.24, update CLAUDE.md for quest chat links feature"
```

---

## In-Game Verification Checklist

These cannot be unit-tested and must be verified in-game after deploying the addon.

**Link format (non-Retail):**
1. Accept a quest while in a party. Confirm the SQ chat announcement shows `[40] Quest Name` as a clickable link (blue underlined or gold depending on Questie theme) rather than plain `[Quest Name]`.
2. Click a Questie-announced quest link in party chat. Confirm the tooltip appears.
3. Shift-click a quest from your quest log into chat. Click the resulting `|Hquest:|` link. Confirm party progress section appears below "Your progress:".

**Tooltip augmentation:**
4. With a party member on the same quest, click any quest link. Confirm "Party progress:" section appears below "Your progress:" with the member's objective counts.
5. Confirm the local player does NOT appear in "Party progress:".
6. In a raid: click a quest link. Confirm "Party progress:" does NOT appear.
7. With a party member who has `isComplete = true` for the quest: confirm their row shows green "Complete".
8. With a party member whose data source is non-SQ (Questie bridge): confirm their row shows "(shared, no data)".

**Retail (requires Retail character):**
9. Click an `|Hsocialquest:|` link. Confirm the native WoW quest tooltip opens (same as clicking `|Hquest:|`).
10. Confirm `TooltipDataProcessor` path appends party progress on the Retail tooltip.
