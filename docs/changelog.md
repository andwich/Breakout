# Changelog

All notable changes to Breakout are documented here. Derived from session retro files.

---

## 2026-08-15 — Session 29: Retheme — Calm Dashboard → Neon Arcade

### Changed
- **Neon palette** — `game_theme.gd`: replaced soft workspace palette with near-black background (`#03050B`), neon cyan (`#00E5FF`), green (`#00F07A`), yellow (`#FFD400`), magenta (`#FF167F`), orange (`#FF7A00`); `BRICK_STANDARD` → cyan; `BALL` → white
- **Authored layouts** — `level_defs.gd`: levels 1 & 2 gain `layout` string masks (full grid + split formation); `level_builder.gd`: mask-aware `_cell_is_filled()` skips empty cells
- **Brick bands** — `level_builder.gd`: `ROW_COLORS` → 8-color neon gradient (cyan → blue → green → orange → pink → purple)
- **HUD** — `hud.tscn`: score cyan, level yellow, lives magenta, cyan divider line, large callout fonts (76px level complete, 52px GO!); `hud.gd`: rounded card removed, intro shows "GO!" in green, clear shows "LEVEL COMPLETED!" in yellow
- **Glow halos** — `paddle.tscn`: cyan halo behind sprite; `ball.tscn`: white halo behind ball
- **Font** — `project.godot`: Mono-Bold wired as global default font (size 22)
- **Background** — `main.tscn`: `BackgroundOverlay` uses `GameTheme.BACKGROUND`; `main.gd`: combo label uses `GameTheme.WARNING`

### Validation
- Godot v4.7.1 headless parse — **PASS** (zero parse errors)

---

## 2026-08-14 — Session 28: Complete Retheme — Neon Arcade → Calm Dashboard

### Changed
- **Semantic color palette** — `game_theme.gd`: replaced NEON_CYAN/MAGENTA/LIME/YELLOW/RED/PURPLE with ACCENT/SUCCESS/INFO/WARNING/DANGER/BRICK_BOSS/BACKGROUND/BORDER_SUBTLE/TEXT_PRIMARY/TEXT_MUTED. Old NEON_* names preserved as aliases.
- **Entity colors** — All entities migrated to semantic palette: brick rows (DANGER→INFO→BRICK_BOSS), paddle (Sticky→WARNING, Big Paddle→SUCCESS, else ACCENT), ball (softened BALL color), border (BORDER_SUBTLE glow), ring effect (semantic pulse), laser (ACCENT)
- **Title screen** — Replaced 4-color hue cycling with single slow breathing pulse (modulate alpha 0.72→1.0); scanline eased to 0.04/0.3; controls muted; powerup legend at 0.7 alpha; VBoxContainer widened
- **Victory screen** — TEXT_PRIMARY title with ACCENT outline glow; elastic scale animation (TRANS_ELASTIC + EASE_OUT); sequential fade-in for score/highscore/prompt; confetti reduced (5 pieces, 2 colors, slower, smaller); VBoxContainer expanded with center alignment
- **HUD** — All label colors, border, effect timer defaults migrated to semantic palette
- **Audio retune** — Brick hits use pentatonic scale; paddle hit deeper (120Hz); launch sweep gentler (150→400Hz); powerup uses E-G-B chord; life lost gentle 440→160Hz drop; level complete longer tail; game over C minor; laser fire softer (440Hz A4)
- **Level builder** — ROW_COLORS uses semantic palette
- **Power-up registry** — Powerup colors use semantic palette

### Fixed
- **Parse error** — `main.gd:106` indentation error from slow_overlay edit
- **Victory animation** — Score/highscore now properly faded during title entrance (modulate.a = 0.0 before tween)

---

## 2026-08-10 — Session 27: Feedback 0810 2225 fixes

### Fixed
- **Corrupt ball scene** — `entities/ball.tscn`: the `ParticleProcessMaterial_trail` sub_resource was declared after the `[node]` sections; Godot requires all `[sub_resource]` blocks before any `[node]` blocks, so the file failed to parse (`Unknown tag 'sub_resource'`), the `BALL_SCENE` preload failed, and every downstream "Cannot infer the type" error cascaded from it. Sections reordered to canonical form; scene now loads.
- **Explicit scene preload typing** — `main.gd`: `BALL_SCENE`/`BRICK_SCENE`/`POWERUP_SCENE` declared as `const X: PackedScene = preload(...)` so a future missing/corrupt scene produces one clear resource error instead of an inference cascade.
- **Inference fragility** — `main.gd`: `orig_y` (brick entrance animation) and `decay` (shake tween lambda) explicitly typed `float`. `ui/hud.gd`: `row` in `set_effect_timer()` explicitly typed `Dictionary` (inference-from-Variant warning surfaced once the preload error cleared).

