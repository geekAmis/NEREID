extends SceneTree
## NEREID — headless test suite for the deterministic core.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path game \
##       --script res://tests/run_tests.gd
##
## Exit code 0 = all checks passed, 1 = failures.
## The suite never requires a renderer, audio device or scene tree beyond `root`.

var checks := 0
var failures := 0
var _current := ""

func _initialize() -> void:
	print("")
	print("NEREID core tests")
	print("=================")
	_test_sim_initial_state()
	_test_fixed_tick()
	_test_leak_and_pump()
	_test_air_and_scrubber()
	_test_failure_endings()
	_test_cable_endings()
	_test_signal_identification()
	_test_photo_accounting()
	_test_director_acts()
	_test_director_serialization()
	_test_listener_states()
	_test_listener_strike()
	_test_listener_serialization()
	_test_save_round_trip()
	_test_full_shift_survival()
	print("")
	if failures == 0:
		print("PASS: %d checks" % checks)
	else:
		print("FAIL: %d of %d checks failed" % [failures, checks])
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _section(name: String) -> void:
	_current = name
	print("")
	print("[%s]" % name)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps

func _sim(seed_value: int = 19690427) -> CapsuleSim:
	return CapsuleSim.new(seed_value)

## advance() clamps a single call to 20 fixed steps (2 s). Tests that need
## longer stretches must feed the sim in small chunks, like the real game loop.
func _run(s: CapsuleSim, seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(0.5, left)
		s.advance(dt)
		left -= dt

# ---------------------------------------------------------------------------
# CapsuleSim
# ---------------------------------------------------------------------------

func _test_sim_initial_state() -> void:
	_section("sim/initial")
	var s := _sim()
	_check(_approx(s.depth, 42.0), "starts at 42 m")
	_check(_approx(s.water_liters, 18.0), "starts with 18 L in the bilge")
	_check(_approx(s.battery_kwh, 0.9), "battery starts full")
	_check(s.act == 1, "act 1")
	_check(not s.game_over, "not game over")
	_check(s.film == 12, "12 film frames")
	_check(s.spare_canisters == 2, "2 spare scrubber canisters")
	_check(s.switches.size() == 6, "6 switches")
	_check(s.noise_history.size() == 300, "noise history is 30 s at 10 Hz")

func _test_fixed_tick() -> void:
	_section("sim/tick")
	var s := _sim()
	s.advance(1.0)
	_check(_approx(s.time, 1.0, 0.011), "advance(1.0) advances ~1 s (got %.3f)" % s.time)
	var before := s.time
	s.advance(0.05)
	_check(_approx(s.time, before, 0.011), "sub-tick delta is accumulated, not lost")
	s.advance(0.05)
	_check(_approx(s.time, before + 0.1, 0.011), "two 0.05 s calls produce one 0.1 s step")
	# A single huge frame must stay bounded (guard of 20 steps).
	var snapshot := s.time
	s.advance(1000.0)
	_check(s.time - snapshot <= 2.05, "long frame is clamped to the step guard")

func _test_leak_and_pump() -> void:
	_section("sim/water")
	var s := _sim()
	var start := s.water_liters
	_run(s, 30.0)
	_check(s.water_liters > start, "unpatched leak raises water")
	var wet := s.water_liters
	s.set_switch("pump", true)
	_run(s, 30.0)
	_check(s.water_liters < wet, "electric pump lowers water")
	_check(s.water_cm > 0.0, "water depth is derived in cm")

	var p := _sim()
	p.patch_leak()
	_check(p.leak_patched, "leak can be patched")
	_check(_approx(p.leak_rate, 4.0), "patched leak drops to 4 L/min")
	var w := p.water_liters
	_run(p, 30.0)
	_check(p.water_liters - w < 4.0, "patched leak is slow")

func _test_air_and_scrubber() -> void:
	_section("sim/air")
	var s := _sim()
	var co2 := s.co2
	_run(s, 60.0)
	_check(s.co2 < co2, "scrubber lowers CO2 while life support runs")
	_check(s.scrubber < 1.0, "scrubber is consumed")

	var bad := _sim()
	bad.switches.life_support = false
	var before := bad.co2
	_run(bad, 60.0)
	_check(bad.co2 > before, "CO2 rises without life support")

	bad.co2 = 3.0
	bad.scrubber = 0.0
	bad.scrubber_installed = false
	var spares := bad.spare_canisters
	_check(bad.replace_scrubber(), "replace_scrubber succeeds with a spare")
	_check(bad.spare_canisters == spares - 1, "spare canister is consumed")
	_check(_approx(bad.scrubber, 1.0), "scrubber restored to 100%")
	_check(bad.co2 < 3.0, "replacement immediately drops CO2")

func _test_failure_endings() -> void:
	_section("sim/endings")
	var s := _sim()
	s.co2 = 6.0
	s.step(0.1)
	_check(s.game_over and s.ending_id == "asphyxia", "CO2 over 5.2 kills -> asphyxia")

	var o := _sim()
	o.o2 = 10.0
	o.step(0.1)
	_check(o.game_over and o.ending_id == "hypoxia", "O2 below 11 -> hypoxia")

	var h := _sim()
	h.hull = 0.0
	h.step(0.1)
	_check(h.game_over and h.ending_id == "implosion", "hull at 0 -> implosion")

	var w := _sim()
	w.water_liters = 24.0 * w.BILGE_AREA_M2 * 10.0
	w.step(0.1)
	_check(w.game_over and w.ending_id == "flood", "24 cm of water -> flood")

	var b := _sim()
	b.battery_kwh = 0.0
	b.co2 = 4.5
	b.step(0.1)
	_check(b.game_over and b.ending_id == "dark", "dead battery with high CO2 -> dark")

func _test_cable_endings() -> void:
	_section("sim/cable")
	var s := _sim()
	s.jettison_ballast()
	s.cut_cable()
	_check(s.game_over and s.ending_id == "surface", "ballast + cut -> surface")

	var c := _sim()
	c.cut_cable()
	_check(not c.game_over, "cut without ballast does not end instantly")
	_run(c, 10.0)
	_check(c.game_over and c.ending_id == "cable", "cut without ballast -> cable after sinking")

	var d := _sim()
	d.set_target_depth(50.0)
	_check(d.winch_moving, "winch accepts a new target")
	_run(d, 2.0)
	_check(d.depth < 50.0, "winch moves depth toward target")

func _test_signal_identification() -> void:
	_section("sim/signals")
	var s := _sim()
	s.set_signal("pump", 0.8, 12.0)
	_check(s.current_signal == "pump", "signal can be set")
	_check(s.identify("pump"), "matching identification succeeds")
	_check("pump" in s.identified, "identified list is updated")
	_check(not s.identify("groan"), "wrong identification fails")
	_check(s.identify("") == false, "empty id is rejected")
	_check(s.identify("nonsense") == false, "unknown id is rejected")

	for id in ["groan", "bell"]:
		s.set_signal(id, 1.0, 10.0)
		s.identify(id)
	_check(bool(s.tasks.identify3), "3 identifications complete the task")
	_check(bool(s.tasks.bell_log), "identifying the bell logs it")

	s.set_bell_trim(47.0)
	_check(bool(s.tasks.secret_bell), "47.0 Hz trim opens the secret")

func _test_photo_accounting() -> void:
	_section("sim/photos")
	var s := _sim()
	_check(s.can_photo(), "camera is ready")
	s.register_photo("bell", "user://photos/photo_001.png", 42.0, "bell")
	_check(s.film == 11, "film decrements")
	_check(s.photo_count() == 1, "photo is stored")
	_check(s.has_photo("bell"), "photo lookup by target")
	_check(bool(s.tasks.photo3) == false, "one photo is not the task")

	s.register_photo("tower", "user://photos/photo_002.png", 42.0, "bell")
	s.register_photo("door", "user://photos/photo_003.png", 42.0, "pump")
	_check(bool(s.tasks.photo3), "3 photos complete the task")
	_check(bool(s.tasks.photo_bell), "bell photo task completes")
	s.film = 0
	s.register_photo("x", "user://photos/photo_004.png", 42.0, "")
	_check(s.photo_count() == 3, "empty film rejects new photos")

# ---------------------------------------------------------------------------
# SilenceDirector
# ---------------------------------------------------------------------------

func _make_director() -> Array:
	var s := _sim()
	var l := ListenerAI.new(4711)
	var d := SilenceDirector.new(4701)
	d.bind(s, l)
	return [s, l, d]

func _test_director_acts() -> void:
	_section("director/acts")
	var trio := _make_director()
	var s: CapsuleSim = trio[0]
	var d: SilenceDirector = trio[2]

	s.time = SilenceDirector.ACT1_END
	d.tick(0.1)
	_check(d.act == 2, "act 2 begins at 300 s")
	_check(s.act == 2, "sim act mirrors director")
	_check(s.power_cable_failed, "act 2 cuts surface power")

	s.time = SilenceDirector.ACT2_END
	d.tick(0.1)
	_check(d.act == 3, "act 3 begins at 840 s")
	_check(s.current_signal == "bell", "act 3 puts the bell on the hydrophone")

	s.time = 860.0
	d.tick(0.1)
	_check(d.final_available, "final becomes available at 860 s")

func _test_director_serialization() -> void:
	_section("director/serialize")
	var trio := _make_director()
	var d: SilenceDirector = trio[2]
	d.final_available = true
	d.act = 3
	d.tension = 0.77
	d.next_signal_gap = 31.5
	d.flags["brief"] = true

	var copy := SilenceDirector.new()
	copy.deserialize(d.serialize())
	_check(copy.final_available, "final flag survives")
	_check(copy.act == 3, "act survives")
	_check(_approx(copy.tension, 0.77), "tension survives")
	_check(_approx(copy.next_signal_gap, 31.5), "signal gap survives")
	_check(bool(copy.flags.get("brief", false)), "flags survive")

# ---------------------------------------------------------------------------
# ListenerAI
# ---------------------------------------------------------------------------

func _test_listener_states() -> void:
	_section("listener/states")
	var trio := _make_director()
	var s: CapsuleSim = trio[0]
	var l: ListenerAI = trio[1]
	_check(l.nodes.size() == 9, "attention graph has 9 nodes")
	_check(l.state == "dormant", "starts dormant")

	l.force_curious()
	_check(l.state == "curious", "force_curious enters curious")
	l.force_approach()
	_check(l.state == "approach", "force_approach enters approach")
	_check(l.attention >= 60.0, "approach raises attention")

	l.distract()
	_check(l.state == "curious", "distract drops to curious")
	_check(l.attention < 60.0, "distract lowers attention")

	var a := l.attention
	s.noise_level = 95.0
	s.ping_flash = 1.0
	l.tick(1.0, s)
	_check(l.attention > a, "noise and ping raise attention")

func _test_listener_strike() -> void:
	_section("listener/strike")
	var trio := _make_director()
	var s: CapsuleSim = trio[0]
	var l: ListenerAI = trio[1]
	var hull := s.hull
	var state_changes: Array[String] = []
	l.state_changed.connect(func(st: String) -> void: state_changes.append(st))

	l.state = "circle"
	l.attention = 80.0
	l._state_time = 5.0
	l.tick(0.1, s)
	_check(l.state == "strike", "high attention in circle enters strike")
	for i in 36:
		l.tick(0.1, s)
	_check(s.hull < hull, "strike damages the hull")
	_check(l.state == "retreat", "strike retreats afterwards")
	_check(l.cooldown > 0.0, "strike sets a cooldown")
	_check(not state_changes.is_empty(), "state_changed fires")

	# Heavy listener load must eventually snap the cable.
	var s2 := _sim()
	s2.set_listener_load(2.5)
	_run(s2, 9.0)
	_check(s2.cable_snapped and s2.cable_cut, "sustained load snaps the cable")

func _test_listener_serialization() -> void:
	_section("listener/serialize")
	var l := ListenerAI.new(4711)
	l.state = "approach"
	l.attention = 55.5
	l.cooldown = 4.0
	l.position = Vector3(1.0, 2.0, 3.0)
	var copy := ListenerAI.new(4711)
	copy.deserialize(l.serialize())
	_check(copy.state == "approach", "state survives")
	_check(_approx(copy.attention, 55.5), "attention survives")
	_check(_approx(copy.cooldown, 4.0), "cooldown survives")
	_check(copy.position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), "position survives")

