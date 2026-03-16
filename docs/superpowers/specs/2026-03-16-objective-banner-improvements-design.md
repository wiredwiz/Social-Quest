# Objective Banner Improvements — Design Spec

## Overview

Two independent improvements to Social Quest's objective progress banners, implemented
and committed separately for ease of debugging.

---

## Feature 1: Show Objective Text in Banners

### Problem

`formatObjectiveBannerMsg` displays the quest title where it should display the
objective text. Both own-player and remote-player banners are affected:

- **Current:** `"You progressed: A Daunting Task (3/5)"`
- **Desired:** `"You progressed: A Daunting Task — Kobolds Slain (3/5)"`

### Root Cause

`formatObjectiveBannerMsg` has no `objText` parameter. The three format strings all
use `questTitle` in the position meant for the objective description. For own banners,
`objective.text` is available in `OnOwnObjectiveEvent` but never passed to the
formatter. For remote banners, `objIndex` is already transmitted in the `SQ_OBJECTIVE`
payload and already parsed by `OnObjectiveReceived`, but never forwarded to
`OnRemoteObjectiveEvent` or used to look up the text from AQL.

### Design

**`formatObjectiveBannerMsg` signature change:**

```lua
-- Before
local function formatObjectiveBannerMsg(sender, questTitle, numFulfilled, numRequired, isComplete, isRegression)

-- After
local function formatObjectiveBannerMsg(sender, questTitle, objText, numFulfilled, numRequired, isComplete, isRegression)
```

**New format strings (all three cases):**

```lua
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
```

Note: `—` (em dash, U+2014) is encoded as the literal UTF-8 character in all Lua
strings since TBC Classic Lua 5.1 does not support `\xNN` hex escapes.

**`OnOwnObjectiveEvent` — pass `objective.text`:**

```lua
local msg = formatObjectiveBannerMsg(
    L["You"], questInfo.title,
    objective.text or "",          -- ← new
    objective.numFulfilled, objective.numRequired,
    eventType == "objective_complete", isRegression)
```

**`OnRemoteObjectiveEvent` — add `objIndex` parameter, look up text:**

```lua
-- Before
function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, numFulfilled, numRequired, isComplete, isRegression)

-- After
function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, objIndex, numFulfilled, numRequired, isComplete, isRegression)
```

Objective text and title lookup inside `OnRemoteObjectiveEvent`:

```lua
local AQL     = SocialQuest.AQL
local objs    = AQL and AQL:GetQuestObjectives(questID)
local objInfo = objs and objs[objIndex]
local objText = (objInfo and objInfo.text) or ""
local title   = (AQL and AQL:GetQuestTitle(questID))
             or ("Quest " .. questID)
```

`AQL:GetQuestObjectives(questID)` checks the AQL cache first, then falls back to
`C_QuestLog.GetQuestObjectives(questID)`. That WoW API only returns data for quests
in the player's active log, so `objText` is `""` when the local player doesn't have
the quest. The format string then renders as
`"PlayerName progressed: Quest Title —  (3/5)"`, which is acceptable.

`AQL:GetQuestTitle(questID)` uses three-tier resolution (cache → WoW log scan →
`C_QuestLog.GetQuestInfo(questID)`). The third tier returns a title string for any
known questID even when the quest is not in the player's log, so the "Quest N" numeric
fallback is only reached if the provider has no data for that questID.

Note: the existing `OnRemoteObjectiveEvent` code uses `AQL:GetQuestLink(questID)` as
its first-tier title lookup (which returns a hyperlink string). This is intentionally
dropped here in favour of `AQL:GetQuestTitle(questID)` — `RaidNotice_AddMessage` does
not parse hyperlinks, so a plain title string is correct for banner display.

**`GroupData:OnObjectiveReceived` — forward `objIndex`:**

```lua
SocialQuestAnnounce:OnRemoteObjectiveEvent(
    sender, payload.questID,
    payload.objIndex,              -- ← new
    payload.numFulfilled, payload.numRequired,
    isComplete, isRegression)
```

**Locale key changes:**

The three format string keys change in all 12 locale files. The old keys are removed;
new keys are added with the em dash.

Old keys (removed from all files):
```lua
L["%s completed objective: %s (%d/%d)"]
L["%s regressed: %s (%d/%d)"]
L["%s progressed: %s (%d/%d)"]
```

New keys (enUS — `true` fallback; non-English files translate the new strings):
```lua
L["%s completed objective: %s — %s (%d/%d)"] = true
L["%s regressed: %s — %s (%d/%d)"]           = true
L["%s progressed: %s — %s (%d/%d)"]          = true
```

For all non-English locales, replace the old key assignments with new ones using the
same translated phrasing but the added em dash and extra `%s` slot.

**`TEST_DEMOS` update:**

The hardcoded banner strings in `TEST_DEMOS` inside `Announcements.lua` should be
updated to match the new format:

```lua
objective_progress = {
    banner = "TestPlayer progressed: [A Daunting Task] — Kobolds Slain (3/8)",
    ...
},
objective_complete = {
    banner = "TestPlayer completed objective: [A Daunting Task] — Kobolds Slain (8/8)",
    ...
},
objective_regression = {
    banner = "TestPlayer regressed: [A Daunting Task] — Kobolds Slain (2/8)",
    ...
},
```

