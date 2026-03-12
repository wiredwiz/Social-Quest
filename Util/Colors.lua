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
    accepted  = { r = 0,     g = 1,     b = 0     },  -- green  (#00FF00)
    completed = { r = 1,     g = 0.843, b = 0     },  -- gold   (#FFD700)
    finished  = { r = 0,     g = 0.8,   b = 1     },  -- cyan   (#00CCFF)
    abandoned = { r = 0.533, g = 0.533, b = 0.533 },  -- grey   (#888888)
    failed    = { r = 1,     g = 0,     b = 0     },  -- red    (#FF0000)
}
