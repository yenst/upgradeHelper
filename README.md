# UpgradeHelper

A World of Warcraft addon that tells you which items can be upgraded **for free** (without crests — only Valorstones).

## What It Does

In The War Within, if you've ever had a higher item level piece in an equipment slot, you can upgrade lower-ilvl items in that slot without spending crests. The game only shows this at the upgrade vendor one item at a time. **UpgradeHelper** makes this visible everywhere:

- **On the character pane**: Green arrow indicators on equipment slots that have free upgrades available
- **At the upgrade vendor**: Automatically scans all your items and reports which have free upgrades
- **In tooltips**: Adds a line showing free upgrade potential on item tooltips
- **In chat**: Summary of all free upgrades available after scanning

## How It Works

When you visit an upgrade vendor, UpgradeHelper scans all your upgradeable items and checks the crest cost via the `C_ItemUpgrade` API. Items where the crest cost is 0 (but Valorstone cost > 0) are flagged as "free upgrades." Results are cached so the information persists after leaving the vendor.

## Installation

1. Copy the `UpgradeHelper` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory
2. Restart WoW or type `/reload` if already in-game
3. Visit any upgrade vendor to populate the scan data

## Slash Commands

- `/uh` or `/upgradehelper` — Print scan summary
- `/uh scan` — Force a rescan (must be at upgrade vendor)
- `/uh reset` — Clear cached data
- `/uh settings` — Open settings panel

## Settings

Available in WoW Settings > AddOns > UpgradeHelper:
- **Show Tooltips** — Toggle free upgrade info in item tooltips
- **Show Character Pane Overlays** — Toggle green arrows on character frame equipment slots
- **Show Scan Message** — Toggle chat message after scan completes

## Requirements

- World of Warcraft: The War Within (Retail)
- Must visit an upgrade vendor at least once to populate data
