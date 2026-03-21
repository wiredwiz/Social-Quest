# Flight Paths, Needs-Shared Eligibility, Quest Log Toggle — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three independent SocialQuest improvements: flight path discovery notifications, "Needs it Shared" eligibility filtering, and quest log toggle on repeat click.

**Architecture:** All three features are additive changes to existing files — no new files are created. Feature 1 (flight paths) touches the most files (SocialQuest.lua, Communications.lua, Announcements.lua, Options.lua, enUS.lua). Features 2 and 3 each touch a single file (PartyTab.lua and RowFactory.lua respectively). A version bump closes out the work.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary Interface 20505, Ace3 (AceAddon, AceEvent, AceComm, AceDB, AceSerializer, AceLocale, AceConfig), AbsoluteQuestLog-1.0 (AQL)

**Testing note:** This is a WoW addon — there is no automated test runner. All verification steps below are manual: load the addon in-game (or reload the UI) and confirm the described behavior. Lua syntax errors will surface as WoW error dialogs on login/reload.

**Spec:** `docs/superpowers/specs/2026-03-20-flight-paths-eligibility-toggle-design.md`

---

## Chunk 1: Feature 1 — Flight Path Discovery

### Task 1: Add AceDB defaults for flight path settings

**Files:**
- Modify: `SocialQuest.lua` — `GetDefaults()` function (~lines 152–267)

Add `flightPath` settings inside `profile` and add `char` namespace as a sibling of `profile`.

- [ ] **Step 1: Add `flightPath` to the `profile` block in `GetDefaults()`**

Locate `GetDefaults()` (~line 152). Inside the `profile = { ... }` block, add the `flightPath` entry just before `minimap`:

```lua
            flightPath = {
                enabled         = true,   -- broadcast my discoveries to party
                announceBanners = true,   -- display banners when party members discover paths
            },
            minimap = { hide = false },
```

- [ ] **Step 2: Add `char` namespace as a sibling of `profile` in `GetDefaults()`**

The closing of the `GetDefaults` return table currently looks like this (after `frameState`):

```lua
        },    -- closes profile
    }
end
```

Change it to:

```lua
        },    -- closes profile
        char = {
            knownFlightNodes = {},  -- [nodeName] = true; persists across sessions
        },
    }
end
```

**Important:** `char` is at the same indentation level as `profile`, not nested inside it. AceDB activates per-character storage automatically when it sees `char` at the root of the defaults table.

- [ ] **Step 3: Manual verification**

`/reload` in-game. No Lua errors. Type `/sq config` — no errors. The addon still initializes normally.

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: add flightPath AceDB defaults (profile.flightPath + char.knownFlightNodes)"
```

---

### Task 2: Add RACE_STARTING_NODES table and getStartingNode helper

**Files:**
- Modify: `SocialQuest.lua` — add file-scope locals before `SocialQuest:OnInitialize`

- [ ] **Step 1: Insert the table and helper**

Place these as file-scope locals immediately before the `------------------------------------------------------------------------` comment that precedes `SocialQuest:OnInitialize` (around line 21, after the `local L = ...` line):

```lua
------------------------------------------------------------------------
-- Flight path starting node lookup
------------------------------------------------------------------------

