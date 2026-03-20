-- Core/Communications.lua
-- Handles all AceComm send/receive. All payloads are numeric-only tables —
-- no quest titles or objective text are ever transmitted.
--
-- Prefixes:
--   SQ_INIT      Full quest log snapshot (questID + objective counts).
--   SQ_UPDATE    Single quest state change.
--   SQ_OBJECTIVE Single objective progress update.
--   SQ_REQUEST   Whisper requesting a full SQ_INIT from a specific player.
--   SQ_FOLLOW_START / SQ_FOLLOW_STOP  Follow notifications (whisper).

SocialQuestComm = {}
SocialQuestComm.followTarget = nil  -- last player we started following

local PREFIXES = {
    "SQ_INIT", "SQ_UPDATE", "SQ_OBJECTIVE",
    "SQ_REQUEST",
    "SQ_FOLLOW_START", "SQ_FOLLOW_STOP",
    "SQ_REQ_COMPLETED", "SQ_RESP_COMPLETE",
}

-- GroupType enum alias — GroupComposition owns the definition; we reference it here
-- so comparisons read GroupType.Party rather than raw "party" strings.
-- GroupComposition.lua loads before Communications.lua (see TOC), so this is safe.
local GroupType = SocialQuestGroupComposition.GroupType

local lastInitSent = {}   -- keyed by sender name; tracks when SQ_INIT was last sent per player

-- Jitter-delayed SQ_INIT whisper handles, keyed by sender name.
-- Prevents response bursts: when a new raid member broadcasts SQ_INIT, all
-- existing members schedule responses with 1–8 s random delay rather than
-- responding simultaneously. Also used for SQ_REQUEST (Force Resync) responses.
local pendingResponses = {}

-- Called from SocialQuest:OnEnable().
function SocialQuestComm:Initialize()
    local AceComm = LibStub("AceComm-3.0")
    for _, prefix in ipairs(PREFIXES) do
        AceComm:RegisterComm(prefix, function(pfx, msg, dist, sender)
            SocialQuestComm:OnCommReceived(pfx, msg, dist, sender)
        end)
    end
end

------------------------------------------------------------------------
-- Group change / initialization
------------------------------------------------------------------------

-- Called when GROUP_ROSTER_UPDATE fires.
function SocialQuestComm:OnGroupChanged()
    lastInitSent = {}
    local db = SocialQuest.db.profile

    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        -- Party (≤5): send full init immediately to PARTY channel.
        if db.party.transmit then
            self:SendFullInit("PARTY")
        end

    elseif IsInRaid() then
        -- Raid init now handled by GroupComposition:OnSelfJoinedGroup → Comm:OnSelfJoinedGroup.
        -- SendBeacon removed in Task 3; OnGroupChanged removed in Task 5.

    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        -- Battleground init now handled by GroupComposition:OnSelfJoinedGroup → Comm:OnSelfJoinedGroup.
        -- SendBeacon removed in Task 3; OnGroupChanged removed in Task 5.
    end
    -- Guild: no AceComm sync.

    self:SendReqCompleted()
end

------------------------------------------------------------------------
-- Send helpers
------------------------------------------------------------------------

-- Build a numeric-only quest payload table from a QuestInfo.
local function buildQuestPayload(questInfo, eventType)
    local objs = {}
    for i, obj in ipairs(questInfo.objectives or {}) do
        objs[i] = {
            numFulfilled = obj.numFulfilled,
            numRequired  = obj.numRequired,
            isFinished   = obj.isFinished and 1 or 0,
        }
    end
    return {
        questID      = questInfo.questID,
        eventType    = eventType,
        isComplete   = questInfo.isComplete  and 1 or 0,
        isFailed     = questInfo.isFailed    and 1 or 0,
        -- snapshotTime is the sender's GetTime() AT MOMENT OF TRANSMISSION, not
        -- the time AQL built its local cache. This gives receivers an accurate
        -- reference for timer estimation: remaining = timerSeconds - (GetTime() - snapshotTime).
        snapshotTime = GetTime(),
        timerSeconds = questInfo.timerSeconds,  -- nil if no timer (serializes cleanly)
        objectives   = objs,
    }
end

