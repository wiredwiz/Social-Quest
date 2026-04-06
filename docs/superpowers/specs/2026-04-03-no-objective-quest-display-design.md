# No-Objective Quest Status Display — Design Spec

## Goal

Quests with no numeric X/Y objectives (travel, talk-to-NPC, exploration) currently show no
progress indicator in any tab. Add a "In Progress" / "Complete" / "Finished" status indicator
so players can tell at a glance where each party member stands on these quests.

---

## Scope

**All three tabs:** Mine, Party, Shared.
**Trigger:** Quest has no numeric objectives (`numRequired == 0` for all objectives, or no
objectives at all) AND `isComplete` is a reliable signal (transmitted in the SQ wire protocol
for remote players; available from AQL cache for the local player).

---

## Architecture

Changes confined to two areas:
- `UI/RowFactory.lua` — new helper, updated badge logic, updated player row rendering
- All 12 locale files — two new keys: `"In Progress"` and `"Finished"`

No changes to AQL, GroupData, Communications, or any tab file.

---

## Text and Style Standards

Player row status words — **no parentheses, title case**:

| State | Text | Color |
|---|---|---|
| Quest turned in | `Finished` | green (`GetUIColor("completed")`) |
| Objectives done, not turned in | `Complete` | green (`GetUIColor("completed")`) |
| No-objective quest, not done yet | `In Progress` | dimmed grey (`C.unknown`) |

Title row badges (right-aligned, **with parentheses**, Mine tab only except `(Group)`):

| Badge | When shown |
|---|---|
| `(Complete)` | `isComplete == true` — Mine tab, existing behavior, no change |
| `(Group)` | `suggestedGroup > 0` — all three tabs, existing behavior, no change |
| `(In Progress)` | no-objective AND `isComplete == false` — Mine tab only, **NEW** |

---

## Components

### New private helper: `isNoObjectiveQuest(objectives)`

Added to the Private helpers section of `RowFactory.lua`:

```lua
local function isNoObjectiveQuest(objectives)
    if not objectives or #objectives == 0 then return true end
    for _, obj in ipairs(objectives) do
        if obj.numRequired and obj.numRequired > 0 then return false end
    end
    return true
end
```

Returns `true` when a quest has no trackable numeric objectives: nil/empty array, or all
entries have `numRequired == 0` or nil.

---

### `AddQuestRow` — title row badge (Mine tab only)

Badge priority order: `(Complete)` → `(Group)` → `(In Progress)`.
`(In Progress)` is last so it never displaces either existing badge:

```lua
if questEntry.isComplete and callbacks and callbacks.onTitleShiftClick then
    badgeText = GetUIColor("completed") .. L["(Complete)"] .. C.reset
elseif questEntry.suggestedGroup and questEntry.suggestedGroup > 0 then
    badgeText = C.chain .. L["(Group)"] .. C.reset
elseif not questEntry.isComplete
    and callbacks and callbacks.onTitleShiftClick
    and isNoObjectiveQuest(questEntry.objectives) then
    badgeText = C.unknown .. L["(In Progress)"] .. C.reset   -- NEW
end
```

- `callbacks.onTitleShiftClick` gates all three cases to **Mine tab only**.
- `(Group)` already shows on Party/Shared tabs today (the `isComplete` check fails without
  `onTitleShiftClick`, so `(Group)` fires) — this is correct and unchanged.
- Mine tab never calls `AddPlayerRow` for no-objective quests (gated by `if #objs > 0`),
  so the title row badge is the sole indicator there. This mirrors the quest log's own
  `(Complete)` display style.

---

### `AddPlayerRow` — player sub-rows (Party and Shared tabs)

#### Two-column rendering helper (local, inline)

When `nameColumnWidth` is provided, status rows use the same two-column layout as
objective bars: player name in the left column, status text left-aligned at `barX`:

