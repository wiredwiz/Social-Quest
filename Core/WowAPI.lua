-- Core/WowAPI.lua
-- Thin pass-through wrappers around WoW game-state and data globals.
-- All version-specific branching for non-quest WoW APIs lives here.
-- No other SocialQuest file should reference these WoW globals directly.

SocialQuestWowAPI = {}

local _toc = select(4, GetBuildInfo())
SocialQuestWowAPI.IS_CLASSIC_ERA = _toc >= 11000 and _toc < 20000
SocialQuestWowAPI.IS_TBC         = _toc >= 20000 and _toc < 30000
SocialQuestWowAPI.IS_MOP         = _toc >= 50000 and _toc < 60000
SocialQuestWowAPI.IS_RETAIL      = _toc >= 100000

function SocialQuestWowAPI.GetTime()                              return GetTime()                              end
function SocialQuestWowAPI.UnitName(unit)                         return UnitName(unit)                         end
function SocialQuestWowAPI.UnitFullName(unit)                     return UnitFullName(unit)                     end
-- Returns the current realm name in the short, hyphenable form used by
-- CHAT_MSG_ADDON sender strings (no spaces). On Retail, UnitFullName("player")
-- returns nil realm even though the player IS on a realm; this fills that gap.
function SocialQuestWowAPI.GetNormalizedRealmName()
    if GetNormalizedRealmName then return GetNormalizedRealmName() end
    local r = GetRealmName and GetRealmName()
    return r and r:gsub("%s+", "") or nil
end
function SocialQuestWowAPI.UnitLevel(unit)                        return UnitLevel(unit)                        end
function SocialQuestWowAPI.UnitRace(unit)                         return UnitRace(unit)                         end
function SocialQuestWowAPI.UnitClass(unit)                        return UnitClass(unit)                        end
function SocialQuestWowAPI.UnitFactionGroup(unit)                 return UnitFactionGroup(unit)                 end
function SocialQuestWowAPI.IsInRaid()                             return IsInRaid()                             end
function SocialQuestWowAPI.IsInGroup(category)                    return IsInGroup(category)                    end
function SocialQuestWowAPI.IsInGuild()                            return IsInGuild()                            end
function SocialQuestWowAPI.GetNumGroupMembers()                   return GetNumGroupMembers()                   end
function SocialQuestWowAPI.GetRaidRosterInfo(index)
    if SocialQuestWowAPI.IS_RETAIL and C_RaidRoster then
        return C_RaidRoster.GetRaidRosterInfo(index)
    end
    return GetRaidRosterInfo(index)
end
function SocialQuestWowAPI.SendChatMessage(text, chan, lang, tgt)  return SendChatMessage(text, chan, lang, tgt)  end
function SocialQuestWowAPI.QuestLogPushQuest(questID)
    if SocialQuestWowAPI.IS_RETAIL then
        C_QuestLog.PushQuestToParty(questID)
    else
        QuestLogPushQuest()
    end
end
function SocialQuestWowAPI.IsFriend(name)                         return C_FriendList.IsFriend(name)            end
function SocialQuestWowAPI.GetNumFriends()                        return C_FriendList.GetNumFriends()           end
function SocialQuestWowAPI.GetFriendInfoByIndex(index)            return C_FriendList.GetFriendInfoByIndex(index) end
function SocialQuestWowAPI.TimerAfter(delay, fn)                   C_Timer.After(delay, fn)                      end
function SocialQuestWowAPI.GetRealZoneText()   return GetRealZoneText()   end
function SocialQuestWowAPI.GetSubZoneText()     return GetSubZoneText()    end
function SocialQuestWowAPI.IsInInstance()       return IsInInstance()       end

-- IsInGroup accepts an optional category argument. When called as
-- SQWowAPI.IsInGroup() (no arg), Lua passes nil, which the WoW API
-- treats as the no-argument form (checks home group only).

-- Version-dependent enum constants. If a future WoW version renames
-- these, update only this file.
SocialQuestWowAPI.PARTY_CATEGORY_HOME     = LE_PARTY_CATEGORY_HOME
SocialQuestWowAPI.PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE

SocialQuestWowAPI.MAX_QUEST_LOG_ENTRIES = SocialQuestWowAPI.IS_RETAIL and 35 or 25

-- Reference: WoW numeric race IDs (third return of UnitRace(unit)).
-- Used with the formula 2^(raceID-1) to compute requiredRaces bitmask bits.
SocialQuestWowAPI.RACE_ID = {
    Human=1, Orc=2, Dwarf=3, NightElf=4, Undead=5, Tauren=6, Gnome=7, Troll=8,
    Goblin=9, BloodElf=10, Draenei=11, Worgen=22, Pandaren=24, Nightborne=27,
    HighmountainTauren=28, VoidElf=29, LightforgedDraenei=30, ZandalariTroll=31,
    KulTiran=32, DarkIronDwarf=34, Vulpera=35, MagharOrc=36, Mechagnome=37,
}

-- Reference: WoW numeric class IDs (third return of UnitClass(unit)).
-- Used with the formula 2^(classID-1) to compute requiredClasses bitmask bits.
SocialQuestWowAPI.CLASS_ID = {
    Warrior=1, Paladin=2, Hunter=3, Rogue=4, Priest=5, DeathKnight=6,
    Shaman=7, Mage=8, Warlock=9, Monk=10, Druid=11, DemonHunter=12, Evoker=13,
}

-- Maps WoW numeric class ID to the uppercase class token used as a key in
-- LOCALIZED_CLASS_NAMES_MALE and returned by UnitClass() as the second value.
-- Covers all classes across all WoW versions; entries for classes absent from
-- the current version are simply absent from LOCALIZED_CLASS_NAMES_MALE.
SocialQuestWowAPI.CLASS_TOKEN_BY_ID = {
    [1]  = "WARRIOR",
    [2]  = "PALADIN",
    [3]  = "HUNTER",
    [4]  = "ROGUE",
    [5]  = "PRIEST",
    [6]  = "DEATHKNIGHT",
    [7]  = "SHAMAN",
    [8]  = "MAGE",
    [9]  = "WARLOCK",
    [10] = "MONK",
    [11] = "DRUID",
    [12] = "DEMONHUNTER",
    [13] = "EVOKER",
}
