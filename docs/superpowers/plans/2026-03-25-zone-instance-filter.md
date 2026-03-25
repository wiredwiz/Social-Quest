# Zone & Instance Auto-Filter Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-filtering of the Party and Shared tabs to the current dungeon instance or open-world zone, with per-tab dismissible labels and configurable toggles in the options panel.

**Architecture:** A new `UI/WindowFilter.lua` module owns all filter state (dismiss flags, filter computation via a private `computeFilterState()` helper). `GroupFrame:Refresh()` queries it and passes a filter table + tab ID down to each tab's `Render()` then `BuildTree()`. PartyTab and SharedTab skip quests whose zone doesn't match the active filter; MineTab accepts but ignores the filter for future-compatibility.

**Tech Stack:** Lua 5.1, Ace3 (AceDB, AceConfig, AceLocale), WoW TBC Anniversary (Interface 20505), AbsoluteQuestLog-1.0.

---

## File Map

| File | Action | What changes |
|------|--------|--------------|
| `Core/WowAPI.lua` | Modify | Add `GetRealZoneText()` and `IsInInstance()` wrappers |
| `SocialQuest.lua` | Modify | Add `window` defaults block; extend `OnPlayerEnteringWorld` |
| `Locales/enUS.lua` … `Locales/jaJP.lua` (12 files) | Modify | Add 7 new locale keys |
| `UI/WindowFilter.lua` | Create | `SocialQuestWindowFilter` module |
| `SocialQuest.toc` | Modify | Add `UI/WindowFilter.lua` entry |
| `UI/Options.lua` | Modify | Add `window` option group (order 9); debug moves to 10 |
| `UI/RowFactory.lua` | Modify | Add `AddFilterHeader()` |
| `UI/Tabs/MineTab.lua` | Modify | Update `BuildTree()` and `Render()` signatures |
| `UI/Tabs/PartyTab.lua` | Modify | `BuildTree(filterTable)`, `Render(..., filterTable, tabId)` |
| `UI/Tabs/SharedTab.lua` | Modify | Same as PartyTab |
| `UI/GroupFrame.lua` | Modify | Pass filter to `Render`; add `OnHide` reset |

---

## Chunk 1: Foundation

### Task 1: WowAPI wrappers

**Files:**
- Modify: `Core/WowAPI.lua` (after line 25, before the PARTY_CATEGORY constants)

- [ ] **Step 1: Add wrappers**

Open `Core/WowAPI.lua`. After the `GetTaxiNodeInfo` wrapper (line 24) and before the `PARTY_CATEGORY` constants (line 32), insert:

```lua
function SocialQuestWowAPI.GetRealZoneText()   return GetRealZoneText()   end
function SocialQuestWowAPI.IsInInstance()       return IsInInstance()       end
```

- [ ] **Step 2: Verify**

Code review: both are trivial pass-throughs following the exact same pattern as every other wrapper in the file. No in-game test needed at this stage.

- [ ] **Step 3: Commit**

```bash
git add Core/WowAPI.lua
git commit -m "feat: add GetRealZoneText and IsInInstance wrappers to WowAPI"
```

---

### Task 2: DB defaults

**Files:**
- Modify: `SocialQuest.lua` (in `GetDefaults()`, inside the `profile` table)

- [ ] **Step 1: Add window defaults**

In `SocialQuest.lua`, inside `GetDefaults()` → `profile` table, add the `window` key before the `minimap` entry (currently around line 342):

```lua
            window = {
                autoFilterInstance = true,
                autoFilterZone     = false,
            },
            minimap = { hide = false },
```

- [ ] **Step 2: Verify**

Code review: `window` sits at the same level as `general`, `party`, etc. — all are direct children of `profile`. AceDB will auto-populate missing keys from defaults on first load.

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.lua
git commit -m "feat: add window filter DB defaults (autoFilterInstance=true, autoFilterZone=false)"
```

---

### Task 3: Locale keys

**Files:**
- Modify: all 12 files in `Locales/` (`enUS`, `deDE`, `frFR`, `esES`, `esMX`, `zhCN`, `zhTW`, `ptBR`, `itIT`, `koKR`, `ruRU`, `jaJP`)

Seven new keys are needed. In `enUS.lua` the value is `true` (the key string is the string). In all other locale files the value is a string — use the English text as a placeholder until community translations are provided.

- [ ] **Step 1: Add keys to enUS.lua**

Open `Locales/enUS.lua`. Append a new section near the end of the file (before the final `end` if present, or just at the end):

```lua
-- UI/WindowFilter.lua — filter header labels
L["Instance: %s"]                                                                                        = true
L["Zone: %s"]                                                                                            = true