-- Keys are the second return value of UnitRace("player") (English internal name).
-- All node name strings require in-game verification against GetTaxiNodeInfo() output
-- at Interface 20505 — values below are best-effort.
-- Pandaren, Dracthyr, and Earthen are faction-dependent; handled in getStartingNode().
local RACE_STARTING_NODES = {
    -- TBC (currently supported)
    ["Human"]              = "Stormwind",
    ["Dwarf"]              = "Ironforge",
    ["Gnome"]              = "Ironforge",
    ["NightElf"]           = "Rut'theran Village",
    ["Scourge"]            = "Undercity",           -- Undead
    ["Tauren"]             = "Thunder Bluff",
    ["Orc"]                = "Orgrimmar",
    ["Troll"]              = "Orgrimmar",
    ["Draenei"]            = "The Exodar",
    ["BloodElf"]           = "Silvermoon City",
    -- Cataclysm
    ["Worgen"]             = "Stormwind",
    ["Goblin"]             = "Orgrimmar",
    -- BfA allied races
    ["VoidElf"]            = "Stormwind",
    ["LightforgedDraenei"] = "Stormwind",
    ["DarkIronDwarf"]      = "Ironforge",
    ["KulTiran"]           = "Boralus",
    ["Mechagnome"]         = "Mechagon",
    ["Nightborne"]         = "Orgrimmar",
    ["HighmountainTauren"] = "Thunder Bluff",
    ["MagharOrc"]          = "Orgrimmar",
    ["ZandalarTroll"]      = "Dazar'alor",
    ["Vulpera"]            = "Orgrimmar",
    -- Dragonflight / The War Within
    -- (Dracthyr and Earthen handled in getStartingNode — faction-dependent)
}

-- Returns the starting flight node name for the local player.
-- Handles faction-dependent races (Pandaren, Dracthyr, Earthen) inline.
-- Returns nil for unknown races; callers treat nil as "no seed available."
local function getStartingNode()
    local _, race = UnitRace("player")
    local node = RACE_STARTING_NODES[race]
    if node then return node end
    local faction = UnitFactionGroup("player")
    if race == "Pandaren" or race == "Dracthyr" or race == "Earthen" then
        return faction == "Alliance" and "Stormwind" or "Orgrimmar"
    end
    return nil
end
```

- [ ] **Step 2: Manual verification**

`/reload`. No Lua errors. The addon initializes normally.

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: add RACE_STARTING_NODES table and getStartingNode helper"
```

---

### Task 3: Register TAXIMAP_OPENED event and implement OnTaxiMapOpened

**Files:**
- Modify: `SocialQuest.lua` — `OnEnable` event registration block + new handler method

- [ ] **Step 1: Register TAXIMAP_OPENED in OnEnable**

In `SocialQuest:OnEnable`, add after the `AUTOFOLLOW_END` registration line:

```lua
    self:RegisterEvent("TAXIMAP_OPENED",    "OnTaxiMapOpened")
```

The block should now read:

```lua
    self:RegisterEvent("GROUP_ROSTER_UPDATE",   "OnGroupRosterUpdate")
    self:RegisterEvent("PLAYER_LOGIN",          "OnPlayerLogin")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("AUTOFOLLOW_BEGIN",       "OnAutoFollowBegin")
    self:RegisterEvent("AUTOFOLLOW_END",         "OnAutoFollowEnd")
    self:RegisterEvent("TAXIMAP_OPENED",         "OnTaxiMapOpened")
```

- [ ] **Step 2: Add OnTaxiMapOpened handler**

Add the handler method after `SocialQuest:OnAutoFollowEnd` (near the bottom of the WoW event handlers section, before the Debug helper section):

```lua
function SocialQuest:OnTaxiMapOpened()
    if not self.db.profile.flightPath.enabled then return end

    -- Collect all node names currently visible on the taxi map.
    -- GetTaxiNodeInfo(i) returns name, texture, x, y at Interface 20505.
    -- Iterate until nil is returned. Only named nodes are collected.
    -- NOTE: exact API behavior (active vs inactive nodes, max index) requires
    -- in-game verification during implementation.
    local currentNodes = {}
    local i = 1
    while true do
        local name = GetTaxiNodeInfo(i)
        if not name then break end
        currentNodes[name] = true
        i = i + 1
    end

    local saved = self.db.char.knownFlightNodes
    local diff  = {}
    for name in pairs(currentNodes) do
        if not saved[name] then
            table.insert(diff, name)
        end
    end

    local diffCount    = #diff
    local currentCount = 0
    for _ in pairs(currentNodes) do currentCount = currentCount + 1 end

    if diffCount == 0 then
        return  -- nothing new
    end

    local startNode = getStartingNode()

    if diffCount == 1 then
        -- Normal case: one new node. Announce unless it is the starting city.
        if diff[1] ~= startNode then
            SocialQuestComm:SendFlightDiscovery(diff[1])
        end
        -- else: first-ever open at starting city — silently absorb.

    elseif diffCount > 1 and currentCount == 2 then
        -- Special case: savedNodes was empty and player has exactly starting city
        -- + one new discovery. Announce the non-starting-city node only.
        -- If startNode is nil (unknown race), skip — cannot identify which is new.
        if startNode then
            for _, name in ipairs(diff) do
                if name ~= startNode then
                    SocialQuestComm:SendFlightDiscovery(name)
                    break
                end
            end
        end

    else
        -- diffCount > 1 and currentCount > 2: mid-game install or ambiguous.
        -- Silently absorb — cannot determine which node is genuinely new.
    end

    -- Always update saved state regardless of whether anything was announced.
    for name in pairs(currentNodes) do
        saved[name] = true
    end
end
```

