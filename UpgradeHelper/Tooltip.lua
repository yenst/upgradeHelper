local AddonName, NS = ...
local H = NS

------------------------------------------------------------------------
-- Tooltip hook — append free upgrade info to item tooltips
------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip, data)
    if not H.db.showTooltips then return end
    if not data or not data.id then return end

    -- Get the item link from the tooltip
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    if not itemLink then return end

    local info = H:GetFreeUpgradeInfo(itemLink)
    if info then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(
            "|cff00ff00Free upgrade|r",
            info.currentIlvl .. " > " .. info.freeMaxIlvl .. "  (+" .. info.freeLevels .. ")",
            nil, nil, nil, 1, 1, 1
        )
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)
