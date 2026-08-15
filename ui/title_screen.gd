extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var powerup_legend_container: VBoxContainer = $VBoxContainer/PowerupLegendContainer
@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var controls_label: Label = $VBoxContainer/ControlsLabel

func _ready() -> void:
	_spawn_bg_particles()
	ScreenTransition.fade_in()

	var high := SaveData.get_high_score()
	high_score_label.visible = high > 0
	if high > 0:
		high_score_label.text = "HIGH SCORE: %d" % high

	var all_types := PowerUpRegistry.all_types()
	var left_types := all_types.slice(0, 3)
	var right_types := all_types.slice(3, 6)
	for i in range(maxi(left_types.size(), right_types.size())):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 24)
		var left_type: Variant = left_types[i] if i < left_types.size() else null
		var right_type: Variant = right_types[i] if i < right_types.size() else null
		for t in [left_type, right_type]:
			if t == null:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(120, 0)
				row.add_child(spacer)
				continue
			var hbox := HBoxContainer.new()
			hbox.custom_minimum_size = Vector2(120, 0)
			var icon := PowerUpRegistry.icon_for(t)
			var display_name := PowerUpRegistry.display_name_for(t)
			var semantic := Color(PowerUpRegistry.color_for(t), 0.7)
			var icon_label := Label.new()
			icon_label.text = icon
			icon_label.add_theme_color_override("font_color", semantic)
			icon_label.add_theme_font_size_override("font_size", 14)
			var name_label := Label.new()
			name_label.text = display_name
			name_label.add_theme_color_override("font_color", semantic)
			name_label.add_theme_font_size_override("font_size", 14)
			hbox.add_child(icon_label)
			hbox.add_child(name_label)
			row.add_child(hbox)
		powerup_legend_container.add_child(row)

	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(prompt_label, "modulate:a", 0.35, 0.6)
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.6)

	_title_glow()

var _title_glow_tween: Tween

func _title_glow() -> void:
	# Calm "breathing" pulse: slow gentle alpha fade on one primary color,
	# no hue shifting.
	_title_glow_tween = create_tween().set_loops()
	_title_glow_tween.set_trans(Tween.TRANS_SINE)
	_title_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_title_glow_tween.tween_property(title_label, "modulate:a", 0.72, 1.8)
	_title_glow_tween.tween_property(title_label, "modulate:a", 1.0, 1.8)

func _spawn_bg_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 5.0
	particles.one_shot = false
	particles.local_coords = false
	particles.position = get_viewport_rect().size / 2.0
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 15.0
	mat.direction = Vector3.DOWN
	mat.spread = 180.0
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	var pc := Color(0.2, 0.25, 0.4, 1.0)
	pc.a = 0.06
	mat.color = pc
	mat.lifetime_randomness = 0.5
	particles.process_material = mat
	add_child(particles)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("click"):
		_start_game()

func _start_game() -> void:
	if _title_glow_tween and _title_glow_tween.is_valid():
		_title_glow_tween.kill()
	RunState.reset()
	RunState.start_level = 1
	ScreenTransition.change_scene("res://main.tscn")
