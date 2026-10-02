extends SceneTree

const AUDIO_SCRIPT := preload("res://autoload/audio_manager.gd")

func _initialize() -> void:
	print("PROBE GameTheme=", GameTheme)
	print("PROBE RunState=", RunState)
	print("PROBE SaveData=", SaveData)
	print("PROBE Registry=", PowerUpRegistry.duration_for(PowerUp.Type.STICKY))
	await process_frame
	var hud := load("res://ui/hud.tscn")
	print("PROBE hud scene=", hud)
	if hud != null:
		var h = hud.instantiate()
		root.add_child(h)
		print("PROBE hearts=", h.hearts.size())
	var am: Node = AUDIO_SCRIPT.new()
	root.add_child(am)
	print("PROBE launch_wav=", am._launch_wav, " samples=", am._launch_wav.data.size() if am._launch_wav else -1)
	am.play_launch()
	print("PROBE pool0=", am._player_pool[0].stream, " playing=", am._player_pool[0].playing)
	quit(0)
