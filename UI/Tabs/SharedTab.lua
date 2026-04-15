-- UI/Tabs/SharedTab.lua
-- Shared tab provider. Shows quests engaged by 2+ players (chain-peer aware).
-- "Engaged" = has questID in active log OR is on a different step of the same chain.
-- No FINISHED or Needs-it-Shared rows on this tab.

SharedTab = {}

local L      = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

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
    local chainTitleToID = {}  -- chainTitle → canonical chainID, for alias normalization

    -- Objectives fingerprint: "count:req1,req2,..." built from numRequired values.
    -- Used as a secondary alias-matching key when quest titles are unresolvable (e.g. a
    -- remote alias questID on MoP Classic that is not in the local log and has no provider).
    -- Returns nil when there are no numeric objectives (avoids false positives on talk/travel quests).
    local function buildObjSig(objectives)
        if not objectives or #objectives == 0 then return nil end
        local parts = {}
        for _, obj in ipairs(objectives) do
            table.insert(parts, tostring(obj.numRequired or 0))
        end
        return #parts .. ":" .. table.concat(parts, ",")
    end

    local function addEngagement(questID, playerName, isLocal, qdata)
        local chainResult = AQL:GetChainInfo(questID)
        local engaged = SocialQuestTabUtils.BuildEngagedSet(isLocal and nil or playerName)
        local ciEntry = SocialQuestTabUtils.SelectChain(chainResult, engaged)
        if ciEntry and ciEntry.chainID then
            local cid = ciEntry.chainID
            -- Alias normalization (Retail/MoP): redirect to canonical chainID when a chain
            -- with the same step-1 title already exists under a different alias chainID.
            if SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP then
                local step1Info  = AQL:GetQuestInfo(cid)
                local chainTitle = step1Info and step1Info.title
                if chainTitle then
                    local canonID = chainTitleToID[chainTitle]
                    if canonID then
                        cid = canonID
                    else
                        chainTitleToID[chainTitle] = cid
                    end
                end
            end
            if not chainEngaged[cid] then chainEngaged[cid] = {} end
            chainEngaged[cid][playerName] = {
                questID     = questID,
                step        = ciEntry.step,
                chainLength = ciEntry.length,
                isLocal     = isLocal,
                qdata       = qdata,
            }
        else
            -- Alias fallback: on Retail and MoP Classic, quest aliases produce different
            -- questIDs for the same logical quest. If chain resolution failed, check whether
            -- a chain already established by another player's alias has the same title.
            -- Local player quests are always processed before remote (see call order below),
            -- so the chain entry will exist by the time the remote alias is processed.
            if SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP then
                local myTitle = (qdata and qdata.title) or AQL:GetQuestTitle(questID)
                if myTitle then
                    for cid, cEntries in pairs(chainEngaged) do
                        for _, eng in pairs(cEntries) do
                            if AQL:GetQuestTitle(eng.questID) == myTitle then
                                if not chainEngaged[cid][playerName] then
                                    chainEngaged[cid][playerName] = {
                                        questID     = questID,
                                        step        = eng.step,
                                        chainLength = eng.chainLength,
                                        isLocal     = isLocal,
                                        qdata       = qdata,
                                    }
                                end
                                return
                            end
                        end
                    end
                else
                    -- Title unavailable (e.g. remote alias questID on MoP Classic not in
                    -- the local log with no provider coverage). Fall back to objectives
                    -- fingerprint: same numRequired pattern = same logical quest.
                    local mySig = buildObjSig(qdata and qdata.objectives)
                    if mySig then
                        for cid, cEntries in pairs(chainEngaged) do
                            for _, eng in pairs(cEntries) do
                                local engInfo = AQL:GetQuest(eng.questID) or eng.qdata
                                local engSig  = buildObjSig(engInfo and engInfo.objectives)
                                if engSig == mySig then
                                    if not chainEngaged[cid][playerName] then
                                        chainEngaged[cid][playerName] = {
                                            questID     = questID,
                                            step        = eng.step,
                                            chainLength = eng.chainLength,
                                            isLocal     = isLocal,
                                            qdata       = qdata,
                                        }
                                    end
                                    return
                                end
                            end
                        end
                    end
                end
            end
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

    -- Merge questEngaged entries for alias questIDs (Retail/MoP): same logical quest,
    -- different numeric IDs per race/class character type. Two-phase approach:
    -- Phase 1: questIDs with resolvable titles become canonical entries. Build a title map
    --   and an objectives-sig map so Phase 2 can merge by fingerprint.
    -- Phase 2: questIDs whose title cannot be resolved (remote alias on MoP with no provider)
    --   are merged into canonical entries by objectives fingerprint.
    -- Chain-grouped quests are already deduplicated by chainEngaged (step-number keying),
    -- so this pass only affects non-chain quests in questEngaged.
    do
        local mergedQuestEngaged = {}
        local questEngagedByTitle = {}
        local questEngagedBySig   = {}  -- objectives sig → canonical questID

        -- Phase 1: questIDs with resolvable titles become canonical entries.
        for questID, engaged in pairs(questEngaged) do
            local title = AQL:GetQuestTitle(questID)
            if title then
                local canonID = questEngagedByTitle[title]
                if canonID then
                    for playerName, eng in pairs(engaged) do
                        if not mergedQuestEngaged[canonID][playerName] then
                            mergedQuestEngaged[canonID][playerName] = eng
                        end
                    end
                else
                    questEngagedByTitle[title]  = questID
                    mergedQuestEngaged[questID] = engaged
                    if SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP then
                        -- Index this entry's objectives sig for Phase 2 alias matching.
                        local info = AQL:GetQuest(questID)
                        local sig  = buildObjSig(info and info.objectives)
                        if sig and not questEngagedBySig[sig] then
                            questEngagedBySig[sig] = questID
                        end
                    end
                end
            end
        end

        -- Phase 2: questIDs without resolvable titles — try objectives fingerprint fallback.
        for questID, engaged in pairs(questEngaged) do
            if not AQL:GetQuestTitle(questID) then
                local canonID
                if SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP then
                    for _, eng in pairs(engaged) do
                        local sig = buildObjSig(eng.qdata and eng.qdata.objectives)
                        if sig then
                            canonID = questEngagedBySig[sig]
                            break
                        end
                    end
                end
                if canonID then
                    for playerName, eng in pairs(engaged) do
                        if not mergedQuestEngaged[canonID][playerName] then
                            mergedQuestEngaged[canonID][playerName] = eng
                        end
                    end
                else
                    -- No match found; keep as a standalone entry with a fallback display key.
                    mergedQuestEngaged[questID] = engaged
                end
            end
        end

        questEngaged = mergedQuestEngaged
    end

    -- Build questID → classID lookup from remote players' quest entries.
    -- Used by GetZoneForQuestID to resolve class-name zone headers for remote
    -- players' class quests.
    local questClassIDs = {}
    for _, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerData.quests then
            for questID, qentry in pairs(playerData.quests) do
                if qentry.classID and not questClassIDs[questID] then
                    questClassIDs[questID] = qentry.classID
                end
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
                    -- chainID is always the questID of step 1; resolve its title for a
                    -- stable chain label regardless of which step any player is currently on.
                    local step1Info  = AQL:GetQuestInfo(chainID)
                    local chainTitle = (step1Info and step1Info.title) or ("Chain " .. chainID)
                    zone.chains[chainID] = { title = chainTitle, steps = {} }
                end

                -- One questEntry per distinct questID in the chain.
                local addedQuestIDs   = {}
                local chainStepEntries = {}
                for playerName, eng in pairs(engaged) do
                    if not addedQuestIDs[eng.questID] then
                        addedQuestIDs[eng.questID] = true
                        local localInfo = AQL:GetQuest(eng.questID)
                        local ci = AQL:GetChainInfo(eng.questID)

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

                        if not chainStepEntries[chainID] then chainStepEntries[chainID] = {} end
                        local existing = chainStepEntries[chainID][eng.step]
                        if existing then
                            for _, p in ipairs(entry.players) do
                                table.insert(existing.players, p)
                            end
                        else
                            chainStepEntries[chainID][eng.step] = entry
                            table.insert(zone.chains[chainID].steps, entry)
                        end
                    end
                end

                -- Sort steps ascending. Inside the guard: zone.chains[chainID] only exists here.
                local sortEngaged = SocialQuestTabUtils.BuildEngagedSet(nil)
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
            local zoneName  = SocialQuestTabUtils.GetZoneForQuestID(questID, questClassIDs[questID])
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
        local sortEngaged = SocialQuestTabUtils.BuildEngagedSet(nil)

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

        local questCount = #zone.quests
        for _, chain in pairs(zone.chains) do
            questCount = questCount + #chain.steps
        end
        local headerLabel = SocialQuest.db.profile.window.zoneQuestCount
            and (zoneName .. " (" .. questCount .. ")")
            or zoneName

        y = rowFactory.AddZoneHeader(contentFrame, y, headerLabel, isCollapsed, function()
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
