# SocialQuest: Flight Path Discovery, Needs-Shared Eligibility, Quest Log Toggle — Design Spec

## Overview

Three independent improvements to SocialQuest (WoW TBC Anniversary, Interface 20505):

1. **Flight Path Discovery** — Detect when a party member discovers a new flight path and display a banner notification. Mirrors the follow-notification pattern for options structure; mirrors the quest-event pattern for communication.
2. **Needs-Shared Eligibility** — Suppress the "Needs it Shared" player row unless the quest is actually shareable, the player hasn't already completed it, and any chain prerequisite has been completed.
3. **Quest Log Toggle** — Left-clicking a quest title in the SQ window closes the quest log if it is already open and showing that quest, turning the click into a toggle.

---

## Feature 1: Flight Path Discovery

### Data and State

**Profile-scope settings** (shared across characters, added to `SocialQuest:GetDefaults()`):

```lua
flightPath = {
    enabled        = true,   -- broadcast my discoveries to party
    announceBanners = true,  -- display banners when party members discover paths
},
```

**Char-scope state** (per character, new `char` namespace in AceDB defaults):

```lua
char = {
    knownFlightNodes = {},  -- [nodeName] = true; persists across sessions
},
```

`SocialQuestDB` already stores the profile namespace. Add `char = { knownFlightNodes = {} }` as a **sibling of `profile`** at the top level of the table returned by `GetDefaults()` — not nested inside `profile`. AceDB activates per-character storage automatically when it sees the `char` key at the root of the defaults table.

The combined defaults structure must look like this:

```lua
return {
    profile = {
        -- ... existing profile keys ...
        flightPath = {
            enabled         = true,
            announceBanners = true,
        },
    },
    char = {
        knownFlightNodes = {},
    },
}
```

### Race Starting Node Table

Defined as a file-scope local in `SocialQuest.lua`. Keys are the second return value of `UnitRace("player")` (the English internal name). **All node name strings require in-game verification against `GetTaxiNodeInfo()` output** — the values below are best-effort and must be confirmed during implementation.

Pandaren, Dracthyr, and Earthen are faction-dependent and handled by the `getStartingNode()` helper below rather than a table entry.

```lua
local RACE_STARTING_NODES = {
    -- TBC (currently supported)
    ["Human"]              = "Stormwind",
    ["Dwarf"]              = "Ironforge",
    ["Gnome"]              = "Ironforge",
    ["NightElf"]           = "Rut'theran Village",
    ["Scourge"]            = "Undercity",           -- Undead
    ["Tauren"]             = "Thunder Bluff",
    ["Orc"]                = "Orgrimmar",
    ["Troll"]              = "Orgrimmar",
    ["Draenei"]            = "The Exodar",
    ["BloodElf"]           = "Silvermoon City",
    -- Cataclysm
    ["Worgen"]             = "Stormwind",
    ["Goblin"]             = "Orgrimmar",
    -- MoP allied races
    -- (Pandaren handled in getStartingNode — faction-dependent)
    -- BfA allied races
    ["VoidElf"]            = "Stormwind",
    ["LightforgedDraenei"] = "Stormwind",
    ["DarkIronDwarf"]      = "Ironforge",
    ["KulTiran"]           = "Boralus",
    ["Mechagnome"]         = "Mechagon",
    ["Nightborne"]         = "Orgrimmar",
    ["HighmountainTauren"] = "Thunder Bluff",
    ["MagharOrc"]          = "Orgrimmar",
    ["ZandalarTroll"]      = "Dazar'alor",
    ["Vulpera"]            = "Orgrimmar",
    -- Dragonflight / The War Within
    -- (Dracthyr and Earthen handled in getStartingNode — faction-dependent)
}

-- Returns the starting flight node name for the local player.
-- Handles faction-dependent races (Pandaren, Dracthyr, Earthen) inline.
-- Returns nil for unknown races; callers treat nil as "no seed available."
local function getStartingNode()
    local _, race = UnitRace("player")
    local node = RACE_STARTING_NODES[race]
    if node then return node end
    local faction = UnitFactionGroup("player")
    if race == "Pandaren" or race == "Dracthyr" or race == "Earthen" then
        return faction == "Alliance" and "Stormwind" or "Orgrimmar"
    end
    return nil
end
```

