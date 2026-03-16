# Quest Chain Step Annotation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Append `(Step N)` to quest accepted, completed, failed, and abandoned messages when the quest is part of a known chain, for both chat and banners (own-player and remote).

**Architecture:** Add `CHAIN_STEP_EVENTS` and `appendChainStep` to `Announcements.lua`. Thread `questInfo` (which carries `chainInfo` from the AQL snapshot) from the four relevant `SocialQuest.lua` callbacks into `OnQuestEvent` → `OnOwnQuestEvent`. For remote events, replace the existing cache-only AQL lookup in `OnRemoteQuestEvent` with the three-tier `AQL:GetQuestInfo` call that also returns `chainInfo`.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary addon API, AceLocale-3.0, AbsoluteQuestLog-1.0 (AQL)

---

## File Map

| File | What changes |
|------|-------------|
| `Core/Announcements.lua` | Add `CHAIN_STEP_EVENTS` table and `appendChainStep` helper near top of file; update `OnQuestEvent`, `OnOwnQuestEvent`, `OnRemoteQuestEvent` signatures/bodies; update 4 `TEST_DEMOS` entries |
| `SocialQuest.lua` | Pass `questInfo` as 3rd arg to `OnQuestEvent` in 4 callbacks: `OnQuestAccepted`, `OnQuestCompleted`, `OnQuestFailed`, `OnQuestAbandoned` |
| `Locales/enUS.lua` | Add `L["(Step %s)"] = true` after the existing `L[" (Step %s of %s)"]` key |
| `Locales/deDE.lua` | Add `L["(Step %s)"] = "(Schritt %s)"` |
| `Locales/esES.lua` | Add `L["(Step %s)"] = "(Paso %s)"` |
| `Locales/esMX.lua` | Add `L["(Step %s)"] = "(Paso %s)"` |
| `Locales/frFR.lua` | Add `L["(Step %s)"] = "(Étape %s)"` |
| `Locales/itIT.lua` | Add `L["(Step %s)"] = "(Passo %s)"` |
| `Locales/jaJP.lua` | Add `L["(Step %s)"] = "(ステップ %s)"` |
| `Locales/koKR.lua` | Add `L["(Step %s)"] = "(단계 %s)"` |
| `Locales/ptBR.lua` | Add `L["(Step %s)"] = "(Passo %s)"` |
| `Locales/ruRU.lua` | Add `L["(Step %s)"] = "(Шаг %s)"` |
| `Locales/zhCN.lua` | Add `L["(Step %s)"] = "(步骤 %s)"` |
| `Locales/zhTW.lua` | Add `L["(Step %s)"] = "(步驟 %s)"` |

---

## Chunk 1: Core logic in Announcements.lua

### Task 1: Add `CHAIN_STEP_EVENTS` and `appendChainStep`

**Files:**
- Modify: `Core/Announcements.lua` (top of file, after the `local L = ...` line)

- [ ] **Step 1: Add `CHAIN_STEP_EVENTS` and `appendChainStep` to `Announcements.lua`**

  Open `Core/Announcements.lua`. After the `local L = LibStub(...)` line near the top
  (currently line 30), add:

  ```lua
  -- Set of event types that carry chain-step annotation when chainInfo is known.
  -- "finished" is intentionally excluded (objectives done, not yet turned in).
  local CHAIN_STEP_EVENTS = {
      accepted  = true,
      completed = true,
      failed    = true,
      abandoned = true,
  }

  -- Appends " (Step N)" to msg when the quest is a known chain step.
  -- Returns msg unchanged when: event is not in CHAIN_STEP_EVENTS, chainInfo is nil,
  -- knownStatus != "known", or step is nil. Never errors on nil inputs.
  local function appendChainStep(msg, eventType, chainInfo)
      if not CHAIN_STEP_EVENTS[eventType] then return msg end
      if not chainInfo or chainInfo.knownStatus ~= "known" or not chainInfo.step then
          return msg
      end
      return msg .. " " .. string.format(L["(Step %s)"], chainInfo.step)
  end
  ```

  Place this block immediately after the `local L = ...` line and before the
  `local throttleQueue = {}` line.

