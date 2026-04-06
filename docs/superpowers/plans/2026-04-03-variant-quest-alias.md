# Variant Quest Alias Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix "Everyone has completed" never firing, and Party/Shared tab duplicating entries, when party members hold Retail variant questIDs for the same logical quest.

**Architecture:** AQL gains `QuestCache:_buildAliasKey` (fingerprint) and two public methods (`GetQuestAliasKey`, `AreQuestsAliases`). SQ's `checkAllFinished` is renamed to `checkAllCompleted` and rewritten to match remote players by quest title (since remote quest data stores title but not the full fingerprint). Party and Shared tabs add title-based entry merging to collapse variant questID rows into one.

**Tech Stack:** Lua 5.1 (WoW), LibStub, AceLocale. No new dependencies.

---

## File Map

| File | Change |
|------|--------|
| `AbsoluteQuestLog/Core/QuestCache.lua` | Add `_buildAliasKey(info)` method |
| `AbsoluteQuestLog/AbsoluteQuestLog.lua` | Add `GetQuestAliasKey`, `AreQuestsAliases`; bump version |
| `AbsoluteQuestLog/AbsoluteQuestLog.toc` | Bump version to 3.3.0 |
| `AbsoluteQuestLog/AbsoluteQuestLog_Mainline.toc` | Bump version to 3.3.0 |
| `AbsoluteQuestLog/changelog.txt` | Add 3.3.0 entry |
| `AbsoluteQuestLog/CLAUDE.md` | Add 3.3.0 to Version History |
| `SocialQuest/Core/Announcements.lua` | Rename to `checkAllCompleted`; title-based alias match; language cleanup |
| `SocialQuest/UI/Tabs/PartyTab.lua` | Add `mergePlayers` helper; title-based `zone.quests` dedup |
| `SocialQuest/UI/Tabs/SharedTab.lua` | Title-based `questEngaged` merge |
| `SocialQuest/SocialQuest.toc` | Bump version to 2.18.0 |
| `SocialQuest/SocialQuest_Mainline.toc` | Bump version to 2.18.0 |
| `SocialQuest/CLAUDE.md` | Add 2.18.0 to Version History |

---

### Task 1: AQL — `QuestCache:_buildAliasKey`

**Files:**
- Modify: `AbsoluteQuestLog/Core/QuestCache.lua` (append after line 233, end of file)

- [ ] **Step 1: Add `_buildAliasKey` to QuestCache**

Open `AbsoluteQuestLog/Core/QuestCache.lua`. The file currently ends at line 233 (`end` of `GetAll`). Append the following after that final `end`:

```
function QuestCache:_buildAliasKey(info)
    -- Builds a stable fingerprint for a quest from its observable player identity:
    -- title, zone, and sorted objective name/count pairs. Retail variant questIDs
    -- (different numeric IDs for the same logical quest across race/class types)
    -- produce identical keys. Internal — not part of the public API.
    local parts = {}
    for _, obj in ipairs(info.objectives or {}) do
        table.insert(parts, (obj.name or obj.text or "") .. "/" .. tostring(obj.numRequired or 1))
    end
    table.sort(parts)
    return (info.title or "") .. ":" .. (info.zone or "") .. ":" .. table.concat(parts, "|")
end
```

- [ ] **Step 2: Verify no syntax errors**

Open a WoW session or a standalone Lua runner and load the file. Expected: no "attempt to" or "unexpected symbol" errors from this file.

In the absence of a WoW session, visually inspect: the function takes `info` (a table with `objectives`, `title`, `zone` fields), builds a sorted array of `"name/numRequired"` strings, and returns a concatenation. No global references; no WoW API calls.

- [ ] **Step 3: Commit**

```
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add Core/QuestCache.lua
git commit -m "feat(aql): add QuestCache:_buildAliasKey fingerprint helper"
```

---

### Task 2: AQL — Public alias API + version bump

**Files:**
- Modify: `AbsoluteQuestLog/AbsoluteQuestLog.lua` (insert after line 166)
- Modify: `AbsoluteQuestLog/AbsoluteQuestLog.toc`
- Modify: `AbsoluteQuestLog/AbsoluteQuestLog_Mainline.toc`
- Modify: `AbsoluteQuestLog/changelog.txt`
- Modify: `AbsoluteQuestLog/CLAUDE.md`