-- UI/Options.lua — Social Quest Window group
L["Social Quest Window"]                                                                                 = true
L["Auto-filter to current instance"]                                                                     = true
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = true
L["Auto-filter to current zone"]                                                                         = true
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."]             = true
```

- [ ] **Step 2: Add keys to all other locale files**

For each of the 11 remaining locale files (`deDE`, `frFR`, `esES`, `esMX`, `zhCN`, `zhTW`, `ptBR`, `itIT`, `koKR`, `ruRU`, `jaJP`), append the same block but with English string values as placeholders (not `true`):

```lua
-- UI/WindowFilter.lua — filter header labels
L["Instance: %s"]                                                                                          = "Instance: %s"
L["Zone: %s"]                                                                                              = "Zone: %s"

-- UI/Options.lua — Social Quest Window group
L["Social Quest Window"]                                                                                   = "Social Quest Window"
L["Auto-filter to current instance"]                                                                       = "Auto-filter to current instance"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."
L["Auto-filter to current zone"]                                                                           = "Auto-filter to current zone"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."]               = "Outside of instances, the Party and Shared tabs show only quests for your current zone."
```

**Important:** Each locale file starts with a guard: `if not L then return end`. Verify the appended block is inside the file scope (before any final `end`) to avoid a no-op. In practice all locale files are flat — there is no wrapping `do/end` block — so appending at the end of the file is correct.

- [ ] **Step 3: Verify**

Spot-check `zhCN.lua` and `jaJP.lua` — both had past issues with string escaping. The new strings contain no special characters so no escaping is needed.

- [ ] **Step 4: Commit**

```bash
git add Locales/
git commit -m "feat: add locale keys for zone/instance filter feature"
```

---

### Task 4: WindowFilter module + TOC entry

**Files:**
- Create: `UI/WindowFilter.lua`
- Modify: `SocialQuest.toc`

- [ ] **Step 1: Create UI/WindowFilter.lua**

```lua
-- UI/WindowFilter.lua
-- Owns per-tab filter state for the SocialQuest group window.
-- Computes the active zone/instance filter from current player location and settings.
-- Provides GetActiveFilter(tabId), GetFilterLabel(tabId), Dismiss(tabId), Reset().

SocialQuestWindowFilter = {}

local SQWowAPI = SocialQuestWowAPI
local L        = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

-- Per-tab dismiss state. [tabId] = true when the user has dismissed the filter for
-- that tab. Cleared on zone change, window close, or settings toggle.
local dismissed = {}

------------------------------------------------------------------------
-- Private helper
------------------------------------------------------------------------

-- Computes the active filter state from game state and current settings.
-- Does NOT check dismissed — callers are responsible for that.
-- Returns { filter = { zone = "..." }, label = "Instance: ..." } or nil.
local function computeFilterState()
    local db = SocialQuest.db.profile

    if db.window.autoFilterInstance then
        local inInstance, instanceType = SQWowAPI.IsInInstance()
        if inInstance and instanceType ~= "none" then
            local zone = SQWowAPI.GetRealZoneText()
            if zone and zone ~= "" then
                return {
                    filter = { zone = zone },
                    label  = string.format(L["Instance: %s"], zone),
                }
            end
        end
    end

    if db.window.autoFilterZone then
        local zone = SQWowAPI.GetRealZoneText()
        if zone and zone ~= "" then
            return {
                filter = { zone = zone },
                label  = string.format(L["Zone: %s"], zone),
            }
        end
    end

    return nil
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Returns { zone = "..." } filter table for tabId, or nil (no filter / dismissed).
function SocialQuestWindowFilter:GetActiveFilter(tabId)
    if dismissed[tabId] then return nil end
    local state = computeFilterState()
    return state and state.filter or nil
end

-- Returns the human-readable filter label string for tabId, or nil.
-- Uses the same priority logic as GetActiveFilter via the shared computeFilterState helper.
function SocialQuestWindowFilter:GetFilterLabel(tabId)
    if dismissed[tabId] then return nil end
    local state = computeFilterState()
    return state and state.label or nil
end

