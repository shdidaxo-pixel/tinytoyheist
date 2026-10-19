# Spinning gold coin with a "$" on it, 16 frames -> out/coin_sheet.png (4x4, 256 px cells, transparent).
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python design/vfx/render_coin.py
import math
import os

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TMP = os.path.join(OUT, "_coin_frames")
os.makedirs(TMP, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"

world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.3, 0.4, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6


def gold(name, base, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = base
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = rough
    b.inputs["Emission Color"].default_value = base
    b.inputs["Emission Strength"].default_value = 0.25
    return m


coin_mat = gold("Gold", (1.0, 0.72, 0.12, 1), 0.28)
rim_mat = gold("Rim", (0.95, 0.55, 0.05, 1), 0.35)
sign_mat = gold("Sign", (1.0, 0.86, 0.35, 1), 0.18)

pivot = bpy.data.objects.new("Pivot", None)
scene.collection.objects.link(pivot)

bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=1.0, depth=0.22, rotation=(math.pi / 2, 0, 0))
coin = bpy.context.object
coin.data.materials.append(coin_mat)
coin.parent = pivot
bevel = coin.modifiers.new("Bevel", "BEVEL")
bevel.width = 0.06
bevel.segments = 3

bpy.ops.mesh.primitive_torus_add(major_radius=0.86, minor_radius=0.05, rotation=(math.pi / 2, 0, 0))
for side in (-1, 1):
    ring = bpy.context.object if side == -1 else ring.copy()
    if side == 1:
        scene.collection.objects.link(ring)
    ring.location = (0, side * 0.11, 0)
    ring.data.materials.append(rim_mat) if not ring.data.materials else None
    ring.parent = pivot

for side in (-1, 1):
    bpy.ops.object.text_add(location=(0, side * 0.1, 0))
    t = bpy.context.object
    t.data.body = "$"
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.size = 1.3
    t.data.extrude = 0.06
    t.data.bevel_depth = 0.015
    t.rotation_euler = (math.pi / 2, 0, 0 if side == -1 else math.pi)
    t.data.materials.append(sign_mat)
    t.parent = pivot

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.5
cam = bpy.data.objects.new("Cam", cam_data)
cam.location = (0, -6, 0)
cam.rotation_euler = (math.pi / 2, 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam

for loc, energy in (((-3, -4, 4), 900), ((4, -3, -1), 300)):
    ld = bpy.data.lights.new("L", "AREA")
    ld.energy = energy
    ld.size = 3
    lo = bpy.data.objects.new("L", ld)
    lo.location = loc
    lo.rotation_euler = (math.atan2(math.hypot(loc[0], loc[1]), -loc[2]) * 0 + math.pi / 2.6, 0, math.atan2(loc[0], -loc[1]))
    scene.collection.objects.link(lo)

frames = []
for f in range(16):
    pivot.rotation_euler = (0.18, 0, f / 16 * math.pi)  # half a turn: both faces match, so it loops
    path = os.path.join(TMP, f"coin_{f:02d}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(256, 256, 4)[::-1]  # Blender stores bottom-up
    frames.append(px)
    bpy.data.images.remove(img)

rows = [np.concatenate(frames[r * 4 : (r + 1) * 4], axis=1) for r in range(4)]
sheet = np.concatenate(rows, axis=0)
img = bpy.data.images.new("coin_sheet", 1024, 1024, alpha=True)
img.pixels = sheet[::-1].ravel().tolist()
img.filepath_raw = os.path.join(OUT, "coin_sheet.png")
img.file_format = "PNG"
img.save()
print("wrote coin_sheet")
