"""Pose the bear over time, and export one USDZ per clip.

    Blender --background bear.blend --python animate_bear.py -- walk

## One file per clip, not one file with everything in it

USD has no clean multi-clip concept that RealityKit reads back as a menu of named animations —
Blender's exporter writes a single `SkelAnimation` per file. Rather than fight that by packing
clips end to end on one timeline and asking the app to play sub-ranges by frame number (which
puts the timing in two places and lets them disagree), each clip is its own USDZ. RealityKit
loads the base model once and pulls animations off the others.

## The bear has no knees

`build_bear.py` gives the limbs one bone each, because the drawing has no joints in them. So
every clip here is rotation from where the limb meets the body, plus what the body itself does
— and that turns out to be most of what a chibi walk *is*. The weight is carried by the hip
bob and the head lag, not by articulation nobody can see at sixty points on screen.
"""

import bpy
import math
import os
import sys
from math import radians

RIG = "BearRig"


def rig():
    obj = bpy.data.objects[RIG]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="POSE")
    for bone in obj.pose.bones:
        bone.rotation_mode = "XYZ"
    return obj


def key(obj, frame, poses):
    """Set a pose at one frame and key exactly what was set.

    Keying only the channels a frame actually touches, rather than everything on every frame,
    is what lets the ears lag behind the head — a bone with no key at frame 6 interpolates
    through it, and that gap *is* the secondary motion.
    """
    for name, values in poses.items():
        bone = obj.pose.bones[name]
        if "rot" in values:
            bone.rotation_euler = [radians(a) for a in values["rot"]]
            bone.keyframe_insert("rotation_euler", frame=frame)
        if "loc" in values:
            bone.location = values["loc"]
            bone.keyframe_insert("location", frame=frame)


def curves(obj):
    """Every f-curve on the rig's action, across two incompatible Blender APIs.

    Blender 4.4 replaced actions-as-a-bag-of-curves with slotted actions, so `action.fcurves`
    is gone in 5.x and the curves live under layer → strip → channelbag(slot). Reaching for the
    old attribute raises rather than returning empty, so this has to branch rather than guess.
    """
    action = obj.animation_data.action
    if hasattr(action, "fcurves"):
        return list(action.fcurves)

    slot = obj.animation_data.action_slot
    found = []
    for layer in action.layers:
        for strip in layer.strips:
            bag = strip.channelbag(slot)
            if bag:
                found.extend(bag.fcurves)
    return found


def cyclic(obj):
    """Make every curve repeat, so the clip loops instead of playing once and stopping."""
    for curve in curves(obj):
        mod = curve.modifiers.new("CYCLES")
        mod.mode_before = "REPEAT_OFFSET"
        mod.mode_after = "REPEAT_OFFSET"


def clear(obj):
    if obj.animation_data:
        obj.animation_data_clear()
    for bone in obj.pose.bones:
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)


# ---------------------------------------------------------------------------
# The clips
# ---------------------------------------------------------------------------

def walk(obj):
    """Twenty-four frames, contact → passing → contact → passing.

    The classic four-pose walk, and the two things that make it read as weight rather than as
    legs swinging: the hips **dip on contact and rise through the passing pose**, which is
    twice per cycle rather than once — and the head keys a frame late, so a heavy head lags the
    body it is sitting on. Take either out and it becomes a toy being waggled.

    The arms counter-swing. A walk with arms in phase with the legs is how you walk when you
    are pretending to be a robot, and the eye catches it instantly without being able to say
    why.
    """
    swing, arm_swing = 24, 15
    dip, lift = -0.030, 0.012

    # contact L forward, passing, contact R forward, passing, back to the start
    poses = [
        (1,  swing, -swing, dip),
        (7,  0,      0,     lift),
        (13, -swing, swing, dip),
        (19, 0,      0,     lift),
        (25, swing, -swing, dip),
    ]
    for frame, left, right, bob in poses:
        key(obj, frame, {
            "leg.L": {"rot": (left, 0, 0)},
            "leg.R": {"rot": (right, 0, 0)},
            "arm.L": {"rot": (-left * arm_swing / swing, 0, 0)},
            "arm.R": {"rot": (-right * arm_swing / swing, 0, 0)},
            "hips":  {"loc": (0, bob, 0)},
            # Leaning into the walk. Small: past a few degrees a bear this round reads as
            # falling over rather than as walking.
            "spine": {"rot": (3.5, 0, 0)},
        })

    # The head and ears follow one frame behind everything else, which is the whole of the
    # secondary motion. Keyed on their own offset frames so they cross zero late.
    for frame, tilt in ((2, -2.5), (8, 1.5), (14, -2.5), (20, 1.5), (26, -2.5)):
        key(obj, frame, {
            "head": {"rot": (tilt, 0, 0)},
            "ear.L": {"rot": (tilt * 2.2, 0, 0)},
            "ear.R": {"rot": (tilt * 2.2, 0, 0)},
        })
    return 1, 24


