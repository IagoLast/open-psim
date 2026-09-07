"""San Francisco-inspired convent from the two user-supplied Pontevedra photos.

Stylised landmark, not a historical reconstruction. Front = -Y, up = Z.
Blender -b --threads 4 --python-exit-code 1 --python art/blender/convent.py
"""
import math
import random
import sys
from pathlib import Path
import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, sphere, beam, mesh, render
from buildings import plot, gable, slab, ring, window, shrub
from civic_buildings import bell


def stone_block(x, y, width, depth, height, bottom=.08):
    box("Convent warm granite wall", (x,y,bottom+height/2), (width,depth,height), "stone", .01)
    box("Weathered granite footing", (x,y,bottom+.07), (width+.035,depth+.035,.14), "stone_wet", .006)
    rng = random.Random(round(width*129+depth*311))
    # Thin, un-bevelled ashlar faces keep this large building within the mesh budget.
    for row in range(int(height/.25)):
        z = bottom+.15+row*.25
        for col in range(int(width/.31)):
            if rng.random() < .42:
                xx = x-width/2+.16+col*.31+(row%2)*.06
                if xx < x+width/2-.12:
                    box("Front ashlar face",(xx,y-depth/2-.008,z),(.25,.018,.20),rng.choice(["stone_light","masonry_warm","stone_dark"]),0)
        for col in range(int(depth/.31)):
            if rng.random() < .4:
                box("Side ashlar face",(x+width/2+.008,y-depth/2+.16+col*.31,z),(.018,.25,.20),rng.choice(["stone_light","stone","stone_dark"]),0)


def tiled_roof(x,y,z,width,depth,rise):
    # Broad low-poly clay tiles; the nave and long wings share the established palette.
    rows=max(3,round(width/.4)); cols=max(4,round(depth/.36))
    for side in [-1,1]:
        slab("Thick terracotta roof",[(x,y-depth/2,z+rise),(x+side*width/2,y-depth/2,z),
             (x+side*width/2,y+depth/2,z),(x,y+depth/2,z+rise)],.06,"roof_dark")
        for row in range(rows):
            u=row/rows; v=(row+1)/rows
            for col in range(cols):
                a=y-depth/2+col*depth/cols+.008; b=a+depth/cols-.016
                slab("Broad convent clay tile",[(x+side*width/2*u,a,z+rise*(1-u)+.024),
                     (x+side*width/2*v,a,z+rise*(1-v)+.035),
                     (x+side*width/2*v,b,z+rise*(1-v)+.035),
                     (x+side*width/2*u,b,z+rise*(1-u)+.024)],.022,"roof_light" if (row+col*3)%9==0 else "roof")
    for col in range(cols):
        beam("Convent segmented ridge",(x,y-depth/2+col*depth/cols,z+rise+.04),
             (x,y-depth/2+(col+1)*depth/cols-.015,z+rise+.04),.05,"roof_light")


def vertical_ring(name,x,y,z,outer,inner,depth=.04,material="stone_light",sides=32):
    obj=ring(name,0,0,0,outer,inner,depth,material,sides)
    obj.matrix_world=Matrix.Translation((x,y,z)) @ Matrix.Rotation(math.pi/2,4,"X")
    return obj


def rose_window(x,y,z):
    disc=cylinder("Deep circular rose window",(x,y-.01,z),.55,.026,"dark",40)
    disc.rotation_euler.x=math.pi/2
    vertical_ring("Outer carved rose moulding",x,y-.035,z,.63,.56,.065)
    vertical_ring("Inner concentric rose moulding",x,y-.10,z,.553,.506,.035,"stone",40)
    vertical_ring("Rose central oculus",x,y-.15,z,.115,.071,.025,"stone_light",16)
    for i in range(10):
        a=i*math.tau/10
        px=x+math.cos(a)*.34; pz=z+math.sin(a)*.34
        vertical_ring("Petal of stone tracery",px,y-.137,pz,.152,.118,.028,"stone_light",12)
        beam("Radial rose mullion",(x+math.cos(a)*.10,y-.15,z+math.sin(a)*.10),
             (x+math.cos(a)*.50,y-.15,z+math.sin(a)*.50),.018,"stone_light")


def portal(x,y,bottom,width,height):
    radius=width/2; spring=bottom+height-radius
    points=[(x-radius,y,bottom),(x+radius,y,bottom)]
    points += [(x+radius*math.cos(i*math.pi/16),y,spring+radius*math.sin(i*math.pi/16)) for i in range(17)]
    mesh("Arched oak door in deep recess",points,[tuple(range(len(points)))],"dark")
    for i in range(7):
        dx=-radius+(i+.5)*width/7
        top=spring+math.sqrt(max(0,radius*radius-dx*dx))-.025
        box("Dark oak arched door plank",(x+dx,y-.018,(bottom+top)/2),(width/7-.01,.026,top-bottom),"wood" if i%3==0 else "dark",0)
    for r in [radius+.04,radius+.13]:
        for side in [-1,1]:
            box("Carved portal jamb",(x+side*r,y-.045,(bottom+spring)/2),(.065,.13,spring-bottom),"stone_light",.004)
        for i in range(16):
            a=i*math.pi/16+.009; b=(i+1)*math.pi/16-.009
            verts=[(x+rr*math.cos(t),yy,spring+rr*math.sin(t))
                   for yy in [y-.025,y-.10] for rr in [r-.035,r+.035] for t in [a,b]]
            mesh("Arch cut granite voussoir",verts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],"stone_light" if i%3 else "stone_dark")
    for z in [bottom+.27,bottom+.62]:
        box("Convent door iron strap",(x,y-.04,z),(width*.84,.022,.035),"iron",0)


