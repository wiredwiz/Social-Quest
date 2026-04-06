# SQ Custom Quest Tooltip Design

## Goal

Build a rich, alias-aware custom quest tooltip for SocialQuest that renders quest details (description, NPC info, type) alongside party progress, resolves the "You are ineligible for this quest" false-positive caused by Questie treating alias questIDs as separate quests, and gives players configurable control over when SQ's tooltip replaces Questie's or WoW's default tooltip.

## Dependencies

- AQL Details Capability (spec: `2026-04-06-aql-details-capability-design.md`) must be implemented first — the SQ tooltip reads `description`, `starterNPC`, `starterZone`, `finisherNPC`, `finisherZone`, `isDungeon`, `isRaid`, `isGroup`, and `objectives[i].npcOrItemName`/`objType` from `AQL:GetQuestInfo`.

## Wire Format Change

SQ's outbound chat quest link format changes from:

```
[[level] Quest Name (questID)]
```

to:

```
[[level] Quest Name {questID}]
```

Questie's `ChatFilter.lua` pattern `%[(..-) %((%d+)%)%]` requires parentheses around the questID — it will not match the new `{questID}` format. This eliminates the race condition where both Questie's and SQ's chat filters compete to convert the same message into their respective link types.

SQ's chat filter pattern is updated to match `{questID}` accordingly.

**Wire protocol version bump required.** Messages sent by older SQ clients (parenthesis format) must still be handled gracefully — the old pattern should remain recognized by the receiving filter for backward compatibility during the transition period.

## Configuration

A new "Tooltips" group is added to `/sq config`. Three options:

| Option | Default | Description |
|---|---|---|
| Enhance Questie/Blizzard tooltips | ON | Appends "Party progress:" section to existing quest tooltips (existing behavior) |
| Replace Blizzard quest tooltips | OFF | When a `quest:` link is clicked, SQ renders its own full tooltip instead of WoW's basic tooltip |
| Replace Questie quest tooltips | OFF | When a `questie:` link is clicked, SQ renders its own full tooltip instead of Questie's tooltip. Greyed out (AceConfig `disabled` callback) when `QuestieLoader` is nil — Questie is not installed so the option does not apply. |

"Enhance" and "Replace" are independent. If both are on for the same link type, "Replace" takes precedence (replace implies a full rebuild, so enhance is redundant).

New locale keys required for all three option labels and their descriptions across all 12 locales.

## Tooltip Layout

```
[Quest Title]                          -- always, yellow
You are on this quest                  -- optional status line (see Status Line Logic)
Level N · Zone · [Dungeon] [Group]     -- level always; zone/type badges optional
                                       -- blank line only if description follows
Quest description text...              -- optional (Questie only)
                                       -- blank line only if NPC lines follow
Quest Giver: NPC Name, Zone            -- optional (Questie + Grail)
Turn In: NPC Name, Zone                -- optional (Questie + Grail)
                                       -- blank line only if party data follows
Party progress:                        -- optional, only when group data exists
 - PlayerName: objective: X/Y
 - PlayerName: Complete
```

All optional sections are fully omitted (no blank lines, no placeholder text) when data is unavailable. The tooltip renders cleanly with whatever is present.

## Tooltip Renderer

`UI/Tooltips.lua` gains a new `SocialQuestTooltips:BuildTooltip(tooltip, questID)` function.

Steps:
1. Call `AQL:GetQuestInfo(questID)` — resolves all fields including Details fields
2. Render title line (yellow)
3. Render status line if determinable (see Status Line Logic)
4. Render level · zone · type line
5. If `questInfo.description` is non-nil: blank line + description
6. If `starterNPC` or `finisherNPC` is non-nil: blank line + NPC lines
7. If group party data exists: blank line + "Party progress:" + member lines (existing logic from `addGroupProgressToTooltip`, refactored to call into `BuildTooltip`)
8. Call `tooltip:Show()`

The existing `addGroupProgressToTooltip` logic is refactored into a shared helper so both the augment path (append-only) and the replace path (full rebuild) can reuse it.

## Status Line Logic

The status line appears on the second line under the title. All lookups are alias-aware.

### "You are on this quest" (green)
- `AQL:GetQuest(questID)` returns non-nil, or
- Title-based scan: `AQL:GetAllQuests()` contains any quest whose title matches the linked quest's title

### "You have completed this quest" (green)
- `AQL:HasCompletedQuest(questID)` returns true, or
- Title-based scan: iterate `AQL:GetCompletedQuests()` keys, resolve titles via provider, match against linked quest title

### "You are eligible for this quest" (white)
- Quest is neither active nor completed (above checks all false)
- A provider is available (Details capability is not NullProvider)
- Look up the linked questID's title in the provider DB; find all quests with the same title
- Check `AQL:GetQuestRequirements()` for each candidate against local player race/class/level
- If any candidate passes all requirements → show "You are eligible for this quest"
- This is a best-effort heuristic. Same-title + same-zone is a strong alias signal but not guaranteed.

### "You are not eligible for this quest" (grey, dimmed)
- Same candidate lookup, but requirements fail for all candidates
- If a specific reason is determinable (level too low, wrong class, etc.), show it — reuse eligibility reason logic from `PartyTab`

### No status line
- Provider is absent (NullProvider) and quest is neither active nor completed
- Show nothing rather than guess

## Hook Sites

### `socialquest:` links (always SQ tooltip, no config gate)

`SetItemRef` hook detects `linkType == "socialquest"`, calls `BuildTooltip(ItemRefTooltip, questID)` directly. No longer calls `SetHyperlink("questie:...")`. This path is independent of the Replace config options.

### `quest:` links (config-gated)

`ItemRefTooltip:SetHyperlink` hook detects `link:match("^quest:(%d+)")`. If "Replace Blizzard" is ON: call `tooltip:ClearLines()` then `BuildTooltip(tooltip, questID)`. If OFF: existing augment-only behavior (append party progress).

### `questie:` links (config-gated)

Same hook, detects `link:match("^questie:(%d+)")`. If "Replace Questie" is ON: `ClearLines()` + `BuildTooltip`. If OFF: existing augment-only behavior.

### Retail `TooltipDataProcessor` path

On Retail, when "Replace" mode is active for the relevant link type, the `TooltipDataProcessor.AddTooltipPostCall` handler must skip its normal augment behavior — `BuildTooltip` already ran via the `SetHyperlink` hook and called `Show()`. A flag (`_sqTooltipBuilt`) set by `BuildTooltip` and cleared by `tooltip:OnHide` guards against double-processing.

## Files to Create or Modify

| File | Change |
|---|---|
| `Core/Communications.lua` | Update `BuildQuestLink` wire format to use `{questID}` |
| `UI/Tooltips.lua` | New `BuildTooltip(tooltip, questID)`; update chat filter pattern for `{questID}`; retain old pattern as fallback for backward compat; update `SetItemRef` hook; update `SetHyperlink` hook with Replace logic; update Retail `TooltipDataProcessor` handler with `_sqTooltipBuilt` guard |
| `UI/Options.lua` | Add "Tooltips" config group with three options |
| `SocialQuest.lua` | Add AceDB defaults for new tooltip config options |
| `Locales/*.lua` | New locale keys for three Tooltips config option labels and descriptions (all 12 locales) |
| `CLAUDE.md` | Document new wire format, Tooltips config options, `BuildTooltip` API |