### Note
- The editor was pointed at a separate checkout (`~/Documents/Programming/Production/Breakout`) carrying the identical corrupt `ball.tscn`; both copies were repaired and validated headless with zero parse errors.

---

## 2026-08-09 — Session 26: Feedback 0809 1445 hardening pass

### Fixed
- **Type inference launch blocker** — `audio_manager.gd`: typed `notes` as `Array[float]` and `freq` as `float` in `play_powerup()`. Fixes Godot 4 static analyzer failure on `:=` inference from untyped Array index.
- **Untyped `_make_chord` parameter** — `audio_manager.gd`: typed `freqs: Array[float]` and loop variable; removed `float(f)` cast; updated call sites with `as Array[float]`.
- **Missing Master bus guard** — `audio_manager.gd`: added `_master_bus_index()` helper with `push_warning`; `toggle_mute()` and `set_volume_db()` guard with `if idx >= 0`.
- **Save-data file handle leak** — `save_data.gd`: added `file.close()` after read/write; `push_warning` on null handles; `parsed is Dictionary` check; `max(0, int(...))` guard.
- **Stale ScreenTransition fade tween** — `screen_transition.gd`: added `_fade_tween` member and `_replace_fade_tween()` helper; `force_reset()` kills in-flight fade.
- **Ball trail persisting after loss** — `ball.gd`: `attach_to_paddle()` stops trail emitting before repositioning.
- **Overlapping overlay tweens** — `main.gd`: `_flash_tween` and `_slow_tween` members with kill-before-create in all sites; cleanup + alpha reset in `_start_new_run()`.
- **Orphaned brick tweens** — `brick.gd`: `_exit_tree()` kills flash/scale/boss-glow tweens on removal.

### Changed
- **AudioStreamPlayer pooling** — `audio_manager.gd`: 12-player preallocated pool with round-robin reuse; no per-effect node allocation/deallocation churn.
- **Canvas scaling** — `project.godot`: added `stretch/mode="canvas_items"` and `stretch/aspect="keep"` for Retina/ultrawide support.
- **Ball teardown safety** — `ball.gd`: `attach_to_paddle()` uses `is_instance_valid(paddle)` guard; `_exit_tree()` kills `pop_tween`.

---

## 2026-08-09 — Session 25: Feedback 0809 0035 fixes

### Fixed
- **Two-press-start from title screen** — `main.gd`: removed `phase == READY` guard from `suppress_launch_until_release` release-clearing block; flag now clears on first release regardless of phase, so the first new press in READY launches immediately.
- **Ball pop tweens stacking** — `entities/ball.gd`: stored `pop_tween` member with kill-before-create lifecycle; replaced uniform scaling with squash/stretch (`Vector2(1.16, 0.88) → Vector2.ONE` elastic) for crisp impact feedback.
- **Harsh audio during rapid destruction** — `autoload/audio_manager.gd`: added 28ms minimum interval between brick-hit sounds.

### Changed
- **Feedback density caps** — `main.gd`: per-frame rate limits of 2 score popups and 2 shake requests; `try_spawn_score_popup()` with priority pass-through for large scores (≥100); audio brick-hit cooldown.
- **Durable-brick damage readability** — `entities/brick.gd`: `refresh_damage_visuals()` updates HP label, health bar, and progressive color darkening on each non-lethal hit.
- **Sticky prompt tightened** — `main.gd`: shortened from "AIM WITH PADDLE • STICKY RELEASE AUTO-FIRES" to "AIM • RELEASE TO FIRE".

---

## 2026-08-08 — Session 24: Feedback 0807 1350 fixes

### Fixed
- **Launch input unresponsive after life loss** — `main.gd`: renamed `launch_input_armed` → `suppress_launch_until_release`; only set on title-screen transition; normal READY states (life loss, level intro, unpause) accept the next press immediately.
- **Ball speed inconsistency at high endless-wave speeds** — `entities/ball.gd`: adaptive substeps with `MAX_PHYSICS_STEPS = 96`; processes all travel segments; residual move for severe frame hitches.
- **Shallow wall-rally paddle rebounds** — `entities/ball.gd`: added `MIN_UPWARD_COMPONENT = 0.38`; horizontal factor 0.9→0.82; simplified `_clamp_min_speed()`.
- **Opaque durable-brick micro-scores** — `entities/brick.gd`: non-lethal hits return `score_points = 0`; `main.gd`: combo/score skipped for `points <= 0`, muted sound plays.
- **Silent power-up drop on round-clear** — `main.gd`: `_on_powerup_collected()` accepts `ROUND_CLEAR` phase so in-flight power-ups resolve their effects.

