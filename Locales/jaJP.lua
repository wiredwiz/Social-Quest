-- Locales/jaJP.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "jaJP")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "クエスト受注: %s"
L["Quest abandoned: %s"]                  = "クエスト放棄: %s"
L["Quest complete (objectives done): %s"] = "クエスト完了（目標達成）: %s"
L["Quest turned in: %s"]                  = "クエスト達成: %s"
L["Quest failed: %s"]                     = "クエスト失敗: %s"
L["Quest event: %s"]                      = "クエストイベント: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " （後退）"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s [%s]!"
L["{rt1} SocialQuest: Quest Turned In: %s"] = "{rt1} SocialQuest: クエスト完了: %s"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s が受注: %s"
L["%s abandoned: %s"]                     = "%s が放棄: %s"
L["%s completed: %s"]                     = "%sがクエストを達成: %s"
L["%s turned in: %s"]                     = "%sがクエストを完了: %s"
L["%s failed: %s"]                        = "%s が失敗: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s が目標クリア: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s が後退: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s が進捗: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (プレビュー):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "全員達成: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "あなた"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s があなたをフォローし始めました。"
L["%s stopped following you."]            = "%s があなたのフォローをやめました。"

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "エラー: AbsoluteQuestLog-1.0 がインストールされていません。SocialQuest は無効です。"
L["Left-click to open group quest frame."]  = "左クリックでグループクエストフレームを開きます。"
L["Right-click to open settings."]          = "右クリックで設定を開きます。"

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — グループクエスト"
L["Quest URL (Ctrl+C to copy)"]            = "クエストURL（Ctrl+Cでコピー）"

-- UI/RowFactory.lua
L["expand all"]                            = "すべて展開"
L["collapse all"]                          = "すべて折りたたむ"
L["Click here to copy the wowhead quest url"] = "クリックしてWowheadクエストURLをコピー"
L["(Complete)"]                            = "（完了）"
L["(Group)"]                               = "（グループ）"
L[" (Step %s of %s)"]                      = " （第 %s/%s ステップ）"
L["(Step %s)"]                             = "(ステップ %s)"
L["Finished"]                              = "完了"
L["In Progress"]                           = "進行中"
L["(In Progress)"]                         = "（進行中）"
L["%s Needs it Shared"]                    = "%s に共有が必要"
L["%s (no data)"]                          = "%s （データなし）"

-- UI/Tooltips.lua
L["Group Progress"]                        = "グループ進捗"
L["Party progress"]                        = "グループ進捗"
L["(shared, no data)"]                     = "（共有済み、データなし）"
L["Objectives complete"]                   = "目標達成"
L["(no data)"]                             = "（データなし）"

