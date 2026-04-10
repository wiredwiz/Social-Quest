# Quest Chat Links Design

## Goal

Replace SocialQuest's outbound chat link format — currently either a broken native
`|Hquest:...|h` that the WoW chat server strips, or a plain `[Quest Title]` bracket —
with a link format that is actually clickable. Clicking any quest link (SQ-generated,
Questie-generated, or a player's manually-shared link) appends party member progress to
the displayed tooltip when the viewer is in a party.

---

## Background and Root Cause

`SendChatMessage()` passes through the WoW chat server, which strips `|H...|h` hyperlink
escape codes on TBC and Classic. Both sender and recipient see plain text. Only
`DEFAULT_CHAT_FRAME:AddMessage()` (local display) renders links correctly because it
bypasses the server. Native `|Hquest:...|h` links also fail on Retail via
`SendChatMessage` — confirmed by in-game testing.

---

## Architecture

Two components change:

- **`Core/Announcements.lua`** — `BuildQuestLink()` constructs a version-appropriate
  clickable link string for `SendChatMessage`. Used by `OnQuestEvent` and
  `OnObjectiveEvent` in place of the current AQL-generated `questInfo.link`.

- **`UI/Tooltips.lua`** — The existing `addGroupProgressToTooltip` and `Initialize`
  functions are extended to handle the new link types, add a party-only gate, skip the
  local player, and resolve aliased quest IDs on Retail.

No new files are created.

---

## BuildQuestLink (Core/Announcements.lua)

A new module-local function that returns the correct hyperlink string for the current
WoW version.

```lua
local function BuildQuestLink(questID, questName, questLevel)
    if not questID or not questName then return nil end
    local level = questLevel or 0
    if SQWowAPI.IS_RETAIL then
        -- SQ's own link type. SetItemRef hook (Tooltips.lua) forwards it to the
        -- native quest tooltip display.
        return "|Hsocialquest:" .. questID .. ":" .. level
               .. "|h[" .. level .. "] " .. questName .. "|h|r"
    else
        -- Questie-compatible link. Questie users get a clickable tooltip;
        -- non-Questie users see "[level] Quest Name" as readable plain text.
        local senderGUID = UnitGUID("player") or ""
        return "|Hquestie:" .. questID .. ":" .. senderGUID
               .. "|h[" .. level .. "] " .. questName .. "|h|r"
    end
end
```

**Display text** is always `[level] Quest Name` — baked into the string we send, so
every recipient sees the same text regardless of their Questie settings. This matches
the default Questie format (trackerShowQuestLevel = on).

**Non-Retail**: Questie's `SetItemRef` handler fires on click. Non-Questie, non-SQ
users see `[level] Quest Name` as plain readable text — acceptable fallback given that
~95% of non-Retail players have Questie.

**Retail**: SQ registers its own `SetItemRef` hook (see Tooltips section below) because
Questie does not exist on Retail.

---

## Link Sending Changes (Core/Announcements.lua)

### OnQuestEvent

Replace the current `questInfo.link → info.link → title` display fallback chain with
`BuildQuestLink`:

```lua
-- Before:
local display = (questInfo and questInfo.link)
             or (info and info.link)
             or title

-- After:
local level = (questInfo and questInfo.level) or (info and info.level)
local display = BuildQuestLink(questID, title, level) or title
```

`title` is already resolved above this block via the existing three-step chain
(`questInfo.title → AQL:GetQuestTitle → "Quest N"`). `BuildQuestLink` returns nil only
when `questName` is nil, which cannot happen here — `title` is always non-nil.

### OnObjectiveEvent

Replace the current `questInfo.link → questInfo.title` display chain:

```lua
-- Before:
local display = (questInfo and questInfo.link) or (questInfo and questInfo.title)
             or ("Quest " .. questID)

-- After:
local questName  = questInfo and questInfo.title or ("Quest " .. questID)
local questLevel = questInfo and questInfo.level
local display    = BuildQuestLink(questID, questName, questLevel) or questName
```

---

## Tooltip Augmentation (UI/Tooltips.lua)

### addGroupProgressToTooltip — changes

**Party-only gate:** add at the top of the function, before any tooltip work:

```lua
-- Only augment in a party; never in raid or BG.
if not SocialQuestWowAPI.IsInGroup() or SocialQuestWowAPI.IsInRaid() then return end
```

**Skip the local player:** the local player's progress is already shown by the native
WoW quest tooltip or Questie. Compute the local key once and skip it:

```lua
local localName, localRealm = SocialQuestWowAPI.UnitFullName("player")
local localKey = localRealm and (localName .. "-" .. localRealm) or localName
```

Add a guard at the top of the `for playerName, entry` loop:

```lua
if playerName == localKey then goto continue end  -- skip self
```

(Use a standard `if` skip if goto is unavailable in the Lua build: wrap the body in
`if playerName ~= localKey then ... end`.)

**Alias resolution:** replace the direct `entry.quests[questID]` lookup with a helper
that also checks aliased quest IDs on Retail:

```lua
local function resolveQuestData(entry, questID, questTitle)
    if entry.quests and entry.quests[questID] then
        return entry.quests[questID]
    end
    -- Retail alias fallback: scan by title when questID doesn't match directly.
    if SocialQuestWowAPI.IS_RETAIL and questTitle and entry.quests then
        for _, qdata in pairs(entry.quests) do
            if qdata.title == questTitle then return qdata end
        end
    end
    return nil
end
```

`questTitle` is resolved once at the top of `addGroupProgressToTooltip`:

```lua
local questTitle = SocialQuest.AQL and SocialQuest.AQL:GetQuestTitle(questID)
```

Replace `entry.quests and entry.quests[questID]` with `resolveQuestData(entry, questID, questTitle)`.

**Visual format — match Questie's style exactly.**

Questie's "Your progress:" section uses:
- A blank `" "` line before the header (via `_AddTooltipLine(" ")`)
- Plain-text header with no color code: `"Your progress: "`
- Per-objective lines as `AddLine`: `" - " .. color .. description .. ": " .. count .. "|r"`

Our party progress section must look like a natural extension of that. Rules:
1. Blank `" "` separator line before the "Party progress:" header.
2. Header is plain uncolored text: `L["Party progress"] .. ":"`.
3. Each player's row is an `AddLine` (not `AddDoubleLine`) in the same
   `" - name: ..."` style as Questie's objective lines.
4. Objective text is resolved from AQL (`AQL:GetQuestObjectives(questID)`) so
   descriptions are shown, not just counts. Index-matched to `qdata.objectives`.
   If AQL text is unavailable, fall back to count-only `"N/M"`.
5. Multiple objectives for one player are semicolon-separated on the same line.
6. `isComplete` players show `L["Complete"]` in the same green Questie uses for
   finished objectives: `"|cFF40C040"`.
7. No SQ-specific color headers — this section should read as a seamless
   continuation of Questie's tooltip, not a separate SQ block.

**Full revised addGroupProgressToTooltip:**

```lua
local function addGroupProgressToTooltip(tooltip, questID)
    if not SocialQuestWowAPI.IsInGroup() or SocialQuestWowAPI.IsInRaid() then return end

    local AQL = SocialQuest.AQL
    if not AQL then return end

    local questTitle = AQL:GetQuestTitle(questID)
    -- Fetch local objective text for description labels (never transmitted over wire).
    local localObjs = AQL:GetQuestObjectives(questID) or {}

    local localName, localRealm = SocialQuestWowAPI.UnitFullName("player")
    local localKey = localRealm and (localName .. "-" .. localRealm) or localName

    local hasAnyGroupData = false

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if playerName ~= localKey then
            local qdata = resolveQuestData(entry, questID, questTitle)
            if qdata then
                if not hasAnyGroupData then
                    tooltip:AddLine(" ")   -- blank separator, matching Questie style
                    tooltip:AddLine(L["Party progress"] .. ":")
                    hasAnyGroupData = true
                end

                local line
                if not entry.hasSocialQuest then
                    line = " - " .. playerName .. ": " .. L["(shared, no data)"]
                elseif qdata.isComplete then
                    line = " - " .. playerName .. ": " .. "|cFF40C040" .. L["Complete"] .. "|r"
                else
                    local parts = {}
                    for i, obj in ipairs(qdata.objectives or {}) do
                        local localObj = localObjs[i]
                        local desc = localObj and localObj.text
                                  and localObj.text:match("^(.-)%s*:%s*%d") -- strip count-last
                                  or  localObj and localObj.text:match("^%d+/%d+%s+(.+)$") -- strip count-first
                        local count = obj.numFulfilled .. "/" .. obj.numRequired
                        if desc and desc ~= "" then
                            table.insert(parts, desc .. ": " .. count)
                        else
                            table.insert(parts, count)
                        end
                    end
                    local status = #parts > 0 and table.concat(parts, "; ") or L["(no data)"]
                    line = " - " .. playerName .. ": " .. status
                end

                tooltip:AddLine(line, 1, 1, 1)  -- white text, matching Questie's plain lines
            end
        end
    end

    if hasAnyGroupData then tooltip:Show() end
end
```

---

### Initialize — changes

**Retail: add SetItemRef hook for `socialquest` links.**

SQ-generated Retail links use `|Hsocialquest:questID:level|h`. WoW does not know this
type, so clicking it fires `SetItemRef` without displaying anything. The hook forwards
it to the native quest tooltip display; `TooltipDataProcessor` then fires and appends
party progress via the existing Retail path.

Add inside the `if SQWowAPI.IS_RETAIL` block:

```lua
hooksecurefunc("SetItemRef", function(link, text, button)
    local linkType, questID, level = strsplit(":", link)
    if linkType ~= "socialquest" then return end
    questID = tonumber(questID)
    level   = tonumber(level) or 0
    if not questID then return end
    ShowUIPanel(ItemRefTooltip)
    ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    ItemRefTooltip:SetHyperlink("quest:" .. questID .. ":" .. level)
    ItemRefTooltip:Show()
end)
```

**TBC/Classic/Mists: extend SetHyperlink pattern to match `questie:` links.**

The current pattern `link:match("quest:(%d+)")` does not match Questie links
(`questie:questID:senderGUID`) or the socialquest format. Extend to cover all three
types SQ may encounter:

```lua
hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
    if not link then return end
    local questID = tonumber(link:match("^quest:(%d+)"))
                 or tonumber(link:match("^questie:(%d+)"))
    if questID then
        addGroupProgressToTooltip(self, questID)
    end
end)
```

Note: `socialquest:` is Retail-only; the TBC path never sees it. The `^` anchor
prevents false matches inside longer strings.

---

## Defensive Coding Requirements

The tooltip rewrite runs inside WoW's and Questie's display path. Any unguarded error
in SQ's code will propagate up and corrupt the tooltip or suppress it entirely for the
user. The following rules are mandatory throughout `addGroupProgressToTooltip` and the
`SetItemRef` hook:

**1. Wrap the entire tooltip augmentation body in `pcall`.**
Both `addGroupProgressToTooltip` and the `SetItemRef` handler must be wrapped so any
error in SQ's code is silently swallowed and never reaches the caller:

```lua
local ok, err = pcall(function()
    -- all tooltip augmentation logic here
end)
if not ok then
    SocialQuest:Debug("Banner", "Tooltip hook error: " .. tostring(err))
end
```

**2. Nil-check every AQL call result before use.**
`AQL:GetQuestTitle`, `AQL:GetQuestObjectives`, `AQL:GetQuest` — all can return nil.
Never index the result without checking first.

**3. Nil-check every `entry` field before use.**
`entry.quests`, `entry.hasSocialQuest`, `qdata.objectives`, `qdata.isComplete` —
all must be guarded. PlayerQuests entries can be stubs with minimal fields.

**4. Nil/type-check objective fields.**
`obj.numFulfilled` and `obj.numRequired` can be nil on stale or partially-received
data. Use `(obj.numFulfilled or 0)` and `(obj.numRequired or 1)` — never divide or
concatenate raw.

**5. Nil-check `localKey` before the self-skip comparison.**
`UnitFullName("player")` can return nil on early load. Guard:
`if localKey and playerName == localKey then`.

**6. Guard the `SetItemRef` hook body entirely.**
`strsplit` can return nil fields; `tonumber` can return nil. Bail out early on any
nil and never call `ItemRefTooltip:SetHyperlink` with a malformed string.

---

## What Is NOT Changed

- **On-screen banners** — `RaidNotice_AddMessage` cannot render hyperlink escape codes;
  banners continue using plain `title` text. This is correct and intentional.
- **TestChatLink debug method** — remains a local-only `AddMessage` preview; not
  affected by this change.
- **Wowhead URL** — already fixed in 2.18.22; out of scope.
- **Drag behavior / saved positions** — unrelated.
- **Party gate API** — `SocialQuestWowAPI.IsInRaid()` may not cover BG groups on all
  versions. If it does not, the implementer should additionally check
  `SocialQuestGroupComposition.currentGroupType()` (or equivalent) to exclude BGs, using
  SQ's existing `GroupType` enum.

---

## Priority Rules Summary

| Situation | Link format sent | Click behavior |
|---|---|---|
| Non-Retail, SQ announces | `\|Hquestie:questID:senderGUID\|h[level] Name\|h\|r` | Questie users: Questie tooltip. Others: plain text. |
| Retail, SQ announces | `\|Hsocialquest:questID:level\|h[level] Name\|h\|r` | SQ `SetItemRef` hook → native quest tooltip + party progress |
| Any version, player manually links quest | Native `\|Hquest:questID:level\|h` | Native tooltip + party progress (Tooltips.lua hook) |
| Any version, Questie announces | `\|Hquestie:questID:senderGUID\|h` | Questie tooltip + party progress (Tooltips.lua hook) |

Party progress augmentation fires for **all** of these — it is tied to the tooltip
event, not to who generated the link.

---

## Files Changed

| File | Change |
|---|---|
| `Core/Announcements.lua` | Add `BuildQuestLink()` local function; update `OnQuestEvent` and `OnObjectiveEvent` to use it |
| `UI/Tooltips.lua` | `addGroupProgressToTooltip`: party gate, skip local player, alias resolution; `Initialize`: `SetItemRef` hook for Retail `socialquest` links, extended TBC `SetHyperlink` pattern |
