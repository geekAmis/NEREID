extends Node3D
## Главное меню: живая 3D-кабина за стеклом, минимум UI, настройки и титры.

const FONT_REG := "res://assets/fonts/PT_Sans-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/PT_Sans-Bold.ttf"
const FONT_MONO := "res://assets/fonts/JetBrainsMono.ttf"
const FONT_HAND := "res://assets/fonts/Caveat.ttf"

const C_BONE := Color(0.87, 0.83, 0.69)
const C_DIM := Color(0.52, 0.60, 0.55)
const C_GREEN := Color(0.55, 0.90, 0.68)
const C_AMBER := Color(0.95, 0.68, 0.32)
const C_RED := Color(0.88, 0.34, 0.24)

var demo_sim: CapsuleSim
var cabin: CabinBuilder
var world: WorldBuilder
var camera: Camera3D
var post: PostProcess
var ui: CanvasLayer
var settings: SettingsPanel
var credits: Control
var _click_player: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _fade: ColorRect
var _time := 0.0
var _starting := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_environment()
	demo_sim = CapsuleSim.new()
	demo_sim.time = 214.0
	cabin = CabinBuilder.new()
	cabin.name = "MenuCabin"
	add_child(cabin)
	cabin.setup(demo_sim, false)
	world = WorldBuilder.new()
	world.name = "MenuWorld"
	add_child(world)
	world.setup(demo_sim)
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = 62.0
	camera.near = 0.02
	camera.far = 240.0
	camera.position = Vector3(0.0, -0.075, 0.56)
	camera.rotation_degrees = Vector3(7.5, 0.0, 0.0)
	camera.current = true
	add_child(camera)
	post = PostProcess.new()
	post.name = "MenuPost"
	add_child(post)
	_build_audio()
	_build_ui()
	_build_fade()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.018, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.32, 0.33)
	env.ambient_light_energy = 0.20
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.72
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.085, 0.10)
	env.fog_density = 0.011
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.22, 0.38, 0.40)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.36, 0.58, 0.70)
	sun.light_energy = 0.26
	sun.rotation_degrees = Vector3(-62.0, 24.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

func _build_audio() -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.bus = "UI"
	_click_player.stream = Synth.get_stream("click")
	_click_player.volume_db = -10.0
	add_child(_click_player)
	_hum = AudioStreamPlayer.new()
	_hum.bus = "SFX"
	_hum.stream = Synth.get_stream("hum")
	_hum.volume_db = -25.0
	add_child(_hum)
	_hum.play()

func _process(delta: float) -> void:
	_time += delta
	if camera != null:
		camera.rotation_degrees.x = 7.5 + sin(_time * 0.11) * 0.9
		camera.rotation_degrees.y = sin(_time * 0.13) * 1.7
		camera.position.y = -0.075 + sin(_time * 0.27) * 0.006
		camera.position.x = sin(_time * 0.19) * 0.012

func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.006, 0.008, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 1.8)
	await tw.finished
	if is_instance_valid(_fade):
		_fade.visible = false

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "MenuUI"
	ui.layer = 10
	add_child(ui)

	var theme := Theme.new()
	var font := load(FONT_REG) as Font
	if font == null:
		font = ThemeDB.fallback_font
	theme.default_font = font
	theme.default_font_size = 16

	var root := Control.new()
	root.name = "Root"
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	# Мягкий градиент слева, чтобы текст читался поверх 3D.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.004, 0.014, 0.018, 0.94))
	grad.set_color(1, Color(0.004, 0.014, 0.018, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 8
	var veil := TextureRect.new()
	veil.texture = gt
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.anchor_left = 0.0
	veil.anchor_top = 0.0
	veil.anchor_right = 0.62
	veil.anchor_bottom = 1.0
	root.add_child(veil)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.position = Vector2(108.0, 0.0)
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_top = 92.0
	col.offset_bottom = -54.0
	col.custom_minimum_size = Vector2(460.0, 0.0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	var inst := _label("ИНСТИТУТ ПРИКЛАДНОЙ АКУСТИКИ · 1979", 12, C_DIM, true)
	col.add_child(inst)
	var title := _label("НЕРЕИДА", 78, C_BONE, false, true)
	col.add_child(title)
	var sub := _label("ПОСЛЕДНИЙ СЕАНС", 18, C_GREEN, true)
	col.add_child(sub)
	var gap1 := Control.new()
	gap1.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap1)
	var tag := _label(Loc.t("menu_tagline"), 30, C_AMBER, false, false, true)
	col.add_child(tag)
	var desc := _label("Клаустрофобный подводный immersive sim.\nОдна кабина. Сорок два метра. Один сигнал.", 14, Color(0.62, 0.68, 0.62))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(410, 0)
	col.add_child(desc)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 22)
	col.add_child(gap2)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 7)
	buttons.custom_minimum_size = Vector2(330, 0)
	col.add_child(buttons)

	var new_btn := _button(Loc.t("menu_new"))
	new_btn.pressed.connect(_on_new)
	buttons.add_child(new_btn)

	var cont := _button(Loc.t("menu_continue"))
	cont.disabled = not Save.has_save()
	if cont.disabled:
		cont.tooltip_text = "Нет сохранённой смены"
	cont.pressed.connect(_on_continue)
	buttons.add_child(cont)

	var setb := _button(Loc.t("menu_settings"))
	setb.pressed.connect(_open_settings)
	buttons.add_child(setb)

	var cred := _button(Loc.t("menu_credits"))
	cred.pressed.connect(_open_credits)
	buttons.add_child(cred)

	var quit := _button(Loc.t("menu_quit"))
	quit.pressed.connect(_on_quit)
	buttons.add_child(quit)

	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 16)
	col.add_child(gap3)
	var controls := _label(Loc.t("menu_controls"), 11, Color(0.44, 0.52, 0.48))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size = Vector2(430, 0)
	col.add_child(controls)
	var warn := _label(Loc.t("menu_warning"), 11, Color(0.66, 0.42, 0.32))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.custom_minimum_size = Vector2(410, 0)
	col.add_child(warn)

	# Язык и версия.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -420.0
	top.offset_right = -34.0
	top.offset_top = 30.0
	top.offset_bottom = 66.0
	top.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(top)
	var langb := _mini_button("EN" if Loc.lang == "ru" else "RU")
	langb.pressed.connect(_toggle_lang)
	top.add_child(langb)
	var ver := _label("v0.1.0 · VERTICAL SLICE", 11, Color(0.40, 0.48, 0.45), true)
	top.add_child(ver)

	var foot := _label("NEREID · GODOT 4.7.2 · ПРОЦЕДУРНЫЙ ЗВУК · 2026", 10, Color(0.30, 0.36, 0.34), true)
	foot.anchor_left = 1.0
	foot.anchor_top = 1.0
	foot.anchor_right = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = -430.0
	foot.offset_right = -34.0
	foot.offset_top = -46.0
	foot.offset_bottom = -24.0
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(foot)

	settings = SettingsPanel.new()
	ui.add_child(settings)
	settings.closed.connect(_on_settings_closed)

	_build_credits(root)

