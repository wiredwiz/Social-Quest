-- tests/TabUtils_test.lua
-- Standalone test runner for UI/TabUtils.lua filter helpers.
-- Run from repo root: lua tests/TabUtils_test.lua

local f = io.open("UI/TabUtils.lua", "r")
if not f then error("Run from repo root: lua tests/TabUtils_test.lua") end
f:close()

-- ── Stubs ─────────────────────────────────────────────────────────────────────

-- AceLocale: key string is its own value
L = setmetatable({}, { __index = function(_, k) return k end })
-- LibStub("AceLocale-3.0"):GetLocale("SocialQuest") → L
LibStub = setmetatable({}, {
    __call = function(_, _)
        return { GetLocale = function(_, _) return L end }
    end,
})

-- Minimal AQL stub used by MatchesTypeFilter.
-- Tests inject quest info via _questInfoMap.
local AQL = {
    ChainStatus = { Known = "known", Unknown = "unknown" },
    _questInfoMap = {},
    _questMap     = {},
    GetQuestInfo  = function(self, questID) return self._questInfoMap[questID] end,
    GetQuest      = function(self, questID) return self._questMap[questID] end,
    _GetCurrentPlayerEngagedQuests = function(self)
        return { [100] = true }
    end,
    SelectBestChain = function(self, chainResult, engaged)
        return chainResult.chains and chainResult.chains[1] or nil
    end,
}

SocialQuest = { AQL = AQL }
SocialQuestGroupData = { PlayerQuests = {} }
SocialQuestWowAPI = {
    IS_TBC = true, IS_RETAIL = false, IS_MOP = false, IS_CLASSIC_ERA = false,
    CLASS_TOKEN_BY_ID = {
        [1]  = "WARRIOR",
        [5]  = "PRIEST",
    },
}

dofile("UI/TabUtils.lua")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local pass, fail = 0, 0

local function assert_true(label, got)
    if got == true then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected true, got %s", label, tostring(got)))
    end
end

local function assert_false(label, got)
    if got == false then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected false, got %s", label, tostring(got)))
    end
end

local function assert_eq(label, got, expected)
    if got == expected then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected %s, got %s",
            label, tostring(expected), tostring(got)))
    end
end

local T = SocialQuestTabUtils

-- ── MatchesStringFilter ───────────────────────────────────────────────────────

-- nil descriptor → always pass
assert_true ("str nil desc",            T.MatchesStringFilter("Elwynn", nil))

-- = operator: substring match (case-insensitive)
assert_true ("str = match",             T.MatchesStringFilter("Elwynn Forest",   { op="=", values={"elwynn"} }))
assert_true ("str = case insensitive",  T.MatchesStringFilter("ELWYNN",          { op="=", values={"elwynn"} }))
assert_false("str = no match",          T.MatchesStringFilter("Westfall",        { op="=", values={"elwynn"} }))
assert_true ("str = partial match",     T.MatchesStringFilter("Elwynn Forest",   { op="=", values={"Forest"} }))

-- != operator: not-substring
assert_false("str != match → false",    T.MatchesStringFilter("Elwynn Forest",   { op="!=", values={"elwynn"} }))
assert_true ("str != no match → true",  T.MatchesStringFilter("Westfall",        { op="!=", values={"elwynn"} }))

-- OR values (multi-value descriptor): any match passes
assert_true ("str OR first match",      T.MatchesStringFilter("Elwynn Forest",   { op="=", values={"elwynn","westfall"} }))
assert_true ("str OR second match",     T.MatchesStringFilter("Westfall",         { op="=", values={"elwynn","westfall"} }))
assert_false("str OR no match",         T.MatchesStringFilter("Duskwood",         { op="=", values={"elwynn","westfall"} }))

-- nil value
assert_false("str nil value = miss",    T.MatchesStringFilter(nil, { op="=", values={"elwynn"} }))
assert_true ("str nil value != miss",   T.MatchesStringFilter(nil, { op="!=", values={"elwynn"} }))

