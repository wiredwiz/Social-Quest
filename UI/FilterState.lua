-- UI/FilterState.lua
-- Per-tab compound user-typed filter state backed by AceDB char.frameState.activeFilters.
-- Keys are canonical (locale-independent); safe to persist across locale changes.
-- No mass Reset() method — entries are ONLY removed via Dismiss().

SocialQuestFilterState = {}

local function getFilters(tabId)
    local all = SocialQuest.db.char.frameState.activeFilters
    if not all[tabId] then all[tabId] = {} end
    return all[tabId]
end

-- Store or replace the entry for parseResult.filter.canonical on tabId.
-- Does NOT call RequestRefresh() — caller is responsible.
function SocialQuestFilterState:Apply(tabId, parseResult)
    local f = parseResult.filter
    getFilters(tabId)[f.canonical] = { descriptor = f.descriptor, raw = f.raw }
end

-- Remove the entry for canonical on tabId. No-op if not active.
-- Does NOT call RequestRefresh() — caller is responsible.
function SocialQuestFilterState:Dismiss(tabId, canonical)
    getFilters(tabId)[canonical] = nil
end

-- Read-only access to all active filters for tabId. Do not modify the returned table.
function SocialQuestFilterState:GetAll(tabId)
    return getFilters(tabId)
end

-- True when no filters are active for tabId.
function SocialQuestFilterState:IsEmpty(tabId)
    return next(getFilters(tabId)) == nil
end
