"""Export the built bear to USDZ, and render turnaround frames to look at it.

Separate from `build_bear.py` on purpose: building is slow and deterministic, looking at the
result is fast and happens twenty times an hour while the proportions are being argued with.
"""
import bpy, sys, os, math

out_dir = os.path.dirname(bpy.data.filepath) or "."
bpy.ops.wm.usd_export(
    filepath=os.path.join(out_dir, "bear.usdz"),
    export_animation=True,
    export_armatures=True,
    export_materials=True,
    only_deform_bones=False,
    # Y-up: what RealityKit expects. Blender is Z-up, and skipping this lands the bear on its
    # face in the app with everything else about the file perfectly correct.
    convert_orientation=True,
    export_global_up_selection="Y",
    export_global_forward_selection="NEGATIVE_Z",
)
print("EXPORTED", os.path.join(out_dir, "bear.usdz"))
