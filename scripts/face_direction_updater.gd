extends Node3D
# 对应 Unity 的 MaterialUpdater：从头骨骼计算脸部朝向，
# 每帧写入脸部/眉毛材质的 face_direction 参数（SDF 脸部阴影与眉毛透发依赖该向量）

@export var skeleton_path: NodePath
@export var head_bone_name := "Bip001 Head"
@export var head_direction := Vector3.UP
@export var face_materials: Array[ShaderMaterial] = []

var _skeleton: Skeleton3D
var _head_bone := -1

func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton:
		_head_bone = _skeleton.find_bone(head_bone_name)

func _process(_delta: float) -> void:
	if _skeleton == null or _head_bone < 0:
		return
	var pose := _skeleton.get_bone_global_pose(_head_bone)
	var dir := (_skeleton.global_transform.basis * pose.basis.orthonormalized() * head_direction).normalized()
	for mat in face_materials:
		if mat:
			mat.set_shader_parameter(&"face_direction", dir)
