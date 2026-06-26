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
	title_label.scale = Vector2(0.3, 0.3)
	title_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.2)
	tw.tween_property(score_label, "modulate:a", 1.0, 0.2).from(0.0)

	if high_score_label.visible:
		tw.tween_property(high_score_label, "modulate:a", 1.0, 0.2).from(0.0)

var _confetti_timer: Timer
var _confetti_palette: Array[Color] = [GameTheme.NEON_RED, GameTheme.NEON_LIME, GameTheme.NEON_CYAN, GameTheme.NEON_MAGENTA]

func _spawn_confetti() -> void:
	_confetti_timer = Timer.new()
	_confetti_timer.wait_time = 0.12
	_confetti_timer.timeout.connect(_spawn_confetti_piece)
	add_child(_confetti_timer)
	_confetti_timer.start()
	for _i in range(10):
		_spawn_confetti_piece()

func _spawn_confetti_piece() -> void:
	var color := _confetti_palette[randi() % _confetti_palette.size()]
	color.a = 0.8
	var rect := ColorRect.new()
	rect.size = Vector2(randf_range(6, 14), randf_range(10, 24))
	rect.color = color
	rect.position = Vector2(randf_range(0, get_viewport_rect().size.x), -20)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.rotation = randf_range(-0.5, 0.5)
	add_child(rect)
	var tw := create_tween()
	var fall_duration := randf_range(2.0, 4.5)
	tw.tween_property(rect, "position:y", get_viewport_rect().size.y + 20, fall_duration)
	tw.parallel().tween_property(rect, "position:x", rect.position.x + randf_range(-120, 120), fall_duration)
	tw.parallel().tween_property(rect, "rotation", rect.rotation + randf_range(-6.28, 6.28), fall_duration)
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
