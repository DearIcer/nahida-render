@tool
extends EditorScenePostImport
# FBX 导入后处理：为每个网格表面生成切线空间平滑法线，存入 CUSTOM0
# 对应 Unity 工程中 Nahida_Body_Smooth.mesh 的 TEXCOORD7，用于描边挤出避免硬边裂缝

func _post_import(scene: Node) -> Object:
	print("[smooth_normal_import] post-import running")
	_process_node(scene)
	return scene

func _process_node(node: Node) -> void:
	var mesh = node.get("mesh")
	if mesh is ArrayMesh:
		_process_mesh(node, mesh)
	for child in node.get_children():
		_process_node(child)

func _process_mesh(mi: Node, mesh: ArrayMesh) -> void:
	var uv2_map := _load_uv2_map() if mi.name == "Body" else {}
	var new_mesh := ArrayMesh.new()
	var bs_names: Array[StringName] = []
	for i in mesh.get_blend_shape_count():
		bs_names.append(mesh.get_blend_shape_name(i))
	for name in bs_names:
		new_mesh.add_blend_shape(name)
	for i in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(i)
		var blend_shapes: Array = []
		if mesh.has_method("surface_get_blend_shape_arrays"):
			blend_shapes = mesh.call("surface_get_blend_shape_arrays", i)
		var format: int = mesh.surface_get_format(i)
		if arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_TANGENT] != null:
			arrays[Mesh.ARRAY_CUSTOM0] = _compute_smooth_normal_ts(arrays)
			format |= Mesh.ARRAY_FORMAT_CUSTOM0 | (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		if not uv2_map.is_empty() and arrays[Mesh.ARRAY_TEX_UV] != null:
			arrays[Mesh.ARRAY_TEX_UV2] = _build_uv2(arrays, uv2_map)
			format |= Mesh.ARRAY_FORMAT_TEX_UV2
		new_mesh.add_surface_from_arrays(
			mesh.surface_get_primitive_type(i),
			arrays,
			blend_shapes,
			{},
			format
		)
		new_mesh.surface_set_name(i, mesh.surface_get_name(i))
		if mesh.surface_get_material(i) != null:
			new_mesh.surface_set_material(i, mesh.surface_get_material(i))
	mi.set("mesh", new_mesh)
	print("[smooth_normal_import] rebuilt mesh on ", mi.name, " surfaces=", new_mesh.get_surface_count())

# 读取 Unity 导出的 UV2 数据（按 UV0 索引）
var _uv2_cache := {}

func _load_uv2_map() -> Dictionary:
	if not _uv2_cache.is_empty():
		return _uv2_cache
	var f := FileAccess.open("res://tools/body_uv2.bin", FileAccess.READ)
	if f == null:
		return {}
	var count := f.get_32()
	for i in count:
		var u := f.get_float()
		var v := f.get_float()
		var u2 := f.get_float()
		var v2 := f.get_float()
		_uv2_cache[_uv_key(u, v)] = Vector2(u2, v2)
	return _uv2_cache

func _uv_key(u: float, v: float) -> Vector2i:
	return Vector2i(roundi(u * 1048576.0), roundi(v * 1048576.0))

func _build_uv2(arrays: Array, uv2_map: Dictionary) -> PackedVector2Array:
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var out := PackedVector2Array()
	out.resize(uvs.size())
	var missing := 0
	for i in uvs.size():
		# Unity 的 mesh.uv 相比 FBX 原始 UV 翻转了 V
		var key := _uv_key(uvs[i].x, 1.0 - uvs[i].y)
		if uv2_map.has(key):
			var val: Vector2 = uv2_map[key]
			out[i] = Vector2(val.x, 1.0 - val.y)
		else:
			out[i] = uvs[i]
			missing += 1
	if missing > 0:
		print("[smooth_normal_import] uv2 lookup missing: ", missing, "/", uvs.size())
	return out

# 按位置聚合顶点，平均法线后转换到切线空间，编码为 RGBA8 (0-255)
func _compute_smooth_normal_ts(arrays: Array) -> PackedByteArray:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var count := verts.size()

	var acc := {}
	for i in count:
		var key := _pos_key(verts[i])
		acc[key] = acc.get(key, Vector3.ZERO) + normals[i]

	var out := PackedByteArray()
	out.resize(count * 4)
	for i in count:
		var avg: Vector3 = (acc[_pos_key(verts[i])] as Vector3)
		if avg.length_squared() < 1e-12:
			avg = normals[i]
		avg = avg.normalized()
		var n := normals[i]
		var t := Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2]).normalized()
		var w := tangents[i * 4 + 3]
		var b := n.cross(t).normalized() * w
		var ts := Vector3(avg.dot(t), avg.dot(b), avg.dot(n)).normalized()
		out[i * 4] = int(clamp(ts.x * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		out[i * 4 + 1] = int(clamp(ts.y * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		out[i * 4 + 2] = int(clamp(ts.z * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		out[i * 4 + 3] = 255
	return out

func _pos_key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 100000.0), roundi(v.y * 100000.0), roundi(v.z * 100000.0))
