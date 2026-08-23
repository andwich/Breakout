class_name Ball
extends CharacterBody2D

signal life_lost
signal brick_hit(points: int)
signal paddle_hit

const MAX_STEP_DISTANCE := 6.0
const MAX_PHYSICS_STEPS := 96
const MIN_UPWARD_COMPONENT := 0.42

@export var base_speed: float = 350.0
@export var ball_color: Color = GameTheme.BALL:
	set(v):
		ball_color = v
		_update_trail_color()
		queue_redraw()
var speed: float = base_speed
var launched := false
var paddle: Paddle
var pop_tween: Tween
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
	if _trail:
		_trail.emitting = false
	if is_instance_valid(paddle):
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

	var viewport_size := get_viewport_rect().size
	var escape_margin := 64.0
	if global_position.x < -escape_margin \
			or global_position.x > viewport_size.x + escape_margin \
			or global_position.y < -escape_margin \
			or global_position.y > viewport_size.y + escape_margin:
		_on_screen_exited()
		return

	var dist := global_position.distance_squared_to(_last_pos)
	_last_pos = global_position
	if dist < 1.0:
		_stuck_frames += 1
		if _stuck_frames > 30:
			var escape_dir := _last_velocity.normalized() if _last_velocity.length_squared() > 0.01 else Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			escape_dir = escape_dir.rotated(deg_to_rad(randf_range(-30, 30)))
			escape_dir.y = minf(escape_dir.y, -0.35)
			velocity = escape_dir.normalized() * speed
			_stuck_frames = 0
	else:
		_stuck_frames = 0

	var travel := velocity * delta
	var remaining := travel.length()
	if remaining <= 0.01:
		return

	var direction := travel / remaining
	var collision: KinematicCollision2D
	var steps := 0

	while remaining > 0.01 and steps < MAX_PHYSICS_STEPS:
		var step_dist := minf(MAX_STEP_DISTANCE, remaining)
		collision = move_and_collide(direction * step_dist)
		if collision:
			break
		remaining -= step_dist
		steps += 1

	# Residual move: accepted tunneling risk on severe frame hitches (travel
	# beyond MAX_PHYSICS_STEPS * MAX_STEP_DISTANCE). Never discard travel.
	if remaining > 0.01 and collision == null:
		move_and_collide(direction * remaining)

	_last_velocity = velocity
	if not collision:
		return

	var collider := collision.get_collider()
	var normal := collision.get_normal()

	if collider is Brick:
		var brick := collider as Brick
		var hit: Dictionary = brick.take_damage(1)

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
		var p: Paddle = collider as Paddle
		if p.sticky_mode:
			if p.stick_ball(self):
				launched = false
				velocity = Vector2.ZERO
				return
			# paddle already has a caught ball — treat as normal bounce
		var hit_ratio: float = (global_position.x - p.global_position.x) / (p.target_width / 2.0)
		hit_ratio = clampf(hit_ratio, -1.0, 1.0)
		var aim := Vector2(hit_ratio, -1.0).normalized()
		aim.y = minf(aim.y, -MIN_UPWARD_COMPONENT)
		velocity = aim.normalized() * speed
		_clamp_min_speed()
		return
	else:
		velocity = velocity.bounce(normal)
		_clamp_min_speed()


func _clamp_min_speed() -> void:
	if velocity.length_squared() < 0.01:
		velocity = Vector2.UP * speed
		return
	velocity = velocity.normalized() * speed

func _pop_visual() -> void:
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
	scale = Vector2.ONE
	pop_tween = create_tween()
	pop_tween.set_trans(Tween.TRANS_QUAD)
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", Vector2(1.16, 0.88), 0.035)
	pop_tween.set_trans(Tween.TRANS_ELASTIC)
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.095)

func _draw() -> void:
	var bright := ball_color.lightened(0.3)
	draw_circle(Vector2.ZERO, 14.0, Color(bright.r, bright.g, bright.b, 0.15))
	draw_circle(Vector2.ZERO, 10.0, Color(bright.r, bright.g, bright.b, 0.30))
	draw_circle(Vector2.ZERO, 8.0, ball_color)

func _on_screen_exited() -> void:
	if not launched:
		return
	launched = false
	velocity = Vector2.ZERO
	life_lost.emit()
	queue_free()

func _exit_tree() -> void:
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
