-- Core/Announcements.lua
-- Drives all chat announcements (outbound from local player's quest events)
-- and banner notifications (inbound from other SocialQuest users).
--
-- Chat queue: all SendChatMessage calls pass through a FIFO queue with a
-- 1-second minimum interval to avoid bot-detection throttling. Duplicate
-- messages are dropped before enqueue.

SocialQuestAnnounce = {}

local throttleQueue  = {}
local lastSendTime   = 0
local THROTTLE_DELAY = 1.0  -- seconds between chat sends

-- Ticker drives the throttle queue. Created once and kept running.
local ticker = nil

local function startThrottleTicker()
    if ticker then return end
    ticker = SocialQuest:ScheduleRepeatingTimer(function()
        local now = GetTime()
        if #throttleQueue > 0 and (now - lastSendTime) >= THROTTLE_DELAY then
            local item = table.remove(throttleQueue, 1)
            SendChatMessage(item.text, item.channel, nil, item.target)
            lastSendTime = now
        end
    end, 0.25)
end

local function enqueueChat(text, channel, target)
    -- Drop duplicate messages already in queue.
    for _, item in ipairs(throttleQueue) do
        if item.text == text and item.channel == channel and item.target == target then
            return
        end
    end
    table.insert(throttleQueue, { text = text, channel = channel, target = target })
    startThrottleTicker()
end

------------------------------------------------------------------------
-- Message formatting
------------------------------------------------------------------------

-- Format a quest event announcement. Returns a plain string.
-- Text is always resolved locally from AQL — never transmitted.
local function formatQuestMessage(eventType, questTitle)
    local templates = {
        accepted  = "Quest accepted: %s",
        abandoned = "Quest abandoned: %s",
        finished  = "Quest complete (objectives done): %s",
        completed = "Quest turned in: %s",
        failed    = "Quest failed: %s",
    }
    local tmpl = templates[eventType] or "Quest event (%s): %s"
    return string.format(tmpl, questTitle)
end

local function formatObjectiveMessage(questTitle, objectiveText)
    return string.format("Quest progress — %s: %s", questTitle, objectiveText)
end

------------------------------------------------------------------------
-- Determine which channels to announce to
------------------------------------------------------------------------

local function getAnnouncementChannels(eventType)
    local db  = SocialQuest.db.profile
    local channels = {}

    -- Party
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        if db.party.transmit and db.party.announce[eventType] then
            table.insert(channels, { channel = "PARTY" })
        end
    end

    -- Raid
    if IsInRaid() then
        if db.raid.transmit and db.raid.announce[eventType] then
            table.insert(channels, { channel = "RAID" })
        end
    end

    -- Guild
    if IsInGuild() then
        if db.guild.transmit and db.guild.announce[eventType] then
            table.insert(channels, { channel = "GUILD" })
        end
    end

    -- Battleground
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if db.battleground.transmit and db.battleground.announce[eventType] then
            table.insert(channels, { channel = "BATTLEGROUND" })
        end
    end

    return channels
end

------------------------------------------------------------------------
-- Local quest event announcements (from our own AQL callbacks)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnQuestEvent(eventType, questInfo)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local title = questInfo.title
    local msg   = formatQuestMessage(eventType, title)
    local chans = getAnnouncementChannels(eventType)

    for _, chan in ipairs(chans) do
        enqueueChat(msg, chan.channel, chan.target)
    end

    -- Whisper friends.
    if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
        self:WhisperFriends(msg, db.whisperFriends.groupOnly)
    end
end

-- Objective progress (party + whisper friends only per announcement matrix).
function SocialQuestAnnounce:OnObjectiveEvent(eventType, questInfo, objective)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local title = questInfo.title
    local msg   = formatObjectiveMessage(title, objective.text or "")

    -- Party and Battleground get objective progress; Raid and Guild do not (per announcement matrix).
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
        if db.party.transmit and db.party.announce["objective"] then
            enqueueChat(msg, "PARTY")
        end
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if db.battleground.transmit and db.battleground.announce["objective"] then
            enqueueChat(msg, "BATTLEGROUND")
        end
    end

    -- Whisper friends.
    if db.whisperFriends.enabled and db.whisperFriends.announce["objective"] then
        self:WhisperFriends(msg, db.whisperFriends.groupOnly)
    end
end

------------------------------------------------------------------------
-- Remote event banner notifications (from SQ_UPDATE received from others)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end
    if not db.general.receive[eventType] then return end

    -- Check friends-only filter for raid/BG.
    local inRaid = IsInRaid()
    local inBG   = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    if inRaid and db.raid.friendsOnly and not C_FriendList.IsFriend(sender) then return end
    if inBG   and db.battleground.friendsOnly and not C_FriendList.IsFriend(sender) then return end

    -- Resolve quest title locally from AQL.
    local AQL = SocialQuest.AQL
    local title = AQL and AQL:GetQuestLink(questID) or C_QuestLog.GetTitleForQuestID(questID) or ("Quest "..questID)

    local templates = {
        accepted  = "%s accepted: %s",
        abandoned = "%s abandoned: %s",
        finished  = "%s finished objectives: %s",
        completed = "%s completed: %s",
        failed    = "%s failed: %s",
    }
    local tmpl = templates[eventType]
    if not tmpl then return end

    local bannerMsg = string.format(tmpl, sender, title)
    if RaidWarningFrame then
        RaidWarningFrame:AddMessage(bannerMsg)
    end
end

------------------------------------------------------------------------
-- Follow notifications
------------------------------------------------------------------------

function SocialQuestAnnounce:OnFollowStart(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    SocialQuest:Print(sender .. " started following you.")
end

function SocialQuestAnnounce:OnFollowStop(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    SocialQuest:Print(sender .. " stopped following you.")
end

------------------------------------------------------------------------
-- Whisper friends helper
------------------------------------------------------------------------

function SocialQuestAnnounce:WhisperFriends(msg, groupOnly)
    local numFriends = C_FriendList.GetNumFriends()
    for i = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            local friendName = info.name
            if groupOnly then
                -- Only whisper if friend is in current group.
                if not self:IsFriendInGroup(friendName) then
                    friendName = nil
                end
            end
            if friendName then
                enqueueChat(msg, "WHISPER", friendName)
            end
        end
    end
end

function SocialQuestAnnounce:IsFriendInGroup(name)
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = IsInRaid() and ("raid"..i) or ("party"..i)
        local unitName = UnitName(unit)
        if unitName == name then return true end
    end
    return false
end
