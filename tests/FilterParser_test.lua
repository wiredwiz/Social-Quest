-- tests/FilterParser_test.lua
-- Standalone test runner. Run from repo root: lua tests/FilterParser_test.lua

local f = io.open("UI/FilterParser.lua", "r")
if not f then error("Run from repo root: lua tests/FilterParser_test.lua") end
f:close()

-- Stub locale: key string is its own value
L = setmetatable({}, { __index = function(_, k) return k end })

dofile("UI/FilterParser.lua")

-- Minimal keyDefs for testing (English canonical names as-is)
SocialQuestFilterParser:Initialize({
    { canonical="zone",   names={"zone","z"},       type="string" },
    { canonical="title",  names={"title","t"},       type="string" },
    { canonical="chain",  names={"chain","c"},       type="string" },
    { canonical="player", names={"player","p"},      type="string" },
    { canonical="level",  names={"level","lvl","l"}, type="numeric" },
    { canonical="step",   names={"step","s"},        type="numeric" },
    { canonical="group",  names={"group","g"},       type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no", ["2"]="2", ["3"]="3", ["4"]="4", ["5"]="5" } },
    { canonical="type",   names={"type"},            type="enum",
      enumMap={ ["chain"]="chain", ["group"]="group", ["solo"]="solo", ["timed"]="timed" } },
    { canonical="status", names={"status"},          type="enum",
      enumMap={ ["complete"]="complete", ["incomplete"]="incomplete", ["failed"]="failed" } },
    { canonical="tracked",names={"tracked"},         type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no" } },
    { canonical="shareable",names={"shareable"},   type="enum",
      enumMap={ ["yes"]="yes", ["no"]="no" } },
})

local pass, fail = 0, 0

local function assert_eq(label, got, expected)
    if got == expected then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected %s, got %s",
            label, tostring(expected), tostring(got)))
    end
end

local function assert_nil(label, got)
    if got == nil then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected nil, got %s", label, tostring(got)))
    end
end

local function assert_error(label, result, code)
    if result and result.error == true and result.code == code then pass = pass + 1
    else
        fail = fail + 1
        local got = result and (result.code or tostring(result)) or "nil"
        print(string.format("FAIL [%s]: expected error %s, got %s", label, code, got))
    end
end

local function assert_filter(label, result, canonical, op)
    if result and result.filter and result.filter.canonical == canonical then
        if op == nil or result.filter.descriptor.op == op then pass = pass + 1
        else
            fail = fail + 1
            print(string.format("FAIL [%s]: expected op=%s, got op=%s",
                label, tostring(op), tostring(result.filter.descriptor.op)))
        end
    else
        fail = fail + 1
        local got = result and (result.filter and result.filter.canonical or tostring(result)) or "nil"
        print(string.format("FAIL [%s]: expected filter canonical=%s, got %s", label, canonical, got))
    end
end

local P = SocialQuestFilterParser

-- ── Fast-fail (nil) ──────────────────────────────────────────────────
assert_nil("nil input",       P:Parse(nil))
assert_nil("empty string",    P:Parse(""))
assert_nil("plain text",      P:Parse("Defias Brotherhood"))
assert_nil("whitespace only", P:Parse("   "))
assert_nil("no equals sign",  P:Parse("level60"))

-- ── String filters ───────────────────────────────────────────────────
local r = P:Parse("zone=Elwynn")
assert_filter("zone= basic",              r, "zone", "=")
assert_eq("zone= value",                  r and r.filter.descriptor.values[1], "Elwynn")

r = P:Parse("z=Elwynn")
assert_filter("z= alias",                 r, "zone", "=")

r = P:Parse("ZONE=Elwynn")
assert_filter("ZONE= case insensitive",   r, "zone", "=")

r = P:Parse("zone = Elwynn")
assert_filter("zone= whitespace",         r, "zone", "=")

r = P:Parse("zone!=Westfall")
assert_filter("zone!= op",                r, "zone", "!=")

r = P:Parse("zone~=Westfall")
assert_filter("zone~= normalised to !=", r, "zone", "!=")

r = P:Parse("zone=Elwynn|Deadmines")
assert_filter("zone= OR list",            r, "zone", "=")
assert_eq("OR val[1]",                    r and r.filter.descriptor.values[1], "Elwynn")
assert_eq("OR val[2]",                    r and r.filter.descriptor.values[2], "Deadmines")

r = P:Parse('zone="Elwynn Forest"')
assert_filter("zone= quoted",             r, "zone", "=")
assert_eq("quoted value",                 r and r.filter.descriptor.values[1], "Elwynn Forest")

r = P:Parse('zone="val 1"|"val 2"')
assert_filter("zone= quoted OR",          r, "zone", "=")
assert_eq("quoted OR val[1]",             r and r.filter.descriptor.values[1], "val 1")
assert_eq("quoted OR val[2]",             r and r.filter.descriptor.values[2], "val 2")

