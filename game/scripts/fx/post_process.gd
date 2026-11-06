class_name PostProcess
extends CanvasLayer
## Один проход постобработки поверх 3D и под HUD.

var rect: ColorRect
var material: ShaderMaterial
var _flash := 0.0
var _danger := 0.0
var _grain := 0.045

func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.name = "PostRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/post.gdshader") as Shader
	material.set_shader_parameter("grain", _grain)
	material.set_shader_parameter("vignette", 0.40)
	material.set_shader_parameter("chroma", 0.0007)
	material.set_shader_parameter("barrel", 0.010)
	material.set_shader_parameter("danger", 0.0)
	material.set_shader_parameter("flash", 0.0)
	rect.material = material
	apply_quality(int(Game.settings.get("quality", 2)))

func apply_quality(q: int) -> void:
	if material == null:
		return
	match q:
		0:
			_grain = 0.02
			material.set_shader_parameter("grain", 0.02)
			material.set_shader_parameter("chroma", 0.0006)
			material.set_shader_parameter("barrel", 0.0)
		1:
			_grain = 0.032
			material.set_shader_parameter("grain", 0.032)
			material.set_shader_parameter("chroma", 0.0005)
			material.set_shader_parameter("barrel", 0.010)
		_:
			_grain = 0.048
			material.set_shader_parameter("grain", 0.048)
			material.set_shader_parameter("chroma", 0.0008)
			material.set_shader_parameter("barrel", 0.020)

func set_danger(value: float) -> void:
	_danger = clampf(value, 0.0, 1.0)
	if material != null:
		material.set_shader_parameter("danger", _danger)

func pulse_flash(amount: float = 0.75, duration: float = 0.18) -> void:
	if material == null:
		return
	var tw := create_tween()
	tw.tween_method(_set_flash, amount, 0.0, duration)

func _set_flash(v: float) -> void:
	_flash = v
	if material != null:
		material.set_shader_parameter("flash", _flash)

func set_post_enabled(on: bool) -> void:
	visible = on
