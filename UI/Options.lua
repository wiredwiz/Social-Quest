-- UI/Options.lua
-- AceConfig options table. Accessible via /sq config or Interface Options.

SocialQuestOptions = {}

function SocialQuestOptions:Initialize()
    local AceConfig       = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local db = SocialQuest.db.profile

    local function get(info)
        local key = info[#info]
        -- Walk info path to find value in db.profile.
        local t = db
        for i = 1, #info - 1 do t = t[info[i]] end
        return t[key]
    end

    local function set(info, value)
        local key = info[#info]
        local t = db
        for i = 1, #info - 1 do t = t[info[i]] end
        t[key] = value
    end

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

    local function announceGroup(pathPrefix)
        return {
            type = "group",
            name = "Announce Events",
            inline = true,
            args = {
                accepted  = toggle("Accepted",  "Announce quest accepted",  { pathPrefix, "announce", "accepted"  }),
                abandoned = toggle("Abandoned", "Announce quest abandoned", { pathPrefix, "announce", "abandoned" }),
                finished  = toggle("Finished",  "Announce objectives done", { pathPrefix, "announce", "finished"  }),
                completed = toggle("Completed", "Announce quest turned in", { pathPrefix, "announce", "completed" }),
                failed    = toggle("Failed",    "Announce quest failed",    { pathPrefix, "announce", "failed"    }),
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
                    enabled         = toggle("Enable SocialQuest", "Master on/off switch.", { "enabled" }),
                    displayReceived = toggle("Show received events", "Display banners for events from other players.", { "general", "displayReceived" }),
                },
            },

            party = {
                type  = "group",
                name  = "Party",
                order = 2,
                args  = {
                    transmit        = toggle("Enable transmission",     "Send quest events to party.", { "party", "transmit" }),
                    displayReceived = toggle("Show received events",    "Show banners from party members.", { "party", "displayReceived" }),
                    objective       = toggle("Objective progress",      "Announce objective progress in party.", { "party", "announce", "objective" }),
                    events          = announceGroup("party"),
                },
            },

            raid = {
                type  = "group",
                name  = "Raid",
                order = 3,
                args  = {
                    transmit        = toggle("Enable transmission",   "Send quest events to raid.", { "raid", "transmit" }),
                    displayReceived = toggle("Show received events",  "Show banners from raid members.", { "raid", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends", "Suppress banners from non-friends in raid.", { "raid", "friendsOnly" }),
                    events          = announceGroup("raid"),
                },
            },

            guild = {
                type  = "group",
                name  = "Guild",
                order = 4,
                args  = {
                    transmit = toggle("Enable chat announcements", "Send quest events to guild chat. No AceComm sync occurs with guild.", { "guild", "transmit" }),
                    events   = announceGroup("guild"),
                },
            },

            battleground = {
                type  = "group",
                name  = "Battleground",
                order = 5,
                args  = {
                    transmit        = toggle("Enable transmission",   "Send quest events to battleground.", { "battleground", "transmit" }),
                    displayReceived = toggle("Show received events",  "Show banners from BG members.", { "battleground", "displayReceived" }),
                    friendsOnly     = toggle("Only show notifications from friends", "Suppress banners from non-friends in BG.", { "battleground", "friendsOnly" }),
                    objective       = toggle("Objective progress",    "Announce objective progress in battleground.", { "battleground", "announce", "objective" }),
                    events          = announceGroup("battleground"),
                },
            },

            whisperFriends = {
                type  = "group",
                name  = "Whisper Friends",
                order = 6,
                args  = {
                    enabled   = toggle("Enable whispers to friends", "Send quest events as whispers to online friends.", { "whisperFriends", "enabled" }),
                    groupOnly = toggle("Group members only", "Restrict to friends currently in your group.", { "whisperFriends", "groupOnly" }),
                    objective = toggle("Objective progress", "Include objective progress in friend whispers (off by default).", { "whisperFriends", "announce", "objective" }),
                    events    = {
                        type   = "group",
                        name   = "Events",
                        inline = true,
                        args   = {
                            accepted  = toggle("Accepted",  nil, { "whisperFriends", "announce", "accepted"  }),
                            abandoned = toggle("Abandoned", nil, { "whisperFriends", "announce", "abandoned" }),
                            finished  = toggle("Finished",  nil, { "whisperFriends", "announce", "finished"  }),
                            completed = toggle("Completed", nil, { "whisperFriends", "announce", "completed" }),
                            failed    = toggle("Failed",    nil, { "whisperFriends", "announce", "failed"    }),
                        },
                    },
                },
            },

            follow = {
                type  = "group",
                name  = "Follow Notifications",
                order = 7,
                args  = {
                    enabled           = toggle("Enable follow notifications",       "Send whispers when following starts/stops.", { "follow", "enabled" }),
                    announceFollowing = toggle("Announce when you follow someone",  "Whisper the player you start following.", { "follow", "announceFollowing" }),
                    announceFollowed  = toggle("Announce when followed",            "Show message when someone starts following you.", { "follow", "announceFollowed"  }),
                },
            },

            debug = {
                type  = "group",
                name  = "Debug",
                order = 8,
                args  = {
                    enabled = toggle("Enable debug mode", "Print debug messages to chat.", { "debug", "enabled" }),
                },
            },
        },
    }

    AceConfig:RegisterOptionsTable("SocialQuest", options)
    AceConfigDialog:AddToBlizOptions("SocialQuest")
end
