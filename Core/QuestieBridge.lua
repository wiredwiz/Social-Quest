-- Core/QuestieBridge.lua
-- Questie implementation of the bridge interface. Hooks QuestieComms to populate
-- GroupData for party members who have Questie but not SocialQuest.
--
-- Hooked methods (permanent via hooksecurefunc):
--   QuestieComms.data:RegisterTooltip(questId, playerName, objectives)
--       Called by ALL Questie packet-insertion paths after remoteQuestLogs is populated:
--         InsertQuestDataPacket          (V1 — progress updates, full log for Questie <= 5)
--         InsertQuestDataPacketV2_noclass_RenameMe  (V2 — full log blocks, Questie > 5)
--         InsertQuestDataPacketV2        (V2 — yell-progress events)
--       Single stable hook; questId is available directly so both first-contact
--       (schedules full hydration) and subsequent per-quest updates work correctly.
--
--   QuestieComms.data:RemoveQuestFromPlayer(questId, playerName)
--       Called when any quest is removed from a player's log.
--       No reason code — cannot distinguish turn-in from abandon.
--
-- playerName format: "Name-Realm" or "Name" (same as SQ's own comm layer).
--
-- Note: Questie's GroupRosterUpdate handler has its broadcast commented out, so
-- when a new member joins an existing group, Questie never requests their quest log.
-- OnMemberJoined() works around this by sending QC_ID_REQUEST_FULL_QUESTLIST so
-- the new member (and everyone else) responds with their current quest logs.

QuestieBridge = {}
QuestieBridge.provider          = SocialQuest.DataProviders.Questie
QuestieBridge.nameTag           = "|TInterface/AddOns/Questie/Icons/questie.png:12:12|t"
QuestieBridge._active           = false
QuestieBridge._hookInstalled    = false
QuestieBridge._pendingHydration = false
QuestieBridge._pendingRequest   = false

local SQWowAPI = SocialQuestWowAPI

-- Questie sender names from CHAT_MSG_ADDON whispers include "-Realm" even for
-- same-realm players, but PlayerQuests keys use short names (no realm) for
-- same-realm players because UnitName("partyN") returns a nil realm for them.
-- Try the full name first (correct for cross-realm), then fall back to the
-- short name (correct for same-realm Questie whisper senders).
local function _NormalizeName(playerName)
    if SocialQuestGroupData.PlayerQuests[playerName] then
        return playerName
    end
    local short = playerName:match("^([^-]+)")
    if short and SocialQuestGroupData.PlayerQuests[short] then
        return short
    end
    return playerName
end

-- Questie uses QuestieLoader:CreateModule() — modules are stored in a private table,
-- not as globals. QuestieComms is never _G.QuestieComms unless Questie debug mode is on.
local function _GetQuestieComms()
    if QuestieLoader then
        return QuestieLoader:ImportModule("QuestieComms")
    end
end

-- Returns true when Questie is loaded and its public comm API is accessible.
function QuestieBridge:IsAvailable()
    local qc = _GetQuestieComms()
    return qc ~= nil and qc.data ~= nil and qc.remoteQuestLogs ~= nil
end

-- Activates bridge processing and installs permanent hooks (once).
-- _hookInstalled guards against duplicate hook installation.
-- _active = true re-enables processing after a Disable() call.
--
-- Also schedules a quest-log request immediately on activation. This covers
-- reloads where EnableAll() fires during PLAYER_LOGIN before group API data
-- (UnitName("party1") etc.) is available — in that case OnMemberJoined may
-- never fire for existing party members, so the request would never be sent
-- if it were left to OnMemberJoined alone. _pendingRequest guards against
-- duplicate requests if OnMemberJoined also fires shortly after.
function QuestieBridge:Enable()
    self._active = true
    SocialQuest:Debug("Quest", "QuestieBridge:Enable")
    if not self._hookInstalled then
        local qc = _GetQuestieComms()
        hooksecurefunc(qc.data, "RegisterTooltip",
            function(_, questId, playerName)
                if self._active then self:_OnQuestDataArrived(questId, playerName) end
            end)
        hooksecurefunc(qc.data, "RemoveQuestFromPlayer",
            function(_, questId, playerName)
                if self._active then self:_OnQuestRemoved(questId, playerName) end
            end)
        self._hookInstalled = true
    end
    self:_ScheduleQuestieRequest()
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
    local qc = _GetQuestieComms()
    if not qc or not qc.remoteQuestLogs then return {} end
    local snapshot = {}
    for questId, players in pairs(qc.remoteQuestLogs) do
        for playerName, objectives in pairs(players) do
            local key = _NormalizeName(playerName)
            if not snapshot[key] then snapshot[key] = {} end
            snapshot[key][questId] = self:_BuildQuestEntry(questId, objectives)
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

-- Hook handler: called after any Questie packet-insertion path populates remoteQuestLogs.
-- RegisterTooltip receives questId directly, so both first-contact and live-update
-- cases are handled with the same code path regardless of packet format (V1 or V2).
--
-- First contact (pdata.quests nil): defers a full re-hydration via C_Timer.After(0)
-- so all quests in the current comm batch land in remoteQuestLogs before we snapshot.
-- _pendingHydration prevents duplicate timers within a single frame.
--
-- Existing player: looks up the specific quest in remoteQuestLogs and calls
-- OnBridgeQuestUpdate for a single-quest refresh. Also handles 2nd+ blocks of a
-- multi-block V2 full-log response (block 1 sets pdata.quests, blocks 2+ arrive here).
function QuestieBridge:_OnQuestDataArrived(questId, playerName)
    local normName = _NormalizeName(playerName)
    local pdata = SocialQuestGroupData.PlayerQuests[normName]
    if not pdata or pdata.hasSocialQuest then return end

    if not pdata.quests then
        self:_ScheduleHydration()
        return
    end

    local qc = _GetQuestieComms()
    local objectives = qc.remoteQuestLogs[questId]
                    and qc.remoteQuestLogs[questId][playerName]
    if not objectives then return end
    local entry = self:_BuildQuestEntry(questId, objectives)
    SocialQuestGroupData:OnBridgeQuestUpdate(self.provider, normName, entry)
end

-- Schedules a single deferred full re-hydration for the next Lua frame.
-- Guards against duplicate timers with _pendingHydration.
function QuestieBridge:_ScheduleHydration()
    if self._pendingHydration then return end
    self._pendingHydration = true
    C_Timer.After(0, function()
        self._pendingHydration = false
        self:_EnsurePartyStubs()
        local qc = _GetQuestieComms()
        local rql = 0
        if qc and qc.remoteQuestLogs then
            for _ in pairs(qc.remoteQuestLogs) do rql = rql + 1 end
        end
        local snapshot = self:GetSnapshot()
        local snap = 0
        for _ in pairs(snapshot) do snap = snap + 1 end
        SocialQuest:Debug("Quest", "QuestieBridge: hydrate rql=" .. rql .. " snap=" .. snap)
        SocialQuestGroupData:OnBridgeHydrate(self.provider, snapshot)
    end)
end

-- Creates hasSocialQuest=false stubs in PlayerQuests for any current group members
-- who lack an entry. Called before GetSnapshot() so OnBridgeHydrate can accept
-- hydration data for players missed during early PLAYER_LOGIN.
--
-- Root cause: on reload, UnitName("party1") returns nil during PLAYER_LOGIN, so
-- GroupComposition's OnGroupRosterUpdate misses the party member, OnMemberJoined
-- is never called, and no stub is created. GROUP_ROSTER_UPDATE may not re-fire
-- after the party API is ready (or fires before SocialQuest registers for it),
-- leaving no other path to create the stub. By the time our polls fire (t+5s,
-- t+9s, etc.) UnitName("party1") is reliably available, so creating stubs here
-- bridges the gap.
function QuestieBridge:_EnsurePartyStubs()
    local count = SQWowAPI.GetNumGroupMembers()
    SocialQuest:Debug("Quest", "QuestieBridge: _EnsurePartyStubs count=" .. count)
    if count <= 1 then return end
    if SQWowAPI.IsInRaid() then
        for i = 1, count do
            local name = SQWowAPI.GetRaidRosterInfo(i)
            if name and not SocialQuestGroupData.PlayerQuests[name] then
                SocialQuestGroupData.PlayerQuests[name] = { hasSocialQuest = false, completedQuests = {} }
                SocialQuest:Debug("Quest", "QuestieBridge: stub created for " .. name)
            end
        end
    else
        for i = 1, count - 1 do
            local name, realm = SQWowAPI.UnitName("party" .. i)
            if name then
                local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
                if not SocialQuestGroupData.PlayerQuests[fullName] then
                    SocialQuestGroupData.PlayerQuests[fullName] = { hasSocialQuest = false, completedQuests = {} }
                    SocialQuest:Debug("Quest", "QuestieBridge: stub created for " .. fullName)
                end
            else
                SocialQuest:Debug("Quest", "QuestieBridge: party" .. i .. " UnitName=nil")
            end
        end
    end
end

-- Called by BridgeRegistry when a new group member joins.
-- Questie's GroupRosterUpdate handler has its broadcast commented out, so it never
-- requests quest logs when a new member joins an existing group. Send the request
-- ourselves so the new member responds with their quest log.
function QuestieBridge:OnMemberJoined(fullName)
    self:_ScheduleQuestieRequest()
end

-- Sends QC_ID_REQUEST_FULL_QUESTLIST via Questie's internal message bus.
-- Debounced so rapid joins (e.g. raid fill) result in a single request pair.
--
-- Two sends are scheduled to cover both use-cases:
--
--   t+1s  (initial group join): Questie is already fully initialized at this point
--         because Stage 2/3 of QuestieInit ran at PLAYER_LOGIN a long time ago.
--
--   t+5s  (reload): QuestieComms:Initialize() — which registers the
--         "QC_ID_REQUEST_FULL_QUESTLIST" AceEvent listener via Questie:RegisterMessage —
--         is called in QuestieInit Stage 3, which only starts after Stage 2 finishes
--         (up to 3s waiting for game cache). On reload the t+1s send fires before the
--         listener exists, so the message is lost. By t+5s Stage 3 is complete and
--         the listener is registered, so this second send succeeds.
--
-- Hydration polls follow each send so remoteQuestLogs is read after the V2 response
-- window (response arrives ~0-3s after the request). _ScheduleHydration() is idempotent.
function QuestieBridge:_ScheduleQuestieRequest()
    if self._pendingRequest then return end
    self._pendingRequest = true

    -- First send: t+1s. Works when Questie is already initialized (live group join).
    C_Timer.After(1, function()
        local hasSM = Questie and Questie.SendMessage ~= nil
        local inParty = UnitInParty and UnitInParty("player")
        local inRaid  = UnitInRaid  and UnitInRaid("player")
        SocialQuest:Debug("Quest", "QuestieBridge: t+1s send hasSM=" .. tostring(hasSM)
            .. " inParty=" .. tostring(inParty) .. " inRaid=" .. tostring(inRaid))
        if hasSM then
            Questie:SendMessage("QC_ID_REQUEST_FULL_QUESTLIST")
        end
        C_Timer.After(4, function()
            if QuestieBridge._active then QuestieBridge:_ScheduleHydration() end
        end)
    end)

    -- Second send: t+5s. Works after reload where Questie needs ~3-4s to initialize.
    C_Timer.After(5, function()
        self._pendingRequest = false
        local inParty = UnitInParty and UnitInParty("player")
        local inRaid  = UnitInRaid  and UnitInRaid("player")
        SocialQuest:Debug("Quest", "QuestieBridge: t+5s send inParty=" .. tostring(inParty)
            .. " inRaid=" .. tostring(inRaid))
        if Questie and Questie.SendMessage then
            Questie:SendMessage("QC_ID_REQUEST_FULL_QUESTLIST")
        end
        C_Timer.After(4, function()
            if QuestieBridge._active then QuestieBridge:_ScheduleHydration() end
        end)
        C_Timer.After(8, function()
            if QuestieBridge._active then QuestieBridge:_ScheduleHydration() end
        end)
    end)

    -- Third send: t+10s. Fallback if UnitInParty("player") was nil at t+1s/t+5s on reload.
    -- By t+10s the party API is always stable; GetGroupType() will return non-nil.
    C_Timer.After(10, function()
        if not QuestieBridge._active then return end
        local inParty = UnitInParty and UnitInParty("player")
        local inRaid  = UnitInRaid  and UnitInRaid("player")
        SocialQuest:Debug("Quest", "QuestieBridge: t+10s send inParty=" .. tostring(inParty)
            .. " inRaid=" .. tostring(inRaid))
        if Questie and Questie.SendMessage then
            Questie:SendMessage("QC_ID_REQUEST_FULL_QUESTLIST")
        end
        C_Timer.After(4, function()
            if QuestieBridge._active then QuestieBridge:_ScheduleHydration() end
        end)
        C_Timer.After(10, function()
            if QuestieBridge._active then QuestieBridge:_ScheduleHydration() end
        end)
    end)
end

-- Hook handler: called when Questie removes a quest from a player's tracked log.
function QuestieBridge:_OnQuestRemoved(questId, playerName)
    SocialQuestGroupData:OnBridgeQuestRemove(self.provider, _NormalizeName(playerName), questId)
end

-- Register with BridgeRegistry at load time.
SocialQuestBridgeRegistry:Register(QuestieBridge)
