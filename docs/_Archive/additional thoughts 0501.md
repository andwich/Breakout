Viewport resolution depends on your target platform and feel. Crisp modern 1280×720 works best for most setups.

Simple ColorRect blocks are perfect for a prototype—add sprites later for polish.

Extra features like sticky paddle and particles would enhance playtesting without overcomplicating the scaffold.

A basic progression system (speed ramps, brick density) adds replay value over endless mode.

## Recommended Setup

| Aspect | Choice | Why |
|---|---|---|
| **Resolution** | 1280×720 (stretchable) | Balances retro proportions with modern clarity; easy to upscale in Godot via CanvasLayer |
| **Visuals** | ColorRect + glow shaders | Quick iteration; add pixel-perfect sprites via TextureRect once mechanics solidify  |
| **Extras** | Sticky + SFX/particles | Sticky makes multi-ball more strategic; AudioStreamPlayer3D + GPUParticles2D for feedback |
| **Progression** | 5 levels + endless | Progressive speed/brick HP; unlock endless after completion |

## Quick Enhancements

**Sticky Paddle**: In `ball.gd`, add `sticky_mode: bool`. On paddle collision: `if paddle.sticky_mode: ball.stick_to_paddle()`. Launch on next spacebar.

**Particles**: Attach `GPUParticles2D` to `brick.tscn`. In `destroy()`: `particles.emitting = true`.

**Audio**: Add `AudioStreamPlayer2D` nodes, play `beep.ogg` on hits via signals.

This keeps the scaffold lightweight while making it feel complete. 

##
## Expanded Power-ups

Added **Sticky Paddle**, **Laser**, **Slow Balls**, and **Extra Life**. Each has unique visuals/symbols and durations where applicable.

### Updated `entities/powerup.gd`
```gdscript
class_name PowerUp
extends Area2D

enum Type { MULTIBALL, BIG_PADDLE, STICKY, LASER, SLOW_BALLS, EXTRA_LIFE }

signal collected(power_type: Type, duration_sec: float)

@export var fall_speed: float = 120.0
@export var power_type: Type = Type.MULTIBALL
@export var duration: float = 8.0  # For timed power-ups

@onready var _symbol_label: Label = $SymbolLabel  # Add Label child for icon

func _ready():
    body_entered.connect(_on_body_entered)
    _update_visual()

func _update_visual():
    var icons = {
        Type.MULTIBALL: "M", Type.BIG_PADDLE: "B", Type.STICKY: "S",
        Type.LASER: "L", Type.SLOW_BALLS: "↓", Type.EXTRA_LIFE: "♥"
    }
    _symbol_label.text = icons.get(power_type, "?")
    
    var colors = {
        Type.MULTIBALL: Color.MAGENTA, Type.BIG_PADDLE: Color.LIME_GREEN,
        Type.STICKY: Color.YELLOW, Type.LASER: Color.CYAN,
        Type.SLOW_BALLS: Color.PURPLE, Type.EXTRA_LIFE: Color.RED
    }
    modulate = colors.get(power_type, Color.WHITE)
```

### New `entities/laser.tscn` (for Laser Power-up)
Root: **Node2D** (singleton manager). Children: `LaserSpawner` (Marker2D).

### `entities/laser.gd`
```gdscript
class_name LaserManager
extends Node2D

signal laser_fired

const LASER_SCENE := preload("res://entities/laser_beam.tscn")  # Bullet scene
var _active: bool = false
var _fire_timer: Timer

func activate(duration_sec: float = 8.0):
    _active = true
    _fire_timer = Timer.new()
    _fire_timer.wait_time = 0.3
    _fire_timer.timeout.connect(_fire_laser)
    add_child(_fire_timer)
    _fire_timer.start()
    await get_tree().create_timer(duration_sec).timeout
    deactivate()

func deactivate():
    _active = false
    if _fire_timer:
        _fire_timer.queue_free()

func _fire_laser():
    if not _active: return
    var laser = LASER_SCENE.instantiate()
    laser.global_position = get_parent().get_parent().paddle.global_position + Vector2(0, -20)
    laser.rotation_degrees = 90  # Upward
    get_tree().current_scene.add_child(laser)
```

*(Create `laser_beam.tscn`: RigidBody2D → Area2D fast mover upward, destroys bricks on collision.)*

