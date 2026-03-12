SocialQuest = LibStub("AceAddon-3.0"):NewAddon("SocialQuest", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0");

SQ_TITLE_COLOR="|cFF6464F0";
SQ_VERSION="1.00";

local SQ_ANNOUNCE_UPDATE = "SQ_ANN_UPDATE";
local SQ_ANNOUNCE_INIT = "SQ_ANN_INIT";
local SQ_REQUEST = "SQ_REQ";
local SQ_FOLLOWED_START = "SQ_FOLLOWED_START";
local SQ_FOLLOWED_STOP = "SQ_FOLLOWED_STOP";

local AQ_QUEST_COMPLETED = "complete";
local AQ_QUEST_PROGRESS_UPDATED = "progress";
local AQ_QUEST_ABANDONED = "abandon";
local AQ_QUEST_ACCEPTED = "accept";
local AQ_QUEST_FAILED = "fail";
local AQ_QUEST_FINISHED = "finish";

local lastChatSend = 0;
local SQ_MessageQueue = {};
local SQ_QueueTimer = nil;
local SQ_MAX_QUEUE_SIZE = 100;

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
	return (GetNumGroupMembers() > 1 and UnitInRaid("player"));
end

local function IsInParty()
	return (GetNumGroupMembers() > 0 and not UnitInRaid("player"));
end

local function IsInBG()
	return UnitInBattleground("player");
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
			((GetGuildInfo() ~= nil and SocialQuest.db.char.guild.enabled) and (not (e) or SocialQuest.db.char.guild.announce[e])));
end

local function SQ_SendChatMessage(...)
	local message, type = ...;
	-- Check for duplicate messages in queue
	for _, queuedMsg in ipairs(SQ_MessageQueue) do
		if queuedMsg.message == message and queuedMsg.type == type then
			return; -- Duplicate, skip
		end
	end
	-- Check queue size
	if #SQ_MessageQueue >= SQ_MAX_QUEUE_SIZE then
		SocialQuest:Print("SocialQuest: Message queue full (100 messages), dropping further messages.");
		return;
	end
	-- Enqueue the message
	table.insert(SQ_MessageQueue, {message = message, type = type});
	-- Try to process immediately if not throttled
	ProcessMessageQueue();
end

local function SQ_PrintDebugData(...)
	local message, type = ...;
	if (SocialQuest.db.char.enabled and (SocialQuest.db.char.debug.enabled and (not (type) or SocialQuest.db.char.debug.announce[type]))) then
		SocialQuest:Print("Debug::"..message);
	end
end

local function ProcessMessageQueue()
	if GetTime() - lastChatSend >= 0.5 and #SQ_MessageQueue > 0 then
		local msg = table.remove(SQ_MessageQueue, 1);
		local message, type = msg.message, msg.type;
		lastChatSend = GetTime();
		if StandardSendOK(type) then
			SendChatMessage(message, GetChannelToUse());
		end
		if GuildSendOK(type) then
			SendChatMessage(message, "GUILD");
		end
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

local function EveryoneHasFinished(questID)
	local maxGroupNum,unitText;
	if IsInRaid() then
		maxGroupNum = GetNumGroupMembers();
		unitText = "raid";
	elseif IsInParty() then
		maxGroupNum = GetNumGroupMembers();
		unitText = "party";
	else
		return true;
	end
	local questDB = BuildQuestData();
	local questData = questDB[questID];
	if (questData) then
		if (questData.complete ~= 1) then
			return false;
		end
	end
	for i=1,maxGroupNum do
		if (UnitName("player") ~= UnitName(unitText..i)) then
			local pName,pRealm = UnitName(unitText..i);
			local person = GetGlobalName(pName,pRealm);
			local questTree = SocialQuest.PlayerQuests[person];
			if (questTree) then
				questData = questTree[questID];
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

local function GetQuestIDFromLink(link)
	if not link then return nil; end
	local questID = link:match("Hquest:(%d+)");
	return tonumber(questID);
end

local function GetQuestLogIndex(questID)
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i);
		if info and info.questID == questID then return i; end
	end
	return nil;
end

local function BuildQuestData()
	local quests = {};
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i);
		if info and info.title then
			local objectives = C_QuestLog.GetQuestObjectives(info.questID) or {};
			quests[info.questID] = {
				title = info.title,
				complete = info.isComplete,
				objectives = objectives
			};
		end
	end
	return quests;
end