### Detection Logic

Register `TAXIMAP_OPENED` in `SocialQuest:OnEnable`. Handler: `SocialQuest:OnTaxiMapOpened`.

```lua
function SocialQuest:OnTaxiMapOpened()
    if not self.db.profile.flightPath.enabled then return end

    -- Collect all node names currently visible on the taxi map.
    -- GetTaxiNodeInfo(i) returns name, texture, x, y at Interface 20505.
    -- Iterate until nil is returned. Only named nodes are collected.
    -- NOTE: exact API behavior (active vs inactive nodes, max index) requires
    -- in-game verification during implementation.
    local currentNodes = {}
    local i = 1
    while true do
        local name = GetTaxiNodeInfo(i)
        if not name then break end
        currentNodes[name] = true
        i = i + 1
    end

    local saved = self.db.char.knownFlightNodes
    local diff  = {}
    for name in pairs(currentNodes) do
        if not saved[name] then
            table.insert(diff, name)
        end
    end

    local diffCount    = #diff
    local currentCount = 0
    for _ in pairs(currentNodes) do currentCount = currentCount + 1 end

    if diffCount == 0 then
        return  -- nothing new
    end

    local startNode = getStartingNode()

    if diffCount == 1 then
        -- Normal case: one new node. Announce unless it is the starting city.
        if diff[1] ~= startNode then
            SocialQuestComm:SendFlightDiscovery(diff[1])
        end
        -- else: first-ever open at starting city — silently absorb.

    elseif diffCount > 1 and currentCount == 2 then
        -- Special case: savedNodes was empty and player has exactly starting city
        -- + one new discovery. Announce the non-starting-city node only.
        -- If startNode is nil (unknown race), skip this branch entirely —
        -- we cannot identify which node is the starting city, so silently absorb.
        if startNode then
            for _, name in ipairs(diff) do
                if name ~= startNode then
                    SocialQuestComm:SendFlightDiscovery(name)
                    break
                end
            end
        end

    else
        -- diffCount > 1 and currentCount > 2: mid-game install or ambiguous.
        -- Silently absorb — cannot determine which node is genuinely new.
    end

    -- Always update saved state.
    for name in pairs(currentNodes) do
        saved[name] = true
    end
end
```

### Communication

Add `"SQ_FLIGHT"` to the `PREFIXES` table in `Communications.lua`.

```lua
-- Sends the local player's newly discovered flight path name to the party.
-- Only sent when in a party (not raid, not battleground).
function SocialQuestComm:SendFlightDiscovery(nodeName)
    if not IsInGroup() or IsInRaid() then return end
    -- Use LibStub("AceComm-3.0"):SendCommMessage — consistent with all other send
    -- helpers in Communications.lua (SocialQuestComm is a plain table, not an Ace3 mixin;
    -- Initialize() registers via LibStub("AceComm-3.0"):RegisterComm, not self:RegisterComm).
    LibStub("AceComm-3.0"):SendCommMessage("SQ_FLIGHT", serialize({ node = nodeName }), "PARTY")
end
```

In `OnCommReceived`, add after the existing prefix branches. **Do not call `Deserialize` here** — the function already deserializes `msg` into `payload` at lines 273–276 before any prefix dispatch. All branches use the pre-deserialized `payload`:

```lua
elseif prefix == "SQ_FLIGHT" then
    if payload and payload.node then
        SocialQuestAnnounce:OnFlightDiscovery(sender, payload.node)
    end
```

### Announcement

Add to `Announcements.lua`, near the follow notification handlers:

```lua
------------------------------------------------------------------------
-- Flight path discovery notifications
------------------------------------------------------------------------

function SocialQuestAnnounce:OnFlightDiscovery(sender, nodeName)
    local db = SocialQuest.db.profile
    if not db.flightPath.announceBanners then return end
    local msg = string.format(L["%s unlocked flight path: %s"], sender, nodeName)
    displayBanner(msg, "accepted")  -- reuses the quest-accepted green color
end
```

