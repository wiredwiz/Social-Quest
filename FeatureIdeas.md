# SocialQuest — Feature Ideas

*Generated from codebase analysis and player questing friction points. March 2026.*

---

## Context: What SocialQuest already does well

The existing feature set covers the **reactive social layer** of questing thoroughly: it broadcasts every state change (accept, progress, finish, turn-in, abandon, fail), renders them as banners, annotates party tooltips, groups quests by zone and chain, surfaces who needs a share, tracks chain step relationships, handles the Questie user case, and syncs completed history.

---

## Player friction points while questing together

Before pitching features, it helps to think about the real friction in group questing:

**Coordination friction:** Players constantly make micro-decisions — "Should I grab this quest? Do you already have it? Can you share it? Are we on the same step?" SQ shows state passively; it doesn't help players act on it quickly.

**Visibility friction:** The objective fraction "3/8" communicates progress, but at a glance when scanning 4 party members it's cognitively expensive. Players want to know "who needs help" and "are we close" without reading every number.

**Planning friction:** Players want to know *before moving to a new zone* whether their party is aligned on quests there. SQ is entirely reactive — it shows what's happening, never what *could* happen.

**Chain momentum friction:** TBC has deep quest chains. A player finishing a chain step often triggers the next one immediately, and the party needs to know "Bob just unlocked step 3 — we can move now." That signal doesn't exist today.

**Group quest friction:** Group/elite quests require the whole party ready simultaneously. Players currently use verbal coordination. SQ could formalize this.

---

## Feature Ideas

---

### 1. ~~Progress bars in the group frame~~ (*DONE*)

**The gap:** The player row shows `Name: 3/8 Gnolls Slain` as text for every objective. When scanning 4 party members' objectives across several quests, this is readable but not *scannable*.

**The idea:** Replace or augment the objective text with a small inline progress bar — a thin colored strip filling proportional to `numFulfilled/numRequired`. Use existing completed/active colors. A completed bar turns green instantly. Render the objective text within the progress bar if possible
rather than taking up an extra line to display a progress bar along with the objective.  Keeping
the text readable is very important though, so the text should display over top of the progress fill
color and the text color should be chosen to contrast well so that it stays readable regardless.

**Implementation notes:** No new protocol. Pure rendering enhancement on top of existing data in `RowFactory.AddPlayerRow`. Immediately makes the window more useful as an at-a-glance dashboard.

---

### 2. "Almost done" highlighting on objectives

**The gap:** When a party member has 7/8 Gnolls, SQ treats that identically to 1/8. No visual urgency signal.

**The idea:** When `numFulfilled / numRequired >= 0.75` (configurable threshold), colorize that objective row differently — a warmer amber rather than the default active yellow. If *all* objectives are at ≥75%, the player's name row gets a subtle "almost done" indicator. Makes it trivial to see who needs a few more kills.

**Implementation notes:** Zero protocol changes. Pure rendering decision inside `RowFactory.AddPlayerRow`. Single threshold constant, optionally exposed in config.

---

### 3. Chain "what's next" notification

**The gap:** When a player turns in a chain quest, SQ announces "Bob turned in: [Lost in Battle]" — but the party has no idea what that unlocks. The next step may require regrouping elsewhere immediately.

**The idea:** When an `SQ_UPDATE` arrives with `eventType = "completed"` for a quest that AQL chain data shows has a next step, display an additional banner: `"Bob can now start [Chapter 2: The Fallen King] (Step 3)"`. Synthesized locally from AQL chain data — no protocol changes.

**Implementation notes:** AQL already carries chain info. Data to synthesize this message is available on the receiving end in `Announcements:OnRemoteQuestEvent`. Check `chainInfo.steps[chainInfo.step + 1]` for the next questID, resolve its title via `AQL:GetQuestInfo`.

---

### 4. Zone quest summary — "Before we go" view

**The gap:** When the party is about to move to a new zone, there's no way to see "what's waiting for us there?" SQ only shows quests players *currently have active*.

**The idea:** A "Zone Preview" panel or command (`/sq zone Hellfire Peninsula`) that scans all party members' active and completed quests for a zone and summarizes: how many quests each person has, which ones are shareable, who is missing which chain prerequisites. Synthesizes data from existing `PlayerQuests` tables plus AQL's local quest data.

**Implementation notes:** No new protocol. Requires a new UI panel or slash command output. Could also appear as a 4th tab in the group frame. Most ambitious idea here but highest pre-session value.

