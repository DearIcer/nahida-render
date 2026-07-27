@tool
extends DirectionalLight3D
# 对应 Unity 场景中的 Directional Light + TransformRotator
# 每帧把指向光源的世界方向写入全局 shader 参数 main_light_direction

@export var direction_to_light := Vector3(0.383, 0.866, 0.321)
@export var rotate_light := false # Unity TransformRotator：绕 Y 轴旋转，周期 10 秒
@export var rotation_cycle := 10.0

var _angle := 0.0

func _ready() -> void:
	_update()

func _process(delta: float) -> void:
	if rotate_light and rotation_cycle > 0.0 and not Engine.is_editor_hint():
		_angle += TAU * delta / rotation_cycle
	_update()

func _update() -> void:
	var dir := direction_to_light.normalized()
	if _angle != 0.0:
		dir = Basis(Vector3.UP, _angle) * dir
	if not Engine.is_editor_hint():
		# 编辑器里不改动节点变换，避免场景被标记为已修改
		global_basis = Basis.looking_at(-dir, Vector3.UP)
	RenderingServer.global_shader_parameter_set(&"main_light_direction", dir)
