-- Locales/ruRU.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "ruRU")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "Задание принято: %s"
L["Quest abandoned: %s"]                  = "Задание брошено: %s"
L["Quest complete (objectives done): %s"] = "Задание выполнено (цели достигнуты): %s"
L["Quest turned in: %s"]                  = "Задание сдано: %s"
L["Quest failed: %s"]                     = "Задание провалено: %s"
L["Quest event: %s"]                      = "Событие задания: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (регресс)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s для %s!"
L["{rt1} SocialQuest: Quest Turned In: %s"] = "{rt1} SocialQuest: Задание сдано: %s"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s принято: %s"
L["%s abandoned: %s"]                     = "%s брошено: %s"
L["%s completed: %s"]                     = "%s выполнил: %s"
L["%s turned in: %s"]                     = "%s сдал задание: %s"
L["%s failed: %s"]                        = "%s провалено: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s выполнил цель: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s откатился: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s прогрессировал: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (предпросмотр):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "Все выполнили: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "Вы"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s начал следовать за вами."
L["%s stopped following you."]            = "%s прекратил следовать за вами."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "ОШИБКА: AbsoluteQuestLog-1.0 не установлен. SocialQuest отключён."
L["Left-click to open group quest frame."]  = "Нажмите левую кнопку мыши, чтобы открыть панель групповых заданий."
L["Right-click to open settings."]          = "Нажмите правую кнопку мыши, чтобы открыть настройки."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — Групповые задания"
L["Quest URL (Ctrl+C to copy)"]            = "URL задания (Ctrl+C для копирования)"

-- UI/RowFactory.lua
L["expand all"]                            = "развернуть всё"
L["collapse all"]                          = "свернуть всё"
L["Click here to copy the wowhead quest url"] = "Нажмите здесь, чтобы скопировать URL задания на Wowhead"
L["(Complete)"]                            = "(Выполнено)"
L["(Group)"]                               = "(Группа)"
L[" (Step %s of %s)"]                      = " (Шаг %s из %s)"
L["(Step %s)"]                             = "(Шаг %s)"
L["%s FINISHED"]                           = "%s ЗАВЕРШЕНО"
L["%s Needs it Shared"]                    = "%s нужно поделиться"
L["%s (no data)"]                          = "%s (нет данных)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "Прогресс группы"
L["(shared, no data)"]                     = "(поделились, нет данных)"
L["Objectives complete"]                   = "Цели выполнены"
L["(no data)"]                             = "(нет данных)"

