## Issue Plan Overview

The feedback covers **10 actionable issues** across 4 severity tiers. The document organizes them as numbered tasks with exact file paths, function names, before/after code diffs, and a verification step for each.

### Execution Order

| Order | Task | File | Severity |
|-------|------|------|----------|
| 1 | Add `laser_manager.deactivate()` as first line of `_load_level()` | `main.gd` | 🔴 Critical |
| 2 | Multiball race condition — add `_life_lost_pending` flag + `_process_life_loss()` | `main.gd` | 🔴 Critical |
| 3 | Strip `"LEVEL X — "` prefix from `_level_subtitle_text()` | `main.gd` | 🟠 Significant |
| 4 | Replace `Vector2.ZERO` sentinel with `_NO_POS` constant | `main.gd` | 🟠 Significant |
| 5 | Confirm `hud.clear_all_effect_timers()` called in `_load_level()` | `main.gd` | 🟠 Significant |
| 6 | 2-column layout for title screen power-up legend | `title_screen.gd` | 🟠 Significant |
| 7 | Connect `vfx.finished` → `vfx.queue_free` in `brick.destroy()` | `brick.gd` | 🟡 Gameplay |
| 8 | Replace `== 5` with `>= BASE_LEVEL_COUNT` constant | `main.gd` | 🟡 Robustness |
| 9 | Slow speed: `ball.speed * 0.6` vs `ball.base_speed * 0.6` | `main.gd` | 🟡 Design call |
| 10 | Re-anchor `HighScoreLabel` to right edge | `hud.tscn` | 🟢 Polish |

### Key Notes

- **Tasks 1 and 2 are the must-fix items** — both are reachable in normal play, the laser bug in particular requires only a single laser power-up pickup[1]
- **Task 7 (particle leak)** is silent during short sessions but compounds over a full 5-level run (~200 bricks)[1]
- **Task 9** is flagged as a design call — the instruction includes both paths with the recommended approach noted[1]
- Issues #8, #12, and #13 from the feedback are **confirmed non-issues** and require no code change, documented in the "Non-Action Items" table at the bottom of the file[1]

---

## Priority 1 — 🔴 Critical Bugs (Fix First)

### Task 1 — Laser deactivation on level load
**File:** `Breakout/main.gd`  
**Function:** `_load_level()`

Add `laser_manager.deactivate()` as the **first line** of the function body, before the existing `_slow_timer.stop()` call.

```gdscript
func _load_level() -> void:
    laser_manager.deactivate()   # ← ADD THIS LINE FIRST
    _slow_timer.stop()
    # ... rest of existing body unchanged ...
```

**Verification:** Start a run, collect Laser power-up on Level 1, clear all bricks, confirm laser beam stops firing during the Level 2 intro panel.

---

### Task 2 — Multiball life-loss race condition
**File:** `Breakout/main.gd`  
**Scope:** Class-level variable + `_on_ball_lost()` + new `_process_life_loss()`

#### Step 2a — Declare flag at class level
Add the following variable declaration alongside other class-level vars (e.g., near `_life_lost_this_frame` or lifecycle booleans):

```gdscript
var _life_lost_pending := false
```

#### Step 2b — Replace `_on_ball_lost()` body
Keep the existing function signature. Replace its **entire body** with:

```gdscript
func _on_ball_lost() -> void:
    if phase in [GameState.Phase.ROUND_CLEAR, GameState.Phase.LEVEL_INTRO,
                 GameState.Phase.GAME_OVER, GameState.Phase.VICTORY,
                 GameState.Phase.TITLE]:
        return
    if _has_active_ball():
        return
    if _life_lost_pending:
        return
    _life_lost_pending = true
    call_deferred("_process_life_loss")
```

> **Note:** Replace the existing phase list in the guard with whatever phases are currently listed — do not remove any existing phase guards, only add the `_life_lost_pending` guard.

#### Step 2c — Add `_process_life_loss()` function
Insert this new function directly after `_on_ball_lost()`:

```gdscript
func _process_life_loss() -> void:
    _life_lost_pending = false
    lives = max(0, lives - 1)
    hud.update_lives(lives)
    if lives <= 0:
        _enter_game_over()
        return
    _reset_round_after_life_loss()
```

#### Step 2d — Move life-decrement logic
Audit `_on_ball_lost()` for any existing `lives -= 1`, `hud.update_lives()`, `_enter_game_over()`, or `_reset_round_after_life_loss()` calls. **Remove them from `_on_ball_lost()`** — they are now exclusively in `_process_life_loss()`.

**Verification:** Enable Multiball, let 3 balls exit the bottom in the same frame. Confirm only one life is lost.

---

## Priority 2 — 🟠 Significant Issues

### Task 3 — Remove redundant level prefix from subtitle
**File:** `Breakout/main.gd`  
**Function:** `_level_subtitle_text()`

