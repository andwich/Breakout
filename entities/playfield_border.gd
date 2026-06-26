extends Node2D

@onready var _size: Vector2 = get_viewport_rect().size

func _ready() -> void:
	get_viewport().size_changed.connect(func():
		_size = get_viewport_rect().size
		queue_redraw()
	)

func _draw() -> void:
	var neon := Color(GameTheme.NEON_CYAN, 0.3)
	var dim := Color(GameTheme.NEON_CYAN, 0.08)
	var bright := Color(GameTheme.NEON_CYAN, 0.5)

	draw_rect(Rect2(Vector2.ZERO, _size), dim, false, 3.0)
	draw_rect(Rect2(Vector2.ZERO, _size), neon, false, 1.0)

	var corner_len := 16.0
	var corner_off := 1.0
	var corners := [
		[Vector2(corner_off, corner_off), Vector2.RIGHT, Vector2.DOWN],
		[Vector2(_size.x - corner_off, corner_off), Vector2.LEFT, Vector2.DOWN],
		[Vector2(corner_off, _size.y - corner_off), Vector2.RIGHT, Vector2.UP],
		[Vector2(_size.x - corner_off, _size.y - corner_off), Vector2.LEFT, Vector2.UP],
	]
	for c in corners:
		var origin: Vector2 = c[0]
		var dir_a: Vector2 = c[1]
		var dir_b: Vector2 = c[2]
		draw_line(origin, origin + dir_a * corner_len, bright, 2.0, true)
		draw_line(origin, origin + dir_b * corner_len, bright, 2.0, true)
