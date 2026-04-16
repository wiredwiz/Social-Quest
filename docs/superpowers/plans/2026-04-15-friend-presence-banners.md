# Friend Presence Banners Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display banner notifications when a WoW friend logs in or out, using SocialQuest's existing banner system, handling both BattleTag friends (via BN events) and traditional character-name friends (via FRIENDLIST_UPDATE diffing).

**Architecture:** A new `Core/FriendPresence.lua` module owns all presence-tracking state and event logic. `SocialQuest.lua` registers the three new WoW events and delegates to `FriendPresence`. `Core/Announcements.lua` gets two new display methods that call `displayBanner`. All BN API calls route through `Core/WowAPI.lua` wrappers. Traditional friends who are also in the BattleTag list are deduplicated so only one banner fires.

**Tech Stack:** WoW Lua 5.1, Ace3 (AceDB, AceConfig, AceLocale), `C_BattleNet.GetFriendAccountInfo` (primary BN API, confirmed available on all supported versions), `BNGetFriendInfo` (fallback), `C_FriendList.GetFriendInfoByIndex` (traditional friends).

---

## File Map

| Action | File |
|---|---|
| Create | `Core/FriendPresence.lua` |
| Modify | `SocialQuest.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`, `SocialQuest_Mainline.toc` |
| Modify | `Util/Colors.lua` |
| Modify | `Core/WowAPI.lua` |
| Modify | `Core/Announcements.lua` |
| Modify | `SocialQuest.lua` |
| Modify | `UI/Options.lua` |
| Modify | `Locales/enUS.lua` (+ 11 others) |

---

### Task 1: Add color keys to Colors.lua

**Files:**
- Modify: `Util/Colors.lua`

- [ ] **Step 1: Open `Util/Colors.lua` and read the existing `event` and `eventCB` tables**

The file is at `Util/Colors.lua`. The `event` table (lines ~19–28) holds normal-mode colors; `eventCB` (lines ~31–40) holds colorblind-mode colors. Both need two new entries.

- [ ] **Step 2: Add `friend_online` and `friend_offline` to `SocialQuestColors.event`**

In `SocialQuestColors.event`, after the `follow` entry, add:

```lua
    friend_online  = { r = 0,     g = 0.867, b = 0.267 },  -- medium green  (#00DD44)
    friend_offline = { r = 0.533, g = 0.533, b = 0.533 },  -- grey          (#888888)
```

- [ ] **Step 3: Add `friend_online` and `friend_offline` to `SocialQuestColors.eventCB`**

In `SocialQuestColors.eventCB`, after the `follow` entry, add:

```lua
    friend_online  = { r = 0,     g = 0.620, b = 0.451 },  -- Okabe-Ito teal  (#009E73)
    friend_offline = { r = 0.533, g = 0.533, b = 0.533 },  -- grey (unchanged; universally distinguishable)
```

- [ ] **Step 4: Commit**

```
git add Util/Colors.lua
git commit -m "feat: add friend_online and friend_offline color keys"
```

---

### Task 2: Add BN API wrappers to Core/WowAPI.lua

**Files:**
- Modify: `Core/WowAPI.lua`

- [ ] **Step 1: Read `Core/WowAPI.lua`**

The existing wrappers for `C_FriendList` are at lines ~47–49. The new BN wrappers go after those, before the `TimerAfter` wrapper.

- [ ] **Step 2: Add the three BN wrappers**

After `SocialQuestWowAPI.GetFriendInfoByIndex`, add:

```lua
function SocialQuestWowAPI.BNGetNumFriends()
    if BNGetNumFriends then return BNGetNumFriends() end
    return 0
end

-- Returns a normalized table for one BN friend by 1-based index.
-- Tries C_BattleNet.GetFriendAccountInfo first (confirmed available on all
-- supported versions). Falls back to positional BNGetFriendInfo returns.
-- Returns nil if neither API is available or the index is out of range.
function SocialQuestWowAPI.BNGetFriendInfoByIndex(index)
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local info = C_BattleNet.GetFriendAccountInfo(index)
        if info then
            local ga = info.gameAccountInfo
            return {
                battleTagName = info.accountName,
                charName      = ga and ga.characterName,
                level         = ga and ga.characterLevel,
                className     = ga and ga.className,
                clientProgram = ga and ga.clientProgram,
                bnetIDAccount = info.bnetAccountID,
                isOnline      = info.isOnline,
            }
        end
    end
    if BNGetFriendInfo then
        -- Positional returns: presenceName, battleTag, isBTPresence, toonName,
        -- toonID, client, isOnline, lastOnline, isAFK, isDND, ...
        local presenceName, battleTag, _, toonName, _, client, isOnline = BNGetFriendInfo(index)
        if presenceName then
            return {
                battleTagName = battleTag or presenceName,
                charName      = toonName,
                level         = nil,  -- not exposed by this API form
                className     = nil,
                clientProgram = client,
                bnetIDAccount = nil,  -- not directly available
                isOnline      = isOnline,
            }
        end
    end
    return nil
end

-- Finds a BN friend by their persistent bnetIDAccount value.
-- Iterates by index; no direct by-ID API is guaranteed on all versions.
-- Returns the same normalized table as BNGetFriendInfoByIndex, or nil.
function SocialQuestWowAPI.BNGetFriendInfoByID(bnetIDAccount)
    local n = SocialQuestWowAPI.BNGetNumFriends()
    for i = 1, n do
        local info = SocialQuestWowAPI.BNGetFriendInfoByIndex(i)
        if info and info.bnetIDAccount == bnetIDAccount then
            return info
        end
    end
    return nil
end
```

