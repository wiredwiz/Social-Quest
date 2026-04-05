-- tests/Announcements_test.lua
-- Unit tests for SocialQuestAnnounce._BuildQuestLink

local failures = 0
local function assert_eq(label, got, expected)
    if got ~= expected then
        failures = failures + 1
        print("FAIL [" .. label .. "]")
        print("  expected: " .. tostring(expected))
        print("  got:      " .. tostring(got))
    end
end

-- ── Stubs ────────────────────────────────────────────────────────────────────
SocialQuestWowAPI = {
    IS_RETAIL = false, IS_TBC = true, IS_MOP = false, IS_CLASSIC_ERA = false,
    GetTime = function() return 0 end,
    SendChatMessage = function() end,
    IsInGroup = function() return false end,
    IsInRaid  = function() return false end,
    IsInGuild = function() return false end,
    TimerAfter = function() end,
    GetNumFriends = function() return 0 end,
    PARTY_CATEGORY_HOME = 0,
    PARTY_CATEGORY_INSTANCE = 2,
}
SocialQuestWowUI  = { AddRaidNotice = function() end, AddChatMessage = function() end }
SocialQuestColors = { GetEventColor = function() return nil end }
SocialQuestTabUtils = {
    BuildEngagedSet = function() return {} end,
    SelectChain     = function() return nil end,
}
SocialQuestGroupData = { PlayerQuests = {} }
UnitGUID = function(unit) return "Player-1234-ABCDEF12" end
LibStub = function(name)
    if name == "AceLocale-3.0" then
        return {
            GetLocale = function()
                return setmetatable({}, { __index = function(t, k) return k end })
            end,
        }
    end
    return {}
end
SocialQuest = {
    EventTypes = {
        Accepted = "accepted", Completed = "completed", Abandoned = "abandoned",
        Failed = "failed", Finished = "finished", Tracked = "tracked",
        Untracked = "untracked",
        ObjectiveComplete = "objective_complete",
        ObjectiveProgress = "objective_progress",
    },
    AQL = { ChainStatus = { Known = "known" } },
    db  = { profile = { enabled = false } },
}
function SocialQuest:Debug() end
function SocialQuest:ScheduleRepeatingTimer(fn, delay) return {} end
function SocialQuest:Print() end

-- ── TBC tests (IS_RETAIL = false) ────────────────────────────────────────────
dofile("Core/Announcements.lua")
local B = SocialQuestAnnounce._BuildQuestLink

assert_eq("tbc_basic",
    B(337, "Wanted: Hogger", 10),
    "|Hquestie:337:Player-1234-ABCDEF12|h[10] Wanted: Hogger|h|r")

assert_eq("tbc_nil_level",
    B(100, "A Quest", nil),
    "|Hquestie:100:Player-1234-ABCDEF12|h[0] A Quest|h|r")

assert_eq("tbc_nil_questID",  B(nil, "A Quest", 5), nil)
assert_eq("tbc_nil_name",     B(337, nil,       5), nil)

-- ── Retail tests (IS_RETAIL = true) ──────────────────────────────────────────
SocialQuestWowAPI.IS_RETAIL = true
SocialQuestWowAPI.IS_TBC    = false
dofile("Core/Announcements.lua")   -- re-load so SQWowAPI local captures IS_RETAIL=true
B = SocialQuestAnnounce._BuildQuestLink

assert_eq("retail_basic",
    B(337, "Wanted: Hogger", 40),
    "|Hsocialquest:337:40|h[40] Wanted: Hogger|h|r")

assert_eq("retail_nil_level",
    B(337, "Wanted: Hogger", nil),
    "|Hsocialquest:337:0|h[0] Wanted: Hogger|h|r")

assert_eq("retail_nil_questID", B(nil, "Name", 5), nil)
assert_eq("retail_nil_name",    B(1,   nil,    5), nil)

-- ── Result ────────────────────────────────────────────────────────────────────
if failures == 0 then
    print("Announcements_test: all tests passed")
else
    print("Announcements_test: " .. failures .. " failure(s)")
    os.exit(1)
end
