class_name ListenerAI
extends RefCounted
## «Слушатель»: простая, читаемая модель внимания на графе из 9 внешних узлов.
## Не навигируется физически, не входит в кабину, не убивает мгновенно.
## Реагирует на шум, свет, пинг и вибрацию лебёдки.

signal state_changed(state: String)
signal sound_event(name: String, position: Vector3)
signal impact(strength: float)

const STATES := ["dormant", "curious", "approach", "circle", "strike", "retreat"]

var state := "dormant"
var attention := 0.0
var position := Vector3(0.0, -4.0, -7.0)
var target := Vector3(0.0, -4.0, -7.0)
var nodes: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var seed_value := 4711
var cooldown := 0.0
var _state_time := 0.0
var _strike_timer := 0.0
var _move_speed := 1.2
var _last_sound := 0.0
var _noise_memory := 0.0
var _last_tick_dt := 0.1

func _init(p_seed: int = 4711) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	_build_graph()

func _build_graph() -> void:
	nodes.clear()
	for i in 8:
		var a := TAU * float(i) / 8.0
		var y := -2.0 + float(i % 3) * 2.0
		nodes.append(Vector3(cos(a) * 7.5, y, sin(a) * 7.5))
	nodes.append(Vector3(0.0, -7.5, 0.0))

func tick(dt: float, sim) -> void:
	if sim == null or sim.game_over:
		return
	_last_tick_dt = dt
	_state_time += dt
	cooldown = maxf(0.0, cooldown - dt)
	_perceive(dt, sim)
	_decide(dt, sim)
	_move(dt)
	_apply_load(sim)
	_emit_sounds(sim)

func _perceive(dt: float, sim) -> void:
	var heard := 0.0
	if sim.noise_level > 42.0:
		heard = (sim.noise_level - 42.0) * 0.09
	if sim.impulse_noise > 60.0:
		heard += sim.impulse_noise * 0.12
	if sim.flashlight_on:
		heard += 1.8
	if sim.ping_flash > 0.0:
		heard += 22.0
	if sim.winch_moving:
		heard += 3.0
	attention = clampf(attention + heard * dt - 1.4 * dt, 0.0, 100.0)
	_noise_memory = lerpf(_noise_memory, sim.noise_level, dt * 2.0)

func _decide(dt: float, sim) -> void:
	if cooldown > 0.0:
		_set_state("retreat")
		return
	match state:
		"dormant":
			if attention > 18.0:
				_set_state("curious")
				_pick_target()
		"curious":
			if attention > 46.0:
				_set_state("approach")
				_pick_nearest()
			elif attention < 8.0:
				_set_state("dormant")
		"approach":
			if position.distance_to(target) < 0.9:
				_set_state("circle")
			elif attention < 25.0:
				_set_state("curious")
		"circle":
			if attention > 76.0 and _state_time > 4.0:
				_set_state("strike")
				_strike_timer = 3.5
				sound_event.emit("listener_inhale", position)
			elif attention < 35.0 and _state_time > 8.0:
				_set_state("retreat")
		"strike":
			_strike_timer -= dt
			if _strike_timer <= 0.0:
				_do_strike(sim)
				_set_state("retreat")
				cooldown = 24.0
		"retreat":
			if cooldown <= 0.0 and attention < 20.0:
				_set_state("dormant")
			elif cooldown <= 0.0 and attention > 55.0:
				_set_state("approach")
				_pick_nearest()
	if _state_time > 18.0 and state in ["curious", "approach", "circle"] and attention < 30.0:
		_set_state("retreat")
		cooldown = 6.0

func _do_strike(sim) -> void:
	var strength := rng.randf_range(8.0, 14.0)
	sim.set_listener_load(0.0)
	sim.apply_impact(strength)
	impact.emit(strength)
	sound_event.emit("listener_strike", position)

func _move(dt: float) -> void:
	var speed := _move_speed
	match state:
		"curious":
			speed = 0.6
		"approach":
			speed = 1.8
		"circle":
			speed = 1.1
		"strike":
			speed = 2.4
		"retreat":
			speed = 2.0
	if position.distance_to(target) > 0.05:
		position = position.move_toward(target, speed * dt)

func _apply_load(sim) -> void:
	var load := 0.0
	match state:
		"curious":
			load = 0.15
		"approach":
			load = 0.55
		"circle":
			load = 1.25
		"strike":
			load = 2.7
		"retreat":
			load = 0.3
	sim.set_listener_load(load)

func _emit_sounds(sim) -> void:
	_last_sound += _last_tick_dt
	if _last_sound > 3.0 + rng.randf_range(0.0, 4.0):
		_last_sound = 0.0
		if state in ["approach", "circle", "strike"]:
			sound_event.emit("listener_breath", position)
		elif state == "curious":
			sound_event.emit("listener_far", position)

func get_process_delta() -> float:
	return _last_tick_dt

func _set_state(next: String) -> void:
	if state == next:
		return
	state = next
	_state_time = 0.0
	state_changed.emit(state)

func _pick_target() -> void:
	target = nodes[rng.randi_range(0, nodes.size() - 1)]

func _pick_nearest() -> void:
	var best := 0.0
	var best_dist := 1e9
	for i in nodes.size():
		var d := position.distance_to(nodes[i])
		if d < best_dist:
			best_dist = d
			best = float(i)
	target = nodes[int(best)]

func force_curious() -> void:
	if state == "dormant":
		attention = maxf(attention, 25.0)
		_set_state("curious")
		_pick_target()

func force_approach() -> void:
	attention = maxf(attention, 60.0)
	_set_state("approach")
	_pick_nearest()

func distract() -> void:
	attention = maxf(0.0, attention - 30.0)
	_set_state("curious")
	_pick_target()

func reset() -> void:
	state = "dormant"
	attention = 0.0
	cooldown = 0.0
	position = nodes[nodes.size() - 1]
	target = position

func state_weight() -> float:
	match state:
		"dormant":
			return 0.0
		"curious":
			return 0.2
		"approach":
			return 0.5
		"circle":
			return 0.8
		"strike":
			return 1.0
		"retreat":
			return 0.3
	return 0.0

func serialize() -> Dictionary:
	return {
		"state": state,
		"attention": attention,
		"position": [position.x, position.y, position.z],
		"cooldown": cooldown,
	}

func deserialize(data: Dictionary) -> void:
	state = str(data.get("state", "dormant"))
	attention = float(data.get("attention", 0.0))
	cooldown = float(data.get("cooldown", 0.0))
	var p: Array = data.get("position", [0.0, -4.0, -7.0])
	if p.size() == 3:
		position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	target = position
