extends Node

const SAVE_PATH := "user://breakout_save.json"

func get_high_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not read save file from: " + SAVE_PATH)
		return 0

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("high_score"):
		return max(0, int(parsed["high_score"]))
	return 0

func save_high_score(score: int) -> void:
	var current := get_high_score()
	if score <= current:
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file to: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify({"high_score": score}))
	file.close()
