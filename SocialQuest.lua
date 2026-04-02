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

SocialQuest.DataProviders = {
    SocialQuest = "SocialQuest",
    Questie     = "Questie",
}

SocialQuest.EventTypes = {
    Accepted          = "accepted",
    Completed         = "completed",         -- turned in to NPC
    Abandoned         = "abandoned",
    Failed            = "failed",
    Finished          = "finished",          -- all objectives done, not yet turned in
    Tracked           = "tracked",
    Untracked         = "untracked",
    ObjectiveComplete = "objective_complete",
    ObjectiveProgress = "objective_progress",
}

local AQL  -- set in OnInitialize
local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

local SQWowAPI = SocialQuestWowAPI
local SQWowUI  = SocialQuestWowUI

local ET = SocialQuest.EventTypes

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

    -- When the player resets their profile, also reset char-scoped frame state
    -- so the quest window reverts to defaults (tab = Shared, all zones expanded,
    -- scroll positions = 0).
    -- Dot-call (not colon): self.db is the CallbackHandler target, not the
    -- method receiver. Colon would pass self.db as target instead of self.
    self.db.RegisterCallback(self, "OnProfileReset", function()
        self.db.char.frameState = {
            activeTab          = "shared",
            collapsedZones     = { mine = {}, party = {}, shared = {} },
            tabScrollPositions = { mine = 0,  party = 0,  shared = 0  },
            tabContentHeights  = { mine = 0,  party = 0,  shared = 0  },
            windowOpen         = false,
            activeFilters      = {},
            helpWindowOpen     = false,
            helpWindowPos      = nil,
        }
        SocialQuestGroupFrame:ResetFrameState()
    end)

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

    -- Initialize group composition tracker.
    SocialQuestGroupComposition:Initialize()

    -- Register AceComm prefixes.
    SocialQuestComm:Initialize()

    -- Raw CHAT_MSG_ADDON debug listener, independent of AceComm.
    -- Fires for every CHAT_MSG_ADDON that WoW delivers (prefix must be registered
    -- for the event to fire at all; unregistered prefixes go to CHAT_MSG_ADDON_FILTERED).
    -- This tells us whether the event fires at the WoW level before AceComm touches it.
    if not self._rawCommFrame then
        self._rawCommFrame = CreateFrame("Frame")
        self._rawCommFrame:RegisterEvent("CHAT_MSG_ADDON")
        self._rawCommFrame:SetScript("OnEvent", function(_, _, prefix, _, dist, sender)
            if not (prefix and prefix:sub(1, 3) == "SQ_") then return end
            if not SocialQuest.db or not SocialQuest.db.profile.debug.enabled then return end
            SQWowUI.AddChatMessage(
                "|cFF00FF88[SQ][CHAT_MSG_ADDON]|r prefix=" .. prefix ..
                " dist=" .. tostring(dist) ..
                " sender=" .. tostring(sender)
            )
        end)
    end

    -- Register tooltips hook.
    SocialQuestTooltips:Initialize()

    -- Register WoW events (non-quest; quest events come via AQL callbacks).
    self:RegisterEvent("GROUP_ROSTER_UPDATE",   "OnGroupRosterUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("AUTOFOLLOW_BEGIN",        "OnAutoFollowBegin")
    self:RegisterEvent("AUTOFOLLOW_END",          "OnAutoFollowEnd")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA",   "OnZoneChangedNewArea")
    self:RegisterEvent("PLAYER_CONTROL_GAINED",   "OnPlayerControlGained")
    self:RegisterEvent("PLAYER_LEAVING_WORLD",    "OnPlayerLeavingWorld")

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

    -- Bootstrap group state now. On Retail, GROUP_ROSTER_UPDATE fires before
    -- OnEnable registers for it, and PLAYER_LOGIN has already passed by the time
    -- we could register OnPlayerLogin — so neither event-driven path runs.
    -- Calling directly here ensures we always detect an existing group on load/reload.
    SocialQuestGroupComposition:OnGroupRosterUpdate()

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
    SQWowUI.AddChatMessage("|cFFFFD200[SQ][" .. tag .. "]|r " .. tostring(msg))
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
            window = {
                autoFilterInstance = true,
                autoFilterZone     = false,
            },
            minimap = { hide = false },
            -- LibDBIcon writes minimapPos into this table automatically when dragged.
        },
        char = {
            frameState = {
                activeTab = "shared",
                collapsedZones = {
                    mine   = {},
                    party  = {},
                    shared = {},
                },
                tabScrollPositions = {
                    mine   = 0,
                    party  = 0,
                    shared = 0,
                },
                tabContentHeights = {
                    mine   = 0,
                    party  = 0,
                    shared = 0,
                },
                windowOpen  = false,
                frameX      = nil,  -- saved absolute screen position (TOPLEFT corner)
                frameY      = nil,
                frameWidth  = nil,
                frameHeight    = nil,
                -- Advanced filter language (Feature #18)
                activeFilters  = {},    -- [canonical] = { descriptor={...}, raw="..." }
                helpWindowOpen = false,
                helpWindowPos  = nil,   -- { x=N, y=N } or nil (use default position)
            },
        },
    }
