# Group Frame Improvements — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the SocialQuest group frame to display quests grouped by zone/chain with difficulty colouring, tracking toggle, Wowhead link popup, FINISHED/Needs-it-Shared indicators, and completed-quest AceComm queries.

**Architecture:** Split GroupFrame.lua's three inline render functions into separate tab-provider modules (MineTab, PartyTab, SharedTab) and a shared stateless RowFactory. GroupFrame becomes a thin dispatcher that builds the frame, manages saved-variable tab state, and calls providers. Each provider implements BuildTree() → structured data, Render() → draws rows via RowFactory.

**Tech Stack:** Lua, WoW TBC Classic (Interface 20505), Ace3 (AceComm-3.0, AceDB-3.0, AceSerializer-3.0), AbsoluteQuestLog-1.0 (AQL)

---

## File Map

**Created:**
- `Social-Quest/UI/RowFactory.lua` — stateless row-drawing helpers (AddZoneHeader, AddChainHeader, AddQuestRow, AddObjectiveRow, AddPlayerRow)
- `Social-Quest/UI/Tabs/MineTab.lua` — Mine tab provider (BuildTree + Render)
- `Social-Quest/UI/Tabs/PartyTab.lua` — Party tab provider (BuildTree + Render)
- `Social-Quest/UI/Tabs/SharedTab.lua` — Shared tab provider (BuildTree + Render)

