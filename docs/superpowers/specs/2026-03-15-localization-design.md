# Social Quest Localization — Design Spec

## Goal

Add AceLocale-3.0-based localization to the Social Quest addon supporting 11 locales: enUS, deDE, frFR, esES, esMX, zhCN, zhTW, ptBR, itIT, koKR, ruRU. Machine translations (AI-generated) are provided for all 10 non-English locales. English strings serve as both keys and fallback values.

---

## Architecture

### Library

`AceLocale-3.0` is used via `LibStub`. It is already available through the existing `Ace3` dependency — no new libraries need to be bundled.

### File Structure

```
Locales/
  enUS.lua    ← default locale, keys = English strings
  deDE.lua
  frFR.lua
  esES.lua
  esMX.lua
  zhCN.lua
  zhTW.lua
  ptBR.lua
  itIT.lua
  koKR.lua
  ruRU.lua
```

All 11 files are listed in the TOC **before** `SocialQuest.lua` (and after `Util\Colors.lua`). AceLocale loads all files on startup, but each non-matching locale registers with a nil guard and exits immediately — no memory or CPU overhead.

### Key Strategy

English strings serve as their own keys. `enUS.lua` registers as the default locale and sets each key to `true`:

```lua
-- Locales/enUS.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "enUS", true)
if not L then return end
L["Quest accepted: %s"] = true
L["Quest abandoned: %s"] = true
-- ... all strings
```

Non-English locales override only the keys they translate:

```lua
-- Locales/deDE.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "deDE")
if not L then return end
L["Quest accepted: %s"] = "Quest angenommen: %s"
-- ...
```

If a key is missing in a non-English locale, AceLocale returns the key itself (the English string) — always a readable fallback, never a symbol name.

### Per-File Access

Every source file that uses localized strings adds at the top (after any existing `local` declarations):

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

String literals are then replaced with `L["..."]`.

---

## Scope

### Strings That Are Localized (~110 strings)

| File | Examples |
|---|---|
| `SocialQuest.lua` | Error message, minimap tooltip lines |
| `Core/Announcements.lua` | Chat templates, banner templates, follow notifications, regression suffix, chat preview label, all-completed message |
| `UI/GroupFrame.lua` | Frame title, URL popup title |
| `UI/RowFactory.lua` | expand all, collapse all, link tooltip, (Complete), (Group), Step X of Y, %s FINISHED, %s Needs it Shared, %s (no data) |
| `UI/Tooltips.lua` | Group Progress header, status labels |
| `UI/Tabs/MineTab.lua` | Tab label, Other Quests fallback |
| `UI/Tabs/PartyTab.lua` | Tab label, (You) |
| `UI/Tabs/SharedTab.lua` | Tab label, Other Quests fallback |
| `UI/TabUtils.lua` | Other Quests fallback |
| `UI/Options.lua` | All labels and descriptions (~100 strings) |

### Strings That Are NOT Localized

| String | Reason |
|---|---|
| `"[+]"` / `"[-]"` | Universal UI symbols |
| `"Quest " .. questID` | Numeric ID fallback, not translatable |
| `"Chain " .. chainID` | Numeric ID fallback, not translatable |
| `"SocialQuest"` (addon name) | Proper noun |
| Test/demo strings in `Announcements.lua` | Developer test content, not player-facing |

---

## Template String Migration

`Announcements.lua` has two static tables of format strings. These are migrated to reference L at file-load time:

```lua
-- Before
local OUTBOUND_QUEST_TEMPLATES = {
    accepted = "Quest accepted: %s",
    ...
}

-- After
local OUTBOUND_QUEST_TEMPLATES = {
    accepted  = L["Quest accepted: %s"],
    abandoned = L["Quest abandoned: %s"],
    finished  = L["Quest complete (objectives done): %s"],
    completed = L["Quest turned in: %s"],
    failed    = L["Quest failed: %s"],
}
```

Same pattern for `BANNER_QUEST_TEMPLATES`. Inline `string.format` calls in `formatOutboundObjectiveMsg` and `formatObjectiveBannerMsg` are also migrated:

```lua
-- Before
local suffix = isRegression and " (regression)" or ""
return string.format("{rt1} SocialQuest: %d/%d %s%s for %s!", ...)

-- After
local suffix = isRegression and L[" (regression)"] or ""
return string.format(L["{rt1} SocialQuest: %d/%d %s%s for %s!"], ...)
```

### Concatenation Refactors Required

Several source sites use Lua string concatenation rather than `string.format`. These must be converted when adding `L[...]` keys, because some languages require the subject/object to appear in a different position.

**`Core/Announcements.lua` — "Everyone has completed"**
```lua
-- Before
local msg = "Everyone has completed: " .. title
-- After
local msg = string.format(L["Everyone has completed: %s"], title)
```

