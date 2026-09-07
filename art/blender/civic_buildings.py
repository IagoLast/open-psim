"""Galician civic and harbour miniatures, sharing the collection's stone and tiles.

Regenerate: Blender -b --threads 4 --python art/blender/civic_buildings.py
Optional identifiers after -- limit the generation to individual buildings.
"""
import math
import sys
from pathlib import Path
import bpy
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, sphere, beam, mesh, render, ROOT
from buildings import plot, masonry, house_shell, roof, gable, door, window, chimney, barrel, ring, shrub, tree, lean_to, slab
from environment import crate


def bench(x, y, z=.10, width=.72):
    box("Oak bench seat", (x,y,z+.25), (width,.23,.065), "wood_light")
    for dx in [-width*.35,width*.35]:
        box("Bench trestle",(x+dx,y,z+.12),(.075,.21,.24),"wood")


def bell(x,y,z,scale=1):
    """Open bell mouth and clapper remain readable below the tiny belfry."""
    cylinder("Bronze bell crown",(x,y,z+.12*scale),.07*scale,.10*scale,"wood_end",10)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=.14*scale, radius2=.065*scale,
                                   depth=.16*scale, location=(x,y,z+.04*scale))
    from common import finish
    finish(bpy.context.object,"wood_end")
    ring("Bell flared lip",x,y,z-.055*scale,.155*scale,.12*scale,.04*scale,"wood_end")
    sphere("Bell iron clapper",(x,y,z-.06*scale),(.04*scale,.04*scale,.07*scale),"iron")


def sign(x,y,z,symbol="book"):
    beam("Projecting sign bracket",(x,y+.22,z+.20),(x,y-.12,z+.20),.022,"iron")
    box("Carved oak service sign",(x,y-.11,z),(.43,.075,.31),"wood")
    if symbol == "book":
        for dx,angle in [(-.095,-.15),(.095,.15)]:
            ob=box("Open parchment book",(x+dx,y-.155,z),(.17,.022,.19),"canvas",.003)
            ob.rotation_euler.y=angle
        box("Book binding",(x,y-.175,z),(.018,.014,.20),"wood_light",.001)
    elif symbol == "shell":
        for i in range(7):
            a=math.pi*.16+i*math.pi*.68/6
            beam("Pilgrim scallop rib",(x,y-.16,z-.095),
                 (x+math.cos(a)*.14,y-.17,z-.09+math.sin(a)*.22),.026,"canvas")
    elif symbol == "herb":
        beam("Apothecary herb stem",(x,y-.16,z-.11),(x,y-.16,z+.11),.013,"leaf_forest")
        for dx,dz in [(-.065,-.03),(.065,.025),(-.05,.075)]:
            sphere("Carved herb leaf",(x+dx,y-.17,z+dz),(.072,.017,.035),"leaf_olive")


def arch(x,y,z,width,height,depth=.16):
    """Open stone arcade, with individual wedge stones and no solid infill."""
    r=width/2
    for side in [-1,1]:
        box("Arcade granite pier",(x+side*(r+.055),y,z+(height-r)/2),(.13,depth,height-r),"stone",.006)
    for i in range(12):
        a=i*math.pi/12+.008; b=(i+1)*math.pi/12-.008
        vertices=[(x+rr*math.cos(t),yy,z+height-r+rr*math.sin(t))
                  for yy in [y-depth/2,y+depth/2] for rr in [r,r+.12] for t in [a,b]]
        mesh("Dressed arcade arch stone",vertices,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],"stone_light" if i%3 else "stone")


def hip_roof(x,y,z,width,depth,rise,material="roof"):
    """Four slopes and a short ridge distinguish institutional halls from houses."""
    ridge=max(0,depth-width)*.5
    corners=[(x-width/2,y-depth/2,z),(x+width/2,y-depth/2,z),
             (x+width/2,y+depth/2,z),(x-width/2,y+depth/2,z)]
    a=(x,y-ridge,z+rise); b=(x,y+ridge,z+rise)
    mesh("Thick hipped roof",corners+[a,b],[(0,4,1),(1,4,5,2),(2,5,3),(3,5,4,0),(3,2,1,0)],material)
    for point in corners:
        beam("Hipped roof corner cap",point,a if point[1]<y else b,.035,"roof_light" if material=="roof" else material)
    if ridge: beam("Short institutional roof ridge",a,b,.045,"roof_light" if material=="roof" else material)
    for side in [-1,1]:
        for row in range(1,5):
            u=row/5
            beam("Broad hipped roof courses",(x+side*width/2*u,y-ridge-(depth/2-ridge)*u,z+rise*(1-u)),
                 (x+side*width/2*u,y+ridge+(depth/2-ridge)*u,z+rise*(1-u)),.012,"roof_dark" if material=="roof" else "slate")


