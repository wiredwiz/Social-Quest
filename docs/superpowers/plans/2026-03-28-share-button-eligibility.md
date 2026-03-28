# Share Button & Quest Eligibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `[Share]` button to quest rows in the Party tab and replace the existing binary share-eligibility check with a full 11-reason eligibility system, so ineligible party members show a specific reason label instead of the misleading "Needs it Shared" label.

**Architecture:** Two sequential stages. Stage 1 adds `AQL:GetQuestRequirements(questID)` to the AbsoluteQuestLog library (new provider method + public API). Stage 2 modifies SocialQuest to use the new data: new `resolveUnitToken` and full `isEligibleForShare` in `PartyTab.lua`, share button in `RowFactory.lua`, reason rendering, and locale strings in all 12 locale files. Stage 1 must be committed before Stage 2 begins.

**Tech Stack:** Lua 5.1, WoW TBC Anniversary API (Interface 20505), Ace3 library, AceLocale-3.0, LibStub. No external test runner — verification is in-game via `/sq debug on` and `/aql debug on`.

---

## File Map

### Stage 1 — AbsoluteQuestLog

| File | Change |
|---|---|
| `Providers/Provider.lua` | Add `GetQuestRequirements` to the interface contract (documentation only) |
| `Providers/NullProvider.lua` | Add `GetQuestRequirements` returning nil |
| `Providers/QuestWeaverProvider.lua` | Add `GetQuestRequirements` with available fields (requiredLevel only; others nil) |
| `Providers/QuestieProvider.lua` | Add `GetQuestRequirements` with full Questie field mapping |
| `AbsoluteQuestLog.lua` | Add `AQL:GetQuestRequirements(questID)` public method |
| `AbsoluteQuestLog.toc` | Bump version |

### Stage 2 — SocialQuest

| File | Change |
|---|---|
| `Core/WowAPI.lua` | Add `SQWowAPI.QuestLogPushQuest()` and `SQWowAPI.UnitClass(unit)` wrappers |
| `UI/Tabs/PartyTab.lua` | Add `local SQWowAPI`, `RACE_BITS`, `CLASS_BITS`, `resolveUnitToken`, replace `isEligibleForShare`; update `buildPlayerRowsForQuest`; update `Render` |
| `UI/RowFactory.lua` | Update `AddQuestRow` (share button + doc comment); update `AddPlayerRow` (ineligReason rendering) |
| `Locales/enUS.lua` | Add 7 `share.reason.*` keys |
| `Locales/deDE.lua` … `Locales/jaJP.lua` | Add translated versions of the same 7 keys (11 files) |
| `SocialQuest.toc` | Bump version |
| `CLAUDE.md` (SQ) | Add version entry |

---

## Stage 1: AQL — `GetQuestRequirements`

---

