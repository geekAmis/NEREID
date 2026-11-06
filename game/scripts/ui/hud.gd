class_name GameHUD
extends CanvasLayer
## Диегетический HUD: шкалы, часы, задача, луч, субтитры, блокнот,
## доска фото, камера, пауза и финальный экран. Всё строится кодом.

var sim = null
var player: Player = null
var post: PostProcess = null
var game_scene = null

var _root: Control
var ui_font: Font
var _status: StatusPanel
var _reticle: Reticle
var _clock: Label
var _tasks_panel: PanelContainer
var _tasks_label: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_bar: ProgressBar
var _subs: PanelContainer
var _subs_speaker: Label
var _subs_text: Label
var _subs_timer := 0.0
var _toast: PanelContainer
var _toast_label: Label
var _toast_timer := 0.0
var _camera_frame: CameraFrame
var _camera_label: Label
var _notebook: Control
var _nb_tasks: Label
var _nb_signals: Label
var _nb_catalog: GridContainer
var _catalog_key := ""
var _nb_stats: Label
var _board: Control
var _board_grid: GridContainer
var _pause: Control
var _ending: Control
var _ending_title: Label
var _ending_text: Label
var _ending_stats: Label
var _ending_hint: Label
var _intro: Control
var _fade: ColorRect
var _settings: SettingsPanel
var _focus = null
var _prompt_text := ""
var _prompt_progress := 0.0
var _task_accum := 0.0
var _nb_accum := 0.0
var _hud_visible := true
var _camera_mode := false
var _tex_cache: Dictionary = {}

const FONT_REG := "res://assets/fonts/PT_Sans-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/PT_Sans-Bold.ttf"
const FONT_MONO := "res://assets/fonts/JetBrainsMono.ttf"

const C_BONE := Color(0.86, 0.82, 0.69)
const C_DIM := Color(0.55, 0.62, 0.57)
const C_GREEN := Color(0.52, 0.92, 0.66)
const C_AMBER := Color(0.95, 0.68, 0.30)
const C_RED := Color(0.92, 0.28, 0.18)
const C_CYAN := Color(0.45, 0.83, 0.88)

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func setup(p_sim, p_player: Player, p_post: PostProcess, p_game) -> void:
	sim = p_sim
	player = p_player
	post = p_post
	game_scene = p_game
	if Game.settings_changed.is_connected(_on_settings_changed):
		pass
	else:
		Game.settings_changed.connect(_on_settings_changed)
	_on_settings_changed()
	_capture(true)
	_show_intro()
	_play_fade()
	if sim != null:
		show_toast("СМЕНА 47 · 42 М · 09:14", 4.0)

