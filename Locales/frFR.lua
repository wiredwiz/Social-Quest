-- Locales/frFR.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "frFR")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "Quête acceptée : %s"
L["Quest abandoned: %s"]                  = "Quête abandonnée : %s"
L["Quest complete (objectives done): %s"] = "Quête terminée (objectifs accomplis) : %s"
L["Quest turned in: %s"]                  = "Quête remise : %s"
L["Quest failed: %s"]                     = "Quête échouée : %s"
L["Quest event: %s"]                      = "Événement de quête : %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (régression)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest : %d/%d %s%s pour %s !"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s acceptée : %s"
L["%s abandoned: %s"]                     = "%s abandonnée : %s"
L["%s completed: %s"]                     = "%s a terminé : %s"
L["%s turned in: %s"]                     = "%s a rendu : %s"
L["%s failed: %s"]                        = "%s échouée : %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s a accompli l'objectif : %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s a régressé : %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s a progressé : %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (aperçu) :|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Tout le monde a terminé : %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Vous"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s a commencé à vous suivre."
L["%s stopped following you."]            = "%s a arrêté de vous suivre."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "ERREUR : AbsoluteQuestLog-1.0 n'est pas installé. SocialQuest est désactivé."
L["Left-click to open group quest frame."]  = "Clic gauche pour ouvrir le cadre des quêtes de groupe."
L["Right-click to open settings."]          = "Clic droit pour ouvrir les paramètres."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — Quêtes de groupe"
L["Quest URL (Ctrl+C to copy)"]            = "URL de la quête (Ctrl+C pour copier)"

-- UI/RowFactory.lua
L["expand all"]                            = "tout développer"
L["collapse all"]                          = "tout réduire"
L["Click here to copy the wowhead quest url"] = "Cliquez ici pour copier l'URL Wowhead de la quête"
L["(Complete)"]                            = "(Terminée)"
L["(Group)"]                               = "(Groupe)"
L[" (Step %s of %s)"]                      = " (Étape %s sur %s)"
L["(Step %s)"]                             = "(Étape %s)"
L["Finished"]                              = "Terminée"
L["In Progress"]                           = "En cours"
L["(In Progress)"]                         = "(En cours)"
L["%s Needs it Shared"]                    = "%s a besoin que ce soit partagé"
L["%s (no data)"]                          = "%s (aucune donnée)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Progression du groupe"
L["Party progress"]                        = "Progression du groupe"
L["(shared, no data)"]                     = "(partagée, aucune donnée)"
L["Objectives complete"]                   = "Objectifs accomplis"
L["(no data)"]                             = "(aucune donnée)"

