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

Replace the exact-match `obj.text == msg` in `AQL:IsQuestObjectiveText` with a
**base-name match** that strips the `": X/Y"` count suffix from both sides before
comparing. Because the objective description (everything before the last colon and
count) is the same regardless of which frame the count is at, the timing of the cache
rebuild no longer matters.

### `obj.text` Source

`obj.text` in the cache comes from `C_QuestLog.GetQuestObjectives(questID)` via
`QuestCache:_buildEntry`. The raw API value is normalised through a `local text =
obj.text or ""` intermediate, so the cache field is always a string, never `nil`.
For a kill objective it contains text like `"Tainted Ooze killed: 4/10"`. No further
transformation is applied to `obj.text`; only the separate `obj.name` field is
pre-stripped. `IsQuestObjectiveText` reads `obj.text` directly.

### Pattern

```lua
msg:match("^(.+):%s*%d+/%d+$")
```

- `(.+)` is **greedy**, so it matches up to the *last* colon — correctly handles
  objective names that contain colons (e.g.
  `"Protect Captain Skarloc: Phase 2: 0/1"` → base = `"Protect Captain Skarloc: Phase 2"`).
  A non-greedy `(.-)` (used by `_buildEntry` to build `obj.name` via the pattern
  `"^(.-):%s*%d+/%d+%s*$"`) would stop at the first colon and produce the wrong base
  for such names; `IsQuestObjectiveText` must use greedy to be consistent with
  `UI_INFO_MESSAGE` text, which carries the full objective description through the
  last colon.
- If `msg` does not end in `": X/Y"` format, `match` returns `nil` and the function
  returns `false` immediately — non-count info messages pass through unchanged.
- The same extraction is applied to `obj.text` before comparison, so a cache entry
  of `"Mosshide Mongrel slain: 0/10"` produces the same base as a message of
  `"Mosshide Mongrel slain: 1/10"`.

### Updated `AQL:IsQuestObjectiveText`

The updated method replaces the existing body in
`Absolute-Quest-Log/AbsoluteQuestLog.lua`. `self.QuestCache.data` is accessed
directly, consistent with all other internal cache reads in AQL.

```lua
-- Returns true if msg matches the base name (description without ": X/Y" count)
-- of any objective in the active quest cache. Strips the count suffix before
-- comparing so that a stale cache (previous count) still matches an incoming
-- UI_INFO_MESSAGE (new count). Used by SocialQuest to identify UI_INFO_MESSAGE
-- events that duplicate its own objective-progress banner. Reads from the live
-- quest cache; the cache is always complete because QuestCache:Rebuild() expands
-- collapsed zones before reading.
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

- Non-count `UI_INFO_MESSAGE` events (e.g. "You have new mail", "You are now rested")
  have no `": X/Y"` suffix, so `msgBase` is `nil` and the function returns `false`
  immediately without touching the cache.
- A `UI_INFO_MESSAGE` arriving before `QUEST_LOG_UPDATE` updates the cache still
  matches because the base name is count-independent.
- Count-format messages that do not match any cached objective pass through unchanged
  — the cache scan finds no base-name match.
- If `obj.text` has no count suffix (e.g. a completion-type objective like
  "Speak with the Elder"), `obj.text:match(...)` returns `nil` and the fallback
  `or obj.text` keeps the full text for comparison. Because `msgBase` is guaranteed
  non-nil (the early return on line 4 of the function guards this), and full raw text
  will never equal a stripped base name, no spurious match is possible.
- The `if obj.text then` guard is defensive courtesy; as noted above, the cache field
  is always a string. It costs nothing and protects against hypothetical future cache
  changes.

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
