class_name GameScene
extends Node3D
## Сцена смены: собирает мир, кабину, игрока, HUD и звук, ведёт симуляцию
## 10 Гц, режиссёра тишины, Слушателя, автосохранение и финалы.

const TAPE_ORDER := ["tape_01", "tape_02", "tape_03", "tape_04"]
const AUTOSAVE_INTERVAL := 20.0
const PHOTO_DEV_TIME := 20.0

var sim: CapsuleSim
var listener: ListenerAI
var director: SilenceDirector
var world: WorldBuilder
var cabin: CabinBuilder
var player: Player
var hud: GameHUD
var post: PostProcess
var audio: AudioDirector
var photo_camera: PhotoCamera
var env: Environment

var developed_photos: Array[String] = []
var _pending_photos: Array[Dictionary] = []
var _tape_index := 0
var _save_accum := 0.0
var _warn_at: Dictionary = {}
var _shake := 0.0
var _ending_shown := false
var _transmit_armed := 0.0
var _co2_warned := false
var _water_warned := false
var _low_batt_warned := false
var _listener_warn_at := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	Game.register_game(self)
	_rng.seed = 19690427
	sim = CapsuleSim.new()
	listener = ListenerAI.new()
	director = SilenceDirector.new()
	director.bind(sim, listener)
	_load_session()
	_build_environment()
	_build_world()
	_build_cabin()
	_build_player()
	_build_post()
	_build_hud()
	_build_photo_camera()
	_build_audio()
	_connect_signals()
	_sync_devices()
	_apply_quality()
	Game.settings_changed.connect(_on_settings_changed)
	if sim.game_over:
		# Битое сохранение после финала: начинаем новый сеанс.
		sim.game_over = false
		sim.ending_id = ""
	print("[NEREID] shift ready · act %d · t=%.1f · photos %d" % [sim.act, sim.time, developed_photos.size()])

# ---------------------------------------------------------------------------
# Сборка мира
# ---------------------------------------------------------------------------

func _load_session() -> void:
	developed_photos = Save.list_photos()
	if not Game.continue_requested:
		return
	var data := Save.load_game()
	if data.is_empty():
		return
	var s: Variant = data.get("sim", {})
	if typeof(s) == TYPE_DICTIONARY and not (s as Dictionary).is_empty():
		sim.deserialize(s)
	var d: Variant = data.get("director", {})
	if typeof(d) == TYPE_DICTIONARY:
		director.deserialize(d)
	var l: Variant = data.get("listener", {})
	if typeof(l) == TYPE_DICTIONARY:
		listener.deserialize(l)
	var photos: Variant = data.get("photos", [])
	if typeof(photos) == TYPE_ARRAY:
		developed_photos.clear()
		for p in photos:
			developed_photos.append(str(p))
	_tape_index = int(data.get("tape_index", 0))
	if sim.game_over:
		Save.delete_save()

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.020, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.30, 0.32)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.62
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.7
	env.ssao_power = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.035, 0.095, 0.105)
	env.fog_light_energy = 0.55
	env.fog_density = 0.012
	env.fog_aerial_perspective = 0.15
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.24, 0.40, 0.42)
	env.volumetric_fog_emission = Color(0.012, 0.030, 0.036)
	env.volumetric_fog_length = 42.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 0.93
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "SurfaceSun"
	sun.light_color = Color(0.36, 0.58, 0.70)
	sun.light_energy = 0.28
	sun.rotation_degrees = Vector3(-62.0, 24.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)

func _build_world() -> void:
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.setup(sim)

func _build_cabin() -> void:
	cabin = CabinBuilder.new()
	cabin.name = "Cabin"
	add_child(cabin)
	cabin.setup(sim, true)

func _build_player() -> void:
	player = Player.new()
	add_child(player)
	player.setup(sim, null, null, cabin)

func _build_post() -> void:
	post = PostProcess.new()
	post.name = "PostProcess"
	add_child(post)

func _build_hud() -> void:
	hud = GameHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(sim, player, post, self)
	player.hud = hud

