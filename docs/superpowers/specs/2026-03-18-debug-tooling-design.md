# Debug Tooling Design

**Goal:** Add a Force Resync button to the debug options page and comprehensive debug logging across all SocialQuest subsystems.

---

## Feature 1: Force Resync Button

### Purpose

A button on the debug options page that, when clicked, requests a fresh quest snapshot from all current group members. Useful when group data appears stale without rejoining the group.

### Behavior

On click, `SocialQuestComm:SendResyncRequest()` is called. It determines the active channel and broadcasts `SQ_REQUEST` to that channel. Every group member whose SocialQuestComm receives it will respond with an `SQ_INIT` whisper containing their full quest snapshot — reusing the existing request/response protocol without any new message types.

| Group type | Channel | Notes |
|---|---|---|
| Party (≤5) | PARTY | At most 4 responses. Safe. |
| Raid | RAID | Up to 39 responses, each a whisper. |
| Battleground | INSTANCE_CHAT | Same as raid. |
| Not in group | — | Silent no-op. |

Respects `db.<section>.transmit`: if transmission is disabled for the current group type, the button does nothing.

### Button Cooldown

The button is disabled for 30 seconds after each click. Implemented via a module-level timestamp in `UI/Options.lua`; the button's `disabled` function returns true while `GetTime() - lastResyncTime < 30`. No countdown display — the button grays out and re-enables automatically.

The button lives inside the existing Debug options group, so it is only visible when `db.debug.enabled` is true.

---

## Feature 1 Security: SQ_REQUEST Handler Mitigations

The existing `SQ_REQUEST` handler responds to any sender, including players outside the current group who send a crafted whisper. This creates a potential amplification attack: many malicious players simultaneously sending `SQ_REQUEST` could cause the victim's addon to attempt sending many `SQ_INIT` whispers, potentially triggering Blizzard's rate limiter or bot-detection system.

Two guards are added to the `SQ_REQUEST` handler in `Core/Comm.lua`:

### Guard 1 — Sender group membership check

Before responding to any `SQ_REQUEST`, verify the sender is in the current group:

```lua
if not (UnitInParty(sender) or UnitInRaid(sender)) then return end
```

WoW already implicitly validates PARTY/RAID/INSTANCE_CHAT broadcasts (only group members receive them). This guard covers the whisper distribution path where external players could otherwise trigger a response. Requests from non-group-members are silently dropped.

### Guard 2 — Per-sender 15-second response cooldown

A `lastInitSent` table (keyed by sender name) tracks when the last `SQ_INIT` was sent to each player. If `GetTime() - lastInitSent[sender] < 15`, the request is dropped.

```lua
if lastInitSent[sender] and (GetTime() - lastInitSent[sender] < 15) then return end
lastInitSent[sender] = GetTime()
```

This caps the damage from rapid repeated requests from any single sender, even if they are in the group.

### Cooldown reset on group change

The `lastInitSent` table is cleared entirely whenever `OnGroupChanged` fires. This prevents the cooldown from blocking legitimate init exchanges when a player leaves and rejoins the group within 15 seconds. During stable group membership, the cooldown still applies.

**Important:** The 15-second cooldown applies only to `SQ_INIT` responses triggered by `SQ_REQUEST`. It does not affect `SQ_UPDATE` broadcasts (individual quest event changes), which go through a completely separate code path and are never throttled by this mechanism.

---

## Feature 2: Debug Logging

### Debug Helper

A single `SocialQuest:Debug(tag, msg)` method added to `SocialQuest.lua`:

```lua
function SocialQuest:Debug(tag, msg)
    if not self.db.profile.debug.enabled then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD200[SQ][" .. tag .. "]|r " .. tostring(msg))
end
```

Gold `[SQ][Tag]` prefix, white message body. Called from any file as `SocialQuest:Debug("Comm", "...")`. Gated on the existing `db.debug.enabled` flag — no new settings required.

