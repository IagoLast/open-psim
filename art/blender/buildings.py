"""Editable miniature architecture based on the three supplied reference sheets.

Front = -Y, up = Z. Run Blender -b --python buildings.py -- house well ...
Tile seams, masonry, joinery and plants are geometry, shared by GLB and PNG.
"""
import math
import random
import sys
from pathlib import Path
import bpy
from mathutils import Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, sphere, beam, mesh, render, finish

FACES = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]


def slab(name, corners, thickness, material):
    return mesh(name, [(x,y,z-thickness) for x,y,z in corners]+corners, FACES, material)


def roof(x,y,z,width,depth,rise,material="roof"):
    """Overlapping individual clay tiles, subtle variations, segmented ridge caps."""
    clay = material == "roof"
    rows = max(3, round(math.hypot(width/2, rise)/.24))
    columns = max(4, round(depth/.28))
    for side in [-1,1]:
        corners=[(x,y-depth/2,z+rise),(x+side*width/2,y-depth/2,z),
                 (x+side*width/2,y+depth/2,z),(x,y+depth/2,z+rise)]
        slab("Terracotta eave thickness" if clay else "Timber roof thickness", corners,.06,
             "roof_dark" if clay else "wood")
        for row in range(rows):
            u0 = row/rows
            u1 = min(1,(row+1)/rows+.012)
            for col in range(columns):
                y0=y-depth/2+depth*col/columns+.004
                y1=y-depth/2+depth*(col+1)/columns-.004
                panel=[(x+side*width/2*u0,y0,z+rise*(1-u0)+.028),
                       (x+side*width/2*u1,y0,z+rise*(1-u1)+.037),
                       (x+side*width/2*u1,y1,z+rise*(1-u1)+.037),
                       (x+side*width/2*u0,y1,z+rise*(1-u0)+.028)]
                tone=("roof_light" if (row*7+col*3+side)%11<3 else "roof") if clay else material
                obj=slab("Individual overlapping clay tile" if clay else "Broad roof board",panel,.035,tone)
                bevel=obj.modifiers.new("Soft tile edges","BEVEL")
                bevel.width=.008; bevel.segments=1
                obj.modifiers.new("Tile face normals","WEIGHTED_NORMAL")
    if clay:
        for col in range(columns):
            beam("Segmented ridge cap",(x,y-depth/2+col*depth/columns+.004,z+rise+.037),
                 (x,y-depth/2+(col+1)*depth/columns-.004,z+rise+.037),.057,
                 "roof_light" if col%3==0 else "roof")


def gable(x,y,z,width,depth,rise):
    vertices=[(x-width/2,y-depth/2,z),(x+width/2,y-depth/2,z),(x,y-depth/2,z+rise),
              (x-width/2,y+depth/2,z),(x+width/2,y+depth/2,z),(x,y+depth/2,z+rise)]
    return mesh("Solid granite masonry gables",vertices,[(0,2,1),(3,4,5),(0,3,5,2),(1,2,5,4),(0,1,4,3)],"stone")


def ring(name,x,y,z,outer,inner,height,material="wood",sides=12):
    vertices=[(x+r*math.cos(i*math.tau/sides),y+r*math.sin(i*math.tau/sides),zz)
              for zz in [z,z+height] for r in [outer,inner] for i in range(sides)]
    faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces += [(i,j,2*sides+j,2*sides+i),
                  (sides+j,sides+i,3*sides+i,3*sides+j),
                  (2*sides+i,2*sides+j,3*sides+j,3*sides+i),
                  (j,i,sides+i,sides+j)]
    return mesh(name,vertices,faces,material)


