-- UI/Tabs/PartyTab.lua
-- Party tab provider. Shows all quests across the party (quest-centric).
-- Each quest appears once; party members with relevant state appear beneath it.

PartyTab = {}

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

-- Returns zone name for a questID using local AQL cache; falls back to "Other Quests".
local function getZoneForQuestID(questID)
    local info = SocialQuest.AQL:GetQuest(questID)
    if info and info.zone then return info.zone end
    return "Other Quests"
end

-- Returns chainInfo for any questID; tries provider for remote quests.
local function getChainInfoForQuestID(questID)
    local AQL = SocialQuest.AQL
    local ci = AQL:GetChainInfo(questID)
    if ci.knownStatus == "known" then return ci end
    local provider = AQL.provider
    if provider then
        local ok, result = pcall(provider.GetChainInfo, provider, questID)
        if ok and result and result.knownStatus == "known" then return result end
    end
    return ci
end

-- Builds objective rows for the local player from AQL questInfo.
local function buildLocalObjectives(questInfo)
    local objs = {}
    for i, obj in ipairs(questInfo.objectives or {}) do
        objs[i] = {
            text         = obj.text or "",
            isFinished   = obj.isFinished,
            numFulfilled = obj.numFulfilled,
            numRequired  = obj.numRequired,
        }
    end
    return objs
end

-- Builds objective rows for a remote player from GroupData quest entry.
local function buildRemoteObjectives(pquest)
    local objs = {}
    for i, obj in ipairs(pquest.objectives or {}) do
        local text = tostring(obj.numFulfilled or 0) .. "/" .. tostring(obj.numRequired or 1)
        objs[i] = {
            text         = text,
            isFinished   = obj.isFinished,
            numFulfilled = obj.numFulfilled or 0,
            numRequired  = obj.numRequired  or 1,
        }
    end
    return objs
end

-- Builds the ordered list of playerEntry rows for one questID.
-- localHasIt: true when AQL:GetQuest(questID) is non-nil.
local function buildPlayerRowsForQuest(questID, localHasIt)
    local AQL     = SocialQuest.AQL
    local players = {}

    -- Local player row (always first when local player has any stake).
    local myInfo = AQL:GetQuest(questID)
    if myInfo then
        local ci = myInfo.chainInfo
        table.insert(players, {
            name           = "(You)",
            isMe           = true,
            hasSocialQuest = true,
            hasCompleted   = false,
            needsShare     = false,
            objectives     = buildLocalObjectives(myInfo),
            step           = ci and ci.knownStatus == "known" and ci.step       or nil,
            chainLength    = ci and ci.knownStatus == "known" and ci.length     or nil,
        })
    elseif AQL:HasCompletedQuest(questID) then
        table.insert(players, {
            name           = "(You)",
            isMe           = true,
            hasSocialQuest = true,
            hasCompleted   = true,
            needsShare     = false,
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
                objectives     = {},
            })
        elseif hasQuest then
            local pquest = playerData.quests[questID]
            local pCI    = getChainInfoForQuestID(questID)
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                needsShare     = false,
                objectives     = buildRemoteObjectives(pquest),
                step           = pCI.knownStatus == "known" and pCI.step   or nil,
                chainLength    = pCI.knownStatus == "known" and pCI.length or nil,
            })
        elseif localHasIt then
            -- Party member lacks the quest; local player has it → "Needs it Shared".
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                needsShare     = true,
                objectives     = {},
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
    return "Party"
end

-- Builds the zone/chain/quest tree from all party members + local player.
function PartyTab:BuildTree()
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
        local zoneName = getZoneForQuestID(questID)
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
        local ci           = localInfo and localInfo.chainInfo or getChainInfoForQuestID(questID)
        local localHasIt   = localInfo ~= nil

        local entry = {
            questID        = questID,
            title          = localInfo and localInfo.title or ("Quest " .. questID),
            level          = localInfo and localInfo.level or 0,
            zone           = zoneName,
            isComplete     = localInfo and localInfo.isComplete or false,
            isFailed       = localInfo and localInfo.isFailed   or false,
            isTracked      = false,
            logIndex       = localInfo and localInfo.logIndex,
            suggestedGroup = localInfo and localInfo.suggestedGroup or 0,
            timerSeconds   = localInfo and localInfo.timerSeconds,
            snapshotTime   = localInfo and localInfo.snapshotTime,
            wowheadUrl     = localInfo and localInfo.wowheadUrl
                             or ("https://www.wowhead.com/tbc/quest=" .. questID),
            chainInfo      = ci,
            objectives     = localInfo and localInfo.objectives or {},
            players        = buildPlayerRowsForQuest(questID, localHasIt),
        }

        if ci.knownStatus == "known" and ci.chainID then
            local chainID = ci.chainID
            if not zone.chains[chainID] then
                zone.chains[chainID] = { title = entry.title, steps = {} }
            end
            -- Prefer step-1 title as chain label (deterministic regardless of pairs() order).
            if ci.step == 1 then
                zone.chains[chainID].title = entry.title
            end
            table.insert(zone.chains[chainID].steps, entry)
        else
            table.insert(zone.quests, entry)
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
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones)
    local tree = self:BuildTree()
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
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8)
                        if not player.hasCompleted and not player.needsShare then
                            for _, obj in ipairs(player.objectives or {}) do
                                y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                            end
                        end
                    end
                end
            end

            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                for _, player in ipairs(entry.players) do
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT)
                    if not player.hasCompleted and not player.needsShare then
                        for _, obj in ipairs(player.objectives or {}) do
                            y = rowFactory.AddObjectiveRow(contentFrame, y, obj, OBJ_INDENT)
                        end
                    end
                end
            end
        end
    end

    return math.max(y, 10)
end