-- Marks this tab's filter as dismissed until Reset() is called.
function SocialQuestWindowFilter:Dismiss(tabId)
    dismissed[tabId] = true
end

-- Clears all dismiss state. Called on zone change, window close, or settings toggle.
function SocialQuestWindowFilter:Reset()
    dismissed = {}
end
```

- [ ] **Step 2: Add to SocialQuest.toc**

Open `SocialQuest.toc`. In the `# UI modules` section, add `UI\WindowFilter.lua` after the last tab file and before `UI\Options.lua`:

```
UI\TabUtils.lua
UI\RowFactory.lua
UI\Tabs\MineTab.lua
UI\Tabs\PartyTab.lua
UI\Tabs\SharedTab.lua
UI\WindowFilter.lua
UI\Options.lua
UI\Tooltips.lua
UI\GroupFrame.lua
```

- [ ] **Step 3: Verify**

Code review checklist:
- `SocialQuestWindowFilter` global is declared at the top (accessible to GroupFrame, Options, and tab providers)
- `computeFilterState()` is a file-scope local (not on the module table) — callers outside the module cannot call it directly
- Both `GetActiveFilter` and `GetFilterLabel` delegate to `computeFilterState()` — no duplicated logic
- `dismissed = {}` reassignment in `Reset()` replaces the table entirely; the upvalue reference in all closures that read `dismissed` still resolves to the new empty table because they capture the upvalue, not the table

- [ ] **Step 4: Commit**

```bash
git add UI/WindowFilter.lua SocialQuest.toc
git commit -m "feat: add SocialQuestWindowFilter module and TOC entry"
```

---

## Chunk 2: UI Components

### Task 5: Options panel

**Files:**
- Modify: `UI/Options.lua`

The new `window` group cannot use the generic `toggle()` helper because each toggle's `set` callback must also call `WindowFilter:Reset()` and `GroupFrame:RequestRefresh()`. The two toggles are written out in full inline. The existing `debug` group's `order` changes from `9` to `10`.

- [ ] **Step 1: Change debug group order from 9 to 10**

In `UI/Options.lua`, find the `debug` group declaration:

```lua
            debug = {
                type  = "group",
                name  = L["Debug"],
                order = 9,
```

Change `order = 9` to `order = 10`.

- [ ] **Step 2: Add window group**

In `UI/Options.lua`, inside the `options.args` table, add the `window` group after the `flightPath` group (currently the last entry before `debug`). Insert before the `debug` entry:

```lua
            window = {
                type  = "group",
                name  = L["Social Quest Window"],
                order = 9,
                args  = {
                    autoFilterInstance = {
                        type  = "toggle",
                        name  = L["Auto-filter to current instance"],
                        desc  = L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."],
                        order = 1,
                        get   = function(info) return db.window.autoFilterInstance end,
                        set   = function(info, value)
                            db.window.autoFilterInstance = value
                            SocialQuestWindowFilter:Reset()
                            SocialQuestGroupFrame:RequestRefresh()
                        end,
                    },
                    autoFilterZone = {
                        type  = "toggle",
                        name  = L["Auto-filter to current zone"],
                        desc  = L["Outside of instances, the Party and Shared tabs show only quests for your current zone."],
                        order = 2,
                        get   = function(info) return db.window.autoFilterZone end,
                        set   = function(info, value)
                            db.window.autoFilterZone = value
                            SocialQuestWindowFilter:Reset()
                            SocialQuestGroupFrame:RequestRefresh()
                        end,
                    },
                },
            },

            debug = {
```

Note: `db` is already a local in `SocialQuestOptions:Initialize()` pointing to `SocialQuest.db.profile`. The set callbacks reference `SocialQuestWindowFilter` and `SocialQuestGroupFrame`, which are globals available at callback call time (runtime, after all files are loaded).

- [ ] **Step 3: In-game verification**

Load the addon (`/reload`). Open `/sq config`. Confirm:
- "Social Quest Window" tab appears in the options panel between "Flight Path Discovery" and "Debug"
- Both toggles are present and clickable
- No Lua errors in the chat frame

- [ ] **Step 4: Commit**

```bash
git add UI/Options.lua
git commit -m "feat: add Social Quest Window options group with instance and zone filter toggles"
```

---

### Task 6: RowFactory filter header row

**Files:**
- Modify: `UI/RowFactory.lua`

- [ ] **Step 1: Add AddFilterHeader function**

