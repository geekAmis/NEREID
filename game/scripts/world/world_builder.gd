class_name WorldBuilder
extends Node3D
## Внешний мир за иллюминатором: дно, институт, колокольня, дома, кабели,
## взвесь, рыбы и слой аномалий, видимый только на вспышке (layers = 2).

var sim = null
var anomaly_list: Array[Dictionary] = []
var _time := 0.0
var _fish: CPUParticles3D
var _snow: CPUParticles3D
var _bubbles: CPUParticles3D
var _rng := RandomNumberGenerator.new()

func setup(p_sim) -> void:
	sim = p_sim
	_rng.seed = 47047
	_build_seabed()
	_build_institute()
	_build_town()
	_build_cables()
	_build_particles()
	_build_anomalies()

func _process(delta: float) -> void:
	_time += delta
	if _fish != null:
		_fish.position.x = sin(_time * 0.035) * 3.0
	if _snow != null:
		_snow.position.x = sin(_time * 0.02) * 0.7

# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _mat(tex: String, tint: Color, metallic: float, roughness: float, uv: float = 4.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/%s/" % tex
	if ResourceLoader.exists(base + "color.jpg"):
		m.albedo_texture = load(base + "color.jpg") as Texture2D
	if ResourceLoader.exists(base + "normal.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "normal.jpg") as Texture2D
	if ResourceLoader.exists(base + "roughness.jpg"):
		m.roughness_texture = load(base + "roughness.jpg") as Texture2D
	m.albedo_color = tint
	m.metallic = metallic
	m.roughness = roughness
	m.uv1_scale = Vector3(uv, uv, uv)
	m.uv1_triplanar = true
	return m

func _glow_mat(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot: Vector3 = Vector3.ZERO, seg: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

func _build_seabed() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(220.0, 220.0)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	mi.position = Vector3(0.0, -60.0, -20.0)
	mi.material_override = _mat("concrete", Color(0.20, 0.24, 0.22), 0.0, 0.95, 9.0)
	add_child(mi)
	# Камни и обломки.
	var rock_mat := _mat("concrete", Color(0.18, 0.20, 0.18), 0.0, 0.98, 5.0)
	for i in 26:
		var x := _rng.randf_range(-40.0, 40.0)
		var z := _rng.randf_range(-55.0, 5.0)
		var s := _rng.randf_range(0.4, 2.4)
		var mi2 := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = s
		sm.height = s * _rng.randf_range(0.5, 1.4)
		sm.radial_segments = 8
		sm.rings = 5
		mi2.mesh = sm
		mi2.material_override = rock_mat
		mi2.position = Vector3(x, -59.0 + s * 0.35, z)
		mi2.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(mi2)

func _build_institute() -> void:
	var root := Node3D.new()
	root.name = "Institute"
	add_child(root)
	var concrete := _mat("concrete", Color(0.32, 0.36, 0.33), 0.05, 0.88, 4.0)
	# Купол.
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 9.0
	sm.height = 18.0
	sm.radial_segments = 32
	sm.rings = 16
	dome.mesh = sm
	dome.material_override = concrete
	dome.position = Vector3(0.0, -15.0, -21.0)
	dome.scale = Vector3(1.0, 0.62, 1.0)
	root.add_child(dome)
	# Барабан и окна.
	_cyl(root, Vector3(0.0, -19.5, -21.0), 8.7, 3.0, concrete, Vector3.ZERO, 28)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var wx := cos(a) * 8.75
		var wz := -21.0 + sin(a) * 8.75
		var win := _box(root, Vector3(wx, -17.4, wz), Vector3(0.55, 1.55, 0.10), _glow_mat(Color(0.95, 0.63, 0.28), 0.9), Vector3(0, -rad_to_deg(a), 0))
		var l := OmniLight3D.new()
		l.position = win.position + Vector3(wx, 0.0, wz).normalized() * 0.35
		l.light_color = Color(1.0, 0.62, 0.26)
		l.light_energy = 0.65
		l.omni_range = 5.5
		l.shadow_enabled = false
		root.add_child(l)
	# Вход.
	_box(root, Vector3(0.0, -20.0, -12.0), Vector3(3.4, 4.0, 0.4), _mat("metal_plates", Color(0.18, 0.20, 0.19), 0.5, 0.7, 2.0))
	# Колокольня: четыре опоры, крыша, колокол.
	var bell_center := Vector3(4.0, -9.0, -26.0)
	for dx in [-1.15, 1.15]:
		for dz in [-1.15, 1.15]:
			_box(root, bell_center + Vector3(dx, -3.0, dz), Vector3(0.48, 12.0, 0.48), concrete)
	_box(root, bell_center + Vector3(0.0, 3.2, 0.0), Vector3(3.6, 0.35, 3.6), concrete)
	_box(root, bell_center + Vector3(0.0, 4.0, 0.0), Vector3(2.2, 1.4, 2.2), concrete)
	# Колокол.
	var bell_mat := StandardMaterial3D.new()
	bell_mat.albedo_color = Color(0.42, 0.32, 0.16)
	bell_mat.metallic = 1.0
	bell_mat.roughness = 0.38
	bell_mat.emission_enabled = true
	bell_mat.emission = Color(0.12, 0.07, 0.02)
	bell_mat.emission_energy_multiplier = 0.8
	var bell := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.58
	bm.bottom_radius = 1.15
	bm.height = 1.9
	bm.radial_segments = 24
	bell.mesh = bm
	bell.material_override = bell_mat
	bell.position = bell_center + Vector3(0.0, -1.0, 0.0)
	root.add_child(bell)
	_cyl(root, bell_center + Vector3(0.0, -0.05, 0.0), 0.10, 2.0, bell_mat, Vector3.ZERO, 10)
	# Свет у входа.
	var entry := OmniLight3D.new()
	entry.position = Vector3(0.0, -19.0, -11.0)
	entry.light_color = Color(0.75, 0.85, 0.70)
	entry.light_energy = 0.8
	entry.omni_range = 9.0
	entry.shadow_enabled = false
	root.add_child(entry)

func _build_town() -> void:
	var root := Node3D.new()
	root.name = "DrownedTown"
	add_child(root)
	var concrete := _mat("concrete", Color(0.24, 0.27, 0.24), 0.0, 0.9, 3.5)
	var rust := _mat("rust", Color(0.30, 0.22, 0.15), 0.6, 0.8, 3.0)
	var roof := _mat("metal_plates", Color(0.17, 0.18, 0.17), 0.7, 0.72, 2.5)
	for i in 9:
		var x := _rng.randf_range(-32.0, 32.0)
		var z := _rng.randf_range(-42.0, -8.0)
		if absf(x) < 8.0 and z > -30.0:
			continue
		var w := _rng.randf_range(2.2, 4.5)
		var h := _rng.randf_range(3.0, 8.0)
		var d := _rng.randf_range(2.2, 4.5)
		_box(root, Vector3(x, -58.0 + h * 0.5, z), Vector3(w, h, d), concrete, Vector3(0, _rng.randf_range(-20, 20), 0))
		var pr := PrismMesh.new()
		pr.size = Vector3(w + 0.6, w * 0.55, d + 0.6)
		var mi := MeshInstance3D.new()
		mi.mesh = pr
		mi.material_override = roof
		mi.position = Vector3(x, -58.0 + h + w * 0.25, z)
		mi.rotation.y = _rng.randf_range(-0.2, 0.2)
		root.add_child(mi)
		if _rng.randf() < 0.5:
			_box(root, Vector3(x, -55.0 + h * 0.3, z + d * 0.5 + 0.02), Vector3(0.5, 0.7, 0.05), _glow_mat(Color(0.9, 0.58, 0.24), 0.65))
	# Затонувшая баржа.
	_box(root, Vector3(-18.0, -52.0, -32.0), Vector3(12.0, 2.2, 4.0), rust, Vector3(0, 18.0, -8.0))
	_box(root, Vector3(-18.0, -50.0, -32.0), Vector3(4.0, 1.2, 2.4), rust, Vector3(0, 18.0, 0))

func _build_cables() -> void:
	var mat := _mat("rubber", Color(0.035, 0.038, 0.038), 0.1, 0.9, 1.0)
	for i in 3:
		var x := -1.2 + float(i) * 1.2
		_cyl(self, Vector3(x, 18.0, -7.0), 0.07, 46.0, mat, Vector3.ZERO, 8)
	# Трос капсулы вверх: крепится к верхнему люку, а не проходит сквозь кабину.
	var cable := _mat("metal_plates", Color(0.19, 0.20, 0.19), 0.9, 0.45, 2.0)
	_cyl(self, Vector3(0.0, 21.71, 0.32), 0.038, 40.58, cable, Vector3.ZERO, 8)

# ---------------------------------------------------------------------------
# Particles
# ---------------------------------------------------------------------------

func _particle_quad(size: Vector2, color: Color, glow: bool = false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	return q

func _build_particles() -> void:
	_snow = CPUParticles3D.new()
	_snow.name = "MarineSnow"
	_snow.amount = 650
	_snow.lifetime = 24.0
	_snow.preprocess = 18.0
	_snow.position = Vector3(0.0, 0.0, -10.0)
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(9.0, 6.0, 10.0)
	_snow.direction = Vector3(0.08, 0.18, 0.02)
	_snow.spread = 180.0
	_snow.gravity = Vector3(0.0, 0.015, 0.0)
	_snow.initial_velocity_min = 0.01
	_snow.initial_velocity_max = 0.08
	_snow.scale_amount_min = 0.25
	_snow.scale_amount_max = 1.1
	_snow.color = Color(0.66, 0.78, 0.76, 0.34)
	_snow.mesh = _particle_quad(Vector2(0.018, 0.018), Color(0.7, 0.82, 0.80, 0.4))
	add_child(_snow)

	_bubbles = CPUParticles3D.new()
	_bubbles.name = "Bubbles"
	_bubbles.amount = 90
	_bubbles.lifetime = 11.0
	_bubbles.preprocess = 8.0
	_bubbles.position = Vector3(0.0, -16.0, -21.0)
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 3.5
	_bubbles.direction = Vector3(0.0, 1.0, 0.0)
	_bubbles.spread = 28.0
	_bubbles.gravity = Vector3(0.0, 0.18, 0.0)
	_bubbles.initial_velocity_min = 0.35
	_bubbles.initial_velocity_max = 0.9
	_bubbles.scale_amount_min = 0.4
	_bubbles.scale_amount_max = 1.7
	_bubbles.color = Color(0.50, 0.68, 0.72, 0.28)
	_bubbles.mesh = _particle_quad(Vector2(0.035, 0.035), Color(0.55, 0.72, 0.76, 0.3))
	add_child(_bubbles)

	_fish = CPUParticles3D.new()
	_fish.name = "Fish"
	_fish.amount = 34
	_fish.lifetime = 20.0
	_fish.preprocess = 12.0
	_fish.position = Vector3(0.0, -3.0, -12.0)
	_fish.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fish.emission_box_extents = Vector3(12.0, 5.0, 8.0)
	_fish.direction = Vector3(1.0, 0.0, 0.0)
	_fish.spread = 50.0
	_fish.gravity = Vector3(0.0, 0.0, 0.0)
	_fish.initial_velocity_min = 0.18
	_fish.initial_velocity_max = 0.55
	_fish.scale_amount_min = 0.6
	_fish.scale_amount_max = 1.8
	_fish.color = Color(0.03, 0.05, 0.055, 0.75)
	_fish.mesh = _particle_quad(Vector2(0.30, 0.09), Color(0.02, 0.04, 0.045, 0.85))
	add_child(_fish)

# ---------------------------------------------------------------------------
# Anomalies, visible on flash only
# ---------------------------------------------------------------------------

func _build_anomalies() -> void:
	var raw: Variant = null
	if FileAccess.file_exists("res://data/anomalies.json"):
		var f := FileAccess.open("res://data/anomalies.json", FileAccess.READ)
		if f != null:
			raw = JSON.parse_string(f.get_as_text())
			f.close()
	var arr: Array = []
	if typeof(raw) == TYPE_DICTIONARY:
		arr = (raw as Dictionary).get("anomalies", [])
	for a in arr:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var id := str(a.get("id", ""))
		var pos_arr: Array = a.get("position", [0, 0, 0])
		if pos_arr.size() != 3:
			continue
		var pos := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		var node := Node3D.new()
		node.name = "Anomaly_" + id
		node.position = pos
		add_child(node)
		_build_anomaly_mesh(node, id)
		anomaly_list.append({
			"id": id,
			"name": str(a.get("name", id)),
			"position": pos,
			"range": float(a.get("range", 8.0)),
			"target": bool(a.get("target", false)),
		})

func _build_anomaly_mesh(parent: Node3D, id: String) -> void:
	var pale := Color(0.62, 0.90, 0.86, 0.82)
	var mat := _glow_mat(pale, 0.82)
	match id:
		"bell":
			var mi := _torus_mesh(parent, Vector3.ZERO, 0.9, 1.25, mat)
			mi.rotation_degrees.x = 90.0
			_cyl(parent, Vector3(0.0, 0.7, 0.0), 0.05, 1.4, mat, Vector3.ZERO, 8)
		"dome":
			var mi2 := _torus_mesh(parent, Vector3.ZERO, 8.0, 8.35, mat)
			mi2.rotation_degrees.x = 90.0
			mi2.scale = Vector3(1.0, 0.6, 1.0)
		"window":
			_box(parent, Vector3.ZERO, Vector3(2.4, 3.2, 0.06), mat)
		"figure":
			var cap := CapsuleMesh.new()
			cap.radius = 0.42
			cap.height = 3.0
			var f := MeshInstance3D.new()
			f.mesh = cap
			f.material_override = mat
			f.position.y = -0.2
			f.layers = 2
			parent.add_child(f)
		"cables":
			for i in 3:
				_box(parent, Vector3(-0.8 + float(i) * 0.8, 0.0, 0.0), Vector3(0.05, 8.0, 0.05), mat)
		"door":
			_box(parent, Vector3.ZERO, Vector3(2.2, 3.4, 0.12), mat)
			_box(parent, Vector3(0.7, 0.0, 0.08), Vector3(0.08, 0.08, 0.04), _glow_mat(Color(1.0, 0.9, 0.6), 0.9))
		"hand":
			_box(parent, Vector3.ZERO, Vector3(1.4, 1.6, 0.04), mat)
			for i in 4:
				_box(parent, Vector3(-0.5 + float(i) * 0.33, -1.0, 0.02), Vector3(0.16, 0.8, 0.03), mat)
		"choir":
			for i in 5:
				var mi3 := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.35
				sp.height = 0.7
				mi3.mesh = sp
				mi3.material_override = mat
				mi3.position = Vector3(float(i - 2) * 0.9, sin(float(i) * 1.7) * 0.4, float(i % 2) * 0.5)
				mi3.layers = 2
				parent.add_child(mi3)
		_:
			_box(parent, Vector3.ZERO, Vector3(0.6, 0.6, 0.6), mat)
	# Все дочерние меши — только на слое аномалий.
	for c in parent.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).layers = 2

func _torus_mesh(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 40
	tm.ring_segments = 10
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	mi.layers = 2
	parent.add_child(mi)
	return mi
