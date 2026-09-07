extends RefCounted
const RoadSurfaces = preload("res://sim/road_surfaces.gd")

const Paths = preload("res://sim/pathfinding.gd")
const Economy = preload("res://sim/systems/economy.gd")
const Map = preload("res://sim/world_map.gd")
const Maritime = preload("res://sim/systems/maritime.gd")
const Citizens = preload("res://sim/systems/citizens.gd")
const Footprints = preload("res://sim/footprints.gd")
const Housing = preload("res://sim/systems/housing.gd")
const Progression = preload("res://sim/systems/progression.gd")
const Risks = preload("res://sim/systems/risks.gd")
const Merchants = preload("res://sim/systems/merchants.gd")
const Pilgrims = preload("res://sim/systems/pilgrims.gd")
var exterior: Dictionary = {}
var distance_cache: Dictionary = {}
var definitions: Dictionary
var state: Dictionary
var roads: Dictionary = {}
var occupied: Dictionary = {}
var reachable: Dictionary = {}
var topology: int = 0

func create(seed_value: int, data: Dictionary, _scenario: Dictionary = {}) -> void:
	topology = 0
	definitions = data.duplicate(true)
	var terrain: Array = Map.generate(seed_value)
	state = {"schema":3, "map_id":Map.ID, "map_size":Map.SIZE, "balance_version":definitions.balance.version, "seed":seed_value, "rng_state":str(seed_value), "tick":0, "sequence":0, "next_building":1, "next_citizen":1, "coins":definitions.balance.coins, "inventory":definitions.balance.inventory.duplicate(true), "terrain":terrain, "roads":[], "buildings":[], "citizens":[], "exported":0, "immigration_checks":0, "milestones":[], "alerts":[], "voyages":[], "trade_routes":[], "trade_history":[], "trade_volume":{}, "trade_season":0, "trade_completed":0, "next_voyage":1, "objective":{"stage":0,"stable_days":0,"victory_days":0,"empty_days":0,"founded":false,"won":false,"failed":false,"aid_used":false,"message":"Funda un barrio junto al camino: almacén, viviendas, pozo y alimentos"}, "operating":0,"cash_history":[],"pilgrims":[],"next_pilgrim":1,"pilgrims_served":0,"reputation":0,"merchant":{},"merchant_visits":0}
	state.roads = Map.main_road()
	state.building_layout = 2
	state.road_surfaces = {}
	rebuild()

func width() -> int:
	return state.map_size

func building(id: int) -> Dictionary:
	for item: Dictionary in state.buildings:
		if item.id == id: return item
	return {}

func _add_building(kind: String, x: int, z: int, rotation: int = 0) -> Dictionary:
	var item: Dictionary = {"id":state.next_building, "type":kind, "x":x, "z":z, "active":true, "priority":0, "work":0, "access":-1, "connected":false, "water":false, "present":0, "assigned":0, "block":"", "care_days":0, "produced":0, "services":{}, "level":1, "service_active":false,"rotation":rotation,"front":rotation,"adjoined":0,"upgrade_days":0,"decline_days":0,"needs":"","condition":100,"fire_risk":0,"burn_days":0,"ruined":false,"age":0}
	state.next_building += 1
	state.buildings.append(item)
	return item

func _add_citizen(home: int, cell: int, arriving: bool = false) -> void:
	var id: int = state.next_citizen
	var names: Array[String] = ["Iria", "Brais", "Alda", "Roi", "Sabela", "Lois", "Mariña", "Antón", "Lúa", "Nuno", "Elvira", "Tomé", "Xiana", "Paio", "Mencía", "Xoán"]
	state.citizens.append({"id":id, "name":names[(id - 1) % names.size()] + " " + str(id), "home":home, "job":0, "cell":cell, "route":[], "progress":0, "destination":-1, "route_version":-1, "activity":"Llegando" if arriving else "En casa", "fed":true, "water":true, "satisfaction":70, "arriving":arriving,"age":0,"hardship":0})
	state.next_citizen += 1

func footprint(kind: String, x: int, z: int, rotation: int = 0) -> Array:
	return Footprints.cells(definitions.buildings[kind],x,z,width(),rotation)

func dimensions(item: Dictionary) -> Vector2i:
	return Footprints.dimensions(definitions.buildings[item.type],item.get("rotation",0))

func alert(message: String) -> void:
	if state.alerts.has(message): return
	state.alerts.append(message)
	if state.alerts.size() > 6: state.alerts.pop_front()

func operational(item: Dictionary) -> bool:
	return not item.is_empty() and item.active and not item.ruined and item.burn_days == 0

