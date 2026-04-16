# Friend Presence Banners Implementation Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display banner notifications when a friend logs into or out of WoW, using SocialQuest's existing banner system.

**Feature:** Feature 20 from FeatureIdeas.md.

---

## Overview

SocialQuest's banner system is already used for quest events and follow notifications. This feature extends it to social presence: when a friend logs into WoW or logs out, a brief banner appears using a new color key distinct from quest events.

Two friend systems are handled:

- **BattleTag friends** — via `BN_FRIEND_ACCOUNT_ONLINE` / `BN_FRIEND_ACCOUNT_OFFLINE` events. Online banners only fire when the friend is playing WoW (not other Battle.net games). Offline banners only fire if an online banner was shown this session for that friend.
- **Traditional (character-name) friends** — via `FRIENDLIST_UPDATE` diffing. A snapshot of connected friends is maintained; each update is diffed against the snapshot to detect logins and logouts. Traditional friends who also appear in the BattleTag list are skipped to prevent double banners.

---

## Files

| Action | File | Responsibility |
|---|---|---|
| Create | `Core/FriendPresence.lua` | Owns presence tracking state and event handling logic |
| Modify | `SocialQuest.lua` | Register 3 new events; call FriendPresence:Initialize() in OnPlayerEnteringWorld; add AceDB defaults |
| Modify | `Core/WowAPI.lua` | Add BN API wrappers |
| Modify | `Core/Announcements.lua` | Add OnFriendOnline / OnFriendOffline display methods |
| Modify | `UI/Options.lua` | Add Friend Notifications config section; add test buttons to debug section |
| Modify | `Util/Colors.lua` | Add friend_online and friend_offline color keys |
| Modify | `Locales/enUS.lua` (+ 11 others) | Add all new locale strings |

---

## Module: Core/FriendPresence.lua

### Global

`SocialQuestFriendPresence` — table, registered in the TOC after `Core/Announcements.lua`.

### State

Three module-level locals:

```lua
local knownFriends = {}   -- { [charName] = true }  connected traditional friends
local bnShownOnline = {}  -- { [bnetIDAccount] = true }  BN friends shown as online this session
local bnCharNames   = {}  -- { [charName] = true }  character names of BN friends in WoW right now
local initialized   = false
```

### Methods

**`FriendPresence:Initialize()`**

Called from `SocialQuest:OnPlayerEnteringWorld`. Populates `knownFriends` and `bnCharNames` from the current friend lists without firing any banners. Sets `initialized = true`. Safe to call multiple times (resets state on each zone transition so stale data is never carried across loading screens).

**`FriendPresence:OnBnFriendOnline(bnetIDAccount)`**

1. Gate: `db.friendPresence.enabled` and `db.friendPresence.showOnline`.
2. Retrieve friend info via `SQWowAPI.BNGetFriendInfoByID(bnetIDAccount)`.
3. Check `clientProgram == BNET_CLIENT_WOW` (or `"WoW"` as string fallback). If not WoW, return.
4. Add `charName` to `bnCharNames`.
5. Add `bnetIDAccount` to `bnShownOnline`.
6. Build banner message and call `SocialQuestAnnounce:OnFriendOnline(battleTagDisplayName, charName, level, className)`.

**`FriendPresence:OnBnFriendOffline(bnetIDAccount)`**

1. Gate: `db.friendPresence.enabled` and `db.friendPresence.showOffline`.
2. If `bnetIDAccount` not in `bnShownOnline`, return (was never shown as online in WoW this session).
3. Retrieve friend info via `SQWowAPI.BNGetFriendInfoByID(bnetIDAccount)`. Use cached name from `bnShownOnline` entry if info is unavailable at offline time.
4. Remove from `bnShownOnline` and `bnCharNames`.
5. Call `SocialQuestAnnounce:OnFriendOffline(battleTagDisplayName, charName, level, className)`.

Note: At offline time `BNGetFriendInfoByID` may return nil or incomplete data because the friend is already gone. Store the display strings (battleTagDisplayName, charName, level, className) in `bnShownOnline` as a table value (not just `true`) so they are available for the offline banner.