### Task 1: Document `GetQuestRequirements` in Provider.lua

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/Provider.lua`

- [ ] **Step 1: Add interface documentation for `GetQuestRequirements`**

Add after the `GetQuestFaction` doc block in `Provider.lua`:

```lua
--   Provider:GetQuestRequirements(questID)
--     Returns a requirements table or nil.
--     Return shape:
--       {
--         requiredLevel        = N or nil,               -- questKeys[4]
--         requiredMaxLevel     = N or nil,               -- questKeys[32]
--         requiredRaces        = N or nil,               -- questKeys[6],  bitmask; nil means no restriction
--         requiredClasses      = N or nil,               -- questKeys[7],  bitmask; nil means no restriction
--         preQuestGroup        = { questID, ... } or nil, -- questKeys[12], ALL must be complete
--         preQuestSingle       = { questID, ... } or nil, -- questKeys[13], ANY ONE must be complete
--         exclusiveTo          = { questID, ... } or nil, -- questKeys[16]
--         nextQuestInChain     = questID or nil,          -- questKeys[22]
--         breadcrumbForQuestId = questID or nil,          -- questKeys[27]
--       }
--     Bitmask fields with value 0 are normalised to nil by the provider
--     (0 means "no restriction" in Questie's encoding).
--     Returns nil when the provider has no data for this questID, or when the
--     provider does not implement this method (NullProvider).
```

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add Providers/Provider.lua
git commit -m "docs(providers): document GetQuestRequirements interface contract"
```

---

### Task 2: NullProvider — `GetQuestRequirements` returns nil

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/NullProvider.lua`

- [ ] **Step 1: Add `GetQuestRequirements` method to NullProvider**

Add before `AQL.NullProvider = NullProvider`:

```lua
function NullProvider:GetQuestRequirements(questID)
    return nil
end
```

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add Providers/NullProvider.lua
git commit -m "feat(providers): NullProvider returns nil for GetQuestRequirements"
```

---

### Task 3: QuestWeaverProvider — `GetQuestRequirements`

QuestWeaver exposes `min_level` (maps to `requiredLevel`). It has no data for the other fields, so they return nil.

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/QuestWeaverProvider.lua`

- [ ] **Step 1: Add `GetQuestRequirements` method to QuestWeaverProvider**

Add before `AQL.QuestWeaverProvider = QuestWeaverProvider`:

```lua
function QuestWeaverProvider:GetQuestRequirements(questID)
    if not self:IsAvailable() then return nil end
    local qw = _G["QuestWeaver"]
    local quest = qw.Quests and qw.Quests[questID]
    if not quest then return nil end
    -- QuestWeaver only exposes min_level; all other requirement fields are unavailable.
    local minLevel = quest.min_level
    if not minLevel or minLevel == 0 then minLevel = nil end
    return {
        requiredLevel        = minLevel,
        requiredMaxLevel     = nil,
        requiredRaces        = nil,
        requiredClasses      = nil,
        preQuestGroup        = nil,
        preQuestSingle       = nil,
        exclusiveTo          = nil,
        nextQuestInChain     = nil,
        breadcrumbForQuestId = nil,
    }
end
```

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add Providers/QuestWeaverProvider.lua
git commit -m "feat(providers): QuestWeaverProvider implements GetQuestRequirements"
```

---

### Task 4: QuestieProvider — `GetQuestRequirements`

This is the full implementation that reads from QuestieDB. All nine fields are populated. Values of 0 in Questie's bitmask fields mean "no restriction" and are normalised to nil so consumers can check with `if reqs.requiredRaces then` without also checking for 0.

Questie field names on the quest object (confirmed against `tbcQuestDB.lua` questKeys):
- `quest.requiredLevel` (questKeys[4])
- `quest.requiredRaces` (questKeys[6]) — bitmask; 0 = all races allowed
- `quest.requiredClasses` (questKeys[7]) — bitmask; 0 = all classes allowed
- `quest.preQuestGroup` (questKeys[12]) — array; ALL must be complete
- `quest.preQuestSingle` (questKeys[13]) — array; ANY ONE must be complete
- `quest.exclusiveTo` (questKeys[16]) — array
- `quest.nextQuestInChain` (questKeys[22]) — 0 means no next quest
- `quest.breadcrumbForQuestId` (questKeys[27]) — questID or nil
- `quest.requiredMaxLevel` (questKeys[32]) — 0 means no cap

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/Providers/QuestieProvider.lua`

- [ ] **Step 1: Add `GetQuestRequirements` method to QuestieProvider**

Add after `QuestieProvider:GetQuestFaction` and before `AQL.QuestieProvider = QuestieProvider`:

```lua
-- Returns quest requirements from QuestieDB, or nil if the quest is not found.
-- Bitmask fields with value 0 are normalised to nil (0 = no restriction in Questie's encoding).
-- nextQuestInChain value of 0 is normalised to nil.
function QuestieProvider:GetQuestRequirements(questID)
    local db = getDB()
    if not db then return nil end
    local ok, quest = pcall(db.GetQuest, questID)
    if not ok or not quest then return nil end

    local function zeroToNil(v)
        if v == 0 then return nil end
        return v
    end

    local nextInChain = zeroToNil(quest.nextQuestInChain)

    return {
        requiredLevel        = zeroToNil(quest.requiredLevel),
        requiredMaxLevel     = zeroToNil(quest.requiredMaxLevel),
        requiredRaces        = zeroToNil(quest.requiredRaces),
        requiredClasses      = zeroToNil(quest.requiredClasses),
        preQuestGroup        = quest.preQuestGroup,
        preQuestSingle       = quest.preQuestSingle,
        exclusiveTo          = quest.exclusiveTo,
        nextQuestInChain     = nextInChain,
        breadcrumbForQuestId = quest.breadcrumbForQuestId,
    }
end
```

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add Providers/QuestieProvider.lua
git commit -m "feat(providers): QuestieProvider implements GetQuestRequirements with full field mapping"
```

---

### Task 5: AQL public method — `AQL:GetQuestRequirements`

The public method wraps the provider call with pcall (consistent with how other provider calls work in `GetQuestInfo`). Returns nil when NullProvider is active or when the provider errors.

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/AbsoluteQuestLog.lua`

- [ ] **Step 1: Find the insertion point**

The new method belongs in Group 1 Quest APIs, after `AQL:IsQuestIdShareable` in the Quest Log section. Since this is a data query (not quest log interaction), place it near the end of Group 1, after `AQL:GetChainInfo`. A good anchor is the line `-- Quest Tracking` section. Insert a new subsection before it.

- [ ] **Step 2: Add `AQL:GetQuestRequirements` public method**

Locate the `-- Quest Tracking` comment block in `AbsoluteQuestLog.lua` and insert before it:

```lua
------------------------------------------------------------------------
-- Quest Requirements
------------------------------------------------------------------------

-- GetQuestRequirements(questID) → requirements table or nil
-- Returns provider-backed quest eligibility requirements for questID.
-- Return shape: { requiredLevel, requiredMaxLevel, requiredRaces, requiredClasses,
--   preQuestGroup, preQuestSingle, exclusiveTo, nextQuestInChain, breadcrumbForQuestId }
-- All bitmask fields with value 0 are normalised to nil by the provider.
-- Returns nil when no provider is available (NullProvider active) or when
-- the provider has no data for this questID.
-- Designed to always return data once QuestieDB is bundled into AQL.
function AQL:GetQuestRequirements(questID)
    local provider = self.provider
    if not provider or not provider.GetQuestRequirements then
        return nil
    end
    local ok, result = pcall(provider.GetQuestRequirements, provider, questID)
    if not ok then return nil end
    return result
end
```

- [ ] **Step 3: Commit**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add AbsoluteQuestLog.lua
git commit -m "feat(aql): add AQL:GetQuestRequirements public method"
```

---

### Task 6: AQL — bump toc version and update CLAUDE.md

**Files:**
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/AbsoluteQuestLog.toc`
- Modify: `D:/Projects/Wow Addons/Absolute-Quest-Log/CLAUDE.md`

- [ ] **Step 1: Bump toc version**

Today is 2026-03-28. Current version is 2.3.0. This is the first AQL modification today, so increment minor: 2.4.0.

In `AbsoluteQuestLog.toc`, change:
```
## Version: 2.3.0
```
to:
```
## Version: 2.4.0
```

- [ ] **Step 2: Add version entry to AQL CLAUDE.md**

Add before `### Version 2.3.0`:

```markdown
### Version 2.4.0 (March 2026)
- Feature: Added `AQL:GetQuestRequirements(questID)` public method. Returns provider-backed quest eligibility requirements: requiredLevel, requiredMaxLevel, requiredRaces (bitmask), requiredClasses (bitmask), preQuestGroup, preQuestSingle, exclusiveTo, nextQuestInChain, breadcrumbForQuestId. All bitmask fields with value 0 are normalised to nil. Returns nil when NullProvider is active. `QuestieProvider` implements full field mapping from QuestieDB. `QuestWeaverProvider` returns requiredLevel only (other fields nil — QuestWeaver does not expose them). `NullProvider` returns nil. `Provider.lua` documentation updated with interface contract.
```

- [ ] **Step 3: Commit**

```bash
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add AbsoluteQuestLog.toc CLAUDE.md
git commit -m "chore: bump AQL version to 2.4.0 — GetQuestRequirements feature"
```

---

## Stage 2: SocialQuest — Share button + full eligibility

---

### Task 7: `Core/WowAPI.lua` — add `QuestLogPushQuest` and `UnitClass` wrappers

The existing `WowAPI.lua` already has wrappers for `UnitName`, `UnitLevel`, `UnitRace`. Two are missing: `QuestLogPushQuest` (share action) and `UnitClass` (needed for class eligibility check).

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/Core/WowAPI.lua`

- [ ] **Step 1: Add the two missing wrappers**

`UnitClass(unit)` in TBC returns two values: `(localizedClassName, classToken)`. The token is always English (e.g., `"WARRIOR"`, `"DRUID"`) and is what the class bitmask lookup uses.

In `Core/WowAPI.lua`, add after the existing `UnitRace` line:

```lua
function SocialQuestWowAPI.UnitClass(unit)                        return UnitClass(unit)                        end
```

And add after the `SendChatMessage` line (or at the end of the wrapper block):

```lua
function SocialQuestWowAPI.QuestLogPushQuest()                    QuestLogPushQuest()                           end
```

The file should look like (showing context around changes):

```lua
function SocialQuestWowAPI.UnitLevel(unit)                        return UnitLevel(unit)                        end
function SocialQuestWowAPI.UnitRace(unit)                         return UnitRace(unit)                         end
function SocialQuestWowAPI.UnitClass(unit)                        return UnitClass(unit)                        end  -- NEW
function SocialQuestWowAPI.UnitFactionGroup(unit)                 return UnitFactionGroup(unit)                 end
```

And:

```lua
function SocialQuestWowAPI.SendChatMessage(text, chan, lang, tgt)  return SendChatMessage(text, chan, lang, tgt)  end
function SocialQuestWowAPI.QuestLogPushQuest()                    QuestLogPushQuest()                           end  -- NEW
```

- [ ] **Step 2: Verify `QuestLogPushQuest` exists in TBC**

`QuestLogPushQuest()` is a standard TBC WoW API that shares the currently selected quest log entry with all party members. It has existed since vanilla and is present in TBC Classic (Interface 20505). No guard needed.

- [ ] **Step 3: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Core/WowAPI.lua
git commit -m "feat(wowapi): add QuestLogPushQuest and UnitClass wrappers to SQWowAPI"
```

---

### Task 8: `PartyTab.lua` — add `SQWowAPI` local, lookup tables, `resolveUnitToken`

This task adds the lookup tables (RACE_BITS, CLASS_BITS) and the `resolveUnitToken` helper to `PartyTab.lua`.

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/UI/Tabs/PartyTab.lua`

- [ ] **Step 1: Add `local SQWowAPI` and the lookup tables**

After the existing `local L = LibStub(...)` line at the top of the file, add:

```lua
local SQWowAPI = SocialQuestWowAPI

-- Maps UnitRace() second return value (English race string) to Questie requiredRaces bitmask bits.
-- "Scourge" is the English race file name for Undead in TBC.
local RACE_BITS = {
    ["Human"]    = 1,
    ["Orc"]      = 2,
    ["Dwarf"]    = 4,
    ["NightElf"] = 8,
    ["Scourge"]  = 16,
    ["Tauren"]   = 32,
    ["Gnome"]    = 64,
    ["Troll"]    = 128,
    ["BloodElf"] = 512,
    ["Draenei"]  = 1024,
}

-- Maps UnitClass() second return value (English class token) to Questie requiredClasses bitmask bits.
-- Death Knight (32) and Monk (512) are omitted: no TBC player can have those classes.
local CLASS_BITS = {
    ["WARRIOR"] = 1,
    ["PALADIN"] = 2,
    ["HUNTER"]  = 4,
    ["ROGUE"]   = 8,
    ["PRIEST"]  = 16,
    ["SHAMAN"]  = 64,
    ["MAGE"]    = 128,
    ["WARLOCK"] = 256,
    ["DRUID"]   = 1024,
}
```

- [ ] **Step 2: Add `resolveUnitToken` helper**

Add before the existing `isEligibleForShare` function:

```lua
-- Scans "party1".."party4" to find the unit token for the given player name.
-- Normalises realm suffix (strips -RealmName) for same-realm matching.
-- Returns the token string ("party1", etc.) or nil if not matched (offline or unknown).
local function resolveUnitToken(playerName)
    local shortLookup = playerName:match("^([^%-]+)") or playerName
    for i = 1, 4 do
        local token = "party" .. i
        local unitName = SQWowAPI.UnitName(token)
        if unitName then
            local shortUnit = unitName:match("^([^%-]+)") or unitName
            if shortUnit == shortLookup or unitName == playerName then
                return token
            end
        end
    end
    return nil
end
```

- [ ] **Step 3: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Tabs/PartyTab.lua
git commit -m "feat(partytab): add SQWowAPI local, RACE_BITS/CLASS_BITS tables, resolveUnitToken"
```

---

### Task 9: `PartyTab.lua` — replace `isEligibleForShare` with full 11-check version

Replace the existing `isEligibleForShare(questID, playerData)` (which only checked shareability, completion, and chain prereq) with the full 11-check version that returns `{ eligible=bool, reason={code, questID?} or nil }`.

**Check sequence (first failure wins):**
1. `AQL:IsQuestIdShareable` — evaluated OUTSIDE this function (in `buildPlayerRowsForQuest`)
2. wrong_race — requiredRaces bitmask vs UnitRace
3. wrong_class — requiredClasses bitmask vs UnitClass
4. level_too_low — requiredLevel vs UnitLevel
5. level_too_high — requiredMaxLevel vs UnitLevel
6. quest_log_full — count(playerData.quests) >= 25
7. exclusive_quest — any exclusiveTo questID in completedQuests (requires reqs)
8. already_advanced — nextQuestInChain in active or completed quests (requires reqs)
9. needs_quest — preQuestGroup: any required questID NOT in completedQuests (requires reqs)
10. needs_quest — preQuestSingle: none of the questIDs in completedQuests (requires reqs)
11. already_advanced — breadcrumbForQuestId in active or completed (requires reqs)

Checks 2–5 are skipped when `unitToken` is nil (offline player — accepted trade-off).
Checks 7–11 are skipped when `reqs` is nil (no provider).

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/UI/Tabs/PartyTab.lua`

- [ ] **Step 1: Replace the `isEligibleForShare` function**

Remove the old `isEligibleForShare` function (lines 21–46 in the current file) and replace with:

```lua
-- Returns { eligible=true } or { eligible=false, reason={code=string, questID=N?} }.
-- Check 1 (AQL:IsQuestIdShareable) is evaluated ONCE outside this function in
-- buildPlayerRowsForQuest — do NOT repeat it here.
-- unitToken: "party1".."party4" or nil (nil when player is offline; skips checks 2-5).
-- Called only from the localHasIt==true branch after the shareable pre-check passes.
local function isEligibleForShare(questID, playerData, unitToken)
    local AQL = SocialQuest.AQL
    local reqs = AQL:GetQuestRequirements(questID)

    -- Checks 2-5 require a live unit token; skip for offline players.
    if unitToken then
        -- Check 2: wrong race.
        if reqs and reqs.requiredRaces then
            local _, raceEn = SQWowAPI.UnitRace(unitToken)
            local raceBit = raceEn and RACE_BITS[raceEn]
            if raceBit and bit.band(reqs.requiredRaces, raceBit) == 0 then
                return { eligible = false, reason = { code = "wrong_race" } }
            end
        end

        -- Check 3: wrong class.
        if reqs and reqs.requiredClasses then
            local _, classToken = SQWowAPI.UnitClass(unitToken)
            local classBit = classToken and CLASS_BITS[classToken]
            if classBit and bit.band(reqs.requiredClasses, classBit) == 0 then
                return { eligible = false, reason = { code = "wrong_class" } }
            end
        end

        -- Check 4: level too low.
        if reqs and reqs.requiredLevel then
            local level = SQWowAPI.UnitLevel(unitToken)
            if level and level < reqs.requiredLevel then
                return { eligible = false, reason = { code = "level_too_low" } }
            end
        end

        -- Check 5: level too high.
        if reqs and reqs.requiredMaxLevel then
            local level = SQWowAPI.UnitLevel(unitToken)
            if level and level > reqs.requiredMaxLevel then
                return { eligible = false, reason = { code = "level_too_high" } }
            end
        end
    end

    -- Check 6: quest log full (TBC cap is 25 quests).
    local questCount = 0
    if playerData.quests then
        for _ in pairs(playerData.quests) do questCount = questCount + 1 end
    end
    if questCount >= 25 then
        return { eligible = false, reason = { code = "quest_log_full" } }
    end

    -- Checks 7-11 require provider data; skip gracefully when reqs is nil.
    if not reqs then
        return { eligible = true }
    end

    -- Check 7: exclusive quest already completed by this player.
    if reqs.exclusiveTo then
        for _, exID in ipairs(reqs.exclusiveTo) do
            if playerData.completedQuests and playerData.completedQuests[exID] then
                return { eligible = false, reason = { code = "exclusive_quest" } }
            end
        end
    end

    -- Check 8: player already has the next step in the chain (active or completed).
    if reqs.nextQuestInChain then
        local nq = reqs.nextQuestInChain
        if (playerData.quests and playerData.quests[nq]) or
           (playerData.completedQuests and playerData.completedQuests[nq]) then
            return { eligible = false, reason = { code = "already_advanced" } }
        end
    end

    -- Check 9: preQuestGroup — ALL of these questIDs must be in completedQuests.
    if reqs.preQuestGroup then
        for _, preID in ipairs(reqs.preQuestGroup) do
            if not (playerData.completedQuests and playerData.completedQuests[preID]) then
                return { eligible = false, reason = { code = "needs_quest", questID = preID } }
            end
        end
    end

    -- Check 10: preQuestSingle — ANY ONE of these questIDs must be in completedQuests.
    if reqs.preQuestSingle and #reqs.preQuestSingle > 0 then
        local anyDone = false
        for _, preID in ipairs(reqs.preQuestSingle) do
            if playerData.completedQuests and playerData.completedQuests[preID] then
                anyDone = true
                break
            end
        end
        if not anyDone then
            return { eligible = false, reason = { code = "needs_quest", questID = reqs.preQuestSingle[1] } }
        end
    end

    -- Check 11: breadcrumb quest already active or completed (player is past this breadcrumb).
    if reqs.breadcrumbForQuestId then
        local bq = reqs.breadcrumbForQuestId
        if (playerData.quests and playerData.quests[bq]) or
           (playerData.completedQuests and playerData.completedQuests[bq]) then
            return { eligible = false, reason = { code = "already_advanced" } }
        end
    end

    return { eligible = true }
end
```

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Tabs/PartyTab.lua
git commit -m "feat(partytab): replace isEligibleForShare with full 11-check eligibility function"
```

---

### Task 10: `PartyTab.lua` — update `buildPlayerRowsForQuest` and `Render`

Update `buildPlayerRowsForQuest` to evaluate shareability once before the player loop and store `ineligReason` in playerEntry. Update `Render` to pass `callbacks.onShare`.

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/UI/Tabs/PartyTab.lua`

- [ ] **Step 1: Update `buildPlayerRowsForQuest`**

The function signature stays the same: `local function buildPlayerRowsForQuest(questID, localHasIt)`.

Add `local AQL = SocialQuest.AQL` at the top (already present, no change needed there).

Add the one-time shareability check near the top of the function, before the player loop:

```lua
-- Check 1: evaluate shareability ONCE for this quest, before the member loop.
-- If false, the localHasIt branch is skipped entirely for all members.
local shareable = localHasIt and AQL:IsQuestIdShareable(questID)
```

Then in the `elseif localHasIt then` branch, replace:
```lua
needsShare     = isEligibleForShare(questID, playerData),
```
with:
```lua
-- shareable is already checked; if false, we never enter this branch.
local eligResult = isEligibleForShare(questID, playerData, resolveUnitToken(playerName))
needsShare   = eligResult.eligible,
ineligReason = eligResult.reason,
```

But the branch needs to be guarded by `shareable`. Change the `elseif localHasIt then` block to:

```lua
elseif localHasIt and shareable then
    local eligResult = isEligibleForShare(questID, playerData, resolveUnitToken(playerName))
    table.insert(players, {
        name           = playerName,
        isMe           = false,
        hasSocialQuest = playerData.hasSocialQuest,
        hasCompleted   = false,
        isComplete     = false,
        needsShare     = eligResult.eligible,
        ineligReason   = eligResult.reason,
        objectives     = {},
        dataProvider   = playerData.dataProvider,
    })
end
```

The full updated loop section in `buildPlayerRowsForQuest` (the `-- Party member rows` section) should read:

```lua
-- Party member rows.
-- Check 1: evaluate shareability once for this quest before iterating members.
local shareable = localHasIt and AQL:IsQuestIdShareable(questID)

for playerName, playerData in pairs(SocialQuestGroupData.PlayerQuests) do
    local hasQuest     = playerData.quests and playerData.quests[questID] ~= nil
    local hasCompleted = playerData.completedQuests and
                         playerData.completedQuests[questID] == true

    if hasCompleted then
        table.insert(players, {
            name           = playerName,
            isMe           = false,
            hasSocialQuest = playerData.hasSocialQuest,
            hasCompleted   = true,
            needsShare     = false,
            isComplete     = false,
            objectives     = {},
            dataProvider   = playerData.dataProvider,
        })
    elseif hasQuest then
        local pquest = playerData.quests[questID]
        local pCI    = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
        table.insert(players, {
            name           = playerName,
            isMe           = false,
            hasSocialQuest = playerData.hasSocialQuest,
            hasCompleted   = false,
            needsShare     = false,
            isComplete     = pquest.isComplete or false,
            objectives     = SocialQuestTabUtils.BuildRemoteObjectives(pquest, myInfo),
            step           = pCI.knownStatus == AQL.ChainStatus.Known and pCI.step   or nil,
            chainLength    = pCI.knownStatus == AQL.ChainStatus.Known and pCI.length or nil,
            dataProvider   = playerData.dataProvider,
        })
    elseif shareable then
        -- Local player has the quest and it is shareable; show eligibility for this member.
        local eligResult = isEligibleForShare(questID, playerData, resolveUnitToken(playerName))
        table.insert(players, {
            name           = playerName,
            isMe           = false,
            hasSocialQuest = playerData.hasSocialQuest,
            hasCompleted   = false,
            isComplete     = false,
            needsShare     = eligResult.eligible,
            ineligReason   = eligResult.reason,
            objectives     = {},
            dataProvider   = playerData.dataProvider,
        })
    end
    -- else: member has no stake and quest is not shareable → omit row entirely.
end
```

- [ ] **Step 2: Update `Render` to pass `callbacks.onShare`**

In `PartyTab:Render()`, the current calls are:
```lua
y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, {})
-- and
y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, {})
```

Replace both with a pattern that builds the callbacks table with `onShare` when appropriate. Add a helper at the top of the Render function (after `local y = 0`):

```lua
-- Builds the callbacks table for a quest row. Adds onShare when:
--   1. Local player has the quest (logIndex non-nil)
--   2. Quest is shareable
--   3. At least one party member has needsShare = true
local function buildQuestCallbacks(entry)
    local AQL = SocialQuest.AQL
    if not entry.logIndex then return {} end
    if not AQL:IsQuestIdShareable(entry.questID) then return {} end
    local hasEligible = false
    for _, p in ipairs(entry.players) do
        if p.needsShare then hasEligible = true break end
    end
    if not hasEligible then return {} end
    return {
        onShare = function()
            -- Safety check: re-verify shareability at click time.
            if not AQL:IsQuestIdShareable(entry.questID) then return end
            local prev = AQL:GetQuestLogSelection()
            AQL:SetQuestLogSelection(entry.logIndex)
            SQWowAPI.QuestLogPushQuest()
            AQL:SetQuestLogSelection(prev)
        end,
    }