- [ ] **Step 2: Update `OnQuestEvent` signature and body**

  Locate `function SocialQuestAnnounce:OnQuestEvent(eventType, questID)` (currently
  around line 168). Make these changes:

  **Signature** — add `questInfo` as a third parameter:
  ```lua
  function SocialQuestAnnounce:OnQuestEvent(eventType, questID, questInfo)
  ```

  **After the `local msg = formatOutboundQuestMsg(eventType, title)` line**, extract
  `chainInfo` as a local and apply `appendChainStep`:
  ```lua
      local chainInfo = questInfo and questInfo.chainInfo
      msg = appendChainStep(msg, eventType, chainInfo)
  ```

  **On the `self:OnOwnQuestEvent(eventType, title)` call**, pass the already-extracted
  `chainInfo` local as a third argument:
  ```lua
      self:OnOwnQuestEvent(eventType, title, chainInfo)
  ```

  No other changes to `OnQuestEvent`. The `questieWouldAnnounce` guard, chat-sending
  block, and `checkAllCompleted` call are untouched.

  After the edit, the relevant section of `OnQuestEvent` should look like:
  ```lua
  function SocialQuestAnnounce:OnQuestEvent(eventType, questID, questInfo)
      local db = SocialQuest.db.profile
      if not db.enabled then return end

      local AQL   = SocialQuest.AQL
      local info  = AQL and AQL:GetQuest(questID)
      local title = (info and info.title)
                 or (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)
      local msg   = formatOutboundQuestMsg(eventType, title)
      local chainInfo = questInfo and questInfo.chainInfo
      msg = appendChainStep(msg, eventType, chainInfo)

      if not questieWouldAnnounce(eventType) then
          -- ... chat sending block unchanged ...
      end

      -- Own-quest banner: fires regardless of chat suppression.
      self:OnOwnQuestEvent(eventType, title, chainInfo)

      if eventType == "completed" then
          checkAllCompleted(questID, true)
      end
  end
  ```

- [ ] **Step 3: Update `OnOwnQuestEvent` signature and body**

  Locate `function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle)` (around
  line 414). Make these changes:

  **Signature** — add `chainInfo` as a third parameter:
  ```lua
  function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle, chainInfo)
  ```

  **Replace** the existing `if msg then displayBanner(msg, eventType) end` block with:
  ```lua
      if msg then
          msg = appendChainStep(msg, eventType, chainInfo)
          displayBanner(msg, eventType)
      end
  ```

  After the edit the full function should look like:
  ```lua
  function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle, chainInfo)
      local db = SocialQuest.db.profile
      if not db.enabled then return end
      if not db.general.displayOwn then return end
      if not db.general.displayOwnEvents[eventType] then return end

      local msg = formatQuestBannerMsg(L["You"], eventType, questTitle)
      if msg then
          msg = appendChainStep(msg, eventType, chainInfo)
          displayBanner(msg, eventType)
      end
  end
  ```

- [ ] **Step 4: Update `OnRemoteQuestEvent` body**

  Locate `function SocialQuestAnnounce:OnRemoteQuestEvent(...)` (around line 346).
  Find the AQL lookup block near the bottom of the function (currently):

  ```lua
      local AQL   = SocialQuest.AQL
      local info  = AQL and AQL:GetQuest(questID)
      local title = cachedTitle
                 or (info and info.title)
                 or (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)

      local msg = formatQuestBannerMsg(sender, eventType, title)
      if msg then displayBanner(msg, eventType) end
  ```

  Replace it with:

  ```lua
      local AQL   = SocialQuest.AQL
      local info  = AQL and AQL:GetQuestInfo(questID)
      local title = cachedTitle
                 or (info and info.title)
                 or ("Quest " .. questID)
      -- Note: AQL:GetQuestTitle fallback is intentionally removed. It delegates
      -- internally to AQL:GetQuestInfo, so if GetQuestInfo returns nil (AQL unavailable
      -- or quest unknown), GetQuestTitle would also return nil — the fallback adds no
      -- resolution capability beyond what the single GetQuestInfo call already provides.
      local chainInfo = info and info.chainInfo

      local msg = formatQuestBannerMsg(sender, eventType, title)
      if msg then
          msg = appendChainStep(msg, eventType, chainInfo)
          displayBanner(msg, eventType)
      end
  ```

  Everything above this block in `OnRemoteQuestEvent` (the `db` checks, section gating,
  friends-only filter, `checkAllCompleted` call) is **untouched**.