-- UI tab labels
L["Mine"]                                  = "Mes quêtes"
L["Other Quests"]                          = "Autres quêtes"
L["Party"]                                 = "Groupe"
L["(You)"]                                 = "(Vous)"
L["Shared"]                                = "Partagées"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "Acceptée"
L["Abandoned"]                             = "Abandonnée"
L["Complete"]                               = "Terminé"
L["Turned In"]                             = "Rendu"
L["Failed"]                                = "Échouée"
L["Objective Progress"]                    = "Progression d'objectif"
L["Objective Complete"]                    = "Objectif accompli"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "Envoie un message dans le chat lorsque vous acceptez une quête."
L["Send a chat message when you abandon a quest."]                       = "Envoie un message dans le chat lorsque vous abandonnez une quête."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "Envoie un message dans le chat lorsque tous les objectifs de quête sont accomplis (avant la remise)."
L["Send a chat message when you turn in a quest."]                       = "Envoie un message dans le chat lorsque vous remettez une quête."
L["Send a chat message when a quest fails."]                             = "Envoie un message dans le chat lorsqu'une quête échoue."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "Envoie un message dans le chat lorsqu'un objectif de quête progresse ou régresse. Le format correspond au style de Questie. Jamais supprimé par Questie — Questie n'annonce pas la progression partielle."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "Envoie un message dans le chat lorsqu'un objectif de quête atteint son but (ex. 8/8 Kobolds). Supprimé automatiquement si Questie est installé et que son paramètre 'Annoncer les objectifs' est activé."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "Annoncer dans le chat"
L["Own Quest Banners"]                     = "Bannières de mes quêtes"
L["Display Events"]                        = "Afficher les événements"
L["General"]                               = "Général"
L["Raid"]                                  = "Raid"
L["Guild"]                                 = "Guilde"
L["Battleground"]                          = "Champ de bataille"
L["Whisper Friends"]                       = "Chuchoter aux amis"
L["Follow Notifications"]                  = "Notifications de suivi"
L["Debug"]                                 = "Débogage"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "Affiche une bannière lorsque vous acceptez une quête."
L["Show a banner when you abandon a quest."]                                           = "Affiche une bannière lorsque vous abandonnez une quête."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "Affiche une bannière lorsque tous les objectifs d'une quête sont accomplis (avant la remise)."
L["Show a banner when you turn in a quest."]                                           = "Affiche une bannière lorsque vous remettez une quête."
L["Show a banner when a quest fails."]                                                 = "Affiche une bannière lorsqu'une quête échoue."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "Affiche une bannière lorsqu'un de vos objectifs de quête progresse ou régresse."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "Affiche une bannière lorsqu'un de vos objectifs de quête atteint son but (ex. 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "Affiche une bannière lorsqu'un membre du groupe accepte une quête."
L["Show a banner on screen when a group member abandons a quest."]                     = "Affiche une bannière lorsqu'un membre du groupe abandonne une quête."
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "Affiche une bannière lorsqu'un membre du groupe termine tous les objectifs d'une quête."
L["Show a banner on screen when a group member turns in a quest."]                     = "Affiche une bannière lorsqu'un membre du groupe remet une quête."
L["Show a banner on screen when a group member fails a quest."]                        = "Affiche une bannière lorsqu'un membre du groupe échoue une quête."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Affiche une bannière lorsque le nombre d'objectifs d'un membre du groupe change (inclut la progression partielle et la régression)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Affiche une bannière lorsqu'un membre du groupe accomplit un objectif de quête (ex. 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "Activer SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "Interrupteur principal pour toutes les fonctionnalités de SocialQuest."
L["Show received events"]                  = "Afficher les événements reçus"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Interrupteur principal : autorise l'affichage des bannières de notification. Les groupes 'Afficher les événements' ci-dessous contrôlent les types d'événements affichés par section."
L["Colorblind Mode"]                       = "Mode daltonien"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Utilise des couleurs adaptées aux daltoniens pour toutes les bannières et textes d'interface SocialQuest. Inutile d'activer ceci si le mode daltonien est déjà activé dans le client de jeu."
L["Show minimap button"]                    = "Afficher le bouton de la minicarte"
L["Show or hide the SocialQuest minimap button."]                        = "Affiche ou masque le bouton de la minicarte SocialQuest."
L["Show banners for your own quest events"] = "Afficher les bannières pour vos propres événements de quête"
L["Show a banner on screen for your own quest events."]                  = "Affiche une bannière à l'écran pour vos propres événements de quête."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Activer la transmission"
L["Broadcast your quest events to party members via addon comm."]        = "Diffuse vos événements de quête aux membres du groupe via la communication addon."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Autorise les bannières de notification des membres du groupe (selon les paramètres Afficher les événements ci-dessous)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Diffuse vos événements de quête aux membres du raid via la communication addon."
L["Allow banner notifications from raid members."]                       = "Autorise les bannières de notification des membres du raid."
L["Only show notifications from friends"]  = "Afficher uniquement les notifications d'amis"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Affiche uniquement les bannières des joueurs sur votre liste d'amis, supprimant les bannières des inconnus dans les grands raids."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Activer les annonces dans le chat"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Annonce vos événements de quête dans le chat de guilde. Les membres de la guilde n'ont pas besoin d'avoir SocialQuest installé pour voir ces messages."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "Diffuse vos événements de quête aux membres du champ de bataille via la communication addon."
L["Allow banner notifications from battleground members."]               = "Autorise les bannières de notification des membres du champ de bataille."
L["Only show banner notifications from friends in the battleground."]    = "Affiche uniquement les bannières d'amis dans le champ de bataille."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "Activer les chuchotements aux amis"
L["Send your quest events as whispers to online friends."]               = "Envoie vos événements de quête en chuchotements à vos amis en ligne."
L["Group members only"]                    = "Membres du groupe uniquement"
L["Restrict whispers to friends currently in your group."]               = "Limite les chuchotements aux amis actuellement dans votre groupe."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "Activer les notifications de suivi"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "Envoie un chuchotement aux joueurs que vous commencez ou cessez de suivre, et reçoit des notifications lorsque quelqu'un vous suit."
L["Announce when you follow someone"]      = "Annoncer lorsque vous suivez quelqu'un"
L["Whisper the player you begin following so they know you are following them."] = "Chuchote au joueur que vous commencez à suivre afin qu'il sache que vous le suivez."
L["Announce when followed"]                = "Annoncer lorsque vous êtes suivi"
L["Display a local message when someone starts or stops following you."] = "Affiche un message local lorsque quelqu'un commence ou cesse de vous suivre."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "Activer le mode débogage"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "Affiche les messages de débogage internes dans le cadre de chat. Utile pour diagnostiquer les problèmes de communication ou de flux d'événements."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "Tester les bannières et le chat"
L["Test Accepted"]                         = "Tester Acceptée"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "Affiche une bannière de démonstration et un aperçu du chat local pour l'événement 'Quête acceptée'. Contourne tous les filtres d'affichage."
L["Test Abandoned"]                        = "Tester Abandonnée"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "Affiche une bannière de démonstration et un aperçu du chat local pour l'événement 'Quête abandonnée'."
L["Test Complete"]                          = "Tester Terminée"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "Affiche une bannière de démonstration et un aperçu du chat local pour l'événement 'Quête terminée' (tous les objectifs remplis, pas encore rendue)."
L["Test Turned In"]                        = "Tester Rendue"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "Affiche une bannière de démonstration et un aperçu du chat local pour l'événement 'Quête rendue'."
L["Test Failed"]                           = "Tester Échouée"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "Affiche une bannière de démonstration et un aperçu du chat local pour l'événement 'Quête échouée'."
L["Test Obj. Progress"]                    = "Tester progression d'objectif"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "Affiche une bannière de démonstration et un aperçu du chat local pour une mise à jour de progression partielle d'objectif (ex. 3/8)."
L["Test Obj. Complete"]                    = "Tester objectif accompli"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "Affiche une bannière de démonstration et un aperçu du chat local pour l'accomplissement d'un objectif (ex. 8/8)."
L["Test Obj. Regression"]                  = "Tester régression d'objectif"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "Affiche une bannière de démonstration et un aperçu du chat local pour une régression d'objectif (le compteur a reculé)."
L["Test All Completed"]                    = "Tester tout terminé"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Affiche une bannière de démonstration pour la notification violette 'Tout le monde a terminé'. Pas d'aperçu de chat (cet événement ne génère jamais de chat sortant directement)."
L["Test Chat Link"]                        = "Tester le lien de chat"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "Affiche un aperçu de chat local du message 'Quête remise' pour la quête 337 avec un vrai hyperlien WoW. Vérifier que le nom de la quête apparaît en texte doré cliquable dans le cadre de chat."
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "Cliquez pour masquer le filtre actif de cet onglet."
L["Instance: %s"]                           = "Filtre : Instance : %s"
L["Zone: %s"]                               = "Filtre : Zone : %s"
L["Social Quest Window"]                    = "Fenêtre SocialQuest"
L["Auto-filter to current instance"]        = "Filtrer automatiquement sur l'instance en cours"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "Dans un donjon ou un raid, les onglets « Groupe » et « Partagées » n'affichent que les quêtes de l'instance en cours."
L["Auto-filter to current zone"]            = "Filtrer automatiquement sur la zone actuelle"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "Hors instance, les onglets « Groupe » et « Partagées » n'affichent que les quêtes de votre zone actuelle."

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "Rechercher..."
L["Clear search"]                            = "Effacer la recherche"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "zone"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "Nom de zone (correspondance partielle)"
L["filter.key.title"]        = "titre"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "Titre de quête (correspondance partielle)"
L["filter.key.chain"]        = "série"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "Titre de série (correspondance partielle)"
L["filter.key.player"]       = "joueur"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "Nom du membre (onglets Groupe/Partagé uniquement)"
L["filter.key.level"]        = "niveau"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "Niveau recommandé de la quête"
L["filter.key.step"]         = "étape"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "Numéro d'étape dans la série"
L["filter.key.group"]        = "groupe"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "Exigence de groupe (oui, non, 2-5)"
L["filter.key.type"]         = "type"
L["filter.key.type.desc"]    = "Type de quête — série, groupe, solo, chronométré, escorte, donjon, raid, élite, journalière, pvp, tuer, collecter, interagir"
L["filter.key.status"]       = "statut"
L["filter.key.status.desc"]  = "Statut de la quête (complète, incomplète, échouée)"
L["filter.key.tracked"]      = "suivi"
L["filter.key.tracked.desc"] = "Suivi sur la minicarte (oui, non ; onglet Moi uniquement)"
L["filter.key.shareable"]    = "partageable"
L["filter.key.shareable.desc"] = true
L["filter.val.yes"]          = "oui"
L["filter.val.no"]           = "non"
L["filter.val.complete"]     = "complète"
L["filter.val.incomplete"]   = "incomplète"
L["filter.val.failed"]       = "échouée"
L["filter.val.chain"]        = "série"
L["filter.val.group"]        = "groupe"
L["filter.val.solo"]         = "solo"
L["filter.val.timed"]        = "chronométré"
L["filter.val.escort"]       = "escorte"
L["filter.val.dungeon"]      = "donjon"
L["filter.val.raid"]         = "raid"
L["filter.val.elite"]        = "élite"
L["filter.val.daily"]        = "journalière"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "tuer"
L["filter.val.gather"]       = "collecter"
L["filter.val.interact"]     = "interagir"
L["filter.err.UNKNOWN_KEY"]      = "clé de filtre inconnue '%s'"
L["filter.err.INVALID_OPERATOR"] = "l'opérateur '%s' ne peut pas être utilisé avec '%s'"
L["filter.err.TYPE_MISMATCH"]    = "'%s' nécessite un champ numérique"
L["filter.err.UNCLOSED_QUOTE"]   = "guillemet non fermé dans l'expression de filtre"
L["filter.err.EMPTY_VALUE"]      = "valeur manquante après '%s'"
L["filter.err.INVALID_NUMBER"]   = "un nombre est attendu pour '%s', mais '%s' a été reçu"
L["filter.err.RANGE_REVERSED"]   = "plage invalide : le min (%s) doit être <= au max (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' n'est pas une valeur valide pour '%s'"
L["filter.err.label"]            = "Erreur de filtre : %s"
L["filter.err.MIXED_AND_OR"] = true
L["filter.err.AND_KEY_MISMATCH"] = true
L["filter.help.title"]                = "Syntaxe des filtres SQ"
L["filter.help.intro"]                = "Saisissez une expression de filtre et appuyez sur Entrée pour l'appliquer comme étiquette persistante. Fermez une étiquette avec [x]. Pour combiner des filtres, appliquez-les un par un — chaque appui sur Entrée ajoute une nouvelle étiquette (ET logique)."
L["filter.help.section.syntax"]       = "Syntaxe"
L["filter.help.section.keys"]         = "Clés supportées"
L["filter.help.section.examples"]     = "Exemples"
L["filter.help.col.key"]              = "Clé"
L["filter.help.col.aliases"]          = "Alias"
L["filter.help.col.desc"]             = "Description"
L["filter.help.example.1"]            = "niveau>=60"
L["filter.help.example.1.note"]       = "Afficher les quêtes de niveau 60 ou plus"
L["filter.help.example.2"]            = "niveau=58..62"
L["filter.help.example.2.note"]       = "Afficher les quêtes de niveau 58 à 62"
L["filter.help.example.3"]            = "zone=Elwynn|Mortemines"
L["filter.help.example.3.note"]       = "Afficher les quêtes en Forêt d'Elwynn OU dans les Mortemines"
L["filter.help.example.4"]            = "statut=incomplète"
L["filter.help.example.4.note"]       = "Afficher uniquement les quêtes incomplètes"
L["filter.help.example.5"]            = "type=série"
L["filter.help.example.5.note"]       = "Afficher uniquement les quêtes en série"
L["filter.help.example.6"]            = "zone=\"Péninsule des Flammes infernales\""
L["filter.help.example.6.note"]       = "Valeur entre guillemets (à utiliser si la valeur contient des espaces)"
L["filter.help.type.note"]            = "tuer, collecter et interagir correspondent aux quêtes ayant au moins un objectif de ce type — une quête peut correspondre à plusieurs types. Les filtres de type nécessitent l'add-on Questie ou Quest Weaver."
L["filter.help.example.7"]            = "type=donjon"
L["filter.help.example.7.note"]       = "Afficher uniquement les quêtes de donjon (nécessite Questie ou Quest Weaver)"
L["filter.help.example.8"]            = "type=tuer"
L["filter.help.example.8.note"]       = "Afficher les quêtes avec au moins un objectif de type tuer"
L["filter.help.example.9"]            = "type=journalière"
L["filter.help.example.9.note"]       = "Afficher uniquement les quêtes journalières"
L["filter.help.example.10"]           = "suivi=oui"
L["filter.help.example.10.note"]      = "Afficher uniquement les quêtes suivies (onglet Mes quêtes uniquement)"
L["filter.help.example.11"]           = "groupe=non"
L["filter.help.example.11.note"]      = "Afficher uniquement les quêtes solo (sans prérequis de groupe)"
L["filter.help.example.12"] = true
L["filter.help.example.12.note"] = true
L["filter.help.example.13"] = true
L["filter.help.example.13.note"] = true
L["filter.help.example.14"] = true
L["filter.help.example.14.note"] = true
L["filter.help.example.15"] = true
L["filter.help.example.15.note"] = true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Partager"
L["share.tooltip"] = "Partager cette quête avec les membres du groupe"
L["share.reason.level_too_low"]    = "niveau trop bas"
L["share.reason.level_too_high"]   = "niveau trop élevé"
L["share.reason.wrong_race"]       = "mauvaise race"
L["share.reason.wrong_class"]      = "mauvaise classe"
L["share.reason.quest_log_full"]   = "carnet de quêtes plein"
L["share.reason.exclusive_quest"]  = "quête exclusive prise"
L["share.reason.already_advanced"] = "déjà plus loin"

