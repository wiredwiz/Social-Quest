================================================================================
  SocialQuest
  Social quest coordination for World of Warcraft (all active versions)
  Supports: Classic Era (11508), TBC Anniversary (20505),
            MoP Classic (50503), Retail (120001)
================================================================================

Social Quest lets players in a party, raid, or guild coordinate quest progress
in real time. When you accept, finish, or complete a quest, your group members
see a notification on their screens and optionally in chat. A shared quest
window shows what everyone is working on at a glance, and tooltip enhancements
show group progress when you mouse over a quest in your log.

Social Quest only transmits numeric data (quest IDs and objective counts).
Quest titles and text are never sent over the network; they are resolved
locally on each player's client.


--------------------------------------------------------------------------------
  REQUIREMENTS
--------------------------------------------------------------------------------

  - Ace3               (required — addon framework)
  - Absolute Quest Log (required — quest data library; Social Quest disables
                        itself if AQL is not installed)

  For Social Quest to work properly, both the Ace3 and Absolute Quest Log 
  addons must be installed. 

  Optionally you get more functionality if you also have Questie or Quest Weaver 
  installed.  You could install neither, both or either.

--------------------------------------------------------------------------------
  HOW TO INSTALL
--------------------------------------------------------------------------------

  Drop the Ace3, AbsoluteQuestLog and SocialQuest add-on folders into your
  Interface/AddOns folder of your World of Warcraft installation.  This version
  currently only works with Burning Crusade Anniversary.  The folder for this
  version is found in the _anniversary_ folder under the game install.

--------------------------------------------------------------------------------
  FEATURES
