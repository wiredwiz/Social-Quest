-- Core/QuestieBridge.lua
-- Questie implementation of the bridge interface. Hooks QuestieComms to populate
-- GroupData for party members who have Questie but not SocialQuest.
--
-- Hooked methods (permanent via hooksecurefunc):
--   QuestieComms:InsertQuestDataPacket(questPacket, playerName)
--       Called by Questie after every parsed quest update (accept, progress, complete).
--       questPacket.id         = questID
--       questPacket.objectives = { { id, type, fulfilled, required, finished }, ... }
--
--   QuestieComms.data:RemoveQuestFromPlayer(questId, playerName)
--       Called when any quest is removed from a player's log.
--       No reason code — cannot distinguish turn-in from abandon.
--
-- playerName format: "Name-Realm" or "Name" (same as SQ's own comm layer).

QuestieBridge = {}
QuestieBridge.provider       = SocialQuest.DataProviders.Questie
QuestieBridge.nameTag        = "|TInterface/AddOns/Questie/Icons/questie.png:12:12|t"
QuestieBridge._active        = false
QuestieBridge._hookInstalled = false

local SQWowAPI = SocialQuestWowAPI

-- Returns true when Questie is loaded and its public comm API is accessible.
function QuestieBridge:IsAvailable()
    return QuestieComms ~= nil and QuestieComms.data ~= nil
end

-- Activates bridge processing and installs permanent hooks (once).
-- _hookInstalled guards against duplicate hook installation.
-- _active = true re-enables processing after a Disable() call.
function QuestieBridge:Enable()
    self._active = true
    if not self._hookInstalled then
        hooksecurefunc(QuestieComms, "InsertQuestDataPacket",
            function(_, questPacket, playerName)
                if self._active then self:_OnQuestUpdated(questPacket, playerName) end
            end)
        hooksecurefunc(QuestieComms.data, "RemoveQuestFromPlayer",
            function(_, questId, playerName)
                if self._active then self:_OnQuestRemoved(questId, playerName) end
            end)
        self._hookInstalled = true
    end
end

-- Suspends bridge processing. Does NOT remove hooks (hooksecurefunc is permanent).
function QuestieBridge:Disable()
    self._active = false
end

-- Returns a player-keyed snapshot of Questie's current remote quest log.
-- Called by BridgeRegistry before Enable() for initial hydration.
-- Pivots QuestieComms.remoteQuestLogs from [questId][playerName] to [playerName][questId].
-- GroupData:OnBridgeHydrate filters to known group members; no filtering needed here.
function QuestieBridge:GetSnapshot()
    if not QuestieComms or not QuestieComms.remoteQuestLogs then return {} end
    local snapshot = {}
    for questId, players in pairs(QuestieComms.remoteQuestLogs) do
        for playerName, objectives in pairs(players) do
            if not snapshot[playerName] then snapshot[playerName] = {} end
            snapshot[playerName][questId] = self:_BuildQuestEntry(questId, objectives)
        end
    end
    return snapshot
end

-- Translates a Questie objective array into an SQ-compatible quest entry.
-- Questie objective fields: { id, type, fulfilled, required, finished }
-- SQ objective fields:      { numFulfilled, numRequired, isFinished }
function QuestieBridge:_BuildQuestEntry(questId, questieObjectives)
    local AQL  = SocialQuest.AQL
    local info = AQL and AQL:GetQuest(questId)
    local objs = {}
    local allFinished = #questieObjectives > 0
    for i, o in ipairs(questieObjectives) do
        objs[i] = {
            numFulfilled = o.fulfilled,
            numRequired  = o.required,
            isFinished   = o.finished == true,
        }
        if not o.finished then allFinished = false end
    end
    return {
        questID      = questId,
        title        = (info and info.title)
                    or (AQL and AQL:GetQuestTitle(questId))
                    or ("Quest " .. questId),
        isComplete   = allFinished,
        isFailed     = false,   -- Questie does not transmit failure state
        snapshotTime = SQWowAPI.GetTime(),
        objectives   = objs,
    }
end

-- Hook handler: called after Questie parses a quest update packet.
function QuestieBridge:_OnQuestUpdated(questPacket, playerName)
    local entry = self:_BuildQuestEntry(questPacket.id, questPacket.objectives or {})
    SocialQuestGroupData:OnBridgeQuestUpdate(self.provider, playerName, entry)
end

-- Hook handler: called when Questie removes a quest from a player's tracked log.
function QuestieBridge:_OnQuestRemoved(questId, playerName)
    SocialQuestGroupData:OnBridgeQuestRemove(self.provider, playerName, questId)
end

-- Register with BridgeRegistry at load time.
SocialQuestBridgeRegistry:Register(QuestieBridge)
