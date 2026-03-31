local AddonName, NS = ...
local H = NS

H.db = {
    showTooltips = true,
    showCharOverlays = true,
    showScanMessage = true,
    autoScan = true,
    iconStyle = "arrow_green",
    iconPosition = "BOTTOMRIGHT",
}
H.scannedItems = {}

------------------------------------------------------------------------
-- Icon options for upgrade indicators
------------------------------------------------------------------------
H.ICON_OPTIONS = {
    {key = "arrow_green", label = "Green Arrow", atlas = "poi-door-arrow-up", color = {0, 1, 0, 1}},
    {key = "coin_gold", label = "Gold Coin", atlas = "Coin-Gold", color = {1, 1, 1, 1}},
    {key = "goblin_face", label = "Goblin Face", atlas = "majorfactions_icons_stars512", color = {1, 1, 1, 1}},
    {key = "golden_boot", label = "Golden Boot", atlas = "Taxi_Frame_Yellow", color = {1, 1, 1, 1}},
    {key = "quest_icon", label = "Quest Log Icon", atlas = "crosshair_directions_64", color = {1, 1, 1, 1}},
    {key = "abundance", label = "Bountiful Abundance", atlas = "UI-EventPoi-abundancebountiful", color = {1, 1, 1, 1}},
    {key = "mage_staff", label = "Mage Staff", atlas = "Crosshair_enchant_48", color = {1, 1, 1, 1}},
    {key = "fireball", label = "Fireball", atlas = "wowlabs_spellbucketicon-fireball", color = {1, 1, 1, 1}},
    {key = "question_mark", label = "Question Mark", atlas = "UI-LFG-RoleIcon-Pending", color = {1, 1, 1, 1}},
    {key = "transmog", label = "Transmog", atlas = "Crosshair_Transmogrify_48", color = {1, 1, 1, 1}},
    {key = "checkmark_glow", label = "Glowing Check Mark", atlas = "VAS-icon-checkmark-glw", color = {1, 1, 1, 1}},
    {key = "woons", label = "WOONS", atlas = "AzeriteArmor-Notification-Neck", color = {1, 1, 1, 1}},
    {key = "bag", label = "Bag", atlas = "shop-icon-mount-utility-up", color = {1, 1, 1, 1}},
    {key = "gold_medal", label = "Gold Medal", atlas = "challenges-medal-gold", color = {1, 1, 1, 1}},
    {key = "vault_slot", label = "Vault Slot", atlas = "mythicplus-dragonflight-greatvault-collect", color = {1, 1, 1, 1}},
    {key = "glowing_ball", label = "Glowing Ball", atlas = "CovenantSanctum-Renown-Next-Glow-Kyrian", color = {1, 1, 1, 1}},
}

H.POSITION_OPTIONS = {
    {key = "TOPLEFT",     label = "Top Left"},
    {key = "TOPRIGHT",    label = "Top Right"},
    {key = "BOTTOMLEFT",  label = "Bottom Left"},
    {key = "BOTTOMRIGHT", label = "Bottom Right"},
}

function H:GetIconInfo()
    local key = H.db.iconStyle or "arrow_green"
    for _, opt in ipairs(H.ICON_OPTIONS) do
        if opt.key == key then return opt end
    end
    return H.ICON_OPTIONS[1]
end
H.scanInProgress = false
H.charKey = nil -- set on ADDON_LOADED

------------------------------------------------------------------------
-- Slot ID → slot button name mapping
------------------------------------------------------------------------
H.EQUIP_SLOTS = {
    [1]  = "HeadSlot",
    [2]  = "NeckSlot",
    [3]  = "ShoulderSlot",
    [5]  = "ChestSlot",
    [6]  = "WaistSlot",
    [7]  = "LegsSlot",
    [8]  = "FeetSlot",
    [9]  = "WristSlot",
    [10] = "HandsSlot",
    [11] = "Finger0Slot",
    [12] = "Finger1Slot",
    [13] = "Trinket0Slot",
    [14] = "Trinket1Slot",
    [15] = "BackSlot",
    [16] = "MainHandSlot",
    [17] = "SecondaryHandSlot",
}