func _build() -> void:
	var theme := Theme.new()
	var f := load(FONT_REG) as Font
	if f == null:
		f = ThemeDB.fallback_font
	ui_font = f
	theme.default_font = f
	theme.default_font_size = 16

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_full(_root)

	_status = StatusPanel.new()
	_status.hud = self
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_status, 0.0, 0.0, 360.0, 296.0, 24.0, 22.0)
	_root.add_child(_status)

	_clock = _label("СМЕНА 47  ·  00:00:00", 15, C_DIM, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_clock, 0.5, 0.0, 360.0, 26.0, -180.0, 18.0)
	_root.add_child(_clock)

	_tasks_panel = PanelContainer.new()
	_tasks_panel.add_theme_stylebox_override("panel", _style(Color(0.015, 0.030, 0.030, 0.66), Color(0.22, 0.34, 0.30, 0.7)))
	_place(_tasks_panel, 1.0, 0.0, 370.0, 176.0, -394.0, 22.0)
	_tasks_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tasks_panel)
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 14)
	tm.add_theme_constant_override("margin_right", 14)
	tm.add_theme_constant_override("margin_top", 10)
	tm.add_theme_constant_override("margin_bottom", 10)
	_tasks_panel.add_child(tm)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tm.add_child(tv)
	tv.add_child(_label("ЗАДАЧА СМЕНЫ", 12, Color(0.56, 0.72, 0.62), true))
	_tasks_label = _label("", 14, C_BONE)
	_tasks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_tasks_label)

	_reticle = Reticle.new()
	_reticle.hud = self
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(_reticle)
	_root.add_child(_reticle)

	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _style(Color(0.012, 0.024, 0.024, 0.88), Color(0.34, 0.42, 0.34, 0.9)))
	_place(_prompt, 0.5, 1.0, 560.0, 58.0, -280.0, -132.0)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	_root.add_child(_prompt)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 14)
	pm.add_theme_constant_override("margin_right", 14)
	pm.add_theme_constant_override("margin_top", 7)
	pm.add_theme_constant_override("margin_bottom", 7)
	_prompt.add_child(pm)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 3)
	pm.add_child(pv)
	_prompt_label = _label("", 17, C_BONE)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_prompt_label)
	_prompt_bar = ProgressBar.new()
	_prompt_bar.max_value = 100.0
	_prompt_bar.show_percentage = false
	_prompt_bar.custom_minimum_size = Vector2(0, 8)
	_prompt_bar.visible = false
	_prompt_bar.add_theme_stylebox_override("background", _style(Color(0.02, 0.04, 0.04, 1.0), Color(0.24, 0.34, 0.30)))
	_prompt_bar.add_theme_stylebox_override("fill", _style(Color(0.65, 0.52, 0.25, 1.0), Color(0.85, 0.70, 0.35)))
	pv.add_child(_prompt_bar)

	_subs = PanelContainer.new()
	_subs.add_theme_stylebox_override("panel", _style(Color(0.008, 0.016, 0.018, 0.88), Color(0.20, 0.32, 0.30, 0.85)))
	_place(_subs, 0.5, 1.0, 800.0, 82.0, -400.0, -222.0)
	_subs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subs.visible = false
	_root.add_child(_subs)
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 16)
	sm.add_theme_constant_override("margin_right", 16)
	sm.add_theme_constant_override("margin_top", 8)
	sm.add_theme_constant_override("margin_bottom", 8)
	_subs.add_child(sm)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sm.add_child(sv)
	_subs_speaker = _label("ВЕРА", 11, C_GREEN, true)
	sv.add_child(_subs_speaker)
	_subs_text = _label("", 17, C_BONE)
	_subs_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_subs_text)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style(Color(0.012, 0.026, 0.026, 0.9), Color(0.38, 0.48, 0.36, 0.85)))
	_place(_toast, 0.5, 0.0, 520.0, 42.0, -260.0, 64.0)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)
	var tom := MarginContainer.new()
	tom.add_theme_constant_override("margin_left", 14)
	tom.add_theme_constant_override("margin_right", 14)
	tom.add_theme_constant_override("margin_top", 6)
	tom.add_theme_constant_override("margin_bottom", 6)
	_toast.add_child(tom)
	_toast_label = _label("", 15, C_BONE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tom.add_child(_toast_label)

	_camera_frame = CameraFrame.new()
	_camera_frame.hud = self
	_camera_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(_camera_frame)
	_camera_frame.visible = false
	_root.add_child(_camera_frame)

	_camera_label = _label("", 14, Color(0.86, 0.88, 0.80), true)
	_camera_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_camera_label, 0.5, 1.0, 620.0, 24.0, -310.0, -104.0)
	_camera_label.visible = false
	_root.add_child(_camera_label)

	_build_notebook()
	_build_board()
	_build_pause()
	_build_ending()
	_build_intro()
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.008, 0.012, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(_fade)
	_root.add_child(_fade)

func _build_notebook() -> void:
	_notebook = Control.new()
	_notebook.name = "Notebook"
	_full(_notebook)
	_notebook.visible = false
	_root.add_child(_notebook)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.012, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_full(dim)
	_notebook.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	_notebook.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 680)
	panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.030, 0.029, 0.985), Color(0.34, 0.42, 0.34, 0.9)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var title := _label("БЛОКНОТ СМЕНЫ · NEREID-7", 26, C_BONE, true)
	vb.add_child(title)
	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 2)
	vb.add_child(rule)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(_label("ЗАДАЧИ", 14, C_GREEN, true))
	_nb_tasks = _label("", 15, C_BONE)
	_nb_tasks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nb_tasks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_nb_tasks)

	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(400, 0)
	mid.add_theme_constant_override("separation", 6)
	cols.add_child(mid)
	mid.add_child(_label("КАТАЛОГ СИГНАЛОВ", 14, C_GREEN, true))
	_nb_signals = _label("", 12, C_DIM)
	_nb_signals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_nb_signals)
	_nb_catalog = GridContainer.new()
	_nb_catalog.columns = 2
	_nb_catalog.add_theme_constant_override("h_separation", 6)
	_nb_catalog.add_theme_constant_override("v_separation", 4)
	_nb_catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_nb_catalog)
	mid.add_child(_label("Слышишь сигнал — нажми подходящее название.\nОшибка стоит нервов.", 11, Color(0.48, 0.54, 0.48)))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(290, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(_label("СМЕНА", 14, C_GREEN, true))
	_nb_stats = _label("", 14, Color(0.68, 0.74, 0.68))
	_nb_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_nb_stats)
	right.add_child(_label("ПОМЕТКИ", 14, C_GREEN, true))
	var notes := _label("Слушать. Не шуметь. Не отвечать.\n\n47,0 Гц — не техногенный шум.\nЕсли колокол зовёт — это не Вера.", 13, Color(0.62, 0.60, 0.50))
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(notes)

	var foot := _label("TAB / ESC — ЗАКРЫТЬ", 12, C_DIM, true)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(foot)

