local AddonName, NS = ...
local H = NS

------------------------------------------------------------------------
-- Overlays — green arrow on character pane slots and bag items
------------------------------------------------------------------------

local charOverlays = {} -- slotID → overlay frame
local bagOverlays = {}  -- "bag:slot" → overlay frame

local ARROW_SIZE = 14

local POSITION_OFFSETS = {
    TOPLEFT     = { point = "TOPLEFT",     x = -2, y =  2 },
    TOPRIGHT    = { point = "TOPRIGHT",    x =  2, y =  2 },
    BOTTOMLEFT  = { point = "BOTTOMLEFT",  x = -2, y = -2 },
    BOTTOMRIGHT = { point = "BOTTOMRIGHT", x =  2, y =  2 },
}

local function GetPositionInfo()
    return POSITION_OFFSETS[H.db.iconPosition or "BOTTOMRIGHT"] or POSITION_OFFSETS.BOTTOMRIGHT
end

------------------------------------------------------------------------
-- Shared overlay creator
------------------------------------------------------------------------
local function CreateArrowOverlay(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetSize(ARROW_SIZE, ARROW_SIZE)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 5)

    local posInfo = GetPositionInfo()
    overlay:SetPoint(posInfo.point, parent, posInfo.point, posInfo.x, posInfo.y)

    local iconInfo = H:GetIconInfo()
    local icon = overlay:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetAtlas(iconInfo.atlas)
    icon:SetVertexColor(unpack(iconInfo.color))
    overlay.icon = icon

    overlay:Hide()
    return overlay
end

------------------------------------------------------------------------
-- Character pane overlays
------------------------------------------------------------------------

local function GetOrCreateCharOverlay(slotID)
    if charOverlays[slotID] then return charOverlays[slotID] end

    local slotButtonName = "Character" .. H.EQUIP_SLOTS[slotID]
    local slotButton = _G[slotButtonName]
    if not slotButton then return nil end

    local overlay = CreateArrowOverlay(slotButton)

    overlay:EnableMouse(true)
    overlay:SetScript("OnEnter", function(self)
        local itemLink = GetInventoryItemLink("player", slotID)
        local info = itemLink and H:GetFreeUpgradeInfo(itemLink)
        if info then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Free Upgrade", 0, 1, 0)
            GameTooltip:AddDoubleLine(
                "Item Level",
                info.currentIlvl .. " > " .. info.freeMaxIlvl .. "  (+" .. info.freeLevels .. ")",
                0.7, 0.7, 0.7, 1, 1, 1
            )
            GameTooltip:Show()
        end
    end)
    overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)

    charOverlays[slotID] = overlay
    return overlay
end

function H:UpdateCharacterOverlays()
    for slotID, _ in pairs(H.EQUIP_SLOTS) do
        local overlay = GetOrCreateCharOverlay(slotID)
        if not overlay then
            -- slot button doesn't exist yet
        elseif not H.db.showCharOverlays then
            overlay:Hide()
        else
            local itemLink = GetInventoryItemLink("player", slotID)
            local info = itemLink and H:GetFreeUpgradeInfo(itemLink)
            if info and info.freeLevels > 0 then
                overlay:Show()
            else
                overlay:Hide()
            end
        end
    end
end

--- Refresh icon atlas/color on all existing overlays (called when icon setting changes).
function H:RefreshOverlayIcons()
    local iconInfo = H:GetIconInfo()
    for _, overlay in pairs(charOverlays) do
        if overlay.icon then
            overlay.icon:SetAtlas(iconInfo.atlas)
            overlay.icon:SetVertexColor(unpack(iconInfo.color))
        end
    end
    for _, overlay in pairs(bagOverlays) do
        if overlay.icon then
            overlay.icon:SetAtlas(iconInfo.atlas)
            overlay.icon:SetVertexColor(unpack(iconInfo.color))
        end
    end
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

--- Reposition all existing overlays (called when position setting changes).
function H:RefreshOverlayPositions()
    local posInfo = GetPositionInfo()
    for _, overlay in pairs(charOverlays) do
        overlay:ClearAllPoints()
        overlay:SetPoint(posInfo.point, overlay:GetParent(), posInfo.point, posInfo.x, posInfo.y)
    end
    for _, overlay in pairs(bagOverlays) do
        overlay:ClearAllPoints()
        overlay:SetPoint(posInfo.point, overlay:GetParent(), posInfo.point, posInfo.x, posInfo.y)
    end
end

------------------------------------------------------------------------
-- Bag overlays
------------------------------------------------------------------------

local function GetOrCreateBagOverlay(bagButton)
    if not bagButton then return nil end
    if bagButton._upgradeHelperOverlay then return bagButton._upgradeHelperOverlay end

    local overlay = CreateArrowOverlay(bagButton)

    bagButton._upgradeHelperOverlay = overlay
    bagOverlays[bagButton] = overlay
    return overlay
end