-- UI tab labels
L["Mine"]                                  = "自分"
L["Other Quests"]                          = "その他のクエスト"
L["Party"]                                 = "パーティ"
L["(You)"]                                 = "（あなた）"
L["Shared"]                                = "共有"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "受注"
L["Abandoned"]                             = "放棄"
L["Complete"]                              = "達成"
L["Turned In"]                             = "完了"
L["Failed"]                                = "失敗"
L["Objective Progress"]                    = "目標進捗"
L["Objective Complete"]                    = "目標クリア"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "クエストを受注したときにチャットメッセージを送信します。"
L["Send a chat message when you abandon a quest."]                       = "クエストを放棄したときにチャットメッセージを送信します。"
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "クエストの全目標が完了したときにチャットメッセージを送信します（達成前）。"
L["Send a chat message when you turn in a quest."]                       = "クエストを達成したときにチャットメッセージを送信します。"
L["Send a chat message when a quest fails."]                             = "クエストが失敗したときにチャットメッセージを送信します。"
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "クエスト目標が進捗または後退したときにチャットメッセージを送信します。形式はQuestieのスタイルに合わせています。Questieによって抑制されることはありません — Questieは部分的な進捗を通知しません。"
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "クエスト目標が達成されたときにチャットメッセージを送信します（例: 8/8 コボルト）。Questieがインストールされ「目標を通知」設定が有効な場合は自動的に抑制されます。"

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "チャットで通知"
L["Own Quest Banners"]                     = "自分のクエストバナー"
L["Display Events"]                        = "イベント表示"
L["General"]                               = "一般"
L["Raid"]                                  = "レイド"
L["Guild"]                                 = "ギルド"
L["Battleground"]                          = "バトルグラウンド"
L["Whisper Friends"]                       = "フレンドにウィスパー"
L["Follow Notifications"]                  = "フォロー通知"
L["Debug"]                                 = "デバッグ"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "クエストを受注したときにバナーを表示します。"
L["Show a banner when you abandon a quest."]                                           = "クエストを放棄したときにバナーを表示します。"
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "クエストの全目標が完了したときにバナーを表示します（達成前）。"
L["Show a banner when you turn in a quest."]                                           = "クエストを達成したときにバナーを表示します。"
L["Show a banner when a quest fails."]                                                 = "クエストが失敗したときにバナーを表示します。"
L["Show a banner when one of your quest objectives progresses or regresses."]          = "クエスト目標が進捗または後退したときにバナーを表示します。"
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "クエスト目標が達成されたときにバナーを表示します（例: 8/8）。"

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "グループメンバーがクエストを受注したときにバナーを表示します。"
L["Show a banner on screen when a group member abandons a quest."]                     = "グループメンバーがクエストを放棄したときにバナーを表示します。"
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "グループメンバーがクエストの全目標を完了したときにバナーを表示します。"
L["Show a banner on screen when a group member turns in a quest."]                     = "グループメンバーがクエストを達成したときにバナーを表示します。"
L["Show a banner on screen when a group member fails a quest."]                        = "グループメンバーのクエストが失敗したときにバナーを表示します。"
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "グループメンバーのクエスト目標数が変化したときにバナーを表示します（部分的な進捗と後退を含む）。"
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "グループメンバーがクエスト目標を達成したときにバナーを表示します（例: 8/8）。"

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "SocialQuestを有効化"
L["Master on/off switch for all SocialQuest functionality."]             = "SocialQuestの全機能のオン/オフスイッチです。"
L["Show received events"]                  = "受信イベントを表示"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "バナー通知の表示を許可するマスタースイッチ。下の「イベント表示」グループで各セクションのイベントタイプを制御します。"
L["Colorblind Mode"]                       = "色覚補助モード"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "SocialQuestのバナーとUIテキストに色覚補助向けの色を使用します。ゲームクライアントで色覚補助モードが有効な場合は不要です。"
L["Show minimap button"]                    = "ミニマップボタンを表示"
L["Show or hide the SocialQuest minimap button."]                        = "SocialQuestのミニマップボタンを表示/非表示にします。"
L["Show banners for your own quest events"] = "自分のクエストイベントにバナーを表示"
L["Show a banner on screen for your own quest events."]                  = "自分のクエストイベントにバナーを表示します。"

