# Bug Fixes: UIErrorsFrame Suppression and AQL Zone Collapse — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two independent bugs: (1) suppress the native WoW objective-progress floating text when SocialQuest's own banner is active, and (2) prevent false AQL_QUEST_ABANDONED/ACCEPTED events when the player collapses or expands zone headers in the WoW quest log.

**Architecture:** Bug 1 is fixed by intercepting `UI_INFO_MESSAGE` events on `UIErrorsFrame` using `GetScript`/`SetScript`, delegating objective text identification to a new AQL public method `IsQuestObjectiveText`. Bug 2 is fixed by wrapping `QuestCache:Rebuild()` in an expand-all-collapsed-headers → full rebuild → re-collapse-them pass, ensuring the cache is always built from the fully-visible quest log regardless of zone collapse state.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AbsoluteQuestLog-1.0 (LibStub), AceAddon-3.0. No test runner — verification is by reading edited files and manual in-game testing.

---

## Chunk 1: AQL Changes

### Task 1: Add `AQL:IsQuestObjectiveText` to AbsoluteQuestLog.lua

**Files:**
- Modify: `Absolute-Quest-Log/AbsoluteQuestLog.lua:182` (insert after line 182)

- [ ] **Step 1: Read the insertion site**

  Read `Absolute-Quest-Log/AbsoluteQuestLog.lua` lines 175–190 to confirm `AQL:GetQuestObjectives` ends at line 182 and the blank line at 183 is the insertion point.

  Expected: line 182 is `end`, line 183 is blank.

- [ ] **Step 2: Insert `AQL:IsQuestObjectiveText` after line 182**

  Insert the following block between line 182 (`end` of `GetQuestObjectives`) and line 184 (the next method comment):

  ```lua

  -- Returns true if msg exactly matches the text of any objective in the active quest
  -- cache. Used by SocialQuest to identify UI_INFO_MESSAGE events that duplicate its
  -- own objective-progress banner. Reads from the live quest cache; the cache is always
  -- complete because QuestCache:Rebuild() expands collapsed zones before reading.
  function AQL:IsQuestObjectiveText(msg)
      if not msg then return false end
      if not self.QuestCache then return false end
      for _, quest in pairs(self.QuestCache.data) do
          if quest.objectives then
              for _, obj in ipairs(quest.objectives) do
                  if obj.text == msg then return true end
              end
          end
      end
      return false
  end
  ```

- [ ] **Step 3: Verify the edit**

  Read `Absolute-Quest-Log/AbsoluteQuestLog.lua` lines 178–205. Confirm:
  - `GetQuestObjectives` ends at its original line
  - The new `IsQuestObjectiveText` function follows immediately
  - Indentation matches surrounding code (4-space)
  - No surrounding code was displaced or corrupted

