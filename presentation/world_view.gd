extends Node3D
const Assets = preload("res://presentation/asset_factory.gd")
var camera: Camera3D
var focus: Vector3 = Vector3(22,0,20)
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
		buildings[hovered_building].get_node("Title").hide()
		buildings[hovered_building].get_node("Status").hide()
	hovered_building = next_hover
	if buildings.has(hovered_building):
		buildings[hovered_building].get_node("Title").show()
		buildings[hovered_building].get_node("Status").show()

func setup(snapshot: Dictionary) -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.far = 150
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
	var colors: Dictionary = {"water":Color("#4fabb4"),"land":Color("#b9bd8c"),"fertile":Color("#a8b578"),"forest":Color("#929f70")}
	for cell: int in range(1600):
		var x: int = cell % 40
		var z: int = cell / 40
		var color: Color = colors[snapshot.terrain[cell]]
		color = color.lightened(((x*13+z*7)%5)*0.004)
		for offset: Vector3 in [Vector3(0,0,0),Vector3(1,0,1),Vector3(0,0,1),Vector3(0,0,0),Vector3(1,0,0),Vector3(1,0,1)]:
			surface.set_color(color.srgb_to_linear())
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(x,-0.02,z)+offset)
		if snapshot.terrain[cell] == "forest" and (x*7+z*3)%5 == 0:
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
	Assets.box(self,Vector3(40,0.5,40),Vector3(20,-0.31,20),Color("#9b9473"))
	# Moored decorative craft: no fictitious deliveries or navigation.
	for boat_info: Array in [["sailboat",33.0,16.0,0.92,-0.35],["sailboat",35.0,27.0,1.08,0.6],["rowboat",30.8,20.8,0.88,0.2]]:
		var boat: Node3D = Assets.scenery(boat_info[0], float(boat_info[4]), float(boat_info[3]))
		if boat != null:
			boat.position = Vector3(boat_info[1], -0.01, boat_info[2])
			add_child(boat)
	road_nodes = Node3D.new()
	add_child(road_nodes)
	overlay = Node3D.new()
	add_child(overlay)
	preview = Node3D.new()
	add_child(preview)

func update_camera() -> void:
	camera.position = focus + Vector3(35,35,35)
	camera.look_at(focus)

func pan(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1
	focus += Vector3(move.x+move.y,0,-move.x+move.y)*delta*camera.size*0.35
	focus.x = clampf(focus.x,5,35)
	focus.z = clampf(focus.z,5,35)
	update_camera()

func cell_at(screen: Vector2) -> int:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	var point: Vector3 = origin + direction * (-origin.y / direction.y)
	if point.x < 0 or point.z < 0 or point.x >= 40 or point.z >= 40: return -1
	return int(floor(point.z))*40 + int(floor(point.x))

func sync(snapshot: Dictionary, definitions: Dictionary) -> void:
	if snapshot.topology != topology:
		topology = snapshot.topology
		building_cells.clear()
		for child: Node in road_nodes.get_children(): child.free()
		for cell: int in snapshot.roads:
			var road: Node3D = Assets.road()
			if road != null:
				road.position = Vector3(cell%40+0.5,0.0,cell/40+0.5)
				road_nodes.add_child(road)
		var existing: Array = []
		for item: Dictionary in snapshot.buildings:
			existing.append(item.id)
			var footprint: int = definitions.buildings[item.type].size
			for dz: int in range(footprint):
				for dx: int in range(footprint): building_cells[(item.z + dz) * 40 + item.x + dx] = item.id
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
			buildings[hovered_building].get_node("Title").hide()
			buildings[hovered_building].get_node("Status").hide()
		hovered_building = 0
	for item: Dictionary in snapshot.buildings:
		var status: Label3D = buildings[item.id].get_node("Status")
		status.text = "SIN CAMINO" if not item.connected else ("CUIDADA" if item.type == "house" and item.care_days >= 3 else "")
		if item.type == "farm" and item.connected:
			status.text = "%d%% · %d presentes" % [100*item.work/definitions.buildings.farm.work,item.present]
		status.modulate = Color("#ffa48d") if not item.connected else Color("#edf5c4")
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
	for citizen: Dictionary in snapshot.citizens:
		if not people.has(citizen.id): continue
		var model: Node3D = people[citizen.id]
		var position_value := Vector3(citizen.cell%40+0.5,0.07,citizen.cell/40+0.5)
		var walking: bool = citizen.activity in ["Al trabajo","A casa","Llegando"] and not citizen.route.is_empty()
		if walking:
			var next: int = citizen.route[0]
			var target := Vector3(next%40+0.5,0.07,next/40+0.5)
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
		if cell < 0 or cell >= 1600: continue
		Assets.box(preview,Vector3(0.95,0.12,0.95),Vector3(cell%40+0.5,0.15,cell/40+0.5),Color(0.5,0.95,0.65,0.5) if valid else Color(1,0.25,0.17,0.55))
