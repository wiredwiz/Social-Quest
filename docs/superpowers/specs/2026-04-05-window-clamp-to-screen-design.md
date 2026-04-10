# Window Clamp-to-Screen Design

## Goal

Ensure the SocialQuest group window and the `/sq diagnose` console window are never
fully or partially off-screen when they open. If a saved position would place the window
outside the visible UI area (e.g. after a monitor change or drag-off-screen), the window
is nudged the minimum amount needed to be fully on-screen. Dragging partially off-screen
during a session is still allowed — the correction only fires at open time.

## Architecture

A single shared utility `SQWowUI.ClampFrameToScreen(frame)` is added to `Core/WowUI.lua`.
Both windows call it at the end of their positioning/show path. No persistent clamping
(`SetClampedToScreen`) is used — clamping is a one-shot adjustment at open time only.

## The Utility: `SQWowUI.ClampFrameToScreen(frame)`

Added to `Core/WowUI.lua`.

Reads the frame's actual rendered edges after `SetPoint` has been called, computes the
minimum X/Y shift to bring all four edges within `UIParent` bounds, and re-anchors if
any shift is needed. Uses `GetLeft()` / `GetRight()` / `GetTop()` / `GetBottom()` and
`UIParent:GetRight()` / `UIParent:GetTop()` directly — same coordinate space, no scale
math required (lesson from help-window positioning work in 2.12.24).

```lua
function SocialQuestWowUI.ClampFrameToScreen(frame)
    local left   = frame:GetLeft()
    local right  = frame:GetRight()
    local top    = frame:GetTop()
    local bottom = frame:GetBottom()
    if not left then return end  -- frame not yet laid out; skip

    local sw = UIParent:GetRight()   -- screen width in UI coordinates
    local sh = UIParent:GetTop()     -- screen height in UI coordinates

    -- X axis: two-pass so left edge takes priority over right edge.
    local dx = 0
    if right > sw    then dx = sw - right end  -- off right  → shift left  (dx negative)
    if left + dx < 0 then dx = -left      end  -- off left   → shift right (dx positive)

    -- Y axis: two-pass so top edge takes priority over bottom edge.
    local dy = 0
    if bottom < 0      then dy = -bottom    end  -- off bottom → shift up   (dy positive)
    if top + dy > sh   then dy = sh - top   end  -- off top    → shift down (dy negative)

    if dx ~= 0 or dy ~= 0 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
    end
end
```

Priority rules:
- If the frame is wider than the screen: left edge is always visible (title bar accessible).
- If the frame is taller than the screen: top edge is always visible.
- If the frame fits on screen but is off one edge: exactly one check on each axis fires,
  producing the minimum shift needed.

## Call Sites in `UI/GroupFrame.lua`

### Group window — `applyFrameState(f)`

`applyFrameState` is already called in both `Toggle()` and `RestoreAfterTransition()`,
covering every code path that opens the window (fresh open, reload, zone transition).
Add one line at the end:

```lua
local function applyFrameState(f)
    local fs = SocialQuest.db.char.frameState
    if fs.frameWidth and fs.frameHeight then
        f:SetSize(fs.frameWidth, fs.frameHeight)
    end
    if fs.frameX and fs.frameY then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", fs.frameX, fs.frameY)
    end
    SQWowUI.ClampFrameToScreen(f)   -- nudge on-screen if needed
end
```

The clamp runs whether or not a saved position exists. On first open (no saved position)
the frame sits at its default anchor; ClampFrameToScreen is a no-op if that default is
already on-screen.

### Console window — restore geometry block

The console restore block runs once at window creation. Add one line at the end:

```lua
do
    local cs = SocialQuest.db.char.frameState.console
    if cs.width and cs.height then f:SetSize(cs.width, cs.height) end
    f._sepFrac = cs.sepFrac or 0.38
    if cs.x and cs.y then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cs.x, cs.y)
    end
    SQWowUI.ClampFrameToScreen(f)   -- nudge on-screen if needed
end
```

## What Is NOT Changed

- Drag behavior — users can still drag either window partially or fully off-screen.
- Saved positions — the bad position is NOT cleared from AceDB. On the next open the
  clamp fires again and nudges it back. This is intentional: if the user later returns
  to the machine/resolution where that position made sense, it works correctly again.
- Help window — it already has its own bounds-checking logic; out of scope.
- `SetClampedToScreen` — not used anywhere; this is open-time correction only.

## Files Changed

| File | Change |
|---|---|
| `Core/WowUI.lua` | Add `SQWowUI.ClampFrameToScreen(frame)` |
| `UI/GroupFrame.lua` | Add `SQWowUI.ClampFrameToScreen(f)` at end of `applyFrameState()` |
| `UI/GroupFrame.lua` | Add `SQWowUI.ClampFrameToScreen(f)` at end of console restore block |
