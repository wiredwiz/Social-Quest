-- tests/WowUI_test.lua
-- Standalone unit tests for Core/WowUI.lua ClampFrameToScreen.
-- Run from repo root: lua tests/WowUI_test.lua

local f = io.open("Core/WowUI.lua", "r")
if not f then error("Run from repo root: lua tests/WowUI_test.lua") end
f:close()

-- ── Stubs ──────────────────────────────────────────────────────────────────

-- WowUI.lua references SocialQuestWowAPI.IS_RETAIL at module scope.
SocialQuestWowAPI = { IS_RETAIL = false, IS_TBC = true, IS_MOP = false, IS_CLASSIC_ERA = false }

-- WowUI.lua wraps these globals; stub them so dofile doesn't crash.
RaidWarningFrame    = {}
RaidNotice_AddMessage = function() end
PanelTemplates_TabResize   = function() end
PanelTemplates_SelectTab   = function() end
PanelTemplates_DeselectTab = function() end
DEFAULT_CHAT_FRAME  = { AddMessage = function() end }

-- UIParent: standard 1080p screen.
UIParent = {}
function UIParent:GetRight() return 1920 end
function UIParent:GetTop()   return 1080 end
function UIParent:GetLeft()  return 0    end
function UIParent:GetBottom() return 0   end

dofile("Core/WowUI.lua")

-- ── Mock frame builder ──────────────────────────────────────────────────────
-- Creates a frame positioned at (left, top) with the given width and height.
-- Records the last SetPoint call in frame.lastX / frame.lastY.
-- frame.setPointCalled is true if SetPoint was ever called.

local function makeFrame(left, top, width, height)
    local fr = {
        _left   = left,
        _top    = top,
        _right  = left + width,
        _bottom = top  - height,
        lastX   = nil,
        lastY   = nil,
        setPointCalled = false,
    }
    function fr:GetLeft()   return self._left   end
    function fr:GetRight()  return self._right  end
    function fr:GetTop()    return self._top    end
    function fr:GetBottom() return self._bottom end
    function fr:ClearAllPoints() end
    function fr:SetPoint(_, _, _, x, y)
        self.setPointCalled = true
        self.lastX = x
        self.lastY = y
    end
    return fr
end

-- ── Test helpers ────────────────────────────────────────────────────────────

local pass, fail = 0, 0

local function assert_eq(label, expected, got)
    if expected == got then
        pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected %s, got %s",
            label, tostring(expected), tostring(got)))
    end
end

local function assert_false(label, got)
    if got == false or got == nil then pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL [%s]: expected false/nil, got %s", label, tostring(got)))
    end
end

-- ── Tests ───────────────────────────────────────────────────────────────────

-- 1. Frame fully on-screen: no SetPoint call.
do
    local fr = makeFrame(100, 800, 400, 300)
    -- left=100, right=500, top=800, bottom=500 — all within 1920×1080
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_false("on_screen: SetPoint not called", fr.setPointCalled)
end

-- 2. Frame off the right edge: shifted left.
do
    local fr = makeFrame(1600, 800, 400, 300)
    -- right=2000 > 1920 → dx = 1920-2000 = -80 → new left = 1520
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_right: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_right: x", 1520, fr.lastX)
    assert_eq("off_right: y unchanged", 800, fr.lastY)
end

-- 3. Frame off the left edge: shifted right.
do
    local fr = makeFrame(-50, 800, 400, 300)
    -- left=-50 < 0 → dx = 50 → new left = 0
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_left: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_left: x", 0, fr.lastX)
    assert_eq("off_left: y unchanged", 800, fr.lastY)
end

-- 4. Frame off the top edge: shifted down.
do
    local fr = makeFrame(100, 1200, 400, 300)
    -- top=1200 > 1080 → dy = 1080-1200 = -120 → new top = 1080
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_top: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_top: x unchanged", 100, fr.lastX)
    assert_eq("off_top: y", 1080, fr.lastY)
end

-- 5. Frame off the bottom edge: shifted up.
do
    local fr = makeFrame(100, 100, 400, 300)
    -- bottom = 100-300 = -200 < 0 → dy = 200 → new top = 300
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_bottom: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_bottom: x unchanged", 100, fr.lastX)
    assert_eq("off_bottom: y", 300, fr.lastY)
end

-- 6. Frame off both right and bottom edges: both axes corrected.
do
    local fr = makeFrame(1700, 200, 400, 300)
    -- right=2100>1920 → dx=-180; left+dx=1520≥0 so no left override
    -- bottom=200-300=-100<0 → dy=100 → new top=300
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("off_right_bottom: setPointCalled", true, fr.setPointCalled)
    assert_eq("off_right_bottom: x", 1520, fr.lastX)
    assert_eq("off_right_bottom: y", 300,  fr.lastY)
end

-- 7. Frame wider than screen: left edge wins.
do
    local fr = makeFrame(-100, 800, 2500, 300)
    -- right=2400>1920 → dx=1920-2400=-480; left+dx=-100+(-480)=-580<0 → dx=-left=100
    -- new left = 0 (left edge pinned)
    SocialQuestWowUI.ClampFrameToScreen(fr)
    assert_eq("wider_than_screen: setPointCalled", true, fr.setPointCalled)
    assert_eq("wider_than_screen: x", 0, fr.lastX)
    assert_eq("wider_than_screen: y unchanged", 800, fr.lastY)
end

-- 8. Frame with nil GetLeft (not yet laid out): no-op, no error.
do
    local fr = makeFrame(100, 800, 400, 300)
    fr.GetLeft = function() return nil end
    local ok = pcall(SocialQuestWowUI.ClampFrameToScreen, fr)
    assert_eq("nil_getleft: no error", true, ok)
    assert_false("nil_getleft: SetPoint not called", fr.setPointCalled)
end

-- ── Results ─────────────────────────────────────────────────────────────────

print(string.format("\nResults: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
