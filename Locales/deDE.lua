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
L["Finished"]                              = "Abgeschlossen"
L["In Progress"]                           = "In Bearbeitung"
L["(In Progress)"]                         = "(In Bearbeitung)"
L["%s Needs it Shared"]                    = "%s benötigt Teilung"
L["%s (no data)"]                          = "%s (keine Daten)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Gruppenfortschritt"
L["Party progress"]                        = "Gruppenfortschritt"
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

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "Gebiet"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "Gebietsname (Teilstring-Suche)"
L["filter.key.title"]        = "Titel"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "Questtitel (Teilstring-Suche)"
L["filter.key.chain"]        = "Questreihe"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "Questreihentitel (Teilstring-Suche)"
L["filter.key.player"]       = "Spieler"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "Gruppenname (nur Gruppe/Geteilt-Reiter)"
L["filter.key.level"]        = "Stufe"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "Empfohlene Queststufe"
L["filter.key.step"]         = "Schritt"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "Schrittnummer der Questreihe"
L["filter.key.group"]        = "Gruppe"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "Gruppenanforderung (Ja, Nein, 2-5)"
L["filter.key.type"]         = "Typ"
L["filter.key.type.desc"]    = "Questtyp — Questreihe, Gruppe, Solo, Zeitbegrenzt, Eskorte, Verlies, Schlachtzug, Elite, Tagesquest, pvp, Töten, Sammeln, Interagieren"
L["filter.key.status"]       = "Status"
L["filter.key.status.desc"]  = "Queststatus (abgeschlossen, unvollständig, fehlgeschlagen)"
L["filter.key.tracked"]      = "Verfolgt"
L["filter.key.tracked.desc"] = "Auf der Minikarte verfolgt (Ja, Nein; nur Mein-Reiter)"
L["filter.key.shareable"]    = "teilbar"
L["filter.key.shareable.desc"] = true
L["filter.val.yes"]          = "Ja"
L["filter.val.no"]           = "Nein"
L["filter.val.complete"]     = "abgeschlossen"
L["filter.val.incomplete"]   = "unvollständig"
L["filter.val.failed"]       = "fehlgeschlagen"
L["filter.val.chain"]        = "Questreihe"
L["filter.val.group"]        = "Gruppe"
L["filter.val.solo"]         = "Solo"
L["filter.val.timed"]        = "Zeitbegrenzt"
L["filter.val.escort"]       = "Eskorte"
L["filter.val.dungeon"]      = "Verlies"
L["filter.val.raid"]         = "Schlachtzug"
L["filter.val.elite"]        = "Elite"
L["filter.val.daily"]        = "Tagesquest"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "Töten"
L["filter.val.gather"]       = "Sammeln"
L["filter.val.interact"]     = "Interagieren"
L["filter.err.UNKNOWN_KEY"]      = "unbekannter Filterschlüssel '%s'"
L["filter.err.INVALID_OPERATOR"] = "Operator '%s' kann nicht mit '%s' verwendet werden"
L["filter.err.TYPE_MISMATCH"]    = "'%s' erfordert ein numerisches Feld"
L["filter.err.UNCLOSED_QUOTE"]   = "nicht geschlossenes Anführungszeichen im Filterausdruck"
L["filter.err.EMPTY_VALUE"]      = "fehlender Wert nach '%s'"
L["filter.err.INVALID_NUMBER"]   = "Zahl für '%s' erwartet, '%s' erhalten"
L["filter.err.RANGE_REVERSED"]   = "ungültiger Bereich: Min (%s) muss <= Max (%s) sein"
L["filter.err.INVALID_ENUM"]     = "'%s' ist kein gültiger Wert für '%s'"
L["filter.err.label"]            = "Filterfehler: %s"
L["filter.err.MIXED_AND_OR"] = true
L["filter.err.AND_KEY_MISMATCH"] = true
L["filter.help.title"]                = "SQ-Filtersyntax"
L["filter.help.intro"]                = "Filterbedingung eingeben und Enter drücken, um sie als dauerhaftes Label anzuwenden. Label mit [x] schließen. Filter lassen sich kombinieren, indem sie einzeln eingegeben werden — jedes Enter fügt ein neues Label hinzu (UND-Verknüpfung)."
L["filter.help.section.syntax"]       = "Syntax"
L["filter.help.section.keys"]         = "Unterstützte Schlüssel"
L["filter.help.section.examples"]     = "Beispiele"
L["filter.help.col.key"]              = "Schlüssel"
L["filter.help.col.aliases"]          = "Aliase"
L["filter.help.col.desc"]             = "Beschreibung"
L["filter.help.example.1"]            = "Stufe>=60"
L["filter.help.example.1.note"]       = "Quests ab Stufe 60 anzeigen"
L["filter.help.example.2"]            = "Stufe=58..62"
L["filter.help.example.2.note"]       = "Quests im Stufenbereich 58-62 anzeigen"
L["filter.help.example.3"]            = "Gebiet=Elwynn|Todesminen"
L["filter.help.example.3.note"]       = "Quests in Elwynn-Forst ODER den Todesminen anzeigen"
L["filter.help.example.4"]            = "Status=unvollständig"
L["filter.help.example.4.note"]       = "Nur unvollständige Quests anzeigen"
L["filter.help.example.5"]            = "Typ=Questreihe"
L["filter.help.example.5.note"]       = "Nur Questreihen anzeigen"
L["filter.help.example.6"]            = "Gebiet=\"Höllenfeuerhalbinsel\""
L["filter.help.example.6.note"]       = "Wert in Anführungszeichen (bei Werten mit Leerzeichen)"
L["filter.help.type.note"]            = "Töten, Sammeln und Interagieren treffen auf Quests zu, die mindestens ein entsprechendes Ziel haben — Quests können mehreren Typen entsprechen. Typfilter erfordern das Add-on Questie oder Quest Weaver."
L["filter.help.example.7"]            = "Typ=Verlies"
L["filter.help.example.7.note"]       = "Nur Verlies-Quests anzeigen (erfordert Questie oder Quest Weaver)"
L["filter.help.example.8"]            = "Typ=Töten"
L["filter.help.example.8.note"]       = "Quests mit mindestens einem Töten-Ziel anzeigen"
L["filter.help.example.9"]            = "Typ=Tagesquest"
L["filter.help.example.9.note"]       = "Nur Tagesquests anzeigen"
L["filter.help.example.10"]           = "Verfolgt=Ja"
L["filter.help.example.10.note"]      = "Nur verfolgte Quests anzeigen (nur Mein-Reiter)"
L["filter.help.example.11"]           = "Gruppe=Nein"
L["filter.help.example.11.note"]      = "Nur Solo-Quests anzeigen (keine Gruppenanforderung)"
L["filter.help.example.12"] = true
L["filter.help.example.12.note"] = true
L["filter.help.example.13"] = true
L["filter.help.example.13.note"] = true
L["filter.help.example.14"] = true
L["filter.help.example.14.note"] = true
L["filter.help.example.15"] = true
L["filter.help.example.15.note"] = true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Teilen"
L["share.tooltip"] = "Diese Quest mit Gruppenmitgliedern teilen"
L["share.reason.level_too_low"]    = "Level zu niedrig"
L["share.reason.level_too_high"]   = "Level zu hoch"
L["share.reason.wrong_race"]       = "falsche Rasse"
L["share.reason.wrong_class"]      = "falsche Klasse"
L["share.reason.quest_log_full"]   = "Questtagebuch voll"
L["share.reason.exclusive_quest"]  = "exklusive Quest angenommen"
L["share.reason.already_advanced"] = "bereits weiter"

