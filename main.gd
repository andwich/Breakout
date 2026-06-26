extends Node2D

# Collision layers: 1=Paddle, 2=Ball, 3=Brick, 4=PowerUp, 5=LaserBeam, 6=Wall (layer bit 32)
# Ball collision_mask = 37 (1+4+32) = Paddle + Brick + Wall. Correct by design.

const BALL_SCENE := preload("res://entities/ball.tscn")
const BRICK_SCENE := preload("res://entities/brick.tscn")
const POWERUP_SCENE := preload("res://entities/powerup.tscn")
const _NO_POS := Vector2(-99999.0, -99999.0)

@onready var paddle: Paddle = $Paddle
@onready var balls_container: Node2D = $Balls
@onready var bricks_container: Node2D = $Bricks
@onready var powerups_container: Node2D = $PowerUps
@onready var laser_manager: LaserManager = $LaserManager
@onready var hud: HUD = $HUD
@onready var score_sfx: AudioStreamPlayer = $ScoreSfx

var level_builder := LevelBuilder.new()
var phase: GameState.Phase = GameState.Phase.LEVEL_INTRO
var score := 0
var lives := 3
var current_level := 1
var brick_count := 0
var _level_config: Dictionary = {}

var _slow_factor: float = 1.0
var _slow_timer: Timer
var _transitioning := false
var _drops_this_frame: int = 0
var _life_lost_pending := false
var _intro_gen: int = 0
var _restart_ready := false
var _intro_timer: SceneTreeTimer
var _combo_count: int = 0
var _combo_timer: Timer
var _combo_label: Label
var _shake_intensity: float = 0.0
var _shake_tween: Tween
var _base_position: Vector2
var _combo_tween: Tween
var _glow_tween: Tween
var _flash_overlay: ColorRect
var _slow_overlay: ColorRect

func _ready() -> void:
	_run_setup()
	var requested_level := RunState.start_level
	RunState.start_level = 1
	_start_new_run(requested_level)

func _run_setup() -> void:
	_base_position = position

	_setup_laser_manager()
	laser_manager.brick_scored.connect(_on_brick_hit)
	laser_manager.laser_fired.connect(AudioManager.play_laser_fire)

	paddle.set_sticky_release_callback(func(): return _is_phase_playing())

func _setup_laser_manager() -> void:
	if laser_manager == null:
		return
	laser_manager.set_paddle(paddle)
	laser_manager.set_can_fire_check(func(): return phase == GameState.Phase.PLAYING)

	var left_shape  := $LeftWall/CollisionShape2D.shape  as RectangleShape2D
	var right_shape := $RightWall/CollisionShape2D.shape as RectangleShape2D
	paddle.wall_left_x  = $LeftWall.position.x  + left_shape.size.x  / 2.0
	paddle.wall_right_x = $RightWall.position.x - right_shape.size.x / 2.0

	_slow_timer = Timer.new()
	_slow_timer.one_shot = true
	_slow_timer.timeout.connect(_restore_ball_speeds)
	add_child(_slow_timer)

	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	_combo_timer.wait_time = 0.6
	_combo_timer.timeout.connect(_reset_combo)
	add_child(_combo_timer)

	_combo_label = Label.new()
	_combo_label.visible = false
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 1.0))
	_combo_label.add_theme_font_size_override("font_size", 28)
	_combo_label.anchor_left = 0.5
	_combo_label.anchor_right = 0.5
	_combo_label.anchor_top = 0.3
	_combo_label.anchor_bottom = 0.3
	hud.add_child(_combo_label)

	_flash_overlay = ColorRect.new()
	_flash_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_flash_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.z_index = 1
	hud.add_child(_flash_overlay)

	_slow_overlay = ColorRect.new()
	_slow_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_slow_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_slow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slow_overlay.z_index = 0
	hud.add_child(_slow_overlay)

	_spawn_background_particles()

func start_new_run(start_level: int = 1) -> void:
	RunState.start_level = 1
	_start_new_run(start_level)

