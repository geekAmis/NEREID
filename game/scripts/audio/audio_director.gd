class_name AudioDirector
extends Node
## Звуковой режиссёр кабины: петли, сигналы гидрофона, рация, голос Веры,
## шаги, тревоги и пространственные события Слушателя. Все клипы — из Synth.

var sim = null
var listener = null
var director = null
var hud = null

var ambience: AudioStreamPlayer
var pump_loop: AudioStreamPlayer
var water_loop: AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var signal_player: AudioStreamPlayer
var radio_static: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var _ui_pool: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer3D] = []
var _ui_index := 0
var _sfx_index := 0

var radio_lines: Dictionary = {}
var tapes: Dictionary = {}
var _queue: Array[Dictionary] = []
var _fallback_timer := 0.0
var _current_line := ""
var _signal_id := ""
var _ambient_timer := 6.0
var _alarm_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _last_step := 0.0
var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20261979
	_load_data()
	_build_players()

func setup(p_sim, p_listener, p_director, p_hud) -> void:
	sim = p_sim
	listener = p_listener
	director = p_director
	hud = p_hud
	if director != null:
		director.radio_line.connect(play_radio)
	if listener != null:
		listener.sound_event.connect(_on_listener_sound)
	if sim != null:
		sim.impact.connect(_on_impact)
	_start_loops()

func _load_data() -> void:
	var raw := _read_json("res://data/radio.json")
	var lines: Array = raw.get("lines", [])
	for line in lines:
		if typeof(line) == TYPE_DICTIONARY:
			radio_lines[str(line.get("id", ""))] = line
	var tr := _read_json("res://data/tapes.json")
	var tt: Array = tr.get("tapes", [])
	for t in tt:
		if typeof(t) == TYPE_DICTIONARY:
			tapes[str(t.get("id", ""))] = t

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _build_players() -> void:
	if not _ui_pool.is_empty():
		return
	ambience = _make_2d("SFX")
	ambience.stream = Synth.get_stream("hum")
	ambience.volume_db = -80.0
	ambience.play()
	pump_loop = _make_2d("SFX")
	pump_loop.stream = Synth.get_stream("pump")
	pump_loop.volume_db = -80.0
	pump_loop.play()
	water_loop = _make_2d("SFX")
	water_loop.stream = Synth.get_stream("water")
	water_loop.volume_db = -80.0
	water_loop.play()
	heartbeat = _make_2d("SFX")
	heartbeat.stream = Synth.get_stream("heartbeat")
	heartbeat.volume_db = -80.0
	heartbeat.play()
	signal_player = _make_2d("Hydrophone")
	signal_player.volume_db = -80.0
	signal_player.finished.connect(_on_signal_finished)
	radio_static = _make_2d("Radio")
	radio_static.stream = Synth.get_stream("static")
	radio_static.volume_db = -80.0
	radio_static.play()
	voice_player = _make_2d("Voice")
	voice_player.finished.connect(_on_voice_finished)
	for i in 8:
		var p := _make_2d("UI")
		_ui_pool.append(p)
	for i in 10:
		var s := AudioStreamPlayer3D.new()
		s.bus = "SFX"
		s.unit_size = 1.8
		s.max_distance = 26.0
		s.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(s)
		_sfx_pool.append(s)