In `UI/RowFactory.lua`, add the new function after `AddZoneHeader` (currently ending around line 130) and before `AddChainHeader`:

```lua
-- Filter-active indicator row with a [x] dismiss button.
-- Shown at the top of Party and Shared tab content when a zone/instance filter is active.
-- label: string describing the active filter, e.g. "Instance: Hellfire Ramparts"
-- onDismiss: called with no arguments when [x] is clicked
function RowFactory.AddFilterHeader(contentFrame, y, label, onDismiss)
    local C = SocialQuestColors

    local labelStr = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelStr:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -y)
    labelStr:SetSize(CONTENT_WIDTH - 30, ROW_H)
    labelStr:SetJustifyH("LEFT")
    labelStr:SetJustifyV("MIDDLE")
    labelStr:SetText(C.unknown .. label .. C.reset)

    local dismissBtn = CreateFrame("Button", nil, contentFrame)
    dismissBtn:SetSize(22, ROW_H)
    dismissBtn:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -4, -y)
    dismissBtn:SetText("[x]")
    dismissBtn:SetNormalFontObject("GameFontNormalSmall")
    dismissBtn:SetHighlightFontObject("GameFontHighlightSmall")
    if onDismiss then dismissBtn:SetScript("OnClick", onDismiss) end

    return y + ROW_H + 4
end
```

`C.unknown` (`|cFF888888`, grey) gives the label a muted/informational appearance, distinct from zone headers (gold) and quest titles.

- [ ] **Step 2: Verify**

Code review: pattern is identical to `AddZoneHeader` — creates a font string and a button anchored to `contentFrame`, returns `y + ROW_H + 4`. No in-game test needed yet (will be exercised in Task 8/9).

- [ ] **Step 3: Commit**

```bash
git add UI/RowFactory.lua
git commit -m "feat: add RowFactory.AddFilterHeader row type for active filter display"
```

---

### Task 7: MineTab signature update

**Files:**
- Modify: `UI/Tabs/MineTab.lua`

MineTab is not filtered in this version. Both method signatures gain the new parameters for future-compatibility only.

- [ ] **Step 1: Update BuildTree signature**

In `UI/Tabs/MineTab.lua`, change line 20:

```lua
function MineTab:BuildTree()
```

to:

```lua
function MineTab:BuildTree(filterTable)  -- filterTable accepted for API consistency; not applied
```

- [ ] **Step 2: Update Render signature**

Change line 119:

```lua
function MineTab:Render(contentFrame, rowFactory, tabCollapsedZones)
```

to:

```lua
function MineTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
```

Also update the internal `BuildTree` call on line 120 to pass `filterTable`:

```lua
    local tree  = self:BuildTree(filterTable)
```

- [ ] **Step 3: Verify**

Code review: `filterTable` and `tabId` are accepted but never read in MineTab. Lua ignores unused parameters; no runtime effect.

- [ ] **Step 4: Commit**

```bash
git add UI/Tabs/MineTab.lua
git commit -m "feat: update MineTab BuildTree/Render signatures for filter API compatibility"
```

---

### Task 8: PartyTab filtering

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

- [ ] **Step 1: Update BuildTree signature and add filter logic**

Change the `BuildTree` signature (line 142):

```lua
function PartyTab:BuildTree()
```

to:

```lua
function PartyTab:BuildTree(filterTable)
```

Inside `BuildTree`, replace the entire quest loop (lines 162–211) with the following. The only addition is the `filtered` local and the `if not filtered then ... end` wrapper — all existing content is preserved inside it:

```lua
    for questID in pairs(allQuestIDs) do
        local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID)
        local filtered = filterTable and filterTable.zone and zoneName ~= filterTable.zone
        if not filtered then
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
            local ci           = localInfo and localInfo.chainInfo or SocialQuestTabUtils.GetChainInfoForQuestID(questID)
            local localHasIt   = localInfo ~= nil

            local entry = {
                questID        = questID,
                title          = (localInfo and localInfo.title)
                                 or AQL:GetQuestTitle(questID)
                                 or ("Quest " .. questID),
                level          = localInfo and localInfo.level or 0,
                zone           = zoneName,
                isComplete     = localInfo and localInfo.isComplete or false,
                isFailed       = localInfo and localInfo.isFailed   or false,
                isTracked      = false,
                logIndex       = localInfo and localInfo.logIndex,
                suggestedGroup = localInfo and localInfo.suggestedGroup or 0,
                timerSeconds   = localInfo and localInfo.timerSeconds,
                snapshotTime   = localInfo and localInfo.snapshotTime,
                chainInfo      = ci,
                objectives     = localInfo and localInfo.objectives or {},
                players        = buildPlayerRowsForQuest(questID, localHasIt),
            }

            if ci.knownStatus == AQL.ChainStatus.Known and ci.chainID then
                local chainID = ci.chainID
                if not zone.chains[chainID] then
                    zone.chains[chainID] = { title = entry.title, steps = {} }
                end
                if ci.step == 1 then
                    zone.chains[chainID].title = entry.title
                end
                table.insert(zone.chains[chainID].steps, entry)
            else
                table.insert(zone.quests, entry)
            end
        end
    end
```

