-- UI/TabUtils.lua
-- Shared utility functions for MineTab, PartyTab, and SharedTab providers.
-- Also consumed by RowFactory (WowheadUrl).

SocialQuestTabUtils = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

local WOWHEAD_QUEST_BASE = "https://www.wowhead.com/tbc/quest="

-- Builds the Wowhead quest URL from a questID.
-- Single owner of the URL format so it never gets out of sync with stored data.
function SocialQuestTabUtils.WowheadUrl(questID)
    return WOWHEAD_QUEST_BASE .. tostring(questID)
end

-- Returns zone name for a questID.
-- Falls back from active-quest cache → AQL:GetQuestInfo (which includes provider lookup)
-- → "Other Quests". The provider fallback resolves zone for remote-only quests (quests
-- a party member has that the local player does not).
function SocialQuestTabUtils.GetZoneForQuestID(questID)
    local AQL = SocialQuest.AQL
    -- Fast path: active quest cache.
    local info = AQL:GetQuest(questID)
    if info and info.zone then return info.zone end
    -- Slow path: three-tier resolution (cache → WoW log → provider).
    local fullInfo = AQL:GetQuestInfo(questID)
    if fullInfo and fullInfo.zone then return fullInfo.zone end
    return L["Other Quests"]
end

-- Returns chainInfo for any questID; queries the provider for remote quests
-- not present in the local quest log.
function SocialQuestTabUtils.GetChainInfoForQuestID(questID)
    local AQL = SocialQuest.AQL
    local ci  = AQL:GetChainInfo(questID)
    if ci.knownStatus == AQL.ChainStatus.Known then return ci end
    local provider = AQL.provider
    if provider then
        local ok, result = pcall(provider.GetChainInfo, provider, questID)
        if ok and result and result.knownStatus == AQL.ChainStatus.Known then return result end
    end
    return ci
end

-- Builds objective rows for the local player from an AQL questInfo snapshot.
function SocialQuestTabUtils.BuildLocalObjectives(questInfo)
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

-- Builds objective rows for a remote player from a GroupData quest entry.
-- localInfo: optional AQL quest info for the same quest; used to supply
--            objective text, which is never transmitted over the wire.
-- When localInfo is nil (local player doesn't have the quest), falls back to
-- AQL:GetQuestObjectives — same backing data but an explicit API call that may
-- succeed in cases where the caller's GetQuest snapshot was not yet populated.
-- If objective text is unavailable from either source, displays count-only (e.g. "3/8").
function SocialQuestTabUtils.BuildRemoteObjectives(pquest, localInfo)
    local AQL = SocialQuest.AQL
    local localObjs = (localInfo and localInfo.objectives)
                   or (AQL and AQL:GetQuestObjectives(pquest.questID))
                   or {}
    local objs = {}
    for i, obj in ipairs(pquest.objectives or {}) do
        local localObj = localObjs[i]
        local text
        if localObj and localObj.text and localObj.text ~= "" then
            -- WoW objective text is "Description: X/Y". Strip the local player's
            -- embedded count and substitute the remote player's values so the bar
            -- overlay shows "6/8" instead of "0/8" when the local player is at 0.
            local baseName = localObj.text:match("^(.-)%s*:%s*%d+/%d+%s*$")
            if baseName then
                text = baseName .. ": " .. tostring(obj.numFulfilled or 0) .. "/" .. tostring(obj.numRequired or 1)
            else
                text = localObj.text  -- event/NPC objectives with no count; use as-is
            end
        else
            text = tostring(obj.numFulfilled or 0) .. "/" .. tostring(obj.numRequired or 1)
        end
        objs[i] = {
            text         = text,
            isFinished   = obj.isFinished,
            numFulfilled = obj.numFulfilled or 0,
            numRequired  = obj.numRequired  or 1,
        }
    end
    return objs
end

------------------------------------------------------------------------
-- Advanced filter language helpers (Feature #18)
------------------------------------------------------------------------

-- String filter: case-insensitive substring match.
-- descriptor = { op = "=" | "!=", values = { ... } }
function SocialQuestTabUtils.MatchesStringFilter(value, descriptor)
    if not descriptor then return true end
    local lower = (value or ""):lower()
    local anyMatch = false
    for _, v in ipairs(descriptor.values or {}) do
        if lower:find(v:lower(), 1, true) then anyMatch = true; break end
    end
    if descriptor.op == "=" then return anyMatch else return not anyMatch end
end

-- Numeric filter: exact, comparison, or range.
-- Single: { op="="|"<"|">"|"<="|">=", val=N }
-- Range:  { op="range", min=N, max=N }
function SocialQuestTabUtils.MatchesNumericFilter(value, descriptor)
    if not descriptor then return true end
    if value == nil then return false end
    local n = tonumber(value)
    if not n then return false end
    if descriptor.op == "range" then return n >= descriptor.min and n <= descriptor.max
    elseif descriptor.op == "="  then return n == descriptor.val
    elseif descriptor.op == "<"  then return n <  descriptor.val
    elseif descriptor.op == ">"  then return n >  descriptor.val
    elseif descriptor.op == "<=" then return n <= descriptor.val
    elseif descriptor.op == ">=" then return n >= descriptor.val
    end
    return true
end

-- Enum filter: canonical value exact match.
-- descriptor = { op = "=" | "!=", value = canonicalString }
function SocialQuestTabUtils.MatchesEnumFilter(value, descriptor)
    if not descriptor then return true end
    local matches = (value == descriptor.value)
    return descriptor.op == "=" and matches or not matches
end

-- Type filter: each value is an independent boolean predicate.
-- descriptor = { op = "=" | "!=", value = canonicalString }
-- entry must have: questID, suggestedGroup, timerSeconds, chainInfo (all set by each tab's BuildTree).
-- AQL:GetQuestInfo() is called only for AQL-based and objective-type predicates.
function SocialQuestTabUtils.MatchesTypeFilter(entry, descriptor)
    if not descriptor then return true end
    local AQL = SocialQuest.AQL
    local value = descriptor.value
    local matched = false

    -- group/timed/solo/chain: read from entry fields directly (no AQL call needed).
    -- suggestedGroup and timerSeconds are denormalized onto every entry by each tab's
    -- BuildTree; chainInfo is populated from GetChainInfoForQuestID by each tab.
    if value == "group" then
        matched = (entry.suggestedGroup or 0) >= 2
    elseif value == "solo" then
        matched = (entry.suggestedGroup or 0) <= 1
    elseif value == "timed" then
        matched = (entry.timerSeconds or 0) > 0
    elseif value == "chain" then
        matched = entry.chainInfo ~= nil
            and entry.chainInfo.knownStatus == AQL.ChainStatus.Known
    else
        -- AQL-based and objective predicates: one GetQuestInfo call per quest.
        local info = AQL and AQL:GetQuestInfo(entry.questID)
        if not info then
            matched = false
        elseif value == "escort" or value == "dungeon" or value == "raid"
            or value == "elite"  or value == "daily"   or value == "pvp" then
            matched = (info.type == value)
        elseif value == "kill" or value == "gather" or value == "interact" then
            local objType = value == "kill" and "monster"
                         or value == "gather" and "item"
                         or "object"
            matched = false
            if info.objectives then
                for _, obj in ipairs(info.objectives) do
                    if obj.type == objType then matched = true; break end
                end
            end
        else
            matched = false  -- unknown value
        end
    end

    -- Explicit if/else avoids the Lua `a and false or c` pitfall.
    if descriptor.op == "=" then return matched else return not matched end
end
