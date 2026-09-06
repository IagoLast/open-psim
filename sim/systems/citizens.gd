extends RefCounted
const Paths = preload("res://sim/pathfinding.gd")

const SERVICE_LABELS: Dictionary = {"water":"Agua","market":"Mercado","health":"Salud","faith":"Culto","safety":"Seguridad","education":"Educación"}

static func refresh_services(sim: Variant) -> void:
	var coverage: Dictionary = {}
	for item: Dictionary in sim.state.buildings:
		var definition: Dictionary = sim.definitions.buildings[item.type]
		if not definition.has("service"): continue
		item.service_active = item.active and item.connected and (definition.jobs == 0 or item.assigned > 0) and item.get("funded",true)
		if not item.service_active: continue
		var service: String = definition.service
		if not coverage.has(service): coverage[service] = []
		coverage[service].append({"distances":Paths.distances(item.access,sim.roads,sim.width()),"radius":definition.radius})
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
		if not job.is_empty() and job.active and job.connected and home.connected and job.assigned < sim.definitions.buildings[job.type].jobs:
			job.assigned += 1
		else: citizen.job = 0
	for item: Dictionary in sim.state.buildings:
		if item.active and item.connected and item.assigned < sim.definitions.buildings[item.type].jobs: vacancies.append(item)
	# Global priority, then actual road distance, citizen ID and building ID.
	while not vacancies.is_empty():
		var best: Array = []
		for citizen: Dictionary in sim.state.citizens:
			if citizen.job != 0 or citizen.arriving: continue
			var home: Dictionary = sim.building(citizen.home)
			if not home.connected: continue
			var distances: Dictionary = Paths.distances(home.access, sim.roads, sim.width())
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
		item.funded = item.active and item.connected and (d.jobs == 0 or item.assigned > 0) and sim.state.coins >= upkeep
		if item.funded: sim.state.coins -= upkeep
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
		if citizen.fed and citizen.water: sim.state.coins += home.level
	for home: Dictionary in sim.state.buildings:
		if home.type != "house": continue
		var cared: bool = home.water and home.services.get("market",false) and home.services.get("health",false) and home.services.get("faith",false)
		var occupants: int = 0
		for citizen: Dictionary in sim.state.citizens:
			if citizen.home == home.id:
				occupants += 1
				if not citizen.fed: cared = false
		home.care_days = mini(3,home.care_days+1) if cared and occupants > 0 else 0
		home.level = 2 if home.care_days >= 3 else 1
		if home.level == 2 and home.services.get("safety",false) and home.services.get("education",false):
			var luxury: bool = true
			for resource: String in ["pottery","cloth","wine"]:
				if sim.state.inventory[resource] < 1: luxury = false
			if luxury:
				for resource: String in ["pottery","cloth","wine"]: sim.state.inventory[resource] -= 1
				home.level = 3
	if day % sim.definitions.balance.immigration_days == 0:
		sim.state.immigration_checks += 1
		immigrate(sim)

static func immigrate(sim: Variant) -> void:
	var homes: Array = []
	var vacancies: int = 0
	var happiness: int = 0
	for citizen: Dictionary in sim.state.citizens: happiness += citizen.satisfaction
	if happiness < sim.state.citizens.size() * sim.definitions.balance.satisfaction_min: return
	var newcomers: int = sim.definitions.balance.immigration_count
	if preload("res://sim/systems/economy.gd").food(sim) < (sim.state.citizens.size() + newcomers) * sim.definitions.balance.reserve_days: return
	for item: Dictionary in sim.state.buildings:
		if not item.connected: continue
		if item.active: vacancies += sim.definitions.buildings[item.type].jobs - item.assigned
		if item.type == "house" and item.water:
			var used: int = 0
			for citizen: Dictionary in sim.state.citizens:
				if citizen.home == item.id: used += 1
			for i: int in range(sim.definitions.buildings.house.capacity - used): homes.append(item.id)
	if homes.size() < newcomers or vacancies < newcomers: return
	for i: int in range(newcomers): sim._add_citizen(homes[i], sim.building(1).access, true)
	assign_jobs(sim)
