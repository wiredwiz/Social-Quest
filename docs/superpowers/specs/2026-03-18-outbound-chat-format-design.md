# Outbound Chat Message Format Design

**Goal:** SocialQuest outbound chat messages mirror Questie's sentence structure while using WoW native hyperlinks instead of Questie's plain-text bracket format.

**Status:** Largely implemented. This document records the design decision and identifies a polish gap in test demo strings.

---

## Background

Questie formats its channel announcements as:

```
{rt1} Questie: Quest Accepted: [[60] Quest Name (questId)]
{rt1} Questie: 3/8 Kobolds Slain for [[60] Quest Name (questId)]!
```

The bracket format `[[level] name (questId)]` is plain text — not clickable, not a WoW hyperlink. It includes the quest level and quest ID inline.

SocialQuest adopts the same **sentence structure** but uses **WoW native hyperlinks** instead of the bracket format, so recipients can hover/click the quest name to see the full quest tooltip without any addon installed.

---

## Format Specification

### Quest Event Messages

Sent to PARTY, RAID, GUILD, BATTLEGROUND, and WHISPER channels (subject to per-channel transmit toggles and Questie suppression).

```
{rt1} SocialQuest: Quest Accepted: [Quest Name]
{rt1} SocialQuest: Quest Abandoned: [Quest Name]
{rt1} SocialQuest: Quest Complete: [Quest Name]      ← "finished" internal event (objectives done, not yet turned in)
{rt1} SocialQuest: Quest Completed: [Quest Name]     ← "completed" internal event (turned in)
{rt1} SocialQuest: Quest Failed: [Quest Name]
```

`[Quest Name]` is a WoW native hyperlink: `|cFFFFD200|Hquest:id:level|h[name]|h|r`. Gold, clickable, shows the standard WoW quest tooltip on hover. No addon required for recipients to interact with it.

Chain quests append a step annotation after the link:

```
{rt1} SocialQuest: Quest Accepted: [Quest Name] (Step 2)
```

### Objective Event Messages

Sent to PARTY, BATTLEGROUND, and WHISPER channels only (never RAID or GUILD).

```
{rt1} SocialQuest: 3/8 Kobolds Slain for [Quest Name]!
{rt1} SocialQuest: 2/8 Kobolds Slain (regression) for [Quest Name]!
```

Both lines come from the same `OnObjectiveEvent` handler. Regression is not a separate event type — it is signalled by the `isRegression` boolean parameter passed to the handler. The `(regression)` suffix is a SocialQuest-specific addition; Questie has no equivalent since it only announces completed objectives, never partial progress or regression.

---

## Link Resolution

### Quest events (`OnQuestEvent`)

Three-step fallback chain (first non-nil wins):

1. `questInfo.link` — snapshot passed with the AQL event callback
2. `info.link` — live AQL quest cache lookup (primary fallback for the `finished` event, where `questInfo` is nil)
3. Plain quest title string — last resort

### Objective events (`OnObjectiveEvent`)

Two-step fallback chain:

1. `questInfo.link` — live AQL cache object passed with the callback
2. `questInfo.title` — plain title from the same object

The shorter chain is intentional: `OnObjectiveEvent` only fires while a quest is active in the player's log, so a live `questInfo` object is always available. The `info.link` intermediate fallback used in `OnQuestEvent` is not needed here.

AQL builds hyperlinks as `|cFFFFD200|Hquest:questID:level|h[title]|h|r`.

---

## Scope

**In scope:** Outbound chat messages only — what SocialQuest sends to party/raid/guild/battleground channels and whispers.

**Out of scope:**
- Inbound banners (on-screen notifications from party member events) — different format, not changing
- Own-quest banners (on-screen notifications for your own events) — not changing
- Chat filter / icon swap — SocialQuest does not replace `{rt1} SocialQuest:` with a texture icon. This could be added as a separate future feature.

---

## Suppression Behavior

When Questie is installed and its announce flag is enabled for the same event type, SocialQuest suppresses its outbound chat message to avoid duplicates. Suppression applies to: `accepted`, `abandoned`, `completed`, `objective_complete`.

Objective progress and regression are **never suppressed**. These are not discrete event types — both are delivered via the same `objective_progress` event type with an `isRegression` boolean. Because Questie has no equivalent announce for partial progress or regression, this event type is intentionally absent from the suppression map.

---

## Test Demo Strings

The test panel uses hardcoded demo strings to preview message formats. Two categories:

**`outbound` strings** — shown as local chat previews via `displayChatPreview`. These represent what would be sent to the channel. Currently, the quest name is hardcoded as plain `[A Daunting Task]` in all demo entries. It should be rendered in gold (`|cFFFFD200[A Daunting Task]|r`) so the preview visually indicates a hyperlink would appear in a real message.

**`banner` strings** — shown on-screen via `RaidNotice_AddMessage`. These intentionally use plain unstyled text because `RaidNotice_AddMessage` cannot render WoW color codes or hyperlinks. No change needed for banner strings.

A dedicated "Test Chat Link" button (quest 337) already demonstrates a real WoW hyperlink in a turned-in message. The remaining `outbound` demo strings (all event types) should receive the gold styling treatment.

---

## Implementation State

| Component | Status |
|---|---|
| Quest event outbound (`OnQuestEvent`) | Done — uses `questInfo.link → info.link → title` |
| Objective outbound (`OnObjectiveEvent`) | Done — uses `questInfo.link → questInfo.title` (two-step, intentional) |
| Locale template keys | Done — Questie-style `{rt1} SocialQuest: Quest Verb: %s` strings |
| Test demo `outbound` strings | Gap — show plain `[A Daunting Task]`, should show `\|cFFFFD200[A Daunting Task]\|r` |
| Test demo `banner` strings | Done — plain text intentional (RaidNotice cannot render color codes) |