Replace the entire function body with:

```gdscript
func _level_subtitle_text() -> String:
    var config := LevelDefs.config_for_level(current_level)
    return str(config.get("intro_text", ""))
```

Do not touch `_level_title_text()`. The title still shows `"LEVEL X  ·  NAME"`. The subtitle now shows only the teaching text.

**Verification:** Load Level 1. The intro panel title reads `"LEVEL 1  ·  OPENING VOLLEY"`. The subtitle reads `"Learn the rebound angle and settle into the pace."` (no `"LEVEL 1  —  "` prefix).

---

### Task 4 — Replace `Vector2.ZERO` spawn sentinel
**File:** `Breakout/main.gd`  
**Function:** `_spawn_ball()`

#### Step 4a — Add sentinel constant at class level
Add near other constants at the top of the class:

```gdscript
const _NO_POS := Vector2(-99999.0, -99999.0)
```

#### Step 4b — Update function signature and guard
Change the default parameter and the guard condition:

```gdscript
# Before:
func _spawn_ball(at: Vector2 = Vector2.ZERO) -> Ball:
    if at == Vector2.ZERO:

# After:
func _spawn_ball(at: Vector2 = _NO_POS) -> Ball:
    if at == _NO_POS:
```

Everything else in the function body is **unchanged**.

**Verification:** Run the game. Ball spawns correctly above the paddle on level load and after life loss. No behavior change — this is a correctness/clarity fix.

---

### Task 5 — Fix power-up effect not fully cleared on level load (compound fix with Task 1)
**File:** `Breakout/main.gd`  
**Function:** `_load_level()`

After Task 1 is applied, `_load_level()` now begins with `laser_manager.deactivate()`. Confirm the function also calls `hud.clear_all_effect_timers()`. If it does not, add the call **after** `laser_manager.deactivate()` and **before** `_slow_timer.stop()`:

```gdscript
func _load_level() -> void:
    laser_manager.deactivate()           # Task 1
    hud.clear_all_effect_timers()        # ← ADD IF MISSING
    _slow_timer.stop()
    # ... rest unchanged ...
```

**Verification:** Collect Big Paddle (8 s) on Level 1. Clear all bricks before the timer expires. Confirm the Big Paddle HUD bar is gone and the paddle width is reset on Level 2 intro.

---

### Task 6 — Fix title screen power-up legend overflow
**File:** `Breakout/ui/title_screen.gd`  
**Location:** The line that assigns `powerup_legend.text`

#### Step 6a — Replace the join call
Find the line:

```gdscript
powerup_legend.text = "  ".join(lines)
```

Replace it with a two-column layout (3 entries per column):

```gdscript
var left := lines.slice(0, 3)
var right := lines.slice(3, 6)
var col_lines: Array[String] = []
for i in range(3):
    col_lines.append("%-28s%s" % [left[i], right[i] if i < right.size() else ""])
powerup_legend.text = "\n".join(col_lines)
```

> **Alternative (simpler):** If the `%-28s` format string causes issues with GDScript's `%` operator, use:
> ```gdscript
> var pairs: Array[String] = []
> for i in range(3):
>     var r := right[i] if i < right.size() else ""
>     pairs.append(left[i] + "    " + r)
> powerup_legend.text = "\n".join(pairs)
> ```

#### Step 6b — Confirm `autowrap_mode`
In `title_screen.tscn` (or set in `_ready()`), ensure `powerup_legend.autowrap_mode = TextServer.AUTOWRAP_OFF` now that newlines are explicit. If wrapping is left on, it will still work but may double-wrap on very narrow windows.

**Verification:** Run the title screen. The six power-up entries appear in two columns of three, none overflow the 600 px container.

---

## Priority 3 — 🟡 Gameplay / Robustness

### Task 7 — Particle VFX memory leak on brick destroy
**File:** `Breakout/entities/brick.gd`  
**Function:** `destroy()`

Find the block that duplicates and emits particles. Add **one line** — `vfx.finished.connect(vfx.queue_free)` — immediately after setting `vfx.one_shot = true`, before `get_tree().root.add_child(vfx)`:

```gdscript
var vfx := _particles.duplicate()
vfx.emitting = true
vfx.one_shot = true
vfx.finished.connect(vfx.queue_free)   # ← ADD THIS LINE
get_tree().root.add_child(vfx)
vfx.global_position = global_position
```

Do not change any other line in `destroy()`.

**Verification:** Play a full level, destroy all bricks. In the Godot **Remote Scene Tree** debugger, confirm no orphaned `GPUParticles2D` nodes accumulate under the root node after brick destruction.

---

### Task 8 — Victory condition: use constant instead of magic number
**File:** `Breakout/main.gd`  
**Function:** `_resolve_round_clear()`

#### Step 8a — Declare constant at class level
```gdscript
const BASE_LEVEL_COUNT := 5
```

