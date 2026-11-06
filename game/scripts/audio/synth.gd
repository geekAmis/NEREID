extends Node
## Процедурный синтез звука. Все клипы генерируются один раз при старте и
## кэшируются как AudioStreamWAV (16 бит, 22 050 Гц, моно).
## Никаких внешних аудиофайлов, кроме SAPI-озвучки.

const RATE := 22050
const TAU_F := TAU

var streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _generated := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 19790427
	_ensure_buses()
	if not _generated:
		generate_all()

func _ensure_buses() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	_ensure_bus("Music")
	_ensure_bus("UI")
	_ensure_bus("Radio")
	_ensure_bus("Underwater")
	_ensure_bus("Hydrophone")

	_add_lowpass("Radio", 2800.0, 0.6)
	_add_distortion("Radio", 0.18)
	_add_reverb("Radio", 0.28, 0.12)
	_add_lowpass("Underwater", 650.0, 0.5)
	_add_reverb("Underwater", 0.55, 0.22)
	_add_lowpass("Hydrophone", 4200.0, 0.4)
	_add_reverb("Hydrophone", 0.45, 0.18)

func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, "Master")

func _add_lowpass(bus: String, cutoff: float, resonance: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
			return
	var fx := AudioEffectLowPassFilter.new()
	fx.cutoff_hz = cutoff
	fx.resonance = resonance
	AudioServer.add_bus_effect(idx, fx)

func _add_distortion(bus: String, drive: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectDistortion:
			return
	var fx := AudioEffectDistortion.new()
	fx.mode = AudioEffectDistortion.MODE_OVERDRIVE
	fx.drive = drive
	fx.post_gain = -2.0
	fx.keep_hf_hz = 2400.0
	AudioServer.add_bus_effect(idx, fx)

func _add_reverb(bus: String, room: float, wet: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectReverb:
			return
	var fx := AudioEffectReverb.new()
	fx.room_size = room
	fx.damping = 0.6
	fx.wet = wet
	fx.dry = 1.0
	fx.spread = 0.8
	AudioServer.add_bus_effect(idx, fx)

# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------

func get_stream(name: String) -> AudioStream:
	if not _generated:
		generate_all()
	return streams.get(name, streams.get("click", null))

func generate_all() -> void:
	_generated = true
	streams.clear()
	streams["hum"] = _wav(_gen_hum(), true)
	streams["pump"] = _wav(_gen_pump(), true)
	streams["drip"] = _wav(_gen_drip(), false)
	streams["creak"] = _wav(_gen_creak(), false)
	streams["bell"] = _wav(_gen_bell(), false)
	streams["ping"] = _wav(_gen_ping(), false)
	streams["whale"] = _wav(_gen_whale(), false)
	streams["knock"] = _wav(_gen_knock(), false)
	streams["static"] = _wav(_gen_static(), true)
	streams["heartbeat"] = _wav(_gen_heartbeat(), true)
	streams["click"] = _wav(_gen_click(), false)
	streams["clunk"] = _wav(_gen_clunk(), false)
	streams["valve"] = _wav(_gen_valve(), false)
	streams["shutter"] = _wav(_gen_shutter(), false)
	streams["alarm"] = _wav(_gen_alarm(), true)
	streams["water"] = _wav(_gen_water(), true)
	streams["chorus"] = _wav(_gen_chorus(), true)
	streams["breath"] = _wav(_gen_breath(), false)
	streams["tape_hiss"] = _wav(_gen_static(), true)
	streams["beep"] = _wav(_gen_beep(), false)
	streams["sonar"] = streams["ping"]
	streams["signal_pump"] = streams["pump"]
	streams["signal_groan"] = streams["creak"]
	streams["signal_bell"] = streams["bell"]
	streams["signal_knock"] = streams["knock"]
	streams["signal_voices"] = streams["chorus"]
	streams["signal_cable"] = streams["creak"]
	streams["signal_fish"] = _wav(_gen_chirp(), false)
	streams["signal_current"] = streams["water"]
	streams["signal_sonar"] = streams["ping"]
	streams["signal_breath"] = streams["breath"]
	print("[SYNTH] generated %d streams" % streams.size())

# ---------------------------------------------------------------------------
# WAV conversion
# ---------------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i], -1.0, 1.0)
		var s := int(round(v * 32767.0))
		data.encode_s16(i * 2, s)
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * seconds))
	return b

func _add_sine(b: PackedFloat32Array, freq: float, amp: float, start: float, dur: float, decay: float) -> void:
	var i0 := maxi(0, int(start * RATE))
	var n := mini(b.size() - i0, int(dur * RATE))
	if n <= 0:
		return
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t / maxf(decay, 0.001))
		b[i0 + i] += sin(TAU_F * freq * t) * amp * env