func edges(item: Dictionary) -> Array:
	var cells: Array = footprint(item.type, item.x, item.z, item.get("rotation",0))
	var border: Array = []
	for cell: int in cells:
		for next: int in Paths.neighbors(cell, width()):
			if not cells.has(next) and not border.has(next): border.append(next)
	border.sort()
	return border

func rebuild() -> void:
	topology += 1
	state.topology = topology
	distance_cache.clear()
	roads.clear()
	occupied.clear()
	for cell: int in state.roads: roads[cell] = true
	for item: Dictionary in state.buildings:
		for cell: int in footprint(item.type, item.x, item.z, item.get("rotation",0)): occupied[cell] = item.id
		item.access = -1
		for cell: int in edges(item):
			if roads.has(cell):
				item.access = cell
				break
	exterior = Paths.distances(Map.entrance(),roads,width())
	reachable = {}
	for item: Dictionary in state.buildings:
		if item.type != "warehouse" or not operational(item): continue
		for cell: int in edges(item):
			if exterior.has(cell):
				reachable = exterior
				break
	for item: Dictionary in state.buildings:
		var access_options: Array = []
		var network: Dictionary = reachable if not reachable.is_empty() else exterior
		item.adjoined = 0
		for cell: int in edges(item):
			var side: int = Footprints.side(item,dimensions(item),cell,width())
			if network.has(cell): access_options.append(cell)
			if occupied.has(cell) and building(occupied[cell]).type == "house": item.adjoined |= 1 << side
		for cell: int in access_options:
			if Footprints.side(item,dimensions(item),cell,width()) == item.front:
				item.access = cell
				break
		if not access_options.has(item.access) and not access_options.is_empty(): item.access = access_options[0]
		if item.access >= 0: item.front = Footprints.side(item,dimensions(item),item.access,width())
		item.connected = reachable.has(item.access) and not item.ruined and item.burn_days == 0
	Citizens.assign_jobs(self)

func terrain_error(kind: String, x: int, z: int, rotation: int = 0) -> String:
	var size: Vector2i = Footprints.dimensions(definitions.buildings[kind],rotation)
	if x < 0 or z < 0 or x + size.x > width() or z + size.y > width(): return "Fuera del mapa"
	for cell: int in footprint(kind, x, z, rotation):
		if Map.BURGO_BRIDGE.has_point(Vector2i(cell%width(),cell/width())): return "El puente debe quedar libre para caminos"
		if state.terrain[cell] == "water" and not definitions.buildings[kind].get("coastal",false): return "Necesita tierra firme"
		if definitions.buildings[kind].get("fertile",false) and state.terrain[cell] != "fertile": return "Terreno no fértil"
	if definitions.buildings[kind].get("coastal",false):
		var parcel: Array = footprint(kind,x,z,rotation)
		var water_cells: Array = parcel.filter(func(cell: int) -> bool: return state.terrain[cell] == "water")
		if water_cells.size()*2 > parcel.size(): return "Apoya al menos la mitad del edificio en tierra"
		for existing: Dictionary in state.buildings:
			if not definitions.buildings[existing.type].get("coastal",false): continue
			var coast_cells: Array = edges(existing).filter(func(cell: int) -> bool: return state.terrain[cell] == "water")
			if not coast_cells.is_empty() and coast_cells.all(func(cell: int) -> bool: return water_cells.has(cell)): return "Conserva el acceso al agua del edificio vecino"
		for voyage: Dictionary in state.voyages:
			for cell: int in water_cells:
				if voyage.path.has(cell): return "Paso de barcos en uso"
		if not state.merchant.is_empty():
			for cell: int in water_cells:
				if state.merchant.path.has(cell): return "Paso del mercader en uso"
		var coast: bool = false
		for cell: int in edges({"type":kind, "x":x, "z":z, "rotation":rotation}):
			if state.terrain[cell] == "water": coast = true
		if not coast: return "Necesita un borde junto al agua"
	if kind == "lumber" or definitions.buildings[kind].has("deposit"):
		var forest: bool = false
		for dz: int in range(maxi(0, z - 3), mini(width(), z + size.y + 3)):
			for dx: int in range(maxi(0, x - 3), mini(width(), x + size.x + 3)):
				if state.terrain[dz * width() + dx] == definitions.buildings[kind].get("deposit","forest"): forest = true
		if not forest: return "Necesita %s a 3 casillas" % {"forest":"bosque","rock":"granito","clay":"arcilla","ore":"hierro"}[definitions.buildings[kind].get("deposit","forest")]
	return ""

