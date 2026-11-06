class_name CapsuleSim
extends RefCounted
## Детерминированная симуляция кабины. Не знает о сцене.
## Шаг 0.1 с. Все величины — игровые, но внутренне согласованные.
##
## Физические допущения (см. .docs/Оценка_перспектив_от_физика_теоретика.md):
## - глубина 42 м, давление ~5,2 бар;
## - CO₂ ускорен в 30–50 раз для 20-минутной сессии;
## - кислород — буфер, CO₂ — главный таймер;
## - трос: рабочая нагрузка ~0,8 т, разрыв при перегрузе;
## - «дБ» здесь — относительный уровень шума 0–100, не SPL.

signal changed
signal noise_event(db: float, position: Vector3, duration: float)
signal message(text: String)
signal task_done(id: String)
signal ending(id: String)
signal impact(strength: float)

const TICK := 0.1
const BATTERY_CAPACITY_KWH := 0.9
const CABIN_VOLUME_M3 := 7.5
const BILGE_AREA_M2 := 1.5
const MAX_DEPTH := 62.0
const MIN_DEPTH := 30.0
const KNOWN_SIGNALS := [
	"pump", "groan", "bell", "knock", "voices",
	"cable", "fish", "current", "sonar", "breath"
]
const SIGNAL_NAMES := {
	"pump": "насос",
	"groan": "структурный стон",
	"bell": "колокол",
	"knock": "шаги по металлу",
	"voices": "голоса",
	"cable": "кабель",
	"fish": "биология",
	"current": "течение",
	"sonar": "сонар",
	"breath": "дыхание",
}

var rng := RandomNumberGenerator.new()
var seed_value := 19690427

# Время и акт
var time := 0.0
var act := 1
var game_over := false
var ending_id := ""

# Глубина и трос
var depth := 42.0
var target_depth := 42.0
var winch_moving := false
var winch_direction := 0
var cable_tension := 0.82
var cable_capacity := 30.0
var cable_cut := false
var cable_snapped := false
var ballast_jettisoned := false
var listener_load := 0.0
var pressure := 5.2

# Дыхание
var o2 := 20.9
var co2 := 0.4
var o2_valve_open := true
var scrubber := 1.0
var spare_canisters := 2
var scrubber_installed := true

# Энергия
var battery_kwh := BATTERY_CAPACITY_KWH
var power_cable := true
var power_cable_failed := false
var flashlight_on := false
var short_circuit := false
var crank_active := false
var switches: Dictionary = {
	"life_support": true,
	"lights": true,
	"console": true,
	"heater": false,
	"pump": false,
	"winch": true,
}

# Вода и корпус
var hull := 100.0
var leak_rate := 18.0         # л/мин — пробоина Ø4 см при 5 бар
var leak_patched := false
var water_liters := 18.0      # ~1,2 см
var water_cm := 1.2
var pump_manual := false

# Климат
var temperature := 9.0
var humidity := 78.0

# Шум и тело
var noise_level := 22.0
var impulse_noise := 0.0
var stress := 0.12
var heart_rate := 68.0
var thermos_effect := 0.0
var noise_history: Array[float] = []

# Гидрофон
var current_signal := ""
var signal_strength := 0.0
var signal_time_left := 0.0
var gain := 6.0
var filter_mode := 1          # 0 НЧ, 1 широкий, 2 ВЧ
var channel_mode := 0         # 0 omni, 1 кардиоида, 2 восьмёрка
var ping_cooldown := 0.0
var ping_flash := 0.0
var identified: Array[String] = []
var recordings := 3

# Фото
var film := 12
var photos: Array[Dictionary] = []

# Рация и ленты
var radio_channel := 1
var bell_trim := 47.0
var tapes_played: Array[String] = []

# Задачи
var tasks: Dictionary = {
	"identify3": false,
	"photo3": false,
	"bell_log": false,
	"patch": false,
	"scrubber": false,
	"photo_bell": false,
	"secret_bell": false,
}

