# Search/Filter Bar Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent text search bar to the SocialQuest group window that filters the quest list by title or chain title in real time, and migrate the zone/instance filter label from the scrollable content area into a fixed header strip alongside the search bar.

**Architecture:** A single `searchText` string at `GroupFrame.lua` module scope drives filtering for all tabs. The search EditBox and filter label widget are created once in `createFrame()` and live in a fixed strip between the tab separator and the scroll frame. On each `Refresh()`, GroupFrame assembles a composite `filterTable` (`{ zone, search }`) and passes it to the active tab's `BuildTree`, which applies a case-insensitive substring post-pass. The zone/instance filter label is removed from the tab `Render` methods and `RowFactory`, and is now rendered and managed entirely by `GroupFrame:Refresh()`.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary (Interface 20505), Ace3 (AceLocale-3.0)

> **Note:** This addon has no automated test framework. All testing steps are manual in-game verifications. After each commit, load the addon in WoW, open the SQ window (`/sq`), and confirm no Lua errors appear in chat.

> **Versioning:** The version in `SocialQuest.toc` must be bumped per `CLAUDE.md`. The current version is `2.10.4`. If this is the **first** functionality change on the day you implement it, set `2.11.0`. If other changes were already made that day, increment the revision instead (e.g. `2.10.5`). The most likely value is **`2.11.0`**.

---

## File Map

| File | Change |
|---|---|
| `Locales/enUS.lua` | Add `["Search..."] = true` near WindowFilter keys |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | Add `["Search..."]` translation (11 files) |
| `UI/GroupFrame.lua` | Add `searchText` upvalue; add search bar + filter label to `createFrame()`; update `Refresh()` and `OnHide` |
| `UI/Tabs/MineTab.lua` | Add search text post-pass filter to `BuildTree` |
| `UI/Tabs/PartyTab.lua` | Add search text post-pass filter to `BuildTree`; remove `GetFilterLabel`/`AddFilterHeader` calls from `Render` |
| `UI/Tabs/SharedTab.lua` | Same as PartyTab |
| `UI/RowFactory.lua` | Delete `AddFilterHeader` function |
| `SocialQuest.toc` | Version bump |
| `CLAUDE.md` | Add version history entry |

---

## Chunk 1: Locale Keys + Search Filtering in BuildTree

### Task 1: Add "Search..." locale key to all 12 locale files

**Files:**
- Modify: `Locales/enUS.lua` (after line 251, after the Options/WindowFilter block)
- Modify: `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`, `Locales/esMX.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`, `Locales/koKR.lua`, `Locales/ruRU.lua`, `Locales/jaJP.lua`

- [ ] **Step 1: Add to enUS.lua**

In `Locales/enUS.lua`, after line 251 (the last line of the `-- UI/WindowFilter.lua` section, which ends with `L["Auto-filter to current zone"]` and its description string), add a new comment section for GroupFrame keys:

```lua

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = true
```

`= true` is the standard AceLocale convention for enUS; the key string itself serves as the display value.

- [ ] **Step 2: Add translations to the 11 non-enUS locale files**

In each file, find the equivalent end of the WindowFilter section (ending with the `L["Auto-filter to current zone"]` description string) and append the same new section below it:

```lua

-- UI/GroupFrame.lua — search bar
```

Then add the locale-specific value shown below. Each file ends its WindowFilter block with the `Auto-filter` description key.

**`Locales/deDE.lua`:**
```lua
L["Search..."]                               = "Suchen..."
```

**`Locales/frFR.lua`:**
```lua
L["Search..."]                               = "Rechercher..."
```

**`Locales/esES.lua`:**
```lua
L["Search..."]                               = "Buscar..."
```

**`Locales/esMX.lua`:**
```lua
L["Search..."]                               = "Buscar..."
```

**`Locales/zhCN.lua`:**
```lua
L["Search..."]                               = "搜索..."
```

**`Locales/zhTW.lua`:**
```lua
L["Search..."]                               = "搜尋..."
```

**`Locales/ptBR.lua`:**
```lua
L["Search..."]                               = "Pesquisar..."
```