func result(error: String = "", coins: int = 0, wood: int = 0) -> Dictionary:
	return {"ok":error.is_empty(), "code":"ok" if error.is_empty() else error, "message":error, "coins":coins, "wood":wood}

func validate_command(command: Dictionary) -> Dictionary:
	var operation: String = command.get("type", "")
	match operation:
		"build":
			var kind: String = command.get("kind", "")
			if not definitions.buildings.has(kind): return result("Edificio no construible")
			if not command.get("x") is int or not command.get("z") is int: return result("Coordenadas inválidas")
			if not command.get("rotation",0) is int or command.get("rotation",0) not in [0,1,2,3]: return result("Giro inválido")
			var error: String = terrain_error(kind, command.x, command.z,command.get("rotation",0))
			if not error.is_empty(): return result(error)
			for cell: int in footprint(kind, command.x, command.z,command.get("rotation",0)):
				if occupied.has(cell) or roads.has(cell): return result("Casilla ocupada")
			var definition: Dictionary = definitions.buildings[kind]
			if state.coins < definition.coins: return result("Monedas insuficientes")
			if state.inventory.wood < definition.wood: return result("Madera insuficiente")
			for resource: String in definition.get("materials",{}):
				if state.inventory[resource] < definition.materials[resource]: return result("Falta " + definitions.resources[resource].label)
			var checked: Dictionary = result("", definition.coins, definition.wood)
			if definition.get("coastal",false):
				var fill_count: int = footprint(kind,command.x,command.z,command.get("rotation",0)).filter(func(cell: int) -> bool: return state.terrain[cell] == "water").size()
				if fill_count > 0: checked.message = "Relleno de ribera: %d casillas · incluido" % fill_count
			return checked
		"road":
			if not command.get("cells") is Array or command.cells.is_empty(): return result("Tramo vacío")
			var surface: Variant = command.get("surface","paved")
			if surface not in ["paved","dirt"]: return result("Tipo de camino inválido")
			var unique: Dictionary = {}
			var previous: int = -1
			for cell: Variant in command.cells:
				if not cell is int or cell < 0 or cell >= width()*width(): return result("Fuera del mapa")
				if previous >= 0 and cell != previous and not Paths.neighbors(previous, width()).has(cell): return result("El tramo debe ser continuo")
				previous = cell
				if occupied.has(cell) or state.terrain[cell] == "water": return result("Tramo bloqueado")
				if surface == "dirt" and Map.BURGO_BRIDGE.has_point(Vector2i(cell%width(),cell/width())): return result("El puente conserva su pavimento de piedra")
				if not roads.has(cell) or RoadSurfaces.at(state,cell) != surface: unique[cell] = true
			var cost: int = unique.size() * definitions.balance.road_cost
			if cost > state.coins: return result("Monedas insuficientes")
			return result("", cost)
		"demolish":
			var cell: int = command.get("cell", -1)
			if Map.main_road().has(cell): return result("El camino principal está protegido")
			if occupied.has(cell):
				var item: Dictionary = building(occupied[cell])
				if item.type == "dock":
					if state.voyages.any(func(v: Dictionary) -> bool: return v.dock == item.id): return result("Espera a que vuelva la nave")
				if item.type in ["depot","horreo"] and not Economy.can_store(self,state.inventory,true,item.id): return result("Vacía el edificio de almacenamiento antes de demoler")
				if item.type == "warehouse" and not item.ruined: return result("Conserva el almacén de abastecimiento")
				for citizen: Dictionary in state.citizens:
					if citizen.home == item.id: return result("No se puede demoler una vivienda ocupada")
				return result()
			return result("" if roads.has(cell) else "Nada que demoler")
		"repair":
			var item: Dictionary = building(command.get("id",0))
			if item.is_empty() or (not item.ruined and item.condition == 100): return result("No necesita reparación")
			if item.burn_days > 0: return result("Extingue primero el incendio")
			if not exterior.has(item.access): return result("Necesita acceso al camino")
			if state.coins < 20 or state.inventory.wood < 4: return result("Reparar: 20 monedas y 4 de madera")
			return result("",20,4)
		"aid":
			if state.objective.aid_used or state.coins > 100: return result("Ayuda disponible una vez con 100 monedas o menos")
			return result()
		"activity", "priority":
			var item: Dictionary = building(command.get("id", 0))
			if item.is_empty() or definitions.buildings[item.type].jobs == 0: return result("Selecciona un establecimiento productivo")
			return result()
		"merchant_trade":
			return Merchants.validate(self,command)
		"trade":
			return Maritime.validate(self, command)
		"route":
			if not command.get("repeat",false) is bool: return result("Ruta inválida")
			if not command.get("repeat",false):
				return result() if state.trade_routes.any(func(r: Dictionary) -> bool: return r.dock == command.get("dock",0)) else result("No hay ruta automática")
			return Maritime.validate(self,command)
	return result("Orden desconocida")

