# Architecture

Breakout is a Godot 4.x (GDScript) arcade game — a modern take on Atari's classic with a neon arcade aesthetic, power-ups, 5 authored levels (2 with authored layouts), and endless mode.

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
| `game/level_defs.gd` | Static level configs: name, grid size, speed multiplier, brick HP, drop weights, optional `layout` string masks |
| `game/level_builder.gd` | Brick geometry generation — mask-aware `_cell_is_filled()` skips empty cells when `layout` is set |
| `game/powerup_registry.gd` | Central power-up metadata: icon, color, duration (single tuning source), weight |

### Entities

| File | Role |
|------|------|
| `entities/paddle.gd` | Movement, sticky mode, tweened width (`_set_paddle_width()` → `visual_width`), wall bounds, edge warnings, aim lines, centralized visual state (`refresh_visual_state()`) |
| `entities/ball.gd` | Physics with substep anti-tunneling, launch, aim, collision response, stuck-ball escape, off-screen containment |
| `entities/brick.gd` | HP, damage, destruction, row color, shader caching (scanline/glow), progressive damage darkening (standard/metal/boss), damage feedback particles |
| `entities/powerup.gd` | Collection (reads metadata from PowerUpRegistry), falling animation, rotation |
| `entities/laser_manager.gd` | Auto-fire logic, phase-aware callback, beam spawning |
| `entities/laser_beam.gd` | Projectile behavior, brick collision |
| `entities/ring_effect.gd` | Expanding arc ring flash on brick destruction |
| `entities/playfield_border.gd` | Resize-safe border with glow + corner accents |

### UI

| File | Role |
|------|------|
| `ui/title_screen.gd` | Title card: high score, controls, power-up legend, breathing alpha pulse |
| `ui/hud.gd` | Score, lives (hearts restored at show-time), multi-effect timer strip, level intro panel (authored title/subtitle), pause/game-over text |
| `ui/victory.gd` | Win screen with confetti, endless mode entry |

### Tests

| File | Role |
|------|------|
| `tests/smoke_0823.gd` | `-s` headless checks: palette aliases, brick banding/damage colors, `TweenHelper`, stuck-ball escape invariant |
| `tests/smoke_0827.gd` | Scene-run runtime harness (107 checks): HUD intro copy + heart restore, scene color literals vs `GameTheme`, boss bar width, metal darkening, cached WAVs, paddle width tween, slow-scaled combo window |
| `tests/smoke_0827.tscn` | Entry scene for the harness — required because `-s` does not register autoload named-globals |

### Autoloads (Singletons)

| Autoload | File | Purpose |
|----------|------|---------|
| `AudioManager` | `autoload/audio_manager.gd` | Synthesized sound effects (8 PCM tones), WAVs rendered once in `_ready()` and replayed via the pool, mute toggle |
| `GameTheme` | `autoload/game_theme.gd` | Neon arcade palette: near-black BACKGROUND, cyan ACCENT, green SUCCESS, yellow WARNING, magenta DANGER, blue INFO; HUD_FONT_SIZE=22, CALLOUT_FONT_SIZE=76 |
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

The boss health bar shares one contract with its background: both are 40px wide, and the fill is `40.0 * health_ratio` in **both** `refresh_damage_visuals()` and `_update_visual()` (a 56px base in the former overran the background above ~71% HP). Metal bricks darkened like the boss since Session 31: `Color(0.7, 0.7, 0.9).darkened(1.0 - clampf(hp_ratio, 0.3, 1.0))` applied to sprite *and* particle material, with the same alpha ramp — the `0.3` clamp floor keeps a near-dead endless-wave brick readable instead of black.

### Paddle Width: Intent vs Reality

`target_width` is what the paddle *should* be; `visual_width` is what the sprite and collision shape *are* while a width change animates. All mutations go through `_set_paddle_width(width, animated)`, which kills any live `_width_tween`, then tweens `_apply_width_pixels(v)` (shape + sprite offsets + `visual_width`) over 0.15s — or snaps when `animated == false` (used by `reset()`, so a level load can never inherit a wide paddle). Drawing (`_draw()` glow, edge warnings, aim origin via `get_visual_ball_attach_offset()`) and physics bounds read `visual_width`, because the collision shape is the thing moving. `get_ball_attach_offset()` deliberately stays intent-based so every ball-attach call site is unaffected. `is_big_paddle_active()` stays `target_width`-based: it reports the power-up state, not the pixel width.

