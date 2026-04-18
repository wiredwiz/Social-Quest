-- Locales/zhCN.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "zhCN")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "已接受任务：%s"
L["Quest abandoned: %s"]                  = "已放弃任务：%s"
L["Quest complete (objectives done): %s"] = "任务完成（目标达成）：%s"
L["Quest turned in: %s"]                  = "已提交任务：%s"
L["Quest failed: %s"]                     = "任务失败：%s"
L["Quest event: %s"]                      = "任务事件：%s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " （退步）"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest：%d/%d %s%s，任务：%s！"
L["{rt1} SocialQuest: Quest Turned In: %s"] = "{rt1} SocialQuest: 任务已提交: %s"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s 已接受：%s"
L["%s abandoned: %s"]                     = "%s 已放弃：%s"
L["%s completed: %s"]                     = "%s 完成了: %s"
L["%s turned in: %s"]                     = "%s 交任务了: %s"
L["%s failed: %s"]                        = "%s 已失败：%s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s 完成了目标：%s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s 退步了：%s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s 进度更新：%s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest（预览）：|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "所有人都完成了: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "你"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s 开始跟随你。"
L["%s stopped following you."]            = "%s 停止跟随你。"

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "错误：未安装 AbsoluteQuestLog-1.0。SocialQuest 已禁用。"
L["Left-click to open group quest frame."]  = "左键单击以打开团队任务面板。"
L["Right-click to open settings."]          = "右键单击以打开设置。"

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — 团队任务"
L["Quest URL (Ctrl+C to copy)"]            = "任务链接（Ctrl+C 复制）"

-- UI/RowFactory.lua
L["expand all"]                            = "展开全部"
L["collapse all"]                          = "收起全部"
L["Click here to copy the wowhead quest url"] = "点击此处复制 Wowhead 任务链接"
L["(Complete)"]                            = "（已完成）"
L["(Group)"]                               = "（团队）"
L[" (Step %s of %s)"]                      = " （第 %s/%s 步）"
L["(Step %s)"]                             = "(步骤 %s)"
L["Finished"]                              = "已完成"
L["In Progress"]                           = "进行中"
L["(In Progress)"]                         = "（进行中）"
L["%s Needs it Shared"]                    = "%s 需要分享"
L["%s (no data)"]                          = "%s（无数据）"

-- UI/Tooltips.lua
L["Group Progress"]                        = "团队进度"
L["Party progress"]                        = "团队进度"
L["(shared, no data)"]                     = "（已分享，无数据）"
L["Objectives complete"]                   = "目标已完成"
L["(no data)"]                             = "（无数据）"

-- UI tab labels
L["Mine"]                                  = "我的"
L["Other Quests"]                          = "其他任务"
L["Party"]                                 = "小队"
L["(You)"]                                 = "（你）"
L["Shared"]                                = "已分享"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "已接受"
L["Abandoned"]                             = "已放弃"
L["Complete"]                              = "完成"
L["Turned In"]                             = "已提交"
L["Failed"]                                = "已失败"
L["Objective Progress"]                    = "目标进度"
L["Objective Complete"]                    = "目标完成"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "接受任务时发送聊天消息。"
L["Send a chat message when you abandon a quest."]                       = "放弃任务时发送聊天消息。"
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "所有任务目标完成时发送聊天消息（提交前）。"
L["Send a chat message when you turn in a quest."]                       = "提交任务时发送聊天消息。"
L["Send a chat message when a quest fails."]                             = "任务失败时发送聊天消息。"
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "任务目标进度更新或退步时发送聊天消息。格式与 Questie 风格一致。不会被 Questie 屏蔽——Questie 不播报部分进度。"
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "任务目标达成时发送聊天消息（如 8/8 科博尔德）。若 Questie 已安装且启用了「播报目标」设置，则自动屏蔽。"

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "在聊天中播报"
L["Own Quest Banners"]                     = "自身任务横幅"
L["Display Events"]                        = "显示事件"
L["General"]                               = "常规"
L["Raid"]                                  = "团队副本"
L["Guild"]                                 = "公会"
L["Battleground"]                          = "战场"
L["Whisper Friends"]                       = "悄悄话给好友"
L["Follow Notifications"]                  = "跟随通知"
L["Debug"]                                 = "调试"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "接受任务时显示横幅。"
L["Show a banner when you abandon a quest."]                                           = "放弃任务时显示横幅。"
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "所有任务目标完成时显示横幅（提交前）。"
L["Show a banner when you turn in a quest."]                                           = "提交任务时显示横幅。"
L["Show a banner when a quest fails."]                                                 = "任务失败时显示横幅。"
L["Show a banner when one of your quest objectives progresses or regresses."]          = "任务目标进度更新或退步时显示横幅。"
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "任务目标达成时显示横幅（如 8/8）。"

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "队员接受任务时在屏幕上显示横幅。"
L["Show a banner on screen when a group member abandons a quest."]                     = "队员放弃任务时在屏幕上显示横幅。"
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "队员完成任务所有目标时在屏幕上显示横幅。"
L["Show a banner on screen when a group member turns in a quest."]                     = "队员提交任务时在屏幕上显示横幅。"
L["Show a banner on screen when a group member fails a quest."]                        = "队员任务失败时在屏幕上显示横幅。"
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "队员任务目标数量变化时在屏幕上显示横幅（包括部分进度和退步）。"
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "队员完成任务目标时在屏幕上显示横幅（如 8/8）。"

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "启用 SocialQuest"
L["Master on/off switch for all SocialQuest functionality."]             = "SocialQuest 所有功能的总开关。"
L["Show received events"]                  = "显示接收到的事件"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "总开关：允许显示横幅通知。下方各\"显示事件\"组分别控制每个区域显示的事件类型。"
L["Colorblind Mode"]                       = "色盲模式"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "为所有 SocialQuest 横幅和界面文本使用色盲友好颜色。若游戏客户端已启用色盲模式，则无需开启此项。"
L["Show minimap button"]                    = "显示小地图按钮"
L["Show or hide the SocialQuest minimap button."]                        = "显示或隐藏 SocialQuest 小地图按钮。"
L["Show banners for your own quest events"] = "为自身任务事件显示横幅"
L["Show a banner on screen for your own quest events."]                  = "为自身任务事件在屏幕上显示横幅。"

