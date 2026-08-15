class_name LaserManager
extends Node2D

signal laser_fired
signal brick_scored(points: int)

const LASER_SCENE := preload("res://entities/laser_beam.tscn")
const FIRE_RATE := 0.3

var _active: bool = false
var _fire_timer: Timer
var _duration_timer: Timer
var _paddle: Paddle
var _check_can_fire: Callable

func set_can_fire_check(check: Callable) -> void:
	_check_can_fire = check

func _ready() -> void:
	_fire_timer = Timer.new()
	_fire_timer.one_shot = false
	_fire_timer.wait_time = FIRE_RATE
	_fire_timer.timeout.connect(_fire_laser)
	add_child(_fire_timer)

	_duration_timer = Timer.new()
	_duration_timer.one_shot = true
	_duration_timer.timeout.connect(deactivate)
	add_child(_duration_timer)

func set_paddle(paddle: Paddle) -> void:
	_paddle = paddle

func _clear_live_beams() -> void:
	for child in get_children():
		if child is Area2D:
			child.queue_free()

func activate(duration_sec: float = 8.0) -> void:
	_active = true
	_fire_timer.start()
	_duration_timer.start(duration_sec)

func deactivate() -> void:
	_active = false
	_fire_timer.stop()
	_clear_live_beams()

func _fire_laser() -> void:
	if not _active:
		return
	if not is_instance_valid(_paddle):
		return
	if _check_can_fire.is_valid() and not _check_can_fire.call():
		return
	var laser := LASER_SCENE.instantiate()
	laser.global_position = _paddle.global_position + Vector2(0, -24)
	add_child(laser)
	laser_fired.emit()

	laser.body_entered.connect(func(body: Node2D) -> void:
		if body is Brick:
			var brick := body as Brick

			if brick.is_scored():
				laser.queue_free()
				return

			var hit: Dictionary = brick.take_damage(1)
			if hit.get("was_already_scored", false):
				laser.queue_free()
				return

			brick_scored.emit(int(hit.get("score_points", 0)))

		laser.queue_free()
	, CONNECT_ONE_SHOT)
