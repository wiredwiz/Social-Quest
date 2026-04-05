-- Locales/esMX.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "esMX")
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
L["%s completed: %s"]                     = "%s ha completado: %s"
L["%s turned in: %s"]                     = "%s ha entregado: %s"
L["%s failed: %s"]                        = "%s fallida: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s completó el objetivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s retrocedió: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s progresó: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (vista previa):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Todos han completado: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Tú"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s empezó a seguirte."
L["%s stopped following you."]            = "%s dejó de seguirte."

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
L["(Step %s)"]                             = "(Paso %s)"
L["Finished"]                              = "Terminada"
L["In Progress"]                           = "En progreso"
L["(In Progress)"]                         = "(En progreso)"
L["%s Needs it Shared"]                    = "%s necesita que se comparta"
L["%s (no data)"]                          = "%s (sin datos)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Progreso del grupo"
L["Party progress"]                        = "Progreso del grupo"
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
L["Complete"]                               = "Completado"
L["Turned In"]                             = "Entregado"
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
L["Guild"]                                 = "Gremio"
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
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "Muestra un banner cuando un miembro del grupo completa todos los objetivos de una misión."
L["Show a banner on screen when a group member turns in a quest."]                     = "Muestra un banner cuando un miembro del grupo entrega una misión."
L["Show a banner on screen when a group member fails a quest."]                        = "Muestra un banner cuando un miembro del grupo falla una misión."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Muestra un banner cuando el conteo de objetivos de misión de un miembro del grupo cambia (incluye progreso parcial y regresión)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Muestra un banner cuando un miembro del grupo completa un objetivo de misión (p. ej. 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "Activar SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "Interruptor principal para todas las funciones de SocialQuest."
L["Show received events"]                  = "Mostrar eventos recibidos"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Interruptor principal: permite que aparezcan notificaciones de banner. Los grupos 'Mostrar eventos' abajo controlan qué tipos de eventos se muestran por sección."
L["Colorblind Mode"]                       = "Modo daltónico"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Usa colores aptos para daltónicos en todos los banners y textos de interfaz de SocialQuest. No es necesario activarlo si el modo daltónico ya está habilitado en el cliente de juego."
L["Show minimap button"]                    = "Mostrar botón del minimapa"
L["Show or hide the SocialQuest minimap button."]                        = "Muestra u oculta el botón del minimapa de SocialQuest."
L["Show banners for your own quest events"] = "Mostrar banners para tus propios eventos de misión"
L["Show a banner on screen for your own quest events."]                  = "Muestra un banner en pantalla para tus propios eventos de misión."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Activar transmisión"
L["Broadcast your quest events to party members via addon comm."]        = "Transmite tus eventos de misión a los miembros del grupo mediante la comunicación del addon."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Permite notificaciones de banner de los miembros del grupo (sujeto a los ajustes de Mostrar eventos abajo)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Transmite tus eventos de misión a los miembros de la banda mediante la comunicación del addon."
L["Allow banner notifications from raid members."]                       = "Permite notificaciones de banner de los miembros de la banda."
L["Only show notifications from friends"]  = "Mostrar solo notificaciones de amigos"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Muestra solo notificaciones de banner de jugadores en tu lista de amigos, suprimiendo banners de desconocidos en bandas grandes."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Activar anuncios en el chat"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Anuncia tus eventos de misión en el chat de gremio. Los miembros del gremio no necesitan tener SocialQuest instalado para ver estos mensajes."

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
L["Test Complete"]                          = "Probar Completada"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "Muestra un banner de demostración y una vista previa del chat local para el evento 'Misión completa' (todos los objetivos cumplidos, aún no entregada)."
L["Test Turned In"]                        = "Probar Entregada"
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
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Muestra un banner de demostración para la notificación púrpura 'Todos han completado'. Sin vista previa de chat (este evento nunca genera chat saliente directamente)."
L["Test Chat Link"]                        = "Probar enlace de chat"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "Muestra una vista previa de chat local del mensaje 'Misión entregada' para la misión 337 usando un hipervínculo real de WoW. Verifica que el nombre de la misión aparece como texto dorado cliqueable en el marco de chat."
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "Haz clic para descartar el filtro activo de esta pestaña."
L["Instance: %s"]                           = "Filtro: Instancia: %s"
L["Zone: %s"]                               = "Filtro: Zona: %s"
L["Social Quest Window"]                    = "Ventana de SocialQuest"
L["Auto-filter to current instance"]        = "Filtrar automáticamente por instancia actual"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "Dentro de una mazmorra o banda, las pestañas 'Grupo' y 'Compartidas' muestran solo las misiones de la instancia actual."
L["Auto-filter to current zone"]            = "Filtrar automáticamente por zona actual"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "Fuera de instancias, las pestañas 'Grupo' y 'Compartidas' muestran solo las misiones de tu zona actual."

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "Buscar..."
L["Clear search"]                            = "Borrar búsqueda"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "zona"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "Nombre de zona (coincidencia parcial)"
L["filter.key.title"]        = "título"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "Título de misión (coincidencia parcial)"
L["filter.key.chain"]        = "serie"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "Título de serie (coincidencia parcial)"
L["filter.key.player"]       = "jugador"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "Nombre del miembro (solo pestañas Grupo/Compartido)"
L["filter.key.level"]        = "nivel"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "Nivel recomendado de la misión"
L["filter.key.step"]         = "paso"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "Número de paso en la serie"
L["filter.key.group"]        = "grupo"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "Requisito de grupo (sí, no, 2-5)"
L["filter.key.type"]         = "tipo"
L["filter.key.type.desc"]    = "Tipo de misión — serie, grupo, solitario, cronometrado, escolta, mazmorra, banda, élite, diaria, pvp, matar, recolectar, interactuar"
L["filter.key.status"]       = "estado"
L["filter.key.status.desc"]  = "Estado de la misión (completa, incompleta, fallida)"
L["filter.key.tracked"]      = "seguido"
L["filter.key.tracked.desc"] = "Seguido en el minimapa (sí, no; solo pestaña Yo)"
L["filter.key.shareable"]    = "compartible"
L["filter.key.shareable.desc"] = true
L["filter.val.yes"]          = "sí"
L["filter.val.no"]           = "no"
L["filter.val.complete"]     = "completa"
L["filter.val.incomplete"]   = "incompleta"
L["filter.val.failed"]       = "fallida"
L["filter.val.chain"]        = "serie"
L["filter.val.group"]        = "grupo"
L["filter.val.solo"]         = "solitario"
L["filter.val.timed"]        = "cronometrado"
L["filter.val.escort"]       = "escolta"
L["filter.val.dungeon"]      = "mazmorra"
L["filter.val.raid"]         = "banda"
L["filter.val.elite"]        = "élite"
L["filter.val.daily"]        = "diaria"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "matar"
L["filter.val.gather"]       = "recolectar"
L["filter.val.interact"]     = "interactuar"
L["filter.err.UNKNOWN_KEY"]      = "clave de filtro desconocida '%s'"
L["filter.err.INVALID_OPERATOR"] = "el operador '%s' no se puede usar con '%s'"
L["filter.err.TYPE_MISMATCH"]    = "'%s' requiere un campo numérico"
L["filter.err.UNCLOSED_QUOTE"]   = "comilla sin cerrar en la expresión de filtro"
L["filter.err.EMPTY_VALUE"]      = "falta el valor después de '%s'"
L["filter.err.INVALID_NUMBER"]   = "se esperaba un número para '%s', se recibió '%s'"
L["filter.err.RANGE_REVERSED"]   = "rango no válido: el mínimo (%s) debe ser <= máximo (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' no es un valor válido para '%s'"
L["filter.err.label"]            = "Error de filtro: %s"
L["filter.err.MIXED_AND_OR"] = true
L["filter.err.AND_KEY_MISMATCH"] = true
L["filter.help.title"]                = "Sintaxis de filtros SQ"
L["filter.help.intro"]                = "Escribe una expresión de filtro y pulsa Enter para aplicarla como etiqueta persistente. Cierra una etiqueta con [x]. Para combinar filtros, aplícalos de uno en uno — cada Enter añade una nueva etiqueta (lógica Y)."
L["filter.help.section.syntax"]       = "Sintaxis"
L["filter.help.section.keys"]         = "Claves admitidas"
L["filter.help.section.examples"]     = "Ejemplos"
L["filter.help.col.key"]              = "Clave"
L["filter.help.col.aliases"]          = "Alias"
L["filter.help.col.desc"]             = "Descripción"
L["filter.help.example.1"]            = "nivel>=60"
L["filter.help.example.1.note"]       = "Mostrar misiones de nivel 60 o más"
L["filter.help.example.2"]            = "nivel=58..62"
L["filter.help.example.2.note"]       = "Mostrar misiones en el rango de nivel 58-62"
L["filter.help.example.3"]            = "zona=Elwynn|Minas"
L["filter.help.example.3.note"]       = "Mostrar misiones en el Bosque de Elwynn O en las Minas de la Muerte"
L["filter.help.example.4"]            = "estado=incompleta"
L["filter.help.example.4.note"]       = "Mostrar solo misiones incompletas"
L["filter.help.example.5"]            = "tipo=serie"
L["filter.help.example.5.note"]       = "Mostrar solo misiones en serie"
L["filter.help.example.6"]            = "zona=\"Península del Fuego Infernal\""
L["filter.help.example.6.note"]       = "Valor entre comillas (úsalas cuando el valor contenga espacios)"
L["filter.help.type.note"]            = "matar, recolectar e interactuar coinciden con misiones que tienen al menos un objetivo de ese tipo — las misiones pueden coincidir con varios tipos. Los filtros de tipo requieren el complemento Questie o Quest Weaver."
L["filter.help.example.7"]            = "tipo=mazmorra"
L["filter.help.example.7.note"]       = "Mostrar solo misiones de mazmorra (requiere Questie o Quest Weaver)"
L["filter.help.example.8"]            = "tipo=matar"
L["filter.help.example.8.note"]       = "Mostrar misiones con al menos un objetivo de matar"
L["filter.help.example.9"]            = "tipo=diaria"
L["filter.help.example.9.note"]       = "Mostrar solo misiones diarias"
L["filter.help.example.10"]           = "seguido=sí"
L["filter.help.example.10.note"]      = "Mostrar solo misiones rastreadas (solo pestaña Mías)"
L["filter.help.example.11"]           = "grupo=no"
L["filter.help.example.11.note"]      = "Mostrar solo misiones en solitario (sin requisito de grupo)"
L["filter.help.example.12"] = true
L["filter.help.example.12.note"] = true
L["filter.help.example.13"] = true
L["filter.help.example.13.note"] = true
L["filter.help.example.14"] = true
L["filter.help.example.14.note"] = true
L["filter.help.example.15"] = true
L["filter.help.example.15.note"] = true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Compartir"
L["share.tooltip"] = "Compartir esta misión con los miembros del grupo"
L["share.reason.level_too_low"]    = "nivel demasiado bajo"
L["share.reason.level_too_high"]   = "nivel demasiado alto"
L["share.reason.wrong_race"]       = "raza incorrecta"
L["share.reason.wrong_class"]      = "clase incorrecta"
L["share.reason.quest_log_full"]   = "diario de misiones lleno"
L["share.reason.exclusive_quest"]  = "misión exclusiva aceptada"
L["share.reason.already_advanced"] = "ya está más avanzado"