def barrel(x,y,z=.08,r=.18,h=.38,filled=None):
    rings=[(r*.83,z),(r,z+h*.24),(r,z+h*.76),(r*.85,z+h)]
    for i in range(12):
        a=i*math.tau/12+.012; b=(i+1)*math.tau/12-.012
        verts=[(x+rr*math.cos(t),y+rr*math.sin(t),zz) for rr,zz in rings for t in [a,b]]
        mesh("Separate oak barrel stave",verts,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(3)],
             "wood_honey" if i%4==0 else "wood_light")
    for zz in [z+h*.20,z+h*.78]:
        ring("Barrel hoop",x,y,zz,r+.008,r-.013,h*.065,"wood",12)
    ring("Open wooden barrel lip",x,y,z+h-.014,r*.86,r*.71,.025,"wood_light",12)
    cylinder("Recessed barrel interior",(x,y,z+h*.78),r*.75,.012,"dark",12)
    if filled: cylinder("Barrel contents",(x,y,z+h*.94),r*.70,.014,filled,12)


def shrub(x,y,z=.07,scale=1):
    for dx,dy,h,w,tone in [(-.08,0,.17,.18,"leaf_olive"),(.065,.035,.27,.19,"green"),(.12,-.08,.12,.14,"leaf_sage")]:
        box("Angular foundation greenery",(x+dx*scale,y+dy*scale,z+h*scale/2),
            (w*scale,w*scale,h*scale),tone,.025*scale)


def tree(x,y,scale=1):
    cylinder("Cypress trunk",(x,y,.30*scale),.052*scale,.60*scale,"wood_light",7)
    verts=[]
    for z,r in [(.22,.12),(.40,.20),(.96,.17),(1.40,.10),(1.49,.025)]:
        verts += [(x+r*scale*math.cos(i*math.tau/7),y+r*scale*math.sin(i*math.tau/7),z*scale) for i in range(7)]
    mesh("Broad faceted cypress",verts,[tuple(range(6,-1,-1)),tuple(range(28,35))]+
         [(j*7+i,j*7+(i+1)%7,(j+1)*7+(i+1)%7,(j+1)*7+i) for j in range(4) for i in range(7)],"green")


def plot(width,depth,material="stone"):
    box("Muted stone and earth plot",(0,0,.027),(width,depth,.054),material,.025)
    for x,y,w,d,tone in [(-width*.35,-depth*.35,width*.29,depth*.22,"stone_light"),
                         (width*.30,depth*.35,width*.37,depth*.27,"earth"),
                         (-width*.38,depth*.29,width*.22,depth*.30,"moss")]:
        box("Quiet patch on miniature base",(x,y,.057),(w,d,.006),tone,0)


def masonry(x,y,width,depth,height,bottom=.065):
    box("Warm weathered granite walls",(x,y,bottom+height/2),(width,depth,height),"stone",.012)
    box("Damp granite plinth",(x,y,bottom+.065),(width+.008,depth+.008,.13),"stone_wet",.009)
    rng=random.Random(42+round(width*100))
    for side in [-1,1]:
        for row in range(max(2,round(height/.23))):
            zz=bottom+.11+row*.23
            for col in range(max(3,round(width/.25))):
                if rng.random()>.40: continue
                xx=x-width/2+.13+col*.25+(row%2)*.055
                if xx>x+width/2-.1: continue
                box("Subtle granite block face",(xx,y+side*(depth/2+.0015),zz),
                    (.18+rng.random()*.05,.009,.14+rng.random()*.035),
                    rng.choice(["stone_wet","stone_dark"] if row == 0 else ["masonry_warm","stone_light","stone"]),.003)
            for col in range(max(3,round(depth/.25))):
                if rng.random()>.38: continue
                yy=y-depth/2+.13+col*.25
                if yy>y+depth/2-.08: continue
                box("Subtle side masonry",(x+side*(width/2+.002),yy,zz),(.01,.21,.17),
                    rng.choice(["stone_wet","stone_dark"] if row == 0 else ["masonry_warm","stone_light","stone"]),.003)
        for xx in [x-width/2,x+width/2]:
            for row in range(2):
                box("Foundation corner stone",(xx,y+side*(depth/2-.08),bottom+.07+row*.145),
                    (.17,.18,.14),"stone" if row else "stone_wet",.006)


