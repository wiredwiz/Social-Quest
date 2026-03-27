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
L["Test Flight Discovery"]                  = true
L["Display a demo flight path unlock banner using your character's starting city as the demo location."] = true

-- Core/Announcements.lua — flight path discovery banner
-- %s args: (1) sender character name, (2) flight node name. Raw AceComm sender (Name-Realm format).
L["%s unlocked flight path: %s"]                = true

-- UI/Options.lua — Flight Path Discovery group
L["Flight Path Discovery"]                      = true
L["Announce flight path discoveries"]           = true
L["Broadcast to your party when you discover a new flight path."] = true
L["Show banner for party discoveries"]          = true
L["Display a banner notification when a party member discovers a new flight path."] = true

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