- [ ] **Step 4: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" add AbsoluteQuestLog.lua
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" commit -m "feat: add AQL:IsQuestObjectiveText for UI_INFO_MESSAGE suppression"
  ```

  Expected: 1 file changed, ~16 lines inserted.

---

### Task 2: Replace `QuestCache:Rebuild()` with expand-rebuild-collapse

**Files:**
- Modify: `Absolute-Quest-Log/Core/QuestCache.lua:18-66` (replace entire `Rebuild` body)

- [ ] **Step 1: Read the current `Rebuild` function**

  Read `Absolute-Quest-Log/Core/QuestCache.lua` lines 16–67 to confirm the function signature is `function QuestCache:Rebuild()` at line 18 and the closing `end` is at line 66, followed by a blank line and `_buildEntry` at line 68.

- [ ] **Step 2: Replace `QuestCache:Rebuild()`**

  Replace the entire function (lines 18–66) with the expand-rebuild-collapse implementation:

  ```lua
  function QuestCache:Rebuild()
      local new = {}
      local currentZone = nil
      local logIndexByQuestID = {}
      local originalSelection = GetQuestLogSelection()

      -- Phase 1: Collect collapsed zone headers.
      local collapsedHeaders = {}
      local numEntries = GetNumQuestLogEntries()
      for i = 1, numEntries do
          local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
          if title and isHeader and isCollapsed then
              table.insert(collapsedHeaders, { index = i, title = title })
          end
      end

      -- Phase 2: Expand collapsed headers back-to-front to preserve earlier indices.
      for k = #collapsedHeaders, 1, -1 do
          ExpandQuestHeader(collapsedHeaders[k].index)
      end

      -- Phase 3: Full rebuild — all quests now visible.
      numEntries = GetNumQuestLogEntries()
      for i = 1, numEntries do
          -- TBC 20505: C_QuestLog.GetInfo() does not exist; use GetQuestLogTitle() global.
          -- Returns: title, level, suggestedGroup, isHeader, isCollapsed, isComplete,
          --          frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI,
          --          isTask, isBounty, isStory, isHidden, isScaling
          local title, level, suggestedGroup, isHeader, _, isComplete, _, questID =
              GetQuestLogTitle(i)
          if title then
              local info = {
                  title          = title,
                  level          = level,
                  suggestedGroup = suggestedGroup,  -- nil-safe: _buildEntry applies or 0 fallback
                  isHeader       = isHeader,
                  isComplete     = isComplete,
                  questID        = questID,
              }
              if info.isHeader then
                  currentZone = info.title
              else
                  logIndexByQuestID[questID] = i
                  -- Wrap each entry build in pcall so one bad entry never aborts the loop.
                  local ok, entryOrErr = pcall(self._buildEntry, self, questID, info, currentZone, i)
                  if ok and entryOrErr then
                      new[questID] = entryOrErr
                  elseif not ok and AQL.debug then
                      print(AQL.RED .. "[AQL] QuestCache: error building entry for questID "
                          .. tostring(questID) .. ": " .. tostring(entryOrErr) .. AQL.RESET)
                  end
              end
          end
      end

      -- Phase 4: Re-collapse headers that were collapsed before rebuild.
      if #collapsedHeaders > 0 then
          local collapsedTitles = {}
          for _, h in ipairs(collapsedHeaders) do
              collapsedTitles[h.title] = true
          end
          local toCollapse = {}
          numEntries = GetNumQuestLogEntries()
          for i = 1, numEntries do
              local title, _, _, isHeader = GetQuestLogTitle(i)
              if title and isHeader and collapsedTitles[title] then
                  table.insert(toCollapse, i)
              end
          end
          -- Collapse back-to-front to preserve earlier indices.
          for k = #toCollapse, 1, -1 do
              CollapseQuestHeader(toCollapse[k])
          end
      end

      -- Phase 5: Restore quest log selection.
      SelectQuestLogEntry(originalSelection or 0)

      local old = self.data
      self.data = new
      return old
  end
  ```

- [ ] **Step 3: Verify the edit**

  Read `Absolute-Quest-Log/Core/QuestCache.lua` lines 16–90. Confirm:
  - `function QuestCache:Rebuild()` opens at line 18 (unchanged)
  - Phase 1–5 comments are present
  - `function QuestCache:_buildEntry` follows immediately after the new `end`
  - The original API comment block (lines 32–35 in the old file) is preserved inside Phase 3
  - No content from `_buildEntry` was accidentally overwritten

- [ ] **Step 4: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" add Core/QuestCache.lua
  git -C "D:/Projects/Wow Addons/Absolute-Quest-Log" commit -m "fix: expand collapsed zone headers before cache rebuild to prevent false AQL_QUEST_ABANDONED events"
  ```

  Expected: 1 file changed, net ~50 lines added (new phases replace the compact original loop).

---

## Chunk 2: SocialQuest Changes

### Task 3: Update `Core/Announcements.lua` — remove `UpdateQuestWatchSuppression`, rewrite `InitEventHooks`

**Files:**
- Modify: `Social-Quest/Core/Announcements.lua:470-502`