- [ ] **Step 3: Run existing tests to confirm no regressions**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both print 0 failures.

- [ ] **Step 4: Commit**

```
git add Core/WowAPI.lua
git commit -m "feat: add BN friend API wrappers to WowAPI"
```

---

### Task 3: Add locale strings to all 12 locale files

**Files:**
- Modify: `Locales/enUS.lua`, `Locales/deDE.lua`, `Locales/frFR.lua`, `Locales/esES.lua`, `Locales/esMX.lua`, `Locales/zhCN.lua`, `Locales/zhTW.lua`, `Locales/ptBR.lua`, `Locales/itIT.lua`, `Locales/koKR.lua`, `Locales/ruRU.lua`, `Locales/jaJP.lua`

There are 15 new locale keys. Add them to each file in the section that follows the follow-notifications strings. The enUS values are all `= true`. All other locales use natural, WoW-appropriate phrasing — not literal translations. Do NOT use a dictionary; use the same terminology WoW's own UI uses in each language.

- [ ] **Step 1: Add keys to `Locales/enUS.lua`**

After the follow-notifications section (after `L["Display a demo follow notification banner showing the 'started following you' message."] = true`), add:

```lua
-- Core/Announcements.lua — friend presence banners
-- %s = character description ("CharName Level Class") or just "CharName"
L["%s Online"]                              = true
L["%s Offline"]                             = true
-- BattleTag friend variant: %s1 = BattleTag display name (before #), %s2 = charDesc
L["%s (%s) Online"]                         = true
L["%s (%s) Offline"]                        = true

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = true
L["Enable friend notifications"]            = true
L["Show a banner when a friend logs into or out of WoW."] = true
L["Show online banners"]                    = true
L["Show a banner when a friend logs into WoW."] = true
L["Show offline banners"]                   = true
L["Show a banner when a friend logs out of WoW."] = true

-- UI/Options.lua — friend presence test buttons (debug section)
L["Test Friend Online"]                     = true
L["Display a demo friend online banner."]   = true
L["Test Friend Offline"]                    = true
L["Display a demo friend offline banner."]  = true
```

- [ ] **Step 2: Add keys to `Locales/deDE.lua`**