### Updated `main.gd` → `_on_powerup_collected()`
```gdscript
func _on_powerup_collected(ptype: PowerUp.Type, duration: float):
    match ptype:
        PowerUp.Type.MULTIBALL:
            for b in balls_container.get_children():
                if b is Ball and b._launched:
                    var clone = _spawn_ball(b.position)
                    clone._launched = true
                    clone.velocity = b.velocity.rotated(deg_to_rad(randf_range(20, 40)))
                    _connect_new_ball(clone)
        
        PowerUp.Type.BIG_PADDLE:
            paddle.apply_big_paddle(duration)
        
        PowerUp.Type.STICKY:
            paddle.toggle_sticky(duration)  # New method on Paddle
        
        PowerUp.Type.LASER:
            $LaserManager.activate(duration)
        
        PowerUp.Type.SLOW_BALLS:
            for b in balls_container.get_children():
                if b is Ball:
                    b._speed *= 0.6
            await get_tree().create_timer(duration).timeout
            for b in balls_container.get_children():
                if b is Ball:
                    b._speed = Ball.base_speed
        
        PowerUp.Type.EXTRA_LIFE:
            _lives += 1
```

### Paddle Updates for Sticky
```gdscript
# In paddle.gd
var _sticky_mode: bool = false
var _stuck_ball: Ball = null

func toggle_sticky(duration_sec: float = 8.0):
    _sticky_mode = true
    await get_tree().create_timer(duration_sec).timeout
    _sticky_mode = false
    if _stuck_ball:
        _stuck_ball.launch()
        _stuck_ball = null

# In ball collision (ball.gd):
if collider is Paddle and collider._sticky_mode:
    _stuck_ball = self  # Set on paddle
    velocity = Vector2.ZERO
    position = collider.position + Vector2(0, -paddle.height/2)
```

## Polished Visuals

Upgrade ColorRects to styled nodes with shaders/effects.

### Visual Polish Pack

1. **Pixel-Perfect Canvas** (Project Settings → Rendering → 2D → Pixel Snap: Enabled)
2. **Glow Shader** for bricks/power-ups:
   ```glsl
   // brick_glow.gdshader
   shader_type canvas_item;
   uniform float glow_intensity : hint_range(0.0, 2.0) = 1.2;
   void fragment() {
       vec4 glow = texture(TEXTURE, UV + vec2(0.01, 0.01)) * glow_intensity;
       COLOR = mix(glow, COLOR, 0.7);
   }
   ```
   Assign to brick/power-up materials.

3. **Trail Effect** on balls:
   ```
   Ball child: Trail2D (Lifetime 0.3s, Width Curve fade-out)
   ```

4. **HUD Overhaul** (`ui/hud.tscn`):
   ```
   CanvasLayer
   ├── ScoreLabel (top-left)
   ├── LivesIcons (HBoxContainer with ♥ textures)
   └── PowerupTimer (ProgressBar for active timed power-ups)
   ```

5. **Brick Variants**:
   | Type | Visual | HP |
   |------|--------|----|
   | Standard | Solid glow | 1 |
   | Metal | Animated scanline shader | 3 |
   | Boss | Pulsing scale tween | 5 |

6. **SFX + Particles**:
   - `AudioStreamPlayer2D` on hits (free brick-break SFX packs).
   - `GPUParticles2D` on brick destroy: Emit bursts of colorful pixels.

## Next Steps
1. Copy the power-up expansions into your scenes.
2. Add `LaserManager` node to `main.tscn`.
3. Apply glow shader to materials.
4. Test multi-ball chaos!

This doubles the power-up variety while keeping code modular. 


##
## Laser Beam Script

### `entities/laser_beam.tscn`
Root: **Area2D** named `LaserBeam`  
Children:  
- `CollisionShape2D` (RectangleShape2D, size ~4×60)  
- `ColorRect` (cyan, size 4×60)  
- `VisibleOnScreenNotifier2D`

### `entities/laser_beam.gd`
```gdscript
class_name LaserBeam
extends Area2D

signal brick_destroyed(points: int)

const SPEED: float = 800.0
@export var damage: int = 1

func _ready():
    body_entered.connect(_on_hit)
    screen_exited.connect(queue_free)
    # Rotate to face up
    rotation_degrees = 90

func _physics_process(delta: float):
    position.y -= SPEED * delta

func _on_hit(body: Node2D):
    if body is Brick:
        body.take_damage(damage)
        brick_destroyed.emit(body.point_value)
        queue_free()
    elif body is Paddle:
        queue_free()  # Harmless if hits paddle
```