# Служебное
var _accum := 0.0
var _changed_accum := 0.0
var _tension_high_time := 0.0
var _sink_time := 0.0
var _last_ambient := 0.0

func _init(p_seed: int = 19690427) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	noise_history.resize(300)
	for i in noise_history.size():
		noise_history[i] = 22.0

# ---------------------------------------------------------------------------
# Основной цикл
# ---------------------------------------------------------------------------

func advance(dt: float) -> void:
	if game_over:
		return
	_accum += dt
	var guard := 0
	while _accum >= TICK and guard < 20:
		_accum -= TICK
		guard += 1
		step(TICK)
	if guard >= 20:
		_accum = 0.0

func step(dt: float) -> void:
	if game_over:
		return
	time += dt
	_tick_power(dt)
	_tick_air(dt)
	_tick_water(dt)
	_tick_depth(dt)
	_tick_climate(dt)
	_tick_noise(dt)
	_tick_stress(dt)
	_tick_signals(dt)
	_check_failures()
	_check_tasks()
	_changed_accum += dt
	if _changed_accum >= 0.1:
		_changed_accum = 0.0
		changed.emit()

# ---------------------------------------------------------------------------
# Энергия
# ---------------------------------------------------------------------------

func current_load_w() -> float:
	var load := 0.0
	if bool(switches.life_support):
		load += 180.0
	if bool(switches.lights) and not short_circuit:
		load += 60.0
	if bool(switches.console) and not short_circuit:
		load += 90.0
	if bool(switches.heater):
		load += 300.0
	if bool(switches.pump):
		load += 240.0
	if bool(switches.winch) and winch_moving:
		load += 400.0
	if flashlight_on:
		load += 30.0
	return load

func battery_pct() -> float:
	return clampf(battery_kwh / BATTERY_CAPACITY_KWH * 100.0, 0.0, 100.0)

func voltage() -> float:
	return 20.0 + battery_pct() / 100.0 * 9.0

func _tick_power(dt: float) -> void:
	if power_cable and not power_cable_failed:
		# Кабель с поверхности держит до 900 Вт; избыток — из АКБ.
		var excess := maxf(0.0, current_load_w() - 900.0)
		battery_kwh = maxf(0.0, battery_kwh - excess / 3600.0 * dt)
	else:
		var load := current_load_w()
		battery_kwh = maxf(0.0, battery_kwh - load / 3600.0 * dt)
	if crank_active:
		battery_kwh = minf(BATTERY_CAPACITY_KWH, battery_kwh + 600.0 / 3600.0 * dt)
	if battery_kwh <= 0.001:
		flashlight_on = false
		short_circuit = true

func set_switch(id: String, on: bool) -> void:
	if not switches.has(id):
		return
	switches[id] = on
	if id == "pump":
		add_noise(62.0 if on else 24.0, Vector3.ZERO, 0.5)
	if id == "heater" and on:
		add_noise(34.0, Vector3.ZERO, 0.4)
	if id == "winch" and not on:
		winch_moving = false
	changed.emit()

func toggle_switch(id: String) -> bool:
	if not switches.has(id):
		return false
	set_switch(id, not bool(switches[id]))
	return bool(switches[id])

func set_crank(active: bool) -> void:
	crank_active = active
	if active:
		add_noise(64.0, Vector3.ZERO, 1.0)
		message.emit("Генератор: заряд идёт.")

func reset_breaker() -> void:
	if water_cm < 5.0 and battery_kwh > 0.01:
		short_circuit = false
		message.emit("Щиток сброшен.")
	else:
		message.emit("Нужно сначала осушить трюм.")

# ---------------------------------------------------------------------------
# Дыхание
# ---------------------------------------------------------------------------

