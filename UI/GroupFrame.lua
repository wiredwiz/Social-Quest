-- UI/GroupFrame.lua
-- Group quest window. Opened via /sq or minimap button.
-- Tab rendering is delegated to MineTab, PartyTab, SharedTab providers.
-- Zone collapse state and active tab are persisted via AceDB frameState.

-- StaticPopup_Show(which, text1, ...) calls editBox:SetText(text1) AFTER it
-- fires OnShow, so any SetText in OnShow gets immediately overwritten.
-- Solution: pass the URL as text1 so Blizzard's own code populates the box.
-- OnShow only defers HighlightText/SetFocus to run after Blizzard finishes.
StaticPopupDialogs["SQ_WOWHEAD_POPUP"] = {
    text         = "Quest URL (Ctrl+C to copy):",
    button1      = "Close",
    hasEditBox   = 1,
    editBoxWidth = 300,
    OnShow       = function(self)
        -- Blizzard sets editBox:SetText(text1) after OnShow returns.
        -- Defer focus+highlight to next tick so the text is already set.
        C_Timer.After(0, function()
            if self.editBox and self:IsShown() then
                self.editBox:SetFocus()
                self.editBox:HighlightText()
            end
        end)
    end,
    OnAccept     = function() end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

SocialQuestGroupFrame = {}

local frame          = nil
local refreshPending = false

-- Ordered tab providers. The id must match the collapsedZones subtable key.
-- MineTab/PartyTab/SharedTab are loaded before GroupFrame per TOC order, so
-- the globals exist here and can be assigned directly.
-- Tab display order: Shared | Mine | Party
local providers = {
    { id = "shared", module = SharedTab },
    { id = "mine",   module = MineTab   },
    { id = "party",  module = PartyTab  },
}

------------------------------------------------------------------------
-- Frame construction
------------------------------------------------------------------------

local function createFrame()
    local f = CreateFrame("Frame", "SocialQuestGroupFramePanel", UIParent,
                          "BasicFrameTemplateWithInset")
    f:SetSize(400, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving(); self:Raise() end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.TitleText:SetText("SocialQuest — Group Quests")

    -- Tab buttons.
    local function makeTab(id, label, offsetX)
        local tab = CreateFrame("Button", "SocialQuestTab_" .. id, f, "TabButtonTemplate")
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", offsetX, -24)
        tab:SetText(label)
        tab:SetScript("OnClick", function()
            SocialQuest.db.profile.frameState.activeTab = id
            SocialQuestGroupFrame:Refresh()
        end)
        return tab
    end

    f.tabShared = makeTab("shared", "Shared",  10)
    f.tabMine   = makeTab("mine",   "Mine",    80)
    f.tabParty  = makeTab("party",  "Party",  150)

    -- Separator: a child Frame created AFTER the tab buttons so it draws on top
    -- of any tab art that bleeds below the button frame.  GetHeight() reads the
    -- real TabButtonTemplate height so the separator sits exactly at tab bottom.
    local TAB_TOP    = -24
    local tabH       = f.tabShared:GetHeight()
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

    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(360, 1)
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
        frame:Raise()
        -- Rebuild the quest cache on every open so IsQuestWatched state is
        -- current.  The initial PLAYER_LOGIN rebuild fires before watch state
        -- is fully set up, causing isTracked to be stale on first open.
        if SocialQuest.AQL and SocialQuest.AQL.QuestCache then
            SocialQuest.AQL.QuestCache:Rebuild()
        end
        self:Refresh()
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
    frame.scrollFrame:SetVerticalScroll(0)

    -- Recreate content child (GetChildren does not return FontStrings; hiding is
    -- the only clean way to discard old rows without leaking them).
    if frame.content then frame.content:Hide() end
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(360, 1)
    frame.scrollFrame:SetScrollChild(frame.content)

    -- Find active provider.
    local activeID = SocialQuest.db.profile.frameState.activeTab or "shared"
    local activeProvider
    for _, p in ipairs(providers) do
        if p.id == activeID then
            activeProvider = p
            break
        end
    end
    if not activeProvider or not activeProvider.module then return end

    -- Per-tab collapsed zones subtable.
    local collapsedZones = SocialQuest.db.profile.frameState.collapsedZones
    local tabCollapsed   = collapsedZones[activeID] or {}

    -- Delegate rendering to the tab provider.
    local totalHeight = activeProvider.module:Render(frame.content, RowFactory, tabCollapsed)
    frame.content:SetHeight(math.max(totalHeight, 10))
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

------------------------------------------------------------------------
-- Minimap button (unchanged from original)
------------------------------------------------------------------------

local minimapButton = CreateFrame("Button", "SocialQuestMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:SetPushedTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")

local angle = 225
local function updateMinimapButtonPosition()
    minimapButton:ClearAllPoints()
    local rad = math.rad(angle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(rad), 80 * math.sin(rad))
end
updateMinimapButtonPosition()

minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local cx, cy = Minimap:GetCenter()
        local mx, my = GetCursorPosition()
        local scale  = Minimap:GetEffectiveScale()
        angle = math.deg(math.atan2((my / scale) - cy, (mx / scale) - cx))
        updateMinimapButtonPosition()
    end)
end)
minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function()
    SocialQuestGroupFrame:Toggle()
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("SocialQuest")
    GameTooltip:AddLine("Click to open group quest frame.", 1, 1, 1)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