**Modified:**
- `Absolute-Quest-Log/Core/QuestCache.lua` — add `logIndex` and `wowheadUrl` to `_buildEntry` return table
- `Social-Quest/SocialQuest.lua` — add `frameState` block to `GetDefaults()`
- `Social-Quest/Core/GroupData.lua` — add `completedQuests = {}` to all stubs; preserve on OnInitReceived
- `Social-Quest/Core/Communications.lua` — add SQ_REQ_COMPLETED / SQ_RESP_COMPLETED
- `Social-Quest/UI/GroupFrame.lua` — replace three Render* functions with provider dispatch; add StaticPopup, ToggleZone, DB-backed tab state
- `Social-Quest/SocialQuest.toc` — register RowFactory and Tabs/*.lua before GroupFrame

---

## Chunk 1: AQL + SocialQuest Core

### Task 1: Add logIndex and wowheadUrl to QuestCache

**Files:**
- Modify: `Absolute-Quest-Log/Core/QuestCache.lua`

- [ ] **Step 1: Add the WOWHEAD_QUEST_BASE constant**

  In `Core/QuestCache.lua`, after line 7 (`if not AQL then return end`), insert:

  ```lua
  local WOWHEAD_QUEST_BASE = "https://www.wowhead.com/tbc/quest="
  ```

- [ ] **Step 2: Add logIndex and wowheadUrl to the _buildEntry return table**

  The return table in `_buildEntry` (currently lines 132–149) becomes:

  ```lua
      return {
          questID        = questID,
          title          = info.title or "",
          level          = info.level or 0,
          suggestedGroup = info.suggestedGroup or 0,
          zone           = zone,
          type           = questType,
          faction        = questFaction,
          isComplete     = isComplete,
          isFailed       = isFailed,
          failReason     = failReason,
          isTracked      = isTracked,
          link           = link,
          logIndex       = logIndex,
          wowheadUrl     = WOWHEAD_QUEST_BASE .. tostring(questID),
          snapshotTime   = GetTime(),
          timerSeconds   = timerSeconds,
          objectives     = objectives,
          chainInfo      = chainInfo,
      }
  ```

- [ ] **Step 3: Verify in-game**

  Copy `Absolute-Quest-Log` to the WoW AddOns folder and `/reload`. In WowLua:

  ```lua
  local AQL = LibStub("AbsoluteQuestLog-1.0", true)
  local qid, info = next(AQL:GetAllQuests())
  print("logIndex:", info.logIndex, "url:", info.wowheadUrl)
  ```

  Expected: a number for logIndex (e.g. `3`) and a URL string like `https://www.wowhead.com/tbc/quest=12345`. No Lua errors in chat.

- [ ] **Step 4: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
  git add Core/QuestCache.lua
  git commit -m "feat: add logIndex and wowheadUrl to QuestCache _buildEntry"
  ```

---

### Task 2: Add frameState to GetDefaults()

**Files:**
- Modify: `Social-Quest/SocialQuest.lua` (lines 85–129)

- [ ] **Step 1: Add frameState block**

  In `GetDefaults()`, after the `debug = { enabled = false, },` block, before the closing `},` of `profile`, insert:

  ```lua
              frameState = {
                  activeTab = "mine",
                  collapsedZones = {
                      mine   = {},
                      party  = {},
                      shared = {},
                  },
              },
  ```

- [ ] **Step 2: Verify in-game**

  After `/reload`, run in WowLua:

  ```lua
  print(SocialQuest.db.profile.frameState.activeTab)
  print(type(SocialQuest.db.profile.frameState.collapsedZones.mine))
  ```

  Expected: `mine` then `table`. No errors.

---

### Task 3: Add completedQuests to GroupData stubs

**Files:**
- Modify: `Social-Quest/Core/GroupData.lua`

- [ ] **Step 1: Update stub creation in OnGroupChanged**

  Change the stub creation on line 47 from:

  ```lua
              self.PlayerQuests[fullName] = { hasSocialQuest = false }
  ```

  To:

  ```lua
              self.PlayerQuests[fullName] = { hasSocialQuest = false, completedQuests = {} }
  ```

- [ ] **Step 2: Preserve completedQuests across OnInitReceived**

  Change lines 58–64 from:

  ```lua
      self.PlayerQuests[sender] = {
          hasSocialQuest = true,
          lastSync       = GetTime(),
          quests         = payload.quests or {},
      }
  ```

  To:

  ```lua
      local existing = self.PlayerQuests[sender]
      self.PlayerQuests[sender] = {
          hasSocialQuest  = true,
          lastSync        = GetTime(),
          quests          = payload.quests or {},
          completedQuests = (existing and existing.completedQuests) or {},
      }
  ```

  This preserves completedQuests if SQ_RESP_COMPLETED arrived before SQ_INIT.

- [ ] **Step 3: Add completedQuests to the OnUnitQuestLogChanged stub**

  In `OnUnitQuestLogChanged`, the stub at lines 164–168 creates an entry without `completedQuests`. Change from:

  ```lua
      self.PlayerQuests[fullName] = {
          hasSocialQuest = false,
          lastSync       = GetTime(),
          quests         = questData,
      }
  ```

  To:

  ```lua
      self.PlayerQuests[fullName] = {
          hasSocialQuest  = false,
          lastSync        = GetTime(),
          quests          = questData,
          completedQuests = {},
      }
  ```

- [ ] **Step 4: Add completedQuests to the OnUpdateReceived implicit-stub path**

  In `OnUpdateReceived`, lines 76–78 create an implicit stub when no entry exists yet for the sender. Change from:

  ```lua
          entry = { hasSocialQuest = true, lastSync = GetTime(), quests = {} }
  ```

  To:

  ```lua
          entry = { hasSocialQuest = true, lastSync = GetTime(), quests = {}, completedQuests = {} }
  ```

- [ ] **Step 5: Verify in-game**

  While solo (no party, PlayerQuests will be empty) this verifies the path via the stub. In WowLua:

  ```lua
  SocialQuestGroupData.PlayerQuests["Test"] = nil
  SocialQuestGroupData:OnGroupChanged()
  -- Simulate: manually call the stub path
  local stub = { hasSocialQuest = false, completedQuests = {} }
  print(type(stub.completedQuests))  -- expected: table
  ```

  Then while in a group, verify all entries have completedQuests:

  ```lua
  for name, e in pairs(SocialQuestGroupData.PlayerQuests) do
      print(name, type(e.completedQuests))
  end
  ```

  Expected: all print `table`.

- [ ] **Step 6: Update GroupData File Map description**

  The File Map at the top of the plan says "add `completedQuests = {}` to all stubs; preserve on OnInitReceived". This description is already correct — no edit needed.

---

### Task 4: Add SQ_REQ_COMPLETED / SQ_RESP_COMPLETED

**Files:**
- Modify: `Social-Quest/Core/Communications.lua`

- [ ] **Step 1: Add new prefixes**

  Change the `PREFIXES` table from:

  ```lua
  local PREFIXES = {
      "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
      "SQ_BEACON", "SQ_REQUEST",
      "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
  }
  ```

  To:

  ```lua
  local PREFIXES = {
      "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
      "SQ_BEACON", "SQ_REQUEST",
      "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
      "SQ_REQ_COMPLETED", "SQ_RESP_COMPLETED",
  }
  ```

- [ ] **Step 2: Add SendReqCompleted helper**

  After `SendFollowStop` (around line 172), add:

  ```lua
  -- Broadcast to group members requesting their completed quest IDs.
  function SocialQuestComm:SendReqCompleted()
      local channel = self:GetActiveChannel()
      if not channel then return end
      LibStub("AceComm-3.0"):SendCommMessage("SQ_REQ_COMPLETED", serialize({}), channel)
  end
  ```

- [ ] **Step 3: Call SendReqCompleted from OnGroupChanged**

  At the very end of `SocialQuestComm:OnGroupChanged()` (after the existing if/elseif chain, before the function's closing `end`), add:

  ```lua
      self:SendReqCompleted()
  ```

- [ ] **Step 3b: Call SendReqCompleted from SocialQuest:OnEnable()**

  The spec says the request is sent on "OnEnable or GROUP_ROSTER_UPDATE". Step 3 covers GROUP_ROSTER_UPDATE. For players who log in while already in a group, OnGroupChanged may not fire until the next roster change. In `SocialQuest.lua`, in `OnEnable()`, after `SocialQuestComm:Initialize()`, add:

  ```lua
      -- If already in a group at login, query completed quest history immediately.
      if IsInGroup() or IsInRaid() then
          SocialQuestComm:SendReqCompleted()
      end
  ```

- [ ] **Step 4: Handle SQ_REQ_COMPLETED and SQ_RESP_COMPLETED in OnCommReceived**

  In `OnCommReceived`, after the `elseif prefix == "SQ_FOLLOW_STOP" then` block, before the final `end`, add:

  ```lua
      elseif prefix == "SQ_REQ_COMPLETED" then
          -- Whisper our completed quest history back to the requester.
          local AQL = SocialQuest.AQL
          if AQL and AQL.HistoryCache then
              local payload = { completedQuests = AQL.HistoryCache.completed }
              LibStub("AceComm-3.0"):SendCommMessage(
                  "SQ_RESP_COMPLETED", serialize(payload), "WHISPER", sender)
          end

      elseif prefix == "SQ_RESP_COMPLETED" then
          -- Store the responding player's completed quest set.
          -- NOTE: `payload` here is already deserialized — the existing code at the
          -- top of OnCommReceived does `local ok, payload = AceSerializer:Deserialize(msg)`
          -- before the prefix dispatch, so no separate deserialization is needed here.
          local entry = SocialQuestGroupData.PlayerQuests[sender]
          if entry then
              entry.completedQuests = payload.completedQuests or {}
          end
          SocialQuestGroupFrame:RequestRefresh()
  ```

- [ ] **Step 5: Verify in-game**

  After `/reload`, check no errors:

  ```lua
  print(SocialQuestComm ~= nil)  -- expected: true (no load errors)
  ```

  If in a group with another SocialQuest user, check that `PlayerQuests[name].completedQuests` populates (may take a moment for the whisper exchange):

  ```lua
  for name, e in pairs(SocialQuestGroupData.PlayerQuests) do
      local cnt = 0
      for _ in pairs(e.completedQuests or {}) do cnt = cnt + 1 end
      print(name, "completed:", cnt)
  end
  ```

- [ ] **Step 6: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add SocialQuest.lua Core/GroupData.lua Core/Communications.lua
  git commit -m "feat: frameState defaults, completedQuests stubs, SQ_REQ/RESP_COMPLETED comms"
  ```

---

## Chunk 2: RowFactory

### Task 5: Create RowFactory.lua

**Files:**
- Create: `Social-Quest/UI/RowFactory.lua`

RowFactory is a stateless module. All functions take `contentFrame` (the scroll child frame, 360 px wide) and a running `y` offset, create child UI elements, and return the new `y`. `SQ_WOWHEAD_POPUP` is registered in GroupFrame.lua (not here).

- [ ] **Step 1: Create Social-Quest/UI/RowFactory.lua**

  ```lua
  -- UI/RowFactory.lua
  -- Stateless row-drawing utilities for the group frame tab providers.
  -- All functions take (contentFrame, y, ...) and return the new y offset.
  -- contentFrame is the scroll child (width = 360 px, set by GroupFrame).
  -- StaticPopupDialogs["SQ_WOWHEAD_POPUP"] is registered in GroupFrame.lua.

  RowFactory = {}

  local CONTENT_WIDTH = 360
  local ROW_H         = 18     -- standard row height in pixels
  local INDENT_STEP   = 16     -- pixels per indent level

  ------------------------------------------------------------------------
  -- Private helpers
  ------------------------------------------------------------------------

  -- Returns a difficulty colour table {r, g, b} for questLevel.
  -- Uses GetQuestDifficultyColor when present (exists in TBC 20505).
  local function getDifficultyColor(questLevel)
      if GetQuestDifficultyColor then
          return GetQuestDifficultyColor(questLevel or 0)
      end
      local diff = UnitLevel("player") - (questLevel or 0)
      if     diff >= 5  then return { r = 0.75, g = 0.75, b = 0.75 }
      elseif diff >= 3  then return { r = 0.25, g = 0.75, b = 0.25 }
      elseif diff >= -2 then return { r = 1.0,  g = 1.0,  b = 0.0  }
      elseif diff >= -4 then return { r = 1.0,  g = 0.5,  b = 0.25 }
      else                   return { r = 1.0,  g = 0.1,  b = 0.1  }
      end
  end

  -- Formats remaining timer as "M:SS". Returns nil when expired or no data.
  local function formatTimeRemaining(timerSeconds, snapshotTime)
      if not timerSeconds or not snapshotTime then return nil end
      local remaining = timerSeconds - (GetTime() - snapshotTime)
      if remaining <= 0 then return nil end
      return string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
  end

  ------------------------------------------------------------------------
  -- Public API
  ------------------------------------------------------------------------

  -- Zone/category header row with [+]/[-] collapse toggle.
  -- onToggle() is called on button click (no arguments).
  function RowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, onToggle)
      local C = SocialQuestColors

      local toggleBtn = CreateFrame("Button", nil, contentFrame)
      toggleBtn:SetSize(22, ROW_H)
      toggleBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -y)
      toggleBtn:SetText(isCollapsed and "[+]" or "[-]")
      toggleBtn:SetNormalFontObject("GameFontNormalSmall")
      toggleBtn:SetHighlightFontObject("GameFontHighlightSmall")
      if onToggle then
          toggleBtn:SetScript("OnClick", onToggle)
      end

      local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 24, -y)
      label:SetWidth(CONTENT_WIDTH - 24)
      label:SetJustifyH("LEFT")
      label:SetText(C.header .. zoneName .. C.reset)

      return y + ROW_H + 4
  end

  -- Chain group label row (indented, cyan).
  function RowFactory.AddChainHeader(contentFrame, y, chainTitle, indent)
      local C = SocialQuestColors
      local x = indent or 0

      local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
      label:SetWidth(CONTENT_WIDTH - x)
      label:SetJustifyH("LEFT")
      label:SetText(C.chain .. chainTitle .. C.reset)

      return y + ROW_H + 2
  end

  -- Quest row.
  -- Layout (left to right): [?] link | [v] checkmark (Mine only) | title | badge (right)
  -- callbacks = { onTitleShiftClick = function(logIndex, isTracked) }
  --   onTitleShiftClick: nil on Party/Shared tabs (disables checkmark and shift-click).
  --   NOTE: The link button calls StaticPopup_Show directly; no onLinkClick callback.
  function RowFactory.AddQuestRow(contentFrame, y, questEntry, indent, callbacks)
      local C = SocialQuestColors
      local x = indent or 0

      -- [?] Wowhead link button.
      local linkBtn = CreateFrame("Button", nil, contentFrame)
      linkBtn:SetSize(22, ROW_H)
      linkBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
      linkBtn:SetText("[?]")
      linkBtn:SetNormalFontObject("GameFontNormalSmall")
      linkBtn:SetHighlightFontObject("GameFontHighlightSmall")
      linkBtn:SetScript("OnClick", function()
          StaticPopup_Show("SQ_WOWHEAD_POPUP", questEntry.wowheadUrl or "")
      end)
      x = x + 24

      -- [v] Tracked checkmark — only when onTitleShiftClick is provided and quest is tracked.
      if callbacks and callbacks.onTitleShiftClick and questEntry.isTracked then
          local check = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          check:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          check:SetWidth(18)
          check:SetText(C.completed .. "[v]" .. C.reset)
          x = x + 20
      end

      -- Determine badge text. "Complete" trumps "Group".
      local badgeText = ""
      if questEntry.isComplete then
          badgeText = C.completed .. "(Complete)" .. C.reset
      elseif questEntry.suggestedGroup and questEntry.suggestedGroup > 0 then
          badgeText = C.chain .. "(Group)" .. C.reset
      end
      local badgeWidth = badgeText ~= "" and 80 or 0

      -- Quest title button.
      local titleWidth = CONTENT_WIDTH - x - badgeWidth - 10
      local titleBtn = CreateFrame("Button", nil, contentFrame)
      titleBtn:SetSize(math.max(titleWidth, 20), ROW_H)
      titleBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
      titleBtn:SetNormalFontObject("GameFontNormalSmall")
      titleBtn:SetHighlightFontObject("GameFontHighlightSmall")

      -- Build title string: title [Step X of Y] [timer].
      local titleText = questEntry.title or "Quest"
      local ci = questEntry.chainInfo
      if ci and ci.knownStatus == "known" then
          titleText = titleText
              .. " (Step " .. tostring(ci.step   or "?")
              .. " of "    .. tostring(ci.length or "?") .. ")"
      end
      local timeStr = formatTimeRemaining(questEntry.timerSeconds, questEntry.snapshotTime)
      if timeStr then
          titleText = titleText .. " [" .. timeStr .. "]"
      end
      titleBtn:SetText(titleText)

      local c = getDifficultyColor(questEntry.level)
      titleBtn:SetTextColor(c.r, c.g, c.b)

      if callbacks then
          titleBtn:SetScript("OnClick", function()
              if IsShiftKeyDown() and callbacks.onTitleShiftClick then
                  callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
              end
          end)
      end

      -- Badge (right-aligned).
      if badgeText ~= "" then
          local badge = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          badge:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -8, -y)
          badge:SetWidth(badgeWidth)
          badge:SetJustifyH("RIGHT")
          badge:SetText(badgeText)
      end

      return y + ROW_H + 2
  end

  -- Objective row. Yellow = incomplete, green = complete.
  -- objectiveEntry must have: text (string), isFinished (bool).
  function RowFactory.AddObjectiveRow(contentFrame, y, objectiveEntry, indent)
      local C  = SocialQuestColors
      local x  = indent or 0
      local clr = objectiveEntry.isFinished and C.completed or C.active

      local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
      fs:SetWidth(CONTENT_WIDTH - x - 4)
      fs:SetJustifyH("LEFT")
      fs:SetText(clr .. (objectiveEntry.text or "") .. C.reset)

      return y + fs:GetStringHeight() + 2
  end

  -- Player row. Display priority (first matching wins):
  --   1. playerEntry.hasCompleted → "[Name] FINISHED" (green)
  --   2. playerEntry.needsShare   → "[Name] Needs it Shared" (grey)
  --   3. hasSocialQuest==false and no objectives → "[Name] (no data)" (grey)
  --   4. otherwise → "[Name]" label (+ "Step X of Y" when step/chainLength set),
  --                  followed by objective rows.
  -- playerEntry fields: name, isMe, hasSocialQuest, hasCompleted, needsShare,
  --                     objectives, step (optional), chainLength (optional).
  function RowFactory.AddPlayerRow(contentFrame, y, playerEntry, indent)
      local C    = SocialQuestColors
      local x    = indent or 0
      local name = playerEntry.name or "Unknown"

      if playerEntry.hasCompleted then
          local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          fs:SetWidth(CONTENT_WIDTH - x - 4)
          fs:SetJustifyH("LEFT")
          fs:SetText(C.completed .. name .. " FINISHED" .. C.reset)
          return y + ROW_H + 2

      elseif playerEntry.needsShare then
          local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          fs:SetWidth(CONTENT_WIDTH - x - 4)
          fs:SetJustifyH("LEFT")
          fs:SetText(C.unknown .. name .. " Needs it Shared" .. C.reset)
          return y + ROW_H + 2

      elseif not playerEntry.hasSocialQuest
          and (not playerEntry.objectives or #playerEntry.objectives == 0) then
          local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          fs:SetWidth(CONTENT_WIDTH - x - 4)
          fs:SetJustifyH("LEFT")
          fs:SetText(C.unknown .. name .. " (no data)" .. C.reset)
          return y + ROW_H + 2

      else
          -- Name line (with optional step info).
          local nameLine = name
          if playerEntry.step and playerEntry.chainLength then
              nameLine = nameLine
                  .. " Step " .. tostring(playerEntry.step)
                  .. " of "   .. tostring(playerEntry.chainLength)
          end
          local nameFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          nameFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
          nameFs:SetWidth(CONTENT_WIDTH - x - 4)
          nameFs:SetJustifyH("LEFT")
          nameFs:SetText(C.white .. nameLine .. C.reset)
          y = y + ROW_H + 2

          -- Objective rows.
          for _, obj in ipairs(playerEntry.objectives or {}) do
              y = RowFactory.AddObjectiveRow(contentFrame, y, obj, x + INDENT_STEP)
          end
          return y
      end
  end
  ```

- [ ] **Step 2: Verify file structure (manual)**

  Confirm the file has exactly 5 public functions (`AddZoneHeader`, `AddChainHeader`, `AddQuestRow`, `AddObjectiveRow`, `AddPlayerRow`) and 2 local helpers. Count `end` keywords match `function` keywords. No `TODO` markers.

- [ ] **Step 3: Verify RowFactory loads cleanly**

  Copy `Social-Quest` to the WoW AddOns folder and `/reload`. In WowLua:

  ```lua
  print(type(RowFactory.AddZoneHeader))   -- expected: function
  print(type(RowFactory.AddChainHeader))  -- expected: function
  print(type(RowFactory.AddQuestRow))     -- expected: function
  print(type(RowFactory.AddObjectiveRow)) -- expected: function
  print(type(RowFactory.AddPlayerRow))    -- expected: function
  ```

  Expected: all print `function`. Any `nil` means the file failed to load — check chat for Lua errors.

- [ ] **Step 4: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua
  git commit -m "feat: add stateless RowFactory row-drawing utilities"
  ```

---

## Chunk 3: MineTab

### Task 6: Create UI/Tabs/MineTab.lua

**Files:**
- Create: `Social-Quest/UI/Tabs/MineTab.lua`

MineTab shows the local player's quests grouped by zone → chain → step, with cross-chain peer rows from GroupData. Shift-click tracking is enabled.

- [ ] **Step 1: Create the UI/Tabs/ directory and MineTab.lua**

  ```lua
  -- UI/Tabs/MineTab.lua
  -- Mine tab provider. Shows the local player's quests grouped by zone and chain.
  -- Cross-chain peers (party members on a different step of the same chain) appear
  -- as player rows beneath the relevant quest entry.

  MineTab = {}

  ------------------------------------------------------------------------
  -- Private helpers
  ------------------------------------------------------------------------

  -- Looks up chainInfo for any questID. Uses AQL cache; falls back to provider
  -- for remote questIDs not in the local log.
  local function getChainInfoForQuestID(questID)
      local AQL = SocialQuest.AQL
      local ci = AQL:GetChainInfo(questID)
      if ci.knownStatus == "known" then return ci end
      local provider = AQL.provider
      if provider then
          local ok, result = pcall(provider.GetChainInfo, provider, questID)
          if ok and result and result.knownStatus == "known" then return result end
      end
      return ci
  end

  ------------------------------------------------------------------------
  -- Tab provider interface
  ------------------------------------------------------------------------

  function MineTab:GetLabel()
      return "Mine"
  end

  -- Builds the zone/chain/quest tree from local AQL data + GroupData chain peers.
  -- Returns: { zones = { [zoneName] = { name, order, chains, quests } } }
  function MineTab:BuildTree()
      local AQL = SocialQuest.AQL
      if not AQL then return { zones = {} } end

      local tree     = { zones = {} }
      local orderIdx = 0

      for questID, questInfo in pairs(AQL:GetAllQuests()) do
          local zoneName = questInfo.zone or "Other Quests"

          if not tree.zones[zoneName] then
              orderIdx = orderIdx + 1
              tree.zones[zoneName] = {
                  name   = zoneName,
                  order  = orderIdx,
                  chains = {},
                  quests = {},
              }
          end
          local zone = tree.zones[zoneName]

          -- Build questEntry from local AQL data.
          local entry = {
              questID        = questInfo.questID,
              title          = questInfo.title,
              level          = questInfo.level,
              zone           = zoneName,
              isComplete     = questInfo.isComplete,
              isFailed       = questInfo.isFailed,
              isTracked      = questInfo.isTracked,
              logIndex       = questInfo.logIndex,
              suggestedGroup = questInfo.suggestedGroup,
              timerSeconds   = questInfo.timerSeconds,
              snapshotTime   = questInfo.snapshotTime,
              wowheadUrl     = questInfo.wowheadUrl,
              chainInfo      = questInfo.chainInfo,
              objectives     = questInfo.objectives,
              players        = {},
          }

          local ci = questInfo.chainInfo
          if ci and ci.knownStatus == "known" and ci.chainID then
              -- Place in chain group.
              local chainID = ci.chainID
              if not zone.chains[chainID] then
                  zone.chains[chainID] = { title = questInfo.title, steps = {} }
              end
              -- Prefer the title of step 1 as the chain label (deterministic).
              if ci.step == 1 then
                  zone.chains[chainID].title = questInfo.title
              end
              table.insert(zone.chains[chainID].steps, entry)

              -- Find cross-chain peers: party members on the same chain, different step.
              for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
                  if playerData.quests then
                      for pQuestID in pairs(playerData.quests) do
                          local pCI = getChainInfoForQuestID(pQuestID)
                          if pCI.knownStatus == "known"
                              and pCI.chainID == chainID
                              and pCI.step    ~= ci.step then
                              table.insert(entry.players, {
                                  name         = playerName,
                                  isMe         = false,
                                  hasSocialQuest = playerData.hasSocialQuest,
                                  step         = pCI.step,
                                  chainLength  = pCI.length,
                                  objectives   = {},
                                  isComplete   = playerData.quests[pQuestID] and
                                                 playerData.quests[pQuestID].isComplete or false,
                                  hasCompleted = false,
                                  needsShare   = false,
                              })
                          end
                      end
                  end
              end
          else
              table.insert(zone.quests, entry)
          end
      end

      -- Sort chain steps ascending by step number.
      for _, zone in pairs(tree.zones) do
          for _, chain in pairs(zone.chains) do
              table.sort(chain.steps, function(a, b)
                  local aStep = a.chainInfo and a.chainInfo.step or 0
                  local bStep = b.chainInfo and b.chainInfo.step or 0
                  return aStep < bStep
              end)
          end
      end

      return tree
  end

  -- Renders the Mine tree into contentFrame using RowFactory.
  -- tabCollapsedZones: the mine-tab subtable from SocialQuestDB.profile.frameState.collapsedZones.
  -- Returns: total content height (number).
  function MineTab:Render(contentFrame, rowFactory, tabCollapsedZones)
      local tree  = self:BuildTree()
      local y     = 0
      local zones = tree.zones

      -- Collect zones sorted by insertion order.
      local sortedZones = {}
      for _, zone in pairs(zones) do
          table.insert(sortedZones, zone)
      end
      table.sort(sortedZones, function(a, b) return a.order < b.order end)

      for _, zone in ipairs(sortedZones) do
          local zoneName    = zone.name
          local isCollapsed = tabCollapsedZones[zoneName] == true

          y = rowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, function()
              SocialQuestGroupFrame:ToggleZone("mine", zoneName)
          end)

          if not isCollapsed then
              local QUEST_INDENT = 16
              local PEER_INDENT  = 32
              local OBJ_INDENT   = 32

              -- Sort chainIDs numerically ascending.
              local sortedChainIDs = {}
              for chainID in pairs(zone.chains) do
                  table.insert(sortedChainIDs, chainID)
              end
              table.sort(sortedChainIDs)

              for _, chainID in ipairs(sortedChainIDs) do
                  local chain = zone.chains[chainID]
                  y = rowFactory.AddChainHeader(contentFrame, y, chain.title, QUEST_INDENT)

                  for _, entry in ipairs(chain.steps) do
                      local callbacks = {
                          onTitleShiftClick = function(logIndex, isTracked)
                              if isTracked then
                                  RemoveQuestWatch(logIndex)
                              else
                                  AddQuestWatch(logIndex)
                              end
                              -- Trigger a cache rebuild so isTracked updates.
                              SocialQuest.AQL.QuestCache:Rebuild()
                              SocialQuestGroupFrame:Refresh()
                          end,
                      }
                      y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, callbacks)

                      for _, obj in ipairs(entry.objectives or {}) do
                          y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT + 8)
                      end

                      for _, peer in ipairs(entry.players) do
                          y = rowFactory.AddPlayerRow(contentFrame, y, peer, PEER_INDENT + 8)
                      end
                  end
              end

              -- Standalone quests (no chain info).
              for _, entry in ipairs(zone.quests) do
                  local callbacks = {
                      onTitleShiftClick = function(logIndex, isTracked)
                          if isTracked then
                              RemoveQuestWatch(logIndex)
                          else
                              AddQuestWatch(logIndex)
                          end
                          SocialQuest.AQL.QuestCache:Rebuild()
                          SocialQuestGroupFrame:Refresh()
                      end,
                  }
                  y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, callbacks)

                  for _, obj in ipairs(entry.objectives or {}) do
                      y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                  end
              end
          end
      end

      return math.max(y, 10)
  end
  ```

- [ ] **Step 2: Verify MineTab loads and BuildTree works in-game**

  Copy the addon and `/reload`. In WowLua:

  ```lua
  -- Confirm module loaded.
  print(type(MineTab.BuildTree))   -- expected: function
  print(type(MineTab.Render))      -- expected: function

  -- Confirm tree structure has expected zones.
  local tree = MineTab:BuildTree()
  local zoneCount = 0
  for zoneName, zone in pairs(tree.zones) do
      zoneCount = zoneCount + 1
      local chainCount, questCount = 0, 0
      for _ in pairs(zone.chains) do chainCount = chainCount + 1 end
      for _ in ipairs(zone.quests) do questCount = questCount + 1 end
      print(zoneName, "chains:", chainCount, "standalone:", questCount)
  end
  print("Total zones:", zoneCount)
  ```

  Expected: at least one zone printed, totals matching your active quest log. Quests with known chain info appear under `chains`; standalone quests appear under `quests`. No Lua errors.

---

## Chunk 4: PartyTab

### Task 7: Create UI/Tabs/PartyTab.lua

**Files:**
- Create: `Social-Quest/UI/Tabs/PartyTab.lua`

PartyTab shows every quest encountered across all party members, grouped by zone/chain. Each quest is listed once; players appear beneath it with per-player state rows.

- [ ] **Step 1: Create Social-Quest/UI/Tabs/PartyTab.lua**

  ```lua
  -- UI/Tabs/PartyTab.lua
  -- Party tab provider. Shows all quests across the party (quest-centric).
  -- Each quest appears once; party members with relevant state appear beneath it.

  PartyTab = {}

  ------------------------------------------------------------------------
  -- Private helpers
  ------------------------------------------------------------------------

  -- Returns zone name for a questID using local AQL cache; falls back to "Other Quests".
  local function getZoneForQuestID(questID)
      local info = SocialQuest.AQL:GetQuest(questID)
      if info and info.zone then return info.zone end
      return "Other Quests"
  end

  -- Returns chainInfo for any questID; tries provider for remote quests.
  local function getChainInfoForQuestID(questID)
      local AQL = SocialQuest.AQL
      local ci = AQL:GetChainInfo(questID)
      if ci.knownStatus == "known" then return ci end
      local provider = AQL.provider
      if provider then
          local ok, result = pcall(provider.GetChainInfo, provider, questID)
          if ok and result and result.knownStatus == "known" then return result end
      end
      return ci
  end

  -- Builds objective rows for the local player from AQL questInfo.
  local function buildLocalObjectives(questInfo)
      local objs = {}
      for i, obj in ipairs(questInfo.objectives or {}) do
          objs[i] = {
              text         = obj.text or "",
              isFinished   = obj.isFinished,
              numFulfilled = obj.numFulfilled,
              numRequired  = obj.numRequired,
          }
      end
      return objs
  end

  -- Builds objective rows for a remote player from GroupData quest entry.
  local function buildRemoteObjectives(pquest)
      local objs = {}
      for i, obj in ipairs(pquest.objectives or {}) do
          local text = tostring(obj.numFulfilled or 0) .. "/" .. tostring(obj.numRequired or 1)
          objs[i] = {
              text         = text,
              isFinished   = obj.isFinished,
              numFulfilled = obj.numFulfilled or 0,
              numRequired  = obj.numRequired  or 1,
          }
      end
      return objs
  end

  -- Builds the ordered list of playerEntry rows for one questID.
  -- localHasIt: true when AQL:GetQuest(questID) is non-nil.
  local function buildPlayerRowsForQuest(questID, localHasIt)
      local AQL     = SocialQuest.AQL
      local players = {}

      -- Local player row (always first when local player has any stake).
      local myInfo = AQL:GetQuest(questID)
      if myInfo then
          local ci = myInfo.chainInfo
          table.insert(players, {
              name           = "(You)",
              isMe           = true,
              hasSocialQuest = true,
              hasCompleted   = false,
              needsShare     = false,
              objectives     = buildLocalObjectives(myInfo),
              step           = ci and ci.knownStatus == "known" and ci.step       or nil,
              chainLength    = ci and ci.knownStatus == "known" and ci.length     or nil,
          })
      elseif AQL:HasCompletedQuest(questID) then
          table.insert(players, {
              name           = "(You)",
              isMe           = true,
              hasSocialQuest = true,
              hasCompleted   = true,
              needsShare     = false,
              objectives     = {},
          })
      end

      -- Party member rows.
      for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
          local hasQuest    = playerData.quests and playerData.quests[questID] ~= nil
          local hasCompleted = playerData.completedQuests and
                               playerData.completedQuests[questID] == true

          if hasCompleted then
              table.insert(players, {
                  name           = playerName,
                  isMe           = false,
                  hasSocialQuest = playerData.hasSocialQuest,
                  hasCompleted   = true,
                  needsShare     = false,
                  objectives     = {},
              })
          elseif hasQuest then
              local pquest = playerData.quests[questID]
              local pCI    = getChainInfoForQuestID(questID)
              table.insert(players, {
                  name           = playerName,
                  isMe           = false,
                  hasSocialQuest = playerData.hasSocialQuest,
                  hasCompleted   = false,
                  needsShare     = false,
                  objectives     = buildRemoteObjectives(pquest),
                  step           = pCI.knownStatus == "known" and pCI.step   or nil,
                  chainLength    = pCI.knownStatus == "known" and pCI.length or nil,
              })
          elseif localHasIt then
              -- Party member lacks the quest; local player has it → "Needs it Shared".
              table.insert(players, {
                  name           = playerName,
                  isMe           = false,
                  hasSocialQuest = playerData.hasSocialQuest,
                  hasCompleted   = false,
                  needsShare     = true,
                  objectives     = {},
              })
          end
          -- else: member has no stake and local doesn't have it → omit.
      end

      return players
  end

  ------------------------------------------------------------------------
  -- Tab provider interface
  ------------------------------------------------------------------------

  function PartyTab:GetLabel()
      return "Party"
  end

  -- Builds the zone/chain/quest tree from all party members + local player.
  function PartyTab:BuildTree()
      local AQL = SocialQuest.AQL
      if not AQL then return { zones = {} } end

      -- Collect all unique questIDs from local player and all party members.
      local allQuestIDs = {}
      for questID in pairs(AQL:GetAllQuests()) do
          allQuestIDs[questID] = true
      end
      for _, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
          if playerData.quests then
              for questID in pairs(playerData.quests) do
                  allQuestIDs[questID] = true
              end
          end
      end

      local tree     = { zones = {} }
      local orderIdx = 0

      for questID in pairs(allQuestIDs) do
          local zoneName = getZoneForQuestID(questID)
          if not tree.zones[zoneName] then
              orderIdx = orderIdx + 1
              tree.zones[zoneName] = {
                  name   = zoneName,
                  order  = orderIdx,
                  chains = {},
                  quests = {},
              }
          end
          local zone = tree.zones[zoneName]

          local localInfo    = AQL:GetQuest(questID)
          local ci           = localInfo and localInfo.chainInfo or getChainInfoForQuestID(questID)
          local localHasIt   = localInfo ~= nil

          local entry = {
              questID        = questID,
              title          = localInfo and localInfo.title or ("Quest " .. questID),
              level          = localInfo and localInfo.level or 0,
              zone           = zoneName,
              isComplete     = localInfo and localInfo.isComplete or false,
              isFailed       = localInfo and localInfo.isFailed   or false,
              isTracked      = false,
              logIndex       = localInfo and localInfo.logIndex,
              suggestedGroup = localInfo and localInfo.suggestedGroup or 0,
              timerSeconds   = localInfo and localInfo.timerSeconds,
              snapshotTime   = localInfo and localInfo.snapshotTime,
              wowheadUrl     = localInfo and localInfo.wowheadUrl
                               or ("https://www.wowhead.com/tbc/quest=" .. questID),
              chainInfo      = ci,
              objectives     = localInfo and localInfo.objectives or {},
              players        = buildPlayerRowsForQuest(questID, localHasIt),
          }

          if ci.knownStatus == "known" and ci.chainID then
              local chainID = ci.chainID
              if not zone.chains[chainID] then
                  zone.chains[chainID] = { title = entry.title, steps = {} }
              end
              table.insert(zone.chains[chainID].steps, entry)
          else
              table.insert(zone.quests, entry)
          end
      end

      -- Sort chain steps ascending.
      for _, zone in pairs(tree.zones) do
          for _, chain in pairs(zone.chains) do
              table.sort(chain.steps, function(a, b)
                  local aS = a.chainInfo and a.chainInfo.step or 0
                  local bS = b.chainInfo and b.chainInfo.step or 0
                  return aS < bS
              end)
          end
      end

      return tree
  end

  -- Renders the Party tree into contentFrame using RowFactory.
  function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones)
      local tree = self:BuildTree()
      local y    = 0

      local sortedZones = {}
      for _, zone in pairs(tree.zones) do
          table.insert(sortedZones, zone)
      end
      table.sort(sortedZones, function(a, b) return a.order < b.order end)

      for _, zone in ipairs(sortedZones) do
          local zoneName    = zone.name
          local isCollapsed = tabCollapsedZones[zoneName] == true

          y = rowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, function()
              SocialQuestGroupFrame:ToggleZone("party", zoneName)
          end)

          if not isCollapsed then
              local QUEST_INDENT  = 16
              local PLAYER_INDENT = 32
              local OBJ_INDENT    = 48

              local sortedChainIDs = {}
              for chainID in pairs(zone.chains) do
                  table.insert(sortedChainIDs, chainID)
              end
              table.sort(sortedChainIDs)

              for _, chainID in ipairs(sortedChainIDs) do
                  local chain = zone.chains[chainID]
                  y = rowFactory.AddChainHeader(contentFrame, y, chain.title, QUEST_INDENT)

                  for _, entry in ipairs(chain.steps) do
                      y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                      for _, player in ipairs(entry.players) do
                          y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8)
                          if not player.hasCompleted and not player.needsShare then
                              for _, obj in ipairs(player.objectives or {}) do
                                  y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                              end
                          end
                      end
                  end
              end

              for _, entry in ipairs(zone.quests) do
                  y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                  for _, player in ipairs(entry.players) do
                      y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT)
                      if not player.hasCompleted and not player.needsShare then
                          for _, obj in ipairs(player.objectives or {}) do
                              y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                          end
                      end
                  end
              end
          end
      end

      return math.max(y, 10)
  end
  ```

- [ ] **Step 2: Verify file structure (manual)**

  Confirm: `GetLabel`, `BuildTree`, `Render` present. 5 local helpers (getZoneForQuestID, getChainInfoForQuestID, buildLocalObjectives, buildRemoteObjectives, buildPlayerRowsForQuest). No `TODO` markers.

---

## Chunk 5: SharedTab

### Task 8: Create UI/Tabs/SharedTab.lua

**Files:**
- Create: `Social-Quest/UI/Tabs/SharedTab.lua`

SharedTab shows quests where 2+ players are engaged (same questID or same chainID different step). No FINISHED / Needs-it-Shared rows — all listed players are actively engaged.

- [ ] **Step 1: Create Social-Quest/UI/Tabs/SharedTab.lua**

  ```lua
  -- UI/Tabs/SharedTab.lua
  -- Shared tab provider. Shows quests engaged by 2+ players (chain-peer aware).
  -- "Engaged" = has questID in active log OR is on a different step of the same chain.
  -- No FINISHED or Needs-it-Shared rows on this tab.

  SharedTab = {}

  ------------------------------------------------------------------------
  -- Private helpers
  ------------------------------------------------------------------------

  local function getZoneForQuestID(questID)
      local info = SocialQuest.AQL:GetQuest(questID)
      if info and info.zone then return info.zone end
      return "Other Quests"
  end

  local function getChainInfoForQuestID(questID)
      local AQL = SocialQuest.AQL
      local ci = AQL:GetChainInfo(questID)
      if ci.knownStatus == "known" then return ci end
      local provider = AQL.provider
      if provider then
          local ok, result = pcall(provider.GetChainInfo, provider, questID)
          if ok and result and result.knownStatus == "known" then return result end
      end
      return ci
  end

  local function buildLocalObjectives(questInfo)
      local objs = {}
      for i, obj in ipairs(questInfo.objectives or {}) do
          objs[i] = {
              text         = obj.text or "",
              isFinished   = obj.isFinished,
              numFulfilled = obj.numFulfilled,
              numRequired  = obj.numRequired,
          }
      end
      return objs
  end

  local function buildRemoteObjectives(pquest)
      local objs = {}
      for i, obj in ipairs(pquest.objectives or {}) do
          local text = tostring(obj.numFulfilled or 0) .. "/" .. tostring(obj.numRequired or 1)
          objs[i] = {
              text         = text,
              isFinished   = obj.isFinished,
              numFulfilled = obj.numFulfilled or 0,
              numRequired  = obj.numRequired  or 1,
          }
      end
      return objs
  end

  ------------------------------------------------------------------------
  -- Tab provider interface
  ------------------------------------------------------------------------

  function SharedTab:GetLabel()
      return "Shared"
  end

  -- Builds the zone/chain/quest tree for quests engaged by 2+ players.
  function SharedTab:BuildTree()
      local AQL = SocialQuest.AQL
      if not AQL then return { zones = {} } end

      -- Step 1: gather all engagements.
      -- chainEngaged[chainID][playerName] = { questID, step, chainLength, isLocal, qdata }
      -- questEngaged[questID][playerName] = { isLocal, qdata }
      local chainEngaged = {}
      local questEngaged = {}

      local function addEngagement(questID, playerName, isLocal, qdata)
          local ci = getChainInfoForQuestID(questID)
          if ci.knownStatus == "known" and ci.chainID then
              local cid = ci.chainID
              if not chainEngaged[cid] then chainEngaged[cid] = {} end
              chainEngaged[cid][playerName] = {
                  questID     = questID,
                  step        = ci.step,
                  chainLength = ci.length,
                  isLocal     = isLocal,
                  qdata       = qdata,
              }
          else
              if not questEngaged[questID] then questEngaged[questID] = {} end
              questEngaged[questID][playerName] = { isLocal = isLocal, qdata = qdata }
          end
      end

      for questID, questInfo in pairs(AQL:GetAllQuests()) do
          addEngagement(questID, "(You)", true, questInfo)
      end
      for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
          if playerData.quests then
              for questID, qdata in pairs(playerData.quests) do
                  addEngagement(questID, playerName, false, qdata)
              end
          end
      end

      -- Step 2: build tree from groups with 2+ engaged players.
      local tree     = { zones = {} }
      local orderIdx = 0

      local function ensureZone(zoneName)
          if not tree.zones[zoneName] then
              orderIdx = orderIdx + 1
              tree.zones[zoneName] = {
                  name = zoneName, order = orderIdx, chains = {}, quests = {},
              }
          end
          return tree.zones[zoneName]
      end

      -- Process chain groups.
      for chainID, engaged in pairs(chainEngaged) do
          local count = 0
          for _ in pairs(engaged) do count = count + 1 end
          if count >= 2 then
              -- Determine zone: prefer local player's zone; fall back to "Other Quests".
              local zoneName = "Other Quests"
              for _, eng in pairs(engaged) do
                  if eng.isLocal then
                      local info = AQL:GetQuest(eng.questID)
                      if info and info.zone then zoneName = info.zone; break end
                  end
              end
              local zone = ensureZone(zoneName)

              if not zone.chains[chainID] then
                  zone.chains[chainID] = { title = "Chain " .. chainID, steps = {} }
              end
              -- Prefer step 1's title as the chain label (deterministic across pairs() order).

              -- One questEntry per distinct questID in the chain.
              local addedQuestIDs = {}
              for playerName, eng in pairs(engaged) do
                  if not addedQuestIDs[eng.questID] then
                      addedQuestIDs[eng.questID] = true
                      local localInfo = AQL:GetQuest(eng.questID)
                      local ci = getChainInfoForQuestID(eng.questID)

                      -- Update chain title: prefer step 1 (deterministic regardless of pairs order).
                      -- `ci` was computed two lines above for this same questID.
                      if localInfo and localInfo.title and ci.step == 1 then
                          zone.chains[chainID].title = localInfo.title
                      elseif localInfo and localInfo.title and
                          zone.chains[chainID].title == "Chain " .. chainID then
                          -- Fallback: use any local title if step 1 not encountered yet.
                          zone.chains[chainID].title = localInfo.title
                      end

                      local entry = {
                          questID        = eng.questID,
                          title          = localInfo and localInfo.title
                                           or ("Quest " .. eng.questID),
                          level          = localInfo and localInfo.level or 0,
                          zone           = zoneName,
                          isComplete     = localInfo and localInfo.isComplete or false,
                          isFailed       = localInfo and localInfo.isFailed   or false,
                          isTracked      = false,
                          logIndex       = localInfo and localInfo.logIndex,
                          suggestedGroup = localInfo and localInfo.suggestedGroup or 0,
                          timerSeconds   = localInfo and localInfo.timerSeconds,
                          snapshotTime   = localInfo and localInfo.snapshotTime,
                          wowheadUrl     = localInfo and localInfo.wowheadUrl
                                           or ("https://www.wowhead.com/tbc/quest=" .. eng.questID),
                          chainInfo      = ci,
                          objectives     = localInfo and localInfo.objectives or {},
                          players        = {},
                      }

                      -- Players engaged with this specific questID step.
                      for pName, pEng in pairs(engaged) do
                          if pEng.questID == eng.questID then
                              if pEng.isLocal then
                                  local info = AQL:GetQuest(pEng.questID)
                                  table.insert(entry.players, {
                                      name           = pName,
                                      isMe           = true,
                                      hasSocialQuest = true,
                                      hasCompleted   = false,
                                      needsShare     = false,
                                      objectives     = buildLocalObjectives(info or {}),
                                      step           = pEng.step,
                                      chainLength    = pEng.chainLength,
                                  })
                              else
                                  local playerData = SocialQuestGroupData.PlayerQuests[pName]
                                  table.insert(entry.players, {
                                      name           = pName,
                                      isMe           = false,
                                      hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                                      hasCompleted   = false,
                                      needsShare     = false,
                                      objectives     = buildRemoteObjectives(pEng.qdata or {}),
                                      step           = pEng.step,
                                      chainLength    = pEng.chainLength,
                                  })
                              end
                          end
                      end

                      table.insert(zone.chains[chainID].steps, entry)
                  end
              end

              -- Sort steps ascending.
              table.sort(zone.chains[chainID].steps, function(a, b)
                  local aS = a.chainInfo and a.chainInfo.step or 0
                  local bS = b.chainInfo and b.chainInfo.step or 0
                  return aS < bS
              end)
          end
      end

      -- Process standalone quest groups.
      for questID, engaged in pairs(questEngaged) do
          local count = 0
          for _ in pairs(engaged) do count = count + 1 end
          if count >= 2 then
              local zoneName  = getZoneForQuestID(questID)
              local zone      = ensureZone(zoneName)
              local localInfo = AQL:GetQuest(questID)

              local entry = {
                  questID        = questID,
                  title          = localInfo and localInfo.title or ("Quest " .. questID),
                  level          = localInfo and localInfo.level or 0,
                  zone           = zoneName,
                  isComplete     = localInfo and localInfo.isComplete or false,
                  isFailed       = localInfo and localInfo.isFailed   or false,
                  isTracked      = false,
                  logIndex       = localInfo and localInfo.logIndex,
                  suggestedGroup = localInfo and localInfo.suggestedGroup or 0,
                  timerSeconds   = localInfo and localInfo.timerSeconds,
                  snapshotTime   = localInfo and localInfo.snapshotTime,
                  wowheadUrl     = localInfo and localInfo.wowheadUrl
                                   or ("https://www.wowhead.com/tbc/quest=" .. questID),
                  chainInfo      = { knownStatus = "unknown" },
                  objectives     = localInfo and localInfo.objectives or {},
                  players        = {},
              }

              for playerName, eng in pairs(engaged) do
                  if eng.isLocal then
                      table.insert(entry.players, {
                          name           = playerName,
                          isMe           = true,
                          hasSocialQuest = true,
                          hasCompleted   = false,
                          needsShare     = false,
                          objectives     = buildLocalObjectives(localInfo or {}),
                      })
                  else
                      local playerData = SocialQuestGroupData.PlayerQuests[playerName]
                      table.insert(entry.players, {
                          name           = playerName,
                          isMe           = false,
                          hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                          hasCompleted   = false,
                          needsShare     = false,
                          objectives     = buildRemoteObjectives(eng.qdata or {}),
                      })
                  end
              end

              table.insert(zone.quests, entry)
          end
      end

      return tree
  end

  -- Renders the Shared tree into contentFrame using RowFactory.
  function SharedTab:Render(contentFrame, rowFactory, tabCollapsedZones)
      local tree = self:BuildTree()
      local y    = 0

      local sortedZones = {}
      for _, zone in pairs(tree.zones) do
          table.insert(sortedZones, zone)
      end
      table.sort(sortedZones, function(a, b) return a.order < b.order end)

      for _, zone in ipairs(sortedZones) do
          local zoneName    = zone.name
          local isCollapsed = tabCollapsedZones[zoneName] == true

          y = rowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, function()
              SocialQuestGroupFrame:ToggleZone("shared", zoneName)
          end)

          if not isCollapsed then
              local QUEST_INDENT  = 16
              local PLAYER_INDENT = 32
              local OBJ_INDENT    = 48

              local sortedChainIDs = {}
              for chainID in pairs(zone.chains) do
                  table.insert(sortedChainIDs, chainID)
              end
              table.sort(sortedChainIDs)

              for _, chainID in ipairs(sortedChainIDs) do
                  local chain = zone.chains[chainID]
                  y = rowFactory.AddChainHeader(contentFrame, y, chain.title, QUEST_INDENT)
                  for _, entry in ipairs(chain.steps) do
                      y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                      for _, player in ipairs(entry.players) do
                          y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8)
                          -- On Shared tab all players are actively engaged (spec Section 8.3),
                          -- so hasCompleted and needsShare are always false. Guard kept for symmetry.
                          if not player.hasCompleted and not player.needsShare then
                              for _, obj in ipairs(player.objectives or {}) do
                                  y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                              end
                          end
                      end
                  end
              end

              for _, entry in ipairs(zone.quests) do
                  y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                  for _, player in ipairs(entry.players) do
                      y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT)
                      if not player.hasCompleted and not player.needsShare then
                          for _, obj in ipairs(player.objectives or {}) do
                              y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                          end
                      end
                  end
              end
          end
      end

      return math.max(y, 10)
  end
  ```

- [ ] **Step 2: Verify file structure (manual)**

  Confirm: `GetLabel`, `BuildTree`, `Render` present. 4 module-level local helpers (`getZoneForQuestID`, `getChainInfoForQuestID`, `buildLocalObjectives`, `buildRemoteObjectives`). Additionally, `addEngagement` and `ensureZone` are defined as `local function` closures **inside** `BuildTree` — they are not module-level helpers. No `TODO` markers.

---

## Chunk 6: GroupFrame Refactor + TOC

### Task 9: Refactor GroupFrame.lua

**Files:**
- Modify: `Social-Quest/UI/GroupFrame.lua`

Replace the three inline Render* functions with provider dispatch. Add `SQ_WOWHEAD_POPUP` StaticPopup at module scope. Persist active tab and collapsedZones to AceDB.

- [ ] **Step 1: Write the new GroupFrame.lua**

  The complete new file (replaces all existing content):

  ```lua
  -- UI/GroupFrame.lua
  -- Group quest window. Opened via /sq or minimap button.
  -- Tab rendering is delegated to MineTab, PartyTab, SharedTab providers.
  -- Zone collapse state and active tab are persisted via AceDB frameState.

  -- Register the Wowhead URL popup at module scope (before any frame is created).
  -- RowFactory.AddQuestRow calls StaticPopup_Show("SQ_WOWHEAD_POPUP", url).
  StaticPopupDialogs["SQ_WOWHEAD_POPUP"] = {
      text         = "Quest URL (Ctrl+C to copy):",
      button1      = "Close",
      hasEditBox   = 1,
      editBoxWidth = 300,
      OnShow       = function(self)
          self.editBox:SetText(self.data or "")
          self.editBox:SetFocus()
          self.editBox:HighlightText()
      end,
      OnAccept     = function() end,
      timeout      = 0,
      whileDead    = true,
      hideOnEscape = true,
  }

  SocialQuestGroupFrame = {}

  local frame          = nil
  local refreshPending = false

  -- Ordered tab providers. The id must match the collapsedZones subtable key.
  -- MineTab/PartyTab/SharedTab are loaded before GroupFrame per TOC order, so
  -- the globals exist here and can be assigned directly.
  local providers = {
      { id = "mine",   module = MineTab   },
      { id = "party",  module = PartyTab  },
      { id = "shared", module = SharedTab },
  }

  ------------------------------------------------------------------------
  -- Frame construction
  ------------------------------------------------------------------------

  local function createFrame()
      local f = CreateFrame("Frame", "SocialQuestGroupFramePanel", UIParent,
                            "BasicFrameTemplateWithInset")
      f:SetSize(400, 500)
      f:SetPoint("CENTER")
      f:SetMovable(true)
      f:EnableMouse(true)
      f:RegisterForDrag("LeftButton")
      f:SetScript("OnDragStart", f.StartMoving)
      f:SetScript("OnDragStop", f.StopMovingOrSizing)
      f:Hide()

      f.TitleText:SetText("SocialQuest — Group Quests")

      -- Tab buttons.
      local function makeTab(id, label, offsetX)
          local tab = CreateFrame("Button", "SocialQuestTab_" .. id, f, "TabButtonTemplate")
          tab:SetPoint("TOPLEFT", f, "TOPLEFT", offsetX, -24)
          tab:SetText(label)
          tab:SetScript("OnClick", function()
              SocialQuest.db.profile.frameState.activeTab = id
              SocialQuestGroupFrame:Refresh()
          end)
          return tab
      end

      f.tabMine   = makeTab("mine",   "Mine",    10)
      f.tabParty  = makeTab("party",  "Party",   80)
      f.tabShared = makeTab("shared", "Shared", 150)

      -- Scroll area.
      f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
      f.scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     10,  -56)
      f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28,  10)

      f.content = CreateFrame("Frame", nil, f.scrollFrame)
      f.content:SetSize(360, 1)
      f.scrollFrame:SetScrollChild(f.content)

      return f
  end

  ------------------------------------------------------------------------
  -- Public API
  ------------------------------------------------------------------------

  function SocialQuestGroupFrame:Toggle()
      if not frame then
          frame = createFrame()
      end
      if frame:IsShown() then
          frame:Hide()
      else
          frame:Show()
          self:Refresh()
      end
  end

  -- Batches refreshes: at most one redraw per frame.
  function SocialQuestGroupFrame:RequestRefresh()
      if not frame or not frame:IsShown() then return end
      if refreshPending then return end
      refreshPending = true
      C_Timer.After(0, function()
          refreshPending = false
          SocialQuestGroupFrame:Refresh()
      end)
  end

  function SocialQuestGroupFrame:Refresh()
      if not frame then return end

      -- Recreate content child (GetChildren does not return FontStrings; hiding is
      -- the only clean way to discard old rows without leaking them).
      if frame.content then frame.content:Hide() end
      frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
      frame.content:SetSize(360, 1)
      frame.scrollFrame:SetScrollChild(frame.content)

      -- Find active provider.
      local activeID = SocialQuest.db.profile.frameState.activeTab or "mine"
      local activeProvider
      for _, p in ipairs(providers) do
          if p.id == activeID then
              activeProvider = p
              break
          end
      end
      if not activeProvider or not activeProvider.module then return end

      -- Per-tab collapsed zones subtable.
      local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
      local tabCollapsed   = collapsedZones[activeID] or {}

      -- Delegate rendering to the tab provider.
      local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed)
      frame.content:SetHeight(math.max(totalHeight, 10))
  end

  -- Flip the collapsed state of one zone in the given tab and redraw.
  -- Absent key = expanded (spec default). Set true when collapsing, nil when expanding,
  -- so no stale false entries accumulate in the saved variable table.
  function SocialQuestGroupFrame:ToggleZone(tabId, zoneName)
      local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
      if not collapsedZones[tabId] then
          collapsedZones[tabId] = {}
      end
      if collapsedZones[tabId][zoneName] then
          collapsedZones[tabId][zoneName] = nil   -- expanded (absent key = default)
      else
          collapsedZones[tabId][zoneName] = true  -- collapsed
      end
      self:Refresh()
  end

  ------------------------------------------------------------------------
  -- Minimap button (unchanged from original)
  ------------------------------------------------------------------------

  local minimapButton = CreateFrame("Button", "SocialQuestMinimapButton", Minimap)
  minimapButton:SetSize(32, 32)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
  minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  minimapButton:SetPushedTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")

  local angle = 225
  local function updateMinimapButtonPosition()
      minimapButton:ClearAllPoints()
      local rad = math.rad(angle)
      minimapButton:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(rad), 80 * math.sin(rad))
  end
  updateMinimapButtonPosition()

  minimapButton:EnableMouse(true)
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetScript("OnDragStart", function(self)
      self:SetScript("OnUpdate", function(self)
          local cx, cy = Minimap:GetCenter()
          local mx, my = GetCursorPosition()
          local scale  = Minimap:GetEffectiveScale()
          angle = math.deg(math.atan2((my / scale) - cy, (mx / scale) - cx))
          updateMinimapButtonPosition()
      end)
  end)
  minimapButton:SetScript("OnDragStop", function(self)
      self:SetScript("OnUpdate", nil)
  end)

  minimapButton:SetScript("OnClick", function()
      SocialQuestGroupFrame:Toggle()
  end)

  minimapButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText("SocialQuest")
      GameTooltip:AddLine("Click to open group quest frame.", 1, 1, 1)
      GameTooltip:Show()
  end)
  minimapButton:SetScript("OnLeave", function()
      GameTooltip:Hide()
  end)
  ```

- [ ] **Step 2: Verify file structure (manual)**

  Confirm: `StaticPopupDialogs["SQ_WOWHEAD_POPUP"]` block, `SocialQuestGroupFrame` table, `providers` table with 3 entries (modules assigned directly — no `initProviders` function), `createFrame`, `Toggle`, `RequestRefresh`, `Refresh`, `ToggleZone`, minimap button. No `TODO` markers. The old `RenderMineTab`, `RenderSharedTab`, `RenderPartyTab` functions and `groupKey`/`formatTime`/`estimateTimer` helpers are **gone**.

---

### Task 10: Update SocialQuest.toc

**Files:**
- Modify: `Social-Quest/SocialQuest.toc`

- [ ] **Step 1: Add RowFactory and Tabs entries before GroupFrame**

  Replace the file list section of the TOC (preserve any existing `## SavedVariables`, `## OptionalDeps`, or other header fields that may be present). The file list becomes:

  ```
  ## Interface: 20505
  ## Title: SocialQuest
  ## Notes: Social quest coordination for WoW Burning Crusade Anniversary.
  ## Author: Thad Ryker
  ## Version: 2.0
  ## Dependencies: Ace3, AbsoluteQuestLog

  Util\Colors.lua
  SocialQuest.lua
  Core\GroupData.lua
  Core\Communications.lua
  Core\Announcements.lua
  UI\RowFactory.lua
  UI\Tabs\MineTab.lua
  UI\Tabs\PartyTab.lua
  UI\Tabs\SharedTab.lua
  UI\Options.lua
  UI\Tooltips.lua
  UI\GroupFrame.lua
  ```

---

### Task 11: End-to-End Integration Test

- [ ] **Step 1: Copy both addons to the WoW AddOns folder and /reload**

  Check chat for any Lua errors. The minimap button should appear.

- [ ] **Step 2: Open the frame and verify Mine tab**

  Type `/sq`. The frame should open. Expected: Mine tab is active. Your active quests appear grouped by zone (e.g. "Duskwood"), with chain quests grouped under a cyan chain label. Quest titles are coloured by difficulty. `[?]` buttons visible on each quest row.

- [ ] **Step 3: Verify the Wowhead popup**

  Click `[?]` on any quest. Expected: a StaticPopup appears with text "Quest URL (Ctrl+C to copy):" and an edit box containing a URL like `https://www.wowhead.com/tbc/quest=12345`. Close it.

- [ ] **Step 4: Verify shift-click tracking (Mine tab)**

  Shift-click a quest title. Expected: if the quest was untracked, it becomes tracked and a `[v]` checkmark appears. Shift-click again — checkmark disappears. Check the objective tracker in-game to confirm.

- [ ] **Step 5: Verify zone collapse**

  Click `[-]` next to a zone header. Expected: quests under that zone disappear; button changes to `[+]`. `/reload` and `/sq` — the zone should still be collapsed (state persisted via AceDB).

- [ ] **Step 6: Verify Party and Shared tabs (while grouped)**

  In a party, click Party tab. Expected: quests from all party members visible, grouped by zone. Player rows with objectives in yellow (incomplete) or green (complete). Members lacking the quest show "Needs it Shared" in grey.

  Shared tab: only quests where 2+ party members are engaged. No FINISHED or Needs-it-Shared rows.

- [ ] **Step 7: Verify no errors solo (empty Party/Shared)**

  Solo, click Party and Shared tabs. Expected: empty content, no Lua errors.

- [ ] **Step 8: Verify FINISHED row (requires second SocialQuest player in party)**

  Have both players in a group. One player completes and turns in a quest. After the AceComm exchange completes (may take a few seconds), open Party tab. Expected: the completing player's row shows `[Name] FINISHED` in green. If testing alone, manually set a mock entry in WowLua:

  ```lua
  local name = next(SocialQuestGroupData.PlayerQuests)
  if name then
      SocialQuestGroupData.PlayerQuests[name].completedQuests[12345] = true
      SocialQuestGroupFrame:Refresh()
  end
  ```

  Then open Party tab and verify a green FINISHED row appears for questID 12345 if that player had it.

---

### Task 12: Commit

- [ ] **Step 1: Commit all Social-Quest changes**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua UI/Tabs/MineTab.lua UI/Tabs/PartyTab.lua UI/Tabs/SharedTab.lua
  git add UI/GroupFrame.lua SocialQuest.toc
  git commit -m "feat: zone/chain grouping, tab providers, RowFactory, Wowhead popup, tracking toggle"
  ```
