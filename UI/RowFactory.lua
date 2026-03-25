-- UI/RowFactory.lua
-- Stateless row-drawing utilities for the group frame tab providers.
-- All functions take (contentFrame, y, ...) and return the new y offset.
-- contentFrame is the scroll child; width is set dynamically by GroupFrame:Refresh()
-- via RowFactory.SetContentWidth(). CONTENT_WIDTH defaults to 360 on first load.

RowFactory = {}

local CONTENT_WIDTH = 360
local ROW_H         = 18     -- standard row height in pixels
local INDENT_STEP   = 16     -- pixels per indent level
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

-- Called by GroupFrame:Refresh() to set content width before rendering.
-- Writes to the CONTENT_WIDTH upvalue so all row functions use the current frame width.
function RowFactory.SetContentWidth(w)
    CONTENT_WIDTH = w
end

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

-- Formats remaining timer as "M:SS". Returns nil when expired or no data.
local function formatTimeRemaining(timerSeconds, snapshotTime)
    if not timerSeconds or not snapshotTime then return nil end
    local remaining = timerSeconds - (SQWowAPI.GetTime() - snapshotTime)
    if remaining <= 0 then return nil end
    return string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
end

local function openQuestLogToQuest(questID)
    local AQL = SocialQuest.AQL
    if not AQL then return end
    -- Toggle: if the log is shown, the quest is visible (zone not collapsed), and already
    -- selected, close it. GetQuestLogIndex returns nil when the quest's zone is collapsed,
    -- which causes the condition to fail and fall through to the expand+navigate path.
    if AQL:IsQuestLogShown() and AQL:GetQuestLogIndex(questID) and AQL:GetSelectedQuestId() == questID then
        AQL:HideQuestLog()
        return
    end
    -- Save collapsed state, expand all to make the quest visible, navigate, restore.
    local zones = AQL:GetQuestLogZones()
    AQL:ShowQuestLog()
    AQL:ExpandAllQuestLogHeaders()
    local logIndex = AQL:GetQuestLogIndex(questID)
    -- targetZone is only set when logIndex is non-nil: quest confirmed in the
    -- live log, guaranteed to have a zone. Keep that zone expanded.
    local targetZone
    if logIndex then
        AQL:SetQuestLogSelection(logIndex)
        targetZone = AQL:GetQuest(questID).zone
    end
    -- Restore collapsed state for all other zones. If logIndex was nil,
    -- targetZone is nil and everything restores to its original state.
    for _, z in ipairs(zones) do
        if z.isCollapsed and z.name ~= targetZone then
            AQL:CollapseQuestLogZoneByName(z.name)
        end
    end
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Expand-all / collapse-all control row rendered at the top of each tab.
-- onExpand() and onCollapse() are called with no arguments on button click.
function RowFactory.AddExpandCollapseHeader(contentFrame, y, onExpand, onCollapse)
    local C   = SocialQuestColors
    local mid = math.floor(CONTENT_WIDTH / 2)

    local expandBtn = CreateFrame("Button", nil, contentFrame)
    expandBtn:SetSize(22, ROW_H)
    expandBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -y)
    expandBtn:SetText("[+]")
    expandBtn:SetNormalFontObject("GameFontNormalSmall")
    expandBtn:SetHighlightFontObject("GameFontHighlightSmall")
    if onExpand then expandBtn:SetScript("OnClick", onExpand) end

    local expandLabel = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandLabel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 24, -y)
    expandLabel:SetSize(mid - 24, ROW_H)
    expandLabel:SetJustifyH("LEFT")
    expandLabel:SetJustifyV("MIDDLE")
    expandLabel:SetText(C.white .. L["expand all"] .. C.reset)

    local collapseBtn = CreateFrame("Button", nil, contentFrame)
    collapseBtn:SetSize(22, ROW_H)
    collapseBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", mid, -y)
    collapseBtn:SetText("[-]")
    collapseBtn:SetNormalFontObject("GameFontNormalSmall")
    collapseBtn:SetHighlightFontObject("GameFontHighlightSmall")
    if onCollapse then collapseBtn:SetScript("OnClick", onCollapse) end

    local collapseLabel = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseLabel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", mid + 24, -y)
    collapseLabel:SetSize(CONTENT_WIDTH - mid - 24, ROW_H)
    collapseLabel:SetJustifyH("LEFT")
    collapseLabel:SetJustifyV("MIDDLE")
    collapseLabel:SetText(C.white .. L["collapse all"] .. C.reset)

    return y + ROW_H + 4
end