end

------------------------------------------------------------------------
-- WoW event handlers
------------------------------------------------------------------------

function SocialQuest:OnGroupRosterUpdate()
    SocialQuestGroupComposition:OnGroupRosterUpdate()
end

-- PLAYER_LEAVING_WORLD fires before WoW calls CloseAllWindows() on a zone transition.
-- Snapshot the SQ window open state now, while the frame is still shown, so we can
-- restore it after the loading screen.
function SocialQuest:OnPlayerLeavingWorld()
    self:Debug("Zone", "Leaving world — snapshotting SQ window state")
    SocialQuestGroupFrame:OnLeavingWorld()
end

-- PLAYER_ENTERING_WORLD fires on every zone transition (including hearthing and /reload).
-- AQL rebuilds its quest snapshot immediately afterward and fires AQL_QUEST_ACCEPTED /
-- AQL_QUEST_FINISHED / etc. for every quest already in the log.  Suppress announces and
-- broadcasts for 3 seconds so those replay events are not treated as new activity.
-- The /reload case is harmless (PLAYER_LOGIN fires first and re-syncs the group; the
-- suppression window just silences the redundant AQL replay that follows).
function SocialQuest:OnPlayerEnteringWorld()
    self.zoneTransitionSuppressUntil = SQWowAPI.GetTime() + 3
    self:Debug("Zone", "Zone transition detected — suppressing AQL callbacks for 3 s")
    SocialQuestWindowFilter:Reset()
    SocialQuestGroupFrame:RestoreAfterTransition()
end

-- ZONE_CHANGED_NEW_AREA fires on seamless overland zone-border crossings (e.g. riding
-- from Elwynn Forest into Westfall). PLAYER_ENTERING_WORLD does NOT fire for these.
-- Reset the filter so the new zone name is used and refresh the window.
function SocialQuest:OnZoneChangedNewArea()
    self:Debug("Zone", "Zone area changed — resetting window filter")
    SocialQuestWindowFilter:Reset()
    SocialQuestGroupFrame:RequestRefresh()
end

