-- Author      : Thad
-- Create Date : 10/31/2008 7:30:54 PM

local questEventValues = {	accept		=	"Quest accepted",
							abandon		=	"Quest abandoned",
							finish		=	"Quest finished",
							complete	=	"Quest completed",
							progress	=	"Quest progress",
							fail		=	"Quest failed"
						};

local debugPage = {
	debug ={
		type = "toggle",
		name = "Debug mode",
		desc = "Toggles the display of debug messages.",
		order = 10,
		get = function()
				return SocialQuest.db.char.debug.enabled;
			end,
		set = function()
				SocialQuest.db.char.debug.enabled = not SocialQuest.db.char.debug.enabled;
			end
	},
	announceMessages ={
		type = "multiselect",
		name = "Quest events to print",
		desc = "Toggles whether each quest event type will be printed for debug.",
		order = 20,
		values = questEventValues,
		get =	function(t,k) return SocialQuest.db.char.debug.announce[k]; end,
		set =	function(t,k,v) SocialQuest.db.char.debug.announce[k] = v; end
	},
};

local followPage = {
	follow ={
		type = "toggle",
		name = "Enable follow notifications",
		desc = "Toggles the broadcast of follow notifications.",
		order = 10,
		get =	function() return SocialQuest.db.char.follow.enabled; end,
		set =	function() SocialQuest.db.char.follow.enabled = not SocialQuest.db.char.follow.enabled; end
	},
	following ={
		type = "toggle",
		name = "Notify those you follow",
		desc = "Toggles sending of notifications to individuals you follow.",
		order = 20,
		get =	function() return SocialQuest.db.char.follow.announceFollowing; end,
		set =	function() SocialQuest.db.char.follow.announceFollowing = not SocialQuest.db.char.follow.announceFollowing; end
	},
	followed ={
		type = "toggle",
		name = "Receive follow notifications",
		desc = "Toggles receiving of notifications form individuals following you.",
		order = 30,
		get =	function() return SocialQuest.db.char.follow.announceFollowed; end,
		set =	function() SocialQuest.db.char.follow.announceFollowed = not SocialQuest.db.char.follow.announceFollowed; end
	},
};

local partyPage = {
	--NOTE: If this option is toggled off data will neither be transmitted nor printed
	enabled ={
		  type = "toggle",
		  name = "Transmit quest event data while in a party",
		  desc = "Toggles sharing of quest events data when in a party.",
		  order = 10,
		  get = function() return SocialQuest.db.char.party.enabled; end,
		  set = function() SocialQuest.db.char.party.enabled = not SocialQuest.db.char.party.enabled; end
		},
	displayReceivedEvents ={
		  type = "toggle",
		  name = "Display quest events",
		  desc = "Toggles display of received quest events while in a party.",
		  order = 15,
		  get = function() return SocialQuest.db.char.party.displayReceivedEvents; end,
		  set = function() SocialQuest.db.char.party.displayReceivedEvents = not SocialQuest.db.char.party.displayReceivedEvents; end
		},
	announceMessages ={
		type = "multiselect",
		name = "Quest events to announce",
		desc = "Toggles whether each quest event type will be announced in the Party channel",
		order = 20,
		values = questEventValues,
		get =	function(t,k) return SocialQuest.db.char.party.announce[k]; end,
		set =	function(t,k,v) SocialQuest.db.char.party.announce[k] = v; end
	},
};

local raidPage = {
	--NOTE: If this option is toggled off data will neither be transmitted nor printed
	enabled ={
		  type = "toggle",
		  name = "Transmit quest event data while in a raid",
		  desc = "Toggles sharing of quest events when in a raid.",
		  order = 10,
		  get = function() return SocialQuest.db.char.raid.enabled; end,
		  set = function() SocialQuest.db.char.raid.enabled = not SocialQuest.db.char.raid.enabled; end
		},
	displayReceivedEvents ={
		  type = "toggle",
		  name = "Display quest events",
		  desc = "Toggles display of received quest events while in a raid.",
		  order = 15,
		  get = function() return SocialQuest.db.char.raid.displayReceivedEvents; end,
		  set = function() SocialQuest.db.char.raid.displayReceivedEvents = not SocialQuest.db.char.raid.displayReceivedEvents; end
		},
	channelName ={
		type = "select",
		name = "Announce on channel",
		desc = "Sets the channel on which quest event announcements should be broadcast while in a raid.",
		order = 20,
		values =	{	PARTY		=	"Party",
						RAID		=	"Raid"
					},
		get =	function() return SocialQuest.db.char.raid.channelName; end,
		set =	function(t,k) SocialQuest.db.char.raid.channelName = k; end
	},
	announceMessages ={
		type = "multiselect",
		name = "Quest events to announce",
		desc = "Toggles whether each quest event type will be announced in the selected channel",
		order = 30,
		values = questEventValues,
		get =	function(t,k) return SocialQuest.db.char.raid.announce[k]; end,
		set =	function(t,k,v) SocialQuest.db.char.raid.announce[k] = v; end
	},
};

