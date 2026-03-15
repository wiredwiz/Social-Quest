# Social Quest Localization — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AceLocale-3.0-based localization to Social Quest supporting 11 locales (enUS + 10 machine-translated), replacing all player-facing string literals with `L["..."]` keys.

**Architecture:** Create `Locales/` directory with 11 locale files registered through AceLocale-3.0 (already available via the existing Ace3 dependency). Update the TOC to load locale files before `SocialQuest.lua`. Add `local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")` at file scope in each source file that contains player-facing strings, then replace all eligible string literals with `L["..."]` references. English strings serve as their own keys; non-English locales provide translations for each key.

**Tech Stack:** Lua 5.1, WoW TBC Classic (Interface 20505), AceLocale-3.0 (via LibStub from existing Ace3 embed). No test framework — verification is manual in-game.

**Spec:** `docs/superpowers/specs/2026-03-15-localization-design.md`

---

## Chunk 1: Locale files + TOC

### Task 1: Create Locales/enUS.lua

**Files:**
- Create: `Locales/enUS.lua`

- [ ] **Step 1: Create `Locales/enUS.lua` with the full content below**

```lua
-- Locales/enUS.lua
-- Default locale. Keys are English strings; values are true (AceLocale convention).
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "enUS", true)
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = true
L["Quest abandoned: %s"]                  = true
L["Quest complete (objectives done): %s"] = true
L["Quest turned in: %s"]                  = true
L["Quest failed: %s"]                     = true
-- Defensive fallback in formatOutboundQuestMsg; unreachable in current call graph.
-- Include for safety; non-English locales need not prioritize it.
L["Quest event: %s"]                      = true

-- Core/Announcements.lua — outbound objective chat
-- Leading space is intentional: appended after objective text when concatenated.
L[" (regression)"]                        = true
-- Five positional args: (1) numFulfilled %d, (2) numRequired %d,
-- (3) objective text %s, (4) regression suffix %s (either " (regression)" or ""),
-- (5) quest title %s. All five must be preserved in translations.
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = true

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = true
L["%s abandoned: %s"]                     = true
L["%s finished objectives: %s"]           = true
L["%s completed: %s"]                     = true
L["%s failed: %s"]                        = true
L["%s completed objective: %s (%d/%d)"]   = true
L["%s regressed: %s (%d/%d)"]             = true
L["%s progressed: %s (%d/%d)"]            = true

-- Core/Announcements.lua — chat preview label
-- Trailing space after |r is intentional: separates label from banner text.
-- All translations must preserve the trailing space and the color/reset codes.
L["|cFF00CCFFSocialQuest (preview):|r "]  = true

-- Core/Announcements.lua — all-completed banner
-- %s = quest title
L["Everyone has completed: %s"]           = true

-- Core/Announcements.lua — own-quest banner sender label
-- Used as the sender name in "You accepted: [Quest]" banners. No parentheses.
L["You"]                                  = true

-- Core/Announcements.lua — follow notifications
-- %s = player character name
L["%s started following you."]            = true
L["%s stopped following you."]            = true

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = true
L["Left-click to open group quest frame."]  = true
L["Right-click to open settings."]          = true

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"] = true   -- literal em dash U+2014; \xNN hex escapes are Lua 5.2+
L["Quest URL (Ctrl+C to copy)"]             = true

-- UI/RowFactory.lua
L["expand all"]                             = true
L["collapse all"]                           = true
L["Click here to copy the wowhead quest url"] = true
L["(Complete)"]                             = true
L["(Group)"]                                = true
-- Leading space is intentional: appended directly after quest title.
-- %s args: (1) step number, (2) chain length. Both are already tostring'd before format.
L[" (Step %s of %s)"]                       = true
-- %s = player character name
L["%s FINISHED"]                            = true
L["%s Needs it Shared"]                     = true
L["%s (no data)"]                           = true

-- UI/Tooltips.lua
L["Group Progress"]                         = true
L["(shared, no data)"]                      = true
L["Objectives complete"]                    = true
L["(no data)"]                              = true

-- UI/Tabs/MineTab.lua — tab label
L["Mine"]                                   = true
-- Shared with UI/TabUtils.lua and UI/Tabs/SharedTab.lua (zone fallback)
L["Other Quests"]                           = true

-- UI/Tabs/PartyTab.lua — tab label
L["Party"]                                  = true
-- Local player label in party/shared tab rows. Translate as self-referential placeholder.
L["(You)"]                                  = true

-- UI/Tabs/SharedTab.lua — tab label
L["Shared"]                                 = true

-- UI/Options.lua — toggle names (shared across multiple groups)
L["Accepted"]                               = true
L["Abandoned"]                              = true
L["Finished"]                               = true
L["Completed"]                              = true
L["Failed"]                                 = true
L["Objective Progress"]                     = true
L["Objective Complete"]                     = true

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = true
L["Send a chat message when you abandon a quest."]                       = true
L["Send a chat message when all your quest objectives are complete (before turning in)."] = true
L["Send a chat message when you turn in a quest."]                       = true
L["Send a chat message when a quest fails."]                             = true
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = true
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = true

-- UI/Options.lua — group headers
L["Announce in Chat"]                       = true
L["Own Quest Banners"]                      = true
L["Display Events"]                         = true
L["General"]                                = true
L["Raid"]                                   = true
L["Guild"]                                  = true
L["Battleground"]                           = true
L["Whisper Friends"]                        = true
L["Follow Notifications"]                   = true
L["Debug"]                                  = true

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = true
L["Show a banner when you abandon a quest."]                                           = true
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = true
L["Show a banner when you turn in a quest."]                                           = true
L["Show a banner when a quest fails."]                                                 = true
L["Show a banner when one of your quest objectives progresses or regresses."]          = true
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = true

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = true
L["Show a banner on screen when a group member abandons a quest."]                     = true
L["Show a banner on screen when a group member finishes all objectives on a quest."]   = true
L["Show a banner on screen when a group member turns in a quest."]                     = true
L["Show a banner on screen when a group member fails a quest."]                        = true
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = true
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = true

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                     = true
L["Master on/off switch for all SocialQuest functionality."]             = true
L["Show received events"]                   = true
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = true
L["Colorblind Mode"]                        = true
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = true
L["Show banners for your own quest events"] = true
L["Show a banner on screen for your own quest events."]                  = true

-- UI/Options.lua — party section
L["Enable transmission"]                    = true
L["Broadcast your quest events to party members via addon comm."]        = true
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = true

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = true
L["Allow banner notifications from raid members."]                       = true
L["Only show notifications from friends"]   = true
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = true

-- UI/Options.lua — guild section
L["Enable chat announcements"]              = true
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = true

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = true
L["Allow banner notifications from battleground members."]               = true
L["Only show banner notifications from friends in the battleground."]    = true

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]             = true
L["Send your quest events as whispers to online friends."]               = true
L["Group members only"]                     = true
L["Restrict whispers to friends currently in your group."]               = true

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]            = true
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = true
L["Announce when you follow someone"]       = true
L["Whisper the player you begin following so they know you are following them."] = true
L["Announce when followed"]                 = true
L["Display a local message when someone starts or stops following you."] = true

-- UI/Options.lua — debug section
L["Enable debug mode"]                      = true
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = true

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                  = true
L["Test Accepted"]                          = true
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = true
L["Test Abandoned"]                         = true
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = true
L["Test Finished"]                          = true
L["Display a demo banner and local chat preview for the 'Quest finished objectives' event."] = true
L["Test Completed"]                         = true
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = true
L["Test Failed"]                            = true
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = true
L["Test Obj. Progress"]                     = true
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = true
L["Test Obj. Complete"]                     = true
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = true
L["Test Obj. Regression"]                   = true
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = true
L["Test All Completed"]                     = true
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = true
```

