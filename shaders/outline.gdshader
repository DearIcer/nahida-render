shader_type spatial;
// 描边 Pass — 移植自 Unity URP "URPGenshinToon" (ToonOutlinePass.hlsl)
// 反转外壳法：沿视图空间法线 XY 方向挤出，剔除正面
render_mode unshaded, cull_front;

uniform sampler2D light_map : filter_linear, repeat_enable;

uniform bool use_smooth_normal = false;
uniform float outline_width = 1.6;
uniform vec4 outline_width_params = vec4(0.0, 6.0, 0.1, 0.6);
uniform float outline_z_offset = 0.1;
uniform vec2 screen_offset = vec2(0.0, 0.0); // Unity _ScreenOffset.zw
uniform vec4 outline_color : source_color = vec4(0.5176471, 0.35686275, 0.34117648, 1.0);
uniform vec4 outline_color2 : source_color = vec4(0.3529412, 0.3529412, 0.3529412, 1.0);
uniform vec4 outline_color3 : source_color = vec4(0.47058824, 0.47058824, 0.5647059, 1.0);
uniform vec4 outline_color4 : source_color = vec4(0.5176471, 0.35686275, 0.34117648, 1.0);
uniform vec4 outline_color5 : source_color = vec4(0.35, 0.35, 0.35, 1.0);

varying vec2 base_uv;

vec3 safe_normalize(vec3 v) {
	return v * inversesqrt(max(dot(v, v), 1e-8));
}

// Unity GetOutlineWidth
float get_outline_width(float position_vs_z, float proj_11) {
	float fov_factor = 2.414 / proj_11;
	float z = abs(position_vs_z * fov_factor);
	float k = clamp((z - outline_width_params.x) / (outline_width_params.y - outline_width_params.x), 0.0, 1.0);
	float width = mix(outline_width_params.z, outline_width_params.w, k);
	return 0.01 * outline_width * width;
}

void vertex() {
	base_uv = UV;

	vec3 normal_ws = safe_normalize(MODEL_NORMAL_MATRIX * NORMAL);
	if (use_smooth_normal) {
		// CUSTOM0 中存有切线空间平滑法线（导入脚本生成，对应 Unity 的 TEXCOORD7）
		vec3 normal_ts = 2.0 * (CUSTOM0.xyz - 0.5);
		vec3 t = safe_normalize(MODEL_NORMAL_MATRIX * TANGENT);
		vec3 b = safe_normalize(MODEL_NORMAL_MATRIX * BINORMAL);
		normal_ws = safe_normalize(t * normal_ts.x + b * normal_ts.y + normal_ws * normal_ts.z);
	}

	vec3 position_vs = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float width = get_outline_width(position_vs.z, PROJECTION_MATRIX[1][1]) * COLOR.a;

	vec3 normal_vs = safe_normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (use_smooth_normal) {
		normal_vs = safe_normalize((VIEW_MATRIX * vec4(normal_ws, 0.0)).xyz);
	}
	normal_vs = safe_normalize(vec3(normal_vs.xy, 0.0));

	position_vs += 0.01 * outline_z_offset * safe_normalize(position_vs);
	position_vs += width * normal_vs;

	POSITION = PROJECTION_MATRIX * vec4(position_vs, 1.0);
	POSITION.xy += screen_offset * POSITION.w;
}

void fragment() {
	vec4 light_map_col = texture(light_map, base_uv);
	float material = light_map_col.a;

	vec4 color = outline_color5;
	color = mix(color, outline_color4, step(0.2, material));
	color = mix(color, outline_color3, step(0.4, material));
	color = mix(color, outline_color2, step(0.6, material));
	color = mix(color, outline_color, step(0.8, material));

	ALBEDO = color.rgb;
}