def market():
    plot(2.9,2.85)
    # A market square made of three separate striped canvas stalls, not a house.
    for x,y,tone in [(-.72,-.60,"canvas"),(.70,-.60,"cloth"),(0,.80,"green")]:
        for xx in [x-.48,x+.48]:
            for yy in [y-.38,y+.38]: box("Market tent pole",(xx,yy,.78),(.045,.045,1.42),"wood")
        for side in [-1,1]:
            for strip in range(6):
                yy=y-.45+strip*.15
                slab("Striped linen canopy",[(x,yy,1.60),(x+side*.55,yy,1.27),
                     (x+side*.55,yy+.145,1.27),(x,yy+.145,1.60)],.016,"canvas" if strip%2 else tone)
        box("Produce stall front",(x,y-.30,.35),(.98,.07,.55),"wood_honey")
        box("Produce stall countertop",(x,y-.12,.65),(1.04,.51,.07),"wood_light")
        for col in range(3):
            xx=x-.32+col*.32
            box("Shallow market tray",(xx,y-.12,.71),(.29,.34,.06),"wood")
            for j in range(3):
                sphere("Golden apples and cabbages",(xx+(j-1)*.065,y-.12,.775),(.065,.072,.067),
                       "grain" if x<0 else "green")
    barrel(-1.18,.78,r=.18,h=.42,filled="grain")
    crate(1.08,.64,z=.07,size=.36)
    cylinder("Town market weighing plinth",(0,-1.13,.28),.15,.40,"stone",8)
    beam("Market weighing balance",(-.25,-1.13,.67),(.25,-1.13,.67),.018,"iron")
    beam("Balance upright",(0,-1.13,.44),(0,-1.13,.78),.023,"iron")


def clinic():
    plot(2.75,3.45)
    # Low U-shaped infirmary surrounding a medicinal court and a stone arcade.
    for x in [-.96,.96]:
        masonry(x,.36,.53,2.38,1.05)
        hip_roof(x,.36,1.16,.72,2.61,.30,"slate")
        for y in [-.40,.38,1.12]: window(x+.275,y,.73,True,width=.19,height=.31,shutters=False)
    masonry(0,1.17,1.47,.75,1.31)
    hip_roof(0,1.17,1.40,1.69,.98,.39,"slate")
    door(0,.786,height=.93,width=.38)
    for x in [-.78,0,.78]: arch(x,-.94,.08,.56,1.0)
    box("Hospital arcade lintel",(0,-.94,1.20),(2.51,.30,.16),"stone_light")
    # A modest carved stone cross, not a modern medical sign.
    box("Hospital carved stone cross",(0,-.94,1.53),(.065,.10,.47),"stone_light")
    box("Hospital stone cross arms",(0,-.94,1.58),(.30,.10,.065),"stone_light")
    for x in [-.33,.33]:
        box("Sunken medicinal herb bed",(x,.10,.15),(.44,.82,.17),"stone_dark")
        for y in [-.13,.13,.39]: shrub(x,y,z=.24,scale=.5)
    bench(-.42,-.57,width=.59)
    sign(.92,-1.04,.62,"herb")


def chapel():
    plot(1.92,2.85)
    # Narrow, tall sanctuary with polygonal apse, buttresses and a stone porch.
    masonry(0,-.16,1.18,1.76,1.53)
    gable(0,-.16,1.595,1.18,1.76,.77)
    roof(0,-.16,1.60,1.34,1.87,.85)
    cylinder("Polygonal chapel apse",(0,.83,.70),.58,1.26,"stone",8)
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.66,radius2=0,depth=.55,location=(0,.83,1.59))
    from common import finish
    finish(bpy.context.object,"roof_dark")
    door(0,-1.049,height=.90,width=.40)
    arch(0,-1.13,.08,.47,1.13)
    for y in [-.60,.24]:
        window(.602,y,1.02,True,width=.15,height=.52,shutters=False)
        box("Chapel stepped buttress",(.68,y+.20,.62),(.18,.21,1.10),"stone_dark")
    # Galician espadaña: two stone uprights around an actual open bell bay.
    for x in [-.21,.21]: box("Espadana granite upright",(x,-1.01,2.58),(.13,.19,.66),"stone")
    box("Espadana stone lintel",(0,-1.01,2.94),(.61,.23,.14),"stone_light")
    gable(0,-1.01,3.01,.64,.24,.20)
    bell(0,-1.01,2.63,.86)
    box("Chapel stone cross",(0,-1.01,3.34),(.055,.07,.30),"stone_light")
    box("Chapel cross arms",(0,-1.01,3.38),(.23,.07,.055),"stone_light")
    for i in range(2): box("Broad chapel entrance step",(0,-1.22+i*.09,.08+i*.06),(.86,.27,.08),"stone_dark")
    shrub(-.73,.98,scale=.8)


