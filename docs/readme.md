# Breakout — Modern Retro Breakout Game

A modern breakout game inspired by Atari's classic, built with **Godot 4.x** featuring neon visuals, 6 power-up types, 5 progressive levels + endless mode, and boss bricks.

---

## Quick Start

1. Open `project.godot` in **Godot 4.x**
2. Press **F5** or click **Run** to start
3. Use **A/D** or **Arrow Keys** to move paddle
4. Press **Space** or **Click** to launch ball

---

## Features

| Feature | Description |
|---------|-------------|
| **Power-ups** | 6 types: Multiball, Big Paddle, Sticky, Laser, Slow Balls, Extra Life |
| **Levels** | 5 hand-crafted layouts with progressive difficulty → Endless mode |
| **Brick HP** | Standard (1 HP), Metal (3 HP, animated), Boss (5 HP, pulsing) |
| **Visuals** | Neon palette (cyan/magenta/lime on dark), glow shaders, particle FX |
| **Controls** | Keyboard (A/D, Arrows, Space) or mouse click/touch drag |
| **Audio** | Synthesized sound effects (brick hit, paddle hit, launch, etc.) |
| **High Scores** | Persistent to local file |

---

## Controls

| Action | Keys |
|--------|------|
| **Move Left** | `A` or `←` |
| **Move Right** | `D` or `→` |
| **Launch Ball** | `Space` or `Left Click` |
| **Pause** | `Escape` |
| **Restart** | `Confirm` after game over |
| **Mute** | `M` |

---

## Power-up Reference

| Icon | Type | Effect | Duration |
|------|------|--------|----------|
| **M** | Multiball | Spawns 2 clones per ball | — |
| **B** | Big Paddle | 1.6× width expansion | 8 sec |
| **S** | Sticky | Catches ball, next click launches | 8 sec |
| **L** | Laser | Auto-fires beams every 0.3s | 8 sec |
| **↓** | Slow Balls | Ball speed reduced to 60% | 8 sec |
| **♥** | Extra Life | +1 life | — |

---

## Level Progression

| Level | Name | Bricks | Speed | Special |
|-------|------|--------|-------|---------|
| 1 | Opening Volley | 8×4 | 1.0× | — |
| 2 | Controlled Angles | 10×5 | 1.1× | — |
| 3 | Metal Core | 10×6 | 1.2× | Metal (3 HP) |
| 4 | Boss Gate | 12×6 | 1.3× | Boss (5 HP) |
| 5 | Breach Point | 12×7 | 1.45× | Boss + Metal |
| Endless | — | ↑ | ↑ | Scaled HP |

Clear Level 5 to unlock Endless Mode. Each level has authored drop-weight tables and a stage intro card.

---

## Project Structure

```
res://
├── main.tscn/.gd          # Run conductor (session/level/round flow)
├── autoload/               # Singletons: AudioManager, GameTheme, RunState, SaveData, ScreenTransition
├── game/                   # Core: GameState, LevelDefs, LevelBuilder, PowerUpRegistry
├── entities/               # Paddle, Ball, Brick, PowerUp, LaserBeam, LaserManager, RingEffect
├── ui/                     # TitleScreen, HUD, Victory
├── shaders/                # brick_glow.gdshader, scanline.gdshader
└── docs/                   # Readme, history, retro notes, agents guide
```

---

## Collision Layers

| Layer | Entity |
|-------|--------|
| 1 | Paddle |
| 2 | Ball |
| 3 | Brick |
| 4 | Power-up |
| 5 | Laser Beam |
| 6 | Wall |

---

## Implementation Notes

- Built with **Godot 4.x** (GDScript), CharacterBody2D / StaticBody2D physics
- Signals for decoupled communication (`life_lost`, `brick_hit`, `collected`, `destroyed`)
- `GameState.Phase` enum drives all game logic transitions
- Colors autoload singleton provides neon palette constants
- Shaders compatible with ColorRect nodes
- One-time setup pattern: `_run_setup()` called unconditionally in `_ready()` for signal wiring, timer creation, wall bounds before any run-starting dispatch
- Tween lifecycle pattern: store Tween references in member variables; `.kill()` before creating new ones on the same properties to prevent racing Tweens
- Callback injection pattern: inject `Callable` dependencies (e.g., `paddle.set_sticky_release_callback()`) instead of using `get_parent()` introspection
- Unified hit result contract: `Brick.take_damage()` returns `{destroyed, awarded_points, score_points, remaining_hp, was_already_scored}` — all damage sources (ball, laser) consume the same dictionary
- Laser manager setup pattern: `_setup_laser_manager()` centralizes paddle binding + phase gate; called from all lifecycle entry points (`_run_setup`, `_start_new_run`, `_load_level`, `_spawn_ball`, power-up branch)

---

## Credits

- **Design**: Derived from Atari's Breakout (1976)
- **Engine**: Godot 4.x
- **Palette**: Retro-neon (cyan/magenta/lime on dark blue-black)

---

*For session history, see [docs/history.md](history.md). For per-session detail, see `docs/retro_MMDD.md` files.*
