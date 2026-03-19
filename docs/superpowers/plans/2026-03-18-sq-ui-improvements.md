# SocialQuest UI Improvements — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Five focused improvements to the SocialQuest group frame and debug panel: auto-redraw on quest state change, clickable quest titles on all tabs, better completion display on Party/Shared tabs, a debug chat link test button, and a resizable group frame.

**Architecture:** All changes are isolated edits to existing files. No new files. Changes are ordered by dependency: auto-redraw and clickable titles first (no inter-task dependencies), then the `(Complete)` badge/player row refactor, then the debug chat button (which requires the AQL quest link fix from the prerequisite spec to be meaningful), then frame resize (which requires the `RowFactory.SetContentWidth` setter added in Task 5).

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AceLocale-3.0. No automated test framework — verification is manual, in-game.

**Prerequisite:** `2026-03-18-aql-quest-link-construction.md` must be implemented (AQL repo) before Task 4 will produce a real quest hyperlink. Task 4 can still be implemented without it; the fallback text `"Quest 337 (no link)"` will be used until AQL is updated.

---

## Chunk 1: Auto-redraw, Clickable Titles, Complete Badge

### Task 1: Auto-redraw on quest state change

**Files:**
- Modify: `SocialQuest.lua` — AQL callback handlers, lines 284–342

**Background:** `SocialQuestGroupFrame:RequestRefresh()` already exists in `GroupFrame.lua` with one-per-frame batching and an early-out when the frame is hidden. It is not currently called from any AQL callback. Adding it as the last statement in each handler means the group frame redraws automatically on any quest state change without requiring close/reopen.

`OnUnitQuestLogChanged` is included for completeness: `GroupData.lua`'s own handler already calls `RequestRefresh()`, so this addition is redundant but safe (the `refreshPending` guard makes it idempotent) and documents intent.

**Current state (lines 284–342):**
```lua
function SocialQuest:OnQuestAccepted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
end

function SocialQuest:OnQuestFinished(event, questInfo)
    -- questInfo intentionally NOT passed: "finished" is excluded from chain-step
    -- annotation. See CHAIN_STEP_EVENTS in Core/Announcements.lua.
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
end

function SocialQuest:OnQuestFailed(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
end

function SocialQuest:OnQuestTracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "tracked")
end

function SocialQuest:OnQuestUntracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "untracked")
end

function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
end

function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
end

function SocialQuest:OnUnitQuestLogChanged(event, unit)
    -- Non-SocialQuest member changed their quest log. Sweep shared quests.
    SocialQuestGroupData:OnUnitQuestLogChanged(unit)
end
```

- [ ] **Step 1: Apply the edit**

  Find:
  ```lua
  function SocialQuest:OnQuestAccepted(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
  end

  function SocialQuest:OnQuestAbandoned(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
  end

  function SocialQuest:OnQuestFinished(event, questInfo)
      -- questInfo intentionally NOT passed: "finished" is excluded from chain-step
      -- annotation. See CHAIN_STEP_EVENTS in Core/Announcements.lua.
      SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
  end

  function SocialQuest:OnQuestCompleted(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
  end

  function SocialQuest:OnQuestFailed(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
  end

  function SocialQuest:OnQuestTracked(event, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "tracked")
  end

  function SocialQuest:OnQuestUntracked(event, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "untracked")
  end

  function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
      -- Always broadcast so remote PlayerQuests tables stay accurate.
      SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

      -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
      if objective.numFulfilled >= objective.numRequired then return end

      SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
  end

  function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
      -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
      SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
  end

  function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
      SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
      SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
  end

  function SocialQuest:OnUnitQuestLogChanged(event, unit)
      -- Non-SocialQuest member changed their quest log. Sweep shared quests.
      SocialQuestGroupData:OnUnitQuestLogChanged(unit)
  end
  ```

  Replace with:
  ```lua
  function SocialQuest:OnQuestAccepted(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnQuestAbandoned(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnQuestFinished(event, questInfo)
      -- questInfo intentionally NOT passed: "finished" is excluded from chain-step
      -- annotation. See CHAIN_STEP_EVENTS in Core/Announcements.lua.
      SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnQuestCompleted(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnQuestFailed(event, questInfo)
      SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnQuestTracked(event, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "tracked")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnQuestUntracked(event, questInfo)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "untracked")
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
      -- Always broadcast so remote PlayerQuests tables stay accurate.
      SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

      -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
      if objective.numFulfilled >= objective.numRequired then return end

      SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
      -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
      SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
      SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
      SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
      SocialQuestGroupFrame:RequestRefresh()
  end

  function SocialQuest:OnUnitQuestLogChanged(event, unit)
      -- Non-SocialQuest member changed their quest log. Sweep shared quests.
      SocialQuestGroupData:OnUnitQuestLogChanged(unit)
      SocialQuestGroupFrame:RequestRefresh()
  end
  ```