-- UI/Options.lua — party section
L["Enable transmission"]                   = "启用广播"
L["Broadcast your quest events to party members via addon comm."]        = "通过插件通讯将任务事件广播给队友。"
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "允许接收来自队友的横幅通知（受下方显示事件开关控制）。"

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "通过插件通讯将任务事件广播给团队成员。"
L["Allow banner notifications from raid members."]                       = "允许接收来自团队成员的横幅通知。"
L["Only show notifications from friends"]  = "仅显示好友的通知"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "仅显示好友列表中玩家的横幅通知，在大型团队中屏蔽陌生人的横幅。"

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "启用聊天播报"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "在公会聊天中播报任务事件。公会成员无需安装 SocialQuest 即可看到这些消息。"

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "通过插件通讯将任务事件广播给战场成员。"
L["Allow banner notifications from battleground members."]               = "允许接收来自战场成员的横幅通知。"
L["Only show banner notifications from friends in the battleground."]    = "在战场中仅显示好友的横幅通知。"

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "启用向好友发送悄悄话"
L["Send your quest events as whispers to online friends."]               = "以悄悄话形式将任务事件发送给在线好友。"
L["Group members only"]                    = "仅限队伍成员"
L["Restrict whispers to friends currently in your group."]               = "将悄悄话限制为当前在队伍中的好友。"

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "启用跟随通知"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "向你开始或停止跟随的玩家发送悄悄话，并在有人跟随你时接收通知。"
L["Announce when you follow someone"]      = "跟随他人时播报"
L["Whisper the player you begin following so they know you are following them."] = "向你开始跟随的玩家发送悄悄话，让他们知道你在跟随他们。"
L["Announce when followed"]                = "被跟随时播报"
L["Display a local message when someone starts or stops following you."] = "当有人开始或停止跟随你时显示本地消息。"

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "启用调试模式"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "在聊天框中输出内部调试消息。有助于诊断通讯问题或事件流问题。"

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "测试横幅与聊天"
L["Test Accepted"]                         = "测试已接受"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "为\"任务已接受\"事件显示演示横幅和本地聊天预览。绕过所有显示过滤器。"
L["Test Abandoned"]                        = "测试已放弃"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "为\"任务已放弃\"事件显示演示横幅和本地聊天预览。"
L["Test Complete"]                         = "测试已完成"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "为「任务完成」事件（所有目标已达成，尚未提交）显示演示横幅和本地聊天预览。"
L["Test Turned In"]                        = "测试已提交"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "为\"任务已提交\"事件显示演示横幅和本地聊天预览。"
L["Test Failed"]                           = "测试已失败"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "为\"任务失败\"事件显示演示横幅和本地聊天预览。"
L["Test Obj. Progress"]                    = "测试目标进度"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "为部分目标进度更新（如 3/8）显示演示横幅和本地聊天预览。"
L["Test Obj. Complete"]                    = "测试目标完成"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "为目标达成（如 8/8）显示演示横幅和本地聊天预览。"
L["Test Obj. Regression"]                  = "测试目标退步"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "为目标退步（计数后退）显示演示横幅和本地聊天预览。"
L["Test All Completed"]                    = "测试全部完成目标"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "为「所有人都完成了」紫色通知显示演示横幅。无聊天预览（此事件从不直接产生外发聊天）。"
L["Test Chat Link"]                        = "测试聊天链接"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "使用真实的WoW任务超链接为任务337的「任务已提交」消息打印本地聊天预览。确认任务名称在聊天框中显示为可点击的金色文本。"
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "点击以关闭此标签的当前筛选。"
L["Instance: %s"]                           = "筛选：副本：%s"
L["Zone: %s"]                               = "筛选：区域：%s"
L["Social Quest Window"]                    = "SocialQuest 窗口"
L["Auto-filter to current instance"]        = "自动过滤当前副本"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "在地下城或团队副本中，「小队」和「已分享」标签仅显示当前副本的任务。"
L["Auto-filter to current zone"]            = "自动过滤当前区域"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "在副本外，「小队」和「已分享」标签仅显示当前区域的任务。"

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "搜索..."
L["Clear search"]                            = "清除搜索"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "区域"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "区域名称（部分匹配）"
L["filter.key.title"]        = "标题"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "任务标题（部分匹配）"
L["filter.key.chain"]        = "任务链"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "任务链标题（部分匹配）"
L["filter.key.player"]       = "玩家"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "队员名称（仅队伍/共享标签）"
L["filter.key.level"]        = "等级"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "推荐任务等级"
L["filter.key.step"]         = "步骤"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "任务链步骤编号"
L["filter.key.group"]        = "组队"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "组队要求（是，否，2-5）"
L["filter.key.type"]         = "类型"
L["filter.key.type.desc"]    = "任务类型 — 任务链, 组队, 单人, 限时, 护送, 地下城, 团队副本, 精英, 日常, pvp, 击杀, 采集, 互动"
L["filter.key.status"]       = "状态"
L["filter.key.status.desc"]  = "任务状态（完成, 未完成, 失败）"
L["filter.key.tracked"]      = "追踪"
L["filter.key.tracked.desc"] = "在小地图上追踪（是, 否；仅我的标签）"
L["filter.key.shareable"] = true
L["filter.key.shareable.desc"] = true
L["filter.val.yes"]          = "是"
L["filter.val.no"]           = "否"
L["filter.val.complete"]     = "完成"
L["filter.val.incomplete"]   = "未完成"
L["filter.val.failed"]       = "失败"
L["filter.val.chain"]        = "任务链"
L["filter.val.group"]        = "组队"
L["filter.val.solo"]         = "单人"
L["filter.val.timed"]        = "限时"
L["filter.val.escort"]       = "护送"
L["filter.val.dungeon"]      = "地下城"
L["filter.val.raid"]         = "团队副本"
L["filter.val.elite"]        = "精英"
L["filter.val.daily"]        = "日常"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "击杀"
L["filter.val.gather"]       = "采集"
L["filter.val.interact"]     = "互动"
L["filter.err.UNKNOWN_KEY"]      = "未知的过滤键 '%s'"
L["filter.err.INVALID_OPERATOR"] = "运算符 '%s' 不能与 '%s' 一起使用"
L["filter.err.TYPE_MISMATCH"]    = "'%s' 需要数字字段"
L["filter.err.UNCLOSED_QUOTE"]   = "过滤表达式中存在未闭合的引号"
L["filter.err.EMPTY_VALUE"]      = "'%s' 后缺少值"
L["filter.err.INVALID_NUMBER"]   = "'%s' 需要数字，但收到 '%s'"
L["filter.err.RANGE_REVERSED"]   = "无效范围：最小值 (%s) 必须 <= 最大值 (%s)"
L["filter.err.INVALID_ENUM"]     = "'%s' 不是 '%s' 的有效值"
L["filter.err.label"]            = "过滤错误：%s"
L["filter.err.MIXED_AND_OR"] = true
L["filter.err.AND_KEY_MISMATCH"] = true
L["filter.help.title"]                = "SQ 过滤语法"
L["filter.help.intro"]                = "输入过滤表达式并按 Enter 将其应用为持久标签。用 [x] 关闭标签。若要组合多个条件，请逐一输入并按 Enter——每次 Enter 都会添加新标签（AND 逻辑）。"
L["filter.help.section.syntax"]       = "语法"
L["filter.help.section.keys"]         = "支持的键"
L["filter.help.section.examples"]     = "示例"
L["filter.help.col.key"]              = "键"
L["filter.help.col.aliases"]          = "别名"
L["filter.help.col.desc"]             = "描述"
L["filter.help.example.1"]            = "等级>=60"
L["filter.help.example.1.note"]       = "显示60级或以上的任务"
L["filter.help.example.2"]            = "等级=58..62"
L["filter.help.example.2.note"]       = "显示58-62级范围内的任务"
L["filter.help.example.3"]            = "区域=艾尔文|死亡矿"
L["filter.help.example.3.note"]       = "显示艾尔文森林或死亡矿井中的任务"
L["filter.help.example.4"]            = "状态=未完成"
L["filter.help.example.4.note"]       = "仅显示未完成的任务"
L["filter.help.example.5"]            = "类型=任务链"
L["filter.help.example.5.note"]       = "仅显示任务链中的任务"
L["filter.help.example.6"]            = "区域=\"地狱火半岛\""
L["filter.help.example.6.note"]       = "带引号的值（当值包含空格时使用）"
L["filter.help.type.note"]            = "击杀、采集和互动匹配至少包含一个相应目标的任务——任务可以匹配多种类型。类型过滤器需要安装 Questie 或 Quest Weaver 插件。"
L["filter.help.example.7"]            = "类型=地下城"
L["filter.help.example.7.note"]       = "仅显示地下城任务（需要 Questie 或 Quest Weaver）"
L["filter.help.example.8"]            = "类型=击杀"
L["filter.help.example.8.note"]       = "显示至少有一个击杀目标的任务"
L["filter.help.example.9"]            = "类型=日常"
L["filter.help.example.9.note"]       = "仅显示日常任务"
L["filter.help.example.10"]           = "追踪=是"
L["filter.help.example.10.note"]      = "仅显示已追踪任务（仅限「我的」标签页）"
L["filter.help.example.11"]           = "组队=否"
L["filter.help.example.11.note"]      = "仅显示单人任务（无组队需求）"
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
L["share.tooltip"] = "与队伍成员分享此任务"
L["share.reason.level_too_low"]    = "等级过低"
L["share.reason.level_too_high"]   = "等级过高"
L["share.reason.wrong_race"]       = "种族不符"
L["share.reason.wrong_class"]      = "职业不符"
L["share.reason.quest_log_full"]   = "任务日志已满"
L["share.reason.exclusive_quest"]  = "已接互斥任务"
L["share.reason.already_advanced"] = "已超过此步骤"

