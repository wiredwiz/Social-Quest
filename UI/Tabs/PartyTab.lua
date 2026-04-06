-- UI/Tabs/PartyTab.lua
-- Party tab provider. Shows all quests across the party (quest-centric).
-- Each quest appears once; party members with relevant state appear beneath it.

PartyTab = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

-- Scans "party1".."party4" to find the unit token for the given player name.
-- Normalises realm suffix (strips -RealmName) for same-realm matching.
-- Returns the token string ("party1", etc.) or nil if not matched (offline or unknown).
local function resolveUnitToken(playerName)
    local shortLookup = playerName:match("^([^%-]+)") or playerName
    for i = 1, 4 do
        local token = "party" .. i
        local unitName = SQWowAPI.UnitName(token)
        if unitName then
            local shortUnit = unitName:match("^([^%-]+)") or unitName
            if shortUnit == shortLookup or unitName == playerName then
                return token
            end
        end
    end
    return nil
end

-- Returns { eligible=true } or { eligible=false, reason={code=string, questID=N?} }.
-- Check 1 (AQL:IsQuestIdShareable) is evaluated ONCE outside this function in
-- buildPlayerRowsForQuest — do NOT repeat it here.
-- unitToken: "party1".."party4" or nil (nil when player is offline; skips checks 2-5).
-- Called only from the localHasIt==true branch after the shareable pre-check passes.
local function isEligibleForShare(questID, playerData, unitToken)
    local AQL = SocialQuest.AQL
    local reqs = AQL:GetQuestRequirements(questID)

    -- Checks 2-5 require a live unit token; skip for offline players.
    if unitToken then
        -- Check 2: wrong race.
        -- UnitRace returns (localizedName, englishName, raceID). The numeric raceID
        -- maps to Questie's requiredRaces bitmask via bit position 2^(raceID-1).
        if reqs and reqs.requiredRaces then
            local raceId = select(3, SQWowAPI.UnitRace(unitToken))
            if raceId and bit.band(reqs.requiredRaces, 2 ^ (raceId - 1)) == 0 then
                return { eligible = false, reason = { code = "wrong_race" } }
            end
        end

        -- Check 3: wrong class.
        -- UnitClass returns (localizedName, classToken, classID). The numeric classID
        -- maps to Questie's requiredClasses bitmask via bit position 2^(classID-1).
        if reqs and reqs.requiredClasses then
            local classId = select(3, SQWowAPI.UnitClass(unitToken))
            if classId and bit.band(reqs.requiredClasses, 2 ^ (classId - 1)) == 0 then
                return { eligible = false, reason = { code = "wrong_class" } }
            end
        end

        -- Check 4: level too low.
        if reqs and reqs.requiredLevel then
            local level = SQWowAPI.UnitLevel(unitToken)
            if level and level < reqs.requiredLevel then
                return { eligible = false, reason = { code = "level_too_low" } }
            end
        end

        -- Check 5: level too high.
        if reqs and reqs.requiredMaxLevel then
            local level = SQWowAPI.UnitLevel(unitToken)
            if level and level > reqs.requiredMaxLevel then
                return { eligible = false, reason = { code = "level_too_high" } }
            end
        end
    end

    -- Check 6: quest log full.
    local questCount = 0
    if playerData.quests then
        for _ in pairs(playerData.quests) do questCount = questCount + 1 end
    end
    if questCount >= SQWowAPI.MAX_QUEST_LOG_ENTRIES then
        return { eligible = false, reason = { code = "quest_log_full" } }
    end

    -- Checks 7-11 require provider data; skip gracefully when reqs is nil.
    if not reqs then
        return { eligible = true }
    end

    -- Check 7: exclusive quest already completed by this player.
    if reqs.exclusiveTo then
        for _, exID in ipairs(reqs.exclusiveTo) do
            if playerData.completedQuests and playerData.completedQuests[exID] then
                return { eligible = false, reason = { code = "exclusive_quest" } }
            end
        end
    end

    -- Check 8: player already has the next step in the chain (active or completed).
    if reqs.nextQuestInChain then
        local nq = reqs.nextQuestInChain
        if (playerData.quests and playerData.quests[nq]) or
           (playerData.completedQuests and playerData.completedQuests[nq]) then
            return { eligible = false, reason = { code = "already_advanced" } }
        end
    end

    -- Check 9: preQuestGroup — ALL of these questIDs must be in completedQuests.
    if reqs.preQuestGroup then
        for _, preID in ipairs(reqs.preQuestGroup) do
            if not (playerData.completedQuests and playerData.completedQuests[preID]) then
                return { eligible = false, reason = { code = "needs_quest", questID = preID } }
            end
        end
    end

    -- Check 10: preQuestSingle — ANY ONE of these questIDs must be in completedQuests.
    if reqs.preQuestSingle and #reqs.preQuestSingle > 0 then
        local anyDone = false
        for _, preID in ipairs(reqs.preQuestSingle) do
            if playerData.completedQuests and playerData.completedQuests[preID] then
                anyDone = true
                break
            end
        end
        if not anyDone then
            return { eligible = false, reason = { code = "needs_quest", questID = reqs.preQuestSingle[1] } }
        end
    end

    -- Check 11: breadcrumb quest already active or completed (player is past this breadcrumb).
    if reqs.breadcrumbForQuestId then
        local bq = reqs.breadcrumbForQuestId
        if (playerData.quests and playerData.quests[bq]) or
           (playerData.completedQuests and playerData.completedQuests[bq]) then
            return { eligible = false, reason = { code = "already_advanced" } }
        end
    end

    return { eligible = true }
