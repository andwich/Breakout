# Session 14 — Code Review Fixes (2026-05-31)

**Theme:** 13-issue review of `docs/Feedback 0531 2223.md` — launch/scene management, play mechanics, and aesthetic polish. All fixes applied in one pass; no new files; no structural changes.

---

## Summary

| Severity | Count | Issues |
|----------|-------|--------|
| **CRITICAL** | 2 | Victory transition race, victory check semantics |
| **HIGH** | 3 | `fade_in` snapback, multiball drop throttling, hardcoded wall thickness |
| **MEDIUM** | 4 | Laser double-score, timer pause drift, redundant normalize, pause-drag |
| **LOW** | 4 | Popup coord drift, boss color flicker, sticky visual, HUD modulate leak |

**Files touched (7):** `main.gd`, `autoload/screen_transition.gd`, `entities/laser_manager.gd`, `entities/paddle.gd`, `entities/ball.gd`, `entities/brick.gd`, `ui/hud.gd`.

---

## Fixes by Category

### Phase 1 — Critical (2)

| # | File | Change |
|---|------|--------|
| 1 | `main.gd` | **Victory transition doesn't halt balls before scene swap** — Added a ball-polling loop in `_resolve_round_clear()` that calls `set_physics_process(false)` on every `Ball` child before `ScreenTransition.change_scene()`. The primary defense is the `phase = VICTORY` assignment placed *before* the loop — `_on_ball_lost` early-returns on the VICTORY phase entry, so any straggling `life_lost` signal is rejected. The `set_physics_process(false)` is defense-in-depth. |
| 2 | `main.gd` | **Victory check semantically wrong for endless** — Wrapped the `current_level == LevelDefs.base_levels().size()` check behind an explicit `is_last_story_level` local that also gates on `RunState.start_level <= base_levels().size()`. Defensive-only today (endless re-entry sets `start_level` to `defs.size() + 1` but `main.gd:45` resets it to 1 before the level completes), but documents intent and prevents future regressions. |

### Phase 2 — High (3)

| # | File | Change |
|---|------|--------|
| 3 | `autoload/screen_transition.gd` | **`fade_in()` snapback** — Added guard `if _overlay.color.a < 0.05: return` at the top of `fade_in()`. Scenes launched from the editor ("Run This Scene") or via rapid scene-restart now skip the `from(1.0)` tween entirely. `change_scene()` is the only `await`er and always calls `fade_in` after `fade_out` (overlay opaque), so the guard never fires in the normal scene-swap flow. |
| 4 | `main.gd` | **Wall boundary offsets hardcode thickness** — Replaced `+ 10.0` / `- 10.0` with `left_shape.size.x / 2.0` / `right_shape.size.x / 2.0` by casting the scene's `CollisionShape2D.shape` to `RectangleShape2D`. `main.tscn:42` confirms the shape is `RectangleShape2D`, so the cast is safe. |
| 5 | `main.gd` | **Global powerup drop cooldown penalizes multiball** — Replaced the 0.4s time-gate on `_last_powerup_drop_time` with a per-frame cap of max 2 simultaneous drops. Added a `_physics_process(_delta: float)` method that resets `_drops_this_frame = 0` every tick. Relies on Godot's tree-order `_physics_process` execution: parent (main) runs before children (balls), so the counter is reset before any `_spawn_powerup` calls in the same frame. |

### Phase 3 — Medium (4)

| # | File | Change |
|---|------|--------|
| 6 | `entities/laser_manager.gd` | **Laser `is_scored()` guard fires after `take_damage()`** — Moved the `body.is_scored()` early-return to *before* `take_damage(1)` in the body_entered lambda. Both ball and laser paths now check `is_scored()` first; if a ball and laser hit the same brick in the same frame, only one score event fires. |
| 7 | `entities/paddle.gd` | **Sticky and big-paddle timers run while paused** — Set `_big_paddle_timer.process_mode = Node.PROCESS_MODE_PAUSABLE` and `_sticky_timer.process_mode = Node.PROCESS_MODE_PAUSABLE` in `_ready()`. Default `INHERIT` propagation left timers ticking during pause, silently draining effect duration and losing sticky state on unpause. |
| 8 | `entities/ball.gd` | **Ball bounce branch double-normalizes** — Removed the redundant `velocity = velocity.normalized() * speed` in the wall/brick bounce branch (inside the `else:` of `if collider is Paddle:`). The subsequent `_clamp_min_speed()` already ends with the same expression, so the caller no longer needed to pre-normalize. |
| 9 | `entities/paddle.gd` | **Mouse-drag paddle input ignores pause state** — Added `if get_tree().paused: return` at the top of `_physics_process()`. The keyboard `direction` was already pause-aware via upstream `_unhandled_input`; the mouse-drag branch (which reads `Input.is_mouse_button_pressed()` directly) was not. Bonus: the `if sticky_mode: queue_redraw()` added in issue 12 sits *after* the pause guard, so the pulse correctly freezes during pause. |

