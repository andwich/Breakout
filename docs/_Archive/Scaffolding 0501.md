Here's a complete **Godot 4.x** scaffold using GDScript. It follows the engine's node-based architecture with scenes-as-prefabs, signals for decoupled communication, and a clean power-up system.

## Project Structure

```
res://
├── main.tscn
├── main.gd
├── entities/
│   ├── paddle.tscn
│   ├── paddle.gd
│   ├── ball.tscn
│   ├── ball.gd
│   ├── brick.tscn
│   ├── brick.gd
│   ├── powerup.tscn
│   └── powerup.gd
└── ui/
    ├── hud.tscn
    └── hud.gd
```

## Scene Setup & Scripts

### `entities/paddle.tscn`
Root: **CharacterBody2D** named `Paddle`  
Children: `CollisionShape2D` (RectangleShape2D, ~100×16), `ColorRect` or `Sprite2D` for visuals.

### `entities/paddle.gd`
```gdscript
class_name Paddle
extends CharacterBody2D

@export var speed: float = 400.0
@export var normal_width: float = 100.0

var _target_width: float = normal_width
var _shape: RectangleShape2D

func _ready():
    _shape = $CollisionShape2D.shape as RectangleShape2D
    _target_width = normal_width

func _physics_process(delta: float) -> void:
    var direction := Input.get_axis("ui_left", "ui_right")
    velocity = Vector2(direction * speed, 0)
    move_and_slide()
    
    # Clamp to viewport
    var limit := get_viewport_rect().size.x
    position.x = clamp(position.x, _target_width / 2.0, limit - _target_width / 2.0)

func apply_big_paddle(duration_sec: float = 8.0) -> void:
    _target_width = normal_width * 1.6
    _shape.size.x = _target_width
    $Sprite2D.scale.x = 1.6  # Adjust if using Sprite2D/ColorRect
    await get_tree().create_timer(duration_sec).timeout
    _target_width = normal_width
    _shape.size.x = normal_width
    $Sprite2D.scale.x = 1.0
```

***

### `entities/ball.tscn`
Root: **CharacterBody2D** named `Ball`  
Children: `CollisionShape2D` (CircleShape2D, radius 8), `VisibleOnScreenNotifier2D` (to detect off-screen).

### `entities/ball.gd`
```gdscript
class_name Ball
extends CharacterBody2D

signal life_lost
signal brick_hit(points: int)

@export var base_speed: float = 350.0
var _speed: float = base_speed
var _launched: bool = false

@onready var _start_pos: Vector2 = position

func _ready():
    velocity = Vector2.ZERO

func launch(toward: Vector2 = Vector2(0, -1)) -> void:
    if _launched:
        return
    _launched = true
    var angle := randf_range(-60, 60)
    velocity = toward.rotated(deg_to_rad(angle)) * _speed

func reset() -> void:
    _launched = false
    velocity = Vector2.ZERO
    position = _start_pos

func _physics_process(delta: float) -> void:
    if not _launched:
        return
    
    var collision := move_and_collide(velocity * delta)
    if not collision:
        return
    
    var collider := collision.get_collider()
    var normal := collision.get_normal()
    
    # Bounce off walls and bricks
    velocity = velocity.bounce(normal)
    
    # Aim control: if hitting paddle, influence angle by hit position
    if collider is Paddle:
        var paddle := collider as Paddle
        var hit_ratio := (position.x - paddle.position.x) / (paddle._target_width / 2.0)
        hit_ratio = clampf(hit_ratio, -1.0, 1.0)
        # Blend current bounce with aim vector
        var aim := Vector2(hit_ratio * 0.9, -1.0).normalized()
        velocity = aim * velocity.length()
    
    if collider is Brick:
        collider.destroy()
        brick_hit.emit(collider.point_value)
    
    # Prevent shallow horizontal bounces
    if absf(velocity.y) < 50.0:
        velocity.y = signf(velocity.y) * 50.0
        velocity = velocity.normalized() * _speed

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
    if global_position.y > get_viewport_rect().size.y:
        life_lost.emit()
        reset()
```

***

### `entities/brick.tscn`
Root: **StaticBody2D** named `Brick`  
Children: `CollisionShape2D` (RectangleShape2D, ~60×20), `ColorRect` for visuals.

### `entities/brick.gd`
```gdscript
class_name Brick
extends StaticBody2D

signal destroyed(from_position: Vector2)

@export var point_value: int = 10
@export var drop_chance: float = 0.25

@onready var _collision: CollisionShape2D = $CollisionShape2D

func destroy() -> void:
    destroyed.emit(global_position)
    queue_free()
```

***

### `entities/powerup.tscn`
Root: **Area2D** named `PowerUp` (gravity = 0)  
Children: `CollisionShape2D` (RectangleShape2D, ~20×20), `ColorRect` or `Sprite2D`.

### `entities/powerup.gd`
```gdscript
class_name PowerUp
extends Area2D

enum Type { MULTIBALL, BIG_PADDLE, STICKY }

signal collected(power_type: Type)

@export var fall_speed: float = 120.0
@export var power_type: Type = Type.MULTIBALL

func _ready():
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    position.y += fall_speed * delta
    if position.y > get_viewport_rect().size.y + 50:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if body is Paddle:
        collected.emit(power_type)
        queue_free()
```