- [ ] **Step 2: Verify the edit**

  Read back `SocialQuest.lua` lines 284–345 and confirm:
  - Every handler except `OnObjectiveProgressed` ends with `SocialQuestGroupFrame:RequestRefresh()`
  - `OnObjectiveProgressed` has `RequestRefresh()` only in the path that reaches `OnObjectiveEvent` (after the early `return`)
  - No extra blank lines or indentation changes

- [ ] **Step 3: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add SocialQuest.lua
  git commit -m "feat: auto-redraw group frame on quest state change

  Wire SocialQuestGroupFrame:RequestRefresh() into all AQL callback
  handlers. Previously the frame required close/reopen to reflect quest
  changes. RequestRefresh() is idempotent (refreshPending guard) and
  no-ops when the frame is hidden.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

### Task 2: Clickable quest titles on all three tabs

**Files:**
- Modify: `UI/RowFactory.lua` — `AddQuestRow`, lines 239–254

**Background:** The invisible click overlay that handles title left-click (open quest log) and shift-click (track/untrack) is currently guarded by `callbacks.onTitleShiftClick`. Party/Shared tabs always pass `{}` as callbacks, so titles on those tabs are not clickable at all. The fix removes the outer guard and makes the overlay unconditional. Each action is then gated independently: shift-click requires `callbacks.onTitleShiftClick` (Mine tab only); left-click requires `questEntry.logIndex` (nil on Party/Shared when player doesn't have the quest). This means Party/Shared titles open the Quest Log only when the local player has the quest.

**Current state (lines 239–254):**
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

- [ ] **Step 1: Apply the edit**

  Find:
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

  Replace with:
  ```lua
      -- Invisible click overlay: always created on all three tabs.
      -- Left-click opens the Quest Log (only when player has the quest: logIndex non-nil).
      -- Shift-click tracks/untracks (Mine tab only: callbacks.onTitleShiftClick present).
      -- Unhandled combos (e.g. shift-click on Party/Shared) do nothing.
      local titleBtn = CreateFrame("Button", nil, contentFrame)
      titleBtn:SetAllPoints(titleFs)
      titleBtn:SetScript("OnClick", function()
          if IsShiftKeyDown() and callbacks and callbacks.onTitleShiftClick then
              callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
          elseif not IsShiftKeyDown() and questEntry.logIndex then
              openQuestLogToQuest(questEntry.questID)
          end
          -- else: no logIndex (player doesn't have quest) or unhandled combo → do nothing
      end)
  ```

- [ ] **Step 2: Verify the edit**

  Read back `UI/RowFactory.lua` lines 239–258 and confirm:
  - No outer `if callbacks and callbacks.onTitleShiftClick then` guard
  - `CreateFrame("Button", ...)` is unconditional
  - `OnClick` checks `IsShiftKeyDown() and callbacks and callbacks.onTitleShiftClick` for shift-click
  - `OnClick` checks `not IsShiftKeyDown() and questEntry.logIndex` for left-click
  - Comment is updated

- [ ] **Step 3: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua
  git commit -m "feat: make quest titles left-clickable on Party and Shared tabs

  Previously the title click overlay was only created on the Mine tab
  (guarded by callbacks.onTitleShiftClick). Now unconditional; each
  action is gated independently. Left-click opens the Quest Log when
  the player has the quest (logIndex non-nil). Shift-click track/untrack
  remains Mine-tab only.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

### Task 3: `(Complete)` badge suppression and `isComplete` player row

**Files:**
- Modify: `UI/RowFactory.lua` — `AddQuestRow` badge section (line ~198); `AddPlayerRow` (line ~305)
- Modify: `UI/Tabs/PartyTab.lua` — two player entry tables
- Modify: `UI/Tabs/SharedTab.lua` — four player entry tables
- Modify: `Locales/enUS.lua` — one new key

**Background:** The `(Complete)` badge (objectives done, not yet turned in) appears on the quest title row on all three tabs. On Party/Shared it is misleading because it refers to the local player's state, not to the party member whose row is being shown. The fix gates the badge on `callbacks.onTitleShiftClick` (Mine tab indicator) to suppress it on Party/Shared. Instead, a `[Name] Completed` single-line row in `AddPlayerRow` conveys the same information at the player level. A new `isComplete` field must be populated in the player entry tables in `PartyTab.lua` and `SharedTab.lua`.

Priority order in `AddPlayerRow` (first match wins):
1. `hasCompleted` → `[Name] FINISHED` (green) — unchanged
2. `isComplete` → `[Name] Completed` (green) — **new**
3. `needsShare` → `[Name] Needs it Shared` (grey) — unchanged
4. no SocialQuest + no objectives → `[Name] (no data)` (grey) — unchanged
5. else → objective lines — unchanged

**Sub-step 3a: Suppress badge on Party/Shared**

Current state (`UI/RowFactory.lua` lines 197–202):
```lua
    -- Determine badge text. "Complete" trumps "Group".
    local badgeText = ""
    if questEntry.isComplete then
        badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
```

- [ ] **Step 1: Apply the badge suppression edit**

  Find:
  ```lua
      -- Determine badge text. "Complete" trumps "Group".
      local badgeText = ""
      if questEntry.isComplete then
          badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
  ```

  Replace with:
  ```lua
      -- Determine badge text. "Complete" trumps "Group".
      -- (Complete) is shown on Mine tab only (callbacks.onTitleShiftClick is present
      -- only there). On Party/Shared, completion is shown in the player row instead.
      local badgeText = ""
      if questEntry.isComplete and callbacks and callbacks.onTitleShiftClick then
          badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
  ```

**Sub-step 3b: Add `isComplete` branch to `AddPlayerRow`**

Current state (`UI/RowFactory.lua` lines 297–311):
```lua
    if playerEntry.hasCompleted then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], name) .. C.reset)
        return y + ROW_H + 2

    elseif playerEntry.needsShare then
```

- [ ] **Step 2: Apply the AddPlayerRow isComplete edit**

  Find:
  ```lua
      if playerEntry.hasCompleted then
          local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          fs:SetWidth(CONTENT_WIDTH - x - 4)
          fs:SetJustifyH("LEFT")
          fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], name) .. C.reset)
          return y + ROW_H + 2

      elseif playerEntry.needsShare then
  ```

  Replace with:
  ```lua
      if playerEntry.hasCompleted then
          local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          fs:SetWidth(CONTENT_WIDTH - x - 4)
          fs:SetJustifyH("LEFT")
          fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], name) .. C.reset)
          return y + ROW_H + 2

      elseif playerEntry.isComplete then
          local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          fs:SetWidth(CONTENT_WIDTH - x - 4)
          fs:SetJustifyH("LEFT")
          fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s Completed"], name) .. C.reset)
          return y + ROW_H + 2

      elseif playerEntry.needsShare then
  ```

- [ ] **Step 3: Commit RowFactory changes**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua
  git commit -m "feat: suppress (Complete) badge on Party/Shared; add isComplete player row

  Badge on the quest title row is now Mine-tab only. Party/Shared tabs
  instead render '[Name] Completed' on a single green line in AddPlayerRow
  when playerEntry.isComplete is set, sitting between hasCompleted and
  needsShare in priority order.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

**Sub-step 3c: Add `isComplete` to PartyTab player entries**

- [ ] **Step 4: Apply PartyTab local player entry edit**

  File: `UI/Tabs/PartyTab.lua`

  Find:
  ```lua
          table.insert(players, {
              name           = L["(You)"],
              isMe           = true,
              hasSocialQuest = true,
              hasCompleted   = false,
              needsShare     = false,
              objectives     = SocialQuestTabUtils.BuildLocalObjectives(myInfo),
              step           = ci and ci.knownStatus == "known" and ci.step       or nil,
              chainLength    = ci and ci.knownStatus == "known" and ci.length     or nil,
          })
  ```

  Replace with:
  ```lua
          table.insert(players, {
              name           = L["(You)"],
              isMe           = true,
              hasSocialQuest = true,
              hasCompleted   = false,
              needsShare     = false,
              isComplete     = myInfo.isComplete or false,
              objectives     = SocialQuestTabUtils.BuildLocalObjectives(myInfo),
              step           = ci and ci.knownStatus == "known" and ci.step       or nil,
              chainLength    = ci and ci.knownStatus == "known" and ci.length     or nil,
          })
  ```

- [ ] **Step 5: Apply PartyTab remote player entry edit**

  File: `UI/Tabs/PartyTab.lua`

  Find:
  ```lua
              table.insert(players, {
                  name           = playerName,
                  isMe           = false,
                  hasSocialQuest = playerData.hasSocialQuest,
                  hasCompleted   = false,
                  needsShare     = false,
                  objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pquest, myInfo),
                  step           = pCI.knownStatus == "known" and pCI.step   or nil,
                  chainLength    = pCI.knownStatus == "known" and pCI.length or nil,
              })
  ```

  Replace with:
  ```lua
              table.insert(players, {
                  name           = playerName,
                  isMe           = false,
                  hasSocialQuest = playerData.hasSocialQuest,
                  hasCompleted   = false,
                  needsShare     = false,
                  isComplete     = pquest.isComplete or false,
                  objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pquest, myInfo),
                  step           = pCI.knownStatus == "known" and pCI.step   or nil,
                  chainLength    = pCI.knownStatus == "known" and pCI.length or nil,
              })
  ```

- [ ] **Step 6: Commit PartyTab changes**

  ```bash
  git add UI/Tabs/PartyTab.lua
  git commit -m "feat: populate isComplete on PartyTab player entries

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

**Sub-step 3d: Add `isComplete` to SharedTab player entries**

SharedTab has four player entry tables. Two variable names are used: `info` (chain block local) and `localInfo` (standalone block local). Remote entries use `pEng.qdata` (chain block) and `eng.qdata` (standalone block).

- [ ] **Step 7: Apply SharedTab chain local player entry edit**

  File: `UI/Tabs/SharedTab.lua`

  Find:
  ```lua
                          table.insert(entry.players, {
                                  name           = pName,
                                  isMe           = true,
                                  hasSocialQuest = true,
                                  hasCompleted   = false,
                                  needsShare     = false,
                                  objectives     = SocialQuestTabUtils.BuildLocalObjectives(info or {}),
                                  step           = pEng.step,
                                  chainLength    = pEng.chainLength,
                              })
  ```

  Replace with:
  ```lua
                          table.insert(entry.players, {
                                  name           = pName,
                                  isMe           = true,
                                  hasSocialQuest = true,
                                  hasCompleted   = false,
                                  needsShare     = false,
                                  isComplete     = info and info.isComplete or false,
                                  objectives     = SocialQuestTabUtils.BuildLocalObjectives(info or {}),
                                  step           = pEng.step,
                                  chainLength    = pEng.chainLength,
                              })
  ```

- [ ] **Step 8: Apply SharedTab chain remote player entry edit**

  File: `UI/Tabs/SharedTab.lua`

  Find:
  ```lua
                              table.insert(entry.players, {
                                  name           = pName,
                                  isMe           = false,
                                  hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                                  hasCompleted   = false,
                                  needsShare     = false,
                                  objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pEng.qdata or {}, localInfo),
                                  step           = pEng.step,
                                  chainLength    = pEng.chainLength,
                              })
  ```

  Replace with:
  ```lua
                              table.insert(entry.players, {
                                  name           = pName,
                                  isMe           = false,
                                  hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                                  hasCompleted   = false,
                                  needsShare     = false,
                                  isComplete     = pEng.qdata and pEng.qdata.isComplete or false,
                                  objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pEng.qdata or {}, localInfo),
                                  step           = pEng.step,
                                  chainLength    = pEng.chainLength,
                              })
  ```

- [ ] **Step 9: Apply SharedTab standalone local player entry edit**

  File: `UI/Tabs/SharedTab.lua` (standalone block; variable is `localInfo`, not `info`)

  Find:
  ```lua
                  table.insert(entry.players, {
                      name           = playerName,
                      isMe           = true,
                      hasSocialQuest = true,
                      hasCompleted   = false,
                      needsShare     = false,
                      objectives     = SocialQuestTabUtils.BuildLocalObjectives(localInfo or {}),
                  })
  ```

  Replace with:
  ```lua
                  table.insert(entry.players, {
                      name           = playerName,
                      isMe           = true,
                      hasSocialQuest = true,
                      hasCompleted   = false,
                      needsShare     = false,
                      isComplete     = localInfo and localInfo.isComplete or false,
                      objectives     = SocialQuestTabUtils.BuildLocalObjectives(localInfo or {}),
                  })
  ```

- [ ] **Step 10: Apply SharedTab standalone remote player entry edit**

  File: `UI/Tabs/SharedTab.lua` (standalone block; variable is `eng.qdata`)

  Find:
  ```lua
                  table.insert(entry.players, {
                      name           = playerName,
                      isMe           = false,
                      hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                      hasCompleted   = false,
                      needsShare     = false,
                      objectives     = SocialQuestTabUtils.BuildRemoteObjectives(eng.qdata or {}, localInfo),
                  })
  ```

  Replace with:
  ```lua
                  table.insert(entry.players, {
                      name           = playerName,
                      isMe           = false,
                      hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                      hasCompleted   = false,
                      needsShare     = false,
                      isComplete     = eng.qdata and eng.qdata.isComplete or false,
                      objectives     = SocialQuestTabUtils.BuildRemoteObjectives(eng.qdata or {}, localInfo),
                  })
  ```

- [ ] **Step 11: Commit SharedTab changes**

  ```bash
  git add UI/Tabs/SharedTab.lua
  git commit -m "feat: populate isComplete on SharedTab player entries

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