func _add_glide(b: PackedFloat32Array, f0: float, f1: float, amp: float, start: float, dur: float) -> void:
	var i0 := maxi(0, int(start * RATE))
	var n := mini(b.size() - i0, int(dur * RATE))
	if n <= 0:
		return
	var phase := 0.0
	for i in n:
		var k := float(i) / maxf(1.0, float(n - 1))
		var f := lerpf(f0, f1, k)
		phase += TAU_F * f / RATE
		var env := sin(PI * k)
		b[i0 + i] += sin(phase) * amp * env

func _add_noise_lp(b: PackedFloat32Array, amp: float, start: float, dur: float, cutoff: float, decay: float) -> void:
	var i0 := maxi(0, int(start * RATE))
	var n := mini(b.size() - i0, int(dur * RATE))
	if n <= 0:
		return
	var y := 0.0
	var a := clampf(cutoff / float(RATE), 0.001, 0.9)
	for i in n:
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		y += (x - y) * a
		var env := exp(-t / maxf(decay, 0.001))
		b[i0 + i] += y * amp * env

func _add_thump(b: PackedFloat32Array, start: float, amp: float, freq: float) -> void:
	var i0 := maxi(0, int(start * RATE))
	var n := mini(b.size() - i0, int(0.35 * RATE))
	if n <= 0:
		return
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t / 0.08)
		b[i0 + i] += sin(TAU_F * freq * t) * amp * env
		b[i0 + i] += _rng.randf_range(-1.0, 1.0) * amp * 0.12 * env

# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------

func _gen_hum() -> PackedFloat32Array:
	var b := _buf(4.0)
	for i in b.size():
		var t := float(i) / RATE
		var v := sin(TAU_F * 50.0 * t) * 0.10
		v += sin(TAU_F * 100.0 * t) * 0.045
		v += sin(TAU_F * 150.0 * t) * 0.018
		v += sin(TAU_F * 37.0 * t) * 0.012
		b[i] = v
	_add_noise_lp(b, 0.02, 0.0, 4.0, 200.0, 99.0)
	return b

func _gen_pump() -> PackedFloat32Array:
	var b := _buf(2.0)
	for k in 8:
		_add_thump(b, float(k) * 0.25, 0.35, 58.0)
		_add_noise_lp(b, 0.06, float(k) * 0.25, 0.18, 900.0, 0.08)
	return b

func _gen_drip() -> PackedFloat32Array:
	var b := _buf(0.35)
	_add_sine(b, 1100.0, 0.32, 0.0, 0.08, 0.025)
	_add_sine(b, 640.0, 0.18, 0.01, 0.12, 0.05)
	_add_noise_lp(b, 0.03, 0.0, 0.05, 4000.0, 0.02)
	return b

func _gen_creak() -> PackedFloat32Array:
	var b := _buf(1.8)
	_add_glide(b, 120.0, 52.0, 0.22, 0.0, 1.2)
	_add_glide(b, 181.0, 74.0, 0.10, 0.05, 1.0)
	_add_noise_lp(b, 0.08, 0.0, 1.4, 700.0, 0.6)
	for k in 4:
		_add_sine(b, _rng.randf_range(280.0, 520.0), 0.03, 0.2 + k * 0.27, 0.18, 0.04)
	return b

func _gen_bell() -> PackedFloat32Array:
	var b := _buf(7.0)
	var partials := [47.0, 94.3, 141.9, 188.2, 237.7, 301.4, 389.0]
	var amps := [0.30, 0.22, 0.15, 0.11, 0.07, 0.045, 0.03]
	for p in partials.size():
		_add_sine(b, partials[p], amps[p], 0.0, 6.8, 2.2 + p * 0.35)
	_add_noise_lp(b, 0.02, 0.0, 0.25, 3000.0, 0.1)
	return b

func _gen_ping() -> PackedFloat32Array:
	var b := _buf(1.6)
	_add_sine(b, 1200.0, 0.28, 0.0, 0.35, 0.08)
	_add_sine(b, 1188.0, 0.12, 0.0, 0.5, 0.12)
	_add_sine(b, 1200.0, 0.10, 0.27, 0.4, 0.12)
	_add_sine(b, 1200.0, 0.05, 0.55, 0.5, 0.2)
	_add_noise_lp(b, 0.02, 0.0, 0.2, 5000.0, 0.05)
	return b

func _gen_whale() -> PackedFloat32Array:
	var b := _buf(4.5)
	_add_glide(b, 92.0, 36.0, 0.26, 0.0, 3.4)
	_add_glide(b, 184.0, 72.0, 0.10, 0.15, 3.0)
	_add_glide(b, 276.0, 108.0, 0.035, 0.35, 2.5)
	_add_noise_lp(b, 0.05, 0.0, 3.8, 300.0, 2.0)
	return b