- [ ] **Step 2: Update Render signature and add filter header**

Change the `Render` signature (line 228):

```lua
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones)
```

to:

```lua
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
```

Inside `Render`, update the `BuildTree` call (line 229):

```lua
    local tree = self:BuildTree()
```

to:

```lua
    local tree = self:BuildTree(filterTable)
```

After `local y = 0` and before the `sortedZones` construction, insert the filter header block:

```lua
    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(tabId)
    if filterLabel then
        y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
            SocialQuestWindowFilter:Dismiss(tabId)
            SocialQuestGroupFrame:Refresh()
        end)
    end
```

- [ ] **Step 3: In-game verification (deferred)**

Will be verified together with SharedTab and GroupFrame in Task 10.

- [ ] **Step 4: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: add zone filter support to PartyTab BuildTree and Render"
```

---

### Task 9: SharedTab filtering

**Files:**
- Modify: `UI/Tabs/SharedTab.lua`

SharedTab's `BuildTree` processes chain groups and standalone quest groups separately. Both paths need a filter guard.

- [ ] **Step 1: Update BuildTree signature**

Change line 19:

```lua
function SharedTab:BuildTree()
```

to:

```lua
function SharedTab:BuildTree(filterTable)
```

- [ ] **Step 2: Add filter guard to chain groups**

Inside `BuildTree`, replace the entire chain group loop (lines 73–175) with the following. The only addition is the `filtered` local and the `if not filtered then ... end` wrapper around everything from `ensureZone` onward — including the `table.sort` at the end, which must remain inside the guard since it operates on data created inside it:

```lua
    -- Process chain groups.
    for chainID, engaged in pairs(chainEngaged) do
        local count = 0
        for _ in pairs(engaged) do count = count + 1 end
        if count >= 2 then
            -- Determine zone: prefer local player's zone; fall back to "Other Quests".
            local zoneName = L["Other Quests"]
            for _, eng in pairs(engaged) do
                if eng.isLocal then
                    local info = AQL:GetQuest(eng.questID)
                    if info and info.zone then zoneName = info.zone; break end
                end
            end
            local filtered = filterTable and filterTable.zone and zoneName ~= filterTable.zone
            if not filtered then
                local zone = ensureZone(zoneName)

                if not zone.chains[chainID] then
                    zone.chains[chainID] = { title = "Chain " .. chainID, steps = {} }
                end

                local addedQuestIDs = {}
                for playerName, eng in pairs(engaged) do
                    if not addedQuestIDs[eng.questID] then
                        addedQuestIDs[eng.questID] = true
                        local localInfo = AQL:GetQuest(eng.questID)
                        local ci = SocialQuestTabUtils.GetChainInfoForQuestID(eng.questID)

                        if localInfo and localInfo.title and ci.step == 1 then
                            zone.chains[chainID].title = localInfo.title
                        elseif localInfo and localInfo.title and
                            zone.chains[chainID].title == "Chain " .. chainID then
                            zone.chains[chainID].title = localInfo.title
                        end

                        local entry = {
                            questID        = eng.questID,
                            title          = (localInfo and localInfo.title)
                                             or AQL:GetQuestTitle(eng.questID)
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
                            chainInfo      = ci,
                            objectives     = localInfo and localInfo.objectives or {},
                            players        = {},
                        }

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
                                        isComplete     = info and info.isComplete or false,
                                        objectives     = SocialQuestTabUtils.BuildLocalObjectives(info or {}),
                                        step           = pEng.step,
                                        chainLength    = pEng.chainLength,
                                        dataProvider   = SocialQuest.DataProviders.SocialQuest,
                                    })
                                else
                                    local playerData = SocialQuestGroupData.PlayerQuests[pName]
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
                                        dataProvider   = playerData and playerData.dataProvider,
                                    })
                                end
                            end
                        end

                        table.insert(zone.chains[chainID].steps, entry)
                    end
                end

                -- Sort steps ascending. Inside the guard: zone.chains[chainID] only exists here.
                table.sort(zone.chains[chainID].steps, function(a, b)
                    local aS = a.chainInfo and a.chainInfo.step or 0
                    local bS = b.chainInfo and b.chainInfo.step or 0
                    return aS < bS
                end)
            end
        end
    end
