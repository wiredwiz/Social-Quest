-- Locales/esES.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "esES")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "Misión aceptada: %s"
L["Quest abandoned: %s"]                  = "Misión abandonada: %s"
L["Quest complete (objectives done): %s"] = "Misión completa (objetivos cumplidos): %s"
L["Quest turned in: %s"]                  = "Misión entregada: %s"
L["Quest failed: %s"]                     = "Misión fallida: %s"
L["Quest event: %s"]                      = "Evento de misión: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (regresión)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s para %s!"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s aceptada: %s"
L["%s abandoned: %s"]                     = "%s abandonada: %s"
L["%s finished objectives: %s"]           = "%s ha terminado los objetivos: %s"
L["%s completed: %s"]                     = "%s completada: %s"
L["%s failed: %s"]                        = "%s fallida: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s ha completado el objetivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s ha retrocedido: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s ha progresado: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (vista previa):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Todos han completado: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Tú"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s ha empezado a seguirte."
L["%s stopped following you."]            = "%s ha dejado de seguirte."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "ERROR: AbsoluteQuestLog-1.0 no está instalado. SocialQuest está desactivado."
L["Left-click to open group quest frame."]  = "Clic izquierdo para abrir el panel de misiones de grupo."
L["Right-click to open settings."]          = "Clic derecho para abrir la configuración."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — Misiones de grupo"
L["Quest URL (Ctrl+C to copy)"]            = "URL de misión (Ctrl+C para copiar)"

-- UI/RowFactory.lua
L["expand all"]                            = "expandir todo"
L["collapse all"]                          = "contraer todo"
L["Click here to copy the wowhead quest url"] = "Haz clic aquí para copiar la URL de Wowhead de la misión"
L["(Complete)"]                            = "(Completa)"
L["(Group)"]                               = "(Grupo)"
L[" (Step %s of %s)"]                      = " (Paso %s de %s)"
L["%s FINISHED"]                           = "%s TERMINADA"
L["%s Needs it Shared"]                    = "%s necesita que se comparta"
L["%s (no data)"]                          = "%s (sin datos)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Progreso del grupo"
L["(shared, no data)"]                     = "(compartida, sin datos)"
L["Objectives complete"]                   = "Objetivos completados"
L["(no data)"]                             = "(sin datos)"

