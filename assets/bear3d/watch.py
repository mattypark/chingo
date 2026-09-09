"""Render a clip as a strip of frames, from the front and from the side.

    Blender --background bear.blend --python watch.py -- <clip> <out-dir>

The side view is the one that matters for a walk: whether the feet stay on the ground is
invisible from the front, and it is the failure that makes a character look like it is
skating rather than walking.
"""
import bpy, sys, os, math

args = sys.argv[sys.argv.index("--") + 1:]
clip, out = args[0], args[1]
os.makedirs(out, exist_ok=True)

# Re-apply the clip, then render its own frame range.
sys.argv = sys.argv[:1] + ["--", clip]
# Import the clip builders rather than re-running the exporter. `animate_bear.py` ends by
# writing a USDZ, and rendering frames does not want another one of those.
_src = open(os.path.join(os.path.dirname(bpy.data.filepath), "animate_bear.py")).read()
_src = _src[:_src.index("def main()")]
_ns = {}
exec(compile(_src, "animate_bear.py", "exec"), _ns)

_obj = _ns["rig"]()
_ns["clear"](_obj)
_start, _end = _ns["CLIPS"][clip][0](_obj)
if _ns["CLIPS"][clip][1]:
    _ns["cyclic"](_obj)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.scene.frame_start, bpy.context.scene.frame_end = _start, _end

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 220
scene.render.resolution_y = 280
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.93, 0.93, 0.92, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.35

for name, loc, energy, rot in (("Key", (2.4, -3.2, 3.0), 180, 38), ("Fill", (-2.6, -2.0, 1.2), 70, -50)):
    light = bpy.data.lights.new(name, "AREA"); light.energy = energy; light.size = 4.0
    o = bpy.data.objects.new(name, light); o.location = loc
    o.rotation_euler = (math.radians(58), 0, math.radians(rot))
    scene.collection.objects.link(o)

cam_data = bpy.data.cameras.new("Cam"); cam_data.lens = 70
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
scene.camera = cam

# A floor line, so "are the feet on the ground" is a question with a visible answer.
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
floor = bpy.context.active_object
mat = bpy.data.materials.new("Floor"); mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.80, 0.66, 1)
floor.data.materials.append(mat)

RADIUS, HEIGHT = 2.9, 0.55
for view, deg in (("front", 0), ("side", 90)):
    a = math.radians(deg)
    cam.location = (math.sin(a) * RADIUS, -math.cos(a) * RADIUS, HEIGHT)
    d = (cam.location[0], cam.location[1], cam.location[2] - 0.48)
    cam.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), d[2]), 0,
                          math.atan2(d[1], d[0]) + math.radians(90))
    for frame in range(scene.frame_start, scene.frame_end + 1):
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(out, f"{view}_{frame:03d}.png")
        bpy.ops.render.render(write_still=True)
print("WATCHED", clip, scene.frame_start, scene.frame_end)
