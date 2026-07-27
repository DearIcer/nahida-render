shader_type spatial;
// 边缘光独立 Pass — 移植 Unity GetRim 的屏幕深度差检测
// 基础 Pass 保持不透明（深度写入深度图），本 Pass 在透明队列中采样深度图，
// 与 Unity 在 Forward Pass 内采样 _CameraDepthTexture 的结果一致
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, blend_add;

uniform sampler2D base_map : source_color, filter_linear, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float rim_offset = 5.0;
uniform float rim_threshold = 0.5;
uniform float rim_intensity = 0.5;

varying vec3 world_normal;
varying vec2 base_uv;

vec3 safe_normalize(vec3 v) {
	return v * inversesqrt(max(dot(v, v), 1e-8));
}

void vertex() {
	world_normal = safe_normalize(MODEL_NORMAL_MATRIX * NORMAL);
	base_uv = UV;
}

void fragment() {
	float frag_depth = -VERTEX.z;
	float raw_depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float depth = -(view_pos.z / view_pos.w);
	// 被其它表面（或描边外壳）遮挡时不叠加（等价于 Unity 的深度测试）
	if (depth < frag_depth - 0.002) {
		discard;
	}

	vec3 n_ws = safe_normalize(world_normal);
	vec3 normal_vs = safe_normalize((VIEW_MATRIX * vec4(n_ws, 0.0)).xyz);
	vec2 offset = vec2(rim_offset * normal_vs.x / VIEWPORT_SIZE.x, 0.0);
	vec2 offset_uv = SCREEN_UV + offset;
	float raw_depth2 = texture(depth_texture, offset_uv).x;
	vec4 view_pos2 = INV_PROJECTION_MATRIX * vec4(offset_uv * 2.0 - 1.0, raw_depth2, 1.0);
	float offset_depth = -(view_pos2.z / view_pos2.w);

	float rim = smoothstep(0.0, rim_threshold, offset_depth - depth) * rim_intensity;

	vec3 view_dir = safe_normalize((INV_VIEW_MATRIX * vec4(safe_normalize(-VERTEX), 0.0)).xyz);
	float ndotv = dot(n_ws, view_dir);
	float fresnel = pow(clamp(1.0 - ndotv, 0.0, 1.0), 5.0);

	vec3 albedo = texture(base_map, base_uv).rgb * base_color.rgb;
	ALBEDO = albedo * rim * fresnel;
}