end
```

Then change all four `AddQuestRow` calls (two for chain steps, two for standalone quests) to use `buildQuestCallbacks(entry)`:

```lua
-- In the chain steps loop:
y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT + 8, buildQuestCallbacks(entry))

-- In the standalone quests loop:
y = rowFactory.AddQuestRow(contentFrame, y, entry, QUEST_INDENT, buildQuestCallbacks(entry))
```

- [ ] **Step 3: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Tabs/PartyTab.lua
git commit -m "feat(partytab): update buildPlayerRowsForQuest and Render for share button + eligibility reasons"
```

---

### Task 11: `RowFactory.lua` — add Share button to `AddQuestRow`

`AddQuestRow` gains a new optional callback: `callbacks.onShare = function()`. When present, a `[Share]` button is rendered right-aligned, to the left of the existing badge. `titleWidth` shrinks by 52px to accommodate the button.

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/UI/RowFactory.lua`

- [ ] **Step 1: Update the `AddQuestRow` doc comment**

Replace the current doc comment block above `AddQuestRow` (lines 130–135) with:

```lua
-- Quest row.
-- Layout (left to right): [?] link | [v] checkmark (Mine only) | title | [Share] (Party only) | badge (right)
-- callbacks = {
--   onTitleShiftClick = function(logIndex, isTracked),  -- nil on Party/Shared tabs
--   onShare           = function(),                      -- nil when quest is not shareable or no eligible members
-- }
--   onTitleShiftClick: nil on Party/Shared tabs (disables checkmark and shift-click).
--   onShare: when present, renders a [Share] button right-aligned, left of badge. titleWidth shrinks 52px.
--   NOTE: The link button calls SocialQuestGroupFrame.ShowWowheadUrl directly; no onLinkClick callback.
```

- [ ] **Step 2: Update `AddQuestRow` to compute `shareWidth` and render the button**

Inside `AddQuestRow`, after the `local badgeWidth` line and before `local titleWidth`, add:

```lua
-- Share button width (0 when no onShare callback).
local shareWidth = (callbacks and callbacks.onShare) and 52 or 0
```

Then change the existing `titleWidth` line from:
```lua
local titleWidth = CONTENT_WIDTH - x - badgeWidth - 10
```
to:
```lua
local titleWidth = CONTENT_WIDTH - x - badgeWidth - shareWidth - 10
```

After the badge rendering block (after the `if badgeText ~= "" then ... end` block and before `return y + ROW_H + 2`), add:

```lua
-- Share button (right-aligned, to the left of the badge).
if callbacks and callbacks.onShare then
    local shareBtn = CreateFrame("Button", nil, contentFrame)
    shareBtn:SetSize(48, ROW_H - 2)
    -- Position: right-aligned, shifted left by badge + 4px gap (when badge present).
    local rightOffset = -(8 + badgeWidth + (badgeWidth > 0 and 4 or 0))
    shareBtn:SetPoint("RIGHT", contentFrame, "RIGHT", rightOffset, -y + 1)
    shareBtn:SetText("[" .. L["Share"] .. "]")
    shareBtn:SetNormalFontObject("GameFontNormalSmall")
    shareBtn:SetHighlightFontObject("GameFontHighlightSmall")
    shareBtn:SetScript("OnClick", callbacks.onShare)
    shareBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["share.tooltip"], 1, 1, 1)
        GameTooltip:Show()
    end)
    shareBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
