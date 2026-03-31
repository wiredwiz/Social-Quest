# SocialQuest Multi-Version Support Design

**Date:** 2026-03-31
**Scope:** Add full-parity support for Classic Era/SOD/HC (11508), Classic MoP (50503), and Retail (120001) alongside existing TBC (20505). Also fixes the `SelectBestChain` per-player engagement bug.

---

## Section 1 — TOC Files

Create three companion TOC files alongside `SocialQuest.toc`. All four files share an identical file list — no conditional loading.

| File | Interface | Target |
|------|-----------|--------|
| `SocialQuest.toc` | 20505 | TBC (existing) |
| `SocialQuest_Classic.toc` | 11508 | Classic Era / SOD / HC |
| `SocialQuest_Mists.toc` | 50503 | Classic MoP |
| `SocialQuest_Mainline.toc` | 120001 | Retail |

Each companion TOC copies all metadata fields from the original and changes only `## Interface`.

---

## Section 2 — Version Detection Constants

Add to `Core/WowAPI.lua`, evaluated once at load time:

```lua
local _toc = select(4, GetBuildInfo())
SocialQuestWowAPI.IS_CLASSIC_ERA = _toc >= 11000 and _toc < 20000
SocialQuestWowAPI.IS_TBC         = _toc >= 20000 and _toc < 30000
SocialQuestWowAPI.IS_MOP         = _toc >= 50000 and _toc < 60000
SocialQuestWowAPI.IS_RETAIL      = _toc >= 100000
```

All version-branching logic throughout the codebase reads from these constants.

---

## Section 3 — WowAPI.lua Additions

### `QuestLogPushQuest`

`QuestLogPushQuest()` is removed on Retail. Replace all call sites with `SQWowAPI.QuestLogPushQuest(questID)`:

```lua
function SocialQuestWowAPI.QuestLogPushQuest(questID)
    if SocialQuestWowAPI.IS_RETAIL then
        C_QuestLog.PushQuestToParty(questID)
    else
        QuestLogPushQuest()
    end
end
```

Call site in `PartyTab.lua` line ~509 currently passes no argument — fix to pass `questID`.

### `GetRaidRosterInfo`

`GetRaidRosterInfo` is a free function on Classic/TBC/MoP, moved to `C_RaidRoster` namespace on Retail. Existing wrapper gains Retail fallback:

```lua
function SocialQuestWowAPI.GetRaidRosterInfo(index)
    if SocialQuestWowAPI.IS_RETAIL and C_RaidRoster then
        return C_RaidRoster.GetRaidRosterInfo(index)
    end
    return GetRaidRosterInfo(index)
end
```

### `MAX_QUEST_LOG_ENTRIES`

Quest log capacity differs by version. Add as a constant:

```lua
SocialQuestWowAPI.MAX_QUEST_LOG_ENTRIES = SocialQuestWowAPI.IS_RETAIL and 35 or 25
```

Replace hardcoded `25` in `PartyTab.lua` line ~126 with `SQWowAPI.MAX_QUEST_LOG_ENTRIES`.

### Race and Class ID Reference Tables

Added to `WowAPI.lua` for reference. Not used in eligibility logic — bitmasks are computed as `2^(id-1)` at runtime.

```lua
-- Reference: WoW numeric race IDs (select(3, UnitRace(unit))).
SocialQuestWowAPI.RACE_ID = {
    Human              = 1,
    Orc                = 2,
    Dwarf              = 3,
    NightElf           = 4,
    Undead             = 5,
    Tauren             = 6,
    Gnome              = 7,
    Troll              = 8,
    Goblin             = 9,
    BloodElf           = 10,
    Draenei            = 11,
    Worgen             = 22,
    Pandaren           = 24,
    Nightborne         = 27,
    HighmountainTauren = 28,
    VoidElf            = 29,
    LightforgedDraenei = 30,
    ZandalariTroll     = 31,
    KulTiran           = 32,
    DarkIronDwarf      = 34,
    Vulpera            = 35,
    MagharOrc          = 36,
    Mechagnome         = 37,
}

-- Reference: WoW numeric class IDs (select(3, UnitClass(unit))).
SocialQuestWowAPI.CLASS_ID = {
    Warrior     = 1,
    Paladin     = 2,
    Hunter      = 3,
    Rogue       = 4,
    Priest      = 5,
    DeathKnight = 6,
    Shaman      = 7,
    Mage        = 8,
    Warlock     = 9,
    Monk        = 10,
    Druid       = 11,
    DemonHunter = 12,
    Evoker      = 13,
}
```