func _build_photo_camera() -> void:
	photo_camera = PhotoCamera.new()
	photo_camera.name = "PhotoCamera"
	add_child(photo_camera)
	photo_camera.setup(hud, post, world.anomaly_list)
	player.photo_camera = photo_camera

func _build_audio() -> void:
	audio = AudioDirector.new()
	audio.name = "AudioDirector"
	add_child(audio)
	audio.setup(sim, listener, director, hud)
	Game.audio = audio
	audio.tick(0.016)

func _connect_signals() -> void:
	sim.message.connect(_on_message)
	sim.impact.connect(_on_impact)
	sim.ending.connect(_on_ending)
	sim.task_done.connect(_on_task_done)
	director.act_changed.connect(_on_act_changed)
	director.bell.connect(_on_bell)
	director.event.connect(_on_director_event)
	listener.state_changed.connect(_on_listener_state)
	cabin.action.connect(_on_cabin_action)
	if photo_camera != null and hud != null:
		photo_camera.photo_taken.connect(_on_photo_taken)
	_greet_player()

func _greet_player() -> void:
	if sim.time > 5.0:
		hud.show_toast("Смена продолжается · %s" % hud.format_time(sim.time), 4.0)
	else:
		hud.show_toast("СМЕНА 47 · 42 М · 09:14", 4.0)

func _apply_quality() -> void:
	if env == null:
		return
	var q := int(Game.settings.get("quality", 2))
	env.glow_enabled = q >= 1
	env.ssao_enabled = q >= 1
	env.volumetric_fog_enabled = q >= 2
	env.volumetric_fog_density = 0.022 if q >= 2 else 0.0
	if post != null:
		post.apply_quality(q)

func _on_settings_changed() -> void:
	_apply_quality()
	if player != null:
		player.apply_settings()

# ---------------------------------------------------------------------------
# Основной цикл
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	if not get_tree().paused:
		sim.advance(delta)
		director.tick(delta)
		listener.tick(delta, sim)
		if audio != null:
			audio.tick(delta)
		_update_pending_photos(delta)
		_check_warnings(delta)
		_tick_autosave(delta)
	_transmit_armed = maxf(0.0, _transmit_armed - delta)
	_update_shake(delta)

func _tick_autosave(delta: float) -> void:
	_save_accum += delta
	if _save_accum < AUTOSAVE_INTERVAL:
		return
	_save_accum = 0.0
	if sim.game_over or (hud != null and hud.is_overlay_open()):
		return
	save_now()

func _update_pending_photos(delta: float) -> void:
	if _pending_photos.is_empty():
		return
	var i := _pending_photos.size() - 1
	while i >= 0:
		_pending_photos[i]["t"] = float(_pending_photos[i].get("t", 0.0)) - delta
		if float(_pending_photos[i]["t"]) <= 0.0:
			var path := str(_pending_photos[i].get("path", ""))
			if path != "" and not (path in developed_photos):
				developed_photos.append(path)
			_pending_photos.remove_at(i)
			hud.show_toast("Снимок проявлен. Доска фото обновлена.", 3.0)
			if audio != null:
				audio.play_ui("beep")
		i -= 1

func _check_warnings(delta: float) -> void:
	# CO₂ — главный таймер.
	if sim.co2 > 3.0 and not _co2_warned:
		_co2_warned = true
		_warn("co2", "CO₂ %.2f %% · замените патрон" % sim.co2, 1.0)
		director.radio("warn_co2")
	elif sim.co2 < 2.4:
		_co2_warned = false
	if sim.water_cm > 6.0 and not _water_warned:
		_water_warned = true
		_warn("water", "Вода в трюме: %.1f см. Помпа слева." % sim.water_cm, 1.0)
		director.radio("warn_water")
	elif sim.water_cm < 4.0:
		_water_warned = false
	if sim.battery_pct() < 22.0 and not _low_batt_warned:
		_low_batt_warned = true
		_warn("battery", "АКБ %.0f %% · генератор в корме" % sim.battery_pct(), 1.0)
	elif sim.battery_pct() > 35.0:
		_low_batt_warned = false
	if sim.leak_rate > 8.0 and not sim.leak_patched:
		_warn("leak", "Течь не заделана. Давление растёт.", 45.0)
	if sim.hull < 60.0:
		_warn("hull", "Корпус: %.0f %%. Удар за ударом." % sim.hull, 50.0)
	# Шум и Слушатель.
	if sim.noise_level > 58.0 and sim.time - _listener_warn_at > 48.0:
		_listener_warn_at = sim.time
		_warn("noise", "Слишком шумно. Оно слышит.", 48.0)
		director.radio("warn_noise")
	if listener.state in ["circle", "strike"] and sim.time - _listener_warn_at > 6.0:
		_listener_warn_at = sim.time
		_warn("listener", "Что-то у корпуса. Замри.", 8.0)

