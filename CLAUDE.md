# UpgradeHelper - WoW Addon

## Project Overview
A World of Warcraft addon that shows players which items can be upgraded for free (without crests) based on their high-watermark item level per equipment slot.

## Development Guidelines

### API Documentation
- **Always check Context7** for any WoW API / library functions before using them. The WoW API changes frequently between patches and Context7 provides up-to-date documentation.
- Primary reference: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- UI source reference: https://github.com/Gethe/wow-ui-source

### Code Style & Patterns (match MDTHelper)
- **No frameworks** — No Ace3, AceConfig, AceDB, AceGUI, LibStub. Pure WoW API only.
- **Namespace pattern** — `local AddonName, NS = ...` then `local H = NS`, export global at end.
- **Direct SavedVariables** — Simple `UpgradeHelperDB` table with per-key defaults in `ADDON_LOADED`.
- **Settings panel** — Use `Settings.RegisterCanvasLayoutCategory()` with `MakeCheckbox()` / `MakeSlider()` helpers (same pattern as MDTHelper/Settings.lua).
- **Event handling** — `CreateFrame("Frame")` with `RegisterEvent` / `SetScript("OnEvent", ...)`. Unregister `ADDON_LOADED` after init.
- **Slash commands** — `SLASH_UPGRADEHELPER1`, `SlashCmdList["UPGRADEHELPER"]` with `strlower(strtrim(msg))` parsing.
- **Error handling** — Wrap external/uncertain API calls in `pcall()`.
- **Print format** — `"|cff00ccffUpgradeHelper|r: message"` for addon messages.
- **No libraries** — All UI built with native `CreateFrame()`, `CreateFontString()`, etc.

### Reference Addon
- See `C:\Users\Jens Thiel\Documents\projects\mdt_helper\MDTHelper\` for the reference implementation of settings, UI patterns, and code conventions.

### Key API Namespaces
- `C_ItemUpgrade` — Core namespace for upgrade cost queries and high-watermark detection
- `C_Item` — Item info and item level queries
- `C_Container` — Bag scanning
- `C_CurrencyInfo` — Currency ID validation (crest/valorstone IDs change per season)

### Important Constraints
- `C_ItemUpgrade` functions mostly only work when the upgrade vendor UI is open
- High-watermark is tracked server-side (includes deleted/disenchanted items) — manual bag scanning alone is insufficient
- Crest and Valorstone currency IDs change each season — detect dynamically or maintain a lookup
- Test with `/dump C_ItemUpgrade` in-game to verify function availability in current patch
