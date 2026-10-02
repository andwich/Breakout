# Breakout — Modern Retro Breakout Game

A modern breakout game inspired by Atari's classic, built with **Godot 4.x** featuring a neon arcade aesthetic, 6 power-up types, 5 progressive levels + endless mode, and boss bricks.

---

## Quick Start

1. Open `project.godot` in **Godot 4.x**
2. Press **F5** or click **Run** to start
3. Use **A/D** or **Arrow Keys** to move paddle
4. Press **Space** or **Click** to launch ball

---

## Features

- **6 power-up types** with differentiated durations: Multiball, Big Paddle (8s), Sticky (10s), Laser (6s), Slow Balls (6s), Extra Life
- **5 hand-crafted levels** with progressive difficulty → Endless mode
- **3 brick types**: Standard (1 HP), Metal (3 HP, scanline shader, progressive darkening), Boss (5 HP, pulsing glow + health bar)
- **Neon palette**: near-black playfield with cyan/green/yellow/magenta/orange brick bands, ball/paddle glow halos, particle FX
- **Controls**: Keyboard (A/D, Arrows, Space) or mouse (paddle follows cursor)
- **Audio**: Synthesized tones cached once at startup (brick hit, paddle hit, launch, power-up, etc.)
- **Animated paddle**: Big Paddle grows/shrinks over ~0.15s instead of snapping
- **Persistent high scores**
- **Headless smoke suites**: `tests/smoke_0823.gd` (`-s`) and `tests/smoke_0827.tscn` (scene-run, 107 checks)

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
├── tests/                  # smoke_0823.gd (-s), smoke_0827.gd/.tscn (scene-run runtime harness)
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
- **Rebound minimum upward**: paddle rebound enforces `Ball.MIN_UPWARD_COMPONENT = 0.42` to prevent shallow wall-rally loops; full edge hits deflect up to ~45° from vertical
- **Durable brick scoring**: non-lethal hits return `score_points = 0`; only destruction awards points; `refresh_damage_visuals()` updates persistent HP label, health bar, and progressive damage color
- **Sticky context prompt**: `sticky_ball_caught` / `sticky_ball_released` signals drive a distinct "AIM WITH PADDLE" HUD prompt
- **Power-up round-clear grace**: power-ups collected in the same frame as `ROUND_CLEAR` resolve their effects instead of being silently dropped
- **Visual hierarchy**: standard bricks idle on muted `ROW_COLORS` bands (row color blended 50% toward TEXT_MUTED, darkened 12%); hit flashes lighten the brick's own hue (`base_color.lightened(0.75)`); slow overlay reduced to 0.10 alpha
- **Semantic color palette**: `GameTheme` provides ACCENT/SUCCESS/INFO/WARNING/DANGER/BRICK_BOSS/BACKGROUND/BORDER_SUBTLE/TEXT_PRIMARY/TEXT_MUTED; legacy NEON_* aliases removed after full migration
- **Global font**: wired via `gui/theme/custom_font` pointing at `res://assets/fonts/Mono-Bold.ttf` (a `[font]` config section is invalid in Godot 4)
- **Paddle input priority**: keyboard owns movement until the mouse actually moves; releasing keys with a stationary cursor stops the paddle instead of snapping to the cursor
- **Multiball over-cap**: pickups collected at `MAX_BALLS` convert to a +50 score bonus with popup instead of spawning nothing
- **Ball pop tween lifecycle**: `pop_tween` member stored, killed before recreate; squash/stretch `Vector2(1.16, 0.88) → Vector2.ONE` elastic; always begins from `Vector2.ONE`
- **Feedback density caps**: max 2 score popups and 2 shake requests per physics frame; priority pass-through for scores ≥100; 28ms brick-hit audio cooldown
- **AudioStreamPlayer pooling**: 12-player preallocated pool in `AudioManager`; round-robin reuse eliminates per-effect node allocation churn during dense gameplay
- **Audio type safety**: all arrays and indexed collections explicitly typed (`Array[float]`, `float freq`); Master bus lookup validated with `push_warning` on missing bus
- **ScreenTransition tween lifecycle**: `_fade_tween` member stored, killed before recreate; `force_reset()` kills in-flight fade
- **Canvas scaling**: `stretch/mode="canvas_items"`, `stretch/aspect="keep"` for Retina/ultrawide support
- **Teardown safety**: `is_instance_valid()` guards in `ball.attach_to_paddle()`, trail emitting reset on attach, `_exit_tree()` cleanup in `Ball` and `Brick` for tween kill
- **Explicit scene typing**: `BALL_SCENE`/`BRICK_SCENE`/`POWERUP_SCENE` declared as `const X: PackedScene` — a missing or corrupt `.tscn` surfaces as one clear preload error instead of an inference cascade
- **Scene section ordering**: `.tscn` files must declare all `[sub_resource]` blocks before any `[node]` blocks; a `sub_resource` after nodes fails parsing (`Unknown tag 'sub_resource'`) and breaks every `preload()` of that scene

