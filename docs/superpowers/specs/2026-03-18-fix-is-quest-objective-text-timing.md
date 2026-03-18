# Fix: AQL:IsQuestObjectiveText Timing — Design Spec

## Overview

`AQL:IsQuestObjectiveText(msg)` always returns `false` for valid objective progress
messages, so SocialQuest's `InitEventHooks` suppressor never fires and the native
WoW objective-progress floating text appears alongside SocialQuest's own banner.

---

## Root Cause

`UI_INFO_MESSAGE` fires **before** AQL has processed `QUEST_LOG_UPDATE` and rebuilt
its cache. At hook time the cache still holds the previous count (e.g. `0/10`), but
`msg` already carries the new count (e.g. `1/10`). The current exact-match check
`obj.text == msg` therefore never succeeds.

Confirmed by in-game diagnostic:
- `msg` captured inside the hook: `"Mosshide Mongrel slain: 1/10"`
- Cache state at that instant: `obj.text = "Mosshide Mongrel slain: 0/10"` (stale)
- `AQL:IsQuestObjectiveText(msg)` at that instant: `false`
- Cache dump immediately afterward: `obj.text = "Mosshide Mongrel slain: 1/10"` (updated by then)

The event ordering is `UI_INFO_MESSAGE` → `QUEST_LOG_UPDATE`. The hook always sees
the count from the previous rebuild.

---

## Fix

Replace the exact-match `obj.text == msg` with a **prefix match**: extract the
base name from `msg` once (stripping the `": X/Y"` count suffix), then check whether
each cached `obj.text` starts with that base. No pattern matching is needed inside
the loop — only a single `string.sub` comparison per objective.

### `obj.text` Source

`obj.text` in the cache comes from `C_QuestLog.GetQuestObjectives(questID)` via
`QuestCache:_buildEntry`. The raw API value is normalised through a `local text =
obj.text or ""` intermediate, so the cache field is always a string, never `nil`.
For a kill objective it contains text like `"Tainted Ooze killed: 4/10"`. No further
transformation is applied to `obj.text`; only the separate `obj.name` field is
pre-stripped. `IsQuestObjectiveText` reads `obj.text` directly.

### Pattern (applied once, outside the loop)

```lua
msg:match("^(.+):%s*%d+/%d+$")
```

- `(.+)` is **greedy**, so it matches up to the *last* colon — correctly handles
  objective names that contain colons (e.g.
  `"Protect Captain Skarloc: Phase 2: 0/1"` → base = `"Protect Captain Skarloc: Phase 2"`).
  A non-greedy `(.-)` (used by `_buildEntry` to build `obj.name` via the pattern
  `"^(.-):%s*%d+/%d+%s*$"`) would stop at the first colon and produce the wrong base
  for such names.
- If `msg` does not end in `": X/Y"` format, `match` returns `nil` and the function
  returns `false` immediately — non-count info messages pass through unchanged.

### Inner loop comparison (no regex)

Inside the loop, `obj.text:sub(1, #msgBase) == msgBase` checks whether `obj.text`
begins with the extracted base. Because `msgBase` is derived from `msg` by stripping
`": X/Y"`, and `obj.text` for the matching quest will begin with the same description
followed by `": X/Y"`, this holds for any count value — including the stale previous
count still in the cache when the event fires.

The theoretical false-positive risk (an objective whose description is a leading
substring of another) is accepted as negligibly small in practice for TBC quest data.

### Updated `AQL:IsQuestObjectiveText`

The updated method replaces the existing body in
`Absolute-Quest-Log/AbsoluteQuestLog.lua`. `self.QuestCache.data` is accessed
directly, consistent with all other internal cache reads in AQL.

```lua
-- Returns true if msg's base name (description without ": X/Y" count) matches
-- the leading text of any objective in the active quest cache. The pattern is
-- applied once to msg; each objective is checked with a plain string.sub
-- comparison so no regex runs inside the loop. A stale cache (previous count)
-- still matches an incoming UI_INFO_MESSAGE (new count) because only the base
-- description is compared. Used by SocialQuest to identify UI_INFO_MESSAGE
-- events that duplicate its own objective-progress banner. Reads from the live
-- quest cache; the cache is always complete because QuestCache:Rebuild() expands
-- collapsed zones before reading.
function AQL:IsQuestObjectiveText(msg)
    if not msg then return false end
    if not self.QuestCache then return false end
    local msgBase = msg:match("^(.+):%s*%d+/%d+$")
    if not msgBase then return false end
    local baseLen = #msgBase
    for _, quest in pairs(self.QuestCache.data) do
        if quest.objectives then
            for _, obj in ipairs(quest.objectives) do
                if obj.text and obj.text:sub(1, baseLen) == msgBase then
                    return true
                end
            end
        end
    end
    return false
end
```

### Invariants

- Non-count `UI_INFO_MESSAGE` events (e.g. "You have new mail", "You are now rested")
  have no `": X/Y"` suffix, so `msgBase` is `nil` and the function returns `false`
  immediately without touching the cache.
- A `UI_INFO_MESSAGE` arriving before `QUEST_LOG_UPDATE` updates the cache still
  matches because only the base description is compared, not the count.
- Count-format messages whose base does not match any cached objective pass through
  unchanged.
- Completion-type objectives with no count (e.g. "Speak with the Elder") cannot
  match a count-format `msg`: `msgBase` is always shorter than `obj.text` for
  count-format objectives, and objectives without counts will never start with a
  count-format base.
- The `if obj.text then` guard is defensive courtesy; the cache field is always a
  string, never `nil`.

---

## Files Changed

| File | Change |
|------|--------|
| `Absolute-Quest-Log/AbsoluteQuestLog.lua` | Replace `AQL:IsQuestObjectiveText` body and update its comment |

No other files change. `InitEventHooks` in `Social-Quest/Core/Announcements.lua` and
all callers remain unchanged.

---

## Testing

1. Accept a quest with a kill or collection objective.
2. Enable `displayOwn` and `Objective Progress` in SocialQuest settings.
3. Kill a mob that advances the objective.
4. Confirm: SocialQuest's own banner appears; the native WoW floating text does **not**.
5. Disable `Objective Progress` in settings.
6. Kill another mob.
7. Confirm: the native WoW floating text **does** appear (suppression off).
8. Receive in-game mail to trigger a `UI_INFO_MESSAGE` ("You have new mail").
9. Confirm: that message appears normally (no suppression of non-objective messages).
