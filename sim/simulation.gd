extends RefCounted

const Paths = preload("res://sim/pathfinding.gd")
const Economy = preload("res://sim/systems/economy.gd")
const Map = preload("res://sim/world_map.gd")
const Maritime = preload("res://sim/systems/maritime.gd")
const Citizens = preload("res://sim/systems/citizens.gd")
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
	state = {"schema":2, "map_size":Map.SIZE, "balance_version":definitions.balance.version, "seed":seed_value, "rng_state":str(seed_value), "tick":0, "sequence":0, "next_building":1, "next_citizen":1, "coins":definitions.balance.coins, "inventory":definitions.balance.inventory.duplicate(true), "terrain":terrain, "roads":[], "buildings":[], "citizens":[], "exported":0, "immigration_checks":0, "milestones":[], "alerts":[], "voyages":[], "trade_routes":[], "trade_history":[], "trade_volume":{}, "trade_season":0, "trade_completed":0, "next_voyage":1}
	_add_building("warehouse", 65, 54)
	_add_building("house", 69, 54)
	_add_building("house", 72, 54)
	_add_building("well", 75, 54)
	for x: int in range(65, 78): state.roads.append(53 * width() + x)
	for z: int in range(47, 53): state.roads.append(z * width() + 77)
	rebuild()
	for home: int in [2, 3]:
		for i: int in range(4): _add_citizen(home, building(home).access)
	Citizens.refresh_services(self)

func width() -> int:
	return state.map_size

func building(id: int) -> Dictionary:
	for item: Dictionary in state.buildings:
		if item.id == id: return item
	return {}

func _add_building(kind: String, x: int, z: int) -> Dictionary:
	var item: Dictionary = {"id":state.next_building, "type":kind, "x":x, "z":z, "active":true, "priority":0, "work":0, "access":-1, "connected":false, "water":false, "present":0, "assigned":0, "block":"", "care_days":0, "produced":0, "services":{}, "level":1, "service_active":false}
	state.next_building += 1
	state.buildings.append(item)
	return item

func _add_citizen(home: int, cell: int, arriving: bool = false) -> void:
	var id: int = state.next_citizen
	var names: Array[String] = ["Iria", "Brais", "Alda", "Roi", "Sabela", "Lois", "Mariña", "Antón", "Lúa", "Nuno", "Elvira", "Tomé", "Xiana", "Paio", "Mencía", "Xoán"]
	state.citizens.append({"id":id, "name":names[(id - 1) % names.size()] + " " + str(id), "home":home, "job":0, "cell":cell, "route":[], "progress":0, "destination":-1, "route_version":-1, "activity":"Llegando" if arriving else "En casa", "fed":true, "water":true, "satisfaction":70, "arriving":arriving})
	state.next_citizen += 1

func footprint(kind: String, x: int, z: int) -> Array:
	var cells: Array = []
	for dz: int in range(definitions.buildings[kind].size):
		for dx: int in range(definitions.buildings[kind].size):
			cells.append((z + dz) * width() + x + dx)
	return cells

func edges(item: Dictionary) -> Array:
	var cells: Array = footprint(item.type, item.x, item.z)
	var border: Array = []
	for cell: int in cells:
		for next: int in Paths.neighbors(cell, width()):
			if not cells.has(next) and not border.has(next): border.append(next)
	border.sort()
	return border

func rebuild() -> void:
	topology += 1
	state.topology = topology
	roads.clear()
	occupied.clear()
	for cell: int in state.roads: roads[cell] = true
	for item: Dictionary in state.buildings:
		for cell: int in footprint(item.type, item.x, item.z): occupied[cell] = item.id
		item.access = -1
		for cell: int in edges(item):
			if roads.has(cell):
				item.access = cell
				break
	reachable = Paths.distances(building(1).get("access", -1), roads, width())
	for item: Dictionary in state.buildings:
		for cell: int in edges(item):
			if reachable.has(cell):
				item.access = cell
				break
		item.connected = reachable.has(item.access)
	Citizens.refresh_services(self)
	Citizens.assign_jobs(self)