-- Zone/category header row with [+]/[-] collapse toggle.
-- onToggle() is called on button click (no arguments).
function RowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, onToggle)
    local C = SocialQuestColors

    local toggleBtn = CreateFrame("Button", nil, contentFrame)
    toggleBtn:SetSize(22, ROW_H)
    toggleBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -y)
    toggleBtn:SetText(isCollapsed and "[+]" or "[-]")
    toggleBtn:SetNormalFontObject("GameFontNormalSmall")
    toggleBtn:SetHighlightFontObject("GameFontHighlightSmall")
    if onToggle then
        toggleBtn:SetScript("OnClick", onToggle)
    end

    local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 24, -y)
    label:SetSize(CONTENT_WIDTH - 24, ROW_H)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(C.header .. zoneName .. C.reset)

    return y + ROW_H + 4
end

-- Chain group label row (indented, cyan).
function RowFactory.AddChainHeader(contentFrame, y, chainTitle, indent)
    local C = SocialQuestColors
    local x = indent or 0

    local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    label:SetSize(CONTENT_WIDTH - x, ROW_H)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(C.chain .. chainTitle .. C.reset)

    return y + ROW_H + 2
end

-- Quest row.
-- Layout (left to right): [?] link | [v] checkmark (Mine only) | title | badge (right)
-- callbacks = { onTitleShiftClick = function(logIndex, isTracked) }
--   onTitleShiftClick: nil on Party/Shared tabs (disables checkmark and shift-click).
--   NOTE: The link button calls SocialQuestGroupFrame.ShowWowheadUrl directly; no onLinkClick callback.
function RowFactory.AddQuestRow(contentFrame, y, questEntry, indent, callbacks)
    local C = SocialQuestColors
    local x = indent or 0

    -- [?] Wowhead link button.
    local linkBtn = CreateFrame("Button", nil, contentFrame)
    linkBtn:SetSize(22, ROW_H)
    linkBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    linkBtn:SetText("[?]")
    linkBtn:SetNormalFontObject("GameFontNormalSmall")
    linkBtn:SetHighlightFontObject("GameFontHighlightSmall")
    linkBtn:SetScript("OnClick", function()
        SocialQuestGroupFrame.ShowWowheadUrl(questEntry.questID)
    end)
    linkBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Click here to copy the wowhead quest url"], 1, 1, 1)
        GameTooltip:Show()
    end)
    linkBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    x = x + 24

    -- Determine badge text. "Complete" trumps "Group".
    -- (Complete) is shown on Mine tab only (callbacks.onTitleShiftClick is present
    -- only there). On Party/Shared, completion is shown in the player row instead.
    local badgeText = ""
    if questEntry.isComplete and callbacks and callbacks.onTitleShiftClick then
        badgeText = SocialQuestColors.GetUIColor("completed") .. L["(Complete)"] .. C.reset
    elseif questEntry.suggestedGroup and questEntry.suggestedGroup > 0 then
        badgeText = C.chain .. L["(Group)"] .. C.reset
    end
    local badgeWidth = badgeText ~= "" and 80 or 0

    -- Quest title (FontString for reliable left-alignment).
    -- Template-less Buttons in TBC Classic do not expose GetFontString(), so we
    -- use a plain FontString for display and an invisible Button overlay for clicks.
    local titleWidth = CONTENT_WIDTH - x - badgeWidth - 10

    -- Build title string: title [Step X of Y] [timer].
    local titleText = questEntry.title or "Quest"
    local ci = questEntry.chainInfo
    if ci and ci.knownStatus == SocialQuest.AQL.ChainStatus.Known then
        titleText = titleText
            .. string.format(L[" (Step %s of %s)"], tostring(ci.step or "?"), tostring(ci.length or "?"))
    end
    local timeStr = formatTimeRemaining(questEntry.timerSeconds, questEntry.snapshotTime)
    if timeStr then
        titleText = titleText .. " " .. C.timer .. "[" .. timeStr .. "]" .. C.reset
    end
    -- Tracked checkmark inline after title — only when shift-click tracking is enabled.
    -- Uses the standard WoW checkbox checkmark texture, matching the quest log's style.
    if callbacks and callbacks.onTitleShiftClick and questEntry.isTracked then
        titleText = titleText .. " |TInterface\\Buttons\\UI-CheckBox-Check:12:12:0:0|t"
    end
    local c = SocialQuest.AQL:GetQuestDifficultyColor(questEntry.level)
    local colorCode = string.format("|cFF%02X%02X%02X",
        math.floor(c.r * 255),
        math.floor(c.g * 255),
        math.floor(c.b * 255))

    local titleFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    titleFs:SetSize(math.max(titleWidth, 20), ROW_H)
    titleFs:SetJustifyH("LEFT")
    titleFs:SetJustifyV("MIDDLE")
    titleFs:SetText(colorCode .. titleText .. "|r")

    -- Invisible click overlay: always created on all three tabs.
    -- Left-click opens the Quest Log (only when player has the quest: logIndex non-nil).
    -- Shift-click tracks/untracks (Mine tab only: callbacks.onTitleShiftClick present).
    -- Unhandled combos (e.g. shift-click on Party/Shared) do nothing.
    local titleBtn = CreateFrame("Button", nil, contentFrame)
    titleBtn:SetAllPoints(titleFs)
    titleBtn:SetScript("OnClick", function()
        if IsShiftKeyDown() and callbacks and callbacks.onTitleShiftClick then
            callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
        elseif not IsShiftKeyDown() and questEntry.logIndex then
            openQuestLogToQuest(questEntry.questID)
        end
        -- else: no logIndex (player doesn't have quest) or unhandled combo → do nothing
    end)

    -- Badge (right-aligned).
    if badgeText ~= "" then
        local badge = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -8, -y)
        badge:SetWidth(badgeWidth)
        badge:SetJustifyH("RIGHT")
        badge:SetText(badgeText)
    end

    return y + ROW_H + 2
