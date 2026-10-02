class_name Paddle
extends CharacterBody2D

signal sticky_ball_caught
signal sticky_ball_released

@export var speed: float = 400.0
@export var normal_width: float = 100.0

var target_width: float
## Rendered/colliding width. `target_width` is the *intent*; `visual_width` is what
## the sprite and collision shape actually hold while a width change tweens. Drawing
## and geometry read `visual_width` so art never leads or lags physics.
var visual_width: float = normal_width
var wall_left_x: float = 0.0
var wall_right_x: float = 0.0
var sticky_mode := false
var stuck_ball: Ball
var aim_angle: float = 0.0
var show_aim := false

var _shape: RectangleShape2D
var _width_tween: Tween
var _prev_aim := 0.0
var _edge_warn_left: float = 0.0
var _edge_warn_right: float = 0.0
var _big_paddle_timer: Timer
var _sticky_timer: Timer
var _sticky_release_callback: Callable
var _deferred_launch: bool = false
var _keyboard_active := false

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	target_width = normal_width
	visual_width = normal_width
	_shape = $CollisionShape2D.shape as RectangleShape2D

	_big_paddle_timer = Timer.new()
	_big_paddle_timer.one_shot = true
	_big_paddle_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_big_paddle_timer.timeout.connect(_reset_paddle_width)
	add_child(_big_paddle_timer)

	_sticky_timer = Timer.new()
	_sticky_timer.one_shot = true
	_sticky_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_sticky_timer.timeout.connect(_disable_sticky)
	add_child(_sticky_timer)

func _draw() -> void:
	if sticky_mode:
		var pulse := sin(Time.get_ticks_msec() * 0.006) * 0.5 + 0.5
		var glow_color := Color(1.0, 1.0, 0.4, pulse * 0.35)
		draw_rect(Rect2(-visual_width / 2.0 - 3, -11, visual_width + 6, 22), glow_color, false, 2.0, true)
	var half_w := visual_width / 2.0
	if _edge_warn_left > 0.0:
		var warn_color := Color(1.0, 1.0, 0.4, _edge_warn_left * 0.5)
		draw_line(Vector2(-half_w, 0), Vector2(-half_w - _edge_warn_left * 10.0, 0), warn_color, 2.0, true)
	if _edge_warn_right > 0.0:
		var warn_color := Color(1.0, 1.0, 0.4, _edge_warn_right * 0.5)
		draw_line(Vector2(half_w, 0), Vector2(half_w + _edge_warn_right * 10.0, 0), warn_color, 2.0, true)
	var draw_aim := show_aim
	if draw_aim:
		var origin := Vector2(0, -get_visual_ball_attach_offset())
		var angle_range := aim_angle
		var line_len := 80.0
		var color := Color(1.0, 1.0, 0.4, 0.55)
		if not sticky_mode:
			color.a = 0.35
		for angle_mod in [-1, 1]:
			var dir := Vector2.UP.rotated(deg_to_rad(angle_mod * angle_range))
			draw_line(origin, origin + dir * line_len, color, 1.5, true)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		_keyboard_active = true
	elif Input.get_last_mouse_velocity().length_squared() > 4.0:
		_keyboard_active = false
	if not _keyboard_active:
		var target_x := get_global_mouse_position().x
		if target_x >= 0.0 and target_x <= get_viewport_rect().size.x:
			direction = clampf((target_x - position.x) / (visual_width * 0.5), -1.0, 1.0)
	velocity = Vector2(direction * speed, 0)
	move_and_slide()

	var limit := get_viewport_rect().size.x
	var left_bound := wall_left_x + visual_width / 2.0
	var right_bound := (wall_right_x if wall_right_x > 0.0 else limit) - visual_width / 2.0
	position.x = clamp(position.x, left_bound, right_bound)

	_edge_warn_left = maxf(0.0, 1.0 - (position.x - left_bound) / 40.0)
	_edge_warn_right = maxf(0.0, 1.0 - (right_bound - position.x) / 40.0)

	if not sticky_mode or has_caught_ball():
		aim_angle = clampf(velocity.x / speed * 45.0, -45.0, 45.0)

	if has_caught_ball() and sticky_mode:
		stuck_ball.global_position = global_position + Vector2(0, -get_ball_attach_offset())
	if not is_equal_approx(aim_angle, _prev_aim):
		_prev_aim = aim_angle
		queue_redraw()
	# Glow / edge warnings / tweened width all animate continuously: redraw each
	# tick any of them is live.
	if sticky_mode or show_aim or _width_tween != null or _edge_warn_left > 0.0 or _edge_warn_right > 0.0:
		queue_redraw()