After the follow-notifications section, add:

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s ist jetzt online"
L["%s Offline"]                             = "%s ist jetzt offline"
L["%s (%s) Online"]                         = "%s (%s) ist jetzt online"
L["%s (%s) Offline"]                        = "%s (%s) ist jetzt offline"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Freundesbenachrichtigungen"
L["Enable friend notifications"]            = "Freundesbenachrichtigungen aktivieren"
L["Show a banner when a friend logs into or out of WoW."] = "Zeigt einen Banner an, wenn ein Freund sich in WoW an- oder abmeldet."
L["Show online banners"]                    = "Online-Banner anzeigen"
L["Show a banner when a friend logs into WoW."] = "Zeigt einen Banner an, wenn ein Freund sich in WoW anmeldet."
L["Show offline banners"]                   = "Offline-Banner anzeigen"
L["Show a banner when a friend logs out of WoW."] = "Zeigt einen Banner an, wenn ein Freund sich von WoW abmeldet."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Freund online testen"
L["Display a demo friend online banner."]   = "Zeigt einen Demo-Banner für 'Freund online' an."
L["Test Friend Offline"]                    = "Freund offline testen"
L["Display a demo friend offline banner."]  = "Zeigt einen Demo-Banner für 'Freund offline' an."
```

- [ ] **Step 3: Add keys to `Locales/frFR.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s est maintenant en ligne"
L["%s Offline"]                             = "%s est maintenant hors ligne"
L["%s (%s) Online"]                         = "%s (%s) est maintenant en ligne"
L["%s (%s) Offline"]                        = "%s (%s) est maintenant hors ligne"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Notifications d'amis"
L["Enable friend notifications"]            = "Activer les notifications d'amis"
L["Show a banner when a friend logs into or out of WoW."] = "Affiche une bannière quand un ami se connecte ou se déconnecte de WoW."
L["Show online banners"]                    = "Afficher les bannières de connexion"
L["Show a banner when a friend logs into WoW."] = "Affiche une bannière quand un ami se connecte à WoW."
L["Show offline banners"]                   = "Afficher les bannières de déconnexion"
L["Show a banner when a friend logs out of WoW."] = "Affiche une bannière quand un ami se déconnecte de WoW."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Tester ami en ligne"
L["Display a demo friend online banner."]   = "Affiche une bannière de démonstration 'ami en ligne'."
L["Test Friend Offline"]                    = "Tester ami hors ligne"
L["Display a demo friend offline banner."]  = "Affiche une bannière de démonstration 'ami hors ligne'."
```

- [ ] **Step 4: Add keys to `Locales/esES.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s está en línea"
L["%s Offline"]                             = "%s se ha desconectado"
L["%s (%s) Online"]                         = "%s (%s) está en línea"
L["%s (%s) Offline"]                        = "%s (%s) se ha desconectado"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Notificaciones de amigos"
L["Enable friend notifications"]            = "Activar notificaciones de amigos"
L["Show a banner when a friend logs into or out of WoW."] = "Muestra un aviso cuando un amigo inicia o cierra sesión en WoW."
L["Show online banners"]                    = "Mostrar avisos de conexión"
L["Show a banner when a friend logs into WoW."] = "Muestra un aviso cuando un amigo inicia sesión en WoW."
L["Show offline banners"]                   = "Mostrar avisos de desconexión"
L["Show a banner when a friend logs out of WoW."] = "Muestra un aviso cuando un amigo cierra sesión en WoW."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Probar amigo en línea"
L["Display a demo friend online banner."]   = "Muestra un aviso de demostración de 'amigo en línea'."
L["Test Friend Offline"]                    = "Probar amigo desconectado"
L["Display a demo friend offline banner."]  = "Muestra un aviso de demostración de 'amigo desconectado'."
```

- [ ] **Step 5: Add keys to `Locales/esMX.lua`**

esMX is identical to esES for these strings:

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s está en línea"
L["%s Offline"]                             = "%s se ha desconectado"
L["%s (%s) Online"]                         = "%s (%s) está en línea"
L["%s (%s) Offline"]                        = "%s (%s) se ha desconectado"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Notificaciones de amigos"
L["Enable friend notifications"]            = "Activar notificaciones de amigos"
L["Show a banner when a friend logs into or out of WoW."] = "Muestra un aviso cuando un amigo inicia o cierra sesión en WoW."
L["Show online banners"]                    = "Mostrar avisos de conexión"
L["Show a banner when a friend logs into WoW."] = "Muestra un aviso cuando un amigo inicia sesión en WoW."
L["Show offline banners"]                   = "Mostrar avisos de desconexión"
L["Show a banner when a friend logs out of WoW."] = "Muestra un aviso cuando un amigo cierra sesión en WoW."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Probar amigo en línea"
L["Display a demo friend online banner."]   = "Muestra un aviso de demostración de 'amigo en línea'."
L["Test Friend Offline"]                    = "Probar amigo desconectado"
L["Display a demo friend offline banner."]  = "Muestra un aviso de demostración de 'amigo desconectado'."
```

- [ ] **Step 6: Add keys to `Locales/zhCN.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s 上线了"
L["%s Offline"]                             = "%s 下线了"
L["%s (%s) Online"]                         = "%s (%s) 上线了"
L["%s (%s) Offline"]                        = "%s (%s) 下线了"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "好友通知"
L["Enable friend notifications"]            = "启用好友通知"
L["Show a banner when a friend logs into or out of WoW."] = "当好友登录或退出《魔兽世界》时显示横幅提醒。"
L["Show online banners"]                    = "显示上线提醒"
L["Show a banner when a friend logs into WoW."] = "当好友登录《魔兽世界》时显示横幅提醒。"
L["Show offline banners"]                   = "显示下线提醒"
L["Show a banner when a friend logs out of WoW."] = "当好友退出《魔兽世界》时显示横幅提醒。"

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "测试好友上线"
L["Display a demo friend online banner."]   = "显示好友上线的演示横幅。"
L["Test Friend Offline"]                    = "测试好友下线"
L["Display a demo friend offline banner."]  = "显示好友下线的演示横幅。"
```

- [ ] **Step 7: Add keys to `Locales/zhTW.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s 上線了"
L["%s Offline"]                             = "%s 下線了"
L["%s (%s) Online"]                         = "%s (%s) 上線了"
L["%s (%s) Offline"]                        = "%s (%s) 下線了"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "好友通知"
L["Enable friend notifications"]            = "啟用好友通知"
L["Show a banner when a friend logs into or out of WoW."] = "當好友登入或登出《魔獸世界》時顯示橫幅提醒。"
L["Show online banners"]                    = "顯示上線提醒"
L["Show a banner when a friend logs into WoW."] = "當好友登入《魔獸世界》時顯示橫幅提醒。"
L["Show offline banners"]                   = "顯示下線提醒"
L["Show a banner when a friend logs out of WoW."] = "當好友登出《魔獸世界》時顯示橫幅提醒。"

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "測試好友上線"
L["Display a demo friend online banner."]   = "顯示好友上線的示範橫幅。"
L["Test Friend Offline"]                    = "測試好友下線"
L["Display a demo friend offline banner."]  = "顯示好友下線的示範橫幅。"
```

