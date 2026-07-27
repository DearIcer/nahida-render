shader_type sky;
// 仿 Unity 默认程序化天空盒渐变（蓝天 - 白地平线 - 黄褐地面）
// 颜色按 Unity 渲染参考经后处理反推（HDR 线性值），三停点拟合

uniform vec3 top_color = vec3(0.155, 0.247, 0.429);
uniform vec3 mid_color = vec3(0.31, 0.466, 0.70);
uniform vec3 horizon_color = vec3(0.88, 0.94, 1.03);
uniform vec3 ground_color = vec3(0.143, 0.122, 0.112);

void sky() {
	float y = EYEDIR.y;
	if (y > 0.0) {
		float k = y * 3.92;
		if (k > 0.6) {
			COLOR = mix(mid_color, top_color, clamp((k - 0.6) / 0.4, 0.0, 1.0));
		} else {
			COLOR = mix(horizon_color, mid_color, clamp(k / 0.6, 0.0, 1.0));
		}
	} else {
		COLOR = mix(horizon_color, ground_color, clamp(-y * 16.0, 0.0, 1.0));
	}
}
