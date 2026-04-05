-- UI/Tooltips.lua
-- Hooks quest link tooltips to append group party member progress.
-- Matches Questie's visual style: blank separator, plain "Party progress:" header,
-- " - Name: desc: X/Y" objective lines.
-- SAFETY: all augmentation is wrapped in pcall so SQ errors never corrupt the
-- base WoW or Questie tooltip.

SocialQuestTooltips = {}

local L      = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")
local SQWowAPI = SocialQuestWowAPI

-- Returns qdata for the given questID from entry, or nil.
-- On Retail, falls back to a title-based scan to handle aliased quest IDs
-- (same logical quest, different numeric IDs per race/class character type).
local function resolveQuestData(entry, questID, questTitle)
    if not entry or not entry.quests then return nil end
    if entry.quests[questID] then return entry.quests[questID] end
    -- Alias fallback: Retail only, requires a resolved title.
    if SQWowAPI.IS_RETAIL and questTitle then
        for _, qdata in pairs(entry.quests) do
            if qdata and qdata.title == questTitle then return qdata end
        end
    end
    return nil
end

local function addGroupProgressToTooltip(tooltip, questID)
    local ok, err = pcall(function()
        -- Party-only gate: never augment in raid or BG.
        local inRaid = SQWowAPI.IsInRaid()
        local inBG   = SQWowAPI.PARTY_CATEGORY_INSTANCE
                    and SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_INSTANCE)
        local inParty = SQWowAPI.IsInGroup(SQWowAPI.PARTY_CATEGORY_HOME)
        if not inParty or inRaid or inBG then return end

        local AQL = SocialQuest.AQL
        if not AQL then return end

        local questTitle = AQL:GetQuestTitle(questID)
        -- Local objective text for description labels (never transmitted over wire).
        local localObjs = AQL:GetQuestObjectives(questID) or {}

        -- Build the local-player key in the same format used by PlayerQuests.
        -- On Retail: "Name-Realm". On TBC: "Name".
        local localName, localRealm = SQWowAPI.UnitFullName("player")
        local localKey = (localName and localRealm)
                      and (localName .. "-" .. localRealm)
                      or  localName

        local hasAnyGroupData = false

        for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
            -- Skip local player — their progress is shown by Questie / native tooltip.
            if localKey and playerName == localKey then
                -- continue
            else
                local qdata = resolveQuestData(entry, questID, questTitle)
                if qdata then
                    if not hasAnyGroupData then
                        -- Blank separator line matches Questie's style before "Your progress:".
                        tooltip:AddLine(" ")
                        tooltip:AddLine(L["Party progress"] .. ":")
                        hasAnyGroupData = true
                    end

                    local line
                    if not entry.hasSocialQuest then
                        line = " - " .. playerName .. ": " .. L["(shared, no data)"]
                    elseif qdata.isComplete then
                        line = " - " .. playerName .. ": "
                               .. "|cFF40C040" .. L["Complete"] .. "|r"
                    else
                        local parts = {}
                        for i, obj in ipairs(qdata.objectives or {}) do
                            local nf  = obj.numFulfilled or 0
                            local nr  = obj.numRequired  or 1
                            local localObj = localObjs[i]
                            local text = localObj and localObj.text
                            -- Strip embedded count from objective text so we can substitute
                            -- the remote player's values. Two formats exist:
                            --   count-last:  "Description: X/Y"
                            --   count-first: "X/Y Description"
                            local desc
                            if text then
                                desc = text:match("^(.-)%s*:%s*%d+/%d+%s*$")  -- count-last
                                    or text:match("^%d+/%d+%s+(.+)$")         -- count-first
                            end
                            if desc and desc ~= "" then
                                table.insert(parts, desc .. ": " .. nf .. "/" .. nr)
                            else
                                table.insert(parts, nf .. "/" .. nr)
                            end
                        end
                        local status = #parts > 0
                            and table.concat(parts, "; ")
                            or  L["(no data)"]
                        line = " - " .. playerName .. ": " .. status
                    end

                    -- White text (1,1,1), matching Questie's plain objective lines.
                    tooltip:AddLine(line, 1, 1, 1)
                end
            end
        end

        if hasAnyGroupData then tooltip:Show() end
    end)

    if not ok then
        SocialQuest:Debug("Banner", "Tooltip augment error: " .. tostring(err))
    end
end

function SocialQuestTooltips:Initialize()
    local SQWowAPI = SocialQuestWowAPI   -- local alias for closures below
    if SQWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        -- Retail: native tooltip data processor — fires after WoW populates quest tooltips.
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )

        -- Retail: forward our custom |Hsocialquest:questID:level| links to the native
        -- quest tooltip display. TooltipDataProcessor then fires and appends party progress.
        hooksecurefunc("SetItemRef", function(link, text, button)
            local ok, err = pcall(function()
                if not link then return end
                local linkType, qidStr, levelStr = strsplit(":", link)
                if linkType ~= "socialquest" then return end
                local questID = tonumber(qidStr)
                local level   = tonumber(levelStr) or 0
                if not questID then return end
                ShowUIPanel(ItemRefTooltip)
                ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
                ItemRefTooltip:SetHyperlink("quest:" .. questID .. ":" .. level)
                ItemRefTooltip:Show()
            end)
            if not ok then
                SocialQuest:Debug("Banner", "SetItemRef hook error: " .. tostring(err))
            end
        end)

    elseif ItemRefTooltip then
        -- TBC / Classic / Mists: hook SetHyperlink on ItemRefTooltip.
        -- Matches quest: (native links), questie: (Questie links), and
        -- socialquest: (should not appear on non-Retail, but guard anyway).
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local questID = tonumber(link:match("^quest:(%d+)"))
                         or tonumber(link:match("^questie:(%d+)"))
            if questID then
                addGroupProgressToTooltip(self, questID)
            end
        end)
    end
end
