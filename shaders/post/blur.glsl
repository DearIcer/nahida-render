#[compute]
#version 450

// 9-tap 高斯模糊（Unity GaussianBlur）：offset = radius * texel * direction

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D src;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D dst;

layout(push_constant, std430) uniform Params {
	vec2 direction;
	float radius;
	vec2 texel;
} p;

const float kernel_offsets[9] = { -4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0 };
const float kernel[9] = {
	0.01621622, 0.05405405, 0.12162162, 0.19459459, 0.22702703,
	0.19459459, 0.12162162, 0.05405405, 0.01621622
};

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(dst);
	if (pos.x >= size.x || pos.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pos) + 0.5) / vec2(size);
	vec2 offset = p.radius * p.texel * p.direction;
	vec3 color = vec3(0.0);
	for (int i = 0; i < 9; i++) {
		color += kernel[i] * texture(src, uv + kernel_offsets[i] * offset).rgb;
	}
	imageStore(dst, pos, vec4(color, 1.0));
}
