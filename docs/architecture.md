# Architecture

Breakout is a Godot 4.x (GDScript) arcade game — a modern take on Atari's classic with neon visuals, power-ups, 5 authored levels, and endless mode.

---

## Overview

- **Engine**: Godot 4.x, GDScript
- **Physics**: CharacterBody2D (ball, paddle) + StaticBody2D (bricks, walls)
- **Resolution**: 1280×720, pixel-art texture filtering disabled
- **Entry point**: `ui/title_screen.tscn` → `main.tscn` (gameplay)

---

## Main Components

### Scene Tree

```
main.tscn (Main : Node2D)
├── Paddle (CharacterBody2D)
├── Balls (Node2D) — dynamic Ball instances
├── Bricks (Node2D) — dynamic Brick instances
├── PowerUps (Node2D) — dynamic PowerUp instances
├── LaserManager (Node2D) — auto-fire logic + laser beams
├── HUD (CanvasLayer) — score, lives, effects, combo label, level intro
├── LeftWall / RightWall (StaticBody2D) — collision boundaries
└── Background (Node2D) — particles, overlays
```

### Core Scripts

| File | Role |
|------|------|
| `main.gd` | **Run conductor** — owns phase transitions, session flow, level loading, score/lives, combo, shake |
| `game/game_state.gd` | Phase enum: `TITLE → LEVEL_INTRO → READY → PLAYING → ROUND_CLEAR` + `PAUSED`, `GAME_OVER`, `VICTORY` |
| `game/level_defs.gd` | Static level configs: name, grid size, speed multiplier, brick HP, drop weights |
| `game/level_builder.gd` | Brick geometry generation from level config |
| `game/powerup_registry.gd` | Central power-up metadata: icon, color, duration, weight |

### Entities

| File | Role |
|------|------|
| `entities/paddle.gd` | Movement, sticky mode, width effects, wall bounds, edge warnings, aim lines, centralized visual state (`refresh_visual_state()`) |
| `entities/ball.gd` | Physics with substep anti-tunneling, launch, aim, collision response, stuck-ball escape, off-screen containment |
| `entities/brick.gd` | HP, damage, destruction, row color, shader caching (scanline/glow), damage feedback particles |
| `entities/powerup.gd` | Collection (reads metadata from PowerUpRegistry), falling animation, rotation |
| `entities/laser_manager.gd` | Auto-fire logic, phase-aware callback, beam spawning |
| `entities/laser_beam.gd` | Projectile behavior, brick collision |
| `entities/ring_effect.gd` | Expanding arc ring flash on brick destruction |
| `entities/playfield_border.gd` | Resize-safe border with glow + corner accents |

### UI

| File | Role |
|------|------|
| `ui/title_screen.gd` | Title card: high score, controls, power-up legend, breathing alpha pulse |
| `ui/hud.gd` | Score, lives, multi-effect timer strip, level intro panel, pause/game-over text |
| `ui/victory.gd` | Win screen with confetti, endless mode entry |

### Autoloads (Singletons)

| Autoload | File | Purpose |
|----------|------|---------|
| `AudioManager` | `autoload/audio_manager.gd` | Synthesized sound effects (8 PCM tones, play-and-forget), mute toggle |
| `GameTheme` | `autoload/game_theme.gd` | Semantic color palette (ACCENT, SUCCESS, INFO, WARNING, DANGER, BRICK_BOSS, BACKGROUND, BORDER_SUBTLE, TEXT_PRIMARY, TEXT_MUTED) |
| `RunState` | `autoload/run_state.gd` | Transient session: `start_level`, `last_score` |
| `SaveData` | `autoload/save_data.gd` | High score persistence to `user://breakout_save.json` |
| `ScreenTransition` | `autoload/screen_transition.gd` | Scene fade in/out with deadlock guard (5s timeout), public API: `is_busy()`, `force_reset()` |

### Shaders

| File | Used By |
|------|---------|
| `shaders/brick_glow.gdshader` | Boss bricks — pulsing glow effect |
| `shaders/scanline.gdshader` | Metal bricks — animated scanline texture |

---

## Data Flow

### Game Loop

