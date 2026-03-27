-- UI/HeaderLabel.lua
-- Dismissible label widget factory.
-- Usage: local ctrl = SocialQuestHeaderLabel.New(parent, config)
-- config: { height=N, r=N, g=N, b=N }

SocialQuestHeaderLabel = {}

function SocialQuestHeaderLabel.New(parent, config)
    config = config or {}
    local height = config.height or 18
    local tR, tG, tB = config.r or 0.9, config.g or 0.9, config.b or 0.9

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(height)
    frame:Hide()

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT",     frame, "TOPLEFT",     4,   0)
    label:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetTextColor(tR, tG, tB)

    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(18, height)
    btn:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")

    local ctrl = {}

    -- SetContent wires new text and handlers. Always reassigns OnClick so
    -- the closure captures the current onDismiss even after filter state changes.
    function ctrl:SetContent(text, tooltipText, onDismiss)
        label:SetText(text or "")
        if tooltipText and tooltipText ~= "" then
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
        end
        btn:SetScript("OnClick", onDismiss or function() end)
    end

    function ctrl:Show()     frame:Show()           end
    function ctrl:Hide()     frame:Hide()           end
    function ctrl:IsShown()  return frame:IsShown() end
    function ctrl:GetFrame() return frame           end

    return ctrl
end
