# Class Quest Zone Resolution Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transmit a numeric class ID alongside class quest data in the SQ comm protocol so remote clients can correctly group class quests under the appropriate localized class-name zone header in the Party and Shared tabs.

**Architecture:** The sender detects class quests by matching AQL's zone string against a runtime-built reverse lookup keyed on `LOCALIZED_CLASS_NAMES_MALE`. A single optional integer field (`classID`) is added to the existing SQ_INIT and SQ_UPDATE payloads. Receivers store it on the quest entry; the display layer resolves it back to a localized class name at render time via the same WoW global.

**Tech Stack:** Lua, WoW addon API (`LOCALIZED_CLASS_NAMES_MALE`), AceSerializer (existing), AQL (existing).

---

## Problem

WoW's quest log groups class quests under a zone header that is the localized class name ("Warrior", "Priest", etc.) rather than a geographic zone. `AQL:GetQuest(questID)` returns this header correctly for quests in the local player's active log. For remote players' class quests — resolved via `AQL:GetQuestInfo(questID)` through Questie/Grail provider data — the provider returns the quest's geographic zone instead of the class-name header, causing class quests to appear under the wrong zone or under "Other Quests" in the SQ group window.

SQ players can fix this by exchanging the class ID, since each sender always has their own class quests in their local log and can detect them reliably.

---

## Key Design Decisions

**Why numeric class ID, not the class name string?**
A single integer is small, version-agnostic, and language-agnostic. The sender and receiver independently resolve it to their own client's localized class name via `LOCALIZED_CLASS_NAMES_MALE`, so no translations need to be transmitted or hardcoded.

**Why `LOCALIZED_CLASS_NAMES_MALE` and not our own locale table?**
`LOCALIZED_CLASS_NAMES_MALE` is a WoW FrameXML global populated before any addon loads. It is available on all supported WoW versions (Classic Era, TBC, MoP, Retail). It contains exactly the class name strings that AQL uses as zone headers, so zone-text matching is guaranteed to be exact. No hardcoded translations and no maintenance burden.

**Why optional nil field rather than a sentinel value (e.g. 0)?**
AceSerializer omits nil table values entirely, keeping non-class quest payloads the same size as before. Receivers that do not recognise the field (older SQ versions) simply ignore it — fully backward compatible.

**Questie bridge players:** Out of scope. Bridge players do not run SQ and cannot transmit classID. Their class quests remain unresolved by this feature.

---

## Files Changed

| File | Change |
|---|---|
| `Core/WowAPI.lua` | Add `CLASS_TOKEN_BY_ID` table mapping classID → WoW class token string |
| `Core/Communications.lua` | Build `localizedClassNameToID` reverse lookup at file scope; add optional `classID` field to `buildInitPayload` and `buildQuestPayload` |
| `Core/GroupData.lua` | Preserve `classID` from payload in `OnInitReceived` and `OnUpdateReceived` |
| `UI/TabUtils.lua` | Add optional `classID` parameter to `GetZoneForQuestID`; resolve before AQL paths |
| `UI/Tabs/PartyTab.lua` | Pass `classID` from quest entry when calling `GetZoneForQuestID` |
| `UI/Tabs/SharedTab.lua` | Pass `classID` from quest entry when calling `GetZoneForQuestID` |

---

## Detailed Design

### `Core/WowAPI.lua` — CLASS_TOKEN_BY_ID

Add alongside the existing `CLASS_ID` table:

```lua
-- Maps WoW numeric class ID to the uppercase class token used as a key in
-- LOCALIZED_CLASS_NAMES_MALE and returned by UnitClass() as the second value.
-- Covers all classes across all WoW versions; entries for classes that do not
-- exist on the current version are simply absent from LOCALIZED_CLASS_NAMES_MALE.
SocialQuestWowAPI.CLASS_TOKEN_BY_ID = {
    [1]  = "WARRIOR",
    [2]  = "PALADIN",
    [3]  = "HUNTER",
    [4]  = "ROGUE",
    [5]  = "PRIEST",
    [6]  = "DEATHKNIGHT",
    [7]  = "SHAMAN",
    [8]  = "MAGE",
    [9]  = "WARLOCK",
    [10] = "MONK",
    [11] = "DRUID",
    [12] = "DEMONHUNTER",
    [13] = "EVOKER",
}
```

