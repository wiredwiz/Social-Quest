# WoW API Abstraction Layer Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize all direct WoW API calls in SocialQuest behind two thin abstraction modules (`Core/WowAPI.lua` and `Core/WowUI.lua`) so the addon can target multiple WoW interface versions without scattered direct calls.

**Architecture:** Two new global table modules loaded before all game-logic modules. Each consumer file declares a local alias (`local SQWowAPI = SocialQuestWowAPI` / `local SQWowUI = SocialQuestWowUI`). Quest and quest-log WoW API calls are replaced with AQL public API calls rather than wrapped. All other WoW API calls route through the new modules.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary Interface 20505, AbsoluteQuestLog-1.0 (AQL)

**Testing note:** This is a WoW addon — there is no automated test runner. Verification for each task is: (1) grep to confirm no bare WoW globals remain in modified files, and (2) load in WoW without Lua errors (check with `/sq debug on` and exercise the feature). Every task ends with a commit.

**Spec:** `docs/superpowers/specs/2026-03-24-wow-api-abstraction-design.md`

---

## Chunk 1: New abstraction modules and TOC wiring

### Task 1: Create Core/WowAPI.lua

**Files:**
- Create: `Core/WowAPI.lua`

- [ ] **Step 1: Create the file with all stubs**

Create `Core/WowAPI.lua` with this exact content:

```lua
-- Core/WowAPI.lua
-- Thin pass-through wrappers around WoW game-state and data globals.
-- All version-specific branching for non-quest WoW APIs lives here.
-- No other SocialQuest file should reference these WoW globals directly.

SocialQuestWowAPI = {}

function SocialQuestWowAPI.GetTime()                              return GetTime()                              end
function SocialQuestWowAPI.UnitName(unit)                         return UnitName(unit)                         end
function SocialQuestWowAPI.UnitFullName(unit)                     return UnitFullName(unit)                     end
function SocialQuestWowAPI.UnitLevel(unit)                        return UnitLevel(unit)                        end
function SocialQuestWowAPI.UnitRace(unit)                         return UnitRace(unit)                         end
function SocialQuestWowAPI.UnitFactionGroup(unit)                 return UnitFactionGroup(unit)                 end
function SocialQuestWowAPI.IsInRaid()                             return IsInRaid()                             end
function SocialQuestWowAPI.IsInGroup(category)                    return IsInGroup(category)                    end
function SocialQuestWowAPI.IsInGuild()                            return IsInGuild()                            end
function SocialQuestWowAPI.GetNumGroupMembers()                   return GetNumGroupMembers()                   end
function SocialQuestWowAPI.GetRaidRosterInfo(index)               return GetRaidRosterInfo(index)               end
function SocialQuestWowAPI.SendChatMessage(text, chan, lang, tgt)  return SendChatMessage(text, chan, lang, tgt)  end
function SocialQuestWowAPI.IsFriend(name)                         return C_FriendList.IsFriend(name)            end
function SocialQuestWowAPI.GetNumFriends()                        return C_FriendList.GetNumFriends()           end
function SocialQuestWowAPI.GetFriendInfoByIndex(index)            return C_FriendList.GetFriendInfoByIndex(index) end
function SocialQuestWowAPI.TimerAfter(delay, fn)                   C_Timer.After(delay, fn)                      end
function SocialQuestWowAPI.GetTaxiNodeInfo(index)                 return GetTaxiNodeInfo(index)                 end

-- IsInGroup accepts an optional category argument. When called as
-- SQWowAPI.IsInGroup() (no arg), Lua passes nil, which the WoW API
-- treats as the no-argument form (checks home group only).

-- Version-dependent enum constants. If a future WoW version renames
-- these, update only this file.
SocialQuestWowAPI.PARTY_CATEGORY_HOME     = LE_PARTY_CATEGORY_HOME
SocialQuestWowAPI.PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
```

- [ ] **Step 2: Verify the file exists and has no syntax errors**

Open WoW with the addon loaded and run `/sq debug on`. If the addon loads without Lua errors, the file is syntactically correct. Alternatively, check that the file exists at `Core/WowAPI.lua` before proceeding.

