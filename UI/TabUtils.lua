-- UI/TabUtils.lua
-- Shared utility functions for MineTab, PartyTab, and SharedTab providers.
-- Also consumed by RowFactory (WowheadUrl).

SocialQuestTabUtils = {}

local WOWHEAD_QUEST_BASE = "https://www.wowhead.com/tbc/quest="

-- Builds the Wowhead quest URL from a questID.
-- Single owner of the URL format so it never gets out of sync with stored data.
function SocialQuestTabUtils.WowheadUrl(questID)
    return WOWHEAD_QUEST_BASE .. tostring(questID)
end

-- Returns zone name for a questID using the local AQL cache; falls back to "Other Quests".
function SocialQuestTabUtils.GetZoneForQuestID(questID)
    local info = SocialQuest.AQL:GetQuest(questID)
    if info and info.zone then return info.zone end
    return "Other Quests"
end

-- Returns chainInfo for any questID; queries the provider for remote quests
-- not present in the local quest log.
function SocialQuestTabUtils.GetChainInfoForQuestID(questID)
    local AQL = SocialQuest.AQL
    local ci  = AQL:GetChainInfo(questID)
    if ci.knownStatus == "known" then return ci end
    local provider = AQL.provider
    if provider then
        local ok, result = pcall(provider.GetChainInfo, provider, questID)
        if ok and result and result.knownStatus == "known" then return result end
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
function SocialQuestTabUtils.BuildRemoteObjectives(pquest, localInfo)
    local localObjs = localInfo and localInfo.objectives or {}
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