Add the locale string `"%s unlocked flight path: %s"` to all locale files.

### Options

Add a new group to `Options.lua` after the follow group. The `debug` group is currently at `order = 8` — change it to `order = 9` to make room, then insert `flightPath` at `order = 8`:

```lua
flightPath = {
    type  = "group",
    name  = L["Flight Path Discovery"],
    order = 8,
    args  = {
        enabled = toggle(L["Announce flight path discoveries"],
            L["Broadcast to your party when you discover a new flight path."],
            { "flightPath", "enabled" }, 1),
        announceBanners = toggle(L["Show banner for party discoveries"],
            L["Display a banner notification when a party member discovers a new flight path."],
            { "flightPath", "announceBanners" }, 2),
    },
},
```

The `profiles` entry (managed by AceDBOptions at `order = 99`) is unaffected.

### Files Touched

- `SocialQuest.lua` — event registration, `OnTaxiMapOpened` handler, `RACE_STARTING_NODES` table, `getStartingNode` helper, AceDB defaults (`profile.flightPath`, `char.knownFlightNodes`)
- `Core/Communications.lua` — `SQ_FLIGHT` prefix, `SendFlightDiscovery`, `OnCommReceived` branch
- `Core/Announcements.lua` — `OnFlightDiscovery` handler
- `UI/Options.lua` — "Flight Path Discovery" options group
- `Locales/*.lua` — new locale string

---

## Feature 2: "Needs Shared" Eligibility

### Problem

`buildPlayerRowsForQuest` in `PartyTab.lua` sets `needsShare = true` whenever the local player has a quest and a party member does not. This includes cases where the quest cannot actually be shared (non-shareable quest, already completed by that player, or chain prerequisite not met).

### Solution

Replace the bare `needsShare = true` with a call to a local helper `isEligibleForShare(questID, playerData)`.

```lua
-- Returns true only when the quest can actually be shared with this player:
--   1. The quest is marked shareable by the WoW API.
--   2. The player has not already completed the quest.
--   3. If the quest is a known chain step with a previous step, that step
--      has been completed by the player.
-- Falls back gracefully when chain info is unavailable (no Questie).
-- NOTE: AQL is a hard dependency — SocialQuest:OnInitialize disables the addon
-- if AQL is missing. The `if not AQL then return false end` guard is a safety
-- net only; it is unreachable in normal operation.
-- NOTE: GetQuestLogSelection() requires in-game verification at Interface 20505.
-- It is expected to exist (it is a standard Classic API), but must be confirmed.
-- If nil is returned, prevSel is nil and the restoration guard silently no-ops
-- (the quest log is left on the last-selected entry — acceptable trade-off).
local function isEligibleForShare(questID, playerData)
    local AQL = SocialQuest.AQL
    if not AQL then return false end

    -- Check 1: quest is shareable via WoW API.
    -- Requires selecting the quest log entry first; selection is restored after.
    -- Guard against stale logIndex: confirm the selected entry is actually this
    -- quest before calling GetQuestLogPushable (the log may have shifted since
    -- the last AQL update).
    local qi = AQL:GetQuest(questID)
    if not qi or not qi.logIndex then return false end
    local prevSel = GetQuestLogSelection()
    SelectQuestLogEntry(qi.logIndex)
    local _, _, _, _, _, _, _, confirmID = GetQuestLogTitle(qi.logIndex)
    if confirmID ~= questID then
        if prevSel and prevSel > 0 then SelectQuestLogEntry(prevSel) end
        return false
    end
    local shareable = GetQuestLogPushable() and true or false
    if prevSel and prevSel > 0 then
        SelectQuestLogEntry(prevSel)
    end
    if not shareable then return false end

    -- Check 2: player has not already completed this quest.
    if playerData.completedQuests and playerData.completedQuests[questID] then
        return false
    end

    -- Check 3: chain prerequisite met (requires Questie/chain info).
    local ci = AQL:GetChainInfo(questID)
    if ci and ci.knownStatus == AQL.ChainStatus.Known and ci.step and ci.step > 1 then
        -- Find the previous step's questID from the chain.
        local prevStep = ci.steps and ci.steps[ci.step - 1]
        if prevStep and prevStep.questID then
            if not (playerData.completedQuests and
                    playerData.completedQuests[prevStep.questID]) then
                return false
            end
        end
    end

    return true
end
```

