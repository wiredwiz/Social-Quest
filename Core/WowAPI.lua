-- Core/WowAPI.lua
-- Thin pass-through wrappers around WoW game-state and data globals.
-- All version-specific branching for non-quest WoW APIs lives here.
-- No other SocialQuest file should reference these WoW globals directly.

SocialQuestWowAPI = {}

function SocialQuestWowAPI.GetTime()                              return GetTime()                              end
function SocialQuestWowAPI.UnitName(unit)                         return UnitName(unit)                         end
function SocialQuestWowAPI.UnitFullName(unit)                     return UnitFullName(unit)                     end
function SocialQuestWowAPI.UnitLevel(unit)                        return UnitLevel(unit)                        end
function SocialQuestWowAPI.UnitRace(unit)                         return UnitRace(unit)                         end
function SocialQuestWowAPI.UnitFactionGroup(unit)                 return UnitFactionGroup(unit)                 end
function SocialQuestWowAPI.IsInRaid()                             return IsInRaid()                             end
function SocialQuestWowAPI.IsInGroup(category)                    return IsInGroup(category)                    end
function SocialQuestWowAPI.IsInGuild()                            return IsInGuild()                            end
function SocialQuestWowAPI.GetNumGroupMembers()                   return GetNumGroupMembers()                   end
function SocialQuestWowAPI.GetRaidRosterInfo(index)               return GetRaidRosterInfo(index)               end
function SocialQuestWowAPI.SendChatMessage(text, chan, lang, tgt)  return SendChatMessage(text, chan, lang, tgt)  end
function SocialQuestWowAPI.IsFriend(name)                         return C_FriendList.IsFriend(name)            end
function SocialQuestWowAPI.GetNumFriends()                        return C_FriendList.GetNumFriends()           end
function SocialQuestWowAPI.GetFriendInfoByIndex(index)            return C_FriendList.GetFriendInfoByIndex(index) end
function SocialQuestWowAPI.TimerAfter(delay, fn)                   C_Timer.After(delay, fn)                      end
function SocialQuestWowAPI.GetTaxiNodeInfo(index)                 return GetTaxiNodeInfo(index)                 end

-- IsInGroup accepts an optional category argument. When called as
-- SQWowAPI.IsInGroup() (no arg), Lua passes nil, which the WoW API
-- treats as the no-argument form (checks home group only).

-- Version-dependent enum constants. If a future WoW version renames
-- these, update only this file.
SocialQuestWowAPI.PARTY_CATEGORY_HOME     = LE_PARTY_CATEGORY_HOME
SocialQuestWowAPI.PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