- [ ] **Step 1: Insert public API methods into AbsoluteQuestLog.lua**

In `AbsoluteQuestLog/AbsoluteQuestLog.lua`, find the block after `IsQuestFinished` ends (currently line 166) and before the `-- Quest History` section header (currently line 168). Insert the following between those two lines:

```
------------------------------------------------------------------------
-- Quest Alias
------------------------------------------------------------------------

-- GetQuestAliasKey(questID) → string or nil
-- Returns a stable fingerprint key for questID based on title, zone, and
-- sorted objective name/count pairs. Two questIDs that are the same logical
-- quest (e.g. Retail variant questIDs assigned per race/class character type)
-- return identical keys.
-- On non-Retail versions: returns tostring(questID) — no fingerprint overhead.
-- On Retail: returns nil when questID is not in the active QuestCache.
--   Callers that need a fallback should use: AQL:GetQuestAliasKey(id) or tostring(id)
function AQL:GetQuestAliasKey(questID)
    if not WowQuestAPI.IS_RETAIL then
        return tostring(questID)
    end
    local info = self.QuestCache and self.QuestCache:Get(questID)
    if not info then return nil end
    return self.QuestCache:_buildAliasKey(info)
end

-- AreQuestsAliases(id1, id2) → bool
-- Returns true if id1 and id2 are the same logical quest from a player perspective
-- (identical fingerprint key). Returns false when either questID is not in cache.
function AQL:AreQuestsAliases(id1, id2)
    local k1 = self:GetQuestAliasKey(id1)
    return k1 ~= nil and k1 == self:GetQuestAliasKey(id2)
end

```

The result: after line 166 (`end` of `IsQuestFinished`), a blank line, then the `-- Quest Alias` section, then a blank line, then the existing `-- Quest History` section header.

- [ ] **Step 2: Bump version to 3.3.0 in both toc files**

In `AbsoluteQuestLog/AbsoluteQuestLog.toc`, change:
```
## Version: 3.2.19
```
to:
```
## Version: 3.3.0
```

In `AbsoluteQuestLog/AbsoluteQuestLog_Mainline.toc`, make the same change.

- [ ] **Step 3: Add changelog entry**

In `AbsoluteQuestLog/changelog.txt`, prepend at the top:

```
Version 3.3.0 (April 2026)
- Feature: AQL:GetQuestAliasKey(questID) — returns a stable fingerprint key for a
  quest (title + zone + sorted objective names/counts). On Retail, two questIDs that
  represent the same logical quest (variant questIDs assigned per race/class character
  type) return identical keys. On non-Retail, returns tostring(questID) with no overhead.
  Returns nil on Retail when questID is not in the active cache.
- Feature: AQL:AreQuestsAliases(id1, id2) — convenience wrapper; returns true when
  both questIDs share the same alias key (both in cache and fingerprints match).
- New internal: QuestCache:_buildAliasKey(info) — private fingerprint builder used by
  GetQuestAliasKey.

```

- [ ] **Step 4: Update CLAUDE.md Version History**

In `AbsoluteQuestLog/CLAUDE.md`, in the Version History section, prepend before the `### Version 3.2.19` entry:

```
### Version 3.3.0 (April 2026)
- Feature: `AQL:GetQuestAliasKey(questID)` — returns a stable fingerprint key for a
  quest (title + zone + sorted objective names/counts). On Retail, two questIDs that
  represent the same logical quest (variant questIDs assigned per race/class character
  type) return identical keys. On non-Retail, returns `tostring(questID)` with no
  overhead. Returns `nil` on Retail when questID is not in the active cache.
- Feature: `AQL:AreQuestsAliases(id1, id2)` — convenience wrapper; returns `true` when
  both questIDs share the same alias key.
- Internal: `QuestCache:_buildAliasKey(info)` — private fingerprint builder.

```

Also update the Public API table in CLAUDE.md to add the two new methods under Quest State:

