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

-- BuildQuestLink now returns plain text [[level] Quest Name {questID}] on all versions.
-- Curly braces are used as the questID delimiter so ChatFrame_AddMessageEventFilter
-- in Tooltips.lua can reliably detect and convert the marker to |Hsocialquest:|
-- locally on each receiving client (parentheses could appear in quest names).
dofile("Core/Announcements.lua")
local B = SocialQuestAnnounce._BuildQuestLink

assert_eq("basic",         B(337, "Wanted: Hogger", 10),  "[[10] Wanted: Hogger {337}]")
assert_eq("nil_level",     B(100, "A Quest",         nil), "[[0] A Quest {100}]")
assert_eq("nil_questID",   B(nil, "A Quest",           5), nil)
assert_eq("nil_name",      B(337, nil,                 5), nil)

-- Retail path: same output (no version branching in BuildQuestLink anymore)
SocialQuestWowAPI.IS_RETAIL = true
SocialQuestWowAPI.IS_TBC    = false
dofile("Core/Announcements.lua")
B = SocialQuestAnnounce._BuildQuestLink

assert_eq("retail_basic",  B(337, "Wanted: Hogger", 40),  "[[40] Wanted: Hogger {337}]")
assert_eq("retail_nil_lv", B(337, "Wanted: Hogger", nil), "[[0] Wanted: Hogger {337}]")

-- ── Result ────────────────────────────────────────────────────────────────────
if failures == 0 then
    print("Announcements_test: all tests passed")
else
    print("Announcements_test: " .. failures .. " failure(s)")
    os.exit(1)
end
