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
function MineTab:BuildTree()
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

        local ci = questInfo.chainInfo
        if ci and ci.knownStatus == AQL.ChainStatus.Known and ci.chainID then
            -- Place in chain group.
            local chainID = ci.chainID
            if not zone.chains[chainID] then
                zone.chains[chainID] = { title = questInfo.title, steps = {} }
            end
            -- Prefer the title of step 1 as the chain label (deterministic).
            if ci.step == 1 then
                zone.chains[chainID].title = questInfo.title
            end
            table.insert(zone.chains[chainID].steps, entry)

            -- Find cross-chain peers: party members on the same chain, different step.
            for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
                if playerData.quests then
                    for pQuestID in pairs(playerData.quests) do
                        local pCI = SocialQuestTabUtils.GetChainInfoForQuestID(pQuestID)
                        if pCI.knownStatus == AQL.ChainStatus.Known
                            and pCI.chainID == chainID
                            and pCI.step    ~= ci.step then
                            table.insert(entry.players, {
                                name         = playerName,
                                isMe         = false,
                                hasSocialQuest = playerData.hasSocialQuest,
                                step         = pCI.step,
                                chainLength  = pCI.length,
                                objectives   = {},
                                isComplete   = playerData.quests[pQuestID] and
                                               playerData.quests[pQuestID].isComplete or false,
                                hasCompleted = false,
                                needsShare   = false,
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

-- Renders the Mine tree into contentFrame using RowFactory.
-- tabCollapsedZones: the mine-tab subtable from SocialQuestDB.profile.frameState.collapsedZones.
-- Returns: total content height (number).
function MineTab:Render(contentFrame, rowFactory, tabCollapsedZones)
    local tree  = self:BuildTree()
    local y     = 0
    local zones = tree.zones

    -- Collect zones sorted by insertion order.
    local sortedZones = {}
    for _, zone in pairs(zones) do
        table.insert(sortedZones, zone)
    end
    table.sort(sortedZones, function(a, b) return a.order < b.order end)

    if #sortedZones > 0 then
        local zoneNames = {}
        for _, zone in ipairs(sortedZones) do table.insert(zoneNames, zone.name) end
        y = rowFactory.AddExpandCollapseHeader(contentFrame, y,
            function() SocialQuestGroupFrame:ExpandAll("mine") end,
            function() SocialQuestGroupFrame:CollapseAll("mine", zoneNames) end)
    end

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

                    for _, obj in ipairs(entry.objectives or {}) do
                        y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT + 8)
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

                for _, obj in ipairs(entry.objectives or {}) do
                    y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                end
            end
        end
    end

    return math.max(y, 10)
end
