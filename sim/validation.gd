extends RefCounted

static func check(data: Dictionary, definitions: Dictionary) -> String:
	if not data.get("topology") is int or data.topology < 1: return "Topología inválida"
	var template: Dictionary = {"schema":TYPE_INT,"balance_version":TYPE_INT,"seed":TYPE_INT,"rng_state":TYPE_STRING,"tick":TYPE_INT,"sequence":TYPE_INT,"next_building":TYPE_INT,"next_citizen":TYPE_INT,"coins":TYPE_INT,"inventory":TYPE_DICTIONARY,"terrain":TYPE_ARRAY,"roads":TYPE_ARRAY,"buildings":TYPE_ARRAY,"citizens":TYPE_ARRAY,"exported":TYPE_INT,"immigration_checks":TYPE_INT,"milestones":TYPE_ARRAY,"alerts":TYPE_ARRAY}
	for key: String in template:
		if not data.has(key) or typeof(data[key]) != template[key]: return "Guardado incompleto: " + key
	if data.schema != 1 or data.balance_version != definitions.balance.version: return "Versión de guardado incompatible"
	if data.tick < 0 or data.sequence < 0 or data.coins < 0 or data.exported < 0 or data.immigration_checks < 0: return "Contadores inválidos"
	if not data.rng_state.is_valid_int(): return "Estado RNG inválido"
	if data.terrain.size() != 1600 or data.buildings.size() > 1600 or data.citizens.size() > 6400 or data.roads.size() > 1600 or data.alerts.size() > 6 or data.milestones.size() > 5: return "Tamaño de estado inválido"
	for terrain: Variant in data.terrain:
		if terrain not in ["land", "water", "forest", "fertile"]: return "Terreno inválido"
	var total: int = 0
	if data.inventory.size() != 5: return "Inventario inválido"
	for resource: String in definitions.resources:
		if not data.inventory.get(resource) is int or data.inventory[resource] < 0: return "Inventario inválido"
		total += data.inventory[resource]
	if total > definitions.balance.inventory_capacity: return "Capacidad excedida"
	var occupied: Dictionary = {}
	var roads: Dictionary = {}
	for cell: Variant in data.roads:
		if not cell is int or cell < 0 or cell >= 1600 or roads.has(cell) or data.terrain[cell] == "water": return "Camino inválido"
		roads[cell] = true
	var buildings: Dictionary = {}
	for item: Variant in data.buildings:
		if not item is Dictionary: return "Edificio inválido"
		for field: String in ["id","x","z","priority","work","access","present","assigned","care_days","produced"]:
			if not item.get(field) is int: return "Campo de edificio inválido"
		for field: String in ["active","connected","water"]:
			if not item.get(field) is bool: return "Campo de edificio inválido"
		if not item.get("block") is String or not definitions.buildings.has(item.get("type","")): return "Tipo de edificio inválido"
		if item.id <= 0 or buildings.has(item.id) or item.id >= data.next_building: return "ID de edificio inválido"
		var size: int = definitions.buildings[item.type].size
		if item.x < 0 or item.z < 0 or item.x + size > 40 or item.z + size > 40: return "Huella inválida"
		if item.priority not in [0,1] or item.work < 0 or item.work > definitions.buildings[item.type].get("work",0) or item.care_days < 0 or item.care_days > 3 or item.produced < 0: return "Producción inválida"
		for z: int in range(item.z, item.z + size):
			for x: int in range(item.x, item.x + size):
				var cell: int = z * 40 + x
				if occupied.has(cell) or roads.has(cell) or data.terrain[cell] == "water": return "Solapamiento inválido"
				occupied[cell] = true
		buildings[item.id] = item
	if not buildings.has(1) or buildings[1].type != "warehouse": return "Almacén ausente"
	var ids: Dictionary = {}
	var jobs: Dictionary = {}
	var homes: Dictionary = {}
	for citizen: Variant in data.citizens:
		if not citizen is Dictionary: return "Ciudadano inválido"
		for field: String in ["id","home","job","cell","progress","destination","route_version","satisfaction"]:
			if not citizen.get(field) is int: return "Campo de ciudadano inválido"
		for field: String in ["fed","water","arriving"]:
			if not citizen.get(field) is bool: return "Necesidad inválida"
		if not citizen.get("name") is String or not citizen.get("activity") is String or not citizen.get("route") is Array: return "Ciudadano incompleto"
		if ids.has(citizen.id) or citizen.id <= 0 or citizen.id >= data.next_citizen: return "ID de ciudadano inválido"
		ids[citizen.id] = true
		if not buildings.has(citizen.home) or buildings[citizen.home].type != "house": return "Vivienda inválida"
		homes[citizen.home] = homes.get(citizen.home,0) + 1
		if homes[citizen.home] > 4: return "Vivienda sobreocupada"
		if citizen.job != 0:
			if not buildings.has(citizen.job): return "Empleo inválido"
			jobs[citizen.job] = jobs.get(citizen.job,0) + 1
			if jobs[citizen.job] > definitions.buildings[buildings[citizen.job].type].jobs: return "Puestos excedidos"
		if citizen.cell < 0 or citizen.cell >= 1600 or data.terrain[citizen.cell] == "water" or citizen.progress < 0 or citizen.progress >= definitions.balance.move_ticks or citizen.satisfaction < 0 or citizen.satisfaction > 100: return "Movimiento o satisfacción inválidos"
		if citizen.destination < -1 or citizen.destination >= 1600 or citizen.route.size() > 1600: return "Destino inválido"
		var previous: int = citizen.cell
		for cell: Variant in citizen.route:
			if not cell is int or not preload("res://sim/pathfinding.gd").neighbors(previous).has(cell): return "Ruta inválida"
			previous = cell
	return ""
