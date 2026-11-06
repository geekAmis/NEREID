class_name SettingsPanel
extends Control
## Панель настроек, общая для главного меню и паузы.

signal closed

var _root: PanelContainer
var _font: Font
var _quality: OptionButton
var _lang: OptionButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/PT_Sans-Regular.ttf") as Font
	if _font == null:
		_font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()

func open() -> void:
	show()
	_sync()
	move_to_front()

func _sync() -> void:
	if _quality != null:
		_quality.selected = clampi(int(Game.settings.get("quality", 2)), 0, 2)
	if _lang != null:
		_lang.selected = 0 if str(Game.settings.get("lang", "ru")) == "ru" else 1

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.015, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_root = PanelContainer.new()
	_root.custom_minimum_size = Vector2(640, 620)
	_root.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_root.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := _label("НАСТРОЙКИ", 30, Color(0.86, 0.80, 0.64))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _label("Параметры применяются сразу", 14, Color(0.50, 0.60, 0.56))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 7)
	vb.add_child(grid)
	_add_slider(grid, "Общая громкость", "master", 0.0, 1.0, 0.01)
	_add_slider(grid, "Эффекты", "sfx", 0.0, 1.0, 0.01)
	_add_slider(grid, "Голос", "voice", 0.0, 1.0, 0.01)
	_add_slider(grid, "Музыка", "music", 0.0, 1.0, 0.01)
	_add_slider(grid, "Чувствительность мыши", "mouse", 0.0006, 0.006, 0.0001)
	_add_slider(grid, "Угол обзора", "fov", 50.0, 90.0, 1.0)

	var checks := GridContainer.new()
	checks.columns = 2
	checks.add_theme_constant_override("h_separation", 20)
	checks.add_theme_constant_override("v_separation", 2)
	vb.add_child(checks)
	_add_check(checks, "Полный экран", "fullscreen")
	_add_check(checks, "Зерно плёнки", "grain")
	_add_check(checks, "Тряска камеры", "shake")
	_add_check(checks, "Вспышки", "flash")
	_add_check(checks, "Субтитры", "subtitles")
	_add_check(checks, "HUD", "hud")

	var optrow := HBoxContainer.new()
	optrow.add_theme_constant_override("separation", 14)
	vb.add_child(optrow)
	optrow.add_child(_label("Качество", 16, Color(0.74, 0.72, 0.62)))
	_quality = OptionButton.new()
	_quality.add_item("Низкое")
	_quality.add_item("Среднее")
	_quality.add_item("Высокое")
	_quality.selected = clampi(int(Game.settings.get("quality", 2)), 0, 2)
	_quality.item_selected.connect(_on_quality)
	optrow.add_child(_quality)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	optrow.add_child(spacer)
	optrow.add_child(_label("Язык", 16, Color(0.74, 0.72, 0.62)))
	_lang = OptionButton.new()
	_lang.add_item("Русский")
	_lang.add_item("English")
	_lang.selected = 0 if str(Game.settings.get("lang", "ru")) == "ru" else 1
	_lang.item_selected.connect(_on_lang)
	optrow.add_child(_lang)

	var warn := _label("Клаустрофобия · вспышки · тревожные звуки", 12, Color(0.58, 0.44, 0.36))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(warn)

	var back := _button("ГОТОВО")
	back.pressed.connect(_close)
	vb.add_child(back)

func _add_slider(grid: GridContainer, text: String, key: String, minv: float, maxv: float, step: float) -> void:
	var lab := _label(text, 16, Color(0.78, 0.75, 0.65))
	grid.add_child(lab)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	grid.add_child(box)
	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.value = float(Game.settings.get(key, minv))
	slider.custom_minimum_size = Vector2(250, 22)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider.bind(key))
	box.add_child(slider)
	var val := Label.new()
	val.text = _fmt(float(Game.settings.get(key, minv)), key)
	val.custom_minimum_size = Vector2(52, 22)
	val.add_theme_font_override("font", _font)
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color(0.58, 0.68, 0.62))
	val.name = "Val_" + key
	box.add_child(val)

func _add_check(grid: GridContainer, text: String, key: String) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = bool(Game.settings.get(key, false))
	cb.add_theme_font_override("font", _font)
	cb.add_theme_font_size_override("font_size", 15)
	cb.toggled.connect(_on_check.bind(key))
	grid.add_child(cb)

func _on_slider(value: float, key: String) -> void:
	Game.set_setting(key, value)
	var val := find_child("Val_" + key, true, false) as Label
	if val != null:
		val.text = _fmt(value, key)

func _fmt(value: float, key: String) -> String:
	if key == "mouse":
		return "%.2f" % (value * 1000.0)
	return "%.0f%%" % (value * 100.0) if key in ["master", "sfx", "voice", "music"] else "%.0f" % value

func _on_check(pressed: bool, key: String) -> void:
	Game.set_setting(key, pressed)
	if key == "subtitles":
		Loc.lang = str(Game.settings.get("lang", "ru"))

func _on_quality(index: int) -> void:
	Game.set_setting("quality", index)

func _on_lang(index: int) -> void:
	Loc.set_lang("ru" if index == 0 else "en")

func _close() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.88, 0.83, 0.68))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.55))
	b.add_theme_stylebox_override("normal", _button_style(Color(0.055, 0.085, 0.082, 0.95), Color(0.22, 0.33, 0.30)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.13, 0.12, 0.98), Color(0.50, 0.42, 0.24)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.05, 0.05, 1.0), Color(0.62, 0.48, 0.24)))
	return b

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.018, 0.032, 0.034, 0.97)
	s.border_color = Color(0.28, 0.38, 0.34, 0.9)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 18
	return s

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