```

- [ ] **Step 3: Verify `L["Share"]` and `L["share.tooltip"]` will be added in Task 13**

These two keys are referenced here; they're added in the locale tasks. The implementation must not be loaded before the locale files. In WoW, locale files load before UI files per toc order — this is already the case. No action needed here, just confirm the keys match what Task 13 adds.

- [ ] **Step 4: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/RowFactory.lua
git commit -m "feat(rowfactory): add [Share] button to AddQuestRow via callbacks.onShare"
```

---

### Task 12: `RowFactory.lua` — update `AddPlayerRow` for `ineligReason` rendering

When `needsShare = false` and `ineligReason ~= nil`, render the player name in muted amber with a bracketed reason label. `needs_quest` is formatted dynamically using `AQL:GetQuestTitle`; all other codes use `L["share.reason." .. code]`.

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/UI/RowFactory.lua`

- [ ] **Step 1: Update `AddPlayerRow` doc comment**

Update the doc comment above `AddPlayerRow` to add the two new fields:

```lua
-- playerEntry fields: name, isMe, hasSocialQuest, hasCompleted, needsShare,
--                     ineligReason (optional: {code, questID?} — set when ineligible),
--                     isComplete (optional), objectives, step (optional), chainLength (optional).
```

Also add to the display priority list:
```lua
-- Display priority (first matching wins):
--   ...
--   2b. playerEntry.ineligReason (needsShare=false, ineligReason~=nil) → "[Name] [reason]" (muted amber)
```

- [ ] **Step 2: Add `ineligReason` branch in `AddPlayerRow`**

In `AddPlayerRow`, after the `elseif playerEntry.needsShare then` block (around line 279–285 in the original file), add a new `elseif` branch:

```lua
elseif playerEntry.ineligReason then
    -- Player is not eligible to receive the quest — show the specific reason in muted amber.
    local reasonText
    local code = playerEntry.ineligReason.code
    if code == "needs_quest" then
        local questTitle = SocialQuest.AQL:GetQuestTitle(playerEntry.ineligReason.questID) or "?"
        reasonText = "needs: " .. questTitle
    else
        reasonText = L["share.reason." .. code] or code
    end
    local amber = "|cFFCC8800"
    local fs = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", x, -y)
    fs:SetWidth(CONTENT_WIDTH - x - 4)
    fs:SetJustifyH("LEFT")
    fs:SetText(amber .. displayName .. "|r " .. amber .. "[" .. reasonText .. "]|r")
    return y + ROW_H + 2