### Phase 4 — Low (4)

| # | File | Change |
|---|------|--------|
| 10 | `main.gd` | **Score popups use world-space coords in a CanvasLayer** — Converted `_spawn_score_popup()` to use `var screen_pos := get_viewport().get_canvas_transform() * world_pos` for both the initial label position and the tween target anchor. Latent today (no Camera2D), but protected against future drift. |
| 11 | `entities/brick.gd` | **Boss brick damage flash can restore wrong color mid-glow tween** — Added a `brick_type == "boss"` branch in `take_damage()`. The `row_color.darkened(...)` target is pre-captured before the tween, so color animates: dimmed → white → target_color without a callback re-running `_update_visual()` (which would race with the looping `glow_intensity` shader tween). Non-boss bricks keep the original flash path via `_update_visual()` callback. |
| 12 | `entities/paddle.gd` | **Sticky paddle has no persistent visual between catches** — Added a pulsing yellow border rect at the top of `_draw()` (sine-driven alpha of `pulse * 0.35` with `Time.get_ticks_msec() * 0.006` as the time argument). Added `if sticky_mode: queue_redraw()` at the end of `_physics_process()` so the pulse animates even when the paddle is stationary. The redraw is gated by the pause guard from issue 9, so it correctly halts when paused. |
| 13 | `ui/hud.gd` | **HUD effect bar doesn't reset its modulate color when cleared early** — Added `row.bar.modulate = Color.WHITE` in `clear_effect_timer()` *before* hiding the row. Effect rows are reused via `_effect_rows`, so any row previously in amber warning state (set by the warning tween at `set_effect_timer`) would otherwise stay amber when reused. The next `set_effect_timer` call will overwrite with the new tint, so the reset is purely a safety net. |

---

## Files Changed

| File | Issues | Severity |
|---|---|---|
| `main.gd` | 1, 2, 4, 5, 10 | CRITICAL / HIGH / LOW |
| `autoload/screen_transition.gd` | 3 | HIGH |
| `entities/laser_manager.gd` | 6 | MEDIUM |
| `entities/paddle.gd` | 7, 9, 12 | MEDIUM / LOW |
| `entities/ball.gd` | 8 | MEDIUM |
| `entities/brick.gd` | 11 | LOW |
| `ui/hud.gd` | 13 | LOW |

**No new files. No new autoloads. No scene changes.** `docs/retro_0531.md` (this file) is the only documentation change.

---

## Code Review (post-implementation)

All 13 fixes were re-verified after implementation for correctness:

- **Issue 1 ordering verified:** `phase = VICTORY` is set on line 290 *before* the ball loop on lines 292-294. The `_on_ball_lost` early-return list (line 306) includes `GameState.Phase.VICTORY`, so any straggling `life_lost` signal is rejected. The `set_physics_process(false)` is belt-and-suspenders.
- **Issue 5 ordering verified:** Godot's `_physics_process` runs in tree order (parent first, then children). `main.gd` is the parent of `balls_container`, so the new `_physics_process` resets the counter before any ball's physics step can call `_spawn_powerup`.
- **Issue 9 + 12 interaction verified:** The pause guard at `paddle.gd:65-66` is the first statement in `_physics_process`. Both the mouse-drag input and the `if sticky_mode: queue_redraw()` at line 89-90 sit *after* the guard, so both are correctly suppressed during pause.
- **Issue 11 boss branch verified:** The new tween animates `_sprite.color` from its current value (set to `dimmed` by `_update_visual()` at line 66) to `Color.WHITE` (0.04s) then to the saved `target_color` (0.07s). The looping `glow_intensity` shader tween in `_ready()` (lines 58-62) is independent — it only sets the `glow_intensity` shader parameter, not `_sprite.color`. No race.
- **Issue 13 ordering verified:** `row.bar.modulate = Color.WHITE` is set at line 190, before `row.root.visible = false` at line 191. The next `set_effect_timer` call (line 167) will set `row.bar.modulate = tint`, so the reset is invisible during normal flow.