func _tick_air(dt: float) -> void:
	var life := bool(switches.life_support)
	if life and o2_valve_open:
		o2 = move_toward(o2, 20.9, 0.0015 * dt)
	else:
		o2 = maxf(0.0, o2 - 0.0042 * dt)
	if life and scrubber_installed and scrubber > 0.0:
		scrubber = maxf(0.0, scrubber - dt / 720.0)
		co2 = maxf(0.0, co2 - 0.014 * dt)
	else:
		co2 = minf(9.0, co2 + 0.0062 * dt)
	if co2 > 3.0:
		stress = minf(1.0, stress + 0.002 * dt)
	if co2 > 4.5:
		stress = minf(1.0, stress + 0.004 * dt)

func replace_scrubber() -> bool:
	if spare_canisters <= 0:
		message.emit("Запасных патронов нет.")
		return false
	spare_canisters -= 1
	scrubber = 1.0
	scrubber_installed = true
	co2 = maxf(0.0, co2 - 0.6)
	add_noise(8.0, Vector3.ZERO, 0.5)
	message.emit("Патрон заменён. Осталось: %d." % spare_canisters)
	_check_tasks()
	changed.emit()
	return true

# ---------------------------------------------------------------------------
# Вода и корпус
# ---------------------------------------------------------------------------

func _tick_water(dt: float) -> void:
	var rate := leak_rate
	if leak_patched:
		rate = maxf(2.0, rate - 14.0)
	water_liters += rate / 60.0 * dt
	var pump_rate := 0.0
	if bool(switches.pump) and not short_circuit and battery_kwh > 0.0:
		pump_rate += 34.0
	if pump_manual:
		pump_rate += 11.0
	water_liters = maxf(0.0, water_liters - pump_rate / 60.0 * dt)
	water_cm = water_liters / BILGE_AREA_M2 / 10.0
	if water_cm > 8.0 and not short_circuit:
		short_circuit = true
		message.emit("Вода добралась до нижних цепей. Замыкание.")
		add_noise(70.0, Vector3.ZERO, 0.6)
	elif water_cm < 4.0 and short_circuit and battery_kwh > 0.01:
		short_circuit = false
		message.emit("Нижние цепи снова сухие.")

func patch_leak() -> void:
	if leak_patched:
		return
	leak_patched = true
	hull = minf(100.0, hull + 4.0)
	leak_rate = maxf(2.0, leak_rate - 14.0)
	add_noise(36.0, Vector3.ZERO, 0.5)
	tasks.patch = true
	message.emit("Пробоина залатана. Приток снизился.")
	changed.emit()

func apply_impact(strength: float) -> void:
	if game_over:
		return
	hull = maxf(0.0, hull - strength)
	leak_rate = 18.0 + (100.0 - hull) * 0.55
	stress = minf(1.0, stress + strength / 60.0)
	add_noise(86.0, Vector3.ZERO, 1.2)
	impact.emit(strength)
	message.emit("Удар по корпусу. Прочность: %d%%." % int(hull))
	changed.emit()

func pump_manual_step(active: bool) -> void:
	pump_manual = active

# ---------------------------------------------------------------------------
# Глубина и трос
# ---------------------------------------------------------------------------

func _tick_depth(dt: float) -> void:
	if cable_cut:
		# Свободное падение или всплытие.
		if ballast_jettisoned:
			depth = maxf(0.0, depth - 1.4 * dt)
			if depth <= 1.0:
				_finish("surface")
		else:
			depth = minf(80.0, depth + 1.7 * dt)
			_sink_time += dt
			if _sink_time > 9.0:
				_finish("cable")
		pressure = 1.0 + depth / 10.2
		return
	if winch_moving:
		var step := 0.35 * dt
		depth = move_toward(depth, target_depth, step)
		if absf(depth - target_depth) < 0.02:
			winch_moving = false
	pressure = 1.0 + depth / 10.2
	# Натяжение: вес + глубина + «пассажир» + вибрация.
	var base := 0.72 + maxf(0.0, depth - 42.0) * 0.006
	cable_tension = base + listener_load + (0.12 if winch_moving else 0.0)
	cable_tension += rng.randf_range(-0.015, 0.015)
	if listener_load > 2.0:
		_tension_high_time += dt
		if _tension_high_time > 8.0 and not cable_snapped:
			cable_snapped = true
			cable_cut = true
			message.emit("Трос не выдержал. Обрыв.")
			add_noise(95.0, Vector3.ZERO, 2.0)
	elif _tension_high_time > 0.0:
		_tension_high_time = maxf(0.0, _tension_high_time - dt * 0.5)

