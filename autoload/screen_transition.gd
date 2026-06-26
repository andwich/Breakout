extends CanvasLayer

var _overlay: ColorRect
var _busy := false
var _guard_timer: float = 0.0
const _GUARD_TIMEOUT: float = 5.0

func _process(delta: float) -> void:
	if _busy:
		_guard_timer += delta
		if _guard_timer > _GUARD_TIMEOUT:
			_busy = false
			_guard_timer = 0.0
			_reset_overlay_state()

func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_reset_overlay_state()

func _reset_overlay_state() -> void:
	if _overlay == null:
		return
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_in(duration: float = 0.3) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _overlay.color.a < 0.05:
		return
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, duration).from(1.0)
	await tween.finished

func fade_out(duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, duration).from(0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await tween.finished

func change_scene(path: String, fade_duration: float = 0.3) -> void:
	if _busy:
		return
	_busy = true
	_guard_timer = 0.0
	await fade_out(fade_duration)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await fade_in(fade_duration)
	_busy = false
	_guard_timer = 0.0
	_reset_overlay_state()