```
| `AQL:GetQuestAliasKey(questID)` | string or nil | Fingerprint key — same for Retail variant questIDs of the same logical quest. `tostring(questID)` on non-Retail. `nil` on Retail if not in cache. |
| `AQL:AreQuestsAliases(id1, id2)` | bool | True if both IDs fingerprint to the same quest. False when either is not in cache. |
```

- [ ] **Step 5: Commit**

```
cd "D:/Projects/Wow Addons/Absolute-Quest-Log"
git add AbsoluteQuestLog.lua AbsoluteQuestLog.toc AbsoluteQuestLog_Mainline.toc changelog.txt CLAUDE.md
git commit -m "feat(aql): add GetQuestAliasKey and AreQuestsAliases public API (v3.3.0)"
```

---

### Task 3: SQ — Rename `checkAllFinished` → `checkAllCompleted` + alias-aware logic

**Files:**
- Modify: `SocialQuest/Core/Announcements.lua`

This task replaces the entire `checkAllFinished` function and updates all references to it. The new function uses quest title matching to find remote players' variant questIDs (remote quest data stores `qdata.title` but not the full fingerprint, so title comparison is the correct cross-source comparison).

- [ ] **Step 1: Update the forward declaration (line 194)**

Change:
```
local checkAllFinished  -- forward declaration; defined below after OnQuestEvent/OnRemoteQuestEvent
```
to:
```
local checkAllCompleted  -- forward declaration; defined below after OnQuestEvent/OnRemoteQuestEvent
```

- [ ] **Step 2: Update the call in `OnQuestEvent` (lines 257–261)**

Change:
```
    -- Party-wide objectives check: fires "Everyone has finished" when all engaged
    -- group members have completed this quest's objectives.
    if eventType == ET.Finished then
        checkAllFinished(questID, true)
    end
```
to:
```
    -- Party-wide objectives check: fires "Everyone has completed" when all engaged
    -- group members have completed this quest's objectives.
    if eventType == ET.Finished then
        checkAllCompleted(questID, true)
    end
```

- [ ] **Step 3: Replace the entire `checkAllFinished` function definition (lines 311–411)**

Remove everything from `-- Fires "Everyone has finished [Quest Name]"` (line 311) through the closing `end` of the function (line 411), and replace with:

```
-- Fires "Everyone has completed [Quest Name]" when every engaged group member
-- (those who have or had the quest) has completed all objectives.
-- Suppressed entirely if any group member lacks SocialQuest (hasSocialQuest == false).
-- localHasCompleted: true when the local player just triggered this via OnQuestEvent;
--                    false when a remote player's SQ_UPDATE triggered it.
checkAllCompleted = function(questID, localHasCompleted)
    -- db.enabled is checked here rather than relying on callers: this function is
    -- called from two separate entry points and must be self-contained.
    local db = SocialQuest.db.profile
    if not db.enabled then return end

    local PlayerQuests = SocialQuestGroupData.PlayerQuests

    -- Must be in a group (PlayerQuests only contains remote members).
    local anyRemote = false
    for _ in pairs(PlayerQuests) do anyRemote = true; break end
    if not anyRemote then
        SocialQuest:Debug("Banner", "All completed suppressed: not in group")
        return
    end

    -- Every group member must have a data source (SQ or bridge); suppress if any has neither.
    -- Without full visibility, we cannot reliably confirm that everyone has completed.
    for _, entry in pairs(PlayerQuests) do
        if not entry.hasSocialQuest and not entry.dataProvider then
            SocialQuest:Debug("Banner", "All completed suppressed: member with no data present")
            return
        end
    end

    local AQL = SocialQuest.AQL

    -- Title of the triggering quest. Used to match variant questIDs for remote players:
    -- GroupData stores qdata.title (resolved from AQL) but not the full fingerprint,
    -- so title comparison is the correct cross-source alias detection method.
    local triggerTitle = AQL and AQL:GetQuestTitle(questID)

    -- Local player: engaged if they just completed objectives or have the quest active.
    local localActive  = AQL and AQL:GetQuest(questID) ~= nil
    local localEngaged = localHasCompleted or localActive
    local localQuest   = AQL and AQL:GetQuest(questID)
    local localDone    = localHasCompleted
                      or (localQuest and localQuest.isComplete)
                      or (AQL and AQL:HasCompletedQuest(questID))
    if localEngaged and not localDone then
        SocialQuest:Debug("Banner", "All completed suppressed: local player engaged but not done")
        return
    end

    -- Remote players: check engagement and objective completion.
    -- "Engaged" = has any quest whose title matches the triggering quest.
    -- This handles Retail variant questIDs (same title, different numeric ID).
    local anyEngaged = localEngaged
    for _, entry in pairs(PlayerQuests) do
        -- Find this player's variant of the quest by title match.
        local matchedQuestData = nil
        local hasCompleted     = false

        if entry.quests and triggerTitle then
            for _, qdata in pairs(entry.quests) do
                if qdata.title and qdata.title == triggerTitle then
                    matchedQuestData = qdata
                    break
                end
            end
        end

        -- Also check completedQuests (quest turned in before we checked).
        -- Title must be resolved via AQL for each completed questID.
        if not matchedQuestData and triggerTitle and entry.completedQuests then
            for remoteQuestID in pairs(entry.completedQuests) do
                if AQL and AQL:GetQuestTitle(remoteQuestID) == triggerTitle then
                    hasCompleted = true
                    break
                end
            end
        end

        local engaged = matchedQuestData ~= nil or hasCompleted
        if engaged then
            anyEngaged = true
            local done = (matchedQuestData and matchedQuestData.isComplete) or hasCompleted
            if not done then
                SocialQuest:Debug("Banner", "All completed suppressed: not all engaged players completed")
                return
            end
        end
    end

    -- No one in the group has or had the quest.
    if not anyEngaged then
        SocialQuest:Debug("Banner", "All completed suppressed: no engaged players")
        return
    end

    -- Display gating: same toggle as the individual "objectives done" banners.
    local section   = getSenderSection()
    local sectionDb = db[section]
    if not sectionDb or not sectionDb.display then return end
    if not sectionDb.display.finished then
        SocialQuest:Debug("Banner", "All completed suppressed: display.finished off")
        return
    end

    -- Title resolution: plain text — RaidNotice does not parse hyperlinks.
    local info  = AQL and AQL:GetQuest(questID)
    local title = (info and info.title)
               or (AQL and AQL:GetQuestTitle(questID))
               or ("Quest " .. questID)

    local msg = string.format(L["Everyone has completed: %s"], title)
    SocialQuest:Debug("Banner", "All completed: questID=" .. questID .. " \xe2\x80\x94 banner displayed")
    displayBanner(msg, "all_complete")

    -- Chat message only when the local player triggered it (avoids duplicate
    -- sends from multiple SQ clients simultaneously detecting the same condition).
    if localHasCompleted and sectionDb.transmit and sectionDb.announce.finished then
        local channelMap = { party = "PARTY", raid = "RAID", battleground = "BATTLEGROUND" }
        local channel = channelMap[section]
        if channel then
            enqueueChat(msg, channel)
        end
    end
end
```

- [ ] **Step 4: Update the call in `OnRemoteQuestEvent` (lines 431–433)**

Change:
```
    -- Party-wide objectives check: fires regardless of displayReceived, because
    -- "Everyone has finished" is a synthesized local event, not a raw inbound banner.
    if eventType == ET.Finished then
        checkAllFinished(questID, false)
    end
```
to:
```
    -- Party-wide objectives check: fires regardless of displayReceived, because
    -- "Everyone has completed" is a synthesized local event, not a raw inbound banner.
    if eventType == ET.Finished then
        checkAllCompleted(questID, false)
    end
```

- [ ] **Step 5: Verify no remaining references to `checkAllFinished`**

Run:
```
grep -n "checkAllFinished" "D:/Projects/Wow Addons/Social-Quest/Core/Announcements.lua"
```
Expected output: empty (no matches). If any remain, fix them.

- [ ] **Step 6: Run test suite**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both report 0 failures.

- [ ] **Step 7: Commit**

```
cd "D:/Projects/Wow Addons/Social-Quest"
git add Core/Announcements.lua
git commit -m "fix(sq): rename checkAllFinished to checkAllCompleted; use title-based alias detection for variant questIDs"
```

---

### Task 4: SQ — Party tab title-based merge for ungrouped quests

