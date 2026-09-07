extends Node3D
const Map = preload("res://sim/world_map.gd")
const Assets = preload("res://presentation/asset_factory.gd")
const Landscape = preload("res://presentation/landscape.gd")
var camera: Camera3D
var focus: Vector3 = Map.START_FOCUS
var sidebar_width: float = 0.0
var map_size: int = Map.SIZE
var ships: Dictionary = {}
var pilgrims: Dictionary = {}
var merchant_ship: Node3D
const Footprints = preload("res://sim/footprints.gd")
var landmarks: Array[Label3D] = []
var buildings: Dictionary = {}
var people: Dictionary = {}
var road_nodes: Node3D
var overlay: Node3D
var preview: Node3D
var preview_key: String = ""
var terrain_node: MeshInstance3D
var topology: int = -1
var water_view: bool = false
var selected_cell: int = -1
var landscape: Node3D
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
	map_size = snapshot.map_size
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30
	camera.far = Map.SIZE*5.0
	add_child(camera)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	update_camera()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	light.light_color = Color("#f4f3ef")
	light.light_energy = 0.30
	light.shadow_enabled = true
	light.shadow_opacity = 0.32
	light.shadow_blur = 2.0
	light.directional_shadow_max_distance = 70
	add_child(light)
	# Neutral, restrained fill preserves the photo's warm stone without bleaching it.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35,145,0)
	fill.light_color = Color("#e4e2dc")
	fill.light_energy = 0.12
	add_child(fill)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#d7d3c4")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#e8e7e0")
	settings.ambient_light_energy = 0.50
	environment.environment = settings
	add_child(environment)
	landscape = Landscape.new()
	landscape.name = "Landscape"
	add_child(landscape)
	landscape.setup(snapshot)
	terrain_node = landscape.ground
	Assets.box(self,Vector3(map_size,0.5,map_size),Vector3(map_size/2.0,-1.65,map_size/2.0),Color("#9b9473"))
	for landmark: Dictionary in Map.LANDMARKS:
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
	camera.position = focus + Vector3.ONE*maxf(300,Map.SIZE*1.2)
	camera.look_at(focus)
	# Keep the town centered in the playable area beside the permanent menu.
	camera.position += camera.basis.x * sidebar_width / get_viewport().get_visible_rect().size.y * camera.size * 0.5
	if landscape != null: landscape.set_overview(camera.size >= 65)
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
	if landscape.world_seed != snapshot.seed:
		landscape.free()
		landscape = Landscape.new()
		landscape.name = "Landscape"
		add_child(landscape)
		landscape.setup(snapshot)
		terrain_node = landscape.ground
		landscape.set_overview(camera.size >= 65)
		for model: Node3D in buildings.values(): model.free()
		buildings.clear()
		topology = -1
	if snapshot.topology != topology:
		topology = snapshot.topology
		building_cells.clear()
		for child: Node in road_nodes.get_children(): child.free()
		for cell: int in snapshot.get("shoreline_fill",[]):
			Assets.box(road_nodes,Vector3(1,1.5,1),Vector3(cell%map_size+0.5,-0.74,cell/map_size+0.5),Color("#8f8876"))
		for cell: int in snapshot.roads:
			# The Blender bridge already supplies paving at the walking plane.
			if Map.BURGO_BRIDGE.has_point(Vector2i(cell%map_size,cell/map_size)): continue
			var road: Node3D = Assets.road(preload("res://sim/road_surfaces.gd").at(snapshot,cell))
			if road != null:
				road.rotation.y = posmod(cell*13+int(cell/map_size)*7,4)*PI*0.5
				road.position = Vector3(cell%map_size+0.5,0.0,cell/map_size+0.5)
				road_nodes.add_child(road)
		var existing: Array = []
		for item: Dictionary in snapshot.buildings:
			existing.append(item.id)
			for cell: int in Footprints.cells(definitions.buildings[item.type],item.x,item.z,map_size,item.rotation): building_cells[cell] = item.id

		for id: int in buildings.keys():
			if not existing.has(id):
				buildings[id].free()
				buildings.erase(id)
		landscape.sync_occupation(building_cells,snapshot.roads)
		# Re-evaluate hover after construction, demolition, or loading.
		if buildings.has(hovered_building):
			buildings[hovered_building].get_node("Title").visible = buildings[hovered_building].get_meta("placeholder",false)
			buildings[hovered_building].get_node("Status").hide()
		hovered_building = 0
	var storage: Dictionary = _storage_levels(snapshot,definitions)
	for item: Dictionary in snapshot.buildings:
		var signature: String = "%s:%s:%s:%s:%s:%s:%s" % [item.type,item.level,item.front,item.adjoined,item.rotation,item.ruined,item.burn_days]
		if not buildings.has(item.id) or buildings[item.id].get_meta("signature","") != signature:
			if buildings.has(item.id): buildings[item.id].free()
			var context: Dictionary = item.duplicate()
			if item.type == "house": context.model_family = definitions.housing.levels[item.level-1].model
			var model: Node3D = Assets.building(item.type,Footprints.dimensions(definitions.buildings[item.type],item.rotation),item.id,definitions.buildings[item.type].label,snapshot.seed,"%d:%d" % [item.x,item.z],context)
			model.position = Vector3(item.x,0,item.z)
			model.set_meta("signature",signature)
			add_child(model)
			buildings[item.id] = model
		var status: Label3D = buildings[item.id].get_node("Status")
		var workers: Label3D = buildings[item.id].get_node("Workers")
		workers.visible = item.assigned > 0 and not item.ruined and camera.size < 65
		workers.text = "● %d" % (item.present if item.present > 0 else item.assigned)
		workers.modulate = Color("#91bd72") if item.present > 0 else Color("#e4ba68")
		status.text = "RUINAS · REPARAR" if item.ruined else ("¡FUEGO!" if item.burn_days > 0 else ("SIN ALMACÉN / CAMINO" if not item.connected else (definitions.housing.levels[item.level-1].label.to_upper() if item.type == "house" else "")))
		if definitions.buildings[item.type].jobs > 0 and not item.ruined:
			status.text += "\nDentro: %d · Asignados: %d/%d" % [item.present,item.assigned,definitions.buildings[item.type].jobs]
			workers.position.y = status.position.y+0.6
		status.modulate = Color("#ffa48d") if not item.connected else Color("#edf5c4")
		_sync_cargo(buildings[item.id],item,snapshot,definitions,storage)
	var active_people: Array = snapshot.citizens.map(func(c: Dictionary) -> int: return c.id)
	for id: int in people.keys():
		if not active_people.has(id):
			people[id].free()
			people.erase(id)
	_sync_visitors(snapshot)
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
		people[citizen.id].visible = citizen.activity != "Trabajando" or not buildings.has(citizen.job)
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
		var from: Vector3 = Vector3(cell%map_size+0.5,Landscape.WATER_LEVEL,cell/map_size+0.5)
		var to: Vector3 = Vector3(next%map_size+0.5,Landscape.WATER_LEVEL,next/map_size+0.5)
		ships[voyage.id].position = from.lerp(to,fmod(travel,1.0))
		if cell != next: ships[voyage.id].rotation.y = atan2(to.x-from.x,to.z-from.z)+(PI if phase >= 0.5 else 0)

	for citizen: Dictionary in snapshot.citizens:
		if not people.has(citizen.id): continue
		var model: Node3D = people[citizen.id]
		model.visible = citizen.activity != "Trabajando" or not buildings.has(citizen.job)
		if not model.visible: continue
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
			limbs.ArmL.rotation.x = -swing
			limbs.ArmR.rotation.x = swing