### Observations (out of scope, future session)

- **`_slow_timer` in `main.gd` (line 28)** has the same pause-drain concern as the paddle timers fixed in issue 7. It is created without an explicit `process_mode`, so it inherits from main, which is `INHERIT` (effectively `PAUSABLE` via the SceneTree). This is currently a *latent* bug — pausing during slow will leave the timer running, and unpause can fire `_restore_ball_speeds` after a level transition. Not fixed in this pass to limit scope, but worth addressing next session.
- **Issue 2 guard is defensive-only** as noted. If `RunState.start_level` is ever changed to preserve its value across main.gd entries (e.g., for a tutorial or level-select feature), the guard becomes load-bearing.

---

## Verification

Manual testing via Godot editor F5 / "Run This Scene":

- [ ] Run scene "Run This Scene" on `main.tscn` does **not** flash black (issue 3)
- [ ] Clear level 5 (Breach Point) with 1 ball — no score corruption on victory (issue 1)
- [ ] Trigger multiball, destroy 4+ bricks in same frame — multiple drops spawn (issue 5)
- [ ] Activate laser + ball hit same brick in same frame — single score event (issue 6)
- [ ] Pause during sticky mode — timer doesn't drain (issue 7)
- [ ] Pause, drag mouse — paddle stays still (issue 9)
- [ ] Boss brick 5+ hits — no wrong-shade flicker (issue 11)
- [ ] Activate sticky, release ball, paddle still shows pulse (issue 12)
- [ ] Activate slow, level transition during slow — next slow effect bar is correct color (issue 13)
- [ ] Wall geometry change in `main.tscn` — paddle still clamps correctly (issue 4)
- [ ] New `_physics_process` in `main.gd` does not regress the level intro / ready / round clear phase timing (issue 5 sanity)

---

## Suggestions for Next Session

### Correctness (Medium)

- **Slow-timer pause-drain (follow-up to issue 7):** Set `_slow_timer.process_mode = Node.PROCESS_MODE_PAUSABLE` in `main.gd:57-60`. The timer is currently inheriting from main and can drain during pause, leading to a phantom `_restore_ball_speeds` call after a level transition. Add to the issue 7 fix style.
- **VisibleOnScreenNotifier2D during victory halt:** Issue 1 disables `_physics_process` on the ball but the notifier's `screen_exited` signal is driven by the engine, not the script. The current fix relies on the `phase = VICTORY` guard catching any `life_lost` emit, but a more robust solution would also disconnect the notifier before the scene swap. Consider `ball.set_physics_process(false); notifier.disconnect("screen_exited", _on_screen_exited)`.

### Code Health (Low)

- **Issue 5 `_drops_this_frame` reset duplication:** With the per-frame counter, the global `_last_powerup_drop_time` field is no longer needed. If any other system depends on it (none currently), consider migrating. The variable was deleted in this pass; if any saves or runs depend on it, document the migration.
- **Issue 4 wall offset cast safety:** The `as RectangleShape2D` cast returns null on type mismatch. If the scene is ever refactored to use a different shape type, the next-line `left_shape.size.x` will crash. Consider `if left_shape: ... else: push_warning(...)`.

### Polish (Low)

- **Sticky pulse color:** Currently `Color(1.0, 1.0, 0.4, ...)` (yellow). Could be theme-driven via `GameTheme.NEON_LIME` or similar for consistency.
- **Boss flash duration:** 0.04s white + 0.07s return may feel slow on rapid hits. Consider adding a `time_scale` parameter for future per-brick flash customization.

---

*Session duration: ~1 hour, 13 fixes across 7 files, 1 new doc.*


