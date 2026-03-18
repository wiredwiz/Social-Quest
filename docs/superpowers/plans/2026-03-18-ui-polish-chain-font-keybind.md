# Social Quest UI Polish: Chain Header Font + Keybind — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote chain group header rows to `GameFontNormal` and add a named WoW keybinding entry so players can assign a key to toggle the Social Quest window.

**Architecture:** Two independent changes. The font fix is a single-line edit in `RowFactory.lua`. The keybind adds a new `Bindings.xml` file, updates the TOC, and adds two global string variables to `SocialQuest.lua`. No runtime logic changes in either task.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AceAddon-3.0. No automated test framework — verification is manual, in-game.

---

## Chunk 1: Both changes

### Task 1: Promote chain header font to GameFontNormal

**Files:**
- Modify: `Social-Quest/UI/RowFactory.lua:113`

**Background:** `AddChainHeader` creates a FontString for the chain group label (the cyan indented label shown under a zone header when quests belong to a chain). It currently uses `GameFontNormalSmall`, making it visually smaller than zone headers (`AddZoneHeader`, line 98) and quest title rows (`AddQuestRow`, line 187), which both use `GameFontNormal`. The fix is a one-line change.

- [ ] **Step 1: Make the font change**

  Open `Social-Quest/UI/RowFactory.lua`. Find line 113 inside `AddChainHeader`:

  **Find:**
  ```lua
      local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ```

  **Replace with:**
  ```lua
      local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ```

- [ ] **Step 2: Verify the edit**

  Read back `RowFactory.lua` lines 45–130 and confirm:
  - `AddChainHeader` (line 113) now creates its FontString with `"GameFontNormal"`
  - `AddZoneHeader` (line 98) still uses `"GameFontNormal"` — unchanged
  - `AddExpandCollapseHeader` toggle buttons (lines 54, 58, 69, 73) still use `"GameFontNormalSmall"` — unchanged

  Then read lines 183–195 and confirm:
  - `AddQuestRow` title FontString (line 187) still uses `"GameFontNormal"` — unchanged

- [ ] **Step 3: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add UI/RowFactory.lua
  git commit -m "fix: promote chain header font from GameFontNormalSmall to GameFontNormal

  Chain group label rows now match the visual weight of zone headers
  and quest title rows.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

### Task 2: Add WoW keybinding for frame toggle

**Files:**
- Create: `Social-Quest/Bindings.xml`
- Modify: `Social-Quest/SocialQuest.toc` (add `Bindings.xml` entry)
- Modify: `Social-Quest/SocialQuest.lua` (add `BINDING_HEADER_*` and `BINDING_NAME_*` globals)

**Background:** WoW reads `Bindings.xml` to register named key binding slots. The `<Binding header="..."/>` self-closing element creates a category in the Key Bindings UI. The `<Binding name="...">` element registers the binding slot; its body is Lua executed at keypress. WoW resolves display names from `BINDING_HEADER_*` and `BINDING_NAME_*` global strings — these must be plain globals set during addon load. The binding body calls `SocialQuestGroupFrame:Toggle()`, the same function already wired to `/sq`.

- [ ] **Step 1: Create Bindings.xml**

  Create `Social-Quest/Bindings.xml` with the following content (exact):

  ```xml
  <Bindings>
      <Binding header="SOCIALQUEST_HEADER"/>
      <Binding name="SOCIALQUEST_TOGGLE" description="Toggle Social Quest Window">
          SocialQuestGroupFrame:Toggle()
      </Binding>
  </Bindings>
  ```

- [ ] **Step 2: Add Bindings.xml to the TOC**

  Open `Social-Quest/SocialQuest.toc`. The current file list starts at line 9. Add `Bindings.xml` as the first entry in the file list, before the library files:

  **Find (the start of the file list):**
  ```
  Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
  ```

  **Replace with:**
  ```
  Bindings.xml
  Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
  ```

- [ ] **Step 3: Add binding display string globals to SocialQuest.lua**

  Open `Social-Quest/SocialQuest.lua`. The file begins with a comment block then `SocialQuest = LibStub(...)` at line 5. Add the two globals immediately before that line:

  **Find:**
  ```lua
  SocialQuest = LibStub("AceAddon-3.0"):NewAddon(
  ```

  **Replace with:**
  ```lua
  -- Key binding display strings. WoW reads these globals to populate the
  -- Key Bindings UI (Options → Key Bindings → AddOns → Social Quest).
  BINDING_HEADER_SOCIALQUEST_HEADER = "Social Quest"
  BINDING_NAME_SOCIALQUEST_TOGGLE   = "Toggle Social Quest Window"

  SocialQuest = LibStub("AceAddon-3.0"):NewAddon(
  ```

- [ ] **Step 4: Verify all three files**

  Read back each file and confirm:

  **Bindings.xml** — contains exactly two `<Binding>` elements: one self-closing with `header="SOCIALQUEST_HEADER"`, one with `name="SOCIALQUEST_TOGGLE"` whose body is `SocialQuestGroupFrame:Toggle()`.

  **SocialQuest.toc** — `Bindings.xml` appears as the first file entry (before `Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua`).

  **SocialQuest.lua** — both globals appear before `SocialQuest = LibStub(...)`, with no other changes to the file.

- [ ] **Step 5: Commit**

  ```bash
  cd "D:/Projects/Wow Addons/Social-Quest"
  git add Bindings.xml SocialQuest.toc SocialQuest.lua
  git commit -m "feat: add WoW keybinding for Social Quest window toggle

  Registers SOCIALQUEST_TOGGLE in the WoW Key Bindings UI under a
  'Social Quest' category. Players can assign any key; the binding
  calls SocialQuestGroupFrame:Toggle(), same as /sq.

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
  ```

---

## In-Game Verification

Reload the WoW client with the updated addon after both tasks are committed.

**Test 1 — Chain header font:** Open the Social Quest window with a chain quest active (requires Questie or QuestWeaver). Confirm chain group label text is the same visual size as zone header text and quest title text.

**Test 2 — Keybind strings in UI:** Open Options → Key Bindings → AddOns. Confirm a "Social Quest" category appears with a "Toggle Social Quest Window" entry — not raw strings like `BINDING_NAME_SOCIALQUEST_TOGGLE`. Assign a key. Press it. Confirm the Social Quest window opens and closes.

**Test 3 — Escape still works:** With the window open, press Escape. Confirm it closes.

**Test 4 — `/sq` still works:** Type `/sq`. Confirm it still toggles the window.

---

*Spec: `Social-Quest/docs/superpowers/specs/2026-03-18-ui-polish-chain-font-keybind.md`*
