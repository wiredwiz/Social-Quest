-- UI/FilterParser.lua
SocialQuestFilterParser = {}

local _nameToKey = {}

function SocialQuestFilterParser:Initialize(defs)
    _nameToKey = {}
    for _, def in ipairs(defs) do
        for _, name in ipairs(def.names) do
            _nameToKey[name:lower()] = def
        end
    end
end

local function makeError(code, args)
    return { error = true, code = code, args = args or {} }
end

-- Parse one value token from str at pos (quoted or unquoted).
-- Returns (value, nextPos) on success, or (nil, nil, errorResult) on unclosed quote.
local function parseOneValue(str, pos)
    if pos > #str then return nil, nil, makeError("EMPTY_VALUE", {}) end
    local ws = str:match("^%s*()", pos); pos = ws or pos
    if str:sub(pos, pos) == '"' then
        pos = pos + 1
        local chars = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '\\' and pos+1 <= #str and str:sub(pos+1,pos+1) == '"' then
                chars[#chars+1] = '"'; pos = pos + 2
            elseif c == '"' then
                return table.concat(chars), pos + 1
            else
                chars[#chars+1] = c; pos = pos + 1
            end
        end
        return nil, nil, makeError("UNCLOSED_QUOTE", {})
    else
        local pipePos = str:find("|", pos, true)
        if pipePos then
            return str:sub(pos, pipePos-1):match("^%s*(.-)%s*$"), pipePos
        else
            return str:sub(pos):match("^%s*(.-)%s*$"), #str + 1
        end
    end
end

-- Parse a |-separated list of values. Returns (values_table) or (nil, errorResult).
local function parseValues(valueStr, op)
    if not valueStr or valueStr == "" then
        return nil, makeError("EMPTY_VALUE", {op})
    end
    local values, pos = {}, 1
    while pos <= #valueStr do
        local ws = valueStr:match("^%s*()", pos); pos = ws or pos
        if pos > #valueStr then break end
        if valueStr:sub(pos,pos) == "|" then
            pos = pos + 1
        else
            local val, nextPos, err = parseOneValue(valueStr, pos)
            if err then return nil, err end
            if val == "" then return nil, makeError("EMPTY_VALUE", {op}) end
            values[#values+1] = val
            pos = nextPos
            local wsEnd = valueStr:match("^%s*()", pos); pos = wsEnd or pos
        end
    end
    if #values == 0 then return nil, makeError("EMPTY_VALUE", {op}) end
    return values, nil
end

-- Try each operator pattern (longest first to avoid ambiguity).
local _opPatterns = {
    "^(%w+)%s*(~=)%s*(.*)", "^(%w+)%s*(!=)%s*(.*)",
    "^(%w+)%s*(<=)%s*(.*)", "^(%w+)%s*(>=)%s*(.*)",
    "^(%w+)%s*(<)%s*(.*)",  "^(%w+)%s*(>)%s*(.*)",
    "^(%w+)%s*(=)%s*(.*)",
}
local function extractKeyAndOp(text)
    for i, pat in ipairs(_opPatterns) do
        local k, op, rest = text:match(pat)
        if k then return k, op, rest end
    end
    return nil, nil, nil
end

function SocialQuestFilterParser:Parse(text)
    if not text then return nil end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    -- Check if input contains any operator (=, <, >, !, ~). Fast-fail on plain text.
    if not text:find("[=<>!~]", 1) then return nil end

    local rawKey, op, valueStr = extractKeyAndOp(text)

    -- Input contains operator chars but no operator pattern matched → check for INVALID_OPERATOR.
    if not rawKey then
        local testKey = text:match("^(%w+)")
        if testKey and _nameToKey[testKey:lower()] then
            local afterKey = text:sub(#testKey+1):match("^%s*(.*)")
            local badOp = afterKey:match("^([^%a%d%s\"]+)")
            return makeError("INVALID_OPERATOR", {badOp or "", testKey})
        end
        return nil
    end

    local keyDef = _nameToKey[rawKey:lower()]
    if not keyDef then return makeError("UNKNOWN_KEY", {rawKey}) end

    -- Check for empty value early (shared across all types).
    if not valueStr or valueStr:match("^%s*$") then
        return makeError("EMPTY_VALUE", {op})
    end

    -- If the value starts with operator characters, this might be an attempted
    -- composite operator (e.g. "zone<=>value" parsed as "zone" "<=" ">value").
    -- Detect this as INVALID_OPERATOR.
    local trimmedValue = valueStr:match("^%s*(.*)")
    if trimmedValue and trimmedValue:match("^[<>=!~]") then
        return makeError("INVALID_OPERATOR", {(op .. trimmedValue:match("^([<>=!~].*)")), rawKey})
    end

    local isComparison = (op=="<" or op==">" or op=="<=" or op==">=")
    if isComparison and keyDef.type ~= "numeric" then
        return makeError("TYPE_MISMATCH", {op, keyDef.canonical})
    end

    local normOp = (op == "~=" and "!=" or op)

    if keyDef.type == "string" then
        local values, err = parseValues(valueStr, op)
        if err then return err end
        return { filter = { canonical=keyDef.canonical,
                            descriptor={ op=normOp, values=values },
                            raw=text } }
    end

    if keyDef.type == "numeric" then
        local values, err = parseValues(valueStr, op)
        if err then return err end
        local v = values[1]
        local minS, maxS = v:match("^(.-)%.%.(.+)$")
        if minS then
            local minN = tonumber(minS:match("^%s*(.-)%s*$"))
            local maxN = tonumber(maxS:match("^%s*(.-)%s*$"))
            if not minN then return makeError("INVALID_NUMBER", {keyDef.canonical, minS}) end
            if not maxN then return makeError("INVALID_NUMBER", {keyDef.canonical, maxS}) end
            if minN > maxN then return makeError("RANGE_REVERSED", {minN, maxN}) end
            return { filter = { canonical=keyDef.canonical,
                                descriptor={ op="range", min=minN, max=maxN },
                                raw=text } }
        else
            local n = tonumber(v)
            if not n then return makeError("INVALID_NUMBER", {keyDef.canonical, v}) end
            return { filter = { canonical=keyDef.canonical,
                                descriptor={ op=normOp, val=n },
                                raw=text } }
        end
    end

    -- Enum handling added in Task 4.
    return nil
end