def window(x,y,z,side=False,flowers=False,shutters=True,width=.25,height=.34):
    before=set(bpy.context.scene.objects)
    box("Deep shadow in window",(0,-.006,0),(width,.04,height),"dark",.002)
    box("Cool glass in shadow",(-width*.14,-.029,.015),(width*.58,.009,height*.75),"fish_dark",0)
    box("Slender window mullion",(0,-.038,0),(.025,.018,height),"wood",.001)
    box("Recessed upper return",(0,-.021,height/2+.012),(width+.047,.056,.035),"stone",.002)
    box("Stone window sill",(0,-.045,-height/2-.02),(width+.08,.095,.045),"stone_light",.005)
    if shutters:
        box("Open wooden shutter",(width*.68,-.025,0),(width*.35,.042,height+.022),"wood",.003)
        box("Shutter plank",(width*.68+.014,-.049,0),(.025,.009,height*.91),"wood_light",.001)
    if flowers:
        box("Wooden flower box",(0,-.12,-height/2-.07),(width+.13,.19,.12),"wood_light",.005)
        for i in range(3):
            sphere("Window box leaves",(-width*.40+i*width*.4,-.13,-height/2+.003),(.075,.075,.065),"green")
            sphere("Small terracotta blossom",(-width*.40+i*width*.4,-.15,-height/2+.052),(.035,.034,.032),"flower" if i%2 else "flower_light")
    bpy.context.view_layer.update()
    transform=Matrix.Translation((x,y,z)) @ Matrix.Rotation(math.pi/2 if side else 0,4,"Z")
    for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world


def door(x,y,bottom=.08,height=.82,width=.36):
    box("Door opening shadow",(x,y,bottom+height/2),(width+.06,.035,height+.05),"dark",.002)
    for i in range(4):
        box("Individual door plank",(x-width/2+width*(i+.5)/4,y-.022,bottom+height/2),
            (width/4-.006,.026,height),"wood_light" if i==1 else "wood",.002)
    for z in [bottom+height*.23,bottom+height*.75]:
        box("Forged door hinge",(x-width*.27,y-.04,z),(width*.32,.013,.025),"iron",.002)
    sphere("Small bronze door latch",(x+width*.30,y-.052,bottom+height*.5),(.017,.014,.023),"wood_end")
    box("Worn stone doorstep",(x,y-.10,bottom-.013),(width+.10,.24,.045),"stone_light",.008)


def chimney(x,y,bottom,height=.62):
    box("Granite chimney shaft",(x,y,bottom+(height-.07)/2),(.25,.27,height-.07),"stone",.006)
    for level in range(3):
        z=bottom+height*(level+.5)/3
        box("Chimney block face",(x-.026,y-.138,z),(.19,.01,height/3-.008),"masonry_pale" if level%2 else "masonry_warm",.002)
        box("Chimney side block",(x+.128,y+.02,z),(.01,.21,height/3-.008),"stone_light" if level%2 else "stone_dark",.002)
    box("Dark open chimney interior",(x,y,bottom+height-.049),(.24,.26,.018),"dark",0)
    for dx,dy,w,d in [(-.134,0,.055,.32),(.134,0,.055,.32),(0,-.145,.23,.055),(0,.145,.23,.055)]:
        box("Open cut-stone chimney rim",(x+dx,y+dy,bottom+height+.023),(w,d,.065),"masonry_pale",.004)


