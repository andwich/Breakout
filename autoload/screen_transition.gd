extends CanvasLayer

var _overlay: ColorRect
var _busy := false
var _fade_tween: Tween
var _guard_timer: float = 0.0
const _GUARD_TIMEOUT: float = 5.0

func is_busy() -> bool:
	return _busy

func _replace_fade_tween() -> Tween:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	return _fade_tween

func force_reset() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
	_busy = false
	_guard_timer = 0.0
	_reset_overlay_state()

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
	var tween := _replace_fade_tween()
	tween.tween_property(_overlay, "color:a", 0.0, duration).from(1.0)
	await tween.finished

func fade_out(duration: float = 0.3) -> void:
	var tween := _replace_fade_tween()
	tween.tween_property(_overlay, "color:a", 1.0, duration).from(0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await tween.finished

func change_scene(path: String, fade_duration: float = 0.3) -> void:
	if _busy:
		return

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("ScreenTransition: cannot load scene: %s" % path)
		force_reset()
		return

	_busy = true
	_guard_timer = 0.0

	await fade_out(fade_duration)

	var result: Error = get_tree().change_scene_to_packed(packed)
	if result != OK:
		push_error("ScreenTransition: failed to change to %s (error %s)" % [path, result])
		force_reset()
		return

	await get_tree().process_frame
	await fade_in(fade_duration)

	_busy = false
	_guard_timer = 0.0
	_reset_overlay_state()