func winch_step(direction: int) -> void:
	if cable_cut or not bool(switches.winch) or battery_kwh <= 0.0:
		return
	winch_direction = 1 if direction > 0 else -1
	target_depth = clampf(target_depth + float(direction) * 0.35, MIN_DEPTH, MAX_DEPTH)
	winch_moving = true
	add_noise(58.0, Vector3.ZERO, 0.3)

func set_target_depth(value: float) -> void:
	if cable_cut or not bool(switches.winch) or battery_kwh <= 0.0:
		return
	var d := clampf(value, MIN_DEPTH, MAX_DEPTH)
	if absf(d - target_depth) < 0.05:
		return
	winch_direction = 1 if d > target_depth else -1
	target_depth = d
	winch_moving = true
	add_noise(58.0, Vector3.ZERO, 0.3)

func set_o2_valve(open: bool) -> void:
	o2_valve_open = open
	add_noise(4.0, Vector3.ZERO, 0.2)
	message.emit("Кислородный вентиль: %s." % ("открыт" if open else "закрыт"))
	changed.emit()

func set_gain(value: float) -> void:
	gain = clampf(value, 0.0, 10.0)
	changed.emit()

func set_filter_mode(value: int) -> void:
	filter_mode = clampi(value, 0, 2)
	changed.emit()

func set_channel_mode(value: int) -> void:
	channel_mode = clampi(value, 0, 2)
	changed.emit()

func set_listener_load(value: float) -> void:
	listener_load = maxf(0.0, value)

func cut_cable() -> void:
	if cable_cut:
		return
	cable_cut = true
	winch_moving = false
	add_noise(94.0, Vector3.ZERO, 2.0)
	if ballast_jettisoned:
		message.emit("Трос перерезан. Балласт сброшен. Всплываем.")
		_finish("surface")
	else:
		message.emit("Трос перерезан. Капсула тонет.")
		_sink_time = 0.0

func jettison_ballast() -> void:
	if ballast_jettisoned:
		return
	ballast_jettisoned = true
	add_noise(78.0, Vector3.ZERO, 1.2)
	message.emit("Аварийный балласт сброшен.")
	if cable_cut:
		_finish("surface")

func set_bell_trim(value: float) -> void:
	bell_trim = clampf(value, 40.0, 55.0)
	if absf(bell_trim - 47.0) < 0.15 and "bell" in identified and not bool(tasks.secret_bell):
		tasks.secret_bell = true
		message.emit("Тон совпал. 47,0 Гц. Канал открыт.")
		changed.emit()

# ---------------------------------------------------------------------------
# Климат
# ---------------------------------------------------------------------------

func _tick_climate(dt: float) -> void:
	var target := 14.0 if bool(switches.heater) else 6.5
	var rate := 0.035 if bool(switches.heater) else 0.012
	temperature = move_toward(temperature, target, rate * dt)
	humidity = 78.0 - (temperature - 6.5) * 2.0
	humidity = clampf(humidity, 55.0, 92.0)
	if thermos_effect > 0.0:
		thermos_effect = maxf(0.0, thermos_effect - dt / 90.0)

