extends RefCounted
## Visiting traders need a connected warehouse, never a player-owned dock.
static func step(sim: Variant) -> void:
	var day_ticks: int = sim.definitions.balance.ticks_per_day
	var visit: Dictionary = sim.state.merchant
	if visit.is_empty():
		if not sim.state.buildings.any(func(b: Dictionary) -> bool: return b.type == "warehouse" and b.connected): return
		var nearest: int = -1
		var best: float = INF
		for cell: int in range(sim.state.terrain.size()):
			if sim.state.terrain[cell] != "water": continue
			var distance: float = Vector2(cell%sim.width(),cell/sim.width()).distance_squared_to(Vector2(sim.Map.START))
			if distance < best:
				best = distance
				nearest = cell
		var harbor := {"type":"warehouse","x":nearest%sim.width()+1,"z":nearest/sim.width(),"rotation":0}
		var path: Array = sim.Maritime.harbor_path(sim,harbor)
		if path.is_empty(): return
		var stock: Dictionary = {}
		var demand: Dictionary = {}
		for resource: String in sim.definitions.resources:
			stock[resource] = 40
			demand[resource] = 60
		var number: int = sim.state.merchant_visits
		sim.state.merchant = {"number":number,"port":sim.definitions.ports.keys()[number%sim.definitions.ports.size()],"elapsed":0,"duration":day_ticks*4,"path":path,"stock":stock,"demand":demand,"status":"Llegando"}
		sim.state.merchant_visits += 1
		return
	visit.elapsed += 1
	visit.status = "En puerto" if visit.elapsed >= day_ticks and visit.elapsed < day_ticks*3 else ("Regresando" if visit.elapsed >= day_ticks*3 else "Llegando")
	if visit.elapsed >= visit.duration: sim.state.merchant = {}

static func validate(sim: Variant, command: Dictionary) -> Dictionary:
	var warehouse: Dictionary = sim.building(command.get("warehouse",0))
	if warehouse.is_empty() or warehouse.type != "warehouse" or not warehouse.connected: return sim.result("Necesitas un almacén conectado al camino principal")
	if sim.state.merchant.is_empty() or sim.state.merchant.status != "En puerto": return sim.result("Espera a que el mercader atraque")
	var resource: String = command.get("resource","")
	var direction: String = command.get("direction","")
	var quantity: Variant = command.get("quantity")
	if not sim.definitions.resources.has(resource) or direction not in ["buy","sell"]: return sim.result("Mercancía u operación inválida")
	if not quantity is int or quantity <= 0: return sim.result("Cantidad inválida")
	var definition: Dictionary = sim.definitions.resources[resource]
	var price: int = definition.buy if direction == "buy" else definition.sell
	if price < 0: return sim.result("El mercader solo compra esta mercancía")
	var quota: Dictionary = sim.state.merchant.stock if direction == "buy" else sim.state.merchant.demand
	if quota[resource] < quantity: return sim.result("Cupo de esta visita agotado")
	if direction == "buy":
		if sim.state.coins < quantity*price: return sim.result("Monedas insuficientes")
		if not sim.Economy.has_room(sim,resource,quantity): return sim.result("Almacén lleno")
	elif sim.state.inventory[resource] < quantity: return sim.result("Existencias insuficientes")
	var result: Dictionary = sim.result()
	result.value = quantity*price
	return result

static func trade(sim: Variant, command: Dictionary, checked: Dictionary) -> void:
	var buying: bool = command.direction == "buy"
	var quantity: int = command.quantity
	sim.state.inventory[command.resource] += quantity if buying else -quantity
	sim.state.coins += -checked.value if buying else checked.value
	sim.state.operating += -checked.value if buying else checked.value
	if buying: sim.state.merchant.stock[command.resource] -= quantity
	else:
		sim.state.merchant.demand[command.resource] -= quantity
		sim.state.exported += quantity
	sim.state.trade_completed += 1
	sim.alert("Mercader: %s %d %s" % ["compradas" if buying else "vendidas",quantity,sim.definitions.resources[command.resource].label])
