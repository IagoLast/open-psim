extends RefCounted
## Build a separate, validated simulation before replacing the current city.
const Simulation = preload("res://sim/simulation.gd")
const Validation = preload("res://sim/validation.gd")
const CENTER := Vector2i(445,136)

static func generate(sim: Variant, preset: String) -> Dictionary:
	if preset not in ["developing","advanced"]: return sim.result("Ciudad desconocida: developing o advanced")
	var candidate := Simulation.new()
	candidate.create(1530,sim.definitions)
	var error: String = _populate(candidate,preset == "advanced")
	if not error.is_empty(): return sim.result(error)
	error = Validation.check(candidate.serialize(),candidate.definitions)
	if not error.is_empty(): return sim.result("Ciudad inválida: " + error)
	var restored: Dictionary = sim.restore(candidate.serialize())
	if not restored.ok: return restored
	return {"ok":true,"replaced":true,"message":"%s preparada: %d vecinos y %d edificios. Partida en pausa." % ["Ciudad avanzada" if preset == "advanced" else "Villa en desarrollo",sim.state.citizens.size(),sim.state.buildings.size()]}

static func _populate(sim: Variant, advanced: bool) -> String:
	# Construction budget exists only in the candidate; final stock obeys storage limits.
	sim.state.coins = 1000000
	for resource: String in sim.state.inventory: sim.state.inventory[resource] = 10000
	var warehouse: int = _place(sim,"warehouse",Vector2i(441,125))
	if warehouse == 0: return "No se pudo colocar el almacén"
	var homes: Array = []
	for z: int in [125,128,132,135,139,142]:
		var id: int = _place(sim,"house",Vector2i(437,z))
		if id == 0: return "No se pudo preparar el barrio"
		homes.append(id)
	if advanced:
		for z: int in [132,135,139,142,146,149]:
			var id: int = _place(sim,"house",Vector2i(441,z))
			if id == 0: return "No se pudo ampliar el barrio"
			homes.append(id)
	for origin: Vector2i in [Vector2i(439,127),Vector2i(439,140),Vector2i(443,147)]:
		if _place(sim,"well",origin) == 0: return "No se pudo abastecer el barrio"
	var civic: Array = ["market","clinic","chapel","firewatch","maintenance","depot","horreo"]
	if advanced: civic.append_array(["watch","school","inn","depot","horreo"])
	for kind: String in civic:
		if _place(sim,kind,CENTER) == 0: return "No se pudo colocar " + kind
	var industry: Array = ["farm","farm","lumber","lumber","fishery","saltworks","saltery","mill","bakery","sheep"]
	if advanced: industry.append_array(["quarry","claypit","mine","vineyard","winery","potter","smith","weaver","dock","farm","farm","fishery","bakery","mill","sheep","lumber"])
	else: industry.append_array(["quarry","potter","claypit"])
	for kind: String in industry:
		var origin: Vector2i = CENTER + Vector2i(9,0)
		if kind in ["farm","vineyard"]: origin = Vector2i(450,111)
		elif kind == "lumber": origin = Vector2i(456,146)
		elif kind in ["fishery","saltworks","dock"]: origin = Vector2i(435,84)
		if _place(sim,kind,origin) == 0: return "No hay una parcela conectable para " + kind
	if advanced and _place(sim,"convent",Vector2i(424,132)) == 0: return "No se pudo colocar el convento"
	# Fill the existing homes with established residents, then let normal job assignment
	# and service coverage determine their actual needs and housing levels.
	for id: int in homes:
		var home: Dictionary = sim.building(id)
		for i: int in range(4): sim._add_citizen(id,home.access)
	sim.Citizens.assign_jobs(sim)
	for id: int in homes:
		var home: Dictionary = sim.building(id)
		if not home.water:
			if _place(sim,"well",Vector2i(home.x,home.z)+Vector2i(0,2)) == 0: return "Falta agua en el barrio"
	# Ensure that preparing a larger city does not begin with forced unemployment.
	var jobs: int = 0
	for item: Dictionary in sim.state.buildings: jobs += sim.definitions.buildings[item.type].jobs
	while jobs < sim.state.citizens.size():
		if _place(sim,"farm",Vector2i(450,111)) == 0: return "Faltan empleos"
		jobs += 2
	sim.Citizens.assign_jobs(sim)
	for resource: String in sim.state.inventory: sim.state.inventory[resource] = 0
	var supplies: Dictionary = {"wood":180,"stone":90,"grain":480 if advanced else 300,"fish":100,"salt":60,"salted_fish":40,"flour":100,"bread":200,"clay":60,"iron":50,"tools":30,"grapes":60,"wine":80,"pottery":80,"wool":60,"cloth":80}
	for resource: String in supplies: sim.state.inventory[resource] = supplies[resource]
	sim.state.coins = 12000 if advanced else 4000
	for id: int in homes:
		var home: Dictionary = sim.building(id)
		var occupants: Array = sim.state.citizens.filter(func(c: Dictionary) -> bool: return c.home == id)
		if sim.Housing.missing(sim,home,2,occupants).is_empty(): home.level = 2
		if advanced and sim.Housing.missing(sim,home,3,occupants).is_empty(): home.level = 3
	# Start at the first workday, with honest progression counters and routes.
	sim.state.tick = sim.definitions.balance.departure
	sim.Citizens.move(sim)
	return ""

static func _place(sim: Variant, kind: String, origin: Vector2i, rotation: int = 0) -> int:
	for radius: int in range(85):
		for z: int in range(origin.y-radius,origin.y+radius+1):
			for x: int in range(origin.x-radius,origin.x+radius+1):
				if maxi(absi(x-origin.x),absi(z-origin.y)) != radius: continue
				var order: Dictionary = {"type":"build","kind":kind,"x":x,"z":z,"rotation":rotation}
				if not sim.validate_command(order).ok: continue
				var path: Array = _connection(sim,kind,x,z,rotation)
				if path.is_empty(): continue
				var result: Dictionary = sim.apply_command(order)
				if not result.ok: continue
				var id: int = sim.state.next_building-1
				result = sim.apply_command({"type":"road","cells":path})
				if result.ok and sim.building(id).connected: return id
				return 0
	return 0

static func _connection(sim: Variant, kind: String, x: int, z: int, rotation: int = 0) -> Array:
	var footprint: Array = sim.footprint(kind,x,z,rotation)
	var previous: Dictionary = {}
	var queue: Array = []
	for cell: int in sim.edges({"type":kind,"x":x,"z":z,"rotation":rotation}):
		if sim.state.terrain[cell] == "water" or sim.occupied.has(cell): continue
		previous[cell] = -1
		queue.append(cell)
	var index: int = 0
	while index < queue.size() and index < 12000:
		var cell: int = queue[index]
		index += 1
		if sim.exterior.has(cell):
			var path: Array = [cell]
			while previous[path[-1]] != -1: path.append(previous[path[-1]])
			return path
		for next: int in sim.Paths.neighbors(cell,sim.width()):
			if previous.has(next) or footprint.has(next) or sim.occupied.has(next) or sim.state.terrain[next] == "water": continue
			previous[next] = cell
			queue.append(next)
	return []