def watch():
    plot(1.94,1.91)
    # An octagonal watchtower beside a low fortified gate, with a crenellated crown.
    cylinder("Octagonal guard tower",(-.30,.22,1.22),.56,2.28,"stone",8)
    cylinder("Tower dark granite foot",(-.30,.22,.19),.60,.26,"stone_wet",8)
    cylinder("Projecting crenellated crown",(-.30,.22,2.43),.65,.19,"stone_light",8)
    for i in range(8):
        a=i*math.tau/8
        ob=box("Octagonal tower battlement",(-.30+.55*math.cos(a),.22+.55*math.sin(a),2.68),(.29,.22,.34),"stone")
        ob.rotation_euler.z=a
    for z in [1.18,1.83]:
        box("Tower frontal arrow slit",(-.30,-.302,z),(.08,.018,.34),"dark",0)
        box("Tower lateral arrow slit",(.228,.22,z),(.018,.08,.34),"dark",0)
    masonry(.43,-.44,.83,.54,1.0)
    door(.43,-.72,height=.81,width=.36)
    arch(.43,-.75,.08,.39,.86)
    for x in [.12,.74]: box("Gatehouse merlon",(x,-.44,1.25),(.23,.48,.28),"stone")
    beam("Watch banner staff",(-.30,.22,2.49),(-.30,.22,3.25),.022,"wood")
    mesh("Tall blue guard pennant",[(-.30,.22,3.21),(.20,.24,3.13),(.07,.24,2.87),(-.30,.22,2.92)],[(0,1,2,3)],"cloth")
    barrel(.73,.59,r=.13,h=.31)


def school():
    plot(1.92,2.86)
    # One long classroom under a single pitched roof. Tall, regularly spaced
    # windows light the room; the entrance and plaque are fixed to its stone wall.
    masonry(0,.24,1.46,2.08,1.48)
    gable(0,.24,1.545,1.46,2.08,.43)
    roof(0,.24,1.535,1.66,2.28,.49)
    door(0,-.813,bottom=.14,height=.84,width=.38)
    for x in [-.48,.48]: window(x,-.815,.88,width=.23,height=.49,shutters=False)
    for y in [-.40,.25,.90]: window(.742,y,.90,True,width=.29,height=.58,shutters=False)
    for x in [-.26,.26]: box("School entrance stone jamb",(x,-.834,.57),(.085,.10,.89),"stone_light")
    box("School entrance granite lintel",(0,-.834,1.04),(.61,.12,.12),"stone_light")
    box("Book plaque fixed to school facade",(0,-.836,1.30),(.30,.05,.25),"stone_dark",.004)
    for x in [-.065,.065]:
        box("Carved open book page",(x,-.867,1.30),(.11,.02,.14),"stone_light",.002)
    box("Carved book central binding",(0,-.884,1.30),(.014,.012,.16),"stone",0)
    for i in range(2): box("School entrance step",(0,-1.03+i*.09,.08+i*.04),(.75,.30,.06),"stone_dark")
    box("School stone bench seat",(.59,-1.08,.37),(.47,.24,.08),"stone_light")
    for x in [.44,.74]: box("School stone bench support",(x,-1.08,.23),(.10,.19,.21),"stone")