# Deferred sticky release lives here (not in _physics_process) on purpose:
# _physics_process stops while the tree is paused, but the release-callback gate
# must keep being polled across pause states.
func _process(_delta: float) -> void:
	if _deferred_launch and not get_tree().paused and (not _sticky_release_callback.is_valid() or _sticky_release_callback.call()):
		_deferred_launch = false
		if has_caught_ball():
			stuck_ball.launch(Vector2.UP, aim_angle)
		stuck_ball = null
		clear_sticky_aim()

func _apply_width_pixels(v: float) -> void:
	_shape.size.x = v
	visual_width = v
	sprite.offset_left = -v / 2.0
	sprite.offset_right = v / 2.0

func _set_paddle_width(width: float, animated: bool = true) -> void:
	target_width = width
	TweenHelper.kill_if_valid(_width_tween)
	_width_tween = null
	if not animated or not is_inside_tree():
		_apply_width_pixels(width)
		queue_redraw()
		return
	_width_tween = create_tween()
	_width_tween.tween_method(_apply_width_pixels, _shape.size.x, width, 0.15)
	_width_tween.tween_callback(func():
		_width_tween = null
		queue_redraw()
	)

func apply_big_paddle(duration_sec: float) -> void:
	_set_paddle_width(normal_width * 1.6)
	_big_paddle_timer.start(duration_sec)
	refresh_visual_state()

func _reset_paddle_width() -> void:
	_set_paddle_width(normal_width)
	refresh_visual_state()

func enable_sticky(duration_sec: float) -> void:
	sticky_mode = true
	_sticky_timer.start(duration_sec)
	refresh_visual_state()

func _disable_sticky() -> void:
	sticky_mode = false
	refresh_visual_state()
	if has_caught_ball():
		stuck_ball.global_position = global_position + Vector2(0, -get_ball_attach_offset())
		stuck_ball.velocity = Vector2.ZERO
		stuck_ball.launched = false
	if get_tree().paused or not is_processing() or (_sticky_release_callback.is_valid() and not _sticky_release_callback.call()):
		_deferred_launch = true
	else:
		if has_caught_ball():
			stuck_ball.launch(Vector2.UP, aim_angle)
		stuck_ball = null
		_deferred_launch = false
		clear_sticky_aim()

func reset() -> void:
	_big_paddle_timer.stop()
	_sticky_timer.stop()
	sticky_mode = false
	stuck_ball = null
	show_aim = false
	_set_paddle_width(normal_width, false)
	refresh_visual_state()

func stick_ball(ball: Ball) -> bool:
	if has_caught_ball():
		return false
	stuck_ball = ball
	ball.global_position = global_position + Vector2(0, -get_ball_attach_offset())
	show_aim = true
	refresh_visual_state()
	sticky_ball_caught.emit()
	return true

## Attach offset derived from a width value — single source for the real and the
## tweening (visual) variants.
func _attach_offset_for(width: float) -> float:
	return 24.0 + (width - 100.0) * 0.05

func get_ball_attach_offset() -> float:
	return _attach_offset_for(target_width)

func get_visual_ball_attach_offset() -> float:
	return _attach_offset_for(visual_width)

func set_sticky_release_callback(cb: Callable) -> void:
	_sticky_release_callback = cb

func is_big_paddle_active() -> bool:
	return target_width > normal_width

func has_caught_ball() -> bool:
	return stuck_ball != null and is_instance_valid(stuck_ball)

func clear_sticky_aim() -> void:
	show_aim = false
	sticky_ball_released.emit()
	queue_redraw()

func refresh_visual_state() -> void:
	var target_color: Color = GameTheme.PADDLE
	if sticky_mode:
		target_color = GameTheme.PADDLE_STICKY
	elif is_big_paddle_active():
		target_color = GameTheme.PADDLE_WIDE

	sprite.color = target_color
	queue_redraw()

func _exit_tree() -> void:
	TweenHelper.kill_if_valid(_width_tween)
	_width_tween = null
