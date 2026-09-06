"""Chunky low-poly resources, matching docs/references/asset-style-reference.png.

Run: blender --background --threads 4 --python art/blender/resources.py
Optional names after -- select assets. Importing never clears/renders a scene.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, sphere, beam, finish, mesh, render


def log(x, z, length=1.85, radius=.255, y=0):
    """An eight-sided log with clean, golden cut ends."""
    beam("Eight-sided chestnut bark", (x,y-length/2,z), (x,y+length/2,z), radius, "wood")
    for side in [-1,1]:
        end = y+side*(length/2+.007)
        beam("Pale freshly cut end", (x,end,z), (x,end+side*.013,z), radius*.81, "wood_end")


def wood():
    for x,z,length in [(-.27,.265,1.78),(.27,.265,1.87),(0,.71,1.81)]:
        log(x,z,length)


def corn_leaf(name, x,y,z, height, width, direction, material="corn_leaf", spread=.40):
    dx,dy=math.cos(direction),math.sin(direction)
    def point(out,side,up):
        return (x+out*dx-side*dy,y+out*dy+side*dx,z+up)
    verts=[point(0,0,0),point(spread*.45*height,-width,.40*height),
           point(spread*.75*height,0,.54*height),point(spread*.45*height,width,.40*height),
           point(spread*height,0,height)]
    obj=mesh(name,verts,[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],material)
    obj.modifiers.new("Leaf thickness","SOLIDIFY").thickness=.012
    return obj


def corn_cob(x=0,y=0,z=.12,scale=1,detailed=True):
    """Rounded chunky kernels and two broad husks, readable at 64 px."""
    cylinder("Golden corn cob",(x,y,z+.64*scale),.15*scale,.94*scale,"corn",10)
    if detailed:
        for row in range(9):
            taper=1-.45*(row/9)**3
            for col in range(8):
                a=col*math.tau/8+(row%2)*.035
                obj=box("Broad rounded corn kernel",(x+math.cos(a)*.165*scale*taper,
                        y+math.sin(a)*.165*scale*taper,z+(.25+row*.103)*scale),
                        (.11*scale,.105*scale,.106*scale),"grain_light" if (row+col)%5==0 else "corn",.026*scale)
                obj.rotation_euler.z=a
        sphere("Tapered corn tip",(x,y,z+1.16*scale),(.090*scale,.088*scale,.14*scale),"corn")
    else:
        sphere("Golden corn tip",(x,y,z+1.13*scale),(.125*scale,.125*scale,.16*scale),"corn")
        for row in range(4):
            for col in range(3):
                a=-math.pi/2+col*math.pi/3
                sphere("Readable field corn grains",(x+math.cos(a)*.17*scale,y+math.sin(a)*.17*scale,
                       z+(.36+row*.20)*scale),(.075*scale,.075*scale,.08*scale),"grain_light")
    for a,h in [(math.pi*1.16,1.10),(-.15,.85)]:
        corn_leaf("Two broad green corn husks",x,y,z,scale*h,.19*scale,a,spread=.59)


def corn_plant(x=0,y=0,z=.08,scale=1,detailed=False):
    beam("Green corn stalk",(x,y,z),(x,y,z+1.65*scale),.026*scale,"corn_leaf")
    corn_cob(x+.07*scale,y,z+.27*scale,scale*.80,detailed)
    for angle,base in [(0,.25),(2.8,.45),(-1.5,.70),(1.1,.72)]:
        corn_leaf("Broad agricultural corn leaf",x,y,z+base*scale,.97*scale,.22*scale,angle,spread=.76)
    for side in [-1,0,1]:
        beam("Golden corn tassel",(x,y,z+1.51*scale),(x+side*.1*scale,y,z+(1.73-abs(side)*.1)*scale),.017*scale,"grain")


def grain():
    # Runtime ID remains grain; the visible crop follows the supplied corn reference.
    corn_cob()


def extruded_profile(name, profile, thickness, material, transform=None):
    vertices = [(x,y,z) for y in [-thickness/2,thickness/2] for x,z in profile]
    if transform:
        vertices = [transform(*v) for v in vertices]
    n = len(profile)
    faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vertices,faces,material)


def fish_shape(offset=(0,0,0), scale=1, dried=False, angle=math.pi/4):
    """Broad sardine profile with a pale head and a forked tail."""
    x,y,z = offset
    def point(a,b,c):
        return (x+scale*(a*math.cos(angle)-b*math.sin(angle)),
                y+scale*(a*math.sin(angle)+b*math.cos(angle)),z+c*scale)

    rings = [(-.92,.085,.15),(-.66,.235,.37),(-.29,.27,.40),
             (.28,.205,.29),(.61,.06,.065)]
    if dried:
        rings = [(xx,depth*.68,height*.70) for xx,depth,height in rings]
    vertices = [(xx,depth*math.cos(i*math.tau/8),.57+height*math.sin(i*math.tau/8))
                for xx,depth,height in rings for i in range(8)]
    faces = [tuple(range(7,-1,-1))]
    face_materials = [1]
    for ring in range(len(rings)-1):
        for i in range(8):
            faces.append((ring*8+i,ring*8+(i+1)%8,
                          (ring+1)*8+(i+1)%8,(ring+1)*8+i))
            face_materials.append(1 if ring < 2 else (2 if i in [0,1,2,3] else 0))
    faces.append(tuple(range(32,40)))
    face_materials.append(0)
    body = mesh("Broad faceted sardine",[point(*v) for v in vertices],faces,
                "salt_shadow" if dried else "fish")
    finish(body,"salt" if dried else "fish_light")
    finish(body,"salt_shadow" if dried else "fish_dark")
    for polygon,index in zip(body.data.polygons,face_materials):
        polygon.material_index = index
    color = "salt_shadow" if dried else "fish_dark"
    tail = ([ (.55,.57),(1.02,.80),(.87,.57),(1.02,.34)] if dried else
            [(.55,.57),(1.02,.96),(.90,.58),(1.02,.19)])
    extruded_profile("Forked sardine tail",
                     tail,.065,color,point)
    extruded_profile("Tall angular dorsal fin",
                     [(-.22,.77),(.20,.91),(.29,.74)] if dried else
                     [(-.22,.88),(.20,1.05),(.29,.81)],.045,color,point)
    extruded_profile("Small ventral fin",
                     [(-.09,.32),(.16,.23),(.20,.37)],.09,color,point)
    eye = sphere("Single dark sardine eye",point(-.685,-.174,.60) if dried else point(-.685,-.226,.67),
                 (.043*scale,.027*scale,.043*scale),"dark")
    eye.rotation_euler.z = angle


def fish():
    fish_shape()


def salt():
    box("Square timber salt tray",(0,0,.075),(1.48,1.30,.15),"wood_light",.025)
    for x in [-.71,.71]:
        box("Salt tray side",(x,0,.17),(.095,1.3,.15),"wood_light",.008)
    for y in [-.60,.60]:
        box("Salt tray end",(0,y,.17),(1.35,.095,.15),"wood_light",.008)
    vertices = []
    for ring,radius,height in [(0,.64,.17),(1,.36,.55)]:
        for i in range(8):
            angle = i*math.tau/8
            r = radius*(1+[.03,-.07,.04,-.02,.05,-.04,.01,-.02][i])
            vertices.append((r*math.cos(angle),r*.91*math.sin(angle),
                             height+(0 if ring == 0 else [.02,-.03,.03,-.01,.02,-.03,.01,0][i])))
    vertices.append((-.07,.03,1.1))
    faces = [tuple(range(7,-1,-1))]
    for i in range(8):
        nxt = (i+1)%8
        faces += [(i,nxt,nxt+8),(i,nxt+8,i+8),(i+8,nxt+8,16)]
    mesh("Large crystalline salt mound",vertices,faces,"salt")


def salted_fish():
    box("Salt curing board",(0,0,.07),(1.82,1.18,.14),"wood_light",.025)
    for y in [-.55,.55]:
        box("Curing board rim",(0,y,.18),(1.82,.085,.15),"wood",.01)
    for y in [-.28,.25]:
        before = set(bpy.context.scene.objects)
        fish_shape(scale=.72,dried=True,angle=0)
        bpy.context.view_layer.update()
        for obj in set(bpy.context.scene.objects)-before:
            obj.matrix_world = (Matrix.Translation((-.02,y,.30))
                                @ Matrix.Rotation(-math.pi/2,4,"X")
                                @ Matrix.Translation((0,0,-.57*.72)) @ obj.matrix_world)
    for x,y in [(-.62,-.03),(-.33,.44),(.12,-.02),(.57,-.35),(.55,.35)]:
        crystal = box("Visible curing salt",(x,y,.22),(.075,.07,.06),"salt",0)
        crystal.rotation_euler.z = x*2


def coins():
    for x,y,count in [(-.38,.20,3),(.39,.21,2),(-.08,-.45,2)]:
        for index in range(count):
            z=.09+index*.155
            cylinder("Chunky gold coin",(x,y,z),.315,.145,"gold",20)
            cylinder("Inset gold face",(x,y,z+.075),.282,.008,"gold_light",20)


def population():
    for x,y,color in [(-.31,-.13,"green"),(.31,.17,"roof")]:
        cylinder("Simple faceless villager tunic",(x,y,.29),.25,.50,color,5)
        sphere("Faceted anonymous head",(x,y,.77),(.22,.20,.25),"skin")


def happiness():
    before = set(bpy.context.scene.objects)
    medal = cylinder("Golden satisfaction medallion",(0,0,.69),.64,.17,"gold",20)
    medal.rotation_euler.x = math.pi/2
    face = cylinder("Warm medallion face",(0,-.089,.69),.583,.015,"grain_light",20)
    face.rotation_euler.x = math.pi/2
    for x in [-.21,.21]:
        sphere("Friendly eye",(x,-.114,.84),(.051,.023,.069),"wood")
    points = [(.34*math.cos(math.radians(215+i*110/8)),-.117,
               .69+.34*math.sin(math.radians(215+i*110/8))) for i in range(9)]
    for a,b in zip(points,points[1:]):
        beam("Simple satisfied smile",a,b,.026,"wood")
    bpy.context.view_layer.update()
    for obj in set(bpy.context.scene.objects)-before:
        obj.matrix_world = Matrix.Rotation(math.pi/4,4,"Z") @ obj.matrix_world


BUILDERS = {name:globals()[name] for name in
            ["grain","wood","fish","salt","salted_fish","coins","population","happiness"]}

if __name__ == "__main__":
    requested = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,256,export_model=True)