-- Build the full init payload: all active quests, objectives only (numeric).
local function buildInitPayload()
    local AQL = SocialQuest.AQL
    local quests = {}
    for questID, info in pairs(AQL:GetAllQuests()) do
        local objs = {}
        for i, obj in ipairs(info.objectives or {}) do
            objs[i] = {
                numFulfilled = obj.numFulfilled,
                numRequired  = obj.numRequired,
                isFinished   = obj.isFinished and 1 or 0,
            }
        end
        quests[questID] = {
            questID      = questID,
            isComplete   = info.isComplete  and 1 or 0,
            isFailed     = info.isFailed    and 1 or 0,
            snapshotTime = GetTime(),  -- stamp at transmission time, not AQL cache build time
            timerSeconds = info.timerSeconds,
            objectives   = objs,
        }
    end
    return { quests = quests }
end

local function serialize(t)
    return LibStub("AceSerializer-3.0"):Serialize(t)
end

function SocialQuestComm:SendFullInit(channel, targetName)
    local payload = buildInitPayload()
    local msg = serialize(payload)
    local _sqN = 0
    for _ in pairs(payload.quests or {}) do _sqN = _sqN + 1 end
    if targetName then
        LibStub("AceComm-3.0"):SendCommMessage("SQ_INIT", msg, "WHISPER", targetName)
        SocialQuest:Debug("Comm", "Sent SQ_INIT to " .. targetName .. " (" .. _sqN .. " quests)")
    else
        LibStub("AceComm-3.0"):SendCommMessage("SQ_INIT", msg, channel)
        SocialQuest:Debug("Comm", "Sent SQ_INIT to " .. channel .. " (" .. _sqN .. " quests)")
    end
end

-- Broadcast a single quest state update.
function SocialQuestComm:BroadcastQuestUpdate(questInfo, eventType)
    local channel = self:GetActiveChannel()
    if not channel then return end

    local payload = buildQuestPayload(questInfo, eventType)
    LibStub("AceComm-3.0"):SendCommMessage("SQ_UPDATE", serialize(payload), channel)
    SocialQuest:Debug("Comm", "Sent SQ_UPDATE: " .. eventType .. " questID=" .. questInfo.questID)
end

-- Broadcast a single objective update.
function SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    local channel = self:GetActiveChannel()
    if not channel then return end

    local payload = {
        questID      = questInfo.questID,
        objIndex     = objective.index,
        numFulfilled = objective.numFulfilled,
        numRequired  = objective.numRequired,
        isFinished   = objective.isFinished and 1 or 0,
    }
    LibStub("AceComm-3.0"):SendCommMessage("SQ_OBJECTIVE", serialize(payload), channel)
    SocialQuest:Debug("Comm", "Sent SQ_OBJECTIVE: questID=" .. questInfo.questID .. " obj=" .. objective.index .. " " .. objective.numFulfilled .. "/" .. objective.numRequired)
end

function SocialQuestComm:SendFollowStart(targetName)
    self.followTarget = targetName
    LibStub("AceComm-3.0"):SendCommMessage("SQ_FOLLOW_START", serialize({}), "WHISPER", targetName)
end

function SocialQuestComm:SendFollowStop(targetName)
    LibStub("AceComm-3.0"):SendCommMessage("SQ_FOLLOW_STOP", serialize({}), "WHISPER", targetName)
end

-- Broadcast to group members requesting their completed quest IDs.
function SocialQuestComm:SendReqCompleted()
    local channel = self:GetActiveChannel()
    if not channel then return end
    LibStub("AceComm-3.0"):SendCommMessage("SQ_REQ_COMPLETED", serialize({}), channel)
    SocialQuest:Debug("Comm", "Sent SQ_REQ_COMPLETED to " .. channel)
end

-- Called by GroupComposition when the local player joins a group or when the
-- group type changes (e.g. party promoted to raid).
-- Broadcasts our full quest snapshot to the new channel and requests completed
-- quest history from all members.
function SocialQuestComm:OnSelfJoinedGroup(groupType)
    -- Cancel any pending jitter responses: they were scheduled for the previous
    -- group context and are no longer valid.
    for _, handle in pairs(pendingResponses) do
        SocialQuest:CancelTimer(handle)
    end
    pendingResponses = {}
    lastInitSent     = {}

    local db = SocialQuest.db.profile
    if groupType == GroupType.Party then
        if db.party.transmit then
            self:SendFullInit("PARTY")
            self:SendReqCompleted()
        end
    elseif groupType == GroupType.Raid then
        if db.raid.transmit then
            self:SendFullInit("RAID")
            self:SendReqCompleted()
        end
    elseif groupType == GroupType.Battleground then
        if db.battleground.transmit then
            self:SendFullInit("INSTANCE_CHAT")
            self:SendReqCompleted()
        end
    end
    SocialQuest:Debug("Comm", "OnSelfJoinedGroup: " .. (groupType or "nil"))
