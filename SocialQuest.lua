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
    -- Dot-notation is required: AQL is the target in CallbackHandler, so
    -- AQL:RegisterCallback() would set self==target and trigger a guard error.
    AQL.RegisterCallback(self, "AQL_QUEST_ACCEPTED",         "OnQuestAccepted")
    AQL.RegisterCallback(self, "AQL_QUEST_ABANDONED",        "OnQuestAbandoned")
    AQL.RegisterCallback(self, "AQL_QUEST_FINISHED",         "OnQuestFinished")
    AQL.RegisterCallback(self, "AQL_QUEST_COMPLETED",        "OnQuestCompleted")
    AQL.RegisterCallback(self, "AQL_QUEST_FAILED",           "OnQuestFailed")
    AQL.RegisterCallback(self, "AQL_QUEST_TRACKED",          "OnQuestTracked")
    AQL.RegisterCallback(self, "AQL_QUEST_UNTRACKED",        "OnQuestUntracked")
    AQL.RegisterCallback(self, "AQL_OBJECTIVE_PROGRESSED",   "OnObjectiveProgressed")
    AQL.RegisterCallback(self, "AQL_OBJECTIVE_REGRESSED",    "OnObjectiveRegressed")
    AQL.RegisterCallback(self, "AQL_OBJECTIVE_COMPLETED",    "OnObjectiveCompleted")
    AQL.RegisterCallback(self, "AQL_UNIT_QUEST_LOG_CHANGED", "OnUnitQuestLogChanged")

    -- Minimap button via LibDBIcon-1.0.
    -- SocialQuestGroupFrame is a global defined in UI/GroupFrame.lua (loaded earlier).
    local LDB    = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and DBIcon then
        -- Guard against double-registration on unexpected second OnEnable call.
        local launcher = LDB:GetDataObjectByName("SocialQuest")
            or LDB:NewDataObject("SocialQuest", {
            type  = "launcher",
            icon  = "Interface\\Icons\\INV_Misc_GroupNeedMore",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    SocialQuestGroupFrame:Toggle()
                elseif button == "RightButton" then
                    LibStub("AceConfigDialog-3.0"):Open("SocialQuest")
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:SetText("SocialQuest")
                tooltip:AddLine("Left-click to open group quest frame.", 1, 1, 1)
                tooltip:AddLine("Right-click to open settings.", 1, 1, 1)
                tooltip:Show()
            end,
        })
        if not DBIcon:GetMinimapButton("SocialQuest") then
            DBIcon:Register("SocialQuest", launcher, self.db.profile.minimap)
        end
    end
end

function SocialQuest:OnDisable()
    if AQL then
        AQL.UnregisterCallback(self, "AQL_QUEST_ACCEPTED")
        AQL.UnregisterCallback(self, "AQL_QUEST_ABANDONED")
        AQL.UnregisterCallback(self, "AQL_QUEST_FINISHED")
        AQL.UnregisterCallback(self, "AQL_QUEST_COMPLETED")
        AQL.UnregisterCallback(self, "AQL_QUEST_FAILED")
        AQL.UnregisterCallback(self, "AQL_QUEST_TRACKED")
        AQL.UnregisterCallback(self, "AQL_QUEST_UNTRACKED")
        AQL.UnregisterCallback(self, "AQL_OBJECTIVE_PROGRESSED")
        AQL.UnregisterCallback(self, "AQL_OBJECTIVE_REGRESSED")
        AQL.UnregisterCallback(self, "AQL_OBJECTIVE_COMPLETED")
        AQL.UnregisterCallback(self, "AQL_UNIT_QUEST_LOG_CHANGED")
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
                displayReceived  = true,
                colorblindMode   = false,
                displayOwn       = false,
                displayOwnEvents = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = true,
                    objective_complete = true,
                },
            },
            party = {
                transmit        = true,
                displayReceived = true,
                announce = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = true,
                    objective_complete = true,
                },
                display = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = true,
                    objective_complete = true,
                },
            },
            raid = {
                transmit        = true,
                displayReceived = true,
                friendsOnly     = false,
                announce = { accepted=false, abandoned=false, finished=false, completed=false, failed=false },
                display = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = true,
                    objective_complete = true,
                },
            },
            guild = {
                transmit = false,
                announce = { accepted=false, abandoned=false, finished=false, completed=false, failed=false },
            },
            battleground = {
                transmit        = true,
                displayReceived = true,
                friendsOnly     = false,
                announce = {
                    accepted           = false,
                    abandoned          = false,
                    finished           = false,
                    completed          = false,
                    failed             = false,
                    objective_progress = false,
                    objective_complete = false,
                },
                display = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = true,
                    objective_complete = true,
                },
            },
            whisperFriends = {
                enabled   = false,
                groupOnly = false,
                announce = {
                    accepted           = true,
                    abandoned          = true,
                    finished           = true,
                    completed          = true,
                    failed             = true,
                    objective_progress = false,
                    objective_complete = false,
                },
            },
            follow = {
                enabled = true,
                announceFollowing = true,
                announceFollowed  = true,
            },
            debug = {
                enabled = false,
            },
            minimap = { hide = false },
            -- LibDBIcon writes minimapPos into this table automatically when dragged.
            frameState = {
                activeTab = "shared",
                collapsedZones = {
                    mine   = {},
                    party  = {},
                    shared = {},
                },
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
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
end

function SocialQuest:OnQuestFinished(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
end

function SocialQuest:OnQuestFailed(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
end

function SocialQuest:OnQuestTracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "tracked")
end

function SocialQuest:OnQuestUntracked(event, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "untracked")
end

function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
end

function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
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