func _start_new_run(start_level: int = 1) -> void:
	score = 0
	lives = 3
	current_level = start_level
	_transitioning = false
	_life_lost_pending = false
	get_tree().paused = false
	_restore_ball_speeds()
	laser_manager.deactivate()
	_setup_laser_manager()
	paddle.position = _paddle_spawn_pos()
	paddle.set_process(true)
	paddle.set_physics_process(true)
	hud.sync(score, lives, current_level, SaveData.get_high_score())
	hud.show_ready(false)
	hud.show_pause(false)
	hud.show_game_over(false, 0)
	_load_level(current_level)

func _paddle_spawn_pos() -> Vector2:
	return Vector2(get_viewport_rect().size.x / 2.0, max(0.0, get_viewport_rect().size.y - 40.0))

func _load_level(level: int) -> void:
	_intro_gen += 1
	current_level = level
	_level_config = LevelDefs.config_for_level(current_level)
	laser_manager.deactivate()
	_setup_laser_manager()
	for child in laser_manager.get_children():
		if child is LaserBeam:
			child.queue_free()
	hud.clear_all_effect_timers()
	_slow_timer.stop()
	_slow_factor = 1.0
	for child in balls_container.get_children():
		child.queue_free()
	for child in bricks_container.get_children():
		child.queue_free()
	for child in powerups_container.get_children():
		child.queue_free()
	paddle.reset()
	paddle.position = _paddle_spawn_pos()
	paddle.set_process(true)
	paddle.set_physics_process(true)
	_spawn_bricks()
	_animate_brick_entrance()
	hud.update_level(current_level)
	_start_level_intro()

func _start_level_intro() -> void:
	_intro_gen += 1
	var my_gen := _intro_gen
	phase = GameState.Phase.LEVEL_INTRO
	hud.show_level_intro(_level_title_text(), _level_subtitle_text())
	await get_tree().create_timer(1.0).timeout
	if _intro_gen != my_gen:
		return
	if not is_instance_valid(self) or not is_inside_tree():
		return
	hud.hide_level_intro()
	_begin_ready_phase()

func _begin_ready_phase() -> void:
	_spawn_ball()
	phase = GameState.Phase.READY
	paddle.show_aim = true
	hud.show_ready(true)

func _launch_waiting_ball() -> void:
	var waiting_ball := _get_waiting_ball()
	if waiting_ball == null:
		return
	paddle.show_aim = false
	waiting_ball.launch(Vector2.UP, paddle.aim_angle)
	phase = GameState.Phase.PLAYING
	AudioManager.play_launch()
	hud.show_ready(false)

func _reset_round_after_life_loss() -> void:
	paddle.position = _paddle_spawn_pos()
	paddle.set_process(true)
	paddle.set_physics_process(true)
	_spawn_ball()
	phase = GameState.Phase.READY
	paddle.show_aim = true
	hud.show_ready(true)

func _spawn_bricks() -> void:
	brick_count = level_builder.build_level(
		bricks_container,
		BRICK_SCENE,
		get_viewport_rect().size,
		_level_config,
		_on_brick_destroyed
	)

func _spawn_ball(at: Vector2 = _NO_POS) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	if at == _NO_POS:
		at = paddle.global_position + Vector2(0, -paddle.get_ball_attach_offset())
	ball.position = at
	ball.speed = ball.base_speed * _level_config["speed_mult"] * _slow_factor
	ball.set_paddle(paddle)
	_setup_laser_manager()
	ball.life_lost.connect(_on_ball_lost)
	ball.brick_hit.connect(_on_brick_hit)
	ball.paddle_hit.connect(_on_ball_paddle_hit)
	balls_container.add_child(ball)
	return ball

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		AudioManager.toggle_mute()
		return

	if get_tree().paused:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("click"):
		match phase:
			GameState.Phase.READY:
				_launch_waiting_ball()
			GameState.Phase.GAME_OVER:
				if _restart_ready:
					_restart_run()
			GameState.Phase.VICTORY:
				pass