### Changed
- **Sticky context prompt** — `entities/paddle.gd`: `sticky_ball_caught` / `sticky_ball_released` signals; `main.gd`: "AIM WITH PADDLE • STICKY RELEASE AUTO-FIRES" prompt; `ui/hud.gd`: `show_context_prompt()` / `hide_context_prompt()`.
- **Visual hierarchy** — `entities/brick.gd`: standard bricks darkened 12% at idle; hit flashes remain bright white. `main.gd`: slow overlay alpha 0.18→0.10.

---

## 2026-08-06 — Session 23: Feedback 0806 1530 fixes

### Fixed
- **Sticky expiry clobbers Big Paddle tint** — `paddle.gd`: new `refresh_visual_state()` derives paddle color from active effects (Sticky → `NEON_YELLOW`, Big Paddle → `NEON_LIME`, else `NEON_CYAN`); all direct `sprite.color` writes removed from `apply_big_paddle()`, `_reset_paddle_width()`, `enable_sticky()`, `_disable_sticky()`, `reset()`.
- **Phantom ball on non-bottom exit** — `ball.gd`: `_on_screen_exited()` treats any exit as a loss (idempotent `if not launched: return` guard) + redundant 64px bounds fallback in `_physics_process()`.
- **Launch input carryover** — `main.gd`: `launch_input_armed` requires the launch action to be released during READY before a press can launch; reset on every READY entry and cleared on launch.
- **Dead code** — `main.gd`: removed unused `score_sfx` var and `_get_phase()`; `main.tscn`: removed the stream-less `ScoreSfx` node.

### Changed
- **Sticky aim guide** — `paddle.gd`: `stick_ball()` shows the aim guide; `clear_sticky_aim()` on every release path; aim steers while a ball is caught (supersedes the Session 19 aim-freeze during Sticky).
- **Power-up chime** — `audio_manager.gd`: per-note envelope via `local_t` (three notes articulate independently instead of one global fade).

---

## 2026-08-06 — Session 22: Feedback 0708 2052 fixes

### Fixed
- **Dead laser aim plumbing removed** — `laser_manager.gd`: deleted unused `_paddle_aim_visible` field, `_sync_paddle_aim()` method, and its call from `set_paddle()`. `Paddle` never defined `set_laser_aim_visible()`, so this was a permanent no-op.
- **Shake state reset on level transition** — `main.gd` `_load_level()`: kills `_shake_tween`, resets `_shake_intensity` to `0.0`, restores `position` to `_base_position`. Previously only reset on full restart.
- **Conditional paddle redraw** — `paddle.gd`: `queue_redraw()` now gated behind `sticky_mode or show_aim or _edge_warn_left > 0.0 or _edge_warn_right > 0.0` in both `_process()` and `_physics_process()`.

---

## 2026-07-06 — Session 21: Feedback 0706 2120 fixes

### Fixed
- **Multiball + Sticky freeze** — `paddle.gd`: `stick_ball()` now returns `bool`; `ball.gd`: sticky catch conditional on success, falls through to normal bounce when paddle already has a ball.
- **ScreenTransition stuck overlay** — `screen_transition.gd`: added `is_busy()` and `force_reset()` public API; `main.gd`: replaced direct `_busy` access.
- **Restart state leakage** — `main.gd`: `_start_new_run()` resets combo count/timer/tween/label and shake tween/intensity/position.
- **Title screen variable shadowing** — `title_screen.gd`: renamed local `name` → `display_name`.

---

## 2026-06-28 — Session 20: Feedback 0628 2200 fixes

### Fixed
- **Laser manager orphaned nodes** — `main.gd`: split `_setup_laser_manager()` into `_bind_laser_manager()` (idempotent) and `_update_wall_bounds()`; timer/label creation moved to `_run_setup()` (one-time).
- **Victory transition retry** — replaced silent no-op when `ScreenTransition` busy with `while` retry loop.
- **Level comparison simplified** — `is_last_story_level` reduced to single comparison.

---

## 2026-06-26 — Session 19: Feedback 0626 1727 fixes

