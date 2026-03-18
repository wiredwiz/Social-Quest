# Social Quest Quest Linkification — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add left-click-to-open-quest-log on quest title rows and WoW quest hyperlinks in outbound chat announcements.

**Architecture:** Two independent changes. The frame click adds a local `openQuestLogToQuest` helper to `RowFactory.lua` and updates the existing `AddQuestRow` overlay's `OnClick` handler to branch on shift-key. The chat hyperlinks change inserts a `display` variable in `OnQuestEvent` that prefers the WoW hyperlink string from the AQL snapshot over plain title. No new files. No changes to `SocialQuest.lua`.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AceAddon-3.0, AceLocale-3.0. No automated test framework — verification is manual, in-game.

---

## Chunk 1: Both changes

### Task 1: Add openQuestLogToQuest helper and update AddQuestRow click handler

**Files:**
- Modify: `Social-Quest/UI/RowFactory.lua`

**Background:** `AddQuestRow` (line 128) already creates an invisible `Button` overlay over the title FontString when `callbacks.onTitleShiftClick` is provided (that is: always on My Quests tab, never on Party/Shared tabs). The current `OnClick` handler (lines 196–203) only handles shift-click. We extend it to also handle plain left-click by calling `openQuestLogToQuest(questEntry.questID)`.

`openQuestLogToQuest` is a new local helper defined in the "Private helpers" section of `RowFactory.lua`. It opens `QuestLogFrame`, then walks `GetNumQuestLogEntries()` to find the quest, expanding collapsed zone headers one at a time and collapsing them back if the quest is not in them, so only the target zone ends up expanded.

`GetQuestLogTitle(i)` returns 18 values in TBC 20505. The fields we use, by position:
1. `title` (string)
2. `level` (number)
3. `suggestedGroup` (number)
4. `isHeader` (bool)
5. `isCollapsed` (bool)
6–7. (unused)
8. `questID` (number, 0 for zone headers)

We select quests with `QuestLog_SetSelection(i)` (not `SelectQuestLogEntry`) and call `QuestLog_Update()` to refresh the UI. Both are safe to call from addon code.

**Current state — the overlay block (lines 195–204 of `RowFactory.lua`):**

```lua
    -- Invisible click overlay (shift-click to track/untrack).
    if callbacks and callbacks.onTitleShiftClick then
        local titleBtn = CreateFrame("Button", nil, contentFrame)
        titleBtn:SetAllPoints(titleFs)
        titleBtn:SetScript("OnClick", function()
            if IsShiftKeyDown() then
                callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
            end
        end)
    end
```

**Current state — end of private helpers section (lines 38–42 of `RowFactory.lua`):**

```lua
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
```

- [ ] **Step 1: Add openQuestLogToQuest to the private helpers section**

  Open `Social-Quest/UI/RowFactory.lua`. Find the end of the private helpers section (the blank line + separator before `-- Public API`):

  **Find:**
  ```lua
  end

  ------------------------------------------------------------------------
  -- Public API
  ------------------------------------------------------------------------
  ```

  **Replace with:**
  ```lua
  end

  -- Opens the WoW Quest Log and selects the given questID.
  -- Expands collapsed zone headers one at a time to locate the quest,
  -- collapsing them back if the quest is not in them, so only the zone
  -- containing the target quest ends up expanded.
  -- If the quest is not found (stale data), the log is opened but nothing
  -- is selected.
  local function openQuestLogToQuest(questID)
      ShowUIPanel(QuestLogFrame)
      local numEntries = GetNumQuestLogEntries()
      local i = 1
      while i <= numEntries do
          local _, _, _, isHeader, isCollapsed, _, _, id = GetQuestLogTitle(i)
          if isHeader and isCollapsed then
              local headerIdx = i
              ExpandQuestHeader(headerIdx)
              numEntries = GetNumQuestLogEntries()
              local found = false
              i = i + 1
              while i <= numEntries do
                  local _, _, _, subIsHeader, _, _, _, subId = GetQuestLogTitle(i)
                  if subIsHeader then break end
                  if subId == questID then
                      found = true
                      QuestLog_SetSelection(i)
                      QuestLog_Update()
                      return
                  end
                  i = i + 1
              end
              if not found then
                  CollapseQuestHeader(headerIdx)
                  numEntries = GetNumQuestLogEntries()
                  i = headerIdx + 1
              end
          elseif not isHeader and id == questID then
              QuestLog_SetSelection(i)
              QuestLog_Update()
              return
          else
              i = i + 1
          end
      end
  end

  ------------------------------------------------------------------------
  -- Public API
  ------------------------------------------------------------------------
  ```

