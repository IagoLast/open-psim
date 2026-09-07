"""Twelve editable production miniatures, using the Pontevedra material library.

Regenerate: Blender -b --threads 4 --python-exit-code 1 --python
art/blender/production_buildings.py [-- saltworks quarry ...].
Front faces -Y. Each source keeps the individually named modelling pieces.
"""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import reset, box, cylinder, sphere, beam, mesh, render
from buildings import plot, house_shell, door, window, chimney, roof, lean_to, barrel, ring, shrub


def shed(x, y, w=.95, d=.95, h=.90):
    house_shell(x, y, w, d, h)
    door(x, y-d/2-.018, height=h*.68, width=w*.28)
    window(x+w/2+.018, y, h*.65, True, shutters=False, width=.18, height=.23)


def fence(x0, x1, y, z=.08):
    for i in range(5):
        x=x0+(x1-x0)*i/4
        box("Oak fence post",(x,y,z+.25),(.075,.08,.5),"wood_light",.005)
    for zz in [.23,.42]:
        box("Fence rail",((x0+x1)/2,y,z+zz),(x1-x0,.055,.06),"wood",.003)


def table(x, y, w=.7, d=.5, h=.48):
    box("Broad workshop bench",(x,y,h),(w,d,.065),"wood_light",.005)
    for xx in [-1,1]:
        for yy in [-1,1]:
            box("Bench leg",(x+xx*(w/2-.07),y+yy*(d/2-.06),h/2),(.06,.065,h),"wood",.003)


def jar(x,y,z=.07,r=.15,h=.32,material="roof"):
    # Hollow lip, closed vessel body, broad faceted silhouette.
    profile=[(.58*r,z),(.92*r,z+h*.18),(r,z+h*.47),(.70*r,z+h*.80),(.55*r,z+h)]
    sides=10
    vertices=[(x+rr*math.cos(i*math.tau/sides),y+rr*math.sin(i*math.tau/sides),zz)
              for rr,zz in profile for i in range(sides)]
    faces=[tuple(range(sides-1,-1,-1))]
    faces += [(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i)
              for j in range(len(profile)-1) for i in range(sides)]
    mesh("Faceted clay vessel",vertices,faces,material)
    ring("Thick open vessel lip",x,y,z+h-.025,r*.61,r*.43,.043,material,10)
    cylinder("Dark vessel interior",(x,y,z+h*.88),r*.44,.008,"roof_dark",10)


def derrick(x,y,z=.07):
    box("Crane oak mast",(x,y,z+.70),(.14,.14,1.4),"wood",.008)
    beam("Crane jib",(x-.60,y,z+1.40),(x+.57,y,z+1.40),.065,"wood_light")
    beam("Triangular crane brace",(x,y,z+.62),(x-.50,y,z+1.38),.045,"wood")
    beam("Hoist rope",(x-.48,y,z+1.39),(x-.48,y,z+.44),.014,"rope")
    beam("Windlass axle",(x-.13,y,z+.70),(x+.15,y,z+.70),.07,"wood_light")
    for i in range(5):
        beam("Windlass rope coil",(x-.07+i*.03,y-.074,z+.66),(x-.07+i*.03,y-.074,z+.75),.015,"rope")


def saltworks():
    plot(3.3,3.1,"ground")
    for x in [-.91,.12]:
        for y in [-.89,.15]:
            box("Shallow evaporation bed",(x,y,.096),(.98,.97,.074),"stone_wet",.012)
            box("Turquoise brine in salt pan",(x,y,.140),(.81,.80,.018),"water_light" if y<0 else "water",.008)
            for dx in [-.47,.47]: box("Low salt pan stone wall",(x+dx,y,.20),(.075,.98,.16),"stone",.009)
            for dy in [-.46,.46]: box("Salt pan end wall",(x,y+dy,.20),(.89,.075,.16),"stone",.009)
            if x>0 or y>0:
                for j in range(3): sphere("Faceted crystallised salt",(x-.23+j*.19,y+.15,.21),(.16,.19,.12),"salt")
    shed(.98,.84,.85,.90,.78)
    for x,y,s in [(.94,-.85,.29),(1.23,-.42,.24),(.86,-.34,.18)]:
        sphere("Harvested white salt mound",(x,y,.13+s*.4),(s,s,s*.85),"salt")
    beam("Long wooden salt rake",(.72,-1.24,.13),(1.25,-.31,.61),.024,"wood_light")
    beam("Broad salt rake head",(.54,-1.15,.13),(.94,-1.37,.13),.038,"wood")
    barrel(1.26,.12,r=.13,h=.27)


