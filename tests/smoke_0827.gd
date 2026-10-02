extends Node

## Headless smoke checks for the Feedback 0827 fixes (Session 31).
##
## Run: godot --headless --path . res://tests/smoke_0827.tscn
##      (exits 0 on success, 1 on any failure)
##
## Why a scene and not `-s`: `-s` scripts run before autoload named-globals are
## registered, so `hud.gd` (SaveData) and `main.gd` (RunState) fail to *compile*
## and their scenes cannot be loaded. Running as a scene gives the same headless
## determinism plus real Fix 1 (HUD hearts) and Fix 4 (combo window) coverage.
##
## Covers: boss health-bar width contract, metal progressive darkening, cached WAV
## synthesis, tweened paddle width (visual_width), registry durations, and the
## slow-factor-scaled combo window. Manual feel checks stay in the retro doc.

const BRICK_SCENE: PackedScene = preload("res://entities/brick.tscn")
const PADDLE_SCENE: PackedScene = preload("res://entities/paddle.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const AUDIO_SCRIPT := preload("res://autoload/audio_manager.gd")
const THEME := preload("res://autoload/game_theme.gd")

const METAL_BASE := Color(0.7, 0.7, 0.9)
const BOSS_BAR_WIDTH := 40.0

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	await _run_all()
	if _failures == 0:
		print("SMOKE 0827 RESULT: ALL PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		printerr("SMOKE 0827 RESULT: %d FAILURE(S) / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _run_all() -> void:
	# Structural (no frames required).
	_test_registry_durations()
	_test_no_hardcoded_duration_defaults()
	_test_combo_window_source_contract()
	# Runtime.
	_test_boss_health_bar()
	_test_metal_darkening()
	_test_audio_wav_cache()
	await _test_hud_level_intro()
	await _test_hud_heart_restore()
	await _test_paddle_width_tween()
	await _test_combo_timer_runtime()


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("PASS: " + label)
	else:
		_failures += 1
		printerr("FAIL: " + label)


func _colors_close(a: Color, b: Color, tol: float = 0.0005) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol \
			and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_check(false, "%s readable" % path)
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## Body of `func <name>(...)` up to the next top-level `func `.
func _func_body(path: String, func_name: String) -> String:
	var text := _source(path)
	var start := text.find("func %s(" % func_name)
	if start < 0:
		_check(false, "%s defines %s()" % [path, func_name])
		return ""
	var next := text.find("\nfunc ", start + 1)
	if next < 0:
		return text.substr(start)
	return text.substr(start, next - start)


# ---------------------------------------------------------------------------
# Fix 6 — differentiated power-up durations
# ---------------------------------------------------------------------------

func _test_registry_durations() -> void:
	var types: Array[PowerUp.Type] = [
		PowerUp.Type.BIG_PADDLE, PowerUp.Type.STICKY,
		PowerUp.Type.LASER, PowerUp.Type.SLOW_BALLS,
	]
	var expected: Array[float] = [8.0, 10.0, 6.0, 6.0]
	var distinct: Dictionary = {}
	for i in range(types.size()):
		var got := PowerUpRegistry.duration_for(types[i])
		distinct[got] = true
		_check(is_equal_approx(got, expected[i]),
			"%s duration = %.1fs (got %.1fs)" % [PowerUpRegistry.hud_label_for(types[i]), expected[i], got])
	_check(PowerUpRegistry.duration_for(PowerUp.Type.MULTIBALL) == 0.0, "MULTIBALL stays untimed")
	_check(PowerUpRegistry.duration_for(PowerUp.Type.EXTRA_LIFE) == 0.0, "EXTRA_LIFE stays untimed")
	_check(distinct.size() >= 3,
		"timed durations are differentiated (%d distinct values)" % distinct.size())


# ---------------------------------------------------------------------------
# Fix 7 — no hardcoded duration defaults in effect entry points
# ---------------------------------------------------------------------------

func _test_no_hardcoded_duration_defaults() -> void:
	var paddle_body := _func_body("res://entities/paddle.gd", "apply_big_paddle")
	_check(paddle_body.contains("func apply_big_paddle(duration_sec: float)"),
		"apply_big_paddle() has no default duration")
	var sticky_body := _func_body("res://entities/paddle.gd", "enable_sticky")
	_check(sticky_body.contains("func enable_sticky(duration_sec: float)"),
		"enable_sticky() has no default duration")
	var laser_body := _func_body("res://entities/laser_manager.gd", "activate")
	_check(laser_body.contains("func activate(duration_sec: float)"),
		"LaserManager.activate() has no default duration")
	_check(not _source("res://entities/paddle.gd").contains("duration_sec: float = "),
		"paddle.gd free of hardcoded duration defaults")
	_check(not _source("entities/laser_manager.gd").contains("duration_sec: float = "),
		"laser_manager.gd free of hardcoded duration defaults")
	# Registry remains the single source: caller passes it straight through.
	var main_src := _source("res://main.gd")
	_check(main_src.contains("paddle.apply_big_paddle(duration)"),
		"main.gd passes registry duration into apply_big_paddle()")
	_check(main_src.contains("laser_manager.activate(duration)"),
		"main.gd passes registry duration into activate()")


# ---------------------------------------------------------------------------
# Fix 4 — combo window scales with _slow_factor
# ---------------------------------------------------------------------------

func _test_combo_window_source_contract() -> void:
	var text := _source("res://main.gd")
	var lines: PackedStringArray = text.split("\n")
	var guarded: int = 0
	var unguarded: int = 0
	for i in range(lines.size()):
		if not lines[i].strip_edges().begins_with("_slow_factor = "):
			continue
		var synced := false
		for j in range(i, mini(i + 3, lines.size())):
			if lines[j].strip_edges().begins_with("_sync_combo_timer_wait()"):
				synced = true
				break
		if synced:
			guarded += 1
		else:
			unguarded += 1
			printerr("  unguarded _slow_factor assignment at main.gd:%d -> %s" % [i + 1, lines[i].strip_edges()])
	_check(guarded == 3 and unguarded == 0,
		"every _slow_factor mutation re-syncs the combo window (%d guarded, %d not)" % [guarded, unguarded])
	var helper := _func_body("res://main.gd", "_sync_combo_timer_wait")
	_check(helper.contains("_combo_timer.wait_time = 0.6 / _slow_factor"),
		"_sync_combo_timer_wait() divides the 0.6s window by _slow_factor")


func _test_combo_timer_runtime() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	# Freeze the conductor so nothing else mutates the window during the probe.
	main.set_process(false)
	main.set_physics_process(false)
	_check(is_instance_valid(main._combo_timer), "main._combo_timer exists after _run_setup()")
	_check(is_equal_approx(main._combo_timer.wait_time, 0.6),
		"combo window starts at 0.6s (got %.3f)" % main._combo_timer.wait_time)

	main._apply_slow_balls(30.0)
	_check(is_equal_approx(main._slow_factor, 0.6), "slow factor applied")
	_check(is_equal_approx(main._combo_timer.wait_time, 1.0),
		"combo window widens to 1.0s under SLOW_BALLS (got %.3f)" % main._combo_timer.wait_time)

	main._restore_ball_speeds()
	_check(is_equal_approx(main._combo_timer.wait_time, 0.6),
		"combo window restored to 0.6s (got %.3f)" % main._combo_timer.wait_time)

	main._apply_slow_balls(30.0)
	main._load_level(1)
	_check(is_equal_approx(main._slow_factor, 1.0) and is_equal_approx(main._combo_timer.wait_time, 0.6),
		"_load_level() resets both slow factor and combo window")
	main.free()


# ---------------------------------------------------------------------------
# Fix 2a — boss health bar fits its background
# ---------------------------------------------------------------------------

func _spawn_brick(btype: String, max_hp: int, boss: bool) -> Brick:
	var brick: Brick = BRICK_SCENE.instantiate()
	brick.brick_type = btype
	brick.max_hp = max_hp
	brick.is_boss = boss
	brick.row_color = THEME.SUCCESS
	get_tree().root.add_child(brick)
	brick.set_physics_process(false)
	brick.set_process(false)
	for child in brick.get_children():
		child.set_physics_process(false)
		child.set_process(false)
	return brick


func _test_boss_health_bar() -> void:
	var brick := _spawn_brick("boss", 5, true)
	_check(brick._health_bar != null and brick._health_bar_bg != null, "boss health bar nodes built")
	if brick._health_bar == null or brick._health_bar_bg == null:
		brick.free()
		return
	_check(is_equal_approx(brick._health_bar.size.x, BOSS_BAR_WIDTH),
		"boss bar at full HP is %.0fpx (got %.1f)" % [BOSS_BAR_WIDTH, brick._health_bar.size.x])
	_check(is_equal_approx(brick._health_bar.size.x, brick._health_bar_bg.size.x),
		"full-HP bar exactly covers its background")

	brick.take_damage(1)
	_check(is_equal_approx(brick._health_bar.size.x, BOSS_BAR_WIDTH * 0.8),
		"bar shrinks proportionally after a hit (got %.1f, want %.1f)"
		% [brick._health_bar.size.x, BOSS_BAR_WIDTH * 0.8])
	_check(brick._health_bar.size.x <= brick._health_bar_bg.size.x + 0.001,
		"bar never overflows its background (pre-fix regression: 56px base)")

	brick.take_damage(2)
	_check(is_equal_approx(brick._health_bar.size.x, BOSS_BAR_WIDTH * 0.6),
		"bar tracks 60% HP (got %.1f)" % brick._health_bar.size.x)
	brick.free()


# ---------------------------------------------------------------------------
# Fix 2b — metal bricks darken progressively
# ---------------------------------------------------------------------------

func _expected_metal(hp: int, max_hp: int) -> Color:
	return METAL_BASE.darkened(1.0 - clampf(float(hp) / float(max_hp), 0.3, 1.0))


func _test_metal_darkening() -> void:
	var brick := _spawn_brick("metal", 3, false)
	var colors: Array[Color] = [brick._sprite.color]
	_check(_colors_close(colors[0], _expected_metal(3, 3)),
		"full-HP metal holds base tone (got %s)" % brick._sprite.color)
	brick.take_damage(1)
	colors.append(brick._sprite.color)
	brick.take_damage(1)
	colors.append(brick._sprite.color)

	for i in range(colors.size()):
		var hp := 3 - i
		_check(_colors_close(colors[i], _expected_metal(hp, 3)),
			"metal hp=%d color follows clamp formula (got %s)" % [hp, colors[i]])
	_check(colors[1].v < colors[0].v and colors[2].v < colors[1].v,
			"metal darkening is monotonic (%.3f > %.3f > %.3f)"
			% [colors[0].v, colors[1].v, colors[2].v])
	_check(absf(colors[2].r - colors[0].r) > 0.05,
		"damage step is visible to the eye (%.3f -> %.3f)" % [colors[0].r, colors[2].r])
	_check(is_equal_approx(colors[2].r / colors[2].g, colors[0].r / colors[0].g)
			and colors[2].b > colors[2].r,
		"metal hue preserved while darkening (no grey fade-out)")

	var particles := brick._particles.process_material as ParticleProcessMaterial
	_check(particles != null and _colors_close(particles.color, _expected_metal(1, 3)),
		"metal particles match the current damage tone")
	_check(brick._hp_label.visible and brick._hp_label.text == "1", "HP label tracks remaining hits")
	brick.free()

	# Clamp floor: a 8-HP endless-wave metal brick must never go near-black.
	var tough := _spawn_brick("metal", 8, false)
	for i in range(7):
		tough.take_damage(1)
	_check(_colors_close(tough._sprite.color, _expected_metal(1, 8)),
		"8-HP metal at 1 HP matches clamped floor (got %s)" % tough._sprite.color)
	_check(tough._sprite.color.v > 0.15, "clamped floor stays legible (v=%.3f)" % tough._sprite.color.v)
	tough.free()


# ---------------------------------------------------------------------------
# Fix 3 — launch / power-up / paddle-hit WAVs are cached, not per-call
# ---------------------------------------------------------------------------

func _test_audio_wav_cache() -> void:
	var am: Node = AUDIO_SCRIPT.new()
	get_tree().root.add_child(am)

	_check(am._launch_wav != null, "_launch_wav cached in _ready()")
	_check(am._powerup_wav != null, "_powerup_wav cached in _ready()")
	_check(am._paddle_hit_wav != null, "_paddle_hit_wav cached in _ready()")
	if am._launch_wav == null or am._powerup_wav == null or am._paddle_hit_wav == null:
		am.free()
		return

	var expected: Array[String] = ["launch", "powerup", "paddle_hit"]
	var cached: Array[AudioStreamWAV] = [am._launch_wav, am._powerup_wav, am._paddle_hit_wav]
	var seconds: Array[float] = [0.12, 0.25, 0.08]
	for i in range(cached.size()):
		var wav := cached[i]
		var want_samples: int = int(AUDIO_SCRIPT.SAMPLE_RATE * seconds[i])
		_check(wav.data.size() == want_samples * 2,
			"%s wav is %d 16-bit mono samples (got %d bytes)" % [expected[i], want_samples, wav.data.size()])
		_check(wav.mix_rate == AUDIO_SCRIPT.SAMPLE_RATE and not wav.stereo,
			"%s wav format unchanged (22050 Hz mono)" % expected[i])
		_check(_peak(wav.data) > 0.0, "%s wav is not silent" % expected[i])

	# Verbatim parity with the previous inline synthesis.
	_check(am._paddle_hit_wav.data == AUDIO_SCRIPT._make_tone(120.0, 0.08, 0.2).data,
		"paddle hit wav identical to _make_tone(120, 0.08, 0.2)")
	_check(am._launch_wav.data == AUDIO_SCRIPT._make_launch_wav().data,
		"cached launch wav identical to freshly synthesized one")

	# Repeat calls reuse the identical stream object (no resynthesis, no new nodes).
	var pool_before: int = am.get_child_count()
	am.play_launch()
	am.play_launch()
	am.play_powerup()
	am.play_paddle_hit()
	var launch_uses: int = 0
	var unique: int = 0
	for player in am._player_pool:
		var stream := player.stream as AudioStreamWAV
		if stream == null:
			continue
		unique += 1
		if stream == am._launch_wav:
			launch_uses += 1
		else:
			_check(stream == am._powerup_wav or stream == am._paddle_hit_wav,
				"pool only ever holds the three cached effect streams")
	_check(launch_uses == 2, "both launch plays reuse the cached stream (got %d)" % launch_uses)
	_check(unique == 4, "four play calls touched four pool slots, all cached (got %d)" % unique)
	_check(am.get_child_count() == pool_before, "no AudioStreamPlayer spawned per effect")

	var launch_fn := _func_body("autoload/audio_manager.gd", "play_launch")
	_check(launch_fn.contains("_play_stream(_launch_wav, -8.0)")
			and not launch_fn.contains("AudioStreamWAV.new()"),
		"play_launch() is a one-liner over the cached wav")
	var powerup_fn := _func_body("res://autoload/audio_manager.gd", "play_powerup")
	_check(powerup_fn.contains("_play_stream(_powerup_wav, -6.0)")
			and not powerup_fn.contains("AudioStreamWAV.new()"),
		"play_powerup() is a one-liner over the cached wav")
	var paddle_fn := _func_body("res://autoload/audio_manager.gd", "play_paddle_hit")
	_check(paddle_fn.contains("_play_stream(_paddle_hit_wav, -12.0)"),
		"play_paddle_hit() is a one-liner over the cached wav")
	am.free()


func _peak(data: PackedByteArray) -> float:
	var peak := 0
	for i in range(0, data.size(), 2):
		var raw := data[i] | (data[i + 1] << 8)
		if data[i + 1] & 0x80 != 0:
			raw -= 65536
		peak = maxi(peak, absi(raw))
	return float(peak) / 32767.0


# ---------------------------------------------------------------------------
# Fix 1a — level intro shows the authored title + subtitle
# ---------------------------------------------------------------------------

func _test_hud_level_intro() -> void:
	var hud: HUD = HUD_SCENE.instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame

	hud.show_level_intro("LEVEL 3  ·  METAL CORE", "Durable metal bricks arrive.")
	_check(hud.level_intro_title.text == "LEVEL 3  ·  METAL CORE",
		"intro title uses the authored title (got %s)" % hud.level_intro_title.text)
	_check(hud.level_intro_subtitle.text == "Durable metal bricks arrive.",
		"intro subtitle uses the authored subtitle (got %s)" % hud.level_intro_subtitle.text)
	_check(hud.level_intro_subtitle.visible, "subtitle visible when non-empty")
	_check(hud.level_intro_panel.visible, "intro panel visible while showing")
	_check(hud.level_intro_title.pivot_offset.length_squared() > 0.0,
		"title pivot reflowed after the text change (scaled grow stays centered)")

	hud.show_level_intro("LEVEL 4")
	_check(hud.level_intro_subtitle.text == "" and not hud.level_intro_subtitle.visible,
		"empty subtitle hides instead of reserving a row")
	_check(hud.level_intro_title.text == "LEVEL 4", "title swaps on re-entry")
	await get_tree().process_frame
	hud.hide_level_intro()
	await get_tree().process_frame
	hud.free()


# ---------------------------------------------------------------------------
# Fix 1b — hearts are restored at show-time, not left faded from a loss
# ---------------------------------------------------------------------------

func _test_hud_heart_restore() -> void:
	var hud: HUD = HUD_SCENE.instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame

	hud.update_lives(3)
	for i in range(3):
		_check(hud.hearts[i].visible and is_equal_approx(hud.hearts[i].modulate.a, 1.0),
			"heart %d live and opaque at 3 lives" % (i + 1))

	# Lose a life, then let the fade-out complete so the residue is on screen.
	hud.update_lives(2)
	for _i in range(60):
		if not hud.hearts[2].visible:
			break
		await get_tree().process_frame
	_check(not hud.hearts[2].visible, "lost heart ends hidden")
	_check(hud.hearts[2].modulate.a == 0.0,
		"documented residue: hidden heart keeps modulate.a = 0 (got %.2f)" % hud.hearts[2].modulate.a)

	# Extra life: the re-shown heart must be solid immediately, not translucent.
	hud.update_lives(3)
	_check(hud.hearts[2].visible, "re-awarded heart shows at once")
	_check(is_equal_approx(hud.hearts[2].modulate.a, 1.0),
		"re-awarded heart is opaque at show-time (got %.2f)" % hud.hearts[2].modulate.a)
	_check(hud.hearts[2].scale == Vector2.ONE,
		"re-awarded heart has no leftover 1.5x scale (got %s)" % hud.hearts[2].scale)

	# A cancelled in-flight fade must not hide it again on the next frames.
	for _i in range(30):
		await get_tree().process_frame
	_check(hud.hearts[2].visible and hud.hearts[2].modulate.a > 0.99,
		"re-awarded heart stays visible and solid (a=%.2f)" % hud.hearts[2].modulate.a)

	# Mid-fade rescue: lose and regain inside the 0.2s fade window.
	hud.update_lives(2)
	await get_tree().process_frame
	hud.update_lives(3)
	_check(hud.hearts[2].visible and is_equal_approx(hud.hearts[2].modulate.a, 1.0),
		"heart rescued mid-fade stays visible and opaque")
	for _i in range(20):
		await get_tree().process_frame
	_check(hud.hearts[2].visible, "rescued heart survives the killed fade")

	# Overflow counter beyond the 5 authored hearts.
	hud.update_lives(6)
	_check(hud.lives_overflow.visible and hud.lives_overflow.text == "+1",
		"6 lives shows '+1' overflow (got %s)" % hud.lives_overflow.text)
	hud.update_lives(2)
	_check(not hud.lives_overflow.visible, "overflow hidden at or below heart capacity")
	hud.free()


# ---------------------------------------------------------------------------
# Fix 5 — paddle width tweens; drawing/geometry read visual_width
# ---------------------------------------------------------------------------

func _test_paddle_width_tween() -> void:
	var paddle: Paddle = PADDLE_SCENE.instantiate()
	get_tree().root.add_child(paddle)
	paddle.set_physics_process(false)
	paddle.wall_left_x = 0.0
	paddle.wall_right_x = 1280.0
	await get_tree().process_frame

	var normal := paddle.normal_width
	var big := normal * 1.6
	_check(is_equal_approx(paddle.visual_width, normal), "paddle idles at normal width")
	_check(is_equal_approx(paddle._shape.size.x, normal), "collision shape idles at normal width")

	paddle.apply_big_paddle(30.0)
	_check(is_equal_approx(paddle.target_width, big), "target width snaps to the intent")
	_check(is_equal_approx(paddle.visual_width, normal), "rendered width starts from the current width")
	_check(paddle._width_tween != null, "grow tween is live")
	_check(paddle.is_big_paddle_active(), "big paddle reported active during growth")

	var grew := await _poll_width(paddle, big)
	_check(grew, "rendered width reaches %.0fpx by tween end (got %.1f)" % [big, paddle.visual_width])
	_check(paddle._width_tween == null, "width tween released on completion")
	_check(is_equal_approx(paddle.sprite.offset_left, -big / 2.0)
			and is_equal_approx(paddle.sprite.offset_right, big / 2.0),
		"sprite offsets track the tweened width")
	_check(is_equal_approx(paddle.get_visual_ball_attach_offset(), paddle.get_ball_attach_offset()),
		"visual and target attach offsets agree once settled")

	# Shrink on expiry animates too, and physics bounds follow visual_width.
	paddle._reset_paddle_width()
	_check(paddle._width_tween != null, "shrink is animated, not snapped")
	await get_tree().process_frame
	_check(paddle.visual_width < big and paddle.visual_width > normal,
		"shrink is mid-flight (%.1fpx)" % paddle.visual_width)
	_check(is_equal_approx(paddle._shape.size.x, paddle.visual_width),
		"collision shape width == visual_width every frame")

	var shrank := await _poll_width(paddle, normal)
	_check(shrank, "width returns to %.0fpx (got %.1f)" % [normal, paddle.visual_width])
	_check(paddle._width_tween == null, "shrink tween released")
	_check(not paddle.is_big_paddle_active(), "big paddle no longer active")

	# reset() must snap (a stale wide paddle across level loads would be a bug).
	paddle.apply_big_paddle(30.0)
	await get_tree().process_frame
	paddle.reset()
	_check(is_equal_approx(paddle.visual_width, normal), "reset() snaps width back")
	_check(paddle._width_tween == null, "reset() leaves no tween running")
	_check(is_equal_approx(paddle._shape.size.x, normal), "reset() restores the collision shape")
	paddle.free()


## Polls until visual_width settles on `target`; asserts shape/sprite stay in lockstep.
func _poll_width(paddle: Paddle, target: float) -> bool:
	var previous := paddle.visual_width
	for _i in range(120):
		await get_tree().process_frame
		if not is_instance_valid(paddle):
			return false
		if not is_equal_approx(paddle._shape.size.x, paddle.visual_width):
			return false
		if absf(paddle.visual_width - previous) > 200.0:
			return false
		previous = paddle.visual_width
		if absf(paddle.visual_width - target) < 0.05:
			return true
	return false