r = P:Parse('zone="He said \\"hi\\""')
assert_filter("escaped quote",            r, "zone", "=")
assert_eq("escaped quote value",          r and r.filter.descriptor.values[1], 'He said "hi"')

r = P:Parse("t=Defias")
assert_filter("title alias t=",           r, "title", "=")

-- ── Shared-infrastructure errors (tested here because they can be
--    triggered by string inputs and are part of the shared parse path)
assert_error("UNKNOWN_KEY",       P:Parse("palyer=Thad"),    "UNKNOWN_KEY")
assert_eq("UNKNOWN_KEY arg",      P:Parse("palyer=Thad").args[1], "palyer")

assert_error("UNCLOSED_QUOTE",    P:Parse('zone="Elwyn'),    "UNCLOSED_QUOTE")
assert_error("EMPTY_VALUE =",     P:Parse("zone="),          "EMPTY_VALUE")
assert_error("EMPTY_VALUE >=",    P:Parse("level>="),        "EMPTY_VALUE")

-- TYPE_MISMATCH: comparison operator on a non-numeric field
assert_error("TYPE_MISMATCH <",   P:Parse("zone<Elwynn"),    "TYPE_MISMATCH")
assert_error("TYPE_MISMATCH >=",  P:Parse("zone>=Elwynn"),   "TYPE_MISMATCH")

-- INVALID_OPERATOR: known key with an unrecognised operator
assert_error("INVALID_OPERATOR",  P:Parse("zone<=>Elwynn"),  "INVALID_OPERATOR")

-- ── Numeric filters ──────────────────────────────────────────────────
r = P:Parse("level=60")
assert_filter("level= exact",       r, "level", "=")
assert_eq("level= val",             r and r.filter.descriptor.val, 60)

r = P:Parse("level>=60")
assert_filter("level>= op",         r, "level", ">=")
assert_eq("level>= val",            r and r.filter.descriptor.val, 60)

r = P:Parse("level<=65")
assert_filter("level<= op",         r, "level", "<=")

r = P:Parse("level<60")
assert_filter("level< op",          r, "level", "<")
assert_eq("level< val",             r and r.filter.descriptor.val, 60)

r = P:Parse("level>60")
assert_filter("level> op",          r, "level", ">")
assert_eq("level> val",             r and r.filter.descriptor.val, 60)

r = P:Parse("step>3")
assert_filter("step> op",           r, "step", ">")
assert_eq("step> val",              r and r.filter.descriptor.val, 3)

r = P:Parse("step<3")
assert_filter("step< op",           r, "step", "<")
assert_eq("step< val",              r and r.filter.descriptor.val, 3)

-- TYPE_MISMATCH: < and > on non-numeric fields
assert_error("TYPE_MISMATCH <  str",  P:Parse("zone<Elwynn"),   "TYPE_MISMATCH")
assert_error("TYPE_MISMATCH >  str",  P:Parse("zone>Elwynn"),   "TYPE_MISMATCH")

-- EMPTY_VALUE for < and >
assert_error("EMPTY_VALUE <",  P:Parse("level<"),  "EMPTY_VALUE")
assert_error("EMPTY_VALUE >",  P:Parse("level>"),  "EMPTY_VALUE")

r = P:Parse("level=60..65")
assert_filter("level range",        r, "level", "range")
assert_eq("range min",              r and r.filter.descriptor.min, 60)
assert_eq("range max",              r and r.filter.descriptor.max, 65)

r = P:Parse("level=60..60")
assert_filter("range single",       r, "level", "range")
assert_eq("range single min",       r and r.filter.descriptor.min, 60)
assert_eq("range single max",       r and r.filter.descriptor.max, 60)

r = P:Parse("lvl>=60")
assert_filter("lvl alias",          r, "level", ">=")

r = P:Parse("l=60")
assert_filter("l alias",            r, "level", "=")

r = P:Parse("step=2")
assert_filter("step= exact",        r, "step", "=")
assert_eq("step= val",              r and r.filter.descriptor.val, 2)

r = P:Parse("level >= 60")
assert_filter("whitespace around",  r, "level", ">=")

-- Numeric error codes
assert_error("INVALID_NUMBER str",  P:Parse("level=abc"),     "INVALID_NUMBER")
assert_error("RANGE_REVERSED",      P:Parse("level=65..60"),  "RANGE_REVERSED")
local rr = P:Parse("level=65..60")
assert_eq("RANGE_REVERSED min arg", rr and rr.args[1], 65)
assert_eq("RANGE_REVERSED max arg", rr and rr.args[2], 60)

-- ── Enum filters ─────────────────────────────────────────────────────
r = P:Parse("group=yes")
assert_filter("group= yes",         r, "group", "=")
assert_eq("group= canonical",       r and r.filter.descriptor.value, "yes")

r = P:Parse("group=2")
assert_filter("group= 2",           r, "group", "=")
assert_eq("group= 2 canonical",     r and r.filter.descriptor.value, "2")