- [ ] **Step 8: Add keys to `Locales/ptBR.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s está online"
L["%s Offline"]                             = "%s ficou offline"
L["%s (%s) Online"]                         = "%s (%s) está online"
L["%s (%s) Offline"]                        = "%s (%s) ficou offline"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Notificações de amigos"
L["Enable friend notifications"]            = "Ativar notificações de amigos"
L["Show a banner when a friend logs into or out of WoW."] = "Exibe um aviso quando um amigo entra ou sai de WoW."
L["Show online banners"]                    = "Mostrar avisos de entrada"
L["Show a banner when a friend logs into WoW."] = "Exibe um aviso quando um amigo entra em WoW."
L["Show offline banners"]                   = "Mostrar avisos de saída"
L["Show a banner when a friend logs out of WoW."] = "Exibe um aviso quando um amigo sai de WoW."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Testar amigo online"
L["Display a demo friend online banner."]   = "Exibe um aviso de demonstração de 'amigo online'."
L["Test Friend Offline"]                    = "Testar amigo offline"
L["Display a demo friend offline banner."]  = "Exibe um aviso de demonstração de 'amigo offline'."
```

- [ ] **Step 9: Add keys to `Locales/itIT.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s è ora online"
L["%s Offline"]                             = "%s è ora offline"
L["%s (%s) Online"]                         = "%s (%s) è ora online"
L["%s (%s) Offline"]                        = "%s (%s) è ora offline"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Notifiche amici"
L["Enable friend notifications"]            = "Abilita notifiche amici"
L["Show a banner when a friend logs into or out of WoW."] = "Mostra un avviso quando un amico entra o esce da WoW."
L["Show online banners"]                    = "Mostra avvisi di accesso"
L["Show a banner when a friend logs into WoW."] = "Mostra un avviso quando un amico entra in WoW."
L["Show offline banners"]                   = "Mostra avvisi di uscita"
L["Show a banner when a friend logs out of WoW."] = "Mostra un avviso quando un amico esce da WoW."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Testa amico online"
L["Display a demo friend online banner."]   = "Mostra un avviso dimostrativo 'amico online'."
L["Test Friend Offline"]                    = "Testa amico offline"
L["Display a demo friend offline banner."]  = "Mostra un avviso dimostrativo 'amico offline'."
```

- [ ] **Step 10: Add keys to `Locales/koKR.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s 접속했습니다"
L["%s Offline"]                             = "%s 접속을 종료했습니다"
L["%s (%s) Online"]                         = "%s (%s) 접속했습니다"
L["%s (%s) Offline"]                        = "%s (%s) 접속을 종료했습니다"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "친구 알림"
L["Enable friend notifications"]            = "친구 알림 활성화"
L["Show a banner when a friend logs into or out of WoW."] = "친구가 WoW에 접속하거나 종료할 때 알림 표시."
L["Show online banners"]                    = "접속 알림 표시"
L["Show a banner when a friend logs into WoW."] = "친구가 WoW에 접속할 때 알림 표시."
L["Show offline banners"]                   = "종료 알림 표시"
L["Show a banner when a friend logs out of WoW."] = "친구가 WoW를 종료할 때 알림 표시."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "친구 접속 테스트"
L["Display a demo friend online banner."]   = "친구 접속 데모 알림 표시."
L["Test Friend Offline"]                    = "친구 종료 테스트"
L["Display a demo friend offline banner."]  = "친구 종료 데모 알림 표시."
```

- [ ] **Step 11: Add keys to `Locales/ruRU.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s вошёл в игру"
L["%s Offline"]                             = "%s вышел из игры"
L["%s (%s) Online"]                         = "%s (%s) вошёл в игру"
L["%s (%s) Offline"]                        = "%s (%s) вышел из игры"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "Уведомления о друзьях"
L["Enable friend notifications"]            = "Включить уведомления о друзьях"
L["Show a banner when a friend logs into or out of WoW."] = "Показывать уведомление, когда друг входит или выходит из WoW."
L["Show online banners"]                    = "Показывать уведомления о входе"
L["Show a banner when a friend logs into WoW."] = "Показывать уведомление, когда друг входит в WoW."
L["Show offline banners"]                   = "Показывать уведомления о выходе"
L["Show a banner when a friend logs out of WoW."] = "Показывать уведомление, когда друг выходит из WoW."

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "Тест входа друга"
L["Display a demo friend online banner."]   = "Показать демонстрационное уведомление о входе друга."
L["Test Friend Offline"]                    = "Тест выхода друга"
L["Display a demo friend offline banner."]  = "Показать демонстрационное уведомление о выходе друга."
```