### Cached Audio Synthesis

`AudioManager` renders the launch sweep (2 646 samples), power-up arpeggio (5 512) and paddle thud (1 764) **once** in `_ready()` via static `_make_launch_wav()` / `_make_powerup_wav()` / `_make_paddle_hit_wav()` makers, storing them in `_launch_wav` / `_powerup_wav` / `_paddle_hit_wav`. `play_launch()` / `play_powerup()` / `play_paddle_hit()` are one-liners over those streams at the original volumes. Before this, every launch, pickup and paddle touch re-ran a 22 kHz synthesis loop and allocated a fresh `AudioStreamWAV` on the hot path. Combined with the 12-player pool, effect playback is allocation-free.

### Registry-Owned Durations

`PowerUpRegistry.DEFS["duration"]` is the single tuning source: BIG_PADDLE 8.0s, STICKY 10.0s, LASER 6.0s, SLOW_BALLS 6.0s (differentiated by impact — Sticky needs aiming headroom, Laser is strong but brief). `PowerUp._on_body_entered()` emits the registry value, `main.gd` forwards it, and the effect entry points (`paddle.apply_big_paddle()`, `paddle.enable_sticky()`, `laser_manager.activate()`) declare a **required** `duration_sec: float` — no defaults, so a forgotten argument is a compile error rather than a silent 8.0 override.

### Slow-Scaled Combo Window

The combo window is real time (`Timer`), but a slowed ball covers less ground per second, so a fixed 0.6s window quietly gets harder while SLOW_BALLS is active. `_sync_combo_timer_wait()` sets `wait_time = 0.6 / _slow_factor` (1.0s when slowed) and is called after every `_slow_factor` mutation — `_apply_slow_balls()`, `_restore_ball_speeds()`, `_load_level()` — plus at run setup. Scoring and combo awarding are unchanged; only the window length moves.

### HUD Restore At Show-Time

`HUD.update_lives()` owns both directions of a heart's life. The loss animation leaves permanent residue (`modulate.a = 0`, `scale = 1.5`, plus a pending `visible = false` callback at +0.2s), so any heart that satisfies `i < new_lives` cancels its own tween in `_heart_tweens[i]` and resets alpha/scale in the *same* pass that makes it visible. Restoring at tween end would be too late: an Extra Life collected during the fade would re-show a translucent heart, or have it hidden again a moment later.

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

### Scene Literal Syntax

Godot's `.tscn` text format parses property values as variant literals; `Color(...)` accepts
**numeric components only**. `theme_override_colors/font_color = Color("#00E5FF")` and
`color = Color(GameTheme.BACKGROUND)` are silent-looking corruption: the headless editor scan
(`--editor --quit`) reports zero problems, while instantiating the scene fails with
`Failed loading resource` — which is how `main.tscn` shipped un-loadable for 13 "validated"
sessions before Session 31. Scene colors must be floats (or be applied from GDScript), and the
scene run gate (`--headless --path . res://main.tscn --quit-after 60`) is part of the gate.

### Why The Smoke Harness Is A Scene

Under `godot -s script.gd` the autoload *nodes* exist under `/root`, but autoload
**named-globals are not registered**, so any script that references one (`hud.gd` →
`SaveData.get_high_score()`, `main.gd` → `RunState`) fails to *compile* and its `.tscn`
loads as `null`. `tests/smoke_0827.tscn` runs as the main scene instead, which keeps
headless determinism while making the HUD and the run conductor reachable for real
behavioral assertions. The suite exits non-zero on failure, so it is CI-shaped.

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
- **Paddle width mid-tween** — collision shape and drawing animate together (`visual_width`), but `ball.gd`'s `hit_ratio` still divides by `target_width`, so an edge contact during the 0.15s grow/shrink deflects marginally shallower than the sprite suggests; self-corrects at tween end (tracked in `docs/retro_1001.md`)
- **Metal brick tone** — `_update_visual()` uses a fixed steel `Color(0.7, 0.7, 0.9)` while `base_color` is `GameTheme.BRICK_DURABLE` (orange), so hit flashes peak orange and settle steel; deferred design decision

---

*See `docs/history.md` for session-by-session changes and `docs/agents.md` for contributor guidelines.*
