# Outbound Chat Message Format Design

**Goal:** SocialQuest outbound chat messages mirror Questie's sentence structure while using WoW native hyperlinks instead of Questie's plain-text bracket format.

**Status:** Largely implemented. This document records the design decision and identifies a minor polish gap in test demo strings.

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
{rt1} SocialQuest: Quest Complete: [Quest Name]
{rt1} SocialQuest: Quest Completed: [Quest Name]
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

The `(regression)` suffix is a SocialQuest-specific addition — Questie has no equivalent since Questie only announces completed objectives, never partial progress or regression.

---

## Link Resolution

For both quest events and objective events, the quest link is resolved in priority order (first non-nil wins):

1. `questInfo.link` — live AQL cache snapshot passed with the event callback
2. `info.link` — AQL quest cache fallback lookup
3. Plain quest title string — last resort when no hyperlink is available

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

Partial objective progress (`objective_progress`) and regression (`objective_regression`) are **never suppressed** — Questie has no equivalent announce for these.

---

## Test Demo Strings

The test panel demo strings are hardcoded. Objective demos currently show `[A Daunting Task]` as plain unstyled text. A separate "Test Chat Link" button uses quest 337 to demonstrate a real WoW hyperlink. The remaining demo strings should be updated to render the quest name in gold (`|cFFFFD200[A Daunting Task]|r`) so the preview visually indicates a hyperlink would appear in the real message.

---

## Implementation State

| Component | Status |
|---|---|
| Quest event outbound (`OnQuestEvent`) | Done — uses `questInfo.link → info.link → title` |
| Objective outbound (`OnObjectiveEvent`) | Done — uses `questInfo.link → questInfo.title` |
| Locale template keys | Done — Questie-style `{rt1} SocialQuest: Quest Verb: %s` strings |
| Test demo objective strings | Gap — show plain `[A Daunting Task]`, should show gold-colored name |
