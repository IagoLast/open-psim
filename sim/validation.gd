extends RefCounted
const Map = preload("res://sim/world_map.gd")
const Footprints = preload("res://sim/footprints.gd")

static func check(data: Dictionary, definitions: Dictionary) -> String:
	if not data.get("building_layout",1) is int or data.get("building_layout",1) not in [1,2]: return "Versión de parcelas incompatible"
	if data.get("map_id") != Map.ID: return "Guardado de otro mapa; inicia una partida en la ría de Pontevedra"
	if not data.get("topology") is int or data.topology < 1: return "Topología inválida"
	var template: Dictionary = {"schema":TYPE_INT,"balance_version":TYPE_INT,"seed":TYPE_INT,"rng_state":TYPE_STRING,"tick":TYPE_INT,"sequence":TYPE_INT,"next_building":TYPE_INT,"next_citizen":TYPE_INT,"coins":TYPE_INT,"inventory":TYPE_DICTIONARY,"terrain":TYPE_ARRAY,"roads":TYPE_ARRAY,"buildings":TYPE_ARRAY,"citizens":TYPE_ARRAY,"exported":TYPE_INT,"immigration_checks":TYPE_INT,"milestones":TYPE_ARRAY,"alerts":TYPE_ARRAY,"objective":TYPE_DICTIONARY,"operating":TYPE_INT,"cash_history":TYPE_ARRAY,"pilgrims":TYPE_ARRAY,"next_pilgrim":TYPE_INT,"pilgrims_served":TYPE_INT,"reputation":TYPE_INT,"merchant":TYPE_DICTIONARY,"merchant_visits":TYPE_INT}
	for key: String in template:
		if not data.has(key) or typeof(data[key]) != template[key]: return "Guardado incompleto: " + key
	if data.schema != 3 or data.balance_version != definitions.balance.version: return "Versión de guardado incompatible"
	if data.tick < 0 or data.sequence < 0 or data.coins < 0 or data.exported < 0 or data.immigration_checks < 0: return "Contadores inválidos"
	if not data.rng_state.is_valid_int(): return "Estado RNG inválido"
	if data.terrain.size() != (Map.SIZE*Map.SIZE) or data.buildings.size() > (Map.SIZE*Map.SIZE) or data.citizens.size() > (Map.SIZE*Map.SIZE*4) or data.roads.size() > (Map.SIZE*Map.SIZE) or data.alerts.size() > 6 or data.milestones.size() > 20: return "Tamaño de estado inválido"
	for terrain: Variant in data.terrain:
		if terrain not in ["land", "water", "forest", "fertile", "rock", "clay", "ore"]: return "Terreno inválido"
	if data.inventory.size() != definitions.resources.size(): return "Inventario inválido"
	for resource: String in definitions.resources:
		if not data.inventory.get(resource) is int or data.inventory[resource] < 0: return "Inventario inválido"

	var occupied: Dictionary = {}
	var roads: Dictionary = {}
	for cell: Variant in data.roads:
		if not cell is int or cell < 0 or cell >= (Map.SIZE*Map.SIZE) or roads.has(cell) or data.terrain[cell] == "water": return "Camino inválido"
		roads[cell] = true
	var surfaces: Variant = data.get("road_surfaces",{})
	if not surfaces is Dictionary: return "Tipos de camino inválidos"
	for key: Variant in surfaces:
		if not key is String or not key.is_valid_int() or str(int(key)) != key or not roads.has(int(key)): return "Superficie sin camino"
		if surfaces[key] not in ["paved","dirt"]: return "Superficie de camino inválida"
		if surfaces[key] == "dirt" and Map.BURGO_BRIDGE.has_point(Vector2i(int(key)%Map.SIZE,int(key)/Map.SIZE)): return "Puente sin pavimento"
	if not data.get("shoreline_fill",[]) is Array: return "Relleno costero inválido"
	var filled: Dictionary = {}
	for cell: Variant in data.get("shoreline_fill",[]):
		if not cell is int or cell < 0 or cell >= Map.SIZE*Map.SIZE or data.terrain[cell] != "land" or filled.has(cell): return "Relleno costero inválido"
		filled[cell] = true
	var buildings: Dictionary = {}
	for item: Variant in data.buildings:
		if not item is Dictionary: return "Edificio inválido"
		for field: String in ["id","x","z","priority","work","access","present","assigned","care_days","produced","level","rotation","front","adjoined","upgrade_days","decline_days","condition","fire_risk","burn_days","age"]:
			if not item.get(field) is int: return "Campo de edificio inválido"
		for field: String in ["active","connected","water","ruined"]:
			if not item.get(field) is bool: return "Campo de edificio inválido"
		if not item.get("block") is String or not definitions.buildings.has(item.get("type","")): return "Tipo de edificio inválido"
		if item.id <= 0 or buildings.has(item.id) or item.id >= data.next_building: return "ID de edificio inválido"
		if item.rotation not in [0,1,2,3] or item.front not in [0,1,2,3]: return "Orientación inválida"
		var size: Vector2i = Footprints.dimensions(definitions.buildings[item.type],item.rotation)
		if item.x < 0 or item.z < 0 or item.x + size.x > Map.SIZE or item.z + size.y > Map.SIZE: return "Huella inválida"
		if item.level < 1 or item.level > 3 or not item.get("services") is Dictionary or not item.get("service_active") is bool: return "Servicios inválidos"
		for service: Variant in item.services:
			if service not in ["water","market","health","faith","safety","education","fire","maintenance","hospitality"] or not item.services[service] is bool: return "Cobertura inválida"
		if item.has("funded") and not item.funded is bool: return "Mantenimiento inválido"
		if item.priority not in [0,1] or item.work < 0 or item.work > definitions.buildings[item.type].get("work",0) or item.care_days < 0 or item.care_days > 3 or item.produced < 0: return "Producción inválida"
		for z: int in range(item.z, item.z + size.y):
			for x: int in range(item.x, item.x + size.x):
				var cell: int = z * Map.SIZE + x
				if Map.BURGO_BRIDGE.has_point(Vector2i(x,z)): return "Edificio sobre el puente"
				if occupied.has(cell) or roads.has(cell) or data.terrain[cell] == "water": return "Solapamiento inválido"
				occupied[cell] = true
		buildings[item.id] = item
	for cell: int in Map.main_road():
		if not roads.has(cell): return "Camino principal incompleto"
	var ids: Dictionary = {}
	var jobs: Dictionary = {}
	var homes: Dictionary = {}
	for citizen: Variant in data.citizens:
		if not citizen is Dictionary: return "Ciudadano inválido"
		for field: String in ["id","home","job","cell","progress","destination","route_version","satisfaction","age","hardship"]:
			if not citizen.get(field) is int: return "Campo de ciudadano inválido"
		for field: String in ["fed","water","arriving"]:
			if not citizen.get(field) is bool: return "Necesidad inválida"
		if not citizen.get("name") is String or not citizen.get("activity") is String or not citizen.get("route") is Array: return "Ciudadano incompleto"
		if ids.has(citizen.id) or citizen.id <= 0 or citizen.id >= data.next_citizen: return "ID de ciudadano inválido"
		ids[citizen.id] = true
		if not buildings.has(citizen.home) or buildings[citizen.home].type != "house": return "Vivienda inválida"
		homes[citizen.home] = homes.get(citizen.home,0) + 1
		if homes[citizen.home] > definitions.housing.levels[-1].capacity: return "Vivienda sobreocupada"
		if citizen.job != 0:
			if not buildings.has(citizen.job): return "Empleo inválido"
			jobs[citizen.job] = jobs.get(citizen.job,0) + 1
			if jobs[citizen.job] > definitions.buildings[buildings[citizen.job].type].jobs: return "Puestos excedidos"
		if citizen.cell < 0 or citizen.cell >= (Map.SIZE*Map.SIZE) or data.terrain[citizen.cell] == "water" or citizen.progress < 0 or citizen.progress >= definitions.balance.move_ticks or citizen.satisfaction < 0 or citizen.satisfaction > 100: return "Movimiento o satisfacción inválidos"
		if citizen.destination < -1 or citizen.destination >= (Map.SIZE*Map.SIZE) or citizen.route.size() > (Map.SIZE*Map.SIZE): return "Destino inválido"
		var previous: int = citizen.cell
		for cell: Variant in citizen.route:
			if not cell is int or not preload("res://sim/pathfinding.gd").neighbors(previous).has(cell): return "Ruta inválida"
			previous = cell
	if data.get("map_size") != Map.SIZE: return "Dimensiones incompatibles"
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
		if not voyage.get("status") is String or not voyage.get("path") is Array or voyage.path.is_empty() or voyage.path.size() > (Map.SIZE*Map.SIZE): return "Ruta marítima inválida"
		var previous: int = -1
		for cell: Variant in voyage.path:
			if not cell is int or cell < 0 or cell >= (Map.SIZE*Map.SIZE) or data.terrain[cell] != "water": return "Nave en tierra"
			if previous >= 0 and not preload("res://sim/pathfinding.gd").neighbors(previous,Map.SIZE).has(cell): return "Ruta marítima discontinua"
			previous = cell
		if voyage.path[-1]%Map.SIZE != 0: return "Ruta sin salida al mar"
		var dock: Dictionary = buildings[voyage.dock]
		var start: Vector2i = Vector2i(voyage.path[0]%Map.SIZE,voyage.path[0]/Map.SIZE)
		var dock_size: Vector2i = Footprints.dimensions(definitions.buildings.dock,dock.rotation)
		if not ((start.x == dock.x-1 or start.x == dock.x+dock_size.x) and start.y >= dock.z and start.y < dock.z+dock_size.y or (start.y == dock.z-1 or start.y == dock.z+dock_size.y) and start.x >= dock.x and start.x < dock.x+dock_size.x): return "Ruta ajena al muelle"
	if not preload("res://sim/systems/economy.gd").storage_fits(data.inventory,data.buildings,definitions,data.voyages,true): return "Capacidad excedida"
	docks.clear()
	for route: Variant in data.trade_routes:
		if not route is Dictionary: return "Ruta automática inválida"
		var error: String = check_order(route,buildings,definitions)
		if not error.is_empty(): return error
		if docks.has(route.dock) or not route.get("status") is String: return "Ruta automática duplicada"
		docks[route.dock] = true
	return check_progression(data,definitions,buildings)