func _make_2d(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _start_loops() -> void:
	if not ambience.playing:
		ambience.play()
	if not pump_loop.playing:
		pump_loop.play()
	if not water_loop.playing:
		water_loop.play()
	if not heartbeat.playing:
		heartbeat.play()
	if not radio_static.playing:
		radio_static.play()

func tick(delta: float) -> void:
	if sim == null:
		return
	var target_amb := -21.0 + clampf(sim.stress, 0.0, 1.0) * 3.0
	if _paused:
		target_amb -= 8.0
	ambience.volume_db = move_toward(ambience.volume_db, target_amb, delta * 12.0)
	var pump_on: bool = bool(sim.switches.get("pump", false)) and not sim.short_circuit
	var pump_target := -15.0 if pump_on else -80.0
	if sim.pump_manual:
		pump_target = -19.0
	pump_loop.volume_db = move_toward(pump_loop.volume_db, pump_target, delta * 30.0)
	var water_target := -80.0
	if sim.water_cm > 0.3:
		water_target = lerpf(-38.0, -11.0, clampf(sim.water_cm / 16.0, 0.0, 1.0))
	water_loop.volume_db = move_toward(water_loop.volume_db, water_target, delta * 18.0)
	var hb_target := -80.0
	if sim.stress > 0.28:
		hb_target = lerpf(-36.0, -12.0, clampf((sim.stress - 0.28) / 0.72, 0.0, 1.0))
	heartbeat.volume_db = move_toward(heartbeat.volume_db, hb_target, delta * 6.0)
	heartbeat.pitch_scale = lerpf(0.82, 1.45, clampf((sim.heart_rate - 62.0) / 100.0, 0.0, 1.0))
	_update_signal(delta)
	_tick_voice(delta)
	radio_static.volume_db = move_toward(radio_static.volume_db, -18.0 if voice_player.playing else -72.0, delta * 20.0)
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = _rng.randf_range(4.5, 11.0)
		_play_ambient()
	_alarm_timer -= delta
	if _alarm_timer <= 0.0:
		_alarm_timer = 9.0
		if sim.co2 > 3.0 or sim.battery_pct() < 20.0 or sim.short_circuit:
			_play_ui_vol("alarm", -24.0)

func _update_signal(delta: float) -> void:
	var id: String = sim.current_signal
	if id != _signal_id:
		_signal_id = id
		if id == "":
			signal_player.stop()
			signal_player.volume_db = -80.0
		else:
			var key := "signal_" + id
			var stream: AudioStream = Synth.get_stream(key)
			if stream == null:
				stream = Synth.get_stream("signal_cable")
			signal_player.stream = stream
			signal_player.volume_db = -32.0
			signal_player.play()
	if id != "":
		var strength := clampf(sim.signal_strength, 0.0, 1.0)
		var gain := clampf(sim.gain / 10.0, 0.0, 1.0)
		var target := lerpf(-34.0, -9.0, strength * (0.45 + gain * 0.55))
		if sim.filter_mode == 0:
			target -= 3.0
		elif sim.filter_mode == 2:
			target += 1.0
		signal_player.volume_db = move_toward(signal_player.volume_db, target, delta * 20.0)

func _on_signal_finished() -> void:
	if sim != null and sim.current_signal != "" and _signal_id == sim.current_signal:
		signal_player.play()

func _play_ambient() -> void:
	var pos := Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.7, 0.2), _rng.randf_range(-0.9, 0.9))
	var roll := _rng.randf()
	if roll < 0.55:
		play_sfx("drip", pos, -26.0)
	elif roll < 0.85:
		play_sfx("creak", pos, -30.0)
	else:
		play_sfx("beep", pos, -34.0)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play_ui(name: String) -> void:
	_play_ui_vol(name, -8.0 if name != "tick_soft" else -34.0)

func _play_ui_vol(name: String, vol: float) -> void:
	if _ui_pool.is_empty():
		return
	var stream: AudioStream = Synth.get_stream(name)
	if stream == null:
		stream = Synth.get_stream("click")
	if stream == null:
		return
	var p := _ui_pool[_ui_index]
	_ui_index = (_ui_index + 1) % _ui_pool.size()
	p.stream = _one_shot(stream)
	p.volume_db = vol
	p.pitch_scale = 1.0
	if name == "tick_soft":
		p.pitch_scale = 1.9
	p.play()

