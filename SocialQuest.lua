-- SocialQuest.lua
-- AceAddon entry point. Handles OnInitialize, OnEnable, and AQL callback
-- registration. All quest logic delegates to sub-modules.

-- Key binding display strings. WoW reads these globals to populate the
-- Key Bindings UI (Options → Key Bindings → AddOns → Social Quest).
BINDING_HEADER_SOCIALQUEST_HEADER = "Social Quest"
BINDING_NAME_SOCIALQUEST_TOGGLE   = "Toggle Social Quest Window"

SocialQuest = LibStub("AceAddon-3.0"):NewAddon(
    "SocialQuest",
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceTimer-3.0",
    "AceConsole-3.0"
)

local AQL  -- set in OnInitialize
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

function SocialQuest:OnInitialize()
    -- Verify AQL is present before doing anything else.
    AQL = LibStub("AbsoluteQuestLog-1.0", true)
    if not AQL then
        self:Print(L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."])
        return
    end

    -- AceDB sets up saved variables. Profile key "Default" shared across chars.
    self.db = LibStub("AceDB-3.0"):New("SocialQuestDB", self:GetDefaults(), true)

    -- Expose AQL to sub-modules that need it.
    self.AQL = AQL

    -- Register options panel.
    SocialQuestOptions:Initialize()

    -- Hook UIErrorsFrame_OnEvent to suppress the default objective progress
    -- notification when Social Quest's own banner is active.
    SocialQuestAnnounce:InitEventHooks()
end

function SocialQuest:OnEnable()
    if not self.AQL then return end  -- AQL missing; stay dormant.

    -- Suppress AQL quest callbacks for this many seconds after a zone transition.
    -- AQL rebuilds its snapshot on PLAYER_ENTERING_WORLD and re-fires accepted/finished/etc.
    -- for every quest in the log; we must not re-announce or re-broadcast those.
    self.zoneTransitionSuppressUntil = 0

    -- Pending regression timer handles, keyed by "questID_objIndex".
    -- AQL_OBJECTIVE_REGRESSED is debounced: if AQL_OBJECTIVE_PROGRESSED arrives for
    -- the same objective within 0.5 s, the regression is a BAG_UPDATE stack-split
    -- artefact and is silently cancelled.
    self.pendingRegressions = {}

    -- Initialize group composition tracker.
    SocialQuestGroupComposition:Initialize()

    -- Register AceComm prefixes.
    SocialQuestComm:Initialize()

    -- Register tooltips hook.
    SocialQuestTooltips:Initialize()

    -- Register WoW events (non-quest; quest events come via AQL callbacks).
    self:RegisterEvent("GROUP_ROSTER_UPDATE",   "OnGroupRosterUpdate")
    self:RegisterEvent("PLAYER_LOGIN",          "OnPlayerLogin")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("AUTOFOLLOW_BEGIN",      "OnAutoFollowBegin")
    self:RegisterEvent("AUTOFOLLOW_END",        "OnAutoFollowEnd")

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
                tooltip:AddLine(L["Left-click to open group quest frame."], 1, 1, 1)
                tooltip:AddLine(L["Right-click to open settings."], 1, 1, 1)
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
-- Debug helper
------------------------------------------------------------------------

function SocialQuest:Debug(tag, msg)
    if not self.db.profile.debug.enabled then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD200[SQ][" .. tag .. "]|r " .. tostring(msg))
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
            flightPath = {
                enabled         = true,   -- broadcast my discoveries to party
                announceBanners = true,   -- display banners when party members discover paths
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
        char = {
            knownFlightNodes = {},  -- [nodeName] = true; persists across sessions
        },
    }
end

------------------------------------------------------------------------
-- WoW event handlers
------------------------------------------------------------------------

function SocialQuest:OnGroupRosterUpdate()
    SocialQuestGroupComposition:OnGroupRosterUpdate()
end

-- Re-sync quest data with group after a UI reload (PLAYER_LOGIN fires on /reload).
function SocialQuest:OnPlayerLogin()
    SocialQuestGroupComposition:OnPlayerLogin()
end

-- PLAYER_ENTERING_WORLD fires on every zone transition (including hearthing and /reload).
-- AQL rebuilds its quest snapshot immediately afterward and fires AQL_QUEST_ACCEPTED /
-- AQL_QUEST_FINISHED / etc. for every quest already in the log.  Suppress announces and
-- broadcasts for 3 seconds so those replay events are not treated as new activity.
-- The /reload case is harmless (PLAYER_LOGIN fires first and re-syncs the group; the
-- suppression window just silences the redundant AQL replay that follows).
function SocialQuest:OnPlayerEnteringWorld()
    self.zoneTransitionSuppressUntil = GetTime() + 3
    self:Debug("Zone", "Zone transition detected — suppressing AQL callbacks for 3 s")
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
    if GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest accepted: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    if GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest abandoned: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent("abandoned", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "abandoned")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestFinished(event, questInfo)
    if GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest finished: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    -- questInfo intentionally NOT passed: "finished" is excluded from chain-step
    -- annotation. See CHAIN_STEP_EVENTS in Core/Announcements.lua.
    SocialQuestAnnounce:OnQuestEvent("finished", questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "finished")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    if GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest completed: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent("completed", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "completed")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestFailed(event, questInfo)
    if GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest failed: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent("failed", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "failed")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestTracked(event, questInfo)
    -- Tracking changes have no meaning for remote group members' data; refresh locally only.
    self:Debug("Quest", "Quest tracked: (id=" .. questInfo.questID .. ")")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestUntracked(event, questInfo)
    -- Tracking changes have no meaning for remote group members' data; refresh locally only.
    self:Debug("Quest", "Quest untracked: (id=" .. questInfo.questID .. ")")
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveProgressed(event, questInfo, objective, delta)
    if GetTime() < self.zoneTransitionSuppressUntil then return end

    -- Cancel any pending regression debounce for this objective.
    -- When a BAG_UPDATE stack split causes a temporary count dip, AQL fires
    -- REGRESSED then PROGRESSED in rapid succession. Cancelling here prevents
    -- the false regression from being broadcast or announced.
    local key = questInfo.questID .. "_" .. (objective.index or 0)
    if self.pendingRegressions[key] then
        self:Debug("Quest", "Regression debounce cancelled for questID=" .. questInfo.questID .. " obj=" .. (objective.index or 0))
        self:CancelTimer(self.pendingRegressions[key])
        self.pendingRegressions[key] = nil
    end

    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    self:Debug("Quest", "Objective " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    if GetTime() < self.zoneTransitionSuppressUntil then return end

    -- Also cancel any pending regression debounce (objective completed = not regressed).
    local key = questInfo.questID .. "_" .. (objective.index or 0)
    if self.pendingRegressions[key] then
        self:CancelTimer(self.pendingRegressions[key])
        self.pendingRegressions[key] = nil
    end

    self:Debug("Quest", "Objective complete " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    if GetTime() < self.zoneTransitionSuppressUntil then return end

    -- Debounce: delay by 0.5 s. If PROGRESSED or COMPLETED fires for the same
    -- objective within that window, the timer is cancelled — indicating a transient
    -- BAG_UPDATE stack-split artefact rather than a genuine regression.
    local key = questInfo.questID .. "_" .. (objective.index or 0)
    if self.pendingRegressions[key] then
        self:CancelTimer(self.pendingRegressions[key])
    end
    self.pendingRegressions[key] = self:ScheduleTimer(function()
        self.pendingRegressions[key] = nil
        self:Debug("Quest", "Objective regression " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
        SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
        SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
        SocialQuestGroupFrame:RequestRefresh()
    end, 0.5)
end

function SocialQuest:OnUnitQuestLogChanged(event, unit)
    -- Non-SocialQuest member changed their quest log. Sweep shared quests.
    SocialQuestGroupData:OnUnitQuestLogChanged(unit)
    SocialQuestGroupFrame:RequestRefresh()
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
