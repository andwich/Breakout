Neon retro palette fits perfectly for a polished Breakout feel. Auto-fire lasers keep action flowing without extra inputs.

Unlock screen adds polish after Level 5. Heart icons are more intuitive than numbers.

## Recommendations

| Question | Pick | Rationale |
|---|---|---|
| **Palette** | Retro-neon (cyan/magenta/lime/dark) | Matches scaffold shaders; evokes Atari+cyberpunk  |
| **Laser** | Auto-fire (as scaffolded) | Frictionless—manual would need UI/timer clutter |
| **Endless** | Win screen → Unlock | Satisfying progression; endless starts with faster balls |
| **Lives** | ♥♥♥ icons | Visual feedback; animate disappear on loss |

## Implementation Snippets

### Retro-Neon Palette (Project-Wide)
**`autload/colors.gd`** (singleton):
```gdscript
extends Node

const NEON_BG = Color(0.08, 0.05, 0.15)
const NEON_CYAN = Color(0.2, 1.0, 1.0)
const NEON_MAGENTA = Color(1.0, 0.2, 0.8)
const NEON_LIME = Color(0.4, 1.0, 0.2)
const NEON_YELLOW = Color(1.0, 1.0, 0.4)

# Use in shaders: uniform vec4 primary_color = vec4(0.2,1.0,1.0,1.0);
```

Apply to `ColorRect` modulates and shader uniforms.

### Lives Icons (`ui/hud.gd`)
```gdscript
@onready var lives_container: HBoxContainer = $LivesContainer

func update_lives(lives: int):
    for child in lives_container.get_children():
        child.visible = false
    for i in range(lives):
        lives_container.get_child(i).visible = true
        lives_container.get_child(i).modulate = Color.RED  # Heart texture
```

**Scene**: HBoxContainer → 5 TextureRect children (preload heart.png).

### Endless Unlock Screen
**New `ui/victory.tscn`**: Control → VBoxContainer ("Level Complete! Press SPACE for Endless").
```gdscript
# In main.gd _level_complete():
if current_level >= 5:
    get_tree().change_scene_to_file("res://ui/victory.tscn")
else:
    current_level += 1
    _spawn_bricks()  # Faster, denser layout
```

This nails the arcade vibe. 
