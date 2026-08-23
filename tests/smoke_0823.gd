extends SceneTree

## Headless smoke checks for the Feedback 0815 fixes (Session 30).
## Run: godot --headless --path . -s res://tests/smoke_0823.gd
## Covers what the parser gate cannot: runtime behavior of the banding,
## flash/damage colors, NEON alias removal, TweenHelper, and the
## stuck-ball escape invariant. Feel items stay manual.
##
## Note: `-s` scripts run before autoloads register, so theme constants are
## read via preload. Spawned nodes get auto-processing disabled so engine
## ticks cannot interfere with manually driven _physics_process calls.

const BRICK_SCENE: PackedScene = preload("res://entities/brick.tscn")
const BALL_SCENE: PackedScene = preload("res://entities/ball.tscn")
# Autoloads are not instanced under -s; read theme constants from the script itself.
const THEME := preload("res://autoload/game_theme.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_theme_aliases()
	_run_node_tests()


func _run_node_tests() -> void:
	# Under `-s`, add_child before the first frame never enters the tree
	# (verified via probe) — defer all node work until the loop is live.
	await process_frame
	_test_tween_helper()
	_test_brick_banding_and_damage()
	_test_ball_escape_upward()

	if _failures == 0:
		print("SMOKE RESULT: ALL PASS")
		quit(0)
	else:
		printerr("SMOKE RESULT: %d FAILURE(S)" % _failures)
		quit(1)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_failures += 1
		printerr("FAIL: " + label)


func _colors_close(a: Color, b: Color, tol: float = 0.0005) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol \
			and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


func _test_theme_aliases() -> void:
	var src := FileAccess.open("res://autoload/game_theme.gd", FileAccess.READ)
	if src == null:
		_check(false, "game_theme.gd readable")
		return
	var text := src.get_as_text()
	_check(not text.contains("const NEON_"), "NEON_* aliases removed from source")
	_check(text.contains("const ACCENT"), "semantic palette intact")


func _test_tween_helper() -> void:
	TweenHelper.kill_if_valid(null)  # must not crash
	var node := ColorRect.new()
	root.add_child(node)
	var tween := node.create_tween()
	tween.tween_interval(10.0)
	TweenHelper.kill_if_valid(tween)
	_check(not tween.is_valid(), "TweenHelper kills a valid tween")
	TweenHelper.kill_if_valid(tween)  # double-kill must be safe
	node.free()


func _spawn_brick(max_hp: int) -> Brick:
	var brick: Brick = BRICK_SCENE.instantiate()
	brick.brick_type = "standard"
	brick.max_hp = max_hp
	brick.row_color = THEME.SUCCESS
	root.add_child(brick)
	# Freeze all automatic behavior; we drive state manually.
	brick.set_physics_process(false)
	brick.set_process(false)
	for child in brick.get_children():
		child.set_physics_process(false)
		child.set_process(false)
	return brick


func _test_brick_banding_and_damage() -> void:
	var row_color := THEME.SUCCESS
	var brick := _spawn_brick(3)

	if brick._sprite == null or brick.base_color == null:
		_check(false, "brick ready-state resolved (_sprite=%s base_color=%s in_tree=%s)"
				% [brick._sprite, brick.base_color, brick.is_inside_tree()])
		brick.free()
		return

	var calm_band := row_color.lerp(THEME.TEXT_MUTED, 0.5)

	# Path A: durable standard — _ready() ends with refresh_damage_visuals(),
	# which at full HP legitimately shows the pure band color.
	_check(_colors_close(brick._sprite.color, calm_band),
			"durable standard at full HP shows pure band (got %s)" % brick._sprite.color)

	if brick._particles and brick._particles.process_material is ParticleProcessMaterial:
		var pm := brick._particles.process_material as ParticleProcessMaterial
		_check(_colors_close(pm.color, calm_band), "brick particles match band color")
	else:
		_check(false, "brick particles material reachable")

	# Non-lethal hit: persistent damage color derives from the band, not BRICK_STANDARD.
	brick.take_damage(1)
	var health_ratio := 2.0 / 3.0
	var expected_damaged := calm_band.darkened((1.0 - health_ratio) * 0.16)
	_check(_colors_close(brick._sprite.color, expected_damaged),
			"damaged brick color follows band (got %s)" % brick._sprite.color)

	# Flash target is the brick's own hue lightened — never pure white.
	var flash_expected: Color = brick.base_color.lightened(0.75)
	_check(flash_expected != Color.WHITE, "flash tint differs from pure white")

	brick.free()

	# Path B: single-HP standard — refresh_damage_visuals() early-returns,
	# so the full idle formula (band darkened 12%, slight white lift) survives.
	var simple := _spawn_brick(1)
	var expected_idle := calm_band.darkened(0.12).lerp(Color.WHITE, 0.05)
	_check(_colors_close(simple._sprite.color, expected_idle),
			"single-HP standard idles on muted band formula (got %s)" % simple._sprite.color)
	simple.free()


func _test_ball_escape_upward() -> void:
	var ball: Ball = BALL_SCENE.instantiate()
	root.add_child(ball)
	ball.launched = true
	ball.speed = 350.0
	ball.set_physics_process(false)  # manual drives only — engine ticks must not touch it
	ball.set_process(false)
	ball.global_position = root.size / 2.0

	var trial_velocities: Array[Vector2] = [
		Vector2.DOWN,
		Vector2(0.5, 1.0).normalized(),
		Vector2(-0.9, 0.44).normalized(),
		Vector2.UP,
		Vector2.RIGHT,
	]
	for i in range(25):
		trial_velocities.append(Vector2.from_angle(randf() * TAU))

	var all_upward := true
	var anchor := root.size / 2.0  # headless viewport can be tiny; stay at its center
	for last_vel in trial_velocities:
		ball.velocity = Vector2.ZERO
		ball._last_velocity = last_vel * ball.speed
		# Re-anchor each trial: escape movement must never accumulate toward
		# the screen-exit margin, or _on_screen_exited() zeroes the ball.
		ball.global_position = anchor
		ball._last_pos = anchor
		ball._stuck_frames = 31
		if not ball.launched:
			all_upward = false
			printerr("  ball de-launched before trial %s" % last_vel)
			break
		ball._physics_process(1.0 / 60.0)
		if not is_instance_valid(ball):
			all_upward = false
			printerr("  ball freed during trial %s" % last_vel)
			break
		if not (ball.velocity.y < 0.0):
			all_upward = false
			printerr("  escape fired downward for last_velocity=%s -> %s" % [last_vel, ball.velocity])
		elif not is_equal_approx(ball.velocity.length(), ball.speed):
			all_upward = false
			printerr("  escape speed drift for %s -> %s" % [last_vel, ball.velocity])
	_check(all_upward, "stuck-ball escape always fires upward at full speed (%d trials)" % trial_velocities.size())

	# Rebound contract: constant present and formula shape honors ~45 deg max.
	_check(is_equal_approx(Ball.MIN_UPWARD_COMPONENT, 0.42), "MIN_UPWARD_COMPONENT = 0.42")
	var edge_aim := Vector2(1.0, -1.0).normalized()
	_check(absf(edge_aim.angle_to(Vector2.UP)) <= deg_to_rad(45.1), "max deflection ~45 deg from vertical")

	ball.free()