- [ ] **Step 12: Add keys to `Locales/jaJP.lua`**

```lua
-- Core/Announcements.lua — friend presence banners
L["%s Online"]                              = "%s がオンラインになりました"
L["%s Offline"]                             = "%s がオフラインになりました"
L["%s (%s) Online"]                         = "%s (%s) がオンラインになりました"
L["%s (%s) Offline"]                        = "%s (%s) がオフラインになりました"

-- UI/Options.lua — Friend Notifications section
L["Friend Notifications"]                   = "フレンド通知"
L["Enable friend notifications"]            = "フレンド通知を有効にする"
L["Show a banner when a friend logs into or out of WoW."] = "フレンドがWoWにログインまたはログアウトしたときにバナーを表示します。"
L["Show online banners"]                    = "ログイン通知を表示"
L["Show a banner when a friend logs into WoW."] = "フレンドがWoWにログインしたときにバナーを表示します。"
L["Show offline banners"]                   = "ログアウト通知を表示"
L["Show a banner when a friend logs out of WoW."] = "フレンドがWoWからログアウトしたときにバナーを表示します。"

-- UI/Options.lua — friend presence test buttons
L["Test Friend Online"]                     = "フレンドログインテスト"
L["Display a demo friend online banner."]   = "フレンドログインのデモバナーを表示します。"
L["Test Friend Offline"]                    = "フレンドログアウトテスト"
L["Display a demo friend offline banner."]  = "フレンドログアウトのデモバナーを表示します。"
```

- [ ] **Step 13: Commit all locale changes**

```
git add Locales/
git commit -m "feat: add friend presence locale strings to all 12 locales"
```

---

### Task 4: Create Core/FriendPresence.lua and register in TOC files

**Files:**
- Create: `Core/FriendPresence.lua`
- Modify: `SocialQuest.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`, `SocialQuest_Mainline.toc`

- [ ] **Step 1: Create `Core/FriendPresence.lua` with the full implementation**

