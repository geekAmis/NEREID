class_name CabinBuilder
extends Node3D
## Процедурная кабина «Нереиды»: сфера с вырезом под иллюминатор, настил,
## рёбра, пульт, приборы, левый и правый борта, корма, свет и коллизии.
## Геометрия детерминирована и не зависит от сцены. Все интерактивные
## устройства складываются в devices[id]; GameScene подписывается на action.

signal action(id: String, value: Variant)

const R := 1.35
const FLOOR_Y := -0.85
const EYE_Y := -0.10
const PORTHOLE_POS := Vector3(0.0, 0.30, -1.28)

var sim = null
var interactive := true
var devices: Dictionary = {}
var glass_material: ShaderMaterial = null
var crt: CRT = null
var water_mesh: MeshInstance3D = null
var leak_particles: CPUParticles3D = null
var leak_puddle: MeshInstance3D = null
var warm_light: OmniLight3D = null
var console_light: OmniLight3D = null
var porthole_light: OmniLight3D = null
var alarm_light: OmniLight3D = null
var gauge_light: OmniLight3D = null
var _font_regular: Font
var _font_bold: Font
var _font_mono: Font
var _mats: Dictionary = {}
var _time := 0.0
var _visual_accum := 0.0
var _wipe_timer := 0.0
var _warm_base := 1.55

func setup(p_sim = null, p_interactive: bool = true) -> void:
	sim = p_sim
	interactive = p_interactive
	_font_regular = load("res://assets/fonts/PT_Sans-Regular.ttf") as Font
	_font_bold = load("res://assets/fonts/PT_Sans-Bold.ttf") as Font
	_font_mono = load("res://assets/fonts/JetBrainsMono.ttf") as Font
	if _font_regular == null:
		_font_regular = ThemeDB.fallback_font
	if _font_bold == null:
		_font_bold = _font_regular
	if _font_mono == null:
		_font_mono = _font_regular
	_build_hull()
	_build_floor()
	_build_ribs()
	_build_porthole()
	_build_console()
	_build_console_devices()
	_build_left_side()
	_build_right_side()
	_build_rear()
	_build_lights()
	_build_collision()
	_refresh_visuals()

func _process(delta: float) -> void:
	_time += delta
	if _wipe_timer > 0.0:
		_wipe_timer = maxf(0.0, _wipe_timer - delta)
		if _wipe_timer <= 0.0 and glass_material != null:
			glass_material.set_shader_parameter("wipe", 0.0)
	# Мерцание лампы 50 Гц — очень лёгкое, чтобы кадр «жил».
	if warm_light != null:
		var flick := 1.0 + sin(_time * TAU * 50.0) * 0.006 + sin(_time * 7.3) * 0.012
		warm_light.light_energy = _warm_base * flick * float(warm_light.get_meta("level", 1.0))
	_visual_accum += delta
	if _visual_accum >= 0.2:
		_visual_accum = 0.0
		_refresh_visuals()

# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _mat(key: String, folder: String, tint: Color, metallic: float, roughness: float, uv: Vector3, triplanar: bool = false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/%s/" % folder
	if ResourceLoader.exists(base + "color.jpg"):
		m.albedo_texture = load(base + "color.jpg") as Texture2D
	if ResourceLoader.exists(base + "normal.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "normal.jpg") as Texture2D
	if ResourceLoader.exists(base + "roughness.jpg"):
		m.roughness_texture = load(base + "roughness.jpg") as Texture2D
	if ResourceLoader.exists(base + "metallic.jpg"):
		m.metallic_texture = load(base + "metallic.jpg") as Texture2D
	if ResourceLoader.exists(base + "ao.jpg"):
		m.ao_enabled = true
		m.ao_texture = load(base + "ao.jpg") as Texture2D
	m.albedo_color = tint
	m.metallic = metallic
	m.roughness = roughness
	m.uv1_scale = uv
	m.uv1_triplanar = triplanar
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

func _plain_mat(key: String, color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.6
	_mats[key] = m
	return m

func _mat_hull() -> StandardMaterial3D:
	var m := _mat("hull", "painted_metal", Color(0.20, 0.30, 0.28), 0.62, 0.62, Vector3(1.6, 1.6, 1.6), true)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _mat_floor() -> StandardMaterial3D:
	return _mat("floor", "metal_plates", Color(0.34, 0.38, 0.38), 0.82, 0.52, Vector3(2.2, 2.2, 2.2), true)

func _mat_rust() -> StandardMaterial3D:
	return _mat("rust", "rust", Color(0.52, 0.36, 0.24), 0.68, 0.74, Vector3(2.4, 2.4, 2.4), true)

func _mat_rubber() -> StandardMaterial3D:
	return _mat("rubber", "rubber", Color(0.08, 0.09, 0.085), 0.0, 0.88, Vector3(2.0, 2.0, 2.0))

func _mat_leather() -> StandardMaterial3D:
	return _mat("leather", "leather", Color(0.23, 0.14, 0.095), 0.0, 0.62, Vector3(1.4, 1.4, 1.4))

func _mat_panel() -> StandardMaterial3D:
	return _mat("panel", "painted_metal", Color(0.17, 0.23, 0.22), 0.58, 0.66, Vector3(2.0, 2.0, 2.0), true)

func _mat_brass() -> StandardMaterial3D:
	return _plain_mat("brass", Color(0.62, 0.47, 0.25), 1.0, 0.34)

func _mat_darkmetal() -> StandardMaterial3D:
	return _plain_mat("darkmetal", Color(0.075, 0.082, 0.078), 0.85, 0.44)

func _mat_cream() -> StandardMaterial3D:
	return _plain_mat("cream", Color(0.79, 0.74, 0.61), 0.0, 0.86)

func _mat_red() -> StandardMaterial3D:
	return _plain_mat("red", Color(0.52, 0.07, 0.045), 0.15, 0.48, Color(0.16, 0.008, 0.0))

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, name_hint: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name_hint != "":
		mi.name = name_hint
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segments: int = 24, name_hint: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name_hint != "":
		mi.name = name_hint
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, name_hint: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name_hint != "":
		mi.name = name_hint
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 20
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _torus(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material, rot_deg: Vector3 = Vector3.ZERO, name_hint: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name_hint != "":
		mi.name = name_hint
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 40
	tm.ring_segments = 12
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _label(parent: Node3D, text: String, pos: Vector3, size_px: int = 24, rot_y_deg: float = 0.0, color: Color = Color(0.83, 0.79, 0.66), width: float = 0.0, bold: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font_bold if bold else _font_regular
	l.font_size = size_px
	l.pixel_size = 0.00125
	l.modulate = color
	l.outline_size = 4
	l.outline_modulate = Color(0.0, 0.0, 0.0, 0.86)
	l.shaded = false
	l.double_sided = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.rotation_degrees.y = rot_y_deg
	if width > 0.0:
		l.width = width
	parent.add_child(l)
	return l

# ---------------------------------------------------------------------------
# Hull
# ---------------------------------------------------------------------------

func _build_hull() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat_steps := 26
	var lon_steps := 48
	var porthole_dir := PORTHOLE_POS.normalized()
	var hole_angle := 0.275
	var points: Array = []
	for lat_i in lat_steps + 1:
		var lat := -PI * 0.5 + PI * float(lat_i) / float(lat_steps)
		var row: Array[Vector3] = []
		for lon_i in lon_steps + 1:
			var lon := TAU * float(lon_i) / float(lon_steps)
			row.append(Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * R)
		points.append(row)

	for lat_i in lat_steps:
		for lon_i in lon_steps:
			var p00: Vector3 = points[lat_i][lon_i]
			var p10: Vector3 = points[lat_i + 1][lon_i]
			var p01: Vector3 = points[lat_i][lon_i + 1]
			var p11: Vector3 = points[lat_i + 1][lon_i + 1]
			var center := (p00 + p10 + p01 + p11) * 0.25
			if center.normalized().angle_to(porthole_dir) < hole_angle:
				continue
			var u0 := float(lon_i) / float(lon_steps)
			var u1 := float(lon_i + 1) / float(lon_steps)
			var v0 := float(lat_i) / float(lat_steps)
			var v1 := float(lat_i + 1) / float(lat_steps)
			_st_quad(st, p00, p10, p11, p01, u0, v0, u1, v1)

	var mesh := st.commit()
	var hull := MeshInstance3D.new()
	hull.name = "PressureHull"
	hull.mesh = mesh
	hull.material_override = _mat_hull()
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(hull)

func _st_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, v0: float, u1: float, v1: float) -> void:
	_st_tri(st, a, b, c, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
	_st_tri(st, a, c, d, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))

func _st_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(-a.normalized())
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(-b.normalized())
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(-c.normalized())
	st.set_uv(uc)
	st.add_vertex(c)

# ---------------------------------------------------------------------------
# Floor, ribs, porthole
# ---------------------------------------------------------------------------

func _build_floor() -> void:
	var floor_mesh := _cyl(self, Vector3(0.0, FLOOR_Y, 0.0), 1.045, 0.07, _mat_floor(), Vector3.ZERO, 56, "Floor")
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Трюмный люк.
	_cyl(self, Vector3(0.0, FLOOR_Y + 0.038, 0.0), 0.33, 0.008, _mat_darkmetal(), Vector3.ZERO, 32, "BilgeHatch")
	for i in 7:
		var z := -0.26 + float(i) * 0.086
		_box(self, Vector3(0.0, FLOOR_Y + 0.045, z), Vector3(0.60, 0.008, 0.014), _mat_rust())
	# Вода.
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader") as Shader
	water_mesh = _cyl(self, Vector3(0.0, FLOOR_Y + 0.075, 0.0), 1.02, 0.012, water_mat, Vector3.ZERO, 48, "BilgeWater")
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Решётка вдоль бортов.
	for side in [-1.0, 1.0]:
		for i in 9:
			var z := -0.9 + float(i) * 0.22
			var x: float = side * sqrt(maxf(0.0, 1.02 * 1.02 - z * z)) * 0.94
			_box(self, Vector3(x, FLOOR_Y + 0.046, z), Vector3(0.08, 0.006, 0.16), _mat_rust())
	# Потолочный люк.
	_cyl(self, Vector3(0.0, 0.835, 0.32), 0.27, 0.03, _mat_darkmetal(), Vector3.ZERO, 28, "TopHatch")
	_torus(self, Vector3(0.0, 0.815, 0.32), 0.18, 0.24, _mat_rust(), Vector3.ZERO, "TopHatchRing")
	for i in 4:
		var ang := TAU * float(i) / 4.0
		_box(self, Vector3(cos(ang) * 0.15, 0.805, 0.32 + sin(ang) * 0.15), Vector3(0.20, 0.012, 0.02), _mat_rust(), Vector3(0, -rad_to_deg(ang), 0))

func _build_ribs() -> void:
	var rib_mesh := BoxMesh.new()
	rib_mesh.size = Vector3(0.052, 0.175, 0.026)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rib_mesh
	var xforms: Array[Transform3D] = []
	for r in 8:
		var lon := TAU * float(r) / 8.0 + 0.18
		for lat_i in 21:
			var lat := deg_to_rad(-72.0 + float(lat_i) * 7.2)
			var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * (R - 0.012)
			var tangent := Vector3(-sin(lat) * cos(lon), cos(lat), -sin(lat) * sin(lon)).normalized()
			var normal := p.normalized()
			var bx := tangent.cross(normal).normalized()
			var basis := Basis(bx, tangent, normal)
			xforms.append(Transform3D(basis, p))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Ribs"
	mmi.multimesh = mm
	mmi.material_override = _mat_rust()
	add_child(mmi)

	# Клёпки по трём обручам.
	var rivet_mesh := SphereMesh.new()
	rivet_mesh.radius = 0.013
	rivet_mesh.height = 0.026
	rivet_mesh.radial_segments = 8
	rivet_mesh.rings = 4
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = rivet_mesh
	var rx: Array[Transform3D] = []
	for ring_y in [-0.58, -0.20, 0.20, 0.58]:
		var ring_r := sqrt(maxf(0.01, R * R - ring_y * ring_y)) - 0.012
		for i in 36:
			var a := TAU * float(i) / 36.0
			rx.append(Transform3D(Basis(), Vector3(cos(a) * ring_r, ring_y, sin(a) * ring_r)))
	rm.instance_count = rx.size()
	for i in rx.size():
		rm.set_instance_transform(i, rx[i])
	var rmi := MultiMeshInstance3D.new()
	rmi.name = "Rivets"
	rmi.multimesh = rm
	rmi.material_override = _mat_darkmetal()
	add_child(rmi)

func _build_porthole() -> void:
	var dir := PORTHOLE_POS.normalized()
	var center := dir * (R - 0.02)
	var rot := Vector3(90.0, 0.0, 0.0)
	_torus(self, center + Vector3(0, 0, -0.015), 0.335, 0.455, _mat_darkmetal(), rot, "PortholeOuterFrame")
	_torus(self, center + Vector3(0, 0, 0.020), 0.300, 0.355, _mat_rust(), rot, "PortholeInnerFrame")
	for i in 10:
		var a := TAU * float(i) / 10.0
		_box(self, center + Vector3(cos(a) * 0.395, sin(a) * 0.395, 0.022), Vector3(0.035, 0.035, 0.018), _mat_brass(), rot)
	glass_material = ShaderMaterial.new()
	glass_material.shader = load("res://shaders/glass.gdshader") as Shader
	glass_material.set_shader_parameter("condensation", 0.55)
	glass_material.set_shader_parameter("wipe", 0.0)
	glass_material.set_shader_parameter("tint", Color(0.31, 0.45, 0.48, 1.0))
	var g := _cyl(self, center + Vector3(0.0, 0.0, -0.002), 0.333, 0.024, glass_material, rot, 48, "PortholeGlass")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label(self, "ИЛЛЮМИНАТОР  ·  Ø 720", Vector3(0.0, 0.70, -1.09), 18, 0.0, Color(0.56, 0.69, 0.65))
	# Протирание стекла.
	var wipe := _device("wipe", Device.Kind.HOLD, Vector3(0.33, 0.10, -1.17), Vector3(0.10, 0.10, 0.08), "ПРОТЕРЕТЬ СТЕКЛО", 0.0)
	wipe.max_hold = 2.0
	_box(wipe, Vector3.ZERO, Vector3(0.075, 0.035, 0.026), _mat_rubber(), Vector3.ZERO, "Wiper")
	_box(wipe, Vector3(0.0, -0.025, 0.005), Vector3(0.05, 0.03, 0.02), _mat_brass())
	wipe.on_hold_complete = _on_hold.bind("wipe")

# ---------------------------------------------------------------------------
# Console
# ---------------------------------------------------------------------------

func _build_console() -> void:
	var tilt := -11.0
	_box(self, Vector3(0.0, -0.415, -0.72), Vector3(1.60, 0.055, 0.42), _mat_panel(), Vector3(tilt, 0, 0), "ConsoleTop")
	_box(self, Vector3(0.0, -0.60, -0.885), Vector3(1.60, 0.32, 0.035), _mat_panel(), Vector3(tilt, 0, 0), "ConsoleFront")
	_box(self, Vector3(0.0, -0.755, -0.89), Vector3(1.64, 0.025, 0.06), _mat_rust(), Vector3.ZERO, "ConsoleKick")
	for side in [-1.0, 1.0]:
		_box(self, Vector3(side * 0.77, -0.60, -0.74), Vector3(0.04, 0.46, 0.40), _mat_darkmetal())
	# Задняя панель со шкалами.
	_box(self, Vector3(0.0, -0.165, -0.995), Vector3(1.55, 0.235, 0.028), _mat_panel(), Vector3(tilt, 0, 0), "GaugePanel")
	_box(self, Vector3(0.0, -0.365, -0.90), Vector3(1.56, 0.022, 0.04), _mat_rust(), Vector3(tilt, 0, 0))
	var console_label := _label(self, "ПУЛЬТ ГИДРОАКУСТИКИ  ·  NEREID-7", Vector3(0.0, -0.515, -0.862), 15, 0.0, Color(0.58, 0.70, 0.60), 1.45, true)
	console_label.rotation_degrees.x = tilt
	# Шкалы.
	var names := [
		["depth", "ГЛУБИНА", 0.0, 80.0, "м"],
		["o2", "КИСЛОРОД", 0.0, 25.0, "%"],
		["co2", "CO₂", 0.0, 6.0, "%"],
		["voltage", "ПИТАНИЕ", 18.0, 30.0, "В"],
		["tension", "ТРОС", 0.0, 4.0, "т"],
	]
	var xs := [-0.56, -0.28, 0.0, 0.28, 0.56]
	for i in names.size():
		var g := Gauge.new()
		g.name = "Gauge_" + str(names[i][0])
		g.position = Vector3(xs[i], -0.145, -0.965)
		g.rotation_degrees.x = tilt
		add_child(g)
		g.setup(sim, str(names[i][0]), str(names[i][1]), float(names[i][2]), float(names[i][3]), str(names[i][4]))
	# CRT.
	crt = CRT.new()
	crt.name = "CRT"
	crt.position = Vector3(-0.27, -0.285, -0.745)
	crt.rotation_degrees.x = tilt
	add_child(crt)
	crt.setup(sim)

func _build_console_devices() -> void:
	# Гидрофон: усиление, фильтр, канал.
	var gain := _knob("gain", Vector3(0.28, -0.335, -0.655), 0.045, "УСИЛЕНИЕ", 0.60, 0.0, 1.0, 0.1)
	_label(self, "0", Vector3(0.23, -0.39, -0.63), 13, 0.0, Color(0.66, 0.62, 0.5))
	_label(self, "10", Vector3(0.33, -0.39, -0.63), 13, 0.0, Color(0.66, 0.62, 0.5))
	var filt := _knob("filter", Vector3(0.45, -0.325, -0.64), 0.036, "ФИЛЬТР", 0.5, 0.0, 1.0, 0.5)
	_label(self, "НЧ / ШИР / ВЧ", Vector3(0.45, -0.39, -0.62), 11, 0.0, Color(0.66, 0.62, 0.5))
	var chan := _knob("channel", Vector3(0.59, -0.32, -0.625), 0.036, "КАНАЛ", 0.0, 0.0, 1.0, 0.5)
	_label(self, "○ / ◒ / ∞", Vector3(0.59, -0.385, -0.60), 12, 0.0, Color(0.66, 0.62, 0.5))
	# Кнопки.
	var ping := _button("ping", Vector3(0.72, -0.315, -0.62), 0.030, "ПИНГ", Color(0.62, 0.12, 0.07))
	var rec := _button("record", Vector3(0.72, -0.395, -0.60), 0.025, "ЗАПИСЬ", Color(0.76, 0.58, 0.16))
	# Тон колокола.
	var trim := _knob("bell_trim", Vector3(0.42, -0.245, -0.72), 0.030, "ТОН 47 Гц", 0.4667, 0.0, 1.0, 0.01)
	_label(self, "40", Vector3(0.355, -0.285, -0.70), 11, 0.0, Color(0.66, 0.62, 0.5))
	_label(self, "55", Vector3(0.485, -0.285, -0.70), 11, 0.0, Color(0.66, 0.62, 0.5))
	# Лебёдка.
	var winch := _knob("winch", Vector3(0.62, -0.40, -0.52), 0.070, "ЛЕБЁДКА", 0.375, 0.0, 1.0, 0.02)
	_label(self, "30", Vector3(0.56, -0.49, -0.51), 11, 0.0, Color(0.66, 0.62, 0.5))
	_label(self, "62", Vector3(0.68, -0.49, -0.51), 11, 0.0, Color(0.66, 0.62, 0.5))
	# Блокнот.
	var nb := _button("notebook", Vector3(0.50, -0.345, -0.60), 0.036, "БЛОКНОТ", Color(0.55, 0.50, 0.36))
	_box(nb, Vector3(0.0, 0.0, 0.016), Vector3(0.145, 0.185, 0.010), _mat_leather(), Vector3.ZERO, "NotebookCover")
	_box(nb, Vector3(0.004, 0.006, 0.0225), Vector3(0.120, 0.158, 0.008), _mat_cream(), Vector3.ZERO, "NotebookPaper")
	for li in 5:
		_box(nb, Vector3(0.004, 0.050 - float(li) * 0.026, 0.0275), Vector3(0.092, 0.0022, 0.0012), _mat_darkmetal())
	_box(nb, Vector3(-0.050, -0.020, 0.0278), Vector3(0.005, 0.095, 0.0012), _mat_red(), Vector3.ZERO, "Bookmark")
	_label(nb, "47", Vector3(0.035, -0.058, 0.029), 9, 0.0, Color(0.22, 0.20, 0.16))
	# Камера на крюке, справа.
	var cam := _button("camera", Vector3(0.94, 0.43, -0.52), 0.050, "ФОТОАППАРАТ", Color(0.10, 0.11, 0.105))
	_box(cam, Vector3.ZERO, Vector3(0.17, 0.12, 0.10), _mat_rubber(), Vector3.ZERO, "CameraBody")
	_cyl(cam, Vector3(0.0, 0.0, 0.06), 0.038, 0.06, _mat_darkmetal(), Vector3(90, 0, 0), 18, "CameraLens")
	_box(cam, Vector3(0.0, 0.07, 0.0), Vector3(0.06, 0.012, 0.06), _mat_darkmetal())
	_label(self, "ФОТО · 12 КАДРОВ", Vector3(0.94, 0.53, -0.54), 12, 0.0, Color(0.66, 0.62, 0.5))

# ---------------------------------------------------------------------------
# Left side
# ---------------------------------------------------------------------------

func _build_left_side() -> void:
	var panel := Node3D.new()
	panel.name = "LeftPanel"
	panel.position = Vector3(-1.00, 0.12, 0.03)
	panel.rotation_degrees.y = 90.0
	add_child(panel)
	_box(panel, Vector3.ZERO, Vector3(0.52, 0.68, 0.05), _mat_panel(), Vector3.ZERO, "BreakerPanel")
	_box(panel, Vector3(0.0, 0.03, 0.030), Vector3(0.46, 0.60, 0.012), _mat_darkmetal())
	_label(panel, "ЩИТОК ПИТАНИЯ", Vector3(0.0, 0.285, 0.045), 15, 0.0, Color(0.76, 0.70, 0.56), 0.46, true)
	var toggles := [
		["main", "ГЛАВНЫЙ", true],
		["life_support", "ЖИЗНЕОБ.", true],
		["lights", "СВЕТ", true],
		["console", "ПУЛЬТ", true],
		["heater", "ОБОГРЕВ", false],
		["pump", "ПОМПА", false],
		["winch", "ЛЕБЁДКА", true],
	]
	for i in toggles.size():
		var row := float(i)
		var ty := 0.205 - row * 0.070
		var d := _device(str(toggles[i][0]), Device.Kind.TOGGLE, Vector3(-0.14, ty, 0.045), Vector3(0.085, 0.060, 0.055), str(toggles[i][1]), 0.0, panel)
		_add_toggle_visual(d, bool(toggles[i][2]))
		d.on_toggle = _on_switch.bind(str(toggles[i][0]))
		_label(panel, str(toggles[i][1]), Vector3(0.10, ty + 0.002, 0.045), 12, 0.0, Color(0.75, 0.72, 0.62), 0.29)
	# Скруббер.
	var scrubber := Node3D.new()
	scrubber.name = "Scrubber"
	scrubber.position = Vector3(-0.99, -0.36, 0.58)
	scrubber.rotation_degrees.y = 90.0
	add_child(scrubber)
	_cyl(scrubber, Vector3(0.0, 0.0, -0.04), 0.115, 0.46, _mat_rust(), Vector3.ZERO, 20, "Canister")
	for i in 3:
		_torus(scrubber, Vector3(0.0, -0.15 + float(i) * 0.15, -0.04), 0.105, 0.125, _mat_darkmetal(), Vector3.ZERO)
	_label(scrubber, "ПАТРОН CO₂", Vector3(0.0, 0.27, 0.02), 13, 0.0, Color(0.76, 0.70, 0.56), 0.30, true)
	var sc := _device("scrubber", Device.Kind.HOLD, Vector3(-0.90, -0.36, 0.58), Vector3(0.14, 0.20, 0.14), "ЗАМЕНИТЬ ПАТРОН", 0.0)
	sc.max_hold = 3.0
	_box(sc, Vector3.ZERO, Vector3(0.10, 0.16, 0.04), _mat_brass(), Vector3.ZERO, "ScrubberHandle")
	sc.on_hold_complete = _on_hold.bind("scrubber")
	# Баллоны O₂.
	_cyl(self, Vector3(-0.79, -0.53, 0.74), 0.065, 0.48, _mat_darkmetal(), Vector3.ZERO, 16, "O2Tank1")
	_cyl(self, Vector3(-0.56, -0.53, 0.86), 0.065, 0.48, _mat_darkmetal(), Vector3.ZERO, 16, "O2Tank2")
	_sphere(self, Vector3(-0.79, -0.28, 0.74), 0.065, _mat_rust())
	_sphere(self, Vector3(-0.56, -0.28, 0.86), 0.065, _mat_rust())
	var valve := _knob("o2", Vector3(-0.70, -0.14, 0.80), 0.045, "КИСЛОРОД", 1.0, 0.0, 1.0, 0.5)
	_label(self, "O₂", Vector3(-0.70, -0.07, 0.80), 18, 0.0, Color(0.58, 0.76, 0.82), 0.2, true)
	# Ручная помпа.
	var pump := _device("manual_pump", Device.Kind.LEVER, Vector3(-0.44, -0.63, 0.60), Vector3(0.16, 0.18, 0.14), "РУЧНАЯ ПОМПА", 0.0)
	_add_lever_visual(pump, _mat_brass())
	pump.on_toggle = _on_lever.bind("manual_pump")
	_label(self, "РУЧНАЯ ПОМПА", Vector3(-0.44, -0.53, 0.60), 11, 0.0, Color(0.70, 0.66, 0.55))
	# Пробоина.
	var patch := _device("patch", Device.Kind.HOLD, Vector3(-0.88, -0.52, -0.52), Vector3(0.14, 0.14, 0.10), "ЗАЛАТАТЬ ПРОБОИНУ", 0.0)
	patch.max_hold = 4.0
	_box(patch, Vector3.ZERO, Vector3(0.13, 0.13, 0.018), _mat_rust(), Vector3(0, 0, 0), "LeakPlate")
	patch.on_hold_complete = _on_hold.bind("patch")
	_label(self, "ТЕЧЬ", Vector3(-0.84, -0.40, -0.52), 14, 0.0, Color(0.86, 0.34, 0.22), 0.2, true)
	leak_particles = CPUParticles3D.new()
	leak_particles.name = "LeakJet"
	leak_particles.position = Vector3(-0.86, -0.48, -0.52)
	leak_particles.amount = 38
	leak_particles.lifetime = 1.1
	leak_particles.direction = Vector3(0.82, -0.18, 0.54)
	leak_particles.spread = 14.0
	leak_particles.gravity = Vector3(0.0, -2.2, 0.0)
	leak_particles.initial_velocity_min = 0.45
	leak_particles.initial_velocity_max = 0.95
	leak_particles.scale_amount_min = 0.35
	leak_particles.scale_amount_max = 1.0
	leak_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	leak_particles.emission_sphere_radius = 0.018
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = Color(0.55, 0.78, 0.82, 0.55)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.vertex_color_use_as_albedo = true
	var qm := QuadMesh.new()
	qm.size = Vector2(0.018, 0.018)
	qm.material = pm
	leak_particles.mesh = qm
	add_child(leak_particles)
	leak_puddle = _cyl(self, Vector3(-0.70, FLOOR_Y + 0.078, -0.36), 0.30, 0.010, _mat_rubber(), Vector3.ZERO, 24, "LeakPuddle")

# ---------------------------------------------------------------------------
# Right side
# ---------------------------------------------------------------------------

func _build_right_side() -> void:
	# Рация.
	var radio := Node3D.new()
	radio.name = "RadioPanel"
	radio.position = Vector3(1.00, 0.27, 0.09)
	radio.rotation_degrees.y = -90.0
	add_child(radio)
	_box(radio, Vector3.ZERO, Vector3(0.36, 0.24, 0.06), _mat_panel(), Vector3.ZERO, "RadioBody")
	_box(radio, Vector3(0.0, 0.0, 0.036), Vector3(0.30, 0.17, 0.012), _mat_darkmetal())
	_label(radio, "РАЦИЯ  ·  КАНАЛ 1", Vector3(0.0, 0.145, 0.045), 13, 0.0, Color(0.76, 0.70, 0.56), 0.34, true)
	var radio_ch := _knob("radio_channel", Vector3(-0.10, 0.02, 0.062), 0.032, "КАНАЛ", 0.0, 0.0, 1.0, 0.5, radio)
	var transmit := _button("transmit", Vector3(0.10, 0.02, 0.062), 0.028, "ПЕРЕДАТЬ", Color(0.72, 0.32, 0.08), radio)
	_label(radio, "ВЕРА", Vector3(0.10, -0.085, 0.045), 11, 0.0, Color(0.58, 0.74, 0.66))
	# Магнитофон.
	var deck := Node3D.new()
	deck.name = "TapeDeck"
	deck.position = Vector3(1.00, -0.01, -0.27)
	deck.rotation_degrees.y = -90.0
	add_child(deck)
	_box(deck, Vector3.ZERO, Vector3(0.44, 0.29, 0.07), _mat_darkmetal(), Vector3.ZERO, "TapeDeckBody")
	_box(deck, Vector3(0.0, 0.0, 0.042), Vector3(0.32, 0.16, 0.012), _mat_rubber())
	_label(deck, "МАГНИТОФОН · ГРИНБЕРГ", Vector3(0.0, 0.175, 0.055), 12, 0.0, Color(0.76, 0.70, 0.56), 0.42, true)
	for i in 2:
		_cyl(deck, Vector3(-0.10 + float(i) * 0.20, 0.02, 0.052), 0.038, 0.012, _mat_rust(), Vector3(90, 0, 0), 18, "Reel")
	var tape_next := _button("tape_next", Vector3(-0.12, -0.10, 0.062), 0.022, "ЛЕНТА", Color(0.56, 0.48, 0.30), deck)
	var tape_play := _button("tape_play", Vector3(0.12, -0.10, 0.062), 0.026, "ПУСК", Color(0.12, 0.48, 0.24), deck)
	# Доска фото.
	var board := Node3D.new()
	board.name = "PhotoBoard"
	board.position = Vector3(1.05, 0.40, 0.56)
	board.rotation_degrees.y = -90.0
	add_child(board)
	_box(board, Vector3.ZERO, Vector3(0.54, 0.74, 0.035), _mat_leather(), Vector3.ZERO, "CorkBoard")
	_box(board, Vector3.ZERO, Vector3(0.58, 0.78, 0.020), _mat_rust(), Vector3(0, 0, -0.02), "BoardFrame")
	for row in 4:
		for col in 3:
			var px := -0.15 + float(col) * 0.15
			var py := 0.24 - float(row) * 0.16
			_box(board, Vector3(px, py, 0.026), Vector3(0.11, 0.13, 0.004), _mat_cream(), Vector3(0, 0, 0), "Slot")
	_label(board, "ДОСКА ФОТО · 0 / 12", Vector3(0.0, 0.405, 0.035), 12, 0.0, Color(0.80, 0.74, 0.58), 0.52, true)
	var pb := _device("photo_board", Device.Kind.BUTTON, Vector3(1.00, 0.40, 0.56), Vector3(0.48, 0.68, 0.08), "ОТКРЫТЬ ДОСКУ", -90.0)
	pb.on_press = _on_press.bind("photo_board")

# ---------------------------------------------------------------------------
# Rear
# ---------------------------------------------------------------------------

func _build_rear() -> void:
	# Кормовой люк.
	_cyl(self, Vector3(0.0, 0.04, 1.23), 0.30, 0.035, _mat_darkmetal(), Vector3(90, 0, 0), 28, "RearHatch")
	_torus(self, Vector3(0.0, 0.04, 1.20), 0.21, 0.30, _mat_rust(), Vector3(90, 0, 0), "RearHatchRing")
	_torus(self, Vector3(0.0, 0.04, 1.185), 0.13, 0.22, _mat_brass(), Vector3(90, 0, 0), "HatchWheel")
	for i in 4:
		var a := TAU * float(i) / 4.0
		_box(self, Vector3(cos(a) * 0.10, 0.04 + sin(a) * 0.10, 1.18), Vector3(0.16, 0.015, 0.02), _mat_brass(), Vector3(0, 0, rad_to_deg(a)))
	_label(self, "ЛЮК · ЗАБЛОКИРОВАН", Vector3(0.0, 0.37, 1.18), 11, 0.0, Color(0.72, 0.55, 0.42), 0.4)
	# Полка.
	_box(self, Vector3(0.58, -0.03, 1.14), Vector3(0.64, 0.03, 0.18), _mat_panel(), Vector3.ZERO, "Shelf")
	var th := _device("thermos", Device.Kind.BUTTON, Vector3(0.58, 0.06, 1.10), Vector3(0.10, 0.18, 0.10), "ТЕРМОС", 180.0)
	_cyl(th, Vector3.ZERO, 0.042, 0.16, _mat_cream(), Vector3.ZERO, 16, "ThermosBody")
	_cyl(th, Vector3(0.0, 0.09, 0.0), 0.033, 0.035, _mat_red(), Vector3.ZERO, 16, "ThermosCap")
	# Семейное фото.
	_box(self, Vector3(-0.52, 0.16, 1.20), Vector3(0.20, 0.15, 0.012), _mat_cream(), Vector3(0, 0, 0), "FamilyPhoto")
	_label(self, "1976", Vector3(-0.52, 0.065, 1.19), 10, 0.0, Color(0.55, 0.50, 0.40))
	# Аварийные рычаги.
	var cutter := _device("cable_cutter", Device.Kind.LEVER, Vector3(-0.34, -0.36, 1.06), Vector3(0.14, 0.18, 0.12), "ПЕРЕРЕЗАТЬ ТРОС", 180.0)
	_add_lever_visual(cutter, _mat_red())
	cutter.on_toggle = _on_lever.bind("cable_cutter")
	_label(self, "ТРОС", Vector3(-0.34, -0.24, 1.03), 11, 0.0, Color(0.82, 0.32, 0.22))
	var ballast := _device("ballast", Device.Kind.LEVER, Vector3(0.34, -0.36, 1.06), Vector3(0.14, 0.18, 0.12), "СБРОСИТЬ БАЛЛАСТ", 180.0)
	_add_lever_visual(ballast, _mat_brass())
	ballast.on_toggle = _on_lever.bind("ballast")
	_label(self, "БАЛЛАСТ", Vector3(0.34, -0.24, 1.03), 11, 0.0, Color(0.82, 0.66, 0.32))
	# Трубы по корме.
	_cyl(self, Vector3(0.82, 0.28, 0.88), 0.035, 0.5, _mat_rust(), Vector3(0, 0, -24), 12, "Pipe")
	_cyl(self, Vector3(-0.82, 0.10, 0.95), 0.028, 0.6, _mat_rust(), Vector3(0, 0, 18), 12, "Pipe2")

# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	warm_light = OmniLight3D.new()
	warm_light.name = "WarmLamp"
	warm_light.position = Vector3(0.0, 0.70, -0.28)
	warm_light.light_color = Color(1.0, 0.69, 0.37)
	warm_light.light_energy = _warm_base
	warm_light.omni_range = 4.0
	warm_light.omni_attenuation = 1.35
	warm_light.shadow_enabled = true
	warm_light.shadow_bias = 0.03
	add_child(warm_light)
	_cyl(self, Vector3(0.0, 0.805, -0.28), 0.135, 0.10, _mat_darkmetal(), Vector3.ZERO, 20, "LampShade")
	var bulb_mat := _plain_mat("bulb", Color(1.0, 0.82, 0.52), 0.0, 0.2, Color(1.0, 0.60, 0.22))
	_sphere(self, Vector3(0.0, 0.745, -0.28), 0.042, bulb_mat, "LampBulb")
	_label(self, "47", Vector3(0.0, 0.785, -0.36), 9, 0.0, Color(0.28, 0.24, 0.16))

	console_light = OmniLight3D.new()
	console_light.name = "ConsoleGlow"
	console_light.position = Vector3(-0.27, -0.17, -0.60)
	console_light.light_color = Color(0.35, 1.0, 0.55)
	console_light.light_energy = 0.38
	console_light.omni_range = 1.25
	console_light.shadow_enabled = false
	add_child(console_light)

	porthole_light = OmniLight3D.new()
	porthole_light.name = "PortholeGlow"
	porthole_light.position = Vector3(0.0, 0.30, -1.02)
	porthole_light.light_color = Color(0.20, 0.52, 0.62)
	porthole_light.light_energy = 0.60
	porthole_light.omni_range = 1.8
	porthole_light.shadow_enabled = false
	add_child(porthole_light)

	alarm_light = OmniLight3D.new()
	alarm_light.name = "AlarmLamp"
	alarm_light.position = Vector3(0.0, -0.18, 0.72)
	alarm_light.light_color = Color(1.0, 0.12, 0.06)
	alarm_light.light_energy = 0.0
	alarm_light.omni_range = 2.4
	alarm_light.shadow_enabled = true
	add_child(alarm_light)
	_sphere(self, Vector3(0.0, -0.16, 0.72), 0.035, _plain_mat("alarmbulb", Color(0.4, 0.03, 0.02), 0.0, 0.35, Color(0.5, 0.02, 0.0)), "AlarmBulb")

	gauge_light = OmniLight3D.new()
	gauge_light.name = "GaugeGlow"
	gauge_light.position = Vector3(0.0, 0.02, -0.84)
	gauge_light.light_color = Color(0.92, 0.86, 0.67)
	gauge_light.light_energy = 0.22
	gauge_light.omni_range = 0.95
	gauge_light.shadow_enabled = false
	add_child(gauge_light)

	# Холодный столб света с поверхности через иллюминатор.
	var beam := SpotLight3D.new()
	beam.name = "SurfaceBeam"
	beam.position = Vector3(0.0, 0.62, -3.2)
	beam.rotation_degrees = Vector3(-14.0, 180.0, 0.0)
	beam.light_color = Color(0.34, 0.62, 0.72)
	beam.light_energy = 4.2
	beam.spot_range = 6.0
	beam.spot_angle = 21.0
	beam.spot_angle_attenuation = 0.8
	beam.shadow_enabled = true
	add_child(beam)

# ---------------------------------------------------------------------------
# Collision
# ---------------------------------------------------------------------------

func _build_collision() -> void:
	# Пол и пульт — единственные жёсткие препятствия. Стену держит clamp игрока.
	_add_static_box(Vector3(0.0, FLOOR_Y - 0.05, 0.0), Vector3(2.2, 0.10, 2.2), "FloorBody")
	_add_static_box(Vector3(0.0, -0.52, -0.76), Vector3(1.70, 0.78, 0.50), "ConsoleBody")
	_add_static_box(Vector3(0.0, -0.16, -0.99), Vector3(1.58, 0.26, 0.10), "GaugeBody")

func _add_static_box(pos: Vector3, size: Vector3, name_hint: String) -> void:
	var body := StaticBody3D.new()
	body.name = name_hint
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

# ---------------------------------------------------------------------------
# Device factories
# ---------------------------------------------------------------------------

func _device(id: String, kind: Device.Kind, pos: Vector3, size: Vector3, prompt: String, rot_y: float = 0.0, parent: Node3D = null) -> Device:
	var d := Device.new()
	d.name = "Dev_" + id
	d.position = pos
	d.rotation_degrees.y = rot_y
	(parent if parent != null else self).add_child(d)
	d.setup_device(kind, prompt, size, sim)
	devices[id] = d
	return d

func _add_toggle_visual(d: Device, initial: bool) -> void:
	_box(d, Vector3(0.0, 0.0, -0.004), Vector3(0.075, 0.105, 0.025), _mat_darkmetal(), Vector3.ZERO, "ToggleBase")
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, 0.014)
	d.add_child(pivot)
	d.lever_pivot = pivot
	var lever := _box(pivot, Vector3(0.0, 0.032, 0.0), Vector3(0.018, 0.070, 0.016), _mat_brass(), Vector3.ZERO, "ToggleLever")
	_box(pivot, Vector3(0.0, 0.067, 0.0), Vector3(0.028, 0.014, 0.020), _mat_cream())
	d.set_value(1.0 if initial else 0.0)

func _knob(id: String, pos: Vector3, radius: float, prompt: String, initial: float, minv: float, maxv: float, step: float, parent: Node3D = null) -> Device:
	var d := _device(id, Device.Kind.KNOB, pos, Vector3(radius * 2.5, radius * 2.5, 0.055), prompt, 0.0, parent)
	d.min_value = minv
	d.max_value = maxv
	d.step_value = step
	_cyl(d, Vector3.ZERO, radius, 0.020, _mat_darkmetal(), Vector3(90, 0, 0), 24, "KnobBase")
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, 0.017)
	d.add_child(pivot)
	d.wheel_pivot = pivot
	_cyl(pivot, Vector3.ZERO, radius * 0.76, 0.026, _mat_brass(), Vector3(90, 0, 0), 20, "Knob")
	_box(pivot, Vector3(0.0, radius * 0.42, 0.010), Vector3(0.006, radius * 0.52, 0.006), _mat_cream(), Vector3.ZERO, "KnobMark")
	_label(d, prompt, Vector3(0.0, radius + 0.030, 0.012), 11, 0.0, Color(0.79, 0.74, 0.61), maxf(0.18, radius * 5.0), true)
	d.on_value = _on_knob.bind(id)
	d.set_value(initial, true)
	return d

func _button(id: String, pos: Vector3, radius: float, prompt: String, color: Color, parent: Node3D = null) -> Device:
	var d := _device(id, Device.Kind.BUTTON, pos, Vector3(radius * 2.4, radius * 2.4, 0.05), prompt, 0.0, parent)
	_cyl(d, Vector3.ZERO, radius * 1.15, 0.012, _mat_darkmetal(), Vector3(90, 0, 0), 20, "ButtonBase")
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, 0.008)
	d.add_child(pivot)
	d.wheel_pivot = pivot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.15
	mat.roughness = 0.38
	mat.emission_enabled = true
	mat.emission = color * 0.20
	mat.emission_energy_multiplier = 0.5
	_cyl(pivot, Vector3.ZERO, radius * 0.82, 0.022, mat, Vector3(90, 0, 0), 20, "ButtonCap")
	_label(d, prompt, Vector3(0.0, -radius - 0.032, 0.012), 10, 0.0, Color(0.78, 0.73, 0.60), maxf(0.18, radius * 6.0), true)
	d.on_press = _on_press.bind(id)
	return d

