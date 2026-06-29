# AI Agent Workflow Documentation

This file documents how to work with AI assistants on this Breakout project.

---

## Running the Project

1. **Open in Godot**: Open `project.godot` in **Godot 4.x**
2. **Run**: Press **F5** or click **Run** to start
3. **Run specific scene**: Right-click a `.tscn` file → **Run This Scene**

---

## Project Structure

```
res://
├── main.gd                     # Run conductor (session/level/round flow split)
├── game/
│   ├── game_state.gd          # Phase enum (TITLE, LEVEL_INTRO, READY, PLAYING, etc.)
│   ├── level_defs.gd          # Level configs with authored identities + weighted drops
│   ├── level_builder.gd       # Brick geometry and spawning
│   └── powerup_registry.gd    # Central power-up metadata (icons, colors, durations)
├── autoload/
│   ├── audio_manager.gd       # Synthesized sound effects (8 tones)
│   ├── game_theme.gd          # Color constants (NEON_CYAN, NEON_MAGENTA, etc.)
│   ├── run_state.gd           # Transient: start_level, last_score
│   ├── save_data.gd           # Persistence: get_high_score(), save_high_score()
│   └── screen_transition.gd  # Scene fade transitions (deadlock guard)
├── entities/
│   ├── paddle.gd              # Movement, sticky, width effects, wall bounds, edge warnings
│   ├── ball.gd                # Physics (substep), launch, aim, collision, stuck escape
│   ├── brick.gd               # HP, damage, destruction, row_color, shader caching, damage feedback
│   ├── powerup.gd             # Collection (reads metadata from PowerUpRegistry), falling animation
│   ├── playfield_border.gd    # Resize-safe border with glow + corner accents
│   ├── laser_manager.gd       # Auto-fire logic (phase-aware callback)
│   ├── laser_beam.gd          # Projectile behavior
│   └── ring_effect.gd         # Expanding arc ring flash effect
└── ui/
    ├── title_screen.gd        # Opening title card (high score, controls, HBox legend)
    ├── hud.gd                  # Score, lives, multi-effect timer strip, level intro, pause text
    └── victory.gd             # Win screen → endless entry
```

---

## Code Conventions

### GDScript Style

- **Files**: `snake_case.gd`
- **Classes**: `PascalCase` (via `class_name`)
- **Methods/Functions**: `snake_case()`
- **Variables**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Enums**: `PascalCase` for enum name, `UPPER_SNAKE` for members

### Example

```gdscript
class_name Ball
extends CharacterBody2D

const MAX_SPEED := 500.0

var launched := false
var paddle: Paddle

func launch(toward: Vector2 = Vector2.UP) -> void:
    if launched:
        return
    launched = true
    velocity = toward * speed
```

---

## Key Design Patterns

### State Management

- Use `GameState.Phase` enum (not HUD visibility) to drive game logic
- `main.gd` owns phase transitions; UI only renders state
- Phases: `TITLE` → `LEVEL_INTRO` → `READY` → `PLAYING` → `ROUND_CLEAR`, with `PAUSED`, `GAME_OVER`, `VICTORY` branching off

### Component Communication

- **Signals**: `life_lost`, `brick_hit(points)`, `destroyed(pos, drop_chance, point_value)`, `collected(type, duration)`
- **Direct injection**: `ball.set_paddle(paddle)`, `laser_manager.set_paddle(paddle)`, `paddle.set_sticky_release_callback(cb)`
- **Callable callbacks**: Use `Callable` members + setters for behavior injection (e.g., phase checks, release callbacks)
- **Avoid**: `get_parent()`, `has_method()`/`call()` introspection, groups for core gameplay

### Timer Management

- Create timers once in `_ready()`, restart them on refresh
- Avoid lazy creation + nulling pattern

### Autoloads

| Autoload | Purpose |
|----------|---------|
| `AudioManager` | Synthesized sound effects (8 tones, play-and-forget) |
| `GameTheme` | Color constants only (no logic) |
| `RunState` | Transient session: `start_level`, `last_score` |
| `SaveData` | Persistence: `get_high_score()`, `save_high_score()` |
| `ScreenTransition` | Scene fade in/out transitions (deadlock-guarded) |

---

## Common Tasks

### Ball Attach Positioning

- Ball attach height is derived from `paddle.get_ball_attach_offset()` (`24.0 + (target_width - 100.0) * 0.05`)
- Never use hard-coded `Vector2(0, -30)` — always call the helper so big-paddle mode seats the ball correctly
- The helper is used in: `paddle.gd` (stick_ball, _disable_sticky, _physics_process stuck tracking), `ball.gd` (attach_to_paddle), `main.gd` (_spawn_ball)

### Adding a New Entity

1. Create `entities/entity_name.tscn` (root node)
2. Create `entities/entity_name.gd` (script)
3. Add to appropriate collision layer in scene
4. Add `class_name EntityName` in script

### Adding a Power-up

1. Add type to `PowerUp.Type` enum in `powerup.gd`
2. Add case in `_on_powerup_collected()` in `main.gd`
3. Add metadata entry in `PowerUpRegistry.DEFS` (icon, color, duration, HUD label, default_weight)
4. Add drop weights for relevant levels in `level_defs.gd::base_levels()`

### Modifying Levels

- Edit level configs in `game/level_defs.gd::base_levels()`
- Endless mode generated in `game/level_defs.gd::config_for_level()`

---

## Testing Checklist

