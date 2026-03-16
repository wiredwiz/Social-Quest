# Quest Chain Step Annotation — Design Spec

## Overview

For quest accepted, completed (turned in), failed, and abandoned events, when the quest
is part of a known chain (per Questie or QuestWeaver), append `(Step N)` to the message.
Applies to outbound chat messages, own-player banners, and remote-player banners.
When no chain provider is installed or the quest is not part of a chain, nothing is
appended — graceful degradation, no "(Step nil)" ever appears.

---

## Excluded event: `finished`

`finished` = quest objectives are all complete but the quest has not yet been turned in
(the quest is still in the log, `isComplete == true`). This event is intentionally
excluded from step annotation. Only accepted, completed, failed, and abandoned are in
scope.

---

## Data Flow

### Local events (accepted / completed / failed / abandoned)

AQL callbacks pass a `questInfo` snapshot to `SocialQuest.lua` handlers. That snapshot
is built by `QuestCache:_buildEntry`, which calls `provider.GetChainInfo(provider,
questID)` directly — the same Questie / QuestWeaver provider used by the three-tier
`AQL:GetQuestInfo`. The snapshot's `chainInfo` field is therefore provider-sourced and
does not share the live-cache-only limitation of `AQL:GetChainInfo`. A player accepting
a chain quest will have `chainInfo` correctly populated in the snapshot even if the quest
was not previously in the live cache.

The four relevant callbacks in `SocialQuest.lua` are changed to forward `questInfo` as a
third argument to `SocialQuestAnnounce:OnQuestEvent`.

`OnQuestEvent` extracts `chainInfo = questInfo and questInfo.chainInfo` and passes it as
a third argument to `OnOwnQuestEvent`.

`OnQuestEvent` has five call sites in the current codebase, all in `SocialQuest.lua`:
`OnQuestAccepted`, `OnQuestCompleted`, `OnQuestFailed`, `OnQuestAbandoned`, and
`OnQuestFinished`. Four of these are updated to pass `questInfo`. `OnQuestFinished` is
intentionally left unchanged — it is excluded from step annotation (see "Excluded
event" section). The test panel calls `SocialQuestAnnounce:TestEvent` directly (which
calls `displayBanner`), not `OnQuestEvent`, so the test panel is unaffected by the
signature change.

### Remote events

Only `questID` arrives over the network. Chain info is never transmitted — GroupData
stores only numeric values and resolves titles locally. Since Questie and QuestWeaver are
static databases covering all quests, the local client can look up chain info for any
questID (including quests the local player has never taken) via `AQL:GetQuestInfo(questID)`,
which falls through to the provider at Tier 3.

`AQL:GetQuestInfo` returns an object with both `.title` and `.chainInfo`. In
`OnRemoteQuestEvent`, the existing `AQL:GetQuest(questID)` call (cache-only) is
**replaced** by a single `AQL:GetQuestInfo(questID)` call (three-tier), which supplies
both the title and the chainInfo in one lookup. The existing `AQL:GetQuestTitle(questID)`
fallback tier is also removed — it is not a regression because `AQL:GetQuestTitle`
internally delegates to `AQL:GetQuestInfo` anyway; it adds no new title-resolution
capability beyond what the single `GetQuestInfo` call already performs.

---

## Message Format

### New locale key

```lua
L["(Step %s)"]
```

Single key, using `%s` (not `%d`) to match the existing AQL locale convention
(`L[" (Step %s of %s)"]` already uses `%s` for step numbers). In Lua 5.1, `%s`
coerces integers to strings, so `string.format("(Step %s)", 3)` produces `"(Step 3)"`.

Non-English locales translate it; translators reorder words as their language requires.

### Helper function

```lua
local CHAIN_STEP_EVENTS = {
    accepted  = true,
    completed = true,
    failed    = true,
    abandoned = true,
}

local function appendChainStep(msg, eventType, chainInfo)
    if not CHAIN_STEP_EVENTS[eventType] then return msg end
    if not chainInfo or chainInfo.knownStatus ~= "known" or not chainInfo.step then
        return msg
    end
    return msg .. " " .. string.format(L["(Step %s)"], chainInfo.step)
end
```

`appendChainStep` is called after the existing `formatOutboundQuestMsg` /
`formatQuestBannerMsg` calls. It never mutates the message when conditions aren't met.

### Output examples

| Context | Example output |
|---------|---------------|
| Outbound chat (accepted) | `Quest accepted: Omer's Revenge (Step 3)` |
| Outbound chat (completed) | `Quest turned in: Omer's Revenge (Step 2)` |
| Own banner | `You accepted: Omer's Revenge (Step 3)` |
| Remote banner | `PlayerName completed: Omer's Revenge (Step 2)` |
| No provider / not a chain | `Quest accepted: Omer's Revenge` (unchanged) |

Note: the outbound chat template for the `completed` event type is
`L["Quest turned in: %s"]` — so the message reads "Quest turned in:" even though the
internal event name is `"completed"`.

---

## Signature Changes

### `SocialQuest.lua`

Four callbacks pass `questInfo` to `OnQuestEvent`:

```lua
function SocialQuest:OnQuestAccepted(event, questInfo)
    SocialQuestAnnounce:OnQuestEvent("accepted", questInfo.questID, questInfo)
    SocialQuestComm:BroadcastQuestUpdate(questInfo, "accepted")
end
-- identical change for OnQuestCompleted, OnQuestFailed, OnQuestAbandoned
```

`OnQuestFinished` is unchanged (see "Excluded event" section above).

### `Core/Announcements.lua`

```lua
-- Before
function SocialQuestAnnounce:OnQuestEvent(eventType, questID)
-- After
function SocialQuestAnnounce:OnQuestEvent(eventType, questID, questInfo)
```