```

Place this branch **between** the `elseif playerEntry.needsShare then` block and the `elseif not playerEntry.hasSocialQuest` block.

- [ ] **Step 3: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/RowFactory.lua
git commit -m "feat(rowfactory): render ineligReason label in AddPlayerRow for ineligible share targets"
```

---

### Task 13: `Locales/enUS.lua` — add share-related locale keys

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/enUS.lua`

- [ ] **Step 1: Add new keys to `enUS.lua`**

Add a new section at the end of `Locales/enUS.lua`:

```lua
-- UI/RowFactory.lua — Share button label and tooltip
L["Share"]         = true
L["share.tooltip"] = "Share this quest with party members"

-- UI/RowFactory.lua — Share eligibility reason labels
-- Displayed as "[reason]" next to a party member's name when they cannot receive the shared quest.
-- "needs_quest" is formatted dynamically as "needs: [Quest Title]" — no locale key for the template.
L["share.reason.level_too_low"]   = true   -- player's level is below the quest's minimum
L["share.reason.level_too_high"]  = true   -- player's level is above the quest's maximum
L["share.reason.wrong_race"]      = true   -- player's race cannot take this quest
L["share.reason.wrong_class"]     = true   -- player's class cannot take this quest
L["share.reason.quest_log_full"]  = true   -- player already has 25 quests (TBC cap)
L["share.reason.exclusive_quest"] = true   -- player completed a mutually exclusive quest
L["share.reason.already_advanced"] = true  -- player is already past this step in the chain
```

- [ ] **Step 2: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Locales/enUS.lua
git commit -m "feat(locales): add share button and eligibility reason keys to enUS"
```