def house_shell(x,y,width,depth,height,cross_roof=False):
    masonry(x,y,width,depth,height)
    z=.065+height
    rw,rd=(depth,width) if cross_roof else (width,depth)
    rise=rw*.43
    before=set(bpy.context.scene.objects)
    # Extend the solid gable to the underside of the oversailing tiles.
    roof_rise=rise+.10
    roof_eave=z-roof_rise*.24/(rw+.24)+.06
    gable(0,0,z,rw,rd,roof_rise*rw/(rw+.24))
    roof(0,0,roof_eave,rw+.24,rd+.25,roof_rise)
    bpy.context.view_layer.update()
    transform=Matrix.Translation((x,y,0)) @ Matrix.Rotation(math.pi/2 if cross_roof else 0,4,"Z")
    for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world
    return z,rise


def lean_to(x,y,z,width,depth,rise=.30,material="wood_light"):
    slab("Sloping porch roof",[(x-width/2,y-depth/2,z),(x+width/2,y-depth/2,z),
         (x+width/2,y+depth/2,z+rise),(x-width/2,y+depth/2,z+rise)],.055,"wood")
    cols=max(3,round(width/.24)); rows=3
    for col in range(cols):
        for row in range(rows):
            y0=y-depth/2+depth*row/rows+.004; y1=y-depth/2+depth*(row+1)/rows-.004
            z0=z+rise*row/rows+.018; z1=z+rise*(row+1)/rows+.018
            x0=x-width/2+width*col/cols+.003; x1=x-width/2+width*(col+1)/cols-.003
            slab("Porch roof tile" if material=="roof" else "Porch roof board",[(x0,y0,z0),(x1,y0,z0),(x1,y1,z1),(x0,y1,z1)],.026,material)


def house_cottage():
    plot(1.94,1.80)
    z,rise=house_shell(-.10,.07,1.36,1.28,1.35)
    door(-.35,-.588,height=.78)
    window(.596,.06,.91,True,shutters=False)
    box("Small attic vent",(-.1,-.581,1.58),(.10,.02,.14),"stone",.001)
    chimney(.27,.36,z+rise*.40,.56)
    barrel(.33,-.72,r=.125,h=.28)
    shrub(.72,.48,scale=1.2); shrub(-.66,.55,scale=.7)


def house():
    plot(2.37,2.15)
    z,rise=house_shell(.18,.20,1.55,1.38,1.68,True)
    door(-.16,-.502,height=.88)
    window(.64,-.503,1.18,flowers=True)
    window(.975,.32,1.18,True,flowers=True)
    chimney(.67,.48,z+rise*.44,.61)
    # Offset wooden porch leaves the flower window and front door readable.
    lean_to(-.31,-.77,1.12,1.31,.92,.32)
    for x in [-.88,.26]:
        box("Porch square oak post",(x,-1.13,.60),(.085,.085,1.07),"wood",.006)
        beam("Porch knee brace",(x,-1.13,.91),(x+(.19 if x<0 else -.19),-1.13,1.13),.026,"wood_light")
    box("Porch crossbeam",(-.31,-1.10,1.10),(1.29,.09,.085),"wood",.004)
    barrel(1.02,-.42,r=.13,h=.30)
    from environment import crate
    crate(.91,-.80,z=.061,size=.24)
    shrub(1.02,.66,scale=.95); shrub(-.96,.50,scale=.65)


def house_tall():
    plot(2.16,1.96)
    z,rise=house_shell(-.10,.14,1.62,1.35,2.05,True)
    door(-.25,-.548,height=.78)
    window(.40,-.552,.48,shutters=False,width=.17,height=.23)
    for x in [-.58,.27]: window(x,-.553,1.58,width=.27,height=.39)
    for height in [.48,1.58]: window(.727,.21,height,True,flowers=height>1,width=.26,height=.36)
    # Continuous upstairs wooden balcony with posts, rails and planted boxes.
    for i in range(7): box("Balcony floorboard",(-.83+i*.235,-.70,1.19),(.229,.39,.07),"wood_light",.003)
    for x in [-.86,.65]:
        box("Balcony side rail",(x,-.71,1.50),(.055,.40,.06),"wood",.003)
        beam("Balcony supporting bracket",(x,-.56,.93),(x,-.86,1.18),.035,"wood")
    for i in range(10): box("Turned square balcony baluster",(-.87+i*.17,-.885,1.36),(.039,.042,.34),"wood",.003)
    for zz in [1.22,1.53]: box("Continuous balcony rail",(-.105,-.892,zz),(1.62,.061,.063),"wood_light",.004)
    for x in [-.62,.39]:
        box("Balcony planter",(x,-.94,1.40),(.30,.16,.13),"wood_light",.004)
        for i in range(3):
            sphere("Balcony leaves",(x-.09+i*.09,-.95,1.49),(.077,.073,.059),"green")
            sphere("Balcony flower",(x-.09+i*.09,-.97,1.535),(.033,.032,.027),"flower" if i%2 else "flower_light")
    chimney(.48,.45,z+rise*.45,.56)
    tree(.90,.45,.94); shrub(-.93,-.40,scale=.8)