When making changes, verify:
- [ ] Game launches to title screen (not straight to gameplay)
- [ ] Title screen shows high score, controls, power-up legend (HBox grid, no misalignment)
- [ ] Paddle spawns at bottom-center, respects wall boundaries
- [ ] Ball launches, bounces correctly, doesn't tunnel through bricks
- [ ] Brick destruction triggers score + combo + damage flash/scale feedback
- [ ] Multi-HP bricks (metal/boss) show HP label + damage particles on hit
- [ ] Power-up collection applies effect with concurrent timer (multiple effects can display)
- [ ] Slow power-up: tint overlay appears, ball speed visibly reduced; expires cleanly
- [ ] Audio plays for: brick hit, paddle hit, launch, power-up, life loss, level clear, game over
- [ ] Level intro shows authored stage name + subtitle
- [ ] Level transition clears old entities and timers; intro timer doesn't leak
- [ ] Endless mode continues past level 5
- [ ] Game over: shows score, high score, NEW HIGH SCORE flag; 1s restart delay
- [ ] Pause shows score + level info; unpause restores correct phase
- [ ] Victory screen → endless mode works; confetti stops on exit
- [ ] Screen shake stacks correctly (no position jump after multi-destroy)
- [ ] Combo label centered, font scales with count, bounce-in animation
- [ ] M key toggles audio mute
- [ ] Score popup floats up from destroyed bricks
- [ ] Power-up pickup shows scale-up + fade animation
- [ ] Mouse/touch drag moves the paddle
- [ ] Big Paddle tints paddle green, reverts to cyan on expiry
- [ ] Run scene "Run This Scene" on `main.tscn` does **not** flash black
- [ ] Clear level 5 with 1 ball — no score corruption on victory
- [ ] Trigger multiball, destroy 4+ bricks in same frame — multiple drops spawn (per-frame cap, max 2)
- [ ] Activate laser + ball hit same brick in same frame — single score event
- [ ] Pause during sticky mode — sticky/big-paddle timers don't drain
- [ ] Boss brick 5+ rapid hits — no wrong-shade flicker
- [ ] Activate sticky, release ball — paddle still shows pulsing border between catches
- [ ] Wall geometry change in `main.tscn` — paddle still clamps correctly
- [ ] Endless Mode: brick hits accumulate score (not broken by null combo_timer)
- [ ] Endless Mode: Laser power-up fires beams (paddle ref set correctly)
- [ ] Endless Mode: Slow Balls timer expires and restores speed (slow_timer created)
- [ ] Combo label centered on screen (not offset, not jittering with camera shake)
- [ ] Score popup doesn't jump/misalign during simultaneous camera shake
- [ ] Power-up icon (Sprite box + symbol) rotates together, not just glyph
- [ ] Title screen BREAKOUT label cycles cyan→lime→magenta→yellow, no layout shift
- [ ] Start game from title: shimmer tween killed, no color flash on main scene load
- [ ] Sticky timer expires while paused: ball auto-launches on unpause, not stuck
- [ ] Ball wedged in corner: escapes in previous travel direction, not random
- [ ] Moving paddle right before sticky catch: aim lines stay tilted right after catch
- [ ] Collect Multiball: all clone balls show tinted halos (not near-invisible white)
- [ ] Collect Slow Balls: purple screen wash visible on dark background, clears on expiry
- [ ] Launch sound: short, punchy chirp with harmonic texture (not flat sine sweep)

---

## AI Assistant Instructions

When working on this codebase:

1. **Read first**: Use `read` tool to understand existing code before editing
2. **Follow conventions**: Match existing code style (snake_case, etc.)
3. **Test changes**: Run the project to verify fixes work
4. **One concern per file**: Avoid mixing unrelated changes
5. **One-time setup pattern**: `_run_setup()` for signal wiring, timer creation, wall bounds — must always run before any `_start_new_run()` call
6. **Tween lifecycle**: Store Tweens in member variables (e.g., `_shake_tween`, `_combo_tween`, `_score_tween`); `.kill()` before creating new ones targeting the same properties to prevent racing Tweens
7. **Callback injection**: Use `Callable` injection (e.g., `paddle.set_sticky_release_callback()`) instead of `get_parent()` / `has_method()` / `call()` introspection
8. **Unified hit contract**: `Brick.take_damage()` returns `{destroyed, awarded_points, score_points, remaining_hp, was_already_scored}` — all damage sources must consume this dictionary, never invent their own scoring rules
9. **Laser manager setup**: `_setup_laser_manager()` centralizes paddle binding + phase gate; call it from all lifecycle entry points, not just `_run_setup()`
10. **Deferred launch pattern**: When a `_disable_sticky`, `_process` or other callback needs to launch a ball but the tree is paused, store a `_deferred_launch: bool` flag and check it in `_process()` (not `_physics_process`, which returns early when paused). Fire the actual launch on the first unpaused tick.
11. **Document retro**: After each session, summarize in `docs/retro_MMDD.md`

### Useful Commands

```bash
glob "**/*.gd"                    # Find files by pattern
grep "pattern" --include="*.gd"  # Search code
godot --path . --script res://scripts/test_runner.gd  # Run tests
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Input not firing | Ensure callback is `_unhandled_input(event)` not `inputevent` |
| Object reference null | Use `is_instance_valid()` before accessing |
| Timer leaks | Create once in `_ready()`, restart on refresh |
| Collision issues | Verify collision layers in `project.godot` |

---

*Session history at [docs/history.md](history.md). Per-session detail in `docs/retro_MMDD.md`.*
