-- Core/WowUI.lua
-- Thin pass-through wrappers around volatile WoW UI-layer primitives.
-- These are the UI APIs confirmed to differ across Classic → Retail.
-- Stable WoW UI primitives (CreateFrame, UIParent, hooksecurefunc, etc.)
-- are left as direct calls — they are consistent across all target versions.

SocialQuestWowUI = {}

-- Displays a raid/banner message. Guards against RaidWarningFrame being nil
-- (possible before the UI is fully initialized).
function SocialQuestWowUI.AddRaidNotice(msg, colorInfo)
    if not RaidWarningFrame then return end
    RaidNotice_AddMessage(RaidWarningFrame, msg, colorInfo)
end

-- Tab frame template name. "TabButtonTemplate" was removed in Retail (Dragonflight+);
-- "PanelTabButtonTemplate" is the Retail equivalent.
SocialQuestWowUI.TabButtonTemplate = SocialQuestWowAPI.IS_RETAIL and "PanelTabButtonTemplate" or "TabButtonTemplate"

-- Tab sizing. PanelTemplates_TabResize was reworked in the Dragonflight UI redesign.
-- absoluteSize and tabWidth are optional; pass nil to omit.
function SocialQuestWowUI.TabResize(tab, padding, absoluteSize, tabWidth)
    PanelTemplates_TabResize(tab, padding, absoluteSize, tabWidth)
end

-- Tab state helpers. Same PanelTemplates family as TabResize; reworked in Dragonflight.
function SocialQuestWowUI.SelectTab(tab)
    PanelTemplates_SelectTab(tab)
end

function SocialQuestWowUI.DeselectTab(tab)
    PanelTemplates_DeselectTab(tab)
end

-- Chat frame output. Included for completeness — WoW-specific object method.
function SocialQuestWowUI.AddChatMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end