- [ ] **Step 5: Update `TEST_DEMOS` entries**

  Locate the `TEST_DEMOS` table in `Core/Announcements.lua` (around line 476). Update
  the four affected entries by appending `" (Step 2)"` to both `outbound` and `banner`
  strings:

  ```lua
  accepted = {
      outbound = "Quest accepted: A Daunting Task (Step 2)",
      banner   = "TestPlayer accepted: [A Daunting Task] (Step 2)",
      colorKey = "accepted",
  },
  abandoned = {
      outbound = "Quest abandoned: A Daunting Task (Step 2)",
      banner   = "TestPlayer abandoned: [A Daunting Task] (Step 2)",
      colorKey = "abandoned",
  },
  completed = {
      outbound = "Quest turned in: A Daunting Task (Step 2)",
      banner   = "TestPlayer completed: [A Daunting Task] (Step 2)",
      colorKey = "completed",
  },
  failed = {
      outbound = "Quest failed: A Daunting Task (Step 2)",
      banner   = "TestPlayer failed: [A Daunting Task] (Step 2)",
      colorKey = "failed",
  },
  ```

  The `finished`, `objective_*`, and `all_complete` entries are unchanged. `finished`
  is excluded from `CHAIN_STEP_EVENTS` because it fires when objectives are complete but
  the quest has not yet been turned in — annotating it with a step number is out of
  scope per the spec. Do not add `"finished"` to `CHAIN_STEP_EVENTS`.

  Note: `TestEvent` calls `displayBanner(demo.banner, ...)` with the literal string
  directly — no chain detection runs in the test path. Updating the hardcoded strings
  is sufficient to make the test panel preview the annotated format.

- [ ] **Step 6: Commit Announcements.lua changes**

  ```bash
  git add Core/Announcements.lua
  git commit -m "feat: append (Step N) to chain quest messages in banners and chat"
  ```

---

## Chunk 2: SocialQuest.lua callback updates

### Task 2: Pass `questInfo` from the four AQL callbacks

**Files:**
- Modify: `SocialQuest.lua` (four callback functions)

- [ ] **Step 7: Update `OnQuestAccepted`**

  Locate `function SocialQuest:OnQuestAccepted(event, questInfo)` (around line 282).
  Change the `OnQuestEvent` call from:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID)
  ```
  to:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
  ```

- [ ] **Step 8: Update `OnQuestCompleted`**

  Locate `function SocialQuest:OnQuestCompleted(event, questInfo)` (around line 297).
  Change:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID)
  ```
  to:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID, questInfo)
  ```

- [ ] **Step 9: Update `OnQuestFailed`**

  Locate `function SocialQuest:OnQuestFailed(event, questInfo)` (around line 302).
  Change:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID)
  ```
  to:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID, questInfo)
  ```

