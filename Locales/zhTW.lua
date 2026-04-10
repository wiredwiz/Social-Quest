-- Locales/zhTW.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "zhTW")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "已接受任務：%s"
L["Quest abandoned: %s"]                  = "已放棄任務：%s"
L["Quest complete (objectives done): %s"] = "任務完成（目標達成）：%s"
L["Quest turned in: %s"]                  = "已繳交任務：%s"
L["Quest failed: %s"]                     = "任務失敗：%s"
L["Quest event: %s"]                      = "任務事件：%s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " （退步）"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest：%d/%d %s%s，任務：%s！"
L["{rt1} SocialQuest: Quest Turned In: %s"] = "{rt1} SocialQuest: 任務已提交: %s"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s 已接受：%s"
L["%s abandoned: %s"]                     = "%s 已放棄：%s"
L["%s completed: %s"]                     = "%s 完成了: %s"
L["%s turned in: %s"]                     = "%s 交任務了: %s"
L["%s failed: %s"]                        = "%s 已失敗：%s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s 完成了目標：%s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s 退步了：%s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s 進度更新：%s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest（預覽）：|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "所有人都完成了: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "你"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s 開始跟隨你。"
L["%s stopped following you."]            = "%s 停止跟隨你。"

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "錯誤：未安裝 AbsoluteQuestLog-1.0。SocialQuest 已停用。"
L["Left-click to open group quest frame."]  = "左鍵點擊以開啟團隊任務面板。"
L["Right-click to open settings."]          = "右鍵點擊以開啟設定。"

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — 團隊任務"
L["Quest URL (Ctrl+C to copy)"]            = "任務連結（Ctrl+C 複製）"

-- UI/RowFactory.lua
L["expand all"]                            = "全部展開"
L["collapse all"]                          = "全部收合"
L["Click here to copy the wowhead quest url"] = "點擊此處複製 Wowhead 任務連結"
L["(Complete)"]                            = "（已完成）"
L["(Group)"]                               = "（團隊）"
L[" (Step %s of %s)"]                      = " （第 %s/%s 步）"
L["(Step %s)"]                             = "(步驟 %s)"
L["Finished"]                              = "已完成"
L["In Progress"]                           = "進行中"
L["(In Progress)"]                         = "（進行中）"
L["%s Needs it Shared"]                    = "%s 需要分享"
L["%s (no data)"]                          = "%s（無資料）"

-- UI/Tooltips.lua
L["Group Progress"]                        = "團隊進度"
L["Party progress"]                        = "團隊進度"
L["(shared, no data)"]                     = "（已分享，無資料）"
L["Objectives complete"]                   = "目標已完成"
L["(no data)"]                             = "（無資料）"

