class_name Device
extends Interactable
## Универсальное устройство: тумблер, кнопка, ручка, вентиль, рукоятка,
## удержание, рычаг. Анимация — через pivot-узлы, логика — через Callable.

enum Kind { TOGGLE, BUTTON, KNOB, CRANK, VALVE, HOLD, LEVER }

var kind: Kind = Kind.TOGGLE
var value := 0.0
var min_value := 0.0
var max_value := 1.0
var step_value := 0.05
var lever_pivot: Node3D = null
var wheel_pivot: Node3D = null
var on_toggle: Callable = Callable()
var on_value: Callable = Callable()
var on_press: Callable = Callable()
var on_hold_complete: Callable = Callable()
var on_crank_tick: Callable = Callable()
var crank_direction := 1
var hold_progress := 0.0
var max_hold := 2.0
var sound_name := "click"
var sound_name_alt := "clunk"
var idle_rotation := 0.0
var lever_angle := 0.9
var _active := false
var _hold_done := false
var _crank_accum := 0.0
var _noise_accum := 0.0
var _lever_target := 0.0
var _visual_value := 0.0

func _ready() -> void:
	super._ready()

func setup_device(p_kind: Kind, p_prompt: String, size: Vector3, p_sim = null) -> void:
	kind = p_kind
	prompt = p_prompt
	_base_prompt = p_prompt
	sim = p_sim
	setup_collider(size)
	match kind:
		Kind.HOLD:
			hold_time = max_hold
		Kind.CRANK:
			noise_db = 64.0
		Kind.BUTTON:
			noise_db = 6.0
		_:
			noise_db = 8.0

func _process(delta: float) -> void:
	if lever_pivot != null:
		var target := _lever_target
		lever_pivot.rotation.x = lerpf(lever_pivot.rotation.x, target, clampf(delta * 12.0, 0.0, 1.0))
	if kind == Kind.HOLD and _active:
		var speed := 1.0
		if sim != null and sim.has_method("interaction_speed"):
			speed = sim.interaction_speed()
		hold_progress = minf(1.0, hold_progress + delta * speed / maxf(0.1, max_hold))
		if hold_progress >= 1.0 and not _hold_done:
			_hold_done = true
			_active = false
			_play("clunk")
			if on_hold_complete.is_valid():
				on_hold_complete.call()
			else:
				activated.emit()
			hold_progress = 0.0
	elif kind == Kind.HOLD and not _active:
		hold_progress = maxf(0.0, hold_progress - delta * 1.6)
	if kind == Kind.CRANK and _active:
		_crank_accum += delta
		_noise_accum += delta
		if wheel_pivot != null:
			wheel_pivot.rotate_z(delta * 4.4 * float(crank_direction))
		if _crank_accum >= 0.45:
			_crank_accum = 0.0
			if on_crank_tick.is_valid():
				on_crank_tick.call()
		if _noise_accum >= 0.5:
			_noise_accum = 0.0
			make_noise(58.0, 0.4)
	if kind == Kind.KNOB or kind == Kind.VALVE:
		if wheel_pivot != null:
			wheel_pivot.rotation.z = lerpf(wheel_pivot.rotation.z, value * TAU * 1.6, clampf(delta * 10.0, 0.0, 1.0))

func _use_start(_player) -> void:
	match kind:
		Kind.TOGGLE, Kind.LEVER:
			value = 0.0 if value > 0.5 else 1.0
			_apply_toggle()
		Kind.BUTTON:
			_press_animation()
			_play("click")
			if on_press.is_valid():
				on_press.call()
			activated.emit()
			make_noise(noise_db, 0.15)
		Kind.KNOB, Kind.VALVE:
			_active = true
		Kind.CRANK:
			_active = true
			_play("clunk")
			if sim != null and sim.has_method("set_crank"):
				sim.set_crank(true)
			make_noise(60.0, 0.5)
		Kind.HOLD:
			_active = true
			_hold_done = false
			hold_progress = 0.0
			_play("valve")

func _use_stop(_player) -> void:
	match kind:
		Kind.KNOB, Kind.VALVE:
			_active = false
		Kind.CRANK:
			_active = false
			if sim != null and sim.has_method("set_crank"):
				sim.set_crank(false)
		Kind.HOLD:
			_active = false
			if not _hold_done:
				hold_progress = 0.0

func _scroll(step: float) -> void:
	if kind != Kind.KNOB and kind != Kind.VALVE:
		return
	value = clampf(value + step * step_value, min_value, max_value)
	_notify_value()
	_play("click")

func _drag(relative: Vector2) -> void:
	if kind != Kind.KNOB and kind != Kind.VALVE:
		return
	if not _active:
		return
	var speed := 0.004 if kind == Kind.VALVE else 0.003
	value = clampf(value + relative.x * speed, min_value, max_value)
	_notify_value()

func _apply_toggle() -> void:
	_play(sound_name_alt)
	var on := value > 0.5
	_lever_target = lever_angle if on else -lever_angle * 0.65
	if on_toggle.is_valid():
		on_toggle.call(on)
	_notify_value()
	activated.emit()
	make_noise(noise_db, 0.15)

func _notify_value() -> void:
	if on_value.is_valid():
		on_value.call(value)
	value_changed.emit(value)

func set_value(v: float, notify: bool = false) -> void:
	value = clampf(v, min_value, max_value)
	if kind == Kind.TOGGLE or kind == Kind.LEVER:
		_lever_target = lever_angle if value > 0.5 else -lever_angle * 0.65
	if notify:
		_notify_value()

func get_progress() -> float:
	return hold_progress

func get_prompt() -> String:
	if kind == Kind.HOLD and _active:
		return "%s  %d%%" % [prompt, int(hold_progress * 100.0)]
	return prompt

func _press_animation() -> void:
	if wheel_pivot != null:
		var tw := create_tween()
		tw.tween_property(wheel_pivot, "position:z", 0.015, 0.05)
		tw.tween_property(wheel_pivot, "position:z", 0.0, 0.08)

func _play(name: String) -> void:
	if Game.is_in_game() and Game.audio != null:
		Game.audio.play_ui(name)
