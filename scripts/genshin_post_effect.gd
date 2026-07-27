@tool
extends CompositorEffect
class_name GenshinPostEffect
# 移植 Unity URPGenshinPostProcess 后处理链：
# Prefilter(阈值) -> 四级高斯模糊链 -> 加权上采样 -> Bloom 叠加 + 曝光 + Filmic 色调映射
# 参数对应 Unity Volume: Bloom(Color, threshold 0.7, intensity 1.5, weights 0.1-0.4,
# blurRadius 2, downSampleScale 0.5) + ColorGrading(tonemap on, exposure 1.05)

@export var bloom_threshold := 0.7
@export var bloom_intensity := 1.5
@export var bloom_weights := Vector4(0.1, 0.2, 0.3, 0.4)
@export var blur_radius := 2.0
@export var downsample_scale := 0.5
@export var exposure := 1.05

const ITERATIONS := 4

var rd: RenderingDevice
var _pipelines := {}
var _shaders := {}
var _linear_sampler: RID
var _tex_a: Array[RID] = []
var _tex_b: Array[RID] = []
var _tex_sizes: Array[Vector2i] = []

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = false
	access_resolved_depth = false
	needs_motion_vectors = false
	rd = RenderingServer.get_rendering_device()
	if rd != null:
		RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(_what: int) -> void:
	# 退出时不显式释放 RID（引擎退出时统一清理），避免渲染线程回调已销毁对象
	pass

func _load_pipeline(path: String) -> RID:
	var shader_file: RDShaderFile = load(path)
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader: RID = rd.shader_create_from_spirv(spirv)
	_shaders[path] = shader
	var pipeline: RID = rd.compute_pipeline_create(shader)
	_pipelines[path] = pipeline
	return pipeline

func _initialize_compute() -> void:
	_load_pipeline("res://shaders/post/prefilter.glsl")
	_load_pipeline("res://shaders/post/blur.glsl")
	_load_pipeline("res://shaders/post/upsample.glsl")
	_load_pipeline("res://shaders/post/grading.glsl")
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_linear_sampler = rd.sampler_create(state)

func _free_textures() -> void:
	for tex in _tex_a + _tex_b:
		rd.free_rid(tex)
	_tex_a.clear()
	_tex_b.clear()
	_tex_sizes.clear()

func _create_texture(size: Vector2i) -> RID:
	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.width = size.x
	fmt.height = size.y
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	return rd.texture_create(fmt, RDTextureView.new(), [])

func _ensure_textures(size: Vector2i) -> void:
	var level0 := Vector2i(maxi(1, roundi(size.x * downsample_scale)), maxi(1, roundi(size.y * downsample_scale)))
	var want: Array[Vector2i] = [level0]
	for i in range(1, ITERATIONS):
		var prev: Vector2i = want[i - 1]
		want.append(Vector2i(maxi(1, prev.x / 2), maxi(1, prev.y / 2)))
	if want == _tex_sizes:
		return
	_free_textures()
	_tex_sizes = want
	for i in ITERATIONS:
		_tex_a.append(_create_texture(want[i]))
		_tex_b.append(_create_texture(want[i]))

func _sampler_uniform(tex: RID, binding: int) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_linear_sampler)
	u.add_id(tex)
	return u

func _image_uniform(tex: RID, binding: int) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u

func _dispatch(path: String, uniforms: Array[RDUniform], push_constants: PackedByteArray, groups: Vector2i) -> void:
	var shader: RID = _shaders[path]
	var uniform_set: RID = UniformSetCacheRD.get_cache(shader, 0, uniforms)
	var cl: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _pipelines[path])
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	if push_constants.size() > 0:
		rd.compute_list_set_push_constant(cl, push_constants, push_constants.size())
	rd.compute_list_dispatch(cl, groups.x, groups.y, 1)
	rd.compute_list_add_barrier(cl)
	rd.compute_list_end()

func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or rd == null:
		return
	var buffers := render_data.get_render_scene_buffers()
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	_ensure_textures(size)
	var color: RID = buffers.get_color_layer(0)

	var screen_factor: float = size.y / 1080.0
	var radius: float = blur_radius * downsample_scale * screen_factor

	# 1. Prefilter: scene color -> A[0]
	_dispatch("res://shaders/post/prefilter.glsl",
		[_sampler_uniform(color, 0), _image_uniform(_tex_a[0], 1)],
		_push([bloom_threshold]), _groups(_tex_sizes[0]))

	# 2. 第 0 级: H1x (A0->B0), V1x (B0->A0)
	_dispatch_blur(_tex_a[0], _tex_b[0], _tex_sizes[0], _tex_sizes[0], Vector2(1, 0), radius)
	_dispatch_blur(_tex_b[0], _tex_a[0], _tex_sizes[0], _tex_sizes[0], Vector2(0, 1), radius)

	# 3. 第 1-3 级: H2x (A[i-1]->B[i]), V1x (B[i]->A[i])
	# 注意 Unity 的 _BlitTexture_TexelSize 取自“源”纹理，H2x 的源是上一级（更大）
	for i in range(1, ITERATIONS):
		_dispatch_blur(_tex_a[i - 1], _tex_b[i], _tex_sizes[i - 1], _tex_sizes[i], Vector2(2, 0), radius)
		_dispatch_blur(_tex_b[i], _tex_a[i], _tex_sizes[i], _tex_sizes[i], Vector2(0, 1), radius)

	# 4. 加权上采样: A[0..3] -> B[0]
	_dispatch("res://shaders/post/upsample.glsl",
		[_sampler_uniform(_tex_a[0], 0), _sampler_uniform(_tex_a[1], 1),
		 _sampler_uniform(_tex_a[2], 2), _sampler_uniform(_tex_a[3], 3),
		 _image_uniform(_tex_b[0], 4)],
		_push([bloom_weights.x, bloom_weights.y, bloom_weights.z, bloom_weights.w]),
		_groups(_tex_sizes[0]))

	# 5. 颜色分级: bloom(B[0]) + 曝光 + tonemap，就地写回场景色
	_dispatch("res://shaders/post/grading.glsl",
		[_image_uniform(color, 0), _sampler_uniform(_tex_b[0], 1)],
		_push([exposure, bloom_intensity]), _groups(size))

func _dispatch_blur(src: RID, dst: RID, src_size: Vector2i, dst_size: Vector2i, direction: Vector2, radius: float) -> void:
	var texel := Vector2(1.0 / src_size.x, 1.0 / src_size.y)
	_dispatch("res://shaders/post/blur.glsl",
		[_sampler_uniform(src, 0), _image_uniform(dst, 1)],
		_push([direction.x, direction.y, radius, 0.0, texel.x, texel.y]),
		_groups(dst_size))

func _groups(size: Vector2i) -> Vector2i:
	return Vector2i((size.x + 7) / 8, (size.y + 7) / 8)

func _push(floats: Array) -> PackedByteArray:
	var arr := PackedFloat32Array(floats)
	return arr.to_byte_array()