func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		if _get_waiting_ball() != null:
			phase = GameState.Phase.READY
			paddle.show_aim = true
		else:
			phase = GameState.Phase.PLAYING
		hud.show_pause(false)
		return

	if phase in [GameState.Phase.GAME_OVER, GameState.Phase.VICTORY, GameState.Phase.LEVEL_INTRO, GameState.Phase.ROUND_CLEAR]:
		return
	if _transitioning:
		return

	get_tree().paused = true
	phase = GameState.Phase.PAUSED
	hud.update_pause_text(score, current_level)
	hud.show_pause(true)

func _on_brick_hit(points: int) -> void:
	if phase != GameState.Phase.PLAYING:
		return
	_combo_count = mini(_combo_count + 1, 15)
	_combo_timer.start()
	var combo_bonus := 0
	if _combo_count >= 3:
		combo_bonus = mini(_combo_count - 2, 10) * 5
		_show_combo(_combo_count, combo_bonus)
	score += points + combo_bonus
	hud.update_score(score)
	AudioManager.play_brick_hit(1.0 + _combo_count * 0.08)

func _on_brick_destroyed(pos: Vector2, drop_chance: float, point_value: int) -> void:
	if _transitioning:
		return
	brick_count = max(0, brick_count - 1)

	_spawn_score_popup(pos, point_value)
	_spawn_powerup(pos, drop_chance)
	_shake_camera(3.0, 0.08)

	if brick_count <= 0:
		_resolve_round_clear()

func _resolve_round_clear() -> void:
	if phase != GameState.Phase.PLAYING or _transitioning:
		return

	phase = GameState.Phase.ROUND_CLEAR
	_transitioning = true
	laser_manager.deactivate()
	paddle.show_aim = false
	hud.show_level_complete(true, current_level)
	AudioManager.play_level_complete()
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	hud.show_level_complete(false)

	var is_last_story_level := (current_level == LevelDefs.base_levels().size()
		and RunState.start_level <= LevelDefs.base_levels().size())
	if is_last_story_level:
		RunState.last_score = score
		phase = GameState.Phase.VICTORY
		_intro_gen += 1
		for b in balls_container.get_children():
			if b is Ball:
				b.set_physics_process(false)
		if ScreenTransition._busy:
			push_warning("ScreenTransition busy; victory scene not loaded")
		else:
			ScreenTransition.change_scene("res://ui/victory.tscn")
		return

	_transitioning = false
	_load_level(current_level + 1)

func _on_ball_paddle_hit() -> void:
	_shake_camera(1.5, 0.04)
	AudioManager.play_paddle_hit()

func _on_ball_lost() -> void:
	if phase in [GameState.Phase.GAME_OVER, GameState.Phase.ROUND_CLEAR, GameState.Phase.LEVEL_INTRO, GameState.Phase.READY, GameState.Phase.VICTORY, GameState.Phase.TITLE, GameState.Phase.PAUSED]:
		return
	if _has_active_ball():
		return
	if _life_lost_pending:
		return
	_life_lost_pending = true
	call_deferred("_process_life_loss")


func _process_life_loss() -> void:
	_life_lost_pending = false
	lives = max(0, lives - 1)
	hud.update_lives(lives)
	AudioManager.play_life_lost()
	if _flash_overlay:
		var tw := create_tween()
		tw.tween_property(_flash_overlay, "color:a", 0.25, 0.05)
		tw.tween_property(_flash_overlay, "color:a", 0.0, 0.2)
	if lives <= 0:
		_enter_game_over()
		return
	_reset_round_after_life_loss()

func _enter_game_over() -> void:
	phase = GameState.Phase.GAME_OVER
	SaveData.save_high_score(score)
	hud.show_game_over(true, score)
	AudioManager.play_game_over()
	_restart_ready = false
	ScreenTransition._busy = false
	get_tree().create_timer(1.0).timeout.connect(func(): _restart_ready = true, CONNECT_ONE_SHOT)

	paddle.set_process(false)
	paddle.set_physics_process(false)
	for b in balls_container.get_children():
		if b is Ball:
			b.set_process(false)
			b.set_physics_process(false)

func _restart_run() -> void:
	start_new_run(1)

