-- UI/Options.lua
-- AceConfig options table. Accessible via /sq config or Interface Options.

SocialQuestOptions = {}

function SocialQuestOptions:Initialize()
    local AceConfig       = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local db = SocialQuest.db.profile

    local function toggle(label, desc, path)
        return {
            type    = "toggle",
            name    = label,
            desc    = desc,
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
            accepted  = toggle("Accepted",
                "Send a chat message when you accept a quest.",
                { sectionKey, "announce", "accepted"  }),
            abandoned = toggle("Abandoned",
                "Send a chat message when you abandon a quest.",
                { sectionKey, "announce", "abandoned" }),
            finished  = toggle("Finished",
                "Send a chat message when all your quest objectives are complete (before turning in).",
                { sectionKey, "announce", "finished"  }),
            completed = toggle("Completed",
                "Send a chat message when you turn in a quest.",
                { sectionKey, "announce", "completed" }),
            failed    = toggle("Failed",
                "Send a chat message when a quest fails.",
                { sectionKey, "announce", "failed"    }),
        }
        if not questOnly then
            args.objective_progress = toggle(
                "Objective Progress",
                "Send a chat message when a quest objective progresses or regresses. "
                .. "Format matches Questie's style. Never suppressed by Questie — "
                .. "Questie does not announce partial progress.",
                { sectionKey, "announce", "objective_progress" })
            args.objective_complete = toggle(
                "Objective Complete",
                "Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). "
                .. "Suppressed automatically if Questie is installed and its "
                .. "'Announce Objectives' setting is enabled.",
                { sectionKey, "announce", "objective_complete" })
        end
        return { type = "group", name = "Announce in Chat", inline = true, args = args }
    end

    -- Builds the "Own Quest Banners" inline group under General.
    local function ownDisplayEventsGroup()
        return {
            type   = "group",
            name   = "Own Quest Banners",
            inline = true,
            args   = {
                accepted  = toggle("Accepted",
                    "Show a banner when you accept a quest.",
                    { "general", "displayOwnEvents", "accepted"  }),
                abandoned = toggle("Abandoned",
                    "Show a banner when you abandon a quest.",
                    { "general", "displayOwnEvents", "abandoned" }),
                finished  = toggle("Finished",
                    "Show a banner when all objectives on a quest are complete (before turning in).",
                    { "general", "displayOwnEvents", "finished"  }),
                completed = toggle("Completed",
                    "Show a banner when you turn in a quest.",
                    { "general", "displayOwnEvents", "completed" }),
                failed    = toggle("Failed",
                    "Show a banner when a quest fails.",
                    { "general", "displayOwnEvents", "failed"    }),
                objective_progress = toggle("Objective Progress",
                    "Show a banner when one of your quest objectives progresses or regresses.",
                    { "general", "displayOwnEvents", "objective_progress" }),
                objective_complete = toggle("Objective Complete",
                    "Show a banner when one of your quest objectives reaches its goal (e.g. 8/8).",
                    { "general", "displayOwnEvents", "objective_complete" }),
            },
        }
    end

    -- Builds the "Display Events" inline group (inbound banner controls).
    -- Not added to guild or whisperFriends (no inbound banner path for either).
    local function displayEventsGroup(sectionKey)
        return {
            type   = "group",
            name   = "Display Events",
            inline = true,
            args   = {
                accepted  = toggle("Accepted",
                    "Show a banner on screen when a group member accepts a quest.",
                    { sectionKey, "display", "accepted"  }),
                abandoned = toggle("Abandoned",
                    "Show a banner on screen when a group member abandons a quest.",
                    { sectionKey, "display", "abandoned" }),
                finished  = toggle("Finished",
                    "Show a banner on screen when a group member finishes all objectives on a quest.",
                    { sectionKey, "display", "finished"  }),
                completed = toggle("Completed",
                    "Show a banner on screen when a group member turns in a quest.",
                    { sectionKey, "display", "completed" }),
                failed    = toggle("Failed",
                    "Show a banner on screen when a group member fails a quest.",
                    { sectionKey, "display", "failed"    }),
                objective_progress = toggle("Objective Progress",
                    "Show a banner on screen when a group member's quest objective count changes "
                    .. "(includes partial progress and regression).",
                    { sectionKey, "display", "objective_progress" }),
                objective_complete = toggle("Objective Complete",
                    "Show a banner on screen when a group member completes a quest objective (e.g. 8/8).",
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
                name  = "General",
                order = 1,
                args  = {
                    enabled         = toggle("Enable SocialQuest",
                        "Master on/off switch for all SocialQuest functionality.",
                        { "enabled" }),
                    displayReceived = toggle("Show received events",
                        "Master switch: allow any banner notifications to appear. "
                        .. "Individual 'Display Events' groups below control which event "
                        .. "types are shown per section.",
                        { "general", "displayReceived" }),
                    colorblindMode  = toggle("Colorblind Mode",
                        "Use colorblind-friendly colors for all SocialQuest banners and "
                        .. "UI text. It is unnecessary to enable this if Color Blind mode is "
                        .. "already enabled in the game client.",
                        { "general", "colorblindMode" }),
                    displayOwn      = toggle("Show banners for your own quest events",
                        "Show a banner on screen for your own quest events.",
                        { "general", "displayOwn" }),
                    ownDisplayEvents = ownDisplayEventsGroup(),
                },
            },

            party = {
                type  = "group",
                name  = "Party",
                order = 2,
                args  = {
                    transmit        = toggle("Enable transmission",
                        "Broadcast your quest events to party members via addon comm.",
                        { "party", "transmit" }),
                    displayReceived = toggle("Show received events",
                        "Allow banner notifications from party members (subject to "
                        .. "Display Events toggles below).",
                        { "party", "displayReceived" }),
                    announceChat    = announceChatGroup("party", false),
                    displayEvents   = displayEventsGroup("party"),
                },
            },

            raid = {
                type  = "group",
                name  = "Raid",
                order = 3,
                args  = {
                    transmit        = toggle("Enable transmission",
                        "Broadcast your quest events to raid members via addon comm.",
                        { "raid", "transmit" }),
                    displayReceived = toggle("Show received events",
                        "Allow banner notifications from raid members.",
                        { "raid", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends",
                        "Only show banner notifications from players on your friends list, "
                        .. "suppressing banners from strangers in large raids.",
                        { "raid", "friendsOnly" }),
                    announceChat    = announceChatGroup("raid", true),
                    displayEvents   = displayEventsGroup("raid"),
                },
            },

            guild = {
                type  = "group",
                name  = "Guild",
                order = 4,
                args  = {
                    transmit     = toggle("Enable chat announcements",
                        "Announce your quest events in guild chat. Guild members do not "
                        .. "need SocialQuest installed to see these messages.",
                        { "guild", "transmit" }),
                    announceChat = announceChatGroup("guild", true),
                },
            },

            battleground = {
                type  = "group",
                name  = "Battleground",
                order = 5,
                args  = {
                    transmit        = toggle("Enable transmission",
                        "Broadcast your quest events to battleground members via addon comm.",
                        { "battleground", "transmit" }),
                    displayReceived = toggle("Show received events",
                        "Allow banner notifications from battleground members.",
                        { "battleground", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends",
                        "Only show banner notifications from friends in the battleground.",
                        { "battleground", "friendsOnly" }),
                    announceChat    = announceChatGroup("battleground", false),
                    displayEvents   = displayEventsGroup("battleground"),
                },
            },

            whisperFriends = {
                type  = "group",
                name  = "Whisper Friends",
                order = 6,
                args  = {
                    enabled      = toggle("Enable whispers to friends",
                        "Send your quest events as whispers to online friends.",
                        { "whisperFriends", "enabled" }),
                    groupOnly    = toggle("Group members only",
                        "Restrict whispers to friends currently in your group.",
                        { "whisperFriends", "groupOnly" }),
                    announceChat = announceChatGroup("whisperFriends", false),
                },
            },

            follow = {
                type  = "group",
                name  = "Follow Notifications",
                order = 7,
                args  = {
                    enabled           = toggle("Enable follow notifications",
                        "Send a whisper to players you start or stop following, and "
                        .. "receive notifications when someone follows you.",
                        { "follow", "enabled" }),
                    announceFollowing = toggle("Announce when you follow someone",
                        "Whisper the player you begin following so they know you are following them.",
                        { "follow", "announceFollowing" }),
                    announceFollowed  = toggle("Announce when followed",
                        "Display a local message when someone starts or stops following you.",
                        { "follow", "announceFollowed"  }),
                },
            },

            debug = {
                type  = "group",
                name  = "Debug",
                order = 8,
                args  = {
                    enabled = toggle("Enable debug mode",
                        "Print internal debug messages to the chat frame. Useful for "
                        .. "diagnosing comm issues or event flow problems.",
                        { "debug", "enabled" }),
                    testBanners = {
                        type   = "group",
                        name   = "Test Banners and Chat",
                        inline = true,
                        args   = {
                            testAccepted = {
                                type = "execute",
                                name = "Test Accepted",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest accepted' event. Bypasses all display filters.",
                                func = function() SocialQuestAnnounce:TestEvent("accepted") end,
                            },
                            testAbandoned = {
                                type = "execute",
                                name = "Test Abandoned",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest abandoned' event.",
                                func = function() SocialQuestAnnounce:TestEvent("abandoned") end,
                            },
                            testFinished = {
                                type = "execute",
                                name = "Test Finished",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest finished objectives' event.",
                                func = function() SocialQuestAnnounce:TestEvent("finished") end,
                            },
                            testCompleted = {
                                type = "execute",
                                name = "Test Completed",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest turned in' event.",
                                func = function() SocialQuestAnnounce:TestEvent("completed") end,
                            },
                            testFailed = {
                                type = "execute",
                                name = "Test Failed",
                                desc = "Display a demo banner and local chat preview for the "
                                    .. "'Quest failed' event.",
                                func = function() SocialQuestAnnounce:TestEvent("failed") end,
                            },
                            testObjProgress = {
                                type = "execute",
                                name = "Test Obj. Progress",
                                desc = "Display a demo banner and local chat preview for a "
                                    .. "partial objective progress update (e.g. 3/8).",
                                func = function() SocialQuestAnnounce:TestEvent("objective_progress") end,
                            },
                            testObjComplete = {
                                type = "execute",
                                name = "Test Obj. Complete",
                                desc = "Display a demo banner and local chat preview for an "
                                    .. "objective completion (e.g. 8/8).",
                                func = function() SocialQuestAnnounce:TestEvent("objective_complete") end,
                            },
                            testObjRegression = {
                                type = "execute",
                                name = "Test Obj. Regression",
                                desc = "Display a demo banner and local chat preview for an "
                                    .. "objective regression (count went backward).",
                                func = function() SocialQuestAnnounce:TestEvent("objective_regression") end,
                            },
                            testAllComplete = {
                                type = "execute",
                                name = "Test All Completed",
                                desc = "Display a demo banner for the 'Everyone has completed' "
                                    .. "purple notification. No chat preview (this event never "
                                    .. "generates outbound chat directly).",
                                func = function() SocialQuestAnnounce:TestEvent("all_complete") end,
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
