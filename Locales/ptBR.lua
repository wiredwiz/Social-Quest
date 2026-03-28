-- Locales/ptBR.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "ptBR")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "Missão aceita: %s"
L["Quest abandoned: %s"]                  = "Missão abandonada: %s"
L["Quest complete (objectives done): %s"] = "Missão completa (objetivos concluídos): %s"
L["Quest turned in: %s"]                  = "Missão entregue: %s"
L["Quest failed: %s"]                     = "Missão falhou: %s"
L["Quest event: %s"]                      = "Evento de missão: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (regressão)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s para %s!"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s aceita: %s"
L["%s abandoned: %s"]                     = "%s abandonada: %s"
L["%s completed: %s"]                     = "%s completou: %s"
L["%s turned in: %s"]                     = "%s entregou: %s"
L["%s failed: %s"]                        = "%s falhou: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s concluiu objetivo: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s regrediu: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s progrediu: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (prévia):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Todos completaram: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Você"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s começou a te seguir."
L["%s stopped following you."]            = "%s parou de te seguir."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "ERRO: AbsoluteQuestLog-1.0 não está instalado. SocialQuest está desativado."
L["Left-click to open group quest frame."]  = "Clique esquerdo para abrir o painel de missões do grupo."
L["Right-click to open settings."]          = "Clique direito para abrir as configurações."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — Missões em Grupo"
L["Quest URL (Ctrl+C to copy)"]            = "URL da missão (Ctrl+C para copiar)"

-- UI/RowFactory.lua
L["expand all"]                            = "expandir tudo"
L["collapse all"]                          = "recolher tudo"
L["Click here to copy the wowhead quest url"] = "Clique aqui para copiar o URL da missão no Wowhead"
L["(Complete)"]                            = "(Completa)"
L["(Group)"]                               = "(Grupo)"
L[" (Step %s of %s)"]                      = " (Passo %s de %s)"
L["(Step %s)"]                             = "(Passo %s)"
L["%s FINISHED"]                           = "%s CONCLUÍDA"
L["%s Needs it Shared"]                    = "%s precisa que seja compartilhada"
L["%s (no data)"]                          = "%s (sem dados)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Progresso do grupo"
L["(shared, no data)"]                     = "(compartilhada, sem dados)"
L["Objectives complete"]                   = "Objetivos concluídos"
L["(no data)"]                             = "(sem dados)"

