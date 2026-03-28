-- Locales/koKR.lua
local L = LibStub("AceLocale-3.0"):NewLocale("SocialQuest", "koKR")
if not L then return end

-- Core/Announcements.lua — outbound chat templates
L["Quest accepted: %s"]                   = "퀘스트 수락: %s"
L["Quest abandoned: %s"]                  = "퀘스트 포기: %s"
L["Quest complete (objectives done): %s"] = "퀘스트 완료 (목표 달성): %s"
L["Quest turned in: %s"]                  = "퀘스트 제출: %s"
L["Quest failed: %s"]                     = "퀘스트 실패: %s"
L["Quest event: %s"]                      = "퀘스트 이벤트: %s"

-- Core/Announcements.lua — outbound objective chat
L[" (regression)"]                        = " (퇴보)"
L["{rt1} SocialQuest: %d/%d %s%s for %s!"] = "{rt1} SocialQuest: %d/%d %s%s, 퀘스트: %s!"
L["{rt1} SocialQuest: Quest Turned In: %s"] = "{rt1} SocialQuest: 퀘스트 반납: %s"

-- Core/Announcements.lua — inbound banner templates
L["%s accepted: %s"]                      = "%s 수락: %s"
L["%s abandoned: %s"]                     = "%s 포기: %s"
L["%s completed: %s"]                     = "%s 퀘스트 완료: %s"
L["%s turned in: %s"]                     = "%s 반납: %s"
L["%s failed: %s"]                        = "%s 실패: %s"
L["%s completed objective: %s — %s (%d/%d)"] = "%s 목표 달성: %s — %s (%d/%d)"
L["%s regressed: %s — %s (%d/%d)"]           = "%s 퇴보: %s — %s (%d/%d)"
L["%s progressed: %s — %s (%d/%d)"]          = "%s 진행: %s — %s (%d/%d)"

-- Core/Announcements.lua — chat preview label
L["|cFF00CCFFSocialQuest (preview):|r "]  = "|cFF00CCFFSocialQuest (미리보기):|r "

-- Core/Announcements.lua — all-completed banner
L["Everyone has completed: %s"]           = "모두 완료: %s"

-- Core/Announcements.lua — own-quest banner sender label
L["You"]                                  = "나"

-- Core/Announcements.lua — follow notifications
L["%s started following you."]            = "%s이(가) 당신을 따르기 시작했습니다."
L["%s stopped following you."]            = "%s이(가) 당신을 따르는 것을 멈췄습니다."

-- SocialQuest.lua
L["ERROR: AbsoluteQuestLog-1.0 is not installed. SocialQuest is disabled."] = "오류: AbsoluteQuestLog-1.0이 설치되지 않았습니다. SocialQuest가 비활성화되었습니다."
L["Left-click to open group quest frame."]  = "마우스 왼쪽 버튼을 클릭하여 그룹 퀘스트 창을 엽니다."
L["Right-click to open settings."]          = "마우스 오른쪽 버튼을 클릭하여 설정을 엽니다."

-- UI/GroupFrame.lua
L["SocialQuest — Group Quests"]            = "SocialQuest — 그룹 퀘스트"
L["Quest URL (Ctrl+C to copy)"]            = "퀘스트 URL (Ctrl+C로 복사)"

-- UI/RowFactory.lua
L["expand all"]                            = "모두 펼치기"
L["collapse all"]                          = "모두 접기"
L["Click here to copy the wowhead quest url"] = "여기를 클릭하여 Wowhead 퀘스트 URL 복사"
L["(Complete)"]                            = "(완료)"
L["(Group)"]                               = "(그룹)"
L[" (Step %s of %s)"]                      = " (%s/%s 단계)"
L["(Step %s)"]                             = "(단계 %s)"
L["%s FINISHED"]                           = "%s 완료"
L["%s Needs it Shared"]                    = "%s에게 공유 필요"
L["%s (no data)"]                          = "%s (데이터 없음)"

-- UI/Tooltips.lua
L["Group Progress"]                        = "그룹 진행도"
L["(shared, no data)"]                     = "(공유됨, 데이터 없음)"
L["Objectives complete"]                   = "목표 완료"
L["(no data)"]                             = "(데이터 없음)"

-- UI tab labels
L["Mine"]                                  = "내 퀘스트"
L["Other Quests"]                          = "다른 퀘스트"
L["Party"]                                 = "파티"
L["(You)"]                                 = "(나)"
L["Shared"]                                = "공유됨"

