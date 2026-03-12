-- UI/GroupFrame.lua
-- Group quest window. Opened via /sq or minimap button.
-- Three tabs: Shared Quests, My Quests, Party Quests.
-- Chain-aware matching: groups quests by chainID when known.

SocialQuestGroupFrame = {}

local frame = nil
local currentTab = "shared"  -- "shared" | "mine" | "party"
local refreshPending = false

------------------------------------------------------------------------
-- Frame construction
------------------------------------------------------------------------

local function createFrame()
    local f = CreateFrame("Frame", "SocialQuestGroupFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(400, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.title = f.TitleBg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
    f.title:SetText("SocialQuest — Group Quests")

    -- Scroll area for quest content.
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(360, 1)
    f.scrollFrame:SetScrollChild(f.content)

    -- Tabs.
    local function makeTab(name, label, offsetX)
        local tab = CreateFrame("Button", "SocialQuestTab_"..name, f, "TabButtonTemplate")
        tab:SetPoint("BOTTOMLEFT", f, "TOPLEFT", offsetX, -30)
        tab:SetText(label)
        tab:SetScript("OnClick", function()
            currentTab = name
            SocialQuestGroupFrame:Refresh()
        end)
        return tab
    end

    f.tabShared = makeTab("shared", "Shared",  10)
    f.tabMine   = makeTab("mine",   "Mine",    90)
    f.tabParty  = makeTab("party",  "Party",  150)

    return f
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function SocialQuestGroupFrame:Toggle()
    if not frame then frame = createFrame() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:Refresh()
    end
end

-- Called by GroupData/Comm whenever data changes.
-- Batches refreshes to avoid multiple redraws per frame.
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
    -- Clear existing content.
    for _, child in ipairs({frame.content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    if currentTab == "shared" then
        self:RenderSharedTab()
    elseif currentTab == "mine" then
        self:RenderMineTab()
    else
        self:RenderPartyTab()
    end
end

------------------------------------------------------------------------
-- Chain-aware grouping helpers
------------------------------------------------------------------------

-- Returns a grouping key for a questID:
--   If chain is known, returns "chain:<chainID>"
--   Otherwise returns "quest:<questID>"
local function groupKey(questID)
    local AQL = SocialQuest.AQL
    if AQL then
        local chain = AQL:GetChainInfo(questID)
        if chain and chain.knownStatus == "known" and chain.chainID then
            return "chain:" .. chain.chainID, chain
        end
    end
    return "quest:" .. questID, nil
end

-- Format a time duration (seconds) as "M:SS".
local function formatTime(seconds)
    if not seconds or seconds <= 0 then return "0:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

-- Estimate remaining timer for a remote player's quest snapshot.
local function estimateTimer(timerSeconds, snapshotTime)
    if not timerSeconds or not snapshotTime then return nil end
    local elapsed = GetTime() - snapshotTime
    local remaining = timerSeconds - elapsed
    return remaining
end

------------------------------------------------------------------------
-- Shared Quests Tab
------------------------------------------------------------------------

function SocialQuestGroupFrame:RenderSharedTab()
    local AQL = SocialQuest.AQL
    if not AQL then return end
    local C = SocialQuestColors

    -- Build groups: key → { localQuestID, players = { [name] = questID } }
    local groups = {}

    -- Include local player's quests.
    for questID, info in pairs(AQL:GetAllQuests()) do
        local key, chain = groupKey(questID)
        if not groups[key] then groups[key] = { chain = chain, members = {} } end
        groups[key].members["(You)"] = questID
    end

    -- Include group members' quests.
    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests then
            for questID in pairs(entry.quests) do
                local key, chain = groupKey(questID)
                if not groups[key] then groups[key] = { chain = chain, members = {} } end
                groups[key].members[playerName] = questID
            end
        end
    end

    -- Filter to groups with at least 2 members (shared = 2+ people on same content).
    local y = 0
    local function addText(text, indent)
        local fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", indent or 0, -y)
        fs:SetText(text)
        fs:SetWidth(340)
        y = y + fs:GetStringHeight() + 4
    end

    for key, group in pairs(groups) do
        local memberCount = 0
        for _ in pairs(group.members) do memberCount = memberCount + 1 end
        if memberCount < 2 then goto continue end

        if group.chain then
            -- Chain display.
            local chain = group.chain
            addText(C.chain .. "[Chain] " .. (chain.steps and chain.steps[chain.step] and chain.steps[chain.step].title or "Unknown Chain") .. C.reset)

            -- Step bar: show each step with member positions marked.
            local stepLine = "  Step: "
            for i = 1, chain.length do
                stepLine = stepLine .. i
                if i < chain.length then stepLine = stepLine .. " -- " end
            end
            addText(stepLine)

            for playerName, questID in pairs(group.members) do
                local playerChain = AQL and AQL:GetChainInfo(questID)
                local step = playerChain and playerChain.step or "?"
                local label = playerName .. ": step " .. step

                -- Timer display.
                if playerName == "(You)" then
                    local info = AQL:GetQuest(questID)
                    if info and info.timerSeconds then
                        local remaining = info.timerSeconds - (GetTime() - info.snapshotTime)
                        if remaining > 0 then
                            label = label .. "  " .. C.timer .. "⏱ " .. formatTime(remaining) .. C.reset
                        end
                    end
                else
                    local pentry = SocialQuestGroupData.PlayerQuests[playerName]
                    local pquest = pentry and pentry.quests and pentry.quests[questID]
                    if pquest and pquest.timerSeconds then
                        local remaining = estimateTimer(pquest.timerSeconds, pquest.snapshotTime)
                        if remaining and remaining > 0 then
                            label = label .. "  " .. C.timer .. "⏱ ~" .. formatTime(remaining) .. " (est.)" .. C.reset
                        elseif remaining then
                            label = label .. "  " .. C.timer .. "(Timer may have expired)" .. C.reset
                        end
                    end
                end

                addText(label, 16)
            end

            -- Relative step summary: compare local player's step to each other member.
            -- "You are N steps ahead/behind" per the spec chain display example.
            local myStep = nil
            local myQuestID = group.members["(You)"]
            if myQuestID then
                local myCI = AQL and AQL:GetChainInfo(myQuestID)
                myStep = myCI and myCI.step
            end
            if myStep then
                for playerName, questID in pairs(group.members) do
                    if playerName ~= "(You)" then
                        local theirCI = AQL and AQL:GetChainInfo(questID)
                        local theirStep = theirCI and theirCI.step
                        if theirStep and theirStep ~= myStep then
                            local diff = myStep - theirStep
                            local rel = diff > 0
                                and string.format("You are %d step(s) ahead of %s.", diff, playerName)
                                or  string.format("You are %d step(s) behind %s.", -diff, playerName)
                            addText(rel, 16)
                        end
                    end
                end
            end
        else
            -- Standalone quest display.
            local questID = next(group.members)  -- get any questID for title lookup
            local title = AQL and AQL:GetQuest(questID) and AQL:GetQuest(questID).title
                          or C_QuestLog.GetTitleForQuestID(questID)
                          or ("Quest " .. questID)
            addText(C.header .. "[Quest] " .. title .. C.reset)

            for playerName, qid in pairs(group.members) do
                local label = "  " .. playerName .. ":"
                if playerName == "(You)" then
                    local info = AQL and AQL:GetQuest(qid)
                    if info then
                        for _, obj in ipairs(info.objectives or {}) do
                            label = label .. " " .. obj.numFulfilled .. "/" .. obj.numRequired
                        end
                    end
                else
                    local pentry = SocialQuestGroupData.PlayerQuests[playerName]
                    local pquest = pentry and pentry.quests and pentry.quests[qid]
                    if pquest then
                        for _, obj in ipairs(pquest.objectives or {}) do
                            label = label .. " " .. obj.numFulfilled .. "/" .. obj.numRequired
                        end
                    else
                        label = label .. " " .. SocialQuestColors.unknown .. "(no data)" .. SocialQuestColors.reset
                    end
                end
                addText(label, 8)
            end
        end

        ::continue::
    end

    frame.content:SetHeight(math.max(y, 10))
end

------------------------------------------------------------------------
-- My Quests Tab
------------------------------------------------------------------------

function SocialQuestGroupFrame:RenderMineTab()
    local AQL = SocialQuest.AQL
    if not AQL then return end
    local C = SocialQuestColors

    -- Build set of questIDs shared with any group member.
    local sharedIDs = {}
    for _, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests then
            for questID in pairs(entry.quests) do
                sharedIDs[questID] = true
            end
        end
    end

    local y = 0
    local function addText(text, indent)
        local fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", indent or 0, -y)
        fs:SetText(text)
        fs:SetWidth(340)
        y = y + fs:GetStringHeight() + 4
    end

    for questID, info in pairs(AQL:GetAllQuests()) do
        if not sharedIDs[questID] then
            local title = info.title or ("Quest " .. questID)
            local chain = info.chainInfo
            local header = C.white .. title .. C.reset
            if chain and chain.knownStatus == "known" then
                header = header .. "  " .. C.chain .. "(chain step " .. chain.step .. "/" .. chain.length .. ")" .. C.reset
            end
            addText(header)

            for _, obj in ipairs(info.objectives or {}) do
                addText("  " .. obj.text, 8)
            end
        end
    end

    frame.content:SetHeight(math.max(y, 10))
end

------------------------------------------------------------------------
-- Party Quests Tab
------------------------------------------------------------------------

function SocialQuestGroupFrame:RenderPartyTab()
    local AQL = SocialQuest.AQL
    if not AQL then return end
    local C = SocialQuestColors

    -- Build set of local player's questIDs.
    local myIDs = {}
    for questID in pairs(AQL:GetAllQuests()) do
        myIDs[questID] = true
    end

    local y = 0
    local function addText(text, indent)
        local fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", indent or 0, -y)
        fs:SetText(text)
        fs:SetWidth(340)
        y = y + fs:GetStringHeight() + 4
    end

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests then
            for questID, qdata in pairs(entry.quests) do
                if not myIDs[questID] then
                    local title = C_QuestLog.GetTitleForQuestID(questID) or ("Quest " .. questID)
                    local chain = AQL:GetChainInfo(questID)
                    local header = C.white .. title .. C.reset .. "  — " .. playerName

                    if chain and chain.knownStatus == "known" then
                        local myChain = nil
                        -- Check if local player is in same chain.
                        for myQuestID in pairs(AQL:GetAllQuests()) do
                            local myCI = AQL:GetChainInfo(myQuestID)
                            if myCI and myCI.chainID == chain.chainID then
                                myChain = myCI
                                break
                            end
                        end
                        if myChain then
                            local diff = chain.step - myChain.step
                            local rel = diff > 0 and ("you are " .. diff .. " step(s) behind")
                                      or diff < 0 and ("you are " .. (-diff) .. " step(s) ahead")
                                      or "same step"
                            header = header .. "  " .. C.chain .. "(chain step " .. chain.step .. "/" .. chain.length .. " — " .. rel .. ")" .. C.reset
                        else
                            header = header .. "  " .. C.chain .. "(chain step " .. chain.step .. "/" .. chain.length .. ")" .. C.reset
                        end
                    end

                    addText(header)

                    if entry.hasSocialQuest then
                        for _, obj in ipairs(qdata.objectives or {}) do
                            addText("  " .. obj.numFulfilled .. "/" .. obj.numRequired, 8)
                        end
                    end
                end
            end
        end
    end

    frame.content:SetHeight(math.max(y, 10))
end
