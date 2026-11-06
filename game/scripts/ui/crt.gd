class_name CRT
extends Node3D
## Диегетический CRT: SubViewport 512×256, осциллограф + водопад,
## плюс шейдер развёртки/свечения на кваде.

var sim = null
var viewport: SubViewport
var screen: Control
var waveform := PackedFloat32Array()
var history: Array = []
var _accum := 0.0
var _time := 0.0
var _font: Font

const HISTORY_COLS := 96
const BANDS := 24

class Screen extends Control:
	var host = null
	func _ready() -> void:
		size = Vector2(512, 256)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		if host != null:
			host.tick(delta)
			queue_redraw()
	func _draw() -> void:
		if host == null:
			return
		host.draw_screen(self)

func setup(p_sim) -> void:
	sim = p_sim
	_font = load("res://assets/fonts/JetBrainsMono.ttf")
	for i in HISTORY_COLS:
		var col := PackedFloat32Array()
		col.resize(BANDS)
		history.append(col)
	waveform.resize(160)
	_build()

func _build() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	add_child(viewport)
	screen = Screen.new()
	screen.host = self
	viewport.add_child(screen)

	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.36, 0.18)
	quad.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	mat.set_shader_parameter("screen_tex", viewport.get_texture())
	mat.set_shader_parameter("glow", 1.35)
	quad.material_override = mat
	quad.position.z = 0.012
	add_child(quad)

	# Рамка.
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.395, 0.215, 0.012)
	frame.mesh = frame_mesh
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.045, 0.05, 0.045)
	frame_mat.metallic = 0.5
	frame_mat.roughness = 0.5
	frame.material_override = frame_mat
	frame.position.z = -0.004
	add_child(frame)

	# Зелёная подсветка.
	var light := OmniLight3D.new()
	light.light_color = Color(0.28, 1.0, 0.48)
	light.light_energy = 0.45
	light.omni_range = 0.9
	light.shadow_enabled = false
	light.position = Vector3(0, 0.02, 0.18)
	add_child(light)

func tick(delta: float) -> void:
	_time += delta
	_accum += delta
	if _accum < 0.06:
		return
	_accum = 0.0
	for i in waveform.size():
		var t := _time * 2.0 + float(i) / float(waveform.size()) * 0.18
		waveform[i] = _sample(t)
	if int(_time * 12.0) % 2 == 0:
		_push_history()

func _sample(t: float) -> float:
	var id: String = sim.current_signal if sim != null else ""
	var n := 0.0
	match id:
		"pump":
			n = sin(TAU * 58.0 * t) * (0.45 + 0.45 * sin(TAU * 2.0 * t))
		"groan":
			n = sin(TAU * (90.0 - 34.0 * fmod(t, 1.4)) * t) * 0.65
			n += sin(TAU * 181.0 * t) * 0.18
		"bell":
			n = sin(TAU * 47.0 * t) * 0.55 + sin(TAU * 94.0 * t) * 0.3 + sin(TAU * 141.0 * t) * 0.15
		"voices":
			n = sin(TAU * 47.0 * t) * 0.35 + sin(TAU * 94.3 * t) * 0.25 + sin(TAU * 141.9 * t) * 0.2
			n += sin(TAU * 188.2 * t) * 0.12
		"sonar", "ping":
			var env := exp(-fmod(t * 2.0, 1.0) * 9.0)
			n = sin(TAU * 1200.0 * t) * env * 0.8
		"knock":
			var env2 := exp(-fmod(t * 1.1, 0.5) * 12.0)
			n = sin(TAU * 72.0 * t) * env2 * 0.8
		"fish":
			n = sin(TAU * 1600.0 * t) * 0.25 * (0.5 + 0.5 * sin(TAU * 3.0 * t))
		"breath":
			n = sin(TAU * 42.0 * t) * 0.35 * (0.5 + 0.5 * sin(TAU * 0.25 * t))
		"current":
			n = sin(TAU * 33.0 * t) * 0.2
		_:
			n = sin(TAU * 50.0 * t) * 0.015
	# Детерминированный шум.
	n += sin(TAU * 371.0 * t + sin(TAU * 13.0 * t) * 3.0) * 0.018
	if sim != null:
		n *= 0.45 + sim.signal_strength * 0.55
		if sim.ping_flash > 0.0:
			n = sin(TAU * 1200.0 * t) * 0.8
	return clampf(n, -1.0, 1.0)

