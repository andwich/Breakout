# AI Agent Workflow

How to work with AI assistants on this Breakout project.

---

## Running the Project

1. Open `project.godot` in **Godot 4.x**
2. Press **F5** or click **Run**
3. Or right-click a `.tscn` → **Run This Scene**

---

## Project Structure

```
res://
├── main.tscn/.gd          # Run conductor (session/level/round flow)
├── game/
│   ├── game_state.gd      # Phase enum (TITLE → LEVEL_INTRO → READY → PLAYING → ROUND_CLEAR)
│   ├── level_defs.gd      # Level configs: authored identities + weighted drop tables
│   ├── level_builder.gd   # Brick geometry and spawning
│   └── powerup_registry.gd # Central power-up metadata (icons, colors, durations, weights)
├── autoload/
│   ├── audio_manager.gd   # Synthesized sound effects (8 tones, play-and-forget)
│   ├── game_theme.gd      # Semantic color constants (ACCENT, SUCCESS, INFO, WARNING, DANGER, etc.)
│   ├── run_state.gd       # Transient: start_level, last_score
│   ├── save_data.gd       # Persistence: get_high_score(), save_high_score()
│   └── screen_transition.gd # Scene fade transitions (deadlock guard, public API)
├── entities/
│   ├── paddle.gd          # Movement, sticky, width effects, wall bounds, edge warnings
│   ├── ball.gd            # Physics (substep anti-tunneling), launch, aim, collision, stuck escape
│   ├── brick.gd           # HP, damage, destruction, row_color, shader caching, damage feedback
│   ├── powerup.gd         # Collection, falling animation (reads PowerUpRegistry)
│   ├── playfield_border.gd # Resize-safe border with glow + corner accents
│   ├── laser_manager.gd   # Auto-fire logic (phase-aware callback)
│   ├── laser_beam.gd      # Projectile behavior
│   └── ring_effect.gd     # Expanding arc ring flash effect
└── ui/
    ├── title_screen.gd    # Title card (high score, controls, HBox legend)
    ├── hud.gd             # Score, lives, multi-effect timer strip, level intro, pause text
    └── victory.gd         # Win screen → endless entry
```

---

## Code Conventions

- **Files**: `snake_case.gd`
- **Classes**: `PascalCase` (via `class_name`)
- **Methods/Functions**: `snake_case()`
- **Variables**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Enums**: `PascalCase` name, `UPPER_SNAKE` members

---

## Key Design Patterns

### State Management

- `GameState.Phase` enum drives logic — never HUD visibility
- `main.gd` owns transitions; UI only renders
- Phases: `TITLE` → `LEVEL_INTRO` → `READY` → `PLAYING` → `ROUND_CLEAR`; `PAUSED`, `GAME_OVER`, `VICTORY` branch off

### Component Communication

- **Signals**: `life_lost`, `brick_hit(points)`, `destroyed(pos, drop_chance, point_value)`, `collected(type, duration)`
- **Direct injection**: `ball.set_paddle()`, `laser_manager.set_paddle()`, `paddle.set_sticky_release_callback(cb)`
- **Callable callbacks**: Injectable behavior (phase checks, release callbacks)
- **Avoid**: `get_parent()`, `has_method()`/`call()`, groups for core gameplay

### Autoloads

| Autoload | Purpose |
|----------|---------|
| `AudioManager` | Synthesized sound effects (8 tones, pentatonic/musical scales) |
| `GameTheme` | Neon arcade palette (ACCENT=cyan, SUCCESS=green, WARNING=yellow, DANGER=magenta, BACKGROUND=near-black) |
| `RunState` | Transient session state |
| `SaveData` | High score persistence |
| `ScreenTransition` | Scene fades (`is_busy()`, `force_reset()` public API) |

---

## Common Tasks

### Ball Attach Position

- Use `paddle.get_ball_attach_offset()` (`24.0 + (target_width - 100.0) * 0.05`)
- Never hard-code `Vector2(0, -30)` — big-paddle mode needs the helper
- Used in: `paddle.gd`, `ball.gd`, `main.gd`

### Adding an Entity

1. Create `entities/name.tscn` + `entities/name.gd`
2. Add to appropriate collision layer
3. Add `class_name Name`

### Adding a Power-up

1. Add type to `PowerUp.Type` enum in `powerup.gd`
2. Add case in `_on_powerup_collected()` in `main.gd`
3. Add metadata in `PowerUpRegistry.DEFS`
4. Add drop weights in `level_defs.gd::base_levels()`