- [ ] **Step 1: Read the target block**

  Read `Social-Quest/Core/Announcements.lua` lines 468–504. Confirm:
  - `UpdateQuestWatchSuppression` spans lines 470–480
  - The comment block for `InitEventHooks` starts at line 482
  - `InitEventHooks` function spans lines 488–502
  - Line 504 begins `-- Debug test entry point` (nothing between should be deleted)

- [ ] **Step 2: Remove `UpdateQuestWatchSuppression` and replace `InitEventHooks`**

  Replace the block from the start of `UpdateQuestWatchSuppression` through the end of `InitEventHooks` (lines 470–502) with only the new `InitEventHooks`:

  ```lua
  -- Intercept UIErrorsFrame's OnEvent to suppress the native WoW objective-progress
  -- floating text when SocialQuest's own banner is active. In TBC Classic (20505),
  -- quest objective progress notifications arrive via UI_INFO_MESSAGE, not
  -- QUEST_WATCH_UPDATE. We use GetScript/SetScript so the hook chains correctly to any
  -- other addon that installed its own OnEvent before us.
  -- Called once from SocialQuest:OnInitialize().
  function SocialQuestAnnounce:InitEventHooks()
      local orig = UIErrorsFrame:GetScript("OnEvent")
      if not orig then return end
      UIErrorsFrame:SetScript("OnEvent", function(self, event, messageType, msg, ...)
          if event == "UI_INFO_MESSAGE" then
              local db = SocialQuest.db.profile
              local AQL = SocialQuest.AQL
              if db and db.enabled
                      and db.general.displayOwn
                      and db.general.displayOwnEvents.objective_progress
                      and AQL and AQL:IsQuestObjectiveText(msg) then
                  return
              end
          end
          return orig(self, event, messageType, msg, ...)
      end)
  end
  ```

- [ ] **Step 3: Verify the edit**

  Read `Social-Quest/Core/Announcements.lua` lines 465–515. Confirm:
  - `UpdateQuestWatchSuppression` is gone entirely
  - New `InitEventHooks` comment block and function are present
  - The function intercepts `UI_INFO_MESSAGE` (not `QUEST_WATCH_UPDATE`)
  - `messageType` and `msg` are named params (not packed into `...`)
  - `-- Debug test entry point` section follows immediately after the new function's `end`
  - No accidental deletion of surrounding code

- [ ] **Step 4: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Social-Quest" add Core/Announcements.lua
  git -C "D:/Projects/Wow Addons/Social-Quest" commit -m "fix: suppress UI_INFO_MESSAGE objective progress via AQL:IsQuestObjectiveText; remove UpdateQuestWatchSuppression"
  ```

  Expected: 1 file changed, net negative lines (old 33-line block replaced by ~21-line block).

---

### Task 4: Update `SocialQuest.lua` — remove two stale lines

**Files:**
- Modify: `Social-Quest/SocialQuest.lua:101` and `Social-Quest/SocialQuest.lua:119`

- [ ] **Step 1: Read the target lines**

  Read `Social-Quest/SocialQuest.lua` lines 96–122. Confirm:
  - Line 101 is `    SocialQuestAnnounce:UpdateQuestWatchSuppression()` inside `OnEnable`
  - Line 119 is `    UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")` inside `OnDisable`
  - Line 118 is the comment `-- Always re-register on disable regardless of settings.`

- [ ] **Step 2: Remove line 101 (`UpdateQuestWatchSuppression()` call in `OnEnable`)**

  Delete the line `    SocialQuestAnnounce:UpdateQuestWatchSuppression()` from `OnEnable`.

- [ ] **Step 3: Remove lines 118–119 (comment + `RegisterEvent` call in `OnDisable`)**

  Delete both the comment `-- Always re-register on disable regardless of settings.` and the line `UIErrorsFrame:RegisterEvent("QUEST_WATCH_UPDATE")` from `OnDisable`.