---

## Section 4 — QuestieBridge.lua: C_Timer.After Cleanup

`QuestieBridge.lua` contains 9 direct `C_Timer.After(delay, fn)` calls (lines 178, 263, 272, 278, 287, 290, 297, 306, 309) that bypass the established `SQWowAPI.TimerAfter` wrapper. The file already declares `local SQWowAPI = SocialQuestWowAPI` at the top.

Replace each occurrence:
```lua
-- Before
C_Timer.After(delay, fn)

-- After
SQWowAPI.TimerAfter(delay, fn)
```

No behavior change — this ensures all timer calls route through the single wrapper, which is the correct extension point for any future version branching on timers.

---

## Section 5 — Race/Class Eligibility Fix (PartyTab.lua)

### Problem

`PartyTab.lua` currently uses `RACE_BITS` and `CLASS_BITS` string-lookup tables that map race/class names to hardcoded bit values. This approach breaks for allied races whose IDs were assigned non-sequentially.

### Fix

Remove `RACE_BITS` and `CLASS_BITS` tables entirely. Use the numeric ID from `select(3, UnitRace/UnitClass)` directly with the `2^(id-1)` formula — the same approach Questie uses (confirmed in `Questie/Modules/QuestiePlayer.lua` lines 32–34).

```lua
local raceId = select(3, SQWowAPI.UnitRace(unitToken))
if raceId and reqs.requiredRaces then
    if bit.band(reqs.requiredRaces, 2 ^ (raceId - 1)) == 0 then
        return { eligible = false, reason = { code = "wrong_race" } }
    end
end

local classId = select(3, SQWowAPI.UnitClass(unitToken))
if classId and reqs.requiredClasses then
    if bit.band(reqs.requiredClasses, 2 ^ (classId - 1)) == 0 then
        return { eligible = false, reason = { code = "wrong_class" } }
    end
end
```

### Provider Compatibility

- **Questie provider:** Returns `quest.requiredRaces` bitmask using `2^(raceId-1)` — formula reads it back correctly.
- **Grail provider:** Explicitly returns `requiredRaces = nil` and `requiredClasses = nil` (bitmask mapping deferred). Both checks are silently skipped — correct behavior.

---

## Section 6 — SelectBestChain Per-Player Engagement Fix

### Problem

`SelectBestChain` requires an engaged quest set to pick the best chain entry when a quest belongs to multiple chains. Currently all call sites pass the **local player's** engaged set, which is wrong when displaying chain info for a remote player's quest (their position in the chain may differ).

### New Helper: `TabUtils.BuildEngagedSet`

Add to `UI/TabUtils.lua`:

```lua
-- Builds an engaged quest set (active + completed) for a named player,
-- or the local player if playerName is nil.
function SocialQuestTabUtils.BuildEngagedSet(playerName)
    local AQL = SocialQuest.AQL
    if not playerName then
        return AQL:_GetCurrentPlayerEngagedQuests()
    end
    local pdata = SocialQuest.GroupData:GetPlayerData(playerName)
    if not pdata then return nil end
    local engaged = {}
    for qid in pairs(pdata.quests or {}) do engaged[qid] = true end
    for qid in pairs(pdata.completedQuests or {}) do engaged[qid] = true end
    return engaged
end
```

Both active and completed quests are included — completed quests can inform which branch of a chain the player is on.

### Call Site Changes

**`Core/Announcements.lua` — `appendChainStep`**

