class_name HUD
extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var lives_container: HBoxContainer = $LivesContainer
@onready var level_label: Label = $LevelLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var launch_prompt: Label = $LaunchPrompt
@onready var pause_label: Label = $PauseLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var level_complete_label: Label = $LevelCompleteLabel

@onready var level_intro_panel: Control = $LevelIntroPanel
@onready var level_intro_title: Label = $LevelIntroPanel/VBoxContainer/LevelIntroTitle
@onready var level_intro_subtitle: Label = $LevelIntroPanel/VBoxContainer/LevelIntroSubtitle
@onready var effect_list: VBoxContainer = $EffectList

@onready var lives_overflow: Label = $LivesContainer/LivesOverflow

var hearts: Array[Label] = []
var _effect_rows: Dictionary = {}
var _effect_tweens: Dictionary = {}
var _score_tween: Tween

func _ready() -> void:
	for child in lives_container.get_children():
		if child is Label and child != lives_overflow:
			hearts.append(child)

	game_over_label.visible = false
	pause_label.visible = false
	launch_prompt.visible = false
	high_score_label.visible = false
	level_complete_label.visible = false
	level_intro_panel.visible = false
	_clear_effect_rows()

	level_intro_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func sync(score_value: int, lives_value: int, level_value: int, high_score_value: int) -> void:
	update_score(score_value)
	update_lives(lives_value)
	update_level(level_value)
	update_high_score(high_score_value)

func update_score(new_score: int) -> void:
	score_label.text = "SCORE: %d" % new_score
	score_label.reset_size()
	score_label.pivot_offset = score_label.size / 2.0
	TweenHelper.kill_if_valid(_score_tween)
	_score_tween = create_tween()
	_score_tween.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.05)
	_score_tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.15)

func update_lives(new_lives: int) -> void:
	var lost := false
	for i in hearts.size():
		var was_visible := hearts[i].visible
		hearts[i].visible = i < new_lives
		if was_visible and not hearts[i].visible:
			lost = true
			hearts[i].visible = true
			var tw := create_tween()
			tw.tween_property(hearts[i], "scale", Vector2(1.5, 1.5), 0.1)
			tw.parallel().tween_property(hearts[i], "modulate:a", 0.0, 0.2)
			tw.tween_callback(func(): hearts[i].visible = false)
	if new_lives > hearts.size():
		lives_overflow.text = "+%d" % (new_lives - hearts.size())
		lives_overflow.visible = true
	else:
		lives_overflow.visible = false
	if not lost:
		for i in hearts.size():
			if hearts[i].visible:
				var tw := create_tween()
				tw.tween_property(hearts[i], "scale", Vector2(1.3, 1.3), 0.08)
				tw.tween_property(hearts[i], "scale", Vector2(1.0, 1.0), 0.15)

func update_level(new_level: int) -> void:
	var base_count := LevelDefs.base_levels().size()
	if new_level <= base_count:
		level_label.text = "LEVEL %d" % new_level
	else:
		level_label.text = "ENDLESS WAVE %d" % (new_level - base_count)

func update_high_score(value: int) -> void:
	if value > 0:
		high_score_label.text = "HIGH: %d" % value
		high_score_label.visible = true
	else:
		high_score_label.visible = false

func show_ready(show: bool) -> void:
	launch_prompt.visible = show

func show_pause(show: bool) -> void:
	pause_label.visible = show
	pause_label.process_mode = Node.PROCESS_MODE_ALWAYS if show else Node.PROCESS_MODE_INHERIT

func update_pause_text(score_value: int, level_value: int) -> void:
	pause_label.text = "PAUSED\nScore: %d\nLevel: %d\n\nPress ESC to Resume" % [score_value, level_value]

func show_game_over(show: bool, final_score: int = 0) -> void:
	game_over_label.visible = show
	if not show:
		return

	var high := SaveData.get_high_score()
	var new_high := final_score >= high and final_score > 0
	if new_high and high > 0:
		game_over_label.text = "GAME OVER\nScore: %d (NEW HIGH SCORE!)\nPress Confirm to Restart" % final_score
	elif high > 0:
		game_over_label.text = "GAME OVER\nScore: %d\nHigh Score: %d\nPress Confirm to Restart" % [final_score, high]
	else:
		game_over_label.text = "GAME OVER\nScore: %d\nPress Confirm to Restart" % final_score