**Notes on special characters:** WoW uses Lua 5.1, which does not support `\xNN` hex escape sequences in string literals. Always use literal UTF-8 characters. The em dash (—, U+2014) must be written as the literal character in source files. When writing locale files, save them as UTF-8 (no BOM).

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Locales/enUS.lua
git commit -m "feat: add Locales/enUS.lua with all localization keys"
```

---

### Task 2: Create non-English locale files

**Files:**
- Create: `Locales/deDE.lua`
- Create: `Locales/frFR.lua`
- Create: `Locales/esES.lua`
- Create: `Locales/esMX.lua`
- Create: `Locales/zhCN.lua`
- Create: `Locales/zhTW.lua`
- Create: `Locales/ptBR.lua`
- Create: `Locales/itIT.lua`
- Create: `Locales/koKR.lua`
- Create: `Locales/ruRU.lua`

**Background:** Each non-English locale file registers with AceLocale using `NewLocale("SocialQuest", "<locale>")` — no `true` third argument. The `if not L then return end` guard means the file does nothing on clients with a different locale. Every key is translated from the enUS.lua list. Untranslated keys fall back to the English string (the key itself).

**Translation rules (MUST be followed for all locales):**
- Format specifiers (`%s`, `%d`, `%d/%d`) must appear in every translation in the same count and order as in the English key.
- The `{rt1}` raid marker in `"{rt1} SocialQuest: %d/%d %s%s for %s!"` must be kept as-is.
- The key `"|cFF00CCFFSocialQuest (preview):|r "` must preserve both the color escape `|cFF00CCFF`, the reset `|r`, and the trailing space after `|r`.
- The key `" (regression)"` must preserve the leading space.
- The key `" (Step %s of %s)"` must preserve the leading space.

**File template** (same structure for all 10 locales — substitute locale code and translations):

```lua
-- Locales/LOCALE.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "LOCALE")
if not L then return end

