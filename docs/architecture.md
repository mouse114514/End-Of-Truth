# Architecture Overview

## Autoload Singletons (Global)

```
BattleManager  — Battle lifecycle (start, end, state save/restore)
GameSettings   — Config toggles (story mode, battle mode, speed mode, mobile control mode)
MobileInput    — Touch input routing (joystick / D-Pad)
PuzzleManager  — Puzzle state tracking
SoundManager   — Audio playback and crossfade
StoryManager   — Story/dialogue flow control
```

## Scene Tree (Runtime)

```
Main (main_menu.tscn)
├── Settings (settings_menu.tscn)
├── OpeningSequence (opening_sequence.tscn)
├── World (node_2d.tscn)
│   ├── Player (character_body_2d.gd)
│   ├── Map (map_tile_manager.gd)
│   ├── StoryRegions
│   ├── InvestigationAreas
│   └── Encounters
├── Battle (bullet_hell_scene.tscn)
│   ├── Soul (player_soul.gd)
│   ├── Enemy (enemy.gd)
│   ├── Bullets
│   └── UI (health_bar, battle_preview)
└── MobileInput Overlay (virtual joystick / D-Pad)
```

## Battle Flow

1. `forced_encounter_trigger.gd` detects overlap → calls `BattleManager.start_battle(enemy_id)`
2. `BattleManager` saves world state → adds `bullet_hell_scene.tscn` as child of root
3. Battle scene runs attack patterns from `timelines.json` via `attack_patterns.gd`
4. On victory/defeat → `BattleManager.end_battle()` restores world state, removes battle scene

## Timeline System

- **Source of truth**: `~/Desktop/au_timelines.json` (desktop file, for editor)
- **Game runtime**: `attack_patterns.gd` reads desktop file fresh each enemy turn
- **Editor**: `timeline_editor.gd` — visual preview, marker drag, CE editor, save/load

## Mobile Input

```
Two modes (switchable in Settings):
├── Buttons (D-Pad) — Fixed directional buttons + action buttons
└── Joystick — Touch-drag analog stick with discrete auto-repeat
```

`MobileInput` autoload handles `_input` at global level → routes to player group via `handle_mobile_input()`.