**`FriendPresence:OnFriendListUpdate()`**

1. Gate: `initialized`.
2. Rebuild `bnCharNames` by iterating BN friends (ensures it is always current).
3. Build `currentFriends = { [charName] = true }` from `C_FriendList.GetFriendInfoByIndex` for connected traditional friends only.
4. Detect newly online: names in `currentFriends` not in `knownFriends`. For each: if name is in `bnCharNames`, skip (BN handles them). Otherwise call `SocialQuestAnnounce:OnFriendOnline(nil, charName, level, className)` when `showOnline` is enabled.
5. Detect newly offline: names in `knownFriends` not in `currentFriends`. For each: if name is in `bnCharNames`, skip. Otherwise call `SocialQuestAnnounce:OnFriendOffline(nil, charName, level, className)` when `showOffline` is enabled.
6. Replace `knownFriends` with `currentFriends`.

### WoW API wrappers to add in Core/WowAPI.lua

```lua
function SocialQuestWowAPI.BNGetNumFriends()
    if BNGetNumFriends then return BNGetNumFriends() end
    return 0
end

-- Returns a table: { battleTagName, displayName, charName, level, className, clientProgram, bnetIDAccount }
-- Tries C_BattleNet.GetFriendAccountInfo first (available on all versions tested),
-- falls back to BNGetFriendInfo positional returns.
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
        -- positional: presenceName, battleTag, isBTPresence, toonName, toonID,
        --             client, isOnline, lastOnline, isAFK, isDND, ...
        local presenceName, battleTag, _, toonName, _, client, isOnline = BNGetFriendInfo(index)
        return {
            battleTagName = battleTag or presenceName,
            charName      = toonName,
            level         = nil,   -- not available in this form; display without level
            className     = nil,
            clientProgram = client,
            isOnline      = isOnline,
        }
    end
    return nil
end

function SocialQuestWowAPI.BNGetFriendInfoByID(bnetIDAccount)
    -- Iterate to find by ID; no direct by-ID API is guaranteed on all versions.
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

---

## Banner Format

Banner messages are assembled in `FriendPresence` before calling into `Announcements`.

**Character description string** (assembled locally, not localized — it is a data string):

```lua
-- When level and class are known:
local charDesc = charName .. " " .. level .. " " .. className
-- When level or class is nil (BNGetFriendInfo fallback):
local charDesc = charName  -- just the name
```

**Locale format strings:**

| Key | Usage |
|---|---|
| `L["%s Online"]` | Regular friend online — %s = charDesc |
| `L["%s Offline"]` | Regular friend offline — %s = charDesc |
| `L["%s (%s) Online"]` | BattleTag friend online — %s1 = displayName, %s2 = charDesc |
| `L["%s (%s) Offline"]` | BattleTag friend offline — %s1 = displayName, %s2 = charDesc |

BattleTag display name: strip everything from `#` onwards. `"Joe#1234"` → `"Joe"`.

**Banner construction examples:**

```
Regular friend:    "EvilWarlock 32 Warlock Online"
BattleTag friend:  "Joe (EvilWarlock 32 Warlock) Online"
```

---

## Announcements.lua: Display Methods

```lua
function SocialQuestAnnounce:OnFriendOnline(battleTagName, charName, level, className)
    local charDesc = (level and className)
        and (charName .. " " .. level .. " " .. className)
        or  charName
    local msg = battleTagName
        and string.format(L["%s (%s) Online"], battleTagName, charDesc)
        or  string.format(L["%s Online"], charDesc)
    displayBanner(msg, "friend_online")
end

function SocialQuestAnnounce:OnFriendOffline(battleTagName, charName, level, className)
    local charDesc = (level and className)
        and (charName .. " " .. level .. " " .. className)
        or  charName
    local msg = battleTagName
        and string.format(L["%s (%s) Offline"], battleTagName, charDesc)
        or  string.format(L["%s Offline"], charDesc)
    displayBanner(msg, "friend_offline")
end

function SocialQuestAnnounce:TestFriendOnline()
    local name = SQWowAPI.UnitName("player") or "TestPlayer"
    SocialQuestAnnounce:OnFriendOnline("TestBattleTag", name, UnitLevel("player") or 60, "Warrior")
end

function SocialQuestAnnounce:TestFriendOffline()
    local name = SQWowAPI.UnitName("player") or "TestPlayer"
    SocialQuestAnnounce:OnFriendOffline("TestBattleTag", name, UnitLevel("player") or 60, "Warrior")
end
```

