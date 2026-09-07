extends RefCounted
## Session-only tools: no arbitrary code evaluation and no changes to save schema.
const Presets = preload("res://sim/city_presets.gd")
const MONEY_RESERVE: int = 1000000000
var infinite_money: bool = false
var _previous_coins: int = 0

static func replaces_city(text: String) -> bool:
	var parts: PackedStringArray = text.strip_edges().to_lower().split(" ",false)
	return parts.size() == 2 and parts[0] in ["city","ciudad"] and parts[1] in ["developing","advanced"]

func reset() -> void:
	infinite_money = false
	_previous_coins = 0

func enforce(sim: Variant) -> void:
	if infinite_money: sim.state.coins = MONEY_RESERVE

func execute(sim: Variant, text: String) -> Dictionary:
	var args: PackedStringArray = text.strip_edges().to_lower().split(" ",false)
	if args.is_empty(): return sim.result("Escribe help para ver los comandos")
	match args[0]:
		"help","ayuda":
			return _ok("money infinite / money off · activar/desactivar dinero infinito\nmoney 10000 · añadir monedas\nresource wood 100 · añadir recurso (usa su identificador)\nresources · ver identificadores\nstock · reponer existencias hasta la capacidad disponible\ncitizens 10 · añadir vecinos donde hay agua, plazas y empleo\nrepair · reparar todos los edificios\ncity developing / city advanced · preparar ciudad\nLos trucos son de esta sesión; los cambios de la ciudad sí se guardan.")
		"money","dinero":
			if args.size() != 2: return sim.result("Uso: money infinite | off | cantidad")
			if args[1] in ["infinite","on","off"]:
				var enabled: bool = args[1] != "off"
				if enabled and not infinite_money: _previous_coins = sim.state.coins
				if not enabled and infinite_money: sim.state.coins = _previous_coins
				infinite_money = enabled
				enforce(sim)
				return _ok("Dinero infinito activado" if enabled else "Dinero infinito desactivado; saldo anterior restaurado")
			var amount: int = _amount(args[1],100000000)
			if amount < 1: return sim.result("Cantidad válida: 1–100000000")
			sim.state.coins = mini(MONEY_RESERVE,sim.state.coins+amount)
			return _ok("Añadidas %d monedas" % amount)
		"resources":
			return _ok("Recursos: " + ", ".join(sim.definitions.resources.keys()))
		"resource","recurso":
			if args.size() != 3 or not sim.definitions.resources.has(args[1]): return sim.result("Uso: resource <identificador> <cantidad>. Consulta resources.")
			var amount: int = _amount(args[2],100000)
			if amount < 1: return sim.result("Cantidad válida: 1–100000")
			if not sim.Economy.has_room(sim,args[1],amount): return sim.result("No cabe en el almacén: construye depósitos u hórreos")
			sim.state.inventory[args[1]] += amount
			return _ok("Añadido: %s × %d" % [sim.definitions.resources[args[1]].label,amount])
		"stock":
			if args.size() != 1: return sim.result("Uso: stock")
			var added: int = 0
			# Round-robin avoids filling the warehouse with just the first resource.
			for i: int in range(200):
				for resource: String in sim.state.inventory:
					if sim.state.inventory[resource] < 200 and sim.Economy.has_room(sim,resource,1):
						sim.state.inventory[resource] += 1
						added += 1
			return _ok("Repuestas %d unidades, respetando almacenamiento y cargas reservadas" % added)
		"citizens","vecinos":
			if args.size() != 2: return sim.result("Uso: citizens <cantidad>")
			var amount: int = _amount(args[1],500)
			if amount < 1: return sim.result("Cantidad válida: 1–500")
			var added: int = 0
			for i: int in range(amount):
				var plan: Dictionary = sim.Citizens.immigration_plan(sim.state,sim.definitions)
				if plan.count == 0: break
				var home: Dictionary = sim.building(plan.homes[0])
				sim._add_citizen(home.id,home.access)
				sim.Citizens.assign_jobs(sim)
				added += 1
			return _ok("Llegaron %d vecinos; se necesitan plazas, agua, comida y empleos para admitir más" % added)
		"repair","reparar":
			if args.size() != 1: return sim.result("Uso: repair")
			for item: Dictionary in sim.state.buildings:
				if item.ruined: item.active = true
				item.ruined = false
				item.burn_days = 0
				item.condition = 100
				item.fire_risk = 0
			sim.rebuild()
			return _ok("Edificios reparados e incendios extinguidos")
		"city","ciudad":
			if not replaces_city(text): return sim.result("Uso: city developing | city advanced")
			var result: Dictionary = Presets.generate(sim,args[1])
			if result.ok: reset()
			return result
	return sim.result("Comando desconocido. Escribe help.")

static func _amount(text: String, maximum: int) -> int:
	if text.length() > 9 or not text.is_valid_int(): return -1
	var amount: int = int(text)
	return amount if amount > 0 and amount <= maximum else -1

static func _ok(message: String) -> Dictionary:
	return {"ok":true,"message":message}
