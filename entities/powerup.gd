class_name PowerUp
extends Area2D

enum Type { MULTIBALL, BIG_PADDLE, STICKY, LASER, SLOW_BALLS, EXTRA_LIFE }

signal collected(power_type: Type, duration_sec: float)

@export var fall_speed: float = 120.0
@export var power_type: Type = Type.MULTIBALL

var _drift_phase: float

@onready var _symbol_label: Label = $Sprite/SymbolLabel
@onready var _sprite: ColorRect = $Sprite

func _ready():
	_drift_phase = randf() * TAU
	body_entered.connect(_on_body_entered)
	_update_visual()
	var t := create_tween().set_loops()
	t.tween_property(self, "modulate:a", 0.6, 0.35)
	t.tween_property(self, "modulate:a", 1.0, 0.35)

func _update_visual():
	_symbol_label.text = PowerUpRegistry.icon_for(power_type)
	modulate = PowerUpRegistry.color_for(power_type)

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	position.x += sin(Time.get_ticks_msec() * 0.003 + _drift_phase) * 0.8
	if _sprite:
		_sprite.rotation += delta * 1.2
	if position.y > get_viewport_rect().size.y + 50:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Paddle:
		collected.emit(power_type, PowerUpRegistry.duration_for(power_type))
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(queue_free)