L["Quest accepted: %s"]                   = "TRANSLATED"
-- ... all keys from enUS.lua translated into the target language
```

- [ ] **Step 1: Generate and write all 10 non-English locale files**

Use the enUS.lua key list from Task 1 as the source. Generate machine translations for each of the 10 locales listed below. The translations must be natural-sounding for in-game UI text.

For the `"|cFF00CCFFSocialQuest (preview):|r "` key: translate only the text between `|cFF00CCFF` and `:|r`, keeping the color code prefix, `:`, `|r` reset, and trailing space intact. Example for deDE: `L["|cFF00CCFFSocialQuest (preview):|r "] = "|cFF00CCFFSocialQuest (Vorschau):|r "`.

For `"You"` (nominative first-person, no parentheses): translate as the natural first-person nominative pronoun in the target language (e.g. "Du" in German, "Vous/Tu" in French, etc.).

For `"(You)"` (with parentheses, self-referential UI label): translate the word inside the parens and keep the parentheses.

For `"Other Quests"` (zone fallback when zone is unknown): translate as a natural UI fallback label.

For `"SocialQuest — Group Quests"` and `"SocialQuest"` proper noun references: keep "SocialQuest" as the proper noun; translate only the surrounding text.

Locales to generate:
- **deDE** — German (Germany)
- **frFR** — French (France)
- **esES** — Spanish (Spain)
- **esMX** — Spanish (Mexico)
- **zhCN** — Simplified Chinese (China Mainland)
- **zhTW** — Traditional Chinese (Taiwan)
- **ptBR** — Portuguese (Brazil)
- **itIT** — Italian (Italy)
- **koKR** — Korean (Korea)
- **ruRU** — Russian (Russia)

- [ ] **Step 2: Commit all non-English locale files**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Locales/deDE.lua Locales/frFR.lua Locales/esES.lua Locales/esMX.lua
git add Locales/zhCN.lua Locales/zhTW.lua Locales/ptBR.lua Locales/itIT.lua
git add Locales/koKR.lua Locales/ruRU.lua
git commit -m "feat: add machine-translated locale files for 10 non-English locales"
```

---

### Task 3: Update SocialQuest.toc

**Files:**
- Modify: `SocialQuest.toc`

**Background:** Locale files must load after `Util\Colors.lua` and before `SocialQuest.lua`. This guarantees that when `SocialQuest.lua` and other source files call `GetLocale("SocialQuest")` at file scope, the locale is already registered.

**Current TOC (relevant excerpt):**
```
Util\Colors.lua
SocialQuest.lua
```

**Target TOC (relevant excerpt):**
```
Util\Colors.lua
Locales\enUS.lua
Locales\deDE.lua
Locales\frFR.lua
Locales\esES.lua
Locales\esMX.lua
Locales\zhCN.lua
Locales\zhTW.lua
Locales\ptBR.lua
Locales\itIT.lua
Locales\koKR.lua
Locales\ruRU.lua
SocialQuest.lua
```

- [ ] **Step 1: Edit `SocialQuest.toc`** — insert the 11 `Locales\` lines between `Util\Colors.lua` and `SocialQuest.lua`.

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add SocialQuest.toc
git commit -m "feat: register locale files in TOC between Colors.lua and SocialQuest.lua"
```

---

## Chunk 2: Core file migrations

### Task 4: Migrate SocialQuest.lua

**Files:**
- Modify: `SocialQuest.lua` (lines 13, 23, 86–87)

**Background:** `SocialQuest.lua` contains the AQL-missing error print and the minimap tooltip strings. `local AQL` is already declared at line 13 as the only top-level local. Add `local L` after it.

- [ ] **Step 1: Add `local L` declaration after `local AQL` (line 13)**

Replace:
```lua
local AQL  -- set in OnInitialize
```
With:
```lua
local AQL  -- set in OnInitialize
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 2: Replace error print (line 23)**

Replace:
```lua
        self:Print("|cFFFF0000ERROR:|r AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled.")