- [ ] **Step 4: Verify the edit**

  Read `Social-Quest/SocialQuest.lua` lines 96–122. Confirm:
  - `OnEnable` no longer contains any `UpdateQuestWatchSuppression` call
  - `OnDisable` contains only the AQL `UnregisterCallback` calls; the `UIErrorsFrame:RegisterEvent` line and its comment are gone
  - `OnDisable` closing `end` is intact

- [ ] **Step 5: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Social-Quest" add SocialQuest.lua
  git -C "D:/Projects/Wow Addons/Social-Quest" commit -m "fix: remove stale UpdateQuestWatchSuppression and UIErrorsFrame RegisterEvent calls"
  ```

  Expected: 1 file changed, 3 lines deleted.

---

### Task 5: Update `UI/Options.lua` — remove three stale call sites

**Files:**
- Modify: `Social-Quest/UI/Options.lua:96`, `:158`, `:175`

- [ ] **Step 1: Read the three call sites**

  Read `Social-Quest/UI/Options.lua` lines 88–180. Confirm the three `UpdateQuestWatchSuppression()` calls:
  - Line 96: in the `objective_progress` setter inside `ownDisplayEventsGroup()`
  - Line 158: in the `enabled` toggle setter inside the `general` options group
  - Line 175: in the `displayOwn` toggle setter inside the `general` options group

- [ ] **Step 2: Remove the call at line 96 (objective_progress setter)**

  In the `objective_progress` setter, remove the line `SocialQuestAnnounce:UpdateQuestWatchSuppression()`. The setter body should become just:
  ```lua
  set  = function(info, value)
      db.general.displayOwnEvents.objective_progress = value
  end,
  ```

- [ ] **Step 3: Remove the call at line 158 (enabled setter)**

  In the `enabled` toggle setter, remove the line `SocialQuestAnnounce:UpdateQuestWatchSuppression()`. The setter body should become just:
  ```lua
  set   = function(info, value)
      db.enabled = value
  end,
  ```

- [ ] **Step 4: Remove the call at line 175 (displayOwn setter)**

  In the `displayOwn` toggle setter, remove the line `SocialQuestAnnounce:UpdateQuestWatchSuppression()`. The setter body should become just:
  ```lua
  set   = function(info, value)
      db.general.displayOwn = value
  end,
  ```

- [ ] **Step 5: Verify the edit**

  Read `Social-Quest/UI/Options.lua` lines 88–180. Confirm:
  - All three `UpdateQuestWatchSuppression()` calls are gone
  - Each setter still sets its db value correctly
  - No other lines were accidentally modified

- [ ] **Step 6: Commit**

  ```bash
  git -C "D:/Projects/Wow Addons/Social-Quest" add UI/Options.lua
  git -C "D:/Projects/Wow Addons/Social-Quest" commit -m "fix: remove stale UpdateQuestWatchSuppression calls from Options setters"
  ```

  Expected: 1 file changed, 3 lines deleted.

---

## In-Game Verification

After all commits, verify in WoW TBC Anniversary client:

### Bug 1 — UIErrorsFrame Suppression

1. Enable `displayOwn` and `Objective Progress` in SocialQuest settings.
2. Kill a mob that advances a quest objective.
3. Confirm: SocialQuest's own banner appears; the native WoW floating text does NOT.
4. Disable either `displayOwn` or `Objective Progress` in settings.
5. Kill another mob.
6. Confirm: the native WoW floating text appears (suppression correctly disabled).
7. Check "New mail" or another non-objective `UI_INFO_MESSAGE`: confirm it still appears.

### Bug 2 — AQL Zone Collapse/Expand

1. Accept two or more quests in the same zone.
2. Collapse that zone's header in the quest log.
3. Confirm: no "Quest abandoned" messages appear in chat or banners.
4. Expand the zone header.
5. Confirm: no "Quest accepted" messages appear.
6. Abandon one of those quests normally (right-click → Abandon) while the zone is expanded.
7. Confirm: the abandoned message DOES appear (genuine abandonment still works).
8. With a zone collapsed, progress an objective for a quest in that zone.
9. Expand the zone; confirm AQL correctly reflects the updated objective state.
