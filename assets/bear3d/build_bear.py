"""Build the ChinGo bear as a rigged 3D model, from nothing, every time.

Run headless:

    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python assets/bear3d/build_bear.py

The model is a *script* rather than a .blend, and that is the whole point. A binary somebody
nudged by hand in a GUI cannot be diffed, cannot be reviewed, and cannot be regenerated when
the ears turn out to be too small — you get one more binary. This can be re-run with a number
changed, and the change shows up in a pull request as the number.

## What it is modelling

`assets/logo/mascot.png`, in three dimensions. The proportions are read off that drawing and
they are deliberately extreme: the head is nearly as wide as the bear is tall, the limbs are
stubs with no joints in them, and there is no neck. That reads at the size the map actually
draws a bear — about sixty points — where anything closer to real bear proportions turns into
a brown smudge.

The reference is a *sitting* bear. This one stands, because it has to walk. Everything else is
kept: the two-tone body, the cream muzzle and belly, the round ears with cream inners.

## Three materials, and why it is three

`Body` is the only one that changes colour. The app has eight accents and recolours the bear
per player, so the body is its own material slot and the runtime replaces one colour on it —
rather than shipping eight models, or tinting the whole thing and turning the cream grey.
`Cream` and `Ink` never change.
"""

import bpy
import math
import os
from mathutils import Vector

# ---------------------------------------------------------------------------
# Proportions, in metres, with the bear standing on z = 0.
#
# Measured off the reference drawing rather than invented: the head is 62% of the total width
# and sits directly on the body with no neck between them, which is what makes it read as the
# same character rather than as a generic teddy.
# ---------------------------------------------------------------------------

TOTAL_HEIGHT = 1.00

# The head is *wider than the body*, which is the single measurement that decides whether this
# reads as the mascot or as a generic teddy. On the reference drawing the head spans 95% of the
# image width and the body 88%, and the first pass here had it the other way round -- the render
# came out looking like a gummy bear.
HEAD_R = 0.34
HEAD_SCALE = (1.0, 0.86, 0.86)
HEAD_Z = 0.70

BODY_R = 0.27
BODY_SCALE = (1.0, 0.85, 0.95)
BODY_Z = 0.33

# Ears sit on the head's top corners and are large. Small ears read as a mouse.
EAR_R = 0.14
EAR_X = 0.26
EAR_Z = 0.22          # above the head centre

MUZZLE = (0.165, 0.115, 0.12)
MUZZLE_Y = -0.245
MUZZLE_Z = 0.655
NOSE_R = 0.048
NOSE_Y = -0.335
EYE_R = 0.040
EYE_X = 0.150
EYE_Y = -0.285
EYE_Z = 0.760

BELLY = (0.175, 0.09, 0.155)
BELLY_Y = -0.20
BELLY_Z = 0.31

ARM_R = 0.10
ARM_X = 0.295
ARM_Z = 0.36

LEG_R = 0.11
LEG_X = 0.145
LEG_Z = 0.105
PAW_Y = -0.105

SEGMENTS = 32          # smooth at sixty points on screen without paying for it
RINGS = 16


def reset_scene():
    """Empty file. Blender opens with a cube, a camera and a light in it."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, colour, roughness=0.62):
    """A flat-ish matte, because the reference art is flat.

    Roughness high and metallic zero: the drawing has one soft highlight and no specular
    hotspot, and a shiny bear on a flat green map would be the only object on the screen
    pretending to be lit by something real.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def blob(name, location, radius, scale=(1, 1, 1), mat=None):
    """One rounded lump.

    Everything here is a scaled sphere. That is not laziness — the character is drawn from
    overlapping circles, and building it from anything with an edge in it would be a different
    bear. Shade-smooth plus a subdivision at the end welds the overlaps into one form.
    """
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, location=location, segments=SEGMENTS, ring_count=RINGS
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.shade_smooth()
    if mat:
        obj.data.materials.append(mat)
    return obj