local battlegroundPage = {
	--NOTE: If this option is toggled off data will neither be transmitted nor printed
	enabled ={
		  type = "toggle",
		  name = "Transmit quest event data while in a battleground",
		  desc = "Toggles sharing of quest events when in a battleground.",
		  order = 10,
		  get = function() return SocialQuest.db.char.battleground.enabled; end,
		  set = function() SocialQuest.db.char.battleground.enabled = not SocialQuest.db.char.battleground.enabled; end
		},
	displayReceivedEvents ={
		  type = "toggle",
		  name = "Display quest events",
		  desc = "Toggles display of received quest events while in a battleground.",
		  order = 15,
		  get = function() return SocialQuest.db.char.battleground.displayReceivedEvents; end,
		  set = function() SocialQuest.db.char.battleground.displayReceivedEvents = not SocialQuest.db.char.battleground.displayReceivedEvents; end
		},
	channelName ={
		type = "select",
		name = "Announce on channel",
		desc = "Sets the channel on which quest event announcements should be broadcast while in a battleground.",
		order = 20,
		values =	{	PARTY		=	"Party",
						RAID		=	"Raid",
						BATTLEGROUND=	"Battleground"
					},
		get =	function() return SocialQuest.db.char.battleground.channelName; end,
		set =	function(t,k) SocialQuest.db.char.battleground.channelName = k; end
	},
	announceMessages ={
		type = "multiselect",
		name = "Quest events to announce",
		desc = "Toggles whether each quest event type will be announced in the selected channel",
		order = 30,
		values = questEventValues,
		get =	function(t,k) return SocialQuest.db.char.battleground.announce[k]; end,
		set =	function(t,k,v) SocialQuest.db.char.battleground.announce[k] = v; end
	},
};

local guildPage = {
	--NOTE: If this option is toggled off data will neither be transmitted nor printed
	enabled ={
		  type = "toggle",
		  name = "Transmit on Guild channel",
		  desc = "Toggles sharing of quest events with guild members.",
		  order = 10,
		  get = function() return SocialQuest.db.char.guild.enabled; end,
		  set = function() SocialQuest.db.char.guild.enabled = not SocialQuest.db.char.guild.enabled; end
		},
	announceMessages ={
		type = "multiselect",
		name = "Quest events to announce",
		desc = "Toggles whether each quest event type will be announced in the Guild channel",
		order = 20,
		values = questEventValues,
		get =	function(t,k) return SocialQuest.db.char.guild.announce[k]; end,
		set =	function(t,k,v) SocialQuest.db.char.guild.announce[k] = v; end
	},
local generalPage = {
--[[	neverAutoAcceptEnabled ={
      type = "toggle",
      name = "Never auto accept quests",
      desc = "Toggles auto accepting of quests (usually only the level 1-5 starter zone quests).",
      order = 10,
      get = function() return SocialQuest.db.char.neverAutoAcceptQuests; end,
      set = function() SocialQuest.db.char.neverAutoAcceptQuests = not SocialQuest.db.char.neverAutoAcceptQuests; end
    }]]--
	receiveEnabled ={
      type = "toggle",
      name = "Display quest events",
      desc = "Toggles display of received quest events.",
      order = 10,
      get = function() return SocialQuest.db.char.general.displayReceivedEvents; end,
      set = function() SocialQuest.db.char.general.displayReceivedEvents = not SocialQuest.db.char.general.displayReceivedEvents; end
    },
	receiveAnnouncements ={
		type = "multiselect",
		name = "Quest events to display",
		desc = "Toggles whether each quest event type will be displayed on reciept from other players",
		order = 20,
		values = questEventValues,
		get =	function(t,k) return SocialQuest.db.char.general.receive[k]; end,
		set =	function(t,k,v)	SocialQuest.db.char.general.receive[k] = v; end
	}
};

local options = {
	name = "SocialQuest",
	desc = "SocialQuest Configuration.",
	type = "group",
	args = {
		enabled ={
			type = "toggle",
			name = "Enable SocialQuest",
			desc = "Enables/Disables all features of SocialQuest",
			order = 10,
			get = function() return SocialQuest.db.char.enabled; end,
			set = function()
					SocialQuest.db.char.enabled = not SocialQuest.db.char.enabled;
					if SocialQuest.db.char.enabled and SocialQuest.db.char.custom.enabled then
						SocialQuest:JoinCustomChannel();
					else
						SocialQuest:LeaveCustomChannel();
					end
				  end
		},
		generalMenu = {
			type = "group",
			name = "General configuration",
			desc = "Set general options for SocialQuest.",
			order = 20,
			args = generalPage,
		},
		customMenu = {
			type = "group",
			name = "Custom channel configuration",
			desc = "Set custom channel broadcast options for SocialQuest.",
			order = 30,
			args = customPage,
		},
		guildMenu = {
			type = "group",
			name = "Guild configuration",
			desc = "Set guild options for SocialQuest.",
			order = 40,
			args = guildPage,
		},
		partyMenu = {
			type = "group",
			name = "Party configuration",
			desc = "Set party options for SocialQuest.",
			order = 50,
			args = partyPage,
		},
		raidMenu = {
			type = "group",
			name = "Raid configuration",
			desc = "Set raid options for SocialQuest.",
			order = 60,
			args = raidPage,
		},
		battlegroundMenu = {
			type = "group",
			name = "Battleground configuration",
			desc = "Set battleground options for SocialQuest.",
			order = 70,
			args = battlegroundPage,
		},
		followMenu = {
			type = "group",
			name = "Follow configuration",
			desc = "Set follow options for SocialQuest.",
			order = 80,
			args = followPage,
		},
		debugMenu = {
			type = "group",
			name = "Debug",
			desc = "Debug options.",
			order = -1,
			args = debugPage,
		},
	}
};

LibStub("AceConfig-3.0"):RegisterOptionsTable("SocialQuest", options, "socialquest");
LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("SocialQuest", options);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SocialQuest", "SocialQuest");