### Fixed
- **Stuck ball when paused** — `paddle.gd`: `_deferred_launch` flag prevents permanently stuck ball when sticky timer expires while paused.
- **Random ball escape** — `ball.gd`: stuck-escape threshold `> 1.0` → `> 0.01` for slow-moving balls.
- **Title screen race** — `title_screen.gd`: added `RunState.reset()` + tween lifecycle guard.

### Changed
- **Aim angle freeze** — `paddle.gd`: freezes `aim_angle` when sticky + stuck ball (preserves pre-catch tilt).
- **Title shimmer** — `title_screen.gd`: smooth `modulate` shimmer cycling 4 neon colors replaces abrupt font color change.
- **Glow rings** — `ball.gd`: uses `ball_color.lightened(0.3)` instead of white multiply.
- **Slow overlay** — `main.gd`: tinted `NEON_PURPLE` (alpha 0.18).
- **Launch sound** — `audio_manager.gd`: mixes 2nd harmonic for punchier attack.

---

## 2026-06-25 — Session 18: Feedback 0625 0009 fixes

### Fixed
- **Callback injection** — `paddle.gd`: replaced `get_parent().has_method()` introspection with injected `Callable` for sticky release.
- **Laser scoring** — `laser_manager.gd`: unified scoring to consume `hit.score_points` from brick (eliminated hardcoded `5`).

### Changed
- **Ball collision stepping** — `ball.gd`: dynamic `while remaining` loop (max 10 steps) replaces fixed 4-step cap for anti-tunneling.
- **Brick hit contract** — `brick.gd`: added `score_points` to hit dictionary + tween lifecycle guards.

---

## 2026-06-22 — Session 17: Feedback 0622 2236 fixes

### Fixed
- **Endless Mode setup crash** — `main.gd`: `_ready()` + `_run_setup()` restructured so one-time setup always runs regardless of entry path.
- **Combo tween race** — `main.gd`: store/kill `_combo_tween` member, reset `modulate.a = 1.0`.
- **Combo label anchoring** — moved to `hud` (CanvasLayer) for working anchors + no shake jitter.
- **Score popup shake offset** — `main.gd`: subtracts shake offset via `_base_position`.

### Changed
- **Power-up rotation** — `powerup.gd`: rotates `Sprite` (box+label) instead of just label.
- **Boss glow** — `brick.gd`: tween stored as `_glow_tween` member.

---

## 2026-06-21 — Session 16: Feedback 0621 1054 fixes

### Fixed
- **Brick hit contract** — `brick.gd`: `take_damage()` returns structured Dictionary (fixes kill-shot bounce/score ambiguity).
- **Ball attach offset** — `paddle.gd`: `get_ball_attach_offset()` replaces all hard-coded `Vector2(0, -30)`.

### Changed
- **Launch spread** — narrowed ±8° → ±3°.
- **Transition hardening** — `screen_transition.gd`: `_reset_overlay_state()` helper on all exit paths.
- **Session entry** — `main.gd`: centralized via `start_new_run()`.
- **Standard bricks** — `lerp(Color.WHITE, 0.08)` + `modulate.a = 0.92`.

---

## 2026-06-13 — Session 15: Feedback 0613 1731 fixes

### Fixed
- **Intro race** — generation counter replaces `_intro_running` boolean.
- **Brick collision fallthrough** — explicit bounce + return.
- **Phantom life loss** — `ROUND_CLEAR` phase set before any `await`.
- **ScreenTransition** — checked + warning before victory scene.

### Changed
- **Combo label** — anchor centering replaces `get_minimum_size()`.
- **Power-up rotation** — only visual label (not collision shape).
- **Audio** — PCM tone pool pre-baked for brick hits.

---

## 2026-05-31 — Session 14: Feedback 0531 2223 fixes

### Fixed
- **Victory transition race** — halt balls before scene swap + `phase = VICTORY` first.
- **ScreenTransition snapback** — `fade_in()` guard.
- **Wall offsets** — derived from `CollisionShape2D` shape size.
- **Power-up drop throttle** — per-frame cap of 2.

### Changed
- **Laser scoring** — `is_scored()` guard moved before `take_damage()`.
- **Paddle timers** — `PROCESS_MODE_PAUSABLE`.
- **Mouse-drag input** — pause-aware.
- **Score popups** — use `get_canvas_transform()`.
- **Boss brick flash** — pre-captures `target_color`.

---

## 2026-05-28 — Session 13: Review-Driven Refinement

### Added
- Score popup system
- Mute toggle (M key)
- Mouse/touch paddle input
- Combo pitch scaling
- Power-up pickup animation
- Big Paddle green tint
- Laser fire sound

