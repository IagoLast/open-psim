extends RefCounted

static func check(data: Dictionary, definitions: Dictionary) -> String:
	if not data.get("topology") is int or data.topology < 1: return "Topología inválida"
	var template: Dictionary = {"schema":TYPE_INT,"balance_version":TYPE_INT,"seed":TYPE_INT,"rng_state":TYPE_STRING,"tick":TYPE_INT,"sequence":TYPE_INT,"next_building":TYPE_INT,"next_citizen":TYPE_INT,"coins":TYPE_INT,"inventory":TYPE_DICTIONARY,"terrain":TYPE_ARRAY,"roads":TYPE_ARRAY,"buildings":TYPE_ARRAY,"citizens":TYPE_ARRAY,"exported":TYPE_INT,"immigration_checks":TYPE_INT,"milestones":TYPE_ARRAY,"alerts":TYPE_ARRAY}
	for key: String in template:
		if not data.has(key) or typeof(data[key]) != template[key]: return "Guardado incompleto: " + key
	if data.schema != 2 or data.balance_version != definitions.balance.version: return "Versión de guardado incompatible"
	if data.tick < 0 or data.sequence < 0 or data.coins < 0 or data.exported < 0 or data.immigration_checks < 0: return "Contadores inválidos"
	if not data.rng_state.is_valid_int(): return "Estado RNG inválido"
	if data.terrain.size() != 16384 or data.buildings.size() > 16384 or data.citizens.size() > 65536 or data.roads.size() > 16384 or data.alerts.size() > 6 or data.milestones.size() > 20: return "Tamaño de estado inválido"
	for terrain: Variant in data.terrain:
		if terrain not in ["land", "water", "forest", "fertile", "rock", "clay", "ore"]: return "Terreno inválido"
	var total: int = 0
	if data.inventory.size() != definitions.resources.size(): return "Inventario inválido"
	for resource: String in definitions.resources:
		if not data.inventory.get(resource) is int or data.inventory[resource] < 0: return "Inventario inválido"
		total += data.inventory[resource]

	var occupied: Dictionary = {}
	var roads: Dictionary = {}
	for cell: Variant in data.roads:
		if not cell is int or cell < 0 or cell >= 16384 or roads.has(cell) or data.terrain[cell] == "water": return "Camino inválido"
		roads[cell] = true
	var buildings: Dictionary = {}
	for item: Variant in data.buildings:
		if not item is Dictionary: return "Edificio inválido"
		for field: String in ["id","x","z","priority","work","access","present","assigned","care_days","produced","level"]:
			if not item.get(field) is int: return "Campo de edificio inválido"
		for field: String in ["active","connected","water"]:
			if not item.get(field) is bool: return "Campo de edificio inválido"
		if not item.get("block") is String or not definitions.buildings.has(item.get("type","")): return "Tipo de edificio inválido"
		if item.id <= 0 or buildings.has(item.id) or item.id >= data.next_building: return "ID de edificio inválido"
		var size: int = definitions.buildings[item.type].size
		if item.x < 0 or item.z < 0 or item.x + size > 128 or item.z + size > 128: return "Huella inválida"
		if item.level < 1 or item.level > 3 or not item.get("services") is Dictionary or not item.get("service_active") is bool: return "Servicios inválidos"
		for service: Variant in item.services:
			if service not in ["water","market","health","faith","safety","education"] or not item.services[service] is bool: return "Cobertura inválida"
		if item.has("funded") and not item.funded is bool: return "Mantenimiento inválido"
		if item.priority not in [0,1] or item.work < 0 or item.work > definitions.buildings[item.type].get("work",0) or item.care_days < 0 or item.care_days > 3 or item.produced < 0: return "Producción inválida"
		for z: int in range(item.z, item.z + size):
			for x: int in range(item.x, item.x + size):
				var cell: int = z * 128 + x
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
		if citizen.cell < 0 or citizen.cell >= 16384 or data.terrain[citizen.cell] == "water" or citizen.progress < 0 or citizen.progress >= definitions.balance.move_ticks or citizen.satisfaction < 0 or citizen.satisfaction > 100: return "Movimiento o satisfacción inválidos"
		if citizen.destination < -1 or citizen.destination >= 16384 or citizen.route.size() > 16384: return "Destino inválido"
		var previous: int = citizen.cell
		for cell: Variant in citizen.route:
			if not cell is int or not preload("res://sim/pathfinding.gd").neighbors(previous).has(cell): return "Ruta inválida"
			previous = cell
	if data.get("map_size") != 128: return "Dimensiones incompatibles"
	for field: String in ["voyages","trade_routes","trade_history"]:
		if not data.get(field) is Array: return "Comercio incompleto"
	for field: String in ["trade_season","trade_completed","next_voyage"]:
		if not data.get(field) is int or data[field] < 0: return "Contador comercial inválido"
	if not data.get("trade_volume") is Dictionary: return "Cupos inválidos"
	for value: Variant in data.trade_volume.values():
		if not value is int or value < 0: return "Cupo inválido"
	if data.trade_history.size() > 8: return "Historial inválido"
	var docks: Dictionary = {}
	var voyage_ids: Dictionary = {}
	var storage: int = definitions.balance.inventory_capacity
	for item: Dictionary in data.buildings: storage += definitions.buildings[item.type].get("storage",0)
	for voyage: Variant in data.voyages:
		if not voyage is Dictionary: return "Travesía inválida"
		for field: String in ["id","dock","quantity","value","elapsed","duration"]:
			if not voyage.get(field) is int: return "Travesía incompleta"
		if voyage.id < 1 or voyage.id >= data.next_voyage or voyage_ids.has(voyage.id): return "ID de travesía inválido"
		voyage_ids[voyage.id] = true
		var error: String = check_order(voyage,buildings,definitions)
		if not error.is_empty(): return error
		if docks.has(voyage.dock): return "Nave duplicada"
		docks[voyage.dock] = true
		var port: Dictionary = definitions.ports[voyage.port]
		var price: int = (port.sells if voyage.direction == "buy" else port.buys)[voyage.resource]
		if voyage.value != price*voyage.quantity or voyage.duration != port.days*definitions.balance.ticks_per_day or voyage.elapsed < 0 or voyage.elapsed > voyage.duration: return "Carga o plazo inválidos"
		if not voyage.get("status") is String or not voyage.get("path") is Array or voyage.path.is_empty() or voyage.path.size() > 16384: return "Ruta marítima inválida"
		var previous: int = -1
		for cell: Variant in voyage.path:
			if not cell is int or cell < 0 or cell >= 16384 or data.terrain[cell] != "water": return "Nave en tierra"
			if previous >= 0 and not preload("res://sim/pathfinding.gd").neighbors(previous,128).has(cell): return "Ruta marítima discontinua"
			previous = cell
		if voyage.path[-1]%128 != 0: return "Ruta sin salida al mar"
		var dock: Dictionary = buildings[voyage.dock]
		var start: Vector2i = Vector2i(voyage.path[0]%128,voyage.path[0]/128)
		var dock_size: int = definitions.buildings.dock.size
		if not ((start.x == dock.x-1 or start.x == dock.x+dock_size) and start.y >= dock.z and start.y < dock.z+dock_size or (start.y == dock.z-1 or start.y == dock.z+dock_size) and start.x >= dock.x and start.x < dock.x+dock_size): return "Ruta ajena al muelle"
		if voyage.direction == "buy": total += voyage.quantity
	if total > storage: return "Capacidad excedida"
	docks.clear()
	for route: Variant in data.trade_routes:
		if not route is Dictionary: return "Ruta automática inválida"
		var error: String = check_order(route,buildings,definitions)
		if not error.is_empty(): return error
		if docks.has(route.dock) or not route.get("status") is String: return "Ruta automática duplicada"
		docks[route.dock] = true
	return ""

static func check_order(order: Dictionary, buildings: Dictionary, definitions: Dictionary) -> String:
	if not order.get("dock") is int or not buildings.has(order.dock) or buildings[order.dock].type != "dock": return "Muelle inválido"
	if not definitions.ports.has(order.get("port","")) or order.get("direction","") not in ["buy","sell"]: return "Puerto inválido"
	var port: Dictionary = definitions.ports[order.port]
	if not order.get("quantity") is int or order.quantity < 1 or order.quantity > port.capacity: return "Cantidad inválida"
	if not (port.sells if order.direction == "buy" else port.buys).has(order.get("resource","")): return "Mercancía inválida"
	return ""
