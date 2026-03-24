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
L["%s FINISHED"]                           = "%s TERMINÉE"
L["%s Needs it Shared"]                    = "%s a besoin que ce soit partagé"
L["%s (no data)"]                          = "%s (aucune donnée)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Progression du groupe"
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
L["Test Flight Discovery"]                 = "Tester la découverte de vol"
L["Display a demo flight path unlock banner using your character's starting city as the demo location."] = "Affiche une bannière de démonstration de déblocage d'itinéraire de vol en utilisant la ville de départ de votre personnage comme emplacement de démonstration."

-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."