- [ ] **Step 3: Manual verification**

`/reload`. Open a flight master — no Lua errors. Check `/sq config` still works.

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: register TAXIMAP_OPENED and implement OnTaxiMapOpened handler"
```

---

### Task 4: Add SQ_FLIGHT communication support

**Files:**
- Modify: `Core/Communications.lua` — PREFIXES table, SendFlightDiscovery function, OnCommReceived branch

- [ ] **Step 1: Add `"SQ_FLIGHT"` to PREFIXES**

The `PREFIXES` table is at the top of the file (line ~15):

```lua
local PREFIXES = {
    "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
    "SQ_REQUEST",
    "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
    "SQ_REQ_COMPLETED", "SQ_RESP_COMPLETE",
}
```

Change to:

```lua
local PREFIXES = {
    "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
    "SQ_REQUEST",
    "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
    "SQ_REQ_COMPLETED", "SQ_RESP_COMPLETE",
    "SQ_FLIGHT",
}
```

- [ ] **Step 2: Add SendFlightDiscovery function**

Add after the `SocialQuestComm:BroadcastObjectiveUpdate` function (before the "Request Completed" section or wherever party-specific helpers are grouped). Use `LibStub("AceComm-3.0"):SendCommMessage` and the file-local `serialize()` wrapper — `SocialQuestComm` is a plain table, not an Ace3 mixin; this is the pattern every other send helper in this file uses:

```lua
-- Sends the local player's newly discovered flight path name to the party.
-- Only sent when in a party (not raid, not battleground).
function SocialQuestComm:SendFlightDiscovery(nodeName)
    if not IsInGroup() or IsInRaid() then return end
    -- Use LibStub("AceComm-3.0"):SendCommMessage — all other send helpers in this
    -- file use the same pattern (SocialQuestComm is a plain table, not an Ace3 mixin).
    LibStub("AceComm-3.0"):SendCommMessage("SQ_FLIGHT", serialize({ node = nodeName }), "PARTY")
    SocialQuest:Debug("Comm", "Sent SQ_FLIGHT: " .. nodeName)
end
```

- [ ] **Step 3: Add SQ_FLIGHT branch in OnCommReceived**

In `SocialQuestComm:OnCommReceived`, `payload` is already deserialized at the top of the function (before the prefix dispatch). Add after the `SQ_RESP_COMPLETE` branch, before the final `end`:

```lua
    elseif prefix == "SQ_FLIGHT" then
        if payload and payload.node then
            SocialQuest:Debug("Comm", "Received SQ_FLIGHT from " .. sender .. ": " .. payload.node)
            SocialQuestAnnounce:OnFlightDiscovery(sender, payload.node)
        end
```

- [ ] **Step 4: Manual verification**

`/reload`. No Lua errors. `/sq config` still works.

- [ ] **Step 5: Commit**

```bash
git add Core/Communications.lua
git commit -m "feat: add SQ_FLIGHT comm prefix, SendFlightDiscovery, OnCommReceived branch"
```

---

### Task 5: Add OnFlightDiscovery announcement handler

**Files:**
- Modify: `Core/Announcements.lua` — new handler after the follow notification section

- [ ] **Step 1: Add OnFlightDiscovery handler**

Add after the `SocialQuestAnnounce:OnFollowStop` function (around line 652), before the "Whisper friends helper" section:

```lua
------------------------------------------------------------------------
-- Flight path discovery notifications
------------------------------------------------------------------------

