-- Core/GroupData.lua
-- Owns the PlayerQuests table. Populated entirely from incoming AceComm messages.
-- All values stored are numeric — no text strings from other players.
--
-- PlayerQuests["Name-Realm"] = {
--     hasSocialQuest = true,
--     lastSync       = <GetTime()>,
--     quests = {
--         [questID] = {
--             questID=N, isComplete=bool, isFailed=bool, isTracked=bool,
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
            self.PlayerQuests[fullName] = { hasSocialQuest = false }
        end
    end
end

-- Called when a full SQ_INIT message arrives from a player.
-- payload: { quests = { [questID] = { isComplete, isFailed, isTracked,
--            snapshotTime, timerSeconds, objectives={...} } } }
function SocialQuestGroupData:OnInitReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    self.PlayerQuests[sender] = {
        hasSocialQuest = true,
        lastSync       = GetTime(),
        quests         = payload.quests or {},
    }

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a single-quest SQ_UPDATE arrives.
-- payload: { questID=N, eventType="accepted"|..., isComplete=bool, isFailed=bool,
--            isTracked=bool, snapshotTime=N, timerSeconds=N_or_nil,
--            objectives={...} }
function SocialQuestGroupData:OnUpdateReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry then
        entry = { hasSocialQuest = true, lastSync = GetTime(), quests = {} }
        self.PlayerQuests[sender] = entry
    end
    entry.hasSocialQuest = true
    entry.lastSync       = GetTime()

    local eventType = payload.eventType
    local questID   = payload.questID

    if eventType == "abandoned" or eventType == "completed" or eventType == "failed" then
        entry.quests[questID] = nil
    else
        entry.quests[questID] = {
            questID      = questID,
            isComplete   = payload.isComplete  == 1,
            isFailed     = payload.isFailed    == 1,
            isTracked    = payload.isTracked   == 1,
            snapshotTime = payload.snapshotTime,
            timerSeconds = payload.timerSeconds,
            objectives   = payload.objectives or {},
        }
    end

    -- Trigger banner notification if applicable.
    SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)

    SocialQuestGroupFrame:RequestRefresh()
end

-- Called when a single-objective SQ_OBJECTIVE arrives.
-- payload: { questID=N, objIndex=N, numFulfilled=N, numRequired=N, isFinished=bool }
function SocialQuestGroupData:OnObjectiveReceived(sender, payload)
    if not self:IsInGroup(sender) then return end

    local entry = self.PlayerQuests[sender]
    if not entry or not entry.quests then return end

    local quest = entry.quests[payload.questID]
    if not quest then return end

    local obj = quest.objectives[payload.objIndex]
    if not obj then
        obj = {}
        quest.objectives[payload.objIndex] = obj
    end
    obj.numFulfilled = payload.numFulfilled
    obj.numRequired  = payload.numRequired
    obj.isFinished   = payload.isFinished == 1

    SocialQuestGroupFrame:RequestRefresh()
end

-- Sweep the local quest log via UnitIsOnQuest for a non-SocialQuest member.
-- UNIT_QUEST_LOG_CHANGED fires for party members even without the addon.
-- UnitIsOnQuest(questLogIndex, unit) checks if `unit` is on the quest at index.
-- We must skip header entries (isHeader = true) when iterating.
function SocialQuestGroupData:OnUnitQuestLogChanged(unit)
    -- Only handle party/raid units, not "player".
    if not unit or unit == "player" then return end

    local name, realm = UnitName(unit)
    if not name then return end
    local fullName = realm and realm ~= "" and (name.."-"..realm) or name

    local entry = self.PlayerQuests[fullName]
    if entry and entry.hasSocialQuest then return end  -- Full data already available.

    -- Partial data: find which of OUR quests this unit also has.
    local sharedQuestIDs = {}
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        -- GetQuestLogTitle in TBC Classic returns: title, level, suggestedGroup, isHeader, ...
        -- isHeader is the 4th return value (not 5th).
        local title, level, suggestedGroup, isHeader = GetQuestLogTitle(i)
        if not isHeader and UnitIsOnQuest(i, unit) then
            local info = C_QuestLog.GetInfo(i)
            if info then
                table.insert(sharedQuestIDs, info.questID)
            end
        end
    end

    -- Build a minimal quest entry with only the questIDs we know about.
    local questData = {}
    for _, questID in ipairs(sharedQuestIDs) do
        questData[questID] = { questID = questID, objectives = {} }
    end

    self.PlayerQuests[fullName] = {
        hasSocialQuest = false,
        lastSync       = GetTime(),
        quests         = questData,
    }

    SocialQuestGroupFrame:RequestRefresh()
end

-- Helper: is this sender currently in our group?
function SocialQuestGroupData:IsInGroup(fullName)
    return self.PlayerQuests[fullName] ~= nil
end
