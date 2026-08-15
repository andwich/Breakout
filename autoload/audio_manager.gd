extends Node

const SAMPLE_RATE := 22050
const MASTER_BUS := "Master"

var _muted := false
var _saved_volume_db: float = 0.0
var _brick_tone_pool: Array[AudioStreamWAV] = []

const BRICK_HIT_MIN_INTERVAL_MS := 28.0

var _last_brick_hit_ms := -BRICK_HIT_MIN_INTERVAL_MS

const PLAYER_POOL_SIZE := 12
var _player_pool: Array[AudioStreamPlayer] = []
var _next_player_idx := 0

func _ready() -> void:
	for i in range(5):
		_brick_tone_pool.append(_make_tone([392.0, 440.0, 494.0, 587.33, 659.25][i], 0.05, 0.25))
	for i in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_player_pool.append(player)

func is_muted() -> bool:
	return _muted

func toggle_mute() -> void:
	_muted = not _muted
	var idx := _master_bus_index()
	if idx >= 0:
		AudioServer.set_bus_mute(idx, _muted)

func set_volume_db(db: float) -> void:
	var idx := _master_bus_index()
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)

func _master_bus_index() -> int:
	var index := AudioServer.get_bus_index(MASTER_BUS)
	if index < 0:
		push_warning("Master bus not found; audio operation skipped.")
	return index

func _play_stream(wav: AudioStreamWAV, volume_db: float = -6.0) -> void:
	# Try to find a non-playing player starting from the next index
	for i in range(PLAYER_POOL_SIZE):
		var idx := (_next_player_idx + i) % PLAYER_POOL_SIZE
		if not _player_pool[idx].playing:
			var player := _player_pool[idx]
			player.stream = wav
			player.volume_db = volume_db
			player.play()
			_next_player_idx = (idx + 1) % PLAYER_POOL_SIZE
			return
	# All players busy — steal the oldest (next in round-robin)
	var player := _player_pool[_next_player_idx]
	player.stream = wav
	player.volume_db = volume_db
	player.play()
	_next_player_idx = (_next_player_idx + 1) % PLAYER_POOL_SIZE

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

static func _make_chord(freqs: Array[float], duration: float, volume: float = 0.25) -> AudioStreamWAV:
	var num_samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := maxf(0.0, 1.0 - t / duration)
		var sample := 0.0
		for f: float in freqs:
			sample += sin(2.0 * PI * f * t)
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
	var now := Time.get_ticks_msec()
	if now - _last_brick_hit_ms < BRICK_HIT_MIN_INTERVAL_MS:
		return
	_last_brick_hit_ms = now
	var idx := mini(int(pitch_factor * 4.0), _brick_tone_pool.size() - 1)
	idx = maxi(0, idx)
	_play_stream(_brick_tone_pool[idx], -10.0)

func play_paddle_hit() -> void:
	_play_stream(_make_tone(120.0, 0.08, 0.2), -12.0)

func play_launch() -> void:
	var num_samples := int(SAMPLE_RATE * 0.12)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var freq := 150.0 + t * 2083.33
		var fundamental := sin(2.0 * PI * freq * t)
		var harmonic := sin(2.0 * PI * freq * 2.0 * t) * 0.25
		var sample := (fundamental + harmonic) / 1.25 * 0.2 * maxf(0.0, 1.0 - t / 0.12)
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	_play_stream(wav, -8.0)

func play_powerup() -> void:
	var num_samples := int(SAMPLE_RATE * 0.25)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var notes: Array[float] = [330.0, 392.0, 494.0]
	var note_duration := 0.25 / notes.size()
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var note_idx := mini(notes.size() - 1, int(t / note_duration))
		var freq: float = notes[note_idx]
		var local_t := t - note_idx * note_duration
		var envelope := maxf(0.0, 1.0 - local_t / note_duration)
		var sample := sin(2.0 * PI * freq * t) * 0.25 * envelope
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	_play_stream(wav, -6.0)

func play_life_lost() -> void:
	var num_samples := int(SAMPLE_RATE * 0.35)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / SAMPLE_RATE
		var freq := 440.0 - t * 800.0
		var envelope := maxf(0.0, 1.0 - t / 0.35)
		var fundamental := sin(2.0 * PI * freq * t)
		var harmonic := sin(2.0 * PI * freq * 2.0 * t) * 0.15
		var sample := (fundamental + harmonic) / 1.15 * 0.2 * envelope
		var val := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		_pack_sample(data, i, val)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	_play_stream(wav, -8.0)

func play_level_complete() -> void:
	_play_stream(_make_chord([523.25, 659.25, 783.99] as Array[float], 0.5, 0.25), -6.0)

func play_game_over() -> void:
	_play_stream(_make_chord([349.23, 311.13, 261.63] as Array[float], 0.6, 0.25), -8.0)

func play_laser_fire() -> void:
	_play_stream(_make_tone(440.0, 0.05, 0.15), -12.0)
