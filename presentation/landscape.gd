extends Node3D
## Flat playable ground, sculpted banks and deterministic Blender scenery batches.
const Map = preload("res://sim/world_map.gd")
const Models = preload("res://presentation/model_library.gd")
const Variants = preload("res://presentation/model_variants.gd")
const WATER_LEVEL: float = -1.12
const CHUNK_SIZE: int = 16
const COLORS: Dictionary = {
	"land":Color("#aeb889"),"fertile":Color("#99ae73"),"forest":Color("#7f9868"),
	"rock":Color("#ada996"),"clay":Color("#b68c65"),"ore":Color("#92968c")
}
var terrain: Array
var map_size: int
var ground: MeshInstance3D
var distances := PackedInt32Array()
var batches: Dictionary = {}
var placements: Dictionary = {}
static var scenery_meshes: Dictionary = {}
static var scenery_materials: Dictionary = {}
var world_seed: int = 1530
var overview: bool = false

func setup(snapshot: Dictionary) -> void:
	world_seed = snapshot.seed
	terrain = snapshot.terrain
	map_size = snapshot.map_size
	_build_distances()
	_build_ground()
	_build_water()
	var bridge: Node3D = Models.create_variant("bridge_stone",world_seed,"burgo-bridge")
	bridge.name = "BurgoBridge"
	bridge.position = Vector3(Map.BURGO_BRIDGE.get_center().x,-1.55,Map.BURGO_BRIDGE.get_center().y)
	add_child(bridge)
	_scatter()
	_commit_batches()

func _is_water(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= map_size or z >= map_size: return true
	return terrain[z*map_size+x] == "water" or Map.BURGO_BRIDGE.has_point(Vector2i(x,z))

func _build_distances() -> void:
	distances.resize(map_size*map_size)
	distances.fill(999)
	var queue := PackedInt32Array()
	for z: int in range(map_size):
		for x: int in range(map_size):
			if not _is_water(x,z):
				var cell: int = z*map_size+x
				distances[cell] = 0
				queue.append(cell)
	var head: int = 0
	while head < queue.size():
		var cell: int = queue[head]
		head += 1
		var p := Vector2i(cell%map_size,cell/map_size)
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = p+direction
			if next.x < 0 or next.y < 0 or next.x >= map_size or next.y >= map_size: continue
			var index: int = next.y*map_size+next.x
			if distances[index] <= distances[cell]+1: continue
			distances[index] = distances[cell]+1
			queue.append(index)

func _corner(x: int, z: int, lower: bool = false) -> Vector3:
	var toward_land := Vector2.ZERO
	var count: int = 0
	for dz: int in [-1,0]:
		for dx: int in [-1,0]:
			if not _is_water(x+dx,z+dz):
				count += 1
				toward_land += Vector2(dx+0.5,dz+0.5)
	var offset := Vector2.ZERO
	if count == 1: offset = toward_land*0.40
	elif count == 3: offset = toward_land*-0.40
	if lower and count > 0 and count < 4: offset -= toward_land.normalized()*0.30
	return Vector3(x+offset.x,-1.32 if lower else -0.02,z+offset.y)

func _color_at(x: int, z: int) -> Color:
	var color := Color(0,0,0,0)
	var count: float = 0.0
	for dz: int in [-1,0]:
		for dx: int in [-1,0]:
			if _is_water(x+dx,z+dz): continue
			color += COLORS[terrain[(z+dz)*map_size+x+dx]]
			count += 1.0
	if count == 0: return COLORS.land
	color /= count
	var variation: float = sin(x*0.39+sin(z*0.21))*cos(z*0.32)*0.035
	return color.lightened(variation) if variation > 0 else color.darkened(-variation)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var normal: Vector3 = (c-a).cross(b-a).normalized()
	for i: int in range(3):
		surface.set_normal(normal)
		surface.set_color([ca,cb,cc][i].srgb_to_linear())
		surface.add_vertex([a,b,c][i])

func _build_ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var banks := SurfaceTool.new()
	banks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(map_size):
		for x: int in range(map_size):
			if _is_water(x,z): continue
			var corners: Array[Vector3] = [_corner(x,z),_corner(x+1,z),_corner(x+1,z+1),_corner(x,z+1)]
			var colors: Array[Color] = [_color_at(x,z),_color_at(x+1,z),_color_at(x+1,z+1),_color_at(x,z+1)]
			_triangle(surface,corners[0],corners[2],corners[3],colors[0],colors[2],colors[3])
			_triangle(surface,corners[0],corners[1],corners[2],colors[0],colors[1],colors[2])
			var grid: Array[Vector2i] = [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]
			var neighbors: Array[Vector2i] = [Vector2i(x,z-1),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x-1,z)]
			for edge: int in range(4):
				if not _is_water(neighbors[edge].x,neighbors[edge].y): continue
				var next: int = (edge+1)%4
				var a: Vector3 = corners[edge]
				var b: Vector3 = corners[next]
				var c: Vector3 = _corner(grid[next].x,grid[next].y,true)
				var d: Vector3 = _corner(grid[edge].x,grid[edge].y,true)
				var mid_a: Vector3 = a.lerp(d,0.20)
				var mid_b: Vector3 = b.lerp(c,0.20)
				var soil: Color = Color("#a79772").lightened(sin(x*1.7+z)*0.04)
				var wet := Color("#777b67")
				_triangle(banks,a,mid_b,b,colors[edge],soil,colors[next])
				_triangle(banks,a,mid_a,mid_b,colors[edge],soil,soil)
				_triangle(banks,mid_a,c,mid_b,soil,wet,soil)
				_triangle(banks,mid_a,d,c,soil,wet,wet)
	ground = MeshInstance3D.new()
	ground.name = "Meadows"
	ground.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/shaders/landscape_ground.gdshader")
	ground.material_override = material
	add_child(ground)
	var shore := MeshInstance3D.new()
	shore.name = "SculptedBanks"
	shore.mesh = banks.commit()
	shore.material_override = material
	add_child(shore)