-- compound_and: ALL parts must match
local strAnd = { type="compound_and", parts={
    { op="=", values={"dragon"} },
    { op="=", values={"slayer"} },
}}
assert_true ("str compound_and both",   T.MatchesStringFilter("Dragonslayer",  strAnd))
assert_false("str compound_and first",  T.MatchesStringFilter("dragonfly",     strAnd))
assert_false("str compound_and second", T.MatchesStringFilter("slayerblade",   strAnd))
assert_false("str compound_and none",   T.MatchesStringFilter("warrior",       strAnd))

-- compound_and != short-circuits correctly
local strAndNot = { type="compound_and", parts={
    { op="!=", values={"dragon"} },
    { op="!=", values={"slayer"} },
}}
assert_true ("str compound_and != both clear",  T.MatchesStringFilter("warrior",    strAndNot))
assert_false("str compound_and != first hit",   T.MatchesStringFilter("dragonfly",  strAndNot))

-- ── MatchesNumericFilter ──────────────────────────────────────────────────────

-- nil descriptor / nil value
assert_true ("num nil desc",            T.MatchesNumericFilter(60, nil))
assert_false("num nil value",           T.MatchesNumericFilter(nil, { op="=", val=60 }))

-- = operator
assert_true ("num = match",             T.MatchesNumericFilter(60, { op="=", val=60 }))
assert_false("num = no match",          T.MatchesNumericFilter(59, { op="=", val=60 }))

-- < operator
assert_true ("num < less",              T.MatchesNumericFilter(59, { op="<", val=60 }))
assert_false("num < equal",             T.MatchesNumericFilter(60, { op="<", val=60 }))
assert_false("num < greater",           T.MatchesNumericFilter(61, { op="<", val=60 }))

-- > operator
assert_false("num > less",              T.MatchesNumericFilter(59, { op=">", val=60 }))
assert_false("num > equal",             T.MatchesNumericFilter(60, { op=">", val=60 }))
assert_true ("num > greater",           T.MatchesNumericFilter(61, { op=">", val=60 }))

-- <= operator
assert_true ("num <= less",             T.MatchesNumericFilter(59, { op="<=", val=60 }))
assert_true ("num <= equal",            T.MatchesNumericFilter(60, { op="<=", val=60 }))
assert_false("num <= greater",          T.MatchesNumericFilter(61, { op="<=", val=60 }))

-- >= operator
assert_false("num >= less",             T.MatchesNumericFilter(59, { op=">=", val=60 }))
assert_true ("num >= equal",            T.MatchesNumericFilter(60, { op=">=", val=60 }))
assert_true ("num >= greater",          T.MatchesNumericFilter(61, { op=">=", val=60 }))

-- range operator
assert_false("num range below",         T.MatchesNumericFilter(54, { op="range", min=55, max=62 }))
assert_true ("num range low edge",      T.MatchesNumericFilter(55, { op="range", min=55, max=62 }))
assert_true ("num range mid",           T.MatchesNumericFilter(58, { op="range", min=55, max=62 }))
assert_true ("num range high edge",     T.MatchesNumericFilter(62, { op="range", min=55, max=62 }))
assert_false("num range above",         T.MatchesNumericFilter(63, { op="range", min=55, max=62 }))

-- compound_and: level>=55&<=62
local numAnd = { type="compound_and", parts={
    { op=">=", val=55 },
    { op="<=", val=62 },
}}
assert_false("num compound_and below",      T.MatchesNumericFilter(54, numAnd))
assert_true ("num compound_and low edge",   T.MatchesNumericFilter(55, numAnd))
assert_true ("num compound_and mid",        T.MatchesNumericFilter(58, numAnd))
assert_true ("num compound_and high edge",  T.MatchesNumericFilter(62, numAnd))
assert_false("num compound_and above",      T.MatchesNumericFilter(63, numAnd))

-- ── MatchesEnumFilter ─────────────────────────────────────────────────────────
-- Regression: = operator with non-matching value was returning true (v2.14.x bug)

-- nil descriptor → always pass
assert_true ("enum nil desc",           T.MatchesEnumFilter("yes", nil))

-- = operator: exact match required
assert_true ("enum = match",            T.MatchesEnumFilter("yes",  { op="=", value="yes" }))
assert_false("enum = no match",         T.MatchesEnumFilter("no",   { op="=", value="yes" }))  -- REGRESSION TEST
assert_false("enum = no match (rev)",   T.MatchesEnumFilter("yes",  { op="=", value="no"  }))  -- REGRESSION TEST

