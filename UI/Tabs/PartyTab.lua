-- UI/Tabs/PartyTab.lua
-- Party tab provider. Shows all quests across the party (quest-centric).
-- Each quest appears once; party members with relevant state appear beneath it.

PartyTab = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

-- Maps UnitRace() second return value (English race string) to Questie requiredRaces bitmask bits.
-- "Scourge" is the English race file name for Undead in TBC.
-- Goblin (256) included as a stub: follows the sequential raceKeys pattern (index 9 → bit 256).
-- Post-Cataclysm allied races (Worgen, Pandaren, Nightborne, etc.) are intentionally absent:
-- their bitmask values in the retail Questie DB are non-contiguous and unverified — including
-- wrong values would produce incorrect eligibility results. Add them when retail support is
-- implemented and the values are confirmed. Missing entries are gracefully skipped (nil check).
local RACE_BITS = {
    ["Human"]    = 1,
    ["Orc"]      = 2,
    ["Dwarf"]    = 4,
    ["NightElf"] = 8,
    ["Scourge"]  = 16,   -- UnitRace returns "Scourge" for Undead
    ["Tauren"]   = 32,
    ["Gnome"]    = 64,
    ["Troll"]    = 128,
    ["Goblin"]   = 256,  -- Cataclysm; stub for future retail support
    ["BloodElf"] = 512,
    ["Draenei"]  = 1024,
}

-- Maps UnitClass() second return value (English class token) to Questie requiredClasses bitmask bits.
-- All 13 classes included. DK/Monk/DemonHunter/Evoker are stubs for future retail support:
-- UnitClass never returns their tokens in TBC so these entries are unreachable and harmless.
local CLASS_BITS = {
    ["WARRIOR"]     = 1,
    ["PALADIN"]     = 2,
    ["HUNTER"]      = 4,
    ["ROGUE"]       = 8,
    ["PRIEST"]      = 16,
    ["DEATHKNIGHT"] = 32,    -- WotLK; stub for retail support
    ["SHAMAN"]      = 64,
    ["MAGE"]        = 128,
    ["WARLOCK"]     = 256,
    ["MONK"]        = 512,   -- MoP; stub for retail support
    ["DRUID"]       = 1024,
    ["DEMONHUNTER"] = 2048,  -- Legion; stub for retail support
    ["EVOKER"]      = 4096,  -- Dragonflight; stub for retail support
}

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
        if reqs and reqs.requiredRaces then
            local _, raceEn = SQWowAPI.UnitRace(unitToken)
            local raceBit = raceEn and RACE_BITS[raceEn]
            if raceBit and bit.band(reqs.requiredRaces, raceBit) == 0 then
                return { eligible = false, reason = { code = "wrong_race" } }
            end
        end

        -- Check 3: wrong class.
        -- CLASS_BITS includes all retail classes as stubs; DK/Monk/DH/Evoker never
        -- match in TBC since UnitClass never returns those tokens there.
        if reqs and reqs.requiredClasses then
            local _, classToken = SQWowAPI.UnitClass(unitToken)
            local classBit = classToken and CLASS_BITS[classToken]
            if classBit and bit.band(reqs.requiredClasses, classBit) == 0 then
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

    -- Check 6: quest log full (TBC cap is 25 quests).
    local questCount = 0
    if playerData.quests then
        for _ in pairs(playerData.quests) do questCount = questCount + 1 end
    end
    if questCount >= 25 then
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

    local tree     = { zones = {} }
    local orderIdx = 0

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
            if ft.step   and not T.MatchesNumericFilter(
                    entry.chainInfo and entry.chainInfo.step, ft.step)          then return false end
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

-- Renders the Party tree into contentFrame using RowFactory.
function PartyTab:Render(contentFrame, rowFactory, tabCollapsedZones, filterTable, tabId)
    local tree = self:BuildTree(filterTable)
    local y    = 0

    -- Builds the callbacks table for a quest row. Adds onShare when:
    --   1. Local player has the quest (logIndex non-nil)
    --   2. Quest is shareable
    --   3. At least one party member has needsShare = true
    local function buildQuestCallbacks(entry)
        local AQL = SocialQuest.AQL
        if not entry.logIndex then return {} end
        if not AQL:IsQuestIdShareable(entry.questID) then return {} end
        local hasEligible = false
        for _, p in ipairs(entry.players) do
            if p.needsShare then hasEligible = true break end
        end
        if not hasEligible then return {} end
        return {
            onShare = function()
                -- Safety check: re-verify shareability at click time.
                if not AQL:IsQuestIdShareable(entry.questID) then return end
                local prev = AQL:GetQuestLogSelection()
                AQL:SetQuestLogSelection(entry.logIndex)
                SQWowAPI.QuestLogPushQuest()
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