Inside `OnQuestEvent`:
- Extract `local chainInfo = questInfo and questInfo.chainInfo`
- Apply `appendChainStep(msg, eventType, chainInfo)` to the outbound chat message (after `formatOutboundQuestMsg`)
- Pass `chainInfo` to `OnOwnQuestEvent` as a third argument

```lua
-- Before
function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle)
-- After
function SocialQuestAnnounce:OnOwnQuestEvent(eventType, questTitle, chainInfo)
```

Inside `OnOwnQuestEvent`:
- Apply `appendChainStep(msg, eventType, chainInfo)` to the banner message before `displayBanner`

Inside `OnRemoteQuestEvent`, replace the existing `AQL:GetQuest(questID)` and
`AQL:GetQuestTitle(questID)` title lookups with a single `AQL:GetQuestInfo(questID)`
call that provides both title and chainInfo. The `checkAllCompleted(questID, false)`
call that exists in the current implementation must be preserved unchanged — it is not
shown in the snippet below but must remain in place before the AQL lookups.

```lua
-- (checkAllCompleted call preserved here — not shown, not changed)

local AQL   = SocialQuest.AQL
local info  = AQL and AQL:GetQuestInfo(questID)
local title = cachedTitle
           or (info and info.title)
           or ("Quest " .. questID)
local chainInfo = info and info.chainInfo

local msg = formatQuestBannerMsg(sender, eventType, title)
if msg then
    msg = appendChainStep(msg, eventType, chainInfo)
    displayBanner(msg, eventType)
end
```

---

## TEST_DEMOS Update

The hardcoded demo strings in `TEST_DEMOS` for accepted, completed, failed, and
abandoned are updated to append `" (Step 2)"`. These strings are unconditional
design-preview strings — they always show the fully annotated form regardless of whether
a provider is installed, because the test panel exists to demonstrate what the feature
looks like when active, not to simulate the no-provider fallback path.

```lua
accepted = {
    outbound = "Quest accepted: A Daunting Task (Step 2)",
    banner   = "TestPlayer accepted: [A Daunting Task] (Step 2)",
    ...
},
completed = {
    outbound = "Quest turned in: A Daunting Task (Step 2)",
    banner   = "TestPlayer completed: [A Daunting Task] (Step 2)",
    ...
},
failed = {
    outbound = "Quest failed: A Daunting Task (Step 2)",
    banner   = "TestPlayer failed: [A Daunting Task] (Step 2)",
    ...
},
abandoned = {
    outbound = "Quest abandoned: A Daunting Task (Step 2)",
    banner   = "TestPlayer abandoned: [A Daunting Task] (Step 2)",
    ...
},
```

---

## Locale Changes

**`Locales/enUS.lua`** — add one key:
```lua
L["(Step %s)"] = true
```

**All 11 non-English locale files** — add the translated equivalent:

| File | Example value |
|------|--------------|
| `Locales/deDE.lua` | `L["(Step %s)"] = "(Schritt %s)"` |
| `Locales/esES.lua` | `L["(Step %s)"] = "(Paso %s)"` |
| `Locales/esMX.lua` | `L["(Step %s)"] = "(Paso %s)"` |
| `Locales/frFR.lua` | `L["(Step %s)"] = "(Étape %s)"` |
| `Locales/itIT.lua` | `L["(Step %s)"] = "(Passo %s)"` |
| `Locales/jaJP.lua` | `L["(Step %s)"] = "(ステップ %s)"` |
| `Locales/koKR.lua` | `L["(Step %s)"] = "(단계 %s)"` |
| `Locales/ptBR.lua` | `L["(Step %s)"] = "(Passo %s)"` |
| `Locales/ruRU.lua` | `L["(Step %s)"] = "(Шаг %s)"` |
| `Locales/zhCN.lua` | `L["(Step %s)"] = "(步骤 %s)"` |
| `Locales/zhTW.lua` | `L["(Step %s)"] = "(步驟 %s)"` |

---

## Files Changed

| File | Change |
|------|--------|
| `SocialQuest.lua` | Pass `questInfo` to `OnQuestEvent` in 4 callbacks |
| `Core/Announcements.lua` | Add `CHAIN_STEP_EVENTS`, `appendChainStep`; update `OnQuestEvent`, `OnOwnQuestEvent`, `OnRemoteQuestEvent`; update `TEST_DEMOS` |
| `Locales/enUS.lua` | Add `L["(Step %d)"] = true` |
| `Locales/deDE.lua` through `Locales/zhTW.lua` (11 files) | Add translated `L["(Step %d)"]` key |

No changes to `GroupData.lua`, `Communications.lua`, or any UI files.

---

## Testing

1. Accept a quest that is part of a known chain (Questie or QuestWeaver installed).
2. Confirm outbound chat shows `"Quest accepted: <title> (Step N)"`.
3. With `displayOwn` enabled, confirm own banner shows `"You accepted: <title> (Step N)"`.
4. Turn in the quest (`completed` event); confirm outbound chat shows
   `"Quest turned in: <title> (Step N)"` and own banner shows
   `"You completed: <title> (Step N)"`.
5. Accept the follow-up quest; confirm step increments correctly.
6. Accept a standalone (non-chain) quest; confirm no `(Step N)` appears.
7. With no Questie/QuestWeaver installed (NullProvider), confirm no `(Step N)` appears
   on any event.
8. In a group with another SQ user, confirm remote banners show `(Step N)` for chain
   quests.
9. For a chain quest the local player has never taken (remote player only), confirm step
   still resolves correctly from the provider DB.
10. Abandon a chain quest; confirm outbound chat and own banner show `(Step N)`.
11. Fail a chain quest (escort timeout or forced failure); confirm `(Step N)` appears.
