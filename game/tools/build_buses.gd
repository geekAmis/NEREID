extends SceneTree
## Генерирует res://default_bus_layout.tres — шины NEREID.
## Запуск: godot --headless --path game --script res://../tools/build_buses.gd
## (скрипт лежит вне game/, поэтому удобнее: --path game --script tools/build_buses.gd из корня)
## Практический запуск: см. tools/build_buses.cmd
##
## Шины:
##   Master      — лимитер
##   SFX         — небольшой объёмный хвост кабины
##   UI          — сухие щелчки
##   Hydrophone  — низкие частоты, лёгкая грязь, длинный хвост воды
##   Radio       — полосовой фильтр рации + компрессор
##   Voice       — мягкий фильтр, компрессор
##   Underwater  — глухой low-pass и большой reverb

func _init() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	AudioServer.set_bus_name(0, "Master")
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_send(0, "")

	_add_bus("SFX", -2.0, 0)
	var room := AudioEffectReverb.new()
	room.room_size = 0.42
	room.damping = 0.62
	room.wet = 0.11
	room.dry = 0.96
	room.spread = 0.7
	AudioServer.add_bus_effect(1, room)

	_add_bus("UI", 0.0, 0)

	_add_bus("Hydrophone", -1.0, 0)
	var hp_lp := AudioEffectLowPassFilter.new()
	hp_lp.cutoff_hz = 2800.0
	hp_lp.resonance = 0.35
	AudioServer.add_bus_effect(3, hp_lp)
	var hp_dist := AudioEffectDistortion.new()
	hp_dist.mode = AudioEffectDistortion.MODE_ATAN
	hp_dist.drive = 0.12
	hp_dist.post_gain = -1.5
	AudioServer.add_bus_effect(3, hp_dist)
	var hp_rev := AudioEffectReverb.new()
	hp_rev.room_size = 0.88
	hp_rev.damping = 0.35
	hp_rev.wet = 0.22
	hp_rev.dry = 0.9
	hp_rev.spread = 1.0
	AudioServer.add_bus_effect(3, hp_rev)

	_add_bus("Radio", 0.0, 0)
	var r_hp := AudioEffectHighPassFilter.new()
	r_hp.cutoff_hz = 340.0
	r_hp.resonance = 0.4
	AudioServer.add_bus_effect(4, r_hp)
	var r_lp := AudioEffectLowPassFilter.new()
	r_lp.cutoff_hz = 3600.0
	r_lp.resonance = 0.45
	AudioServer.add_bus_effect(4, r_lp)
	var r_dist := AudioEffectDistortion.new()
	r_dist.mode = AudioEffectDistortion.MODE_ATAN
	r_dist.drive = 0.22
	r_dist.post_gain = -2.0
	AudioServer.add_bus_effect(4, r_dist)
	var r_comp := AudioEffectCompressor.new()
	r_comp.threshold = -16.0
	r_comp.ratio = 4.0
	r_comp.attack_us = 6000.0
	r_comp.release_ms = 160.0
	r_comp.gain = 3.0
	AudioServer.add_bus_effect(4, r_comp)

	_add_bus("Voice", -1.0, 0)
	var v_lp := AudioEffectLowPassFilter.new()
	v_lp.cutoff_hz = 4800.0
	v_lp.resonance = 0.2
	AudioServer.add_bus_effect(5, v_lp)
	var v_comp := AudioEffectCompressor.new()
	v_comp.threshold = -18.0
	v_comp.ratio = 3.0
	v_comp.attack_us = 8000.0
	v_comp.release_ms = 180.0
	v_comp.gain = 4.0
	AudioServer.add_bus_effect(5, v_comp)

	_add_bus("Underwater", -2.0, 0)
	var uw_lp := AudioEffectLowPassFilter.new()
	uw_lp.cutoff_hz = 620.0
	uw_lp.resonance = 0.5
	AudioServer.add_bus_effect(6, uw_lp)
	var uw_rev := AudioEffectReverb.new()
	uw_rev.room_size = 0.95
	uw_rev.damping = 0.28
	uw_rev.wet = 0.45
	uw_rev.dry = 0.75
	uw_rev.spread = 1.0
	AudioServer.add_bus_effect(6, uw_rev)

	var layout := AudioServer.generate_bus_layout()
	var err := ResourceSaver.save(layout, "res://default_bus_layout.tres")
	if err == OK:
		print("[BUS] saved default_bus_layout.tres: %d buses" % AudioServer.bus_count)
	else:
		push_error("[BUS] save failed: %d" % err)
	quit(0 if err == OK else 1)

func _add_bus(bus_name: String, volume_db: float, send_to: int) -> void:
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_volume_db(idx, volume_db)
	AudioServer.set_bus_send(idx, AudioServer.get_bus_name(send_to))
