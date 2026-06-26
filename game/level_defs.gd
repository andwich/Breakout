class_name LevelDefs
extends RefCounted

static func base_levels() -> Array[Dictionary]:
	return [
		{
			"name": "Opening Volley",
			"intro_text": "Learn the rebound angle and settle into the pace.",
			"cols": 8, "rows": 4,
			"speed_mult": 1.0,
			"boss_hp": 0,
			"metal_hp": 0,
			"drop_chance": 0.15,
			"drop_weights": {
				PowerUp.Type.BIG_PADDLE: 4,
				PowerUp.Type.STICKY: 3,
				PowerUp.Type.SLOW_BALLS: 2,
				PowerUp.Type.MULTIBALL: 1,
				PowerUp.Type.LASER: 1,
				PowerUp.Type.EXTRA_LIFE: 1,
			}
		},
		{
			"name": "Controlled Angles",
			"intro_text": "Sticky catches matter more than raw speed here.",
			"cols": 10, "rows": 5,
			"speed_mult": 1.1,
			"boss_hp": 0,
			"metal_hp": 0,
			"drop_chance": 0.18,
			"drop_weights": {
				PowerUp.Type.STICKY: 4,
				PowerUp.Type.BIG_PADDLE: 3,
				PowerUp.Type.SLOW_BALLS: 2,
				PowerUp.Type.MULTIBALL: 2,
				PowerUp.Type.LASER: 1,
				PowerUp.Type.EXTRA_LIFE: 1,
			}
		},
		{
			"name": "Metal Core",
			"intro_text": "Durable metal bricks arrive. Slow Ball helps you aim.",
			"cols": 10, "rows": 6,
			"speed_mult": 1.2,
			"boss_hp": 0,
			"metal_hp": 3,
			"drop_chance": 0.22,
			"drop_weights": {
				PowerUp.Type.SLOW_BALLS: 4,
				PowerUp.Type.LASER: 3,
				PowerUp.Type.BIG_PADDLE: 2,
				PowerUp.Type.MULTIBALL: 2,
				PowerUp.Type.STICKY: 2,
				PowerUp.Type.EXTRA_LIFE: 1,
			}
		},
		{
			"name": "Boss Gate",
			"intro_text": "A boss block commands the field. Laser is your edge.",
			"cols": 12, "rows": 6,
			"speed_mult": 1.3,
			"boss_hp": 5,
			"metal_hp": 0,
			"drop_chance": 0.25,
			"drop_weights": {
				PowerUp.Type.LASER: 4,
				PowerUp.Type.BIG_PADDLE: 3,
				PowerUp.Type.MULTIBALL: 2,
				PowerUp.Type.STICKY: 2,
				PowerUp.Type.SLOW_BALLS: 2,
				PowerUp.Type.EXTRA_LIFE: 1,
			}
		},
		{
			"name": "Breach Point",
			"intro_text": "Everything at once. Survive the final test.",
			"cols": 12, "rows": 7,
			"speed_mult": 1.45,
			"boss_hp": 5,
			"metal_hp": 3,
			"drop_chance": 0.28,
			"drop_weights": {
				PowerUp.Type.MULTIBALL: 3,
				PowerUp.Type.LASER: 3,
				PowerUp.Type.BIG_PADDLE: 2,
				PowerUp.Type.STICKY: 2,
				PowerUp.Type.SLOW_BALLS: 2,
				PowerUp.Type.EXTRA_LIFE: 2,
			}
		},
	]

static func config_for_level(level: int) -> Dictionary:
	var defs := base_levels()
	if level <= defs.size():
		return defs[level - 1].duplicate(true)

	var wave := level - defs.size()
	return {
		"name": "Endless",
		"intro_text": "Survive the escalation.",
		"cols": mini(14, 10 + wave),
		"rows": mini(10, 5 + wave / 2),
		"speed_mult": minf(2.5, 1.0 + wave * 0.15),
		"boss_hp": 0 if wave < 2 else mini(8, 3 + wave),
		"metal_hp": 0 if wave < 1 else mini(5, 2 + wave / 2),
		"drop_chance": minf(1.0, 0.25 + wave * 0.02),
		"drop_weights": {
			PowerUp.Type.MULTIBALL: 2,
			PowerUp.Type.BIG_PADDLE: 2,
			PowerUp.Type.STICKY: 2,
			PowerUp.Type.LASER: 2,
			PowerUp.Type.SLOW_BALLS: 2,
			PowerUp.Type.EXTRA_LIFE: 1,
		}
	}

static func pick_powerup_for_level(level: int) -> PowerUp.Type:
	var weights: Dictionary = config_for_level(level).get("drop_weights", {})
	if weights.is_empty():
		return PowerUpRegistry.random_type()
	return PowerUpRegistry.random_type(weights)
