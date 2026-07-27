shader_type spatial;
// 眉毛透发叠加 Pass — 移植自 Unity URP "URPGenshinToon" (ToonBrowShowThroughPass.hlsl)
// Unity 用 ZTest Greater + Stencil(Equal) 只在被头发遮挡处叠加眉毛；
// Godot 无模板缓冲，改为手动比较深度图：仅在眉毛被近距离遮挡物（刘海）挡住时绘制
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, blend_mix;

#include "toon_common.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float show_through_alpha = 0.65;
uniform float show_through_max_depth = 0.2;

void fragment() {
	// 场景深度（不透明物体，含眉毛自身的 Forward Pass）
	float raw_depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float scene_depth = -(view_pos.z / view_pos.w);
	float brow_depth = -VERTEX.z;

	// ZTest Greater：未被遮挡（眉毛自身或更近处无遮挡物）时不叠加
	if (brow_depth - scene_depth < 0.001) {
		discard;
	}
	// 遮挡物距离眉毛太远（如从背后看到的后脑勺头发）时不透眉（与 Unity 公式一致）
	if (scene_depth - brow_depth > show_through_max_depth) {
		discard;
	}

	vec2 uv = base_uv;
	vec3 n = safe_normalize(world_normal);
	vec3 view_dir = safe_normalize((INV_VIEW_MATRIX * vec4(safe_normalize(-VERTEX), 0.0)).xyz);
	vec3 final_color = compute_toon_shading(uv, n, view_dir, COLOR.rgb, mat3(VIEW_MATRIX));

	// 视线越贴近表面（侧面视角）透出越弱，避免侧发上出现悬浮的透视斑块
	float view_fade = clamp(dot(n, view_dir), 0.0, 1.0);
	// 只有镜头位于面部前方半球时才透出，杜绝从脑后看到眉眼
	vec3 f = safe_normalize(face_direction);
	float face_fade = smoothstep(0.0, 0.3, dot(f, view_dir));

	ALBEDO = final_color;
	ALPHA = show_through_alpha * view_fade * face_fade;
}