end

-- Called by GroupComposition when a new member appears in the group.
-- Party only: whisper the new member directly because they missed our channel
-- broadcast (they weren't in the group when we sent it).
-- Raid/BG: no-op — the new member broadcasts SQ_INIT to the channel themselves;
-- we respond via the SQ_INIT receive handler with a jittered whisper.
function SocialQuestComm:OnMemberJoined(fullName, groupType)
    if groupType == GroupType.Party then
        local db = SocialQuest.db.profile
        if db.party.transmit then
            self:SendFullInit("WHISPER", fullName)
            SocialQuest:Debug("Comm", "OnMemberJoined (party): sent SQ_INIT whisper to " .. fullName)
        end
    end
    -- raid/battleground: receive handler schedules jittered response to their SQ_INIT broadcast
end

-- Called by GroupComposition immediately after PurgePlayer when a member leaves.
-- Clears the 15-second cooldown for that sender so that if they rejoin quickly
-- (within 15 s), their SQ_INIT broadcast on rejoin is not silently dropped.
function SocialQuestComm:OnMemberLeft(fullName)
    lastInitSent[fullName] = nil
    if pendingResponses[fullName] then
        SocialQuest:CancelTimer(pendingResponses[fullName])
        pendingResponses[fullName] = nil
    end
    SocialQuest:Debug("Comm", "OnMemberLeft: cleared cooldowns for " .. fullName)
end

-- Called by GroupComposition when the local player leaves all groups.
-- Cancels all pending jitter timers and clears cooldown state.
function SocialQuestComm:OnSelfLeftGroup()
    for _, handle in pairs(pendingResponses) do
        SocialQuest:CancelTimer(handle)
    end
    pendingResponses = {}
    lastInitSent     = {}
    SocialQuest:Debug("Comm", "OnSelfLeftGroup: cleared all pending responses and cooldowns")
end

-- Returns the appropriate AceComm channel string for the player's current group context.
-- Returns nil if not in a group or guild-only (guild has no AceComm sync).
function SocialQuestComm:GetActiveChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
    return nil
end

function SocialQuestComm:SendResyncRequest()
    local channel = self:GetActiveChannel()
    if not channel then
        SocialQuest:Debug("Resync", "Resync: not in group, no-op")
        return
    end
    -- Transmit guard: use GetActiveChannel priority (raid > battleground > party).
    local sectionMap = { RAID = "raid", INSTANCE_CHAT = "battleground", PARTY = "party" }
    local section = sectionMap[channel]
    local db = SocialQuest.db.profile
    if section and db[section] and not db[section].transmit then
        SocialQuest:Debug("Resync", "Resync: transmit disabled for " .. section .. ", no-op")
        return
    end
    SocialQuest:Debug("Resync", "Resync: broadcasting SQ_REQUEST to " .. channel)
    LibStub("AceComm-3.0"):SendCommMessage("SQ_REQUEST", serialize({}), channel)
    SocialQuest:Debug("Comm", "Sent SQ_REQUEST to " .. channel)
end

------------------------------------------------------------------------
-- Receive
------------------------------------------------------------------------

function SocialQuestComm:OnCommReceived(prefix, msg, distribution, sender)
    -- Ignore our own messages.
    local myName, myRealm = UnitFullName("player")
    local myFullName = myRealm and (myName .. "-" .. myRealm) or myName
    if sender == myName or sender == myFullName then return end

    local ok, payload = LibStub("AceSerializer-3.0"):Deserialize(msg)
    if not ok then
        SocialQuest:Debug("Comm", "Failed to deserialize " .. prefix .. " from " .. sender)
        return
    end

    if prefix == "SQ_INIT" then
        local _sqN = 0
        for _ in pairs(payload.quests or {}) do _sqN = _sqN + 1 end
        SocialQuest:Debug("Comm", "Received SQ_INIT from " .. sender .. " (" .. _sqN .. " quests, dist=" .. distribution .. ")")
        SocialQuestGroupData:OnInitReceived(sender, payload)

        -- Raid/BG broadcasts: schedule a jittered whisper response so that up to
        -- 39 existing members don't all respond simultaneously (storm prevention).
        -- Party and whisper distributions need no response here:
        --   Party:   OnMemberJoined already sent a direct whisper to new members.
        --   Whisper: This is their response to us; no further response needed.
        if distribution == "RAID" or distribution == "INSTANCE_CHAT" then
            if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
                SocialQuest:Debug("Comm", "SQ_INIT from " .. sender .. " — response suppressed (cooldown)")
            else
                lastInitSent[sender] = GetTime()
                if pendingResponses[sender] then
                    SocialQuest:CancelTimer(pendingResponses[sender])
                end
                pendingResponses[sender] = SocialQuest:ScheduleTimer(function()
                    pendingResponses[sender] = nil
                    self:SendFullInit("WHISPER", sender)
                    SocialQuest:Debug("Comm", "Sent jittered SQ_INIT whisper to " .. sender)
                end, math.random(1, 8))
            end
        end

    elseif prefix == "SQ_UPDATE" then
        SocialQuest:Debug("Comm", "Received SQ_UPDATE from " .. sender .. ": " .. (payload.eventType or "?") .. " questID=" .. (payload.questID or "?"))
        SocialQuestGroupData:OnUpdateReceived(sender, payload)

    elseif prefix == "SQ_OBJECTIVE" then
        SocialQuest:Debug("Comm", "Received SQ_OBJECTIVE from " .. sender .. ": questID=" .. (payload.questID or "?") .. " obj=" .. (payload.objIndex or "?"))
        SocialQuestGroupData:OnObjectiveReceived(sender, payload)

    elseif prefix == "SQ_REQUEST" then
        if not SocialQuestGroupData.PlayerQuests[sender] then
            SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — dropped (not in group)")
            return
        end
        if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then
            SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — dropped (cooldown)")
            return
        end
        -- Stamp at schedule time (not fire time) so a second SQ_REQUEST arriving
        -- during the jitter window doesn't schedule a duplicate response.
        lastInitSent[sender] = GetTime()
        if pendingResponses[sender] then
            SocialQuest:CancelTimer(pendingResponses[sender])
        end
        SocialQuest:Debug("Comm", "Received SQ_REQUEST from " .. sender .. " — scheduling jittered response (1-4 s)")
        pendingResponses[sender] = SocialQuest:ScheduleTimer(function()
            pendingResponses[sender] = nil
            self:SendFullInit("WHISPER", sender)
            SocialQuest:Debug("Comm", "Sent jittered SQ_INIT to " .. sender .. " (SQ_REQUEST response)")
        end, math.random(1, 4))

    elseif prefix == "SQ_FOLLOW_START" then
        SocialQuestAnnounce:OnFollowStart(sender)

    elseif prefix == "SQ_FOLLOW_STOP" then
        SocialQuestAnnounce:OnFollowStop(sender)

    elseif prefix == "SQ_REQ_COMPLETED" then
        SocialQuest:Debug("Comm", "Received SQ_REQ_COMPLETED from " .. sender)
        -- Whisper our completed quest history back to the requester.
        local AQL = SocialQuest.AQL
        if AQL then
            local completedPayload = { completedQuests = AQL:GetCompletedQuests() }
            local _sqN = 0
            for _ in pairs(completedPayload.completedQuests or {}) do _sqN = _sqN + 1 end
            LibStub("AceComm-3.0"):SendCommMessage(
                "SQ_RESP_COMPLETE", serialize(completedPayload), "WHISPER", sender)
            SocialQuest:Debug("Comm", "Sent SQ_RESP_COMPLETE to " .. sender .. " (" .. _sqN .. " completed quests)")
        end

    elseif prefix == "SQ_RESP_COMPLETE" then
        -- Store the responding player's completed quest set.
        -- NOTE: `payload` here is already deserialized — the existing code at the
        -- top of OnCommReceived does `local ok, payload = AceSerializer:Deserialize(msg)`
        -- before the prefix dispatch, so no separate deserialization is needed here.
        local _sqN = 0
        for _ in pairs(payload.completedQuests or {}) do _sqN = _sqN + 1 end
        SocialQuest:Debug("Comm", "Received SQ_RESP_COMPLETE from " .. sender .. " (" .. _sqN .. " completed quests)")
        local entry = SocialQuestGroupData.PlayerQuests[sender]
        if entry then
            entry.completedQuests = payload.completedQuests or {}
        end
        SocialQuestGroupFrame:RequestRefresh()
    end
end
