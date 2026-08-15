# Breakout — Modern Retro Breakout Game

A modern breakout game inspired by Atari's classic, built with **Godot 4.x** featuring a calm dashboard aesthetic, 6 power-up types, 5 progressive levels + endless mode, and boss bricks.

---

## Quick Start

1. Open `project.godot` in **Godot 4.x**
2. Press **F5** or click **Run** to start
3. Use **A/D** or **Arrow Keys** to move paddle
4. Press **Space** or **Click** to launch ball

---

## Features

- **6 power-up types**: Multiball, Big Paddle, Sticky, Laser, Slow Balls, Extra Life
- **5 hand-crafted levels** with progressive difficulty → Endless mode
- **3 brick types**: Standard (1 HP), Metal (3 HP, scanline shader), Boss (5 HP, pulsing glow)
- **Calm palette**: soft blue/green/purple/amber on dark, glow shaders, particle FX
- **Controls**: Keyboard (A/D, Arrows, Space) or mouse (paddle follows cursor)
- **Audio**: Synthesized tones (brick hit, paddle hit, launch, power-up, etc.)
- **Persistent high scores**

---

## Controls

| Action | Keys |
|--------|------|
| Move | `A` / `D`, `←` / `→`, or mouse (cursor over window) |
| Launch | `Space` or `Left Click` |
| Pause | `Escape` |
| Mute | `M` |

---

## Project Structure

```
res://
├── main.tscn/.gd          # Run conductor (session/level/round flow)
├── autoload/               # Singletons: AudioManager, GameTheme, RunState, SaveData, ScreenTransition
├── game/                   # GameState, LevelDefs, LevelBuilder, PowerUpRegistry
├── entities/               # Paddle, Ball, Brick, PowerUp, LaserManager, LaserBeam, RingEffect, PlayfieldBorder
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

- **Engine**: Godot 4.x (GDScript), CharacterBody2D / StaticBody2D physics
- **State machine**: `GameState.Phase` enum drives all game logic; `main.gd` owns transitions
- **Communication**: Signals for decoupled events; `Callable` injection for behavior; avoid `get_parent()`/`has_method()` introspection
- **Key patterns**: One-time setup (`_run_setup()`), tween lifecycle (store + kill), unified hit contract (`Brick.take_damage()` returns structured dict), deferred launch for paused-tree ball release
- **ScreenTransition API**: Use `is_busy()` / `force_reset()` — never write `_busy` directly
- **Sticky paddle**: `stick_ball()` returns `bool`; callers must check and fall through to normal bounce on `false`
- **Paddle visual state**: `refresh_visual_state()` is the single authority for paddle color (Sticky → yellow, Big Paddle → lime, else cyan); power-up methods never write `sprite.color` directly
- **Sticky aim guide**: `stick_ball()` shows the aim guide; `clear_sticky_aim()` on every release path; aim steers while a ball is caught
- **Ball containment**: any screen exit counts as a loss (idempotent handler) + redundant bounds fallback in `_physics_process()` — no phantom balls
- **Launch input suppression**: `suppress_launch_until_release` is set only on title-screen transition; flag clears on first release regardless of phase; normal READY states accept the next press immediately
- **Ball adaptive substeps**: up to 96 steps per physics tick (`MAX_PHYSICS_STEPS`); residual move for severe frame hitches; prevents missed collisions in endless mode
- **Rebound minimum upward**: paddle rebound enforces `MIN_UPWARD_COMPONENT = 0.38` to prevent shallow wall-rally loops
- **Durable brick scoring**: non-lethal hits return `score_points = 0`; only destruction awards points; `refresh_damage_visuals()` updates persistent HP label, health bar, and progressive damage color
- **Sticky context prompt**: `sticky_ball_caught` / `sticky_ball_released` signals drive a distinct "AIM WITH PADDLE" HUD prompt
- **Power-up round-clear grace**: power-ups collected in the same frame as `ROUND_CLEAR` resolve their effects instead of being silently dropped
- **Visual hierarchy**: standard bricks darkened 12% for idle state; hit flashes remain bright white; slow overlay reduced to 0.10 alpha
- **Semantic color palette**: `GameTheme` replaced NEON_* constants with ACCENT/SUCCESS/INFO/WARNING/DANGER/BRICK_BOSS/BACKGROUND/BORDER_SUBTLE/TEXT_PRIMARY/TEXT_MUTED; old NEON_* names preserved as aliases for backward compat
- **Ball pop tween lifecycle**: `pop_tween` member stored, killed before recreate; squash/stretch `Vector2(1.16, 0.88) → Vector2.ONE` elastic; always begins from `Vector2.ONE`
- **Feedback density caps**: max 2 score popups and 2 shake requests per physics frame; priority pass-through for scores ≥100; 28ms brick-hit audio cooldown
- **AudioStreamPlayer pooling**: 12-player preallocated pool in `AudioManager`; round-robin reuse eliminates per-effect node allocation churn during dense gameplay
- **Audio type safety**: all arrays and indexed collections explicitly typed (`Array[float]`, `float freq`); Master bus lookup validated with `push_warning` on missing bus
- **ScreenTransition tween lifecycle**: `_fade_tween` member stored, killed before recreate; `force_reset()` kills in-flight fade
- **Canvas scaling**: `stretch/mode="canvas_items"`, `stretch/aspect="keep"` for Retina/ultrawide support
- **Teardown safety**: `is_instance_valid()` guards in `ball.attach_to_paddle()`, trail emitting reset on attach, `_exit_tree()` cleanup in `Ball` and `Brick` for tween kill
- **Explicit scene typing**: `BALL_SCENE`/`BRICK_SCENE`/`POWERUP_SCENE` declared as `const X: PackedScene` — a missing or corrupt `.tscn` surfaces as one clear preload error instead of an inference cascade
- **Scene section ordering**: `.tscn` files must declare all `[sub_resource]` blocks before any `[node]` blocks; a `sub_resource` after nodes fails parsing (`Unknown tag 'sub_resource'`) and breaks every `preload()` of that scene

---

## Credits

- **Design**: Derived from Atari's Breakout (1976)
- **Engine**: Godot 4.x
- **Palette**: Calm dashboard (soft blue/green/purple/amber on dark)

---

*Session history: [docs/history.md](history.md). Per-session detail: `docs/retro_MMDD.md`.*