- [ ] **Step 10: Update `OnQuestAbandoned`**

  Locate `function SocialQuest:OnQuestAbandoned(event, questInfo)` (around line 287).
  Change:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID)
  ```
  to:
  ```lua
  SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID, questInfo)
  ```

  **Do NOT touch `OnQuestFinished`** — it intentionally passes no `questInfo`, which
  causes `questInfo` to be nil in `OnQuestEvent`, making `appendChainStep` a no-op for
  the `finished` event. This is correct behavior. Add a comment to `OnQuestFinished` to
  protect against future regressions:
  ```lua
  function SocialQuest:OnQuestFinished(event, questInfo)
      -- questInfo intentionally NOT passed: "finished" is excluded from chain-step
      -- annotation. See CHAIN_STEP_EVENTS in Core/Announcements.lua.
      SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
      SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
  end
  ```

- [ ] **Step 11: Commit SocialQuest.lua changes**

  ```bash
  git add SocialQuest.lua
  git commit -m "feat: forward questInfo to OnQuestEvent for chain step lookup"
  ```

---

## Chunk 3: Locale files

### Task 3: Add `L["(Step %s)"]` to all 12 locale files

**Files:**
- Modify: `Locales/enUS.lua` and 11 non-English locale files

The new key belongs in the `RowFactory.lua` section of each locale file, immediately
after the existing `L[" (Step %s of %s)"]` key (line 69 in enUS.lua). Use the same
comment format as surrounding keys.

Note: the key is `L["(Step %s)"]` with **no leading space** — the space before
`(Step N)` is already provided by the explicit `" "` separator in `appendChainStep`.
This is intentionally different from the sibling `L[" (Step %s of %s)"]` which has a
leading space because it is concatenated directly without a separator.

- [ ] **Step 12: Confirm locale file list is exhaustive**

  Run:
  ```bash
  ls "D:/Projects/Wow Addons/Social-Quest/Locales/"
  ```
  Confirm the output lists exactly these 12 files and no others:
  `enUS.lua deDE.lua esES.lua esMX.lua frFR.lua itIT.lua jaJP.lua koKR.lua ptBR.lua ruRU.lua zhCN.lua zhTW.lua`

  If any additional locale files exist, add `L["(Step %s)"]` to them too following the
  same pattern as the steps below.

- [ ] **Step 13: Add key to `Locales/enUS.lua`**

  After the line `L[" (Step %s of %s)"]  = true`, add:
  ```lua
  L["(Step %s)"]                              = true
  ```

- [ ] **Step 14: Add key to `Locales/deDE.lua`**

  Find the existing `L[" (Step %s of %s)"]` line and add immediately after:
  ```lua
  L["(Step %s)"] = "(Schritt %s)"
  ```

- [ ] **Step 15: Add key to `Locales/esES.lua`**

  ```lua
  L["(Step %s)"] = "(Paso %s)"
  ```

- [ ] **Step 16: Add key to `Locales/esMX.lua`**

  ```lua
  L["(Step %s)"] = "(Paso %s)"
  ```

- [ ] **Step 17: Add key to `Locales/frFR.lua`**

  ```lua
  L["(Step %s)"] = "(Étape %s)"
  ```

- [ ] **Step 18: Add key to `Locales/itIT.lua`**

  ```lua
  L["(Step %s)"] = "(Passo %s)"
  ```

- [ ] **Step 19: Add key to `Locales/jaJP.lua`**

  ```lua
  L["(Step %s)"] = "(ステップ %s)"
  ```

- [ ] **Step 20: Add key to `Locales/koKR.lua`**

  ```lua
  L["(Step %s)"] = "(단계 %s)"
  ```

- [ ] **Step 21: Add key to `Locales/ptBR.lua`**

  ```lua
  L["(Step %s)"] = "(Passo %s)"
  ```

- [ ] **Step 22: Add key to `Locales/ruRU.lua`**

  ```lua
  L["(Step %s)"] = "(Шаг %s)"
  ```

- [ ] **Step 23: Add key to `Locales/zhCN.lua`**

  ```lua
  L["(Step %s)"] = "(步骤 %s)"
  ```

- [ ] **Step 24: Add key to `Locales/zhTW.lua`**

  ```lua
  L["(Step %s)"] = "(步驟 %s)"
  ```

- [ ] **Step 25: Commit all locale changes**

  ```bash
  git add Locales/
  git commit -m "feat: add (Step N) locale key for chain step annotation"
  ```

---

## Chunk 4: In-game verification

### Task 4: Verify in WoW

Load the addon in TBC Classic Anniversary with Questie or QuestWeaver installed.

- [ ] **Step 25: Verify test panel shows step annotation**

  Open SQ options (`/sq config` → Debug → Test Banners and Chat). Click **Test Accepted**
  and **Test Completed**.
  - Banner should show `"TestPlayer accepted: [A Daunting Task] (Step 2)"`
  - Chat preview should show `"Quest accepted: A Daunting Task (Step 2)"`
  - Click **Test Abandoned** and **Test Failed** — same pattern with `(Step 2)`.
  - Click **Test Finished** — banner should show NO `(Step N)` annotation.

- [ ] **Step 26: Verify accepted event on a chain quest**

  Accept a quest that is part of a known chain (Questie/QuestWeaver must know it).
  - Outbound chat: `"Quest accepted: <title> (Step N)"`
  - With `displayOwn` on: own banner shows `"You accepted: <title> (Step N)"`

- [ ] **Step 27: Verify completed event on a chain quest**

  Turn in the chain quest.
  - Outbound chat: `"Quest turned in: <title> (Step N)"`
  - With `displayOwn` on: own banner shows `"You completed: <title> (Step N)"`

- [ ] **Step 28: Verify step increments on follow-up**

  Accept the follow-up quest in the chain.
  - `(Step N)` should be one higher than the previous step.

- [ ] **Step 29: Verify no annotation on standalone quest**

  Accept a quest that is NOT part of a chain.
  - No `(Step N)` in chat or banner.

- [ ] **Step 30: Verify remote banners show step (requires group)**

  In a group with another SQ user, have them accept/complete a chain quest.
  - Their banner on your screen should show `(Step N)`.