```
With:
```lua
        self:Print(L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."])
```

Note: the `|cFFFF0000ERROR:|r ` color prefix is intentionally dropped. The L key is the full human-readable message per the spec's key list; WoW color escape codes are not part of localizable strings. The error is only visible when the addon fails to load (an exceptional case), so the cosmetic change is acceptable.

- [ ] **Step 3: Replace minimap tooltip strings (lines 86–87)**

Replace:
```lua
                tooltip:AddLine("Left-click to open group quest frame.", 1, 1, 1)
                tooltip:AddLine("Right-click to open settings.", 1, 1, 1)
```
With:
```lua
                tooltip:AddLine(L["Left-click to open group quest frame."], 1, 1, 1)
                tooltip:AddLine(L["Right-click to open settings."], 1, 1, 1)
```

- [ ] **Step 4: Verify the file looks correct** — open it and confirm the 3 string literals are replaced and `local L` is present.

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add SocialQuest.lua
git commit -m "feat: localize SocialQuest.lua strings"
```

---

### Task 5: Migrate Core/Announcements.lua

**Files:**
- Modify: `Core/Announcements.lua` (lines 21–23, 57–83, 72–74, 93–101, 117, 330, 416, 427, 501, 507)

**Background:** This file has the most strings. Key changes:
- Static table literals at lines 57–83 become `L["..."]` references (evaluated at load time).
- `formatOutboundObjectiveMsg` at lines 71–75: two inline strings become L keys.
- `formatObjectiveBannerMsg` at lines 91–101: three format strings become L keys.
- `displayChatPreview` at line 117: the chat label string (including color codes) becomes a L key. The full string including `|cFF00CCFF...|r ` with trailing space is the key.
- Line 330: concatenation `"Everyone has completed: " .. title` → `string.format(L["Everyone has completed: %s"], title)`.
- Lines 416, 427: `"You"` literal → `L["You"]`.
- Lines 501, 507: `sender .. " started/stopped following you."` concatenation → `string.format(L[...], sender)`.

- [ ] **Step 1: Add `local L` declaration after all existing top-level locals (after line 28)**

Lines 23–28 declare `throttleQueue`, `lastSendTime`, `THROTTLE_DELAY`, and `ticker`. Add `local L` after them, after `local ticker = nil`:

```lua
local ticker = nil
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 2: Replace OUTBOUND_QUEST_TEMPLATES table (lines 57–63)**

Replace:
```lua
local OUTBOUND_QUEST_TEMPLATES = {
    accepted  = "Quest accepted: %s",
    abandoned = "Quest abandoned: %s",
    finished  = "Quest complete (objectives done): %s",
    completed = "Quest turned in: %s",
    failed    = "Quest failed: %s",
}
```
With:
```lua
local OUTBOUND_QUEST_TEMPLATES = {
    accepted  = L["Quest accepted: %s"],
    abandoned = L["Quest abandoned: %s"],
    finished  = L["Quest complete (objectives done): %s"],
    completed = L["Quest turned in: %s"],
    failed    = L["Quest failed: %s"],
}
```

- [ ] **Step 3: Replace fallback in `formatOutboundQuestMsg` (line 66)**

Replace:
```lua
    local tmpl = OUTBOUND_QUEST_TEMPLATES[eventType] or "Quest event: %s"
```
With:
```lua
    local tmpl = OUTBOUND_QUEST_TEMPLATES[eventType] or L["Quest event: %s"]
```

- [ ] **Step 4: Replace strings in `formatOutboundObjectiveMsg` (lines 72–74)**

Replace:
```lua
    local suffix = isRegression and " (regression)" or ""
    return string.format("{rt1} SocialQuest: %d/%d %s%s for %s!",
        numFulfilled, numRequired, objText, suffix, questTitle)
```
With:
```lua
    local suffix = isRegression and L[" (regression)"] or ""
    return string.format(L["{rt1} SocialQuest: %d/%d %s%s for %s!"],
        numFulfilled, numRequired, objText, suffix, questTitle)
```

- [ ] **Step 5: Replace BANNER_QUEST_TEMPLATES table (lines 77–83)**

Replace:
```lua
local BANNER_QUEST_TEMPLATES = {
    accepted  = "%s accepted: %s",
    abandoned = "%s abandoned: %s",
    finished  = "%s finished objectives: %s",
    completed = "%s completed: %s",
    failed    = "%s failed: %s",
}
```
With:
```lua
local BANNER_QUEST_TEMPLATES = {
    accepted  = L["%s accepted: %s"],
    abandoned = L["%s abandoned: %s"],
    finished  = L["%s finished objectives: %s"],
    completed = L["%s completed: %s"],
    failed    = L["%s failed: %s"],
}
```

- [ ] **Step 6: Replace format strings in `formatObjectiveBannerMsg` (lines 93–100)**

Replace:
```lua
    if isComplete then
        return string.format("%s completed objective: %s (%d/%d)",
            sender, questTitle, numFulfilled, numRequired)
    elseif isRegression then
        return string.format("%s regressed: %s (%d/%d)",
            sender, questTitle, numFulfilled, numRequired)
    else
        return string.format("%s progressed: %s (%d/%d)",
            sender, questTitle, numFulfilled, numRequired)
    end
```
With:
```lua
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
```

- [ ] **Step 7: Replace chat preview label in `displayChatPreview` (line 117)**

Replace:
```lua
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCFFSocialQuest (preview):|r " .. msg)
```
With:
```lua
    DEFAULT_CHAT_FRAME:AddMessage(L["|cFF00CCFFSocialQuest (preview):|r "] .. msg)
```

- [ ] **Step 8: Replace "Everyone has completed" concatenation (line 330)**

Replace:
```lua
    local msg = "Everyone has completed: " .. title
```
With:
```lua
    local msg = string.format(L["Everyone has completed: %s"], title)
```

- [ ] **Step 9: Replace "You" in `OnOwnQuestEvent` (line 416)**

Replace:
```lua
    local msg = formatQuestBannerMsg("You", eventType, questTitle)
```
With:
```lua
    local msg = formatQuestBannerMsg(L["You"], eventType, questTitle)
```

- [ ] **Step 10: Replace "You" in `OnOwnObjectiveEvent` (line 427)**

Replace:
```lua
    local msg = formatObjectiveBannerMsg(
        "You", questInfo.title,
```
With:
```lua
    local msg = formatObjectiveBannerMsg(
        L["You"], questInfo.title,
```

- [ ] **Step 11: Replace follow notification concatenations (lines 501, 507)**

Replace:
```lua
    SocialQuest:Print(sender .. " started following you.")
```
With:
```lua
    SocialQuest:Print(string.format(L["%s started following you."], sender))
```

Replace:
```lua
    SocialQuest:Print(sender .. " stopped following you.")
```
With:
```lua
    SocialQuest:Print(string.format(L["%s stopped following you."], sender))
```

- [ ] **Step 12: Verify** — open `Core/Announcements.lua` and confirm:
- `local L` declaration is present near the top.
- No raw string literals remain for any of the player-facing strings listed above.
- `OUTBOUND_QUEST_TEMPLATES` and `BANNER_QUEST_TEMPLATES` tables use L keys.
- The two `checkAllCompleted` / follow blocks use `string.format` with L keys.

- [ ] **Step 13: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Core/Announcements.lua
git commit -m "feat: localize Core/Announcements.lua strings"
```

---

## Chunk 3: UI file migrations

### Task 6: Migrate UI/GroupFrame.lua

**Files:**
- Modify: `UI/GroupFrame.lua` (lines 8–10, 39, 100)

**Background:** Two player-visible strings: the frame title and the URL popup title.

- [ ] **Step 1: Add `local L` declaration after existing local declarations (after line 10)**

After:
```lua
local frame          = nil
local refreshPending = false
local urlPopup       = nil
```
Add:
```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 2: Replace URL popup title (line 39)**

Replace:
```lua
    p.TitleText:SetText("Quest URL (Ctrl+C to copy)")
```
With:
```lua
    p.TitleText:SetText(L["Quest URL (Ctrl+C to copy)"])
```

- [ ] **Step 3: Replace frame title (line 100)**

Replace:
```lua
    f.TitleText:SetText("SocialQuest — Group Quests")
```
With:
```lua
    f.TitleText:SetText(L["SocialQuest — Group Quests"])
```
(The key uses a literal em dash character, matching both the source file and `enUS.lua`.)

- [ ] **Step 4: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/GroupFrame.lua
git commit -m "feat: localize UI/GroupFrame.lua strings"
```

---

### Task 7: Migrate UI/RowFactory.lua

**Files:**
- Modify: `UI/RowFactory.lua` (lines 8–10, 62, 77, 142, 153, 155, 168–170, 251, 259, 268)

**Background:** Eight string literals plus three concatenation refactors. The concatenation refactors are required because word order differs across languages — a player name cannot simply be prepended to a suffix.

- [ ] **Step 1: Add `local L` declaration after existing local constants (after line 10)**

After:
```lua
local CONTENT_WIDTH = 360
local ROW_H         = 18     -- standard row height in pixels
local INDENT_STEP   = 16     -- pixels per indent level
```
Add:
```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 2: Replace "expand all" label (line 62)**

Replace:
```lua
    expandLabel:SetText(C.white .. "expand all" .. C.reset)
```
With:
```lua
    expandLabel:SetText(C.white .. L["expand all"] .. C.reset)
```

- [ ] **Step 3: Replace "collapse all" label (line 77)**

Replace:
```lua
    collapseLabel:SetText(C.white .. "collapse all" .. C.reset)
```
With:
```lua
    collapseLabel:SetText(C.white .. L["collapse all"] .. C.reset)
```

- [ ] **Step 4: Replace wowhead tooltip string (line 142)**

Replace:
```lua
        GameTooltip:SetText("Click here to copy the wowhead quest url", 1, 1, 1)
```
With:
```lua
        GameTooltip:SetText(L["Click here to copy the wowhead quest url"], 1, 1, 1)
```

- [ ] **Step 5: Replace "(Complete)" badge (line 153)**

Replace:
```lua
        badgeText = SocialQuestColors.GetUIColor("completed") .. "(Complete)" .. C.reset
```
With:
```lua
        badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
```

- [ ] **Step 6: Replace "(Group)" badge (line 155)**

Replace:
```lua
        badgeText = C.chain .. "(Group)" .. C.reset
```
With:
```lua
        badgeText = C.chain .. L["(Group)"] .. C.reset
```

- [ ] **Step 7: Replace " (Step X of Y)" concatenation (lines 168–170)**

Replace:
```lua
        titleText = titleText
            .. " (Step " .. tostring(ci.step   or "?")
            .. " of "    .. tostring(ci.length or "?") .. ")"
```
With:
```lua
        titleText = titleText
            .. string.format(L[" (Step %s of %s)"], tostring(ci.step or "?"), tostring(ci.length or "?"))
```

- [ ] **Step 8: Replace name .. " FINISHED" concatenation (line 251)**

Replace:
```lua
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. name .. " FINISHED" .. C.reset)
```
With:
```lua
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], name) .. C.reset)
```

- [ ] **Step 9: Replace name .. " Needs it Shared" concatenation (line 259)**

Replace:
```lua
        fs:SetText(C.unknown .. name .. " Needs it Shared" .. C.reset)
