# Fray

Fray puts every enemy that is fighting you or your group into one list, styled like the game's own target frame. Each entry shows who is attacking you right now, so you see at a glance where aggro sits and which mob just turned on someone else.

## What you get

**One frame per enemy**
- Name, health bar with percent, resource bar (mana, rage, energy), portrait, raid marker, elite and rare markers.
- Blizzard's **threat glow** on every frame: red and pulsing = this enemy is on you, orange = it just left you, no glow = it is on someone else.
- A cast strip under each frame, so you see enemy casts without picking a target.
- Your current target gets a golden outline.
- Only enemies that are actually fighting you or your group are listed. Mobs that someone else is fighting stay out.
- Enemies stay listed when they run out of nameplate range while you are in combat. Dead ones drop out right away.

**Sorting**
- **Pull order** (default): the first mob you pulled stays on top, new ones are added below.
- By threat, or by name.
- Tank mode flips the logic: enemies that are not on you move to the top.

**Alerts**
- Banners with sound for: aggro gained, aggro lost, high threat, low health.
- Every alert can be switched off on its own, with its own sound and threshold.
- Optional: only in a group, only in combat, pause per enemy. Test buttons for each alert.

**Cast bars** for your target and focus, built from Blizzard's casting bar.

**English and German.**

**Minimap button** in the classic Blizzard look, plus an entry in the addon compartment. Left click opens the settings, right click locks or unlocks the frames. It can be hidden in the settings.

**Layout**
- Move every frame with `/fray unlock` (snap grid, live coordinates, Alt for free placement), then `/fray lock`.
- Scale all frames together or each one separately.
- Choose how many enemies are shown and how many per column.

## Commands
- `/fray` opens the settings
- `/fray unlock` / `/fray lock` move the frames
- `/fray plates` turns on enemy nameplates
- `/fray test` shows placeholder frames and a test alert for 20 seconds
- `/fray reset` resets all settings (asks first)
- `/fray help` lists all commands

## Good to know
- Enemy nameplates have to be on, Fray reads its enemies from them. `/fray plates` switches them on and sets the nameplate distance to 60 yards.
- The frames are display only, clicking them does not target an enemy. The game does not let addons change your target, and the list re-sorts too often for secure buttons.
- In combat the game hides some threat values on nameplates. Where that happens, Fray falls back to "is this enemy targeting you?" for the glow and alerts.

Source code and bug reports: https://github.com/Kthargas/Fray

*Created with the help of Claude Code (Anthropic).*
