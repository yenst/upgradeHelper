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

local function MakeDropdown(label, width, options, getFunc, setFunc, tooltip)
    local text = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", lastWidget == version and -2 or 0, SPACING)
    text:SetText(label)

    local dropName = "UpgradeHelper_" .. label:gsub("%s", "") .. "_Dropdown"
    local dropdown = CreateFrame("Frame", dropName, optionsFrame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(dropdown, width)

    local function optLabel(opt)
        if opt.atlas then
            return "|A:" .. opt.atlas .. ":16:16|a  " .. opt.label
        end
        return opt.label
    end

    local function updateText()
        local key = getFunc()
        for _, opt in ipairs(options) do
            if opt.key == key then
                UIDropDownMenu_SetText(dropdown, optLabel(opt))
                return
            end
        end
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = optLabel(opt)
            info.value = opt.key
            info.checked = (getFunc() == opt.key)
            info.func = function()
                setFunc(opt.key)
                updateText()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dropdown:SetScript("OnShow", updateText)

    if tooltip then
        local hitFrame = CreateFrame("Frame", nil, optionsFrame)
        hitFrame:SetPoint("TOPLEFT", text, "TOPLEFT")
        hitFrame:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT")
        hitFrame:EnableMouse(true)
        hitFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        hitFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Anchor for next widget: vertically below the dropdown, horizontally
    -- aligned with the label (compensating for the -16 UIDropDownMenu offset).
    local anchor = CreateFrame("Frame", nil, optionsFrame)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, 0)
    lastWidget = anchor
    return dropdown
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

-- Auto Scan at Vendor
MakeCheckbox("Auto Scan at Vendor",
    function() return H.db.autoScan end,
    function(v) H.db.autoScan = v end,
    "Automatically scan for free upgrades when opening the upgrade vendor")

-- Indicator Icon
MakeDropdown("Indicator Icon", 150, H.ICON_OPTIONS,
    function() return H.db.iconStyle end,
    function(v)
        H.db.iconStyle = v
        if H.RefreshOverlayIcons then H:RefreshOverlayIcons() end
    end)

-- Icon Position
MakeDropdown("Icon Position", 150, H.POSITION_OPTIONS,
    function() return H.db.iconPosition end,
    function(v)
        H.db.iconPosition = v
        if H.RefreshOverlayPositions then H:RefreshOverlayPositions() end
    end,
    "Choose which corner of the item slot to display the indicator icon.\nBaganator users: configure the corner in Baganator's own settings.")

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
