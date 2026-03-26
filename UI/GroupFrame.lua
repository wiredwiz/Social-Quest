-- UI/GroupFrame.lua
-- Group quest window. Opened via /sq or minimap button.
-- Tab rendering is delegated to MineTab, PartyTab, SharedTab providers.
-- Zone collapse state, active tab, and scroll positions are persisted via AceDB char.frameState.

SocialQuestGroupFrame = {}

local frame          = nil
local refreshPending = false
local urlPopup       = nil
local lastRenderedTab     = nil  -- set to activeID after each render; nil on first run / reload
local scrollRestoreSeq    = 0    -- incremented each Refresh(); deferred scroll callback checks for staleness
local leavingWorld        = false -- true while a loading-screen transition is in progress;
                                  -- prevents OnHide from clearing the persisted open state
local searchText          = ""   -- current search bar text; shared across all tabs
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI
local SQWowUI  = SocialQuestWowUI

-- Ordered tab providers. The id must match the collapsedZones subtable key.
-- MineTab/PartyTab/SharedTab are loaded before GroupFrame per TOC order, so
-- the globals exist here and can be assigned directly.
-- Tab display order: Shared | Mine | Party
local providers = {
    { id = "shared", module = SharedTab, tab = nil, offsetX = 18  },
    { id = "mine",   module = MineTab,   tab = nil, offsetX = 138 },
    { id = "party",  module = PartyTab,  tab = nil, offsetX = 258 },
}

------------------------------------------------------------------------
-- Wowhead URL popup
------------------------------------------------------------------------

local function createUrlPopup()
    local p = CreateFrame("Frame", "SocialQuestWowheadPopup", UIParent,
                          "BasicFrameTemplate")
    p:SetSize(340, 100)
    p:SetPoint("CENTER")
    p:SetFrameStrata("DIALOG")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", function(self) self:StartMoving(); self:Raise() end)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:Hide()

    p.TitleText:SetText(L["Quest URL (Ctrl+C to copy)"])

    local eb = CreateFrame("EditBox", nil, p)
    eb:SetSize(300, 20)
    eb:SetPoint("CENTER", p, "CENTER", 0, -8)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetScript("OnEscapePressed", function() p:Hide() end)

    local ebBg = CreateFrame("Frame", nil, p, "BackdropTemplate")
    ebBg:SetPoint("TOPLEFT",     eb, "TOPLEFT",     -3,  3)
    ebBg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT",  3, -3)
    ebBg:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ebBg:SetBackdropColor(0, 0, 0, 0.6)
    ebBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    ebBg:SetFrameLevel(eb:GetFrameLevel() - 1)

    p.editBox = eb

    -- Register so pressing Escape closes this popup (same pattern as main frame).
    tinsert(UISpecialFrames, "SocialQuestWowheadPopup")

    return p
end

-- Called by RowFactory when the user clicks the [?] link button on a quest row.
-- Sets the URL synchronously before Show() so the edit box is never blank.
function SocialQuestGroupFrame.ShowWowheadUrl(questID)
    if not urlPopup then
        urlPopup = createUrlPopup()
    end
    local url = SocialQuestTabUtils.WowheadUrl(questID)
    urlPopup.editBox:SetText(url)
    urlPopup:Show()
    urlPopup.editBox:SetFocus()
    urlPopup.editBox:HighlightText()
end