**`Locales/itIT.lua`:**
```lua
L["Search..."]                               = "Cerca..."
```

**`Locales/koKR.lua`:**
```lua
L["Search..."]                               = "검색..."
```

**`Locales/ruRU.lua`:**
```lua
L["Search..."]                               = "Поиск..."
```

**`Locales/jaJP.lua`:**
```lua
L["Search..."]                               = "検索..."
```

- [ ] **Step 3: Test in WoW**

Load the addon (`/reload`). Open `/sq`. Confirm no "unknown locale key" errors in chat.

- [ ] **Step 4: Commit**

```bash
git add Locales/
git commit -m "feat: add Search... locale key to all 12 locale files"
```

---

### Task 2: Add search text filtering to MineTab:BuildTree

**Files:**
- Modify: `UI/Tabs/MineTab.lua` — `BuildTree` function (lines 20–114)

The filter is a post-pass applied after the tree is fully built. It applies only to `filterTable.search`; `filterTable.zone` continues to be **ignored** in MineTab by design.

- [ ] **Step 1: Add the search post-pass at the end of BuildTree, just before `return tree`**

Replace the closing section of `MineTab:BuildTree`:

```lua
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
```

With:

```lua
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

    -- Search text filter: case-insensitive substring match on quest/chain titles.
    -- filterTable.zone is intentionally not applied in MineTab.
    local searchText = filterTable and filterTable.search
    if searchText then
        local lower = string.lower(searchText)
        local function matches(title)
            return string.find(string.lower(title or ""), lower, 1, true) ~= nil
        end
        for zoneName, zone in pairs(tree.zones) do
            for chainID, chain in pairs(zone.chains) do
                if not matches(chain.title) then
                    local kept = {}
                    for _, step in ipairs(chain.steps) do
                        if matches(step.title) then kept[#kept + 1] = step end
                    end
                    chain.steps = kept
                end
                if #chain.steps == 0 then zone.chains[chainID] = nil end
            end
            local kept = {}
            for _, quest in ipairs(zone.quests) do
                if matches(quest.title) then kept[#kept + 1] = quest end
            end
            zone.quests = kept
            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end

    return tree
end
```

- [ ] **Step 2: Update the function signature comment**

The existing comment on `MineTab:BuildTree` says `-- filterTable accepted for API consistency; not applied`. This is now stale. Update it:

```lua
function MineTab:BuildTree(filterTable)  -- filterTable.search applied; filterTable.zone intentionally ignored
```

- [ ] **Step 3: Test in WoW**

`/reload`. Open `/sq`, Mine tab. No errors. Quest list displays as before (search is not wired yet — filtering will be invisible until Task 6, when Refresh() passes a non-nil filterTable).

- [ ] **Step 4: Commit**

```bash
git add UI/Tabs/MineTab.lua
git commit -m "feat: add search text filter post-pass to MineTab:BuildTree"
```

---

### Task 3: Add search text filtering to PartyTab:BuildTree

**Files:**
- Modify: `UI/Tabs/PartyTab.lua` — `BuildTree` function (lines 142–226)

Same post-pass as MineTab. PartyTab also applies `filterTable.zone` (already exists); both filters are independent.

- [ ] **Step 1: Add the search post-pass at the end of BuildTree, just before `return tree`**

Replace the closing section of `PartyTab:BuildTree`:

```lua
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
```

With:

```lua
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

    -- Search text filter: case-insensitive substring match on quest/chain titles.
    -- Applied independently from the zone filter; both must pass for a quest to appear.
    local searchText = filterTable and filterTable.search
    if searchText then
        local lower = string.lower(searchText)
        local function matches(title)
            return string.find(string.lower(title or ""), lower, 1, true) ~= nil
        end
        for zoneName, zone in pairs(tree.zones) do
            for chainID, chain in pairs(zone.chains) do
                if not matches(chain.title) then
                    local kept = {}
                    for _, step in ipairs(chain.steps) do
                        if matches(step.title) then kept[#kept + 1] = step end
                    end
                    chain.steps = kept
                end
                if #chain.steps == 0 then zone.chains[chainID] = nil end
            end
            local kept = {}
            for _, quest in ipairs(zone.quests) do
                if matches(quest.title) then kept[#kept + 1] = quest end
            end
            zone.quests = kept
            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end

    return tree
end
```