```
TitleScreen → [F5/Click] → main.gd._ready() → _run_setup() → _start_new_run()
    ↓
_start_new_run() → phase = LEVEL_INTRO → _load_level()
    ↓
_load_level() → spawn bricks → _start_level_intro() → timer → phase = READY
    ↓
READY → ball launch → phase = PLAYING
    ↓
PLAYING → brick hits → score/combo → all destroyed → phase = ROUND_CLEAR
    ↓
ROUND_CLEAR → _resolve_round_clear()
    ├── Level < 5: _load_level(level + 1)
    ├── Level 5: phase = VICTORY → victory scene
    └── Endless: _load_level(level + 1) with scaled config
    ↓
Ball lost → _on_ball_lost()
    ├── Lives > 0: respawn ball, phase = READY
    └── Lives = 0: phase = GAME_OVER → _enter_game_over()
```

### Power-Up Flow

```
PowerUp enters PLAYING phase → falls with sine drift + rotation
    ↓
Ball collects → main.gd._on_powerup_collected(ptype, duration)
    ├── Timed effects (Big Paddle, Sticky, Laser, Slow): activate + HUD timer
    ├── Multiball: clone active balls
    └── Extra Life: increment lives
    ↓
Timer expires → deactivate → restore paddle/ball state
```

### Collision Layers

| Bit | Layer | Entity |
|-----|-------|--------|
| 1 | Paddle | Paddle |
| 2 | Ball | Ball |
| 3 | Brick | Brick |
| 4 | PowerUp | PowerUp |
| 5 | Laser | LaserBeam |
| 6 | Wall | LeftWall, RightWall |

Ball collision_mask = Paddle + Brick + Wall (bits 1 + 4 + 32 = 37).

---

## Key Design Decisions

### Phase-Driven State Machine

All game logic is gated by `GameState.Phase`. UI never drives transitions — `main.gd` owns them. This prevents race conditions like phantom life loss during ROUND_CLEAR or power-up collection during non-PLAYING phases.

### One-Time Setup Pattern

`_run_setup()` runs once in `_ready()` for signal wiring, timer creation, wall bounds, and overlay setup. `_start_new_run()` and `_load_level()` only reset mutable state — they never recreate timers or re-wire signals. This prevents orphaned nodes and double-connections.

### Tween Lifecycle

All tweens are stored in member variables and `.kill()`-ed before recreating on the same properties. This prevents racing tweens during rapid events (e.g., combo chain, boss rapid hits).

### Callback Injection

Behavior is injected via `Callable` members (e.g., `paddle.set_sticky_release_callback()`) rather than `get_parent()`/`has_method()`/`call()` introspection. This makes dependencies explicit and prevents fragile parent-chain assumptions.

### Unified Hit Contract

`Brick.take_damage()` returns `{destroyed, awarded_points, score_points, remaining_hp, was_already_scored}`. All damage sources (ball, laser) consume this dictionary — no ad-hoc scoring rules.

### Deferred Launch

When a sticky release callback fires during a paused tree, the launch is deferred via `_deferred_launch: bool` flag. It fires on the first unpaused tick in `_process()` (not `_physics_process`, which returns early when paused).

### ScreenTransition Deadlock Guard

`ScreenTransition` has a 5-second timeout on its `_busy` state. `force_reset()` clears both the flag and overlay state. Game code never writes `_busy` directly.

### Centralized Paddle Visual State

`Paddle.refresh_visual_state()` is the single authority for paddle color: Sticky → `WARNING`, Big Paddle → `SUCCESS`, else `ACCENT`. Power-up methods never write `sprite.color` directly — they mutate effect state and call `refresh_visual_state()`. This eliminates order-dependent tint bugs (e.g., Sticky expiry clobbering the Big Paddle lime tint).

### Adaptive Ball Substeps

`Ball._physics_process()` uses `MAX_STEP_DISTANCE = 6.0` and `MAX_PHYSICS_STEPS = 96`. The loop processes every travel segment within the safe cap; a residual `move_and_collide()` handles severe frame hitches. This prevents missed collisions and inconsistent speed in endless mode at high speeds, while capping the worst-case loop for pathological delta spikes.

### Rebound Minimum Upward Component

Paddle rebound enforces `MIN_UPWARD_COMPONENT = 0.38` after applying the horizontal hit-ratio factor (0.82). The `aim.y` is clamped to `minf(aim.y, -0.38)` and then normalized, ensuring every paddle rebound has a strong enough upward direction. This prevents long side-wall rally patterns that were possible with the previous 0.9× horizontal factor and weak 50 px/s axis floor.