end

-- Builds the ordered list of playerEntry rows for one questID.
-- localHasIt: true when AQL:GetQuest(questID) is non-nil.
local function buildPlayerRowsForQuest(questID, localHasIt)
    local AQL     = SocialQuest.AQL
    if not AQL then return {} end
    local players = {}

    -- Check 1: evaluate shareability ONCE for this quest, before the member loop.
    -- If false, the localHasIt branch is skipped entirely for all members.
    local shareable = localHasIt and AQL:IsQuestIdShareable(questID)

    -- Local player row (always first when local player has any stake).
    local myInfo = AQL:GetQuest(questID)
    if myInfo then
        local chainResult  = myInfo.chainInfo
        local localEngaged = SocialQuestTabUtils.BuildEngagedSet(nil)
        local ci = SocialQuestTabUtils.SelectChain(chainResult, localEngaged)
        table.insert(players, {
            name           = L["(You)"],
            isMe           = true,
            hasSocialQuest = true,
            hasCompleted   = false,
            needsShare     = false,
            isComplete     = myInfo.isComplete or false,
            objectives     = SocialQuestTabUtils.BuildLocalObjectives(myInfo),
            step           = ci and ci.step or nil,
            chainLength    = ci and ci.length or nil,
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
            local pquest      = playerData.quests[questID]
            local pChainResult = AQL:GetChainInfo(questID)
            local pCI = SocialQuestTabUtils.SelectChain(pChainResult, SocialQuestTabUtils.BuildEngagedSet(playerName))
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                needsShare     = false,
                isComplete     = pquest.isComplete or false,
                objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pquest, myInfo),
                step           = pCI and pCI.step or nil,
                chainLength    = pCI and pCI.length or nil,
                dataProvider   = playerData.dataProvider,
            })
        elseif shareable then
            -- Local player has the quest and it is shareable; show eligibility for this member.
            local eligResult = isEligibleForShare(questID, playerData, resolveUnitToken(playerName))
            table.insert(players, {
                name           = playerName,
                isMe           = false,
                hasSocialQuest = playerData.hasSocialQuest,
                hasCompleted   = false,
                isComplete     = false,
                needsShare     = eligResult.eligible,
                ineligReason   = eligResult.reason,
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

    local tree                = { zones = {} }
    local orderIdx            = 0
    local chainStepEntriesByZone = {}
    local questsByTitleByZone    = {}   -- zoneName → {title → entry} for ungrouped quest dedup
    local chainTitleToIDByZone   = {}   -- zoneName → {chainTitle → canonical chainID} for alias dedup

    -- Merges source players into target, deduplicating by player name.
    -- When a player appears in both lists, the entry with real quest data is
    -- preferred over a "needsShare" placeholder row (which is only added when
    -- the local player has a shareable quest and the remote player lacks it by
    -- exact-ID lookup — the variant case produces this false placeholder).
    local function mergePlayers(target, source)
        local byName = {}
        for i, p in ipairs(target) do
            byName[p.name] = i
        end
        for _, p in ipairs(source) do
            local idx = byName[p.name]
            if idx then
                -- Player already present. Prefer the entry with real quest data.
                if target[idx].needsShare and not p.needsShare then
                    target[idx] = p
                end
            else
                table.insert(target, p)
                byName[p.name] = #target
            end
        end
    end

    for questID in pairs(allQuestIDs) do
        local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID)
        local filtered = filterTable and filterTable.autoZone and zoneName ~= filterTable.autoZone
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
            local ci           = AQL:GetChainInfo(questID)
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

            -- Pre-compute shareability so Render's buildQuestCallbacks doesn't redo this work.
            entry.hasShareableMembers = false
            if entry.logIndex and AQL and AQL:IsQuestIdShareable(questID) then
                for _, pl in ipairs(entry.players) do
                    if pl.needsShare then entry.hasShareableMembers = true; break end
                end
            end

            if not chainStepEntriesByZone[zoneName] then chainStepEntriesByZone[zoneName] = {} end
            local chainStepEntries = chainStepEntriesByZone[zoneName]

            local buildEngaged = SocialQuestTabUtils.BuildEngagedSet(nil)
            local ciEntry = SocialQuestTabUtils.SelectChain(ci, buildEngaged)
            if ciEntry and ciEntry.chainID then
                local chainID = ciEntry.chainID
                if not zone.chains[chainID] then
                    -- chainID is always the questID of step 1; resolve its title for a
                    -- stable chain label regardless of which step the player is currently on.
                    local step1Info  = AQL:GetQuestInfo(chainID)
                    local chainTitle = (step1Info and step1Info.title) or entry.title
                    -- Alias normalization (Retail/MoP): if a chain with the same step-1 title
                    -- already exists under a different chainID (another alias), redirect so
                    -- all players merge into one chain block instead of two.
                    if SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP then
                        if not chainTitleToIDByZone[zoneName] then
                            chainTitleToIDByZone[zoneName] = {}
                        end
                        local canonID = chainTitleToIDByZone[zoneName][chainTitle]
                        if canonID then
                            chainID = canonID  -- redirect; zone.chains[canonID] already exists
                        else
                            chainTitleToIDByZone[zoneName][chainTitle] = chainID
                            zone.chains[chainID] = { title = chainTitle, steps = {} }
                        end
                    else
                        zone.chains[chainID] = { title = chainTitle, steps = {} }
                    end
                end
                if ciEntry.step then
                    if not chainStepEntries[chainID] then chainStepEntries[chainID] = {} end
                    local existing = chainStepEntries[chainID][ciEntry.step]
                    if existing then
                        -- Variant questID for an already-recorded step: merge players only.
                        for _, p in ipairs(entry.players) do
                            table.insert(existing.players, p)
                        end
                    else
                        -- First questID seen at this step: record and insert.
                        chainStepEntries[chainID][ciEntry.step] = entry
                        table.insert(zone.chains[chainID].steps, entry)
                    end
                else
                    table.insert(zone.chains[chainID].steps, entry)
                end
            else
                -- Ungrouped quest: group by title to merge Retail variant questIDs.
                -- (Non-chain quests with the same title are the same logical quest.)
                if not questsByTitleByZone[zoneName] then
                    questsByTitleByZone[zoneName] = {}
                end
                local titleKey  = entry.title
                local existing  = questsByTitleByZone[zoneName][titleKey]
                if existing then
                    mergePlayers(existing.players, entry.players)
                    -- Recompute hasShareableMembers — dedup may have removed needsShare rows.
                    existing.hasShareableMembers = false
                    for _, pl in ipairs(existing.players) do
                        if pl.needsShare then existing.hasShareableMembers = true; break end
                    end
                    -- Prefer the local player's entry data (logIndex, questID) for interactions.
                    if entry.logIndex and not existing.logIndex then
                        existing.questID    = entry.questID
                        existing.logIndex   = entry.logIndex
                        existing.isComplete = entry.isComplete
                        existing.isFailed   = entry.isFailed
                        existing.isTracked  = entry.isTracked
                    end
                else
                    questsByTitleByZone[zoneName][titleKey] = entry
                    table.insert(zone.quests, entry)
                end
            end
        end
    end

    -- Alias post-processing: on Retail and MoP Classic, an ungrouped entry whose title
    -- matches an existing chain step was produced by a variant questID that failed chain
    -- resolution. Merge its players into the matching step and remove it from zone.quests.
    if SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP then
        for _, zone in pairs(tree.zones) do
            if next(zone.quests) and next(zone.chains) then
                local remaining = {}
                for _, entry in ipairs(zone.quests) do
                    local merged = false
                    for _, searchZone in pairs(tree.zones) do
                        for _, chainEntry in pairs(searchZone.chains) do
                            for _, stepEntry in ipairs(chainEntry.steps) do
                                if stepEntry.title == entry.title then
                                    mergePlayers(stepEntry.players, entry.players)
                                    merged = true
                                    break
                                end
                            end
                            if merged then break end
                        end
                        if merged then break end
                    end
                    if not merged then table.insert(remaining, entry) end
                end
                zone.quests = remaining
            end
        end
    end

    -- Sort chain steps ascending.
    local sortEngaged = SocialQuestTabUtils.BuildEngagedSet(nil)
    for _, zone in pairs(tree.zones) do
        for _, chain in pairs(zone.chains) do
            table.sort(chain.steps, function(a, b)
                local aResult = a.chainInfo
                local bResult = b.chainInfo
                local aci = SocialQuestTabUtils.SelectChain(aResult, sortEngaged)
                local bci = SocialQuestTabUtils.SelectChain(bResult, sortEngaged)
                return (aci and aci.step or 0) < (bci and bci.step or 0)
            end)
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
            if ft.shareable and not T.MatchesEnumFilter(
                    entry.hasShareableMembers and "yes" or "no", ft.shareable) then
                return false
            end
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

-- Renders the Party tree into contentFrame using RowFactory.
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
    local tree = self:BuildTree(filterTable)
    local y    = 0

    -- Builds the callbacks table for a quest row. Adds onShare when:
    --   1. Local player has the quest (logIndex non-nil)
    --   2. Quest is shareable
    --   3. At least one party member has needsShare = true
    local function buildQuestCallbacks(entry)
        if not entry.hasShareableMembers then return {} end
        local AQL = SocialQuest.AQL
        return {
            onShare = function()
                -- Safety check: re-verify shareability at click time.
                if not AQL:IsQuestIdShareable(entry.questID) then return end
                local prev = AQL:GetQuestLogSelection()
                AQL:SetQuestLogSelection(entry.logIndex)
                SQWowAPI.QuestLogPushQuest(entry.questID)
                AQL:SetQuestLogSelection(prev)
            end,
        }
    end

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
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, buildQuestCallbacks(entry))
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
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, buildQuestCallbacks(entry))
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
