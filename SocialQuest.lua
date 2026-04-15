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
            console            = { x=nil, y=nil, width=nil, height=nil, sepFrac=0.38 },
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
            tooltips = {
                enhance        = true,
                replaceBlizzard = false,
                replaceQuestie  = false,
            },
            window = {
                autoFilterInstance = true,
                autoFilterZone     = false,
                zoneQuestCount     = true,
                windowFontScale    = 1.0,
            },
            doNotDisturb = false,
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
                -- /sq diagnose console window geometry (persisted across sessions)
                console = {
                    x       = nil,      -- TOPLEFT x (absolute screen coords)
                    y       = nil,      -- TOPLEFT y
                    width   = nil,
                    height  = nil,
                    sepFrac = 0.38,     -- input/output split fraction
                },
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
    -- Remind the player if DND mode is still on. Fires after the 3s suppression
    -- window and after the initial quest log re-announce has settled.
    -- Calls SQWowUI.AddRaidNotice directly (bypasses the DND guard in displayBanner).
    SQWowAPI.TimerAfter(5, function()
        if SocialQuest.db and SocialQuest.db.profile.doNotDisturb then
            SQWowUI.AddRaidNotice(
                "SocialQuest: Do Not Disturb is ON — banners are suppressed.",
                { r = 0.337, g = 0.706, b = 0.914 }
            )
        end
    end)
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
    elseif cmd == "sync" then
        local remaining = SocialQuestComm:GetResyncCooldownRemaining()
        if remaining > 0 then
            SocialQuest:Print("Sync is on cooldown. Try again in "
                .. remaining .. (remaining == 1 and " second." or " seconds."))
        elseif not SocialQuestComm:GetActiveChannel() then
            SocialQuest:Print("You must be in a group to sync.")
        else
            SocialQuestComm:ResyncAll()
            SocialQuest:Print("Requesting a fresh quest snapshot from all group members.")
        end
    elseif cmd == "diagnose" then
        local isNew = not SQConsoleFrame
        if not SQConsoleFrame then
            local SEP_H   = 8
            local TOP_PAD = 30
            local BOT_PAD = 14
            local SIDE    = 8

            local f = CreateFrame("Frame", "SQConsoleFrame", UIParent, "BasicFrameTemplateWithInset")
            f:SetSize(560, 520)
            f:SetPoint("CENTER")
            f:SetFrameStrata("TOOLTIP")
            f:SetToplevel(true)
            f:SetMovable(true)
            f:SetClampedToScreen(true)
            f:EnableMouse(true)
            f:EnableKeyboard(true)
            -- Block WoW's C-level game keybinding dispatch only while one of our
            -- EditBoxes has focus. This prevents Ctrl+C from opening the Character
            -- window when the user tries to copy selected output text.
            f:SetScript("OnKeyDown", function(self, key)
                self:SetPropagateKeyboardInput(not sqEditFocused)
            end)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local cs = SocialQuest.db.char.frameState.console
                cs.x, cs.y = self:GetLeft(), self:GetTop()
            end)
            f:SetResizable(true)
            if f.SetResizeBounds then f:SetResizeBounds(340, 280)
            elseif f.SetMinResize then f:SetMinResize(340, 280) end
            -- UISpecialFrames: WoW closes this frame when Escape is pressed and no
            -- EditBox owns focus. This avoids intercepting keys from the chat input.
            tinsert(UISpecialFrames, "SQConsoleFrame")
            f._sepFrac = 0.38
            -- Track whether one of our EditBoxes owns keyboard focus so the main
            -- frame can block game keybindings (e.g. Ctrl+C → Character window)
            -- while the user is typing or selecting output text.
            local sqEditFocused = false
            if f.TitleText then f.TitleText:SetText("SQ Lua Console") end

            -- Toolbar: Run and Clear buttons placed in the title bar, left of the X button
            local runBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            runBtn:SetSize(54, 20)
            runBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -52, -4)
            runBtn:SetText("Run")

            local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            clearBtn:SetSize(54, 20)
            clearBtn:SetPoint("RIGHT", runBtn, "LEFT", -4, 0)
            clearBtn:SetText("Clear")

            -- layout(): repositions all panes from current frame size and _sepFrac
            local function layout()
                local fw, fh    = f:GetWidth(), f:GetHeight()
                local contentW  = fw - SIDE * 2
                local contentH  = fh - TOP_PAD - BOT_PAD - SEP_H
                local inputH    = math.max(40, math.floor(contentH * f._sepFrac))
                local outputH   = math.max(40, contentH - inputH)

                f._inputScroll:ClearAllPoints()
                f._inputScroll:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE, -TOP_PAD)
                f._inputScroll:SetSize(contentW, inputH)
                f._inputEB:SetWidth(contentW - 26)

                f._sep:ClearAllPoints()
                f._sep:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE, -TOP_PAD - inputH)
                f._sep:SetSize(contentW, SEP_H)

                f._outputScroll:ClearAllPoints()
                f._outputScroll:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE, -TOP_PAD - inputH - SEP_H)
                f._outputScroll:SetSize(contentW, outputH)
                f._outputEB:SetWidth(contentW - 26)
            end
            f._layout = layout

            -- Input pane: ScrollFrame containing a multiline EditBox
            local inputScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
            inputScroll:EnableMouse(true)
            f._inputScroll = inputScroll
            local inputEB = CreateFrame("EditBox", nil, inputScroll)
            inputEB:SetMultiLine(true)
            inputEB:SetFontObject(ChatFontNormal)
            inputEB:SetTextColor(1, 1, 0.7, 1)
            inputEB:SetWidth(500)
            inputEB:SetAutoFocus(false)
            inputEB:EnableMouse(true)
            inputEB:EnableKeyboard(true)
            inputEB:SetPropagateKeyboardInput(false)
            inputEB:SetScript("OnMouseDown", function(self)
                self:SetFocus()
                -- Defer so WoW has placed the cursor before we read it
                SQWowAPI.TimerAfter(0, function()
                    if self:HasFocus() then self._selAnchor = self:GetCursorPosition() end
                end)
            end)
            inputEB:SetScript("OnEscapePressed", function() f:Hide() end)
            inputEB:SetScript("OnTabPressed", function(self) self:Insert("  ") end)
            inputEB:SetScript("OnKeyDown", function(self, key)
                self:SetPropagateKeyboardInput(false)
                if key == "PAGEUP" or key == "PAGEDOWN" then
                    local pageH = inputScroll:GetHeight()
                    local cur   = inputScroll:GetVerticalScroll()
                    local maxS  = inputScroll:GetVerticalScrollRange()
                    if key == "PAGEUP" then
                        inputScroll:SetVerticalScroll(math.max(0, cur - pageH))
                    else
                        inputScroll:SetVerticalScroll(math.min(maxS, cur + pageH))
                    end
                    if IsShiftKeyDown() then
                        local text    = self:GetText()
                        local textLen = #text
                        if textLen > 0 then
                            local lines   = math.max(1, select(2, text:gsub("\n", "")) + 1)
                            local lineH   = math.max(10, self:GetHeight() / lines)
                            local lpp     = math.max(1, math.floor(pageH / lineH))
                            local cpp     = math.floor(textLen / lines * lpp)
                            local curPos  = self:GetCursorPosition()
                            local anchor  = self._selAnchor or curPos
                            self._selAnchor = anchor
                            local newPos  = key == "PAGEUP"
                                and math.max(0, curPos - cpp)
                                or  math.min(textLen, curPos + cpp)
                            self:HighlightText(math.min(anchor, newPos), math.max(anchor, newPos))
                            self:SetCursorPosition(newPos)
                        end
                    else
                        self._selAnchor = nil
                    end
                end
            end)
            inputEB:SetScript("OnEditFocusGained", function() sqEditFocused = true end)
            inputEB:SetScript("OnEditFocusLost",   function() sqEditFocused = false end)
            -- Clicking anywhere in the scroll pane (including empty space below text) gives focus
            inputScroll:SetScript("OnMouseDown", function(_, btn)
                if btn == "LeftButton" then inputEB:SetFocus() end
            end)
            inputScroll:SetScrollChild(inputEB)
            f._inputEB = inputEB

            -- Separator bar: draggable, adjusts _sepFrac
            local sep = CreateFrame("Frame", nil, f)
            sep:EnableMouse(true)
            local sepTex = sep:CreateTexture(nil, "BACKGROUND")
            sepTex:SetAllPoints(sep)
            sepTex:SetColorTexture(0.25, 0.55, 1.0, 0.45)
            local sepLabel = sep:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sepLabel:SetPoint("CENTER")
            sepLabel:SetText("drag")
            sepLabel:SetTextColor(0.7, 0.85, 1.0)
            sep:SetScript("OnEnter", function() sepTex:SetColorTexture(0.45, 0.72, 1.0, 0.70) end)
            sep:SetScript("OnLeave", function() sepTex:SetColorTexture(0.25, 0.55, 1.0, 0.45) end)
            sep:SetScript("OnMouseDown", function(self, btn)
                if btn ~= "LeftButton" then return end
                self._drag = true
                self._y0   = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
                self._f0   = f._sepFrac
                self:SetScript("OnUpdate", function(s)
                    if not s._drag then s:SetScript("OnUpdate", nil); return end
                    local cy       = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
                    local contentH = f:GetHeight() - TOP_PAD - BOT_PAD - SEP_H
                    -- drag down (cy decreases) → startY-cy > 0 → frac grows → input taller
                    f._sepFrac = math.max(0.10, math.min(0.85, s._f0 + (s._y0 - cy) / contentH))
                    layout()
                end)
            end)
            sep:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then
                    self._drag = false
                    SocialQuest.db.char.frameState.console.sepFrac = f._sepFrac
                end
            end)
            f._sep = sep

            -- Output pane: ScrollFrame with EditBox — supports mouse text selection and Ctrl+C
            local outputScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
            f._outputScroll = outputScroll
            local outputEB = CreateFrame("EditBox", nil, outputScroll)
            outputEB:SetMultiLine(true)
            outputEB:SetFontObject(ChatFontNormal)
            outputEB:SetWidth(500)
            outputEB:SetAutoFocus(false)
            outputEB:EnableMouse(true)
            outputEB:EnableKeyboard(true)
            outputEB:SetPropagateKeyboardInput(false)
            outputEB:SetScript("OnMouseDown", function(self)
                self:SetFocus()
                SQWowAPI.TimerAfter(0, function()
                    if self:HasFocus() then self._selAnchor = self:GetCursorPosition() end
                end)
            end)
            -- Release keyboard focus on any key except copy shortcuts, page scroll, and
            -- modifier-only presses.  PageUp/Down scroll the viewport and optionally
            -- extend the text selection (Shift+Page) without releasing focus.
            outputEB:SetScript("OnKeyDown", function(self, key)
                -- Modifier keys alone: block propagation so holding Ctrl/Shift doesn't
                -- clear focus before the next key arrives.
                if key == "LCTRL" or key == "RCTRL"
                or key == "LSHIFT" or key == "RSHIFT"
                or key == "LALT"  or key == "RALT" then
                    self:SetPropagateKeyboardInput(false)
                    return
                end
                -- Ctrl+A / Ctrl+C: block game keybindings; let WoW's native
                -- EditBox copy/select-all run at the C level.
                if IsControlKeyDown() and (key == "A" or key == "C") then
                    self:SetPropagateKeyboardInput(false)
                    return
                end
                -- PageUp / PageDown: scroll the output viewport, keep focus for selection.
                if key == "PAGEUP" or key == "PAGEDOWN" then
                    self:SetPropagateKeyboardInput(false)
                    local pageH = outputScroll:GetHeight()
                    local cur   = outputScroll:GetVerticalScroll()
                    local maxS  = outputScroll:GetVerticalScrollRange()
                    if key == "PAGEUP" then
                        outputScroll:SetVerticalScroll(math.max(0, cur - pageH))
                    else
                        outputScroll:SetVerticalScroll(math.min(maxS, cur + pageH))
                    end
                    if IsShiftKeyDown() then
                        local text    = self:GetText()
                        local textLen = #text
                        if textLen > 0 then
                            local lines   = math.max(1, select(2, text:gsub("\n", "")) + 1)
                            local lineH   = math.max(10, self:GetHeight() / lines)
                            local lpp     = math.max(1, math.floor(pageH / lineH))
                            local cpp     = math.floor(textLen / lines * lpp)
                            local curPos  = self:GetCursorPosition()
                            local anchor  = self._selAnchor or curPos
                            self._selAnchor = anchor
                            local newPos  = key == "PAGEUP"
                                and math.max(0, curPos - cpp)
                                or  math.min(textLen, curPos + cpp)
                            self:HighlightText(math.min(anchor, newPos), math.max(anchor, newPos))
                            self:SetCursorPosition(newPos)
                        end
                    else
                        self._selAnchor = nil
                    end
                    return
                end
                -- Any other key: release focus and let game keybindings through.
                self:SetPropagateKeyboardInput(true)
                self:ClearFocus()
                if key == "ESCAPE" then f:Hide() end
            end)
            outputEB:SetScript("OnEditFocusGained", function() sqEditFocused = true end)
            outputEB:SetScript("OnEditFocusLost",   function() sqEditFocused = false end)
            outputScroll:SetScrollChild(outputEB)
            f._outputEB = outputEB

            -- Output buffer management
            local MAX_LINES = 200
            local outBuf = {}
            local function refreshOutputHeight()
                -- EditBox must be tall enough for content; scroll pane handles the viewport
                local h = math.max(#outBuf * 16 + 20, f._outputScroll:GetHeight())
                f._outputEB:SetHeight(h)
            end
            f._appendOutput = function(line)
                if #outBuf >= MAX_LINES then table.remove(outBuf, 1) end
                outBuf[#outBuf + 1] = line
                f._outputEB:SetText(table.concat(outBuf, "\n"))
                refreshOutputHeight()
            end
            f._clearOutput = function()
                outBuf = {}
                f._outputEB:SetText("")
                f._outputEB:SetHeight(20)
            end

            -- Resize grip (bottom-right corner)
            local grip = CreateFrame("Button", nil, f)
            grip:SetSize(16, 16)
            grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
            local gripTex = grip:CreateTexture(nil, "OVERLAY")
            gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            gripTex:SetAllPoints(grip)
            grip:SetScript("OnMouseDown", function(_, btn)
                if btn == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
            end)
            grip:SetScript("OnMouseUp", function()
                f:StopMovingOrSizing()
                layout()
                local cs = SocialQuest.db.char.frameState.console
                cs.width, cs.height = f:GetWidth(), f:GetHeight()
            end)
            f:SetScript("OnSizeChanged", function()
                local fw = f:GetWidth()
                f._inputEB:SetWidth(fw - 34)
                f._outputEB:SetWidth(fw - 34)
                layout()
            end)

            -- Run: execute input as Lua, capture print() to output
            runBtn:SetScript("OnClick", function()
                local code = f._inputEB:GetText()
                if not code or strtrim(code) == "" then return end
                f._appendOutput("|cff3399ff--[[ SQ-RUN-START ]]--")
                local captured = {}
                local origPrint = print
                print = function(...)
                    local parts = {}
                    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
                    captured[#captured + 1] = table.concat(parts, "\t")
                end
                local fn, compErr = loadstring(code)
                local ok, runErr
                if fn then ok, runErr = pcall(fn) end
                print = origPrint
                for _, ln in ipairs(captured) do
                    f._appendOutput("|cffffff99" .. ln .. "|r")
                end
                if not fn then
                    f._appendOutput("|cffff6666[compile error] " .. tostring(compErr) .. "|r")
                elseif not ok then
                    f._appendOutput("|cffff6666[runtime error] " .. tostring(runErr) .. "|r")
                elseif #captured == 0 then
                    f._appendOutput("|cff88dd88[ok — no output]|r")
                end
                f._appendOutput("|cff3399ff--[[ SQ-RUN-END ]]--")
                C_Timer.After(0.05, function()
                    f._outputScroll:SetVerticalScroll(f._outputScroll:GetVerticalScrollRange())
                end)
            end)

            clearBtn:SetScript("OnClick", function() f._clearOutput() end)

            -- Restore saved geometry (position / size / split fraction)
            do
                local cs = SocialQuest.db.char.frameState.console
                if cs.width and cs.height then f:SetSize(cs.width, cs.height) end
                f._sepFrac = cs.sepFrac or 0.38
                if cs.x and cs.y then
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cs.x, cs.y)
                end
                SQWowUI.ClampFrameToScreen(f)
            end

            layout()

            -- Pre-populate output with current group state snapshot
            local function dp(s) f._appendOutput("|cffaaaaaa" .. tostring(s)) end
            dp("IsInRaid: " .. tostring(SQWowAPI.IsInRaid()))
            dp("PARTY_CATEGORY_HOME: " .. tostring(SQWowAPI.PARTY_CATEGORY_HOME))
            dp("PARTY_CATEGORY_INSTANCE: " .. tostring(SQWowAPI.PARTY_CATEGORY_INSTANCE))
            dp("IsInGroup(HOME): " .. tostring(SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)))
            dp("IsInGroup(INSTANCE): " .. tostring(SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)))
            dp("IsInGroup(nil): " .. tostring(SQWowAPI.IsInGroup(nil)))
            dp("GetActiveChannel: " .. tostring(SocialQuestComm:GetActiveChannel()))
            dp("GetNumGroupMembers: " .. tostring(SQWowAPI.GetNumGroupMembers()))
            local sn, sr = SQWowAPI.UnitFullName("player")
            dp("UnitFullName(player): " .. tostring(sn) .. " / " .. tostring(sr))
            dp("UnitName(player): " .. tostring(SQWowAPI.UnitName("player")))
            local mc = SQWowAPI.GetNumGroupMembers()
            for i = 1, math.min(mc, 5) do
                local pn, pr = SQWowAPI.UnitFullName("party" .. i)
                dp("party" .. i .. " UnitFullName: " .. tostring(pn) .. " / " .. tostring(pr))
                dp("party" .. i .. " UnitName: " .. tostring(SQWowAPI.UnitName("party" .. i)))
            end
            local ms = SocialQuestGroupComposition.memberSet or {}
            local msc = 0
            for k in pairs(ms) do msc = msc + 1; dp("memberSet: " .. k) end
            if msc == 0 then dp("memberSet: (empty)") end
            local pqc = 0
            for k, v in pairs(SocialQuestGroupData.PlayerQuests) do
                pqc = pqc + 1
                dp("PlayerQuests[" .. k .. "] hasSQ=" .. tostring(v.hasSocialQuest) .. " dp=" .. tostring(v.dataProvider))
            end
            if pqc == 0 then dp("PlayerQuests: (empty)") end
            dp("debug.enabled: " .. tostring(SocialQuest.db.profile.debug.enabled))
            dp("party.transmit: " .. tostring(SocialQuest.db.profile.party.transmit))
            dp("zoneSuppress: " .. tostring(SQWowAPI.GetTime() < (SocialQuest.zoneTransitionSuppressUntil or 0)))
            if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
                local prefixes = {"SQ_INIT","SQ_UPDATE","SQ_OBJECTIVE","SQ_REQUEST","SQ_FOLLOW_START","SQ_FOLLOW_STOP","SQ_REQ_COMPLETED","SQ_RESP_COMPLETE"}
                for _, pfx in ipairs(prefixes) do
                    dp("prefix " .. pfx .. ": " .. tostring(C_ChatInfo.IsAddonMessagePrefixRegistered(pfx)))
                end
            else
                dp("C_ChatInfo.IsAddonMessagePrefixRegistered: not available")
            end
        end  -- end if not SQConsoleFrame

        -- isNew: frame was just built this call, always show it.
        -- Otherwise toggle: hide if visible, show if hidden.
        if SQConsoleFrame:IsShown() and not isNew then
            SQConsoleFrame:Hide()
        else
            SQConsoleFrame:Show()
            SQConsoleFrame:Raise()
        end
    elseif cmd == "dnd" then
        local db = SocialQuest.db.profile
        db.doNotDisturb = not db.doNotDisturb
        if db.doNotDisturb then
            SocialQuest:Print("SocialQuest Do Not Disturb: ON — banners suppressed.")
        else
            SocialQuest:Print("SocialQuest Do Not Disturb: OFF — banners enabled.")
        end
    elseif cmd == "" then
        SocialQuestGroupFrame:Toggle()
    else
        SocialQuest:Print("Unknown command '" .. cmd .. "'. Usage:")
        SocialQuest:Print("  /sq — open the SocialQuest window")
        SocialQuest:Print("  /sq config — open settings")
        SocialQuest:Print("  /sq dnd — toggle Do Not Disturb (suppress banners)")
        SocialQuest:Print("  /sq sync — request a fresh quest snapshot from all group members")
    end
end)