**Files:**
- Modify: `SocialQuest/UI/Tabs/PartyTab.lua`

The Party tab already merges chain-step variant questIDs via `chainStepEntries[chainID][step]` (lines 331–345). This task adds equivalent merging for the `zone.quests` (ungrouped) path, which handles non-chain variant questIDs.

Note: `buildPlayerRowsForQuest(questID, localHasIt)` is called once per questID. When the local player has questID A and a remote player has questID B (aliases), questID A's call finds the local player and shows the remote as "needsShare", while questID B's call finds the remote player with real data. The `mergePlayers` helper deduplicates by name, preferring the entry with real quest data over the "needsShare" placeholder.

- [ ] **Step 1: Add `mergePlayers` helper and `questsByTitleByZone` tracking table**

In `BuildTree`, immediately after the existing declaration on line 269:
```
    local chainStepEntriesByZone = {}
```
add:
```
    local questsByTitleByZone    = {}   -- zoneName → {title → entry} for ungrouped quest dedup
```

Then, immediately after the `local chainStepEntriesByZone = {}` line and before the `for questID in pairs(allQuestIDs) do` loop, insert the `mergePlayers` local function:

```
    -- Merges source players into target, deduplicating by player name.
    -- When a player appears in both lists, the entry with real quest data is
    -- preferred over a "needsShare" placeholder row (which is only added when
    -- the local player has a shareable quest and the remote player lacks it by
    -- exact-ID lookup — the variant case produces this false placeholder).
    local function mergePlayers(target, source)
        local byName = {}
        for i, p in ipairs(target) do
            byName[p.name] = i
        end
        for _, p in ipairs(source) do
            local idx = byName[p.name]
            if idx then
                -- Player already present. Prefer the entry with real quest data.
                if target[idx].needsShare and not p.needsShare then
                    target[idx] = p
                end
            else
                table.insert(target, p)
                byName[p.name] = #target
            end
        end
    end
```

- [ ] **Step 2: Replace the `else` branch in `BuildTree` that inserts into `zone.quests`**

Find the current `else` branch (line 346–348):
```
            else
                table.insert(zone.quests, entry)
            end
```

Replace with:
```
            else
                -- Ungrouped quest: group by title to merge Retail variant questIDs.
                -- (Non-chain quests with the same title are the same logical quest.)
                if not questsByTitleByZone[zoneName] then
                    questsByTitleByZone[zoneName] = {}
                end
                local titleKey  = entry.title
                local existing  = questsByTitleByZone[zoneName][titleKey]
                if existing then
                    mergePlayers(existing.players, entry.players)
                    -- Recompute hasShareableMembers — dedup may have removed needsShare rows.
                    existing.hasShareableMembers = false
                    for _, pl in ipairs(existing.players) do
                        if pl.needsShare then existing.hasShareableMembers = true; break end
                    end
                    -- Prefer the local player's entry data (logIndex, questID) for interactions.
                    if entry.logIndex and not existing.logIndex then
                        existing.questID    = entry.questID
                        existing.logIndex   = entry.logIndex
                        existing.isComplete = entry.isComplete
                        existing.isFailed   = entry.isFailed
                        existing.isTracked  = entry.isTracked
                    end
                else
                    questsByTitleByZone[zoneName][titleKey] = entry
                    table.insert(zone.quests, entry)
                end
            end
```

- [ ] **Step 3: Run test suite**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both report 0 failures.

- [ ] **Step 4: Commit**

```
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Tabs/PartyTab.lua
git commit -m "fix(sq): Party tab — merge ungrouped variant questID entries by title"
```

---

### Task 5: SQ — Shared tab title-based merge for `questEngaged`

**Files:**
- Modify: `SocialQuest/UI/Tabs/SharedTab.lua`

The Shared tab's `questEngaged` table is keyed by questID. When two players hold alias questIDs (e.g. 101 and 102), each entry has only one player and the count-≥2 gate never fires — neither quest appears in the Shared tab. This task adds a title-based merge pass after `questEngaged` is built and before it is processed.

- [ ] **Step 1: Add title-based merge pass for `questEngaged`**

