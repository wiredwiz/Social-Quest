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
-- Flight path starting node lookup
------------------------------------------------------------------------

-- Keys are the second return value of UnitRace("player") (English internal name).
-- All node name strings require in-game verification against GetTaxiNodeInfo() output
-- at Interface 20505 — values below are best-effort.
-- Pandaren, Dracthyr, and Earthen are faction-dependent; handled in getStartingNode().
local RACE_STARTING_NODES = {
    -- TBC (currently supported)
    ["Human"]              = "Stormwind",
    ["Dwarf"]              = "Ironforge",
    ["Gnome"]              = "Ironforge",
    ["NightElf"]           = "Rut'theran Village",
    ["Scourge"]            = "Undercity",           -- Undead
    ["Tauren"]             = "Thunder Bluff",
    ["Orc"]                = "Orgrimmar",
    ["Troll"]              = "Orgrimmar",
    ["Draenei"]            = "The Exodar",
    ["BloodElf"]           = "Silvermoon City",
    -- Cataclysm
    ["Worgen"]             = "Stormwind",
    ["Goblin"]             = "Orgrimmar",
    -- BfA allied races
    ["VoidElf"]            = "Stormwind",
    ["LightforgedDraenei"] = "Stormwind",
    ["DarkIronDwarf"]      = "Ironforge",
    ["KulTiran"]           = "Boralus",
    ["Mechagnome"]         = "Mechagon",
    ["Nightborne"]         = "Orgrimmar",
    ["HighmountainTauren"] = "Thunder Bluff",
    ["MagharOrc"]          = "Orgrimmar",
    ["ZandalarTroll"]      = "Dazar'alor",
    ["Vulpera"]            = "Orgrimmar",
    -- Dragonflight / The War Within
    -- (Dracthyr and Earthen handled in getStartingNode — faction-dependent)
}

-- Returns the starting flight node name for the local player.
-- Handles faction-dependent races (Pandaren, Dracthyr, Earthen) inline.
-- Returns nil for unknown races; callers treat nil as "no seed available."
local function getStartingNode()
    local _, race = SQWowAPI.UnitRace("player")
    local node = RACE_STARTING_NODES[race]
    if node then return node end
    local faction = SQWowAPI.UnitFactionGroup("player")
    if race == "Pandaren" or race == "Dracthyr" or race == "Earthen" then
        return faction == "Alliance" and "Stormwind" or "Orgrimmar"
    end
    return nil
end

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

    -- Register tooltips hook.
    SocialQuestTooltips:Initialize()

    -- Register WoW events (non-quest; quest events come via AQL callbacks).
    self:RegisterEvent("GROUP_ROSTER_UPDATE",   "OnGroupRosterUpdate")
    self:RegisterEvent("PLAYER_LOGIN",          "OnPlayerLogin")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("AUTOFOLLOW_BEGIN",        "OnAutoFollowBegin")
    self:RegisterEvent("AUTOFOLLOW_END",          "OnAutoFollowEnd")
    self:RegisterEvent("TAXIMAP_OPENED",          "OnTaxiMapOpened")
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
            flightPath = {
                enabled         = true,   -- broadcast my discoveries to party
                announceBanners = true,   -- display banners when party members discover paths
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
                windowOpen = false,
            },
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

function SocialQuest:GetStartingNode()
    return getStartingNode()
end

function SocialQuest:OnTaxiMapOpened()
    if not self.db.profile.flightPath.enabled then return end

    -- Collect all node names currently visible on the taxi map.
    -- GetTaxiNodeInfo(i) returns name, texture, x, y at Interface 20505.
    -- Iterate until nil is returned. Only named nodes are collected.
    -- NOTE: exact API behavior (active vs inactive nodes, max index) requires
    -- in-game verification during implementation.
    local currentNodes = {}
    local i = 1
    while true do
        local name = SQWowAPI.GetTaxiNodeInfo(i)
        if not name then break end
        currentNodes[name] = true
        i = i + 1
    end

    local saved = self.db.char.knownFlightNodes
    local diff  = {}
    for name in pairs(currentNodes) do
        if not saved[name] then
            table.insert(diff, name)
        end
    end

    local diffCount    = #diff
    local currentCount = 0
    for _ in pairs(currentNodes) do currentCount = currentCount + 1 end

    self:Debug("Quest", "OnTaxiMapOpened: currentNodes=" .. currentCount .. " saved=" .. (function() local n=0; for _ in pairs(saved) do n=n+1 end; return n end)() .. " diff=" .. diffCount)

    if diffCount == 0 then
        self:Debug("Quest", "OnTaxiMapOpened: no new nodes — silent return")
        return  -- nothing new
    end

    local startNode = getStartingNode()
    self:Debug("Quest", "OnTaxiMapOpened: startNode=" .. tostring(startNode))

    if diffCount == 1 then
        -- Normal case: one new node. Announce unless it is the starting city.
        if diff[1] ~= startNode then
            self:Debug("Quest", "OnTaxiMapOpened: announcing new node=" .. diff[1])
            SocialQuestComm:SendFlightDiscovery(diff[1])
        else
            self:Debug("Quest", "OnTaxiMapOpened: first-open at starting city (" .. diff[1] .. ") — silent absorb")
        end

    elseif diffCount > 1 and currentCount == 2 then
        -- Special case: savedNodes was empty and player has exactly starting city
        -- + one new discovery. Announce the non-starting-city node only.
        -- If startNode is nil (unknown race), skip — cannot identify which is new.
        self:Debug("Quest", "OnTaxiMapOpened: two-node special case — diff=" .. diffCount .. " current=" .. currentCount)
        if startNode then
            for _, name in ipairs(diff) do
                if name ~= startNode then
                    self:Debug("Quest", "OnTaxiMapOpened: announcing discovery (two-node case) node=" .. name)
                    SocialQuestComm:SendFlightDiscovery(name)
                    break
                end
            end
        else
            self:Debug("Quest", "OnTaxiMapOpened: unknown race — cannot identify new node in two-node case, skipping")
        end

    else
        -- diffCount > 1 and currentCount > 2: mid-game install or ambiguous.
        -- Silently absorb — cannot determine which node is genuinely new.
        self:Debug("Quest", "OnTaxiMapOpened: mid-game install / ambiguous (" .. diffCount .. " new of " .. currentCount .. " total) — silent absorb")
    end

    -- Always update saved state regardless of whether anything was announced.
    for name in pairs(currentNodes) do
        saved[name] = true
    end
    self:Debug("Quest", "OnTaxiMapOpened: knownFlightNodes updated")
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
    else
        SocialQuestGroupFrame:Toggle()
    end
end)
