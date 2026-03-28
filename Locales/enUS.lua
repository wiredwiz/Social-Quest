-- Locales/enUS.lua
-- Default locale. Keys are English strings; values are true (AceLocale convention).
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "enUS", true)
if not L then return end

-- Core/Announcements.lua — outbound chat templates
-- Format mirrors Questie: "{rt1} SocialQuest: Quest Verb: link"
L["{rt1} SocialQuest: Quest Accepted: %s"]   = true
L["{rt1} SocialQuest: Quest Abandoned: %s"]  = true
L["{rt1} SocialQuest: Quest Complete: %s"]   = true  -- objectives done, not yet turned in
L["{rt1} SocialQuest: Quest Turned In: %s"]  = true  -- turned in
L["{rt1} SocialQuest: Quest Failed: %s"]     = true
-- Defensive fallback in formatOutboundQuestMsg; unreachable in current call graph.
-- Include for safety; non-English locales need not prioritize it.
L["{rt1} SocialQuest: Quest Event: %s"]      = true

-- Core/Announcements.lua — outbound objective chat
-- Leading space is intentional: appended after objective text when concatenated.
L[" (regression)"]                        = true
-- Five positional args: (1) numFulfilled %d, (2) numRequired %d,
-- (3) objective text %s, (4) regression suffix %s (either " (regression)" or ""),
-- (5) quest link or title %s. All five must be preserved in translations.
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = true

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = true
L["%s abandoned: %s"]                     = true
L["%s turned in: %s"]                     = true
L["%s completed: %s"]                     = true
L["%s failed: %s"]                        = true
L["%s completed objective: %s — %s (%d/%d)"] = true
L["%s regressed: %s — %s (%d/%d)"]           = true
L["%s progressed: %s — %s (%d/%d)"]          = true

-- Core/Announcements.lua — chat preview label
-- Trailing space after |r is intentional: separates label from banner text.
-- All translations must preserve the trailing space and the color/reset codes.
L["|cFF00CCFFSocialQuest (preview):|r "]  = true

-- Core/Announcements.lua — all-completed banner
-- %s = quest title
L["Everyone has completed: %s"]           = true

-- Core/Announcements.lua — own-quest banner sender label
-- Used as the sender name in "You accepted: [Quest]" banners. No parentheses.
L["You"]                                  = true

-- Core/Announcements.lua — chain step annotation
-- Appended to accepted/completed/failed/abandoned messages when the quest is a known
-- chain step. No leading space: the space separator is provided by appendChainStep.
-- %s = step number (integer coerced to string by string.format in Lua 5.1).
L["(Step %s)"]                            = true

-- Core/Announcements.lua — follow notifications
-- %s = player character name
L["%s started following you."]            = true
L["%s stopped following you."]            = true

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = true
L["Left-click to open group quest frame."]  = true
L["Right-click to open settings."]          = true

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"] = true   -- literal em dash U+2014; \xNN hex escapes are Lua 5.2+
L["Quest URL (Ctrl+C to copy)"]             = true

-- UI/RowFactory.lua
L["expand all"]                             = true
L["collapse all"]                           = true
L["Click here to copy the wowhead quest url"] = true
L["(Complete)"]                             = true
L["(Group)"]                                = true
-- Leading space is intentional: appended directly after quest title.
-- %s args: (1) step number, (2) chain length. Both are already tostring'd before format.
L[" (Step %s of %s)"]                       = true
-- %s = player character name
L["%s FINISHED"]                            = true   -- permanent: quest turned in
L["Completed"]                              = true   -- in-progress: objectives done, not yet turned in
L["%s Needs it Shared"]                     = true
L["%s (no data)"]                           = true

-- UI/Tooltips.lua
L["Group Progress"]                         = true
L["(shared, no data)"]                      = true
L["Objectives complete"]                    = true
L["(no data)"]                              = true

-- UI/Tabs/MineTab.lua — tab label
L["Mine"]                                   = true
-- Shared with UI/TabUtils.lua and UI/Tabs/SharedTab.lua (zone fallback)
L["Other Quests"]                           = true

-- UI/Tabs/PartyTab.lua — tab label
L["Party"]                                  = true
-- Local player label in party/shared tab rows. Translate as self-referential placeholder.
L["(You)"]                                  = true

-- UI/Tabs/SharedTab.lua — tab label
L["Shared"]                                 = true

-- UI/Options.lua — toggle names (shared across multiple groups)
L["Accepted"]                               = true
L["Abandoned"]                              = true
L["Complete"]                               = true
L["Turned In"]                             = true
L["Failed"]                                 = true
L["Objective Progress"]                     = true
L["Objective Complete"]                     = true

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = true
L["Send a chat message when you abandon a quest."]                       = true
L["Send a chat message when all your quest objectives are complete (before turning in)."] = true
L["Send a chat message when you turn in a quest."]                       = true
L["Send a chat message when a quest fails."]                             = true
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = true
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = true

