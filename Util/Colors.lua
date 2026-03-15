-- Util/Colors.lua
-- Color constants used across SocialQuest UI files.

SocialQuestColors = {
    -- Quest state colors
    active    = "|cFFFFFF00",  -- yellow
    completed = "|cFF00FF00",  -- green
    failed    = "|cFFFF0000",  -- red
    unknown   = "|cFF888888",  -- grey
    header    = "|cFFFFD700",  -- gold
    chain     = "|cFF00CCFF",  -- cyan
    timer     = "|cFFFF8C00",  -- orange
    -- General
    white     = "|cFFFFFFFF",
    reset     = "|r",
}

SocialQuestColors.event = {
    accepted           = { r = 0,     g = 1,     b = 0     },  -- green  (#00FF00)
    completed          = { r = 1,     g = 0.843, b = 0     },  -- gold   (#FFD700)
    finished           = { r = 0,     g = 0.8,   b = 1     },  -- cyan   (#00CCFF)
    abandoned          = { r = 0.533, g = 0.533, b = 0.533 },  -- grey   (#888888)
    failed             = { r = 1,     g = 0,     b = 0     },  -- red    (#FF0000)
    objective_progress = { r = 1,     g = 0.6,   b = 0     },  -- orange (#FF9900)
    objective_complete = { r = 0.4,   g = 1,     b = 0.4   },  -- lime   (#66FF66)
    all_complete       = { r = 0.6,   g = 0.0,   b = 0.9   },  -- purple (#9900E6)
}

SocialQuestColors.eventCB = {
    accepted           = { r = 0.337, g = 0.706, b = 0.914 },  -- sky blue       (#56B4E9)
    completed          = { r = 1,     g = 0.843, b = 0     },  -- gold           (#FFD700) unchanged
    finished           = { r = 0,     g = 0.620, b = 0.451 },  -- teal           (#009E73)
    abandoned          = { r = 0.533, g = 0.533, b = 0.533 },  -- grey           (#888888) unchanged
    failed             = { r = 0.835, g = 0.369, b = 0     },  -- vermillion     (#D55E00)
    objective_progress = { r = 0.902, g = 0.624, b = 0     },  -- amber          (#E69F00)
    objective_complete = { r = 0.800, g = 0.475, b = 0.655 },  -- reddish purple (#CC79A7)
    all_complete       = { r = 0.0,   g = 0.447, b = 0.698 },  -- blue   (#0072B2, Okabe-Ito)
}

SocialQuestColors.cbUI = {
    completed = "|cFF56B4E9",  -- sky blue   (replaces green  #00FF00)
    failed    = "|cFFD55E00",  -- vermillion (replaces red    #FF0000)
}

-- Returns true when colorblind mode is active — either WoW's built-in CVar or the
-- SocialQuest override. The CVar check is intentionally first so WoW's global setting
-- always wins, even if the SocialQuest toggle is off.
local function isColorblindMode()
    if GetCVar("colorblindMode") == "1" then return true end
    return SocialQuest and SocialQuest.db
        and SocialQuest.db.profile.general.colorblindMode == true
end

-- Returns the {r,g,b} color for a banner/chat event type.
-- Always call this instead of indexing SocialQuestColors.event directly.
function SocialQuestColors.GetEventColor(eventType)
    local tbl = isColorblindMode() and SocialQuestColors.eventCB or SocialQuestColors.event
    return tbl[eventType]
end

-- Returns the inline color escape string for a UI text key (e.g. "completed", "failed").
-- Falls back to the standard value when no colorblind override is defined for the key.
function SocialQuestColors.GetUIColor(key)
    if isColorblindMode() and SocialQuestColors.cbUI[key] then
        return SocialQuestColors.cbUI[key]
    end
    return SocialQuestColors[key]
end