func _build_credits(root: Control) -> void:
	credits = Control.new()
	credits.name = "Credits"
	credits.visible = false
	credits.mouse_filter = Control.MOUSE_FILTER_STOP
	credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(credits)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.008, 0.010, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 620)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var t := _label("ТИТРЫ", 34, C_BONE, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var rule := HSeparator.new()
	vb.add_child(rule)
	var body := _label(
		"НЕРЕИДА: ПОСЛЕДНИЙ СЕАНС\n\n" +
		"Оригинальная игра. Вдохновлена клаустрофобией, гидроакустикой\n" +
		"и привычкой слышать в тишине то, чего там нет.\n\n" +
		"ДВИЖОК\nGodot 4.7.2 · Forward+\n\n" +
		"ГРАФИКА\nПроцедурная геометрия кабины · PBR-материалы ambientCG (CC0)\nШрифты PT Sans, JetBrains Mono, Caveat (OFL)\n\n" +
		"ЗВУК\nПолностью процедурный синтез (Synth.gd)\nГолоса — Microsoft SAPI Irina, ru-RU (локально)\n\n" +
		"КОД И ДИЗАЙН\ngeekAmis · 2026\n\n" +
		"Спасибо всем, кто слушал.",
		15, Color(0.74, 0.72, 0.62)
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	var back := _button(Loc.t("back"))
	back.pressed.connect(_close_credits)
	vb.add_child(back)

func _open_settings() -> void:
	_click()
	_close_credits()
	settings.open()

func _on_settings_closed() -> void:
	pass

func _open_credits() -> void:
	_click()
	credits.visible = true
	credits.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(credits, "modulate:a", 1.0, 0.25)

func _close_credits() -> void:
	if credits != null:
		credits.visible = false

func _toggle_lang() -> void:
	_click()
	Loc.set_lang("en" if Loc.lang == "ru" else "ru")
	_rebuild_ui()

func _rebuild_ui() -> void:
	if ui != null:
		ui.queue_free()
		settings = null
		credits = null
		_fade = null
	_build_ui()
	_build_fade()

func _on_new() -> void:
	_click()
	_start(false)

func _on_continue() -> void:
	_click()
	_start(true)

func _on_quit() -> void:
	_click()
	Game.quit_game()

func _start(continue_shift: bool) -> void:
	if _starting:
		return
	_starting = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.65)
	await tw.finished
	if continue_shift:
		Game.continue_game()
	else:
		Game.start_new_game()

func _click() -> void:
	if _click_player != null:
		_click_player.play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and credits != null and credits.visible:
		_close_credits()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Виджеты
# ---------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, mono: bool = false, bold: bool = false, hand: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var path := FONT_MONO if mono else (FONT_HAND if hand else (FONT_BOLD if bold else FONT_REG))
	var f := load(path) as Font
	if f == null:
		f = ThemeDB.fallback_font
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 45)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", load(FONT_BOLD) as Font)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.86, 0.82, 0.68))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.55))
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.42, 0.38))
	b.add_theme_stylebox_override("normal", _button_style(Color(0.05, 0.08, 0.078, 0.82), Color(0.20, 0.30, 0.28)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.09, 0.15, 0.14, 0.96), Color(0.55, 0.45, 0.24)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.05, 0.05, 1.0), Color(0.64, 0.50, 0.25)))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0.03, 0.04, 0.04, 0.55), Color(0.14, 0.18, 0.17)))
	return b

func _mini_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(46, 28)
	b.add_theme_font_override("font", load(FONT_MONO) as Font)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(0.70, 0.74, 0.64))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.55))
	b.add_theme_stylebox_override("normal", _button_style(Color(0.05, 0.08, 0.078, 0.7), Color(0.22, 0.30, 0.27)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.09, 0.14, 0.13, 0.95), Color(0.50, 0.42, 0.24)))
	return b

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.014, 0.026, 0.028, 0.985)
	s.border_color = Color(0.30, 0.40, 0.35, 0.9)
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 22
	return s