### Durable Brick Scoring

`Brick.take_damage()` returns `score_points = 0` for non-lethal hits and `score_points = point_value` only on destruction. `main.gd`'s `_on_brick_hit()` plays a muted brick-hit sound but skips combo increment and score addition for `points <= 0`. This makes durable-brick (metal, boss) scoring explicit and prevents opaque micro-scores from confusing players.

### Sticky Context Prompt

`Paddle` emits `sticky_ball_caught` and `sticky_ball_released` signals on catch and release. `main.gd` connects these in `_run_setup()` and drives a context prompt ("AIM WITH PADDLE • STICKY RELEASE AUTO-FIRES") via `HUD.show_context_prompt()` / `hide_context_prompt()`. The HUD reuses the existing `launch_prompt` label and restores the default READY text on release. This maintains the established UI-as-renderer boundary.

### Visual Hierarchy

Standard bricks use `row_color.darkened(0.12).lerp(Color.WHITE, 0.05)` at idle instead of the previous `lerp(Color.WHITE, 0.08)`, creating a 12% dimming effect. Hit flashes still animate to white, producing stronger contrast between idle and reactive states. The Slow Ball overlay alpha is reduced from 0.18 to 0.10 to preserve gameplay legibility during activation.

### Feedback Density Rate Limits

`main.gd` caps per-frame audiovisual feedback to prevent chaos during laser/multiball dense destruction. `_score_popups_this_frame` and `_shake_requests_this_frame` reset each physics tick. `try_spawn_score_popup()` and `try_shake_camera()` enforce caps of 2 per frame; score popups with value ≥100 always pass through. `AudioManager.play_brick_hit()` enforces a 28ms minimum interval between calls. Gameplay logic (scoring, brick destruction, drops, ball physics) is unaffected.

### Ball Impact Tween Ownership

`Ball._pop_visual()` stores `pop_tween` as a member variable and kills it before recreation. Scale is reset to `Vector2.ONE` before starting, preventing a cancelled squash state from becoming the animation baseline. The squash/stretch uses `Vector2(1.16, 0.88)` (quad-ease-out) → `Vector2.ONE` (elastic-ease-out), communicating elastic collision rather than uniform UI-button pulsing.

### Durable Brick Persistent Damage State

`Brick.refresh_damage_visuals()` runs after every non-lethal hit on multi-HP bricks. It updates `_hp_label` text, `_health_bar` size, and progressively darkens `_sprite.color` relative to health ratio. Standard bricks use `row_color.darkened((1.0 - health_ratio) * 0.16)`. The flash tween temporarily goes white and returns to the current post-damage base color — never the pre-damage color.

### Ball Containment

Any screen exit is terminal: `_on_screen_exited()` is idempotent (`if not launched: return`) and emits exactly one `life_lost`. A redundant 64px bounds check in `_physics_process()` catches tunneling or notifier-regression cases so a ball can never remain a live off-screen "phantom" that soft-locks the round.

### Launch Input Suppression

`main.gd`'s `suppress_launch_until_release` flag is set only on title-screen transition to consume the input that started the game. Normal READY states (life loss, level intro, unpause) accept the next press immediately. The flag is cleared on the first launch-action release. This prevents accidental title-click launches while keeping repeated play responsive.

### AudioStreamPlayer Pooling

`AudioManager` preallocates a pool of 12 `AudioStreamPlayer` children in `_ready()`. `_play_stream()` reuses the first non-playing player via round-robin; if all players are busy, the oldest is stolen. This eliminates per-effect node allocation/deallocation churn during dense laser/multiball gameplay. The pool size (`PLAYER_POOL_SIZE = 12`) is a constant. The existing 28ms brick-hit rate limiter is unchanged.

### Typed Audio Arrays

All indexed collections in `audio_manager.gd` use explicit types: `Array[float]` for frequency arrays, `float` for indexed values. `_make_chord(freqs: Array[float], ...)` enforces typed input. This prevents Godot 4's static analyzer from failing on `:=` inference from untyped `Array` index (the P0 launch blocker that prompted this hardening pass).

### Master Bus Validation