-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "Info-bulles"
L["Enhance Questie/Blizzard tooltips"]               = "Améliorer les info-bulles Questie/Blizzard"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "Ajoute la progression du groupe aux info-bulles de quête existantes."
L["Replace Blizzard quest tooltips"]                  = "Remplacer les info-bulles de quête Blizzard"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "Affiche l'info-bulle complète de SocialQuest au lieu de l'info-bulle de base de WoW."
L["Replace Questie quest tooltips"]                   = "Remplacer les info-bulles de quête Questie"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Affiche l'info-bulle complète de SocialQuest au lieu de l'info-bulle de Questie. Non disponible si Questie n'est pas installé."
-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "Vous suivez cette quête"
L["You have completed this quest"]                    = "Vous avez accompli cette quête"
L["You are eligible for this quest"]                  = "Vous pouvez accepter cette quête"
L["You are not eligible for this quest"]              = "Vous ne pouvez pas accepter cette quête"
-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "Donneur de quête :"
L["Turn In:"]                                         = "Restitution :"
-- UI/Tooltips.lua — BuildTooltip title and location lines
L["Location:"]                                        = "Lieu :"
L["(Dungeon)"]                                        = "(Donjon)"
L["(Raid)"]                                           = "(Raid)"
L["(Group %d+)"]                                      = "(Groupe %d+)"

