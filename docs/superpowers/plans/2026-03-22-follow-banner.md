# Follow Banner Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display a banner notification when another player starts or stops following the local player, in addition to the existing chat message, with a new `follow` color key and a debug test button.

**Architecture:** Add `follow` to the `SocialQuestColors.event` and `eventCB` tables so `displayBanner` can resolve its color. Call `displayBanner(msg, "follow")` in the existing `OnFollowStart`/`OnFollowStop` handlers alongside the current `SocialQuest:Print`. Add a `TestFollowNotification` function and a corresponding execute button in the debug panel. Add locale keys to all 11 locale files.

**Tech Stack:** Lua 5.1, Ace3 (AceConfig/AceLocale), WoW TBC Anniversary (Interface 20505)

---

## Files Modified

| File | Change |
|---|---|
| `Util/Colors.lua` | Add `follow` entry to `event` and `eventCB` tables |
| `Core/Announcements.lua` | Add `displayBanner` calls in follow handlers; add `TestFollowNotification` |
| `UI/Options.lua` | Add `testFollowNotification` execute button in debug panel |
| `Locales/enUS.lua` | Add 2 new locale keys |
| `Locales/deDE.lua` | Add 2 new keys (English placeholder) |
| `Locales/frFR.lua` | Add 2 new keys (English placeholder) |
| `Locales/esES.lua` | Add 2 new keys (English placeholder) |
| `Locales/esMX.lua` | Add 2 new keys (English placeholder) |
| `Locales/zhCN.lua` | Add 2 new keys (English placeholder) |
| `Locales/zhTW.lua` | Add 2 new keys (English placeholder) |
| `Locales/ptBR.lua` | Add 2 new keys (English placeholder) |
| `Locales/itIT.lua` | Add 2 new keys (English placeholder) |
| `Locales/koKR.lua` | Add 2 new keys (English placeholder) |
| `Locales/ruRU.lua` | Add 2 new keys (English placeholder) |
| `Locales/jaJP.lua` | Add 2 new keys (English placeholder) |
| `SocialQuest.toc` | Bump version 2.3.7 → 2.4.0 |
| `CLAUDE.md` | Add version history entry for 2.4.0 |

---

### Task 1: Add `follow` color to Colors.lua

**Files:**
- Modify: `Util/Colors.lua:18-38`

- [ ] **Step 1: Add `follow` to `SocialQuestColors.event`**

In `Util/Colors.lua`, add after the `all_complete` line inside `SocialQuestColors.event` (currently line 26):

```lua
    follow             = { r=1,     g=0.85,  b=0.6   },  -- warm tan (#FFD999)
```

- [ ] **Step 2: Add `follow` to `SocialQuestColors.eventCB`**

In `Util/Colors.lua`, add after the `all_complete` line inside `SocialQuestColors.eventCB` (currently line 37):

```lua
    follow             = { r=0.941, g=0.894, b=0.259 },  -- Okabe-Ito yellow (#F0E442)
```

- [ ] **Step 3: Commit**

```
git add Util/Colors.lua
git commit -m "feat: add follow color key to event and eventCB tables"
```

---

### Task 2: Add banner display and test function to Announcements.lua

**Files:**
- Modify: `Core/Announcements.lua:639-649` (follow handlers)
- Modify: `Core/Announcements.lua` (add `TestFollowNotification` after `TestFlightDiscovery`)

- [ ] **Step 1: Update `OnFollowStart` to also display a banner**

Replace the existing `OnFollowStart` function (lines 639–643):

```lua
function SocialQuestAnnounce:OnFollowStart(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    local msg = string.format(L["%s started following you."], sender)
    SocialQuest:Print(msg)
    displayBanner(msg, "follow")
end
```

- [ ] **Step 2: Update `OnFollowStop` to also display a banner**

Replace the existing `OnFollowStop` function (lines 645–649):