```

- [ ] **Step 3: Add filter guard to standalone quest groups**

Replace the standalone quest loop (lines 178–234) with the following. The only addition is the `filtered` local and the `if not filtered then ... end` wrapper:

```lua
    -- Process standalone quest groups.
    for questID, engaged in pairs(questEngaged) do
        local count = 0
        for _ in pairs(engaged) do count = count + 1 end
        if count >= 2 then
            local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID)
            local filtered = filterTable and filterTable.zone and zoneName ~= filterTable.zone
            if not filtered then
                local zone      = ensureZone(zoneName)
                local localInfo = AQL:GetQuest(questID)

                local entry = {
                    questID        = questID,
                    title          = (localInfo and localInfo.title)
                                     or AQL:GetQuestTitle(questID)
                                     or ("Quest " .. questID),
                    level          = localInfo and localInfo.level or 0,
                    zone           = zoneName,
                    isComplete     = localInfo and localInfo.isComplete or false,
                    isFailed       = localInfo and localInfo.isFailed   or false,
                    isTracked      = false,
                    logIndex       = localInfo and localInfo.logIndex,
                    suggestedGroup = localInfo and localInfo.suggestedGroup or 0,
                    timerSeconds   = localInfo and localInfo.timerSeconds,
                    snapshotTime   = localInfo and localInfo.snapshotTime,
                    chainInfo      = { knownStatus = AQL.ChainStatus.Unknown },
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
                            isComplete     = localInfo and localInfo.isComplete or false,
                            objectives     = SocialQuestTabUtils.BuildLocalObjectives(localInfo or {}),
                            dataProvider   = SocialQuest.DataProviders.SocialQuest,
                        })
                    else
                        local playerData = SocialQuestGroupData.PlayerQuests[playerName]
                        table.insert(entry.players, {
                            name           = playerName,
                            isMe           = false,
                            hasSocialQuest = playerData and playerData.hasSocialQuest or false,
                            hasCompleted   = false,
                            needsShare     = false,
                            isComplete     = eng.qdata and eng.qdata.isComplete or false,
                            objectives     = SocialQuestTabUtils.BuildRemoteObjectives(eng.qdata or {}, localInfo),
                            dataProvider   = playerData and playerData.dataProvider,
                        })
                    end
                end

                table.insert(zone.quests, entry)
            end
        end
    end
```

- [ ] **Step 4: Update Render signature and add filter header**

Change line 240:

```lua
function SharedTab:Render(contentFrame, rowFactory, tabCollapsedZones)
```

to:

```lua
function SharedTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
```

Update the `BuildTree` call on line 241:

```lua
    local tree = self:BuildTree()
```

to:

```lua
    local tree = self:BuildTree(filterTable)
```

After `local y = 0` and before the `sortedZones` construction, insert the filter header block (same as PartyTab):

```lua
    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(tabId)
    if filterLabel then
        y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
            SocialQuestWindowFilter:Dismiss(tabId)
            SocialQuestGroupFrame:Refresh()
        end)
    end
```

- [ ] **Step 5: Commit**

```bash
git add UI/Tabs/SharedTab.lua
git commit -m "feat: add zone filter support to SharedTab BuildTree and Render"
```

---

## Chunk 3: Integration

### Task 10: GroupFrame integration + OnPlayerEnteringWorld

**Files:**
- Modify: `UI/GroupFrame.lua`
- Modify: `SocialQuest.lua`

- [ ] **Step 1: Pass filterTable and tabId to Render in GroupFrame:Refresh()**

In `UI/GroupFrame.lua`, find the `Refresh()` method. Near the bottom of that method (around line 280), the current render call is:

```lua
    -- Delegate rendering to the tab provider.
    local totalHeight  = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed)
