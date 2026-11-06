class_name SilenceDirector
extends RefCounted
## «Режиссёр тишины»: utility-подобный контроллер темпа. Управляет событиями,
## репликами и агрессией Слушателя, но не физикой и не финалом игрока.
## Все решения детерминированы seed'ом и состоянием симуляции.

signal radio_line(id: String)
signal event(name: String, data: Dictionary)
signal act_changed(act: int)
signal bell(strength: float)

const ACT1_END := 300.0
const ACT2_END := 840.0

var sim = null
var listener = null
var rng := RandomNumberGenerator.new()
var seed_value := 4701
var act := 1
var tension := 0.0
var quiet_time := 0.0
var last_signal_time := 0.0
var next_signal_gap := 28.0
var final_available := false
var flags: Dictionary = {}
var _line_cooldowns: Dictionary = {}
var _last_radio := ""
var _delayed: Array[Dictionary] = []

func _init(p_seed: int = 4701) -> void:
	seed_value = p_seed
	rng.seed = p_seed

func bind(p_sim, p_listener) -> void:
	sim = p_sim
	listener = p_listener

func tick(dt: float) -> void:
	if sim == null or sim.game_over:
		return
	var t: float = sim.time
	_update_act(t)
	_scripted(t)
	_dynamic(t, dt)
	_update_tension()
	_tick_cooldowns(dt)
	_tick_delays(dt)

func _update_act(t: float) -> void:
	var next := 1
	if t >= ACT2_END:
		next = 3
	elif t >= ACT1_END:
		next = 2
	if next != act:
		act = next
		sim.act = act
		act_changed.emit(act)
		_on_act_start(act)

func _on_act_start(a: int) -> void:
	if a == 2:
		radio("power_cut")
		event.emit("power_cut", {})
		sim.power_cable_failed = true
		sim.message.emit("Кабель питания перебит. Работаем на АКБ.")
		if listener != null:
			listener.force_curious()
	elif a == 3:
		radio("bell_02")
		sim.set_signal("bell", 1.0, 999.0)
		bell.emit(1.0)
		event.emit("act3", {})
		if listener != null:
			listener.force_approach()

func _scripted(t: float) -> void:
	if _once("brief", t >= 4.0):
		radio("brief_01")
		radio("brief_02", 7.0)
	if _once("tut1", t >= 28.0):
		radio("tut_01")
	if _once("tut2", t >= 52.0):
		radio("tut_02")
	if _once("pump", t >= 78.0):
		_trigger_signal("pump", 0.7, 14.0)
		radio("signal_pump")
	if _once("groan", t >= 148.0):
		_trigger_signal("groan", 0.9, 16.0)
		radio("signal_groan")
	if _once("bell1", t >= 218.0):
		_trigger_signal("bell", 1.0, 999.0)
		radio("signal_bell")
		bell.emit(0.8)
	if _once("leak", t >= 390.0):
		sim.apply_impact(6.0)
		radio("warn_water")
		event.emit("leak", {})
	if _once("voices", t >= 470.0):
		_trigger_signal("voices", 0.85, 20.0)
		radio("bell_01")
		if listener != null:
			listener.force_approach()
	if _once("return1", t >= 540.0):
		radio("return_01")
	if _once("cable", t >= 610.0):
		_trigger_signal("cable", 0.8, 15.0)
		radio("warn_cable")
		if listener != null:
			listener.force_curious()
	if _once("return2", t >= 700.0):
		radio("return_02")
		_trigger_signal("bell", 1.0, 999.0)
		bell.emit(1.0)
	if _once("final", t >= 860.0):
		final_available = true
		radio("end_surface")
		event.emit("final_available", {})
	if _once("silence", t >= 980.0):
		radio("silence_01")
	if _once("silence2", t >= 1030.0):
		radio("silence_02")
	if _once("late_bell", t >= 1100.0):
		_trigger_signal("bell", 1.0, 999.0)
		bell.emit(1.0)
		if listener != null:
			listener.force_approach()

func _once(key: String, condition: bool) -> bool:
	if not condition:
		return false
	if bool(flags.get(key, false)):
		return false
	flags[key] = true
	return true

