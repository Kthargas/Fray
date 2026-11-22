# Changelog

## 1.1.0 - 2026-11-22

- New: sort the enemy list by pull order (new default); threat and name still available.
- New: minimap button (left click: settings, right click: lock/unlock frames), can be hidden in the settings.
- Fixed: enemies no longer drop out of the list when they walk out of nameplate range while you are in combat.
- `/fray plates` now also raises the nameplate distance to 60 yards.
- Removed the combat text, cooldown bar and convenience (auto-sell/repair) modules to keep Fray focused on the enemy list.
- The whole addon, including the settings window, is now English.

## 1.0.0 - 2026-11-21

First public release.

- Enemy list built from Blizzard's own target frame art (mirrored, portrait on the left), with live threat/aggro
  shield, elite and rare markers, raid markers, health text, resource bar, a separate cast bar below each frame,
  selection outline, sorting by pull order (default), threat or name and configurable columns and row count.
- Aggro alerts: aggro gained, aggro lost, high threat, low health, with per-event sounds, conditions and a pause per enemy.
- Target and focus cast bars with Blizzard casting bar art.
- Settings window in the style of the game menu (`/fray`), frame mover with grid and coordinates, global and
  per-element scale, frame colour presets and a test mode.
- No third-party assets: Fray uses the game's own fonts and interface graphics, plus textures created for this project.
