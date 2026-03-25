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
L["%s FINISHED"]                           = "%s 完了"
L["%s Needs it Shared"]                    = "%s に共有が必要"
L["%s (no data)"]                          = "%s （データなし）"

-- UI/Tooltips.lua
L["Group Progress"]                        = "グループ進捗"
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
L["Test Flight Discovery"]                 = "フライト発見テスト"
L["Display a demo flight path unlock banner using your character's starting city as the demo location."] = "キャラクターの出発地をデモ地点として使用して、フライトパス解放のデモバナーを表示します。"

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