```
With:
```lua
        fs:SetText(C.unknown .. string.format(L["%s Needs it Shared"], name) .. C.reset)
```

- [ ] **Step 10: Replace name .. " (no data)" concatenation (line 268)**

Replace:
```lua
        fs:SetText(C.unknown .. name .. " (no data)" .. C.reset)
```
With:
```lua
        fs:SetText(C.unknown .. string.format(L["%s (no data)"], name) .. C.reset)
```

- [ ] **Step 11: Verify** — confirm `local L` is present and all 10 sites are updated. Check the `AddPlayerRow` function especially — the three player-status lines are in the `if playerEntry.hasCompleted`, `elseif playerEntry.needsShare`, and third `elseif` branches.

- [ ] **Step 12: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/RowFactory.lua
git commit -m "feat: localize UI/RowFactory.lua strings including concatenation refactors"
```

---

### Task 8: Migrate UI/Tooltips.lua, UI/Tabs/*, and UI/TabUtils.lua

**Files:**
- Modify: `UI/Tooltips.lua` (line 4, 18, 26, 28, 35)
- Modify: `UI/Tabs/MineTab.lua` (line 6, 13, 26)
- Modify: `UI/Tabs/PartyTab.lua` (line 5, 23, 34, 93)
- Modify: `UI/Tabs/SharedTab.lua` (line 7, 13)
- Modify: `UI/TabUtils.lua` (line 5, 19)