def dock():
    box("Harbour shallow water",(0,0,.025),(3.05,2.1,.05),"water")
    box("Granite quay foundation",(0,.67,.16),(3.0,.68,.31),"stone_wet")
    for i in range(8): box("Quay paving blocks",(-1.31+i*.375,.67,.335),(.36,.65,.06),"stone")
    for x in [-1.08,0,1.08]:
        for y in [-.87,.27]: cylinder("Harbour oak pile",(x,y,.24),.085,.48,"wood",8)
    for i in range(13): box("Commercial jetty planks",(-1.32+i*.22,-.35,.39),(.21,1.32,.10),"wood_honey" if i%3==0 else "wood_light")
    # Hand operated harbour crane with diagonal brace, windlass and hanging hook.
    cylinder("Crane stone socket",(.86,.08,.50),.18,.24,"stone_dark",10)
    beam("Crane oak mast",(.86,.08,.58),(.86,.08,1.88),.085,"wood")
    beam("Crane horizontal jib",(.86,.08,1.81),(-.10,-.42,1.81),.06,"wood_light")
    beam("Crane diagonal brace",(.86,.08,1.10),(-.05,-.39,1.80),.05,"wood")
    beam("Crane hanging rope",(-.08,-.41,1.78),(-.08,-.41,.93),.014,"rope")
    ring("Crane iron hook",-.08,-.41,.87,.06,.037,.045,"iron",10)
    beam("Crane winding drum",(.63,.08,.91),(1.07,.08,.91),.073,"wood_honey")
    for x,y in [(-1.22,-.84),(1.24,-.84),(-1.24,.38)]:
        cylinder("Mooring bollard",(x,y,.55),.065,.30,"wood",8)
        ring("Mooring rope collar",x,y,.60,.078,.059,.04,"rope",10)
    crate(-.86,.63,z=.37,size=.39); crate(-.39,.66,z=.37,size=.35)
    barrel(-.92,-.05,z=.44,r=.18,h=.38)
    barrel(-.49,.05,z=.44,r=.15,h=.31)


def depot():
    plot(2.84,2.85)
    masonry(0,.32,2.14,1.98,1.59)
    gable(0,.32,1.65,2.14,1.98,.66)
    roof(0,.32,1.66,2.40,2.23,.74,"slate")
    door(-.29,-.683,height=1.19,width=.65)
    door(.39,-.683,height=1.19,width=.65)
    box("Warehouse door lintel",(.05,-.73,1.36),(1.58,.16,.15),"wood")
    for y in [-.18,.67]: window(1.084,y,1.11,True,width=.27,height=.30,shutters=False)
    for x,y,s in [(-.98,-.98,.38),(-.57,-1.10,.30),(.97,-.95,.42)]: crate(x,y,z=.065,size=s)
    barrel(-1.18,.69,r=.14,h=.36)
    beam("Warehouse hoist bracket",(0,-.72,1.76),(0,-1.06,1.76),.042,"wood")
    beam("Warehouse hoist rope",(0,-1.05,1.75),(0,-1.05,1.25),.012,"rope")


def firewatch():
    plot(1.93,2.85)
    # An entirely open timber lookout with braced legs and a large stone cistern.
    for x in [-.53,.53]:
        for y in [.12,1.05]:
            box("Alarm tower granite socket",(x,y,.19),(.25,.25,.26),"stone_dark")
            beam("Tall alarm tower leg",(x,y,.28),(x*.82,y,2.94),.06,"wood")
    for y in [.12,1.05]:
        for z in [.40,1.44]:
            beam("Alarm tower diagonal bracing",(-.49,y,z),(.45,y,z+1.04),.036,"wood_light")
            beam("Crossed alarm tower brace",(.49,y,z),(-.45,y,z+1.04),.036,"wood_light")
    box("Open lookout floor",(0,.59,2.51),(1.20,1.19,.12),"wood_light")
    for x in [-.56,.56]:
        beam("Lookout handrail",(x,.03,2.86),(x,1.15,2.86),.034,"wood")
        for y in [.05,.58,1.12]: beam("Lookout railing spindle",(x,y,2.54),(x,y,2.85),.019,"wood")
    hip_roof(0,.59,3.12,1.37,1.39,.42,"slate")
    bell(0,.59,2.90,1.12)
    beam("Long alarm bell rope",(0,.59,2.91),(0,.59,.26),.012,"rope")
    for i in range(10): beam("Lookout access ladder rung",(.62,.14,.26+i*.23),(.84,.14,.26+i*.23),.017,"wood_light")
    for x in [.60,.86]: beam("Lookout access ladder side",(x,.14,.12),(x,.14,2.50),.024,"wood")
    ring("Large open fire cistern",-.25,-.76,.08,.53,.43,.48,"stone_dark",12)
    cylinder("Water in fire cistern",(-.25,-.76,.48),.435,.018,"water",12)
    barrel(.61,-.95,r=.16,h=.36,filled="water")
    beam("Fire hook handle",(.70,-.55,.11),(.70,-.55,1.20),.018,"wood")
    beam("Forged fire hook",(.70,-.55,1.20),(.84,-.55,1.13),.020,"iron")