func refresh_overlay(snapshot: Dictionary, definitions: Dictionary) -> void:
	for child: Node in overlay.get_children(): child.free()
	if not water_view: return
	for item: Dictionary in snapshot.buildings:
		if item.type == "house":
			var size: Vector2i = Footprints.dimensions(definitions.buildings.house,item.rotation)
			Assets.box(overlay,Vector3(size.x,0.04,size.y),Vector3(item.x+size.x/2.0,0.18,item.z+size.y/2.0),Color(0.2,0.75,0.95,0.5) if item.water else Color(0.9,0.3,0.2,0.5))

func show_preview(cells: Array, valid: bool, kind: String = "", definition: Dictionary = {}, rotation: int = 0, seed_value: int = 1530) -> void:
	var key: String = str([cells,valid,kind,rotation,seed_value])
	if key == preview_key: return
	preview_key = key
	for child: Node in preview.get_children(): child.free()
	for cell: int in cells:
		if cell < 0 or cell >= map_size*map_size: continue
		Assets.box(preview,Vector3(0.95,0.12,0.95),Vector3(cell%map_size+0.5,0.15,cell/map_size+0.5),Color(0.5,0.95,0.65,0.5) if valid else Color(1,0.25,0.17,0.55))

	if kind.is_empty() or cells.is_empty(): return
	var first: int = cells[0]
	var size: Vector2i = Footprints.dimensions(definition,rotation)
	var model: Node3D = Assets.building(kind,size,0,"",seed_value,"%d:%d" % [first%map_size,first/map_size],{"front":rotation})
	model.name = "BuildingPreview"
	model.position = Vector3(first%map_size,0,first/map_size)
	preview.add_child(model)
	_tint_preview(model,Assets.material(Color(0.35,0.95,0.65,0.55) if valid else Color(1,0.25,0.17,0.55)))
	if definition.get("coastal",false):
		Assets.box(preview,Vector3(size.x,1.5,size.y),model.position+Vector3(size.x/2.0,-0.74,size.y/2.0),Color(0.65,0.61,0.48,0.6))

func _tint_preview(node: Node, mat: Material) -> void:
	if node is Label3D: node.hide()
	elif node is MeshInstance3D:
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children(): _tint_preview(child,mat)

