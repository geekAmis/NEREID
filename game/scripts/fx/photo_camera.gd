class_name PhotoCamera
extends Node
## Захват кадра: вспышка, слой аномалий, PNG в user://photos, проявка.
## Определение цели — по углу между взглядом и позицией аномалии.

signal photo_taken(path: String, target_id: String)

var hud = null
var post = null
var anomalies: Array[Dictionary] = []
var dev_time := 20.0
var _busy := false

func setup(p_hud, p_post, list: Array[Dictionary]) -> void:
	hud = p_hud
	post = p_post
	anomalies = list

func capture(player: Player, sim) -> void:
	if _busy or player == null or sim == null:
		return
	_busy = true
	var target := _detect_target(player, sim)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.92, 0.97, 1.0)
	flash.light_energy = 16.0
	flash.omni_range = 42.0
	flash.shadow_enabled = false
	player.camera.add_child(flash)
	flash.global_position = player.camera.global_position
	var old_mask := player.camera.cull_mask
	player.camera.cull_mask = old_mask | 2
	var hud_was := false
	var post_was := false
	if hud != null and hud is CanvasLayer:
		hud_was = (hud as CanvasLayer).visible
		(hud as CanvasLayer).visible = false
	if post != null and post is CanvasLayer:
		post_was = (post as CanvasLayer).visible
		(post as CanvasLayer).visible = false
	if Game.settings.get("flash", true) and post != null:
		post.pulse_flash(0.55, 0.22)
	await get_tree().create_timer(0.055).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = null
	if player.get_viewport() != null:
		img = player.get_viewport().get_texture().get_image()
	player.camera.cull_mask = old_mask
	if is_instance_valid(flash):
		flash.queue_free()
	if hud != null and hud is CanvasLayer:
		(hud as CanvasLayer).visible = hud_was
	if post != null and post is CanvasLayer:
		(post as CanvasLayer).visible = post_was
	if img == null:
		_busy = false
		Game.toast("Снимок не проявился.")
		return
	var index := Save.next_photo_index()
	var path := Save.photo_path(index)
	var abs_path := ProjectSettings.globalize_path(path)
	var err := img.save_png(abs_path)
	if err != OK:
		_busy = false
		Game.toast("Ошибка записи снимка.")
		return
	sim.register_photo(target, path, sim.depth, sim.current_signal)
	photo_taken.emit(path, target)
	Game.toast("КАДР %02d · %s" % [index, "цель: " + _target_name(target) if target != "" else "пустой кадр"])
	if Game.audio != null:
		Game.audio.play_ui("shutter")
		Game.audio.play_sfx("shutter", player.camera.global_position, -6.0)
	# Перезарядка и лёгкий звон плёнки.
	await get_tree().create_timer(0.9).timeout
	_busy = false

func _detect_target(player: Player, sim) -> String:
	var origin := player.camera.global_position
	var forward := player.look_direction().normalized()
	var best := ""
	var best_angle := deg_to_rad(10.5)
	for a in anomalies:
		var pos_arr: Array = a.get("position", [])
		if pos_arr.size() != 3:
			continue
		var p := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		var to := p - origin
		var dist := to.length()
		if dist < 0.5 or dist > 38.0:
			continue
		var ang := forward.angle_to(to.normalized())
		if ang < best_angle:
			best_angle = ang
			best = str(a.get("id", ""))
	# Дополнительно: колокол виден и без точного угла, если игрок смотрит в его сторону.
	if best == "" and sim.current_signal == "bell":
		for a in anomalies:
			if str(a.get("id", "")) != "bell":
				continue
			var pa: Array = a.get("position", [])
			if pa.size() == 3:
				var pb := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
				if forward.angle_to((pb - origin).normalized()) < deg_to_rad(18.0):
					best = "bell"
	return best

func _target_name(id: String) -> String:
	match id:
		"bell":
			return "колокольня"
		"dome":
			return "купол"
		"window":
			return "окно"
		"figure":
			return "силуэт"
		"cables":
			return "кабели"
		"door":
			return "дверь"
		"hand":
			return "рука"
		"choir":
			return "хор"
	return "аномалия"
