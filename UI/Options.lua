-- UI/Options.lua
-- AceConfig options table. Accessible via /sq config or Interface Options.

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

SocialQuestOptions = {}

function SocialQuestOptions:Initialize()
    local AceConfig       = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local db = SocialQuest.db.profile

    local function toggle(label, desc, path, order)
        return {
            type    = "toggle",
            name    = label,
            desc    = desc,
            order   = order,
            get     = function(info)
                local t = db
                for _, k in ipairs(path) do t = t[k] end
                return t
            end,
            set     = function(info, v)
                local t = db
                for i = 1, #path - 1 do t = t[path[i]] end
                t[path[#path]] = v
            end,
        }
    end

    -- Builds the "Announce in Chat" inline group.
    -- questOnly = true → 5 quest-event keys only (raid and guild).
    -- questOnly = false → all 7 keys (party, battleground, whisperFriends).
    local function announceChatGroup(sectionKey, questOnly)
        local args = {
            accepted  = toggle(L["Accepted"],
                L["Send a chat message when you accept a quest."],
                { sectionKey, "announce", "accepted"  }),
            abandoned = toggle(L["Abandoned"],
                L["Send a chat message when you abandon a quest."],
                { sectionKey, "announce", "abandoned" }),
            finished  = toggle(L["Complete"],
                L["Send a chat message when all your quest objectives are complete (before turning in)."],
                { sectionKey, "announce", "finished"  }),
            completed = toggle(L["Turned In"],
                L["Send a chat message when you turn in a quest."],
                { sectionKey, "announce", "completed" }),
            failed    = toggle(L["Failed"],
                L["Send a chat message when a quest fails."],
                { sectionKey, "announce", "failed"    }),
        }
        if not questOnly then
            args.objective_progress = toggle(
                L["Objective Progress"],
                L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."],
                { sectionKey, "announce", "objective_progress" })
            args.objective_complete = toggle(
                L["Objective Complete"],
                L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."],
                { sectionKey, "announce", "objective_complete" })
        end
        return { type = "group", name = L["Announce in Chat"], inline = true, order = 3, args = args }
    end

    -- Builds the "Own Quest Banners" inline group under General.
    local function ownDisplayEventsGroup()
        return {
            type   = "group",
            name   = L["Own Quest Banners"],
            inline = true,
            order  = 6,
            args   = {
                accepted  = toggle(L["Accepted"],
                    L["Show a banner when you accept a quest."],
                    { "general", "displayOwnEvents", "accepted"  }),
                abandoned = toggle(L["Abandoned"],
                    L["Show a banner when you abandon a quest."],
                    { "general", "displayOwnEvents", "abandoned" }),
                finished  = toggle(L["Complete"],
                    L["Show a banner when all objectives on a quest are complete (before turning in)."],
                    { "general", "displayOwnEvents", "finished"  }),
                completed = toggle(L["Turned In"],
                    L["Show a banner when you turn in a quest."],
                    { "general", "displayOwnEvents", "completed" }),
                failed    = toggle(L["Failed"],
                    L["Show a banner when a quest fails."],
                    { "general", "displayOwnEvents", "failed"    }),
                objective_progress = {
                    type = "toggle",
                    name = L["Objective Progress"],
                    desc = L["Show a banner when one of your quest objectives progresses or regresses."],
                    get  = function(info) return db.general.displayOwnEvents.objective_progress end,
                    set  = function(info, value)
                        db.general.displayOwnEvents.objective_progress = value
                    end,
                },
                objective_complete = toggle(L["Objective Complete"],
                    L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."],
                    { "general", "displayOwnEvents", "objective_complete" }),
            },
        }
    end

    -- Builds the "Display Events" inline group (inbound banner controls).
    -- Not added to guild or whisperFriends (no inbound banner path for either).
    local function displayEventsGroup(sectionKey)
        return {
            type   = "group",
            name   = L["Display Events"],
            inline = true,
            order  = 4,
            args   = {
                accepted  = toggle(L["Accepted"],
                    L["Show a banner on screen when a group member accepts a quest."],
                    { sectionKey, "display", "accepted"  }),
                abandoned = toggle(L["Abandoned"],
                    L["Show a banner on screen when a group member abandons a quest."],
                    { sectionKey, "display", "abandoned" }),
                finished  = toggle(L["Complete"],
                    L["Show a banner on screen when a group member completes all objectives on a quest."],
                    { sectionKey, "display", "finished"  }),
                completed = toggle(L["Turned In"],
                    L["Show a banner on screen when a group member turns in a quest."],
                    { sectionKey, "display", "completed" }),
                failed    = toggle(L["Failed"],
                    L["Show a banner on screen when a group member fails a quest."],
                    { sectionKey, "display", "failed"    }),
                objective_progress = toggle(L["Objective Progress"],
                    L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."],
                    { sectionKey, "display", "objective_progress" }),
                objective_complete = toggle(L["Objective Complete"],
                    L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."],
                    { sectionKey, "display", "objective_complete" }),
            },
        }
    end

    local options = {
        type = "group",
        name = "SocialQuest",
        args = {

            general = {
                type  = "group",
                name  = L["General"],
                order = 1,
                args  = {
                    enabled         = {
                        type  = "toggle",
                        name  = L["Enable SocialQuest"],
                        desc  = L["Master on/off switch for all SocialQuest functionality."],
                        order = 1,
                        get   = function(info) return db.enabled end,
                        set   = function(info, value)
                            db.enabled = value
                        end,
                    },
                    displayReceived = toggle(L["Show received events"],
                        L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."],
                        { "general", "displayReceived" }, 2),
                    colorblindMode  = toggle(L["Colorblind Mode"],
                        L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."],
                        { "general", "colorblindMode" }, 3),
                    showMinimapButton = {
                        type   = "toggle",
                        name   = L["Show minimap button"],
                        desc   = L["Show or hide the SocialQuest minimap button."],
                        order  = 4,
                        hidden = function()
                            return LibStub("LibDBIcon-1.0", true) == nil
                        end,
                        get    = function(info) return not db.minimap.hide end,
                        set    = function(info, value)
                            db.minimap.hide = not value
                            local DBIcon = LibStub("LibDBIcon-1.0", true)
                            if DBIcon then
                                if value then
                                    DBIcon:Show("SocialQuest")
                                else
                                    DBIcon:Hide("SocialQuest")
                                end
                            end
                        end,
                    },
                    displayOwn      = {
                        type  = "toggle",
                        name  = L["Show banners for your own quest events"],
                        desc  = L["Show a banner on screen for your own quest events."],
                        order = 5,
                        get   = function(info) return db.general.displayOwn end,
                        set   = function(info, value)
                            db.general.displayOwn = value
                        end,
                    },
                    ownDisplayEvents = ownDisplayEventsGroup(),
                    doNotDisturb = {
                        type  = "toggle",
                        name  = "Do Not Disturb",
                        desc  = "Suppress all SQ banner notifications. Chat announcements are unaffected. Toggle quickly with /sq dnd.",
                        order = 6,
                        get   = function(info) return db.doNotDisturb end,
                        set   = function(info, value)
                            db.doNotDisturb = value
                        end,
                    },
                },
            },

            party = {
                type  = "group",
                name  = L["Party"],
                order = 2,
                args  = {
                    transmit        = toggle(L["Enable transmission"],
                        L["Broadcast your quest events to party members via addon comm."],
                        { "party", "transmit" }, 1),
                    displayReceived = toggle(L["Show received events"],
                        L["Allow banner notifications from party members (subject to Display Events toggles below)."],
                        { "party", "displayReceived" }, 2),
                    announceChat    = announceChatGroup("party", false),
                    displayEvents   = displayEventsGroup("party"),
                },
            },

            raid = {
                type  = "group",
                name  = L["Raid"],
                order = 3,
                args  = {
                    transmit        = toggle(L["Enable transmission"],
                        L["Broadcast your quest events to raid members via addon comm."],
                        { "raid", "transmit" }, 1),
                    displayReceived = toggle(L["Show received events"],
                        L["Allow banner notifications from raid members."],
                        { "raid", "displayReceived" }, 2),
                    friendsOnly     = toggle(L["Only show notifications from friends"],
                        L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."],
                        { "raid", "friendsOnly" }, 3),
                    announceChat    = announceChatGroup("raid", true),
                    displayEvents   = displayEventsGroup("raid"),
                },
            },

            guild = {
                type  = "group",
                name  = L["Guild"],
                order = 4,
                args  = {
                    transmit     = toggle(L["Enable chat announcements"],
                        L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."],
                        { "guild", "transmit" }, 1),
                    announceChat = announceChatGroup("guild", true),
                },
            },

            battleground = {
                type  = "group",
                name  = L["Battleground"],
                order = 5,
                args  = {
                    transmit        = toggle(L["Enable transmission"],
                        L["Broadcast your quest events to battleground members via addon comm."],
                        { "battleground", "transmit" }, 1),
                    displayReceived = toggle(L["Show received events"],
                        L["Allow banner notifications from battleground members."],
                        { "battleground", "displayReceived" }, 2),
                    friendsOnly     = toggle(L["Only show notifications from friends"],
                        L["Only show banner notifications from friends in the battleground."],
                        { "battleground", "friendsOnly" }, 3),
                    announceChat    = announceChatGroup("battleground", false),
                    displayEvents   = displayEventsGroup("battleground"),
                },
            },

            whisperFriends = {
                type  = "group",
                name  = L["Whisper Friends"],
                order = 6,
                args  = {
                    enabled      = toggle(L["Enable whispers to friends"],
                        L["Send your quest events as whispers to online friends."],
                        { "whisperFriends", "enabled" }, 1),
                    groupOnly    = toggle(L["Group members only"],
                        L["Restrict whispers to friends currently in your group."],
                        { "whisperFriends", "groupOnly" }, 2),
                    announceChat = announceChatGroup("whisperFriends", false),
                },
            },

            follow = {
                type  = "group",
                name  = L["Follow Notifications"],
                order = 7,
                args  = {
                    enabled           = toggle(L["Enable follow notifications"],
                        L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."],
                        { "follow", "enabled" }),
                    announceFollowing = toggle(L["Announce when you follow someone"],
                        L["Whisper the player you begin following so they know you are following them."],
                        { "follow", "announceFollowing" }),
                    announceFollowed  = toggle(L["Announce when followed"],
                        L["Display a local message when someone starts or stops following you."],
                        { "follow", "announceFollowed"  }),
                },
            },

            window = {
                type  = "group",
                name  = L["Social Quest Window"],
                order = 9,
                args  = {
                    autoFilterInstance = {
                        type  = "toggle",
                        name  = L["Auto-filter to current instance"],
                        desc  = L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."],
                        order = 1,
                        get   = function(info) return db.window.autoFilterInstance end,
                        set   = function(info, value)
                            db.window.autoFilterInstance = value
                            SocialQuestWindowFilter:Reset()
                            SocialQuestGroupFrame:RequestRefresh()
                        end,
                    },
                    autoFilterZone = {
                        type  = "toggle",
                        name  = L["Auto-filter to current zone"],
                        desc  = L["Outside of instances, the Party and Shared tabs show only quests for your current zone."],
                        order = 2,
                        get   = function(info) return db.window.autoFilterZone end,
                        set   = function(info, value)
                            db.window.autoFilterZone = value
                            SocialQuestWindowFilter:Reset()
                            SocialQuestGroupFrame:RequestRefresh()
                        end,
                    },
                    zoneQuestCount = {
                        type  = "toggle",
                        name  = "Show quest count in zone headers",
                        desc  = "Append the number of quests in each zone section to its header label (e.g. 'Hellfire Peninsula (7)').",
                        order = 3,
                        get   = function(info) return db.window.zoneQuestCount end,
                        set   = function(info, value)
                            db.window.zoneQuestCount = value
                            SocialQuestGroupFrame:RequestRefresh()
                        end,
                    },
                },
            },

            tooltips = {
                type  = "group",
                name  = L["Tooltips"],
                order = 10,
                args  = {
                    enhance = toggle(L["Enhance Questie/Blizzard tooltips"],
                        L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."],
                        { "tooltips", "enhance" }, 1),
                    replaceBlizzard = toggle(L["Replace Blizzard quest tooltips"],
                        L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."],
                        { "tooltips", "replaceBlizzard" }, 2),
                    replaceQuestie  = {
                        type     = "toggle",
                        name     = L["Replace Questie quest tooltips"],
                        desc     = L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."],
                        order    = 3,
                        disabled = function() return QuestieLoader == nil end,
                        get      = function(info) return db.tooltips.replaceQuestie end,
                        set      = function(info, v)
                            db.tooltips.replaceQuestie = v
                        end,
                    },
                },
            },

            debug = {
                type  = "group",
                name  = L["Debug"],
                order = 11,
                args  = {
                    enabled = toggle(L["Enable debug mode"],
                        L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."],
                        { "debug", "enabled" }, 1),
                    forceResync = {
                        type     = "execute",
                        name     = L["Force Resync"],
                        desc     = L["Request a fresh quest snapshot from all current group members. Disabled for 30 seconds after each use."],
                        order    = 2,
                        hidden   = function() return not db.debug.enabled end,
                        disabled = function() return SocialQuestComm:IsResyncOnCooldown() end,
                        func     = function()
                            SocialQuestComm:ResyncAll()
                        end,
                    },
                    testBanners = {
                        type   = "group",
                        name   = L["Test Banners and Chat"],
                        inline = true,
                        order  = 3,
                        args   = {
                            testAccepted = {
                                type = "execute",
                                name = L["Test Accepted"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."],
                                func = function() SocialQuestAnnounce:TestEvent("accepted") end,
                            },
                            testAbandoned = {
                                type = "execute",
                                name = L["Test Abandoned"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest abandoned' event."],
                                func = function() SocialQuestAnnounce:TestEvent("abandoned") end,
                            },
                            testFinished = {
                                type = "execute",
                                name = L["Test Complete"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."],
                                func = function() SocialQuestAnnounce:TestEvent("finished") end,
                            },
                            testCompleted = {
                                type = "execute",
                                name = L["Test Turned In"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest turned in' event."],
                                func = function() SocialQuestAnnounce:TestEvent("completed") end,
                            },
                            testFailed = {
                                type = "execute",
                                name = L["Test Failed"],
                                desc = L["Display a demo banner and local chat preview for the 'Quest failed' event."],
                                func = function() SocialQuestAnnounce:TestEvent("failed") end,
                            },
                            testObjProgress = {
                                type = "execute",
                                name = L["Test Obj. Progress"],
                                desc = L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."],
                                func = function() SocialQuestAnnounce:TestEvent("objective_progress") end,
                            },
                            testObjComplete = {
                                type = "execute",
                                name = L["Test Obj. Complete"],
                                desc = L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."],
                                func = function() SocialQuestAnnounce:TestEvent("objective_complete") end,
                            },
                            testObjRegression = {
                                type = "execute",
                                name = L["Test Obj. Regression"],
                                desc = L["Display a demo banner and local chat preview for an objective regression (count went backward)."],
                                func = function() SocialQuestAnnounce:TestEvent("objective_regression") end,
                            },
                            testAllComplete = {
                                type = "execute",
                                name = L["Test All Completed"],
                                desc = L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."],
                                func = function() SocialQuestAnnounce:TestEvent("all_complete") end,
                            },
                            testChatLink = {
                                type = "execute",
                                name = L["Test Chat Link"],
                                desc = L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."],
                                func = function() SocialQuestAnnounce:TestChatLink() end,
                            },
                            testFollowNotification = {
                                type   = "execute",
                                name   = L["Test Follow Notification"],
                                desc   = L["Display a demo follow notification banner showing the 'started following you' message."],
                                func   = function() SocialQuestAnnounce:TestFollowNotification() end,
                            },
                        },
                    },
                },
            },

        },
    }

    local AceDBOptions = LibStub("AceDBOptions-3.0", true)
    if AceDBOptions then
        options.args.profiles = AceDBOptions:GetOptionsTable(SocialQuest.db)
        options.args.profiles.order = 99
    end

    AceConfig:RegisterOptionsTable("SocialQuest", options)
    AceConfigDialog:AddToBlizOptions("SocialQuest")
end
