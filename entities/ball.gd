class_name Ball
extends CharacterBody2D

signal life_lost
signal brick_hit(points: int)
signal paddle_hit

@export var base_speed: float = 350.0
@export var ball_color: Color = Color(1.0, 1.0, 0.6):
	set(v):
		ball_color = v
		_update_trail_color()
		queue_redraw()
var speed: float = base_speed
var launched := false
var paddle: Paddle
var _stuck_frames: int = 0
var _last_pos: Vector2
var _last_velocity: Vector2
var _trail_dir: Vector3 = Vector3(0, -1, 0)
var _trail: GPUParticles2D
var _trail_mat: ParticleProcessMaterial

func set_paddle(value: Paddle) -> void:
	paddle = value

func _update_trail_color() -> void:
	if not _trail:
		return
	if _trail_mat:
		_trail_mat.color = ball_color

func _ready() -> void:
	velocity = Vector2.ZERO
	_trail = $Trail as GPUParticles2D
	if _trail:
		_trail_mat = _trail.process_material as ParticleProcessMaterial
	var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	_update_trail_color()

func is_waiting() -> bool:
	return not launched

func attach_to_paddle() -> void:
	launched = false
	velocity = Vector2.ZERO
	_stuck_frames = 0
	if paddle:
		global_position = paddle.global_position + Vector2(0, -paddle.get_ball_attach_offset())
	_last_pos = global_position
	_last_velocity = Vector2.ZERO

func launch(toward: Vector2 = Vector2.UP, aim_bias: float = 0.0) -> void:
	if launched:
		return
	if paddle and paddle.stuck_ball == self:
		paddle.stuck_ball = null
	launched = true
	var angle := aim_bias + randf_range(-3.0, 3.0)
	velocity = toward.rotated(deg_to_rad(angle)) * speed
	_last_pos = global_position
	_last_velocity = velocity

func _physics_process(delta: float) -> void:
	if _trail:
		_trail.emitting = launched
	if launched and velocity.length_squared() > 1.0 and _trail_mat:
		var target := Vector3(-velocity.normalized().x, -velocity.normalized().y, 0.0)
		_trail_dir = _trail_dir.lerp(target, 0.25)
		_trail_mat.direction = _trail_dir

	if not launched:
		return

	var dist := global_position.distance_squared_to(_last_pos)
	_last_pos = global_position
	if dist < 1.0:
		_stuck_frames += 1
		if _stuck_frames > 30:
			var escape_dir := _last_velocity.normalized() if _last_velocity.length_squared() > 0.01 else Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			velocity = escape_dir.rotated(deg_to_rad(randf_range(-40, 40))) * speed
			_stuck_frames = 0
	else:
		_stuck_frames = 0

	var max_step_dist := 6.0
	var travel := velocity * delta
	var remaining := travel.length()
	var direction := travel.normalized()
	var collision: KinematicCollision2D
	var steps := 0
	var max_steps := 10

	while remaining > 0.01 and steps < max_steps:
		var step_dist := mini(max_step_dist, remaining)
		collision = move_and_collide(direction * step_dist)
		if collision:
			break
		remaining -= step_dist
		steps += 1

	_last_velocity = velocity
	if not collision:
		return

	var collider := collision.get_collider()
	var normal := collision.get_normal()

	if collider is Brick:
		var hit := collider.take_damage(1)
		if hit.get("was_already_scored", false):
			return
		velocity = velocity.bounce(normal)
		_clamp_min_speed()
		_pop_visual()
		brick_hit.emit(int(hit.get("score_points", 0)))
		return

	if collider is Paddle:
		paddle_hit.emit()
		_pop_visual()
		var p := collider as Paddle
		if p.sticky_mode:
			p.stick_ball(self)
			launched = false
			velocity = Vector2.ZERO
			return
		var hit_ratio := (global_position.x - p.global_position.x) / (p.target_width / 2.0)
		hit_ratio = clampf(hit_ratio, -1.0, 1.0)
		var aim := Vector2(hit_ratio * 0.9, -1.0).normalized()
		velocity = aim * velocity.length()
		_clamp_min_speed()
		return
	else:
		velocity = velocity.bounce(normal)
		_clamp_min_speed()


func _clamp_min_speed() -> void:
	if absf(velocity.y) < 50.0:
		velocity.y = 50.0 if velocity.y >= 0.0 else -50.0
	if velocity.x != 0.0 and absf(velocity.x) < 50.0:
		velocity.x = signf(velocity.x) * 50.0
	velocity = velocity.normalized() * speed

func _pop_visual() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.03)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

func _draw() -> void:
	var bright := ball_color.lightened(0.3)
	draw_circle(Vector2.ZERO, 14.0, Color(bright.r, bright.g, bright.b, 0.15))
	draw_circle(Vector2.ZERO, 10.0, Color(bright.r, bright.g, bright.b, 0.30))
	draw_circle(Vector2.ZERO, 8.0, ball_color)

func _on_screen_exited() -> void:
	if global_position.y > get_viewport_rect().size.y + 20.0:
		launched = false
		life_lost.emit()
		queue_free()
