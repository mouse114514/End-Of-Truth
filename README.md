# End Of Truth

An **Undertale** fan game built with **Godot 4.3**.

> *"The truth will set you free — but first, it will shatter everything."*

---

## Features

### ⚔️ Battle System
- Turn-based + bullet hell hybrid combat (Undertale-style)
- Triple flash-black transition on battle start
- 7 SOUL modes (Determination, Patience, Bravery, Justice, Kindness, Integrity, Perseverance)
- Soul shatter death animation with skippable GAME OVER sequence
- Invincibility frames after taking damage
- Dynamic HP bar with label display

### 🔫 Bullet Hell System
- Multiple attack patterns: circle, spiral, aimed, random, boomerang, and more
- ContinuousBulletEmitter: path-interpolated multi-shot emitter with arc / reverse / boomerang tags
- Area2D-based collision detection
- Configurable damage values
- Timeline-driven bullet patterns (JSON-based)

### 📖 Story & Dialogue System
- **StoryManager** — global autoload singleton
- **Timeline system** — JSON-driven event timelines (`timelines.json`)
- **Desktop-first editing** — `timeline_editor.gd` reads/writes `~/Desktop/au_timelines.json` directly
- **Rich text tags** — floating, color, rainbow, rotation, scaling, strikethrough (see Dialog Tags below)
- **Investigation system** — interactive hotspots with dialog bubbles
- **StoryRegions** — area-triggered story events
- **Opening cinematic** — 10-phase intro sequence with MV, credits, and void credits

### 🧩 Puzzle System
- **PuzzleManager** — global autoload singleton
- **PuzzleBlock** — pushable blocks
- **PuzzleSwitch** — trigger mechanisms
- **PuzzleDoor** — lock/unlock mechanisms

### ⚡ QTE System
- Quick Time Events with dynamic generation
- Keyboard + mobile input support

### 🎨 Visual Effects
- Grayscale shader for special scenes
- High-contrast grayscale shader for character portraits
- Rainbow color cycling effect
- Wave / tornado floating animations
- Damage flash effect
- Transition effects (fade-to-black, flash, shatter, brighten)

### 🔊 Audio System
- **SoundManager** — global autoload singleton
- Dynamic SFX for damage, death, bullet collision, dialogue, and more
- BGM system with crossfade support

### 📱 Mobile Support
- **Virtual joystick** (drag with auto-repeat discrete direction)
- **D-Pad buttons** (switchable in settings)
- **MobileInput** autoload — unified touch input handling
- **Two control modes**: buttons (D-Pad) or joystick (toggle in Settings)
- Auto-detect keyboard vs touch input
- Multi-touch support with touch index tracking

### 🛠️ Timeline Editor (Developer Tool)
- Desktop JSON file as source of truth (`~/Desktop/au_timelines.json`)
- Visual timeline playback with pause/resume/replay
- Action inspector with full parameter editing
- **ContinuousBulletEmitter** editor panel — set start position, key positions, targets, move duration, emit count, special tags
- Path visualization: red arrow markers, red square targets, green path lines, yellow target lines
- Drag-to-reposition markers for muzzle positions and targets
- Backup from project file / write to project file
- Right-click action menu (insert, duplicate, delete, reorder)

---

## Dialog Tags

Embed effects in dialog text using `§[tag]<text>` syntax:

| Tag | Effect | Example |
|-----|--------|---------|
| `fl` | Floating text | `§[fl]<float>` |
| `co(R,G,B)` | Color (RGB 0-255) | `§[co(255,0,0)]<red>` |
| `ra` | Rainbow cycle | `§[ra]<rainbow>` |
| `ro` | Continuous rotation | `§[ro]<spin>` |
| `sh` | Scale up | `§[sh]<big>` |
| `no` | Strikethrough | `§[no]<nope>` |

### Combined Example:
```
§[fl,co(255,0,0),sh]<This is important!>
```

Tags are comma-separated and applied in order.

---

## Controls

### Keyboard

| Key | Action |
|-----|--------|
| Arrow keys / WASD | Move |
| Z | Investigate / Confirm / Skip death animation |
| X | Close dialog / Slow move (hold in battle) |

### Mobile

| Control | Action |
|---------|--------|
| Virtual joystick / D-Pad | Move |
| Virtual buttons | Investigate / Confirm |
| Tap | Interact |

### Mobile Input Integration

To receive mobile directional input, any node must:

```gdscript
func _ready():
    add_to_group("player")                    # 1. Register to "player" group

func handle_mobile_input(input_vec: Vector2): # 2. Implement this method
    mobile_dir = input_vec.x                  # MobileInput calls this automatically
```

- **Direction input**: Join `"player"` group + implement `handle_mobile_input`. See: `character_body_2d.gd`, `player_soul.gd`, `opening_sequence.gd`
- **Confirm/Investigate**: Mobile buttons trigger `Input.action_press("investigate")` — just check `Input.is_action_just_pressed("investigate")`
- **Menu/UI scenes**: Connect `direction_input` and `investigate_pressed` signals directly. See: `main_menu.gd`, `settings_menu.gd`, `canvas_c.gd`

---

## Project Structure

