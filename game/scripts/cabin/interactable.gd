class_name Interactable
extends Node3D
## База для всего, что можно потрогать. Луч игрока попадает в StaticBody3D
## на слое Interactable; в metadata лежит ссылка на устройство.

signal activated
signal value_changed(value: float)

@export var prompt: String = "Использовать"
@export var hold_time: float = 0.0
@export var noise_db: float = 8.0

var sim = null
var focused := false
var enabled := true
var _collider: StaticBody3D
var _highlight: OmniLight3D
var _base_prompt := ""

func _ready() -> void:
	_base_prompt = prompt
	_highlight = OmniLight3D.new()
	_highlight.light_color = Color(1.0, 0.72, 0.42)
	_highlight.light_energy = 0.0
	_highlight.omni_range = 0.55
	_highlight.shadow_enabled = false
	_highlight.position = Vector3(0, 0.08, 0)
	add_child(_highlight)

func setup_collider(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	if _collider != null:
		return
	_collider = StaticBody3D.new()
	_collider.name = "InteractCollider"
	_collider.collision_layer = 4
	_collider.collision_mask = 0
	_collider.set_meta("interactable", self)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	_collider.add_child(cs)
	add_child(_collider)

func focus(player) -> void:
	focused = true
	prompt = _base_prompt
	if _highlight != null:
		_highlight.light_energy = 0.35
	_on_focus(player)

func unfocus() -> void:
	focused = false
	if _highlight != null:
		_highlight.light_energy = 0.0
	_on_unfocus()

func _on_focus(_player) -> void:
	pass

func _on_unfocus() -> void:
	pass

func use_start(player) -> void:
	if not enabled:
		return
	_use_start(player)

func use_stop(player) -> void:
	if not enabled:
		return
	_use_stop(player)

func scroll(step: float) -> void:
	if not enabled:
		return
	_scroll(step)

func drag(relative: Vector2) -> void:
	if not enabled:
		return
	_drag(relative)

func alt_use() -> void:
	pass

func get_prompt() -> String:
	return prompt

func get_progress() -> float:
	return 0.0

func make_noise(db: float, duration: float = 0.2) -> void:
	if sim != null:
		sim.add_noise(db, global_position, duration)
	else:
		Game.add_noise(db, global_position, duration)

# Переопределяемые.
func _use_start(_player) -> void:
	pass

func _use_stop(_player) -> void:
	pass

func _scroll(_step: float) -> void:
	pass

func _drag(_relative: Vector2) -> void:
	pass
