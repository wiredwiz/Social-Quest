-- Locales/deDE.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "deDE")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "Quest angenommen: %s"
L["Quest abandoned: %s"]                  = "Quest abgebrochen: %s"
L["Quest complete (objectives done): %s"] = "Quest abgeschlossen (Ziele erfüllt): %s"
L["Quest turned in: %s"]                  = "Quest abgegeben: %s"
L["Quest failed: %s"]                     = "Quest fehlgeschlagen: %s"
L["Quest event: %s"]                      = "Quest-Ereignis: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (Rückschritt)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s für %s!"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s angenommen: %s"
L["%s abandoned: %s"]                     = "%s abgebrochen: %s"
L["%s completed: %s"]                     = "%s hat Ziele abgeschlossen: %s"
L["%s turned in: %s"]                     = "%s abgegeben: %s"
L["%s failed: %s"]                        = "%s fehlgeschlagen: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s hat Ziel abgeschlossen: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s zurückgegangen: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s Fortschritt: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (Vorschau):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Alle haben abgeschlossen: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Du"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s folgt dir jetzt."
L["%s stopped following you."]            = "%s folgt dir nicht mehr."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "FEHLER: AbsoluteQuestLog-1.0 ist nicht installiert. SocialQuest ist deaktiviert."
L["Left-click to open group quest frame."]  = "Linksklick zum Öffnen des Gruppenquest-Fensters."
L["Right-click to open settings."]          = "Rechtsklick zum Öffnen der Einstellungen."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — Gruppenquests"
L["Quest URL (Ctrl+C to copy)"]            = "Quest-URL (Strg+C zum Kopieren)"

-- UI/RowFactory.lua
L["expand all"]                            = "alle ausklappen"
L["collapse all"]                          = "alle einklappen"
L["Click here to copy the wowhead quest url"] = "Klicken, um die Wowhead-Quest-URL zu kopieren"
L["(Complete)"]                            = "(Abgeschlossen)"
L["(Group)"]                               = "(Gruppe)"
L[" (Step %s of %s)"]                      = " (Schritt %s von %s)"
L["(Step %s)"]                             = "(Schritt %s)"
L["%s FINISHED"]                           = "%s ABGESCHLOSSEN"
L["%s Needs it Shared"]                    = "%s benötigt Teilung"
L["%s (no data)"]                          = "%s (keine Daten)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Gruppenfortschritt"
L["(shared, no data)"]                     = "(geteilt, keine Daten)"
L["Objectives complete"]                   = "Ziele abgeschlossen"
L["(no data)"]                             = "(keine Daten)"

