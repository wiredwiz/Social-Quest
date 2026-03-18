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
- `AQL:IsQuestObjectiveText(msg)` at that instant: `false`
- Cache dump immediately afterward: `obj.text = "Mosshide Mongrel slain: 1/10"` (already updated)

This shows the cache was stale when the hook ran and current by the time it was
inspected — the event ordering is `UI_INFO_MESSAGE` → `QUEST_LOG_UPDATE`.

---

## Fix

Replace the exact-match `obj.text == msg` in `AQL:IsQuestObjectiveText` with a
**base-name match** that strips the `": X/Y"` count suffix from both sides before
comparing. Because the objective description (everything before the last colon and
count) is the same regardless of which frame the count is at, the timing of the cache
rebuild no longer matters.

### Pattern

```lua
msg:match("^(.+):%s*%d+/%d+$")
```

- `(.+)` is **greedy**, so it matches up to the *last* colon — correctly handles
  objective names that contain colons (e.g. `"Kill Ner'zhul: Phase 2: 1/1"` →
  base = `"Kill Ner'zhul: Phase 2"`).
- If `msg` does not end in `": X/Y"` format, `match` returns `nil` and the function
  returns `false` immediately — non-count info messages (e.g. "New mail") pass
  through unchanged.
- The same extraction is applied to `obj.text` before comparison, so a cache entry
  of `"Mosshide Mongrel slain: 0/10"` produces the same base as a message of
  `"Mosshide Mongrel slain: 1/10"`.

### Updated `AQL:IsQuestObjectiveText`

```lua
-- Returns true if msg matches the base name of any objective in the active quest
-- cache. Strips the ": X/Y" progress count before comparing so that a stale cache
-- (old count) still matches an incoming UI_INFO_MESSAGE (new count). Used by
-- SocialQuest to identify UI_INFO_MESSAGE events that duplicate its own
-- objective-progress banner.
function AQL:IsQuestObjectiveText(msg)
    if not msg then return false end
    if not self.QuestCache then return false end
    local msgBase = msg:match("^(.+):%s*%d+/%d+$")
    if not msgBase then return false end
    for _, quest in pairs(self.QuestCache.data) do
        if quest.objectives then
            for _, obj in ipairs(quest.objectives) do
                if obj.text then
                    local objBase = obj.text:match("^(.+):%s*%d+/%d+$") or obj.text
                    if objBase == msgBase then return true end
                end
            end
        end
    end
    return false
end
```

### Invariants

- Non-count `UI_INFO_MESSAGE` events (e.g. "New mail", "You are now rested") have no
  `": X/Y"` suffix, so `msgBase` is `nil` and the function returns `false`
  immediately without touching the cache.
- Count-format messages that do not match any cached objective (e.g. a hypothetical
  third-party message ending in `": 2/5"`) pass through unchanged — the cache scan
  finds no base-name match.
- If `obj.text` itself has no count suffix (e.g. a completion-type objective like
  "Speak with the Elder"), `obj.text:match(...)` returns `nil` and the fallback
  `or obj.text` keeps the full text for comparison. Such objectives will never match
  a count-format `msg`, which is correct.

---

## Files Changed

| File | Change |
|------|--------|
| `Absolute-Quest-Log/AbsoluteQuestLog.lua` | Replace `AQL:IsQuestObjectiveText` body with base-name match |

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
8. Trigger a non-objective `UI_INFO_MESSAGE` (e.g. log in/out of a friend to get a
   "X is now online" message, or receive mail).
9. Confirm: that message appears normally (no suppression of non-objective messages).
