-- UI/Tabs/SharedTab.lua
-- Shared tab provider. Shows quests engaged by 2+ players (chain-peer aware).
-- "Engaged" = has questID in active log OR is on a different step of the same chain.
-- No FINISHED or Needs-it-Shared rows on this tab.

SharedTab = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

------------------------------------------------------------------------
-- Tab provider interface
------------------------------------------------------------------------

function SharedTab:GetLabel()
    return L["Shared"]
end

-- Builds the zone/chain/quest tree for quests engaged by 2+ players.
function SharedTab:BuildTree(filterTable)
    local AQL = SocialQuest.AQL
    if not AQL then return { zones = {} } end

    -- Step 1: gather all engagements.
    -- chainEngaged[chainID][playerName] = { questID, step, chainLength, isLocal, qdata }
    -- questEngaged[questID][playerName] = { isLocal, qdata }
    local chainEngaged = {}
    local questEngaged = {}

    local function addEngagement(questID, playerName, isLocal, qdata)
        local chainResult = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
        local engaged
        if isLocal then
            engaged = AQL:_GetCurrentPlayerEngagedQuests()
        else
            engaged = {}
            local pd = SocialQuestGroupData.PlayerQuests[playerName]
            if pd then
                for aqid in pairs(pd.completedQuests or {}) do engaged[aqid] = true end
                for aqid in pairs(pd.quests or {}) do engaged[aqid] = true end
            end
        end
        local ciEntry = SocialQuestTabUtils.SelectChain(chainResult, engaged)
        if ciEntry and ciEntry.chainID then
            local cid = ciEntry.chainID
            if not chainEngaged[cid] then chainEngaged[cid] = {} end
            chainEngaged[cid][playerName] = {
                questID     = questID,
                step        = ciEntry.step,
                chainLength = ciEntry.length,
                isLocal     = isLocal,
                qdata       = qdata,
            }
        else
            if not questEngaged[questID] then questEngaged[questID] = {} end
            questEngaged[questID][playerName] = { isLocal = isLocal, qdata = qdata }
        end
    end

    for questID, questInfo in pairs(AQL:GetAllQuests()) do
        addEngagement(questID, "(You)", true, questInfo)
    end
    for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerData.quests then
            for questID, qdata in pairs(playerData.quests) do
                addEngagement(questID, playerName, false, qdata)
            end
        end
    end

    -- Step 2: build tree from groups with 2+ engaged players.
    local tree     = { zones = {} }
    local orderIdx = 0

    local function ensureZone(zoneName)
        if not tree.zones[zoneName] then
            orderIdx = orderIdx + 1
            tree.zones[zoneName] = {
                name = zoneName, order = orderIdx, chains = {}, quests = {},
            }
        end
        return tree.zones[zoneName]
    end

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
            local filtered = filterTable and filterTable.autoZone and zoneName ~= filterTable.autoZone
            if not filtered then
                local zone = ensureZone(zoneName)

                if not zone.chains[chainID] then
                    zone.chains[chainID] = { title = "Chain " .. chainID, steps = {} }
                end
                -- Prefer step 1's title as the chain label (deterministic across pairs() order).

                -- One questEntry per distinct questID in the chain.
                local addedQuestIDs = {}
                for playerName, eng in pairs(engaged) do
                    if not addedQuestIDs[eng.questID] then
                        addedQuestIDs[eng.questID] = true
                        local localInfo = AQL:GetQuest(eng.questID)
                        local ci = SocialQuestTabUtils.GetChainInfoForQuestID(eng.questID)

                        -- Update chain title: prefer step 1 (deterministic regardless of pairs order).
                        -- eng.step was resolved in addEngagement via SelectBestChain.
                        if localInfo and localInfo.title and eng.step == 1 then
                            zone.chains[chainID].title = localInfo.title
                        elseif localInfo and localInfo.title and
                            zone.chains[chainID].title == "Chain " .. chainID then
                            -- Fallback: use any local title if step 1 not encountered yet.
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

                        -- Players engaged with this specific questID step.
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
                local sortEngaged = AQL:_GetCurrentPlayerEngagedQuests()
                table.sort(zone.chains[chainID].steps, function(a, b)
                    local aResult = a.chainInfo
                    local bResult = b.chainInfo
                    local aci = SocialQuestTabUtils.SelectChain(aResult, sortEngaged)
                    local bci = SocialQuestTabUtils.SelectChain(bResult, sortEngaged)
                    return (aci and aci.step or 0) < (bci and bci.step or 0)
                end)
            end
        end
    end

    -- Process standalone quest groups.
    for questID, engaged in pairs(questEngaged) do
        local count = 0
        for _ in pairs(engaged) do count = count + 1 end
        if count >= 2 then
            local zoneName  = SocialQuestTabUtils.GetZoneForQuestID(questID)
            local filtered = filterTable and filterTable.autoZone and zoneName ~= filterTable.autoZone
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

    -- ── Structured filter application (Feature #18) ──────────────────
    local ft = filterTable
    if ft then
        local T = SocialQuestTabUtils
        local sortEngaged = AQL:_GetCurrentPlayerEngagedQuests()

        local function mapGroup(entry)
            local sg = entry.suggestedGroup or 0
            if sg >= 2 then return tostring(sg) end
            if sg == 1 then return "yes" end
            return "no"
        end

        local function playerMatches(players)
            if not ft.player then return true end
            for _, p in ipairs(players) do
                if T.MatchesStringFilter(p.name, ft.player) then return true end
            end
            return false
        end

        local function questPasses(entry)
            if ft.zone   and not T.MatchesStringFilter(entry.zone,  ft.zone)   then return false end
            if ft.title  and not T.MatchesStringFilter(entry.title, ft.title)  then return false end
            if ft.level  and not T.MatchesNumericFilter(entry.level, ft.level) then return false end
            local chainStep = nil
            local sci = SocialQuestTabUtils.SelectChain(entry.chainInfo, sortEngaged)
            chainStep = sci and sci.step
            if ft.step   and not T.MatchesNumericFilter(chainStep, ft.step)     then return false end
            if ft.group  and not T.MatchesEnumFilter(mapGroup(entry), ft.group) then return false end
            if ft.type   and not T.MatchesTypeFilter(entry, ft.type)  then return false end
            if not playerMatches(entry.players) then return false end
            return true
        end

        for zoneName, zone in pairs(tree.zones) do
            local kept = {}
            for _, e in ipairs(zone.quests) do
                if questPasses(e) then kept[#kept+1] = e end
            end
            zone.quests = kept

            for chainID, chain in pairs(zone.chains) do
                local chainMatchesTitle = not ft.chain
                    or T.MatchesStringFilter(chain.title, ft.chain)
                local keptSteps = {}
                for _, step in ipairs(chain.steps) do
                    if (chainMatchesTitle or T.MatchesStringFilter(step.title, ft.chain))
                       and questPasses(step) then
                        keptSteps[#keptSteps+1] = step
                    end
                end
                chain.steps = keptSteps
                if #chain.steps == 0 then zone.chains[chainID] = nil end
            end

            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end
    -- ── End of structured filter application ─────────────────────────

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
function SharedTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
    local tree = self:BuildTree(filterTable)
    local y    = 0

    local sortedZones = {}
    for _, zone in pairs(tree.zones) do
        table.insert(sortedZones, zone)
    end
    table.sort(sortedZones, function(a, b) return a.order < b.order end)

    for _, zone in ipairs(sortedZones) do
        local zoneName    = zone.name
        local isCollapsed = tabCollapsedZones[zoneName] == true

        y = rowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, function()
            SocialQuestGroupFrame:ToggleZone("shared", zoneName)
        end)

        if not isCollapsed then
            local QUEST_INDENT  = 16
            local PLAYER_INDENT = 32
            local OBJ_INDENT    = 48

            local sortedChainIDs = {}
            for chainID in pairs(zone.chains) do
                table.insert(sortedChainIDs, chainID)
            end
            table.sort(sortedChainIDs)

            for _, chainID in ipairs(sortedChainIDs) do
                local chain = zone.chains[chainID]
                y = rowFactory.AddChainHeader(contentFrame, y, chain.title, QUEST_INDENT)
                for _, entry in ipairs(chain.steps) do
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                    local nameColumnWidth = 0
                    for _, player in ipairs(entry.players) do
                        local w = rowFactory.MeasureNameWidth(rowFactory.GetDisplayName(player))
                        if w > nameColumnWidth then nameColumnWidth = w end
                    end
                    for _, player in ipairs(entry.players) do
                        -- AddPlayerRow renders objectives internally; do not loop here.
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8, nameColumnWidth)
                    end
                end
            end

            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                local nameColumnWidth = 0
                for _, player in ipairs(entry.players) do
                    local w = rowFactory.MeasureNameWidth(rowFactory.GetDisplayName(player))
                    if w > nameColumnWidth then nameColumnWidth = w end
                end
                for _, player in ipairs(entry.players) do
                    -- AddPlayerRow renders objectives internally; do not loop here.
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT, nameColumnWidth)
                end
            end
        end
    end

    return math.max(y, 10)
end