func apply_command(command: Dictionary) -> Dictionary:
	var checked: Dictionary = validate_command(command)
	if not checked.ok: return checked
	state.sequence += 1
	match command.type:
		"build":
			state.coins -= checked.coins
			state.inventory.wood -= checked.wood
			for resource: String in definitions.buildings[command.kind].get("materials",{}): state.inventory[resource] -= definitions.buildings[command.kind].materials[resource]
			if definitions.buildings[command.kind].get("coastal",false):
				for cell: int in footprint(command.kind,command.x,command.z,command.get("rotation",0)):
					if state.terrain[cell] == "water":
						state.terrain[cell] = "land"
						if not state.has("shoreline_fill"): state.shoreline_fill = []
						state.shoreline_fill.append(cell)
			_add_building(command.kind, command.x, command.z,command.get("rotation",0))
			rebuild()
		"road":
			state.coins -= checked.coins
			if not state.has("road_surfaces"): state.road_surfaces = {}
			for cell: int in command.cells:
				if not state.roads.has(cell): state.roads.append(cell)
				state.road_surfaces[str(cell)] = command.get("surface","paved")
			state.roads.sort()
			rebuild()
		"demolish":
			if occupied.has(command.cell):
				var item: Dictionary = building(occupied[command.cell])
				for citizen: Dictionary in state.citizens:
					if citizen.job == item.id: citizen.job = 0
				state.trade_routes = state.trade_routes.filter(func(r: Dictionary) -> bool: return r.dock != item.id)
				state.buildings.erase(item)
			else:
				state.roads.erase(command.cell)
				if state.has("road_surfaces"): state.road_surfaces.erase(str(command.cell))
			rebuild()
		"repair":
			var item: Dictionary = building(command.id)
			state.coins -= checked.coins
			state.inventory.wood -= checked.wood
			item.ruined = false
			item.active = true
			item.condition = 100
			item.fire_risk = 0
			rebuild()
		"aid":
			state.objective.aid_used = true
			state.objective.failed = false
			state.objective.empty_days = 0
			state.coins += 250
			var available: int = maxi(0,Economy.capacity(self)-Economy.total(state.inventory)-Economy.reserved(self))
			var timber: int = mini(20,available)
			state.inventory.wood += timber
			state.inventory.grain += mini(40,available-timber)
			alert("Ayuda de emergencia concedida; valoración reducida")
		"activity":
			var item: Dictionary = building(command.id)
			item.active = not item.active
			Citizens.assign_jobs(self)
		"priority":
			var item: Dictionary = building(command.id)
			item.priority = 1 - item.priority
			Citizens.assign_jobs(self)
		"merchant_trade":
			Merchants.trade(self,command,checked)
		"trade":
			Maritime.dispatch(self, command, checked)
		"route":
			state.trade_routes = state.trade_routes.filter(func(r: Dictionary) -> bool: return r.dock != command.dock)
			if command.get("repeat",false):
				state.trade_routes.append({"dock":command.dock,"port":command.port,"direction":command.direction,"resource":command.resource,"quantity":command.quantity,"status":"Navegando"})
				Maritime.dispatch(self,command,checked)
	return checked

func step() -> void:
	state.tick += 1
	if state.tick % definitions.balance.labor_interval == 0: Citizens.assign_jobs(self)
	Citizens.move(self)
	Pilgrims.step(self)
	Maritime.step(self)
	Merchants.step(self)
	Economy.produce(self)
	if state.tick % definitions.balance.ticks_per_day == 0:
		Citizens.daily(self)
		Risks.daily(self)
		Pilgrims.daily(self)
		Progression.daily(self)
		Economy.close_flow_day(self)
	Economy.milestones(self)

func get_snapshot() -> Dictionary:
	return state.duplicate(true)

func serialize() -> Dictionary:
	return state.duplicate(true)

func restore(data: Dictionary) -> Dictionary:
	var error: String = preload("res://sim/validation.gd").check(data, definitions)
	if not error.is_empty(): return result(error)
	state = data.duplicate(true)
	topology = data.topology - 1
	# Derived connectivity is reconstructed; persisted routes remain valid after recalculation.
	rebuild()
	state = data.duplicate(true)
	return result()

func road_distances(start: int) -> Dictionary:
	if not distance_cache.has(start): distance_cache[start] = Paths.distances(start,roads,width())
	return distance_cache[start]
