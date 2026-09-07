extends RefCounted
const Paths = preload("res://sim/pathfinding.gd")

const SERVICE_LABELS: Dictionary = {"water":"Agua","market":"Mercado","health":"Salud","faith":"Culto","safety":"Seguridad","education":"Educación","fire":"Vigías del fuego","maintenance":"Conservación","hospitality":"Hospitalidad"}

static func refresh_services(sim: Variant) -> void:
	var coverage: Dictionary = {}
	for item: Dictionary in sim.state.buildings:
		var definition: Dictionary = sim.definitions.buildings[item.type]
		if not definition.has("service"): continue
		item.service_active = sim.operational(item) and item.connected and (definition.jobs == 0 or item.assigned > 0) and item.get("funded",true)
		if not item.service_active: continue
		var service: String = definition.service
		if not coverage.has(service): coverage[service] = []
		coverage[service].append({"distances":sim.road_distances(item.access),"radius":definition.radius})
	for home: Dictionary in sim.state.buildings:
		if home.type != "house": continue
		home.services = {}
		for service: String in SERVICE_LABELS:
			home.services[service] = false
			for zone: Dictionary in coverage.get(service,[]):
				if home.connected and zone.distances.get(home.access,99999) <= zone.radius: home.services[service] = true
		home.water = home.services.water
	for citizen: Dictionary in sim.state.citizens: citizen.water = sim.building(citizen.home).get("water",false)

static func assign_jobs(sim: Variant) -> void:
	var vacancies: Array = []
	for item: Dictionary in sim.state.buildings:
		item.assigned = 0
		item.present = 0
	for citizen: Dictionary in sim.state.citizens:
		var job: Dictionary = sim.building(citizen.job)
		var home: Dictionary = sim.building(citizen.home)
		if not job.is_empty() and sim.operational(job) and job.connected and home.connected and job.assigned < sim.definitions.buildings[job.type].jobs:
			job.assigned += 1
		else: citizen.job = 0
	for item: Dictionary in sim.state.buildings:
		if sim.operational(item) and item.connected and item.assigned < sim.definitions.buildings[item.type].jobs: vacancies.append(item)
	# Global priority, then actual road distance, citizen ID and building ID.
	while not vacancies.is_empty():
		var best: Array = []
		for citizen: Dictionary in sim.state.citizens:
			if citizen.job != 0 or citizen.arriving: continue
			var home: Dictionary = sim.building(citizen.home)
			if not home.connected: continue
			var distances: Dictionary = sim.road_distances(home.access)
			for item: Dictionary in vacancies:
				if not distances.has(item.access): continue
				var score: Array = [-item.priority, distances[item.access], citizen.id, item.id]
				if best.is_empty() or _less(score, best): best = score
		if best.is_empty(): break
		var workplace: Dictionary = sim.building(best[3])
		for citizen: Dictionary in sim.state.citizens:
			if citizen.id == best[2]: citizen.job = workplace.id
		workplace.assigned += 1
		if workplace.assigned >= sim.definitions.buildings[workplace.type].jobs: vacancies.erase(workplace)

	refresh_services(sim)

static func _less(a: Array, b: Array) -> bool:
	for i: int in range(a.size()):
		if a[i] != b[i]: return a[i] < b[i]
	return false

static func move(sim: Variant) -> void:
	var moment: int = sim.state.tick % sim.definitions.balance.ticks_per_day
	var working: bool = moment >= sim.definitions.balance.departure and moment < sim.definitions.balance["return"]
	for item: Dictionary in sim.state.buildings: item.present = 0
	for citizen: Dictionary in sim.state.citizens:
		var home: Dictionary = sim.building(citizen.home)
		var job: Dictionary = sim.building(citizen.job)
		var going_work: bool = working and not job.is_empty() and not citizen.arriving
		var target: int = job.access if going_work else home.access
		if target != citizen.destination or citizen.route_version != sim.topology:
			citizen.route = Paths.route(citizen.cell, target, sim.roads, sim.width())
			citizen.destination = target
			citizen.route_version = sim.topology
			citizen.progress = 0
		if citizen.cell == target and target >= 0 and sim.roads.has(target):
			citizen.arriving = false
			citizen.activity = "Trabajando" if going_work else "En casa"
			if going_work: job.present += 1
			continue
		if citizen.route.is_empty():
			citizen.activity = "Sin ruta"
			continue
		citizen.activity = "Al trabajo" if going_work else ("Llegando" if citizen.arriving else "A casa")
		citizen.progress += 1
		if citizen.progress >= sim.definitions.balance.move_ticks:
			citizen.cell = citizen.route.pop_front()
			citizen.progress = 0