def idle(obj):
    """Breathing, and nothing else.

    Long and shallow on purpose. `MascotOrb` already learned this in two dimensions: a static
    character reads as dead, and a busy one reads as a distraction sitting on top of a map.
    """
    for frame, rise, squash in ((1, 0, 0), (36, 0.012, -1.5), (72, 0, 0)):
        key(obj, frame, {
            "spine": {"rot": (squash, 0, 0), "loc": (0, rise, 0)},
            "head":  {"rot": (-squash * 0.6, 0, 0)},
            "ear.L": {"rot": (-squash * 1.4, 0, 0)},
            "ear.R": {"rot": (-squash * 1.4, 0, 0)},
        })
    return 1, 72


def sleep(obj):
    """Away, not sad.

    The distinction is the whole of `NEXT-STREAK-AND-PET.md`: Finch's bird goes off on its own
    adventures while you are gone and is pleased to see you back, and copying the moping is how
    a companion becomes a debt. So this is a slow deep breath with the head tipped and the ears
    dropped — asleep, which is a thing a bear does, rather than drooping, which is a thing a
    bear does *at* you.
    """
    for frame, breath in ((1, 0), (60, 0.018), (120, 0)):
        key(obj, frame, {
            "spine": {"rot": (-2, 0, 0), "loc": (0, breath, 0)},
            "head":  {"rot": (14, 0, 8)},
            "ear.L": {"rot": (18, 0, 0)},
            "ear.R": {"rot": (16, 0, 0)},
            "arm.L": {"rot": (-8, 0, 0)},
            "arm.R": {"rot": (-8, 0, 0)},
        })
    return 1, 120


def hug(obj):
    """Arms in, and a squash.

    Held rather than looping: the app drives this from a finger, so what matters is the shape
    at the end of it. `MascotOrb`'s two-dimensional version squashes to 0.88 and overshoots to
    1.18, and this is the same beat with arms on it.
    """
    key(obj, 1, {
        "arm.L": {"rot": (0, 0, 0)}, "arm.R": {"rot": (0, 0, 0)},
        "spine": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)},
    })
    key(obj, 8, {
        "arm.L": {"rot": (-52, 0, -34)}, "arm.R": {"rot": (-52, 0, 34)},
        "spine": {"rot": (7, 0, 0), "loc": (0, -0.022, 0)},
        "head":  {"rot": (-9, 0, 0)},
        "ear.L": {"rot": (-16, 0, 0)}, "ear.R": {"rot": (-16, 0, 0)},
    })
    return 1, 8


def catch(obj):
    """The one moment that gets the whole juice budget.

    Anticipate, impact, settle — the same three beats `RewardPhase` drives everything else
    with, so a catch in three dimensions and a catch in two are recognisably the same event.
    """
    key(obj, 1,  {"spine": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)}})
    key(obj, 5,  {"spine": {"rot": (11, 0, 0), "loc": (0, -0.035, 0)},
                  "head": {"rot": (9, 0, 0)},
                  "arm.L": {"rot": (16, 0, 0)}, "arm.R": {"rot": (16, 0, 0)}})
    key(obj, 12, {"spine": {"rot": (-9, 0, 0), "loc": (0, 0.055, 0)},
                  "head": {"rot": (-13, 0, 0)},
                  "arm.L": {"rot": (-62, 0, -20)}, "arm.R": {"rot": (-62, 0, 20)},
                  "ear.L": {"rot": (-26, 0, 0)}, "ear.R": {"rot": (-26, 0, 0)}})
    key(obj, 24, {"spine": {"rot": (0, 0, 0), "loc": (0, 0, 0)},
                  "head": {"rot": (0, 0, 0)},
                  "arm.L": {"rot": (0, 0, 0)}, "arm.R": {"rot": (0, 0, 0)},
                  "ear.L": {"rot": (0, 0, 0)}, "ear.R": {"rot": (0, 0, 0)}})
    return 1, 24


CLIPS = {"walk": (walk, True), "idle": (idle, True), "sleep": (sleep, True),
         "hug": (hug, False), "catch": (catch, False)}


def main():
    name = sys.argv[-1]
    if name not in CLIPS:
        raise SystemExit(f"unknown clip {name!r}; have {sorted(CLIPS)}")

    build, loops = CLIPS[name]
    obj = rig()
    clear(obj)
    start, end = build(obj)
    if loops:
        cyclic(obj)

    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = start, end
    bpy.ops.object.mode_set(mode="OBJECT")

    here = os.path.dirname(bpy.data.filepath)
    out = os.path.join(here, f"bear_{name}.usdz")
    bpy.ops.wm.usd_export(
        filepath=out,
        export_animation=True,
        export_armatures=True,
        export_materials=True,
        only_deform_bones=False,
        convert_orientation=True,
        export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z",
    )
    print(f"CLIP {name} frames={start}-{end} -> {out}")


main()
