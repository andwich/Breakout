# Session 20 — Feedback 0706 2120 fixes

- **6 changes across 4 files** — full rollout of issues from `docs/Feedback 0706 2120.md`
- **Critical (1)**: `paddle.gd` — `stick_ball()` now returns `bool`; `ball.gd` — sticky catch is conditional on success, falling through to normal paddle-bounce when paddle already has a caught ball. Fixes silent ball freeze in Multiball + Sticky combo.
- **High (1)**: `screen_transition.gd` — added `is_busy()` and `force_reset()` public API; `main.gd` — replaced direct `_busy` access with public methods. Prevents stuck black overlay on game over.
- **Medium (1)**: `main.gd` — `_start_new_run()` now resets `_combo_count`, `_combo_timer`, `_combo_tween`, `_combo_label`, `_shake_tween`, `_shake_intensity`, and `position` to baseline. Prevents combo/shake state leaking across runs.
- **Low (1)**: `title_screen.gd` — renamed local `name` → `display_name` to avoid shadowing `Node.name`.
- **Low (1, no action)**: `hud.tscn` — `HighScoreLabel` text already `""` (was previously `" "`), no change needed.
- **Files**: `entities/paddle.gd`, `entities/ball.gd`, `autoload/screen_transition.gd`, `main.gd`, `ui/title_screen.gd`
- **Docs**: `docs/agents.md` updated with ScreenTransition public API note

---

*See `docs/history.md` for summary. Feedback source: `docs/Feedback 0706 2120.md`.*
