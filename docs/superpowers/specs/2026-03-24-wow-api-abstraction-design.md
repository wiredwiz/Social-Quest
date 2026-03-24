# SocialQuest WoW API Abstraction Layer Design

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize all WoW API calls in SocialQuest behind two thin abstraction modules so the addon can target multiple WoW interface versions in the future without hunting for direct API calls scattered across the codebase.

**Architecture:** Two new files in `Core/` — `WowAPI.lua` for game-state/data APIs and `WowUI.lua` for volatile WoW UI-layer primitives. Every consumer file declares a local alias to the global module table. Quest and quest-log WoW API calls are replaced with appropriate AQL public API calls rather than wrapped.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), AQL library (`AbsoluteQuestLog-1.0`)

---

## Scope

### In scope
- All direct WoW game-state and data API calls across SocialQuest (unit info, group membership, friend list, taxi, communications, timers)
- All volatile WoW UI-layer primitive calls (`RaidNotice_AddMessage`, `PanelTemplates_TabResize`, `DEFAULT_CHAT_FRAME:AddMessage`)
- All quest and quest-log WoW API calls — replaced with AQL public API calls (not wrapped)
- WoW enum constants (`LE_PARTY_CATEGORY_HOME`, `LE_PARTY_CATEGORY_INSTANCE`) exposed as module properties

### Out of scope
- Stable WoW UI framework primitives: `CreateFrame`, `UIParent`, `UISpecialFrames`, `tinsert`, `GameTooltip`, `ItemRefTooltip`, `hooksecurefunc`, `UIErrorsFrame` — these are consistent across Classic and forward and are left as direct calls
- Original Vanilla (Interface 11xxx) — minimum target is Classic Era / Classic TBC and forward
- AQL internals — AQL already abstracts its own WoW quest API calls via `Core/WowQuestAPI.lua`

---

## File Structure

Two new files added to `Core/`, loaded before all existing Core and UI modules:

| File | Global | Responsibility |
|---|---|---|
| `Core/WowAPI.lua` | `SocialQuestWowAPI` | Game-state and data API stubs |
| `Core/WowUI.lua` | `SocialQuestWowUI` | Volatile WoW UI-layer primitive stubs |

### TOC load order

Both files load immediately after the locales and before `SocialQuest.lua`:

```
# Core abstraction layer  (NEW — before all other modules)
Core\WowAPI.lua
Core\WowUI.lua

# Main modules
SocialQuest.lua
Core\GroupComposition.lua
...
```

### Consumer pattern

Every file that uses WoW APIs declares a local alias at file scope:

```lua
local SQWowAPI = SocialQuestWowAPI   -- game-state/data
local SQWowUI  = SocialQuestWowUI    -- volatile UI primitives (only where needed)
```

Call sites read `SQWowAPI.GetTime()`, `SQWowAPI.IsInRaid()`, `SQWowUI.AddRaidNotice(msg, colorInfo)`, etc. The local alias provides one fewer global table lookup per call versus `SocialQuestWowAPI.GetTime()` directly, and `SQWowAPI` is distinct enough for unambiguous grepping.

---

## Core/WowAPI.lua

Plain global table. No metatables, no OOP, no lazy initialization. All stubs are one-liners. Loaded at file scope and ready before any consumer.

### Function stubs