- [ ] **Step 3: Commit**

```bash
git add "Core/WowAPI.lua"
git commit -m "feat: add Core/WowAPI.lua with game-state API stubs"
```

---

### Task 2: Create Core/WowUI.lua

**Files:**
- Create: `Core/WowUI.lua`

- [ ] **Step 1: Create the file with all stubs**

Create `Core/WowUI.lua` with this exact content:

```lua
-- Core/WowUI.lua
-- Thin pass-through wrappers around volatile WoW UI-layer primitives.
-- These are the UI APIs confirmed to differ across Classic → Retail.
-- Stable WoW UI primitives (CreateFrame, UIParent, hooksecurefunc, etc.)
-- are left as direct calls — they are consistent across all target versions.

SocialQuestWowUI = {}

-- Displays a raid/banner message. Guards against RaidWarningFrame being nil
-- (possible before the UI is fully initialized).
function SocialQuestWowUI.AddRaidNotice(msg, colorInfo)
    if not RaidWarningFrame then return end
    RaidNotice_AddMessage(RaidWarningFrame, msg, colorInfo)
end

-- Tab sizing. PanelTemplates_TabResize was reworked in the Dragonflight UI redesign.
-- absoluteSize and tabWidth are optional; pass nil to omit.
function SocialQuestWowUI.TabResize(tab, padding, absoluteSize, tabWidth)
    PanelTemplates_TabResize(tab, padding, absoluteSize, tabWidth)
end

-- Tab state helpers. Same PanelTemplates family as TabResize; reworked in Dragonflight.
function SocialQuestWowUI.SelectTab(tab)
    PanelTemplates_SelectTab(tab)
end

function SocialQuestWowUI.DeselectTab(tab)
    PanelTemplates_DeselectTab(tab)
end

-- Chat frame output. Included for completeness — WoW-specific object method.
function SocialQuestWowUI.AddChatMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end
```

- [ ] **Step 2: Verify no Lua errors on load**

Load in WoW; confirm no errors from this file.

- [ ] **Step 3: Commit**

```bash
git add "Core/WowUI.lua"
git commit -m "feat: add Core/WowUI.lua with volatile WoW UI API stubs"
```

---

### Task 3: Wire both files into SocialQuest.toc

**Files:**
- Modify: `SocialQuest.toc`

The current TOC has the locale files followed immediately by `SocialQuest.lua`. The two new abstraction modules must load after the locales and before all game-logic modules.

- [ ] **Step 1: Add the new files to the TOC**

In `SocialQuest.toc`, find this block:

```
Locales\jaJP.lua

# Main modules
SocialQuest.lua
```

Replace it with:

```
Locales\jaJP.lua

# Core abstraction layer — after locales, before all game-logic modules
Core\WowAPI.lua
Core\WowUI.lua

# Main modules
SocialQuest.lua
```

- [ ] **Step 2: Verify load order**

Reload WoW. Both `SocialQuestWowAPI` and `SocialQuestWowUI` should be non-nil globals. Verify in WoW chat: `/run print(type(SocialQuestWowAPI))` should print `table`. Same for `SocialQuestWowUI`.

- [ ] **Step 3: Commit**

```bash
git add "SocialQuest.toc"
git commit -m "chore: add WowAPI.lua and WowUI.lua to TOC load order"
```

---

## Chunk 2: Quest-log API replacements (RowFactory and PartyTab)

### Task 4: Refactor UI/RowFactory.lua — replace quest-log calls with AQL

**Files:**
- Modify: `UI/RowFactory.lua`

Three changes in this file:
1. Remove the `getDifficultyColor` local helper and replace its call sites with `AQL:GetQuestDifficultyColor`.
2. Replace `GetTime()` with `SQWowAPI.GetTime()` in `formatTimeRemaining`.
3. Replace the entire body of `openQuestLogToQuest` with AQL calls.

- [ ] **Step 1: Add the local alias at the top of the file**

After line 12 (`local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")`), add:

```lua
local SQWowAPI = SocialQuestWowAPI
```

- [ ] **Step 2: Remove getDifficultyColor and replace its call sites**