func _push_history() -> void:
	var col := PackedFloat32Array()
	col.resize(BANDS)
	var id: String = sim.current_signal if sim != null else ""
	for b in BANDS:
		var f := 20.0 * pow(120.0, float(b) / float(BANDS - 1))
		var energy := 0.02
		match id:
			"pump":
				energy = 0.85 if b <= 2 else 0.08
			"bell":
				energy = 0.9 if b in [2, 3] else 0.12
			"voices":
				energy = 0.6 if b < 8 else 0.18
			"sonar", "ping":
				energy = 0.9 if b >= 18 else 0.05
			"groan":
				energy = 0.5 if b < 6 else 0.06
			"breath":
				energy = 0.3 if b < 5 else 0.04
			"fish":
				energy = 0.55 if b >= 15 else 0.05
			_:
				energy = 0.05
		col[b] = clampf(energy + sin(float(b) * 0.7 + _time * 2.0) * 0.04, 0.0, 1.0)
	history.pop_front()
	history.push_back(col)

func draw_screen(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 512, 256), Color(0.012, 0.055, 0.028))
	# Сетка.
	for x in range(0, 512, 32):
		ci.draw_line(Vector2(x, 0), Vector2(x, 256), Color(0.08, 0.3, 0.14, 0.35), 1.0)
	for y in range(0, 256, 32):
		ci.draw_line(Vector2(0, y), Vector2(512, y), Color(0.08, 0.3, 0.14, 0.35), 1.0)
	# Волна.
	var pts := PackedVector2Array()
	for i in waveform.size():
		var x := float(i) / float(waveform.size() - 1) * 512.0
		var y := 128.0 - waveform[i] * 74.0 * clampf(0.4 + (sim.gain / 10.0 if sim != null else 0.5), 0.0, 1.1)
		pts.append(Vector2(x, y))
	if pts.size() > 1:
		ci.draw_polyline(pts, Color(0.49, 1.0, 0.63), 1.6)
	# Водопад.
	var w := 512.0 / float(HISTORY_COLS)
	for c in history.size():
		var col: PackedFloat32Array = history[c]
		for b in BANDS:
			var v: float = col[b]
			var color := Color(0.1 + v * 0.45, 0.3 + v * 0.7, 0.15 + v * 0.4, 0.55)
			ci.draw_rect(Rect2(float(c) * w, 150.0 + float(BANDS - 1 - b) * 4.0, w + 0.5, 4.0), color)
	# Текст.
	var font := _font
	if font == null:
		font = ThemeDB.fallback_font
	ci.draw_string(font, Vector2(12, 20), "NEREID-7 · HYDRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 1.0, 0.72))
	ci.draw_string(font, Vector2(380, 20), "47.0 Hz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 1.0, 0.72))
	if sim != null:
		var sig: String = sim.current_signal
		var txt := "—"
		if sig != "":
			txt = sig.to_upper()
		ci.draw_string(font, Vector2(12, 248), "SIG: %s  G%.1f  CH%d  F%d" % [txt, sim.gain, sim.channel_mode + 1, sim.filter_mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.9, 0.55))
		if sim.ping_flash > 0.0:
			ci.draw_string(font, Vector2(360, 248), "PING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.7, 0.3))
	# Виньетка.
	for i in 8:
		ci.draw_rect(Rect2(i, i, 512 - i * 2, 256 - i * 2), Color(0, 0, 0, 0), false, 1.0, false)