---

## Colors: Util/Colors.lua

Add to `SocialQuestColors.event`:

```lua
friend_online  = { r = 0,     g = 0.867, b = 0.267 },  -- medium green  (#00DD44)
friend_offline = { r = 0.533, g = 0.533, b = 0.533 },  -- grey          (#888888)
```

Add to `SocialQuestColors.eventCB`:

```lua
friend_online  = { r = 0,     g = 0.620, b = 0.451 },  -- Okabe-Ito teal  (#009E73)
friend_offline = { r = 0.533, g = 0.533, b = 0.533 },  -- grey (unchanged)
```

---

## Config: UI/Options.lua

### AceDB profile defaults (SocialQuest.lua)

```lua
friendPresence = {
    enabled     = true,
    showOnline  = true,
    showOffline = true,
},
```

Add between `follow` and `window` sub-tables.

### Options group (order 8, after Follow Notifications at order 7)

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
        showOnline = toggle(
            L["Show online banners"],
            L["Show a banner when a friend logs into WoW."],
            { "friendPresence", "showOnline" }
        ),
        showOffline = toggle(
            L["Show offline banners"],
            L["Show a banner when a friend logs out of WoW."],
            { "friendPresence", "showOffline" }
        ),
    },
},
```

`showOnline` and `showOffline` are disabled in the UI when `enabled` is false (use the standard `disabled` callback pattern already used by other sub-toggles in Options.lua).

### Debug section additions

Two execute buttons added alongside the existing test buttons:

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

---

## Locale Strings

All 12 locale files (`enUS` through `jaJP`) require the following new keys. `enUS` values are `= true`. All other locales must use natural, WoW-appropriate phrasing — not literal word-for-word translations.

**Banner format strings:**

- `"%s Online"`
- `"%s Offline"`
- `"%s (%s) Online"`
- `"%s (%s) Offline"`

**Config UI strings:**

- `"Friend Notifications"`
- `"Enable friend notifications"`
- `"Show online banners"`
- `"Show offline banners"`
- `"Show a banner when a friend logs into or out of WoW."`
- `"Show a banner when a friend logs into WoW."`
- `"Show a banner when a friend logs out of WoW."`

**Debug UI strings:**

- `"Test Friend Online"`
- `"Display a demo friend online banner."`
- `"Test Friend Offline"`
- `"Display a demo friend offline banner."`

---

## Event Registration in SocialQuest.lua

In `OnEnable`, alongside the existing event registrations:

```lua
self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE",  "OnBnFriendOnline")
self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE", "OnBnFriendOffline")
self:RegisterEvent("FRIENDLIST_UPDATE",          "OnFriendListUpdate")
```

New handlers in SocialQuest.lua:

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

`OnPlayerEnteringWorld` gains one additional call at the end:

```lua
SocialQuestFriendPresence:Initialize()
```

---

## No Protocol Changes

This feature is entirely local — no new AceComm prefixes, no wire format changes, no impact on other group members.

---

## Testing

- Enable debug mode and use "Test Friend Online" / "Test Friend Offline" buttons to verify banner appearance and color without needing a real friend to log in.
- Log in and out with a BattleTag friend online to verify the WoW-only filter works (friend playing another game should produce no banner).
- Add a player to both the traditional friends list and the BattleTag list, then have them log in — verify only one banner fires (the BattleTag-format one).
- Toggle "Show offline banners" off — verify no offline banner fires.
- Reload UI while friends are online — verify no spurious login banners fire on the first FRIENDLIST_UPDATE after reload.