-- UI/Options.lua — party section
L["Enable transmission"]                   = "送信を有効化"
L["Broadcast your quest events to party members via addon comm."]        = "アドオン通信でクエストイベントをパーティメンバーに送信します。"
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "パーティメンバーからのバナー通知を許可します（下のイベント表示設定に従います）。"

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "アドオン通信でクエストイベントをレイドメンバーに送信します。"
L["Allow banner notifications from raid members."]                       = "レイドメンバーからのバナー通知を許可します。"
L["Only show notifications from friends"]  = "フレンドからの通知のみ表示"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "フレンドリストのプレイヤーからのバナー通知のみ表示し、大規模レイドの見知らぬプレイヤーからの通知を抑制します。"

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "チャット通知を有効化"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "ギルドチャットでクエストイベントを通知します。ギルドメンバーはSocialQuestをインストールしなくてもメッセージを見ることができます。"

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "アドオン通信でクエストイベントをバトルグラウンドメンバーに送信します。"
L["Allow banner notifications from battleground members."]               = "バトルグラウンドメンバーからのバナー通知を許可します。"
L["Only show banner notifications from friends in the battleground."]    = "バトルグラウンドのフレンドからのバナー通知のみ表示します。"

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "フレンドへのウィスパーを有効化"
L["Send your quest events as whispers to online friends."]               = "オンラインのフレンドにクエストイベントをウィスパーで送信します。"
L["Group members only"]                    = "グループメンバーのみ"
L["Restrict whispers to friends currently in your group."]               = "現在のグループ内のフレンドのみにウィスパーを制限します。"

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "フォロー通知を有効化"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "フォロー開始/終了時にプレイヤーにウィスパーを送信し、誰かがフォローしたときに通知を受け取ります。"
L["Announce when you follow someone"]      = "フォロー開始時に通知"
L["Whisper the player you begin following so they know you are following them."] = "フォローを開始したプレイヤーに、あなたがフォローしていることを知らせるウィスパーを送ります。"
L["Announce when followed"]                = "フォローされたときに通知"
L["Display a local message when someone starts or stops following you."] = "誰かがあなたのフォローを開始または終了したときにローカルメッセージを表示します。"

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "デバッグモードを有効化"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "内部デバッグメッセージをチャットフレームに表示します。通信の問題やイベントフローの診断に役立ちます。"

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "バナーとチャットのテスト"
L["Test Accepted"]                         = "受注テスト"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "「クエスト受注」イベントのデモバナーとローカルチャットプレビューを表示します。すべての表示フィルターをバイパスします。"
L["Test Abandoned"]                        = "放棄テスト"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "「クエスト放棄」イベントのデモバナーとローカルチャットプレビューを表示します。"
L["Test Complete"]                         = "達成テスト"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "「クエスト達成」イベント（全目標完了、未完了）のデモバナーとローカルチャットプレビューを表示します。"
L["Test Turned In"]                        = "完了テスト"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "「クエスト完了」イベントのデモバナーとローカルチャットプレビューを表示します。"
L["Test Failed"]                           = "失敗テスト"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "「クエスト失敗」イベントのデモバナーとローカルチャットプレビューを表示します。"
L["Test Obj. Progress"]                    = "目標進捗テスト"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "部分的な目標進捗更新（例: 3/8）のデモバナーとローカルチャットプレビューを表示します。"
L["Test Obj. Complete"]                    = "目標クリアテスト"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "目標達成（例: 8/8）のデモバナーとローカルチャットプレビューを表示します。"
L["Test Obj. Regression"]                  = "目標後退テスト"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "目標後退（カウントが減少）のデモバナーとローカルチャットプレビューを表示します。"
L["Test All Completed"]                    = "全員達成テスト"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "「全員達成」紫色通知のデモバナーを表示します。チャットプレビューなし（このイベントは直接外向きチャットを生成しません）。"
L["Test Chat Link"]                        = "チャットリンクテスト"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "実際のWoWクエストハイパーリンクを使用してクエスト337の「クエスト提出」メッセージのローカルチャットプレビューを表示します。クエスト名がチャットフレームにクリック可能な金色のテキストとして表示されることを確認してください。"
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "クリックしてこのタブのフィルターを閉じます。"
L["Instance: %s"]                           = "フィルター: インスタンス: %s"
L["Zone: %s"]                               = "フィルター: ゾーン: %s"
L["Social Quest Window"]                    = "SocialQuest ウィンドウ"
L["Auto-filter to current instance"]        = "現在のインスタンスで自動フィルター"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "ダンジョンやレイドにいる間、「パーティ」と「共有」タブは現在のインスタンスのクエストのみ表示します。"
L["Auto-filter to current zone"]            = "現在のゾーンで自動フィルター"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "インスタンス外では、「パーティ」と「共有」タブは現在のゾーンのクエストのみ表示します。"

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "検索..."
L["Clear search"]                            = "検索をクリア"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "ゾーン"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "ゾーン名（部分一致）"
L["filter.key.title"]        = "タイトル"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "クエストタイトル（部分一致）"
L["filter.key.chain"]        = "シリーズ"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "シリーズタイトル（部分一致）"
L["filter.key.player"]       = "プレイヤー"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "パーティメンバー名（パーティ/共有タブのみ）"
L["filter.key.level"]        = "レベル"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "推奨クエストレベル"
L["filter.key.step"]         = "ステップ"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "シリーズのステップ番号"
L["filter.key.group"]        = "グループ"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "グループ要件（はい, いいえ, 2-5）"
L["filter.key.type"]         = "タイプ"
L["filter.key.type.desc"]    = "クエストタイプ — シリーズ, グループ, ソロ, 時間制限, エスコート, ダンジョン, レイド, エリート, デイリー, pvp, 討伐, 採集, インタラクト"
L["filter.key.status"]       = "ステータス"
L["filter.key.status.desc"]  = "クエストステータス（完了, 未完了, 失敗）"
L["filter.key.tracked"]      = "追跡中"
L["filter.key.tracked.desc"] = "ミニマップで追跡中（はい, いいえ；マイタブのみ）"
L["filter.key.shareable"] = true
L["filter.key.shareable.desc"] = true
L["filter.val.yes"]          = "はい"
L["filter.val.no"]           = "いいえ"
L["filter.val.complete"]     = "完了"
L["filter.val.incomplete"]   = "未完了"
L["filter.val.failed"]       = "失敗"
L["filter.val.chain"]        = "シリーズ"
L["filter.val.group"]        = "グループ"
L["filter.val.solo"]         = "ソロ"
L["filter.val.timed"]        = "時間制限"
L["filter.val.escort"]       = "エスコート"
L["filter.val.dungeon"]      = "ダンジョン"
L["filter.val.raid"]         = "レイド"
L["filter.val.elite"]        = "エリート"
L["filter.val.daily"]        = "デイリー"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "討伐"
L["filter.val.gather"]       = "採集"
L["filter.val.interact"]     = "インタラクト"
L["filter.err.UNKNOWN_KEY"]      = "不明なフィルターキー '%s'"
L["filter.err.INVALID_OPERATOR"] = "演算子 '%s' は '%s' には使用できません"
L["filter.err.TYPE_MISMATCH"]    = "'%s' には数値フィールドが必要です"
L["filter.err.UNCLOSED_QUOTE"]   = "フィルター式に閉じられていない引用符があります"
L["filter.err.EMPTY_VALUE"]      = "'%s' の後に値がありません"
L["filter.err.INVALID_NUMBER"]   = "'%s' には数値が必要ですが、'%s' を受け取りました"
L["filter.err.RANGE_REVERSED"]   = "無効な範囲：最小値 (%s) は最大値 (%s) 以下である必要があります"
L["filter.err.INVALID_ENUM"]     = "'%s' は '%s' の有効な値ではありません"
L["filter.err.label"]            = "フィルターエラー：%s"
L["filter.err.MIXED_AND_OR"] = true
L["filter.err.AND_KEY_MISMATCH"] = true
L["filter.help.title"]                = "SQ フィルター構文"
L["filter.help.intro"]                = "フィルター式を入力してEnterを押すと、固定ラベルとして適用されます。[x]でラベルを閉じます。フィルターを組み合わせるには、一つずつ入力してEnterを押してください — 押すたびに新しいラベルが追加されます（AND条件）。"
L["filter.help.section.syntax"]       = "構文"
L["filter.help.section.keys"]         = "サポートされているキー"
L["filter.help.section.examples"]     = "例"
L["filter.help.col.key"]              = "キー"
L["filter.help.col.aliases"]          = "エイリアス"
L["filter.help.col.desc"]             = "説明"
L["filter.help.example.1"]            = "レベル>=60"
L["filter.help.example.1.note"]       = "レベル60以上のクエストを表示"
L["filter.help.example.2"]            = "レベル=58..62"
L["filter.help.example.2.note"]       = "レベル58-62範囲のクエストを表示"
L["filter.help.example.3"]            = "ゾーン=エルウィン|デッドマインズ"
L["filter.help.example.3.note"]       = "エルウィンの森またはデッドマインズのクエストを表示"
L["filter.help.example.4"]            = "ステータス=未完了"
L["filter.help.example.4.note"]       = "未完了のクエストのみ表示"
L["filter.help.example.5"]            = "タイプ=シリーズ"
L["filter.help.example.5.note"]       = "シリーズクエストのみ表示"
L["filter.help.example.6"]            = "ゾーン=\"地獄火の半島\""
L["filter.help.example.6.note"]       = "引用符付きの値（値にスペースが含まれる場合に使用）"
L["filter.help.type.note"]            = "討伐、採集、インタラクトは、その種類の目標が少なくとも1つあるクエストに一致します — クエストは複数のタイプに一致できます。タイプフィルターには Questie または Quest Weaver アドオンが必要です。"
L["filter.help.example.7"]            = "タイプ=ダンジョン"
L["filter.help.example.7.note"]       = "ダンジョンクエストのみ表示（Questie または Quest Weaver が必要）"
L["filter.help.example.8"]            = "タイプ=討伐"
L["filter.help.example.8.note"]       = "討伐目標が少なくとも1つあるクエストを表示"
L["filter.help.example.9"]            = "タイプ=デイリー"
L["filter.help.example.9.note"]       = "デイリークエストのみ表示"
L["filter.help.example.10"]           = "追跡中=はい"
L["filter.help.example.10.note"]      = "追跡中のクエストのみ表示（マイクエストタブのみ）"
L["filter.help.example.11"]           = "グループ=いいえ"
L["filter.help.example.11.note"]      = "ソロクエストのみ表示（グループ不要）"
L["filter.help.example.12"] = true
L["filter.help.example.12.note"] = true
L["filter.help.example.13"] = true
L["filter.help.example.13.note"] = true
L["filter.help.example.14"] = true
L["filter.help.example.14.note"] = true
L["filter.help.example.15"] = true
L["filter.help.example.15.note"] = true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "共有"
L["share.tooltip"] = "このクエストをパーティメンバーと共有する"
L["share.reason.level_too_low"]    = "レベルが低すぎる"
L["share.reason.level_too_high"]   = "レベルが高すぎる"
L["share.reason.wrong_race"]       = "種族が合わない"
L["share.reason.wrong_class"]      = "クラスが合わない"
L["share.reason.quest_log_full"]   = "クエストログが満杯"
L["share.reason.exclusive_quest"]  = "排他クエストを受注済み"
L["share.reason.already_advanced"] = "すでに次のステップに進んでいる"