**Sub-step 3e: Add locale key**

- [ ] **Step 12: Add locale key to `Locales/enUS.lua`**

  File: `Locales/enUS.lua`

  Find:
  ```lua
  -- %s = player character name
  L["%s FINISHED"]                            = true
  L["%s Needs it Shared"]                     = true
  L["%s (no data)"]                           = true
  ```

  Replace with:
  ```lua
  -- %s = player character name
  L["%s FINISHED"]                            = true
  L["%s Completed"]                           = true
  L["%s Needs it Shared"]                     = true
  L["%s (no data)"]                           = true
  ```

- [ ] **Step 13: Commit locale change**

  ```bash
  git add Locales/enUS.lua
  git commit -m "feat: add '%s Completed' locale key for isComplete player row

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

## Chunk 2: Debug Chat Button, Frame Resize

### Task 4: Debug chat link test button

**Files:**
- Modify: `Core/Announcements.lua` — after `TestEvent` function (line ~561)
- Modify: `UI/Options.lua` — `testBanners` inline group (line ~343)
- Modify: `Locales/enUS.lua` — two new keys

**Background:** `formatOutboundQuestMsg` (line 87) and `displayChatPreview` (line 138) are `local function`s in `Core/Announcements.lua`. `TestChatLink` must be defined in the same file, after both of them — placing it after `TestEvent` (line 556) satisfies this. The function calls `AQL:GetQuestLink(337)` which (after the AQL prerequisite is implemented) resolves via the provider database even when quest 337 is not in the player's log. The result is passed to `formatOutboundQuestMsg("completed", ...)` which wraps it in the `"Quest turned in: %s"` template and passes it to `displayChatPreview`.

**Current state (`Core/Announcements.lua` lines 556–561):**
```lua
function SocialQuestAnnounce:TestEvent(eventType)
    local demo = TEST_DEMOS[eventType]
    if not demo then return end
    displayBanner(demo.banner, demo.colorKey)
    displayChatPreview(demo.outbound)
