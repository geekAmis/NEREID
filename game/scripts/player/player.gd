class_name Player
extends CharacterBody3D
## Игрок в кабине: ходьба в тесной сфере, взгляд, луч взаимодействия 2,2 м,
## фонарь, дыхание, шаги и фотокамера. Никакой инвентарной магии.

signal focus_changed(target)
signal camera_mode_changed(active: bool)

const EYE_HEIGHT := 0.15
const INTERACT_RANGE := 2.2

var sim = null
var hud = null
var photo_camera = null
var cabin: CabinBuilder = null

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var focus: Interactable = null
var using: Interactable = null

var camera_mode := false
var input_blocked := false
var _pitch := 0.0
var _bob := 0.0
var _step_accum := 0.0
var _drag_accum := Vector2.ZERO
var _rmb := false
var _base_fov := 65.0
var _zoom_fov := 28.0
var _focus_timer := 0.0

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.22
	floor_max_angle = deg_to_rad(55.0)
	up_direction = Vector3.UP
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.23
	cap.height = 1.12
	cs.shape = cap
	add_child(cs)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 65.0
	camera.near = 0.02
	camera.far = 240.0
	camera.current = true
	head.add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.86, 0.93, 1.0)
	flashlight.light_energy = 2.1
	flashlight.spot_range = 7.0
	flashlight.spot_angle = 25.0
	flashlight.spot_angle_attenuation = 1.2
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)

