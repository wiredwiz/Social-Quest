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

### 6. ~~One-click quest share button~~ (*DONE*)

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

### ~~13. Do-Not-Disturb toggle~~ (*DONE*)

**The gap:** Sometimes a player wants to focus — during a difficult pull, a boss fight, or just a stretch of solo grinding — and SQ banner notifications become noise rather than signal. There is currently no way to silence them without diving into the config panel and disabling individual event toggles.

**The idea:** A Do-Not-Disturb toggle in the General section of `/sq config`. When enabled, all incoming SQ banner announcements are silently suppressed — no frames are shown, no sounds play. Chat announcements are unaffected (banners only). The toggle is a single checkbox, easy to flip on and off mid-session. No state persists beyond the session (DND resets to off on login/reload).

**Implementation notes:** Add a `doNotDisturb` boolean to the AceDB profile defaults (default `false`). In `Announcements.lua`, add an early-return guard at the top of the banner display path that checks `SocialQuest.db.profile.doNotDisturb` and returns without showing the frame if true. No changes to the communication layer — events are still received and processed; only the display is suppressed. Add the checkbox to `Options.lua` in the General group.

---

### 14. ~~Quest log hover tooltip enhancement~~ (*DONE*)

**The gap:** Hovering a quest link in chat already shows group progress via `ItemRefTooltip` (the existing `Tooltips.lua` hook). But hovering a quest entry directly in the quest log does nothing — the player must open the SQ window and find the quest there to see who has it and where they stand.

**The idea:** Hook `GameTooltip:SetQuestLogItem` (or the equivalent quest-log tooltip entry point in TBC) so that when the player mouses over a quest title in the quest log, the same "Group Progress" block appended by the chat-link tooltip appears: a header line, then one `AddDoubleLine` row per party member who has the quest, showing their objective fractions or completion state. Reuses `addGroupProgressToTooltip` from `Tooltips.lua` — no duplication of display logic.

**Implementation notes:** In TBC the quest log tooltip is populated by the default UI calling `GameTooltip:SetQuestLogItem(index)` (via `QuestLog_UpdateQuestDetails` and related functions). Hook `hooksecurefunc(GameTooltip, "SetQuestLogItem", ...)` in `Tooltips.lua:Initialize`. Extract the questID from `AQL:GetQuestLogIndex` reverse lookup or from `GetQuestLogTitle(index)` → `AQL:FindQuestByTitle`. The cleanest path: `hooksecurefunc("QuestLog_SetSelection", ...)` fires when the player clicks a quest and updates the detail pane — the selected log index is available via `GetQuestLogSelection()` at that point. Alternatively, hook `GameTooltip`'s `OnTooltipSetItem`/`SetQuestLogItem` script directly. Either way, resolve the questID, then call the existing `addGroupProgressToTooltip(GameTooltip, questID)`. No protocol changes; no new data structures.

---

### 15. ~~`/sq sync` slash command~~ (*DONE*)

**The gap:** The Force Resync button lives inside `/sq config` → Resync tab. A player who notices stale data mid-session has to open the config panel, navigate to the right tab, and click the button — several steps for a one-shot operation that should be instant.

**The idea:** Add a `/sq sync` slash command that triggers the exact same logic as the Force Resync button: calls `SocialQuestComm:SendResyncRequest()`, enforces the same 30-second cooldown, and re-enables after the cooldown expires. If the command is run while the cooldown is still active, print an error to chat showing how many seconds remain: *"Force Resync is on cooldown. Please wait N more seconds."* Fires a debug message when issued and when rejected by the cooldown.

**Implementation notes:** The 30-second cooldown constant is currently a magic number (`30`) repeated in `Options.lua` — it appears in both the `disabled` guard and the `AceTimer` re-enable call. Centralize it as a module-level constant (e.g. `local RESYNC_COOLDOWN = 30`) in `Communications.lua` alongside `SendResyncRequest`, and reference it from `Options.lua`. The slash command handler in `SocialQuest.lua` checks `SQWowAPI.GetTime() - lastResyncTime < RESYNC_COOLDOWN`; if blocked, prints the remaining seconds via `SocialQuest:Print`; if allowed, sets `lastResyncTime`, calls `SendResyncRequest`, and schedules the `AceConfigRegistry:NotifyChange` re-enable timer. The `lastResyncTime` variable must also move from `Options.lua` to a shared location (or be exposed as a getter/setter on `SocialQuestComm`) so both the button and the slash command share the same state and the cooldown is respected regardless of which path triggered the sync.