-- UI tab labels
L["Mine"]                                  = "Mías"
L["Other Quests"]                          = "Otras misiones"
L["Party"]                                 = "Grupo"
L["(You)"]                                 = "(Tú)"
L["Shared"]                                = "Compartidas"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "Aceptada"
L["Abandoned"]                             = "Abandonada"
L["Finished"]                              = "Terminada"
L["Completed"]                             = "Completada"
L["Failed"]                                = "Fallida"
L["Objective Progress"]                    = "Progreso de objetivo"
L["Objective Complete"]                    = "Objetivo completado"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "Envía un mensaje de chat cuando aceptas una misión."
L["Send a chat message when you abandon a quest."]                       = "Envía un mensaje de chat cuando abandonas una misión."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "Envía un mensaje de chat cuando todos los objetivos de la misión están completos (antes de entregarla)."
L["Send a chat message when you turn in a quest."]                       = "Envía un mensaje de chat cuando entregas una misión."
L["Send a chat message when a quest fails."]                             = "Envía un mensaje de chat cuando falla una misión."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "Envía un mensaje de chat cuando un objetivo de misión progresa o retrocede. El formato coincide con el estilo de Questie. Nunca suprimido por Questie — Questie no anuncia el progreso parcial."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "Envía un mensaje de chat cuando un objetivo de misión alcanza su meta (p. ej. 8/8 Kobolds). Se suprime automáticamente si Questie está instalado y su ajuste 'Anunciar objetivos' está activado."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "Anunciar en el chat"
L["Own Quest Banners"]                     = "Banners de mis misiones"
L["Display Events"]                        = "Mostrar eventos"
L["General"]                               = "General"
L["Raid"]                                  = "Banda"
L["Guild"]                                 = "Hermandad"
L["Battleground"]                          = "Campo de batalla"
L["Whisper Friends"]                       = "Susurrar a amigos"
L["Follow Notifications"]                  = "Notificaciones de seguimiento"
L["Debug"]                                 = "Depuración"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "Muestra un banner cuando aceptas una misión."
L["Show a banner when you abandon a quest."]                                           = "Muestra un banner cuando abandonas una misión."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "Muestra un banner cuando todos los objetivos de una misión están completos (antes de entregarla)."
L["Show a banner when you turn in a quest."]                                           = "Muestra un banner cuando entregas una misión."
L["Show a banner when a quest fails."]                                                 = "Muestra un banner cuando falla una misión."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "Muestra un banner cuando uno de tus objetivos de misión progresa o retrocede."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "Muestra un banner cuando uno de tus objetivos de misión alcanza su meta (p. ej. 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "Muestra un banner cuando un miembro del grupo acepta una misión."
L["Show a banner on screen when a group member abandons a quest."]                     = "Muestra un banner cuando un miembro del grupo abandona una misión."
L["Show a banner on screen when a group member finishes all objectives on a quest."]   = "Muestra un banner cuando un miembro del grupo termina todos los objetivos de una misión."
L["Show a banner on screen when a group member turns in a quest."]                     = "Muestra un banner cuando un miembro del grupo entrega una misión."
L["Show a banner on screen when a group member fails a quest."]                        = "Muestra un banner cuando un miembro del grupo falla una misión."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Muestra un banner cuando el recuento de objetivos de misión de un miembro del grupo cambia (incluye progreso parcial y regresión)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Muestra un banner cuando un miembro del grupo completa un objetivo de misión (p. ej. 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "Activar SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "Interruptor principal para todas las funciones de SocialQuest."
L["Show received events"]                  = "Mostrar eventos recibidos"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Interruptor principal: permite que aparezcan notificaciones de banner. Los grupos 'Mostrar eventos' a continuación controlan qué tipos de eventos se muestran por sección."
L["Colorblind Mode"]                       = "Modo daltónico"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Usa colores aptos para daltónicos en todos los banners y textos de interfaz de SocialQuest. No es necesario activarlo si el modo daltónico ya está habilitado en el cliente de juego."
L["Show banners for your own quest events"] = "Mostrar banners para tus propios eventos de misión"
L["Show a banner on screen for your own quest events."]                  = "Muestra un banner en pantalla para tus propios eventos de misión."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Activar transmisión"
L["Broadcast your quest events to party members via addon comm."]        = "Transmite tus eventos de misión a los miembros del grupo mediante la comunicación del addon."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Permite notificaciones de banner de los miembros del grupo (sujeto a los ajustes de Mostrar eventos a continuación)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Transmite tus eventos de misión a los miembros de la banda mediante la comunicación del addon."
L["Allow banner notifications from raid members."]                       = "Permite notificaciones de banner de los miembros de la banda."
L["Only show notifications from friends"]  = "Mostrar solo notificaciones de amigos"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Muestra solo notificaciones de banner de jugadores en tu lista de amigos, suprimiendo banners de desconocidos en bandas grandes."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Activar anuncios en el chat"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Anuncia tus eventos de misión en el chat de hermandad. Los miembros de la hermandad no necesitan tener SocialQuest instalado para ver estos mensajes."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "Transmite tus eventos de misión a los miembros del campo de batalla mediante la comunicación del addon."
L["Allow banner notifications from battleground members."]               = "Permite notificaciones de banner de los miembros del campo de batalla."
L["Only show banner notifications from friends in the battleground."]    = "Muestra solo notificaciones de banner de amigos en el campo de batalla."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "Activar susurros a amigos"
L["Send your quest events as whispers to online friends."]               = "Envía tus eventos de misión como susurros a tus amigos en línea."
L["Group members only"]                    = "Solo miembros del grupo"
L["Restrict whispers to friends currently in your group."]               = "Limita los susurros a amigos que estén actualmente en tu grupo."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "Activar notificaciones de seguimiento"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "Envía un susurro a los jugadores a los que empiezas o dejas de seguir, y recibe notificaciones cuando alguien te sigue."
L["Announce when you follow someone"]      = "Anunciar cuando sigues a alguien"
L["Whisper the player you begin following so they know you are following them."] = "Susurra al jugador al que empiezas a seguir para que sepa que lo estás siguiendo."
L["Announce when followed"]                = "Anunciar cuando te siguen"
L["Display a local message when someone starts or stops following you."] = "Muestra un mensaje local cuando alguien empieza o deja de seguirte."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "Activar modo de depuración"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "Muestra mensajes de depuración internos en el marco de chat. Útil para diagnosticar problemas de comunicación o de flujo de eventos."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "Probar banners y chat"
L["Test Accepted"]                         = "Probar Aceptada"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "Muestra un banner de demostración y una vista previa del chat local para el evento 'Misión aceptada'. Omite todos los filtros de visualización."
L["Test Abandoned"]                        = "Probar Abandonada"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "Muestra un banner de demostración y una vista previa del chat local para el evento 'Misión abandonada'."
L["Test Finished"]                         = "Probar Terminada"
L["Display a demo banner and local chat preview for the 'Quest finished objectives' event."] = "Muestra un banner de demostración y una vista previa del chat local para el evento 'Objetivos de misión terminados'."
L["Test Completed"]                        = "Probar Completada"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "Muestra un banner de demostración y una vista previa del chat local para el evento 'Misión entregada'."
L["Test Failed"]                           = "Probar Fallida"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "Muestra un banner de demostración y una vista previa del chat local para el evento 'Misión fallida'."
L["Test Obj. Progress"]                    = "Probar progreso de objetivo"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "Muestra un banner de demostración y una vista previa del chat local para una actualización de progreso parcial de objetivo (p. ej. 3/8)."
L["Test Obj. Complete"]                    = "Probar objetivo completado"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "Muestra un banner de demostración y una vista previa del chat local para la finalización de un objetivo (p. ej. 8/8)."
L["Test Obj. Regression"]                  = "Probar regresión de objetivo"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "Muestra un banner de demostración y una vista previa del chat local para una regresión de objetivo (el contador retrocedió)."
L["Test All Completed"]                    = "Probar todos completados"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Muestra un banner de demostración para la notificación morada 'Todos han completado'. Sin vista previa de chat (este evento nunca genera chat saliente directamente)."
