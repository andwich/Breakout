extends SceneTree

## Temporary probe: what is available under `-s`?

const AUDIO_SCRIPT := preload("res://autoload/audio_manager.gd")

func _initialize() -> void:
	print("PROBE GameTheme=", GameTheme)
	print("PROBE SaveData=", SaveData)
	print("PROBE AudioManager=", AudioManager)
	await process_frame
	var am: Node = AUDIO_SCRIPT.new()
	root.add_child(am)
	print("PROBE launch_wav=", am._launch_wav, " data=", am._launch_wav.data.size())
	am.play_launch()
	print("PROBE pool0 stream=", am._player_pool[0].stream, " playing=", am._player_pool[0].playing)
	var main := preload("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	print("PROBE main combo wait=", main._combo_timer.wait_time, " phase=", main.phase)
	quit(0)