def convent():
    plot(5.86,4.86)
    # The long three-storey convent wing stands to the left of the church.
    stone_block(-1.30,-1.10,2.85,1.49,2.77)
    before=set(bpy.context.scene.objects)
    gable(0,0,2.85,1.49,2.85,.43)
    tiled_roof(0,0,2.85,1.66,3.02,.48)
    bpy.context.view_layer.update()
    transform=Matrix.Translation((-1.30,-1.10,0)) @ Matrix.Rotation(math.pi/2,4,"Z")
    for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world
    for z in [.57,1.39,2.22]:
        for x in [-2.42,-1.88,-1.34,-.80,-.26]:
            if z == .57 and x == -1.34: continue
            window(x,-1.853,z,width=.20,height=.40,shutters=False)
        for y in [-1.46,-.73]: window(.137,y,z,True,width=.19,height=.40,shutters=False)
    portal(-1.34,-1.858,.09,.37,.88)
    # Rear cloister wing, leaving an open, planted court beside the nave.
    stone_block(-1.23,1.72,2.66,.74,1.59)
    before=set(bpy.context.scene.objects)
    gable(0,0,1.67,.74,2.66,.27)
    tiled_roof(0,0,1.67,.89,2.80,.31)
    bpy.context.view_layer.update()
    transform=Matrix.Translation((-1.23,1.72,0)) @ Matrix.Rotation(math.pi/2,4,"Z")
    for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world
    for x in [-2.1,-1.53,-.96,-.39]: portal(x,1.337,.08,.27,1.03)
    stone_block(-2.33,.50,.69,1.88,1.59)
    gable(-2.33,.50,1.67,.69,1.88,.27)
    tiled_roof(-2.33,.50,1.67,.84,1.99,.31)
    box("Cloister herb garden",(-1.08,.56,.095),(1.11,1.04,.065),"earth",.01)
    for x,y in [(-1.37,.30),(-.79,.30),(-1.37,.83),(-.79,.83)]: shrub(x,y,z=.14,scale=.7)
    # High, simple church gable, rose window and concentric arched doorway.
    stone_block(1.50,.02,2.03,3.59,2.86)
    gable(1.50,.02,2.94,2.03,3.59,.63)
    tiled_roof(1.50,.10,2.95,2.17,3.52,.67)
    # Exposed granite parapet in front of the roof gives the facade its stone silhouette.
    gable(1.50,-1.82,2.94,2.21,.12,.73)
    rose_window(1.50,-1.80,2.38)
    portal(1.50,-1.80,.24,.73,1.19)
    for x in [.72,2.28]: portal(x,-1.80,.98,.15,.43)
    for x in [.49,2.51]:
        box("Facade buttress",(x,-1.72,1.34),(.22,.32,2.51),"stone_dark",.007)
        box("Buttress dressed cap",(x,-1.72,2.61),(.28,.37,.12),"stone_light",.006)
    for y in [-.97,.13,1.20]:
        box("Church lateral buttress",(2.54,y,1.17),(.29,.26,2.16),"stone",.007)
        window(2.533,y+.33,1.91,True,width=.18,height=.64,shutters=False)
    for i in range(3):
        box("Broad church steps",(1.50,-2.13+i*.12,.08+i*.065),(1.29,.48-i*.08,.10),"stone_dark",.012)
    box("Facade stone cross",(1.50,-1.82,3.84),(.061,.076,.39),"stone_light",.004)
    box("Facade cross arms",(1.50,-1.82,3.88),(.27,.076,.062),"stone_light",.004)
    # Lateral bell tower: actual open belfry, bell, cornices and faceted stone cupola.
    tx,ty=.24,-.95
    stone_block(tx,ty,.64,.72,3.13)
    box("Belfry lower cornice",(tx,ty,3.25),(.87,.91,.13),"stone_light",.009)
    for dx in [-.26,.26]:
        for dy in [-.30,.30]: box("Open belfry stone pier",(tx+dx,ty+dy,3.67),(.14,.14,.75),"stone",.005)
    bell(tx,ty,3.63,1.5)
    box("Belfry arch lintel",(tx,ty,4.07),(.80,.86,.14),"stone_light",.008)
    for dx in [-.32,.32]:
        for dy in [-.35,.35]:
            cylinder("Stone pinnacle foot",(tx+dx,ty+dy,4.19),.047,.14,"stone",8)
            sphere("Stone pinnacle",(tx+dx,ty+dy,4.29),(.07,.07,.095),"stone_light")
    dome=[]
    for z,r in [(4.14,.32),(4.28,.30),(4.42,.22),(4.50,.075)]:
        dome += [(tx+r*math.cos(i*math.tau/12),ty+r*math.sin(i*math.tau/12),z) for i in range(12)]
    mesh("Faceted granite cupola",dome,[(j*12+i,j*12+(i+1)%12,(j+1)*12+(i+1)%12,(j+1)*12+i) for j in range(3) for i in range(12)]+[tuple(range(36,48))],"stone_dark")
    beam("Belfry iron cross upright",(tx,ty,4.49),(tx,ty,4.85),.019,"iron")
    beam("Belfry iron cross arms",(tx-.10,ty,4.74),(tx+.10,ty,4.74),.017,"iron")
    for x,y in [(-2.68,1.96),(-2.68,-1.96),(2.70,1.93)]: shrub(x,y,scale=.7)
    # Repeated window details are only a few pixels in play; reserve bevels for
    # the landmark silhouette and carved facade instead of every tiny mullion.
    for obj in bpy.context.scene.objects:
        if obj.name.startswith(("Recessed upper return","Stone window sill","Slender window mullion")):
            for modifier in list(obj.modifiers): obj.modifiers.remove(modifier)


if __name__ == "__main__":
    reset()
    convent()
    render("convent",512,export_model=True)
