SocialQuest = LibStub("AceAddon-3.0"):NewAddon("SocialQuest", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0");

SQ_TITLE_COLOR="|cFF6464F0";
SQ_VERSION="1.00";

local SQ_ANNOUNCE_UPDATE = "SQ_ANN_UPDATE";
local SQ_ANNOUNCE_INIT = "SQ_ANN_INIT";
local SQ_REQUEST = "SQ_REQ";
local SQ_FOLLOWED_START = "SQ_FOLLOWED_START";
local SQ_FOLLOWED_STOP = "SQ_FOLLOWED_STOP";

local defaults = {};
defaults.char = {};
defaults.char.enabled = true;
defaults.char.neverAutoAcceptQuests = false;
defaults.char.custom = {};
defaults.char.custom.enabled = false;
defaults.char.custom.channelName = "GenericSQ";
defaults.char.custom.password = nil;
defaults.char.custom.announce = {	accept = true,
									abandon = true,
									finish = true,
									complete = true,
									progress = true,
									fail = true
								};
defaults.char.general = {};
defaults.char.general.displayReceivedEvents  = true;
defaults.char.general.receive = {	accept = true,
									abandon = true,
									finish = true,
									complete = true,
									progress = true,
									fail = true
								};
defaults.char.guild = {};
defaults.char.guild.enabled = false;
defaults.char.guild.announce = {	accept = true,
									abandon = true,
									finish = true,
									complete = true,
									progress = true,
									fail = true
								};
defaults.char.party = {};
defaults.char.party.enabled = true;
defaults.char.party.displayReceivedEvents = true;
defaults.char.party.announce = {	accept = true,
									abandon = true,
									finish = true,
									complete = true,
									progress = true,
									fail = true
								};
defaults.char.raid = {};
defaults.char.raid.enabled = false;
defaults.char.raid.displayReceivedEvents = false;
defaults.char.raid.channelName = "RAID";
defaults.char.raid.announce = {	accept = true,
									abandon = true,
									finish = true,
									complete = true,
									progress = true,
									fail = true
								};
defaults.char.battleground = {};
defaults.char.battleground.enabled = false;
defaults.char.battleground.displayReceivedEvents = false;
defaults.char.battleground.channelName = "BATTLEGROUND";
defaults.char.battleground.announce = {	accept = true,
											abandon = true,
											finish = true,
											complete = true,
											progress = true,
											fail = true
										};
defaults.char.debug = {};
defaults.char.debug.enabled = false;
defaults.char.debug.announce = {	accept = true,
									abandon = true,
									finish = true,
									complete = true,
									progress = true,
									fail = true
								};
defaults.char.follow = {};
defaults.char.follow.enabled = true;
defaults.char.follow.announceFollowing = true;
defaults.char.follow.announceFollowed = true;

local function IsInRaid()
	return (GetNumRaidMembers() ~= 0);
end

local function IsInParty()
	return (GetNumPartyMembers() ~= 0);
end

local function IsInBG()
	return UnitInBattleground("player");
end

local function ChannelExists(channel)
	local index = GetChannelName(channel);
	return (index ~= 0);
end

local function GetChannelToUse()
	local channelUsed;
	if IsInBG() then
		channelUsed = defaults.char.battleground.channelName;
	elseif IsInRaid() then
		channelUsed = defaults.char.raid.channelName;
	elseif IsInParty() then
		channelUsed = "PARTY";
	else
		channelUsed = nil;
	end
	return channelUsed;
end

local function StandardSendOK(e)
	return (SocialQuest.db.char.enabled and
			(((IsInRaid() and SocialQuest.db.char.raid.enabled) and (not (e) or SocialQuest.db.char.raid.announce[e])) or
			((IsInBG() and SocialQuest.db.char.battleground.enabled) and (not (e) or SocialQuest.db.char.battleground.announce[e])) or
			((IsInParty() and SocialQuest.db.char.party.enabled) and (not (e) or SocialQuest.db.char.party.announce[e]))));
end

local function GuildSendOK(e)
	return (SocialQuest.db.char.enabled and
			((IsInGuild() and SocialQuest.db.char.guild.enabled) and (not (e) or SocialQuest.db.char.guild.announce[e])));
end

local function CustomSendOK(e)
	return (SocialQuest.db.char.enabled and
			(SocialQuest.db.char.custom.enabled and (not (e) or SocialQuest.db.char.custom.announce[e])));
end

local function SQ_SendChatMessage(...)
	local message, type = ...;
	if StandardSendOK(type) then
		SendChatMessage(message,GetChannelToUse());
	end
	if GuildSendOK(type) then
		SendChatMessage(message,"GUILD");
	end
	if CustomSendOK(type) then
		local id,name = GetChannelName(SocialQuest.db.char.custom.channelName);
		if (name) then
			SendChatMessage(message,"CHANNEL",nil,tostring(id));
		end
	end
end

local function SQ_PrintDebugData(...)
	local message, type = ...;
	if (SocialQuest.db.char.enabled and (SocialQuest.db.char.debug.enabled and (not (type) or SocialQuest.db.char.debug.announce[type]))) then
		SocialQuest:Print("Debug::"..message);
	end
end

local function GetGlobalName(pName,pRealm)
	if (pRealm) then
		pName = pName.."-"..pRealm;
	end
	return pName;
end

local function GetGlobalDisplayName(friendName,friendRealm)
	local nameTemplate = "%s";
	if IsInBG() then
		nameTemplate = nameTemplate.."<%s>";
	end
	return string.format(nameTemplate,friendName,friendRealm);
end

local function EveryoneHasFinished(questName)	
	local maxGroupNum,unitText;
	if IsInRaid() then
		maxGroupNum = GetNumRaidMembers();
		unitText = "raid";
	elseif IsInParty() then
		maxGroupNum = GetNumPartyMembers();
		unitText = "party";
	else
		return true;
	end
	if (not AbsoluteQuestLog.Quests) then
		return false;
	end
	questData = AbsoluteQuestLog.Quests[questName];
	if (questData) then
		if (questData.complete ~= 1) then
			return false;
		end
	end
	for i=1,maxGroupNum do
		if (GetUnitName("player") ~= GetUnitName(unitText..i)) then
			local pName,pRealm = UnitName(unitText..i);
			questTree = SocialQuest.PlayerQuests[GetGlobalName(pName,pRealm)];
			if (questTree) then
				questData = questTree[questName];
				if (questData) then
					if (questData.complete ~= 1) then
						return false;
					end
				end
			else
				return false;
			end
		end
	end
	return true;
end

local function trim(s)
	if (not s) then
		return s;
	end
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"));
end


function SocialQuest:QuestUpdate(updateType,...)
	local questInfo, objective = ...;	
	local playerName,playerRealm = UnitName("player");
	local channelName = GetChannelToUse();
	if (SocialQuest.db.char.enabled) and
		((IsInParty() and (SocialQuest.db.char.party.enabled)) or
		(IsInRaid() and (SocialQuest.db.char.raid.enabled)) or
		(IsInBG() and (SocialQuest.db.char.battleground.enabled)))
	then
		local updateMessage = "";
		if (objective) then
			updateMessage = objective.text;
		end
		local updateData = SocialQuest:Serialize(updateType,questInfo.cleanTitle,questInfo.link,updateMessage,questInfo,channelName);
		SocialQuest:SendCommMessage(SQ_ANNOUNCE_UPDATE, updateData, channelName);
		SocialQuest.LastUpdate = updateData;
		SQ_PrintDebugData('Quest update comm message sent');
	end
	if updateType == AbsoluteQuestLog.AQ_QUEST_COMPLETED then
		SQ_SendChatMessage("turned in quest "..questInfo.link,"complete");
		SQ_PrintDebugData("turned in quest "..questInfo.link,"complete");
	elseif updateType == AbsoluteQuestLog.AQ_QUEST_PROGRESS_UPDATED then
		SQ_SendChatMessage(questInfo.link.." "..objective.text,"progress");
		SQ_PrintDebugData(questInfo.link.." "..objective.text,"progress");
	elseif updateType == AbsoluteQuestLog.AQ_QUEST_ABANDONED then
		SQ_SendChatMessage("abandoned quest "..questInfo.link,"abandon");
		SQ_PrintDebugData("abandoned quest "..questInfo.link,"abandon");
	elseif updateType == AbsoluteQuestLog.AQ_QUEST_ACCEPTED then
		SQ_SendChatMessage("accepted quest "..questInfo.link,"accept");
		SQ_PrintDebugData("accepted quest "..questInfo.link,"accept");
	elseif updateType == AbsoluteQuestLog.AQ_QUEST_FAILED then
		SQ_SendChatMessage("failed quest "..questInfo.link,"fail");
		SQ_PrintDebugData("failed quest "..questInfo.link,"fail");
	elseif updateType == AbsoluteQuestLog.AQ_QUEST_FINISHED then
		SQ_SendChatMessage("completed quest "..questInfo.link,"finish");
		if (IsInParty() or IsInRaid()) and EveryoneHasFinished(questInfo.cleanTitle) then
			Sea.io.bannerc(PURPLE_FONT_COLOR,"Everyone has completed "..questInfo.cleanTitle);
		end
		SQ_PrintDebugData("completed quest "..questInfo.link,"finish");
	end
end

function SocialQuest:InsertIntoQuestTooltip(toolTip,lineNumber,text,...)
	local color,wordWrap = ...;
	local lineCount = toolTip:NumLines();
	local lines,colors,wordWraps = {},{},{};
	local lineColor = {};
	if (not color) then
		color = WHITE_FONT_COLOR;
	end
	for i=1,lineCount do
		lineColor = {}
		table.insert(lines,_G["ItemRefTooltipTextLeft"..i]:GetText());
		lineColor.r, lineColor.g, lineColor.b = _G["ItemRefTooltipTextLeft"..i]:GetTextColor();
		table.insert(colors,lineColor);
		table.insert(wordWraps,_G["ItemRefTooltipTextLeft"..i]:CanWordWrap());
	end
	if (lineNumber <= lineCount) then
		table.insert(lines,lineNumber,text);
		table.insert(colors,lineNumber,color);
		table.insert(wordWraps,lineNumber,wordWrap);
	else
		table.insert(lines,text);
		table.insert(colors,color);
		table.insert(wordWraps,wordWrap);
	end
	toolTip:ClearLines();
	for i=1,#lines do
		color = colors[i];
		toolTip:AddLine(lines[i],color.r,color.g,color.b,wordWraps[i]);
	end
	toolTip:Show();
end

function SocialQuest:CreateQuestTooltip(toolTip,uniqueID)
	if (not uniqueID) then
		return nil;
	end
	local questInfo = AbsoluteQuestLog:GetQuestHistory(uniqueID);
	local isOnQuest = false;
	local hasCompletedQuest = AbsoluteQuestLog:HasCompletedQuest(uniqueID);
	
	if (not questInfo) then
		if hasCompletedQuest then
			-- we have history with no detail so we should just augment the existing tip
			SocialQuest:InsertIntoQuestTooltip(toolTip,2,"You have completed this quest",RED_FONT_COLOR)
			return nil;
		else
			-- we know nothing of this quest, let wow do what it normally does
			return nil;
		end
	end
	
	local liveQuestInfo = AbsoluteQuestLog:GetQuestByID(uniqueID);

	if (liveQuestInfo) then
		isOnQuest = true;
	end
	
	-- Now we build a tooltip from what we know of the quest
	toolTip:ClearLines();
	toolTip:AddLine(questInfo.cleanTitle,GOLD_FONT_COLOR.r,GOLD_FONT_COLOR.g,GOLD_FONT_COLOR.b);
	if (isOnQuest) then
		if (liveQuestInfo.complete) then
			toolTip:AddLine("You need to turn in this quest",ROYALBLUE_FONT_COLOR.r,ROYALBLUE_FONT_COLOR.g,ROYALBLUE_FONT_COLOR.b);
		else
			toolTip:AddLine("You are on this quest",GREEN_FONT_COLOR.r,GREEN_FONT_COLOR.g,GREEN_FONT_COLOR.b);
		end
	elseif (hasCompletedQuest) then
		toolTip:AddLine("You have completed this quest",RED_FONT_COLOR.r,RED_FONT_COLOR.g,RED_FONT_COLOR.b);
	end
	toolTip:AddLine(" ");
	toolTip:AddLine(questInfo.objective,1,1,1,1);
	
	local objectives = questInfo.objectives;
	if (isOnQuest) then
		objectives = liveQuestInfo.objectives;
	end
	if (objectives) and (#objectives > 0) then
		toolTip:AddLine(" ");
		toolTip:AddLine("Requirements:",GOLD_FONT_COLOR.r,GOLD_FONT_COLOR.g,GOLD_FONT_COLOR.b);
		for i=1,#objectives do
			objective = objectives[i];
			local color = WHITE_FONT_COLOR;
			-- print this player's progress if we can
			if (isOnQuest) then
				if (objective.finished) then
					color = ROYALBLUE_FONT_COLOR;
				end
				if (trim(objective.info.name) ~= "") then
					toolTip:AddLine(" - "..objective.info.name.." ("..objective.info.done.."/"..objective.info.total..")",color.r,color.g,color.b);
				else
					toolTip:AddLine(" - "..objective.text,color.r,color.g,color.b);
				end
			else
				if (trim(objective.info.name) ~= "") then
					toolTip:AddLine(" - "..objective.info.name.." x "..objective.info.total,color.r,color.g,color.b);
				else
					toolTip:AddLine(" - "..objective.text,color.r,color.g,color.b);
				end
			end
			-- now scan other party members with SocialQuest data and integrate it
			local partySize = GetNumPartyMembers();
			if (partySize ~= 0) then
				for p=1,partySize do
					local pName,pRealm = UnitName("party"..p);
					local person = GetGlobalName(pName,pRealm);
					questData = SocialQuest.PlayerQuests[person];
					-- do we have a quest log for this party member
					if (questData) then
						local pQuestInfo = questData[questInfo.cleanTitle];
						-- now that we have the party member's quest log, do they have an entry for this quest?
						if (pQuestInfo) then
							local pObjective = pQuestInfo.objectives[i];
							-- did this give us a valid objective and does it appear to match ours
							if (pObjective) and (pObjective.text == objective.text) then
								-- now print that player's progress
								if (pObjective.finished) then
									color = ROYALBLUE_FONT_COLOR;
								else
									color = WHITE_FONT_COLOR;
								end
								if (trim(pObjective.info.name) ~= "") then
									toolTip:AddLine("   * "..person.." ("..pObjective.info.done.."/"..pObjective.info.total..")",color.r,color.g,color.b);
								else
									local qualifier = " X";
									if (pObjective.finished) then
										qualifier = " (done)";
									end
									toolTip:AddLine("   * "..person..qualifier,color.r,color.g,color.b);
								end				
							end
						end
					end
				end
			end
		end
	end
	toolTip:Show();
end

function SocialQuest:SetHyperlink(...)
	local toolTip, hyperLink = ...;	
	local uniqueID = AbsoluteQuestLog:GetUniqueIDFromLink(hyperLink);
	SocialQuest:CreateQuestTooltip(toolTip,uniqueID);
end

function SocialQuest:OnInitialize()
    -- Called when the addon is loaded
    SocialQuest.db = LibStub("AceDB-3.0"):New("SOCIALQUEST_CONFIG", defaults);
    SocialQuest:Print(SQ_TITLE_COLOR.." v"..SQ_VERSION.." loaded.|r");
    SocialQuest.PlayerQuests = {};
    SocialQuest.LastUpdate = nil;
    SocialQuest.options = {};    
    SocialQuest.CurrentFollowed = nil;
end

function SocialQuest:OnEnable()
	-- Called when the addon is enabled
	SocialQuest:RegisterComm(SQ_ANNOUNCE_UPDATE);
	SocialQuest:RegisterComm(SQ_ANNOUNCE_INIT);
	SocialQuest:RegisterComm(SQ_FOLLOWED_START);
	SocialQuest:RegisterComm(SQ_FOLLOWED_STOP);
	SocialQuest:RegisterComm(SQ_REQUEST);
	SocialQuest:RegisterEvent("PARTY_MEMBERS_CHANGED");
	SocialQuest:RegisterEvent("AUTOFOLLOW_BEGIN");
	SocialQuest:RegisterEvent("AUTOFOLLOW_END");
	SocialQuest:RegisterMessage(AbsoluteQuestLog.AQ_QUEST_COMPLETED,"QuestUpdate");
	SocialQuest:RegisterMessage(AbsoluteQuestLog.AQ_QUEST_PROGRESS_UPDATED,"QuestUpdate");
	SocialQuest:RegisterMessage(AbsoluteQuestLog.AQ_QUEST_ABANDONED,"QuestUpdate");
	SocialQuest:RegisterMessage(AbsoluteQuestLog.AQ_QUEST_ACCEPTED,"QuestUpdate");
	SocialQuest:RegisterMessage(AbsoluteQuestLog.AQ_QUEST_FAILED,"QuestUpdate");
	SocialQuest:RegisterMessage(AbsoluteQuestLog.AQ_QUEST_FINISHED,"QuestUpdate");
	SocialQuest:SecureHook(ItemRefTooltip,"SetHyperlink");
	--SocialQuest:RawHook("QuestGetAutoAccept",true);
	local channel = GetChannelToUse();
	-- Lets populate AbsoluteQuestLog with all the quests in our log, in case any are missing
	for title,questInfo in pairs(AbsoluteQuestLog.Quests) do
		AbsoluteQuestLog:AddQuestHistory(questInfo);
	end
	if (channel) then
		local updateData = SocialQuest:Serialize(AbsoluteQuestLog.Quests);
		SocialQuest:SendCommMessage(SQ_ANNOUNCE_INIT, updateData, GetChannelToUse());
		SQ_PrintDebugData('Quest init comm message sent');
	end
end

function SocialQuest:OnDisable()
    -- Called when the addon is disabled
    SocialQuest:UnregisterComm(SQ_ANNOUNCE_UPDATE);
    SocialQuest:UnregisterComm(SQ_ANNOUNCE_INIT);
    SocialQuest:UnregisterComm(SQ_FOLLOWED_START);
    SocialQuest:UnregisterComm(SQ_FOLLOWED_STOP);
    SocialQuest:UnregisterComm(SQ_REQUEST);
    SocialQuest:UnregisterEvent("PARTY_MEMBERS_CHANGED");
    SocialQuest:UnregisterEvent("AUTOFOLLOW_BEGIN");
	SocialQuest:UnregisterEvent("AUTOFOLLOW_END");
	SocialQuest:UnregisterMessage(AbsoluteQuestLog.AQ_QUEST_COMPLETED);
	SocialQuest:UnregisterMessage(AbsoluteQuestLog.AQ_QUEST_PROGRESS_UPDATED);
	SocialQuest:UnregisterMessage(AbsoluteQuestLog.AQ_QUEST_ABANDONED);
	SocialQuest:UnregisterMessage(AbsoluteQuestLog.AQ_QUEST_ACCEPTED);
	SocialQuest:UnregisterMessage(AbsoluteQuestLog.AQ_QUEST_FAILED);
	SocialQuest:UnregisterMessage(AbsoluteQuestLog.AQ_QUEST_FINISHED);
	SocialQuest:UnHook(ItemRefTooltip,"SetHyperlink");
	--SocialQuest:UnHook("QuestGetAutoAccept");
end


function SocialQuest:OnCommReceived(prefix, message, distribution, sender)
    -- process the incoming message
	
	local sName,sRealm = strsplit("-",sender);        
    if sender ~= UnitName("player") then
		if prefix == SQ_FOLLOWED_START then
			if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.follow.enabled) and (SocialQuest.db.char.follow.announceFollowed) then
				Sea.io.bannerc(GREEN_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has started following you");
			end
		elseif prefix == SQ_FOLLOWED_STOP then
			if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.follow.enabled) and (SocialQuest.db.char.follow.announceFollowed) then
				Sea.io.bannerc(RED_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has stopped following you");
			end
		elseif prefix == SQ_ANNOUNCE_INIT then
			local success,allQuestData = SocialQuest:Deserialize(message);
			if not success then
				-- corrupted data, request a refresh
				--SocialQuest:SendCommMessage(SQ_REQUEST, '', "WHISPER", sender);
				SocialQuest:Print('Error parsing quest initialization from '..sender);
				return;
			end
			SocialQuest.PlayerQuests[sender] = allQuestData;
			for title,questInfo in pairs(allQuestData) do
				AbsoluteQuestLog:AddQuestHistory(questInfo);
			end
			SQ_PrintDebugData('Quest init received from '..sender);
		elseif prefix == SQ_REQUEST then
			SQ_PrintDebugData('Quest init requested from '..sender);
			local updateData = SocialQuest:Serialize(AbsoluteQuestLog.Quests);
			SocialQuest:SendCommMessage(SQ_ANNOUNCE_INIT, updateData, "WHISPER", sender);
			SQ_PrintDebugData('Quest init comm message sent to '..sender);
			if (SocialQuest.LastUpdate ~= nil) then
				SocialQuest:SendCommMessage(SQ_ANNOUNCE_UPDATE, SocialQuest.LastUpdate, "WHISPER", sender);
				SQ_PrintDebugData('Quest update comm message sent to '..sender);
			end
		elseif prefix == SQ_ANNOUNCE_UPDATE then
			local success,updateType,questName,questLink,progressText,questData,source = SocialQuest:Deserialize(message);
			if not success then
				-- corrupted data, request a refresh
				SocialQuest:SendCommMessage(SQ_REQUEST, '', "WHISPER", sender);
				SocialQuest:Print('Error parsing quest update');
				return;
			end
			if SocialQuest.PlayerQuests[sender] == nil then
				SocialQuest:SendCommMessage(SQ_REQUEST, '', "WHISPER", sender);
				SQ_PrintDebugData('Quest init request sent to '..sender..' (no questlog data)');
				return;
			end
			SQ_PrintDebugData('Quest update received from '..sender);
			SocialQuest.PlayerQuests[sender][questName] = questData;
			if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.general.displayReceivedEvents) and
				(IsInParty() and (SocialQuest.db.char.party.displayReceivedEvents)) or
				(IsInRaid() and (SocialQuest.db.char.raid.displayReceivedEvents)) or
				(IsInBG() and (SocialQuest.db.char.battleground.displayReceivedEvents))
			then
				if updateType == AbsoluteQuestLog.AQ_QUEST_COMPLETED then
					if (SocialQuest.db.char.general.receive["complete"]) then
						Sea.io.bannerc(BLUE_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has turned in "..questName);
					end
				elseif updateType == AbsoluteQuestLog.AQ_QUEST_PROGRESS_UPDATED then
					if (SocialQuest.db.char.general.receive["progress"]) then
						Sea.io.bannerc(GREEN_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).."'s objectives:\r",progressText);
					end
				elseif updateType == AbsoluteQuestLog.AQ_QUEST_ABANDONED then
					if (SocialQuest.db.char.general.receive["abandon"]) then
						Sea.io.bannerc(RED_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has abandoned "..questName);
					end
				elseif updateType == AbsoluteQuestLog.AQ_QUEST_ACCEPTED then
					if (SocialQuest.db.char.general.receive["accept"]) then
						Sea.io.bannerc(YELLOW_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has accepted "..questName);
					end
				elseif updateType == AbsoluteQuestLog.AQ_QUEST_FAILED then
					if (SocialQuest.db.char.general.receive["fail"]) then
						Sea.io.bannerc(RED_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has failed "..questName);
					end
				elseif updateType == AbsoluteQuestLog.AQ_QUEST_FINISHED then
					if (SocialQuest.db.char.general.receive["finish"]) then
						Sea.io.bannerc(GREEN_FONT_COLOR,GetGlobalDisplayName(sName,sRealm).." has completed "..questName);
						if EveryoneHasFinished(questName) then
							Sea.io.bannerc(PURPLE_FONT_COLOR,"Everyone has completed "..questName);
						end
					end
				end
			end
		end
    end
end

function SocialQuest:GetSharedMembers()
	numEntries = GetNumQuestLogEntries();
	shared = {};
	if GetNumPartyMembers() ~= 0 then
		numMembers = GetNumPartyMembers();
		for j = 1, numMembers, 1 do
			if IsUnitOnQuest(GetQuestLogSelection(),"party"..j) then
				uName = UnitName("party"..j);
				table.insert(shared,uName);
			end	
		end
	elseif GetNumRaidMembers() ~= 0 then
		numMembers = GetNumRaidMembers();
		for j = 1, numMembers, 1 do
			if IsUnitOnQuest(GetQuestLogSelection(),"raid"..j) then
				uName = UnitName("raid"..j);
				table.insert(shared,uName);
			end	
		end
	else
		return nil;
	end
	if #shared > 0 then
		names = shared[1];
		for i=2,#shared,1 do
			if not (shared[j] == nil) then
				names = names ..", "..shared[j];
			end
		end
		return names;
	else
		return "none";
	end
end

-- for direct function hooks
--function SocialQuest:GetQuestLogQuestText()
  ---- call the original function through the self.hooks table
  --local questText, questObjectives = self.hooks["GetQuestLogQuestText"]();
  --if (SocialQuest.db.char.enabled) then
	  --local shared = SocialQuest:GetSharedMembers();
	  --if shared ~= nil then
		--questText = questText .. "\r\r"..PURPLE_FONT_COLOR_CODE.."Party members who share this quest: "..FONT_COLOR_CODE_CLOSE..shared;
	  --end
  --end
  --questObjectives = questObjectives .. "\r\rTesting";
  --return questText, questObjectives;
--end

function SocialQuest:QuestGetAutoAccept()
	if (SocialQuest.db.char.neverAutoAcceptQuests) then
		return nil;
	else
		self.hooks.QuestGetAutoAccept();
	end
end

function SocialQuest:PARTY_MEMBERS_CHANGED(eventName)
    -- update the other party/raid members or clean up
    local channel = GetChannelToUse();
    if not (channel) then
		-- flush party quest data
		SocialQuest.PlayerQuests = {};
		collectgarbage(); -- clean up just for the sake of being tidy
		return;
    end
	if StandardSendOK() then
		local updateData = SocialQuest:Serialize(AbsoluteQuestLog.Quests);
		SocialQuest:SendCommMessage(SQ_ANNOUNCE_INIT, updateData, channel);
		SQ_PrintDebugData('Quest init comm message sent');
	end
end

function SocialQuest:AUTOFOLLOW_BEGIN(...)
	-- args1 = unit
	eventName,unit = ...;
	SocialQuest.CurrentFollowed = unit;
	if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.follow.enabled) and (SocialQuest.db.char.follow.announceFollowing) then
		SocialQuest:SendCommMessage(SQ_FOLLOWED_START, '', "WHISPER", SocialQuest.CurrentFollowed);
	end
end

function SocialQuest:AUTOFOLLOW_END(...)
	-- no args
	if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.follow.enabled) and (SocialQuest.db.char.follow.announceFollowing) and not (SocialQuest.CurrentFollowed == nil) then
		SocialQuest:SendCommMessage(SQ_FOLLOWED_STOP, '', "WHISPER", SocialQuest.CurrentFollowed);
	end
	SocialQuest.CurrentFollowed = nil;
end

function SocialQuest:JoinCustomChannel()
	if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.custom.enabled) then
		JoinPermanentChannel(SocialQuest.db.char.custom.channelName,SocialQuest.db.char.custom.password,DEFAULT_CHAT_FRAME:GetID(),1);
	end
end

function SocialQuest:LeaveCustomChannel()
	LeaveChannelByName(SocialQuest.db.char.custom.channelName);
end