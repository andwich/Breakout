# Retro: 2026-08-09 — Session 26

## Feedback 0809 1445 — Hardening Pass

### Summary

10 changes across 6 files — compile hardening, reliability, and teardown safety from `docs/Feedback 0809 1445.md`.

### Changes

#### P0 (1) — Launch Blocker
- **`autoload/audio_manager.gd`** — Typed `notes` as `Array[float]` and `freq` as `float` in `play_powerup()`. Fixes Godot 4 static analyzer failure on `:=` inference from untyped Array index.

#### P1 (3) — Reliability
- **`autoload/audio_manager.gd`** — Typed `_make_chord(freqs: Array[float], ...)` parameter and loop variable; removed `float(f)` cast; updated call sites with `as Array[float]`. Prevents same `Variant` propagation that caused `play_powerup()` to fail.
- **`autoload/audio_manager.gd`** — Added `_master_bus_index()` helper with `push_warning` on missing bus; `toggle_mute()` and `set_volume_db()` now guard with `if idx >= 0`. Protects startup if default audio bus layout is altered.
- **`autoload/audio_manager.gd`** — Preallocated 12-player `AudioStreamPlayer` pool in `_ready()`; `_play_stream()` reuses non-playing players via round-robin; no per-effect node allocation/deallocation. Eliminates scene-tree churn during dense laser/multiball gameplay.
- **`autoload/save_data.gd`** — Added `file.close()` after read/write; `push_warning` on null file handles; `parsed is Dictionary` type check; `max(0, int(...))` guard on parsed value. Prevents file handle leaks and malformed save data.

#### P2 (2) — Robustness
- **`autoload/screen_transition.gd`** — Added `_fade_tween: Tween` member and `_replace_fade_tween()` helper that kills existing tween before creating new one; `fade_in()` and `fade_out()` use the helper; `force_reset()` kills the fade tween. Prevents stale tweens modifying overlay alpha after forced reset.
- **`project.godot`** — Added `window/stretch/mode="canvas_items"` and `window/stretch/aspect="keep"`. Enables aspect-preserving canvas scaling for Retina/ultrawide/non-16:9 displays.

#### P3 (3) — Teardown Safety
- **`entities/ball.gd`** — `attach_to_paddle()` adds `if _trail: _trail.emitting = false` and uses `is_instance_valid(paddle)` guard. Prevents trail persisting after loss and crashes during scene teardown.
- **`entities/ball.gd`** — Added `_exit_tree()` that kills `pop_tween` on tree exit.
- **`main.gd`** — Added `_flash_tween` and `_slow_tween` members; killed prior instances before creating new tweens in `_process_life_loss()`, `_apply_slow_balls()`, `_restore_ball_speeds()`; cleanup + alpha reset in `_start_new_run()`. Prevents overlapping tweens corrupting overlay state during rapid events.
- **`entities/brick.gd`** — Added `_exit_tree()` that kills `_flash_tween`, `_scale_tween`, `_boss_glow_tween`. Prevents orphaned tweens firing after `queue_free()`.

### Files Modified
- `autoload/audio_manager.gd` (P0 + P1)
- `autoload/save_data.gd` (P1)
- `autoload/screen_transition.gd` (P2)
- `project.godot` (P2)
- `entities/ball.gd` (P3)
- `main.gd` (P3)
- `entities/brick.gd` (P3)

### Testing Notes
1. Scan Godot debugger after F5 — no parser errors expected
2. Title screen → start with mouse and keyboard — launch not blocked
3. Stress multiball + lasers — watch Remote scene tree for player count stability (should be exactly 12)
4. Rapid restart during active effects — no visual glitches
5. Delete or corrupt `user://breakout_save.json` — game starts with zero high score
6. Resize window — canvas scales preserving aspect ratio
