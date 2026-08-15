extends Control

@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel

func _ready() -> void:
	ScreenTransition.fade_in()
	high_score_label.visible = false
	title_label.text = "YOU WIN!"
	var final_score := RunState.last_score
	score_label.text = "Score: %d" % final_score
	SaveData.save_high_score(final_score)
	var high := SaveData.get_high_score()
	if high > 0:
		high_score_label.text = "High Score: %d" % high
		high_score_label.visible = true
	prompt_label.text = "All 5 levels cleared!\nPress Confirm to start Endless Mode"

	_celebration_animation()
	_spawn_confetti()

func _celebration_animation() -> void:
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(0.85, 0.85)
	score_label.modulate.a = 0.0
	if high_score_label.visible:
		high_score_label.modulate.a = 0.0

	# Wait one frame for layout to settle so pivot_offset is accurate
	await get_tree().process_frame
	title_label.pivot_offset = title_label.size / 2.0

	var tw := create_tween()
	tw.tween_property(title_label, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(score_label, "modulate:a", 1.0, 0.35).from(0.0).set_trans(Tween.TRANS_SINE)
	if high_score_label.visible:
		tw.tween_property(high_score_label, "modulate:a", 1.0, 0.35).from(0.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.35).from(0.0).set_trans(Tween.TRANS_SINE)

var _confetti_timer: Timer
var _confetti_palette: Array[Color] = [GameTheme.ACCENT, GameTheme.SUCCESS]

func _spawn_confetti() -> void:
	_confetti_timer = Timer.new()
	_confetti_timer.wait_time = 0.45
	_confetti_timer.timeout.connect(_spawn_confetti_piece)
	add_child(_confetti_timer)
	_confetti_timer.start()
	for _i in range(5):
		_spawn_confetti_piece()

func _spawn_confetti_piece() -> void:
	var color := _confetti_palette[randi() % _confetti_palette.size()]
	color.a = 0.8
	var rect := ColorRect.new()
	rect.size = Vector2(randf_range(4, 8), randf_range(6, 16))
	rect.color = color
	rect.position = Vector2(randf_range(0, get_viewport_rect().size.x), -20)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.rotation = randf_range(-0.5, 0.5)
	add_child(rect)
	var tw := create_tween()
	var fall_duration := randf_range(3.0, 5.5)
	tw.tween_property(rect, "position:y", get_viewport_rect().size.y + 20, fall_duration)
	tw.parallel().tween_property(rect, "position:x", rect.position.x + randf_range(-60, 60), fall_duration)
	tw.parallel().tween_property(rect, "rotation", rect.rotation + randf_range(-3.14, 3.14), fall_duration)
	tw.tween_callback(rect.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _confetti_timer:
			_confetti_timer.stop()
		get_tree().quit()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("click"):
		start_endless()

func start_endless() -> void:
	if _confetti_timer:
		_confetti_timer.stop()
	RunState.start_level = LevelDefs.base_levels().size() + 1
	ScreenTransition.change_scene("res://main.tscn")