---

### Task 14: Non-English locale files — natural translations for all 12 reason keys

All 11 non-English locale files need the same 9 keys (7 reason keys + Share button + tooltip). Translations must use natural, game-appropriate phrasing — not literal word-for-word translations. Use in-game WoW terminology for each language (e.g., German "Tagebuch" for quest log, French "Carnet de quêtes"). A native speaker should read the reason label and immediately understand why they cannot receive the quest.

**Key reference (enUS values for translator context):**
- `L["Share"]` → "Share" (the button label — a verb)
- `L["share.tooltip"]` → "Share this quest with party members"
- `L["share.reason.level_too_low"]` → "level too low"
- `L["share.reason.level_too_high"]` → "level too high"
- `L["share.reason.wrong_race"]` → "wrong race"
- `L["share.reason.wrong_class"]` → "wrong class"
- `L["share.reason.quest_log_full"]` → "quest log full"
- `L["share.reason.exclusive_quest"]` → "took exclusive quest"
- `L["share.reason.already_advanced"]` → "already past this quest"

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/deDE.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/frFR.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/esES.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/esMX.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/zhCN.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/zhTW.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/ptBR.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/itIT.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/koKR.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/ruRU.lua`
- Modify: `D:/Projects/Wow Addons/Social-Quest/Locales/jaJP.lua`

- [ ] **Step 1: Write deDE translations**

Add to `Locales/deDE.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Teilen"
L["share.tooltip"] = "Diese Quest mit Gruppenmitgliedern teilen"
L["share.reason.level_too_low"]    = "Level zu niedrig"
L["share.reason.level_too_high"]   = "Level zu hoch"
L["share.reason.wrong_race"]       = "falsche Rasse"
L["share.reason.wrong_class"]      = "falsche Klasse"
L["share.reason.quest_log_full"]   = "Questtagebuch voll"
L["share.reason.exclusive_quest"]  = "exklusive Quest angenommen"
L["share.reason.already_advanced"] = "bereits weiter"
```

- [ ] **Step 2: Write frFR translations**

Add to `Locales/frFR.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Partager"
L["share.tooltip"] = "Partager cette quête avec les membres du groupe"
L["share.reason.level_too_low"]    = "niveau trop bas"
L["share.reason.level_too_high"]   = "niveau trop élevé"
L["share.reason.wrong_race"]       = "mauvaise race"
L["share.reason.wrong_class"]      = "mauvaise classe"
L["share.reason.quest_log_full"]   = "carnet de quêtes plein"
L["share.reason.exclusive_quest"]  = "quête exclusive prise"
L["share.reason.already_advanced"] = "déjà plus loin"
```

- [ ] **Step 3: Write esES translations**

Add to `Locales/esES.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Compartir"
L["share.tooltip"] = "Compartir esta misión con los miembros del grupo"
L["share.reason.level_too_low"]    = "nivel demasiado bajo"
L["share.reason.level_too_high"]   = "nivel demasiado alto"
L["share.reason.wrong_race"]       = "raza incorrecta"
L["share.reason.wrong_class"]      = "clase incorrecta"
L["share.reason.quest_log_full"]   = "diario de misiones lleno"
L["share.reason.exclusive_quest"]  = "misión exclusiva aceptada"
L["share.reason.already_advanced"] = "ya está más avanzado"
```

- [ ] **Step 4: Write esMX translations (identical to esES)**

Add to `Locales/esMX.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Compartir"
L["share.tooltip"] = "Compartir esta misión con los miembros del grupo"
L["share.reason.level_too_low"]    = "nivel demasiado bajo"
L["share.reason.level_too_high"]   = "nivel demasiado alto"
L["share.reason.wrong_race"]       = "raza incorrecta"
L["share.reason.wrong_class"]      = "clase incorrecta"
L["share.reason.quest_log_full"]   = "diario de misiones lleno"
L["share.reason.exclusive_quest"]  = "misión exclusiva aceptada"
L["share.reason.already_advanced"] = "ya está más avanzado"
```

- [ ] **Step 5: Write zhCN translations**

Add to `Locales/zhCN.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "分享"
L["share.tooltip"] = "与队伍成员分享此任务"
L["share.reason.level_too_low"]    = "等级过低"
L["share.reason.level_too_high"]   = "等级过高"
L["share.reason.wrong_race"]       = "种族不符"
L["share.reason.wrong_class"]      = "职业不符"
L["share.reason.quest_log_full"]   = "任务日志已满"
L["share.reason.exclusive_quest"]  = "已接互斥任务"
L["share.reason.already_advanced"] = "已超过此步骤"
```

- [ ] **Step 6: Write zhTW translations**

Add to `Locales/zhTW.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "分享"
L["share.tooltip"] = "與隊伍成員分享此任務"
L["share.reason.level_too_low"]    = "等級太低"
L["share.reason.level_too_high"]   = "等級太高"
L["share.reason.wrong_race"]       = "種族不符"
L["share.reason.wrong_class"]      = "職業不符"
L["share.reason.quest_log_full"]   = "任務日誌已滿"
L["share.reason.exclusive_quest"]  = "已接互斥任務"
L["share.reason.already_advanced"] = "已超過此步驟"
```

- [ ] **Step 7: Write ptBR translations**

Add to `Locales/ptBR.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Compartilhar"
L["share.tooltip"] = "Compartilhar esta missão com os membros do grupo"
L["share.reason.level_too_low"]    = "nível muito baixo"
L["share.reason.level_too_high"]   = "nível muito alto"
L["share.reason.wrong_race"]       = "raça incorreta"
L["share.reason.wrong_class"]      = "classe incorreta"
L["share.reason.quest_log_full"]   = "diário de missões cheio"
L["share.reason.exclusive_quest"]  = "missão exclusiva aceita"
L["share.reason.already_advanced"] = "já está mais avançado"
```

- [ ] **Step 8: Write itIT translations**

Add to `Locales/itIT.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Condividi"
L["share.tooltip"] = "Condividi questa missione con i membri del gruppo"
L["share.reason.level_too_low"]    = "livello troppo basso"
L["share.reason.level_too_high"]   = "livello troppo alto"
L["share.reason.wrong_race"]       = "razza sbagliata"
L["share.reason.wrong_class"]      = "classe sbagliata"
L["share.reason.quest_log_full"]   = "diario delle missioni pieno"
L["share.reason.exclusive_quest"]  = "missione esclusiva accettata"
L["share.reason.already_advanced"] = "già oltre questo passo"
```

- [ ] **Step 9: Write koKR translations**

Add to `Locales/koKR.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "공유"
L["share.tooltip"] = "이 퀘스트를 파티원과 공유합니다"
L["share.reason.level_too_low"]    = "레벨 부족"
L["share.reason.level_too_high"]   = "레벨 초과"
L["share.reason.wrong_race"]       = "종족 불일치"
L["share.reason.wrong_class"]      = "직업 불일치"
L["share.reason.quest_log_full"]   = "퀘스트 수첩 가득 참"
L["share.reason.exclusive_quest"]  = "독점 퀘스트 수락"
L["share.reason.already_advanced"] = "이미 다음 단계 진행 중"
```

- [ ] **Step 10: Write ruRU translations**

Add to `Locales/ruRU.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "Поделиться"
L["share.tooltip"] = "Поделиться этим заданием с членами группы"
L["share.reason.level_too_low"]    = "уровень слишком низкий"
L["share.reason.level_too_high"]   = "уровень слишком высокий"
L["share.reason.wrong_race"]       = "не та раса"
L["share.reason.wrong_class"]      = "не тот класс"
L["share.reason.quest_log_full"]   = "журнал заданий заполнен"
L["share.reason.exclusive_quest"]  = "принято взаимоисключающее задание"
L["share.reason.already_advanced"] = "уже прошёл этот этап"
```

- [ ] **Step 11: Write jaJP translations**

Add to `Locales/jaJP.lua`:

```lua
-- UI/RowFactory.lua — Share button and eligibility reasons
L["Share"]         = "共有"
L["share.tooltip"] = "このクエストをパーティメンバーと共有する"
L["share.reason.level_too_low"]    = "レベルが低すぎる"
L["share.reason.level_too_high"]   = "レベルが高すぎる"
L["share.reason.wrong_race"]       = "種族が合わない"
L["share.reason.wrong_class"]      = "クラスが合わない"
L["share.reason.quest_log_full"]   = "クエストログが満杯"
L["share.reason.exclusive_quest"]  = "排他クエストを受注済み"
L["share.reason.already_advanced"] = "すでに次のステップに進んでいる"
```

- [ ] **Step 12: Commit all locale files**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add Locales/
git commit -m "feat(locales): add Share button and eligibility reason strings to all 12 locale files"
```

