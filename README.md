<p align="center">
  <img src="docs/logo.png" alt="Fray logo" width="128" height="128">
</p>

<h1 align="center">Fray</h1>

<p align="center"><em>Your Enemies, but listed</em></p>

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
- **Aggro shield**: Fray's shield at each portrait in the aggro colour (red and pulsing: the enemy is on you, orange: you just lost it or have high threat, green: safe).
- Elite and rare markers, a separate cast strip below each frame, and a golden outline for your current target.
- Shows only enemies fighting you or your group - mobs another player is fighting stay hidden.
- Your own debuffs on each enemy (up to four, with stacks and remaining time), a heading with the number of enemies and the enemy's tooltip on mouseover.
- Reads every nameplate, the boss frames and the targets of your group or raid.
- Sorting by pull order (default), threat or name, maximum rows, rows per column, and switches for every element.

### Alerts
- Aggro gained, aggro lost, high threat and low health, each with its own on/off switch, sound and threshold.
- Conditions (group only, combat only), a pause per enemy, duration, font size and scale.
- Test buttons for every alert.

### More
- Target and focus **cast bars** built from Blizzard's casting bar (background, fill for casts, channels and uninterruptible casts, spark and frame), red "Interrupted" and a fade-out at the end; casts of your own group are hidden by default.
- A classic minimap button with the Fray logo, the same frame as Mundi's (left click: options, right click: lock/unlock frames; can be hidden), and an entry in the addon compartment. Mundi can collect the button into its addon button window.
- Role per character (automatic, tank, damage or healer) and optional own settings per character.
- Settings built into the game's own options (Esc > Options > AddOns > Fray, with the pages Enemy list, Cast bars, Alerts and Actions; laid out like Mundi's), a frame mover with grid and live coordinates, global and per-element scale and a test mode.
- English and German.

## Requirements

None besides the game client (World of Warcraft: Forever). Enemy nameplates have to be switched on in the game settings; `/fray plates` does it for you.

## Installation

1. Download the latest release or clone this repository.
2. Place the folder in `World of Warcraft\_forever_\Interface\AddOns\` so that it is called exactly **`Fray`**
   (it must contain `Fray.toc`).
3. Start the game (or `/reload`) and enable *Fray* in the addon list.

## Usage

Type `/fray` to open the settings (Esc > Options > AddOns > Fray). Buttons such as unlocking frames, test mode and
resetting everything are on the **Actions** page below it.

| Command | What it does |
|---|---|
| `/fray` | Open the settings |
| `/fray help` | List all commands |
| `/fray unlock` / `lock` | Move the frames (drag the blue overlays; hold Alt for free placement) |
| `/fray test` | Show placeholder frames and a test alert |
| `/fray plates` | Enable enemy nameplates |
| `/fray reset` | Reset all settings (asks first) |

Everything else (tank mode, modules, grid, single options) is in the settings.

## Known limitations

- **No click-to-target.** Addon code cannot change your target, and secure frames cannot follow a list that re-sorts in
  combat, so the frames are display only.
- **Secret values.** In combat the client hides some values (e.g. threat numbers on nameplates). Fray only uses what is
  readable; where threat is hidden it falls back to "is this enemy targeting you".
- The Blizzard art is loaded from the game client by name. Without Blizzard's target frame art the enemy list stays off
  (and says so in chat). Fonts always come from the client.

## Credits and licences

- Fray is released under the [MIT License](LICENSE).
- Fray contains no third-party assets. Fray's own files (logo, aggro shields and an invisible bar mask) were made for Fray; everything else is the game's own interface art and fonts.
- Fray does not ship Blizzard art; it only refers to the client's interface graphics by name (the game loads them).
- *World of Warcraft* is a trademark of Blizzard Entertainment, Inc. This project is not affiliated with or endorsed by Blizzard.

<br>

<sub>Disclaimer: this addon was created with the help of Claude Code (Anthropic).</sub>
