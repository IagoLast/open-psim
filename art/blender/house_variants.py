"""Nine authored housing silhouettes, built identically through Blender MCP or CLI.
Front -Y, Z up, common 2.4m plot; recipes keep the three gameplay levels.
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, reset, box, mesh, render
from buildings import house_shell, door, window, chimney, shrub, lean_to, barrel
from variants import signature

RECIPES = {
    'house_cottage_long': ('house_cottage', 'Casa de labranza', 'long'),
    'house_cottage_porch': ('house_cottage', 'Casita con porche', 'porch'),
    'house_cottage_annex': ('house_cottage', 'Casita con anexo', 'annex'),
    'house_stairs': ('house', 'Casa con patín', 'stairs'),
    'house_balcony': ('house', 'Casa con balcón', 'balcony'),
    'house_annex': ('house', 'Casa con cobertizo', 'annex'),
    'house_tall_gallery': ('house_tall', 'Galería acristalada', 'gallery'),
    'house_tall_arcade': ('house_tall', 'Casa de soportales', 'arcade'),
    'house_tall_veranda': ('house_tall', 'Galería abierta', 'veranda'),
}


def base():
    box('Square miniature plot', (0, 0, .026), (2.4, 2.4, .052), 'ground', .035)
    for x,y,w,d in [(-.92,.55,.47,.82),(.84,.71,.65,.7),(-.79,-.88,.64,.4)]:
        box('Muted olive patch', (x,y,.055), (w,d,.008), 'leaf_olive', .015)
    for i in range(3):
        box('Entrance paving', (-.30,-1.07+i*.18,.063), (.38,.17,.022), 'stone_light', .01)


def panes(x,y,z,w=.25,h=.34,side=False):
    window(x,y,z,side=side,shutters=False,width=w,height=h)


def side_door(x,y,z=.075,h=.76):
    before=set(bpy.context.scene.objects)
    door(0,0,bottom=z,height=h,width=.33)
    bpy.context.view_layer.update()
    transform=Matrix.Translation((x,y,0)) @ Matrix.Rotation(math.pi/2,4,'Z')
    for obj in set(bpy.context.scene.objects)-before:
        obj.matrix_world=transform @ obj.matrix_world


def rail(x,y,z,w,depth=.38):
    box('Balcony floor', (x,y,z), (w,depth,.09), 'wood', .008)
    front=y-depth/2
    for zz in [z+.13,z+.46]:
        box('Continuous balcony rail', (x,front,zz), (w+.035,.055,.055), 'wood_light', .006)
    for i in range(round(w/.15)+1):
        xx=x-w/2+w*i/round(w/.15)
        box('Balcony spindle',(xx,front,z+.29),(.035,.035,.33),'wood',.004)
    for xx in [x-w/2,x+w/2]:
        box('Balcony end rail',(xx,y,z+.46),(.055,depth,.055),'wood_light',.004)
        box('Balcony end spindle',(xx,y,z+.29),(.035,.035,.33),'wood',.004)


def gallery(x,y,z,w,glazed=True,columns=False):
    depth=.43
    rail(x,y,z,w,depth)
    front=y-depth/2
    for i in range(6):
        xx=x-w/2+w*i/5
        box('Gallery oak upright',(xx,front,z+.49),(.052,.055,.94),'wood',.004)
        if glazed and i<5:
            box('Muted blue gallery glass',(xx+w/10,front+.025,z+.69),(w/5-.053,.021,.42),'fish',.002)
    for zz in [z+.51,z+.74,z+.98]:
        box('Gallery horizontal frame',(x,front,zz),(w+.07,.06,.04),'wood_light',.003)
    for xx in [x-w/2,x+w/2]:
        box('Gallery upper side beam',(xx,y,z+.98),(.06,depth,.055),'wood',.004)
        if glazed:
            box('Gallery side glazing',(xx,y,z+.7),(.02,depth-.065,.42),'fish_dark',.002)
        if columns:
            box('Veranda granite support',(xx,front,.065+(z-.065)/2),(.13,.15,z-.065),'stone_light',.006)
            box('Veranda pillar foot',(xx,front,.16),(.21,.23,.19),'stone',.008)


def stairs(x,y,landing=1.13):
    # Ascends away from the street to the right-hand entrance.
    count=7
    for i in range(count):
        h=(landing-.065)*(i+1)/count
        box('Solid exterior granite step',(x,y+i*.145,.065+h/2),(.43,.15,h),'stone_light',.005)
    return y+(count-1)*.145


def arcade():
    # Two actual open arches: voussoir strips bridge clear ground-floor bays.
    front=-.69
    for x in [-.81,0,.81]:
        box('Arcade stone pier',(x,front,.435),(.19,.25,.74),'stone',.008)
        box('Arcade pier base',(x,front,.115),(.25,.3,.10),'stone_light',.005)
    for cx in [-.405,.405]:
        radius=.31
        for i in range(9):
            a=i*math.pi/9; b=(i+1)*math.pi/9
            corners=[(cx+radius*math.cos(a),.69+radius*math.sin(a)),
                     (cx+radius*math.cos(b),.69+radius*math.sin(b)),
                     (cx+radius*math.cos(b),1.14),(cx+radius*math.cos(a),1.14)]
            verts=[(x,yy,z) for yy in [front-.125,front+.125] for x,z in corners]
            mesh('Cut stone arch voussoir',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'stone_light' if i%3==0 else 'stone')
    box('Recessed arcade rear wall',(0,.61,.6),(1.82,.18,1.07),'stone',.008)
    for x in [-.82,.82]:
        box('Arcade side return',(x,.09,.6),(.18,1.1,1.07),'stone',.008)
    door(-.32,.508,height=.79)
    barrel(.38,.28,r=.14,h=.31)


def build(name):
    if name not in RECIPES: raise ValueError(name)
    reset()
    family,label,style=RECIPES[name]
    base()
    if family=='house_cottage':
        if style=='long':
            x,y,w,d,h=0,.12,1.91,1.18,1.12
        elif style=='porch':
            x,y,w,d,h=0,.29,1.48,1.32,1.3
        else:
            x,y,w,d,h=-.25,.17,1.28,1.34,1.25
        z,rise=house_shell(x,y,w,d,h,True)
        door(x-.26,y-d/2-.014,height=.74,width=.32)
        if style=='long':
            for xx in [-.68,.60]: panes(xx,y-d/2-.014,.79,w=.23,h=.28)
        elif style=='porch':
            panes(.40,y-d/2-.014,.89,w=.24,h=.3)
            lean_to(0,-.64,.93,1.65,.88,.35,'roof')
            for xx in [-.70,.70]: box('Porch oak post',(xx,-1.03,.49),(.075,.075,.86),'wood',.005)
            box('Porch lintel',(0,-1.03,.92),(1.53,.09,.09),'wood_light',.005)
            barrel(.48,-.63,r=.13,h=.28)
        else:
            house_shell(.68,.02,.61,.91,.76,True)
            door(.68,-.449,height=.59,width=.24)
        panes(x+w/2+.018,y+(.47 if style=='annex' else .18),.83,side=True,w=.24,h=.30)
        chimney(x+w*.25,y+.28,z+rise*.5,.47)
    elif family=='house':
        x=-.19 if style in ('stairs','annex') else 0
        w=1.34 if style in ('stairs','annex') else 1.56
        y=.17; d=1.32; h=1.91
        z,rise=house_shell(x,y,w,d,h,True)
        door(x-.24,y-d/2-.014,height=.73,width=.31)
        for zz in [.64,1.49]:
            panes(x+.35,y-d/2-.014,zz,w=.22,h=.3)
        if style=='stairs':
            end=stairs(.72,-.85,1.10)
            side_door(x+w/2+.018,end,1.10,.69)
            panes(x-.31,y-d/2-.014,1.49,w=.22,h=.3)
        elif style=='balcony':
            door(-.30,y-d/2-.018,bottom=1.10,height=.66,width=.30)
            rail(-.30,-.72,1.08,.73,.43)
            panes(x+w/2+.018,.23,1.49,side=True)
        else:
            house_shell(.76,.19,.55,1.05,.91,True)
            door(.76,-.348,height=.69,width=.25)
            panes(x-.31,y-d/2-.014,1.49,w=.22,h=.3)
            panes(x+w/2+.018,.63,1.49,side=True)
        chimney(x+.24,.49,z+rise*.45,.48)
    else:
        if style=='arcade':
            arcade()
            before=set(bpy.context.scene.objects)
            z,rise=house_shell(0,.01,1.82,1.40,1.18,True)
            for obj in set(bpy.context.scene.objects)-before: obj.location.z+=1.055
            z+=1.055
            for xx in [-.47,.42]: panes(xx,-.706,1.73,w=.28,h=.41)
            for zz in [1.73]: panes(.928,.14,zz,side=True,w=.27,h=.41)
        else:
            z,rise=house_shell(0,.20,1.68,1.45,2.20,True)
            door(-.28,-.539,height=.78,width=.34)
            panes(.43,-.539,.66,w=.24,h=.30)
            door(-.28,-.539,bottom=1.23,height=.73,width=.33)
            # Gallery top meets the roof eave. A clay lean-to seals the overhang.
            gallery(0,-.69,1.18,1.75,style=='gallery',style=='veranda')
            lean_to(0,-.70,2.17,1.93,.58,.19,'roof')
            panes(.858,.28,.66,side=True)
            panes(.858,.28,1.70,side=True)
        chimney(.38,.48,z+rise*.45,.51)
    for x,y,s in [(-.94,.79,.78),(.95,.82,.95),(.83,-.82,.55)]:
        if style=='stairs' and y<0: continue
        shrub(x,y,scale=s)
    bpy.context.scene['variant_recipe']=json.dumps(dict(schema=1,family=family,style=style,label=label,generator='house_variants.py'))
    bpy.context.view_layer.update()
    pts=[o.matrix_world @ Vector(v) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.bound_box]
    assert all(abs(p.x)<=1.205 and abs(p.y)<=1.205 and p.z>=-.001 for p in pts), 'Outside housing plot'
    return signature()


def generate(name, output_root=ROOT):
    digest=build(name)
    render(name,512,export_model=True,output_root=output_root)
    return dict(family=RECIPES[name][0],style=RECIPES[name][2],label=RECIPES[name][1],
                generator='art/blender/house_variants.py',geometry_digest=digest)


def publish(records, output_root=ROOT):
    path=Path(output_root)/'data/model_variants.json'
    manifest=json.loads(path.read_text()) if path.exists() else dict(schema=1,selection_version=1,families={},models={})
    manifest['models'].update(records)
    for family in ['house_cottage','house','house_tall']:
        manifest['families'][family]=[family]+[name for name,r in RECIPES.items() if r[0]==family]
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')


def start_mcp_queue():
    """Yield between assets so the interactive MCP connection stays responsive."""
    import traceback
    queue=list(RECIPES)
    records={}
    progress=ROOT/'build/house-generation.json'
    progress.parent.mkdir(parents=True,exist_ok=True)
    def next_house():
        try:
            if not queue:
                publish(records)
                progress.write_text(json.dumps(dict(done=True,models=records)))
                return None
            name=queue.pop(0)
            records[name]=generate(name)
            progress.write_text(json.dumps(dict(done=False,finished=list(records),remaining=queue)))
            return .2
        except Exception:
            progress.write_text(json.dumps(dict(error=traceback.format_exc())))
            return None
    progress.write_text(json.dumps(dict(done=False,finished=[],remaining=queue)))
    bpy.app.timers.register(next_house,first_interval=1.0)


def review_scene():
    """Leave an editable, organised contact sheet open in the connected Blender."""
    reset()
    scene=bpy.context.scene
    for collection in list(bpy.data.collections):
        if not collection.objects: bpy.data.collections.remove(collection)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/house_variants_review.blend'))
    right=Vector((1,1,0)).normalized()
    back=Vector((-1,1,0)).normalized()
    for i,(name,(_,label,_)) in enumerate(RECIPES.items()):
        collection=bpy.data.collections.new(label)
        scene.collection.children.link(collection)
        with bpy.data.libraries.load(str(ROOT/'art/blender'/f'{name}.blend'),link=False) as (source,target):
            target.objects=[n for n in source.objects if not n.startswith(('Thumbnail shadow','Collection orthographic','Soft daylight'))]
        offset=right*((i%3-1)*3.6)+back*((1-i//3)*4.4)
        for obj in target.objects:
            if obj is not None and obj.type=='MESH':
                collection.objects.link(obj)
                obj.location+=offset
    bpy.ops.object.camera_add(location=(12,-12,16))
    camera=bpy.context.object
    camera.name='Housing collection camera'
    camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=15.2
    scene.camera=camera
    scene.render.resolution_x=1536
    scene.render.resolution_y=1536
    scene.render.resolution_percentage=100
    scene.compositing_node_group=None
    scene.render.film_transparent=False
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.78,.70,.52,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,13))
    bpy.context.object.data.energy=1800
    bpy.context.object.data.shape='DISK'
    bpy.context.object.data.size=9
    bpy.context.object.rotation_euler=(Vector((0,0,0))-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.select_all(action='DESELECT')
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active
                space.region_3d.view_perspective='CAMERA'
                space.region_3d.view_camera_zoom=28
                space.shading.type='MATERIAL'
                space.shading.use_scene_world=False
                space.overlay.show_overlays=False
    scene['collection_notes']='Nine authored variants; each collection contains editable components. Front -Y, shared 2.4m plot. See house_variants.py.'
    if 'variant_recipe' in scene: del scene['variant_recipe']
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/house_variants_review.blend'))
    print('Editable review scene saved: nine collections')


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if args==['--check']:
        for name in RECIPES:
            a=build(name)
            assert a==build(name), f'Not repeatable: {name}'
            print('HOUSING OK',name)
    else:
        records={name:generate(name) for name in RECIPES}
        publish(records)
        review_scene()

