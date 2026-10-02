extends SceneTree

func _initialize() -> void:
	await process_frame
	var names: Array[String] = []
	for c in root.get_children():
		names.append(str(c.name))
	print("PROBE root children=", names)
	print("PROBE save_data=", root.get_node_or_null("SaveData"))
	var hud := load("res://ui/hud.tscn")
	print("PROBE hud=", hud)
	if hud != null:
		var h = hud.instantiate()
		root.add_child(h)
		print("PROBE hearts=", h.hearts.size(), " high_label=", h.high_score_label.visible)
	print("PROBE registry_sticky=", load("res://game/powerup_registry.gd").duration_for(load("res://entities/powerup.gd").Type.STICKY))
	quit(0)
