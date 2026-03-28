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

-- Split valueStr on unquoted & characters.
-- Returns a table of fragment strings (trimmed), or nil if no unquoted & found.
local function splitOnAmpersand(str)
    local parts = {}
    local current = {}
    local inQ = false
    local i = 1
    local found = false
    while i <= #str do
        local c = str:sub(i, i)
        if c == '"' then
            inQ = not inQ
            current[#current+1] = c
        elseif c == '\\' and inQ and i+1 <= #str then
            current[#current+1] = c
            current[#current+1] = str:sub(i+1, i+1)
            i = i + 1  -- extra increment; the i=i+1 at bottom will make it i+2 total
        elseif c == '&' and not inQ then
            parts[#parts+1] = table.concat(current):match("^%s*(.-)%s*$")
            current = {}
            found = true
        else
            current[#current+1] = c
        end
        i = i + 1
    end
    if not found then return nil end
    parts[#parts+1] = table.concat(current):match("^%s*(.-)%s*$")
    return parts
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

    -- ── compound_and: & splits the value into multiple fragments ──────
    local fragments = splitOnAmpersand(valueStr)
    if fragments then
        -- Check for mixed & and | (unquoted | in the original valueStr).
        local hasPipe = false
        do
            local p2, inQ2 = 1, false
            while p2 <= #valueStr do
                local c2 = valueStr:sub(p2, p2)
                if c2 == '"' then inQ2 = not inQ2
                elseif c2 == '\\' and inQ2 then p2 = p2 + 1
                elseif c2 == '|' and not inQ2 then hasPipe = true; break
                end
                p2 = p2 + 1
            end
        end
        if hasPipe then return makeError("MIXED_AND_OR", {}) end

        local parts = {}

        -- Parse first fragment: its value is fragments[1]; key and op already extracted.
        local firstResult = SocialQuestFilterParser:_ParseFragment(keyDef, op, normOp, fragments[1])
        if firstResult.error then return firstResult end
        parts[#parts+1] = firstResult

        -- Parse subsequent fragments: each is "op val" or "val" (inherit op).
        local _fragOpPats = {
            "^(~=)%s*(.*)", "^(!=)%s*(.*)",
            "^(<=)%s*(.*)", "^(>=)%s*(.*)",
            "^(<)%s*(.*)",  "^(>)%s*(.*)",
            "^(=)%s*(.*)",
        }
        for fi = 2, #fragments do
            local frag = fragments[fi]
            if not frag or frag == "" then
                return makeError("EMPTY_VALUE", {op})
            end
            local fragOp, fragVal = nil, nil
            for _, fpat in ipairs(_fragOpPats) do
                fragOp, fragVal = frag:match(fpat)
                if fragOp then break end
            end
            if not fragOp then
                fragOp = normOp
                fragVal = frag
            else
                fragOp = (fragOp == "~=" and "!=" or fragOp)
            end
            local fragIsComp = (fragOp=="<" or fragOp==">" or fragOp=="<=" or fragOp==">=")
            if fragIsComp and keyDef.type ~= "numeric" then
                return makeError("TYPE_MISMATCH", {fragOp, keyDef.canonical})
            end
            local fragResult = SocialQuestFilterParser:_ParseFragment(keyDef, fragOp, fragOp, fragVal)
            if fragResult.error then return fragResult end
            parts[#parts+1] = fragResult
        end

        return { filter = { canonical=keyDef.canonical,
                            descriptor={ type="compound_and", parts=parts },
                            raw=text } }
    end
    -- ── End compound_and ──────────────────────────────────────────────

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

    if keyDef.type == "enum" then
        local values, err = parseValues(valueStr, op)
        if err then return err end
        local v = values[1]:lower()
        local canonicalVal = keyDef.enumMap and keyDef.enumMap[v]
        if not canonicalVal then
            return makeError("INVALID_ENUM", {keyDef.canonical, values[1]})
        end
        return { filter = { canonical=keyDef.canonical,
                            descriptor={ op=normOp, value=canonicalVal },
                            raw=text } }
    end

    return nil
end

-- Internal helper: parse a single value fragment for a given keyDef/op pair.
-- Returns a descriptor table on success, or { error=true, ... } on failure.
-- Does NOT produce a full filter result — callers wrap descriptors into compound_and.parts.
function SocialQuestFilterParser:_ParseFragment(keyDef, rawOp, normOp, valueStr)
    if not valueStr or valueStr:match("^%s*$") then
        return makeError("EMPTY_VALUE", {rawOp})
    end
    if keyDef.type == "string" then
        local values, err = parseValues(valueStr, rawOp)
        if err then return err end
        return { op=normOp, values=values }
    end
    if keyDef.type == "numeric" then
        local values, err = parseValues(valueStr, rawOp)
        if err then return err end
        local v = values[1]
        local minS, maxS = v:match("^(.-)%.%.(.+)$")
        if minS then
            local minN = tonumber(minS:match("^%s*(.-)%s*$"))
            local maxN = tonumber(maxS:match("^%s*(.-)%s*$"))
            if not minN then return makeError("INVALID_NUMBER", {keyDef.canonical, minS}) end
            if not maxN then return makeError("INVALID_NUMBER", {keyDef.canonical, maxS}) end
            if minN > maxN then return makeError("RANGE_REVERSED", {minN, maxN}) end
            return { op="range", min=minN, max=maxN }
        else
            local n = tonumber(v)
            if not n then return makeError("INVALID_NUMBER", {keyDef.canonical, v}) end
            return { op=normOp, val=n }
        end
    end
    if keyDef.type == "enum" then
        local values, err = parseValues(valueStr, rawOp)
        if err then return err end
        local v = values[1]:lower()
        local canonicalVal = keyDef.enumMap and keyDef.enumMap[v]
        if not canonicalVal then
            return makeError("INVALID_ENUM", {keyDef.canonical, values[1]})
        end
        return { op=normOp, value=canonicalVal }
    end
    return makeError("EMPTY_VALUE", {rawOp})
end
