# UpgradeHelper — Technical Design

## Architecture Overview

Follows the same structure and patterns as MDTHelper — no frameworks, pure WoW API, direct SavedVariables.

```
UpgradeHelper/
  UpgradeHelper.toc          -- Addon metadata and file list
  Core.lua                   -- Namespace init, ADDON_LOADED, events, slash commands, scanning logic
  Tooltip.lua                -- GameTooltip hook to display free upgrade info
  CharacterFrame.lua         -- Green arrow overlays on character pane equipment slots
  Settings.lua               -- WoW Settings panel (MakeCheckbox/MakeSlider pattern)
```

## Namespace Pattern

```lua
local AddonName, NS = ...
local H = NS

H.db = {}
H.scannedItems = {}

-- ... addon logic ...

UpgradeHelper = H  -- export global
```

## SavedVariables

```lua
-- TOC: ## SavedVariables: UpgradeHelperDB

-- In ADDON_LOADED:
UpgradeHelperDB = UpgradeHelperDB or {}
if UpgradeHelperDB.showTooltips == nil then UpgradeHelperDB.showTooltips = true end
if UpgradeHelperDB.showScanMessage == nil then UpgradeHelperDB.showScanMessage = true end
H.db = UpgradeHelperDB
```

### Data Model

```lua
UpgradeHelperDB = {
    -- Settings
    showTooltips = true,        -- show free upgrade info in tooltips
    showCharOverlays = true,    -- show green arrows on character pane slots
    showScanMessage = true,     -- print message after scan completes

    -- Cached scan data (populated at upgrade vendor)
    scannedItems = {
        ["itemLink"] = {
            slot = 1,                   -- equipment slot ID
            currentIlvl = 619,          -- current item level
            freeMaxIlvl = 626,          -- highest ilvl reachable without crests
            freeLevels = 2,             -- number of crest-free upgrade steps
            valorstoneCost = 300,       -- total valorstone cost for free levels
            lastScanned = 1711234567,   -- timestamp
        },
    },
}
```

## Core Mechanics

### 1. Scan Phase (at upgrade vendor)

When the player opens the upgrade vendor (`ITEM_UPGRADE_MASTER_OPENED` event):

1. Iterate through all equipment slots (1-17) and all bag items
2. For each upgradeable item:
   a. Call `C_ItemUpgrade.SetItemUpgradeFromLocation(itemLocation)`
   b. Call `C_ItemUpgrade.GetItemUpgradeCurrencyCost()` to get costs
   c. Check if crest currencies have cost = 0
   d. Record: itemLink, current ilvl, max free ilvl, number of free levels, slot
3. Store results in SavedVariables for persistence across sessions
4. Print summary: "Scan complete: X items with free upgrades found"

### 2. Crest Detection

Crest currency IDs change per season. Strategy for dynamic detection:
- Maintain a known list of crest currency IDs as a fallback
- On scan, identify which returned currency IDs are crests vs. valorstones by checking `C_CurrencyInfo.GetCurrencyInfo()` and matching against known crest category/names
- Valorstones are always the "base" currency; crests are the "bonus" currency

### 3. Tooltip Integration

Hook `GameTooltip` via `TooltipDataProcessor.AddTooltipPostCall`:
- When a tooltip shows an item, look up the item in the cache
- If free upgrades are available, append a green line: "Free upgrade available (+X levels)"
- If no data cached, show gray text: "Visit upgrade vendor to scan"

### 4. Character Pane Overlays

Hook into `PaperDollFrame` to show indicators on equipped items that have free upgrades.

**Slot button names:**
```
CharacterHeadSlot (1)       CharacterNeckSlot (2)
CharacterShoulderSlot (3)   CharacterChestSlot (5)
CharacterWaistSlot (6)      CharacterLegsSlot (7)
CharacterFeetSlot (8)       CharacterWristSlot (9)
CharacterHandsSlot (10)     CharacterFinger0Slot (11)
CharacterFinger1Slot (12)   CharacterTrinket0Slot (13)
CharacterTrinket1Slot (14)  CharacterBackSlot (15)
CharacterMainHandSlot (16)  CharacterSecondaryHandSlot (17)
```

**Implementation:**
1. For each slot button, create a green arrow overlay texture (hidden by default)
2. On `PLAYER_EQUIPMENT_CHANGED` or when scan data updates, call `H:UpdateCharacterOverlays()`
3. For each slot, get the equipped item link via `GetInventoryItemLink("player", slotID)`
4. Look up the item in `H.db.scannedItems` — if it has `freeLevels > 0`, show the green arrow
5. Arrow overlay: small green upward arrow icon in the corner of the slot button
6. Hovering the arrow shows a mini-tooltip: "Free upgrade: 619 → 626 (+2 levels)"
7. Only update when `CharacterFrame:IsShown()` to avoid unnecessary work

**Refresh triggers:**
- `PaperDollFrame` `OnShow` — refresh all overlays
- `PLAYER_EQUIPMENT_CHANGED` — refresh the changed slot
- After a scan completes — refresh all overlays

### 5. Settings Panel

Same pattern as MDTHelper/Settings.lua:
- `Settings.RegisterCanvasLayoutCategory()` with canvas frame
- `MakeCheckbox()` for toggles (show tooltips, show scan messages)
- `MakeSlider()` if any numeric settings needed
- `OnCommit`, `OnDefault`, `OnRefresh` callbacks (empty)

### 5. Slash Commands

```
/uh or /upgradehelper
/uh scan       -- Force rescan (must be at vendor)
/uh reset      -- Clear cached data
/uh settings   -- Open settings panel
/uh status     -- Print scan summary
```

## Events

| Event | Action |
|-------|--------|
| `ADDON_LOADED` | Init SavedVariables, register other events, unregister self |
| `ITEM_UPGRADE_MASTER_OPENED` | Auto-scan all items for free upgrades |
| `ITEM_UPGRADE_MASTER_CLOSED` | Finalize scan |
| `PLAYER_EQUIPMENT_CHANGED` | Mark cache as potentially stale, refresh character pane overlays |

## Implementation Phases

### Phase 1: Core + Tooltips + Character Pane
- TOC file
- Core.lua: namespace, events, SavedVariables, slash commands, scanning
- Tooltip.lua: GameTooltip hook
- CharacterFrame.lua: green arrow overlays on character pane equipment slots
- Settings.lua: WoW Settings panel

### Phase 2: Polish
- Stale data warnings (e.g. item changed since last scan)
- Per-slot summary in chat