-- UI/Options.lua — toggle names
L["Accepted"]                              = "수락됨"
L["Abandoned"]                             = "포기됨"
L["Complete"]                              = "완료"
L["Turned In"]                             = "반납"
L["Failed"]                                = "실패됨"
L["Objective Progress"]                    = "목표 진행도"
L["Objective Complete"]                    = "목표 달성"

-- UI/Options.lua — announce chat toggle descriptions
L["Send a chat message when you accept a quest."]                        = "퀘스트를 수락할 때 채팅 메시지를 보냅니다."
L["Send a chat message when you abandon a quest."]                       = "퀘스트를 포기할 때 채팅 메시지를 보냅니다."
L["Send a chat message when all your quest objectives are complete (before turning in)."] = "모든 퀘스트 목표가 완료되었을 때 채팅 메시지를 보냅니다 (제출 전)."
L["Send a chat message when you turn in a quest."]                       = "퀘스트를 제출할 때 채팅 메시지를 보냅니다."
L["Send a chat message when a quest fails."]                             = "퀘스트가 실패할 때 채팅 메시지를 보냅니다."
L["Send a chat message when a quest objective progresses or regresses. Format matches Questie's style. Never suppressed by Questie — Questie does not announce partial progress."] = "퀘스트 목표가 진행되거나 퇴보할 때 채팅 메시지를 보냅니다. 형식은 Questie 스타일과 일치합니다. Questie에 의해 억제되지 않습니다 — Questie는 부분 진행을 알리지 않습니다."
L["Send a chat message when a quest objective reaches its goal (e.g. 8/8 Kobolds). Suppressed automatically if Questie is installed and its 'Announce Objectives' setting is enabled."] = "퀘스트 목표가 달성될 때 채팅 메시지를 보냅니다 (예: 8/8 코볼트). Questie가 설치되어 있고 '목표 알림' 설정이 활성화된 경우 자동으로 억제됩니다."

-- UI/Options.lua — group headers
L["Announce in Chat"]                      = "채팅에서 알림"
L["Own Quest Banners"]                     = "내 퀘스트 배너"
L["Display Events"]                        = "이벤트 표시"
L["General"]                               = "일반"
L["Raid"]                                  = "공격대"
L["Guild"]                                 = "길드"
L["Battleground"]                          = "전장"
L["Whisper Friends"]                       = "친구에게 귓속말"
L["Follow Notifications"]                  = "따라가기 알림"
L["Debug"]                                 = "디버그"

-- UI/Options.lua — own-quest banner toggle descriptions
L["Show a banner when you accept a quest."]                                            = "퀘스트를 수락할 때 배너를 표시합니다."
L["Show a banner when you abandon a quest."]                                           = "퀘스트를 포기할 때 배너를 표시합니다."
L["Show a banner when all objectives on a quest are complete (before turning in)."]    = "퀘스트의 모든 목표가 완료될 때 배너를 표시합니다 (제출 전)."
L["Show a banner when you turn in a quest."]                                           = "퀘스트를 제출할 때 배너를 표시합니다."
L["Show a banner when a quest fails."]                                                 = "퀘스트가 실패할 때 배너를 표시합니다."
L["Show a banner when one of your quest objectives progresses or regresses."]          = "퀘스트 목표 중 하나가 진행되거나 퇴보할 때 배너를 표시합니다."
L["Show a banner when one of your quest objectives reaches its goal (e.g. 8/8)."]     = "퀘스트 목표 중 하나가 달성될 때 배너를 표시합니다 (예: 8/8)."

-- UI/Options.lua — display events toggle descriptions
L["Show a banner on screen when a group member accepts a quest."]                      = "그룹 구성원이 퀘스트를 수락할 때 화면에 배너를 표시합니다."
L["Show a banner on screen when a group member abandons a quest."]                     = "그룹 구성원이 퀘스트를 포기할 때 화면에 배너를 표시합니다."
L["Show a banner on screen when a group member completes all objectives on a quest."]  = "그룹 구성원이 퀘스트의 모든 목표를 완료할 때 화면에 배너를 표시합니다."
L["Show a banner on screen when a group member turns in a quest."]                     = "그룹 구성원이 퀘스트를 제출할 때 화면에 배너를 표시합니다."
L["Show a banner on screen when a group member fails a quest."]                        = "그룹 구성원이 퀘스트에 실패할 때 화면에 배너를 표시합니다."
L["Show a banner on screen when a group member's quest objective count changes (includes partial progress and regression)."] = "그룹 구성원의 퀘스트 목표 수가 변경될 때 화면에 배너를 표시합니다 (부분 진행 및 퇴보 포함)."
L["Show a banner on screen when a group member completes a quest objective (e.g. 8/8)."] = "그룹 구성원이 퀘스트 목표를 달성할 때 화면에 배너를 표시합니다 (예: 8/8)."