### Files Changed (Feature 1)

| File | Change |
|------|--------|
| `Core/Announcements.lua` | `formatObjectiveBannerMsg` signature + format strings; `OnOwnObjectiveEvent` passes `objective.text`; `OnRemoteObjectiveEvent` adds `objIndex` param and text lookup; `TEST_DEMOS` updated |
| `Core/GroupData.lua` | `OnObjectiveReceived` forwards `payload.objIndex` |
| `Locales/enUS.lua` | 3 keys replaced |
| `Locales/deDE.lua` through `Locales/jaJP.lua` (11 files) | 3 keys replaced with translated equivalents |

---

## Feature 2: Suppress Default WoW Objective Progress Banner

### Problem

When Social Quest's own objective progress banner is enabled for the local player's
quests, the default WoW client also shows a smaller, faster-fading notification for
the same event via `UIErrorsFrame`. The user sees two notifications for the same
event, with mismatched sizes and fade rates.

### Design

**Suppression function in `Core/Announcements.lua`:**

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

Suppression is active when all three conditions are true:
1. `db.enabled` — addon is enabled
2. `db.general.displayOwn` — own-event banners are on
3. `db.general.displayOwnEvents.objective_progress` — objective progress banner specifically is on

`objective_complete` is intentionally excluded: TBC Classic has no separate
"objective complete" UI notification distinct from `QUEST_WATCH_UPDATE`. Both partial
progress and the final completion step go through the same event, so suppressing on
`objective_progress` alone is sufficient.

**Call sites in `SocialQuest.lua`:**

```lua
function SocialQuest:OnEnable()
    ...
    SocialQuestAnnounce:UpdateQuestWatchSuppression()
end

function SocialQuest:OnDisable()
    ...
    -- Always re-register on disable regardless of settings.
    UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")
end
```

**`UI/Options.lua` — `set` callbacks for affected options:**

Three options affect the suppression state. Each needs an explicit `set` callback that
writes the value and then calls `UpdateQuestWatchSuppression`. Currently all three use
the generic `toggle()` helper which only writes to the db — they do not trigger any
suppression update.

```lua
-- enabled (master toggle)
set = function(info, value)
    SocialQuest.db.profile.enabled = value
    SocialQuestAnnounce:UpdateQuestWatchSuppression()
end,

-- general.displayOwn
set = function(info, value)
    SocialQuest.db.profile.general.displayOwn = value
    SocialQuestAnnounce:UpdateQuestWatchSuppression()
end,

-- general.displayOwnEvents.objective_progress
set = function(info, value)
    SocialQuest.db.profile.general.displayOwnEvents.objective_progress = value
    SocialQuestAnnounce:UpdateQuestWatchSuppression()
end,
```

Note: `SocialQuest:OnEnable` / `OnDisable` are AceAddon lifecycle hooks, not wired to
the options panel `enabled` toggle. The `enabled` toggle must have its own explicit
`set` callback so that disabling the addon via the options panel always re-registers
`UIErrorsFrame` for `QUEST_WATCH_UPDATE`.

### Safety Note

If Social Quest encounters an error after unregistering `UIErrorsFrame` from
`QUEST_WATCH_UPDATE` but before `OnDisable` can re-register it, objective notifications
from the default UI will not show for the remainder of the session. A `/reload`
restores normal behavior. This is an accepted tradeoff in exchange for a clean,
state-free implementation.

### Files Changed (Feature 2)

| File | Change |
|------|--------|
| `Core/Announcements.lua` | Add `UpdateQuestWatchSuppression` function |
| `SocialQuest.lua` | Call `UpdateQuestWatchSuppression` from `OnEnable`; call `RegisterEvent` directly in `OnDisable` |
| `UI/Options.lua` | Add explicit `set` callbacks to `enabled`, `general.displayOwn`, and `general.displayOwnEvents.objective_progress` |

---

## Testing

**Feature 1:**
1. Accept a multi-objective quest or a collection quest.
2. Progress one objective (kill a mob, collect an item).
3. Confirm the Social Quest banner shows `"You progressed: Quest Title — Objective Text (n/req)"`.
4. In a group with another Social Quest user, confirm their banner also shows objective text.
5. For a quest a remote player has that you don't, confirm the remote banner degrades gracefully — shows `"PlayerName progressed: Quest Title —  (3/5)"` (empty objective text with em dash) without crashing.

**Feature 2:**
1. Enable `displayOwn` and `objective_progress` in Social Quest settings.
2. Progress a quest objective.
3. Confirm only the Social Quest banner appears — no smaller default WoW notification.
4. Disable `objective_progress` in Social Quest settings.
5. Confirm the default WoW notification reappears.
6. Re-enable, verify suppression is back.
7. `/reload` — confirm suppression state matches current settings.
8. While suppression is active, disable SocialQuest via the options panel master toggle — confirm the default WoW notification reappears immediately (no `/reload` needed).
