extends Node3D
const Assets = preload("res://presentation/asset_factory.gd")
var camera: Camera3D
var focus: Vector3 = Vector3(70,0,54)
var map_size: int = 128
var ships: Dictionary = {}
var landmarks: Array[Label3D] = []
var buildings: Dictionary = {}
var people: Dictionary = {}
var road_nodes: Node3D
var overlay: Node3D
var preview: Node3D
var terrain_node: MeshInstance3D
var topology: int = -1
var water_view: bool = false
var selected_cell: int = -1
var trees: Dictionary = {}
var building_cells: Dictionary = {}
var hovered_building: int = 0

func _process(_delta: float) -> void:
	if camera == null: return
	var cell: int = cell_at(get_viewport().get_mouse_position()) if get_viewport().gui_get_hovered_control() == null else -1
	var next_hover: int = building_cells.get(cell, 0)
	if next_hover == hovered_building: return
	if buildings.has(hovered_building):
		buildings[hovered_building].get_node("Title").visible = buildings[hovered_building].get_meta("placeholder",false)
		buildings[hovered_building].get_node("Status").hide()
	hovered_building = next_hover
	if buildings.has(hovered_building):
		buildings[hovered_building].get_node("Title").show()
		buildings[hovered_building].get_node("Status").show()

func setup(snapshot: Dictionary) -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30
	camera.far = 500
	add_child(camera)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	update_camera()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	light.light_color = Color("#fffaf3")
	light.light_energy = 0.32
	light.shadow_enabled = true
	light.shadow_opacity = 0.32
	light.shadow_blur = 2.0
	light.directional_shadow_max_distance = 70
	add_child(light)
	# Broad studio fill keeps the unlit facade warm and readable in GL Compatibility.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35,145,0)
	fill.light_color = Color("#fff5e5")
	fill.light_energy = 0.22
	add_child(fill)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#d9d4b8")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#f0ece2")
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	add_child(environment)
	terrain_node = MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors: Dictionary = {"water":Color("#4fabb4"),"land":Color("#b9bd8c"),"fertile":Color("#a8b578"),"forest":Color("#929f70"),"rock":Color("#96999e"),"clay":Color("#c17b57"),"ore":Color("#677787")}
	for cell: int in range(snapshot.terrain.size()):
		var x: int = cell % map_size
		var z: int = cell / map_size
		var color: Color = colors[snapshot.terrain[cell]]
		color = color.lightened(((x*13+z*7)%5)*0.004)
		for offset: Vector3 in [Vector3(0,0,0),Vector3(1,0,1),Vector3(0,0,1),Vector3(0,0,0),Vector3(1,0,0),Vector3(1,0,1)]:
			surface.set_color(color.srgb_to_linear())
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(x,-0.02,z)+offset)
		if snapshot.terrain[cell] == "forest" and (x*7+z*3)%13 == 0:
			var tree_scale: float = 0.82 + (cell % 5) * 0.085
			var tree: Node3D = Assets.scenery("tree_cypress" if cell % 4 == 0 else "tree_oak", float(cell % 7) * 0.8, tree_scale)
			if tree != null:
				tree.position = Vector3(x + 0.5, 0.0, z + 0.5)
				add_child(tree)
				trees[cell] = tree
	terrain_node.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.roughness = 1.0
	terrain_node.material_override = mat
	add_child(terrain_node)
	Assets.box(self,Vector3(map_size,0.5,map_size),Vector3(map_size/2.0,-0.31,map_size/2.0),Color("#9b9473"))
	for landmark: Dictionary in preload("res://sim/world_map.gd").LANDMARKS:
		var title: Label3D = Assets.label(self,landmark.label,Vector3(landmark.x,0.3,landmark.z),32)
		landmarks.append(title)
		title.visible = false
		title.pixel_size = 0.035
		title.modulate = Color("#ecdfb9")
	road_nodes = Node3D.new()
	add_child(road_nodes)
	overlay = Node3D.new()
	add_child(overlay)
	preview = Node3D.new()
	add_child(preview)

func update_camera() -> void:
	camera.position = focus + Vector3(120,120,120)
	camera.look_at(focus)
	for title: Label3D in landmarks:
		title.visible = camera.size >= 65
		title.pixel_size = camera.size*0.0006