func _warn(key: String, text: String, cooldown: float) -> void:
	var now: float = sim.time
	if now - float(_warn_at.get(key, -999.0)) < cooldown:
		return
	_warn_at[key] = now
	if hud != null:
		hud.show_toast(text, 3.4)

func _update_shake(delta: float) -> void:
	if player == null or player.camera == null:
		return
	if _shake > 0.001:
		_shake = maxf(0.0, _shake - delta * 1.7)
		var amp := _shake * _shake * 0.022
		player.camera.position = Vector3(
			_rng.randf_range(-amp, amp),
			_rng.randf_range(-amp, amp),
			_rng.randf_range(-amp * 0.4, amp * 0.4)
		)
	else:
		player.camera.position = player.camera.position.lerp(Vector3.ZERO, clampf(delta * 9.0, 0.0, 1.0))

# ---------------------------------------------------------------------------
# Публичный API для HUD и мира
# ---------------------------------------------------------------------------

func is_final_available() -> bool:
	return director != null and director.final_available

func identify_signal(id: String) -> void:
	if sim == null or sim.game_over:
		return
	if sim.current_signal == "":
		hud.show_toast("В эфире тишина. Нечего опознавать.", 2.4)
		return
	var ok: bool = sim.identify(id)
	if ok:
		hud.show_toast("Сигнал записан: %s" % str(CapsuleSim.SIGNAL_NAMES.get(id, id)), 3.0)
		if audio != null:
			audio.play_ui("beep")
		if id == "bell":
			hud.show_radio("Это не техногенный шум. Это колокол.", "ВЕРА", 4.0)
	else:
		hud.show_toast("Не совпадает. Слушай ещё.", 2.2)
		if audio != null:
			audio.play_ui("click")

func show_subtitle(text: String, duration: float = 4.0) -> void:
	if hud != null:
		hud.show_subtitle(text, duration)

func show_toast(text: String, duration: float = 3.0) -> void:
	if hud != null:
		hud.show_toast(text, duration)

func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)

func save_now() -> void:
	if sim == null or sim.game_over:
		return
	Save.save_game(_state())

func _state() -> Dictionary:
	return {
		"sim": sim.serialize(),
		"director": director.serialize(),
		"listener": listener.serialize(),
		"photos": developed_photos.duplicate(),
		"tape_index": _tape_index,
	}

func _sync_devices() -> void:
	if cabin == null:
		return
	for key in sim.switches.keys():
		if cabin.devices.has(key):
			var d := cabin.devices[key] as Device
			if d != null:
				d.set_value(1.0 if bool(sim.switches[key]) else 0.0)
	var knobs := {
		"gain": sim.gain / 10.0,
		"filter": float(sim.filter_mode) / 2.0,
		"channel": float(sim.channel_mode) / 2.0,
		"bell_trim": (sim.bell_trim - 40.0) / 15.0,
		"o2": 1.0 if sim.o2_valve_open else 0.0,
		"radio_channel": float(sim.radio_channel - 1) / 2.0,
		"winch": inverse_lerp(30.0, 62.0, sim.target_depth),
	}
	for key in knobs.keys():
		if cabin.devices.has(key):
			var dk := cabin.devices[key] as Device
			if dk != null:
				dk.set_value(float(knobs[key]))

# ---------------------------------------------------------------------------
# Обработка кабины
# ---------------------------------------------------------------------------

