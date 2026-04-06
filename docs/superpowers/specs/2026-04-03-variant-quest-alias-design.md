# Variant Quest Alias Detection Design

## Problem

Retail WoW assigns different questIDs to different race/class character types for the same logical quest. Two players doing "The Rite of Vision" may each have a different questID — same title, same zone, same objectives — but numerically distinct IDs.

This breaks three things in SocialQuest:

1. **"Everyone has completed" never fires.** `checkAllFinished` looks up each party member by exact questID. A member with a variant ID is invisible to the check, so the "everyone done" condition is never met.
2. **Party tab shows duplicate rows** — one per variant questID — instead of one grouped entry.
3. **Shared tab has the same duplication problem.**

Additionally, all internal debug messages and comments around this feature use "finished" (objectives done, not turned in) instead of "completed" (turned in to NPC), which is inconsistent with the displayed `L["Everyone has completed: %s"]` string.

---

## Solution Overview

AQL gains a new public API for alias detection based on quest fingerprinting. SQ uses that API in three places: the "everyone done" check, the Party tab render loop, and the Shared tab render loop. Internal language is updated to "completed" throughout.

---

## AQL Changes — `AbsoluteQuestLog`

### Fingerprint helper: `QuestCache:_buildAliasKey(info)`

Private method on `QuestCache`. Builds a stable string from a quest's observable identity: title, zone, and sorted objectives.

```
title:zone:objName1/numRequired1|objName2/numRequired2|...
```

- Objectives sorted alphabetically by name so ordering differences don't affect the key.
- Zone defaults to `""` for quests with no zone header (e.g. campaign quests under a campaign header).
- `numRequired` included so quests with same name but different counts are not aliased.

Lives in `Core/QuestCache.lua`.

### Public API 1: `AQL:GetQuestAliasKey(questID)`

```
function AQL:GetQuestAliasKey(questID)
    if not AQL.isRetail then
        return tostring(questID)
    end
    local info = AQL.QuestCache:Get(questID)
    if not info then return nil end
    return AQL.QuestCache:_buildAliasKey(info)
end
```

- On non-Retail versions (Classic, TBC, MoP), variant questIDs do not exist. The key is simply `tostring(questID)` — no fingerprint computation, no cache lookup.
- On Retail, returns `nil` if the questID is not in the live cache. Callers fall back to `tostring(questID)` on nil so ungrouped quests still display/function correctly.
- Works for both local quests (from `QuestCache`) and remote quests (GroupData stores `title`, `zone`, `objectives` already — no wire format changes needed).

Added to `AbsoluteQuestLog.lua`.

### Public API 2: `AQL:AreQuestsAliases(id1, id2)`

```
function AQL:AreQuestsAliases(id1, id2)
    local k1 = AQL:GetQuestAliasKey(id1)
    return k1 ~= nil and k1 == AQL:GetQuestAliasKey(id2)
end
```

Thin convenience wrapper. Added to `AbsoluteQuestLog.lua`.

---

## SQ Changes — `checkAllFinished` → `checkAllCompleted`

### Rename

`checkAllFinished` → `checkAllCompleted` everywhere: function definition, all call sites, all debug messages, all inline comments.

Debug message updates (non-exhaustive examples):
- `"All finished suppressed"` → `"All completed suppressed"`
- `"Everyone has finished"` in comments → `"Everyone has completed"`

The displayed `L["Everyone has completed: %s"]` string is already correct — no localization changes.

### Alias-aware engagement check

Current (broken):
```
local hasActive = entry.quests and entry.quests[questID] ~= nil
```

New logic in `checkAllCompleted(questID)`:

1. Resolve alias key: `local aliasKey = AQL:GetQuestAliasKey(questID) or tostring(questID)`
2. For each party member, scan their `entry.quests` map. For each of their questIDs, call `AQL:GetQuestAliasKey(memberQuestID)` and compare to `aliasKey`.
   - **Engaged** = at least one of their quests matches the alias key.
   - **Done** = their matching quest has `isComplete = true`.
3. Fire banner when: at least one member is engaged AND every engaged member is done.

### No double-fire risk

Each variant fires its own `AQL_QUEST_FINISHED` → `checkAllCompleted`. When the first member finishes, the second member's variant is not yet `isComplete` — the check is suppressed. When the last member finishes, all engaged members are done and the banner fires exactly once.

---

## SQ Changes — Party Tab Grouping

### Current behavior

Render loop iterates quests by questID. Each variant ID produces a separate row.

### New behavior

Two-phase render:

**Build phase:** Collect all quests across all members. Group into alias buckets:
```
buckets[aliasKey] = { { member = ..., questID = ..., questData = ... }, ... }
```
Alias key computed via `AQL:GetQuestAliasKey(questID)`, falling back to `tostring(questID)` on nil.

**Render phase:** One row per alias bucket.
- Title and zone: prefer local player's entry; otherwise use the first available member's entry.
- Each member's objectives rendered as sub-rows within the group entry.

**Interactions** (track, abandon, etc.): always operate on the local player's own questID (from AQL's live cache), never a remote variant ID.

---

## SQ Changes — Shared Tab Grouping

Same two-phase build/render approach as Party tab. The Shared tab displays quests the local player has shared with the group; variant grouping ensures the same logical quest is not listed multiple times when multiple party members share it.

---

## What Does NOT Change

- Wire format (`buildQuestPayload` / `buildInitPayload`) — `isComplete` serialization is correct as-is.
- `PlayerQuests` storage structure — still keyed by questID internally; grouping is display-layer only.
- `GroupData.OnUpdateReceived` / `OnInitReceived` — no changes.
- Localization strings — `L["Everyone has completed: %s"]` is already correct.
- Any Classic/TBC/MoP code paths — variant questIDs are a Retail-only phenomenon. On non-Retail versions `GetQuestAliasKey` returns `tostring(questID)` immediately with no fingerprint computation or cache lookup, so there is zero overhead.

---

## Files Touched

| File | Change |
|------|--------|
| `AbsoluteQuestLog/Core/QuestCache.lua` | Add `_buildAliasKey(info)` |
| `AbsoluteQuestLog/AbsoluteQuestLog.lua` | Add `GetQuestAliasKey`, `AreQuestsAliases` |
| `SocialQuest/Core/Announcements.lua` | Rename to `checkAllCompleted`, alias-aware check, language cleanup |
| `SocialQuest/UI/Tabs/PartyTab.lua` | Alias-based grouping in render loop |
| `SocialQuest/UI/Tabs/SharedTab.lua` | Alias-based grouping in render loop |
