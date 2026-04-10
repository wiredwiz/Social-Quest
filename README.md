# SocialQuest

  SocialQuest is a World of Warcraft addon for **The Burning Crusade Anniversary** that helps
  players quest together. When you are in a party, raid, or battleground, SocialQuest keeps
  every member's quest progress synchronized in real time and surfaces that information exactly
  when and where it is useful — without requiring any setup from your groupmates beyond having
  the addon installed.
  
  ---
  
  ## Required Dependencies
  * Absolute Quest Log (library Add-on)
  * Ace3 (library Add-on)

  If either of these libraries are not installed, SocialQuest will print an error on login and remain disabled.
  
  ---

  ## Language Support

  SocialQuest ships with localizations for all languages supported by the WoW client. All
  in-game text — banner messages, chat announcements, window labels, and settings — will
  appear in your client language automatically. No configuration is needed.

  | Language | Locale |
  |---|---|
  | English | enUS |
  | German | deDE |
  | Spanish (Spain) | esES |
  | Spanish (Latin America) | esMX |
  | French | frFR |
  | Italian | itIT |
  | Japanese | jaJP |
  | Korean | koKR |
  | Portuguese (Brazil) | ptBR |
  | Russian | ruRU |
  | Chinese (Simplified) | zhCN |
  | Chinese (Traditional) | zhTW |

  ---

  ## Colorblind Support

  SocialQuest includes a dedicated colorblind palette based on the Okabe-Ito scheme.  See more about this below.

  ---

  ## Slash Commands

  | Command | Effect |
  |---|---|
  | `/sq` | Toggle the group quest window open/closed |
  | `/sq config` | Open the settings panel |
  | `/sq sync` | Request a fresh quest snapshot from all group members |
 
  ---

  ## Keybindings
  
  The group quest window can also be bound to a keyboard shortcut in
  **Options → Key Bindings → AddOns → Social Quest → Toggle Social Quest Window**.  

  This allows you to easily map a custom key to toggle the SocialQuest Quest Window.
  
  ---

  ## WoW Version Support

  SocialQuest runs on all active WoW version families:

  | Version | Interface |
  |---|---|
  | Classic Era | 1.14.x |
  | The Burning Crusade (Anniversary) | 2.5.x |
  | Mists of Pandaria Classic | 5.4.x |
  | Retail (The War Within) | 11.x |

  ---

  ## Quest Chain Support Requirements:
  
  SocialQuest surfaces information relating to quest chains, but only if you have either Questie or the Quest Weaver add-on installed.
  SocialQuest gets its data from Absolute Quest Log (AQL), which attempts to gather as much information about quests as possible.  
  AQL does not require Questie or Quest Weaver to be installed, but if either one is, AQL will detect it and utilize their data
  to establish full quest chain info.  With full quest chain data available, you will be able to see each player's position in
  their quest chains, making it easy at a glance to see that your friend is on the same chain as you but just 2 steps behind.
  I personally feel that SocialQuest works best when paired with Questie.
  
  ---

  ## The Group Quest Window

  Open the main window with `/sq`, a custom keybind or by **left-clicking** the SocialQuest minimap icon.
  The window is resizable and can be moved by dragging the title bar. Press **Escape** to close
  it. The window has three tabs: **Shared**, **Mine**, and **Party**.

  ### Shared Tab

  Shows every quest that **two or more** players in your group are currently engaged with,
  grouped by zone. This is the primary coordination view — it tells you at a glance where your
  group overlaps so you know who to help and what to work on together.

  When multiple members are on different steps of the same quest chain, the chain is shown as a
  single entry with each step listed in order beneath a chain header. For example, if you are on
  "The Cipher of Damnation" (Step 2) and your party member is on "The Cipher of Damnation"
  (Step 1), both steps appear together under one chain entry.

  > **Chain info restriction:** Quest chain grouping and step numbers are only available for
  > quests that AbsoluteQuestLog has chain data for. Quests without known chain data appear as
  > standalone entries even if they are part of a series. The amount of coverage depends on the
  > AbsoluteQuestLog library's database.

  ### Mine Tab

  Your own active quests, organized by zone and chain. Objectives are shown for each quest.
  For chain quests, party members currently on a **different step** of the same chain appear as
  player rows beneath your quest entry, so you can see how your group is distributed across the
  chain.

  > **Chain info restriction:** Cross-chain peer rows only appear when AbsoluteQuestLog
  > recognizes both quests as part of the same chain. If chain data is unavailable for a quest,
  > no peer rows will be shown even if a party member is on a related quest.

  **Shift-click** a quest title to add or remove it from your objective tracker.

  ### Party Tab

  Every quest currently active across the **entire group**, regardless of who has it, organized
  by zone. Each quest shows all party members with a stake in it:

  | Status shown | Meaning |
  |---|---|
  | Objective counts (e.g. `3/8 · 1/1`) | Member has the quest in progress |
  | *Objectives complete* | Member has finished all objectives but not yet turned in |
  | *Turned In* | Member has already turned the quest in this session |
  | *Needs it Shared* | Member lacks the quest and you have it — you may be able to share it |
  | *Reason label (e.g. "level too low")* | Member cannot receive the quest right now; the reason is shown |
  | *(shared, no data)* | Member appears to have the quest (via group data) but has no SocialQuest |

  When a quest is shareable and at least one party member needs it, a **[Share]** button
  appears on the quest row. Clicking it shares the quest with the group. Members who are
  ineligible (wrong level, wrong class/race, missing a prerequisite) show a specific reason
  label so you know at a glance why they cannot receive it.

  > **Data restriction:** Objective counts for party members only appear if they have
  > SocialQuest installed. Members without SocialQuest show a "no data" note for quests that
  > appear in the group's shared quest log.

  ### Navigating the Window

  Click any **zone header** to collapse or expand that zone's quests. When more than one zone is
  present, **Expand All** and **Collapse All** buttons appear at the top of the tab. Collapse
  state is saved per tab and persists across sessions.

  Each quest row has a **[?] button** that opens a small popup with the quest's Wowhead URL.
  Select all and copy (`Ctrl+A`, `Ctrl+C`) to grab the link.

  ### Searching and Filtering

  A **search bar** appears at the top of the window below the tab strip. Typing filters
  all three tabs by quest or chain title (case-insensitive). The search text is shared
  across tabs and preserved across loading screens.

  The window also offers an **Advanced Filter Language** for structured queries. Type a
  filter expression and press Enter to activate it. Active filters appear as dismissible
  labels in the header. Examples:

  | Expression | Effect |
  |---|---|
  | `level>=60` | Show only quests at or above level 60 |
  | `zone=Elwynn\|Deadmines` | Show quests in Elwynn Forest or Deadmines |
  | `status=incomplete` | Show quests with objectives not yet finished |
  | `type=dungeon` | Show dungeon quests |
  | `type=kill&gather` | Show quests with both kill and gather objectives |
  | `shareable=yes` | Show quests you can currently share with a party member |
  | `player=Thad` | (Party/Shared tabs) Show only quests involving Thad |

  Click the **[?]** button in the search bar header for a full syntax reference panel.

  ---

  ## Quest Tooltips

  Hover over any **quest hyperlink** in chat to see a **Group Progress** section appended to the
  bottom of the standard quest tooltip. Each party member who has that quest is listed with their
  current objective counts.

  > **Restriction:** Tooltip data only reflects members who have SocialQuest installed and have
  > transmitted their quest state. Members without SocialQuest do not appear in the tooltip.

  ---

  ## On-Screen Banner Notifications

  When a party member's quest state changes, a color-coded banner appears on screen using WoW's
  built-in raid warning display. Each event type has its own color:

  | Event | Banner text example |
  |---|---|
  | Accepted | `Thralldar accepted: The Cipher of Damnation (Step 1)` |
  | Abandoned | `Thralldar abandoned: The Cipher of Damnation` |
  | Objectives complete | `Thralldar completed: The Cipher of Damnation` |
  | Turned in | `Thralldar turned in: The Cipher of Damnation (Step 1)` |
  | Failed | `Thralldar failed: The Cipher of Damnation` |
  | Objective progress | `Thralldar progressed: The Cipher of Damnation — Fragments Collected (3/8)` |
  | Objective complete | `Thralldar completed objective: The Cipher of Damnation — Fragments Collected (8/8)` |
  | Objective regression | `Thralldar regressed: The Cipher of Damnation — Fragments Collected (2/8)` |

  The `(Step N)` annotation appears on accepted, abandoned, completed, and failed events for
  quests with known chain data. It does not appear on the "objectives complete" event.

  ### "Everyone Has Completed" Banner

  When every engaged group member has finished all objectives on the same quest, a special
  purple banner fires:
  `Everyone has completed: The Cipher of Damnation`

  Players who have already turned the quest in also count as finished for this check, so the
  banner fires as soon as the last engaged member completes their objectives — even if some
  members turned in earlier.

  > **Restrictions:**
  > - This banner only fires if **every** member in the group has SocialQuest installed. If even
  >   one member lacks it, the banner is suppressed entirely, because their objective state
  >   cannot be verified.
  > - "Engaged" means the player currently has the quest active or has already turned it in
  >   this session. Players who were never engaged with the quest are excluded from the check.
  > - Only the player who triggered the final completion sends the accompanying chat message,
  >   preventing duplicate messages when multiple SocialQuest clients detect the same condition
  >   simultaneously.

  ---

  ## Chat Announcements

  SocialQuest can send messages to your group chat channel when **your own** quest events occur.
  Quest names appear as **gold WoW hyperlinks** — recipients can hover or click the quest name
  to see the full quest tooltip without needing SocialQuest installed.

  Example message:
  {skull} SocialQuest: Quest Accepted: [The Cipher of Damnation] (Step 1)

  Objective progress messages follow Questie's format:
  {skull} SocialQuest: 3/8 Fragments Collected for [The Cipher of Damnation]!
  {skull} SocialQuest: 2/8 Fragments Collected (regression) for [The Cipher of Damnation]!

  ### Announcement Suppression With Questie

  If **Questie** is installed and its announce feature is enabled for the same event type,
  SocialQuest suppresses its own message to avoid duplicates. Suppression applies to:
  accepted, abandoned, turned in, and objective complete.

  > **Exception:** Objective **progress** and **regression** messages are **never suppressed**,
  > because Questie has no equivalent — it only announces when an objective is fully completed,
  > not for partial progress or for counts going backward.

  ### Announcement Channels

  | Channel | Quest events | Objective progress & complete |
  |---|---|---|
  | Party | Yes (configurable) | Yes (configurable) |
  | Raid | Yes (configurable) | No |
  | Guild | Yes (configurable) | No |
  | Battleground | Yes (configurable) | Yes (configurable) |
  | Whisper Friends | Yes (configurable) | Yes (configurable) |

  Raid and Guild do not support objective progress/complete announcements — those events occur
  too frequently in large groups to be practical in those channels.

  ---

  ## Real-Time Quest Progress Sync

  As soon as you join a group, SocialQuest exchanges a full snapshot of everyone's active quest
  log over the addon communication channel. From that point forward, every objective update,
  quest acceptance, completion, and abandonment is broadcast automatically.

  In **parties** (up to 5 players), the full snapshot is sent immediately on joining.

  In **raids** and **battlegrounds**, each player broadcasts a lightweight beacon on joining
  (with a random 0–8 second delay to avoid a message flood). Other members respond individually
  by sending their full snapshot as a whisper. This keeps network traffic manageable in large
  groups.

  > **Restriction:** Quest data sync uses addon messaging, which requires SocialQuest to be
  > installed on both ends. Guild members and players outside your current group do not receive
  > or transmit addon quest data, even if guild chat announcements are enabled.

  > **After a UI reload:** Pressing `/reload` mid-session will re-trigger the sync handshake
  > automatically so your group data is restored without rejoining the group.

  ---

  ## How to Customize It

  Open settings with **`/sq config`**, by **right-clicking** the minimap icon, or through
  **Interface Options → AddOns → SocialQuest**. Settings are shared across all your characters
  by default (one profile for the account).

  ---

  ### General

  | Setting | Default | Description |
  |---|---|---|
  | Enable SocialQuest | On | Master on/off. Disabling stops all announcements, banners, sync, and tooltips. |
  | Show received events | On | Master toggle for all incoming banners. Turn off to silence all group notifications at once without changing per-channel settings. |
  | Colorblind Mode | Off | Switches all banner colors and status indicators to the Okabe-Ito colorblind-friendly palette. Not needed if WoW's built-in Colorblind Mode (Interface Options → Accessibility) is already enabled — SocialQuest detects that setting automatically. |
  | Show banners for your own quest events | Off | Disabled by default. When enabled, your own quest events also appear as on-screen banners. |

  ## Accessibility — Color Vision

  Banner notifications and quest status text throughout the interface are color-coded by event
  type. By default these colors include red and green, which can be difficult to distinguish for
  players with red-green color vision deficiency.

  SocialQuest includes a dedicated colorblind palette based on the
  [Okabe-Ito](https://jfly.uni-koeln.de/color/) scheme, one of the most widely recommended
  palettes for accessible data visualization. When active, every banner color and every colored
  status indicator in the quest window switches to a version distinguishable under the most
  common forms of color blindness:

  | Event | Standard color | Colorblind color |
  |---|---|---|
  | Accepted | Green | Sky Blue |
  | Objectives complete | Cyan | Teal |
  | Turned in | Gold | Gold *(unchanged)* |
  | Abandoned | Grey | Grey *(unchanged)* |
  | Failed | Red | Vermillion |
  | Objective progress | Orange | Amber |
  | Objective complete | Lime | Reddish Purple |
  | Everyone completed | Purple | Blue |
  | Follow notification | Warm Tan | Yellow |

  Colorblind mode activates in either of two ways:

  - **Automatically**, if WoW's built-in **Colorblind Mode** setting is enabled under
    Interface Options → Accessibility. SocialQuest detects this CVar and applies its
    palette without any additional steps.
  - **Manually**, via the **Colorblind Mode** toggle in SocialQuest's own General settings,
    which lets you use the accessible palette independently of the game-wide setting.

  The game-wide setting always takes precedence — if it is enabled, SocialQuest uses the
  colorblind palette regardless of its own toggle.

  ---

  When **Show banners for your own quest events** is enabled, a sub-group of toggles appears
  (**Own Quest Banners**) letting you choose exactly which event types trigger your own banners:
  Accepted, Abandoned, Objectives Complete, Turned In, Failed, Objective Progress, and
  Objective Complete.

  ---

  ### Party

  This is the most common usage for SocialQuest.  I realize 99% of socially questing folks are doing so in a party questing context.

  | Setting | Default | Description |
  |---|---|---|
  | Enable transmission | On | Broadcast your quest data to party members via addon comm. |
  | Show received events | On | Allow banner notifications from party members. |
  | Announce in Chat | Varies | Per-event toggles for which of your quest events are announced in party chat. All 7 event types available (including objective progress and complete). |
  | Display Events | All on | Per-event toggles for which inbound event types show a banner. |

  ---

  ### Raid

  A less likely used scenario, but still supported for those that would like the possibilty.

  | Setting | Default | Description |
  |---|---|---|
  | Enable transmission | On | Broadcast your quest data to raid members. |
  | Show received events | On | Allow banner notifications from raid members. |
  | Only show notifications from friends | Off | Suppress banners from players not on your friends list. Useful in large PuG raids. |
  | Announce in Chat | All off | Per-event toggles for quest-only announcements (no objective events in raid chat). All off by default — raid chat announcements are rarely appropriate. |
  | Display Events | All on | Per-event toggles for inbound banners. |

  ---

  ### Guild

  Let me first say that I fully realize most people won't want this.  Most guilds won't tolerate this.  That said, if you are in a guild that for some reason doesn't mind
  members spamming guild chat with automated quest messages, this is possible.  Use your common sense though, don't spam guildies against their wishes, don't be a jerk.
  
  There is a reason I turn this off by default.

  | Setting | Default | Description |
  |---|---|---|
  | Enable chat announcements | Off | Send your quest events to guild chat. Off by default. |
  | Announce in Chat | All off | Per-event toggles for which events are announced. Quest events only — no objective events in guild chat. |

  > **Note:** Guild integration works differently from party/raid. Messages are sent as plain
  > guild chat, so guild members **without** SocialQuest can read them. However, there is no
  > addon-comm sync for guild, so no incoming banners or tooltip data are available for
  > guild-only interactions.

  ---

  ### Battleground

  Also, not a common use scenario, that said, there are those quests in Alterac Valley.  However, one alternative is to use friend whisper settings instead
  with the "group members only" if you don't care about banner messages and whispered quest update messages suffice for your desires.

  | Setting | Default | Description |
  |---|---|---|
  | Enable transmission | On | Broadcast your quest data to battleground members. |
  | Show received events | On | Allow banner notifications from battleground members. |
  | Only show notifications from friends | Off | Suppress banners from strangers. |
  | Announce in Chat | All off | Per-event toggles. All 7 event types available including objective progress. All off by default. |
  | Display Events | All on | Per-event toggles for inbound banners. |

  ---

  ### Whisper Friends

  Optionally whisper your quest events to online friends, even when they are not in your group.

  | Setting | Default | Description |
  |---|---|---|
  | Enable whispers to friends | Off | Send your quest events as whispers to online friends. Off by default. |
  | Group members only | Off | When enabled, only whispers friends who are currently in your group. |
  | Announce in Chat | Varies | Per-event toggles. Quest events default on; objective events default off. |

  > **Note:** Whisper Friends is outbound-only. There are no incoming banners from friends
  > via this channel — events you receive from friends in your group come through the normal
  > party/raid path.

  ---

  ### Follow Notifications

  When one SocialQuest user auto-follows another, both players are notified via the addon comm
  channel (not a visible WoW whisper). This is handy so you don't have to ask if your friend is
  following yet — and if they get stuck on a post and stop following mid-run, you'll know
  immediately.

  When someone starts or stops following you, you receive both a **chat message** and an
  **on-screen banner notification** in warm tan (yellow in colorblind mode).

  | Setting | Default | Description |
  |---|---|---|
  | Enable follow notifications | On | Master toggle for the follow whisper system. |
  | Announce when you follow someone | On | Sends an addon comm whisper to the player you begin auto-following so they know. |
  | Announce when followed | On | Shows a chat message and banner when someone starts or stops following you. |

  ---