-- != operator: must not equal
assert_false("enum != match → false",   T.MatchesEnumFilter("yes",  { op="!=", value="yes" }))
assert_true ("enum != no match → true", T.MatchesEnumFilter("no",   { op="!=", value="yes" }))

-- Concrete filter scenarios that were broken:
-- shareable=yes should hide non-shareable quests
assert_false("shareable=yes hides no",  T.MatchesEnumFilter("no",  { op="=", value="yes" }))
assert_true ("shareable=yes shows yes", T.MatchesEnumFilter("yes", { op="=", value="yes" }))
-- tracked=yes should hide untracked quests
assert_false("tracked=yes hides no",    T.MatchesEnumFilter("no",  { op="=", value="yes" }))
assert_true ("tracked=yes shows yes",   T.MatchesEnumFilter("yes", { op="=", value="yes" }))
-- status=complete should hide incomplete quests
assert_false("status=complete hides other", T.MatchesEnumFilter("incomplete", { op="=", value="complete" }))
assert_true ("status=complete shows it",    T.MatchesEnumFilter("complete",   { op="=", value="complete" }))

-- compound_and: type=chain&group (both must match)
local enumAnd = { type="compound_and", parts={
    { op="=", value="chain" },
    { op="=", value="group" },
}}
-- compound_and on an enum: MatchesEnumFilter tests each part against the SAME value.
-- "chain" does not equal "group", so both can never match the same value simultaneously.
-- This mirrors the parser structure but the filter application is a tautological false
-- for mutually exclusive enum values — valid syntax, always filters out everything.
assert_false("enum compound_and chain vs chain-only", T.MatchesEnumFilter("chain", enumAnd))
assert_false("enum compound_and chain vs group-only", T.MatchesEnumFilter("group", enumAnd))

-- ── MatchesTypeFilter ─────────────────────────────────────────────────────────

local KNOWN = AQL.ChainStatus.Known

-- nil descriptor → always pass
assert_true ("type nil desc", T.MatchesTypeFilter({}, nil))

-- group: suggestedGroup >= 2
assert_true ("type group=2",  T.MatchesTypeFilter({ suggestedGroup=2 }, { op="=", value="group" }))
assert_true ("type group=5",  T.MatchesTypeFilter({ suggestedGroup=5 }, { op="=", value="group" }))
assert_false("type group=1",  T.MatchesTypeFilter({ suggestedGroup=1 }, { op="=", value="group" }))
assert_false("type group=0",  T.MatchesTypeFilter({ suggestedGroup=0 }, { op="=", value="group" }))

-- solo: suggestedGroup <= 1
assert_true ("type solo=0",   T.MatchesTypeFilter({ suggestedGroup=0 }, { op="=", value="solo" }))
assert_true ("type solo=1",   T.MatchesTypeFilter({ suggestedGroup=1 }, { op="=", value="solo" }))
assert_false("type solo=2",   T.MatchesTypeFilter({ suggestedGroup=2 }, { op="=", value="solo" }))

-- timed: timerSeconds > 0
assert_true ("type timed yes",  T.MatchesTypeFilter({ timerSeconds=300 }, { op="=", value="timed" }))
assert_false("type timed no",   T.MatchesTypeFilter({ timerSeconds=0   }, { op="=", value="timed" }))
assert_false("type timed nil",  T.MatchesTypeFilter({},                   { op="=", value="timed" }))

-- chain: chainInfo present with Known status
assert_true ("type chain known",
    T.MatchesTypeFilter({ chainInfo={ knownStatus=KNOWN } }, { op="=", value="chain" }))
assert_false("type chain nil chainInfo",
    T.MatchesTypeFilter({ chainInfo=nil }, { op="=", value="chain" }))
assert_false("type chain unknown status",
    T.MatchesTypeFilter({ chainInfo={ knownStatus="unknown" } }, { op="=", value="chain" }))

-- != operator on type
assert_false("type != group (is group)",
    T.MatchesTypeFilter({ suggestedGroup=3 }, { op="!=", value="group" }))
assert_true ("type != group (is solo)",
    T.MatchesTypeFilter({ suggestedGroup=1 }, { op="!=", value="group" }))