func interaction_speed() -> float:
	var base := 0.65 + clampf((temperature - 6.5) / 7.5, 0.0, 1.0) * 0.35
	if short_circuit:
		base *= 0.9
	return clampf(base, 0.55, 1.0)

func drink_thermos() -> void:
	thermos_effect = 1.0
	stress = maxf(0.0, stress - 0.18)
	message.emit("Кофе. Ещё тёплый.")
	changed.emit()

# ---------------------------------------------------------------------------
# Шум
# ---------------------------------------------------------------------------

func sustained_noise() -> float:
	var n := 22.0
	if bool(switches.pump) and not short_circuit:
		n += 20.0
	if winch_moving:
		n += 22.0
	if bool(switches.heater):
		n += 6.0
	if crank_active:
		n += 14.0
	if bool(switches.console) and not short_circuit:
		n += 2.0
	if pump_manual:
		n += 10.0
	return n

func _tick_noise(dt: float) -> void:
	var target := sustained_noise()
	noise_level = move_toward(noise_level, maxf(target, impulse_noise), 8.0 * dt)
	impulse_noise = maxf(0.0, impulse_noise - 6.0 * dt)
	noise_history.pop_front()
	noise_history.push_back(noise_level)
	_last_ambient += dt
	if _last_ambient > 6.0 + rng.randf_range(0.0, 8.0):
		_last_ambient = 0.0
		_ambient_creak()

func _ambient_creak() -> void:
	if game_over:
		return
	add_noise(30.0 + rng.randf_range(0.0, 12.0), Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), -1.0), 0.3)

func add_noise(db: float, position: Vector3 = Vector3.ZERO, duration: float = 0.0) -> void:
	if game_over:
		return
	impulse_noise = maxf(impulse_noise, db)
	noise_level = maxf(noise_level, db)
	noise_event.emit(db, position, duration)
	stress = minf(1.0, stress + maxf(0.0, db - 40.0) / 900.0)
	changed.emit()

func average_noise(seconds: float = 10.0) -> float:
	var count := clampi(int(seconds / TICK), 1, noise_history.size())
	var sum := 0.0
	for i in count:
		sum += noise_history[noise_history.size() - 1 - i]
	return sum / float(count)

# ---------------------------------------------------------------------------
# Стресс
# ---------------------------------------------------------------------------

func _tick_stress(dt: float) -> void:
	var target := 0.10
	target += clampf(co2 / 5.0, 0.0, 1.0) * 0.38
	target += clampf(water_cm / 20.0, 0.0, 1.0) * 0.18
	target += clampf((100.0 - hull) / 100.0, 0.0, 1.0) * 0.22
	target += clampf((noise_level - 30.0) / 60.0, 0.0, 1.0) * 0.20
	target += clampf(listener_load / 2.5, 0.0, 1.0) * 0.30
	target -= clampf(thermos_effect, 0.0, 1.0) * 0.12
	if o2 < 17.0:
		target += (17.0 - o2) / 17.0 * 0.35
	target = clampf(target, 0.0, 1.0)
	stress = lerpf(stress, target, clampf(dt * 0.8, 0.0, 1.0))
	var hr_target := 62.0 + stress * 98.0
	heart_rate = lerpf(heart_rate, hr_target, clampf(dt * 1.2, 0.0, 1.0))

# ---------------------------------------------------------------------------
# Гидрофон
# ---------------------------------------------------------------------------

func set_signal(id: String, strength: float = 1.0, duration: float = 12.0) -> void:
	current_signal = id
	signal_strength = clampf(strength, 0.0, 1.0)
	signal_time_left = duration

func clear_signal() -> void:
	current_signal = ""
	signal_strength = 0.0
	signal_time_left = 0.0

func _tick_signals(dt: float) -> void:
	if signal_time_left > 0.0:
		signal_time_left = maxf(0.0, signal_time_left - dt)
		if signal_time_left <= 0.0 and current_signal != "bell":
			current_signal = ""
	ping_cooldown = maxf(0.0, ping_cooldown - dt)
	ping_flash = maxf(0.0, ping_flash - dt)