def road():
    box("Damp grit between paving stones",(0,0,.018),(1,1,.036),"mortar",.012)
    rng = random.Random(73)
    for row in range(3):
        edges = [-.5,-.17,.16,.5] if row%2 == 0 else [-.5,-.34,0,.33,.5]
        for col,(left,right) in enumerate(zip(edges,edges[1:])):
            box("Worn granite paving slab",((left+right)/2,-.333+row/3,.047),
                (right-left-.018,.313,.045),rng.choice(["stone","stone","masonry_warm","stone_wet"]),.010)
    for x,y,w,d in [(-.174,-.26,.015,.14),(.19,.166,.16,.012),(-.43,-.165,.10,.013)]:
        box("Moss in sheltered paving joint",(x,y,.038),(w,d,.006),"moss",0)


def well():
    plot(1.66,1.62)
    for xx,yy in [(-.54,-.57),(-.19,-.63),(.17,-.63),(.53,-.57),(.61,-.23)]:
        box("Apron paving stone",(xx,yy,.079),(.31,.28,.048),"stone",.010)
    sides=12
    for tier in range(3):
        bottom=.07+tier*.164
        for i in range(sides):
            a=(i+(tier%2)*.5)*math.tau/sides+.007; b=(i+1+(tier%2)*.5)*math.tau/sides-.007
            verts=[(r*math.cos(t),r*math.sin(t),z) for z in [bottom,bottom+.158]
                   for r,t in [(.49,a),(.49,b),(.33,b),(.33,a)]]
            obj=mesh("Staggered granite well block",verts,FACES,
                     ["stone_wet","stone_dark","stone","masonry_warm"][(i+tier*3)%4])
            mod=obj.modifiers.new("Worn stone edge","BEVEL"); mod.width=.006; mod.segments=1
            obj.modifiers.new("Block normals","WEIGHTED_NORMAL")
    for i in range(sides):
        a=i*math.tau/sides+.006; b=(i+1)*math.tau/sides-.006
        verts=[(r*math.cos(t),r*math.sin(t),z) for z in [.562,.66]
               for r,t in [(.53,a),(.53,b),(.315,b),(.315,a)]]
        mesh("Thick open coping stone",verts,FACES,"masonry_pale" if i%3 else "stone_light")
    cylinder("Turquoise water inside the shaft",(0,0,.28),.329,.014,"water",24)
    for x in [-.53,.53]:
        box("Canopy oak upright",(x,.035,.94),(.125,.135,1.70),"wood_light",.007)
        box("Dark post side grain",(x+.044,-.036,1.16),(.022,.012,1.16),"wood",.001)
        beam("Canopy triangular brace",(x,.035,1.38),(x*.40,.035,1.68),.043,"wood")
    beam("Winding spindle",(-.62,.035,1.16),(.64,.035,1.16),.052,"wood")
    for i in range(8):
        obj=ring("Coiled rope on spindle",0,0,0,.063,.049,.018,"rope",10)
        obj.rotation_euler.y=math.pi/2; obj.location=(-.08+i*.02,.035,1.16)
    beam("Bucket hanging rope",(.03,.023,1.13),(.03,.023,.93),.012,"rope")
    barrel(.03,.023,.69,.105,.20)
    for a,b in [((-.057,.023,.86),(-.057,.023,.94)),((-.057,.023,.94),(.03,.023,.98)),((.03,.023,.98),(.117,.023,.94)),((.117,.023,.94),(.117,.023,.86))]:
        beam("Bucket iron handle",a,b,.009,"iron")
    beam("Wooden crank arm",(.66,.035,1.16),(.66,.035,.99),.025,"wood")
    beam("Wooden crank grip",(.66,.035,.99),(.78,.035,.99),.027,"wood_light")
    roof(0,.035,1.74,1.52,1.12,.44)
    barrel(.64,-.38,r=.11,h=.25)
    shrub(-.67,-.20,scale=.9); shrub(.50,.55,scale=.85)