```lua
function SocialQuestAnnounce:OnFollowStop(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    local msg = string.format(L["%s stopped following you."], sender)
    SocialQuest:Print(msg)
    displayBanner(msg, "follow")
end
```

- [ ] **Step 3: Add `TestFollowNotification` function**

Add after `TestFlightDiscovery` (currently ending around line 666), before the `WhisperFriends helpers` section:

```lua
function SocialQuestAnnounce:TestFollowNotification()
    local msg = string.format(L["%s started following you."], "TestPlayer")
    displayBanner(msg, "follow")
end
```

- [ ] **Step 4: Commit**

```
git add Core/Announcements.lua
git commit -m "feat: display banner on follow/unfollow; add TestFollowNotification"
```

---

### Task 3: Add debug button to Options.lua

**Files:**
- Modify: `UI/Options.lua` (debug test buttons group, after `testFlightDiscovery`)

- [ ] **Step 1: Add `testFollowNotification` execute button**

In `UI/Options.lua`, inside the `testBanners.args` table, add after the closing `}` of `testFlightDiscovery`:

```lua
                            testFollowNotification = {
                                type   = "execute",
                                name   = L["Test Follow Notification"],
                                desc   = L["Display a demo follow notification banner showing the 'started following you' message."],
                                func   = function() SocialQuestAnnounce:TestFollowNotification() end,
                            },
```

- [ ] **Step 2: Commit**

```
git add UI/Options.lua
git commit -m "feat: add Test Follow Notification button to debug panel"
```

---

### Task 4: Add locale keys to enUS.lua

**Files:**
- Modify: `Locales/enUS.lua`

- [ ] **Step 1: Add the two new keys**

In `Locales/enUS.lua`, add at the end of the file (after the `Test Flight Discovery` block):

```lua
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = true
L["Display a demo follow notification banner showing the 'started following you' message."] = true
```

- [ ] **Step 2: Commit**

```
git add Locales/enUS.lua
git commit -m "locale: add follow notification test button keys to enUS"
```

---

### Task 5: Add locale keys to all non-English locale files

**Files:**
- Modify: `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`, `Locales/esMX.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`, `Locales/koKR.lua`, `Locales/ruRU.lua`, `Locales/jaJP.lua`

AceLocale falls back to the enUS key string when a translation is missing, so these are placeholders for future translators. Add the same block to all 11 files at the end of their test banner sections (after their `Test Flight Discovery` entry).

- [ ] **Step 1: Add to each non-English locale file**

The block to append to each file (after the `Test Flight Discovery` lines):

```lua
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."
```

Do this for all 11 files: `deDE`, `frFR`, `esES`, `esMX`, `zhCN`, `zhTW`, `ptBR`, `itIT`, `koKR`, `ruRU`, `jaJP`.

- [ ] **Step 2: Commit**

```
git add Locales/
git commit -m "locale: add follow notification test button keys to all non-English locales (English placeholder)"
```

---

### Task 6: Version bump and CLAUDE.md update

**Files:**
- Modify: `SocialQuest.toc:5`
- Modify: `CLAUDE.md` (Version History section)

This is the first functional change on 2026-03-22, so minor version increments and revision resets: **2.3.7 → 2.4.0**.

- [ ] **Step 1: Bump version in SocialQuest.toc**

Change line 5:
```
## Version: 2.4.0
```

- [ ] **Step 2: Add version history entry in CLAUDE.md**

Add before the existing `### Version 2.3.7` entry:

```markdown
### Version 2.4.0 (March 2026 — Improvements branch)
- Follow banner notifications: `OnFollowStart` and `OnFollowStop` now display a banner in addition to the existing chat message. Uses new `follow` color key (warm tan normal / Okabe-Ito yellow colorblind). Added `TestFollowNotification` debug function and corresponding debug panel button.
```

- [ ] **Step 3: Commit**

```
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump version to 2.4.0"
```