**Background:** Small files with few strings each. TabUtils.lua and MineTab.lua both use `"Other Quests"` as a zone fallback — they share the same L key (defined once in enUS.lua). PartyTab.lua uses `"(You)"` in two places (lines 23 and 34) for the local player label.

**UI/Tooltips.lua changes:**

- [ ] **Step 1: Add `local L` after `SocialQuestTooltips = {}` (line 4)**

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 2: Replace "Group Progress" (line 18)**

Replace:
```lua
                tooltip:AddLine(C.header .. "Group Progress" .. C.reset)
```
With:
```lua
                tooltip:AddLine(C.header .. L["Group Progress"] .. C.reset)
```

- [ ] **Step 3: Replace "(shared, no data)" (line 26)**

Replace:
```lua
                statusStr = C.unknown .. "(shared, no data)" .. C.reset
```
With:
```lua
                statusStr = C.unknown .. L["(shared, no data)"] .. C.reset
```

- [ ] **Step 4: Replace "Objectives complete" (line 28)**

Replace:
```lua
                statusStr = C.completed .. "Objectives complete" .. C.reset
```
With:
```lua
                statusStr = C.completed .. L["Objectives complete"] .. C.reset
```

- [ ] **Step 5: Replace "(no data)" in Tooltips.lua (line 35)**

Replace:
```lua
                statusStr = #parts > 0 and table.concat(parts, "  ") or C.unknown .. "(no data)" .. C.reset
```
With:
```lua
                statusStr = #parts > 0 and table.concat(parts, "  ") or C.unknown .. L["(no data)"] .. C.reset
```

**UI/Tabs/MineTab.lua changes:**

- [ ] **Step 6: Add `local L` after `MineTab = {}` (line 6)**

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 7: Replace "Mine" in `GetLabel` (line 13)**

Replace:
```lua
    return "Mine"
```
With:
```lua
    return L["Mine"]
```

- [ ] **Step 8: Replace "Other Quests" fallback in MineTab.lua (line 26)**

Replace:
```lua
        local zoneName = questInfo.zone or "Other Quests"
```
With:
```lua
        local zoneName = questInfo.zone or L["Other Quests"]
```

**UI/Tabs/PartyTab.lua changes:**

- [ ] **Step 9: Add `local L` after `PartyTab = {}` (line 5)**

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 10: Replace first `"(You)"` (line 23 — local player has quest)**

Replace:
```lua
            name           = "(You)",
```
(The first occurrence, inside the `if myInfo then` block)
With:
```lua
            name           = L["(You)"],
```

- [ ] **Step 11: Replace second `"(You)"` (line 34 — local player has completed quest)**

Replace:
```lua
            name           = "(You)",
```
(The second occurrence, inside the `elseif AQL:HasCompletedQuest(questID) then` block)
With:
```lua
            name           = L["(You)"],
```

- [ ] **Step 12: Replace "Party" in `GetLabel` (line 93)**

Replace:
```lua
    return "Party"
```
With:
```lua
    return L["Party"]
```

**UI/Tabs/SharedTab.lua changes:**

- [ ] **Step 13: Add `local L` after `SharedTab = {}` (line 7)**

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 14: Replace "Shared" in `GetLabel` (line 13)**

Replace:
```lua
    return "Shared"
```
With:
```lua
    return L["Shared"]
```

- [ ] **Step 14b: Replace "Other Quests" fallback in SharedTab.lua (line 76)**

Replace:
```lua
            local zoneName = "Other Quests"
```
With:
```lua
            local zoneName = L["Other Quests"]
```

(Same key already defined in enUS.lua; no new key needed.)

**UI/TabUtils.lua changes:**

- [ ] **Step 15: Add `local L` after `SocialQuestTabUtils = {}` (line 5)**

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 16: Replace "Other Quests" fallback in TabUtils.lua (line 19)**

Replace:
```lua
    return "Other Quests"
```
With:
```lua
    return L["Other Quests"]
```