- [ ] **Step 2: Test in WoW**

`/reload`. Open `/sq`, Party tab. No errors. Quest list displays as before. (Filtering is still invisible until Task 6 wires the composite filterTable.)

- [ ] **Step 3: Commit**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: add search text filter post-pass to PartyTab:BuildTree"
```

---

### Task 4: Add search text filtering to SharedTab:BuildTree

**Files:**
- Modify: `UI/Tabs/SharedTab.lua` — `BuildTree` function (lines 19–243)

Identical logic to PartyTab.

- [ ] **Step 1: Add the search post-pass at the end of BuildTree, just before `return tree`**

Replace the closing section of `SharedTab:BuildTree`:

```lua
    return tree
end

-- Renders the Shared tree into contentFrame using RowFactory.
```

With:

```lua
    -- Search text filter: case-insensitive substring match on quest/chain titles.
    -- Applied independently from the zone filter; both must pass for a quest to appear.
    local searchText = filterTable and filterTable.search
    if searchText then
        local lower = string.lower(searchText)
        local function matches(title)
            return string.find(string.lower(title or ""), lower, 1, true) ~= nil
        end
        for zoneName, zone in pairs(tree.zones) do
            for chainID, chain in pairs(zone.chains) do
                if not matches(chain.title) then
                    local kept = {}
                    for _, step in ipairs(chain.steps) do
                        if matches(step.title) then kept[#kept + 1] = step end
                    end
                    chain.steps = kept
                end
                if #chain.steps == 0 then zone.chains[chainID] = nil end
            end
            local kept = {}
            for _, quest in ipairs(zone.quests) do
                if matches(quest.title) then kept[#kept + 1] = quest end
            end
            zone.quests = kept
            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end

    return tree
end

-- Renders the Shared tree into contentFrame using RowFactory.
```

- [ ] **Step 2: Commit**

```bash
git add UI/Tabs/SharedTab.lua
git commit -m "feat: add search text filter post-pass to SharedTab:BuildTree"
```

---

## Chunk 2: GroupFrame Widgets + Wiring + Cleanup

### Task 5: Add search bar and filter label widgets to GroupFrame.createFrame()

**Files:**
- Modify: `UI/GroupFrame.lua` lines 1–17 (add `searchText` upvalue)
- Modify: `UI/GroupFrame.lua` lines 152–200 (`createFrame`: insert widgets, update scroll anchor, update `OnHide`)

- [ ] **Step 1: Add `searchText` module-level upvalue**

In `GroupFrame.lua`, find the block of module-level locals (lines 8–17):

```lua
local frame          = nil
local refreshPending = false
local urlPopup       = nil
local lastRenderedTab     = nil
local scrollRestoreSeq    = 0
local leavingWorld        = false
```

Add `searchText` to this block:

```lua
local frame          = nil
local refreshPending = false
local urlPopup       = nil
local lastRenderedTab     = nil
local scrollRestoreSeq    = 0
local leavingWorld        = false
local searchText          = ""
```

- [ ] **Step 2: Insert search bar and filter label widget creation in createFrame()**

In `createFrame()`, find this block (lines ~160–178):

```lua
    local sepFrame = CreateFrame("Frame", nil, f)
    sepFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",   6, SEP_Y)
    sepFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, SEP_Y)
    sepFrame:SetHeight(2)
    local sepTex = sepFrame:CreateTexture(nil, "ARTWORK")
    sepTex:SetAllPoints(sepFrame)
    sepTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    sepTex:SetVertexColor(0.4, 0.35, 0.25, 1)

    -- Scroll area.
    ...
    f.scrollFrame = CreateFrame("ScrollFrame", "SocialQuestGroupScrollFrame", f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     10, SCROLL_TOP)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
```

Replace with:

```lua
    local sepFrame = CreateFrame("Frame", nil, f)
    sepFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",   6, SEP_Y)
    sepFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, SEP_Y)
    sepFrame:SetHeight(2)
    local sepTex = sepFrame:CreateTexture(nil, "ARTWORK")
    sepTex:SetAllPoints(sepFrame)
    sepTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    sepTex:SetVertexColor(0.4, 0.35, 0.25, 1)

    -- Search bar (persistent; lives on f, survives every Refresh()).
    local SEARCH_H = 24
    local searchBarFrame = CreateFrame("Frame", nil, f)
    searchBarFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",   10, SCROLL_TOP)
    searchBarFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, SCROLL_TOP)
    searchBarFrame:SetHeight(SEARCH_H)

    local searchBg = searchBarFrame:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints(searchBarFrame)
    searchBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    searchBg:SetVertexColor(0, 0, 0, 0.5)

    local searchBorder = CreateFrame("Frame", nil, searchBarFrame, "BackdropTemplate")
    searchBorder:SetAllPoints(searchBarFrame)
    searchBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    searchBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local searchBox = CreateFrame("EditBox", nil, searchBarFrame)
    searchBox:SetPoint("LEFT",  searchBarFrame, "LEFT",   6, 0)
    searchBox:SetPoint("RIGHT", searchBarFrame, "RIGHT", -26, 0)
    searchBox:SetHeight(SEARCH_H)
    searchBox:SetFontObject("GameFontNormalSmall")
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(64)

    local searchPlaceholder = searchBarFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 2, 0)
    searchPlaceholder:SetText(L["Search..."])

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        searchPlaceholder:SetShown(text == "")
        searchText = text
        SocialQuestGroupFrame:RequestRefresh()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    local searchClearBtn = CreateFrame("Button", nil, searchBarFrame)
    searchClearBtn:SetSize(20, SEARCH_H)
    searchClearBtn:SetPoint("RIGHT", searchBarFrame, "RIGHT", -2, 0)
    searchClearBtn:SetText("x")
    searchClearBtn:SetNormalFontObject("GameFontNormalSmall")
    searchClearBtn:SetHighlightFontObject("GameFontHighlightSmall")
    searchClearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    searchClearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Clear search"], 1, 1, 1)
        GameTooltip:Show()
    end)
    searchClearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.searchBarFrame   = searchBarFrame
    f.searchBox        = searchBox
    f.searchPlaceholder = searchPlaceholder

    -- Filter label (zone/instance filter; shown only when a filter is active).
    -- Positioned below the search bar; shown/hidden and re-wired on every Refresh().
    local FILTER_LABEL_H = 18    -- matches ROW_H in RowFactory (18px)
    local filterLabelFrame = CreateFrame("Frame", nil, f)
    filterLabelFrame:SetPoint("TOPLEFT",  searchBarFrame, "BOTTOMLEFT",  0, -2)
    filterLabelFrame:SetPoint("TOPRIGHT", searchBarFrame, "BOTTOMRIGHT", 0, -2)
    filterLabelFrame:SetHeight(FILTER_LABEL_H)
    filterLabelFrame:Hide()

    local filterLabelText = filterLabelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabelText:SetPoint("TOPLEFT",     filterLabelFrame, "TOPLEFT",     4,  0)
    filterLabelText:SetPoint("BOTTOMRIGHT", filterLabelFrame, "BOTTOMRIGHT", -28, 0)
    filterLabelText:SetJustifyH("LEFT")
    filterLabelText:SetJustifyV("MIDDLE")

    local filterDismissBtn = CreateFrame("Button", nil, filterLabelFrame)
    filterDismissBtn:SetSize(22, FILTER_LABEL_H)
    filterDismissBtn:SetPoint("TOPRIGHT", filterLabelFrame, "TOPRIGHT", -4, 0)
    filterDismissBtn:SetText("[x]")
    filterDismissBtn:SetNormalFontObject("GameFontNormalSmall")
    filterDismissBtn:SetHighlightFontObject("GameFontHighlightSmall")
    filterDismissBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Click to dismiss the active filter for this tab."], 1, 1, 1)
        GameTooltip:Show()
    end)
    filterDismissBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- OnClick is assigned in Refresh() so it captures the current activeID.

    f.filterLabelFrame  = filterLabelFrame
    f.filterLabelText   = filterLabelText
    f.filterDismissBtn  = filterDismissBtn

    -- Scroll area.
    -- TOPLEFT is anchored to searchBarFrame initially; Refresh() re-anchors dynamically
    -- depending on whether the filter label is shown.
    f.scrollFrame = CreateFrame("ScrollFrame", "SocialQuestGroupScrollFrame", f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT",     searchBarFrame, "BOTTOMLEFT",  0, -4)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f,              "BOTTOMRIGHT", -28, 10)
```

> **Note:** You also need to add `L["Clear search"] = true` to `Locales/enUS.lua` and an appropriate translation for each of the 11 non-enUS locale files alongside the `L["Search..."]` key you added in Task 1.

- [ ] **Step 3: Update OnHide to clear search on user-initiated close**

Find the `OnHide` handler in `createFrame()`:

```lua
    f:SetScript("OnHide", function()
        SocialQuestWindowFilter:Reset()
        -- Save closed state for user-initiated hides (X button, Escape).
        -- Skip during loading-screen transitions: CloseAllWindows() hides us then, but
        -- OnLeavingWorld already snapshotted the true open state before it happened.
        if not leavingWorld then
            SocialQuest.db.char.frameState.windowOpen = false
        end
    end)
```

Replace with:

```lua
    f:SetScript("OnHide", function()
        SocialQuestWindowFilter:Reset()
        -- Save closed state for user-initiated hides (X button, Escape).
        -- Skip during loading-screen transitions: CloseAllWindows() hides us then, but
        -- OnLeavingWorld already snapshotted the true open state before it happened.
        if not leavingWorld then
            SocialQuest.db.char.frameState.windowOpen = false
            -- Clear search text on user close. Preserved across loading-screen transitions
            -- (leavingWorld == true) so the filter survives hearths and instance entry.
            searchText = ""
            if f.searchBox then f.searchBox:SetText("") end
        end
    end)
```

- [ ] **Step 4: Update RestoreAfterTransition() to repopulate the EditBox**

The spec states: "Window reopened after loading screen → EditBox repopulated from `searchText`". The existing `RestoreAfterTransition()` only calls `frame:Show()` + `self:Refresh()` — it does not push `searchText` back into the EditBox widget.

Find `RestoreAfterTransition()` in `GroupFrame.lua`:

```lua
function SocialQuestGroupFrame:RestoreAfterTransition()
    leavingWorld = false
    if SocialQuest.db.char.frameState.windowOpen then
        if not frame then frame = createFrame() end
        frame:Show()
        self:Refresh()
        frame:Raise()
    end
end
```

Replace with:

```lua
function SocialQuestGroupFrame:RestoreAfterTransition()
    leavingWorld = false
    if SocialQuest.db.char.frameState.windowOpen then
        if not frame then frame = createFrame() end
        -- Repopulate the search EditBox from the preserved upvalue.
        -- OnTextChanged fires on SetText(), which updates the placeholder and calls
        -- RequestRefresh() — the subsequent Refresh() below is the effective rebuild.
        if frame.searchBox and searchText ~= "" then
            frame.searchBox:SetText(searchText)
        end
        frame:Show()
        self:Refresh()
        frame:Raise()
    end
end
```

- [ ] **Step 5: Add "Clear search" locale key**

In `Locales/enUS.lua`, add next to `L["Search..."]` (same `-- UI/GroupFrame.lua — search bar` section):

```lua
L["Clear search"]                            = true
```

Add translations to the 11 non-enUS locale files:

| File | Translation |
|---|---|
| deDE | `"Suche leeren"` |
| frFR | `"Effacer la recherche"` |
| esES / esMX | `"Borrar búsqueda"` |
| zhCN | `"清除搜索"` |
| zhTW | `"清除搜尋"` |
| ptBR | `"Limpar pesquisa"` |
| itIT | `"Cancella ricerca"` |
| koKR | `"검색 초기화"` |
| ruRU | `"Очистить поиск"` |
| jaJP | `"検索をクリア"` |

- [ ] **Step 6: Test in WoW**

`/reload`. Open `/sq`. Confirm:
- Search bar is visible below the tab separator.
- Typing in the search bar does not yet filter (Refresh() wiring is next task), but no Lua errors appear.
- The [x] button is visible; clicking it clears the text.
- Closing the window and reopening shows an empty search box.

- [ ] **Step 7: Commit**

```bash
git add UI/GroupFrame.lua Locales/
git commit -m "feat: add search bar and filter label widgets to GroupFrame.createFrame()"
```

---

### Task 6: Wire up Refresh() — filterTable assembly, filter label management, scroll anchors

**Files:**
- Modify: `UI/GroupFrame.lua` — `Refresh()` method (lines 236–336)

- [ ] **Step 1: Replace filterTable assembly and add filter label + scroll anchor logic**

In `Refresh()`, find this block (near line 292):

```lua
    -- Delegate rendering to the tab provider.
    local filterTable = SocialQuestWindowFilter:GetActiveFilter(activeID)
    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed, filterTable, activeID)
