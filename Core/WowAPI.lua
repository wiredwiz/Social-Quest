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
function SocialQuestWowAPI.UnitLevel(unit)                        return UnitLevel(unit)                        end
function SocialQuestWowAPI.UnitRace(unit)                         return UnitRace(unit)                         end
function SocialQuestWowAPI.UnitClass(unit)                        return UnitClass(unit)                        end
function SocialQuestWowAPI.UnitFactionGroup(unit)                 return UnitFactionGroup(unit)                 end
function SocialQuestWowAPI.IsInRaid()                             return IsInRaid()                             end
function SocialQuestWowAPI.IsInGroup(category)                    return IsInGroup(category)                    end
function SocialQuestWowAPI.IsInGuild()                            return IsInGuild()                            end
function SocialQuestWowAPI.GetNumGroupMembers()                   return GetNumGroupMembers()                   end
function SocialQuestWowAPI.GetRaidRosterInfo(index)               return GetRaidRosterInfo(index)               end
function SocialQuestWowAPI.SendChatMessage(text, chan, lang, tgt)  return SendChatMessage(text, chan, lang, tgt)  end
function SocialQuestWowAPI.QuestLogPushQuest()                    QuestLogPushQuest()                           end
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