-- UI/Options.lua — group headers
L["Announce in Chat"]                       = true
L["Own Quest Banners"]                      = true
L["Display Events"]                         = true
L["General"]                                = true
L["Raid"]                                   = true
L["Guild"]                                  = true
L["Battleground"]                           = true
L["Whisper Friends"]                        = true
L["Follow Notifications"]                   = true
L["Debug"]                                  = true

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = true
L["Show a banner when you abandon a quest."]                                           = true
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = true
L["Show a banner when you turn in a quest."]                                           = true
L["Show a banner when a quest fails."]                                                 = true
L["Show a banner when one of your quest objectives progresses or regresses."]          = true
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = true

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = true
L["Show a banner on screen when a group member abandons a quest."]                     = true
L["Show a banner on screen when a group member completes all objectives on a quest."]   = true
L["Show a banner on screen when a group member turns in a quest."]                     = true
L["Show a banner on screen when a group member fails a quest."]                        = true
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = true
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = true

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                     = true
L["Master on/off switch for all SocialQuest functionality."]             = true
L["Show received events"]                   = true
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = true
L["Colorblind Mode"]                        = true
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = true
L["Show minimap button"]                    = true
L["Show or hide the SocialQuest minimap button."]                        = true
L["Show banners for your own quest events"] = true
L["Show a banner on screen for your own quest events."]                  = true

-- UI/Options.lua — party section
L["Enable transmission"]                    = true
L["Broadcast your quest events to party members via addon comm."]        = true
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = true

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = true
L["Allow banner notifications from raid members."]                       = true
L["Only show notifications from friends"]   = true
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = true

-- UI/Options.lua — guild section
L["Enable chat announcements"]              = true
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = true

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = true
L["Allow banner notifications from battleground members."]               = true
L["Only show banner notifications from friends in the battleground."]    = true

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]             = true
L["Send your quest events as whispers to online friends."]               = true
L["Group members only"]                     = true
L["Restrict whispers to friends currently in your group."]               = true

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]            = true
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = true
L["Announce when you follow someone"]       = true
L["Whisper the player you begin following so they know you are following them."] = true
L["Announce when followed"]                 = true
L["Display a local message when someone starts or stops following you."] = true