end

-- Objective row. Yellow = incomplete, green = complete.
-- objectiveEntry must have: text (string), isFinished (bool).
function RowFactory.AddObjectiveRow(contentFrame, y, objectiveEntry, indent)
    local C  = SocialQuestColors
    local x  = indent or 0
    local clr = objectiveEntry.isFinished and SocialQuestColors.GetUIColor("completed") or C.active

    local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    fs:SetWidth(CONTENT_WIDTH - x - 4)
    fs:SetJustifyH("LEFT")
    fs:SetText(clr .. (objectiveEntry.text or "") .. C.reset)

    return y + fs:GetStringHeight() + 2
end

-- Player row. Display priority (first matching wins):
--   1. playerEntry.hasCompleted → "[Name] FINISHED" (green)
--   2. playerEntry.needsShare   → "[Name] Needs it Shared" (grey)
--   3. hasSocialQuest==false and no objectives → "[Name] (no data)" (grey)
--   4. otherwise → "[Name]" label (+ "Step X of Y" when step/chainLength set),
--                  followed by objective rows.
-- playerEntry fields: name, isMe, hasSocialQuest, hasCompleted, needsShare,
--                     isComplete (optional), objectives, step (optional), chainLength (optional).
function RowFactory.AddPlayerRow(contentFrame, y, playerEntry, indent)
    local C    = SocialQuestColors
    local x    = indent or 0
    local name        = playerEntry.name or "Unknown"
    local nameTag     = playerEntry.dataProvider
                     and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
    local displayName = nameTag and (name .. " " .. nameTag) or name

    if playerEntry.hasCompleted then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(SocialQuestColors.GetUIColor("completed") .. string.format(L["%s FINISHED"], displayName) .. C.reset)
        return y + ROW_H + 2

    elseif playerEntry.isComplete then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.white .. displayName .. C.reset .. " " .. SocialQuestColors.GetUIColor("completed") .. L["Complete"] .. C.reset)
        return y + ROW_H + 2

    elseif playerEntry.needsShare then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.unknown .. string.format(L["%s Needs it Shared"], displayName) .. C.reset)
        return y + ROW_H + 2

    elseif not playerEntry.hasSocialQuest
        and (not playerEntry.objectives or #playerEntry.objectives == 0) then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.unknown .. string.format(L["%s (no data)"], displayName) .. C.reset)
        return y + ROW_H + 2

    else
        local objectives = playerEntry.objectives or {}
        if #objectives == 0 then
            -- Has quest but no objective data yet; show name alone.
            local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
            fs:SetWidth(CONTENT_WIDTH - x - 4)
            fs:SetJustifyH("LEFT")
            fs:SetText(C.white .. displayName .. C.reset)
            return y + ROW_H + 2
        end

        -- One row per objective, prefixed with player name.
        for _, obj in ipairs(objectives) do
            local clr = obj.isFinished and SocialQuestColors.GetUIColor("completed") or C.active
            local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
            fs:SetWidth(CONTENT_WIDTH - x - 4)
            fs:SetJustifyH("LEFT")
            fs:SetText(C.white .. displayName .. C.reset .. " " .. clr .. (obj.text or "") .. C.reset)
            y = y + fs:GetStringHeight() + 2
        end
        return y
    end
end