### Fixed
- LaserManager timer destruction
- Heart animation visibility
- Flash/slow overlay camera-shake immunity
- Brick VFX scene-parent

### Performance
- Cached level config
- `paddle_spawn_pos` helper
- Audio byte-packing dedup
- Ball trail ref caching

---

## 2026-05-27 — Session 12: Comprehensive Improvement

### Added
- **Audio system** — `AudioManager` autoload with 7 synthesized tones
- Life loss red flash
- Slow purple tint
- Enhanced playfield border
- Dynamic ring effect arcs
- Brick damage flash + scale punch
- Paddle edge warnings
- Combo label font scaling + bounce-in
- Enhanced pause (score + level)
- High score detection + 1s restart delay

### Fixed
- Ball substep physics (anti-tunneling)
- Stuck-ball escape direction
- Screen transition deadlock guard
- Level intro race condition
- Multiball null paddle ref

---

## 2026-05-27 — Session 11: Feedback 0527 fixes

### Fixed
- Combo label `reset_minimum_size()` on first call
- Screen shake accumulated intensity + single tracked tween
- Slow-ball HUD timer clear on early restore
- Orphaned await guard on victory
- Dual-source `_scored` flag on Brick
- Confetti timer stop on victory screen exit

---

## 2026-05-26 — Sessions 9–10: Incremental Refinements

### Fixed
- Multiball clone trail color (was yellow → magenta)
- Laser scoring guarded against round-clear
- Background particle alpha copy bug
- Score tween stacking
- Power-up collection guarded during non-PLAYING phases

### Changed
- Brick entrance stagger 0.025→0.015s
- Confetti timer-based spawn replaces teleport-loop
- Ball glow redraws on color change

---

## 2026-05-26 — Sessions 7–8: Initial Polish

### Added
- `ScreenTransition` autoload
- Title screen floating particles + pulsing glow
- Victory screen bounce-in + confetti
- Combo scoring system
- Screen shake
- Power-up flash ring effect
- RingEffect (replaces square flash)
- Boss HP bar

### Fixed
- Laser scoring double-emit
- Slow balls restoration with `_slow_factor`
- Power-ups respect pause
- Combo capped at 15 count / 10× bonus

### Changed
- Ball launch randomness ±15° → ±8°
- Stuck-ball escape after 30 frames
- Staggered brick entrance with `TRANS_BACK`

---

## 2026-05-11 — Session 6: Feedback 0511 fixes

### Fixed
- Life loss while paused (PAUSED phase guard)
- In-flight lasers cleared on level load
- Aim V-lines hidden during ROUND_CLEAR

### Changed
- Power-up fall speed scales in endless mode
- Boss brick glow uses `row_color`
- Labels use center anchors
- `PowerUpRegistry` extends `Object`

---

## 2026-05-10 — Sessions 4–5: Feedback 0509–0510 fixes

### Fixed
- HUD timer bars split into independent tweens
- Aim lines restored on life loss
- Brick destruction particles reparented
- Multiball sticky reject guard
- Laser deactivates on level load
- Multiball race with `_life_lost_pending` flag
- Ball spawn `_NO_POS` sentinel

### Changed
- Title screen power-up legend 2-column layout
- Power-up drift with unique phase

---

## 2026-05-09 — Session 3: Feedback 0509 fixes

### Fixed
- Modulate double-coloring in `level_builder.gd`
- LEVEL_INTRO phase guard in `_on_ball_lost()`

### Changed
- Power-up cooldown 2.0→0.8s
- Paddle clamp +10px margin
- Boss pulse uses `glow_intensity` shader param
- Power-up sine drift + rotation

---

## 2026-05-08 — Session 2: Feedback 0508 fixes

### Fixed
- ROUND_CLEAR guard in `_on_ball_lost()`
- ShaderMaterial cached in `_ready()` instead of recreated per `take_damage()`

### Changed
- Ball 3-layer glow halo
- Brick damage particles match brick color
- Power-up pulse tween
- Removed vestigial TITLE phase

---

## 2026-05-05/06/07 — Session 1: Initial Build

### Added
- Opening title screen with GameState phases (TITLE, LEVEL_INTRO, ROUND_CLEAR)
- Multi-effect HUD with concurrent timer strip
- Level intro panel with stage name + subtitle
- Power-up registry with central metadata
- 5 authored level identities with weighted drop tables
- Endless mode (unlocked after Level 5)
- 15 code review issues resolved
- Ball rendered as circle via `_draw()`
- Brick glow shader

---

*Derived from `docs/retro_MMDD.md` and `docs/history.md`.*