func _gen_knock() -> PackedFloat32Array:
	var b := _buf(0.5)
	_add_thump(b, 0.0, 0.4, 72.0)
	_add_sine(b, 310.0, 0.10, 0.0, 0.35, 0.12)
	_add_sine(b, 470.0, 0.05, 0.01, 0.25, 0.08)
	return b

func _gen_static() -> PackedFloat32Array:
	var b := _buf(1.5)
	var y := 0.0
	for i in b.size():
		var x := _rng.randf_range(-1.0, 1.0)
		y += (x - y) * 0.25
		b[i] = y * 0.12 + sin(TAU_F * 60.0 * float(i) / RATE) * 0.004
	return b

func _gen_heartbeat() -> PackedFloat32Array:
	var b := _buf(1.1)
	_add_thump(b, 0.0, 0.3, 48.0)
	_add_thump(b, 0.18, 0.18, 44.0)
	return b

func _gen_click() -> PackedFloat32Array:
	var b := _buf(0.09)
	_add_noise_lp(b, 0.22, 0.0, 0.03, 7000.0, 0.006)
	_add_sine(b, 1900.0, 0.08, 0.0, 0.04, 0.01)
	return b

func _gen_clunk() -> PackedFloat32Array:
	var b := _buf(0.4)
	_add_thump(b, 0.0, 0.32, 96.0)
	_add_noise_lp(b, 0.12, 0.0, 0.12, 1400.0, 0.04)
	_add_sine(b, 380.0, 0.08, 0.0, 0.25, 0.08)
	return b

func _gen_valve() -> PackedFloat32Array:
	var b := _buf(0.6)
	_add_glide(b, 420.0, 260.0, 0.08, 0.0, 0.35)
	_add_noise_lp(b, 0.04, 0.0, 0.4, 2200.0, 0.12)
	return b

func _gen_shutter() -> PackedFloat32Array:
	var b := _buf(0.25)
	_add_noise_lp(b, 0.3, 0.0, 0.04, 9000.0, 0.008)
	_add_noise_lp(b, 0.18, 0.06, 0.12, 4000.0, 0.03)
	_add_sine(b, 1400.0, 0.05, 0.0, 0.05, 0.01)
	return b

func _gen_alarm() -> PackedFloat32Array:
	var b := _buf(1.2)
	_add_sine(b, 440.0, 0.12, 0.0, 0.28, 0.18)
	_add_sine(b, 660.0, 0.12, 0.3, 0.28, 0.18)
	_add_sine(b, 440.0, 0.12, 0.6, 0.28, 0.18)
	_add_sine(b, 660.0, 0.12, 0.9, 0.28, 0.18)
	return b

func _gen_water() -> PackedFloat32Array:
	var b := _buf(3.0)
	_add_noise_lp(b, 0.06, 0.0, 3.0, 350.0, 99.0)
	for k in 6:
		_add_sine(b, _rng.randf_range(180.0, 420.0), 0.015, _rng.randf_range(0.0, 2.5), 0.4, 0.15)
	return b

func _gen_chorus() -> PackedFloat32Array:
	var b := _buf(8.0)
	var roots := [47.0, 94.0, 141.0, 188.0, 235.0]
	for k in roots.size():
		var f: float = roots[k]
		var phase := _rng.randf_range(0.0, TAU_F)
		for i in b.size():
			var t := float(i) / RATE
			var vib := sin(TAU_F * (0.08 + k * 0.013) * t) * 0.7
			b[i] += sin(TAU_F * (f + vib) * t + phase) * (0.05 / (1.0 + k * 0.6))
	_add_noise_lp(b, 0.025, 0.0, 8.0, 1200.0, 99.0)
	# Slow swell.
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= 0.35 + 0.65 * (0.5 + 0.5 * sin(TAU_F * 0.12 * t - PI / 2.0))
	return b

func _gen_breath() -> PackedFloat32Array:
	var b := _buf(2.2)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		y += (x - y) * 0.08
		var env := sin(PI * clampf(t / 2.2, 0.0, 1.0))
		b[i] = y * 0.35 * env
	return b

func _gen_beep() -> PackedFloat32Array:
	var b := _buf(0.2)
	_add_sine(b, 880.0, 0.12, 0.0, 0.12, 0.05)
	return b

func _gen_chirp() -> PackedFloat32Array:
	var b := _buf(0.8)
	for k in 3:
		_add_glide(b, 1200.0 + k * 180.0, 2200.0 + k * 220.0, 0.08, k * 0.18, 0.12)
	return b
