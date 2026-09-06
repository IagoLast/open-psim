"""Original low-poly town scenery, boats and a citizen, authored in Blender.

blender -b -t 4 --python art/blender/environment.py [-- asset_name ...]
Origins are at ground/water level; front is -Y. Citizen limb origins are
shoulders/hips, so the game can animate the exported mesh nodes directly.
"""
import math
import sys
from pathlib import Path
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, beam, render, mesh, mat
from buildings import roof
from variation import CANONICAL


def faceted_crown(name, rings, sides, material, phase=0, variation=.075):
    """Few broad irregular planes rather than layered cones or sphere clusters."""
    vertices = []
    for ring_index, (z, radius, dx, dy) in enumerate(rings):
        for i in range(sides):
            angle = phase + i * math.tau / sides
            irregular = 1 + variation * math.sin(i * 2.7 + ring_index * 1.1)
            vertices.append((dx + math.cos(angle) * radius * irregular,
                             dy + math.sin(angle) * radius * irregular, z))
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(rings)-1):
        for i in range(sides):
            a, b = j*sides+i, j*sides+(i+1)%sides
            c, d = (j+1)*sides+(i+1)%sides, (j+1)*sides+i
            if j == 1 and i % 2 == 0:
                faces.extend([(a,b,d),(b,c,d)])
            else:
                faces.append((a,b,c,d))
    faces.append(tuple(range((len(rings)-1)*sides,len(rings)*sides)))
    return mesh(name, vertices, faces, material)


def hull(length, width, height):
    # A thick open shell, with broad wooden planes and a pointed bow.
    profile = [(0,-.52),(.30,-.41),(.47,-.22),(.50,.13),(.37,.39),(.20,.48),
               (-.20,.48),(-.37,.39),(-.50,.13),(-.47,-.22),(-.30,-.41)]
    n = len(profile)
    vertices = [(x*width*.57,y*length*.83,.025) for x,y in profile]
    vertices += [(x*width,y*length,height+(.10 if abs(y)>.38 else 0)) for x,y in profile]
    vertices += [(x*width*.85,y*length*.93,height-.035+(.10 if abs(y)>.38 else 0)) for x,y in profile]
    vertices += [(x*width*.51,y*length*.79,.105) for x,y in profile]
    faces = [tuple(reversed(range(n)))]
    for ring in range(3):
        for i in range(n):
            j = (i+1) % n
            faces.append((ring*n+i,ring*n+j,(ring+1)*n+j,(ring+1)*n+i))
    faces.append(tuple(range(3*n,4*n)))
    boat = mesh("Carved open wooden hull",vertices,faces,"wood_light")
    boat.data.materials.append(mat("wood"))
    for polygon in boat.data.polygons:
        if polygon.index in [2,5,8,10]:
            polygon.material_index = 1
    for i in range(n):
        j = (i+1) % n
        beam("Rounded gunwale",vertices[n+i],vertices[n+j],.024,"wood_light")
    for yy in [-.20,.19]:
        box("Broad rowing bench",(0,yy*length,height-.06),(width*.79,.13,.06),"wood_light",.006)
    box("Keel floorboard",(0,0,.12),(width*.30,length*.64,.035),"wood_light",.005)


def sailboat():
    hull(2.72,1.16,.35)
    beam("Single wooden mast",(0,.29,.13),(0,.29,2.54),.045,"wood")
    beam("Sloping lateen yard",(0,-1.19,.72),(0,.73,2.58),.027,"wood_light")
    # A single triangular lateen sail. A shallow belly yields broad facets.
    sail = mesh("Ivory triangular lateen sail",
                [(.065,-1.10,.75),(.065,.69,2.49),(.065,.95,.56),(.19,.18,1.21)],
                [(0,1,3),(1,2,3),(2,0,3)],"canvas")
    solid = sail.modifiers.new("Cloth thickness","SOLIDIFY")
    solid.thickness = .014
    beam("Short mainsheet",(0,.94,.57),(0,1.10,.38),.009,"ground")
    box("Small stern deck",(0,1.02,.41),(.48,.34,.055),"wood_light",.009)
    box("Rudder",(0,1.35,.20),(.07,.17,.37),"wood",.009)
    beam("Tiller",(0,1.37,.44),(0,.83,.48),.022,"wood")


def rowboat():
    hull(2.05,.92,.29)
    for sign in [-1,1]:
        beam("Resting oar",(sign*.08,-.39,.36),(sign*.70,.49,.38),.019,"wood_light")
        paddle = box("Broad oar blade",(sign*.77,.59,.38),(.12,.30,.034),"wood_light",.008)
        paddle.rotation_euler.z = -sign*.61