-- Core/Announcements.lua — friend presence banners
-- %s = character description (e.g. "Arthas 60 Paladin") or "BattleTagName (charDesc)"
L["%s Online"]                              = "%s en ligne"
L["%s Offline"]                             = "%s hors ligne"
L["%s (%s) Online"]                         = "%s (%s) en ligne"
L["%s (%s) Offline"]                        = "%s (%s) hors ligne"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Notifications d'amis"
L["Enable friend notifications"]            = "Activer les notifications d'amis"
L["Show online banners"]                    = "Afficher les bannières de connexion"
L["Show offline banners"]                   = "Afficher les bannières de déconnexion"
L["Show a banner when a friend logs into or out of WoW."]  = "Affiche une bannière quand un ami se connecte ou se déconnecte de WoW."
L["Show a banner when a friend logs into WoW."]            = "Affiche une bannière quand un ami se connecte à WoW."
L["Show a banner when a friend logs out of WoW."]          = "Affiche une bannière quand un ami se déconnecte de WoW."

-- UI/Options.lua — Friend Notifications debug buttons
L["Test Friend Online"]                     = "Test ami en ligne"
L["Display a demo friend online banner."]   = "Affiche une bannière de démonstration pour un ami en ligne."
L["Test Friend Offline"]                    = "Test ami hors ligne"
L["Display a demo friend offline banner."]  = "Affiche une bannière de démonstration pour un ami hors ligne."
