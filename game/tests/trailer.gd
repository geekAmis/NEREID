extends Node
## Records the README trailer as PNG frame sequences.
##
##   godot --path game res://tests/trailer.tscn
##
## Output: _frames/menu_###.png, _frames/game_###.png, _frames/notebook_###.png
## Assemble with tools/make_trailer.py (Pillow) into docs/media/nereid.gif.

const OUT_DIR := "D:/Iron_Lung_parody/_frames"
const MENU_FRAMES := 45
const GAME_FRAMES := 120
const NOTEBOOK_FRAMES := 24

var _game: Node = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _capture_menu()
	await _capture_game()
	print("[TRAILER] done")
	get_tree().quit(0)

func _capture_menu() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(2.2).timeout
	for i in MENU_FRAMES:
		await _snap("%s/menu_%03d.png" % [OUT_DIR, i])
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_game() -> void:
	var packed := load("res://scenes/game/Game.tscn") as PackedScene
	_game = packed.instantiate()
	add_child(_game)
	await get_tree().create_timer(12.6).timeout

	var cam := Camera3D.new()
	cam.name = "TrailerCamera"
	cam.fov = 68.0
	cam.near = 0.01
	cam.far = 240.0
	cam.current = true
	add_child(cam)

	for i in GAME_FRAMES:
		var t := float(i) / float(GAME_FRAMES - 1)
		var ease_t := smoothstep(0.0, 1.0, t)
		cam.position = Vector3(
			sin(t * 2.4) * 0.035,
			lerpf(0.36, 0.02, ease_t) + sin(t * 5.2) * 0.006,
			lerpf(0.44, 1.16, ease_t)
		)
		cam.rotation_degrees = Vector3(
			lerpf(-1.5, -6.0, ease_t),
			lerpf(1.5, -2.0, ease_t) + sin(t * 3.1) * 1.4,
			0.0
		)
		await _snap("%s/game_%03d.png" % [OUT_DIR, i])

	var hud = _game.get("hud")
	if hud != null:
		hud.open_notebook()
		await get_tree().create_timer(0.7).timeout
		for i in NOTEBOOK_FRAMES:
			await _snap("%s/notebook_%03d.png" % [OUT_DIR, i])

func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.save_png(path)
	await get_tree().process_frame
	await get_tree().process_frame
