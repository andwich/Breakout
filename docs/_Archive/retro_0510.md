# Session Notes — 2026-05-10

## Summary (Session 5 — 0510 2035)

Addressed all 10 issues from `docs/breakout-implementation-plan 0510 2035.md`:

### Critical Fixes

| # | Issue | Files Changed |
|---|-------|---------------|
| 1 | Laser keeps firing after level transition (not deactivated on `_load_level()`) | `main.gd` |
| 2 | Multiball: multiple balls lost same frame → multiple lives lost (race condition) | `main.gd` |

### Significant Fixes

| # | Issue | Files Changed |
|---|-------|---------------|
| 3 | Level subtitle displays redundant prefix ("LEVEL 1 — LEVEL 1 — ...") | `main.gd` |
| 4 | Weak `Vector2.ZERO` sentinel for ball spawn position | `main.gd` |
| 5 | Power-up effect timers not cleared on level load (compound with #1) | `main.gd` |
| 6 | Title power-up legend overflows 600px container | `ui/title_screen.gd` |

### Gameplay/Robustness Fixes

| # | Issue | Files Changed |
|---|-------|---------------|
| 7 | Brick VFX particles leak memory (not freed after playing) | `entities/brick.gd` |
| 8 | Victory check uses magic number `== 5` instead of constant | `main.gd` |
| 9 | Slow ball applies 60% of base_speed, not current level-scaled speed | `main.gd` |

### Polish Fix

| # | Issue | Files Changed |
|---|-------|---------------|
| 10 | HighScoreLabel misaligned, overlaps LevelLabel | `ui/hud.tscn` |

### Implementation Details

**Issue 1 — Laser deactivation on level load**
- Added `laser_manager.deactivate()` as first line in `_load_level()` before existing calls

**Issue 2 — Multiball race condition**
- Added `_life_lost_pending` flag at class level
- Refactored `_on_ball_lost()` to guard with `_life_lost_pending`, use `call_deferred("_process_life_loss")`
- New `_process_life_loss()` function handles life decrement, game over check, and round reset
- Added `VICTORY` and `TITLE` to phase guard (preserved existing `READY`)

**Issue 3 — Subtitle prefix removed**
- Replaced `_level_subtitle_text()` body to return only `intro_text` config value, no prefix

**Issue 4 — `_NO_POS` sentinel**
- Added `const _NO_POS := Vector2(-99999.0, -99999.0)` at class level
- Changed `_spawn_ball()` default param from `Vector2.ZERO` to `_NO_POS`
- Changed guard from `at == Vector2.ZERO` to `at == _NO_POS`

**Issue 5 — HUD timers cleared on level load**
- Confirmed `hud.clear_all_effect_timers()` already present
- Moved to execute before `_slow_timer.stop()` (after `laser_manager.deactivate()`)

**Issue 6 — 2-column title legend**
- Replaced single `"  ".join(lines)` with manual 2-column layout:
  - Slice lines into left (0-3) and right (3-6)
  - Format each row with `%-28s` padding
  - Join with explicit newlines

**Issue 7 — Particle leak**
- Added `vfx.finished.connect(vfx.queue_free)` in `brick.gd::destroy()` after `one_shot = true`

**Issue 8 — Victory constant**
- Added `const BASE_LEVEL_COUNT := 5`
- Changed `current_level == 5` to `current_level >= BASE_LEVEL_COUNT`

**Issue 9 — Slow ball speed**
- In `_spawn_ball()`: changed `ball.base_speed * 0.6` to `ball.speed * 0.6`
- In `_apply_slow_balls()`: changed `b.base_speed * 0.6` to `b.speed * 0.6`
- Slow now applies to already-level-scaled speed, not base

**Issue 10 — HighScoreLabel anchor**
- Changed anchor from top-left to right edge: `anchor_left = 1.0`, `anchor_right = 1.0`
- Changed offsets to `-220.0` to `-20.0` (relative from right edge)

### Files Modified

| File | Changes |
|------|---------|
| `main.gd` | +laser_manager.deactivate(), +_life_lost_pending, +_process_life_loss(), +BASE_LEVEL_COUNT, +_NO_POS, _level_subtitle_text() stripped, slow uses level-scaled speed |
| `ui/title_screen.gd` | 2-column legend layout |
| `entities/brick.gd` | +vfx.finished.connect(vfx.queue_free) |
| `ui/hud.tscn` | HighScoreLabel right-anchored |

**Total: 4 files, 10 issues**

---

## Summary (Session 4 — 0509 2200)

Addressed all 10 issues from `docs/Feedback 0509 2200.md`:

### Issues Fixed

| # | Severity | Issue | Files Changed |
|---|----------|-------|---------------|
| 1 | Critical | HUD effect timer bar clears ~1.7s too early (tween callback fires after amber step, not value tween) | `ui/hud.gd` |
| 2 | Critical | Aim lines vanish after losing a ball (`show_aim` never restored in `_reset_round_after_life_loss`) | `main.gd` |
| 3 | Moderate | Brick destruction particles vanish instantly (child particles killed with `queue_free()` before playing) | `entities/brick.gd` |
| 4 | Moderate | Multiball + sticky: only the last ball sticks (single `stuck_ball` reference overwritten by second ball) | `entities/paddle.gd` |
| 5 | Moderate | Cooldown blocks the only drop at sparse brick counts (chance roll succeeds but cooldown gate discards it) | `main.gd` |
| 6 | Moderate | Ball lost during READY still costs a life (`READY` missing from phase guard) | `main.gd` |
| 7 | Polish | Level intro title omits the level number (authored name shown without prefix like "LEVEL 1  ·  ") | `main.gd` |
| 8 | Polish | Power-ups drift in perfect unison (no per-instance phase offset in sine drift) | `entities/powerup.gd` |
| 9 | Polish | BackgroundOverlay hardcoded to 1280×720 (fixed pixel offsets break on resize/HiDPI) | `main.tscn` |
| 10 | Polish | EffectList anchored in fixed pixel space (no relative anchoring to right/bottom edges) | `ui/hud.tscn` |

### Implementation Details

**Issue 1 — HUD tween bar clears early**
- Split the single tween chain into two independent tweens
- `val_tw` tweens bar value over full duration, fires `clear_effect_timer` on completion
- `warn_tw` waits `duration_sec - 2.0`, then tweens modulate to amber (if `> 2.0s`)
- Both stored as array in `_effect_tweens[effect_id]`; `clear_effect_timer` now iterates and kills each

**Issue 2 — Aim lines gone after life loss**
- Added `paddle.show_aim = true` in `_reset_round_after_life_loss()` after setting phase to `READY`
- Mirrors behavior in `_begin_ready_phase()`

**Issue 3 — Brick particles vanish**
- In `destroy()`, before `queue_free()`:
  - Duplicate the `GPUParticles2D`
  - Reparent to `get_tree().root`
  - Set `emitting = true`, `one_shot = true`
  - Set global position to brick's position

**Issue 4 — Multiball sticky orphans**
- Added guard in `stick_ball()`:
  ```gdscript
  if stuck_ball and is_instance_valid(stuck_ball):
      return
  ```
- Second ball bounces off; first stays held

**Issue 5 — Cooldown blocks drop**
- Moved `randf() < drop_chance` check into `_spawn_powerup()` BEFORE the cooldown check
- Added `drop_chance: float` parameter to `_spawn_powerup()`
- Removed `randf() < drop_chance` from `_on_brick_destroyed()`
- No more wasted rolls

**Issue 6 — Ball lost during READY**
- Added `GameState.Phase.READY` to phase guard list in `_on_ball_lost()`

**Issue 7 — Level title missing prefix**
- In `_level_title_text()`, added prefix calculation:
  ```gdscript
  var prefix := "LEVEL %d  ·  " % current_level if current_level <= 5 \
      else "WAVE %d  ·  " % (current_level - 5)
  return (prefix + authored).to_upper()
  ```

**Issue 8 — Power-up unison drift**
- Added `_drift_phase: float` member variable
- Initialize in `_ready()`: `_drift_phase = randf() * TAU`
- Use in `_physics_process()`: `sin(Time.get_ticks_msec() * 0.003 + _drift_phase)`

**Issue 9 — BackgroundOverlay hardcoded**
- Changed `anchors_preset = 0` (Full Rect) → `anchors_preset = 15`
- Added `anchor_right = 1.0`, `anchor_bottom = 1.0`
- Removed fixed `offset_right = 1280.0`, `offset_bottom = 720.0`

**Issue 10 — EffectList/LivesContainer fixed pixels**
- EffectList: anchored bottom-right (`anchor_left = 1.0`, `anchor_right = 1.0`, `anchor_top = 1.0`, `anchor_bottom = 1.0`, offsets from edges)
- LivesContainer: anchored to right edge (`anchor_left = 1.0`, `anchor_right = 1.0`, `offset_left = -180`)

### Files Modified

| File | Changes |
|------|---------|
| `ui/hud.gd` | +Two independent tweens, array-based tween storage, kills both in clear |
| `main.gd` | +show_aim restore, READY guard, drop_chance reorder, level prefix |
| `entities/paddle.gd` | +Sticky ball reject guard |
| `entities/brick.gd` | +Particle duplicate + reparent before queue_free |
| `entities/powerup.gd` | +_drift_phase random init, used in sine drift |
| `main.tscn` | +BackgroundOverlay full-rect anchors |
| `ui/hud.tscn` | +EffectList + LivesContainer edge anchors |

**Total: 7 files, 10 issues, ~55 net lines**

---

## Suggestions for Next Session

### High Priority

1. **Playtest all 10 fixes** — Run through: title → level intro → lose ball → verify aim lines return → play through power-up collection → verify timer bars don't clear early → verify particles play → verify multiball sticky works → verify sparse brick drops work correctly

2. **End-to-end stress test** — Play through to endless mode, verify multiple power-ups on screen at once (test drift phase), verify resize doesn't break UI anchors

### Medium Priority

3. **Attract Mode / Demo Loop** — Add a short autoplay demo showing ball movement, brick hits, power-up activation to the title screen

4. **Sound Effects** — Add audio for ball launch, brick hit, power-up collect, life lost. The `ScoreSfx` player exists but has no stream.

5. **Level Patterns** — The `level_defs.gd` has `brick_pattern` field but it's not used yet. Add actual pattern variations (checkerboard, diagonal, pyramid) via `level_builder.gd`.

### Lower Priority

6. **VFX Container** — Currently particles are reparented to `get_tree().root`. Consider a dedicated `VFX` node under main to batch particle management and enable post-processing.

7. **Edge Cases** — Test ball launch during rapid window resize, multiple balls stuck simultaneously (verify #4 handles edge case where first ball gets freed), pause during READY phase

---

*All 10 issues from Feedback 0509 2200 resolved. Ready for playtesting.*