"""Render the bear from several angles into PNGs, so proportions can be argued with in seconds.

    Blender --background bear.blend --python look.py -- <out-dir>

`usdrecord` can draw a USDZ but it auto-frames a single camera and cannot orbit, which is
enough to tell you the bear exists and not enough to tell you the nose is buried inside the
muzzle. This puts a real camera on a ring around it and lights it flatly, which is roughly how
the app will light it anyway.
"""
import bpy, sys, math, os

out = sys.argv[-1] if "--" in sys.argv else "/tmp"
os.makedirs(out, exist_ok=True)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 380
scene.render.resolution_y = 460
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.93, 0.93, 0.92, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.35

# Flat key plus fill. The app's map has no dramatic lighting in it and a bear with a hard rim
# light would be the only object on screen claiming a sun that is not there.
# Energies deliberately low. The first pass ran at 900W and blew the berry body out to pale
# pink, which meant every colour judgement made against it was a judgement about the lighting.
for name, loc, energy in (("Key", (2.4, -3.2, 3.0), 180), ("Fill", (-2.6, -2.0, 1.2), 70)):
    light = bpy.data.lights.new(name, "AREA")
    light.energy = energy
    light.size = 4.0
    obj = bpy.data.objects.new(name, light)
    obj.location = loc
    obj.rotation_euler = (math.radians(58), 0, math.radians(38 if name == "Key" else -50))
    scene.collection.objects.link(obj)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 70            # long-ish, so the chibi proportions are not distorted further
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

RADIUS, HEIGHT = 3.1, 0.62
for name, deg in (("front", 0), ("quarter", 35), ("side", 90), ("back", 180)):
    a = math.radians(deg)
    # -Y is the bear's front, so zero degrees stands the camera there.
    cam.location = (math.sin(a) * RADIUS, -math.cos(a) * RADIUS, HEIGHT)
    direction = (cam.location[0], cam.location[1], cam.location[2] - 0.52)
    cam.rotation_euler = (
        math.atan2(math.hypot(direction[0], direction[1]), direction[2]),
        0,
        math.atan2(direction[1], direction[0]) + math.radians(90),
    )
    scene.render.filepath = os.path.join(out, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)