def maintenance():
    plot(1.94,2.83)
    # A builder's open yard: unfinished stone arch, scaffold, timber rack and sawpit.
    masonry(-.63,.56,.30,1.51,.81)
    box("Workshop rear stone wall",(0,1.21,.50),(1.57,.16,.88),"stone")
    lean_to(-.20,.58,1.19,1.40,1.38,.42,"wood_light")
    for x in [-.82,.44]: box("Open timber workshop post",(x,-.08,.62),(.07,.07,1.11),"wood")
    arch(.02,-.60,.08,.91,1.20,.26)
    for x in [-.72,.72]:
        box("Builder scaffold upright",(x,-.84,.90),(.06,.07,1.68),"wood")
        beam("Scaffold diagonal brace",(x,-.84,.32),(-x,-.84,1.30),.024,"wood_light")
    box("Builder scaffold working platform",(0,-.85,1.44),(1.67,.33,.07),"wood_light")
    box("Stonecutters workbench",(0,-.80,.58),(1.09,.46,.10),"wood_honey")
    for x in [-.43,.43]: box("Workshop bench trestle",(x,-.80,.33),(.10,.36,.47),"wood")
    box("Stone block being dressed",(-.21,-.80,.73),(.34,.27,.21),"stone_light")
    beam("Mason mallet handle",(.15,-.83,.655),(.47,-.71,.655),.022,"wood")
    box("Mason wooden mallet head",(.45,-.72,.69),(.11,.21,.12),"wood_end")
    for i in range(4): box("Stacked repair boards",(.77,.54,.14+i*.067),(.23,1.35,.06),"wood_light")
    for i in range(3): box("Cut repair granite",(-.68,-1.20+i*.20,.15),(.33,.18,.17),"stone_dark")
    barrel(-.74,.90,r=.13,h=.30)


def inn():
    plot(1.97,2.84)
    # Two storeys of guest rooms, a hearth chimney and a small balcony accessed
    # through an upstairs door. Both corbels meet the wall and balcony slab.
    masonry(0,.31,1.50,1.86,2.10)
    gable(0,.31,2.165,1.50,1.86,.46)
    roof(0,.31,2.155,1.71,2.06,.52)
    door(0,-.633,bottom=.10,height=.85,width=.43)
    for y in [-.12,.68]:
        for z in [.66,1.65]: window(.762,y,z,True,width=.25,height=.39,shutters=False)
    for x in [-.49,.49]: window(x,-.634,1.66,width=.21,height=.37,shutters=False)
    # The upper threshold is flush with the balcony floor; the balcony is
    # uncovered, with returns on both sides and a continuous front handrail.
    door(0,-.636,bottom=1.23,height=.68,width=.35)
    box("Inn balcony granite slab",(0,-.80,1.18),(.81,.42,.10),"stone_light",.008)
    for x in [-.27,.27]:
        mesh("Balcony stone corbel",[(x-.055,-.60,.88),(x+.055,-.60,.88),
             (x-.055,-.60,1.135),(x+.055,-.60,1.135),
             (x-.055,-.97,1.135),(x+.055,-.97,1.135)],
             [(0,4,2),(1,3,5),(0,1,5,4),(2,4,5,3),(0,2,3,1)],"stone_dark")
    for x in [-.36,.36]:
        for y in [-.99,-.66]: box("Balcony corner post",(x,y,1.41),(.043,.043,.37),"wood")
        box("Balcony side handrail",(x,-.825,1.61),(.046,.37,.045),"wood_light")
    for z in [1.28,1.61]: box("Balcony front rail",(0,-.99,z),(.76,.045,.045),"wood_light")
    for i in range(7): box("Balcony upright baluster",(-.30+i*.10,-.99,1.44),(.025,.029,.30),"wood",0)
    chimney(.36,.86,2.20,.73)
    box("Pilgrim shell plaque fixed to inn wall",(-.52,-.657,.67),(.29,.045,.30),"wood",.005)
    for i in range(7):
        a=math.pi*.16+i*math.pi*.68/6
        beam("Carved pilgrim shell rib",(-.52,-.690,.57),
             (-.52+math.cos(a)*.11,-.696,.57+math.sin(a)*.19),.018,"canvas")
    bench(.43,-1.18,width=.61)


BUILDERS={name:globals()[name] for name in ["market","clinic","chapel","watch","school","dock","depot","firewatch","maintenance","inn"]}
if __name__ == "__main__":
    requested=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,512,export_model=True)