-- UI/Options.lua — Tooltips group
L["Tooltips"]                                         = "ツールチップ"
L["Enhance Questie/Blizzard tooltips"]               = "Questie/Blizzardのツールチップを拡張"
L["Append party progress to existing quest tooltips. Adds party member status below Questie's or WoW's tooltip."] = "既存のクエストツールチップにパーティ進行状況を追加します。"
L["Replace Blizzard quest tooltips"]                  = "Blizzardのクエストツールチップを置換"
L["When clicking a quest link, show SocialQuest's full tooltip instead of WoW's basic tooltip."] = "クエストリンクのクリック時にWoWの基本ツールチップの代わりにSocialQuestのツールチップを表示します。"
L["Replace Questie quest tooltips"]                   = "Questieのクエストツールチップを置換"
L["When clicking a questie link, show SocialQuest's full tooltip instead of Questie's tooltip. Not available when Questie is not installed."] = "Questieリンクのクリック時にQuestieのツールチップの代わりにSocialQuestのツールチップを表示します。Questie未インストール時は使用できません。"
-- UI/Tooltips.lua — BuildTooltip status lines
L["You are on this quest"]                            = "このクエストを進行中です"
L["You have completed this quest"]                    = "このクエストを完了しました"
L["You are eligible for this quest"]                  = "このクエストを受注できます"
L["You are not eligible for this quest"]              = "このクエストを受注できません"
-- UI/Tooltips.lua — BuildTooltip NPC labels
L["Quest Giver:"]                                     = "クエスト発行者："
L["Turn In:"]                                         = "完了報告："
-- UI/Tooltips.lua — BuildTooltip title and location lines
L["Location:"]                                        = "場所："
L["(Dungeon)"]                                        = "(ダンジョン)"
L["(Raid)"]                                           = "(レイド)"
L["(Group %d+)"]                                      = "(グループ %d+)"