func ping() -> bool:
	if ping_cooldown > 0.0 or not bool(switches.console) or short_circuit:
		return false
	ping_cooldown = 8.0
	ping_flash = 3.0
	add_noise(78.0, Vector3.ZERO, 0.8)
	return true

func identify(id: String) -> bool:
	if id == "" or not (id in KNOWN_SIGNALS):
		return false
	if id == current_signal:
		if not (id in identified):
			identified.append(id)
		message.emit("Сигнал записан: %s." % str(SIGNAL_NAMES.get(id, id)))
		add_noise(2.0, Vector3.ZERO, 0.1)
		_check_tasks()
		changed.emit()
		return true
	stress = minf(1.0, stress + 0.06)
	message.emit("Не совпадает. Слушай ещё.")
	return false

func record_signal() -> bool:
	if recordings <= 0:
		return false
	recordings -= 1
	add_noise(2.0, Vector3.ZERO, 0.2)
	message.emit("Бобина записана. Осталось: %d." % recordings)
	return true

# ---------------------------------------------------------------------------
# Фото
# ---------------------------------------------------------------------------

func can_photo() -> bool:
	return film > 0 and not game_over

func register_photo(target_id: String, path: String, depth_value: float, signal_id: String) -> void:
	if film <= 0:
		return
	film -= 1
	photos.append({
		"target": target_id,
		"path": path,
		"depth": depth_value,
		"signal": signal_id,
		"time": time,
	})
	add_noise(6.0, Vector3.ZERO, 0.3)
	_check_tasks()
	changed.emit()

func photo_count() -> int:
	return photos.size()

func has_photo(target_id: String) -> bool:
	for p in photos:
		if str(p.get("target", "")) == target_id:
			return true
	return false

# ---------------------------------------------------------------------------
# Ленты и рация
# ---------------------------------------------------------------------------

func play_tape(id: String) -> void:
	if not (id in tapes_played):
		tapes_played.append(id)
	message.emit("Лента: %s." % id)
	add_noise(10.0, Vector3.ZERO, 1.0)

func set_radio_channel(ch: int) -> void:
	radio_channel = clampi(ch, 1, 3)
	add_noise(6.0, Vector3.ZERO, 0.3)

# ---------------------------------------------------------------------------
# Задачи и финалы
# ---------------------------------------------------------------------------

func _check_tasks() -> void:
	if not bool(tasks.identify3) and identified.size() >= 3:
		tasks.identify3 = true
		task_done.emit("identify3")
	if not bool(tasks.photo3) and photos.size() >= 3:
		tasks.photo3 = true
		task_done.emit("photo3")
	if not bool(tasks.bell_log) and "bell" in identified:
		tasks.bell_log = true
		task_done.emit("bell_log")
	if not bool(tasks.scrubber) and scrubber < 0.99 and spare_canisters < 2:
		tasks.scrubber = true
		task_done.emit("scrubber")
	if not bool(tasks.photo_bell) and has_photo("bell"):
		tasks.photo_bell = true
		task_done.emit("photo_bell")

func _check_failures() -> void:
	if game_over:
		return
	if co2 >= 5.2:
		_finish("asphyxia")
	elif o2 <= 11.0:
		_finish("hypoxia")
	elif hull <= 0.0:
		_finish("implosion")
	elif water_cm >= 24.0:
		_finish("flood")
	elif battery_kwh <= 0.0 and co2 > 4.0:
		_finish("dark")

func _finish(id: String) -> void:
	if game_over:
		return
	game_over = true
	ending_id = id
	ending.emit(id)
	message.emit("Смена окончена: %s" % id)

func trigger_ending(id: String) -> void:
	_finish(id)

func complete_task(id: String) -> void:
	if tasks.has(id):
		tasks[id] = true
		task_done.emit(id)