func _build_board() -> void:
	_board = Control.new()
	_board.name = "PhotoBoard"
	_full(_board)
	_board.visible = false
	_root.add_child(_board)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.012, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_full(dim)
	_board.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	_board.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 700)
	panel.add_theme_stylebox_override("panel", _style(Color(0.020, 0.028, 0.026, 0.985), Color(0.36, 0.40, 0.32, 0.9)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	vb.add_child(_label("ДОСКА ФОТО", 25, C_BONE, true))
	vb.add_child(_label("Проявка занимает 20 секунд. Снимки остаются между сменами.", 12, C_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_board_grid = GridContainer.new()
	_board_grid.columns = 4
	_board_grid.add_theme_constant_override("h_separation", 10)
	_board_grid.add_theme_constant_override("v_separation", 10)
	_board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_board_grid)
	var foot := _label("TAB / ESC — ЗАКРЫТЬ", 12, C_DIM, true)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(foot)

func _build_pause() -> void:
	_pause = Control.new()
	_pause.name = "Pause"
	_full(_pause)
	_pause.visible = false
	_root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.012, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_full(dim)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	_pause.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 470)
	panel.add_theme_stylebox_override("panel", _style(Color(0.016, 0.030, 0.031, 0.98), Color(0.32, 0.42, 0.36, 0.9)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var title := _label("ПАУЗА", 32, C_BONE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _label("Смена приостановлена", 12, C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var buttons := [
		["ПРОДОЛЖИТЬ", _resume],
		["НАСТРОЙКИ", _open_settings],
		["В ГЛАВНОЕ МЕНЮ", _to_menu],
		["ВЫЙТИ ИЗ ИГРЫ", _quit_game],
	]
	for b in buttons:
		var btn := _button(str(b[0]))
		btn.pressed.connect(b[1])
		vb.add_child(btn)
	var warn := _label("Клаустрофобия · вспышки света · тревожные звуки", 10, Color(0.50, 0.38, 0.32))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(warn)

	_settings = SettingsPanel.new()
	_root.add_child(_settings)
	_settings.closed.connect(_on_settings_closed)

func _build_ending() -> void:
	_ending = Control.new()
	_ending.name = "Ending"
	_full(_ending)
	_ending.visible = false
	_root.add_child(_ending)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.006, 0.008, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_full(dim)
	_ending.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	_ending.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	panel.add_theme_stylebox_override("panel", _style(Color(0.014, 0.024, 0.026, 0.99), Color(0.32, 0.40, 0.34, 0.95)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)
	_ending_title = _label("СМЕНА ОКОНЧЕНА", 38, C_BONE, true)
	_ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_ending_title)
	_ending_text = _label("", 18, C_BONE)
	_ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_ending_text)
	_ending_stats = _label("", 13, C_DIM)
	_ending_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_ending_stats)
	_ending_hint = _label("", 12, Color(0.55, 0.48, 0.38))
	_ending_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_ending_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var again := _button("ЕЩЁ СМЕНА")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_restart)
	row.add_child(again)
	var menu := _button("В МЕНЮ")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(_to_menu)
	row.add_child(menu)

func _build_intro() -> void:
	_intro = Control.new()
	_intro.name = "Intro"
	_full(_intro)
	_root.add_child(_intro)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.008, 0.010, 1.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(dim)
	_intro.add_child(dim)
	var center := CenterContainer.new()
	_full(center)
	_intro.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	center.add_child(vb)
	var title := _label("НЕРЕИДА", 74, Color(0.83, 0.80, 0.66), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _label("ПОСЛЕДНИЙ СЕАНС", 16, Color(0.48, 0.66, 0.62), true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var meta := _label("СМЕНА 47  ·  42 М  ·  1979", 13, Color(0.42, 0.50, 0.46))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(meta)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	vb.add_child(gap)
	var hint := _label("WASD — идти   ·   E / ЛКМ — трогать   ·   F — фонарь   ·   TAB — блокнот", 12, Color(0.44, 0.54, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

func _show_intro() -> void:
	_intro.visible = true
	_intro.modulate.a = 1.0
	if player != null:
		player.set_input_blocked(true)
	await get_tree().create_timer(3.8).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 0.0, 1.7)
	await tw.finished
	if not is_instance_valid(self):
		return
	_intro.visible = false
	if player != null and not _pause.visible and not _ending.visible:
		player.set_input_blocked(false)

func _play_fade() -> void:
	_fade.visible = true
	_fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 2.2)
	await tw.finished
	if is_instance_valid(self):
		_fade.visible = false

# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock.text = "СМЕНА 47  ·  %s  ·  АКТ %d" % [format_time(sim.time), sim.act]
	_clock.visible = _hud_visible
	_status.queue_redraw()
	_reticle.queue_redraw()
	_task_accum += delta
	if _task_accum >= 0.35:
		_task_accum = 0.0
		_update_tasks()
	_toast_timer = maxf(0.0, _toast_timer - delta)
	if _toast_timer <= 0.0 and _toast.visible:
		_toast.visible = false
	elif _toast.visible and _toast_timer < 0.7:
		_toast.modulate.a = clampf(_toast_timer / 0.7, 0.0, 1.0)
	_subs_timer = maxf(0.0, _subs_timer - delta)
	if _subs_timer <= 0.0 and _subs.visible:
		_subs.visible = false
	var d := 0.0
	d = maxf(d, clampf(sim.co2 / 4.6, 0.0, 1.0) * 0.92)
	d = maxf(d, clampf(sim.water_cm / 19.0, 0.0, 1.0) * 0.82)
	d = maxf(d, clampf((100.0 - sim.hull) / 65.0, 0.0, 1.0))
	d = maxf(d, sim.stress * 0.62)
	if _camera_mode:
		d *= 0.55
	if post != null:
		post.set_danger(d)
	if _notebook.visible:
		_nb_accum += delta
		if _nb_accum > 0.5:
			_nb_accum = 0.0
			_update_notebook()
	if _camera_label.visible:
		_camera_label.text = "КАДР %d / 12   ·   50 ММ   ·   SPACE — СНЯТЬ   ·   Z / ПКМ — ЗУМ   ·   Q — ВЫЙТИ" % [sim.film]

func _update_tasks() -> void:
	if sim == null:
		return
	var lines := PackedStringArray()
	var shown := 0
	for t in sim.task_list():
		if bool(t.get("done", false)):
			continue
		if shown >= 4:
			break
		lines.append("· " + str(t.get("text", "")))
		shown += 1
	if lines.is_empty():
		lines.append("· Все задачи выполнены.")
		lines.append("· Осмотрись. Слушай.")
	if game_scene != null and game_scene.has_method("is_final_available") and game_scene.is_final_available():
		lines.append("● ФИНАЛ: корма. Трос. Балласт.")
	_tasks_label.text = "\n".join(lines)

func _update_notebook() -> void:
	if sim == null:
		return
	var tl := PackedStringArray()
	for t in sim.task_list():
		tl.append(("[X] " if bool(t.get("done", false)) else "[ ] ") + str(t.get("text", "")))
	_nb_tasks.text = "\n".join(tl)
	_nb_signals.text = "Опознано: %d / 10   ·   %s" % [
		sim.identified.size(),
		"в эфире сигнал" if sim.current_signal != "" else "в эфире тишина",
	]
	_rebuild_catalog()
	var stats := PackedStringArray()
	stats.append("Время: " + format_time(sim.time))
	stats.append("Глубина: %.1f м" % sim.depth)
	stats.append("Плёнка: %d / 12" % sim.film)
	stats.append("Снимков: %d" % sim.photo_count())
	stats.append("Бобин: %d" % sim.recordings)
	stats.append("CO₂: %.2f %%" % sim.co2)
	stats.append("Вода: %.1f см" % sim.water_cm)
	stats.append("Шум: %.0f" % sim.noise_level)
	stats.append("Трос: %.2f т" % sim.cable_tension)
	stats.append("АКБ: %.0f %%" % sim.battery_pct())
	_nb_stats.text = "\n".join(stats)

func _rebuild_catalog() -> void:
	if _nb_catalog == null or sim == null:
		return
	var key := "%d|%s" % [sim.identified.size(), sim.current_signal]
	if key == _catalog_key and _nb_catalog.get_child_count() == CapsuleSim.KNOWN_SIGNALS.size():
		return
	_catalog_key = key
	for child in _nb_catalog.get_children():
		child.queue_free()
	for id in CapsuleSim.KNOWN_SIGNALS:
		var known: bool = id in sim.identified
		var nm := str(CapsuleSim.SIGNAL_NAMES.get(id, id))
		var b := _button(("✓  " if known else "") + nm)
		b.custom_minimum_size = Vector2(0, 31)
		b.add_theme_font_size_override("font_size", 13)
		b.disabled = known
		b.tooltip_text = "Уже опознано" if known else "Отметить как «%s»" % nm
		b.pressed.connect(_on_catalog_pressed.bind(id))
		_nb_catalog.add_child(b)

func _on_catalog_pressed(id: String) -> void:
	if game_scene != null and game_scene.has_method("identify_signal"):
		game_scene.identify_signal(id)
	_catalog_key = ""
	_update_notebook()

# ---------------------------------------------------------------------------
# Public HUD API
# ---------------------------------------------------------------------------

func format_time(seconds: float) -> String:
	var s := int(maxf(0.0, seconds))
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]

func set_prompt(text: String, progress: float = 0.0) -> void:
	_prompt_text = text
	_prompt_progress = progress
	if text == "" or _camera_mode or not _hud_visible:
		_prompt.visible = false
		return
	_prompt.visible = true
	_prompt_label.text = text
	_prompt_bar.visible = progress > 0.001
	_prompt_bar.value = progress * 100.0

func set_focus(target) -> void:
	_focus = target
	_reticle.queue_redraw()

func show_radio(text: String, speaker: String = "ВЕРА", duration: float = 4.0) -> void:
	if not bool(Game.settings.get("subtitles", true)):
		return
	_subs_speaker.text = speaker.to_upper()
	_subs_text.text = text
	_subs.visible = true
	_subs.modulate.a = 1.0
	_subs_timer = duration

func show_subtitle(text: String, duration: float = 3.0) -> void:
	show_radio(text, "СИСТЕМА", duration)

func show_toast(text: String, duration: float = 3.0) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_timer = duration

func show_camera(active: bool, film: int) -> void:
	_camera_mode = active
	_camera_frame.visible = active
	_camera_label.visible = active
	_prompt.visible = false
	if active:
		_camera_label.text = "КАДР %d / 12   ·   50 ММ   ·   SPACE — СНЯТЬ   ·   Z / ПКМ — ЗУМ   ·   Q — ВЫЙТИ" % film
	_reticle.queue_redraw()

func open_notebook() -> void:
	if _pause.visible or _ending.visible or _notebook.visible:
		return
	_close_board()
	_notebook.visible = true
	_update_notebook()
	player.set_input_blocked(true)
	_capture(false)

func close_notebook() -> void:
	_notebook.visible = false
	if not _pause.visible and not _ending.visible and not _board.visible:
		player.set_input_blocked(false)
		_capture(true)

func open_board() -> void:
	if _pause.visible or _ending.visible or _board.visible:
		return
	_close_notebook()
	_board.visible = true
	_fill_board()
	player.set_input_blocked(true)
	_capture(false)

func close_board() -> void:
	_board.visible = false
	if not _pause.visible and not _ending.visible and not _notebook.visible:
		player.set_input_blocked(false)
		_capture(true)

func open_pause() -> void:
	if _ending.visible:
		return
	_close_notebook()
	_close_board()
	_pause.visible = true
	get_tree().paused = true
	if player != null:
		player.set_input_blocked(true)
	_capture(false)
	if Game.audio != null:
		Game.audio.set_paused(true)

func resume_game() -> void:
	_pause.visible = false
	get_tree().paused = false
	if player != null:
		player.set_input_blocked(false)
	_capture(true)
	if Game.audio != null:
		Game.audio.set_paused(false)

func show_ending(id: String, stats_text: String = "") -> void:
	_ending.visible = true
	get_tree().paused = true
	_capture(false)
	if player != null:
		player.set_input_blocked(true)
	_pause.visible = false
	_notebook.visible = false
	_board.visible = false
	var data := ending_data(id)
	_ending_title.text = str(data.get("title", "СМЕНА ОКОНЧЕНА"))
	_ending_title.add_theme_color_override("font_color", data.get("color", C_BONE))
	_ending_text.text = str(data.get("text", ""))
	_ending_stats.text = stats_text
	_ending_hint.text = str(data.get("hint", ""))
	if Game.audio != null:
		Game.audio.set_paused(true)

func ending_data(id: String) -> Dictionary:
	match id:
		"surface":
			return {"title": "ВСПЛЫТИЕ", "color": C_GREEN, "text": "Балласт ушёл. Капсула рванулась вверх, и вода отпустила вас. Наверху был свет, дождь и Вера, которая не задавала вопросов. Колокол остался внизу. Он не звонил. Он ждал.", "hint": "Вы ответили не колоколу, а себе. Это редкий финал."}
		"answer":
			return {"title": "ОТВЕТ", "color": C_RED, "text": "Вы нажали передачу. В эфире не было помех. Только ваш голос, повторённый хором. Вера не ответила. Вера больше не была на связи. Теперь вы — часть сигнала.", "hint": "Не отвечай. Вы ответили."}
		"keep":
			return {"title": "ХРАНИТЕЛЬ", "color": Color(0.78, 0.86, 0.80), "text": "Вы остались. Не из-за троса и не из-за воздуха. Просто остались. Колокол замолчал первым. Капсула стала комнатой. Комната стала домом. Кто-то должен слушать.", "hint": "Финал для тех, кто выключил радио и остался."}
		"asphyxia":
			return {"title": "АСФИКСИЯ", "color": C_RED, "text": "CO₂ поднялся выше пяти. Воздух стал тяжёлым, потом тёплым, потом никаким. Вера звала вас по имени. Вы слышали её через слой собственного дыхания.", "hint": "Патрон. Всегда меняйте патрон."}
		"hypoxia":
			return {"title": "ГИПОКСИЯ", "color": Color(0.72, 0.72, 0.70), "text": "Кислорода стало мало. Мир сузился до зелёного экрана и пульса в ушах. Вы записали ещё один сигнал. Он был очень похож на ваш.", "hint": "Следите за вентилем O₂."}
		"implosion":
			return {"title": "ИМПЛОЗИЯ", "color": C_RED, "text": "Корпус не выдержал. 5,2 бара нашли трещину и вошли внутрь. Всё, что было кабиной, стало пузырём. Всё, что было вами, стало частью воды.", "hint": "Латайте пробоину. Не ждите."}
		"flood":
			return {"title": "ЗАТОПЛЕНИЕ", "color": Color(0.32, 0.62, 0.70), "text": "Вода дошла до нижних цепей, потом до колен, потом до глаз. Экран погас. Последним, что вы слышали, был колокол. Он был ближе, чем пол.", "hint": "Помпа и латка. В таком порядке."}
		"dark":
			return {"title": "ТЕМНОТА", "color": Color(0.44, 0.44, 0.46), "text": "Аккумулятор умер. Свет, экран, вентиляция — всё стало тишиной. У вас остался только слух. И он сказал: «Я рядом».", "hint": "Генератор. Рукоятка. Терпение."}
		"cable":
			return {"title": "ТРОС ОБОРВАН", "color": Color(0.62, 0.48, 0.30), "text": "Трос лопнул. Капсула пошла вниз, мимо института, мимо колокольни, мимо глубины, у которой нет дна. Вера вызывала вас до самой последней секунды.", "hint": "Сбросьте балласт до того, как резать трос."}
	return {"title": "СМЕНА ОКОНЧЕНА", "color": C_BONE, "text": "Запись оборвалась.", "hint": ""}

func is_overlay_open() -> bool:
	return _notebook.visible or _board.visible or _pause.visible or _ending.visible

func hide_all_overlays() -> void:
	close_notebook()
	close_board()
	_pause.visible = false

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _fill_board() -> void:
	for child in _board_grid.get_children():
		child.queue_free()
	var photos: Array = []
	if game_scene != null:
		var p = game_scene.get("developed_photos")
		if p is Array:
			photos = p
	if photos.is_empty():
		var empty := _label("Пока пусто. Снимите что-нибудь через иллюминатор.", 15, C_DIM)
		empty.custom_minimum_size = Vector2(700, 60)
		_board_grid.add_child(empty)
		return
	for i in photos.size():
		var path := str(photos[i])
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(250, 160)
		box.add_theme_constant_override("separation", 4)
		var tex := _load_texture(path)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(240, 135)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex
		tr.add_theme_stylebox_override("panel", _style(Color(0.03, 0.04, 0.04, 1.0), Color(0.36, 0.40, 0.34)))
		box.add_child(tr)
		box.add_child(_label("КАДР %02d" % (i + 1), 11, C_DIM, true))
		_board_grid.add_child(box)

func _load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var abs := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(abs)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex

func _capture(on: bool) -> void:
	if _ending.visible:
		on = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _open_settings() -> void:
	_settings.open()

func _on_settings_closed() -> void:
	if _pause.visible:
		_capture(false)

func _resume() -> void:
	resume_game()

func _to_menu() -> void:
	get_tree().paused = false
	Game.goto_menu()

func _quit_game() -> void:
	get_tree().paused = false
	Game.quit_game()

func _restart() -> void:
	get_tree().paused = false
	Game.start_new_game()

func _close_notebook() -> void:
	if _notebook.visible:
		close_notebook()

func _close_board() -> void:
	if _board.visible:
		close_board()

func _on_settings_changed() -> void:
	_hud_visible = bool(Game.settings.get("hud", true))
	_apply_hud_visibility()
	if post != null:
		post.apply_quality(int(Game.settings.get("quality", 2)))

func _apply_hud_visibility() -> void:
	_status.visible = _hud_visible
	_clock.visible = _hud_visible
	_tasks_panel.visible = _hud_visible
	if not _hud_visible:
		_prompt.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _ending.visible:
			return
		if _settings.visible:
			_settings.hide()
			_capture(false)
			return
		if _notebook.visible:
			close_notebook()
			get_viewport().set_input_as_handled()
			return
		if _board.visible:
			close_board()
			get_viewport().set_input_as_handled()
			return
		if _pause.visible:
			resume_game()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("notebook"):
		if _pause.visible or _ending.visible:
			return
		if _notebook.visible:
			close_notebook()
		else:
			open_notebook()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("subtitles"):
		Game.set_setting("subtitles", not bool(Game.settings.get("subtitles", true)))
		show_toast("Субтитры: " + ("ВКЛ" if bool(Game.settings.get("subtitles", true)) else "ВЫКЛ"), 1.5)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hide_hud"):
		Game.set_setting("hud", not bool(Game.settings.get("hud", true)))
		get_viewport().set_input_as_handled()

func _label(text: String, size: int, color: Color, mono: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var f := load(FONT_MONO if mono else FONT_REG) as Font
	if f == null:
		f = ThemeDB.fallback_font
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	var f := load(FONT_REG) as Font
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.86, 0.82, 0.68))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.55))
	b.add_theme_stylebox_override("normal", _style(Color(0.05, 0.08, 0.078, 0.95), Color(0.22, 0.33, 0.30)))
	b.add_theme_stylebox_override("hover", _style(Color(0.08, 0.13, 0.12, 0.98), Color(0.50, 0.42, 0.24)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.03, 0.05, 0.05, 1.0), Color(0.62, 0.48, 0.24)))
	return b

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func _place(c: Control, ax: float, ay: float, w: float, h: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_top = oy
	c.offset_right = ox + w
	c.offset_bottom = oy + h

func _full(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

# ---------------------------------------------------------------------------
# Inner UI widgets
# ---------------------------------------------------------------------------

class Reticle extends Control:
	var hud
	func _draw() -> void:
		if hud == null:
			return
		if hud._camera_mode:
			return
		var c := size * 0.5
		var focus = hud._focus
		var col := Color(0.75, 0.78, 0.68, 0.55)
		var rad := 2.0
		if focus != null:
			col = Color(0.92, 0.80, 0.48, 0.92)
			rad = 2.8
		draw_circle(c, rad, col)
		if focus != null:
			draw_arc(c, 10.0, 0.0, TAU, 40, Color(0.92, 0.80, 0.48, 0.65), 1.2)
			draw_arc(c, 14.0, -0.5, 0.5, 16, Color(0.92, 0.80, 0.48, 0.45), 1.0)
			draw_arc(c, 14.0, PI - 0.5, PI + 0.5, 16, Color(0.92, 0.80, 0.48, 0.45), 1.0)

class StatusPanel extends Control:
	var hud
	func _draw() -> void:
		if hud == null or hud.sim == null:
			return
		var sim = hud.sim
		var font: Font = hud.ui_font
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.010, 0.020, 0.020, 0.76))
		draw_rect(rect, Color(0.30, 0.42, 0.37, 0.85), false, 1.0)
		draw_string(font, Vector2(14, 22), "NEREID-7  ·  СМЕНА 47", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.74, 0.86, 0.74))
		draw_string(font, Vector2(14, 40), "ГЛУБИНА 42 М  ·  ДАВЛЕНИЕ 5,2 БАР", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.64, 0.58))
		var rows := [
			["ГЛУБИНА", "%.1f м" % sim.depth, clampf(sim.depth / 80.0, 0.0, 1.0), Color(0.42, 0.76, 0.70)],
			["O₂", "%.1f %%" % sim.o2, clampf(sim.o2 / 25.0, 0.0, 1.0), Color(0.55, 0.88, 0.66) if sim.o2 > 17.0 else Color(0.95, 0.42, 0.22)],
			["CO₂", "%.2f %%" % sim.co2, clampf(sim.co2 / 6.0, 0.0, 1.0), Color(0.55, 0.88, 0.66) if sim.co2 < 2.4 else Color(0.95, 0.30, 0.16)],
			["ПИТАНИЕ", "%.0f %%" % sim.battery_pct(), clampf(sim.battery_pct() / 100.0, 0.0, 1.0), Color(0.90, 0.76, 0.38) if sim.battery_pct() > 30.0 else Color(0.95, 0.26, 0.14)],
			["ВОДА", "%.1f см" % sim.water_cm, clampf(sim.water_cm / 24.0, 0.0, 1.0), Color(0.38, 0.78, 0.84) if sim.water_cm < 8.0 else Color(0.95, 0.30, 0.18)],
			["ШУМ", "%.0f" % sim.noise_level, clampf(sim.noise_level / 100.0, 0.0, 1.0), Color(0.55, 0.86, 0.60) if sim.noise_level < 46.0 else Color(0.96, 0.46, 0.18)],
			["КОРПУС", "%.0f %%" % sim.hull, clampf(sim.hull / 100.0, 0.0, 1.0), Color(0.68, 0.82, 0.66) if sim.hull > 65.0 else Color(0.95, 0.30, 0.16)],
		]
		var y := 62.0
		for r in rows:
			var label := str(r[0])
			var val := str(r[1])
			var frac := float(r[2])
			var col: Color = r[3]
			draw_string(font, Vector2(14, y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.74, 0.78, 0.68))
			draw_string(font, Vector2(250, y + 12), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			var bar := Rect2(100, y + 2, 142, 9)
			draw_rect(bar, Color(0.02, 0.04, 0.04, 0.95))
			draw_rect(bar, Color(0.22, 0.30, 0.27, 0.8), false, 1.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), col * Color(1, 1, 1, 0.9))
			for tick in [0.25, 0.5, 0.75]:
				var x: float = bar.position.x + bar.size.x * float(tick)
				draw_line(Vector2(x, bar.position.y), Vector2(x, bar.position.y + bar.size.y), Color(0.0, 0.0, 0.0, 0.35), 1.0)
			y += 30.0

