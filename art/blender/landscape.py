"""Original landscape kit: granite bridge, native woodland and shoreline props.

blender -b -t 4 --python art/blender/landscape.py [-- asset_name ...]
The bridge deck is at Z=.04; its foundation is at Z=-1.55. All other
assets have their origin at ground level. Sources retain separate pieces.
"""
import math
import sys
from pathlib import Path
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, beam, render, mesh, mat, sphere
from environment import faceted_crown
from variation import CANONICAL

def tree_pine(variation=CANONICAL):
    v = variation
    h = v.factor("height","height")
    dx,dy = v.offset("trunk.x","lean"),v.offset("trunk.y","lean")
    beam("Maritime pine trunk",(0,0,0),(.12+dx,.04+dy,2.04*h),
         .105*v.factor("trunk.radius","trunk"),"wood_light")
    for i,(x,y,z,r) in enumerate([(-.38,.05,1.80,.59),(.44,.12,2.02,.67),(.07,-.34,2.20,.66)]):
        x,y,z,r = v.lobe(f"pine.{i}",x,y,z,r)
        beam("High spreading pine branch",(.06+dx*.6,dy*.6,1.25*h),(x,y,z),
             .053*v.factor(f"branch.{i}","trunk"),"wood")
        faceted_crown("Umbrella of pine needles",
            [(z-.22,r*.48,x,y),(z,r,x,y),(z+.33,r*.83,x-.03,y),
             (z+.52,r*.30,x+.05,y)],8,"leaf_forest" if i==0 else "green",i*.3,.075+v.offset(f"facets.{i}","facets"))


def rock_cluster(variation=CANONICAL):
    v = variation
    for i,(x,y,z,s) in enumerate([(-.18,.04,.22,(.43,.35,.35)),(.23,.14,.17,(.30,.29,.26)),(.07,-.25,.08,(.24,.17,.15))]):
        x += v.offset(f"rock.{i}.x","spread")
        y += v.offset(f"rock.{i}.y","spread")
        s = tuple(size*v.factor(f"rock.{i}.scale.{axis}","rock") for axis,size in enumerate(s))
        obj = sphere("Weathered granite boulder",(x,y,z),s,"stone" if i==0 else "stone_light")
        obj.rotation_euler = (.13*i,.25,.4*i)
        obj.data.materials.append(mat("stone_dark"))
        for p in obj.data.polygons:
            if p.normal.z < -.1: p.material_index = 1
        if v.parameters:
            # Moss lives on existing upper faces: no detached caps or new materials.
            obj.data.materials.append(mat("moss"))
            for face in obj.data.polygons:
                if face.normal.z > .25 and v.unit(f"moss.{i}.{face.index}") < v.parameters.get("moss",0):
                    face.material_index = 2
    if not v.parameters:
        sphere("Moss on sheltered stone",(-.22,.03,.47),(.24,.21,.045),"moss")


def grass_clump():
    for i in range(9):
        a = i*2.4
        x,y = math.cos(a)*.13,math.sin(a)*.13
        h = .17+(i%4)*.043
        mesh("Broad folded grass blade",[(x-.025,y,0),(x+.025,y,0),
            (x+.02,y+.01,h*.55),(x+math.cos(a)*.12,y+math.sin(a)*.1,h)],
            [(0,1,2),(0,2,3),(2,1,3)],"green" if i%3 else "leaf_olive")


def wildflowers():
    grass_clump()
    for i in range(5):
        x,y = math.cos(i*2.4)*.20,math.sin(i*2.4)*.20
        h = .21+(i%3)*.055
        beam("Meadow flower stem",(x,y,0),(x+.02,y,h),.012,"green")
        cylinder("Small buttercup",(x+.02,y,h),.048,.035,"flower_light",5)


def reeds():
    for i in range(8):
        x,y = math.cos(i*2.4)*.22,math.sin(i*2.4)*.22
        h = .46+(i%4)*.11
        beam("Reed stem",(x,y,0),(x+.07,y,h),.014,"leaf_olive")
        if i%2: cylinder("Brown reed head",(x+.07,y,h-.035),.030,.14,"wood",6)
        mesh("Bent reed leaf",[(x-.022,y,.06),(x+.022,y,.06),(x+.14,y+.08,h*.67),
            (x+.28,y+.14,h*.51)],[(0,1,2),(0,2,3),(2,1,3)],"green")