---

### 5. ~~Dungeon quest auto-filter~~ (*DONE*)

**The gap:** When entering an instance, the SQ window shows all quests from all zones. Players scroll past Nagrand quests to find the two Ramparts quests everyone has.

**The idea:** When `PLAYER_ENTERING_WORLD` fires inside an instance, automatically switch the Party tab to show only quests whose zone matches the current instance. A small "Instance: Hellfire Ramparts" label at the top makes the filter obvious. Filter drops on exit.

**Implementation notes:** Instance zone name available via `GetRealZoneText()` / AQL zone data. Filtering is a rendering change to `PartyTab:BuildTree` — skip entries where `zoneName ~= currentInstance`. No protocol changes.

---

### 6. One-click quest share button

**The gap:** The "Needs it Shared" row tells you a party member needs the quest, but you must manually open the quest log, find the quest, and right-click to share — 4-6 clicks across two windows.

**The idea:** When a quest row has any "Needs it Shared" players below it, show a small `[Share]` button next to the quest title (Mine tab only). Clicking calls `QuestLogPushQuest(logIndex)` directly. Blizzard's native sharing system handles party communication.

**Implementation notes:** `logIndex` and `isEligibleForShare` data already exist. The `[Share]` button is only rendered when `localHasIt == true` and at least one player row has `needsShare == true`. Add to `RowFactory.AddQuestRow` via a new `callbacks.onShare` field (same pattern as `onTitleShiftClick`).

---

### 7. Session quest statistics summary

**The gap:** At the end of a long session, players have no idea how much they accomplished together. "We did a lot of quests tonight" is vague.

**The idea:** Track a session-scoped counter: `{ accepted=N, completed=N, abandoned=N, failed=N }`. On `/sq stats`, display this alongside how many quests the party collectively completed. Example: *"This session: 12 quests completed · 1 abandoned · 0 failed · 4 chain quests finished"*.

**Implementation notes:** Counters increment in the existing AQL callback handlers (`OnQuestAccepted`, etc.) into a `SocialQuest.sessionStats` table. Reset on `OnSelfLeftGroup` or `/sq stats reset`. Display via `SocialQuest:Print` or a small popup. No protocol changes.

---

### 8. Objective countdown mode ("3 more kills")

**The gap:** "3/8 Gnolls Slain" is useful but passive. "5 more Gnolls" is more immediately actionable — it answers the question players actually ask during grinding.

**The idea:** Config option to display objective progress as remaining-count rather than fraction. For kill objectives: `numRequired - numFulfilled` remaining. For item collection or other types, keep the fraction. Label changes from "3/8 Gnolls Slain" to "5 more · Gnolls Slain".

**Implementation notes:** String formatting change in `RowFactory.AddPlayerRow` and `formatObjectiveBannerMsg` in `Announcements.lua`. Config toggle in the general settings panel. Detection of "kill" vs "collect" objective type requires AQL objective type field (verify availability).

---

### 9. Party zone divergence indicator

**The gap:** SQ knows everything about quests but nothing about where party members physically are. When half the party is in Thrallmar turning in quests and the other half is still killing, there's no signal in the SQ window.

**The idea:** Track each party member's current zone via a new `SQ_ZONE` broadcast on `PLAYER_ENTERING_WORLD`. The Party tab shows a small zone label next to each player's name, or a divergence badge when players are in different zones.

**Implementation notes:** New comm prefix `SQ_ZONE` with payload `{ zone = GetRealZoneText() }`. Stored as `currentZone` in each `PlayerQuests` entry. `PLAYER_ENTERING_WORLD` already hooks in `SocialQuest.lua` — broadcast fires after the zone transition suppression window so it doesn't race with quest callbacks. The 3-second suppression delay means the zone broadcast should be deferred similarly.

---

### ~~10. Group quest ready-check~~ (*No plans to implement*)

**The gap:** Group/elite quests ([Group] badge in SQ) require everyone physically present and ready. Coordinating this verbally in chat is clumsy.

**The idea:** Right-clicking a [Group] quest in the Mine or Party tab gives a "Ready Check" option. Broadcasts a ping to all party members: `"Thad wants to do [Wanted: Arazzius the Cruel] — are you ready?"`. Each recipient gets a banner with a [Yes]/[No] response. Responses show in SQ as a small status board next to the quest.