***

### `main.gd`
```gdscript
extends Node2D

const BALL_SCENE := preload("res://entities/ball.tscn")
const BRICK_SCENE := preload("res://entities/brick.tscn")
const POWERUP_SCENE := preload("res://entities/powerup.tscn")

@onready var paddle: Paddle = $Paddle
@onready var balls_container: Node2D = $Balls
@onready var powerups_container: Node2D = $PowerUps
@onready var bricks_container: Node2D = $Bricks

var _score: int = 0
var _lives: int = 3
var _brick_count: int = 0

func _ready():
    _spawn_bricks()
    _spawn_ball()
    _connect_new_ball(balls_container.get_child(0) as Ball)

func _spawn_bricks():
    var cols := 10
    var rows := 5
    var brick_w := 60
    var brick_h := 20
    var pad := 4
    var total_w := cols * (brick_w + pad) - pad
    var start_x := (get_viewport_rect().size.x - total_w) / 2.0
    
    for r in range(rows):
        for c in range(cols):
            var b := BRICK_SCENE.instantiate() as Brick
            b.position = Vector2(start_x + c * (brick_w + pad), 50 + r * (brick_h + pad))
            b.point_value = (rows - r) * 10
            b.destroyed.connect(_on_brick_destroyed)
            bricks_container.add_child(b)
            _brick_count += 1

func _spawn_ball(at: Vector2 = Vector2.ZERO) -> Ball:
    var b := BALL_SCENE.instantiate() as Ball
    if at == Vector2.ZERO:
        at = paddle.position + Vector2(0, -30)
    b.position = at
    balls_container.add_child(b)
    return b

func _connect_new_ball(b: Ball):
    b.life_lost.connect(_on_ball_lost)
    b.brick_hit.connect(_on_brick_hit)

func _on_brick_hit(points: int):
    _score += points
    # Update HUD here

func _on_brick_destroyed(pos: Vector2):
    _brick_count -= 1
    if randf() < 0.25:
        _spawn_powerup(pos)
    if _brick_count <= 0:
        _level_complete()

func _spawn_powerup(pos: Vector2):
    var p := POWERUP_SCENE.instantiate() as PowerUp
    p.position = pos
    p.power_type = PowerUp.Type.values().pick_random()
    p.collected.connect(_on_powerup_collected)
    powerups_container.add_child(p)

func _on_powerup_collected(ptype: PowerUp.Type) -> void:
    match ptype:
        PowerUp.Type.MULTIBALL:
            # Clone every active ball into two
            for b in balls_container.get_children():
                if not (b is Ball):
                    continue
                var original: Ball = b
                var clone := _spawn_ball(original.position)
                clone._launched = true
                clone._speed = original._speed
                # Diverge slightly
                var angle := deg_to_rad(randf_range(20, 40))
                clone.velocity = original.velocity.rotated(angle)
                _connect_new_ball(clone)
        PowerUp.Type.BIG_PADDLE:
            paddle.apply_big_paddle()
        PowerUp.Type.STICKY:
            # Scaffold: set a sticky flag, catch next ball
            pass

func _on_ball_lost():
    var alive := balls_container.get_children().filter(
        func(b): return b is Ball and b._launched
    )
    if alive.is_empty():
        _lives -= 1
        if _lives <= 0:
            _game_over()
        else:
            var b := _spawn_ball()
            _connect_new_ball(b)

func _input(event):
    if event.is_action_pressed("ui_accept") or event.is_action_pressed("click"):
        var balls := balls_container.get_children()
        for b in balls:
            if b is Ball and not b._launched:
                (b as Ball).launch()

func _level_complete():
    # Spawn harder layout or win screen
    get_tree().reload_current_scene()

func _game_over():
    # Show Game Over UI
    get_tree().paused = true
```

## Godot Editor Setup

1. **Input Map**: Add `move_left` / `move_right` (Arrow keys or A/D). `click` or `ui_accept` for launching.
2. **Collision Layers**:
   - Layer 1: Paddle
   - Layer 2: Ball
   - Layer 3: Bricks
   - Layer 4: Power-ups
3. **Collision Masks**:
   - Ball: collides with Paddle (1), Bricks (3)
   - Power-up Area2D: collides with Paddle (1)

## Modern Features Built In

| Feature | Implementation |
|---|---|
| **Multi-ball drops** | `MULTIBALL` power-up clones every active ball with a slightly rotated velocity [1] |
| **Big paddle** | `BIG_PADDLE` triggers `apply_big_paddle()` on the paddle, using an async timer to auto-revert after 8 seconds |
| **Aim control** | On paddle collision, `hit_ratio` shifts the ball's horizontal velocity based on where it struck the paddle |
| **Signal decoupling** | Bricks emit `destroyed`, balls emit `life_lost`, and power-ups emit `collected`—the `main.gd` conductor handles all game logic |

To add lasers or a sticky paddle, extend the `PowerUp.Type` enum and add handlers in `_on_powerup_collected()`.