-- UI tab labels
L["Mine"]                                  = "Minhas"
L["Other Quests"]                          = "Outras missões"
L["Party"]                                 = "Grupo"
L["(You)"]                                 = "(Você)"
L["Shared"]                                = "Compartilhadas"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "Aceita"
L["Abandoned"]                             = "Abandonada"
L["Complete"]                               = "Completo"
L["Turned In"]                             = "Entregue"
L["Failed"]                                = "Falhou"
L["Objective Progress"]                    = "Progresso de objetivo"
L["Objective Complete"]                    = "Objetivo concluído"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "Envia uma mensagem no chat quando você aceita uma missão."
L["Send a chat message when you abandon a quest."]                       = "Envia uma mensagem no chat quando você abandona uma missão."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "Envia uma mensagem no chat quando todos os objetivos da missão estão concluídos (antes de entregar)."
L["Send a chat message when you turn in a quest."]                       = "Envia uma mensagem no chat quando você entrega uma missão."
L["Send a chat message when a quest fails."]                             = "Envia uma mensagem no chat quando uma missão falha."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "Envia uma mensagem no chat quando um objetivo de missão progride ou regride. O formato corresponde ao estilo do Questie. Nunca suprimido pelo Questie — Questie não anuncia progresso parcial."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "Envia uma mensagem no chat quando um objetivo de missão atinge sua meta (ex.: 8/8 Kobolds). Suprimido automaticamente se o Questie estiver instalado e sua configuração 'Anunciar Objetivos' estiver ativada."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "Anunciar no Chat"
L["Own Quest Banners"]                     = "Banners das minhas missões"
L["Display Events"]                        = "Exibir eventos"
L["General"]                               = "Geral"
L["Raid"]                                  = "Raid"
L["Guild"]                                 = "Guilda"
L["Battleground"]                          = "Campo de batalha"
L["Whisper Friends"]                       = "Sussurrar para amigos"
L["Follow Notifications"]                  = "Notificações de seguimento"
L["Debug"]                                 = "Depuração"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "Exibe um banner quando você aceita uma missão."
L["Show a banner when you abandon a quest."]                                           = "Exibe um banner quando você abandona uma missão."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "Exibe um banner quando todos os objetivos de uma missão estão concluídos (antes de entregar)."
L["Show a banner when you turn in a quest."]                                           = "Exibe um banner quando você entrega uma missão."
L["Show a banner when a quest fails."]                                                 = "Exibe um banner quando uma missão falha."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "Exibe um banner quando um dos seus objetivos de missão progride ou regride."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "Exibe um banner quando um dos seus objetivos de missão atinge sua meta (ex.: 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "Exibe um banner quando um membro do grupo aceita uma missão."
L["Show a banner on screen when a group member abandons a quest."]                     = "Exibe um banner quando um membro do grupo abandona uma missão."
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "Exibe um banner quando um membro do grupo completa todos os objetivos de uma missão."
L["Show a banner on screen when a group member turns in a quest."]                     = "Exibe um banner quando um membro do grupo entrega uma missão."
L["Show a banner on screen when a group member fails a quest."]                        = "Exibe um banner quando um membro do grupo falha em uma missão."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Exibe um banner quando a contagem de objetivos de missão de um membro do grupo muda (inclui progresso parcial e regressão)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Exibe um banner quando um membro do grupo conclui um objetivo de missão (ex.: 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "Ativar SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "Interruptor principal para todas as funcionalidades do SocialQuest."
L["Show received events"]                  = "Exibir eventos recebidos"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Interruptor principal: permite que notificações de banner apareçam. Os grupos 'Exibir eventos' abaixo controlam quais tipos de eventos são mostrados por seção."
L["Colorblind Mode"]                       = "Modo daltônico"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Usa cores amigáveis para daltônicos em todos os banners e textos de interface do SocialQuest. Não é necessário ativar se o modo daltônico já estiver habilitado no cliente do jogo."
L["Show minimap button"]                    = "Mostrar botão do minimapa"
L["Show or hide the SocialQuest minimap button."]                        = "Exibe ou oculta o botão do minimapa do SocialQuest."
L["Show banners for your own quest events"] = "Exibir banners para seus próprios eventos de missão"
L["Show a banner on screen for your own quest events."]                  = "Exibe um banner na tela para seus próprios eventos de missão."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Ativar transmissão"
L["Broadcast your quest events to party members via addon comm."]        = "Transmite seus eventos de missão para membros do grupo via comunicação de addon."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Permite notificações de banner de membros do grupo (sujeito às opções de Exibir eventos abaixo)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Transmite seus eventos de missão para membros do raid via comunicação de addon."
L["Allow banner notifications from raid members."]                       = "Permite notificações de banner de membros do raid."
L["Only show notifications from friends"]  = "Mostrar apenas notificações de amigos"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Exibe apenas notificações de banner de jogadores na sua lista de amigos, suprimindo banners de desconhecidos em raids grandes."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Ativar anúncios no chat"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Anuncia seus eventos de missão no chat da guilda. Membros da guilda não precisam ter o SocialQuest instalado para ver essas mensagens."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "Transmite seus eventos de missão para membros do campo de batalha via comunicação de addon."
L["Allow banner notifications from battleground members."]               = "Permite notificações de banner de membros do campo de batalha."
L["Only show banner notifications from friends in the battleground."]    = "Exibe apenas notificações de banner de amigos no campo de batalha."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "Ativar sussurros para amigos"
L["Send your quest events as whispers to online friends."]               = "Envia seus eventos de missão como sussurros para amigos online."
L["Group members only"]                    = "Apenas membros do grupo"
L["Restrict whispers to friends currently in your group."]               = "Restringe sussurros a amigos que estejam atualmente no seu grupo."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "Ativar notificações de seguimento"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "Envia um sussurro para jogadores que você começa ou para de seguir, e recebe notificações quando alguém te segue."
L["Announce when you follow someone"]      = "Anunciar quando você segue alguém"
L["Whisper the player you begin following so they know you are following them."] = "Sussurra para o jogador que você começa a seguir para que saibam que você os está seguindo."
L["Announce when followed"]                = "Anunciar quando seguido"
L["Display a local message when someone starts or stops following you."] = "Exibe uma mensagem local quando alguém começa ou para de te seguir."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "Ativar modo de depuração"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "Imprime mensagens de depuração internas no frame de chat. Útil para diagnosticar problemas de comunicação ou de fluxo de eventos."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "Testar banners e chat"
L["Test Accepted"]                         = "Testar Aceita"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "Exibe um banner de demonstração e prévia do chat local para o evento 'Missão aceita'. Ignora todos os filtros de exibição."
L["Test Abandoned"]                        = "Testar Abandonada"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "Exibe um banner de demonstração e prévia do chat local para o evento 'Missão abandonada'."
L["Test Complete"]                          = "Testar Completa"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "Exibe um banner de demonstração e prévia do chat local para o evento 'Missão completa' (todos os objetivos concluídos, ainda não entregue)."
L["Test Turned In"]                        = "Testar Entregue"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "Exibe um banner de demonstração e prévia do chat local para o evento 'Missão entregue'."
L["Test Failed"]                           = "Testar Falhou"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "Exibe um banner de demonstração e prévia do chat local para o evento 'Missão falhou'."
L["Test Obj. Progress"]                    = "Testar progresso de objetivo"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "Exibe um banner de demonstração e prévia do chat local para uma atualização de progresso parcial de objetivo (ex.: 3/8)."
L["Test Obj. Complete"]                    = "Testar objetivo concluído"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "Exibe um banner de demonstração e prévia do chat local para a conclusão de um objetivo (ex.: 8/8)."
L["Test Obj. Regression"]                  = "Testar regressão de objetivo"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "Exibe um banner de demonstração e prévia do chat local para uma regressão de objetivo (contagem voltou atrás)."
L["Test All Completed"]                    = "Testar todos completados"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Exibe um banner de demonstração para a notificação roxa 'Todos completaram'. Sem pré-visualização de chat (este evento nunca gera chat de saída diretamente)."
L["Test Chat Link"]                        = "Testar link de chat"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "Imprime uma pré-visualização de chat local de uma mensagem 'Missão entregue' para a missão 337 usando um hyperlink real de WoW. Verifique se o nome da missão aparece como texto dourado clicável no frame de chat."
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "Clique para dispensar o filtro ativo desta aba."
L["Instance: %s"]                           = "Filtro: Instância: %s"
L["Zone: %s"]                               = "Filtro: Zona: %s"
L["Social Quest Window"]                    = "Janela do SocialQuest"
L["Auto-filter to current instance"]        = "Filtrar automaticamente pela instância atual"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "Dentro de uma masmorra ou raid, as abas 'Grupo' e 'Compartilhadas' mostram apenas missões da instância atual."
L["Auto-filter to current zone"]            = "Filtrar automaticamente pela zona atual"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "Fora de instâncias, as abas 'Grupo' e 'Compartilhadas' mostram apenas missões da sua zona atual."

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "Pesquisar..."
L["Clear search"]                            = "Limpar pesquisa"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "zona"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "Nome da zona (correspondência parcial)"
L["filter.key.title"]        = "título"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "Título da missão (correspondência parcial)"
L["filter.key.chain"]        = "série"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "Título da série (correspondência parcial)"
L["filter.key.player"]       = "jogador"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "Nome do membro (apenas abas Grupo/Compartilhado)"
L["filter.key.level"]        = "nível"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "Nível recomendado da missão"
L["filter.key.step"]         = "passo"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "Número do passo na série"
L["filter.key.group"]        = "grupo"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "Requisito de grupo (sim, não, 2-5)"
L["filter.key.type"]         = "tipo"
L["filter.key.type.desc"]    = "Tipo de missão — série, grupo, solo, cronometrado, escolta, masmorra, raide, elite, diária, pvp, matar, coletar, interagir"
L["filter.key.status"]       = "estado"
L["filter.key.status.desc"]  = "Estado da missão (completa, incompleta, falhou)"
L["filter.key.tracked"]      = "rastreado"
L["filter.key.tracked.desc"] = "Rastreado no minimapa (sim, não; apenas aba Meu)"
L["filter.val.yes"]          = "sim"
L["filter.val.no"]           = "não"
L["filter.val.complete"]     = "completa"
L["filter.val.incomplete"]   = "incompleta"
L["filter.val.failed"]       = "falhou"
L["filter.val.chain"]        = "série"
L["filter.val.group"]        = "grupo"
L["filter.val.solo"]         = "solo"
L["filter.val.timed"]        = "cronometrado"
L["filter.val.escort"]       = "escolta"
L["filter.val.dungeon"]      = "masmorra"
L["filter.val.raid"]         = "raide"
L["filter.val.elite"]        = "elite"
L["filter.val.daily"]        = "diária"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "matar"
L["filter.val.gather"]       = "coletar"
L["filter.val.interact"]     = "interagir"
L["filter.err.UNKNOWN_KEY"]      = "chave de filtro desconhecida '%s'"
L["filter.err.INVALID_OPERATOR"] = "o operador '%s' não pode ser usado com '%s'"
L["filter.err.TYPE_MISMATCH"]    = "'%s' requer um campo numérico"
L["filter.err.UNCLOSED_QUOTE"]   = "aspas não fechadas na expressão de filtro"
L["filter.err.EMPTY_VALUE"]      = "valor ausente após '%s'"
L["filter.err.INVALID_NUMBER"]   = "esperava um número para '%s', recebeu '%s'"
L["filter.err.RANGE_REVERSED"]   = "intervalo inválido: o mínimo (%s) deve ser <= máximo (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' não é um valor válido para '%s'"
L["filter.err.label"]            = "Erro de filtro: %s"
L["filter.help.title"]                = "Sintaxe de filtros SQ"
L["filter.help.intro"]                = "Digite uma expressão de filtro e pressione Enter para aplicá-la como etiqueta persistente. Feche uma etiqueta com [x]. Para combinar filtros, aplique-os um de cada vez — cada Enter adiciona uma nova etiqueta (lógica E)."
L["filter.help.section.syntax"]       = "Sintaxe"
L["filter.help.section.keys"]         = "Chaves suportadas"
L["filter.help.section.examples"]     = "Exemplos"
L["filter.help.col.key"]              = "Chave"
L["filter.help.col.aliases"]          = "Apelidos"
L["filter.help.col.desc"]             = "Descrição"
L["filter.help.example.1"]            = "nível>=60"
L["filter.help.example.1.note"]       = "Mostrar missões de nível 60 ou superior"
L["filter.help.example.2"]            = "nível=58..62"
L["filter.help.example.2.note"]       = "Mostrar missões no intervalo de nível 58-62"
L["filter.help.example.3"]            = "zona=Elwynn|Minas"
L["filter.help.example.3.note"]       = "Mostrar missões na Floresta de Elwynn OU nas Minas da Morte"
L["filter.help.example.4"]            = "estado=incompleta"
L["filter.help.example.4.note"]       = "Mostrar apenas missões incompletas"
L["filter.help.example.5"]            = "tipo=série"
L["filter.help.example.5.note"]       = "Mostrar apenas missões em série"
L["filter.help.example.6"]            = "zona=\"Península do Fogo Infernal\""
L["filter.help.example.6.note"]       = "Valor entre aspas (use quando o valor contiver espaços)"
L["filter.help.type.note"]            = "matar, coletar e interagir correspondem a missões com pelo menos um objetivo desse tipo — missões podem corresponder a vários tipos. Os filtros de tipo requerem o add-on Questie ou Quest Weaver."
L["filter.help.example.7"]            = "tipo=masmorra"
L["filter.help.example.7.note"]       = "Mostrar apenas missões de masmorra (requer Questie ou Quest Weaver)"
L["filter.help.example.8"]            = "tipo=matar"
L["filter.help.example.8.note"]       = "Mostrar missões com pelo menos um objetivo de matar"
L["filter.help.example.9"]            = "tipo=diária"
L["filter.help.example.9.note"]       = "Mostrar apenas missões diárias"
L["filter.help.example.10"]           = "rastreado=sim"
L["filter.help.example.10.note"]      = "Mostrar apenas missões rastreadas (somente aba Minhas)"
L["filter.help.example.11"]           = "grupo=não"
L["filter.help.example.11.note"]      = "Mostrar apenas missões solo (sem requisito de grupo)"

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Compartilhar"
L["share.tooltip"] = "Compartilhar esta missão com os membros do grupo"
L["share.reason.level_too_low"]    = "nível muito baixo"
L["share.reason.level_too_high"]   = "nível muito alto"
L["share.reason.wrong_race"]       = "raça incorreta"
L["share.reason.wrong_class"]      = "classe incorreta"
L["share.reason.quest_log_full"]   = "diário de missões cheio"
L["share.reason.exclusive_quest"]  = "missão exclusiva aceita"
L["share.reason.already_advanced"] = "já está mais avançado"