def quarry():
    plot(3.15,2.85,"earth")
    for x,y,s in [(-.95,.55,.60),(-.32,.80,.72),(.45,.82,.58),(1.04,.54,.43)]:
        sphere("Angular exposed granite outcrop",(x,y,.40),(s,.58,s*.87),"granite_shadow")
        box("Fresh rectangular quarry cut",(x,y-.32,.29),(s*.95,.21,.42),"granite",.01)
    for i in range(3):
        box("Terraced granite extraction step",(-.42,.09-i*.25,.28-i*.07),(1.74,.28,.14),"stone_dark" if i%2 else "stone",.012)
    derrick(.91,.11)
    box("Block hanging from quarry crane",(.43,.11,.41),(.40,.37,.33),"stone_light",.008)
    for x,y in [(-1.03,-.91),(-.54,-.89),(-1.02,-.45)]:
        box("Dressed granite stock",(x,y,.19),(.42,.35,.25),"stone",.008)
    beam("Quarry pick handle",(.37,-1.03,.10),(.72,-.79,.35),.022,"wood_light")
    beam("Quarry iron pick",(.56,-.90,.34),(.88,-.69,.34),.028,"iron")
    shrub(1.21,.97,scale=.7)


def claypit():
    plot(3.1,2.85,"earth")
    for i in range(3):
        # Receding terraces leave the central digging hollow visible.
        box("Clay bank terrace",(-.27,.82-i*.34,.39-i*.10),(2.05-i*.28,.47,.23),"roof_dark",.05)
    for x in [-1.08,.73]:
        sphere("Unworked clay bank",(x,.42,.28),(.37,.73,.32),"roof")
    box("Wet clay pit floor",(-.23,-.20,.074),(1.65,.70,.035),"roof_dark",.02)
    box("Water pooled in digging hollow",(-.30,-.32,.097),(.72,.30,.017),"water",.025)
    shed(1.0,.71,.85,.94,.82)
    table(.73,-.66,.90,.53,.40)
    for i in range(5): box("Drying cut clay brick",(.42+(i%3)*.23,-.78+(i//3)*.23,.47),(.19,.15,.09),"roof",.01)
    barrel(-1.05,-.80,r=.16,h=.27,filled="roof_dark")
    beam("Digging spade shaft",(-.76,-.42,.12),(-.94,-.30,.87),.025,"wood_light")
    box("Broad iron spade blade",(-.75,-.43,.13),(.18,.04,.21),"iron",.01)


def mine():
    plot(3.1,2.9,"earth")
    for x,y,s in [(-.91,.58,.66),(-.40,.94,.70),(.30,.94,.83),(.87,.51,.58)]:
        sphere("Faceted rocky mine hillside",(x,y,.53),(s,.60,s),"stone_dark")
    box("Deep black mine mouth",(0,.05,.58),(.89,.075,.95),"dark",.04)
    for x in [-.52,.52]:
        box("Heavy entrance timber",(x,-.035,.60),(.18,.21,1.08),"wood",.011)
        box("Entrance timber foot stone",(x,-.04,.16),(.26,.29,.20),"stone_wet",.008)
    box("Mine entrance lintel",(0,-.035,1.15),(1.26,.23,.19),"wood_light",.009)
    for x in [-.39,.39]:
        beam("Entrance diagonal brace",(x,-.17,.80),(x*.53,-.17,1.06),.045,"wood")
    for y in [-1.21,-.96,-.71,-.46,-.21]: box("Mine track oak sleeper",(0,y,.10),(.84,.095,.075),"wood",.004)
    for x in [-.25,.25]: box("Short iron mine rail",(x,-.70,.15),(.05,1.48,.04),"iron",.004)
    box("Mine cart underframe",(0,-.91,.29),(.66,.59,.10),"wood",.005)
    for x in [-.30,.30]:
        for y in [-1.12,-.70]:
            obj=cylinder("Mine cart iron wheel",(x,y,.25),.12,.07,"iron",10); obj.rotation_euler.y=math.pi/2
        box("Mine cart side",(x,-.91,.51),(.07,.61,.39),"wood_light",.005)
    for y in [-1.19,-.63]: box("Mine cart end",(0,y,.51),(.62,.055,.39),"wood",.005)
    for i in range(5): sphere("Iron ore in cart",(-.18+i%3*.17,-1.07+i//3*.24,.68),(.15,.14,.15),"iron")
    for x,y in [(.98,-.59),(.97,-1.02)]: sphere("Stockpiled ore",(x,y,.20),(.26,.23,.20),"iron_dark")
    shrub(-1.22,.95,scale=.9)


def sheep_shape(x,y,angle=0):
    before=set(bpy.context.scene.objects)
    sphere("Low poly sheep fleece",(0,0,.40),(.29,.18,.22),"canvas")
    for dx,dy in [(-.12,-.09),(.07,.06),(.16,-.05)]: sphere("Broad wool tuft",(dx,dy,.50),(.17,.14,.12),"salt")
    sphere("Sheep dark face",(.27,0,.43),(.11,.095,.14),"stone_dark")
    for y0 in [-.09,.09]: sphere("Sheep ear",(.25,y0,.52),(.055,.065,.035),"wood_end")
    for dx in [-.17,.16]:
        for dy in [-.11,.11]: beam("Sheep leg",(dx,dy,.12),(dx,dy,.35),.028,"stone_dark")
    bpy.context.view_layer.update()
    transform=Matrix.Translation((x,y,0)) @ Matrix.Rotation(angle,4,"Z")
    for obj in set(bpy.context.scene.objects)-before: obj.matrix_world=transform @ obj.matrix_world


def sheep():
    plot(3.35,3.10,"leaf_olive")
    shed(.89,.76,1.17,1.09,.93)
    fence(-1.54,1.54,1.44)
    fence(-1.54,.85,-1.43)
    for x in [-1.55,1.55]:
        for y in [-.85,0,.75]: box("Pasture fence post",(x,y,.32),(.075,.075,.50),"wood_light",.004)
        for z in [.26,.44]: box("Pasture side rail",(x,0,z),(.055,2.80,.06),"wood",.003)
    for x,y,a in [(-.80,-.70,.15),(.12,-.53,-.25),(-.85,.38,-.7),(.87,-.88,2.7)]: sheep_shape(x,y,a)
    box("Sheep watering trough",(.85,.0,.19),(.65,.28,.22),"wood",.012)
    box("Water in trough",(.85,0,.31),(.54,.18,.02),"water",.005)
    shrub(-1.22,1.09,scale=.6)


def vineyard():
    plot(3.35,3.12,"leaf_olive")
    for x in [-1.13,-.38,.37]:
        box("Cultivated vineyard row",(x,-.07,.08),(.44,2.54,.035),"earth",.012)
        for y in [-1.20,-.42,.36,1.14]:
            box("Vine trellis post",(x,y,.55),(.065,.065,.95),"wood_light",.004)
        for z in [.55,.89]: beam("Trellis stretched rope",(x,-1.22,z),(x,1.22,z),.012,"rope")
        for y in [-.94,-.17,.60]:
            beam("Twisting vine stem",(x,y,.10),(x+.05,y,.71),.024,"wood")
            for dy in [-.19,0,.20]: sphere("Faceted vine foliage",(x,y+dy,.78),(.19,.20,.20),"leaf_forest" if dy==0 else "green")
            for dy in [-.12,.12]:
                for dz,r in [(0,.066),(-.08,.046)]: sphere("Hanging dark grape cluster",(x+.16,y+dy,.62+dz),(r,r,r*1.15),"fish_dark")
    shed(1.16,.78,.72,.87,.75)
    barrel(1.17,-.66,r=.16,h=.32,filled="fish_dark")
    barrel(1.10,-1.09,r=.12,h=.24)


def mill():
    plot(3.25,2.8)
    box("Turquoise millrace",(1.11,0,.075),(.70,2.75,.06),"water",.016)
    for x in [.73,1.50]: box("Millrace granite bank",(x,0,.17),(.13,2.77,.23),"stone_wet",.009)
    house_shell(-.35,.28,1.63,1.48,1.52)
    door(-.67,-.48,height=.92,width=.39)
    window(.05,-.482,1.02,shutters=False)
    chimney(-.86,.56,1.91,.48)
    # Wheel stands in YZ plane, visible on the right side of the mill.
    for xx in [.99,1.24]:
        obj=ring("Open oak waterwheel rim",0,0,0,.74,.61,.065,"wood",16)
        obj.rotation_euler.y=math.pi/2; obj.location=(xx,.03,.89)
        for i in range(8):
            a=i*math.tau/8
            beam("Waterwheel radial spoke",(xx,.03,.89),(xx,.03+math.cos(a)*.66,.89+math.sin(a)*.66),.035,"wood_light")
    for i in range(16):
        a=i*math.tau/16
        obj=box("Wide waterwheel paddle",(1.14,.03+math.cos(a)*.70,.89+math.sin(a)*.70),(.38,.17,.075),"wood_honey",.004)
        obj.rotation_euler.x=a
    beam("Mill wheel axle",(.42,.03,.89),(1.38,.03,.89),.095,"wood")
    cylinder("Spare circular millstone",(-.71,-1.03,.16),.29,.18,"stone_light",14)
    ring("Millstone central iron socket",-.71,-1.03,.25,.067,.031,.01,"iron",10)
    for x,y in [(-.12,-1.01),(.29,-.89)]: sphere("Linen flour sack",(x,y,.29),(.17,.15,.25),"canvas")


def bakery():
    plot(2.85,2.66)
    house_shell(-.39,.38,1.45,1.44,1.42)
    door(-.71,-.36,height=.87)
    window(-.02,-.361,1.02,shutters=False)
    # Outdoor masonry oven has a dark front mouth and its own tall flue.
    box("Bread oven stone hearth",(.83,.06,.27),(.83,.94,.41),"stone_dark",.015)
    sphere("Round clay bread oven dome",(.83,.13,.59),(.48,.48,.44),"roof_dark")
    box("Dark oven mouth",(.83,-.319,.54),(.38,.025,.29),"dark",.025)
    for x in [.60,1.06]: box("Oven mouth stone jamb",(x,-.33,.52),(.105,.14,.35),"stone",.01)
    box("Oven mouth lintel",(.83,-.33,.73),(.55,.14,.12),"stone_light",.012)
    chimney(.92,.40,.82,1.20)
    table(-.34,-.93,1.10,.53,.46)
    for i in range(5):
        x=-.74+i*.20
        sphere("Golden fresh loaf",(x,-.94,.56),(.084,.16,.082),"grain")
        for j in range(3): beam("Pale diagonal loaf score",(x-.03,-1.03+j*.08,.626),(x+.035,-1.0+j*.08,.626),.009,"grain_light")
    beam("Long baker peel handle",(.33,-1.13,.15),(1.12,-.62,.81),.023,"wood_light")
    box("Baker peel blade",(1.13,-.61,.83),(.22,.25,.035),"wood_light",.014)
    barrel(-1.14,-.52,r=.13,h=.34,filled="cream")


def winery():
    plot(3.0,2.8)
    house_shell(-.47,.44,1.54,1.42,1.43,True)
    door(-.73,-.285,height=.91,width=.40)
    window(-.02,-.29,1.06,shutters=False)
    # Big screw press on the visible side: uprights, horizontal beam and vat.
    barrel(.83,-.36,r=.39,h=.49)
    for x in [.37,1.28]: box("Wine press heavy upright",(x,-.32,.82),(.14,.15,1.49),"wood",.008)
    box("Wine press crossbeam",(.83,-.32,1.54),(1.14,.20,.17),"wood_light",.008)
    cylinder("Wooden vertical press screw",(.83,-.32,1.16),.07,.78,"wood",10)
    for z in [.84,.95,1.06,1.17,1.28,1.39]: ring("Broad screw thread",.83,-.32,z,.09,.062,.026,"wood_light",10)
    cylinder("Press follower board",(.83,-.32,.68),.31,.075,"wood_light",12)
    beam("Press turning handle",(.50,-.32,1.11),(1.16,-.32,1.11),.034,"wood_honey")
    for x,y in [(-.88,-.89),(-.40,-.94),(-1.13,-.31)]: barrel(x,y,r=.18,h=.39)
    jar(.78,-1.02,r=.12,h=.26)


def potter():
    plot(2.9,2.65)
    shed(-.58,.51,1.38,1.21,1.33)
    cylinder("Round pottery firing kiln",(.80,.50,.54),.46,.93,"roof_dark",12)
    ring("Kiln top masonry rim",.80,.50,1.005,.46,.29,.12,"stone_dark",12)
    cylinder("Dark kiln opening",(.80,.50,1.025),.285,.014,"dark",12)
    box("Kiln lower fire mouth",(.80,.044,.31),(.32,.028,.26),"dark",.02)
    table(-.59,-.72,.97,.47,.49)
    for i in range(3): jar(-.89+i*.30,-.72,.527,.09,.21+i*.035)
    cylinder("Potter wheel base",(.55,-.74,.15),.23,.17,"stone_dark",12)
    cylinder("Potter wheel spindle",(.55,-.74,.32),.05,.24,"wood",10)
    cylinder("Potter turning wheel",(.55,-.74,.44),.28,.05,"wood_light",14)
    jar(.55,-.74,.47,.12,.24)
    for x,y,r,h in [(1.08,-.70,.18,.40),(1.13,-1.11,.12,.25),(-1.13,-1.08,.15,.30)]: jar(x,y,.07,r,h)


def smith():
    plot(3.0,2.7)
    house_shell(-.60,.43,1.31,1.38,1.38)
    door(-.69,-.277,height=.87)
    chimney(-.34,.67,1.67,1.02)
    lean_to(.75,.11,1.34,1.47,1.72,.31,"wood_light")
    for x in [.10,1.36]: box("Forge canopy post",(x,-.69,.69),(.10,.10,1.27),"wood",.005)
    box("Forge stone hearth",(.70,.47,.35),(.81,.63,.55),"stone_dark",.013)
    box("Coal in forge",(.70,.47,.64),(.62,.46,.045),"dark",.005)
    for x,y in [(.49,.42),(.71,.56),(.87,.37)]: sphere("Hot forge ember",(x,y,.69),(.07,.065,.05),"roof_light")
    cylinder("Anvil oak stump",(.66,-.82,.27),.23,.40,"wood",9)
    box("Anvil foot",(.66,-.82,.50),(.40,.27,.08),"iron",.01)
    box("Anvil waist",(.66,-.82,.60),(.22,.20,.15),"iron",.005)
    box("Anvil face",(.66,-.82,.71),(.50,.25,.10),"iron",.008)
    mesh("Forged anvil tapered horn",[(.89,-.945,.67),(.89,-.695,.67),(.89,-.945,.76),(.89,-.695,.76),(1.17,-.82,.72)],[(0,1,3,2),(0,4,1),(2,3,4),(0,2,4),(1,4,3)],"iron")
    table(-.57,-.98,.88,.39,.48)
    for i in range(3): box("Stacked iron bar",(-.62,-1.08+i*.10,.54),(.65,.06,.05),"iron",.004)
    beam("Smith hammer handle",(.24,-.91,.13),(.40,-.65,.55),.023,"wood_light")
    box("Smith hammer head",(.40,-.65,.57),(.18,.095,.10),"iron",.009)


def weaver():
    plot(2.95,2.7)
    house_shell(-.59,.45,1.32,1.33,1.47)
    door(-.81,-.234,height=.85)
    window(-.24,-.235,1.11,shutters=False,width=.22,height=.27)
    # Open loom frame and taut linen warp visible from the camera.
    for x in [.23,1.22]:
        for y in [-.90,-.05]: box("Loom upright",(x,y,.64),(.09,.09,1.10),"wood",.005)
        box("Loom lower side beam",(x,-.47,.25),(.08,1.0,.10),"wood_light",.004)
    for z,y in [(.35,-.90),(1.13,-.06),(.72,-.90)]:
        beam("Loom wooden roller",(.18,y,z),(1.27,y,z),.055,"wood_light")
    for i in range(14):
        x=.29+i*.067
        beam("Individual cream warp thread",(x,-.88,.73),(x,-.06,1.11),.009,"canvas")
    mesh("Woven linen on loom",[(.27,-.89,.73),(1.19,-.89,.73),(1.19,-.51,.91),(.27,-.51,.91)],[(0,1,2,3)],"canvas")
    box("Linen hanging over cloth roller",(.73,-.945,.54),(.91,.022,.36),"canvas",.001)
    for i in range(3): box("Blue woven cloth stripe",(.49+i*.19,-.959,.54),(.06,.006,.35),"cloth",0)
    table(-.69,-.93,.80,.47,.49)
    for i in range(3):
        obj=cylinder("Rolled woven bolt",(-.91+i*.23,-.92,.63),.095,.38,"canvas" if i%2==0 else "cloth",10)
        obj.rotation_euler.x=math.pi/2
    barrel(1.14,.73,r=.15,h=.31,filled="canvas")
    shrub(-1.15,.92,scale=.7)


BUILDERS={name:globals()[name] for name in ["saltworks","quarry","claypit","mine","sheep","vineyard","mill","bakery","winery","potter","smith","weaver"]}
if __name__ == "__main__":
    requested=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else list(BUILDERS)
    for name in requested:
        reset()
        BUILDERS[name]()
        render(name,512,export_model=True)
