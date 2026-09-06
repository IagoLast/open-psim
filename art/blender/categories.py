"""Menu icons made from the same Blender geometry as the game collection.

Run: blender --background --threads 4 --python art/blender/categories.py
Optional names after -- select individual assets.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import reset, box, beam, render
from resources import wood, corn_cob, extruded_profile


def housing():
    from buildings import house_cottage
    house_cottage()


def services():
    from buildings import well
    well()


def food():
    box("Corn crate interior",(0,0,.13),(1.0,.76,.15),"wood",.01)
    for x in [-.48,.48]:
        for z in [.20,.38]: box("Corn crate end plank",(x,0,z),(.08,.81,.16),"wood_light",.007)
    for y in [-.38,.38]:
        for z in [.20,.38]: box("Corn crate side plank",(0,y,z),(1.04,.08,.16),"wood_honey",.007)
    for x,y,z in [(-.21,.13,.20),(.21,.17,.31),(0,-.15,.18)]:
        corn_cob(x,y,z,scale=.70)



def materials():
    wood()
    beam("Lumber axe handle",(.61,-.79,.12),(.45,-.12,1.14),.052,"wood_honey")
    head=box("Simple iron axe head",(.47,-.15,1.10),(.43,.12,.29),"iron",.018)
    head.rotation_euler.y=-.22
    blade=box("Broad saw blade",(.73,-.27,.57),(.17,.037,.78),"iron",.006)
    blade.rotation_euler.y=-.47



def select():
    outline = [(-.47,1.50),(.58,.70),(.18,.66),(.44,.12),
               (.15,0),(-.10,.55),(-.40,.28)]
    inset = [(-.375,1.31),(.36,.745),(.055,.71),(.315,.17),
             (.195,.115),(-.09,.68),(-.335,.47)]
    extruded_profile("Dark carved pointer edge",outline,.15,"wood")
    extruded_profile("Ivory pointer face",inset,.012,"cream",
                     lambda x,y,z:(x,y-.082,z))
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        obj.matrix_world = Matrix.Rotation(math.pi/4,4,"Z") @ obj.matrix_world


def demolish():
    beam("Mallet ash handle",(-.43,0,.12),(.34,0,1.08),.086,"wood_light")
    beam("Mallet dark grip",(-.43,0,.12),(-.21,0,.39),.098,"wood")
    head = box("Simple forged hammer head",(.34,0,1.1),(.69,.28,.28),"iron",.018)
    head.rotation_euler.y = .64
    band = box("Hammer handle socket",(.34,0,1.1),(.14,.294,.296),"iron_dark",.008)
    band.rotation_euler.y = .64
    bpy.context.view_layer.update()
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        obj.matrix_world = Matrix.Rotation(math.pi/4,4,"Z") @ obj.matrix_world


BUILDERS = {"category_housing":housing,"category_services":services,
            "category_food":food,"category_materials":materials,
            "select":select,"demolish":demolish}

if __name__ == "__main__":
    requested = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,256)
