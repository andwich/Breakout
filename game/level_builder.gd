class_name LevelBuilder
extends RefCounted

const BRICK_W := 60
const BRICK_H := 24
const BRICK_PAD := 4
const START_Y := 40.0

func build_level(container: Node, brick_scene: PackedScene, viewport_size: Vector2, config: Dictionary, on_destroyed: Callable) -> int:
	var cols: int = config["cols"]
	var rows: int = config["rows"]
	var total_w := float(cols * (BRICK_W + BRICK_PAD) - BRICK_PAD)
	var start_x := (viewport_size.x - total_w) / 2.0
	var count := 0

	for row in range(rows):
		for col in range(cols):
			var brick := brick_scene.instantiate() as Brick
			brick.position = Vector2(start_x + col * (BRICK_W + BRICK_PAD), START_Y + row * (BRICK_H + BRICK_PAD))
			_configure_brick(brick, row, col, rows, config)
			brick.destroyed.connect(on_destroyed)
			container.add_child(brick)
			count += 1

	return count

const ROW_COLORS := [
	Color(1.0, 0.1, 0.1),   # row 0 — red
	Color(1.0, 0.5, 0.1),   # row 1 — orange
	Color(1.0, 1.0, 0.2),   # row 2 — yellow
	Color(GameTheme.SUCCESS),   # row 3 — lime
	Color(GameTheme.ACCENT),    # row 4 — cyan
	Color(0.3, 0.5, 1.0),       # row 5 — blue
	Color(GameTheme.BRICK_BOSS),# row 6 — purple
	Color(GameTheme.INFO),      # row 7 — magenta
	Color(0.9, 0.9, 0.9),   # row 8 — white
	Color(0.6, 1.0, 0.8),   # row 9 — mint
]

func _configure_brick(brick: Brick, row: int, col: int, total_rows: int, config: Dictionary) -> void:
	var hp := 1
	var drop := float(config.get("drop_chance", 0.25))
	var is_boss := false
	var brick_type := "standard"
	var cols: int = config.get("cols", 8)

	if config.get("boss_hp", 0) > 0 and row == 0 and (col == cols / 2 or col == cols / 2 - 1):
		hp = config["boss_hp"]
		drop = minf(0.6, drop + 0.2)
		is_boss = true
		brick_type = "boss"
	elif config.get("metal_hp", 0) > 0 and row <= 1:
		hp = config["metal_hp"]
		drop = minf(0.6, drop + 0.1)
		brick_type = "metal"

	brick.max_hp = hp
	brick.point_value = (total_rows - row) * 10 * hp
	brick.is_boss = is_boss
	brick.brick_type = brick_type
	brick.drop_chance = drop

	brick.row_color = ROW_COLORS[row % ROW_COLORS.size()]
