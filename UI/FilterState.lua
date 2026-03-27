-- UI/FilterState.lua
-- Compound user-typed filter state backed by AceDB char.frameState.activeFilters.
-- Keys are canonical (locale-independent); safe to persist across locale changes.
-- No mass Reset() method — entries are ONLY removed via Dismiss().

SocialQuestFilterState = {}

local function getFilters()
    return SocialQuest.db.char.frameState.activeFilters
end

-- Store or replace the entry for parseResult.filter.canonical.
-- Does NOT call RequestRefresh() — caller is responsible.
function SocialQuestFilterState:Apply(parseResult)
    local f = parseResult.filter
    getFilters()[f.canonical] = { descriptor = f.descriptor, raw = f.raw }
end

-- Remove the entry for canonical. No-op if not active.
-- Does NOT call RequestRefresh() — caller is responsible.
function SocialQuestFilterState:Dismiss(canonical)
    getFilters()[canonical] = nil
end

-- Read-only access to all active filters. Do not modify the returned table.
function SocialQuestFilterState:GetAll()
    return getFilters()
end

-- True when no filters are active.
function SocialQuestFilterState:IsEmpty()
    return next(getFilters()) == nil
end
