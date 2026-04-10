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

-- Nudges `frame` the minimum amount needed to be fully within the visible
-- UI area. Called once at open time — not a persistent clamp.
-- Safe to call when no saved position exists; no-op if frame is already on-screen.
-- Uses GetLeft/Right/Top/Bottom directly (same coordinate space as UIParent
-- GetRight/Top) — no scale math required.
function SocialQuestWowUI.ClampFrameToScreen(frame)
    local left   = frame:GetLeft()
    local right  = frame:GetRight()
    local top    = frame:GetTop()
    local bottom = frame:GetBottom()
    if not left then return end  -- frame not yet laid out; skip

    local sw = UIParent:GetRight()   -- screen width in UI coordinates
    local sh = UIParent:GetTop()     -- screen height in UI coordinates

    -- X axis: two-pass so left edge takes priority when frame is wider than screen.
    local dx = 0
    if right > sw    then dx = sw - right end  -- off right  → shift left  (dx negative)
    if left + dx < 0 then dx = -left      end  -- off left   → shift right (dx positive)

    -- Y axis: two-pass so top edge takes priority when frame is taller than screen.
    local dy = 0
    if bottom < 0      then dy = -bottom    end  -- off bottom → shift up   (dy positive)
    if top + dy > sh   then dy = sh - top   end  -- off top    → shift down (dy negative)

    if dx ~= 0 or dy ~= 0 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
    end
end