-- UI/Options.lua — general toggles
L["Enable SocialQuest"]                    = "SocialQuest 활성화"
L["Master on/off switch for all SocialQuest functionality."]             = "모든 SocialQuest 기능의 마스터 켜기/끄기 스위치입니다."
L["Show received events"]                  = "수신된 이벤트 표시"
L["Master switch: allow any banner notifications to appear. Individual 'Display Events' groups below control which event types are shown per section."] = "마스터 스위치: 배너 알림 표시를 허용합니다. 아래의 각 '이벤트 표시' 그룹은 섹션별로 표시할 이벤트 유형을 제어합니다."
L["Colorblind Mode"]                       = "색맹 모드"
L["Use colorblind-friendly colors for all SocialQuest banners and UI text. It is unnecessary to enable this if Color Blind mode is already enabled in the game client."] = "모든 SocialQuest 배너 및 UI 텍스트에 색맹 친화적인 색상을 사용합니다. 게임 클라이언트에서 색맹 모드가 이미 활성화된 경우 활성화할 필요가 없습니다."
L["Show minimap button"]                    = "미니맵 버튼 표시"
L["Show or hide the SocialQuest minimap button."]                        = "SocialQuest 미니맵 버튼을 표시하거나 숨깁니다."
L["Show banners for your own quest events"] = "내 퀘스트 이벤트에 배너 표시"
L["Show a banner on screen for your own quest events."]                  = "내 퀘스트 이벤트에 대한 배너를 화면에 표시합니다."

-- UI/Options.lua — party section
L["Enable transmission"]                   = "전송 활성화"
L["Broadcast your quest events to party members via addon comm."]        = "애드온 통신을 통해 파티 구성원에게 퀘스트 이벤트를 방송합니다."
L["Allow banner notifications from party members (subject to Display Events toggles below)."] = "파티 구성원의 배너 알림을 허용합니다 (아래 이벤트 표시 설정에 따름)."

-- UI/Options.lua — raid section
L["Broadcast your quest events to raid members via addon comm."]         = "애드온 통신을 통해 공격대 구성원에게 퀘스트 이벤트를 방송합니다."
L["Allow banner notifications from raid members."]                       = "공격대 구성원의 배너 알림을 허용합니다."
L["Only show notifications from friends"]  = "친구의 알림만 표시"
L["Only show banner notifications from players on your friends list, suppressing banners from strangers in large raids."] = "친구 목록에 있는 플레이어의 배너 알림만 표시하고, 대규모 공격대에서 낯선 사람의 배너를 억제합니다."

-- UI/Options.lua — guild section
L["Enable chat announcements"]             = "채팅 알림 활성화"
L["Announce your quest events in guild chat. Guild members do not need SocialQuest installed to see these messages."] = "길드 채팅에서 퀘스트 이벤트를 알립니다. 길드 구성원은 이 메시지를 보기 위해 SocialQuest를 설치할 필요가 없습니다."

-- UI/Options.lua — battleground section
L["Broadcast your quest events to battleground members via addon comm."] = "애드온 통신을 통해 전장 구성원에게 퀘스트 이벤트를 방송합니다."
L["Allow banner notifications from battleground members."]               = "전장 구성원의 배너 알림을 허용합니다."
L["Only show banner notifications from friends in the battleground."]    = "전장에서 친구의 배너 알림만 표시합니다."

-- UI/Options.lua — whisper friends section
L["Enable whispers to friends"]            = "친구에게 귓속말 활성화"
L["Send your quest events as whispers to online friends."]               = "온라인 친구에게 퀘스트 이벤트를 귓속말로 보냅니다."
L["Group members only"]                    = "그룹 구성원만"
L["Restrict whispers to friends currently in your group."]               = "귓속말을 현재 그룹에 있는 친구로 제한합니다."