| Wrapper method | Delegates to |
|---|---|
| `SocialQuestWowAPI.GetTime()` | `GetTime()` |
| `SocialQuestWowAPI.UnitName(unit)` | `UnitName(unit)` |
| `SocialQuestWowAPI.UnitFullName(unit)` | `UnitFullName(unit)` |
| `SocialQuestWowAPI.UnitLevel(unit)` | `UnitLevel(unit)` |
| `SocialQuestWowAPI.UnitRace(unit)` | `UnitRace(unit)` |
| `SocialQuestWowAPI.UnitFactionGroup(unit)` | `UnitFactionGroup(unit)` |
| `SocialQuestWowAPI.IsInRaid()` | `IsInRaid()` |
| `SocialQuestWowAPI.IsInGroup(category)` | `IsInGroup(category)` |
| `SocialQuestWowAPI.IsInGuild()` | `IsInGuild()` |
| `SocialQuestWowAPI.GetNumGroupMembers()` | `GetNumGroupMembers()` |
| `SocialQuestWowAPI.GetRaidRosterInfo(index)` | `GetRaidRosterInfo(index)` |
| `SocialQuestWowAPI.SendChatMessage(text, channel, language, target)` | `SendChatMessage(text, channel, language, target)` |
| `SocialQuestWowAPI.IsFriend(name)` | `C_FriendList.IsFriend(name)` |
| `SocialQuestWowAPI.GetNumFriends()` | `C_FriendList.GetNumFriends()` |
| `SocialQuestWowAPI.GetFriendInfoByIndex(index)` | `C_FriendList.GetFriendInfoByIndex(index)` |
| `SocialQuestWowAPI.TimerAfter(delay, fn)` | `C_Timer.After(delay, fn)` |
| `SocialQuestWowAPI.GetTaxiNodeInfo(index)` | `GetTaxiNodeInfo(index)` |

### Constants (set at load time)

```lua
SocialQuestWowAPI.PARTY_CATEGORY_HOME     = LE_PARTY_CATEGORY_HOME
SocialQuestWowAPI.PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
```

Exposed as module properties rather than function calls. If a future version renames these enums, only `WowAPI.lua` needs updating.

### Error handling

No error handling inside stubs. These are pass-throughs — if the underlying WoW API errors, WoW surfaces it. Swallowing errors here would hide bugs.

---

## Core/WowUI.lua

Same plain table pattern as `WowAPI.lua`. Only the volatile WoW UI primitives are wrapped — ones confirmed to differ across Classic → Retail. Stable primitives are left as direct WoW calls.

### Function stubs

| Wrapper method | Delegates to | Why volatile |
|---|---|---|
| `SocialQuestWowUI.AddRaidNotice(msg, colorInfo)` | `RaidNotice_AddMessage(RaidWarningFrame, msg, colorInfo)` | Signature and `RaidWarningFrame` reference differ across versions |
| `SocialQuestWowUI.TabResize(tab, padding, minWidth)` | `PanelTemplates_TabResize(tab, padding, minWidth)` | Reworked in Dragonflight UI redesign |
| `SocialQuestWowUI.AddChatMessage(msg)` | `DEFAULT_CHAT_FRAME:AddMessage(msg)` | WoW-specific object method call; included for completeness |

`AddRaidNotice` also guards against `RaidWarningFrame` being nil (possible before the UI is fully loaded):

```lua
function SocialQuestWowUI.AddRaidNotice(msg, colorInfo)
    if not RaidWarningFrame then return end
    RaidNotice_AddMessage(RaidWarningFrame, msg, colorInfo)
end
```

---

## Quest and Quest-Log API Replacements

Quest and quest-log WoW API calls are **replaced with AQL public API calls** — not wrapped in `WowUI` or `WowAPI`. AQL already centralizes WoW quest API access in its own `Core/WowQuestAPI.lua`.

### Case 1: `openQuestLogToQuest(questID)` in `UI/RowFactory.lua`

The function manually expands zone headers, scans by logIndex, selects, and re-collapses — all with raw WoW APIs. The entire body is replaced using AQL:

```lua
local function openQuestLogToQuest(questID)
    local AQL = SocialQuest.AQL
    -- Toggle: if shown and this quest is already selected, close
    if AQL:IsQuestLogShown() and AQL:GetSelectedQuestId() == questID then
        AQL:HideQuestLog()
        return
    end
    -- Save collapsed state, expand all to make quest visible, navigate, restore
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

### Case 2: `isEligibleForShare` in `UI/Tabs/PartyTab.lua`

The current code manually saves selection, selects the entry by logIndex, calls `GetQuestLogPushable()`, and restores — exactly what `AQL:IsQuestIdShareable(questID)` does internally. Check 1 collapses to:

```lua
if not AQL:IsQuestIdShareable(questID) then return false end
```

The manual save/select/check/restore block is removed entirely.

### Case 3: `getDifficultyColor` helper in `UI/RowFactory.lua`

The helper guards on `GetQuestDifficultyColor` and falls back to manual `UnitLevel("player")` math. `AQL:GetQuestDifficultyColor(level)` already has this fallback built in. The local helper is removed; call sites become:

```lua
local color = AQL:GetQuestDifficultyColor(questLevel)
```

### All other quest/quest-log replacements (one-for-one)

| Current call | Replaced with |
|---|---|
| `GetQuestLogSelection()` | `AQL:GetQuestLogSelection()` |
| `SelectQuestLogEntry(i)` | `AQL:SelectQuestLogEntry(i)` |
| `QuestLog_SetSelection(i)` + `QuestLog_Update()` | `AQL:SetQuestLogSelection(i)` |
| `ShowUIPanel(QuestLogFrame)` | `AQL:ShowQuestLog()` |
| `HideUIPanel(QuestLogFrame)` | `AQL:HideQuestLog()` |
| `ExpandQuestHeader(i)` | `AQL:ExpandQuestLogHeader(i)` |
| `CollapseQuestHeader(i)` | `AQL:CollapseQuestLogHeader(i)` |
| `GetQuestLogPushable()` | `AQL:IsQuestIdShareable(questID)` |
| `QuestLogFrame:IsShown()` | `AQL:IsQuestLogShown()` |
| `GetQuestLogTitle(i)` (for questID) | `AQL:GetSelectedQuestId()` or `AQL:GetQuestLogEntries()` |
| `GetNumQuestLogEntries()` + `GetQuestLogTitle(i)` loop | `AQL:GetQuestLogEntries()` |

---

## Files Modified

| File | Change |
|---|---|
| `Core/WowAPI.lua` | **New** — game-state/data stub module |
| `Core/WowUI.lua` | **New** — volatile UI primitive stub module |
| `SocialQuest.toc` | Add both new files before existing Core modules |
| `SocialQuest.lua` | Add `local SQWowAPI`; replace `UnitRace`, `UnitFactionGroup`, `GetTaxiNodeInfo` calls |
| `Core/GroupComposition.lua` | Add `local SQWowAPI`; replace `IsInRaid`, `IsInGroup`, `LE_PARTY_CATEGORY_*`, `GetNumGroupMembers`, `GetRaidRosterInfo`, `UnitName` calls |
| `Core/GroupData.lua` | Add `local SQWowAPI`; replace `GetTime`, `UnitName` calls |
| `Core/Communications.lua` | Add `local SQWowAPI`; replace `IsInRaid`, `IsInGroup`, `LE_PARTY_CATEGORY_*`, `UnitFullName`, `GetTime` calls |
| `Core/Announcements.lua` | Add `local SQWowAPI`, `local SQWowUI`; replace `GetTime`, `IsInRaid`, `IsInGroup`, `IsInGuild`, `SendChatMessage`, `C_FriendList.*`, `GetNumGroupMembers`, `UnitName`, `RaidNotice_AddMessage`, `DEFAULT_CHAT_FRAME:AddMessage` calls |
| `UI/RowFactory.lua` | Add `local SQWowAPI`; replace `GetTime`; replace quest-log calls with AQL; remove `getDifficultyColor` helper |
| `UI/Tabs/PartyTab.lua` | Replace quest-log calls with AQL; simplify `isEligibleForShare` |
| `UI/GroupFrame.lua` | Add `local SQWowUI`; replace `PanelTemplates_TabResize` with `SQWowUI.TabResize` |

---

## Commit Strategy

One focused commit per logical unit:

1. `feat: add Core/WowAPI.lua with game-state API stubs`
2. `feat: add Core/WowUI.lua with volatile WoW UI API stubs`
3. `refactor: replace WoW quest-log API calls with AQL in RowFactory and PartyTab`
4. `refactor: replace direct WoW API calls with SQWowAPI in SocialQuest.lua`
5. `refactor: replace direct WoW API calls with SQWowAPI in Core modules`
6. `refactor: replace direct WoW API calls with SQWowAPI/SQWowUI in UI modules`
7. `chore: bump version, update CLAUDE.md`