func _add_lever_visual(d: Device, mat: Material) -> void:
	_box(d, Vector3(0.0, 0.0, -0.01), Vector3(0.10, 0.12, 0.035), _mat_darkmetal())
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, 0.015)
	d.add_child(pivot)
	d.lever_pivot = pivot
	_box(pivot, Vector3(0.0, 0.050, 0.0), Vector3(0.022, 0.105, 0.020), mat)
	_sphere(pivot, Vector3(0.0, 0.108, 0.0), 0.024, mat)
	d.set_value(0.0)

# ---------------------------------------------------------------------------
# Device callbacks
# ---------------------------------------------------------------------------

func _on_switch(on: bool, id: String) -> void:
	if id == "main":
		if sim != null:
			for k in ["life_support", "lights", "console", "heater", "pump", "winch"]:
				sim.set_switch(k, on)
	else:
		if sim != null:
			sim.set_switch(id, on)
	action.emit(id, on)

func _on_knob(value: float, id: String) -> void:
	if sim != null:
		match id:
			"gain":
				sim.set_gain(value * 10.0)
			"filter":
				sim.set_filter_mode(int(round(value * 2.0)))
			"channel":
				sim.set_channel_mode(int(round(value * 2.0)))
			"winch":
				sim.set_target_depth(lerpf(30.0, 62.0, value))
			"bell_trim":
				sim.set_bell_trim(40.0 + value * 15.0)
			"o2":
				sim.set_o2_valve(value > 0.5)
			"radio_channel":
				sim.set_radio_channel(1 + int(round(value * 2.0)))
	action.emit(id, value)