-- UI tab labels
L["Mine"]                                  = "我的"
L["Other Quests"]                          = "其他任務"
L["Party"]                                 = "小隊"
L["(You)"]                                 = "（你）"
L["Shared"]                                = "已分享"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "已接受"
L["Abandoned"]                             = "已放棄"
L["Complete"]                              = "完成"
L["Turned In"]                             = "已提交"
L["Failed"]                                = "已失敗"
L["Objective Progress"]                    = "目標進度"
L["Objective Complete"]                    = "目標完成"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "接受任務時發送聊天訊息。"
L["Send a chat message when you abandon a quest."]                       = "放棄任務時發送聊天訊息。"
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "所有任務目標完成時發送聊天訊息（繳交前）。"
L["Send a chat message when you turn in a quest."]                       = "繳交任務時發送聊天訊息。"
L["Send a chat message when a quest fails."]                             = "任務失敗時發送聊天訊息。"
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "任務目標進度更新或退步時發送聊天訊息。格式與 Questie 風格一致。不會被 Questie 屏蔽——Questie 不播報部分進度。"
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "任務目標達成時發送聊天訊息（如 8/8 科博爾德）。若 Questie 已安裝且啟用了「播報目標」設定，則自動屏蔽。"

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "在聊天中播報"
L["Own Quest Banners"]                     = "自身任務橫幅"
L["Display Events"]                        = "顯示事件"
L["General"]                               = "一般"
L["Raid"]                                  = "團隊副本"
L["Guild"]                                 = "公會"
L["Battleground"]                          = "戰場"
L["Whisper Friends"]                       = "悄悄話給好友"
L["Follow Notifications"]                  = "跟隨通知"
L["Debug"]                                 = "除錯"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "接受任務時顯示橫幅。"
L["Show a banner when you abandon a quest."]                                           = "放棄任務時顯示橫幅。"
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "所有任務目標完成時顯示橫幅（繳交前）。"
L["Show a banner when you turn in a quest."]                                           = "繳交任務時顯示橫幅。"
L["Show a banner when a quest fails."]                                                 = "任務失敗時顯示橫幅。"
L["Show a banner when one of your quest objectives progresses or regresses."]          = "任務目標進度更新或退步時顯示橫幅。"
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "任務目標達成時顯示橫幅（如 8/8）。"

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "隊員接受任務時在螢幕上顯示橫幅。"
L["Show a banner on screen when a group member abandons a quest."]                     = "隊員放棄任務時在螢幕上顯示橫幅。"
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "隊員完成任務所有目標時在螢幕上顯示橫幅。"
L["Show a banner on screen when a group member turns in a quest."]                     = "隊員繳交任務時在螢幕上顯示橫幅。"
L["Show a banner on screen when a group member fails a quest."]                        = "隊員任務失敗時在螢幕上顯示橫幅。"
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "隊員任務目標數量變化時在螢幕上顯示橫幅（包括部分進度和退步）。"
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "隊員完成任務目標時在螢幕上顯示橫幅（如 8/8）。"

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "啟用 SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "SocialQuest 所有功能的總開關。"
L["Show received events"]                  = "顯示接收到的事件"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "總開關：允許顯示橫幅通知。下方各「顯示事件」組分別控制每個區域顯示的事件類型。"
L["Colorblind Mode"]                       = "色盲模式"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "為所有 SocialQuest 橫幅和介面文字使用色盲友好顏色。若遊戲客戶端已啟用色盲模式，則無需開啟此項。"
L["Show minimap button"]                    = "顯示小地圖按鈕"
L["Show or hide the SocialQuest minimap button."]                        = "顯示或隱藏 SocialQuest 小地圖按鈕。"
L["Show banners for your own quest events"] = "為自身任務事件顯示橫幅"
L["Show a banner on screen for your own quest events."]                  = "為自身任務事件在螢幕上顯示橫幅。"

