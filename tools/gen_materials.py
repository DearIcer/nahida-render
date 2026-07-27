#!/usr/bin/env python3
# 重新生成全部材质 .tres（参数对齐 Unity Nahida_Base.mat 及其变体）
# 用法: python tools/gen_materials.py
import os, re

TEX = "res://assets/textures/"
BODY_D = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Body_Diffuse.png"
BODY_L = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Body_Lightmap.png"
BODY_N = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Body_Normalmap.png"
BODY_R = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Body_Shadow_Ramp.png"
HAIR_D = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Hair_Diffuse.png"
HAIR_L = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Hair_Lightmap.png"
HAIR_N = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Hair_Normalmap.png"
HAIR_R = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Hair_Shadow_Ramp.png"
FACE_D = TEX+"Avatar_Loli_Catalyst_Nahida_Tex_Face_Diffuse.png"
FACE_LM = TEX+"Avatar_Loli_Tex_FaceLightmap.png"
FACE_SH = TEX+"Avatar_Tex_Face_Shadow.png"
METAL = TEX+"Avatar_Tex_MetalMap.png"
WHITE = TEX+"white.png"

TOON = "res://shaders/toon.gdshader"
TOON_DS = "res://shaders/toon_doublesided.gdshader"
OUTLINE = "res://shaders/outline.gdshader"
RIM = "res://shaders/rim.gdshader"
RIM_DS = "res://shaders/rim_doublesided.gdshader"
BROW = "res://shaders/brow_showthrough.gdshader"

MAT = "res://materials/"

BASE = {
    "is_day": "true",
    "light_direction_multiplier": "Vector3(1, 0.5, 1)",
    "shadow_offset": "0.1",
    "shadow_smoothness": "0.4",
    "shadow_color": "Vector3(1.1, 1.1, 1.1)",
    "use_custom_material_type": "false",
    "custom_material_type": "1.0",
    "use_emission": "false",
    "emission_intensity": "0.2",
    "use_normal_map": "false",
    "is_face": "false",
    "face_shadow_offset": "0.0",
    "face_blush_color": "Color(1, 0.72156864, 0.69803923, 1)",
    "face_blush_strength": "0.0",
    "use_specular": "false",
    "specular_smoothness": "5.0",
    "nonmetallic_intensity": "0.3",
    "metallic_intensity": "8.0",
    "use_rim": "false",
    "rim_offset": "5.0",
    "rim_threshold": "0.5",
    "rim_intensity": "0.5",
}