### `Core/Communications.lua` — detection and payload

At file scope, after the `local SQWowAPI = SocialQuestWowAPI` alias:

```lua
-- Reverse lookup: localized class name (as used by AQL zone headers) → WoW numeric classID.
-- Built at load time from LOCALIZED_CLASS_NAMES_MALE (always available before addon load).
-- Used by buildInitPayload and buildQuestPayload to detect class quests.
local localizedClassNameToID = {}
do
    local names = LOCALIZED_CLASS_NAMES_MALE
    if names then
        for classID, token in pairs(SQWowAPI.CLASS_TOKEN_BY_ID) do
            local name = names[token]
            if name then localizedClassNameToID[name] = classID end
        end
    end
end
```

In `buildQuestPayload`, add one field:

```lua
classID = localizedClassNameToID[questInfo.zone],  -- nil for non-class quests
```

In `buildInitPayload`, add the same field to each quest entry:

```lua
classID = localizedClassNameToID[info.zone],  -- nil for non-class quests
```

### `Core/GroupData.lua` — store classID on receipt

`OnInitReceived` already loops converting integer wire flags. `classID` is already numeric (or nil) so it requires no conversion — it is preserved automatically once the quest entry is stored from the wire payload. No code change needed beyond confirming the field passes through the existing storage block.

`OnUpdateReceived` explicitly constructs the stored quest entry. Add `classID`:

```lua
entry.quests[questID] = {
    questID      = questID,
    title        = ...,
    isComplete   = payload.isComplete == 1,
    isFailed     = payload.isFailed   == 1,
    classID      = payload.classID,        -- nil for non-class quests
    snapshotTime = payload.snapshotTime,
    timerSeconds = payload.timerSeconds,
    objectives   = storedObjs,
}
```

### `UI/TabUtils.lua` — GetZoneForQuestID

```lua
-- classID is optional. When provided (remote player's quest entry), it is used
-- to resolve the localized class name directly, bypassing AQL. This covers the
-- case where AQL's provider lookup returns a geographic zone instead of the
-- class-name zone header used by WoW's quest log.
function SocialQuestTabUtils.GetZoneForQuestID(questID, classID)
    if classID then
        local token = SQWowAPI.CLASS_TOKEN_BY_ID[classID]
        local name  = token and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
        if name then return name end
    end
    local AQL = SocialQuest.AQL
    local info = AQL:GetQuest(questID)
    if info and info.zone then return info.zone end
    local fullInfo = AQL:GetQuestInfo(questID)
    if fullInfo and fullInfo.zone then return fullInfo.zone end
    return L["Other Quests"]
end
```

### `UI/Tabs/PartyTab.lua` and `UI/Tabs/SharedTab.lua`

Both tabs call `GetZoneForQuestID(questID)` when building their zone/chain tree from `SocialQuestGroupData.PlayerQuests`. At each such call site, `playerData` (the current player's entry) and `questID` are both in scope. Pass `classID` from the quest entry:

```lua
local qentry   = playerData.quests[questID]
local classID  = qentry and qentry.classID
local zoneName = SocialQuestTabUtils.GetZoneForQuestID(questID, classID)
```

The implementer should grep for `GetZoneForQuestID` in each tab file to locate every call site — there may be more than one if the zone is resolved in multiple passes (e.g. the MoP alias post-processing pass in PartyTab).

For the local player's own quests (iterated via `AQL:GetAllQuests()`), `classID` is nil at the call site — the existing AQL fast path correctly returns the class-name zone header as it does today. No regression.

---

## Backward Compatibility

- Older SQ clients receiving payloads with `classID` ignore the unknown field — AceSerializer deserializes into a Lua table and extra keys cause no errors.
- Newer SQ clients receiving from older SQ clients see `classID = nil` in the quest entry and fall through to the existing AQL zone resolution — same behavior as today.
- No protocol version bump required.

---

## What This Does Not Fix

- **Questie bridge players** — they do not run SQ and cannot transmit classID. Their class quests continue to display under the geographic zone or "Other Quests" as today.
- **AQL provider data quality** — the root cause (provider returning geographic zone for class quests) is not addressed in AQL. This feature works around it for SQ-to-SQ communication only.
