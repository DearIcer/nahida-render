#[compute]
#version 450

// Bloom 上采样（Unity Upsample）：四级加权求和

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D bloom_a;
layout(set = 0, binding = 1) uniform sampler2D bloom_b;
layout(set = 0, binding = 2) uniform sampler2D bloom_c;
layout(set = 0, binding = 3) uniform sampler2D bloom_d;
layout(rgba16f, set = 0, binding = 4) uniform writeonly image2D dst;

layout(push_constant, std430) uniform Params {
	vec4 weights;
} p;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(dst);
	if (pos.x >= size.x || pos.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pos) + 0.5) / vec2(size);
	vec3 color = vec3(0.0);
	color += texture(bloom_a, uv).rgb * p.weights.x;
	color += texture(bloom_b, uv).rgb * p.weights.y;
	color += texture(bloom_c, uv).rgb * p.weights.z;
	color += texture(bloom_d, uv).rgb * p.weights.w;
	imageStore(dst, pos, vec4(color, 1.0));
}