-- AQL-based predicates via stub
AQL._questInfoMap[1001] = { type="dungeon", objectives={} }
AQL._questInfoMap[1002] = { type="raid",    objectives={{ type="monster" }, { type="item" }} }
AQL._questInfoMap[1003] = { type="daily",   objectives={{ type="item" }} }

assert_true ("type dungeon match",
    T.MatchesTypeFilter({ questID=1001 }, { op="=", value="dungeon" }))
assert_false("type dungeon no match",
    T.MatchesTypeFilter({ questID=1002 }, { op="=", value="dungeon" }))
assert_true ("type raid match",
    T.MatchesTypeFilter({ questID=1002 }, { op="=", value="raid" }))

-- Objective-based: kill (monster)
assert_false("type kill quest 1001 (no monster obj)",
    T.MatchesTypeFilter({ questID=1001 }, { op="=", value="kill" }))
assert_true ("type kill quest 1002 (has monster obj)",
    T.MatchesTypeFilter({ questID=1002 }, { op="=", value="kill" }))

-- Objective-based: gather (item)
assert_false("type gather quest 1001 (no item obj)",
    T.MatchesTypeFilter({ questID=1001 }, { op="=", value="gather" }))
assert_true ("type gather quest 1002 (has item obj)",
    T.MatchesTypeFilter({ questID=1002 }, { op="=", value="gather" }))
assert_true ("type gather quest 1003 (has item obj)",
    T.MatchesTypeFilter({ questID=1003 }, { op="=", value="gather" }))

-- No AQL data: AQL-based predicates return false gracefully
AQL._questInfoMap[9999] = nil
assert_false("type dungeon no AQL data",
    T.MatchesTypeFilter({ questID=9999 }, { op="=", value="dungeon" }))

-- compound_and on type: group AND timed
local typeAnd = { type="compound_and", parts={
    { op="=", value="group" },
    { op="=", value="timed" },
}}
assert_true ("type compound_and group+timed match",
    T.MatchesTypeFilter({ suggestedGroup=5, timerSeconds=120 }, typeAnd))
assert_false("type compound_and group only",
    T.MatchesTypeFilter({ suggestedGroup=5, timerSeconds=0   }, typeAnd))
assert_false("type compound_and timed only",
    T.MatchesTypeFilter({ suggestedGroup=1, timerSeconds=120 }, typeAnd))

-- ── SelectChain ───────────────────────────────────────────────────────────────

-- nil chainResult → nil
assert_eq("SelectChain nil result", T.SelectChain(nil, {}), nil)

-- knownStatus != Known → nil
assert_eq("SelectChain unknown status",
    T.SelectChain({ knownStatus = AQL.ChainStatus.Unknown }, {}), nil)

-- AQL 2.x bare ChainInfo (no chains field): returned as-is when knownStatus == Known
local bareCI = { knownStatus = AQL.ChainStatus.Known, chainID = 10, step = 2, length = 5 }
assert_eq("SelectChain bare ChainInfo is returned directly", T.SelectChain(bareCI, {}), bareCI)

-- AQL 3.0+ wrapper with chains array: delegates to AQL:SelectBestChain → chains[1]
local wrappedCI = {
    knownStatus = AQL.ChainStatus.Known,
    chains = { { chainID = 20, step = 1, length = 3 } },
}
local scResult = T.SelectChain(wrappedCI, { [100] = true })
assert_eq("SelectChain wrapper chainID", scResult and scResult.chainID, 20)
assert_eq("SelectChain wrapper step",    scResult and scResult.step,    1)

-- wrapper with empty chains → SelectBestChain returns nil (chains[1] is nil)
local emptyWrapper = { knownStatus = AQL.ChainStatus.Known, chains = {} }
assert_eq("SelectChain wrapper empty chains → nil", T.SelectChain(emptyWrapper, {}), nil)

-- ── BuildEngagedSet ───────────────────────────────────────────────────────────

-- nil playerName → delegates to AQL:_GetCurrentPlayerEngagedQuests → { [100]=true }
local localSet = T.BuildEngagedSet(nil)
assert_true("BuildEngagedSet nil playerName returns local set (quest 100)", localSet[100] == true)