```

Replace with:

```lua
    -- Delegate rendering to the tab provider.
    -- Assemble composite filterTable: zone filter (from WindowFilter) + search text.
    -- The existing GetActiveFilter line is fully replaced by this block.
    local zoneFilter   = SocialQuestWindowFilter:GetActiveFilter(activeID)
    local filterTable  = nil
    if zoneFilter or (searchText ~= "") then
        filterTable = {
            zone   = zoneFilter and zoneFilter.zone or nil,
            search = searchText ~= "" and searchText or nil,
        }
    end

    -- Update filter label in fixed header.
    -- GetFilterLabel is called separately (same computeFilterState() path as GetActiveFilter).
    -- The dismiss button OnClick is reassigned here so it always captures the current activeID.
    -- Note: dismiss now calls RequestRefresh() (deferred one frame) instead of Refresh()
    -- directly — intentional, consistent with the rest of the debounce pattern.
    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(activeID)
    if filterLabel then
        frame.filterLabelText:SetText(filterLabel)
        frame.filterLabelFrame:Show()
        frame.filterDismissBtn:SetScript("OnClick", function()
            SocialQuestWindowFilter:Dismiss(activeID)
            SocialQuestGroupFrame:RequestRefresh()
        end)
    else
        frame.filterLabelFrame:Hide()
    end

    -- Re-anchor scroll frame: TOPLEFT moves dynamically based on filter label visibility.
    -- Both points are always set explicitly to prevent width collapsing.
    frame.scrollFrame:ClearAllPoints()
    if filterLabel then
        frame.scrollFrame:SetPoint("TOPLEFT",  frame.filterLabelFrame, "BOTTOMLEFT",  0, -4)
    else
        frame.scrollFrame:SetPoint("TOPLEFT",  frame.searchBarFrame,   "BOTTOMLEFT",  0, -4)
    end
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 10)

    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed, filterTable, activeID)