Delete the entire `getDifficultyColor` function (lines 26–37):

```lua
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
```

Then grep for `getDifficultyColor(` in the file to find every call site. Replace each call:

```lua
-- Before:
local color = getDifficultyColor(questLevel)
-- After:
local color = SocialQuest.AQL:GetQuestDifficultyColor(questLevel)
```

- [ ] **Step 3: Replace GetTime() in formatTimeRemaining**

Find the `formatTimeRemaining` function (around line 40). Change:

```lua
    local remaining = timerSeconds - (GetTime() - snapshotTime)
```

to:

```lua
    local remaining = timerSeconds - (SQWowAPI.GetTime() - snapshotTime)
```

- [ ] **Step 4: Replace the body of openQuestLogToQuest**

Find the `openQuestLogToQuest` function (lines 53–105). Replace its entire body with:

```lua
local function openQuestLogToQuest(questID)
    local AQL = SocialQuest.AQL
    if not AQL then return end
    -- Toggle: if the log is shown and this quest is already selected, close it.
    if AQL:IsQuestLogShown() and AQL:GetSelectedQuestId() == questID then
        AQL:HideQuestLog()
        return
    end
    -- Save collapsed state, expand all to make the quest visible, navigate, restore.
    local zones = AQL:GetQuestLogZones()
    AQL:ShowQuestLog()
    AQL:ExpandAllQuestLogHeaders()
    local logIndex = AQL:GetQuestLogIndex(questID)
    if logIndex then AQL:SetQuestLogSelection(logIndex) end
    for _, z in ipairs(zones) do
        if z.isCollapsed then AQL:CollapseQuestLogZoneByName(z.name) end
    end
end
```

- [ ] **Step 5: Verify no bare WoW quest-log globals remain**

Run these greps and confirm zero results in `UI/RowFactory.lua`:

```bash
grep -n "GetQuestDifficultyColor\|GetQuestLogTitle\|GetNumQuestLogEntries\|ShowUIPanel\|HideUIPanel\|ExpandQuestHeader\|CollapseQuestHeader\|QuestLog_SetSelection\|QuestLog_Update\|QuestLogFrame\|UnitLevel\|GetTime()" "UI/RowFactory.lua" | grep -v "SQWowAPI\|SQWowUI\|AQL:"
```

Expected: no matches (or only matches inside comments).

- [ ] **Step 6: Commit**

```bash
git add "UI/RowFactory.lua"
git commit -m "refactor: replace WoW quest-log API calls with AQL in RowFactory"
```

---

### Task 5: Refactor UI/Tabs/PartyTab.lua — simplify isEligibleForShare

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

The `isEligibleForShare` function (lines 24–63) manually saves selection, selects by logIndex, calls `GetQuestLogPushable()`, and restores. This is exactly what `AQL:IsQuestIdShareable(questID)` does internally. Replace the entire Check 1 block with a single AQL call.

- [ ] **Step 1: Find and replace Check 1 in isEligibleForShare**

The current Check 1 block (lines 33–44) reads:

```lua
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
```

Replace it with:

```lua
    if not AQL:IsQuestIdShareable(questID) then return false end
```

- [ ] **Step 2: Verify no bare WoW quest-log globals remain**

```bash
grep -n "GetQuestLogSelection\|SelectQuestLogEntry\|GetQuestLogTitle\|GetQuestLogPushable\|QuestLog_SetSelection\|QuestLog_Update" "UI/Tabs/PartyTab.lua" | grep -v "SQWowAPI\|AQL:"
```

Expected: no matches.

- [ ] **Step 3: Load in WoW and verify the Party tab renders**

Open the SocialQuest window, click the Party tab. Confirm it renders without errors. If you have a quest that could be shared with a party member, confirm the "Needs it Shared" indicator still appears correctly.

- [ ] **Step 4: Commit**

```bash
git add "UI/Tabs/PartyTab.lua"
git commit -m "refactor: replace WoW quest-log API calls with AQL in PartyTab"
```

---

## Chunk 3: Core game-logic file refactors

### Task 6: Refactor SocialQuest.lua

**Files:**
- Modify: `SocialQuest.lua`