static func daily(sim: Variant) -> void:
	for item: Dictionary in sim.state.buildings:
		var d: Dictionary = sim.definitions.buildings[item.type]
		if not d.has("service"): continue
		var upkeep: int = d.get("upkeep",0)
		item.funded = sim.operational(item) and item.connected and (d.jobs == 0 or item.assigned > 0) and sim.state.coins >= upkeep
		if item.funded:
			sim.state.coins -= upkeep
			sim.state.operating -= upkeep
		item.block = "" if item.funded else ("Sin presupuesto de mantenimiento" if sim.state.coins < upkeep else "Necesita camino y personal")
	refresh_services(sim)
	var count: int = sim.state.citizens.size()
	var day: int = sim.state.tick / sim.definitions.balance.ticks_per_day
	for offset: int in range(count):
		var citizen: Dictionary = sim.state.citizens[(offset + day) % count]
		var home: Dictionary = sim.building(citizen.home)
		citizen.fed = false
		if home.connected:
			for resource: String in ["bread", "grain", "fish"]:
				if sim.state.inventory[resource] > 0:
					sim.state.inventory[resource] -= 1
					citizen.fed = true
					break
		var target: int = 45 * int(citizen.fed) + 25 * int(citizen.water) + 10 * int(citizen.job != 0)
		for service: String in ["market","health","faith","safety","education"]:
			target += 4 * int(home.services.get(service,false))
		citizen.satisfaction = clampi(citizen.satisfaction + clampi(target - citizen.satisfaction, -10, 5), 0, 100)
		if citizen.fed and citizen.water:
			sim.state.coins += home.level
			sim.state.operating += home.level
		citizen.age += 1
		if not citizen.arriving and citizen.age > sim.definitions.scenario.arrival_grace_days:
			citizen.hardship = citizen.hardship+1 if citizen.job == 0 or not citizen.fed or not citizen.water else maxi(0,citizen.hardship-2)
	sim.Housing.daily(sim)
	for citizen: Dictionary in sim.state.citizens.duplicate():
		if citizen.hardship >= sim.definitions.scenario.emigration_days:
			sim.state.citizens.erase(citizen)
			sim.alert("Un vecino se marcha: revisa empleo, comida y agua")
		elif citizen.hardship >= 3: sim.alert("Vecinos consideran marcharse: faltan empleo o suministros")
	assign_jobs(sim)
	if day % sim.definitions.balance.immigration_days == 0:
		sim.state.immigration_checks += 1
		immigrate(sim)

static func immigration_plan(state: Dictionary, definitions: Dictionary) -> Dictionary:
	var homes: Array = []
	var vacancies: int = 0
	var happiness: int = 0
	var arriving: int = 0
	var housing: int = 0
	var connected_housing: int = 0
	var watered_housing: int = 0
	var warehouse: bool = false
	for citizen: Dictionary in state.citizens:
		happiness += citizen.satisfaction
		if citizen.arriving: arriving += 1
	for item: Dictionary in state.buildings:
		if item.type == "warehouse" and item.connected and not item.ruined: warehouse = true
		if item.type == "house" and not item.ruined:
			housing += 1
			if item.connected: connected_housing += 1
			if item.connected and item.water: watered_housing += 1
		if not item.connected or item.ruined: continue
		if item.active: vacancies += definitions.buildings[item.type].jobs-item.assigned
		if item.type == "house" and item.water:
			var used: int = 0
			for citizen: Dictionary in state.citizens:
				if citizen.home == item.id: used += 1
			for i: int in range(preload("res://sim/systems/housing.gd").capacity(item,definitions)-used): homes.append(item.id)
	var count: int = mini(definitions.balance.immigration_count,mini(homes.size(),maxi(0,vacancies-arriving)))
	var reason: String = ""
	if not warehouse: reason = "Construye un almacén conectado al camino principal."
	elif housing == 0: reason = "Construye una vivienda para alojar vecinos."
	elif connected_housing == 0: reason = "Conecta las viviendas al almacén mediante caminos."
	elif watered_housing == 0: reason = "Falta agua: conecta un pozo a los caminos de las viviendas."
	elif homes.is_empty(): reason = "No quedan plazas en viviendas con agua."
	elif vacancies-arriving <= 0: reason = "Abre empleos conectados al almacén: granja, leñadores o pesquería."
	elif happiness < state.citizens.size()*definitions.balance.satisfaction_min: reason = "Mejora la satisfacción de los vecinos: agua, comida y empleo."
	elif preload("res://sim/systems/economy.gd").food({"state":state}) < (state.citizens.size()+count)*definitions.balance.reserve_days:
		reason = "Falta reserva de comida para recibir nuevos vecinos."
	return {"homes":homes,"count":count if reason.is_empty() else 0,"reason":reason,"arriving":arriving}

static func immigrate(sim: Variant) -> void:
	var plan: Dictionary = immigration_plan(sim.state,sim.definitions)
	for i: int in range(plan.count):
		var home: Dictionary = sim.building(plan.homes[i])
		var distances: Dictionary = sim.road_distances(home.access)
		var entrance: int = sim.Map.entrance()
		if distances.get(sim.Map.exit_cell(),999999) < distances.get(entrance,999999): entrance = sim.Map.exit_cell()
		sim._add_citizen(home.id,entrance,true)
	assign_jobs(sim)