-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Schnellinfos"
L["Enhance Questie/Blizzard tooltips"]               = "Questie/Blizzard-Schnellinfos erweitern"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Fügt den bestehenden Quest-Schnellinfos einen Gruppenfortschrittsabschnitt hinzu."
L["Replace Blizzard quest tooltips"]                  = "Blizzard-Quest-Schnellinfos ersetzen"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Zeigt beim Klick auf einen Quest-Link den vollständigen SocialQuest-Tooltip statt des WoW-Standardtooltips."
L["Replace Questie quest tooltips"]                   = "Questie-Quest-Schnellinfos ersetzen"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Zeigt beim Klick auf einen Questie-Link den vollständigen SocialQuest-Tooltip. Nicht verfügbar, wenn Questie nicht installiert ist."
-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Du bist auf dieser Quest"
L["You have completed this quest"]                    = "Du hast diese Quest abgeschlossen"
L["You are eligible for this quest"]                  = "Du kannst diese Quest annehmen"
L["You are not eligible for this quest"]              = "Du kannst diese Quest nicht annehmen"
-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Questgeber:"
L["Turn In:"]                                         = "Abgabe:"
-- UI/Tooltips.lua — BuildTooltip title and location lines
L["Location:"]                                        = "Ort:"
L["(Dungeon)"]                                        = "(Verlies)"
L["(Raid)"]                                           = "(Schlachtzug)"
L["(Group %d+)"]                                      = "(Gruppe %d+)"

-- Core/Announcements.lua — friend presence banners
-- %s = character description (e.g. "Arthas 60 Paladin") or "BattleTagName (charDesc)"
L["%s Online"]                              = "%s Online"
L["%s Offline"]                             = "%s Offline"
L["%s (%s) Online"]                         = "%s (%s) Online"
L["%s (%s) Offline"]                        = "%s (%s) Offline"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Freundesbenachrichtigungen"
L["Enable friend notifications"]            = "Freundesbenachrichtigungen aktivieren"
L["Show online banners"]                    = "Online-Banner anzeigen"
L["Show offline banners"]                   = "Offline-Banner anzeigen"
L["Show a banner when a friend logs into or out of WoW."]  = "Zeigt ein Banner an, wenn ein Freund sich in WoW ein- oder ausloggt."
L["Show a banner when a friend logs into WoW."]            = "Zeigt ein Banner an, wenn ein Freund sich in WoW einloggt."
L["Show a banner when a friend logs out of WoW."]          = "Zeigt ein Banner an, wenn ein Freund sich aus WoW ausloggt."

-- UI/Options.lua — Friend Notifications debug buttons
L["Test Friend Online"]                     = "Test Freund Online"
L["Display a demo friend online banner."]   = "Zeigt ein Demo-Banner für einen Online-Freund an."
L["Test Friend Offline"]                    = "Test Freund Offline"
L["Display a demo friend offline banner."]  = "Zeigt ein Demo-Banner für einen Offline-Freund an."