# ---------------------------------------------------------------------------
# SaveSystem
# ---------------------------------------------------------------------------

func _test_save_round_trip() -> void:
	_section("save/round-trip")
	var save_script: GDScript = load("res://scripts/core/save_system.gd")
	var save: Node = save_script.new()
	root.add_child(save)
	var save_path: String = save.SAVE_PATH

	var backup := ""
	var had_backup := FileAccess.file_exists(save_path)
	if had_backup:
		var bf := FileAccess.open(save_path, FileAccess.READ)
		if bf != null:
			backup = bf.get_as_text()
			bf.close()

	var sim := _sim(4242)
	sim.time = 123.4
	sim.water_liters = 44.0
	sim.identified.append("pump")
	sim.tasks.identify3 = true
	sim.register_photo("bell", "user://photos/photo_009.png", 43.0, "bell")

	var director := SilenceDirector.new(4701)
	director.final_available = true
	director.flags["final"] = true

	var listener := ListenerAI.new(4711)
	listener.state = "curious"
	listener.attention = 33.0

	var payload := {
		"sim": sim.serialize(),
		"director": director.serialize(),
		"listener": listener.serialize(),
	}
	_check(save.save_game(payload), "save_game writes a file")
	_check(save.has_save(), "has_save sees the file")
	var loaded: Dictionary = save.load_game()
	_check(not loaded.is_empty(), "load_game returns a payload")

	var sim2 := _sim()
	sim2.deserialize(loaded.get("sim", {}))
	_check(_approx(sim2.time, 123.4), "sim time round-trips")
	_check(_approx(sim2.water_liters, 44.0), "water round-trips")
	_check("pump" in sim2.identified, "identified list round-trips")
	_check(bool(sim2.tasks.identify3), "tasks round-trip")
	_check(sim2.photo_count() == 1 and sim2.has_photo("bell"), "photos round-trip")
	_check(sim2.film == 11, "film count round-trips")

	var dir2 := SilenceDirector.new()
	dir2.deserialize(loaded.get("director", {}))
	_check(dir2.final_available, "director final round-trips")

	var lis2 := ListenerAI.new()
	lis2.deserialize(loaded.get("listener", {}))
	_check(lis2.state == "curious", "listener state round-trips")
	_check(_approx(lis2.attention, 33.0), "listener attention round-trips")

	_check(save.photo_path(3).ends_with("photo_003.png"), "photo path is zero-padded")

	# Restore the previous save so tests never destroy real progress.
	if had_backup:
		var wf := FileAccess.open(save_path, FileAccess.WRITE)
		if wf != null:
			wf.store_string(backup)
			wf.close()
	else:
		save.delete_save()

	save.queue_free()