**Implementation notes:** New comm prefixes `SQ_READY_CHECK` (broadcast, payload: questID) and `SQ_READY_RESP` (whisper back to initiator, payload: questID + ready=true/false). Store responses in a module-level table keyed by questID. Display in `RowFactory.AddQuestRow` as colored player dots (green = ready, grey = pending, red = declined). Expires after 60 seconds or on group change.

### 11. Add a flyout settings panel for Quest Window

**The gap:** Players may wish to toggle a number of various quest window display settings
while they are questing, turning various filters on/off, changing display structure.  It
would be nice if this were easily accessible to change on the fly as desired without being
required to go into the main add-on config every time you want to adjust a small display behavior.

**The idea:** Create an options panel that appears off the right of the main quest window frame.
Ideally there is a gear icon configure toggle button on the main quest window panel that when clicked
causes an options panel to slide out to the right or collapse back into the main window.  This
options tab would provide a number of toggle options and filter range entry text boxes that a player
could use to restructure or filter the quest listings in the tabs. Some of the filter option ideas are:

 1. A toggle to only show quests worth xp to the group
 2. A min/max range entry text box set to filter quests within a given recommended level
 3. A quest level delta entry box that when specified, filters the list to quests with a level
     difference from the player of the delta value specified.
 4. An option to filter select party members out of the party tab.

### 12. ~~Add a search/filter bar to the top of every tab~~ (*DONE*)

**The gap:** Sometimes tabs can get rather spammy, especially the party tab.  It would be nice
if players could easily and quickly locate a quest they cared about without lots of scrolling and
searching.

**The idea:** Add a textbox input at the top of each tab (the filter label should be first if
it is present).  If the player begins typing in the textbox, filter the displayed quest listings
down to only quests where either the quest title or quest chain title contains the typed text.
The text would not need to persist after the window is gone.  Ideally it would be nice if the box
provided a little "x" button inside on the right edge that when clicked, would clear the text
(as many modern UI's do), but that is not necessary.

### 13. Do-Not-Disturb toggle

**The gap:** Sometimes a player wants to focus — during a difficult pull, a boss fight, or just a stretch of solo grinding — and SQ banner notifications become noise rather than signal. There is currently no way to silence them without diving into the config panel and disabling individual event toggles.

**The idea:** A Do-Not-Disturb toggle in the General section of `/sq config`. When enabled, all incoming SQ banner announcements are silently suppressed — no frames are shown, no sounds play. Chat announcements are unaffected (banners only). The toggle is a single checkbox, easy to flip on and off mid-session. No state persists beyond the session (DND resets to off on login/reload).

**Implementation notes:** Add a `doNotDisturb` boolean to the AceDB profile defaults (default `false`). In `Announcements.lua`, add an early-return guard at the top of the banner display path that checks `SocialQuest.db.profile.doNotDisturb` and returns without showing the frame if true. No changes to the communication layer — events are still received and processed; only the display is suppressed. Add the checkbox to `Options.lua` in the General group.

---

## Summary

| # | Feature | Complexity | Impact | Protocol change? |
|---|---------|-----------|--------|-----------------|
| 1 | ~~Progress bars~~ | — | — | *DONE* |
| 2 | Almost-done highlighting | Very low | Medium | No |
| 3 | Chain "what's next" notification | Low | High | No |
| 4 | Zone quest summary | Medium | High | No |
| 5 | ~~Dungeon quest auto-filter~~ | — | — | *DONE* |
| 6 | One-click share button | Low | High | No |
| 7 | Session stats | Low | Medium | No |
| 8 | Objective countdown mode | Very low | Medium | No |
| 9 | Party zone divergence | Medium | High | Yes (SQ_ZONE) |
| 10 | ~~Group quest ready-check~~ | — | — | No plans to implement |
| 11 | Flyout settings panel | Medium | Medium | No |
| 12 | ~~Search/filter bar~~ | — | — | *DONE* |
| 13 | Do-Not-Disturb toggle | Very low | Medium | No |

**Quick wins (start here):** #2 (almost-done highlight), #6 (one-click share), #3 (chain what's-next notification), #8 (objective countdown), #13 (do-not-disturb) — all low/very-low complexity, no protocol changes.

**High-value medium lifts:** #9 (zone divergence), #11 (flyout settings).

**Biggest feature:** #4 (zone quest summary) — most planning effort required but highest pre-session value for organized groups.