-- PLAYER_CONTROL_GAINED fires when the taxi system releases the player at the end of a
-- flight path. ZONE_CHANGED_NEW_AREA may have fired mid-flight for intermediate zone
-- crossings, but the player's actual destination zone may not have triggered a new event.
-- Reset and refresh here so the filter reflects wherever the player actually landed.
function SocialQuest:OnPlayerControlGained()
    self:Debug("Zone", "Player control gained — resetting window filter")
    SocialQuestWindowFilter:Reset()
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnAutoFollowBegin(event, unit)
    if not self.db.profile.follow.enabled then return end
    if not self.db.profile.follow.announceFollowing then return end
    local name = SQWowAPI.UnitName(unit)
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
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest accepted: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent(ET.Accepted, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Accepted)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestAbandoned(event, questInfo)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest abandoned: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent(ET.Abandoned, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Abandoned)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestFinished(event, questInfo)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest finished: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    -- questInfo intentionally NOT passed: "finished" is excluded from chain-step
    -- annotation. See CHAIN_STEP_EVENTS in Core/Announcements.lua.
    SocialQuestAnnounce:OnQuestEvent(ET.Finished, questInfo.questID)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Finished)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestCompleted(event, questInfo)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest completed: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent(ET.Completed, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Completed)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnQuestFailed(event, questInfo)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end
    self:Debug("Quest", "Quest failed: [" .. (questInfo.title or "?") .. "] (id=" .. questInfo.questID .. ")")
    SocialQuestAnnounce:OnQuestEvent(ET.Failed, questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, ET.Failed)
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
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    -- Always broadcast so remote PlayerQuests tables stay accurate.
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)

    -- Suppress progress announce when threshold is crossed; COMPLETED fires next.
    if objective.numFulfilled >= objective.numRequired then return end

    self:Debug("Quest", "Objective " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveCompleted(event, questInfo, objective)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    self:Debug("Quest", "Objective complete " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    -- Comm already broadcast by OnObjectiveProgressed. Only announce here.
    SocialQuestAnnounce:OnObjectiveEvent("objective_complete", questInfo, objective, false)
    SocialQuestGroupFrame:RequestRefresh()
end

function SocialQuest:OnObjectiveRegressed(event, questInfo, objective, delta)
    if SQWowAPI.GetTime() < self.zoneTransitionSuppressUntil then return end

    self:Debug("Quest", "Objective regression " .. objective.numFulfilled .. "/" .. objective.numRequired .. ": " .. (objective.name or "") .. " for [" .. (questInfo.title or "?") .. "]")
    SocialQuestComm:BroadcastObjectiveUpdate(questInfo, objective)
    SocialQuestAnnounce:OnObjectiveEvent("objective_progress", questInfo, objective, true)
    SocialQuestGroupFrame:RequestRefresh()
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
    elseif cmd == "diagnose" then
        local lines = {}
        local p = function(s) lines[#lines + 1] = tostring(s) end
        p("IsInRaid: " .. tostring(SQWowAPI.IsInRaid()))
        p("PARTY_CATEGORY_HOME: " .. tostring(SQWowAPI.PARTY_CATEGORY_HOME))
        p("PARTY_CATEGORY_INSTANCE: " .. tostring(SQWowAPI.PARTY_CATEGORY_INSTANCE))
        p("IsInGroup(HOME): " .. tostring(SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)))
        p("IsInGroup(INSTANCE): " .. tostring(SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)))
        p("IsInGroup(nil): " .. tostring(SQWowAPI.IsInGroup(nil)))
        p("GetActiveChannel: " .. tostring(SocialQuestComm:GetActiveChannel()))
        p("GetNumGroupMembers: " .. tostring(SQWowAPI.GetNumGroupMembers()))
        local selfName, selfRealm = SQWowAPI.UnitFullName("player")
        p("UnitFullName(player): " .. tostring(selfName) .. " / " .. tostring(selfRealm))
        p("UnitName(player): " .. tostring(SQWowAPI.UnitName("player")))
        local memberCount = SQWowAPI.GetNumGroupMembers()
        for i = 1, math.min(memberCount, 5) do
            local n, r = SQWowAPI.UnitName("party" .. i)
            p("party" .. i .. ": name=" .. tostring(n) .. " realm=" .. tostring(r))
        end
        local ms = SocialQuestGroupComposition.memberSet or {}
        local msCount = 0
        for k in pairs(ms) do msCount = msCount + 1; p("memberSet: " .. k) end
        if msCount == 0 then p("memberSet: (empty)") end
        local pqCount = 0
        for k, v in pairs(SocialQuestGroupData.PlayerQuests) do
            pqCount = pqCount + 1
            p("PlayerQuests: " .. k .. " hasSQ=" .. tostring(v.hasSocialQuest) .. " dp=" .. tostring(v.dataProvider))
        end
        if pqCount == 0 then p("PlayerQuests: (empty)") end
        p("debug.enabled: " .. tostring(SocialQuest.db.profile.debug.enabled))
        p("party.transmit: " .. tostring(SocialQuest.db.profile.party.transmit))
        p("zoneSuppress: " .. tostring(SQWowAPI.GetTime() < (SocialQuest.zoneTransitionSuppressUntil or 0)))
        if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
            local prefixes = { "SQ_INIT","SQ_UPDATE","SQ_OBJECTIVE","SQ_REQUEST","SQ_FOLLOW_START","SQ_FOLLOW_STOP","SQ_REQ_COMPLETED","SQ_RESP_COMPLETE" }
            for _, pfx in ipairs(prefixes) do
                p("prefix " .. pfx .. ": " .. tostring(C_ChatInfo.IsAddonMessagePrefixRegistered(pfx)))
            end
        else
            p("C_ChatInfo.IsAddonMessagePrefixRegistered: not available")
        end

        local text = table.concat(lines, "\n")

        -- Show in a copyable popup EditBox (supports Ctrl+A / Ctrl+C).
        local f = CreateFrame("Frame", "SQDiagFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(480, 340)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then f:Hide() end
        end)
        f:SetPropagateKeyboardInput(false)
        if f.TitleText then f.TitleText:SetText("SQ Diagnose — Ctrl+A then Ctrl+C to copy") end

        local eb = CreateFrame("EditBox", nil, f)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(440)
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -28)
        eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
        eb:SetAutoFocus(true)
        eb:SetText(text)
        eb:HighlightText()
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f:Show()
    else
        SocialQuestGroupFrame:Toggle()
    end
end)
