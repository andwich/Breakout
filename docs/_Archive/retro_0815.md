# Session 29 (2026-08-15) — Retheme: Calm Dashboard → Neon Arcade

## Overview

Reverted the visual aesthetic from the "calm dashboard" palette (Session 28) back to a **neon arcade** style per `docs/Feedback 0815 1700.md`. Changes are purely visual/layout — no physics, scoring, collision, or power-up contract modifications.

## Changes

### Diff 1: Theme Tokens (Direct Edit)
- **`autoload/game_theme.gd`** — Replaced workspace-oriented soft palette with arcade-neon:
  - `BACKGROUND` = `#03050B` (near-black), `SURFACE` = `#070B14`, `SURFACE_ELEVATED` = `#0A1020`
  - `BORDER_SUBTLE` = `#00C9E8` at 0.38 alpha, `BORDER_STRONG` = `#00E5FF` at 0.85 alpha
  - `ACCENT` = `#00E5FF` (cyan — score, normal paddle, standard bricks)
  - `SUCCESS` = `#00F07A` (green — GO!, wide paddle, green bricks)
  - `WARNING` = `#FFD400` (yellow — level label, transitions, yellow bricks)
  - `DANGER` = `#FF167F` (magenta/pink — lives, hazards, boss bricks)
  - `INFO` = `#189CFF` (blue — utility indicators, blue bricks)
  - `BRICK_STANDARD` = `ACCENT` (cyan, not gray-blue)
  - `BRICK_DURABLE` = `#FF7A00` (orange)
  - `BRICK_BOSS` = `#FF167F` (pink)
  - `BALL` = `#FFFFFF` (white)
  - `PADDLE_STICKY` = `WARNING` (yellow), `PADDLE_WIDE` = `SUCCESS` (green)
  - Added `HUD_FONT_SIZE := 22`, `CALLOUT_FONT_SIZE := 76`, `PANEL_RADIUS := 0`, `PANEL_MARGIN := Vector2i(18, 12)`
  - Temporary `NEON_*` aliases retained for backward compat

### Diff 2: Authored Layouts (Direct Edit)
- **`game/level_defs.gd`** — Added `layout` string masks to levels 1 and 2:
  - Level 1 ("Opening Volley"): expanded from 8×4 to 10×4 full grid
  - Level 2 ("Controlled Angles"): 5-row split formation — left cluster on rows 1–5, right column on row 1 only, open center
  - Intro text for levels 1–2 cleared (author-driven visuals replace teaching text in intro)
- **`game/level_builder.gd`** — Mask-aware brick spawning:
  - `build_level()` now reads `config.get("layout", [])` and skips empty cells via `_cell_is_filled()`
  - `_cell_is_filled()` returns `true` when no layout mask is present (backward compat for levels 3–5 and endless)
  - Brick HP, points, drop chance, color, metal/boss selection remain in `_configure_brick()` (layout only controls existence)

### Diff 3: Arcade Brick Bands (Direct Edit)
- **`game/level_builder.gd`** — `ROW_COLORS` replaced with 8-color neon gradient:
  - Cyan → Blue → Green → Bright Green → Orange → Red-Orange → Pink → Purple
  - Replaces the previous red→magenta generalized row spectrum

### Diff 4: HUD and Callouts (Direct Edit)
- **`ui/hud.tscn`** — Full layout refresh:
  - `ScoreLabel`: left=72px, cyan `#00E5FF`, size 22
  - `LevelLabel`: center-anchored, yellow `#FFD400`, size 22
  - `LivesContainer`: right-anchored with `-180` to `-72` bounds, hearts magenta `#FF167F`
  - `HighScoreLabel`: muted gray `#7F91AD`, size 16
  - `TopDivider`: new `ColorRect` at y=51–53, cyan at 0.55 alpha
  - `LevelCompleteLabel`: yellow `#FFD400`, size 76, center-anchored
  - `LevelIntroTitle`: green `#00F07A`, size 52
  - `LevelIntroSubtitle`: yellow at 0.9 alpha, size 18
  - `PauseLabel`: green `#00F07A`, size 32
  - `GameOverLabel`: magenta `#FF167F`, size 32
- **`ui/hud.gd`** — Script-level changes:
  - Removed `StyleBoxFlat` rounded card styling from intro panel; replaced with `StyleBoxEmpty.new()`
  - `show_level_intro()`: always displays "GO!" in `GameTheme.SUCCESS` with scale bounce-in (TRANS_BACK + EASE_OUT); subtitle hidden
  - `show_level_complete()`: text changed to "LEVEL COMPLETED!", uses `GameTheme.WARNING` color

### Diff 5: Paddle and Ball Glow (Direct Edit)
- **`entities/paddle.tscn`** — Added `Glow` ColorRect behind sprite:
  - `mouse_filter = 2` (ignore), `show_behind_parent = true`
  - Offset: `[-58, -13]` to `[58, 13]`, color `Color(0.0, 0.9, 1.0, 0.18)` (cyan halo)
- **`entities/ball.tscn`** — Added `Glow` ColorRect behind visible core:
  - `mouse_filter = 2` (ignore), `show_behind_parent = true`
  - Offset: `[-11, -11]` to `[11, 11]`, color `Color(1.0, 1.0, 1.0, 0.22)` (white halo)

### Additional: Font and Background Sweep (Direct Edit)
- **`project.godot`** — Added `[font]` section: `default_font="res://assets/fonts/Mono-Bold.tres"`, `default_font_size=22`
- **`main.tscn`** — `BackgroundOverlay` color changed from hardcoded `Color(0.08, 0.05, 0.15, 1.0)` to `Color(GameTheme.BACKGROUND)`
- **`main.gd`** — Combo label font color changed from hardcoded yellow to `GameTheme.WARNING`

## Validation

- Godot v4.7.1 headless editor load/quit — **PASS** (zero parse errors)
- All changes are non-mechanical (palette, layout, scene structure only)
- Physics, scoring, collision layers, power-up contracts, and laser manager untouched

## Not Done (Deferred per Feedback Doc)

- Downward pink hazards / `HazardManager` — explicitly deferred until neon slice is stable
- Title screen / Victory screen palette sweeps — not in this vertical slice
- Campaign reduction from 5 → 4 levels — explicitly deferred (product decision)
- New power-up kinds — explicitly deferred

## Acceptance Criteria (Pre-Playtest)

1. Level 1 renders 4 full rows (cyan/blue/green/bright green) with centered green "GO!"
2. Level 2 produces split formation with empty center cells
3. Level complete shows yellow "LEVEL COMPLETED!" with no panel background
4. Paddle colors: normal=cyan, wide=green, sticky=yellow
5. HUD: score=cyan, level=yellow, lives=magenta

## Playtest Required

- [ ] Level 1: 4-row cyan/blue/green bands, green GO! callout
- [ ] Level 2: split mask, no premature round clear
- [ ] Level clear: yellow "LEVEL COMPLETED!", no panel bg, no stuck transition
- [ ] Power-up colors: sticky→yellow, wide→green, normal→cyan
- [ ] Multiball, metal bricks, game over, level 5, endless mode
- [ ] HUD readability: score/level/lives color contrast against near-black background
- [ ] Ball glow halo visible but not overwhelming
- [ ] Paddle glow halo visible but not overwhelming