class CameraFrame extends Control:
	var hud
	func _draw() -> void:
		if hud == null:
			return
		var w := size.x
		var h := size.y
		var m := Vector2(w * 0.13, h * 0.12)
		var r := Rect2(m, Vector2(w - m.x * 2.0, h - m.y * 2.0))
		var col := Color(0.86, 0.88, 0.80, 0.55)
		# Уголки.
		var arm := 24.0
		draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x + arm, r.position.y), col, 2.0)
		draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.position.y + arm), col, 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - arm, r.position.y), col, 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + arm), col, 2.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + arm, r.end.y), col, 2.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - arm), col, 2.0)
		draw_line(Vector2(r.end.x, r.end.y), Vector2(r.end.x - arm, r.end.y), col, 2.0)
		draw_line(Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.end.y - arm), col, 2.0)
		# Центр.
		var c := Vector2(w, h) * 0.5
		draw_line(c - Vector2(12, 0), c + Vector2(12, 0), Color(0.9, 0.85, 0.62, 0.8), 1.2)
		draw_line(c - Vector2(0, 12), c + Vector2(0, 12), Color(0.9, 0.85, 0.62, 0.8), 1.2)
		draw_circle(c, 1.6, Color(0.95, 0.28, 0.18))
		# Сетка третей.
		for i in [1, 2]:
			var x := r.position.x + r.size.x * float(i) / 3.0
			var y := r.position.y + r.size.y * float(i) / 3.0
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.8, 0.82, 0.72, 0.10), 1.0)
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.8, 0.82, 0.72, 0.10), 1.0)
		# REC.
		draw_circle(Vector2(r.position.x + 18, r.position.y + 18), 4.0, Color(0.95, 0.18, 0.12, 0.9))