func _get_waiting_ball() -> Ball:
	for child in balls_container.get_children():
		if child is Ball and not child.launched:
			return child
	return null

func _has_active_ball() -> bool:
	for child in balls_container.get_children():
		if child is Ball and child.launched:
			return true
	return false

func _level_title_text() -> String:
	var authored := str(_level_config.get("name", ""))
	var defs_count := LevelDefs.base_levels().size()
	var prefix := "LEVEL %d  ·  " % current_level if current_level <= defs_count \
		else "WAVE %d  ·  " % (current_level - defs_count)
	if authored.is_empty():
		if current_level <= defs_count:
			return "LEVEL %d" % current_level
		return "ENDLESS WAVE %d" % (current_level - defs_count)
	return (prefix + authored).to_upper()


func _level_subtitle_text() -> String:
	return str(_level_config.get("intro_text", ""))

func _animate_brick_entrance() -> void:
	var i := 0
	for brick in bricks_container.get_children():
		if brick is Brick:
			var orig_y := brick.position.y
			brick.position.y -= 20
			var tw := create_tween()
			tw.tween_property(brick, "position:y", orig_y, 0.2).set_delay(i * 0.015).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			i += 1

func _spawn_powerup(pos: Vector2, drop_chance: float) -> void:
	if randf() >= drop_chance:
		return
	if _drops_this_frame >= 2:
		return
	_drops_this_frame += 1
	var p := POWERUP_SCENE.instantiate() as PowerUp
	p.position = pos
	p.power_type = LevelDefs.pick_powerup_for_level(current_level)
	p.fall_speed = 120.0 + max(0, current_level - 5) * 10.0
	p.collected.connect(_on_powerup_collected)
	powerups_container.add_child(p)

func _on_powerup_collected(ptype: PowerUp.Type, duration: float) -> void:
	if phase != GameState.Phase.PLAYING:
		return
	_shake_camera(2.0, 0.05)
	AudioManager.play_powerup()
	_flash_effect(paddle.global_position, PowerUpRegistry.color_for(ptype), 40.0)
	match ptype:
		PowerUp.Type.MULTIBALL:
			const MAX_BALLS := 6
			var active: Array[Ball] = []
			for b in balls_container.get_children():
				if b is Ball and b.launched:
					active.append(b)

			var slots := MAX_BALLS - active.size()
			for original in active:
				for _i in range(2):
					if slots <= 0:
						break
					var clone := _spawn_ball(original.position)
					clone.ball_color = GameTheme.NEON_MAGENTA
					clone.launched = true
					var rotated := original.velocity.rotated(deg_to_rad(
						randf_range(25, 45) * (1 if randi() % 2 == 0 else -1)))
					# clone.speed is already the slowed value when slow is active (_spawn_ball applies it).
					# Using clone.speed here (not original.speed) is intentional.
					clone.velocity = rotated.normalized() * clone.speed
					slots -= 1

		PowerUp.Type.BIG_PADDLE:
			paddle.apply_big_paddle(duration)
			hud.set_effect_timer(PowerUpRegistry.effect_id_for(ptype), PowerUpRegistry.hud_label_for(ptype), duration, PowerUpRegistry.color_for(ptype))

		PowerUp.Type.STICKY:
			paddle.enable_sticky(duration)
			hud.set_effect_timer(PowerUpRegistry.effect_id_for(ptype), PowerUpRegistry.hud_label_for(ptype), duration, PowerUpRegistry.color_for(ptype))

		PowerUp.Type.LASER:
			_setup_laser_manager()
			laser_manager.activate(duration)
			hud.set_effect_timer(PowerUpRegistry.effect_id_for(ptype), PowerUpRegistry.hud_label_for(ptype), duration, PowerUpRegistry.color_for(ptype))

		PowerUp.Type.SLOW_BALLS:
			_apply_slow_balls(duration)

		PowerUp.Type.EXTRA_LIFE:
			lives += 1
			hud.update_lives(lives)