```lua
-- Core/FriendPresence.lua
-- Tracks Battle.net and traditional WoW friend presence.
-- Fires banner notifications via SocialQuestAnnounce when friends log
-- into or out of WoW.
--
-- Public interface:
--   SocialQuestFriendPresence:Initialize()          — call from OnPlayerEnteringWorld
--   SocialQuestFriendPresence:OnBnFriendOnline(id)  — delegate from SocialQuest
--   SocialQuestFriendPresence:OnBnFriendOffline(id) — delegate from SocialQuest
--   SocialQuestFriendPresence:OnFriendListUpdate()  — delegate from SocialQuest

SocialQuestFriendPresence = {}

local SQWowAPI   = SocialQuestWowAPI
local SQAnnounce = nil  -- resolved in Initialize() to avoid load-order dependency

-- { [charName] = { level=N, class="ClassName" } }
-- Traditional friends currently shown as connected.
-- Stores level/class so they are available when the friend goes offline and
-- GetFriendInfoByIndex no longer returns them.
local knownFriends = {}

-- { [bnetIDAccount] = { displayName="Joe", charName="X", level=N, className="Y" } }
-- BattleTag friends for whom we showed an online (WoW) banner this session.
-- Table value (not just true) caches info for the offline banner because
-- BNGetFriendInfoByID may return nil once the friend has disconnected.
local bnShownOnline = {}

-- { [charName] = true }
-- Character names of BattleTag friends currently in WoW.
-- Used by OnFriendListUpdate to skip traditional-list entries that BN already handles.
local bnCharNames = {}

local initialized = false

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- Strips the "#NNNN" suffix from a BattleTag, returning just the display
-- name. "Joe#1234" -> "Joe". Returns nil if input is nil.
local function stripBattleTagSuffix(battleTagName)
    if not battleTagName then return nil end
    return battleTagName:match("^([^#]+)") or battleTagName
end

-- Returns the BNET_CLIENT_WOW constant value, which varies between client
-- versions. Falls back to the string "WoW" used on most classic builds.
local function wowClientToken()
    return BNET_CLIENT_WOW or "WoW"
end

-- Rebuilds bnCharNames from the current live BN friend list.
-- Called at Initialize() time and at the start of OnFriendListUpdate()
-- to keep the dedup set current.
local function rebuildBnCharNames()
    wipe(bnCharNames)
    local n = SQWowAPI.BNGetNumFriends()
    for i = 1, n do
        local info = SQWowAPI.BNGetFriendInfoByIndex(i)
        if info and info.isOnline and info.charName
                and info.clientProgram == wowClientToken() then
            bnCharNames[info.charName] = true
        end
    end
end

------------------------------------------------------------------------
-- Public methods
------------------------------------------------------------------------

-- Called from SocialQuest:OnPlayerEnteringWorld.
-- Resets all state and populates snapshots silently (no banners fire).
-- Safe to call multiple times — each call replaces the previous snapshot.
function SocialQuestFriendPresence:Initialize()
    SQAnnounce = SocialQuestAnnounce  -- both modules are loaded by this point

    wipe(knownFriends)
    wipe(bnShownOnline)
    wipe(bnCharNames)
    initialized = false

    -- Build the initial traditional-friends snapshot without firing banners.
    local n = SQWowAPI.GetNumFriends()
    for i = 1, n do
        local info = SQWowAPI.GetFriendInfoByIndex(i)
        if info and info.connected then
            knownFriends[info.name] = { level = info.level, class = info.class }
        end
    end

    -- Build the initial BN character name set without firing banners.
    rebuildBnCharNames()

    initialized = true
end

-- Fires when a BattleTag friend's Battle.net account comes online.
-- arg: bnetIDAccount — the persistent account ID passed by the WoW event.
function SocialQuestFriendPresence:OnBnFriendOnline(bnetIDAccount)
    if not initialized then return end
    local db = SocialQuest.db.profile
    if not db.friendPresence.enabled   then return end
    if not db.friendPresence.showOnline then return end

    local info = SQWowAPI.BNGetFriendInfoByID(bnetIDAccount)
    if not info then return end
    -- Only fire for WoW sessions, not Diablo/Overwatch/etc.
    if info.clientProgram ~= wowClientToken() then return end

    local displayName = stripBattleTagSuffix(info.battleTagName)
    local charName    = info.charName or displayName or ""
    local level       = info.level
    local className   = info.className

    -- Update bnCharNames immediately so OnFriendListUpdate doesn't double-fire.
    if charName ~= "" then
        bnCharNames[charName] = true
    end

    -- Cache display data for the offline event — BNGetFriendInfoByID may
    -- return nil once the friend has fully disconnected.
    bnShownOnline[bnetIDAccount] = {
        displayName = displayName,
        charName    = charName,
        level       = level,
        className   = className,
    }

    SQAnnounce:OnFriendOnline(displayName, charName, level, className)
end

-- Fires when a BattleTag friend's Battle.net account goes offline.
-- arg: bnetIDAccount — the persistent account ID passed by the WoW event.
function SocialQuestFriendPresence:OnBnFriendOffline(bnetIDAccount)
    if not initialized then return end
    local db = SocialQuest.db.profile
    if not db.friendPresence.enabled    then return end
    if not db.friendPresence.showOffline then return end

    -- Only fire if we showed an online (WoW) banner for this account this session.
    local cached = bnShownOnline[bnetIDAccount]
    if not cached then return end

    -- Clean up tracking tables.
    bnShownOnline[bnetIDAccount] = nil
    if cached.charName and cached.charName ~= "" then
        bnCharNames[cached.charName] = nil
    end

    -- Use cached data — BNGetFriendInfoByID returns nil at this point.
    SQAnnounce:OnFriendOffline(cached.displayName, cached.charName, cached.level, cached.className)
end

-- Fires on every FRIENDLIST_UPDATE event.
-- Diffs the current traditional-friend connected list against the last known
-- snapshot to detect logins and logouts.
function SocialQuestFriendPresence:OnFriendListUpdate()
    if not initialized then return end
    local db = SocialQuest.db.profile
    if not db.friendPresence.enabled then return end

    -- Refresh bnCharNames so the dedup check uses current state.
    rebuildBnCharNames()

    -- Build the current connected set from the live friend list.
    local currentFriends = {}
    local n = SQWowAPI.GetNumFriends()
    for i = 1, n do
        local info = SQWowAPI.GetFriendInfoByIndex(i)
        if info and info.connected then
            currentFriends[info.name] = { level = info.level, class = info.class }
        end
    end

    -- Newly online: in currentFriends but not in knownFriends.
    -- Skip names handled by the BN path to prevent double banners.
    if db.friendPresence.showOnline then
        for name, info in pairs(currentFriends) do
            if not knownFriends[name] and not bnCharNames[name] then
                SQAnnounce:OnFriendOnline(nil, name, info.level, info.class)
            end
        end
    end

    -- Newly offline: in knownFriends but not in currentFriends.
    -- Use cached level/class from knownFriends since the friend is already gone.
    if db.friendPresence.showOffline then
        for name, cached in pairs(knownFriends) do
            if not currentFriends[name] and not bnCharNames[name] then
                SQAnnounce:OnFriendOffline(nil, name, cached.level, cached.class)
            end
        end
    end

    -- Replace the snapshot with current state.
    wipe(knownFriends)
    for name, info in pairs(currentFriends) do
        knownFriends[name] = info
    end
end
```

- [ ] **Step 2: Register `Core/FriendPresence.lua` in all four TOC files**

In `SocialQuest.toc`, after `Core/Announcements.lua`:

```
Core\FriendPresence.lua
```

Apply the same change in `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`, and `SocialQuest_Mainline.toc`.

- [ ] **Step 3: Run existing tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both print 0 failures.

- [ ] **Step 4: Commit**