-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "提示信息"
L["Enhance Questie/Blizzard tooltips"]               = "增强 Questie/暴雪任务提示"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "在现有任务提示框中添加队伍成员进度。"
L["Replace Blizzard quest tooltips"]                  = "替换暴雪任务提示"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "点击任务链接时，显示 SocialQuest 完整提示框而非原版任务提示框。"
L["Replace Questie quest tooltips"]                   = "替换 Questie 任务提示"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "点击 Questie 链接时，显示 SocialQuest 完整提示框而非 Questie 提示框。未安装 Questie 时不可用。"
-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "你正在进行此任务"
L["You have completed this quest"]                    = "你已完成此任务"
L["You are eligible for this quest"]                  = "你可以接取此任务"
L["You are not eligible for this quest"]              = "你无法接取此任务"
-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "任务发布者："
L["Turn In:"]                                         = "交任务处："
-- UI/Tooltips.lua — BuildTooltip title and location lines
L["Location:"]                                        = "地点："
L["(Dungeon)"]                                        = "(地下城)"
L["(Raid)"]                                           = "(团队副本)"
L["(Group %d+)"]                                      = "(组队 %d+)"

-- Core/Announcements.lua — friend presence banners
-- %s = character description (e.g. "Arthas 60 Paladin") or "BattleTagName (charDesc)"
L["%s Online"]                              = "%s 上线"
L["%s Offline"]                             = "%s 下线"
L["%s (%s) Online"]                         = "%s（%s）上线"
L["%s (%s) Offline"]                        = "%s（%s）下线"
L["Level %d"]                               = "%d级"
L["in %s"]                                  = "在%s"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "好友通知"
L["Enable friend notifications"]            = "启用好友通知"
L["Show online banners"]                    = "显示上线横幅"
L["Show offline banners"]                   = "显示下线横幅"
L["Show a banner when a friend logs into or out of WoW."]  = "当好友登录或退出《魔兽世界》时显示横幅通知。"
L["Show a banner when a friend logs into WoW."]            = "当好友登录《魔兽世界》时显示横幅通知。"
L["Show a banner when a friend logs out of WoW."]          = "当好友退出《魔兽世界》时显示横幅通知。"

-- UI/Options.lua — Friend Notifications debug buttons
L["Test Friend Online"]                     = "测试好友上线"
L["Display a demo friend online banner."]   = "显示好友上线演示横幅。"
L["Test Friend Offline"]                    = "测试好友下线"
L["Display a demo friend offline banner."]  = "显示好友下线演示横幅。"
