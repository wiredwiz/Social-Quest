# Outbound Chat Format — Test Demo Polish Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update hardcoded test demo strings so the chat preview correctly shows the quest name in gold (matching what a real WoW hyperlink looks like in chat), and guard against a nil-concat error when the `all_complete` demo has no outbound string.

**Architecture:** Two edits to `Core/Announcements.lua` only. No new files. No locale changes needed — the locale template keys are already correct. The `banner` strings in `TEST_DEMOS` are intentionally plain text (RaidNotice cannot render color codes) and are not touched.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505). No automated test framework — verification is done in-game via the Options UI test buttons or the `/sq test <eventType>` path.

**Spec:** `docs/superpowers/specs/2026-03-18-outbound-chat-format-design.md`

---

## Chunk 1: Test demo string polish + nil guard

### Task 1: Update TEST_DEMOS outbound strings and fix nil guard

**Files:**
- Modify: `Core/Announcements.lua:508-561`

This task has two sub-goals that are edited together since they touch the same block:

**Sub-goal A — Gold quest name in outbound strings.**
A real `formatOutboundQuestMsg` call produces a WoW hyperlink that renders in chat as gold `[Quest Name]`. The demo strings bypass that path and hardcode the quest name as plain text. Update them to use `|cFFFFD200[A Daunting Task]|r` so the preview visually matches what party members would see.

Quest-event demos currently show `A Daunting Task` (no brackets, no color). Objective demos already have brackets (`[A Daunting Task]`) but no color code.

**Sub-goal B — Nil guard in TestEvent.**
`displayChatPreview` concatenates its argument onto a string. When `eventType` is `all_complete`, `demo.outbound` is nil, which causes a Lua 5.1 concat error. Guard the call.

- [ ] **Step 1: Open the file and locate the TEST_DEMOS table**

  File: `Core/Announcements.lua`, lines 508–561. Confirm the `TEST_DEMOS` table and `TestEvent` function look like this before editing:

  ```lua
  local TEST_DEMOS = {
      accepted = {
          outbound = "{rt1} SocialQuest: Quest Accepted: A Daunting Task (Step 2)",
          ...
      },
      -- ... (abandoned, finished, completed, failed follow same pattern)
      objective_progress = {
          outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for [A Daunting Task]!",
          ...
      },
      -- ... (objective_complete, objective_regression follow same pattern)
      all_complete = {
          outbound = nil,
          ...
      },
  }

  function SocialQuestAnnounce:TestEvent(eventType)
      local demo = TEST_DEMOS[eventType]
      if not demo then return end
      displayBanner(demo.banner, demo.colorKey)
      displayChatPreview(demo.outbound)   -- BUG: errors when outbound is nil
  end
  ```