- [ ] **Step 17: Commit all five files**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Tooltips.lua UI/Tabs/MineTab.lua UI/Tabs/PartyTab.lua UI/Tabs/SharedTab.lua UI/TabUtils.lua
git commit -m "feat: localize UI/Tooltips.lua, UI/Tabs/*, and UI/TabUtils.lua strings"
```

---

### Task 9: Migrate UI/Options.lua

**Files:**
- Modify: `UI/Options.lua` (lines 1–4, and throughout the options table)

**Background:** All `name` and `desc` string literals in the options table become `L["..."]` calls. These are evaluated at `Initialize()` call time (during addon OnInitialize), which runs after all locale files are already loaded. `local L` goes at file scope before `SocialQuestOptions = {}`.

Note: `"Party"`, `"Raid"`, `"Guild"`, `"Battleground"`, `"Debug"` and the toggle names `"Accepted"`, `"Abandoned"` etc. share L keys with other files — same key, same definition in enUS.lua. No special handling needed; just use `L["..."]`.

Note: Long description strings that span multiple lines with `..` concatenation in the source must be replaced with a single `L["..."]` call matching the full concatenated English text as the key. For example:

```lua
-- Before (across two lines)
"Send a chat message when a quest objective progresses or regresses. "
.. "Format matches Questie's style. Never suppressed by Questie — "
.. "Questie does not announce partial progress.",
-- After (single L key)
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."],
```

Similarly for `"Master switch: allow any banner notifications to appear. " .. "Individual 'Display Events' groups below control which event types are shown per section."` and all other concatenated descriptions.

- [ ] **Step 1: Add `local L` at file scope (before `SocialQuestOptions = {}`)**

At the top of the file, add:
```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 2: Replace all name and desc strings in the options table**

Replace every string literal used as a `name` or `desc` value with the corresponding `L["..."]` call. Match strings exactly as they appear in enUS.lua.

The full set of replacements (name → key, desc → key):

**`announceChatGroup` function:**
- `"Accepted"` → `L["Accepted"]`
- `"Send a chat message when you accept a quest."` → `L["Send a chat message when you accept a quest."]`
- `"Abandoned"` → `L["Abandoned"]`
- `"Send a chat message when you abandon a quest."` → `L["Send a chat message when you abandon a quest."]`
- `"Finished"` → `L["Finished"]`
- `"Send a chat message when all your quest objectives are complete (before turning in)."` → `L[...]`
- `"Completed"` → `L["Completed"]`
- `"Send a chat message when you turn in a quest."` → `L[...]`
- `"Failed"` → `L["Failed"]`
- `"Send a chat message when a quest fails."` → `L[...]`
- `"Objective Progress"` → `L["Objective Progress"]`
- Multi-line Objective Progress desc → `L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."]`
- `"Objective Complete"` → `L["Objective Complete"]`
- Multi-line Objective Complete desc → `L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."]`
- Group name `"Announce in Chat"` → `L["Announce in Chat"]`

**`ownDisplayEventsGroup` function:**
- Group name `"Own Quest Banners"` → `L["Own Quest Banners"]`
- `"Accepted"` → `L["Accepted"]`
- `"Show a banner when you accept a quest."` → `L[...]`
- `"Abandoned"` → `L["Abandoned"]`
- `"Show a banner when you abandon a quest."` → `L[...]`
- `"Finished"` → `L["Finished"]`
- `"Show a banner when all objectives on a quest are complete (before turning in)."` → `L[...]`
- `"Completed"` → `L["Completed"]`
- `"Show a banner when you turn in a quest."` → `L[...]`
- `"Failed"` → `L["Failed"]`
- `"Show a banner when a quest fails."` → `L[...]`
- `"Objective Progress"` → `L["Objective Progress"]`
- `"Show a banner when one of your quest objectives progresses or regresses."` → `L[...]`
- `"Objective Complete"` → `L["Objective Complete"]`
- `"Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."` → `L[...]`

**`displayEventsGroup` function:**
- Group name `"Display Events"` → `L["Display Events"]`
- `"Accepted"` → `L["Accepted"]`
- `"Show a banner on screen when a group member accepts a quest."` → `L[...]`
- `"Abandoned"` → `L["Abandoned"]`
- `"Show a banner on screen when a group member abandons a quest."` → `L[...]`
- `"Finished"` → `L["Finished"]`
- `"Show a banner on screen when a group member finishes all objectives on a quest."` → `L[...]`
- `"Completed"` → `L["Completed"]`
- `"Show a banner on screen when a group member turns in a quest."` → `L[...]`
- `"Failed"` → `L["Failed"]`
- `"Show a banner on screen when a group member fails a quest."` → `L[...]`
- `"Objective Progress"` → `L["Objective Progress"]`
- Multi-line desc → `L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."]`
- `"Objective Complete"` → `L["Objective Complete"]`
- `"Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."` → `L[...]`

**`options` table — general group:**
- Group name `"General"` → `L["General"]`
- `"Enable SocialQuest"` → `L["Enable SocialQuest"]`
- `"Master on/off switch for all SocialQuest functionality."` → `L[...]`
- `"Show received events"` → `L["Show received events"]`
- Multi-line master switch desc → `L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."]`
- `"Colorblind Mode"` → `L["Colorblind Mode"]`
- Multi-line colorblind desc → `L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."]`
- `"Show banners for your own quest events"` → `L["Show banners for your own quest events"]`
- `"Show a banner on screen for your own quest events."` → `L[...]`

**`options` table — party group:**
- Group name `"Party"` → `L["Party"]`
- `"Enable transmission"` → `L["Enable transmission"]`
- `"Broadcast your quest events to party members via addon comm."` → `L[...]`
- `"Show received events"` → `L["Show received events"]`
- `"Allow banner notifications from party members (subject to Display Events toggles below)."` → `L[...]`