func _one_shot(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			var copy := wav.duplicate() as AudioStreamWAV
			copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return copy
	return stream

func play_step(pos: Vector3, quiet: bool = false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_step < 0.15:
		return
	_last_step = now
	_play_sfx_stream("clunk", pos, -30.0 if quiet else -21.0, 1.75)

func play_sfx(name: String, pos: Vector3, vol: float = -10.0) -> void:
	_play_sfx_stream(name, pos, vol, 1.0)

func _play_sfx_stream(name: String, pos: Vector3, vol: float, pitch: float) -> void:
	if _sfx_pool.is_empty():
		return
	var stream: AudioStream = Synth.get_stream(name)
	if stream == null:
		return
	var p := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	p.stream = _one_shot(stream)
	p.global_position = pos
	p.volume_db = vol
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.05)
	p.play()

func play_radio(id: String) -> void:
	var line: Dictionary = radio_lines.get(id, {})
	if line.is_empty():
		return
	var text := str(line.get("text", ""))
	var speaker := str(line.get("speaker", "Вера"))
	_queue_line(id, text, speaker, maxf(2.8, float(text.length()) / 13.0))
	_play_ui_vol("static", -22.0)

func play_voice_text(id: String, text: String, speaker: String, duration: float = 0.0) -> void:
	_queue_line(id, text, speaker, duration if duration > 0.0 else maxf(2.8, float(text.length()) / 13.0))

func play_tape(id: String) -> bool:
	var t: Dictionary = tapes.get(id, {})
	if t.is_empty():
		return false
	var text := str(t.get("text", ""))
	var speaker := str(t.get("speaker", "Гринберг"))
	var dur := minf(float(t.get("duration", 20.0)), maxf(6.0, float(text.length()) / 11.0))
	_queue_line(id, text, speaker, dur)
	_play_ui_vol("tape_hiss", -18.0)
	return true

func _queue_line(id: String, text: String, speaker: String, duration: float) -> void:
	if text.strip_edges() == "":
		return
	for q in _queue:
		if str(q.get("id", "")) == id:
			return
	_queue.append({"id": id, "text": text, "speaker": speaker, "duration": duration})

func _tick_voice(delta: float) -> void:
	if voice_player.playing:
		return
	if _fallback_timer > 0.0:
		_fallback_timer = maxf(0.0, _fallback_timer - delta)
		return
	if _queue.is_empty():
		return
	var line: Dictionary = _queue.pop_front()
	_start_line(line)

func _start_line(line: Dictionary) -> void:
	var id := str(line.get("id", ""))
	var text := str(line.get("text", ""))
	var speaker := str(line.get("speaker", "Вера"))
	var est := float(line.get("duration", 4.0))
	_current_line = id
	var path := "res://assets/voice/%s.wav" % id
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			voice_player.stream = stream
			voice_player.volume_db = -3.0
			voice_player.play()
			var dur := stream.get_length()
			if dur <= 0.1:
				dur = est
			if hud != null:
				hud.show_radio(text, speaker, dur + 0.8)
			return
	if hud != null:
		hud.show_radio(text, speaker, est + 1.0)
	_fallback_timer = est

func _on_voice_finished() -> void:
	_current_line = ""

# ---------------------------------------------------------------------------
# Signals from world
# ---------------------------------------------------------------------------

func _on_listener_sound(name: String, pos: Vector3) -> void:
	match name:
		"listener_breath", "listener_inhale":
			play_sfx_at_bus("breath", pos, -10.0, "Underwater")
		"listener_far":
			play_sfx_at_bus("whale", pos, -18.0, "Underwater")
		"listener_strike":
			play_sfx_at_bus("knock", pos, -4.0, "Underwater")
			if Game.settings.get("shake", true) and Game.current_game != null and Game.current_game.has_method("shake"):
				Game.current_game.shake(0.6)
		_:
			play_sfx_at_bus("static", pos, -30.0, "Underwater")

func play_sfx_at_bus(name: String, pos: Vector3, vol: float, bus: String) -> void:
	if _sfx_pool.is_empty():
		return
	var stream: AudioStream = Synth.get_stream(name)
	if stream == null:
		return
	var p := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	p.stream = _one_shot(stream)
	p.bus = bus
	p.global_position = pos
	p.volume_db = vol
	p.pitch_scale = _rng.randf_range(0.92, 1.04)
	p.play()

func _on_impact(strength: float) -> void:
	play_sfx("clunk", Vector3(0.0, -0.2, 0.0), -4.0 + minf(strength, 12.0) * 0.4)
	_play_ui_vol("alarm", -24.0)
	if Game.settings.get("shake", true) and Game.current_game != null and Game.current_game.has_method("shake"):
		Game.current_game.shake(clampf(strength / 14.0, 0.2, 1.0))

func set_paused(value: bool) -> void:
	_paused = value
	ambience.volume_db = -32.0 if value else -21.0

func stop_all() -> void:
	for p in [ambience, pump_loop, water_loop, heartbeat, signal_player, radio_static, voice_player]:
		if p != null:
			p.stop()
	for s in _sfx_pool:
		s.stop()
	for u in _ui_pool:
		u.stop()