### 16. Quest failure reason in failed-quest announcements

**The gap:** When a quest is failed, SQ already broadcasts a banner and chat message (e.g. *"You failed: [The Mana Cells]"*), but gives no indication of *why* it failed. The two most common causes in TBC — timer expiry on timed quests, and escort NPC death on escort quests — are often surprising to the player and always relevant to the party.

**The idea:** Append a failure reason to the existing failed-quest banner and chat message where it can be determined. Examples: *"You failed: [The Mana Cells] — time limit expired"* or *"You failed: [Escort the Prisoner] — escort target died"*. When no reason can be determined, the message is unchanged. The same reason is included when a party member's failure is announced remotely. A new **Test Quest Failed (Timed)** debug button demonstrates the timed-failure variant alongside the existing generic Test Quest Failed button.

**Implementation notes:** `questInfo.timerSeconds ~= nil` reliably identifies a timed quest; when a timed quest fails it is almost certainly due to timer expiry, so append `L["time limit expired"]` in that case. Escort-quest detection is less reliable in the TBC API — `GetQuestTagInfo(questID)` returns a tag type that may include escort quests; verify at implementation time whether this is available via AQL or WoW API and only append the escort reason if a confirmed check exists, otherwise omit it. The failure reason is appended in `Announcements.lua` inside `OnQuestEvent` (for chat) and `OnOwnQuestEvent` (for own banner) before `appendChainStep`. For the remote case, `questInfo.timerSeconds` is already serialized in `SQ_UPDATE` payloads and available at `OnRemoteQuestEvent`. New locale keys: `L["time limit expired"]` and optionally `L["escort target died"]`. New debug test entry in `Options.lua` alongside the existing `failed` test button.

### ~~17. Font size setting for the SQ window~~ (*DONE*)

**The gap:** Players with small monitors, high-DPI displays, or accessibility needs can't adjust how much content fits in the SQ window. The only option today is to resize the window itself — which changes the *amount* of visible space, not the *density* of information within it. A player who wants to see twice as many quest rows without scrolling has no path forward.