H.SLOT_NAMES = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Finger 1",
    [12] = "Finger 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

--- Create a stable cache key from an item link.
function H:ItemLinkToKey(itemLink)
    if not itemLink then return nil end
    local id = GetItemInfoInstant(itemLink)
    if not id then return nil end
    local stripped = itemLink:match("|Hitem:([%d:%-]+)|")
    return stripped or tostring(id)
end

------------------------------------------------------------------------
-- Scanning logic
------------------------------------------------------------------------

function H:ScanAllItems()
    if not C_ItemUpgrade then
        print("|cff00ccffUpgradeHelper|r: Item upgrade API not available")
        return
    end

    H.scanInProgress = true
    local found = 0
    local scanned = {}

    -- Scan equipped items
    for slotID, _ in pairs(H.EQUIP_SLOTS) do
        local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
        if itemLocation and itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation) then
            local ok, freeLevels, info = pcall(H.CheckItemUpgrade, H, itemLocation, slotID)
            if ok and freeLevels and freeLevels > 0 then
                local itemLink = C_Item.GetItemLink(itemLocation)
                local key = H:ItemLinkToKey(itemLink)
                if key then
                    info.itemLink = itemLink
                    scanned[key] = info
                    found = found + 1
                end
            end
        end
    end

    -- Scan bag items
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if itemLocation and itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation) then
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, itemEquipLoc = GetItemInfoInstant(itemLink)
                    if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" and itemEquipLoc ~= "INVTYPE_NON_EQUIP" then
                        local ok, freeLevels, info = pcall(H.CheckItemUpgrade, H, itemLocation, nil)
                        if ok and freeLevels and freeLevels > 0 then
                            local key = H:ItemLinkToKey(itemLink)
                            if key then
                                info.itemLink = itemLink
                                scanned[key] = info
                                found = found + 1
                            end
                        end
                    end
                end
            end
        end
    end

    H.db.charScannedItems[H.charKey] = scanned
    H.scannedItems = scanned
    H.scanInProgress = false

    if H.db.showScanMessage then
        print("|cff00ccffUpgradeHelper|r: Scan complete — " .. found .. " item(s) with free upgrades found")
    end

    if H.UpdateCharacterOverlays then
        H:UpdateCharacterOverlays()
    end
    if H.UpdateBagOverlays then
        H:UpdateBagOverlays()
    end
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh()
    end
    if H.bagnonHooked and H.bagnonAddon and H.bagnonAddon.SendSignal then
        H.bagnonAddon:SendSignal('UPDATE_ALL')
    end
end