func _build_water() -> void:
	var distance_image := Image.create(map_size,map_size,false,Image.FORMAT_R8)
	for z: int in range(map_size):
		for x: int in range(map_size): distance_image.set_pixel(x,z,Color(minf(distances[z*map_size+x]/8.0,1.0),0,0))
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/shaders/landscape_water.gdshader")
	material.set_shader_parameter("shore_distance",ImageTexture.create_from_image(distance_image))
	material.set_shader_parameter("map_size",float(map_size))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*map_size
	var water := MeshInstance3D.new()
	water.name = "Estuary"
	water.mesh = plane
	water.material_override = material
	water.position = Vector3(map_size/2.0,WATER_LEVEL,map_size/2.0)
	add_child(water)

func _near_shore(x: int, z: int) -> bool:
	return _is_water(x-1,z) or _is_water(x+1,z) or _is_water(x,z-1) or _is_water(x,z+1)

func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	for z: int in range(map_size):
		for x: int in range(map_size):
			var cell: int = z*map_size+x
			if _is_water(x,z): continue
			# Keep the bridge entrances and parapets unobstructed.
			if Map.BURGO_BRIDGE.grow(1).has_point(Vector2i(x,z)): continue
			rng.seed = Variants.stable_seed(world_seed,str(cell),"scatter")
			var kind: String = terrain[cell]
			var chance: float = rng.randf()
			var shore: bool = _near_shore(x,z)
			if kind == "forest" and chance < 0.43:
				var tree_kind: String = ["tree_oak","tree_oak","tree_pine","tree_cypress"][rng.randi_range(0,3)]
				_place(tree_kind,cell,rng,0.76,1.24)
			elif kind in ["land","fertile"] and not shore and chance < 0.012:
				_place("tree_oak" if chance < 0.008 else "tree_pine",cell,rng,0.64,0.95)
			if kind in ["rock","ore"] and chance < 0.48:
				_place("rock_cluster",cell,rng,0.9,1.85)
			elif shore:
				if chance < 0.24: _place("reeds",cell,rng,0.7,1.1,-0.14)
				elif chance < 0.43: _place("rock_cluster",cell,rng,0.55,1.1,-0.12)
			elif kind == "forest" and chance > 0.78:
				_place("gorse" if chance < 0.94 else "rock_cluster",cell,rng,0.6,1.0)
			elif kind in ["land","fertile","clay"]:
				if chance > 0.82: _place("grass_clump",cell,rng,0.8,1.35)
				elif chance > 0.76 and kind != "clay": _place("wildflowers",cell,rng,0.7,1.15)
				elif chance > 0.74: _place("gorse",cell,rng,0.45,0.75)