--------------------------------------------------------------------------------

  Quest Event Sharing
  -------------------
  When you accept, abandon, finish objectives on, complete, or fail a quest,
  Social Quest can broadcast that event to your party, raid, guild, or
  battleground group via addon communication. Each channel can be enabled or
  disabled independently.

  Chat Announcements
  ------------------
  Quest events can also be announced in party, raid, guild, battleground, or
  guild chat. Each event type (accepted, abandoned, finished, completed, failed,
  objective progress, objective complete) is individually toggleable per channel.
  Messages are formatted as:
      [Quest Name] — e.g. "⭐ SocialQuest: Quest Accepted: [Costly Menace]"

  Banner Notifications
  --------------------
  When a group member's quest event arrives, Social Quest displays a brief
  banner on screen (using the game's built-in RaidNotice system). Banners show
  the member's name, the event type, and the quest title. Each event type is
  individually toggleable per channel.

  "Everyone Has Finished" Notification
  -------------------------------------
  When all group members with Social Quest installed have completed all
  objectives on a shared quest (but before turning in), a purple notification
  banner appears: "Everyone has finished: [Quest Name]". This only fires when
  every engaged member is tracked by Social Quest; if any member does not have
  the addon the notification is suppressed.

  Own Quest Banners
  -----------------
  Social Quest can show banners for your own quest events as well as group
  members'. This is off by default and configured separately under the General
  tab, with per-event-type toggles.

  Group Quest Window
  ------------------
  A quest progress window is accessible via /sq or the minimap button.
  It has three tabs:

    Mine    — Your own active quests, organized by zone. Shows objectives and
              chain step information.

    Party   — Each group member's quest progress, organized by player and zone.
              Shows objective counts for each quest they have. Members without
              Social Quest show "No data" stubs.

    Shared  — Quests that you and at least one group member share. Shows
              combined progress across all group members for each quest.
              Quests eligible to be shared with a specific member are indicated
              with a "Needs it Shared" marker (only shown when the quest is
              shareable, the member has not completed it, and you have completed
              any prerequisite in the chain).

  Zone sections in the window can be collapsed by clicking the zone header.
  Collapsed/expanded state and scroll position are saved per-tab per-character.
  Clicking a quest title opens the quest log to that entry (clicking it again
  when it is already shown closes the log).

  The Party tab shows a [Share] button on quests you can share with group
  members who need them. Members who are ineligible show a specific reason
  (e.g. "level too low", "wrong class") instead of a generic label.

  Advanced Filter Language
  -------------------------
  A search bar at the top of the window filters all tabs by quest or chain
  title. Press Enter in the search bar to submit a structured filter expression.
  Active filters appear as dismissible labels. Examples:

    level>=60              — quests at or above level 60
    zone=Elwynn|Deadmines  — quests in Elwynn Forest or Deadmines
    status=incomplete      — quests with unfinished objectives
    type=dungeon           — dungeon quests
    shareable=yes          — quests you can currently share with a party member

  Click the [?] button in the search bar header for the full syntax reference.

  Tooltip Enhancement
  -------------------
  When you hover over a quest in your quest log, Social Quest adds a section
  to the tooltip showing which group members share that quest and their current
  objective progress.

  Follow Notifications
  --------------------
  When you begin auto-following a player, Social Quest can display a banner
  along with a message to their chat log to let them know you are following. 
  When you stop, it prints a follow-stop message to chat. Optionally, 
  Social Quest notifies you in your chat frame when someone begins or 
  stops following you.


  Questie Integration
  --------------------
  If Questie is installed and its quest announcement options are enabled,
  Social Quest automatically suppresses its own duplicate chat announcements
  for the same event type (accepted, abandoned, completed, objective complete)
  to avoid double-posting.  Questie will also be used to retrieve quest chain
  information used for display in the social quest window and banners.

  Minimap Button
  --------------
  A minimap button provides quick access to the quest window. The button can
  be hidden via the minimap icon's right-click menu or by unlocking it from
  the minimap and dragging it to a different position. Its position is saved
  per-profile.


--------------------------------------------------------------------------------
  COMMANDS
--------------------------------------------------------------------------------

  /sq             Toggle the group quest window open or closed.
  /sq config      Open the configuration panel.
  /sq sync        Request a fresh quest snapshot from all group members.

  A key binding is also available under Options → Key Bindings → AddOns →
  Social Quest → "Toggle Social Quest Window".


--------------------------------------------------------------------------------
  CONFIGURATION
--------------------------------------------------------------------------------

Open the configuration panel with /sq config or through the Interface Options
AddOns list.

Settings are stored in a shared profile (SocialQuestDB) — one profile applies
to all your characters by default. Profiles can be managed under the Profiles
tab.

  ============================================================
  GENERAL
  ============================================================

  Enable Social Quest                        (default: ON)
      Master on/off switch for all Social Quest functionality.

  Show received events                      (default: ON)
      Master switch for all incoming banner notifications. When off, no
      banners from group members will appear regardless of per-section
      settings.

  Colorblind Mode                           (default: OFF)
      Uses colorblind-friendly colors for all banners and UI text. Not needed
      if the game client's own colorblind mode is already enabled.

  Show banners for your own quest events    (default: OFF)
      Enables the "Own Quest Banners" sub-group below.

  --- Own Quest Banners ---
  Controls which of your own quest events show a banner on your screen.
  All default ON when the parent toggle is enabled.

    Accepted           — Banner when you accept a quest.
    Abandoned          — Banner when you abandon a quest.
    Finished           — Banner when all your quest objectives are complete
                         (before turning in).
    Completed          — Banner when you turn in a quest.
    Failed             — Banner when a quest fails.
    Objective Progress — Banner when a quest objective progresses or regresses.
    Objective Complete — Banner when a quest objective reaches its goal.


  ============================================================
  PARTY
  ============================================================

  Enable transmission                       (default: ON)
      Broadcast your quest events to party members via addon comm.

  Show received events                      (default: ON)
      Allow banner notifications from party members (subject to Display
      Events toggles below).

  --- Announce in Chat ---
  Send a message to /party chat when the event occurs.

    Accepted           (default: ON)
    Abandoned          (default: ON)
    Finished           (default: ON)
    Completed          (default: ON)
    Failed             (default: ON)
    Objective Progress (default: ON)  — includes partial progress and regression
    Objective Complete (default: ON)  — objective reached its goal (e.g. 8/8)

  --- Display Events ---
  Show a banner on screen when a party member triggers the event.

    Accepted           (default: ON)
    Abandoned          (default: ON)
    Finished           (default: ON)
    Completed          (default: ON)
    Failed             (default: ON)
    Objective Progress (default: ON)
    Objective Complete (default: ON)


  ============================================================
  RAID
  ============================================================

  Enable transmission                       (default: ON)
      Broadcast your quest events to raid members via addon comm.

  Show received events                      (default: ON)
      Allow banner notifications from raid members.

  Only show notifications from friends      (default: OFF)
      Show banners only from players on your friends list. Suppresses banners
      from strangers in large raids.

  --- Announce in Chat ---
  (Quest events only — objective events are not available for raid chat.)

    Accepted           (default: OFF)
    Abandoned          (default: OFF)
    Finished           (default: OFF)
    Completed          (default: OFF)
    Failed             (default: OFF)

  --- Display Events ---

    Accepted           (default: ON)
    Abandoned          (default: ON)
    Finished           (default: ON)
    Completed          (default: ON)
    Failed             (default: ON)
    Objective Progress (default: ON)
    Objective Complete (default: ON)


  ============================================================
  GUILD
  ============================================================

  Enable chat announcements                 (default: OFF)
      Announce your quest events in /guild chat. Guild members do not need
      Social Quest installed to see these messages.

  --- Announce in Chat ---
  (Quest events only.)

    Accepted           (default: OFF)
    Abandoned          (default: OFF)
    Finished           (default: OFF)
    Completed          (default: OFF)
    Failed             (default: OFF)

  Note: The guild channel does not have a Display Events group — incoming guild
  chat events do not generate banner notifications.


  ============================================================
  BATTLEGROUND
  ============================================================

  Enable transmission                       (default: ON)
      Broadcast your quest events to battleground members via addon comm.

  Show received events                      (default: ON)
      Allow banner notifications from battleground members.

  Only show notifications from friends      (default: OFF)
      Show banners only from friends in the battleground.

  --- Announce in Chat ---

    Accepted           (default: OFF)
    Abandoned          (default: OFF)
    Finished           (default: OFF)
    Completed          (default: OFF)
    Failed             (default: OFF)
    Objective Progress (default: OFF)
    Objective Complete (default: OFF)

  --- Display Events ---

    Accepted           (default: ON)
    Abandoned          (default: ON)
    Finished           (default: ON)
    Completed          (default: ON)
    Failed             (default: ON)
    Objective Progress (default: ON)
    Objective Complete (default: ON)


  ============================================================
  WHISPER FRIENDS
  ============================================================

  Enable whispers to friends                (default: OFF)
      Send your quest events as whispers to online friends.

  Group members only                        (default: OFF)
      Restrict whispers to friends who are currently in your group.

  --- Announce in Chat ---
  (Controls which events are whispered when transmission is enabled.)

    Accepted           (default: ON)
    Abandoned          (default: ON)
    Finished           (default: ON)
    Completed          (default: ON)
    Failed             (default: ON)
    Objective Progress (default: OFF)
    Objective Complete (default: OFF)


  ============================================================
  FOLLOW NOTIFICATIONS
  ============================================================

  Enable follow notifications               (default: ON)
      Enables all follow notification behavior below.

  Announce when you follow someone          (default: ON)
      Whisper the player you begin following to let them know.
      Sends a follow-stop whisper when you stop.

  Announce when followed                    (default: ON)
      Display a local message in your chat frame when another player starts
      or stops following you.


  ============================================================
  DEBUG
  ============================================================

  Enable debug mode                         (default: OFF)
      Print internal debug messages to the chat frame. Useful for diagnosing
      communication issues, event flow, or unexpected behavior. Messages are
      prefixed [SQ] with a category tag.

  Force Resync                              (visible when debug is ON)
      Request a fresh quest snapshot from all current group members.
      Disabled for 30 seconds after each use to prevent spam.

  --- Test Banners and Chat ---
  (Visible when debug is ON)
  Buttons that trigger demo banners and local chat previews for each event
  type, bypassing all display filters. Useful for verifying banner appearance
  and chat formatting without needing another player.

    Test Accepted        — Accepted event demo.
    Test Abandoned       — Abandoned event demo.
    Test Finished        — Finished objectives demo.
    Test Completed       — Turned-in demo.
    Test Failed          — Failed quest demo.
    Test Obj. Progress   — Partial objective progress demo (e.g. 3/8).
    Test Obj. Complete   — Objective completion demo (e.g. 8/8).
    Test Obj. Regression — Objective regression demo (count went backward).
    Test All Finished    — "Everyone has finished" purple banner demo.
    Test Chat Link       — Prints a local chat preview of a quest announcement
                           message. Verify [Quest Name] formatting in the chat
                           frame.
    Test Flight Discovery — Flight path unlock banner using your character's
                            starting city as the demo location.


  ============================================================
  PROFILES
  ============================================================

  Managed via the Profiles tab in the configuration panel (standard AceDB
  profiles). Settings are shared across all characters by default. You can
  create per-character profiles or copy settings between profiles here.


================================================================================
