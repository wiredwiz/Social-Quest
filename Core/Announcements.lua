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
--   9. Follow notifications + WhisperFriends helpers  (unchanged)
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
local SQWowAPI = SocialQuestWowAPI
local SQWowUI  = SocialQuestWowUI
local ET = SocialQuest.EventTypes

-- Remembers questIDs for which the local player has confirmed completion this session.
-- Populated when checkAllCompleted fires with localHasCompleted=true.
-- Ensures the local-done check passes if a remote SQ_UPDATE triggers a second
-- checkAllCompleted call after both players finish near-simultaneously (the AQL cache
-- may not yet reflect isComplete=true by the time the remote update arrives).
local selfFinishedQuests = {}

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
local function appendChainStep(msg, eventType, chainResult, sender)
    if not CHAIN_STEP_EVENTS[eventType] then return msg end
    if not chainResult or chainResult.knownStatus ~= SocialQuest.AQL.ChainStatus.Known then
        return msg
    end
    local engaged = SocialQuestTabUtils.BuildEngagedSet(sender)  -- nil = local player
    local ci = SocialQuestTabUtils.SelectChain(chainResult, engaged)
    if not ci or not ci.step then return msg end
    return msg .. " " .. string.format(L["(Step %s)"], ci.step)
end

local function startThrottleTicker()
    if ticker then return end
    ticker = SocialQuest:ScheduleRepeatingTimer(function()
        local now = SQWowAPI.GetTime()
        if #throttleQueue > 0 and (now - lastSendTime) >= THROTTLE_DELAY then
            local item = table.remove(throttleQueue, 1)
            SQWowAPI.SendChatMessage(item.text, item.channel, nil, item.target)
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
    completed = L["{rt1} SocialQuest: Quest Turned In: %s"],
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

-- Builds the clickable hyperlink string for SendChatMessage.
-- Non-Retail: Questie-compatible |Hquestie:| format. Questie users get a clickable
--   tooltip; others see "[level] Name" as plain readable text.
-- Retail: SQ's own |Hsocialquest:| format. Tooltips.lua registers a SetItemRef hook
--   that forwards it to the native quest tooltip display.
-- Returns nil when questID or questName is nil (safe: callers fall back to plain title).
local function BuildQuestLink(questID, questName, questLevel)
    if not questID or not questName then return nil end
    local level = questLevel or 0
    if SQWowAPI.IS_RETAIL then
        return "|Hsocialquest:" .. questID .. ":" .. level
               .. "|h[" .. level .. "] " .. questName .. "|h|r"
    else
        local senderGUID = UnitGUID("player") or ""
        return "|Hquestie:" .. questID .. ":" .. senderGUID
               .. "|h[" .. level .. "] " .. questName .. "|h|r"
    end
end
-- Exposed for unit tests. Not part of the public API.
SocialQuestAnnounce._BuildQuestLink = BuildQuestLink

local BANNER_QUEST_TEMPLATES = {
    accepted  = L["%s accepted: %s"],
    abandoned = L["%s abandoned: %s"],
    finished  = L["%s completed: %s"],
    completed = L["%s turned in: %s"],
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
    local color = SocialQuestColors.GetEventColor(eventType)
    local colorInfo = color and { r = color.r, g = color.g, b = color.b }
                   or { r = 1, g = 1, b = 0 }
    SQWowUI.AddRaidNotice(msg, colorInfo)
end

local function displayChatPreview(msg)
    local preview = msg:gsub("{rt(%d)}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t")
    SQWowUI.AddChatMessage(L["|cFF00CCFFSocialQuest (preview):|r "] .. preview)
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
    if SQWowAPI.IsInRaid() then
        return "raid"
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
        return "battleground"
    else
        return "party"
    end
end

------------------------------------------------------------------------
-- Local quest event announcements (from AQL callbacks)
------------------------------------------------------------------------

local checkAllCompleted  -- forward declaration; defined below after OnQuestEvent/OnRemoteQuestEvent

function SocialQuestAnnounce:OnQuestEvent(eventType, questID, questInfo)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local AQL   = SocialQuest.AQL
    local info  = AQL and AQL:GetQuest(questID)
    local title = (info and info.title)
               or (questInfo and questInfo.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)
    local level   = (questInfo and questInfo.level) or (info and info.level)
    local display = BuildQuestLink(questID, title, level) or ("[" .. title .. "]")
    local msg     = formatOutboundQuestMsg(eventType, display)
    local chainInfo = questInfo and questInfo.chainInfo
    msg = appendChainStep(msg, eventType, chainInfo)

    if questieWouldAnnounce(eventType) then
        SocialQuest:Debug("Banner", "Chat suppressed: Questie will announce " .. eventType)
    else
        -- Party
        if SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME) and not SQWowAPI.IsInRaid() then
            if db.party.transmit and db.party.announce[eventType] then
                SocialQuest:Debug("Banner", "Chat [PARTY]: " .. string.sub(msg, 1, 60))
                enqueueChat(msg, "PARTY")
            end
        end

        -- Raid
        if SQWowAPI.IsInRaid() then
            if db.raid.transmit and db.raid.announce[eventType] then
                SocialQuest:Debug("Banner", "Chat [RAID]: " .. string.sub(msg, 1, 60))
                enqueueChat(msg, "RAID")
            end
        end

        -- Guild
        if SQWowAPI.IsInGuild() then
            if db.guild.transmit and db.guild.announce[eventType] then
                SocialQuest:Debug("Banner", "Chat [GUILD]: " .. string.sub(msg, 1, 60))
                enqueueChat(msg, "GUILD")
            end
        end

        -- Battleground
        if SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
            if db.battleground.transmit and db.battleground.announce[eventType] then
                SocialQuest:Debug("Banner", "Chat [BATTLEGROUND]: " .. string.sub(msg, 1, 60))
                enqueueChat(msg, "BATTLEGROUND")
            end
        end

        -- Whisper friends
        if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
            SocialQuest:Debug("Banner", "Chat [WHISPER]: " .. string.sub(msg, 1, 60))
            self:WhisperFriends(msg, db.whisperFriends.groupOnly)
        end
    end

    -- Own-quest banner: fires regardless of chat suppression.
    self:OnOwnQuestEvent(eventType, title, chainInfo)

    -- Clear stale completion record when the local player abandons a quest.
    -- selfFinishedQuests persists until explicitly cleared; without this, a second
    -- run of the same quest would show localDone=true from a prior completion even
    -- though the player re-accepted and has not finished the objectives again.
    if eventType == ET.Abandoned then
        selfFinishedQuests[questID] = nil
    end

    -- Party-wide objectives check: fires "Everyone has completed" when all engaged
    -- group members have completed this quest's objectives.
    if eventType == ET.Finished then
        checkAllCompleted(questID, true)
    end
end

-- Objective progress/complete/regression — party + battleground + whisper only.
-- isRegression is true when the count decreased (e.g. party member died).
function SocialQuestAnnounce:OnObjectiveEvent(eventType, questInfo, objective, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    if questieWouldAnnounce(eventType) then
        SocialQuest:Debug("Banner", "Chat suppressed: Questie will announce " .. eventType)
    else
        local msg = formatOutboundObjectiveMsg(
            "[" .. (questInfo.title or ("Quest " .. questInfo.questID)) .. "]",
            objective.name or "",
            objective.numFulfilled,
            objective.numRequired,
            isRegression)

        -- Party
        if SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME) and not SQWowAPI.IsInRaid() then
            if db.party.transmit and db.party.announce[eventType] then
                SocialQuest:Debug("Banner", "Chat [PARTY]: " .. string.sub(msg, 1, 60))
                enqueueChat(msg, "PARTY")
            end
        end

        -- Battleground
        if SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
            if db.battleground.transmit and db.battleground.announce[eventType] then
                SocialQuest:Debug("Banner", "Chat [BATTLEGROUND]: " .. string.sub(msg, 1, 60))
                enqueueChat(msg, "BATTLEGROUND")
            end
        end

        -- Whisper friends
        if db.whisperFriends.enabled and db.whisperFriends.announce[eventType] then
            SocialQuest:Debug("Banner", "Chat [WHISPER]: " .. string.sub(msg, 1, 60))
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
-- (those who have or had the quest) has completed all objectives.
-- Suppressed entirely if any group member lacks SocialQuest (hasSocialQuest == false).
-- localHasCompleted: true when the local player just triggered this via OnQuestEvent;
--                    false when a remote player's SQ_UPDATE triggered it.
checkAllCompleted = function(questID, localHasCompleted)
    -- db.enabled is checked here rather than relying on callers: this function is
    -- called from two separate entry points and must be self-contained.
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    -- Remember that the local player finished this quest so the localDone check
    -- passes on any subsequent call triggered by a remote player's SQ_UPDATE.
    if localHasCompleted then
        selfFinishedQuests[questID] = true
    end

    local PlayerQuests = SocialQuestGroupData.PlayerQuests

    -- Must be in a group (PlayerQuests only contains remote members).
    local anyRemote = false
    for _ in pairs(PlayerQuests) do anyRemote = true; break end
    if not anyRemote then
        SocialQuest:Debug("Banner", "All completed suppressed: not in group")
        return
    end

    -- Every group member must have a data source (SQ or bridge); suppress if any has neither.
    -- Without full visibility, we cannot reliably confirm that everyone has completed.
    for _, entry in pairs(PlayerQuests) do
        if not entry.hasSocialQuest and not entry.dataProvider then
            SocialQuest:Debug("Banner", "All completed suppressed: member with no data present (hasSQ=" .. tostring(entry.hasSocialQuest) .. " dp=" .. tostring(entry.dataProvider) .. ")")
            return
        end
    end

    local AQL = SocialQuest.AQL

    -- Title of the triggering quest. Used as the primary method to match variant
    -- questIDs across players (same logical quest, different numeric IDs on Retail).
    local triggerTitle = AQL and AQL:GetQuestTitle(questID)

    -- Local player engagement.
    -- Primary: direct questID lookup (works when local has the exact same questID).
    -- Fallback: title-based scan of all local quests (handles Retail variant questIDs
    -- where the local player has questID_A but the trigger arrived with questID_B).
    local localQuest = AQL and AQL:GetQuest(questID)
    if not localQuest and triggerTitle and AQL then
        for _, q in pairs(AQL:GetAllQuests()) do
            if q.title == triggerTitle then
                localQuest = q
                break
            end
        end
    end
    local localActive  = localQuest ~= nil
    local localEngaged = localHasCompleted or localActive
    local localDone    = localHasCompleted
                      or selfFinishedQuests[questID]
                      or (localQuest and localQuest.isComplete)
                      or (AQL and AQL:HasCompletedQuest(questID))
    if localEngaged and not localDone then
        SocialQuest:Debug("Banner", "All completed suppressed: local player engaged but not done")
        return
    end

    -- Remote players: check engagement and objective completion.
    -- Priority order for finding a player's quest:
    --   1. Title match in entry.quests (primary; handles Retail variant questIDs)
    --   2. Direct questID match in entry.quests (fallback when title is nil or unresolved)
    --   3. Direct questID in completedQuests (turned in before we checked)
    --   4. Title match in completedQuests via AQL lookup (fallback)
    local anyEngaged = localEngaged
    local anyRemoteEngaged = false
    for _, entry in pairs(PlayerQuests) do
        local matchedQuestData = nil

        -- 1. Title match.
        if entry.quests and triggerTitle then
            for _, qdata in pairs(entry.quests) do
                if qdata.title and qdata.title == triggerTitle then
                    matchedQuestData = qdata
                    break
                end
            end
        end

        -- 2. Direct questID match (fallback when triggerTitle is nil or qdata.title is nil).
        if not matchedQuestData and entry.quests then
            matchedQuestData = entry.quests[questID]
        end

        -- Note: completedQuests is intentionally NOT checked here. That table is
        -- populated from SQ_RESP_COMPLETE which sends AQL:GetCompletedQuests() —
        -- the player's entire quest history. Checking it would cause false positives
        -- whenever a player has previously completed the quest (e.g. a daily, or any
        -- quest the other party member has already done). Only entry.quests (active
        -- quests this session) is used for engagement detection.

        local engaged = matchedQuestData ~= nil
        if engaged then
            anyEngaged = true
            anyRemoteEngaged = true
            local done = matchedQuestData.isComplete
            if not done then
                SocialQuest:Debug("Banner", "All completed suppressed: not all engaged players completed")
                return
            end
        end
    end

    -- No one in the group has or had the quest, or no remote player was engaged.
    if not anyEngaged or not anyRemoteEngaged then
        SocialQuest:Debug("Banner", "All completed suppressed: no remote players engaged")
        return
    end

    -- Display gating: same toggle as the individual "objectives done" banners.
    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.display.finished then
        SocialQuest:Debug("Banner", "All completed suppressed: display.finished off")
        return
    end

    -- Title resolution: plain text — RaidNotice does not parse hyperlinks.
    local info  = AQL and AQL:GetQuest(questID)
    local title = (info and info.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)

    local msg = string.format(L["Everyone has completed: %s"], title)
    SocialQuest:Debug("Banner", "All completed: questID=" .. questID .. " \xe2\x80\x94 banner scheduled")

    -- Delay the banner so it fires after the objective-complete and quest-finished
    -- banners that precede it in the same Lua frame. RaidWarningFrame holds at most
    -- ~2 messages; without the delay the "Everyone has completed" message is dropped
    -- because the queue is already full when it arrives.
    SQWowAPI.TimerAfter(2, function()
        displayBanner(msg, "all_complete")
    end)

    -- Chat message only when the local player triggered it (avoids duplicate
    -- sends from multiple SQ clients simultaneously detecting the same condition).
    -- Sent immediately — chat does not share the RaidWarningFrame queue.
    if localHasCompleted and sectionDb.transmit and sectionDb.announce.finished then
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

    -- Defense-in-depth: bridge providers cannot verify Completed/Abandoned/Failed
    -- (remove packet carries no reason code). Block them here regardless of call site.
    local pdata    = SocialQuestGroupData.PlayerQuests[sender]
    local provider = pdata and pdata.dataProvider
    if provider and provider ~= SocialQuest.DataProviders.SocialQuest then
        if eventType == ET.Completed
        or eventType == ET.Abandoned
        or eventType == ET.Failed then
            return
        end
    end

    -- Party-wide objectives check: fires regardless of displayReceived, because
    -- "Everyone has completed" is a synthesized local event, not a raw inbound banner.
    if eventType == ET.Finished then
        checkAllCompleted(questID, false)
    end

    if not db.general.displayReceived then
        SocialQuest:Debug("Banner", "Banner suppressed: displayReceived off")
        return
    end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then
        SocialQuest:Debug("Banner", "Banner suppressed: section displayReceived off")
        return
    end
    if not sectionDb.display[eventType] then
        SocialQuest:Debug("Banner", "Banner suppressed: display." .. eventType .. " off")
        return
    end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not SQWowAPI.IsFriend(sender) then
        SocialQuest:Debug("Banner", "Banner suppressed: friends-only filter")
        return
    end
    if section == "battleground" and db.battleground.friendsOnly
        and not SQWowAPI.IsFriend(sender) then
        SocialQuest:Debug("Banner", "Banner suppressed: friends-only filter")
        return
    end

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
        msg = appendChainStep(msg, eventType, chainInfo, sender)
        SocialQuest:Debug("Banner", "Banner: " .. eventType .. " from " .. sender .. " \xe2\x80\x94 " .. (title or "?"))
        displayBanner(msg, eventType)
    end
end

function SocialQuestAnnounce:OnRemoteObjectiveEvent(sender, questID, objIndex, numFulfilled, numRequired, isComplete, isRegression)
    local db = SocialQuest.db.profile
    if not db.enabled or not db.general.displayReceived then
        SocialQuest:Debug("Banner", "Banner suppressed: addon or displayReceived off")
        return
    end

    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.displayReceived then
        SocialQuest:Debug("Banner", "Banner suppressed: section displayReceived off")
        return
    end

    local eventType = isComplete and ET.ObjectiveComplete or ET.ObjectiveProgress
    if not sectionDb.display[eventType] then
        SocialQuest:Debug("Banner", "Banner suppressed: display." .. eventType .. " off")
        return
    end

    -- Friends-only filter.
    if section == "raid" and db.raid.friendsOnly
        and not SQWowAPI.IsFriend(sender) then
        SocialQuest:Debug("Banner", "Banner suppressed: friends-only filter")
        return
    end
    if section == "battleground" and db.battleground.friendsOnly
        and not SQWowAPI.IsFriend(sender) then
        SocialQuest:Debug("Banner", "Banner suppressed: friends-only filter")
        return
    end

    local AQL     = SocialQuest.AQL
    local objs    = AQL and AQL:GetQuestObjectives(questID)
    local objInfo = objs and objs[objIndex]
    local objText = (objInfo and objInfo.name) or ""
    local title   = (AQL and AQL:GetQuestTitle(questID))
                 or ("Quest " .. questID)

    local msg = formatObjectiveBannerMsg(sender, title, objText, numFulfilled, numRequired, isComplete, isRegression)
    SocialQuest:Debug("Banner", "Banner: " .. eventType .. " from " .. sender .. " \xe2\x80\x94 questID=" .. questID)
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
    -- Hook UIErrorsFrame:AddMessage instead of the OnEvent handler.
    -- On Retail, GetScript("OnEvent") returns nil (the handler is XML-defined), so
    -- the old GetScript/SetScript pattern bailed out immediately and suppressed nothing.
    -- AddMessage is the common display path on all WoW version families regardless of
    -- how the event reached the frame; hooking it here handles both TBC and Retail.
    local origAddMessage = UIErrorsFrame.AddMessage
    if not origAddMessage then return end
    UIErrorsFrame.AddMessage = function(self, msg, ...)
        local db = SocialQuest.db.profile
        local AQL = SocialQuest.AQL
        if db and db.enabled and db.general.displayOwn then
            -- Suppress count-based objective text (e.g. "Tainted Ooze killed: 4/10")
            -- when either progress or complete own-banner is enabled.
            if (db.general.displayOwnEvents.objective_progress
                    or db.general.displayOwnEvents.objective_complete)
                    and AQL and AQL:IsQuestObjectiveText(msg) then
                return
            end
            -- Suppress WoW's standalone "Objective Complete" notification.
            -- Case-insensitive: TBC sends "Objective complete" (lowercase c).
            -- QUEST_WATCH_OBJECTIVE_COMPLETE is nil on Retail; fallback covers both.
            if db.general.displayOwnEvents.objective_complete then
                local globalText = QUEST_WATCH_OBJECTIVE_COMPLETE
                local target = string.lower(globalText or "objective complete")
                -- Strip trailing period before comparing: Retail sends "Objective Complete."
                local msgNorm = string.lower(tostring(msg or "")):match("^(.-)%.?$") or ""
                if msgNorm == target then
                    return
                end
            end
        end
        return origAddMessage(self, msg, ...)
    end
end

------------------------------------------------------------------------
-- Debug test entry point
------------------------------------------------------------------------

-- "objective_regression" is a pseudo-type used only by the test panel; it shares
-- the objective_progress color and toggle but has distinct demo text.
local TEST_DEMOS = {
    accepted = {
        outbound = "{rt1} SocialQuest: Quest Accepted: |cFFFFD200[A Daunting Task]|r (Step 2)",
        banner   = "TestPlayer accepted: [A Daunting Task] (Step 2)",
        colorKey = "accepted",
    },
    abandoned = {
        outbound = "{rt1} SocialQuest: Quest Abandoned: |cFFFFD200[A Daunting Task]|r (Step 2)",
        banner   = "TestPlayer abandoned: [A Daunting Task] (Step 2)",
        colorKey = "abandoned",
    },
    finished = {
        outbound = "{rt1} SocialQuest: Quest Complete: |cFFFFD200[A Daunting Task]|r",
        banner   = "TestPlayer completed: [A Daunting Task]",
        colorKey = "finished",
    },
    completed = {
        outbound = "{rt1} SocialQuest: Quest Turned In: |cFFFFD200[A Daunting Task]|r (Step 2)",
        banner   = "TestPlayer turned in: [A Daunting Task] (Step 2)",
        colorKey = "completed",
    },
    failed = {
        outbound = "{rt1} SocialQuest: Quest Failed: |cFFFFD200[A Daunting Task]|r (Step 2)",
        banner   = "TestPlayer failed: [A Daunting Task] (Step 2)",
        colorKey = "failed",
    },
    objective_progress = {
        outbound = "{rt1} SocialQuest: 3/8 Kobolds Slain for |cFFFFD200[A Daunting Task]|r!",
        banner   = "TestPlayer progressed: [A Daunting Task] — Kobolds Slain (3/8)",
        colorKey = "objective_progress",
    },
    objective_complete = {
        outbound = "{rt1} SocialQuest: 8/8 Kobolds Slain for |cFFFFD200[A Daunting Task]|r!",
        banner   = "TestPlayer completed objective: [A Daunting Task] — Kobolds Slain (8/8)",
        colorKey = "objective_complete",
    },
    objective_regression = {
        outbound = "{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for |cFFFFD200[A Daunting Task]|r!",
        banner   = "TestPlayer regressed: [A Daunting Task] — Kobolds Slain (2/8)",
        colorKey = "objective_progress",   -- same color as progress
    },
    all_complete = {
        outbound = nil,   -- no outbound chat for this synthesized event
        banner   = "Everyone has completed: [A Daunting Task]",
        colorKey = "all_complete",
    },
}

function SocialQuestAnnounce:TestEvent(eventType)
    local demo = TEST_DEMOS[eventType]
    if not demo then return end
    displayBanner(demo.banner, demo.colorKey)
    if demo.outbound then
        displayChatPreview(demo.outbound)
    end
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
    local msg = string.format(L["%s started following you."], sender)
    SocialQuest:Print(msg)
    displayBanner(msg, "follow")
end

function SocialQuestAnnounce:OnFollowStop(sender)
    local db = SocialQuest.db.profile
    if not db.follow.enabled or not db.follow.announceFollowed then return end
    local msg = string.format(L["%s stopped following you."], sender)
    SocialQuest:Print(msg)
    displayBanner(msg, "follow")
end

function SocialQuestAnnounce:TestFollowNotification()
    local msg = string.format(L["%s started following you."], "TestPlayer")
    displayBanner(msg, "follow")
end

------------------------------------------------------------------------
-- Whisper friends helper
------------------------------------------------------------------------

function SocialQuestAnnounce:WhisperFriends(msg, groupOnly)
    local numFriends = SQWowAPI.GetNumFriends()
    for i = 1, numFriends do
        local info = SQWowAPI.GetFriendInfoByIndex(i)
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
    local numMembers = SQWowAPI.GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = SQWowAPI.IsInRaid() and ("raid"..i) or ("party"..i)
        local unitName = SQWowAPI.UnitName(unit)
        if unitName == name then return true end
    end
    return false
end