`AudioManager._master_bus_index()` returns the bus index and pushes a warning if the Master bus is not found. All callers (`toggle_mute()`, `set_volume_db()`) guard with `if idx >= 0` before performing bus operations. This protects startup if the default audio bus layout is altered.

### Save-Data Safety

`SaveData.get_high_score()` and `save_high_score()` explicitly close file handles after use, validate parsed JSON with `parsed is Dictionary`, guard against negative values with `max(0, int(...))`, and push warnings on null file handles. The key name is consistently `"high_score"`.

### ScreenTransition Fade Tween Lifecycle

`ScreenTransition` stores the active fade tween in `_fade_tween` member. `_replace_fade_tween()` kills any existing tween before creating a new one. Both `fade_in()` and `fade_out()` use this helper. `force_reset()` kills `_fade_tween` and sets it to null. This prevents stale fade tweens from modifying overlay alpha after a forced reset.

### Canvas Scaling

`project.godot` configures `stretch/mode="canvas_items"` and `stretch/aspect="keep"`. Godot scales the 1280×720 gameplay canvas while preserving aspect ratio on Retina, ultrawide, or non-16:9 displays. The existing `allow_hidpi=true` setting is appropriate.

### Teardown Validity Guards

`Ball.attach_to_paddle()` uses `is_instance_valid(paddle)` before accessing the stored paddle reference, preventing crashes during scene teardown. The trail emitter is explicitly stopped (`_trail.emitting = false`) on attach to prevent a previously active trail from persisting one frame after a loss or level reset.

### _exit_tree Tween Cleanup

Destroyable nodes (`Ball`, `Brick`) kill owned tweens in `_exit_tree()` to prevent orphaned effects after `queue_free()`. `Ball._exit_tree()` kills `pop_tween`. `Brick._exit_tree()` kills `_flash_tween`, `_scale_tween`, and `_boss_glow_tween`. This is essential during rapid scene changes and level transitions.

### Explicit Scene Preload Typing

`main.gd` declares `BALL_SCENE`, `BRICK_SCENE`, and `POWERUP_SCENE` as `const X: PackedScene = preload(...)` rather than relying on `:=` inference. Explicit typing converts a missing or corrupt `.tscn` into a single clear "Could not preload resource file" error instead of a cascade of "Cannot infer the type" errors on every downstream use. Related: Godot `.tscn` files require all `[sub_resource]` sections to precede all `[node]` sections; violating this produces `Parse Error: Unknown tag 'sub_resource'`. That defect in `entities/ball.tscn` (trail material declared after nodes) once blocked all three scene preloads and masqueraded as inference errors.

### Overlay Tween Ownership in main.gd

`main.gd` stores flash overlay (`_flash_tween`) and slow overlay (`_slow_tween`) tweens as members. All sites that create these tweens kill the prior instance first. `_start_new_run()` kills both tweens and resets overlay alphas to 0.0. This prevents overlapping tweens from corrupting overlay state during rapid events (multiple life losses, slow power-up re-collection).

---

## Dependencies

- **Engine**: Godot 4.x (GDScript, no plugins)
- **External**: None — all audio is synthesized in-engine, all shaders are inline
- **Persistence**: Single JSON file at `user://breakout_save.json` (high score only)
- **Input**: Keyboard (A/D, Arrows, Space, Escape, M) + mouse (paddle follows cursor)

---

## Deployment / Runtime

- Open `project.godot` in Godot 4.x, press F5
- No build step, no export templates needed for development
- Single-scene architecture: title screen loads main scene via `ScreenTransition.change_scene()`
- All state is in-memory; save file written on game over if new high score

---

## Tradeoffs & Constraints

- **No networking** — single-player only
- **No external assets** — all audio synthesized, all visuals procedural/shader-based
- **One ball at paddle** — `stick_ball()` returns `bool` to prevent silent freeze in Multiball + Sticky combo
- **Launch input suppression** — `suppress_launch_until_release` consumes only the title-screen start input; normal READY states accept the next press immediately
- **Combo carries across levels** — intentional streak continuity; only shake resets on level transition
- **Brick entrance animation** — staggered with `TRANS_BACK` for visual polish, but means bricks aren't interactive until animation completes
- **Endless mode** — generated from base level configs with scaled HP/speed; no authored layout beyond level 5

---

*See `docs/history.md` for session-by-session changes and `docs/agents.md` for contributor guidelines.*