func _on_cabin_action(id: String, value: Variant) -> void:
	match id:
		"wipe":
			hud.show_toast("Стекло протёрто. Мир снова виден.", 2.2)
			if audio != null:
				audio.play_ui("valve")
		"patch":
			if audio != null:
				audio.play_ui("clunk")
		"scrubber":
			if audio != null:
				audio.play_ui("clunk")
		"thermos":
			hud.show_toast("Кофе. Ещё тёплый.", 2.2)
		"manual_pump":
			if bool(value) and audio != null:
				audio.play_ui("clunk")
		"ping":
			if post != null:
				post.pulse_flash(0.18, 0.16)
			if audio != null:
				audio.play_sfx("ping", Vector3(0.0, 0.2, -1.0), -12.0)
		"notebook":
			hud.open_notebook()
		"camera":
			player.enter_camera_mode()
		"photo_board":
			hud.open_board()
		"tape_next":
			_tape_index = (_tape_index + 1) % TAPE_ORDER.size()
			_announce_tape()
		"tape_play":
			_play_tape()
		"radio_channel":
			_on_radio_channel(int(round(float(value) * 2.0)) + 1)
		"transmit":
			_transmit()
		"cable_cutter":
			if bool(value):
				_cut_cable()
		"ballast":
			if bool(value):
				_jettison_ballast()
		_:
			pass

func _announce_tape() -> void:
	var id: String = TAPE_ORDER[_tape_index]
	var t: Dictionary = audio.tapes.get(id, {}) if audio != null else {}
	hud.show_toast(str(t.get("title", id)), 2.6)
	if audio != null:
		audio.play_ui("click")

func _play_tape() -> void:
	var id: String = TAPE_ORDER[_tape_index]
	if sim.tapes_played.has(id):
		hud.show_toast("Эта лента уже прослушана.", 2.2)
		return
	sim.play_tape(id)
	if audio != null:
		audio.play_tape(id)
	hud.show_toast("Лента: %s" % str(audio.tapes.get(id, {}).get("title", id)), 2.4)

func _on_radio_channel(ch: int) -> void:
	match ch:
		1:
			hud.show_toast("Канал 1 · Вера на связи.", 2.0)
		2:
			if audio != null:
				audio.play_voice_text("ch2", "…канал два. Здесь только вода. И кто-то дышит.", "НЕИЗВЕСТНЫЙ", 5.0)
		3:
			if audio != null:
				audio.play_voice_text("ch3", "…ноль. Ноль. Ноль. Ты уже ответил.", "ХОР", 4.5)

func _transmit() -> void:
	if sim.game_over or _ending_shown:
		return
	if director != null and director.final_available:
		if sim.current_signal == "bell":
			if _transmit_armed > 0.0:
				sim.trigger_ending("answer")
			else:
				_transmit_armed = 6.0
				hud.show_toast("Передача открыта. Повторное нажатие — ответ.", 3.0)
				if audio != null:
					audio.play_ui("click")
		else:
			sim.trigger_ending("keep")
		return
	if audio != null:
		audio.play_radio("return_01")
	hud.show_toast("Вера не отвечает. Только помехи.", 2.4)
	sim.add_noise(4.0, Vector3.ZERO, 0.2)

func _cut_cable() -> void:
	if sim.cable_cut:
		return
	sim.cut_cable()
	shake(0.72)
	if post != null:
		post.pulse_flash(0.3, 0.3)
	if audio != null:
		audio.play_sfx("clunk", Vector3(0.0, 0.0, 0.8), -2.0)

func _jettison_ballast() -> void:
	if sim.ballast_jettisoned:
		return
	sim.jettison_ballast()
	shake(0.55)
	if audio != null:
		audio.play_sfx("clunk", Vector3(0.0, -0.2, 0.8), -4.0)
	if not sim.cable_cut:
		hud.show_toast("Балласт сброшен. Теперь режь трос — или жди.", 4.0)

# ---------------------------------------------------------------------------
# Сигналы симуляции и режиссёра
# ---------------------------------------------------------------------------