func task_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"id": "identify3", "done": bool(tasks.identify3), "text": "Опознать 3 сигнала"})
	out.append({"id": "photo3", "done": bool(tasks.photo3), "text": "Сделать 3 снимка"})
	out.append({"id": "bell_log", "done": bool(tasks.bell_log), "text": "Записать колокол"})
	out.append({"id": "photo_bell", "done": bool(tasks.photo_bell), "text": "Сфотографировать колокольню"})
	out.append({"id": "patch", "done": bool(tasks.patch), "text": "Залатать пробоину"})
	out.append({"id": "scrubber", "done": bool(tasks.scrubber), "text": "Заменить патрон"})
	out.append({"id": "secret_bell", "done": bool(tasks.secret_bell), "text": "Настроиться на 47,0 Гц"})
	return out

# ---------------------------------------------------------------------------
# Сериализация
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"seed": seed_value,
		"time": time,
		"act": act,
		"game_over": game_over,
		"ending": ending_id,
		"depth": depth,
		"target_depth": target_depth,
		"cable_cut": cable_cut,
		"ballast": ballast_jettisoned,
		"o2": o2,
		"co2": co2,
		"scrubber": scrubber,
		"spares": spare_canisters,
		"battery": battery_kwh,
		"power_cable": power_cable,
		"power_failed": power_cable_failed,
		"short": short_circuit,
		"switches": switches.duplicate(true),
		"hull": hull,
		"leak": leak_rate,
		"patched": leak_patched,
		"water": water_liters,
		"temp": temperature,
		"noise": noise_level,
		"stress": stress,
		"film": film,
		"photos": photos.duplicate(true),
		"identified": identified.duplicate(),
		"tasks": tasks.duplicate(true),
		"bell_trim": bell_trim,
		"recordings": recordings,
		"tapes": tapes_played.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 19690427))
	rng.seed = seed_value
	time = float(data.get("time", 0.0))
	act = int(data.get("act", 1))
	game_over = bool(data.get("game_over", false))
	ending_id = str(data.get("ending", ""))
	depth = float(data.get("depth", 42.0))
	target_depth = float(data.get("target_depth", 42.0))
	cable_cut = bool(data.get("cable_cut", false))
	ballast_jettisoned = bool(data.get("ballast", false))
	o2 = float(data.get("o2", 20.9))
	co2 = float(data.get("co2", 0.4))
	scrubber = float(data.get("scrubber", 1.0))
	spare_canisters = int(data.get("spares", 2))
	battery_kwh = float(data.get("battery", BATTERY_CAPACITY_KWH))
	power_cable = bool(data.get("power_cable", true))
	power_cable_failed = bool(data.get("power_failed", false))
	short_circuit = bool(data.get("short", false))
	switches = (data.get("switches", switches) as Dictionary).duplicate(true)
	hull = float(data.get("hull", 100.0))
	leak_rate = float(data.get("leak", 2.2))
	leak_patched = bool(data.get("patched", false))
	water_liters = float(data.get("water", 12.0))
	temperature = float(data.get("temp", 9.0))
	noise_level = float(data.get("noise", 22.0))
	stress = float(data.get("stress", 0.12))
	film = int(data.get("film", 12))
	photos.clear()
	for p in (data.get("photos", []) as Array):
		if typeof(p) == TYPE_DICTIONARY:
			photos.append(p)
	identified.clear()
	for s in (data.get("identified", []) as Array):
		identified.append(str(s))
	tasks = (data.get("tasks", tasks) as Dictionary).duplicate(true)
	bell_trim = float(data.get("bell_trim", 47.0))
	recordings = int(data.get("recordings", 3))
	tapes_played.clear()
	for t in (data.get("tapes", []) as Array):
		tapes_played.append(str(t))
	water_cm = water_liters / BILGE_AREA_M2 / 10.0
	changed.emit()