### Modifying Levels

- Edit `game/level_defs.gd::base_levels()` — optional `layout` string mask (`#`=brick, `.`=hole) per level
- Endless mode: `game/level_defs.gd::config_for_level()` — no layout mask (full rectangular grid)
- `level_builder.gd::_cell_is_filled()` returns `true` when `layout` is empty (backward compat)

---

## Critical Rules

1. **Read first** — understand existing code before editing
2. **One concern per file** — no mixing unrelated changes
3. **Tween lifecycle** — store in member vars, `.kill()` before recreating on same properties
4. **Callback injection** — use `Callable` injection, not `get_parent()`/`has_method()`/`call()`
5. **Unified hit contract** — `Brick.take_damage()` returns `{destroyed, awarded_points, score_points, remaining_hp, was_already_scored}`; all damage sources consume this dict
6. **Laser manager** — `_bind_laser_manager()` is idempotent; call from all lifecycle entry points
7. **Deferred launch** — when paused tree needs ball launch, use `_deferred_launch` flag + `_process()`
8. **ScreenTransition** — never write `_busy`; use `is_busy()` / `force_reset()`
9. **Sticky return** — `stick_ball()` returns `bool`; callers must check
10. **Restart cleanup** — `_start_new_run()` resets combo/shake state; do not add state without resetting it
11. **Document retro** — summarize each session in `docs/retro_MMDD.md`
12. **Paddle visual state** — never write `sprite.color` directly in power-up methods; call `refresh_visual_state()` (Sticky → yellow, Big Paddle → lime, else cyan)
13. **Ball containment** — treat any screen exit as a loss; keep the idempotent `_on_screen_exited()` guard and the bounds fallback in `_physics_process()`
14. **Launch input suppression** — `suppress_launch_until_release` is only set on title-screen transition; normal READY states accept the next press immediately
15. **Ball adaptive substeps** — up to `MAX_PHYSICS_STEPS` (96) per tick; residual move for severe frame hitches; never discard travel
16. **Rebound minimum upward** — paddle rebound enforces `Ball.MIN_UPWARD_COMPONENT = 0.42` to prevent shallow wall-rally loops; max horizontal deflection is full `hit_ratio` (~45° at the edges)
17. **Durable brick scoring** — non-lethal hits return `score_points = 0`; only destruction awards points; combo/score skipped for `points <= 0`
18. **Sticky context prompt** — emit `sticky_ball_caught` / `sticky_ball_released` signals; `main.gd` owns HUD text via `show_context_prompt()` / `hide_context_prompt()`
19. **Power-up round-clear grace** — `_on_powerup_collected()` accepts `ROUND_CLEAR` phase so in-flight power-ups resolve their effects
20. **Visual hierarchy** — standard bricks idle on muted `ROW_COLORS` bands (row_color blended 50% toward TEXT_MUTED, then darkened 12%); hit flashes lighten the brick's own hue (`base_color.lightened(0.75)`), never pure white; slow overlay alpha = 0.10
21. **Typed arrays** — all indexed collections must use `Array[float]` (or appropriate type); never rely on `:=` inference from untyped `Array` index
22. **Master bus guard** — use `AudioManager._master_bus_index()` with `if idx >= 0` before audio bus operations; never call `AudioServer.get_bus_index()` inline without checking
23. **AudioStreamPlayer pool** — reuse the 12-player pool via `_play_stream()`; never create `AudioStreamPlayer.new()` per effect
24. **ScreenTransition fade tween** — store in `_fade_tween` member; use `_replace_fade_tween()` in `fade_in()`/`fade_out()`; `force_reset()` kills it
25. **Teardown validity** — use `is_instance_valid()` before accessing stored node references (`paddle`, etc.) in `attach_to_paddle()` and similar teardown paths
26. **_exit_tree cleanup** — destroyable nodes (`Ball`, `Brick`) must kill owned tweens in `_exit_tree()` to prevent orphaned effects after `queue_free()`
27. **Overlay tween ownership** — `main.gd` flash/slow overlay tweens stored as `_flash_tween`/`_slow_tween` members; killed before recreate; reset in `_start_new_run()`
28. **Headless validation gate** — after every GDScript edit, run `godot --headless --path . --editor --quit` and fix all parse errors before reporting completion
29. **Explicit scene preloads** — declare scene constants as `const X: PackedScene = preload(...)`; never rely on `:=` inference for preloads (a missing or corrupt scene produces a cascade of inference errors). Keep `.tscn` section order canonical: all `[sub_resource]` blocks must precede all `[node]` blocks

