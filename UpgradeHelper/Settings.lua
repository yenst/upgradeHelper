local AddonName, NS = ...
local H = NS

------------------------------------------------------------------------
-- WoW Settings panel for UpgradeHelper
------------------------------------------------------------------------
local optionsFrame = CreateFrame("Frame")
optionsFrame:SetSize(400, 400)
optionsFrame:Hide()

-- Header
local header = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
header:SetPoint("TOPLEFT", 16, -16)
header:SetText("UpgradeHelper")

local version = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
version:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
version:SetText("Shows which items can be upgraded for free (without crests)")

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local lastWidget = version
local SPACING = -20

local function MakeCheckbox(label, getFunc, setFunc, tooltip)
    local cb = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", lastWidget == version and -2 or 0, SPACING)
    cb:SetScript("OnShow", function(self) self:SetChecked(getFunc()) end)
    cb:SetScript("OnClick", function(self) setFunc(self:GetChecked()) end)

    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetText(label)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    lastWidget = cb
    return cb
end

------------------------------------------------------------------------
-- Controls
------------------------------------------------------------------------

-- Show Tooltips
MakeCheckbox("Show Tooltip Info",
    function() return H.db.showTooltips end,
    function(v) H.db.showTooltips = v end,
    "Show free upgrade information in item tooltips")

-- Show Character Pane Overlays
MakeCheckbox("Show Character Pane Overlays",
    function() return H.db.showCharOverlays end,
    function(v)
        H.db.showCharOverlays = v
        if H.UpdateCharacterOverlays then H:UpdateCharacterOverlays() end
    end,
    "Show green arrow indicators on character pane equipment slots that have free upgrades")

-- Show Scan Message
MakeCheckbox("Show Scan Message",
    function() return H.db.showScanMessage end,
    function(v) H.db.showScanMessage = v end,
    "Print a chat message when an upgrade scan completes at the vendor")

------------------------------------------------------------------------
-- Required callbacks
------------------------------------------------------------------------
optionsFrame.OnCommit = function() end
optionsFrame.OnDefault = function() end
optionsFrame.OnRefresh = function() end

------------------------------------------------------------------------
-- Register with WoW Settings
------------------------------------------------------------------------
H.settingsCategory = Settings.RegisterCanvasLayoutCategory(optionsFrame, "UpgradeHelper")
Settings.RegisterAddOnCategory(H.settingsCategory)