```

- [ ] **Step 2: Test in WoW**

`/reload`. Open `/sq`. Confirm:

1. **Search filtering works:** Type "gnoll" in the search bar — only quests matching "gnoll" (title or chain title) appear. Clear the box — all quests return.
2. **Cross-tab:** Type "hog", switch between Party/Shared/Mine — each tab filters by "hog".
3. **Zone filter label position:** Enter a dungeon (or trigger an overland zone filter). The filter label appears below the search bar, above the quest list. Dismiss it — the quest list expands to fill the space; search text is unchanged.
4. **Both filters active:** With a zone filter active, type a search term — only quests matching both the zone AND the search text appear.
5. **Empty results:** Type a string that matches nothing — tabs show an empty list (no Lua errors).
6. **Close/reopen:** Type a search, close the window, reopen — search box is empty.
7. **Loading screen:** With a search active, hearth or enter an instance — search text is preserved when the window reopens.

- [ ] **Step 3: Commit**

```bash
git add UI/GroupFrame.lua
git commit -m "feat: wire Refresh() — composite filterTable, filter label header, scroll anchors"
```

---

### Task 7: Remove AddFilterHeader from tab Render methods and RowFactory

**Files:**
- Modify: `UI/Tabs/PartyTab.lua` — `Render` method (remove `GetFilterLabel` + `AddFilterHeader` calls)
- Modify: `UI/Tabs/SharedTab.lua` — `Render` method (same)
- Modify: `UI/RowFactory.lua` — delete `AddFilterHeader` function (lines 158–185)

GroupFrame now owns the filter label in the fixed header. Removing these calls from the tabs eliminates duplicate rendering.

- [ ] **Step 1: Remove from PartyTab:Render**

In `UI/Tabs/PartyTab.lua`, find and delete this block in `Render()`:

```lua
    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(tabId)
    if filterLabel then
        y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
            SocialQuestWindowFilter:Dismiss(tabId)
            SocialQuestGroupFrame:Refresh()
        end)
    end