func _on_message(text: String) -> void:
	if hud != null:
		hud.show_toast(text, 3.4)

func _on_impact(strength: float) -> void:
	shake(clampf(strength / 13.0, 0.2, 1.0))
	if post != null:
		post.pulse_flash(0.28, 0.2)
	if hud != null:
		hud.show_toast("Удар по корпусу.", 2.0)

func _on_task_done(id: String) -> void:
	var label := id
	for t in sim.task_list():
		if str(t.get("id", "")) == id:
			label = str(t.get("text", id))
			break
	if hud != null:
		hud.show_toast("ЗАДАЧА ВЫПОЛНЕНА · %s" % label, 3.2)
	if audio != null:
		audio.play_ui("beep")

func _on_act_changed(act: int) -> void:
	match act:
		2:
			hud.show_toast("АКТ II · Кабель перебит. Работаем от АКБ.", 5.0)
			if post != null:
				post.pulse_flash(0.5, 0.35)
			if audio != null:
				audio.play_ui("alarm")
		3:
			hud.show_toast("АКТ III · Колокол не умолкает.", 5.0)
			if post != null:
				post.pulse_flash(0.65, 0.5)
			if audio != null:
				audio.play_sfx("chorus", Vector3(0.0, -2.0, -6.0), -14.0)

func _on_bell(strength: float) -> void:
	shake(clampf(strength * 0.35, 0.1, 0.5))
	if post != null:
		post.pulse_flash(0.2, 0.4)
	if audio != null:
		audio.play_sfx_at_bus("bell", Vector3(0.0, 0.4, -5.0), -20.0, "Underwater")

func _on_director_event(name: String, data: Dictionary) -> void:
	match name:
		"power_cut":
			hud.show_toast("Питание с поверхности потеряно.", 3.5)
		"leak":
			shake(0.4)
			hud.show_toast("Пробоина. Вода идёт в трюм.", 4.0)
		"final_available":
			hud.show_toast("ФИНАЛ ДОСТУПЕН · корма: балласт и трос", 6.0)
		"act3":
			pass
		"signal":
			pass

func _on_listener_state(state: String) -> void:
	if state == "circle":
		_warn("circle", "Оно обходит капсулу. Не шуми.", 20.0)
	elif state == "strike":
		shake(0.9)
		if post != null:
			post.pulse_flash(0.55, 0.4)
		_warn("strike", "УДАР.", 6.0)
	elif state == "retreat":
		_warn("retreat", "Оно отходит. Пока.", 30.0)

func _on_photo_taken(path: String, target_id: String) -> void:
	_pending_photos.append({"path": path, "t": PHOTO_DEV_TIME})
	hud.show_toast("Кадр ушёл в проявку. 20 секунд.", 2.6)
	if target_id == "bell" and audio != null:
		audio.play_radio("photo_01")

# ---------------------------------------------------------------------------
# Финал
# ---------------------------------------------------------------------------

func _on_ending(id: String) -> void:
	if _ending_shown:
		return
	_ending_shown = true
	Save.delete_save()
	var line := ""
	match id:
		"surface":
			line = "end_surface"
		"answer":
			line = "end_answer"
		"keep":
			line = "end_keep"
	if line != "" and audio != null:
		audio.play_radio(line)
	if hud != null:
		hud.show_toast("Смена окончена.", 2.0)
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(self):
		return
	var stats := "СМЕНА 47 · %s · ГЛУБИНА %.1f М · СИГНАЛОВ %d/10 · СНИМКОВ %d · ШУМ %.0f" % [
		hud.format_time(sim.time),
		sim.depth,
		sim.identified.size(),
		sim.photo_count(),
		sim.average_noise(20.0),
	]
	if hud != null:
		hud.show_ending(id, stats)
	if audio != null:
		audio.stop_all()
		audio.set_paused(true)

func _exit_tree() -> void:
	if sim != null and not sim.game_over and not _ending_shown:
		save_now()
	if Game.settings_changed.is_connected(_on_settings_changed):
		Game.settings_changed.disconnect(_on_settings_changed)
	Game.unregister_game(self)
