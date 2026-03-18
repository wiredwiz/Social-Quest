# Fix: AQL:IsQuestObjectiveText Timing — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `AQL:IsQuestObjectiveText` so it correctly identifies objective progress messages even when the AQL cache still holds the previous count.

**Architecture:** The current exact-match `obj.text == msg` fails because `UI_INFO_MESSAGE` fires before AQL rebuilds its cache — the cache has the old count, the message has the new count. The fix extracts the base description from `msg` once using a greedy Lua pattern, then checks each cached objective with a plain `string.sub` prefix comparison (no regex per objective). The pattern and prefix length are computed outside the loop.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AbsoluteQuestLog-1.0. No test runner — verification is by reading the edited file and in-game testing.

---

## Chunk 1: Replace `AQL:IsQuestObjectiveText`

### Task 1: Update `AQL:IsQuestObjectiveText` in AbsoluteQuestLog.lua

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/AbsoluteQuestLog.lua:184-199`

- [ ] **Step 1: Read the current method to confirm line numbers**

  Read `D:/Projects/Wow Addons/Absolute-Quest-Log/AbsoluteQuestLog.lua` lines 183–201.

  Expected: the comment block starts at line 184, `function AQL:IsQuestObjectiveText(msg)` is at line 188, closing `end` is at line 199, and `function AQL:TrackQuest` follows at line 205.

- [ ] **Step 2: Replace the method**

  Replace the comment block and function body (lines 184–199) with the following:

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

- [ ] **Step 3: Verify the edit**

  Read `D:/Projects/Wow Addons/Absolute-Quest-Log/AbsoluteQuestLog.lua` lines 183–210. Confirm:
  - The new comment block is present and describes base-name matching
  - `msgBase = msg:match("^(.+):%s*%d+/%d+$")` is on the first line of the function body
  - `local baseLen = #msgBase` follows
  - The inner loop uses `obj.text:sub(1, baseLen) == msgBase` (no `obj.text:match` inside the loop)
  - `function AQL:TrackQuest` follows immediately after the closing `end`
  - Indentation is 4-space throughout, consistent with surrounding code

- [ ] **Step 4: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" add AbsoluteQuestLog.lua
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" commit -m "fix: use base-name prefix match in IsQuestObjectiveText to handle stale cache counts"
  ```

  Expected: 1 file changed, ~10 insertions, ~5 deletions.

---

## In-Game Verification

1. Accept a quest with a kill or collection objective.
2. Enable `displayOwn` and `Objective Progress` in SocialQuest settings.
3. Kill a mob that advances the objective.
4. Confirm: SocialQuest's own banner appears; the native WoW floating text does **not**.
5. Disable `Objective Progress` in settings.
6. Kill another mob.
7. Confirm: the native WoW floating text **does** appear (suppression correctly off).
8. Receive in-game mail ("You have new mail" `UI_INFO_MESSAGE`).
9. Confirm: that message appears normally.
