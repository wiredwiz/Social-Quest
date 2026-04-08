-- Core/BridgeRegistry.lua
-- Lifecycle manager for data-provider bridges. Bridges are plain Lua tables that
-- satisfy the bridge interface contract documented below.
--
-- Bridge interface contract:
--
--   bridge.provider  = SocialQuest.DataProviders.X   (string identity constant)
--   bridge.nameTag   = string or nil
--       Appended after the player's name in RowFactory. May be a WoW texture
--       escape "|TPath:w:h|t" or plain text. nil means no annotation (first-party).
--
--   bridge:IsAvailable() -> bool
--       Returns true when the source addon is loaded and its public API is accessible.
--
--   bridge:Enable() -> void
--       Installs hooks or listeners. Safe to call multiple times (must guard with
--       _hookInstalled). Must check _active to avoid double-hydration on group type
--       changes. hooksecurefunc is permanent — hooks cannot be uninstalled.
--
--   bridge:Disable() -> void
--       Suspends processing. Sets _active = false. Does NOT remove hooks.
--
--   bridge:GetSnapshot() -> { [fullName] = { [questID] = questEntry } }
--       Returns current known state for initial hydration. Returns {} if unavailable.
--
-- Bridges call GroupData directly:
--   SocialQuestGroupData:OnBridgeQuestUpdate(provider, fullName, questEntry)
--   SocialQuestGroupData:OnBridgeQuestRemove(provider, fullName, questID)
--
-- BridgeRegistry calls GroupData for hydration:
--   SocialQuestGroupData:OnBridgeHydrate(provider, snapshot)

SocialQuestBridgeRegistry = {}
SocialQuestBridgeRegistry._bridges = {}

function SocialQuestBridgeRegistry:Register(bridge)
    table.insert(self._bridges, bridge)
end

-- Called by GroupComposition when the local player joins a group (or group type changes).
-- For each available bridge that is not already active:
--   1. Gets a snapshot of existing data (reduces spurious "accepted" banners from
--      Questie's initial 2-second sync broadcast on group join).
--   2. Hydrates GroupData with the snapshot (no banners).
--   3. Calls Enable() to start processing live hook events.
-- Skips bridges already active — avoids double-hydration on group type changes
-- (e.g. party promoted to raid) where OnSelfJoinedGroup fires again.
function SocialQuestBridgeRegistry:EnableAll()
    for _, bridge in ipairs(self._bridges) do
        if bridge:IsAvailable() and not bridge._active then
            local snapshot = bridge:GetSnapshot()
            SocialQuestGroupData:OnBridgeHydrate(bridge.provider, snapshot)
            bridge:Enable()
        end
    end
end

-- Called by GroupComposition when a new member joins the group.
-- Notifies each active bridge so they can fetch data for the new member.
function SocialQuestBridgeRegistry:OnMemberJoined(fullName)
    for _, bridge in ipairs(self._bridges) do
        if bridge._active and bridge.OnMemberJoined then
            bridge:OnMemberJoined(fullName)
        end
    end
end

-- Called by GroupComposition when the local player leaves all groups.
-- Suspends all bridge callbacks until the next EnableAll().
function SocialQuestBridgeRegistry:DisableAll()
    for _, bridge in ipairs(self._bridges) do
        bridge:Disable()
    end
end

-- Called by Communications:ResyncAll() when the user triggers a manual resync.
-- Forwards to each active bridge that supports ForceResync().
function SocialQuestBridgeRegistry:ForceResync()
    for _, bridge in ipairs(self._bridges) do
        if bridge._active and bridge.ForceResync then
            bridge:ForceResync()
        end
    end
end

-- Returns the nameTag string for a given provider, or nil if not found.
-- Used by RowFactory to annotate player names with their data-source icon.
function SocialQuestBridgeRegistry:GetNameTag(provider)
    for _, bridge in ipairs(self._bridges) do
        if bridge.provider == provider then
            return bridge.nameTag
        end
    end
    return nil
end