Calls to replace: `UnitRace`, `UnitFactionGroup`, `GetTaxiNodeInfo`, `GetTime` (9 call sites), `UnitName` (in `OnAutoFollowBegin`), `DEFAULT_CHAT_FRAME:AddMessage` (in `Debug` helper).

- [ ] **Step 1: Add local aliases near the top of the file**

After the `local AQL` and `local L` declarations (around lines 18–19), add:

```lua
local SQWowAPI = SocialQuestWowAPI
local SQWowUI  = SocialQuestWowUI
```

- [ ] **Step 2: Replace UnitRace and UnitFactionGroup in getStartingNode**

Find `getStartingNode()` (around lines 62–71). Change:

```lua
    local _, race = UnitRace("player")
```
to:
```lua
    local _, race = SQWowAPI.UnitRace("player")
```

And:
```lua
    local faction = UnitFactionGroup("player")
```
to:
```lua
    local faction = SQWowAPI.UnitFactionGroup("player")
```

- [ ] **Step 3: Replace GetTime in zone suppression (9 call sites)**

All 9 uses of `GetTime()` in this file relate to zone transition suppression. Run:

```bash
grep -n "GetTime()" "SocialQuest.lua"
```

Replace every occurrence:
- `GetTime()` → `SQWowAPI.GetTime()`

There is 1 setter (in `OnPlayerEnteringWorld`) and 8 guard checks at the top of each AQL callback handler.

- [ ] **Step 4: Replace UnitName in OnAutoFollowBegin**

Find the `OnAutoFollowBegin` handler (around line 381):

```lua
    local name = UnitName(unit)
```

Replace with:

```lua
    local name = SQWowAPI.UnitName(unit)
```

- [ ] **Step 5: Replace DEFAULT_CHAT_FRAME:AddMessage in Debug helper**

Find the `Debug` method (around line 213):

```lua
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD200[SQ][" .. tag .. "]|r " .. tostring(msg))
```

Replace with:

```lua
    SQWowUI.AddChatMessage("|cFFFFD200[SQ][" .. tag .. "]|r " .. tostring(msg))
```

- [ ] **Step 6: Replace GetTaxiNodeInfo in OnTaxiMapOpened**

Find the `OnTaxiMapOpened` handler (around line 414):

```lua
        local name = GetTaxiNodeInfo(i)
```

Replace with:

```lua
        local name = SQWowAPI.GetTaxiNodeInfo(i)
```

- [ ] **Step 7: Verify no bare WoW globals remain**

```bash
grep -n "UnitRace\|UnitFactionGroup\|GetTaxiNodeInfo\|GetTime()\|UnitName\|DEFAULT_CHAT_FRAME" "SocialQuest.lua" | grep -v "SQWowAPI\|SQWowUI"
```

Expected: no matches outside of comments.

- [ ] **Step 8: Commit**

```bash
git add "SocialQuest.lua"
git commit -m "refactor: replace direct WoW API calls with SQWowAPI in SocialQuest.lua"
```

---

### Task 7: Refactor Core/GroupComposition.lua

**Files:**
- Modify: `Core/GroupComposition.lua`

Calls to replace: `IsInRaid`, `IsInGroup` (with `LE_PARTY_CATEGORY_HOME` and `LE_PARTY_CATEGORY_INSTANCE`), `GetNumGroupMembers`, `GetRaidRosterInfo`, `UnitName`.

- [ ] **Step 1: Add local alias at the top of the file**

After the `local GroupType = { ... }` block (around line 22), add:

```lua
local SQWowAPI = SocialQuestWowAPI
```

- [ ] **Step 2: Replace currentGroupType() body**

The `currentGroupType()` function (lines 34–43) currently reads:

```lua
local function currentGroupType()
    if IsInRaid() then
        return GroupType.Raid
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return GroupType.Battleground
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return GroupType.Party
    end
    return nil
end
```

Replace with:

```lua
local function currentGroupType()
    if SQWowAPI.IsInRaid() then
        return GroupType.Raid
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
        return GroupType.Battleground
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME) then
        return GroupType.Party
    end
    return nil
end
```

- [ ] **Step 3: Replace UnitName in OnGroupRosterUpdate**

