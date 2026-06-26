# Breakout

A modern Breakout-style arcade game built with Godot 4.x, featuring neon visuals, 6 power-ups, 5 progressive levels, and endless mode.

## Controls

| Input | Action |
|-------|--------|
| **A / D** or **← / →** | Move paddle |
| **Space** or **Click** | Launch ball / Start game / Restart |
| **Escape** | Pause / Unpause |

## Features

- **6 Power-ups**: Multiball, Big Paddle, Sticky Paddle, Laser, Slow Balls, Extra Life
- **5 Hand-crafted Levels** → Endless mode with scaling difficulty
- **Brick Types**: Standard (1 HP), Metal (3 HP), Boss (5 HP, pulsing)
- **High Score** persistence via local save file

## Project Structure

```
autoload/
  game_theme.gd     # Neon color palette (registered as GameTheme)
  run_state.gd      # Transient session (start_level, last_score)
  save_data.gd      # High-score persistence

game/
  game_state.gd     # GameState.Phase enum
  level_defs.gd    # Static level configs + endless waves
  level_builder.gd  # Brick layout & geometry

entities/
  ball.gd          # Ball movement, collision, launch
  paddle.gd        # Paddle movement, sticky, effects
  brick.gd        # Brick HP, destruction, particles
  powerup.gd       # Power-up collection
  laser_manager.gd  # Laser auto-fire
  laser_beam.gd    # Laser ray collision

ui/
  hud.gd           # Score, lives, level, state display
  victory.gd       # Endless-mode entry

main.gd             # Game flow orchestration
```

## Architecture

- **State-driven input**: Uses `GameState.Phase` enum instead of UI visibility
- **Decoupled autoloads**: Theme (colors), RunState (session), SaveData (persistence)
- **Named constants**: Brick dimensions, timing values extracted for easy tuning

## Running

1. Open in Godot 4.x
2. Run `main.tscn`
3. Launch ball with Space or Click

## Build Notes

- Godot 4.x (GDScript 2.0)
- Collision layers: 1=Paddle, 2=Ball, 3=Brick, 4=PowerUp, 5=Laser
- Signals used for decoupled communication