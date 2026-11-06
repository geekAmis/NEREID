extends Node
## Глобальное состояние: настройки, ввод, переключение сцен, доступ к текущей
## симуляции. Автолоад. Не хранит состояние сессии — только приложение.

signal settings_changed

const MAIN_SCENE := "res://scenes/Main.tscn"
const GAME_SCENE := "res://scenes/game/Game.tscn"

const DEFAULT_SETTINGS := {
	"master": 0.9,
	"sfx": 0.95,
	"voice": 1.0,
	"music": 0.6,
	"mouse": 0.0022,
	"invert_y": false,
	"fov": 65.0,
	"fullscreen": false,
	"grain": true,
	"shake": true,
	"flash": true,
	"subtitles": true,
	"quality": 2,
	"lang": "ru",
	"hud": true,
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var current_game: Node = null
var sim = null
var audio = null
var continue_requested := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_merge_settings(Save.load_settings())
	Loc.lang = str(settings.get("lang", "ru"))
	_setup_input()
	apply_settings()
	print("[NEREID] boot ok · godot %s · quality %d" % [Engine.get_version_info().string, int(settings.quality)])

func _merge_settings(loaded: Dictionary) -> void:
	for key in loaded.keys():
		if DEFAULT_SETTINGS.has(key):
			settings[key] = loaded[key]

func _setup_input() -> void:
	_add_action("move_forward", KEY_W)
	_add_action("move_back", KEY_S)
	_add_action("move_left", KEY_A)
	_add_action("move_right", KEY_D)
	_add_action("interact", KEY_E)
	_add_action("flashlight", KEY_F)
	_add_action("notebook", KEY_TAB)
	_add_action("pause", KEY_ESCAPE)
	_add_action("hide_hud", KEY_H)
	_add_action("subtitles", KEY_C)
	_add_action("exit_camera", KEY_Q)
	_add_action("zoom", KEY_Z)
	_add_action("shutter", KEY_SPACE)
	_add_action("crank", KEY_R)
	_add_action("crouch", KEY_CTRL)

func _add_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var exists := false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
			exists = true
			break
	if exists:
		return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func apply_settings() -> void:
	_apply_bus("Master", float(settings.master))
	_apply_bus("SFX", float(settings.sfx))
	_apply_bus("Voice", float(settings.voice))
	_apply_bus("Music", float(settings.music))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	settings_changed.emit()

func _apply_bus(name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, -80.0 if linear <= 0.001 else linear_to_db(linear))

func save_settings() -> void:
	Save.save_settings(settings)

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	settings[key] = value
	save_settings()
	apply_settings()

func t(key: String) -> String:
	return Loc.t(key)

func start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func start_new_game() -> void:
	Save.delete_save()
	continue_requested = false
	start_game()

func continue_game() -> void:
	continue_requested = true
	start_game()

func goto_menu() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func quit_game() -> void:
	save_settings()
	get_tree().quit()

func register_game(node: Node) -> void:
	current_game = node

func unregister_game(node: Node) -> void:
	if current_game == node:
		current_game = null
		sim = null
		audio = null

func is_in_game() -> bool:
	return is_instance_valid(current_game)

func add_noise(db: float, position: Vector3 = Vector3.ZERO, duration: float = 0.0) -> void:
	if is_instance_valid(sim):
		sim.add_noise(db, position, duration)

func subtitle(text: String, duration: float = 4.0) -> void:
	if is_instance_valid(current_game) and current_game.has_method("show_subtitle"):
		current_game.show_subtitle(text, duration)

func toast(text: String, duration: float = 3.0) -> void:
	if is_instance_valid(current_game) and current_game.has_method("show_toast"):
		current_game.show_toast(text, duration)

func quality_level() -> int:
	return int(settings.get("quality", 2))
