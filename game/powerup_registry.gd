class_name PowerUpRegistry
extends Object

const DEFS := {
	PowerUp.Type.MULTIBALL: {
		"id": "multiball",
		"hud_label": "MULTIBALL",
		"display_name": "Multiball",
		"icon": "M",
		"color": Color(GameTheme.INFO),
		"duration": 0.0,
		"is_timed": false,
		"description": "Spawns 2 clones per active ball",
		"default_weight": 2,
	},
	PowerUp.Type.BIG_PADDLE: {
		"id": "big_paddle",
		"hud_label": "BIG PADDLE",
		"display_name": "Big Paddle",
		"icon": "B",
		"color": Color(GameTheme.SUCCESS),
		"duration": 8.0,
		"is_timed": true,
		"description": "Expands paddle 1.6x",
		"default_weight": 3,
	},
	PowerUp.Type.STICKY: {
		"id": "sticky",
		"hud_label": "STICKY",
		"display_name": "Sticky Paddle",
		"icon": "S",
		"color": Color(1.0, 1.0, 0.4),
		"duration": 10.0,
		"is_timed": true,
		"description": "Catches ball, relaunch on input",
		"default_weight": 3,
	},
	PowerUp.Type.LASER: {
		"id": "laser",
		"hud_label": "LASER",
		"display_name": "Laser",
		"icon": "L",
		"color": Color(GameTheme.ACCENT),
		"duration": 6.0,
		"is_timed": true,
		"description": "Auto-fires beams every 0.3 sec",
		"default_weight": 2,
	},
	PowerUp.Type.SLOW_BALLS: {
		"id": "slow_balls",
		"hud_label": "SLOW",
		"display_name": "Slow Balls",
		"icon": "\u2193",
		"color": Color(0.6, 0.2, 1.0),
		"duration": 6.0,
		"is_timed": true,
		"description": "Reduces ball speed to 60%",
		"default_weight": 2,
	},
	PowerUp.Type.EXTRA_LIFE: {
		"id": "extra_life",
		"hud_label": "1UP",
		"display_name": "Extra Life",
		"icon": "\u2665",
		"color": Color(1.0, 0.1, 0.1),
		"duration": 0.0,
		"is_timed": false,
		"description": "Adds 1 life",
		"default_weight": 1,
	},
}

static func get_def(ptype: PowerUp.Type) -> Dictionary:
	return DEFS.get(ptype, {}).duplicate(true)

static func all_types() -> Array[PowerUp.Type]:
	var result: Array[PowerUp.Type] = []
	for key in DEFS.keys():
		result.append(key as PowerUp.Type)
	return result

static func ids() -> Array[String]:
	var result: Array[String] = []
	for ptype in DEFS.keys():
		result.append(String(DEFS[ptype]["id"]))
	return result

static func hud_label_for(ptype: PowerUp.Type) -> String:
	return String(DEFS.get(ptype, {}).get("hud_label", "POWER"))

static func display_name_for(ptype: PowerUp.Type) -> String:
	return String(DEFS.get(ptype, {}).get("display_name", "Power-up"))

static func icon_for(ptype: PowerUp.Type) -> String:
	return String(DEFS.get(ptype, {}).get("icon", "?"))

static func color_for(ptype: PowerUp.Type) -> Color:
	return DEFS.get(ptype, {}).get("color", Color.WHITE)

static func duration_for(ptype: PowerUp.Type) -> float:
	return float(DEFS.get(ptype, {}).get("duration", 0.0))

static func is_timed(ptype: PowerUp.Type) -> bool:
	return bool(DEFS.get(ptype, {}).get("is_timed", false))

static func description_for(ptype: PowerUp.Type) -> String:
	return String(DEFS.get(ptype, {}).get("description", ""))

static func effect_id_for(ptype: PowerUp.Type) -> String:
	return String(DEFS.get(ptype, {}).get("id", "power"))

static func default_weight_for(ptype: PowerUp.Type) -> int:
	return int(DEFS.get(ptype, {}).get("default_weight", 1))

static func weighted_bag_from(weights: Dictionary = {}) -> Array[PowerUp.Type]:
	var bag: Array[PowerUp.Type] = []
	for ptype in all_types():
		var weight := int(weights.get(ptype, default_weight_for(ptype)))
		for i in range(maxi(0, weight)):
			bag.append(ptype)
	return bag

static func random_type(weights: Dictionary = {}) -> PowerUp.Type:
	var bag := weighted_bag_from(weights)
	if bag.is_empty():
		return PowerUp.Type.MULTIBALL
	return bag[randi() % bag.size()]