--- Update a single bag item button's overlay.
local function UpdateBagButton(itemButton, bag, slot)
    local overlay = itemButton._upgradeHelperOverlay
    -- Fast hide path
    if not H.db.showCharOverlays then
        if overlay then overlay:Hide() end
        return
    end

    bag = bag or itemButton:GetBagID()
    slot = slot or itemButton:GetID()
    if not (bag and slot) then
        if overlay then overlay:Hide() end
        return
    end

    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if itemLink then
        local info = H:GetFreeUpgradeInfo(itemLink)
        if info and info.freeLevels > 0 then
            local ov = GetOrCreateBagOverlay(itemButton)
            if ov then
                -- Re-sync frame level (bag buttons change level during UpdateItems)
                ov:SetFrameLevel(itemButton:GetFrameLevel() + 5)
                ov:Show()
            end
            return
        end
    end

    -- No free upgrade — hide if overlay exists
    if overlay then overlay:Hide() end
end

--- Refresh all visible buttons in a container frame.
local function UpdateContainerFrame(frame)
    if not frame or not frame.EnumerateValidItems then return end
    for _, itemButton in frame:EnumerateValidItems() do
        UpdateBagButton(itemButton, itemButton:GetBagID(), itemButton:GetID())
    end
end

function H:UpdateBagOverlays()
    if not H.db.showCharOverlays then
        for _, overlay in pairs(bagOverlays) do
            overlay:Hide()
        end
        return
    end

    -- Refresh combined bags view
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        UpdateContainerFrame(ContainerFrameCombinedBags)
    end

    -- Refresh individual bag frames
    local container = ContainerFrameContainer or UIParent
    if container.ContainerFrames then
        for _, frame in ipairs(container.ContainerFrames) do
            if frame:IsShown() then
                UpdateContainerFrame(frame)
            end
        end
    end
end

------------------------------------------------------------------------
-- Hook character frame and bags
------------------------------------------------------------------------

-- Hook bag frames at file scope (same pattern as SimpleItemLevel).
-- ContainerFrameCombinedBags and ContainerFrameContainer exist at load time.
local function OnUpdateItems(frame)
    if not frame.EnumerateValidItems then return end
    for _, itemButton in frame:EnumerateValidItems() do
        UpdateBagButton(itemButton, itemButton:GetBagID(), itemButton:GetID())
    end
end

if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", OnUpdateItems)
end

for _, frame in ipairs((ContainerFrameContainer or UIParent).ContainerFrames or {}) do
    hooksecurefunc(frame, "UpdateItems", OnUpdateItems)
end

-- Character frame hooks need to wait for the frame to exist.
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if CharacterFrame then
            CharacterFrame:HookScript("OnShow", function()
                H:UpdateCharacterOverlays()
            end)
        end
        if PaperDollFrame then
            PaperDollFrame:HookScript("OnShow", function()
                H:UpdateCharacterOverlays()
            end)
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

------------------------------------------------------------------------
-- Baganator integration (corner widget API)
------------------------------------------------------------------------

function H:RegisterBaganatorWidget()
    if not Baganator or not Baganator.API or not Baganator.API.RegisterCornerWidget then return end
    if H.baganatorRegistered then return end
    H.baganatorRegistered = true

    Baganator.API.RegisterCornerWidget(
        "UpgradeHelper: Free Upgrade",
        "upgradehelper-free-upgrade",
        function(cornerFrame, details)
            if not details.itemLink then return false end
            local info = H:GetFreeUpgradeInfo(details.itemLink)
            if info and info.freeLevels > 0 then
                local iconInfo = H:GetIconInfo()
                cornerFrame:SetAtlas(iconInfo.atlas)
                cornerFrame:SetVertexColor(unpack(iconInfo.color))
                return true
            end
            return false
        end,
        function(itemButton)
            local texture = itemButton:CreateTexture(nil, "ARTWORK")
            local iconInfo = H:GetIconInfo()
            texture:SetAtlas(iconInfo.atlas)
            texture:SetSize(11, 11)
            return texture
        end,
        {corner = "bottom_right", priority = 1}
    )
end

------------------------------------------------------------------------
-- Bagnon integration (hook ContainerItem:Update via BagBrother)
------------------------------------------------------------------------

local function UpdateBagnonButton(itemButton)
    local overlay = itemButton._upgradeHelperOverlay
    if not H.db.showCharOverlays then
        if overlay then overlay:Hide() end
        return
    end

    -- Skip cached/offline character views
    if itemButton.IsCached and itemButton:IsCached() then
        if overlay then overlay:Hide() end
        return
    end

    local itemLink = itemButton.info and itemButton.info.hyperlink
    if itemLink then
        local info = H:GetFreeUpgradeInfo(itemLink)
        if info and info.freeLevels > 0 then
            local ov = GetOrCreateBagOverlay(itemButton)
            if ov then
                ov:SetFrameLevel(itemButton:GetFrameLevel() + 5)
                ov:Show()
            end
            return
        end
    end

    if overlay then overlay:Hide() end
end

function H:HookBagnon()
    -- BagBrother classes may be registered on the Bagnon global (Group directive)
    -- or the BagBrother global depending on load context; check both.
    local bb = (Bagnon and Bagnon.ContainerItem and Bagnon)
            or (BagBrother and BagBrother.ContainerItem and BagBrother)
    if not bb then return end
    if H.bagnonHooked then return end
    H.bagnonHooked = true
    H.bagnonAddon = bb

    hooksecurefunc(bb.ContainerItem, 'Update', function(self)
        UpdateBagnonButton(self)
    end)
end
