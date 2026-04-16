-- Core/FriendPresence.lua
-- Tracks BattleTag and traditional friend presence.
-- Fires banner notifications via SocialQuestAnnounce when friends log in/out of WoW.

SocialQuestFriendPresence = {}

local SQWowAPI = SocialQuestWowAPI
local db

-- { [charName] = { level = N, className = "ClassName" } }  connected traditional friends
local knownFriends   = {}
-- { [bnetIDAccount] = { battleTagName, charName, level, className } }  BN friends shown online this session
local bnShownOnline  = {}
-- { [charName] = true }  character names of BN friends currently in WoW
local bnCharNames    = {}
local initialized    = false

-- Called from SocialQuest:OnPlayerEnteringWorld.
-- Populates state without firing any banners. Safe to call multiple times.
function SocialQuestFriendPresence:Initialize()
    db = SocialQuest.db.profile

    wipe(knownFriends)
    wipe(bnShownOnline)
    wipe(bnCharNames)
    initialized = false

    -- Populate bnCharNames from current BN friends
    local numBN = SQWowAPI.BNGetNumFriends()
    for i = 1, numBN do
        local info = SQWowAPI.BNGetFriendInfoByIndex(i)
        if info and info.isOnline and info.charName
                and (info.clientProgram == SQWowAPI.BNET_CLIENT_WOW) then
            bnCharNames[info.charName] = true
        end
    end

    -- Populate knownFriends from current traditional friends list
    local numFriends = SQWowAPI.GetNumFriends()
    for i = 1, numFriends do
        local info = SQWowAPI.GetFriendInfoByIndex(i)
        if info and info.connected then
            knownFriends[info.name] = { level = info.level, className = info.className }
        end
    end

    initialized = true
end

-- Strips everything from '#' onward: "Joe#1234" → "Joe"
local function stripBattleTag(battleTagName)
    if not battleTagName then return nil end
    return battleTagName:match("^([^#]+)") or battleTagName
end

-- Fires when BN_FRIEND_ACCOUNT_ONLINE fires for a BattleNet friend.
function SocialQuestFriendPresence:OnBnFriendOnline(bnetIDAccount)
    if not (db.friendPresence.enabled and db.friendPresence.showOnline) then return end

    local info = SQWowAPI.BNGetFriendInfoByID(bnetIDAccount)
    if not info then return end
    if info.clientProgram ~= SQWowAPI.BNET_CLIENT_WOW then return end

    local displayName = stripBattleTag(info.battleTagName)
    local charName    = info.charName
    local level       = info.level
    local className   = info.className

    if charName then
        bnCharNames[charName] = true
    end
    bnShownOnline[bnetIDAccount] = {
        battleTagName = displayName,
        charName      = charName,
        level         = level,
        className     = className,
    }

    SocialQuestAnnounce:OnFriendOnline(displayName, charName, level, className)
end

-- Fires when BN_FRIEND_ACCOUNT_OFFLINE fires for a BattleNet friend.
function SocialQuestFriendPresence:OnBnFriendOffline(bnetIDAccount)
    if not (db.friendPresence.enabled and db.friendPresence.showOffline) then return end
    if not bnShownOnline[bnetIDAccount] then return end

    -- Use cached data — BNGetFriendInfoByID may return nil when already offline
    local cached  = bnShownOnline[bnetIDAccount]
    local displayName = cached.battleTagName
    local charName    = cached.charName
    local level       = cached.level
    local className   = cached.className

    bnShownOnline[bnetIDAccount] = nil
    if charName then
        bnCharNames[charName] = nil
    end

    SocialQuestAnnounce:OnFriendOffline(displayName, charName, level, className)
end

-- Fires when FRIENDLIST_UPDATE fires.
function SocialQuestFriendPresence:OnFriendListUpdate()
    if not initialized then return end

    -- Rebuild bnCharNames fresh (keeps it current even if FRIENDLIST_UPDATE fires
    -- before a BN event for a given player)
    wipe(bnCharNames)
    local numBN = SQWowAPI.BNGetNumFriends()
    for i = 1, numBN do
        local info = SQWowAPI.BNGetFriendInfoByIndex(i)
        if info and info.isOnline and info.charName
                and (info.clientProgram == SQWowAPI.BNET_CLIENT_WOW) then
            bnCharNames[info.charName] = true
        end
    end

    -- Build current connected traditional friends snapshot
    local currentFriends = {}
    local numFriends = SQWowAPI.GetNumFriends()
    for i = 1, numFriends do
        local info = SQWowAPI.GetFriendInfoByIndex(i)
        if info and info.connected then
            currentFriends[info.name] = { level = info.level, className = info.className }
        end
    end

    -- Detect newly online: in currentFriends but not in knownFriends
    if db.friendPresence.enabled and db.friendPresence.showOnline then
        for name, data in pairs(currentFriends) do
            if not knownFriends[name] and not bnCharNames[name] then
                SocialQuestAnnounce:OnFriendOnline(nil, name, data.level, data.className)
            end
        end
    end

    -- Detect newly offline: in knownFriends but not in currentFriends
    if db.friendPresence.enabled and db.friendPresence.showOffline then
        for name, data in pairs(knownFriends) do
            if not currentFriends[name] and not bnCharNames[name] then
                SocialQuestAnnounce:OnFriendOffline(nil, name, data.level, data.className)
            end
        end
    end

    knownFriends = currentFriends
end
