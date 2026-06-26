# Session 15 — Feedback 0613 1731 fixes

**Date**: 2026-06-13

## Summary

9 fixes across 5 files — full rollout of issues identified in `docs/Feedback 0613 1731.md`.

## Fixes Applied

| # | Severity | File | Issue | Fix |
|---|----------|------|-------|-----|
| 1 | **High** | `main.gd` | `_intro_running` boolean race (double-spawn) | Replaced with `_intro_gen: int` generation counter — stale coroutines bail out via gen check |
| 2 | **High** | `ball.gd` | Brick collision fallthrough — bounce via paddle's else branch | Added explicit `velocity.bounce(normal)` + `_clamp_min_speed()` + `return` in brick branch |
| 3 | **High** | `main.gd` | `ROUND_CLEAR` phase set too late — life loss can slip through in same frame | Moved `phase = ROUND_CLEAR` to first line of `_resolve_round_clear()` before any `await` |
| 4 | **Medium** | `main.gd` | `SceneTreeTimer` ref cleared but timer still fires | Resolved by fix #1 — generation guard makes stale timer irrelevant |
| 5 | **Medium** | `main.gd` | Combo label `get_minimum_size()` reads stale value before layout flush | Removed manual positioning; set `anchor_left/right = 0.5`, `anchor_top/bottom = 0.3` for auto-centering |
| 6 | **Medium** | `main.gd` | `ScreenTransition._busy` silently swallows victory scene change | Added `_busy` check + `push_warning` before `change_scene()`; reset `_busy = false` in `_enter_game_over()` |
| 7 | **Low** | `paddle.gd` | Sticky ball auto-launches on timer expiry just after unpause | Added `_is_phase_playing()` check via parent call before launch |
| 8 | **Low** | `powerup.gd` | `rotation` on `Area2D` distorts `RectangleShape2D` collision | Rotate `$SymbolLabel` only instead of the `Area2D` |
| 9 | **Low** | `audio_manager.gd` | Per-call PCM synthesis causes frame hitches at high combo rates | Pre-baked 5-tone pool in `_ready()`; `play_brick_hit()` indexes into pool by pitch |

## Files Modified

- `main.gd` — fixes #1, #3, #5, #6
- `entities/ball.gd` — fix #2
- `entities/paddle.gd` — fix #7
- `entities/powerup.gd` — fix #8
- `autoload/audio_manager.gd` — fix #9

## Documents Updated

- `docs/Feedback 0613 1731.md` — reviewed and actioned
- `docs/readme.md` — restructured: session history extracted to `docs/history.md`, feature bullets condensed, structure/tests trees trimmed
- `docs/history.md` — new file with full session history (Sessions 7–15)
- `docs/agents.md` — deduplicated, session history references moved to `history.md`

---

## Suggestions for Next Session

**Polish & Hardening:**
- Visual: ball glow trail depth could be tuned for performance; brick destruction particle variety (different shapes per brick type)
- Audio: pre-bake remaining tones (paddle hit, launch sweep, etc.) into pool pattern; add volume control to HUD
- Sticky paddle: consider visual indicator for "about to expire" (sprite flash) matching timer-bar amber warning

**Gameplay Expansion:**
- New power-up: Shield (one free life loss absorbed per level), Fire Ball (passes through bricks, lower score)
- Level editor or seeded random generation for more variety in endless mode
- Boss mechanics: attack patterns, weak-point phases, bullet-hell elements

**Performance:**
- Replace per-instance `create_tween()` in frequently-called paths with shared tweens or manual lerp
- Pool `AudioStreamPlayer` nodes instead of creating + queue_free on every sound

**Cross-platform:**
- Gamepad/controller support (analog paddle movement)
- Resolution scaling / aspect-ratio handling for non-16:9 displays
- Touch controls refinement (swipe detection, dead zones)
