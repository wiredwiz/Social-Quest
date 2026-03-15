-- Core/GroupData.lua
-- Owns the PlayerQuests table. Populated entirely from incoming AceComm messages.
-- All values stored are numeric — no text strings from other players.
--
-- PlayerQuests["Name-Realm"] = {
--     hasSocialQuest = true,
--     lastSync       = <GetTime()>,
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

-- Called when GROUP_ROSTER_UPDATE fires. Removes stale entries and adds stubs
-- for newly visible members who haven't sent data yet.
function SocialQuestGroupData:OnGroupChanged()
    -- Build a set of current group member names.
    local current = {}
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid"..i) or ("party"..i)
        local name, realm = UnitName(unit)
        if name then
            local fullName = realm and realm ~= "" and (name.."-"..realm) or name
            current[fullName] = true
        end
    end

    -- Remove entries for players no longer in group.
    for fullName in pairs(self.PlayerQuests) do
        if not current[fullName] then
            self.PlayerQuests[fullName] = nil
        end
    end

    -- Add stub entries for new members we haven't heard from yet.
    for fullName in pairs(current) do
        if not self.PlayerQuests[fullName] then
            self.PlayerQuests[fullName] = { hasSocialQuest = false, completedQuests = {} }
        end
    end
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
        lastSync        = GetTime(),
        quests          = quests,
        completedQuests = (existing and existing.completedQuests) or {},
    }

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
        entry = { hasSocialQuest = true, lastSync = GetTime(), quests = {}, completedQuests = {} }
        self.PlayerQuests[sender] = entry
    end
    entry.hasSocialQuest = true
    entry.lastSync       = GetTime()

    local eventType = payload.eventType
    local questID   = payload.questID

    local cachedTitle
    if eventType == "abandoned" or eventType == "completed" or eventType == "failed" then
        if eventType == "completed" then
            entry.completedQuests[questID] = true
        end
        -- Grab the title we stored when this quest was first received, before removing it.
        cachedTitle = entry.quests[questID] and entry.quests[questID].title
        entry.quests[questID] = nil
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

    local name, realm = UnitName(unit)
    if not name then return end
    local fullName = realm and realm ~= "" and (name.."-"..realm) or name

    local entry = self.PlayerQuests[fullName]
    if entry and entry.hasSocialQuest then return end  -- Full data already available.

    self.PlayerQuests[fullName] = {
        hasSocialQuest  = false,
        lastSync        = GetTime(),
        quests          = {},
        completedQuests = {},
    }

    SocialQuestGroupFrame:RequestRefresh()
end

-- Helper: is this sender currently in our group?
function SocialQuestGroupData:IsInGroup(fullName)
    return self.PlayerQuests[fullName] ~= nil
end