end
```

- [ ] **Step 1: Add `TestChatLink` to `Core/Announcements.lua`**

  Find:
  ```lua
  function SocialQuestAnnounce:TestEvent(eventType)
      local demo = TEST_DEMOS[eventType]
      if not demo then return end
      displayBanner(demo.banner, demo.colorKey)
      displayChatPreview(demo.outbound)
  end
  ```

  Replace with:
  ```lua
  function SocialQuestAnnounce:TestEvent(eventType)
      local demo = TEST_DEMOS[eventType]
      if not demo then return end
      displayBanner(demo.banner, demo.colorKey)
      displayChatPreview(demo.outbound)
  end

  function SocialQuestAnnounce:TestChatLink()
      local AQL  = SocialQuest.AQL
      local link = AQL and AQL:GetQuestLink(337)
      local msg  = formatOutboundQuestMsg("completed", link or "Quest 337 (no link)")
      displayChatPreview(msg)
  end
  ```

- [ ] **Step 2: Add `testChatLink` button to `UI/Options.lua`**

  File: `UI/Options.lua`

  Find:
  ```lua
                          testAllComplete = {
                              type = "execute",
                              name = L["Test All Completed"],
                              desc = L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."],
                              func = function() SocialQuestAnnounce:TestEvent("all_complete") end,
                          },
                      },
                  },
  ```

  Replace with:
  ```lua
                          testAllComplete = {
                              type = "execute",
                              name = L["Test All Completed"],
                              desc = L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."],
                              func = function() SocialQuestAnnounce:TestEvent("all_complete") end,
                          },
                          testChatLink = {
                              type = "execute",
                              name = L["Test Chat Link"],
                              desc = L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."],
                              func = function() SocialQuestAnnounce:TestChatLink() end,
                          },
                      },
                  },
  ```

- [ ] **Step 3: Add locale keys to `Locales/enUS.lua`**

  File: `Locales/enUS.lua`

  Find:
  ```lua
  L["Test All Completed"]                     = true
  L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = true
  ```

  Replace with:
  ```lua
  L["Test All Completed"]                     = true
  L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = true
  L["Test Chat Link"]                         = true
  L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = true
  ```

- [ ] **Step 4: Verify the edits**

  Read back:
  - `Core/Announcements.lua` lines 556–575: confirm `TestChatLink` follows `TestEvent`, uses `formatOutboundQuestMsg("completed", link or "Quest 337 (no link)")`, and calls `displayChatPreview`
  - `UI/Options.lua` lines 338–355: confirm `testChatLink` is inside `testBanners.args`, after `testAllComplete`
  - `Locales/enUS.lua`: confirm both new keys are present

- [ ] **Step 5: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add Core/Announcements.lua UI/Options.lua Locales/enUS.lua
  git commit -m "feat: add debug 'Test Chat Link' button for quest hyperlink verification

  TestChatLink() calls AQL:GetQuestLink(337) and passes the result through
  the real 'Quest turned in' template, printing a chat preview. Requires the
  AQL quest link construction fix to produce an actual hyperlink; falls back
  to plain text otherwise.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

### Task 5: Resizable group frame

**Files:**
- Modify: `UI/RowFactory.lua` — add `SetContentWidth` setter after line 8
- Modify: `UI/GroupFrame.lua` — `createFrame()` resize support; `Refresh()` dynamic content width

**Background:** The frame already uses `BasicFrameTemplateWithInset` and is movable. Two changes are needed: (1) `RowFactory.SetContentWidth(w)` writes to the `local CONTENT_WIDTH` upvalue, allowing `GroupFrame:Refresh()` to push the current frame width into `RowFactory` before each render. (2) `createFrame()` adds `SetResizable(true)`, `SetResizeBounds(280, 200)`, and a 16×16 resize handle at `BOTTOMRIGHT` using the standard WoW grip texture. The handle's `OnMouseUp` calls `RequestRefresh()` to rerender at the new size. Size is not persisted (no AceDB changes).

**Sub-step 5a: Add `RowFactory.SetContentWidth`**

**Current state (`UI/RowFactory.lua` lines 6–11):**
```lua
RowFactory = {}