**`options` table — raid group:**
- Group name `"Raid"` → `L["Raid"]`
- `"Enable transmission"` → `L["Enable transmission"]`
- `"Broadcast your quest events to raid members via addon comm."` → `L[...]`
- `"Show received events"` → `L["Show received events"]`
- `"Allow banner notifications from raid members."` → `L[...]`
- `"Only show notifications from friends"` → `L["Only show notifications from friends"]`
- Multi-line friends-only desc → `L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."]`

**`options` table — guild group:**
- Group name `"Guild"` → `L["Guild"]`
- `"Enable chat announcements"` → `L["Enable chat announcements"]`
- Multi-line guild desc → `L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."]`

**`options` table — battleground group:**
- Group name `"Battleground"` → `L["Battleground"]`
- `"Enable transmission"` → `L["Enable transmission"]`
- `"Broadcast your quest events to battleground members via addon comm."` → `L[...]`
- `"Show received events"` → `L["Show received events"]`
- `"Allow banner notifications from battleground members."` → `L[...]`
- `"Only show notifications from friends"` → `L["Only show notifications from friends"]`
- `"Only show banner notifications from friends in the battleground."` → `L[...]`

**`options` table — whisperFriends group:**
- Group name `"Whisper Friends"` → `L["Whisper Friends"]`
- `"Enable whispers to friends"` → `L["Enable whispers to friends"]`
- `"Send your quest events as whispers to online friends."` → `L[...]`
- `"Group members only"` → `L["Group members only"]`
- `"Restrict whispers to friends currently in your group."` → `L[...]`

**`options` table — follow group:**
- Group name `"Follow Notifications"` → `L["Follow Notifications"]`
- `"Enable follow notifications"` → `L["Enable follow notifications"]`
- Multi-line follow desc → `L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."]`
- `"Announce when you follow someone"` → `L["Announce when you follow someone"]`
- `"Whisper the player you begin following so they know you are following them."` → `L[...]`
- `"Announce when followed"` → `L["Announce when followed"]`
- `"Display a local message when someone starts or stops following you."` → `L[...]`

**`options` table — debug group:**
- Group name `"Debug"` → `L["Debug"]`
- `"Enable debug mode"` → `L["Enable debug mode"]`
- Multi-line debug desc → `L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."]`
- Inline group name `"Test Banners and Chat"` → `L["Test Banners and Chat"]`

**Test button names and descs:**
- `"Test Accepted"` → `L["Test Accepted"]`
- Long desc → `L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."]`
- `"Test Abandoned"` → `L["Test Abandoned"]`
- `"Display a demo banner and local chat preview for the 'Quest abandoned' event."` → `L[...]`
- `"Test Finished"` → `L["Test Finished"]`
- `"Display a demo banner and local chat preview for the 'Quest finished objectives' event."` → `L[...]`
- `"Test Completed"` → `L["Test Completed"]`
- `"Display a demo banner and local chat preview for the 'Quest turned in' event."` → `L[...]`
- `"Test Failed"` → `L["Test Failed"]`
- `"Display a demo banner and local chat preview for the 'Quest failed' event."` → `L[...]`
- `"Test Obj. Progress"` → `L["Test Obj. Progress"]`
- `"Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."` → `L[...]`
- `"Test Obj. Complete"` → `L["Test Obj. Complete"]`
- `"Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."` → `L[...]`
- `"Test Obj. Regression"` → `L["Test Obj. Regression"]`
- `"Display a demo banner and local chat preview for an objective regression (count went backward)."` → `L[...]`
- `"Test All Completed"` → `L["Test All Completed"]`
- Long all-completed desc → `L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."]`

- [ ] **Step 3: Verify** — open `UI/Options.lua` and scan for any remaining raw string literals in `name` or `desc` fields. There should be none matching the strings above.

- [ ] **Step 4: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Options.lua
git commit -m "feat: localize UI/Options.lua — replace all name/desc strings with L keys"
```

---

## Manual Verification Checklist

These steps cannot be automated (no test framework for WoW Lua). Perform in-game after loading the updated addon.

**Test A — enUS locale (default)**
- [ ] Log in (or `/reload`) with client locale `enUS`.
- [ ] Open `/sq` — confirm Group Quests frame shows "Mine", "Party", "Shared" tab labels.
- [ ] Open `/sq config` — confirm all option labels and descriptions display in English.
- [ ] Accept a quest — confirm chat announcement fires normally.
- [ ] Hover a quest link — confirm "Group Progress" tooltip header appears.

**Test B — Non-English locale smoke test**
- [ ] Temporarily override `GetLocale` in a test session to return `"deDE"` (or any non-English locale).
- [ ] Reload and verify German strings appear in tab labels, frame title, tooltip header, and option panel.
- [ ] Verify format strings with `%s`/`%d` still produce correct output (no Lua errors from arg count mismatch).

**Test C — Format specifier integrity**
- [ ] Accept a quest with objectives — confirm objective progress chat message formats correctly.
- [ ] Confirm `{rt1}` raid marker appears in objective progress messages.
- [ ] Turn in a quest — confirm completion announcement fires; confirm no regression announcement.
