-- UI/Tooltips.lua
-- Hooks ItemRefTooltip to append group quest progress when hovering a quest link.

SocialQuestTooltips = {}

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
                tooltip:AddLine(C.header .. "Group Progress" .. C.reset)
                hasAnyGroupData = true
            end

            local qdata = entry.quests[questID]
            local statusStr

            if not entry.hasSocialQuest then
                statusStr = C.unknown .. "(shared, no data)" .. C.reset
            elseif qdata.isComplete then
                statusStr = C.completed .. "Objectives complete" .. C.reset
            else
                -- Show objective progress.
                local parts = {}
                for i, obj in ipairs(qdata.objectives or {}) do
                    table.insert(parts, obj.numFulfilled .. "/" .. obj.numRequired)
                end
                statusStr = #parts > 0 and table.concat(parts, "  ") or C.unknown .. "(no data)" .. C.reset
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
    -- Hook the quest hyperlink tooltip.
    local orig = ItemRefTooltip:GetScript("OnTooltipSetItem")
    -- Quest links use a different hook point. We hook SetHyperlink instead.
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
        if not link then return end
        local questID = tonumber(link:match("quest:(%d+)"))
        if questID then
            addGroupProgressToTooltip(self, questID)
        end
    end)
end