- [ ] **Step 2: Update the AddQuestRow OnClick handler**

  In the same file, find the overlay block inside `AddQuestRow`:

  **Find:**
  ```lua
      -- Invisible click overlay (shift-click to track/untrack).
      if callbacks and callbacks.onTitleShiftClick then
          local titleBtn = CreateFrame("Button", nil, contentFrame)
          titleBtn:SetAllPoints(titleFs)
          titleBtn:SetScript("OnClick", function()
              if IsShiftKeyDown() then
                  callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
              end
          end)
      end
  ```

  **Replace with:**
  ```lua
      -- Invisible click overlay: left-click opens quest log, shift-click tracks/untracks.
      -- Guard is callbacks.onTitleShiftClick: present on My Quests tab (MineTab), nil on
      -- Party/Shared tabs (those tabs pass {} as callbacks). Party/Shared tab entries can
      -- have a non-nil logIndex when the local player also has the quest, so logIndex > 0
      -- is NOT a safe guard — callbacks.onTitleShiftClick is the authoritative indicator.
      if callbacks and callbacks.onTitleShiftClick then
          local titleBtn = CreateFrame("Button", nil, contentFrame)
          titleBtn:SetAllPoints(titleFs)
          titleBtn:SetScript("OnClick", function()
              if IsShiftKeyDown() then
                  callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
              else
                  openQuestLogToQuest(questEntry.questID)
              end
          end)
      end
  ```

- [ ] **Step 3: Verify the edit**

  Read back `RowFactory.lua` lines 1–125 and confirm:
  - `openQuestLogToQuest` appears as a local function in the private helpers section (after `formatTimeRemaining`, before `-- Public API`)
  - The function body matches the spec exactly (inner/outer loop structure, `CollapseQuestHeader(headerIdx)`, `i = headerIdx + 1`)

  Read back the `AddQuestRow` overlay block (~lines 195–215) and confirm:
  - Comment says "left-click opens quest log, shift-click tracks/untracks"
  - `OnClick` has `if IsShiftKeyDown() then ... else openQuestLogToQuest(questEntry.questID) end`
  - The `if callbacks and callbacks.onTitleShiftClick then` guard is still present and unchanged

- [ ] **Step 4: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua
  git commit -m "feat: left-click quest title opens Quest Log to that quest

  Add openQuestLogToQuest local helper that surgically expands collapsed
  zone headers to locate the quest and collapses them back if not found.
  Extend AddQuestRow OnClick to call it on plain left-click; shift-click
  behavior (track/untrack) is unchanged.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

### Task 2: Add quest hyperlinks to outbound chat announcements

**Files:**
- Modify: `Social-Quest/Core/Announcements.lua`

**Background:** `OnQuestEvent` (line 188) currently builds the chat message from `title` (plain text). AQL quest snapshots (passed as `questInfo`) include a `link` field set by `GetQuestLink(logIndex)` — this is the WoW hyperlink string (`|cFFFFD200|Hquest:questID:level|h[Title]|h|r`) that renders as a clickable link in chat.

We introduce a `display` variable that prefers `questInfo.link`, falls back to `info.link` (from `AQL:GetQuest`), and finally to plain `title`. Only `msg` (the chat string) uses `display`. `title` is preserved unchanged because `self:OnOwnQuestEvent(eventType, title, chainInfo)` at line 237 feeds plain title into `RaidNotice_AddMessage` (which cannot render hyperlinks), and `appendChainStep` appends to `msg`, not `title`.

The `finished` event is called without `questInfo` (SocialQuest.lua:297), so `questInfo` is nil for that event. The `info.link` fallback handles it. If `GetQuestLink` returned nil at cache-build time, both link fields will be nil and `title` is the final fallback.

**Current state (lines 194–199 of `Announcements.lua`):**

```lua
    local title = (info and info.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)
    local msg   = formatOutboundQuestMsg(eventType, title)
    local chainInfo = questInfo and questInfo.chainInfo
    msg = appendChainStep(msg, eventType, chainInfo)
```