```

- [ ] **Step 2: Remove from SharedTab:Render**

In `UI/Tabs/SharedTab.lua`, delete the same pattern:

```lua
    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(tabId)
    if filterLabel then
        y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
            SocialQuestWindowFilter:Dismiss(tabId)
            SocialQuestGroupFrame:Refresh()
        end)
    end
```

- [ ] **Step 3: Delete AddFilterHeader from RowFactory**

In `UI/RowFactory.lua`, delete the entire `AddFilterHeader` function (lines 158–185):

```lua
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
    dismissBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Click to dismiss the active filter for this tab."], 1, 1, 1)
        GameTooltip:Show()
    end)
    dismissBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return y + ROW_H + 4
end
```

- [ ] **Step 4: Test in WoW**

`/reload`. Open `/sq`. Confirm:

1. Zone/instance filter label still appears correctly in the fixed header (not duplicated in content).
2. Dismissing the filter label works.
3. Switching between Party, Shared, Mine tabs shows/hides the filter label correctly for each tab.
4. Search filtering still works.
5. No Lua errors.

- [ ] **Step 5: Commit**

```bash
git add UI/Tabs/PartyTab.lua UI/Tabs/SharedTab.lua UI/RowFactory.lua
git commit -m "refactor: move filter label to GroupFrame header; remove AddFilterHeader from tabs and RowFactory"
```

---

### Task 8: Version bump and CLAUDE.md

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Check for same-day commits, then bump version in SocialQuest.toc**

First, check whether any functionality commits were made earlier today:

```bash
git log --since="midnight" --oneline
```

Per the versioning rule in `CLAUDE.md`:
- If **no** prior commits today (or all prior commits are chore/refactor only): use `2.11.0` (minor++ revision=0)
- If **yes** functionality commits already landed today: use `2.10.5` (revision++)

Most likely value: **`2.11.0`**

Change:
```
## Version: 2.10.4
```
To the version determined above (most likely):
```
## Version: 2.11.0
```

- [ ] **Step 2: Add version history entry to CLAUDE.md**

Add a new entry at the top of the Version History section:

```markdown
### Version 2.11.0 (March 2026 — FilterTextbox branch)
- Search bar: a persistent search box appears in a fixed header strip below the tab
  separator, above the scrollable quest list. Typing filters all three tabs by quest
  title or chain title (case-insensitive substring match). The search text is shared
  across tabs; switching tabs re-filters against the same text. Cleared on user-initiated
  window close; preserved across loading screen transitions (`leavingWorld` guard).
- Filter label migration: the zone/instance filter label is moved from the scrollable
  content area (RowFactory.AddFilterHeader) into the same fixed header strip below the
  search bar. GroupFrame:Refresh() now manages the label visibility and the dismiss
  button directly. RowFactory.AddFilterHeader removed.
```

- [ ] **Step 3: Commit**

```bash
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump version to 2.11.0; update CLAUDE.md for search bar feature"
```

---

## Done

Plan complete and saved to `docs/superpowers/plans/2026-03-26-search-filter-bar.md`. Ready to execute?
