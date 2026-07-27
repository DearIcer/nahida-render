shader_type spatial;
// 仿原神卡通渲染 — 移植自 Unity URP "URPGenshinToon" (ToonForwardPass.hlsl)
// 与 Unity 版一致：全部光照在片元中手工计算，不依赖引擎光照管线
render_mode unshaded, cull_back;

#include "toon_common.gdshaderinc"

void fragment() {
	vec2 uv = base_uv;
	vec3 n = safe_normalize(world_normal);
	vec3 view_dir = safe_normalize((INV_VIEW_MATRIX * vec4(safe_normalize(-VERTEX), 0.0)).xyz);
	ALBEDO = compute_toon_shading(uv, n, view_dir, COLOR.rgb, mat3(VIEW_MATRIX));
}