In `buildPlayerRowsForQuest`, replace:

```lua
needsShare = true,
```

with:

```lua
needsShare = isEligibleForShare(questID, playerData),
```

### Files Touched

- `UI/Tabs/PartyTab.lua` — `isEligibleForShare` local helper, updated `needsShare` assignment

---

## Feature 3: Quest Log Toggle

### Problem

Left-clicking a quest title in the SQ window always opens the quest log and selects that quest. Clicking the same title again has no effect. The user expects it to act as a toggle.

### Solution

Add a guard at the top of `openQuestLogToQuest` in `RowFactory.lua`:

```lua
local function openQuestLogToQuest(questID)
    -- Toggle: if the quest log is already open and this quest is currently
    -- selected, close the log instead of re-opening it.
    -- NOTE: GetQuestLogSelection() requires in-game verification at Interface 20505.
    -- If it is absent or returns nil, sel is nil, the guard silently skips the
    -- toggle, and the function falls through to the existing open-and-select
    -- logic — safe graceful degradation to the pre-toggle behaviour.
    if QuestLogFrame:IsShown() then
        local sel = GetQuestLogSelection()
        if sel and sel > 0 then
            local _, _, _, _, _, _, _, selID = GetQuestLogTitle(sel)
            if selID == questID then
                HideUIPanel(QuestLogFrame)
                return
            end
        end
    end

    -- Existing logic: open log and select the quest.
    ShowUIPanel(QuestLogFrame)
    ...
end
```

No new state, no new functions. The existing open-and-select logic below the guard is unchanged.

### Files Touched

- `UI/RowFactory.lua` — four-line guard added at the top of `openQuestLogToQuest`

---

## Key Behaviors and Constraints

- **Flight path detection is party-only.** `SendFlightDiscovery` returns early if not in a party or if in a raid. No broadcast in raids or battlegrounds.
- **First-run handling.** `char.knownFlightNodes` starts empty. The detection logic handles all first-use scenarios via the diff and count checks; no pre-seeding at login is needed.
- **Race table is best-effort.** All `RACE_STARTING_NODES` string values must be verified in-game against `GetTaxiNodeInfo()` output at Interface 20505. Names for post-TBC races will not be exercised in the current target but are present for future expansion.
- **Eligibility check is best-effort.** Chain prerequisite detection requires Questie (for `chainInfo`). Without it, only checks 1 and 2 apply. `playerData.completedQuests` is available only for players with SocialQuest installed (`hasSocialQuest = true`); for non-SQ players the check falls back to `false` for check 2 (completed unknown → assume not completed → still potentially eligible).
- **Quest log toggle only applies to the local player's own quests.** `openQuestLogToQuest` is only called when `questEntry.logIndex` is non-nil (the local player has the quest). Party/Shared tab rows for remote players without a `logIndex` do not call this function.
- **`SelectQuestLogEntry` side effect.** The eligibility check temporarily selects a quest log entry to call `GetQuestLogPushable()`, then restores the prior selection. This is safe when called during a PartyTab rebuild (frame refresh), which does not happen while the user is actively interacting with the quest log UI.
- **Sender display name.** `sender` from AceComm is the raw `"Name-Realm"` string. This is the established pattern in `Announcements.lua` — all existing banner and follow handlers use the raw sender string without realm-stripping. The flight path banner follows the same convention.
- **Version bump required.** Per CLAUDE.md versioning rules, `SocialQuest.toc` and `CLAUDE.md` must be updated after implementation: increment the minor version and reset the revision to 0 (new functionality on a new day). Update the Version History section in `CLAUDE.md` with a summary of all three features.

---

## Out of Scope

- Persisting flight path discovery state across characters (char-scope is per character by design)
- Broadcasting flight path discoveries to raid or battleground
- Displaying discovered flight paths anywhere in the SQ quest window
- Eligibility checks for non-SQ party members beyond what `completedQuests` already provides