-- Core/Announcements.lua — friend presence banners
-- %s = character description (e.g. "Arthas 60 Paladin") or "BattleTagName (charDesc)"
L["%s Online"]                              = "%s がログインしました"
L["%s Offline"]                             = "%s がログアウトしました"
L["%s (%s) Online"]                         = "%s (%s) がログインしました"
L["%s (%s) Offline"]                        = "%s (%s) がログアウトしました"
L["Level %d"]                               = "レベル%d"
L["in %s"]                                  = "%sにて"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "フレンド通知"
L["Enable friend notifications"]            = "フレンド通知を有効にする"
L["Show online banners"]                    = "ログインバナーを表示"
L["Show offline banners"]                   = "ログアウトバナーを表示"
L["Show a banner when a friend logs into or out of WoW."]  = "フレンドがWoWにログインまたはログアウトしたときにバナーを表示します。"
L["Show a banner when a friend logs into WoW."]            = "フレンドがWoWにログインしたときにバナーを表示します。"
L["Show a banner when a friend logs out of WoW."]          = "フレンドがWoWからログアウトしたときにバナーを表示します。"

-- UI/Options.lua — Friend Notifications debug buttons
L["Test Friend Online"]                     = "フレンドログインテスト"
L["Display a demo friend online banner."]   = "フレンドログインのデモバナーを表示します。"
L["Test Friend Offline"]                    = "フレンドログアウトテスト"
L["Display a demo friend offline banner."]  = "フレンドログアウトのデモバナーを表示します。"