### Coverage by Subsystem

#### `[SQ][Comm]` — `Core/Comm.lua`

| Event | Message |
|---|---|
| `SQ_INIT` sent | `"Sent SQ_INIT to <channel> (<N> quests)"` |
| `SQ_INIT` received | `"Received SQ_INIT from <sender> (<N> quests)"` |
| `SQ_UPDATE` sent | `"Sent SQ_UPDATE: <eventType> questID=<N>"` |
| `SQ_UPDATE` received | `"Received SQ_UPDATE from <sender>: <eventType> questID=<N>"` |
| `SQ_BEACON` sent | `"Sent SQ_BEACON to <channel>"` |
| `SQ_BEACON` received | `"Received SQ_BEACON from <sender>"` |
| `SQ_REQUEST` sent | `"Sent SQ_REQUEST to <channel>"` |
| `SQ_REQUEST` received + accepted | `"Received SQ_REQUEST from <sender> — responding"` |
| `SQ_REQUEST` dropped (not in group) | `"Received SQ_REQUEST from <sender> — dropped (not in group)"` |
| `SQ_REQUEST` dropped (cooldown) | `"Received SQ_REQUEST from <sender> — dropped (cooldown)"` |
| `SQ_REQ_COMPLETED` sent | `"Sent SQ_REQ_COMPLETED to <channel>"` |
| `SQ_REQ_COMPLETED` received | `"Received SQ_REQ_COMPLETED from <sender>"` |
| `SQ_RESP_COMPLETE` sent | `"Sent SQ_RESP_COMPLETE to <sender> (<N> completed quests)"` |
| `SQ_RESP_COMPLETE` received | `"Received SQ_RESP_COMPLETE from <sender> (<N> completed quests)"` |

#### `[SQ][Quest]` — `SocialQuest.lua`

| Event | Message |
|---|---|
| Quest event fired | `"Quest <eventType>: [<title>] (id=<N>)"` |
| Objective progress | `"Objective <N>/<N>: <text> for [<title>]"` |
| Objective regression | `"Objective regression <N>/<N>: <text> for [<title>]"` |

#### `[SQ][Group]` — `Core/GroupData.lua`

| Event | Message |
|---|---|
| Player added to roster | `"Added <name> to tracked roster"` |
| Player removed from roster | `"Removed <name> from tracked roster"` |
| SQ_INIT processed | `"Stored init data for <name> (<N> quests)"` |

#### `[SQ][Banner]` — `Core/Announcements.lua`

| Event | Message |
|---|---|
| Banner displayed | `"Banner: <eventType> from <sender> — <quest title>"` |
| Banner suppressed | `"Banner suppressed: <reason>"` |
| Outbound chat sent | `"Chat [<channel>]: <abbreviated message>"` |
| Outbound chat suppressed | `"Chat suppressed: Questie will announce <eventType>"` |

#### `[SQ][Resync]` — `Core/Comm.lua`

| Event | Message |
|---|---|
| Resync triggered | `"Resync: broadcasting SQ_REQUEST to <channel>"` |
| Not in group | `"Resync: not in group, no-op"` |

---

## Files Changed

| File | Changes |
|---|---|
| `SocialQuest.lua` | Add `SocialQuest:Debug(tag, msg)` helper; add `[SQ][Quest]` calls in quest event handlers |
| `Core/Comm.lua` | Add `SendResyncRequest()`; add Guard 1 + Guard 2 to `SQ_REQUEST` handler; clear `lastInitSent` on `OnGroupChanged`; add `[SQ][Comm]` and `[SQ][Resync]` debug calls |
| `Core/GroupData.lua` | Add `[SQ][Group]` debug calls |
| `Core/Announcements.lua` | Add `[SQ][Banner]` debug calls |
| `UI/Options.lua` | Add "Force Resync" execute button to debug section with 30-second cooldown |

**No new files. No new message types. No new settings.**