**`Core/Announcements.lua` — Follow notifications**
```lua
-- Before
SocialQuest:Print(sender .. " started following you.")
SocialQuest:Print(sender .. " stopped following you.")
-- After
SocialQuest:Print(string.format(L["%s started following you."], sender))
SocialQuest:Print(string.format(L["%s stopped following you."], sender))
```

**`UI/RowFactory.lua` — Player status suffixes**
```lua
-- Before
fs:SetText(SocialQuestColors.GetUIColor("completed") .. name .. " FINISHED" .. C.reset)
fs:SetText(C.unknown .. name .. " Needs it Shared" .. C.reset)
fs:SetText(C.unknown .. name .. " (no data)" .. C.reset)
-- After
fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], name) .. C.reset)
fs:SetText(C.unknown .. string.format(L["%s Needs it Shared"], name) .. C.reset)
fs:SetText(C.unknown .. string.format(L["%s (no data)"], name) .. C.reset)
```

**`UI/RowFactory.lua` — Step/chain display (lines 168–170)**

Source currently uses three separate concatenations:
```lua
-- Before
titleText = titleText
    .. " (Step " .. tostring(ci.step   or "?")
    .. " of "    .. tostring(ci.length or "?") .. ")"
-- After
titleText = titleText
    .. string.format(L[" (Step %s of %s)"], tostring(ci.step or "?"), tostring(ci.length or "?"))
```

---

## TOC Changes

Add locale files after `Util\Colors.lua` and before `SocialQuest.lua`:

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

---

## Complete String List for enUS.lua

The following keys must be defined in `enUS.lua`. Each is set to `true`.

### Core/Announcements.lua
```
"Quest accepted: %s"
"Quest abandoned: %s"
"Quest complete (objectives done): %s"
"Quest turned in: %s"
"Quest failed: %s"
"Quest event: %s"              ← defensive fallback in formatOutboundQuestMsg; unreachable
                                  in the current call graph. Include for safety; non-English
                                  locales need not prioritize translating it.
" (regression)"
"{rt1} SocialQuest: %d/%d %s%s for %s!"
"%s accepted: %s"
"%s abandoned: %s"
"%s finished objectives: %s"
"%s completed: %s"
"%s failed: %s"
"%s completed objective: %s (%d/%d)"
"%s regressed: %s (%d/%d)"
"%s progressed: %s (%d/%d)"
"|cFF00CCFFSocialQuest (preview):|r "
"Everyone has completed: %s"   ← %s = quest title; source currently uses concatenation,
                                  must be changed to string.format (see migration note below)
"You"                          ← sender name used in own-quest banners ("You accepted: …");
                                  distinct from "(You)" in RowFactory (which has parentheses)
"%s started following you."    ← %s = player name; source currently uses concatenation
"%s stopped following you."    ← %s = player name; source currently uses concatenation
```

### SocialQuest.lua
```
"ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."
"Left-click to open group quest frame."
"Right-click to open settings."
```

### UI/GroupFrame.lua
```
"SocialQuest — Group Quests"
"Quest URL (Ctrl+C to copy)"
```

### UI/RowFactory.lua
```
"expand all"
"collapse all"
"Click here to copy the wowhead quest url"
"(Complete)"
"(Group)"
" (Step %s of %s)"   ← source uses string concatenation, not string.format; must be
                        refactored (see migration note below)
"%s FINISHED"        ← %s = player name; source concatenates name .. " FINISHED";
                        must be refactored to string.format(L["%s FINISHED"], name)
"%s Needs it Shared" ← %s = player name; same concatenation refactor required
"%s (no data)"       ← %s = player name; same concatenation refactor required
```

### UI/Tooltips.lua
```
"Group Progress"
"(shared, no data)"
"Objectives complete"
"(no data)"
```

### UI/Tabs/MineTab.lua
```
"Mine"
"Other Quests"
```

### UI/Tabs/PartyTab.lua
```
"Party"
"(You)"
```

### UI/Tabs/SharedTab.lua
```
"Shared"
```

### UI/TabUtils.lua
*(shares "Other Quests" — same key, defined once in enUS.lua)*

