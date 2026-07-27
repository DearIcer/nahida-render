// ---- General ----
uniform sampler2D base_map : source_color, filter_linear, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool is_day = true;
uniform bool double_sided = false; // Unity _DOUBLE_SIDED（本 FBX 无第二套 UV，背面粉扑退回主 UV）

// ---- Shadow ----
uniform sampler2D light_map : filter_linear, repeat_enable;
uniform vec3 light_direction_multiplier = vec3(1.0, 0.5, 1.0);
uniform float shadow_offset = 0.1;
uniform float shadow_smoothness = 0.4;
uniform vec3 shadow_color = vec3(1.1, 1.1, 1.1); // HDR
uniform sampler2D shadow_ramp : source_color, filter_linear, repeat_disable;
uniform bool use_custom_material_type = false;
uniform float custom_material_type = 1.0;

// ---- Emission ----
uniform bool use_emission = false;
uniform float emission_intensity = 0.2;

// ---- Normal ----
uniform bool use_normal_map = false;
uniform sampler2D normal_map : filter_linear, repeat_enable;

// ---- Face ----
uniform bool is_face = false;
uniform vec3 face_direction = vec3(0.0, 0.0, 1.0);
uniform float face_shadow_offset = 0.0;
uniform vec4 face_blush_color : source_color = vec4(1.0, 0.72156864, 0.69803923, 1.0);
uniform float face_blush_strength = 0.0;
uniform sampler2D face_light_map : filter_linear, repeat_enable;
uniform sampler2D face_shadow_tex : filter_linear, repeat_enable;

// ---- Specular ----
uniform bool use_specular = false;
uniform float specular_smoothness = 5.0;
uniform float nonmetallic_intensity = 0.3;
uniform float metallic_intensity = 8.0;
uniform sampler2D metal_map : source_color, filter_linear, repeat_enable;

// ---- Rim Light ----
// 注：Unity 版用屏幕深度差检测轮廓抑制内侧边缘光；
// Godot 透明队列外的材质无法采样包含自身的深度图，这里退化为纯菲涅尔边缘光
uniform bool use_rim = false;
uniform float rim_offset = 5.0;
uniform float rim_threshold = 0.5;
uniform float rim_intensity = 0.5;

// 主光方向（指向光源），由 DirectionalLight3D 上的脚本每帧写入
global uniform vec3 main_light_direction;

varying vec3 world_pos;
varying vec3 world_tangent;
varying vec3 world_bitangent;
varying vec3 world_normal;
varying vec2 base_uv;
varying vec2 back_uv;

vec3 safe_normalize(vec3 v) {
	return v * inversesqrt(max(dot(v, v), 1e-8));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = safe_normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_tangent = safe_normalize(MODEL_NORMAL_MATRIX * TANGENT);
	world_bitangent = safe_normalize(MODEL_NORMAL_MATRIX * BINORMAL);
	base_uv = UV;
	back_uv = UV2;
}

// Unity GetShadow
float get_shadow(vec3 normal_ws, vec3 light_dir, float ao_factor) {
	float ndotl = dot(normal_ws, light_dir);
	float half_lambert = 0.5 * ndotl + 0.5;
	float shadow = clamp(2.0 * half_lambert * ao_factor, 0.0, 1.0);
	return mix(shadow, 1.0, step(0.9, ao_factor));
}

// Unity GetFaceShadow（SDF 脸部阴影）
float get_face_shadow(vec2 uv, vec3 light_dir) {
	vec3 f = safe_normalize(vec3(face_direction.x, 0.0, face_direction.z));
	vec3 l = safe_normalize(vec3(light_dir.x, 0.0, light_dir.z));
	float fdotl = dot(f, l);
	float fcrossl = cross(f, l).y;

	vec2 shadow_uv = uv;
	// 与 Unity 一致：light 从角色左侧来时翻转 SDF 贴图（已验证与 Unity 渲染结果同侧）
	shadow_uv.x = mix(shadow_uv.x, 1.0 - shadow_uv.x, step(0.0, fcrossl));
	float face_shadow_map = texture(face_light_map, shadow_uv).r;
	float face_shadow_val = step(-0.5 * fdotl + 0.5 + face_shadow_offset, face_shadow_map);

	float face_mask = texture(face_shadow_tex, uv).a;
	return mix(face_shadow_val, 1.0, face_mask);
}