func terrain_error(kind: String, x: int, z: int) -> String:
	var size: int = definitions.buildings[kind].size
	if x < 0 or z < 0 or x + size > width() or z + size > width(): return "Fuera del mapa"
	for cell: int in footprint(kind, x, z):
		if state.terrain[cell] == "water": return "Necesita tierra firme"
		if definitions.buildings[kind].get("fertile",false) and state.terrain[cell] != "fertile": return "Terreno no fértil"
	if definitions.buildings[kind].get("coastal",false):
		var coast: bool = false
		for cell: int in edges({"type":kind, "x":x, "z":z}):
			if state.terrain[cell] == "water": coast = true
		if not coast: return "Necesita un borde junto al agua"
	if kind == "lumber" or definitions.buildings[kind].has("deposit"):
		var forest: bool = false
		for dz: int in range(maxi(0, z - 3), mini(width(), z + size + 3)):
			for dx: int in range(maxi(0, x - 3), mini(width(), x + size + 3)):
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
			if not definitions.buildings.has(kind) or kind == "warehouse": return result("Edificio no construible")
			if not command.get("x") is int or not command.get("z") is int: return result("Coordenadas inválidas")
			var error: String = terrain_error(kind, command.x, command.z)
			if not error.is_empty(): return result(error)
			for cell: int in footprint(kind, command.x, command.z):
				if occupied.has(cell) or roads.has(cell): return result("Casilla ocupada")
			var definition: Dictionary = definitions.buildings[kind]
			if state.coins < definition.coins: return result("Monedas insuficientes")
			if state.inventory.wood < definition.wood: return result("Madera insuficiente")
			for resource: String in definition.get("materials",{}):
				if state.inventory[resource] < definition.materials[resource]: return result("Falta " + definitions.resources[resource].label)
			return result("", definition.coins, definition.wood)
		"road":
			if not command.get("cells") is Array or command.cells.is_empty(): return result("Tramo vacío")
			var unique: Dictionary = {}
			var previous: int = -1
			for cell: Variant in command.cells:
				if not cell is int or cell < 0 or cell >= width()*width(): return result("Fuera del mapa")
				if previous >= 0 and cell != previous and not Paths.neighbors(previous, width()).has(cell): return result("El tramo debe ser continuo")
				previous = cell
				if occupied.has(cell) or state.terrain[cell] == "water": return result("Tramo bloqueado")
				if not roads.has(cell): unique[cell] = true
			var cost: int = unique.size() * definitions.balance.road_cost
			if cost > state.coins: return result("Monedas insuficientes")
			return result("", cost)
		"demolish":
			var cell: int = command.get("cell", -1)
			if occupied.has(cell):
				var item: Dictionary = building(occupied[cell])
				if item.type == "dock":
					if state.voyages.any(func(v: Dictionary) -> bool: return v.dock == item.id): return result("Espera a que vuelva la nave")
				if item.type == "depot" and Economy.total(state.inventory)+Maritime.reserved(self) > Economy.physical_capacity(self)-definitions.buildings.depot.storage: return result("Vacía el depósito antes de demoler")
				if item.type == "warehouse": return result("El almacén inicial está protegido")
				for citizen: Dictionary in state.citizens:
					if citizen.home == item.id: return result("No se puede demoler una vivienda ocupada")
				return result()
			return result("" if roads.has(cell) else "Nada que demoler")
		"activity", "priority":
			var item: Dictionary = building(command.get("id", 0))
			if item.is_empty() or definitions.buildings[item.type].jobs == 0: return result("Selecciona un establecimiento productivo")
			return result()
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
			_add_building(command.kind, command.x, command.z)
			rebuild()
		"road":
			state.coins -= checked.coins
			for cell: int in command.cells:
				if not state.roads.has(cell): state.roads.append(cell)
			state.roads.sort()
			rebuild()
		"demolish":
			if occupied.has(command.cell):
				var item: Dictionary = building(occupied[command.cell])
				for citizen: Dictionary in state.citizens:
					if citizen.job == item.id: citizen.job = 0
				state.trade_routes = state.trade_routes.filter(func(r: Dictionary) -> bool: return r.dock != item.id)
				state.buildings.erase(item)
			else: state.roads.erase(command.cell)
			rebuild()
		"activity":
			var item: Dictionary = building(command.id)
			item.active = not item.active
			Citizens.assign_jobs(self)
		"priority":
			var item: Dictionary = building(command.id)
			item.priority = 1 - item.priority
			Citizens.assign_jobs(self)
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
	Maritime.step(self)
	Economy.produce(self)
	if state.tick % definitions.balance.ticks_per_day == 0:
		Citizens.daily(self)
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