### UI/Options.lua
```
"Accepted"
"Send a chat message when you accept a quest."
"Abandoned"
"Send a chat message when you abandon a quest."
"Finished"
"Send a chat message when all your quest objectives are complete (before turning in)."
"Completed"
"Send a chat message when you turn in a quest."
"Failed"
"Send a chat message when a quest fails."
"Objective Progress"
"Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."
"Objective Complete"
"Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."
"Announce in Chat"
"Own Quest Banners"
"Show a banner when you accept a quest."
"Show a banner when you abandon a quest."
"Show a banner when all objectives on a quest are complete (before turning in)."
"Show a banner when you turn in a quest."
"Show a banner when a quest fails."
"Show a banner when one of your quest objectives progresses or regresses."
"Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."
"Display Events"
"Show a banner on screen when a group member accepts a quest."
"Show a banner on screen when a group member abandons a quest."
"Show a banner on screen when a group member finishes all objectives on a quest."
"Show a banner on screen when a group member turns in a quest."
"Show a banner on screen when a group member fails a quest."
"Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."
"Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."
"General"
"Enable SocialQuest"
"Master on/off switch for all SocialQuest functionality."
"Show received events"
"Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."
"Colorblind Mode"
"Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."
"Show banners for your own quest events"
"Show a banner on screen for your own quest events."
"Party"
"Enable transmission"
"Broadcast your quest events to party members via addon comm."
"Allow banner notifications from party members (subject to Display Events toggles below)."
"Raid"
"Broadcast your quest events to raid members via addon comm."
"Allow banner notifications from raid members."
"Only show notifications from friends"
"Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."
"Guild"
"Enable chat announcements"
"Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."
"Battleground"
"Broadcast your quest events to battleground members via addon comm."
"Allow banner notifications from battleground members."
"Only show banner notifications from friends in the battleground."
"Whisper Friends"
"Enable whispers to friends"
"Send your quest events as whispers to online friends."
"Group members only"
"Restrict whispers to friends currently in your group."
"Follow Notifications"
"Enable follow notifications"
"Send a whisper to players you start or stop following, and receive notifications when someone follows you."
"Announce when you follow someone"
"Whisper the player you begin following so they know you are following them."
"Announce when followed"
"Display a local message when someone starts or stops following you."
"Debug"
"Enable debug mode"
"Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."
"Test Banners and Chat"
"Test Accepted"
"Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."
"Test Abandoned"
"Display a demo banner and local chat preview for the 'Quest abandoned' event."
"Test Finished"
"Display a demo banner and local chat preview for the 'Quest finished objectives' event."
"Test Completed"
"Display a demo banner and local chat preview for the 'Quest turned in' event."
"Test Failed"
"Display a demo banner and local chat preview for the 'Quest failed' event."
"Test Obj. Progress"
"Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."
"Test Obj. Complete"
"Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."
"Test Obj. Regression"
"Display a demo banner and local chat preview for an objective regression (count went backward)."
"Test All Completed"
"Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."
```

---

## Translation Notes

- All 10 non-English locale files are AI-generated. Format specifiers (`%s`, `%d`, `%d/%d`) must be preserved exactly in all translations — count and order must match the source exactly.
- The `{rt1}` raid marker symbol in the objective progress chat string must be preserved as-is in all translations.
- The key `"|cFF00CCFFSocialQuest (preview):|r "` includes a trailing space after `|r`. That trailing space is intentional and required — without it, the banner text immediately follows the reset code with no separator. Every translation must preserve the trailing space.
- "Other Quests" is used as a zone fallback name when no zone can be determined. It appears in three files (`MineTab`, `SharedTab`, `TabUtils`) but is one key defined once in `enUS.lua`.
- `"(You)"` (with parentheses) refers to the local player label in party/shared tab rows — translate as the local-language equivalent of a self-referential placeholder.
- `"You"` (without parentheses) is used as the sender name in own-quest banners (e.g. "You accepted: [Quest Name]"). Translate as the nominative first-person pronoun.
- The `%s` in `"%s FINISHED"`, `"%s Needs it Shared"`, `"%s (no data)"`, `"%s started following you."`, `"%s stopped following you."` is always a player character name. Translators should account for morphological agreement where applicable.
- The `%s` in `"Everyone has completed: %s"` is a quest title.
- The key `" (regression)"` has a leading space. That space is intentional — it separates the suffix from the preceding objective text when concatenated. Every translation must preserve the leading space.
- The string `"{rt1} SocialQuest: %d/%d %s%s for %s!"` has five positional arguments in order: (1) numFulfilled `%d`, (2) numRequired `%d`, (3) objective text `%s`, (4) regression suffix `%s` (either `" (regression)"` or empty string), (5) quest title `%s`. Translators must preserve all five specifiers in the same order.

---

## Testing

1. Set client locale to `enUS` — all strings display normally.
2. Verify a non-English locale file (e.g. `deDE`) by temporarily setting `GetLocale = function() return "deDE" end` in a test session and checking that German strings appear in the UI and chat.
3. Verify that format strings with `%s`/`%d` still produce correct output after translation (no argument count mismatch).
4. Options panel: open `/sq config` and confirm all labels and descriptions are translated.
