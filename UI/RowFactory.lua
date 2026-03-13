-- UI/RowFactory.lua
-- Stateless row-drawing utilities for the group frame tab providers.
-- All functions take (contentFrame, y, ...) and return the new y offset.
-- contentFrame is the scroll child (width = 360 px, set by GroupFrame).
-- StaticPopupDialogs["SQ_WOWHEAD_POPUP"] is registered in GroupFrame.lua.

RowFactory = {}

local CONTENT_WIDTH = 360
local ROW_H         = 18     -- standard row height in pixels
local INDENT_STEP   = 16     -- pixels per indent level

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

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

-- Formats remaining timer as "M:SS". Returns nil when expired or no data.
local function formatTimeRemaining(timerSeconds, snapshotTime)
    if not timerSeconds or not snapshotTime then return nil end
    local remaining = timerSeconds - (GetTime() - snapshotTime)
    if remaining <= 0 then return nil end
    return string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

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
    label:SetWidth(CONTENT_WIDTH - 24)
    label:SetJustifyH("LEFT")
    label:SetText(C.header .. zoneName .. C.reset)

    return y + ROW_H + 4
end

-- Chain group label row (indented, cyan).
function RowFactory.AddChainHeader(contentFrame, y, chainTitle, indent)
    local C = SocialQuestColors
    local x = indent or 0

    local label = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    label:SetWidth(CONTENT_WIDTH - x)
    label:SetJustifyH("LEFT")
    label:SetText(C.chain .. chainTitle .. C.reset)

    return y + ROW_H + 2
end

-- Quest row.
-- Layout (left to right): [?] link | [v] checkmark (Mine only) | title | badge (right)
-- callbacks = { onTitleShiftClick = function(logIndex, isTracked) }
--   onTitleShiftClick: nil on Party/Shared tabs (disables checkmark and shift-click).
--   NOTE: The link button calls StaticPopup_Show directly; no onLinkClick callback.
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
        StaticPopup_Show("SQ_WOWHEAD_POPUP", questEntry.wowheadUrl or "")
    end)
    x = x + 24

    -- [v] Tracked checkmark — only when onTitleShiftClick is provided and quest is tracked.
    if callbacks and callbacks.onTitleShiftClick and questEntry.isTracked then
        local check = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        check:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        check:SetWidth(18)
        check:SetText(C.completed .. "[v]" .. C.reset)
        x = x + 20
    end

    -- Determine badge text. "Complete" trumps "Group".
    local badgeText = ""
    if questEntry.isComplete then
        badgeText = C.completed .. "(Complete)" .. C.reset
    elseif questEntry.suggestedGroup and questEntry.suggestedGroup > 0 then
        badgeText = C.chain .. "(Group)" .. C.reset
    end
    local badgeWidth = badgeText ~= "" and 80 or 0

    -- Quest title button.
    local titleWidth = CONTENT_WIDTH - x - badgeWidth - 10
    local titleBtn = CreateFrame("Button", nil, contentFrame)
    titleBtn:SetSize(math.max(titleWidth, 20), ROW_H)
    titleBtn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    titleBtn:SetNormalFontObject("GameFontNormalSmall")
    titleBtn:SetHighlightFontObject("GameFontHighlightSmall")

    -- Build title string: title [Step X of Y] [timer].
    local titleText = questEntry.title or "Quest"
    local ci = questEntry.chainInfo
    if ci and ci.knownStatus == "known" then
        titleText = titleText
            .. " (Step " .. tostring(ci.step   or "?")
            .. " of "    .. tostring(ci.length or "?") .. ")"
    end
    local timeStr = formatTimeRemaining(questEntry.timerSeconds, questEntry.snapshotTime)
    if timeStr then
        titleText = titleText .. " " .. C.timer .. "[" .. timeStr .. "]" .. C.reset
    end
    titleBtn:SetText(titleText)

    local c = getDifficultyColor(questEntry.level)
    titleBtn:SetTextColor(c.r, c.g, c.b)

    if callbacks then
        titleBtn:SetScript("OnClick", function()
            if IsShiftKeyDown() and callbacks.onTitleShiftClick then
                callbacks.onTitleShiftClick(questEntry.logIndex, questEntry.isTracked)
            end
        end)
    end

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
    local clr = objectiveEntry.isFinished and C.completed or C.active

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
--                     objectives, step (optional), chainLength (optional).
function RowFactory.AddPlayerRow(contentFrame, y, playerEntry, indent)
    local C    = SocialQuestColors
    local x    = indent or 0
    local name = playerEntry.name or "Unknown"

    if playerEntry.hasCompleted then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.completed .. name .. " FINISHED" .. C.reset)
        return y + ROW_H + 2

    elseif playerEntry.needsShare then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.unknown .. name .. " Needs it Shared" .. C.reset)
        return y + ROW_H + 2

    elseif not playerEntry.hasSocialQuest
        and (not playerEntry.objectives or #playerEntry.objectives == 0) then
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.unknown .. name .. " (no data)" .. C.reset)
        return y + ROW_H + 2

    else
        -- Name line (with optional step info).
        local nameLine = name
        if playerEntry.step and playerEntry.chainLength then
            nameLine = nameLine
                .. " Step " .. tostring(playerEntry.step)
                .. " of "   .. tostring(playerEntry.chainLength)
        end
        local nameFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        nameFs:SetWidth(CONTENT_WIDTH - x - 4)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(C.white .. nameLine .. C.reset)
        y = y + ROW_H + 2

        -- Objective rows.
        for _, obj in ipairs(playerEntry.objectives or {}) do
            y = RowFactory.AddObjectiveRow(contentFrame, y, obj, x + INDENT_STEP)
        end
        return y
    end
end
