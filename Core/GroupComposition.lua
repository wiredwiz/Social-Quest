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

SocialQuestGroupComposition = {}

-- Expose for Communications.lua, which compares groupType arguments
-- but does not own the type definition.
SocialQuestGroupComposition.GroupType = GroupType

------------------------------------------------------------------------
-- Private helpers
------------------------------------------------------------------------

local function currentGroupType()
    if IsInRaid() then
        return GroupType.Raid
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return GroupType.Battleground
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
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
-- Event handlers (stubs — full diff implemented in Task 4)
------------------------------------------------------------------------

function SocialQuestGroupComposition:OnGroupRosterUpdate()
    -- Full diff algorithm implemented in Task 4.
end

-- On login/reload, memberSet is empty. Running the diff against empty
-- state fires OnSelfJoinedGroup then OnMemberJoined for each current
-- member — the correct bootstrap behavior.
function SocialQuestGroupComposition:OnPlayerLogin()
    self:OnGroupRosterUpdate()
end
