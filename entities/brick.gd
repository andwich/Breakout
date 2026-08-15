class_name Brick
extends StaticBody2D

signal destroyed(from_position: Vector2, drop_chance: float, point_value: int)
signal damaged(hp_remaining: int)

@export var max_hp: int = 1
@export var point_value: int = 10
@export var drop_chance: float = 0.25
@export var is_boss: bool = false
@export var brick_type: String = "standard"
@export var row_color: Color = Color.WHITE
var base_color: Color

var _hp: int
var _shader_mat: ShaderMaterial
var _scored := false

func is_scored() -> bool:
	return _scored

const GLOW_SHADER := preload("res://shaders/brick_glow.gdshader")
const SCAN_SHADER := preload("res://shaders/scanline.gdshader")

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _hp_label: Label = $Sprite/HP_Label
@onready var _particles: GPUParticles2D = $Particles
@onready var _sprite: ColorRect = $Sprite
var _health_bar: ColorRect
var _health_bar_bg: ColorRect
var _flash_tween: Tween
var _scale_tween: Tween
var _boss_glow_tween: Tween

func _ready():
	_hp = max_hp
	match brick_type:
		"metal":
			base_color = GameTheme.BRICK_DURABLE
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = SCAN_SHADER
			_shader_mat.set_shader_parameter("frequency", 40.0)
			_shader_mat.set_shader_parameter("intensity", 0.15)
			_sprite.material = _shader_mat
		"boss":
			base_color = GameTheme.BRICK_BOSS
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = GLOW_SHADER
			_shader_mat.set_shader_parameter("glow_intensity", 2.0)
			_shader_mat.set_shader_parameter("glow_color", GameTheme.BRICK_BOSS)
			_sprite.material = _shader_mat
		_:
			base_color = GameTheme.BRICK_STANDARD
	_update_visual()
	refresh_damage_visuals()
	if is_boss:
		_health_bar_bg = ColorRect.new()
		_health_bar_bg.size = Vector2(40, 4)
		_health_bar_bg.position = Vector2(-20, 16)
		_health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.8)
		add_child(_health_bar_bg)
		_health_bar = ColorRect.new()
		_health_bar.size = Vector2(40, 4)
		_health_bar.position = Vector2(-20, 16)
		_health_bar.color = GameTheme.BRICK_BOSS
		add_child(_health_bar)
	if is_boss and _shader_mat:
		_boss_glow_tween = create_tween()
		_boss_glow_tween.set_loops()
		_boss_glow_tween.tween_method(func(v): _shader_mat.set_shader_parameter("glow_intensity", v), 1.5, 3.0, 0.6)
		_boss_glow_tween.tween_method(func(v): _shader_mat.set_shader_parameter("glow_intensity", v), 3.0, 1.5, 0.6)

func take_damage(amount: int = 1) -> Dictionary:
	if _scored:
		return {
			"destroyed": false,
			"awarded_points": 0,
			"score_points": 0,
			"remaining_hp": _hp,
			"was_already_scored": true,
		}

	_hp -= amount
	_update_visual()

	if _hp > 0:
		refresh_damage_visuals()
		if _particles:
			_particles.emitting = true
		if brick_type == "boss":
			var hp_ratio := float(_hp) / float(max_hp)
			var target_color := GameTheme.BRICK_BOSS.darkened(1.0 - clampf(hp_ratio, 0.3, 1.0))
			if _flash_tween and _flash_tween.is_valid():
				_flash_tween.kill()
			_flash_tween = create_tween()
			_flash_tween.tween_property(_sprite, "color", Color.WHITE, 0.04)
			_flash_tween.tween_property(_sprite, "color", target_color, 0.07)
		else:
			if _flash_tween and _flash_tween.is_valid():
				_flash_tween.kill()
			_flash_tween = create_tween()
			_flash_tween.tween_property(_sprite, "color", Color(1.0, 1.0, 1.0), 0.04)
			_flash_tween.tween_callback(func(): _update_visual())
		if _scale_tween and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.03)
		_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.07)
	damaged.emit(_hp)

	if _hp <= 0:
		var awarded_points := point_value
		destroy()
		return {
			"destroyed": true,
			"awarded_points": awarded_points,
			"score_points": awarded_points,
			"remaining_hp": 0,
			"was_already_scored": false,
		}

	return {
		"destroyed": false,
		"awarded_points": 0,
		"score_points": 0,
		"remaining_hp": _hp,
		"was_already_scored": false,
	}

func destroy():
	_scored = true
	destroyed.emit(global_position, drop_chance, point_value)
	if _particles:
		var vfx := _particles.duplicate()
		vfx.emitting = true
		vfx.one_shot = true
		vfx.finished.connect(vfx.queue_free)
		if get_tree().current_scene:
			get_tree().current_scene.add_child(vfx)
		else:
			get_tree().root.add_child(vfx)
		vfx.global_position = global_position
	queue_free()

func refresh_damage_visuals() -> void:
	if max_hp <= 1:
		return
	var health_ratio := clampf(float(_hp) / float(max_hp), 0.0, 1.0)
	if _hp_label:
		_hp_label.text = str(_hp)
		_hp_label.visible = true
	if _health_bar:
		_health_bar.size.x = 56.0 * health_ratio
	if _sprite and brick_type == "standard":
		_sprite.color = GameTheme.BRICK_STANDARD.darkened((1.0 - health_ratio) * 0.16)

func _update_visual():
	if _hp_label:
		_hp_label.text = str(_hp)
		_hp_label.visible = max_hp > 1
	match brick_type:
		"boss":
			var hp_ratio := float(_hp) / float(max_hp)
			var dimmed := GameTheme.BRICK_BOSS.darkened(1.0 - clampf(hp_ratio, 0.3, 1.0))
			if _health_bar:
				_health_bar.size.x = 40.0 * hp_ratio
			if _sprite:
				_sprite.color = dimmed
			if _particles:
				var pm := _particles.process_material as ParticleProcessMaterial
				if pm:
					pm.color = dimmed
			var alpha := 1.0 - float(max_hp - _hp) / float(max_hp) * 0.45
			modulate.a = clampf(alpha, 0.55, 1.0)
		"metal":
			if _sprite:
				_sprite.color = Color(0.7, 0.7, 0.9)
			if _particles:
				var pm := _particles.process_material as ParticleProcessMaterial
				if pm:
					pm.color = Color(0.7, 0.7, 0.9)
			var alpha := 1.0 - float(max_hp - _hp) / float(max_hp) * 0.45
			modulate.a = clampf(alpha, 0.55, 1.0)
		_:
			if _sprite:
				_sprite.material = null
				_sprite.color = GameTheme.BRICK_STANDARD.darkened(0.12).lerp(Color.WHITE, 0.05)
			if _particles:
				var pm := _particles.process_material as ParticleProcessMaterial
				if pm:
					pm.color = GameTheme.BRICK_STANDARD
			modulate.a = 0.92

func _exit_tree() -> void:
	for tween in [_flash_tween, _scale_tween, _boss_glow_tween]:
		if is_instance_valid(tween):
			tween.kill()