def farm():
    from resources import corn_plant
    plot(3.55,3.35,"leaf_olive")
    box("Cultivated rectangular field",(-.36,-.08,.080),(2.55,2.93,.032),"ground",.015)
    for row in range(4):
        x=-1.36+row*.57
        box("Visible earth between corn rows",(x,-.13,.108),(.27,2.60,.025),"wood_light",.015)
        for col in range(5):
            y=-1.19+col*.52
            corn_plant(x,y,.13,scale=.55+((row+col)%3)*.04,detailed=False)
    # Small stone farmhouse is the field's defining secondary form.
    z,rise=house_shell(1.16,.56,.86,1.02,.92)
    door(1.16,.034,bottom=.08,height=.56,width=.24)
    window(1.604,.58,.64,True,shutters=False,width=.15,height=.20)
    for x in [-1.67,1.67]:
        for y in [-1.55,-.52,.53,1.55]: box("Corn field fence post",(x,y,.32),(.095,.095,.50),"wood_light",.007)
        for zz in [.24,.43]: box("Corn field side rail",(x,0,zz),(.060,3.15,.07),"wood",.004)
    for y in [-1.55,1.55]:
        for zz in [.24,.43]: box("Corn field end rail",(-.36,y,zz),(2.60,.060,.07),"wood_light",.004)
    barrel(1.25,-.70,r=.13,h=.27)
    shrub(1.43,1.25,scale=.7)


def lumber():
    plot(2.43,2.13,"ground")
    for x in [-.84,.65]:
        for y in [-.28,.75]: box("Shed timber post",(x,y,.68),(.14,.14,1.23),"wood",.008)
    for i in range(5): box("Shed back plank",(-.70+i*.29,.76,.62),(.276,.07,1.09),"wood_light",.004)
    roof(-.10,.24,1.37,1.93,1.48,.55,"wood_light")
    for row in range(3):
        for col in range(3-row):
            x=-.62+col*.35+row*.175; z=.24+row*.30
            beam("Large stacked octagonal log",(x,-.39,z),(x,.66,z),.175,"wood_light")
            beam("Fresh golden cut end",(x,-.403,z),(x,-.414,z),.15,"wood_end")
    cylinder("Chopping stump",(.93,-.61,.22),.18,.32,"wood",9)
    cylinder("Pale stump top",(.93,-.61,.387),.17,.015,"wood_end",9)
    beam("Axe handle",(.92,-.61,.38),(1.04,-.59,.81),.024,"wood_light")
    box("Iron axe head",(1.00,-.59,.77),(.19,.045,.14),"iron",.011)
    shrub(-.97,.60,scale=.9); shrub(.95,.62,scale=.9)