Line 75:
```lua
    local selfName  = normalize(UnitName("player"))
```
→
```lua
    local selfName  = normalize(SQWowAPI.UnitName("player"))
```

Line 109:
```lua
            local name, realm = UnitName("party" .. i)
```
→
```lua
            local name, realm = SQWowAPI.UnitName("party" .. i)
```

- [ ] **Step 4: Replace GetNumGroupMembers and GetRaidRosterInfo**

Line 95:
```lua
        local count = GetNumGroupMembers()
```
→
```lua
        local count = SQWowAPI.GetNumGroupMembers()
```

Line 97:
```lua
            local name, _, subgroup = GetRaidRosterInfo(i)
```
→
```lua
            local name, _, subgroup = SQWowAPI.GetRaidRosterInfo(i)
```

Line 107:
```lua
        local count = GetNumGroupMembers()
```
→
```lua
        local count = SQWowAPI.GetNumGroupMembers()
```

- [ ] **Step 5: Verify no bare WoW globals remain**

```bash
grep -n "IsInRaid\|IsInGroup\|LE_PARTY_CATEGORY\|GetNumGroupMembers\|GetRaidRosterInfo\|UnitName" "Core/GroupComposition.lua" | grep -v "SQWowAPI"
```

Expected: no matches outside comments.

- [ ] **Step 6: Commit**

```bash
git add "Core/GroupComposition.lua"
git commit -m "refactor: replace direct WoW API calls with SQWowAPI in GroupComposition"
```

---

### Task 8: Refactor Core/GroupData.lua

**Files:**
- Modify: `Core/GroupData.lua`

Calls to replace: `GetTime` (lines 70, 91, 95, 184), `UnitName` (line 175).

- [ ] **Step 1: Add local alias at the top of the file**

After `SocialQuestGroupData.PlayerQuests = {}` (line 20), add:

```lua
local SQWowAPI = SocialQuestWowAPI
```

- [ ] **Step 2: Replace all GetTime() calls**

Run:
```bash
grep -n "GetTime()" "Core/GroupData.lua"
```

Replace every occurrence of `GetTime()` with `SQWowAPI.GetTime()`. There are 4 call sites (lines 70, 91, 95, 184).

- [ ] **Step 3: Replace UnitName**

Line 175:
```lua
    local name, realm = UnitName(unit)
```
→
```lua
    local name, realm = SQWowAPI.UnitName(unit)
```

- [ ] **Step 4: Verify no bare WoW globals remain**

```bash
grep -n "GetTime()\|UnitName(" "Core/GroupData.lua" | grep -v "SQWowAPI"
```

Expected: no matches outside comments.

- [ ] **Step 5: Commit**

```bash
git add "Core/GroupData.lua"
git commit -m "refactor: replace direct WoW API calls with SQWowAPI in GroupData"
```

---

## Chunk 4: Communications, Announcements, GroupFrame

### Task 9: Refactor Core/Communications.lua

**Files:**
- Modify: `Core/Communications.lua`

Calls to replace: `IsInGroup()` zero-arg (line 147), `IsInRaid` (lines 147, 246), `IsInGroup` with category (lines 248, 250), `LE_PARTY_CATEGORY_INSTANCE` (line 248), `LE_PARTY_CATEGORY_HOME` (line 250), `UnitFullName` (line 281), `GetTime` (lines 69, 92, 303, 306, 331, 337).

- [ ] **Step 1: Add local alias at the top of the file**

After the `local GroupType = SocialQuestGroupComposition.GroupType` line (line 27), add:

```lua
local SQWowAPI = SocialQuestWowAPI
```

- [ ] **Step 2: Replace GetTime calls (6 call sites)**

Run:
```bash
grep -n "GetTime()" "Core/Communications.lua"
```

Replace every `GetTime()` with `SQWowAPI.GetTime()`.

- [ ] **Step 3: Replace zero-argument IsInGroup and IsInRaid in SendFlightDiscovery**

Line 147:
```lua
    if not IsInGroup() or IsInRaid() then return end
```
→
```lua
    if not SQWowAPI.IsInGroup() or SQWowAPI.IsInRaid() then return end
```

