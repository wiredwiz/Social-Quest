-- UI/Tabs/MineTab.lua
-- Mine tab provider. Shows the local player's quests grouped by zone and chain.
-- Cross-chain peers (party members on a different step of the same chain) appear
-- as player rows beneath the relevant quest entry.

MineTab = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

------------------------------------------------------------------------
-- Tab provider interface
------------------------------------------------------------------------

function MineTab:GetLabel()
    return L["Mine"]
end

-- Builds the zone/chain/quest tree from local AQL data + GroupData chain peers.
-- Returns: { zones = { [zoneName] = { name, order, chains, quests } } }
function MineTab:BuildTree(filterTable)  -- filterTable.search, filterTable.autoZone, and structured filters applied
    local AQL = SocialQuest.AQL
    if not AQL then return { zones = {} } end

    local tree     = { zones = {} }
    local orderIdx = 0

    for questID, questInfo in pairs(AQL:GetAllQuests()) do
        local zoneName = questInfo.zone or L["Other Quests"]

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

        -- Build questEntry from local AQL data.
        local entry = {
            questID        = questInfo.questID,
            title          = questInfo.title,
            level          = questInfo.level,
            zone           = zoneName,
            isComplete     = questInfo.isComplete,
            isFailed       = questInfo.isFailed,
            isTracked      = questInfo.isTracked,
            logIndex       = questInfo.logIndex,
            suggestedGroup = questInfo.suggestedGroup,
            timerSeconds   = questInfo.timerSeconds,
            snapshotTime   = questInfo.snapshotTime,
            chainInfo      = questInfo.chainInfo,
            objectives     = questInfo.objectives,
            players        = {},
        }

        local chainResult = questInfo.chainInfo
        local engaged = AQL:_GetCurrentPlayerEngagedQuests()
        local ci = chainResult and chainResult.knownStatus == AQL.ChainStatus.Known
            and AQL:SelectBestChain(chainResult, engaged)
        if ci and ci.chainID then
            local chainID = ci.chainID
            if not zone.chains[chainID] then
                -- chainID is always the questID of step 1; resolve its title for a
                -- stable chain label regardless of which step the player is currently on.
                local step1Info = AQL:GetQuestInfo(chainID)
                local chainTitle = (step1Info and step1Info.title) or questInfo.title
                zone.chains[chainID] = { title = chainTitle, steps = {} }
            end
            table.insert(zone.chains[chainID].steps, entry)

            -- Find cross-chain peers: party members on the same chain, different step.
            for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
                if playerData.quests then
                    for pQuestID in pairs(playerData.quests) do
                        local pChainResult = SocialQuestTabUtils.GetChainInfoForQuestID(pQuestID)
                        local pEngaged = {}
                        for aqid in pairs(playerData.completedQuests or {}) do pEngaged[aqid] = true end
                        for aqid in pairs(playerData.quests) do pEngaged[aqid] = true end
                        local pCI = AQL:SelectBestChain(pChainResult, pEngaged)
                        if pCI and pCI.chainID == chainID and pCI.step ~= ci.step then
                            table.insert(entry.players, {
                                name           = playerName,
                                isMe           = false,
                                hasSocialQuest = playerData.hasSocialQuest,
                                step           = pCI.step,
                                chainLength    = pCI.length,
                                objectives     = {},
                                isComplete     = playerData.quests[pQuestID] and
                                                 playerData.quests[pQuestID].isComplete or false,
                                hasCompleted   = false,
                                needsShare     = false,
                                dataProvider   = playerData.dataProvider,
                            })
                        end
                    end
                end
            end
        else
            table.insert(zone.quests, entry)
        end
    end

    -- Sort chain steps ascending by step number.
    local sortEngaged = AQL:_GetCurrentPlayerEngagedQuests()
    for _, zone in pairs(tree.zones) do
        for _, chain in pairs(zone.chains) do
            table.sort(chain.steps, function(a, b)
                local aResult = a.chainInfo
                local bResult = b.chainInfo
                local aci = aResult and aResult.knownStatus == AQL.ChainStatus.Known
                    and AQL:SelectBestChain(aResult, sortEngaged)
                local bci = bResult and bResult.knownStatus == AQL.ChainStatus.Known
                    and AQL:SelectBestChain(bResult, sortEngaged)
                return (aci and aci.step or 0) < (bci and bci.step or 0)
            end)
        end
    end

    -- autoZone exact match (same as Party/Shared tabs)
    if filterTable and filterTable.autoZone then
        for zoneName in pairs(tree.zones) do
            if zoneName ~= filterTable.autoZone then
                tree.zones[zoneName] = nil
            end
        end
    end

    -- ── Structured filter application (Feature #18) ──────────────────
    local ft = filterTable
    if ft then
        local T = SocialQuestTabUtils

        local function mapGroup(entry)
            local sg = entry.suggestedGroup or 0
            if sg >= 2 then return tostring(sg) end
            if sg == 1 then return "yes" end
            return "no"
        end

        local function questPasses(entry)
            if ft.zone   and not T.MatchesStringFilter(entry.zone,  ft.zone)   then return false end
            if ft.title  and not T.MatchesStringFilter(entry.title, ft.title)  then return false end
            if ft.level  and not T.MatchesNumericFilter(entry.level, ft.level) then return false end
            local chainStep = nil
            if entry.chainInfo and entry.chainInfo.knownStatus == AQL.ChainStatus.Known then
                local sci = AQL:SelectBestChain(entry.chainInfo, AQL:_GetCurrentPlayerEngagedQuests())
                chainStep = sci and sci.step
            end
            if ft.step   and not T.MatchesNumericFilter(chainStep, ft.step)     then return false end
            if ft.group  and not T.MatchesEnumFilter(mapGroup(entry), ft.group) then return false end
            if ft.type   and not T.MatchesTypeFilter(entry, ft.type)  then return false end
            if ft.status then
                local s = entry.isFailed and "failed" or entry.isComplete and "complete" or "incomplete"
                if not T.MatchesEnumFilter(s, ft.status) then return false end
            end
            if ft.tracked then
                local tv = entry.isTracked and "yes" or "no"
                if not T.MatchesEnumFilter(tv, ft.tracked) then return false end
            end
            return true
        end

        for zoneName, zone in pairs(tree.zones) do
            -- Filter standalone quests
            local kept = {}
            for _, e in ipairs(zone.quests) do
                if questPasses(e) then kept[#kept+1] = e end
            end
            zone.quests = kept

            -- Filter chains
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

            -- Remove empty zones
            local empty = true
            for _ in pairs(zone.chains) do empty = false; break end
            if empty then empty = (#zone.quests == 0) end
            if empty then tree.zones[zoneName] = nil end
        end
    end
    -- ── End of structured filter application ─────────────────────────

    -- Search text filter: case-insensitive substring match on quest/chain titles.
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

-- Renders the Mine tree into contentFrame using RowFactory.
-- tabCollapsedZones: the mine-tab subtable from SocialQuestDB.char.frameState.collapsedZones.
-- Returns: total content height (number).
function MineTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
    local tree  = self:BuildTree(filterTable)
    local y     = 0
    local zones = tree.zones

    -- Collect zones sorted by insertion order.
    local sortedZones = {}
    for _, zone in pairs(zones) do
        table.insert(sortedZones, zone)
    end
    table.sort(sortedZones, function(a, b) return a.order < b.order end)

    for _, zone in ipairs(sortedZones) do
        local zoneName    = zone.name
        local isCollapsed = tabCollapsedZones[zoneName] == true

        y = rowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, function()
            SocialQuestGroupFrame:ToggleZone("mine", zoneName)
        end)

        if not isCollapsed then
            local QUEST_INDENT = 16
            local PEER_INDENT  = 32
            local OBJ_INDENT   = 32

            -- Sort chainIDs numerically ascending.
            local sortedChainIDs = {}
            for chainID in pairs(zone.chains) do
                table.insert(sortedChainIDs, chainID)
            end
            table.sort(sortedChainIDs)

            for _, chainID in ipairs(sortedChainIDs) do
                local chain = zone.chains[chainID]
                y = rowFactory.AddChainHeader(contentFrame, y, chain.title, QUEST_INDENT)

                for _, entry in ipairs(chain.steps) do
                    local callbacks = {
                        onTitleShiftClick = function(logIndex, isTracked)
                            if isTracked then
                                RemoveQuestWatch(logIndex)
                            else
                                AddQuestWatch(logIndex)
                            end
                            -- Trigger a cache rebuild so isTracked updates.
                            SocialQuest.AQL.QuestCache:Rebuild()
                            SocialQuestGroupFrame:Refresh()
                        end,
                    }
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, callbacks)

                    local objs = entry.objectives or {}
                    if #objs > 0 then
                        y = rowFactory.AddPlayerRow(contentFrame, y, {
                            name           = "",
                            isMe           = true,
                            hasSocialQuest = true,
                            hasCompleted   = false,
                            needsShare     = false,
                            isComplete     = false,
                            objectives     = objs,
                        }, OBJ_INDENT + 8, 0)
                    end

                    for _, peer in ipairs(entry.players) do
                        y = rowFactory.AddPlayerRow(contentFrame, y, peer, PEER_INDENT + 8)
                    end
                end
            end

            -- Standalone quests (no chain info).
            for _, entry in ipairs(zone.quests) do
                local callbacks = {
                    onTitleShiftClick = function(logIndex, isTracked)
                        if isTracked then
                            RemoveQuestWatch(logIndex)
                        else
                            AddQuestWatch(logIndex)
                        end
                        SocialQuest.AQL.QuestCache:Rebuild()
                        SocialQuestGroupFrame:Refresh()
                    end,
                }
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, callbacks)

                local objs = entry.objectives or {}
                if #objs > 0 then
                    y = rowFactory.AddPlayerRow(contentFrame, y, {
                        name           = "",
                        isMe           = true,
                        hasSocialQuest = true,
                        hasCompleted   = false,
                        needsShare     = false,
                        isComplete     = false,
                        objectives     = objs,
                    }, OBJ_INDENT, 0)
                end
            end
        end
    end

    return math.max(y, 10)
end
