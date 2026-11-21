<p align="center">
  <img src="docs/logo.png" alt="Fray logo" width="128" height="128">
</p>

<h1 align="center">Fray</h1>

<p align="center">
  A live enemy list for <strong>World of Warcraft: Forever</strong> - threat, aggro alerts and cast bars,<br>
  built from Blizzard's own unit frame art.
</p>

---

## What it does

Fray shows the enemies you are actually fighting - and only those - as a compact list of frames that looks like
the game's own target frame. It re-sorts live, closes gaps when an enemy dies and tells you when aggro changes hands.

### Enemy list
- Frames built from Blizzard's unit frame atlases (mirrored, portrait on the left): name banner, health bar, resource bar
  (mana, rage, energy, ...), real portrait and raid marker.
- **Aggro shield** next to the portrait in the colour of your threat state (red: you have aggro, orange: lost it, green: safe).
- Elite and rare markers, a separate cast strip below each frame, and a golden outline for your current target.
- Shows only enemies fighting you or your group - mobs another player is fighting stay hidden.
- Sorting by threat or name, maximum rows, rows per column, and switches for every element.

### Alerts
- Aggro gained, aggro lost, high threat and low health, each with its own on/off switch, sound and threshold.
- Conditions (group only, combat only), a pause per enemy, duration, font size and scale.
- Test buttons for every alert.

### More
- Target and focus **cast bars** using Blizzard's casting bar art.
- A settings window styled like the game menu, a frame mover with grid and live coordinates, global and per-element scale,
  frame colour presets (copper, silver, gold) and a test mode.

## Requirements

- World of Warcraft: Forever (interface 16001). The TOC also lists 20506 and 20505, but those clients are untested.
- Enemy nameplates must be enabled (`/fray plates` turns them on).

## Installation

1. Download the latest release or clone this repository.
2. Place the folder in `World of Warcraft\_forever_\Interface\AddOns\` so that it is called exactly **`Fray`**
   (it must contain `Fray.toc`).
3. Start the game (or `/reload`) and enable *Fray* in the addon list.

## Usage

Type `/fray` to open the settings window.

| Command | What it does |
|---|---|
| `/fray` | Open the settings |
| `/fray unlock` / `lock` | Move the frames (drag the blue overlays; hold Alt for free placement) |
| `/fray grid [on\|off\|<px>]` | Toggle the snap grid |
| `/fray reset` | Reset all frame positions |
| `/fray toggle <module>` | Enable or disable a module (`enemy`, `cast`, `alerts`) |
| `/fray tank` | Tank mode |
| `/fray all` | Show all hostile units, not only those in combat |
| `/fray plates` | Enable enemy nameplates |
| `/fray test` | Show placeholder frames and a test alert |
| `/fray probe` | Print what the client exposes to addons (for bug reports) |

## Known limitations

- **No click-to-target.** Addon code cannot change your target, and secure frames cannot follow a list that re-sorts in
  combat, so the frames are display only.
- **Secret values.** In combat the client hides some values (e.g. threat numbers on nameplates). Fray only uses what is
  readable; where threat is hidden it falls back to "is this enemy targeting you".
- The Blizzard art is loaded from the game client by name. If your client does not have an atlas, Fray falls back to its
  own textures. Fonts always come from the client.

## Credits and licences

- Fray is released under the [MIT License](LICENSE).
- Fray contains no third-party assets. Its textures were created for this project; text and titles use the game's own fonts.
- Fray does not ship Blizzard art; it only refers to the client's interface graphics by name (the game loads them).
- *World of Warcraft* is a trademark of Blizzard Entertainment, Inc. This project is not affiliated with or endorsed by Blizzard.

<br>

<sub>Disclaimer: this addon was created with the help of Claude Code (Anthropic).</sub>
