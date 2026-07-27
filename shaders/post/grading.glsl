#[compute]
#version 450

// 颜色分级（Unity ColorGrading）：bloom 叠加 -> 曝光 -> filmic 色调映射
// 对比度/饱和度系数为 1（Unity Volume 配置），省略 ACEScc 变换

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D bloom_texture;

layout(push_constant, std430) uniform Params {
	float exposure;
	float bloom_intensity;
} p;

vec3 tonemap(vec3 color) {
	vec3 c0 = (1.36 * color + 0.047) * color;
	vec3 c1 = (0.93 * color + 0.56) * color + 0.14;
	return clamp(c0 / c1, vec3(0.0), vec3(1.0));
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (pos.x >= size.x || pos.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pos) + 0.5) / vec2(size);
	vec4 base = imageLoad(color_image, pos);
	vec3 color = base.rgb;

	vec3 bloom = texture(bloom_texture, uv).rgb;
	color += bloom * p.bloom_intensity;

	color *= p.exposure;
	color = tonemap(color);

	imageStore(color_image, pos, vec4(color, base.a));
}