- [ ] **Step 4: Replace IsInRaid, IsInGroup, and LE_PARTY_CATEGORY_* in the channel-selection block**

Lines 246–251 (the channel-selection logic inside a send helper):
```lua
    if IsInRaid() then
        ...
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        ...
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        ...
```
→
```lua
    if SQWowAPI.IsInRaid() then
        ...
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
        ...
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME) then
        ...
```

- [ ] **Step 5: Replace UnitFullName**

Line 281:
```lua
    local myName, myRealm = UnitFullName("player")
```
→
```lua
    local myName, myRealm = SQWowAPI.UnitFullName("player")
```

- [ ] **Step 6: Verify no bare WoW globals remain**

```bash
grep -n "IsInRaid\|IsInGroup\|LE_PARTY_CATEGORY\|UnitFullName\|GetTime()" "Core/Communications.lua" | grep -v "SQWowAPI"
```

Expected: no matches outside comments.

- [ ] **Step 7: Commit**

```bash
git add "Core/Communications.lua"
git commit -m "refactor: replace direct WoW API calls with SQWowAPI in Communications"
```

---

### Task 10: Refactor Core/Announcements.lua

**Files:**
- Modify: `Core/Announcements.lua`

This is the largest consumer. Calls to replace:
- `GetTime()` — line 55 (throttle ticker)
- `SendChatMessage(...)` — line 58 (inside throttle ticker closure)
- `RaidNotice_AddMessage(RaidWarningFrame, ...)` — line 135 (also remove the `if not RaidWarningFrame then return end` guard; it moves into `SQWowUI.AddRaidNotice`)
- `DEFAULT_CHAT_FRAME:AddMessage(...)` — line 140
- `IsInRaid()` — lines 176, 219, 704
- `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` — lines 178, 235, 284
- `IsInGroup(LE_PARTY_CATEGORY_HOME)` — lines 211, 276
- `IsInGuild()` — line 227
- `C_FriendList.IsFriend(sender)` — lines 437, 442, 489, 494
- `UnitName("player")` — line 669
- `C_FriendList.GetNumFriends()` — line 683
- `C_FriendList.GetFriendInfoByIndex(i)` — line 685
- `GetNumGroupMembers()` — line 702
- `UnitName(unit)` — line 705

- [ ] **Step 1: Add local aliases at the top of the file**

After `local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")` (line 30), add:

```lua
local SQWowAPI = SocialQuestWowAPI
local SQWowUI  = SocialQuestWowUI
```

- [ ] **Step 2: Replace GetTime and SendChatMessage in the throttle ticker**

Lines 55–59 currently read:

```lua
        local now = GetTime()
        if #throttleQueue > 0 and (now - lastSendTime) >= THROTTLE_DELAY then
            local item = table.remove(throttleQueue, 1)
            SendChatMessage(item.text, item.channel, nil, item.target)
            lastSendTime = now
```

Replace with:

```lua
        local now = SQWowAPI.GetTime()
        if #throttleQueue > 0 and (now - lastSendTime) >= THROTTLE_DELAY then
            local item = table.remove(throttleQueue, 1)
            SQWowAPI.SendChatMessage(item.text, item.channel, nil, item.target)
            lastSendTime = now
```

- [ ] **Step 3: Replace displayBanner**

The current `displayBanner` function (lines 130–136) reads:

```lua
local function displayBanner(msg, eventType)
    if not RaidWarningFrame then return end
    local color = SocialQuestColors.GetEventColor(eventType)
    local colorInfo = color and { r = color.r, g = color.g, b = color.b }
                   or { r = 1, g = 1, b = 0 }
    RaidNotice_AddMessage(RaidWarningFrame, msg, colorInfo)
end
```

Replace with:

```lua
local function displayBanner(msg, eventType)
    local color = SocialQuestColors.GetEventColor(eventType)
    local colorInfo = color and { r = color.r, g = color.g, b = color.b }
                   or { r = 1, g = 1, b = 0 }
    SQWowUI.AddRaidNotice(msg, colorInfo)
end
```

