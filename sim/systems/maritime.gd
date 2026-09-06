extends RefCounted
const Paths = preload("res://sim/pathfinding.gd")
const Economy = preload("res://sim/systems/economy.gd")

static func harbor_path(sim: Variant, dock: Dictionary) -> Array:
	if dock.is_empty(): return []
	var starts: Array = []
	for cell: int in sim.edges(dock):
		if sim.state.terrain[cell] == "water": starts.append(cell)
	var previous: Dictionary = {}
	var queue: Array = starts.duplicate()
	for cell: int in starts: previous[cell] = -1
	var index: int = 0
	while index < queue.size():
		var cell: int = queue[index]
		index += 1
		if cell % sim.width() == 0:
			var path: Array = [cell]
			while previous[path[0]] != -1: path.push_front(previous[path[0]])
			return path
		for next: int in Paths.neighbors(cell,sim.width()):
			if sim.state.terrain[next] == "water" and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	return []

static func reserved(sim: Variant) -> int:
	var amount: int = 0
	for voyage: Dictionary in sim.state.voyages:
		if voyage.direction == "buy": amount += voyage.quantity
	return amount

static func validate(sim: Variant, command: Dictionary) -> Dictionary:
	var port: String = command.get("port","")
	var resource: String = command.get("resource","")
	var direction: String = command.get("direction","")
	var quantity: Variant = command.get("quantity")
	if not sim.definitions.ports.has(port) or direction not in ["buy","sell"]: return sim.result("Elige un puerto y una operación")
	var market: Dictionary = sim.definitions.ports[port]
	var prices: Dictionary = market.sells if direction == "buy" else market.buys
	if not prices.has(resource): return sim.result("Este puerto no comercia con ese recurso")
	if not quantity is int or quantity <= 0 or quantity > market.capacity: return sim.result("Carga: entre 1 y %d unidades" % market.capacity)
	var dock: Dictionary = sim.building(command.get("dock",0))
	if dock.is_empty() or dock.type != "dock" or not dock.active or not dock.connected: return sim.result("Necesitas un muelle conectado al almacén")
	for voyage: Dictionary in sim.state.voyages:
		if voyage.dock == dock.id: return sim.result("La nave de este muelle está de viaje")
	var key: String = "%s:%s:%s" % [port,direction,resource]
	if sim.state.trade_volume.get(key,0) + quantity > market.capacity*3: return sim.result("Cupo del puerto agotado; se renueva cada 10 días")
	var cost: int = market.fee + (prices[resource]*quantity if direction == "buy" else 0)
	if sim.state.coins < cost: return sim.result("Monedas insuficientes para carga y flete")
	if direction == "buy" and Economy.total(sim.state.inventory)+reserved(sim)+quantity > Economy.capacity(sim): return sim.result("Sin espacio para la carga reservada")
	if direction == "sell" and sim.state.inventory[resource] < quantity: return sim.result("Existencias insuficientes")
	var path: Array = harbor_path(sim,dock)
	if path.is_empty(): return sim.result("El muelle necesita salida al Atlántico")
	var checked: Dictionary = sim.result()
	checked.path = path
	checked.cost = cost
	checked.value = quantity*prices[resource]
	checked.key = key
	return checked

static func dispatch(sim: Variant, command: Dictionary, checked: Dictionary) -> void:
	var port: Dictionary = sim.definitions.ports[command.port]
	sim.state.coins -= checked.cost
	if command.direction == "sell": sim.state.inventory[command.resource] -= command.quantity
	sim.state.trade_volume[checked.key] = sim.state.trade_volume.get(checked.key,0)+command.quantity
	sim.state.voyages.append({"id":sim.state.next_voyage,"dock":command.dock,"port":command.port,"direction":command.direction,"resource":command.resource,"quantity":command.quantity,"value":checked.value,"elapsed":0,"duration":port.days*sim.definitions.balance.ticks_per_day,"path":checked.path,"status":"Navegando"})
	sim.state.next_voyage += 1

static func step(sim: Variant) -> void:
	var season: int = sim.state.tick / (sim.definitions.balance.ticks_per_day*10)
	if season != sim.state.trade_season:
		sim.state.trade_season = season
		sim.state.trade_volume.clear()
	for voyage: Dictionary in sim.state.voyages.duplicate():
		voyage.elapsed = mini(voyage.duration,voyage.elapsed+1)
		if voyage.elapsed < voyage.duration: continue
		var dock: Dictionary = sim.building(voyage.dock)
		if dock.is_empty() or not dock.connected or not dock.active:
			voyage.status = "Esperando camino al almacén"
			continue
		if voyage.direction == "buy": sim.state.inventory[voyage.resource] += voyage.quantity
		else:
			sim.state.coins += voyage.value
			sim.state.exported += voyage.quantity
		sim.state.trade_completed += 1
		sim.state.trade_history.push_front("%s · %s %d %s" % [sim.definitions.ports[voyage.port].label,"Importadas" if voyage.direction == "buy" else "Exportadas",voyage.quantity,sim.definitions.resources[voyage.resource].label])
		if sim.state.trade_history.size() > 8: sim.state.trade_history.pop_back()
		sim.state.voyages.erase(voyage)
	if sim.state.tick % sim.definitions.balance.ticks_per_day != 0: return
	for route: Dictionary in sim.state.trade_routes:
		var busy: bool = sim.state.voyages.any(func(v: Dictionary) -> bool: return v.dock == route.dock)
		if busy:
			route.status = "Nave de viaje"
			continue
		var checked: Dictionary = validate(sim,route)
		route.status = "Navegando" if checked.ok else checked.message
		if checked.ok: dispatch(sim,route,checked)