```
git add Core/FriendPresence.lua SocialQuest.toc SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc
git commit -m "feat: add FriendPresence module for friend login/logout tracking"
```

---

### Task 5: Add display methods to Core/Announcements.lua

**Files:**
- Modify: `Core/Announcements.lua`

- [ ] **Step 1: Read the end of `Core/Announcements.lua` to find the right insertion point**

The follow-notifications section ends around line 806 with `TestFollowNotification`. The new methods go after that, before the `WhisperFriends` helper section.

- [ ] **Step 2: Add the four new methods after `TestFollowNotification`**

```lua
------------------------------------------------------------------------
-- Friend presence notifications
------------------------------------------------------------------------

-- Called by FriendPresence when a friend logs into WoW.
-- battleTagName: BattleTag display name (e.g. "Joe"), or nil for traditional friends.
-- charName: character name. level, className: may be nil (graceful degradation).
function SocialQuestAnnounce:OnFriendOnline(battleTagName, charName, level, className)
    local charDesc = (level and className)
        and (charName .. " " .. tostring(level) .. " " .. className)
        or  (charName or "")
    local msg = battleTagName
        and string.format(L["%s (%s) Online"], battleTagName, charDesc)
        or  string.format(L["%s Online"], charDesc)
    displayBanner(msg, "friend_online")
end

-- Called by FriendPresence when a friend logs out of WoW.
function SocialQuestAnnounce:OnFriendOffline(battleTagName, charName, level, className)
    local charDesc = (level and className)
        and (charName .. " " .. tostring(level) .. " " .. className)
        or  (charName or "")
    local msg = battleTagName
        and string.format(L["%s (%s) Offline"], battleTagName, charDesc)
        or  string.format(L["%s Offline"], charDesc)
    displayBanner(msg, "friend_offline")
end

-- Debug test buttons — bypass all config gates.
function SocialQuestAnnounce:TestFriendOnline()
    local name  = SQWowAPI.UnitName("player") or "TestPlayer"
    local level = UnitLevel("player") or 60
    self:OnFriendOnline("TestBattleTag", name, level, "Warrior")
end

function SocialQuestAnnounce:TestFriendOffline()
    local name  = SQWowAPI.UnitName("player") or "TestPlayer"
    local level = UnitLevel("player") or 60
    self:OnFriendOffline("TestBattleTag", name, level, "Warrior")
end
```

- [ ] **Step 3: Run existing tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both print 0 failures.

- [ ] **Step 4: Commit**

```
git add Core/Announcements.lua
git commit -m "feat: add OnFriendOnline/Offline display methods to Announcements"
```

---

### Task 6: Wire events and defaults in SocialQuest.lua

**Files:**
- Modify: `SocialQuest.lua`

- [ ] **Step 1: Add `friendPresence` to the AceDB profile defaults**

Read `SocialQuest.lua` around line 309 where `follow = { ... }` is defined. After the `follow` sub-table and before `debug`, add:

```lua
            friendPresence = {
                enabled     = true,
                showOnline  = true,
                showOffline = true,
            },
```

- [ ] **Step 2: Register the three new events in `OnEnable`**

In `OnEnable`, after the existing `self:RegisterEvent("PLAYER_LEAVING_WORLD", ...)` line, add:

```lua
    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE",  "OnBnFriendOnline")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE", "OnBnFriendOffline")
    self:RegisterEvent("FRIENDLIST_UPDATE",          "OnFriendListUpdate")
```

- [ ] **Step 3: Add the three event handler methods**

After `SocialQuest:OnAutoFollowEnd` (around line 450), add:

```lua
function SocialQuest:OnBnFriendOnline(event, bnetIDAccount)
    SocialQuestFriendPresence:OnBnFriendOnline(bnetIDAccount)
end

function SocialQuest:OnBnFriendOffline(event, bnetIDAccount)
    SocialQuestFriendPresence:OnBnFriendOffline(bnetIDAccount)
end

function SocialQuest:OnFriendListUpdate()
    SocialQuestFriendPresence:OnFriendListUpdate()
end
```

- [ ] **Step 4: Call `FriendPresence:Initialize()` from `OnPlayerEnteringWorld`**

At the end of `SocialQuest:OnPlayerEnteringWorld`, after the existing `SQWowAPI.TimerAfter(5, ...)` block, add:

```lua
    SocialQuestFriendPresence:Initialize()
```

- [ ] **Step 5: Run existing tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both print 0 failures.

- [ ] **Step 6: Commit**

```
git add SocialQuest.lua
git commit -m "feat: wire FriendPresence events and AceDB defaults"
```

---

### Task 7: Add Friend Notifications section to Options.lua

**Files:**
- Modify: `UI/Options.lua`

- [ ] **Step 1: Read the `follow` group in `UI/Options.lua` (around line 292)**

The `follow` group is at `order = 7`. The `window` group is at `order = 9`. We insert `friendPresence` at `order = 8`.

- [ ] **Step 2: Add the `friendPresence` group after the `follow` group closing brace**