(The `if not RaidWarningFrame then return end` guard moves into `SQWowUI.AddRaidNotice` in `WowUI.lua`, so remove it here.)

- [ ] **Step 4: Replace displayChatPreview**

Line 140:
```lua
    DEFAULT_CHAT_FRAME:AddMessage(L["|cFF00CCFFSocialQuest (preview):|r "] .. preview)
```
→
```lua
    SQWowUI.AddChatMessage(L["|cFF00CCFFSocialQuest (preview):|r "] .. preview)
```

- [ ] **Step 5: Replace getSenderSection**

The `getSenderSection()` function (lines 175–183) reads:

```lua
local function getSenderSection()
    if IsInRaid() then
        return "raid"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "battleground"
    else
        return "party"
    end
end
```

Replace with:

```lua
local function getSenderSection()
    if SQWowAPI.IsInRaid() then
        return "raid"
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
        return "battleground"
    else
        return "party"
    end
end
```

- [ ] **Step 6: Replace remaining IsInRaid / IsInGroup / IsInGuild / LE_PARTY_CATEGORY_* calls**

Run:
```bash
grep -n "IsInRaid\|IsInGroup\|IsInGuild\|LE_PARTY_CATEGORY" "Core/Announcements.lua"
```

For each remaining match, apply the pattern:
- `IsInRaid()` → `SQWowAPI.IsInRaid()`
- `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` → `SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)`
- `IsInGroup(LE_PARTY_CATEGORY_HOME)` → `SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)`
- `IsInGuild()` → `SQWowAPI.IsInGuild()`

Call sites to hit: lines 211, 219, 227, 235, 276, 284.

- [ ] **Step 7: Replace C_FriendList calls (4 IsFriend, 1 GetNumFriends, 1 GetFriendInfoByIndex)**

```bash
grep -n "C_FriendList" "Core/Announcements.lua"
```

Apply:
- `C_FriendList.IsFriend(sender)` → `SQWowAPI.IsFriend(sender)` (lines 437, 442, 489, 494)
- `C_FriendList.GetNumFriends()` → `SQWowAPI.GetNumFriends()` (line 683)
- `C_FriendList.GetFriendInfoByIndex(i)` → `SQWowAPI.GetFriendInfoByIndex(i)` (line 685)

- [ ] **Step 8: Replace UnitName and GetNumGroupMembers in WhisperFriends helper**

Line 669:
```lua
    local msg = string.format(L["%s unlocked flight path: %s"], UnitName("player") or "You", nodeName)
```
→
```lua
    local msg = string.format(L["%s unlocked flight path: %s"], SQWowAPI.UnitName("player") or "You", nodeName)
```

Line 702:
```lua
    local numMembers = GetNumGroupMembers()
```
→
```lua
    local numMembers = SQWowAPI.GetNumGroupMembers()
```

Line 704–705:
```lua
        local unit = IsInRaid() and ("raid"..i) or ("party"..i)
        local unitName = UnitName(unit)
```
→
```lua
        local unit = SQWowAPI.IsInRaid() and ("raid"..i) or ("party"..i)
        local unitName = SQWowAPI.UnitName(unit)
```

- [ ] **Step 9: Verify no bare WoW globals remain**

```bash
grep -n "IsInRaid\|IsInGroup\|IsInGuild\|LE_PARTY_CATEGORY\|C_FriendList\|GetNumGroupMembers\|UnitName\|GetTime()\|SendChatMessage\|RaidNotice_AddMessage\|DEFAULT_CHAT_FRAME" "Core/Announcements.lua" | grep -v "SQWowAPI\|SQWowUI"
```

Expected: no matches outside comments.

- [ ] **Step 10: Commit**

```bash
git add "Core/Announcements.lua"
git commit -m "refactor: replace direct WoW API calls with SQWowAPI/SQWowUI in Announcements"
```

---

### Task 11: Refactor UI/GroupFrame.lua

**Files:**
- Modify: `UI/GroupFrame.lua`

Calls to replace: `C_Timer.After` (lines 216 and 311), `PanelTemplates_TabResize` (line 143), `PanelTemplates_SelectTab` (line 266), `PanelTemplates_DeselectTab` (line 268).