func _storage_levels(snapshot: Dictionary, definitions: Dictionary) -> Dictionary:
	var economy = preload("res://sim/systems/economy.gd")
	var stored: Dictionary = snapshot.inventory.duplicate()
	for voyage: Dictionary in snapshot.voyages:
		if voyage.direction == "buy": stored[voyage.resource] += voyage.quantity
	var general: int = definitions.balance.inventory_capacity
	var granaries: int = 0
	for building: Dictionary in snapshot.buildings:
		if building.connected:
			general += definitions.buildings[building.type].get("storage",0)
			granaries += definitions.buildings[building.type].get("food_storage",0)
	var food_used: int = mini(economy.granary_stock(stored),granaries)
	var used: int = economy.total(stored)-food_used
	return {"general":general,"granaries":granaries,"food_used":food_used,"used":used,"stored":stored}

func _sync_cargo(model: Node3D, item: Dictionary, snapshot: Dictionary, definitions: Dictionary, storage: Dictionary) -> void:
	var definition: Dictionary = definitions.buildings[item.type]
	var count: int = 0
	var warning: String = ""
	var economy = preload("res://sim/systems/economy.gd")
	var food_used: int = storage.food_used
	var granaries: int = storage.granaries
	var used: int = storage.used
	var general: int = storage.general
	if item.type == "warehouse" or definition.has("storage") or definition.has("food_storage"):
		var ratio: float = float(food_used)/maxi(1,granaries) if definition.has("food_storage") else float(used)/maxi(1,general)
		count = clampi(int(ceil(ratio*8)),0,8) if item.connected else 0
		if ratio >= 1.0 and item.connected: warning = "HÓRREO LLENO" if definition.has("food_storage") else "ALMACÉN LLENO"
	elif not definition.get("outputs",{}).is_empty() and item.active:
		if not item.connected: warning = "SIN CONEXIÓN"
		else:
			var produced: Dictionary = storage.stored.duplicate()
			for resource: String in definition.get("inputs",{}): produced[resource] = maxi(0,produced[resource]-definition.inputs[resource])
			for resource: String in definition.outputs: produced[resource] += definition.outputs[resource]
			if economy.total(produced)-mini(economy.granary_stock(produced),granaries) > general: warning = "SIN ESPACIO"
		if not warning.is_empty(): count = 6
	if item.ruined or item.burn_days > 0:
		count = 0
		warning = ""
	var size: Vector2i = Footprints.dimensions(definition,item.rotation)
	if model.get_meta("cargo_count",-1) != count:
		if model.has_node("Cargo"): model.get_node("Cargo").free()
		var cargo := Node3D.new()
		cargo.name = "Cargo"
		model.add_child(cargo)
		for i: int in range(count):
			var at := Vector3(0.22+(i%4)*minf(0.34,(size.x-0.4)/3.0),0.19+(i/4)*0.34,size.y+0.12)
			Assets.box(cargo,Vector3(0.29,0.32,0.29),at,Color("#a27343"))
			Assets.box(cargo,Vector3(0.31,0.045,0.31),at+Vector3(0,0.08,0),Color("#554d40"))
		model.set_meta("cargo_count",count)
	if not model.has_node("CargoWarning"):
		var label: Label3D = Assets.label(model,"",model.get_node("Status").position+Vector3(0,1.1,0),22)
		label.name = "CargoWarning"
		label.modulate = Color("#ffd38a")
	model.get_node("CargoWarning").text = warning
	model.get_node("CargoWarning").visible = not warning.is_empty() and camera.size < 65

func _sync_visitors(snapshot: Dictionary) -> void:
	var ids: Array = []
	for visitor: Dictionary in snapshot.pilgrims:
		ids.append(visitor.id)
		if not pilgrims.has(visitor.id):
			var person: Node3D = Assets.citizen(visitor.id)
			add_child(person)
			Assets.label(person,"Peregrino",Vector3(0,1.6,0),18)
			pilgrims[visitor.id] = person
		pilgrims[visitor.id].position = Vector3(visitor.cell%map_size+0.7,0.07,visitor.cell/map_size+0.7)
	for id: int in pilgrims.keys():
		if not ids.has(id):
			pilgrims[id].free()
			pilgrims.erase(id)
	if snapshot.merchant.is_empty():
		if is_instance_valid(merchant_ship): merchant_ship.free()
		merchant_ship = null
		return
	if not is_instance_valid(merchant_ship):
		merchant_ship = Assets.scenery("sailboat",0,0.8)
		add_child(merchant_ship)
		Assets.label(merchant_ship,"Mercader",Vector3(0,2.5,0),22)
	var visit: Dictionary = snapshot.merchant
	var day: float = visit.duration/4.0
	var progress: float = clampf(1.0-visit.elapsed/day,0,1) if visit.elapsed < day else clampf((visit.elapsed-day*3)/day,0,1)
	var index: int = mini(visit.path.size()-1,int(progress*(visit.path.size()-1)))
	var cell: int = visit.path[index]
	merchant_ship.position = Vector3(cell%map_size+0.5,Landscape.WATER_LEVEL,cell/map_size+0.5)
