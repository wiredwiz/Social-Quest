# Progress Bar Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat colored-rectangle progress bars with WoW-native `StatusBar` widgets using the standard `UI-StatusBar` fill texture, a casting bar border, and white text with a drop shadow.

**Architecture:** The bar-layout branch inside `AddPlayerRow` in `UI/RowFactory.lua` is replaced entirely. Each objective bar becomes a `StatusBar` frame with a BACKGROUND dark texture, the native fill managed by `SetValue`, a casting-bar border texture at OVERLAY extending 2px outside the bar, and a white text FontString at OVERLAY with a shadow. The plain-text fallback path and all tab files are unchanged.

**Tech Stack:** Lua 5.1, WoW TBC Classic frame API (`CreateFrame("StatusBar")`, `SetStatusBarTexture`, `SetStatusBarColor`, `SetMinMaxValues`, `SetValue`, `SetBlendMode`), Blizzard textures (`Interface\TargetingFrame\UI-StatusBar`, `Interface\CastingBar\UI-CastingBar-Border`).

**Spec:** `docs/superpowers/specs/2026-03-25-progress-bars-polish-design.md`

---

## File Structure

| File | Change |
|---|---|
| `UI/RowFactory.lua` | Replace bar-layout branch in `AddPlayerRow` (lines ~385–429) |
| `SocialQuest.toc` | Bump `## Version:` from `2.10.0` to `2.10.1` |
| `CLAUDE.md` | Add `### Version 2.10.1` entry at top of Version History section |

---

## Task 1: Replace bar-layout branch in AddPlayerRow

**Files:**
- Modify: `UI/RowFactory.lua` (bar-layout branch, approximately lines 385–429)

No automated test suite exists for this WoW addon. Verification is in-game after implementation.

- [ ] **Step 1: Read `UI/RowFactory.lua`** to confirm current line numbers of the bar-layout branch. The branch starts at `if nameColumnWidth and obj.numRequired and obj.numRequired > 0 then` and ends at `y = y + ROW_H + 2` before the `else` keyword. Note the exact lines.

- [ ] **Step 2: Replace the bar-layout branch.** Find this entire block:

```lua
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
```

Replace with:

```lua
            if nameColumnWidth and obj.numRequired and obj.numRequired > 0 then
                -- Bar layout (StatusBar widget).
                local barX     = x + nameColumnWidth + 4
                local barWidth = math.max(CONTENT_WIDTH - barX - 4, 0)

                -- Name label (left column).
                local nameFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
                nameFs:SetSize(nameColumnWidth, ROW_H)
                nameFs:SetJustifyH("LEFT")
                nameFs:SetJustifyV("MIDDLE")
                nameFs:SetText(C.white .. displayName .. C.reset)

                if barWidth > 0 then
                    -- StatusBar widget — handles fill clipping natively via SetValue.
                    -- Do NOT call SetClipsChildren; the border texture intentionally
                    -- extends 2px outside the bar bounds on all sides.
                    local statusBar = CreateFrame("StatusBar", nil, contentFrame)
                    statusBar:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", barX, -y)
                    statusBar:SetSize(barWidth, ROW_H)
                    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    statusBar:SetMinMaxValues(0, obj.numRequired)
                    statusBar:SetValue(obj.numFulfilled or 0)
                    local fillClr = SocialQuestColors.GetUIColorRGB(
                        obj.isFinished and "completed" or "active")
                    statusBar:SetStatusBarColor(fillClr.r, fillClr.g, fillClr.b, 0.85)

                    -- Dark background (BACKGROUND — renders behind the fill).
                    local bg = statusBar:CreateTexture(nil, "BACKGROUND")
                    bg:SetColorTexture(0, 0, 0, 0.5)
                    bg:SetAllPoints(statusBar)

                    -- Casting bar border (OVERLAY — transparent center, renders above fill).
                    -- Creation order matters: border must be created before textFs so
                    -- textFs renders on top of the border edges at the same OVERLAY layer.
                    local borderTex = statusBar:CreateTexture(nil, "OVERLAY")
                    borderTex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
                    borderTex:SetBlendMode("BLEND")
                    borderTex:SetPoint("TOPLEFT",     statusBar, "TOPLEFT",     -2,  2)
                    borderTex:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT",  2, -2)

                    -- Objective text (OVERLAY, created after border — renders above border edges).
                    -- Strip embedded WoW color codes so yellow text doesn't appear on yellow fill.
                    local plainText = (obj.text or "")
                        :gsub("|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
                        :gsub("|c%x%x%x%x%x%x%x%x([^|]*)", "%1")
                    local textFs = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    textFs:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
                    textFs:SetSize(barWidth - 8, ROW_H)
                    textFs:SetJustifyH("LEFT")
                    textFs:SetJustifyV("MIDDLE")
                    textFs:SetMaxLines(1)
                    textFs:SetShadowOffset(1, -1)
                    textFs:SetShadowColor(0, 0, 0, 1)
                    textFs:SetText(C.white .. plainText .. C.reset)
                end

                y = y + ROW_H + 6
```

