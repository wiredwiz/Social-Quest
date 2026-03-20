-- UI/GroupFrame.lua
-- Group quest window. Opened via /sq or minimap button.
-- Tab rendering is delegated to MineTab, PartyTab, SharedTab providers.
-- Zone collapse state and active tab are persisted via AceDB frameState.

SocialQuestGroupFrame = {}

local frame          = nil
local refreshPending = false
local urlPopup       = nil
local tabScrollPositions = {}  -- [tabID] = last known vertical scroll offset
local lastRenderedTab    = nil -- set to activeID after each render; nil on first run / reload
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

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
            local outgoingID = SocialQuest.db.profile.frameState.activeTab or "shared"
            tabScrollPositions[outgoingID] = frame.scrollFrame:GetVerticalScroll()
            SocialQuest.db.profile.frameState.activeTab = id
            SocialQuestGroupFrame:Refresh()
        end)
        return tab
    end

    for _, p in ipairs(providers) do
        p.tab = makeTab(p.id, p.module:GetLabel(), p.offsetX)
        PanelTemplates_TabResize(p.tab, 0, 120, 120)
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

    -- Scroll area.
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     10, SCROLL_TOP)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    local initContentW = math.floor(f:GetWidth() - 40)
    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(initContentW, 1)
    f.scrollFrame:SetScrollChild(f.content)

    -- Register with UISpecialFrames so pressing Escape closes this window,
    -- matching standard WoW window behaviour. Requires the frame's global name.
    tinsert(UISpecialFrames, "SocialQuestGroupFramePanel")

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
    C_Timer.After(0, function()
        refreshPending = false
        SocialQuestGroupFrame:Refresh()
    end)
end

function SocialQuestGroupFrame:Refresh()
    if not frame then return end

    -- Resolve activeID early so the scroll save below can reference it before
    -- SetScrollChild() is called (SetScrollChild may clamp GetVerticalScroll to 0).
    local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"

    -- Save scroll position for same-tab refreshes BEFORE SetScrollChild can clamp it.
    -- Tab-switch paths save the outgoing tab's position in the click handler instead.
    if activeID == lastRenderedTab then
        tabScrollPositions[activeID] = frame.scrollFrame:GetVerticalScroll()
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

    -- Determine which scroll offset to restore after the rebuild.
    -- Same-tab path: the offset was saved before SetScrollChild above.
    -- Tab-switch / first-render path (lastRenderedTab is nil on first call):
    --   restore the remembered offset for the incoming tab (0 on first visit).
    local scrollToRestore
    if activeID == lastRenderedTab then
        scrollToRestore = tabScrollPositions[activeID] or 0
    else
        lastRenderedTab = activeID
        scrollToRestore = tabScrollPositions[activeID] or 0
    end

    -- Highlight active tab; deselect others.
    -- PanelTemplates_SelectTab disables the button (standard WoW: can't re-click active tab).
    -- PanelTemplates_DeselectTab re-enables inactive tabs.
    for _, p in ipairs(providers) do
        if p.tab then
            if p.id == activeID then
                PanelTemplates_SelectTab(p.tab)
            else
                PanelTemplates_DeselectTab(p.tab)
            end
        end
    end

    -- Per-tab collapsed zones subtable.
    local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
    local tabCollapsed   = collapsedZones[activeID] or {}

    -- Delegate rendering to the tab provider.
    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed)
    frame.content:SetHeight(math.max(totalHeight, 10))
    frame.scrollFrame:SetVerticalScroll(scrollToRestore)
end

-- Expand all zones in the given tab and redraw.
function SocialQuestGroupFrame:ExpandAll(tabId)
    SocialQuest.db.profile.frameState.collapsedZones[tabId] = {}
    self:Refresh()
end

-- Collapse all named zones in the given tab and redraw.
function SocialQuestGroupFrame:CollapseAll(tabId, zoneNames)
    local collapsed = SocialQuest.db.profile.frameState.collapsedZones
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