# ---------------------------------------------------------------------------
# Balance: a competent but not perfect player must survive a full shift.
# ---------------------------------------------------------------------------

func _test_full_shift_survival() -> void:
	_section("balance/full-shift")
	var s := _sim()
	var dir := SilenceDirector.new()
	var lis := ListenerAI.new()
	dir.bind(s, lis)
	var t := 0.0
	var patched := false
	var pump_on := false
	var max_co2 := 0.0
	var max_water := 0.0
	while t < 1200.0 and not s.game_over:
		s.advance(0.5)
		t += 0.5
		dir.tick(0.5)
		lis.tick(0.5, s)
		if not patched and s.time >= 40.0:
			s.patch_leak()
			patched = true
		if s.scrubber < 0.12 and s.spare_canisters > 0:
			s.replace_scrubber()
		if not pump_on and s.water_cm > 6.0:
			s.set_switch("pump", true)
			pump_on = true
		elif pump_on and s.water_cm < 2.0:
			s.set_switch("pump", false)
			pump_on = false
		max_co2 = maxf(max_co2, s.co2)
		max_water = maxf(max_water, s.water_cm)
	_check(not s.game_over, "no scripted death in the first 20 minutes (ended: %s at %.0f s)" % [s.ending_id, s.time])
	_check(dir.final_available, "final becomes available by 860 s")
	_check(s.time >= 1199.0, "simulation reaches 1200 s (got %.0f)" % s.time)
	_check(max_co2 < 5.2, "CO2 stays below the lethal threshold (max %.2f)" % max_co2)
	_check(max_water < 24.0, "water stays below the flood threshold (max %.1f cm)" % max_water)
	_check(s.hull > 0.0, "hull survives the shift (%.0f%%)" % s.hull)