func _dynamic(t: float, dt: float) -> void:
	if sim.current_signal == "" and t - last_signal_time > next_signal_gap:
		var pool := ["fish", "current", "sonar", "knock", "breath", "groan", "cable"]
		var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
		_trigger_signal(pick, rng.randf_range(0.45, 0.85), rng.randf_range(10.0, 18.0))
		next_signal_gap = rng.randf_range(26.0, 46.0)
		if rng.randf() < 0.28:
			radio("misc_signal")
	elif sim.current_signal == "":
		quiet_time += dt
	if sim.noise_level > 45.0:
		quiet_time = 0.0
	if quiet_time > 38.0 and tension < 0.35:
		_trigger_signal("breath", 0.5, 12.0)
		next_signal_gap = 24.0
		quiet_time = 0.0
		if rng.randf() < 0.3 and listener != null:
			listener.force_curious()

func _trigger_signal(id: String, strength: float, duration: float) -> void:
	sim.set_signal(id, strength, duration)
	last_signal_time = sim.time
	var a := rng.randf_range(0.0, TAU)
	var pos := Vector3(cos(a) * 8.0, rng.randf_range(-5.0, 2.0), sin(a) * 8.0)
	event.emit("signal", {"id": id, "position": pos, "strength": strength, "duration": duration})

func _update_tension() -> void:
	var resource_pressure := 0.0
	resource_pressure += clampf(sim.co2 / 5.0, 0.0, 1.0) * 0.35
	resource_pressure += clampf(sim.water_cm / 16.0, 0.0, 1.0) * 0.25
	resource_pressure += clampf((100.0 - sim.battery_pct()) / 100.0, 0.0, 1.0) * 0.2
	resource_pressure += clampf((100.0 - sim.hull) / 100.0, 0.0, 1.0) * 0.2
	var act_progress := clampf(sim.time / ACT2_END, 0.0, 1.0)
	var violation := 1.0 if sim.average_noise(6.0) > 58.0 else 0.0
	var listener_w: float = listener.state_weight() if listener != null else 0.0
	tension = clampf(
		0.32 * listener_w
		+ 0.22 * resource_pressure
		+ 0.18 * sim.stress
		+ 0.16 * act_progress
		+ 0.12 * violation,
		0.0, 1.0
	)

func _tick_cooldowns(dt: float) -> void:
	for key in _line_cooldowns.keys():
		_line_cooldowns[key] = maxf(0.0, float(_line_cooldowns[key]) - dt)

func _tick_delays(dt: float) -> void:
	if _delayed.is_empty():
		return
	var i := _delayed.size() - 1
	while i >= 0:
		_delayed[i]["t"] = float(_delayed[i].get("t", 0.0)) - dt
		if float(_delayed[i]["t"]) <= 0.0:
			var id := str(_delayed[i].get("id", ""))
			_delayed.remove_at(i)
			radio(id)
		i -= 1

func radio(id: String, delay: float = 0.0) -> void:
	if id == "":
		return
	if float(_line_cooldowns.get(id, 0.0)) > 0.0:
		return
	if delay > 0.0:
		_delayed.append({"id": id, "t": delay})
		return
	_line_cooldowns[id] = 14.0
	_last_radio = id
	radio_line.emit(id)

func line_id() -> String:
	return _last_radio

func trigger_bell(strength: float = 1.0) -> void:
	_trigger_signal("bell", strength, 999.0)
	bell.emit(strength)

func invite_ending() -> void:
	final_available = true
	event.emit("final_available", {})

func serialize() -> Dictionary:
	return {
		"seed": seed_value,
		"act": act,
		"tension": tension,
		"quiet": quiet_time,
		"last_signal": last_signal_time,
		"gap": next_signal_gap,
		"final": final_available,
		"flags": flags.duplicate(true),
	}

func deserialize(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 4701))
	rng.seed = seed_value
	act = int(data.get("act", 1))
	tension = float(data.get("tension", 0.0))
	quiet_time = float(data.get("quiet", 0.0))
	last_signal_time = float(data.get("last_signal", 0.0))
	next_signal_gap = float(data.get("gap", 28.0))
	final_available = bool(data.get("final", false))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