- [ ] **Step 3: Verify the edit.** Re-read the modified section of `UI/RowFactory.lua` and confirm:
  - `fillWidth` and the old `CreateFrame("Frame")` / `SetClipsChildren` / `SetColorTexture` fill code are gone
  - `StatusBar` is created with `SetStatusBarTexture`, `SetMinMaxValues`, `SetValue`, `SetStatusBarColor`
  - `bg` texture is at `BACKGROUND`
  - `borderTex` is at `OVERLAY`, created before `textFs`
  - `textFs` is at `OVERLAY`, has `SetShadowOffset` and `SetShadowColor`
  - Row increment is `ROW_H + 6` (was `ROW_H + 2`)
  - The `else` plain-text fallback path is intact and unchanged

- [ ] **Step 4: Commit.**

```bash
cd "D:\Projects\Wow Addons\Social-Quest"
git add UI/RowFactory.lua
git commit -m "feat: replace flat bars with StatusBar widget and casting bar border"
```

---

## Task 2: Bump version and update CLAUDE.md

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read `SocialQuest.toc`.** Confirm the current `## Version:` line reads `2.10.0`.

- [ ] **Step 2: Update the version line in `SocialQuest.toc`.**

Find:
```
## Version: 2.10.0
```
Replace with:
```
## Version: 2.10.1
```

- [ ] **Step 3: Read `CLAUDE.md`.** Confirm the `## Version History` section starts with `### Version 2.10.0`.

- [ ] **Step 4: Add a new version entry to `CLAUDE.md`.** Insert the following block immediately before the `### Version 2.10.0` line:

```markdown
### Version 2.10.1 (March 2026 — ProgressBars branch)
- Progress Bar Polish: replaced flat colored-rectangle bars with WoW-native `StatusBar` widgets. Each bar now uses the standard `Interface\TargetingFrame\UI-StatusBar` fill texture (the same texture used by health and cast bars), colored at 85% opacity so the texture's built-in highlight stripe and bevel are visible. A `Interface\CastingBar\UI-CastingBar-Border` overlay provides the characteristic tapered border that suggests rounded ends. Objective text is forced white with a 1px drop shadow and has WoW color escape codes stripped, eliminating the yellow-on-yellow readability problem from the previous implementation. Colorblind mode uses sky-blue for completed objectives as before.

```

- [ ] **Step 5: Commit.**

```bash
cd "D:\Projects\Wow Addons\Social-Quest"
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump version to 2.10.1; document progress bar polish"
```

---

## Manual Verification Checklist

Load the addon in WoW TBC Classic (`/reload`) and verify:

- [ ] Addon loads without Lua errors (no red error text in chat)
- [ ] `/sq` opens the group window without errors
- [ ] Party tab — objective bars render as WoW-style bars (not flat color rectangles)
- [ ] Fill texture has visible highlight stripe / bevel (UI-StatusBar shading)
- [ ] A visible border with tapered ends surrounds each bar
- [ ] Fill proportion is correct (e.g., 3/8 fills ~38% of bar width)
- [ ] In-progress bar fill is yellow; completed bar fill is green
- [ ] Objective text is white and readable over both filled and unfilled portions
- [ ] Objective text has a visible drop shadow (dark outline effect)
- [ ] No yellow text on yellow fill (color stripping works)
- [ ] In colorblind mode (`/sq config` → General → Colorblind): completed fill turns sky-blue
- [ ] Bars for multiple players on the same quest are column-aligned (nameColumnWidth pre-pass still works)
- [ ] Shared tab shows the same styled bars
- [ ] Mine tab unchanged (no bars — MineTab never passes nameColumnWidth)
- [ ] Plain-text fallback rows (objectives with no numRequired) unchanged
- [ ] FINISHED / Complete / Needs it Shared special-case rows unchanged
- [ ] If border appears behind the fill: raise borderTex draw layer from `"OVERLAY"` to `"HIGHLIGHT"`
