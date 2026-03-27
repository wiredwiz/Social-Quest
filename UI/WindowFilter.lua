-- UI/WindowFilter.lua
-- Owns per-tab filter state for the SocialQuest group window.
-- Computes the active zone/instance filter from current player location and settings.
-- Provides GetActiveFilter(tabId), GetFilterLabel(tabId), Dismiss(tabId), Reset().

SocialQuestWindowFilter = {}

local SQWowAPI = SocialQuestWowAPI
local L        = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

-- Per-tab dismiss state. [tabId] = true when the user has dismissed the filter for
-- that tab. Cleared on zone change, window close, or settings toggle.
local dismissed = {}

------------------------------------------------------------------------
-- Private helper
------------------------------------------------------------------------

-- Computes the active filter state from game state and current settings.
-- Does NOT check dismissed — callers are responsible for that.
-- Returns { filter = { zone = "..." }, label = "Instance: ..." } or nil.
local function computeFilterState()
    local db = SocialQuest.db.profile

    if db.window.autoFilterInstance then
        local inInstance, instanceType = SQWowAPI.IsInInstance()
        if inInstance and instanceType ~= "none" then
            local zone = SQWowAPI.GetRealZoneText()
            if zone and zone ~= "" then
                return {
                    filter = { zone = zone },
                    label  = string.format(L["Instance: %s"], zone),
                }
            end
        end
    end

    if db.window.autoFilterZone then
        local zone = SQWowAPI.GetRealZoneText()
        if zone and zone ~= "" then
            return {
                filter = { zone = zone },
                label  = string.format(L["Zone: %s"], zone),
            }
        end
    end

    return nil
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Returns { zone = "..." } filter table for tabId, or nil (no filter / dismissed).
function SocialQuestWindowFilter:GetActiveFilter(tabId)
    if dismissed[tabId] then return nil end
    local state = computeFilterState()
    return state and state.filter or nil
end

-- Returns the human-readable filter label string for tabId, or nil.
-- Uses the same priority logic as GetActiveFilter via the shared computeFilterState helper.
function SocialQuestWindowFilter:GetFilterLabel(tabId)
    if dismissed[tabId] then return nil end
    local state = computeFilterState()
    return state and state.label or nil
end

-- Marks this tab's filter as dismissed until Reset() is called.
function SocialQuestWindowFilter:Dismiss(tabId)
    dismissed[tabId] = true
end

-- Clears all dismiss state. Called on zone change, window close, or settings toggle.
function SocialQuestWindowFilter:Reset()
    dismissed = {}
end