#### Step 8b — Replace exact equality check
Find:
```gdscript
if current_level == 5:
```
Replace with:
```gdscript
if current_level >= BASE_LEVEL_COUNT:
```

Do not change anything else in the conditional block.

**Verification:** Clear Level 5 normally — victory screen appears. Confirm endless mode still activates after victory.

---

### Task 9 — Slow ball speed: apply to level-scaled speed (design decision)
**File:** `Breakout/main.gd`  
**Function:** `_spawn_ball()`

This is a **design call**: the current code applies slow at `base_speed * 0.6`, meaning 60% of base regardless of level. The alternative is 60% of the current level speed.

**Recommended change (60% of current level speed):**

Find the block inside `_spawn_ball()` that checks `_slow_timer.is_stopped()`:

```gdscript
# Before:
if not _slow_timer.is_stopped():
    _original_ball_speeds[ball.get_instance_id()] = ball.speed
    ball.speed = ball.base_speed * 0.6

# After:
if not _slow_timer.is_stopped():
    _original_ball_speeds[ball.get_instance_id()] = ball.speed
    ball.speed = ball.speed * 0.6   # 60% of already-leveled speed
```

> **If the original feel is preferred** (60% of base speed across all levels), skip this task. Document the decision in a code comment:
> ```gdscript
> ball.speed = ball.base_speed * 0.6  # Intentional: slow always means 60% of base, not level speed
> ```

---

## Priority 4 — 🟢 Aesthetic Polish

### Task 10 — HUD HighScoreLabel positioning
**File:** `Breakout/ui/hud.tscn`  
**Node:** `HighScoreLabel`

Change the node's anchor and offset properties so it aligns to the right edge of the HUD, consistent with `LivesContainer`:

```
# Before:
offset_left = 720.0
offset_right = 920.0
# (no anchor set — defaults to top-left anchor)

# After:
anchor_left = 1.0
anchor_right = 1.0
offset_left = -220.0
offset_right = -20.0
offset_top = 8.0
offset_bottom = 40.0
```

This places the 200 px label 20 px from the right edge, above the `EffectList` and to the right of `LevelLabel`.

> **If editing `.tscn` directly** is preferred over the Godot editor, change the node section for `HighScoreLabel` to:
> ```
> [node name="HighScoreLabel" type="Label" parent="."]
> anchor_left = 1.0
> anchor_right = 1.0
> offset_left = -220.0
> offset_top = 8.0
> offset_right = -20.0
> offset_bottom = 40.0
> theme_override_colors/font_color = Color(1.0, 0.2, 0.8, 1.0)
> theme_override_font_sizes/font_size = 16
> horizontal_alignment = 2
> text = " "
> ```

**Verification:** Run the game. `HIGH: 99999` is fully visible in the top-right area, not overlapping `LevelLabel` or `LivesContainer`.

---

## Non-Action Items (Confirmed Correct / Low Risk)

The following issues from the feedback file were reviewed and require **no code changes**:

| # | Issue | Status |
|---|-------|--------|
| 7 | Wall positions fixed at 1280×720 — misaligns on dynamic resize | No-fix: game targets fixed 1280×720. Add `# NOTE: walls baked at 1280×720; dynamic resize not supported` comment in `main.tscn` or `_ready()` if desired. |
| 8 | Sticky paddle aim lines — minor UX jitter after ball launch | Confirmed non-issue: `show_aim` is already set false in `_launch_waiting_ball()`. No change needed. |
| 12 | Boss tween not killed on `destroy()` | Confirmed non-issue: Godot 4 `create_tween()` tweens are tied to the node's lifetime and auto-stop on `queue_free()`. No change needed. |
| 13 | `to_upper()` mangles accented characters | Acceptable for current ASCII level names. No change unless non-ASCII names are added. |

---

## Implementation Order Summary

| Order | Task | File | Severity |
|-------|------|------|----------|
| 1 | Laser deactivation on `_load_level()` | `main.gd` | 🔴 Critical |
| 2 | Multiball race condition guard | `main.gd` | 🔴 Critical |
| 3 | Remove subtitle level prefix | `main.gd` | 🟠 Significant |
| 4 | Replace `Vector2.ZERO` spawn sentinel | `main.gd` | 🟠 Significant |
| 5 | Confirm HUD timers cleared on level load | `main.gd` | 🟠 Significant |
| 6 | Title screen legend 2-column layout | `title_screen.gd` | 🟠 Significant |
| 7 | Brick particle `queue_free` on finish | `brick.gd` | 🟡 Gameplay |
| 8 | Victory condition constant | `main.gd` | 🟡 Robustness |
| 9 | Slow speed relative to level speed | `main.gd` | 🟡 Design call |
| 10 | HUD HighScoreLabel anchor fix | `hud.tscn` | 🟢 Polish |