r = P:Parse("type=chain")
assert_filter("type= chain",        r, "type", "=")
assert_eq("type= canonical",        r and r.filter.descriptor.value, "chain")

r = P:Parse("status=complete")
assert_filter("status= complete",   r, "status", "=")
assert_eq("status= value",          r and r.filter.descriptor.value, "complete")

r = P:Parse("status!=incomplete")
assert_filter("status!= op",        r, "status", "!=")

r = P:Parse("tracked=yes")
assert_filter("tracked= yes",       r, "tracked", "=")
assert_eq("tracked= value",         r and r.filter.descriptor.value, "yes")

r = P:Parse("shareable=yes")
assert_filter("shareable= yes",     r, "shareable", "=")
assert_eq("shareable= value",       r and r.filter.descriptor.value, "yes")

r = P:Parse("shareable=no")
assert_filter("shareable= no",      r, "shareable", "=")
assert_eq("shareable=no value",     r and r.filter.descriptor.value, "no")

-- Operator variant: != and ~= produce identical results
local r1, r2 = P:Parse("status!=complete"), P:Parse("status~=complete")
assert_eq("!= and ~= same op",
    r1 and r1.filter.descriptor.op,
    r2 and r2.filter.descriptor.op)
assert_eq("~= normalizes to !=",
    r1 and r1.filter.descriptor.op,
    "!=")

-- Enum error
assert_error("INVALID_ENUM",        P:Parse("type=dungeon"),  "INVALID_ENUM")
local ie = P:Parse("type=dungeon")
assert_eq("INVALID_ENUM canonical", ie and ie.args[1], "type")
assert_eq("INVALID_ENUM value",     ie and ie.args[2], "dungeon")

-- ── & operator (compound_and) ────────────────────────────────────────

-- Helper: confirm a result is a compound_and with N parts
local function assert_compound(label, result, canonical, nParts)
    if result and result.filter
       and result.filter.canonical == canonical
       and result.filter.descriptor.type == "compound_and"
       and #result.filter.descriptor.parts == nParts then
        pass = pass + 1
    else
        fail = fail + 1
        local got = result and result.filter and result.filter.descriptor.type or "nil"
        print(string.format("FAIL [%s]: expected compound_and(%d) canonical=%s, got %s",
            label, nParts, canonical, got))
    end
end

-- Numeric & with explicit operators on both sides
r = P:Parse("level>=55&<=62")
assert_compound("numeric & 2-part", r, "level", 2)
assert_eq("part1 op", r and r.filter.descriptor.parts[1].op, ">=")
assert_eq("part1 val", r and r.filter.descriptor.parts[1].val, 55)
assert_eq("part2 op", r and r.filter.descriptor.parts[2].op, "<=")
assert_eq("part2 val", r and r.filter.descriptor.parts[2].val, 62)

-- Enum & with inherited operator
r = P:Parse("type=chain&group")
assert_compound("enum & inherited op", r, "type", 2)
assert_eq("enum part1 op", r and r.filter.descriptor.parts[1].op, "=")
assert_eq("enum part1 val", r and r.filter.descriptor.parts[1].value, "chain")
assert_eq("enum part2 op", r and r.filter.descriptor.parts[2].op, "=")
assert_eq("enum part2 val", r and r.filter.descriptor.parts[2].value, "group")

-- String & with inherited operator
r = P:Parse("title=dragon&slayer")
assert_compound("string & inherited op", r, "title", 2)
assert_eq("string part1 val[1]", r and r.filter.descriptor.parts[1].values[1], "dragon")
assert_eq("string part2 val[1]", r and r.filter.descriptor.parts[2].values[1], "slayer")

-- Whitespace around &
r = P:Parse("level >= 55 & <= 62")
assert_compound("& whitespace tolerance", r, "level", 2)
assert_eq("& ws part1 val", r and r.filter.descriptor.parts[1].val, 55)

-- raw field preserved
r = P:Parse("level>=55&<=62")
assert_eq("& raw field", r and r.filter.raw, "level>=55&<=62")

-- MIXED_AND_OR error
assert_error("MIXED_AND_OR |&", P:Parse("level>=55&<=62|58"), "MIXED_AND_OR")
assert_error("MIXED_AND_OR &|", P:Parse("type=chain|group&solo"), "MIXED_AND_OR")

-- & inside a quoted string must NOT split (quote-awareness test)
r = P:Parse('title="a&b"')
assert_filter('quoted & no split', r, "title", "=")
assert_eq('quoted & value', r and r.filter.descriptor.values[1], "a&b")
assert_nil('quoted & not compound', r and r.filter.descriptor.type)
-- descriptor.type is nil for a plain string descriptor (no "compound_and" field)

-- EMPTY_VALUE on trailing &
assert_error("& trailing EMPTY_VALUE", P:Parse("level>=55&"), "EMPTY_VALUE")

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