Add optional `sender` parameter. When non-nil, use `BuildEngagedSet(sender)` instead of the local player's set:

```lua
local function appendChainStep(lines, questID, sender)
    local chainResult = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
    local engaged = SocialQuestTabUtils.BuildEngagedSet(sender)  -- nil = local player
    local chain = SocialQuestTabUtils.SelectChain(chainResult, engaged)
    -- ... rest unchanged
end
```

`OnRemoteQuestEvent` already has `sender` available and passes it through.

**`UI/Tabs/PartyTab.lua` and `UI/Tabs/SharedTab.lua` — row building**

When constructing each remote player's quest row:

```lua
local engaged = SocialQuestTabUtils.BuildEngagedSet(playerName)
local chainResult = SocialQuestTabUtils.GetChainInfoForQuestID(questID)
entry.chainInfo = chainResult
local chain = SocialQuestTabUtils.SelectChain(chainResult, engaged)
```

**`UI/Tabs/MineTab.lua`** — no change. Local player rows continue to use `BuildEngagedSet(nil)` (which returns `AQL:_GetCurrentPlayerEngagedQuests()`).

---

## Section 7 — Tooltip Hook (Retail)

`UI/Tooltips.lua` currently hooks `ItemRefTooltip:SetHyperlink`. On Retail, `TooltipDataProcessor` is the correct extension point.

```lua
function SocialQuestTooltips:Initialize()
    if SocialQuestWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )
    else
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local questID = tonumber(link:match("quest:(%d+)"))
            if questID then
                addGroupProgressToTooltip(self, questID)
            end
        end)
    end
end
```

The `addGroupProgressToTooltip(tooltip, questID)` internal function signature is unchanged — both paths call it the same way.

---

## APIs Confirmed Unchanged Across All Versions

The following were explicitly verified as present on Classic Era, TBC, MoP, and Retail — no branching required:

- `LE_PARTY_CATEGORY_HOME` / `LE_PARTY_CATEGORY_INSTANCE`
- `PanelTemplates_SetNumTabs` / `PanelTemplates_UpdateTabs` / `PanelTemplates_SelectTab` / `PanelTemplates_DeselectTab`
- `RaidWarningFrame` / `RaidNotice_AddMessage`
- `UIErrorsFrame:AddMessage`
- `AUTOFOLLOW_BEGIN` / `AUTOFOLLOW_END` events
- `UnitFullName`
- `C_FriendList.*` (already wrapped)
- `C_Timer.After` (already wrapped as `SQWowAPI.TimerAfter`)
- `UnitRace` / `UnitClass` (already wrapped; both return numeric ID as third value on all versions)

---

## Summary of File Changes

| File | Change |
|------|--------|
| `SocialQuest_Classic.toc` | New — Interface 11508 |
| `SocialQuest_Mists.toc` | New — Interface 50503 |
| `SocialQuest_Mainline.toc` | New — Interface 120001 |
| `Core/WowAPI.lua` | Version constants, `QuestLogPushQuest`, `GetRaidRosterInfo` fallback, `MAX_QUEST_LOG_ENTRIES`, `RACE_ID`/`CLASS_ID` tables |
| `Core/QuestieBridge.lua` | Replace 9 direct `C_Timer.After` calls with `SQWowAPI.TimerAfter` |
| `UI/Tooltips.lua` | Retail `TooltipDataProcessor` path in `Initialize` |
| `UI/TabUtils.lua` | Add `BuildEngagedSet(playerName)` helper |
| `UI/Tabs/PartyTab.lua` | Remove `RACE_BITS`/`CLASS_BITS`; fix eligibility formula; fix `QuestLogPushQuest(questID)`; replace hardcoded `25`; use `BuildEngagedSet` |
| `UI/Tabs/SharedTab.lua` | Use `BuildEngagedSet` for remote player chain lookup |
| `Core/Announcements.lua` | Add `sender` param to `appendChainStep`; use `BuildEngagedSet` |