static func check_order(order: Dictionary, buildings: Dictionary, definitions: Dictionary) -> String:
	if not order.get("dock") is int or not buildings.has(order.dock) or buildings[order.dock].type != "dock": return "Muelle inválido"
	if not definitions.ports.has(order.get("port","")) or order.get("direction","") not in ["buy","sell"]: return "Puerto inválido"
	var port: Dictionary = definitions.ports[order.port]
	if not order.get("quantity") is int or order.quantity < 1 or order.quantity > port.capacity: return "Cantidad inválida"
	if not (port.sells if order.direction == "buy" else port.buys).has(order.get("resource","")): return "Mercancía inválida"
	return ""

static func check_progression(data: Dictionary, definitions: Dictionary, buildings: Dictionary) -> String:
	for field: String in ["stage","stable_days","victory_days","empty_days"]:
		if not data.objective.get(field) is int or data.objective[field] < 0: return "Objetivo inválido"
	if data.objective.stage > 4: return "Etapa inválida"
	for field: String in ["founded","won","failed","aid_used"]:
		if not data.objective.get(field) is bool: return "Objetivo incompleto"
	if not data.objective.get("message") is String: return "Objetivo incompleto"
	if data.cash_history.size() > definitions.scenario.hold_days: return "Historial económico inválido"
	for amount: Variant in data.cash_history:
		if not amount is int: return "Saldo inválido"
	for item: Dictionary in buildings.values():
		if item.condition < 0 or item.condition > 100 or item.fire_risk < 0 or item.fire_risk > 100 or item.burn_days < 0 or item.burn_days > 3 or item.age < 0 or item.upgrade_days < 0 or item.upgrade_days >= definitions.housing.upgrade_days or item.decline_days < 0 or item.adjoined < 0 or item.adjoined > 15 or not item.get("needs") is String: return "Evolución o conservación inválida"
	for citizen: Dictionary in data.citizens:
		if citizen.age < 0 or citizen.hardship < 0: return "Estado de vecino inválido"
	if data.next_pilgrim < 1 or data.pilgrims_served < 0 or data.reputation < 0 or data.reputation > 100 or data.merchant_visits < 0: return "Visitantes inválidos"
	var ids: Dictionary = {}
	for p: Variant in data.pilgrims:
		if not p is Dictionary: return "Peregrino inválido"
		for field: String in ["id","inn","cell","stay","route_version"]:
			if not p.get(field) is int: return "Peregrino incompleto"
		if p.id < 1 or p.id >= data.next_pilgrim or ids.has(p.id) or p.cell < 0 or p.cell >= Map.SIZE*Map.SIZE or data.terrain[p.cell] == "water" or p.stay < 0: return "Peregrino inválido"
		ids[p.id] = true
		if p.get("phase","") not in ["arriving","staying","leaving"] or not p.get("served") is bool or not p.get("route") is Array: return "Peregrino incompleto"
		if p.phase != "leaving" and (not buildings.has(p.inn) or buildings[p.inn].type != "inn"): return "Hospedería ausente"
		var previous: int = p.cell
		for cell: Variant in p.route:
			if not cell is int or not preload("res://sim/pathfinding.gd").neighbors(previous).has(cell): return "Ruta de peregrino inválida"
			previous = cell
	if data.merchant.is_empty(): return ""
	var m: Dictionary = data.merchant
	for field: String in ["number","elapsed","duration"]:
		if not m.get(field) is int or m[field] < 0: return "Mercader inválido"
	if m.duration != definitions.balance.ticks_per_day*4 or m.elapsed >= m.duration or not definitions.ports.has(m.get("port","")): return "Visita inválida"
	var expected: String = "En puerto" if m.elapsed >= definitions.balance.ticks_per_day and m.elapsed < definitions.balance.ticks_per_day*3 else ("Regresando" if m.elapsed >= definitions.balance.ticks_per_day*3 else "Llegando")
	if m.get("status") != expected: return "Estado de mercader inválido"
	for field: String in ["stock","demand"]:
		if not m.get(field) is Dictionary or m[field].size() != definitions.resources.size(): return "Cupo de mercader inválido"
		for resource: String in definitions.resources:
			if not m[field].get(resource) is int or m[field][resource] < 0 or m[field][resource] > (40 if field == "stock" else 60): return "Cupo de mercader inválido"
	if not m.get("path") is Array or m.path.is_empty() or m.path.size() > Map.SIZE*Map.SIZE: return "Ruta de mercader inválida"
	var previous: int = -1
	for cell: Variant in m.path:
		if not cell is int or cell < 0 or cell >= Map.SIZE*Map.SIZE or data.terrain[cell] != "water": return "Mercader en tierra"
		if previous >= 0 and not preload("res://sim/pathfinding.gd").neighbors(previous).has(cell): return "Ruta de mercader discontinua"
		previous = cell
	if m.path[-1]%Map.SIZE != 0: return "Mercader sin salida al mar"
	return ""