Connect `brick_destroyed` to `main.gd`'s `_on_brick_hit()` in `LaserManager`.

## Boss Bricks (Multi-Hit)

### Updated `entities/brick.gd`
```gdscript
class_name Brick
extends StaticBody2D

signal destroyed(from_position: Vector2)
signal damaged(hp_remaining: int)

@export var max_hp: int = 1
@export var point_value: int = 10
@export var drop_chance: float = 0.25
@export var is_boss: bool = false

var _hp: int

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _hp_label: Label = $HP_Label  # Optional child Label
@onready var _particles: GPUParticles2D = $Particles  # Child for effects

func _ready():
    _hp = max_hp
    _update_visual()
    if is_boss:
        # Tween pulsing
        var tween := create_tween()
        tween.set_loops()
        tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.5)
        tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func take_damage(amount: int = 1):
    _hp -= amount
    _update_visual()
    damaged.emit(_hp)
    
    if _hp <= 0:
        destroy()
    else:
        _particles.emitting = true  # Hit flash

func destroy():
    destroyed.emit(global_position)
    if randf() < drop_chance:
        get_tree().current_scene._spawn_powerup(global_position)  # Access via signal if decoupled
    _particles.emitting = true
    queue_free()

func _update_visual():
    if _hp_label:
        _hp_label.text = str(_hp)
    modulate.a = 1.0 - float(_hp) / max_hp * 0.5  # Fade as damaged
```

**Spawn Boss**: In `_spawn_bricks()`, for certain positions: `b.max_hp = 3; b.is_boss = true; b.point_value = 100`.

## Glow Shader Files

### `shaders/brick_glow.gdshader`
```
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.5, 3.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 uv_offset = vec2(0.005, 0.005);
    vec4 center = texture(TEXTURE, UV);
    vec4 glow = (
        texture(TEXTURE, UV + uv_offset) +
        texture(TEXTURE, UV - uv_offset) +
        texture(TEXTURE, UV + vec2(-uv_offset.x, uv_offset.y)) +
        texture(TEXTURE, UV + vec2(uv_offset.x, -uv_offset.y))
    ) * 0.25 * glow_intensity * glow_color;
    
    COLOR = mix(glow, center, 0.6);
    COLOR.a = center.a;
}
```

**Assign**: Brick `ColorRect` → Material → New ShaderMaterial → Shader: this file.

### `shaders/scanline.gdshader` (for Metal Boss Bricks)
```
shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 2.0;

void fragment() {
    float scan_y = mod(TIME * speed + UV.y * 10.0, 1.0);
    float scan = sin(scan_y * 3.14159 * 2.0) * 0.3 + 0.7;
    COLOR.rgb *= scan;
}
```

## Pixel-Art Power-up Sprites

Instead of labels, use **AtlasTexture** sprites:

1. **Create 32×32 PNG spritesheet** (`powerups.png`): M/B/S/L/↓/♥ icons, pixel art style.
2. **AtlasTexture setup** in `powerup.tscn`:
   ```
   SpriteFrames (AnimatedSprite2D child)
   ├── frame_0: atlas region (0,0,32,32)  # Multi-ball
   └── etc.
   ```
3. In `powerup.gd`: `animated_sprite.play(power_type_names[power_type])`.

Free pixel assets: Search "breakout power-up icons itch.io" or draw in Aseprite (4 colors: BG, primary, glow, highlight).

## Particles Setup

**`brick.tscn` child**: `GPUParticles2D`
- Process Material: `New ParticlesMaterial`
  - Direction: (0,-1), Spread 45°
  - Initial Velocity: 100-200
  - Scale: 0.5-1.5 over lifetime
  - Color Ramp: Yellow→Orange→Fade
- Amount: 12, Lifetime: 0.4s
- Emitting: False (toggle in `take_damage()`)

Boss bricks now pulse, take 3+ hits, and drop better rewards. Lasers fire automatically every 0.3s during active period.

Test this expansion—multi-ball + lasers create wild combos!