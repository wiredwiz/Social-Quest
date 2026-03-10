# SocialQuest - WoW TBC Addon

## Project Overview

**SocialQuest** is a World of Warcraft addon designed to enhance social questing experiences in The Burning Crusade (Anniversary edition). It enables players in parties, raids, and guilds to coordinate quest progress by sharing quest events and displaying group member progress in tooltips.

**Version**: 1.01  
**Interface**: 20505 (TBC Anniversary)  
**Author**: Thad Ryker  
**Status**: Active, recently updated from Wrath of the Lich King compatibility

## Core Functionality

### Quest Event Sharing
- **Automatic Announcements**: Broadcasts quest events (accept, complete, turn-in, abandon, fail) to group chat channels
- **Channels Supported**:
  - Party (when in party)
  - Raid (when in raid)
  - Guild (when in guild)
  - Battleground (when in battleground)
- **Rate Limiting**: 1-second cooldown between announcements to prevent spam/bot detection

### Group Progress Tracking
- **Tooltip Integration**: Shows party members' quest progress in quest tooltips
- **Real-time Sync**: Shares quest data between group members via addon communication
- **Completion Alerts**: Displays banner notifications when entire group completes quests

### Follow System
- **Auto-follow Notifications**: Alerts when players start/stop following each other
- **Whisper Integration**: Sends follow status updates via whispers

## Architecture

### Files Structure
```
SocialQuest/
├── SocialQuest.toc          # Addon manifest
├── SocialQuest.lua          # Core addon logic
├── SocialQuest.options.lua  # Configuration UI
├── Colors.lua              # Color definitions
└── claude.md              # This documentation
```

### Key Components

#### Core Systems
- **Event Handling**: Uses Ace3 EventSystem for WoW events (QUEST_ACCEPTED, QUEST_COMPLETE, etc.)
- **Communication**: AceComm for inter-player data sharing
- **Configuration**: AceDB for per-character settings
- **UI**: AceConfig for options panel

#### Quest Tracking
- **Data Source**: C_QuestLog API (TBC built-in)
- **Storage**: Local tables for quest states and objectives
- **Sync**: Serialized quest data via addon channels

#### UI Elements
- **Tooltips**: Enhanced quest tooltips with group progress
- **Banners**: RaidWarningFrame for large notifications
- **Chat**: Integrated with WoW chat system

## Dependencies

### Required
- **Ace3**: Comprehensive addon framework (AceAddon, AceEvent, AceComm, AceDB, AceConfig, AceSerializer)
  - Repository: https://github.com/WoWUIDev/Ace3
  - Status: Compatible with TBC Anniversary

### Removed (Replaced with Built-ins)
- ~~AbsoluteQuestLog~~: Replaced with C_QuestLog APIs
- ~~Sea~~: Replaced with RaidWarningFrame for banners

## Development Status

### Completed Updates (v1.01)
- ✅ TBC Anniversary compatibility (Interface 20505)
- ✅ Replaced deprecated APIs (GetNumGroupMembers, GROUP_ROSTER_UPDATE, etc.)
- ✅ Removed unavailable dependencies (AbsoluteQuestLog, Sea)
- ✅ Implemented rate limiting for bot detection prevention
- ✅ Updated quest tracking to use C_QuestLog
- ✅ Modernized color handling (_G[] instead of getglobal)
- ✅ Removed custom channel support (APIs unavailable in TBC)

### Current Features
- Quest event announcements in group channels
- Group quest progress in tooltips
- On-screen completion notifications
- Follow system notifications
- Comprehensive configuration options
- Debug logging

### Known Limitations
- No custom channel support (removed due to API changes)
- No quest history tracking (removed for simplicity)
- Progress announcements disabled (too spammy)
- Only active quest tooltips enhanced

## Configuration Options

### General Settings
- Enable/disable addon
- Display received quest events
- Receive event types (accept, complete, finish, abandon, fail)

### Channel-Specific Settings
- **Party**: Enable transmission, display events, announce types
- **Raid**: Enable transmission, display events, channel selection (Party/Raid), announce types
- **Guild**: Enable transmission, announce types
- **Battleground**: Enable transmission, display events, announce types

### Follow Settings
- Enable follow notifications
- Announce following/followed status

### Debug
- Enable debug mode
- Debug event types

## Future Development Plans

### High Priority
- Test in TBC Anniversary client
- Verify quest sharing works correctly
- Optimize data transmission size
- Add more granular rate limiting options

### Medium Priority
- Add banner customization options (size, color overrides)
- Implement quest progress sharing (currently disabled)
- Add sound alerts for important events
- Improve tooltip formatting

### Low Priority
- Add localization support
- Create minimap icon
- Add slash command help
- Implement quest history tracking (if feasible)

### Potential Enhancements
- Integration with other quest addons
- Custom sound effects
- Advanced filtering options
- Performance optimizations

## Technical Notes

### API Usage
- **C_QuestLog**: GetInfo(), GetQuestObjectives(), GetTitleForQuestID()
- **Ace3 Libraries**: Event handling, configuration, communication
- **WoW Events**: QUEST_ACCEPTED, QUEST_COMPLETE, QUEST_TURNED_IN, QUEST_FAILED, QUEST_REMOVED
- **UI Frames**: RaidWarningFrame, ItemRefTooltip

### Data Structures
```lua
-- Quest Data Format
{
    title = "Quest Name",
    id = 12345,
    complete = true/false,
    objectives = {
        {text = "Kill 5 mobs", finished = true, numFulfilled = 5, numRequired = 5},
        ...
    }
}
```

### Communication Protocol
- **Prefixes**: SQ_ANNOUNCE_UPDATE, SQ_ANNOUNCE_INIT, SQ_REQUEST, SQ_FOLLOWED_START, SQ_FOLLOWED_STOP
- **Channels**: PARTY, RAID, GUILD (group-dependent)
- **Data**: Serialized quest tables via AceSerializer

## Testing Checklist

### Basic Functionality
- [ ] Addon loads without errors
- [ ] Options panel accessible
- [ ] Quest acceptance announced in party
- [ ] Quest completion announced
- [ ] Tooltips show group progress

### Advanced Features
- [ ] Data sync between party members
- [ ] Rate limiting prevents spam
- [ ] Banner notifications display correctly
- [ ] Follow notifications work
- [ ] Guild/raid announcements function

### Edge Cases
- [ ] Solo play (no announcements)
- [ ] Large raids (performance)
- [ ] Multiple quests active
- [ ] Quest sharing with offline players

## Recent Changes

### Version 1.01 (March 2026)
- Updated for TBC Anniversary compatibility
- Replaced AbsoluteQuestLog with C_QuestLog APIs
- Added rate limiting for bot detection prevention
- Removed custom channel support
- Replaced Sea banners with RaidWarningFrame
- Modernized deprecated API calls
- Updated interface version to 20505

### Version 1.00 (Original)
- Initial release for Wrath of the Lich King
- Full quest event sharing system
- Custom channel support
- AbsoluteQuestLog integration
- Sea library banners

## Maintenance Notes

### Updating Dependencies
- Ace3: Check https://github.com/WoWUIDev/Ace3 for updates
- Monitor WoW API changes for future patches

### Code Style
- Uses Ace3 conventions
- Lua 5.1 compatible (WoW's Lua version)
- Consistent naming and structure

### Debugging
- Enable debug mode in options
- Check chat for error messages
- Use `/socialquest` slash command

---

*This document should be updated whenever significant changes are made to the project. Keep sections organized and use consistent formatting for easy maintenance.*