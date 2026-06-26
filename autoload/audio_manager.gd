extends Node

const SAMPLE_RATE := 22050
const MASTER_BUS := "Master"

var _muted := false
var _saved_volume_db: float = 0.0
var _brick_tone_pool: Array[AudioStreamWAV] = []

func _ready() -> void:
	for i in range(5):
		_brick_tone_pool.append(_make_tone(400.0 + i * 100.0, 0.035, 0.35))

func is_muted() -> bool:
	return _muted

func toggle_mute() -> void:
	_muted = not _muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), _muted)

func set_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), db)

func _play_stream(wav: AudioStreamWAV, volume_db: float = -6.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = wav
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

static func _pack_sample(data: PackedByteArray, index: int, value: int) -> void:
	data[index * 2] = value & 0xFF
	data[index * 2 + 1] = (value >> 8) & 0xFF

static func _make_tone(freq: float, duration: float, volume: float = 0.35) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := maxf(0.0, 1.0 - t / duration)
		var sample := sin(2.0 * PI * freq * t) * volume * envelope
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav

static func _make_chord(freqs: Array, duration: float, volume: float = 0.25) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := maxf(0.0, 1.0 - t / duration)
		var sample := 0.0
		for f in freqs:
			sample += sin(2.0 * PI * float(f) * t)
		sample /= freqs.size()
		sample *= volume * envelope
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav

func play_brick_hit(pitch_factor: float = 1.0) -> void:
	var idx := mini(int(pitch_factor * 4.0), _brick_tone_pool.size() - 1)
	idx = maxi(0, idx)
	_play_stream(_brick_tone_pool[idx], -10.0)

func play_paddle_hit() -> void:
	_play_stream(_make_tone(180.0, 0.06, 0.25), -12.0)

func play_launch() -> void:
	var num_samples := int(SAMPLE_RATE * 0.1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var freq := 200.0 + t * 3000.0
		var sample := sin(2.0 * PI * freq * t) * 0.3 * maxf(0.0, 1.0 - t / 0.1)
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	_play_stream(wav, -8.0)

func play_powerup() -> void:
	var num_samples := int(SAMPLE_RATE * 0.2)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var notes := [400.0, 600.0, 800.0]
	var note_duration := 0.2 / notes.size()
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var note_idx := mini(notes.size() - 1, int(t / note_duration))
		var freq := notes[note_idx]
		var local_t := t - note_idx * note_duration
		var envelope := maxf(0.0, 1.0 - t / 0.2)
		var sample := sin(2.0 * PI * freq * t) * 0.3 * envelope
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	_play_stream(wav, -6.0)

func play_life_lost() -> void:
	var num_samples := int(SAMPLE_RATE * 0.3)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var freq := 400.0 - t * 666.0
		var envelope := maxf(0.0, 1.0 - t / 0.3)
		var sample := sin(2.0 * PI * freq * t) * 0.35 * envelope
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	_play_stream(wav, -8.0)

func play_level_complete() -> void:
	_play_stream(_make_chord([523.25, 659.25, 783.99], 0.35, 0.3), -6.0)

func play_game_over() -> void:
	_play_stream(_make_chord([400.0, 300.0, 200.0], 0.5, 0.3), -8.0)

func play_laser_fire() -> void:
	_play_stream(_make_tone(600.0, 0.03, 0.2), -12.0)