func show_level_complete(show: bool, level: int = 0) -> void:
	level_complete_label.visible = show
	if show:
		level_complete_label.text = "LEVEL COMPLETED!"
		level_complete_label.add_theme_color_override("font_color", GameTheme.WARNING)
		level_complete_label.scale = Vector2(0.5, 0.5)
		level_complete_label.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(level_complete_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE)
		tw.parallel().tween_property(level_complete_label, "modulate:a", 1.0, 0.2)

func show_level_intro(title: String, subtitle: String = "") -> void:
	level_intro_title.text = "GO!"
	level_intro_title.add_theme_color_override("font_color", GameTheme.SUCCESS)
	level_intro_subtitle.text = ""
	level_intro_subtitle.visible = false
	level_intro_panel.modulate.a = 0.0
	level_intro_panel.visible = true
	level_intro_title.scale = Vector2(0.78, 0.78)
	level_intro_title.pivot_offset = level_intro_title.size * 0.5
	var tw := create_tween()
	tw.tween_property(level_intro_panel, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(level_intro_title, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_level_intro() -> void:
	var tw := create_tween()
	tw.tween_property(level_intro_panel, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): level_intro_panel.visible = false)

func set_effect_timer(effect_id: String, label_text: String, duration_sec: float, tint: Color = Color(GameTheme.ACCENT)) -> void:
	var row: Dictionary
	if _effect_rows.has(effect_id):
		row = _effect_rows[effect_id]
	else:
		row = _create_effect_row()
		effect_list.add_child(row.root)
		_effect_rows[effect_id] = row

	if _effect_tweens.has(effect_id):
		for t: Tween in _effect_tweens[effect_id]:
			if t and t.is_valid():
				t.kill()

	row.label.text = label_text
	row.label.modulate = tint
	row.bar.modulate = tint
	row.bar.max_value = duration_sec
	row.bar.value = duration_sec
	row.root.visible = true

	var val_tw := create_tween()
	val_tw.tween_property(row.bar, "value", 0.0, duration_sec)
	val_tw.tween_callback(func():
		clear_effect_timer(effect_id)
	)

	var result: Array[Tween] = [val_tw]
	if duration_sec > 2.0:
		var warn_tw := create_tween()
		warn_tw.tween_interval(duration_sec - 2.0)
		warn_tw.tween_property(row.bar, "modulate", Color(1.0, 0.7, 0.1), 0.3)
		result.append(warn_tw)
	_effect_tweens[effect_id] = result

func clear_effect_timer(effect_id: String) -> void:
	if not _effect_rows.has(effect_id):
		return
	var row = _effect_rows[effect_id]
	row.bar.modulate = Color.WHITE
	row.root.visible = false
	row.bar.value = 0.0
	if _effect_tweens.has(effect_id):
		for t: Tween in _effect_tweens[effect_id]:
			if t and t.is_valid():
				t.kill()
		_effect_tweens.erase(effect_id)

func clear_all_effect_timers() -> void:
	for effect_id in _effect_rows.keys():
		clear_effect_timer(effect_id)

func _clear_effect_rows() -> void:
	for child in effect_list.get_children():
		child.queue_free()
	_effect_rows.clear()
	_effect_tweens.clear()

func _create_effect_row() -> Dictionary:
	var root := HBoxContainer.new()
	root.visible = false
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.custom_minimum_size = Vector2(120, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 16)

	root.add_child(label)
	root.add_child(bar)

	return {
		"root": root,
		"label": label,
		"bar": bar,
	}

func show_context_prompt(text: String) -> void:
	# Reuse the launch_prompt node for contextual feedback
	launch_prompt.text = text
	launch_prompt.visible = true

func hide_context_prompt() -> void:
	launch_prompt.visible = false
	# Restore default text for next READY phase
	launch_prompt.text = "Press SPACE or Click to Launch"