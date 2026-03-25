-- UI/Tabs/PartyTab.lua
-- Party tab provider. Shows all quests across the party (quest-centric).
-- Each quest appears once; party members with relevant state appear beneath it.

PartyTab = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

-- Returns true only when the quest can actually be shared with this player:
--   1. The quest is marked shareable by the WoW API.
--   2. The player has not already completed the quest.
--   3. If the quest is a known chain step with a previous step, that step
--      has been completed by the player.
-- Falls back gracefully when chain info is unavailable (no Questie).
-- NOTE: AQL is a hard dependency — the addon disables itself if AQL is missing,
-- so the `if not AQL then return false end` guard is a safety net only.
local function isEligibleForShare(questID, playerData)
    local AQL = SocialQuest.AQL
    if not AQL then return false end

    -- Check 1: quest is shareable via AQL.
    if not AQL:IsQuestIdShareable(questID) then return false end

    -- Check 2: player has not already completed this quest.
    if playerData.completedQuests and playerData.completedQuests[questID] then
        return false
    end

    -- Check 3: chain prerequisite met (requires Questie/chain info).
    local ci = AQL:GetChainInfo(questID)
    if ci and ci.knownStatus == AQL.ChainStatus.Known and ci.step and ci.step > 1 then
        local prevStep = ci.steps and ci.steps[ci.step - 1]
        if prevStep and prevStep.questID then
            if not (playerData.completedQuests and
                    playerData.completedQuests[prevStep.questID]) then
                return false
            end
        end
    end

    return true
end

-- Builds the ordered list of playerEntry rows for one questID.
-- localHasIt: true when AQL:GetQuest(questID) is non-nil.
local function buildPlayerRowsForQuest(questID, localHasIt)
    local AQL     = SocialQuest.AQL
    if not AQL then return {} end
    local players = {}

    -- Local player row (always first when local player has any stake).
    local myInfo = AQL:GetQuest(questID)
    if myInfo then
        local ci = myInfo.chainInfo
        table.insert(players, {
            name           = L["(You)"],
            isMe           = true,
            hasSocialQuest = true,
            hasCompleted   = false,
            needsShare     = false,
            isComplete     = myInfo.isComplete or false,
            objectives     = SocialQuestTabUtils.BuildLocalObjectives(myInfo),
            step           = ci and ci.knownStatus == AQL.ChainStatus.Known and ci.step       or nil,
            chainLength    = ci and ci.knownStatus == AQL.ChainStatus.Known and ci.length     or nil,
        })
    elseif AQL:HasCompletedQuest(questID) then
        table.insert(players, {
            name           = L["(You)"],
            isMe           = true,
            hasSocialQuest = true,
            hasCompleted   = true,
            needsShare     = false,
            isComplete     = false,
            objectives     = {},
        })
    end

    -- Party member rows.
    for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        local hasQuest    = playerData.quests and playerData.quests[questID] ~= nil
        local hasCompleted = playerData.completedQuests and
                             playerData.completedQuests[questID] == true

        if hasCompleted then
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = true,
                needsShare     = false,
                isComplete     = false,
                objectives     = {},
                dataProvider   = playerData.dataProvider,
            })
        elseif hasQuest then
            local pquest = playerData.quests[questID]
            local pCI    = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                needsShare     = false,
                isComplete     = pquest.isComplete or false,
                objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pquest, myInfo),
                step           = pCI.knownStatus == AQL.ChainStatus.Known and pCI.step   or nil,
                chainLength    = pCI.knownStatus == AQL.ChainStatus.Known and pCI.length or nil,
                dataProvider   = playerData.dataProvider,
            })
        elseif localHasIt then
            -- Party member lacks the quest; local player has it → "Needs it Shared".
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                isComplete     = false,
                needsShare     = isEligibleForShare(questID, playerData),
                objectives     = {},
                dataProvider   = playerData.dataProvider,
            })
        end
        -- else: member has no stake and local doesn't have it → omit.
    end

    return players
end

------------------------------------------------------------------------
-- Tab provider interface
------------------------------------------------------------------------

function PartyTab:GetLabel()
    return L["Party"]
end

-- Builds the zone/chain/quest tree from all party members + local player.
function PartyTab:BuildTree(filterTable)
    local AQL = SocialQuest.AQL
    if not AQL then return { zones = {} } end

    -- Collect all unique questIDs from local player and all party members.
    local allQuestIDs = {}
    for questID in pairs(AQL:GetAllQuests()) do
        allQuestIDs[questID] = true
    end
    for _, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerData.quests then
            for questID in pairs(playerData.quests) do
                allQuestIDs[questID] = true
            end
        end
    end

    local tree     = { zones = {} }
    local orderIdx = 0

    for questID in pairs(allQuestIDs) do
        local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID)
        local filtered = filterTable and filterTable.zone and zoneName ~= filterTable.zone
        if not filtered then
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

            local localInfo    = AQL:GetQuest(questID)
            local ci           = localInfo and localInfo.chainInfo or SocialQuestTabUtils.GetChainInfoForQuestID(questID)
            local localHasIt   = localInfo ~= nil

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
                chainInfo      = ci,
                objectives     = localInfo and localInfo.objectives or {},
                players        = buildPlayerRowsForQuest(questID, localHasIt),
            }

            if ci.knownStatus == AQL.ChainStatus.Known and ci.chainID then
                local chainID = ci.chainID
                if not zone.chains[chainID] then
                    zone.chains[chainID] = { title = entry.title, steps = {} }
                end
                if ci.step == 1 then
                    zone.chains[chainID].title = entry.title
                end
                table.insert(zone.chains[chainID].steps, entry)
            else
                table.insert(zone.quests, entry)
            end
        end
    end

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

-- Renders the Party tree into contentFrame using RowFactory.
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
    local tree = self:BuildTree(filterTable)
    local y    = 0

    local filterLabel = SocialQuestWindowFilter:GetFilterLabel(tabId)
    if filterLabel then
        y = rowFactory.AddFilterHeader(contentFrame, y, filterLabel, function()
            SocialQuestWindowFilter:Dismiss(tabId)
            SocialQuestGroupFrame:Refresh()
        end)
    end

    local sortedZones = {}
    for _, zone in pairs(tree.zones) do
        table.insert(sortedZones, zone)
    end
    table.sort(sortedZones, function(a, b) return a.order < b.order end)

    if #sortedZones > 0 then
        local zoneNames = {}
        for _, zone in ipairs(sortedZones) do table.insert(zoneNames, zone.name) end
        y = rowFactory.AddExpandCollapseHeader(contentFrame, y,
            function() SocialQuestGroupFrame:ExpandAll("party") end,
            function() SocialQuestGroupFrame:CollapseAll("party", zoneNames) end)
    end

    for _, zone in ipairs(sortedZones) do
        local zoneName    = zone.name
        local isCollapsed = tabCollapsedZones[zoneName] == true

        y = rowFactory.AddZoneHeader(contentFrame, y, zoneName, isCollapsed, function()
            SocialQuestGroupFrame:ToggleZone("party", zoneName)
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
                    for _, player in ipairs(entry.players) do
                        -- AddPlayerRow renders objectives internally; do not loop here.
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8)
                    end
                end
            end

            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                for _, player in ipairs(entry.players) do
                    -- AddPlayerRow renders objectives internally; do not loop here.
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT)
                end
            end
        end
    end

    return math.max(y, 10)
end