- [ ] **Step 1: Add local aliases at the top of the file**

After `local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")` (line 13), add:

```lua
local SQWowAPI = SocialQuestWowAPI
local SQWowUI  = SocialQuestWowUI
```

- [ ] **Step 2: Replace C_Timer.After (2 call sites)**

Line 216:
```lua
    C_Timer.After(0, function()
```
→
```lua
    SQWowAPI.TimerAfter(0, function()
```

Line 311:
```lua
    C_Timer.After(0, function()
```
→
```lua
    SQWowAPI.TimerAfter(0, function()
```

- [ ] **Step 3: Replace PanelTemplates_TabResize**

Line 143:
```lua
        PanelTemplates_TabResize(p.tab, 0, 120, 120)
```
→
```lua
        SQWowUI.TabResize(p.tab, 0, 120, 120)
```

- [ ] **Step 4: Replace PanelTemplates_SelectTab and PanelTemplates_DeselectTab**

Line 266:
```lua
                PanelTemplates_SelectTab(p.tab)
```
→
```lua
                SQWowUI.SelectTab(p.tab)
```

Line 268:
```lua
                PanelTemplates_DeselectTab(p.tab)
```
→
```lua
                SQWowUI.DeselectTab(p.tab)
```

- [ ] **Step 5: Verify no bare WoW globals remain**

```bash
grep -n "C_Timer\|PanelTemplates_Tab\|PanelTemplates_Select\|PanelTemplates_Deselect" "UI/GroupFrame.lua" | grep -v "SQWowAPI\|SQWowUI"
```

Expected: no matches outside comments.

- [ ] **Step 6: Open the SocialQuest window in WoW and verify**

- Open the window (`/sq`). Tabs should render and be clickable.
- Switch between tabs. The active tab should appear selected (depressed) and inactive tabs deselected.
- No Lua errors in the chat frame.

- [ ] **Step 7: Commit**

```bash
git add "UI/GroupFrame.lua"
git commit -m "refactor: replace direct WoW API calls with SQWowAPI/SQWowUI in GroupFrame"
```

---

### Note: UI/Tooltips.lua — no changes required

`UI/Tooltips.lua` uses only `hooksecurefunc` and `ItemRefTooltip`, both stable WoW UI primitives explicitly out of scope per the spec. No tasks needed for this file.

---

### Task 12: Version bump and documentation update

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Bump version in SocialQuest.toc**

Current: `## Version: 2.6.0`

Today is 2026-03-24. This is the first change today, so increment the minor version and reset revision:

New: `## Version: 2.7.0`

- [ ] **Step 2: Update CLAUDE.md Architecture section**

In `CLAUDE.md`, update the Core Modules table to add the two new files:

```markdown
| `Core\WowAPI.lua` | `SocialQuestWowAPI` | Thin pass-through wrappers for all WoW game-state and data globals. All version-specific branching for non-quest APIs lives here. Consumer files access via `local SQWowAPI = SocialQuestWowAPI`. |
| `Core\WowUI.lua` | `SocialQuestWowUI` | Thin pass-through wrappers for volatile WoW UI-layer primitives (`RaidNotice_AddMessage`, `PanelTemplates_*`, `DEFAULT_CHAT_FRAME`). Consumer files access via `local SQWowUI = SocialQuestWowUI`. |
```

- [ ] **Step 3: Add Version 2.7.0 entry to the Version History section in CLAUDE.md**

```markdown
### Version 2.7.0 (March 2026 — Improvements branch)
- Added `Core/WowAPI.lua` (`SocialQuestWowAPI`) and `Core/WowUI.lua` (`SocialQuestWowUI`) abstraction modules. All direct WoW game-state/data API calls now route through `SQWowAPI`; volatile WoW UI primitives route through `SQWowUI`. Quest and quest-log API calls replaced with AQL public API calls. Prepares SocialQuest to support multiple WoW interface versions without scattered direct WoW API usage.
```

- [ ] **Step 4: Commit**

```bash
git add "SocialQuest.toc" "CLAUDE.md"
git commit -m "chore: bump version to 2.7.0, document WoW API abstraction layer"
```
