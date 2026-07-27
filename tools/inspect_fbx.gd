extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://assets/models/Avatar_Loli_Catalyst_Nahida.fbx")
	var root := ps.instantiate()
	_dump(root, 0)
	quit()

func _dump(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var info := pad + n.name + " [" + n.get_class() + "]"
	if n is MeshInstance3D:
		print(pad, "  transparency=", n.transparency, " gi=", n.gi_mode, " cast_shadow=", n.cast_shadow)
		var m = n.mesh
		if m:
			info += " surfaces=%d aabb=%s blend_shapes=%d" % [m.get_surface_count(), m.get_aabb(), m.get_blend_shape_count()]
			for i in m.get_surface_count():
				var arrays = m.surface_get_arrays(i)
				var flags = m.surface_get_format(i)
				var has_color = (flags & Mesh.ARRAY_FORMAT_COLOR) != 0
				var has_tangent = (flags & Mesh.ARRAY_FORMAT_TANGENT) != 0
				var has_uv2 = (flags & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
				var custom0 = (flags & Mesh.ARRAY_FORMAT_CUSTOM0) != 0
				var vcount: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var cinfo := ""
				if has_color:
					var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					var c0 := cols[0] if cols.size() > 0 else Color.BLACK
					cinfo = " color0=%s" % c0
				print("%s  surface %d name=%s verts=%d color=%s tangent=%s uv2=%s custom0=%s%s" % [pad, i, m.surface_get_name(i), vcount, has_color, has_tangent, has_uv2, custom0, cinfo])
				var mat = m.surface_get_material(i)
				if mat:
					print("%s    material: %s" % [pad, mat.resource_name])
	if n is Skeleton3D:
		info += " bones=%d" % n.get_bone_count()
	print(info)
	if n is Skeleton3D:
		for i in n.get_bone_count():
			var bname = n.get_bone_name(i)
			if "head" in bname.to_lower():
				print("%s  bone %d: %s" % [pad, i, bname])
	for c in n.get_children():
		_dump(c, depth + 1)