After the closing `},` of the `follow` group and before the `window` group, insert:

```lua
            friendPresence = {
                type  = "group",
                name  = L["Friend Notifications"],
                order = 8,
                args  = {
                    enabled = toggle(
                        L["Enable friend notifications"],
                        L["Show a banner when a friend logs into or out of WoW."],
                        { "friendPresence", "enabled" }
                    ),
                    showOnline = {
                        type    = "toggle",
                        name    = L["Show online banners"],
                        desc    = L["Show a banner when a friend logs into WoW."],
                        get     = function() return db.friendPresence.showOnline end,
                        set     = function(_, v) db.friendPresence.showOnline = v end,
                        disabled = function() return not db.friendPresence.enabled end,
                    },
                    showOffline = {
                        type    = "toggle",
                        name    = L["Show offline banners"],
                        desc    = L["Show a banner when a friend logs out of WoW."],
                        get     = function() return db.friendPresence.showOffline end,
                        set     = function(_, v) db.friendPresence.showOffline = v end,
                        disabled = function() return not db.friendPresence.enabled end,
                    },
                },
            },
```

- [ ] **Step 3: Add two test buttons to the debug `testBanners` group**

Read the `testBanners` group (around line 414). After the existing `testFollowNotification` entry inside `testBanners.args`, add:

```lua
                            testFriendOnline = {
                                type = "execute",
                                name = L["Test Friend Online"],
                                desc = L["Display a demo friend online banner."],
                                func = function() SocialQuestAnnounce:TestFriendOnline() end,
                            },
                            testFriendOffline = {
                                type = "execute",
                                name = L["Test Friend Offline"],
                                desc = L["Display a demo friend offline banner."],
                                func = function() SocialQuestAnnounce:TestFriendOffline() end,
                            },
```

- [ ] **Step 4: Run existing tests**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both print 0 failures.

- [ ] **Step 5: Commit**

```
git add UI/Options.lua
git commit -m "feat: add Friend Notifications config section and debug test buttons"
```

---

### Task 8: Version bump, CLAUDE.md, and final verification

**Files:**
- Modify: `SocialQuest.toc`, `SocialQuest_Classic.toc`, `SocialQuest_Mists.toc`, `SocialQuest_Mainline.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run the full test suite one final time**

```
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```

Expected: both print 0 failures. Do not bump the version if either fails.

- [ ] **Step 2: Bump the version in all four TOC files**

Today's date is 2026-04-15. The last version was 2.25.2. This is the first change today so bump the minor version, reset revision: **2.26.0**.

In all four TOC files, change:

```
## Version: 2.25.2
```

to:

```
## Version: 2.26.0
```

- [ ] **Step 3: Add a version entry to `CLAUDE.md`**

At the top of the Version History section, add:

```markdown
### Version 2.26.0 (April 2026)
- Feature: friend presence banners (Feature 20). SocialQuest now displays a
  banner notification when a friend logs into or out of WoW. BattleTag friends
  (via `BN_FRIEND_ACCOUNT_ONLINE` / `BN_FRIEND_ACCOUNT_OFFLINE`) show the
  richer format "Joe (EvilWarlock 32 Warlock) Online"; traditional character-
  name friends are detected by diffing `FRIENDLIST_UPDATE` and show the simpler
  "EvilWarlock 32 Warlock Online". Online banners only fire for WoW sessions
  (not other Battle.net games). Offline banners only fire if an online banner
  was shown for that friend this session. Friends in both lists produce only one
  banner (the BattleTag format). Two config toggles in a new "Friend
  Notifications" section: "Show online banners" and "Show offline banners" (both
  default ON), with a master enable toggle. New module: `Core/FriendPresence.lua`
  (`SocialQuestFriendPresence`). New colors: `friend_online` (medium green /
  Okabe-Ito teal) and `friend_offline` (grey) in `Util/Colors.lua`.
```

- [ ] **Step 4: Commit**

```
git add SocialQuest.toc SocialQuest_Classic.toc SocialQuest_Mists.toc SocialQuest_Mainline.toc CLAUDE.md
git commit -m "feat: friend presence banners — version 2.26.0 (Feature 20)"
```

---

## In-Game Verification Checklist

After all commits, load the addon in TBC Anniversary and verify:

- [ ] `/sq config` shows a "Friend Notifications" section with three toggles; "Show online banners" and "Show offline banners" are greyed out when the master toggle is off.
- [ ] Debug mode on: "Test Friend Online" button shows a medium-green banner reading "TestBattleTag (YourCharName 60 Warrior) Online".
- [ ] Debug mode on: "Test Friend Offline" button shows a grey banner reading "TestBattleTag (YourCharName 60 Warrior) Offline".
- [ ] Reload UI while a traditional friend is online — no login banner fires on the first `FRIENDLIST_UPDATE`.
- [ ] Toggle "Show offline banners" off — no offline banner fires when a friend logs out.
