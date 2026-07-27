shader_type spatial;
// 双面版（裙摆等） — 对应 Unity _Cull Off + _DOUBLE_SIDED
// 双面版（裙摆等） — 对应 Unity _Cull Off + _DOUBLE_SIDED
render_mode unshaded, cull_disabled;

#include "toon_common.gdshaderinc"

void fragment() {
	vec2 uv = base_uv;
	// Unity _DOUBLE_SIDED：背面切换第二套 UV（导入时已对齐 Unity 绕序）
	if (!FRONT_FACING) {
		uv = back_uv;
	}
	vec3 n = safe_normalize(world_normal);
	vec3 view_dir = safe_normalize((INV_VIEW_MATRIX * vec4(safe_normalize(-VERTEX), 0.0)).xyz);
	ALBEDO = compute_toon_shading(uv, n, view_dir, COLOR.rgb, mat3(VIEW_MATRIX));
}