-- UI tab labels
L["Mine"]                                  = "Мои"
L["Other Quests"]                          = "Другие задания"
L["Party"]                                 = "Группа"
L["(You)"]                                 = "(Вы)"
L["Shared"]                                = "Общие"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "Принято"
L["Abandoned"]                             = "Брошено"
L["Complete"]                              = "Выполнено"
L["Turned In"]                             = "Сдано"
L["Failed"]                                = "Провалено"
L["Objective Progress"]                    = "Прогресс цели"
L["Objective Complete"]                    = "Цель выполнена"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "Отправляет сообщение в чат при принятии задания."
L["Send a chat message when you abandon a quest."]                       = "Отправляет сообщение в чат при отказе от задания."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "Отправляет сообщение в чат, когда все цели задания выполнены (до сдачи)."
L["Send a chat message when you turn in a quest."]                       = "Отправляет сообщение в чат при сдаче задания."
L["Send a chat message when a quest fails."]                             = "Отправляет сообщение в чат при провале задания."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "Отправляет сообщение в чат при прогрессе или регрессе цели задания. Формат совпадает со стилем Questie. Никогда не подавляется Questie — Questie не объявляет о частичном прогрессе."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "Отправляет сообщение в чат, когда цель задания достигнута (например, 8/8 кобольдов). Автоматически подавляется, если установлен Questie и включена его настройка 'Объявлять о целях'."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "Объявить в чате"
L["Own Quest Banners"]                     = "Баннеры моих заданий"
L["Display Events"]                        = "Показывать события"
L["General"]                               = "Общие"
L["Raid"]                                  = "Рейд"
L["Guild"]                                 = "Гильдия"
L["Battleground"]                          = "Поле боя"
L["Whisper Friends"]                       = "Шептать друзьям"
L["Follow Notifications"]                  = "Уведомления о слежке"
L["Debug"]                                 = "Отладка"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "Показывает баннер при принятии задания."
L["Show a banner when you abandon a quest."]                                           = "Показывает баннер при отказе от задания."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "Показывает баннер, когда все цели задания выполнены (до сдачи)."
L["Show a banner when you turn in a quest."]                                           = "Показывает баннер при сдаче задания."
L["Show a banner when a quest fails."]                                                 = "Показывает баннер при провале задания."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "Показывает баннер при прогрессе или регрессе одной из целей задания."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "Показывает баннер, когда одна из целей задания достигнута (например, 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "Показывает баннер на экране, когда участник группы принимает задание."
L["Show a banner on screen when a group member abandons a quest."]                     = "Показывает баннер на экране, когда участник группы отказывается от задания."
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "Показывает баннер на экране, когда участник группы выполняет все цели задания."
L["Show a banner on screen when a group member turns in a quest."]                     = "Показывает баннер на экране, когда участник группы сдаёт задание."
L["Show a banner on screen when a group member fails a quest."]                        = "Показывает баннер на экране, когда участник группы проваливает задание."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "Показывает баннер на экране при изменении счётчика целей задания участника группы (включая частичный прогресс и регресс)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "Показывает баннер на экране, когда участник группы выполняет цель задания (например, 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "Включить SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "Главный переключатель вкл/выкл для всего функционала SocialQuest."
L["Show received events"]                  = "Показывать полученные события"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "Главный переключатель: разрешить отображение баннерных уведомлений. Группы 'Показывать события' ниже управляют типами событий, отображаемых в каждом разделе."
L["Colorblind Mode"]                       = "Режим для дальтоников"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "Использует цвета, удобные для дальтоников, для всех баннеров и текстов интерфейса SocialQuest. Не нужно включать, если режим для дальтоников уже активирован в игровом клиенте."
L["Show minimap button"]                    = "Показать кнопку миникарты"
L["Show or hide the SocialQuest minimap button."]                        = "Показывает или скрывает кнопку миникарты SocialQuest."
L["Show banners for your own quest events"] = "Показывать баннеры для своих событий заданий"
L["Show a banner on screen for your own quest events."]                  = "Показывает баннер на экране для своих событий заданий."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "Включить передачу"
L["Broadcast your quest events to party members via addon comm."]        = "Транслирует события ваших заданий участникам группы через аддон-коммуникацию."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "Разрешает баннерные уведомления от участников группы (в соответствии с настройками 'Показывать события' ниже)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "Транслирует события ваших заданий участникам рейда через аддон-коммуникацию."
L["Allow banner notifications from raid members."]                       = "Разрешает баннерные уведомления от участников рейда."
L["Only show notifications from friends"]  = "Показывать уведомления только от друзей"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "Показывает баннерные уведомления только от игроков из списка друзей, подавляя баннеры незнакомцев в больших рейдах."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "Включить объявления в чате"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "Объявляет события ваших заданий в чате гильдии. Участникам гильдии не нужно устанавливать SocialQuest, чтобы видеть эти сообщения."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "Транслирует события ваших заданий участникам поля боя через аддон-коммуникацию."
L["Allow banner notifications from battleground members."]               = "Разрешает баннерные уведомления от участников поля боя."
L["Only show banner notifications from friends in the battleground."]    = "Показывает баннерные уведомления только от друзей на поле боя."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "Включить шёпот друзьям"
L["Send your quest events as whispers to online friends."]               = "Отправляет события ваших заданий в виде шёпота онлайн-друзьям."
L["Group members only"]                    = "Только участники группы"
L["Restrict whispers to friends currently in your group."]               = "Ограничивает шёпот друзьями, находящимися в вашей группе."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "Включить уведомления о слежке"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "Отправляет шёпот игрокам, за которыми вы начинаете или прекращаете следить, и получает уведомления, когда кто-то следит за вами."
L["Announce when you follow someone"]      = "Объявить, когда вы следите за кем-то"
L["Whisper the player you begin following so they know you are following them."] = "Шепчет игроку, за которым вы начинаете следить, чтобы тот знал, что за ним следят."
L["Announce when followed"]                = "Объявить, когда за вами следят"
L["Display a local message when someone starts or stops following you."] = "Показывает локальное сообщение, когда кто-то начинает или прекращает следить за вами."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "Включить режим отладки"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "Выводит внутренние отладочные сообщения в окно чата. Полезно для диагностики проблем связи или потока событий."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "Тест баннеров и чата"
L["Test Accepted"]                         = "Тест принятия"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для события 'Задание принято'. Обходит все фильтры отображения."
L["Test Abandoned"]                        = "Тест отказа"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для события 'Задание брошено'."
L["Test Complete"]                         = "Тест выполнения"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для события 'Задание выполнено' (все цели достигнуты, ещё не сдано)."
L["Test Turned In"]                        = "Тест сдачи"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для события 'Задание сдано'."
L["Test Failed"]                           = "Тест провала"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "Показывает демонстрационный баннер и локальный предпросмотр чата для события 'Задание провалено'."
L["Test Obj. Progress"]                    = "Тест прогресса цели"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для частичного обновления прогресса цели (например, 3/8)."
L["Test Obj. Complete"]                    = "Тест выполнения цели"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для выполнения цели (например, 8/8)."
L["Test Obj. Regression"]                  = "Тест регресса цели"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "Показывает демонстрационный баннер и локальный предпросмотр чата для регресса цели (счётчик пошёл назад)."
L["Test All Completed"]                    = "Тест все выполнили"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "Отображает демонстрационный баннер для фиолетового уведомления 'Все выполнили'. Без предварительного просмотра чата (это событие никогда не генерирует исходящий чат напрямую)."
L["Test Chat Link"]                        = "Тест ссылки чата"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "Выводит локальный предварительный просмотр чата сообщения 'Задание сдано' для задания 337 с использованием реальной гиперссылки WoW. Убедитесь, что имя задания отображается как кликабельный золотой текст в окне чата."
L["Test Flight Discovery"]                 = "Тест открытия маршрута полёта"
L["Display a demo flight path unlock banner using your character's starting city as the demo location."] = "Отображает демонстрационный баннер разблокировки маршрута полёта, используя стартовый город вашего персонажа в качестве демо-места."

-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."