---

### Task 15: Bump SQ version and update CLAUDE.md

**Files:**
- Modify: `D:/Projects/Wow Addons/Social-Quest/SocialQuest.toc`
- Modify: `D:/Projects/Wow Addons/Social-Quest/CLAUDE.md`

- [ ] **Step 1: Check current toc version and determine new version**

Read `SocialQuest.toc` to find the current `## Version:` line. Today is 2026-03-28. If `2.13.x` is the current version and this is the first change today, the new version is `2.14.0`. If changes were already made today, increment the revision instead.

- [ ] **Step 2: Bump toc version**

In `SocialQuest.toc`, update the `## Version:` line to the new version determined above.

- [ ] **Step 3: Add version entry to SQ CLAUDE.md**

Add a new version entry at the top of the Version History section in `CLAUDE.md`:

```markdown
### Version 2.14.0 (March 2026 — Improvements branch)
- Feature: Share button + full quest eligibility. Party tab quest rows now show a `[Share]` button when the local player has the quest, it is shareable, and at least one party member needs it. Clicking calls `QuestLogPushQuest()` via `SQWowAPI` after selecting the quest in the log. Party member rows for ineligible players now show a specific reason label in muted amber (e.g. "level too low", "wrong class", "needs: [Quest Name]") instead of the misleading "Needs it Shared" label. Reason labels cover 7 cases: level_too_low, level_too_high, wrong_race, wrong_class, quest_log_full, exclusive_quest, already_advanced, plus dynamic "needs: questTitle" for prerequisite mismatches. Uses `AQL:GetQuestRequirements(questID)` (new in AQL 2.4.0) for tier-2 checks; degrades gracefully to tier-1-only (race/class/level/log-full) when no provider is available. New `SQWowAPI` wrappers: `QuestLogPushQuest`, `UnitClass`. New private helpers in `PartyTab.lua`: `resolveUnitToken`, updated `isEligibleForShare`. New locale keys in all 12 locale files.
```

- [ ] **Step 4: Commit**

```bash
cd "D:/Projects/Wow Addons/Social-Quest"
git add SocialQuest.toc CLAUDE.md
git commit -m "chore: bump SQ version for share button + eligibility feature"
```

---

## In-Game Verification Checklist

After all tasks are complete, verify the following scenarios in-game with at least one party member:

- [ ] Party tab shows `[Share]` button on a quest row when at least one member is eligible
- [ ] Party tab hides `[Share]` button when no members are eligible (all have reasons)
- [ ] Party tab hides `[Share]` button on quests the local player doesn't have
- [ ] Clicking `[Share]` broadcasts the quest to party (other player gets accept dialog)
- [ ] Ineligible member shows amber reason label (e.g. test with a low-level character)
- [ ] "Needs it Shared" still appears for eligible members (green check expected)
- [ ] Member who already has the quest shows progress normally (not in eligibility rows)
- [ ] Member who already completed the quest shows "FINISHED" normally
- [ ] Non-shareable quests (daily, group quests with pushable=false) show no `[Share]` button and no eligibility rows
- [ ] No Lua errors in chat with `/sq debug on` during all the above
- [ ] No Lua errors in chat with `/aql debug on` while verifying `GetQuestRequirements` returns data
