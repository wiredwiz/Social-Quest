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
function SharedTab:BuildTree()
    local AQL = SocialQuest.AQL
    if not AQL then return { zones = {} } end

    -- Step 1: gather all engagements.
    -- chainEngaged[chainID][playerName] = { questID, step, chainLength, isLocal, qdata }
    -- questEngaged[questID][playerName] = { isLocal, qdata }
    local chainEngaged = {}
    local questEngaged = {}

    local function addEngagement(questID, playerName, isLocal, qdata)
        local ci = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
        if ci.knownStatus == "known" and ci.chainID then
            local cid = ci.chainID
            if not chainEngaged[cid] then chainEngaged[cid] = {} end
            chainEngaged[cid][playerName] = {
                questID     = questID,
                step        = ci.step,
                chainLength = ci.length,
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
                    -- `ci` was computed two lines above for this same questID.
                    if localInfo and localInfo.title and ci.step == 1 then
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
                                })
                            end
                        end
                    end

                    table.insert(zone.chains[chainID].steps, entry)
                end
            end

            -- Sort steps ascending.
            table.sort(zone.chains[chainID].steps, function(a, b)
                local aS = a.chainInfo and a.chainInfo.step or 0
                local bS = b.chainInfo and b.chainInfo.step or 0
                return aS < bS
            end)
        end
    end

    -- Process standalone quest groups.
    for questID, engaged in pairs(questEngaged) do
        local count = 0
        for _ in pairs(engaged) do count = count + 1 end
        if count >= 2 then
            local zoneName  = SocialQuestTabUtils.GetZoneForQuestID(questID)
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
                chainInfo      = { knownStatus = "unknown" },
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
                    })
                end
            end

            table.insert(zone.quests, entry)
        end
    end

    return tree
end

-- Renders the Shared tree into contentFrame using RowFactory.
function SharedTab:Render(contentFrame, rowFactory, tabCollapsedZones)
    local tree = self:BuildTree()
    local y    = 0

    local sortedZones = {}
    for _, zone in pairs(tree.zones) do
        table.insert(sortedZones, zone)
    end
    table.sort(sortedZones, function(a, b) return a.order < b.order end)

    if #sortedZones > 0 then
        local zoneNames = {}
        for _, zone in ipairs(sortedZones) do table.insert(zoneNames, zone.name) end
        y = rowFactory.AddExpandCollapseHeader(contentFrame, y,
            function() SocialQuestGroupFrame:ExpandAll("shared") end,
            function() SocialQuestGroupFrame:CollapseAll("shared", zoneNames) end)
    end

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