def tree_oak(variation=CANONICAL):
    v = variation
    h = v.factor("height", "height")
    lean = (v.offset("trunk.x", "lean"), v.offset("trunk.y", "lean"))
    beam("Leaning oak trunk",(0,0,0),(.06+lean[0],.02+lean[1],1.26*h),
         .12*v.factor("trunk.radius", "trunk"),"wood")
    for i,(x,y,z,r) in enumerate([(-.36,.02,1.48,.53),(.34,.16,1.67,.57),
                                 (.06,-.32,1.53,.49),(-.04,.02,2.02,.52)]):
        x,y,z,r = v.lobe(f"oak.{i}",x,y,z,r)
        if i < 3:
            end = (x,y,z-.12) if v.parameters else [(-.44,.03,1.36),(.43,.18,1.57),(.08,-.35,1.40)][i]
            beam("Visible fork",(.04+lean[0]*.55,.02+lean[1]*.55,.69*h),
                 end,.062*v.factor(f"branch.{i}","trunk"),"wood_light")
        crown = faceted_crown("Broad lobed oak canopy",
            [(z-r*.65,r*.40,x,y),(z-r*.22,r,x-.025,y),
             (z+r*.40,r*.84,x+.03,y),(z+r*.78,r*.26,x-.07,y)],
            7,"leaf_olive" if i%2 else "green",i*.7,.10+v.offset(f"facets.{i}","facets"))
        crown.data.materials.append(mat("leaf_sage"))
        for p in crown.data.polygons:
            if p.normal.z > .3 and p.index%3 == 0: p.material_index = 1
    for i in range(5):
        a = i*math.tau/5
        beam("Exposed buttress root",(0,0,.18),(.25*math.cos(a),.25*math.sin(a),.025),.045,"wood")


def tree_cypress(variation=CANONICAL):
    v = variation
    h = v.factor("height", "height")
    dx,dy = v.offset("trunk.x","lean"),v.offset("trunk.y","lean")
    if v.parameters:
        beam("Cypress trunk",(0,0,0),(dx,dy,.84*h),.085*v.factor("trunk.radius","trunk"),"wood_light")
    else:
        cylinder("Cypress trunk",(0,0,.42),.085,.84,"wood_light",7)
    for i,(z,r,length) in enumerate([(.48,.37,1.20),(.95,.32,1.21),(1.52,.23,1.19)]):
        x,y,z,r = v.lobe(f"cypress.{i}",dx,dy,z,r)
        length *= h
        if v.parameters:
            for side in [-1,1]:
                beam("Short cypress branch",(dx*.7,dy*.7,z*.75),
                     (x+side*r*.60,y,z+.16),.025*v.factor(f"branch.{i}","trunk"),"wood_light")
        crown = faceted_crown("Overlapping cypress foliage",
            [(z,r*.6,x,y),(z+.16,r,x+.02,y),(z+length*.55,r*.61,x-.015,y),
             (z+length,.012,x+.025,y)],7,"leaf_forest" if i!=1 else "green",i*.4,
             .075+v.offset(f"facets.{i}","facets"))
        crown.data.materials.append(mat("leaf_olive"))
        for p in crown.data.polygons:
            if p.index%7 == 3: p.material_index = 1


def crate(x,y,z=.11,size=.43):
    box("Crate body",(x,y,z+size/2),(size,size,size),"wood",.008)
    for side in [-1,1]:
        for offset in [-.30,.30]:
            box("Crate horizontal boards",(x,y+side*(size/2+.007),z+size*(.5+offset)),
                (size+.025,.035,size*.15),"wood_light",.003)
            box("Crate side boards",(x+side*(size/2+.007),y,z+size*(.5+offset)),
                (.035,size+.025,size*.15),"wood_light",.003)
    brace = box("Crate diagonal brace",(x,y-size/2-.03,z+size/2),
                (size*1.02,.033,size*.105),"wood_light",.003)
    brace.rotation_euler.y = -.68
    for offset in [-.25,0,.25]:
        box("Crate lid board",(x+offset*size,y,z+size+.012),(size*.23,size,.025),"wood_light",.003)


def barrel(x,y,z=.10,r=.18,h=.38):
    sides = 10
    vertices = [(x+math.cos(i*math.tau/sides)*radius,
                 y+math.sin(i*math.tau/sides)*radius,height)
                for height,radius in [(z,r*.85),(z+h*.22,r),(z+h*.75,r),(z+h,r*.85)]
                for i in range(sides)]
    faces = [tuple(reversed(range(sides)))]
    for j in range(3):
        faces.extend([(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for i in range(sides)])
    mesh("Faceted barrel staves",vertices,faces,"wood_light")
    cylinder("Dark open barrel",(x,y,z+h-.05),r*.73,.016,"wood",sides)
    for zz in [z+h*.22,z+h*.76]:
        cylinder("Wooden barrel hoop",(x,y,zz),r+.008,.028,"wood",sides)
    # An open lip, not a solid disc concealing the opening.
    vertices = [(x+math.cos(i*math.tau/sides)*radius,y+math.sin(i*math.tau/sides)*radius,z+h)
                for radius in [r*.86,r*.70] for i in range(sides)]
    mesh("Open barrel rim",vertices,[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)],"wood_light")


