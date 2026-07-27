#[compute]
#version 450

// Bloom 预过滤（Unity Prefilter, _BLOOM_COLOR 模式）：逐通道减去阈值

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D src;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D dst;

layout(push_constant, std430) uniform Params {
	float threshold;
} p;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(dst);
	if (pos.x >= size.x || pos.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pos) + 0.5) / vec2(size);
	vec3 color = texture(src, uv).rgb;
	color = max(color - p.threshold, vec3(0.0));
	imageStore(dst, pos, vec4(color, 1.0));
}
