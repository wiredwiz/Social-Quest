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

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