### Autoload Singletons
- `BattleManager.gd` — Battle flow management
- `GameSettings.gd` — Game configuration (story mode, battle mode, speed mode, mobile control mode)
- `MobileInput.gd` — Mobile input manager (joystick + D-Pad)
- `PuzzleManager.gd` — Puzzle logic
- `SoundManager.gd` — Audio management
- `StoryManager.gd` — Story/dialogue management

### Core Systems
- `player_soul.gd` — SOUL system (7 modes, movement, collision, death animation)
- `enemy.gd` — Enemy base class with `create_bullet()`, `create_boomerang_bullet()`
- `enemy_defs.gd` — Enemy catalog loader (`enemy_catalog.json`)
- `bullet.gd` / `bullet.tscn` — Bullet base class
- `bullet_hell_scene.gd` / `bullet_hell_scene.tscn` — Battle scene
- `attack_patterns.gd` — Attack pattern definitions, loads timeline JSON
- `continuous_emitter.gd` — Path-interpolated multi-shot bullet emitter
- `boomerang_bullet.gd` / `boomerang_bullet.tscn` — Boomerang bullet

### Story & Dialogue
- `canvas_c.gd` — Dialog box system (with tag parsing)
- `timeline_editor.gd` / `timeline_editor.tscn` — Timeline editor
- `timeline_track.gd` — Timeline track
- `timelines.json` — Timeline data
- `stories/all_stories.gd` — Story function definitions
- `StoryRegion.gd` / `StoryRegion.tscn` — Area-triggered stories
- `InvestigationArea.gd` / `InvestigationArea.tscn` — Investigation hotspots
- `InvestigationDialog.tscn` — Investigation dialog UI

### Opening & Credits
- `opening_sequence.gd` / `opening_sequence.tscn` — 10-phase opening cinematic
- `void_credits` — Walking into the void shows credits and exits

### UI
- `main_menu.gd` / `main_menu.tscn` — Main menu
- `settings_menu.gd` / `settings_menu.tscn` — Settings (audio, modes, mobile control)
- `battle_preview.gd` / `battle_preview.tscn` — Battle preview
- `health_bar.gd` — HP bar
- `progress_bar.gd` — Progress bar
- `ui/virtual_joystick.gd` — Virtual joystick component
- `ui/virtual_button.gd` — Virtual button component
- `ui/joystick_input.gd` — Joystick input handler

### Visual Effects
- `wave_effect.gd` / `wave_effect.tres` — Wave float animation
- `tornado_effect.gd` / `tornado_effect.tres` — Tornado spin animation
- `rainbow_effect.gd` / `rainbow_effect.tres` — Rainbow color cycling
- `strike_effect.gd` — Strike/impact effect
- `grayscale_shader.gdshader` — Grayscale shader
- `grayscale_high_contrast.gdshader` — High-contrast grayscale shader

### Triggers & Zones
- `forced_encounter_trigger.gd` / `forced_encounter_trigger.tscn` — Scripted encounter trigger
- `VisibilityOccluder.gd` / `VisibilityOccluder.tscn` — Visibility occluder
- `Collectible.gd` — Collectible items
- `action_drag_button.gd` — Action drag button

### Other
- `character_body_2d.gd` — Player character body
- `area_2d.gd` — Base area class
- `node_2d.gd` / `node_2d.tscn` — Base 2D node
- `canvas_layer.gd` — Canvas layer
- `tell.gd` — Notification system

### Resource Directories
- `android/` — Android platform resources
- `bullets/` — Bullet textures
- `font/` — Font files
- `look_tscn/` — Look/scene preview assets
- `map/` — Map assets (tiles, walls, backgrounds)
- `music/` — BGM and SFX
- `MV/` — Opening MV assets
- `player/` — Player sprites (walk, battle, EAIM menu)

---

## How to Run

### Requirements
- [Godot 4.3](https://godotengine.org/) or later

### Steps
1. Clone or download this repository
2. Open the project in Godot 4.3 (select `project.godot`)
3. Press **F5** or click the **Run** button
4. Main scene: `main_menu.tscn`

### For Mobile Export
- Install Android/iOS export templates
- Configure export in **Project → Export**
- See `export_presets.cfg` for existing configurations

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Engine | Godot 4.3 |
| Language | GDScript |
| Renderer | Mobile (optimized for mobile devices) |
| Platforms | Windows, Android, iOS, Web (theoretically) |

---

## License

### Code
This project's code is licensed under **GNU General Public License v3.0** — see [LICENSE](LICENSE).

### Assets & IP
**End Of Truth** is a non-official fan game.

- **Original & derivative assets**: Artwork, character designs, music, and sound effects are a mix of original creations and fan-made derivatives.
- **Undertale content**: Only the map tile assets are directly ported from Undertale.
- **Undertale** is the property of **Toby Fox**.

This is a fan project created out of passion and respect for the original work. It is not affiliated with or endorsed by Toby Fox.

---

## Credits

### Core Team
- **Xmouse** — Programming & Post-production
- **克斯里德** — Art & Story
- **EmoCez** — Textures & Sound Effects
- **Xx_出c好吃_xX** — Music & Operations
- **飞** — Debug & Music

### Special Thanks
- **青龙狱碧** — Textures
- **粥伞** — Textures
- **Toby Fox** — Creating Undertale
- **Godot Engine Team** — The open-source game engine

---

## Development Status

**Active development** 🚧

---

*"Despite everything, it's still you."*