function SocialQuestAnnounce:OnFlightDiscovery(sender, nodeName)
    local db = SocialQuest.db.profile
    if not db.flightPath.announceBanners then return end
    local msg = string.format(L["%s unlocked flight path: %s"], sender, nodeName)
    displayBanner(msg, "accepted")  -- reuses the quest-accepted green color
end
```

Note: `displayBanner` is a file-scope local in `Announcements.lua` — this method can call it directly because it is in the same file. Do not use `self:displayBanner(...)` — that would fail.

- [ ] **Step 2: Manual verification**

`/reload`. No Lua errors.

- [ ] **Step 3: Commit**

```bash
git add Core/Announcements.lua
git commit -m "feat: add OnFlightDiscovery banner handler in Announcements.lua"
```

---

### Task 6: Add locale strings for flight path feature

**Files:**
- Modify: `Locales/enUS.lua` — new strings for banner message and options panel

Non-enUS locales do not need immediate updates. AceLocale-3.0 falls back to the default locale (enUS) for any key not present in the current locale file. Translators can add translations later.

- [ ] **Step 1: Add strings to enUS.lua**

Add a new section at the end of `Locales/enUS.lua`:

```lua
-- Core/Announcements.lua — flight path discovery banner
-- %s args: (1) sender character name, (2) flight node name. Raw AceComm sender (Name-Realm format).
L["%s unlocked flight path: %s"]                = true

-- UI/Options.lua — Flight Path Discovery group
L["Flight Path Discovery"]                      = true
L["Announce flight path discoveries"]           = true
L["Broadcast to your party when you discover a new flight path."] = true
L["Show banner for party discoveries"]          = true
L["Display a banner notification when a party member discovers a new flight path."] = true
```

- [ ] **Step 2: Manual verification**

`/reload`. No Lua errors.

- [ ] **Step 3: Commit**

```bash
git add Locales/enUS.lua
git commit -m "feat: add flight path discovery locale strings to enUS.lua"
```

---

### Task 7: Add Flight Path Discovery options group

**Files:**
- Modify: `UI/Options.lua` — add `flightPath` group, bump `debug` order from 8 to 9

- [ ] **Step 1: Change debug group order from 8 to 9**

Find the `debug` group definition (~line 278):

```lua
            debug = {
                type  = "group",
                name  = L["Debug"],
                order = 8,
```

Change `order = 8` to `order = 9`.

- [ ] **Step 2: Add the flightPath options group after the follow group**

Find the end of the `follow` group (around line 276, which ends `},`). Insert the new group immediately after it, before the `debug` group:

```lua
            flightPath = {
                type  = "group",
                name  = L["Flight Path Discovery"],
                order = 8,
                args  = {
                    enabled = toggle(L["Announce flight path discoveries"],
                        L["Broadcast to your party when you discover a new flight path."],
                        { "flightPath", "enabled" }, 1),
                    announceBanners = toggle(L["Show banner for party discoveries"],
                        L["Display a banner notification when a party member discovers a new flight path."],
                        { "flightPath", "announceBanners" }, 2),
                },
            },