-- UI tab labels
L["Mine"]                                  = "Meine"
L["Other Quests"]                          = "Andere Quests"
L["Party"]                                 = "Gruppe"
L["(You)"]                                 = "(Du)"
L["Shared"]                                = "Geteilt"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "Angenommen"
L["Abandoned"]                             = "Abgebrochen"
L["Complete"]                               = "Abgeschlossen"
L["Turned In"]                             = "Abgegeben"
L["Failed"]                                = "Fehlgeschlagen"
L["Objective Progress"]                    = "Zielfortschritt"
L["Objective Complete"]                    = "Ziel abgeschlossen"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "Sendet eine Chat-Nachricht, wenn du eine Quest annimmst."
L["Send a chat message when you abandon a quest."]                       = "Sendet eine Chat-Nachricht, wenn du eine Quest abbrichst."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "Sendet eine Chat-Nachricht, wenn alle Questziele erfüllt sind (vor der Abgabe)."
L["Send a chat message when you turn in a quest."]                       = "Sendet eine Chat-Nachricht, wenn du eine Quest abgibst."
L["Send a chat message when a quest fails."]                             = "Sendet eine Chat-Nachricht, wenn eine Quest fehlschlägt."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "Sendet eine Chat-Nachricht bei Fortschritt oder Rückschritt eines Questziels. Format entspricht Questies Stil. Wird nie von Questie unterdrückt — Questie meldet keinen Teilfortschritt."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "Sendet eine Chat-Nachricht, wenn ein Questziel erreicht wird (z.B. 8/8 Kobolde). Wird automatisch unterdrückt, wenn Questie installiert ist und 'Ziele ankündigen' aktiviert ist."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "Im Chat ankündigen"
L["Own Quest Banners"]                     = "Eigene Quest-Banner"
L["Display Events"]                        = "Ereignisse anzeigen"
L["General"]                               = "Allgemein"
L["Raid"]                                  = "Schlachtzug"
L["Guild"]                                 = "Gilde"
L["Battleground"]                          = "Schlachtfeld"
L["Whisper Friends"]                       = "Freunde flüstern"
L["Follow Notifications"]                  = "Folge-Benachrichtigungen"
L["Debug"]                                 = "Debug"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "Zeigt einen Banner, wenn du eine Quest annimmst."
L["Show a banner when you abandon a quest."]                                           = "Zeigt einen Banner, wenn du eine Quest abbrichst."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "Zeigt einen Banner, wenn alle Questziele erfüllt sind (vor der Abgabe)."
L["Show a banner when you turn in a quest."]                                           = "Zeigt einen Banner, wenn du eine Quest abgibst."
L["Show a banner when a quest fails."]                                                 = "Zeigt einen Banner, wenn eine Quest fehlschlägt."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "Zeigt einen Banner, wenn ein Questziel Fortschritt oder Rückschritt verzeichnet."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "Zeigt einen Banner, wenn ein Questziel erreicht wird (z.B. 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "Zeigt einen Banner, wenn ein Gruppenmitglied eine Quest annimmt."
L["Show a banner on screen when a group member abandons a quest."]                     = "Zeigt einen Banner, wenn ein Gruppenmitglied eine Quest abbricht."
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "Zeigt einen Banner, wenn ein Gruppenmitglied alle Questziele abschließt."
L["Show a banner on screen when a group member turns in a quest."]                     = "Zeigt einen Banner, wenn ein Gruppenmitglied eine Quest abgibt."
L["Show a banner on screen when a group member fails a quest."]                        = "Zeigt einen Banner, wenn ein Gruppenmitglied eine Quest nicht besteht."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Zeigt einen Banner, wenn sich der Questzielstand eines Gruppenmitglieds ändert (inkl. Teilfortschritt und Rückschritt)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Zeigt einen Banner, wenn ein Gruppenmitglied ein Questziel abschließt (z.B. 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "SocialQuest aktivieren"
L["Master on/off switch for all SocialQuest functionality."]             = "Haupt-Ein/Aus-Schalter für alle SocialQuest-Funktionen."
L["Show received events"]                  = "Empfangene Ereignisse anzeigen"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Hauptschalter: Erlaubt das Anzeigen von Banner-Benachrichtigungen. Die einzelnen 'Ereignisse anzeigen'-Gruppen unten steuern, welche Ereignistypen je Abschnitt angezeigt werden."
L["Colorblind Mode"]                       = "Farbenblind-Modus"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Verwendet farbenblindfreundliche Farben für alle SocialQuest-Banner und UI-Texte. Nicht nötig, wenn der Farbenblind-Modus bereits im Spielclient aktiviert ist."
L["Show minimap button"]                    = "Minimap-Schaltfläche anzeigen"
L["Show or hide the SocialQuest minimap button."]                        = "Zeigt oder versteckt die SocialQuest-Minimap-Schaltfläche."
L["Show banners for your own quest events"] = "Banner für eigene Quest-Ereignisse anzeigen"
L["Show a banner on screen for your own quest events."]                  = "Zeigt einen Banner auf dem Bildschirm für eigene Quest-Ereignisse."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Übertragung aktivieren"
L["Broadcast your quest events to party members via addon comm."]        = "Sendet deine Quest-Ereignisse per Addon-Kommunikation an Gruppenmitglieder."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Erlaubt Banner-Benachrichtigungen von Gruppenmitgliedern (gemäß den Ereignisse-anzeigen-Einstellungen unten)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Sendet deine Quest-Ereignisse per Addon-Kommunikation an Schlachtzugsmitglieder."
L["Allow banner notifications from raid members."]                       = "Erlaubt Banner-Benachrichtigungen von Schlachtzugsmitgliedern."
L["Only show notifications from friends"]  = "Nur Benachrichtigungen von Freunden anzeigen"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Zeigt nur Banner-Benachrichtigungen von Spielern auf deiner Freundesliste an und unterdrückt Banner von Fremden in großen Schlachtzügen."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Chat-Ankündigungen aktivieren"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Kündigt deine Quest-Ereignisse im Gilden-Chat an. Gildenmitglieder benötigen SocialQuest nicht installiert, um diese Nachrichten zu sehen."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "Sendet deine Quest-Ereignisse per Addon-Kommunikation an Schlachtfeld-Teilnehmer."
L["Allow banner notifications from battleground members."]               = "Erlaubt Banner-Benachrichtigungen von Schlachtfeld-Teilnehmern."
L["Only show banner notifications from friends in the battleground."]    = "Zeigt im Schlachtfeld nur Banner-Benachrichtigungen von Freunden an."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "Flüstern an Freunde aktivieren"
L["Send your quest events as whispers to online friends."]               = "Sendet deine Quest-Ereignisse als Flüsternachrichten an Online-Freunde."
L["Group members only"]                    = "Nur Gruppenmitglieder"
L["Restrict whispers to friends currently in your group."]               = "Flüsternachrichten auf Freunde beschränken, die sich in deiner Gruppe befinden."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "Folge-Benachrichtigungen aktivieren"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "Sendet eine Flüsternachricht an Spieler, denen du zu folgen beginnst oder aufhörst, und empfängt Benachrichtigungen, wenn dir jemand folgt."
L["Announce when you follow someone"]      = "Ankündigen, wenn du jemandem folgst"
L["Whisper the player you begin following so they know you are following them."] = "Flüstert dem Spieler, dem du zu folgen beginnst, damit er weiß, dass du ihm folgst."
L["Announce when followed"]                = "Ankündigen, wenn dir jemand folgt"
L["Display a local message when someone starts or stops following you."] = "Zeigt eine lokale Nachricht an, wenn jemand beginnt oder aufhört, dir zu folgen."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "Debug-Modus aktivieren"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "Gibt interne Debug-Nachrichten im Chat-Fenster aus. Nützlich zur Diagnose von Kommunikations- oder Ereignisproblemen."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "Banner und Chat testen"
L["Test Accepted"]                         = "Angenommen testen"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für das Ereignis 'Quest angenommen'. Umgeht alle Anzeigefilter."
L["Test Abandoned"]                        = "Abgebrochen testen"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für das Ereignis 'Quest abgebrochen'."
L["Test Complete"]                          = "Abgeschlossen testen"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für das Ereignis 'Quest abgeschlossen' (alle Ziele erfüllt, noch nicht abgegeben)."
L["Test Turned In"]                        = "Abgegeben testen"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für das Ereignis 'Quest abgegeben'."
L["Test Failed"]                           = "Fehlgeschlagen testen"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für das Ereignis 'Quest fehlgeschlagen'."
L["Test Obj. Progress"]                    = "Zielfortschritt testen"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für einen Teilzielfortschritt (z.B. 3/8)."
L["Test Obj. Complete"]                    = "Ziel abgeschlossen testen"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für einen Zielabschluss (z.B. 8/8)."
L["Test Obj. Regression"]                  = "Zielrückschritt testen"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "Zeigt einen Demo-Banner und eine lokale Chat-Vorschau für einen Zielrückschritt (Zähler wurde zurückgesetzt)."
L["Test All Completed"]                    = "Alle Ziele abgeschlossen testen"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Zeigt einen Demo-Banner für die lilafarbene Benachrichtigung 'Alle haben abgeschlossen'. Keine Chat-Vorschau (dieses Ereignis erzeugt nie direkt ausgehenden Chat)."
L["Test Chat Link"]                        = "Chat-Link testen"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "Gibt eine lokale Chat-Vorschau einer 'Quest abgegeben'-Nachricht für Quest 337 mit einem echten WoW-Quest-Hyperlink aus. Überprüfen, ob der Questname als anklickbarer goldener Text im Chat-Fenster erscheint."
L["Test Flight Discovery"]                 = "Flugrouten-Entdeckung testen"
L["Display a demo flight path unlock banner using your character's starting city as the demo location."] = "Zeigt einen Demo-Banner für das Freischalten einer Flugroute mit der Startstadt deines Charakters als Demo-Ort."

-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "Klicken, um den aktiven Filter für diesen Tab auszublenden."
L["Instance: %s"]                           = "Filter: Instanz: %s"
L["Zone: %s"]                               = "Filter: Zone: %s"
L["Social Quest Window"]                    = "SocialQuest-Fenster"
L["Auto-filter to current instance"]        = "Automatisch auf aktuelle Instanz filtern"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "Innerhalb eines Dungeons oder Schlachtzugs zeigen die Tabs 'Gruppe' und 'Geteilt' nur Quests der aktuellen Instanz."
L["Auto-filter to current zone"]            = "Automatisch auf aktuelle Zone filtern"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "Außerhalb von Instanzen zeigen die Tabs 'Gruppe' und 'Geteilt' nur Quests deiner aktuellen Zone."

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "Suchen..."
L["Clear search"]                            = "Suche leeren"

-- Advanced filter language (Feature #18) — translate these strings
L["filter.key.zone"]=true L["filter.key.zone.z"]=true L["filter.key.zone.desc"]=true
L["filter.key.title"]=true L["filter.key.title.t"]=true L["filter.key.title.desc"]=true
L["filter.key.chain"]=true L["filter.key.chain.c"]=true L["filter.key.chain.desc"]=true
L["filter.key.player"]=true L["filter.key.player.p"]=true L["filter.key.player.desc"]=true
L["filter.key.level"]=true L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true L["filter.key.level.desc"]=true
L["filter.key.step"]=true L["filter.key.step.s"]=true L["filter.key.step.desc"]=true
L["filter.key.group"]=true L["filter.key.group.g"]=true L["filter.key.group.desc"]=true
L["filter.key.type"]=true L["filter.key.type.desc"]=true
L["filter.key.status"]=true L["filter.key.status.desc"]=true
L["filter.key.tracked"]=true L["filter.key.tracked.desc"]=true
L["filter.val.yes"]=true L["filter.val.no"]=true
L["filter.val.complete"]=true L["filter.val.incomplete"]=true L["filter.val.failed"]=true
L["filter.val.chain"]=true L["filter.val.group"]=true L["filter.val.solo"]=true L["filter.val.timed"]=true
L["filter.val.escort"]=true L["filter.val.dungeon"]=true L["filter.val.raid"]=true L["filter.val.elite"]=true L["filter.val.daily"]=true L["filter.val.pvp"]=true
L["filter.val.kill"]=true L["filter.val.gather"]=true L["filter.val.interact"]=true
L["filter.err.UNKNOWN_KEY"]=true L["filter.err.INVALID_OPERATOR"]=true
L["filter.err.TYPE_MISMATCH"]=true L["filter.err.UNCLOSED_QUOTE"]=true
L["filter.err.EMPTY_VALUE"]=true L["filter.err.INVALID_NUMBER"]=true
L["filter.err.RANGE_REVERSED"]=true L["filter.err.INVALID_ENUM"]=true
L["filter.err.label"]=true
L["filter.help.title"]=true L["filter.help.intro"]=true
L["filter.help.section.syntax"]=true L["filter.help.section.keys"]=true L["filter.help.section.examples"]=true
L["filter.help.col.key"]=true L["filter.help.col.aliases"]=true L["filter.help.col.desc"]=true
L["filter.help.example.1"]=true L["filter.help.example.1.note"]=true
L["filter.help.example.2"]=true L["filter.help.example.2.note"]=true
L["filter.help.example.3"]=true L["filter.help.example.3.note"]=true
L["filter.help.example.4"]=true L["filter.help.example.4.note"]=true
L["filter.help.example.5"]=true L["filter.help.example.5.note"]=true
L["filter.help.example.6"]=true L["filter.help.example.6.note"]=true
L["filter.help.type.note"]=true
L["filter.help.example.7"]=true L["filter.help.example.7.note"]=true
L["filter.help.example.8"]=true L["filter.help.example.8.note"]=true
L["filter.help.example.9"]=true L["filter.help.example.9.note"]=true
