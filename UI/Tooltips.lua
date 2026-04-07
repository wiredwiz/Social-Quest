-- UI/Tooltips.lua
-- Quest tooltip enhancement. Two modes:
--   Enhance: appends party progress section to Questie's or WoW's existing tooltip.
--   Replace: renders SocialQuest's own full tooltip instead (configurable per link type).
-- SAFETY: all augmentation is wrapped in pcall so SQ errors never corrupt the
-- base WoW or Questie tooltip.

SocialQuestTooltips = {}

local L      = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

-- ---------------------------------------------------------------------------
-- resolveQuestData (unchanged)
-- ---------------------------------------------------------------------------

-- Returns qdata for the given questID from entry, or nil.
-- On Retail and MoP, falls back to a title-based scan to handle aliased quest IDs.
local function resolveQuestData(entry, questID, questTitle)
    if not entry or not entry.quests then return nil end
    if entry.quests[questID] then return entry.quests[questID] end
    if (SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP) and questTitle then
        for _, qdata in pairs(entry.quests) do
            if qdata and qdata.title == questTitle then return qdata end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- renderPartyProgress — shared helper used by both augment and replace paths
-- ---------------------------------------------------------------------------

-- Adds "Party progress:" lines to tooltip for all group members who have the quest.
-- Includes the blank separator line before the header.
-- Returns true if any party data was added, false otherwise.
-- Does NOT call tooltip:Show().
local function renderPartyProgress(tooltip, questID, includeSelf)
    -- Party-only gate: never augment in raid or BG.
    local inRaid  = SQWowAPI.IsInRaid()
    local inBG    = SQWowAPI.PARTY_CATEGORY_INSTANCE
                 and SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)
    local inParty = SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)
    if not inParty or inRaid or inBG then return false end

    local AQL = SocialQuest.AQL
    if not AQL then return false end

    local questTitle = AQL:GetQuestTitle(questID)
    local localObjs  = AQL:GetQuestObjectives(questID) or {}

    local localName, localRealm = SQWowAPI.UnitFullName("player")
    local localKey = (localName and localRealm)
                  and (localName .. "-" .. localRealm)
                  or  localName

    local hasAnyGroupData = false

    -- The local player is not in PlayerQuests (SQ stores remote members only).
    -- When includeSelf is true (SQ's own full tooltip), fetch from live AQL data.
    if includeSelf then
        local localQuestEntry = AQL:GetQuest(questID)
        if not localQuestEntry and (SQWowAPI.IS_RETAIL or SQWowAPI.IS_MOP) and questTitle then
            for _, q in pairs(AQL:GetAllQuests()) do
                if q.title == questTitle then localQuestEntry = q; break end
            end
        end
        if localQuestEntry then
            if not hasAnyGroupData then
                tooltip:AddLine(" ")
                tooltip:AddLine(L["Party progress"] .. ":")
                hasAnyGroupData = true
            end
            local line
            if localQuestEntry.isComplete then
                line = " - " .. (localName or "You") .. ": "
                       .. "|cFF40C040" .. L["Complete"] .. "|r"
            else
                local parts = {}
                for _, obj in ipairs(localQuestEntry.objectives or {}) do
                    local nf   = obj.numFulfilled or 0
                    local nr   = obj.numRequired  or 1
                    local text = obj.text
                    local desc = text and (
                        text:match("^(.-)%s*:%s*%d+/%d+%s*$")
                     or text:match("^%d+/%d+%s+(.+)$")
                    )
                    if desc and desc ~= "" then
                        table.insert(parts, desc .. ": " .. nf .. "/" .. nr)
                    else
                        table.insert(parts, nf .. "/" .. nr)
                    end
                end
                local status = #parts > 0 and table.concat(parts, "; ") or L["In Progress"]
                line = " - " .. (localName or "You") .. ": " .. status
            end
            tooltip:AddLine(line, 1, 1, 1)
        end
    end

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if localKey and playerName == localKey then
            -- Skip local player (not in PlayerQuests in practice; guard for safety).
        else
            local qdata = resolveQuestData(entry, questID, questTitle)
            if qdata then
                if not hasAnyGroupData then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(L["Party progress"] .. ":")
                    hasAnyGroupData = true
                end

                local line
                if not entry.hasSocialQuest then
                    line = " - " .. playerName .. ": " .. L["(shared, no data)"]
                elseif qdata.isComplete then
                    line = " - " .. playerName .. ": "
                           .. "|cFF40C040" .. L["Complete"] .. "|r"
                else
                    local parts = {}
                    for i, obj in ipairs(qdata.objectives or {}) do
                        local nf       = obj.numFulfilled or 0
                        local nr       = obj.numRequired  or 1
                        local localObj = localObjs[i]
                        local text     = localObj and localObj.text
                        local desc
                        if text then
                            desc = text:match("^(.-)%s*:%s*%d+/%d+%s*$")
                                or text:match("^%d+/%d+%s+(.+)$")
                        end
                        if desc and desc ~= "" then
                            table.insert(parts, desc .. ": " .. nf .. "/" .. nr)
                        else
                            table.insert(parts, nf .. "/" .. nr)
                        end
                    end
                    local status = #parts > 0
                        and table.concat(parts, "; ")
                        or  L["In Progress"]
                    line = " - " .. playerName .. ": " .. status
                end

                tooltip:AddLine(line, 1, 1, 1)
            end
        end
    end

    return hasAnyGroupData
end

-- ---------------------------------------------------------------------------
-- addGroupProgressToTooltip — augment path (called when Replace is OFF)
-- ---------------------------------------------------------------------------

local function addGroupProgressToTooltip(tooltip, questID)
    local ok, err = pcall(function()
        local hasData = renderPartyProgress(tooltip, questID)
        if hasData then tooltip:Show() end
    end)
    if not ok then
        SocialQuest:Debug("Banner", "Tooltip augment error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- BuildTooltip helpers
-- ---------------------------------------------------------------------------

-- Determines the status line for the tooltip. Returns text, r, g, b or nil.
-- Checks: active quest → completed quest → heuristic eligibility.
local function buildStatusLine(questID, questInfo, AQL)
    local title = questInfo.title

    -- On this quest? (exact match or alias title scan)
    if AQL:GetQuest(questID) then
        return L["You are on this quest"], 0.25, 1, 0.25
    end
    if title then
        for _, q in pairs(AQL:GetAllQuests()) do
            if q.title == title then
                return L["You are on this quest"], 0.25, 1, 0.25
            end
        end
    end

    -- Already completed? (exact match or title scan of history)
    if AQL:HasCompletedQuest(questID) then
        return L["You have completed this quest"], 0.25, 1, 0.25
    end
    if title then
        for cqID in pairs(AQL:GetCompletedQuests()) do
            local cqTitle = AQL:GetQuestTitle(cqID)
            if cqTitle == title then
                return L["You have completed this quest"], 0.25, 1, 0.25
            end
        end
    end

    -- Heuristic eligibility: only when a provider has requirements data.
    local reqs = AQL:GetQuestRequirements(questID)
    if not reqs then
        -- NullProvider or quest completely unknown — show nothing.
        return nil
    end

    -- Check level, race, class.
    local playerLevel = AQL:GetPlayerLevel()
    if reqs.requiredLevel and playerLevel < reqs.requiredLevel then
        return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
    end
    if reqs.requiredMaxLevel and reqs.requiredMaxLevel > 0
       and playerLevel > reqs.requiredMaxLevel then
        return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
    end
    if reqs.requiredRaces and reqs.requiredRaces ~= 0 then
        local _, _, raceID = SQWowAPI.UnitRace("player")
        if raceID and bit.band(reqs.requiredRaces, bit.lshift(1, raceID - 1)) == 0 then
            return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
        end
    end
    if reqs.requiredClasses and reqs.requiredClasses ~= 0 then
        local _, _, classID = SQWowAPI.UnitClass("player")
        if classID and bit.band(reqs.requiredClasses, bit.lshift(1, classID - 1)) == 0 then
            return L["You are not eligible for this quest"], 0.6, 0.6, 0.6
        end
    end

    return L["You are eligible for this quest"], 1, 1, 1
end


-- ---------------------------------------------------------------------------
-- BuildTooltip — full SQ tooltip renderer
-- ---------------------------------------------------------------------------

-- Renders a complete quest tooltip on `tooltip` for the given questID.
-- Uses AQL:GetQuestInfo for all fields, including Details capability fields
-- (description, starterNPC, starterZone, finisherNPC, finisherZone, isDungeon, isRaid, isGroup).
-- Sets tooltip._sqTooltipBuilt = true and calls tooltip:Show().
-- tooltip._sqTooltipBuilt is cleared by an OnHide hook registered in Initialize().
function SocialQuestTooltips:BuildTooltip(tooltip, questID)
    local ok, err = pcall(function()
        local AQL = SocialQuest.AQL
        if not AQL then return end

        local questInfo = AQL:GetQuestInfo(questID)
        if not questInfo then return end

        -- GetQuestInfo Tier 1 (cache path) returns the raw cache entry, which has no
        -- description, NPC info, or type-badge fields — those come from GetQuestDetails.
        -- Merge them in when missing so BuildTooltip always has the full set of fields.
        if questInfo.description == nil then
            local details = AQL:GetQuestDetails(questID)
            if details then
                local merged = {}
                for k, v in pairs(questInfo) do merged[k] = v end
                merged.description  = details.description
                merged.starterNPC   = details.starterNPC
                merged.starterZone  = details.starterZone
                merged.finisherNPC  = details.finisherNPC
                merged.finisherZone = details.finisherZone
                merged.isDungeon    = details.isDungeon
                merged.isRaid       = details.isRaid
                if details.isDungeon or details.isRaid then
                    merged.isGroup = true
                end
                questInfo = merged
            end
        end

        tooltip:ClearLines()

        -- 1. Title line: "Title [level]  <SQ badge>" left, "(Dungeon)"/"(Raid)"/"(Group N+)" right.
        local title = questInfo.title or ("Quest " .. questID)
        local level = questInfo.level
        local levelBadge = level and (" [" .. level .. "]") or ""
        local titleLeft = title .. levelBadge .. "  |TInterface/AddOns/SocialQuest/Logo.png:14:14|t"

        local sg = questInfo.suggestedGroup and questInfo.suggestedGroup > 0 and questInfo.suggestedGroup
        local typeBadge
        if questInfo.isDungeon then
            typeBadge = L["(Dungeon)"]
        elseif questInfo.isRaid then
            typeBadge = L["(Raid)"]
        elseif questInfo.isGroup or sg then
            typeBadge = sg and string.format(L["(Group %d+)"], sg) or L["(Group)"]
        end

        if typeBadge then
            tooltip:AddDoubleLine(titleLeft, typeBadge, 1, 0.82, 0, 0.4, 0.8, 1.0)
        else
            tooltip:AddLine(titleLeft, 1, 0.82, 0)
        end

        -- 1b. Chain line: "<Chain Name> (Step x of y)" when provider has chain data.
        local chainResult = AQL:GetChainInfo(questID)
        if chainResult and chainResult.knownStatus == AQL.ChainStatus.Known then
            local chain = AQL:SelectBestChain(chainResult, { [questID] = true })
            if chain and chain.step and chain.length and chain.length > 1 then
                local s1 = chain.steps and chain.steps[1]
                local chainName = (s1 and s1.title)
                               or (s1 and s1.quests and s1.quests[1] and s1.quests[1].title)
                               or AQL:GetQuestTitle(chain.chainID)
                if chainName then
                    tooltip:AddLine(chainName .. string.format(L[" (Step %s of %s)"], chain.step, chain.length), 0.4, 0.7, 1.0)
                end
            end
        end

        -- 2. Status line (alias-aware).
        local statusText, sR, sG, sB = buildStatusLine(questID, questInfo, AQL)
        if statusText then
            tooltip:AddLine(statusText, sR, sG, sB)
        end

        -- 3. Location line.
        if questInfo.zone then
            tooltip:AddLine(L["Location:"] .. " " .. questInfo.zone, 1, 1, 1)
        end

        -- 4. Description (Questie only; nil when not available).
        if questInfo.description then
            tooltip:AddLine(" ")
            tooltip:AddLine(questInfo.description, 1, 1, 1, true)  -- true = wrap
        end

        -- 5. NPC lines (Questie + Grail).
        local hasNPC = questInfo.starterNPC or questInfo.finisherNPC
        if hasNPC then
            tooltip:AddLine(" ")
            if questInfo.starterNPC then
                local giverLine = L["Quest Giver:"] .. " " .. questInfo.starterNPC
                if questInfo.starterZone then
                    giverLine = giverLine .. ", " .. questInfo.starterZone
                end
                tooltip:AddLine(giverLine, 1, 1, 1)
            end
            if questInfo.finisherNPC then
                local turnInLine = L["Turn In:"] .. " " .. questInfo.finisherNPC
                if questInfo.finisherZone then
                    turnInLine = turnInLine .. ", " .. questInfo.finisherZone
                end
                tooltip:AddLine(turnInLine, 1, 1, 1)
            end
        end

        -- 6. Party progress section — include self since we own the full tooltip.
        renderPartyProgress(tooltip, questID, true)

        -- 7. Mark built and show.
        tooltip._sqTooltipBuilt = true
        tooltip:Show()
    end)
    if not ok then
        SocialQuest:Debug("Banner", "BuildTooltip error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Initialize — register all hooks
-- ---------------------------------------------------------------------------

function SocialQuestTooltips:Initialize()
    -- New wire format: [[level] Quest Name {questID}] — curly braces avoid Questie collision.
    local SQ_LINK_PATTERN = "%[%[(%d+)%]%s(.-)%s*{(%d+)}%]"
    -- Legacy wire format: [[level] Quest Name (questID)] — for backward compat with old SQ clients.
    -- Only applied when Questie is not installed.
    local SQ_LINK_PATTERN_LEGACY = "%[%[(%d+)%]%s(.-)%s*%((%d+)%)%]"
    local function sqChatFilter(_, _, msg, ...)
        if not msg then return end
        local function convert(levelStr, name, questIDStr)
            local level   = tonumber(levelStr) or 0
            local questID = tonumber(questIDStr)
            if not questID then return end
            return "|cffffff00|Hsocialquest:" .. questID .. ":" .. level
                   .. "|h[" .. level .. "] " .. name .. "|h|r"
        end
        local newMsg = msg:gsub(SQ_LINK_PATTERN, convert)
        -- Legacy fallback: only when Questie is absent (Questie handles its own (questID) format).
        if newMsg == msg and not QuestieLoader then
            newMsg = msg:gsub(SQ_LINK_PATTERN_LEGACY, convert)
        end
        if newMsg ~= msg then
            return false, newMsg, ...
        end
    end
    local SQ_FILTER_EVENTS = {
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    }
    for _, event in ipairs(SQ_FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, sqChatFilter)
    end

    -- SetItemRef hook: fires when the player clicks a |Hsocialquest:| link.
    -- Calls BuildTooltip directly — no routing through questie:/quest: links.
    hooksecurefunc("SetItemRef", function(link, text, button)
        local ok, err = pcall(function()
            if not link then return end
            local linkType, qidStr = strsplit(":", link)
            if linkType ~= "socialquest" then return end
            local questID = tonumber(qidStr)
            if not questID then return end
            ShowUIPanel(ItemRefTooltip)
            ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
            SocialQuestTooltips:BuildTooltip(ItemRefTooltip, questID)
        end)
        if not ok then
            SocialQuest:Debug("Banner", "SetItemRef hook error: " .. tostring(err))
        end
    end)

    -- SetHyperlink hook: handles quest: and questie: links.
    -- Replace mode: ClearLines() + BuildTooltip (all versions).
    -- Enhance mode on non-Retail: addGroupProgressToTooltip.
    -- Enhance mode on Retail: handled by TooltipDataProcessor below.
    if ItemRefTooltip then
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local db = SocialQuest.db and SocialQuest.db.profile
            if not db then return end

            local questID = tonumber(link:match("^quest:(%d+)"))
            if questID then
                if db.tooltips.replaceBlizzard then
                    self:ClearLines()
                    SocialQuestTooltips:BuildTooltip(self, questID)
                elseif db.tooltips.enhance and not SQWowAPI.IS_RETAIL then
                    addGroupProgressToTooltip(self, questID)
                end
                return
            end

            questID = tonumber(link:match("^questie:(%d+)"))
            if questID then
                if db.tooltips.replaceQuestie then
                    self:ClearLines()
                    SocialQuestTooltips:BuildTooltip(self, questID)
                elseif db.tooltips.enhance and not SQWowAPI.IS_RETAIL then
                    addGroupProgressToTooltip(self, questID)
                end
                return
            end
        end)

        -- Clear _sqTooltipBuilt when the tooltip hides so future tooltip calls are not blocked.
        ItemRefTooltip:HookScript("OnHide", function(self)
            self._sqTooltipBuilt = nil
        end)
    end

    if SQWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        -- Retail: native tooltip data processor fires after WoW populates quest tooltips.
        -- Skipped when BuildTooltip already ran via the SetHyperlink hook (Replace mode).
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if tooltip._sqTooltipBuilt then return end
                local db = SocialQuest.db and SocialQuest.db.profile
                if not db or not db.tooltips.enhance then return end
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )
    end
end