```lua
-- Used by hasCompleted, isComplete, and no-objective cases when nameColumnWidth is set.
local function renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName, statusText, color, C)
    local barX = x + nameColumnWidth + 4
    local nameFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    nameFs:SetSize(nameColumnWidth, ROW_H)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetJustifyV("MIDDLE")
    nameFs:SetText(C.white .. displayName .. C.reset)
    local statusFs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", barX, -y)
    statusFs:SetWidth(CONTENT_WIDTH - barX - 4)
    statusFs:SetJustifyH("LEFT")
    statusFs:SetJustifyV("MIDDLE")
    statusFs:SetText(color .. statusText .. C.reset)
    return y + ROW_H + 2
end
```

When `nameColumnWidth` is nil (Mine tab peer rows, fallback), fall back to a single
left-aligned string: `displayName .. " " .. statusText`.

#### Updated priority chain

```
1. hasCompleted  → "Finished"    (green)
2. isComplete    → "Complete"    (green)
3. needsShare    → "Needs it Shared"  (grey, unchanged)
4. ineligReason  → "[reason]"    (amber, unchanged)
5. NEW: hasSocialQuest AND isNoObjectiveQuest → "In Progress"  (dimmed grey)
6. !hasSocialQuest + no objectives → "(no data)"  (grey, unchanged)
7. else          → objective bars or plain text    (unchanged)
```

Cases 1 and 2 are updated to use `renderStatusRow` when `nameColumnWidth` is set.
Case 5 is new, also uses `renderStatusRow`.

#### Case 1 — `hasCompleted` (updated)

```lua
if playerEntry.hasCompleted then
    if nameColumnWidth then
        return renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName,
            L["Finished"], GetUIColor("completed"), C)
    else
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(GetUIColor("completed") .. displayName .. " " .. L["Finished"] .. C.reset)
        return y + ROW_H + 2
    end
```

#### Case 2 — `isComplete` (updated)

Same structure as case 1, using `L["Complete"]` and `GetUIColor("completed")`.

#### Case 5 — `isNoObjectiveQuest` (new)

```lua
elseif playerEntry.hasSocialQuest and isNoObjectiveQuest(playerEntry.objectives) then
    if nameColumnWidth then
        return renderStatusRow(contentFrame, y, x, nameColumnWidth, displayName,
            L["In Progress"], C.unknown, C)
    else
        local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
        fs:SetWidth(CONTENT_WIDTH - x - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText(C.white .. displayName .. C.reset .. " " .. C.unknown .. L["In Progress"] .. C.reset)
        return y + ROW_H + 2
    end
```

---

### Locale

Two new keys added to all 12 locale files. `enUS = true`. Non-English strings must follow
the SQ localization standard: natural WoW-appropriate phrasing in each language, not
literal translations.

| Key | Used in |
|---|---|
| `L["In Progress"]` | Player rows (case 5) — no parens |
| `L["(In Progress)"]` | Mine tab title row badge — with parens, consistent with `(Complete)` and `(Group)` |
| `L["Finished"]` | Player rows (case 1) — no parens |

`L["Complete"]` and `L["(Complete)"]` already exist — no change.
`L["%s FINISHED"]` is no longer used — both the two-column path and the single-string
fallback now use `L["Finished"]` directly. Remove `L["%s FINISHED"]` from all locale files.

---

## What Does NOT Change

- `AQL` — `isComplete` and `objectives` already available
- `GroupData.lua` — `isComplete` already transmitted and decoded as boolean
- `MineTab.lua`, `PartyTab.lua`, `SharedTab.lua` — no changes; `nameColumnWidth` is already
  calculated and passed for every `AddPlayerRow` call in Party/Shared
- `(Complete)` and `(Group)` badge behaviour — unchanged
- Mine tab `AddPlayerRow` call site — already gated on `#objs > 0`; no-objective quests
  on Mine tab are handled entirely by the title row badge

---

## Data Flow

| Tab | `isComplete` source | `objectives` source | `nameColumnWidth` |
|---|---|---|---|
| Mine (title row) | `questInfo.isComplete` from AQL cache | `questInfo.objectives` from AQL | n/a (badge only) |
| Party | `qdata.isComplete` from transmitted snapshot | `qdata.objectives` | calculated from player names |
| Shared | `qdata.isComplete` from transmitted snapshot | `qdata.objectives` | calculated from player names |