def fishery():
    box("Turquoise shallow water base",(0,0,.025),(2.48,2.43,.05),"water",.018)
    for x,y,w,d in [(-.78,-.82,.76,.59),(.62,.72,.89,.82),(.65,-.62,.84,.32)]:
        box("Shallow water color patch",(x,y,.052),(w,d,.006),"water_light",0)
    for x in [-.91,.92]:
        for y in [-.39,.84]: cylinder("Jetty support pile",(x,y,.40),.085,.77,"wood",8)
    for i in range(9): box("Honey oak dock plank",(-.88+i*.22,.21,.41),(.211,1.48,.10),
                            "wood_honey" if i%3==0 else "wood_light",.005)
    for x in [-.91,.92]:
        box("Fishing net post",(x,.76,1.0),(.12,.12,1.40),"wood",.006)
        ring("Post rope lashing",x,.76,1.46,.077,.058,.09,"rope",8)
    # A suspended diagonal rope between two posts, as in the reference pier.
    beam("Hanging fishing line",(-.91,.76,1.65),(.92,.76,1.47),.014,"rope")
    beam("Tackle lowering rope",(-.70,.76,1.63),(-.70,.76,.70),.012,"rope")
    from environment import crate
    crate(-.58,.45,z=.47,size=.26)
    def point(u,v):
        return (.90, .76-1.08*u, 1.47-(1.03*u)-v*(1-u)*.88)
    for i in range(7):
        t=i/6
        beam("Visible net warp",point(t,0),point(t,1),.012,"fish_dark")
        beam("Visible net weft",point(0,t),point(1,t),.012,"fish_dark")
    from environment import hull
    before=set(bpy.context.scene.objects)
    hull(1.72,.60,.20)
    bpy.context.view_layer.update()
    transform=Matrix.Translation((-.12,-.84,.04)) @ Matrix.Rotation(math.pi/2,4,"Z")
    for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world


def saltery():
    from resources import fish_shape
    plot(2.72,2.37)
    z,rise=house_shell(-.29,.39,1.50,1.21,1.53,True)
    door(-.60,-.231,height=.91,width=.39)
    window(.05,-.233,1.13,shutters=False,width=.22,height=.26)
    window(.474,.60,1.13,True,shutters=False,width=.22,height=.26)
    chimney(.13,.63,z+rise*.39,.53)
    lean_to(.67,-.50,1.03,1.27,1.04,.32)
    for x in [.13,1.21]: box("Salting awning oak post",(x,-.99,.55),(.09,.09,.99),"wood",.005)
    beam("Fish curing rail",(.18,-.63,.99),(1.20,-.63,.99),.029,"wood")
    for i in range(3):
        x=.36+i*.27
        before=set(bpy.context.scene.objects)
        fish_shape(scale=.21,dried=False,angle=0)
        bpy.context.view_layer.update()
        transform=Matrix.Translation((x,-.66,.69)) @ Matrix.Rotation(math.pi/2,4,"Y")
        for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world
        beam("Fish hanging twine",(x,-.66,.82),(x,-.66,.98),.007,"rope")
    barrel(-1.08,-.40,r=.14,h=.34)
    barrel(-.79,-.68,r=.145,h=.31,filled="salt")
    box("Square salting table",(-.12,-.88,.39),(.61,.49,.06),"wood_light",.006)
    for x in [-.37,.13]:
        for y in [-1.08,-.68]: box("Salting table leg",(x,y,.23),(.054,.054,.34),"wood",.003)
    for x in [-.39,.15]: box("Salt tray raised edge",(x,-.88,.46),(.045,.49,.12),"wood_light",.003)
    for y in [-1.10,-.66]: box("Salt tray end",(-.12,y,.46),(.58,.035,.12),"wood_light",.003)
    mesh("Angular white salt pile",[(-.34,-1.04,.43),(.09,-1.04,.43),(.09,-.70,.43),(-.34,-.70,.43),(-.12,-.85,.75)],
         [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],"salt")
    shrub(-1.13,.68,scale=.8)


BUILDERS={name:globals()[name] for name in ["house","house_cottage","house_tall","road","well","farm","lumber","fishery","saltery"]}
if __name__=="__main__":
    requested=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,512,export_model=True)
