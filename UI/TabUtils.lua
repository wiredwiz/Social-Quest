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
        local text = (localObj and localObj.text ~= "" and localObj.text)
                  or (tostring(obj.numFulfilled or 0) .. "/" .. tostring(obj.numRequired or 1))
        objs[i] = {
            text         = text,
            isFinished   = obj.isFinished,
            numFulfilled = obj.numFulfilled or 0,
            numRequired  = obj.numRequired  or 1,
        }
    end
    return objs
end