---

## Code Change Validation Workflow

Every GDScript change must follow this sequence before the task is considered complete:

### 1. Edit
Make the requested code changes.

### 2. Headless Validation
Run the Godot editor in headless mode to parse all scripts:

```bash
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /path/to/Breakout --editor --quit
```

### 3. Fix All Parser Errors
Read every `SCRIPT ERROR: Parse Error` from the output. Common issues:
- **Type inference failures** — use explicit type annotations (`Array[float]`, `Variant`, etc.) instead of `:=` when the inferred type is ambiguous
- **Typed array mismatches** — ensure methods return properly constructed typed arrays, not raw `Array` from `Dictionary.keys()`
- **Null in ternary** — ternaries containing `null` cannot be inferred; annotate as `Variant`

Fix all errors, then re-run validation.

### 4. Repeat Until Clean
Re-run headless validation after each fix batch. Do not stop until the output is free of parse errors.

### 5. Report
Summarize the validation command used, its exit status, and confirm zero parse errors.

**Never claim a task is complete while Godot reports any script parse errors.**

---

## Testing Checklist

When making changes, verify:

### Core Flow
- [ ] Game launches to title screen
- [ ] Title screen: high score, controls, power-up legend
- [ ] Paddle spawns bottom-center, respects wall bounds
- [ ] Ball launches, bounces, doesn't tunnel through bricks
- [ ] Brick destruction: score + combo + damage flash/scale
- [ ] Multi-HP bricks: HP label + damage particles
- [ ] Power-up collection with concurrent timer display
- [ ] Audio: brick hit, paddle hit, launch, power-up, life loss, level clear, game over
- [ ] Level intro shows stage name + subtitle
- [ ] Level transition clears old entities/timers

### Edge Cases
- [ ] Endless mode continues past level 5
- [ ] Game over: score, high score, NEW HIGH SCORE flag, 1s restart delay
- [ ] Pause: score + level info; unpause restores correct phase
- [ ] Victory → endless mode; confetti stops on exit
- [ ] Screen shake stacks correctly
- [ ] Multiball + Sticky: first ball sticks, second bounces
- [ ] Sticky timer expires while paused: auto-launch on unpause
- [ ] Ball wedged in corner: escapes upward, preserving previous horizontal direction
- [ ] Keyboard released with cursor off-center: paddle stops; resumes tracking on mouse move
- [ ] Multiball collected at cap: +50 bonus popup, no clone spawned
- [ ] Laser + ball hit same brick same frame: single score event
- [ ] Launch from title: READY does not launch until the click/Space is released and pressed again
- [ ] Big Paddle + Sticky: yellow while sticky; lime on sticky expiry while Big Paddle still active
- [ ] Sticky catch shows aim guide; guide clears on release (expiry + deferred paths)
- [ ] Ball forced beyond left/right/top/bottom bounds: exactly one loss, ball removed
- [ ] Launch suppression clears after title click releases during LEVEL_INTRO; next READY press launches once
- [ ] Rapid pop_visual() calls do not stack tweens; ball always returns to Vector2.ONE
- [ ] Laser + multiball produces capped cosmetic feedback (max 2 score popups, 2 shakes per frame) but unchanged score and drops
- [ ] Durable brick damage visibly changes persistent state on non-lethal hits; flash tween returns to post-damage base color
- [ ] Sticky prompt reads "AIM • RELEASE TO FIRE" and clears on every release/expiry path
- [ ] Brick-hit audio does not overlap into harsh click bursts during rapid destruction
- [ ] Edge paddle hits exit visibly steeper than center hits (~45° max)
- [ ] Brick damage flash tints toward the brick's own hue, never pure white

### Visual Polish
- [ ] Combo label centered, font scales, bounce-in
- [ ] Score popup floats from destroyed bricks
- [ ] Power-up pickup scale-up + fade
- [ ] Big Paddle green tint, reverts on expiry
- [ ] Title screen breathing pulse (single-color alpha modulation), no layout shift
- [ ] Sticky pulsing border between catches
- [ ] Power-up icon rotates together
- [ ] Launch sound: punchy chirp, not flat sine sweep

---

*Session history: [docs/history.md](history.md). Per-session detail: `docs/retro_MMDD.md`.*