- **Paddle width authority**: `target_width` is intent, `visual_width` is reality — `_set_paddle_width()` tweens the collision shape, sprite offsets and `visual_width` in lockstep; `_draw()`, wall bounds and the aim guide all read `visual_width` so art never leads physics
- **Cached audio synthesis**: launch / power-up / paddle-hit WAVs are synthesized once in `AudioManager._ready()` (`_make_*_wav()` makers) and replayed through the pooled players — no per-call 22 kHz sample loops
- **Registry-owned durations**: `PowerUpRegistry.DEFS` is the only duration source; `apply_big_paddle()` / `enable_sticky()` / `activate()` take a required `duration_sec` with no default
- **Slow-scaled combo window**: `_sync_combo_timer_wait()` keeps the 0.6s combo window honest while SLOW_BALLS runs the balls at 60% (`0.6 / _slow_factor`)
- **HUD restore at show-time**: a heart re-awarded by Extra Life cancels its own in-flight loss fade and resets `modulate.a` / `scale` in the same pass that makes it visible — residue from the fade never reaches the player
- **Scene literal syntax**: `.tscn` color properties take numeric components only — `Color("#RRGGBB")` and `Color(GameTheme.X)` are parse errors that the `--editor --quit` gate does **not** surface (see `docs/retro_1001.md`)

---

## Validation

```bash
GODOT="/tmp/godotbin/Godot.app/Contents/MacOS/Godot"   # Godot 4.x binary on this machine

"$GODOT" --headless --path . --editor --quit                          # script parse gate
"$GODOT" --headless --path . res://main.tscn --quit-after 60          # scene loads + ticks
"$GODOT" --headless --path . res://tests/smoke_0827.tscn              # 107 runtime checks
"$GODOT" --headless --path . -s res://tests/smoke_0823.gd             # legacy smoke checks
```

All four must exit 0. `-s` scripts do **not** register autoload named-globals, so
`hud.tscn` / `main.tscn` cannot be loaded there — that is why `smoke_0827` is a scene.

---

## Credits

- **Design**: Derived from Atari's Breakout (1976)
- **Engine**: Godot 4.x
- **Palette**: Neon arcade (near-black, cyan/green/yellow/magenta on dark)

---

## Latest session — 31 (2026-10-01)

Feedback 0827 rollout: authored level-intro copy + hearts restored at show-time (`ui/hud.gd`),
boss bar width + progressive metal darkening (`entities/brick.gd`), cached launch/power-up/paddle-hit
WAVs (`autoload/audio_manager.gd`), tweened paddle width via `visual_width` (`entities/paddle.gd`),
slow-scaled combo window (`main.gd`), differentiated registry durations (8/10/6/6) with the hardcoded
8.0s defaults removed — plus a **P0**: `main.tscn` and `hud.tscn` contained invalid color literals and
failed to parse, so gameplay never loaded. New 107-check runtime harness in `tests/smoke_0827.tscn` (including a scene-color parity guard against `GameTheme`).
Detail: [docs/retro_1001.md](retro_1001.md).

---

*Session history: [docs/history.md](history.md). Per-session detail: `docs/retro_MMDD.md`.*
