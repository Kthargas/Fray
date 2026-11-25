# Changelog

## 1.3.0 - 2026-11-25

- Fixed: enemies were missing when there were many nameplates around. Only the first 12 nameplate slots were read, but the game hands them out in no particular order; now all of them are.
- New: boss frames (boss1 to boss5) and, in a raid, the targets of all raid members count as enemies too.
- Role per character: "Automatic" (tank by group role, specialisation, bear form or defensive stance), "Tank" or "Damage or healer". The old account-wide tank switch goes to the first character that logs in.
- Profiles: "Own settings for this character" gives a character its own copy of the settings; otherwise all characters share them.
- New: your own debuffs on every enemy (up to four, right of its frame), with Blizzard's debuff border, stacks and remaining time.
- New: heading "Enemies: 5" above the list, and the enemy's tooltip on mouseover (clicks still go through to the world). Both can be switched off.
- Enemies out of sight keep their last known health instead of an empty bar.
- The enemy list frame and its mover are only as large as the rows that can be shown.
- Cast bars like Blizzard's: an interrupted cast turns red with "Interrupted", and bars fade out at the end. The cast strip in the enemy list shows channels and casts that cannot be interrupted in Blizzard's colours.
- Alerts: two banners, so a new alert no longer wipes one that is still showing. Sounds use Blizzard's sound kits. Low health and high threat say once per session when the client hides the numbers they need, instead of silently never firing.

## 1.2.2 - 2026-11-25

- Tagline in the AddOn list: "Fray - Your Enemies, but listed".
- SquareMap is now called Mundi; the texts that mention it say so.

## 1.2.1 - 2026-11-25

- The aggro shield is back at every portrait (red and pulsing: aggro on you, orange: lost or high threat, green: little threat). Blizzard's threat glow around the frame is gone again.
- The alert banner shows the shield in the alert colour again instead of Blizzard's alert icon.
- The minimap button and the AddOn list show the Fray logo again.

## 1.2.0 - 2026-11-25

- Blizzard art only: the aggro shield is replaced by Blizzard's own threat glow of the target frame (red and pulsing: aggro on you, orange: lost or high threat). The cast bars, alert banner and minimap button use Blizzard's casting bar, alert icon and classic minimap button art. All of Fray's own textures are gone except an invisible bar mask; the "Frame colour" option is removed with them.
- German translation; settings, chat messages and alerts follow the game language.
- Settings laid out like SquareMap: Fray (role, appearance, frames), Enemy list, Cast bars, Alerts and Actions. The Actions page uses the same layout as SquareMap's.
- Slash commands like SquareMap: `/fray` opens the options, `/fray help` lists the commands, `/fray reset` asks before it resets everything (positions are reset on the Actions page). `grid`, `toggle`, `tank`, `all`, `opt`, `atlas`, `probe` and `debug` are removed; their settings are on the options pages.
- Minimap button looks like SquareMap's addon button and follows a square minimap edge; new entry in the addon compartment.
- Removed the fallback look for clients without Blizzard's unit frame art (custom plates, shields, glows), the unused settings-window code, and the login message. The TOC now targets WoW Forever only.

## 1.1.0 - 2026-11-25

- New: cast bars of yourself, party and raid members (and their pets) are hidden by default. Option "Hide casts of your group" under Cast bars, or `/fray opt hidegroup`.
- Changed: the settings now live in the game's own options window (Esc > Options > AddOns > Fray) with pages for Enemy list, Cast bars and Alerts, built from Blizzard's standard controls. The custom settings window is gone; `/fray` and the minimap button open the new page.
- Buttons (unlock frames, reset positions, test mode, test alerts, reset all) are on a separate "Actions" page so they cannot taint Blizzard's own settings buttons.

## 1.0.2 - 2026-11-22

- Fixed: an enemy that is tagged by you no longer drops out of the list when a player outside your group attacks it.
- New: warning when enemy nameplates are off (the list is built from them): big text on screen during combat and a chat message at every pull. Can be switched off in the Enemy list settings.

## 1.0.1 - 2026-11-22

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