local CONTENT_WIDTH = 360
local ROW_H         = 18     -- standard row height in pixels
local INDENT_STEP   = 16     -- pixels per indent level
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
```

- [ ] **Step 1: Add the SetContentWidth setter to `UI/RowFactory.lua`**

  Find:
  ```lua
  RowFactory = {}

  local CONTENT_WIDTH = 360
  local ROW_H         = 18     -- standard row height in pixels
  local INDENT_STEP   = 16     -- pixels per indent level
  local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
  ```

  Replace with:
  ```lua
  RowFactory = {}

  local CONTENT_WIDTH = 360
  local ROW_H         = 18     -- standard row height in pixels
  local INDENT_STEP   = 16     -- pixels per indent level
  local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

  -- Called by GroupFrame:Refresh() to set content width before rendering.
  -- Writes to the CONTENT_WIDTH upvalue so all row functions use the current frame width.
  function RowFactory.SetContentWidth(w)
      CONTENT_WIDTH = w
  end
  ```

**Sub-step 5b: Add resize support to `createFrame()`**

**Current state (`UI/GroupFrame.lua` lines 87–99):**
```lua
local function createFrame()
    local f = CreateFrame("Frame", "SocialQuestGroupFramePanel", UIParent,
                          "BasicFrameTemplateWithInset")
    f:SetSize(400, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetScript("OnMouseDown", function(self) self:Raise() end)
    f:Hide()
```

- [ ] **Step 2: Add resize support after `f:Hide()` in `createFrame()`**

  Find:
  ```lua
      f:SetScript("OnDragStart", function(self) self:StartMoving() end)
      f:SetScript("OnDragStop",  f.StopMovingOrSizing)
      f:SetScript("OnMouseDown", function(self) self:Raise() end)
      f:Hide()
  ```

  Replace with:
  ```lua
      f:SetScript("OnDragStart", function(self) self:StartMoving() end)
      f:SetScript("OnDragStop",  f.StopMovingOrSizing)
      f:SetScript("OnMouseDown", function(self) self:Raise() end)
      f:Hide()

      f:SetResizable(true)
      f:SetResizeBounds(280, 200)

      local resizeHandle = CreateFrame("Frame", nil, f)
      resizeHandle:SetSize(16, 16)
      resizeHandle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
      resizeHandle:EnableMouse(true)
      local resizeTex = resizeHandle:CreateTexture(nil, "BACKGROUND")
      resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
      resizeTex:SetAllPoints(resizeHandle)
      resizeHandle:SetScript("OnMouseDown", function(self, button)
          if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
      end)
      resizeHandle:SetScript("OnMouseUp", function()
          f:StopMovingOrSizing()
          SocialQuestGroupFrame:RequestRefresh()
      end)
  ```

**Sub-step 5c: Consistent initial content width in `createFrame()`**

The initial `f.content` created in `createFrame()` uses a hardcoded `360`. It is immediately overwritten by the first `Refresh()` call, but the spec requires the same computed value for consistency.

**Current state (`UI/GroupFrame.lua` lines 144–146):**
```lua
    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(360, 1)
    f.scrollFrame:SetScrollChild(f.content)
```

- [ ] **Step 3: Update initial content size in `createFrame()`**

  Find:
  ```lua
      f.content = CreateFrame("Frame", nil, f.scrollFrame)
      f.content:SetSize(360, 1)
      f.scrollFrame:SetScrollChild(f.content)
  ```

  Replace with:
  ```lua
      local initContentW = math.floor(f:GetWidth() - 40)
      f.content = CreateFrame("Frame", nil, f.scrollFrame)
      f.content:SetSize(initContentW, 1)
      f.scrollFrame:SetScrollChild(f.content)
  ```

  Note: `f:GetWidth()` returns 400 at this point (set by `f:SetSize(400, 500)` above), so `initContentW` equals 360 — the same as before. This is a consistency change; the first `Refresh()` call immediately overwrites it with the actual computed width.

**Sub-step 5d: Dynamic content width in `Refresh()`**

**Current state (`UI/GroupFrame.lua` lines 189–198):**
```lua
function SocialQuestGroupFrame:Refresh()
    if not frame then return end
    frame.scrollFrame:SetVerticalScroll(0)

    -- Recreate content child (GetChildren does not return FontStrings; hiding is
    -- the only clean way to discard old rows without leaking them).
    if frame.content then frame.content:Hide() end
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(360, 1)
    frame.scrollFrame:SetScrollChild(frame.content)
```

- [ ] **Step 4: Apply the dynamic width edit to `Refresh()`**

  Find:
  ```lua
      -- Recreate content child (GetChildren does not return FontStrings; hiding is
      -- the only clean way to discard old rows without leaking them).
      if frame.content then frame.content:Hide() end
      frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
      frame.content:SetSize(360, 1)
      frame.scrollFrame:SetScrollChild(frame.content)
  ```

  Replace with:
  ```lua
      -- Recreate content child (GetChildren does not return FontStrings; hiding is
      -- the only clean way to discard old rows without leaking them).
      local contentW = math.floor(frame:GetWidth() - 40)
      RowFactory.SetContentWidth(contentW)
      if frame.content then frame.content:Hide() end
      frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
      frame.content:SetSize(contentW, 1)
      frame.scrollFrame:SetScrollChild(frame.content)
  ```

- [ ] **Step 5: Verify the edits**

  Read back:
  - `UI/RowFactory.lua` lines 6–20: confirm `RowFactory.SetContentWidth` is present after `CONTENT_WIDTH` declaration
  - `UI/GroupFrame.lua` lines 140–150: confirm `initContentW` computation and `SetSize(initContentW, 1)` in `createFrame()`
  - `UI/GroupFrame.lua` lines 87–125: confirm `SetResizable(true)`, `SetResizeBounds(280, 200)`, and resize handle block are present after `f:Hide()`
  - `UI/GroupFrame.lua` lines 190–210: confirm `contentW` computation, `RowFactory.SetContentWidth(contentW)`, and `SetSize(contentW, 1)` are present in `Refresh()`

- [ ] **Step 6: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua UI/GroupFrame.lua
  git commit -m "feat: make group frame resizable with dynamic content width

  Add SetResizable, SetResizeBounds(280, 200), and a BOTTOMRIGHT resize
  handle with the standard WoW grip texture. Refresh() computes
  contentW = frame:GetWidth() - 40 and passes it to RowFactory via
  RowFactory.SetContentWidth() so all row rendering uses the current
  width. Size resets to 400x500 on UI reload (not persisted).

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

## In-Game Verification

Load the updated addon in WoW TBC Classic (Interface 20505).

**Task 1 — Auto-redraw:**
1. Open the group frame. Accept a new quest without closing the frame. Confirm the quest appears immediately on the Mine and Party tabs without reopening.
2. Complete all objectives on an active quest. Confirm objective progress updates in the frame without reopening.
3. Abandon a quest. Confirm it disappears from the Mine tab immediately.

**Task 2 — Clickable titles on all tabs:**
1. On the Party/Shared tab, left-click a quest title for a quest the player also has. Confirm the Quest Log opens and selects that quest.
2. Left-click a quest title on the Party/Shared tab that only another party member has (player does not have this quest). Confirm nothing happens — no Quest Log opens, no Lua error in chat.
3. Shift-click a quest title on the Mine tab. Confirm it still toggles the tracking checkmark.
4. Left-click a quest title on the Mine tab (no shift). Confirm it opens the Quest Log to that quest.

**Task 3 — Complete badge / player row:**
1. Have a quest with all objectives done (ready to turn in). Open the Party tab. Confirm `(Complete)` does NOT appear on the quest title row. Confirm the `(You)` row shows `(You) Completed` on a single line with no objective lines below it.
2. Open the Mine tab for the same quest. Confirm `(Complete)` badge still appears on the title row.
3. Have a party member with all objectives done. Confirm their row shows `Name Completed` on Party/Shared tabs.

**Task 4 — Debug chat link button:**
1. Open Interface Options → SocialQuest → Debug. Click "Test Chat Link". Confirm the chat preview shows `[SocialQuest (preview):] Quest turned in: [Quest Name]` where the quest name is rendered as clickable gold text (requires AQL quest link fix). Ctrl-click to confirm the quest tooltip appears.
2. If the link shows as plain text `Quest 337 (no link)`, the AQL prerequisite fix has not been applied yet.

**Task 5 — Resize:**
1. Open the group frame. Drag the bottom-right corner to make it taller. Confirm quest rows fill the available height and the content redraws on release.
2. Drag to make it narrower. Confirm quest titles truncate cleanly rather than overflowing.
3. `/reload`. Confirm the frame returns to its default 400×500 size.