**The idea:** A "Window font size" selector in `/sq config` → Social Quest Window (or the flyout panel from #11). Five named presets — Very Small (70%), Small (85%), Normal (100%, default), Large (115%), Very Large (130%) — stored as a numeric scale factor in the AceDB profile. When changed, all text in the SQ window redraws at the scaled size and all row heights adjust proportionally, so the window never has gaps or overflow. Progress bar heights and indent widths scale with the row height.

**Implementation notes:** Store `windowFontScale` (default `1.0`) in AceDB profile. `RowFactory` exposes a `GetScaledRowHeight()` helper (`math.floor(ROW_H * scale)`) and a `GetScaledFont(baseFontObject)` helper that calls `fontString:SetFont(face, baseSize * scale, flags)` after reading the face/size/flags from the base font object with `fontString:GetFont()`. The module-level `ROW_H` constant becomes the *base* height; the effective height at render time is always fetched through the helper. `SetContentWidth` already runs before every render, so a companion `SetFontScale(scale)` call from `GroupFrame:Refresh()` propagates the current profile value before the tab provider renders. No protocol changes; no locale changes needed (labels use existing keys).

---

### 18. ~~Advanced filter language for the search bar~~ (*DONE*)

**The gap:** The search bar filters only by title substring. Players who want to see "all group quests in Hellfire Peninsula" or "all quests between level 60 and 65 that Bob needs" must combine the zone auto-filter, the Party tab, and their own memory. There is no way to compound multiple criteria or filter on any field other than title without the unbuilt flyout settings panel (#11).

**The idea:** Extend the search bar to accept an optional structured filter expression alongside plain text. The moment the user presses Enter, the input is evaluated: if it matches the filter syntax, a dismissible filter label is created from it, the search bar clears, and the structured criteria are applied to all tabs. If the expression looks like a filter attempt but contains errors, a temporary dismissible error label appears beneath the search bar describing what went wrong, and the search bar retains the text so the user can correct it. Plain freeform text (no `=`) continues to work as an immediate, real-time title substring match with no Enter required — the Enter path is only triggered when the expression contains `=`. Typed filter labels compound with previous ones: a second `zone=` definition replaces the first; a new `level=` definition adds to the active criteria. A `[?]` button in the search bar opens a movable, localised help popup explaining all filter keys and syntax with examples.

**Filter syntax:**

```
key=value                  -- equals / substring match
key!=value                 -- not-equal / does not contain (alias: ~=)
key<N                      -- less than (numeric fields)
key>N                      -- greater than (numeric fields)
key<=N                     -- less than or equal
key>=N                     -- greater than or equal
key="value with spaces"    -- quoted value
key=value1|value2          -- OR: zone=Elwynn|Deadmines
key="value 1"|"value 2"    -- OR with quoted values
key=N..M                   -- range: level=60..65 means 60–65
```

The operator appears between the key and the value: `level>=60`, `level<=65`, `zone!=Orgrimmar`. `~=` and `!=` are interchangeable not-equal operators; `~=` is the Lua idiom, `!=` is the C/common idiom — both are accepted. Comparison operators (`<`, `>`, `<=`, `>=`, `!=`, `~=`) apply only to numeric fields (`level`, `step`); on string fields they are treated as parse errors and the expression falls back to plain text. The `=` operator on string fields performs a case-insensitive substring match; on numeric fields it performs exact equality. The `..` range operator (`level=60..65`) is shorthand for `level>=60&level<=65` and applies only to numeric fields; it may be combined with `|` to express multiple ranges (`level=1..29|60..65`). Quotes are optional; required only when the value contains spaces, `|`, or an operator character. Escaped quotes inside a quoted value: `\"`. Keys are case-insensitive. Leading/trailing whitespace around the operator, `|`, and `..` is stripped.

**Supported keys:**

| Key | Alias | Meaning |
|-----|-------|---------|
| `zone` | `z` | Zone name substring match (OR of multiple values) |
| `title` | `t` | Quest title substring match — same as plain text |
| `chain` | `c` | Chain title substring match |
| `level` | `lvl`, `l` | Recommended quest level; exact (`level=60`) or range (`level=60&65`) |
| `group` | `g` | Group quest filter: `group=yes` shows only [Group] quests; `group=no` hides them; `group=2`–`group=5` matches a specific group size |
| `type` | — | Quest type: `chain`, `group`, `solo`, `timed` |
| `player` | `p` | Show only quests where the named party member is listed (Party/Shared tabs) |
| `status` | — | `complete`, `incomplete`, `failed` — filters by local completion state |
| `tracked` | — | `tracked=yes` / `tracked=no` — filters to watched/unwatched quests (Mine tab) |
| `step` | `s` | Chain step number; exact or range |

Additional keys to consider at implementation time: `instance` (match instance name), `shared` (show only quests the local player can still share), `missing` (show quests the local player lacks that others have).

**Parser design (fail-fast, three-way result):** The parser runs only on Enter, not on every keystroke, and returns one of three outcomes:

- **`nil`** — the string is clearly not a filter attempt; treat as a plain-text search, no error shown.
- **`{ filter = <descriptor> }`** — a valid, fully-parsed filter; apply it and clear the search bar.
- **`{ error = true, message = <string> }`** — the string looks like a filter but is malformed; display the error label and leave the search bar text intact for correction.

The dividing line between `nil` and an error result is the presence of `=` in the trimmed string. If there is no `=`, the input cannot possibly be a filter expression — return `nil` immediately with zero further processing (fast-fail). Once `=` is detected, the parser commits to the filter path and all subsequent failures produce error results rather than silent `nil`.

Step 1: no `=` present → return `nil`.
Step 2: extract the leading key token with `(\w+)\s*([~!<>]?=|[<>])`. If the key is not in the recognised key table → error: `L["Unknown filter key: '%s'"]`. If the operator is unrecognised → error: `L["Invalid operator '%s' for key '%s'"]`.
Step 3: validate operator/field compatibility — comparison operators on string fields → error: `L["Operator '%s' cannot be used with text field '%s'"]`.
Step 4: parse values — handle quotes, `\"` escape sequences, `|` OR combiner, `..` range operator. Specific errors: unclosed quote → `L["Unclosed quote in filter expression"]`; non-numeric value for a numeric field → `L["Expected a number for '%s', got '%s'"]`; range min > max → `L["Invalid range: min (%s) must be less than or equal to max (%s)"]`; empty value after operator → `L["Missing value after operator '%s'"]`.

Error messages are plain, lower-case, player-facing strings. Every error string is a locale key so all 12 locales can provide translations. The entire parser is a pure function with no side effects and no allocations on the fast-fail (`nil`) path.

**Filter table extension:** The existing `filterTable = { zone = "...", search = "..." }` is extended to carry richer field types while remaining backward-compatible with the existing tab `BuildTree` methods until they are updated:

```lua
filterTable = {
    search  = "plain text",            -- existing: substring on title (real-time, not from parser)
    zone    = { "Elwynn", "Deadmines" }, -- OR list; string kept as single-element table internally
    level   = { min = 60, max = 65 },    -- from level=60..65
    group   = "yes",
    player  = "Thad",
    status  = "incomplete",
}
```

**Filter label tooltip:** Every filter label's tooltip (`GameTooltip` on `OnEnter`) displays the complete original filter expression string so that a truncated label never hides what the filter actually says. Example: hovering `zone: Elwynn | Deadmines` shows `"zone=Elwynn|Deadmines"` in the tooltip.

**Error label behavior:** When the parser returns an error result, a dismissible error label appears immediately below the search bar, pushing the filter labels, expand/collapse row, and scroll frame downward to avoid overlap. The label text is formatted as `L["Filter error: %s"]` populated with the parser's message (e.g. *"Filter error: unknown filter key 'palyer'"*). The error label uses a distinct colour (red or amber) to differentiate it from normal filter labels. Clicking its `[x]` dismiss button removes the label and restores the normal layout. The error label is also cleared automatically the next time the user types in the search bar, so it never persists as stale feedback. There is at most one error label at a time — a new parse error replaces the previous one.

**Dismissible label factory:** Both filter labels and error labels share the same visual structure: a full-width strip with a text FontString on the left, a `[x]` dismiss button on the right, and a tooltip that shows full content on hover. Rather than duplicating this frame construction, a `UI/HeaderLabel.lua` module (or a factory table `SocialQuestHeaderLabel`) exposes a single constructor:

```lua
SocialQuestHeaderLabel.New(parent, config)
-- config = {
--     text     = string,          -- display text (may be truncated)
--     tooltip  = string,          -- full text shown on hover
--     color    = { r, g, b },     -- label text colour
--     height   = number,          -- row height in pixels
--     onDismiss = function(),      -- called when [x] is clicked
-- }
-- returns: frame, setText(s), setTooltip(s), dismiss()
```

`GroupFrame.lua` uses this factory for filter labels, error labels, and any future notification strips (e.g. a "sync in progress" indicator). The factory owns the frame construction and tooltip wiring; `GroupFrame.lua` owns the layout (anchoring and stacking order).

**Filter syntax help window:** A `[?]` button sits inside the search bar to the left of the existing `[x]` clear button. Clicking it opens (or closes, if already open) a movable, Escape-closable popup panel that documents the filter language. The panel contains:

- A title: *"SQ Filter Syntax"*
- A brief introductory line: *"Type a filter expression in the search bar and press Enter. Plain text searches without pressing Enter."*
- A table listing every supported key, its aliases, its type (text/numeric), and a short one-line description.
- A syntax reference block showing example expressions with plain-English explanations (e.g. `zone=Elwynn|Deadmines` → *"show quests in Elwynn Forest or The Deadmines"*).
- A note on quoting and escaping rules.

The panel is a standard `BasicFrameTemplate` frame registered in `UISpecialFrames` so Escape closes it. It is movable via left-button drag on the title bar. Its content is built entirely from locale strings so all 12 locales can provide full translations; the key list and example expressions use the same locale keys as error messages where possible, avoiding duplication. The panel is created lazily on first `[?]` click and then shown/hidden on subsequent clicks.

**Implementation notes:** The parser lives in a new `UI/FilterParser.lua` module (`SocialQuestFilterParser`) — a pure library with no WoW frame dependencies, making it independently testable. `GroupFrame.lua` calls `SocialQuestFilterParser:Parse(text)` in the `OnKeyDown` / `OnEnter` handler of the search box; `BuildTree` in each tab is updated to interpret the extended filter table fields. The `WindowFilter` module stores an ordered list of active filter descriptors (one per key) keyed by filter key, so a second `zone=` parse result replaces the first `zone` entry. Filter labels, error labels, and any future header strips are all created via the `SocialQuestHeaderLabel` factory and stacked vertically in the fixed header by `GroupFrame:Refresh()`, each with its own `[x]` dismiss button and full-text tooltip. The `[?]` help button is created once in `createFrame()` alongside the `[x]` clear button; the help panel itself is created lazily. All user-facing strings introduced by this feature — error messages, key descriptions, example annotations, help panel text — are locale keys. No protocol changes.

---

### ~~19. Zone quest count in group frame headers~~ (*DONE*)

**The gap:** Zone section headers in the group quest window show only the zone name. When scanning a tab with many zones, there is no at-a-glance indicator of how many quests are grouped under each header — the player must visually count rows or expand/collapse sections to gauge the density.

**The idea:** Append a parenthetical quest count to each zone header label: "Elwynn Forest (3)", "Hellfire Peninsula (7)". A config toggle in `/sq config` → Social Quest Window enables this, defaulting to on. The count reflects the number of quests rendered under that zone after all active filters are applied — a filtered view showing 2 of 5 zone quests displays "(2)" not "(5)".

**Implementation notes:** Add `db.window.zoneQuestCount` boolean (default `true`) to AceDB profile. Zone header text is assembled in each tab's `BuildTree` method. After accumulating the per-zone quest list, append `string.format(" (%d)", count)` to the zone name string before passing it to the header row, conditional on `db.window.zoneQuestCount`. Add a toggle to `/sq config` → Social Quest Window. No protocol changes; no locale changes required (the format is purely numeric).

---

### ~~20. Friend online/offline banners~~ (*DONE*)

**The gap:** WoW's default UI shows friend login and logout notifications only as system chat messages, easily missed in busy chat. SocialQuest already has a well-established banner system for quest events and follow notifications, but it makes no use of social presence events.

**The idea:** Display a banner notification when a friend logs in or out. Login format for a BattleTag friend: *"Joe (EvilWarlock 32 Warlock) Online"* — "Joe" is the BattleTag name and the parenthetical shows the character name, level, and class. For a regular (non-BattleTag) friend: *"EvilWarlock 32 Warlock Online"*. Logout banners follow the same format with "Offline" in place of "Online". Separate config toggles for login and logout banners, both defaulting to on.

**Implementation notes:** Battle.net presence events `BN_FRIEND_ACCOUNT_ONLINE` and `BN_FRIEND_ACCOUNT_OFFLINE` fire when a BattleTag friend connects or disconnects; `BNGetFriendInfoByID(bnetIDAccount)` provides the BattleTag name, active character name, level, and class. For regular (non-BattleTag) friends, detecting login/logout requires diffing the friend list on `FRIENDLIST_UPDATE` since WoW raises no per-friend event — track connected status in a session table keyed by character name, diff on each `FRIENDLIST_UPDATE` fire; `GetFriendInfo(index)` provides name, level, class, and `connected` boolean. Verify at implementation time whether `BN_FRIEND_ACCOUNT_ONLINE` is available at Interface 20505 (TBC Anniversary runs on modern Battle.net infrastructure but BN_ API availability should be confirmed before relying on it). Banner color: use a new `friend` color key in `Colors.lua` — the existing follow tan is a candidate base or define a distinct social color. New toggles (`friendOnline`, `friendOffline`) in the General section of `/sq config`. No protocol changes.

---

### 21. Quest suggested level in group frame

**The gap:** The group quest window shows quest titles but gives no indication of a quest's recommended level. Players levelling with a mixed-level group, or who have a backlog of quests from earlier zones, have no quick way to see which quests are appropriate to tackle next without cross-referencing the quest log.

**The idea:** A config toggle (default off) that appends the quest's suggested level in square brackets after the title in the group quest window: *"Wanted: Arazzius the Cruel [62]"*. Applies to all three tabs. The bracketed level appears immediately after the quest title, before any chain step annotation.

**Implementation notes:** Add `db.window.showQuestLevel` boolean (default `false`) to AceDB profile. Quest level is available via `AQL:GetQuestInfo(questID)` — verify the exact field name at implementation time (`questLevel`, `level`, or similar). The title string is constructed in each tab's `BuildTree` or in `RowFactory.AddQuestRow`. When `db.window.showQuestLevel` is true, append `string.format(" [%d]", questLevel)` to the title before it is passed to the row. If the quest level is nil (not in AQL cache), display the title unmodified. Add the toggle to `/sq config` → Social Quest Window alongside the zone count toggle (#19). No protocol changes; no locale changes required.

---

### 22. Zone grouping display toggles

**The gap:** The quest window always groups quests by zone using WoW's default behavior — class quests appear under their class zone header, and the zone is always determined by the quest giver's location. Players who want to organize quests differently — by turn-in location, or by where their objectives are — have no control over these groupings.

**The idea:** A set of zone-grouping controls in the flyout settings panel (#11) or `/sq config` → Social Quest Window:

1. **Show class quests in class zone grouping** (toggle, default ON): Mirrors WoW's default behavior. When toggled off, class quests are classified under their actual geographic zone like any other quest.
2. **Quest zone source** (radio, two options): *(a)* Use quest giver's location *(default)* — the zone where the quest is picked up determines grouping; *(b)* Use quest turn-in location — the zone of the turn-in NPC determines grouping.
3. **Show quest in every zone containing an objective** (toggle, default OFF): When enabled, a quest also appears under every zone header where one of its kill/collect/interact objectives is located, potentially causing a quest to display in multiple zone sections simultaneously.
4. **Suppress in primary zone while objectives are incomplete** (toggle, default OFF, indented, enabled only when #3 is ON): When enabled, the quest is hidden from its primary zone grouping while any objectives remain incomplete — surfacing it only in the objective zones. Once all objectives are complete, it reappears in the primary zone for turn-in awareness.

**Implementation notes:** All four settings stored in AceDB profile under `db.window.zoneGrouping.*`. The quest zone source and class quest logic are applied during the zone resolution step in each tab's `BuildTree` (the lookup that currently calls `AQL:GetQuestInfo(questID).zone`). Objective zone data requires Questie or Grail to provide per-objective map coordinates — verify availability at implementation time; if unavailable, toggles #3 and #4 are visible but greyed out with a tooltip indicating the required addon. No protocol changes.

---

### 23. Quest difficulty / time-sink badging

**The gap:** All quests in the window look identical regardless of how time-intensive they are. A kill quest with mobs next door is indistinguishable from a multi-step quest requiring travel across two zones, leaving players to rely on memory or prior experience when deciding which quests to prioritize.

**The idea:** A config toggle (default OFF) that shows a time-sink badge alongside each quest title in the SQ window. When enabled, each quest with sufficient data receives one of a small set of tier labels — for example: Fast, Normal, Long, Heavy Travel — rendered as a small colored tag or symbol to the left of the quest title. Players can scan at a glance to find quick wins or identify the quests that will eat up a session.

**Implementation notes:** Difficulty scoring is synthesized from available Questie/Grail data: estimated travel distance to objectives (from map coordinates), total objective counts, required kill quantities, and whether the turn-in zone differs from the quest giver zone. The exact tier thresholds and weighting formula should be tuned at implementation time based on what fields Questie/Grail expose. Store the toggle as `db.window.showDifficultyBadge` (default `false`). Badge rendering added to `RowFactory.AddQuestRow` alongside the level bracket (#21). Quests without sufficient objective location data show no badge — the feature degrades gracefully. No protocol changes.

---

### 24. Group size recommendation in SQ quest data

**The gap:** SQ transmits quest state (accepted, progress, completed) but not the quest's recommended group size. Players have no way to see "this quest recommends 3 players" directly in the SQ window or tooltips — they must look it up separately.

**The idea:** Transmit the quest's recommended group size as an additional field in SQ quest data. Each SQ player resolves the group size locally from AQL/Questie data and includes it when broadcasting `SQ_INIT` and `SQ_UPDATE`. On the receiving end, the group size is surfaced in the quest window title row and in quest tooltips — for example, `[Wanted: Arazzius the Cruel] (3)` or a dedicated "Group: 3" line in the tooltip block — letting all party members see at a glance which quests are designed for a group.

**Implementation notes:** Add `groupSize` (integer or nil) to the `SQ_INIT` and `SQ_UPDATE` payloads. Resolve from `AQL:GetQuestInfo(questID).groupSize` (or the equivalent Questie/Grail field — verify field name at implementation time). Store as `entry.groupSize` in `PlayerQuests`. Display in `RowFactory.AddQuestRow` when `db.window.showGroupSize` is true (default `false`), appending `(N)` or a `[Group: N]` badge after the title. Also append in the tooltip group progress block in `Tooltips.lua`. If `groupSize` is nil, display nothing. Protocol change: `groupSize` field added to `SQ_INIT` and `SQ_UPDATE` payloads; backward-compatible (nil on older clients, displayed normally on newer clients).

---

## Summary

| # | Feature | Complexity | Impact | Protocol change? |
|---|---------|-----------|--------|-----------------|
| 1 | ~~Progress bars~~ | — | — | *DONE* |
| 2 | Almost-done highlighting | Very low | Medium | No |
| 3 | Chain "what's next" notification | Low | High | No |
| 4 | Zone quest summary | Medium | High | No |
| 5 | ~~Dungeon quest auto-filter~~ | — | — | *DONE* |
| 6 | ~~One-click share button~~ | — | — | *DONE* |
| 7 | Session stats | Low | Medium | No |
| 8 | Objective countdown mode | Very low | Medium | No |
| 9 | Party zone divergence | Medium | High | Yes (SQ_ZONE) |
| 10 | ~~Group quest ready-check~~ | — | — | No plans to implement |
| 11 | Flyout settings panel | Medium | Medium | No |
| 12 | ~~Search/filter bar~~ | — | — | *DONE* |
| 13 | ~~Do-Not-Disturb toggle~~ | — | — | *DONE* |
| 14 | ~~Quest log hover tooltip~~ | — | — | *DONE* |
| 15 | ~~`/sq sync` slash command~~ | — | — | *DONE* |
| 16 | Quest failure reason | Very low | Medium | No |
| 17 | ~~Font size setting~~ | — | — | *DONE* |
| 18 | ~~Advanced filter language~~ | — | — | *DONE* |
| 19 | ~~Zone quest count in headers~~ | — | — | *DONE* |
| 20 | ~~Friend online/offline banners~~ | — | — | *DONE* |
| 21 | Quest suggested level in window | Very low | Low | No |
| 22 | Zone grouping display toggles | Medium | High | No |
| 23 | Quest difficulty / time-sink badging | Medium | Medium | No |
| 24 | Group size recommendation | Low | Medium | Yes (SQ_INIT, SQ_UPDATE) |

**Quick wins (start here):** #2 (almost-done highlight), #3 (chain what's-next notification), #8 (objective countdown), #13 (do-not-disturb), #16 (failure reason), #17 (font size), #19 (zone quest count), #21 (quest level display), #24 (group size recommendation) — all low/very-low complexity.

**High-value medium lifts:** #9 (zone divergence), #11 (flyout settings), #18 (advanced filter language — includes label factory, error UX, and help window), #22 (zone grouping toggles), #23 (time-sink badging), #24 (group size recommendation).

**Biggest feature:** #4 (zone quest summary) — most planning effort required but highest pre-session value for organized groups.