func _spawn_background_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 6.0
	particles.one_shot = false
	particles.local_coords = false
	particles.z_index = -1
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 20.0
	mat.direction = Vector3.DOWN
	mat.spread = 180.0
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	var pc := GameTheme.NEON_CYAN
	pc.a = 0.08
	mat.color = pc
	mat.lifetime_randomness = 0.5
	particles.process_material = mat
	particles.position = get_viewport_rect().size / 2.0
	add_child(particles)

func _reset_combo() -> void:
	_combo_count = 0
	if _combo_label and _combo_label.visible:
		if _combo_tween and _combo_tween.is_valid():
			_combo_tween.kill()
		_combo_tween = create_tween()
		_combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 0.3)
		_combo_tween.tween_callback(func(): _combo_label.visible = false)

func _show_combo(count: int, bonus: int) -> void:
	if not _combo_label:
		return
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_label.text = "COMBO x%d  +%d" % [count, bonus]
	_combo_label.modulate = Color(1.0, 0.8, 0.2, 1.0) if count < 6 else Color(1.0, 0.3, 0.3, 1.0)
	_combo_label.add_theme_font_size_override("font_size", mini(28 + count * 2, 48))
	_combo_label.visible = true
	_combo_label.modulate.a = 1.0
	_combo_label.scale = Vector2(1.4, 1.4)
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE)
	_combo_tween.parallel().tween_property(_combo_label, "modulate:a", 0.0, 0.5).set_delay(0.3)

func _shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = minf(_shake_intensity + intensity, 8.0)
	if _shake_tween and _shake_tween.is_valid():
		return
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(t):
		var decay := 1.0 - t
		position = _base_position + Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity)) * decay
	, 0.0, 1.0, duration)
	_shake_tween.tween_callback(func(): position = _base_position; _shake_intensity = 0.0)

func _flash_effect(at: Vector2, color: Color, size: float = 20.0) -> void:
	var ring := RingEffect.new()
	add_child(ring)
	ring.play(at, color, size, 3.0, 0.3)

func _apply_slow_balls(duration: float) -> void:
	_slow_factor = 0.6
	for b in balls_container.get_children():
		if b is Ball:
			b.speed = b.base_speed * _level_config["speed_mult"] * _slow_factor
			if b.launched and b.velocity.length_squared() > 1.0:
				b.velocity = b.velocity.normalized() * b.speed
	_slow_timer.start(duration)
	hud.set_effect_timer(PowerUpRegistry.effect_id_for(PowerUp.Type.SLOW_BALLS), PowerUpRegistry.hud_label_for(PowerUp.Type.SLOW_BALLS), duration, PowerUpRegistry.color_for(PowerUp.Type.SLOW_BALLS))
	if _slow_overlay:
		var tw := create_tween()
		tw.tween_property(_slow_overlay, "color:a", 0.12, 0.2)

func _restore_ball_speeds() -> void:
	hud.clear_effect_timer(PowerUpRegistry.effect_id_for(PowerUp.Type.SLOW_BALLS))
	_slow_factor = 1.0
	for b in balls_container.get_children():
		if b is Ball:
			b.speed = b.base_speed * _level_config["speed_mult"]
			if b.launched and b.velocity.length_squared() > 1.0:
				b.velocity = b.velocity.normalized() * b.speed
	if _slow_overlay:
		var tw := create_tween()
		tw.tween_property(_slow_overlay, "color:a", 0.0, 0.2)

func _spawn_score_popup(world_pos: Vector2, value: int) -> void:
	var stable_pos := world_pos - (position - _base_position)
	var label := Label.new()
	label.text = "+%d" % value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6, 1.0))
	label.modulate.a = 1.0
	var screen_pos := get_viewport().get_canvas_transform() * stable_pos
	label.position = screen_pos - Vector2(0, 20)
	hud.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", screen_pos.y - 50, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tw.tween_callback(label.queue_free)

func _physics_process(_delta: float) -> void:
	_drops_this_frame = 0

func _get_phase() -> GameState.Phase:
	return phase

func _is_phase_playing() -> bool:
	return phase == GameState.Phase.PLAYING