--- Check a single item for crest-free upgrade levels.
--- Uses GetItemUpgradeItemInfo() which returns all upgrade data in one table.
--- An upgrade level is "free" if the only cost is gold (no crests / currencies).
--- Returns freeLevels, infoTable  or  nil, nil
function H:CheckItemUpgrade(itemLocation, slotID)
    local canUpgrade = C_ItemUpgrade.CanUpgradeItem(itemLocation)
    if not canUpgrade then
        return nil, nil
    end

    C_ItemUpgrade.SetItemUpgradeFromLocation(itemLocation)

    local itemInfo = C_ItemUpgrade.GetItemUpgradeItemInfo()
    if not itemInfo then
        C_ItemUpgrade.ClearItemUpgrade()
        return nil, nil
    end

    if not itemInfo.itemUpgradeable or not itemInfo.upgradeLevelInfos then
        C_ItemUpgrade.ClearItemUpgrade()
        return nil, nil
    end

    if itemInfo.currUpgrade >= itemInfo.maxUpgrade then
        C_ItemUpgrade.ClearItemUpgrade()
        return nil, nil
    end

    local currentIlvl = C_ItemUpgrade.GetItemUpgradeCurrentLevel() or itemInfo.minItemLevel

    local freeLevels = 0
    local freeMaxIlvl = currentIlvl

    for _, levelInfo in ipairs(itemInfo.upgradeLevelInfos) do
        -- Skip levels at or below current upgrade rank (includes the current level entry)
        if levelInfo.upgradeLevel <= itemInfo.currUpgrade then
            -- skip, this is current or already-passed level
        else
            -- An upgrade is "free" if the only cost is gold.
            -- Any non-discounted item costs or currency costs (crests) = not free.
            local hasNonGoldCost = false

            if levelInfo.itemCostsToUpgrade then
                for _, itemCost in ipairs(levelInfo.itemCostsToUpgrade) do
                    if itemCost.cost and itemCost.cost > 0 then
                        local di = itemCost.discountInfo
                        if not (di and di.isDiscounted and di.doesCurrentCharacterMeetHighWatermark) then
                            hasNonGoldCost = true
                        end
                    end
                end
            end

            if levelInfo.currencyCostsToUpgrade then
                for _, currCost in ipairs(levelInfo.currencyCostsToUpgrade) do
                    if currCost.cost and currCost.cost > 0 then
                        local di = currCost.discountInfo
                        if not (di and di.isDiscounted and di.doesCurrentCharacterMeetHighWatermark) then
                            hasNonGoldCost = true
                        end
                    end
                end
            end

            if hasNonGoldCost then
                break -- stop at first level that requires more than just gold
            end

            freeLevels = freeLevels + 1
            freeMaxIlvl = currentIlvl + (levelInfo.itemLevelIncrement or 0)
        end
    end

    C_ItemUpgrade.ClearItemUpgrade()

    if freeLevels == 0 then
        return nil, nil
    end

    return freeLevels, {
        slot = slotID,
        currentIlvl = currentIlvl,
        freeMaxIlvl = freeMaxIlvl,
        freeLevels = freeLevels,
        lastScanned = time(),
    }
end

------------------------------------------------------------------------
-- Event frame
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        UpgradeHelperDB = UpgradeHelperDB or {}
        if UpgradeHelperDB.showTooltips == nil then UpgradeHelperDB.showTooltips = true end
        if UpgradeHelperDB.showCharOverlays == nil then UpgradeHelperDB.showCharOverlays = true end
        if UpgradeHelperDB.showScanMessage == nil then UpgradeHelperDB.showScanMessage = true end
        if UpgradeHelperDB.autoScan == nil then UpgradeHelperDB.autoScan = true end
        if UpgradeHelperDB.iconStyle == nil then UpgradeHelperDB.iconStyle = "arrow_green" end
        if UpgradeHelperDB.iconPosition == nil then UpgradeHelperDB.iconPosition = "BOTTOMRIGHT" end

        -- Migrate old flat scannedItems to per-character storage
        if UpgradeHelperDB.scannedItems and next(UpgradeHelperDB.scannedItems) then
            -- Check if it's old-style (flat, not keyed by character)
            local firstKey, firstVal = next(UpgradeHelperDB.scannedItems)
            if type(firstVal) == "table" and firstVal.currentIlvl then
                -- Old format: flat item data — discard it (we don't know which char it belonged to)
                UpgradeHelperDB.scannedItems = nil
            end
        end

        UpgradeHelperDB.charScannedItems = UpgradeHelperDB.charScannedItems or {}
        local charKey = UnitName("player") .. "-" .. (GetNormalizedRealmName() or GetRealmName():gsub("%s", ""))
        H.charKey = charKey
        UpgradeHelperDB.charScannedItems[charKey] = UpgradeHelperDB.charScannedItems[charKey] or {}

        H.db = UpgradeHelperDB
        H.scannedItems = H.db.charScannedItems[charKey]

        -- Hook already-loaded bag addons
        if C_AddOns.IsAddOnLoaded("Baganator") then
            H:RegisterBaganatorWidget()
        end
        -- Bagnon uses ## Group: BagBrother, so check both names
        if C_AddOns.IsAddOnLoaded("Bagnon") or C_AddOns.IsAddOnLoaded("BagBrother") then
            H:HookBagnon()
        end

        frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    elseif event == "ADDON_LOADED" then
        if arg1 == "Baganator" then
            H:RegisterBaganatorWidget()
        elseif arg1 == "Bagnon" or arg1 == "BagBrother" then
            H:HookBagnon()
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if arg1 == Enum.PlayerInteractionType.ItemUpgrade then
            H:CreateScanButton()
            if H.db.autoScan then
                C_Timer.After(0.2, function() H:ScanAllItems() end)
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if H.UpdateCharacterOverlays then
            H:UpdateCharacterOverlays()
        end
    end
end)