function SocialQuest:QuestUpdate(event, ...)
	local updateType, questInfo, objective;
	local questID;
	if event == "QUEST_ACCEPTED" then
		local questLogIndex = ...;
		local info = C_QuestLog.GetInfo(questLogIndex);
		if not info then return; end
		updateType = AQ_QUEST_ACCEPTED;
		questInfo = {cleanTitle = info.title, link = GetQuestLink(info.questID), objectives = C_QuestLog.GetQuestObjectives(info.questID) or {}};
		questID = info.questID;
		objective = nil;
	elseif event == "QUEST_COMPLETE" then
		local questLogIndex = ...;
		local info = C_QuestLog.GetInfo(questLogIndex);
		if not info then return; end
		updateType = AQ_QUEST_FINISHED;
		questInfo = {cleanTitle = info.title, link = GetQuestLink(info.questID), objectives = C_QuestLog.GetQuestObjectives(info.questID) or {}};
		questID = info.questID;
		objective = nil;
	elseif event == "QUEST_TURNED_IN" then
		questID = ...;
		local title = C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest";
		updateType = AQ_QUEST_COMPLETED;
		questInfo = {cleanTitle = title, link = GetQuestLink(questID), objectives = {}};
		objective = nil;
	elseif event == "QUEST_FAILED" then
		local questLogIndex = ...;
		local info = C_QuestLog.GetInfo(questLogIndex);
		if not info then return; end
		updateType = AQ_QUEST_FAILED;
		questInfo = {cleanTitle = info.title, link = GetQuestLink(info.questID), objectives = C_QuestLog.GetQuestObjectives(info.questID) or {}};
		questID = info.questID;
		objective = nil;
	elseif event == "QUEST_REMOVED" then
		questID = ...;
		local title = C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest";
		updateType = AQ_QUEST_ABANDONED;
		questInfo = {cleanTitle = title, link = GetQuestLink(questID), objectives = {}};
		objective = nil;
	end
	if not updateType then return; end

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
		local questData = BuildQuestData()[questID] or {};
		local updateData = SocialQuest:Serialize(updateType,questID,questInfo.link,updateMessage,questData,channelName);
		SocialQuest:SendCommMessage(SQ_ANNOUNCE_UPDATE, updateData, channelName);
		SocialQuest.LastUpdate = updateData;
		SQ_PrintDebugData('Quest update comm message sent');
	end
	if updateType == AQ_QUEST_COMPLETED then
		SQ_SendChatMessage("turned in quest "..questInfo.link,"complete");
		SQ_PrintDebugData("turned in quest "..questInfo.link,"complete");
	elseif updateType == AQ_QUEST_ABANDONED then
		SQ_SendChatMessage("abandoned quest "..questInfo.link,"abandon");
		SQ_PrintDebugData("abandoned quest "..questInfo.link,"abandon");
	elseif updateType == AQ_QUEST_ACCEPTED then
		SQ_SendChatMessage("accepted quest "..questInfo.link,"accept");
		SQ_PrintDebugData("accepted quest "..questInfo.link,"accept");
	elseif updateType == AQ_QUEST_FAILED then
		SQ_SendChatMessage("failed quest "..questInfo.link,"fail");
		SQ_PrintDebugData("failed quest "..questInfo.link,"fail");
	elseif updateType == AQ_QUEST_FINISHED then
		SQ_SendChatMessage("completed quest "..questInfo.link,"finish");
		if (IsInParty() or IsInRaid()) and EveryoneHasFinished(info.questID) then
			SocialQuest:ShowBanner("Everyone has completed "..questInfo.cleanTitle, PURPLE_FONT_COLOR);
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
	local logIndex = GetQuestLogIndex(uniqueID);
	if not logIndex then
		return nil;
	end
	local liveQuestInfo = C_QuestLog.GetInfo(logIndex);
	if not liveQuestInfo then
		return nil;
	end

	-- Now we build a tooltip from what we know of the quest
	toolTip:ClearLines();
	toolTip:AddLine(liveQuestInfo.title,GOLD_FONT_COLOR.r,GOLD_FONT_COLOR.g,GOLD_FONT_COLOR.b);
	if (liveQuestInfo.isComplete) then
		toolTip:AddLine("You need to turn in this quest",ROYALBLUE_FONT_COLOR.r,ROYALBLUE_FONT_COLOR.g,ROYALBLUE_FONT_COLOR.b);
	else
		toolTip:AddLine("You are on this quest",GREEN_FONT_COLOR.r,GREEN_FONT_COLOR.g,GREEN_FONT_COLOR.b);
	end
	toolTip:AddLine(" ");
	toolTip:AddLine(liveQuestInfo.description,1,1,1,1);

	local objectives = C_QuestLog.GetQuestObjectives(uniqueID) or {};
	if (objectives) and (#objectives > 0) then
		toolTip:AddLine(" ");
		toolTip:AddLine("Requirements:",GOLD_FONT_COLOR.r,GOLD_FONT_COLOR.g,GOLD_FONT_COLOR.b);
		for i=1,#objectives do
			local objective = objectives[i];
			local color = WHITE_FONT_COLOR;
			if (objective.finished) then
				color = ROYALBLUE_FONT_COLOR;
			end
			if (trim(objective.text) ~= "") then
				toolTip:AddLine(" - "..objective.text,color.r,color.g,color.b);
			end
			-- now scan other party members with SocialQuest data and integrate it
			local partySize = GetNumGroupMembers();
			if (partySize > 1) then
				for p=1,partySize do
					if (UnitName("player") ~= UnitName("party"..p)) then
						local pName,pRealm = UnitName("party"..p);
						local person = GetGlobalName(pName,pRealm);
						local questData = SocialQuest.PlayerQuests[person];
						-- do we have a quest log for this party member
						if (questData) then
							local pQuestInfo = questData[uniqueID];
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
									if (trim(pObjective.text) ~= "") then
										toolTip:AddLine("   * "..person.." ("..pObjective.numFulfilled.."/"..pObjective.numRequired..")",color.r,color.g,color.b);
									end
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
	local questID = GetQuestIDFromLink(hyperLink);
	SocialQuest:CreateQuestTooltip(toolTip, questID);
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

function SocialQuest:ShowBanner(message, color)
	if not color then color = BLUE_FONT_COLOR; end
	RaidWarningFrame:AddMessage(message, color.r, color.g, color.b, 5);
end

function SocialQuest:OnEnable()
	-- Called when the addon is enabled
	SocialQuest:RegisterComm(SQ_ANNOUNCE_UPDATE);
	SocialQuest:RegisterComm(SQ_ANNOUNCE_INIT);
	SocialQuest:RegisterComm(SQ_FOLLOWED_START);
	SocialQuest:RegisterComm(SQ_FOLLOWED_STOP);
	SocialQuest:RegisterComm(SQ_REQUEST);
	SocialQuest:RegisterEvent("GROUP_ROSTER_UPDATE");
	SocialQuest:RegisterEvent("AUTOFOLLOW_BEGIN");
	SocialQuest:RegisterEvent("AUTOFOLLOW_END");
	SocialQuest:RegisterEvent("QUEST_ACCEPTED","QuestUpdate");
	SocialQuest:RegisterEvent("QUEST_COMPLETE","QuestUpdate");
	SocialQuest:RegisterEvent("QUEST_TURNED_IN","QuestUpdate");
	SocialQuest:RegisterEvent("QUEST_FAILED","QuestUpdate");
	SocialQuest:RegisterEvent("QUEST_REMOVED","QuestUpdate");
	SocialQuest:SecureHook(ItemRefTooltip,"SetHyperlink");
	--SocialQuest:RawHook("QuestGetAutoAccept",true);
	local channel = GetChannelToUse();

		if (channel) then
			local updateData = SocialQuest:Serialize(BuildQuestData());
			SocialQuest:SendCommMessage(SQ_ANNOUNCE_INIT, updateData, GetChannelToUse());
			SQ_PrintDebugData('Quest init comm message sent');
		end
	-- Start the message queue timer
	SQ_QueueTimer = SocialQuest:ScheduleRepeatingTimer(ProcessMessageQueue, 0.25);
end

function SocialQuest:OnDisable()
    -- Called when the addon is disabled
    SocialQuest:UnregisterComm(SQ_ANNOUNCE_UPDATE);
    SocialQuest:UnregisterComm(SQ_ANNOUNCE_INIT);
    SocialQuest:UnregisterComm(SQ_FOLLOWED_START);
    SocialQuest:UnregisterComm(SQ_FOLLOWED_STOP);
    SocialQuest:UnregisterComm(SQ_REQUEST);
	SocialQuest:UnregisterEvent("GROUP_ROSTER_UPDATE");
    SocialQuest:UnregisterEvent("AUTOFOLLOW_BEGIN");
	SocialQuest:UnregisterEvent("AUTOFOLLOW_END");
	SocialQuest:UnregisterEvent("QUEST_ACCEPTED");
	SocialQuest:UnregisterEvent("QUEST_COMPLETE");
	SocialQuest:UnregisterEvent("QUEST_TURNED_IN");
	SocialQuest:UnregisterEvent("QUEST_FAILED");
	SocialQuest:UnregisterEvent("QUEST_REMOVED");
	SocialQuest:UnHook(ItemRefTooltip,"SetHyperlink");
	--SocialQuest:UnHook("QuestGetAutoAccept");
	-- Cancel the message queue timer
	if SQ_QueueTimer then
		SocialQuest:CancelTimer(SQ_QueueTimer);
		SQ_QueueTimer = nil;
	end
end


function SocialQuest:OnCommReceived(prefix, message, distribution, sender)
    -- process the incoming message

	local sName,sRealm = strsplit("-",sender);
    if sender ~= UnitName("player") then
		if prefix == SQ_FOLLOWED_START then
			if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.follow.enabled) and (SocialQuest.db.char.follow.announceFollowed) then
				SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has started following you", GREEN_FONT_COLOR);
			end
		elseif prefix == SQ_FOLLOWED_STOP then
			if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.follow.enabled) and (SocialQuest.db.char.follow.announceFollowed) then
				SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has stopped following you", RED_FONT_COLOR);
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
			SQ_PrintDebugData('Quest init received from '..sender);
		elseif prefix == SQ_REQUEST then
			SQ_PrintDebugData('Quest init requested from '..sender);
			local updateData = SocialQuest:Serialize(BuildQuestData());
			SocialQuest:SendCommMessage(SQ_ANNOUNCE_INIT, updateData, "WHISPER", sender);
			SQ_PrintDebugData('Quest init comm message sent to '..sender);
			if (SocialQuest.LastUpdate ~= nil) then
				SocialQuest:SendCommMessage(SQ_ANNOUNCE_UPDATE, SocialQuest.LastUpdate, "WHISPER", sender);
				SQ_PrintDebugData('Quest update comm message sent to '..sender);
			end
		elseif prefix == SQ_ANNOUNCE_UPDATE then
			local success,updateType,questID,questLink,progressText,questData,source = SocialQuest:Deserialize(message);
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
			SocialQuest.PlayerQuests[sender][questID] = questData;
			local questTitle = questData.title or C_QuestLog.GetTitleForQuestID(questID) or "Unknown Quest";
			if (SocialQuest.db.char.enabled) and (SocialQuest.db.char.general.displayReceivedEvents) and
				(IsInParty() and (SocialQuest.db.char.party.displayReceivedEvents)) or
				(IsInRaid() and (SocialQuest.db.char.raid.displayReceivedEvents)) or
				(IsInBG() and (SocialQuest.db.char.battleground.displayReceivedEvents))
			then
				if updateType == AQ_QUEST_COMPLETED then
					if (SocialQuest.db.char.general.receive["complete"]) then
						SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has turned in "..questTitle, BLUE_FONT_COLOR);
					end
				elseif updateType == AQ_QUEST_PROGRESS_UPDATED then
					if (SocialQuest.db.char.general.receive["progress"]) then
						SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).."'s objectives:\r",progressText, GREEN_FONT_COLOR);
					end
				elseif updateType == AQ_QUEST_ABANDONED then
					if (SocialQuest.db.char.general.receive["abandon"]) then
						SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has abandoned "..questTitle, RED_FONT_COLOR);
					end
				elseif updateType == AQ_QUEST_ACCEPTED then
					if (SocialQuest.db.char.general.receive["accept"]) then
						SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has accepted "..questTitle, YELLOW_FONT_COLOR);
					end
				elseif updateType == AQ_QUEST_FAILED then
					if (SocialQuest.db.char.general.receive["fail"]) then
						SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has failed "..questTitle, RED_FONT_COLOR);
					end
				elseif updateType == AQ_QUEST_FINISHED then
					if (SocialQuest.db.char.general.receive["finish"]) then
						SocialQuest:ShowBanner(GetGlobalDisplayName(sName,sRealm).." has completed "..questTitle, GREEN_FONT_COLOR);
						if EveryoneHasFinished(questID) then
							SocialQuest:ShowBanner("Everyone has completed "..questTitle, PURPLE_FONT_COLOR);
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

function SocialQuest:GROUP_ROSTER_UPDATE(eventName)
    -- update the other party/raid members or clean up
    local channel = GetChannelToUse();
    if not (channel) then
		-- flush party quest data
		SocialQuest.PlayerQuests = {};
		collectgarbage(); -- clean up just for the sake of being tidy
		return;
    end
	if StandardSendOK() then
		local updateData = SocialQuest:Serialize(BuildQuestData());
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