```

Replace with:

```lua
    -- Delegate rendering to the tab provider.
    local filterTable = SocialQuestWindowFilter:GetActiveFilter(activeID)
    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed, filterTable, activeID)
```

`activeID` is already in scope (resolved at the top of `Refresh()`). `SocialQuestWindowFilter` is a global loaded before `GroupFrame.lua` per the TOC order.

- [ ] **Step 2: Add OnHide script to reset filter state**

In `UI/GroupFrame.lua`, inside the `createFrame()` function, add the `OnHide` script before `return f` (currently line 187):

```lua
    f:SetScript("OnHide", function()
        SocialQuestWindowFilter:Reset()
    end)

    return f
```

- [ ] **Step 3: Extend OnPlayerEnteringWorld in SocialQuest.lua**

In `SocialQuest.lua`, find `OnPlayerEnteringWorld` (currently lines 389–392):

```lua
function SocialQuest:OnPlayerEnteringWorld()
    self.zoneTransitionSuppressUntil = SQWowAPI.GetTime() + 3
    self:Debug("Zone", "Zone transition detected — suppressing AQL callbacks for 3 s")
end
```

Replace with:

```lua
function SocialQuest:OnPlayerEnteringWorld()
    self.zoneTransitionSuppressUntil = SQWowAPI.GetTime() + 3
    self:Debug("Zone", "Zone transition detected — suppressing AQL callbacks for 3 s")
    SocialQuestWindowFilter:Reset()
    SocialQuestGroupFrame:RequestRefresh()
end
```

The suppression window is set first (existing behaviour). `Reset()` then clears any per-tab dismiss state. `RequestRefresh()` redraws the window with the new zone's filter applied if the window is open; it is a no-op if the window is closed (guarded by `if not frame or not frame:IsShown() then return end` inside `RequestRefresh`).

- [ ] **Step 4: In-game integration test — instance filter**

Load the addon (`/reload`). Enter a dungeon (e.g. Hellfire Ramparts):
1. Open `/sq` — Party and Shared tabs should show only Hellfire Ramparts quests
2. A grey `"Instance: Hellfire Ramparts [x]"` label appears at the top of Party and Shared tabs
3. Mine tab is unaffected (no filter label, all quests shown)
4. Click `[x]` on the Party tab — filter label disappears, all party quests reappear
5. Click `[x]` on the Shared tab — same
6. Close and reopen the SQ window — filter is reinstated on both tabs (Reset fired on Hide)
7. Verify no Lua errors in chat at any step

- [ ] **Step 5: In-game integration test — zone filter and settings toggle**

Open `/sq config` → Social Quest Window:
1. Enable "Auto-filter to current zone" — Party/Shared tabs immediately reflect zone filter if window is open
2. Disable "Auto-filter to current instance" while inside an instance — tabs immediately show all quests
3. Re-enable instance filter — tabs immediately show only instance quests
4. Dismiss filter with `[x]` — tabs show all quests
5. Toggle instance filter off and on in the options panel — dismiss state is cleared and filter reapplies

- [ ] **Step 6: Version bump**

In `SocialQuest.toc`, increment the version according to the project rule (first feature of the day → bump minor, reset revision). Example: if current is `2.8.2`, set to `2.9.0`.

Update `CLAUDE.md` with a new version history entry describing this feature.

- [ ] **Step 7: Commit**

```bash
git add UI/GroupFrame.lua SocialQuest.lua SocialQuest.toc CLAUDE.md
git commit -m "feat: wire zone/instance filter into GroupFrame and zone transition handler"
```

---

## Reference: Key Data Paths

| What | Where |
|------|-------|
| Filter settings | `SocialQuest.db.profile.window.autoFilterInstance` / `.autoFilterZone` |
| Dismiss state | `dismissed` table in `UI/WindowFilter.lua` (module-local) |
| Active filter | `SocialQuestWindowFilter:GetActiveFilter(tabId)` → `{ zone = "..." }` or nil |
| Tab IDs | Defined in `GroupFrame.lua` `providers` table: `"shared"`, `"mine"`, `"party"` |
| Zone text | `SQWowAPI.GetRealZoneText()` — same value used in filter table and `GetZoneForQuestID` output |
| Instance detection | `SQWowAPI.IsInInstance()` → `inInstance (bool), instanceType (string)`; real instance when `inInstance == true and instanceType ~= "none"` |