func pan(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1
	focus += Vector3(move.x+move.y,0,-move.x+move.y)*delta*camera.size*0.35
	focus.x = clampf(focus.x,0,map_size)
	focus.z = clampf(focus.z,0,map_size)
	update_camera()

func cell_at(screen: Vector2) -> int:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	var point: Vector3 = origin + direction * (-origin.y / direction.y)
	if point.x < 0 or point.z < 0 or point.x >= map_size or point.z >= map_size: return -1
	return int(floor(point.z))*map_size + int(floor(point.x))

func sync(snapshot: Dictionary, definitions: Dictionary) -> void:
	if snapshot.topology != topology:
		topology = snapshot.topology
		building_cells.clear()
		for child: Node in road_nodes.get_children(): child.free()
		for cell: int in snapshot.roads:
			var road: Node3D = Assets.road()
			if road != null:
				road.position = Vector3(cell%map_size+0.5,0.0,cell/map_size+0.5)
				road_nodes.add_child(road)
		var existing: Array = []
		for item: Dictionary in snapshot.buildings:
			existing.append(item.id)
			var footprint: int = definitions.buildings[item.type].size
			for dz: int in range(footprint):
				for dx: int in range(footprint): building_cells[(item.z + dz) * map_size + item.x + dx] = item.id
			if not buildings.has(item.id):
				var model: Node3D = Assets.building(item.type,definitions.buildings[item.type].size,item.id,definitions.buildings[item.type].label)
				model.position = Vector3(item.x,0,item.z)
				add_child(model)
				buildings[item.id] = model
		for id: int in buildings.keys():
			if not existing.has(id):
				buildings[id].free()
				buildings.erase(id)
		for cell: int in trees:
			trees[cell].visible = not building_cells.has(cell) and not snapshot.roads.has(cell)
		# Re-evaluate hover after construction, demolition, or loading.
		if buildings.has(hovered_building):
			buildings[hovered_building].get_node("Title").visible = buildings[hovered_building].get_meta("placeholder",false)
			buildings[hovered_building].get_node("Status").hide()
		hovered_building = 0
	for item: Dictionary in snapshot.buildings:
		var status: Label3D = buildings[item.id].get_node("Status")
		status.text = "SIN CAMINO" if not item.connected else ("CUIDADA" if item.type == "house" and item.care_days >= 3 else "")
		if item.type == "farm" and item.connected:
			status.text = "%d%% · %d presentes" % [100*item.work/definitions.buildings.farm.work,item.present]
		status.modulate = Color("#ffa48d") if not item.connected else Color("#edf5c4")
	var active_ships: Array = []
	for voyage: Dictionary in snapshot.voyages:
		active_ships.append(voyage.id)
		if not ships.has(voyage.id):
			var ship: Node3D = Assets.scenery("sailboat",0,0.7)
			add_child(ship)
			Assets.label(ship,definitions.ports[voyage.port].label,Vector3(0,2.6,0),23)
			ships[voyage.id] = ship
	for id: int in ships.keys():
		if not active_ships.has(id):
			ships[id].free()
			ships.erase(id)
	for citizen: Dictionary in snapshot.citizens:
		if not people.has(citizen.id):
			var model: Node3D = Assets.citizen(citizen.id)
			if model == null: continue
			add_child(model)
			people[citizen.id] = model
	for id: int in people.keys():
		if not snapshot.citizens.any(func(c: Dictionary) -> bool: return c.id == id):
			people[id].free()
			people.erase(id)
	refresh_overlay(snapshot,definitions)

func animate(snapshot: Dictionary, fraction: float, moving_time: float) -> void:
	for voyage: Dictionary in snapshot.voyages:
		if not ships.has(voyage.id): continue
		var phase: float = clampf((voyage.elapsed+fraction)/float(voyage.duration),0,1)
		var travel: float = (phase*2 if phase < 0.5 else (1-phase)*2)*(voyage.path.size()-1)
		var cell: int = voyage.path[int(travel)]
		var next: int = voyage.path[mini(int(travel)+1,voyage.path.size()-1)]
		var from: Vector3 = Vector3(cell%map_size+0.5,0,cell/map_size+0.5)
		var to: Vector3 = Vector3(next%map_size+0.5,0,next/map_size+0.5)
		ships[voyage.id].position = from.lerp(to,fmod(travel,1.0))
		if cell != next: ships[voyage.id].rotation.y = atan2(to.x-from.x,to.z-from.z)+(PI if phase >= 0.5 else 0)

	for citizen: Dictionary in snapshot.citizens:
		if not people.has(citizen.id): continue
		var model: Node3D = people[citizen.id]
		var position_value := Vector3(citizen.cell%map_size+0.5,0.07,citizen.cell/map_size+0.5)
		var walking: bool = citizen.activity in ["Al trabajo","A casa","Llegando"] and not citizen.route.is_empty()
		if walking:
			var next: int = citizen.route[0]
			var target := Vector3(next%map_size+0.5,0.07,next/map_size+0.5)
			model.rotation.y = atan2(target.x-position_value.x,target.z-position_value.z)
			position_value = position_value.lerp(target,clampf((citizen.progress+fraction)/2.0,0,1))
		position_value.x += (citizen.id%2-0.5)*0.22
		position_value.z += (citizen.id%4/2-0.5)*0.22
		model.position = position_value
		var swing: float = sin(moving_time*9+citizen.id)*0.55 if walking else 0.0
		var limbs: Dictionary = model.get_meta("limbs")
		if limbs.size() == Assets.LIMBS.size():
			limbs.LegL.rotation.x = swing
			limbs.LegR.rotation.x = -swing
			limbs.ArmL.rotation.x = -swing if citizen.activity != "Trabajando" else sin(moving_time*6)*0.6
			limbs.ArmR.rotation.x = swing

func refresh_overlay(snapshot: Dictionary, definitions: Dictionary) -> void:
	for child: Node in overlay.get_children(): child.free()
	if not water_view: return
	for item: Dictionary in snapshot.buildings:
		if item.type == "house":
			var size: int = definitions.buildings.house.size
			Assets.box(overlay,Vector3(size,0.04,size),Vector3(item.x+size/2.0,0.18,item.z+size/2.0),Color(0.2,0.75,0.95,0.5) if item.water else Color(0.9,0.3,0.2,0.5))

func show_preview(cells: Array, valid: bool) -> void:
	for child: Node in preview.get_children(): child.free()
	for cell: int in cells:
		if cell < 0 or cell >= map_size*map_size: continue
		Assets.box(preview,Vector3(0.95,0.12,0.95),Vector3(cell%map_size+0.5,0.15,cell/map_size+0.5),Color(0.5,0.95,0.65,0.5) if valid else Color(1,0.25,0.17,0.55))
