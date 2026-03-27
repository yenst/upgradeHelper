local AddonName, NS = ...
local H = NS

------------------------------------------------------------------------
-- Overlays — green arrow on character pane slots and bag items
------------------------------------------------------------------------

local charOverlays = {} -- slotID → overlay frame
local bagOverlays = {}  -- "bag:slot" → overlay frame

local ARROW_SIZE = 14

------------------------------------------------------------------------
-- Shared overlay creator
------------------------------------------------------------------------
local function CreateArrowOverlay(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetSize(ARROW_SIZE, ARROW_SIZE)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 5)

    local icon = overlay:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\BUTTONS\\Arrow-Up-Up")
    icon:SetVertexColor(0, 1, 0, 1)
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
    overlay:SetPoint("BOTTOMRIGHT", slotButton, "BOTTOMRIGHT", 2, 2)

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

------------------------------------------------------------------------
-- Bag overlays
------------------------------------------------------------------------

local function GetOrCreateBagOverlay(bagButton)
    if not bagButton then return nil end
    if bagButton._upgradeHelperOverlay then return bagButton._upgradeHelperOverlay end

    local overlay = CreateArrowOverlay(bagButton)
    overlay:SetPoint("BOTTOMRIGHT", bagButton, "BOTTOMRIGHT", 2, 2)

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

local function RegisterBaganatorWidget()
    if not Baganator or not Baganator.API or not Baganator.API.RegisterCornerWidget then return end

    Baganator.API.RegisterCornerWidget(
        "UpgradeHelper: Free Upgrade",
        "upgradehelper-free-upgrade",
        function(cornerFrame, details)
            if not details.itemLink then return false end
            local info = H:GetFreeUpgradeInfo(details.itemLink)
            if info and info.freeLevels > 0 then
                cornerFrame:SetVertexColor(0, 1, 0)
                return true
            end
            return false
        end,
        function(itemButton)
            local texture = itemButton:CreateTexture(nil, "ARTWORK")
            texture:SetAtlas("poi-door-arrow-up")
            texture:SetSize(11, 11)
            return texture
        end,
        {corner = "bottom_right", priority = 1}
    )
end

if C_AddOns.IsAddOnLoaded("Baganator") then
    RegisterBaganatorWidget()
else
    local bagaFrame = CreateFrame("Frame")
    bagaFrame:RegisterEvent("ADDON_LOADED")
    bagaFrame:SetScript("OnEvent", function(self, _, addon)
        if addon == "Baganator" then
            RegisterBaganatorWidget()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
