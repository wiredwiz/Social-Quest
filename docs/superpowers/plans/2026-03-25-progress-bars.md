# Progress Bars in Group Frame — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace plain objective text rows in the Party and Shared tabs with inline progress bars, where the bar fill is proportional to `numFulfilled/numRequired` and objective text is rendered over the fill.

**Architecture:** `Colors.lua` gains `GetUIColorRGB` for numeric RGB tuples (required by `SetColorTexture`). `RowFactory.lua` gains `GetDisplayName` (centralizes nameTag resolution), `MeasureNameWidth` (cached pixel-width measurer), and a bar-layout path in `AddPlayerRow` triggered by a new optional `nameColumnWidth` parameter. `PartyTab` and `SharedTab` each add a per-entry pre-pass that measures the widest player name before rendering, ensuring all bars in a quest are column-aligned.

**Tech Stack:** Lua 5.1, WoW TBC Classic frame API (`CreateFrame`, `CreateTexture`, `CreateFontString`, `SetColorTexture`, `SetClipsChildren`), Ace3 (AceLocale).

**Spec:** `docs/superpowers/specs/2026-03-25-progress-bars-design.md`

---

## File Structure

| File | Change |
|---|---|
| `Util/Colors.lua` | Add `uiRGB`, `uiCBRGB` tables + `GetUIColorRGB(key)` |
| `UI/RowFactory.lua` | Add `GetDisplayName`, `MeasureNameWidth`; refactor `AddPlayerRow` name resolution; add bar layout path |
| `UI/Tabs/PartyTab.lua` | Add nameColumnWidth pre-pass before each player-row render loop |
| `UI/Tabs/SharedTab.lua` | Same as PartyTab |
| `SocialQuest.toc` | Version bump |
| `CLAUDE.md` | Version history entry |

---

## Chunk 1: Color helper and RowFactory utilities

### Task 1: Add `GetUIColorRGB` to Colors.lua

**Files:**
- Modify: `Util/Colors.lua`

`GetUIColor` returns inline escape strings like `"|cFF00FF00"` — these cannot be passed to `SetColorTexture`, which requires numeric `r, g, b, a` arguments. This task adds the parallel RGB-tuple helper.

- [ ] **Step 1: Read `Util/Colors.lua`** to find the exact end of the file (after the `GetUIColor` function). Add the following block at the very end:

```lua
SocialQuestColors.uiRGB = {
    completed = { r = 0,     g = 1,     b = 0     },  -- green  (#00FF00)
    active    = { r = 1,     g = 1,     b = 0     },  -- yellow (#FFFF00)
}

SocialQuestColors.uiCBRGB = {
    completed = { r = 0.337, g = 0.706, b = 0.914 },  -- sky-blue (#56B4E9)
}

-- Returns {r, g, b} for a UI color key, for use with texture:SetColorTexture().
-- Respects colorblind mode. Falls back to uiRGB when no CB override exists.
-- isColorblindMode() is accessible here as a local upvalue (defined earlier in this file).
function SocialQuestColors.GetUIColorRGB(key)
    if isColorblindMode() and SocialQuestColors.uiCBRGB[key] then
        return SocialQuestColors.uiCBRGB[key]
    end
    return SocialQuestColors.uiRGB[key]
end
```

- [ ] **Step 2: Confirm placement.** `isColorblindMode` is declared `local function isColorblindMode()` earlier in the same file. `GetUIColorRGB` defined after it can access it as an upvalue. No changes to `isColorblindMode` are needed.

- [ ] **Step 3: Commit.**

```bash
git add Util/Colors.lua
git commit -m "feat: add GetUIColorRGB helper for texture fill colors"
```

---

### Task 2: Add `GetDisplayName` and `MeasureNameWidth` to RowFactory.lua

**Files:**
- Modify: `UI/RowFactory.lua`

`GetDisplayName` centralizes the nameTag-suffix logic that currently lives inline in `AddPlayerRow`. `MeasureNameWidth` uses a single lazily-created FontString (cached in a module-level upvalue) to measure pixel widths without per-call allocation.

- [ ] **Step 1: Read `UI/RowFactory.lua`** to confirm the current top section. After line 13 (`local SQWowAPI = SocialQuestWowAPI`), add the cached measurer upvalue:

```lua
local _measureFs  -- cached FontString for MeasureNameWidth; created on first use
```

- [ ] **Step 2: After the `RowFactory.SetContentWidth` function** (after the closing `end` of that function, before the "Private helpers" comment block), add the two new public helpers:

```lua
-- Returns the fully-resolved display name for a playerEntry.
-- Appends the bridge nameTag suffix when dataProvider is set.
-- Call this instead of building the name inline anywhere name display is needed.
function RowFactory.GetDisplayName(playerEntry)
    local name    = playerEntry.name or "Unknown"
    local nameTag = playerEntry.dataProvider
                 and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
    return nameTag and (name .. " " .. nameTag) or name
end

-- Returns the rendered pixel width of displayName at GameFontNormalSmall.
-- Reuses a single cached FontString to avoid per-call frame allocation.
function RowFactory.MeasureNameWidth(displayName)
    if not _measureFs then
        _measureFs = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        _measureFs:Hide()
    end
    _measureFs:SetText(displayName)
    return _measureFs:GetStringWidth()
end
```

- [ ] **Step 3: Refactor the inline name resolution in `AddPlayerRow`.** Find these lines near the top of `AddPlayerRow` (around line 308):

```lua
    local name        = playerEntry.name or "Unknown"
    local nameTag     = playerEntry.dataProvider
                     and SocialQuestBridgeRegistry:GetNameTag(playerEntry.dataProvider)
    local displayName = nameTag and (name .. " " .. nameTag) or name
```

Replace with the single call:

```lua
    local displayName = RowFactory.GetDisplayName(playerEntry)
```

- [ ] **Step 4: Verify** there are no other uses of the old `name`/`nameTag` locals in `AddPlayerRow` after the replacement — they should not exist since they were only used to build `displayName`.

- [ ] **Step 5: Commit.**

```bash
git add UI/RowFactory.lua
git commit -m "feat: add GetDisplayName and MeasureNameWidth helpers to RowFactory"
```

---

## Chunk 2: Bar rendering and tab integration

### Task 3: Add bar layout path to `AddPlayerRow`

**Files:**
- Modify: `UI/RowFactory.lua`

Adds a new optional fifth parameter `nameColumnWidth`. When provided and `obj.numRequired > 0`, renders a two-column bar row (name label left, progress bar right) instead of plain text. Falls back to the existing plain-text layout when `nameColumnWidth` is nil or the objective lacks numeric data.

- [ ] **Step 1: Update the `AddPlayerRow` function signature.** Find:

```lua
function RowFactory.AddPlayerRow(contentFrame, y, playerEntry, indent)
```

Replace with:

```lua
-- nameColumnWidth (optional): pixel width of the name column. When provided,
-- in-progress objectives render as two-column bar rows (name left, bar right).
-- When nil, falls back to plain single-column text layout.
function RowFactory.AddPlayerRow(contentFrame, y, playerEntry, indent, nameColumnWidth)
```

- [ ] **Step 2: Replace the in-progress objectives loop** near the end of `AddPlayerRow`. Find this block (the loop that starts with `-- One row per objective, prefixed with player name.`):

```lua
        -- One row per objective, prefixed with player name.
        for _, obj in ipairs(objectives) do
            local clr = obj.isFinished and SocialQuestColors.GetUIColor("completed") or C.active
            local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
            fs:SetWidth(CONTENT_WIDTH - x - 4)
            fs:SetJustifyH("LEFT")
            fs:SetText(C.white .. displayName .. C.reset .. " " .. clr .. (obj.text or "") .. C.reset)
            y = y + fs:GetStringHeight() + 2
        end
        return y
```

Replace with:

```lua
        -- One row per objective.
        -- Bar layout: when nameColumnWidth is set and objective has numeric data,
        -- render a two-column row (name label left, progress bar right).
        -- Plain text fallback: when nameColumnWidth is nil or numRequired is absent/zero.
        for _, obj in ipairs(objectives) do
            if nameColumnWidth and obj.numRequired and obj.numRequired > 0 then
                -- Bar layout.
                local barX      = x + nameColumnWidth + 4
                local barWidth  = math.max(CONTENT_WIDTH - barX - 4, 0)
                local fillWidth = math.floor(barWidth * ((obj.numFulfilled or 0) / obj.numRequired))

                -- Name label (left column).
                local nameFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
                nameFs:SetSize(nameColumnWidth, ROW_H)
                nameFs:SetJustifyH("LEFT")
                nameFs:SetJustifyV("MIDDLE")
                nameFs:SetText(C.white .. displayName .. C.reset)

                -- Bar container frame (clips children so fill/text stay within bounds).
                local barFrame = CreateFrame("Frame", nil, contentFrame)
                barFrame:SetSize(barWidth, ROW_H)
                barFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", barX, -y)
                barFrame:SetClipsChildren(true)

                -- Dark background texture.
                local bg = barFrame:CreateTexture(nil, "BACKGROUND")
                bg:SetColorTexture(0, 0, 0, 0.35)
                bg:SetAllPoints(barFrame)

                -- Colored fill texture (proportional to progress).
                if fillWidth > 0 then
                    local fillClr = SocialQuestColors.GetUIColorRGB(
                        obj.isFinished and "completed" or "active")
                    local fill = barFrame:CreateTexture(nil, "ARTWORK")
                    fill:SetColorTexture(fillClr.r, fillClr.g, fillClr.b, 0.45)
                    fill:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 0, 0)
                    fill:SetSize(fillWidth, ROW_H)
                end

                -- Objective text overlay (white, single line, 4px left padding).
                local textFs = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                textFs:SetPoint("LEFT", barFrame, "LEFT", 4, 0)
                textFs:SetSize(barWidth - 8, ROW_H)
                textFs:SetJustifyH("LEFT")
                textFs:SetJustifyV("MIDDLE")
                textFs:SetMaxLines(1)
                textFs:SetText(obj.text or "")

                y = y + ROW_H + 2
            else
                -- Plain text fallback (original behavior).
                local clr = obj.isFinished and SocialQuestColors.GetUIColor("completed") or C.active
                local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
                fs:SetWidth(CONTENT_WIDTH - x - 4)
                fs:SetJustifyH("LEFT")
                fs:SetText(C.white .. displayName .. C.reset .. " " .. clr .. (obj.text or "") .. C.reset)
                y = y + fs:GetStringHeight() + 2
            end
        end
        return y
```

- [ ] **Step 3: Verify** `AddPlayerRow` still compiles correctly — count that all `if/else/end` blocks are balanced in the function.

- [ ] **Step 4: Commit.**

```bash
git add UI/RowFactory.lua
git commit -m "feat: add progress bar rendering path to AddPlayerRow"
```

---

### Task 4: Add nameColumnWidth pre-pass to PartyTab

**Files:**
- Modify: `UI/Tabs/PartyTab.lua`

The pre-pass iterates each quest's `entry.players` list before rendering to find the maximum display-name pixel width. This value is then passed as `nameColumnWidth` to every `AddPlayerRow` call for that entry, ensuring all bars in a quest start at the same x position.

Note: `RowFactory` (the global, same object as the `rowFactory` parameter) is used directly for the new helpers since they are module-level functions, not instance methods.

- [ ] **Step 1: Read `UI/Tabs/PartyTab.lua`** to confirm current line numbers. Locate the **chain steps loop** in `Render` (inside the `for _, chainID in ipairs(sortedChainIDs) do` block):

```lua
                for _, entry in ipairs(chain.steps) do
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                    for _, player in ipairs(entry.players) do
                        -- AddPlayerRow renders objectives internally; do not loop here.
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8)
                    end
                end
```

Replace with:

```lua
                for _, entry in ipairs(chain.steps) do
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                    local nameColumnWidth = 0
                    for _, player in ipairs(entry.players) do
                        local w = RowFactory.MeasureNameWidth(RowFactory.GetDisplayName(player))
                        if w > nameColumnWidth then nameColumnWidth = w end
                    end
                    for _, player in ipairs(entry.players) do
                        -- AddPlayerRow renders objectives internally; do not loop here.
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8, nameColumnWidth)
                    end
                end
```

- [ ] **Step 2: Locate the standalone quests loop** in `Render`:

```lua
            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                for _, player in ipairs(entry.players) do
                    -- AddPlayerRow renders objectives internally; do not loop here.
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT)
                end
            end
```

Replace with:

```lua
            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                local nameColumnWidth = 0
                for _, player in ipairs(entry.players) do
                    local w = RowFactory.MeasureNameWidth(RowFactory.GetDisplayName(player))
                    if w > nameColumnWidth then nameColumnWidth = w end
                end
                for _, player in ipairs(entry.players) do
                    -- AddPlayerRow renders objectives internally; do not loop here.
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT, nameColumnWidth)
                end
            end
```

- [ ] **Step 3: Commit.**

```bash
git add UI/Tabs/PartyTab.lua
git commit -m "feat: add nameColumnWidth pre-pass to PartyTab for aligned progress bars"
```

---

### Task 5: Add nameColumnWidth pre-pass to SharedTab, bump version, update CLAUDE.md

**Files:**
- Modify: `UI/Tabs/SharedTab.lua`
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

SharedTab has the same two render loops as PartyTab (chain steps + standalone quests). Apply the identical pre-pass pattern. Then bump the version and record in CLAUDE.md.

