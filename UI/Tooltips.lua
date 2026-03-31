-- UI/Tooltips.lua
-- Hooks ItemRefTooltip to append group quest progress when hovering a quest link.

SocialQuestTooltips = {}

local L = LibStub("AceLocale-3.0"):GetLocale("SocialQuest")

local function addGroupProgressToTooltip(tooltip, questID)
    local C = SocialQuestColors
    local AQL = SocialQuest.AQL
    if not AQL then return end

    local hasAnyGroupData = false

    for playerName, entry in pairs(SocialQuestGroupData.PlayerQuests) do
        if entry.quests and entry.quests[questID] then
            -- Add the header on the first matching entry, then subsequent entries
            -- fall through to the player rows below.
            if not hasAnyGroupData then
                tooltip:AddLine(C.header .. L["Group Progress"] .. C.reset)
                hasAnyGroupData = true
            end

            local qdata = entry.quests[questID]
            local statusStr

            if not entry.hasSocialQuest then
                statusStr = C.unknown .. L["(shared, no data)"] .. C.reset
            elseif qdata.isComplete then
                statusStr = C.completed .. L["Objectives complete"] .. C.reset
            else
                -- Show objective progress.
                local parts = {}
                for i, obj in ipairs(qdata.objectives or {}) do
                    table.insert(parts, obj.numFulfilled .. "/" .. obj.numRequired)
                end
                statusStr = #parts > 0 and table.concat(parts, "  ") or C.unknown .. L["(no data)"] .. C.reset
            end

            tooltip:AddDoubleLine(
                C.white .. playerName .. C.reset,
                statusStr,
                1, 1, 1, 1, 1, 1
            )
        end
    end

    if hasAnyGroupData then
        tooltip:Show()
    end
end

function SocialQuestTooltips:Initialize()
    if SocialQuestWowAPI.IS_RETAIL and TooltipDataProcessor and Enum.TooltipDataType then
        -- Retail: use the native tooltip data processor API.
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Quest,
            function(tooltip, data)
                if data and data.id then
                    addGroupProgressToTooltip(tooltip, data.id)
                end
            end
        )
    elseif ItemRefTooltip then
        -- TBC / Classic / Mists: hook SetHyperlink on ItemRefTooltip.
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
            if not link then return end
            local questID = tonumber(link:match("quest:(%d+)"))
            if questID then
                addGroupProgressToTooltip(self, questID)
            end
        end)
    end
end
