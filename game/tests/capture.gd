extends Node
## Screenshot harness for manual/automated visual review.
##
## Run (windowed, not headless):
##   godot --path game res://tests/capture.tscn -- <scene> <out.png> <wait_frames>
##
## Example:
##   godot --path game res://tests/capture.tscn -- res://scenes/Main.tscn D:/shots/menu.png 150

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := "res://scenes/Main.tscn"
	var out_path := "res://_shot.png"
	var wait_frames := 120
	if args.size() > 0:
		scene_path = args[0]
	if args.size() > 1:
		out_path = args[1]
	if args.size() > 2:
		wait_frames = int(args[2])

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("[CAPTURE] cannot load %s" % scene_path)
		get_tree().quit(2)
		return
	add_child(packed.instantiate())
	var instance := get_child(get_child_count() - 1)
	if args.size() > 4 and args[3] != "":
		var p := args[3].split(",")
		var r := args[4].split(",")
		if p.size() == 3 and r.size() == 2:
			var cam := Camera3D.new()
			cam.name = "DebugCaptureCamera"
			cam.fov = float(args[5]) if args.size() > 5 else 70.0
			cam.near = 0.01
			cam.far = 400.0
			cam.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
			cam.rotation_degrees = Vector3(float(r[0]), float(r[1]), 0.0)
			cam.current = true
			add_child(cam)
	await get_tree().create_timer(maxf(0.1, float(wait_frames) / 60.0)).timeout
	if args.size() > 6 and args[6] != "":
		_apply_action(instance, args[6])
		await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[CAPTURE] empty viewport image")
		get_tree().quit(3)
		return
	var err := image.save_png(out_path)
	if err != OK:
		push_error("[CAPTURE] save_png failed: %d" % err)
		get_tree().quit(4)
		return
	print("[CAPTURE] %s -> %s (%dx%d)" % [scene_path, out_path, image.get_width(), image.get_height()])
	get_tree().quit(0)

func _apply_action(instance: Node, action: String) -> void:
	match action:
		"notebook":
			instance.get("hud").open_notebook()
		"board":
			var sim = instance.get("sim")
			if sim != null:
				sim.register_photo("bell", "D:/Iron_Lung_parody/_shots/photo_a.png", 42.0, "bell")
				sim.register_photo("tower", "D:/Iron_Lung_parody/_shots/photo_b.png", 43.0, "bell")
				sim.register_photo("door", "D:/Iron_Lung_parody/_shots/photo_c.png", 41.0, "pump")
			var dp = instance.get("developed_photos")
			if dp is Array:
				dp.append("D:/Iron_Lung_parody/_shots/photo_a.png")
				dp.append("D:/Iron_Lung_parody/_shots/photo_b.png")
				dp.append("D:/Iron_Lung_parody/_shots/photo_c.png")
			instance.get("hud").open_board()
		"camera":
			instance.get("player").enter_camera_mode()
		"pause":
			instance.get("hud").open_pause()
		"ending":
			instance.get("hud").show_ending("keep", "42 М  ·  3 СИГНАЛА  ·  12 КАДРОВ")
		"settings":
			instance.call("_open_settings")
		"credits":
			instance.call("_open_credits")
		"hidehud":
			var hud_node = instance.get("hud")
			if hud_node != null:
				hud_node.visible = false
		_:
			push_warning("[CAPTURE] unknown action: %s" % action)