func _on_press(id: String) -> void:
	if sim != null:
		match id:
			"ping":
				if sim.ping():
					action.emit("ping", true)
				else:
					return
			"thermos":
				sim.drink_thermos()
	action.emit(id, null)

func _on_hold(id: String) -> void:
	if sim != null:
		match id:
			"scrubber":
				sim.replace_scrubber()
			"patch":
				sim.patch_leak()
			"wipe":
				wipe_glass()
	action.emit(id, null)

func _on_lever(on: bool, id: String) -> void:
	if id == "manual_pump":
		if sim != null:
			sim.pump_manual_step(on)
		action.emit(id, on)
		return
	if on:
		action.emit(id, true)

func _on_switch_sound(_on: bool) -> void:
	pass

# ---------------------------------------------------------------------------
# Visual sync
# ---------------------------------------------------------------------------

func wipe_glass() -> void:
	_wipe_timer = 60.0
	if glass_material != null:
		glass_material.set_shader_parameter("wipe", 1.0)

func _refresh_visuals() -> void:
	if sim == null:
		return
	var level := clampf(sim.water_cm, 0.0, 18.0)
	if water_mesh != null:
		water_mesh.position.y = FLOOR_Y + 0.075 + level * 0.01
		water_mesh.visible = sim.water_cm > 0.15
	if leak_particles != null:
		leak_particles.emitting = not sim.leak_patched and sim.leak_rate > 5.0
	if leak_puddle != null:
		leak_puddle.visible = sim.water_cm > 0.5
		leak_puddle.scale = Vector3(1.0 + clampf(sim.water_cm / 24.0, 0.0, 1.0) * 0.8, 1.0, 1.0)
	if glass_material != null:
		var cond := clampf(0.18 + (14.0 - sim.temperature) / 12.0 + sim.humidity / 240.0, 0.0, 0.9)
		glass_material.set_shader_parameter("condensation", cond)
	if warm_light != null:
		var on: bool = bool(sim.switches.get("lights", true)) and not sim.short_circuit
		warm_light.set_meta("level", 1.0 if on else 0.0)
		warm_light.light_energy = _warm_base if on else 0.0
	if console_light != null:
		var con: bool = bool(sim.switches.get("console", true)) and not sim.short_circuit
		console_light.light_energy = 0.38 if con else 0.0
	if porthole_light != null:
		porthole_light.light_energy = 0.55 + 0.10 * sin(_time * 0.7)
	if gauge_light != null:
		gauge_light.light_energy = 0.22 if bool(sim.switches.get("console", true)) else 0.0
	if alarm_light != null:
		var emergency: bool = sim.short_circuit or sim.hull < 55.0 or sim.water_cm > 12.0
		alarm_light.light_energy = (0.85 if emergency else 0.0) * (0.55 + 0.45 * sin(_time * TAU * 0.8))
	if crt != null:
		crt.visible = bool(sim.switches.get("console", true)) and not sim.short_circuit