- [ ] **Step 2: Replace the TEST_DEMOS table and TestEvent function**

  Replace lines 508–561 with the following. Changes from current:
  - Quest event `outbound` strings: plain name → `|cFFFFD200[A Daunting Task]|r` (adds gold color + brackets)
  - Objective `outbound` strings: `[A Daunting Task]` → `|cFFFFD200[A Daunting Task]|r` (adds gold color)
  - `TestEvent`: guards `displayChatPreview` behind `if demo.outbound then`

  ```lua
  local TEST_DEMOS = {
      accepted = {
          outbound = "{rt1} SocialQuest: Quest Accepted: |cFFFFD200[A Daunting Task]|r (Step 2)",
          banner   = "TestPlayer accepted: [A Daunting Task] (Step 2)",
          colorKey = "accepted",
      },
      abandoned = {
          outbound = "{rt1} SocialQuest: Quest Abandoned: |cFFFFD200[A Daunting Task]|r (Step 2)",
          banner   = "TestPlayer abandoned: [A Daunting Task] (Step 2)",
          colorKey = "abandoned",
      },
      finished = {
          outbound = "{rt1} SocialQuest: Quest Complete: |cFFFFD200[A Daunting Task]|r",
          banner   = "TestPlayer finished objectives: [A Daunting Task]",
          colorKey = "finished",
      },
      completed = {
          outbound = "{rt1} SocialQuest: Quest Completed: |cFFFFD200[A Daunting Task]|r (Step 2)",
          banner   = "TestPlayer completed: [A Daunting Task] (Step 2)",
          colorKey = "completed",
      },
      failed = {
          outbound = "{rt1} SocialQuest: Quest Failed: |cFFFFD200[A Daunting Task]|r (Step 2)",
          banner   = "TestPlayer failed: [A Daunting Task] (Step 2)",
          colorKey = "failed",
      },
      objective_progress = {
          outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for |cFFFFD200[A Daunting Task]|r!",
          banner   = "TestPlayer progressed: [A Daunting Task] — Kobolds Slain (3/8)",
          colorKey = "objective_progress",
      },
      objective_complete = {
          outbound = "{rt1} SocialQuest: 8/8 Kobolds Slain for |cFFFFD200[A Daunting Task]|r!",
          banner   = "TestPlayer completed objective: [A Daunting Task] — Kobolds Slain (8/8)",
          colorKey = "objective_complete",
      },
      objective_regression = {
          outbound = "{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for |cFFFFD200[A Daunting Task]|r!",
          banner   = "TestPlayer regressed: [A Daunting Task] — Kobolds Slain (2/8)",
          colorKey = "objective_progress",   -- same color as progress
      },
      all_complete = {
          outbound = nil,   -- no outbound chat for this synthesized event
          banner   = "Everyone has completed: A Daunting Task",
          colorKey = "all_complete",
      },
  }

  function SocialQuestAnnounce:TestEvent(eventType)
      local demo = TEST_DEMOS[eventType]
      if not demo then return end
      displayBanner(demo.banner, demo.colorKey)
      if demo.outbound then
          displayChatPreview(demo.outbound)
      end
  end
  ```

- [ ] **Step 3: Verify the changes look correct**

  After editing, confirm:
  - All five quest-event `outbound` strings contain `|cFFFFD200[A Daunting Task]|r`
  - All three objective `outbound` strings contain `|cFFFFD200[A Daunting Task]|r`
  - `all_complete.outbound` is still `nil`
  - `TestEvent` has `if demo.outbound then` guard
  - No `banner` strings were changed

- [ ] **Step 4: In-game verification (manual)**

  Load the addon and open the SocialQuest options panel. Under "Test Banners and Chat", click each test button. Verify:

  | Button | Chat preview shows |
  |---|---|
  | Test Accepted | `SocialQuest (preview): {rt1} SocialQuest: Quest Accepted: [A Daunting Task] (Step 2)` with `[A Daunting Task]` in **gold** |
  | Test Abandoned | Same pattern, "Quest Abandoned" |
  | Test Finished | Same pattern, "Quest Complete", no Step suffix |
  | Test Completed | Same pattern, "Quest Completed" |
  | Test Failed | Same pattern, "Quest Failed" |
  | Test Obj. Progress | `... 3/8 Kobolds Slain for [A Daunting Task]!` with gold link |
  | Test Obj. Complete | `... 8/8 Kobolds Slain for [A Daunting Task]!` with gold link |
  | Test Obj. Regression | `... 2/8 Kobolds Slain (regression) for [A Daunting Task]!` with gold link |
  | Test All Completed | On-screen banner only — **no chat preview line at all** (nil guard working) |
  | Test Chat Link | Shows quest 337 as a real clickable hyperlink (unchanged, still works) |

- [ ] **Step 5: Commit**

  ```bash
  git add Core/Announcements.lua
  git commit -m "fix: gold-color quest name in test demo outbound strings

  Test demo chat previews now show the quest name in gold
  (|cFFFFD200...|r) matching how a real WoW hyperlink renders in chat.
  Also adds nil guard in TestEvent so all_complete (which has no
  outbound string) no longer errors on concat."
  ```