- [ ] **Step 1: Read `UI/Tabs/SharedTab.lua`** to confirm current line numbers. Locate the **chain steps loop** in `Render` (inside the `for _, chainID in ipairs(sortedChainIDs) do` block):

```lua
                for _, entry in ipairs(chain.steps) do
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                    for _, player in ipairs(entry.players) do
                        -- AddPlayerRow renders objectives internally; do not loop here.
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8)
                    end
                end
```

Replace with:

```lua
                for _, entry in ipairs(chain.steps) do
                    y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
                    local nameColumnWidth = 0
                    for _, player in ipairs(entry.players) do
                        local w = RowFactory.MeasureNameWidth(RowFactory.GetDisplayName(player))
                        if w > nameColumnWidth then nameColumnWidth = w end
                    end
                    for _, player in ipairs(entry.players) do
                        -- AddPlayerRow renders objectives internally; do not loop here.
                        y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT + 8, nameColumnWidth)
                    end
                end
```

- [ ] **Step 2: Locate the standalone quests loop** in `Render`:

```lua
            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                for _, player in ipairs(entry.players) do
                    -- AddPlayerRow renders objectives internally; do not loop here.
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT)
                end
            end
```

Replace with:

```lua
            for _, entry in ipairs(zone.quests) do
                y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
                local nameColumnWidth = 0
                for _, player in ipairs(entry.players) do
                    local w = RowFactory.MeasureNameWidth(RowFactory.GetDisplayName(player))
                    if w > nameColumnWidth then nameColumnWidth = w end
                end
                for _, player in ipairs(entry.players) do
                    -- AddPlayerRow renders objectives internally; do not loop here.
                    y = rowFactory.AddPlayerRow(contentFrame, y, player, PLAYER_INDENT, nameColumnWidth)
                end
            end
```

- [ ] **Step 3: Bump the version in `SocialQuest.toc`.** Read the current `## Version:` line. The current version at the time this plan was written is `2.9.0`. Apply the versioning rule from `CLAUDE.md`:
  - **First functionality change today on this branch** → increment minor, reset revision → `2.10.0`
  - **Second+ change today** → increment revision only → e.g., `2.9.1`
  - Today is March 25, 2026. If this is the first functionality change on this branch today (which is the common case for a fresh ProgressBars branch), the correct version is **`2.10.0`**.

- [ ] **Step 4: Update `CLAUDE.md`.** Add a new version entry at the top of the Version History section. Use the new version number from Step 3:

```markdown
### Version 2.10.0 (March 2026 — ProgressBars branch)
- Progress Bars: objective rows in the Party and Shared tabs now render as inline progress bars. Each bar fills proportionally to `numFulfilled/numRequired`; objective text overlays the fill in white. Player names appear in a left-aligned column whose width matches the widest name in each quest, so all bars are column-aligned for at-a-glance comparison. Colorblind mode respected. Falls back to plain text for objectives without numeric data. New `GetDisplayName` helper in `RowFactory` centralizes nameTag resolution. New `GetUIColorRGB` helper in `Colors.lua` exposes numeric RGB tuples for texture coloring.
```

- [ ] **Step 5: Commit.**

```bash
git add UI/Tabs/SharedTab.lua SocialQuest.toc CLAUDE.md
git commit -m "feat: add nameColumnWidth pre-pass to SharedTab; bump version"
```

---

### Manual Verification Checklist

Load the addon in WoW TBC Classic and verify (no automated test suite exists for this addon):

- [ ] Addon loads without Lua errors (`/reload` → no red error text)
- [ ] `/sq` opens the group window without errors
- [ ] Party tab — objective rows for party members with in-progress quests render as bars (not plain text)
- [ ] Bar fill proportion is correct (e.g., 3/8 fills ~38% of bar width)
- [ ] All bars for the same quest start at the same x position (column-aligned)
- [ ] Completed objective bar shows green fill; in-progress shows yellow
- [ ] In colorblind mode (`/sq config` → General → Colorblind): completed fill turns sky-blue
- [ ] Objective text is readable over both filled and unfilled portions
- [ ] Special-case rows unchanged: FINISHED (green text), Complete (white+green), Needs it Shared (grey), no data (grey)
- [ ] Shared tab shows the same bar layout
- [ ] Mine tab renders unchanged (no bars — MineTab never passes nameColumnWidth)
- [ ] A quest with a single party member renders the bar with correct alignment (no wasted left space)
- [ ] Window resize / refresh does not leave visual artifacts