In `BuildTree`, find the comment `-- Step 2: build tree from groups with 2+ engaged players.` (currently around line 61). Insert the following block immediately before that comment (after the closing `end` of the `addEngagement` loops):

```
    -- Merge questEngaged entries with matching titles to handle Retail variant questIDs:
    -- same logical quest, different numeric IDs per race/class character type.
    -- Chain-grouped quests are already deduplicated by chainEngaged (step-number keying),
    -- so this pass only affects non-chain quests in questEngaged.
    -- On non-Retail this is a safe no-op (all quest titles are unique per zone in practice).
    do
        local mergedQuestEngaged = {}
        local questEngagedByTitle = {}
        for questID, engaged in pairs(questEngaged) do
            local title = AQL:GetQuestTitle(questID) or ("Quest " .. questID)
            local canonID = questEngagedByTitle[title]
            if canonID then
                -- Another questID with the same title already exists; merge players into it.
                for playerName, eng in pairs(engaged) do
                    if not mergedQuestEngaged[canonID][playerName] then
                        mergedQuestEngaged[canonID][playerName] = eng
                    end
                end
            else
                questEngagedByTitle[title]  = questID
                mergedQuestEngaged[questID] = engaged
            end
        end
        questEngaged = mergedQuestEngaged
    end
```

- [ ] **Step 2: Run test suite**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both report 0 failures.

- [ ] **Step 3: Commit**

```
cd "D:/Projects/Wow Addons/Social-Quest"
git add UI/Tabs/SharedTab.lua
git commit -m "fix(sq): Shared tab — merge variant questID questEngaged entries by title"
```

---

### Task 6: SQ version bump + CLAUDE.md updates

**Files:**
- Modify: `SocialQuest/SocialQuest.toc`
- Modify: `SocialQuest/SocialQuest_Mainline.toc`
- Modify: `SocialQuest/CLAUDE.md`

- [ ] **Step 1: Bump SQ version to 2.18.0 in both toc files**

In `SocialQuest/SocialQuest.toc`, change:
```
## Version: 2.17.19
```
to:
```
## Version: 2.18.0
```

In `SocialQuest/SocialQuest_Mainline.toc`, make the same change.

- [ ] **Step 2: Add 2.18.0 to CLAUDE.md Version History**

In `SocialQuest/CLAUDE.md`, prepend before the `### Version 2.17.19` entry:

```
### Version 2.18.0 (April 2026 — Improvements branch)
- Bug fix: "Everyone has completed" banner now fires correctly when party members hold
  Retail variant questIDs for the same logical quest (same title, different numeric ID
  per race/class character type). `checkAllFinished` renamed to `checkAllCompleted`
  throughout. Remote player matching now uses quest title comparison (`qdata.title`)
  rather than exact questID lookup, so variant questIDs are correctly detected as the
  same quest.
- Bug fix: Party tab no longer shows duplicate rows for Retail variant questIDs of the
  same ungrouped (non-chain) quest. Entries are merged by title via new `mergePlayers`
  deduplication helper that prefers real quest-data rows over "needsShare" placeholders.
- Bug fix: Shared tab no longer requires both players to have the identical questID for
  a quest to appear. Title-based merge of `questEngaged` entries means variant questIDs
  of the same quest now combine their player counts, correctly reaching the 2+ threshold.
- Language cleanup: all internal debug messages and comments around the "everyone done"
  check updated from "finished" to "completed" for consistency with the displayed
  `L["Everyone has completed: %s"]` string.
- Requires: AQL 3.3.0 (`GetQuestAliasKey`, `AreQuestsAliases` available; `checkAllCompleted`
  uses `AQL:GetQuestTitle` for cross-source title resolution).

```

- [ ] **Step 3: Run test suite one final time**

```
cd "D:/Projects/Wow Addons/Social-Quest"
lua tests/FilterParser_test.lua
lua tests/TabUtils_test.lua
```
Expected: both report 0 failures.

- [ ] **Step 4: Commit**

```
cd "D:/Projects/Wow Addons/Social-Quest"
git add SocialQuest.toc SocialQuest_Mainline.toc CLAUDE.md
git commit -m "chore(sq): bump version to 2.18.0; update CLAUDE.md"
```