------------------------------------------------------------------------
-- Scan button on the upgrade vendor frame
------------------------------------------------------------------------
function H:CreateScanButton()
    if H.scanButton then
        H.scanButton:Show()
        return
    end

    -- Wait a frame for the Blizzard UI to be fully loaded
    C_Timer.After(0.1, function()
        local parent = ItemUpgradeFrame
        if not parent then return end

        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(28, 28)
        btn:SetClipsChildren(false)
        btn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 25)
        parent:SetClipsChildren(false)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetAtlas("communities-icon-searchmagnifyingglass")
        btn.icon = icon

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetAtlas("communities-icon-searchmagnifyingglass")
        highlight:SetAlpha(0.4)

        btn:SetScript("OnClick", function()
            H:ScanAllItems()
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Scan Free Upgrades", 1, 1, 1)
            GameTooltip:AddLine("Scans all equipped and bag items to find upgrades that only cost gold (no crests).", nil,
                nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        H.scanButton = btn
    end)
end

------------------------------------------------------------------------
-- Lookup helper for tooltip / character frame
------------------------------------------------------------------------
function H:GetFreeUpgradeInfo(itemLink)
    if not itemLink then return nil end
    local key = H:ItemLinkToKey(itemLink)
    if not key then return nil end
    return H.scannedItems[key]
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_UPGRADEHELPER1 = "/upgradehelper"
SLASH_UPGRADEHELPER2 = "/uh"
SlashCmdList["UPGRADEHELPER"] = function(msg)
    local cmd = strlower(strtrim(msg))

    if cmd == "" or cmd == "status" then
        local count = 0
        for _ in pairs(H.scannedItems) do count = count + 1 end
        print("|cff00ccffUpgradeHelper|r: " .. count .. " item(s) with free upgrades cached")
        if count > 0 then
            for _, info in pairs(H.scannedItems) do
                local slotName = info.slot and H.SLOT_NAMES[info.slot] or "Bag"
                print("  " ..
                    (info.itemLink or "?") ..
                    " — " ..
                    slotName ..
                    " — " .. info.currentIlvl .. " → " .. info.freeMaxIlvl .. " (+" .. info.freeLevels .. " levels)")
            end
        end
    elseif cmd == "scan" then
        if C_ItemUpgrade and C_ItemUpgrade.GetItemUpgradeItemInfo then
            H:ScanAllItems()
        else
            print("|cff00ccffUpgradeHelper|r: Must be at an upgrade vendor to scan")
        end
    elseif cmd == "reset" then
        wipe(H.db.charScannedItems[H.charKey])
        wipe(H.scannedItems)
        H.db.scannedItems = nil -- clear legacy shared data
        if H.UpdateCharacterOverlays then H:UpdateCharacterOverlays() end
        print("|cff00ccffUpgradeHelper|r: Cached data cleared")
    elseif cmd == "settings" or cmd == "config" then
        if H.settingsCategory then
            Settings.OpenToCategory(H.settingsCategory:GetID())
        end
    else
        print("|cff00ccffUpgradeHelper|r: /uh [status|scan|reset|settings]")
    end
end

------------------------------------------------------------------------
-- Export global
------------------------------------------------------------------------
UpgradeHelper = H