-- playerName not in PlayerQuests → empty set (not nil, safe to iterate)
SocialQuestGroupData.PlayerQuests = {}
local missingSet = T.BuildEngagedSet("NoSuchPlayer")
local missingCount = 0
for _ in pairs(missingSet) do missingCount = missingCount + 1 end
assert_eq("BuildEngagedSet missing player returns empty set", missingCount, 0)

-- player with both quests and completedQuests → union of both
SocialQuestGroupData.PlayerQuests["Alice"] = {
    quests          = { [201] = { questID = 201 }, [202] = { questID = 202 } },
    completedQuests = { [300] = true },
}
local aliceSet = T.BuildEngagedSet("Alice")
assert_true("BuildEngagedSet Alice active quest 201",    aliceSet[201] == true)
assert_true("BuildEngagedSet Alice active quest 202",    aliceSet[202] == true)
assert_true("BuildEngagedSet Alice completed quest 300", aliceSet[300] == true)
assert_eq  ("BuildEngagedSet Alice no stray quest 999",  aliceSet[999], nil)

-- player with only completedQuests (quests field is nil)
SocialQuestGroupData.PlayerQuests["Bob"] = {
    quests          = nil,
    completedQuests = { [400] = true },
}
local bobSet = T.BuildEngagedSet("Bob")
assert_true("BuildEngagedSet Bob completed quest 400", bobSet[400] == true)
local bobCount = 0
for _ in pairs(bobSet) do bobCount = bobCount + 1 end
assert_eq("BuildEngagedSet Bob exactly one entry", bobCount, 1)

-- player with both tables empty → empty set
SocialQuestGroupData.PlayerQuests["Carol"] = {
    quests          = {},
    completedQuests = {},
}
local carolSet = T.BuildEngagedSet("Carol")
local carolCount = 0
for _ in pairs(carolSet) do carolCount = carolCount + 1 end
assert_eq("BuildEngagedSet Carol empty tables → empty set", carolCount, 0)

-- reset shared state so other tests in future runs start clean
SocialQuestGroupData.PlayerQuests = {}

-- ── GetZoneForQuestID ─────────────────────────────────────────────────────────

-- Reset AQL maps and set up LOCALIZED_CLASS_NAMES_MALE global for tests.
AQL._questMap     = {}
AQL._questInfoMap = {}
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PRIEST = "Priest" }

-- classID=1 (Warrior) → "Warrior"
assert_eq("GetZone classID=1 returns Warrior",
    T.GetZoneForQuestID(999, 1), "Warrior")

-- classID=5 (Priest) → "Priest"
assert_eq("GetZone classID=5 returns Priest",
    T.GetZoneForQuestID(999, 5), "Priest")

-- classID nil, AQL:GetQuest has zone → returns that zone
AQL._questMap = { [42] = { zone = "Elwynn Forest" } }
assert_eq("GetZone nil classID uses AQL GetQuest zone",
    T.GetZoneForQuestID(42, nil), "Elwynn Forest")
AQL._questMap = {}

-- classID nil, GetQuest nil, AQL:GetQuestInfo has zone → returns that zone
AQL._questInfoMap = { [55] = { zone = "Stormwind City" } }
assert_eq("GetZone nil classID falls through to AQL GetQuestInfo",
    T.GetZoneForQuestID(55, nil), "Stormwind City")
AQL._questInfoMap = {}

-- classID nil, no AQL data → "Other Quests"
assert_eq("GetZone nil classID no AQL data returns Other Quests",
    T.GetZoneForQuestID(999, nil), "Other Quests")

-- classID provided but LOCALIZED_CLASS_NAMES_MALE is nil → falls back to AQL
LOCALIZED_CLASS_NAMES_MALE = nil
AQL._questMap = { [100] = { zone = "Dun Morogh" } }
assert_eq("GetZone classID with nil LOCALIZED table falls back to AQL",
    T.GetZoneForQuestID(100, 1), "Dun Morogh")
AQL._questMap = {}
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PRIEST = "Priest" }

-- classID for unknown class (not in CLASS_TOKEN_BY_ID) → falls back to AQL
AQL._questMap = { [77] = { zone = "Feralas" } }
assert_eq("GetZone unknown classID falls back to AQL",
    T.GetZoneForQuestID(77, 99), "Feralas")
AQL._questMap = {}

-- ── Results ───────────────────────────────────────────────────────────────────

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