def warehouse():
    box("Weathered granite warehouse base",(0,0,.055),(3.08,2.70,.11),"stone",.04)
    # The reference's storehouse is an open timber bay under a slate roof.
    for i in range(6):
        box("Back horizontal plank",(-.31,.88,.29+i*.23),(1.91,.075,.215),"wood_light",.004)
        box("Left horizontal plank",(-1.22,.10,.29+i*.23),(.075,1.61,.215),"wood_light",.004)
    for x in [-1.23,.63]:
        for y in [-.75,.94]:
            box("Heavy storehouse upright",(x,y,.97),(.14,.14,1.73),"wood",.008)
    box("Front crossbeam",(-.30,-.76,1.77),(2.02,.15,.17),"wood",.009)
    for side in [-1,1]:
        beam("Timber knee brace",(-.30+side*.83,-.76,1.46),(-.30+side*.49,-.76,1.78),.046,"wood_light")
    roof(-.30,.095,1.87,2.19,2.07,.68,"slate")
    # A low side bay, the brown lean-to in the asset sheet.
    for y in [-.75,.80]:
        box("Lean-to upright",(1.33,y,.57),(.10,.10,.92),"wood",.007)
    box("Lean-to rear boards",(1.00,.82,.59),(.78,.075,.95),"wood_light",.004)
    canopy = box("Timber lean-to roof",(1.02,.03,1.25),(.96,1.83,.09),"wood_light",.009)
    canopy.rotation_euler.y = .30
    for y in [-.53,-.06,.41]:
        seam = box("Lean-to plank seam",(1.02,y,1.298),(.96,.014,.013),"wood",.001)
        seam.rotation_euler.y = .30
    crate(-.84,-.49,size=.48)
    crate(-.78,.12,size=.44)
    crate(-.78,.12,z=.56,size=.35)
    crate(.96,-.38,size=.43)
    barrel(.30,-.99,r=.20,h=.41)


def pivot_mesh(name, objects, pivot):
    """Join a limb's pieces and place its exported origin at the joint."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        # Bake bevels before joining so the boot and hand keep their edges.
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    limb = bpy.context.object
    limb.name = name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = (0,0,0)
    return limb


def citizen():
    # Chunky hand-modelled proportions stay readable at the map's scale.
    cylinder("Linen neck",(0,0,.666),.052,.074,"skin",7)
    faceted_crown("Faceted head",
                  [(.672,.074,0,0),(.722,.109,0,0),(.811,.116,0,0),(.856,.093,0,0)],
                  8,"skin",math.pi/8)
    box("Simple nose",(0,-.107,.773),(.041,.051,.042),"skin",.012)
    faceted_crown("Cropped brown hair",
                  [(.804,.134,0,.003),(.862,.111,0,.008),(.899,.035,0,.008)],
                  8,"wood",math.pi/8,variation=0)
    # Front faces -Y; a quiet face avoids oversized black mascot eyes.
    for x in [-.039,.039]:
        box("Small eye",(x,-.110,.787),(.012,.009,.013),"dark",.002)
    vertices = [(x,y,z) for z,width,depth in [(.315,.15,.112),(.45,.12,.095),(.628,.155,.100)]
                for x,y in [(-width+.025,-depth),(width-.025,-depth),(width,-depth+.025),
                            (width,depth-.025),(width-.025,depth),(-width+.025,depth),
                            (-width,depth-.025),(-width,-depth+.025)]]
    mesh("Wool tunic",vertices,[tuple(reversed(range(8))),tuple(range(16,24))]+
         [(j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for j in range(2) for i in range(8)],"cloth")
    box("Leather belt",(0,0,.432),(.256,.204,.035),"wood",.005)
    box("Small belt clasp",(.026,-.108,.433),(.030,.018,.029),"gold",.003)
    for sign,label in [(-1,"L"),(1,"R")]:
        hip = (sign*.077,0,.344)
        leg = beam("Trouser leg",hip,(sign*.079,0,.105),.045,"cream")
        boot = box("Leather boot",(sign*.079,-.028,.052),(.100,.177,.100),"wood",.018)
        pivot_mesh("Leg"+label,[leg,boot],hip)
        shoulder = (sign*.173,0,.592)
        sleeve = beam("Short tunic sleeve",shoulder,(sign*.210,0,.455),.058,"cloth")
        forearm = beam("Bare forearm",(sign*.21,0,.468),(sign*.221,-.006,.356),.038,"skin")
        hand = box("Rounded hand",(sign*.222,-.007,.340),(.078,.077,.084),"skin",.022)
        pivot_mesh("Arm"+label,[sleeve,forearm,hand],shoulder)
    static_parts = [obj for obj in bpy.context.scene.objects
                    if obj.type == "MESH" and obj.name not in ["LegL","LegR","ArmL","ArmR"]]
    pivot_mesh("Body",static_parts,(0,0,0))


BUILDERS = {"sailboat":sailboat,"rowboat":rowboat,"tree_oak":tree_oak,
            "tree_cypress":tree_cypress,"warehouse":warehouse,"citizen":citizen}
if __name__ == "__main__":
    requested = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,512,export_model=True)
