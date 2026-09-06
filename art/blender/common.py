"""One Blender art pipeline: matte sRGB palette, flat meshes, orthographic thumbnails.

Sources remain separated and editable. Static GLB exports are joined for efficient
instancing; animated citizens retain their named hierarchy. Blender units are metres.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HEX = {
    "stone": "beae92", "stone_light": "d2c2a5", "stone_dark": "a79982", "cream": "e7d7b8",
    "masonry_warm": "c4b294", "masonry_pale": "cfc0a5", "mortar": "968b77",
    "stone_wet": "9e937f", "moss": "546545", "lichen": "999d70", "earth": "84765f",
    "granite": "beae92", "granite_light": "d2c2a5", "granite_shadow": "a79982",
    "roof": "d8754c", "roof_light": "e58155", "roof_dark": "bd603e",
    "wood": "825b38", "wood_light": "aa7c4c", "wood_end": "d4aa75",
    "wood_honey": "b98956", "rope": "c7a16b", "iron": "61645c",
    "flower": "d76843", "flower_light": "eed591", "water_light": "69b9b7",
    "dark": "3d403b", "water": "449dac", "green": "72934b",
    "grain": "e9ad3e", "grain_light": "f8cc65", "grain_dark": "c88c2c",
    "salt": "f1efe7", "fish": "6599b0", "fish_light": "a2c4cf",
    "fish_dark": "406a80", "gold": "edb23c", "gold_light": "ffd267",
    "ground": "c5b07d", "leaf_olive": "88a454", "leaf_sage": "a0b764",
    "leaf_forest": "446f45", "canvas": "f4e5c6", "timber_honey": "ab7c4c",
    "slate": "6b7688", "skin": "d6ae83", "cloth": "668690",
}

# Keep the user's design prompt as the single source for principal swatches.
STYLE = json.loads((ROOT / "docs/design-style.json").read_text())
for family, keys in {
    "stone": ("stone_light", "stone", "stone_dark"),
    "terracotta": ("roof", "roof_dark", "roof_light"),
    "wood": ("wood_light", "wood", "wood_honey"),
    "vegetation": ("green", "leaf_olive", "leaf_forest"),
    "water": ("water_light", "water"), "fish": ("fish", "fish_light"),
    "grain": ("grain", "grain_light"), "corn": ("corn", "corn_leaf"),
    "salt": ("salt", "salt_shadow"), "iron": ("iron", "iron_dark"),
    "coins": ("gold", "gold_light"),
}.items():
    HEX.update(zip(keys, (value.lstrip("#") for value in STYLE["palette"][family])))

# Warm sand/greige stone follows the user's Pontevedra photo, with lower value
# than the original cream palette. Dampness does not turn the mineral green.
# Quarried stone, bridge masonry and boulders share the same granite swatches.
# Cream is reserved for linen and other light props, not building stone.
HEX.update(granite=HEX["stone"], granite_light=HEX["stone_light"], granite_shadow=HEX["stone_dark"])

def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4

PALETTE = {key: tuple(linear(int(value[i:i+2],16)/255) for i in (0,2,4))+(1,)
           for key,value in HEX.items()}


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
        for block in list(collection):
            if block.users == 0: collection.remove(block)
    bpy.context.preferences.filepaths.save_version = 0


def mat(name):
    material = bpy.data.materials.get(name)
    if material: return material
    material = bpy.data.materials.new(name)
    material.diffuse_color = PALETTE[name]
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = PALETTE[name]
    mineral = name in {"stone", "stone_light", "stone_dark", "stone_wet", "mortar",
                       "masonry_warm", "masonry_pale", "granite", "granite_light", "granite_shadow"}
    bsdf.inputs["Roughness"].default_value = .78 if name == "stone_wet" else (.96 if mineral else .9)
    bsdf.inputs["Specular IOR Level"].default_value = .10 if mineral else .18
    return material


def finish(obj, material):
    obj.data.materials.append(mat(material))
    return obj


def mesh(name, vertices, faces, material="cream"):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, material)


def box(name, location, scale, material="cream", bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, material)
    if bevel:
        modifier = obj.modifiers.new("Single cut edges", "BEVEL")
        modifier.width = min(bevel, min(scale)*.22)
        modifier.segments = 1
        obj.modifiers.new("Broad face normals", "WEIGHTED_NORMAL")
    return obj


def cylinder(name, location, radius, depth, material="wood", vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, material)


def sphere(name, location, scale, material="green"):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish(obj, material)


def beam(name, start, end, radius=.04, material="wood"):
    a,b = Vector(start),Vector(end)
    obj = cylinder(name,(a+b)/2,radius,(b-a).length,material,8)
    obj.rotation_euler = (b-a).to_track_quat("Z","Y").to_euler()
    return obj


def render(name, resolution=512, export_model=False, output_root=ROOT):
    output_root = Path(output_root)
    for folder in ["assets/ui", "assets/models", "art/blender"]:
        (output_root/folder).mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    for obj in meshes: obj.pass_index = 1
    bpy.context.view_layer.use_pass_object_index = True
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(v) for obj in meshes for v in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (low+high)/2
    azimuth = math.radians(STYLE["camera"]["horizontal_rotation_degrees"])
    elevation = math.radians(STYLE["camera"]["elevation_degrees"])
    direction = Vector((math.sin(azimuth)*math.cos(elevation),
                        -math.cos(azimuth)*math.cos(elevation), math.sin(elevation)))
    bpy.ops.object.camera_add(location=center+direction*12)
    camera = bpy.context.object
    camera.name = "Collection orthographic camera"
    camera.rotation_euler = (center-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type = "ORTHO"
    inverse = camera.rotation_euler.to_matrix().transposed()
    projected = [inverse @ (point-center) for point in points]
    width = max(p.x for p in projected)-min(p.x for p in projected)
    height = max(p.y for p in projected)-min(p.y for p in projected)
    camera.data.ortho_scale = max(width,height)/.74
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=center+Vector((-3,-4,10)))
    key = bpy.context.object
    key.name = "Soft daylight"
    key.data.energy = 700
    key.data.shape = "DISK"
    key.data.size = 5
    key.rotation_euler = (center-key.location).to_track_quat("-Z","Y").to_euler()
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (.93,.95,1,1)
    bg.inputs["Strength"].default_value = .8
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.filepath = str(output_root/"assets/ui"/(name+".png"))
    # Ground only catches shadows in the thumbnail, never exported to the game.
    bpy.ops.mesh.primitive_plane_add(size=max(high-low)*200, location=(0,0,low.z-.015))
    ground = bpy.context.object
    ground.name = "Thumbnail shadow catcher (not exported)"
    ground.is_shadow_catcher = True
    finish(ground,"cream")
    # Cycles' shadow catcher can leave 1–8/255 alpha noise across the entire
    # transparent film. Remove that floor in Blender's compositor, retaining
    # opaque geometry and smoothly remapping the visible contact shadows.
    compositor = bpy.data.node_groups.new("Clean transparent film", "CompositorNodeTree")
    compositor.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    scene.compositing_node_group = compositor
    layers = compositor.nodes.new("CompositorNodeRLayers")
    subtract = compositor.nodes.new("ShaderNodeMath")
    subtract.operation = "SUBTRACT"
    subtract.inputs[1].default_value = .12
    divide = compositor.nodes.new("ShaderNodeMath")
    divide.operation = "DIVIDE"
    divide.inputs[1].default_value = .88
    divide.use_clamp = True
    alpha = compositor.nodes.new("CompositorNodeSetAlpha")
    alpha.inputs["Type"].default_value = "Replace Alpha"
    output = compositor.nodes.new("NodeGroupOutput")
    compositor.links.new(layers.outputs["Alpha"], subtract.inputs[0])
    compositor.links.new(subtract.outputs[0], divide.inputs[0])
    compositor.links.new(layers.outputs["Image"], alpha.inputs["Image"])
    # Keep opaque geometry intact while making the studio floor's shadow subtle.
    geometry_mask = compositor.nodes.new("CompositorNodeIDMask")
    geometry_mask.inputs["Index"].default_value = 1
    geometry_mask.inputs["Anti-Alias"].default_value = True
    compositor.links.new(layers.outputs["Object Index"], geometry_mask.inputs[0])
    shadow_opacity = compositor.nodes.new("ShaderNodeMath")
    shadow_opacity.operation = "MULTIPLY"
    shadow_opacity.inputs[1].default_value = .38
    compositor.links.new(divide.outputs[0], shadow_opacity.inputs[0])
    coverage = compositor.nodes.new("ShaderNodeMath")
    coverage.operation = "MAXIMUM"
    compositor.links.new(shadow_opacity.outputs[0], coverage.inputs[0])
    compositor.links.new(geometry_mask.outputs[0], coverage.inputs[1])
    # Shadows fade inside a small safe frame instead of being cut by the PNG
    # edge. The model occupies at most 77% of the frame and remains untouched.
    frame = compositor.nodes.new("CompositorNodeBoxMask")
    frame.inputs["Position"].default_value = (.5,.5)
    frame.inputs["Size"].default_value = (.92,.92)
    feather = compositor.nodes.new("CompositorNodeBlur")
    feather.inputs["Size"].default_value = (resolution*.016,resolution*.016)
    multiply = compositor.nodes.new("ShaderNodeMath")
    multiply.operation = "MULTIPLY"
    compositor.links.new(frame.outputs[0], feather.inputs["Image"])
    compositor.links.new(feather.outputs[0], multiply.inputs[1])
    compositor.links.new(coverage.outputs[0], multiply.inputs[0])
    compositor.links.new(multiply.outputs[0], alpha.inputs["Alpha"])
    compositor.links.new(alpha.outputs["Image"], output.inputs["Image"])
    bpy.ops.wm.save_as_mainfile(filepath=str(output_root/"art/blender"/(name+".blend")))
    if export_model:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes: obj.select_set(True)
        if name == "citizen":
            # Include arm/leg Empty pivots in the export selection.
            for obj in scene.objects:
                if obj.type == "EMPTY": obj.select_set(True)
        else:
            # Apply modifiers to copies, retaining fully editable .blend sources.
            bpy.context.view_layer.objects.active = meshes[0]
            bpy.ops.object.duplicate()
            bpy.ops.object.convert(target="MESH")
            bpy.ops.object.join()
            bpy.context.object.name = name
        bpy.ops.export_scene.gltf(filepath=str(output_root/"assets/models"/(name+".glb")),
                                  use_selection=True, export_apply=True)
        if name != "citizen":
            bpy.ops.object.delete(use_global=False)
    bpy.ops.render.render(write_still=True)
