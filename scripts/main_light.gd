@tool
extends DirectionalLight3D
# 对应 Unity 场景中的 Directional Light + TransformRotator
# 每帧把指向光源的世界方向写入全局 shader 参数 main_light_direction
# 编辑器中：旋转本节点（DirectionalLight3D 的 +Z 指向光源）即可实时预览光照变化；
# 未旋转过节点时沿用 direction_to_light 导出参数。

@export var direction_to_light := Vector3(0.383, 0.866, 0.321)
@export var rotate_light := false # Unity TransformRotator：绕 Y 轴旋转，周期 10 秒
@export var rotation_cycle := 10.0

var _angle := 0.0
var _editor_dir := Vector3.ZERO # 编辑器下实际使用的方向
var _last_editor_basis := Basis.IDENTITY
var _last_export_dir := Vector3.ZERO

func _ready() -> void:
	if Engine.is_editor_hint() and not global_basis.is_equal_approx(Basis.IDENTITY):
		# 场景里保存了旋转过的节点：以节点朝向为准
		_editor_dir = global_basis.z.normalized()
		_last_editor_basis = global_basis
	else:
		_editor_dir = direction_to_light.normalized()
	_last_export_dir = direction_to_light
	_update()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# 节点被旋转时优先跟随节点实际朝向；否则跟随导出参数的修改
		if not global_basis.is_equal_approx(_last_editor_basis):
			_last_editor_basis = global_basis
			_editor_dir = global_basis.z.normalized()
			_last_export_dir = direction_to_light
		elif direction_to_light != _last_export_dir:
			_last_export_dir = direction_to_light
			_editor_dir = direction_to_light.normalized()
	elif rotate_light and rotation_cycle > 0.0:
		_angle += TAU * delta / rotation_cycle
	_update()

func _update() -> void:
	var dir: Vector3
	if Engine.is_editor_hint():
		# 编辑器里不改动节点变换，避免场景被标记为已修改
		dir = _editor_dir
	else:
		dir = direction_to_light.normalized()
		if _angle != 0.0:
			dir = Basis(Vector3.UP, _angle) * dir
		global_basis = Basis.looking_at(-dir, Vector3.UP)
	RenderingServer.global_shader_parameter_set(&"main_light_direction", dir)
