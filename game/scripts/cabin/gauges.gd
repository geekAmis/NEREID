class_name Gauge
extends Node3D
## Стрелочный прибор. Лицо рисуется в ImageTexture, стрелка — 3D-меш.

@export var source := "depth"
@export var display_name := "ГЛУБИНА"
@export var unit := "м"
@export var min_value := 0.0
@export var max_value := 80.0
@export var value := 0.0
@export var dial_radius := 0.105

var sim = null
var _needle: Node3D
var _value_label: Label3D
var _font: Font

func setup(p_sim, p_source: String, p_name: String, p_min: float, p_max: float, p_unit: String) -> void:
	sim = p_sim
	source = p_source
	display_name = p_name
	min_value = p_min
	max_value = p_max
	unit = p_unit
	_build()

func _build() -> void:
	_font = load("res://assets/fonts/PT_Sans-Bold.ttf")
	# Корпус.
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = dial_radius + 0.012
	cyl.bottom_radius = dial_radius + 0.012
	cyl.height = 0.018
	cyl.radial_segments = 32
	body.mesh = cyl
	body.rotation_degrees.x = 90.0
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.11)
	metal.metallic = 0.8
	metal.roughness = 0.45
	body.material_override = metal
	add_child(body)

	# Лицо.
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(dial_radius * 2.0, dial_radius * 2.0)
	face.mesh = quad
	face.position.z = 0.011
	var face_mat := StandardMaterial3D.new()
	face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_mat.albedo_texture = _make_dial_texture()
	face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	face.material_override = face_mat
	add_child(face)

	# Стрелка.
	_needle = Node3D.new()
	_needle.position.z = 0.018
	add_child(_needle)
	var needle_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.004, dial_radius * 0.78, 0.003)
	needle_mesh.mesh = box
	needle_mesh.position.y = dial_radius * 0.36
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.16, 0.08)
	red.emission_enabled = true
	red.emission = Color(0.6, 0.08, 0.03)
	red.emission_energy_multiplier = 0.6
	needle_mesh.material_override = red
	_needle.add_child(needle_mesh)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.009
	hub_mesh.bottom_radius = 0.009
	hub_mesh.height = 0.006
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.rotation_degrees.x = 90.0
	hub.position.z = 0.006
	hub.material_override = metal
	_needle.add_child(hub)

	# Подписи.
	var name_label := Label3D.new()
	name_label.text = display_name
	name_label.font = _font
	name_label.font_size = 24
	name_label.pixel_size = 0.0011
	name_label.modulate = Color(0.91, 0.87, 0.77)
	name_label.outline_size = 3
	name_label.outline_modulate = Color(0, 0, 0, 0.8)
	name_label.position = Vector3(0, -dial_radius - 0.012, 0.030)
	add_child(name_label)

	_value_label = Label3D.new()
	_value_label.text = "—"
	_value_label.font = _font
	_value_label.font_size = 22
	_value_label.pixel_size = 0.0011
	_value_label.modulate = Color(0.49, 1.0, 0.63)
	_value_label.outline_size = 3
	_value_label.outline_modulate = Color(0, 0, 0, 0.85)
	_value_label.position = Vector3(0, -dial_radius - 0.062, 0.030)
	add_child(_value_label)

	if sim != null:
		sim.changed.connect(_refresh)
	_refresh()

func _make_dial_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.055, 0.068, 0.06, 1.0))
	var c := Vector2(size * 0.5, size * 0.5)
	var r := size * 0.47
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r - 2.0:
				img.set_pixel(x, y, Color(0.45, 0.4, 0.3, 1.0))
	# Риски.
	for i in 11:
		var t := float(i) / 10.0
		var ang := deg_to_rad(lerpf(-135.0, 135.0, t))
		var dir := Vector2(sin(ang), -cos(ang))
		var inner := c + dir * (r - (10.0 if i % 5 == 0 else 6.0))
		var outer := c + dir * (r - 3.0)
		_draw_line(img, inner, outer, Color(0.8, 0.75, 0.6, 1.0), 1.0 if i % 5 == 0 else 0.6)
	# Красная зона.
	for i in 30:
		var t := 0.78 + float(i) / 100.0
		var ang := deg_to_rad(lerpf(-135.0, 135.0, t))
		var dir := Vector2(sin(ang), -cos(ang))
		img.set_pixel(int(c.x + dir.x * (r - 6.0)), int(c.y + dir.y * (r - 6.0)), Color(0.8, 0.15, 0.08, 1.0))
	# Пыль.
	for i in 700:
		var p := Vector2(randf_range(20, 236), randf_range(20, 236))
		if p.distance_to(c) < r - 4.0:
			var v := randf_range(0.0, 0.06)
			img.set_pixel(int(p.x), int(p.y), Color(v, v, v * 0.8, 1.0))
	return ImageTexture.create_from_image(img)

func _draw_line(img: Image, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var steps := int(a.distance_to(b) * 2.0)
	for s in steps:
		var p := a.lerp(b, float(s) / maxf(1.0, float(steps)))
		for ox in range(-int(width), int(width) + 1):
			for oy in range(-int(width), int(width) + 1):
				var x := int(p.x) + ox
				var y := int(p.y) + oy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, color)

func _refresh() -> void:
	if sim == null:
		return
	var raw := 0.0
	match source:
		"depth":
			raw = sim.depth
		"o2":
			raw = sim.o2
		"co2":
			raw = sim.co2
		"voltage":
			raw = sim.voltage()
		"tension":
			raw = sim.cable_tension
		"hull":
			raw = sim.hull
		"noise":
			raw = sim.noise_level
		"water":
			raw = sim.water_cm
	value = raw
	var t := clampf((raw - min_value) / maxf(0.001, max_value - min_value), 0.0, 1.0)
	var ang := deg_to_rad(lerpf(-135.0, 135.0, t))
	_needle.rotation.z = -ang
	if _value_label != null:
		_value_label.text = _format_value(raw)

func _format_value(v: float) -> String:
	if max_value <= 10.0:
		return "%s %s" % [String.num(v, 1), unit]
	return "%s %s" % [String.num(v, 0), unit]
