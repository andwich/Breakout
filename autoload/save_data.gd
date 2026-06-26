extends Node

const SAVE_PATH := "user://breakout_save.json"

func get_high_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) == TYPE_DICTIONARY and data.has("high_score"):
		return int(data["high_score"])
	return 0

func save_high_score(score: int) -> void:
	var current := get_high_score()
	if score <= current:
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"high_score": score}))
