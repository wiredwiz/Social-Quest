-- Core/GroupData.lua
-- Owns the PlayerQuests table. Populated entirely from incoming AceComm messages.
-- All values stored are numeric — no text strings from other players.
--
-- PlayerQuests["Name-Realm"] = {
--     hasSocialQuest = true,
--     lastSync       = <SQWowAPI.GetTime()>,
--     quests = {
--         [questID] = {
--             questID=N, isComplete=bool, isFailed=bool,
--             snapshotTime=N, timerSeconds=N_or_nil,
--             objectives = { {numFulfilled=N, numRequired=N, isFinished=bool}, ... }
--         },
--     }
-- }
-- Players without SocialQuest: { hasSocialQuest=false }

SocialQuestGroupData = {}

SocialQuestGroupData.PlayerQuests = {}

local SQWowAPI = SocialQuestWowAPI
local ET = SocialQuest.EventTypes

-- Called by GroupComposition when a new player appears in the group.
-- Creates a hasSocialQuest=false stub so receive handlers can accept their
-- messages before an SQ_INIT arrives.
-- groupType is accepted but unused; passed for signature consistency.
function SocialQuestGroupData:OnMemberJoined(fullName, groupType)
    if not self.PlayerQuests[fullName] then
        self.PlayerQuests[fullName] = { hasSocialQuest = false, completedQuests = {} }
        SocialQuest:Debug("Group", "Stub created for " .. fullName)
    end
end

-- Called by GroupComposition immediately when a player leaves the group.
-- Removes their entry from PlayerQuests so the GroupFrame stops showing them.
-- If they rejoin, their SQ_INIT broadcast on rejoin replaces this data anyway.
function SocialQuestGroupData:PurgePlayer(fullName)
    if self.PlayerQuests[fullName] then
        self.PlayerQuests[fullName] = nil
        SocialQuest:Debug("Group", "Purged data for " .. fullName)
    end
end

-- Called by GroupComposition when the local player leaves all groups.
-- Clears the entire PlayerQuests table.
function SocialQuestGroupData:OnSelfLeftGroup()
    self.PlayerQuests = {}
    SocialQuest:Debug("Group", "PlayerQuests cleared (self left group)")
end

-- Called when a full SQ_INIT message arrives from a player.
-- payload: { quests = { [questID] = { isComplete, isFailed,
--            snapshotTime, timerSeconds, objectives={...} } } }
function SocialQuestGroupData:OnInitReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    -- Enrich each quest entry with a title from local AQL where available.
    -- Titles are never transmitted; we resolve them locally.
    local AQL    = SocialQuest.AQL
    local quests = payload.quests or {}
    for questID, q in pairs(quests) do
        if not q.title then
            local info = AQL and AQL:GetQuest(questID)
            q.title = (info and info.title) or (AQL and AQL:GetQuestTitle(questID))
        end
    end

    local existing = self.PlayerQuests[sender]
    self.PlayerQuests[sender] = {
        hasSocialQuest  = true,
        dataProvider    = SocialQuest.DataProviders.SocialQuest,
        lastSync        = SQWowAPI.GetTime(),
        quests          = quests,
        completedQuests = (existing and existing.completedQuests) or {},
    }

    local _sqN = 0
    for _ in pairs(quests or {}) do _sqN = _sqN + 1 end
    SocialQuest:Debug("Group", "Stored init data for " .. sender .. " (" .. _sqN .. " quests)")

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a single-quest SQ_UPDATE arrives.
-- payload: { questID=N, eventType="accepted"|..., isComplete=bool, isFailed=bool,
--            snapshotTime=N, timerSeconds=N_or_nil,
--            objectives={...} }
function SocialQuestGroupData:OnUpdateReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry then
        entry = { hasSocialQuest = true, dataProvider = SocialQuest.DataProviders.SocialQuest, lastSync = SQWowAPI.GetTime(), quests = {}, completedQuests = {} }
        self.PlayerQuests[sender] = entry
    end
    entry.hasSocialQuest = true
    entry.lastSync       = SQWowAPI.GetTime()

    local eventType = payload.eventType
    local questID   = payload.questID

    local cachedTitle
    if eventType == ET.Abandoned or eventType == ET.Completed or eventType == ET.Failed then
        if eventType == ET.Completed then
            entry.completedQuests[questID] = true
        end
        -- Grab the title we stored when this quest was first received, before removing it.
        cachedTitle = entry.quests[questID] and entry.quests[questID].title
        entry.quests[questID] = nil
    elseif eventType == ET.Tracked or eventType == ET.Untracked then
        -- Tracking state has no meaning in remote data; skip without modifying the entry.
        -- Guard also prevents recreating an entry that was already removed by a terminal event.
        return
    else
        local AQL  = SocialQuest.AQL
        local info = AQL and AQL:GetQuest(questID)
        entry.quests[questID] = {
            questID      = questID,
            title        = (info and info.title) or (AQL and AQL:GetQuestTitle(questID)),
            isComplete   = payload.isComplete  == 1,
            isFailed     = payload.isFailed    == 1,
            snapshotTime = payload.snapshotTime,
            timerSeconds = payload.timerSeconds,
            objectives   = payload.objectives or {},
        }
    end

    -- Trigger banner notification if applicable.
    SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID, cachedTitle)

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a single-objective SQ_OBJECTIVE arrives.
-- payload: { questID=N, objIndex=N, numFulfilled=N, numRequired=N, isFinished=0|1 }
-- Determines regression direction before updating stored value, then fires banner.
function SocialQuestGroupData:OnObjectiveReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry or not entry.quests then return end
    local quest = entry.quests[payload.questID]
    if not quest then return end

    local obj = quest.objectives[payload.objIndex]
    if not obj then obj = {}; quest.objectives[payload.objIndex] = obj end

    -- Determine direction before updating stored value.
    local isRegression = obj.numFulfilled ~= nil
                     and payload.numFulfilled < obj.numFulfilled
    local isComplete   = payload.isFinished == 1

    obj.numFulfilled = payload.numFulfilled
    obj.numRequired  = payload.numRequired
    obj.isFinished   = isComplete

    -- Banner notification.
    SocialQuestAnnounce:OnRemoteObjectiveEvent(
        sender, payload.questID,
        payload.objIndex,
        payload.numFulfilled, payload.numRequired,
        isComplete, isRegression)

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a non-SocialQuest group member's quest log changes.
-- UNIT_QUEST_LOG_CHANGED fires for party members even without the addon.
-- Ensures they have a hasSocialQuest=false stub so the "all completed" check
-- correctly suppresses when a non-SQ member is present.
-- Note: UnitIsOnQuest does not exist in TBC Classic, so shared quest detection
-- is not possible here. The entry is created with an empty quests table.
function SocialQuestGroupData:OnUnitQuestLogChanged(unit)
    -- Only handle party/raid units, not "player".
    if not unit or unit == "player" then return end

    local name, realm = SQWowAPI.UnitName(unit)
    if not name then return end
    local fullName = realm and realm ~= "" and (name.."-"..realm) or name

    local entry = self.PlayerQuests[fullName]
    if entry and entry.hasSocialQuest then return end  -- Full data already available.

    self.PlayerQuests[fullName] = {
        hasSocialQuest  = false,
        lastSync        = SQWowAPI.GetTime(),
        quests          = {},
        completedQuests = {},
    }

    SocialQuestGroupFrame:RequestRefresh()
