-- UI/FilterParser.lua
-- Pure Lua filter expression parser. No WoW dependencies.
-- Grown incrementally across Tasks 1-4.

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

function SocialQuestFilterParser:Parse(text)
    if not text then return nil end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    if not text:find("=", 1, true) then return nil end
    return nil  -- full implementation added in Tasks 2-4
end
