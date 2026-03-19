-- Core/Announcements.lua
-- Drives all chat announcements (outbound from local player's quest events)
-- and banner notifications (inbound from other SocialQuest users).
--
-- Structure (top to bottom):
--   1. Throttle queue: enqueueChat, startThrottleTicker  (unchanged)
--   2. Pure message formatters (no I/O, no game-state reads)
--   3. Display primitives: displayBanner, displayChatPreview
--   4. Questie suppression: QUESTIE_FLAG_FOR, questieWouldAnnounce
--   5. Section detection: getSenderSection
--   6. Public event handlers: OnQuestEvent, OnObjectiveEvent,
--      OnRemoteQuestEvent, OnRemoteObjectiveEvent, OnOwnQuestEvent,
--      OnOwnObjectiveEvent
--   7. InitEventHooks: UIErrorsFrame_OnEvent hook for suppression backup
--   8. Debug test entry point: TestEvent
--   8. Follow notifications + WhisperFriends helpers  (unchanged)
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
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

-- Set of event types that carry chain-step annotation when chainInfo is known.
-- "finished" is intentionally excluded (objectives done, not yet turned in).
local CHAIN_STEP_EVENTS = {
    accepted  = true,
    completed = true,
    failed    = true,
    abandoned = true,
}

-- Appends " (Step N)" to msg when the quest is a known chain step.
-- Returns msg unchanged when: event is not in CHAIN_STEP_EVENTS, chainInfo is nil,
-- knownStatus != "known", or step is nil. Never errors on nil inputs.
local function appendChainStep(msg, eventType, chainInfo)
    if not CHAIN_STEP_EVENTS[eventType] then return msg end
    if not chainInfo or chainInfo.knownStatus ~= "known" or not chainInfo.step then
        return msg
    end
    return msg .. " " .. string.format(L["(Step %s)"], chainInfo.step)
end

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
-- Pure message formatters (no I/O, no game-state reads)
------------------------------------------------------------------------

local OUTBOUND_QUEST_TEMPLATES = {
    accepted  = L["{rt1} SocialQuest: Quest Accepted: %s"],
    abandoned = L["{rt1} SocialQuest: Quest Abandoned: %s"],
    finished  = L["{rt1} SocialQuest: Quest Complete: %s"],
    completed = L["{rt1} SocialQuest: Quest Completed: %s"],
    failed    = L["{rt1} SocialQuest: Quest Failed: %s"],
}

local function formatOutboundQuestMsg(eventType, questTitle)
    local tmpl = OUTBOUND_QUEST_TEMPLATES[eventType] or L["{rt1} SocialQuest: Quest Event: %s"]
    return string.format(tmpl, questTitle)
end

-- isRegression appends " (regression)" to distinguish direction.
local function formatOutboundObjectiveMsg(questTitle, objText, numFulfilled, numRequired, isRegression)
    local suffix = isRegression and L[" (regression)"] or ""
    return string.format(L["{rt1} SocialQuest: %d/%d %s%s for %s!"],
        numFulfilled, numRequired, objText, suffix, questTitle)
end

local BANNER_QUEST_TEMPLATES = {
    accepted  = L["%s accepted: %s"],
    abandoned = L["%s abandoned: %s"],
    finished  = L["%s finished objectives: %s"],
    completed = L["%s completed: %s"],
    failed    = L["%s failed: %s"],
}

local function formatQuestBannerMsg(sender, eventType, questTitle)
    local tmpl = BANNER_QUEST_TEMPLATES[eventType]
    if not tmpl then return nil end
    return string.format(tmpl, sender, questTitle)
end

local function formatObjectiveBannerMsg(sender, questTitle, objText, numFulfilled, numRequired, isComplete, isRegression)
    if isComplete then
        return string.format(L["%s completed objective: %s — %s (%d/%d)"],
            sender, questTitle, objText, numFulfilled, numRequired)
    elseif isRegression then
        return string.format(L["%s regressed: %s — %s (%d/%d)"],
            sender, questTitle, objText, numFulfilled, numRequired)
    else
        return string.format(L["%s progressed: %s — %s (%d/%d)"],
            sender, questTitle, objText, numFulfilled, numRequired)
    end
end

------------------------------------------------------------------------
-- Display primitives
------------------------------------------------------------------------

local function displayBanner(msg, eventType)
    if not RaidWarningFrame then return end
    local color = SocialQuestColors.GetEventColor(eventType)
    local colorInfo = color and { r = color.r, g = color.g, b = color.b }
                   or { r = 1, g = 1, b = 0 }
    RaidNotice_AddMessage(RaidWarningFrame, msg, colorInfo)
end

local function displayChatPreview(msg)
    DEFAULT_CHAT_FRAME:AddMessage(L["|cFF00CCFFSocialQuest (preview):|r "] .. msg)
end

------------------------------------------------------------------------
-- Questie suppression
------------------------------------------------------------------------

-- Maps SocialQuest event type → the Questie profile flag that controls the same message.
-- Event types absent from this table are never suppressed (Questie has no equivalent).
-- Research note: Questie only announces objective_complete (threshold reached),
-- never partial progress — so objective_progress is intentionally absent.
local QUESTIE_FLAG_FOR = {
    accepted           = "questAnnounceAccepted",
    abandoned          = "questAnnounceAbandoned",
    completed          = "questAnnounceCompleted",
    objective_complete = "questAnnounceObjectives",
}

local function questieWouldAnnounce(eventType)
    local flag = QUESTIE_FLAG_FOR[eventType]
    if not flag then return false end
    if type(Questie) ~= "table" then return false end
    local profile = Questie.db and Questie.db.profile
    if not profile then return false end
    if not profile[flag] then return false end
    return profile.questAnnounceChannel ~= "disabled"
end

------------------------------------------------------------------------
-- Section detection
------------------------------------------------------------------------

-- Returns "raid", "battleground", or "party" only.
-- "whisperFriends" is never returned: whisper-to-friends is outbound only;
-- inbound addon-comm messages always arrive via PARTY, RAID, or BATTLEGROUND.
local function getSenderSection()
    if IsInRaid() then
        return "raid"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "battleground"
    else
        return "party"
    end
end

------------------------------------------------------------------------
-- Local quest event announcements (from AQL callbacks)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnQuestEvent(eventType, questID, questInfo)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local AQL   = SocialQuest.AQL
    local info  = AQL and AQL:GetQuest(questID)
    local title = (info and info.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)
    -- Prefer the WoW quest hyperlink string from the AQL snapshot so that recipients
    -- can ctrl-click the quest link in chat. Falls back to info.link (from the live
    -- QuestCache) then plain title. The finished event passes no questInfo (questInfo
    -- is nil) so the info.link fallback is the primary path for that event type.
    -- RaidNotice_AddMessage (banners) cannot render hyperlinks — title is used there.
    local display = (questInfo and questInfo.link)
                 or (info and info.link)
                 or title
    local msg   = formatOutboundQuestMsg(eventType, display)
    local chainInfo = questInfo and questInfo.chainInfo
    msg = appendChainStep(msg, eventType, chainInfo)

    if not questieWouldAnnounce(eventType) then
        -- Party
        if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
            if db.party.transmit and db.party.announce[eventType] then
                enqueueChat(msg, "PARTY")
            end
        end

        -- Raid
        if IsInRaid() then
            if db.raid.transmit and db.raid.announce[eventType] then
                enqueueChat(msg, "RAID")
            end
        end

        -- Guild
        if IsInGuild() then
            if db.guild.transmit and db.guild.announce[eventType] then
                enqueueChat(msg, "GUILD")
            end
        end

        -- Battleground
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            if db.battleground.transmit and db.battleground.announce[eventType] then
                enqueueChat(msg, "BATTLEGROUND")
            end
        end

        -- Whisper friends
        if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
            self:WhisperFriends(msg, db.whisperFriends.groupOnly)
        end
    end

    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnQuestEvent(eventType, title, chainInfo)

    -- Party-wide completion check: fires "Everyone has completed" when all engaged
    -- group members have turned in this quest.
    if eventType == "completed" then
        checkAllCompleted(questID, true)
    end
end

-- Objective progress/complete/regression — party + battleground + whisper only.
-- isRegression is true when the count decreased (e.g. party member died).
function SocialQuestAnnounce:OnObjectiveEvent(eventType, questInfo, objective, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    if not questieWouldAnnounce(eventType) then
        local msg = formatOutboundObjectiveMsg(
            questInfo.title,
            objective.name or "",
            objective.numFulfilled,
            objective.numRequired,
            isRegression)

        -- Party
        if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() then
            if db.party.transmit and db.party.announce[eventType] then
                enqueueChat(msg, "PARTY")
            end
        end

        -- Battleground
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            if db.battleground.transmit and db.battleground.announce[eventType] then
                enqueueChat(msg, "BATTLEGROUND")
            end
        end

        -- Whisper friends
        if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
            self:WhisperFriends(msg, db.whisperFriends.groupOnly)
        end
    end

    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnObjectiveEvent(eventType, questInfo, objective, isRegression)
end

------------------------------------------------------------------------
-- Remote event banner notifications (inbound from other SocialQuest users)
------------------------------------------------------------------------

-- Fires "Everyone has completed [Quest Name]" when every engaged group member
-- (those who have or had the quest) has turned it in.
-- Suppressed entirely if any group member lacks SocialQuest (hasSocialQuest == false).
-- localHasCompleted: true when the local player just triggered this via OnQuestEvent;
--                    false when a remote player's SQ_UPDATE triggered it.
local function checkAllCompleted(questID, localHasCompleted)
    -- db.enabled is checked here rather than relying on callers: this function is
    -- called from two separate entry points and must be self-contained.
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local PlayerQuests = SocialQuestGroupData.PlayerQuests

    -- Must be in a group (PlayerQuests only contains remote members).
    local anyRemote = false
    for _ in pairs(PlayerQuests) do anyRemote = true; break end
    if not anyRemote then return end

    -- Every group member must have SocialQuest; suppress entirely if any lacks it.
    for _, entry in pairs(PlayerQuests) do
        if not entry.hasSocialQuest then return end
    end

    -- Build engaged set: only players who have or had the quest this session.
    -- "Engaged" = currently has the quest active OR has completed it THIS session.
    -- Players who never had the quest are excluded entirely.
    -- Note: IsQuestFlaggedCompleted is NOT used for engagement — it returns true
    -- for quests completed in prior sessions, which would cause false positives.
    local AQL = SocialQuest.AQL

    -- Local player: engaged if they just completed it or have it active right now.
    -- IsQuestFlaggedCompleted is intentionally NOT used for engagement — it returns
    -- true for quests completed in prior sessions and would cause false positives.
    local localActive   = AQL and AQL:GetQuest(questID) ~= nil
    local localEngaged  = localHasCompleted or localActive
    -- localFlagged is only consulted inside the localEngaged guard below.
    local localFlagged  = localHasCompleted or (AQL and AQL:HasCompletedQuest(questID))
    if localEngaged and not localFlagged then return end  -- engaged but not done

    -- Remote players: check engagement and completion.
    local anyEngaged = localEngaged
    for _, entry in pairs(PlayerQuests) do
        local hasActive    = entry.quests and entry.quests[questID] ~= nil
        local hasCompleted = entry.completedQuests and entry.completedQuests[questID] == true
        local engaged      = hasActive or hasCompleted
        if engaged then
            anyEngaged = true
            if not hasCompleted then return end  -- engaged but not done
        end
    end

    -- No one in the group has or had the quest.
    if not anyEngaged then return end

    -- Display gating: same toggle as normal completion banners.
    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.display.completed then return end

    -- Title resolution: plain text — RaidNotice does not parse hyperlinks.
    local info  = AQL and AQL:GetQuest(questID)
    local title = (info and info.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)

    local msg = string.format(L["Everyone has completed: %s"], title)
    displayBanner(msg, "all_complete")

    -- Chat message only when the local player triggered it (avoids duplicate
    -- sends from multiple SQ clients simultaneously detecting the same condition).
    if localHasCompleted and sectionDb.transmit and sectionDb.announce.completed then
        local channelMap = { party = "PARTY", raid = "RAID", battleground = "BATTLEGROUND" }
        local channel = channelMap[section]
        if channel then
            enqueueChat(msg, channel)
        end
    end
end

function SocialQuestAnnounce:OnRemoteQuestEvent(sender, eventType, questID, cachedTitle)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    -- Party-wide completion check: fires regardless of displayReceived, because
    -- "Everyone has completed" is a synthesized local event, not a raw inbound banner.
    if eventType == "completed" then
        checkAllCompleted(questID, false)
    end

    if not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end
    if not sectionDb.display[eventType] then return end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end
    if section == "battleground" and db.battleground.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end

    local AQL   = SocialQuest.AQL
    local info  = AQL and AQL:GetQuestInfo(questID)
    local title = cachedTitle
               or (info and info.title)
               or ("Quest " .. questID)
    -- Note: AQL:GetQuestTitle fallback is intentionally removed. It delegates
    -- internally to AQL:GetQuestInfo, so if GetQuestInfo returns nil (AQL unavailable
    -- or quest unknown), GetQuestTitle would also return nil — the fallback adds no
    -- resolution capability beyond what the single GetQuestInfo call already provides.
    local chainInfo = info and info.chainInfo

    local msg = formatQuestBannerMsg(sender, eventType, title)
    if msg then
        msg = appendChainStep(msg, eventType, chainInfo)
        displayBanner(msg, eventType)
    end
end

function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, objIndex, numFulfilled, numRequired, isComplete, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then return end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then return end

    local eventType = isComplete and "objective_complete" or "objective_progress"
    if not sectionDb.display[eventType] then return end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end
    if section == "battleground" and db.battleground.friendsOnly
        and not C_FriendList.IsFriend(sender) then return end

    local AQL     = SocialQuest.AQL
    local objs    = AQL and AQL:GetQuestObjectives(questID)
    local objInfo = objs and objs[objIndex]
    local objText = (objInfo and objInfo.name) or ""
    local title   = (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)

    local msg = formatObjectiveBannerMsg(sender, title, objText, numFulfilled, numRequired, isComplete, isRegression)
    displayBanner(msg, eventType)
end

------------------------------------------------------------------------
-- Own-quest banners (local player's own events, opt-in)
------------------------------------------------------------------------

function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle, chainInfo)
    local db = SocialQuest.db.profile
    if not db.enabled then return end
    if not db.general.displayOwn then return end
    if not db.general.displayOwnEvents[eventType] then return end

    local msg = formatQuestBannerMsg(L["You"], eventType, questTitle)
    if msg then
        msg = appendChainStep(msg, eventType, chainInfo)
        displayBanner(msg, eventType)
    end
end

function SocialQuestAnnounce:OnOwnObjectiveEvent(eventType, questInfo, objective, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled then return end
    if not db.general.displayOwn then return end
    if not db.general.displayOwnEvents[eventType] then return end

    local msg = formatObjectiveBannerMsg(
        L["You"], questInfo.title,
        objective.name or "",
        objective.numFulfilled, objective.numRequired,
        eventType == "objective_complete", isRegression)
    displayBanner(msg, eventType)
end

-- Intercept UIErrorsFrame's OnEvent to suppress the native WoW objective-progress
-- floating text when SocialQuest's own banner is active. In TBC Classic (20505),
-- quest objective progress notifications arrive via UI_INFO_MESSAGE, not
-- QUEST_WATCH_UPDATE. We use GetScript/SetScript so the hook chains correctly to any
-- other addon that installed its own OnEvent before us.
-- Called once from SocialQuest:OnInitialize().
function SocialQuestAnnounce:InitEventHooks()
    local orig = UIErrorsFrame:GetScript("OnEvent")
    if not orig then return end
    UIErrorsFrame:SetScript("OnEvent", function(self, event, messageType, msg, ...)
        if event == "UI_INFO_MESSAGE" then
            local db = SocialQuest.db.profile
            local AQL = SocialQuest.AQL
            if db and db.enabled
                    and db.general.displayOwn
                    and db.general.displayOwnEvents.objective_progress
                    and AQL and AQL:IsQuestObjectiveText(msg) then
                return
            end
        end
        return orig(self, event, messageType, msg, ...)
    end)
end

------------------------------------------------------------------------
-- Debug test entry point
------------------------------------------------------------------------

-- "objective_regression" is a pseudo-type used only by the test panel; it shares
-- the objective_progress color and toggle but has distinct demo text.
local TEST_DEMOS = {
    accepted = {
        outbound = "{rt1} SocialQuest: Quest Accepted: A Daunting Task (Step 2)",
        banner   = "TestPlayer accepted: [A Daunting Task] (Step 2)",
        colorKey = "accepted",
    },
    abandoned = {
        outbound = "{rt1} SocialQuest: Quest Abandoned: A Daunting Task (Step 2)",
        banner   = "TestPlayer abandoned: [A Daunting Task] (Step 2)",
        colorKey = "abandoned",
    },
    finished = {
        outbound = "{rt1} SocialQuest: Quest Complete: A Daunting Task",
        banner   = "TestPlayer finished objectives: [A Daunting Task]",
        colorKey = "finished",
    },
    completed = {
        outbound = "{rt1} SocialQuest: Quest Completed: A Daunting Task (Step 2)",
        banner   = "TestPlayer completed: [A Daunting Task] (Step 2)",
        colorKey = "completed",
    },
    failed = {
        outbound = "{rt1} SocialQuest: Quest Failed: A Daunting Task (Step 2)",
        banner   = "TestPlayer failed: [A Daunting Task] (Step 2)",
        colorKey = "failed",
    },
    objective_progress = {
        outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer progressed: [A Daunting Task] — Kobolds Slain (3/8)",
        colorKey = "objective_progress",
    },
    objective_complete = {
        outbound = "{rt1} SocialQuest: 8/8 Kobolds Slain for [A Daunting Task]!",
        banner   = "TestPlayer completed objective: [A Daunting Task] — Kobolds Slain (8/8)",
        colorKey = "objective_complete",
    },
    objective_regression = {
        outbound = "{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for [A Daunting Task]!",
        banner   = "TestPlayer regressed: [A Daunting Task] — Kobolds Slain (2/8)",
        colorKey = "objective_progress",   -- same color as progress
    },
    all_complete = {
        outbound = nil,   -- no outbound chat for this synthesized event
        banner   = "Everyone has completed: A Daunting Task",
        colorKey = "all_complete",
    },
}

function SocialQuestAnnounce:TestEvent(eventType)
    local demo = TEST_DEMOS[eventType]
    if not demo then return end
    displayBanner(demo.banner, demo.colorKey)
    displayChatPreview(demo.outbound)
end

function SocialQuestAnnounce:TestChatLink()
    local AQL  = SocialQuest.AQL
    local link = AQL and AQL:GetQuestLink(337)
    local msg  = formatOutboundQuestMsg("completed", link or "Quest 337 (no link)")
    displayChatPreview(msg)
end

------------------------------------------------------------------------
-- Follow notifications
------------------------------------------------------------------------

function SocialQuestAnnounce:OnFollowStart(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    SocialQuest:Print(string.format(L["%s started following you."], sender))
end

function SocialQuestAnnounce:OnFollowStop(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    SocialQuest:Print(string.format(L["%s stopped following you."], sender))
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