-- UI/Options.lua — party section
L["Enable transmission"]                   = "啟用廣播"
L["Broadcast your quest events to party members via addon comm."]        = "透過插件通訊將任務事件廣播給隊友。"
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "允許接收來自隊友的橫幅通知（受下方顯示事件開關控制）。"

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "透過插件通訊將任務事件廣播給團隊成員。"
L["Allow banner notifications from raid members."]                       = "允許接收來自團隊成員的橫幅通知。"
L["Only show notifications from friends"]  = "僅顯示好友的通知"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "僅顯示好友名單中玩家的橫幅通知，在大型團隊中屏蔽陌生人的橫幅。"

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "啟用聊天播報"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "在公會聊天中播報任務事件。公會成員無需安裝 SocialQuest 即可看到這些訊息。"

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "透過插件通訊將任務事件廣播給戰場成員。"
L["Allow banner notifications from battleground members."]               = "允許接收來自戰場成員的橫幅通知。"
L["Only show banner notifications from friends in the battleground."]    = "在戰場中僅顯示好友的橫幅通知。"

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "啟用向好友發送悄悄話"
L["Send your quest events as whispers to online friends."]               = "以悄悄話形式將任務事件發送給在線好友。"
L["Group members only"]                    = "僅限隊伍成員"
L["Restrict whispers to friends currently in your group."]               = "將悄悄話限制為目前在隊伍中的好友。"

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "啟用跟隨通知"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "向你開始或停止跟隨的玩家發送悄悄話，並在有人跟隨你時接收通知。"
L["Announce when you follow someone"]      = "跟隨他人時播報"
L["Whisper the player you begin following so they know you are following them."] = "向你開始跟隨的玩家發送悄悄話，讓他們知道你在跟隨他們。"
L["Announce when followed"]                = "被跟隨時播報"
L["Display a local message when someone starts or stops following you."] = "當有人開始或停止跟隨你時顯示本地訊息。"

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "啟用除錯模式"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "在聊天框中輸出內部除錯訊息。有助於診斷通訊問題或事件流問題。"

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "測試橫幅與聊天"
L["Test Accepted"]                         = "測試已接受"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "為「任務已接受」事件顯示示範橫幅和本地聊天預覽。繞過所有顯示過濾器。"
L["Test Abandoned"]                        = "測試已放棄"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "為「任務已放棄」事件顯示示範橫幅和本地聊天預覽。"
L["Test Complete"]                         = "測試已完成"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "為「任務完成」事件（所有目標已達成，尚未繳交）顯示示範橫幅和本地聊天預覽。"
L["Test Turned In"]                        = "測試已繳交"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "為「任務已繳交」事件顯示示範橫幅和本地聊天預覽。"
L["Test Failed"]                           = "測試已失敗"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "為「任務失敗」事件顯示示範橫幅和本地聊天預覽。"
L["Test Obj. Progress"]                    = "測試目標進度"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "為部分目標進度更新（如 3/8）顯示示範橫幅和本地聊天預覽。"
L["Test Obj. Complete"]                    = "測試目標完成"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "為目標達成（如 8/8）顯示示範橫幅和本地聊天預覽。"
L["Test Obj. Regression"]                  = "測試目標退步"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "為目標退步（計數後退）顯示示範橫幅和本地聊天預覽。"
L["Test All Completed"]                    = "測試全部完成目標"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "為「所有人都完成了」紫色通知顯示示範橫幅。無聊天預覽（此事件從不直接產生外發聊天）。"
L["Test Chat Link"]                        = "測試聊天連結"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "使用真實的WoW任務超連結為任務337的「任務已繳交」訊息列印本地聊天預覽。確認任務名稱在聊天框中顯示為可點擊的金色文字。"
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "點擊以關閉此分頁的當前篩選。"
L["Instance: %s"]                           = "篩選：副本：%s"
L["Zone: %s"]                               = "篩選：區域：%s"
L["Social Quest Window"]                    = "SocialQuest 視窗"
L["Auto-filter to current instance"]        = "自動過濾至當前副本"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "在地城或團隊副本中，「小隊」和「已分享」分頁只顯示當前副本的任務。"
L["Auto-filter to current zone"]            = "自動過濾至當前區域"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "在副本外，「小隊」和「已分享」分頁只顯示你目前所在區域的任務。"

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "搜尋..."
L["Clear search"]                            = "清除搜尋"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "區域"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "區域名稱（部分匹配）"
L["filter.key.title"]        = "標題"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "任務標題（部分匹配）"
L["filter.key.chain"]        = "任務鏈"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "任務鏈標題（部分匹配）"
L["filter.key.player"]       = "玩家"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "隊員名稱（僅隊伍/共享標籤）"
L["filter.key.level"]        = "等級"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "推薦任務等級"
L["filter.key.step"]         = "步驟"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "任務鏈步驟編號"
L["filter.key.group"]        = "組隊"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "組隊要求（是，否，2-5）"
L["filter.key.type"]         = "類型"
L["filter.key.type.desc"]    = "任務類型 — 任務鏈, 組隊, 單人, 限時, 護送, 地下城, 團隊副本, 精英, 日常, pvp, 擊殺, 採集, 互動"
L["filter.key.status"]       = "狀態"
L["filter.key.status.desc"]  = "任務狀態（完成, 未完成, 失敗）"
L["filter.key.tracked"]      = "追蹤"
L["filter.key.tracked.desc"] = "在小地圖上追蹤（是, 否；僅我的標籤）"
L["filter.key.shareable"] = true
L["filter.key.shareable.desc"] = true
L["filter.val.yes"]          = "是"
L["filter.val.no"]           = "否"
L["filter.val.complete"]     = "完成"
L["filter.val.incomplete"]   = "未完成"
L["filter.val.failed"]       = "失敗"
L["filter.val.chain"]        = "任務鏈"
L["filter.val.group"]        = "組隊"
L["filter.val.solo"]         = "單人"
L["filter.val.timed"]        = "限時"
L["filter.val.escort"]       = "護送"
L["filter.val.dungeon"]      = "地下城"
L["filter.val.raid"]         = "團隊副本"
L["filter.val.elite"]        = "精英"
L["filter.val.daily"]        = "日常"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "擊殺"
L["filter.val.gather"]       = "採集"
L["filter.val.interact"]     = "互動"
L["filter.err.UNKNOWN_KEY"]      = "未知的過濾鍵 '%s'"
L["filter.err.INVALID_OPERATOR"] = "運算符 '%s' 不能與 '%s' 一起使用"
L["filter.err.TYPE_MISMATCH"]    = "'%s' 需要數字字段"
L["filter.err.UNCLOSED_QUOTE"]   = "過濾表達式中存在未閉合的引號"
L["filter.err.EMPTY_VALUE"]      = "'%s' 後缺少值"
L["filter.err.INVALID_NUMBER"]   = "'%s' 需要數字，但收到 '%s'"
L["filter.err.RANGE_REVERSED"]   = "無效範圍：最小值 (%s) 必須 <= 最大值 (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' 不是 '%s' 的有效值"
L["filter.err.label"]            = "過濾錯誤：%s"
L["filter.err.MIXED_AND_OR"] = true
L["filter.err.AND_KEY_MISMATCH"] = true
L["filter.help.title"]                = "SQ 過濾語法"
L["filter.help.intro"]                = "輸入過濾表達式並按 Enter 將其應用為持久標籤。用 [x] 關閉標籤。若要組合多個條件，請逐一輸入並按 Enter——每次 Enter 都會添加新標籤（AND 邏輯）。"
L["filter.help.section.syntax"]       = "語法"
L["filter.help.section.keys"]         = "支援的鍵"
L["filter.help.section.examples"]     = "範例"
L["filter.help.col.key"]              = "鍵"
L["filter.help.col.aliases"]          = "別名"
L["filter.help.col.desc"]             = "描述"
L["filter.help.example.1"]            = "等級>=60"
L["filter.help.example.1.note"]       = "顯示60級或以上的任務"
L["filter.help.example.2"]            = "等級=58..62"
L["filter.help.example.2.note"]       = "顯示58-62級範圍內的任務"
L["filter.help.example.3"]            = "區域=艾爾文|死亡礦"
L["filter.help.example.3.note"]       = "顯示艾爾文森林或死亡礦井中的任務"
L["filter.help.example.4"]            = "狀態=未完成"
L["filter.help.example.4.note"]       = "僅顯示未完成的任務"
L["filter.help.example.5"]            = "類型=任務鏈"
L["filter.help.example.5.note"]       = "僅顯示任務鏈中的任務"
L["filter.help.example.6"]            = "區域=\"地獄火半島\""
L["filter.help.example.6.note"]       = "帶引號的值（當值包含空格時使用）"
L["filter.help.type.note"]            = "擊殺、採集和互動匹配至少包含一個相應目標的任務——任務可以匹配多種類型。類型過濾器需要安裝 Questie 或 Quest Weaver 插件。"
L["filter.help.example.7"]            = "類型=地下城"
L["filter.help.example.7.note"]       = "僅顯示地下城任務（需要 Questie 或 Quest Weaver）"
L["filter.help.example.8"]            = "類型=擊殺"
L["filter.help.example.8.note"]       = "顯示至少有一個擊殺目標的任務"
L["filter.help.example.9"]            = "類型=日常"
L["filter.help.example.9.note"]       = "僅顯示日常任務"
L["filter.help.example.10"]           = "追蹤=是"
L["filter.help.example.10.note"]      = "僅顯示已追蹤任務（僅限「我的」分頁）"
L["filter.help.example.11"]           = "組隊=否"
L["filter.help.example.11.note"]      = "僅顯示單人任務（無組隊需求）"
L["filter.help.example.12"] = true
L["filter.help.example.12.note"] = true
L["filter.help.example.13"] = true
L["filter.help.example.13.note"] = true
L["filter.help.example.14"] = true
L["filter.help.example.14.note"] = true
L["filter.help.example.15"] = true
L["filter.help.example.15.note"] = true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "分享"
L["share.tooltip"] = "與隊伍成員分享此任務"
L["share.reason.level_too_low"]    = "等級太低"
L["share.reason.level_too_high"]   = "等級太高"
L["share.reason.wrong_race"]       = "種族不符"
L["share.reason.wrong_class"]      = "職業不符"
L["share.reason.quest_log_full"]   = "任務日誌已滿"
L["share.reason.exclusive_quest"]  = "已接互斥任務"
L["share.reason.already_advanced"] = "已超過此步驟"

-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "提示資訊"
L["Enhance Questie/Blizzard tooltips"]               = "增強 Questie/暴雪任務提示"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "在現有任務提示框中加入小隊成員進度。"
L["Replace Blizzard quest tooltips"]                  = "取代暴雪任務提示"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "點擊任務連結時，顯示 SocialQuest 完整提示框而非原版任務提示框。"
L["Replace Questie quest tooltips"]                   = "取代 Questie 任務提示"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "點擊 Questie 連結時，顯示 SocialQuest 完整提示框而非 Questie 提示框。未安裝 Questie 時不可用。"
-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "你正在進行此任務"
L["You have completed this quest"]                    = "你已完成此任務"
L["You are eligible for this quest"]                  = "你可以接取此任務"
L["You are not eligible for this quest"]              = "你無法接取此任務"
-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "任務發布者："
L["Turn In:"]                                         = "交任務："
-- UI/Tooltips.lua — BuildTooltip title and location lines
L["Location:"]                                        = "地點："
L["(Dungeon)"]                                        = "(地城)"
L["(Raid)"]                                           = "(團隊)"
L["(Group %d+)"]                                      = "(組隊 %d+)"