```

- [ ] **Step 3: Manual verification**

`/reload`. Open `/sq config`. Confirm "Flight Path Discovery" group appears between "Follow Notifications" and "Debug". Confirm both toggles are visible and functional (they check/uncheck and persist through `/reload`).

- [ ] **Step 4: Commit**

```bash
git add UI/Options.lua
git commit -m "feat: add Flight Path Discovery options group (order 8); bump debug to order 9"
```

---

## Chunk 2: Features 2 & 3 + Version Bump

### Task 8: Add Needs-Shared eligibility check

**Files:**
- Modify: `UI/Tabs/PartyTab.lua` — add `isEligibleForShare` local helper, replace `needsShare = true`

- [ ] **Step 1: Add isEligibleForShare helper before buildPlayerRowsForQuest**

Insert the following local function immediately before the `-- Builds the ordered list...` comment that precedes `buildPlayerRowsForQuest` (currently line 13):

```lua
-- Returns true only when the quest can actually be shared with this player:
--   1. The quest is marked shareable by the WoW API.
--   2. The player has not already completed the quest.
--   3. If the quest is a known chain step with a previous step, that step
--      has been completed by the player.
-- Falls back gracefully when chain info is unavailable (no Questie).
-- NOTE: AQL is a hard dependency — the addon disables itself if AQL is missing,
-- so the `if not AQL then return false end` guard is a safety net only.
-- NOTE: GetQuestLogSelection() requires in-game verification at Interface 20505.
-- If absent or returning nil, prevSel is nil; the restoration guard silently
-- skips it, leaving the log on the last-selected entry — acceptable trade-off.
local function isEligibleForShare(questID, playerData)
    local AQL = SocialQuest.AQL
    if not AQL then return false end

    -- Check 1: quest is shareable via WoW API.
    -- Guard against stale logIndex: confirm the entry actually maps to questID
    -- before calling GetQuestLogPushable (the log may have shifted since last AQL update).
    local qi = AQL:GetQuest(questID)
    if not qi or not qi.logIndex then return false end
    local prevSel = GetQuestLogSelection()
    SelectQuestLogEntry(qi.logIndex)
    local _, _, _, _, _, _, _, confirmID = GetQuestLogTitle(qi.logIndex)
    if confirmID ~= questID then
        if prevSel and prevSel > 0 then SelectQuestLogEntry(prevSel) end
        return false
    end
    local shareable = GetQuestLogPushable() and true or false
    if prevSel and prevSel > 0 then
        SelectQuestLogEntry(prevSel)
    end
    if not shareable then return false end

    -- Check 2: player has not already completed this quest.
    if playerData.completedQuests and playerData.completedQuests[questID] then
        return false
    end

    -- Check 3: chain prerequisite met (requires Questie/chain info).
    local ci = AQL:GetChainInfo(questID)
    if ci and ci.knownStatus == AQL.ChainStatus.Known and ci.step and ci.step > 1 then
        local prevStep = ci.steps and ci.steps[ci.step - 1]
        if prevStep and prevStep.questID then
            if not (playerData.completedQuests and
                    playerData.completedQuests[prevStep.questID]) then
                return false
            end
        end
    end

    return true
end
```

- [ ] **Step 2: Replace `needsShare = true` with the helper call**

In `buildPlayerRowsForQuest`, find the `elseif localHasIt then` branch (~line 77). The current code is:

```lua
        elseif localHasIt then
            -- Party member lacks the quest; local player has it → "Needs it Shared".
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                isComplete     = false,
                needsShare     = true,
                objectives     = {},
            })
```

Change `needsShare = true` to:

```lua
                needsShare     = isEligibleForShare(questID, playerData),
```

- [ ] **Step 3: Manual verification**

`/reload`. Open the Party tab in the SQ window with a party member who lacks a quest you have. Verify:
- "Needs it Shared" row appears when the quest is shareable and they haven't completed it.
- "Needs it Shared" row is suppressed for quests that are non-shareable (e.g., daily quests or quests with `GetQuestLogPushable()` returning false).

- [ ] **Step 4: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: replace needsShare=true with isEligibleForShare() eligibility check"
```

---

### Task 9: Add quest log toggle behavior

**Files:**
- Modify: `UI/RowFactory.lua` — add toggle guard at top of `openQuestLogToQuest`

- [ ] **Step 1: Add toggle guard at the top of openQuestLogToQuest**

Find `local function openQuestLogToQuest(questID)` (~line 53). The current function body starts with `ShowUIPanel(QuestLogFrame)`. Add the guard block before that line:

```lua
local function openQuestLogToQuest(questID)
    -- Toggle: if the quest log is already open and this quest is currently
    -- selected, close the log instead of re-opening it.
    -- NOTE: GetQuestLogSelection() requires in-game verification at Interface 20505.
    -- If absent or returning nil, sel is nil, the guard skips, and the function
    -- falls through to the existing open-and-select logic — safe degradation.
    if QuestLogFrame:IsShown() then
        local sel = GetQuestLogSelection()
        if sel and sel > 0 then
            local _, _, _, _, _, _, _, selID = GetQuestLogTitle(sel)
            if selID == questID then
                HideUIPanel(QuestLogFrame)
                return
            end
        end
    end

    ShowUIPanel(QuestLogFrame)
    -- ... rest of existing function unchanged ...
```

The rest of the existing function body (the while loop that expands zone headers and calls `QuestLog_SetSelection`) is **completely unchanged** — do not touch it.

- [ ] **Step 2: Manual verification**

`/reload`. In the SQ window, click a quest title — the quest log opens and selects that quest (existing behavior). Click the same quest title again — the quest log closes. Click a different quest title while the log is open — it switches to that quest (no toggle, since a different quest is selected).

- [ ] **Step 3: Commit**

```bash
git add UI/RowFactory.lua
git commit -m "feat: add quest log toggle to openQuestLogToQuest (close if already showing that quest)"
```

---

### Task 10: Version bump and CLAUDE.md update

**Files:**
- Modify: `SocialQuest.toc` — version number
- Modify: `CLAUDE.md` — version history entry

Per CLAUDE.md versioning rule: this is the first functionality change on this day → increment minor version, reset revision to 0. Current version is `2.1.2` → new version is `2.2.0`.

- [ ] **Step 1: Update SocialQuest.toc**

Change:

```
## Version: 2.1.2
```

To:

```
## Version: 2.2.0
```

- [ ] **Step 2: Add version history entry to CLAUDE.md**

Add a new section at the top of the Version History, before the `### Version 2.1.2` entry:

```markdown
### Version 2.2.0 (March 2026 — Improvements branch)
- Flight Path Discovery: detects new flight path unlocks via `TAXIMAP_OPENED`; broadcasts to party via `SQ_FLIGHT` prefix; displays banner using quest-accepted green color. Per-character `knownFlightNodes` persists across sessions. Handles first-run, mid-game install, and unknown-race edge cases.
- Needs-Shared Eligibility: "Needs it Shared" rows now suppressed unless the quest is shareable (`GetQuestLogPushable`), the player has not completed it, and any chain prerequisite has been completed.
- Quest Log Toggle: left-clicking a quest title in the SQ window now closes the quest log if it is already open and showing that quest.
```

- [ ] **Step 3: Manual verification**

`/reload`. Hover over the minimap button or check the addon list — version shows `2.2.0`.

- [ ] **Step 4: Commit**

```bash
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump version to 2.2.0; update CLAUDE.md version history"
```

---

## End-to-End Verification Checklist

After all tasks are complete, perform a full smoke test in-game:

**Flight Path Discovery:**
- [ ] Open a flight master. No Lua errors. `char.knownFlightNodes` populates (verify via `/print #SocialQuestDB` or debug logging).
- [ ] In a party: open a flight master at a node you don't have yet. Confirm the other party member receives a "Name unlocked flight path: NodeName" banner (green, quest-accepted style).
- [ ] Toggle `Announce flight path discoveries` off in `/sq config`. Open flight master at new node — no broadcast to party.
- [ ] Toggle `Show banner for party discoveries` off. Have a party member open a flight master — no banner appears locally.

**Needs-Shared Eligibility:**
- [ ] Join a party. Have a party member not have a quest you have. Confirm "Needs it Shared" appears for shareable quests, is absent for non-shareable ones.

**Quest Log Toggle:**
- [ ] Click a quest title in the SQ window — quest log opens, quest is selected.
- [ ] Click the same title again — quest log closes.
- [ ] Click a different title while the log is open — log switches quest (no close).
