# AGENTS.md

Godot 4.7 项目：仿原神卡通渲染（纳西妲），逐行移植自 Unity 工程
`E:\UnityProject\NahidaRenderProject` 的 `URPGenshinToon` 着色器。细节见 `README.md`。

## 关键约定

- Godot 可执行文件：`C:\Users\lijin\Desktop\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe`
- 无头导入：`godot --headless --import`；截图验证：`godot -- --capture=res://screenshot.png`
- FBX 重新导入需先删除 `.godot/imported/Avatar_Loli_Catalyst_Nahida.fbx-*`
  （内容未变时 Godot 不会重导）。
- FBX 导入后处理脚本 `tools/smooth_normal_import.gd` 负责：生成 CUSTOM0 平滑法线、
  按 `tools/body_uv2.bin`（Unity 导出的 UV2，注意 Unity mesh.uv 翻转了 V）注入 UV2。
  网格实例是 `Skeleton3D` 的子节点（材质覆盖路径别写错）。
- 材质参数一律以 Unity `Materials/Nahida/Nahida_Base.mat` 为准，各部位材质是
  它的变体（只覆盖差值）；`python tools/gen_materials.py` 一键重建全部材质。
- 贴图：`mipmaps/generate=false`（对齐 Unity enableMipMap:0，否则 ShadowRamp 混成灰色）；
  Diffuse/Ramp/MetalMap 用 `source_color`，Lightmap/Normal/FaceLightmap/FaceShadow 线性。
- **着色器内计算的 UV（Ramp 行号、matcap）必须翻转 V**（Unity 纹理原点左下，
  Godot 左上；网格 UV 采样则无需处理）。
- **网格法线 X、Z 均与 Unity 相反**（FBX 导入轴转换，骨骼朝向不受影响）：身体
  光照用 `light_dir_body = (-L.x, L.y, -L.z)`，脸部 SDF 用原光向。注意 Unity 与
  Godot 世界互为 X 镜像（反射）：`dot(F,L)` 不变，但 `cross(F,L).y` 变号，因此
  脸部 SDF 翻面条件必须与 Unity **反号**（`fcrossl = -cross(f,l).y`），否则侧光时
  脸部阴影左右颠倒（默认顶光下差异极小，需用侧光验证）。
- 着色器内置矩阵（`VIEW_MATRIX`、`PROJECTION_MATRIX` 等）只能直接在
  `vertex()/fragment()` 里用，需传入自定义函数（否则编译报错）。
- 改 `.gdshaderinc` 后渲染未变 → 删 `.godot/shader_cache`。
- 材质/场景被编辑器重新序列化后参数丢失 → 跑 `python tools/gen_materials.py` 重建。
- 主光方向通过全局 shader uniform `main_light_direction` 传递
  （在 `project.godot [shader_globals]` 中声明，编辑器编译期必须存在；
  `global_shader_parameter_get` 仅编辑器可用，运行时用 `set`）。
  编辑器里旋转 DirectionalLight3D 节点即可实时预览光照变化（脚本 `main_light.gd`
  检测节点 basis 变化并跟随，节点 +Z 为指向光源方向；未旋转过时沿用
  `direction_to_light` 导出参数，运行时行为不变）。
- Unity 批处理参考图：`E:\UnityProject\NahidaRenderProject` 下
  `Assets/Editor/BatchScreenshot.cs`，`Unity.exe -batchmode -projectPath ... -executeMethod BatchScreenshot.Capture`
  生成 `unity_reference.png` 供逐像素对比；`BatchScreenshot.CaptureSideLight`
  生成侧光参考 `unity_side_right.png`（验证脸部 SDF 左右方向用，默认顶光下看不出）。
- 角色模型/贴图为游戏提取资源，仅限学习用途，禁止商用。