end

-- Helper: is this sender currently in our group?
function SocialQuestGroupData:IsInGroup(fullName)
    return self.PlayerQuests[fullName] ~= nil
end

-- Called by bridge modules when a quest update packet arrives for a player.
-- provider: SocialQuest.DataProviders.* constant identifying the data source.
-- fullName:  "Name-Realm" or "Name" — same format used as PlayerQuests keys.
-- questEntry: { questID, title, isComplete, isFailed, snapshotTime, objectives={...} }
function SocialQuestGroupData:OnBridgeQuestUpdate(provider, fullName, questEntry)
    local pdata = self.PlayerQuests[fullName]
    if not pdata then return end            -- not a known group member; ignore
    if pdata.hasSocialQuest then return end -- SQ data takes precedence

    pdata.dataProvider = provider
    pdata.lastSync     = SQWowAPI.GetTime()
    if not pdata.quests then pdata.quests = {} end

    local questID  = questEntry.questID
    local existing = pdata.quests[questID]
    local isNew    = existing == nil

    -- Diff objectives only when the quest was already known.
    -- Avoids progress banners for catch-up data seen for the first time.
    if existing then
        for i, obj in ipairs(questEntry.objectives) do
            local prev        = existing.objectives[i]
            local wasFinished = prev and prev.isFinished
            if obj.isFinished and not wasFinished then
                SocialQuestAnnounce:OnRemoteObjectiveEvent(
                    fullName, questID, i,
                    obj.numFulfilled, obj.numRequired, true, false)
            elseif prev and obj.numFulfilled > prev.numFulfilled then
                SocialQuestAnnounce:OnRemoteObjectiveEvent(
                    fullName, questID, i,
                    obj.numFulfilled, obj.numRequired, false, false)
            end
        end

        -- Quest complete: all objectives finished and wasn't complete before.
        if questEntry.isComplete and not existing.isComplete then
            SocialQuestAnnounce:OnRemoteQuestEvent(
                fullName, ET.Finished, questID, questEntry.title)
        end
    end

    pdata.quests[questID] = questEntry

    if isNew then
        SocialQuestAnnounce:OnRemoteQuestEvent(
            fullName, ET.Accepted, questID, questEntry.title)
    end

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called by bridge modules when a quest is removed from a player's log.
-- Reason (turn-in vs abandon) is unverifiable from the bridge; no Announce is fired.
-- completedQuests[questID] is NOT set — reason unknown.
function SocialQuestGroupData:OnBridgeQuestRemove(provider, fullName, questID)
    local pdata = self.PlayerQuests[fullName]
    if not pdata or pdata.hasSocialQuest then return end
    if pdata.quests and pdata.quests[questID] then
        pdata.quests[questID] = nil
        SocialQuestGroupFrame:RequestRefresh()
    end
end

-- Called by BridgeRegistry before Enable() to populate initial quest state.
-- No banners are fired. Only hydrates players who already have a stub in
-- PlayerQuests (current group members) — skips non-group players in the snapshot.
function SocialQuestGroupData:OnBridgeHydrate(provider, snapshot)
    for fullName, quests in pairs(snapshot) do
        local pdata = self.PlayerQuests[fullName]
        if pdata and not pdata.hasSocialQuest then
            pdata.dataProvider = provider
            pdata.lastSync     = SQWowAPI.GetTime()
            pdata.quests       = quests
            -- completedQuests preserved if accumulated before hydration
        end
    end
    SocialQuestGroupFrame:RequestRefresh()
end
