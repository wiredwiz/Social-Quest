-- SocialQuest.lua
-- AceAddon entry point. Handles OnInitialize, OnEnable, and AQL callback
-- registration. All quest logic delegates to sub-modules.

SocialQuest = LibStub("AceAddon-3.0"):NewAddon(
    "SocialQuest",
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceTimer-3.0",
    "AceConsole-3.0"
)

local AQL  -- set in OnInitialize

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

function SocialQuest:OnInitialize()
    -- Verify AQL is present before doing anything else.
    AQL = LibStub("AbsoluteQuestLog-1.0", true)
    if not AQL then
        self:Print("|cFFFF0000ERROR:|r AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled.")
        return
    end

    -- AceDB sets up saved variables. Profile key "Default" shared across chars.
    self.db = LibStub("AceDB-3.0"):New("SocialQuestDB", self:GetDefaults(), true)

    -- Expose AQL to sub-modules that need it.
    self.AQL = AQL

    -- Register options panel.
    SocialQuestOptions:Initialize()
end

function SocialQuest:OnEnable()
    if not self.AQL then return end  -- AQL missing; stay dormant.

    -- Register AceComm prefixes.
    SocialQuestComm:Initialize()

    -- Register tooltips hook.
    SocialQuestTooltips:Initialize()

    -- Register WoW events (non-quest; quest events come via AQL callbacks).
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("AUTOFOLLOW_BEGIN",    "OnAutoFollowBegin")
    self:RegisterEvent("AUTOFOLLOW_END",      "OnAutoFollowEnd")

    -- Register AQL callbacks.
    AQL:RegisterCallback("AQL_QUEST_ACCEPTED",        self, self.OnQuestAccepted)
    AQL:RegisterCallback("AQL_QUEST_ABANDONED",       self, self.OnQuestAbandoned)
    AQL:RegisterCallback("AQL_QUEST_FINISHED",        self, self.OnQuestFinished)
    AQL:RegisterCallback("AQL_QUEST_COMPLETED",       self, self.OnQuestCompleted)
    AQL:RegisterCallback("AQL_QUEST_FAILED",          self, self.OnQuestFailed)
    AQL:RegisterCallback("AQL_QUEST_TRACKED",         self, self.OnQuestTracked)
    AQL:RegisterCallback("AQL_QUEST_UNTRACKED",       self, self.OnQuestUntracked)
    AQL:RegisterCallback("AQL_OBJECTIVE_PROGRESSED",  self, self.OnObjectiveProgressed)
    AQL:RegisterCallback("AQL_OBJECTIVE_REGRESSED",   self, self.OnObjectiveRegressed)
    AQL:RegisterCallback("AQL_UNIT_QUEST_LOG_CHANGED",self, self.OnUnitQuestLogChanged)
end

function SocialQuest:OnDisable()
    if AQL then
        AQL:UnregisterCallback("AQL_QUEST_ACCEPTED",         self)
        AQL:UnregisterCallback("AQL_QUEST_ABANDONED",        self)
        AQL:UnregisterCallback("AQL_QUEST_FINISHED",         self)
        AQL:UnregisterCallback("AQL_QUEST_COMPLETED",        self)
        AQL:UnregisterCallback("AQL_QUEST_FAILED",           self)
        AQL:UnregisterCallback("AQL_QUEST_TRACKED",          self)
        AQL:UnregisterCallback("AQL_QUEST_UNTRACKED",        self)
        AQL:UnregisterCallback("AQL_OBJECTIVE_PROGRESSED",   self)
        AQL:UnregisterCallback("AQL_OBJECTIVE_REGRESSED",    self)
        AQL:UnregisterCallback("AQL_UNIT_QUEST_LOG_CHANGED", self)
    end
end

------------------------------------------------------------------------
-- Default settings
------------------------------------------------------------------------

function SocialQuest:GetDefaults()
    return {
        profile = {
            enabled = true,
            general = {
                displayReceived = true,
                receive = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
            party = {
                transmit = true,
                displayReceived = true,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=true },
            },
            raid = {
                transmit = true,
                displayReceived = true,
                friendsOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
            guild = {
                transmit = true,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true },
            },
            battleground = {
                transmit = true,
                displayReceived = true,
                friendsOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=true },
            },
            whisperFriends = {
                enabled = false,
                groupOnly = false,
                announce = { accepted=true, abandoned=true, finished=true, completed=true, failed=true, objective=false },
            },
            follow = {
                enabled = true,
                announceFollowing = true,
                announceFollowed  = true,
            },
            debug = {
                enabled = false,
            },
        },
    }
end

------------------------------------------------------------------------
-- WoW event handlers
------------------------------------------------------------------------

function SocialQuest:OnGroupRosterUpdate()
    SocialQuestComm:OnGroupChanged()
    SocialQuestGroupData:OnGroupChanged()
end

function SocialQuest:OnAutoFollowBegin(event, unit)
    if not self.db.profile.follow.enabled then return end
    if not self.db.profile.follow.announceFollowing then return end
    local name = UnitName(unit)
    if name then
        SocialQuestComm:SendFollowStart(name)
    end
end

function SocialQuest:OnAutoFollowEnd()
    if not self.db.profile.follow.enabled then return end
    -- Find who we were following by iterating group.
    -- AUTOFOLLOW_END does not pass the unit; whisper is sent to last known follow target.
    -- Stored in SocialQuestComm.followTarget.
    local target = SocialQuestComm.followTarget
    if target then
        SocialQuestComm:SendFollowStop(target)
        SocialQuestComm.followTarget = nil
    end
end

------------------------------------------------------------------------
-- AQL Callback handlers
------------------------------------------------------------------------

function SocialQuest:OnQuestAccepted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
end

function SocialQuest:OnQuestFinished(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
end

function SocialQuest:OnQuestFailed(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
end

function SocialQuest:OnQuestTracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "tracked")
end

function SocialQuest:OnQuestUntracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "untracked")
end

function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    SocialQuestAnnounce:OnObjectiveEvent("objective", questInfo, objective)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    -- Broadcast regression so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
end

function SocialQuest:OnUnitQuestLogChanged(event, unit)
    -- Non-SocialQuest member changed their quest log. Sweep shared quests.
    SocialQuestGroupData:OnUnitQuestLogChanged(unit)
end

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------

SocialQuest:RegisterChatCommand("sq", function(input)
    local cmd = strtrim(input or "")
    if cmd == "config" then
        LibStub("AceConfigDialog-3.0"):Open("SocialQuest")
    else
        SocialQuestGroupFrame:Toggle()
    end
end)