def build_mesh(body_mat, cream_mat, ink_mat):
    """Every lump, in one mesh with three material slots."""
    parts = []

    parts.append(blob("Body", (0, 0, BODY_Z), BODY_R, BODY_SCALE, body_mat))
    parts.append(blob("Head", (0, 0, HEAD_Z), HEAD_R, HEAD_SCALE, body_mat))

    for side, tag in ((-1, "L"), (1, "R")):
        parts.append(blob(f"Ear{tag}", (side * EAR_X, 0, HEAD_Z + EAR_Z),
                          EAR_R, (1.0, 0.72, 1.0), body_mat))
        # The cream inner, pushed forward so it reads from the front and not from the side.
        # Forward of the ear's own centre by most of its depth, not a nudge. At -0.05 the
        # inner sat inside the ear and never appeared in a single render angle -- a cream
        # sphere perfectly hidden by the berry one around it.
        parts.append(blob(f"EarInner{tag}", (side * EAR_X, -EAR_R * 0.5, HEAD_Z + EAR_Z),
                          EAR_R * 0.66, (1.0, 0.45, 1.0), cream_mat))
        parts.append(blob(f"Arm{tag}", (side * ARM_X, 0, ARM_Z),
                          ARM_R, (1.0, 0.85, 1.3), body_mat))
        parts.append(blob(f"Leg{tag}", (side * LEG_X, 0, LEG_Z),
                          LEG_R, (1.0, 1.2, 0.9), body_mat))
        # Paw pad on the front of the foot, the way the drawing has it.
        # Same fault as the ear inners, same fix: pushed out past the leg's own front face.
        parts.append(blob(f"Paw{tag}", (side * LEG_X, PAW_Y, LEG_Z),
                          LEG_R * 0.66, (1.0, 0.4, 0.85), cream_mat))
        parts.append(blob(f"Eye{tag}", (side * EYE_X, EYE_Y, EYE_Z),
                          EYE_R, (1.0, 0.6, 1.3), ink_mat))

    parts.append(blob("Muzzle", (0, MUZZLE_Y, MUZZLE_Z), 1.0, MUZZLE, cream_mat))
    parts.append(blob("Nose", (0, NOSE_Y, MUZZLE_Z + 0.03), NOSE_R, (1.0, 0.72, 0.8), ink_mat))
    parts.append(blob("Belly", (0, BELLY_Y, BELLY_Z), 1.0, BELLY, cream_mat))

    # Join into one object. The slots survive, so the runtime still has a `Body` material to
    # tint without having to hunt through a hierarchy of separate meshes.
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()

    bear = bpy.context.active_object
    bear.name = "Bear"

    # One level of subdivision, not two. Two doubles the vertex count for a difference nobody
    # sees at sixty points, on a screen already drawing a tilted vector map.
    sub = bear.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    return bear


def build_armature(bear):
    """A skeleton with no joints in the limbs, because the character has none.

    Ten bones. The limbs rotate from where they meet the body and do not bend — a stub with an
    elbow in it stops looking like this drawing immediately. `root` exists so the whole bear can
    be moved without touching the pose, which is what the walk cycle's bob rides on.
    """
    bpy.ops.object.armature_add(location=(0, 0, 0))
    rig = bpy.context.active_object
    rig.name = "BearRig"
    rig.data.name = "BearArmature"

    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    bones.remove(bones[0])   # the default bone Blender adds

    def bone(name, head, tail, parent=None):
        b = bones.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if parent:
            b.parent = bones[parent]
        return b

    bone("root", (0, 0, 0), (0, 0, 0.1))
    bone("hips", (0, 0, LEG_Z + 0.05), (0, 0, BODY_Z), "root")
    bone("spine", (0, 0, BODY_Z), (0, 0, HEAD_Z - 0.12), "hips")
    bone("head", (0, 0, HEAD_Z - 0.12), (0, 0, HEAD_Z + 0.28), "spine")

    for side, tag in ((-1, "L"), (1, "R")):
        bone(f"ear.{tag}",
             (side * EAR_X, 0, HEAD_Z + 0.08),
             (side * EAR_X, 0, HEAD_Z + EAR_Z + EAR_R), "head")
        bone(f"arm.{tag}",
             (side * 0.20, 0, ARM_Z + 0.06),
             (side * ARM_X, 0, ARM_Z - 0.07), "spine")
        bone(f"leg.{tag}",
             (side * LEG_X, 0, LEG_Z + 0.13),
             (side * LEG_X, 0, 0.0), "hips")

    bpy.ops.object.mode_set(mode="OBJECT")

    # Automatic weights. The parts barely overlap and the limbs are separate lumps, so the
    # heat-map solver has an easy job here — hand-painting would be work with no visible result.
    bpy.ops.object.select_all(action="DESELECT")
    bear.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    return rig


def main():
    reset_scene()

    # Berry, cream and ink — the shipped mascot's own colours. The body is replaced per player
    # at runtime; this is what it looks like before anybody has chosen.
    body = material("Body", (0.478, 0.180, 0.322))
    cream = material("Cream", (0.988, 0.910, 0.749))
    ink = material("Ink", (0.110, 0.102, 0.086), roughness=0.45)

    bear = build_mesh(body, cream, ink)
    build_armature(bear)

    # Beside this script, not beside the .blend. `bpy.path.abspath("//")` resolves against the
    # open file, and on a run that started from an empty scene there is no open file -- so it
    # answered with nothing and the bear was quietly saved into /tmp.
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bear.blend")
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print(f"BUILT bear.blend  verts={len(bear.data.vertices)}  slots={len(bear.data.materials)}")


main()