// Unity GetShadowColor（阴影色阶 + Ramp）
vec3 get_shadow_color(float shadow, float material, float day) {
	float index = 4.0;
	index = mix(index, 1.0, step(0.2, material));
	index = mix(index, 2.0, step(0.4, material));
	index = mix(index, 0.0, step(0.6, material));
	index = mix(index, 3.0, step(0.8, material));

	float range_min = 0.5 + shadow_offset - shadow_smoothness;
	float range_max = 0.5 + shadow_offset;
	vec2 ramp_uv = vec2(smoothstep(range_min, range_max, shadow), index / 10.0 + 0.5 * day + 0.05);
	// Unity 纹理原点在左下，shader 计算的 v 需翻转才能与 Godot（原点在左上）采到同一行
	ramp_uv.y = 1.0 - ramp_uv.y;
	vec3 shadow_ramp_col = texture(shadow_ramp, ramp_uv).rgb;

	vec3 shadow_col = shadow_ramp_col * mix(shadow_color, vec3(1.0), smoothstep(0.9, 1.0, ramp_uv.x));
	shadow_col = mix(shadow_col, vec3(1.0), step(range_max, shadow));
	return shadow_col;
}

// Unity GetSpecular（Blinn-Phong + MetalMap matcap）
vec3 get_specular(vec3 normal_ws, vec3 normal_vs, vec3 light_dir, vec3 albedo, vec3 light_map_rgb, vec3 view_dir) {
	vec3 h = safe_normalize(light_dir + view_dir);
	float ndoth = dot(normal_ws, h);
	float blinn_phong = pow(clamp(ndoth, 0.0, 1.0), specular_smoothness);

	vec2 matcap_uv = 0.5 * normal_vs.xy + 0.5;
	matcap_uv.y = 1.0 - matcap_uv.y; // Unity 纹理原点左下，翻转 V
	vec3 metal_map_col = texture(metal_map, matcap_uv).rgb;

	vec3 non_metallic = vec3(step(1.1, light_map_rgb.b + blinn_phong) * light_map_rgb.r * nonmetallic_intensity);
	vec3 metallic = blinn_phong * light_map_rgb.b * albedo * metal_map_col * metallic_intensity;
	return mix(non_metallic, metallic, step(0.9, light_map_rgb.r));
}

// 菲涅尔边缘光（Unity GetRim 的退化版，见上方注释）
float get_rim(vec3 normal_ws, vec3 view_dir) {
	float ndotv = dot(normal_ws, view_dir);
	float fresnel = pow(clamp(1.0 - ndotv, 0.0, 1.0), 5.0);
	return rim_intensity * fresnel;
}

// Unity ComputeToonShading（view_dir 与 view_mat 需在 fragment 中用内置矩阵计算后传入）
vec3 compute_toon_shading(vec2 uv, vec3 normal_ws, vec3 view_dir, vec3 vertex_color, mat3 view_mat) {
	vec4 base_map_col = texture(base_map, uv);
	vec3 albedo = base_map_col.rgb * base_color.rgb;
	float alpha = base_map_col.a;

	if (is_face) {
		albedo = mix(albedo, face_blush_color.rgb, face_blush_strength * alpha);
	}

	if (use_normal_map) {
		vec3 normal_ts = texture(normal_map, uv).rgb * 2.0 - 1.0;
		normal_ws = safe_normalize(world_tangent * normal_ts.x + world_bitangent * normal_ts.y + normal_ws * normal_ts.z);
	}
	vec3 normal_vs = safe_normalize(view_mat * normal_ws);

	vec3 light_dir = safe_normalize(main_light_direction * light_direction_multiplier);
	// FBX 导入的轴转换使网格法线相对 Unity 绕 Y 旋转了 180°（x、z 均反向），
	// 骨骼朝向（脸部 SDF）不受影响；身体 half-lambert 与高光用 XZ 翻转后的光向
	vec3 light_dir_body = vec3(-light_dir.x, light_dir.y, -light_dir.z);

	vec4 light_map_col = texture(light_map, uv);
	float material = mix(light_map_col.a, custom_material_type, float(use_custom_material_type));

	float shadow;
	if (is_face) {
		shadow = get_face_shadow(uv, light_dir);
	} else {
		// Godot 4 在着色器里把顶点色从 sRGB 转到了线性空间，Unity 用的是原始 sRGB 值，
		// 此处 pow(1/2.2) 还原，否则 AO 系统性偏小、受光面偏暗
		float ao_factor = light_map_col.g * pow(vertex_color.r, 1.0 / 2.2);
		shadow = get_shadow(normal_ws, light_dir_body, ao_factor);
	}
	vec3 shadow_col = get_shadow_color(shadow, material, is_day ? 1.0 : 0.0);

	vec3 specular = vec3(0.0);
	if (use_specular) {
		specular = get_specular(normal_ws, normal_vs, light_dir_body, albedo, light_map_col.rgb, view_dir);
	}

	vec3 emission = vec3(0.0);
	if (use_emission) {
		emission = albedo * emission_intensity * alpha;
	}

	vec3 rim = vec3(0.0);
	if (use_rim) {
		rim = albedo * get_rim(normal_ws, view_dir);
	}

	return albedo * shadow_col + specular + rim + emission;
}
