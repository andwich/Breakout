# Retro 0626 — Feedback 0626 1727 Fixes

## Summary

**8 fixes across 5 files (+ docs)** — full rollout of 8 items from `docs/Feedback 0626 1727.md` covering bug fixes, play mechanics, and aesthetic refinements.

---

## Changes

| Priority | Fix | File | Lines |
|----------|-----|------|-------|
| High | FIX 1: `RunState.reset()` in title screen + kill glow tween | `ui/title_screen.gd` | +7/−2 |
| High | FIX 2: Sticky timer expiry when paused — deferred launch on unpause | `entities/paddle.gd` | +16/−4 |
| High | FIX 3: Stuck-escape threshold `> 1.0` → `> 0.01` | `entities/ball.gd` | +1/−1 |
| Medium | FIX 4: Freeze `aim_angle` when sticky + stuck ball | `entities/paddle.gd` | +2/−1 |
| Medium | FIX 5: Title shimmer via `modulate` cycling 4 neon colors | `ui/title_screen.gd` | +13/−5 |
| Medium | FIX 6: Ball glow rings use `ball_color.lightened(0.3)` | `entities/ball.gd` | +4/−3 |
| Medium | FIX 7: Slow overlay tinted `NEON_PURPLE`, alpha `0.18` | `main.gd` | +3/−2 |
| Medium | FIX 8: Launch sound adds 2nd harmonic at 2× frequency | `autoload/audio_manager.gd` | +4/−1 |

**Files modified:** `ui/title_screen.gd`, `entities/paddle.gd`, `entities/ball.gd`, `main.gd`, `autoload/audio_manager.gd`, `docs/AGENTS.md`

**Totals:** +51 / −15 lines across 6 files.

---

## Design Decisions

- **FIX 2 (deferred launch):** Used `_process()` instead of `_physics_process()` because `_physics_process` returns early when the tree is paused. `_process` runs on the first frame after unpause, catching the `paused == false` transition.
- **FIX 4 (aim angle freeze):** The original feedback suggested saving/restoring `aim_angle` from before velocity cleared. I chose a simpler approach — conditionally skip the `aim_angle` update when `sticky_mode && stuck_ball` is valid — which achieves the same effect without an extra storage variable.
- **FIX 5 (title shimmer):** Replaced the existing `_title_glow()` `theme_override_colors/font_color` approach with `modulate` tweening, which gives a smooth color blend rather than abrupt hue snaps. The tween is stored in `_title_glow_tween` and killed in `_start_game()` to prevent dangling.
- **FIX 6 (ball glow):** Increased alpha values (0.12→0.15, 0.25→0.30) to compensate for the softer `lightened()` approach vs the previous white-multiply that was brighter on yellow but nearly invisible on other colors.
- **FIX 7 (slow overlay):** `NEON_PURPLE` was chosen because the power-up already uses purple in `PowerUpRegistry` — this visually links the screen effect to the power-up source. Alpha 0.18 was picked as the minimum visible on `NEON_BG` without washing out gameplay.

---

## Suggestions for Next Session

### Unaddressed Feedback Items

1. **`ScreenTransition.busy` victory guard** (`main.gd:317`)
   - Currently pushes a warning and silently fails the victory transition if `ScreenTransition._busy` is true (e.g., from the level intro fade).
   - **Suggest:** Replace the `if _busy` guard with a polling approach — store `_pending_victory = true` and check in `_process` until `_busy` clears, then call `change_scene`. Or make `ScreenTransition.change_scene()` queue-able.

2. **Level intro `introgen` timer can't be cancelled** (`main.gd:169`)
   - `create_timer(1.0)` returns a `SceneTreeTimer` that cannot be stopped. If `load_level` is called twice rapidly, the old timer always completes (even if the gen check skips it).
   - **Suggest:** Replace the `SceneTreeTimer` with a member `Timer` node (created once in `_run_setup`, started in `_start_level_intro`, stopped in `_load_level`). This gives full cancellation control.

3. **HP label fixed offset** (`brick.tscn`)
   - Boss brick HP label uses fixed `-8`/`8` pixel offsets. Multi-digit HP values appear off-center.
   - **Suggest:** Set `size_flags_horizontal = SIZE_SHRINK_CENTER` on the label and remove the fixed offset.

### Low Priority / Future

4. **Multiball + laser interaction** — The feedback notes that multiball clones don't call `_setup_laser_manager`. This is by design (laser fires from paddle, not balls), but it's not explicitly documented anywhere. Add a comment in `main.gd`'s MULTIBALL branch.

5. **`aim_angle` pre-catch save** — The current FIX 4 freezes aim angle when the ball is stuck. The original feedback also suggested saving it before velocity clears so sticky re-aim respects the last known direction even on the first frame. This could be tightened in a follow-up.