def gorse(variation=CANONICAL):
    v = variation
    for i,(x,y,z,r) in enumerate([(-.14,0,.20,.32),(.20,.08,.23,.28),(0,-.16,.15,.24)]):
        x,y,z,r = v.lobe(f"gorse.{i}",x,y,z,r)
        faceted_crown("Low gorse bush",[(.02,r*.5,x,y),(z,r,x,y),(z+.22,r*.35,x,y)],
            6,"green" if i%2 else "leaf_forest",i*.5,.075+v.offset(f"facets.{i}","facets"))
        for j in range(3):
            a = j*2.4+i
            sphere("Golden gorse blossom",(x+math.cos(a)*r*.52,y+math.sin(a)*r*.52,z+.17),(.055,.055,.045),"grain_light")


def bridge_stone(variation=CANONICAL):
    # Four full barrel arches. Blocks remain separate in the editable source.
    for center in [-3.75,-1.25,1.25,3.75]:
        for i in range(11):
            a,b = i*math.pi/11+.009,(i+1)*math.pi/11-.009
            inner,outer,spring = .99,1.22,-1.20
            profile = [(center+math.cos(t)*r,spring+math.sin(t)*r)
                       for r,t in [(inner,a),(inner,b),(outer,b),(outer,a)]]
            vertices = [(x,y,z) for x in [-.96,.96] for y,z in profile]
            mesh("Granite arch voussoir",vertices,[(0,3,2,1),(4,5,6,7),
                 (0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
                 ["stone_light","stone","stone_dark"][i%3])
            # Fill above the curve, preserving the open arch underneath.
            ya,za = profile[3]
            yb,zb = profile[2]
            vertices = [(x,y,z) for x in [-.92,.92] for y,z in [(ya,za),(yb,zb),(yb,.035),(ya,.035)]]
            mesh("Stone above the arch",vertices,[(0,3,2,1),(4,5,6,7),
                 (0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],"stone")
    for y in [-5,-2.5,0,2.5,5]:
        width = .25 if abs(y)==5 else .50
        cy = y-math.copysign(.125,y) if abs(y)==5 else y
        box("Bridge pier",(0,cy,-.78),(1.94,width,1.54),"stone_wet",.022)
        if abs(y)<5:
            for side in [-1,1]:
                mesh("Pointed river cutwater",[(side*.94,y-.28,-1.55),(side*.94,y+.28,-1.55),
                    (side*1.32,y,-1.55),(side*.94,y-.28,-.45),(side*.94,y+.28,-.45),(side*1.32,y,-.67)],
                    [(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],"stone_wet")
    box("Continuous paved deck",(0,0,.025),(1.94,10,.05),"stone_wet",.008)
    for row in range(25):
        for col in range(4):
            box("Broad worn paving slab",(-.69+col*.46,-4.8+row*.4,.052),
                (.445,.385,.034),"stone" if (row+col)%4 else "stone_wet",.009)
    for side in [-1,1]:
        for row in range(2):
            for i in range(20):
                box("Parapet masonry course",(side*.91,-4.75+i*.5,.17+row*.20),
                    (.22,.485,.19),"stone" if (i+row)%3 else "stone_light",.012)
        for i in range(20):
            box("Chamfered parapet cap",(side*.91,-4.75+i*.5,.495),(.29,.49,.085),"stone_light",.018)

    if variation.parameters:
        # Only face finishes change. Deck, arches, piers, footprint and all vertices
        # remain identical to the canonical bridge (including bevel modifiers).
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH": continue
            base = obj.data.materials[0].name
            obj.data.materials.append(mat("moss"))
            finish = "stone_wet" if base == "stone_wet" else ("stone" if base == "stone_light" else "stone_dark")
            obj.data.materials.append(mat(finish))
            for face in obj.data.polygons:
                key = f"{obj.name}.{face.index}"
                if "paving" not in obj.name and "deck" not in obj.name and face.normal.z < .5 and variation.unit("moss."+key) < variation.parameters.get("moss",0):
                    face.material_index = 1
                elif variation.unit("stone."+key) < variation.parameters.get("stone",0):
                    face.material_index = 2


BUILDERS = {"tree_pine":tree_pine,"rock_cluster":rock_cluster,"grass_clump":grass_clump,
            "wildflowers":wildflowers,"reeds":reeds,"gorse":gorse,"bridge_stone":bridge_stone}
if __name__ == "__main__":
    requested = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,512,export_model=True)