func setup(p_sim, p_hud, p_photo = null, p_cabin = null, spawn: Vector3 = Vector3(0.0, -0.25, 0.18)) -> void:
	sim = p_sim
	hud = p_hud
	photo_camera = p_photo
	cabin = p_cabin
	global_position = spawn
	_base_fov = float(Game.settings.get("fov", 65.0))
	camera.fov = _base_fov
	if sim != null:
		flashlight.visible = sim.flashlight_on

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var mm := event as InputEventMouseMotion
		var sens := float(Game.settings.get("mouse", 0.0022))
		rotate_y(-mm.relative.x * sens)
		_pitch = clampf(_pitch - mm.relative.y * sens, deg_to_rad(-78.0), deg_to_rad(78.0))
		head.rotation.x = _pitch
		if using != null and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("interact")):
			using.drag(mm.relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if focus != null and not camera_mode:
				focus.scroll(1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if focus != null and not camera_mode:
				focus.scroll(-1.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if camera_mode:
				_take_photo()
			else:
				_begin_use()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_use()

func _physics_process(delta: float) -> void:
	if input_blocked:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (global_transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized()
	var speed := 1.55
	if camera_mode:
		speed = 0.85
	if Input.is_action_pressed("crouch"):
		speed = 0.85
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, delta * 8.0)
	velocity.z = move_toward(velocity.z, target.z, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Сферическая граница кабины.
	var p := global_position
	var flat := Vector2(p.x, p.z)
	if flat.length() > 0.98:
		flat = flat.normalized() * 0.98
		p.x = flat.x
		p.z = flat.y
		global_position = p
	# Шаги.
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.15 and is_on_floor():
		_bob += delta * planar * 8.0
		head.position.y = EYE_HEIGHT + sin(_bob) * 0.006
		_step_accum += planar * delta
		if _step_accum > 0.62:
			_step_accum = 0.0
			if sim != null:
				sim.add_noise(9.0 if speed < 1.0 else 15.0, global_position, 0.08)
			if Game.audio != null:
				Game.audio.play_step(global_position, speed < 1.0)
	else:
		head.position.y = lerpf(head.position.y, EYE_HEIGHT, clampf(delta * 6.0, 0.0, 1.0))
	# Фонарь всегда следует за взглядом. Дрожание от стресса.
	if sim != null and flashlight.visible:
		var stress := clampf(sim.stress, 0.0, 1.0)
		flashlight.light_energy = 2.1 - stress * 0.7 + sin(Time.get_ticks_msec() * 0.02) * stress * 0.18
	# Зум камеры.
	if camera_mode:
		var zooming := _rmb or Input.is_action_pressed("zoom")
		var target_fov := _zoom_fov if zooming else _base_fov * 0.82
		camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 9.0, 0.0, 1.0))
	else:
		camera.fov = lerpf(camera.fov, _base_fov, clampf(delta * 8.0, 0.0, 1.0))
	# Фокус луча.
	_focus_timer += delta
	if _focus_timer >= 0.05:
		_focus_timer = 0.0
		_update_focus()

func _process(delta: float) -> void:
	if input_blocked:
		if focus != null:
			_set_focus(null)
		return
	if Input.is_action_just_pressed("interact"):
		_begin_use()
	if Input.is_action_just_released("interact"):
		_end_use()
	if Input.is_action_just_pressed("flashlight") and not camera_mode:
		_toggle_flashlight()
	if Input.is_action_just_pressed("exit_camera") and camera_mode:
		exit_camera_mode()
	if camera_mode and Input.is_action_just_pressed("shutter"):
		_take_photo()
	if hud != null and focus != null:
		hud.set_prompt(focus.get_prompt(), focus.get_progress())
	elif hud != null:
		hud.set_prompt("", 0.0)

func _update_focus() -> void:
	if camera_mode:
		_set_focus(null)
		return
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var to := from + forward * INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 4)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var found: Interactable = null
	if not result.is_empty():
		var collider = result.get("collider")
		if collider != null and collider.has_meta("interactable"):
			var obj = collider.get_meta("interactable")
			if obj is Interactable and obj.enabled:
				found = obj
	_set_focus(found)

func _set_focus(next: Interactable) -> void:
	if focus == next:
		return
	if focus != null:
		focus.unfocus()
	focus = next
	if focus != null:
		focus.focus(self)
		if Game.audio != null:
			Game.audio.play_ui("tick_soft")
	else:
		if using != null:
			_end_use()
	focus_changed.emit(focus)
	if hud != null:
		hud.set_focus(focus)

func _begin_use() -> void:
	if camera_mode or focus == null or input_blocked:
		return
	using = focus
	using.use_start(self)

func _end_use() -> void:
	if using != null:
		using.use_stop(self)
		using = null

func _toggle_flashlight() -> void:
	if sim == null:
		return
	sim.flashlight_on = not sim.flashlight_on
	flashlight.visible = sim.flashlight_on
	sim.add_noise(3.0, global_position, 0.1)
	if Game.audio != null:
		Game.audio.play_ui("click")

func enter_camera_mode() -> void:
	if camera_mode:
		return
	if sim != null and sim.film <= 0:
		Game.toast("Плёнка закончилась.")
		return
	camera_mode = true
	_rmb = false
	_set_focus(null)
	if flashlight.visible:
		sim.flashlight_on = false
		flashlight.visible = false
	if hud != null:
		hud.show_camera(true, sim.film if sim != null else 0)
	camera_mode_changed.emit(true)

func exit_camera_mode() -> void:
	if not camera_mode:
		return
	camera_mode = false
	camera.fov = _base_fov
	if hud != null:
		hud.show_camera(false, 0)
	camera_mode_changed.emit(false)

func _take_photo() -> void:
	if not camera_mode or sim == null or photo_camera == null:
		return
	if sim.film <= 0:
		Game.toast("Плёнка закончилась.")
		return
	photo_camera.capture(self, sim)

func look_direction() -> Vector3:
	return -camera.global_transform.basis.z

func set_input_blocked(blocked: bool) -> void:
	input_blocked = blocked
	if blocked:
		_end_use()
		_set_focus(null)
		velocity = Vector3.ZERO

func get_eye_position() -> Vector3:
	return camera.global_position

func apply_settings() -> void:
	_base_fov = clampf(float(Game.settings.get("fov", 65.0)), 45.0, 100.0)
	if not camera_mode:
		camera.fov = _base_fov
	flashlight.visible = sim != null and sim.flashlight_on