def write_mat(name, shader, textures, params, next_pass=None, render_priority=None, res_name=None):
    ext = [('Shader', shader, '1')]
    tex_ids = {}
    i = 2
    for key, path in textures.items():
        ext.append(('Texture2D', path, str(i)))
        tex_ids[key] = str(i)
        i += 1
    np_id = None
    if next_pass:
        ext.append(('Material', next_pass, str(i)))
        np_id = str(i)
        i += 1
    lines = ['[gd_resource type="ShaderMaterial" load_steps=%d format=3]' % (len(ext)+1), '']
    for t, p, eid in ext:
        lines.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, eid))
    lines += ['', '[resource]']
    if res_name:
        lines.append('resource_name = "%s"' % res_name)
    if render_priority is not None:
        lines.append('render_priority = %d' % render_priority)
    if np_id:
        lines.append('next_pass = ExtResource("%s")' % np_id)
    lines.append('shader = ExtResource("1")')
    for key, tid in tex_ids.items():
        lines.append('shader_parameter/%s = ExtResource("%s")' % (key, tid))
    for k, v in params.items():
        lines.append('shader_parameter/%s = %s' % (k, v))
    open('materials/%s.tres' % name, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

def p(**kw):
    d = dict(BASE); d.update(kw); return d

OC = {
    "outline_color": "Color(0.5176471, 0.35686275, 0.34117648, 1)",
    "outline_color2": "Color(0.3529412, 0.3529412, 0.3529412, 1)",
    "outline_color3": "Color(0.47058824, 0.47058824, 0.5647059, 1)",
    "outline_color4": "Color(0.5176471, 0.35686275, 0.34117648, 1)",
    "outline_color5": "Color(0.35, 0.35, 0.35, 1)",
}
def op(**kw):
    d = {"use_smooth_normal": "true", "outline_width": "1.6",
         "outline_width_params": "Vector4(0, 6, 0.1, 0.6)", "outline_z_offset": "0.1"}
    d.update(OC); d.update(kw); return d

def rp(base_map, base_color=None, next_pass=None):
    d = {"rim_offset": "5.0", "rim_threshold": "0.5", "rim_intensity": "0.5"}
    if base_color:
        d["base_color"] = base_color
    return d

# ---- Rim 材质 ----
write_mat('rim_hair', RIM, {"base_map": HAIR_D}, rp(HAIR_D), render_priority=1, res_name="Rim_Hair")
write_mat('rim_body', RIM, {"base_map": BODY_D}, rp(BODY_D), render_priority=1, res_name="Rim_Body")
write_mat('rim_dress1', RIM_DS, {"base_map": BODY_D}, rp(BODY_D), render_priority=1, res_name="Rim_Dress1")
write_mat('rim_dress2', RIM_DS, {"base_map": HAIR_D}, rp(HAIR_D), render_priority=1, res_name="Rim_Dress2")
write_mat('rim_face', RIM, {"base_map": FACE_D}, rp(FACE_D), render_priority=1, res_name="Rim_Face")

# ---- 描边材质（next_pass 链到 rim）----
write_mat('outline_hair', OUTLINE, {"light_map": HAIR_L}, op(outline_color="Color(0.2784314, 0.18039216, 0.14901961, 1)"),
          next_pass=MAT+"rim_hair.tres", res_name="Outline_Hair")
write_mat('outline_body', OUTLINE, {"light_map": BODY_L}, op(), next_pass=MAT+"rim_body.tres", res_name="Outline_Body")
write_mat('outline_dress1', OUTLINE, {"light_map": BODY_L}, op(outline_z_offset="0.5"),
          next_pass=MAT+"rim_dress1.tres", res_name="Outline_Dress1")
write_mat('outline_dress2', OUTLINE, {"light_map": HAIR_L}, op(outline_z_offset="0.5"),
          next_pass=MAT+"rim_dress2.tres", res_name="Outline_Dress2")

# ---- 本体材质 ----
on_flags = {"use_emission": "true", "use_normal_map": "true", "use_specular": "true"}

write_mat('mat_hair', TOON,
    {"base_map": HAIR_D, "light_map": HAIR_L, "normal_map": HAIR_N, "shadow_ramp": HAIR_R, "metal_map": METAL,
     "face_light_map": WHITE, "face_shadow_tex": WHITE},
    p(**on_flags), next_pass=MAT+"outline_hair.tres", res_name="Nahida_Hair")

write_mat('mat_body', TOON,
    {"base_map": BODY_D, "light_map": BODY_L, "normal_map": BODY_N, "shadow_ramp": BODY_R, "metal_map": METAL,
     "face_light_map": WHITE, "face_shadow_tex": WHITE},
    p(**on_flags), next_pass=MAT+"outline_body.tres", res_name="Nahida_Body")

write_mat('mat_dress1', TOON_DS,
    {"base_map": BODY_D, "light_map": BODY_L, "normal_map": BODY_N, "shadow_ramp": BODY_R, "metal_map": METAL,
     "face_light_map": WHITE, "face_shadow_tex": WHITE},
    p(**on_flags), next_pass=MAT+"outline_dress1.tres", res_name="Nahida_Dress1")

write_mat('mat_dress2', TOON_DS,
    {"base_map": HAIR_D, "light_map": HAIR_L, "normal_map": HAIR_N, "shadow_ramp": HAIR_R, "metal_map": METAL,
     "face_light_map": WHITE, "face_shadow_tex": WHITE},
    p(**on_flags), next_pass=MAT+"outline_dress2.tres", res_name="Nahida_Dress2")

face_flags = {"is_face": "true", "use_custom_material_type": "true"}
face_texs = {"base_map": FACE_D, "face_light_map": FACE_LM, "face_shadow_tex": FACE_SH, "shadow_ramp": BODY_R,
             "light_map": WHITE, "normal_map": WHITE, "metal_map": WHITE}

write_mat('mat_face', TOON, face_texs, p(**face_flags), next_pass=MAT+"rim_face.tres", res_name="Nahida_Face")

write_mat('mat_brow', TOON, face_texs,
    p(**face_flags, base_color="Color(0.9764706, 0.80103135, 0.76164705, 1)"),
    next_pass=MAT+"rim_brow.tres", res_name="Nahida_Brow")

write_mat('rim_brow', RIM, {"base_map": FACE_D},
    rp(FACE_D, base_color="Color(0.9764706, 0.80103135, 0.76164705, 1)"),
    next_pass=MAT+"mat_brow_overlay.tres", render_priority=1, res_name="Rim_Brow")

write_mat('mat_brow_overlay', BROW, face_texs,
    p(**face_flags, base_color="Color(0.9764706, 0.80103135, 0.76164705, 1)",
      use_rim="true", show_through_alpha="0.65", show_through_max_depth="0.2"),
    render_priority=2, res_name="Nahida_BrowShowThrough")

print("regenerated all materials")
