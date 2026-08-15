class_name RingEffect
extends Node2D

var _radius: float = 20.0
var _color: Color = Color.WHITE

func play(at: Vector2, color: Color, start_radius: float = 14.0, expand_to: float = 2.0, duration: float = 0.18) -> void:
	global_position = at
	_color = color
	_radius = start_radius
	var tw := create_tween()
	tw.tween_method(func(r): _radius = r; queue_redraw(), start_radius, start_radius * expand_to, duration)
	tw.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var segments := maxi(32, int(_radius * 0.8))
	if _radius > 4.0:
		var thin := _radius * 0.2
		draw_arc(Vector2.ZERO, _radius, 0, TAU, segments, Color(_color, modulate.a * 0.3), thin, true)
	if _radius > 8.0:
		var thick := _radius * 0.35
		draw_arc(Vector2.ZERO, _radius * 0.75, 0, TAU, segments, Color(_color, modulate.a * 0.5), thick, true)