------------------------------------------------------------------------
-- Frame construction
------------------------------------------------------------------------

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

    f.TitleText:SetText(L["SocialQuest — Group Quests"])

    -- Tab buttons.
    local function makeTab(id, label, offsetX)
        local tab = CreateFrame("Button", "SocialQuestTab_" .. id, f, "TabButtonTemplate")
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", offsetX, -24)
        tab:SetText(label)
        tab:SetScript("OnClick", function()
            -- Save the outgoing tab's scroll position before activeTab is overwritten.
            -- frame is the module-level upvalue (not the local f); it is non-nil by the
            -- time any click fires.
            local outgoingID = SocialQuest.db.char.frameState.activeTab or "shared"
            SocialQuest.db.char.frameState.tabScrollPositions[outgoingID] = frame.scrollFrame:GetVerticalScroll()
            SocialQuest.db.char.frameState.tabContentHeights[outgoingID]  = (frame.content and frame.content:GetHeight()) or 0
            SocialQuest.db.char.frameState.activeTab = id
            SocialQuestGroupFrame:Refresh()
        end)
        return tab
    end

    for _, p in ipairs(providers) do
        p.tab = makeTab(p.id, p.module:GetLabel(), p.offsetX)
        SQWowUI.TabResize(p.tab, 0, 120, 120)
        p.tab:SetFrameStrata("HIGH")
        p.tab:SetScript("OnMouseDown", function() f:Raise() end)
    end

    -- Separator: a child Frame created AFTER the tab buttons so it draws on top
    -- of any tab art that bleeds below the button frame.  GetHeight() reads the
    -- real TabButtonTemplate height so the separator sits exactly at tab bottom.
    local TAB_TOP    = -24
    local tabH       = providers[1].tab:GetHeight()
    local SEP_Y      = TAB_TOP - tabH      -- y of separator top edge
    local SCROLL_TOP = SEP_Y - 4           -- 4 px gap below separator

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

    f.searchBarFrame    = searchBarFrame
    f.searchBox         = searchBox
    f.searchPlaceholder = searchPlaceholder

    -- Expand/collapse all row: persistent strip immediately below the search bar.
    -- [+] expand all          [-] collapse all
    -- Handlers are re-wired on every Refresh() to target the current active tab.
    local EC_H = 18   -- matches ROW_H in RowFactory
    local expandCollapseFrame = CreateFrame("Frame", nil, f)
    expandCollapseFrame:SetPoint("TOPLEFT",  searchBarFrame, "BOTTOMLEFT",  0, -2)
    expandCollapseFrame:SetPoint("TOPRIGHT", searchBarFrame, "BOTTOMRIGHT", 0, -2)
    expandCollapseFrame:SetHeight(EC_H)

    local expandAllBtn = CreateFrame("Button", nil, expandCollapseFrame)
    expandAllBtn:SetSize(22, EC_H)
    expandAllBtn:SetPoint("TOPLEFT", expandCollapseFrame, "TOPLEFT", 0, 0)
    expandAllBtn:SetText("[+]")
    expandAllBtn:SetNormalFontObject("GameFontNormalSmall")
    expandAllBtn:SetHighlightFontObject("GameFontHighlightSmall")
    expandAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["expand all"], 1, 1, 1)
        GameTooltip:Show()
    end)
    expandAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local expandLabel = expandCollapseFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandLabel:SetPoint("TOPLEFT", expandCollapseFrame, "TOPLEFT",  24, 0)
    expandLabel:SetPoint("RIGHT",   expandCollapseFrame, "CENTER",    0, 0)
    expandLabel:SetHeight(EC_H)
    expandLabel:SetJustifyH("LEFT")
    expandLabel:SetJustifyV("MIDDLE")
    expandLabel:SetText(L["expand all"])

    local collapseAllBtn = CreateFrame("Button", nil, expandCollapseFrame)
    collapseAllBtn:SetSize(22, EC_H)
    collapseAllBtn:SetPoint("LEFT", expandCollapseFrame, "CENTER", 0, 0)
    collapseAllBtn:SetText("[-]")
    collapseAllBtn:SetNormalFontObject("GameFontNormalSmall")
    collapseAllBtn:SetHighlightFontObject("GameFontHighlightSmall")
    collapseAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["collapse all"], 1, 1, 1)
        GameTooltip:Show()
    end)
    collapseAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local collapseLabel = expandCollapseFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseLabel:SetPoint("TOPLEFT", collapseAllBtn, "TOPRIGHT", 2,  0)
    collapseLabel:SetPoint("RIGHT",   expandCollapseFrame, "RIGHT", 0, 0)
    collapseLabel:SetHeight(EC_H)
    collapseLabel:SetJustifyH("LEFT")
    collapseLabel:SetJustifyV("MIDDLE")
    collapseLabel:SetText(L["collapse all"])

    f.expandCollapseFrame = expandCollapseFrame
    f.expandAllBtn        = expandAllBtn
    f.collapseAllBtn      = collapseAllBtn

    -- Filter label (zone/instance filter; shown only when a filter is active).
    -- Positioned below the expand/collapse row; shown/hidden and re-wired on every Refresh().
    local FILTER_LABEL_H = 18    -- matches ROW_H in RowFactory (18px)
    local filterLabelFrame = CreateFrame("Frame", nil, f)
    filterLabelFrame:SetPoint("TOPLEFT",  expandCollapseFrame, "BOTTOMLEFT",  0, -2)
    filterLabelFrame:SetPoint("TOPRIGHT", expandCollapseFrame, "BOTTOMRIGHT", 0, -2)
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
    -- Named so that UIPanelScrollFrameTemplate helper functions
    -- (ScrollFrame_OnScrollRangeChanged / UIPanelScrollFrame_OnVerticalScroll)
    -- can locate the scrollbar child via _G[name.."ScrollBar"].
    -- Without a name those functions silently no-op, leaving the scrollbar and
    -- scroll position desynced and causing WoW to fire deferred reconciliation
    -- callbacks that override SetVerticalScroll calls.
    -- TOPLEFT initially anchored to expandCollapseFrame; Refresh() will ClearAllPoints and
    -- re-anchor dynamically based on filter label visibility (wired in the Refresh step).
    f.scrollFrame = CreateFrame("ScrollFrame", "SocialQuestGroupScrollFrame", f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT",     expandCollapseFrame, "BOTTOMLEFT",  0, -4)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f,              "BOTTOMRIGHT", -28, 10)

    local initContentW = math.floor(f:GetWidth() - 40)
    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(initContentW, 1)
    f.scrollFrame:SetScrollChild(f.content)

    -- Register with UISpecialFrames so pressing Escape closes this window,
    -- matching standard WoW window behaviour. Requires the frame's global name.
    tinsert(UISpecialFrames, "SocialQuestGroupFramePanel")

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
        -- Rebuild the quest cache on every open so IsQuestWatched state is
        -- current.  The initial PLAYER_LOGIN rebuild fires before watch state
        -- is fully set up, causing isTracked to be stale on first open.
        if SocialQuest.AQL and SocialQuest.AQL.QuestCache then
            SocialQuest.AQL.QuestCache:Rebuild()
        end
        self:Refresh()
        frame:Raise()
    end
end

-- Batches refreshes: at most one redraw per frame.
function SocialQuestGroupFrame:RequestRefresh()
    if not frame or not frame:IsShown() then return end
    if refreshPending then return end
    refreshPending = true
    SQWowAPI.TimerAfter(0, function()
        refreshPending = false
        SocialQuestGroupFrame:Refresh()
    end)
end

function SocialQuestGroupFrame:Refresh()
    if not frame then return end

    -- Resolve activeID early so the scroll save below can reference it before
    -- SetScrollChild() is called (SetScrollChild may clamp GetVerticalScroll to 0).
    local activeID = SocialQuest.db.char.frameState.activeTab or "shared"

    -- Save scroll position for same-tab refreshes BEFORE SetScrollChild can clamp it.
    -- Tab-switch paths save the outgoing tab's position in the click handler instead.
    if activeID == lastRenderedTab then
        SocialQuest.db.char.frameState.tabScrollPositions[activeID] = frame.scrollFrame:GetVerticalScroll()
        SocialQuest.db.char.frameState.tabContentHeights[activeID]  = (frame.content and frame.content:GetHeight()) or 0
    end

    -- Recreate content child (GetChildren does not return FontStrings; hiding is
    -- the only clean way to discard old rows without leaking them).
    local contentW = math.floor(frame:GetWidth() - 40)
    RowFactory.SetContentWidth(contentW)
    if frame.content then frame.content:Hide() end
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(contentW, 1)
    frame.scrollFrame:SetScrollChild(frame.content)

    -- Find active provider.
    local activeProvider
    for _, p in ipairs(providers) do
        if p.id == activeID then
            activeProvider = p
            break
        end
    end
    if not activeProvider or not activeProvider.module then return end

    -- Capture saved scroll data before potentially updating lastRenderedTab.
    local savedScroll  = SocialQuest.db.char.frameState.tabScrollPositions[activeID] or 0
    local savedHeight  = SocialQuest.db.char.frameState.tabContentHeights[activeID]  or 0
    lastRenderedTab = activeID

    -- Highlight active tab; deselect others.
    -- SQWowUI.SelectTab disables the button (standard WoW: can't re-click active tab).
    -- SQWowUI.DeselectTab re-enables inactive tabs.
    for _, p in ipairs(providers) do
        if p.tab then
            if p.id == activeID then
                SQWowUI.SelectTab(p.tab)
            else
                SQWowUI.DeselectTab(p.tab)
            end
        end
    end

    -- Per-tab collapsed zones subtable.
    local collapsedZones = SocialQuest.db.char.frameState.collapsedZones
    local tabCollapsed   = collapsedZones[activeID] or {}

    -- Delegate rendering to the tab provider.
    -- Assemble composite filterTable: zone filter (from WindowFilter) + search text.
    -- The existing GetActiveFilter line is fully replaced by this block.
    local zoneFilter  = SocialQuestWindowFilter:GetActiveFilter(activeID)
    local filterTable = nil
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

    -- Wire expand/collapse all buttons in the fixed header.
    -- Re-wired on every Refresh() so handlers always target the current tab,
    -- matching the same pattern used for filterDismissBtn.
    if frame.expandAllBtn then
        local capturedActiveID = activeID
        frame.expandAllBtn:SetScript("OnClick", function()
            SocialQuestGroupFrame:ExpandAll(capturedActiveID)
        end)
    end
    if frame.collapseAllBtn then
        local capturedActiveID = activeID
        local capturedProvider = activeProvider
        local capturedFilter   = filterTable
        frame.collapseAllBtn:SetScript("OnClick", function()
            local tree  = capturedProvider.module:BuildTree(capturedFilter)
            local names = {}
            for _, zone in pairs(tree.zones) do names[#names + 1] = zone.name end
            SocialQuestGroupFrame:CollapseAll(capturedActiveID, names)
        end)
    end

    -- Re-anchor scroll frame: TOPLEFT moves dynamically based on filter label visibility.
    -- Both points are always set explicitly to prevent width collapsing.
    frame.scrollFrame:ClearAllPoints()
    if filterLabel then
        frame.scrollFrame:SetPoint("TOPLEFT",  frame.filterLabelFrame,     "BOTTOMLEFT",  0, -4)
    else
        frame.scrollFrame:SetPoint("TOPLEFT",  frame.expandCollapseFrame,  "BOTTOMLEFT",  0, -4)
    end
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 10)

    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed, filterTable, activeID)
    local effectiveH   = math.max(totalHeight, 10)
    frame.content:SetHeight(effectiveH)

    -- Determine scroll to restore.
    -- If user was at the bottom when the scroll was saved, track the new bottom
    -- (handles content growth from GroupData sync while on another tab).
    -- Otherwise restore the absolute pixel offset.
    -- savedHeight > visibleH is load-bearing: without it, the first render
    -- (savedHeight == 0, savedMax == 0) would satisfy savedScroll >= savedMax - 1
    -- (0 >= -1) and incorrectly jump to the "track new bottom" path.
    local visibleH    = frame.scrollFrame:GetHeight()
    local savedMax    = math.max(0, savedHeight - visibleH)
    local scrollToRestore
    if savedHeight > visibleH and savedScroll >= savedMax - 1 then
        scrollToRestore = math.max(0, effectiveH - visibleH)
    else
        scrollToRestore = savedScroll
    end

    -- Apply the scroll immediately so the current frame renders correctly,
    -- then also apply it deferred (next frame) to survive any overrides fired
    -- by UIPanelScrollFrameTemplate callbacks (OnScrollRangeChanged / scrollbar
    -- OnValueChanged) that react to SetScrollChild/SetHeight above.
    -- The deferred call goes through the scrollbar (SetValue) rather than
    -- SetVerticalScroll directly: scrollBar:SetValue fires OnValueChanged →
    -- UIPanelScrollFrame_OnVerticalScroll → SetVerticalScroll, which keeps
    -- the scrollbar handle in sync with the content position.
    -- The sequence guard discards stale deferred calls when tabs switch rapidly.
    frame.scrollFrame:SetVerticalScroll(scrollToRestore)
    scrollRestoreSeq = scrollRestoreSeq + 1
    local seq = scrollRestoreSeq
    local scrollVal = scrollToRestore
    SQWowAPI.TimerAfter(0, function()
        if frame and frame:IsShown() and scrollRestoreSeq == seq then
            local scrollBar = _G["SocialQuestGroupScrollFrameScrollBar"]
            if scrollBar then
                scrollBar:SetValue(scrollVal)
            else
                frame.scrollFrame:SetVerticalScroll(scrollVal)
            end
        end
    end)
end

-- Expand all zones in the given tab and redraw.
function SocialQuestGroupFrame:ExpandAll(tabId)
    SocialQuest.db.char.frameState.collapsedZones[tabId] = {}
    self:Refresh()
end

-- Collapse all named zones in the given tab and redraw.
function SocialQuestGroupFrame:CollapseAll(tabId, zoneNames)
    local collapsed = SocialQuest.db.char.frameState.collapsedZones
    if not collapsed[tabId] then collapsed[tabId] = {} end
    for _, name in ipairs(zoneNames) do
        collapsed[tabId][name] = true
    end
    self:Refresh()
end

-- Flip the collapsed state of one zone in the given tab and redraw.
-- Absent key = expanded (spec default). Set true when collapsing, nil when expanding,
-- so no stale false entries accumulate in the saved variable table.
function SocialQuestGroupFrame:ToggleZone(tabId, zoneName)
    local collapsedZones = SocialQuest.db.char.frameState.collapsedZones
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

-- Called by the OnProfileReset callback in SocialQuest.lua.
-- Clears lastRenderedTab so the next Refresh() does not write a stale scroll
-- offset back into the freshly-reset char.frameState.
-- RequestRefresh() is a no-op when the frame has never been opened; in that
-- case nil-clearing lastRenderedTab is the only meaningful work here.
function SocialQuestGroupFrame:ResetFrameState()
    lastRenderedTab = nil
    self:RequestRefresh()
end

-- Called from OnPlayerLeavingWorld (before CloseAllWindows hides the frame).
-- Snapshots the current open state and sets the guard flag so the OnHide
-- script does not overwrite the snapshot when WoW closes the window.
function SocialQuestGroupFrame:OnLeavingWorld()
    leavingWorld = true
    SocialQuest.db.char.frameState.windowOpen = frame ~= nil and frame:IsShown()
end

-- Called from OnPlayerEnteringWorld (after the loading screen).
-- Resets the guard flag and reopens the window if it was open before the transition.
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

