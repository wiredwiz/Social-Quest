-- Locales/itIT.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "itIT")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "Missione accettata: %s"
L["Quest abandoned: %s"]                  = "Missione abbandonata: %s"
L["Quest complete (objectives done): %s"] = "Missione completata (obiettivi raggiunti): %s"
L["Quest turned in: %s"]                  = "Missione consegnata: %s"
L["Quest failed: %s"]                     = "Missione fallita: %s"
L["Quest event: %s"]                      = "Evento missione: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (regressione)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s per %s!"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s accettata: %s"
L["%s abandoned: %s"]                     = "%s abbandonata: %s"
L["%s completed: %s"]                     = "%s ha completato: %s"
L["%s turned in: %s"]                     = "%s ha consegnato: %s"
L["%s failed: %s"]                        = "%s fallita: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s ha completato l'obiettivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s è regredito: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s ha progredito: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (anteprima):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Tutti hanno completato: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Tu"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s ha iniziato a seguirti."
L["%s stopped following you."]            = "%s ha smesso di seguirti."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "ERRORE: AbsoluteQuestLog-1.0 non è installato. SocialQuest è disabilitato."
L["Left-click to open group quest frame."]  = "Clic sinistro per aprire il pannello delle missioni di gruppo."
L["Right-click to open settings."]          = "Clic destro per aprire le impostazioni."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — Missioni di gruppo"
L["Quest URL (Ctrl+C to copy)"]            = "URL missione (Ctrl+C per copiare)"

-- UI/RowFactory.lua
L["expand all"]                            = "espandi tutto"
L["collapse all"]                          = "comprimi tutto"
L["Click here to copy the wowhead quest url"] = "Clicca qui per copiare l'URL Wowhead della missione"
L["(Complete)"]                            = "(Completata)"
L["(Group)"]                               = "(Gruppo)"
L[" (Step %s of %s)"]                      = " (Fase %s di %s)"
L["(Step %s)"]                             = "(Passo %s)"
L["%s FINISHED"]                           = "%s COMPLETATA"
L["%s Needs it Shared"]                    = "%s ha bisogno che venga condivisa"
L["%s (no data)"]                          = "%s (nessun dato)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Progresso del gruppo"
L["(shared, no data)"]                     = "(condivisa, nessun dato)"
L["Objectives complete"]                   = "Obiettivi completati"
L["(no data)"]                             = "(nessun dato)"