-- UI/Options.lua — follow notifications section
L["Enable follow notifications"]           = "따라가기 알림 활성화"
L["Send a whisper to players you start or stop following, and receive notifications when someone follows you."] = "따라가기 시작하거나 멈춘 플레이어에게 귓속말을 보내고, 누군가 당신을 따라갈 때 알림을 받습니다."
L["Announce when you follow someone"]      = "누군가를 따라갈 때 알림"
L["Whisper the player you begin following so they know you are following them."] = "따라가기 시작한 플레이어에게 귓속말을 보내어 당신이 따라가고 있음을 알립니다."
L["Announce when followed"]                = "누군가 따라올 때 알림"
L["Display a local message when someone starts or stops following you."] = "누군가가 당신을 따라가기 시작하거나 멈출 때 로컬 메시지를 표시합니다."

-- UI/Options.lua — debug section
L["Enable debug mode"]                     = "디버그 모드 활성화"
L["Print internal debug messages to the chat frame. Useful for diagnosing comm issues or event flow problems."] = "내부 디버그 메시지를 채팅 프레임에 출력합니다. 통신 문제나 이벤트 흐름 문제를 진단하는 데 유용합니다."

-- UI/Options.lua — test banners group and buttons
L["Test Banners and Chat"]                 = "배너 및 채팅 테스트"
L["Test Accepted"]                         = "수락 테스트"
L["Display a demo banner and local chat preview for the 'Quest accepted' event. Bypasses all display filters."] = "'퀘스트 수락' 이벤트에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다. 모든 표시 필터를 우회합니다."
L["Test Abandoned"]                        = "포기 테스트"
L["Display a demo banner and local chat preview for the 'Quest abandoned' event."] = "'퀘스트 포기' 이벤트에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test Complete"]                         = "완료 테스트"
L["Display a demo banner and local chat preview for the 'Quest complete' event (all objectives filled, not yet turned in)."] = "'퀘스트 완료' 이벤트 (모든 목표 달성, 아직 제출 전)에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test Turned In"]                        = "반납 테스트"
L["Display a demo banner and local chat preview for the 'Quest turned in' event."] = "'퀘스트 제출' 이벤트에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test Failed"]                           = "실패 테스트"
L["Display a demo banner and local chat preview for the 'Quest failed' event."]    = "'퀘스트 실패' 이벤트에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test Obj. Progress"]                    = "목표 진행 테스트"
L["Display a demo banner and local chat preview for a partial objective progress update (e.g. 3/8)."] = "부분 목표 진행 업데이트 (예: 3/8)에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test Obj. Complete"]                    = "목표 달성 테스트"
L["Display a demo banner and local chat preview for an objective completion (e.g. 8/8)."] = "목표 달성 (예: 8/8)에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test Obj. Regression"]                  = "목표 퇴보 테스트"
L["Display a demo banner and local chat preview for an objective regression (count went backward)."] = "목표 퇴보 (카운트가 감소됨)에 대한 데모 배너와 로컬 채팅 미리보기를 표시합니다."
L["Test All Completed"]                    = "모두 완료 테스트"
L["Display a demo banner for the 'Everyone has completed' purple notification. No chat preview (this event never generates outbound chat directly)."] = "'모두 완료' 보라색 알림의 데모 배너를 표시합니다. 채팅 미리보기 없음 (이 이벤트는 직접 발신 채팅을 생성하지 않습니다)."
L["Test Chat Link"]                        = "채팅 링크 테스트"
L["Print a local chat preview of a 'Quest turned in' message for quest 337 using a real WoW quest hyperlink. Verify the quest name appears as clickable gold text in the chat frame."] = "실제 WoW 퀘스트 하이퍼링크를 사용하여 퀘스트 337의 '퀘스트 제출' 메시지에 대한 로컬 채팅 미리보기를 출력합니다. 퀘스트 이름이 채팅 프레임에 클릭 가능한 금색 텍스트로 나타나는지 확인하세요."
-- UI/Options.lua — follow notification test button
L["Test Follow Notification"]   = "Test Follow Notification"
L["Display a demo follow notification banner showing the 'started following you' message."] = "Display a demo follow notification banner showing the 'started following you' message."