- [ ] **Step 1: Insert display variable and update formatOutboundQuestMsg call**

  Open `Social-Quest/Core/Announcements.lua`. Find the title/msg block (lines 194–199):

  **Find:**
  ```lua
      local title = (info and info.title)
                 or (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)
      local msg   = formatOutboundQuestMsg(eventType, title)
      local chainInfo = questInfo and questInfo.chainInfo
      msg = appendChainStep(msg, eventType, chainInfo)
  ```

  **Replace with:**
  ```lua
      local title = (info and info.title)
                 or (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)
      -- Prefer the WoW quest hyperlink string from the AQL snapshot so that recipients
      -- can ctrl-click the quest link in chat. Falls back to info.link (from the live
      -- QuestCache) then plain title. The finished event passes no questInfo (questInfo
      -- is nil) so the info.link fallback is the primary path for that event type.
      -- RaidNotice_AddMessage (banners) cannot render hyperlinks — title is used there.
      local display = (questInfo and questInfo.link)
                   or (info and info.link)
                   or title
      local msg   = formatOutboundQuestMsg(eventType, display)
      local chainInfo = questInfo and questInfo.chainInfo
      msg = appendChainStep(msg, eventType, chainInfo)
  ```

- [ ] **Step 2: Verify the edit**

  Read back `Announcements.lua` lines 188–205 and confirm:
  - `title` computation is unchanged (three-tier fallback ending with `"Quest " .. questID`)
  - `display` variable appears after `title`, using `questInfo.link` → `info.link` → `title`
  - `formatOutboundQuestMsg` is called with `display` (not `title`)
  - `chainInfo` and `appendChainStep` lines are unchanged and still present
  - No changes anywhere else in the function

- [ ] **Step 3: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add Core/Announcements.lua
  git commit -m "feat: use WoW quest hyperlinks in outbound chat announcements

  Introduce display variable in OnQuestEvent that prefers questInfo.link
  (the |Hquest:...|h hyperlink from the AQL snapshot) over plain title.
  Falls back to info.link then title. Banners (OnOwnQuestEvent) continue
  using plain title since RaidNotice_AddMessage cannot render hyperlinks.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

## In-Game Verification

Reload the WoW client with the updated addon after both tasks are committed.

**Test 1 — Left-click, already expanded zone:** Open the Quest Log with all zones expanded. Open the Social Quest frame. Left-click any quest title. Confirm the Quest Log selects that quest.

**Test 2 — Left-click, basic case:** Close the Quest Log. Left-click any quest title in the My Quests tab. Confirm the Quest Log opens and the quest is selected.

**Test 3 — Left-click, collapsed zone:** In the Quest Log, manually collapse a zone that contains one of your active quests. Left-click that quest's title in the Social Quest frame. Confirm the zone expands and the quest is selected. Confirm other collapsed zones remain collapsed.

**Test 4 — Left-click, multiple collapsed zones:** Collapse two or more zone headers in the Quest Log. Click a quest in one of the collapsed zones. Confirm only that zone expands; the others remain collapsed.

**Test 5 — Shift-click still works:** Shift-click a quest title. Confirm it still toggles the tracking checkmark (track/untrack) and does not open the Quest Log.

**Test 6 — Party/Shared tab not clickable:** Switch to the Party or Shared tab. Left-click any quest title. Confirm nothing happens (no Quest Log opens, no error in chat).

**Test 7 — Stale quest no-op:** Turn in or abandon a quest without refreshing the Social Quest frame. Left-click the now-gone quest's row. Confirm no Lua error fires. The Quest Log may open but nothing is selected — that is correct.

**Test 8 — Chat hyperlinks, completed:** Turn in a quest while in a party. Confirm the outbound chat message contains a gold-text bracketed quest name. Ctrl-click it — a quest tooltip should appear.

**Test 9 — Chat hyperlinks, accepted:** Accept a new quest while in a party. Confirm the acceptance message contains a clickable quest link.

**Test 10 — Chat hyperlinks, finished:** Complete a quest's objectives (quest shows as ready to turn in) while in a party. Confirm the "finished" announcement contains a clickable quest link.

**Test 11 — Banner uses plain text:** Accept or complete a quest. Confirm the on-screen banner shows plain quest title with no raw escape sequences (no `|c`, `|H`, `|h`, or `|r` visible).

---

*Spec: `Social-Quest/docs/superpowers/specs/2026-03-18-quest-linkification.md`*