func _place(kind: String, cell: int, rng: RandomNumberGenerator, low: float, high: float, height: float = 0.0) -> void:
	var x: int = cell%map_size
	var z: int = cell/map_size
	var model_kind: String = Variants.choose(kind,world_seed,str(cell))
	var key: String = "%s:%d:%d" % [model_kind,x/CHUNK_SIZE,z/CHUNK_SIZE]
	if not placements.has(key): placements[key] = []
	var scale_value: float = rng.randf_range(low,high)
	var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_value,scale_value*rng.randf_range(0.92,1.12),scale_value))
	var origin := Vector3(x+rng.randf_range(0.28,0.72),height,z+rng.randf_range(0.28,0.72))
	placements[key].append({"cell":cell,"transform":Transform3D(basis,origin),"tint":rng.randf_range(0.91,1.0 if kind == "rock_cluster" else 1.06)})

func _mesh_for(kind: String) -> ArrayMesh:
	if scenery_meshes.has(kind): return scenery_meshes[kind]
	var model: Node3D = Models.create(kind)
	var parts: Array[MeshInstance3D] = []
	_collect_meshes(model,parts)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Bake materials into vertex colors, so one chunk costs a single draw call.
	# Geometry and face colors still come entirely from the authored Blender mesh.
	for part: MeshInstance3D in parts:
		var transform := Transform3D.IDENTITY
		var current: Node3D = part
		while current != model:
			transform = current.transform*transform
			current = current.get_parent() as Node3D
		for index: int in range(part.mesh.get_surface_count()):
			var source: StandardMaterial3D = part.mesh.surface_get_material(index) as StandardMaterial3D
			var color: Color = source.albedo_color if source != null else Color.WHITE
			var arrays: Array = part.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for vertex_index: int in range(indices.size() if not indices.is_empty() else vertices.size()):
				var i: int = indices[vertex_index] if not indices.is_empty() else vertex_index
				surface.set_color(color)
				surface.set_normal((transform.basis.inverse().transposed()*normals[i]).normalized())
				surface.add_vertex(transform*vertices[i])
	var base_kind: String = Variants.family(kind)
	var wind: float = 0.0 if base_kind == "rock_cluster" else (0.018 if base_kind.begins_with("tree_") else 0.07)
	if not scenery_materials.has(wind):
		var material := ShaderMaterial.new()
		material.shader = preload("res://presentation/shaders/landscape_foliage.gdshader")
		material.set_shader_parameter("wind_strength",wind)
		scenery_materials[wind] = material
	surface.set_material(scenery_materials[wind])
	surface.index()
	var merged: ArrayMesh = surface.commit()
	merged.custom_aabb = merged.get_aabb().grow(0.25)
	model.free()
	scenery_meshes[kind] = merged
	return merged

func _collect_meshes(node: Node3D, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: output.append(node)
	for child: Node in node.get_children():
		if child is Node3D: _collect_meshes(child,output)

func _commit_batches() -> void:
	for key: String in placements:
		var kind: String = key.get_slice(":",0)
		var batch := MultiMeshInstance3D.new()
		batch.name = key.replace(":","_")
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _mesh_for(kind)
		multi.instance_count = placements[key].size()
		for i: int in range(multi.instance_count):
			multi.set_instance_transform(i,placements[key][i].transform)
			var tint: float = placements[key][i].tint
			multi.set_instance_color(i,Color(tint,tint, tint*0.98))
		batch.multimesh = multi
		if Variants.family(kind) in ["grass_clump","wildflowers","reeds","gorse"]:
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		batches[key] = batch

func set_overview(value: bool) -> void:
	if overview == value: return
	overview = value
	for key: String in batches:
		if Variants.family(key.get_slice(":",0)) in ["grass_clump","wildflowers","reeds","gorse"]:
			batches[key].visible = not overview

func sync_occupation(building_cells: Dictionary, roads: Array) -> void:
	var occupied: Dictionary = building_cells.duplicate()
	for cell: int in roads: occupied[cell] = true
	for key: String in placements:
		var multi: MultiMesh = batches[key].multimesh
		var visible_count: int = 0
		for placement: Dictionary in placements[key]:
			var cell: int = placement.cell
			var blocked: bool = occupied.has(cell)
			# Crowns overhang their own tile: leave room around occupied footprints.
			if key.begins_with("tree_"):
				for dz: int in [-1,0,1]:
					for dx: int in [-1,0,1]:
						var x: int = cell%map_size+dx
						var z: int = cell/map_size+dz
						if x >= 0 and x < map_size and z >= 0 and z < map_size and occupied.has(z*map_size+x): blocked = true
			if blocked: continue
			multi.set_instance_transform(visible_count,placement.transform)
			var tint: float = placement.tint
			multi.set_instance_color(visible_count,Color(tint,tint,tint*0.98))
			visible_count += 1
		multi.visible_instance_count = visible_count