-- UI/Options.lua — Social Quest Window option group
-- UI/WindowFilter.lua — filter header labels
L["Click to dismiss the active filter for this tab."] = "클릭하여 이 탭의 활성 필터를 닫습니다."
L["Instance: %s"]                           = "필터: 인스턴스: %s"
L["Zone: %s"]                               = "필터: 지역: %s"
L["Social Quest Window"]                    = "SocialQuest 창"
L["Auto-filter to current instance"]        = "현재 인스턴스로 자동 필터"
L["When inside a dungeon or raid instance, the Party and Shared tabs show only quests for that instance."] = "던전이나 레이드에 있을 때 '파티'와 '공유됨' 탭은 현재 인스턴스의 퀘스트만 표시합니다."
L["Auto-filter to current zone"]            = "현재 지역으로 자동 필터"
L["Outside of instances, the Party and Shared tabs show only quests for your current zone."] = "인스턴스 밖에서는 '파티'와 '공유됨' 탭이 현재 지역의 퀘스트만 표시합니다."

-- UI/GroupFrame.lua — search bar
L["Search..."]                               = "검색..."
L["Clear search"]                            = "검색 초기화"

-- Advanced filter language (Feature #18)
L["filter.key.zone"]         = "구역"
L["filter.key.zone.z"]=true
L["filter.key.zone.desc"]    = "구역 이름 (부분 일치)"
L["filter.key.title"]        = "제목"
L["filter.key.title.t"]=true
L["filter.key.title.desc"]   = "퀘스트 제목 (부분 일치)"
L["filter.key.chain"]        = "연쇄"
L["filter.key.chain.c"]=true
L["filter.key.chain.desc"]   = "연쇄 제목 (부분 일치)"
L["filter.key.player"]       = "플레이어"
L["filter.key.player.p"]=true
L["filter.key.player.desc"]  = "파티원 이름 (파티/공유 탭 전용)"
L["filter.key.level"]        = "레벨"
L["filter.key.level.lvl"]=true
L["filter.key.level.l"]=true
L["filter.key.level.desc"]   = "권장 퀘스트 레벨"
L["filter.key.step"]         = "단계"
L["filter.key.step.s"]=true
L["filter.key.step.desc"]    = "연쇄 단계 번호"
L["filter.key.group"]        = "그룹"
L["filter.key.group.g"]=true
L["filter.key.group.desc"]   = "그룹 요건 (예, 아니오, 2-5)"
L["filter.key.type"]         = "유형"
L["filter.key.type.desc"]    = "퀘스트 유형 — 연쇄, 그룹, 솔로, 시간제한, 호위, 던전, 공격대, 정예, 일일, pvp, 처치, 수집, 상호작용"
L["filter.key.status"]       = "상태"
L["filter.key.status.desc"]  = "퀘스트 상태 (완료, 미완료, 실패)"
L["filter.key.tracked"]      = "추적중"
L["filter.key.tracked.desc"] = "미니맵 추적 중 (예, 아니오; 내 탭 전용)"
L["filter.key.shareable"]=true
L["filter.key.shareable.desc"]=true
L["filter.val.yes"]          = "예"
L["filter.val.no"]           = "아니오"
L["filter.val.complete"]     = "완료"
L["filter.val.incomplete"]   = "미완료"
L["filter.val.failed"]       = "실패"
L["filter.val.chain"]        = "연쇄"
L["filter.val.group"]        = "그룹"
L["filter.val.solo"]         = "솔로"
L["filter.val.timed"]        = "시간제한"
L["filter.val.escort"]       = "호위"
L["filter.val.dungeon"]      = "던전"
L["filter.val.raid"]         = "공격대"
L["filter.val.elite"]        = "정예"
L["filter.val.daily"]        = "일일"
L["filter.val.pvp"]          = "pvp"
L["filter.val.kill"]         = "처치"
L["filter.val.gather"]       = "수집"
L["filter.val.interact"]     = "상호작용"
L["filter.err.UNKNOWN_KEY"]      = "알 수 없는 필터 키 '%s'"
L["filter.err.INVALID_OPERATOR"] = "연산자 '%s'은(는) '%s'에 사용할 수 없습니다"
L["filter.err.TYPE_MISMATCH"]    = "'%s'은(는) 숫자 필드가 필요합니다"
L["filter.err.UNCLOSED_QUOTE"]   = "필터 표현식에 닫히지 않은 따옴표가 있습니다"
L["filter.err.EMPTY_VALUE"]      = "'%s' 다음에 값이 없습니다"
L["filter.err.INVALID_NUMBER"]   = "'%s'에 숫자가 필요하지만 '%s'을(를) 받았습니다"
L["filter.err.RANGE_REVERSED"]   = "잘못된 범위: 최솟값 (%s)은 최댓값 (%s) 이하여야 합니다"
L["filter.err.INVALID_ENUM"]     = "'%s'은(는) '%s'에 유효한 값이 아닙니다"
L["filter.err.label"]            = "필터 오류: %s"
L["filter.err.MIXED_AND_OR"]=true
L["filter.err.AND_KEY_MISMATCH"]=true
L["filter.help.title"]                = "SQ 필터 구문"
L["filter.help.intro"]                = "필터 표현식을 입력하고 Enter를 눌러 고정 레이블로 적용합니다. [x]로 레이블을 닫습니다. 필터를 조합하려면 하나씩 입력하세요 — Enter를 누를 때마다 새 레이블이 추가됩니다(AND 조건)."
L["filter.help.section.syntax"]       = "구문"
L["filter.help.section.keys"]         = "지원되는 키"
L["filter.help.section.examples"]     = "예시"
L["filter.help.col.key"]              = "키"
L["filter.help.col.aliases"]          = "별칭"
L["filter.help.col.desc"]             = "설명"
L["filter.help.example.1"]            = "레벨>=60"
L["filter.help.example.1.note"]       = "레벨 60 이상의 퀘스트 표시"
L["filter.help.example.2"]            = "레벨=58..62"
L["filter.help.example.2.note"]       = "레벨 58-62 범위의 퀘스트 표시"
L["filter.help.example.3"]            = "구역=엘윈|죽음의"
L["filter.help.example.3.note"]       = "엘윈 숲 또는 죽음의 광산의 퀘스트 표시"
L["filter.help.example.4"]            = "상태=미완료"
L["filter.help.example.4.note"]       = "미완료 퀘스트만 표시"
L["filter.help.example.5"]            = "유형=연쇄"
L["filter.help.example.5.note"]       = "연쇄 퀘스트만 표시"
L["filter.help.example.6"]            = "구역=\"지옥불 반도\""
L["filter.help.example.6.note"]       = "따옴표로 묶인 값 (값에 공백이 있을 때 사용)"
L["filter.help.type.note"]            = "처치, 수집, 상호작용은 해당 종류의 목표가 하나 이상 있는 퀘스트와 일치합니다 — 퀘스트는 여러 유형에 해당할 수 있습니다. 유형 필터는 Questie 또는 Quest Weaver 애드온이 필요합니다."
L["filter.help.example.7"]            = "유형=던전"
L["filter.help.example.7.note"]       = "던전 퀘스트만 표시 (Questie 또는 Quest Weaver 필요)"
L["filter.help.example.8"]            = "유형=처치"
L["filter.help.example.8.note"]       = "처치 목표가 하나 이상 있는 퀘스트 표시"
L["filter.help.example.9"]            = "유형=일일"
L["filter.help.example.9.note"]       = "일일 퀘스트만 표시"
L["filter.help.example.10"]           = "추적중=예"
L["filter.help.example.10.note"]      = "추적 중인 퀘스트만 표시 (내 퀘스트 탭 전용)"
L["filter.help.example.11"]           = "그룹=아니오"
L["filter.help.example.11.note"]      = "솔로 퀘스트만 표시 (그룹 불필요)"
L["filter.help.example.12"]=true
L["filter.help.example.12.note"]=true
L["filter.help.example.13"]=true
L["filter.help.example.13.note"]=true
L["filter.help.example.14"]=true
L["filter.help.example.14.note"]=true
L["filter.help.example.15"]=true
L["filter.help.example.15.note"]=true

-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "공유"
L["share.tooltip"] = "이 퀘스트를 파티원과 공유합니다"
L["share.reason.level_too_low"]    = "레벨 부족"
L["share.reason.level_too_high"]   = "레벨 초과"
L["share.reason.wrong_race"]       = "종족 불일치"
L["share.reason.wrong_class"]      = "직업 불일치"
L["share.reason.quest_log_full"]   = "퀘스트 수첩 가득 참"
L["share.reason.exclusive_quest"]  = "독점 퀘스트 수락"
L["share.reason.already_advanced"] = "이미 다음 단계 진행 중"
