-- Core/GroupComposition.lua
-- Sole handler for GROUP_ROSTER_UPDATE and PLAYER_LOGIN.
-- Diffs each event against a membership snapshot to classify changes
-- (join / leave / subgroup-move), then calls typed methods on
-- Communications and GroupData directly.
--
-- Internal state:
--   memberSet       [fullName] = true     -- current group members
--   memberSubgroups [fullName] = subgroup -- raid/BG subgroup numbers
--   lastGroupType   GroupType.X|nil       -- group type from last snapshot

------------------------------------------------------------------------
-- GroupType enum
-- Values are plain English strings so debug output is self-documenting.
-- Never transmitted over the wire; never localized.
------------------------------------------------------------------------

local GroupType = {
    Party        = "party",
    Raid         = "raid",
    Battleground = "battleground",
}

local SQWowAPI = SocialQuestWowAPI

SocialQuestGroupComposition = {}

-- Expose for Communications.lua, which compares groupType arguments
-- but does not own the type definition.
SocialQuestGroupComposition.GroupType = GroupType

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

local function currentGroupType()
    if SQWowAPI.IsInRaid() then
        return GroupType.Raid
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE) then
        return GroupType.Battleground
    elseif SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME) then
        return GroupType.Party
    end
    return nil
end

-- Produces a canonical "Name" or "Name-Realm" key.
-- One-argument form: name may already contain "-Realm" (GetRaidRosterInfo cross-realm format).
-- Two-argument form: name + realm from UnitName(unit); appends realm when non-nil/non-empty.
local function normalize(name, realm)
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

-- Called from SocialQuest:OnEnable().
function SocialQuestGroupComposition:Initialize()
    self.memberSet       = {}
    self.memberSubgroups = {}
    self.lastGroupType   = nil
    SocialQuest:Debug("Group", "GroupComposition initialized")
end

------------------------------------------------------------------------
-- Event handlers
------------------------------------------------------------------------

function SocialQuestGroupComposition:OnGroupRosterUpdate()
    local groupType = currentGroupType()
    -- UnitName("player") returns name, realm where realm is nil for same-realm.
    -- normalize() handles nil realm correctly.
    local selfName  = normalize(SQWowAPI.UnitName("player"))

    -- ── Self left all groups ──────────────────────────────────────────────────
    if groupType == nil then
        if next(self.memberSet) then
            self.memberSet       = {}
            self.memberSubgroups = {}
            self.lastGroupType   = nil
            SocialQuestComm:OnSelfLeftGroup()
            SocialQuestGroupData:OnSelfLeftGroup()
            SocialQuestBridgeRegistry:DisableAll()
            SocialQuest:Debug("Group", "Self left all groups")
        end
        return
    end

    -- ── Build new membership snapshot ─────────────────────────────────────────
    local newMembers   = {}   -- [fullName] = true
    local newSubgroups = {}   -- [fullName] = subgroupNumber (raid/BG only)

    if groupType == GroupType.Raid or groupType == GroupType.Battleground then
        local count = SQWowAPI.GetNumGroupMembers()
        for i = 1, count do
            local name, _, subgroup = SQWowAPI.GetRaidRosterInfo(i)
            if name then
                local fullName = normalize(name)  -- one-arg: name may already have "-Realm"
                newMembers[fullName]   = true
                newSubgroups[fullName] = subgroup
            end
        end
    else
        -- Party: self is not a "partyX" unit; add explicitly.
        newMembers[selfName] = true
        local count = SQWowAPI.GetNumGroupMembers()
        for i = 1, count - 1 do  -- count includes self; partyX units are non-self members
            local name, realm = SQWowAPI.UnitName("party" .. i)
            if name then
                local fullName = normalize(name, realm)
                newMembers[fullName] = true
            end
        end
    end

    -- ── Self joined or group type changed — handle FIRST ─────────────────────
    -- Must fire before member loops so OnSelfJoinedGroup (which broadcasts SQ_INIT)
    -- runs before OnMemberJoined (which whispers individual party members).
    if not self.memberSet[selfName] then
        SocialQuest:Debug("Group", "Self joined group: " .. groupType)
        SocialQuestComm:OnSelfJoinedGroup(groupType)
        SocialQuestBridgeRegistry:EnableAll()
    elseif groupType ~= self.lastGroupType then
        SocialQuest:Debug("Group", "Group type changed: " .. (self.lastGroupType or "nil") .. " → " .. groupType)
        SocialQuestComm:OnSelfJoinedGroup(groupType)
        SocialQuestBridgeRegistry:EnableAll()
    end

    -- ── Detect member joins ───────────────────────────────────────────────────
    for fullName in pairs(newMembers) do
        if fullName ~= selfName and not self.memberSet[fullName] then
            SocialQuest:Debug("Group", fullName .. " joined the group")
            SocialQuestGroupData:OnMemberJoined(fullName, groupType)
            SocialQuestComm:OnMemberJoined(fullName, groupType)
        end
    end

    -- ── Detect member leaves ──────────────────────────────────────────────────
    -- Self-leave is handled by the nil-groupType path at the top; selfName being
    -- in memberSet but absent from newMembers while groupType != nil is unreachable.
    for fullName in pairs(self.memberSet) do
        if fullName ~= selfName and not newMembers[fullName] then
            SocialQuest:Debug("Group", fullName .. " left the group — purging data")
            SocialQuestGroupData:PurgePlayer(fullName)
            SocialQuestComm:OnMemberLeft(fullName)
        end
    end

    -- ── Detect subgroup moves (raid/BG only) ──────────────────────────────────
    -- Only compare players who had a prior subgroup entry (guard against false
    -- positives for new joiners whose memberSubgroups entry is nil).
    local subgroupsChanged = false
    for fullName, sg in pairs(newSubgroups) do
        if self.memberSubgroups[fullName] ~= nil and self.memberSubgroups[fullName] ~= sg then
            subgroupsChanged = true
            break
        end
    end
    if subgroupsChanged then
        SocialQuest:Debug("Group", "Subgroup reorganization detected (no sync needed)")
        -- OnSubgroupsChanged() has no current subscribers; defined as a future extension point.
    end

    -- ── Commit snapshot ───────────────────────────────────────────────────────
    self.memberSet       = newMembers
    self.memberSubgroups = newSubgroups
    self.lastGroupType   = groupType
end

-- On login/reload, memberSet is empty. Running the diff against empty
-- state fires OnSelfJoinedGroup then OnMemberJoined for each current
-- member — the correct bootstrap behavior.
function SocialQuestGroupComposition:OnPlayerLogin()
    self:OnGroupRosterUpdate()
end