-- UI/Options.lua — debug section
L["Enable debug mode"]                      = true
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = true
L["Force Resync"]                           = true
L["Request a fresh quest snapshot from all current group members. Disabled for 30 seconds after each use."] = true

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                  = true
L["Test Accepted"]                          = true
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = true
L["Test Abandoned"]                         = true
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = true
L["Test Complete"]                          = true
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = true
L["Test Turned In"]                         = true
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = true
L["Test Failed"]                            = true
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = true
L["Test Obj. Progress"]                     = true
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = true
L["Test Obj. Complete"]                     = true
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = true
L["Test Obj. Regression"]                   = true
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = true
L["Test All Completed"]                      = true
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = true
L["Test Chat Link"]                         = true
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = true
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = true
L["Display a demo follow notification banner showing the 'started following you' message."] = true

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = true
L["Instance: %s"]                           = "Filter: Instance: %s"
L["Zone: %s"]                               = "Filter: Zone: %s"
L["Social Quest Window"]                    = true
L["Auto-filter to current instance"]        = true
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = true
L["Auto-filter to current zone"]            = true
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = true

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = true
L["Clear search"]                            = true

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "zone"
L["filter.key.zone.z"]       = "z"
L["filter.key.zone.desc"]    = "Zone name (substring match)"
L["filter.key.title"]        = "title"
L["filter.key.title.t"]      = "t"
L["filter.key.title.desc"]   = "Quest title (substring match)"
L["filter.key.chain"]        = "chain"
L["filter.key.chain.c"]      = "c"
L["filter.key.chain.desc"]   = "Chain title (substring match)"
L["filter.key.player"]       = "player"
L["filter.key.player.p"]     = "p"
L["filter.key.player.desc"]  = "Party member name (Party/Shared tabs only)"
L["filter.key.level"]        = "level"
L["filter.key.level.lvl"]    = "lvl"
L["filter.key.level.l"]      = "l"
L["filter.key.level.desc"]   = "Recommended quest level"
L["filter.key.step"]         = "step"
L["filter.key.step.s"]       = "s"
L["filter.key.step.desc"]    = "Chain step number"
L["filter.key.group"]        = "group"
L["filter.key.group.g"]      = "g"
L["filter.key.group.desc"]   = "Group requirement (yes, no, 2-5)"
L["filter.key.type"]         = "type"
L["filter.key.type.desc"]    = "Quest type — chain, group, solo, timed, escort, dungeon, raid, elite, daily, pvp, kill, gather, interact"
L["filter.key.status"]       = "status"
L["filter.key.status.desc"]  = "Quest status (complete, incomplete, failed)"
L["filter.key.tracked"]      = "tracked"
L["filter.key.tracked.desc"] = "Tracked on minimap (yes, no; Mine tab only)"
L["filter.val.yes"]          = "yes"
L["filter.val.no"]           = "no"
L["filter.val.complete"]     = "complete"
L["filter.val.incomplete"]   = "incomplete"
L["filter.val.failed"]       = "failed"
L["filter.val.chain"]        = "chain"
L["filter.val.group"]        = "group"
L["filter.val.solo"]         = "solo"
L["filter.val.timed"]        = "timed"
L["filter.val.escort"]   = "escort"
L["filter.val.dungeon"]  = "dungeon"
L["filter.val.raid"]     = "raid"
L["filter.val.elite"]    = "elite"
L["filter.val.daily"]    = "daily"
L["filter.val.pvp"]      = "pvp"
L["filter.val.kill"]     = "kill"
L["filter.val.gather"]   = "gather"
L["filter.val.interact"] = "interact"
L["filter.err.UNKNOWN_KEY"]      = "unknown filter key '%s'"
L["filter.err.INVALID_OPERATOR"] = "operator '%s' cannot be used with '%s'"
L["filter.err.TYPE_MISMATCH"]    = "'%s' requires a numeric field"
L["filter.err.UNCLOSED_QUOTE"]   = "unclosed quote in filter expression"
L["filter.err.EMPTY_VALUE"]      = "missing value after '%s'"
L["filter.err.INVALID_NUMBER"]   = "expected a number for '%s', got '%s'"
L["filter.err.RANGE_REVERSED"]   = "invalid range: min (%s) must be <= max (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' is not a valid value for '%s'"
L["filter.err.label"]            = "Filter error: %s"
L["filter.help.title"]                = "SQ Filter Syntax"
L["filter.help.intro"]                = "Type a filter expression and press Enter to apply it as a persistent label. Dismiss a label with [x]. Multiple filters AND together."
L["filter.help.section.syntax"]       = "Syntax"
L["filter.help.section.keys"]         = "Supported Keys"
L["filter.help.section.examples"]     = "Examples"
L["filter.help.col.key"]              = "Key"
L["filter.help.col.aliases"]          = "Aliases"
L["filter.help.col.desc"]             = "Description"
L["filter.help.example.1"]            = "level>=60"
L["filter.help.example.1.note"]       = "Show quests for level 60 or higher"
L["filter.help.example.2"]            = "level=58..62"
L["filter.help.example.2.note"]       = "Show quests in the level 58-62 range"
L["filter.help.example.3"]            = "zone=Elwynn|Deadmines"
L["filter.help.example.3.note"]       = "Show quests in Elwynn Forest OR Deadmines"
L["filter.help.example.4"]            = "status=incomplete"
L["filter.help.example.4.note"]       = "Show only incomplete quests"
L["filter.help.example.5"]            = "type=chain"
L["filter.help.example.5.note"]       = "Show only chain quests"
L["filter.help.example.6"]            = "zone=\"Hellfire Peninsula\""
L["filter.help.example.6.note"]       = "Quoted value (use when value contains spaces)"
L["filter.help.type.note"] = "kill, gather, and interact match quests with at least one objective of that kind — quests can match multiple types. Type filters require the Questie or Quest Weaver add-on to be installed."
L["filter.help.example.7"]        = "type=dungeon"
L["filter.help.example.7.note"]   = "Show only dungeon quests (requires Questie or Quest Weaver)"
L["filter.help.example.8"]        = "type=kill"
L["filter.help.example.8.note"]   = "Show quests with at least one kill objective"
L["filter.help.example.9"]        = "type=daily"
L["filter.help.example.9.note"]   = "Show only daily quests"

-- UI/RowFactory.lua — Share button label and tooltip
L["Share"]         = true
L["share.tooltip"] = "Share this quest with party members"

-- UI/RowFactory.lua — Share eligibility reason labels
-- Displayed as "[reason]" next to a party member's name when they cannot receive the shared quest.
-- "needs_quest" is formatted dynamically as "needs: [Quest Title]" — no locale key for the template.
L["share.reason.level_too_low"]    = true   -- player's level is below the quest's minimum
L["share.reason.level_too_high"]   = true   -- player's level is above the quest's maximum
L["share.reason.wrong_race"]       = true   -- player's race cannot take this quest
L["share.reason.wrong_class"]      = true   -- player's class cannot take this quest
L["share.reason.quest_log_full"]   = true   -- player already has 25 quests (TBC cap)
L["share.reason.exclusive_quest"]  = true   -- player completed a mutually exclusive quest
L["share.reason.already_advanced"] = true   -- player is already past this step in the chain