-- UI tab labels
L["Mine"]                                  = "Mie"
L["Other Quests"]                          = "Altre missioni"
L["Party"]                                 = "Gruppo"
L["(You)"]                                 = "(Tu)"
L["Shared"]                                = "Condivise"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "Accettata"
L["Abandoned"]                             = "Abbandonata"
L["Complete"]                               = "Completato"
L["Turned In"]                             = "Consegnato"
L["Failed"]                                = "Fallita"
L["Objective Progress"]                    = "Progresso obiettivo"
L["Objective Complete"]                    = "Obiettivo completato"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "Invia un messaggio in chat quando accetti una missione."
L["Send a chat message when you abandon a quest."]                       = "Invia un messaggio in chat quando abbandoni una missione."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "Invia un messaggio in chat quando tutti gli obiettivi della missione sono completati (prima della consegna)."
L["Send a chat message when you turn in a quest."]                       = "Invia un messaggio in chat quando consegni una missione."
L["Send a chat message when a quest fails."]                             = "Invia un messaggio in chat quando una missione fallisce."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "Invia un messaggio in chat quando un obiettivo della missione progredisce o regredisce. Il formato corrisponde allo stile di Questie. Non viene mai soppresso da Questie — Questie non annuncia il progresso parziale."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "Invia un messaggio in chat quando un obiettivo della missione raggiunge il suo traguardo (es. 8/8 Coboldi). Soppresso automaticamente se Questie è installato e la sua impostazione 'Annuncia Obiettivi' è abilitata."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "Annuncia in Chat"
L["Own Quest Banners"]                     = "Banner missioni personali"
L["Display Events"]                        = "Mostra eventi"
L["General"]                               = "Generale"
L["Raid"]                                  = "Raid"
L["Guild"]                                 = "Gilda"
L["Battleground"]                          = "Campo di battaglia"
L["Whisper Friends"]                       = "Sussurra agli amici"
L["Follow Notifications"]                  = "Notifiche di seguimento"
L["Debug"]                                 = "Debug"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "Mostra un banner quando accetti una missione."
L["Show a banner when you abandon a quest."]                                           = "Mostra un banner quando abbandoni una missione."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "Mostra un banner quando tutti gli obiettivi di una missione sono completati (prima della consegna)."
L["Show a banner when you turn in a quest."]                                           = "Mostra un banner quando consegni una missione."
L["Show a banner when a quest fails."]                                                 = "Mostra un banner quando una missione fallisce."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "Mostra un banner quando uno dei tuoi obiettivi della missione progredisce o regredisce."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "Mostra un banner quando uno dei tuoi obiettivi della missione raggiunge il suo traguardo (es. 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "Mostra un banner quando un membro del gruppo accetta una missione."
L["Show a banner on screen when a group member abandons a quest."]                     = "Mostra un banner quando un membro del gruppo abbandona una missione."
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "Mostra un banner quando un membro del gruppo completa tutti gli obiettivi di una missione."
L["Show a banner on screen when a group member turns in a quest."]                     = "Mostra un banner quando un membro del gruppo consegna una missione."
L["Show a banner on screen when a group member fails a quest."]                        = "Mostra un banner quando un membro del gruppo fallisce una missione."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Mostra un banner quando il conteggio degli obiettivi di missione di un membro del gruppo cambia (include progresso parziale e regressione)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Mostra un banner quando un membro del gruppo completa un obiettivo di missione (es. 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "Abilita SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "Interruttore principale per tutte le funzionalità di SocialQuest."
L["Show received events"]                  = "Mostra eventi ricevuti"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Interruttore principale: consente la visualizzazione delle notifiche banner. I gruppi 'Mostra eventi' qui sotto controllano quali tipi di eventi vengono mostrati per sezione."
L["Colorblind Mode"]                       = "Modalità daltonismo"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Usa colori adatti ai daltonici per tutti i banner e i testi dell'interfaccia di SocialQuest. Non è necessario abilitarlo se la modalità daltonismo è già attiva nel client di gioco."
L["Show minimap button"]                    = "Mostra pulsante minimappa"
L["Show or hide the SocialQuest minimap button."]                        = "Mostra o nasconde il pulsante minimappa di SocialQuest."
L["Show banners for your own quest events"] = "Mostra banner per i tuoi eventi missione"
L["Show a banner on screen for your own quest events."]                  = "Mostra un banner sullo schermo per i tuoi eventi missione."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Abilita trasmissione"
L["Broadcast your quest events to party members via addon comm."]        = "Trasmetti i tuoi eventi missione ai membri del gruppo tramite comunicazione addon."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Consenti notifiche banner dai membri del gruppo (soggette alle opzioni Mostra eventi qui sotto)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Trasmetti i tuoi eventi missione ai membri del raid tramite comunicazione addon."
L["Allow banner notifications from raid members."]                       = "Consenti notifiche banner dai membri del raid."
L["Only show notifications from friends"]  = "Mostra solo notifiche dagli amici"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Mostra solo notifiche banner dai giocatori nella tua lista amici, sopprimendo i banner degli sconosciuti nei raid di grandi dimensioni."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Abilita annunci in chat"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Annuncia i tuoi eventi missione nella chat di gilda. I membri della gilda non hanno bisogno di SocialQuest installato per vedere questi messaggi."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "Trasmetti i tuoi eventi missione ai membri del campo di battaglia tramite comunicazione addon."
L["Allow banner notifications from battleground members."]               = "Consenti notifiche banner dai membri del campo di battaglia."
L["Only show banner notifications from friends in the battleground."]    = "Mostra solo notifiche banner dagli amici nel campo di battaglia."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "Abilita sussurri agli amici"
L["Send your quest events as whispers to online friends."]               = "Invia i tuoi eventi missione come sussurri agli amici online."
L["Group members only"]                    = "Solo membri del gruppo"
L["Restrict whispers to friends currently in your group."]               = "Limita i sussurri agli amici attualmente nel tuo gruppo."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "Abilita notifiche di seguimento"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "Invia un sussurro ai giocatori che inizi o smetti di seguire, e ricevi notifiche quando qualcuno ti segue."
L["Announce when you follow someone"]      = "Annuncia quando segui qualcuno"
L["Whisper the player you begin following so they know you are following them."] = "Sussurra al giocatore che inizi a seguire in modo che sappia che lo stai seguendo."
L["Announce when followed"]                = "Annuncia quando sei seguito"
L["Display a local message when someone starts or stops following you."] = "Mostra un messaggio locale quando qualcuno inizia o smette di seguirti."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "Abilita modalità debug"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "Stampa i messaggi di debug interni nel frame chat. Utile per diagnosticare problemi di comunicazione o di flusso eventi."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "Testa banner e chat"
L["Test Accepted"]                         = "Testa Accettata"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "Mostra un banner dimostrativo e un'anteprima chat locale per l'evento 'Missione accettata'. Bypassa tutti i filtri di visualizzazione."
L["Test Abandoned"]                        = "Testa Abbandonata"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "Mostra un banner dimostrativo e un'anteprima chat locale per l'evento 'Missione abbandonata'."
L["Test Complete"]                          = "Testa Completata"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "Mostra un banner dimostrativo e un'anteprima chat locale per l'evento 'Missione completata' (tutti gli obiettivi raggiunti, non ancora consegnata)."
L["Test Turned In"]                        = "Testa Consegnata"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "Mostra un banner dimostrativo e un'anteprima chat locale per l'evento 'Missione consegnata'."
L["Test Failed"]                           = "Testa Fallita"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "Mostra un banner dimostrativo e un'anteprima chat locale per l'evento 'Missione fallita'."
L["Test Obj. Progress"]                    = "Testa progresso obiettivo"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "Mostra un banner dimostrativo e un'anteprima chat locale per un aggiornamento di progresso parziale dell'obiettivo (es. 3/8)."
L["Test Obj. Complete"]                    = "Testa obiettivo completato"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "Mostra un banner dimostrativo e un'anteprima chat locale per il completamento di un obiettivo (es. 8/8)."
L["Test Obj. Regression"]                  = "Testa regressione obiettivo"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "Mostra un banner dimostrativo e un'anteprima chat locale per una regressione dell'obiettivo (il conteggio è andato indietro)."
L["Test All Completed"]                    = "Testa tutti completati"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Mostra un banner demo per la notifica viola 'Tutti hanno completato'. Nessuna anteprima chat (questo evento non genera mai chat in uscita direttamente)."
L["Test Chat Link"]                        = "Testa collegamento chat"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "Mostra un'anteprima chat locale del messaggio 'Quest consegnata' per la quest 337 usando un vero hyperlink WoW. Verifica che il nome della quest appaia come testo dorato cliccabile nel frame chat."
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "Clicca per chiudere il filtro attivo di questa scheda."
L["Instance: %s"]                           = "Filtro: Istanza: %s"
L["Zone: %s"]                               = "Filtro: Zona: %s"
L["Social Quest Window"]                    = "Finestra SocialQuest"
L["Auto-filter to current instance"]        = "Filtra automaticamente per istanza corrente"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "All'interno di un dungeon o raid, le schede 'Gruppo' e 'Condivise' mostrano solo le quest dell'istanza corrente."
L["Auto-filter to current zone"]            = "Filtra automaticamente per zona corrente"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "Al di fuori delle istanze, le schede 'Gruppo' e 'Condivise' mostrano solo le quest della tua zona corrente."

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "Cerca..."
L["Clear search"]                            = "Cancella ricerca"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "zona"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "Nome della zona (corrispondenza parziale)"
L["filter.key.title"]        = "titolo"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "Titolo della missione (corrispondenza parziale)"
L["filter.key.chain"]        = "serie"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "Titolo della serie (corrispondenza parziale)"
L["filter.key.player"]       = "giocatore"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "Nome del membro (solo schede Gruppo/Condiviso)"
L["filter.key.level"]        = "livello"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "Livello consigliato della missione"
L["filter.key.step"]         = "passo"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "Numero del passo nella serie"
L["filter.key.group"]        = "gruppo"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "Requisito di gruppo (sì, no, 2-5)"
L["filter.key.type"]         = "tipo"
L["filter.key.type.desc"]    = "Tipo di missione — serie, gruppo, solo, a tempo, scorta, dungeon, incursione, elite, giornaliera, pvp, uccidere, raccogliere, interagire"
L["filter.key.status"]       = "stato"
L["filter.key.status.desc"]  = "Stato della missione (completata, incompleta, fallita)"
L["filter.key.tracked"]      = "monitorato"
L["filter.key.tracked.desc"] = "Monitorato sulla minimappa (sì, no; solo scheda Mio)"
L["filter.key.shareable"]    = "condivisibile"
L["filter.key.shareable.desc"]=true
L["filter.val.yes"]          = "sì"
L["filter.val.no"]           = "no"
L["filter.val.complete"]     = "completata"
L["filter.val.incomplete"]   = "incompleta"
L["filter.val.failed"]       = "fallita"
L["filter.val.chain"]        = "serie"
L["filter.val.group"]        = "gruppo"
L["filter.val.solo"]         = "solo"
L["filter.val.timed"]        = "a tempo"
L["filter.val.escort"]       = "scorta"
L["filter.val.dungeon"]      = "dungeon"
L["filter.val.raid"]         = "incursione"
L["filter.val.elite"]        = "elite"
L["filter.val.daily"]        = "giornaliera"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "uccidere"
L["filter.val.gather"]       = "raccogliere"
L["filter.val.interact"]     = "interagire"
L["filter.err.UNKNOWN_KEY"]      = "chiave filtro sconosciuta '%s'"
L["filter.err.INVALID_OPERATOR"] = "l'operatore '%s' non può essere usato con '%s'"
L["filter.err.TYPE_MISMATCH"]    = "'%s' richiede un campo numerico"
L["filter.err.UNCLOSED_QUOTE"]   = "virgolette non chiuse nell'espressione del filtro"
L["filter.err.EMPTY_VALUE"]      = "valore mancante dopo '%s'"
L["filter.err.INVALID_NUMBER"]   = "era atteso un numero per '%s', ricevuto '%s'"
L["filter.err.RANGE_REVERSED"]   = "intervallo non valido: il min (%s) deve essere <= max (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' non è un valore valido per '%s'"
L["filter.err.label"]            = "Errore filtro: %s"
L["filter.err.MIXED_AND_OR"]=true
L["filter.err.AND_KEY_MISMATCH"]=true
L["filter.help.title"]                = "Sintassi filtri SQ"
L["filter.help.intro"]                = "Digita un'espressione di filtro e premi Invio per applicarla come etichetta persistente. Chiudi un'etichetta con [x]. Per combinare più filtri, applicali uno alla volta — ogni Invio aggiunge una nuova etichetta (logica E)."
L["filter.help.section.syntax"]       = "Sintassi"
L["filter.help.section.keys"]         = "Chiavi supportate"
L["filter.help.section.examples"]     = "Esempi"
L["filter.help.col.key"]              = "Chiave"
L["filter.help.col.aliases"]          = "Alias"
L["filter.help.col.desc"]             = "Descrizione"
L["filter.help.example.1"]            = "livello>=60"
L["filter.help.example.1.note"]       = "Mostra missioni di livello 60 o superiore"
L["filter.help.example.2"]            = "livello=58..62"
L["filter.help.example.2.note"]       = "Mostra missioni nel range di livello 58-62"
L["filter.help.example.3"]            = "zona=Elwynn|Miniere"
L["filter.help.example.3.note"]       = "Mostra missioni nella Foresta di Elwynn O nelle Miniere della Morte"
L["filter.help.example.4"]            = "stato=incompleta"
L["filter.help.example.4.note"]       = "Mostra solo missioni incomplete"
L["filter.help.example.5"]            = "tipo=serie"
L["filter.help.example.5.note"]       = "Mostra solo missioni in serie"
L["filter.help.example.6"]            = "zona=\"Penisola del Fuoco Infernale\""
L["filter.help.example.6.note"]       = "Valore tra virgolette (da usare quando il valore contiene spazi)"
L["filter.help.type.note"]            = "uccidere, raccogliere e interagire corrispondono alle missioni con almeno un obiettivo di quel tipo — le missioni possono corrispondere a più tipi. I filtri di tipo richiedono l'add-on Questie o Quest Weaver."
L["filter.help.example.7"]            = "tipo=dungeon"
L["filter.help.example.7.note"]       = "Mostra solo missioni dungeon (richiede Questie o Quest Weaver)"
L["filter.help.example.8"]            = "tipo=uccidere"
L["filter.help.example.8.note"]       = "Mostra missioni con almeno un obiettivo di uccidere"
L["filter.help.example.9"]            = "tipo=giornaliera"
L["filter.help.example.9.note"]       = "Mostra solo missioni giornaliere"
L["filter.help.example.10"]           = "monitorato=sì"
L["filter.help.example.10.note"]      = "Mostra solo le missioni monitorate (solo scheda Le mie)"
L["filter.help.example.11"]           = "gruppo=no"
L["filter.help.example.11.note"]      = "Mostra solo le missioni in solitaria (nessun requisito di gruppo)"
L["filter.help.example.12"]=true
L["filter.help.example.12.note"]=true
L["filter.help.example.13"]=true
L["filter.help.example.13.note"]=true
L["filter.help.example.14"]=true
L["filter.help.example.14.note"]=true
L["filter.help.example.15"]=true
L["filter.help.example.15.note"]=true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Condividi"
L["share.tooltip"] = "Condividi questa missione con i membri del gruppo"
L["share.reason.level_too_low"]    = "livello troppo basso"
L["share.reason.level_too_high"]   = "livello troppo alto"
L["share.reason.wrong_race"]       = "razza sbagliata"
L["share.reason.wrong_class"]      = "classe sbagliata"
L["share.reason.quest_log_full"]   = "diario delle missioni pieno"
L["share.reason.exclusive_quest"]  = "missione esclusiva accettata"
L["share.reason.already_advanced"] = "già oltre questo passo"
